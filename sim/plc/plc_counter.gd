class_name PlcCounter
extends RefCounted
## Up/down counter of a PLC program: counts the rising edges of its count
## inputs; its output is on while the count has reached [member preset].

## Highest count.
const MAX_VALUE: int = 999999

var value: int = 0
## Count at which the output comes on (at least 1).
var preset: int = 1
var _last_up: bool = false
var _last_down: bool = false


## One scan of the up-count input.
func count_up(input: bool) -> void:
	if input and not _last_up:
		value = mini(value + 1, MAX_VALUE)
	_last_up = input


## One scan of the down-count input.
func count_down(input: bool) -> void:
	if input and not _last_down:
		value = maxi(value - 1, 0)
	_last_down = input


func reset() -> void:
	value = 0


func output() -> bool:
	return value >= maxi(preset, 1)
