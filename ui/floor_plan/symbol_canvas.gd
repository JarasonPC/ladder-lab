class_name SymbolCanvas
extends Control
## Where a symbol of the user's own ([CustomSymbol]) is drawn, on schematic
## paper with a grid of centimetres: its origin where the axes cross (for a
## symbol on a wall the wall above it, the room below). Wheel zooms at the
## mouse, right or middle drag pans.
##
## By [member tool]: SELECT picks shapes (a click one, Shift or Ctrl+click
## more, a box dragged from an empty place all it touches; dragged, they
## move; the points of one picked alone drag by their handles, the corners
## of the box round them scale them, the round handle over it turns them
## about their middle, by whole degrees, by 15° with Shift); LINE, RECT and ELLIPSE are dragged
## from corner to corner; POLYLINE and POLYGON take a point a click and end
## with a double click, Enter or a right click (a polygon also a click on
## its first point); ARC and CURVE are dragged from one end to the other,
## then a click sets the point the arc goes through or the curve bends
## towards; TEXT puts [member text] where it is clicked. Editing the points
## of a polygon or polyline ([member editing_points]: a double click on it,
## Esc or a click elsewhere ends it), a point is dragged, a click on an
## edge or a drag of the mark in its middle puts a point in, Delete or
## Ctrl+click takes the point clicked last out (a picture is
## added by [method add_shape] with [method CustomSymbol.image_shape],
## then moved and scaled as any shape). Esc drops what is
## being drawn. New shapes take the look of [member look]. Points snap to
## the points of the other shapes near them, else to [member grid] (0: not
## at all). Keys: Delete, Ctrl+A / C / X / V / D (select all, copy, cut,
## paste, duplicate), R / Shift+R turn a quarter clockwise / back (Ctrl+R
## asks for any angle: [signal rotate_requested]), F /
## Shift+F mirror left to right / top to bottom, Ctrl+Z / Ctrl+Y undo and
## redo.

## The shapes changed.
signal changed
## [member selection] changed.
signal selection_changed
## The angle the shapes picked turn by should be asked (Ctrl+R).
signal rotate_requested
## Editing the points of the shape picked began or ended.
signal points_mode_changed(on: bool)

enum Tool { SELECT, LINE, POLYLINE, POLYGON, RECT, ELLIPSE, ARC, CURVE, TEXT }

## Pixels a metre at zoom 1.
const PX: float = 600.0
const MIN_ZOOM: float = 0.2
const MAX_ZOOM: float = 8.0
const ZOOM_STEP: float = 1.15
## Grid steps offered (m), the first the one at the start; 0 snaps to none.
const GRIDS: PackedFloat32Array = [0.005, 0.001, 0.01, 0.0]
## Angle steps offered for lines drawn from a point (degrees; 0: any), and
## the one Shift snaps to while none is set.
const ANGLES: PackedFloat32Array = [0.0, 15.0, 45.0, 90.0]
const SHIFT_ANGLES: float = 15.0
## A shape this close to the mouse (pixels) is under it; a handle this
## close; a point of another shape this close is snapped to.
const GRAB: float = 6.0
const HANDLE: float = 4.5
## The handle that turns the shapes picked is this far over the box round
## them (pixels); held with Shift it turns them by this many degrees a step.
const ROTATE_REACH: float = 24.0
const ROTATE_STEP: float = 15.0
const POINT_SNAP: float = 8.0
## Pasted and duplicated shapes are put this far off the originals (m).
const PASTE_OFFSET: Vector2 = Vector2(0.01, 0.01)
## The most undo steps kept.
const MAX_UNDO: int = 100

## Shapes copied or cut, for any symbol edited in this run of the program.
static var clipboard: Array[CustomSymbol.Shape] = []

var symbol: CustomSymbol = CustomSymbol.new()
var tool: Tool = Tool.SELECT:
	set(value):
		tool = value
		if value != Tool.SELECT:
			editing_points = false
		_pending = PackedVector2Array()
		_path = PackedVector2Array()
		mouse_default_cursor_shape = Control.CURSOR_CROSS if value != Tool.SELECT else Control.CURSOR_ARROW
		queue_redraw()
## The look of new shapes: width, style, colours, fill; a text's height,
## angle, bold and italic.
var look: CustomSymbol.Shape = CustomSymbol.Shape.new()
## What TEXT puts.
var text: String = "TV"
## Points snap to this (m); 0 to none.
var grid: float = GRIDS[0]
## Lines drawn from a point snap to angles of this step (degrees; 0: any,
## but [constant SHIFT_ANGLES] with Shift held).
var angles: float = 0.0
## The shapes picked, in the order of [member CustomSymbol.shapes].
var selection: PackedInt32Array = PackedInt32Array():
	set(value):
		var sorted: PackedInt32Array = value.duplicate()
		sorted.sort()
		var was: PackedInt32Array = selection
		selection = sorted
		if was != sorted:
			# Another pick ends editing the points of the one before.
			editing_points = false
			selection_changed.emit()
		queue_redraw()
## The one shape picked, -1 for none or several; set, it is picked alone.
var selected: int:
	get:
		return selection[0] if selection.size() == 1 else -1
	set(value):
		selection = PackedInt32Array([value]) if value >= 0 else PackedInt32Array()
## The points of the polygon or polyline picked alone are being edited
## (see [method can_edit_points]); set true for another shape, it stays false.
var editing_points: bool = false:
	set(value):
		var on: bool = value and can_edit_points()
		var was: bool = editing_points
		editing_points = on
		if not on:
			_active_point = -1
		if was != on:
			points_mode_changed.emit(on)
		queue_redraw()
var zoom: float = 1.0
## Screen position of the origin.
var offset: Vector2 = Vector2.ZERO

