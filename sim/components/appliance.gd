class_name Appliance
extends Load
## Appliance of a house installation (spotřebič, designation "EB1", a
## fridge "EC1"): a water heater, oven, hob, microwave, washing machine,
## dishwasher, heater, fridge or kettle of a rated power, on 230 V (L, N) or
## on 400 V between two phases (L1, L2), its metal frame on PE (ignored by the
## solver but for a fault). An insulation fault ([member frame_fault],
## simulation state) joins its phase to the frame: with the frame on PE that
## is a short to PE, without it the frame is live.

enum Kind { WATER_HEATER, OVEN, HOB, MICROWAVE, WASHING_MACHINE, DISHWASHER, HEATER, FRIDGE, KETTLE }

## Kinds as saved, in [enum Kind] order.
const KIND_NAMES: PackedStringArray = ["water_heater", "oven", "hob", "microwave", "washing_machine", "dishwasher", "heater", "fridge", "kettle"]
## Rated power of each kind when none is set (W), in [enum Kind] order.
const DEFAULT_POWER: PackedFloat32Array = [2000.0, 3500.0, 6400.0, 1200.0, 2200.0, 2000.0, 2000.0, 150.0, 2000.0]
## Kinds connected between two phases (400 V) when none is set.
const DEFAULT_400: Array[Kind] = [Kind.HOB]
## Least and most rated power (W).
const MIN_POWER: float = 1.0
const MAX_POWER: float = 30000.0
## Mounting height of the fixed connection box over the floor (m) when none
## is set.
const STANDARD_HEIGHT: float = 0.6

var kind: Kind = Kind.WATER_HEATER
## Rated power (W; design data).
var power: float = 2000.0
## On 400 V between two phases rather than 230 V (design data).
var two_phases: bool = false:
	set(value):
		two_phases = value
		_terminals = PackedStringArray(["L1", "L2", "PE"] if value else ["L", "N", "PE"])
		rating = "400v" if value else "230v"
		_update_id()
## Mounting height of its connection over the floor in metres (design data).
var height: float = STANDARD_HEIGHT
## Insulation fault: its phase on its metal frame (simulation state).
var frame_fault: bool = false


func _init(p_designation: String, p_kind: Kind = Kind.WATER_HEATER) -> void:
	super(p_designation, "L", "N")
	kind = p_kind
	power = DEFAULT_POWER[p_kind]
	two_phases = DEFAULT_400.has(p_kind)


## Current it draws while it works, amperes: at 230 V, or between two
## phases (the solver takes √3 times this there).
func rated_draw() -> float:
	return power / (400.0 * sqrt(3.0)) if two_phases else power / 230.0


## The insulation fault's path, from its first conductor to the frame.
func switch_paths() -> Array[Vector2i]:
	return [Vector2i(0, 2)]


func is_path_closed(_path: int) -> bool:
	return frame_fault


## Designation letters of [param p_kind]: EC for cooling, EB for the others
## (ČSN EN 81346-2).
static func letters(p_kind: Kind) -> String:
	return "EC" if p_kind == Kind.FRIDGE else "EB"
