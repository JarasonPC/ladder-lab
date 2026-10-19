class_name LampSymbol
extends SchematicSymbol
## Signal lamp (IEC 60617 S00965): circle with a cross, filled grey while lit.

const CENTER := Vector2(0, 30)
const RADIUS: float = 12.0


func _draw_shape(color: Color, width: float) -> void:
	var lit: bool = (component as Load).energized
	aa_line(Vector2(0, 0), Vector2(0, CENTER.y - RADIUS), lead_color(0), lead_width(0))
	aa_line(Vector2(0, CENTER.y + RADIUS), Vector2(0, 3 * G), lead_color(1), lead_width(1))
	if lit:
		aa_circle(CENTER, RADIUS, SchematicTheme.LAMP_ON)
	aa_arc(CENTER, RADIUS, 0.0, TAU, 32, color, width)
	var d: float = RADIUS * 0.7071
	var cross: Color = (SchematicTheme.LAMP_CROSS if lit else SchematicTheme.LINE) if not warning else color
	aa_line(CENTER + Vector2(-d, -d), CENTER + Vector2(d, d), cross, SchematicTheme.LINE_WIDTH)
	aa_line(CENTER + Vector2(-d, d), CENTER + Vector2(d, -d), cross, SchematicTheme.LINE_WIDTH)


func _draw_labels() -> void:
	super()
	var purpose: String = (component as Lamp).purpose
	# Lines further on are written down the drawing beside or under the
	# lamp, up it over the lamp.
	var down: bool = is_side_label(_designation_anchor()) or _under()
	draw_rating(_designation_anchor(), 1 if down or purpose.is_empty() else 2)
	if not purpose.is_empty():
		# Above the designation, as in the guide ("Chod" over "-H3").
		draw_label(purpose, _designation_anchor(), SchematicTheme.LABEL_SIZE - 1, SchematicTheme.PURPOSE_TEXT, -1 if down else 1)


func _designation_anchor() -> Vector2:
	# Under the lamp with a purpose: a line further down, so that the purpose
	# fits between the lamp and the designation.
	if _under() and not (component as Lamp).purpose.is_empty():
		return Vector2(-2.2 * G, 1.5 * G)
	return super()


## True when the designation is written under the lamp.
func _under() -> bool:
	return SymbolGeometry.draw_transform(placement).basis_xform(Vector2.LEFT).y > 0.5
