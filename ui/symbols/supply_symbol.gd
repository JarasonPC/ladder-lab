class_name SupplySymbol
extends SchematicSymbol
## Supply point (L, L1, L2, L3, N or the DC poles + and -) as in the guide: a
## circle with the conductor name above the terminal, joined to it by a short
## lead.

const CIRCLE := Vector2(0, -19)
const RADIUS: float = 10.0


func _draw_shape(color: Color, width: float) -> void:
	var c: Color = color if reach(0) != REACH_NONE else SchematicTheme.LINE
	aa_line(CIRCLE + Vector2(0, RADIUS), Vector2.ZERO, lead_color(0), lead_width(0))
	aa_circle(CIRCLE, RADIUS, SchematicTheme.BACKGROUND)
	aa_arc(CIRCLE, RADIUS, 0.0, TAU, 28, c, minf(width, 2.0))


func _draw_labels() -> void:
	# Several supply points may share a conductor ("L", "L.2"); show the conductor.
	var text: String = (component as PowerSupply).conductor_name()
	var font: Font = AppTheme.schematic_font()
	var size: int = 11 if text.length() > 1 else 12
	if (component as PowerSupply).is_dc():
		# The DC poles: a bigger sign, a real minus sign when the font has one.
		size = 16
		if text == "-" and font.has_char(0x2212):
			text = "−"
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var center: Vector2 = to_upright(CIRCLE)
	draw_string(font, center + Vector2(-w * 0.5, font.get_ascent(size) * 0.5 - 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SchematicTheme.TEXT)
