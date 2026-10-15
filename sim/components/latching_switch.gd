class_name LatchingSwitch
extends SwitchingElement
## Switch that keeps its position until operated again. Snap action: it moves
## almost at once. Blocks with the same designation share one actuator.

## Shared by all blocks of the switch (assigned by [Circuit]).
var actuator: Armature = Armature.new(Armature.MIN_TIME, Armature.MIN_TIME)
var switched_on: bool:
	get:
		return actuator.target
	set(value):
		actuator.target = value


func toggle() -> void:
	switched_on = not switched_on


func set_switched_on(value: bool) -> void:
	switched_on = value


func get_armature() -> Armature:
	return actuator
