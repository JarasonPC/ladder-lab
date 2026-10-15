class_name Simulator
extends RefCounted
## Solves a [Circuit]: which loads have power and which contacts are operated.
## Each supply is a phase (L or L1, L2, L3) or N. Wires and closed switching
## paths join nets into groups; a group reached by two different supplies is a
## short circuit. A two-terminal load has power when its terminals are reached
## by two different supplies (phase and N, or two phases). A
## [ThreePhaseMotor] runs when its windings get all three phases.
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
## Indices into [member _loads] of the coils, in the order they were added.
var _coil_indices: PackedInt32Array = PackedInt32Array()
## Actuators of push buttons and switches (one per device).
var _actuators: Array[Armature] = []
var _overload_relays: Array[OverloadRelay] = []
## Parts with a protection state (fuses, breakers, overload relays).
var _protective: Array[CircuitComponent] = []
var _supplies: Array[PowerSupply] = []
var _motors: Array[ThreePhaseMotor] = []
## Nine nets per motor (-1 where it has no such terminal).
var _motor_nets: PackedInt32Array = PackedInt32Array()
## Last evaluation: motor state and direction, overcurrent per overload relay.
var _motor_states: PackedInt32Array = PackedInt32Array()
var _motor_directions: PackedInt32Array = PackedInt32Array()
var _motor_speeds: PackedInt32Array = PackedInt32Array()
var _relay_overcurrent: PackedByteArray = PackedByteArray()
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
			_advance_overloads(delta, result)
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
	for c: CircuitComponent in circuit.get_components():
		for key: String in c.get_terminal_keys():
			index[key] = index.size()
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

	_switches.clear()
	_switch_paths.clear()
	_switch_nets.clear()
	_switch_terms.clear()
	_loads.clear()
	_load_nets.clear()
	_control_nets.clear()
	_coil_indices.clear()
	_supplies.clear()
	_actuators.clear()
	_overload_relays.clear()
	_protective.clear()
	_motors.clear()
	_motor_nets.clear()
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
		for p: int in paths.size():
			_add_switch_path(c, p, keys[paths[p].x], keys[paths[p].y])
		if not paths.is_empty():
			continue
		if c is ThreePhaseMotor:
			_motors.append(c as ThreePhaseMotor)
			var windings: int = (c as ThreePhaseMotor).winding_terminal_count()
			for t: int in MOTOR_TERMINALS:
				_motor_nets.append(_net_of_key[keys[t]] if t < windings else -1)
		elif c is Load:
			if c is Coil:
				_coil_indices.append(_loads.size())
			_loads.append(c as Load)
			if c is TimerRelay and (c as TimerRelay).control_input and keys.size() > 2:
				_control_nets[_loads.size() - 1] = _net_of_key[keys[2]]
			_load_nets.append(_net_of_key[keys[0]])
			_load_nets.append(_net_of_key[keys[1]])
		elif c is PowerSupply:
			_supplies.append(c as PowerSupply)
	_motor_states.resize(_motors.size())
	_motor_directions.resize(_motors.size())
	_motor_speeds.resize(_motors.size())
	_relay_overcurrent.resize(_overload_relays.size())


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


## Supply bits reaching each group root.
func _root_masks(uf: UnionFind) -> Dictionary[int, int]:
	var masks: Dictionary[int, int] = {}
	for supply: PowerSupply in _supplies:
		var root: int = uf.find(_net_of_key[supply.designation])
		masks[root] = masks.get(root, 0) | supply.source_bit()
	return masks


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
		if not (_loads[i] is Coil):
			_loads[i].energized = (desired[i] & 1) == 1
	for m: int in _motors.size():
		var motor: ThreePhaseMotor = _motors[m]
		var new_state: ThreePhaseMotor.State = _motor_states[m] as ThreePhaseMotor.State
		if new_state != motor.state:
			if new_state == ThreePhaseMotor.State.PHASE_LOSS:
				_log(result, "%s: phase loss", [motor.designation])
			elif new_state == ThreePhaseMotor.State.MISWIRED:
				_log(result, "%s: windings wrongly connected", [motor.designation])
			elif motor.is_running() and new_state == ThreePhaseMotor.State.STOPPED:
				_log(result, "%s stopped", [motor.designation])
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
	for r: int in _overload_relays.size():
		_overload_relays[r].motor_overcurrent = _relay_overcurrent[r] == 1


