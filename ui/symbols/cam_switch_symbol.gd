class_name CamSwitchSymbol
extends SchematicSymbol
## Rotary cam switch, 1-4 poles, drawn as the other contacts: each blade
## pivots at its lower terminal, the turn actuator on the left joined to
## every blade by a dashed mechanical link. Positions 0-I: each pole an NO
## contact (1-2, 3-4 ...) that makes in position I. Positions I-0-II: each
## pole a changeover with the off position in the middle: the common below,
## the I side up to the left and the II side up to the right, each with its
## stop; in 0 the blade stands straight up between them. Its switching table
## (positions, a dot where a contact is closed) is written under the
## designation. Click it while simulating to turn it on to the next
## position (0 → I → 0 → II).

const FIXED_END := Vector2(0, 20)
const PIVOT := Vector2(0, 40)
## 0-I: as the NO contact (see [ContactSymbol]).
const OPEN_TIP := Vector2(-13, 18)
const CLOSED_TIP := Vector2(0, 14.45)
## I-0-II: on the stops of the I and the II side, as far from the pivot
## (see [ChangeoverSymbol]); the stops end STOP from the pivot.
const ONE_TIP := Vector2(-10, 18)
const TWO_TIP := Vector2(10, 18)
const STOP: float = 9.0
## Height of the dashed link, and where the actuator's head stands (0-I,
## I-0-II).
const LINK_Y: float = 30.0
const HEAD_X: float = -26.0
const CHANGEOVER_HEAD_X: float = -12.0


func flips_when_horizontal() -> bool:
	# As the changeover contact, the I-0-II switch is never mirrored.
	return (component as CamSwitch).positions == CamSwitch.Positions.OFF_ON


func is_interactive() -> bool:
	return true


func _designation_anchor() -> Vector2:
	return Vector2(-1.9 * G if (component as CamSwitch).positions == CamSwitch.Positions.OFF_ON else -1.25 * G, 1.5 * G)


## Where the blades head: 0-I 0 open, 1 closed; I-0-II 0 on I, 0.5 off, 1 on II.
func _target() -> float:
	var cam: CamSwitch = component as CamSwitch
	if cam.positions == CamSwitch.Positions.OFF_ON:
		return 1.0 if cam.position == CamSwitch.ONE else 0.0
	match cam.position:
		CamSwitch.ONE:
			return 0.0
		CamSwitch.TWO:
			return 1.0
	return 0.5


func _draw_shape(_color: Color, _width: float) -> void:
	var cam: CamSwitch = component as CamSwitch
	var changeover: bool = cam.positions == CamSwitch.Positions.CHANGEOVER
	var per: int = cam.pole_terminals()
	var s: float = shown("blade", _target())
	var tip: Vector2 = blade_tip(PIVOT, ONE_TIP, TWO_TIP, s) if changeover else blade_tip(PIVOT, OPEN_TIP, CLOSED_TIP, s)
	var link_x: PackedFloat32Array = PackedFloat32Array()
	for pole: int in cam.poles:
		var top: int = pole * per
		var common: int = top + per - 1
		# The pivot under the common's lead.
		var x: Vector2 = Vector2(SymbolGeometry.cam_terminal_cell(cam, common).x * G, 0)
		if changeover:
			var two: int = top + 1
			aa_polyline(PackedVector2Array([x + Vector2(-G, 0), x + Vector2(-G, 20), x + Vector2(-STOP, 20)]), lead_color(top), lead_width(top))
			aa_polyline(PackedVector2Array([x + Vector2(G, 0), x + Vector2(G, 20), x + Vector2(STOP, 20)]), lead_color(two), lead_width(two))
		else:
			aa_line(x, x + FIXED_END, lead_color(top), lead_width(top))
		aa_line(x + Vector2(0, 3 * G), x + PIVOT, lead_color(common), lead_width(common))
		draw_blade(x + PIVOT, x + tip, lead_color(common), lead_width(common))
		link_x.append(x.x + PIVOT.x + (tip.x - PIVOT.x) * (PIVOT.y - LINK_Y) / (PIVOT.y - tip.y))
	# The actuator and the link are insulated from the poles: never live.
	var mark: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	var head: float = CHANGEOVER_HEAD_X if changeover else HEAD_X
	aa_dashed_line(Vector2(head, LINK_Y), Vector2(link_x[link_x.size() - 1] - 1.0, LINK_Y), mark, 1.4, 2.5)
	# The turn head stays straight; it turns over with the knob.
	var flip: float = -1.0 if cam.position != CamSwitch.OFF and (not changeover or cam.position == CamSwitch.ONE) else 1.0
	aa_line(Vector2(head, LINK_Y - 7), Vector2(head, LINK_Y + 7), mark, 1.8)
	aa_line(Vector2(head, LINK_Y - 7), Vector2(head - 5 * flip, LINK_Y - 7), mark, 1.8)
	aa_line(Vector2(head, LINK_Y + 7), Vector2(head + 5 * flip, LINK_Y + 7), mark, 1.8)


func _draw_labels() -> void:
	var cam: CamSwitch = component as CamSwitch
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	# Its positions as marked on the front, a dot under those its contacts
	# are closed in (the first pole's for the others); the one it is in
	# (while simulating) shown by the blades.
	var names: PackedStringArray = component.get_terminal_names()
	if cam.positions == CamSwitch.Positions.OFF_ON:
		draw_position_table(PackedStringArray(["0", "I"]), [["", [false, true]]], _designation_anchor(), 1)
		_draw_pole_labels()
		return
	draw_position_table(PackedStringArray(["I", "0", "II"]), [[names[0] + "-" + names[2], [true, false, false]], [names[1] + "-" + names[2], [false, false, true]]], _designation_anchor(), 1)
	for pole: int in cam.poles:
		var x: float = SymbolGeometry.cam_terminal_cell(cam, pole * 3).x * G
		draw_label(names[pole * 3], Vector2(x - 0.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		draw_label(names[pole * 3 + 1], Vector2(x + 2.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		draw_label(names[pole * 3 + 2], Vector2(x + 1.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
