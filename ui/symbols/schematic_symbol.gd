class_name SchematicSymbol
extends Node2D
## Base for symbols drawn with _draw() per IEC 60617. Subclasses draw in local
## pixel coordinates of the unturned symbol (first terminal at the origin,
## second terminal [constant SymbolGeometry.SPAN] cells below); the placement
## mirror and rotation are applied here. Labels are always drawn upright.

const G: float = float(SymbolGeometry.GRID)

var component: CircuitComponent
var placement: Placement
## Set by the view from the last [StepResult].
var carries_current: bool = false
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
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if show_labels:
		_draw_labels()


func stroke_color() -> Color:
	if warning:
		return SchematicTheme.WARNING
	return SchematicTheme.CURRENT if carries_current else SchematicTheme.LINE


func stroke_width() -> float:
	return SchematicTheme.CURRENT_WIDTH if carries_current or warning else SchematicTheme.LINE_WIDTH


## Draws the symbol in local coordinates. Override.
func _draw_shape(_color: Color, _width: float) -> void:
	pass


## Draws designation and terminal numbers. Override to add more.
func _draw_labels() -> void:
	draw_label(component.designation, _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.TEXT)
	var names: PackedStringArray = component.get_terminal_names()
	if names.size() == 2:
		draw_label(names[0], Vector2(0.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		draw_label(names[1], Vector2(0.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)


## Local point next to which the designation is written.
func _designation_anchor() -> Vector2:
	return Vector2(-1.3 * G, 1.5 * G)


## Draws upright text at a local anchor. Text extends away from the symbol
## axis: left/right of it when the anchor is to the side, above/below otherwise.
## [param line] > 0 writes a further line: below the first one when the text is
## beside the symbol, further away from the symbol when it is above or below.
func draw_label(text: String, local_anchor: Vector2, font_size: int, color: Color, line: int = 0) -> void:
	var font: Font = ThemeDB.fallback_font
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
	if line > 0:
		var line_height: float = font.get_height(font_size)
		var direction: float = -1.0 if absf(away.x) < absf(away.y) and away.y < 0.0 else 1.0
		pos.y += direction * line * line_height
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Point of the unturned symbol mapped to upright node coordinates.
func to_upright(local_point: Vector2) -> Vector2:
	return SymbolGeometry.draw_transform(placement) * local_point