func _settle(result: StepResult) -> StepResult:
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
			settled = true
			break

	if not settled and result.oscillating_tags.is_empty():
		# Iteration cap reached without a repeated state.
		result.oscillating_tags = _changing_tags(history)
		desired = _evaluate_protected(result)

	result.stable = settled
	_apply_outputs(desired, result)
	_finish(result)
	return result


func _finish(result: StepResult) -> void:
	result.short_circuit = _short
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
		for actuator: Armature in _actuators:
			dt = minf(dt, actuator.time_to_next_event())
		for relay: OverloadRelay in _overload_relays:
			dt = minf(dt, relay.time_to_trip())
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
	var desired: PackedByteArray = _evaluate_protected(result)
	for i: int in _coil_indices:
		var coil: Coil = _loads[i] as Coil
		var want: bool = (desired[i] & 1) == 1
		if coil.energized != want:
			coil.set_energized(want)
			_note_toggle(coil.designation)
		if _control_nets.has(i):
			(coil as TimerRelay).set_control((desired[i] & 2) != 0)
	_apply_outputs(desired, result)
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
	_advance_overloads(dt, result)
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


func _advance_overloads(dt: float, result: StepResult) -> void:
	for relay: OverloadRelay in _overload_relays:
		if relay.advance(dt):
			_log(result, "%s tripped (overload)", [relay.designation], time + dt)


## [method _evaluate], but first lets every fuse or breaker that carries the
## fault current of a short circuit trip.
func _evaluate_protected(result: StepResult) -> PackedByteArray:
	var desired: PackedByteArray = _evaluate()
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
	for motor: ThreePhaseMotor in _motors:
		trace.record(motor.designation, time, 1.0 if motor.is_running() else 0.0)


## Returns, per load, 1 if its terminals are reached by two different supplies
## (phase and N, or two phases) through closed switching paths, and works out
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
	_relay_overcurrent.fill(0)
	if _short:
		return result
	for i: int in _loads.size():
		var a: int = masks.get(uf.find(_load_nets[2 * i]), 0)
		var b: int = masks.get(uf.find(_load_nets[2 * i + 1]), 0)
		if _is_single_source(a) and _is_single_source(b) and a != b:
			result[i] = 1
		if _loads[i] is Coil and (_loads[i] as Coil).fault == Coil.Fault.OPEN:
			# A broken winding has voltage but draws no current.
			result[i] = 0
		if _control_nets.has(i):
			# Control input S: pressed when it has voltage against A2 (bit 1).
			var s: int = masks.get(uf.find(_control_nets[i]), 0)
			if _is_single_source(s) and _is_single_source(b) and s != b:
				result[i] |= 2
	_evaluate_motors(uf, masks)
	return result


