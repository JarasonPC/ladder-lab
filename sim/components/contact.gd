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
	id = "%s:%s-%s" % [designation, _terminals[0], _terminals[1]]


func is_actuated() -> bool:
	return linked_coil != null and linked_coil.get_armature(delayed).no_closed


func is_closed() -> bool:
	if linked_coil == null:
		return contact_type == ContactType.NC
	var a: Armature = linked_coil.get_armature(delayed)
	return a.no_closed if contact_type == ContactType.NO else not a.nc_open


## Armature position 0..1 driving this contact (for drawing it in motion).
func get_travel() -> float:
	return linked_coil.get_armature(delayed).position if linked_coil != null else 0.0
