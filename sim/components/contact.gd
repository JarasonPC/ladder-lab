class_name Contact
extends SwitchingElement
## Auxiliary or main contact of a relay, contactor or timer. Follows the coil
## with the same designation. Delayed contacts (terminals x5-x6 / x7-x8) follow
## the timed output of a [TimerRelay]; ordinary contacts follow the coil power.
## A contact with no matching coil stays in its rest position.

var delayed: bool
## Set by [Circuit] when a coil with the same designation exists.
var linked_coil: Coil = null


func _init(p_designation: String, p_type: ContactType, p_sequence: int = 1, p_delayed: bool = false) -> void:
	super(p_designation, p_type, p_sequence, p_delayed)
	delayed = p_delayed
	id = "%s:%s-%s" % [designation, _terminals[0], _terminals[1]]


func is_actuated() -> bool:
	if linked_coil == null:
		return false
	return linked_coil.get_contact_state(delayed)
