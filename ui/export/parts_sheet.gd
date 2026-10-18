class_name PartsSheet
extends Node2D
## A sheet of the parts list for the export ([PartsList]): a table with the
## designation, name and data of each device, headed by the place it sits
## in; on A4 portrait ([method split] shares the rows out over the sheets).

const G: float = float(SymbolGeometry.GRID)
## The table, in world pixels: A4 portrait inside the frame at full size.
const SIZE := Vector2(35.9 * G, 49.7 * G)
const ROW_H: float = 24.0
const HEAD_H: float = 30.0
const TEXT_SIZE: int = 12
## Column edges, as parts of the width.
const COLUMNS: Array[float] = [0.0, 0.16, 0.5, 1.0]

## Rows of this sheet (see [method PartsList.rows]).
var rows: Array = []


## [param all] rows shared out over sheets; a heading never ends a sheet.
static func split(all: Array[Dictionary]) -> Array[Array]:
	var per_sheet: int = floori((SIZE.y - HEAD_H) / ROW_H)
	var sheets: Array[Array] = []
	var sheet: Array = []
	for i: int in all.size():
		var heading: bool = all[i].get("heading", false)
		if sheet.size() >= per_sheet or (heading and sheet.size() >= per_sheet - 1):
			sheets.append(sheet)
			sheet = []
		sheet.append(all[i])
	if not sheet.is_empty():
		sheets.append(sheet)
	return sheets


## What the sheet covers, in grid cells.
func extent() -> Rect2:
	return Rect2(Vector2.ZERO, SIZE / G)


func _draw() -> void:
	var font: Font = AppTheme.schematic_font()
	var bold: Font = AppTheme.bold_font()
	var line: Color = SchematicTheme.LINE
	var x: Array[float] = []
	for part: float in COLUMNS:
		x.append(SIZE.x * part)
	var pad: float = 6.0
	var titles: PackedStringArray = [tr("Designation"), tr("Name"), tr("Data")]
	for c: int in titles.size():
		draw_string(bold, Vector2(x[c] + pad, HEAD_H - 9.0), titles[c], HORIZONTAL_ALIGNMENT_LEFT, x[c + 1] - x[c] - 2.0 * pad, TEXT_SIZE, SchematicTheme.TEXT)
	draw_line(Vector2(0.0, HEAD_H), Vector2(SIZE.x, HEAD_H), line, 1.5)
	var columns: Color = line.lerp(SchematicTheme.BACKGROUND, 0.5)
	for c: int in range(1, x.size() - 1):
		draw_line(Vector2(x[c], 0.0), Vector2(x[c], HEAD_H), columns, 0.5)
	var y: float = HEAD_H
	for row: Dictionary in rows:
		var baseline: float = y + ROW_H - 8.0
		if row.get("heading", false):
			# A place heads the rows after it across the whole table.
			draw_string(bold, Vector2(pad, baseline), row["text"], HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 2.0 * pad, TEXT_SIZE, SchematicTheme.DESIGNATION)
		else:
			var texts: Array = [row["designation"], row["name"], row["data"]]
			for c: int in texts.size():
				var color: Color = SchematicTheme.DESIGNATION if c == 0 else SchematicTheme.TEXT
				draw_string(font, Vector2(x[c] + pad, baseline), str(texts[c]), HORIZONTAL_ALIGNMENT_LEFT, x[c + 1] - x[c] - 2.0 * pad, TEXT_SIZE, color)
			for c: int in range(1, x.size() - 1):
				draw_line(Vector2(x[c], y), Vector2(x[c], y + ROW_H), columns, 0.5)
		y += ROW_H
		draw_line(Vector2(0.0, y), Vector2(SIZE.x, y), line.lerp(SchematicTheme.BACKGROUND, 0.7), 0.5)
