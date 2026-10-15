class_name PowerRail
extends CircuitComponent
## Supply rail of the control circuit. Has a single terminal addressed by its
## designation alone ("L" or "N").

enum Conductor { L, N }

var conductor: Conductor


func _init(p_designation: String, p_conductor: Conductor) -> void:
	super(p_designation)
	conductor = p_conductor


func get_terminal_names() -> PackedStringArray:
	return PackedStringArray([designation])


func get_terminal_keys() -> PackedStringArray:
	return PackedStringArray([designation])