func _evaluate_motors(uf: UnionFind, masks: Dictionary[int, int]) -> void:
	const PHASE_BITS: int = PowerSupply.BIT_L1 | PowerSupply.BIT_L2 | PowerSupply.BIT_L3
	# Group roots of the terminals of motors drawing overcurrent.
	var hot_roots: Dictionary[int, bool] = {}
	for m: int in _motors.size():
		var motor: ThreePhaseMotor = _motors[m]
		var phases: PackedInt32Array = PackedInt32Array()
		var roots: PackedInt32Array = PackedInt32Array()
		for t: int in MOTOR_TERMINALS:
			var net: int = _motor_nets[MOTOR_TERMINALS * m + t]
			roots.append(uf.find(net) if net >= 0 else -1)
			phases.append(_phase_of(masks.get(roots[t], 0)) if net >= 0 else 0)
		# For each group of three terminals: joined in a point with no phase on it?
		var star_points: Array[bool] = []
		for g: int in 3:
			var root: int = roots[3 * g]
			star_points.append(root >= 0 and root == roots[3 * g + 1] and root == roots[3 * g + 2] and (masks.get(root, 0) & PHASE_BITS) == 0)
		var outcome: Array = ThreePhaseMotor.evaluate(motor.kind, phases, star_points)
		_motor_states[m] = outcome[0]
		_motor_directions[m] = outcome[1]
		_motor_speeds[m] = outcome[2]
		var state: ThreePhaseMotor.State = outcome[0]
		var running: bool = state == ThreePhaseMotor.State.RUNNING or state == ThreePhaseMotor.State.STAR or state == ThreePhaseMotor.State.DELTA
		if state == ThreePhaseMotor.State.PHASE_LOSS or state == ThreePhaseMotor.State.MISWIRED or (motor.overloaded and running):
			for root: int in roots:
				if root >= 0:
					hot_roots[root] = true
	# An overload relay heats when one of its heaters carries such a motor's current.
	for r: int in _overload_relays.size():
		var relay: OverloadRelay = _overload_relays[r]
		if relay.poles != 3:
			continue
		var keys: PackedStringArray = relay.get_terminal_keys()
		for k: String in keys:
			if hot_roots.has(uf.find(_net_of_key[k])):
				_relay_overcurrent[r] = 1
				break


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
	for device: CircuitComponent in _protective:
		sig.append(device.protection_state())
	return sig


## Designations of coils whose state differs anywhere in [param states].
func _changing_tags(states: Array[PackedByteArray]) -> PackedStringArray:
	var tags: PackedStringArray = PackedStringArray()
	if states.is_empty():
		return tags
	for j: int in _coil_indices.size():
		for s: PackedByteArray in states:
			if s[j] != states[0][j]:
				tags.append(_loads[_coil_indices[j]].designation)
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
	var bits: Array[int] = []
	for supply: PowerSupply in _supplies:
		if not bits.has(supply.source_bit()):
			bits.append(supply.source_bit())
	bits.sort()
	for bit: int in bits:
		var path: PackedStringArray = _short_path_from(bit, adjacency)
		if not path.is_empty():
			return path
	return PackedStringArray()


