class_name Switchboard
extends RefCounted
## A switchboard (rozvaděč, location "+RA1") of the workspace: its DIN rails
## ([CabinetRail]) with the devices and terminal strips of the circuit, top to
## bottom, the push buttons, switches and signal lamps on its door, and where
## it sits on the workspace, and what its temperature rise calculation is
## given ([HeatRise]). Design data only.

## Items in a row on a new door.
const DOOR_COLUMNS: int = 3

## Location designation without the "+", e.g. "RA1".
var name: String = ""
## Free text, e.g. "Main switchboard"; may be empty.
var title: String = ""
var rails: Array[CabinetRail] = []
## The door: its push buttons, switches and signal lamps in rows of its
## columns, as on a control station (its name, title, position and face
## unused).
var door: ControlBox = ControlBox.new("", DOOR_COLUMNS)
## Top-left corner of its tile on the workspace.
var position: Vector2 = Vector2.ZERO
## What its temperature rise calculation is given beyond the drawing (see
## [method HeatRise.settings]): only what differs from
## [constant HeatRise.DEFAULTS].
var heat: Dictionary = {}


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
	if not door.items.is_empty() or door.columns != DOOR_COLUMNS:
		d["door"] = {"columns": door.columns, "items": door.to_data()["items"]}
	if not heat.is_empty():
		d["heat"] = heat.duplicate(true)
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
	var raw_door: Variant = d.get("door", null)
	if raw_door is Dictionary:
		var door: ControlBox = ControlBox.from_data(raw_door)
		if door != null:
			board.door = door
	board.door.name = ""
	board.heat = HeatRise.changed(HeatRise.settings(d.get("heat", {})))
	return board
