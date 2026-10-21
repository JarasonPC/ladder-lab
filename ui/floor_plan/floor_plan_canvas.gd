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
## MEASURE shows the distance dragged; NOTE adds a note pointing where it
## is pressed, its text where it is let go; SCALE takes two points of the
## architect's drawing under the plan (its underlay) to set its scale,
## UNDERLAY drags it; PLACE puts
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
## The text of note [param index] should be typed (-1: a new one, at
## [member pending_note]).
signal note_requested(index: int)
## Fixture [param index] should be edited (its width and depth).
signal fixture_requested(index: int)
## The distance between plan points [param a] and [param b] on the
## underlay should be typed, to scale it.
signal scale_requested(a: Vector2, b: Vector2)

enum Tool { SELECT, ROOM, DOOR, PLACE, WIRE, JOIN, WINDOW, DIMENSION, MEASURE, NOTE, SCALE, UNDERLAY }

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
## Half the side of a selection's handle (pixels): a room's corners, a door's
## or window's ends, a fixture's corners, a free dimension's ends.
const HANDLE: float = 4.5
## A press this close to a room's edge (pixels) drags the edge.
const EDGE_GRAB: float = 6.0
## The middle of a symbol of a part on a wall is this far into the room (m);
## upright, it is drawn from this far over its middle.
const WALL_SYMBOL_OFFSET: float = 0.15
## A part within this (m) of the mouse is under it.
const PART_GRAB: float = 0.25
## Least height of the legend under the plan on a sheet (m): room for the
## scale and the north arrow.
const LEGEND_HEIGHT: float = 3.1
## Width of a column of that legend (m).
const LEGEND_COLUMN: float = 9.0
## Room for the scale bar and the north arrow right of the legend, and the
## bar's length (m).
const SCALE_ROOM: float = 7.5
const SCALE_BAR: int = 5
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
		_typed = ""
		_scale_from = Vector2(NAN, NAN)
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
## What of the installation is drawn: "" all of it, "lighting" the switches,
## luminaires and their lines, "power" the sockets and appliances (the
## building, the consumer unit and the notes always).
var layer: String = ""
## On a sheet: the scale it is printed at (50 for 1:50), 0 for none; its
## scale bar and the north arrow are drawn by the legend.
var print_scale: int = 0
## What is selected: {"kind": "room" / "edge" / "door" / "window" / "part" /
## "link" / "label" / "dimension" / "note" / "fixture", "index",
## "designation"}.
var selected: Dictionary = {}:
	set(value):
		var changed: bool = value != selected
		selected = value
		if changed:
			_typed = ""
			selection_changed.emit()

var _press: Dictionary = {}
var _press_at: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _mouse: Vector2 = Vector2.ZERO
var _pan_button: MouseButton = MOUSE_BUTTON_NONE
var _pan_from: Vector2 = Vector2.ZERO
## With Tool.JOIN: the room clicked first, -1 for none yet.
var _join_first: int = -1
## Digits typed while a part is put on a wall, or with one on a wall
## selected: its distance (mm) from the nearest corner or end of a door or
## window; Enter puts it there.
var _typed: String = ""
## A new note's point and where its text starts, while its text is asked (m).
var pending_note: Array[Vector2] = []
## With Tool.SCALE: the first point clicked (m), NAN for none yet.
var _scale_from: Vector2 = Vector2(NAN, NAN)
## Underlay images loaded, by file (null for one that could not be read).
var _underlays: Dictionary[String, Texture2D] = {}


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
	for note: FloorPlan.Note in plan().notes:
		area = area.expand(note.at).expand(note.label + Vector2(note.text.length() * 0.12, 0.3))
	# Under it the legend in as many columns as its width takes, the scale
	# and the north arrow right of them.
	var width: float = maxf(area.size.x, LEGEND_COLUMN + SCALE_ROOM + 0.8)
	return Rect2(area.position, Vector2(width, area.size.y + _legend_height(width)))


## Columns of the legend of symbols on a sheet [param width] wide (m), and
## the rows in each.
func _legend_grid(width: float) -> Vector2i:
	var count: int = maxi(legend_rows().size(), 1)
	var columns: int = clampi(floori((width - SCALE_ROOM - 0.8) / LEGEND_COLUMN), 1, count)
	return Vector2i(columns, ceili(count / float(columns)))


## Height of the legend under the plan on a sheet [param width] wide (m):
## its title, its rows, the note on the heights; at least the scale's and
## the north arrow's.
func _legend_height(width: float) -> float:
	return maxf(0.5 + _legend_grid(width).y * 0.55 + 0.8, LEGEND_HEIGHT)


## Where the room legend of a residential installation is (m): right of the rooms.
func _room_legend_rect() -> Rect2:
	var rooms_area: Rect2 = plan().bounds()
	var width: float = 0.0
	for w: float in ROOM_COLUMNS:
		width += w
	# Right of the plan unless moved (and while dragged); the rows and room
	# under them for what the environments mean.
	var by: Vector2 = plan().legend_offset
	if _dragging and _press.get("kind", "") == "room_legend":
		by += FloorPlan.snap(to_plan(_mouse) - to_plan(_press_at))
	return Rect2(Vector2(rooms_area.end.x + 1.2, rooms_area.position.y + 0.6) + by, Vector2(width, ROOM_ROW * (plan().rooms.size() + 4)))


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
	return at + _face(designation) + into * WALL_SYMBOL_OFFSET


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
	if _dragging and _press.get("kind", "") == "dimension_end" and _press.get("index", -1) == index:
		ends[int(_press["which"])] = _feature_point(to_plan(_mouse))
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


