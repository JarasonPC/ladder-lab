class_name Switchboard
extends RefCounted
## A switchboard (rozvaděč, location "+RA1") of the workspace: its DIN rails
## ([CabinetRail]) with the devices and terminal strips of the circuit, top to
## bottom, and where it sits on the workspace. Design data only.

## Location designation without the "+", e.g. "RA1".
var name: String = ""
## Free text, e.g. "Main switchboard"; may be empty.
var title: String = ""
var rails: Array[CabinetRail] = []
## Top-left corner of its tile on the workspace.
var position: Vector2 = Vector2.ZERO


func _init(p_name: String = "", p_position: Vector2 = Vector2.ZERO) -> void:
	name = p_name
	position = p_position


func to_data() -> Dictionary:
	var list: Array[Dictionary] = []
	for rail: CabinetRail in rails:
		list.append(rail.to_data())
	var d: Dictionary = {"name": name, "position": [position.x, position.y], "rails": list}
	if not title.is_empty():
		d["title"] = title
	return d


## Switchboard from [method to_data] data, or null when it is malformed.
## Malformed rails are left out; a missing name is given later
## ([method SchematicDocument.name_places]).
static func from_data(data: Variant) -> Switchboard:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	var board: Switchboard = Switchboard.new(Workspace.place_name(d.get("name", "")), Workspace.position_from(d.get("position", null)))
	board.title = str(d.get("title", "")).strip_edges()
	var raw_rails: Variant = d.get("rails", [])
	if raw_rails is Array:
		for raw: Variant in raw_rails:
			var rail: CabinetRail = CabinetRail.from_data(raw)
			if rail != null:
				board.rails.append(rail)
	return board
