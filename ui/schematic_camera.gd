class_name SchematicCamera
extends Camera2D
## Pan with the middle or right mouse button, zoom with the wheel.

const MIN_ZOOM: float = 0.3
const MAX_ZOOM: float = 4.0
const ZOOM_STEP: float = 1.15

var _panning: bool = false


## Centres and zooms so [param rect] (pixels) fits the visible area.
func fit(rect: Rect2, margin: float = 60.0) -> void:
	var view: Vector2 = get_viewport_rect().size
	var target: Rect2 = rect.grow(margin)
	var z: float = minf(view.x / target.size.x, view.y / target.size.y)
	z = clampf(z, MIN_ZOOM, 1.6)
	zoom = Vector2(z, z)
	position = target.get_center()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			_panning = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(ZOOM_STEP, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / ZOOM_STEP, mb.position)
	elif event is InputEventMouseMotion and _panning:
		position -= (event as InputEventMouseMotion).relative / zoom.x


func _zoom_at(factor: float, screen_point: Vector2) -> void:
	var before: Vector2 = get_canvas_transform().affine_inverse() * screen_point
	var z: float = clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)
	force_update_scroll()
	var after: Vector2 = get_canvas_transform().affine_inverse() * screen_point
	position += before - after
