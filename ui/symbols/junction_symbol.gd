class_name JunctionSymbol
extends SchematicSymbol
## Wire branch point. The dot itself is drawn by [WireLayer] where three or
## more wires meet; the symbol only marks an unused junction while editing.


func _draw_shape(color: Color, _width: float) -> void:
	draw_circle(Vector2.ZERO, 2.0, color)


func _draw_labels() -> void:
	pass
