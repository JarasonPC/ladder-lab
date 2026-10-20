class_name CompactPlc
extends Plc
## Compact PLC (CPU, designation "A1"), modelled on the small Siemens
## controllers in their 24 V DC version with transistor outputs (never with
## maker names or type designations on the drawing): supply L+ M (24 V DC),
## inputs I0.0 ... against their common 1M (on from 15 V), two analog inputs
## AI0 AI1 (0-10 V against 2M, 0-27648 in the program), transistor outputs
## Q0.0 ... switching the output supply 3L+ (3M its 0 V) to the output.
## Three sizes ([enum Cpu]); signal modules ([enum Plc.Module] SM_*) clip on
## to the right, as many as the CPU takes (none, 2, 8), with addresses by
## their slot: inputs and outputs from byte 8 on, four bytes a slot (I8.0,
## I12.0 ...), analog values from word 96 on, sixteen bytes a slot.
##
## The program sees the inputs, outputs and analog values in order as I1,
## Q1, AI1 ... ([PlcProgram]); [method address] writes them as the CPU's
## addresses (%I0.0, %Q0.0, %IW64, %M0.0). Its Ethernet port P1 is the
## PROFINET port X1 P1 of the real ones.

## CPU sizes: 6 inputs / 4 outputs, 8 / 6, 14 / 10, each with 2 analog inputs.
enum Cpu { DI6_DQ4, DI8_DQ6, DI14_DQ10 }

const CPU_NAMES: PackedStringArray = ["6di4dq", "8di6dq", "14di10dq"]
const CPU_INPUTS: PackedInt32Array = [6, 8, 14]
const CPU_OUTPUTS: PackedInt32Array = [4, 6, 10]
const CPU_ANALOG_INPUTS: int = 2
## Signal modules each CPU takes.
const CPU_MODULES: PackedInt32Array = [0, 2, 8]
const RATING: String = "cpu24dc"
## Program value for 10 V on an analog input or output.
const FULL_SCALE: float = 27648.0
## First byte of the signal modules' inputs and outputs, bytes a slot; first
## word of their analog values, bytes a slot; the CPU's analog inputs.
const MODULE_BYTE: int = 8
const BYTES_PER_SLOT: int = 4
const MODULE_WORD: int = 96
const WORD_BYTES_PER_SLOT: int = 16
const CPU_ANALOG_WORD: int = 64
## Switching times of the transistor outputs (seconds).
const SWITCH_TIME: float = 0.0005
## Most inputs, outputs, analog inputs and outputs (largest CPU, 8 modules).
const CPU_MAX_INPUTS: int = 78
const CPU_MAX_OUTPUTS: int = 74
const CPU_MAX_ANALOG: int = 34
## Current drawn while working (amperes at 24 V).
const CPU_DRAW: float = 0.1

var cpu: Cpu = Cpu.DI8_DQ6
## Address of each input and output terminal, by program operand.
var _addresses: Dictionary[String, String] = {}


func _init(p_designation: String, p_program: PlcProgram = null, p_modules: Array[Plc.Module] = [], p_cpu: Cpu = Cpu.DI8_DQ6) -> void:
	cpu = p_cpu
	super(p_designation, p_program, p_modules)
	rating = RATING


## True when [param list] are signal modules the CPU [param p_cpu] takes.
static func modules_fit_cpu(list: Array[Plc.Module], p_cpu: Cpu) -> bool:
	if list.size() > CPU_MODULES[p_cpu]:
		return false
	for m: Plc.Module in list:
		if not Plc.is_signal_module(m):
			return false
	return true


func duplicate_plc(p_program: PlcProgram) -> Plc:
	var copy: CompactPlc = CompactPlc.new(designation, p_program, modules, cpu)
	copy.ip_address = ip_address
	return copy


func full_scale() -> float:
	return FULL_SCALE


func rated_draw() -> float:
	return CPU_DRAW


func module_rating(_m: int) -> String:
	return RATING


## "%I0.0", "%Q8.1", "%IW64", "%QW96", "%M0.0"; timers and counters as they are.
func address(operand: String) -> String:
	if _addresses.has(operand):
		return _addresses[operand]
	var area: String = PlcProgram.area_of(operand)
	var k: int = PlcProgram.operand_index(operand)
	match area:
		"M":
			return "%%M%d.%d" % [k / 8, k % 8]
		"I", "Q", "AI", "AQ":
			# Beyond what the CPU and its modules have.
			return operand
	return operand


