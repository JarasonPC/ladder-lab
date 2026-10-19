class_name PlcCanvas
extends Control
## Base of the diagrams of the PLC program window ([PlcFbdCanvas],
## [PlcLadCanvas]): drawn on schematic paper with _draw(). The wheel scrolls
## (Shift+wheel sideways), Ctrl+wheel zooms, dragging with the middle or
## right button or with Space held moves the view (in the [ScrollContainer]
## it sits in). Editing changes [member program] in place and reports it with
## [signal changed]; while monitoring (a [member runtime] is given) nothing
## can be changed and, as in the simulation of the programming software,
## signals that are 1 are drawn in [constant ON] (red), signals that are 0 in
## [constant OFF] (blue).
##
## Palette tools: [method tools] lists them, [member tool] is the one in use
## ("" selects and moves).

## The program was edited (one finished change, for undo).
signal changed
## Another element was selected (or the selected one changed).
signal selection_changed
## The tool ended (Esc or right click): the palette goes back to selecting.
signal tool_finished

## Colours of a signal that is 1 and of one that is 0 while monitoring.
const ON := Color("e0201b")
const OFF := Color("2f6fd4")
## Mouse travel (pixels) after which a right button press moves the view
## instead of clicking.
const PAN_SLOP: float = 5.0
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.5

var program: PlcProgram
## The running PLC's program state while monitoring, else null.
var runtime: PlcRuntime = null
var zoom: float = 1.0:
	set(value):
		zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
		update_size()
		queue_redraw()
var tool: String = "":
	set(value):
		tool = value
		queue_redraw()
## Drawn for a sheet of paper (the PDF export): read-only, without the
## editing aids (grid, dots, spare room).
var paper: bool = false
## Writes an operand as the PLC names it ([method Plc.address]).
var address: Callable = func(operand: String) -> String: return operand
## The program's value for 10 V on the PLC ([method Plc.full_scale]): new
## analog elements start at values on its scale.
var full_scale: float = PlcBlock.ANALOG_MAX

## Moving the view: the button doing it (MOUSE_BUTTON_NONE when not), where
## it went down, whether it moved far enough.
var _pan_button: MouseButton = MOUSE_BUTTON_NONE
var _pan_from: Vector2 = Vector2.ZERO
var _panned: bool = false


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	# Unused wheel turns go on to the ScrollContainer, which scrolls.
	mouse_filter = Control.MOUSE_FILTER_PASS


## Shows [param p]; with [param p_runtime] its running state (monitoring,
## read-only).
func show_program(p: PlcProgram, p_runtime: PlcRuntime) -> void:
	program = p
	runtime = p_runtime
	if runtime != null:
		tool = ""
	_program_shown()
	update_size()
	queue_redraw()


func editable() -> bool:
	return runtime == null and program != null and not paper


## Palette entries: [{"id": tool, "title": English text, "symbol": short
## symbol text, "group": English group title}].
func tools() -> Array[Dictionary]:
	return []


## What is selected, for the window's side panel: "title" (English),
## optional "operand" with "areas" (operands it may name), "time" (s),
## "preset", "live" (state while monitoring, already formatted), "help"
## (English). {} when nothing is selected.
func selection_info() -> Dictionary:
	return {}


## Sets property [param key] ("operand", "time", "preset") of the selection.
func set_property(_key: String, _value: Variant) -> void:
	pass


func delete_selection() -> void:
	pass


## Size of the drawing in pixels at zoom 1. Override.
func _content_size() -> Vector2:
	return Vector2.ZERO


## Called when another program is shown (keep or drop the selection). Override.
func _program_shown() -> void:
	pass


func update_size() -> void:
	custom_minimum_size = _content_size() * zoom


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		if mb.pressed and (mb.ctrl_pressed or mb.meta_pressed) and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_at(1.1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1, mb.position)
			accept_event()
		return
	if _pan_input(event):
		accept_event()
		return
	if mb != null and mb.pressed:
		grab_focus()
	_canvas_input(event)


## Moves the view by middle or right dragging, or left dragging with Space
## held. Returns true when [param event] was taken for it. A right press
## that does not move is handed on as a click on its release.
func _pan_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		var space: bool = mb.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE)
		if mb.pressed and _pan_button == MOUSE_BUTTON_NONE and (mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT or space):
			_pan_button = mb.button_index
			_pan_from = mb.global_position
			_panned = mb.button_index != MOUSE_BUTTON_RIGHT
			grab_focus()
			return true
		if not mb.pressed and mb.button_index == _pan_button:
			var clicked: bool = _pan_button == MOUSE_BUTTON_RIGHT and not _panned
			_pan_button = MOUSE_BUTTON_NONE
			if clicked:
				_right_click(mb.position)
			return true
		return false
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _pan_button != MOUSE_BUTTON_NONE:
		if not _panned and motion.global_position.distance_to(_pan_from) >= PAN_SLOP:
			_panned = true
		if _panned:
			scroll_by(-motion.relative)
		return true
	return false


## Scrolls the [ScrollContainer] the diagram sits in by [param pixels].
func scroll_by(pixels: Vector2) -> void:
	var scroll: ScrollContainer = get_parent() as ScrollContainer
	if scroll != null:
		scroll.scroll_horizontal += roundi(pixels.x)
		scroll.scroll_vertical += roundi(pixels.y)


## Zooms by [param factor] keeping the diagram point under [param at] where it is.
func _zoom_at(factor: float, at: Vector2) -> void:
	var before: float = zoom
	zoom *= factor
	var shift: Vector2 = at * (zoom / before - 1.0)
	await get_tree().process_frame
	scroll_by(shift)


## A right click (that did not move the view) at [param _at]. Override.
func _right_click(_at: Vector2) -> void:
	pass


## Mouse and keys on the diagram. Override.
func _canvas_input(_event: InputEvent) -> void:
	pass


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SchematicTheme.BACKGROUND)


## Line colour of a signal: [constant ON] or [constant OFF] while
## monitoring, else the line colour.
func signal_color(on: bool) -> Color:
	if runtime == null:
		return SchematicTheme.LINE
	return ON if on else OFF


## Text centred on [param at] ([param align] -1 left from it, 1 right up to it).
func text(value: String, at: Vector2, font_size: int, color: Color, align: int = 0) -> void:
	var font: Font = AppTheme.schematic_font()
	var px: int = maxi(roundi(font_size * zoom), 6)
	var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x: float = at.x - width * 0.5
	if align < 0:
		x = at.x
	elif align > 0:
		x = at.x - width
	draw_string(font, Vector2(x, at.y + font.get_ascent(px) * 0.5 - 1.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


## Seconds as written on the diagrams: "3 s", "1.5 s", "0.25 s".
static func seconds(value: float) -> String:
	return "%s s" % String.num(snappedf(value, 0.01))
