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
## windows; ROOM draws a room by dragging or by two clicks (its width and
## depth typed in mm, Tab between them, Enter); OUTLINE draws one by
## clicking its corners (walls across or up and down, a wall's length
## typed; a click on the first corner, a double click, Enter or a right
## click closes it); WALL draws walls on their own, or splits a room by
## walls drawn from its wall across it to its wall; PLACE_ROOM puts a
## ready room ([member placing_room]) where it is clicked; DOOR and WINDOW
## put a door or a window where a wall is clicked; DIMENSION adds a chain of dimensions
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
## The user's own symbols ([CustomSymbol]) come from the palette too: a
## drawing-only one as a mark ([FloorPlan.Mark]), an electrical one as an
## appliance drawn with it.
##
## Layers ([member SchematicDocument.plan_layers]): parts, notes, dimensions,
## fixtures and marks on a hidden one are neither drawn nor picked (nor the
## lines of a hidden part); new ones go on [member active_layer]; a right
## click on one asks for the layer it goes on.

## Changes the plan: [param change] is called with the document.
signal edit_requested(change: Callable)
## Room [param index] was just drawn, put in or split off (to be named).
signal room_drawn(index: int)
## The menu of room [param index] should open at screen point [param at]
## (a right click on it).
signal room_menu_requested(index: int, at: Vector2)
## The layer menu of what is selected (a part, note, dimension, fixture or
## mark right-clicked) should open at screen point [param at].
signal layer_menu_requested(at: Vector2)
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
## [member tool] was set.
signal tool_changed
## The length of wall [param side] of room [param index] should be typed
## (its other end, the right or bottom wall, moves).
signal length_requested(index: int, side: int)
## A free wall was double-clicked: its length, direction and thickness are asked.
signal free_wall_requested(index: int)
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

enum Tool { SELECT, ROOM, DOOR, PLACE, WIRE, JOIN, WINDOW, DIMENSION, MEASURE, NOTE, SCALE, UNDERLAY, OUTLINE, PLACE_ROOM, WALL }

## Pixels a metre at zoom 1.
const PX: float = 60.0
## Slanting walls are drawn at a whole number of these (degrees).
const ANGLE_STEP: float = 15.0
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
## Width of a new garage door (m).
const GARAGE_WIDTH: float = 2.5
## A press this close to a room's edge (pixels) drags the edge.
const EDGE_GRAB: float = 6.0
## The middle of a symbol of a part on a wall is this far into the room (m);
## upright, it is drawn from this far over its middle.
const WALL_SYMBOL_OFFSET: float = 0.15
## How far past the middle of a wall part's symbol the handle moving it off
## its wall is (m at symbol size 1).
const OFFSET_HANDLE: float = 0.32
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


## Text size [param size] as the plan has its texts: larger or smaller by
## its text size.
func _sized(size: int) -> int:
	return maxi(roundi(size * (plan().text_scale if plan() != null else 1.0)), 4)


## How large the symbols are drawn (1 as usual).
func _symbols() -> float:
	return plan().symbol_scale if plan() != null else 1.0
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
		_room_from = Vector2(NAN, NAN)
		_corners = PackedVector2Array()
		_split_room = -1
		_room_typed = PackedStringArray(["", ""])
		_room_field = 0
		if value != Tool.PLACE_ROOM:
			placing_room = -1
		mouse_default_cursor_shape = Control.CURSOR_CROSS if value != Tool.SELECT else Control.CURSOR_ARROW
		tool_changed.emit()
## The ready room ([constant FloorPlan.PRESETS]) Tool.PLACE_ROOM puts, -1 for none.
var placing_room: int = -1
## Designation (or [constant FloorPlan.UNIT]) put by a click with Tool.PLACE.
var placing: String = ""
## A palette template a click with Tool.PLACE makes a new part of ({} for none).
var placing_template: Dictionary = {}
## The circuit (its number, 0 for none) new parts go on in a residential
## installation; made, waiting for its protection, when none has it yet;
## [constant SingleLine.BY_KIND]: by the kind of each part.
var circuit: int = SingleLine.BY_KIND
var zoom: float = 1.0
## Screen position of the plan's origin.
var offset: Vector2 = Vector2(60.0, 60.0)
## Drawn for a sheet: the legend of the symbols and the standard heights
## under the plan (see [method paper_area]).
var legend: bool = false
## The layer new parts, notes, dimensions, fixtures and marks go on ("" none).
var active_layer: String = ""
## On a sheet: the scale it is printed at (50 for 1:50), 0 for none; its
## scale bar and the north arrow are drawn by the legend.
var print_scale: int = 0
## What is selected: {"kind": "room" / "edge" / "door" / "window" / "part" /
## "link" / "label" / "dimension" / "note" / "fixture" / "mark", "index",
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
## What the mouse is over in Edit mode with Tool.SELECT, to light it up:
## {"kind": "handle" / "edge" / "room", "index", "side"}; {} for nothing.
var _hover: Dictionary = {}
## With Tool.ROOM: the first corner clicked (m), NAN while none is.
var _room_from: Vector2 = Vector2(NAN, NAN)
## With Tool.OUTLINE: the corners clicked so far (m).
var _corners: PackedVector2Array = PackedVector2Array()
## The room whose wall the walls being drawn started on, -1 for none: while
## they run inside it they wait (in [member _corners]) to split it once they
## end on its wall.
var _split_room: int = -1
## The [enum FloorPlan.DoorKind] a door put in with Tool.DOOR is (the one
## last chosen in the door dialog).
var door_kind: int = FloorPlan.DoorKind.SWING
## The rooms as the corner or wall being dragged leaves them, and what they
## were worked out for (see [method _room_preview]).
var _preview: FloorPlan = null
var _preview_key: Array = []
## The width and depth typed for a room being drawn (mm; with
## Tool.OUTLINE the first is the next wall's length), and which is typed.
var _room_typed: PackedStringArray = PackedStringArray(["", ""])
var _room_field: int = 0
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
		if not shows(plan().dimensions[i]):
			continue
		var line: PackedVector2Array = _dimension_geometry(i)["line"]
		area = area.expand(line[0]).expand(line[1])
	for note: FloorPlan.Note in plan().notes:
		if shows(note):
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
	return maxf(0.5 + _legend_grid(width).y * _legend_row() + 0.8, LEGEND_HEIGHT)


## The legend's rows apart (m): more for larger symbols or texts.
func _legend_row() -> float:
	return 0.55 * maxf(1.0, maxf(_symbols(), plan().text_scale))


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
	return (c is Luminaire and not (c as Luminaire).wall) or (c is Appliance and (c as Appliance).ceiling)


## Whether a part made from palette template [param template] goes where it
## is clicked rather than onto the nearest wall.
func _template_on_ceiling(template: Dictionary) -> bool:
	match template.get("type", ""):
		"luminaire":
			return not template.get("wall", false)
		"appliance":
			return template.get("ceiling", false) == true
		"custom_symbol":
			var def: CustomSymbol = template_symbol(document, template)
			return def == null or not def.wall
	return false


## The user's symbol palette template [param template] is drawn with: the
## library's (the schematic takes it when it is put in), else the
## schematic's copy; null for none.
static func template_symbol(doc: SchematicDocument, template: Dictionary) -> CustomSymbol:
	var id: String = str(template.get("symbol", ""))
	if id.is_empty():
		return null
	var def: CustomSymbol = SymbolLibrary.shared().find(id)
	return def if def != null else doc.symbol(id)


func symbol_center(designation: String) -> Vector2:
	var at: Vector2 = plan().parts[designation]
	if not plan().facing.has(designation):
		return at
	var into: Vector2 = FloorPlan.FACING[plan().facing[designation]]
	return at + _face(designation) + into * (WALL_SYMBOL_OFFSET * _symbols() + _offset(designation))


## How far part [param designation]'s symbol is off its wall (m; its handle
## dragged: where it goes).
func _offset(designation: String) -> float:
	if _dragging and _press.get("kind", "") == "part_offset" and _press.get("designation", "") == designation:
		return _dragged_offset(designation, _mouse)
	return plan().offsets.get(designation, 0.0)


## The offset of part [param designation]'s symbol from its wall with its
## handle dragged from the press to screen point [param point].
func _dragged_offset(designation: String, point: Vector2) -> float:
	var into: Vector2 = FloorPlan.FACING[plan().facing[designation]]
	var offset: float = plan().offsets.get(designation, 0.0) + (to_plan(point) - to_plan(_press_at)).dot(into)
	return clampf(snappedf(offset, 0.01), 0.0, FloorPlan.MAX_OFFSET)


## From the line of its wall to the wall's face, for a part on a wall
## between rooms (drawn on its axis): half its thickness into the room (m).
func _face(designation: String) -> Vector2:
	if not plan().facing.has(designation):
		return Vector2.ZERO
	var into: Vector2 = FloorPlan.FACING[plan().facing[designation]]
	return into * plan().wall_face(plan().parts[designation], into)


## The part under screen point [param point], "" for none.
func part_at(point: Vector2) -> String:
	var m: Vector2 = to_plan(point)
	var best: float = PART_GRAB * maxf(_symbols(), 1.0)
	var found: String = ""
	for designation: String in plan().parts:
		if not layer_shows(designation):
			continue
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
		if layer_shows(designation):
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
					# A wall selected: the corners at its ends.
					if selected["kind"] == "room" or k == int(selected.get("side", -1)) or k == (int(selected.get("side", -1)) + 1) % points.size():
						list.append({"kind": "corner", "index": index, "which": k, "at": points[k]})
		"free_wall":
			if index >= 0 and index < plan().walls.size():
				var ends: PackedVector2Array = _shown_free_wall(index)
				for which: int in 2:
					list.append({"kind": "free_wall_end", "index": index, "which": which, "at": ends[which]})
		"door", "window":
			var openings: Array = plan().doors if selected["kind"] == "door" else plan().windows
			if index >= 0 and index < openings.size():
				var shown: FloorPlan.Opening = _shown_opening(selected["kind"], index)
				var ends: PackedVector2Array = shown.ends()
				for which: int in 2:
					list.append({"kind": selected["kind"] + "_end", "index": index, "which": which, "at": ends[which]})
				if selected["kind"] == "door":
					# Dragged to another corner of the door, it turns the door:
					# its hinges to that end, opening to that side.
					list.append({"kind": "door_swing", "index": index, "at": door_corner(shown as FloorPlan.Door)})
		"fixture":
			if index >= 0 and index < plan().fixtures.size():
				var r: Rect2 = _shown_fixture_rect(index)
				var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
				for which: int in 4:
					list.append({"kind": "fixture_corner", "index": index, "which": which, "at": corners[which]})
		"part":
			# On a wall: its symbol dragged off the wall, clear of it.
			var designation: String = str(selected.get("designation", ""))
			if plan().facing.has(designation):
				var into: Vector2 = FloorPlan.FACING[plan().facing[designation]]
				var middle: Vector2 = _shown_at(designation) + symbol_center(designation) - plan().parts[designation]
				list.append({"kind": "part_offset", "designation": designation, "at": middle + into * OFFSET_HANDLE * _symbols()})
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


## Door or window [param kind] [param index] as shown while something is
## dragged: its end stretched, itself moved onto the wall under the mouse,
## or moved along with its room or its wall.
func _shown_opening(kind: String, index: int) -> FloorPlan.Opening:
	var original: FloorPlan.Opening = plan().doors[index] if kind == "door" else plan().windows[index]
	if not _dragging:
		return original
	var pressed: String = _press.get("kind", "")
	var own: bool = _press.get("index", -1) == index
	var shown: FloorPlan.Opening = FloorPlan.Door.new(original.at, original.vertical, original.width) if kind == "door" else FloorPlan.WindowOpening.new(original.at, original.vertical, original.width)
	if kind == "door":
		var door: FloorPlan.Door = original as FloorPlan.Door
		(shown as FloorPlan.Door).hinge_end = door.hinge_end
		(shown as FloorPlan.Door).opens_back = door.opens_back
		(shown as FloorPlan.Door).double = door.double
		(shown as FloorPlan.Door).kind = door.kind
	if pressed == "door_swing" and own and kind == "door":
		var turned: Vector2i = _door_turn(shown as FloorPlan.Door, to_plan(_mouse))
		(shown as FloorPlan.Door).hinge_end = turned.x == 1
		(shown as FloorPlan.Door).opens_back = turned.y == 1
	elif pressed == kind + "_end" and own:
		FloorPlan.stretch_opening(shown, _press["which"], to_plan(_mouse), FloorPlan.DOOR_MIN_WIDTH if kind == "door" else 0.3, FloorPlan.DOOR_MAX_WIDTH if kind == "door" else 6.0)
	elif pressed == kind and own:
		var wall: Dictionary = plan().wall_near(to_plan(_mouse), 0.3)
		if wall.is_empty() or not wall["straight"]:
			return original
		shown.at = wall["at"]
		shown.vertical = int(wall["facing"]) % 2 == 0
	elif pressed in ["edge", "corner"]:
		var moved: Vector2 = _wall_drag_shift(original.at, true)
		shown.at += moved
	else:
		var by: Vector2 = _room_drag_shift(original.at)
		if by == Vector2.ZERO:
			return original
		shown.at += by
	return shown


## How far something at [param point] moves with the room being dragged
## (zero when no room is dragged or it is not in it).
func _room_drag_shift(point: Vector2) -> Vector2:
	if not _dragging or _press.get("kind", "") != "room":
		return Vector2.ZERO
	var index: int = _press["index"]
	if index < 0 or index >= plan().rooms.size() or not plan().rooms[index].contains(point, 0.01):
		return Vector2.ZERO
	return _shown_points(index)[0] - plan().rooms[index].points[0]


## How far something on a wall at [param point] moves while a wall or a
## corner is dragged: along with the wall it is on, keeping its share of the
## way along it (see [method _room_preview]); a door or window
## ([param opening]) only while that wall stays straight the same way.
func _wall_drag_shift(point: Vector2, opening: bool = false) -> Vector2:
	var preview: FloorPlan = _room_preview()
	if preview == null:
		return Vector2.ZERO
	for i: int in plan().rooms.size():
		var before: PackedVector2Array = plan().rooms[i].points
		if i >= preview.rooms.size() or preview.rooms[i].points.size() != before.size():
			continue
		for k: int in before.size():
			var a: Vector2 = before[k]
			var b: Vector2 = before[(k + 1) % before.size()]
			if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) > 0.01:
				continue
			var after: PackedVector2Array = preview.rooms[i].wall(k)
			if after[0] == a and after[1] == b:
				continue
			if opening and not (FloorPlan.is_straight(after) and is_equal_approx(a.x, b.x) == is_equal_approx(after[0].x, after[1].x)):
				return Vector2.ZERO
			var length: float = a.distance_to(b)
			var t: float = a.distance_to(point) / length if length > 0.001 else 0.0
			return after[0].lerp(after[1], t) - point
	return Vector2.ZERO


## The note under screen point [param point]: {"index", "end": "anchor"
## (its point) or "label" (its text)}; {} for none.
func note_at(point: Vector2) -> Dictionary:
	var font: Font = get_theme_default_font()
	for i: int in range(plan().notes.size() - 1, -1, -1):
		var note: FloorPlan.Note = plan().notes[i]
		if not shows(note):
			continue
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
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE)).x)
	var start: Vector2 = to_screen(note.label)
	return Rect2(start - Vector2(0, font.get_ascent(_sized(TEXT_SIZE))), Vector2(maxf(width, 20.0), lines.size() * (_sized(TEXT_SIZE) + 3)))


