class_name SheetLayout
extends RefCounted
## The sheet of paper a page of the schematic is exported on (PDF and PNG):
## ISO A5 to A0, landscape or portrait, with a frame and a title block along
## the bottom of the frame. [method fit] takes the smallest paper from A4 up
## to the largest allowed (A3 unless set otherwise; A5 only when that is the
## largest) on which the drawing fits at [constant CELL_MM] per grid cell,
## else the largest sheet, on which it is scaled down least. Rectangles are in grid cells, on the grid of
## the drawing, so the drawing sits in the middle of the room above the title
## block.

## Millimetres per grid cell at full size.
const CELL_MM: float = 5.0
## Paper edge to frame.
const MARGIN_MM: float = 10.0
## Frame to drawing, at least.
const PADDING_MM: float = 5.0
const TITLE_BLOCK_MM: float = 18.0
const MM_PER_INCH: float = 25.4
const POINTS_PER_INCH: float = 72.0
## Paper sizes (landscape), smallest first.
const PAPERS: Array[Dictionary] = [
	{"name": "A5", "size": Vector2(210.0, 148.0)}, {"name": "A4", "size": Vector2(297.0, 210.0)},
	{"name": "A3", "size": Vector2(420.0, 297.0)}, {"name": "A2", "size": Vector2(594.0, 420.0)},
	{"name": "A1", "size": Vector2(841.0, 594.0)}, {"name": "A0", "size": Vector2(1189.0, 841.0)},
]
## The largest paper used unless another is chosen, and the smallest used
## while a larger one is allowed.
const DEFAULT_LARGEST: String = "A3"
const SMALLEST: String = "A4"

## "A5" to "A0".
var paper_name: String = "A4"
var portrait: bool = false
## Paper width and height in millimetres, as the sheet is seen.
var paper_mm: Vector2 = Vector2.ZERO
## Millimetres per grid cell on the paper (at most [constant CELL_MM]).
var cell_mm: float = CELL_MM
## The whole paper, the frame and the title block, in grid cells.
var sheet: Rect2 = Rect2()
var frame: Rect2 = Rect2()
var title_block: Rect2 = Rect2()


## Sheet for a drawing covering [param drawing] (grid cells), on paper up
## to [param largest] ("A5" to "A0").
static func fit(drawing: Rect2, largest: String = DEFAULT_LARGEST) -> SheetLayout:
	var best: SheetLayout = null
	var top: int = maxi(paper_index(largest), 0)
	var bottom: int = mini(paper_index(SMALLEST), top)
	for i: int in range(bottom, top + 1):
		var paper: Dictionary = PAPERS[i]
		for upright: bool in [false, true]:
			var size: Vector2 = paper["size"]
			if upright:
				size = Vector2(size.y, size.x)
			var room: Vector2 = _room(size)
			var needed: Vector2 = Vector2(maxf(drawing.size.x, 1.0), maxf(drawing.size.y, 1.0)) * CELL_MM
			var scale: float = minf(1.0, minf(room.x / needed.x, room.y / needed.y))
			if best == null or scale > best.cell_mm / CELL_MM + 1e-6:
				best = _make(drawing, paper["name"], upright, size, CELL_MM * scale)
			if scale >= 1.0:
				return best
	return best


## Index of paper [param name] in [constant PAPERS], -1 for none.
static func paper_index(name: String) -> int:
	for i: int in PAPERS.size():
		if PAPERS[i]["name"] == name:
			return i
	return -1


## Paper size in PDF points (1/72 inch).
func paper_points() -> Vector2:
	return paper_mm / MM_PER_INCH * POINTS_PER_INCH


## Image pixels per grid cell when printed at [param dpi] dots per inch.
func pixels_per_cell(dpi: float) -> float:
	return cell_mm / MM_PER_INCH * dpi


## Space for the drawing on paper of [param size] mm: inside the frame and
## the padding, above the title block.
static func _room(size: Vector2) -> Vector2:
	var inset: float = 2.0 * (MARGIN_MM + PADDING_MM)
	return size - Vector2(inset, inset + TITLE_BLOCK_MM)


static func _make(drawing: Rect2, name: String, upright: bool, size: Vector2, mm: float) -> SheetLayout:
	var layout: SheetLayout = SheetLayout.new()
	layout.paper_name = name
	layout.portrait = upright
	layout.paper_mm = size
	layout.cell_mm = mm
	var room_center: Vector2 = Vector2.ONE * (MARGIN_MM + PADDING_MM) + _room(size) * 0.5
	layout.sheet = Rect2(drawing.get_center() - room_center / mm, size / mm)
	layout.frame = layout.sheet.grow(-MARGIN_MM / mm)
	var block_height: float = TITLE_BLOCK_MM / mm
	layout.title_block = Rect2(Vector2(layout.frame.position.x, layout.frame.end.y - block_height), Vector2(layout.frame.size.x, block_height))
	return layout
