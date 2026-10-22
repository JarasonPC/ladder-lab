extends GutTest
## Every switchboard drawn whole: each net joined on its terminals by
## wires, plug-in bridges and distribution blocks, no wire between two nets,
## no clamp holding more than it takes, a supply core in for every supply
## and a core out for every strip terminal leading outside, in the built-in
## examples and in switchboards set up in other ways (split over two
## switchboards, no terminal strips, parts on the door, a strip order set by
## hand, two + voltages).

const K: float = 2.0


## What is wrong with the wiring of switchboard [param board] of
## [param doc], one line each ([param tag] before it). [param clamps]: also
## clamps holding more wires than they take.
func _problems(doc: SchematicDocument, board: int, tag: String, clamps: bool = true) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var layout: CabinetLayout = CabinetLayout.build(doc, K, board)
	var wiring: CabinetWiring = layout.wiring if layout.wiring != null else CabinetWiring.build(doc, layout, K, board)
	var circuit: Circuit = doc.circuit
	var net: Dictionary[String, int] = CabinetDevices.nets(circuit)
	var same: Dictionary[String, int] = CabinetDevices.supply_nets(circuit, net)
	# Every terminal a wire can go to: {"key", "at", "what" (dev, strip,
	# field: a strip terminal's field side, bus), "group" (one terminal),
	# "bridge" (the group bridged to it), "label"}.
	var points: Array[Dictionary] = []
	for p: int in layout.places.size():
		var place: Dictionary = layout.places[p]
		var origin: Vector2 = place["origin"]
		match place["kind"]:
			CabinetLayout.STRIP:
				var terminals: Array = place["desc"]["terminals"]
				var bridges: Array = place["desc"].get("bridges", [])
				for i: int in terminals.size():
					var label: String = "%s:%s" % [place["designation"], terminals[i]["label"]]
					var bridge: String = "s%d:%d" % [p, i + 1] if i < bridges.size() and bridges[i] else ""
					for key: String in terminals[i]["keys"]:
						if net.has(key):
							points.append({"key": key, "at": origin + CabinetParts.strip_entry(i, K), "what": "strip", "group": "s%d:%d" % [p, i], "bridge": bridge, "label": label})
							points.append({"key": key, "at": origin + CabinetParts.strip_entry(i, K, true), "what": "field", "group": "s%d:%d" % [p, i], "bridge": "", "label": label + " field side"})
			CabinetLayout.BUS_BLOCK:
				for i: int in place["desc"]["connections"]:
					points.append({"key": place["desc"]["key"], "at": origin + CabinetParts.bus_entry(i), "what": "bus", "group": "b%d" % p, "bridge": "", "label": "block " + place["designation"], "connections": place["desc"]["connections"]})
			CabinetLayout.MISSING_DEVICE:
				pass
			_:
				_device_points(points, place["kind"], place["desc"], origin, net, place["designation"])
				if place.has("under_origin"):
					_device_points(points, CabinetDevices.Kind.OVERLOAD, place["under_desc"], place["under_origin"], net, place["under_designation"])
	var joined: UnionFind = UnionFind.new(points.size())
	var groups: Dictionary[String, Array] = {}
	for i: int in points.size():
		if not groups.has(points[i]["group"]):
			groups[points[i]["group"]] = []
		groups[points[i]["group"]].append(i)
	for i: int in points.size():
		for g: String in [points[i]["group"], points[i]["bridge"]]:
			for j: int in groups.get(g, []):
				if g != "" and same[points[j]["key"]] == same[points[i]["key"]]:
					joined.union(i, j)
	# The terminal a wire end goes into: the nearest one with its key.
	var nearest: Callable = func(key: String, at: Vector2) -> int:
		var best: int = -1
		for i: int in points.size():
			if points[i]["key"] == key and (best < 0 or (points[i]["at"] as Vector2).distance_to(at) < (points[best]["at"] as Vector2).distance_to(at)):
				best = i
		return best
	var uses: Dictionary[int, int] = {}
	var fed: Dictionary[int, bool] = {}
	var sent: Dictionary[int, bool] = {}
	for wire: Dictionary in wiring.wires:
		var path: PackedVector2Array = wire["points"]
		var b: int = nearest.call(wire["to"], path[path.size() - 1])
		if b < 0:
			problems.append("%s: a wire ends at %s, no terminal" % [tag, wire["to"]])
			continue
		uses[b] = uses.get(b, 0) + 1
		if wire["external"]:
			if wire["cable"] == "AC" or wire["cable"] == "DC":
				fed[same[wire["to"]]] = true
			else:
				sent[same[wire["to"]]] = true
			continue
		var a: int = nearest.call(wire["from"], path[0])
		if a < 0:
			problems.append("%s: a wire ends at %s, no terminal" % [tag, wire["from"]])
			continue
		uses[a] = uses.get(a, 0) + 1
		if same[wire["from"]] != same[wire["to"]]:
			problems.append("%s: a wire joins two nets, %s and %s" % [tag, points[a]["label"], points[b]["label"]])
		joined.union(a, b)
	# Each net joined.
	var parts_of: Dictionary[int, Dictionary] = {}
	for i: int in points.size():
		var n: int = same[points[i]["key"]]
		if not parts_of.has(n):
			parts_of[n] = {}
		var root: int = joined.find(i)
		if not parts_of[n].has(root):
			parts_of[n][root] = PackedStringArray()
		parts_of[n][root].append(points[i]["label"])
	for n: int in parts_of:
		if parts_of[n].size() > 1:
			var pieces: PackedStringArray = PackedStringArray()
			for root: int in parts_of[n]:
				pieces.append(", ".join(parts_of[n][root]))
			problems.append("%s: a net in pieces: %s" % [tag, " | ".join(pieces)])
	# Clamps, strip terminal entries (two in a twin ferrule) and blocks.
	if clamps:
		var on_block: Dictionary[String, int] = {}
		for i: int in uses:
			var twin: bool = wiring.twins.any(func(t: Dictionary) -> bool: return (t["at"] as Vector2).distance_to(points[i]["at"]) < 0.5)
			match points[i]["what"]:
				"bus":
					on_block[points[i]["group"]] = on_block.get(points[i]["group"], 0) + uses[i]
				"dev":
					if uses[i] > CabinetWiring.CLAMP_WIRES:
						problems.append("%s: %d wires in %s" % [tag, uses[i], points[i]["label"]])
				_:
					if uses[i] > (2 if twin else 1):
						problems.append("%s: %d wires in %s" % [tag, uses[i], points[i]["label"]])
		for g: String in on_block:
			if on_block[g] > points[groups[g][0]]["connections"]:
				problems.append("%s: %d wires on a block of %d connections" % [tag, on_block[g], points[groups[g][0]]["connections"]])
	# A core in for every supply with terminals here, a core out for every
	# strip terminal leading outside.
	for c: CircuitComponent in circuit.get_components():
		var n: int = same[c.get_terminal_keys()[0]]
		if c is PowerSupply and parts_of.has(n) and not fed.has(n) and not sent.has(n):
			problems.append("%s: no core brings in %s" % [tag, c.designation])
	for point: Dictionary in points:
		if point["what"] == "field" and not (circuit.get_terminal_owner(point["key"]) is PowerSupply) and not CabinetDevices.field_devices(circuit, point["key"], net).is_empty() and not sent.has(same[point["key"]]):
			problems.append("%s: no core out of %s" % [tag, point["label"]])
	# A net reaching a part outside goes out, with or without a strip terminal.
	for n: int in parts_of:
		if sent.has(n):
			continue
		for key: String in same:
			var owner: CircuitComponent = circuit.get_terminal_owner(key)
			if same[key] == n and owner != null and CabinetDevices.is_outside(circuit, owner) and not CabinetDevices.network_keys(circuit).has(key):
				problems.append("%s: nothing goes out to %s" % [tag, key])
				break
	# The door harness: the cores the door takes.
	var door: Dictionary[int, bool] = {}
	for wire: Dictionary in wiring.wires:
		if wire["external"] and wire["cable"] == CabinetWiring.DOOR:
			door[same[wire["to"]]] = true
	if door.size() != CabinetWiring.door_harness(doc, board).size():
		problems.append("%s: %d cores to the door, the door takes %d" % [tag, door.size(), CabinetWiring.door_harness(doc, board).size()])
	return problems


