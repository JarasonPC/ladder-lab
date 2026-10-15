class_name TimerRelay
extends Coil
## Time relay (designation usually "KT1"), modelled on real multifunction
## time relays. It is powered on A1-A2; with [member control_input] it has a
## third terminal S (control input, renameable, e.g. "TL") that counts as
## pressed when it has voltage against A2, like the button input of a real
## relay. Delayed contacts (x5-x6, x7-x8) are the relay output R and follow
## [member output] through their own [member output_armature]; instantaneous
## contacts follow the coil power through [member armature].
##
## Functions ([member mode]), t = t1 = [member delay], t2 = [member delay2]:
## - F1 PULSE_ON_POWER: R on for t after power on.
## - F2 ON_DELAY: R on t after power on.
## - F3 PULSE_ON_PRESS: S pressed -> R on for t (not retriggered).
## - F4 DELAY_AFTER_RELEASE: S released -> R on after t, until power off.
## - F5 PULSE_AFTER_RELEASE: S released -> R on for t.
## - F6 TOGGLE: every press of S switches R over (impulse relay, no memory).
## - F7 PULSE_GENERATOR: R off for t, on for 0.5 s, repeated.
## - F8 SHIFTED_PULSE: S pressed -> after t, R on for t.
## - F9 TEST: R on while powered.
## - F10 CYCLE_PAUSE_FIRST: off for t2, on for t1, repeated (asymmetric
##   cycler starting with the pause).
## - F11 CYCLE_PULSE_FIRST: on for t1, off for t2, repeated (starting with
##   the pulse).
## - F12 ON_OFF_DELAY: S pressed -> R on after t1; S released -> R off
##   after t2.
## - OFF_DELAY (true off-delay, no F code): R on with power, off t after
##   power is removed.
## Losing power resets every function except OFF_DELAY.

enum Mode { ON_DELAY, OFF_DELAY, PULSE_ON_POWER, PULSE_ON_PRESS, DELAY_AFTER_RELEASE, PULSE_AFTER_RELEASE, TOGGLE, PULSE_GENERATOR, SHIFTED_PULSE, TEST, CYCLE_PAUSE_FIRST, CYCLE_PULSE_FIRST, ON_OFF_DELAY }

