class_name VfdSymbol
extends SchematicSymbol
## Frequency inverter as a converter (IEC 60617): on the left its power part,
## a box with a diagonal, the mains "3~ 50 Hz" above it and "3~ f" below,
## with L1 L2 L3 PE on top and U V W below; on the right the control
## terminals on top, a window with the output frequency (filled while the
## output is on) and the relay output DO2 below, drawn as the NO contact it
## closes (moving with it).

const BOX := Rect2(-SymbolGeometry.GRID, SymbolGeometry.GRID, SymbolGeometry.VFD_WIDTH * SymbolGeometry.GRID, (SymbolGeometry.VFD_HEIGHT - 2) * SymbolGeometry.GRID)
## The power part.
const POWER := Rect2(-0.6 * G, 1.3 * G, 7.2 * G, 3.4 * G)
const WINDOW := Rect2(17.0 * G, 2.2 * G, 7.0 * G, 1.4 * G)
const CONTACT_Y: float = 4.3 * G


func _draw_shape(color: Color, width: float) -> void:
	if preview:
		_draw_power_part(color)
		return
	var drive: Vfd = component as Vfd
	for i: int in Vfd.TERMINALS.size():
		var cell: Vector2 = Vector2(SymbolGeometry.vfd_terminal_cell(i)) * G
		if i < Vfd.FIRST_BOTTOM:
			aa_line(cell, Vector2(cell.x, BOX.position.y), lead_color(i), lead_width(i))
		elif i < Vfd.DO2C:
			aa_line(cell, Vector2(cell.x, POWER.end.y), lead_color(i), lead_width(i))
	for i: int in 4:
		# The supply leads go on into the power part.
		var x: float = SymbolGeometry.vfd_terminal_cell(i).x * G
		aa_line(Vector2(x, BOX.position.y), Vector2(x, POWER.position.y), lead_color(i), lead_width(i))
	aa_rect(BOX, color, false, width)
	aa_rect(POWER, color, false, width)
	aa_line(Vector2(POWER.position.x, POWER.end.y), Vector2(POWER.end.x, POWER.position.y), color, 1.2)
	if drive.output:
		aa_rect(WINDOW, SchematicTheme.COIL_ON)
	aa_rect(WINDOW, color, false, 1.2)
	# DO2: a lead up from each terminal, the NO contact across.
	var a: Vector2 = Vector2(SymbolGeometry.vfd_terminal_cell(Vfd.DO2C)) * G
	var b: Vector2 = Vector2(SymbolGeometry.vfd_terminal_cell(Vfd.DO2C + 1)) * G
	aa_line(a, Vector2(a.x, CONTACT_Y), lead_color(Vfd.DO2C), lead_width(Vfd.DO2C))
	aa_line(b, Vector2(b.x, CONTACT_Y), lead_color(Vfd.DO2C + 1), lead_width(Vfd.DO2C + 1))
	var pivot: Vector2 = Vector2(a.x + 9.0, CONTACT_Y)
	var fixed: Vector2 = Vector2(b.x - 9.0, CONTACT_Y)
	aa_line(Vector2(a.x, CONTACT_Y), pivot, color, width)
	aa_line(fixed, Vector2(b.x, CONTACT_Y), color, width)
	var travel: float = shown("DO2", 1.0 if drive.is_path_closed(0) else 0.0)
	draw_blade(pivot, blade_tip(pivot, fixed + Vector2(2.0, -9.0), fixed + Vector2(2.0, 0.0), travel), color, width)


## The palette shows the power part alone: the whole drive is too wide to
## read on a tile.
func preview_rect() -> Rect2:
	return Rect2(POWER.position.x, 0.0, POWER.size.x, SymbolGeometry.VFD_HEIGHT * G)


## The power part with its supply leads (L1 L2 L3 PE) and motor leads (U V W).
func _draw_power_part(color: Color) -> void:
	for i: int in 4:
		var top: Vector2 = Vector2(SymbolGeometry.vfd_terminal_cell(i)) * G
		aa_line(top, Vector2(top.x, POWER.position.y), color)
	for i: int in range(Vfd.FIRST_BOTTOM, Vfd.DO2C):
		var bottom: Vector2 = Vector2(SymbolGeometry.vfd_terminal_cell(i)) * G
		aa_line(bottom, Vector2(bottom.x, POWER.end.y), color)
	aa_rect(POWER, color, false)
	aa_line(Vector2(POWER.position.x, POWER.end.y), Vector2(POWER.end.x, POWER.position.y), color)


func _draw_labels() -> void:
	var drive: Vfd = component as Vfd
	draw_label(designation_text(), Vector2(-1.4 * G, 3.0 * G), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in names.size():
		var cell: Vector2 = Vector2(SymbolGeometry.vfd_terminal_cell(i))
		var y: float = 0.5 * G if cell.y == 0.0 else (SymbolGeometry.VFD_HEIGHT - 0.5) * G
		draw_label(names[i], Vector2(cell.x * G + 0.3 * G, y), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	_centered("3~ 50 Hz", POWER.position + Vector2(1.9 * G, 0.6 * G), 10)
	_centered("3~ f", POWER.end - Vector2(1.5 * G, 0.6 * G), 10)
	var state: String = "%.1f Hz" % absf(drive.frequency) if drive.output else ("STOP" if drive.powered else "f  0-%d Hz" % roundi(drive.max_frequency))
	if drive.output and drive.frequency < 0.0:
		state = "◀ " + state
	_centered(state, WINDOW.get_center(), 11)
	_centered("DO2", Vector2(SymbolGeometry.vfd_terminal_cell(Vfd.DO2C).x * G + 1.2 * G, CONTACT_Y - 0.9 * G), SchematicTheme.TERMINAL_SIZE)


func is_interactive() -> bool:
	return true


## Upright text centred on local point [param at].
func _centered(text: String, at: Vector2, font_size: int) -> void:
	var font: Font = AppTheme.schematic_font()
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var c: Vector2 = to_upright(at)
	var pos: Vector2 = c + Vector2(-size.x * 0.5, font.get_ascent(font_size) * 0.5 - 1.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, SchematicTheme.TEXT)
	text_rects.append(Rect2(Vector2(pos.x, pos.y - font.get_ascent(font_size)), size))