func _device_points(points: Array[Dictionary], kind: int, desc: Dictionary, origin: Vector2, net: Dictionary[String, int], designation: String) -> void:
	var terminals: Dictionary = desc.get("terminals", {})
	var at: Dictionary = CabinetParts.terminal_points(kind, desc)
	for name: String in terminals:
		# The heaters of an overload relay under its contactor are in the
		# contactor's outputs.
		if net.has(terminals[name]) and at.has(name):
			var p: Vector3 = at[name]
			points.append({"key": terminals[name], "at": origin + Vector2(p.x, p.y), "what": "dev", "group": "", "bridge": "", "label": "%s:%s" % [designation, name]})


func _all(doc: SchematicDocument, tag: String, clamps: bool = true) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for b: int in doc.switchboards.size():
		problems.append_array(_problems(doc, b, "%s +%s" % [tag, doc.switchboards[b].name], clamps))
	return problems


func _supplies(doc: SchematicDocument) -> void:
	for s: Array in [["L1", PowerSupply.Conductor.L], ["L2", PowerSupply.Conductor.L2], ["L3", PowerSupply.Conductor.L3], ["N", PowerSupply.Conductor.N], ["PE", PowerSupply.Conductor.PE]]:
		doc.add(PowerSupply.new(s[0], s[1]), Vector2i(4 * doc.circuit.get_components().size(), 0))


