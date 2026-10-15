class_name ThreePoleFuseSymbol
extends SchematicSymbol
## Multi-pole fuse (IEC 60617 S00362), the fuses side by side. Each pole blows on its own and
## shows the conductor broken with a cross; click to replace the blown ones.
## A multi-pole fuse holder draws each pole as a blade carrying its fuse,
## joined by a dashed link; click it to open or close it.

const BOX := Rect2(-6, 14, 12, 32)


func is_interactive() -> bool:
	return (component as ThreePoleFuse).any_blown() or (component as ThreePoleFuse).holder


func _draw_shape(_color: Color, width: float) -> void:
	var color: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	var fuse: ThreePoleFuse = component as ThreePoleFuse
	if fuse.holder:
		var middles: PackedVector2Array = PackedVector2Array()
		for pole: int in fuse.poles:
			middles.append(FuseSymbol._draw_holder(self, Vector2(pole_x(pole), 0), pole * 2, pole * 2 + 1, fuse.switched_on, fuse.blown[pole] == 1, color, width))
		# The link runs between the fuse bodies, never across them.
		var link: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
		var gap: float = FuseSymbol.holder_half_extent(fuse.switched_on) + 2.0
		for pole: int in range(fuse.poles - 1):
			var from: Vector2 = middles[pole] + Vector2(gap, 0)
			var to: Vector2 = middles[pole + 1] - Vector2(gap, 0)
			if to.x > from.x:
				draw_dashed_line(from, to, link, 1.5, 3.0, true, true)
		return
	for pole: int in fuse.poles:
		var x: Vector2 = Vector2(pole_x(pole), 0)
		var top: int = pole * 2
		var bottom: int = top + 1
		var box: Rect2 = Rect2(BOX.position + x, BOX.size)
		draw_line(x, x + Vector2(0, BOX.position.y), lead_color(top), lead_width(top), true)
		draw_line(x + Vector2(0, BOX.end.y), x + Vector2(0, 3 * G), lead_color(bottom), lead_width(bottom), true)
		draw_rect(box, color, false, SchematicTheme.LINE_WIDTH)
		if fuse.blown[pole] == 1:
			draw_line(x + Vector2(0, BOX.position.y), x + Vector2(0, 24), lead_color(top), SchematicTheme.LINE_WIDTH, true)
			draw_line(x + Vector2(0, 36), x + Vector2(0, BOX.end.y), lead_color(bottom), SchematicTheme.LINE_WIDTH, true)
			draw_line(x + Vector2(-5, 25), x + Vector2(5, 35), SchematicTheme.FAULT, 2.5, true)
			draw_line(x + Vector2(-5, 35), x + Vector2(5, 25), SchematicTheme.FAULT, 2.5, true)
		else:
			var pole_color: Color = lead_color(top) if reach(top) != REACH_NONE else color
			draw_line(x + Vector2(0, BOX.position.y), x + Vector2(0, BOX.end.y), pole_color, width, true)


func _draw_labels() -> void:
	draw_label(designation_text(), Vector2(-1.0 * G, 1.5 * G), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	_draw_pole_labels()
