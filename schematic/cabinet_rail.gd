class_name CabinetRail
extends RefCounted
## A DIN rail of the switchboard (rozvaděč): its devices and terminal strips
## ([CabinetItem]) left to right. The rails are stacked top to bottom with
## wire ducts between them. Design data only.

var items: Array[CabinetItem] = []


func to_data() -> Dictionary:
	var list: Array[Dictionary] = []
	for item: CabinetItem in items:
		list.append(item.to_data())
	return {"items": list}


## Rail from [method to_data] data, or null when it is malformed. Malformed
## items are left out.
static func from_data(data: Variant) -> CabinetRail:
	if not (data is Dictionary):
		return null
	var rail: CabinetRail = CabinetRail.new()
	var raw_items: Variant = (data as Dictionary).get("items", [])
	if raw_items is Array:
		for raw: Variant in raw_items:
			var item: CabinetItem = CabinetItem.from_data(raw)
			if item != null:
				rail.items.append(item)
	return rail
