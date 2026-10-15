class_name ThreePoleFuseSymbol
extends SchematicSymbol
## Three fuses (IEC 60617 S00362) side by side. Each pole blows on its own and
## shows the conductor broken with a cross; click to replace the blown ones.
## A three-pole fuse holder draws each pole as a blade carrying its fuse,
## joined by a dashed link; click it to open or close it.

const BOX := Rect2(-6, 14, 12, 32)


func is_interactive() -> bool:
	return (component as ThreePoleFuse).any_blown() or (component as ThreePoleFuse).holder


func _draw_shape(_color: Color, width: float) -> void:
	var color: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	var fuse: ThreePoleFuse = component as ThreePoleFuse
	if fuse.holder:
		var middles: PackedVector2Array = PackedVector2Array()
		for pole: int in 3:
			middles.append(FuseSymbol._draw_holder(self, Vector2(pole_x(pole), 0), pole * 2, pole * 2 + 1, fuse.switched_on, fuse.blown[pole] == 1, color, width))
		var link: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
		draw_dashed_line(Vector2(middles[0].x - 14.0, middles[0].y), middles[2] - Vector2(5, 0), link, 1.5, 3.0)
		return
	for pole: int in 3:
		var x: Vector2 = Vector2(pole_x(pole), 0)
		var top: int = pole * 2
		var bottom: int = top + 1
		var box: Rect2 = Rect2(BOX.position + x, BOX.size)
		draw_line(x, x + Vector2(0, BOX.position.y), lead_color(top), lead_width(top))
		draw_line(x + Vector2(0, BOX.end.y), x + Vector2(0, 3 * G), lead_color(bottom), lead_width(bottom))
		draw_rect(box, color, false, SchematicTheme.LINE_WIDTH)
		if fuse.blown[pole] == 1:
			draw_line(x + Vector2(0, BOX.position.y), x + Vector2(0, 24), lead_color(top), SchematicTheme.LINE_WIDTH)
			draw_line(x + Vector2(0, 36), x + Vector2(0, BOX.end.y), lead_color(bottom), SchematicTheme.LINE_WIDTH)
			draw_line(x + Vector2(-5, 25), x + Vector2(5, 35), SchematicTheme.FAULT, 2.5)
			draw_line(x + Vector2(-5, 35), x + Vector2(5, 25), SchematicTheme.FAULT, 2.5)
		else:
			var pole_color: Color = lead_color(top) if reach(top) != REACH_NONE else color
			draw_line(x + Vector2(0, BOX.position.y), x + Vector2(0, BOX.end.y), pole_color, width)


func _draw_labels() -> void:
	draw_label(designation_text(), Vector2(-1.0 * G, 1.5 * G), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	_draw_pole_labels()
