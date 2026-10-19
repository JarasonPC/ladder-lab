class_name CabinetWiring
extends RefCounted
## The wires of the switchboard (rozvaděč), in millimetres on a
## [CabinetLayout]: every net of the circuit that reaches two or more
## terminals on the rails is wired terminal to terminal along the shortest
## tree joining them. A wire leaves its terminal straight to the duct over
## or under its rail, goes in through the nearest slot between the duct's
## fingers, runs along the duct (down a side duct to reach another duct)
## and comes out to the other terminal the same way. Wires from the bottom
## terminals of a contactor with an overload relay under it run across the
## contactor's front out to the nearer side and down beside the relay.
## Wires sharing a duct lie side by side. The supply comes in from outside:
## one cable per source (AC, DC) through a gland in the top of the
## enclosure, each core of a supply conductor (L1, L2, L3, N, PE; +, -)
## straight into the top duct and on to the first terminal it feeds, or to
## the field side of the strip terminal on its supply point's lead. The
## colour follows the conductor of the net
## ([method CabinetDevices.conductors]). Terminals of the strips that lead
## to parts outside (buttons, lamps, motors) send their field wires out:
## from the bottom of the terminal to the bottom duct and out through a
## gland in the bottom of the enclosure, one cable for each cable of the
## workspace (see [WorkspaceCables]: "W2" to a control station with all
## its buttons and lamps, a core for each net), one per part for parts
## without a place; a net going on to another switchboard leaves the same
## way, in the cable between the two. No nodes.

## Room between a duct and the bend into its slot.
const BEND: float = 2.0
## Thickness of a control wire and of a power wire.
const WIRE_W: float = 1.6
const POWER_W: float = 2.0
## Room a wire takes in a duct and in a slot.
const LANE: float = 2.2
## Room between two wires running out from under a contactor.
const LEG_STEP: float = 0.8
## Room between the cores of the incoming cable where it enters.
const CORE: float = 2.2
## Order of the cores of the incoming cables, AC then DC.
const CORE_ORDER: Array[PowerSupply.Conductor] = [
	PowerSupply.Conductor.L, PowerSupply.Conductor.L2, PowerSupply.Conductor.L3, PowerSupply.Conductor.N,
	PowerSupply.Conductor.PE, PowerSupply.Conductor.DC_PLUS, PowerSupply.Conductor.DC_MINUS,
]
## Room between two wires in one terminal.
const SHARED: float = 0.9

## The wires: {"net": int, "conductor": [enum CabinetDevices.Conductor],
## "width": float, "points": PackedVector2Array (mm, from one terminal to
## the other), "from", "to" (terminal keys in the circuit; for a core of a
## cable "from" names the cable), "external" (true for a core of a cable:
## it starts at the gland), "cable" ("AC", "DC", or what is written on a
## field cable: the workspace cable's name, "-SB1" for a part without a place)}.
var wires: Array[Dictionary] = []
## Cable glands (mm): {"rect", "bottom" (in the bottom of the enclosure,
## a field cable going out; else the supply coming in at the top),
## "cable"}.
var glands: Array[Dictionary] = []

# Field side of the strip terminals leading to parts outside, like the
# points of [method _terminals] with "field" (the part).
var _field: Array[Dictionary] = []
# Field side of the strip terminals on the leads of supply points, where the
# incoming cores land: conductor -> point like those of [method _terminals].
var _entries: Dictionary[PowerSupply.Conductor, Dictionary] = {}
# Where the cores of the field cables leave the plate (mm from its top).
var _bottom: float = 0.0

var _circuit: Circuit
# Ducts across (top to bottom) and down the sides (left, right).
var _across: Array[Rect2] = []
var _sides: Array[Rect2] = []


