class_name PlcCanvas
extends Control
## Base of the diagrams of the PLC program window ([PlcFbdCanvas],
## [PlcLadCanvas]): drawn on schematic paper with _draw(), zoomed with
## Ctrl+wheel. Editing changes [member program] in place and reports it with
## [signal changed]; while monitoring (a [member runtime] is given) nothing
## can be changed and the signals are drawn in [constant ON] where they are 1.
##
## Palette tools: [method tools] lists them, [member tool] is the one in use
## ("" selects and moves).

## The program was edited (one finished change, for undo).
signal changed
## Another element was selected (or the selected one changed).
signal selection_changed
## The tool ended (Esc or right click): the palette goes back to selecting.
signal tool_finished

## Colour of a signal that is 1 while monitoring (as in PLC programming software).
const ON := Color(0.1, 0.66, 0.28)
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


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


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
	return runtime == null and program != null


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
	if mb != null and mb.pressed and (mb.ctrl_pressed or mb.meta_pressed) and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom *= 1.1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
		accept_event()
		return
	if mb != null and mb.pressed:
		grab_focus()
	_canvas_input(event)


## Mouse and keys on the diagram. Override.
func _canvas_input(_event: InputEvent) -> void:
	pass


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SchematicTheme.BACKGROUND)


## Line colour of a signal: [constant ON] while monitoring when [param on].
func signal_color(on: bool) -> Color:
	return ON if runtime != null and on else SchematicTheme.LINE


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
