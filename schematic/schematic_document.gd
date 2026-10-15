class_name SchematicDocument
extends RefCounted
## A circuit together with its drawing: where each component sits and how each
## wire is routed. Wire routes are kept in the same order as
## [method Circuit.get_wires].

## Display name of the schematic (English source text, translated by the UI).
var title: String
var circuit: Circuit = Circuit.new()
## True after [method transpose] turned the drawing to horizontal current paths.
var horizontal: bool = false
## Simulate relays with pick-up and drop-out times (see [Armature]) rather
## than instant switching.
var realistic_timing: bool = true
## Operator panel: control boxes with the buttons, switches and signal lamps
## of the circuit (see [ControlBox]).
var control_boxes: Array[ControlBox] = []

var _placements: Dictionary[String, Placement] = {}
var _routes: Array[WireRoute] = []


func _init(p_title: String = "") -> void:
	title = p_title


## Adds a component at a grid cell. Returns it, or null if the circuit refused it.
func add(component: CircuitComponent, cell: Vector2i, rotation: int = 0, mirrored: bool = false) -> CircuitComponent:
	if circuit.add(component) == null:
		return null
	_placements[component.id] = Placement.new(cell, rotation, mirrored)
	return component


## Wires two terminals, drawn through the given grid corners.
func connect_terminals(key_a: String, key_b: String, corners: Array[Vector2i] = []) -> bool:
	if not circuit.connect_terminals(key_a, key_b):
		return false
	_routes.append(WireRoute.new(corners))
	return true


func get_placement(component_id: String) -> Placement:
	return _placements.get(_id(component_id), null)


## Exact id for an id or a designation ("S1" -> "S1:13-14"), see
## [method Circuit.get_component].
func _id(component_id: String) -> String:
	var c: CircuitComponent = circuit.get_component(component_id)
	return c.id if c != null else component_id


func get_route(wire_index: int) -> WireRoute:
	return _routes[wire_index]


func get_wire_count() -> int:
	return _routes.size()


## Grid cell of a terminal.
func terminal_cell(key: String) -> Vector2i:
	var owner: CircuitComponent = circuit.get_terminal_owner(key)
	var p: Placement = _placements[owner.id]
	var local: Vector2i = SymbolGeometry.local_terminals(owner)[_terminal_name(owner, key)]
	return p.cell + SymbolGeometry.transform_cell(local, p)


## Full polyline of a wire: start terminal, corners, end terminal.
func wire_points(wire_index: int) -> Array[Vector2i]:
	var wire: PackedStringArray = circuit.get_wires()[wire_index]
	var points: Array[Vector2i] = [terminal_cell(wire[0])]
	points.append_array(_routes[wire_index].corners)
	points.append(terminal_cell(wire[1]))
	return points


## Clickable body of a component in grid units.
func component_body(component: CircuitComponent) -> Rect2:
	var p: Placement = _placements[component.id]
	var r: Rect2 = SymbolGeometry.transform_rect(SymbolGeometry.local_body(component), p)
	r.position += Vector2(p.cell)
	return r


## Topmost component whose body contains [param point] (grid units), or null.
func component_at(point: Vector2) -> CircuitComponent:
	var components: Array[CircuitComponent] = circuit.get_components()
	for i: int in range(components.size() - 1, -1, -1):
		if component_body(components[i]).has_point(point):
			return components[i]
	return null


## Bounding box of all symbols and wires, in grid units.
func bounds() -> Rect2:
	var r: Rect2 = Rect2()
	var first: bool = true
	for c: CircuitComponent in circuit.get_components():
		var body: Rect2 = component_body(c)
		r = body if first else r.merge(body)
		first = false
	for w: int in _routes.size():
		for p: Vector2i in wire_points(w):
			r = r.expand(Vector2(p))
	return r


## Grid positions of the numbered current paths: x of each column when the
## drawing is vertical, y of each row when it is horizontal. Every two-terminal
## symbol marks the midpoint between its terminals; positions closer than
## [param merge] cells count as one path.
func current_paths(merge: float = 2.0) -> PackedFloat32Array:
	var coordinates: Array[float] = []
	for c: CircuitComponent in circuit.get_components():
		var keys: PackedStringArray = c.get_terminal_keys()
		if keys.size() < 2:
			continue
		var center: Vector2 = (Vector2(terminal_cell(keys[0])) + Vector2(terminal_cell(keys[1]))) * 0.5
		coordinates.append(center.y if horizontal else center.x)
	coordinates.sort()
	var paths: PackedFloat32Array = PackedFloat32Array()
	var group_start: float = 0.0
	var group_sum: float = 0.0
	var group_count: int = 0
	for value: float in coordinates:
		if group_count > 0 and value - group_start > merge:
			paths.append(group_sum / group_count)
			group_count = 0
		if group_count == 0:
			group_start = value
			group_sum = 0.0
		group_sum += value
		group_count += 1
	if group_count > 0:
		paths.append(group_sum / group_count)
	return paths