## Wires of switchboard [param board] of [param doc] laid out on
## [param layout] ([param k]: pixels per mm the terminal strips are drawn at).
static func build(doc: SchematicDocument, layout: CabinetLayout, k: float, board: int = 0) -> CabinetWiring:
	var wiring: CabinetWiring = CabinetWiring.new()
	for duct: Dictionary in layout.ducts:
		if duct["vertical"]:
			wiring._sides.append(duct["rect"])
		else:
			wiring._across.append(duct["rect"])
	if wiring._sides.size() < 2 or wiring._across.is_empty():
		return wiring
	wiring._circuit = doc.circuit
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	var conductor: Dictionary[int, CabinetDevices.Conductor] = CabinetDevices.conductors(doc.circuit, net)
	# Net -> its terminals on the rails, in the order of the places.
	var by_net: Dictionary[int, Array] = {}
	for point: Dictionary in wiring._terminals(layout, k, net):
		var n: int = net[point["key"]]
		if not by_net.has(n):
			by_net[n] = []
		by_net[n].append(point)
	var cores: Dictionary[int, Dictionary] = wiring._feed(doc.circuit, net, conductor, by_net)
	var edges: Array[Dictionary] = []
	for n: int in by_net:
		var points: Array = by_net[n]
		var c: CabinetDevices.Conductor = conductor.get(n, CabinetDevices.Conductor.CONTROL)
		var entry: Dictionary = wiring._entries.get(cores[n]["conductor"], {}) if cores.has(n) else {}
		if not entry.is_empty():
			# The core lands on the supply's strip terminal from below.
			edges.append({"net": n, "conductor": c, "a": cores[n], "b": entry, "width": POWER_W if c == CabinetDevices.Conductor.POWER else WIRE_W})
		elif cores.has(n):
			points.push_front(cores[n])
		for pair: Vector2i in wiring._tree(points, cores.has(n) and entry.is_empty()):
			edges.append({"net": n, "conductor": c, "a": points[pair.x], "b": points[pair.y], "width": POWER_W if c == CabinetDevices.Conductor.POWER else WIRE_W})
	wiring._bottom = layout.size.y - CabinetLayout.FRAME
	var cables: Array[Dictionary] = WorkspaceCables.cables(doc)
	# A net going on to another switchboard leaves like a field wire, in the
	# cable between the two (from its first terminal here).
	var onward: Dictionary[int, String] = _board_cables(doc, board, cables)
	for n: int in onward:
		if by_net.has(n) and not cores.has(n):
			var first: Dictionary = by_net[n][0]
			wiring._field.append({"key": first["key"], "at": first["at"], "duct": first["duct"], "up": first["up"], "id": first["id"], "cable": onward[n]})
	wiring._field_cables(edges, net, conductor, _cable_names(doc, board, cables))
	wiring._route(edges)
	wiring._glands()
	return wiring


## A cable out of the bottom of the enclosure for each part outside: its
## gland under the terminals it comes from (sideways where cables would
## meet), two cores to a slot of the bottom duct and a free slot beside it
## (closer together where the duct is short), a core to the field side of
## each terminal. Adds the cores to [param edges].
func _field_cables(edges: Array[Dictionary], net: Dictionary[String, int], conductor: Dictionary[int, CabinetDevices.Conductor], named: Dictionary[String, String]) -> void:
	var cables: Dictionary[String, Array] = {}
	for point: Dictionary in _field:
		var cable: String = point["cable"] if point.has("cable") else named.get(point["field"], "-" + str(point["field"]))
		if not cables.has(cable):
			cables[cable] = []
		cables[cable].append(point)
	# One core for each net in a cable, as the workspace counts them (see
	# [WorkspaceCables]): to the first of its terminals that sits on the lead
	# of a part outside (else the first of them, e.g. one on the lead of a
	# breaker inside); the others on that net are joined to it inside the
	# switchboard.
	for cable: String in cables:
		var points: Array = cables[cable]
		points.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["at"].x < q["at"].x)
		var first: Dictionary[int, int] = {}
		for i: int in points.size():
			var n: int = net[points[i]["key"]]
			if not first.has(n) or (points[i].get("on_lead", false) and not points[first[n]].get("on_lead", false)):
				first[n] = i
		var chosen: Array = first.values()
		chosen.sort()
		var cores: Array = []
		for i: int in chosen:
			cores.append(points[i])
		cables[cable] = cores
	var middle: Callable = func(points: Array) -> float:
		var sum: float = 0.0
		for point: Dictionary in points:
			sum += point["at"].x
		return sum / points.size()
	var order: Array = cables.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return middle.call(cables[a]) < middle.call(cables[b]))
	var d: int = _across.size() - 1
	var duct: Rect2 = _across[d]
	var pitch: float = CabinetParts.DUCT_FINGER + CabinetParts.DUCT_SLOT
	var count: int = CabinetParts.duct_slots(duct.size.x)
	# As much room as the duct has: the gap between cables goes first, then
	# three cores go to a slot.
	var per_slot: int = 2
	var gap: int = 1
	var room: Callable = func(cores: int, between: int) -> int:
		var total: int = between * maxi(order.size() - 1, 0)
		for name: String in order:
			total += ceili(cables[name].size() / float(cores))
		return total
	# The layout makes the plate wide enough for three cores to a slot (see
	# [method bottom_slots]); a cable to another switchboard may still need
	# more to a slot.
	while room.call(per_slot, gap) > count and (gap > 0 or per_slot < 8):
		if gap > 0:
			gap -= 1
		else:
			per_slot += 1
	var free: int = 0
	var id: int = 2000000
	for name: String in order:
		var points: Array = cables[name]
		points.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["at"].x < q["at"].x)
		var need: int = ceili(points.size() / float(per_slot))
		var first: int = roundi((middle.call(points) - duct.position.x - CabinetParts.duct_slot(0)) / pitch - (need - 1) * 0.5)
		# The cables still to come must fit after it.
		var left: int = 0
		for other: String in order.slice(order.find(name)):
			left += ceili(cables[other].size() / float(per_slot)) + gap
		first = clampi(maxi(first, free), 0, maxi(count - (left - gap), free))
		free = first + need + gap
		for i: int in points.size():
			var x: float = duct.position.x + CabinetParts.duct_slot(mini(first + int(i / float(per_slot)), count - 1))
			var core: Dictionary = {"key": name, "at": Vector2(x, _bottom), "duct": d, "up": true, "id": id, "external": true, "cable": name}
			id += 1
			var n: int = net[points[i]["key"]]
			var c: CabinetDevices.Conductor = conductor.get(n, CabinetDevices.Conductor.CONTROL)
			# A PE or N terminal takes the PE or N core, wired or not.
			if points[i].get("kind", "") == "PE":
				c = CabinetDevices.Conductor.PE
			elif points[i].get("kind", "") == "N" and c == CabinetDevices.Conductor.CONTROL:
				c = CabinetDevices.Conductor.NEUTRAL
			edges.append({"net": n, "conductor": c, "a": core, "b": points[i], "width": POWER_W if c == CabinetDevices.Conductor.POWER else WIRE_W})


