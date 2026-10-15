class_name PushButton
extends SwitchingElement
## Momentary push button: operated only while held.

var pressed: bool = false


func press() -> void:
	pressed = true


func release() -> void:
	pressed = false


func is_actuated() -> bool:
	return pressed
