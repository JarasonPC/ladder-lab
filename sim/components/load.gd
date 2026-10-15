class_name Load
extends CircuitComponent
## Two-terminal consumer. Energized when one terminal is connected to L and the
## other to N through closed switching elements only.

var energized: bool = false
var _terminals: PackedStringArray


func _init(p_designation: String, terminal_a: String, terminal_b: String) -> void:
	super(p_designation)
	_terminals = PackedStringArray([terminal_a, terminal_b])


func default_terminal_names() -> PackedStringArray:
	return _terminals
