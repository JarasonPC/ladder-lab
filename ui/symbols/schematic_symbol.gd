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
## Markings written at the last draw, for editing them in place:
## [kind, index, Rect2 in node coordinates]; kind is "designation",
## "terminal" (index = terminal index), "purpose" (lamp) or "label" (terminal
## block, page connector).
var marking_rects: Array = []
## Every text written at the last draw (markings, times, states), in node
## coordinates: what the symbol covers beyond its body.
var text_rects: Array[Rect2] = []
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
	# Lying horizontally, switching symbols are drawn mirrored along their
	# axis, so the blade pivots on the left and rises to the right.
	_ends_swapped = flips_when_horizontal() and placement.rotation % 2 == 1
	var shape_t: Transform2D = t
	if _ends_swapped:
		shape_t = t * Transform2D(Vector2(1, 0), Vector2(0, -1), Vector2(0, _span() * G))
	draw_set_transform_matrix(shape_t * unscale)
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
	if has_fault():
		draw_set_transform_matrix(unscale)
		_draw_fault_marker(to_upright(Vector2(0.9 * G, 0.9 * G)))
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
	draw_rect(Rect2(rect.position * _k, rect.size * _k), color, filled, _px(width) if not filled else -1.0)


func aa_polygon(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(_scaled(points), color)


func _px(width: float) -> float:
	return width * _k if width > 0.0 else 1.0


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
			var d: float = TerminalBlockSymbol.RADIUS * 1.25
			aa_line(at + Vector2(-d, d), at + Vector2(d, -d), line, 1.6)
		else:
			aa_rect(Rect2(at - Vector2(s, s) * 0.5, Vector2(s, s)), fill)


## Labels of the strip terminals on the leads, left of the lead; a terminal
## of another strip than X1 ("X2:4") has the strip over its number, so
## terminals two cells apart keep their labels apart.
func _draw_strip_labels() -> void:
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(component)
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in placement.strips:
		if i < names.size():
			var at: Vector2 = Vector2(cells[names[i]]) * G + Vector2(-0.55 * G, 0.0)
			var label: String = placement.strips[i]
			var colon: int = label.find(":")
			if colon > 0:
				# Up on the drawing, however the symbol is turned.
				var up: Vector2 = SymbolGeometry.draw_transform(placement).affine_inverse().basis_xform(Vector2.UP).normalized()
				draw_label(label.left(colon), at + up * 0.6 * G, SchematicTheme.TERMINAL_SIZE + 1, SchematicTheme.DESIGNATION, 0, ["strip", i])
				draw_label(label.substr(colon + 1), at + up * 0.1 * G, SchematicTheme.TERMINAL_SIZE + 2, SchematicTheme.DESIGNATION, 0, ["strip", i])
			else:
				draw_label(label, at, SchematicTheme.TERMINAL_SIZE + 2, SchematicTheme.DESIGNATION, 0, ["strip", i])


## Draws designation and terminal numbers. Override to add more.
func _draw_labels() -> void:
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	var names: PackedStringArray = component.get_terminal_names()
	if names.size() == 2:
		draw_label(names[0], Vector2(0.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		draw_label(names[1], Vector2(0.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)


## True when a fault is injected into this component (simulation only).
func has_fault() -> bool:
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


## Terminal numbers of a multi-pole symbol: 1, 3, 5, 7 on top, 2, 4, 6, 8 below.
func _draw_pole_labels() -> void:
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in names.size():
		var x: float = (i / 2) * SymbolGeometry.POLE_SPACING * G + 0.3 * G
		var y: float = 0.4 * G if i % 2 == 0 else 2.6 * G
		draw_label(names[i], Vector2(x, y), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)


## Local x of pole [param pole] (0-3) of a multi-pole symbol.
static func pole_x(pole: int) -> float:
	return pole * SymbolGeometry.POLE_SPACING * G


## Small lightning bolt marking an injected fault.
func _draw_fault_marker(at: Vector2) -> void:
	var bolt: PackedVector2Array = PackedVector2Array([Vector2(2, -9), Vector2(-3, 0), Vector2(1, 0), Vector2(-2, 9), Vector2(4, -2), Vector2(0, -2), Vector2(2, -9)])
	for i: int in bolt.size():
		bolt[i] += at
	aa_polygon(bolt, SchematicTheme.FAULT)
	aa_polyline(bolt, SchematicTheme.LIVE, 1.0)


## Local point next to which the designation is written.
func _designation_anchor() -> Vector2:
	return Vector2(-1.3 * G, 1.5 * G)


## Draws upright text at a local anchor. Text extends away from the symbol
## axis: left/right of it when the anchor is to the side, above/below otherwise.
## [param line] > 0 writes a further line: below the first one when the text is
## beside the symbol, further away from the symbol when it is above or below.
## [param marking]: what the text marks ([kind, index]); found from the text
## when not given.
func draw_label(text: String, local_anchor: Vector2, font_size: int, color: Color, line: int = 0, marking: Array = []) -> void:
	var font: Font = AppTheme.schematic_font()
	var anchor: Vector2 = SymbolGeometry.draw_transform(placement) * local_anchor
	var axis_point: Vector2 = SymbolGeometry.draw_transform(placement) * Vector2(0.0, local_anchor.y)
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
	if marking.is_empty():
		marking = _marking_of(text)
	if not marking.is_empty() and marking[0] == "designation":
		_designation_anchor_drawn = local_anchor
	if marking.is_empty() or marking[0] == "purpose":
		if local_anchor == _designation_anchor_drawn:
			pos += placement.labels.get("designation", Vector2.ZERO) * G
	var own: Vector2 = Vector2.ZERO
	if not marking.is_empty():
		own = placement.labels.get(marking_key(marking[0], marking[1]), Vector2.ZERO)
		pos += own * G
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	text_rects.append(Rect2(Vector2(pos.x, pos.y - ascent), size))
	if not marking.is_empty():
		marking_rects.append([marking[0], marking[1], Rect2(Vector2(pos.x, pos.y - ascent), size), own])


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