## Slots of the bottom duct the field cables of switchboard [param board]
## take at least, three cores to a slot (see [method _field_cables]): one
## cable for each station and each part outside the field wires of its
## [param strips] (see [method CabinetDevices.strips]) go to, a core for
## each net. The layout makes the plate wide enough for them.
static func bottom_slots(doc: SchematicDocument, board: int, strips: Dictionary) -> int:
	if board < 0 or board >= doc.switchboards.size():
		return 0
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	# Where the cable goes -> its nets.
	var ends: Dictionary[String, Dictionary] = {}
	for rail: CabinetRail in doc.switchboards[board].rails:
		for item: CabinetItem in rail.items:
			if item.kind != CabinetItem.Kind.STRIP:
				continue
			for terminal: Dictionary in strips.get(item.designation, []):
				for key: String in terminal["keys"]:
					if not net.has(key) or doc.circuit.get_terminal_owner(key) is PowerSupply:
						continue
					var part: String = CabinetDevices.field_device(doc.circuit, key, net)
					if part.is_empty():
						continue
					var station: int = Workspace.station_of(doc, part)
					var to: String = "+" + doc.control_boxes[station].name if station >= 0 else "-" + part
					if not ends.has(to):
						ends[to] = {}
					ends[to][net[key]] = true
	var slots: int = 0
	for to: String in ends:
		slots += ceili(ends[to].size() / 3.0)
	return slots


## Net -> name of the workspace cable it runs in from switchboard
## [param board] to another switchboard ([param cables]: those of
## [method WorkspaceCables.cables]).
static func _board_cables(doc: SchematicDocument, board: int, cables: Array[Dictionary]) -> Dictionary[int, String]:
	var result: Dictionary[int, String] = {}
	if board < 0 or board >= doc.switchboards.size():
		return result
	var here: String = "+" + doc.switchboards[board].name
	var boards: Dictionary[String, bool] = {}
	for other: Switchboard in doc.switchboards:
		boards["+" + other.name] = true
	for cable: Dictionary in cables:
		var other: String = cable["b"] if cable["a"] == here else (cable["a"] if cable["b"] == here else "")
		if boards.has(other):
			for core: Dictionary in cable["cores"]:
				result[core["net"]] = cable["name"]
	return result


## Part outside (designation) -> name of the workspace cable from switchboard
## [param board] to where the part is (its station, itself in the field);
## [param cables]: those of [method WorkspaceCables.cables].
static func _cable_names(doc: SchematicDocument, board: int, cables: Array[Dictionary]) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	if board < 0 or board >= doc.switchboards.size():
		return result
	var here: String = "+" + doc.switchboards[board].name
	var stations: Dictionary[String, PackedStringArray] = {}
	for box: ControlBox in doc.control_boxes:
		var on: PackedStringArray = PackedStringArray()
		for item: ControlBoxItem in box.items:
			for designation: String in [item.designation, item.lamp]:
				if not designation.is_empty():
					on.append(designation)
		stations["+" + box.name] = on
	for cable: Dictionary in cables:
		var other: String = cable["b"] if cable["a"] == here else (cable["a"] if cable["b"] == here else "")
		if other.begins_with("-"):
			result[other.substr(1)] = cable["name"]
		elif stations.has(other):
			for designation: String in stations[other]:
				result[designation] = cable["name"]
	return result


