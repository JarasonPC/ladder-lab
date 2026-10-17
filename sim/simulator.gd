class_name Simulator
extends RefCounted
## Solves a [Circuit]: which loads have power and which contacts are operated.
## Each supply is a phase (L or L1, L2, L3), N, or a pole of the DC source (+,
## -). Wires and closed switching paths join nets into groups; a group reached
## by two different supplies is a short circuit. A two-terminal load has power
## when its terminals are reached by two different supplies of the same source
## (phase and N, two phases, or + and -). A [ThreePhaseMotor] runs when its
## windings get all three phases and is braked when DC flows through them;
## switched off, its shaft runs down over time. A [Rectifier] whose input has
## voltage makes its outputs + and - poles of the DC source.
##
## [enum Mode] IDEAL: relays switch instantly. Each [method step] advances the
## timers, then settles: the coils that should change are found and the first
## one (in the order components were added) is switched, which may move its
## contacts, until nothing wants to change. A circuit state seen twice while
## settling is an oscillation (e.g. a relay whose own NC contact feeds its
## coil); it is reported in [StepResult] instead of looping, with
## [member max_iterations] as a hard cap.
##
## [enum Mode] REALISTIC: coils get power at once but their [Armature] needs the
## pick-up or drop-out time to move, so NC contacts break before NO contacts
## make and races are decided by the relays' times. A step jumps from event to
## event (a contact switching, an armature reaching an end, a timer expiring)
## and re-traces power after each one. A coil switching on and off fast is
## reported as chattering; [member max_events] caps the work per step.
##
## Protection: when a short circuit's fault current flows through a fuse or
## circuit breaker, it trips and the circuit is traced again. A short that no
## protective device interrupts makes the supply drop out while it lasts and
## is reported in [member StepResult.short_circuit].
##
## Currents: every load draws a current (coils and lamps a little, three-phase
## motors what their [MotorModel] gives for their supply and speed), and
## [CurrentFlow] spreads it over the wires and closed switching paths
## ([member StepResult.wire_currents], [member StepResult.terminal_currents]).
## Fuses, breakers and overload relays heat up with the current through them
## and trip after the time of their characteristic; the magnetic release of a
## breaker trips at once. In realistic timing motors run up over time (the
## starting current flows while they do); with instant switching they are at
## their final speed at once.
## Push buttons and switches move through their own actuators the same way
## (instantly in IDEAL mode). Injected faults (welded or open contacts, open
## or stuck coils, broken wires, overload) are taken into account.

enum Mode { IDEAL, REALISTIC }

const DEFAULT_MAX_ITERATIONS: int = 1000
## Terminal slots per motor (the largest motor has nine).
const MOTOR_TERMINALS: int = 9
const DEFAULT_MAX_EVENTS: int = 20000
## A coil that switched at least this often within [constant CHATTER_WINDOW]
## seconds is reported as chattering.
const CHATTER_TOGGLES: int = 8
const CHATTER_WINDOW: float = 0.5
## Event log entries kept per step at most.
const MAX_LOGGED_EVENTS: int = 50
## Longest step while a motor runs up or slows down (seconds).
const MOTOR_STEP: float = 0.01
## Edge kinds of the current-flow graph (see [method _find_current_paths]).
const _EDGE_WIRE: int = 0
const _EDGE_SWITCH: int = 1
const _EDGE_LOAD: int = 2
const _EDGE_VIRTUAL: int = 3
## Rectifier output joined to its DC conductor node (ref: rectifier index).
const _EDGE_OUTPUT: int = 4
## Page connectors with the same label (see [method Circuit.get_links]).
const _EDGE_LINK: int = 5

var circuit: Circuit
var mode: Mode = Mode.IDEAL
var max_iterations: int = DEFAULT_MAX_ITERATIONS
var max_events: int = DEFAULT_MAX_EVENTS
var last_result: StepResult = StepResult.new()
## Simulated seconds so far.
var time: float = 0.0
## Optional: receives coil power, armature positions and load states.
var trace: TraceRecorder = null

var _built_version: int = -1
var _net_count: int = 0
var _net_of_key: Dictionary[String, int] = {}
## Switching paths: a switching element has one, a changeover contact two
## ([member _switch_paths] tells which).
var _switches: Array[CircuitComponent] = []
var _switch_paths: PackedInt32Array = PackedInt32Array()
## Two nets and two terminal indices per switching path.
var _switch_nets: PackedInt32Array = PackedInt32Array()
var _switch_terms: PackedInt32Array = PackedInt32Array()
var _loads: Array[Load] = []
## Two nets per load, in the order of [member _loads].
var _load_nets: PackedInt32Array = PackedInt32Array()
## Load index -> net of the control input S of time relays that have one.
var _control_nets: Dictionary[int, int] = {}
## Time relays (load index) with A1 and A2 swapped: A2 is their first terminal.
var _control_a2_first: Dictionary[int, bool] = {}
## Indices into [member _loads] of the coils, in the order they were added.
var _coil_indices: PackedInt32Array = PackedInt32Array()
## Indices into [member _loads] of the PLCs, the nets of their inputs (from
## _plc_input_start[p] on for PLC p) and, from the last evaluation, which
## inputs have voltage against their N (bit k: input k + 1).
var _plc_indices: PackedInt32Array = PackedInt32Array()
var _plc_input_nets: PackedInt32Array = PackedInt32Array()
var _plc_input_start: PackedInt32Array = PackedInt32Array()
var _plc_inputs: PackedInt32Array = PackedInt32Array()
## Expansion modules of the PLCs: nets and terminal indices of their L1 and
## N (from _plc_module_start[p] on, two per module) and, from the last
## evaluation, which have voltage (bit m: module m).
var _plc_module_nets: PackedInt32Array = PackedInt32Array()
var _plc_module_terms: PackedInt32Array = PackedInt32Array()
var _plc_module_start: PackedInt32Array = PackedInt32Array()
var _plc_modules: PackedInt32Array = PackedInt32Array()
## Analog inputs and outputs of the PLCs: their nets (from
## _plc_ai_start[p] / _plc_aq_start[p] on) and, from the last evaluation,
## the volts on each analog input.
var _plc_ai_nets: PackedInt32Array = PackedInt32Array()
var _plc_ai_start: PackedInt32Array = PackedInt32Array()
var _plc_aq_nets: PackedInt32Array = PackedInt32Array()
var _plc_aq_start: PackedInt32Array = PackedInt32Array()
var _plc_analog: Array[PackedFloat32Array] = []
## Temperature sensors (load index) and the net of their output U.
var _sensor_outputs: Dictionary[int, int] = {}
## Actuators of push buttons and switches (one per device).
var _actuators: Array[Armature] = []
var _overload_relays: Array[OverloadRelay] = []
## Parts with a protection state (fuses, breakers, overload relays).
var _protective: Array[CircuitComponent] = []
var _supplies: Array[PowerSupply] = []
## Indices into [member _loads] of the rectifiers, their output nets (+, -)
## and, from the last evaluation, which ones have voltage on their input.
var _rectifiers: PackedInt32Array = PackedInt32Array()
var _rectifier_out_nets: PackedInt32Array = PackedInt32Array()
var _rectifier_on: PackedByteArray = PackedByteArray()
var _motors: Array[ThreePhaseMotor] = []
## Nine nets per motor (-1 where it has no such terminal).
var _motor_nets: PackedInt32Array = PackedInt32Array()
## Last evaluation: motor state and direction, overcurrent per overload relay.
var _motor_states: PackedInt32Array = PackedInt32Array()
var _motor_directions: PackedInt32Array = PackedInt32Array()
var _motor_speeds: PackedInt32Array = PackedInt32Array()
## Per motor terminal slot: the phase 1-3 on it (0: none), from the last evaluation.
var _motor_phases: PackedInt32Array = PackedInt32Array()
## Per motor: [potentials, fixed, groups, DC polarity] of its winding terminals
## (see [method ThreePhaseMotor.set_supply]), from the last evaluation.
var _motor_supply: Array[Array] = []
## Terminal indices: of each motor terminal slot (-1 where none), of the two
## terminals of each load, of each supply point, of each rectifier's + and -.
var _motor_terms: PackedInt32Array = PackedInt32Array()
var _load_terms: PackedInt32Array = PackedInt32Array()
var _supply_terms: PackedInt32Array = PackedInt32Array()
var _rectifier_out_terms: PackedInt32Array = PackedInt32Array()
## Terminal key of every terminal index.
var _terminal_keys: PackedStringArray = PackedStringArray()
## Group roots and supply masks of the last evaluation.
var _eval_uf: UnionFind = null
var _eval_masks: Dictionary[int, int] = {}
var _flow: CurrentFlow = CurrentFlow.new()
## Current through each switching path (amperes), from the last evaluation.
var _path_current: PackedFloat32Array = PackedFloat32Array()
## Switching paths of each protective part, in pole order.
var _device_paths: Dictionary[CircuitComponent, PackedInt32Array] = {}
var _short: bool = false
## Terminal index (into the current-flow graph) of every terminal key.
var _terminal_index: Dictionary[String, int] = {}
## Terminal pairs joined by page connectors (see [method Circuit.get_links]).
var _links: Array[PackedStringArray] = []
## Realistic mode: times at which each coil (by designation) switched recently.
var _toggles: Dictionary[String, PackedFloat64Array] = {}
var _chattering: Dictionary[String, bool] = {}
## Realistic mode: when the present short circuit began, or -1.
var _short_since: float = -1.0


