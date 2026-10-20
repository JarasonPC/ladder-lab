class_name PotentiometerSymbol
extends SchematicSymbol
## Potentiometer (IEC 60617 S00557): an upright resistor from 1 down to 3,
## the wiper 2 an arrow pointing at its side from the right. Its resistance
## and turns are written beside it, while simulating where it is set and the
## volts on the wiper; a click then sets it.

const BOX := Rect2(-0.35 * G, 1.1 * G, 0.7 * G, 1.8 * G)
const ARROW_LENGTH: float = 9.0
const ARROW_HALF: float = 4.5


func _draw_shape(color: Color, width: float) -> void:
	var span: float = SymbolGeometry.POT_SPAN * G
	var wiper: Vector2 = Vector2(SymbolGeometry.POT_WIPER_CELL) * G
	aa_line(Vector2.ZERO, Vector2(0, BOX.position.y), lead_color(0), lead_width(0))
	aa_line(Vector2(0, BOX.end.y), Vector2(0, span), lead_color(2), lead_width(2))
	aa_line(wiper, Vector2(BOX.end.x + ARROW_LENGTH, wiper.y), lead_color(1), lead_width(1))
	aa_rect(BOX, color, false, width)
	var tip: Vector2 = Vector2(BOX.end.x, wiper.y)
	aa_polygon(PackedVector2Array([tip, tip + Vector2(ARROW_LENGTH, -ARROW_HALF), tip + Vector2(ARROW_LENGTH, ARROW_HALF)]), lead_color(1))


func _draw_labels() -> void:
	var pot: Potentiometer = component as Potentiometer
	var names: PackedStringArray = component.get_terminal_names()
	var anchor: Vector2 = _designation_anchor()
	draw_label(designation_text(), anchor, SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	draw_label(names[0], name_anchor(0, Vector2(0.35 * G, 0.5 * G)), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[1], name_anchor(1, Vector2(SymbolGeometry.POT_WIPER_CELL.x * G - 0.3 * G, SymbolGeometry.POT_WIPER_CELL.y * G - 0.45 * G)), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[2], name_anchor(2, Vector2(0.35 * G, (SymbolGeometry.POT_SPAN - 0.5) * G)), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label("%s kΩ" % _number(Potentiometer.RESISTANCE / 1000.0), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
	draw_label(turns_text(pot.turns), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 2)
	if any_live() or pot.volts >= 0.0:
		var state: String = "%.1f %%" % (pot.setting * 100.0)
		if pot.volts >= 0.0:
			state += "  %.2f V" % pot.volts
		draw_label(state, anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.DESIGNATION, 3)


## "1 turn", "10 turns".
func turns_text(turns: int) -> String:
	return tr_n("%d turn", "%d turns", turns) % turns


func _designation_anchor() -> Vector2:
	return Vector2(-0.9 * G, 2.0 * G)


func is_interactive() -> bool:
	return true


static func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