## Cells where three or more wire or lead directions meet at a wire's end or
## corner, drawn as dots (a plain crossing is not a connection).
func junction_cells() -> Array[Vector2i]:
	var directions: Dictionary[Vector2i, int] = {}
	# Cells where a wire starts, ends or turns: only there do wires connect.
	# Two wires merely crossing each other get no dot.
	var vertices: Dictionary[Vector2i, bool] = {}
	for i: int in _routes.size():
		var points: Array[Vector2i] = wire_points(i)
		for p: Vector2i in points:
			vertices[p] = true
		for s: int in range(1, points.size()):
			var a: Vector2i = points[s - 1]
			var b: Vector2i = points[s]
			if a == b:
				continue
			var unit: Vector2i = (b - a).sign()
			var cell: Vector2i = a
			while true:
				var bits: int = directions.get(cell, 0)
				if cell != b:
					bits |= SymbolGeometry.direction_of(unit)
				if cell != a:
					bits |= SymbolGeometry.direction_of(-unit)
				directions[cell] = bits
				if cell == b:
					break
				cell += unit
	for c: CircuitComponent in circuit.get_components():
		var p: Placement = _placements[c.id]
		var names: PackedStringArray = c.get_terminal_names()
		var keys: PackedStringArray = c.get_terminal_keys()
		for t: int in names.size():
			var lead: int = SymbolGeometry.local_lead_direction(c, names[t])
			if lead == 0:
				continue
			var cell: Vector2i = terminal_cell(keys[t])
			if directions.has(cell):
				directions[cell] |= SymbolGeometry.transform_direction(lead, p)
	var result: Array[Vector2i] = []
	for cell: Vector2i in directions:
		var bits: int = directions[cell]
		var count: int = (bits & 1) + ((bits >> 1) & 1) + ((bits >> 2) & 1) + ((bits >> 3) & 1)
		if count >= 3 and vertices.has(cell):
			result.append(cell)
	return result


## Swaps rows and columns of the whole drawing, turning vertical current paths
## into horizontal ones and back. The circuit itself is unchanged.
func transpose() -> void:
	for id: String in _placements:
		var p: Placement = _placements[id]
		# Transpose = mirror then a quarter turn back: T * R(r) * M^m = R(3 - r) * M^(m + 1).
		p.cell = Vector2i(p.cell.y, p.cell.x)
		p.rotation = posmod(3 - p.rotation, 4)
		p.mirrored = not p.mirrored
	for route: WireRoute in _routes:
		for i: int in route.corners.size():
			route.corners[i] = Vector2i(route.corners[i].y, route.corners[i].x)
	horizontal = not horizontal


# --- Editing -----------------------------------------------------------------

const AXIS_NONE: int = -1
const AXIS_HORIZONTAL: int = 0
const AXIS_VERTICAL: int = 1


func remove_wire(index: int) -> void:
	circuit.remove_wire(index)
	_routes.remove_at(index)


## Index of the segment of wire [param index] under [param point] (segment k
## runs from wire_points()[k] to [k + 1]), or -1.
func wire_segment_at(index: int, point: Vector2, tolerance: float = 0.35) -> int:
	var points: Array[Vector2i] = wire_points(index)
	for k: int in range(points.size() - 1):
		var a: Vector2 = Vector2(points[k])
		var b: Vector2 = Vector2(points[k + 1])
		if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) <= tolerance:
			return k
	return -1


## Moves segment [param segment] of wire [param index] sideways by
## [param offset] cells, starting from the route [param points] the wire had
## when the drag began (so a drag can be updated as the mouse moves). The
## terminal ends stay where they are: new corners are added next to them, and
## corners that end up in a straight line are merged.
func drag_wire_segment(index: int, points: Array[Vector2i], segment: int, offset: Vector2i) -> void:
	if segment < 0 or segment + 1 >= points.size():
		return
	var a: Vector2i = points[segment]
	var b: Vector2i = points[segment + 1]
	var shift: Vector2i = Vector2i(0, offset.y) if a.y == b.y else Vector2i(offset.x, 0)
	var moved: Array[Vector2i] = points.duplicate()
	var last: int = points.size() - 1
	if segment + 1 == last:
		moved.insert(last, b + shift)
	else:
		moved[segment + 1] = b + shift
	if segment == 0:
		moved.insert(1, a + shift)
	else:
		moved[segment] = a + shift
	var simple: Array[Vector2i] = _simplify_path(moved)
	_routes[index].corners = simple.slice(1, simple.size() - 1)


