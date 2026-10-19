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
## Wires sharing a duct lie side by side, in lanes laid so they cross as
## few others as they can (see [method _lanes]). The supply comes in from outside:
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
## way, in the cable between the two. Every wire carries its net's wire
## number on a marker sleeve at each terminal end (the supply conductor's
## name, "L1", "N", "PE", on a net without a number); wires sharing a
## terminal spread out under it, so their sleeves sit side by side. No nodes.

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
## Most wires in one terminal's clamp.
const CLAMP_WIRES: int = 2
## Two or more wires in one terminal spread out right under it, so their
## marker sleeves sit side by side: FAN apart (closer where the next
## terminal is near), aside past the ferrule (FAN_FROM from the terminal),
## before [constant CabinetParts.MARKER_FROM].
const FAN: float = 3.2
const FAN_FROM: float = 2.2
## Least and most room between the bend of a slanting wire and its duct.
const SLANT_MIN: float = 1.5
const SLANT_MAX: float = 6.0
## Room between two marker sleeves one above the other.
const MARKER_SPACE: float = 0.5

## The wires: {"net": int, "conductor": [enum CabinetDevices.Conductor],
## "width": float, "points": PackedVector2Array (mm, from one terminal to
## the other; from where it comes out under an overload relay for a wire
## going down behind it), "from", "to" (terminal keys in the circuit; for a core of a
## cable "from" names the cable), "external" (true for a core of a cable:
## it starts at the gland), "cable" ("AC", "DC", or what is written on a
## field cable: the workspace cable's name, "-SB1" for a part without a place),
## "mark" (what its marker sleeves say: the wire number, else the supply
## conductor's name, else ""), "pins" (Vector2: how much of the ferrule
## shows at its first and its last end, see [method CabinetParts.wire]),
## "markers" (its marker sleeves, each as
## PackedVector2Array [from, to] in mm along the wire; see [method _markers])}.
var wires: Array[Dictionary] = []
## Cable glands (mm): {"rect", "bottom" (in the bottom of the enclosure,
## a field cable going out; else the supply coming in at the top),
## "cable"}.
var glands: Array[Dictionary] = []
## Wires side by side at the busiest point of each duct, in the order of
## [member CabinetLayout.ducts] (across from the top, then down the left and
## the right side).
var lanes: Array[int] = []

# Field side of the strip terminals leading to parts outside, like the
# points of [method _terminals] with "field" (the part).
var _field: Array[Dictionary] = []
# Field side of the strip terminals on the leads of supply points, where the
# incoming cores land: conductor -> point like those of [method _terminals].
var _entries: Dictionary[PowerSupply.Conductor, Dictionary] = {}
# Where the cores of the field cables leave the plate (mm from its top).
var _bottom: float = 0.0
# Every screw of the devices on the rails, wired or not: centre and radius
# (mm) as x, y, z.
var _screws: Array[Vector3] = []
# Columns under overload relays taken by wires coming out from behind them.
var _behind_taken: Dictionary[float, bool] = {}

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
	var cables: Array[Dictionary] = WorkspaceCables.cables(doc)
	# A net going on to another switchboard leaves like a field wire, in the
	# cable between the two (from its first terminal here, which keeps room
	# in its clamp for it).
	var onward: Dictionary[int, String] = _board_cables(doc, board, cables)
	for n: int in onward:
		if by_net.has(n) and not cores.has(n):
			by_net[n][0]["taken"] = 1
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
			if _bridged(points[pair.x], points[pair.y]):
				# A plug-in bridge joins them, no wire.
				continue
			edges.append({"net": n, "conductor": c, "a": points[pair.x], "b": points[pair.y], "width": POWER_W if c == CabinetDevices.Conductor.POWER else WIRE_W})
	wiring._bottom = layout.size.y - CabinetLayout.FRAME
	for n: int in onward:
		if by_net.has(n) and not cores.has(n):
			var first: Dictionary = by_net[n][0]
			wiring._field.append({"key": first["key"], "at": first["at"], "duct": first["duct"], "up": first["up"], "id": first["id"], "cable": onward[n]})
	wiring._field_cables(edges, net, conductor, _cable_names(doc, board, cables))
	var marks: Dictionary[int, String] = _marks(doc, net)
	for edge: Dictionary in edges:
		edge["mark"] = marks.get(edge["net"], "")
	wiring._route(edges)
	wiring._glands()
	return wiring