func _init(p_circuit: Circuit) -> void:
	circuit = p_circuit


## Advances the simulation by [param delta] seconds.
func step(delta: float = 0.0) -> StepResult:
	_ensure_built()
	if mode == Mode.REALISTIC:
		last_result = _step_realistic(maxf(delta, 0.0))
	else:
		var result: StepResult = StepResult.new()
		for actuator: Armature in _actuators:
			actuator.snap(actuator.target)
		if delta > 0.0:
			for i: int in _coil_indices:
				var coil: Coil = _loads[i] as Coil
				coil.advance(delta)
				coil.snap()
			for i: int in _plc_indices:
				var plc: Plc = _loads[i] as Plc
				plc.advance(delta)
				plc.snap()
			_advance_protection(delta, result)
			_advance_motors(delta, result)
		time += maxf(delta, 0.0)
		last_result = _settle(result)
		_record_trace()
	return last_result


## Number of electrical nets (groups of terminals joined by wires).
func get_net_count() -> int:
	_ensure_built()
	return _net_count


## Net index of a terminal, or -1 for an unknown terminal.
func get_net_of(terminal_key: String) -> int:
	_ensure_built()
	return _net_of_key.get(terminal_key, -1)


func _ensure_built() -> void:
	if _built_version != circuit.topology_version:
		_build()
		_built_version = circuit.topology_version


func _build() -> void:
	var index: Dictionary[String, int] = {}
	_terminal_keys.clear()
	for c: CircuitComponent in circuit.get_components():
		for key: String in c.get_terminal_keys():
			index[key] = index.size()
			_terminal_keys.append(key)
	_terminal_index = index

	var uf: UnionFind = UnionFind.new(index.size())
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for w: int in wires.size():
		if not circuit.broken_wires.has(w):
			uf.union(index[wires[w][0]], index[wires[w][1]])
	# Page connectors with the same label join their pages.
	_links = circuit.get_links()
	for link: PackedStringArray in _links:
		uf.union(index[link[0]], index[link[1]])

	var net_of_root: Dictionary[int, int] = {}
	_net_of_key.clear()
	for key: String in index:
		var root: int = uf.find(index[key])
		if not net_of_root.has(root):
			net_of_root[root] = net_of_root.size()
		_net_of_key[key] = net_of_root[root]
	_net_count = net_of_root.size()
	# Current flow along the wires and page links of each net.
	var net_of: PackedInt32Array = PackedInt32Array()
	net_of.resize(index.size())
	for key: String in index:
		net_of[index[key]] = _net_of_key[key]
	var edges: PackedInt32Array = PackedInt32Array()
	var edge_wires: PackedInt32Array = PackedInt32Array()
	for w: int in wires.size():
		if not circuit.broken_wires.has(w):
			edges.append_array(PackedInt32Array([index[wires[w][0]], index[wires[w][1]]]))
			edge_wires.append(w)
	for link: PackedStringArray in _links:
		edges.append_array(PackedInt32Array([index[link[0]], index[link[1]]]))
		edge_wires.append(-1)
	_flow.setup(net_of, _net_count, edges, edge_wires, wires.size())

	_switches.clear()
	_switch_paths.clear()
	_switch_nets.clear()
	_switch_terms.clear()
	_loads.clear()
	_load_nets.clear()
	_control_nets.clear()
	_control_a2_first.clear()
	_coil_indices.clear()
	_plc_indices.clear()
	_plc_input_nets.clear()
	_plc_input_start.clear()
	_plc_module_nets.clear()
	_plc_module_terms.clear()
	_plc_module_start.clear()
	_plc_ai_nets.clear()
	_plc_ai_start.clear()
	_plc_aq_nets.clear()
	_plc_aq_start.clear()
	_sensor_outputs.clear()
	_supplies.clear()
	_rectifiers.clear()
	_rectifier_out_nets.clear()
	_actuators.clear()
	_overload_relays.clear()
	_protective.clear()
	_motors.clear()
	_motor_nets.clear()
	_motor_terms.clear()
	_load_terms.clear()
	_supply_terms.clear()
	_rectifier_out_terms.clear()
	_device_paths.clear()
	for c: CircuitComponent in circuit.get_components():
		var keys: PackedStringArray = c.get_terminal_keys()
		if c is PushButton or c is LatchingSwitch:
			var actuator: Armature = (c as SwitchingElement).get_armature()
			if not _actuators.has(actuator):
				_actuators.append(actuator)
		if c.protection_state() >= 0:
			_protective.append(c)
		if c is OverloadRelay:
			_overload_relays.append(c as OverloadRelay)
		var paths: Array[Vector2i] = c.switch_paths()
		if c.protection_state() >= 0 and not paths.is_empty():
			_device_paths[c] = PackedInt32Array(range(_switches.size(), _switches.size() + paths.size()))
		for p: int in paths.size():
			_add_switch_path(c, p, keys[paths[p].x], keys[paths[p].y])
		if c is Plc:
			# A load on L1-N with inputs, besides its output contacts.
			_plc_indices.append(_loads.size())
			_loads.append(c as Plc)
			_load_nets.append(_net_of_key[keys[0]])
			_load_nets.append(_net_of_key[keys[1]])
			_load_terms.append(index[keys[0]])
			_load_terms.append(index[keys[1]])
			var plc: Plc = c as Plc
			_plc_input_start.append(_plc_input_nets.size())
			for k: int in plc.input_count():
				_plc_input_nets.append(_net_of_key[keys[plc.input_terminal(k)]])
			_plc_module_start.append(_plc_module_nets.size())
			for m: int in plc.modules.size():
				for t: int in 2:
					_plc_module_nets.append(_net_of_key[keys[plc.module_terminal(m) + t]])
					_plc_module_terms.append(index[keys[plc.module_terminal(m) + t]])
			_plc_ai_start.append(_plc_ai_nets.size())
			for k: int in plc.analog_input_count():
				_plc_ai_nets.append(_net_of_key[keys[plc.analog_input_terminal(k)]])
			_plc_aq_start.append(_plc_aq_nets.size())
			for k: int in plc.analog_output_count():
				_plc_aq_nets.append(_net_of_key[keys[plc.analog_output_terminal(k)]])
			continue
		if not paths.is_empty():
			continue
		if c is ThreePhaseMotor:
			_motors.append(c as ThreePhaseMotor)
			var windings: int = (c as ThreePhaseMotor).winding_terminal_count()
			for t: int in MOTOR_TERMINALS:
				_motor_nets.append(_net_of_key[keys[t]] if t < windings else -1)
				_motor_terms.append(index[keys[t]] if t < windings else -1)
		elif c is Load:
			if c is Coil:
				_coil_indices.append(_loads.size())
			elif c is Rectifier:
				_rectifiers.append(_loads.size())
				_rectifier_out_nets.append(_net_of_key[keys[2]])
				_rectifier_out_nets.append(_net_of_key[keys[3]])
				_rectifier_out_terms.append(index[keys[2]])
				_rectifier_out_terms.append(index[keys[3]])
			_loads.append(c as Load)
			if c is TemperatureSensor:
				_sensor_outputs[_loads.size() - 1] = _net_of_key[keys[2]]
			if c is TimerRelay and (c as TimerRelay).control_input and keys.size() > 2:
				_control_nets[_loads.size() - 1] = _net_of_key[keys[2]]
				if (c as TimerRelay).a2_index() == 0:
					_control_a2_first[_loads.size() - 1] = true
			_load_nets.append(_net_of_key[keys[0]])
			_load_nets.append(_net_of_key[keys[1]])
			_load_terms.append(index[keys[0]])
			_load_terms.append(index[keys[1]])
		elif c is PowerSupply:
			_supplies.append(c as PowerSupply)
			_supply_terms.append(index[keys[0]])
	_rectifier_on.resize(_rectifiers.size())
	_rectifier_on.fill(0)
	_plc_inputs.resize(_plc_indices.size())
	_plc_inputs.fill(0)
	_plc_modules.resize(_plc_indices.size())
	_plc_modules.fill(0)
	_plc_analog.resize(_plc_indices.size())
	_plc_analog.fill(PackedFloat32Array())
	_motor_states.resize(_motors.size())
	_motor_directions.resize(_motors.size())
	_motor_speeds.resize(_motors.size())
	_motor_phases.resize(_motors.size() * MOTOR_TERMINALS)
	_motor_phases.fill(0)
	_motor_supply.clear()
	for m: int in _motors.size():
		_motor_supply.append(_unfed_motor(_motors[m]))
	_path_current.resize(_switches.size())
	_path_current.fill(0.0)


