class_name Contact
extends SwitchingElement
## Auxiliary or main contact of a relay, contactor or timer. Follows the
## armature of the coil with the same designation (see [Armature] for when NO
## and NC contacts switch). Delayed contacts (terminals x5-x6 / x7-x8) follow
## the timed output of a [TimerRelay]; ordinary contacts follow the coil.
## Without a coil it follows a push button, switch or limit switch with the
## same designation (one more block of that device), else a circuit breaker
## with the same designation (its auxiliary contact: NO closed while the
## breaker is on). A contact with no such device stays in its rest position.

var delayed: bool
## Set by [Circuit] when a coil with the same designation exists.
var linked_coil: Coil = null
## Set by [Circuit] when there is no coil but a button or switch with the
## same designation: its actuator.
var linked_actuator: Armature = null
## Set by [Circuit] when there is no coil, button or switch but a circuit
## breaker with the same designation.
var linked_breaker: CircuitComponent = null


func _init(p_designation: String, p_type: ContactType, p_sequence: int = 1, p_delayed: bool = false) -> void:
	super(p_designation, p_type, p_sequence, p_delayed)
	delayed = p_delayed


func get_armature() -> Armature:
	return linked_coil.get_armature(delayed) if linked_coil != null else linked_actuator


## True when a coil, button, switch or breaker operates this contact.
func has_device() -> bool:
	return linked_coil != null or linked_actuator != null or linked_breaker != null


func _closed_by_state() -> bool:
	if get_armature() == null and linked_breaker != null:
		var on: bool = linked_breaker.is_path_closed(0)
		return on if contact_type == ContactType.NO else not on
	return super()