## The fixture under screen point [param point], -1 for none.
func fixture_at(point: Vector2) -> int:
	var m: Vector2 = to_plan(point)
	for i: int in range(plan().fixtures.size() - 1, -1, -1):
		if shows(plan().fixtures[i]) and plan().fixtures[i].rect.has_point(m):
			return i
	return -1


## The mark under screen point [param point], -1 for none.
func mark_at(point: Vector2) -> int:
	var m: Vector2 = to_plan(point)
	for i: int in range(plan().marks.size() - 1, -1, -1):
		if shows(plan().marks[i]) and _mark_box(i).grow(0.05).has_point(m):
			return i
	return -1


## Where the origin of mark [param index]'s symbol is drawn (m): on a wall
## [constant WALL_SYMBOL_OFFSET] over its middle, as the other wall symbols
## (dragged: where it goes).
func _mark_origin(index: int) -> Vector2:
	var mark: FloorPlan.Mark = plan().marks[index]
	var at: Vector2 = mark.at + _room_drag_shift(mark.at)
	var facing: int = mark.facing
	if _dragging and _press.get("kind", "") == "mark" and _press.get("index", -1) == index:
		var moved: FloorPlan.Mark = plan().mark_at_point(mark.symbol, mark.at + FloorPlan.snap(to_plan(_mouse) - to_plan(_press_at)), mark.facing >= 0)
		at = moved.at
		facing = moved.facing if moved.facing >= 0 else facing
	if facing < 0:
		return at
	var into: Vector2 = FloorPlan.FACING[facing]
	var face: Vector2 = into * plan().wall_face(at, into)
	return at + face + (into - Vector2.DOWN) * WALL_SYMBOL_OFFSET * _symbols()


## What mark [param index]'s symbol covers (m).
func _mark_box(index: int) -> Rect2:
	var def: CustomSymbol = document.symbol(plan().marks[index].symbol)
	var box: Rect2 = def.bounds() if def != null else Rect2(-0.15, -0.15, 0.3, 0.3)
	return Rect2(box.position * _symbols() + _mark_origin(index), box.size * _symbols())


## The saved dimension under screen point [param point], -1 for none.
func saved_dimension_at(point: Vector2) -> int:
	for i: int in plan().dimensions.size():
		if not shows(plan().dimensions[i]):
			continue
		var line: PackedVector2Array = _dimension_geometry(i)["line"]
		if Geometry2D.get_closest_point_to_segment(point, to_screen(line[0]), to_screen(line[1])).distance_to(point) < LINK_GRAB:
			return i
	return -1


## The link of the lighting under screen point [param point], -1 for none.
func link_at(point: Vector2) -> int:
	if not installation():
		return -1
	for i: int in plan().links.size():
		if not _link_shown(plan().links[i]) or is_nan(_link_end(plan().links[i].a).x) or is_nan(_link_end(plan().links[i].b).x):
			continue
		var path: PackedVector2Array = _link_path(plan().links[i])
		for k: int in path.size() - 1:
			if Geometry2D.get_closest_point_to_segment(point, path[k], path[k + 1]).distance_to(point) < LINK_GRAB:
				return i
	return -1


## The way link [param link] is drawn along the walls (screen points).
func _link_path(link: FloorPlan.Link) -> PackedVector2Array:
	var a: Vector2 = to_screen(_link_end(link.a))
	var b: Vector2 = to_screen(_link_end(link.b))
	return PackedVector2Array([a, Vector2(b.x, a.y), b])


## Where a link to [param designation] ends (m): its symbol, or the part of
## the floor above or below shown in a staircase; NAN for neither.
func _link_end(designation: String) -> Vector2:
	if plan().parts.has(designation):
		return _cable_end(designation)
	var ghosts: Dictionary = stair_ghosts()
	return Vector2(ghosts[designation]["at"]) if ghosts.has(designation) else Vector2(NAN, NAN)


## The light switches and luminaires of the floors above and below this one
## that are in a staircase (of either floor), shown in it so the lighting
## can be drawn to them: designation -> {"at" (m, where its symbol is),
## "floor" (its index), "up" (above this one)}.
func stair_ghosts() -> Dictionary:
	var result: Dictionary = {}
	if document == null or not installation() or document.floors.size() < 2:
		return result
	var here: int = document.floor
	var stairs: Array[PackedVector2Array] = []
	for room: FloorPlan.Room in plan().rooms:
		if room.stairs:
			stairs.append(room.points)
	for other: int in [here - 1, here + 1]:
		if other < 0 or other >= document.floors.size():
			continue
		var there: FloorPlan = document.floors[other]
		var their_stairs: Array[PackedVector2Array] = stairs.duplicate()
		for room: FloorPlan.Room in there.rooms:
			if room.stairs:
				their_stairs.append(room.points)
		for designation: String in there.parts:
			var c: CircuitComponent = document.circuit.get_component(designation) if designation != FloorPlan.UNIT else null
			if not (c is LightSwitch or c is Luminaire) or plan().parts.has(designation):
				continue
			var at: Vector2 = there.parts[designation]
			var inside: bool = false
			for shape: PackedVector2Array in their_stairs:
				if Geometry2D.is_point_in_polygon(at, shape) or FloorPlan.wall_through(shape, at) >= 0:
					inside = true
			if not inside:
				continue
			if there.facing.has(designation):
				at += FloorPlan.FACING[there.facing[designation]] * WALL_SYMBOL_OFFSET * _symbols()
			result[designation] = {"at": at, "floor": other, "up": other > here}
	return result


## The part of the floor above or below shown in a staircase under screen
## point [param point], "" for none.
func ghost_at(point: Vector2) -> String:
	var m: Vector2 = to_plan(point)
	var ghosts: Dictionary = stair_ghosts()
	var best: String = ""
	var reach: float = maxf(0.25 * _symbols(), EDGE_GRAB / (PX * zoom))
	for designation: String in ghosts:
		var d: float = Vector2(ghosts[designation]["at"]).distance_to(m)
		if d < reach:
			reach = d
			best = designation
	return best


## The floor drawn under the one shown while editing (to draw this one over
## it): the one below, for the lowest the one above; -1 for none.
func reference_floor() -> int:
	if document == null or not editing or document.floors.size() < 2:
		return -1
	return document.floor - 1 if document.floor > 0 else 1


## The corners of the floor drawn under this one (see
## [method reference_floor]): of its building's outlines inside and out of
## its outside walls and of its staircases (m).
func _reference_corners() -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var index: int = reference_floor()
	if index < 0:
		return result
	var there: FloorPlan = document.floors[index]
	for outline: PackedVector2Array in there.building_outlines():
		result.append_array(outline)
		for grown: PackedVector2Array in Geometry2D.offset_polygon(outline, there.outer_wall, Geometry2D.JOIN_MITER):
			result.append_array(grown)
	for room: FloorPlan.Room in there.rooms:
		if room.stairs:
			result.append_array(room.points)
	return result


## The floor under this one (see [method reference_floor]) as dash-dot lines:
## its outside walls and its staircases, its name by them; never where this
## floor has a wall already (it is drawn there).
func _draw_reference(font: Font) -> void:
	var index: int = reference_floor()
	if index < 0:
		return
	var there: FloorPlan = document.floors[index]
	var color: Color = Color(SchematicTheme.LINE, 0.5)
	var lines: Array[PackedVector2Array] = []
	var top_left: Vector2 = Vector2(INF, INF)
	for outline: PackedVector2Array in there.building_outlines():
		lines.append(outline)
		lines.append_array(Geometry2D.offset_polygon(outline, there.outer_wall, Geometry2D.JOIN_MITER))
		for p: Vector2 in outline:
			top_left = Vector2(minf(top_left.x, p.x), minf(top_left.y, p.y))
	for room: FloorPlan.Room in there.rooms:
		if room.stairs:
			lines.append(room.points)
	var shown: bool = false
	for line: PackedVector2Array in lines:
		var closed: PackedVector2Array = line.duplicate()
		closed.append(line[0])
		for piece: PackedVector2Array in _off_walls(closed):
			CustomSymbol.stroke_line(self, _screen_points(piece), color, 1.2, "dashdot")
			shown = true
	if shown and top_left.x < INF:
		var at: Vector2 = to_screen(top_left - Vector2(0.0, there.outer_wall)) + Vector2(0, -6)
		draw_string(font, at, "%s %s" % ["↓" if index < document.floor else "↑", there.floor_name()], HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), color)


## The stretches of polyline [param line] (m) not on a wall of this floor:
## not within the band its rooms' walls take (a little to spare).
func _off_walls(line: PackedVector2Array) -> Array[PackedVector2Array]:
	var visible: Array[PackedVector2Array] = [line]
	for room: FloorPlan.Room in plan().rooms:
		var offsets: PackedFloat32Array = PackedFloat32Array()
		for k: int in room.points.size():
			var own: float = room.wall_thickness(k)
			offsets.append(own if own > 0.0 else plan().outer_wall)
		var outer: Array[PackedVector2Array] = Geometry2D.offset_polygon(FloorPlan.grown(room.points, offsets), 0.03, Geometry2D.JOIN_MITER)
		var inner: Array[PackedVector2Array] = Geometry2D.offset_polygon(room.points, -0.03, Geometry2D.JOIN_MITER)
		if outer.is_empty():
			continue
		var next: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in visible:
			next.append_array(Geometry2D.clip_polyline_with_polygon(piece, outer[0]))
			# Inside the room itself it shows again.
			for inside: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(piece, outer[0]):
				for floor_shape: PackedVector2Array in inner:
					next.append_array(Geometry2D.intersect_polyline_with_polygon(inside, floor_shape))
		visible = next
	return visible


## The zones of the bathrooms round baths and shower trays (ČSN 33
## 2000-7-701): zone 1 over each tinted, zone 2 dashed round it, each
## numbered.
func _draw_bath_zones(font: Font) -> void:
	var color: Color = Color(0.25, 0.55, 0.95)
	for zone: Dictionary in plan().bath_zones():
		var points: PackedVector2Array = _screen_points(zone["points"])
		var box: Rect2 = Rect2(points[0], Vector2.ZERO)
		for p: Vector2 in points:
			box = box.expand(p)
		if int(zone["zone"]) == 1:
			draw_colored_polygon(points, Color(color, 0.12))
			draw_string(font, box.position + Vector2(4, _sized(TEXT_SIZE) + 2), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), Color(color, 0.9))
		else:
			var closed: PackedVector2Array = points.duplicate()
			closed.append(points[0])
			CustomSymbol.stroke_line(self, closed, Color(color, 0.7), 1.0, "dash")
			draw_string(font, box.position + Vector2(4, _sized(TEXT_SIZE) + 2), "2", HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), Color(color, 0.9))


## The parts of the floors above and below in a staircase, faint, each with
## its floor and the way to it.
func _draw_stair_ghosts(font: Font, s: float) -> void:
	var ghosts: Dictionary = stair_ghosts()
	var color: Color = Color(SchematicTheme.LINE, 0.45)
	var width: float = clampf(1.6 * zoom, 1.0, 2.5)
	for designation: String in ghosts:
		var ghost: Dictionary = ghosts[designation]
		var at: Vector2 = to_screen(ghost["at"])
		var c: CircuitComponent = document.circuit.get_component(designation)
		if c is LightSwitch:
			PlanSymbols.draw_switch(self, c as LightSwitch, at, Vector2.DOWN, s * _symbols(), color, width)
		else:
			PlanSymbols.draw_luminaire(self, at, s * _symbols(), color, width, false, Vector2.ZERO)
		var floor_name: String = document.floors[int(ghost["floor"])].floor_name()
		var text: String = "-%s %s %s" % [designation, "↑" if ghost["up"] else "↓", floor_name]
		draw_string(font, at + Vector2(10, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), Color(SchematicTheme.DESIGNATION, 0.6))


## The rocker or output of switch [param designation] a point on its
## symbol is on: of two, the side as seen from the room.
func _port_at(designation: String, point: Vector2) -> int:
	var sw: LightSwitch = document.circuit.get_component(designation) as LightSwitch
	if sw == null or SingleLine.switch_ports(sw).size() < 2:
		return 0
	# Drawn upright: the left rocker is the first.
	var center: Vector2 = to_screen(symbol_center(designation) if plan().parts.has(designation) else _link_end(designation))
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
	# A few pixels more all round, so that a thin one is easy to take.
	var slack: float = EDGE_GRAB / (PX * zoom)
	for i: int in range(list.size() - 1, -1, -1):
		var opening: FloorPlan.Opening = list[i]
		var half: Vector2 = Vector2(across, opening.width * 0.5) if opening.vertical else Vector2(opening.width * 0.5, across)
		if Rect2(opening.at - half, half * 2.0).grow(slack).has_point(m):
			return i
		if opening is FloorPlan.Door and _door_swing_box(opening as FloorPlan.Door).grow(slack).has_point(m):
			# Its leaf and the way it swings.
			return i
	return -1


## The door a click with Tool.DOOR puts in at [param at] on a wall
## ([param vertical] running up and down): of [member door_kind], a garage
## door wider.
func _new_door(at: Vector2, vertical: bool) -> FloorPlan.Door:
	var door: FloorPlan.Door = FloorPlan.Door.new(at, vertical, GARAGE_WIDTH if door_kind == FloorPlan.DoorKind.GARAGE else FloorPlan.DOOR_WIDTH)
	door.kind = door_kind
	return door


## The way door [param door] opens into the room from its wall (m, a unit).
static func door_across(door: FloorPlan.Door) -> Vector2:
	var across: Vector2 = Vector2.LEFT if door.vertical else Vector2.DOWN
	return -across if door.opens_back else across


## Where the leaf of door [param door] reaches open: the corner of the
## square it swings in away from its hinge (of a double door, of the first
## leaf; of a sliding, folding or garage door, as far into the room).
func door_corner(door: FloorPlan.Door) -> Vector2:
	var along: Vector2 = Vector2.DOWN if door.vertical else Vector2.RIGHT
	var hinge: Vector2 = door.at + along * door.width * 0.5 * (1.0 if door.hinge_end else -1.0)
	var reach: float = door.width * (0.5 if door.double else 1.0)
	if door.kind in [FloorPlan.DoorKind.SWING, FloorPlan.DoorKind.DOUBLE_ACTING]:
		return hinge + door_across(door) * reach
	return hinge + door_across(door) * minf(reach, 0.6)


## The box the leaf of door [param door] swings in (m; both ways for one
## swinging both ways), on the side it opens to.
func _door_swing_box(door: FloorPlan.Door) -> Rect2:
	var along: Vector2 = Vector2.DOWN if door.vertical else Vector2.RIGHT
	var ends: PackedVector2Array = door.ends()
	var depth: float = door.width * (0.5 if door.double else 1.0)
	if door.kind not in [FloorPlan.DoorKind.SWING, FloorPlan.DoorKind.DOUBLE_ACTING]:
		depth = minf(depth, 0.6)
	var box: Rect2 = Rect2(ends[0], Vector2.ZERO).expand(ends[1]).expand(ends[0] + door_across(door) * depth).expand(ends[1] + door_across(door) * depth)
	if door.kind == FloorPlan.DoorKind.DOUBLE_ACTING:
		box = box.expand(ends[0] - door_across(door) * depth).expand(ends[1] - door_across(door) * depth)
	return box


## How door [param door] is turned by its corner dragged to plan point
## [param m]: Vector2i(hinge at its end, opening the other way), by the end
## and the side of the wall the point is nearer.
static func _door_turn(door: FloorPlan.Door, m: Vector2) -> Vector2i:
	var along: Vector2 = Vector2.DOWN if door.vertical else Vector2.RIGHT
	var across: Vector2 = Vector2.LEFT if door.vertical else Vector2.DOWN
	var hinge_end: bool = door.hinge_end if door.double else (m - door.at).dot(along) > 0.0
	return Vector2i(1 if hinge_end else 0, 1 if (m - door.at).dot(across) < 0.0 else 0)


