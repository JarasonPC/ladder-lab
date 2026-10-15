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
## The line that closes L-N: the L supply, the closed elements in order, the N supply,
## e.g. ["L", "S1:13-14", "K1:13-14", "N"].
var short_circuit_path: PackedStringArray = PackedStringArray()

## Terminal keys at L potential: joined to an L supply by wires and closed
## switching elements (voltage reach), whether or not current flows.
var live_terminals: PackedStringArray = PackedStringArray()
## Indices into [method Circuit.get_wires] of the wires at L potential.
var live_wires: PackedInt32Array = PackedInt32Array()
## Indices into [method Circuit.get_wires] of the wires that carry current.
## During a short these are the wires carrying the fault current.
var current_wires: PackedInt32Array = PackedInt32Array()
## Ids of closed switching elements and energized loads that carry current.
var current_components: PackedStringArray = PackedStringArray()


func is_oscillating() -> bool:
	return not oscillating_tags.is_empty()