## Saved names of the functions, in [enum Mode] order.
const MODE_NAMES: PackedStringArray = ["on_delay", "off_delay", "pulse_on_power", "pulse_on_press", "delay_after_release", "pulse_after_release", "toggle", "pulse_generator", "shifted_pulse", "test", "cycle_pause_first", "cycle_pulse_first", "on_off_delay"]
## Function codes of real multifunction relays, in [enum Mode] order.
const MODE_CODES: PackedStringArray = ["F2", "", "F1", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"]
## On time of the pulse generator (F7).
const GENERATOR_PULSE: float = 0.5
const _EPSILON: float = 1e-9

var mode: Mode
## Delay in seconds (t, or t1 of the functions with two times).
var delay: float
## Second time t2 in seconds (functions with two times only).
var delay2: float = 1.0
## Has the control input S (terminals A1-A2-S); design data.
var control_input: bool = false:
	set(value):
		control_input = value
		_update_id()
## The control input S is active (simulation state).
var control: bool = false
## Timed output R (where the delayed contacts are heading).
var output: bool = false
## Seconds counted in the current timing run.
var elapsed: float = 0.0
## Moves the delayed contacts.
var output_armature: Armature

## Seconds left in the running timing, -1 when not timing.
var _left: float = -1.0
## Step of the shifted pulse (1 waiting, 2 pulse).
var _stage: int = 0


func _init(p_designation: String, p_mode: Mode, p_delay: float, p_pick_up: float = -1.0, p_drop_out: float = -1.0) -> void:
	super(p_designation, Kind.RELAY, p_pick_up, p_drop_out)
	mode = p_mode
	delay = p_delay
	output_armature = _new_armature()


func default_terminal_names() -> PackedStringArray:
	return PackedStringArray(["A1", "A2", "S"]) if control_input else PackedStringArray(["A1", "A2"])


## "F3" etc., "" for the true off-delay.
static func code_of(m: Mode) -> String:
	return MODE_CODES[m]


## True for functions started by the control input S.
static func uses_control(m: Mode) -> bool:
	return m in [Mode.PULSE_ON_PRESS, Mode.DELAY_AFTER_RELEASE, Mode.PULSE_AFTER_RELEASE, Mode.TOGGLE, Mode.SHIFTED_PULSE, Mode.ON_OFF_DELAY]


## True for functions with two set times t1 and t2.
static func uses_two_times(m: Mode) -> bool:
	return m in [Mode.CYCLE_PAUSE_FIRST, Mode.CYCLE_PULSE_FIRST, Mode.ON_OFF_DELAY]


func set_energized(value: bool) -> void:
	if value != energized:
		energized = value
		if value:
			_power_on()
		else:
			_power_off()
		advance(0.0)
	_sync_targets()


## Sets the control input S; edges start the S functions while powered.
func set_control(active: bool) -> void:
	if active == control:
		return
	control = active
	if energized:
		if active:
			_press()
		else:
			_release()
		advance(0.0)
	_sync_targets()


func get_armature(delayed: bool) -> Armature:
	return output_armature if delayed else armature


func snap() -> void:
	armature.snap(armature.target)
	output_armature.snap(output_armature.target)


## Counts time; several timeouts may fall into one [param delta] (F7).
func advance(delta: float) -> void:
	var remaining: float = delta
	var guard: int = 0
	while _left >= 0.0 and remaining + _EPSILON >= _left and guard < 10000:
		remaining -= _left
		_left = -1.0
		_timeout()
		guard += 1
	if _left >= 0.0:
		_left -= remaining
		elapsed += remaining
	_sync_targets()


func move_armatures(delta: float) -> void:
	armature.advance(delta)
	output_armature.advance(delta)


func time_to_next_event() -> float:
	var t: float = minf(armature.time_to_next_event(), output_armature.time_to_next_event())
	if _left >= 0.0:
		t = minf(t, _left)
	return t


## Seconds left until the output switches, 0 when not timing.
func get_remaining() -> float:
	return maxf(_left, 0.0)


func _start(seconds: float) -> void:
	_left = maxf(seconds, 0.0)
	elapsed = 0.0


func _cancel() -> void:
	_left = -1.0
	elapsed = 0.0
	_stage = 0


func _power_on() -> void:
	_cancel()
	output = false
	match mode:
		Mode.ON_DELAY, Mode.PULSE_GENERATOR:
			_start(delay)
		Mode.OFF_DELAY, Mode.TEST:
			output = true
		Mode.PULSE_ON_POWER:
			output = true
			_start(delay)
		Mode.CYCLE_PAUSE_FIRST:
			_start(delay2)
		Mode.CYCLE_PULSE_FIRST:
			output = true
			_start(delay)
	if control:
		_press()


func _power_off() -> void:
	if mode == Mode.OFF_DELAY and output:
		_start(delay)
		return
	_cancel()
	output = false


func _press() -> void:
	match mode:
		Mode.PULSE_ON_PRESS:
			if not output:
				output = true
				_start(delay)
		Mode.DELAY_AFTER_RELEASE:
			if not output:
				_cancel()
		Mode.TOGGLE:
			output = not output
		Mode.SHIFTED_PULSE:
			if _left < 0.0 and not output:
				_stage = 1
				_start(delay)
		Mode.ON_OFF_DELAY:
			# On after t1; a running off-delay is cancelled.
			if output:
				_cancel()
			else:
				_start(delay)


func _release() -> void:
	match mode:
		Mode.ON_OFF_DELAY:
			# Off after t2; a running on-delay is cancelled.
			if output:
				_start(delay2)
			else:
				_cancel()
		Mode.DELAY_AFTER_RELEASE:
			if not output:
				_start(delay)
		Mode.PULSE_AFTER_RELEASE:
			if not output:
				output = true
				_start(delay)


func _timeout() -> void:
	match mode:
		Mode.ON_DELAY, Mode.DELAY_AFTER_RELEASE:
			output = true
		Mode.OFF_DELAY, Mode.PULSE_ON_POWER, Mode.PULSE_ON_PRESS, Mode.PULSE_AFTER_RELEASE:
			output = false
		Mode.PULSE_GENERATOR:
			output = not output
			_start(GENERATOR_PULSE if output else delay)
		Mode.CYCLE_PAUSE_FIRST, Mode.CYCLE_PULSE_FIRST:
			# t1 on, t2 off.
			output = not output
			_start(delay if output else delay2)
		Mode.ON_OFF_DELAY:
			output = control
		Mode.SHIFTED_PULSE:
			if _stage == 1:
				output = true
				_stage = 2
				_start(delay)
			else:
				output = false
				_stage = 0


func _sync_targets() -> void:
	armature.target = energized
	if output_armature != null:
		output_armature.target = output


func _apply_fault() -> void:
	armature.stuck = fault == Fault.STUCK
	output_armature.stuck = fault == Fault.STUCK
