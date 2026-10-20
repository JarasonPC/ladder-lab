class_name Transmitter
extends AnalogSensor
## Pressure, level or flow transmitter with a 0-10 V output (designation
## "BP1", "BL1", "BF1" by ČSN EN 81346-2), three wires as the usual ones
## with an M12 plug: 1 BN (L+, 15-30 V DC), 3 BU (M), 2 WH (the output
## against M). While it has its supply it puts 0 V at [member range_min]
## and 10 V at [member range_max] on 2, in between in proportion (held
## within 0-10 V). [member value] is set by hand while simulating (it
## starts at the one saved with the schematic).

enum Quantity { PRESSURE, LEVEL, FLOW }

## As saved.
const QUANTITY_NAMES: PackedStringArray = ["pressure", "level", "flow"]
const UNITS: PackedStringArray = ["bar", "m", "m³/h"]
## Designation letters by quantity.
const LETTERS: PackedStringArray = ["BP", "BL", "BF"]
## Range and value a new transmitter of each quantity starts with.
const DEFAULT_MIN: PackedFloat32Array = [0.0, 0.0, 0.0]
const DEFAULT_MAX: PackedFloat32Array = [10.0, 5.0, 20.0]
const DEFAULT_VALUE: PackedFloat32Array = [2.0, 1.0, 5.0]
## Limits of the range and of the value.
const LOWEST: float = -1000.0
const HIGHEST: float = 10000.0
## Colour code of the cores by terminal number.
const CORE_COLOURS: Dictionary[String, String] = {"1": "BN", "2": "WH", "3": "BU"}

var quantity: Quantity = Quantity.PRESSURE
var value: float = 2.0


func _init(p_designation: String, p_quantity: Quantity = Quantity.PRESSURE) -> void:
	super(p_designation, "1", "3")
	rating = "1530dc"
	quantity = p_quantity
	range_min = DEFAULT_MIN[quantity]
	range_max = DEFAULT_MAX[quantity]
	value = DEFAULT_VALUE[quantity]


func default_terminal_names() -> PackedStringArray:
	return PackedStringArray(["1", "3", "2"])


func measured() -> float:
	return value


func set_measured(p_value: float) -> void:
	value = clampf(p_value, LOWEST, HIGHEST)


func unit() -> String:
	return UNITS[quantity]


func lowest() -> float:
	return LOWEST


func highest() -> float:
	return HIGHEST


## Name of the core colour of terminal [param terminal] (by its standard
## number).
func core_colour(terminal: int) -> String:
	var names: PackedStringArray = default_terminal_names()
	return CORE_COLOURS.get(names[terminal], "") if terminal < names.size() else ""