## The cores of the incoming cables: net -> the core feeding it, a point like
## those of [method _terminals] at the top of the enclosure with
## "external" set. Nets of one supply conductor (several supply points of
## L1 on the drawing) are merged in [param by_net] under the first, so one
## core feeds them all; conductors without a terminal on the rails get no
## core.
func _feed(circuit: Circuit, net: Dictionary[String, int], conductor: Dictionary[int, CabinetDevices.Conductor], by_net: Dictionary[int, Array]) -> Dictionary[int, Dictionary]:
	var fed: Dictionary[PowerSupply.Conductor, int] = {}
	var keys: Dictionary[PowerSupply.Conductor, String] = {}
	# Net -> the net it was merged into: supply points of two conductors
	# wired together (a short) join their nets too.
	var merged: Dictionary[int, int] = {}
	var resolve: Callable = func(n: int) -> int:
		while merged.has(n):
			n = merged[n]
		return n
	for c: CircuitComponent in circuit.get_components():
		if not (c is PowerSupply):
			continue
		var supply: PowerSupply = c as PowerSupply
		var n: int = resolve.call(net[supply.get_terminal_keys()[0]])
		if not by_net.has(n):
			continue
		if not fed.has(supply.conductor):
			fed[supply.conductor] = n
			keys[supply.conductor] = supply.get_terminal_keys()[0]
			continue
		var first: int = resolve.call(fed[supply.conductor])
		if first != n:
			# Another supply point of the same conductor: one core feeds both.
			by_net[first].append_array(by_net[n])
			by_net.erase(n)
			merged[n] = first
			if conductor.get(n, CabinetDevices.Conductor.CONTROL) == CabinetDevices.Conductor.POWER:
				conductor[first] = CabinetDevices.Conductor.POWER
	for which: PowerSupply.Conductor in fed:
		fed[which] = resolve.call(fed[which])
	var result: Dictionary[int, Dictionary] = {}
	var top: Rect2 = _across[0]
	var x: float = top.position.x + CabinetParts.duct_slot(0)
	var id: int = 1000000
	for k: int in CORE_ORDER.size():
		var which: PowerSupply.Conductor = CORE_ORDER[k]
		if k == CORE_ORDER.find(PowerSupply.Conductor.DC_PLUS) and not result.is_empty():
			# The DC source has a cable of its own.
			x += 3.0 * (CabinetParts.DUCT_FINGER + CabinetParts.DUCT_SLOT)
		if not fed.has(which) or result.has(fed[which]):
			continue
		result[fed[which]] = {"key": keys[which], "at": Vector2(x, CabinetLayout.FRAME), "duct": 0, "up": false, "id": id, "external": true, "cable": "DC" if k >= CORE_ORDER.find(PowerSupply.Conductor.DC_PLUS) else "AC", "conductor": which}
		x += CORE
		id += 1
	return result


## A gland round the cores of each cable where they come in or go out;
## glands side by side narrower where they would overlap.
func _glands() -> void:
	var spans: Dictionary[String, Vector2] = {}
	var bottom: Dictionary[String, bool] = {}
	for wire: Dictionary in wires:
		if not wire["external"]:
			continue
		var start: Vector2 = (wire["points"] as PackedVector2Array)[0]
		var span: Vector2 = spans.get(wire["cable"], Vector2(INF, -INF))
		spans[wire["cable"]] = Vector2(minf(span.x, start.x), maxf(span.y, start.x))
		bottom[wire["cable"]] = start.y > CabinetLayout.FRAME + 1.0
	var order: Array = spans.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return spans[a].x < spans[b].x)
	# Left and right edge of each gland.
	var edges: Dictionary[String, Vector2] = {}
	for cable: String in order:
		var span: Vector2 = spans[cable]
		var w: float = maxf(span.y - span.x + 2.0 * CORE + 2.0, 12.0)
		edges[cable] = Vector2((span.x + span.y) * 0.5 - w * 0.5, (span.x + span.y) * 0.5 + w * 0.5)
	for i: int in order.size() - 1:
		var a: String = order[i]
		var b: String = order[i + 1]
		if bottom[a] != bottom[b] or edges[a].y + 1.0 <= edges[b].x:
			continue
		# Halfway between their outermost cores.
		var between: float = (spans[a].y + spans[b].x) * 0.5
		edges[a].y = minf(edges[a].y, between - 0.5)
		edges[b].x = maxf(edges[b].x, between + 0.5)
	for cable: String in order:
		var y: float = _bottom - 1.0 if bottom[cable] else 0.0
		glands.append({"rect": Rect2(edges[cable].x, y, edges[cable].y - edges[cable].x, CabinetLayout.FRAME + 1.0), "bottom": bottom[cable], "cable": cable})


