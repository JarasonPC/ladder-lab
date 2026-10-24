class_name HeatRiseSheet
extends Node2D
## A sheet of a switchboard's temperature rise protocol for the export
## ([HeatRiseReport]): its title, headings, texts, tables and the curve, on
## A4 portrait ([method split] shares the rows out over the sheets: a long
## text is wrapped, a heading never ends a sheet, a table going on to the
## next sheet repeats its heading row there).

const G: float = float(SymbolGeometry.GRID)
## The protocol, in world pixels: A4 portrait inside the frame at full size.
const SIZE := Vector2(35.9 * G, 49.7 * G)
const TEXT_SIZE: int = 12
const TITLE_SIZE: int = 16
## Heights of the rows by type.
const HEIGHTS: Dictionary = {"title": 36.0, "heading": 32.0, "text": 18.0, "table": 22.0, "curve": 300.0, "gap": 10.0}
const PAD: float = 6.0

## Rows of this sheet (see [method HeatRiseReport.rows]).
var rows: Array = []


## [param all] rows shared out over sheets: texts wrapped to the width, a
## heading never last on a sheet, a table's heading row repeated where it
## goes on.
static func split(all: Array[Dictionary]) -> Array[Array]:
	var font: Font = AppTheme.schematic_font()
	var lines: Array[Dictionary] = []
	for row: Dictionary in all:
		if row["type"] == "text":
			for line: String in wrap_text(font, row["text"], SIZE.x - 2.0 * PAD, TEXT_SIZE):
				var piece: Dictionary = row.duplicate()
				piece["text"] = line
				lines.append(piece)
		else:
			lines.append(row)
	var sheets: Array[Array] = []
	var sheet: Array = []
	var used: float = 0.0
	var heads: Dictionary = {}
	for i: int in lines.size():
		var row: Dictionary = lines[i]
		if row["type"] == "table" and row["head"]:
			heads[row["table"]] = row
		var height: float = HEIGHTS[row["type"]]
		# A heading (or a table's heading row) keeps the row after it on its sheet.
		var keep: float = 0.0
		if (row["type"] == "heading" or (row["type"] == "table" and row["head"])) and i + 1 < lines.size():
			keep = HEIGHTS[lines[i + 1]["type"]]
		if not sheet.is_empty() and used + height + keep > SIZE.y:
			sheets.append(sheet)
			sheet = []
			used = 0.0
			if row["type"] == "table" and not row["head"] and heads.has(row["table"]):
				sheet.append(heads[row["table"]])
				used += HEIGHTS["table"]
		sheet.append(row)
		used += height
	if not sheet.is_empty():
		sheets.append(sheet)
	return sheets


## [param text] in lines no wider than [param width] at [param size].
static func wrap_text(font: Font, text: String, width: float, size: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var line: String = ""
	for word: String in text.split(" ", false):
		var tried: String = word if line.is_empty() else line + " " + word
		if not line.is_empty() and font.get_string_size(tried, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			lines.append(line)
			line = word
		else:
			line = tried
	if not line.is_empty():
		lines.append(line)
	return lines


## What the sheet covers, in grid cells.
func extent() -> Rect2:
	return Rect2(Vector2.ZERO, SIZE / G)


func _ready() -> void:
	# The curve is a control of its own, at its row.
	var y: float = 0.0
	for row: Dictionary in rows:
		if row["type"] == "curve":
			var curve: HeatRiseCurve = HeatRiseCurve.new()
			curve.paper = true
			curve.result = row["result"]
			curve.ambient = row["ambient"]
			curve.limit = row["limit"]
			curve.marks.assign(row["marks"])
			curve.position = Vector2(0.0, y + 8.0)
			curve.size = Vector2(SIZE.x * 0.7, HEIGHTS["curve"] - 16.0)
			add_child(curve)
		y += HEIGHTS[row["type"]]


func _draw() -> void:
	var font: Font = AppTheme.schematic_font()
	var bold: Font = AppTheme.bold_font()
	var line: Color = SchematicTheme.LINE
	var faint: Color = line.lerp(SchematicTheme.BACKGROUND, 0.6)
	var y: float = 0.0
	for row: Dictionary in rows:
		var height: float = HEIGHTS[row["type"]]
		match row["type"]:
			"title":
				draw_string(bold, Vector2(PAD, y + 24.0), row["text"], HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 2.0 * PAD, TITLE_SIZE, SchematicTheme.TEXT)
			"heading":
				draw_string(bold, Vector2(PAD, y + height - 9.0), row["text"], HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 2.0 * PAD, TEXT_SIZE + 1, SchematicTheme.DESIGNATION)
			"text":
				var colour: Color = SchematicTheme.TEXT.lerp(SchematicTheme.BACKGROUND, 0.25) if row.get("muted", false) else SchematicTheme.TEXT
				draw_string(font, Vector2(PAD, y + height - 5.0), row["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, colour)
			"table":
				var x: float = 0.0
				var face: Font = bold if row["head"] or row.get("bold", false) else font
				var widths: Array = row["widths"]
				for c: int in widths.size():
					var w: float = SIZE.x * float(widths[c])
					var fitted: Dictionary = PartsSheet.fit(face, str(row["cells"][c]), w - 2.0 * PAD)
					var text_w: float = face.get_string_size(fitted["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fitted["size"]).x
					var at_x: float = x + PAD if row["align"][c] == "l" else x + w - PAD - text_w
					draw_string(face, Vector2(at_x, y + height - 7.0), fitted["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fitted["size"], SchematicTheme.TEXT)
					if c > 0:
						draw_line(Vector2(x, y), Vector2(x, y + height), faint, 0.5)
					x += w
				draw_line(Vector2(0.0, y + height), Vector2(SIZE.x, y + height), line if row["head"] else faint, 1.2 if row["head"] else 0.5)
		y += height
