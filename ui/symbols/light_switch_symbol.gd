class_name LightSwitchSymbol
extends SchematicSymbol
## Light switch of a house installation (see [LightSwitch]), drawn as on
## Czech wiring diagrams after ČSN EN 60669-1: a box with its terminals as
## small circles inside, the incoming ones on top and the outgoing ones
## below, and a lever from each incoming terminal to the contact it touches
## (a one-way lever stands off its contact while off; switch 4's points at
## the stop between its contacts while off). The levers of one rocker are
## joined by a dashed link. The intermediate switch (7) has a lever from each
## of 1 and 3; the contacts below are bridged so that at rest 1 reaches 2 and
## 3 reaches 4, switched over 1 reaches 4 (by the U bridge) and 3 reaches 2
## (by the straight one). A circle and the lever from it take the colour of
## the voltage that reaches them while simulating (filled), hollow while
## nothing does. Click it while simulating to switch the rocker clicked over.

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
		"2", "3", "03":
			var tips: PackedVector2Array = PackedVector2Array()
			for p: int in sw.poles():
				tips.append(_blade(2 * p, _one_way_tip(2 * p, 2 * p + 1, sw.on[0], "pole%d" % p)))
			_link(_circle(0), tips[0], _circle(2 * tips.size() - 2), tips[tips.size() - 1])
		"4":
			# Off, the lever points at the stop between its contacts.
			var stop: Vector2 = Vector2(G, BOTTOM_Y)
			var target: float = 0.5 if sw.position == LightSwitch.OFF else (0.0 if sw.position == 1 else 1.0)
			_draw_circle(stop, REACH_NONE)
			_blade(0, blade_tip(_circle(0), _circle(1), _circle(2), shown("a", target)))
		"5":
			_blade(0, _one_way_tip(0, 1, sw.on[0], "a"))
			_blade(0, _one_way_tip(0, 2, sw.on[1], "b"))
		"6":
			_blade(0, _two_way_tip(_circle(0), _circle(1), _circle(2), sw.on[0], "a"))
		"5B":
			_blade(0, _two_way_tip(_circle(0), _circle(1), _circle(2), sw.on[0], "a"))
			_blade(3, _two_way_tip(_circle(3), _circle(4), _circle(5), sw.on[1], "b"))
		"6/2":
			var first: Vector2 = _blade(0, _two_way_tip(_circle(0), _circle(2), _circle(4), sw.on[0], "a"))
			var second: Vector2 = _blade(1, _two_way_tip(_circle(1), _circle(3), _circle(5), sw.on[0], "b"))
			_link(_circle(0), first, _circle(1), second)
		"7":
			_intermediate()
		_:
			_blade(0, _one_way_tip(0, 1, sw.on[0], "a"))
	for i: int in component.get_terminal_names().size():
		_draw_circle(_circle(i), reach(i))


## The dashed link between the first lever (from [param a] to [param a_tip])
## and the last (from [param b] to [param b_tip]), at the link's height.
func _link(a: Vector2, a_tip: Vector2, b: Vector2, b_tip: Vector2) -> void:
	if a.is_equal_approx(b):
		return
	var mark: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	aa_dashed_line(_on_blade(a, a_tip, LINK_Y), _on_blade(b, b_tip, LINK_Y), mark, 1.4, 2.5)


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


## The intermediate switch: blades from 1 and 2; the crossing contacts
## bridged to 3 (straight) and to 4 (the U under the others).
func _intermediate() -> void:
	var over: bool = _switch().on[0]
	var s: float = shown("blades", 1.0 if over else 0.0)
	# The outputs 2 (below 1) and 4 (below 3).
	var two: Vector2 = _circle(1)
	var four: Vector2 = _circle(3)
	var cross_left: Vector2 = Vector2(CROSS_LEFT_X, CROSS_Y)
	var cross_right: Vector2 = Vector2(CROSS_RIGHT_X, CROSS_Y)
	aa_line(two + Vector2(RADIUS, 0), cross_right - Vector2(RADIUS, 0), _live_color(reach(1)), SchematicTheme.LINE_WIDTH)
	aa_polyline(PackedVector2Array([cross_left + Vector2(0, RADIUS), Vector2(CROSS_LEFT_X, BRIDGE_Y), Vector2(four.x, BRIDGE_Y), four + Vector2(0, RADIUS)]), _live_color(reach(3)), SchematicTheme.LINE_WIDTH)
	_blade(0, blade_tip(_circle(0), two, cross_left, s))
	_blade(2, blade_tip(_circle(2), four, cross_right, s))
	_draw_circle(cross_left, reach(3))
	_draw_circle(cross_right, reach(1))


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
		if sw.circuit == "7" and (i == 1 or i == 3):
			at.y = (CROSS_Y + BRIDGE_Y) * 0.5
		draw_label(names[i], at + Vector2(0.3 * G, 0), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)


## Mounting height as written beside a part of a house installation whose
## height is not the standard one, e.g. "h = 1.10 m".
static func height_text(height: float) -> String:
	return "h = %s m" % String.num(height, 2).pad_decimals(2)
