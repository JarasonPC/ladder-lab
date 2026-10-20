class_name LightSwitchSymbol
extends SchematicSymbol
## Light switch of a house installation (see [LightSwitch]), drawn as the
## other contacts: each blade pivots at its lower terminal, the common L
## below (joined along to the second rocker's blade), the outputs above.
## A one-way rocker works an NO blade, a two-way rocker a changeover blade
## between its two outputs; each rocker has a turn head (IEC 60617 S00254)
## on a dashed link, the first on the left, the second on the right. The
## intermediate switch (7) has two changeover blades worked against each
## other, the outputs wired to their stops crosswise. Click it while
## simulating to switch the rocker clicked over.

## Height of the fixed contacts and of the pivots, as on the contacts.
const FIXED_Y: float = 20.0
const PIVOT_Y: float = 40.0
## NO blade: open, standing off toward its head; closed along the fixed contact.
const OPEN_ARM := Vector2(-13, -22)
const CLOSED_ARM := Vector2(0, -25.55)
## Changeover blade: on the stop of either side.
const LEFT_ARM := Vector2(-10, -22)
const RIGHT_ARM := Vector2(10, -22)
const STOP: float = 9.0
## Height of the common joining the blades of one L, and of the dashed links.
const COMMON_Y: float = 50.0
const LINK_Y: float = 30.0
## Intermediate switch (taller, see [constant
## SymbolGeometry.INTERMEDIATE_SPAN]): heights of the bars from 1 and from 2
## to the stops, of the stops, the pivots and the link.
const BAR_ONE_Y: float = 14.0
const BAR_TWO_Y: float = 22.0
const CROSS_STOP_Y: float = 34.0
const CROSS_PIVOT_Y: float = 56.0
const CROSS_LINK_Y: float = 45.0


func is_interactive() -> bool:
	return true


func _switch() -> LightSwitch:
	return component as LightSwitch


func _designation_anchor() -> Vector2:
	var y: float = CROSS_LINK_Y if _switch().circuit == "7" else 1.5 * G
	return Vector2(SymbolGeometry.light_switch_heads(_switch()).x - 0.6 * G, y)


func _draw_shape(_color: Color, _width: float) -> void:
	var sw: LightSwitch = _switch()
	var heads: Vector2 = SymbolGeometry.light_switch_heads(sw)
	match sw.circuit:
		"2", "3":
			var link_x: float = 0.0
			for p: int in sw.poles():
				link_x = _no_blade(p * SymbolGeometry.POLE_SPACING * G, 2 * p, 2 * p + 1, -1.0, sw.on[0])
			_head(heads.x, link_x, sw.on[0], -1.0)
		"5":
			_common(0.0, 2.0 * G)
			_head(heads.x, _no_blade(0.0, 1, 0, -1.0, sw.on[0]), sw.on[0], -1.0)
			_head(heads.y, _no_blade(2.0 * G, 2, 0, 1.0, sw.on[1]), sw.on[1], 1.0)
		"6":
			_head(heads.x, _changeover(G, 1, 2, 0, sw.on[0]), sw.on[0], -1.0)
		"5A":
			_common(0.0, 3.0 * G)
			_head(heads.x, _no_blade(0.0, 1, 0, -1.0, sw.on[0]), sw.on[0], -1.0)
			_head(heads.y, _changeover(3.0 * G, 2, 3, 0, sw.on[1]), sw.on[1], 1.0)
		"5B":
			_common(G, 5.0 * G)
			_head(heads.x, _changeover(G, 1, 2, 0, sw.on[0]), sw.on[0], -1.0)
			_head(heads.y, _changeover(5.0 * G, 3, 4, 0, sw.on[1]), sw.on[1], 1.0)
		"7":
			_intermediate(heads.x)
		_:
			_head(heads.x, _no_blade(0.0, 1, 0, -1.0, sw.on[0]), sw.on[0], -1.0)


