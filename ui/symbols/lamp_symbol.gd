class_name LampSymbol
extends SchematicSymbol
## Signal lamp (IEC 60617 S00965): circle with a cross.

const CENTER := Vector2(0, 30)
const RADIUS: float = 11.0


func _draw_shape(color: Color, width: float) -> void:
	var lit: bool = (component as Load).energized
	draw_line(Vector2(0, 0), Vector2(0, CENTER.y - RADIUS), lead_color(0), lead_width(0))
	draw_line(Vector2(0, CENTER.y + RADIUS), Vector2(0, 3 * G), lead_color(1), lead_width(1))
	if lit:
		draw_circle(CENTER, RADIUS + 7.0, SchematicTheme.LAMP_GLOW)
		draw_circle(CENTER, RADIUS, SchematicTheme.LAMP_ON)
	draw_arc(CENTER, RADIUS, 0.0, TAU, 32, color, width)
	var d: float = RADIUS * 0.7071
	draw_line(CENTER + Vector2(-d, -d), CENTER + Vector2(d, d), color, SchematicTheme.LINE_WIDTH)
	draw_line(CENTER + Vector2(-d, d), CENTER + Vector2(d, -d), color, SchematicTheme.LINE_WIDTH)
