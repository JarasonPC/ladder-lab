class_name PlcSymbol
extends SchematicSymbol
## PLC (logic module): a box with the supply L1 N and the inputs I1-I8 on top
## and the relay outputs Q1-Q4 below, each drawn as the NO contact it closes
## between its two terminals (moving with the output relay). A small square
## under each input lights up while the input is on; the display in the
## middle is filled while the PLC has power (RUN). Expansion modules follow
## on the right, a box each joined to the one before it, with their supply,
## inputs and outputs drawn alike and a window filled while they work.
## A compact CPU ([CompactPlc]) alike: its transistor outputs (and their
## supply 3L+ 3M) below, a small square over each output lit while it is on.
## The Ethernet port P1 on the left of the box: an RJ45 socket lit while it
## has a link.

const G2: float = SymbolGeometry.POLE_SPACING * G
const BOX := Rect2(-G, G, SymbolGeometry.PLC_WIDTH * G, (SymbolGeometry.PLC_HEIGHT - 2) * G)
const DISPLAY := Rect2(7.0 * G, 2.0 * G, 6.0 * G, 1.2 * G)
## Height of the output contacts.
const CONTACT_Y: float = 4.3 * G
## The palette's smaller PLC: four terminals on top, two outputs below.
const PREVIEW_BOX := Rect2(0.0, 0.0, 7.0 * G, 4.0 * G)


func _draw_shape(color: Color, width: float) -> void:
	if preview:
		_draw_preview(color, width)
		return
	var plc: Plc = component as Plc
	var cells: Array[Vector2i] = SymbolGeometry.plc_terminal_cells(plc)
	for i: int in cells.size():
		var x: float = cells[i].x * G
		if i == plc.port_terminal():
			aa_line(Vector2(x, cells[i].y * G), Vector2(BOX.position.x, cells[i].y * G), lead_color(i), lead_width(i))
		elif cells[i].y == 0:
			aa_line(Vector2(x, 0), Vector2(x, BOX.position.y), lead_color(i), lead_width(i))
		elif plc.terminal_role(i) != Plc.Role.DQ:
			aa_line(Vector2(x, cells[i].y * G), Vector2(x, BOX.end.y), lead_color(i), lead_width(i))
	aa_rect(module_box(plc, -1), color, false, width)
	for m: int in plc.modules.size():
		var box: Rect2 = module_box(plc, m)
		aa_rect(box, color, false, width)
		# The plug joining it to the module before it.
		var plug: Rect2 = Rect2(box.position.x - SymbolGeometry.PLC_MODULE_GAP * G, box.get_center().y - 0.3 * G, SymbolGeometry.PLC_MODULE_GAP * G, 0.6 * G)
		aa_rect(plug, color, false, 1.0)
		var window: Rect2 = module_window(plc, m)
		if plc.module_on(m):
			aa_rect(window, SchematicTheme.COIL_ON)
		aa_rect(window, color, false, 1.2)
	# Input lights.
	for k: int in plc.input_count():
		var x: float = cells[plc.input_terminal(k)].x * G
		var light: Rect2 = Rect2(x - 4.0, BOX.position.y + 5.0, 8.0, 6.0)
		var m: int = plc.input_module(k)
		if plc.energized and plc.input_on(k) and (m < 0 or plc.module_on(m)):
			aa_rect(light, SchematicTheme.COIL_ON)
		aa_rect(light, color, false, 1.0)
	if plc.energized:
		aa_rect(DISPLAY, SchematicTheme.COIL_ON)
	aa_rect(DISPLAY, color, false, 1.2)
	NetworkSwitchSymbol.draw_socket(self, Vector2(BOX.position.x + 9.0, SymbolGeometry.PLC_PORT_CELL.y * G), plc.port_link, color)
	# Outputs: a relay's NO contact across its two terminals, a light over a
	# transistor output.
	for k: int in plc.output_count():
		var a: int = plc.output_terminal(k)
		if plc.terminal_role(a) == Plc.Role.TQ:
			var x: float = cells[a].x * G
			var lamp: Rect2 = Rect2(x - 4.0, BOX.end.y - 11.0, 8.0, 6.0)
			if plc.output_armatures[k].no_closed:
				aa_rect(lamp, SchematicTheme.COIL_ON)
			aa_rect(lamp, color, false, 1.0)
			continue
		var cell_a: Vector2 = Vector2(cells[a]) * G
		var cell_b: Vector2 = Vector2(cells[a + 1]) * G
		aa_line(cell_a, Vector2(cell_a.x, CONTACT_Y), lead_color(a), lead_width(a))
		aa_line(cell_b, Vector2(cell_b.x, CONTACT_Y), lead_color(a + 1), lead_width(a + 1))
		_draw_output_contact(cell_a.x, cell_b.x, shown("Q%d" % k, plc.output_armatures[k].position), color, width)