## An NO blade at [param x]: the fixed contact down from terminal [param top],
## the pivot on the lead from terminal [param pivot] (the common's lead is
## drawn by [method _common] when the blade is not straight over L), the
## blade standing off to [param side] (-1 left, 1 right) while open. Returns
## the x where the blade crosses the link's height.
func _no_blade(x: float, top: int, pivot: int, side: float, closed: bool) -> float:
	var origin: Vector2 = Vector2(x, PIVOT_Y)
	aa_line(Vector2(x, 0), Vector2(x, FIXED_Y), lead_color(top), lead_width(top))
	if _straight_over(pivot, x):
		_lead(pivot, x)
	var open_arm: Vector2 = Vector2(-OPEN_ARM.x * side, OPEN_ARM.y)
	var tip: Vector2 = blade_tip(origin, origin + open_arm, origin + CLOSED_ARM, shown("blade%d" % top, 1.0 if closed else 0.0))
	draw_blade(origin, tip, lead_color(pivot), lead_width(pivot))
	return _link_x(origin, tip)


## A changeover blade pivoting at [param x] between the stops of terminals
## [param left] (a cell to the left, at rest) and [param right] (a cell to
## the right, switched over). Returns the x where it crosses the link's height.
func _changeover(x: float, left: int, right: int, pivot: int, over: bool) -> float:
	var origin: Vector2 = Vector2(x, PIVOT_Y)
	aa_polyline(PackedVector2Array([Vector2(x - G, 0), Vector2(x - G, FIXED_Y), Vector2(x - STOP, FIXED_Y)]), lead_color(left), lead_width(left))
	aa_polyline(PackedVector2Array([Vector2(x + G, 0), Vector2(x + G, FIXED_Y), Vector2(x + STOP, FIXED_Y)]), lead_color(right), lead_width(right))
	if _straight_over(pivot, x):
		_lead(pivot, x)
	var tip: Vector2 = blade_tip(origin, origin + LEFT_ARM, origin + RIGHT_ARM, shown("blade%d" % left, 1.0 if over else 0.0))
	draw_blade(origin, tip, lead_color(pivot), lead_width(pivot))
	return _link_x(origin, tip)


## The intermediate switch: blades from 3 and 4 between stops wired to 1
## (left of each) and 2 (right of each); at rest 3 on 1 and 4 on 2, switched
## over 3 on 2 and 4 on 1.
func _intermediate(head_x: float) -> void:
	var over: bool = _switch().on[0]
	# 1 to the left stops, 2 to the right stops; the bars cross once.
	aa_line(Vector2(0, 0), Vector2(0, BAR_ONE_Y), lead_color(0), lead_width(0))
	aa_line(Vector2(-G * 0.5, BAR_ONE_Y), Vector2(1.5 * G, BAR_ONE_Y), lead_color(0), lead_width(0))
	for x: float in [-G * 0.5, 1.5 * G]:
		aa_polyline(PackedVector2Array([Vector2(x, BAR_ONE_Y), Vector2(x, CROSS_STOP_Y), Vector2(x + 0.5 * G - STOP, CROSS_STOP_Y)]), lead_color(0), lead_width(0))
	aa_line(Vector2(2 * G, 0), Vector2(2 * G, BAR_TWO_Y), lead_color(1), lead_width(1))
	aa_line(Vector2(0.5 * G, BAR_TWO_Y), Vector2(2.5 * G, BAR_TWO_Y), lead_color(1), lead_width(1))
	for x: float in [0.5 * G, 2.5 * G]:
		aa_polyline(PackedVector2Array([Vector2(x, BAR_TWO_Y), Vector2(x, CROSS_STOP_Y), Vector2(x - 0.5 * G + STOP, CROSS_STOP_Y)]), lead_color(1), lead_width(1))
	var s: float = shown("blades", 1.0 if over else 0.0)
	var link: float = 0.0
	for k: int in 2:
		var x: float = k * 2.0 * G
		var origin: Vector2 = Vector2(x, CROSS_PIVOT_Y)
		aa_line(Vector2(x, SymbolGeometry.INTERMEDIATE_SPAN * G), origin, lead_color(2 + k), lead_width(2 + k))
		# The blade from 3 rests on 1 (left), the one from 4 on 2 (right).
		var tip: Vector2 = blade_tip(origin, origin + (LEFT_ARM if k == 0 else RIGHT_ARM), origin + (RIGHT_ARM if k == 0 else LEFT_ARM), s)
		draw_blade(origin, tip, lead_color(2 + k), lead_width(2 + k))
		link = origin.x + (tip.x - origin.x) * (origin.y - CROSS_LINK_Y) / (origin.y - tip.y)
	_head(head_x, link, over, -1.0, CROSS_LINK_Y)


