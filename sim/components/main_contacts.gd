class_name MainContacts
extends PoleDevice
## Main (power) contacts of a contactor with the same designation (1-4 poles,
## three unless set otherwise): 1-2, 3-4, 5-6, 7-8. They make with the NO contacts, at the end of the armature
## travel (see [Armature]).

## Injected fault: WELDED stays closed, OPEN never closes.
var fault: SwitchingElement.Fault = SwitchingElement.Fault.NONE
## Set by [Circuit] when a coil with the same designation exists.
var linked_coil: Coil = null


func _init(p_designation: String) -> void:
	super(p_designation)
	_update_id()


func get_armature() -> Armature:
	return linked_coil.armature if linked_coil != null else null


func get_travel() -> float:
	var a: Armature = get_armature()
	return a.position if a != null else 0.0


func is_path_closed(_path: int) -> bool:
	match fault:
		SwitchingElement.Fault.WELDED:
			return true
		SwitchingElement.Fault.OPEN:
			return false
	var a: Armature = get_armature()
	return a != null and a.no_closed
