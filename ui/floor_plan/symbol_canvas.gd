class_name SymbolCanvas
extends Control
## Where a symbol of the user's own ([CustomSymbol]) is drawn, on schematic
## paper with a grid of centimetres: its origin where the axes cross (for a
## symbol on a wall the wall above it, the room below). Wheel zooms at the
## mouse, right or middle drag pans.
##
## By [member tool]: SELECT picks a shape (dragged, it moves; its points'
## handles drag them; Delete takes it away); LINE, RECT and ELLIPSE are
## dragged from corner to corner; ARC and CURVE are dragged from one end to
## the other, then a click sets the point the arc goes through or the curve
## bends towards (Esc or a right click drops it); TEXT puts [member text]
## where it is clicked. Points snap to [constant SNAP]. Ctrl+Z / Ctrl+Y undo
## and redo.

## The shapes changed.
signal changed
## [member selected] changed.
signal selection_changed

enum Tool { SELECT, LINE, RECT, ELLIPSE, ARC, CURVE, TEXT }

## Pixels a metre at zoom 1.
const PX: float = 600.0
const MIN_ZOOM: float = 0.2
const MAX_ZOOM: float = 8.0
const ZOOM_STEP: float = 1.15
## Points snap to this (m).
const SNAP: float = 0.005
## A shape this close to the mouse (pixels) is under it; a handle this close.
const GRAB: float = 6.0
const HANDLE: float = 4.5
## The most undo steps kept.
const MAX_UNDO: int = 100

var symbol: CustomSymbol = CustomSymbol.new()
var tool: Tool = Tool.SELECT:
	set(value):
		tool = value
		_pending = PackedVector2Array()
		mouse_default_cursor_shape = Control.CURSOR_CROSS if value != Tool.SELECT else Control.CURSOR_ARROW
		queue_redraw()
## New rectangles and ellipses filled.
var filled: bool = false
## What TEXT puts, and its height (m).
var text: String = "TV"
var text_size: float = CustomSymbol.TEXT_SIZE
## The shape selected, -1 for none.
var selected: int = -1:
	set(value):
		var was: int = selected
		selected = value
		if was != value:
			selection_changed.emit()
		queue_redraw()
var zoom: float = 1.0
## Screen position of the origin.
var offset: Vector2 = Vector2.ZERO

var _press: Dictionary = {}
var _press_at: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _mouse: Vector2 = Vector2.ZERO
var _pan_button: MouseButton = MOUSE_BUTTON_NONE
## An arc's or curve's two ends while its middle point is chosen.
var _pending: PackedVector2Array = PackedVector2Array()
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
	selected = -1
	_undo.clear()
	_redo.clear()
	_pending = PackedVector2Array()
	offset = Vector2.ZERO
	fit()


func to_symbol(point: Vector2) -> Vector2:
	return (point - offset) / (PX * zoom)


func to_screen(point: Vector2) -> Vector2:
	return offset + point * PX * zoom


static func snap(point: Vector2) -> Vector2:
	return point.snapped(Vector2(SNAP, SNAP)).clamp(-Vector2.ONE * CustomSymbol.REACH, Vector2.ONE * CustomSymbol.REACH)


## Shows the symbol (at least half a metre round the origin) as large as fits.
func fit() -> void:
	if size.x < 10.0:
		return
	var area: Rect2 = symbol.bounds().merge(Rect2(-0.25, -0.25, 0.5, 0.5)).grow(0.05)
	zoom = clampf(minf(size.x / (area.size.x * PX), size.y / (area.size.y * PX)), MIN_ZOOM, MAX_ZOOM)
	offset = size * 0.5 - area.get_center() * PX * zoom
	queue_redraw()


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
	selected = -1
	changed.emit()


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_shapes_copy())
	symbol.shapes.assign(_redo.pop_back())
	selected = -1
	changed.emit()


## Adds [param shape] (one undo step) and selects it.
func add_shape(shape: CustomSymbol.Shape) -> void:
	if symbol.shapes.size() >= CustomSymbol.MAX_SHAPES:
		return
	_record()
	symbol.shapes.append(shape)
	selected = symbol.shapes.size() - 1
	changed.emit()


