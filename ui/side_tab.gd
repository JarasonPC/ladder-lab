class_name SideTab
extends Control
## The narrow tab a side panel at the right of the window leaves when it is
## rolled in: an arrow and the panel's title written down the tab. A click
## rolls the panel out again.

signal pressed

const PAD: float = 8.0
const ICON_SIZE: int = 16

var title: String = "":
	set(value):
		title = value
		update_minimum_size()
		queue_redraw()

var _hovered: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _get_minimum_size() -> Vector2:
	var font: Font = get_theme_font("font", "Label")
	var font_size: int = get_theme_font_size("font_size", "Label")
	var text_width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return Vector2(maxf(font.get_height(font_size), ICON_SIZE) + 2.0 * PAD, 3.0 * PAD + ICON_SIZE + text_width)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			queue_redraw()
		NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			queue_redraw()
		NOTIFICATION_THEME_CHANGED:
			update_minimum_size()
			queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit()
			accept_event()


func _draw() -> void:
	draw_style_box(get_theme_stylebox("panel", "RightPanel"), Rect2(Vector2.ZERO, size))
	if _hovered:
		draw_rect(Rect2(Vector2.ZERO, size), AppTheme.accent_soft)
	var color: Color = AppTheme.text if _hovered else AppTheme.text_muted
	var icon: Texture2D = AppTheme.icon("chevron_left", ICON_SIZE, color)
	draw_texture(icon, Vector2((size.x - ICON_SIZE) * 0.5, PAD))
	# The title reads downwards.
	var font: Font = get_theme_font("font", "Label")
	var font_size: int = get_theme_font_size("font_size", "Label")
	var baseline: float = (size.x - font.get_height(font_size)) * 0.5 + font.get_descent(font_size)
	draw_set_transform(Vector2(baseline, 2.0 * PAD + ICON_SIZE), PI * 0.5)
	draw_string(font, Vector2.ZERO, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	draw_set_transform(Vector2.ZERO)
