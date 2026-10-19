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
## Room between the name and the title in a caption.
const CAPTION_GAP: float = 10.0

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
		var size: Vector2 = footprint(doc, i)
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


## What station [param index] of [param doc] takes on the sheet: the box with
## its caption above it, as wide as the wider of the two.
static func footprint(doc: SchematicDocument, index: int) -> Vector2:
	var box: Vector2 = box_size(doc, index)
	var font: Font = AppTheme.schematic_font()
	var caption: PackedStringArray = _caption(doc.control_boxes[index])
	var width: float = font.get_string_size(caption[0], HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE).x + CAPTION_GAP
	width += font.get_string_size(caption[1], HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE - 2).x
	return Vector2(maxf(box.x, width), box.y + CAPTION_H)


## The name and the title written above [param box].
static func _caption(box: ControlBox) -> PackedStringArray:
	var title: String = box.title if not box.title.is_empty() else String(TranslationServer.translate("Control station"))
	return PackedStringArray(["+" + box.name, title])


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
		end = end.max(entry["at"] + footprint(document, entry["box"]))
	return Rect2(Vector2.ZERO, end / G)


func _draw() -> void:
	var font: Font = AppTheme.schematic_font()
	for entry: Dictionary in placed:
		var caption: PackedStringArray = _caption(document.control_boxes[entry["box"]])
		var at: Vector2 = entry["at"] + Vector2(0.0, CAPTION_H - 10.0)
		draw_string(font, at, caption[0], HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE, SchematicTheme.DESIGNATION)
		var shift: float = font.get_string_size(caption[0], HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE).x + CAPTION_GAP
		draw_string(font, at + Vector2(shift, 0.0), caption[1], HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE - 2, SchematicTheme.TEXT)
