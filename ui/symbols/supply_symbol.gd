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
	draw_label(text, Vector2(-0.6 * G, 0.0), SchematicTheme.LABEL_SIZE + 2, _conductor_color())


func _conductor_color() -> Color:
	match (component as PowerSupply).conductor:
		PowerSupply.Conductor.N:
			return SchematicTheme.N_COLOR
		PowerSupply.Conductor.L2:
			return SchematicTheme.L2_COLOR
		PowerSupply.Conductor.L3:
			return SchematicTheme.L3_COLOR
	return SchematicTheme.L_COLOR
