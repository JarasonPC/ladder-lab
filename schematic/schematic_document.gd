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
	return _placements.get(component_id, null)


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


## Cells where three or more wire or lead directions meet, drawn as dots.
func junction_cells() -> Array[Vector2i]:
	var directions: Dictionary[Vector2i, int] = {}
	for i: int in _routes.size():
		var points: Array[Vector2i] = wire_points(i)
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
		if count >= 3:
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


func _terminal_name(owner: CircuitComponent, key: String) -> String:
	var keys: PackedStringArray = owner.get_terminal_keys()
	return owner.get_terminal_names()[keys.find(key)]