## Drops repeated points and points in the middle of a straight run.
static func _simplify_path(points: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for p: Vector2i in points:
		if result.is_empty() or result[result.size() - 1] != p:
			result.append(p)
	var i: int = 1
	while i < result.size() - 1:
		var prev: Vector2i = result[i - 1]
		var next: Vector2i = result[i + 1]
		if (prev.x == result[i].x and next.x == result[i].x) or (prev.y == result[i].y and next.y == result[i].y):
			result.remove_at(i)
		else:
			i += 1
	return result


## Wires of the net of wire [param index]: all wires joined to it through
## shared terminals (junctions, terminal blocks, component terminals).
func wire_net(index: int) -> PackedInt32Array:
	var wires: Array[PackedStringArray] = circuit.get_wires()
	var by_key: Dictionary[String, PackedInt32Array] = {}
	for i: int in wires.size():
		for key: String in wires[i]:
			if not by_key.has(key):
				by_key[key] = PackedInt32Array()
			by_key[key].append(i)
	var seen: Dictionary[int, bool] = {index: true}
	var queue: PackedInt32Array = PackedInt32Array([index])
	while not queue.is_empty():
		var w: int = queue[queue.size() - 1]
		queue.remove_at(queue.size() - 1)
		for key: String in wires[w]:
			for other: int in by_key[key]:
				if not seen.has(other):
					seen[other] = true
					queue.append(other)
	var result: PackedInt32Array = PackedInt32Array(seen.keys())
	result.sort()
	return result


## Gives the whole net of wire [param index] the number [param number].
func set_wire_number(index: int, number: String) -> void:
	for w: int in wire_net(index):
		_routes[w].number = number.strip_edges()


## Wires up to this long (in cells) show their number only once, in the middle.
const SHORT_WIRE: float = 2.0


## Wire ends that show their wire number, as Vector2i(wire, end): ends on
## components and terminal blocks (not junctions), one per terminal; a short
## wire shows its number once.
func wire_number_ends() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var written: Dictionary[String, bool] = {}
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for w: int in wires.size():
		if _routes[w].number.is_empty() or _path_length(w) == 0.0:
			continue
		var ends: Array[int] = []
		for end: int in 2:
			var key: String = wires[w][end]
			if not (circuit.get_terminal_owner(key) is Junction) and not written.has(key):
				written[key] = true
				ends.append(end)
		if ends.size() == 2 and _path_length(w) <= SHORT_WIRE:
			ends.resize(1)
		for end: int in ends:
			result.append(Vector2i(w, end))
	return result


## Grid point the number of wire end [param end] is written at: 0.8 cell along
## the wire from its terminal (the middle of a short wire), plus the offset
## the user dragged it by.
func wire_number_point(index: int, end: int) -> Vector2:
	var points: Array[Vector2i] = wire_points(index)
	var length: float = _path_length(index)
	var along: float = length * 0.5 if length <= SHORT_WIRE else 0.8
	if end == 1:
		points.reverse()
	var p: Vector2 = Vector2(points[0])
	for i: int in range(1, points.size()):
		var step: float = Vector2(points[i] - points[i - 1]).length()
		if along <= step or i == points.size() - 1:
			p = Vector2(points[i - 1]) + Vector2(points[i] - points[i - 1]).normalized() * minf(along, step)
			break
		along -= step
	return p + _routes[index].number_offsets[end]


## True when the wire leaves end [param end] vertically (the number is
## written beside it), false when horizontally (written above it).
func wire_number_vertical(index: int, end: int) -> bool:
	var points: Array[Vector2i] = wire_points(index)
	if end == 1:
		points.reverse()
	for i: int in range(1, points.size()):
		if points[i] != points[0]:
			return points[i].x == points[0].x
	return true


## Moves the number at wire end [param end] by [param offset] cells from its
## standard place.
func set_wire_number_offset(index: int, end: int, offset: Vector2) -> void:
	_routes[index].number_offsets[end] = offset


func _path_length(index: int) -> float:
	var points: Array[Vector2i] = wire_points(index)
	var length: float = 0.0
	for i: int in range(1, points.size()):
		length += Vector2(points[i] - points[i - 1]).length()
	return length


## Numbers every net from [param first] on, in drawing order (current path by
## current path); nets fed straight from a supply (L, N, ...) stay unnumbered.
func number_wires(first: int = 1) -> void:
	var done: Dictionary[int, bool] = {}
	var nets: Array[PackedInt32Array] = []
	for i: int in circuit.get_wires().size():
		if not done.has(i):
			var net: PackedInt32Array = wire_net(i)
			for w: int in net:
				done[w] = true
			nets.append(net)
	var order: Callable = func(net: PackedInt32Array) -> Vector2i:
		var best: Vector2i = Vector2i(2147483647, 2147483647)
		for w: int in net:
			for p: Vector2i in wire_points(w):
				var k: Vector2i = Vector2i(p.y, p.x) if horizontal else p
				if k.x < best.x or (k.x == best.x and k.y < best.y):
					best = k
		return best
	nets.sort_custom(func(a: PackedInt32Array, b: PackedInt32Array) -> bool:
		var ka: Vector2i = order.call(a)
		var kb: Vector2i = order.call(b)
		return ka.x < kb.x or (ka.x == kb.x and ka.y < kb.y))
	var n: int = first
	for net: PackedInt32Array in nets:
		var supplied: bool = false
		for w: int in net:
			for key: String in circuit.get_wires()[w]:
				if circuit.get_terminal_owner(key) is PowerSupply:
					supplied = true
		for w: int in net:
			_routes[w].number = "" if supplied else str(n)
		if not supplied:
			n += 1


## Removes a component together with its wires.
func remove_component(component_id: String) -> void:
	var c: CircuitComponent = circuit.get_component(component_id)
	if c == null:
		return
	for i: int in circuit.remove(c):
		_routes.remove_at(i)
	_placements.erase(c.id)


## Moves components by [param delta] cells. Wires between two moved
## components move along; wires with one moved end are re-routed.
func move_components(ids: PackedStringArray, delta: Vector2i) -> void:
	var moved_keys: Dictionary[String, bool] = {}
	for given: String in ids:
		var id: String = _id(given)
		_placements[id].cell += delta
		for key: String in circuit.get_component(id).get_terminal_keys():
			moved_keys[key] = true
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in wires.size():
		var a: bool = moved_keys.has(wires[i][0])
		var b: bool = moved_keys.has(wires[i][1])
		if a and b:
			for k: int in _routes[i].corners.size():
				_routes[i].corners[k] += delta
		elif a or b:
			normalize_route(i)


## Turns a component a quarter turn clockwise (or counterclockwise).
func rotate_component(component_id: String, clockwise: bool = true) -> void:
	component_id = _id(component_id)
	var p: Placement = _placements[component_id]
	p.rotation = posmod(p.rotation + (1 if clockwise else -1), 4)
	_reroute_component(component_id)


## Makes lead [param index] of a component end in a strip terminal labelled
## [param label] (drawn instead of the terminal square); "" removes it.
func set_strip_terminal(component_id: String, index: int, label: String) -> void:
	var p: Placement = _placements[_id(component_id)]
	if label.strip_edges().is_empty():
		p.strips.erase(index)
		p.labels.erase("strip:%d" % index)
	else:
		p.strips[index] = label.strip_edges()


## Next free number for a strip terminal: one more than the highest number
## among the terminals on wires and on leads.
func next_strip_label() -> String:
	var highest: int = 0
	for c: CircuitComponent in circuit.get_components():
		if c is TerminalBlock and (c as TerminalBlock).label.is_valid_int():
			highest = maxi(highest, int((c as TerminalBlock).label))
		for label: String in _placements[c.id].strips.values():
			if label.is_valid_int():
				highest = maxi(highest, int(label))
	return str(highest + 1)


## Moves a marking of a component (see [member Placement.labels]) by
## [param offset] cells from its standard place.
func set_label_offset(component_id: String, key: String, offset: Vector2) -> void:
	var p: Placement = _placements[_id(component_id)]
	if offset == Vector2.ZERO:
		p.labels.erase(key)
	else:
		p.labels[key] = offset


## Mirrors a component left to right as seen on the drawing. A vertical
## symbol is mirrored across its own axis (actuator to the other side, the
## terminals stay); a horizontal one swaps its ends in place.
func mirror_component(component_id: String) -> void:
	component_id = _id(component_id)
	if _placements[component_id].rotation % 2 == 0:
		_mirror_across_axis(component_id)
	else:
		_swap_ends(component_id)


## Mirrors a component top to bottom as seen on the drawing: a vertical
## symbol swaps its upper and lower terminals in place, a horizontal one is
## mirrored across its own axis.
func flip_component(component_id: String) -> void:
	component_id = _id(component_id)
	if _placements[component_id].rotation % 2 == 0:
		_swap_ends(component_id)
	else:
		_mirror_across_axis(component_id)


func _mirror_across_axis(component_id: String) -> void:
	var p: Placement = _placements[component_id]
	# The mirror flips local x before rotation, so the symbol axis (local y)
	# and both terminals stay where they are; only the side marks swap.
	p.mirrored = not p.mirrored
	_reroute_component(component_id)


## Mirrors local y about the symbol's middle, so its first and last
## terminals swap places.
func _swap_ends(component_id: String) -> void:
	var p: Placement = _placements[component_id]
	var height: int = 0
	for cell: Vector2i in SymbolGeometry.local_terminals(circuit.get_component(component_id)).values():
		height = maxi(height, cell.y)
	# Mirroring y = mirroring x and a half turn; shift so the ends swap.
	p.cell += SymbolGeometry.transform_cell(Vector2i(0, height), p)
	p.mirrored = not p.mirrored
	p.rotation = (p.rotation + 2) % 4
	_reroute_component(component_id)


## Replaces a component (e.g. after its properties were edited) keeping its
## placement and wiring. Returns false if the circuit refused it.
func replace_component(old_id: String, new_component: CircuitComponent) -> bool:
	var old: CircuitComponent = circuit.get_component(old_id)
	if old == null:
		return false
	old_id = old.id
	# Wires on terminals the new component no longer has go away.
	var new_count: int = new_component.get_terminal_keys().size()
	var old_keys: PackedStringArray = old.get_terminal_keys()
	for i: int in range(circuit.get_wires().size() - 1, -1, -1):
		var wire: PackedStringArray = circuit.get_wires()[i]
		for k: int in range(new_count, old_keys.size()):
			if wire.has(old_keys[k]):
				remove_wire(i)
				break
	var p: Placement = _placements[old_id]
	if not circuit.replace(old, new_component):
		return false
	_placements.erase(old_id)
	_placements[new_component.id] = p
	_reroute_component(new_component.id)
	if new_component.designation != old.designation and circuit.get_component(old.designation) == null:
		# The last part of the device was renamed: the control panel follows.
		rename_control_device(old.designation, new_component.designation)
	return true


## Inserts a [Junction] at [param cell] on wire [param index], splitting the
## wire in two. Returns the junction terminal key ("" if the cell is not on
## the wire). At an end of the wire the existing terminal key is returned.
func split_wire(index: int, cell: Vector2i, point: CircuitComponent = null) -> String:
	var points: Array[Vector2i] = wire_points(index)
	var wire: PackedStringArray = circuit.get_wires()[index]
	if cell == points[0]:
		return wire[0]
	if cell == points[points.size() - 1]:
		return wire[1]
	var segment: int = -1
	for s: int in range(1, points.size()):
		if _on_segment(cell, points[s - 1], points[s]):
			segment = s
			break
	if segment < 0:
		return ""
	# A new junction, or the given single-terminal component (a terminal block).
	var junction: CircuitComponent = point if point != null else Junction.new(next_designation("J"))
	add(junction, cell)
	var corners_a: Array[Vector2i] = points.slice(1, segment)
	var corners_b: Array[Vector2i] = points.slice(segment, points.size() - 1)
	if not corners_a.is_empty() and corners_a[corners_a.size() - 1] == cell:
		corners_a.remove_at(corners_a.size() - 1)
	if not corners_b.is_empty() and corners_b[0] == cell:
		corners_b.remove_at(0)
	var key_a: String = wire[0]
	var key_b: String = wire[1]
	var number: String = _routes[index].number
	remove_wire(index)
	connect_terminals(key_a, junction.designation, corners_a)
	connect_terminals(junction.designation, key_b, corners_b)
	_routes[_routes.size() - 1].number = number
	_routes[_routes.size() - 2].number = number
	return junction.designation


## Removes junctions that no longer join anything: without wires they go,
## with one wire the dangling stub goes too, with two wires the wires are
## merged back into one.
func cleanup_junctions() -> void:
	var changed: bool = true
	while changed:
		changed = false
		for c: CircuitComponent in circuit.get_components().duplicate():
			if not (c is Junction):
				continue
			var wires: PackedInt32Array = circuit.wires_of(c)
			if wires.size() == 2:
				_merge_at_junction(c, wires)
			elif wires.size() > 2:
				continue
			else:
				remove_component(c.id)
			changed = true
			break


## Re-routes a wire so all segments are horizontal or vertical. Each end that
## belongs to a symbol first leaves one cell straight out along the symbol
## axis. If that route would cross one of the two symbols (e.g. after turning
## a symbol by 180 degrees) or run over another of their terminals, the
## shortest route around them is used instead.
func normalize_route(index: int) -> void:
	var wire: PackedStringArray = circuit.get_wires()[index]
	var points: Array[Vector2i] = wire_points(index)
	var start: Vector2i = points[0]
	var end: Vector2i = points[points.size() - 1]
	var out_a: Vector2i = terminal_outward(wire[0])
	var out_b: Vector2i = terminal_outward(wire[1])
	var path: Array[Vector2i] = [start]
	if out_a != Vector2i.ZERO:
		path.append(start + out_a)
	path.append_array(points.slice(1, points.size() - 1))
	if out_b != Vector2i.ZERO:
		path.append(end + out_b)
	path.append(end)
	var best: Array[Vector2i] = orthogonalize(path, terminal_axis(wire[0]), terminal_axis(wire[1]))

	var bodies: Array[Rect2] = []
	var cells: Array[Vector2i] = []
	for key: String in [wire[0], wire[1]]:
		var owner: CircuitComponent = circuit.get_terminal_owner(key)
		if owner.get_terminal_keys().size() == 2:
			bodies.append(component_body(owner))
		for other: String in owner.get_terminal_keys():
			if other != wire[0] and other != wire[1]:
				cells.append(terminal_cell(other))
	if not _route_clear(best, bodies, cells):
		var best_length: int = 1 << 30
		for candidate: Array[Vector2i] in _detours(start, end, out_a, out_b, bodies):
			var clean: Array[Vector2i] = orthogonalize(candidate)
			var length: int = _route_length(clean)
			if length < best_length and _route_clear(clean, bodies, cells):
				best = clean
				best_length = length
	_routes[index].corners = best.slice(1, best.size() - 1)


## Candidate routes around [param bodies]: via one or two corners of each body
## grown by a cell, with and without the straight lead-out at each end.
func _detours(start: Vector2i, end: Vector2i, out_a: Vector2i, out_b: Vector2i, bodies: Array[Rect2]) -> Array:
	var vias: Array = []
	for body: Rect2 in bodies:
		var left: int = floori(body.position.x) - 1
		var right: int = ceili(body.end.x) + 1
		var top: int = floori(body.position.y) - 1
		var bottom: int = ceili(body.end.y) + 1
		var corners: Array[Vector2i] = [Vector2i(left, top), Vector2i(right, top), Vector2i(right, bottom), Vector2i(left, bottom)]
		for i: int in 4:
			vias.append([corners[i]])
			vias.append([corners[i], corners[(i + 1) % 4]])
			vias.append([corners[(i + 1) % 4], corners[i]])
	var heads: Array = [[start]]
	if out_a != Vector2i.ZERO:
		heads.append([start, start + out_a])
	var tails: Array = [[end]]
	if out_b != Vector2i.ZERO:
		tails.append([end + out_b, end])
	var result: Array = []
	for head: Array in heads:
		for tail: Array in tails:
			for via: Array in vias:
				var path: Array[Vector2i] = []
				for p: Vector2i in head + via + tail:
					path.append(p)
				result.append(path)
	return result


## True if no segment crosses the inside of [param bodies] or runs over one
## of [param cells].
static func _route_clear(points: Array[Vector2i], bodies: Array[Rect2], cells: Array[Vector2i]) -> bool:
	for s: int in range(1, points.size()):
		var a: Vector2i = points[s - 1]
		var b: Vector2i = points[s]
		for cell: Vector2i in cells:
			if _on_segment(cell, a, b):
				return false
		for body: Rect2 in bodies:
			if a.x == b.x:
				if float(a.x) > body.position.x and float(a.x) < body.end.x and float(maxi(a.y, b.y)) > body.position.y and float(mini(a.y, b.y)) < body.end.y:
					return false
			elif float(a.y) > body.position.y and float(a.y) < body.end.y and float(maxi(a.x, b.x)) > body.position.x and float(mini(a.x, b.x)) < body.end.x:
				return false
	return true


static func _route_length(points: Array[Vector2i]) -> int:
	var length: int = 0
	for s: int in range(1, points.size()):
		var d: Vector2i = (points[s] - points[s - 1]).abs()
		length += d.x + d.y
	# Each corner costs a little, so straighter routes win ties.
	return length * 4 + points.size()


## Axis along which wires should leave a terminal, or AXIS_NONE.
func terminal_axis(key: String) -> int:
	var out: Vector2i = terminal_outward(key)
	if out == Vector2i.ZERO:
		return AXIS_NONE
	return AXIS_VERTICAL if out.x == 0 else AXIS_HORIZONTAL


## Unit step pointing away from the symbol at a terminal, or zero for
## supplies and junctions.
func terminal_outward(key: String) -> Vector2i:
	var owner: CircuitComponent = circuit.get_terminal_owner(key)
	var lead: int = SymbolGeometry.local_lead_direction(owner, _terminal_name(owner, key))
	if lead == 0:
		return Vector2i.ZERO
	match SymbolGeometry.transform_direction(lead, _placements[owner.id]):
		SymbolGeometry.DIR_UP:
			return Vector2i.DOWN
		SymbolGeometry.DIR_DOWN:
			return Vector2i.UP
		SymbolGeometry.DIR_LEFT:
			return Vector2i.RIGHT
	return Vector2i.LEFT


## Makes a polyline orthogonal by inserting elbows and drops duplicate and
## collinear points. The first and last point are kept. An elbow keeps going
## the way the previous segment went unless that would turn back; at the start
## (no previous segment) [param start_axis] decides, at the end [param end_axis].
static func orthogonalize(points: Array[Vector2i], start_axis: int = AXIS_NONE, end_axis: int = AXIS_NONE) -> Array[Vector2i]:
	var out: Array[Vector2i] = [points[0]]
	for s: int in range(1, points.size()):
		var p: Vector2i = out[out.size() - 1]
		var q: Vector2i = points[s]
		if p.x != q.x and p.y != q.y:
			var previous: Vector2i = Vector2i.ZERO
			if out.size() >= 2:
				previous = (p - out[out.size() - 2]).sign()
			var vertical_first: bool = false
			if previous.y != 0:
				vertical_first = signi(q.y - p.y) == previous.y
			elif previous.x != 0:
				vertical_first = signi(q.x - p.x) != previous.x
			elif s == 1 and start_axis != AXIS_NONE:
				vertical_first = start_axis == AXIS_VERTICAL
			elif s == points.size() - 1 and end_axis != AXIS_NONE:
				vertical_first = end_axis == AXIS_HORIZONTAL
			out.append(Vector2i(p.x, q.y) if vertical_first else Vector2i(q.x, p.y))
		out.append(q)
	var cleaned: Array[Vector2i] = [out[0]]
	for i: int in range(1, out.size()):
		var q: Vector2i = out[i]
		if q == cleaned[cleaned.size() - 1] and i < out.size() - 1:
			continue
		while cleaned.size() >= 2:
			var a: Vector2i = cleaned[cleaned.size() - 2]
			var b: Vector2i = cleaned[cleaned.size() - 1]
			if (a.x == b.x and b.x == q.x) or (a.y == b.y and b.y == q.y) or b == q:
				cleaned.remove_at(cleaned.size() - 1)
			else:
				break
		cleaned.append(q)
	return cleaned


# --- Queries for the editor ----------------------------------------------------

## Key of the terminal nearest to [param point] (grid units) within
## [param radius], or "".
func terminal_at(point: Vector2, radius: float = 0.4) -> String:
	var best: String = ""
	var best_distance: float = radius
	for c: CircuitComponent in circuit.get_components():
		for key: String in c.get_terminal_keys():
			var d: float = point.distance_to(Vector2(terminal_cell(key)))
			if d <= best_distance:
				best_distance = d
				best = key
	return best


## Index of the wire nearest to [param point] within [param tolerance], or -1.
func wire_at(point: Vector2, tolerance: float = 0.3) -> int:
	var best: int = -1
	var best_distance: float = tolerance
	for i: int in _routes.size():
		var points: Array[Vector2i] = wire_points(i)
		for s: int in range(1, points.size()):
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, Vector2(points[s - 1]), Vector2(points[s]))
			var d: float = point.distance_to(closest)
			if d <= best_distance:
				best_distance = d
				best = i
	return best


