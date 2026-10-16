class_name SideBar
extends HBoxContainer
## A panel beside the schematic that can be resized by dragging the grip on
## its inner edge and zoomed with Ctrl+wheel (see [ZoomBox]). It can roll in
## to a narrow tab with its [member title] written down it ([member rolled]);
## a click on the tab rolls it out again.

## The width, the zoom or the rolled state changed (to remember them).
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

## Rolled in to its tab.
var rolled: bool = false:
	set(value):
		if value == rolled:
			return
		rolled = value
		_show_rolled()
		changed.emit()
## Written down the tab while rolled in.
var title: String = "":
	set(value):
		title = value
		if _tab != null:
			_tab.tooltip_text = value
			_tab.update_minimum_size()
			_tab.custom_minimum_size.y = _tab_height()
			_tab.queue_redraw()

var _grip: Control
var _tab: Button
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
	_tab = Button.new()
	_tab.theme_type_variation = "ListButton"
	_tab.focus_mode = Control.FOCUS_NONE
	_tab.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tab.custom_minimum_size.x = 30.0
	_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab.visible = false
	_tab.pressed.connect(func() -> void: rolled = false)
	_tab.draw.connect(_draw_tab)
	if grip_left:
		add_child(_grip)
		add_child(zoom_box)
	else:
		add_child(zoom_box)
		add_child(_grip)
	add_child(_tab)
	width = p_width


func retranslate() -> void:
	_grip.tooltip_text = tr("Drag to resize. Ctrl+wheel over the panel zooms it, Ctrl+0 resets the zoom.")


func _show_rolled() -> void:
	zoom_box.visible = not rolled
	_grip.visible = not rolled
	_tab.visible = rolled
	_tab.custom_minimum_size.y = _tab_height()


## Height of the tab: the arrow and the title written down it.
func _tab_height() -> float:
	if _tab == null or not _tab.is_inside_tree():
		return 0.0
	var font: Font = _tab.get_theme_font("font")
	return 34.0 + font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, _tab.get_theme_font_size("font_size")).x


## The rolled-in tab: an arrow at the top, the title down from it.
func _draw_tab() -> void:
	var font: Font = _tab.get_theme_font("font")
	var font_size: int = _tab.get_theme_font_size("font_size")
	var color: Color = _tab.get_theme_color("font_color")
	var arrow: Texture2D = AppTheme.icon("chevron_left" if _grip_left else "chevron_right", 16)
	var w: float = _tab.size.x
	_tab.draw_texture(arrow, Vector2((w - arrow.get_width()) * 0.5, 8.0))
	# Turned a quarter clockwise, the text reads from the top down.
	var x: float = w * 0.5 - (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	_tab.draw_set_transform(Vector2(x, 30.0), PI * 0.5)
	_tab.draw_string(font, Vector2.ZERO, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	_tab.draw_set_transform(Vector2.ZERO)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _tab != null:
		_tab.custom_minimum_size.y = _tab_height()


func _on_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var dx: float = (event as InputEventMouseMotion).relative.x
		# Dragging from the shown width, even when the content made it wider.
		width = zoom_box.size.x + (-dx if _grip_left else dx)
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		changed.emit()
