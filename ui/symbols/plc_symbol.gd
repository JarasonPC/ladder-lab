class_name PlcSymbol
extends SchematicSymbol
## PLC (logic module): a box with the supply L1 N and the inputs I1-I8 on top
## and the relay outputs Q1-Q4 below, each drawn as the NO contact it closes
## between its two terminals (moving with the output relay). A small square
## under each input lights up while the input is on; the display in the
## middle is filled while the PLC has power (RUN).

const G2: float = SymbolGeometry.POLE_SPACING * G
const BOX := Rect2(-G, G, 20.0 * G, (SymbolGeometry.PLC_HEIGHT - 2) * G)
const DISPLAY := Rect2(7.0 * G, 2.0 * G, 6.0 * G, 1.2 * G)
## Height of the output contacts.
const CONTACT_Y: float = 4.3 * G


func _draw_shape(color: Color, width: float) -> void:
	var plc: Plc = component as Plc
	var top: int = Plc.output_terminal(0)
	for i: int in top:
		aa_line(Vector2(i * G2, 0), Vector2(i * G2, BOX.position.y), lead_color(i), lead_width(i))
	aa_rect(BOX, color, false, width)
	# Input lights.
	for k: int in Plc.INPUTS:
		var x: float = Plc.input_terminal(k) * G2
		var light: Rect2 = Rect2(x - 4.0, BOX.position.y + 5.0, 8.0, 6.0)
		if plc.energized and plc.input_on(k):
			aa_rect(light, SchematicTheme.COIL_ON)
		aa_rect(light, color, false, 1.0)
	if plc.energized:
		aa_rect(DISPLAY, SchematicTheme.COIL_ON)
	aa_rect(DISPLAY, color, false, 1.2)
	# Outputs: a lead up from each terminal, the NO contact across.
	for k: int in Plc.OUTPUTS:
		var cell_a: Vector2 = Vector2(SymbolGeometry.plc_terminal_cell(Plc.output_terminal(k))) * G
		var cell_b: Vector2 = Vector2(SymbolGeometry.plc_terminal_cell(Plc.output_terminal(k) + 1)) * G
		var a: int = Plc.output_terminal(k)
		aa_line(cell_a, Vector2(cell_a.x, CONTACT_Y), lead_color(a), lead_width(a))
		aa_line(cell_b, Vector2(cell_b.x, CONTACT_Y), lead_color(a + 1), lead_width(a + 1))
		var pivot: Vector2 = Vector2(cell_a.x + 9.0, CONTACT_Y)
		var fixed: Vector2 = Vector2(cell_b.x - 9.0, CONTACT_Y)
		aa_line(Vector2(cell_a.x, CONTACT_Y), pivot, color, width)
		aa_line(fixed, Vector2(cell_b.x, CONTACT_Y), color, width)
		var travel: float = shown("Q%d" % k, plc.output_armatures[k].position)
		var tip: Vector2 = blade_tip(pivot, fixed + Vector2(2.0, -9.0), fixed + Vector2(2.0, 0.0), travel)
		draw_blade(pivot, tip, color, width)


func _draw_labels() -> void:
	draw_label(designation_text(), Vector2(-1.4 * G, 3.0 * G), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	var plc: Plc = component as Plc
	var names: PackedStringArray = component.get_terminal_names()
	for i: int in names.size():
		var cell: Vector2 = Vector2(SymbolGeometry.plc_terminal_cell(i))
		var y: float = 0.5 * G if cell.y == 0.0 else (SymbolGeometry.PLC_HEIGHT - 0.5) * G
		draw_label(names[i], Vector2(cell.x * G + 0.3 * G, y), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	var display: String = "PLC  RUN" if plc.energized else "PLC  " + ("LAD" if plc.program.language == PlcProgram.Language.LAD else "FBD")
	_centered(display, DISPLAY.get_center(), 11, SchematicTheme.TEXT)
	for k: int in Plc.OUTPUTS:
		var cell_a: Vector2 = Vector2(SymbolGeometry.plc_terminal_cell(Plc.output_terminal(k))) * G
		_centered("Q%d" % (k + 1), Vector2(cell_a.x + G, CONTACT_Y - 0.9 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT)


## Upright text centred on local point [param at].
func _centered(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var font: Font = AppTheme.schematic_font()
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var c: Vector2 = to_upright(at)
	var pos: Vector2 = c + Vector2(-size.x * 0.5, font.get_ascent(font_size) * 0.5 - 1.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	text_rects.append(Rect2(Vector2(pos.x, pos.y - font.get_ascent(font_size)), size))
