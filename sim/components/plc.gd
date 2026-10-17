class_name Plc
extends Load
## Small PLC (logic module, designation "A1"), modelled on the small Siemens
## logic modules with relay outputs for 230 V: supply L1-N, inputs I1-I8,
## relay outputs Q1-Q4 (a free contact each, terminals Q1.1-Q1.2 ...).
##
## Expansion modules ([member modules]) clip on to the right of it, as on the
## real ones: each has its own supply (2L1-2N for the first, 3L1-3N ...), its
## inputs and relay outputs numbered on from the module before it (I9...,
## Q5...), up to [constant MAX_INPUTS] inputs and [constant MAX_OUTPUTS]
## outputs in all. A module works while it has voltage on its own L1-N and
## the PLC works; an input of it is on with voltage against its own N.
##
## Analog: the 12/24 V and 24 V versions read the inputs I7, I8, I1, I2 also
## as analog inputs AI1-AI4 (0-10 V against N, 0-1000 in the program);
## analog modules (24 V DC on L+-M) add two analog inputs U1 U2 (AI numbered
## on) or two analog outputs AQ (0-10 V against their M), up to
## [constant MAX_ANALOG] of each.
##
## It works while it has voltage on L1-N. An input is on (1) when it has
## voltage against N, like the control input of a time relay. The PLC then
## runs its [member program] (function block diagram or ladder diagram, see
## [PlcProgram]) whenever an input changes or a timer of the program ends,
## until the program settles; each output Q closes its relay contact through
## an [Armature] with the switching times of a small relay. Losing power
## resets the program (outputs, flags, timers and counters to 0).

## Expansion modules: 4 inputs and 4 relay outputs, 8 inputs and 8 relay
## outputs, 2 analog inputs, 2 analog outputs.
enum Module { DI4_DQ4, DI8_DQ8, AI2, AQ2 }
## What a terminal is: the supply of the PLC or of a module, a digital input,
## one of the two terminals of a relay output, an analog input or output.
enum Role { SUPPLY, DI, DQ, AI, AQ }

const MODULE_NAMES: PackedStringArray = ["4di4dq", "8di8dq", "2ai", "2aq"]
const MODULE_INPUTS: PackedInt32Array = [4, 8, 0, 0]
const MODULE_OUTPUTS: PackedInt32Array = [4, 8, 0, 0]
const MODULE_ANALOG_INPUTS: PackedInt32Array = [0, 0, 2, 0]
const MODULE_ANALOG_OUTPUTS: PackedInt32Array = [0, 0, 0, 2]
## Supply of the analog modules (24 V DC on L+ and M).
const ANALOG_MODULE_RATING: String = "1224rc"
## Versions whose inputs I7, I8, I1, I2 are also analog inputs AI1-AI4.
const ANALOG_VERSIONS: PackedStringArray = ["24rc", "1224rc"]
const BASE_ANALOG_INPUTS: PackedInt32Array = [6, 7, 0, 1]
## Most analog inputs and outputs.
const MAX_ANALOG: int = 8
## Volts of the analog range (0-10 V = 0-1000).
const ANALOG_VOLTS: float = 10.0
## Inputs and outputs of the PLC itself.
const BASE_INPUTS: int = 8
const BASE_OUTPUTS: int = 4
## Most inputs and outputs with all its expansion modules.
const MAX_INPUTS: int = 24
const MAX_OUTPUTS: int = 20
## Switching times of the output relays (seconds).
const RELAY_PICK_UP: float = 0.010
const RELAY_DROP_OUT: float = 0.008
## Seconds until a program that kept changing is scanned again.
const CYCLE_TIME: float = 0.01
## Current drawn while working (amperes at 230 V), by the PLC and by each
## expansion module.
const DRAW: float = 0.03
const MODULE_DRAW: float = 0.02

var program: PlcProgram
var runtime: PlcRuntime
## Expansion modules, from the PLC to the right.
var modules: Array[Module] = []
## One per output Q1, Q2 ...
var output_armatures: Array[Armature] = []
## Bit k: input I(k+1) is on (simulation state).
var inputs: int = 0
## Bit m: expansion module m has voltage on its supply (simulation state).
var module_power: int = 0
## Volts on each analog input AI1, AI2 ... (simulation state).
var analog_in: PackedFloat32Array = PackedFloat32Array()
## The last scans did not settle: the program is scanned again after
## [constant CYCLE_TIME].
var pending: bool = false
var _cycle_left: float = 0.0
## Terminal index of each input, of the first terminal of each output, of
## the L1 of each module; the module of each input and output (-1: the PLC).
var _input_terms: PackedInt32Array = PackedInt32Array()
var _output_terms: PackedInt32Array = PackedInt32Array()
var _module_terms: PackedInt32Array = PackedInt32Array()
var _input_module: PackedInt32Array = PackedInt32Array()
var _output_module: PackedInt32Array = PackedInt32Array()
## Analog inputs of the modules (terminal, module), analog outputs alike.
var _module_ai_terms: PackedInt32Array = PackedInt32Array()
var _module_ai_module: PackedInt32Array = PackedInt32Array()
var _aq_terms: PackedInt32Array = PackedInt32Array()
var _aq_module: PackedInt32Array = PackedInt32Array()
var _names: PackedStringArray = PackedStringArray()
var _roles: PackedInt32Array = PackedInt32Array()
var _role_module: PackedInt32Array = PackedInt32Array()