## Grid cell on wire [param index] nearest to [param point].
func wire_cell_near(index: int, point: Vector2) -> Vector2i:
	var points: Array[Vector2i] = wire_points(index)
	var best: Vector2i = points[0]
	var best_distance: float = INF
	for s: int in range(1, points.size()):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, Vector2(points[s - 1]), Vector2(points[s]))
		var cell: Vector2i = Vector2i(closest.round())
		var d: float = point.distance_to(Vector2(cell))
		if d < best_distance:
			best_distance = d
			best = cell
	return best


## First free designation "<prefix><n>", e.g. "K3", also avoiding
## [param reserved].
func next_designation(prefix: String, reserved: Dictionary[String, bool] = {}) -> String:
	var used: Dictionary[String, bool] = reserved.duplicate()
	for c: CircuitComponent in circuit.get_components():
		used[c.designation] = true
	var n: int = 1
	while used.has(prefix + str(n)):
		n += 1
	return prefix + str(n)


## Designation for another supply point: "L", then "L.2", "L.3", ...
func next_supply_designation(conductor: PowerSupply.Conductor) -> String:
	var base: String = "N"
	match conductor:
		PowerSupply.Conductor.L:
			# L1, unless a single-phase drawing already names its phase plain
			# "L" (then "L.2", "L.3", ...); next to L2 or L3 always L1.
			base = "L1"
			var plain: bool = false
			for c: CircuitComponent in circuit.get_components():
				if c is PowerSupply:
					if (c as PowerSupply).conductor in [PowerSupply.Conductor.L2, PowerSupply.Conductor.L3]:
						plain = false
						break
					if c.designation == "L" or c.designation.begins_with("L."):
						plain = true
			if plain:
				base = "L"
		PowerSupply.Conductor.L2:
			base = "L2"
		PowerSupply.Conductor.L3:
			base = "L3"
		PowerSupply.Conductor.DC_PLUS:
			base = "+"
		PowerSupply.Conductor.DC_MINUS:
			base = "-"
	if not circuit.has_component_id(base):
		return base
	var n: int = 2
	while circuit.has_component_id("%s.%d" % [base, n]):
		n += 1
	return "%s.%d" % [base, n]


