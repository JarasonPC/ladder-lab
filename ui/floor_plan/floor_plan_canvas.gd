class_name FloorPlanCanvas
extends Control
## The floor plan drawn on schematic paper (see [FloorPlan]): rooms with
## their names and areas, doors, the parts at their places with the symbols
## of Czech installation drawings ([PlanSymbols]), their designations and
## any height other than the standard one, the consumer unit and the cables
## worked out from the wiring (a tick per core). Wheel zooms at the mouse,
## right or middle drag pans.
##
## Edit mode, by [member tool]: SELECT drags rooms (with what is in them and
## the doors and windows in their walls), their edges, parts, doors and
## windows; ROOM draws a room by dragging; DOOR and WINDOW put a door or a
## window where a wall is clicked; DIMENSION adds a chain of dimensions
## along a wall clicked or one dragged between two points (both printed);
## MEASURE shows the distance dragged; PLACE puts
## [member placing] where it is clicked. Rooms snap to the walls of the
## others, switches, sockets and appliances onto the nearest wall. Delete
## takes the selection away, a double click renames a room. Simulate mode: a
## click on a switch switches its rocker (of two, the one on the side
## clicked); luminaires light up, working appliances and live sockets glow.
##
## A residential installation (its single-line diagram wires the plan, see
## [SingleLine]): WIRE draws the lighting, dragged from a switch (the side of
## a two-rocker one: which rocker) to a luminaire or another switch, drawn
## along the walls with a tick per core; PLACE also puts a new part from
## the palette ([member placing_template]) on [member circuit]; sockets and
## appliances carry their tag ("Z 6.1"), rooms their number, and beside the
## plan the legend of the rooms with their environment and illuminance.

## Changes the plan: [param change] is called with the document.
signal edit_requested(change: Callable)
## Rocker [param rocker] of light switch [param designation] was clicked.
signal switch_toggled(designation: String, rocker: int)
## Room [param index] should be renamed.
signal rename_requested(index: int)
## [member placing] was put on the plan.
signal placed
## The consumer unit should open (a click on it while simulating, a double
## click while editing).
signal unit_requested
## [member selected] changed.
signal selection_changed
## The length of wall [param side] of room [param index] should be typed
## (its other end, the right or bottom wall, moves).
signal length_requested(index: int, side: int)
## Door [param index] should be edited (its width, double, swing).
signal door_requested(index: int)
## Window [param index] should be edited (its width, sill, height).
signal window_requested(index: int)

enum Tool { SELECT, ROOM, DOOR, PLACE, WIRE, JOIN, WINDOW, DIMENSION, MEASURE }

## Pixels a metre at zoom 1.
const PX: float = 60.0
const MIN_ZOOM: float = 0.2
const MAX_ZOOM: float = 6.0
const ZOOM_STEP: float = 1.15
## Thickness of the walls drawn (m).
const WALL: float = 0.08
## The dimension and measure tools catch a corner, a part or an end of an
## opening this close (pixels).
const FEATURE_GRAB: float = 12.0
## A press this close to a room's edge (pixels) drags the edge.
const EDGE_GRAB: float = 6.0
## A part within this (m) of the mouse is under it.
const PART_GRAB: float = 0.25
## Height of the legend under the plan on a sheet (m).
const LEGEND_HEIGHT: float = 3.1
## Symbols in a column of that legend.
const LEGEND_ROWS: int = 4
const LEGEND_WIDTH: float = 16.0
const NAME_SIZE: int = 14
const TEXT_SIZE: int = 11
## The room legend of a residential installation beside the plan: its
## columns' widths and the height of a row (m).
const ROOM_COLUMNS: PackedFloat32Array = [0.9, 2.6, 3.3, 1.8]
const ROOM_ROW: float = 0.45
## A link within this (pixels) of the mouse is under it.
const LINK_GRAB: float = 6.0
## Dimension lines of the selected room: this far outside its walls (m).
const DIMENSION_GAP: float = 0.35

var document: SchematicDocument
var editing: bool = false
var tool: Tool = Tool.SELECT:
	set(value):
		tool = value
		mouse_default_cursor_shape = Control.CURSOR_CROSS if value != Tool.SELECT else Control.CURSOR_ARROW
## Designation (or [constant FloorPlan.UNIT]) put by a click with Tool.PLACE.
var placing: String = ""
## A palette template a click with Tool.PLACE makes a new part of ({} for none).
var placing_template: Dictionary = {}
## The circuit (its device) new parts go on in a residential installation.
var circuit: String = ""
var zoom: float = 1.0
## Screen position of the plan's origin.
var offset: Vector2 = Vector2(60.0, 60.0)
## Drawn for a sheet: the legend of the symbols and the standard heights
## under the plan (see [method paper_area]).
var legend: bool = false
## What is selected: {"kind": "room" / "edge" / "door" / "window" / "part" /
## "link" / "label" / "dimension", "index", "designation"}.
var selected: Dictionary = {}:
	set(value):
		var changed: bool = value != selected
		selected = value
		if changed:
			selection_changed.emit()

var _press: Dictionary = {}
var _press_at: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _mouse: Vector2 = Vector2.ZERO
var _pan_button: MouseButton = MOUSE_BUTTON_NONE
var _pan_from: Vector2 = Vector2.ZERO
## With Tool.JOIN: the room clicked first, -1 for none yet.
var _join_first: int = -1


func _ready() -> void:
	focus_mode = Control.FOCUS_CLICK
	clip_contents = true


func plan() -> FloorPlan:
	return document.floor_plan if document != null else null


## A residential installation: its plan wired by the single-line diagram.
func installation() -> bool:
	return document != null and document.environment == SchematicDocument.Kind.RESIDENTIAL


func to_plan(point: Vector2) -> Vector2:
	return (point - offset) / (PX * zoom)


func to_screen(point: Vector2) -> Vector2:
	return offset + point * PX * zoom


## What a sheet of the plan shows (m): the plan with a margin and, under
## it, room for the legend.
func paper_area() -> Rect2:
	var area: Rect2 = plan().bounds().grow(0.8)
	if not area.has_area():
		area = Rect2(0, 0, 4, 3)
	if installation() and not plan().rooms.is_empty():
		# The room legend beside the plan.
		area = area.merge(_room_legend_rect().grow(0.4))
	for i: int in plan().dimensions.size():
		var line: PackedVector2Array = _dimension_geometry(i)["line"]
		area = area.expand(line[0]).expand(line[1])
	# The legend's two columns need their width.
	return Rect2(area.position, Vector2(maxf(area.size.x, LEGEND_WIDTH), area.size.y + LEGEND_HEIGHT))


## Where the room legend of a residential installation is (m): right of the rooms.
func _room_legend_rect() -> Rect2:
	var rooms_area: Rect2 = plan().bounds()
	var width: float = 0.0
	for w: float in ROOM_COLUMNS:
		width += w
	# The rows and room under them for what the environments mean.
	return Rect2(Vector2(rooms_area.end.x + 1.2, rooms_area.position.y + 0.6), Vector2(width, ROOM_ROW * (plan().rooms.size() + 4)))


## Shows everything, as large as fits.
func fit() -> void:
	var area: Rect2 = plan().bounds() if plan() != null else Rect2()
	if installation() and not plan().rooms.is_empty():
		area = area.merge(_room_legend_rect())
	if not area.has_area() or size.x < 10.0:
		zoom = 1.0
		offset = Vector2(60.0, 60.0)
		queue_redraw()
		return
	area = area.grow(1.0)
	zoom = clampf(minf(size.x / (area.size.x * PX), size.y / (area.size.y * PX)), MIN_ZOOM, 2.0)
	offset = size * 0.5 - area.get_center() * PX * zoom
	queue_redraw()


# --- Finding things -------------------------------------------------------------------

## Where part [param designation]'s symbol is centred (m).
## Whether [param c] goes on the ceiling (a luminaire not on a wall), not
## onto the nearest wall.
static func on_ceiling(c: CircuitComponent) -> bool:
	return c is Luminaire and not (c as Luminaire).wall


func symbol_center(designation: String) -> Vector2:
	var at: Vector2 = plan().parts[designation]
	if not plan().facing.has(designation):
		return at
	var into: Vector2 = FloorPlan.FACING[plan().facing[designation]]
	return at + _face(designation) + into * 0.15


