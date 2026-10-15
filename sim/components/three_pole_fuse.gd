class_name ThreePoleFuse
extends PoleDevice
## Three fuses in one (1-2, 3-4, 5-6). Each pole blows on its own when fault
## current flows through it; [method reset] replaces the blown ones. In a
## three-pole fuse holder ([member holder]) all poles are opened and closed
## together by hand.

var blown: PackedByteArray = PackedByteArray([0, 0, 0])
## Mounted in a fuse holder that can be opened (design data).
var holder: bool = false
## A fuse holder is closed (simulation state).
var switched_on: bool = true


func _init(p_designation: String) -> void:
	super(p_designation)
	_update_id()


func is_path_closed(path: int) -> bool:
	return blown[path] == 0 and (switched_on or not holder)


## Opens or closes a fuse holder.
func toggle() -> void:
	if holder:
		switched_on = not switched_on


func trip_path(path: int) -> bool:
	if not is_path_closed(path):
		return false
	blown[path] = 1
	return true


func any_blown() -> bool:
	return blown.has(1)


func reset() -> void:
	blown = PackedByteArray([0, 0, 0])


func protection_state() -> int:
	return blown[0] | (blown[1] << 1) | (blown[2] << 2) | (8 if switched_on else 0)


func trip_message() -> String:
	return "%s blown"