## The handles of what is selected: {"kind": "corner" / "door_end" /
## "window_end" / "fixture_corner" / "dimension_end", "index", "which",
## "at" (m), "handle": true}; dragged, they change its size or shape.
func handles() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if not editing or plan() == null:
		return list
	var index: int = selected.get("index", -1)
	match selected.get("kind", ""):
		"room", "edge":
			if index >= 0 and index < plan().rooms.size():
				var points: PackedVector2Array = _shown_points(index)
				for k: int in points.size():
					list.append({"kind": "corner", "index": index, "which": k, "at": points[k]})
		"door", "window":
			var openings: Array = plan().doors if selected["kind"] == "door" else plan().windows
			if index >= 0 and index < openings.size():
				var ends: PackedVector2Array = _shown_opening(selected["kind"], index).ends()
				for which: int in 2:
					list.append({"kind": selected["kind"] + "_end", "index": index, "which": which, "at": ends[which]})
		"fixture":
			if index >= 0 and index < plan().fixtures.size():
				var r: Rect2 = _shown_fixture_rect(index)
				var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
				for which: int in 4:
					list.append({"kind": "fixture_corner", "index": index, "which": which, "at": corners[which]})
		"dimension":
			if index >= 0 and index < plan().dimensions.size() and plan().dimensions[index].room < 0:
				var ends: PackedVector2Array = _dimension_geometry(index)["ends"]
				for which: int in 2:
					list.append({"kind": "dimension_end", "index": index, "which": which, "at": ends[which]})
	for handle: Dictionary in list:
		handle["handle"] = true
	return list


## The handle under screen point [param point], {} for none.
func handle_at(point: Vector2) -> Dictionary:
	for handle: Dictionary in handles():
		if to_screen(handle["at"]).distance_to(point) <= HANDLE + 4.0:
			return handle
	return {}


## Door or window [param kind] [param index] as shown: its end dragged.
func _shown_opening(kind: String, index: int) -> FloorPlan.Opening:
	var original: FloorPlan.Opening = plan().doors[index] if kind == "door" else plan().windows[index]
	if not (_dragging and _press.get("kind", "") == kind + "_end" and _press.get("index", -1) == index):
		return original
	var shown: FloorPlan.Opening = FloorPlan.Door.new(original.at, original.vertical, original.width) if kind == "door" else FloorPlan.WindowOpening.new(original.at, original.vertical, original.width)
	if kind == "door":
		var door: FloorPlan.Door = original as FloorPlan.Door
		(shown as FloorPlan.Door).hinge_end = door.hinge_end
		(shown as FloorPlan.Door).opens_back = door.opens_back
		(shown as FloorPlan.Door).double = door.double
	FloorPlan.stretch_opening(shown, _press["which"], to_plan(_mouse), 0.5 if kind == "door" else 0.3, 3.0 if kind == "door" else 6.0)
	return shown


## The note under screen point [param point]: {"index", "end": "anchor"
## (its point) or "label" (its text)}; {} for none.
func note_at(point: Vector2) -> Dictionary:
	var font: Font = get_theme_default_font()
	for i: int in range(plan().notes.size() - 1, -1, -1):
		var note: FloorPlan.Note = plan().notes[i]
		if to_screen(note.at).distance_to(point) < 7.0:
			return {"index": i, "end": "anchor"}
		if _note_box(note, font).grow(3.0).has_point(point):
			return {"index": i, "end": "label"}
	return {}


## The box of note [param note]'s text on the screen.
func _note_box(note: FloorPlan.Note, font: Font) -> Rect2:
	var lines: PackedStringArray = note.text.split("\n")
	var width: float = 0.0
	for line: String in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x)
	var start: Vector2 = to_screen(note.label)
	return Rect2(start - Vector2(0, font.get_ascent(TEXT_SIZE)), Vector2(maxf(width, 20.0), lines.size() * (TEXT_SIZE + 3)))


