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
## Both tips as far from the pivot: the blade keeps its length.
const OPEN_TIP := Vector2(-10, 18)
const CLOSED_TIP := Vector2(-2, 16.1)
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


func flips_when_horizontal() -> bool:
	return true


func _closed() -> bool:
	if component is MotorBreaker:
		return (component as MotorBreaker).is_path_closed(0)
	return (component as CircuitBreaker).is_closed()


func is_interactive() -> bool:
	return true


func _designation_anchor() -> Vector2:
	return Vector2(-1.4 * G, 1.5 * G)


func _draw_shape(_color: Color, _width: float) -> void:
	var tripped: bool = (component as MotorBreaker).tripped if component is MotorBreaker else (component as CircuitBreaker).tripped
	var poles: int = component.get_terminal_names().size() / 2
	var opening: float = shown("blade", 0.0 if _closed() else 1.0)
	var tip: Vector2 = blade_tip(PIVOT, CLOSED_TIP, OPEN_TIP, opening)
	# The releases are fixed to the blade: drawn for the closed blade and
	# turned with it about the pivot.
	var turn: float = (tip - PIVOT).angle() - (CLOSED_TIP - PIVOT).angle()
	var on_blade: Callable = func(p: Vector2) -> Vector2:
		return PIVOT + (p - PIVOT).rotated(turn)
	var thermal_local: PackedVector2Array = PackedVector2Array([on_blade.call(Vector2(_blade_x(CLOSED_TIP, THERMAL_Y), THERMAL_Y))])
	for p: Vector2 in THERMAL:
		thermal_local.append(on_blade.call(p))
	var magnetic_local: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in MAGNETIC:
		magnetic_local.append(on_blade.call(p))
	var stub_from: Vector2 = on_blade.call(Vector2(MAGNETIC[0].x, MAGNETIC_Y))
	var stub_to: Vector2 = on_blade.call(Vector2(_blade_x(CLOSED_TIP, MAGNETIC_Y), MAGNETIC_Y))
	var release_left: float = INF
	for p: Vector2 in thermal_local + magnetic_local:
		release_left = minf(release_left, p.x)
	# The releases and the link are insulated from the poles: never live.
	var mark: Color = SchematicTheme.WARNING if warning or tripped else SchematicTheme.LINE
	var thin: float = SchematicTheme.LINE_WIDTH * 0.8
	for pole: int in poles:
		var x: Vector2 = Vector2(pole_x(pole), 0)
		var top: int = pole * 2
		var bottom: int = top + 1
		aa_line(x, x + FIXED_END, lead_color(top), lead_width(top))
		var f: Vector2 = x + FIXED_END
		aa_line(f + Vector2(-CROSS, -CROSS), f + Vector2(CROSS, CROSS), lead_color(top), SchematicTheme.LINE_WIDTH)
		aa_line(f + Vector2(-CROSS, CROSS), f + Vector2(CROSS, -CROSS), lead_color(top), SchematicTheme.LINE_WIDTH)
		aa_line(x + Vector2(0, 3 * G), x + PIVOT, lead_color(bottom), lead_width(bottom))
		var blade: Color = SchematicTheme.WARNING if tripped else lead_color(bottom)
		draw_blade(x + PIVOT, x + tip, blade, lead_width(bottom))
		var thermal: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in thermal_local:
			thermal.append(x + p)
		aa_polyline(thermal, mark, thin)
		var magnetic: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in magnetic_local:
			magnetic.append(x + p)
		aa_polyline(magnetic, mark, thin)
		aa_line(x + stub_from, x + stub_to, mark, thin)
	# The link runs from each blade to the releases of the next pole, never
	# across them.
	release_left -= 2.0
	for pole: int in range(poles - 1):
		var from: Vector2 = Vector2(pole_x(pole) + _blade_x(tip, LINK_Y) + 1.0, LINK_Y)
		var to: Vector2 = Vector2(pole_x(pole + 1) + release_left, LINK_Y)
		if to.x > from.x:
			aa_dashed_line(from, to, mark, 1.5, 3.0)


func _draw_labels() -> void:
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	_draw_pole_labels()
	# Characteristic and rated current as on the breaker, e.g. "C16".
	var rating: String
	var heat: TripCurve
	if component is MotorBreaker:
		var multi: MotorBreaker = component as MotorBreaker
		rating = CircuitBreaker.rating_text(multi.characteristic, multi.rated_current)
		heat = multi.heat
	else:
		var single: CircuitBreaker = component as CircuitBreaker
		rating = CircuitBreaker.rating_text(single.characteristic, single.rated_current)
		heat = single.heat
	draw_label(rating, _designation_anchor(), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
	draw_heat(heat.progress, _designation_anchor(), 2)


## X of the blade at height [param y] for a blade ending at [param tip].
static func _blade_x(tip: Vector2, y: float) -> float:
	return PIVOT.x + (tip.x - PIVOT.x) * (PIVOT.y - y) / (PIVOT.y - tip.y)
