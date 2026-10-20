class_name LightSwitchSymbol
extends SchematicSymbol
## Light switch of a house installation (see [LightSwitch]), drawn as on
## Czech wiring diagrams: a box with its terminals as small circles inside,
## the common P on top and the outputs below, and a blade from P to the
## contact it touches (a one-way blade stands off its contact while off).
## Rockers switching two ways move their blade from one contact to the other.
## The intermediate switch (7) has a blade from each of 1 and 2 on top; the
## contacts below are bridged so that at rest 1 reaches 3 and 2 reaches 4,
## switched over 1 reaches 4 (by the U bridge) and 2 reaches 3 (by the
## straight one). A circle and the blade from it take the colour of the
## voltage that reaches them while simulating (filled), hollow while nothing
## does. Click it while simulating to switch the rocker clicked over.

## Rows of the circles: the commons on top, the contacts below; the
## intermediate switch's contacts a little higher, the U bridge under them.
const TOP_Y: float = 16.0
const BOTTOM_Y: float = 44.0
const CROSS_Y: float = 36.0
const BRIDGE_Y: float = 51.0
const RADIUS: float = 3.5
## A one-way lever while off: turned a little (radians) outward off its
## contact and lifted short of it, a clear gap before the contact.
const OFF_TURN: float = 0.25
const OFF_LENGTH: float = 0.7
## The lever: a thick bar with a round knob at its free end.
const LEVER_WIDTH: float = 2.6
const KNOB: float = 2.4
## Height of the dashed link between the blades of a multi-pole switch.
const LINK_Y: float = 30.0
## Intermediate switch: where the crossing contacts are, left of 3 and right
## of the middle.
const CROSS_LEFT_X: float = -16.0
const CROSS_RIGHT_X: float = 24.0


func is_interactive() -> bool:
	return true


func _switch() -> LightSwitch:
	return component as LightSwitch


func _designation_anchor() -> Vector2:
	return Vector2(SymbolGeometry.light_switch_box(_switch()).position.x - 0.15 * G, 1.5 * G)


## Local point of the circle of terminal [param index] inside the box.
func _circle(index: int) -> Vector2:
	var cell: Vector2i = SymbolGeometry.light_switch_cell(_switch(), index)
	var y: float = TOP_Y if cell.y == 0 else (CROSS_Y if _switch().circuit == "7" else BOTTOM_Y)
	return Vector2(cell.x * G, y)


func _draw_shape(_color: Color, width: float) -> void:
	var sw: LightSwitch = _switch()
	aa_rect(SymbolGeometry.light_switch_box(sw), SchematicTheme.BACKGROUND)
	if hovered and sw.rocker_count() > 1:
		# The half of the rocker a click switches.
		var box: Rect2 = SymbolGeometry.light_switch_box(sw)
		var split: float = (SymbolGeometry.light_switch_pivots(sw, 0)[0] + SymbolGeometry.light_switch_pivots(sw, 1)[0]) * 0.5
		var mouse: Vector2 = shape_transform().affine_inverse() * get_local_mouse_position()
		var left: bool = SymbolGeometry.light_switch_rocker_at(sw, mouse.x) == 0
		var half: Rect2 = Rect2(box.position, Vector2(split - box.position.x, box.size.y)) if left else Rect2(Vector2(split, box.position.y), Vector2(box.end.x - split, box.size.y))
		aa_rect(half, SchematicTheme.HOVER)
	aa_rect(SymbolGeometry.light_switch_box(sw), SchematicTheme.WARNING if warning else SchematicTheme.LINE, false, width)
	# Leads from the terminals in to their circles.
	for i: int in component.get_terminal_names().size():
		var cell: Vector2i = SymbolGeometry.light_switch_cell(sw, i)
		var at: Vector2 = _circle(i)
		var edge: float = at.y - RADIUS if cell.y == 0 else at.y + RADIUS
		aa_line(Vector2(cell.x * G, cell.y * G), Vector2(at.x, edge), lead_color(i), lead_width(i))
	match sw.circuit:
		"2", "3":
			var tips: PackedVector2Array = PackedVector2Array()
			for p: int in sw.poles():
				tips.append(_blade(2 * p, _one_way_tip(2 * p, 2 * p + 1, sw.on[0], "pole%d" % p)))
			if tips.size() > 1:
				var mark: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
				var a: Vector2 = _on_blade(_circle(0), tips[0], LINK_Y)
				var b: Vector2 = _on_blade(_circle(2 * tips.size() - 2), tips[tips.size() - 1], LINK_Y)
				aa_dashed_line(a, b, mark, 1.4, 2.5)
		"5":
			_blade(0, _one_way_tip(0, 1, sw.on[0], "a"))
			_blade(0, _one_way_tip(0, 2, sw.on[1], "b"))
		"6":
			_blade(0, _two_way_tip(_circle(0), _circle(1), _circle(2), sw.on[0], "a"))
		"5A":
			var second: Vector2 = _common_bar(3.0 * G)
			_blade(0, _one_way_tip(0, 1, sw.on[0], "a"))
			_blade(0, _two_way_tip(second, _circle(2), _circle(3), sw.on[1], "b"), second)
		"5B":
			var second: Vector2 = _common_bar(5.0 * G)
			_blade(0, _two_way_tip(_circle(0), _circle(1), _circle(2), sw.on[0], "a"))
			_blade(0, _two_way_tip(second, _circle(3), _circle(4), sw.on[1], "b"), second)
		"7":
			_intermediate()
		_:
			_blade(0, _one_way_tip(0, 1, sw.on[0], "a"))
	for i: int in component.get_terminal_names().size():
		_draw_circle(_circle(i), reach(i))


