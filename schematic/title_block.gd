class_name TitleBlock
extends RefCounted
## Texts of the title block on exported sheets (popisové pole): who drew and
## checked the schematic, the company, project, drawing number, revision and
## date. Free text, all may be empty; the schematic title is
## [member SchematicDocument.title]. Design data only, saved with the document.

## Fields in the order they are edited, keyed as saved.
const FIELDS: PackedStringArray = ["company", "project", "drawing_number", "revision", "drawn_by", "checked_by", "date"]

var company: String = ""
var project: String = ""
var drawing_number: String = ""
var revision: String = ""
var drawn_by: String = ""
var checked_by: String = ""
## Date written in the title block; "" = the date of the export.
var date: String = ""


func is_empty() -> bool:
	for field: String in FIELDS:
		if not (get(field) as String).is_empty():
			return false
	return true


func equals(other: TitleBlock) -> bool:
	return to_data() == other.to_data()


func copy() -> TitleBlock:
	return from_data(to_data())


## The filled fields only.
func to_data() -> Dictionary:
	var d: Dictionary = {}
	for field: String in FIELDS:
		var value: String = get(field)
		if not value.is_empty():
			d[field] = value
	return d


## Title block from [method to_data] data; anything malformed is left empty.
static func from_data(data: Variant) -> TitleBlock:
	var block: TitleBlock = TitleBlock.new()
	if data is Dictionary:
		for field: String in FIELDS:
			var value: Variant = (data as Dictionary).get(field, "")
			if value is String:
				block.set(field, (value as String).strip_edges())
	return block