## The fixture under screen point [param point], -1 for none.
func fixture_at(point: Vector2) -> int:
	var m: Vector2 = to_plan(point)
	for i: int in range(plan().fixtures.size() - 1, -1, -1):
		if plan().fixtures[i].rect.has_point(m):
			return i
	return -1


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
	# Drawn upright: the left rocker is the first.
	var center: Vector2 = to_screen(symbol_center(designation))
	return 0 if point.x < center.x else 1


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
	if key != null and key.pressed and editing and _takes_distance() and _type_distance(key):
		accept_event()
		return
	if key != null and key.pressed and editing and (key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE):
		delete_selected()
		accept_event()
		return
	if key != null and key.pressed and editing and key.keycode == KEY_R and selected.get("kind", "") == "fixture" and not key.ctrl_pressed:
		# R turns a fixture a quarter round.
		var turned: int = selected["index"]
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.turn_fixture(turned))
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
		if tool == Tool.SELECT and editing:
			mouse_default_cursor_shape = Control.CURSOR_DRAG if not handle_at(motion.position).is_empty() else Control.CURSOR_ARROW
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
				var note: Dictionary = note_at(mb.position)
				if not note.is_empty():
					note_requested.emit(note["index"])
					_press = {}
					return
				var fixture: int = fixture_at(mb.position)
				if fixture >= 0 and part_at(mb.position).is_empty():
					fixture_requested.emit(fixture)
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
				if _press.get("handle", false) or _press["kind"] == "room_legend":
					pass
				elif _press["kind"] in ["room", "door", "window", "part", "edge", "link", "label", "dimension", "note", "fixture"]:
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
		Tool.NOTE:
			return {"kind": "new_note"}
		Tool.SCALE:
			return {"kind": "scale_point"}
		Tool.UNDERLAY:
			return {"kind": "underlay"}
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
	var handle: Dictionary = handle_at(point)
	if not handle.is_empty():
		return handle
	var part: String = part_at(point)
	if not part.is_empty():
		return {"kind": "part", "designation": part}
	var saved: int = saved_dimension_at(point)
	if saved >= 0:
		return {"kind": "dimension", "index": saved}
	var note: Dictionary = note_at(point)
	if not note.is_empty():
		return {"kind": "note", "index": note["index"], "end": note["end"]}
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
	var fixture: int = fixture_at(point)
	if fixture >= 0:
		return {"kind": "fixture", "index": fixture}
	if installation() and not plan().rooms.is_empty() and _room_legend_rect().has_point(to_plan(point)):
		return {"kind": "room_legend"}
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
		"scale_point":
			if is_nan(_scale_from.x):
				_scale_from = m
			else:
				var from: Vector2 = _scale_from
				_scale_from = Vector2(NAN, NAN)
				if from.distance_to(m) > 0.01:
					scale_requested.emit(from, m)
		"underlay":
			if _dragging and by != Vector2.ZERO:
				var moved: Vector2 = to_plan(point) - to_plan(_press_at)
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.underlay_at += moved)
		"corner":
			if _dragging:
				var index: int = press["index"]
				var k: int = press["which"]
				var to: Vector2 = FloorPlan.snap(m)
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.set_corner(index, k, to))
		"door_end", "window_end":
			if _dragging:
				var index: int = press["index"]
				var door: bool = press["kind"] == "door_end"
				var shown: FloorPlan.Opening = _shown_opening("door" if door else "window", index)
				var width: float = shown.width
				var at: Vector2 = shown.at
				edit_requested.emit(func(doc: SchematicDocument) -> void:
					var opening: FloorPlan.Opening = doc.floor_plan.doors[index] if door else doc.floor_plan.windows[index]
					opening.width = width
					opening.at = at)
		"fixture_corner":
			if _dragging:
				var index: int = press["index"]
				var rect: Rect2 = FloorPlan.stretch_rect(plan().fixtures[index].rect, press["which"], m)
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.fixtures[index].rect = rect)
		"dimension_end":
			if _dragging:
				var index: int = press["index"]
				var which: int = press["which"]
				var to: Vector2 = _feature_point(m)
				edit_requested.emit(func(doc: SchematicDocument) -> void:
					if which == 0:
						doc.floor_plan.dimensions[index].a = to
					else:
						doc.floor_plan.dimensions[index].b = to)
		"room_legend":
			if _dragging and by != Vector2.ZERO:
				var to: Vector2 = plan().legend_offset + by
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.legend_offset = to)
		"new_note":
			var anchor: Vector2 = FloorPlan.snap(to_plan(_press_at))
			var label: Vector2 = FloorPlan.snap(m) if _dragging else anchor + Vector2(0.6, -0.6)
			pending_note = [anchor, label]
			note_requested.emit(-1)
		"note":
			if _dragging and by != Vector2.ZERO:
				var index: int = press["index"]
				var anchor_end: bool = press["end"] == "anchor"
				edit_requested.emit(func(doc: SchematicDocument) -> void:
					var note: FloorPlan.Note = doc.floor_plan.notes[index]
					if anchor_end:
						note.at += by
					else:
						note.label += by)
		"fixture":
			if _dragging and by != Vector2.ZERO:
				var index: int = press["index"]
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.move_fixture(index, by))
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
			_put_part(m, false)
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


## Puts the part being placed at plan point [param m]: a new one from the
## palette on [member circuit], or [member placing]; with [param exact] at
## that very point on its wall.
func _put_part(m: Vector2, exact: bool) -> void:
	if placing_template.get("type", "") == "fixture":
		var kind: String = placing_template.get("kind", "table")
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.fixtures.append(doc.floor_plan.fixture_at_point(kind, m)))
		return
	if not placing_template.is_empty():
		var template: Dictionary = placing_template.duplicate()
		var feeder: String = circuit
		edit_requested.emit(func(doc: SchematicDocument) -> void: add_part(doc, template, feeder, m, exact))
		return
	var designation: String = placing
	if designation.is_empty():
		return
	var ceiling: bool = on_ceiling(document.circuit.get_component(designation))
	placing = ""
	tool = Tool.SELECT
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		if exact and not ceiling:
			doc.floor_plan.place_on_wall(designation, m)
		else:
			doc.floor_plan.place(designation, m, ceiling)
		if designation == FloorPlan.UNIT:
			doc.ensure_consumer_unit())
	placed.emit()


## Makes a part of [param template] in [param doc], fed by circuit
## [param feeder] (a device; none for ""), and puts it at [param at] on the
## plan (onto the nearest wall unless it goes on the ceiling; with
## [param exact] at that very point, facing [param face] when given).
## Returns its designation ("" if none was made).
static func add_part(doc: SchematicDocument, template: Dictionary, feeder: String, at: Vector2, exact: bool = false, face: int = -1) -> String:
	var data: Dictionary = template.duplicate()
	data["designation"] = SingleLineCanvas.new_designation(doc, template)
	var part: CircuitComponent = DocumentSerializer.component_from_dict(data)
	if part == null:
		return ""
	doc.add(part, SingleLine.hidden_cell(doc))
	var f: SingleLine.Feeder = doc.single_line.feeder_of(feeder)
	if f != null:
		f.loads.append(part.designation)
	if exact and not on_ceiling(part):
		doc.floor_plan.place_on_wall(part.designation, at, face)
	else:
		doc.floor_plan.place(part.designation, at, on_ceiling(part))
	# A socket behind a kitchen worktop goes over it.
	if part is SocketOutlet and doc.floor_plan.over_worktop(doc.floor_plan.parts[part.designation]):
		(part as SocketOutlet).height = FloorPlan.WORKTOP_SOCKET_HEIGHT
	return part.designation


