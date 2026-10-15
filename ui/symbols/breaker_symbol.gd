class_name BreakerSymbol
extends SchematicSymbol
## Circuit breaker (IEC 60617 S00287) with thermal (bimetal) and magnetic
## releases, 1-4 poles, drawn as in the guide: each blade pivots at the lower
## terminal (2, 4, 6, 8) and stands off to the left of the fixed contact with
## the cross below the upper terminal (1, 3, 5, 7); several poles are joined
## by a dashed link. Click to switch it; a trip shows in the warning colour
## until it is switched on again.

## Fixed contact (with the cross) below the upper terminal.
const FIXED_END := Vector2(0, 18)
## Blade pivot above the lower terminal.
const PIVOT := Vector2(0, 42)
const OPEN_TIP := Vector2(-10, 18)
const CLOSED_TIP := Vector2(-2, 18)
const CROSS: float = 3.5
## Height of the dashed link.
const LINK_Y: float = 30.0
## Thermal release: a step on the left of the blade, joined to it at [constant THERMAL_Y].
const THERMAL_Y: float = 26.5
const THERMAL: PackedVector2Array = [Vector2(-9, 26.5), Vector2(-9, 23), Vector2(-14.5, 23), Vector2(-14.5, 27.5), Vector2(-19, 27.5)]
## Magnetic release: an isosceles triangle pointing left, away from the
## blade; the middle of its base is joined to the blade at [constant MAGNETIC_Y].
const MAGNETIC_Y: float = 35.5
const MAGNETIC: PackedVector2Array = [Vector2(-11, 31.5), Vector2(-19, 35.5), Vector2(-11, 39.5), Vector2(-11, 31.5)]


func is_interactive() -> bool:
	return true


func _designation_anchor() -> Vector2:
	return Vector2(-1.4 * G, 1.5 * G)


func _draw_shape(_color: Color, _width: float) -> void:
	var closed: bool
	var tripped: bool
	if component is MotorBreaker:
		closed = (component as MotorBreaker).is_path_closed(0)
		tripped = (component as MotorBreaker).tripped
	else:
		closed = (component as CircuitBreaker).is_closed()
		tripped = (component as CircuitBreaker).tripped
	var poles: int = component.get_terminal_names().size() / 2
	var tip: Vector2 = CLOSED_TIP if closed else OPEN_TIP
	# The releases and the link are insulated from the poles: never live.
	var mark: Color = SchematicTheme.WARNING if warning or tripped else SchematicTheme.LINE
	var thin: float = SchematicTheme.LINE_WIDTH * 0.8
	for pole: int in poles:
		var x: Vector2 = Vector2(pole_x(pole), 0)
		var top: int = pole * 2
		var bottom: int = top + 1
		draw_line(x, x + FIXED_END, lead_color(top), lead_width(top))
		var f: Vector2 = x + FIXED_END
		draw_line(f + Vector2(-CROSS, -CROSS), f + Vector2(CROSS, CROSS), lead_color(top), SchematicTheme.LINE_WIDTH)
		draw_line(f + Vector2(-CROSS, CROSS), f + Vector2(CROSS, -CROSS), lead_color(top), SchematicTheme.LINE_WIDTH)
		draw_line(x + Vector2(0, 3 * G), x + PIVOT, lead_color(bottom), lead_width(bottom))
		var blade: Color = SchematicTheme.WARNING if tripped else lead_color(bottom)
		draw_blade(x + PIVOT, x + tip, blade, lead_width(bottom))
		var thermal: PackedVector2Array = PackedVector2Array([x + Vector2(_blade_x(tip, THERMAL_Y), THERMAL_Y)])
		for p: Vector2 in THERMAL:
			thermal.append(x + p)
		draw_polyline(thermal, mark, thin)
		var magnetic: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in MAGNETIC:
			magnetic.append(x + p)
		draw_polyline(magnetic, mark, thin)
		draw_line(x + Vector2(MAGNETIC[0].x, MAGNETIC_Y), x + Vector2(_blade_x(tip, MAGNETIC_Y), MAGNETIC_Y), mark, thin)
	# The link runs from each blade to the releases of the next pole, never
	# across them.
	var release_left: float = minf(THERMAL[THERMAL.size() - 1].x, MAGNETIC[1].x) - 2.0
	for pole: int in range(poles - 1):
		var from: Vector2 = Vector2(pole_x(pole) + _blade_x(tip, LINK_Y) + 1.0, LINK_Y)
		var to: Vector2 = Vector2(pole_x(pole + 1) + release_left, LINK_Y)
		if to.x > from.x:
			draw_dashed_line(from, to, mark, 1.5, 3.0)


func _draw_labels() -> void:
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	_draw_pole_labels()


## X of the blade at height [param y] for a blade ending at [param tip].
static func _blade_x(tip: Vector2, y: float) -> float:
	return PIVOT.x + (tip.x - PIVOT.x) * (PIVOT.y - y) / (PIVOT.y - tip.y)
