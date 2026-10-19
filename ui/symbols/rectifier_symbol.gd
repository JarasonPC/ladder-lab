class_name RectifierSymbol
extends SchematicSymbol
## Full bridge rectifier: a box with the bridge of four diodes (diodes as in
## IEC 60617) inside, AC input ~1 ~2 on top, DC output + - below. Filled
## while its input has voltage, like a running motor.

const BOX := Rect2(-4, 10, 48, 40)
const BRIDGE_CENTER := Vector2(20, 30)
## Half diagonals of the bridge: a square standing on its corner.
const BRIDGE_SIZE := Vector2(14, 14)


func _draw_shape(color: Color, width: float) -> void:
	var on: bool = (component as Load).energized
	for i: int in 4:
		var x: float = (i % 2) * SymbolGeometry.POLE_SPACING * G
		if i < 2:
			aa_line(Vector2(x, 0), Vector2(x, BOX.position.y), lead_color(i), lead_width(i))
		else:
			aa_line(Vector2(x, BOX.end.y), Vector2(x, SymbolGeometry.SPAN * G), lead_color(i), lead_width(i))
	if on:
		aa_rect(BOX, SchematicTheme.COIL_ON)
	aa_rect(BOX, color, false, width)
	# The bridge: AC on the left and right corners, + on top, - below; every
	# diode conducts towards the + corner.
	var left: Vector2 = BRIDGE_CENTER + Vector2(-BRIDGE_SIZE.x, 0)
	var right: Vector2 = BRIDGE_CENTER + Vector2(BRIDGE_SIZE.x, 0)
	var top: Vector2 = BRIDGE_CENTER + Vector2(0, -BRIDGE_SIZE.y)
	var bottom: Vector2 = BRIDGE_CENTER + Vector2(0, BRIDGE_SIZE.y)
	for diode: Array in [[bottom, left], [left, top], [bottom, right], [right, top]]:
		_draw_diode(diode[0], diode[1], color)


## One side of the bridge with a diode in its middle, anode at [param from].
func _draw_diode(from: Vector2, to: Vector2, color: Color) -> void:
	aa_line(from, to, color, 1.2)
	var along: Vector2 = (to - from).normalized()
	var across: Vector2 = Vector2(-along.y, along.x)
	var middle: Vector2 = (from + to) * 0.5
	var tip: Vector2 = middle + along * 3.0
	var back: Vector2 = middle - along * 3.0
	aa_polygon(PackedVector2Array([tip, back + across * 3.5, back - across * 3.5]), color)
	aa_line(tip + across * 3.5, tip - across * 3.5, color, 1.2)


func _draw_labels() -> void:
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in names.size():
		var x: float = (i % 2) * SymbolGeometry.POLE_SPACING * G + 0.3 * G
		var y: float = 0.22 * G if i < 2 else 2.78 * G
		draw_label(names[i], name_anchor(i, Vector2(x, y)), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