## Every terminal on the rails a wire can go to: {"key" (terminal key in
## the circuit), "at" (where the wire ends), "duct" (index of the duct
## across it is led to), "up" (the duct is above it), "id" (its index),
## for a terminal under a contactor with an overload relay "beside" (the
## two together, Rect2), "channel" (room for the wires on both sides),
## "out" (heights to run out to the side at) and "side" (on a block on the
## contactor's side)}.
## A terminal of a strip is one terminal for each net it joins.
func _terminals(layout: CabinetLayout, k: float, net: Dictionary[String, int]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for place: Dictionary in layout.places:
		var rail: int = place["rail"]
		var centre: float = layout.rails[rail].get_center().y
		var origin: Vector2 = place["origin"]
		match place["kind"]:
			CabinetLayout.STRIP:
				var terminals: Array = place["desc"]["terminals"]
				for i: int in terminals.size():
					var at: Vector2 = origin + CabinetParts.strip_entry(i, k)
					var below: Vector2 = origin + CabinetParts.strip_entry(i, k, true)
					var nets: Dictionary[int, bool] = {}
					for key: String in terminals[i]["keys"]:
						if net.has(key) and not nets.has(net[key]):
							nets[net[key]] = true
							result.append({"key": key, "at": at, "duct": rail, "up": true})
							var owner: CircuitComponent = _circuit.get_terminal_owner(key)
							if owner is PowerSupply:
								# The supply comes in on the field side.
								if not _entries.has((owner as PowerSupply).conductor):
									_entries[(owner as PowerSupply).conductor] = {"key": key, "at": below, "duct": rail + 1, "up": false}
								continue
							# The field side: the wire out to the part outside.
							var part: String = CabinetDevices.field_device(_circuit, key, net)
							if not part.is_empty():
								# "on_lead": the terminal sits on the lead of that part (else the part was found on its net).
								_field.append({"key": key, "at": below, "duct": rail + 1, "up": false, "field": part, "kind": terminals[i]["kind"], "on_lead": owner != null and owner.designation == part})
			CabinetLayout.MISSING_DEVICE:
				pass
			_:
				var beside: Rect2 = Rect2()
				if place.has("under_rect"):
					beside = (place["rect"] as Rect2).merge(place["under_rect"])
				_add_device(result, net, place["kind"], place["desc"], origin, rail, centre, beside, place.get("channel", 0.0))
				if place.has("under_origin"):
					_add_device(result, net, CabinetDevices.Kind.OVERLOAD, place["under_desc"], place["under_origin"], rail, centre)
	for i: int in result.size():
		result[i]["id"] = i
	for i: int in _field.size():
		_field[i]["id"] = result.size() + i
	var next: int = result.size() + _field.size()
	for which: PowerSupply.Conductor in _entries:
		_entries[which]["id"] = next
		next += 1
	return result


## Terminals of a device at [param origin] on rail [param rail]; wires from
## its bottom terminals go round [param beside] when it has an area, in
## [param channel] on both sides.
func _add_device(result: Array[Dictionary], net: Dictionary[String, int], kind: int, desc: Dictionary, origin: Vector2, rail: int, centre: float, beside: Rect2 = Rect2(), channel: float = 0.0) -> void:
	var terminals: Dictionary = desc.get("terminals", {})
	var points: Dictionary = CabinetParts.terminal_points(kind, desc)
	# The terminals of a contactor's auxiliary contact block on its front
	# and of those on its sides.
	var block: Dictionary[String, bool] = {}
	var side: Dictionary[String, bool] = {}
	var aux: Array = desc.get("aux", [])
	if kind == CabinetDevices.Kind.CONTACTOR:
		for k: int in range(CabinetParts.AUX_BUILT_IN, aux.size()):
			var on: Dictionary[String, bool] = block if k < CabinetParts.AUX_BUILT_IN + CabinetParts.AUX_FRONT else side
			on[str(aux[k][0])] = true
			on[str(aux[k][2])] = true
	for name: String in points:
		if not terminals.has(name) or not net.has(terminals[name]):
			continue
		var p: Vector3 = points[name]
		var up: bool = origin.y + p.y < centre
		var at: Vector2 = origin + Vector2(p.x, p.y + (-p.z if up else p.z))
		var point: Dictionary = {"key": terminals[name], "at": at, "duct": rail if up else rail + 1, "up": up}
		if not up and beside.has_area():
			var out: Array[float] = []
			for y: float in CabinetParts.CONTACTOR_OUT_Y:
				out.append(origin.y + y)
			point["beside"] = beside
			point["channel"] = channel
			point["out"] = out
			point["side"] = side.has(name)
		elif block.has(name):
			var leads: Dictionary = CabinetParts.aux_block_leads(int(desc.get("poles", 3)), CabinetParts.contactor_left(aux.size()))
			var heights: Vector2 = leads["top" if up else "bottom"]
			point["aside"] = {"x": leads["x"] + Vector2(origin.x, origin.x), "y": heights + Vector2(origin.y, origin.y)}
		result.append(point)


## Pairs of indices into [param points] joining them all along the
## shortest routes (a minimum spanning tree).
## [param single]: the first point gets one wire only (a core of an
## incoming cable goes to one terminal).
func _tree(points: Array, single: bool = false) -> Array[Vector2i]:
	var pairs: Array[Vector2i] = []
	if points.size() < 2:
		return pairs
	var joined: Array[bool] = []
	joined.resize(points.size())
	joined.fill(false)
	joined[0] = true
	var best: Array[float] = []
	var from: Array[int] = []
	for i: int in points.size():
		best.append(_length(points[0], points[i]))
		from.append(0)
	for step: int in points.size() - 1:
		var next: int = -1
		for i: int in points.size():
			if not joined[i] and (next < 0 or best[i] < best[next]):
				next = i
		joined[next] = true
		pairs.append(Vector2i(from[next], next))
		if single and step == 0:
			# Nothing more from the first point: the others are reached
			# from the one it went to.
			for i: int in points.size():
				if not joined[i]:
					best[i] = _length(points[next], points[i])
					from[i] = next
		for i: int in points.size():
			if not joined[i]:
				var d: float = _length(points[next], points[i])
				if d < best[i]:
					best[i] = d
					from[i] = next
	return pairs


## Length of the route between two terminals (near enough to compare).
func _length(a: Dictionary, b: Dictionary) -> float:
	var da: Rect2 = _across[a["duct"]]
	var db: Rect2 = _across[b["duct"]]
	var ax: float = a["at"].x
	var bx: float = b["at"].x
	var drops: float = absf(a["at"].y - da.get_center().y) + absf(b["at"].y - db.get_center().y)
	if a["duct"] == b["duct"]:
		return drops + absf(ax - bx)
	var left: float = _sides[0].get_center().x
	var right: float = _sides[1].get_center().x
	var along: float = minf(ax + bx - 2.0 * left, 2.0 * right - ax - bx)
	return drops + along + absf(da.get_center().y - db.get_center().y)


## Lays the wires of [param edges] through the ducts.
func _route(edges: Array[Dictionary]) -> void:
	# Ends of the wires: side by side where two share a terminal, led
	# through the nearest slots of their ducts, several in one.
	var ends: Array[Dictionary] = []
	var shared: Dictionary[int, int] = {}
	for e: int in edges.size():
		for side: String in ["a", "b"]:
			var point: Dictionary = edges[e][side]
			shared[point["id"]] = shared.get(point["id"], 0) + 1
			ends.append({"edge": e, "side": side, "point": point})
	var used: Dictionary[int, int] = {}
	for end: Dictionary in ends:
		var id: int = end["point"]["id"]
		var index: int = used.get(id, 0)
		used[id] = index + 1
		end["x"] = end["point"]["at"].x + (index - (shared[id] - 1) * 0.5) * SHARED
		end["start"] = Vector2(end["x"], end["point"]["at"].y)
		end["via"] = PackedVector2Array()
	_lead_beside(ends)
	_lead_aside(ends)
	ends.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["x"] < q["x"])
	var pitch: float = CabinetParts.DUCT_FINGER + CabinetParts.DUCT_SLOT
	# Slots by duct, number and side: wires from above and from below go in
	# through the fingers on their own side.
	var slots: Dictionary[Vector3i, Array] = {}
	for end: Dictionary in ends:
		var d: int = end["point"]["duct"]
		var duct: Rect2 = _across[d]
		var count: int = CabinetParts.duct_slots(duct.size.x)
		var along: float = end["x"] - duct.position.x
		# The nearest slot: wires near each other go in through one slot together.
		var slot: int = clampi(roundi((along - CabinetParts.duct_slot(0)) / pitch), 0, count - 1)
		var key: Vector3i = Vector3i(d, slot, 1 if end["point"]["up"] else 0)
		if not slots.has(key):
			slots[key] = []
		slots[key].append(end)
		end["slot"] = duct.position.x + CabinetParts.duct_slot(slot)
	for key: Vector3i in slots:
		var group: Array = slots[key]
		var spread: float = minf(LANE, (CabinetParts.DUCT_SLOT - WIRE_W) / maxf(group.size() - 1, 1))
		for i: int in group.size():
			group[i]["slot"] += (i - (group.size() - 1) * 0.5) * spread
	var by_side: Dictionary = {}
	for end: Dictionary in ends:
		by_side["%d%s" % [end["edge"], end["side"]]] = end
	# Runs along the ducts across: which side duct a wire takes between two
	# ducts, then a lane in every duct it runs along.
	var runs: Array = []
	for i: int in _across.size():
		runs.append([])
	var routes: Array[Dictionary] = []
	for e: int in edges.size():
		var a: Dictionary = by_side["%da" % e]
		var b: Dictionary = by_side["%db" % e]
		var route: Dictionary = {"a": a, "b": b, "da": a["point"]["duct"], "db": b["point"]["duct"]}
		if route["da"] == route["db"]:
			runs[route["da"]].append({"route": route, "lane": "lane_a", "from": minf(a["slot"], b["slot"]), "to": maxf(a["slot"], b["slot"])})
		else:
			var left: bool = a["slot"] + b["slot"] - 2.0 * _sides[0].end.x <= 2.0 * _sides[1].position.x - a["slot"] - b["slot"]
			route["side"] = 0 if left else 1
			var edge: float = _sides[0].end.x if left else _sides[1].position.x
			runs[route["da"]].append({"route": route, "lane": "lane_a", "from": minf(a["slot"], edge), "to": maxf(a["slot"], edge)})
			runs[route["db"]].append({"route": route, "lane": "lane_b", "from": minf(b["slot"], edge), "to": maxf(b["slot"], edge)})
		routes.append(route)
	for d: int in _across.size():
		var r: Rect2 = _across[d]
		var positions: PackedFloat32Array = _lanes(runs[d], r.position.y + CabinetParts.DUCT_DEPTH, r.end.y - CabinetParts.DUCT_DEPTH)
		for i: int in runs[d].size():
			runs[d][i]["route"][runs[d][i]["lane"]] = positions[i]
	for s: int in 2:
		var down: Array = []
		for route: Dictionary in routes:
			if route.get("side", -1) == s:
				down.append({"route": route, "from": minf(route["lane_a"], route["lane_b"]), "to": maxf(route["lane_a"], route["lane_b"])})
		var r: Rect2 = _sides[s]
		var positions: PackedFloat32Array = _lanes(down, r.position.x + CabinetParts.DUCT_DEPTH, r.end.x - CabinetParts.DUCT_DEPTH)
		for i: int in down.size():
			down[i]["route"]["lane_side"] = positions[i]
	for e: int in edges.size():
		var route: Dictionary = routes[e]
		var points: PackedVector2Array = _drop(route["a"], route["lane_a"])
		if route.has("side"):
			points.append(Vector2(route["lane_side"], route["lane_a"]))
			points.append(Vector2(route["lane_side"], route["lane_b"]))
		var back: PackedVector2Array = _drop(route["b"], route["lane_b"] if route.has("side") else route["lane_a"])
		back.reverse()
		points.append_array(back)
		wires.append({
			"net": edges[e]["net"], "conductor": edges[e]["conductor"], "width": edges[e]["width"],
			"points": _clean(points), "from": edges[e]["a"]["key"], "to": edges[e]["b"]["key"],
			"external": edges[e]["a"].get("external", false), "cable": edges[e]["a"].get("cable", ""),
		})


