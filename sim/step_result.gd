class_name StepResult
extends RefCounted
## Outcome of one [method Simulator.step].

## True when the circuit reached a state where no coil wants to change.
var stable: bool = true
## Evaluation passes used while settling.
var iterations: int = 0
## Coils that kept switching in a cycle (e.g. a relay cutting off its own coil).
var oscillating_tags: PackedStringArray = PackedStringArray()
## True when closed switching elements connect L directly to N.
## While it lasts all loads are without power (the protective device trips).
var short_circuit: bool = false
## The line that closes L-N: the L rail, the closed elements in order, the N rail,
## e.g. ["L", "S1:13-14", "K1:13-14", "N"].
var short_circuit_path: PackedStringArray = PackedStringArray()


func is_oscillating() -> bool:
	return not oscillating_tags.is_empty()
