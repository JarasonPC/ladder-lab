class_name ChangeoverContact
extends CircuitComponent
## Changeover contact of a relay, contactor or timer with the same
## designation: a common terminal switched between an NC and an NO side,
## marked common-NC-NO, e.g. 11-12-14 (ČSN EN 60947-1), delayed timer contacts
## 15-16-18. At rest common-NC is closed; operating the armature first breaks
## common-NC, then makes common-NO (see [Armature]).

## Switching paths, see [method is_path_closed].
const PATH_NC: int = 0
const PATH_NO: int = 1

var sequence: int
var delayed: bool
## Injected fault: WELDED stays in the operated position, OPEN connects nothing.
var fault: SwitchingElement.Fault = SwitchingElement.Fault.NONE
## Set by [Circuit] when a coil with the same designation exists.
var linked_coil: Coil = null


func _init(p_designation: String, p_sequence: int = 1, p_delayed: bool = false) -> void:
	super(p_designation)
	sequence = p_sequence
	delayed = p_delayed
	_update_id()


## Common, NC side, NO side.
func default_terminal_names() -> PackedStringArray:
	var prefix: String = "" if sequence == 0 else str(sequence)
	if delayed:
		return PackedStringArray([prefix + "5", prefix + "6", prefix + "8"])
	return PackedStringArray([prefix + "1", prefix + "2", prefix + "4"])


func switch_paths() -> Array[Vector2i]:
	return [Vector2i(0, 1), Vector2i(0, 2)]


func get_armature() -> Armature:
	return linked_coil.get_armature(delayed) if linked_coil != null else null


## PATH_NC: common to NC side; PATH_NO: common to NO side.
func is_path_closed(path: int) -> bool:
	match fault:
		SwitchingElement.Fault.WELDED:
			return path == PATH_NO
		SwitchingElement.Fault.OPEN:
			return false
	var a: Armature = get_armature()
	if a == null:
		return path == PATH_NC
	return not a.nc_open if path == PATH_NC else a.no_closed


func get_travel() -> float:
	var a: Armature = get_armature()
	return a.position if a != null else 0.0


func _update_id() -> void:
	id = "%s:%s" % [designation, "-".join(get_terminal_names())]