## From the line of its wall to the wall's face, for a part on a wall
## between rooms (drawn on its axis): half its thickness into the room (m).
func _face(designation: String) -> Vector2:
	if not plan().facing.has(designation):
		return Vector2.ZERO
	var into: Vector2 = FloorPlan.FACING[plan().facing[designation]]
	return into * plan().inner_wall * 0.5 if plan().inner_wall_at(plan().parts[designation], into) else Vector2.ZERO


## The part under screen point [param point], "" for none.
func part_at(point: Vector2) -> String:
	var m: Vector2 = to_plan(point)
	var best: float = PART_GRAB
	var found: String = ""
	for designation: String in plan().parts:
		var d: float = symbol_center(designation).distance_to(m)
		if d < best:
			best = d
			found = designation
	return found


## The dimension of the selected room under screen point [param point]:
## Vector2i(room, wall), (-1, -1) for none.
func dimension_at(point: Vector2) -> Vector2i:
	var index: int = _dimensioned_room()
	if index < 0:
		return Vector2i(-1, -1)
	var points: PackedVector2Array = _shown_points(index)
	var m: Vector2 = to_plan(point)
	for k: int in _dimension_walls(index):
		var line: PackedVector2Array = _dimension_line(points, k, _dimension_gap())
		if Geometry2D.get_closest_point_to_segment(m, line[0], line[1]).distance_to(m) < 0.18:
			return Vector2i(index, k)
	return Vector2i(-1, -1)


## The walls of room [param index] given dimensions: a rectangle's top and
## left, every wall of another outline.
func _dimension_walls(index: int) -> PackedInt32Array:
	if plan().rooms[index].is_rectangle():
		return PackedInt32Array([0, 3])
	return PackedInt32Array(range(plan().rooms[index].points.size()))


## The dimension line of wall [param k] of outline [param points], [param gap] outside it (m).
static func _dimension_line(points: PackedVector2Array, k: int, gap: float = DIMENSION_GAP) -> PackedVector2Array:
	var a: Vector2 = points[k]
	var b: Vector2 = points[(k + 1) % points.size()]
	var out: Vector2 = -(b - a).normalized().rotated(PI / 2.0) * gap
	return PackedVector2Array([a + out, b + out])


## How far outside its walls a room's dimensions are: past the outside wall (m).
func _dimension_gap() -> float:
	return DIMENSION_GAP + plan().outer_wall


## The room whose dimensions are shown: the one selected or whose wall is, -1.
func _dimensioned_room() -> int:
	if not editing or not (selected.get("kind", "") in ["room", "edge"]):
		return -1
	var index: int = selected.get("index", -1)
	return index if index >= 0 and index < plan().rooms.size() else -1


## The corner, the part on a wall or the end of a door or window nearest
## to plan point [param m] within [constant FEATURE_GRAB], else [param m] snapped.
func _feature_point(m: Vector2) -> Vector2:
	var best: float = FEATURE_GRAB / (PX * zoom)
	var found: Vector2 = FloorPlan.snap(m)
	var points: Array[Vector2] = []
	for room: FloorPlan.Room in plan().rooms:
		points.append_array(Array(room.points))
	for designation: String in plan().parts:
		points.append(plan().parts[designation])
	for opening: FloorPlan.Opening in plan().openings():
		points.append_array(Array(opening.ends()))
	for p: Vector2 in points:
		if p.distance_to(m) < best:
			best = p.distance_to(m)
			found = p
	return found


## Saved dimension [param index] as drawn (m): {"ends" on the wall or the
## two points, "out" (the way it is set off), "base" (where its extension
## lines start: past the outside wall for a wall), "line": its two ends,
## "stops": its cuts from the first end}.
func _dimension_geometry(index: int) -> Dictionary:
	var dim: FloorPlan.Dimension = plan().dimensions[index]
	var ends: PackedVector2Array = plan().dimension_ends(dim)
	var dir: Vector2 = (ends[1] - ends[0]).normalized()
	var out: Vector2 = dir.orthogonal()
	var base: float = 0.05
	if dim.room >= 0:
		out = -plan().rooms[dim.room].inward(dim.wall)
		base = plan().outer_wall
	var offset: float = dim.offset
	if _dragging and _press.get("kind", "") == "dimension" and _press.get("index", -1) == index:
		offset = (to_plan(_mouse) - ends[0]).dot(out) - base
	var away: Vector2 = out * (base + offset)
	return {"ends": ends, "out": out, "base": base, "line": PackedVector2Array([ends[0] + away, ends[1] + away]), "stops": plan().dimension_stops(dim), "dir": dir}


## The saved dimension under screen point [param point], -1 for none.
func saved_dimension_at(point: Vector2) -> int:
	for i: int in plan().dimensions.size():
		var line: PackedVector2Array = _dimension_geometry(i)["line"]
		if Geometry2D.get_closest_point_to_segment(point, to_screen(line[0]), to_screen(line[1])).distance_to(point) < LINK_GRAB:
			return i
	return -1


## The link of the lighting under screen point [param point], -1 for none.
func link_at(point: Vector2) -> int:
	if not installation():
		return -1
	for i: int in plan().links.size():
		var path: PackedVector2Array = _link_path(plan().links[i])
		for k: int in path.size() - 1:
			if Geometry2D.get_closest_point_to_segment(point, path[k], path[k + 1]).distance_to(point) < LINK_GRAB:
				return i
	return -1


## The way link [param link] is drawn along the walls (screen points).
func _link_path(link: FloorPlan.Link) -> PackedVector2Array:
	var a: Vector2 = to_screen(_cable_end(link.a))
	var b: Vector2 = to_screen(_cable_end(link.b))
	return PackedVector2Array([a, Vector2(b.x, a.y), b])


## The rocker or output of switch [param designation] a point on its
## symbol is on: of two, the side as seen from the room.
func _port_at(designation: String, point: Vector2) -> int:
	var sw: LightSwitch = document.circuit.get_component(designation) as LightSwitch
	if sw == null or SingleLine.switch_ports(sw).size() < 2:
		return 0
	var center: Vector2 = to_screen(symbol_center(designation))
	var into: Vector2 = FloorPlan.FACING[plan().facing.get(designation, 1)]
	return 0 if (point - center).dot(into.rotated(-PI / 2.0)) < 0.0 else 1


## The door under screen point [param point], -1 for none.
func door_at(point: Vector2) -> int:
	return _opening_at(plan().doors, point)


## The window under screen point [param point], -1 for none.
func window_at(point: Vector2) -> int:
	return _opening_at(plan().windows, point)


func _opening_at(list: Array, point: Vector2) -> int:
	var m: Vector2 = to_plan(point)
	var across: float = maxf(0.15, plan().outer_wall)
	for i: int in list.size():
		var opening: FloorPlan.Opening = list[i]
		var half: Vector2 = Vector2(across, opening.width * 0.5) if opening.vertical else Vector2(opening.width * 0.5, across)
		if Rect2(opening.at - half, half * 2.0).has_point(m):
			return i
	return -1


## The wall of a room under screen point [param point]: Vector2i(room,
## wall), (-1, -1) for none.
func edge_at(point: Vector2) -> Vector2i:
	var m: Vector2 = to_plan(point)
	var grab: float = EDGE_GRAB / (PX * zoom)
	var inside: int = plan().room_at(m)
	var order: Array[int] = []
	if inside >= 0:
		order.append(inside)
	for i: int in range(plan().rooms.size() - 1, -1, -1):
		if i != inside:
			order.append(i)
	for i: int in order:
		var room: FloorPlan.Room = plan().rooms[i]
		if not room.rect.grow(grab).has_point(m):
			continue
		for k: int in room.points.size():
			var w: PackedVector2Array = room.wall(k)
			if Geometry2D.get_closest_point_to_segment(m, w[0], w[1]).distance_to(m) <= grab:
				return Vector2i(i, k)
	return Vector2i(-1, -1)


## Where the label of room [param index] (its name or number, its area)
## starts on the screen: the baseline of its first line.
func _label_at(index: int) -> Vector2:
	var room: FloorPlan.Room = plan().rooms[index]
	var shown: FloorPlan.Room = FloorPlan.Room.new()
	shown.points = _shown_points(index)
	var corner: Vector2 = shown.corner()
	var wall: float = maxf(WALL * PX * zoom, 2.0)
	var font: Font = get_theme_default_font()
	var by: Vector2 = room.label_offset
	if _dragging and _press.get("kind", "") == "label" and _press.get("index", -1) == index:
		by += FloorPlan.snap(to_plan(_mouse) - to_plan(_press_at))
	return to_screen(corner + by) + Vector2(wall + 6.0, wall + 10.0 + font.get_ascent(NAME_SIZE))