## What the marker sleeves of each net say: its wire number, else the name
## of the supply conductor on it ("L1", "N", "PE", "+").
static func _marks(doc: SchematicDocument, net: Dictionary[String, int]) -> Dictionary[int, String]:
	var marks: Dictionary[int, String] = WorkspaceCables.wire_numbers(doc, net)
	for c: CircuitComponent in doc.circuit.get_components():
		if not (c is PowerSupply):
			continue
		var n: int = net.get(c.get_terminal_keys()[0], -1)
		if n >= 0 and not marks.has(n):
			marks[n] = (c as PowerSupply).conductor_name()
	return marks


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
	# The cores of a cable, as the workspace counts them (see
	# [WorkspaceCables]): one to each terminal on the lead of a part outside
	# where a net has two or more, else one for the net, to the first of its
	# terminals that sits on such a lead (else the first of them, e.g. one on
	# the lead of a breaker inside); the others on that net are joined to it
	# inside the switchboard.
	for cable: String in cables:
		var points: Array = cables[cable]
		points.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["at"].x < q["at"].x)
		var first: Dictionary[int, int] = {}
		var leads: Dictionary[int, Array] = {}
		for i: int in points.size():
			var n: int = net[points[i]["key"]]
			if points[i].get("on_lead", false):
				if not leads.has(n):
					leads[n] = []
				leads[n].append(i)
			if not first.has(n) or (points[i].get("on_lead", false) and not points[first[n]].get("on_lead", false)):
				first[n] = i
		var chosen: Array = []
		for n: int in first:
			if leads.has(n) and leads[n].size() >= 2:
				chosen.append_array(leads[n])
			else:
				chosen.append(first[n])
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
			# One on the same strip terminal is the same point: no wire from
			# the terminal back into itself.
			for point: Dictionary in by_net[n]:
				if not by_net[first].any(func(p: Dictionary) -> bool: return p["at"] == point["at"] and p["up"] == point["up"]):
					by_net[first].append(point)
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
	for p: int in layout.places.size():
		var place: Dictionary = layout.places[p]
		var rail: int = place["rail"]
		var centre: float = layout.rails[rail].get_center().y
		var origin: Vector2 = place["origin"]
		match place["kind"]:
			CabinetLayout.STRIP:
				var terminals: Array = place["desc"]["terminals"]
				var bridges: Array = place["desc"].get("bridges", [])
				var run: int = 0
				for i: int in terminals.size():
					if i == 0 or not (i - 1 < bridges.size() and bridges[i - 1]):
						run = i
					var at: Vector2 = origin + CabinetParts.strip_entry(i, k)
					var below: Vector2 = origin + CabinetParts.strip_entry(i, k, true)
					var nets: Dictionary[int, bool] = {}
					for key: String in terminals[i]["keys"]:
						if net.has(key) and not nets.has(net[key]):
							nets[net[key]] = true
							result.append({"key": key, "at": at, "duct": rail, "up": true, "bridge": p * 1000 + run})
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
				_add_device(result, net, place["kind"], place["desc"], origin, rail, centre, beside, place.get("channel", 0.0), place.get("under_rect", Rect2()))
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
func _add_device(result: Array[Dictionary], net: Dictionary[String, int], kind: int, desc: Dictionary, origin: Vector2, rail: int, centre: float, beside: Rect2 = Rect2(), channel: float = 0.0, relay: Rect2 = Rect2()) -> void:
	var terminals: Dictionary = desc.get("terminals", {})
	var points: Dictionary = CabinetParts.terminal_points(kind, desc)
	# The terminals of the auxiliary contact blocks on a contactor's sides.
	var side: Dictionary[String, bool] = {}
	var aux: Array = desc.get("aux", [])
	if kind == CabinetDevices.Kind.CONTACTOR:
		for k: int in range(CabinetParts.AUX_BUILT_IN + CabinetParts.AUX_FRONT, aux.size()):
			side[str(aux[k][0])] = true
			side[str(aux[k][2])] = true
	for name: String in points:
		var p: Vector3 = points[name]
		_screws.append(Vector3(origin.x + p.x, origin.y + p.y, p.z))
		if not terminals.has(name) or not net.has(terminals[name]):
			continue
		var up: bool = origin.y + p.y < centre
		# Into the face of the terminal's tier, else at the edge of its screw.
		var entry: float = CabinetParts.wire_entry(kind, desc, name, up)
		if not up and relay.has_area() and entry > CabinetParts.CONTACTOR_OUT_Y[CabinetParts.CONTACTOR_OUT_Y.size() - 1] - LEG_STEP:
			# The overload relay under the contactor covers that face (its
			# heaters' pins are in these terminals): the wire goes down behind
			# the relay and comes out under it in a column of its own, between
			# the relay's terminals.
			var x: float = _behind_column(relay, origin.x + p.x)
			result.append({"key": terminals[name], "at": Vector2(x, relay.end.y), "duct": rail + 1, "up": false, "behind": true})
			continue
		var at: Vector2 = origin + Vector2(p.x, p.y + (-p.z if up else p.z) if is_nan(entry) else entry)
		var point: Dictionary = {"key": terminals[name], "at": at, "duct": rail if up else rail + 1, "up": up, "clamp": true}
		if not up and beside.has_area():
			var out: Array[float] = []
			for y: float in CabinetParts.CONTACTOR_OUT_Y:
				out.append(origin.y + y)
			point["beside"] = beside
			point["channel"] = channel
			point["out"] = out
			point["side"] = side.has(name)
		result.append(point)


