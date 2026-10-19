class_name LatchingSwitch
extends SwitchingElement
## Switch that keeps its position until operated again. Snap action: it moves
## almost at once. Blocks with the same designation share one actuator.
##
## A selector switch with the positions I-0-II ([member three_positions])
## has a second actuator for position II, shared the same way: each block is
## operated in position I or in position II ([member side]), and in 0
## neither is.

## Shared by all blocks of the switch (assigned by [Circuit]); for I-0-II
## the one of position I.
var actuator: Armature = Armature.new(Armature.MIN_TIME, Armature.MIN_TIME)
## Of position II, for I-0-II (assigned by [Circuit] like [member actuator]).
var actuator_two: Armature = Armature.new(Armature.MIN_TIME, Armature.MIN_TIME)
## Positions I-0-II instead of 0-I (design data).
var three_positions: bool = false
## Position that operates this block: 1 (I) or 2 (II, only with
## [member three_positions]) (design data).
var side: int = 1:
	set(value):
		side = 2 if value == 2 else 1
## This block is operated (its position is set). Set: 0-I on or off; I-0-II
## to this block's position or 0.
var switched_on: bool:
	get:
		return get_armature().target
	set(value):
		if three_positions:
			set_position(_side() if value else 0)
		else:
			actuator.target = value
## Turned back to 0 from I last: the next [method toggle] goes on to II.
var _from_one: bool = false


## 0, 1 (I) or 2 (II) where the switch is set.
func get_position() -> int:
	if three_positions and actuator_two.target:
		return 2
	return 1 if actuator.target else 0


func set_position(value: int) -> void:
	actuator.target = value == 1
	actuator_two.target = three_positions and value == 2


## 0-I: on and off; I-0-II: on to the next position, 0 → I → 0 → II → 0.
func toggle() -> void:
	if not three_positions:
		switched_on = not switched_on
		return
	var at: int = get_position()
	if at == 0:
		set_position(2 if _from_one else 1)
	else:
		_from_one = at == 1
		set_position(0)


## I-0-II: turns the knob [param steps] positions to the right (negative: to
## the left) through I, 0, II, stopping at either end; 0-I: right is I.
func turn(steps: int) -> void:
	var order: PackedInt32Array = PackedInt32Array([1, 0, 2]) if three_positions else PackedInt32Array([0, 1])
	var at: int = clampi(order.find(get_position()) + steps, 0, order.size() - 1)
	_from_one = get_position() == 1 and order[at] == 0
	set_position(order[at])


func set_switched_on(value: bool) -> void:
	switched_on = value


func get_armature() -> Armature:
	return actuator_two if _side() == 2 else actuator


func _side() -> int:
	return side if three_positions else 1
