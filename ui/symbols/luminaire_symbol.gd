class_name LuminaireSymbol
extends SchematicSymbol
## Luminaire (see [Luminaire]): the lamp's circle with a cross (IEC 60617
## S00965), filled grey while lit, L above, N below and the frame's PE
## beside N joined to the circle. Its power is written under the designation.

const CENTER := Vector2(0, 30)
const RADIUS: float = 12.0


func _draw_shape(color: Color, width: float) -> void:
	var lit: bool = (component as Load).energized
	aa_line(Vector2(0, 0), Vector2(0, CENTER.y - RADIUS), lead_color(0), lead_width(0))
	aa_line(Vector2(0, CENTER.y + RADIUS), Vector2(0, 3 * G), lead_color(1), lead_width(1))
	aa_polyline(PackedVector2Array([Vector2(G, 3 * G), Vector2(G, CENTER.y), Vector2(RADIUS, CENTER.y)]), lead_color(2), lead_width(2))
	if lit:
		aa_circle(CENTER, RADIUS, SchematicTheme.LAMP_ON)
	aa_arc(CENTER, RADIUS, 0.0, TAU, 32, color, width)
	var d: float = RADIUS * 0.7071
	var cross: Color = (SchematicTheme.LAMP_CROSS if lit else SchematicTheme.LINE) if not warning else color
	aa_line(CENTER + Vector2(-d, -d), CENTER + Vector2(d, d), cross, SchematicTheme.LINE_WIDTH)
	aa_line(CENTER + Vector2(-d, d), CENTER + Vector2(d, -d), cross, SchematicTheme.LINE_WIDTH)


func _draw_labels() -> void:
	var luminaire: Luminaire = component as Luminaire
	var anchor: Vector2 = _designation_anchor()
	draw_label(designation_text(), anchor, SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	draw_label("%s W" % power_text(luminaire.power), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
	if not is_equal_approx(luminaire.height, Luminaire.STANDARD_HEIGHT):
		draw_label(LightSwitchSymbol.height_text(luminaire.height), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 2)
	var names: PackedStringArray = component.get_terminal_names()
	draw_label(names[0], Vector2(0.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[1], Vector2(-0.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[2], Vector2(1.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)


## Rated power as written, whole watts without decimals ("60", "7.5").
static func power_text(power: float) -> String:
	var tenths: float = snappedf(power, 0.1)
	return str(roundi(tenths)) if is_equal_approx(tenths, roundf(tenths)) else String.num(tenths, 1)
