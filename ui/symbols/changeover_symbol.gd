class_name ChangeoverSymbol
extends SchematicSymbol
## Changeover contact (IEC 60617 S00230): common terminal at the bottom, NO
## fixed contact straight above it, NC fixed contact one cell to the right with
## a hook. The blade rests on the NC hook and swings to the NO contact.

const PIVOT := Vector2(0, 40)
const NO_END := Vector2(0, 20)
const NC_TIP := Vector2(10, 18)
const NO_TIP := Vector2(-3, 20)


func _designation_anchor() -> Vector2:
	var delayed: bool = (component as ChangeoverContact).delayed
	return Vector2(-1.9 * G if delayed else -1.3 * G, 1.5 * G)


func _draw_shape(color: Color, _width: float) -> void:
	var contact: ChangeoverContact = component as ChangeoverContact
	# Terminal order: common (0), NC side (1), NO side (2).
	draw_line(Vector2(0, 3 * G), PIVOT, lead_color(0), lead_width(0))
	draw_line(Vector2(0, 0), NO_END, lead_color(2), lead_width(2))
	draw_line(Vector2(G, 0), Vector2(G, 20), lead_color(1), lead_width(1))
	draw_line(Vector2(G, 20), Vector2(9, 20), lead_color(1), lead_width(1))
	var tip: Vector2
	if contact.is_path_closed(ChangeoverContact.PATH_NO):
		tip = NO_TIP
	elif contact.is_path_closed(ChangeoverContact.PATH_NC):
		tip = NC_TIP
	else:
		# In transit (or burnt): between the two fixed contacts.
		var t: float = clampf(contact.get_travel(), 0.15, 0.85)
		tip = NC_TIP.lerp(Vector2(-13, 18), t)
	draw_line(PIVOT, tip, lead_color(0), lead_width(0))
	if contact.delayed and contact.linked_coil is TimerRelay:
		var on_delay: bool = (contact.linked_coil as TimerRelay).mode == TimerRelay.Mode.ON_DELAY
		var middle: Vector2 = PIVOT.lerp(tip, 0.5)
		var c: Vector2 = Vector2(-12.0, middle.y)
		var w: float = SchematicTheme.LINE_WIDTH * 0.75
		var mark: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
		if on_delay:
			draw_arc(c, 6.0, PI * 0.5, PI * 1.5, 12, mark, w)
			draw_line(Vector2(c.x, middle.y - 6), Vector2(middle.x - 1, middle.y - 6), mark, w)
			draw_line(Vector2(c.x, middle.y + 6), Vector2(middle.x - 1, middle.y + 6), mark, w)
		else:
			var c2: Vector2 = Vector2(-20.0, middle.y)
			draw_arc(c2, 6.0, -PI * 0.5, PI * 0.5, 12, mark, w)
			draw_line(Vector2(c2.x + 6, middle.y - 2.5), Vector2(middle.x - 1, middle.y - 2.5), mark, w)
			draw_line(Vector2(c2.x + 6, middle.y + 2.5), Vector2(middle.x - 1, middle.y + 2.5), mark, w)


func _draw_labels() -> void:
	draw_label(component.designation, _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.TEXT)
	var names: PackedStringArray = component.get_terminal_names()
	draw_label(names[0], Vector2(0.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[2], Vector2(-0.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[1], Vector2(1.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
