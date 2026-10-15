class_name PowerSupply
extends CircuitComponent
## Supply point: one per conductor (L or L1, L2, L3, N, +, -). Has a single
## terminal addressed by its designation alone (e.g. "L", "L1", "N", "+").
## L, L1-L3 and N belong to the same three-phase source (L is the same phase as
## L1); + and - are the poles of a separate DC source (e.g. a rectifier for
## DC braking of motors).

enum Conductor { L, N, L2, L3, DC_PLUS, DC_MINUS }

## Source bits used by the simulator.
const BIT_L1: int = 1
const BIT_L2: int = 2
const BIT_L3: int = 4
const BIT_N: int = 8
const BIT_DC_PLUS: int = 16
const BIT_DC_MINUS: int = 32
## Bits of the AC source and of the DC source: a load works between two
## conductors of the same source only.
const AC_BITS: int = BIT_L1 | BIT_L2 | BIT_L3 | BIT_N
const DC_BITS: int = BIT_DC_PLUS | BIT_DC_MINUS

var conductor: Conductor


func _init(p_designation: String, p_conductor: Conductor) -> void:
	super(p_designation)
	conductor = p_conductor


func source_bit() -> int:
	match conductor:
		Conductor.N:
			return BIT_N
		Conductor.L2:
			return BIT_L2
		Conductor.L3:
			return BIT_L3
		Conductor.DC_PLUS:
			return BIT_DC_PLUS
		Conductor.DC_MINUS:
			return BIT_DC_MINUS
	return BIT_L1


func is_dc() -> bool:
	return conductor == Conductor.DC_PLUS or conductor == Conductor.DC_MINUS


## Short name of the conductor: "L", "L2", "L3", "N", "+" or "-" ("L1" when
## the designation says so).
func conductor_name() -> String:
	match conductor:
		Conductor.N:
			return "N"
		Conductor.L2:
			return "L2"
		Conductor.L3:
			return "L3"
		Conductor.DC_PLUS:
			return "+"
		Conductor.DC_MINUS:
			return "-"
	return "L1" if designation.begins_with("L1") else "L"


func get_terminal_names() -> PackedStringArray:
	return PackedStringArray([designation])


func get_terminal_keys() -> PackedStringArray:
	return PackedStringArray([designation])
