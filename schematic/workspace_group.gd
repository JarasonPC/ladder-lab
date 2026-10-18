class_name WorkspaceGroup
extends RefCounted
## A group of parts outside the switchboards on the workspace (location
## "+G1"), e.g. a gate with its motor and limit switches: a frame round its
## members that moves them together. Design data only.

## Location designation without the "+", e.g. "G1".
var name: String = ""
## Free text, e.g. "Gate"; may be empty.
var title: String = ""
## Designations of the parts in the group (see [method Workspace.field_devices]).
var members: PackedStringArray = PackedStringArray()
## Where the frame sits while it has no members (top-left corner).
var position: Vector2 = Vector2.ZERO


func _init(p_name: String = "", p_position: Vector2 = Vector2.ZERO) -> void:
	name = p_name
	position = p_position


func to_data() -> Dictionary:
	var d: Dictionary = {"name": name, "position": [position.x, position.y], "members": Array(members)}
	if not title.is_empty():
		d["title"] = title
	return d


## Group from [method to_data] data, or null when it is malformed.
static func from_data(data: Variant) -> WorkspaceGroup:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	var group: WorkspaceGroup = WorkspaceGroup.new(Workspace.place_name(d.get("name", "")), Workspace.position_from(d.get("position", null)))
	group.title = str(d.get("title", "")).strip_edges()
	var raw_members: Variant = d.get("members", [])
	if raw_members is Array:
		for raw: Variant in raw_members:
			var designation: String = Workspace.place_name(raw)
			if not designation.is_empty() and not group.members.has(designation):
				group.members.append(designation)
	return group
