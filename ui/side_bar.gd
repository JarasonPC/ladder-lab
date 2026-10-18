class_name SideBar
extends HBoxContainer
## A panel beside the schematic or the workspace that can be resized by
## dragging the grip on its inner edge and zoomed with Ctrl+wheel (see
## [ZoomBox]).

## The width or the zoom changed (to remember them).
signal changed

const MIN_WIDTH: float = 160.0
const MAX_WIDTH: float = 720.0
const GRIP_WIDTH: float = 6.0

var content: Control
var zoom_box: ZoomBox
## Width of the panel without its grip (it grows when its content needs more).
var width: float = 250.0:
	set(value):
		width = clampf(value, MIN_WIDTH, MAX_WIDTH)
		if zoom_box != null:
			zoom_box.custom_minimum_size.x = width
var zoom: float:
	get:
		return zoom_box.zoom
	set(value):
		zoom_box.zoom = value

var _grip: Control
## The grip is on the left (panels at the right of the window).
var _grip_left: bool


func _init(p_content: Control, grip_left: bool, p_width: float = 250.0) -> void:
	content = p_content
	_grip_left = grip_left
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_box = ZoomBox.new()
	zoom_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zoom_box.add_child(content)
	zoom_box.zoom_changed.connect(func(_z: float) -> void: changed.emit())
	_grip = Control.new()
	_grip.custom_minimum_size = Vector2(GRIP_WIDTH, 0)
	_grip.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_grip.gui_input.connect(_on_grip_input)
	if grip_left:
		add_child(_grip)
		add_child(zoom_box)
	else:
		add_child(zoom_box)
		add_child(_grip)
	width = p_width


func retranslate() -> void:
	_grip.tooltip_text = tr("Drag to resize. Ctrl+wheel over the panel zooms it, Ctrl+0 resets the zoom.")


func _on_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var dx: float = (event as InputEventMouseMotion).relative.x
		# Dragging from the shown width, even when the content made it wider.
		width = zoom_box.size.x + (-dx if _grip_left else dx)
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		changed.emit()