func _init(p_designation: String, p_program: PlcProgram = null, p_modules: Array[Module] = []) -> void:
	super(p_designation, "L1", "N")
	program = p_program if p_program != null else PlcProgram.new()
	runtime = PlcRuntime.new(program)
	modules = p_modules.duplicate()
	_lay_out()
	for k: int in output_count():
		output_armatures.append(Armature.new(RELAY_PICK_UP, RELAY_DROP_OUT))


## True when [param list] of modules stays within [constant MAX_INPUTS],
## [constant MAX_OUTPUTS] and [constant MAX_ANALOG] analog inputs and outputs
## (the PLC's own analog inputs counted for [param version]).
static func modules_fit(list: Array[Module], version: String = "") -> bool:
	var i: int = BASE_INPUTS
	var q: int = BASE_OUTPUTS
	var ai: int = BASE_ANALOG_INPUTS.size() if ANALOG_VERSIONS.has(version) else 0
	var aq: int = 0
	for m: Module in list:
		i += MODULE_INPUTS[m]
		q += MODULE_OUTPUTS[m]
		ai += MODULE_ANALOG_INPUTS[m]
		aq += MODULE_ANALOG_OUTPUTS[m]
	return i <= MAX_INPUTS and q <= MAX_OUTPUTS and ai <= MAX_ANALOG and aq <= MAX_ANALOG


## True for the analog modules.
static func is_analog(module: Module) -> bool:
	return MODULE_ANALOG_INPUTS[module] + MODULE_ANALOG_OUTPUTS[module] > 0


func default_terminal_names() -> PackedStringArray:
	return _names.duplicate()


## Terminal names of a PLC with [param list] of modules: L1, N, I1-I8, the
## two terminals of each output Q1.1, Q1.2 ... Q4.2, then each module: its
## supply (2L1, 2N for the first), its inputs and outputs numbered on.
static func standard_terminal_names(list: Array[Module] = []) -> PackedStringArray:
	return Plc.new("A", null, list).default_terminal_names()


func input_count() -> int:
	return _input_terms.size()


func output_count() -> int:
	return _output_terms.size()


## Index of the terminal of input I(k + 1).
func input_terminal(k: int) -> int:
	return _input_terms[k]


## Index of the first terminal of output Q(k + 1) (the second follows it).
func output_terminal(k: int) -> int:
	return _output_terms[k]


## Index of the L1 terminal of expansion module [param m] (its N follows it).
func module_terminal(m: int) -> int:
	return _module_terms[m]


## Expansion module of input I(k + 1); -1 for an input of the PLC itself.
func input_module(k: int) -> int:
	return _input_module[k]


## Expansion module of output Q(k + 1); -1 for an output of the PLC itself.
func output_module(k: int) -> int:
	return _output_module[k]


## What terminal [param index] is ([enum Role]) and its module (-1: the PLC).
func terminal_role(index: int) -> Role:
	return _roles[index] as Role


func terminal_module(index: int) -> int:
	return _role_module[index]


## Analog inputs AI1, AI2 ...: the PLC's own (of an analog version), then the
## modules', at most [constant MAX_ANALOG].
func analog_input_count() -> int:
	return mini(_base_analog() + _module_ai_terms.size(), MAX_ANALOG)


func analog_output_count() -> int:
	return mini(_aq_terms.size(), MAX_ANALOG)


## Terminal of analog input AI(k + 1) (an input I of the PLC for its own).
func analog_input_terminal(k: int) -> int:
	var base: int = _base_analog()
	return input_terminal(BASE_ANALOG_INPUTS[k]) if k < base else _module_ai_terms[k - base]


## Module of analog input AI(k + 1); -1 for the PLC's own.
func analog_input_module(k: int) -> int:
	var base: int = _base_analog()
	return -1 if k < base else _module_ai_module[k - base]


func analog_output_terminal(k: int) -> int:
	return _aq_terms[k]


func analog_output_module(k: int) -> int:
	return _aq_module[k]


## Version (rating) a module's supply is checked against.
func module_rating(m: int) -> String:
	return ANALOG_MODULE_RATING if is_analog(modules[m]) else rating


## Volts the program puts on analog output AQ(k + 1) (0 while it or its
## module does not work).
func analog_output_volts(k: int) -> float:
	if not energized or not module_on(analog_output_module(k)):
		return 0.0
	return clampf(runtime.analog_outputs[k], 0.0, PlcBlock.ANALOG_MAX) * ANALOG_VOLTS / PlcBlock.ANALOG_MAX


