class_name NetworkSwitchSymbol
extends SchematicSymbol
## Network switch: a box with its supply L+ M on top and the RJ45 ports
## P1-P4 below, each drawn as a socket that lights up while the port has a
## link; arrows both ways in the box say that it passes data on. The box
## is filled while the switch has its supply.

const BOX := Rect2(-G, G, SymbolGeometry.SWITCH_WIDTH * G, (SymbolGeometry.SWITCH_HEIGHT - 2) * G)
const PREVIEW_BOX := Rect2(0.0, 0.0, 100.0, 50.0)
## Half the width and height of a socket.
const SOCKET := Vector2(6.0, 4.5)


func _draw_shape(color: Color, width: float) -> void:
	if preview:
		_draw_preview(color, width)
		return
	var hub: NetworkSwitch = component as NetworkSwitch
	for i: int in NetworkSwitch.FIRST_PORT:
		var x: float = SymbolGeometry.switch_terminal_cell(i).x * G
		aa_line(Vector2(x, 0), Vector2(x, BOX.position.y), lead_color(i), lead_width(i))
	for k: int in NetworkSwitch.PORTS:
		var x: float = SymbolGeometry.switch_terminal_cell(NetworkSwitch.port_terminal(k)).x * G
		aa_line(Vector2(x, BOX.end.y), Vector2(x, SymbolGeometry.SWITCH_HEIGHT * G), lead_color(NetworkSwitch.port_terminal(k)), lead_width(NetworkSwitch.port_terminal(k)))
	if hub.energized:
		aa_rect(BOX, SchematicTheme.COIL_ON)
	aa_rect(BOX, color, false, width)
	for k: int in NetworkSwitch.PORTS:
		var x: float = SymbolGeometry.switch_terminal_cell(NetworkSwitch.port_terminal(k)).x * G
		draw_socket(self, Vector2(x, BOX.end.y - SOCKET.y - 3.0), hub.port_linked(k), color)
	_draw_arrows(Vector2(5.0 * G, BOX.position.y + 13.0), color)


## Two arrows pointing both ways: data passed on.
func _draw_arrows(at: Vector2, color: Color) -> void:
	var half: float = 14.0
	aa_line(at + Vector2(-half, -3.0), at + Vector2(half, -3.0), color, 1.2)
	aa_polyline(PackedVector2Array([at + Vector2(half - 4.0, -6.0), at + Vector2(half, -3.0), at + Vector2(half - 4.0, 0.0)]), color, 1.2)
	aa_line(at + Vector2(-half, 3.0), at + Vector2(half, 3.0), color, 1.2)
	aa_polyline(PackedVector2Array([at + Vector2(-half + 4.0, 0.0), at + Vector2(-half, 3.0), at + Vector2(-half + 4.0, 6.0)]), color, 1.2)


## An RJ45 socket seen from the front centred at [param at] (the latch slot
## below), filled while [param lit] (the port has a link).
static func draw_socket(symbol: SchematicSymbol, at: Vector2, lit: bool, color: Color) -> void:
	var s: Vector2 = SOCKET
	var outline: PackedVector2Array = PackedVector2Array([
		at + Vector2(-s.x, -s.y), at + Vector2(s.x, -s.y), at + Vector2(s.x, s.y - 2.0),
		at + Vector2(2.5, s.y - 2.0), at + Vector2(2.5, s.y), at + Vector2(-2.5, s.y),
		at + Vector2(-2.5, s.y - 2.0), at + Vector2(-s.x, s.y - 2.0), at + Vector2(-s.x, -s.y)])
	if lit:
		symbol.aa_polygon(outline, SchematicTheme.COIL_ON)
	symbol.aa_polyline(outline, color, 1.0)


func preview_rect() -> Rect2:
	return PREVIEW_BOX


## A box with four sockets and the arrows.
func _draw_preview(color: Color, width: float) -> void:
	aa_rect(PREVIEW_BOX, color, false, width)
	for k: int in 4:
		draw_socket(self, Vector2(20.0 + k * 20.0, 36.0), false, color)
	_draw_arrows(Vector2(50.0, 16.0), color)


func _draw_labels() -> void:
	draw_label(designation_text(), Vector2(-1.4 * G, 2.0 * G), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	draw_rating(Vector2(-1.4 * G, 2.0 * G), 1)
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in names.size():
		var cell: Vector2 = Vector2(SymbolGeometry.switch_terminal_cell(i))
		var y: float = 0.5 * G if cell.y == 0.0 else (SymbolGeometry.SWITCH_HEIGHT - 0.5) * G
		if placement.rotation % 2 == 1:
			y = cell.y * G
		draw_label(names[i], Vector2(cell.x * G + 0.3 * G, y), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
