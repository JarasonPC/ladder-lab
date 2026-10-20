class_name TemperatureSensorSymbol
extends SchematicSymbol
## Temperature transmitter: a box holding its measuring element, a resistor
## varying with the temperature θ (IEC 60617 S00561, as a Pt100), and the
## voltage U it puts out; supply L+ on top, M below, the output U on top
## beside L+. Its range and its temperature are written beside it, while it
## has its supply also the volts on U; the box is filled then. While
## simulating a click sets the temperature. The palette shows a thermometer
## with an arrow to U. [TransmitterSymbol] draws other transmitters alike.

const BOX := Rect2(-0.8 * G, 0.8 * G, 3.6 * G, 1.4 * G)
## The measuring element and the slanted line across it, its foot to the left.
const ELEMENT := Rect2(-2.0, 26.0, 24.0, 9.0)
const SLANT_FROM := Vector2(-6.0, 40.0)
const SLANT_TO := Vector2(26.0, 20.0)
## θ above the foot, clear of the line and the element.
const THETA_AT := Vector2(-9.0, 22.0)
const PREVIEW_BOX := Rect2(0.0, 0.0, 100.0, 50.0)


func _draw_shape(color: Color, width: float) -> void:
	if preview:
		_draw_preview(color, width)
		return
	var sensor: AnalogSensor = component as AnalogSensor
	var out_x: float = SymbolGeometry.SENSOR_OUTPUT_CELL.x * G
	aa_line(Vector2.ZERO, Vector2(0, BOX.position.y), lead_color(0), lead_width(0))
	aa_line(Vector2(0, BOX.end.y), Vector2(0, SymbolGeometry.SPAN * G), lead_color(1), lead_width(1))
	aa_line(Vector2(out_x, 0), Vector2(out_x, BOX.position.y), lead_color(2), lead_width(2))
	if sensor.energized:
		aa_rect(BOX, SchematicTheme.COIL_ON)
	aa_rect(BOX, color, false, width)
	_draw_element(color, width)


## What it measures with, in the left of the box.
func _draw_element(color: Color, width: float) -> void:
	aa_rect(ELEMENT, color, false, width)
	aa_polyline(PackedVector2Array([SLANT_FROM - Vector2(4.0, 0.0), SLANT_FROM, SLANT_TO]), color, 1.2)


func preview_rect() -> Rect2:
	return PREVIEW_BOX


## A box with a thermometer and an arrow to U.
func _draw_preview(color: Color, width: float) -> void:
	aa_rect(PREVIEW_BOX, color, false, width)
	# Stem with a rounded top, the bulb, the column and three scale ticks.
	aa_line(Vector2(20.0, 12.0), Vector2(20.0, 32.0), color, width)
	aa_line(Vector2(28.0, 12.0), Vector2(28.0, 32.0), color, width)
	aa_arc(Vector2(24.0, 12.0), 4.0, PI, TAU, 8, color, width)
	aa_circle(Vector2(24.0, 37.0), 7.0, color)
	aa_line(Vector2(24.0, 15.0), Vector2(24.0, 32.0), color, 3.0)
	for y: float in [14.0, 20.0, 26.0]:
		aa_line(Vector2(31.0, y), Vector2(36.0, y), color, width)
	aa_line(Vector2(46.0, 25.0), Vector2(64.0, 25.0), color, width)
	aa_polyline(PackedVector2Array([Vector2(58.0, 19.0), Vector2(64.0, 25.0), Vector2(58.0, 31.0)]), color, width)
	draw_preview_text("U", Vector2(80.0, 25.0), 28)


func _draw_labels() -> void:
	var sensor: AnalogSensor = component as AnalogSensor
	var names: PackedStringArray = component.get_terminal_names()
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	draw_label(names[0], name_anchor(0, Vector2(0.35 * G, 0.4 * G)), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[1], name_anchor(1, Vector2(0.35 * G, 2.6 * G)), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[2], name_anchor(2, Vector2(SymbolGeometry.SENSOR_OUTPUT_CELL.x * G + 0.35 * G, 0.4 * G)), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	_draw_element_labels()
	_centered("U", Vector2(BOX.end.x - 0.6 * G, BOX.get_center().y), 12)
	var anchor: Vector2 = _designation_anchor()
	draw_label("%s…%s %s" % [_number(sensor.range_min), _number(sensor.range_max), sensor.unit()], anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
	var state: String = "%.1f %s" % [sensor.measured(), sensor.unit()]
	if sensor.energized:
		state += "  %.2f V" % sensor.output_volts()
	draw_label(state, anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.DESIGNATION, 2)


## Texts of the measuring element.
func _draw_element_labels() -> void:
	_centered("θ", THETA_AT, 10)


func _designation_anchor() -> Vector2:
	# Further out when M is on a terminal strip, clear of the strip's label.
	return Vector2(-1.4 * G if placement.strips.has(1) else -1.1 * G, 1.5 * G)


func is_interactive() -> bool:
	return true


static func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


## Upright text centred on local point [param at].
func _centered(text: String, at: Vector2, font_size: int) -> void:
	var font: Font = AppTheme.schematic_font()
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var c: Vector2 = to_upright(at)
	var pos: Vector2 = c + Vector2(-size.x * 0.5, font.get_ascent(font_size) * 0.5 - 1.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, SchematicTheme.TEXT)
	text_rects.append(Rect2(Vector2(pos.x, pos.y - font.get_ascent(font_size)), size))