## The room whose label is under screen point [param point], -1 for none.
func label_at(point: Vector2) -> int:
	for i: int in range(plan().rooms.size() - 1, -1, -1):
		var start: Vector2 = _label_at(i)
		if Rect2(start - Vector2(2, NAME_SIZE + 6), Vector2(72, NAME_SIZE + TEXT_SIZE + 14)).has_point(point):
			return i
	return -1


# --- Input ----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if document == null:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and editing and (key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE):
		delete_selected()
		accept_event()
		return
	if key != null and key.pressed and editing and key.keycode == KEY_F and selected.get("kind", "") == "door" and not key.ctrl_pressed:
		# F swaps the hinge, Shift+F opens the door to the other side.
		var index: int = selected["index"]
		var other_side: bool = key.shift_pressed
		edit_requested.emit(func(doc: SchematicDocument) -> void:
			var door: FloorPlan.Door = doc.floor_plan.doors[index]
			if other_side:
				door.opens_back = not door.opens_back
			else:
				door.hinge_end = not door.hinge_end)
		accept_event()
		return
	if key != null and key.pressed and editing and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER) and _dimensioned_room() >= 0:
		# Enter types the length of the wall selected (of the room: its first).
		var side: int = selected.get("side", 0) if selected.get("kind", "") == "edge" else 0
		length_requested.emit(_dimensioned_room(), side)
		accept_event()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		_on_button(mb)
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	_mouse = motion.position
	if _pan_button != MOUSE_BUTTON_NONE:
		offset += motion.relative
	elif not _press.is_empty() and not _dragging and motion.position.distance_to(_press_at) >= SchematicEditor.CLICK_SLOP:
		_dragging = true
	elif _press.is_empty():
		var over: String = part_at(motion.position)
		tooltip_text = _tooltip(over) if not over.is_empty() else ""
	if tool != Tool.SELECT or _dragging or _pan_button != MOUSE_BUTTON_NONE:
		queue_redraw()
	accept_event()


func _on_button(mb: InputEventMouseButton) -> void:
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var at: Vector2 = to_plan(mb.position)
				zoom = clampf(zoom * (ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP), MIN_ZOOM, MAX_ZOOM)
				offset = mb.position - at * PX * zoom
				queue_redraw()
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_pan_button = mb.button_index
				_pan_from = mb.position
			elif mb.button_index == _pan_button:
				_pan_button = MOUSE_BUTTON_NONE
				if mb.button_index == MOUSE_BUTTON_RIGHT and mb.position.distance_to(_pan_from) < SchematicEditor.CLICK_SLOP and tool != Tool.SELECT:
					# A right click ends drawing rooms, doors or placing.
					tool = Tool.SELECT
					placing = ""
					placing_template = {}
					placed.emit()
					queue_redraw()
		MOUSE_BUTTON_LEFT:
			if not editing:
				if mb.pressed:
					_operate(mb.position)
				return
			if mb.pressed and mb.double_click and tool == Tool.SELECT:
				var dimension: Vector2i = dimension_at(mb.position)
				if dimension.x >= 0:
					length_requested.emit(dimension.x, dimension.y)
					_press = {}
					return
				if part_at(mb.position) == FloorPlan.UNIT:
					unit_requested.emit()
					_press = {}
					return
				var door: int = door_at(mb.position)
				if door >= 0:
					door_requested.emit(door)
					_press = {}
					return
				var window: int = window_at(mb.position)
				if window >= 0:
					window_requested.emit(window)
					_press = {}
					return
				var room: int = plan().room_at(to_plan(mb.position))
				if room >= 0 and part_at(mb.position).is_empty():
					rename_requested.emit(room)
				_press = {}
				return
			if mb.pressed and tool == Tool.SELECT and dimension_at(mb.position).x >= 0:
				# A click on a dimension keeps the room selected (a double click types it).
				_press = {}
				return
			if mb.pressed:
				_press_at = mb.position
				_dragging = false
				_press = _pressed(mb.position)
				if _press["kind"] in ["room", "door", "window", "part", "edge", "link", "label", "dimension"]:
					selected = _press
				elif tool == Tool.SELECT:
					selected = {}
				queue_redraw()
			elif not _press.is_empty():
				var press: Dictionary = _press
				_press = {}
				_release(press, mb.position)
				_dragging = false
				queue_redraw()


## What a press at [param point] takes hold of.
func _pressed(point: Vector2) -> Dictionary:
	match tool:
		Tool.ROOM:
			return {"kind": "new_room"}
		Tool.DOOR:
			return {"kind": "new_door"}
		Tool.WINDOW:
			return {"kind": "new_window"}
		Tool.DIMENSION:
			return {"kind": "new_dimension"}
		Tool.MEASURE:
			return {"kind": "measure"}
		Tool.PLACE:
			return {"kind": "new_part"}
		Tool.JOIN:
			return {"kind": "join", "index": plan().room_at(to_plan(point))}
		Tool.WIRE:
			var from: String = part_at(point)
			var c: CircuitComponent = document.circuit.get_component(from) if not from.is_empty() else null
			if c is LightSwitch or c is Luminaire:
				return {"kind": "new_link", "designation": from, "port": _port_at(from, point)}
			return {"kind": "empty"}
	var part: String = part_at(point)
	if not part.is_empty():
		return {"kind": "part", "designation": part}
	var saved: int = saved_dimension_at(point)
	if saved >= 0:
		return {"kind": "dimension", "index": saved}
	var link: int = link_at(point)
	if link >= 0:
		return {"kind": "link", "index": link}
	var label: int = label_at(point)
	if label >= 0:
		return {"kind": "label", "index": label}
	var door: int = door_at(point)
	if door >= 0:
		return {"kind": "door", "index": door}
	var window: int = window_at(point)
	if window >= 0:
		return {"kind": "window", "index": window}
	var edge: Vector2i = edge_at(point)
	if edge.x >= 0:
		return {"kind": "edge", "index": edge.x, "side": edge.y}
	var room: int = plan().room_at(to_plan(point))
	if room >= 0:
		return {"kind": "room", "index": room}
	return {"kind": "empty"}