var _press: Dictionary = {}
var _press_at: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _mouse: Vector2 = Vector2.ZERO
var _pan_button: MouseButton = MOUSE_BUTTON_NONE
## Shift was held at the last move or click of the mouse.
var _shift: bool = false
## The point found by [method _point_near] last was the middle of an edge.
var _near_middle: bool = false
## An arc's or curve's two ends while its middle point is chosen.
var _pending: PackedVector2Array = PackedVector2Array()
## The points of a polyline or polygon being drawn.
var _path: PackedVector2Array = PackedVector2Array()
## While editing points: the point clicked last (Delete takes it out), -1 for none.
var _active_point: int = -1
## Pastes since the last copy (each further off).
var _pastes: int = 0
var _undo: Array[Array] = []
var _redo: Array[Array] = []


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	resized.connect(func() -> void:
		if offset == Vector2.ZERO:
			fit())


## Edits [param def] (its shapes are changed in place); undo starts afresh.
func edit(def: CustomSymbol) -> void:
	symbol = def
	selection = PackedInt32Array()
	_undo.clear()
	_redo.clear()
	_pending = PackedVector2Array()
	_path = PackedVector2Array()
	offset = Vector2.ZERO
	fit()


func to_symbol(point: Vector2) -> Vector2:
	return (point - offset) / (PX * zoom)


func to_screen(point: Vector2) -> Vector2:
	return offset + point * PX * zoom


## [param point] (m) on the grid, within reach of the origin.
func snap(point: Vector2) -> Vector2:
	var on: Vector2 = point.snapped(Vector2(grid, grid)) if grid > 0.0 else point
	return on.clamp(-Vector2.ONE * CustomSymbol.REACH, Vector2.ONE * CustomSymbol.REACH)


## Screen point [param point] as a point of the symbol: on a point or the
## middle of an edge of a shape near it (not of [param skip]); else, drawn
## from [param anchor] (m; NAN for none) with angles snapping
## ([method angle_step]), on the nearest line from it at such an angle, as
## far as the grid takes it; else on the grid.
func snap_point(point: Vector2, skip: PackedInt32Array = PackedInt32Array(), anchor: Vector2 = Vector2(NAN, NAN)) -> Vector2:
	var found: Vector2 = _point_near(point, skip)
	if not is_nan(found.x):
		return found
	var step: float = angle_step()
	if step > 0.0 and not is_nan(anchor.x):
		var d: Vector2 = to_symbol(point) - anchor
		if d.length() > 0.0001:
			var angle: float = snappedf(d.angle(), deg_to_rad(step))
			var length: float = d.dot(Vector2.from_angle(angle))
			if grid > 0.0:
				length = snappedf(length, grid)
			return (anchor + Vector2.from_angle(angle) * length).clamp(-Vector2.ONE * CustomSymbol.REACH, Vector2.ONE * CustomSymbol.REACH)
	return snap(to_symbol(point))


## The angles lines drawn from a point snap to (degrees): [member angles],
## or [constant SHIFT_ANGLES] while Shift is held with none set; 0 for any.
func angle_step() -> float:
	return angles if angles > 0.0 else (SHIFT_ANGLES if _shift else 0.0)


## The point of a shape (not of [param skip]) within [constant POINT_SNAP]
## of screen point [param point] (m), NAN for none: the points of each
## shape (see [method key_points]) or the middles of its edges (see
## [method middle_points]), the points of the polyline being drawn.
## [member _near_middle] says which it was.
func _point_near(point: Vector2, skip: PackedInt32Array = PackedInt32Array()) -> Vector2:
	var best: float = POINT_SNAP
	var found: Vector2 = Vector2(NAN, NAN)
	_near_middle = false
	for i: int in symbol.shapes.size():
		if skip.has(i):
			continue
		for middle: bool in [false, true]:
			for p: Vector2 in (middle_points(symbol.shapes[i]) if middle else key_points(symbol.shapes[i])):
				var d: float = to_screen(p).distance_to(point)
				if d < best:
					best = d
					found = p
					_near_middle = middle
	for k: int in _path.size():
		for middle: bool in [false, true]:
			if middle and k == 0:
				continue
			var p: Vector2 = (_path[k - 1] + _path[k]) * 0.5 if middle else _path[k]
			if to_screen(p).distance_to(point) < best:
				best = to_screen(p).distance_to(point)
				found = p
				_near_middle = middle
	return found


## The points of [param shape] others snap to (m).
static func key_points(shape: CustomSymbol.Shape) -> PackedVector2Array:
	var p: PackedVector2Array = shape.points
	match shape.kind:
		"rect", "image":
			# Its corners as drawn, turned with it, and its middle.
			var round: PackedVector2Array = CustomSymbol.outline_of(shape).slice(0, 4)
			round.append(CustomSymbol.box_middle(shape))
			return round
		"ellipse":
			return PackedVector2Array([CustomSymbol.box_middle(shape)])
	return p.duplicate()


## The middles others snap to (m): of each straight edge of [param shape]
## (a polygon's back to its first point, a rectangle's or picture's sides
## as drawn), the middle along an arc or a curve.
static func middle_points(shape: CustomSymbol.Shape) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	match shape.kind:
		"line", "polyline", "polygon", "rect", "image":
			var round: PackedVector2Array = CustomSymbol.outline_of(shape) if shape.kind in ["polygon", "rect", "image"] else shape.points
			for k: int in round.size() - 1:
				result.append((round[k] + round[k + 1]) * 0.5)
		"arc", "curve":
			var along: PackedVector2Array = CustomSymbol.outline_of(shape)
			result.append(along[along.size() / 2] if along.size() % 2 == 1 else (along[along.size() / 2 - 1] + along[along.size() / 2]) * 0.5)
	return result