## The wall of a room under screen point [param point]: Vector2i(room,
## wall), (-1, -1) for none.
func edge_at(point: Vector2) -> Vector2i:
	var m: Vector2 = to_plan(point)
	var grab: float = EDGE_GRAB / (PX * zoom)
	# Anywhere on a wall's band, as it is drawn.
	for piece: Dictionary in plan().wall_pieces():
		var a: Vector2 = piece["a"]
		var b: Vector2 = piece["b"]
		var length: float = a.distance_to(b)
		if length < 0.001:
			continue
		var along: float = (m - a).dot((b - a) / length)
		var across: float = (m - a).dot(Vector2(piece["out"]))
		if along >= 0.0 and along <= length and across >= float(piece["from"]) - grab and across <= float(piece["to"]) + grab:
			var room: int = piece["room"]
			# Of a wall between two rooms, the one the point is nearer to.
			if int(piece["other"]) >= 0 and int(piece["other_wall"]) >= 0 and across > (float(piece["from"]) + float(piece["to"])) * 0.5:
				return Vector2i(piece["other"], piece["other_wall"])
			return Vector2i(room, piece["wall"])
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


## The walls selected (Vector2i(room, wall)): the one clicked and those
## added with Ctrl+click; none unless walls are selected.
func selected_walls() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if selected.get("kind", "") != "edge":
		return result
	var first: Vector2i = Vector2i(selected.get("index", -1), selected.get("side", -1))
	for wall_at: Vector2i in [first] + Array(selected.get("more", [])):
		if wall_at.x >= 0 and wall_at.x < plan().rooms.size() and wall_at.y >= 0 and wall_at.y < plan().rooms[wall_at.x].points.size() and not result.has(wall_at):
			result.append(wall_at)
	return result


## Wall [param wall_at] added to the walls selected, or taken off them.
func _toggle_wall(wall_at: Vector2i) -> void:
	var walls: Array[Vector2i] = selected_walls()
	if walls.has(wall_at):
		walls.erase(wall_at)
	else:
		walls.append(wall_at)
	if walls.is_empty():
		selected = {}
		return
	selected = {"kind": "edge", "index": walls[0].x, "side": walls[0].y, "more": walls.slice(1)}


## The wall of a room of [param target] (Vector2i(room, wall)) through
## plan point [param point], (-1, -1) for none.
static func wall_through(target: FloorPlan, point: Vector2) -> Vector2i:
	for i: int in target.rooms.size():
		var k: int = FloorPlan.wall_through(target.rooms[i].points, point)
		if k >= 0:
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
	var dragged: bool = _dragging and _press.get("kind", "") == "label" and _press.get("index", -1) == index
	if dragged:
		by += FloorPlan.snap(to_plan(_mouse) - to_plan(_press_at))
	var ascent: float = font.get_ascent(_sized(NAME_SIZE))
	if by != Vector2.ZERO or dragged:
		return to_screen(corner + by) + Vector2(wall + 6.0, wall + 10.0 + ascent)
	# Where it was not dragged to: the first corner of the room (then its
	# middle) where it covers no door, window or part.
	var size: Vector2 = _label_size(index, font)
	var box: Rect2 = Rect2(shown.points[0], Vector2.ZERO)
	for p: Vector2 in shown.points:
		box = box.expand(p)
	var room_box: Rect2 = Rect2(to_screen(box.position), box.size * PX * zoom)
	var inset: Vector2 = Vector2(wall + 6.0, wall + 10.0)
	# Along its top, then its bottom, then its middle, from the left.
	var spots: Array[Vector2] = [to_screen(corner) + inset]
	var left: float = room_box.position.x + inset.x
	var right: float = room_box.end.x - inset.x - size.x
	for y: float in [room_box.position.y + inset.y, room_box.end.y - inset.y - size.y, room_box.get_center().y - size.y * 0.5]:
		for k: int in 9:
			spots.append(Vector2(lerpf(left, right, k / 8.0), y))
	var taken: Array[Rect2] = _label_obstacles(box)
	for spot: Vector2 in spots:
		var label_box: Rect2 = Rect2(spot, size)
		if not shown.contains(to_plan(spot), 0.0) or not shown.contains(to_plan(label_box.end), 0.0):
			continue
		if not taken.any(func(r: Rect2) -> bool: return r.intersects(label_box)):
			return spot + Vector2(0.0, ascent)
	return to_screen(corner) + inset + Vector2(0.0, ascent)


## How large the label of room [param index] is on the screen (its name or
## number over its area).
func _label_size(index: int, font: Font) -> Vector2:
	var title: String = plan().room_number(index) if installation() else tr(plan().rooms[index].name)
	var title_size: int = _sized(NAME_SIZE) + (6 if installation() else 0)
	var area: String = "%s m²" % String.num(plan().rooms[index].area(), 1)
	var width: float = maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x, font.get_string_size(area, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE)).x)
	return Vector2(width, title_size + _sized(TEXT_SIZE) + 4.0)


## What a room's label in [param box] (m) should not cover, on the screen:
## the doors with their swing, the windows there, and the parts' symbols
## and designations (as drawn, [member _taken]).
func _label_obstacles(box: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var near: Rect2 = box.grow(1.0)
	for door: FloorPlan.Door in plan().doors:
		var swing: Rect2 = _door_swing_box(door)
		if near.intersects(swing):
			result.append(Rect2(to_screen(swing.position), swing.size * PX * zoom).grow(4.0))
	for window: FloorPlan.WindowOpening in plan().windows:
		if near.has_point(window.at):
			var ends: PackedVector2Array = window.ends()
			result.append(Rect2(to_screen(ends[0]), Vector2.ZERO).expand(to_screen(ends[1])).grow(10.0))
	# The parts' symbols and designations as drawn last.
	for taken: Rect2 in _taken:
		result.append(taken.grow(3.0))
	return result


## The room whose label is under screen point [param point], -1 for none.
func label_at(point: Vector2) -> int:
	for i: int in range(plan().rooms.size() - 1, -1, -1):
		var start: Vector2 = _label_at(i)
		if Rect2(start - Vector2(2, _sized(NAME_SIZE) + 6), Vector2(72, _sized(NAME_SIZE) + _sized(TEXT_SIZE) + 14)).has_point(point):
			return i
	return -1


# --- Input ----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if document == null:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and editing and _room_key(key):
		accept_event()
		queue_redraw()
		return
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
			_hover_at(motion.position)
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
				var clicked: bool = mb.button_index == MOUSE_BUTTON_RIGHT and mb.position.distance_to(_pan_from) < SchematicEditor.CLICK_SLOP
				if clicked and tool == Tool.WALL and not _corners.is_empty():
					# A right click ends the walls being drawn.
					_end_walls()
					queue_redraw()
					return
				if clicked and tool == Tool.OUTLINE and _corners.size() >= 2:
					# A right click closes the room being drawn by its corners.
					_close_outline()
					queue_redraw()
					return
				if clicked and tool == Tool.SELECT and editing:
					# A right click on a part, mark, dimension, note or fixture:
					# the layer it is on; on a room: its menu.
					var item: Dictionary = _layered_at(mb.position)
					if not item.is_empty():
						selected = item
						layer_menu_requested.emit(mb.position)
						queue_redraw()
						return
					var room: int = plan().room_at(to_plan(mb.position))
					if room >= 0:
						selected = {"kind": "room", "index": room}
						room_menu_requested.emit(room, mb.position)
						queue_redraw()
					return
				if clicked and tool != Tool.SELECT:
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
			if mb.pressed and mb.double_click and tool == Tool.OUTLINE and _corners.size() >= 2:
				# The click before put the last corner.
				_close_outline()
				_press = {}
				queue_redraw()
				return
			if mb.pressed and mb.double_click and tool == Tool.SELECT and free_wall_at(mb.position) >= 0:
				free_wall_requested.emit(free_wall_at(mb.position))
				_press = {}
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
				if room >= 0 and part_at(mb.position).is_empty() and mark_at(mb.position) < 0:
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
				elif _press["kind"] == "edge" and mb.is_command_or_control_pressed() and selected.get("kind", "") == "edge":
					# Ctrl+click: one more wall selected (or one taken off).
					_toggle_wall(Vector2i(_press["index"], _press["side"]))
				elif _press["kind"] in ["room", "door", "window", "part", "edge", "link", "label", "dimension", "note", "fixture", "mark", "free_wall"]:
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


## The part (not the consumer unit), mark or fixture under screen point
## [param point] as a selection, {} for none (dimensions and notes stay on
## their own layer).
func _layered_at(point: Vector2) -> Dictionary:
	var part: String = part_at(point)
	if not part.is_empty() and part != FloorPlan.UNIT:
		return {"kind": "part", "designation": part}
	var mark: int = mark_at(point)
	if mark >= 0:
		return {"kind": "mark", "index": mark}
	if saved_dimension_at(point) >= 0 or not note_at(point).is_empty():
		return {}
	var fixture: int = fixture_at(point)
	if fixture >= 0:
		return {"kind": "fixture", "index": fixture}
	return {}


## What a press at [param point] takes hold of.
func _pressed(point: Vector2) -> Dictionary:
	match tool:
		Tool.ROOM:
			return {"kind": "room_end"} if not is_nan(_room_from.x) else {"kind": "new_room"}
		Tool.OUTLINE:
			return {"kind": "room_corner"}
		Tool.WALL:
			return {"kind": "wall_point"}
		Tool.PLACE_ROOM:
			return {"kind": "place_room"}
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
			if from.is_empty():
				# A part of the floor above or below, in a staircase.
				from = ghost_at(point)
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
	var mark: int = mark_at(point)
	if mark >= 0:
		return {"kind": "mark", "index": mark}
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
	var free: int = free_wall_at(point)
	if free >= 0:
		return {"kind": "free_wall", "index": free}
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
			if not _dragging:
				# A click: the first corner; the next click (or a size typed) the other.
				_room_from = _room_point(m)
				return
			_add_rect_room(_drawn_room())
		"room_end":
			_add_rect_room(_drawn_room())
		"room_corner":
			if _corners.size() >= 3 and to_screen(_corners[0]).distance_to(point) <= FEATURE_GRAB:
				_close_outline()
			else:
				_add_corner(_next_corner())
		"wall_point":
			_add_wall_point()
		"free_wall":
			if _dragging and by != Vector2.ZERO:
				var index: int = press["index"]
				edit_requested.emit(func(doc: SchematicDocument) -> void:
					doc.floor_plan.walls[index].a += by
					doc.floor_plan.walls[index].b += by)
		"free_wall_end":
			if _dragging:
				var index: int = press["index"]
				var which: int = press["which"]
				var to: Vector2 = _wall_end_target(index, which)
				var room_name: String = _next_room_name()
				var made: Array[int] = [-1]
				edit_requested.emit(func(doc: SchematicDocument) -> void: made[0] = doc.floor_plan.move_wall_end(index, which, to, room_name))
				if made[0] >= 0:
					selected = {"kind": "room", "index": made[0]}
					room_drawn.emit(made[0])
				else:
					# Put back last among the walls.
					selected = {"kind": "free_wall", "index": plan().walls.size() - 1}
		"place_room":
			var ghost: FloorPlan.Room = _placed_room()
			if ghost != null:
				var made: Array[int] = [-1]
				edit_requested.emit(func(doc: SchematicDocument) -> void: made[0] = doc.floor_plan.put_room(ghost))
				selected = {"kind": "room", "index": made[0]}
		"new_door":
			var wall: Dictionary = plan().wall_near(m, 0.3)
			if not wall.is_empty() and wall["straight"]:
				var at: Vector2 = wall["at"]
				var vertical: bool = int(wall["facing"]) % 2 == 0
				var door: FloorPlan.Door = _new_door(at, vertical)
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.doors.append(door))
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
				var to: Vector2 = _corner_target(index)
				var free: bool = Input.is_key_pressed(KEY_SHIFT)
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.set_corner(index, k, to, free))
		"door_swing":
			if _dragging:
				var index: int = press["index"]
				var turned: Vector2i = _door_turn(plan().doors[index], m)
				edit_requested.emit(func(doc: SchematicDocument) -> void:
					doc.floor_plan.doors[index].hinge_end = turned.x == 1
					doc.floor_plan.doors[index].opens_back = turned.y == 1)
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
		"mark":
			if _dragging and by != Vector2.ZERO:
				var index: int = press["index"]
				var to: Vector2 = plan().marks[index].at + by
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.move_mark(index, to))
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
			if not wall.is_empty() and wall["straight"]:
				var at: Vector2 = wall["at"]
				var vertical: bool = int(wall["facing"]) % 2 == 0
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.windows.append(FloorPlan.WindowOpening.new(at, vertical)))
		"new_link":
			var to: String = part_at(point)
			if to.is_empty():
				to = ghost_at(point)
			var c: CircuitComponent = document.circuit.get_component(to) if not to.is_empty() else null
			var from: String = press["designation"]
			if (c is LightSwitch or c is Luminaire) and to != from and (c is LightSwitch or document.circuit.get_component(from) is LightSwitch or c is Luminaire):
				var from_port: int = press["port"]
				var to_port: int = _port_at(to, point)
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.add_link(from, from_port, to, to_port))
		"new_part":
			_put_part(m, false)
		"part_offset":
			if _dragging:
				var designation: String = press["designation"]
				var offset: float = _dragged_offset(designation, point)
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.set_offset(designation, offset))
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
				if not wall.is_empty() and wall["straight"]:
					var at: Vector2 = wall["at"]
					var vertical: bool = int(wall["facing"]) % 2 == 0
					edit_requested.emit(func(doc: SchematicDocument) -> void:
						doc.floor_plan.doors[index].at = at
						doc.floor_plan.doors[index].vertical = vertical)
		"window":
			if _dragging:
				var index: int = press["index"]
				var wall: Dictionary = plan().wall_near(m, 0.3)
				if not wall.is_empty() and wall["straight"]:
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
				# The rooms sharing the wall keep sharing it.
				if FloorPlan.is_straight(plan().rooms[index].wall(k)):
					var at: float = _edge_target(index, k)
					edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.set_edge(index, k, at))
				else:
					var shift: float = _slant_shift(index, k)
					edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.move_wall(index, k, shift))
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
	var layer: String = new_layer()
	if placing_template.get("type", "") == "fixture":
		var kind: String = placing_template.get("kind", "table")
		edit_requested.emit(func(doc: SchematicDocument) -> void:
			var fixture: FloorPlan.Fixture = doc.floor_plan.fixture_at_point(kind, m)
			fixture.layer = layer
			doc.floor_plan.fixtures.append(fixture))
		return
	if placing_template.get("type", "") == "custom_symbol":
		var def: CustomSymbol = template_symbol(document, placing_template)
		if def == null:
			return
		edit_requested.emit(func(doc: SchematicDocument) -> void:
			doc.use_symbol(def)
			var mark: FloorPlan.Mark = doc.floor_plan.mark_at_point(def.id, m, def.wall)
			mark.layer = layer
			doc.floor_plan.marks.append(mark))
		return
	if not placing_template.is_empty():
		var template: Dictionary = placing_template.duplicate()
		var feeder: int = circuit
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.set_part_layer(add_part(doc, template, feeder, m, exact), layer))
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
		doc.floor_plan.set_part_layer(designation, layer)
		if designation == FloorPlan.UNIT:
			doc.ensure_consumer_unit())
	placed.emit()


