class_name CamSwitch
extends CircuitComponent
## Rotary cam switch (vačkový spínač, designation "RB1") of 1-4 poles,
## turned by hand with its knob. Positions 0-I: each pole a make contact,
## terminals 1-2, 3-4, 5-6, 7-8, closed in position I. Positions I-0-II
## (forward / off / reverse): each pole a changeover with the off position
## in the middle, its common (load side) 2, 4, 6, 8 joined to 1, 3, 5, 7 in
## position I and to 1', 3', 5', 7' in position II, never to both. Snap
## action: it moves at once. It starts in position 0.

## Positions it has, as marked on its front.
enum Positions { OFF_ON, CHANGEOVER }

## Position names as saved, in [enum Positions] order.
const POSITION_NAMES: PackedStringArray = ["0-I", "I-0-II"]
## Its positions ([member position]).
const OFF: int = 0
const ONE: int = 1
const TWO: int = 2
## What each position is marked on the front, by [member position].
const MARKS: PackedStringArray = ["0", "I", "II"]

## Number of poles (1-4; design data). Three unless set otherwise.
var poles: int = 3:
	set(value):
		poles = clampi(value, 1, 4)
		_update_id()
## Positions 0-I or I-0-II (design data).
var positions: Positions = Positions.OFF_ON:
	set(value):
		positions = value
		_update_id()
## Where the knob is: [constant OFF], [constant ONE] (I) or [constant TWO]
## (II, only with [constant Positions.CHANGEOVER]). Simulation state.
var position: int = OFF:
	set(value):
		position = value if value == OFF or value == ONE or (value == TWO and positions == Positions.CHANGEOVER) else OFF
## Turned back to 0 from I last: the next [method step_on] goes on to II.
var _from_one: bool = false


func _init(p_designation: String, p_positions: Positions = Positions.OFF_ON, p_poles: int = 3) -> void:
	super(p_designation)
	positions = p_positions
	poles = p_poles


## 0-I: 1, 2, 3, 4, ...; I-0-II: each pole I side, II side, common
## (1, 1', 2, 3, 3', 4, ...).
func default_terminal_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for p: int in poles:
		names.append(str(2 * p + 1))
		if positions == Positions.CHANGEOVER:
			names.append(str(2 * p + 1) + "'")
		names.append(str(2 * p + 2))
	return names


## Terminals of each pole: 2 (0-I) or 3 (I-0-II).
func pole_terminals() -> int:
	return 3 if positions == Positions.CHANGEOVER else 2


## 0-I: one path a pole, 1-2, 3-4 ...; I-0-II: two a pole, common to the I
## side (even paths) and common to the II side (odd paths).
func switch_paths() -> Array[Vector2i]:
	var paths: Array[Vector2i] = []
	for p: int in poles:
		if positions == Positions.CHANGEOVER:
			paths.append(Vector2i(3 * p + 2, 3 * p))
			paths.append(Vector2i(3 * p + 2, 3 * p + 1))
		else:
			paths.append(Vector2i(2 * p, 2 * p + 1))
	return paths


func is_path_closed(path: int) -> bool:
	if positions == Positions.CHANGEOVER:
		return position == (ONE if path % 2 == 0 else TWO)
	return position == ONE


## Positions the knob passes turned from the left to the right: 0 I, or
## I 0 II.
func knob_positions() -> PackedInt32Array:
	return PackedInt32Array([ONE, OFF, TWO]) if positions == Positions.CHANGEOVER else PackedInt32Array([OFF, ONE])


## Turns the knob [param steps] positions to the right (negative: to the
## left), stopping at its last position either way.
func turn(steps: int) -> void:
	var order: PackedInt32Array = knob_positions()
	var at: int = clampi(order.find(position) + steps, 0, order.size() - 1)
	_from_one = position == ONE and order[at] == OFF
	position = order[at]


## Turns it on to the next position: 0 → I → 0 → II → 0 (0-I: on and off).
func step_on() -> void:
	if positions == Positions.OFF_ON:
		position = OFF if position == ONE else ONE
		return
	if position == OFF:
		position = TWO if _from_one else ONE
	else:
		_from_one = position == ONE
		position = OFF


## How far the knob is turned, -1 (left end) .. 1 (right end) as on the
## front: 0-I from -1 (0) to 1 (I); I-0-II -1 (I), 0, 1 (II).
func knob_angle() -> float:
	var order: PackedInt32Array = knob_positions()
	return -1.0 + 2.0 * order.find(position) / float(order.size() - 1)


func _update_id() -> void:
	id = "%s:%s" % [designation, "-".join(get_terminal_names())]