## Tip of a one-way blade from terminal [param from] to [param to]: on it
## while [param closed], else standing off it outward.
func _one_way_tip(from: int, to: int, closed: bool, key: String) -> Vector2:
	var start: Vector2 = _circle(from)
	var contact: Vector2 = _circle(to)
	var turn: float = OFF_TURN if contact.x <= start.x else -OFF_TURN
	var off: Vector2 = start + (contact - start).rotated(turn) * OFF_LENGTH
	return blade_tip(start, off, contact, shown(key, 1.0 if closed else 0.0))


## Tip of a two-way blade from [param pivot]: on [param rest] at rest, on
## [param over] switched over.
func _two_way_tip(pivot: Vector2, rest: Vector2, over: Vector2, switched: bool, key: String) -> Vector2:
	return blade_tip(pivot, rest, over, shown(key, 1.0 if switched else 0.0))


## Draws a blade from the circle of terminal [param from] (or [param start])
## to [param tip], ending at the circles' edges; returns the tip.
func _blade(from: int, tip: Vector2, start: Vector2 = Vector2(INF, INF)) -> Vector2:
	var origin: Vector2 = _circle(from) if start.x == INF else start
	var along: Vector2 = (tip - origin).normalized()
	var color: Color = _live_color(reach(from))
	# A lever turning about its pivot: a thick bar to a round knob, which
	# rests on the contact it touches.
	var end: Vector2 = tip - along * RADIUS
	aa_line(origin, end, color, LEVER_WIDTH)
	aa_circle(end, KNOB, color)
	return tip


## The common P joined along the top to a second pivot at [param x] (5A,
## 5B), with its circle. Returns the second pivot.
func _common_bar(x: float) -> Vector2:
	var pivot: Vector2 = Vector2(x, TOP_Y)
	aa_line(_circle(0) + Vector2(RADIUS, 0), pivot - Vector2(RADIUS, 0), _live_color(reach(0)), SchematicTheme.LINE_WIDTH)
	_draw_circle(pivot, reach(0))
	return pivot


## The intermediate switch: blades from 1 and 2; the crossing contacts
## bridged to 3 (straight) and to 4 (the U under the others).
func _intermediate() -> void:
	var over: bool = _switch().on[0]
	var s: float = shown("blades", 1.0 if over else 0.0)
	var three: Vector2 = _circle(2)
	var four: Vector2 = _circle(3)
	var cross_left: Vector2 = Vector2(CROSS_LEFT_X, CROSS_Y)
	var cross_right: Vector2 = Vector2(CROSS_RIGHT_X, CROSS_Y)
	aa_line(three + Vector2(RADIUS, 0), cross_right - Vector2(RADIUS, 0), _live_color(reach(2)), SchematicTheme.LINE_WIDTH)
	aa_polyline(PackedVector2Array([cross_left + Vector2(0, RADIUS), Vector2(CROSS_LEFT_X, BRIDGE_Y), Vector2(four.x, BRIDGE_Y), four + Vector2(0, RADIUS)]), _live_color(reach(3)), SchematicTheme.LINE_WIDTH)
	_blade(0, blade_tip(_circle(0), three, cross_left, s))
	_blade(1, blade_tip(_circle(1), four, cross_right, s))
	_draw_circle(cross_left, reach(3))
	_draw_circle(cross_right, reach(2))


## A terminal circle: filled with the colour of what reaches it, hollow
## while nothing does.
func _draw_circle(at: Vector2, code: int) -> void:
	var color: Color = _live_color(code)
	aa_circle(at, RADIUS, color if code != REACH_NONE else SchematicTheme.BACKGROUND)
	aa_arc(at, RADIUS, 0.0, TAU, 16, color, SchematicTheme.LINE_WIDTH)


## Colour of the parts reached by [param code]; the line colour while
## nothing reaches them.
func _live_color(code: int) -> Color:
	if warning:
		return SchematicTheme.WARNING
	return SchematicTheme.reach_color(code) if code != REACH_NONE else SchematicTheme.LINE


## The point at height [param y] on the line from [param a] to [param b].
static func _on_blade(a: Vector2, b: Vector2, y: float) -> Vector2:
	return a.lerp(b, clampf((y - a.y) / (b.y - a.y), 0.0, 1.0)) if not is_equal_approx(a.y, b.y) else a


func _draw_labels() -> void:
	var sw: LightSwitch = _switch()
	var anchor: Vector2 = _designation_anchor()
	draw_label(designation_text(), anchor, SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	draw_label(tr("No. %s") % sw.circuit, anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
	if not is_equal_approx(sw.height, LightSwitch.STANDARD_HEIGHT):
		draw_label(height_text(sw.height), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 2)
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in names.size():
		var at: Vector2 = _circle(i)
		# Beside its circle, clear of the blades and bars: the common on the
		# left where a bar runs on to the right, the intermediate switch's
		# outputs beside their leads between the bridges.
		var left: bool = sw.circuit in ["5A", "5B"] and i == 0
		if sw.circuit == "7" and i >= 2:
			at.y = (CROSS_Y + BRIDGE_Y) * 0.5
		draw_label(names[i], at + Vector2(-0.3 * G if left else 0.3 * G, 0), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)


## Mounting height as written beside a part of a house installation whose
## height is not the standard one, e.g. "h = 1.10 m".
static func height_text(height: float) -> String:
	return "h = %s m" % String.num(height, 2).pad_decimals(2)