## Makes a part of [param template] in [param doc], fed by circuit number
## [param feeder] (none for 0; made, waiting for its protection, when no
## circuit has that number yet), and puts it at [param at] on the
## plan (onto the nearest wall unless it goes on the ceiling; with
## [param exact] at that very point, facing [param face] when given).
## Returns its designation ("" if none was made).
static func add_part(doc: SchematicDocument, template: Dictionary, feeder: int, at: Vector2, exact: bool = false, face: int = -1) -> String:
	var data: Dictionary = template.duplicate()
	data["designation"] = SingleLineCanvas.new_designation(doc, template)
	var part: CircuitComponent = DocumentSerializer.component_from_dict(data)
	if part == null:
		return ""
	doc.add(part, SingleLine.hidden_cell(doc))
	# Drawn with a symbol of the user's own: the schematic keeps a copy.
	var def: CustomSymbol = template_symbol(doc, template)
	if def != null:
		doc.use_symbol(def)
	if exact and not on_ceiling(part):
		doc.floor_plan.place_on_wall(part.designation, at, face)
	else:
		doc.floor_plan.place(part.designation, at, on_ceiling(part))
	if feeder == SingleLine.BY_KIND:
		feeder = doc.single_line.circuit_by_kind(doc, part)
	if feeder > 0:
		doc.single_line.feed(part.designation, feeder)
	# A socket behind a kitchen worktop goes over it.
	if part is SocketOutlet and doc.floor_plan.over_worktop(doc.floor_plan.parts[part.designation]):
		(part as SocketOutlet).height = FloorPlan.WORKTOP_SOCKET_HEIGHT
	return part.designation


## Whether a distance can be typed: a part on a wall being placed, or one
## selected.
func _takes_distance() -> bool:
	if tool == Tool.PLACE:
		if placing_template.get("type", "") in ["fixture", "custom_symbol"]:
			return false
		if not placing_template.is_empty():
			return not _template_on_ceiling(placing_template)
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
	var color: Color = SchematicTheme.SELECTED
	_draw_wall_dimension(font, ref["from"], point, into, color)
	if not _typed.is_empty():
		draw_circle(to_screen(point), 4.0, color)
		var text: String = _typed + " mm  ↵"
		var at: Vector2 = to_screen(point) + Vector2(12, -14)
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE)).x
		draw_rect(Rect2(at + Vector2(-4, -_sized(TEXT_SIZE) - 2), Vector2(width + 8, _sized(TEXT_SIZE) + 8)), SchematicTheme.BACKGROUND)
		draw_rect(Rect2(at + Vector2(-4, -_sized(TEXT_SIZE) - 2), Vector2(width + 8, _sized(TEXT_SIZE) + 8)), color, false, 1.0)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), color)


## A dimension in the room (towards [param into]) along a wall from
## [param from] to [param point], in [param color].
func _draw_wall_dimension(font: Font, from: Vector2, point: Vector2, into: Vector2, color: Color) -> void:
	var a: Vector2 = to_screen(from + into * 0.35)
	var b: Vector2 = to_screen(point + into * 0.35)
	draw_line(a, b, color, 1.0, true)
	for end: Array in [[from, a], [point, b]]:
		draw_line(to_screen(end[0]), end[1] + (end[1] - to_screen(end[0])).normalized() * 4.0, color, 1.0, true)
		var tick: Vector2 = (b - a).normalized().rotated(PI / 4.0) * 5.0 if a.distance_to(b) > 0.5 else Vector2(4, -4)
		draw_line(end[1] - tick, end[1] + tick, color, 1.6, true)
	if a.distance_to(b) > 1.0:
		_draw_length(font, a, b, (to_screen(into) - to_screen(Vector2.ZERO)).normalized(), from.distance_to(point), color)


## A point snapped onto a room's wall (not at its end): dimensions from it
## to both ends of the wall, in the room.
func _draw_snap_dimensions(font: Font, point: Vector2) -> void:
	var ref: Dictionary = plan().wall_reference(point)
	if ref.is_empty():
		return
	var wall: PackedVector2Array = ref["wall"]
	if point.distance_to(wall[0]) < 0.01 or point.distance_to(wall[1]) < 0.01:
		return
	# Into the room the wall belongs to (between two, the one the walls
	# come from).
	var into: Vector2 = (wall[1] - wall[0]).normalized().orthogonal()
	var toward: Vector2 = _corners[_corners.size() - 1] - point if not _corners.is_empty() else into
	if plan().room_at(point + into * 0.05) < 0 or (plan().room_at(point - into * 0.05) >= 0 and toward.dot(into) < 0.0):
		into = -into
	for end: Vector2 in [wall[0], wall[1]]:
		_draw_wall_dimension(font, end, point, into, SchematicTheme.SELECTED)


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
		"room":
			var index: int = selected["index"]
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.remove_room(index))
		"edge":
			# Each wall selected taken away: rooms on both sides joined, an
			# outside wall left open. Found again by its middle, as joining
			# renumbers the rooms.
			var middles: Array[Vector2] = []
			for wall_at: Vector2i in selected_walls():
				var w: PackedVector2Array = plan().rooms[wall_at.x].wall(wall_at.y)
				middles.append((w[0] + w[1]) * 0.5)
			edit_requested.emit(func(doc: SchematicDocument) -> void:
				for middle: Vector2 in middles:
					var found: Vector2i = FloorPlanCanvas.wall_through(doc.floor_plan, middle)
					if found.x >= 0 and not doc.floor_plan.rooms[found.x].is_open(found.y):
						doc.floor_plan.remove_room_wall(found.x, found.y))
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
		"mark":
			var mark: int = selected["index"]
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.marks.remove_at(mark))
		"part":
			var designation: String = selected["designation"]
			edit_requested.emit(func(doc: SchematicDocument) -> void:
				doc.floor_plan.remove(designation)
				# Its lighting drawn from the floors above and below goes too.
				for other: FloorPlan in doc.floors:
					other.unlink(designation))
		"link":
			var link: int = selected["index"]
			edit_requested.emit(func(doc: SchematicDocument) -> void:
				if link < doc.floor_plan.links.size():
					doc.floor_plan.links.remove_at(link))
		"free_wall":
			var wall: int = selected["index"]
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.walls.remove_at(wall))
	selected = {}
	queue_redraw()


# --- Drawing rooms ----------------------------------------------------------------

## What is under screen point [param point] to light up, and the cursor
## that says what a drag does there: a handle (drag), a wall (resize across
## it), a room (move).
func _hover_at(point: Vector2) -> void:
	var was: Dictionary = _hover
	var handle: Dictionary = handle_at(point)
	var edge: Vector2i = edge_at(point) if handle.is_empty() and part_at(point).is_empty() else Vector2i(-1, -1)
	var room: int = plan().room_at(to_plan(point)) if handle.is_empty() and edge.x < 0 and part_at(point).is_empty() else -1
	if not handle.is_empty():
		_hover = {"kind": "handle"}
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	elif edge.x >= 0:
		_hover = {"kind": "edge", "index": edge.x, "side": edge.y}
		var w: PackedVector2Array = plan().rooms[edge.x].wall(edge.y)
		mouse_default_cursor_shape = Control.CURSOR_HSIZE if is_equal_approx(w[0].x, w[1].x) else Control.CURSOR_VSIZE
	elif room >= 0 and door_at(point) < 0 and window_at(point) < 0 and fixture_at(point) < 0 and mark_at(point) < 0 and note_at(point).is_empty() and label_at(point) < 0:
		_hover = {"kind": "room", "index": room}
		mouse_default_cursor_shape = Control.CURSOR_MOVE
	else:
		_hover = {}
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	if _hover != was:
		queue_redraw()


## While editing: the wall or room under the mouse lit up; while a room or
## a wall or corner of it is dragged, its size and area by the mouse and a
## guide along each wall it has snapped onto; where rooms overlap, hatched
## with a warning.
func _draw_room_feedback(s: float, font: Font) -> void:
	var color: Color = SchematicTheme.SELECTED
	if _press.is_empty() and tool == Tool.SELECT:
		match _hover.get("kind", ""):
			"edge":
				var index: int = _hover["index"]
				if index < plan().rooms.size() and int(_hover["side"]) < plan().rooms[index].points.size():
					var w: PackedVector2Array = plan().rooms[index].wall(_hover["side"])
					draw_line(to_screen(w[0]), to_screen(w[1]), Color(color, 0.45), maxf(WALL * s, 2.0) + 4.0, true)
			"room":
				var index: int = _hover["index"]
				if index < plan().rooms.size() and not (selected.get("kind", "") in ["room", "edge"] and selected.get("index", -1) == index):
					var outline: PackedVector2Array = _screen_points(plan().rooms[index].points)
					outline.append(outline[0])
					draw_polyline(outline, Color(color, 0.35), 2.0, true)
	var kind: String = _press.get("kind", "")
	if _dragging and kind in ["edge", "corner", "room"] and int(_press.get("index", -1)) < plan().rooms.size():
		var index: int = _press["index"]
		var shown: FloorPlan.Room = FloorPlan.Room.new()
		shown.points = _shown_points(index)
		var text: String = "%s × %s m  ·  %s m²" % [_metres_text(shown.rect.size.x), _metres_text(shown.rect.size.y), String.num(shown.area(), 1)]
		draw_string(font, _mouse + Vector2(14, 22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), color)
		_draw_wall_guides(shown.points, index)
	if _drawing_rect():
		var drawn: Rect2 = _drawn_room()
		_draw_wall_guides(PackedVector2Array([drawn.position, Vector2(drawn.end.x, drawn.position.y), drawn.end, Vector2(drawn.position.x, drawn.end.y)]), -1)
	var overlaps: Array[PackedVector2Array] = plan().overlaps()
	if overlaps.is_empty():
		return
	for piece: PackedVector2Array in overlaps:
		var area: PackedVector2Array = _screen_points(piece)
		draw_colored_polygon(area, Color(SchematicTheme.FAULT, 0.18))
		var box: Rect2 = Rect2(area[0], Vector2.ZERO)
		for p: Vector2 in area:
			box = box.expand(p)
		# Hatched across.
		var step: float = 8.0
		var x: float = box.position.x - box.size.y
		while x < box.end.x:
			var line: PackedVector2Array = PackedVector2Array([Vector2(x, box.end.y), Vector2(x + box.size.y, box.position.y)])
			for inside: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(line, area):
				draw_line(inside[0], inside[1], Color(SchematicTheme.FAULT, 0.6), 1.0, true)
			x += step
	var warning: String = tr_n("%d place where rooms overlap: drag them apart", "%d places where rooms overlap: drag them apart", overlaps.size()) % overlaps.size()
	var width: float = font.get_string_size(warning, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE)).x
	var at: Vector2 = Vector2(16.0, 16.0 + _sized(TEXT_SIZE))
	draw_rect(Rect2(at + Vector2(-8, -_sized(TEXT_SIZE) - 4), Vector2(width + 16, _sized(TEXT_SIZE) + 12)), SchematicTheme.BACKGROUND)
	draw_rect(Rect2(at + Vector2(-8, -_sized(TEXT_SIZE) - 4), Vector2(width + 16, _sized(TEXT_SIZE) + 12)), SchematicTheme.FAULT, false, 1.0)
	draw_string(font, at, warning, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), SchematicTheme.FAULT)


## A dashed guide across the plan along each wall of outline [param points]
## that lies on the line of a wall of another room (not [param skip]): it
## has snapped onto it.
func _draw_wall_guides(points: PackedVector2Array, skip: int) -> void:
	var drawn: Dictionary[String, bool] = {}
	for k: int in points.size():
		var a: Vector2 = points[k]
		var b: Vector2 = points[(k + 1) % points.size()]
		var vertical: bool = is_equal_approx(a.x, b.x)
		var at: float = a.x if vertical else a.y
		var key: String = "%s%s" % ["x" if vertical else "y", snappedf(at, 0.001)]
		if drawn.has(key):
			continue
		for i: int in plan().rooms.size():
			if i == skip:
				continue
			var lined_up: bool = false
			var room: FloorPlan.Room = plan().rooms[i]
			for j: int in room.points.size():
				var w: PackedVector2Array = room.wall(j)
				if is_equal_approx(w[0].x, w[1].x) == vertical and absf((w[0].x if vertical else w[0].y) - at) < 0.001:
					lined_up = true
					break
			if lined_up:
				drawn[key] = true
				var line: PackedVector2Array = PackedVector2Array([Vector2(to_screen(Vector2(at, 0)).x, 0), Vector2(to_screen(Vector2(at, 0)).x, size.y)]) if vertical else PackedVector2Array([Vector2(0, to_screen(Vector2(0, at)).y), Vector2(size.x, to_screen(Vector2(0, at)).y)])
				CustomSymbol.stroke_line(self, line, Color(SchematicTheme.SELECTED, 0.35), 1.0, "dash")
				break


## The room being drawn with Tool.ROOM: from its first corner (clicked or
## pressed) to the mouse, snapped onto the walls near; a width or depth
## typed taken as it is, the way the mouse is.
func _drawn_room() -> Rect2:
	var a: Vector2 = _room_from if not is_nan(_room_from.x) else _room_point(to_plan(_press_at))
	var b: Vector2 = FloorPlan.snap(to_plan(_mouse))
	var rect: Rect2 = _snap_corners(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()))
	for axis: int in 2:
		if _room_typed[axis].is_empty():
			continue
		var length: float = float(_room_typed[axis]) / 1000.0
		var toward: float = 1.0 if b[axis] >= a[axis] else -1.0
		var low: float = a[axis] if toward > 0.0 else a[axis] - length
		var start: Vector2 = rect.position
		var extent: Vector2 = rect.size
		start[axis] = low
		extent[axis] = length
		rect = Rect2(start, extent)
	return rect


## Whether a room is being drawn with Tool.ROOM (its first corner set).
func _drawing_rect() -> bool:
	return tool == Tool.ROOM and (not is_nan(_room_from.x) or (_press.get("kind", "") == "new_room" and _dragging))


## Plan point [param m] where a room's corner goes: onto a corner of the
## floor below near, else on the grid, onto the walls near.
func _room_point(m: Vector2) -> Vector2:
	# Onto a corner of the floor below, drawn under this one.
	var reach: float = FEATURE_GRAB / (PX * zoom)
	for p: Vector2 in _reference_corners():
		if p.distance_to(m) < reach:
			return p
	var at: Vector2 = FloorPlan.snap(m)
	return Vector2(_snap_edge(at.x, false, -1), _snap_edge(at.y, true, -1))


## Adds a room of [param rect] (named in turn) when it is large enough,
## then the first corner is forgotten.
func _add_rect_room(rect: Rect2) -> void:
	_room_from = Vector2(NAN, NAN)
	_room_typed = PackedStringArray(["", ""])
	_room_field = 0
	if rect.size.x < FloorPlan.MIN_ROOM - 0.001 or rect.size.y < FloorPlan.MIN_ROOM - 0.001:
		return
	_add_room(FloorPlan.Room.new(_next_room_name(), rect))


func _add_room(room: FloorPlan.Room) -> void:
	# Put into or over other rooms, they give up what it covers.
	var made: Array[int] = [-1]
	edit_requested.emit(func(doc: SchematicDocument) -> void: made[0] = doc.floor_plan.put_room(room))
	var index: int = made[0]
	selected = {"kind": "room", "index": index}
	room_drawn.emit(index)


