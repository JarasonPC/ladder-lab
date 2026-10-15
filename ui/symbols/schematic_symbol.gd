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
	var t: Transform2D = SymbolGeometry.draw_transform(placement)
	draw_set_transform_matrix(t)
	if hovered and is_interactive():
		var body: Rect2 = SymbolGeometry.local_body(component)
		draw_rect(Rect2(body.position * G, body.size * G), SchematicTheme.HOVER)
	_draw_shape(stroke_color(), stroke_width())
	if show_labels:
		_draw_terminals()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if show_labels:
		_draw_labels()
	if has_fault():
		_draw_fault_marker(to_upright(Vector2(0.9 * G, 0.9 * G)))


func reach(terminal_index: int) -> int:
	return live[terminal_index] if terminal_index < live.size() else REACH_NONE


## True when a phase (or several supplies) reaches any terminal.
func any_live() -> bool:
	for code: int in live:
		if code != REACH_NONE and code != REACH_N:
			return true
	return false


## Colour of the symbol body. Voltage reach shows on the leads only; a coil
## is the exception and takes the colour of the first phase that reaches it
## (else N when N does).
func stroke_color() -> Color:
	if warning:
		return SchematicTheme.WARNING
	if not (component is Coil):
		return SchematicTheme.LINE
	for code: int in live:
		if code != REACH_NONE and code != REACH_N:
			return SchematicTheme.reach_color(code)
	return SchematicTheme.NEUTRAL if live.has(REACH_N) else SchematicTheme.LINE


func stroke_width() -> float:
	if not (component is Coil):
		return SchematicTheme.LINE_WIDTH
	return SchematicTheme.LIVE_WIDTH if warning or any_live() or live.has(REACH_N) else SchematicTheme.LINE_WIDTH


## Colour of the lead and contact parts on the side of one terminal.
func lead_color(terminal_index: int) -> Color:
	if warning:
		return SchematicTheme.WARNING
	return SchematicTheme.reach_color(reach(terminal_index))


func lead_width(terminal_index: int) -> float:
	return SchematicTheme.LIVE_WIDTH if warning or reach(terminal_index) != REACH_NONE else SchematicTheme.LINE_WIDTH


## Draws the symbol in local coordinates. Override.
func _draw_shape(_color: Color, _width: float) -> void:
	pass


## Designation as written on the drawing: "-KM1" (ČSN EN 81346 prefix).
func designation_text() -> String:
	return "-" + component.designation


## Square at every terminal, filled with what reaches it (black when nothing).
func _draw_terminals() -> void:
	if component is Junction:
		return
	var s: float = SchematicTheme.TERMINAL_SQUARE
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(component)
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in names.size():
		var at: Vector2 = Vector2(cells[names[i]]) * G
		var code: int = reach(i)
		var fill: Color = SchematicTheme.TERMINAL_DEAD if code == REACH_NONE else SchematicTheme.reach_color(code)
		draw_rect(Rect2(at - Vector2(s, s) * 0.5, Vector2(s, s)), fill)


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


## Terminal numbers of a three-pole symbol: 1, 3, 5 on top, 2, 4, 6 below.
func _draw_pole_labels() -> void:
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in names.size():
		var x: float = (i / 2) * SymbolGeometry.POLE_SPACING * G + 0.3 * G
		var y: float = 0.4 * G if i % 2 == 0 else 2.6 * G
		draw_label(names[i], Vector2(x, y), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)


## Local x of pole [param pole] (0-2) of a three-pole symbol.
static func pole_x(pole: int) -> float:
	return pole * SymbolGeometry.POLE_SPACING * G


## Small lightning bolt marking an injected fault.
func _draw_fault_marker(at: Vector2) -> void:
	var bolt: PackedVector2Array = PackedVector2Array([Vector2(2, -9), Vector2(-3, 0), Vector2(1, 0), Vector2(-2, 9), Vector2(4, -2), Vector2(0, -2), Vector2(2, -9)])
	for i: int in bolt.size():
		bolt[i] += at
	draw_colored_polygon(bolt, SchematicTheme.FAULT)
	draw_polyline(bolt, SchematicTheme.LIVE, 1.0)


## Local point next to which the designation is written.
func _designation_anchor() -> Vector2:
	return Vector2(-1.3 * G, 1.5 * G)


## Draws upright text at a local anchor. Text extends away from the symbol
## axis: left/right of it when the anchor is to the side, above/below otherwise.
## [param line] > 0 writes a further line: below the first one when the text is
## beside the symbol, further away from the symbol when it is above or below.
func draw_label(text: String, local_anchor: Vector2, font_size: int, color: Color, line: int = 0) -> void:
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
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


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