## Column (mm) a wire coming down behind overload relay [param relay] at
## [param x] comes out under it in: the middle between two of the relay's
## terminal columns nearest [param x] that no other wire took.
func _behind_column(relay: Rect2, x: float) -> float:
	var columns: Array[float] = []
	columns.append_array(CabinetParts.OVERLOAD_OUT_X)
	columns.append_array(CabinetParts.OVERLOAD_AUX_X)
	columns.sort()
	var best: float = NAN
	for i: int in columns.size() - 1:
		var mid: float = relay.position.x + (columns[i] + columns[i + 1]) * 0.5
		if _behind_taken.has(mid):
			continue
		if is_nan(best) or absf(mid - x) < absf(best - x):
			best = mid
	if is_nan(best):
		return x
	_behind_taken[best] = true
	return best


## Pairs of indices into [param points] joining them all along the
## shortest routes (a minimum spanning tree) with at most CLAMP_WIRES wires
## in any terminal's clamp, so nets are looped from terminal to terminal
## where they would branch; terminals a plug-in bridge joins take no wire
## between them. [param single]: the first point gets one wire only (a core
## of an incoming cable goes to one terminal).
func _tree(points: Array, single: bool = false) -> Array[Vector2i]:
	var pairs: Array[Vector2i] = []
	if points.size() < 2:
		return pairs
	var room: Array[int] = []
	for i: int in points.size():
		# Less a wire out to another switchboard from it.
		room.append(CLAMP_WIRES - int(points[i].get("taken", 0)))
	if single:
		room[0] = 1
	var joined: Array[bool] = []
	joined.resize(points.size())
	joined.fill(false)
	joined[0] = true
	for step: int in points.size() - 1:
		# The shortest way from a terminal with room in its clamp to one not
		# yet joined (a bridge needs no room).
		var best: float = INF
		var pair: Vector2i = Vector2i(-1, -1)
		for j: int in points.size():
			if not joined[j]:
				continue
			for i: int in points.size():
				if joined[i]:
					continue
				var bridged: bool = _bridged(points[j], points[i])
				if not bridged and (room[j] <= 0 or room[i] <= 0):
					continue
				var d: float = _length(points[j], points[i])
				if d < best:
					best = d
					pair = Vector2i(j, i)
		if pair.x < 0:
			break
		joined[pair.y] = true
		if not _bridged(points[pair.x], points[pair.y]):
			room[pair.x] -= 1
			room[pair.y] -= 1
		pairs.append(pair)
	return pairs


## Which neighbouring terminals of a strip ([param terminals] as in
## [method CabinetDevices.strips]) a plug-in bridge joins: element i is true
## when terminal i and the next are on the same net of [param net].
static func strip_bridges(terminals: Array, net: Dictionary[String, int]) -> Array[bool]:
	var result: Array[bool] = []
	var nets: Array[int] = []
	for t: Dictionary in terminals:
		var n: int = -1
		for key: String in t["keys"]:
			if net.has(key):
				n = net[key]
				break
		nets.append(n)
	for i: int in maxi(terminals.size() - 1, 0):
		result.append(nets[i] >= 0 and nets[i] == nets[i + 1])
	return result