func _add_switch_path(c: CircuitComponent, path: int, key_a: String, key_b: String) -> void:
	_switches.append(c)
	_switch_paths.append(path)
	_switch_nets.append(_net_of_key[key_a])
	_switch_nets.append(_net_of_key[key_b])
	_switch_terms.append(_terminal_index[key_a])
	_switch_terms.append(_terminal_index[key_b])


func _switch_closed(i: int) -> bool:
	return _switches[i].is_path_closed(_switch_paths[i])


## Union-find over the nets joined by closed switching paths.
func _union_closed() -> UnionFind:
	var uf: UnionFind = UnionFind.new(_net_count)
	for i: int in _switches.size():
		if _switch_closed(i):
			uf.union(_switch_nets[2 * i], _switch_nets[2 * i + 1])
	return uf


## Supply bits reaching each group root. Rectifiers with voltage on their
## input add the DC poles on their outputs (one may feed the next); sets
## [member _rectifier_on].
func _root_masks(uf: UnionFind) -> Dictionary[int, int]:
	var masks: Dictionary[int, int] = {}
	for supply: PowerSupply in _supplies:
		var root: int = uf.find(_net_of_key[supply.designation])
		masks[root] = masks.get(root, 0) | supply.source_bit()
	_rectifier_on.fill(0)
	var changed: bool = true
	while changed:
		changed = false
		for r: int in _rectifiers.size():
			var i: int = _rectifiers[r]
			if _rectifier_on[r] == 1:
				continue
			var a: int = masks.get(uf.find(_load_nets[2 * i]), 0)
			var b: int = masks.get(uf.find(_load_nets[2 * i + 1]), 0)
			if _powers(a, b):
				_rectifier_on[r] = 1
				changed = true
				var plus: int = uf.find(_rectifier_out_nets[2 * r])
				var minus: int = uf.find(_rectifier_out_nets[2 * r + 1])
				masks[plus] = masks.get(plus, 0) | PowerSupply.BIT_DC_RECTIFIED
				masks[minus] = masks.get(minus, 0) | PowerSupply.BIT_DC_MINUS
	return masks


## Points where a supply enters the circuit, as [net, source bit, name]: the
## supply points, then the outputs of the rectifiers that have input voltage
## ("TB1:+").
func _source_points() -> Array[Array]:
	var points: Array[Array] = []
	for supply: PowerSupply in _supplies:
		points.append([_net_of_key[supply.designation], supply.source_bit(), supply.designation])
	for r: int in _rectifiers.size():
		if _rectifier_on[r] == 1:
			var keys: PackedStringArray = _loads[_rectifiers[r]].get_terminal_keys()
			points.append([_rectifier_out_nets[2 * r], PowerSupply.BIT_DC_RECTIFIED, keys[2]])
			points.append([_rectifier_out_nets[2 * r + 1], PowerSupply.BIT_DC_MINUS, keys[3]])
	return points


static func _is_single_source(mask: int) -> bool:
	return mask != 0 and (mask & (mask - 1)) == 0


## 1-3 for a single phase L1-L3, 0 for none, N or several.
static func _phase_of(mask: int) -> int:
	match mask:
		PowerSupply.BIT_L1:
			return 1
		PowerSupply.BIT_L2:
			return 2
		PowerSupply.BIT_L3:
			return 3
	return 0


## Applies what the last evaluation found to lamps, motors and the heating of
## overload relays (coils are switched by the caller).
func _apply_outputs(desired: PackedByteArray, result: StepResult) -> void:
	for i: int in _loads.size():
		if not (_loads[i] is Coil or _loads[i] is Plc):
			_loads[i].energized = (desired[i] & 1) == 1
	for m: int in _motors.size():
		var motor: ThreePhaseMotor = _motors[m]
		var new_state: ThreePhaseMotor.State = _motor_states[m] as ThreePhaseMotor.State
		var was_running: bool = motor.is_running()
		if new_state != motor.state:
			if new_state == ThreePhaseMotor.State.PHASE_LOSS:
				_log(result, "%s: phase loss", [motor.designation])
			elif new_state == ThreePhaseMotor.State.MISWIRED:
				_log(result, "%s: windings wrongly connected", [motor.designation])
			elif new_state == ThreePhaseMotor.State.DC_BRAKING:
				_log(result, "%s: DC braking", [motor.designation])
			elif new_state == ThreePhaseMotor.State.STAR:
				_log(result, "%s runs in star", [motor.designation])
			elif new_state == ThreePhaseMotor.State.DELTA:
				_log(result, "%s runs in delta", [motor.designation])
			elif new_state == ThreePhaseMotor.State.RUNNING:
				if _motor_speeds[m] > 0:
					_log(result, "%s runs at speed %d", [motor.designation, _motor_speeds[m]])
				else:
					_log(result, "%s runs", [motor.designation])
		elif motor.is_running() and _motor_speeds[m] != motor.speed and _motor_speeds[m] > 0:
			_log(result, "%s runs at speed %d", [motor.designation, _motor_speeds[m]])
		motor.state = new_state
		motor.direction = _motor_directions[m] as ThreePhaseMotor.Direction
		motor.speed = _motor_speeds[m]
		var supply: Array = _motor_supply[m]
		motor.set_supply(supply[0], supply[1], supply[2], supply[3])
		if mode == Mode.IDEAL:
			# Instant switching: at the final speed at once.
			motor.snap_speed()
		# Fed: the currents for the present speed; switched off it runs down
		# (at once when its run-down time is 0).
		if motor.advance_shaft(0.0):
			_log(result, "%s stopped", [motor.designation])
		elif was_running and new_state == ThreePhaseMotor.State.STOPPED and motor.is_turning():
			_log(result, "%s switched off, runs down", [motor.designation])
	_compute_currents()


## Settles the coils, then lets breakers whose magnetic release the currents
## reach trip and settles again.
func _settle(result: StepResult) -> StepResult:
	for round: int in _protective.size() + 1:
		_settle_coils(result)
		if not _instant_trips(result):
			break
	_finish(result)
	return result


func _settle_coils(result: StepResult) -> void:
	var seen: Dictionary[String, int] = {}
	var history: Array[PackedByteArray] = []
	var desired: PackedByteArray = PackedByteArray()
	var settled: bool = false

	while result.iterations < max_iterations:
		desired = _evaluate_protected(result)
		result.iterations += 1
		var signature: PackedByteArray = _signature()
		var key: String = signature.hex_encode()
		if seen.has(key):
			result.oscillating_tags = _changing_tags(history.slice(seen[key]))
			break
		seen[key] = history.size()
		history.append(signature)

		var switched: bool = false
		for i: int in _coil_indices:
			var coil: Coil = _loads[i] as Coil
			var want: bool = (desired[i] & 1) == 1
			if coil.energized != want:
				coil.set_energized(want)
				coil.snap()
				switched = true
				break
			if _control_nets.has(i) and (coil as TimerRelay).control != ((desired[i] & 2) != 0):
				(coil as TimerRelay).set_control((desired[i] & 2) != 0)
				coil.snap()
				switched = true
				break
		if not switched:
			for p: int in _plc_indices.size():
				var plc: Plc = _loads[_plc_indices[p]] as Plc
				var powered: bool = (desired[_plc_indices[p]] & 1) == 1
				if plc.energized != powered or plc.inputs != _plc_inputs[p] or plc.module_power != _plc_modules[p] or plc.analog_in != _plc_analog[p]:
					plc.update(powered, _plc_inputs[p], _plc_modules[p], _plc_analog[p])
				elif plc.pending:
					plc.rescan()
				else:
					continue
				plc.snap()
				switched = true
				break
		if not switched:
			settled = true
			break

	if not settled and result.oscillating_tags.is_empty():
		# Iteration cap reached without a repeated state.
		result.oscillating_tags = _changing_tags(history)
		desired = _evaluate_protected(result)

	result.stable = settled
	_apply_outputs(desired, result)