func _add(doc: SchematicDocument, c: CircuitComponent) -> CircuitComponent:
	var n: int = doc.circuit.get_components().size()
	doc.add(c, Vector2i(4 + (n % 12) * 8, 4 + (n / 12) * 14))
	return c


## Moves the rail items [param designations] to a new rail of switchboard
## [param to] (made when there is none).
func _move(doc: SchematicDocument, designations: Array, to: int) -> void:
	while doc.switchboards.size() <= to:
		doc.add_switchboard()
	var rail: CabinetRail = doc.add_cabinet_rail(to)
	for b: int in doc.switchboards.size():
		for r: CabinetRail in doc.switchboards[b].rails:
			if r == rail:
				continue
			for item: CabinetItem in r.items.duplicate():
				if designations.has(item.designation):
					r.items.erase(item)
					rail.items.append(item)


## Example [param index] with every other device and strip X2 in a second switchboard.
func _split(index: int) -> SchematicDocument:
	var doc: SchematicDocument = ExampleCircuits.build(index)
	var devices: PackedStringArray = CabinetDevices.devices(doc)
	var moved: Array = ["X2"]
	for i: int in range(1, devices.size(), 2):
		moved.append(devices[i])
	_move(doc, moved, 1)
	return doc


## Example [param index] without terminals on its parts outside, its
## stations kept ([param where] 0), gone (1) or on the switchboard's door (2).
func _bare(index: int, where: int) -> SchematicDocument:
	var doc: SchematicDocument = ExampleCircuits.build(index)
	for c: CircuitComponent in doc.circuit.get_components():
		var placement: Placement = doc.get_placement(c.id)
		if not (c is PowerSupply) and placement != null:
			for i: int in placement.strips.keys():
				doc.set_strip_terminal(c.id, i, "")
	if where == 2:
		_onto_door(doc)
	elif where == 1:
		doc.control_boxes.clear()
	return doc


func _onto_door(doc: SchematicDocument) -> void:
	for box: ControlBox in doc.control_boxes:
		doc.switchboards[0].door.items.append_array(box.items)
	doc.control_boxes.clear()


