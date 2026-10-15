class_name PowerSupply
extends CircuitComponent
## Supply point of the control circuit: one for L, another for N. Has a single
## terminal addressed by its designation alone (e.g. "L" or "N"). All supply
## points belong to the same source.

enum Conductor { L, N }

var conductor: Conductor


func _init(p_designation: String, p_conductor: Conductor) -> void:
	super(p_designation)
	conductor = p_conductor


func get_terminal_names() -> PackedStringArray:
	return PackedStringArray([designation])


func get_terminal_keys() -> PackedStringArray:
	return PackedStringArray([designation])