## Where what is being drawn or dragged is drawn from, for angles to snap
## (m): the first point of a line, box, arc or curve dragged, the last
## point of a polyline or polygon, the point before a point dragged or put
## in; NAN for none.
func _anchor() -> Vector2:
	if not _path.is_empty():
		return _path[_path.size() - 1]
	var kind: String = _press.get("kind", "")
	if kind == "new" and _dragging and tool in [Tool.LINE, Tool.RECT, Tool.ELLIPSE, Tool.ARC, Tool.CURVE]:
		return snap_point(_press_at)
	if kind == "handle":
		return _handle_anchor(int(_press["which"]))
	if kind == "insert" and selected >= 0:
		return symbol.shapes[selected].points[int(_press["which"])]
	return Vector2(NAN, NAN)


## The point a point [param k] of the shape picked is dragged from, for
## angles to snap: the one before it (a polygon's last for its first, the
## second for the first of others, a box's other corner); NAN for a text or
## a picture.
func _handle_anchor(k: int) -> Vector2:
	if selected < 0:
		return Vector2(NAN, NAN)
	var shape: CustomSymbol.Shape = symbol.shapes[selected]
	var points: PackedVector2Array = CustomSymbol.handle_points(shape)
	if points.size() < 2 or shape.kind in ["text", "image"]:
		return Vector2(NAN, NAN)
	if shape.kind == "polygon":
		return points[(k - 1 + points.size()) % points.size()]
	return points[k - 1] if k > 0 else points[1]


## Shows the symbol (at least half a metre round the origin) as large as fits.
func fit() -> void:
	if size.x < 10.0:
		return
	var area: Rect2 = symbol.bounds().merge(Rect2(-0.25, -0.25, 0.5, 0.5)).grow(0.05)
	zoom = clampf(minf(size.x / (area.size.x * PX), size.y / (area.size.y * PX)), MIN_ZOOM, MAX_ZOOM)
	offset = size * 0.5 - area.get_center() * PX * zoom
	queue_redraw()


# --- Changes (each one undo step) -------------------------------------------------

## Keeps the shapes as they are for an undo, before they change.
func _record() -> void:
	_undo.append(_shapes_copy())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()


func _shapes_copy() -> Array[CustomSymbol.Shape]:
	var list: Array[CustomSymbol.Shape] = []
	for shape: CustomSymbol.Shape in symbol.shapes:
		list.append(shape.copy())
	return list


func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(_shapes_copy())
	symbol.shapes.assign(_undo.pop_back())
	selection = PackedInt32Array()
	changed.emit()


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_shapes_copy())
	symbol.shapes.assign(_redo.pop_back())
	selection = PackedInt32Array()
	changed.emit()


## Adds [param list] (one undo step) and picks them.
func add_shapes(list: Array[CustomSymbol.Shape]) -> void:
	var room: int = CustomSymbol.MAX_SHAPES - symbol.shapes.size()
	if list.is_empty() or room <= 0:
		return
	_record()
	var picked: PackedInt32Array = PackedInt32Array()
	for shape: CustomSymbol.Shape in list.slice(0, room):
		symbol.shapes.append(shape)
		picked.append(symbol.shapes.size() - 1)
	selection = picked
	changed.emit()


## Adds [param shape] (one undo step) and picks it.
func add_shape(shape: CustomSymbol.Shape) -> void:
	add_shapes([shape])


## Changes every shape picked with [param change] (called with each), one
## undo step.
func change_selected(change: Callable) -> void:
	var picked: Array[CustomSymbol.Shape] = selected_shapes()
	if picked.is_empty():
		return
	_record()
	for shape: CustomSymbol.Shape in picked:
		change.call(shape)
	changed.emit()
	queue_redraw()


func selected_shapes() -> Array[CustomSymbol.Shape]:
	var list: Array[CustomSymbol.Shape] = []
	for i: int in selection:
		if i >= 0 and i < symbol.shapes.size():
			list.append(symbol.shapes[i])
	return list


func delete_selected() -> void:
	if selected_shapes().is_empty():
		return
	_record()
	for k: int in range(selection.size() - 1, -1, -1):
		if selection[k] < symbol.shapes.size():
			symbol.shapes.remove_at(selection[k])
	selection = PackedInt32Array()
	changed.emit()


func select_all() -> void:
	selection = PackedInt32Array(range(symbol.shapes.size()))


## What the shapes picked cover (m).
func selection_bounds() -> Rect2:
	return CustomSymbol.bounds_of(selected_shapes())


## The middle the shapes picked turn and mirror about: the middle of the box
## round them, on the grid.
func _selection_middle() -> Vector2:
	return snap(selection_bounds().get_center())


## Turns the shapes picked a quarter round their middle.
func turn_selected(clockwise: bool) -> void:
	var about: Vector2 = _selection_middle()
	change_selected(func(shape: CustomSymbol.Shape) -> void: CustomSymbol.turn_shape(shape, about, clockwise))


## Turns the shapes picked by [param degrees] (anticlockwise) round their middle.
func rotate_selected(degrees: float) -> void:
	if is_zero_approx(fposmod(degrees, 360.0)):
		return
	var about: Vector2 = _selection_middle()
	change_selected(func(shape: CustomSymbol.Shape) -> void: CustomSymbol.rotate_shape(shape, about, degrees))


## Mirrors the shapes picked about their middle, left to right when
## [param across], else top to bottom.
func mirror_selected(across: bool) -> void:
	var about: Vector2 = _selection_middle()
	change_selected(func(shape: CustomSymbol.Shape) -> void: CustomSymbol.mirror_shape(shape, about, across))


## Makes the shapes picked [param factor] times as large about
## [param about] (their middle when NAN).
func scale_selected(factor: float, about: Vector2 = Vector2(NAN, NAN)) -> void:
	var fixed: Vector2 = _selection_middle() if is_nan(about.x) else about
	change_selected(func(shape: CustomSymbol.Shape) -> void: CustomSymbol.scale_shape(shape, fixed, factor))


func copy_selected() -> void:
	var picked: Array[CustomSymbol.Shape] = selected_shapes()
	if picked.is_empty():
		return
	clipboard.clear()
	for shape: CustomSymbol.Shape in picked:
		clipboard.append(shape.copy())
	_pastes = 0