## Changes the selected shape with [param change] (called with it), one undo step.
func change_selected(change: Callable) -> void:
	if selected < 0 or selected >= symbol.shapes.size():
		return
	_record()
	change.call(symbol.shapes[selected])
	changed.emit()
	queue_redraw()


func delete_selected() -> void:
	if selected < 0 or selected >= symbol.shapes.size():
		return
	_record()
	symbol.shapes.remove_at(selected)
	selected = -1
	changed.emit()


## The handle of the selected shape under screen point [param point]: the
## index of its point, -1 for none.
func handle_at(point: Vector2) -> int:
	if selected < 0 or selected >= symbol.shapes.size():
		return -1
	var shape: CustomSymbol.Shape = symbol.shapes[selected]
	for k: int in shape.points.size():
		if to_screen(shape.points[k]).distance_to(point) <= HANDLE + 3.0:
			return k
	return -1


func shape_at(point: Vector2) -> int:
	return symbol.shape_at(to_symbol(point), GRAB / (PX * zoom))


func _gui_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed:
		if key.keycode == KEY_Z and key.is_command_or_control_pressed():
			if key.shift_pressed:
				redo()
			else:
				undo()
		elif key.keycode == KEY_Y and key.is_command_or_control_pressed():
			redo()
		elif key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE:
			delete_selected()
		elif key.keycode == KEY_ESCAPE and not _pending.is_empty():
			_pending = PackedVector2Array()
			queue_redraw()
		else:
			return
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
		if _pan_button != MOUSE_BUTTON_NONE:
			offset += motion.relative
		elif not _press.is_empty() and not _dragging and motion.position.distance_to(_press_at) >= SchematicEditor.CLICK_SLOP:
			_dragging = true
		queue_redraw()
		accept_event()


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
				if mb.button_index == MOUSE_BUTTON_RIGHT and not _pending.is_empty():
					_pending = PackedVector2Array()
					queue_redraw()
					return
				_pan_button = mb.button_index
			elif mb.button_index == _pan_button:
				_pan_button = MOUSE_BUTTON_NONE
		MOUSE_BUTTON_LEFT:
			grab_focus()
			if mb.pressed:
				_press_at = mb.position
				_mouse = mb.position
				_dragging = false
				_press = _pressed(mb.position)
				queue_redraw()
			elif not _press.is_empty():
				var press: Dictionary = _press
				_press = {}
				_release(press, mb.position)
				_dragging = false
				queue_redraw()


func _pressed(point: Vector2) -> Dictionary:
	if not _pending.is_empty():
		return {"kind": "middle"}
	if tool != Tool.SELECT:
		return {"kind": "new"}
	var handle: int = handle_at(point)
	if handle >= 0:
		return {"kind": "handle", "which": handle}
	var shape: int = shape_at(point)
	selected = shape
	return {"kind": "shape"} if shape >= 0 else {"kind": "empty"}


func _release(press: Dictionary, point: Vector2) -> void:
	var a: Vector2 = snap(to_symbol(_press_at))
	var b: Vector2 = snap(to_symbol(point))
	match press["kind"]:
		"middle":
			var ends: PackedVector2Array = _pending
			_pending = PackedVector2Array()
			add_shape(_shape("arc" if tool == Tool.ARC else "curve", [ends[0], b, ends[1]]))
		"new":
			match tool:
				Tool.TEXT:
					if not text.strip_edges().is_empty():
						var shape: CustomSymbol.Shape = _shape("text", [b])
						shape.text = text.strip_edges().left(CustomSymbol.MAX_TEXT_LENGTH)
						shape.size = text_size
						add_shape(shape)
				Tool.LINE, Tool.RECT, Tool.ELLIPSE:
					if a.distance_to(b) >= SNAP:
						var shape: CustomSymbol.Shape = _shape(["", "line", "rect", "ellipse"][tool], [a, b])
						shape.filled = filled and tool != Tool.LINE
						add_shape(shape)
				Tool.ARC, Tool.CURVE:
					if a.distance_to(b) >= SNAP:
						_pending = PackedVector2Array([a, b])
		"handle":
			if _dragging:
				var which: int = press["which"]
				change_selected(func(shape: CustomSymbol.Shape) -> void: shape.points[which] = b)
		"shape":
			if _dragging and a != b:
				var by: Vector2 = b - a
				change_selected(func(shape: CustomSymbol.Shape) -> void:
					for k: int in shape.points.size():
						shape.points[k] = snap(shape.points[k] + by))


