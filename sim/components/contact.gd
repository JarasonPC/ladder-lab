class_name Contact
extends SwitchingElement
## Auxiliary or main contact of a relay, contactor or timer. Follows the
## armature of the coil with the same designation (see [Armature] for when NO
## and NC contacts switch). Delayed contacts (terminals x5-x6 / x7-x8) follow
## the timed output of a [TimerRelay]; ordinary contacts follow the coil.
## A contact with no matching coil stays in its rest position.

var delayed: bool
## Set by [Circuit] when a coil with the same designation exists.
var linked_coil: Coil = null


func _init(p_designation: String, p_type: ContactType, p_sequence: int = 1, p_delayed: bool = false) -> void:
	super(p_designation, p_type, p_sequence, p_delayed)
	delayed = p_delayed


func get_armature() -> Armature:
	return linked_coil.get_armature(delayed) if linked_coil != null else null
