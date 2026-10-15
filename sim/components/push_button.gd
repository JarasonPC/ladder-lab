class_name PushButton
extends SwitchingElement
## Momentary push button: operated only while held. Blocks with the same
## designation (e.g. S1 13-14 and S1 21-22) share one actuator, so pressing
## the button operates all of them; it needs [constant TRAVEL_TIME] to move,
## and its NC blocks break before its NO blocks make.

const TRAVEL_TIME: float = 0.010

## Shared by all blocks of the button (assigned by [Circuit]).
var actuator: Armature = Armature.new(TRAVEL_TIME, TRAVEL_TIME)
var pressed: bool:
	get:
		return actuator.target
	set(value):
		actuator.target = value


func press() -> void:
	pressed = true


func release() -> void:
	pressed = false


func get_armature() -> Armature:
	return actuator