func test_examples_are_wired_whole() -> void:
	var problems: PackedStringArray = PackedStringArray()
	for i: int in ExampleCircuits.count():
		problems.append_array(_all(ExampleCircuits.build(i), "example %d" % i))
		problems.append_array(_all(ExampleCircuits.build(i, true), "example %d across" % i))
		problems.append_array(_all(_split(i), "example %d split" % i))
		var door: SchematicDocument = ExampleCircuits.build(i)
		_onto_door(door)
		problems.append_array(_all(door, "example %d on the door" % i))
		for where: int in 3:
			# Parts without a place, no terminal between them: as many wires
			# from one terminal as there are parts.
			problems.append_array(_all(_bare(i, where), "example %d bare %d" % [i, where], where != 1))
	assert_eq(problems, PackedStringArray())


func test_lessons_are_wired_whole() -> void:
	var problems: PackedStringArray = PackedStringArray()
	for lesson: Lesson in Lessons.all():
		var doc: SchematicDocument = lesson.solution.call()
		doc.add_switchboard()
		doc.fill_cabinet(0)
		# No terminal strips: a clamp may take a core out besides two wires.
		problems.append_array(_all(doc, lesson.id, false))
	assert_eq(problems, PackedStringArray())


func test_strip_order_set_by_hand() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(9)
	for strip: String in ["X2", "X3"]:
		var labels: PackedStringArray = PackedStringArray()
		for t: Dictionary in CabinetDevices.strips(doc)[strip]:
			labels.append(t["label"])
		labels.reverse()
		doc.strip_orders[strip] = labels
	assert_eq(_all(doc, "reversed"), PackedStringArray())


## A 24 V and a 10 V + supply, each feeding a relay through its own strip
## terminal side by side.
func test_supplies_of_two_voltages_stay_apart() -> void:
	var doc: SchematicDocument = SchematicDocument.new("dc")
	_add(doc, PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS))
	var ten: PowerSupply = _add(doc, PowerSupply.new("+.2", PowerSupply.Conductor.DC_PLUS)) as PowerSupply
	ten.voltage = 10.0
	_add(doc, PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS))
	for i: int in 2:
		_add(doc, Coil.new("KA%d" % (i + 1), Coil.Kind.RELAY))
		var block: TerminalBlock = _add(doc, TerminalBlock.new("X%d" % (10 + i))) as TerminalBlock
		block.label = "X4:%d" % (i + 1)
		doc.connect_terminals(["+", "+.2"][i], block.designation)
		doc.connect_terminals(block.designation, "KA%d:A1" % (i + 1))
		doc.connect_terminals("KA%d:A2" % (i + 1), "-")
	doc.add_switchboard()
	doc.fill_cabinet(0)
	assert_eq(_all(doc, "dc"), PackedStringArray())
	var layout: CabinetLayout = CabinetLayout.build(doc, K)
	var plus: int = 0
	for wire: Dictionary in layout.wiring.wires:
		if wire["external"] and wire["from"].begins_with("+"):
			plus += 1
	assert_eq(plus, 2, "a + core of each voltage comes in")
	for place: Dictionary in layout.places:
		if place["designation"] == "X4":
			assert_eq(place["desc"]["bridges"], [false], "no bridge between 24 V and 10 V")


## Six relays and contactor KM1 taking N, KM1's through the overload
## contact of F1 under it.
func test_distribution_block_has_a_connection_for_every_load() -> void:
	var doc: SchematicDocument = SchematicDocument.new("n")
	_supplies(doc)
	_add(doc, Coil.new("KM1"))
	_add(doc, MainContacts.new("KM1"))
	_add(doc, OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3))
	_add(doc, OverloadContact.new("F1", SwitchingElement.ContactType.NC))
	for pole: int in 3:
		doc.connect_terminals(["L1", "L2", "L3"][pole], "KM1:%d" % (2 * pole + 1))
		doc.connect_terminals("KM1:%d" % (2 * pole + 2), "F1:%d" % (2 * pole + 1))
	doc.connect_terminals("L1", "KM1:A1")
	doc.connect_terminals("KM1:A2", "F1:95")
	doc.connect_terminals("F1:96", "N")
	for i: int in 6:
		_add(doc, Coil.new("KA%d" % (i + 1), Coil.Kind.RELAY))
		doc.connect_terminals("L1", "KA%d:A1" % (i + 1))
		doc.connect_terminals("KA%d:A2" % (i + 1), "N")
	doc.add_switchboard()
	doc.fill_cabinet(0)
	assert_eq(_all(doc, "n"), PackedStringArray())
	var blocks: Array[Dictionary] = CabinetLayout.bus_blocks(doc, 0, CabinetDevices.strips(doc), CabinetDevices.nets(doc.circuit))
	assert_eq(blocks.size(), 1)
	assert_true(blocks[0]["connections"] >= 8, "the relays, F1:96 and the incoming N")


