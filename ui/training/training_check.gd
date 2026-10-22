class_name TrainingCheck
extends RefCounted
## What a training plan ([TrainingPlan]) asks the student to wire and whether
## the student's wires do it. The places to wire: each switchboard ("+RA1"),
## the back of its door ("+RA1/door") and each control station ("+ST1"); in
## each its ports, the points a wire can go to:
## - "t:KM1:13": a device's terminal on a rail (the name as on the device,
##   "13#2" the second place of a changeover's common, see
##   [method CabinetDevices.describe]); on a door or in a station "t:" and the
##   terminal key ("t:SB1:13");
## - "s:X2:4" the top of a strip terminal, "f:X2:4" its field side;
## - "b:N", "b:PE" a distribution block;
## - "c:W2:0" core 0 of cable W2 of the workspace where it comes in,
##   "c:@door:0" a core of the door harness, "p:" and the source conductor
##   ([method CabinetDevices.supply_key]) a core of the incoming supply cable.
## What is made already joins ports: a strip terminal's top and field side,
## strip terminals bridged, each core's two ends (at a part in the field the
## core is landed already). The wiring is right when every net of the
## circuit (as [method WorkspaceCables.nets]) joins all its ports and no
## wire joins two nets, no terminal taking more wires than it holds. No nodes.

## Wires a device's or a block's terminal takes, a strip terminal's entry
## (two in one twin ferrule), a core's end.
const DEVICE_WIRES: int = 2
const STRIP_WIRES: int = 2
const CORE_WIRES: int = 1
## Ports named in a problem at most, then "…".
const NAMES: int = 2


## Every port to wire: "place|port" -> {"place", "id", "net" (of
## [method WorkspaceCables.nets]), "holds" (wires it takes), "name" (as
## shown: "+RA1: -KM1:13"), "core" (a core's end)}.
static func ports(doc: SchematicDocument) -> Dictionary[String, Dictionary]:
	var result: Dictionary[String, Dictionary] = {}
	var ws: Dictionary[String, int] = WorkspaceCables.nets(doc.circuit)
	var network: Dictionary[String, bool] = CabinetDevices.network_keys(doc.circuit)
	var cables: Array[Dictionary] = WorkspaceCables.cables(doc)
	for b: int in doc.switchboards.size():
		var here: String = "+" + doc.switchboards[b].name
		var layout: CabinetLayout = CabinetLayout.build(doc, 2.0, b)
		for place: Dictionary in layout.places:
			match place["kind"]:
				CabinetLayout.STRIP:
					for t: Dictionary in place["desc"]["terminals"]:
						var key: String = _first_key(t["keys"], ws)
						if key.is_empty():
							continue
						var label: String = "%s:%s" % [place["designation"], t["label"]]
						var shown: String = "-" + CabinetDevices.terminal_text(label)
						_add(result, here, "s:" + label, ws[key], STRIP_WIRES, shown)
						_add(result, here, "f:" + label, ws[key], STRIP_WIRES, shown + " " + TranslationServer.translate("(field side)"))
				CabinetLayout.BUS_BLOCK:
					var key: String = place["desc"]["key"]
					if ws.has(key):
						_add(result, here, "b:" + str(place["designation"]), ws[key], int(place["desc"]["connections"]), TranslationServer.translate("N distribution block") if place["desc"]["neutral"] else TranslationServer.translate("PE distribution block"))
				CabinetLayout.MISSING_DEVICE:
					pass
				_:
					_device_ports(result, here, place["kind"], place["desc"], place["designation"], ws, network)
					if place.has("under_origin"):
						_device_ports(result, here, CabinetDevices.Kind.OVERLOAD, place["under_desc"], place["under_designation"], ws, network)
		_cable_ports(result, here, cables)
		# The supply comes in where the cables of the workspace do not bring it.
		var arriving: Dictionary[int, bool] = CabinetWiring._arriving(doc, b, cables)
		var nets_here: Dictionary[int, bool] = {}
		for id: String in result:
			if result[id]["place"] == here:
				nets_here[result[id]["net"]] = true
		for c: CircuitComponent in doc.circuit.get_components():
			if c is PowerSupply:
				var n: int = ws[c.get_terminal_keys()[0]]
				var which: String = CabinetDevices.supply_key(c as PowerSupply)
				if nets_here.has(n) and not arriving.has(n) and not result.has(here + "|p:" + which):
					_add(result, here, "p:" + which, n, CORE_WIRES, TranslationServer.translate("supply") + " " + supply_name(c as PowerSupply), true)
		var harness: Array[Dictionary] = CabinetWiring.door_harness(doc, b)
		for i: int in harness.size():
			var shown: String = TranslationServer.translate("door harness") + " /%d" % (i + 1)
			_add(result, here, "c:%s:%d" % [CabinetWiring.DOOR, i], harness[i]["net"], CORE_WIRES, shown, true)
			_add(result, here + "/door", "c:%s:%d" % [CabinetWiring.DOOR, i], harness[i]["net"], CORE_WIRES, shown, true)
		if not doc.switchboards[b].door.items.is_empty():
			var door: StationInside = StationInside.build_door(doc, b, layout.size)
			for key: String in door.terminals:
				if ws.has(key) and not network.has(key):
					_add(result, here + "/door", "t:" + key, ws[key], DEVICE_WIRES, "-" + key)
	for i: int in doc.control_boxes.size():
		var here: String = "+" + doc.control_boxes[i].name
		var inside: StationInside = StationInside.build(doc, i)
		for key: String in inside.terminals:
			if ws.has(key):
				_add(result, here, "t:" + key, ws[key], DEVICE_WIRES, "-" + key)
		_cable_ports(result, here, cables)
	return result


