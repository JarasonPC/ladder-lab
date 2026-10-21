class_name TimersSheet
extends Node2D
## A sheet of the time relays for the export, one row each: its symbol as on
## the schematic, its designation, the function it is set to, its times and
## control input, and the timing diagram of that function ([TimerDiagram] on
## paper); on A4 portrait ([method split] shares the relays out over the
## sheets).

const G: float = float(SymbolGeometry.GRID)
## The list, in world pixels: A4 portrait inside the frame at full size.
const SIZE := Vector2(35.9 * G, 49.7 * G)
## Height of one relay on the sheet.
const ENTRY_H: float = 130.0
const NAME_SIZE: int = 15
const TEXT_SIZE: int = 12
const LINE_H: float = 19.0
## Width of the symbol's column.
const SYMBOL_W: float = 130.0
## Where the diagram begins, as a part of the width; the texts are between.
const DIAGRAM_SHARE: float = 0.55
const PAD: float = 6.0

## The relays on this sheet, from [method entries].
var relays: Array = []
## The document the relays are drawn from (their symbols).
var document: SchematicDocument


## The time relays of [param doc] by designation: {"id", "designation", "mode",
## "function" (its title), "input" (name of the control input, "" without
## one), "data" ([label, value] pairs: the times)}.
static func entries(doc: SchematicDocument) -> Array[Dictionary]:
	var found: Array[TimerRelay] = []
	for c: CircuitComponent in doc.circuit.get_components():
		if c is TimerRelay:
			found.append(c as TimerRelay)
	found.sort_custom(func(a: TimerRelay, b: TimerRelay) -> bool:
		return a.designation.naturalnocasecmp_to(b.designation) < 0)
	var result: Array[Dictionary] = []
	for relay: TimerRelay in found:
		var names: PackedStringArray = relay.get_terminal_names()
		var input: String = names[2] if relay.control_input and names.size() > 2 else ""
		var titles: Array = TimerFunctionsPopup.function_titles(input if not input.is_empty() else "S")
		var data: Array = []
		if TimerRelay.uses_two_times(relay.mode):
			data.append([_tr("Times t1 / t2"), "%s s / %s s" % [Fuse.amperes_text(relay.delay), Fuse.amperes_text(relay.delay2)]])
		elif relay.mode != TimerRelay.Mode.TEST:
			data.append([_tr("Time t"), "%s s" % Fuse.amperes_text(relay.delay)])
		if relay.mode == TimerRelay.Mode.PULSE_GENERATOR:
			data.append([_tr("Pulse of F7"), "%s s" % Fuse.amperes_text(TimerRelay.GENERATOR_PULSE)])
		data.append([_tr("Control input"), input if not input.is_empty() else "–"])
		result.append({"id": relay.id, "designation": "-" + relay.designation, "mode": relay.mode, "function": str(titles[relay.mode]), "input": input, "data": data})
	return result


static func _tr(text: String) -> String:
	return String(TranslationServer.translate(text))


## [param all] entries shared out over sheets, as many on each as fit.
static func split(all: Array[Dictionary]) -> Array[Array]:
	var per_sheet: int = maxi(floori(SIZE.y / ENTRY_H), 1)
	var sheets: Array[Array] = []
	for start: int in range(0, all.size(), per_sheet):
		sheets.append(all.slice(start, start + per_sheet))
	return sheets


func _ready() -> void:
	var x: float = SIZE.x * DIAGRAM_SHARE + PAD
	for i: int in relays.size():
		var entry: Dictionary = relays[i]
		var relay: TimerRelay = document.circuit.get_component(entry["id"]) as TimerRelay if document != null else null
		if relay != null:
			# Upright as in the palette, scaled to fit its column.
			var extent: Rect2 = DatasheetLayout.symbol_extent(relay)
			var k: float = minf(1.0, minf((SYMBOL_W - 2.0 * PAD) / extent.size.x, (ENTRY_H - 2.0 * PAD) / extent.size.y))
			var symbol: SchematicSymbol = SymbolFactory.create(relay, Placement.new(Vector2i.ZERO, 0, false))
			symbol.position = Vector2(SYMBOL_W * 0.5, (i + 0.5) * ENTRY_H) - extent.get_center() * k
			symbol.scale = Vector2(k, k)
			add_child(symbol)
		var diagram: TimerDiagram = TimerDiagram.new()
		diagram.paper = true
		diagram.input_name = entry["input"] if not str(entry["input"]).is_empty() else "S"
		diagram.mode = entry["mode"]
		diagram.position = Vector2(x, i * ENTRY_H + PAD)
		diagram.size = Vector2(SIZE.x - x - PAD, diagram._get_minimum_size().y)
		add_child(diagram)


## What the sheet covers, in grid cells.
func extent() -> Rect2:
	return Rect2(Vector2.ZERO, SIZE / G)


func _draw() -> void:
	var font: Font = AppTheme.schematic_font()
	var bold: Font = AppTheme.bold_font()
	var left: float = SYMBOL_W + PAD
	var width: float = SIZE.x * DIAGRAM_SHARE - left - PAD
	var rule: Color = SchematicTheme.LINE.lerp(SchematicTheme.BACKGROUND, 0.7)
	for i: int in relays.size():
		var entry: Dictionary = relays[i]
		var top: float = i * ENTRY_H
		var y: float = top + PAD + NAME_SIZE
		draw_string(bold, Vector2(left, y), entry["designation"], HORIZONTAL_ALIGNMENT_LEFT, width, NAME_SIZE, SchematicTheme.DESIGNATION)
		y += LINE_H + 2.0
		# The function's title on up to two lines.
		var title: String = entry["function"]
		draw_multiline_string(font, Vector2(left, y), title, HORIZONTAL_ALIGNMENT_LEFT, width, TEXT_SIZE, 2, SchematicTheme.TEXT)
		var lines: int = roundi(font.get_multiline_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, width, TEXT_SIZE, 2).y / font.get_height(TEXT_SIZE))
		y += (maxi(lines, 1) - 1) * font.get_height(TEXT_SIZE)
		for pair: Array in entry["data"]:
			y += LINE_H
			_text(font, Vector2(left, y), "%s:" % pair[0], width * 0.5, SchematicTheme.PATH_TEXT)
			_text(font, Vector2(left + width * 0.5, y), str(pair[1]), width * 0.5, SchematicTheme.TEXT)
		draw_line(Vector2(0.0, top + ENTRY_H), Vector2(SIZE.x, top + ENTRY_H), rule, 0.5)


func _text(font: Font, at: Vector2, text: String, width: float, color: Color) -> void:
	var fitted: Dictionary = PartsSheet.fit(font, text, width)
	draw_string(font, at, fitted["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fitted["size"], color)
