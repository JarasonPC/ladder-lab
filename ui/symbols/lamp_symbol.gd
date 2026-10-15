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
	if not purpose.is_empty():
		# Above the designation, as in the guide ("Chod" over "-H3").
		var anchor: Vector2 = _designation_anchor()
		draw_label(purpose, anchor, SchematicTheme.LABEL_SIZE - 1, SchematicTheme.PURPOSE_TEXT, -1 if is_side_label(anchor) else 1)