## What is joined already: [["place|port" or "@key" (a terminal of a part
## in the field), the same], ...] (see the class description).
static func joins(doc: SchematicDocument, all: Dictionary[String, Dictionary]) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	for id: String in all:
		var port: String = all[id]["id"]
		if port.begins_with("s:") and all.has(all[id]["place"] + "|f:" + port.substr(2)):
			result.append(PackedStringArray([id, all[id]["place"] + "|f:" + port.substr(2)]))
		if port.begins_with("c:%s:" % CabinetWiring.DOOR) and not all[id]["place"].ends_with("/door") and all.has(all[id]["place"] + "/door|" + port):
			result.append(PackedStringArray([id, all[id]["place"] + "/door|" + port]))
	# Strip terminals bridged.
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	var strips: Dictionary = CabinetDevices.strips(doc)
	for b: int in doc.switchboards.size():
		var here: String = "+" + doc.switchboards[b].name
		var blocks: Dictionary[int, bool] = CabinetLayout.bus_nets(CabinetLayout.bus_blocks(doc, b, strips, net))
		for rail: CabinetRail in doc.switchboards[b].rails:
			for item: CabinetItem in rail.items:
				if item.kind != CabinetItem.Kind.STRIP:
					continue
				var terminals: Array = strips.get(item.designation, [])
				var bridges: Array[bool] = CabinetWiring.strip_bridges(terminals, CabinetDevices.supply_nets(doc.circuit, net), blocks)
				for i: int in bridges.size():
					if bridges[i]:
						result.append(PackedStringArray([here + "|s:%s:%s" % [item.designation, terminals[i]["label"]], here + "|s:%s:%s" % [item.designation, terminals[i + 1]["label"]]]))
	# Each core's ends; at a part in the field, the terminals it lands on.
	for cable: Dictionary in WorkspaceCables.cables(doc):
		for i: int in cable["cores"].size():
			var core: Dictionary = cable["cores"][i]
			var ends: PackedStringArray = PackedStringArray()
			for end: String in ["a", "b"]:
				var place: String = cable[end]
				if all.has("%s|c:%s:%d" % [place, cable["name"], i]):
					ends.append("%s|c:%s:%d" % [place, cable["name"], i])
				elif place.begins_with("-"):
					for label: String in core[end]:
						var key: String = _key_of(doc.circuit, label)
						if not key.is_empty():
							ends.append("@" + key)
			for k: int in range(1, ends.size()):
				result.append(PackedStringArray([ends[0], ends[k]]))
	return result