func _finish(result: StepResult) -> void:
	result.short_circuit = _short
	result.wire_currents = _flow.wire_currents.duplicate()
	for t: int in _flow.terminal_currents.size():
		var amps: float = _flow.terminal_currents[t].length()
		if amps > 1e-6:
			result.terminal_currents[_terminal_keys[t]] = amps
	if _short:
		result.short_circuit_path = _find_short_path()
	_find_current_paths(result)
	_find_live_parts(result)


# --- Realistic mode ------------------------------------------------------------

func _step_realistic(delta: float) -> StepResult:
	var result: StepResult = StepResult.new()
	var remaining: float = delta
	var events: int = 0
	while true:
		_apply_power(result)
		var dt: float = remaining
		for i: int in _coil_indices:
			dt = minf(dt, (_loads[i] as Coil).time_to_next_event())
		for i: int in _plc_indices:
			dt = minf(dt, (_loads[i] as Plc).time_to_next_event())
		for actuator: Armature in _actuators:
			dt = minf(dt, actuator.time_to_next_event())
		for relay: OverloadRelay in _overload_relays:
			dt = minf(dt, relay.time_to_trip())
		for motor: ThreePhaseMotor in _motors:
			dt = minf(dt, motor.time_to_standstill())
			if not motor.is_settled():
				dt = minf(dt, MOTOR_STEP)
		dt = minf(dt, _time_to_heat_trip())
		dt = maxf(dt, 0.0)
		_advance_armatures(dt, result)
		time += dt
		remaining -= dt
		events += 1
		if remaining <= 1e-12:
			break
		if events >= max_events:
			# Too much going on: move on without tracing every event.
			_advance_armatures(remaining, result)
			time += remaining
			result.stable = false
			break
	_apply_power(result)
	result.iterations = events
	_update_chatter(result)
	_finish(result)
	return result


## Traces power for the present contact positions: coils get or lose power
## (their armatures start moving), lamps and motors follow at once.
func _apply_power(result: StepResult) -> void:
	for round: int in _protective.size() + 1:
		var desired: PackedByteArray = _evaluate_protected(result)
		for i: int in _coil_indices:
			var coil: Coil = _loads[i] as Coil
			var want: bool = (desired[i] & 1) == 1
			if coil.energized != want:
				coil.set_energized(want)
				_note_toggle(coil.designation)
			if _control_nets.has(i):
				(coil as TimerRelay).set_control((desired[i] & 2) != 0)
		for p: int in _plc_indices.size():
			var plc: Plc = _loads[_plc_indices[p]] as Plc
			var powered: bool = (desired[_plc_indices[p]] & 1) == 1
			if powered != plc.energized:
				_log(result, "%s switched on" if powered else "%s switched off", [plc.designation])
			for m: int in plc.modules.size():
				var module_on: bool = powered and (_plc_modules[p] >> m) & 1 == 1
				if module_on != plc.module_on(m):
					_log(result, "%s: expansion module %d switched on" if module_on else "%s: expansion module %d switched off", [plc.designation, m + 1])
			plc.update(powered, _plc_inputs[p], _plc_modules[p], _plc_analog[p])
		_apply_outputs(desired, result)
		if not _instant_trips(result):
			break
	if _short and _short_since < 0.0:
		_short_since = time
		_log(result, "Short circuit: %s", [" → ".join(_find_short_path())])
	elif not _short and _short_since >= 0.0:
		_log(result, "Short circuit ended after %.1f ms", [(time - _short_since) * 1000.0])
		_short_since = -1.0
	_record_trace()


func _advance_armatures(dt: float, result: StepResult) -> void:
	for actuator: Armature in _actuators:
		actuator.advance(dt)
	_advance_protection(dt, result)
	_advance_motors(dt, result)
	for i: int in _coil_indices:
		var coil: Coil = _loads[i] as Coil
		var was_in: bool = coil.armature.position >= 1.0
		var was_out: bool = coil.armature.position <= 0.0
		var timer: TimerRelay = coil as TimerRelay
		var output_before: bool = timer.output if timer != null else false
		coil.move_armatures(dt)
		coil.advance(dt)
		if not was_in and coil.armature.position >= 1.0:
			_log(result, "%s pulled in", [coil.designation], time + dt)
		elif not was_out and coil.armature.position <= 0.0:
			_log(result, "%s released", [coil.designation], time + dt)
		if timer != null and timer.output != output_before:
			_log(result, "%s timed output on" if timer.output else "%s timed output off", [coil.designation], time + dt)
	for i: int in _plc_indices:
		var plc: Plc = _loads[i] as Plc
		var closed_before: PackedByteArray = PackedByteArray()
		for a: Armature in plc.output_armatures:
			closed_before.append(1 if a.no_closed else 0)
		plc.move_armatures(dt)
		plc.advance(dt)
		for k: int in plc.output_count():
			var closed: bool = plc.output_armatures[k].no_closed
			if closed != (closed_before[k] == 1):
				_log(result, "%s: output Q%d on" if closed else "%s: output Q%d off", [plc.designation, k + 1], time + dt)


## Heats fuses, breakers and overload relays for [param dt] seconds with the
## currents of the last evaluation; the injected overload of overload relays
## counts on.
func _advance_protection(dt: float, result: StepResult) -> void:
	for relay: OverloadRelay in _overload_relays:
		if relay.advance(dt):
			_log(result, "%s tripped (overload)", [relay.designation], time + dt)
	for device: CircuitComponent in _device_paths:
		var currents: PackedFloat32Array = _device_currents(device)
		var soonest: float = device.time_to_heat_trip(currents)
		if device.heat_up(dt, currents):
			var text: String = "%s blown" if device is Fuse or device is ThreePoleFuse else "%s tripped (overload)"
			_log(result, text, [device.designation], time + minf(soonest, dt))


## Currents through the poles of a protective part, amperes.
func _device_currents(device: CircuitComponent) -> PackedFloat32Array:
	var currents: PackedFloat32Array = PackedFloat32Array()
	for i: int in _device_paths[device]:
		currents.append(_path_current[i])
	return currents


## Seconds until the present currents make a protective part trip, or INF.
func _time_to_heat_trip() -> float:
	var soonest: float = INF
	for device: CircuitComponent in _device_paths:
		soonest = minf(soonest, device.time_to_heat_trip(_device_currents(device)))
	return soonest


## Breakers whose magnetic release the present currents reach trip at once.
## Returns true if one did.
func _instant_trips(result: StepResult) -> bool:
	var any: bool = false
	for device: CircuitComponent in _device_paths:
		if device.trips_instantly(_device_currents(device)):
			_log(result, "%s tripped (short-circuit release)", [device.designation])
			any = true
	return any


## Moves the shafts on by [param dt] seconds: motors fed with AC run up or
## slow down (in realistic timing; with instant switching they already are at
## their speed), switched-off motors run down.
func _advance_motors(dt: float, result: StepResult) -> void:
	for motor: ThreePhaseMotor in _motors:
		if motor.ac_powered and mode == Mode.IDEAL:
			continue
		var stops_in: float = motor.time_to_standstill()
		var before: float = motor.shaft
		if motor.advance_shaft(dt):
			_log(result, "%s stopped", [motor.designation], time + minf(stops_in, dt))
		elif motor.ac_powered and motor.is_running() and before < 0.95 and motor.shaft >= 0.95:
			_log(result, "%s up to speed", [motor.designation], time + dt)


## [method _evaluate], but first lets every fuse or breaker that carries the
## fault current of a short circuit trip.
func _evaluate_protected(result: StepResult) -> PackedByteArray:
	var desired: PackedByteArray = _evaluate()
	while _burn_out(desired, result):
		desired = _evaluate()
	while _short:
		var probe: StepResult = StepResult.new()
		_find_current_paths(probe, false)
		var tripped: bool = false
		for i: int in probe.current_switch_paths:
			var c: CircuitComponent = _switches[i]
			if c.trip_path(_switch_paths[i]):
				tripped = true
				_log(result, c.trip_message(), [c.designation])
		if not tripped:
			break
		desired = _evaluate()
	return desired


