class_name ProximitySensor
extends Load
## Proximity sensor (designation "BG1"), a three-wire DC sensor as sold for
## PLC inputs: inductive, capacitive, optical (diffuse light sensor) or
## magnetic (cylinder sensor). Terminals as ČSN EN 60947-5-2 marks them,
## with the colours of the cable's cores (the pins of an M12 plug alike):
## 1 BN (L+), 3 BU (M), 4 BK (switching output) and, for the four-wire
## antivalent version, 2 WH (the opposite output).
##
## It works while it has 10-30 V DC on 1-3. A PNP output switches L+ (its
## terminal 1) to the output, an NPN output switches M (its terminal 3) to
## it. The output follows [member detecting] (an object in front of it,
## simulation state, set by a click or a mechanical link): an NO output is
## on while it detects, an NC output while it does not; antivalent: 4 as NO
## and 2 as NC. The outputs switch after [constant SWITCH_TIME], as a
## solid-state output does.

enum Sensing { INDUCTIVE, CAPACITIVE, OPTICAL, MAGNETIC }
enum Output { PNP, NPN }
enum Function { NO, NC, ANTIVALENT }

## As saved.
const SENSING_NAMES: PackedStringArray = ["inductive", "capacitive", "optical", "magnetic"]
const OUTPUT_NAMES: PackedStringArray = ["pnp", "npn"]
const FUNCTION_NAMES: PackedStringArray = ["no", "nc", "antivalent"]
## How the drawing and the datasheet write the output and its function.
const OUTPUT_TEXTS: PackedStringArray = ["PNP", "NPN"]
const FUNCTION_TEXTS: PackedStringArray = ["NO", "NC", "NO + NC"]
## Colour code of the cores (ČSN EN 60947-5-2, IEC 60757) by terminal number.
const CORE_COLOURS: Dictionary[String, String] = {"1": "BN", "2": "WH", "3": "BU", "4": "BK"}
## Seconds an output takes to switch (solid state).
const SWITCH_TIME: float = 0.0005
## Current drawn while working (amperes), without the load on its output.
const DRAW: float = 0.01
## Typical switching distance (mm) by kind, for the datasheet (an M18
## sensor; the optical one up to its reach).
const DISTANCES: PackedFloat32Array = [8.0, 8.0, 400.0, 60.0]

var sensing: Sensing = Sensing.INDUCTIVE
var output: Output = Output.PNP
var function: Function = Function.NO:
	set(value):
		function = value
		_make_armatures()
## Something is in front of it (simulation state).
var detecting: bool = false
## One per output: 4 (BK), then 2 (WH) for the antivalent version.
var output_armatures: Array[Armature] = []


func _init(p_designation: String, p_function: Function = Function.NO) -> void:
	super(p_designation, "1", "3")
	rating = "1030dc"
	function = p_function


func default_terminal_names() -> PackedStringArray:
	if function == Function.ANTIVALENT:
		return PackedStringArray(["1", "3", "4", "2"])
	return PackedStringArray(["1", "3", "4"])


func rated_draw() -> float:
	return DRAW


## Number of switching outputs (4, and 2 for the antivalent version).
func output_count() -> int:
	return 2 if function == Function.ANTIVALENT else 1


## Output [param k] from L+ (PNP) or M (NPN) to its terminal.
func switch_paths() -> Array[Vector2i]:
	var paths: Array[Vector2i] = []
	var from: int = 0 if output == Output.PNP else 1
	for k: int in output_count():
		paths.append(Vector2i(from, 2 + k))
	return paths


func is_path_closed(path: int) -> bool:
	return path < output_armatures.size() and output_armatures[path].no_closed


## Whether output [param k] wants to be on now: working, and what is in
## front of it as its function says.
func output_wanted(k: int) -> bool:
	if not energized or burnt:
		return false
	var opener: bool = function == Function.NC or (function == Function.ANTIVALENT and k == 1)
	return detecting != opener


## Whether output [param k] is switched on.
func output_on(k: int) -> bool:
	return is_path_closed(k)


## Sets the outputs heading where they want to be; true if any changed.
func aim_outputs() -> bool:
	var changed: bool = false
	for k: int in output_armatures.size():
		var want: bool = output_wanted(k)
		if output_armatures[k].target != want:
			output_armatures[k].target = want
			changed = true
	return changed


## Instant switching: the outputs jump to where they head.
func snap() -> void:
	for a: Armature in output_armatures:
		a.snap(a.target)


func move_armatures(delta: float) -> void:
	for a: Armature in output_armatures:
		a.advance(delta)


func time_to_next_event() -> float:
	var best: float = INF
	for a: Armature in output_armatures:
		best = minf(best, a.time_to_next_event())
	return best


## Name of the core colour of terminal [param terminal] (by its standard
## number), "" for a terminal renamed by hand.
func core_colour(terminal: int) -> String:
	var names: PackedStringArray = default_terminal_names()
	return CORE_COLOURS.get(names[terminal], "") if terminal < names.size() else ""


func _make_armatures() -> void:
	output_armatures.clear()
	for k: int in output_count():
		output_armatures.append(Armature.new(SWITCH_TIME, SWITCH_TIME))