## First contact sequence digit (1-9) not yet used by [param designation].
func next_contact_sequence(designation: String) -> int:
	var used: Dictionary[int, bool] = {}
	for c: CircuitComponent in circuit.get_components():
		if c is SwitchingElement and c.designation == designation:
			used[(c as SwitchingElement).sequence] = true
		elif c is ChangeoverContact and c.designation == designation:
			used[(c as ChangeoverContact).sequence] = true
	for n: int in range(1, 10):
		if not used.has(n):
			return n
	return 9


# --- Clipboard -----------------------------------------------------------------

## Copies components and the wires running between them (both ends inside the
## selection) into plain data for [method insert].
func extract(ids: PackedStringArray) -> Dictionary:
	var keys: Dictionary[String, bool] = {}
	var components: Array[Dictionary] = []
	for c: CircuitComponent in circuit.get_components():
		if not ids.has(c.id):
			continue
		var d: Dictionary = DocumentSerializer.component_to_dict(c)
		var p: Placement = _placements[c.id]
		d["cell"] = [p.cell.x, p.cell.y]
		d["rotation"] = p.rotation
		d["mirrored"] = p.mirrored
		if not p.labels.is_empty():
			d["labels"] = p.labels_to_data()
		if not p.strips.is_empty():
			d["strips"] = p.strips_to_data()
		components.append(d)
		for key: String in c.get_terminal_keys():
			keys[key] = true
	var wires: Array[Dictionary] = []
	var circuit_wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in circuit_wires.size():
		if keys.has(circuit_wires[i][0]) and keys.has(circuit_wires[i][1]):
			var corners: Array = []
			for corner: Vector2i in _routes[i].corners:
				corners.append([corner.x, corner.y])
			wires.append({"a": circuit_wires[i][0], "b": circuit_wires[i][1], "corners": corners})
	return {"components": components, "wires": wires}


