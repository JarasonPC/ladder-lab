class_name TimerRelay
extends Coil
## Time relay (designation usually "KT1"). Delayed contacts follow
## [member output] through their own [member output_armature]; instantaneous
## contacts follow the coil power through [member armature].
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
## Timed output (where the delayed contacts are heading).
var output: bool = false
## Seconds counted in the current timing run.
var elapsed: float = 0.0
## Moves the delayed contacts.
var output_armature: Armature


func _init(p_designation: String, p_mode: Mode, p_delay: float, p_pick_up: float = -1.0, p_drop_out: float = -1.0) -> void:
	super(p_designation, Kind.RELAY, p_pick_up, p_drop_out)
	mode = p_mode
	delay = p_delay
	output_armature = _new_armature()


func set_energized(value: bool) -> void:
	if value != energized:
		energized = value
		elapsed = 0.0
		match mode:
			Mode.ON_DELAY:
				output = value and delay <= 0.0
			Mode.OFF_DELAY:
				if value or delay <= 0.0:
					output = value
	_sync_targets()


func get_armature(delayed: bool) -> Armature:
	return output_armature if delayed else armature


func snap() -> void:
	armature.snap(armature.target)
	output_armature.snap(output_armature.target)


func advance(delta: float) -> void:
	if _timing():
		elapsed += delta
		if elapsed + _EPSILON >= delay:
			output = mode == Mode.ON_DELAY
	_sync_targets()


func move_armatures(delta: float) -> void:
	armature.advance(delta)
	output_armature.advance(delta)


func time_to_next_event() -> float:
	var t: float = minf(armature.time_to_next_event(), output_armature.time_to_next_event())
	if _timing():
		t = minf(t, maxf(delay - elapsed, 0.0))
	return t


## Seconds left until the output switches, 0 when not timing.
func get_remaining() -> float:
	return maxf(delay - elapsed, 0.0) if _timing() else 0.0


func _timing() -> bool:
	return (energized and not output) if mode == Mode.ON_DELAY else (not energized and output)


func _sync_targets() -> void:
	armature.target = energized
	if output_armature != null:
		output_armature.target = output


func _apply_fault() -> void:
	armature.stuck = fault == Fault.STUCK
	output_armature.stuck = fault == Fault.STUCK
