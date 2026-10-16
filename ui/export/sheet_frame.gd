class_name SheetFrame
extends Node2D
## Frame and title block of an exported sheet (see [SheetLayout]), drawn on
## the drawing's grid (world pixels) in the line colour of the schematic:
## the schematic title with the file name and date, the page title and the
## page number.

const G: float = float(SymbolGeometry.GRID)

var layout: SheetLayout
## Title of the schematic.
var title: String = ""
var page_title: String = ""
var page_number: int = 1
var page_count: int = 1
## Small text under the title, e.g. the file name and the date.
var note: String = ""
## Caption over the page number ("Page", translated).
var page_caption: String = "Page"


func _draw() -> void:
	if layout == null:
		return
	# Sizes on paper, in millimetres, turned into world pixels.
	var mm: float = G / layout.cell_mm
	var line: Color = SchematicTheme.LINE
	var frame: Rect2 = Rect2(layout.frame.position * G, layout.frame.size * G)
	var block: Rect2 = Rect2(layout.title_block.position * G, layout.title_block.size * G)
	draw_rect(frame, line, false, 0.5 * mm)
	draw_line(block.position, Vector2(block.end.x, block.position.y), line, 0.5 * mm)
	var split_a: float = block.position.x + block.size.x * 0.55
	var split_b: float = block.position.x + block.size.x * 0.85
	for x: float in [split_a, split_b]:
		draw_line(Vector2(x, block.position.y), Vector2(x, block.end.y), line, 0.35 * mm)
	var pad: float = 3.0 * mm
	_text(title, Vector2(block.position.x + pad, block.position.y + 8.0 * mm), split_a - block.position.x - 2.0 * pad, 5.0 * mm, SchematicTheme.TEXT)
	_text(note, Vector2(block.position.x + pad, block.end.y - 3.5 * mm), split_a - block.position.x - 2.0 * pad, 3.0 * mm, SchematicTheme.PATH_TEXT)
	_text(page_title, Vector2(split_a + pad, block.position.y + 10.5 * mm), split_b - split_a - 2.0 * pad, 5.0 * mm, SchematicTheme.TEXT)
	_text(page_caption, Vector2(split_b + pad, block.position.y + 5.5 * mm), block.end.x - split_b - 2.0 * pad, 3.0 * mm, SchematicTheme.PATH_TEXT)
	_text("%d / %d" % [page_number, page_count], Vector2(split_b + pad, block.end.y - 3.5 * mm), block.end.x - split_b - 2.0 * pad, 5.0 * mm, SchematicTheme.TEXT)


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