func cut_selected() -> void:
	copy_selected()
	delete_selected()


## Adds the shapes copied, a little off where they were, and picks them.
func paste() -> void:
	if clipboard.is_empty():
		return
	_pastes += 1
	add_shapes(_moved_copies(clipboard, PASTE_OFFSET * _pastes))


## Adds a copy of the shapes picked a little off them, and picks it.
func duplicate_selected() -> void:
	add_shapes(_moved_copies(selected_shapes(), PASTE_OFFSET))


static func _moved_copies(list: Array[CustomSymbol.Shape], by: Vector2) -> Array[CustomSymbol.Shape]:
	var copies: Array[CustomSymbol.Shape] = []
	for shape: CustomSymbol.Shape in list:
		var twin: CustomSymbol.Shape = shape.copy()
		CustomSymbol.move_shape(twin, by)
		copies.append(twin)
	return copies


# --- Finding things ---------------------------------------------------------------

## The point of the one shape picked under screen point [param point]: its
## index, -1 for none.
func handle_at(point: Vector2) -> int:
	if selected < 0:
		return -1
	var points: PackedVector2Array = CustomSymbol.handle_points(symbol.shapes[selected])
	for k: int in points.size():
		if to_screen(points[k]).distance_to(point) <= HANDLE + 3.0:
			return k
	return -1


## The corners of the box round the shapes picked (m), top left first,
## clockwise; none when it has no size.
func corners() -> PackedVector2Array:
	var box: Rect2 = selection_bounds()
	if selection.is_empty() or (box.size.x < 0.001 and box.size.y < 0.001):
		return PackedVector2Array()
	return PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])


## The corner of the box round the shapes picked under screen point
## [param point]: 0 top left, clockwise; -1 for none.
func corner_at(point: Vector2) -> int:
	var list: PackedVector2Array = corners()
	for k: int in list.size():
		if to_screen(list[k]).distance_to(point) <= HANDLE + 3.0:
			return k
	return -1


## Where the handle that turns the shapes picked is on screen: over the
## middle of the top of the box round them; NAN when nothing is picked.
func rotation_handle() -> Vector2:
	if corners().is_empty():
		return Vector2(NAN, NAN)
	var box: Rect2 = selection_bounds()
	return to_screen(Vector2(box.get_center().x, box.position.y)) - Vector2(0, ROTATE_REACH)


func rotation_at(point: Vector2) -> bool:
	var at: Vector2 = rotation_handle()
	return not is_nan(at.x) and at.distance_to(point) <= HANDLE + 4.0


## How far the turning handle dragged to screen point [param point] turns
## the shapes picked (degrees, anticlockwise) round their middle: whole
## degrees, steps of [constant ROTATE_STEP] with Shift.
func _rotation_degrees(point: Vector2) -> float:
	var about: Vector2 = to_screen(_selection_middle())
	var from: Vector2 = _press_at - about
	var to: Vector2 = point - about
	if from.length() < 1.0 or to.length() < 1.0:
		return 0.0
	var degrees: float = -rad_to_deg(from.angle_to(to))
	return wrapf(snappedf(degrees, ROTATE_STEP if _shift else 1.0), -180.0, 180.0)


func shape_at(point: Vector2) -> int:
	return symbol.shape_at(to_symbol(point), GRAB / (PX * zoom))


# --- Editing points ---------------------------------------------------------------

## Whether the shape picked alone takes points in and out: a polygon or a polyline.
func can_edit_points() -> bool:
	return selected >= 0 and symbol.shapes[selected].kind in ["polygon", "polyline"]


## The edges of the shape whose points are edited: [from, to] (m) each, a
## polygon's last back to its first.
func _edges() -> Array[PackedVector2Array]:
	var list: Array[PackedVector2Array] = []
	if not editing_points:
		return list
	var shape: CustomSymbol.Shape = symbol.shapes[selected]
	var n: int = shape.points.size()
	for k: int in (n if shape.kind == "polygon" else n - 1):
		list.append(PackedVector2Array([shape.points[k], shape.points[(k + 1) % n]]))
	return list


## The edge whose middle mark is under screen point [param point], -1 for none.
func midpoint_at(point: Vector2) -> int:
	var edges: Array[PackedVector2Array] = _edges()
	for k: int in edges.size():
		if to_screen((edges[k][0] + edges[k][1]) * 0.5).distance_to(point) <= HANDLE + 3.0:
			return k
	return -1


## The edge under screen point [param point], -1 for none.
func edge_at(point: Vector2) -> int:
	var edges: Array[PackedVector2Array] = _edges()
	for k: int in edges.size():
		var near: Vector2 = Geometry2D.get_closest_point_to_segment(point, to_screen(edges[k][0]), to_screen(edges[k][1]))
		if near.distance_to(point) <= GRAB:
			return k
	return -1


## Puts a point at [param at] (m) into the shape picked after its point
## [param after] (on edge [param after]); one undo step, the new point the
## one clicked last.
func insert_point(after: int, at: Vector2) -> void:
	if selected < 0 or symbol.shapes[selected].points.size() >= CustomSymbol.MAX_POINTS:
		return
	change_selected(func(shape: CustomSymbol.Shape) -> void: shape.points.insert(after + 1, at))
	_active_point = after + 1


## Takes point [param k] out of the shape picked, unless it would have too
## few (a polygon three, a polyline two); one undo step. Returns whether it
## was taken out.
func delete_point(k: int) -> bool:
	if selected < 0:
		return false
	var shape: CustomSymbol.Shape = symbol.shapes[selected]
	if k < 0 or k >= shape.points.size() or shape.points.size() <= CustomSymbol.MIN_POINTS.get(shape.kind, shape.points.size()):
		return false
	change_selected(func(edited: CustomSymbol.Shape) -> void: edited.points.remove_at(k))
	_active_point = -1
	return true