## Adds data from [method extract], shifted by [param offset] cells. Taken
## designations are renumbered; a copied coil and its copied contacts get the
## same new designation, contacts copied without their coil stay with it and
## get a free contact number. Returns the ids of the new components.
func insert(data: Dictionary, offset: Vector2i) -> PackedStringArray:
	var components: Array = data.get("components", [])
	var renamed: Dictionary[String, String] = {}
	var reserved: Dictionary[String, bool] = {}
	for cd: Dictionary in components:
		var kind: String = cd["type"]
		if kind == "supply" or kind == "junction" or kind == "contact":
			continue
		var designation: String = cd["designation"]
		if renamed.has(designation):
			continue
		var taken: bool = reserved.has(designation)
		for c: CircuitComponent in circuit.get_components():
			if c.designation == designation:
				taken = true
				break
		var new_designation: String = designation
		if taken:
			new_designation = next_designation(_designation_prefix(designation), reserved)
		renamed[designation] = new_designation
		reserved[new_designation] = true

	var new_ids: PackedStringArray = PackedStringArray()
	var key_map: Dictionary[String, String] = {}
	for cd: Dictionary in components:
		var d: Dictionary = cd.duplicate()
		match d["type"]:
			"supply":
				var conductor: int = maxi(DocumentSerializer.CONDUCTORS.find(str(d.get("conductor", "L"))), 0)
				d["designation"] = next_supply_designation(conductor as PowerSupply.Conductor)
			"junction":
				d["designation"] = next_designation("J")
			_:
				d["designation"] = renamed.get(d["designation"], d["designation"])
		var c: CircuitComponent = DocumentSerializer.component_from_dict(d)
		if c is SwitchingElement and not DocumentSerializer._fits(circuit, c):
			d["sequence"] = next_contact_sequence(d["designation"])
			c = DocumentSerializer.component_from_dict(d)
		if c == null or not DocumentSerializer._fits(circuit, c):
			continue
		var old_keys: PackedStringArray = DocumentSerializer.component_from_dict(cd).get_terminal_keys()
		var new_keys: PackedStringArray = c.get_terminal_keys()
		for k: int in old_keys.size():
			key_map[old_keys[k]] = new_keys[k]
		var cell: Array = cd["cell"]
		add(c, Vector2i(int(cell[0]), int(cell[1])) + offset, int(cd.get("rotation", 0)), bool(cd.get("mirrored", false)))
		_placements[c.id].labels_from_data(cd.get("labels", {}))
		_placements[c.id].strips_from_data(cd.get("strips", {}))
		new_ids.append(c.id)
	for wd: Dictionary in data.get("wires", []):
		if not key_map.has(wd["a"]) or not key_map.has(wd["b"]):
			continue
		var corners: Array[Vector2i] = []
		for corner: Array in wd["corners"]:
			corners.append(Vector2i(int(corner[0]), int(corner[1])) + offset)
		connect_terminals(key_map[wd["a"]], key_map[wd["b"]], corners)
	return new_ids


