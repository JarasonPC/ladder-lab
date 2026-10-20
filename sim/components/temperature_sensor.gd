class_name TemperatureSensor
extends AnalogSensor
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

var temperature: float = DEFAULT_TEMPERATURE


func _init(p_designation: String) -> void:
	super(p_designation, "L+", "M")
	rating = "24dc"
	range_min = DEFAULT_MIN
	range_max = DEFAULT_MAX


func default_terminal_names() -> PackedStringArray:
	return PackedStringArray(["L+", "M", "U"])


func measured() -> float:
	return temperature


func set_measured(value: float) -> void:
	temperature = clampf(value, LOWEST, HIGHEST)


func unit() -> String:
	return "°C"


func lowest() -> float:
	return LOWEST


func highest() -> float:
	return HIGHEST