## What a press at [param point] takes hold of while points are edited: a
## point (with [param adding]: taken out), an edge's middle mark or an edge
## (a point put in), the shape (moved); {} elsewhere (the editing ends).
func _pressed_points(point: Vector2, adding: bool) -> Dictionary:
	var handle: int = handle_at(point)
	if handle >= 0:
		if adding:
			delete_point(handle)
			return {"kind": "none"}
		_active_point = handle
		queue_redraw()
		return {"kind": "handle", "which": handle}
	var middle: int = midpoint_at(point)
	if middle >= 0:
		var edge: PackedVector2Array = _edges()[middle]
		return {"kind": "insert", "which": middle, "at": (edge[0] + edge[1]) * 0.5}
	var on_edge: int = edge_at(point)
	if on_edge >= 0:
		var edge: PackedVector2Array = _edges()[on_edge]
		return {"kind": "insert", "which": on_edge, "at": Geometry2D.get_closest_point_to_segment(to_symbol(point), edge[0], edge[1])}
	if shape_at(point) == selected:
		return {"kind": "shape"}
	return {}


## The shapes whose box meets [param box] (m).
func shapes_in(box: Rect2) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array()
	for i: int in symbol.shapes.size():
		if CustomSymbol.shape_bounds(symbol.shapes[i]).grow(0.0001).intersects(box):
			found.append(i)
	return found


# --- Input ------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed:
		if _key(key):
			accept_event()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		_on_button(mb)
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_mouse = motion.position
		_shift = motion.shift_pressed
		if tool == Tool.SELECT and _press.is_empty():
			var over_handle: bool = handle_at(motion.position) >= 0 or corner_at(motion.position) >= 0
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if rotation_at(motion.position) else (Control.CURSOR_DRAG if over_handle else Control.CURSOR_ARROW)
		if _pan_button != MOUSE_BUTTON_NONE:
			offset += motion.relative
		elif not _press.is_empty() and not _dragging and motion.position.distance_to(_press_at) >= SchematicEditor.CLICK_SLOP:
			_dragging = true
		queue_redraw()
		accept_event()


## A key pressed; returns whether it was taken.
func _key(key: InputEventKey) -> bool:
	var command: bool = key.is_command_or_control_pressed()
	match key.keycode:
		KEY_Z when command:
			if key.shift_pressed:
				redo()
			else:
				undo()
		KEY_Y when command:
			redo()
		KEY_A when command:
			select_all()
		KEY_C when command:
			copy_selected()
		KEY_X when command:
			cut_selected()
		KEY_V when command:
			paste()
		KEY_D when command:
			duplicate_selected()
		KEY_R when command:
			if not selection.is_empty():
				rotate_requested.emit()
		KEY_R:
			turn_selected(not key.shift_pressed)
		KEY_F when not command:
			mirror_selected(not key.shift_pressed)
		KEY_DELETE, KEY_BACKSPACE:
			if editing_points:
				delete_point(_active_point)
			else:
				delete_selected()
		KEY_ENTER, KEY_KP_ENTER:
			if _path.is_empty():
				return false
			finish_path()
		KEY_ESCAPE:
			if editing_points and _pending.is_empty() and _path.is_empty():
				editing_points = false
				return true
			if _pending.is_empty() and _path.is_empty():
				return false
			_pending = PackedVector2Array()
			_path = PackedVector2Array()
			queue_redraw()
		_:
			return false
	return true


func _on_button(mb: InputEventMouseButton) -> void:
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var at: Vector2 = to_symbol(mb.position)
				zoom = clampf(zoom * (ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP), MIN_ZOOM, MAX_ZOOM)
				offset = mb.position - at * PX * zoom
				queue_redraw()
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				if mb.button_index == MOUSE_BUTTON_RIGHT and not _path.is_empty():
					finish_path()
					return
				if mb.button_index == MOUSE_BUTTON_RIGHT and not _pending.is_empty():
					_pending = PackedVector2Array()
					queue_redraw()
					return
				_pan_button = mb.button_index
			elif mb.button_index == _pan_button:
				_pan_button = MOUSE_BUTTON_NONE
		MOUSE_BUTTON_LEFT:
			grab_focus()
			if mb.pressed and mb.double_click and not _path.is_empty():
				# The click before put the last point.
				finish_path()
				_press = {}
				return
			if mb.pressed and mb.double_click and tool == Tool.SELECT:
				# A double click on a polygon or polyline edits its points.
				var hit: int = shape_at(mb.position)
				if hit >= 0 and symbol.shapes[hit].kind in ["polygon", "polyline"]:
					selected = hit
					editing_points = true
					_press = {}
					return
			if mb.pressed:
				_press_at = mb.position
				_mouse = mb.position
				_dragging = false
				_press = _pressed(mb.position, mb.shift_pressed or mb.is_command_or_control_pressed())
				queue_redraw()
			elif not _press.is_empty():
				var press: Dictionary = _press
				_press = {}
				_shift = mb.shift_pressed
				_release(press, mb.position)
				_dragging = false
				queue_redraw()


## What a press at [param point] takes hold of; [param adding]: Shift or
## Ctrl held (the shape clicked is picked or let go besides the others).
func _pressed(point: Vector2, adding: bool = false) -> Dictionary:
	if not _pending.is_empty():
		return {"kind": "middle"}
	if tool != Tool.SELECT:
		return {"kind": "new"}
	if editing_points:
		var on_points: Dictionary = _pressed_points(point, adding)
		if not on_points.is_empty():
			return on_points
		editing_points = false
	var handle: int = handle_at(point)
	if handle >= 0:
		return {"kind": "handle", "which": handle}
	if rotation_at(point):
		return {"kind": "rotate"}
	var corner: int = corner_at(point)
	if corner >= 0:
		return {"kind": "corner", "which": corner}
	var shape: int = shape_at(point)
	if shape < 0:
		return {"kind": "box", "adding": adding}
	if adding:
		var picked: PackedInt32Array = selection.duplicate()
		if picked.has(shape):
			picked.remove_at(picked.find(shape))
		else:
			picked.append(shape)
		selection = picked
		return {"kind": "none"}
	if not selection.has(shape):
		selected = shape
	return {"kind": "shape", "index": shape}