## Whether points [param a] and [param b] (of [method _terminals]) are tops
## of strip terminals one plug-in bridge joins.
static func _bridged(a: Dictionary, b: Dictionary) -> bool:
	return a.get("bridge", -1) >= 0 and a.get("bridge", -1) == b.get("bridge", -1)


## Length of the route between two terminals (near enough to compare); none
## between terminals a plug-in bridge joins.
func _length(a: Dictionary, b: Dictionary) -> float:
	if _bridged(a, b):
		return 0.0
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
			ends.append({"edge": e, "side": side, "point": point, "sleeve": CabinetParts.marker_length(edges[e]["mark"]) if not str(edges[e]["mark"]).is_empty() else 0.0})
	var used: Dictionary[int, int] = {}
	for end: Dictionary in ends:
		var id: int = end["point"]["id"]
		var index: int = used.get(id, 0)
		used[id] = index + 1
		end["index"] = index
		end["shared"] = shared[id]
		end["x"] = end["point"]["at"].x + (index - (shared[id] - 1) * 0.5) * SHARED
		end["start"] = Vector2(end["x"], end["point"]["at"].y)
		end["via"] = PackedVector2Array()
	_lead_beside(ends)
	_fan(ends, shared)
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
	_slants(ends)
	var by_side: Dictionary = {}
	for end: Dictionary in ends:
		by_side["%d%s" % [end["edge"], end["side"]]] = end
	# Runs along the ducts across: which side duct a wire takes between two
	# ducts, then a lane in every duct it runs along.
	var runs: Array = []
	for i: int in _across.size():
		runs.append([])
	var routes: Array[Dictionary] = []
	var reaches: Array[Vector2] = []
	for e: int in edges.size():
		var a: Dictionary = by_side["%da" % e]
		var b: Dictionary = by_side["%db" % e]
		var route: Dictionary = {"a": a, "b": b, "da": a["point"]["duct"], "db": b["point"]["duct"]}
		if route["da"] == route["db"]:
			runs[route["da"]].append({"route": route, "lane": "lane_a", "from": minf(a["slot"], b["slot"]), "to": maxf(a["slot"], b["slot"]), "edge": _edge([a, b]), "in": b["slot"] if a["point"]["up"] else a["slot"]})
		else:
			var left: bool = a["slot"] + b["slot"] - 2.0 * _sides[0].end.x <= 2.0 * _sides[1].position.x - a["slot"] - b["slot"]
			route["side"] = 0 if left else 1
			var edge: float = _sides[0].end.x if left else _sides[1].position.x
			runs[route["da"]].append({"route": route, "lane": "lane_a", "from": minf(a["slot"], edge), "to": maxf(a["slot"], edge), "edge": _edge([a])})
			runs[route["db"]].append({"route": route, "lane": "lane_b", "from": minf(b["slot"], edge), "to": maxf(b["slot"], edge), "edge": _edge([b])})
		routes.append(route)
	for d: int in _across.size():
		var r: Rect2 = _across[d]
		var positions: PackedFloat32Array = _lanes(runs[d], r.position.y + CabinetParts.DUCT_DEPTH, r.end.y - CabinetParts.DUCT_DEPTH, lanes)
		for i: int in runs[d].size():
			runs[d][i]["route"][runs[d][i]["lane"]] = positions[i]
	for s: int in 2:
		var down: Array = []
		for route: Dictionary in routes:
			if route.get("side", -1) == s:
				# The wires come in from the plate's side of the duct.
				down.append({"route": route, "from": minf(route["lane_a"], route["lane_b"]), "to": maxf(route["lane_a"], route["lane_b"]), "edge": 1 if s == 0 else -1})
		var r: Rect2 = _sides[s]
		var positions: PackedFloat32Array = _lanes(down, r.position.x + CabinetParts.DUCT_DEPTH, r.end.x - CabinetParts.DUCT_DEPTH, lanes)
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
			"mark": edges[e]["mark"], "pins": Vector2(_pin(route["a"]), _pin(route["b"])),
		})
		reaches.append(Vector2(_reach(route["a"]), _reach(route["b"])))
	_markers(reaches)