func _shape(kind: String, points: Array[Vector2]) -> CustomSymbol.Shape:
	var shape: CustomSymbol.Shape = CustomSymbol.Shape.new()
	shape.kind = kind
	shape.points = PackedVector2Array(points)
	return shape


## The selected shape as it is shown: its point or itself dragged.
func _shown(index: int) -> CustomSymbol.Shape:
	var shape: CustomSymbol.Shape = symbol.shapes[index]
	if not _dragging or index != selected or not (_press.get("kind", "") in ["handle", "shape"]):
		return shape
	var moved: CustomSymbol.Shape = shape.copy()
	var b: Vector2 = snap(to_symbol(_mouse))
	if _press["kind"] == "handle":
		moved.points[int(_press["which"])] = b
	else:
		var by: Vector2 = b - snap(to_symbol(_press_at))
		for k: int in moved.points.size():
			moved.points[k] = snap(moved.points[k] + by)
	return moved


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SchematicTheme.BACKGROUND)
	var s: float = PX * zoom
	var font: Font = get_theme_default_font()
	# The grid: every centimetre faint (when far enough apart), every 5 cm
	# and 10 cm stronger.
	var from: Vector2 = to_symbol(Vector2.ZERO)
	var to: Vector2 = to_symbol(size)
	for step: Array in [[0.01, 0.05], [0.05, 0.1], [0.1, 0.18]]:
		var d: float = step[0]
		if d * s < 6.0:
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
		CustomSymbol.draw_shape(self, _shown(i), origin, s, SchematicTheme.SELECTED if i == selected else SchematicTheme.LINE, width, font)
	if selected >= 0 and selected < symbol.shapes.size():
		for p: Vector2 in _shown(selected).points:
			var box: Rect2 = Rect2(to_screen(p) - Vector2(HANDLE, HANDLE), Vector2(HANDLE, HANDLE) * 2.0)
			draw_rect(box, SchematicTheme.BACKGROUND)
			draw_rect(box, SchematicTheme.SELECTED, false, 1.5)
	# What is being drawn.
	var m: Vector2 = snap(to_symbol(_mouse))
	var ghost: Color = Color(SchematicTheme.SELECTED, 0.7)
	if not _pending.is_empty():
		CustomSymbol.draw_shape(self, _shape("arc" if tool == Tool.ARC else "curve", [_pending[0], m, _pending[1]]), origin, s, ghost, width, font)
	elif _dragging and _press.get("kind", "") == "new" and tool in [Tool.LINE, Tool.RECT, Tool.ELLIPSE, Tool.ARC, Tool.CURVE]:
		var a: Vector2 = snap(to_symbol(_press_at))
		var kind: String = "line" if tool in [Tool.LINE, Tool.ARC, Tool.CURVE] else ("rect" if tool == Tool.RECT else "ellipse")
		CustomSymbol.draw_shape(self, _shape(kind, [a, m]), origin, s, ghost, width, font)
	if tool != Tool.SELECT and Rect2(Vector2.ZERO, size).has_point(_mouse):
		draw_circle(to_screen(m), 3.0, SchematicTheme.SELECTED)
		draw_string(font, to_screen(m) + Vector2(8, -6), "%d, %d mm" % [roundi(m.x * 1000.0), roundi(m.y * 1000.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SchematicTheme.TEXT)
	if tool == Tool.TEXT and _press.is_empty() and Rect2(Vector2.ZERO, size).has_point(_mouse) and not text.strip_edges().is_empty():
		var preview: CustomSymbol.Shape = _shape("text", [m])
		preview.text = text.strip_edges()
		preview.size = text_size
		CustomSymbol.draw_shape(self, preview, origin, s, ghost, width, font)
