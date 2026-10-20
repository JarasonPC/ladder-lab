class_name RcdSymbol
extends BreakerSymbol
## Residual current device (IEC 60617 S00290 family) or arc fault detection
## device: the poles as a circuit breaker's (an RCD without overcurrent
## release as plain switch blades), the dashed link to a release box on the
## right: an RCD's says IΔ and is worked by the summation transformer, a ring
## round all its pole leads under the blades; an AFDD's holds an arc. The
## box takes the warning colour after a trip, as the releases do.

## The summation transformer's ring round the leads under the pivots.
const RING_Y: float = 47.0
const RING_HEIGHT: float = 5.0
## The release box beside the last pole.
const BOX := Rect2(14, 22, 22, 16)


func _plain() -> bool:
	return component is ResidualCurrentDevice and not (component as ResidualCurrentDevice).overcurrent


func _box() -> Rect2:
	var poles: int = component.get_terminal_names().size() / 2
	return Rect2(BOX.position + Vector2(pole_x(poles - 1), 0), BOX.size)


func _draw_shape(color: Color, width: float) -> void:
	var device: MotorBreaker = component as MotorBreaker
	var poles: int = component.get_terminal_names().size() / 2
	var mark: Color = SchematicTheme.WARNING if warning or device.tripped else SchematicTheme.LINE
	var tip: Vector2 = blade_tip(PIVOT, CLOSED_TIP, OPEN_TIP, shown("blade", 0.0 if device.is_path_closed(0) else 1.0))
	if _plain():
		# Switch blades without the breaker's cross and releases.
		for pole: int in poles:
			var x: Vector2 = Vector2(pole_x(pole), 0)
			aa_line(x, x + FIXED_END, lead_color(2 * pole), lead_width(2 * pole))
			aa_line(x + Vector2(0, 3 * G), x + PIVOT, lead_color(2 * pole + 1), lead_width(2 * pole + 1))
			draw_blade(x + PIVOT, x + tip, SchematicTheme.WARNING if device.tripped else lead_color(2 * pole + 1), lead_width(2 * pole + 1))
		for pole: int in range(poles - 1):
			aa_dashed_line(Vector2(pole_x(pole) + _blade_x(tip, LINK_Y) + 1.0, LINK_Y), Vector2(pole_x(pole + 1) + _blade_x(tip, LINK_Y) - 1.0, LINK_Y), mark, 1.5, 3.0)
	else:
		super(color, width)
	var box: Rect2 = _box()
	var last: float = pole_x(poles - 1) + _blade_x(tip, LINK_Y)
	aa_dashed_line(Vector2(last + 1.0, LINK_Y), Vector2(box.position.x, LINK_Y), mark, 1.5, 3.0)
	aa_rect(box, SchematicTheme.BACKGROUND)
	aa_rect(box, mark, false, SchematicTheme.LINE_WIDTH * 0.8)
	if component is ResidualCurrentDevice:
		# The summation transformer round every pole lead, wired to the box.
		var left: float = -6.0
		var right: float = pole_x(poles - 1) + 6.0
		var center: Vector2 = Vector2((left + right) * 0.5, RING_Y)
		var radii: Vector2 = Vector2((right - left) * 0.5, RING_HEIGHT * 0.5)
		var ring: PackedVector2Array = PackedVector2Array()
		for k: int in 33:
			ring.append(center + Vector2(cos(TAU * k / 32.0) * radii.x, sin(TAU * k / 32.0) * radii.y))
		aa_polyline(ring, mark, SchematicTheme.LINE_WIDTH * 0.8)
		aa_polyline(PackedVector2Array([Vector2(right, RING_Y), Vector2(box.get_center().x, RING_Y), Vector2(box.get_center().x, box.end.y)]), mark, SchematicTheme.LINE_WIDTH * 0.8)
	else:
		# An arc between two electrodes.
		var c: Vector2 = box.get_center()
		aa_polyline(PackedVector2Array([c + Vector2(-7, 0), c + Vector2(-4, 0), c + Vector2(-1, -4), c + Vector2(1, 4), c + Vector2(4, 0), c + Vector2(7, 0)]), mark, SchematicTheme.LINE_WIDTH * 0.8)


func _draw_labels() -> void:
	var anchor: Vector2 = _designation_anchor()
	draw_label(designation_text(), anchor, SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	# The lower numbers under the ring.
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in names.size():
		var x: float = (i / 2) * SymbolGeometry.POLE_SPACING * G + 0.3 * G
		draw_label(names[i], Vector2(x, 0.4 * G if i % 2 == 0 else 2.8 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(rating_text(component), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
	if component is ResidualCurrentDevice:
		write_in("IΔ", _box(), SchematicTheme.TERMINAL_SIZE)
	if not _plain():
		draw_heat((component as MotorBreaker).heat.progress, anchor, 2)


## What is written on the device: "40 A 30 mA A", an RCBO "B16 30 mA A", an
## AFDD "AFDD B16".
static func rating_text(c: CircuitComponent) -> String:
	if c is ResidualCurrentDevice:
		var rcd: ResidualCurrentDevice = c as ResidualCurrentDevice
		var current: String = CircuitBreaker.rating_text(rcd.characteristic, rcd.rated_current) if rcd.overcurrent else Fuse.amperes_text(rcd.rated_current) + " A"
		return "%s %d mA %s" % [current, roundi(rcd.residual_rating * 1000.0), rcd.type]
	var afdd: MotorBreaker = c as MotorBreaker
	return "AFDD " + CircuitBreaker.rating_text(afdd.characteristic, afdd.rated_current)