## A relay output's NO contact between its leads at [param left] and
## [param right], closed by [param travel] (0..1).
func _draw_output_contact(left: float, right: float, travel: float, color: Color, width: float) -> void:
	var pivot: Vector2 = Vector2(left + 9.0, CONTACT_Y)
	var fixed: Vector2 = Vector2(right - 9.0, CONTACT_Y)
	aa_line(Vector2(left, CONTACT_Y), pivot, color, width)
	aa_line(fixed, Vector2(right, CONTACT_Y), color, width)
	var tip: Vector2 = blade_tip(pivot, fixed + Vector2(2.0, -9.0), fixed + Vector2(2.0, 0.0), travel)
	draw_blade(pivot, tip, color, width)


## The palette shows a box saying what the PLC is: the whole module is too
## wide to read on a tile.
func preview_rect() -> Rect2:
	return PREVIEW_BOX


## A box with "PLC" over "relay" (logic module with relay outputs) or "CPU"
## (compact PLC).
func _draw_preview(color: Color, width: float) -> void:
	aa_rect(PREVIEW_BOX, color, false, width)
	var c: Vector2 = PREVIEW_BOX.get_center()
	draw_preview_text("PLC", c + Vector2(0.0, -15.0), 32)
	draw_preview_text("CPU" if component is CompactPlc else tr("relay"), c + Vector2(0.0, 17.0), 30)


## Box of expansion module [param m] (-1: the PLC itself; local pixels).
static func module_box(plc: Plc, m: int) -> Rect2:
	var left: float = (SymbolGeometry.plc_module_origins(plc)[m + 1] - 1) * G
	return Rect2(left, BOX.position.y, SymbolGeometry.plc_module_width(plc, m) * G, BOX.size.y)


## Window of expansion module [param m] with its inputs and outputs written
## in it, filled while the module works.
static func module_window(plc: Plc, m: int) -> Rect2:
	var box: Rect2 = module_box(plc, m)
	var w: float = minf(6.0 * G, box.size.x - 2.0 * G)
	return Rect2(box.get_center().x - w * 0.5, DISPLAY.position.y, w, DISPLAY.size.y)


func _draw_labels() -> void:
	draw_label(designation_text(), Vector2(-1.4 * G, 3.0 * G), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	draw_rating(Vector2(-1.4 * G, 3.0 * G), 1)
	var plc: Plc = component as Plc
	var names: PackedStringArray = component.get_terminal_names()
	var cells: Array[Vector2i] = SymbolGeometry.plc_terminal_cells(plc)
	for i: int in names.size():
		var cell: Vector2 = Vector2(cells[i])
		if i == plc.port_terminal():
			# Inside the box, right of its socket.
			draw_label(names[i], Vector2(BOX.position.x + 17.0, cell.y * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
			continue
		var y: float = 0.5 * G if cell.y == 0.0 else (SymbolGeometry.PLC_HEIGHT - 0.5) * G
		if placement.rotation % 2 == 1:
			# Turned, the names run across the leads: level with the
			# terminal, between the lead and the box they would reach the box.
			y = cell.y * G
		draw_label(names[i], Vector2(cell.x * G + 0.3 * G, y), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	var kind: String = "CPU" if plc is CompactPlc else "PLC"
	var display: String = kind + ("  RUN" if plc.energized else "  " + ("LAD" if plc.program.language == PlcProgram.Language.LAD else "FBD"))
	write_in(display, DISPLAY, 11)
	for m: int in plc.modules.size():
		write_in(module_text(plc.modules[m]), module_window(plc, m), 11)
	for k: int in plc.output_count():
		if plc.terminal_role(plc.output_terminal(k)) != Plc.Role.DQ:
			continue
		var cell_a: Vector2 = Vector2(cells[plc.output_terminal(k)]) * G
		# Between the display and the open blade.
		_centered("Q%d" % (k + 1), Vector2(cell_a.x + G, CONTACT_Y - 0.7 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT)


## What a module is, as written on it: "4 DI  4 DQ", "2 AI", "2 AQ".
static func module_text(module: Plc.Module) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for count: Array in [[Plc.MODULE_INPUTS[module], "DI"], [Plc.MODULE_OUTPUTS[module], "DQ"], [Plc.MODULE_ANALOG_INPUTS[module], "AI"], [Plc.MODULE_ANALOG_OUTPUTS[module], "AQ"]]:
		if count[0] > 0:
			parts.append("%d %s" % count)
	return "  ".join(parts)


## Upright text centred on local point [param at].
func _centered(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var font: Font = AppTheme.schematic_font()
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var c: Vector2 = to_upright(at)
	var pos: Vector2 = c + Vector2(-size.x * 0.5, font.get_ascent(font_size) * 0.5 - 1.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	text_rects.append(Rect2(Vector2(pos.x, pos.y - font.get_ascent(font_size)), size))