func _release(press: Dictionary, point: Vector2) -> void:
	var a: Vector2 = snap_point(_press_at)
	# A line, box, arc or curve is drawn from where it was pressed, a
	# polyline's next point from its last: angles snap from there.
	var anchor: Vector2 = Vector2(NAN, NAN)
	if press["kind"] == "new" and tool in [Tool.POLYLINE, Tool.POLYGON] and not _path.is_empty():
		anchor = _path[_path.size() - 1]
	elif press["kind"] == "new" and tool in [Tool.LINE, Tool.RECT, Tool.ELLIPSE, Tool.ARC, Tool.CURVE]:
		anchor = a
	var b: Vector2 = snap_point(point, PackedInt32Array(), anchor)
	match press["kind"]:
		"middle":
			var ends: PackedVector2Array = _pending
			_pending = PackedVector2Array()
			add_shape(_new_shape("arc" if tool == Tool.ARC else "curve", [ends[0], b, ends[1]]))
		"new":
			match tool:
				Tool.TEXT:
					if not text.strip_edges().is_empty():
						var shape: CustomSymbol.Shape = _new_shape("text", [b])
						shape.text = text.strip_edges().left(CustomSymbol.MAX_TEXT_LENGTH)
						shape.angle = look.angle
						add_shape(shape)
				Tool.LINE, Tool.RECT, Tool.ELLIPSE:
					if a.distance_to(b) >= 0.001:
						add_shape(_new_shape({Tool.LINE: "line", Tool.RECT: "rect", Tool.ELLIPSE: "ellipse"}[tool], [a, b]))
				Tool.ARC, Tool.CURVE:
					if a.distance_to(b) >= 0.001:
						_pending = PackedVector2Array([a, b])
				Tool.POLYLINE, Tool.POLYGON:
					if tool == Tool.POLYGON and _path.size() >= 3 and to_screen(_path[0]).distance_to(point) <= POINT_SNAP:
						# Back on its first point: closed.
						finish_path()
					elif _path.is_empty() or _path[_path.size() - 1].distance_to(b) >= 0.0005:
						_path.append(b)
						if _path.size() >= CustomSymbol.MAX_POINTS:
							finish_path()
		"handle":
			if _dragging:
				var which: int = press["which"]
				var to: Vector2 = snap_point(point, selection, _handle_anchor(which))
				change_selected(func(shape: CustomSymbol.Shape) -> void: CustomSymbol.set_handle(shape, which, to))
		"corner":
			if _dragging:
				var scaled: Array = _corner_scale(press["which"], point)
				scale_selected(scaled[0], scaled[1])
		"insert":
			var after: Vector2 = symbol.shapes[selected].points[int(press["which"])] if selected >= 0 else Vector2(NAN, NAN)
			insert_point(press["which"], snap_point(point, selection, after) if _dragging else press["at"])
		"rotate":
			if _dragging:
				rotate_selected(_rotation_degrees(point))
		"shape":
			if _dragging:
				var by: Vector2 = _drag_by(point)
				if by != Vector2.ZERO:
					change_selected(func(shape: CustomSymbol.Shape) -> void: CustomSymbol.move_shape(shape, by))
			elif press.has("index"):
				# A click on one of several picked picks it alone.
				selected = press["index"]
		"box":
			var found: PackedInt32Array = shapes_in(_box(point)) if _dragging else PackedInt32Array()
			if press.get("adding", false):
				for i: int in selection:
					if not found.has(i):
						found.append(i)
			selection = found


## Ends the polyline or polygon being drawn (one too short is dropped).
func finish_path() -> void:
	var points: PackedVector2Array = _path
	_path = PackedVector2Array()
	var kind: String = "polygon" if tool == Tool.POLYGON else "polyline"
	if points.size() >= CustomSymbol.MIN_POINTS[kind]:
		add_shape(_new_shape(kind, Array(points)))
	queue_redraw()


## How far the shapes picked are dragged (m): on the grid, or so the point
## grabbed lands on a point of another shape.
func _drag_by(point: Vector2) -> Vector2:
	var grabbed: Vector2 = to_symbol(_press_at)
	var best: float = INF
	for shape: CustomSymbol.Shape in selected_shapes():
		for p: Vector2 in key_points(shape):
			if p.distance_to(grabbed) < best:
				best = p.distance_to(grabbed)
				grabbed = p
	var target: Vector2 = _point_near(point - _press_at + to_screen(grabbed), selection)
	if not is_nan(target.x):
		return target - grabbed
	return snap(to_symbol(point)) - snap(to_symbol(_press_at))


## Corner [param which] of the box round the shapes picked dragged to
## screen point [param point]: [the factor, the opposite corner (m)].
func _corner_scale(which: int, point: Vector2) -> Array:
	var list: PackedVector2Array = corners()
	var fixed: Vector2 = list[(which + 2) % 4]
	var diagonal: Vector2 = list[which] - fixed
	var factor: float = (snap(to_symbol(point)) - fixed).dot(diagonal) / maxf(diagonal.length_squared(), 1e-9)
	return [maxf(factor, 0.05), fixed]


## The box dragged from where the mouse was pressed to [param point] (m).
func _box(point: Vector2) -> Rect2:
	var a: Vector2 = to_symbol(_press_at)
	var b: Vector2 = to_symbol(point)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


## A new shape of [param kind] through [param points] with the look of
## [member look].
func _new_shape(kind: String, points: Array) -> CustomSymbol.Shape:
	var shape: CustomSymbol.Shape = CustomSymbol.Shape.new()
	shape.kind = kind
	shape.points = PackedVector2Array(points)
	shape.take_style(look)
	return shape