## Whether a distance can be typed: a part on a wall being placed, or one
## selected.
func _takes_distance() -> bool:
	if tool == Tool.PLACE:
		if placing_template.get("type", "") == "fixture":
			return false
		if not placing_template.is_empty():
			return not (placing_template.get("type", "") == "luminaire" and not placing_template.get("wall", false))
		return not placing.is_empty() and not on_ceiling(document.circuit.get_component(placing))
	return tool == Tool.SELECT and selected.get("kind", "") == "part" and plan().facing.has(str(selected.get("designation", "")))


## A key while a distance can be typed: digits make it, Backspace takes the
## last one back, Enter puts the part there, Escape forgets it. Returns
## whether the key was taken.
func _type_distance(key: InputEventKey) -> bool:
	var ch: String = String.chr(key.unicode) if key.unicode > 0 else ""
	if ch.length() == 1 and ch >= "0" and ch <= "9" and _typed.length() < 6:
		_typed += ch
		queue_redraw()
		return true
	if _typed.is_empty():
		return false
	match key.keycode:
		KEY_BACKSPACE:
			_typed = _typed.left(-1)
		KEY_ESCAPE:
			_typed = ""
		KEY_ENTER, KEY_KP_ENTER:
			var distance: float = float(_typed) / 1000.0
			_typed = ""
			var target: Vector2 = _distance_target(distance)
			if is_nan(target.x):
				return true
			if tool == Tool.PLACE:
				_put_part(target, true)
			else:
				var designation: String = selected["designation"]
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.place_on_wall(designation, target))
		_:
			return false
	queue_redraw()
	return true


## Where the part goes [param distance] (m) from the reference on its wall:
## the wall under the mouse while placing, the selected part's wall; NAN
## when there is no wall.
func _distance_target(distance: float) -> Vector2:
	var from: Vector2 = _distance_point()
	if is_nan(from.x):
		return from
	return plan().at_distance(from, distance)


## The point on a wall a distance is measured to: where the part being
## placed would go, or the selected part; NAN for none.
func _distance_point() -> Vector2:
	if tool == Tool.PLACE:
		var wall: Dictionary = plan().wall_near(to_plan(_mouse))
		return wall["at"] if not wall.is_empty() else Vector2(NAN, NAN)
	if selected.get("kind", "") == "part" and plan().parts.has(str(selected.get("designation", ""))):
		return plan().parts[selected["designation"]]
	return Vector2(NAN, NAN)