func _release(press: Dictionary, point: Vector2) -> void:
	var m: Vector2 = to_plan(point)
	var by: Vector2 = FloorPlan.snap(to_plan(point) - to_plan(_press_at))
	match press["kind"]:
		"new_room":
			var rect: Rect2 = _drawn_room()
			if rect.size.x >= FloorPlan.MIN_ROOM and rect.size.y >= FloorPlan.MIN_ROOM:
				var room_name: String = _next_room_name()
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.rooms.append(FloorPlan.Room.new(room_name, rect)))
		"new_door":
			var wall: Dictionary = plan().wall_near(m, 0.3)
			if not wall.is_empty():
				var at: Vector2 = wall["at"]
				var vertical: bool = int(wall["facing"]) % 2 == 0
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.doors.append(FloorPlan.Door.new(at, vertical)))
		"new_dimension":
			var from: Vector2 = _feature_point(to_plan(_press_at))
			var to: Vector2 = _feature_point(m)
			if not _dragging or from.distance_to(to) < 0.05:
				# A click on a wall: the chain along it.
				var edge: Vector2i = edge_at(_press_at)
				if edge.x < 0:
					return
				for dim: FloorPlan.Dimension in plan().dimensions:
					if dim.room == edge.x and dim.wall == edge.y:
						return
				edit_requested.emit(func(doc: SchematicDocument) -> void:
					var dim: FloorPlan.Dimension = FloorPlan.Dimension.new()
					dim.room = edge.x
					dim.wall = edge.y
					doc.floor_plan.dimensions.append(dim))
			else:
				edit_requested.emit(func(doc: SchematicDocument) -> void:
					var dim: FloorPlan.Dimension = FloorPlan.Dimension.new()
					dim.a = from
					dim.b = to
					doc.floor_plan.dimensions.append(dim))
		"dimension":
			if _dragging:
				var index: int = press["index"]
				var g: Dictionary = _dimension_geometry(index)
				var ends: PackedVector2Array = g["ends"]
				var offset: float = snappedf((m - ends[0]).dot(g["out"]) - float(g["base"]), FloorPlan.SNAP)
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.dimensions[index].offset = offset)
		"new_window":
			var wall: Dictionary = plan().wall_near(m, 0.3)
			if not wall.is_empty():
				var at: Vector2 = wall["at"]
				var vertical: bool = int(wall["facing"]) % 2 == 0
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.windows.append(FloorPlan.WindowOpening.new(at, vertical)))
		"new_link":
			var to: String = part_at(point)
			var c: CircuitComponent = document.circuit.get_component(to) if not to.is_empty() else null
			var from: String = press["designation"]
			if (c is LightSwitch or c is Luminaire) and to != from and (c is LightSwitch or document.circuit.get_component(from) is LightSwitch or c is Luminaire):
				var from_port: int = press["port"]
				var to_port: int = _port_at(to, point)
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.add_link(from, from_port, to, to_port))
		"new_part":
			if not placing_template.is_empty():
				var template: Dictionary = placing_template.duplicate()
				var feeder: String = circuit
				var ceiling_part: bool = template.get("type", "") == "luminaire" and not template.get("wall", false)
				edit_requested.emit(func(doc: SchematicDocument) -> void:
					var data: Dictionary = template.duplicate()
					data["designation"] = SingleLineCanvas.new_designation(doc, template)
					var part: CircuitComponent = DocumentSerializer.component_from_dict(data)
					if part == null:
						return
					doc.add(part, SingleLine.hidden_cell(doc))
					var f: SingleLine.Feeder = doc.single_line.feeder_of(feeder)
					if f != null:
						f.loads.append(part.designation)
					doc.floor_plan.place(part.designation, m, ceiling_part))
				return
			var designation: String = placing
			if not designation.is_empty():
				var ceiling: bool = on_ceiling(document.circuit.get_component(designation))
				placing = ""
				tool = Tool.SELECT
				edit_requested.emit(func(doc: SchematicDocument) -> void:
					doc.floor_plan.place(designation, m, ceiling)
					if designation == FloorPlan.UNIT:
						doc.ensure_consumer_unit())
				placed.emit()
		"part":
			if _dragging:
				var designation: String = press["designation"]
				var ceiling: bool = on_ceiling(document.circuit.get_component(designation))
				var to: Vector2 = plan().parts[designation] + by
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.place(designation, to, ceiling))
		"door":
			if _dragging:
				var index: int = press["index"]
				var wall: Dictionary = plan().wall_near(m, 0.3)
				if not wall.is_empty():
					var at: Vector2 = wall["at"]
					var vertical: bool = int(wall["facing"]) % 2 == 0
					edit_requested.emit(func(doc: SchematicDocument) -> void:
						doc.floor_plan.doors[index].at = at
						doc.floor_plan.doors[index].vertical = vertical)
		"window":
			if _dragging:
				var index: int = press["index"]
				var wall: Dictionary = plan().wall_near(m, 0.3)
				if not wall.is_empty():
					var at: Vector2 = wall["at"]
					var vertical: bool = int(wall["facing"]) % 2 == 0
					edit_requested.emit(func(doc: SchematicDocument) -> void:
						doc.floor_plan.windows[index].at = at
						doc.floor_plan.windows[index].vertical = vertical)
		"room":
			if _dragging and by != Vector2.ZERO:
				var index: int = press["index"]
				var to: Rect2 = plan().snap_room(Rect2(plan().rooms[index].rect.position + by, plan().rooms[index].rect.size), index)
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.move_room(index, to.position))
		"edge":
			if _dragging:
				var index: int = press["index"]
				var k: int = press["side"]
				var at: float = _edge_target(index, k)
				# The rooms sharing the wall keep sharing it.
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.set_edge(index, k, at))
		"label":
			if _dragging and by != Vector2.ZERO:
				var index: int = press["index"]
				var to: Vector2 = plan().rooms[index].label_offset + by
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.rooms[index].label_offset = to)
		"join":
			var index: int = press["index"]
			if index < 0:
				_join_first = -1
			elif _join_first < 0 or _join_first >= plan().rooms.size():
				_join_first = index
				selected = {"kind": "room", "index": index}
			elif index != _join_first:
				var first: int = _join_first
				_join_first = -1
				selected = {}
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.join_rooms(mini(first, index), maxi(first, index)))


## A click while simulating: a switch's rocker is switched.
func _operate(point: Vector2) -> void:
	var designation: String = part_at(point)
	if designation == FloorPlan.UNIT:
		unit_requested.emit()
		return
	var sw: LightSwitch = document.circuit.get_component(designation) as LightSwitch if not designation.is_empty() else null
	if sw == null:
		return
	var rocker: int = 0
	if sw.rocker_count() > 1:
		var center: Vector2 = to_screen(symbol_center(designation))
		var into: Vector2 = FloorPlan.FACING[plan().facing.get(designation, 1)]
		# Seen from the room, the left rocker is the first.
		rocker = 0 if (point - center).dot(into.rotated(-PI / 2.0)) < 0.0 else 1
	switch_toggled.emit(designation, rocker)


## Takes the selection away: a room (what is in it stays), a door, a
## window, or a part off the plan.
func delete_selected() -> void:
	match selected.get("kind", ""):
		"room", "edge":
			var index: int = selected["index"]
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.remove_room(index))
		"door":
			var door: int = selected["index"]
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.doors.remove_at(door))
		"window":
			var window: int = selected["index"]
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.windows.remove_at(window))
		"dimension":
			var dim: int = selected["index"]
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.dimensions.remove_at(dim))
		"part":
			var designation: String = selected["designation"]
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.remove(designation))
		"link":
			var link: int = selected["index"]
			edit_requested.emit(func(doc: SchematicDocument) -> void:
				if link < doc.floor_plan.links.size():
					doc.floor_plan.links.remove_at(link))
	selected = {}
	queue_redraw()


## The room being drawn with Tool.ROOM, snapped.
func _drawn_room() -> Rect2:
	var a: Vector2 = FloorPlan.snap(to_plan(_press_at))
	var b: Vector2 = FloorPlan.snap(to_plan(_mouse))
	var rect: Rect2 = Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
	return _snap_corners(rect)


## [param rect] with each edge snapped onto a near wall of the rooms (but
## room [param skip]).
func _snap_corners(rect: Rect2, skip: int = -1) -> Rect2:
	var edges: Array[float] = [rect.position.x, rect.position.y, rect.end.x, rect.end.y]
	for side: int in 4:
		edges[side] = _snap_edge(edges[side], side % 2 == 1, skip)
	return Rect2(Vector2(edges[0], edges[1]), Vector2(edges[2] - edges[0], edges[3] - edges[1]))


## Coordinate [param v] (y when [param horizontal_edge]) onto the nearest
## wall running the same way within [constant FloorPlan.WALL_SNAP].
func _snap_edge(v: float, horizontal_edge: bool, skip: int) -> float:
	var best: float = FloorPlan.WALL_SNAP
	var result: float = v
	for i: int in plan().rooms.size():
		if i == skip:
			continue
		var room: FloorPlan.Room = plan().rooms[i]
		for k: int in room.points.size():
			var w: PackedVector2Array = room.wall(k)
			if is_equal_approx(w[0].y, w[1].y) != horizontal_edge:
				continue
			var theirs: float = w[0].y if horizontal_edge else w[0].x
			if absf(theirs - v) < best:
				best = absf(theirs - v)
				result = theirs
	return result


## Where wall [param k] of room [param index] dragged to the mouse goes: its
## x or y snapped onto a wall running the same way, kept so the walls beside
## it stay long enough.
func _edge_target(index: int, k: int) -> float:
	var room: FloorPlan.Room = plan().rooms[index]
	var w: PackedVector2Array = room.wall(k)
	var horizontal: bool = is_equal_approx(w[0].y, w[1].y)
	var m: Vector2 = FloorPlan.snap(to_plan(_mouse))
	return FloorPlan._clamp_edge(room, k, _snap_edge(m.y if horizontal else m.x, horizontal, index))


func _next_room_name() -> String:
	var n: int = plan().rooms.size() + 1
	return tr("Room %d") % n


func _tooltip(designation: String) -> String:
	if designation == FloorPlan.UNIT:
		return tr("Consumer unit %s") % FloorPlan.UNIT + "\n" + (tr("Double-click to open it") if editing else tr("Click to open it and switch its breakers"))
	var c: CircuitComponent = document.circuit.get_component(designation)
	if c == null:
		return designation
	var text: String = "-" + designation
	if c is LightSwitch:
		text += "  " + PropertiesPanel.light_switch_title((c as LightSwitch).circuit)
		if not editing:
			text += "\n" + tr("Click to switch it")
	elif c is Appliance:
		text += "  " + ApplianceSymbol.kind_title((c as Appliance).kind)
	var height: float = float(c.get("height"))
	return text + "\n" + tr("Mounting height %s m") % String.num(height, 2).pad_decimals(2)


