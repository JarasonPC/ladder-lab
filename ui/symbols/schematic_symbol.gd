class_name SchematicSymbol
extends Node2D
## Base for symbols drawn with _draw() per IEC 60617. Subclasses draw in local
## pixel coordinates of the unturned symbol (first terminal at the origin,
## second terminal [constant SymbolGeometry.SPAN] cells below); the placement
## mirror and rotation are applied here. Labels are always drawn upright.

const G: float = float(SymbolGeometry.GRID)

var component: CircuitComponent
var placement: Placement
const REACH_NONE: int = StepResult.REACH_NONE
const REACH_N: int = StepResult.REACH_N

## Per terminal (in [method CircuitComponent.get_terminal_names] order): what
## reaches it, a [StepResult] reach code (REACH_NONE, a phase, N or several).
## Set by the view from the last [StepResult].
var live: PackedByteArray = PackedByteArray()
## Blinking warning (oscillation), already gated by the blink phase.
var warning: bool = false
var hovered: bool = false
## False for palette previews.
var show_labels: bool = true
## Key of the keyboard bound to the device ("" for none), drawn as a keycap
## after the designation.
var key: String = ""
## True for palette previews (supplies there show their name only).
var preview: bool = false
## Markings written at the last draw, for editing them in place:
## [kind, index, Rect2 in node coordinates]; kind is "designation",
## "terminal" (index = terminal index), "purpose" (lamp) or "label" (terminal
## block, page connector).
var marking_rects: Array = []
## Every text written at the last draw (markings, times, states), in node
## coordinates: what the symbol covers beyond its body.
var text_rects: Array[Rect2] = []
## Terminals of other parts near this one, node coordinates (set by the
## view): strip labels keep off them.
var nearby_terminals: PackedVector2Array = PackedVector2Array()
## Local anchor the designation was last written at (texts written there
## follow it when it is dragged).
var _designation_anchor_drawn: Vector2 = Vector2(INF, INF)
## On-screen scale while drawing (see _draw); [member drawn_scale] is the one
## of the last draw, so the view can redraw when the zoom changes.
var _k: float = 1.0
var drawn_scale: float = 0.0
## The shape is being drawn mirrored along its axis (see [method flips_when_horizontal]).
var _ends_swapped: bool = false


func setup(p_component: CircuitComponent, p_placement: Placement) -> void:
	component = p_component
	placement = p_placement
	update_position()


func update_position() -> void:
	position = Vector2(placement.cell) * G


## True for symbols the user can operate with the mouse.
func is_interactive() -> bool:
	return false


func _draw() -> void:
	# Shapes go through the aa_* helpers: coordinates scaled up by the
	# on-screen scale under a transform scaled back down, so Godot's
	# antialiasing edge (one coordinate unit) is one screen pixel at any zoom.
	_k = maxf(get_global_transform_with_canvas().get_scale().x, 0.05)
	var unscale: Transform2D = Transform2D().scaled(Vector2.ONE / _k)
	var t: Transform2D = SymbolGeometry.draw_transform(placement)
	_ends_swapped = ends_swapped()
	draw_set_transform_matrix(shape_transform() * unscale)
	if hovered and is_interactive():
		var body: Rect2 = SymbolGeometry.local_body(component)
		aa_rect(Rect2(body.position * G, body.size * G), SchematicTheme.HOVER)
	_draw_shape(stroke_color(), stroke_width())
	_ends_swapped = false
	draw_set_transform_matrix(t * unscale)
	if show_labels:
		_draw_terminals()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	marking_rects.clear()
	text_rects.clear()
	if show_labels:
		_draw_labels()
		_draw_strip_labels()
		if not key.is_empty():
			_draw_keycap()
	if has_fault():
		draw_set_transform_matrix(unscale)
		_draw_fault_marker(to_upright(fault_anchor()))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	drawn_scale = _k


# --- Smooth movement ----------------------------------------------------------

## Seconds a moving part (blade, button, holder) takes on the drawing.
const MOVE_TIME: float = 0.15

var _shown: Dictionary[String, float] = {}
var _targets: Dictionary[String, float] = {}


## Position (0..1) to draw a moving part [param key] at: it follows
## [param target] smoothly over [constant MOVE_TIME], so switching is seen as
## a movement rather than a jump. The first value is taken as it is.
func shown(key: String, target: float) -> float:
	_targets[key] = target
	if not _shown.has(key):
		_shown[key] = target
	return _shown[key]


func _process(delta: float) -> void:
	for key: String in _targets:
		var now: float = _shown.get(key, _targets[key])
		if now != _targets[key]:
			_shown[key] = move_toward(now, _targets[key], delta / MOVE_TIME)
			queue_redraw()


# --- Drawing helpers: antialiased with a one-pixel edge (see _draw) --------------