## While a part goes on a wall or one there is selected: its distance from
## the nearest corner or end of a door or window as a dimension in the
## room, and the distance typed.
func _draw_wall_distance(font: Font) -> void:
	if not editing or not _takes_distance():
		return
	var point: Vector2 = _distance_point()
	if is_nan(point.x):
		return
	if not _typed.is_empty():
		point = plan().at_distance(point, float(_typed) / 1000.0)
	var ref: Dictionary = plan().wall_reference(point)
	if ref.is_empty():
		return
	var wall: Dictionary = plan().wall_near(point, 0.05)
	var into: Vector2 = FloorPlan.FACING[int(wall.get("facing", 1))]
	var from: Vector2 = ref["from"]
	var color: Color = SchematicTheme.SELECTED
	var a: Vector2 = to_screen(from + into * 0.35)
	var b: Vector2 = to_screen(point + into * 0.35)
	draw_line(a, b, color, 1.0, true)
	for end: Array in [[from, a], [point, b]]:
		draw_line(to_screen(end[0]), end[1] + (end[1] - to_screen(end[0])).normalized() * 4.0, color, 1.0, true)
		var tick: Vector2 = (b - a).normalized().rotated(PI / 4.0) * 5.0 if a.distance_to(b) > 0.5 else Vector2(4, -4)
		draw_line(end[1] - tick, end[1] + tick, color, 1.6, true)
	if a.distance_to(b) > 1.0:
		_draw_length(font, a, b, (to_screen(into) - to_screen(Vector2.ZERO)).normalized(), from.distance_to(point), color)
	if not _typed.is_empty():
		draw_circle(to_screen(point), 4.0, color)
		var text: String = _typed + " mm  ↵"
		var at: Vector2 = to_screen(point) + Vector2(12, -14)
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
		draw_rect(Rect2(at + Vector2(-4, -TEXT_SIZE - 2), Vector2(width + 8, TEXT_SIZE + 8)), SchematicTheme.BACKGROUND)
		draw_rect(Rect2(at + Vector2(-4, -TEXT_SIZE - 2), Vector2(width + 8, TEXT_SIZE + 8)), color, false, 1.0)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)


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
		# Drawn upright: the left rocker is the first.
		rocker = 0 if point.x < center.x else 1
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
		"note":
			var note: int = selected["index"]
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.notes.remove_at(note))
		"fixture":
			var fixture: int = selected["index"]
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.fixtures.remove_at(fixture))
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
	_draw_underlay(s)
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
			_draw_walls(rooms[i], SchematicTheme.SELECTED, 2.0)
	for i: int in plan().doors.size():
		_draw_door(_shown_opening("door", i), s, wall, selected.get("kind", "") == "door" and selected.get("index", -1) == i)
	for i: int in plan().windows.size():
		_draw_window(_shown_opening("window", i), s, selected.get("kind", "") == "window" and selected.get("index", -1) == i)
	for i: int in rooms.size():
		# Name and area in the room's corner, clear of its ceiling light (or
		# where it was dragged to); in a residential installation its number
		# (the legend names it).
		var room: FloorPlan.Room = plan().rooms[i]
		var corner: Vector2 = _label_at(i)
		var chosen_label: bool = selected.get("kind", "") == "label" and selected.get("index", -1) == i
		if installation():
			draw_string(font, corner, plan().room_number(i), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE + 6, SchematicTheme.SELECTED if chosen_label else Color(SchematicTheme.LINE, 0.75))
		else:
			draw_string(font, corner, tr(room.name), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, SchematicTheme.SELECTED if chosen_label else Color(SchematicTheme.LINE, 0.55))
		var area: String = "%s m²" % String.num(room.area(), 1)
		draw_string(font, corner + Vector2(0, NAME_SIZE + 1), area, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, Color(SchematicTheme.LINE, 0.45))
	for i: int in plan().fixtures.size():
		var fixture: FloorPlan.Fixture = plan().fixtures[i]
		var chosen_fixture: bool = selected.get("kind", "") == "fixture" and selected.get("index", -1) == i
		_draw_fixture(fixture, _shown_fixture_rect(i), SchematicTheme.SELECTED if chosen_fixture else Color(SchematicTheme.LINE, 0.4))
	if editing and tool == Tool.PLACE and placing_template.get("type", "") == "fixture":
		var ghost: FloorPlan.Fixture = plan().fixture_at_point(str(placing_template.get("kind", "table")), to_plan(_mouse))
		_draw_fixture(ghost, ghost.rect, SchematicTheme.SELECTED)
	if installation():
		if layer != "power":
			_draw_links(font)
	else:
		_draw_cables(s, font)
	# Each part's designation where it is clear of the other symbols and
	# designations.
	_taken = []
	for designation: String in plan().parts:
		if layer_shows(designation):
			_taken.append(_symbol_box(designation, s))
	for designation: String in plan().parts:
		if layer_shows(designation):
			_draw_part(designation, s, font)
	if editing and tool == Tool.ROOM and _press.get("kind", "") == "new_room":
		var drawn: Rect2 = _drawn_room()
		draw_rect(Rect2(to_screen(drawn.position), drawn.size * s), SchematicTheme.SELECTED, false, wall)
		var dims: String = "%s × %s m" % [String.num(drawn.size.x, 2), String.num(drawn.size.y, 2)]
		draw_string(font, to_screen(drawn.end) + Vector2(6, 0), dims, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.TEXT)
	if editing and tool == Tool.PLACE and not placing.is_empty():
		var m: Vector2 = to_plan(_mouse)
		var wall_point: Dictionary = {} if on_ceiling(document.circuit.get_component(placing)) else plan().wall_near(m)
		var at: Vector2 = wall_point.get("at", FloorPlan.snap(m))
		draw_circle(to_screen(at), 4.0, SchematicTheme.SELECTED)
		draw_string(font, to_screen(at) + Vector2(8, -6), ("-" if placing != FloorPlan.UNIT else "") + placing, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.DESIGNATION)
	if editing and tool == Tool.PLACE and not placing_template.is_empty():
		var m: Vector2 = to_plan(_mouse)
		var wall_point: Dictionary = {} if placing_template.get("type", "") == "luminaire" and not placing_template.get("wall", false) else plan().wall_near(m)
		draw_circle(to_screen(wall_point.get("at", FloorPlan.snap(m))), 4.0, SchematicTheme.SELECTED)
	if editing and tool == Tool.WIRE and _press.get("kind", "") == "new_link":
		draw_dashed_line(to_screen(symbol_center(_press["designation"])), _mouse, SchematicTheme.SELECTED, 1.6, 5.0)
	_draw_saved_dimensions(font)
	_draw_wall_distance(font)
	_draw_notes(font)
	for handle: Dictionary in handles():
		var c: Vector2 = to_screen(handle["at"])
		var box: Rect2 = Rect2(c - Vector2(HANDLE, HANDLE), Vector2(HANDLE, HANDLE) * 2.0)
		draw_rect(box, SchematicTheme.BACKGROUND)
		draw_rect(box, SchematicTheme.SELECTED, false, 1.5)
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


## Whether part [param designation] is drawn on the layer shown
## ([member layer]).
func layer_shows(designation: String) -> bool:
	if layer.is_empty() or designation == FloorPlan.UNIT:
		return true
	var c: CircuitComponent = document.circuit.get_component(designation)
	if layer == "lighting":
		return c is LightSwitch or c is Luminaire
	return c is SocketOutlet or c is Appliance