## Loads with too high a voltage across them (bit 2 of [param desired]) burn
## out; true when any did.
func _burn_out(desired: PackedByteArray, result: StepResult) -> bool:
	var any: bool = false
	for i: int in _loads.size():
		if desired[i] & 4 != 0 and not _loads[i].burnt:
			_loads[i].burnt = true
			any = true
			var rated: String = VoltageRating.text(_loads[i].rating)
			_log(result, "%s burnt out: too high a voltage for %s", [_loads[i].designation, rated])
	return any


func _note_toggle(designation: String) -> void:
	var times: PackedFloat64Array = _toggles.get(designation, PackedFloat64Array())
	times.append(time)
	var cut: int = 0
	while cut < times.size() and times[cut] < time - CHATTER_WINDOW:
		cut += 1
	_toggles[designation] = times.slice(cut)


func _update_chatter(result: StepResult) -> void:
	for designation: String in _toggles:
		var times: PackedFloat64Array = _toggles[designation]
		var recent: int = 0
		for t: float in times:
			if t >= time - CHATTER_WINDOW:
				recent += 1
		if recent >= CHATTER_TOGGLES:
			var span: float = maxf(times[times.size() - 1] - times[times.size() - recent], 1e-6)
			result.oscillating_tags.append(designation)
			result.chatter_hz[designation] = (recent - 1) / 2.0 / span
			if not _chattering.has(designation):
				_chattering[designation] = true
				_log(result, "%s is chattering", [designation])
		else:
			_chattering.erase(designation)
	if not result.oscillating_tags.is_empty():
		result.stable = false


func _log(result: StepResult, text: String, args: Array, at: float = -1.0) -> void:
	if result.events.size() < MAX_LOGGED_EVENTS:
		result.events.append({"time": at if at >= 0.0 else time, "text": text, "args": args})


func _record_trace() -> void:
	if trace == null:
		return
	for i: int in _loads.size():
		var load: Load = _loads[i]
		trace.record(load.designation, time, 1.0 if load.energized else 0.0)
		if load is Coil:
			trace.record(load.designation + "/armature", time, (load as Coil).armature.position, true)
			if load is TimerRelay:
				trace.record(load.designation + "/output", time, (load as TimerRelay).output_armature.position, true)
		elif load is Plc:
			for k: int in (load as Plc).output_count():
				trace.record("%s/Q%d" % [load.designation, k + 1], time, (load as Plc).output_armatures[k].position, true)
	for m: int in _motors.size():
		var motor: ThreePhaseMotor = _motors[m]
		trace.record(motor.designation, time, 1.0 if motor.is_running() else 0.0)
		trace.record(motor.designation + "/shaft", time, motor.shaft, true)
		var lines: PackedFloat32Array = motor_line_currents(m)
		for p: int in 3:
			trace.record("%s/I%d" % [motor.designation, p + 1], time, lines[p], true)
	for device: CircuitComponent in _device_paths:
		var currents: PackedFloat32Array = _device_currents(device)
		for p: int in currents.size():
			trace.record("%s/I%d" % [device.designation, p + 1], time, currents[p], true)


## Returns, per load, 1 if its terminals are reached by two different supplies
## of the same source (phase and N, two phases, or + and -) through closed
## switching paths, and works out
## the motors and overload relays (applied by [method _apply_outputs]). Sets
## [member _short]; during a short everything is without power.
func _evaluate() -> PackedByteArray:
	var uf: UnionFind = _union_closed()
	var masks: Dictionary[int, int] = _root_masks(uf)
	_short = false
	for root: int in masks:
		if not _is_single_source(masks[root]):
			_short = true
			break

	var result: PackedByteArray = PackedByteArray()
	result.resize(_loads.size())
	result.fill(0)
	_motor_states.fill(ThreePhaseMotor.State.STOPPED)
	_motor_directions.fill(ThreePhaseMotor.Direction.NONE)
	_motor_speeds.fill(0)
	_motor_phases.fill(0)
	_eval_uf = uf
	_eval_masks = masks
	if _short:
		for m: int in _motors.size():
			_motor_supply[m] = _unfed_motor(_motors[m])
		_plc_inputs.fill(0)
		_plc_modules.fill(0)
		_plc_analog.fill(PackedFloat32Array())
		return result
	for i: int in _loads.size():
		var a: int = masks.get(uf.find(_load_nets[2 * i]), 0)
		var b: int = masks.get(uf.find(_load_nets[2 * i + 1]), 0)
		match _rated_state(_loads[i].rating, a, b):
			VoltageRating.State.WORKS:
				result[i] = 1
			VoltageRating.State.BURNS:
				# Too high a voltage (bit 2): burns out (see _burn_out).
				result[i] = 4
		if _loads[i].burnt:
			result[i] = 0
		if _loads[i] is Coil and (_loads[i] as Coil).fault == Coil.Fault.OPEN:
			# A broken winding has voltage but draws no current.
			result[i] = 0
		if _control_nets.has(i):
			# Control input S: pressed when it has voltage against A2 (bit 1).
			var s: int = masks.get(uf.find(_control_nets[i]), 0)
			if _powers(s, a if _control_a2_first.has(i) else b):
				result[i] |= 2
	for p: int in _plc_indices.size():
		# Expansion modules: on with voltage on their own L1-N.
		var plc: Plc = _loads[_plc_indices[p]] as Plc
		var module_n: PackedInt32Array = PackedInt32Array()
		var on: int = 0
		var overvoltage: bool = false
		for m: int in plc.modules.size():
			var at: int = _plc_module_start[p] + 2 * m
			module_n.append(masks.get(uf.find(_plc_module_nets[at + 1]), 0))
			match _rated_state(plc.module_rating(m), masks.get(uf.find(_plc_module_nets[at]), 0), module_n[m]):
				VoltageRating.State.WORKS:
					on |= 1 << m
				VoltageRating.State.BURNS:
					overvoltage = true
		_plc_modules[p] = on
		# Inputs: on with voltage against the N terminal of the PLC (of the
		# module they are on).
		var n_mask: int = masks.get(uf.find(_load_nets[2 * _plc_indices[p] + 1]), 0)
		var bits: int = 0
		var threshold: float = VoltageRating.input_threshold(plc.rating)
		for k: int in plc.input_count():
			var m: int = plc.input_module(k)
			var input: int = masks.get(uf.find(_plc_input_nets[_plc_input_start[p] + k]), 0)
			var reference: int = n_mask if m < 0 else module_n[m]
			if not _powers(input, reference):
				continue
			var volts: float = _volts(input, reference)
			if VoltageRating.state(plc.rating, volts, (input & PowerSupply.AC_BITS) == 0) == VoltageRating.State.BURNS:
				overvoltage = true
			elif volts >= threshold and (VoltageRating.kind(plc.rating) != VoltageRating.Kind.DC or (input & PowerSupply.AC_BITS) == 0):
				bits |= 1 << k
		_plc_inputs[p] = bits
		if overvoltage and not plc.burnt:
			result[_plc_indices[p]] = 4
	# Analog signals: volts put on nets by the sensors that have their
	# supply and by the analog outputs of the PLCs.
	var analog: Dictionary[int, float] = {}
	for i: int in _sensor_outputs:
		analog[uf.find(_sensor_outputs[i])] = (_loads[i] as TemperatureSensor).output_volts(result[i] & 1 == 1)
	for p: int in _plc_indices.size():
		var plc: Plc = _loads[_plc_indices[p]] as Plc
		for k: int in plc.analog_output_count():
			var root: int = uf.find(_plc_aq_nets[_plc_aq_start[p] + k])
			analog[root] = maxf(analog.get(root, 0.0), plc.analog_output_volts(k))
	for p: int in _plc_indices.size():
		var plc: Plc = _loads[_plc_indices[p]] as Plc
		var volts: PackedFloat32Array = PackedFloat32Array()
		for k: int in plc.analog_input_count():
			var root: int = uf.find(_plc_ai_nets[_plc_ai_start[p] + k])
			var mask: int = masks.get(root, 0)
			# A DC + pole on an analog input reads its voltage.
			var dc: float = PowerSupply.dc_volts(mask) if _is_single_source(mask) else 0.0
			volts.append(snappedf(analog.get(root, dc), 0.001))
		_plc_analog[p] = volts
	_evaluate_motors(uf, masks)
	return result


