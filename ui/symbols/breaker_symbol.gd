class_name BreakerSymbol
extends SchematicSymbol
## Circuit breaker (IEC 60617 S00287): switch with a cross at the fixed
## contact and a manual actuator. Click to switch it; a trip shows in the
## warning colour until it is switched on again.

## Pivot at the top terminal, fixed contact with the cross below (as the
## contacts are drawn).
const PIVOT := Vector2(0, 20)
const FIXED_END := Vector2(0, 40)


func is_interactive() -> bool:
	return true


func _designation_anchor() -> Vector2:
	return Vector2(-1.9 * G, 1.5 * G)


func _draw_shape(_color: Color, _width: float) -> void:
	var breaker: CircuitBreaker = component as CircuitBreaker
	var closed: bool = breaker.is_closed()
	draw_line(Vector2(0, 0), PIVOT, lead_color(0), lead_width(0))
	draw_line(Vector2(0, 3 * G), FIXED_END, lead_color(1), lead_width(1))
	var x_size: float = 4.0
	var cross: Color = lead_color(1)
	draw_line(FIXED_END + Vector2(-x_size, -x_size), FIXED_END + Vector2(x_size, x_size), cross, SchematicTheme.LINE_WIDTH)
	draw_line(FIXED_END + Vector2(-x_size, x_size), FIXED_END + Vector2(x_size, -x_size), cross, SchematicTheme.LINE_WIDTH)
	var tip: Vector2 = Vector2(-3, 40) if closed else Vector2(-13, 42)
	var blade: Color = SchematicTheme.WARNING if breaker.tripped else lead_color(0)
	draw_line(PIVOT, tip, blade, lead_width(0))
	var middle: Vector2 = PIVOT.lerp(tip, 0.5)
	var head_x: float = -26.0
	draw_dashed_line(Vector2(head_x, middle.y), Vector2(middle.x - 1.0, middle.y), SchematicTheme.LINE, 1.5, 3.0)
	draw_line(Vector2(head_x, middle.y - 6), Vector2(head_x, middle.y + 6), SchematicTheme.LINE, SchematicTheme.LINE_WIDTH)