static func _designation_prefix(designation: String) -> String:
	var prefix: String = ""
	for ch: String in designation:
		if ch >= "0" and ch <= "9":
			break
		prefix += ch
	return prefix if not prefix.is_empty() else "X"


func _reroute_component(component_id: String) -> void:
	for i: int in circuit.wires_of(circuit.get_component(component_id)):
		normalize_route(i)


func _merge_at_junction(junction: Junction, unordered: PackedInt32Array) -> void:
	# Older wire first, so the merged wire keeps the original direction.
	var wires: PackedInt32Array = unordered.duplicate()
	wires.sort()
	var cell: Vector2i = _placements[junction.id].cell
	var first: Array[Vector2i] = wire_points(wires[0])
	var second: Array[Vector2i] = wire_points(wires[1])
	var w0: PackedStringArray = circuit.get_wires()[wires[0]]
	var w1: PackedStringArray = circuit.get_wires()[wires[1]]
	var key_a: String = w0[0] if w0[1] == junction.designation else w0[1]
	var key_b: String = w1[1] if w1[0] == junction.designation else w1[0]
	if first[0] == cell:
		first.reverse()
	if second[second.size() - 1] == cell:
		second.reverse()
	var merged: Array[Vector2i] = first
	merged.append_array(second.slice(1))
	remove_component(junction.id)
	if key_a == key_b:
		return
	connect_terminals(key_a, key_b, merged.slice(1, merged.size() - 1))
	normalize_route(get_wire_count() - 1)


static func _on_segment(cell: Vector2i, a: Vector2i, b: Vector2i) -> bool:
	if a.x == b.x and cell.x == a.x:
		return cell.y >= mini(a.y, b.y) and cell.y <= maxi(a.y, b.y)
	if a.y == b.y and cell.y == a.y:
		return cell.x >= mini(a.x, b.x) and cell.x <= maxi(a.x, b.x)
	return false