## Spreads the wires of a terminal that has [param shared] (terminal id ->
## wires) two or more apart right under it: in the terminal side by side,
## out past the ferrule, then aside to a place of its own (a short jog),
## FAN apart or as
## far as the room to the next terminal in the row and the screws on their
## way to the duct allow, so the marker sleeves sit side by side. Wires led
## round a contactor already go their own ways.
func _fan(ends: Array[Dictionary], shared: Dictionary[int, int]) -> void:
	var steps: Dictionary[int, float] = {}
	for end: Dictionary in ends:
		var point: Dictionary = end["point"]
		var count: int = shared[point["id"]]
		if count < 2 or not end["via"].is_empty() or point.get("external", false):
			continue
		if not steps.has(point["id"]):
			steps[point["id"]] = _fan_step(point, count, ends)
		var at: Vector2 = point["at"]
		var away: float = -1.0 if point["up"] else 1.0
		var x: float = at.x + (end["index"] - (count - 1) * 0.5) * steps[point["id"]]
		if point.get("clamp", false):
			# A device terminal's clamp takes them side by side, each ferrule in.
			end["x"] = x
			end["start"] = Vector2(x, at.y)
			continue
		end["via"] = PackedVector2Array([Vector2(end["x"], at.y + away * FAN_FROM), Vector2(x, at.y + away * FAN_FROM)])
		end["x"] = x


## Places the marker sleeves of every wire (its "markers"): one at each end
## leading to a terminal (none where a core comes out of its cable),
## [constant CabinetParts.MARKER_FROM] from the end, else on the first
## straight stretch long enough after it, clear of the bends (as
## [method CabinetParts.wire] rounds them) and before the wire bends into
## its duct ([param reaches]: how far each wire runs from its first and its
## last terminal before that), so a sleeve never sits in a duct. A sleeve
## that would cover another one moves on along its wire by its length (two
## wires in a terminal too narrow to have them side by side: one above the
## other, in a row of such terminals by turns); one with nowhere else to go
## stays where it was first put. An end without
## room for its sleeve has none.
func _markers(reaches: Array[Vector2]) -> void:
	var placed: Array[Rect2] = []
	for w: int in wires.size():
		var wire: Dictionary = wires[w]
		var markers: Array[PackedVector2Array] = []
		wire["markers"] = markers
		if str(wire["mark"]).is_empty():
			continue
		var length: float = CabinetParts.marker_length(wire["mark"])
		var thick: float = wire["width"] + CabinetParts.MARKER_GROW
		for end: int in range(1 if wire["external"] else 0, 2):
			var path: PackedVector2Array = (wire["points"] as PackedVector2Array).duplicate()
			if end == 1:
				path.reverse()
			var limit: float = (reaches[w].x if end == 0 else reaches[w].y) - wire["width"] * 1.6
			var span: PackedVector2Array = _marker_span(path, CabinetParts.MARKER_FROM, length, wire["width"] * 1.6, limit)
			var free: PackedVector2Array = span
			var from: float = CabinetParts.MARKER_FROM
			while not free.is_empty() and _covers(free, thick, placed):
				# On past where it came to lie.
				from = _distance_to(path, free[1]) + MARKER_SPACE
				free = _marker_span(path, from, length, wire["width"] * 1.6, limit)
			if not free.is_empty():
				span = free
			if not span.is_empty():
				markers.append(span)
				placed.append(_outline(span, thick))


## The first straight stretch [param length] long along [param path] from
## [param from] on, clear of the bends rounded off at [param radius] and
## ending before [param limit] (mm along the path), as [from, to]; empty
## for none.
static func _marker_span(path: PackedVector2Array, from: float, length: float, radius: float, limit: float) -> PackedVector2Array:
	var walked: float = 0.0
	for i: int in path.size() - 1:
		if walked >= limit:
			break
		var leg: float = path[i].distance_to(path[i + 1])
		var low: float = maxf(from, walked + _bend_radius(path, i, radius))
		var high: float = minf(limit, walked + leg - _bend_radius(path, i + 1, radius))
		if high - low >= length:
			return PackedVector2Array([_point_along(path, low), _point_along(path, low + length)])
		walked += leg
	return PackedVector2Array()


## Radius of the bend at point [param i] of [param path] as
## [method CabinetParts.wire] rounds it off ([param radius], less where the
## legs are short); 0 at the ends.
static func _bend_radius(path: PackedVector2Array, i: int, radius: float) -> float:
	if i <= 0 or i >= path.size() - 1:
		return 0.0
	return minf(radius, minf(path[i - 1].distance_to(path[i]), path[i].distance_to(path[i + 1])) * 0.5)


