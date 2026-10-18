class_name StationsSheet
extends Node2D
## A sheet of control stations for the export: each station drawn as on its
## panel ([ControlBoxView], no keys), its name and title above it, side by
## side in rows ([method arrange] shares them out over the sheets).

const G: float = float(SymbolGeometry.GRID)
## Room on one sheet (A4 landscape at full size), in world pixels.
const ROOM := Vector2(52.0 * G, 31.0 * G)
const CAPTION_H: float = 30.0
const GAP: float = 40.0
const CAPTION_SIZE: int = 15

var document: SchematicDocument
## The stations on this sheet: [{"box" (index), "at" (top-left of its
## caption)}], from [method arrange].
var placed: Array = []


## The stations of [param doc] shared out over sheets: rows left to right
## within [constant ROOM], a new sheet when the next row does not fit (a
## station larger than a sheet gets one of its own).
static func arrange(doc: SchematicDocument) -> Array[Array]:
	var sheets: Array[Array] = []
	var sheet: Array = []
	var x: float = 0.0
	var y: float = 0.0
	var row_h: float = 0.0
	for i: int in doc.control_boxes.size():
		var size: Vector2 = box_size(doc, i) + Vector2(0.0, CAPTION_H)
		if x > 0.0 and x + size.x > ROOM.x:
			x = 0.0
			y += row_h + GAP
			row_h = 0.0
		if y > 0.0 and y + size.y > ROOM.y:
			sheets.append(sheet)
			sheet = []
			x = 0.0
			y = 0.0
		sheet.append({"box": i, "at": Vector2(x, y)})
		x += size.x + GAP
		row_h = maxf(row_h, size.y)
	if not sheet.is_empty():
		sheets.append(sheet)
	return sheets


## Size station [param index] of [param doc] is drawn at.
static func box_size(doc: SchematicDocument, index: int) -> Vector2:
	var view: ControlBoxView = ControlBoxView.new()
	view.document = doc
	view.box_index = index
	var size: Vector2 = view._get_minimum_size()
	view.free()
	return size


func _ready() -> void:
	for entry: Dictionary in placed:
		var view: ControlBoxView = ControlBoxView.new()
		view.document = document
		view.box_index = entry["box"]
		view.show_keys = false
		view.position = entry["at"] + Vector2(0.0, CAPTION_H)
		view.size = box_size(document, entry["box"])
		add_child(view)


## What the sheet covers, in grid cells.
func extent() -> Rect2:
	var end: Vector2 = Vector2.ZERO
	for entry: Dictionary in placed:
		end = end.max(entry["at"] + box_size(document, entry["box"]) + Vector2(0.0, CAPTION_H))
	return Rect2(Vector2.ZERO, end / G)


func _draw() -> void:
	var font: Font = AppTheme.schematic_font()
	for entry: Dictionary in placed:
		var box: ControlBox = document.control_boxes[entry["box"]]
		var at: Vector2 = entry["at"] + Vector2(0.0, CAPTION_H - 10.0)
		draw_string(font, at, "+" + box.name, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE, SchematicTheme.DESIGNATION)
		var title: String = box.title if not box.title.is_empty() else tr("Control station")
		var shift: float = font.get_string_size("+" + box.name, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE).x + 10.0
		draw_string(font, at + Vector2(shift, 0.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE - 2, SchematicTheme.TEXT)
