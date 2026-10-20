class_name SheetFrame
extends Node2D
## Frame and title block of an exported sheet (see [SheetLayout]), drawn on
## the drawing's grid (world pixels) in the line colour of the schematic.
## The title block has, left to right: company and project, the schematic
## title with the file name, drawn by and checked by, date and drawing
## number, the page title, revision and page number, the stage of the
## documentation and the scale and format (as Czech title blocks have them).
## Each field has a small caption and stays there when empty, to be filled in by hand.

const G: float = float(SymbolGeometry.GRID)
## Column edges of the title block, as parts of its width.
const COLUMNS: Array[float] = [0.0, 0.16, 0.40, 0.52, 0.64, 0.78, 0.89, 1.0]

var layout: SheetLayout
## Title of the schematic.
var title: String = ""
var page_title: String = ""
var page_number: int = 1
var page_count: int = 1
## Small text under the title, e.g. the file name.
var note: String = ""
## Texts of the fields (drawn by, ...); an empty date is replaced by [member date].
var block: TitleBlock = TitleBlock.new()
## Date written when [member block] has none (the date of the export).
var date: String = ""
## The drawing's scale ("1:50"), "" for a sheet not drawn to scale.
var scale_text: String = ""


func _draw() -> void:
	if layout == null:
		return
	# Sizes on paper, in millimetres, turned into world pixels.
	var mm: float = G / layout.cell_mm
	var line: Color = SchematicTheme.LINE
	var frame: Rect2 = Rect2(layout.frame.position * G, layout.frame.size * G)
	var area: Rect2 = Rect2(layout.title_block.position * G, layout.title_block.size * G)
	draw_rect(frame, line, false, 0.5 * mm)
	draw_line(area.position, Vector2(area.end.x, area.position.y), line, 0.5 * mm)
	var x: Array[float] = []
	for part: float in COLUMNS:
		x.append(area.position.x + area.size.x * part)
	for i: int in range(1, x.size() - 1):
		draw_line(Vector2(x[i], area.position.y), Vector2(x[i], area.end.y), line, 0.35 * mm)
	var middle: float = area.position.y + area.size.y * 0.5
	# Columns split into two fields: 0, 2, 3, 5 and 6.
	for i: int in [0, 2, 3, 5, 6]:
		draw_line(Vector2(x[i], middle), Vector2(x[i + 1], middle), line, 0.25 * mm)
	var pad: float = 2.0 * mm
	var top: float = area.position.y
	_field(tr("Company"), block.company, x[0], x[1], top, mm)
	_field(tr("Project"), block.project, x[0], x[1], middle, mm)
	_text(title, Vector2(x[1] + pad, top + 8.0 * mm), x[2] - x[1] - 2.0 * pad, 5.0 * mm, SchematicTheme.TEXT)
	_text(note, Vector2(x[1] + pad, area.end.y - 3.5 * mm), x[2] - x[1] - 2.0 * pad, 3.0 * mm, SchematicTheme.PATH_TEXT)
	_field(tr("Drawn by"), block.drawn_by, x[2], x[3], top, mm)
	_field(tr("Checked by"), block.checked_by, x[2], x[3], middle, mm)
	_field(tr("Date"), block.date if not block.date.is_empty() else date, x[3], x[4], top, mm)
	_field(tr("Drawing no."), block.drawing_number, x[3], x[4], middle, mm)
	_text(page_title, Vector2(x[4] + pad, top + 10.5 * mm), x[5] - x[4] - 2.0 * pad, 5.0 * mm, SchematicTheme.TEXT)
	_field(tr("Revision"), block.revision, x[5], x[6], top, mm)
	_field(tr("Page"), "%d / %d" % [page_number, page_count], x[5], x[6], middle, mm)
	_field(tr("Stage"), block.stage, x[6], x[7], top, mm)
	_field(tr("Scale · Format"), "%s · %s" % [scale_text if not scale_text.is_empty() else "–", layout.paper_name], x[6], x[7], middle, mm)


## A field between [param left] and [param right] whose half of the title
## block starts at [param top]: the caption, and the value under it.
func _field(caption: String, value: String, left: float, right: float, top: float, mm: float) -> void:
	var pad: float = 1.5 * mm
	var width: float = right - left - 2.0 * pad
	_text(caption, Vector2(left + pad, top + 2.8 * mm), width, 2.2 * mm, SchematicTheme.PATH_TEXT)
	_text(value, Vector2(left + pad, top + 7.6 * mm), width, 4.0 * mm, SchematicTheme.TEXT)


## Writes [param text] from [param at] (baseline), as large as [param height]
## allows within [param width].
func _text(text: String, at: Vector2, width: float, height: float, color: Color) -> void:
	if text.is_empty():
		return
	var font: Font = AppTheme.schematic_font()
	var size: int = maxi(roundi(height), 1)
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if text_width > width and text_width > 0.0:
		size = maxi(floori(size * width / text_width), 1)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
