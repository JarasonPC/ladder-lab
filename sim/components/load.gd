class_name Load
extends CircuitComponent
## Two-terminal consumer. Energized when one terminal is connected to L and the
## other to N through closed switching elements only.

var energized: bool = false
## Rated voltage ([VoltageRating] name; "" works on any voltage).
var rating: String = ""
## Burnt out by too high a voltage (simulation state): works no more.
var burnt: bool = false
var _terminals: PackedStringArray

## Current drawn at the nominal voltage (230 V AC between a phase and N, or
## the DC supply), amperes; more between two phases.
const RATED_DRAW: float = 0.02


func _init(p_designation: String, terminal_a: String, terminal_b: String) -> void:
	super(p_designation)
	_terminals = PackedStringArray([terminal_a, terminal_b])


func default_terminal_names() -> PackedStringArray:
	return _terminals


## Current it draws at the nominal voltage while energized, amperes.
func rated_draw() -> float:
	return RATED_DRAW