## The rows of the legend: a symbol used on the plan shown (on its layer),
## each {"key", "sample" (a part drawn so; null for the unit and the cable),
## "title", "height" (its standard height as written, "" for none), "count"},
## switches by their number, sockets single and double, ceiling and wall
## luminaires, appliances by kind, then the consumer unit and the cable.
func legend_rows() -> Array[Dictionary]:
	var rows: Dictionary[String, Dictionary] = {}
	for designation: String in plan().parts:
		if not layer_shows(designation):
			continue
		var key: String = ""
		var row: Dictionary = {}
		var c: CircuitComponent = document.circuit.get_component(designation)
		if designation == FloorPlan.UNIT:
			key = "6"
			row = {"title": tr("Consumer unit"), "height": ""}
		elif c is LightSwitch:
			var circuit_number: String = (c as LightSwitch).circuit
			key = "0" + circuit_number
			row = {"title": tr("Switch %s") % PropertiesPanel.light_switch_title(circuit_number), "height": tr("%s m over the floor") % _num(LightSwitch.STANDARD_HEIGHT)}
		elif c is SocketOutlet:
			var gangs: int = (c as SocketOutlet).gangs
			key = "1%d" % gangs
			row = {"title": tr("Double socket outlet 230 V with the protective pin") if gangs > 1 else tr("Socket outlet 230 V with the protective pin"), "height": tr("%s m over the floor") % _num(SocketOutlet.STANDARD_HEIGHT)}
		elif c is Luminaire:
			var wall: bool = (c as Luminaire).wall
			key = "3" if wall else "2"
			row = {"title": tr("Wall luminaire") if wall else tr("Luminaire"), "height": tr("%s m over the floor") % _num(Luminaire.WALL_HEIGHT) if wall else tr("on the ceiling, %s m") % _num(Luminaire.STANDARD_HEIGHT)}
		elif c is Appliance:
			var kind: int = (c as Appliance).kind
			key = "4%02d" % kind
			row = {"title": ApplianceSymbol.kind_title(kind), "height": tr("its connection %s m over the floor") % _num(Appliance.STANDARD_HEIGHT)}
		else:
			continue
		if rows.has(key):
			rows[key]["count"] += 1
		else:
			row["key"] = key
			row["sample"] = c
			row["count"] = 1
			rows[key] = row
	var cabled: bool = not plan().links.is_empty() if installation() else not plan().cables(document.circuit).is_empty()
	if layer != "power" and cabled:
		rows["7"] = {"key": "7", "sample": null, "title": tr("Cable, a tick per core"), "height": "", "count": 0}
	var keys: Array = rows.keys()
	keys.sort()
	var result: Array[Dictionary] = []
	for key: String in keys:
		result.append(rows[key])
	return result


