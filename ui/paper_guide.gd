class_name PaperGuide
extends Node2D
## The paper size guide over a page of the schematic (View > Paper size
## guide): a sheet of the chosen paper as the export draws it at full size
## ([constant SheetLayout.CELL_MM] a grid cell): the paper's edge, the frame,
## the title block and, dashed, the room for the drawing, which starts at the
## top left corner of everything drawn on the page. Where the drawing does
## not fit in that room the room is drawn in the warning colour and the
## paper's name says so (the export then takes larger paper, or scales the
## drawing down). Drawn behind the drawing; never on exported sheets.

const G: float = float(SymbolGeometry.GRID)
const DASH: float = 8.0

## "A4" to "A0", "" for none.
var paper: String = ""
var portrait: bool = false
## Gives everything drawn on the page, in cells (see
## [method SchematicView.drawn_extent]).
var extent: Callable


func _draw() -> void:
	if paper.is_empty() or not extent.is_valid():
		return
	# As the export measures it (see SheetRenderer).
	var drawing: Rect2 = (extent.call() as Rect2).grow(0.5)
	var layout: SheetLayout = SheetLayout.at_corner(paper, portrait, drawing.position)
	var room: Rect2 = layout.room()
	var fits: bool = room.grow(0.01).encloses(drawing)
	var color: Color = SchematicTheme.PAPER_GUIDE
	draw_rect(_px(layout.sheet), color, false, 1.0)
	draw_rect(_px(layout.frame), color, false, 2.0)
	draw_rect(_px(layout.title_block), color, false, 1.0)
	var r: Rect2 = _px(room)
	var edge: Color = color if fits else SchematicTheme.WARNING
	var corners: PackedVector2Array = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i: int in 4:
		draw_dashed_line(corners[i], corners[i + 1], edge, 1.5, DASH)
	var font: Font = AppTheme.schematic_font()
	var size: int = SchematicTheme.LABEL_SIZE
	var text: String = text_of(paper, portrait, fits)
	draw_string(font, _px(layout.sheet).position + Vector2(0.0, -font.get_descent(size) - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, edge)
	# The paper's name in its title block too.
	var block: Rect2 = _px(layout.title_block)
	draw_string(font, block.position + Vector2(8.0, block.size.y * 0.5 + font.get_ascent(size) * 0.5 - 1.0), paper, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## What the guide says over its sheet: "A4, landscape", and where the
## drawing does not fit, that it does not.
static func text_of(paper_name: String, upright: bool, fits: bool) -> String:
	var text: String = (TranslationServer.translate("%s, portrait") if upright else TranslationServer.translate("%s, landscape")) % paper_name
	if not fits:
		text += " – " + TranslationServer.translate("the drawing does not fit at full size")
	return text


static func _px(cells: Rect2) -> Rect2:
	return Rect2(cells.position * G, cells.size * G)
