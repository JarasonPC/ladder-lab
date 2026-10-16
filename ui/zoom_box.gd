class_name ZoomBox
extends Container
## Shows its one child at [member zoom]: the child is laid out in the box's
## size divided by the zoom and drawn scaled up, with text and icons rendered
## for the scale, so they stay sharp. Ctrl+wheel over the box zooms it,
## Ctrl+0 sets it back to 100 %. Other wheel steps never pass through it.

signal zoom_changed(zoom: float)

const MIN_ZOOM: float = 0.6
const MAX_ZOOM: float = 2.5
## Zoom factor per wheel step.
const ZOOM_STEP: float = 1.1

var zoom: float = 1.0:
	set(value):
		value = clampf(snappedf(value, 0.05), MIN_ZOOM, MAX_ZOOM)
		if is_equal_approx(value, zoom):
			return
		zoom = value
		update_minimum_size()
		queue_sort()
		_redraw(self)
		zoom_changed.emit(zoom)


func _init() -> void:
	clip_contents = true
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	mouse_filter = Control.MOUSE_FILTER_PASS


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for child: Node in get_children():
			if child is Control and (child as Control).visible:
				var c: Control = child as Control
				c.scale = Vector2(zoom, zoom)
				c.position = Vector2.ZERO
				c.size = size / zoom


func _get_minimum_size() -> Vector2:
	var result: Vector2 = Vector2.ZERO
	for child: Node in get_children():
		if child is Control and (child as Control).visible:
			result = result.max((child as Control).get_combined_minimum_size() * zoom)
	return result


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var at: Vector2 = get_global_transform_with_canvas().affine_inverse() * (event as InputEventMouse).position if event is InputEventMouse else get_local_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(at):
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if not mb.pressed or not (mb.ctrl_pressed or mb.meta_pressed):
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom *= ZOOM_STEP
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom /= ZOOM_STEP
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and (key.ctrl_pressed or key.meta_pressed) and (key.keycode == KEY_0 or key.keycode == KEY_KP_0):
			zoom = 1.0
			get_viewport().set_input_as_handled()


## Wheel steps that nothing in the panel used (a list scrolled to its end)
## stop here, so they do not reach the schematic behind it.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
				accept_event()


## Symbols drawn for the screen scale (see [SchematicSymbol]) are drawn again.
static func _redraw(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).queue_redraw()
	for child: Node in node.get_children():
		_redraw(child)