## How far along [param path] its point [param at] lies (mm).
static func _distance_to(path: PackedVector2Array, at: Vector2) -> float:
	var walked: float = 0.0
	for i: int in path.size() - 1:
		var leg: float = path[i].distance_to(path[i + 1])
		var on: Vector2 = Geometry2D.get_closest_point_to_segment(at, path[i], path[i + 1])
		if on.distance_to(at) < 0.001:
			return walked + path[i].distance_to(on)
		walked += leg
	return walked


## The point [param distance] mm along [param path].
static func _point_along(path: PackedVector2Array, distance: float) -> Vector2:
	for i: int in path.size() - 1:
		var leg: float = path[i].distance_to(path[i + 1])
		if distance <= leg:
			return path[i].lerp(path[i + 1], distance / leg) if leg > 0.0 else path[i]
		distance -= leg
	return path[path.size() - 1]


## Outline of a sleeve [param thick] mm thick along [param span] (lying or
## standing).
static func _outline(span: PackedVector2Array, thick: float) -> Rect2:
	var r: Rect2 = Rect2(span[0], Vector2.ZERO).expand(span[1])
	return r.grow_individual(thick * 0.5, 0.0, thick * 0.5, 0.0) if r.size.x < r.size.y else r.grow_individual(0.0, thick * 0.5, 0.0, thick * 0.5)


## Whether a sleeve [param thick] mm thick along [param span] covers one of
## the sleeves [param placed] (their outlines).
static func _covers(span: PackedVector2Array, thick: float, placed: Array[Rect2]) -> bool:
	var outline: Rect2 = _outline(span, thick).grow(-0.05)
	for other: Rect2 in placed:
		if outline.intersects(other):
			return true
	return false


## How far apart the [param count] wires of the terminal at [param point]
## spread (see [method _fan]): FAN, less for the next terminal in the row
## ([param ends]) and for screws on their way to the duct; SHARED for no
## room.
func _fan_step(point: Dictionary, count: int, ends: Array[Dictionary]) -> float:
	var at: Vector2 = point["at"]
	var step: float = FAN
	for other: Dictionary in ends:
		var next: Dictionary = other["point"]
		if next["id"] != point["id"] and next["up"] == point["up"] and absf(next["at"].y - at.y) < FAN:
			step = minf(step, absf(next["at"].x - at.x) / count)
	var duct: Rect2 = _across[point["duct"]]
	var way: float = absf((duct.end.y + BEND if point["up"] else duct.position.y - BEND) - at.y)
	var away: float = -1.0 if point["up"] else 1.0
	var in_way: Array[Vector3] = []
	for screw: Vector3 in _screws:
		var ahead: float = (screw.y - at.y) * away
		if absf(screw.x - at.x) < 0.01 and ahead <= 0.0:
			# The terminal's own.
			continue
		# Ahead of the terminal, also one standing over the face it goes in at.
		if ahead > -screw.z and ahead < way + screw.z:
			in_way.append(screw)
	var hits: Callable = func(spread: float, screw: Vector3) -> bool:
		for i: int in count:
			if absf(at.x + (i - (count - 1) * 0.5) * spread - screw.x) < screw.z + POWER_W * 0.5:
				return true
		return false
	while step > SHARED:
		var clear: bool = true
		for screw: Vector3 in in_way:
			if hits.call(step, screw):
				clear = false
				break
		if clear:
			return step
		step -= 0.1
	return SHARED


## How much of the ferrule shows at [param end] (one of the ends of
## [method _route]): none where it goes all the way into a device
## terminal's clamp, a little going into a strip terminal's opening; -1
## where the wire comes out from behind an overload relay (no ferrule).
static func _pin(end: Dictionary) -> float:
	if end["point"].get("behind", false):
		return -1.0
	return 0.0 if end["point"].get("clamp", false) else CabinetParts.FERRULE