# --- Drawing --------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SchematicTheme.BACKGROUND)
	if document == null:
		return
	var s: float = PX * zoom
	var font: Font = get_theme_default_font()
	if editing:
		_draw_grid(s)
	var shapes: Array[PackedVector2Array] = []
	var rooms: Array[PackedVector2Array] = []
	for i: int in plan().rooms.size():
		shapes.append(_shown_points(i))
		var screen: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in shapes[i]:
			screen.append(to_screen(p))
		rooms.append(screen)
	var wall: float = maxf(WALL * s, 2.0)
	_draw_building(shapes, rooms, s)
	for i: int in rooms.size():
		var chosen: bool = selected.get("kind", "") in ["room", "edge"] and selected.get("index", -1) == i
		if chosen or i == _join_first:
			_draw_walls(rooms[i], SchematicTheme.HOVER, 2.0)
	for i: int in plan().doors.size():
		_draw_door(plan().doors[i], s, wall, selected.get("kind", "") == "door" and selected.get("index", -1) == i)
	for i: int in plan().windows.size():
		_draw_window(plan().windows[i], s, selected.get("kind", "") == "window" and selected.get("index", -1) == i)
	for i: int in rooms.size():
		# Name and area in the room's corner, clear of its ceiling light (or
		# where it was dragged to); in a residential installation its number
		# (the legend names it).
		var room: FloorPlan.Room = plan().rooms[i]
		var corner: Vector2 = _label_at(i)
		var chosen_label: bool = selected.get("kind", "") == "label" and selected.get("index", -1) == i
		if installation():
			draw_string(font, corner, plan().room_number(i), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE + 6, SchematicTheme.HOVER if chosen_label else Color(SchematicTheme.LINE, 0.75))
		else:
			draw_string(font, corner, tr(room.name), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, SchematicTheme.HOVER if chosen_label else Color(SchematicTheme.LINE, 0.55))
		var area: String = "%s m²" % String.num(room.area(), 1)
		draw_string(font, corner + Vector2(0, NAME_SIZE + 1), area, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, Color(SchematicTheme.LINE, 0.45))
	if installation():
		_draw_links(font)
	else:
		_draw_cables(s, font)
	# Each part's designation where it is clear of the other symbols and
	# designations.
	_taken = []
	for designation: String in plan().parts:
		_taken.append(_symbol_box(designation, s))
	for designation: String in plan().parts:
		_draw_part(designation, s, font)
	if editing and tool == Tool.ROOM and _press.get("kind", "") == "new_room":
		var drawn: Rect2 = _drawn_room()
		draw_rect(Rect2(to_screen(drawn.position), drawn.size * s), SchematicTheme.HOVER, false, wall)
		var dims: String = "%s × %s m" % [String.num(drawn.size.x, 2), String.num(drawn.size.y, 2)]
		draw_string(font, to_screen(drawn.end) + Vector2(6, 0), dims, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.TEXT)
	if editing and tool == Tool.PLACE and not placing.is_empty():
		var m: Vector2 = to_plan(_mouse)
		var wall_point: Dictionary = {} if on_ceiling(document.circuit.get_component(placing)) else plan().wall_near(m)
		var at: Vector2 = wall_point.get("at", FloorPlan.snap(m))
		draw_circle(to_screen(at), 4.0, SchematicTheme.HOVER)
		draw_string(font, to_screen(at) + Vector2(8, -6), ("-" if placing != FloorPlan.UNIT else "") + placing, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.DESIGNATION)
	if editing and tool == Tool.PLACE and not placing_template.is_empty():
		var m: Vector2 = to_plan(_mouse)
		var wall_point: Dictionary = {} if placing_template.get("type", "") == "luminaire" and not placing_template.get("wall", false) else plan().wall_near(m)
		draw_circle(to_screen(wall_point.get("at", FloorPlan.snap(m))), 4.0, SchematicTheme.HOVER)
	if editing and tool == Tool.WIRE and _press.get("kind", "") == "new_link":
		draw_dashed_line(to_screen(symbol_center(_press["designation"])), _mouse, SchematicTheme.HOVER, 1.6, 5.0)
	_draw_saved_dimensions(font)
	if editing and tool in [Tool.MEASURE, Tool.DIMENSION] and _press.get("kind", "") in ["measure", "new_dimension"] and _dragging:
		_draw_measure(font)
	if installation() and not plan().rooms.is_empty():
		_draw_room_legend(s, font)
	if _dimensioned_room() >= 0:
		_draw_dimensions(_dimensioned_room(), s, font)
	if legend:
		_draw_legend(s, font)
	if plan().rooms.is_empty() and editing:
		var hint: String = tr("Draw a room: pick Room and drag, or add one of the ready rooms.")
		draw_string(font, Vector2(20, 30), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, Color(SchematicTheme.LINE, 0.6))


