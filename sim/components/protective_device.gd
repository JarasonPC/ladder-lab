class_name ProtectiveDevice
extends SwitchingElement
## Fuse or circuit breaker in a conductor (terminals 1-2). A short circuit
## whose fault current flows through it trips it (see [Simulator]); it then
## stays open until reset.

var tripped: bool = false


func _init(p_designation: String) -> void:
	super(p_designation, ContactType.NC, 0)
	id = designation


func trip() -> void:
	tripped = true


func reset() -> void:
	tripped = false


func _closed_by_state() -> bool:
	return not tripped