## True when supply masks [param a] and [param b] give voltage: one supply
## each, different, of the same source (AC or DC).
static func _powers(a: int, b: int) -> bool:
	if not (_is_single_source(a) and _is_single_source(b)) or a == b:
		return false
	var ac: int = PowerSupply.AC_BITS
	return ((a & ac) != 0) == ((b & ac) != 0)


## Supply of a motor with nothing on its terminals (see [member _motor_supply]).
static func _unfed_motor(motor: ThreePhaseMotor) -> Array:
	var count: int = motor.winding_terminal_count()
	var potentials: PackedVector2Array = PackedVector2Array()
	potentials.resize(count)
	var fixed: PackedByteArray = PackedByteArray()
	fixed.resize(count)
	var groups: PackedInt32Array = PackedInt32Array(range(-1, -1 - count, -1))
	var polarity: PackedInt32Array = PackedInt32Array()
	polarity.resize(count)
	return [potentials, fixed, groups, polarity]


## Potential of a group reached by supply bits [param mask] (see [Phasor]):
## the phase, 0 for N and DC -, 1 for DC +.
static func _potential_of(mask: int) -> Vector2:
	match mask:
		PowerSupply.BIT_L1:
			return Phasor.phase(1)
		PowerSupply.BIT_L2:
			return Phasor.phase(2)
		PowerSupply.BIT_L3:
			return Phasor.phase(3)
	if _is_single_source(mask) and (mask & PowerSupply.DC_PLUS_BITS) != 0:
		return Phasor.ONE
	return Vector2.ZERO


## Volts between groups reached by supply bits [param a] and [param b] (one
## supply each, of the same source).
static func _volts(a: int, b: int) -> float:
	if (a & PowerSupply.AC_BITS) != 0:
		return (_potential_of(a) - _potential_of(b)).length() * PowerSupply.PHASE_VOLTS
	return absf(PowerSupply.dc_volts(a) - PowerSupply.dc_volts(b))


## What a load rated [param rating] does between supply bits [param a] and
## [param b] (see [method _powers]).
static func _rated_state(rating: String, a: int, b: int) -> VoltageRating.State:
	if not _powers(a, b):
		return VoltageRating.State.OFF
	return VoltageRating.state(rating, _volts(a, b), (a & PowerSupply.AC_BITS) == 0)


## Currents in the lines L1, L2, L3 feeding motor [param m] (amperes): the
## currents of its terminals on each phase added up.
func motor_line_currents(m: int) -> PackedFloat32Array:
	var lines: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	var motor: ThreePhaseMotor = _motors[m]
	for t: int in mini(motor.terminal_currents.size(), MOTOR_TERMINALS):
		var p: int = _motor_phases[MOTOR_TERMINALS * m + t]
		if p > 0:
			lines[p - 1] += motor.terminal_currents[t]
	return PackedFloat32Array([lines[0].length(), lines[1].length(), lines[2].length()])


## Works out the current of every load and spreads it over the circuit (see
## [CurrentFlow]); nothing flows while there is a short (the fault current is
## shown apart).
func _compute_currents() -> void:
	var draws: PackedVector2Array = PackedVector2Array()
	draws.resize(_terminal_index.size())
	var paths: PackedInt32Array = PackedInt32Array()
	var path_ids: PackedInt32Array = PackedInt32Array()
	var sources: PackedInt32Array = _supply_terms.duplicate()
	if not _short and _eval_uf != null:
		for i: int in _loads.size():
			if _loads[i].energized and _loads[i].rated_draw() > 0.0:
				var v: Vector2 = _load_voltage(i)
				draws[_load_terms[2 * i]] += v * _loads[i].rated_draw()
				draws[_load_terms[2 * i + 1]] -= v * _loads[i].rated_draw()
		for p: int in _plc_indices.size():
			# Expansion modules that work draw from their own supply.
			var plc: Plc = _loads[_plc_indices[p]] as Plc
			for m: int in plc.modules.size():
				if plc.module_on(m):
					var at: int = _plc_module_start[p] + 2 * m
					var v: Vector2 = _voltage_between(_plc_module_nets[at], _plc_module_nets[at + 1])
					draws[_plc_module_terms[at]] += v * Plc.MODULE_DRAW
					draws[_plc_module_terms[at + 1]] -= v * Plc.MODULE_DRAW
		for m: int in _motors.size():
			var motor: ThreePhaseMotor = _motors[m]
			for t: int in mini(motor.terminal_currents.size(), MOTOR_TERMINALS):
				draws[_motor_terms[MOTOR_TERMINALS * m + t]] += motor.terminal_currents[t]
		for i: int in _switches.size():
			if _switch_closed(i):
				paths.append(_switch_terms[2 * i])
				paths.append(_switch_terms[2 * i + 1])
				path_ids.append(i)
		for r: int in _rectifiers.size():
			if _rectifier_on[r] == 1:
				sources.append(_rectifier_out_terms[2 * r])
				sources.append(_rectifier_out_terms[2 * r + 1])
	_flow.solve(draws, paths, sources)
	# A working rectifier draws on its input what its output delivers.
	var feeding: bool = false
	for r: int in _rectifiers.size():
		if _rectifier_on[r] == 1 and not _short:
			var out: float = _flow.terminal_currents[_rectifier_out_terms[2 * r]].length()
			var v: Vector2 = _load_voltage(_rectifiers[r])
			if out > 0.0 and v.length() > 0.0:
				var i: int = _rectifiers[r]
				draws[_load_terms[2 * i]] += v.normalized() * out
				draws[_load_terms[2 * i + 1]] -= v.normalized() * out
				feeding = true
	if feeding:
		_flow.solve(draws, paths, sources)
	_path_current.fill(0.0)
	for k: int in path_ids.size():
		_path_current[path_ids[k]] = _flow.path_currents[k].length()
	for relay: OverloadRelay in _overload_relays:
		if _device_paths.has(relay):
			relay.current = TripCurve.largest(_device_currents(relay))
	for m: int in _motors.size():
		_motors[m].line_currents = motor_line_currents(m)


## Voltage across load [param i] (first terminal against the second) from the
## last evaluation, in phase voltages.
func _load_voltage(i: int) -> Vector2:
	return _voltage_between(_load_nets[2 * i], _load_nets[2 * i + 1])


## Voltage of net [param a] against net [param b] from the last evaluation.
func _voltage_between(a: int, b: int) -> Vector2:
	var mask_a: int = _eval_masks.get(_eval_uf.find(a), 0)
	var mask_b: int = _eval_masks.get(_eval_uf.find(b), 0)
	return _potential_of(mask_a) - _potential_of(mask_b)


func _evaluate_motors(uf: UnionFind, masks: Dictionary[int, int]) -> void:
	const PHASE_BITS: int = PowerSupply.BIT_L1 | PowerSupply.BIT_L2 | PowerSupply.BIT_L3
	for m: int in _motors.size():
		var motor: ThreePhaseMotor = _motors[m]
		var phases: PackedInt32Array = PackedInt32Array()
		var roots: PackedInt32Array = PackedInt32Array()
		# DC on each winding terminal: 1 for the + pole, -1 for the - pole.
		var polarity: PackedInt32Array = PackedInt32Array()
		var any_phase: bool = false
		var any_dc: bool = false
		for t: int in MOTOR_TERMINALS:
			var net: int = _motor_nets[MOTOR_TERMINALS * m + t]
			roots.append(uf.find(net) if net >= 0 else -1)
			var mask: int = masks.get(roots[t], 0) if net >= 0 else 0
			phases.append(_phase_of(mask))
			polarity.append(1 if _is_single_source(mask) and (mask & PowerSupply.DC_PLUS_BITS) != 0 else (-1 if mask == PowerSupply.BIT_DC_MINUS else 0))
			any_phase = any_phase or phases[t] != 0
			any_dc = any_dc or polarity[t] != 0
		# For each group of three terminals: joined in a point with no phase on it?
		var star_points: Array[bool] = []
		for g: int in 3:
			var root: int = roots[3 * g]
			star_points.append(root >= 0 and root == roots[3 * g + 1] and root == roots[3 * g + 2] and (masks.get(root, 0) & PHASE_BITS) == 0)
		var outcome: Array = ThreePhaseMotor.evaluate(motor.kind, phases, star_points)
		if any_dc and any_phase:
			outcome = [ThreePhaseMotor.State.MISWIRED, ThreePhaseMotor.Direction.NONE, 0]
		elif any_dc and ThreePhaseMotor.carries_dc(motor.kind, polarity, roots):
			outcome = [ThreePhaseMotor.State.DC_BRAKING, ThreePhaseMotor.Direction.NONE, 0]
		_motor_states[m] = outcome[0]
		_motor_directions[m] = outcome[1]
		_motor_speeds[m] = outcome[2]
		# Potentials for the currents: terminals on one AC conductor are fed,
		# the others float (joined when in one group).
		var count: int = motor.winding_terminal_count()
		var potentials: PackedVector2Array = PackedVector2Array()
		var fixed: PackedByteArray = PackedByteArray()
		var groups: PackedInt32Array = PackedInt32Array()
		for t: int in count:
			var mask: int = masks.get(roots[t], 0)
			var on_ac: bool = _is_single_source(mask) and (mask & PowerSupply.AC_BITS) != 0
			potentials.append(Phasor.phase(phases[t]) if on_ac else Vector2.ZERO)
			fixed.append(1 if on_ac else 0)
			groups.append(roots[t])
			_motor_phases[MOTOR_TERMINALS * m + t] = phases[t]
		_motor_supply[m] = [potentials, fixed, groups, polarity.slice(0, count)]


