class_name WorkspaceCables
extends RefCounted
## The cables of the workspace, worked out from the wiring: every net of the
## circuit that joins terminals in two or more places (a switchboard, a
## control station, a part in the field) needs a core between them. A net
## with a terminal on a strip in a switchboard runs from there to each other
## place (a star from the strip); a net in a switchboard runs from the first
## switchboard; a net only between stations and parts in the field runs the
## shortest way between them (e.g. a stop button looped through from one
## station to the next). The cores between two places make one cable, named
## W1, W2, ... ([member SchematicDocument.cable_names] keeps the names). No nodes.

## A cable: {"key" (its two ends, "+RA1|+ST1"), "name" ("W1"), "a", "b" (the
## ends: "+RA1" a switchboard or station, "-M1" a part in the field), "cores":
## [{"net", "conductor" ([enum CabinetDevices.Conductor]), "a", "b" (what the
## core lands on at each end, e.g. "X2:3", "SB1:13"), "number" (wire number,
## may be empty)}]}, the PE core last.
static func cables(doc: SchematicDocument) -> Array[Dictionary]:
	var circuit: Circuit = doc.circuit
	var net: Dictionary[String, int] = CabinetDevices.nets(circuit)
	var conductor: Dictionary[int, CabinetDevices.Conductor] = CabinetDevices.conductors(circuit, net)
	var where: Dictionary[String, String] = _locations(doc)
	# Net -> place -> what the net lands on there.
	var ends: Dictionary[int, Dictionary] = {}
	# Net -> switchboards with a strip terminal on it.
	var strip_boards: Dictionary[int, Array] = {}
	for c: CircuitComponent in circuit.get_components():
		var place: String = where.get(c.designation, "")
		if c is TerminalBlock or place.is_empty():
			continue
		var names: PackedStringArray = c.get_terminal_names()
		var keys: PackedStringArray = c.get_terminal_keys()
		for i: int in keys.size():
			_land(ends, net[keys[i]], place, "%s:%s" % [c.designation, names[i]])
	var strips: Dictionary = CabinetDevices.strips(doc)
	var strip_labels: Dictionary[String, bool] = {}
	for strip: String in strips:
		var b: int = Workspace.switchboard_of(doc, CabinetItem.Kind.STRIP, strip)
		if b < 0:
			continue
		var place: String = "+" + doc.switchboards[b].name
		for t: Dictionary in strips[strip]:
			var label: String = "%s:%s" % [strip, t["label"]]
			strip_labels[label] = true
			for key: String in t["keys"]:
				if not net.has(key):
					continue
				var n: int = net[key]
				_land(ends, n, place, label)
				if not strip_boards.has(n):
					strip_boards[n] = []
				if not strip_boards[n].has(place):
					strip_boards[n].append(place)
	# At a switchboard a core lands on its strip terminal (the devices behind
	# it are wired inside).
	for n: int in strip_boards:
		for place: String in strip_boards[n]:
			var on_strip: Array = []
			for label: Variant in ends[n][place]:
				if strip_labels.has(label):
					on_strip.append(label)
			ends[n][place] = on_strip
	var numbers: Dictionary[int, String] = _numbers(doc, net)
	var centres: Dictionary[String, Vector2] = _centres(doc)
	var rank: Dictionary[String, int] = {}
	for i: int in centres.size():
		rank[centres.keys()[i]] = i
	# Cable key -> cable.
	var found: Dictionary[String, Dictionary] = {}
	var nets: Array = ends.keys()
	nets.sort()
	for n: int in nets:
		var places: Array = ends[n].keys()
		if places.size() < 2:
			continue
		places.sort_custom(func(p: String, q: String) -> bool: return rank.get(p, 1 << 20) < rank.get(q, 1 << 20))
		var pairs: Array[PackedStringArray] = []
		var hub: String = ""
		if strip_boards.has(n):
			hub = strip_boards[n][0]
		elif places[0].begins_with("+") and _is_board(doc, places[0]):
			hub = places[0]
		if not hub.is_empty():
			for place: String in places:
				if place != hub:
					pairs.append(PackedStringArray([hub, place]))
		else:
			pairs = _tree(places, centres)
		for pair: PackedStringArray in pairs:
			var a: String = pair[0]
			var b: String = pair[1]
			if rank.get(b, 1 << 20) < rank.get(a, 1 << 20):
				a = pair[1]
				b = pair[0]
			var key: String = a + "|" + b
			if not found.has(key):
				found[key] = {"key": key, "name": "", "a": a, "b": b, "cores": []}
			found[key]["cores"].append({"net": n, "conductor": conductor.get(n, CabinetDevices.Conductor.CONTROL), "a": _labels(ends[n][a]), "b": _labels(ends[n][b]), "number": numbers.get(n, "")})
	var result: Array[Dictionary] = []
	for key: String in found:
		var cable: Dictionary = found[key]
		# The PE core last, as in a real cable.
		(cable["cores"] as Array).sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["conductor"] != CabinetDevices.Conductor.PE and q["conductor"] == CabinetDevices.Conductor.PE)
		result.append(cable)
	result.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		if p["a"] != q["a"]:
			return rank.get(p["a"], 1 << 20) < rank.get(q["a"], 1 << 20)
		return rank.get(p["b"], 1 << 20) < rank.get(q["b"], 1 << 20))
	_name(doc, result)
	return result


