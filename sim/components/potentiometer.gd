class_name Potentiometer
extends CircuitComponent
## Potentiometer (designation "RP1"), 10 kΩ, for a PLC's or a frequency
## inverter's analog input: terminals 1 (one end of the track), 2 (the
## wiper) and 3 (the other end), as printed on real ones. Turned clockwise
## the wiper runs from 1 to 3; it puts out its share ([member setting]) of
## the voltage between 1 and 3, e.g. 0-10 V with 1 on 0 V and 3 on a 10 V
## reference. A single-turn one sweeps its track in
## [constant SINGLE_TURN_DEGREES], a multi-turn one in its [member turns]
## full turns; a notch of the mouse wheel (or a step of a drag) turns the
## knob [constant NOTCH_DEGREES], so more turns set it finer. Mounted on a
## control station or a switchboard's door.

## Turns offered (the first for a new one).
const TURNS: PackedInt32Array = [1, 2, 5, 10]
## Travel of a single-turn potentiometer.
const SINGLE_TURN_DEGREES: float = 270.0
## A notch of the mouse wheel, a step of a drag.
const NOTCH_DEGREES: float = 2.7
## Resistance of the track (ohms).
const RESISTANCE: float = 10000.0
## Where a new one is set.
const DEFAULT_SETTING: float = 0.0

## 1, 2, 5 or 10 (design data).
var turns: int = 1:
	set(value):
		turns = value if TURNS.has(value) else TURNS[0]
## Where the wiper is, 0 (at 1) .. 1 (at 3); simulation state, starting at
## the one saved with the schematic.
var setting: float = DEFAULT_SETTING:
	set(value):
		setting = clampf(value, 0.0, 1.0)
## Volts on the wiper in the last simulation step, -1 while they are not
## known (1 or 3 without a voltage).
var volts: float = -1.0


func _init(p_designation: String, p_turns: int = 1) -> void:
	super(p_designation)
	turns = p_turns


func default_terminal_names() -> PackedStringArray:
	return PackedStringArray(["1", "2", "3"])


## Degrees the knob turns from one end of the track to the other.
func travel_degrees() -> float:
	return SINGLE_TURN_DEGREES if turns == 1 else 360.0 * turns


## Turns the knob [param notches] notches clockwise (negative:
## anticlockwise), stopping at the ends.
func turn(notches: int) -> void:
	setting = snappedf(setting + notches * step(), step())


## Share of the track a notch moves the wiper.
func step() -> float:
	return NOTCH_DEGREES / travel_degrees()


## Degrees the knob is turned from the start of the track.
func knob_degrees() -> float:
	return setting * travel_degrees()


## Volts on the wiper with [param volts_1] on 1 and [param volts_3] on 3.
func wiper_volts(volts_1: float, volts_3: float) -> float:
	return volts_1 + (volts_3 - volts_1) * setting
