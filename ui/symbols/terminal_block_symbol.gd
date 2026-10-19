class_name TerminalBlockSymbol
extends SchematicSymbol
## Terminal of a terminal strip (IEC 60617 S00017/S00018 style): a small circle
## with a slash, sitting on the wire, with its free label beside it.

const RADIUS: float = 6.0


func _draw_shape(_color: Color, _width: float) -> void:
	var line: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	aa_circle(Vector2.ZERO, RADIUS, SchematicTheme.BACKGROUND)
	aa_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 20, line, 1.6)
	var d: Vector2 = slash(placement)
	aa_line(-d, d, line, 1.6)


## Half the slash of a strip terminal's mark in local pixels of a symbol
## placed by [param p]: always "/" on the drawing, however it is turned.
static func slash(p: Placement) -> Vector2:
	return SymbolGeometry.draw_transform(p).basis_xform_inv(Vector2(RADIUS, -RADIUS) * 1.25)


func _draw_labels() -> void:
	# Strip and number on one line: "X2-6".
	var text: String = CabinetDevices.terminal_text((component as TerminalBlock).label)
	if text.is_empty():
		text = component.designation
	draw_label(text, Vector2(-0.55 * G, 0.0), SchematicTheme.TERMINAL_SIZE + 2, SchematicTheme.DESIGNATION)
