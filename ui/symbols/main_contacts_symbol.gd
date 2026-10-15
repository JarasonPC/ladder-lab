class_name MainContactsSymbol
extends SchematicSymbol
## Main contacts of a contactor, 1-4 poles (IEC 60617 S00284: NO contact with
## the contactor semicircle on the fixed contact), drawn as in the guide: each
## blade pivots at the lower terminal (2, 4, 6, 8) and stands off to the left
## of the fixed contact below the upper terminal (1, 3, 5, 7); several poles
## are joined by a dashed mechanical link. Drawn where the armature is, so the
## blades visibly move.

## End of the upper lead, the bottom of the semicircle.
const FIXED_END := Vector2(0, 21.5)
## Centre of the semicircle, open to the right.
const ARC_CENTER := Vector2(0, 18)
const ARC_RADIUS: float = 3.5
const PIVOT := Vector2(0, 42)
const OPEN_TIP := Vector2(-10, 18)
const CLOSED_TIP := Vector2(-3.5, 18)
const LINK_Y: float = 30.0


func flips_when_horizontal() -> bool:
	return true


func _designation_anchor() -> Vector2:
	return Vector2(-1.3 * G, 1.5 * G)


func _draw_shape(_color: Color, _width: float) -> void:
	var contacts: MainContacts = component as MainContacts
	var travel: float = contacts.get_travel()
	var poles: int = component.get_terminal_names().size() / 2
	var link_x: PackedFloat32Array = PackedFloat32Array()
	for pole: int in poles:
		var x: Vector2 = Vector2(pole_x(pole), 0)
		var closed: bool = contacts.is_path_closed(pole)
		var top: int = pole * 2
		var bottom: int = top + 1
		aa_line(x, x + FIXED_END, lead_color(top), lead_width(top))
		aa_arc(x + ARC_CENTER, ARC_RADIUS, PI * 0.5, PI * 1.5, 10, lead_color(top), SchematicTheme.LINE_WIDTH * 0.8)
		aa_line(x + Vector2(0, 3 * G), x + PIVOT, lead_color(bottom), lead_width(bottom))
		var tip: Vector2 = CLOSED_TIP if closed else OPEN_TIP.lerp(CLOSED_TIP, minf(travel, 0.85))
		if contacts.fault == SwitchingElement.Fault.OPEN:
			tip = OPEN_TIP
		draw_blade(x + PIVOT, x + tip, lead_color(bottom), lead_width(bottom))
		link_x.append(x.x + PIVOT.x + (tip.x - PIVOT.x) * (PIVOT.y - LINK_Y) / (PIVOT.y - tip.y))
	if poles > 1:
		# The link is insulated from the contacts: never live.
		var link: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
		aa_dashed_line(Vector2(link_x[0], LINK_Y), Vector2(link_x[poles - 1] - 1.0, LINK_Y), link, 1.5, 3.0)


func _draw_labels() -> void:
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	_draw_pole_labels()
