class_name ThreePoleFuse
extends PoleDevice
## Multi-pole fuse, 2-4 fuses in one (1-2, 3-4, 5-6, 7-8; three unless set
## otherwise). Each pole blows on its own when fault current flows through it;
## [method reset] replaces the blown ones. In a multi-pole fuse holder
## ([member holder]) all poles are opened and closed together by hand.

## 1 for each blown pole.
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
	blown = PackedByteArray()
	blown.resize(poles)


func protection_state() -> int:
	var state: int = 16 if switched_on else 0
	for p: int in blown.size():
		state |= blown[p] << p
	return state


func _poles_changed() -> void:
	reset()


func trip_message() -> String:
	return "%s blown"
