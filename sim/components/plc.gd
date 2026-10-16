class_name Plc
extends Load
## Small PLC (logic module, designation "A1"), modelled on the small Siemens
## logic modules with relay outputs for 230 V: supply L1-N, inputs I1-I8,
## relay outputs Q1-Q4 (a free contact each, terminals Q1.1-Q1.2 ...).
##
## It works while it has voltage on L1-N. An input is on (1) when it has
## voltage against N, like the control input of a time relay. The PLC then
## runs its [member program] (function block diagram or ladder diagram, see
## [PlcProgram]) whenever an input changes or a timer of the program ends,
## until the program settles; each output Q closes its relay contact through
## an [Armature] with the switching times of a small relay. Losing power
## resets the program (outputs, flags, timers and counters to 0).

const INPUTS: int = 8
const OUTPUTS: int = 4
## Switching times of the output relays (seconds).
const RELAY_PICK_UP: float = 0.010
const RELAY_DROP_OUT: float = 0.008
## Seconds until a program that kept changing is scanned again.
const CYCLE_TIME: float = 0.01
## Current drawn while working (amperes at 230 V).
const DRAW: float = 0.03

var program: PlcProgram
var runtime: PlcRuntime
## One per output Q1-Q4.
var output_armatures: Array[Armature] = []
## Bit k: input I(k+1) is on (simulation state).
var inputs: int = 0
## The last scans did not settle: the program is scanned again after
## [constant CYCLE_TIME].
var pending: bool = false
var _cycle_left: float = 0.0


func _init(p_designation: String, p_program: PlcProgram = null) -> void:
	super(p_designation, "L1", "N")
	program = p_program if p_program != null else PlcProgram.new()
	runtime = PlcRuntime.new(program)
	for k: int in OUTPUTS:
		output_armatures.append(Armature.new(RELAY_PICK_UP, RELAY_DROP_OUT))


func default_terminal_names() -> PackedStringArray:
	return standard_terminal_names()


## L1, N, I1-I8, then the two terminals of each output: Q1.1, Q1.2, ...
static func standard_terminal_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray(["L1", "N"])
	for k: int in INPUTS:
		names.append("I%d" % (k + 1))
	for k: int in OUTPUTS:
		names.append("Q%d.1" % (k + 1))
		names.append("Q%d.2" % (k + 1))
	return names


## Index of the first terminal of input I(k + 1).
static func input_terminal(k: int) -> int:
	return 2 + k


## Index of the first terminal of output Q(k + 1) (the second follows it).
static func output_terminal(k: int) -> int:
	return 2 + INPUTS + 2 * k


func switch_paths() -> Array[Vector2i]:
	var paths: Array[Vector2i] = []
	for k: int in OUTPUTS:
		paths.append(Vector2i(output_terminal(k), output_terminal(k) + 1))
	return paths


func is_path_closed(path: int) -> bool:
	return output_armatures[path].no_closed


func rated_draw() -> float:
	return DRAW


## True when input I(k + 1) is on.
func input_on(k: int) -> bool:
	return (inputs >> k) & 1 == 1


## True when the program switches output Q(k + 1) on.
func output_on(k: int) -> bool:
	return energized and runtime.outputs[k] != 0


## Takes the supply and the inputs found by the simulator; the program runs
## when the PLC is switched on and whenever an input changed.
func update(powered: bool, input_bits: int) -> void:
	var changed: bool = input_bits != inputs
	inputs = input_bits
	if powered != energized:
		energized = powered
		runtime.reset()
		pending = false
		changed = true
	if changed and energized:
		_run()
	_sync_targets()


## Runs the program again (it had not settled).
func rescan() -> void:
	if energized:
		_run()
	_sync_targets()


## Instant switching: every output relay jumps to where it is heading.
func snap() -> void:
	for a: Armature in output_armatures:
		a.snap(a.target)


func move_armatures(delta: float) -> void:
	for a: Armature in output_armatures:
		a.advance(delta)


## Moves the program time on by [param delta] seconds: timers that end on
## the way make the program run at that moment (several may in one step).
func advance(delta: float) -> void:
	if not energized:
		return
	var remaining: float = delta
	var guard: int = 0
	while guard < 10000:
		var t: float = runtime.time_to_next_timer()
		if pending:
			t = minf(t, _cycle_left)
		if t > remaining:
			break
		runtime.advance(t)
		remaining -= t
		_run()
		guard += 1
	runtime.advance(remaining)
	if pending:
		_cycle_left -= remaining
	_sync_targets()


## Seconds until an output relay switches or reaches its end, a timer of the
## program ends or a program that kept changing runs again; INF when nothing
## is pending.
func time_to_next_event() -> float:
	var t: float = INF
	for a: Armature in output_armatures:
		t = minf(t, a.time_to_next_event())
	if energized:
		t = minf(t, runtime.time_to_next_timer())
		if pending:
			t = minf(t, maxf(_cycle_left, 0.0))
	return t


## Bytes of the state the program may change (outputs, flags, timers, ...),
## for telling a repeated state apart.
func state_signature() -> PackedByteArray:
	var sig: PackedByteArray = PackedByteArray([1 if energized else 0, inputs])
	sig.append_array(var_to_bytes(runtime.snapshot()))
	return sig


func _run() -> void:
	for k: int in INPUTS:
		runtime.inputs[k] = 1 if input_on(k) else 0
	pending = not runtime.scan_until_stable()
	_cycle_left = CYCLE_TIME


func _sync_targets() -> void:
	for k: int in OUTPUTS:
		output_armatures[k].target = output_on(k)
