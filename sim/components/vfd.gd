class_name Vfd
extends CircuitComponent
## Frequency inverter (designation "TA1") for a 3~ motor, modelled on the
## small Siemens drives (never with maker names or type designations on the
## drawing): supply L1 L2 L3 (3 x 400 V; PE as on the device, not simulated),
## motor output U V W at a frequency from 0 to [member max_frequency], the
## voltage in proportion (V/f). Control terminals as on the real one: digital
## inputs DI1-DI4 on with 24 V against their common DIC, its own 24 V supply
## 24V-0V for them, the 10 V reference 10V for a setpoint on the analog input
## AI1 (0-10 V against 0V), and the relay output DO2 (C-NO), closed while the
## motor runs.
##
## Inputs: DI1 run (ON/OFF1, stops along the ramp), DI2 reverse, DI3 the
## fixed frequency instead of the setpoint, DI4 coast stop (OFF2: the
## output goes off at once, the motor runs down). Run, stop and the
## direction come from the terminals or the keypad ([member control]); the
## setpoint from AI1 or the keypad ([member setpoint]). The output frequency
## follows the target along the ramps (seconds from 0 to the maximum and
## back); a change of direction goes through 0. Without all three phases on
## its supply it does nothing.

## Where run / stop come from, and the setpoint.
enum Command { TERMINALS, KEYPAD }
enum Setpoint { ANALOG, KEYPAD }

const TERMINALS: PackedStringArray = ["L1", "L2", "L3", "PE", "10V", "AI1", "0V", "DI1", "DI2", "DI3", "DI4", "DIC", "24V", "U", "V", "W", "DO2C", "DO2NO"]
const L1: int = 0
const PE: int = 3
const REF_10V: int = 4
const AI1: int = 5
const ZERO_V: int = 6
const DI1: int = 7
const DIC: int = 11
const SUPPLY_24V: int = 12
const U: int = 13
const DO2C: int = 16
## The terminals below (motor output, relay output); the others on top.
const FIRST_BOTTOM: int = U
const CONTROL_NAMES: PackedStringArray = ["terminals", "keypad"]
const SETPOINT_NAMES: PackedStringArray = ["ai1", "keypad"]
const DEFAULT_MAX_FREQUENCY: float = 50.0
const DEFAULT_RAMP: float = 10.0
const DEFAULT_FIXED: float = 25.0
## Volts on a digital input that make it 1 (against DIC).
const INPUT_THRESHOLD: float = 11.0
## Volts of the setpoint for the maximum frequency; of the reference.
const ANALOG_VOLTS: float = 10.0
## Mains frequency (the motor's rated speed is at it).
const MAINS_HZ: float = 50.0
## Longest step while the frequency ramps (seconds).
const RAMP_STEP: float = 0.05
## Efficiency and power factor on its supply side.
const EFFICIENCY: float = 0.97
const INPUT_POWER_FACTOR: float = 0.95
## Current drawn while it has its supply and the motor stands (amperes).
const IDLE_CURRENT: float = 0.05
## Most frequency and longest ramp that can be set.
const HIGHEST_FREQUENCY: float = 100.0
const LONGEST_RAMP: float = 600.0

var control: Command = Command.TERMINALS
var setpoint: Setpoint = Setpoint.ANALOG
var max_frequency: float = DEFAULT_MAX_FREQUENCY
## Seconds from 0 to [member max_frequency] and back.
var ramp_up: float = DEFAULT_RAMP
var ramp_down: float = DEFAULT_RAMP
## Frequency while DI3 is on (Hz).
var fixed_frequency: float = DEFAULT_FIXED
## Keypad setpoint (Hz); saved as the setpoint it starts with.
var keypad_frequency: float = DEFAULT_MAX_FREQUENCY

## Simulation state: its supply has all three phases; the inputs DI1-DI4
## (bit k: DI(k+1)); the volts on AI1; run and direction from the keypad;
## the output frequency now (Hz, negative in reverse) and the one it heads
## for.
var powered: bool = false
var inputs: int = 0
var analog_in: float = 0.0
var keypad_run: bool = false
var keypad_reverse: bool = false
var frequency: float = 0.0
var target: float = 0.0
## The output is switched on (running or ramping down; off after OFF2).
var output: bool = false


func default_terminal_names() -> PackedStringArray:
	return TERMINALS


## The relay output DO2: closed while the motor runs.
func switch_paths() -> Array[Vector2i]:
	return [Vector2i(DO2C, DO2C + 1)]


func is_path_closed(_path: int) -> bool:
	return output and frequency != 0.0


## Takes its supply, the inputs and AI1 found by the simulator and works out
## where the output frequency heads.
func update(p_powered: bool, input_bits: int, ai_volts: float) -> void:
	powered = p_powered
	inputs = input_bits
	analog_in = ai_volts
	var run: bool = keypad_run if control == Command.KEYPAD else _input(0)
	var reverse: bool = keypad_reverse if control == Command.KEYPAD else _input(1)
	if not powered or _input(3):
		# No supply, or coast stop: the output goes off at once.
		output = false
		frequency = 0.0
		target = 0.0
		return
	var wanted: float = 0.0
	if run:
		if _input(2):
			wanted = fixed_frequency
		elif setpoint == Setpoint.KEYPAD:
			wanted = keypad_frequency
		else:
			wanted = clampf(analog_in / ANALOG_VOLTS, 0.0, 1.0) * max_frequency
	wanted = clampf(wanted, 0.0, max_frequency)
	target = -wanted if reverse else wanted
	if run:
		output = true
	elif frequency == 0.0:
		output = false


## The output jumps to its target (instant switching).
func snap() -> void:
	frequency = target if output else 0.0
	if frequency == 0.0 and target == 0.0:
		output = output and _running_command()


## Moves the output frequency on by [param dt] seconds along the ramps.
func advance(dt: float) -> void:
	if not output:
		frequency = 0.0
		return
	var left: float = dt
	while left > 0.0 and frequency != target:
		# Towards 0 first when the direction changes.
		var goal: float = target if signf(target) == signf(frequency) or frequency == 0.0 else 0.0
		var rising: bool = absf(goal) > absf(frequency)
		var rate: float = max_frequency / maxf(ramp_up if rising else ramp_down, 0.001)
		var step: float = minf(absf(goal - frequency), rate * left)
		frequency += signf(goal - frequency) * step
		left -= step / rate
		if is_zero_approx(frequency):
			frequency = 0.0
	if frequency == 0.0 and target == 0.0 and not _running_command():
		output = false


## Seconds until it should be looked at again: while ramping, at most
## [constant RAMP_STEP]; INF when the frequency stays.
func time_to_next_event() -> float:
	if not output or frequency == target:
		return INF
	return RAMP_STEP


## The output frequency as a fraction of the mains frequency.
func frequency_factor() -> float:
	return absf(frequency) / MAINS_HZ


## Output volts between two phases (V/f: 400 V at 50 Hz).
func output_volts() -> float:
	return 400.0 * minf(frequency_factor(), 1.0) if output else 0.0


func _input(k: int) -> bool:
	return (inputs >> k) & 1 == 1


func _running_command() -> bool:
	return keypad_run if control == Command.KEYPAD else _input(0)
