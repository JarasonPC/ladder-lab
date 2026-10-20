class_name AnalogSensor
extends Load
## A transmitter with a 0-10 V output, three wires as the usual ones: a
## supply (24 V DC) on its first two terminals and the output against the
## second. While it has its supply it puts 0 V at [member range_min] and
## 10 V at [member range_max] of what it measures ([method measured]) on
## its output, in between in proportion (held within 0-10 V).

## Volts at the top of the range.
const FULL_SCALE: float = 10.0
## Current drawn while working (amperes).
const DRAW: float = 0.015

var range_min: float = 0.0
var range_max: float = 100.0


func rated_draw() -> float:
	return DRAW


## Terminal index of the output.
func output_terminal() -> int:
	return 2


## What it measures now, in [method unit]s. Override.
func measured() -> float:
	return 0.0


## Sets what it measures (while simulating). Override.
func set_measured(_value: float) -> void:
	pass


## Unit of the range and of what it measures, e.g. "°C", "bar".
func unit() -> String:
	return ""


## Limits of the range and of what it measures.
func lowest() -> float:
	return -1000.0


func highest() -> float:
	return 10000.0


## Volts on its output against the reference (0 without its supply;
## [param powered]: whether it has it, else as [member energized]).
func output_volts(powered: Variant = null) -> float:
	var on: bool = energized if powered == null else bool(powered)
	if not on or range_max <= range_min:
		return 0.0
	return clampf((measured() - range_min) / (range_max - range_min), 0.0, 1.0) * FULL_SCALE