## Short text of a cable's cores, e.g. "4G" (four cores, one of them PE) or "6".
static func cores_text(cable: Dictionary) -> String:
	var cores: Array = cable["cores"]
	for core: Dictionary in cores:
		if core["conductor"] == CabinetDevices.Conductor.PE:
			return "%dG" % cores.size()
	return str(cores.size())


## A cable name as saved: "" when unusable (empty, spaces, colons, "|").
static func cable_name(value: Variant) -> String:
	var text: String = str(value).strip_edges()
	return "" if text.contains(":") or text.contains(" ") or text.contains("|") else text


## Names: the one kept for the cable, else the first free "W<n>" in order.
static func _name(doc: SchematicDocument, list: Array[Dictionary]) -> void:
	var taken: Dictionary[String, bool] = {}
	for cable: Dictionary in list:
		var kept: String = doc.cable_names.get(cable["key"], "")
		if not kept.is_empty() and not taken.has(kept):
			cable["name"] = kept
			taken[kept] = true
	var n: int = 1
	for cable: Dictionary in list:
		if not str(cable["name"]).is_empty():
			continue
		while taken.has("W%d" % n):
			n += 1
		cable["name"] = "W%d" % n
		taken[cable["name"]] = true


## Where each part of the circuit sits, by designation: "+RA1" for a device
## in a switchboard (an overload relay fitted under its contactor where the
## contactor is), "+ST1" for a button, switch or lamp on a station, "-M1" for
## a part in the field. Parts with no place are left out.
static func _locations(doc: SchematicDocument) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for board: Switchboard in doc.switchboards:
		for rail: CabinetRail in board.rails:
			for item: CabinetItem in rail.items:
				if item.kind == CabinetItem.Kind.DEVICE:
					result[item.designation] = "+" + board.name
	var under: Dictionary[String, String] = CabinetDevices.overloads_under_contactors(doc.circuit)
	for contactor: String in under:
		if result.has(contactor) and not result.has(under[contactor]):
			result[under[contactor]] = result[contactor]
	for box: ControlBox in doc.control_boxes:
		for item: ControlBoxItem in box.items:
			for designation: String in [item.designation, item.lamp]:
				if not designation.is_empty():
					result[designation] = "+" + box.name
	for designation: String in Workspace.field_devices(doc.circuit):
		result[designation] = "-" + designation
	return result


## Centre of every place and part in the field on the workspace, switchboards
## first, then stations, then parts (their order ranks the ends of a cable).
static func _centres(doc: SchematicDocument) -> Dictionary[String, Vector2]:
	var result: Dictionary[String, Vector2] = {}
	var tile: Vector2 = Vector2(Workspace.TILE, Workspace.TILE) * 0.5
	for board: Switchboard in doc.switchboards:
		result["+" + board.name] = board.position + tile
	for box: ControlBox in doc.control_boxes:
		result["+" + box.name] = box.position + tile
	var positions: Dictionary[String, Vector2] = Workspace.field_positions(doc)
	for designation: String in positions:
		result["-" + designation] = positions[designation] + Vector2(Workspace.FIELD_SIZE.x * 0.5, Workspace.FIELD_TILE * 0.5)
	return result


static func _is_board(doc: SchematicDocument, place: String) -> bool:
	for board: Switchboard in doc.switchboards:
		if "+" + board.name == place:
			return true
	return false


static func _land(ends: Dictionary[int, Dictionary], n: int, place: String, label: String) -> void:
	if not ends.has(n):
		ends[n] = {}
	if not ends[n].has(place):
		ends[n][place] = []
	if not ends[n][place].has(label):
		ends[n][place].append(label)


static func _labels(list: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for label: Variant in list:
		result.append(str(label))
	return result


## Wire number of each net that has one.
static func _numbers(doc: SchematicDocument, net: Dictionary[String, int]) -> Dictionary[int, String]:
	var result: Dictionary[int, String] = {}
	var wires: Array[PackedStringArray] = doc.circuit.get_wires()
	for i: int in wires.size():
		var number: String = doc.get_route(i).number
		if not number.is_empty() and net.has(wires[i][0]):
			result[net[wires[i][0]]] = number
	return result


## Pairs of [param places] joining them all along the shortest distances
## between their [param centres] (a minimum spanning tree).
static func _tree(places: Array, centres: Dictionary[String, Vector2]) -> Array[PackedStringArray]:
	var pairs: Array[PackedStringArray] = []
	var joined: Array = [places[0]]
	while joined.size() < places.size():
		var best: float = INF
		var pair: PackedStringArray = PackedStringArray()
		for a: String in joined:
			for b: String in places:
				if joined.has(b):
					continue
				var d: float = centres.get(a, Vector2.ZERO).distance_to(centres.get(b, Vector2.ZERO))
				if d < best:
					best = d
					pair = PackedStringArray([a, b])
		joined.append(pair[1])
		pairs.append(pair)
	return pairs
