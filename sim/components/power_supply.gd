class_name PowerSupply
extends CircuitComponent
## Supply point: one per conductor (L or L1, L2, L3, N). Has a single terminal
## addressed by its designation alone (e.g. "L", "L1", "N"). All supply
## points belong to the same three-phase source; L is the same phase as L1.

enum Conductor { L, N, L2, L3 }

## Source bits used by the simulator.
const BIT_L1: int = 1
const BIT_L2: int = 2
const BIT_L3: int = 4
const BIT_N: int = 8

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
	return BIT_L1


## Short name of the conductor: "L", "L2", "L3" or "N" ("L1" when the
## designation says so).
func conductor_name() -> String:
	match conductor:
		Conductor.N:
			return "N"
		Conductor.L2:
			return "L2"
		Conductor.L3:
			return "L3"
	return "L1" if designation.begins_with("L1") else "L"


func get_terminal_names() -> PackedStringArray:
	return PackedStringArray([designation])


func get_terminal_keys() -> PackedStringArray:
	return PackedStringArray([designation])
