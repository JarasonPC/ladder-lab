class_name ThreePoleFuseSymbol
extends SchematicSymbol
## Three fuses (IEC 60617 S00362) side by side. Each pole blows on its own and
## shows the conductor broken with a cross; click to replace the blown ones.

const BOX := Rect2(-6, 14, 12, 32)


func is_interactive() -> bool:
	return (component as ThreePoleFuse).any_blown()


func _draw_shape(_color: Color, width: float) -> void:
	var color: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	var fuse: ThreePoleFuse = component as ThreePoleFuse
	for pole: int in 3:
		var x: Vector2 = Vector2(pole_x(pole), 0)
		var top: int = pole * 2
		var bottom: int = top + 1
		var box: Rect2 = Rect2(BOX.position + x, BOX.size)
		draw_line(x, x + Vector2(0, BOX.position.y), lead_color(top), lead_width(top))
		draw_line(x + Vector2(0, BOX.end.y), x + Vector2(0, 3 * G), lead_color(bottom), lead_width(bottom))
		draw_rect(box, lead_color(top) if reach(top) != REACH_NONE else color, false, SchematicTheme.LINE_WIDTH)
		if fuse.blown[pole] == 1:
			draw_line(x + Vector2(0, BOX.position.y), x + Vector2(0, 24), lead_color(top), SchematicTheme.LINE_WIDTH)
			draw_line(x + Vector2(0, 36), x + Vector2(0, BOX.end.y), lead_color(bottom), SchematicTheme.LINE_WIDTH)
			draw_line(x + Vector2(-5, 25), x + Vector2(5, 35), SchematicTheme.FAULT, 2.5)
			draw_line(x + Vector2(-5, 35), x + Vector2(5, 25), SchematicTheme.FAULT, 2.5)
		else:
			var pole_color: Color = lead_color(top) if reach(top) != REACH_NONE else color
			draw_line(x + Vector2(0, BOX.position.y), x + Vector2(0, BOX.end.y), pole_color, width)


func _draw_labels() -> void:
	draw_label(component.designation, Vector2(-1.0 * G, 1.5 * G), SchematicTheme.LABEL_SIZE, SchematicTheme.TEXT)
	_draw_pole_labels()