## FU1 feeds KA1 here and, through strip terminal X5:1, KA2 in +RA2.
func _onward() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("onward")
	_supplies(doc)
	_add(doc, Fuse.new("FU1"))
	_add(doc, Coil.new("KA1", Coil.Kind.RELAY))
	_add(doc, Coil.new("KA2", Coil.Kind.RELAY))
	var block: TerminalBlock = _add(doc, TerminalBlock.new("X5")) as TerminalBlock
	block.label = "X5:1"
	doc.connect_terminals("L1", "FU1:1")
	doc.connect_terminals("FU1:2", "KA1:A1")
	doc.connect_terminals("KA1:A1", "X5")
	doc.connect_terminals("X5", "KA2:A1")
	doc.connect_terminals("KA1:A2", "N")
	doc.connect_terminals("KA2:A2", "N")
	doc.add_switchboard()
	doc.fill_cabinet(0)
	_move(doc, ["KA2"], 1)
	return doc


func test_cable_to_another_switchboard_lands_on_its_strip_terminal() -> void:
	var doc: SchematicDocument = _onward()
	assert_eq(_all(doc, "onward"), PackedStringArray())
	var between: Dictionary = WorkspaceCables.cables(doc)[0]
	assert_eq(between["key"], "+RA1|+RA2")
	var first: CabinetWiring = CabinetLayout.build(doc, K, 0).wiring
	var second: CabinetWiring = CabinetLayout.build(doc, K, 1).wiring
	var lands: Dictionary[String, String] = {}
	for wire: Dictionary in first.wires:
		if wire["cable"] == between["name"]:
			lands[wire["to"]] = wire["cable"]
	assert_eq(lands.get("X5", ""), between["name"], "out of X5:1, as the cable says, not out of FU1:2")
	assert_eq(lands.get("KA1:A2", ""), between["name"], "N goes on in the cable too")
	for wire: Dictionary in second.wires:
		assert_ne(wire["cable"], "AC", "+RA2 takes its N from +RA1, in the cable between them")
	assert_eq(second.glands.size(), 1, "the cable from +RA1 alone")


func test_parts_outside_without_terminals_are_wired_out() -> void:
	var doc: SchematicDocument = Lessons.by_id("start_stop").solution.call()
	doc.add_switchboard()
	doc.fill_cabinet(0)
	var cables: Dictionary[String, int] = {}
	for wire: Dictionary in CabinetLayout.build(doc, K).wiring.wires:
		if wire["external"] and wire["cable"] != "AC":
			cables[wire["cable"]] = cables.get(wire["cable"], 0) + 1
	assert_eq(cables.get("-SB1", 0), 2, "the start button: KM1:13 and KM1:14")
	assert_eq(cables.get("-H1", 0), 2, "the lamp: KM1:24 and N")
	var door: SchematicDocument = ExampleCircuits.build(0)
	_onto_door(door)
	for c: CircuitComponent in door.circuit.get_components():
		var placement: Placement = door.get_placement(c.id)
		if not (c is PowerSupply) and placement != null:
			for i: int in placement.strips.keys():
				door.set_strip_terminal(c.id, i, "")
	assert_false(CabinetWiring.door_harness(door, 0).is_empty(), "the door's parts take cores of the harness straight from the devices")
	assert_eq(_all(door, "door"), PackedStringArray())
