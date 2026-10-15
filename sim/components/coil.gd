class_name Coil
extends Load
## Coil of a relay or contactor (terminals A1-A2). Contacts with the same
## designation follow it.

enum Kind { RELAY, CONTACTOR }

var kind: Kind


func _init(p_designation: String, p_kind: Kind = Kind.CONTACTOR) -> void:
	super(p_designation, "A1", "A2")
	kind = p_kind


## Called by the simulator when the coil gains or loses power.
func set_energized(value: bool) -> void:
	energized = value


## State seen by linked contacts. Plain coils ignore [param delayed].
func get_contact_state(_delayed: bool) -> bool:
	return energized


## Called once per simulation step, before the circuit settles.
func advance(_delta: float) -> void:
	pass