## How far a wire runs from its terminal at [param end] (one of the ends of
## [method _route]) to the bend into its duct; 0 for a core coming out of a
## cable.
func _reach(end: Dictionary) -> float:
	var point: Dictionary = end["point"]
	if point.get("external", false):
		return 0.0
	var duct: Rect2 = _across[point["duct"]]
	var path: PackedVector2Array = PackedVector2Array([end["start"]])
	path.append_array(end["via"])
	var slant: float = _slant_from(end)
	path.append(Vector2(end["x"], (duct.end.y + BEND if point["up"] else duct.position.y - BEND) if is_nan(slant) else slant))
	var length: float = 0.0
	for i: int in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	return length


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
	var slant: float = _slant_from(end)
	if not is_nan(slant):
		var edge: float = duct.end.y if point["up"] else duct.position.y
		points.append_array([Vector2(end["x"], slant), Vector2(end["slot"], edge), Vector2(end["slot"], lane)])
		return points
	points.append_array([Vector2(end["x"], bend), Vector2(end["slot"], bend), Vector2(end["slot"], lane)])
	return points


## Where the wire at [param end] bends towards its slot (see
## [method _slants]); NAN for none (a core coming straight from its gland).
func _slant_from(end: Dictionary) -> float:
	return end.get("slant", NAN)


## Sets where each of the wire [param ends] (of [method _route], in their
## slots) bends once to slant straight into its slot: just past its marker
## sleeve and the bend's rounding, at most SLANT_MAX before the duct. Wires
## whose slants would lie side by side bend at one height, the latest any of
## them needs, so with the slots
## taking the wires in the order of their terminals no slant crosses
## another (wires heading apart cross in the duct, out of sight).
func _slants(ends: Array[Dictionary]) -> void:
	var sides: Dictionary[Vector2i, Array] = {}
	for end: Dictionary in ends:
		var point: Dictionary = end["point"]
		if point.get("external", false):
			continue
		var key: Vector2i = Vector2i(point["duct"], 1 if point["up"] else 0)
		if not sides.has(key):
			sides[key] = []
		sides[key].append(end)
	for key: Vector2i in sides:
		var group: Array = sides[key]
		var up: bool = key.y == 1
		var away: float = -1.0 if up else 1.0
		var duct: Rect2 = _across[key.x]
		var edge: float = duct.end.y if up else duct.position.y
		group.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return minf(p["x"], p["slot"]) < minf(q["x"], q["slot"]))
		var cluster: Array = []
		var reach: float = -INF
		for n: int in group.size() + 1:
			var end: Dictionary = group[n] if n < group.size() else {}
			if n < group.size() and (cluster.is_empty() or minf(end["x"], end["slot"]) <= reach + LANE):
				cluster.append(end)
				reach = maxf(reach, maxf(end["x"], end["slot"]))
				continue
			# The latest height any of them needs: past its sleeve (two rows
			# where wires share a strip terminal too narrow for them side by
			# side, or run close beside an overload relay) and the bend's
			# rounding, also when it comes after a jog.
			var y: float = edge - away * INF
			var slope: float = 0.0
			for c: Dictionary in cluster:
				var narrow: bool = (c["shared"] > 1 and not c["point"].get("clamp", false)) or c["point"].has("beside")
				var rows: int = 2 if narrow else 1
				var sleeves: float = rows * (c["sleeve"] + MARKER_SPACE)
				var need: float = c["start"].y + away * (CabinetParts.MARKER_FROM + sleeves + POWER_W * 1.6 + 0.5)
				if not c["via"].is_empty():
					var last: Vector2 = c["via"][c["via"].size() - 1]
					var after: float = last.y + away * (sleeves + 2.0 * POWER_W * 1.6 + 0.5)
					need = minf(need, after) if up else maxf(need, after)
				y = minf(y, need) if up else maxf(y, need)
				slope = maxf(slope, absf(c["slot"] - c["x"]) * 0.5)
			# Late, a short slant into the slot, where the wires have room.
			y = maxf(y, edge - SLANT_MAX) if not up else minf(y, edge + SLANT_MAX)
			# Without room to slant: the two short turns by the duct.
			var slanted: bool = (edge - y) * away >= maxf(SLANT_MIN, slope)
			for c: Dictionary in cluster:
				c["slant"] = y if slanted else NAN
			cluster = [end] if n < group.size() else []
			reach = maxf(end["x"], end["slot"]) if n < group.size() else -INF


## Whether a wire straight from [param a] to [param b] passes over no screw
## (the one of the terminal it starts at, behind its start, aside).
func _clear(a: Vector2, b: Vector2) -> bool:
	for screw: Vector3 in _screws:
		var at: Vector2 = Vector2(screw.x, screw.y)
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b)) < screw.z + POWER_W * 0.5 and at.distance_to(a) > screw.z + 0.01:
			return false
	return true


