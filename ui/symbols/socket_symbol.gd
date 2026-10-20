class_name SocketSymbol
extends SchematicSymbol
## Socket outlet 230 V (see [SocketOutlet]): its plate with a female contact
## (IEC 60617 S00031) for each of L, N and the protective pin PE in the
## middle; a double socket shows a second plate behind. While simulating,
## "230 V" is written under it while L and N have their voltage.

## Female contacts: the leads end on top of a cup this far down, this wide.
const CUP_Y: float = 22.0
const CUP_RADIUS: float = 5.0
## The plate round the contacts.
const PLATE := Rect2(-12, 12, 104, 22)
## Offset of the second plate of a double socket, behind the first.
const BEHIND := Vector2(4, 4)


func _draw_shape(color: Color, width: float) -> void:
	if (component as SocketOutlet).gangs > 1:
		var back: Rect2 = Rect2(PLATE.position + BEHIND, PLATE.size)
		aa_polyline(PackedVector2Array([Vector2(back.end.x, back.position.y + BEHIND.y), back.end, Vector2(back.position.x + BEHIND.x, back.end.y)]), color, width)
	aa_rect(PLATE, SchematicTheme.BACKGROUND)
	aa_rect(PLATE, color, false, width)
	for i: int in 3:
		var x: float = SymbolGeometry.local_terminals(component)[component.get_terminal_names()[i]].x * G
		aa_line(Vector2(x, 0), Vector2(x, CUP_Y - CUP_RADIUS), lead_color(i), lead_width(i))
		aa_arc(Vector2(x, CUP_Y), CUP_RADIUS, PI, TAU, 12, color, width)


## True while L has a phase and N its return: the socket has its voltage.
func is_live() -> bool:
	var l: int = reach(0)
	return l >= StepResult.REACH_L1 and l <= StepResult.REACH_L3 and reach(1) == StepResult.REACH_N


func _draw_labels() -> void:
	var socket: SocketOutlet = component as SocketOutlet
	var anchor: Vector2 = _designation_anchor()
	draw_label(designation_text(), anchor, SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	draw_label(("2× " if socket.gangs > 1 else "") + "16 A", anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
	var line: int = 2
	if not is_equal_approx(socket.height, SocketOutlet.STANDARD_HEIGHT):
		draw_label(LightSwitchSymbol.height_text(socket.height), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, line)
		line += 1
	if is_live():
		draw_label("230 V", anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.reach_color(reach(0)), line)
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in names.size():
		var x: float = SymbolGeometry.local_terminals(component)[names[i]].x * G
		draw_label(names[i], Vector2(x + 0.3 * G, 0.3 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)


func _designation_anchor() -> Vector2:
	return Vector2(-1.0 * G, 1.2 * G)