## Shape [param index] as it is shown: moved, scaled or its point dragged.
func _shown(index: int) -> CustomSymbol.Shape:
	var shape: CustomSymbol.Shape = symbol.shapes[index]
	if not _dragging or not selection.has(index) or not (_press.get("kind", "") in ["handle", "shape", "corner", "rotate", "insert"]):
		return shape
	var moved: CustomSymbol.Shape = shape.copy()
	match _press["kind"]:
		"handle":
			CustomSymbol.set_handle(moved, int(_press["which"]), snap_point(_mouse, selection, _anchor()))
		"corner":
			var scaled: Array = _corner_scale(_press["which"], _mouse)
			CustomSymbol.scale_shape(moved, scaled[1], scaled[0])
		"rotate":
			CustomSymbol.rotate_shape(moved, _selection_middle(), _rotation_degrees(_mouse))
		"insert":
			moved.points.insert(int(_press["which"]) + 1, snap_point(_mouse, selection, _anchor()))
		_:
			CustomSymbol.move_shape(moved, _drag_by(_mouse))
	return moved


# --- Drawing ----------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SchematicTheme.BACKGROUND)
	var s: float = PX * zoom
	var font: Font = get_theme_default_font()
	# The grid: every centimetre faint (when far enough apart), every 5 cm
	# and 10 cm stronger; millimetres too on the finest grid zoomed in.
	var from: Vector2 = to_symbol(Vector2.ZERO)
	var to: Vector2 = to_symbol(size)
	for step: Array in [[0.001, 0.03], [0.01, 0.05], [0.05, 0.1], [0.1, 0.18]]:
		var d: float = step[0]
		if d * s < 6.0 or (d < 0.005 and grid != 0.001):
			continue
		var color: Color = Color(SchematicTheme.LINE, step[1])
		for i: int in range(floori(from.x / d), ceili(to.x / d) + 1):
			draw_line(Vector2(to_screen(Vector2(i * d, 0)).x, 0), Vector2(to_screen(Vector2(i * d, 0)).x, size.y), color, 1.0)
		for i: int in range(floori(from.y / d), ceili(to.y / d) + 1):
			draw_line(Vector2(0, to_screen(Vector2(0, i * d)).y), Vector2(size.x, to_screen(Vector2(0, i * d)).y), color, 1.0)
	var origin: Vector2 = to_screen(Vector2.ZERO)
	if symbol.wall:
		# The wall it hangs from, the room below.
		draw_rect(Rect2(Vector2(0, origin.y - FloorPlanCanvas.WALL * s), Vector2(size.x, FloorPlanCanvas.WALL * s)), Color(FloorPlanCanvas.wall_color(), 0.6))
	draw_line(Vector2(origin.x, 0), Vector2(origin.x, size.y), Color(SchematicTheme.SELECTED, 0.35), 1.0)
	draw_line(Vector2(0, origin.y), Vector2(size.x, origin.y), Color(SchematicTheme.SELECTED, 0.35), 1.0)
	var width: float = 2.0
	for i: int in symbol.shapes.size():
		CustomSymbol.draw_shape(self, _shown(i), origin, s, SchematicTheme.LINE, width, font)
	_draw_selection(origin, s)
	# What is being drawn.
	var anchor: Vector2 = _anchor()
	var m: Vector2 = snap_point(_mouse, PackedInt32Array(), anchor)
	var ghost: Color = Color(SchematicTheme.SELECTED, 0.7)
	if not _pending.is_empty():
		CustomSymbol.draw_shape(self, _new_shape("arc" if tool == Tool.ARC else "curve", [_pending[0], m, _pending[1]]), origin, s, ghost, width, font, true)
	elif not _path.is_empty():
		var points: Array = Array(_path) + [m]
		CustomSymbol.draw_shape(self, _new_shape("polygon" if tool == Tool.POLYGON and points.size() >= 3 else "polyline", points), origin, s, ghost, width, font, true)
	elif _dragging and _press.get("kind", "") == "new" and tool in [Tool.LINE, Tool.RECT, Tool.ELLIPSE, Tool.ARC, Tool.CURVE]:
		var a: Vector2 = snap_point(_press_at)
		var kind: String = {Tool.RECT: "rect", Tool.ELLIPSE: "ellipse"}.get(tool, "line")
		CustomSymbol.draw_shape(self, _new_shape(kind, [a, m]), origin, s, ghost, width, font, true)
	elif _dragging and _press.get("kind", "") == "box":
		var box: Rect2 = _box(_mouse)
		draw_rect(Rect2(to_screen(box.position), box.size * s), Color(SchematicTheme.SELECTED, 0.08))
		draw_rect(Rect2(to_screen(box.position), box.size * s), SchematicTheme.SELECTED, false, 1.0)
	var dragging_point: bool = _dragging and _press.get("kind", "") in ["handle", "insert"]
	if (tool != Tool.SELECT or dragging_point) and Rect2(Vector2.ZERO, size).has_point(_mouse):
		var c: Vector2 = to_screen(m) if not dragging_point else to_screen(snap_point(_mouse, selection, anchor))
		var at: Vector2 = to_symbol(c)
		if not is_nan(_point_near(_mouse, selection if dragging_point else PackedInt32Array()).x):
			if _near_middle:
				# Caught on the middle of an edge: a triangle.
				draw_polyline(PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 4), c + Vector2(-6, 4), c + Vector2(0, -7)]), SchematicTheme.SELECTED, 1.5, true)
			else:
				# Caught on a point of a shape: a diamond.
				draw_polyline(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0), c + Vector2(0, -6)]), SchematicTheme.SELECTED, 1.5, true)
		elif not is_nan(anchor.x) and angle_step() > 0.0 and to_screen(anchor).distance_to(c) > 2.0:
			# On an angle from where it is drawn: the line it lies on.
			var start: Vector2 = to_screen(anchor)
			var reach: Vector2 = (c - start).normalized() * maxf(size.x, size.y)
			CustomSymbol.stroke_line(self, PackedVector2Array([start, start + reach]), Color(SchematicTheme.SELECTED, 0.45), 1.0, "dash")
		var text: String = "%s, %s mm" % [_mm(at.x), _mm(at.y)]
		if not is_nan(anchor.x) and anchor.distance_to(at) > 0.0001:
			# How long and at what angle (anticlockwise from the right).
			var degrees: float = fposmod(-rad_to_deg((at - anchor).angle()), 360.0)
			text += "   %s mm  %s°" % [_mm(anchor.distance_to(at)), String.num(degrees, 1)]
		draw_circle(c, 3.0, SchematicTheme.SELECTED)
		draw_string(font, c + Vector2(8, -6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SchematicTheme.TEXT)
	if tool == Tool.TEXT and _press.is_empty() and Rect2(Vector2.ZERO, size).has_point(_mouse) and not text.strip_edges().is_empty():
		var preview: CustomSymbol.Shape = _new_shape("text", [m])
		preview.text = text.strip_edges()
		preview.angle = look.angle
		CustomSymbol.draw_shape(self, preview, origin, s, ghost, width, font, true)


## The shapes picked: a dashed box round each, the handles of the points of
## one alone, the corners of the box round them all (filled: they scale)
## and the round handle over it that turns them; while it is dragged, a
## line from their middle to the mouse and the angle.
func _draw_selection(origin: Vector2, s: float) -> void:
	if selection.is_empty():
		return
	var all: Rect2 = Rect2()
	for k: int in selection.size():
		if selection[k] >= symbol.shapes.size():
			continue
		var box: Rect2 = CustomSymbol.shape_bounds(_shown(selection[k]))
		all = box if k == 0 else all.merge(box)
		var screen: Rect2 = Rect2(origin + box.position * s, box.size * s).grow(3.0)
		var round: PackedVector2Array = PackedVector2Array([screen.position, Vector2(screen.end.x, screen.position.y), screen.end, Vector2(screen.position.x, screen.end.y), screen.position])
		CustomSymbol.stroke_line(self, round, Color(SchematicTheme.SELECTED, 0.8), 1.0, "dash")
	if editing_points:
		_draw_point_editing()
		return
	if selected >= 0:
		for p: Vector2 in CustomSymbol.handle_points(_shown(selected)):
			var handle: Rect2 = Rect2(to_screen(p) - Vector2(HANDLE, HANDLE), Vector2(HANDLE, HANDLE) * 2.0)
			draw_rect(handle, SchematicTheme.BACKGROUND)
			draw_rect(handle, SchematicTheme.SELECTED, false, 1.5)
	if _dragging and _press.get("kind", "") == "rotate":
		var middle: Vector2 = to_screen(_selection_middle())
		draw_line(middle, _mouse, Color(SchematicTheme.SELECTED, 0.6), 1.0, true)
		draw_circle(middle, 3.0, SchematicTheme.SELECTED)
		draw_arc(_mouse, HANDLE + 1.0, 0.0, TAU, 16, SchematicTheme.SELECTED, 1.5, true)
		var text: String = "%s°" % String.num(_rotation_degrees(_mouse), 0)
		draw_string(get_theme_default_font(), _mouse + Vector2(12, -8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SchematicTheme.SELECTED)
		return
	if all.size.x >= 0.001 or all.size.y >= 0.001:
		for corner: Vector2 in [all.position, Vector2(all.end.x, all.position.y), all.end, Vector2(all.position.x, all.end.y)]:
			var handle: Rect2 = Rect2(to_screen(corner) - Vector2(HANDLE - 1.0, HANDLE - 1.0), Vector2(HANDLE - 1.0, HANDLE - 1.0) * 2.0)
			draw_rect(handle, SchematicTheme.SELECTED)
		var top: Vector2 = to_screen(Vector2(all.get_center().x, all.position.y))
		var knob: Vector2 = top - Vector2(0, ROTATE_REACH)
		draw_line(top, knob + Vector2(0, HANDLE + 1.0), SchematicTheme.SELECTED, 1.0, true)
		draw_circle(knob, HANDLE + 1.0, SchematicTheme.BACKGROUND)
		draw_arc(knob, HANDLE + 1.0, 0.0, TAU, 16, SchematicTheme.SELECTED, 1.5, true)


## Editing points: each point's square (the one clicked last filled) and a
## round mark with a plus in the middle of each edge (where a point goes in).
func _draw_point_editing() -> void:
	var shape: CustomSymbol.Shape = _shown(selected)
	for k: int in shape.points.size():
		var handle: Rect2 = Rect2(to_screen(shape.points[k]) - Vector2(HANDLE, HANDLE), Vector2(HANDLE, HANDLE) * 2.0)
		draw_rect(handle, SchematicTheme.SELECTED if k == _active_point and not _dragging else SchematicTheme.BACKGROUND)
		draw_rect(handle, SchematicTheme.SELECTED, false, 1.5)
	if _dragging:
		return
	for edge: PackedVector2Array in _edges():
		var c: Vector2 = to_screen((edge[0] + edge[1]) * 0.5)
		draw_circle(c, HANDLE, SchematicTheme.BACKGROUND)
		draw_arc(c, HANDLE, 0.0, TAU, 16, Color(SchematicTheme.SELECTED, 0.8), 1.0, true)
		draw_line(c - Vector2(HANDLE - 2.0, 0), c + Vector2(HANDLE - 2.0, 0), SchematicTheme.SELECTED, 1.0)
		draw_line(c - Vector2(0, HANDLE - 2.0), c + Vector2(0, HANDLE - 2.0), SchematicTheme.SELECTED, 1.0)


## Metres [param metres] in millimetres as written: whole, or to a tenth
## off the grid.
static func _mm(metres: float) -> String:
	var mm: float = metres * 1000.0
	return str(roundi(mm)) if is_equal_approx(mm, roundf(mm)) else String.num(mm, 1)