## From a terminal up or down to its duct and in through its slot to the
## lane at [param lane] (y).
func _drop(end: Dictionary, lane: float) -> PackedVector2Array:
	var point: Dictionary = end["point"]
	if point.get("external", false):
		# A core comes straight down from the gland into its slot.
		return PackedVector2Array([Vector2(end["slot"], point["at"].y), Vector2(end["slot"], lane)])
	var duct: Rect2 = _across[point["duct"]]
	var bend: float = duct.end.y + BEND if point["up"] else duct.position.y - BEND
	var points: PackedVector2Array = PackedVector2Array([end["start"]])
	points.append_array(end["via"])
	points.append_array([Vector2(end["x"], bend), Vector2(end["slot"], bend), Vector2(end["slot"], lane)])
	return points


## Leads the wire ends from the bottom terminals of a contactor with an
## overload relay under it out of the way: down to the first height under
## the terminal clear of the contactor's screws, across to the nearer side
## and on down beside the relay. At one height the wire nearest the side
## runs highest; beside the relay the highest runs outermost, so they
## never cross. Wires from the blocks on the contactor's sides cross no
## screws of the contactor: they run above those that do, which keep the
## middle of the height.
func _lead_beside(ends: Array[Dictionary]) -> void:
	var sides: Dictionary[Vector3, Array] = {}
	for end: Dictionary in ends:
		var point: Dictionary = end["point"]
		if not point.has("beside"):
			continue
		var r: Rect2 = point["beside"]
		var right: bool = end["x"] > r.get_center().x
		var out: Array[float] = point["out"]
		var leg: float = out[out.size() - 1]
		for y: float in out:
			if y > point["at"].y + LEG_STEP:
				leg = y
				break
		end["leg"] = leg
		var key: Vector3 = Vector3(r.position.x, r.position.y, 1.0 if right else 0.0)
		if not sides.has(key):
			sides[key] = []
		sides[key].append(end)
	for key: Vector3 in sides:
		var group: Array = sides[key]
		var right: bool = key.z > 0.5
		var r: Rect2 = group[0]["point"]["beside"]
		var edge: float = r.end.x if right else r.position.x
		group.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
			if not is_equal_approx(p["leg"], q["leg"]):
				return p["leg"] < q["leg"]
			return absf(edge - p["x"]) < absf(edge - q["x"]))
		# Wires at each height from the contactor itself and from its side
		# blocks (these come first, being nearer the side).
		var at_height: Dictionary[float, int] = {}
		var from_side: Dictionary[float, int] = {}
		for end: Dictionary in group:
			if end["point"]["side"]:
				from_side[end["leg"]] = from_side.get(end["leg"], 0) + 1
			else:
				at_height[end["leg"]] = at_height.get(end["leg"], 0) + 1
		var placed: Dictionary[float, int] = {}
		var channel: float = group[0]["point"]["channel"]
		var spread: float = minf(LANE, (channel - 1.5) / maxf(group.size() - 1, 1))
		for j: int in group.size():
			var end: Dictionary = group[j]
			var i: int = placed.get(end["leg"], 0) - from_side.get(end["leg"], 0)
			placed[end["leg"]] = placed.get(end["leg"], 0) + 1
			# Side wires (i < 0) above the contactor's, centred when it has none.
			var own: int = at_height.get(end["leg"], 0)
			var middle: float = (own - 1) * 0.5 if own > 0 else -(from_side[end["leg"]] + 1) * 0.5
			var y: float = end["leg"] + (i - middle) * LEG_STEP
			var x: float = edge + (channel - 1.0 - spread * j) * (1.0 if right else -1.0)
			end["via"] = PackedVector2Array([Vector2(end["x"], y), Vector2(x, y)])
			end["x"] = x


