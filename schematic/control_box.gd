class_name ControlBox
extends RefCounted
## A control station of the operator panel (ovládací skříňka): a housing with
## push buttons, switches and signal lamps ([ControlBoxItem]) placed in rows
## of [member columns], left to right and top to bottom. While simulating, the
## panel operates the buttons and switches and shows the lamps. Design data only.

const MAX_COLUMNS: int = 4

## Text on the housing, may be empty.
var title: String = ""
## Items per row, 1..[constant MAX_COLUMNS].
var columns: int = 1:
	set(value):
		columns = clampi(value, 1, MAX_COLUMNS)
var items: Array[ControlBoxItem] = []


func _init(p_title: String = "", p_columns: int = 1) -> void:
	title = p_title
	columns = p_columns


func to_data() -> Dictionary:
	var list: Array[Dictionary] = []
	for item: ControlBoxItem in items:
		list.append(item.to_data())
	var d: Dictionary = {"columns": columns, "items": list}
	if not title.is_empty():
		d["title"] = title
	return d


## Box from [method to_data] data, or null when it is malformed. Malformed
## items are left out.
static func from_data(data: Variant) -> ControlBox:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	var raw_columns: Variant = d.get("columns", 1)
	var box: ControlBox = ControlBox.new(str(d.get("title", "")).strip_edges(), int(raw_columns) if (raw_columns is int or raw_columns is float) else 1)
	var raw_items: Variant = d.get("items", [])
	if raw_items is Array:
		for raw: Variant in raw_items:
			var item: ControlBoxItem = ControlBoxItem.from_data(raw)
			if item != null:
				box.items.append(item)
	return box