## Where the next corner of the room drawn by its corners goes: straight
## across or up and down from the last (whichever the mouse is nearer),
## that far on the grid and onto the walls near; as long as typed.
func _next_corner() -> Vector2:
	var m: Vector2 = to_plan(_mouse)
	if _corners.is_empty():
		return _room_point(m)
	var last: Vector2 = _corners[_corners.size() - 1]
	if Input.is_key_pressed(KEY_SHIFT):
		# Slanting, by ANGLE_STEP.
		return _angled(last, m, float(_room_typed[0]) / 1000.0 if not _room_typed[0].is_empty() else -1.0, ANGLE_STEP)
	var d: Vector2 = m - last
	var across: bool = absf(d.x) >= absf(d.y)
	if not _room_typed[0].is_empty():
		var length: float = float(_room_typed[0]) / 1000.0
		return last + (Vector2(signf(d.x) if d.x != 0.0 else 1.0, 0.0) if across else Vector2(0.0, signf(d.y) if d.y != 0.0 else 1.0)) * length
	var at: Vector2 = _room_point(m)
	# Level with the first corner when near it, so the room closes square.
	var first: Vector2 = _corners[0]
	if across and absf(at.x - first.x) < FloorPlan.WALL_SNAP:
		at.x = first.x
	elif not across and absf(at.y - first.y) < FloorPlan.WALL_SNAP:
		at.y = first.y
	return Vector2(at.x, last.y) if across else Vector2(last.x, at.y)


## The point from [param from] towards [param to] at a whole number of
## [param step] degrees (none: any), [param length] m away (-1: as far as
## [param to], on the grid).
static func _angled(from: Vector2, to: Vector2, length: float, step: float) -> Vector2:
	var d: Vector2 = to - from
	if d.length() < 0.001:
		return from
	var angle: float = d.angle()
	if step > 0.0:
		angle = snappedf(angle, deg_to_rad(step))
	var reach: float = length if length > 0.0 else snappedf(d.length(), FloorPlan.SNAP)
	return (from + Vector2.from_angle(angle) * reach).snappedf(0.001)


## Where the wall being drawn ends: on a wall's end or a room's corner near
## the mouse, else from the last point at a whole number of
## [constant ANGLE_STEP] degrees (any with Shift), as long as typed (mm),
## onto a room's wall it meets near the mouse or on the grid; the first
## point on the grid, onto a room's wall near.
func _next_wall_point() -> Vector2:
	var m: Vector2 = to_plan(_mouse)
	var near: Vector2 = _wall_snap(m)
	if _corners.is_empty():
		if not is_nan(near.x):
			return near
		var on_wall: Vector2 = _room_wall_snap(m)
		return on_wall if not is_nan(on_wall.x) else FloorPlan.snap(m)
	var last: Vector2 = _corners[_corners.size() - 1]
	if _room_typed[0].is_empty() and not is_nan(near.x):
		return near
	var typed: float = float(_room_typed[0]) / 1000.0 if not _room_typed[0].is_empty() else -1.0
	var to: Vector2 = _angled(last, m, typed, 0.0 if Input.is_key_pressed(KEY_SHIFT) else ANGLE_STEP)
	if typed > 0.0 or to.distance_to(last) < 0.001:
		return to
	# Onto a room's wall the way it goes, where that meets one near the mouse.
	var reach: float = FEATURE_GRAB / (PX * zoom)
	var far: Vector2 = last + (to - last).normalized() * 1000.0
	var best: Vector2 = to
	for room: FloorPlan.Room in plan().rooms:
		for k: int in room.points.size():
			var hit: Variant = Geometry2D.segment_intersects_segment(last, far, room.points[k], room.points[(k + 1) % room.points.size()])
			if hit != null and (hit as Vector2).distance_to(last) > 0.01 and (hit as Vector2).distance_to(m) < reach:
				reach = (hit as Vector2).distance_to(m)
				best = (hit as Vector2).snappedf(0.001)
	return best


## A free wall's end, a room's corner or a corner of the floor below within
## reach of plan point [param m], NAN for none.
func _wall_snap(m: Vector2) -> Vector2:
	var reach: float = FEATURE_GRAB / (PX * zoom)
	var best: Vector2 = Vector2(NAN, NAN)
	for wall: FloorPlan.Wall in plan().walls:
		for p: Vector2 in [wall.a, wall.b]:
			if p.distance_to(m) < reach:
				reach = p.distance_to(m)
				best = p
	for room: FloorPlan.Room in plan().rooms:
		for p: Vector2 in room.points:
			if p.distance_to(m) < reach:
				reach = p.distance_to(m)
				best = p
	# The corners of the floor below, drawn under this one.
	for p: Vector2 in _reference_corners():
		if p.distance_to(m) < reach:
			reach = p.distance_to(m)
			best = p
	return best


## The point of a room's wall nearest plan point [param m] within reach
## (along a wall across or up and down on the grid), NAN for none.
func _room_wall_snap(m: Vector2) -> Vector2:
	var reach: float = FEATURE_GRAB / (PX * zoom)
	var best: Vector2 = Vector2(NAN, NAN)
	for room: FloorPlan.Room in plan().rooms:
		for k: int in room.points.size():
			var a: Vector2 = room.points[k]
			var b: Vector2 = room.points[(k + 1) % room.points.size()]
			var p: Vector2 = Geometry2D.get_closest_point_to_segment(m, a, b)
			if p.distance_to(m) >= reach:
				continue
			if absf(a.y - b.y) < 0.001:
				p.x = clampf(snappedf(p.x, FloorPlan.SNAP), minf(a.x, b.x), maxf(a.x, b.x))
			elif absf(a.x - b.x) < 0.001:
				p.y = clampf(snappedf(p.y, FloorPlan.SNAP), minf(a.y, b.y), maxf(a.y, b.y))
			reach = p.distance_to(m)
			best = p.snappedf(0.001) if absf(a.y - b.y) < 0.001 or absf(a.x - b.x) < 0.001 else p
	return best


## Puts the next point of the walls being drawn: the first, else a wall to
## it from the last; walls closing round a space make a room (named as
## asked), and the drawing ends. Walls started on a room's wall and running
## inside it wait: once they end on its wall they split it in two (the new
## room named as asked); leaving it, they become walls on their own.
func _add_wall_point() -> void:
	var to: Vector2 = _next_wall_point()
	_room_typed = PackedStringArray(["", ""])
	if _corners.is_empty():
		_corners = PackedVector2Array([to])
		return
	var from: Vector2 = _corners[_corners.size() - 1]
	if from.distance_to(to) < 0.01:
		return
	if _corners.size() == 1:
		# From a room's wall into the room (of two rooms on a wall, the one it goes into).
		_split_room = -1
		for i: int in plan().rooms.size():
			var points: PackedVector2Array = plan().rooms[i].points
			if FloorPlan.wall_through(points, from) >= 0 and Geometry2D.is_point_in_polygon((from + to) * 0.5, points):
				_split_room = i
	if _split_room >= 0:
		var room: FloorPlan.Room = plan().rooms[_split_room]
		if Geometry2D.is_point_in_polygon((from + to) * 0.5, room.points):
			if FloorPlan.wall_through(room.points, to) < 0:
				if Geometry2D.is_point_in_polygon(to, room.points):
					_corners.append(to)
					return
			else:
				var line: PackedVector2Array = _corners + PackedVector2Array([to])
				var index: int = _split_room
				var room_name: String = _next_room_name()
				var made: Array[int] = [-1]
				edit_requested.emit(func(doc: SchematicDocument) -> void: made[0] = doc.floor_plan.split_room(index, line, room_name))
				if made[0] >= 0:
					_corners = PackedVector2Array()
					_split_room = -1
					selected = {"kind": "room", "index": made[0]}
					room_drawn.emit(made[0])
				# Refused: the walls wait on, for another end.
				return
		# Out of the room: what waited becomes walls on their own.
		_end_walls()
		_corners = PackedVector2Array([from])
	var room_name: String = _next_room_name()
	var made: Array[int] = [-1]
	edit_requested.emit(func(doc: SchematicDocument) -> void: made[0] = doc.floor_plan.add_wall(from, to, 0.0, room_name))
	if made[0] >= 0:
		_corners = PackedVector2Array()
		selected = {"kind": "room", "index": made[0]}
		room_drawn.emit(made[0])
	else:
		_corners = PackedVector2Array([to])


## Ends the walls being drawn: those waiting to split a room become walls
## on their own (one edit).
func _end_walls() -> void:
	if _split_room >= 0 and _corners.size() > 1:
		var corners: PackedVector2Array = _corners
		var room_name: String = _next_room_name()
		edit_requested.emit(func(doc: SchematicDocument) -> void:
			for k: int in corners.size() - 1:
				doc.floor_plan.add_wall(corners[k], corners[k + 1], 0.0, room_name))
	_corners = PackedVector2Array()
	_split_room = -1
	_room_typed = PackedStringArray(["", ""])


## The free wall under screen point [param point], -1 for none.
func free_wall_at(point: Vector2) -> int:
	var m: Vector2 = to_plan(point)
	for i: int in range(plan().walls.size() - 1, -1, -1):
		var wall: FloorPlan.Wall = plan().walls[i]
		var reach: float = maxf(plan().free_thickness(wall) * 0.5, EDGE_GRAB / (PX * zoom))
		if Geometry2D.get_closest_point_to_segment(m, wall.a, wall.b).distance_to(m) <= reach:
			return i
	return -1


## Where end [param which] of free wall [param index] goes as it is
## dragged: onto a wall's end or a room's corner near, else onto a room's
## wall near, else at a whole number of [constant ANGLE_STEP] degrees from
## its other end (any with Shift).
func _wall_end_target(index: int, which: int) -> Vector2:
	var m: Vector2 = to_plan(_mouse)
	var near: Vector2 = _wall_snap(m)
	if not is_nan(near.x):
		return near
	var on_wall: Vector2 = _room_wall_snap(m)
	if not is_nan(on_wall.x):
		return on_wall
	var wall: FloorPlan.Wall = plan().walls[index]
	var fixed: Vector2 = wall.a if which == 1 else wall.b
	return _angled(fixed, m, -1.0, 0.0 if Input.is_key_pressed(KEY_SHIFT) else ANGLE_STEP)


## Free wall [param index]'s ends as shown (dragged: where they go).
func _shown_free_wall(index: int) -> PackedVector2Array:
	var wall: FloorPlan.Wall = plan().walls[index]
	var ends: PackedVector2Array = PackedVector2Array([wall.a, wall.b])
	if not _dragging or _press.get("index", -1) != index:
		return ends
	match _press.get("kind", ""):
		"free_wall":
			var by: Vector2 = FloorPlan.snap(to_plan(_mouse) - to_plan(_press_at))
			ends[0] += by
			ends[1] += by
		"free_wall_end":
			ends[int(_press["which"])] = _wall_end_target(index, _press["which"])
	return ends


## The free walls: a band of its thickness on each one's line, its ends
## joined to the walls they are on (see [method FloorPlan.free_wall_outlines];
## the one selected in the selection colour).
func _draw_free_walls() -> void:
	var shown: Array[PackedVector2Array] = []
	for i: int in plan().walls.size():
		shown.append(_shown_free_wall(i))
	var outlines: Array[PackedVector2Array] = plan().free_wall_outlines(shown)
	for i: int in outlines.size():
		if outlines[i].is_empty():
			continue
		var chosen: bool = selected.get("kind", "") == "free_wall" and selected.get("index", -1) == i
		draw_colored_polygon(_screen_points(outlines[i]), Color(SchematicTheme.SELECTED, 0.8) if chosen else wall_color())


## Adds corner [param corner] (not twice over, nor back on the last).
func _add_corner(corner: Vector2) -> void:
	_room_typed = PackedStringArray(["", ""])
	if not _corners.is_empty() and _corners[_corners.size() - 1].distance_to(corner) < 0.01:
		return
	_corners.append(corner)


## Closes the room drawn by its corners: back to the first corner (by one
## more corner where the last is level with neither of its sides) and
## adds it when it is a room (else the corners stay to be changed).
func _close_outline() -> void:
	var points: PackedVector2Array = _corners.duplicate()
	if points.size() < 2:
		return
	var first: Vector2 = points[0]
	var last: Vector2 = points[points.size() - 1]
	if last.distance_to(first) < 0.01:
		points.remove_at(points.size() - 1)
		last = points[points.size() - 1]
	var slanting: bool = false
	for k: int in points.size() - 1:
		slanting = slanting or not FloorPlan.is_straight(PackedVector2Array([points[k], points[k + 1]]))
	if not slanting and not is_equal_approx(last.x, first.x) and not is_equal_approx(last.y, first.y):
		# The last wall came across: back up or down, then across to the first.
		var before: Vector2 = points[points.size() - 2] if points.size() >= 2 else first
		points.append(Vector2(first.x, last.y) if is_equal_approx(before.x, last.x) else Vector2(last.x, first.y))
	var room: FloorPlan.Room = FloorPlan.outline_room(points, _next_room_name())
	if room == null:
		return
	_corners = PackedVector2Array()
	_room_typed = PackedStringArray(["", ""])
	_add_room(room)


## What the room tools are drawing: the room dragged or clicked with its
## size and area (the size typed in a box), the corners clicked so far
## with the next wall and the way back to the first, the walls waiting to
## split a room, a ready room where it would go.
func _draw_room_tools(s: float, font: Font, wall: float) -> void:
	var color: Color = SchematicTheme.SELECTED
	if _drawing_rect():
		var drawn: Rect2 = _drawn_room()
		draw_rect(Rect2(to_screen(drawn.position), drawn.size * s), Color(color, 0.07))
		draw_rect(Rect2(to_screen(drawn.position), drawn.size * s), color, false, wall)
		var dims: String = "%s × %s m  ·  %s m²" % [_metres_text(drawn.size.x), _metres_text(drawn.size.y), String.num(drawn.size.x * drawn.size.y, 1)]
		draw_string(font, to_screen(drawn.end) + Vector2(8, 0), dims, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), SchematicTheme.TEXT)
		_draw_typed_size(font, to_screen(drawn.end) + Vector2(8, 18), true)
	elif tool == Tool.ROOM and Rect2(Vector2.ZERO, size).has_point(_mouse):
		draw_circle(to_screen(_room_point(to_plan(_mouse))), 4.0, color)
	if tool == Tool.WALL and Rect2(Vector2.ZERO, size).has_point(_mouse):
		var to: Vector2 = _next_wall_point()
		if _corners.size() > 1 and _split_room >= 0:
			# Waiting to split the room, drawn over it.
			draw_colored_polygon(_screen_points(plan().rooms[_split_room].points), Color(color, 0.06))
			draw_polyline(_screen_points(_corners), color, maxf(wall, 2.0), true)
		if not _corners.is_empty():
			var from: Vector2 = _corners[_corners.size() - 1]
			var thick: float = plan().inner_wall
			var side: Vector2 = (to - from).normalized().orthogonal() * thick * 0.5
			if to.distance_to(from) > 0.001:
				draw_colored_polygon(_screen_points(PackedVector2Array([from - side, to - side, to + side, from + side])), Color(color, 0.35))
				draw_line(to_screen(from), to_screen(to), color, 1.5, true)
			# Its length and direction, as it is drawn.
			var degrees: float = FloorPlan.wall_angle(PackedVector2Array([from, to]))
			draw_string(font, to_screen(to) + Vector2(10, -8), "%s m  %s°" % [_metres_text(from.distance_to(to)), String.num(degrees, 1)], HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), SchematicTheme.TEXT)
			var start_angle: float = 0.0
			var end_angle: float = (to - from).angle()
			draw_arc(to_screen(from), 22.0, minf(start_angle, end_angle), maxf(start_angle, end_angle), 24, Color(color, 0.6), 1.0, true)
			_draw_typed_size(font, to_screen(to) + Vector2(10, 10), false)
			draw_circle(to_screen(from), 3.0, color)
		draw_circle(to_screen(to), 4.0, color)
		_draw_snap_dimensions(font, to)
	if tool == Tool.OUTLINE:
		var next: Vector2 = _next_corner()
		var points: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in _corners:
			points.append(to_screen(p))
		if not _corners.is_empty():
			points.append(to_screen(next))
			draw_polyline(points, color, wall, true)
			# The way back to the first corner, dashed.
			CustomSymbol.stroke_line(self, PackedVector2Array([to_screen(next), to_screen(_corners[0])]), Color(color, 0.5), 1.0, "dash")
			draw_arc(to_screen(_corners[0]), FEATURE_GRAB * 0.6, 0.0, TAU, 20, color, 1.5, true)
			var last: Vector2 = _corners[_corners.size() - 1]
			draw_string(font, to_screen(next) + Vector2(8, -6), _metres_text(last.distance_to(next)) + " m", HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), SchematicTheme.TEXT)
			_draw_typed_size(font, to_screen(next) + Vector2(8, 12), false)
		for p: Vector2 in points:
			draw_circle(p, 3.0, color)
		if _corners.is_empty() and Rect2(Vector2.ZERO, size).has_point(_mouse):
			draw_circle(to_screen(next), 4.0, color)
		if Rect2(Vector2.ZERO, size).has_point(_mouse):
			_draw_snap_dimensions(font, next)
	if tool == Tool.PLACE_ROOM:
		var ghost: FloorPlan.Room = _placed_room()
		if ghost != null:
			var outline: PackedVector2Array = _screen_points(ghost.points)
			draw_colored_polygon(outline, Color(color, 0.08))
			outline.append(outline[0])
			draw_polyline(outline, color, wall, true)
			draw_string(font, to_screen(ghost.rect.position) + Vector2(6, 16), tr(ghost.name), HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(NAME_SIZE), color)


