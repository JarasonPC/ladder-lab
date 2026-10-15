class_name ProtectiveDevice
extends SwitchingElement
## Fuse or circuit breaker in a conductor (terminals 1-2). A short circuit
## whose fault current flows through it trips it (see [Simulator]); it then
## stays open until reset.

var tripped: bool = false


func _init(p_designation: String) -> void:
	super(p_designation, ContactType.NC, 0)


func _update_id() -> void:
	id = designation


func trip() -> void:
	tripped = true


func trip_path(_path: int) -> bool:
	if tripped or not is_closed():
		return false
	trip()
	return true


func protection_state() -> int:
	return 1 if tripped else 0


func reset() -> void:
	tripped = false


func _closed_by_state() -> bool:
	return not tripped