## Leads the wire ends from the auxiliary contact block on a contactor's
## front round the contactor's own terminals (see
## [method CabinetParts.aux_block_leads]): to a height between the block and
## the inner tier, out to the left and on along the contactor's left edge.
## The wire from the column nearest that edge runs nearest the block and
## outermost, so they never cross.
func _lead_aside(ends: Array[Dictionary]) -> void:
	var groups: Dictionary[Vector3, Array] = {}
	for end: Dictionary in ends:
		var point: Dictionary = end["point"]
		if not point.has("aside"):
			continue
		var key: Vector3 = Vector3(point["aside"]["x"].x, point["aside"]["y"].x, 1.0 if point["up"] else 0.0)
		if not groups.has(key):
			groups[key] = []
		groups[key].append(end)
	for key: Vector3 in groups:
		var group: Array = groups[key]
		group.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["x"] < q["x"])
		var across: Vector2 = group[0]["point"]["aside"]["x"]
		var heights: Vector2 = group[0]["point"]["aside"]["y"]
		var step_x: float = minf(LANE * 0.6, (across.y - across.x) / maxf(group.size() - 1, 1))
		var step_y: float = (heights.y - heights.x) / maxf(group.size() - 1, 1)
		step_y = signf(step_y) * minf(absf(step_y), LEG_STEP)
		for i: int in group.size():
			var end: Dictionary = group[i]
			var y: float = heights.x + step_y * i
			var x: float = across.x + step_x * i
			end["via"] = PackedVector2Array([Vector2(end["x"], y), Vector2(x, y)])
			end["x"] = x


