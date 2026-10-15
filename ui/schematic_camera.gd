class_name SchematicCamera
extends Camera2D
## Pan with the middle or right mouse button, zoom with the wheel.

const MIN_ZOOM: float = 0.3
const MAX_ZOOM: float = 4.0
const ZOOM_STEP: float = 1.15

var _panning: bool = false


## Zooms and moves so [param rect] (world pixels) fits [param screen_rect]
## (the visible part of the window between the panels), or the whole window.
func fit(rect: Rect2, screen_rect: Rect2 = Rect2(), margin: float = 50.0) -> void:
	var view: Rect2 = screen_rect if screen_rect.has_area() else get_viewport_rect()
	var target: Rect2 = rect.grow(margin)
	var z: float = minf(view.size.x / target.size.x, view.size.y / target.size.y)
	z = clampf(z, MIN_ZOOM, 1.6)
	zoom = Vector2(z, z)
	look_at_world(target.get_center(), view)


## Moves so [param world_point] appears in the middle of [param screen_rect].
func look_at_world(world_point: Vector2, screen_rect: Rect2 = Rect2()) -> void:
	var view: Rect2 = screen_rect if screen_rect.has_area() else get_viewport_rect()
	var offset_on_screen: Vector2 = view.get_center() - get_viewport_rect().get_center()
	position = world_point - offset_on_screen / zoom.x


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
