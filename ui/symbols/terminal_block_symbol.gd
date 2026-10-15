class_name TerminalBlockSymbol
extends SchematicSymbol
## Terminal of a terminal strip (IEC 60617 S00017/S00018 style): a small circle
## with a slash, sitting on the wire, with its free label beside it.

const RADIUS: float = 6.0


func _draw_shape(_color: Color, _width: float) -> void:
	var line: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	draw_circle(Vector2.ZERO, RADIUS, SchematicTheme.BACKGROUND, true, -1.0, true)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 20, line, 1.6, true)
	var d: float = RADIUS * 1.25
	draw_line(Vector2(-d, d), Vector2(d, -d), line, 1.6, true)


func _draw_labels() -> void:
	var text: String = (component as TerminalBlock).label
	if text.is_empty():
		text = component.designation
	draw_label(text, Vector2(-0.55 * G, 0.0), SchematicTheme.TERMINAL_SIZE + 2, SchematicTheme.DESIGNATION)