## [param points] (m) on the screen.
func _screen_points(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		result.append(to_screen(p))
	return result


## The width and depth typed (or, for a room drawn by its corners, the
## next wall's length) in a box at screen point [param at], the one typed
## into marked; nothing while nothing is typed.
func _draw_typed_size(font: Font, at: Vector2, both: bool) -> void:
	if _room_typed[0].is_empty() and _room_typed[1].is_empty():
		return
	var text: String = _room_typed[0] + " mm  ↵"
	if both:
		var parts: PackedStringArray = PackedStringArray()
		for axis: int in 2:
			var value: String = _room_typed[axis] if not _room_typed[axis].is_empty() else "…"
			parts.append(("[%s]" if axis == _room_field else "%s") % value)
		text = "%s × %s mm  ⇥ ↵" % [parts[0], parts[1]]
	var height: int = _sized(TEXT_SIZE)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, height).x
	var box: Rect2 = Rect2(at + Vector2(-4, -height - 2), Vector2(width + 8, height + 8))
	draw_rect(box, SchematicTheme.BACKGROUND)
	draw_rect(box, SchematicTheme.SELECTED, false, 1.0)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, height, SchematicTheme.SELECTED)


## The ready room being placed, where the mouse is (its middle there, on
## the grid, its walls onto the walls near); null for none.
func _placed_room() -> FloorPlan.Room:
	if placing_room < 0 or placing_room >= FloorPlan.PRESETS.size():
		return null
	var preset: Dictionary = FloorPlan.PRESETS[placing_room]
	var room_size: Vector2 = preset["size"]
	var at: Vector2 = FloorPlan.snap(to_plan(_mouse) - room_size * 0.5)
	var snapped: Rect2 = plan().snap_room(Rect2(at, room_size))
	return FloorPlan.preset_room(placing_room, snapped.position, preset["name"])


## Joins room [param first] with the room clicked next (Tool.JOIN).
func begin_join(first: int) -> void:
	tool = Tool.JOIN
	_join_first = first
	selected = {"kind": "room", "index": first}
	queue_redraw()


## Puts ready room [param index] where the plan is clicked next (again
## until a right click or Esc).
func begin_place_room(index: int) -> void:
	tool = Tool.PLACE_ROOM
	placing_room = index
	if is_inside_tree():
		grab_focus()
	queue_redraw()


## A key while a room is drawn or picked: a size or length typed (digits,
## Backspace, Tab between width and depth, Enter), Esc, Backspace taking
## the last corner back; Ctrl+D duplicates the room picked, the arrows
## move it (by 5 cm, with Shift by 50 cm). Returns whether it was taken.
func _room_key(key: InputEventKey) -> bool:
	var ch: String = String.chr(key.unicode) if key.unicode > 0 else ""
	var drawing: bool = _drawing_rect() or (tool in [Tool.OUTLINE, Tool.WALL] and not _corners.is_empty())
	if drawing and ch.length() == 1 and ch >= "0" and ch <= "9" and _room_typed[_room_field].length() < 6:
		_room_typed[_room_field] += ch
		return true
	if key.keycode == KEY_ESCAPE and (drawing or tool in [Tool.PLACE_ROOM, Tool.OUTLINE, Tool.WALL]):
		if drawing and tool == Tool.WALL:
			_end_walls()
		elif drawing:
			_room_from = Vector2(NAN, NAN)
			_corners = PackedVector2Array()
			_room_typed = PackedStringArray(["", ""])
			_press = {}
			_dragging = false
		else:
			tool = Tool.SELECT
			placed.emit()
		return true
	if drawing and key.keycode == KEY_BACKSPACE:
		if not _room_typed[_room_field].is_empty():
			_room_typed[_room_field] = _room_typed[_room_field].left(-1)
		elif tool == Tool.OUTLINE:
			_corners.remove_at(_corners.size() - 1)
		return true
	if _drawing_rect() and key.keycode == KEY_TAB:
		_room_field = 1 - _room_field
		return true
	if drawing and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		if tool == Tool.ROOM:
			if _room_typed[0].is_empty() and _room_typed[1].is_empty():
				return true
			var rect: Rect2 = _drawn_room()
			_press = {}
			_dragging = false
			_add_rect_room(rect)
		elif tool == Tool.WALL:
			if not _room_typed[0].is_empty():
				_add_wall_point()
		elif not _room_typed[0].is_empty():
			_add_corner(_next_corner())
		else:
			_close_outline()
		return true
	var room: int = selected.get("index", -1) if tool == Tool.SELECT and selected.get("kind", "") in ["room", "edge"] else -1
	if room < 0 or room >= plan().rooms.size():
		return false
	if key.keycode == KEY_D and key.is_command_or_control_pressed():
		var twin: int = plan().rooms.size()
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.duplicate_room(room))
		selected = {"kind": "room", "index": twin}
		return true
	var arrows: Dictionary[Key, Vector2] = {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}
	if arrows.has(key.keycode) and not key.is_command_or_control_pressed():
		var to: Vector2 = plan().rooms[room].rect.position + arrows[key.keycode] * (FloorPlan.SNAP * (10.0 if key.shift_pressed else 1.0))
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.move_room(room, to))
		return true
	return false


## [param rect] with each edge snapped onto a near wall of the rooms (but
## room [param skip]).
func _snap_corners(rect: Rect2, skip: int = -1) -> Rect2:
	var edges: Array[float] = [rect.position.x, rect.position.y, rect.end.x, rect.end.y]
	for side: int in 4:
		var span: Vector2 = Vector2(rect.position.y, rect.end.y) if side % 2 == 0 else Vector2(rect.position.x, rect.end.x)
		edges[side] = _snap_edge(edges[side], side % 2 == 1, skip, span)
	return Rect2(Vector2(edges[0], edges[1]), Vector2(edges[2] - edges[0], edges[3] - edges[1]))


## Coordinate [param v] (y when [param horizontal_edge]) onto the nearest
## wall running the same way within [constant FloorPlan.WALL_SNAP]; for an
## edge reaching along [param span] (x from .. to for one across, else y),
## onto a wall beside it along a stretch of it within
## [method FloorPlan.gap_reach] (wall to wall, no gap left for a wall of no
## set thickness). Walls at [param moving] (the line of a wall or corner
## dragged, which they move along with) are left out.
func _snap_edge(v: float, horizontal_edge: bool, skip: int, span: Vector2 = Vector2(NAN, NAN), moving: float = NAN) -> float:
	var best: float = FloorPlan.WALL_SNAP
	var result: float = v
	var more: float = plan().gap_reach() - FloorPlan.WALL_SNAP
	for i: int in plan().rooms.size():
		if i == skip:
			continue
		var room: FloorPlan.Room = plan().rooms[i]
		for k: int in room.points.size():
			var w: PackedVector2Array = room.wall(k)
			if is_equal_approx(w[0].y, w[1].y) != horizontal_edge or not FloorPlan.is_straight(w):
				continue
			var theirs: float = w[0].y if horizontal_edge else w[0].x
			if not is_nan(moving) and absf(theirs - moving) < 0.001:
				continue
			var near: float = absf(theirs - v)
			if not is_nan(span.x):
				var low: float = minf(w[0].x, w[1].x) if horizontal_edge else minf(w[0].y, w[1].y)
				var high: float = maxf(w[0].x, w[1].x) if horizontal_edge else maxf(w[0].y, w[1].y)
				if minf(high, maxf(span.x, span.y)) - maxf(low, minf(span.x, span.y)) > 0.01:
					near -= more
			if near < best:
				best = near
				result = theirs
	return result


## Where a corner of room [param index] dragged to the mouse goes: on the
## grid, onto the walls of the other rooms near.
func _corner_target(index: int) -> Vector2:
	var at: Vector2 = FloorPlan.snap(to_plan(_mouse))
	var box: Rect2 = plan().rooms[index].rect
	var corner: Vector2 = plan().rooms[index].points[_press.get("which", 0)] if _press.get("kind", "") == "corner" else Vector2(NAN, NAN)
	return Vector2(_snap_edge(at.x, false, index, Vector2(box.position.y, box.end.y), corner.x), _snap_edge(at.y, true, index, Vector2(box.position.x, box.end.x), corner.y))


## Where wall [param k] of room [param index] dragged to the mouse goes: its
## x or y snapped onto a wall running the same way, kept so the walls beside
## it stay long enough.
func _edge_target(index: int, k: int) -> float:
	var room: FloorPlan.Room = plan().rooms[index]
	var w: PackedVector2Array = room.wall(k)
	var horizontal: bool = is_equal_approx(w[0].y, w[1].y)
	var m: Vector2 = FloorPlan.snap(to_plan(_mouse))
	var span: Vector2 = Vector2(w[0].x, w[1].x) if horizontal else Vector2(w[0].y, w[1].y)
	return FloorPlan._clamp_edge(room, k, _snap_edge(m.y if horizontal else m.x, horizontal, index, span, w[0].y if horizontal else w[0].x))


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
		text += "  " + ApplianceSymbol.title_of(c as Appliance)
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
	_draw_free_walls()
	_draw_reference(font)
	for i: int in shapes.size():
		if plan().rooms[i].stairs:
			_draw_stairs(shapes[i], plan().rooms[i].stairs_reverse)
	for i: int in rooms.size():
		var chosen: bool = selected.get("kind", "") == "room" and selected.get("index", -1) == i
		if chosen or i == _join_first:
			_draw_walls(rooms[i], SchematicTheme.SELECTED, 2.0)
	# The walls selected, each alone (a wall taken away dashed).
	for wall_at: Vector2i in selected_walls():
		var w: PackedVector2Array = _shown_points(wall_at.x)
		var a: Vector2 = to_screen(w[wall_at.y])
		var b: Vector2 = to_screen(w[(wall_at.y + 1) % w.size()])
		if plan().rooms[wall_at.x].is_open(wall_at.y):
			draw_dashed_line(a, b, SchematicTheme.SELECTED, 3.0, 6.0, true)
		else:
			draw_line(a, b, SchematicTheme.SELECTED, 4.0, true)
	for i: int in plan().doors.size():
		_draw_door(_shown_opening("door", i), s, wall, selected.get("kind", "") == "door" and selected.get("index", -1) == i)
	for i: int in plan().windows.size():
		_draw_window(_shown_opening("window", i), s, selected.get("kind", "") == "window" and selected.get("index", -1) == i)
	if editing and tool in [Tool.DOOR, Tool.WINDOW] and Rect2(Vector2.ZERO, size).has_point(_mouse):
		# The door or window a click puts in, where it would go.
		var near: Dictionary = plan().wall_near(to_plan(_mouse), 0.3)
		if not near.is_empty() and near["straight"]:
			var vertical: bool = int(near["facing"]) % 2 == 0
			if tool == Tool.DOOR:
				_draw_door(_new_door(near["at"], vertical), s, wall, true)
			else:
				_draw_window(FloorPlan.WindowOpening.new(near["at"], vertical), s, true)
	for i: int in plan().fixtures.size():
		var fixture: FloorPlan.Fixture = plan().fixtures[i]
		if not shows(fixture):
			continue
		var chosen_fixture: bool = selected.get("kind", "") == "fixture" and selected.get("index", -1) == i
		_draw_fixture(fixture, _shown_fixture_rect(i), SchematicTheme.SELECTED if chosen_fixture else Color(SchematicTheme.LINE, 0.4))
	if installation():
		_draw_bath_zones(font)
	if editing and tool == Tool.PLACE and placing_template.get("type", "") == "fixture":
		var ghost: FloorPlan.Fixture = plan().fixture_at_point(str(placing_template.get("kind", "table")), to_plan(_mouse))
		_draw_fixture(ghost, ghost.rect, SchematicTheme.SELECTED)
	var line_width: float = clampf(1.6 * zoom, 1.0, 2.5)
	for i: int in plan().marks.size():
		var def: CustomSymbol = document.symbol(plan().marks[i].symbol)
		if def != null and shows(plan().marks[i]):
			var chosen_mark: bool = selected.get("kind", "") == "mark" and selected.get("index", -1) == i
			def.draw(self, to_screen(_mark_origin(i)), s * _symbols(), SchematicTheme.SELECTED if chosen_mark else SchematicTheme.LINE, line_width, font, chosen_mark)
	if editing and tool == Tool.PLACE and placing_template.has("symbol"):
		# The user's symbol where it would go.
		var ghost_def: CustomSymbol = template_symbol(document, placing_template)
		if ghost_def != null:
			var ghost_at: Vector2 = FloorPlan.snap(to_plan(_mouse))
			if not _template_on_ceiling(placing_template):
				var near: Dictionary = plan().wall_near(to_plan(_mouse))
				if not near.is_empty():
					ghost_at = Vector2(near["at"]) + (FloorPlan.FACING[int(near["facing"])] - Vector2.DOWN) * WALL_SYMBOL_OFFSET * _symbols()
			ghost_def.draw(self, to_screen(ghost_at), s * _symbols(), Color(SchematicTheme.SELECTED, 0.6), line_width, font, true)
	if installation():
		_draw_links(font)
	else:
		_draw_cables(s, font)
	# Each part's designation where it is clear of the other symbols and
	# designations.
	_taken = []
	for designation: String in plan().parts:
		if layer_shows(designation):
			_taken.append(_symbol_box(designation, s * _symbols()))
	for designation: String in plan().parts:
		if layer_shows(designation):
			_draw_part(designation, s, font)
	for i: int in rooms.size():
		# Name and area in the room's corner, clear of its ceiling light (or
		# where it was dragged to); in a residential installation its number
		# (the legend names it).
		var room: FloorPlan.Room = plan().rooms[i]
		var corner: Vector2 = _label_at(i)
		var chosen_label: bool = selected.get("kind", "") == "label" and selected.get("index", -1) == i
		if installation():
			draw_string(font, corner, plan().room_number(i), HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(NAME_SIZE) + 6, SchematicTheme.SELECTED if chosen_label else Color(SchematicTheme.LINE, 0.75))
		else:
			draw_string(font, corner, tr(room.name), HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(NAME_SIZE), SchematicTheme.SELECTED if chosen_label else Color(SchematicTheme.LINE, 0.55))
		var area: String = "%s m²" % String.num(room.area(), 1)
		draw_string(font, corner + Vector2(0, _sized(NAME_SIZE) + 1), area, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), Color(SchematicTheme.LINE, 0.45))
	if editing:
		_draw_room_tools(s, font, wall)
	if editing and tool == Tool.PLACE and not placing.is_empty():
		var m: Vector2 = to_plan(_mouse)
		var wall_point: Dictionary = {} if on_ceiling(document.circuit.get_component(placing)) else plan().wall_near(m)
		var at: Vector2 = wall_point.get("at", FloorPlan.snap(m))
		draw_circle(to_screen(at), 4.0, SchematicTheme.SELECTED)
		draw_string(font, to_screen(at) + Vector2(8, -6), ("-" if placing != FloorPlan.UNIT else "") + placing, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), SchematicTheme.DESIGNATION)
	if editing and tool == Tool.PLACE and not placing_template.is_empty():
		var m: Vector2 = to_plan(_mouse)
		var wall_point: Dictionary = {} if _template_on_ceiling(placing_template) else plan().wall_near(m)
		draw_circle(to_screen(wall_point.get("at", FloorPlan.snap(m))), 4.0, SchematicTheme.SELECTED)
	if editing and tool == Tool.WIRE and _press.get("kind", "") == "new_link":
		draw_dashed_line(to_screen(_link_end(_press["designation"])), _mouse, SchematicTheme.SELECTED, 1.6, 5.0)
	_draw_saved_dimensions(font)
	_draw_wall_distance(font)
	_draw_corner_slide(font)
	if editing and _dragging and _press.get("kind", "") == "door_swing":
		# The corners the door can be turned to.
		var door: FloorPlan.Door = plan().doors[_press["index"]]
		for hinge_end: bool in [false, true]:
			for back: bool in [false, true]:
				var turned: FloorPlan.Door = FloorPlan.Door.new(door.at, door.vertical, door.width)
				turned.kind = door.kind
				turned.double = door.double
				turned.hinge_end = hinge_end
				turned.opens_back = back
				draw_arc(to_screen(door_corner(turned)), HANDLE + 2.0, 0.0, TAU, 16, Color(SchematicTheme.SELECTED, 0.6), 1.2, true)
	if editing and _dragging and _press.get("kind", "") == "free_wall_end":
		_draw_snap_dimensions(font, _wall_end_target(_press["index"], _press["which"]))
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
	if editing:
		_draw_room_feedback(s, font)
	if legend:
		_draw_legend(s, font)
	if plan().rooms.is_empty() and editing:
		var hint: String = tr("Draw a room: pick Room and drag, or add one of the ready rooms.")
		if reference_floor() >= 0:
			hint = tr("Draw this floor over the one below it, dash-dot: its corners are caught (by the corners of the house, then walls across it).")
		draw_string(font, Vector2(20, 30), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(NAME_SIZE), Color(SchematicTheme.LINE, 0.6))


