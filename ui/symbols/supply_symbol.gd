class_name SupplySymbol
extends SchematicSymbol
## Supply point (L, L1, L2, L3 or N): terminal circle (IEC 60617 S00017) with its label.


func _draw_shape(color: Color, width: float) -> void:
	var c: Color = color if reach(0) != REACH_NONE else _conductor_color()
	draw_circle(Vector2.ZERO, 5.0, SchematicTheme.BACKGROUND)
	draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 20, c, width)


func _draw_labels() -> void:
	# Several supply points may share a conductor ("L", "L.2"); show the conductor.
	var text: String = (component as PowerSupply).conductor_name()
	# Centred above the terminal on screen, so L1, L2, L3 side by side do not overlap.
	var font: Font = AppTheme.schematic_font()
	var size: int = SchematicTheme.LABEL_SIZE + 2
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(-w * 0.5, -8.0 - font.get_descent(size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _conductor_color())


func _conductor_color() -> Color:
	match (component as PowerSupply).conductor:
		PowerSupply.Conductor.N:
			return SchematicTheme.N_COLOR
		PowerSupply.Conductor.L2:
			return SchematicTheme.L2_COLOR
		PowerSupply.Conductor.L3:
			return SchematicTheme.L3_COLOR
	return SchematicTheme.L_COLOR