func _switch_times() -> Vector2:
	return Vector2(SWITCH_TIME, SWITCH_TIME)


func _base_analog() -> int:
	return 0


func _analog_limit() -> int:
	return CPU_MAX_ANALOG


## L+ M 1M I0.0 ... 2M AI0 AI1 on top, 3L+ 3M Q0.0 ... below; then each
## signal module, its own terminals marked with its slot (n. with n = 2 for
## the first): inputs with their common n.1M on top, outputs below with their
## supply n.L+ n.M, analog inputs on top with the module's supply n.L+ n.M,
## analog outputs n.AQ0 ... below.
func _lay_out() -> void:
	_add("L+", Plc.Role.SUPPLY, -1)
	_add("M", Plc.Role.SUPPLY, -1)
	var common: int = _names.size()
	_add("1M", Plc.Role.SUPPLY, -1)
	for k: int in CPU_INPUTS[cpu]:
		_cpu_input(common, k)
	_add("2M", Plc.Role.SUPPLY, -1)
	for k: int in CPU_ANALOG_INPUTS:
		_module_ai_terms.append(_names.size())
		_module_ai_module.append(-1)
		_addresses["AI%d" % _module_ai_terms.size()] = "%%IW%d" % (CPU_ANALOG_WORD + 2 * k)
		_add("AI%d" % k, Plc.Role.AI, -1)
	var supply: int = _names.size()
	_add("3L+", Plc.Role.SUPPLY, -1, 1)
	_add("3M", Plc.Role.SUPPLY, -1, 1)
	for k: int in CPU_OUTPUTS[cpu]:
		var name: String = "Q%d.%d" % [k / 8, k % 8]
		_addresses["Q%d" % (_output_terms.size() + 1)] = "%" + name
		_add_transistor_output(-1, supply, name)
	for m: int in modules.size():
		_signal_module(m)


func _cpu_input(common: int, k: int) -> void:
	var name: String = "I%d.%d" % [k / 8, k % 8]
	_addresses["I%d" % (_input_terms.size() + 1)] = "%" + name
	_add_input(-1, common, name)


func _signal_module(m: int) -> void:
	var module: Plc.Module = modules[m]
	var n: int = m + 2
	var byte: int = MODULE_BYTE + BYTES_PER_SLOT * m
	var word: int = MODULE_WORD + WORD_BYTES_PER_SLOT * m
	_module_terms.append(_names.size())
	var analog: bool = Plc.is_analog(module)
	_module_supply.append(_names.size() if analog else -1)
	if analog:
		_add("%d.L+" % n, Plc.Role.SUPPLY, m)
		_add("%d.M" % n, Plc.Role.SUPPLY, m)
	if Plc.MODULE_INPUTS[module] > 0:
		var common: int = _names.size()
		_add("%d.1M" % n, Plc.Role.SUPPLY, m)
		for k: int in Plc.MODULE_INPUTS[module]:
			var name: String = "I%d.%d" % [byte + k / 8, k % 8]
			_addresses["I%d" % (_input_terms.size() + 1)] = "%" + name
			_add_input(m, common, name)
	if Plc.MODULE_OUTPUTS[module] > 0:
		var supply: int = _names.size()
		_add("%d.L+" % n, Plc.Role.SUPPLY, m, 1)
		_add("%d.M" % n, Plc.Role.SUPPLY, m, 1)
		for k: int in Plc.MODULE_OUTPUTS[module]:
			var name: String = "Q%d.%d" % [byte + k / 8, k % 8]
			_addresses["Q%d" % (_output_terms.size() + 1)] = "%" + name
			_add_transistor_output(m, supply, name)
	for k: int in Plc.MODULE_ANALOG_INPUTS[module]:
		_module_ai_terms.append(_names.size())
		_module_ai_module.append(m)
		_addresses["AI%d" % _module_ai_terms.size()] = "%%IW%d" % (word + 2 * k)
		_add("%d.AI%d" % [n, k], Plc.Role.AI, m)
	for k: int in Plc.MODULE_ANALOG_OUTPUTS[module]:
		_aq_terms.append(_names.size())
		_aq_module.append(m)
		_addresses["AQ%d" % _aq_terms.size()] = "%%QW%d" % (word + 2 * k)
		_add("%d.AQ%d" % [n, k], Plc.Role.AQ, m)
