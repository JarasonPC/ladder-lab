class_name WorkspaceGroup
extends RefCounted
## A group of parts outside the switchboards on the workspace (location
## "+G1"), e.g. a gate with its motor and limit switches: a frame round its
## members that moves them together. A group can be a machine part moved by
## one of its motors (the mechanical link, see [Travel]): it takes
## [member travel_time] from one end to the other and operates its limit
## switches where they are ([member stops]). Design data only.

## Location designation without the "+", e.g. "G1".
var name: String = ""
## Free text, e.g. "Gate"; may be empty.
var title: String = ""
## Designations of the parts in the group (see [method Workspace.field_devices]).
var members: PackedStringArray = PackedStringArray()
## Where the frame sits while it has no members (top-left corner).
var position: Vector2 = Vector2.ZERO
## Mechanical link: the member motor that moves the part, "" for none.
var drive: String = ""
## Seconds the part takes from one end to the other at full speed.
var travel_time: float = 10.0
## Where the part is when the simulation starts, 0-1.
var start: float = 0.0
## Member limit switches operated by the part -> where they are, 0-1 (0: the
## end the part moves to when the motor turns backwards).
var stops: Dictionary[String, float] = {}


func _init(p_name: String = "", p_position: Vector2 = Vector2.ZERO) -> void:
	name = p_name
	position = p_position


func to_data() -> Dictionary:
	var d: Dictionary = {"name": name, "position": [position.x, position.y], "members": Array(members)}
	if not title.is_empty():
		d["title"] = title
	if not drive.is_empty():
		var at: Dictionary = {}
		for designation: String in stops:
			at[designation] = stops[designation]
		d["drive"] = drive
		d["travel_time"] = travel_time
		d["start"] = start
		d["stops"] = at
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
	group.drive = Workspace.place_name(d.get("drive", ""))
	var raw_time: Variant = d.get("travel_time", 10.0)
	group.travel_time = clampf(float(raw_time), 0.1, 3600.0) if (raw_time is float or raw_time is int) else 10.0
	var raw_start: Variant = d.get("start", 0.0)
	group.start = clampf(float(raw_start), 0.0, 1.0) if (raw_start is float or raw_start is int) else 0.0
	var raw_stops: Variant = d.get("stops", {})
	if raw_stops is Dictionary:
		for key: Variant in raw_stops:
			var value: Variant = raw_stops[key]
			if key is String and (value is float or value is int):
				group.stops[key] = clampf(float(value), 0.0, 1.0)
	return group