## The legend under the plan: the symbols used and the heights parts are
## mounted at unless another one is written beside them.
func _draw_legend(s: float, font: Font) -> void:
	var area: Rect2 = paper_area()
	var top: Vector2 = to_screen(Vector2(area.position.x + 0.4, area.end.y - LEGEND_HEIGHT + 0.5))
	var color: Color = SchematicTheme.LINE
	draw_string(font, top, tr("Legend"), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, color)
	var rows: Array = [
		["switch", tr("Switch (its number: lines and ticks)"), tr("%s m over the floor") % _num(LightSwitch.STANDARD_HEIGHT)],
		["socket", tr("Socket outlet 230 V with the protective pin"), tr("%s m over the floor") % _num(SocketOutlet.STANDARD_HEIGHT)],
		["luminaire", tr("Luminaire"), tr("on the ceiling, %s m") % _num(Luminaire.STANDARD_HEIGHT)],
		["wall_luminaire", tr("Wall luminaire"), tr("%s m over the floor") % _num(Luminaire.WALL_HEIGHT)],
		["appliance", tr("Appliance, its connection"), tr("%s m over the floor") % _num(Appliance.STANDARD_HEIGHT)],
		["unit", tr("Consumer unit"), ""],
		["cable", tr("Cable, a tick per core"), ""],
	]
	var width: float = clampf(1.6 * zoom, 1.0, 2.5)
	for i: int in rows.size():
		var column: int = i / LEGEND_ROWS
		var at: Vector2 = top + Vector2(column * 8.0 * s, (0.45 + (i % LEGEND_ROWS) * 0.55) * s)
		var symbol: Vector2 = at + Vector2(0.3 * s, -0.08 * s)
		match rows[i][0]:
			"switch":
				PlanSymbols.draw_switch(self, LightSwitch.new("SF0"), symbol + Vector2(0, -0.1 * s), Vector2.DOWN, s, color, width)
			"socket":
				PlanSymbols.draw_socket(self, SocketOutlet.new("XD0"), symbol + Vector2(0, -0.1 * s), Vector2.DOWN, s, color, width, false)
			"luminaire":
				PlanSymbols.draw_luminaire(self, symbol, s, color, width, false)
			"wall_luminaire":
				PlanSymbols.draw_luminaire(self, symbol + Vector2(0, -0.15 * s), s, color, width, false, Vector2.DOWN)
			"appliance":
				PlanSymbols.draw_appliance(self, Appliance.new("EB0"), symbol + Vector2(0, -0.25 * s), Vector2.DOWN, s * 0.7, color, width, false)
			"unit":
				PlanSymbols.draw_unit(self, symbol + Vector2(0, -0.1 * s), Vector2.DOWN, s * 0.8, color, width)
			"cable":
				draw_dashed_line(symbol - Vector2(0.25 * s, 0), symbol + Vector2(0.25 * s, 0), SchematicTheme.DESIGNATION, 1.4, 6.0)
				for k: int in 3:
					var p: Vector2 = symbol + Vector2((k - 1) * 4.0, 0)
					draw_line(p + Vector2(-3, 5), p + Vector2(3, -5), SchematicTheme.DESIGNATION, 1.2, true)
		var text: String = rows[i][1] + ("  –  " + rows[i][2] if not str(rows[i][2]).is_empty() else "")
		draw_string(font, at + Vector2(0.75 * s, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.TEXT)
	var note: String = tr("Heights are to the middle of the box; a height other than these is written beside the part (h).")
	draw_string(font, top + Vector2(0, (0.45 + LEGEND_ROWS * 0.55) * s), note, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.TEXT)


static func _num(metres: float) -> String:
	return String.num(metres, 2).pad_decimals(2)


func _draw_grid(s: float) -> void:
	var from: Vector2 = to_plan(Vector2.ZERO).floor()
	var to: Vector2 = to_plan(size).ceil()
	var color: Color = Color(SchematicTheme.LINE, 0.06)
	for x: float in range(int(from.x), int(to.x) + 1):
		draw_line(to_screen(Vector2(x, from.y)), to_screen(Vector2(x, to.y)), color, 1.0)
	for y: float in range(int(from.y), int(to.y) + 1):
		draw_line(to_screen(Vector2(from.x, y)), to_screen(Vector2(to.x, y)), color, 1.0)


## The outline of room [param index] as shown: where it is dragged or a
## wall of it is dragged to.
func _shown_points(index: int) -> PackedVector2Array:
	var room: FloorPlan.Room = plan().rooms[index]
	if not _dragging or _press.get("index", -1) != index:
		return room.points
	match _press.get("kind", ""):
		"room":
			var by: Vector2 = FloorPlan.snap(to_plan(_mouse) - to_plan(_press_at))
			var to: Rect2 = plan().snap_room(Rect2(room.rect.position + by, room.rect.size), index)
			var moved: PackedVector2Array = room.points.duplicate()
			for i: int in moved.size():
				moved[i] += to.position - room.rect.position
			return moved
		"edge":
			return FloorPlan.with_edge(room.points, _press["side"], _edge_target(index, _press["side"]))
	return room.points


## Where part [param designation] is shown: where it is dragged to.
func _shown_at(designation: String) -> Vector2:
	var at: Vector2 = plan().parts[designation]
	if _dragging and _press.get("kind", "") == "part" and _press.get("designation", "") == designation:
		return FloorPlan.snap(at + to_plan(_mouse) - to_plan(_press_at))
	if _dragging and _press.get("kind", "") == "room":
		var index: int = _press["index"]
		if plan().rooms[index].contains(at, 0.01):
			return at + _shown_points(index)[0] - plan().rooms[index].points[0]
	return at


## The walls of the rooms of outlines [param shapes] ([param rooms] on the
## screen): the outside walls outside them, [member FloorPlan.outer_wall]
## thick, the walls between rooms on their line, [member
## FloorPlan.inner_wall] thick, the rooms' floors over them.
func _draw_building(shapes: Array[PackedVector2Array], rooms: Array[PackedVector2Array], s: float) -> void:
	var color: Color = wall_color()
	var outer: float = plan().outer_wall
	for shape: PackedVector2Array in shapes:
		for grown: PackedVector2Array in Geometry2D.offset_polygon(shape, outer, Geometry2D.JOIN_MITER):
			var screen: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in grown:
				screen.append(to_screen(p))
			draw_colored_polygon(screen, color)
	for outline: PackedVector2Array in rooms:
		draw_colored_polygon(outline, SchematicTheme.BACKGROUND)
		draw_colored_polygon(outline, Color(SchematicTheme.LINE, 0.03))
	var half: float = plan().inner_wall * 0.5
	for piece: PackedVector2Array in FloorPlan.inner_pieces_of(shapes):
		var dir: Vector2 = (piece[1] - piece[0]).normalized()
		var side: Vector2 = dir.orthogonal() * half
		var a: Vector2 = piece[0] - dir * half
		var b: Vector2 = piece[1] + dir * half
		draw_colored_polygon(PackedVector2Array([to_screen(a - side), to_screen(b - side), to_screen(b + side), to_screen(a + side)]), color)


## Across the wall [param opening] is in: from where to where its band
## goes (m), as offsets from the wall's line; and the way into the room.
func _band(opening: FloorPlan.Opening) -> Dictionary:
	var across: Vector2 = Vector2.RIGHT if opening.vertical else Vector2.DOWN
	var a_room: bool = plan().room_at(opening.at + across * 0.05) >= 0
	var b_room: bool = plan().room_at(opening.at - across * 0.05) >= 0
	if a_room and b_room:
		return {"from": -plan().inner_wall * 0.5, "to": plan().inner_wall * 0.5, "across": across}
	# An outside wall: outside the room.
	var out: Vector2 = -across if a_room else across
	return {"from": 0.0, "to": plan().outer_wall, "across": out}


## Cuts the wall at [param opening]: its band cleared, its jambs drawn;
## returns the band's corners [start inside, start outside, end outside, end inside] (screen).
func _cut(opening: FloorPlan.Opening) -> PackedVector2Array:
	var band: Dictionary = _band(opening)
	var ends: PackedVector2Array = opening.ends()
	var across: Vector2 = band["across"]
	var near: float = band["from"]
	var far: float = band["to"]
	var corners: PackedVector2Array = PackedVector2Array([to_screen(ends[0] + across * near), to_screen(ends[0] + across * far), to_screen(ends[1] + across * far), to_screen(ends[1] + across * near)])
	var grow: Vector2 = (corners[1] - corners[0]).normalized()
	draw_colored_polygon(PackedVector2Array([corners[0] - grow, corners[1] + grow, corners[2] + grow, corners[3] - grow]), SchematicTheme.BACKGROUND)
	draw_line(corners[0], corners[1], wall_color(), 2.0)
	draw_line(corners[3], corners[2], wall_color(), 2.0)
	return corners


## A window: its opening with the glazing, two lines along it.
func _draw_window(window: FloorPlan.WindowOpening, s: float, chosen: bool) -> void:
	var c: PackedVector2Array = _cut(window)
	var color: Color = SchematicTheme.HOVER if chosen else Color(SchematicTheme.LINE, 0.7)
	for t: float in [0.35, 0.65]:
		draw_line(c[0].lerp(c[1], t), c[3].lerp(c[2], t), color, 1.2, true)
	draw_line(c[0], c[3], color, 1.0, true)
	draw_line(c[1], c[2], color, 1.0, true)


func _draw_door(door: FloorPlan.Door, s: float, wall: float, chosen: bool) -> void:
	var along: Vector2 = Vector2.DOWN if door.vertical else Vector2.RIGHT
	var a: Vector2 = to_screen(door.at - along * door.width * 0.5)
	var b: Vector2 = to_screen(door.at + along * door.width * 0.5)
	# The opening in the wall, the leaf from its hinge and its swing.
	_cut(door)
	var color: Color = SchematicTheme.HOVER if chosen else Color(SchematicTheme.LINE, 0.7)
	var across: Vector2 = Vector2.LEFT if door.vertical else Vector2.DOWN
	if door.opens_back:
		across = -across
	# A leaf from each end for a double door, meeting in the middle.
	var leaves: Array = [[a, b], [b, a]] if door.double else [[b, a] if door.hinge_end else [a, b]]
	var length: float = door.width * s * (0.5 if door.double else 1.0)
	for leaf_ends: Array in leaves:
		var hinge: Vector2 = leaf_ends[0]
		var latch: Vector2 = leaf_ends[1]
		draw_line(hinge, hinge + across * length, color, 1.5, true)
		var start: float = (latch - hinge).angle()
		draw_arc(hinge, length, start, start + angle_difference(start, across.angle()), 16, color, 1.0, true)


## Colour of the walls: grey, apart from the symbols' lines.
static func wall_color() -> Color:
	return Color("6a707a") if SchematicTheme.dark else Color("8e9197")


## The walls along outline [param outline] (screen points), closed, the
## corners filled.
func _draw_walls(outline: PackedVector2Array, color: Color, wall: float) -> void:
	var closed: PackedVector2Array = outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, color, wall)
	for p: Vector2 in outline:
		draw_rect(Rect2(p - Vector2(wall, wall) * 0.5, Vector2(wall, wall)), color)


