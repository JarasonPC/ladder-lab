class_name ControlBox
extends RefCounted
## A control station of the workspace (ovládací skříňka, location "+ST1"): a
## housing with push buttons, switches and signal lamps ([ControlBoxItem])
## placed in rows of [member columns], left to right and top to bottom. While
## simulating, the station operates the buttons and switches and shows the
## lamps. Design data only.

const MAX_COLUMNS: int = 4
## Geometry of the station's face as drawn (at scale 1, see
## [ControlBoxView]): a cell per item in rows, the housing's margins and the
## title line under the items.
const CELL_W: float = 136.0
const ROW_H: float = 60.0
const PAD_X: float = 20.0
## Room above the first row (the cable gland and the top of the housing).
const PAD_TOP: float = 30.0
const PAD_BOTTOM: float = 22.0
const TITLE_H: float = 16.0
## Scales the face can be shown at on the workspace, and the first one.
const MIN_FACE: float = 0.3
const MAX_FACE: float = 2.0
const DEFAULT_FACE: float = 0.6

## Location designation without the "+", e.g. "ST1".
var name: String = ""
## Text on the housing, may be empty.
var title: String = ""
## Items per row, 1..[constant MAX_COLUMNS].
var columns: int = 1:
	set(value):
		columns = clampi(value, 1, MAX_COLUMNS)
var items: Array[ControlBoxItem] = []
## Top-left corner of its tile on the workspace.
var position: Vector2 = Vector2.ZERO
## Shown on the workspace as its face at this scale (buttons that work while
## simulating), 0 as its tile.
var face_scale: float = 0.0


func _init(p_title: String = "", p_columns: int = 1) -> void:
	title = p_title
	columns = p_columns


func to_data() -> Dictionary:
	var list: Array[Dictionary] = []
	for item: ControlBoxItem in items:
		list.append(item.to_data())
	var d: Dictionary = {"name": name, "position": [position.x, position.y], "columns": columns, "items": list}
	if not title.is_empty():
		d["title"] = title
	if face_scale > 0.0:
		d["face"] = face_scale
	return d


## Size of the station's face at scale 1: as wide as its columns, as high as
## its rows, with the title line when it has a title.
func face_size() -> Vector2:
	var columns_used: int = clampi(items.size(), 1, columns)
	var rows: int = maxi(ceili(items.size() / float(columns)), 1)
	return Vector2(2.0 * PAD_X + columns_used * CELL_W, PAD_TOP + rows * ROW_H + PAD_BOTTOM + (TITLE_H if not title.is_empty() else 0.0))


## A face scale as kept: within [constant MIN_FACE]-[constant MAX_FACE], 0
## (the tile) for anything else.
static func valid_face(value: float) -> float:
	return clampf(value, MIN_FACE, MAX_FACE) if value > 0.0 else 0.0


## Box from [method to_data] data, or null when it is malformed. Malformed
## items are left out; a missing name is given later
## ([method SchematicDocument.name_places]).
static func from_data(data: Variant) -> ControlBox:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	var raw_columns: Variant = d.get("columns", 1)
	var box: ControlBox = ControlBox.new(str(d.get("title", "")).strip_edges(), int(raw_columns) if (raw_columns is int or raw_columns is float) else 1)
	box.name = Workspace.place_name(d.get("name", ""))
	box.position = Workspace.position_from(d.get("position", null))
	var raw_face: Variant = d.get("face", 0.0)
	box.face_scale = valid_face(float(raw_face)) if (raw_face is float or raw_face is int) else 0.0
	var raw_items: Variant = d.get("items", [])
	if raw_items is Array:
		for raw: Variant in raw_items:
			var item: ControlBoxItem = ControlBoxItem.from_data(raw)
			if item != null:
				box.items.append(item)
	return box