func aa_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0) -> void:
	draw_line(from * _k, to * _k, color, _px(width), true)


func aa_polyline(points: PackedVector2Array, color: Color, width: float = -1.0) -> void:
	draw_polyline(_scaled(points), color, _px(width), true)


func aa_arc(center: Vector2, radius: float, start: float, end: float, point_count: int, color: Color, width: float = -1.0) -> void:
	draw_arc(center * _k, radius * _k, start, end, point_count, color, _px(width), true)


func aa_circle(center: Vector2, radius: float, color: Color, filled: bool = true, width: float = -1.0) -> void:
	draw_circle(center * _k, radius * _k, color, filled, _px(width) if not filled else -1.0, true)


func aa_dashed_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, dash: float = 2.0) -> void:
	draw_dashed_line(from * _k, to * _k, color, _px(width), dash * _k, true, true)


func aa_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0) -> void:
	if filled:
		draw_rect(Rect2(rect.position * _k, rect.size * _k), color)
		return
	# An outline is a closed line (draw_rect's outline is not antialiased
	# and thins away below zoom 1), starting in the middle of the top edge
	# so that every corner is a joint; never thinner than a pixel, or the
	# small boxes (PLC lights, display) fade away when zoomed out.
	var top: Vector2 = Vector2(rect.get_center().x, rect.position.y)
	aa_polyline(PackedVector2Array([top, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position, top]), color, maxf(width, 1.0 / _k) if width > 0.0 else width)


