class_name TimersSheet
extends Node2D
## A sheet of the time relays for the export: each relay's designation, the
## function it is set to, its times and control input, beside the timing
## diagram of that function ([TimerDiagram] on paper); on A4 portrait
## ([method split] shares the relays out over the sheets).

const G: float = float(SymbolGeometry.GRID)
## The list, in world pixels: A4 portrait inside the frame at full size.
const SIZE := Vector2(35.9 * G, 49.7 * G)
## Height of one relay on the sheet.
const ENTRY_H: float = 124.0
const NAME_SIZE: int = 15
const TEXT_SIZE: int = 12
const LINE_H: float = 19.0
## Part of the width the texts take; the diagram the rest.
const TEXT_SHARE: float = 0.48
const PAD: float = 6.0

## The relays on this sheet, from [method entries].
var relays: Array = []


## The time relays of [param doc] by designation: {"designation", "mode",
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
		result.append({"designation": "-" + relay.designation, "mode": relay.mode, "function": str(titles[relay.mode]), "input": input, "data": data})
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
	var x: float = SIZE.x * TEXT_SHARE + PAD
	for i: int in relays.size():
		var entry: Dictionary = relays[i]
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
	var width: float = SIZE.x * TEXT_SHARE - 2.0 * PAD
	var rule: Color = SchematicTheme.LINE.lerp(SchematicTheme.BACKGROUND, 0.7)
	for i: int in relays.size():
		var entry: Dictionary = relays[i]
		var top: float = i * ENTRY_H
		var y: float = top + PAD + NAME_SIZE
		draw_string(bold, Vector2(PAD, y), entry["designation"], HORIZONTAL_ALIGNMENT_LEFT, width, NAME_SIZE, SchematicTheme.DESIGNATION)
		y += LINE_H + 2.0
		_text(font, Vector2(PAD, y), entry["function"], width, SchematicTheme.TEXT)
		for pair: Array in entry["data"]:
			y += LINE_H
			_text(font, Vector2(PAD, y), "%s:" % pair[0], width * 0.5, SchematicTheme.PATH_TEXT)
			_text(font, Vector2(PAD + width * 0.5, y), str(pair[1]), width * 0.5, SchematicTheme.TEXT)
		draw_line(Vector2(0.0, top + ENTRY_H), Vector2(SIZE.x, top + ENTRY_H), rule, 0.5)


func _text(font: Font, at: Vector2, text: String, width: float, color: Color) -> void:
	var fitted: Dictionary = PartsSheet.fit(font, text, width)
	draw_string(font, at, fitted["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fitted["size"], color)
