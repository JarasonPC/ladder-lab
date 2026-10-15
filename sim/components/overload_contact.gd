class_name OverloadContact
extends SwitchingElement
## Auxiliary contact of a thermal overload relay with the same designation:
## NC 95-96 opens and NO 97-98 closes when the relay has tripped
## (ČSN EN 60947-4-1 marking).

## Set by [Circuit] when an overload relay with the same designation exists.
var linked_relay: OverloadRelay = null


func _init(p_designation: String, p_type: ContactType) -> void:
	super(p_designation, p_type, 9)
	_terminals = PackedStringArray(["95", "96"] if p_type == ContactType.NC else ["97", "98"])
	id = "%s:%s-%s" % [designation, _terminals[0], _terminals[1]]


func is_actuated() -> bool:
	return linked_relay != null and linked_relay.tripped


func _closed_by_state() -> bool:
	return is_actuated() if contact_type == ContactType.NO else not is_actuated()
