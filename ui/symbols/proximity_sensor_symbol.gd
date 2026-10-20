class_name ProximitySensorSymbol
extends SchematicSymbol
## Proximity sensor: a box holding the proximity actuator (a rhombus, IEC
## 60617 S00369) with the mark of what it senses beside it ("Fe" inductive,
## a capacitor capacitive, light arrows optical, a magnet magnetic) and,
## worked by it on a dashed link, the contact of each output (NO or NC,
## pivoting at the bottom like every contact) under its lead; "PNP" or "NPN"
## under the rhombus. Supply 1 (L+) on top, 3 (M) below, the output 4 on
## top beside 1 and the second output 2 of the antivalent version beyond
## it; the colours of the cores (BN, BU, BK, WH) beside the leads. The box
## is filled while it has its supply, the rhombus while it detects
## something; while simulating a click puts something in front of it or
## takes it away. The palette shows the rhombus and the contact.

const BOX_TOP: float = 0.8 * G
const BOX_BOTTOM: float = 2.2 * G
const BOX_LEFT: float = -0.8 * G
## Right edge of the box beyond the last output's lead.
const BOX_RIGHT_MARGIN: float = 0.8 * G
const RHOMBUS_CENTER := Vector2(-2.0, 27.0)
const RHOMBUS_HALF := Vector2(7.0, 8.0)
## Where the sensing mark sits, right of the rhombus, over the link.
const MARK_AT := Vector2(17.0, 20.5)
const TYPE_AT := Vector2(-2.0, 39.5)
## A contact under its lead (x offset from the lead): fixed contact down
## from the box, the pivot near its bottom.
const FIXED_END: float = 22.0
const PIVOT_Y: float = 38.0
const OPEN_TIP := Vector2(-8.0, 23.0)
const NO_CLOSED_TIP := Vector2(0.0, 21.0)
const NC_CLOSED_TIP := Vector2(6.0, 23.0)
const NC_OPEN_TIP := Vector2(11.0, 26.5)
const HOOK: float = 6.0
const PREVIEW_BOX := Rect2(0.0, 0.0, 100.0, 50.0)


func preview_rect() -> Rect2:
	return PREVIEW_BOX


func is_interactive() -> bool:
	return true


func _box() -> Rect2:
	var outputs: int = component.get_terminal_names().size() - 2
	var right: float = SymbolGeometry.SENSOR_OUTPUT_CELL.x * G * outputs + BOX_RIGHT_MARGIN
	return Rect2(BOX_LEFT, BOX_TOP, right - BOX_LEFT, BOX_BOTTOM - BOX_TOP)


func _draw_shape(color: Color, width: float) -> void:
	var sensor: ProximitySensor = component as ProximitySensor
	if preview:
		_draw_preview(color, width)
		return
	var box: Rect2 = _box()
	aa_line(Vector2.ZERO, Vector2(0, BOX_TOP), lead_color(0), lead_width(0))
	aa_line(Vector2(0, BOX_BOTTOM), Vector2(0, SymbolGeometry.SPAN * G), lead_color(1), lead_width(1))
	if sensor.energized:
		aa_rect(box, SchematicTheme.COIL_ON)
	aa_rect(box, color, false, width)
	_draw_rhombus(RHOMBUS_CENTER, RHOMBUS_HALF, color, width, sensor.detecting)
	_draw_mark(sensor.sensing, MARK_AT, 1.0, color, width)
	var link_to: Vector2 = Vector2(RHOMBUS_CENTER.x + RHOMBUS_HALF.x, RHOMBUS_CENTER.y)
	for k: int in sensor.output_count():
		var x: float = SymbolGeometry.SENSOR_OUTPUT_CELL.x * G * (k + 1)
		aa_line(Vector2(x, 0), Vector2(x, BOX_TOP), lead_color(2 + k), lead_width(2 + k))
		link_to = _draw_contact(sensor, k, x, color, width)
	# The link from the rhombus to the farthest contact's blade.
	aa_dashed_line(Vector2(RHOMBUS_CENTER.x + RHOMBUS_HALF.x, RHOMBUS_CENTER.y), link_to, color, 1.0, 2.0)


## Contact of output [param k] under its lead at [param x]; returns the
## middle of its blade, where the link reaches it.
func _draw_contact(sensor: ProximitySensor, k: int, x: float, color: Color, width: float) -> Vector2:
	var opener: bool = sensor.function == ProximitySensor.Function.NC or k == 1
	var pivot: Vector2 = Vector2(x, PIVOT_Y)
	aa_line(Vector2(x, BOX_TOP), Vector2(x, FIXED_END), color, width)
	aa_line(pivot, Vector2(x, BOX_BOTTOM - 2.0), color, width)
	# 1 operated: an NO closed, an NC open (heading there smoothly); at rest
	# without its supply, as drawings show it.
	var operated: float = shown("output%d" % k, 1.0 if sensor.energized and sensor.output_on(k) != opener else 0.0)
	var tip: Vector2
	if opener:
		aa_line(Vector2(x, FIXED_END), Vector2(x + HOOK, FIXED_END), color, width)
		tip = blade_tip(pivot, Vector2(x, 0) + NC_CLOSED_TIP, Vector2(x, 0) + NC_OPEN_TIP, operated)
	else:
		tip = blade_tip(pivot, Vector2(x, 0) + OPEN_TIP, Vector2(x, 0) + NO_CLOSED_TIP, operated)
	draw_blade(pivot, tip, color, width)
	var y: float = RHOMBUS_CENTER.y
	return Vector2(pivot.x + (tip.x - pivot.x) * (pivot.y - y) / (pivot.y - tip.y), y)


