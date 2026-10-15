class_name ThreePoleFuse
extends PoleDevice
## Three fuses in one (1-2, 3-4, 5-6). Each pole blows on its own when fault
## current flows through it; [method reset] replaces the blown ones.

var blown: PackedByteArray = PackedByteArray([0, 0, 0])


func _init(p_designation: String) -> void:
	super(p_designation)
	_update_id()


func is_path_closed(path: int) -> bool:
	return blown[path] == 0


func trip_path(path: int) -> bool:
	if blown[path] == 1:
		return false
	blown[path] = 1
	return true


func any_blown() -> bool:
	return blown.has(1)


func reset() -> void:
	blown = PackedByteArray([0, 0, 0])


func protection_state() -> int:
	return blown[0] | (blown[1] << 1) | (blown[2] << 2)


func trip_message() -> String:
	return "%s blown"