## Checks the student's wires of [param doc]'s training plan: {"ok",
## "problems": [{"kind" ("missing", "wrong", "crowded"), "text" (English,
## %s for the args), "args", "ports" (the "place|port" ids)}], "wires" (how
## many)}.
static func run(doc: SchematicDocument) -> Dictionary:
	var plan: TrainingPlan = doc.training if doc.training != null else TrainingPlan.new()
	var all: Dictionary[String, Dictionary] = ports(doc)
	var ws: Dictionary[String, int] = WorkspaceCables.nets(doc.circuit)
	var marks: Dictionary[int, String] = CabinetWiring.wire_marks(doc, ws)
	var problems: Array[Dictionary] = []
	# Nodes: the ports, then the terminals of parts in the field.
	var index: Dictionary[String, int] = {}
	var nets: Array[int] = []
	for id: String in all:
		index[id] = index.size()
		nets.append(all[id]["net"])
	var made: Array[PackedStringArray] = joins(doc, all)
	for join: PackedStringArray in made:
		for node: String in join:
			if node.begins_with("@") and not index.has(node):
				index[node] = index.size()
				nets.append(ws.get(node.substr(1), -1))
	var groups: UnionFind = UnionFind.new(index.size())
	for join: PackedStringArray in made:
		groups.union(index[join[0]], index[join[1]])
	var uses: Dictionary[String, int] = {}
	var count: int = 0
	for place: String in plan.wires:
		for wire: PackedStringArray in plan.wires[place]:
			var a: String = place + "|" + wire[0]
			var b: String = place + "|" + wire[1]
			if not all.has(a) or not all.has(b):
				# A port the plan has no more (a part taken away since).
				continue
			count += 1
			uses[a] = uses.get(a, 0) + 1
			uses[b] = uses.get(b, 0) + 1
			if all[a]["net"] != all[b]["net"]:
				problems.append({"kind": "wrong", "text": "Wrong wire: %s – %s, which are not connected in the schematic.", "args": [all[a]["name"], all[b]["name"]], "ports": PackedStringArray([a, b])})
			groups.union(index[a], index[b])
	for id: String in uses:
		if uses[id] > all[id]["holds"]:
			problems.append({"kind": "crowded", "text": "Too many wires in %s: %d, it takes %d.", "args": [all[id]["name"], uses[id], all[id]["holds"]], "ports": PackedStringArray([id])})
	# Each net joined: its ports (and the terminals in the field its cores
	# land on) in one piece.
	var pieces: Dictionary[int, Dictionary] = {}
	for node: String in index:
		var n: int = nets[index[node]]
		if n < 0:
			continue
		if not pieces.has(n):
			pieces[n] = {}
		var root: int = groups.find(index[node])
		if not pieces[n].has(root):
			pieces[n][root] = PackedStringArray()
		pieces[n][root].append(node)
	for n: int in pieces:
		if pieces[n].size() < 2:
			continue
		var parts: Array = pieces[n].values()
		parts.sort_custom(func(p: PackedStringArray, q: PackedStringArray) -> bool: return p.size() > q.size())
		for k: int in range(1, parts.size()):
			var names: PackedStringArray = _names(parts[k], all)
			if names.is_empty():
				continue
			var mark: String = marks.get(n, "")
			var ids: PackedStringArray = PackedStringArray(Array(parts[k]).filter(func(node: String) -> bool: return all.has(node)))
			if mark.is_empty():
				problems.append({"kind": "missing", "text": "%s is not joined to %s.", "args": [", ".join(names), ", ".join(_names(parts[0], all))], "ports": ids})
			else:
				problems.append({"kind": "missing", "text": "Wire %s: %s is not joined to %s.", "args": [mark, ", ".join(names), ", ".join(_names(parts[0], all))], "ports": ids})
	return {"ok": problems.is_empty(), "problems": problems, "wires": count}


## Wires that make [param doc]'s plan right: place -> [[port, port], ...]
## (each net's ports in a place chained, the cores landed on what has room).
static func solution(doc: SchematicDocument) -> Dictionary[String, Array]:
	var all: Dictionary[String, Dictionary] = ports(doc)
	# Ports joined already within one place (a strip terminal's top and
	# field side, bridged terminals) are one: only the first is chained.
	var index: Dictionary[String, int] = {}
	for id: String in all:
		index[id] = index.size()
	var groups: UnionFind = UnionFind.new(index.size())
	for join: PackedStringArray in joins(doc, all):
		if index.has(join[0]) and index.has(join[1]) and all[join[0]]["place"] == all[join[1]]["place"]:
			groups.union(index[join[0]], index[join[1]])
	var by_place: Dictionary[String, Dictionary] = {}
	for id: String in all:
		var port: Dictionary = all[id]
		if not by_place.has(port["place"]):
			by_place[port["place"]] = {}
		if not by_place[port["place"]].has(port["net"]):
			by_place[port["place"]][port["net"]] = []
		by_place[port["place"]][port["net"]].append(id)
	var result: Dictionary[String, Array] = {}
	for place: String in by_place:
		var wires: Array = []
		for n: int in by_place[place]:
			var ids: Array = by_place[place][n]
			var used: Dictionary[String, int] = {}
			var heads: Array = []
			var seen: Dictionary[int, bool] = {}
			for id: String in ids:
				var root: int = groups.find(index[id])
				if not all[id]["core"] and not str(all[id]["id"]).begins_with("f:") and not seen.has(root):
					seen[root] = true
					heads.append(id)
			for k: int in range(1, heads.size()):
				wires.append(_pair(all, heads[k - 1], heads[k]))
				used[heads[k - 1]] = used.get(heads[k - 1], 0) + 1
				used[heads[k]] = used.get(heads[k], 0) + 1
			for id: String in ids:
				if not all[id]["core"]:
					continue
				# On a strip terminal's field side first, else what has room.
				var target: String = ""
				for other: String in ids:
					if not all[other]["core"] and used.get(other, 0) < all[other]["holds"] and (target.is_empty() or str(all[other]["id"]).begins_with("f:") and not str(all[target]["id"]).begins_with("f:")):
						target = other
				if target.is_empty():
					continue
				used[target] = used.get(target, 0) + 1
				wires.append(_pair(all, id, target))
		result[place] = wires
	return result


