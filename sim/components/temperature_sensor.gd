class_name TemperatureSensor
extends Load
## Temperature transmitter (designation "BT1"), three wires as the usual
## ones with a 0-10 V output: supply L+ and M (24 V DC), output U against M.
## While it has its supply it puts 0 V at [member range_min] and 10 V at
## [member range_max] on U, in between in proportion (held within 0-10 V).
## [member temperature] is set by hand while simulating (it starts at the
## one saved with the schematic).

const DEFAULT_MIN: float = 0.0
const DEFAULT_MAX: float = 100.0
const DEFAULT_TEMPERATURE: float = 20.0
## Limits of the measuring range and of the temperature (°C).
const LOWEST: float = -200.0
const HIGHEST: float = 1000.0
## Volts at the top of the range.
const FULL_SCALE: float = 10.0
## Current drawn while working (amperes).
const DRAW: float = 0.015

var range_min: float = DEFAULT_MIN
var range_max: float = DEFAULT_MAX
var temperature: float = DEFAULT_TEMPERATURE


func _init(p_designation: String) -> void:
	super(p_designation, "L+", "M")
	rating = "24dc"


func default_terminal_names() -> PackedStringArray:
	return PackedStringArray(["L+", "M", "U"])


func rated_draw() -> float:
	return DRAW


## Volts on its output U against M (0 without its supply; [param powered]:
## whether it has it, else as [member energized]).
func output_volts(powered: Variant = null) -> float:
	var on: bool = energized if powered == null else bool(powered)
	if not on or range_max <= range_min:
		return 0.0
	return clampf((temperature - range_min) / (range_max - range_min), 0.0, 1.0) * FULL_SCALE
