class_name TimerRelay
extends Coil
## Time relay (designation usually "KT1"). Delayed contacts follow
## [member output]; instantaneous contacts follow the coil power.
##
## ON_DELAY: output turns on [member delay] seconds after the coil is energized
## and turns off immediately when power is removed.
## OFF_DELAY: output turns on immediately with power and turns off [member delay]
## seconds after power is removed.

enum Mode { ON_DELAY, OFF_DELAY }

const _EPSILON: float = 1e-9

var mode: Mode
## Delay in seconds.
var delay: float
## Timed output (state of the delayed contacts).
var output: bool = false
## Seconds counted in the current timing run.
var elapsed: float = 0.0


func _init(p_designation: String, p_mode: Mode, p_delay: float) -> void:
	super(p_designation, Kind.RELAY)
	mode = p_mode
	delay = p_delay


func set_energized(value: bool) -> void:
	if value == energized:
		return
	energized = value
	elapsed = 0.0
	match mode:
		Mode.ON_DELAY:
			output = value and delay <= 0.0
		Mode.OFF_DELAY:
			if value or delay <= 0.0:
				output = value


func get_contact_state(delayed: bool) -> bool:
	return output if delayed else energized


func advance(delta: float) -> void:
	match mode:
		Mode.ON_DELAY:
			if energized and not output:
				elapsed += delta
				if elapsed + _EPSILON >= delay:
					output = true
		Mode.OFF_DELAY:
			if not energized and output:
				elapsed += delta
				if elapsed + _EPSILON >= delay:
					output = false