## The source conductor of [param supply] as shown: "L1", "N", "PE", "+24 V".
static func supply_name(supply: PowerSupply) -> String:
	if supply.conductor == PowerSupply.Conductor.DC_PLUS:
		return "+%s V" % String.num(supply.voltage)
	return supply.conductor_name()


static func _pair(all: Dictionary[String, Dictionary], a: String, b: String) -> PackedStringArray:
	return PackedStringArray([all[a]["id"], all[b]["id"]])


static func _add(result: Dictionary[String, Dictionary], place: String, id: String, net: int, holds: int, name: String, core: bool = false) -> void:
	result[place + "|" + id] = {"place": place, "id": id, "net": net, "holds": holds, "name": "%s: %s" % [place, name], "core": core}


## The ports of a device on a rail: each terminal with a screw, Ethernet
## ports left out (their cables are laid already).
static func _device_ports(result: Dictionary[String, Dictionary], place: String, kind: int, desc: Dictionary, designation: String, ws: Dictionary[String, int], network: Dictionary[String, bool]) -> void:
	var terminals: Dictionary = desc.get("terminals", {})
	var screws: Dictionary = CabinetParts.terminal_points(kind, desc)
	for name: String in terminals:
		var key: String = terminals[name]
		if screws.has(name) and ws.has(key) and not network.has(key):
			_add(result, place, "t:%s:%s" % [designation, name], ws[key], DEVICE_WIRES, "-%s:%s" % [designation, name])


## Ports of the cores of every cable of the workspace that ends at [param place].
static func _cable_ports(result: Dictionary[String, Dictionary], place: String, cables: Array[Dictionary]) -> void:
	for cable: Dictionary in cables:
		if cable["a"] != place and cable["b"] != place:
			continue
		for i: int in cable["cores"].size():
			_add(result, place, "c:%s:%d" % [cable["name"], i], cable["cores"][i]["net"], CORE_WIRES, "%s/%d" % [cable["name"], i + 1], true)


static func _first_key(keys: PackedStringArray, ws: Dictionary[String, int]) -> String:
	for key: String in keys:
		if ws.has(key):
			return key
	return ""


## Terminal key of the terminal labelled [param label] ("M1:U1": the part
## and the terminal's name), "" for none.
static func _key_of(circuit: Circuit, label: String) -> String:
	var colon: int = label.rfind(":")
	if colon < 0:
		return ""
	var designation: String = label.left(colon)
	var name: String = label.substr(colon + 1)
	for c: CircuitComponent in circuit.get_components():
		if c.designation == designation:
			var names: PackedStringArray = c.get_terminal_names()
			for k: int in names.size():
				if names[k] == name:
					return c.get_terminal_keys()[k]
	return ""


## Names of the ports among [param nodes], at most NAMES and "…": a strip
## terminal once (not its field side too), terminals before cores.
static func _names(nodes: PackedStringArray, all: Dictionary[String, Dictionary]) -> PackedStringArray:
	var shown: Array = Array(nodes).filter(func(node: String) -> bool:
		if not all.has(node):
			return false
		var port: String = all[node]["id"]
		return not (port.begins_with("f:") and nodes.has(all[node]["place"] + "|s:" + port.substr(2))))
	shown.sort_custom(func(p: String, q: String) -> bool: return not all[p]["core"] and all[q]["core"])
	var result: PackedStringArray = PackedStringArray()
	for node: String in shown:
		if result.size() == NAMES:
			result.append("…")
			break
		result.append(all[node]["name"])
	return result