## The legend under the plan: the symbols on it with how many there are,
## and the heights they are mounted at unless another one is written beside them.
func _draw_legend(s: float, font: Font) -> void:
	var rows: Array[Dictionary] = legend_rows()
	if rows.is_empty():
		return
	var area: Rect2 = paper_area()
	var band: float = _legend_height(area.size.x)
	var rows_in_column: int = _legend_grid(area.size.x).y
	var top: Vector2 = to_screen(Vector2(area.position.x + 0.4, area.end.y - band + 0.5))
	var color: Color = SchematicTheme.LINE
	draw_string(font, top, tr("Legend"), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, color)
	var width: float = clampf(1.6 * zoom, 1.0, 2.5)
	for i: int in rows.size():
		var column: int = i / rows_in_column
		var at: Vector2 = top + Vector2(column * LEGEND_COLUMN * s, (0.45 + (i % rows_in_column) * 0.55) * s)
		var symbol: Vector2 = at + Vector2(0.3 * s, -0.08 * s)
		var sample: CircuitComponent = rows[i]["sample"]
		match str(rows[i]["key"]).left(1):
			"0":
				PlanSymbols.draw_switch(self, sample as LightSwitch, symbol + Vector2(0, -0.1 * s), Vector2.DOWN, s, color, width)
			"1":
				PlanSymbols.draw_socket(self, sample as SocketOutlet, symbol + Vector2(0, -0.1 * s), Vector2.DOWN, s, color, width, false)
			"2":
				PlanSymbols.draw_luminaire(self, symbol, s, color, width, false)
			"3":
				PlanSymbols.draw_luminaire(self, symbol + Vector2(0, -0.15 * s), s, color, width, false, Vector2.DOWN)
			"4":
				PlanSymbols.draw_appliance(self, sample as Appliance, symbol + Vector2(0, -0.25 * s), Vector2.DOWN, s * 0.7, color, width, false)
			"6":
				PlanSymbols.draw_unit(self, symbol + Vector2(0, -0.1 * s), Vector2.DOWN, s * 0.8, color, width)
			"7":
				draw_dashed_line(symbol - Vector2(0.25 * s, 0), symbol + Vector2(0.25 * s, 0), SchematicTheme.DESIGNATION, 1.4, 6.0)
				for k: int in 3:
					var p: Vector2 = symbol + Vector2((k - 1) * 4.0, 0)
					draw_line(p + Vector2(-3, 5), p + Vector2(3, -5), SchematicTheme.DESIGNATION, 1.2, true)
		var text: String = str(rows[i]["title"]) + ("  –  " + str(rows[i]["height"]) if not str(rows[i]["height"]).is_empty() else "")
		draw_string(font, at + Vector2(0.75 * s, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.TEXT)
		if int(rows[i]["count"]) > 0:
			var count: String = "%d×" % int(rows[i]["count"])
			var count_width: float = font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
			draw_string(font, at + Vector2((LEGEND_COLUMN - 0.6) * s - count_width, 0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.TEXT)
	_draw_scale_and_north(s, font, area)
	var note: String = tr("Heights are to the middle of the box; a height other than these is written beside the part (h).")
	draw_string(font, top + Vector2(0, (0.45 + rows_in_column * 0.55) * s), note, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.TEXT)


## At the right of the legend band of the sheet [param area]: the north
## arrow, the scale and its bar of metres.
func _draw_scale_and_north(s: float, font: Font, area: Rect2) -> void:
	var color: Color = SchematicTheme.LINE
	var top: float = area.end.y - _legend_height(area.size.x) + 0.5
	var left: float = area.end.x - SCALE_ROOM + 0.4
	# North: an arrow half filled, "N" at its tip.
	var c: Vector2 = to_screen(Vector2(area.end.x - 0.8, top + 1.0))
	var up: Vector2 = Vector2.UP.rotated(deg_to_rad(plan().north))
	var r: float = 0.45 * s
	var tip: Vector2 = c + up * r
	var back: Vector2 = c - up * r
	var side: Vector2 = up.orthogonal() * r * 0.45
	draw_colored_polygon(PackedVector2Array([tip, back - side * 0.0 + up * r * 0.25, back + side]), color)
	draw_polyline(PackedVector2Array([tip, back + side, c - up * r * 0.6, back - side, tip]), color, 1.2, true)
	# The first letter of north in the language (N, S for sever).
	var north_text: String = tr("N (north)").left(1)
	var nw: float = font.get_string_size(north_text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	draw_string(font, tip + up * 12.0 + Vector2(-nw * 0.5, NAME_SIZE * 0.4), north_text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, color)
	if print_scale <= 0:
		return
	# The scale and a bar of [constant SCALE_BAR] metres, true to the plan,
	# every other one filled.
	var bar_top: Vector2 = to_screen(Vector2(left, top + 1.3))
	draw_string(font, to_screen(Vector2(left, top + 0.6)), tr("Scale 1:%d") % print_scale, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, color)
	for k: int in SCALE_BAR:
		var cell: Rect2 = Rect2(bar_top + Vector2(k * s, 0), Vector2(s, 0.12 * s))
		if k % 2 == 0:
			draw_rect(cell, color)
		draw_rect(cell, color, false, 1.0)
	for k: int in SCALE_BAR + 1:
		var label: String = str(k)
		var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
		draw_string(font, bar_top + Vector2(k * s - lw * 0.5, 0.12 * s + TEXT_SIZE + 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)
	draw_string(font, bar_top + Vector2(SCALE_BAR * s + 8.0, 0.12 * s), "m", HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)


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
		"corner":
			var n: int = room.points.size()
			var k: int = _press["which"]
			var to: Vector2 = FloorPlan.snap(to_plan(_mouse))
			var shaped: PackedVector2Array = room.points
			for wall: int in [(k + n - 1) % n, k]:
				var w0: Vector2 = shaped[wall]
				var w1: Vector2 = shaped[(wall + 1) % n]
				var vertical: bool = is_equal_approx(w0.x, w1.x)
				var probe: FloorPlan.Room = FloorPlan.Room.new()
				probe.points = shaped
				shaped = FloorPlan.with_edge(shaped, wall, FloorPlan._clamp_edge(probe, wall, to.x if vertical else to.y))
			return shaped
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
	var color: Color = SchematicTheme.SELECTED if chosen else Color(SchematicTheme.LINE, 0.7)
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
	var color: Color = SchematicTheme.SELECTED if chosen else Color(SchematicTheme.LINE, 0.7)
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
		var color: Color = SchematicTheme.SELECTED if k == wall else SchematicTheme.TEXT
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
			# Across, beside a dimension up and down, on its side away from the wall.
			draw_string(font, mid + Vector2(-width - 2.0 if toward.x > 0.0 else 2.0, TEXT_SIZE * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)


## The underlay image of a file (null when it cannot be read), kept once read.
func underlay_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not _underlays.has(path):
		var image: Image = Image.load_from_file(path) if FileAccess.file_exists(path) else null
		_underlays[path] = ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null
	return _underlays[path]


## The architect's drawing under the plan, faint (not on a sheet), where it
## is dragged to with Tool.UNDERLAY; the first point taken with Tool.SCALE.
func _draw_underlay(s: float) -> void:
	if legend or not plan().underlay_shown:
		return
	var texture: Texture2D = underlay_texture(plan().underlay)
	if texture != null:
		var at: Vector2 = plan().underlay_at
		if _dragging and _press.get("kind", "") == "underlay":
			at += to_plan(_mouse) - to_plan(_press_at)
		draw_texture_rect(texture, Rect2(to_screen(at), texture.get_size() * plan().underlay_scale * s), false, Color(1, 1, 1, 0.35))
	if tool == Tool.SCALE and not is_nan(_scale_from.x):
		draw_circle(to_screen(_scale_from), 4.0, SchematicTheme.SELECTED)
		draw_dashed_line(to_screen(_scale_from), _mouse, SchematicTheme.SELECTED, 1.5, 5.0)


## Fixture [param fixture] over plan rectangle [param rect] in [param color].
func _draw_fixture(fixture: FloorPlan.Fixture, rect: Rect2, color: Color) -> void:
	var screen: Rect2 = Rect2(to_screen(rect.position), rect.size * PX * zoom)
	PlanSymbols.draw_fixture(self, fixture.kind, screen, FloorPlan.FACING[fixture.facing], color, clampf(1.0 * zoom, 1.0, 1.6))


## Where fixture [param index] is shown: where it is dragged to.
func _shown_fixture_rect(index: int) -> Rect2:
	var rect: Rect2 = plan().fixtures[index].rect
	if _dragging and _press.get("kind", "") == "fixture" and _press.get("index", -1) == index:
		rect.position += FloorPlan.snap(to_plan(_mouse) - to_plan(_press_at))
	elif _dragging and _press.get("kind", "") == "fixture_corner" and _press.get("index", -1) == index:
		rect = FloorPlan.stretch_rect(rect, _press["which"], to_plan(_mouse))
	return rect


## The notes: a dot where each points, a leader to its text, the text
## underlined (the one selected, or being dragged, in the selection colour).
func _draw_notes(font: Font) -> void:
	for i: int in plan().notes.size():
		var note: FloorPlan.Note = plan().notes[i]
		var at: Vector2 = note.at
		var label: Vector2 = note.label
		if _dragging and _press.get("kind", "") == "note" and _press.get("index", -1) == i:
			var by: Vector2 = FloorPlan.snap(to_plan(_mouse) - to_plan(_press_at))
			if _press["end"] == "anchor":
				at += by
			else:
				label += by
		var color: Color = SchematicTheme.SELECTED if selected.get("kind", "") == "note" and selected.get("index", -1) == i else SchematicTheme.TEXT
		var shown: FloorPlan.Note = FloorPlan.Note.new()
		shown.text = note.text
		shown.label = label
		var box: Rect2 = _note_box(shown, font)
		var under: float = box.position.y + TEXT_SIZE + 4.0
		# The leader to the nearer end of the first line's underline.
		var near_end: Vector2 = Vector2(box.position.x if to_screen(at).x <= box.get_center().x else box.end.x, under)
		draw_circle(to_screen(at), 2.6, color)
		draw_line(to_screen(at), near_end, color, 1.0, true)
		draw_line(Vector2(box.position.x, under), Vector2(box.end.x, under), color, 1.0, true)
		var lines: PackedStringArray = note.text.split("\n")
		for k: int in lines.size():
			draw_string(font, to_screen(label) + Vector2(0, k * (TEXT_SIZE + 3)), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)


## The saved dimensions: a line with a slanted tick and an extension line
## at each cut, the length of each piece over it (the selected one in the
## hover colour).
func _draw_saved_dimensions(font: Font) -> void:
	for i: int in plan().dimensions.size():
		var g: Dictionary = _dimension_geometry(i)
		var color: Color = SchematicTheme.SELECTED if selected.get("kind", "") == "dimension" and selected.get("index", -1) == i else SchematicTheme.TEXT
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
		# Across, beside a dimension up and down, on its side away from the wall.
		draw_string(font, mid + Vector2(-width - 2.0 if away.x < 0.0 else 2.0, TEXT_SIZE * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)


## What the measure (or the dimension being dragged) spans: a dashed line
## between the points caught, its length and how far across and down.
func _draw_measure(font: Font) -> void:
	var a: Vector2 = _feature_point(to_plan(_press_at))
	var b: Vector2 = _feature_point(to_plan(_mouse))
	var sa: Vector2 = to_screen(a)
	var sb: Vector2 = to_screen(b)
	draw_dashed_line(sa, sb, SchematicTheme.SELECTED, 1.5, 5.0)
	for p: Vector2 in [sa, sb]:
		draw_circle(p, 3.0, SchematicTheme.SELECTED)
	var d: Vector2 = (b - a).abs()
	var text: String = "%s m   (↔ %s  ↕ %s)" % [_metres_text(a.distance_to(b)), _metres_text(d.x), _metres_text(d.y)]
	var at: Vector2 = (sa + sb) * 0.5 + Vector2(10, -10)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	draw_rect(Rect2(at + Vector2(-4, -TEXT_SIZE - 2), Vector2(width + 8, TEXT_SIZE + 8)), SchematicTheme.BACKGROUND)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.SELECTED)


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
		var color: Color = SchematicTheme.SELECTED if chosen else SchematicTheme.LINE
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
	var into: Vector2 = FloorPlan.FACING[plan().facing[designation]] if plan().facing.has(designation) else Vector2.ZERO
	# Every symbol upright, as in the legend and the palette, whatever wall
	# it is on: its middle where it is, drawn from above it; but a socket
	# outlet turned to face into the room from its wall.
	var middle: Vector2 = _shown_at(designation) + symbol_center(designation) - plan().parts[designation]
	var upright: Vector2 = Vector2.DOWN if into != Vector2.ZERO else Vector2.ZERO
	var at: Vector2 = to_screen(middle - upright * WALL_SYMBOL_OFFSET)
	var chosen: bool = selected.get("kind", "") == "part" and selected.get("designation", "") == designation
	var color: Color = SchematicTheme.SELECTED if chosen else SchematicTheme.LINE
	var width: float = clampf(1.6 * zoom, 1.0, 2.5)
	var label: String = designation
	var height_text: String = ""
	if designation == FloorPlan.UNIT:
		PlanSymbols.draw_unit(self, at, upright, s, color, width)
	else:
		var c: CircuitComponent = document.circuit.get_component(designation)
		label = "-" + designation
		if installation() and (c is SocketOutlet or c is Appliance):
			# Its circuit and place on it, as Czech plans tag outlets.
			var tag: String = document.single_line.tag(designation, document.circuit)
			if not tag.is_empty():
				label = tag
		if c is LightSwitch:
			PlanSymbols.draw_switch(self, c as LightSwitch, at, upright, s, color, width)
			if not is_equal_approx((c as LightSwitch).height, LightSwitch.STANDARD_HEIGHT):
				height_text = _height((c as LightSwitch).height)
		elif c is SocketOutlet:
			var socket: SocketOutlet = c as SocketOutlet
			PlanSymbols.draw_socket(self, socket, to_screen(_shown_at(designation) + _face(designation)), into, s, color, width, not editing and socket.energized)
			if not is_equal_approx(socket.height, SocketOutlet.STANDARD_HEIGHT):
				height_text = _height(socket.height)
		elif c is Luminaire:
			var luminaire: Luminaire = c as Luminaire
			PlanSymbols.draw_luminaire(self, at, s, color, width, not editing and luminaire.energized, upright if luminaire.wall else Vector2.ZERO)
			if not is_equal_approx(luminaire.height, luminaire.standard_height()):
				height_text = _height(luminaire.height)
		elif c is Appliance:
			PlanSymbols.draw_appliance(self, c as Appliance, at, upright, s, color, width, not editing and (c as Load).energized)
			if not is_equal_approx((c as Appliance).height, Appliance.STANDARD_HEIGHT):
				height_text = _height((c as Appliance).height)
	# The designation beside the symbol, away from its wall.
	var center: Vector2 = to_screen(middle)
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
