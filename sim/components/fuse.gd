class_name Fuse
extends ProtectiveDevice
## Fuse (designation "F2", terminals 1-2). Blows on a short circuit through
## it; [method ProtectiveDevice.reset] replaces it. In a fuse holder
## ([member holder], fuse disconnector) it can also be opened and closed by
## hand.

## Mounted in a fuse holder that can be opened (design data).
var holder: bool = false
## A fuse holder is closed (simulation state; holders start open).
var switched_on: bool = false


func _closed_by_state() -> bool:
	return not tripped and (switched_on or not holder)


## Opens or closes a fuse holder.
func toggle() -> void:
	if holder:
		switched_on = not switched_on


func protection_state() -> int:
	return (1 if tripped else 0) | (2 if switched_on else 0)


func trip_message() -> String:
	return "%s blown"