## One byte per coil (bit 0 coil power, bit 1 timed output), then one per
## protective device (tripped), so a trip is never mistaken for a repeat.
func _signature() -> PackedByteArray:
	var sig: PackedByteArray = PackedByteArray()
	for i: int in _coil_indices:
		var coil: Coil = _loads[i] as Coil
		var b: int = 1 if coil.energized else 0
		if coil is TimerRelay and (coil as TimerRelay).output:
			b |= 2
		if coil is TimerRelay and (coil as TimerRelay).control:
			b |= 4
		sig.append(b)
	for i: int in _plc_indices:
		var plc: Plc = _loads[i] as Plc
		var outputs: int = 1 if plc.energized else 0
		for k: int in plc.output_count():
			if plc.output_on(k):
				outputs |= 2 << k
		sig.append(outputs)
	for device: CircuitComponent in _protective:
		sig.append(device.protection_state())
	for i: int in _plc_indices:
		sig.append_array((_loads[i] as Plc).state_signature())
	return sig


## Designations of coils whose state differs anywhere in [param states].
func _changing_tags(states: Array[PackedByteArray]) -> PackedStringArray:
	var tags: PackedStringArray = PackedStringArray()
	if states.is_empty():
		return tags
	var indices: PackedInt32Array = _coil_indices + _plc_indices
	for j: int in indices.size():
		for s: PackedByteArray in states:
			if s[j] != states[0][j]:
				tags.append(_loads[indices[j]].designation)
				break
	return tags


## Shortest chain of closed switching paths between two supplies of different
## conductors: [supply, element ids..., supply].
func _find_short_path() -> PackedStringArray:
	var adjacency: Array[PackedInt32Array] = []
	adjacency.resize(_net_count)
	for n: int in _net_count:
		adjacency[n] = PackedInt32Array()
	for i: int in _switches.size():
		if _switch_closed(i):
			var a: int = _switch_nets[2 * i]
			var b: int = _switch_nets[2 * i + 1]
			adjacency[a].append_array(PackedInt32Array([i, b]))
			adjacency[b].append_array(PackedInt32Array([i, a]))
	var sources: Array[Array] = _source_points()
	var bits: Array[int] = []
	for source: Array in sources:
		if not bits.has(source[1]):
			bits.append(source[1])
	# From a phase or a + pole first, the return conductors N and - last.
	var returns: int = PowerSupply.BIT_N | PowerSupply.BIT_DC_MINUS
	bits.sort_custom(func(x: int, y: int) -> bool: return (x & returns == 0 and y & returns != 0) or ((x & returns == 0) == (y & returns == 0) and x < y))
	for bit: int in bits:
		var path: PackedStringArray = _short_path_from(bit, sources, adjacency)
		if not path.is_empty():
			return path
	return PackedStringArray()


func _short_path_from(bit: int, sources: Array[Array], adjacency: Array[PackedInt32Array]) -> PackedStringArray:
	var target_of_net: Dictionary[int, String] = {}
	for source: Array in sources:
		if source[1] != bit:
			target_of_net[source[0]] = source[2]
	var prev_net: PackedInt32Array = PackedInt32Array()
	var prev_switch: PackedInt32Array = PackedInt32Array()
	prev_net.resize(_net_count)
	prev_switch.resize(_net_count)
	prev_net.fill(-2)
	prev_switch.fill(-1)
	var start_supply: Dictionary[int, String] = {}
	var queue: PackedInt32Array = PackedInt32Array()
	for source: Array in sources:
		if source[1] != bit:
			continue
		var net: int = source[0]
		if prev_net[net] == -2:
			prev_net[net] = -1
			start_supply[net] = source[2]
			queue.append(net)
	var head: int = 0
	while head < queue.size():
		var net: int = queue[head]
		head += 1
		if target_of_net.has(net):
			var middle: PackedStringArray = PackedStringArray()
			var cursor: int = net
			while prev_net[cursor] != -1:
				middle.append(_switches[prev_switch[cursor]].id)
				cursor = prev_net[cursor]
			middle.reverse()
			var path: PackedStringArray = PackedStringArray([start_supply[cursor]])
			path.append_array(middle)
			path.append(target_of_net[net])
			return path
		var edges: PackedInt32Array = adjacency[net]
		for e: int in range(0, edges.size(), 2):
			var other: int = edges[e + 1]
			if prev_net[other] == -2:
				prev_net[other] = net
				prev_switch[other] = edges[e]
				queue.append(other)
	return PackedStringArray()


## Fills the reach of the supplies in [StepResult]: what each terminal and
## wire is joined to by wires and closed switching paths, whether or not
## current flows there (1-3 phase L1-L3, 4 N, 5 several = short). Loads do not
## pass a supply on.
func _find_live_parts(result: StepResult) -> void:
	var uf: UnionFind = _union_closed()
	var masks: Dictionary[int, int] = _root_masks(uf)
	var code_of_root: Dictionary[int, int] = {}
	for root: int in masks:
		code_of_root[root] = StepResult.reach_code(masks[root])
	# N potential from PE alone is shown as PE.
	var neutral_roots: Dictionary[int, bool] = {}
	for supply: PowerSupply in _supplies:
		if supply.conductor == PowerSupply.Conductor.N:
			neutral_roots[uf.find(_net_of_key[supply.designation])] = true
	for supply: PowerSupply in _supplies:
		var root: int = uf.find(_net_of_key[supply.designation])
		if supply.conductor == PowerSupply.Conductor.PE and not neutral_roots.has(root) and code_of_root.get(root, 0) == StepResult.REACH_N:
			code_of_root[root] = StepResult.REACH_PE
	for key: String in _net_of_key:
		var code: int = code_of_root.get(uf.find(_net_of_key[key]), 0)
		if code == 0:
			continue
		result.terminal_reach[key] = code
		if StepResult.is_return(code):
			result.neutral_terminals.append(key)
		else:
			result.live_terminals.append(key)
	var wires: Array[PackedStringArray] = circuit.get_wires()
	result.wire_reach.resize(wires.size())
	result.wire_reach.fill(0)
	for i: int in wires.size():
		var code_a: int = code_of_root.get(uf.find(_net_of_key[wires[i][0]]), 0)
		var code_b: int = code_of_root.get(uf.find(_net_of_key[wires[i][1]]), 0)
		var code: int = code_a if code_a != 0 and not StepResult.is_return(code_a) else (code_b if code_b != 0 else code_a)
		result.wire_reach[i] = code
		if StepResult.is_return(code):
			result.neutral_wires.append(i)
		elif code != 0:
			result.live_wires.append(i)