## Whether part [param designation] is drawn: on no layer or on one shown
## (the consumer unit always).
func layer_shows(designation: String) -> bool:
	return document.layer_shown(plan().layer_of(designation))


## Whether [param item] (a note, dimension, fixture or mark) is drawn: on
## no layer or on one shown.
func shows(item: Object) -> bool:
	return document.layer_shown(str(item.get("layer")))


## Whether link [param link] is drawn: both its parts are.
func _link_shown(link: FloorPlan.Link) -> bool:
	return layer_shows(link.a) and layer_shows(link.b)


## The layer something new goes on: [member active_layer] while the schematic
## has it, else none.
func new_layer() -> String:
	return active_layer if document != null and document.plan_layer(active_layer) != null else ""


## The rows of the legend: a symbol used on the plan shown (on a layer drawn),
## each {"key", "sample" (a part drawn so; null for the unit and the cable),
## "symbol" (the user's own symbol it is drawn with, if it is),
## "title", "height" (its standard height as written, "" for none), "count"},
## switches by their number, sockets single and double, ceiling and wall
## luminaires, appliances by kind and by the user's symbol, the user's
## drawing-only symbols, then the consumer unit and the cable.
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
		elif c is Appliance and document.symbol((c as Appliance).symbol) != null:
			key = "4~" + (c as Appliance).symbol
			row = {"title": (c as Appliance).title, "height": "", "symbol": document.symbol((c as Appliance).symbol)}
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
	for mark: FloorPlan.Mark in plan().marks:
		var def: CustomSymbol = document.symbol(mark.symbol)
		if def == null or not shows(mark):
			continue
		var key: String = "5" + mark.symbol
		if rows.has(key):
			rows[key]["count"] += 1
		else:
			rows[key] = {"key": key, "sample": null, "symbol": def, "title": def.name, "height": "", "count": 1}
	var cabled: bool = false
	if installation():
		cabled = plan().links.any(_link_shown)
	else:
		cabled = plan().cables(document.circuit).any(func(cable: Dictionary) -> bool: return layer_shows(cable["a"]) and layer_shows(cable["b"]))
	if cabled:
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
	draw_string(font, top, tr("Legend"), HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(NAME_SIZE), color)
	var width: float = clampf(1.6 * zoom, 1.0, 2.5)
	# The symbols as large as on the plan.
	var ss: float = s * _symbols()
	for i: int in rows.size():
		var column: int = i / rows_in_column
		var at: Vector2 = top + Vector2(column * LEGEND_COLUMN * s, (0.45 + (i % rows_in_column) * _legend_row()) * s)
		var symbol: Vector2 = at + Vector2(0.3 * ss, -0.08 * s)
		var sample: CircuitComponent = rows[i]["sample"]
		if rows[i].has("symbol"):
			(rows[i]["symbol"] as CustomSymbol).draw_fitted(self, Rect2(symbol - Vector2(0.3, 0.24) * ss, Vector2(0.6, 0.44) * ss), ss, color, width, font)
		match str(rows[i]["key"]).left(1) if not rows[i].has("symbol") else "":
			"0":
				PlanSymbols.draw_switch(self, sample as LightSwitch, symbol + Vector2(0, -0.1 * ss), Vector2.DOWN, ss, color, width)
			"1":
				PlanSymbols.draw_socket(self, sample as SocketOutlet, symbol + Vector2(0, -0.1 * ss), Vector2.DOWN, ss, color, width, false)
			"2":
				PlanSymbols.draw_luminaire(self, symbol, ss, color, width, false)
			"3":
				PlanSymbols.draw_luminaire(self, symbol + Vector2(0, -0.15 * ss), ss, color, width, false, Vector2.DOWN)
			"4":
				PlanSymbols.draw_appliance(self, sample as Appliance, symbol + Vector2(0, -0.25 * ss), Vector2.DOWN, ss * 0.7, color, width, false)
			"6":
				PlanSymbols.draw_unit(self, symbol + Vector2(0, -0.1 * ss), Vector2.DOWN, ss * 0.8, color, width)
			"7":
				draw_dashed_line(symbol - Vector2(0.25 * s, 0), symbol + Vector2(0.25 * s, 0), SchematicTheme.DESIGNATION, 1.4, 6.0)
				for k: int in 3:
					var p: Vector2 = symbol + Vector2((k - 1) * 4.0, 0)
					draw_line(p + Vector2(-3, 5), p + Vector2(3, -5), SchematicTheme.DESIGNATION, 1.2, true)
		var text: String = str(rows[i]["title"]) + ("  –  " + str(rows[i]["height"]) if not str(rows[i]["height"]).is_empty() else "")
		draw_string(font, at + Vector2(0.45 * s + 0.3 * ss, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), SchematicTheme.TEXT)
		if int(rows[i]["count"]) > 0:
			var count: String = "%d×" % int(rows[i]["count"])
			var count_width: float = font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE)).x
			draw_string(font, at + Vector2((LEGEND_COLUMN - 0.6) * s - count_width, 0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), SchematicTheme.TEXT)
	_draw_scale_and_north(s, font, area)
	var note: String = tr("Heights are to the middle of the box; a height other than these is written beside the part (h).")
	draw_string(font, top + Vector2(0, (0.45 + rows_in_column * _legend_row()) * s), note, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), SchematicTheme.TEXT)


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
	var nw: float = font.get_string_size(north_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(NAME_SIZE)).x
	draw_string(font, tip + up * 12.0 + Vector2(-nw * 0.5, _sized(NAME_SIZE) * 0.4), north_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(NAME_SIZE), color)
	if print_scale <= 0:
		return
	# The scale and a bar of [constant SCALE_BAR] metres, true to the plan,
	# every other one filled.
	var bar_top: Vector2 = to_screen(Vector2(left, top + 1.3))
	draw_string(font, to_screen(Vector2(left, top + 0.6)), tr("Scale 1:%d") % print_scale, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(NAME_SIZE), color)
	for k: int in SCALE_BAR:
		var cell: Rect2 = Rect2(bar_top + Vector2(k * s, 0), Vector2(s, 0.12 * s))
		if k % 2 == 0:
			draw_rect(cell, color)
		draw_rect(cell, color, false, 1.0)
	for k: int in SCALE_BAR + 1:
		var label: String = str(k)
		var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE)).x
		draw_string(font, bar_top + Vector2(k * s - lw * 0.5, 0.12 * s + _sized(TEXT_SIZE) + 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), color)
	draw_string(font, bar_top + Vector2(SCALE_BAR * s + 8.0, 0.12 * s), "m", HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), color)


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
	var preview: FloorPlan = _room_preview()
	if preview != null and index < preview.rooms.size():
		return preview.rooms[index].points
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
	return room.points


## The rooms as the corner or wall being dragged leaves them (the edit tried
## on a copy of them, every room it moves), null while none is dragged.
func _room_preview() -> FloorPlan:
	if not _dragging or _press.get("kind", "") not in ["corner", "edge"]:
		_preview = null
		return null
	var key: Array = [_mouse, _press_at, _press.get("kind", ""), Input.is_key_pressed(KEY_SHIFT)]
	if _preview != null and key == _preview_key:
		return _preview
	var preview: FloorPlan = plan().rooms_copy()
	var index: int = _press["index"]
	if _press["kind"] == "corner":
		preview.set_corner(index, _press["which"], _corner_target(index), Input.is_key_pressed(KEY_SHIFT))
	elif FloorPlan.is_straight(plan().rooms[index].wall(_press["side"])):
		preview.set_edge(index, _press["side"], _edge_target(index, _press["side"]))
	else:
		preview.move_wall(index, _press["side"], _slant_shift(index, _press["side"]))
	_preview = preview
	_preview_key = key
	return preview


## How far slanting wall [param k] of room [param index] is dragged out of
## the room (m, on the grid; into it when negative).
func _slant_shift(index: int, k: int) -> float:
	var w: PackedVector2Array = plan().rooms[index].wall(k)
	var out: Vector2 = -(w[1] - w[0]).normalized().rotated(PI / 2.0)
	return snappedf((to_plan(_mouse) - to_plan(_press_at)).dot(out), FloorPlan.SNAP)


## While a corner shared by rooms slides along a wall: its distances to the
## wall's ends, in the rooms.
func _draw_corner_slide(font: Font) -> void:
	if not editing or not _dragging or _press.get("kind", "") != "corner":
		return
	var index: int = _press["index"]
	var k: int = _press["which"]
	var start: Vector2 = plan().rooms[index].points[k]
	var line: PackedVector2Array = plan().corner_line(start)
	if line.is_empty():
		return
	var now: Vector2 = _shown_points(index)[k]
	var into: Vector2 = (line[1] - line[0]).normalized().orthogonal()
	if plan().room_at(start + into * 0.05) < 0:
		into = -into
	for end: Vector2 in line:
		if end.distance_to(now) > 0.01:
			_draw_wall_dimension(font, end, now, into, SchematicTheme.SELECTED)


## Where part [param designation] is shown: where it is dragged to.
func _shown_at(designation: String) -> Vector2:
	var at: Vector2 = plan().parts[designation]
	if _dragging and _press.get("kind", "") == "part" and _press.get("designation", "") == designation:
		return FloorPlan.snap(at + to_plan(_mouse) - to_plan(_press_at))
	if _dragging and _press.get("kind", "") == "room":
		return at + _room_drag_shift(at)
	if _dragging and _press.get("kind", "") in ["edge", "corner"] and plan().facing.has(designation):
		return at + _wall_drag_shift(at)
	return at


## The walls of the rooms of outlines [param shapes] ([param rooms] on the
## screen; see [method FloorPlan.wall_pieces]): each room grown by its
## outside walls' thickness, the rooms' floors over them, then the walls
## between rooms where they lie, run on past their ends to meet the walls
## they join but never over a floor.
func _draw_building(shapes: Array[PackedVector2Array], rooms: Array[PackedVector2Array], s: float) -> void:
	var color: Color = wall_color()
	var pieces: Array[Dictionary] = plan().wall_pieces(shapes)
	for i: int in shapes.size():
		var offsets: PackedFloat32Array = PackedFloat32Array()
		# A staircase's start is open.
		var open: int = FloorPlan.stair_start_wall(shapes[i], plan().rooms[i].stairs_reverse) if plan().rooms[i].stairs else -1
		for k: int in shapes[i].size():
			var own: float = plan().rooms[i].wall_thickness(k)
			offsets.append(0.0 if k == open or plan().rooms[i].is_open(k) else own if own > 0.0 else plan().outer_wall)
		draw_colored_polygon(_screen_points(FloorPlan.grown(shapes[i], offsets)), color)
	for outline: PackedVector2Array in rooms:
		draw_colored_polygon(outline, SchematicTheme.BACKGROUND)
		draw_colored_polygon(outline, Color(SchematicTheme.LINE, 0.03))
	for piece: Dictionary in pieces:
		if int(piece["other"]) < 0:
			continue
		var a: Vector2 = piece["a"]
		var b: Vector2 = piece["b"]
		var out: Vector2 = piece["out"]
		var from: float = piece["from"]
		var to: float = piece["to"]
		var dir: Vector2 = (b - a).normalized()
		draw_colored_polygon(_screen_points(PackedVector2Array([a + out * from, b + out * from, b + out * to, a + out * to])), color)
		# Run on past each end, round a corner, but off the floors; not off
		# the floor of either of its rooms where that has a corner of more
		# than a right angle there (a slanting wall), so the band reaches
		# the wall across.
		var reach: float = to - from
		for end: PackedVector2Array in [PackedVector2Array([a - dir * reach, a]), PackedVector2Array([b, b + dir * reach])]:
			var tip: Vector2 = a if end[1] == a else b
			var rest: Array[PackedVector2Array] = [PackedVector2Array([end[0] + out * from, end[1] + out * from, end[1] + out * to, end[0] + out * to])]
			for j: int in shapes.size():
				if (j == int(piece["room"]) or j == int(piece["other"])) and FloorPlan.obtuse_corner(shapes[j], tip):
					continue
				var cut: Array[PackedVector2Array] = []
				for part: PackedVector2Array in rest:
					cut.append_array(Geometry2D.clip_polygons(part, shapes[j]))
				rest = cut
			for part: PackedVector2Array in rest:
				draw_colored_polygon(_screen_points(part), color)