## Dimension lines of room [param index] as a CAD program draws them: a
## rectangle's width over its top wall and height left of its left wall,
## every wall of another outline outside it; ticks at the ends, the length
## in metres (the selected wall's in the hover colour).
func _draw_dimensions(index: int, s: float, font: Font) -> void:
	var points: PackedVector2Array = _shown_points(index)
	var wall: int = selected.get("side", -1) if selected.get("kind", "") == "edge" else -1
	for k: int in _dimension_walls(index):
		var color: Color = SchematicTheme.HOVER if k == wall else SchematicTheme.TEXT
		var line: PackedVector2Array = _dimension_line(points, k, _dimension_gap())
		var sa: Vector2 = to_screen(line[0])
		var sb: Vector2 = to_screen(line[1])
		var dir: Vector2 = (sb - sa).normalized()
		var toward: Vector2 = (to_screen(points[k]) - sa).normalized()
		draw_line(sa, sb, color, 1.0, true)
		for end: Vector2 in [sa, sb]:
			# Extension lines to the wall and a slanted tick.
			draw_line(end - toward * 4.0, end + toward * _dimension_gap() * s, color, 1.0, true)
			var tick: Vector2 = dir.rotated(PI / 4.0) * 5.0
			draw_line(end - tick, end + tick, color, 1.6, true)
		var length: float = points[k].distance_to(points[(k + 1) % points.size()])
		var text: String = SingleLineCanvas._decimal(String.num(length, 2).pad_decimals(2)) + " m"
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
		var mid: Vector2 = (sa + sb) * 0.5 - toward * 4.0
		if absf(dir.y) < 0.5:
			# Over a dimension above its wall, under one below it.
			draw_string(font, mid + Vector2(-width * 0.5, TEXT_SIZE if toward.y < 0.0 else 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)
		else:
			draw_set_transform(mid + Vector2(TEXT_SIZE * 0.8 if toward.x < 0.0 else 0.0, width * 0.5), -PI / 2.0)
			draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)
			draw_set_transform(Vector2.ZERO)


## The saved dimensions: a line with a slanted tick and an extension line
## at each cut, the length of each piece over it (the selected one in the
## hover colour).
func _draw_saved_dimensions(font: Font) -> void:
	for i: int in plan().dimensions.size():
		var g: Dictionary = _dimension_geometry(i)
		var color: Color = SchematicTheme.HOVER if selected.get("kind", "") == "dimension" and selected.get("index", -1) == i else SchematicTheme.TEXT
		var line: PackedVector2Array = g["line"]
		var ends: PackedVector2Array = g["ends"]
		var dir: Vector2 = g["dir"]
		var out: Vector2 = g["out"]
		var stops: PackedFloat32Array = g["stops"]
		draw_line(to_screen(line[0]), to_screen(line[1]), color, 1.0, true)
		for t: float in stops:
			var on: Vector2 = to_screen(line[0] + dir * t)
			var foot: Vector2 = to_screen(ends[0] + dir * t + out * float(g["base"]))
			draw_line(foot, on + (on - foot).normalized() * 4.0, color, 1.0, true)
			var tick: Vector2 = (to_screen(line[1]) - to_screen(line[0])).normalized().rotated(PI / 4.0) * 5.0
			draw_line(on - tick, on + tick, color, 1.6, true)
		for k: int in stops.size() - 1:
			_draw_length(font, to_screen(line[0] + dir * stops[k]), to_screen(line[0] + dir * stops[k + 1]), (to_screen(out) - to_screen(Vector2.ZERO)).normalized(), stops[k + 1] - stops[k], color)


## The length [param length] (m) written along the dimension line from
## [param a] to [param b] (screen), on its side [param away] from the wall.
func _draw_length(font: Font, a: Vector2, b: Vector2, away: Vector2, length: float, color: Color) -> void:
	var text: String = SingleLineCanvas._decimal(String.num(length, 2).pad_decimals(2))
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	var mid: Vector2 = (a + b) * 0.5 + away * 3.0
	var dir: Vector2 = (b - a).normalized()
	if absf(dir.y) < 0.5:
		draw_string(font, mid + Vector2(-width * 0.5, 0.0 if away.y < 0.0 else TEXT_SIZE), text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)
	else:
		draw_set_transform(mid + Vector2(0.0 if away.x < 0.0 else TEXT_SIZE * 0.8, width * 0.5), -PI / 2.0)
		draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)
		draw_set_transform(Vector2.ZERO)


## What the measure (or the dimension being dragged) spans: a dashed line
## between the points caught, its length and how far across and down.
func _draw_measure(font: Font) -> void:
	var a: Vector2 = _feature_point(to_plan(_press_at))
	var b: Vector2 = _feature_point(to_plan(_mouse))
	var sa: Vector2 = to_screen(a)
	var sb: Vector2 = to_screen(b)
	draw_dashed_line(sa, sb, SchematicTheme.HOVER, 1.5, 5.0)
	for p: Vector2 in [sa, sb]:
		draw_circle(p, 3.0, SchematicTheme.HOVER)
	var d: Vector2 = (b - a).abs()
	var text: String = "%s m   (↔ %s  ↕ %s)" % [_metres_text(a.distance_to(b)), _metres_text(d.x), _metres_text(d.y)]
	var at: Vector2 = (sa + sb) * 0.5 + Vector2(10, -10)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	draw_rect(Rect2(at + Vector2(-4, -TEXT_SIZE - 2), Vector2(width + 8, TEXT_SIZE + 8)), SchematicTheme.BACKGROUND)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.HOVER)


static func _metres_text(metres: float) -> String:
	return SingleLineCanvas._decimal(String.num(metres, 2).pad_decimals(2))


## The lighting of a residential installation: each link along the walls,
## a tick per core it carries (the nets its two ends share).
func _draw_links(font: Font) -> void:
	var nets: Dictionary[String, int] = _nets()
	for i: int in plan().links.size():
		var link: FloorPlan.Link = plan().links[i]
		if not (plan().parts.has(link.a) and plan().parts.has(link.b)):
			continue
		var chosen: bool = selected.get("kind", "") == "link" and selected.get("index", -1) == i
		var color: Color = SchematicTheme.HOVER if chosen else SchematicTheme.LINE
		var path: PackedVector2Array = _link_path(link)
		draw_polyline(path, color, clampf(1.3 * zoom, 1.0, 2.2), true)
		var shared: Dictionary[int, bool] = {}
		var a: CircuitComponent = document.circuit.get_component(link.a)
		var b: CircuitComponent = document.circuit.get_component(link.b)
		var b_nets: Dictionary[int, bool] = {}
		for key: String in b.get_terminal_keys():
			if nets.has(key):
				b_nets[nets[key]] = true
		for key: String in a.get_terminal_keys():
			if nets.has(key) and b_nets.has(nets[key]):
				shared[nets[key]] = true
		var longer: PackedVector2Array = PackedVector2Array([path[0], path[1]]) if path[0].distance_to(path[1]) >= path[1].distance_to(path[2]) else PackedVector2Array([path[1], path[2]])
		if longer[0].distance_to(longer[1]) < 1.0 or shared.is_empty():
			continue
		var mid: Vector2 = (longer[0] + longer[1]) * 0.5
		var dir: Vector2 = (longer[1] - longer[0]).normalized()
		var tick: Vector2 = dir.rotated(PI / 3.0) * 5.0
		for k: int in shared.size():
			var p: Vector2 = mid + dir * (k - (shared.size() - 1) * 0.5) * 4.0
			draw_line(p - tick, p + tick, color, 1.1, true)


## Net of each terminal key (wires joined), as roots of a union.
func _nets() -> Dictionary[String, int]:
	var index: Dictionary[String, int] = {}
	for c: CircuitComponent in document.circuit.get_components():
		for key: String in c.get_terminal_keys():
			index[key] = index.size()
	var uf: UnionFind = UnionFind.new(index.size())
	for wire: PackedStringArray in document.circuit.get_wires():
		if index.has(wire[0]) and index.has(wire[1]):
			uf.union(index[wire[0]], index[wire[1]])
	var result: Dictionary[String, int] = {}
	for key: String in index:
		result[key] = uf.find(index[key])
	return result