func _short_path_from(bit: int, adjacency: Array[PackedInt32Array]) -> PackedStringArray:
	var target_of_net: Dictionary[int, PowerSupply] = {}
	for supply: PowerSupply in _supplies:
		if supply.source_bit() != bit:
			target_of_net[_net_of_key[supply.designation]] = supply
	var prev_net: PackedInt32Array = PackedInt32Array()
	var prev_switch: PackedInt32Array = PackedInt32Array()
	prev_net.resize(_net_count)
	prev_switch.resize(_net_count)
	prev_net.fill(-2)
	prev_switch.fill(-1)
	var start_supply: Dictionary[int, PowerSupply] = {}
	var queue: PackedInt32Array = PackedInt32Array()
	for supply: PowerSupply in _supplies:
		if supply.source_bit() != bit:
			continue
		var net: int = _net_of_key[supply.designation]
		if prev_net[net] == -2:
			prev_net[net] = -1
			start_supply[net] = supply
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
			var path: PackedStringArray = PackedStringArray([start_supply[cursor].designation])
			path.append_array(middle)
			path.append(target_of_net[net].designation)
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
	for key: String in _net_of_key:
		var code: int = code_of_root.get(uf.find(_net_of_key[key]), 0)
		if code == 0:
			continue
		result.terminal_reach[key] = code
		if code == StepResult.REACH_N:
			result.neutral_terminals.append(key)
		else:
			result.live_terminals.append(key)
	var wires: Array[PackedStringArray] = circuit.get_wires()
	result.wire_reach.resize(wires.size())
	result.wire_reach.fill(0)
	for i: int in wires.size():
		var code_a: int = code_of_root.get(uf.find(_net_of_key[wires[i][0]]), 0)
		var code_b: int = code_of_root.get(uf.find(_net_of_key[wires[i][1]]), 0)
		var code: int = code_a if code_a != 0 and code_a != StepResult.REACH_N else (code_b if code_b != 0 else code_a)
		result.wire_reach[i] = code
		if code == StepResult.REACH_N:
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
func _find_current_paths(result: StepResult, include_loads: bool = true) -> void:
	if _supplies.is_empty():
		return
	const WIRE := 0
	const SWITCH := 1
	const LOAD := 2
	const VIRTUAL := 3
	const LINK := 4
	var terminal_count: int = _terminal_index.size()
	# Virtual vertices: hub, then one per conductor bit (1, 2, 4, 8).
	var hub: int = terminal_count
	var conductor_vertex: Dictionary[int, int] = {}
	# Edges as parallel arrays indexed by edge id.
	var edge_a: PackedInt32Array = PackedInt32Array()
	var edge_b: PackedInt32Array = PackedInt32Array()
	var edge_kind: PackedInt32Array = PackedInt32Array()
	var edge_ref: PackedInt32Array = PackedInt32Array()

	var wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in wires.size():
		if circuit.broken_wires.has(i):
			continue
		edge_a.append(_terminal_index[wires[i][0]])
		edge_b.append(_terminal_index[wires[i][1]])
		edge_kind.append(WIRE)
		edge_ref.append(i)
	for link: PackedStringArray in _links:
		edge_a.append(_terminal_index[link[0]])
		edge_b.append(_terminal_index[link[1]])
		edge_kind.append(LINK)
		edge_ref.append(-1)
	for i: int in _switches.size():
		if _switch_closed(i):
			edge_a.append(_switch_terms[2 * i])
			edge_b.append(_switch_terms[2 * i + 1])
			edge_kind.append(SWITCH)
			edge_ref.append(i)
	for i: int in _loads.size():
		if include_loads and _loads[i].energized:
			var keys: PackedStringArray = _loads[i].get_terminal_keys()
			edge_a.append(_terminal_index[keys[0]])
			edge_b.append(_terminal_index[keys[1]])
			edge_kind.append(LOAD)
			edge_ref.append(i)
	var hub_edges: PackedInt32Array = PackedInt32Array()
	for supply: PowerSupply in _supplies:
		var bit: int = supply.source_bit()
		if not conductor_vertex.has(bit):
			conductor_vertex[bit] = terminal_count + 1 + conductor_vertex.size()
			hub_edges.append(edge_a.size())
			edge_a.append(hub)
			edge_b.append(conductor_vertex[bit])
			edge_kind.append(VIRTUAL)
			edge_ref.append(-1)
		edge_a.append(conductor_vertex[bit])
		edge_b.append(_terminal_index[supply.designation])
		edge_kind.append(VIRTUAL)
		edge_ref.append(-1)
	if hub_edges.size() < 2:
		return

	var adjacency: Array[PackedInt32Array] = []
	adjacency.resize(terminal_count + 1 + conductor_vertex.size())
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
		for e: int in _biconnected_block(adjacency, hub, hub_edge):
			in_block[e] = true
	var block: PackedInt32Array = PackedInt32Array(in_block.keys())
	block.sort()
	for e: int in block:
		match edge_kind[e]:
			WIRE:
				result.current_wires.append(edge_ref[e])
			SWITCH:
				result.current_switch_paths.append(edge_ref[e])
				if not result.current_components.has(_switches[edge_ref[e]].id):
					result.current_components.append(_switches[edge_ref[e]].id)
			LOAD:
				result.current_components.append(_loads[edge_ref[e]].id)


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