func _draw_rhombus(center: Vector2, half: Vector2, color: Color, width: float, filled: bool) -> void:
	var points: PackedVector2Array = PackedVector2Array([center + Vector2(0, -half.y), center + Vector2(half.x, 0), center + Vector2(0, half.y), center + Vector2(-half.x, 0), center + Vector2(0, -half.y)])
	if filled:
		aa_polygon(points.slice(0, 4), color)
	aa_polyline(points, color, width)


## The mark of what it senses, centred at [param at], [param scale] times
## its size on the drawing ("Fe" is written by [method _draw_labels]).
func _draw_mark(sensing: ProximitySensor.Sensing, at: Vector2, scale: float, color: Color, width: float) -> void:
	match sensing:
		ProximitySensor.Sensing.CAPACITIVE:
			for dx: float in [-1.8, 1.8]:
				aa_line(at + Vector2(dx, -4.0) * scale, at + Vector2(dx, 4.0) * scale, color, width)
			aa_line(at + Vector2(-6.0, 0.0) * scale, at + Vector2(-1.8, 0.0) * scale, color, width)
			aa_line(at + Vector2(1.8, 0.0) * scale, at + Vector2(6.0, 0.0) * scale, color, width)
		ProximitySensor.Sensing.OPTICAL:
			# Two rays falling on the rhombus.
			for dy: float in [-2.5, 2.5]:
				var from: Vector2 = at + Vector2(6.0, dy - 3.0) * scale
				var to: Vector2 = at + Vector2(-5.0, dy + 2.0) * scale
				aa_line(from, to, color, width * 0.8)
				var back: Vector2 = (from - to).normalized() * 3.0 * scale
				aa_polyline(PackedVector2Array([to + back.rotated(0.5), to, to + back.rotated(-0.5)]), color, width * 0.8)
		ProximitySensor.Sensing.MAGNETIC:
			# A bar magnet, its north half filled.
			var bar: Rect2 = Rect2(at + Vector2(-6.0, -2.5) * scale, Vector2(12.0, 5.0) * scale)
			aa_rect(Rect2(bar.position, Vector2(bar.size.x * 0.5, bar.size.y)), color)
			aa_rect(bar, color, false, width)


func _draw_preview(color: Color, width: float) -> void:
	var sensor: ProximitySensor = component as ProximitySensor
	aa_rect(PREVIEW_BOX, color, false, width)
	_draw_rhombus(Vector2(22.0, 25.0), Vector2(12.0, 14.0), color, width, false)
	if sensor.sensing != ProximitySensor.Sensing.INDUCTIVE:
		_draw_mark(sensor.sensing, Vector2(46.0, 13.0), 1.4, color, width)
	# An NO contact worked by it.
	aa_line(Vector2(80.0, 4.0), Vector2(80.0, 14.0), color, width)
	aa_line(Vector2(80.0, 40.0), Vector2(80.0, 46.0), color, width)
	draw_blade(Vector2(80.0, 40.0), Vector2(68.0, 16.0), color, width)
	aa_dashed_line(Vector2(34.0, 25.0), Vector2(73.5, 27.0), color, 1.4, 3.0)
	if sensor.sensing == ProximitySensor.Sensing.INDUCTIVE:
		draw_preview_text("Fe", Vector2(46.0, 12.0), 14)


func _draw_labels() -> void:
	var sensor: ProximitySensor = component as ProximitySensor
	var names: PackedStringArray = component.get_terminal_names()
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	draw_label(names[0], name_anchor(0, Vector2(0.35 * G, 0.4 * G)), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[1], name_anchor(1, Vector2(0.35 * G, 2.6 * G)), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	for k: int in sensor.output_count():
		var x: float = SymbolGeometry.SENSOR_OUTPUT_CELL.x * G * (k + 1)
		draw_label(names[2 + k], name_anchor(2 + k, Vector2(x + 0.35 * G, 0.4 * G)), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	# The colours of the cores beside the leads, away from the terminal numbers.
	for i: int in names.size():
		var colour: String = sensor.core_colour(i)
		if colour.is_empty() or placement.strips.has(i):
			continue
		var cell: Vector2 = Vector2(SymbolGeometry.local_terminals(component)[names[i]]) * G
		_centered(colour, Vector2(cell.x - 0.6 * G, 2.6 * G if i == 1 else 0.4 * G), SchematicTheme.TERMINAL_SIZE - 1)
	if sensor.sensing == ProximitySensor.Sensing.INDUCTIVE:
		_centered("Fe", MARK_AT, 8)
	_centered(ProximitySensor.OUTPUT_TEXTS[sensor.output], TYPE_AT, 7)
	draw_rating(_designation_anchor(), 1)


func _designation_anchor() -> Vector2:
	# Clear of the colour of the lower core.
	return Vector2(-1.6 * G if placement.strips.has(1) else -1.4 * G, 1.5 * G)


## Upright text centred on local point [param at].
func _centered(text: String, at: Vector2, font_size: int) -> void:
	var font: Font = AppTheme.schematic_font()
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var c: Vector2 = to_upright(at)
	var pos: Vector2 = c + Vector2(-size.x * 0.5, font.get_ascent(font_size) * 0.5 - 1.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, SchematicTheme.TEXT)
	text_rects.append(Rect2(Vector2(pos.x, pos.y - font.get_ascent(font_size)), size))