## The legend of the rooms of a residential installation beside the plan:
## number, purpose, environment after ČSN 33 2000-5-51, illuminance.
func _draw_room_legend(s: float, font: Font) -> void:
	var rect: Rect2 = _room_legend_rect()
	var top_left: Vector2 = to_screen(rect.position)
	var color: Color = SchematicTheme.LINE
	draw_string(font, top_left + Vector2(0, -0.2 * s), tr("Legend"), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE + 2, color)
	var heads: PackedStringArray = PackedStringArray([tr("Number"), tr("Purpose of the room"), tr("Environment (ČSN 33 2000-5-51)"), tr("Illuminance (lx)")])
	var rows: int = plan().rooms.size() + 1
	draw_rect(Rect2(top_left, Vector2(rect.size.x, rows * ROOM_ROW) * s), color, false, 1.0)
	for row: int in range(1, rows):
		var y: float = top_left.y + row * ROOM_ROW * s
		draw_line(Vector2(top_left.x, y), Vector2(top_left.x + rect.size.x * s, y), color, 1.0)
	var x: float = top_left.x
	var text_size: int = maxi(roundi(TEXT_SIZE * zoom), 6)
	for column: int in ROOM_COLUMNS.size():
		if column > 0:
			draw_line(Vector2(x, top_left.y), Vector2(x, top_left.y + rows * ROOM_ROW * s), color, 1.0)
		var width: float = ROOM_COLUMNS[column] * s - 8.0
		draw_string(font, Vector2(x + 4.0, top_left.y + ROOM_ROW * s * 0.7), heads[column], HORIZONTAL_ALIGNMENT_LEFT, width, text_size, color)
		for i: int in plan().rooms.size():
			var values: PackedStringArray = PackedStringArray([plan().room_number(i), tr(plan().rooms[i].name), plan().room_environment(i), plan().room_lux(i)])
			draw_string(font, Vector2(x + 4.0, top_left.y + (i + 1.7) * ROOM_ROW * s), values[column], HORIZONTAL_ALIGNMENT_LEFT, width, text_size, SchematicTheme.TEXT)
		x += ROOM_COLUMNS[column] * s
	# What the environments used mean, under the legend.
	var used: PackedStringArray = PackedStringArray()
	for i: int in plan().rooms.size():
		var environment: String = plan().room_environment(i)
		if not used.has(environment):
			used.append(environment)
	var y: float = top_left.y + (rows + 0.8) * ROOM_ROW * s
	for environment: String in used:
		var index: int = FloorPlan.ENVIRONMENTS.find(environment)
		if index < 0:
			continue
		var note: String = "%s – %s" % [environment, tr(FloorPlan.ENVIRONMENT_NOTES[index])]
		draw_multiline_string(font, Vector2(top_left.x, y), note, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * s, text_size - 1, -1, SchematicTheme.TEXT)
		y += (text_size + 2) * maxf(1.0, ceilf(font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size - 1).x / (rect.size.x * s)))


func _draw_cables(s: float, font: Font) -> void:
	var color: Color = SchematicTheme.DESIGNATION
	for cable: Dictionary in plan().cables(document.circuit):
		var a: Vector2 = to_screen(_cable_end(cable["a"]))
		var b: Vector2 = to_screen(_cable_end(cable["b"]))
		var corner: Vector2 = Vector2(b.x, a.y)
		draw_dashed_line(a, corner, color, 1.4, 6.0, true, true)
		draw_dashed_line(corner, b, color, 1.4, 6.0, true, true)
		# A tick per core across the longer run, a number past five.
		var longer: PackedVector2Array = PackedVector2Array([a, corner]) if a.distance_to(corner) >= corner.distance_to(b) else PackedVector2Array([corner, b])
		if longer[0].distance_to(longer[1]) < 1.0:
			continue
		var mid: Vector2 = (longer[0] + longer[1]) * 0.5
		var dir: Vector2 = (longer[1] - longer[0]).normalized()
		var tick: Vector2 = dir.rotated(PI / 3.0) * 6.0
		var cores: int = cable["cores"]
		for k: int in mini(cores, 5):
			var p: Vector2 = mid + dir * (k - (mini(cores, 5) - 1) * 0.5) * 4.0
			draw_line(p - tick, p + tick, color, 1.2, true)
		if cores > 5:
			draw_string(font, mid + dir.rotated(PI / 2.0) * 12.0, str(cores), HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)


## Where a cable to [param designation] ends: its symbol (m).
func _cable_end(designation: String) -> Vector2:
	var shown: Vector2 = _shown_at(designation)
	return shown + symbol_center(designation) - plan().parts[designation]


func _draw_part(designation: String, s: float, font: Font) -> void:
	var at: Vector2 = to_screen(_shown_at(designation) + _face(designation))
	var into: Vector2 = FloorPlan.FACING[plan().facing[designation]] if plan().facing.has(designation) else Vector2.ZERO
	var chosen: bool = selected.get("kind", "") == "part" and selected.get("designation", "") == designation
	var color: Color = SchematicTheme.HOVER if chosen else SchematicTheme.LINE
	var width: float = clampf(1.6 * zoom, 1.0, 2.5)
	var label: String = designation
	var height_text: String = ""
	if designation == FloorPlan.UNIT:
		PlanSymbols.draw_unit(self, at, into, s, color, width)
	else:
		var c: CircuitComponent = document.circuit.get_component(designation)
		label = "-" + designation
		if installation() and (c is SocketOutlet or c is Appliance):
			# Its circuit and place on it, as Czech plans tag outlets.
			var tag: String = document.single_line.tag(designation, document.circuit)
			if not tag.is_empty():
				label = tag
		if c is LightSwitch:
			PlanSymbols.draw_switch(self, c as LightSwitch, at, into, s, color, width)
			if not is_equal_approx((c as LightSwitch).height, LightSwitch.STANDARD_HEIGHT):
				height_text = _height((c as LightSwitch).height)
		elif c is SocketOutlet:
			var socket: SocketOutlet = c as SocketOutlet
			PlanSymbols.draw_socket(self, socket, at, into, s, color, width, not editing and socket.energized)
			if not is_equal_approx(socket.height, SocketOutlet.STANDARD_HEIGHT):
				height_text = _height(socket.height)
		elif c is Luminaire:
			var luminaire: Luminaire = c as Luminaire
			PlanSymbols.draw_luminaire(self, at, s, color, width, not editing and luminaire.energized, into if luminaire.wall else Vector2.ZERO)
			if not is_equal_approx(luminaire.height, luminaire.standard_height()):
				height_text = _height(luminaire.height)
		elif c is Appliance:
			PlanSymbols.draw_appliance(self, c as Appliance, at, into, s, color, width, not editing and (c as Load).energized)
			if not is_equal_approx((c as Appliance).height, Appliance.STANDARD_HEIGHT):
				height_text = _height((c as Appliance).height)
	# The designation beside the symbol, away from its wall.
	var center: Vector2 = to_screen(_shown_at(designation) + symbol_center(designation) - plan().parts[designation])
	var text_at: Vector2 = _label_spot(designation, center, into, label, height_text, s, font)
	draw_string(font, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.DESIGNATION)
	if not height_text.is_empty():
		draw_string(font, text_at + Vector2(0, TEXT_SIZE), height_text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE - 1, SchematicTheme.TEXT)


## Screen boxes of the symbols and the designations drawn so far.
var _taken: Array[Rect2] = []


## The box round the symbol of part [param designation] on screen.
func _symbol_box(designation: String, s: float) -> Rect2:
	var center: Vector2 = to_screen(_shown_at(designation) + symbol_center(designation) - plan().parts[designation])
	var half: float = 0.2 * s
	return Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)


## Where the designation [param label] (with [param height_text] under it)
## of part [param designation] goes: beside its symbol at [param center], on
## the side into the room ([param into]) first, else right, left, below or
## above, the first clear of the other symbols and designations, a step
## further out when none is. Takes the box it gets.
func _label_spot(designation: String, center: Vector2, into: Vector2, label: String, height_text: String, s: float, font: Font) -> Vector2:
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	if not height_text.is_empty():
		width = maxf(width, font.get_string_size(height_text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE - 1).x)
	var height: float = TEXT_SIZE * (2.0 if not height_text.is_empty() else 1.0)
	var ascent: float = font.get_ascent(TEXT_SIZE)
	var sides: Array[Vector2] = []
	if into != Vector2.ZERO:
		sides.append(into)
	for side: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		if not sides.has(side):
			sides.append(side)
	var own: Rect2 = _symbol_box(designation, s)
	var first: Vector2 = Vector2.INF
	for step: int in 3:
		var gap: float = 0.22 * s + 2.0 + step * TEXT_SIZE
		for side: Vector2 in sides:
			# The box's top left, its near edge [gap] from the centre.
			var corner: Vector2 = center + Vector2(gap, -2.0 - ascent)
			if side == Vector2.LEFT:
				corner = center + Vector2(-gap - width, -2.0 - ascent)
			elif side == Vector2.DOWN:
				corner = center + Vector2(-width * 0.5, gap)
			elif side == Vector2.UP:
				corner = center + Vector2(-width * 0.5, -gap - height)
			var box: Rect2 = Rect2(corner, Vector2(width, height))
			if first == Vector2.INF:
				first = corner
			var clear: bool = true
			for other: Rect2 in _taken:
				if other != own and other.intersects(box):
					clear = false
					break
			if clear:
				_taken.append(box)
				return corner + Vector2(0, ascent)
	_taken.append(Rect2(first, Vector2(width, height)))
	return first + Vector2(0, ascent)


static func _height(height: float) -> String:
	return "h %s" % String.num(height, 2).pad_decimals(2)