## Fills [member StepResult.current_wires] and [member StepResult.current_components].
## [param include_loads] false leaves energized loads out (fault current only).
##
## Graph: terminals are vertices; wires, closed switching paths and energized
## loads are edges. Every supply is joined to a virtual node of its conductor,
## and those nodes to a hub. A wire or element carries current exactly when it
## lies on a simple cycle through the hub (from one conductor to another), i.e.
## in a biconnected component with a hub edge. Dead-end branches and loops
## hanging off a single point stay dark. During a short the loads are off, so
## the result is the fault-current path.
##
## The outputs of a rectifier with input voltage are joined to the DC
## conductor nodes like supply points. Its input (an edge like a load's)
## takes part only when current flows on its outputs, so a rectifier feeding
## nothing draws nothing and a short on its DC side also shows (and blows the
## fuses) on its AC side.
func _find_current_paths(result: StepResult, include_loads: bool = true) -> void:
	if _supplies.is_empty():
		return
	var feeding: Dictionary[int, bool] = {}
	var graph: Dictionary = _current_graph(include_loads, feeding)
	var block: PackedInt32Array = _hub_blocks(graph)
	var kinds: PackedInt32Array = graph["kind"]
	var refs: PackedInt32Array = graph["ref"]
	for e: int in block:
		if kinds[e] == _EDGE_OUTPUT:
			feeding[refs[e]] = true
	if not feeding.is_empty():
		graph = _current_graph(include_loads, feeding)
		block = _hub_blocks(graph)
		kinds = graph["kind"]
		refs = graph["ref"]
	for e: int in block:
		match kinds[e]:
			_EDGE_WIRE:
				result.current_wires.append(refs[e])
			_EDGE_SWITCH:
				result.current_switch_paths.append(refs[e])
				if not result.current_components.has(_switches[refs[e]].id):
					result.current_components.append(_switches[refs[e]].id)
			_EDGE_LOAD:
				result.current_components.append(_loads[refs[e]].id)


## Edges of the current-flow graph (see [method _find_current_paths]) as
## parallel arrays "a", "b", "kind", "ref", plus "hub", "hub_edges" and
## "vertices". The inputs of the rectifiers in [param feeding] (by rectifier
## index) are edges, whatever [param include_loads] says; other rectifier
## inputs are not.
func _current_graph(include_loads: bool, feeding: Dictionary[int, bool]) -> Dictionary:
	var terminal_count: int = _terminal_index.size()
	# Virtual vertices: hub, then one per conductor bit.
	var hub: int = terminal_count
	var conductor_vertex: Dictionary[int, int] = {}
	var edge_a: PackedInt32Array = PackedInt32Array()
	var edge_b: PackedInt32Array = PackedInt32Array()
	var edge_kind: PackedInt32Array = PackedInt32Array()
	var edge_ref: PackedInt32Array = PackedInt32Array()
	var hub_edges: PackedInt32Array = PackedInt32Array()
	var add: Callable = func(a: int, b: int, kind: int, ref: int) -> void:
		edge_a.append(a)
		edge_b.append(b)
		edge_kind.append(kind)
		edge_ref.append(ref)
	# Virtual node of a conductor bit, joined to the hub when first used.
	var vertex_of: Callable = func(bit: int) -> int:
		if not conductor_vertex.has(bit):
			conductor_vertex[bit] = terminal_count + 1 + conductor_vertex.size()
			hub_edges.append(edge_a.size())
			add.call(hub, conductor_vertex[bit], _EDGE_VIRTUAL, -1)
		return conductor_vertex[bit]

	var wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in wires.size():
		if not circuit.broken_wires.has(i):
			add.call(_terminal_index[wires[i][0]], _terminal_index[wires[i][1]], _EDGE_WIRE, i)
	# Page connectors with the same label: joined like a wire, not drawn.
	for link: PackedStringArray in _links:
		add.call(_terminal_index[link[0]], _terminal_index[link[1]], _EDGE_LINK, -1)
	for i: int in _switches.size():
		if _switch_closed(i):
			add.call(_switch_terms[2 * i], _switch_terms[2 * i + 1], _EDGE_SWITCH, i)
	for i: int in _loads.size():
		var r: int = _rectifiers.find(i)
		var wanted: bool = feeding.has(r) if r >= 0 else (include_loads and _loads[i].energized)
		if wanted:
			var keys: PackedStringArray = _loads[i].get_terminal_keys()
			add.call(_terminal_index[keys[0]], _terminal_index[keys[1]], _EDGE_LOAD, i)
	for supply: PowerSupply in _supplies:
		add.call(vertex_of.call(supply.source_bit()), _terminal_index[supply.designation], _EDGE_VIRTUAL, -1)
	for r: int in _rectifiers.size():
		if _rectifier_on[r] == 1:
			var keys: PackedStringArray = _loads[_rectifiers[r]].get_terminal_keys()
			add.call(vertex_of.call(PowerSupply.BIT_DC_RECTIFIED), _terminal_index[keys[2]], _EDGE_OUTPUT, r)
			add.call(vertex_of.call(PowerSupply.BIT_DC_MINUS), _terminal_index[keys[3]], _EDGE_OUTPUT, r)
	return {"a": edge_a, "b": edge_b, "kind": edge_kind, "ref": edge_ref, "hub": hub, "hub_edges": hub_edges, "vertices": terminal_count + 1 + conductor_vertex.size()}


## Sorted ids of the edges of [param graph] that lie in a biconnected block
## with a hub edge (empty with fewer than two conductors).
func _hub_blocks(graph: Dictionary) -> PackedInt32Array:
	var edge_a: PackedInt32Array = graph["a"]
	var edge_b: PackedInt32Array = graph["b"]
	var hub_edges: PackedInt32Array = graph["hub_edges"]
	if hub_edges.size() < 2:
		return PackedInt32Array()
	var adjacency: Array[PackedInt32Array] = []
	adjacency.resize(graph["vertices"])
	for i: int in adjacency.size():
		adjacency[i] = PackedInt32Array()
	for e: int in edge_a.size():
		if edge_a[e] != edge_b[e]:
			adjacency[edge_a[e]].append_array(PackedInt32Array([edge_b[e], e]))
			adjacency[edge_b[e]].append_array(PackedInt32Array([edge_a[e], e]))
	var in_block: Dictionary[int, bool] = {}
	for hub_edge: int in hub_edges:
		if in_block.has(hub_edge):
			continue
		for e: int in _biconnected_block(adjacency, graph["hub"], hub_edge):
			in_block[e] = true
	var block: PackedInt32Array = PackedInt32Array(in_block.keys())
	block.sort()
	return block


## Edges of the biconnected component that contains [param target_edge],
## found with an iterative Tarjan search started at [param root].
## [param adjacency] holds (neighbor, edge id) pairs per vertex.
func _biconnected_block(adjacency: Array[PackedInt32Array], root: int, target_edge: int) -> PackedInt32Array:
	var vertex_count: int = adjacency.size()
	var disc: PackedInt32Array = PackedInt32Array()
	var low: PackedInt32Array = PackedInt32Array()
	disc.resize(vertex_count)
	low.resize(vertex_count)
	disc.fill(-1)
	low.fill(-1)
	var edge_stack: PackedInt32Array = PackedInt32Array()
	# Frames: vertex, edge used to enter it, next adjacency position.
	var frame_vertex: PackedInt32Array = PackedInt32Array([root])
	var frame_edge: PackedInt32Array = PackedInt32Array([-1])
	var frame_pos: PackedInt32Array = PackedInt32Array([0])
	var time: int = 0
	disc[root] = time
	low[root] = time
	time += 1

	while not frame_vertex.is_empty():
		var top: int = frame_vertex.size() - 1
		var u: int = frame_vertex[top]
		var pos: int = frame_pos[top]
		var edges: PackedInt32Array = adjacency[u]
		if pos < edges.size():
			frame_pos[top] = pos + 2
			var v: int = edges[pos]
			var e: int = edges[pos + 1]
			if e == frame_edge[top]:
				continue
			if disc[v] == -1:
				edge_stack.append(e)
				disc[v] = time
				low[v] = time
				time += 1
				frame_vertex.append(v)
				frame_edge.append(e)
				frame_pos.append(0)
			elif disc[v] < disc[u]:
				edge_stack.append(e)
				low[u] = mini(low[u], disc[v])
			continue

		var entered_by: int = frame_edge[top]
		frame_vertex.resize(top)
		frame_edge.resize(top)
		frame_pos.resize(top)
		if top == 0:
			break
		var parent: int = frame_vertex[top - 1]
		low[parent] = mini(low[parent], low[u])
		if low[u] >= disc[parent]:
			var block: PackedInt32Array = PackedInt32Array()
			var found: bool = false
			while not edge_stack.is_empty():
				var x: int = edge_stack[edge_stack.size() - 1]
				edge_stack.resize(edge_stack.size() - 1)
				block.append(x)
				if x == target_edge:
					found = true
				if x == entered_by:
					break
			if found:
				return block
	return PackedInt32Array()