func _terminal_name(owner: CircuitComponent, key: String) -> String:
	var keys: PackedStringArray = owner.get_terminal_keys()
	return owner.get_terminal_names()[keys.find(key)]


# --- Control panel -------------------------------------------------------------

## Adds an empty control box at the end of the panel.
func add_control_box(title: String = "", columns: int = 1) -> ControlBox:
	var box: ControlBox = ControlBox.new(title, columns)
	control_boxes.append(box)
	return box


## Adds a control box with every push button, switch and signal lamp that is
## not on the panel yet: buttons that only break (stop) red, other buttons
## green, switches black, lamps green. Returns null when there is none.
func add_control_box_for_all() -> ControlBox:
	var items: Array[ControlBoxItem] = []
	var listed: Dictionary[String, bool] = control_panel_devices()
	var breaks_only: Dictionary[String, bool] = {}
	for c: CircuitComponent in circuit.get_components():
		if c is PushButton:
			var nc: bool = (c as PushButton).contact_type == SwitchingElement.ContactType.NC
			breaks_only[c.designation] = breaks_only.get(c.designation, true) and nc
	for kind: int in [ControlBoxItem.Kind.BUTTON, ControlBoxItem.Kind.SWITCH, ControlBoxItem.Kind.LAMP]:
		for designation: String in control_devices(kind):
			if listed.has(designation):
				continue
			var color: String = ControlBoxItem.default_color(kind as ControlBoxItem.Kind)
			if kind == ControlBoxItem.Kind.BUTTON and breaks_only.get(designation, false):
				color = "red"
			var item: ControlBoxItem = ControlBoxItem.new(kind as ControlBoxItem.Kind, designation, color)
			var device: CircuitComponent = circuit.get_component(designation)
			if device is Lamp:
				item.label = (device as Lamp).purpose
			items.append(item)
	if items.is_empty():
		return null
	var box: ControlBox = add_control_box("", 1 if items.size() <= 4 else 2)
	box.items = items
	return box


func remove_control_box(index: int) -> void:
	if index >= 0 and index < control_boxes.size():
		control_boxes.remove_at(index)


## Moves control box [param index] by [param delta] places (clamped).
func move_control_box(index: int, delta: int) -> void:
	if index < 0 or index >= control_boxes.size():
		return
	var box: ControlBox = control_boxes[index]
	control_boxes.remove_at(index)
	control_boxes.insert(clampi(index + delta, 0, control_boxes.size()), box)


## Sets the text on a control box and how many items it has per row.
func set_control_box(index: int, title: String, columns: int) -> void:
	if index >= 0 and index < control_boxes.size():
		control_boxes[index].title = title.strip_edges()
		control_boxes[index].columns = columns


## Adds a [param kind] item to control box [param box_index], showing the
## first device of that kind not on the panel yet (or no device). Returns it.
func add_control_item(box_index: int, kind: ControlBoxItem.Kind) -> ControlBoxItem:
	if box_index < 0 or box_index >= control_boxes.size():
		return null
	var designation: String = ""
	var listed: Dictionary[String, bool] = control_panel_devices()
	for candidate: String in control_devices(kind):
		if not listed.has(candidate):
			designation = candidate
			break
	var item: ControlBoxItem = ControlBoxItem.new(kind, designation)
	control_boxes[box_index].items.append(item)
	return item


func remove_control_item(box_index: int, item_index: int) -> void:
	if _has_control_item(box_index, item_index):
		control_boxes[box_index].items.remove_at(item_index)


## Moves an item by [param delta] places within its box (clamped).
func move_control_item(box_index: int, item_index: int, delta: int) -> void:
	if not _has_control_item(box_index, item_index):
		return
	var items: Array[ControlBoxItem] = control_boxes[box_index].items
	var item: ControlBoxItem = items[item_index]
	items.remove_at(item_index)
	items.insert(clampi(item_index + delta, 0, items.size()), item)


## Replaces an item by one made from [method ControlBoxItem.to_data] data.
## Returns false when the data is malformed.
func set_control_item(box_index: int, item_index: int, data: Dictionary) -> bool:
	var item: ControlBoxItem = ControlBoxItem.from_data(data)
	if item == null or not _has_control_item(box_index, item_index):
		return false
	control_boxes[box_index].items[item_index] = item
	return true


## Designations of the devices that can be shown as [param kind] items, in
## the order they were added to the circuit (each device once).
func control_devices(kind: int) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for c: CircuitComponent in circuit.get_components():
		if ControlBoxItem.kind_of(c) == kind and not result.has(c.designation):
			result.append(c.designation)
	return result


## Points every control panel item (and lamp under one) showing device
## [param old_designation] to [param new_designation].
func rename_control_device(old_designation: String, new_designation: String) -> void:
	for box: ControlBox in control_boxes:
		for item: ControlBoxItem in box.items:
			if item.designation == old_designation:
				item.designation = new_designation
			if item.lamp == old_designation:
				item.lamp = new_designation


func _has_control_item(box_index: int, item_index: int) -> bool:
	return box_index >= 0 and box_index < control_boxes.size() and item_index >= 0 and item_index < control_boxes[box_index].items.size()


## Designations already shown on the panel (items and lamps under them).
func control_panel_devices() -> Dictionary[String, bool]:
	var listed: Dictionary[String, bool] = {}
	for box: ControlBox in control_boxes:
		for item: ControlBoxItem in box.items:
			listed[item.designation] = true
			if not item.lamp.is_empty():
				listed[item.lamp] = true
	return listed