func _base_analog() -> int:
	return BASE_ANALOG_INPUTS.size() if ANALOG_VERSIONS.has(rating) else 0


## Index of the first terminal of expansion module [param m] (-1: the PLC
## itself, 0) and the index after its last.
func module_terminals(m: int) -> Vector2i:
	var first: int = 0 if m < 0 else _module_terms[m]
	var end: int = _names.size() if m + 1 >= _module_terms.size() else _module_terms[m + 1]
	return Vector2i(first, end)


func switch_paths() -> Array[Vector2i]:
	var paths: Array[Vector2i] = []
	for k: int in output_count():
		paths.append(Vector2i(output_terminal(k), output_terminal(k) + 1))
	return paths


func is_path_closed(path: int) -> bool:
	return output_armatures[path].no_closed


func rated_draw() -> float:
	return DRAW


## True when input I(k + 1) is on.
func input_on(k: int) -> bool:
	return (inputs >> k) & 1 == 1


## True when expansion module [param m] works: it has voltage on its supply
## and the PLC works.
func module_on(m: int) -> bool:
	return energized and (module_power >> m) & 1 == 1


## True when the program switches output Q(k + 1) on (and its module works).
func output_on(k: int) -> bool:
	if not energized or runtime.outputs[k] == 0:
		return false
	return output_module(k) < 0 or module_on(output_module(k))


## Bits of every expansion module having voltage on its supply.
func all_modules() -> int:
	return (1 << modules.size()) - 1


## Takes the supply, the inputs, the supply of the expansion modules
## ([member module_power]) and the volts on the analog inputs found by the
## simulator; the program runs when the PLC is switched on and whenever an
## input, a module or an analog input changed.
func update(powered: bool, input_bits: int, module_bits: int, analog_volts: PackedFloat32Array = PackedFloat32Array()) -> void:
	var changed: bool = input_bits != inputs or module_bits != module_power or analog_volts != analog_in
	inputs = input_bits
	module_power = module_bits
	analog_in = analog_volts
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
	var sig: PackedByteArray = PackedByteArray([1 if energized else 0])
	sig.append_array(var_to_bytes([inputs, module_power, analog_in]))
	sig.append_array(var_to_bytes(runtime.snapshot()))
	return sig


func _run() -> void:
	for k: int in input_count():
		var m: int = input_module(k)
		runtime.inputs[k] = 1 if input_on(k) and (m < 0 or module_on(m)) else 0
	for k: int in analog_input_count():
		var m: int = analog_input_module(k)
		var volts: float = analog_in[k] if k < analog_in.size() and (m < 0 or module_on(m)) else 0.0
		runtime.analog_inputs[k] = clampf(volts, 0.0, ANALOG_VOLTS) * PlcBlock.ANALOG_MAX / ANALOG_VOLTS
	pending = not runtime.scan_until_stable()
	_cycle_left = CYCLE_TIME


func _sync_targets() -> void:
	for k: int in output_count():
		output_armatures[k].target = output_on(k)


## Terminal names and where the inputs, outputs and modules are among them.
## A digital module's supply is nL1-nN, an analog one's nL+-nM (n = 2 for
## the first module); analog inputs of a module are nU1, nU2 (their AI
## number follows the PLC's version), analog outputs AQ1, AQ2 ...
func _lay_out() -> void:
	_add("L1", Role.SUPPLY, -1)
	_add("N", Role.SUPPLY, -1)
	for k: int in BASE_INPUTS:
		_add_input(-1)
	for k: int in BASE_OUTPUTS:
		_add_output(-1)
	for m: int in modules.size():
		var module: Module = modules[m]
		_module_terms.append(_names.size())
		var analog: bool = is_analog(module)
		_add("%d%s" % [m + 2, "L+" if analog else "L1"], Role.SUPPLY, m)
		_add("%d%s" % [m + 2, "M" if analog else "N"], Role.SUPPLY, m)
		for k: int in MODULE_INPUTS[module]:
			_add_input(m)
		for k: int in MODULE_OUTPUTS[module]:
			_add_output(m)
		for k: int in MODULE_ANALOG_INPUTS[module]:
			_module_ai_terms.append(_names.size())
			_module_ai_module.append(m)
			_add("%dU%d" % [m + 2, k + 1], Role.AI, m)
		for k: int in MODULE_ANALOG_OUTPUTS[module]:
			_aq_terms.append(_names.size())
			_aq_module.append(m)
			_add("AQ%d" % _aq_terms.size(), Role.AQ, m)


func _add(name: String, role: Role, m: int) -> void:
	_names.append(name)
	_roles.append(role)
	_role_module.append(m)


func _add_input(m: int) -> void:
	_input_terms.append(_names.size())
	_input_module.append(m)
	_add("I%d" % _input_terms.size(), Role.DI, m)


func _add_output(m: int) -> void:
	_output_terms.append(_names.size())
	_output_module.append(m)
	_add("Q%d.1" % _output_terms.size(), Role.DQ, m)
	_add("Q%d.2" % _output_terms.size(), Role.DQ, m)
