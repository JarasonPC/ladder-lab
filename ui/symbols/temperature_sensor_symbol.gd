class_name TemperatureSensorSymbol
extends SchematicSymbol
## Temperature transmitter as a converter (IEC 60617): a box with a
## diagonal, the temperature θ it measures above it, the voltage U it puts
## out below; supply L+ on top, M below, the output U on top beside L+. Its
## range and its temperature are written beside it, while it has its supply
## also the volts on U; the box is filled then. While simulating a click
## sets the temperature.

const BOX := Rect2(-0.8 * G, 0.8 * G, 3.6 * G, 1.4 * G)


func _draw_shape(color: Color, width: float) -> void:
	var sensor: TemperatureSensor = component as TemperatureSensor
	var out_x: float = SymbolGeometry.SENSOR_OUTPUT_CELL.x * G
	aa_line(Vector2.ZERO, Vector2(0, BOX.position.y), lead_color(0), lead_width(0))
	aa_line(Vector2(0, BOX.end.y), Vector2(0, SymbolGeometry.SPAN * G), lead_color(1), lead_width(1))
	aa_line(Vector2(out_x, 0), Vector2(out_x, BOX.position.y), lead_color(2), lead_width(2))
	if sensor.energized:
		aa_rect(BOX, SchematicTheme.COIL_ON)
	aa_rect(BOX, color, false, width)
	aa_line(Vector2(BOX.position.x, BOX.end.y), Vector2(BOX.end.x, BOX.position.y), color, 1.2)


func _draw_labels() -> void:
	super()
	var sensor: TemperatureSensor = component as TemperatureSensor
	var names: PackedStringArray = component.get_terminal_names()
	draw_label(names[2], Vector2(SymbolGeometry.SENSOR_OUTPUT_CELL.x * G + 0.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	_centered("θ", BOX.position + Vector2(0.75 * G, 0.4 * G), 12)
	_centered("U", BOX.end - Vector2(0.75 * G, 0.4 * G), 11)
	var anchor: Vector2 = _designation_anchor()
	draw_label("%s…%s °C" % [_number(sensor.range_min), _number(sensor.range_max)], anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
	var state: String = "%.1f °C" % sensor.temperature
	if sensor.energized:
		state += "  %.2f V" % sensor.output_volts()
	draw_label(state, anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.DESIGNATION, 2)


func _designation_anchor() -> Vector2:
	return Vector2(-1.1 * G, 1.5 * G)


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
