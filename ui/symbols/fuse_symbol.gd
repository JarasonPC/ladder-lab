class_name FuseSymbol
extends SchematicSymbol
## Fuse (IEC 60617 S00362): rectangle with the conductor running through.
## A blown fuse shows the conductor broken with a cross.

const BOX := Rect2(-6, 14, 12, 32)


func is_interactive() -> bool:
	return (component as Fuse).tripped


func _draw_shape(color: Color, width: float) -> void:
	var fuse: Fuse = component as Fuse
	draw_line(Vector2(0, 0), Vector2(0, BOX.position.y), lead_color(0), lead_width(0))
	draw_line(Vector2(0, BOX.end.y), Vector2(0, 3 * G), lead_color(1), lead_width(1))
	draw_rect(BOX, color, false, SchematicTheme.LINE_WIDTH)
	if fuse.tripped:
		draw_line(Vector2(0, BOX.position.y), Vector2(0, 24), lead_color(0), SchematicTheme.LINE_WIDTH)
		draw_line(Vector2(0, 36), Vector2(0, BOX.end.y), lead_color(1), SchematicTheme.LINE_WIDTH)
		draw_line(Vector2(-5, 25), Vector2(5, 35), SchematicTheme.FAULT, 2.5)
		draw_line(Vector2(-5, 35), Vector2(5, 25), SchematicTheme.FAULT, 2.5)
	else:
		draw_line(Vector2(0, BOX.position.y), Vector2(0, BOX.end.y), color, width)


func _draw_labels() -> void:
	draw_label(component.designation, Vector2(-1.0 * G, 1.5 * G), SchematicTheme.LABEL_SIZE, SchematicTheme.TEXT)
	var names: PackedStringArray = component.get_terminal_names()
	draw_label(names[0], Vector2(0.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[1], Vector2(0.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