## Lanes for the [param runs] ({"from", "to"} along one duct) between
## [param low] and [param high] across it: runs that overlap get lanes of
## their own, the lanes spread evenly (closer together when there are many).
## Returns the position of each run's lane.
func _lanes(runs: Array, low: float, high: float) -> PackedFloat32Array:
	var order: Array = range(runs.size())
	order.sort_custom(func(i: int, j: int) -> bool: return runs[i]["from"] < runs[j]["from"])
	var lane_of: PackedInt32Array = PackedInt32Array()
	lane_of.resize(runs.size())
	var lane_end: Array[float] = []
	for i: int in order:
		var lane: int = -1
		for l: int in lane_end.size():
			if lane_end[l] + LANE < runs[i]["from"]:
				lane = l
				break
		if lane < 0:
			lane = lane_end.size()
			lane_end.append(0.0)
		lane_end[lane] = runs[i]["to"]
		lane_of[i] = lane
	var count: int = lane_end.size()
	var pitch: float = minf(LANE, (high - low - WIRE_W) / maxf(count - 1, 1))
	var first: float = (low + high) * 0.5 - pitch * (count - 1) * 0.5
	var result: PackedFloat32Array = PackedFloat32Array()
	for i: int in runs.size():
		result.append(first + pitch * lane_of[i])
	return result


## [param points] without repeated points and without points in the
## middle of a straight run.
static func _clean(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		if not result.is_empty() and result[result.size() - 1].distance_squared_to(point) < 0.0001:
			continue
		if result.size() >= 2:
			var a: Vector2 = result[result.size() - 2]
			var b: Vector2 = result[result.size() - 1]
			if absf((b - a).cross(point - b)) < 0.0001 and (b - a).dot(point - b) > 0.0:
				result[result.size() - 1] = point
				continue
		result.append(point)
	return result
