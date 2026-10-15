class_name MotorBreakerSymbol
extends SchematicSymbol
## Three-pole motor protective breaker (IEC 60617 S00287 poles with the cross
## at the fixed contact), poles joined by a dashed link to the manual
## actuator. Click to switch it; a trip shows in the warning colour.

const PIVOT := Vector2(0, 20)
const FIXED_END := Vector2(0, 40)


func is_interactive() -> bool:
	return true


func _designation_anchor() -> Vector2:
	return Vector2(-1.9 * G, 1.5 * G)


func _draw_shape(_color: Color, _width: float) -> void:
	var breaker: MotorBreaker = component as MotorBreaker
	var closed: bool = breaker.is_path_closed(0)
	var middles: PackedVector2Array = PackedVector2Array()
	for pole: int in 3:
		var x: Vector2 = Vector2(pole_x(pole), 0)
		var top: int = pole * 2
		var bottom: int = top + 1
		draw_line(x, x + PIVOT, lead_color(top), lead_width(top))
		draw_line(x + Vector2(0, 3 * G), x + FIXED_END, lead_color(bottom), lead_width(bottom))
		var s: float = 4.0
		var cross: Color = lead_color(bottom)
		var f: Vector2 = x + FIXED_END
		draw_line(f + Vector2(-s, -s), f + Vector2(s, s), cross, SchematicTheme.LINE_WIDTH)
		draw_line(f + Vector2(-s, s), f + Vector2(s, -s), cross, SchematicTheme.LINE_WIDTH)
		var tip: Vector2 = x + (Vector2(-3, 40) if closed else Vector2(-13, 42))
		var blade: Color = SchematicTheme.WARNING if breaker.tripped else lead_color(top)
		draw_line(x + PIVOT, tip, blade, lead_width(top))
		middles.append((x + PIVOT).lerp(tip, 0.5))
	var head_x: float = -26.0
	var y: float = middles[0].y
	draw_dashed_line(Vector2(head_x, y), middles[2] - Vector2(1, 0), SchematicTheme.LINE, 1.5, 3.0)
	draw_line(Vector2(head_x, y - 6), Vector2(head_x, y + 6), SchematicTheme.LINE, SchematicTheme.LINE_WIDTH)


func _draw_labels() -> void:
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	_draw_pole_labels()