func aa_polygon(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(_scaled(points), color)


func _px(width: float) -> float:
	if width <= 0.0:
		return 1.0
	# Palette previews are drawn small: no line thinner than a pixel there.
	return maxf(width * _k, 1.0) if preview else width * _k


func _scaled(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	result.resize(points.size())
	for i: int in points.size():
		result[i] = points[i] * _k
	return result


func reach(terminal_index: int) -> int:
	if _ends_swapped:
		# Drawn mirrored along the axis: the ends trade places.
		terminal_index = 1 - terminal_index if component.get_terminal_names().size() == 2 else terminal_index ^ 1
	return live[terminal_index] if terminal_index < live.size() else REACH_NONE


## True for symbols whose blade should pivot on the left when they lie
## horizontally (contacts, breakers, fuse holders). Override.
func flips_when_horizontal() -> bool:
	return false


## True while the shape is drawn mirrored along its axis: lying horizontally,
## switching symbols are, so the blade pivots on the left and rises to the
## right. Turned once the second terminal (the pivot) is on the left
## already; turned three times it is on the right.
func ends_swapped() -> bool:
	return flips_when_horizontal() and placement.rotation == 3


## Transform the shape is drawn with (see [method ends_swapped]), local
## pixels to upright node pixels.
func shape_transform() -> Transform2D:
	var t: Transform2D = SymbolGeometry.draw_transform(placement)
	if ends_swapped():
		t = t * Transform2D(Vector2(1, 0), Vector2(0, -1), Vector2(0, _span() * G))
	return t


## Distance from the first to the last terminal along the symbol axis, in cells.
func _span() -> int:
	var span: int = 0
	for cell: Vector2i in SymbolGeometry.local_terminals(component).values():
		span = maxi(span, cell.y)
	return span


## True when a phase, + (or several supplies) reaches any terminal.
func any_live() -> bool:
	for code: int in live:
		if code != REACH_NONE and not StepResult.is_return(code):
			return true
	return false


## Colour of the symbol body. Voltage reach shows on the wires only; a coil
## is the exception and takes the colour of the first phase (or +) that
## reaches it (else N or the DC - pole when one does).
func stroke_color() -> Color:
	if warning:
		return SchematicTheme.WARNING
	if not (component is Coil):
		return SchematicTheme.LINE
	for code: int in live:
		if code != REACH_NONE and not StepResult.is_return(code):
			return SchematicTheme.reach_color(code)
	for code: int in live:
		if StepResult.is_return(code):
			return SchematicTheme.reach_color(code)
	return SchematicTheme.LINE


func stroke_width() -> float:
	if not (component is Coil):
		return SchematicTheme.LINE_WIDTH
	var reached: bool = false
	for code: int in live:
		reached = reached or code != REACH_NONE
	return SchematicTheme.LIVE_WIDTH if warning or reached else SchematicTheme.LINE_WIDTH


## Colour of the lead and contact parts on the side of one terminal. The
## voltage shows on the wires up to the terminal squares, not inside the
## symbol: leads stay in the line colour.
func lead_color(_terminal_index: int) -> Color:
	return SchematicTheme.WARNING if warning else SchematicTheme.LINE


func lead_width(_terminal_index: int) -> float:
	return SchematicTheme.LIVE_WIDTH if warning else SchematicTheme.LINE_WIDTH


## Contact blade: a line with round ends, so slanted blades meet their
## leads cleanly.
func draw_blade(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	aa_line(from, to, color, width)
	aa_circle(from, width * 0.5, color)
	aa_circle(to, width * 0.5, color)


## Tip of a blade turning about [param pivot] from [param from_tip] to
## [param to_tip], [param t] 0..1: the blade turns instead of sliding its tip
## along a straight line, so it keeps its length when both tips are as far
## from the pivot.
static func blade_tip(pivot: Vector2, from_tip: Vector2, to_tip: Vector2, t: float) -> Vector2:
	var from_arm: Vector2 = from_tip - pivot
	var to_arm: Vector2 = to_tip - pivot
	var angle: float = from_arm.angle() + angle_difference(from_arm.angle(), to_arm.angle()) * t
	return pivot + Vector2.from_angle(angle) * lerpf(from_arm.length(), to_arm.length(), t)


## Part of the drawing a palette preview shows (local pixels, unturned); an
## empty rect for the body with its terminals. Symbols too wide for a
## palette tile draw a smaller version of themselves while [member preview]
## is set and give its extent here.
func preview_rect() -> Rect2:
	return Rect2()


## Palette previews: [param text] centred upright at [param local_point] of
## the unturned symbol, in the schematic font of [param size]. Called last in
## [method _draw_shape] (it changes the draw transform).
func draw_preview_text(text: String, local_point: Vector2, size: int) -> void:
	draw_set_transform_matrix(Transform2D().scaled(Vector2.ONE / _k))
	var font: Font = AppTheme.schematic_font()
	var px: int = maxi(roundi(size * _k), 1)
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, to_upright(local_point) * _k + Vector2(-w * 0.5, font.get_ascent(px) * 0.5 - 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, SchematicTheme.TEXT)


## Draws the symbol in local coordinates. Override.
func _draw_shape(_color: Color, _width: float) -> void:
	pass


## Designation as written on the drawing: "-KM1" (ČSN EN 81346 prefix).
func designation_text() -> String:
	return "-" + component.designation


## Square at every terminal, filled with what reaches it (black when nothing).
func _draw_terminals() -> void:
	if component is Junction or component is TerminalBlock:
		return
	var s: float = SchematicTheme.TERMINAL_SQUARE
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(component)
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in names.size():
		var at: Vector2 = Vector2(cells[names[i]]) * G
		var code: int = reach(i)
		var fill: Color = SchematicTheme.TERMINAL_DEAD if code == REACH_NONE else SchematicTheme.reach_color(code)
		if placement.strips.has(i):
			# A terminal of a terminal strip: a circle with a slash.
			var line: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
			aa_circle(at, TerminalBlockSymbol.RADIUS, SchematicTheme.BACKGROUND)
			aa_arc(at, TerminalBlockSymbol.RADIUS, 0.0, TAU, 20, line, 1.6)
			var d: Vector2 = TerminalBlockSymbol.slash(placement)
			aa_line(at - d, at + d, line, 1.6)
		else:
			aa_rect(Rect2(at - Vector2(s, s) * 0.5, Vector2(s, s)), fill)


## Half the size of a strip terminal's mark (circle and slash) and a little
## room: texts stay this far from the terminal along and across its lead.
const STRIP_MARK: float = 8.5


## Labels of the strip terminals, all of one symbol written alike: the
## first style (see [method _strip_styles]) that fits the most of them,
## each on its side of the wire ([method _strip_side]), else the other side;
## a label that fits in that style nowhere takes the first style and side
## that fits, else the first clear of marks.
func _draw_strip_labels() -> void:
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(component)
	var names: PackedStringArray = component.get_terminal_names()
	var t: Transform2D = SymbolGeometry.draw_transform(placement)
	var font: Font = AppTheme.schematic_font()
	var terminals: Array[int] = []
	for i: int in placement.strips:
		if i < names.size():
			terminals.append(i)
	if terminals.is_empty():
		return
	var styles: Array[int] = _strip_styles(terminals)
	var placed: Dictionary[int, Array] = {}
	for style: int in styles:
		var trial: Dictionary[int, Array] = {}
		for i: int in terminals:
			for choice: Array in _strip_choices(i, [style]):
				if _strip_label_fits(choice, i, trial):
					trial[i] = choice
					break
		if trial.size() > placed.size():
			placed = trial
		if placed.size() == terminals.size():
			break
	for i: int in terminals:
		if placed.has(i):
			continue
		var choices: Array[Array] = _strip_choices(i, styles)
		var chosen: Array = choices[0]
		for choice: Array in choices:
			if _strip_label_fits(choice, i, placed):
				chosen = choice
				break
		if not _strip_label_fits(chosen, i, placed):
			for choice: Array in choices:
				if not _hits_marks(choice, i, cells, names, t):
					chosen = choice
					break
		placed[i] = chosen
	for i: int in terminals:
		for line: Array in placed[i]:
			var rect: Rect2 = line[2]
			_write(line[0], rect.position + Vector2(0.0, font.get_ascent(line[1])), line[1], SchematicTheme.DESIGNATION, ["strip", i])


## Styles the strip labels of [param terminals] are tried in: a supply
## point's on one line over the mark (close to the wire and clear of the
## wire it is joined to); where three or more terminals stand in a row
## across their wires close together (a motor, the poles of a breaker) on
## one line past the mark, as there is no room beside it; else beside the
## mark (along a horizontal wire over it), then past it along a horizontal
## wire. Where one line does not fit (terminals close together), a size
## smaller, then the strip over the number.
func _strip_styles(terminals: Array[int]) -> Array[int]:
	var t: Transform2D = SymbolGeometry.draw_transform(placement)
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(component)
	var names: PackedStringArray = component.get_terminal_names()
	var horizontal: bool = false
	var crowded: bool = false
	for i: int in terminals:
		var outward: Vector2 = -lead_vector(i)
		var at: Vector2 = t * (Vector2(cells[names[i]]) * G)
		horizontal = horizontal or absf(outward.x) > 0.5
		crowded = crowded or (_crowded(i, at, outward) and (absf(outward.x) > 0.5 or _in_row(i, at, outward) >= 2))
	if names.size() == 1 and horizontal:
		return [OVER_MARK, PAST_MARK, STACKED, SMALL, TWO_LINES]
	if crowded:
		return [PAST_MARK, STACKED, SMALL, TWO_LINES]
	if horizontal:
		return [STACKED, PAST_MARK, SMALL, TWO_LINES]
	return [STACKED, SMALL, TWO_LINES]


## The places the label of strip terminal [param index] can take in
## [param styles], each on its side of the wire, then on the other.
func _strip_choices(index: int, styles: Array[int]) -> Array[Array]:
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(component)
	var at: Vector2 = SymbolGeometry.draw_transform(placement) * (Vector2(cells[component.get_terminal_names()[index]]) * G)
	var outward: Vector2 = -lead_vector(index)
	var side: Vector2 = _strip_side(index, at, outward)
	var label: String = placement.strips[index]
	var choices: Array[Array] = []
	for style: int in styles:
		choices += [_strip_label_lines(label, at, outward, side, style), _strip_label_lines(label, at, outward, -side, style)]
	return choices


## True when the [param lines] of the label of strip terminal [param index]
## keep off the marks, the texts written so far and the strip labels
## [param placed] (terminal index -> lines) before they are written.
func _strip_label_fits(lines: Array, index: int, placed: Dictionary[int, Array]) -> bool:
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(component)
	if _hits_markings(lines) or _hits_marks(lines, index, cells, component.get_terminal_names(), SymbolGeometry.draw_transform(placement)):
		return false
	for k: int in placed:
		for other: Array in placed[k]:
			for line: Array in lines:
				if (line[2] as Rect2).grow(-1.0).intersects((other[2] as Rect2).grow_individual(2.0, 0.0, 2.0, 0.0)):
					return false
	return true


## How a strip label is written (see [method _strip_label_lines]), always
## strip and number on one line ("X2-6", [method CabinetDevices.terminal_text])
## but the last: beside the mark, on one line past the mark beside the wire,
## on one line over (or under) the mark, beside the mark a size smaller, the
## strip over the number beside the mark (where nothing else fits).
const STACKED: int = 0
const PAST_MARK: int = 1
const OVER_MARK: int = 2
const SMALL: int = 3
const TWO_LINES: int = 4


## Lines of strip label [param label] written at terminal [param at] on
## [param side] of its wire in [param style]: [text, font size, Rect2 in
## node coordinates] each.
func _strip_label_lines(label: String, at: Vector2, outward: Vector2, side: Vector2, style: int) -> Array[Array]:
	var font: Font = AppTheme.schematic_font()
	var texts: PackedStringArray = PackedStringArray([CabinetDevices.terminal_text(label)])
	var sizes: PackedInt32Array = PackedInt32Array([SchematicTheme.TERMINAL_SIZE + (2 if style == STACKED or style == PAST_MARK else (0 if style == SMALL else 1))])
	if style == TWO_LINES:
		texts = CabinetDevices.split_label(label)
		sizes = PackedInt32Array([SchematicTheme.TERMINAL_SIZE + 1, SchematicTheme.TERMINAL_SIZE + 2])
	var lines: Array[Array] = []
	for k: int in texts.size():
		var size: Vector2 = font.get_string_size(texts[k], HORIZONTAL_ALIGNMENT_LEFT, -1, sizes[k])
		var middle: Vector2
		if style == PAST_MARK and absf(outward.x) > 0.5:
			middle = at + outward * (STRIP_MARK + 2.5 + size.x * 0.5) + side * (size.y * 0.5 + 2.0)
		elif style == PAST_MARK:
			# Beside a vertical wire, out past the mark.
			middle = at + outward * (STRIP_MARK + size.y * 0.5) + side * (size.x * 0.5 + 3.0)
		elif style == OVER_MARK:
			middle = at + side * (STRIP_MARK + 1.0 + size.y * 0.5)
		elif absf(outward.x) > 0.5:
			# Over or under a horizontal wire, centred on the mark, the
			# lines stacked away from the wire.
			var away: float = (texts.size() - 1 - k if side.y < 0.0 else k) * 10.0
			middle = at + side * (STRIP_MARK + 1.0 + size.y * 0.5 + away)
		else:
			# Beside a vertical wire, the line nearest the terminal level
			# with it, the others further out along the wire.
			var step: float = 10.0 * (k - texts.size() + 1 if outward.y < 0.0 else k)
			middle = at + side * (STRIP_MARK + 2.5 + size.x * 0.5) + Vector2(0.0, step - 2.0 * signf(-outward.y))
		lines.append([texts[k], sizes[k], Rect2(middle - size * 0.5, size)])
	return lines


## Screen direction of the lead of terminal [param index] into the symbol
## (supplies and page connectors: up from the terminal to the circle or tag).
func lead_vector(index: int) -> Vector2:
	var name: String = component.get_terminal_names()[index]
	var local: Vector2 = Vector2.UP
	match SymbolGeometry.local_lead_direction(component, name):
		SymbolGeometry.DIR_DOWN:
			local = Vector2.DOWN
		SymbolGeometry.DIR_LEFT:
			local = Vector2.LEFT
		SymbolGeometry.DIR_RIGHT:
			local = Vector2.RIGHT
	return SymbolGeometry.draw_transform(placement).basis_xform(local).round()


## Side of the wire (a screen direction across it) on which strip terminal
## [param index] at [param at] writes its label: that of the symbol's left
## (its designation side), unless the terminal is one of a pair side by side
## (no other terminal in line with them) and the other one is on that side.
func _strip_side(index: int, at: Vector2, outward: Vector2) -> Vector2:
	var t: Transform2D = SymbolGeometry.draw_transform(placement)
	var across: Vector2 = Vector2(absf(outward.y), absf(outward.x))
	var left: float = t.basis_xform(Vector2.LEFT).round().dot(across)
	var side: Vector2 = across * (left if left != 0.0 else -1.0)
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(component)
	var names: PackedStringArray = component.get_terminal_names()
	var beside: Array[Vector2] = []
	for k: int in names.size():
		var other: Vector2 = t * (Vector2(cells[names[k]]) * G) - at
		if k != index and absf(other.dot(outward)) < 1.0:
			beside.append(other)
	if beside.size() == 1 and beside[0].dot(side) > 0.0:
		side = -side
	return side


## True when another terminal of the symbol is in line with terminal
## [param index] at [param at] across its wire, two cells away at most.
func _crowded(index: int, at: Vector2, outward: Vector2) -> bool:
	var t: Transform2D = SymbolGeometry.draw_transform(placement)
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(component)
	var names: PackedStringArray = component.get_terminal_names()
	for k: int in names.size():
		var other: Vector2 = t * (Vector2(cells[names[k]]) * G) - at
		if k != index and absf(other.dot(outward)) < 1.0 and other.length() < 2.5 * G:
			return true
	return false


## Number of the other terminals of the symbol in line with terminal
## [param index] at [param at] across its wire.
func _in_row(index: int, at: Vector2, outward: Vector2) -> int:
	var t: Transform2D = SymbolGeometry.draw_transform(placement)
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(component)
	var names: PackedStringArray = component.get_terminal_names()
	var count: int = 0
	for k: int in names.size():
		if k != index and absf((t * (Vector2(cells[names[k]]) * G) - at).dot(outward)) < 1.0:
			count += 1
	return count


## True when one of the [param lines] of the strip label of terminal
## [param index] runs onto the strip mark or square of another terminal of
## the symbol ([param cells], [param names] and [param t] as in [method
## _draw_strip_labels]) or onto a terminal of a part nearby
## ([member nearby_terminals], e.g. the next supply point of L1 L2 L3).
func _hits_marks(lines: Array, index: int, cells: Dictionary[String, Vector2i], names: PackedStringArray, t: Transform2D) -> bool:
	var points: PackedVector2Array = nearby_terminals.duplicate()
	for k: int in names.size():
		if k != index:
			points.append(t * (Vector2(cells[names[k]]) * G))
	for point: Vector2 in points:
		# The circle with its slash.
		var mark: Rect2 = Rect2(point - Vector2(7.5, 7.5), Vector2(15.0, 15.0))
		for line: Array in lines:
			if (line[2] as Rect2).grow_individual(-1.0, -2.5, -1.0, -3.0).intersects(mark):
				return true
	return false


## True when one of the [param lines] of a strip label (see [method
## _strip_label_lines]) overlaps a terminal name or strip label written so
## far.
func _hits_markings(lines: Array) -> bool:
	for m: Array in marking_rects:
		if m[0] == "terminal" or m[0] == "strip":
			for line: Array in lines:
				if (line[2] as Rect2).grow(-1.0).intersects((m[2] as Rect2).grow_individual(2.0, 0.0, 2.0, 0.0)):
					return true
	# Nor any other text written so far (ratings, ranges).
	for r: Rect2 in text_rects:
		for line: Array in lines:
			if (line[2] as Rect2).grow_individual(-1.0, -2.5, -1.0, -3.0).intersects(r.grow_individual(-1.0, -2.5, -1.0, -3.0)):
				return true
	return false


## Draws designation and terminal numbers. Override to add more.
func _draw_labels() -> void:
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	var names: PackedStringArray = component.get_terminal_names()
	if names.size() == 2:
		draw_label(names[0], Vector2(0.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		draw_label(names[1], Vector2(0.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)


## The keycap of [member key] beside the designation on the side away from
## the symbol (after it when the designation is above or below the symbol),
## lit while the device is operated.
func _draw_keycap() -> void:
	for entry: Array in marking_rects:
		if entry[0] == "designation":
			var rect: Rect2 = entry[2]
			var cap: Vector2 = Keycap.size_of(key, SchematicTheme.TERMINAL_SIZE)
			var lit: bool = component is SwitchingElement and (component as SwitchingElement).get_travel() > 0.5
			var transform: Transform2D = SymbolGeometry.draw_transform(placement)
			var centre: Vector2 = rect.get_center()
			var away: Vector2 = centre - transform * Vector2(0.0, (transform.affine_inverse() * centre).y)
			var x: float = rect.end.x + 4.0
			if absf(away.x) >= absf(away.y) and away.x < 0.0:
				x = rect.position.x - 4.0 - cap.x
			Keycap.draw(self, Vector2(x, centre.y - cap.y * 0.5), key, SchematicTheme.TERMINAL_SIZE, lit and not (component is LatchingSwitch))
			return


## True when a fault is injected into this component (simulation only).
func has_fault() -> bool:
	if component is Load and (component as Load).burnt:
		return true
	if component is SwitchingElement:
		return (component as SwitchingElement).fault != SwitchingElement.Fault.NONE
	if component is ChangeoverContact:
		return (component as ChangeoverContact).fault != SwitchingElement.Fault.NONE
	if component is Coil:
		return (component as Coil).fault != Coil.Fault.NONE
	if component is MainContacts:
		return (component as MainContacts).fault != SwitchingElement.Fault.NONE
	if component is OverloadRelay:
		return (component as OverloadRelay).overloaded
	if component is ThreePhaseMotor:
		return (component as ThreePhaseMotor).overloaded
	return false


## Writes how far an overcurrent has heated a protective device towards
## tripping ([param progress] 0-1) as a percentage, on line [param line]
## beside [param anchor]; nothing while it is cold.
func draw_heat(progress: float, anchor: Vector2, line: int) -> void:
	if progress >= 0.005:
		draw_label("%d %%" % roundi(progress * 100.0), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.FAULT, line)


## Terminal numbers of a multi-pole symbol: 1, 3, 5, 7 on top, 2, 4, 6, 8
## below; [param short_leads]: out beside the wire on a terminal strip (see
## [method name_anchor]).
func _draw_pole_labels(short_leads: bool = false) -> void:
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in names.size():
		var x: float = (i / 2) * SymbolGeometry.POLE_SPACING * G + 0.3 * G
		var y: float = 0.4 * G if i % 2 == 0 else 2.6 * G
		draw_label(names[i], name_anchor(i, Vector2(x, y)) if short_leads else Vector2(x, y), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)


## Local x of pole [param pole] (0-3) of a multi-pole symbol.
static func pole_x(pole: int) -> float:
	return pole * SymbolGeometry.POLE_SPACING * G


## Local point the fault mark is drawn at: right of the body (away from the
## designation), level with its middle, clear of its lines and terminal names.
func fault_anchor() -> Vector2:
	var body: Rect2 = SymbolGeometry.local_body(component)
	# The upright bolt is taller than wide: further out when the body's
	# right is up or down on the drawing.
	var across: bool = absf(SymbolGeometry.draw_transform(placement).basis_xform(Vector2.RIGHT).x) > 0.5
	return Vector2(body.end.x * G + (6.0 if across else 11.5), body.get_center().y * G)


## Small lightning bolt marking an injected fault.
func _draw_fault_marker(at: Vector2) -> void:
	var bolt: PackedVector2Array = PackedVector2Array([Vector2(2, -9), Vector2(-3, 0), Vector2(1, 0), Vector2(-2, 9), Vector2(4, -2), Vector2(0, -2), Vector2(2, -9)])
	for i: int in bolt.size():
		bolt[i] += at
	aa_polygon(bolt, SchematicTheme.FAULT)
	aa_polyline(bolt, SchematicTheme.LIVE, 1.0)


## Local point next to which the designation is written.
## Writes the rated voltage of a load ("24 V DC") on [param line] beside
## [param anchor]; nothing for a part without a rating.
func draw_rating(anchor: Vector2, line: int) -> void:
	var load: Load = component as Load
	if load != null and not load.rating.is_empty():
		draw_label(VoltageRating.text(load.rating), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, line)


func _designation_anchor() -> Vector2:
	return Vector2(-1.3 * G, 1.5 * G)


## Draws upright text at a local anchor. Text extends away from the symbol
## axis (a terminal's name away from its own lead): left/right of it when the
## anchor is to the side, above/below otherwise.
## [param line] > 0 writes a further line: below the first one when the text is
## beside the symbol, further away from the symbol when it is above or below.
## [param marking]: what the text marks ([kind, index]); found from the text
## when not given. The name of a strip terminal keeps off its mark.
func draw_label(text: String, local_anchor: Vector2, font_size: int, color: Color, line: int = 0, marking: Array = []) -> void:
	var font: Font = AppTheme.schematic_font()
	if marking.is_empty():
		marking = _marking_of(text)
	var axis_x: float = 0.0
	if not marking.is_empty() and marking[0] == "terminal":
		axis_x = SymbolGeometry.local_terminals(component)[component.get_terminal_names()[marking[1]]].x * G
	var anchor: Vector2 = SymbolGeometry.draw_transform(placement) * local_anchor
	var axis_point: Vector2 = SymbolGeometry.draw_transform(placement) * Vector2(axis_x, local_anchor.y)
	var away: Vector2 = anchor - axis_point
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent: float = font.get_ascent(font_size)
	var pos: Vector2
	if absf(away.x) >= absf(away.y):
		pos = Vector2(anchor.x - size.x if away.x < 0.0 else anchor.x, anchor.y + ascent * 0.5 - 1.0)
	else:
		var top: float = anchor.y - size.y if away.y < 0.0 else anchor.y
		pos = Vector2(anchor.x - size.x * 0.5, top + ascent)
	if line != 0:
		# Further lines sit beside the designation, which uses the larger size.
		var line_height: float = font.get_height(maxi(font_size, SchematicTheme.LABEL_SIZE))
		var direction: float = -1.0 if absf(away.x) < absf(away.y) and away.y < 0.0 else 1.0
		pos.y += direction * line * line_height
	# Markings the user dragged elsewhere; texts written with the
	# designation (times, states, a lamp's label) move along with it.
	if not marking.is_empty() and marking[0] == "designation":
		_designation_anchor_drawn = local_anchor
	if marking.is_empty() or marking[0] == "purpose":
		if local_anchor == _designation_anchor_drawn:
			pos += placement.labels.get("designation", Vector2.ZERO) * G
	if not marking.is_empty() and marking[0] == "terminal" and placement.strips.has(marking[1]):
		pos += _clear_of_strip_mark(marking[1], Rect2(Vector2(pos.x, pos.y - ascent), size), ascent)
	_write(text, pos, font_size, color, marking)


## Upright text in the middle of the local [param box] (a display, a
## window); in a box turned upright its words go on lines of their own,
## smaller where they would not fit.
func write_in(text: String, box: Rect2, font_size: int) -> void:
	var font: Font = AppTheme.schematic_font()
	var room: Vector2 = SymbolGeometry.transform_rect(box, placement).size - Vector2(4.0, 2.0)
	var lines: PackedStringArray = PackedStringArray([text])
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room.x:
		lines = text.split("  " if text.contains("  ") else " ", false)
	var size: int = font_size
	while size > 6:
		var widest: float = 0.0
		for line: String in lines:
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		if widest <= room.x and lines.size() * font.get_height(size) <= room.y:
			break
		size -= 1
	# Lines one under the other on the drawing, whichever way the box is turned.
	var down: Vector2 = SymbolGeometry.draw_transform(placement).basis_xform_inv(Vector2.DOWN)
	for i: int in lines.size():
		var at: Vector2 = to_upright(box.get_center() + down * (i - (lines.size() - 1) * 0.5) * font.get_height(size))
		var width: float = font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		_write(lines[i], at + Vector2(-width * 0.5, font.get_ascent(size) * 0.5 - 1.0), size, SchematicTheme.TEXT, [])


## Writes [param text] with its baseline starting at [param pos] (node
## coordinates), moved by the offset the user dragged its marking by, and
## remembers where.
func _write(text: String, pos: Vector2, font_size: int, color: Color, marking: Array) -> void:
	var font: Font = AppTheme.schematic_font()
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent: float = font.get_ascent(font_size)
	var own: Vector2 = Vector2.ZERO
	if not marking.is_empty():
		own = placement.labels.get(marking_key(marking[0], marking[1]), Vector2.ZERO)
		pos += own * G
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	text_rects.append(Rect2(Vector2(pos.x, pos.y - ascent), size))
	if not marking.is_empty():
		marking_rects.append([marking[0], marking[1], Rect2(Vector2(pos.x, pos.y - ascent), size), own])


## Local anchor for the name of terminal [param index] for symbols with
## leads too short for a name between a strip's mark and the body:
## [param inside] beside the lead, or as far out beside the wire when the
## terminal is on a terminal strip, on the other side of the wire than the
## strip label.
func name_anchor(index: int, inside: Vector2) -> Vector2:
	if not placement.strips.has(index):
		return inside
	var cell: Vector2 = Vector2(SymbolGeometry.local_terminals(component)[component.get_terminal_names()[index]]) * G
	var anchor: Vector2 = Vector2(inside.x, 2.0 * cell.y - inside.y)
	var t: Transform2D = SymbolGeometry.draw_transform(placement)
	var outward: Vector2 = -lead_vector(index)
	if (t.basis_xform(anchor - cell)).dot(_strip_side(index, t * cell, outward)) > 0.0:
		anchor.x = 2.0 * cell.x - anchor.x
	return anchor


## Shift that takes the name of strip terminal [param index], written at
## [param rect] with [param ascent], off the strip mark: along the lead,
## further into the symbol or out along the wire, whichever side of the
## terminal it is on. Up and down the drawing its letters count (from the
## top of the capitals to the baseline), not the room of the whole line.
func _clear_of_strip_mark(index: int, rect: Rect2, ascent: float) -> Vector2:
	var at: Vector2 = to_upright(Vector2(SymbolGeometry.local_terminals(component)[component.get_terminal_names()[index]]) * G)
	var mark: Rect2 = Rect2(at - Vector2.ONE * STRIP_MARK, Vector2.ONE * STRIP_MARK * 2.0)
	var cap: float = ascent * 0.72
	rect = Rect2(rect.position.x, rect.position.y + ascent - cap, rect.size.x, cap)
	if not rect.intersects(mark):
		return Vector2.ZERO
	var axis: Vector2 = lead_vector(index).abs()
	var ahead: float = (rect.get_center() - at).dot(axis)
	if ahead >= 0.0:
		return axis * (mark.end.dot(axis) - rect.position.dot(axis))
	return -axis * (rect.end.dot(axis) - mark.position.dot(axis))


## Key of a marking in [member Placement.labels]: "designation",
## "terminal:<index>", "strip:<index>", "purpose" or "label".
static func marking_key(kind: String, index: int) -> String:
	if kind == "terminal" or kind == "strip":
		return "%s:%d" % [kind, index]
	return kind


## What a written [param text] marks: [kind, index] (see [member
## marking_rects]), or [] for other text (times, states).
func _marking_of(text: String) -> Array:
	if text == designation_text():
		return ["designation", -1]
	if component is Lamp and text == (component as Lamp).purpose:
		return ["purpose", -1]
	if component is TerminalBlock or (component is PageConnector and text == (component as PageConnector).label):
		return ["label", -1]
	var i: int = component.get_terminal_names().find(text)
	return ["terminal", i] if i >= 0 else []


## Rectangle of the marking [param kind] (and [param index]) as last drawn,
## moved to where its offset puts it now (it may have been dragged since),
## or an empty Rect2.
func marking_rect(kind: String, index: int = -1) -> Rect2:
	var result: Rect2 = Rect2()
	for m: Array in marking_rects:
		if m[0] == kind and m[1] == index:
			# A marking written on two lines covers both.
			var now: Vector2 = placement.labels.get(marking_key(kind, index), Vector2.ZERO)
			var r: Rect2 = Rect2((m[2] as Rect2).position + (now - (m[3] as Vector2)) * G, (m[2] as Rect2).size)
			result = r if not result.has_area() else result.merge(r)
	return result


## True when a label at [param local_anchor] is written beside the symbol
## (left or right of it) rather than above or below it.
func is_side_label(local_anchor: Vector2) -> bool:
	var anchor: Vector2 = SymbolGeometry.draw_transform(placement) * local_anchor
	var axis_point: Vector2 = SymbolGeometry.draw_transform(placement) * Vector2(0.0, local_anchor.y)
	var away: Vector2 = anchor - axis_point
	return absf(away.x) >= absf(away.y)


## Point of the unturned symbol mapped to upright node coordinates.
func to_upright(local_point: Vector2) -> Vector2:
	return SymbolGeometry.draw_transform(placement) * local_point
