class_name LatchingSwitch
extends SwitchingElement
## Switch that keeps its position until operated again.

var switched_on: bool = false


func toggle() -> void:
	switched_on = not switched_on


func set_switched_on(value: bool) -> void:
	switched_on = value


func is_actuated() -> bool:
	return switched_on