## Lead of terminal [param index] (below) up to the pivot at [param x].
func _lead(index: int, x: float) -> void:
	aa_line(Vector2(x, SymbolGeometry.SPAN * G), Vector2(x, PIVOT_Y), lead_color(index), lead_width(index))


## The common L below [param from] joined along to the pivot at [param to].
func _common(from: float, to: float) -> void:
	_lead(0, from)
	aa_polyline(PackedVector2Array([Vector2(from, COMMON_Y), Vector2(to, COMMON_Y), Vector2(to, PIVOT_Y)]), lead_color(0), lead_width(0))
	aa_circle(Vector2(from, COMMON_Y), SchematicTheme.LINE_WIDTH * 1.6, lead_color(0))


## True when terminal [param index] stands straight under the pivot at [param x].
func _straight_over(index: int, x: float) -> bool:
	return is_equal_approx(SymbolGeometry.light_switch_cell(_switch(), index).x * G, x) and SymbolGeometry.light_switch_cell(_switch(), index).y == SymbolGeometry.SPAN and _switch().circuit in ["1", "2", "3", "6"]


## Where the blade from [param origin] to [param tip] crosses the link's height.
func _link_x(origin: Vector2, tip: Vector2) -> float:
	return origin.x + (tip.x - origin.x) * (origin.y - LINK_Y) / (origin.y - tip.y)


## A rocker's turn head at [param x] on a dashed link to [param link_x]; it
## turns over with the rocker. [param side] -1 for a head on the left.
func _head(x: float, link_x: float, over: bool, side: float, y: float = LINK_Y) -> void:
	# The actuator and the link are insulated from the poles: never live.
	var mark: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	aa_dashed_line(Vector2(x, y), Vector2(link_x + side, y), mark, 1.4, 2.5)
	var flip: float = (-1.0 if over else 1.0) * -side
	aa_line(Vector2(x, y - 7), Vector2(x, y + 7), mark, 1.8)
	aa_line(Vector2(x, y - 7), Vector2(x - 5 * flip, y - 7), mark, 1.8)
	aa_line(Vector2(x, y + 7), Vector2(x + 5 * flip, y + 7), mark, 1.8)


func _draw_labels() -> void:
	var sw: LightSwitch = _switch()
	var anchor: Vector2 = _designation_anchor()
	draw_label(designation_text(), anchor, SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	draw_label(tr("No. %s") % sw.circuit, anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
	if not is_equal_approx(sw.height, LightSwitch.STANDARD_HEIGHT):
		draw_label(height_text(sw.height), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 2)
	if sw.circuit in ["2", "3"]:
		_draw_pole_labels()
		return
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in names.size():
		var cell: Vector2i = SymbolGeometry.light_switch_cell(sw, i)
		var x: float = cell.x * G
		if cell.y == 0:
			draw_label(names[i], Vector2(x + 0.3 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		else:
			draw_label(names[i], Vector2(x - 0.3 * G, (cell.y - 0.4) * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)


## Mounting height as written beside a part of a house installation whose
## height is not the standard one, e.g. "h = 1.10 m".
static func height_text(height: float) -> String:
	return "h = %s m" % String.num(height, 2).pad_decimals(2)
