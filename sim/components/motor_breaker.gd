class_name MotorBreaker
extends PoleDevice
## Three-pole circuit breaker (motor protective breaker, designation "Q1").
## Fault current through any pole trips all three; it is switched off and on
## by hand, and switching on resets a trip.

var switched_on: bool = true
var tripped: bool = false


func _init(p_designation: String) -> void:
	super(p_designation)
	_update_id()


func is_path_closed(_path: int) -> bool:
	return switched_on and not tripped


func trip_path(_path: int) -> bool:
	if tripped or not switched_on:
		return false
	tripped = true
	return true


func toggle() -> void:
	if tripped:
		tripped = false
		switched_on = true
	else:
		switched_on = not switched_on


func protection_state() -> int:
	return (1 if tripped else 0) | (2 if switched_on else 0)
