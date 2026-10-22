class_name TrainingSim
extends RefCounted
## A training plan simulated as the student wired it: a copy of the
## schematic whose nets reaching the switchboards, doors and stations are
## made of the student's wires (and of what is made already: strip terminals'
## two sides, bridges, the cores of the laid cables, a distribution block's
## bar, an overload relay's heaters in its contactor's outputs) instead of
## the schematic's wires. What no port of the plan reaches
## (an Ethernet cable, a part with no place) keeps the schematic's wires.
## A strip terminal on the lead of a part (or of a supply point) gets a
## terminal of its own in the copy, so the part is joined to it only by the
## core the student lands; the supply comes in on the supply points, where
## the student lands the incoming cable's cores. No nodes.


## The copy of [param doc] to simulate (see the class description); its
## [member TrainingPlan.drawn] is [param doc].
static func build(doc: SchematicDocument) -> SchematicDocument:
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	if copy.training == null:
		return copy
	copy.training.drawn = doc
	var all: Dictionary[String, Dictionary] = TrainingCheck.ports(doc)
	var nodes: Dictionary[String, int] = {}
	var node: Callable = func(name: String) -> int:
		if not nodes.has(name):
			nodes[name] = nodes.size()
		return nodes[name]
	var pairs: Array[PackedStringArray] = []
	var strips: Dictionary = CabinetDevices.strips(doc)
	var strip_keys: Dictionary[String, String] = {}
	var supplies: Dictionary[String, String] = {}
	for c: CircuitComponent in doc.circuit.get_components():
		if c is PowerSupply and not supplies.has(CabinetDevices.supply_key(c as PowerSupply)):
			supplies[CabinetDevices.supply_key(c as PowerSupply)] = c.get_terminal_keys()[0]
	var boards: Dictionary[String, bool] = {}
	for board: Switchboard in doc.switchboards:
		boards["+" + board.name] = true
	for id: String in all:
		var port: String = all[id]["id"]
		var place: String = all[id]["place"]
		var key: String = ""
		match port.left(2):
			"t:":
				key = port.substr(2)
				if boards.has(place):
					# A device on a rail: its terminal's name on the device.
					var designation: String = key.get_slice(":", 0)
					var terminals: Dictionary = CabinetDevices.describe(doc, designation).get("terminals", {})
					key = terminals.get(key.substr(designation.length() + 1), "")
			"s:", "f:":
				key = _strip_key(copy, strips, port.substr(2), strip_keys)
			"p:":
				key = supplies.get(port.substr(2), "")
		node.call(id)
		if not key.is_empty():
			pairs.append(PackedStringArray([id, "@" + key]))
	pairs.append_array(TrainingCheck.joins(doc, all))
	# An overload relay under its contactor: its heaters' pins are in the
	# contactor's power outputs, pole by pole.
	var under: Dictionary[String, String] = CabinetDevices.overloads_under_contactors(doc.circuit)
	for contactor: String in under:
		if not doc.cabinet_has(CabinetItem.Kind.DEVICE, contactor):
			continue
		var mains: MainContacts = null
		for c: CircuitComponent in doc.circuit.get_components():
			if c is MainContacts and c.designation == contactor:
				mains = c as MainContacts
		var relay: OverloadRelay = doc.circuit.get_overload_relay(under[contactor])
		if mains == null or relay == null:
			continue
		var outputs: PackedStringArray = mains.get_terminal_keys()
		var heaters: PackedStringArray = relay.get_terminal_keys()
		for pole: int in mini(3, mini(outputs.size(), heaters.size()) / 2):
			pairs.append(PackedStringArray(["@" + outputs[2 * pole + 1], "@" + heaters[2 * pole]]))
	for place: String in doc.training.wires:
		for wire: PackedStringArray in doc.training.wires[place]:
			if TrainingFaults.broken(doc.training, place, wire):
				# A broken wire of a fault-finding task: drawn, joins nothing.
				continue
			if all.has(place + "|" + wire[0]) and all.has(place + "|" + wire[1]):
				pairs.append(PackedStringArray([place + "|" + wire[0], place + "|" + wire[1]]))
	for pair: PackedStringArray in pairs:
		node.call(pair[0])
		node.call(pair[1])
	var groups: UnionFind = UnionFind.new(nodes.size())
	for pair: PackedStringArray in pairs:
		groups.union(nodes[pair[0]], nodes[pair[1]])
	# The schematic's wires of the nets the plan reaches go; the student's
	# come in their place.
	var net: Dictionary[String, int] = CabinetDevices.nets(copy.circuit)
	var reached: Dictionary[int, bool] = {}
	for name: String in nodes:
		if name.begins_with("@") and net.has(name.substr(1)):
			reached[net[name.substr(1)]] = true
	var wires: Array[PackedStringArray] = copy.circuit.get_wires()
	for i: int in range(wires.size() - 1, -1, -1):
		if reached.has(net.get(wires[i][0], -1)) or reached.has(net.get(wires[i][1], -1)):
			copy.remove_wire(i)
	var keys_of: Dictionary[int, PackedStringArray] = {}
	for name: String in nodes:
		if name.begins_with("@"):
			var root: int = groups.find(nodes[name])
			if not keys_of.has(root):
				keys_of[root] = PackedStringArray()
			keys_of[root].append(name.substr(1))
	for root: int in keys_of:
		var keys: PackedStringArray = keys_of[root]
		for k: int in range(1, keys.size()):
			copy.connect_terminals(keys[0], keys[k])
	TrainingFaults.apply(copy)
	# Where a multimeter's probe on each port touches the copy.
	for id: String in all:
		var root: int = groups.find(nodes[id])
		copy.training.probe_keys[id] = keys_of[root][0] if keys_of.has(root) else ""
	return copy


## The terminal key strip terminal [param label] ("X2:4") is in [param copy]:
## the terminal on a wire that is it, else a terminal of its own added (a
## terminal on a part's lead shares the part's key). [param made] keeps them.
static func _strip_key(copy: SchematicDocument, strips: Dictionary, label: String, made: Dictionary[String, String]) -> String:
	if made.has(label):
		return made[label]
	var strip: String = label.get_slice(":", 0)
	var name: String = label.substr(strip.length() + 1)
	var key: String = ""
	for t: Dictionary in strips.get(strip, []):
		if t["label"] != name:
			continue
		for k: String in t["keys"]:
			if copy.circuit.get_terminal_owner(k) is TerminalBlock:
				key = k
				break
	if key.is_empty():
		var n: int = 1
		while copy.circuit.get_terminal_owner("XS%d" % n) != null:
			n += 1
		var block: TerminalBlock = TerminalBlock.new("XS%d" % n)
		copy.add(block, Vector2i(-1000 - 2 * n, -1000))
		key = block.get_terminal_keys()[0]
	made[label] = key
	return key
