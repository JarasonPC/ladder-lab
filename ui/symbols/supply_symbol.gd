class_name SupplySymbol
extends SchematicSymbol
## Supply point (L or N): terminal circle (IEC 60617 S00017) with its label.


func _draw_shape(color: Color, width: float) -> void:
	var c: Color = color if live.has(REACH_L) or live.has(REACH_N) else _conductor_color()
	draw_circle(Vector2.ZERO, 5.0, SchematicTheme.BACKGROUND)
	draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 20, c, width)


func _draw_labels() -> void:
	# Several supply points may share a conductor ("L", "L.2"); show the conductor.
	var supply: PowerSupply = component as PowerSupply
	var text: String = "L" if supply.conductor == PowerSupply.Conductor.L else "N"
	draw_label(text, Vector2(-0.6 * G, 0.0), SchematicTheme.LABEL_SIZE + 2, _conductor_color())


func _conductor_color() -> Color:
	var supply: PowerSupply = component as PowerSupply
	return SchematicTheme.L_COLOR if supply.conductor == PowerSupply.Conductor.L else SchematicTheme.N_COLOR