## Leads the wire ends from the bottom terminals of a contactor with an
## overload relay under it out of the way: straight down as far as it goes
## without passing over a screw on its way down or across (to the lowest of
## the heights clear of the contactor's screws, just over the relay, where it
## can), across to the nearer side
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
		var first: bool = true
		for y: float in out:
			if y <= point["at"].y + LEG_STEP:
				continue
			# The first height under the terminal, on down while the way is
			# clear (a side block's wires, stacked over the others at their
			# height, stay at the first).
			var down: bool = _clear(Vector2(end["x"], point["at"].y), Vector2(end["x"], y))
			var across: bool = _clear(Vector2(end["x"], y), Vector2(r.end.x if right else r.position.x, y))
			if not first and (point["side"] or not (down and across)):
				break
			leg = y
			first = false
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


## Which edge of its duct across the wire ends [param ends] (of
## [method _route]) come in over: -1 all over the top (from parts above
## it, or the supply from the gland), 1 all over the bottom, 0 both.
static func _edge(ends: Array) -> int:
	var from_below: int = 0
	for end: Dictionary in ends:
		if end["point"]["up"]:
			from_below += 1
	return 1 if from_below == ends.size() else (-1 if from_below == 0 else 0)


## Lanes for the [param runs] ({"from", "to" along one duct, "edge" (see
## [method _edge]): the edge their wires come in over, -1 the low one, 1 the
## high one, 0 both, then "in": where it comes in over the low edge}) between
## [param low] and [param high] across it, laid so the wires are easy to
## follow, crossing as few others as they can: runs coming in over one edge
## lie nearest it, a run nested in another nearer the edge than that one;
## runs coming in over both edges between them, those heading the same way
## stepped so they do not cross (the one coming in further along its way
## nearer the low edge). Each run lies past every run before it that it
## overlaps, runs that do not overlap share a lane. Appends the number of
## lanes to [param counts]; returns the position of each run's lane.
func _lanes(runs: Array, low: float, high: float, counts: Array[int]) -> PackedFloat32Array:
	var groups: Array = [[], [], []]
	for i: int in runs.size():
		groups[int(runs[i].get("edge", 0)) + 1].append(i)
	var lane_of: PackedInt32Array = PackedInt32Array()
	lane_of.resize(runs.size())
	var sizes: Array[int] = []
	for g: int in 3:
		var order: Array = groups[g]
		if g == 1:
			# Heading right (coming in over the low edge at "from") first, the
			# one coming in furthest right first; then heading left, the one
			# coming in furthest left first.
			order.sort_custom(func(i: int, j: int) -> bool:
				var right_i: bool = is_equal_approx(runs[i]["in"], runs[i]["from"])
				var right_j: bool = is_equal_approx(runs[j]["in"], runs[j]["from"])
				if right_i != right_j:
					return right_i
				return runs[i]["in"] > runs[j]["in"] if right_i else runs[i]["in"] < runs[j]["in"])
		else:
			# The shortest first: a run nested in another lies nearer the edge.
			order.sort_custom(func(i: int, j: int) -> bool:
				var a: float = runs[i]["to"] - runs[i]["from"]
				var b: float = runs[j]["to"] - runs[j]["from"]
				return a < b if not is_equal_approx(a, b) else runs[i]["from"] < runs[j]["from"])
		var count: int = 0
		for n: int in order.size():
			var i: int = order[n]
			var lane: int = 0
			for m: int in n:
				var j: int = order[m]
				if runs[i]["from"] <= runs[j]["to"] + LANE and runs[i]["to"] >= runs[j]["from"] - LANE:
					lane = maxi(lane, lane_of[j] + 1)
			lane_of[i] = lane
			count = maxi(count, lane + 1)
		sizes.append(count)
	var total: int = sizes[0] + sizes[1] + sizes[2]
	counts.append(total)
	var pitch: float = minf(LANE, (high - low - WIRE_W) / maxf(total - 1, 1))
	var first: float = (low + high) * 0.5 - pitch * (total - 1) * 0.5
	var result: PackedFloat32Array = PackedFloat32Array()
	for i: int in runs.size():
		var g: int = int(runs[i].get("edge", 0)) + 1
		# From the low edge: its runs, the middle ones, the high edge's last.
		var place: int = lane_of[i] if g == 0 else (sizes[0] + lane_of[i] if g == 1 else total - 1 - lane_of[i])
		result.append(first + pitch * place)
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