## The stairs of a staircase of outline [param points] (see
## [method FloorPlan.stair_lines]): its treads, the walking line from a dot
## where it starts to an arrow where it goes up to.
func _draw_stairs(points: PackedVector2Array, reverse: bool) -> void:
	var stairs: Dictionary = FloorPlan.stair_lines(points, reverse)
	var color: Color = Color(SchematicTheme.LINE, 0.6)
	for tread: PackedVector2Array in stairs["treads"]:
		draw_line(to_screen(tread[0]), to_screen(tread[tread.size() - 1]), color, 1.0, true)
	var walk: PackedVector2Array = _screen_points(stairs["walk"])
	if walk.size() < 2:
		return
	draw_polyline(walk, SchematicTheme.LINE, 1.3, true)
	draw_circle(walk[0], 3.5, SchematicTheme.LINE)
	var tip: Vector2 = walk[walk.size() - 1]
	var back: Vector2 = (walk[walk.size() - 2] - tip).normalized() * 10.0
	draw_colored_polygon(PackedVector2Array([tip, tip + back + back.orthogonal() * 0.4, tip + back - back.orthogonal() * 0.4]), SchematicTheme.LINE)


## Across the wall [param opening] is in: from where to where its band
## goes (m), as offsets from the wall's line; and the way into the room.
func _band(opening: FloorPlan.Opening) -> Dictionary:
	var piece: Dictionary = plan().wall_piece_at(opening.at)
	if not piece.is_empty():
		return {"from": piece["from"], "to": piece["to"], "across": piece["out"]}
	var across: Vector2 = Vector2.RIGHT if opening.vertical else Vector2.DOWN
	var a_room: bool = plan().room_at(opening.at + across * 0.05) >= 0
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
	var cut: PackedVector2Array = _cut(door)
	var color: Color = SchematicTheme.SELECTED if chosen else Color(SchematicTheme.LINE, 0.7)
	var across: Vector2 = door_across(door)
	# A leaf from each end for a double door, meeting in the middle.
	var leaves: Array = [[a, b], [b, a]] if door.double else [[b, a] if door.hinge_end else [a, b]]
	var length: float = door.width * s * (0.5 if door.double else 1.0)
	match door.kind:
		FloorPlan.DoorKind.SWING, FloorPlan.DoorKind.DOUBLE_ACTING:
			for leaf_ends: Array in leaves:
				var hinge: Vector2 = leaf_ends[0]
				var latch: Vector2 = leaf_ends[1]
				draw_line(hinge, hinge + across * length, color, 1.5, true)
				var start: float = (latch - hinge).angle()
				draw_arc(hinge, length, start, start + angle_difference(start, across.angle()), 16, color, 1.0, true)
				if door.kind == FloorPlan.DoorKind.DOUBLE_ACTING:
					# It swings the other way too.
					draw_line(hinge, hinge - across * length, Color(color, color.a * 0.5), 1.5, true)
					draw_arc(hinge, length, start, start + angle_difference(start, (-across).angle()), 16, Color(color, color.a * 0.5), 1.0, true)
		FloorPlan.DoorKind.SLIDING, FloorPlan.DoorKind.POCKET:
			# The leaf closed over the opening (outside the wall's face, or
			# in the wall for a pocket door), where it slides to dashed, an
			# arrow the way it slides.
			var face: Vector2 = cut[0] if (cut[0] - a).dot(across) > (cut[1] - a).dot(across) else cut[1]
			var off: Vector2 = (cut[0] + cut[1]) * 0.5 - a if door.kind == FloorPlan.DoorKind.POCKET else face - a + across * 3.0
			for leaf_ends: Array in leaves:
				var to: Vector2 = leaf_ends[0]
				var from: Vector2 = leaf_ends[1] if not door.double else (a + b) * 0.5
				var way: Vector2 = (to - from).normalized()
				var span: float = from.distance_to(to)
				draw_line(from + off, to + off, color, 3.0, true)
				draw_dashed_line(to + off, to + off + way * span, color, 1.5, 4.0, true)
				var tip: Vector2 = (from + to) * 0.5 + off + across * 7.0 + way * span * 0.25
				draw_line(tip - way * span * 0.4, tip, color, 1.0, true)
				draw_line(tip, tip - way * 6.0 + across * 3.0, color, 1.0, true)
				draw_line(tip, tip - way * 6.0 - across * 3.0, color, 1.0, true)
		FloorPlan.DoorKind.FOLDING:
			# Its panels folded up, a zigzag from where it folds to.
			for leaf_ends: Array in leaves:
				var hinge: Vector2 = leaf_ends[0]
				var latch: Vector2 = leaf_ends[1] if not door.double else (a + b) * 0.5
				var points: PackedVector2Array = PackedVector2Array()
				var panels: int = 4
				for k: int in panels + 1:
					var p: Vector2 = hinge.lerp(latch, float(k) / panels * 0.5)
					points.append(p + (across * length * 0.22 if k % 2 == 1 else Vector2.ZERO))
				draw_polyline(points, color, 1.5, true)
				draw_dashed_line(points[points.size() - 1], latch, color, 1.0, 4.0, true)
		FloorPlan.DoorKind.GARAGE:
			# The door closed in the opening; dashed where it goes up under
			# the ceiling.
			draw_line(a, b, color, 2.0, true)
			var depth: float = minf(door.width, 2.5) * s
			for p: Vector2 in [a, b]:
				draw_dashed_line(p, p + across * depth, color, 1.0, 5.0, true)
			draw_dashed_line(a + across * depth, b + across * depth, color, 1.0, 5.0, true)


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
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE)).x
		var mid: Vector2 = (sa + sb) * 0.5 - toward * 4.0
		if absf(dir.y) < 0.5:
			# Over a dimension above its wall, under one below it.
			draw_string(font, mid + Vector2(-width * 0.5, _sized(TEXT_SIZE) if toward.y < 0.0 else 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), color)
		else:
			# Across, beside a dimension up and down, on its side away from the wall.
			draw_string(font, mid + Vector2(-width - 2.0 if toward.x > 0.0 else 2.0, _sized(TEXT_SIZE) * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), color)


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
	rect.position += _room_drag_shift(rect.get_center())
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
		if not shows(note):
			continue
		var at: Vector2 = note.at + _room_drag_shift(note.at)
		var label: Vector2 = note.label + _room_drag_shift(note.at)
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
		var under: float = box.position.y + _sized(TEXT_SIZE) + 4.0
		# The leader to the nearer end of the first line's underline.
		var near_end: Vector2 = Vector2(box.position.x if to_screen(at).x <= box.get_center().x else box.end.x, under)
		draw_circle(to_screen(at), 2.6, color)
		draw_line(to_screen(at), near_end, color, 1.0, true)
		draw_line(Vector2(box.position.x, under), Vector2(box.end.x, under), color, 1.0, true)
		var lines: PackedStringArray = note.text.split("\n")
		for k: int in lines.size():
			draw_string(font, to_screen(label) + Vector2(0, k * (_sized(TEXT_SIZE) + 3)), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), color)


## The saved dimensions: a line with a slanted tick and an extension line
## at each cut, the length of each piece over it (the selected one in the
## hover colour).
func _draw_saved_dimensions(font: Font) -> void:
	for i: int in plan().dimensions.size():
		if not shows(plan().dimensions[i]):
			continue
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
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE)).x
	var mid: Vector2 = (a + b) * 0.5 + away * 3.0
	var dir: Vector2 = (b - a).normalized()
	if absf(dir.y) < 0.5:
		draw_string(font, mid + Vector2(-width * 0.5, 0.0 if away.y < 0.0 else _sized(TEXT_SIZE)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), color)
	else:
		# Across, beside a dimension up and down, on its side away from the wall.
		draw_string(font, mid + Vector2(-width - 2.0 if away.x < 0.0 else 2.0, _sized(TEXT_SIZE) * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), color)


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
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE)).x
	draw_rect(Rect2(at + Vector2(-4, -_sized(TEXT_SIZE) - 2), Vector2(width + 8, _sized(TEXT_SIZE) + 8)), SchematicTheme.BACKGROUND)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), SchematicTheme.SELECTED)


static func _metres_text(metres: float) -> String:
	return SingleLineCanvas._decimal(String.num(metres, 2).pad_decimals(2))


## The lighting of a residential installation: each link along the walls,
## a tick per core it carries (the nets its two ends share).
func _draw_links(font: Font) -> void:
	var nets: Dictionary[String, int] = _nets()
	_draw_stair_ghosts(font, PX * zoom)
	# This floor's links, then those of the floors above and below to a part
	# of this one (through a staircase).
	var links: Array[FloorPlan.Link] = plan().links.duplicate()
	for other: FloorPlan in document.floors:
		if other == plan():
			continue
		for link: FloorPlan.Link in other.links:
			if plan().parts.has(link.a) != plan().parts.has(link.b):
				links.append(link)
	for i: int in links.size():
		var link: FloorPlan.Link = links[i]
		if is_nan(_link_end(link.a).x) or is_nan(_link_end(link.b).x) or not _link_shown(link):
			continue
		var chosen: bool = i < plan().links.size() and selected.get("kind", "") == "link" and selected.get("index", -1) == i
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
	draw_string(font, top_left + Vector2(0, -0.2 * s), tr("Legend"), HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(NAME_SIZE) + 2, color)
	var heads: PackedStringArray = PackedStringArray([tr("Number"), tr("Purpose of the room"), tr("Environment (ČSN 33 2000-5-51)"), tr("Illuminance (lx)")])
	var rows: int = plan().rooms.size() + 1
	draw_rect(Rect2(top_left, Vector2(rect.size.x, rows * ROOM_ROW) * s), color, false, 1.0)
	for row: int in range(1, rows):
		var y: float = top_left.y + row * ROOM_ROW * s
		draw_line(Vector2(top_left.x, y), Vector2(top_left.x + rect.size.x * s, y), color, 1.0)
	var x: float = top_left.x
	var text_size: int = maxi(roundi(_sized(TEXT_SIZE) * zoom), 6)
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
		if not (layer_shows(cable["a"]) and layer_shows(cable["b"])):
			continue
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
			draw_string(font, mid + dir.rotated(PI / 2.0) * 12.0, str(cores), HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), color)


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
	var at: Vector2 = to_screen(middle - upright * WALL_SYMBOL_OFFSET * _symbols())
	# The symbol as large as the plan has its symbols.
	s *= _symbols()
	var chosen: bool = selected.get("kind", "") == "part" and selected.get("designation", "") == designation
	var color: Color = SchematicTheme.SELECTED if chosen else SchematicTheme.LINE
	var width: float = clampf(1.6 * zoom, 1.0, 2.5)
	var offset: float = _offset(designation) if into != Vector2.ZERO else 0.0
	if offset > 0.0:
		# Moved off its wall: a thin line back to where it is on the wall.
		var wall_at: Vector2 = _shown_at(designation) + _face(designation)
		draw_line(to_screen(wall_at), to_screen(wall_at + into * offset), color, 1.0, true)
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
		elif installation():
			# Its circuit's number after the designation.
			var fed: SingleLine.Feeder = document.single_line.feeder_feeding(designation)
			if fed != null:
				label += " /%d" % fed.number
		if c is LightSwitch:
			PlanSymbols.draw_switch(self, c as LightSwitch, at, upright, s, color, width)
			if not is_equal_approx((c as LightSwitch).height, LightSwitch.STANDARD_HEIGHT):
				height_text = _height((c as LightSwitch).height)
		elif c is SocketOutlet:
			var socket: SocketOutlet = c as SocketOutlet
			PlanSymbols.draw_socket(self, socket, to_screen(_shown_at(designation) + _face(designation) + into * offset), into, s, color, width, not editing and socket.energized)
			if not is_equal_approx(socket.height, SocketOutlet.STANDARD_HEIGHT):
				height_text = _height(socket.height)
		elif c is Luminaire:
			var luminaire: Luminaire = c as Luminaire
			PlanSymbols.draw_luminaire(self, at, s, color, width, not editing and luminaire.energized, upright if luminaire.wall else Vector2.ZERO)
			if not is_equal_approx(luminaire.height, luminaire.standard_height()):
				height_text = _height(luminaire.height)
		elif c is Appliance and document.symbol((c as Appliance).symbol) != null:
			# Drawn with the user's own symbol, glowing while it works.
			var def: CustomSymbol = document.symbol((c as Appliance).symbol)
			if not editing and (c as Load).energized:
				var box: Rect2 = def.bounds()
				draw_circle(at + box.get_center() * s, maxf(box.size.x, box.size.y) * 0.6 * s, PlanSymbols.GLOW)
			def.draw(self, at, s, color, width, font, chosen)
			if not is_equal_approx((c as Appliance).height, Appliance.STANDARD_HEIGHT):
				height_text = _height((c as Appliance).height)
		elif c is Appliance:
			PlanSymbols.draw_appliance(self, c as Appliance, at, upright, s, color, width, not editing and (c as Load).energized)
			if not is_equal_approx((c as Appliance).height, Appliance.STANDARD_HEIGHT):
				height_text = _height((c as Appliance).height)
	# The designation beside the symbol, away from its wall.
	var center: Vector2 = to_screen(middle)
	var text_at: Vector2 = _label_spot(designation, center, into, label, height_text, s, font)
	draw_string(font, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE), SchematicTheme.DESIGNATION)
	if not height_text.is_empty():
		draw_string(font, text_at + Vector2(0, _sized(TEXT_SIZE)), height_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE) - 1, SchematicTheme.TEXT)


## Screen boxes of the symbols and the designations drawn so far.
var _taken: Array[Rect2] = []


## The box round the symbol of part [param designation] on screen, its
## symbol drawn [param s] pixels a metre (the plan's symbol size taken in).
func _symbol_box(designation: String, s: float) -> Rect2:
	var center: Vector2 = _symbol_middle(designation)
	var c: CircuitComponent = document.circuit.get_component(designation) if designation != FloorPlan.UNIT else null
	var def: CustomSymbol = document.symbol((c as Appliance).symbol) if c is Appliance else null
	if def != null:
		# The user's symbol: what it covers, from its origin.
		var origin: Vector2 = center - (Vector2(0, WALL_SYMBOL_OFFSET * s) if plan().facing.has(designation) else Vector2.ZERO)
		var box: Rect2 = def.bounds()
		return Rect2(origin + box.position * s, box.size * s)
	var half: float = 0.2 * s
	return Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)


## Where the middle of part [param designation]'s symbol is on screen (dragged: where it goes).
func _symbol_middle(designation: String) -> Vector2:
	return to_screen(_shown_at(designation) + symbol_center(designation) - plan().parts[designation])


## Where the designation [param label] (with [param height_text] under it)
## of part [param designation] goes: beside its symbol at [param center]
## (drawn [param s] pixels a metre), just past its symbol's box, on the side
## into the room ([param into]) first, else right, left, below or above, the
## first clear of the other symbols and designations, a step further out
## when none is. Takes the box it gets.
func _label_spot(designation: String, center: Vector2, into: Vector2, label: String, height_text: String, s: float, font: Font) -> Vector2:
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE)).x
	if not height_text.is_empty():
		width = maxf(width, font.get_string_size(height_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sized(TEXT_SIZE) - 1).x)
	var height: float = _sized(TEXT_SIZE) * (2.0 if not height_text.is_empty() else 1.0)
	var ascent: float = font.get_ascent(_sized(TEXT_SIZE))
	var sides: Array[Vector2] = []
	if into != Vector2.ZERO:
		sides.append(into)
	for side: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		if not sides.has(side):
			sides.append(side)
	var own: Rect2 = _symbol_box(designation, s)
	var first: Vector2 = Vector2.INF
	# How far the symbol reaches from its centre on each side: at least as
	# far as a symbol of the palette does.
	var middle: Vector2 = _symbol_middle(designation)
	var reach: Dictionary[Vector2, float] = {Vector2.RIGHT: own.end.x - middle.x, Vector2.LEFT: middle.x - own.position.x, Vector2.DOWN: own.end.y - middle.y, Vector2.UP: middle.y - own.position.y}
	for step: int in 3:
		for side: Vector2 in sides:
			var gap: float = maxf(0.22 * s, reach[side] + 0.02 * s) + 2.0 + step * _sized(TEXT_SIZE)
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
