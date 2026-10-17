class_name StepResult
extends RefCounted
## Outcome of one [method Simulator.step].

## True when the circuit reached a state where no coil wants to change.
var stable: bool = true
## Evaluation passes used while settling.
var iterations: int = 0
## Coils that kept switching in a cycle (e.g. a relay cutting off its own coil).
## In realistic mode: coils that are chattering.
var oscillating_tags: PackedStringArray = PackedStringArray()
## Realistic mode: approximate switching frequency of each chattering coil.
var chatter_hz: Dictionary[String, float] = {}
## Realistic mode: what happened during the step, oldest first. Each entry has
## "time" (seconds), "text" (English, with %s placeholders) and "args".
var events: Array[Dictionary] = []
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
## Reach codes: what a terminal or wire is joined to.
const REACH_NONE: int = 0
const REACH_L1: int = 1
const REACH_L2: int = 2
const REACH_L3: int = 3
const REACH_N: int = 4
## Several supplies (a short circuit).
const REACH_SEVERAL: int = 5
## Poles of the DC source.
const REACH_DC_PLUS: int = 6
const REACH_DC_MINUS: int = 7
## Reached by PE only (N potential, drawn in the protective conductor colour).
const REACH_PE: int = 8

## Reach code of every terminal reached by a supply (see REACH_*).
var terminal_reach: Dictionary[String, int] = {}
## Reach code per wire, in the order of [method Circuit.get_wires].
var wire_reach: PackedByteArray = PackedByteArray()
## Terminal keys joined to an N or DC - supply (and not to L): return conductor reach.
var neutral_terminals: PackedStringArray = PackedStringArray()
## Indices into [method Circuit.get_wires] of the wires joined to N or DC - (and not to L).
var neutral_wires: PackedInt32Array = PackedInt32Array()
## Indices into [method Circuit.get_wires] of the wires that carry current.
## During a short these are the wires carrying the fault current.
var current_wires: PackedInt32Array = PackedInt32Array()
## Switching path indices (internal to the simulator) that carry current.
var current_switch_paths: PackedInt32Array = PackedInt32Array()
## Ids of closed switching elements and energized loads that carry current.
var current_components: PackedStringArray = PackedStringArray()
## Current in each wire (amperes, RMS for AC), in the order of
## [method Circuit.get_wires]; 0 where nothing flows and during a short.
var wire_currents: PackedFloat32Array = PackedFloat32Array()
## Current into a part at each of its terminals (amperes) where any flows,
## by terminal key, e.g. {"M1:U1": 8.0, "FU1:1": 8.0}.
var terminal_currents: Dictionary[String, float] = {}


## Reach code for a mask of supply bits (see [PowerSupply]).
static func reach_code(mask: int) -> int:
	match mask:
		0:
			return REACH_NONE
		PowerSupply.BIT_L1:
			return REACH_L1
		PowerSupply.BIT_L2:
			return REACH_L2
		PowerSupply.BIT_L3:
			return REACH_L3
		PowerSupply.BIT_N:
			return REACH_N
		PowerSupply.BIT_DC_MINUS:
			return REACH_DC_MINUS
		PowerSupply.BIT_VFD_U:
			return REACH_L1
		PowerSupply.BIT_VFD_V:
			return REACH_L2
		PowerSupply.BIT_VFD_W:
			return REACH_L3
	if (mask & (mask - 1)) == 0 and (mask & PowerSupply.DC_PLUS_BITS) != 0:
		return REACH_DC_PLUS
	return REACH_SEVERAL


## True for the return conductors N and -: drawn like N, never "live".
static func is_return(code: int) -> bool:
	return code == REACH_N or code == REACH_DC_MINUS or code == REACH_PE


func is_oscillating() -> bool:
	return not oscillating_tags.is_empty()
