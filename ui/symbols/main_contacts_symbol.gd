class_name MainContactsSymbol
extends SchematicSymbol
## Three main contacts of a contactor (IEC 60617 S00284: NO contact with the
## contactor semicircle on the fixed contact), joined by a dashed mechanical
## link. Drawn where the armature is, so they visibly move.

const FIXED_END := Vector2(0, 20)
const PIVOT := Vector2(0, 40)
const OPEN_TIP := Vector2(-13, 18)
const CLOSED_TIP := Vector2(-3, 20)


func _designation_anchor() -> Vector2:
	return Vector2(-1.3 * G, 1.5 * G)


func _draw_shape(_color: Color, _width: float) -> void:
	var contacts: MainContacts = component as MainContacts
	var travel: float = contacts.get_travel()
	var middles: PackedVector2Array = PackedVector2Array()
	for pole: int in 3:
		var x: Vector2 = Vector2(pole_x(pole), 0)
		var closed: bool = contacts.is_path_closed(pole)
		var top: int = pole * 2
		var bottom: int = top + 1
		draw_line(x, x + FIXED_END, lead_color(top), lead_width(top))
		draw_arc(x + FIXED_END + Vector2(0, 4), 4.0, -PI * 0.5, PI * 0.5, 8, lead_color(top), SchematicTheme.LINE_WIDTH * 0.75)
		draw_line(x + Vector2(0, 3 * G), x + PIVOT, lead_color(bottom), lead_width(bottom))
		var tip: Vector2 = CLOSED_TIP if closed else OPEN_TIP.lerp(CLOSED_TIP, minf(travel, 0.85))
		if contacts.fault == SwitchingElement.Fault.OPEN:
			tip = OPEN_TIP
		draw_line(x + PIVOT, x + tip, lead_color(bottom), lead_width(bottom))
		middles.append(x + PIVOT.lerp(tip, 0.5))
	# The link is insulated from the contacts: never live.
	var link: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	draw_dashed_line(Vector2(middles[0].x - 12.0, middles[0].y), middles[2] - Vector2(1, 0), link, 1.5, 3.0)


func _draw_labels() -> void:
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	_draw_pole_labels()
