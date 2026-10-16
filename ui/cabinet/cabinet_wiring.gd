class_name CabinetWiring
extends RefCounted
## The wires of the switchboard (rozvaděč), in millimetres on a
## [CabinetLayout]: every net of the circuit that reaches two or more
## terminals on the rails is wired terminal to terminal along the shortest
## tree joining them. A wire leaves its terminal straight to the duct over
## or under its rail, goes in through the nearest slot between the duct's
## fingers, runs along the duct (down a side duct to reach another duct)
## and comes out to the other terminal the same way. Wires sharing a duct
## lie side by side. The colour follows the conductor of the net
## ([method CabinetDevices.conductors]). No nodes.

## Room between a duct and the bend into its slot.
const BEND: float = 2.0
## Thickness of a control wire and of a power wire.
const WIRE_W: float = 1.6
const POWER_W: float = 2.0
## Room a wire takes in a duct and in a slot.
const LANE: float = 2.2
## Most wires led through one slot.
const SLOT_WIRES: int = 2
## Room between two wires in one terminal.
const SHARED: float = 0.9

## The wires: {"net": int, "conductor": [enum CabinetDevices.Conductor],
## "width": float, "points": PackedVector2Array (mm, from one terminal to
## the other), "from", "to" (terminal keys in the circuit)}.
var wires: Array[Dictionary] = []

# Ducts across (top to bottom) and down the sides (left, right).
var _across: Array[Rect2] = []
var _sides: Array[Rect2] = []


## Wires of [param doc] laid out on [param layout] ([param k]: pixels per
## mm the terminal strips are drawn at).
static func build(doc: SchematicDocument, layout: CabinetLayout, k: float) -> CabinetWiring:
	var wiring: CabinetWiring = CabinetWiring.new()
	for duct: Dictionary in layout.ducts:
		if duct["vertical"]:
			wiring._sides.append(duct["rect"])
		else:
			wiring._across.append(duct["rect"])
	if wiring._sides.size() < 2 or wiring._across.is_empty():
		return wiring
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	var conductor: Dictionary[int, CabinetDevices.Conductor] = CabinetDevices.conductors(doc.circuit, net)
	# Net -> its terminals on the rails, in the order of the places.
	var by_net: Dictionary[int, Array] = {}
	for point: Dictionary in wiring._terminals(layout, k, net):
		var n: int = net[point["key"]]
		if not by_net.has(n):
			by_net[n] = []
		by_net[n].append(point)
	var edges: Array[Dictionary] = []
	for n: int in by_net:
		for pair: Vector2i in wiring._tree(by_net[n]):
			var a: Dictionary = by_net[n][pair.x]
			var b: Dictionary = by_net[n][pair.y]
			var c: CabinetDevices.Conductor = conductor.get(n, CabinetDevices.Conductor.CONTROL)
			edges.append({"net": n, "conductor": c, "a": a, "b": b, "width": POWER_W if c == CabinetDevices.Conductor.POWER else WIRE_W})
	wiring._route(edges)
	return wiring


## Every terminal on the rails a wire can go to: {"key" (terminal key in
## the circuit), "at" (where the wire ends), "duct" (index of the duct
## across it is led to), "up" (the duct is above it), "id" (its index)}.
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
					var nets: Dictionary[int, bool] = {}
					for key: String in terminals[i]["keys"]:
						if net.has(key) and not nets.has(net[key]):
							nets[net[key]] = true
							result.append({"key": key, "at": at, "duct": rail, "up": true})
			CabinetLayout.MISSING_DEVICE:
				pass
			_:
				_add_device(result, net, place["kind"], place["desc"], origin, rail, centre)
				if place.has("under_origin"):
					_add_device(result, net, CabinetDevices.Kind.OVERLOAD, place["under_desc"], place["under_origin"], rail, centre)
	for i: int in result.size():
		result[i]["id"] = i
	return result


func _add_device(result: Array[Dictionary], net: Dictionary[String, int], kind: int, desc: Dictionary, origin: Vector2, rail: int, centre: float) -> void:
	var terminals: Dictionary = desc.get("terminals", {})
	var points: Dictionary = CabinetParts.terminal_points(kind, desc)
	for name: String in points:
		if not terminals.has(name) or not net.has(terminals[name]):
			continue
		var p: Vector3 = points[name]
		var up: bool = origin.y + p.y < centre
		var at: Vector2 = origin + Vector2(p.x, p.y + (-p.z if up else p.z))
		result.append({"key": terminals[name], "at": at, "duct": rail if up else rail + 1, "up": up})


## Pairs of indices into [param points] joining them all along the
## shortest routes (a minimum spanning tree).
func _tree(points: Array) -> Array[Vector2i]:
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
	# through the slots of their ducts, at most SLOT_WIRES in one.
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
	ends.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["x"] < q["x"])
	var pitch: float = CabinetParts.DUCT_FINGER + CabinetParts.DUCT_SLOT
	var slots: Dictionary[Vector2i, Array] = {}
	for end: Dictionary in ends:
		var d: int = end["point"]["duct"]
		var duct: Rect2 = _across[d]
		var count: int = CabinetParts.duct_slots(duct.size.x)
		var along: float = end["x"] - duct.position.x
		var nearest: int = clampi(roundi((along - CabinetParts.duct_slot(0)) / pitch), 0, count - 1)
		# The nearest slot with room, trying further out on both sides
		# (first towards the terminal).
		var toward: int = 1 if along > CabinetParts.duct_slot(nearest) else -1
		var slot: int = nearest
		for t: int in 7:
			var candidate: int = nearest + int((t + 1) / 2.0) * (toward if t % 2 == 1 else -toward)
			if candidate >= 0 and candidate < count and slots.get(Vector2i(d, candidate), []).size() < SLOT_WIRES:
				slot = candidate
				break
		var key: Vector2i = Vector2i(d, slot)
		if not slots.has(key):
			slots[key] = []
		slots[key].append(end)
		end["slot"] = duct.position.x + CabinetParts.duct_slot(slot)
	for key: Vector2i in slots:
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
		})


## From a terminal up or down to its duct and in through its slot to the
## lane at [param lane] (y).
func _drop(end: Dictionary, lane: float) -> PackedVector2Array:
	var point: Dictionary = end["point"]
	var duct: Rect2 = _across[point["duct"]]
	var bend: float = duct.end.y + BEND if point["up"] else duct.position.y - BEND
	var at: Vector2 = Vector2(end["x"], point["at"].y)
	return PackedVector2Array([at, Vector2(at.x, bend), Vector2(end["slot"], bend), Vector2(end["slot"], lane)])


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
