class_name Simulator
extends RefCounted
## Solves a [Circuit]: which loads have power and which contacts are operated.
## Power is traced from L through closed switching elements; a load has power
## when L reaches one terminal and N the other.
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

enum Mode { IDEAL, REALISTIC }

const DEFAULT_MAX_ITERATIONS: int = 1000
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
var _switches: Array[SwitchingElement] = []
## Two nets per switching element, in the order of [member _switches].
var _switch_nets: PackedInt32Array = PackedInt32Array()
var _loads: Array[Load] = []
## Two nets per load, in the order of [member _loads].
var _load_nets: PackedInt32Array = PackedInt32Array()
## Indices into [member _loads] of the coils, in the order they were added.
var _coil_indices: PackedInt32Array = PackedInt32Array()
var _l_supplies: Array[PowerSupply] = []
var _n_supplies: Array[PowerSupply] = []
var _short: bool = false
## Terminal index (into the current-flow graph) of every terminal key.
var _terminal_index: Dictionary[String, int] = {}
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
		if delta > 0.0:
			for i: int in _coil_indices:
				var coil: Coil = _loads[i] as Coil
				coil.advance(delta)
				coil.snap()
		time += maxf(delta, 0.0)
		last_result = _settle()
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
	for wire: PackedStringArray in circuit.get_wires():
		uf.union(index[wire[0]], index[wire[1]])

	var net_of_root: Dictionary[int, int] = {}
	_net_of_key.clear()
	for key: String in index:
		var root: int = uf.find(index[key])
		if not net_of_root.has(root):
			net_of_root[root] = net_of_root.size()
		_net_of_key[key] = net_of_root[root]
	_net_count = net_of_root.size()

	_switches.clear()
	_switch_nets.clear()
	_loads.clear()
	_load_nets.clear()
	_coil_indices.clear()
	_l_supplies.clear()
	_n_supplies.clear()
	for c: CircuitComponent in circuit.get_components():
		var keys: PackedStringArray = c.get_terminal_keys()
		if c is SwitchingElement:
			_switches.append(c as SwitchingElement)
			_switch_nets.append(_net_of_key[keys[0]])
			_switch_nets.append(_net_of_key[keys[1]])
		elif c is Load:
			if c is Coil:
				_coil_indices.append(_loads.size())
			_loads.append(c as Load)
			_load_nets.append(_net_of_key[keys[0]])
			_load_nets.append(_net_of_key[keys[1]])
		elif c is PowerSupply:
			var supply: PowerSupply = c as PowerSupply
			if supply.conductor == PowerSupply.Conductor.L:
				_l_supplies.append(supply)
			else:
				_n_supplies.append(supply)


func _settle() -> StepResult:
	var result: StepResult = StepResult.new()
	var seen: Dictionary[String, int] = {}
	var history: Array[PackedByteArray] = []
	var desired: PackedByteArray = PackedByteArray()
	var settled: bool = false

	while result.iterations < max_iterations:
		desired = _evaluate()
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
			var want: bool = desired[i] == 1
			if coil.energized != want:
				coil.set_energized(want)
				coil.snap()
				switched = true
				break
		if not switched:
			settled = true
			break

	if not settled and result.oscillating_tags.is_empty():
		# Iteration cap reached without a repeated state.
		result.oscillating_tags = _changing_tags(history)
		desired = _evaluate()

	result.stable = settled
	for i: int in _loads.size():
		if not (_loads[i] is Coil):
			_loads[i].energized = desired[i] == 1
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
	var desired: PackedByteArray = _evaluate()
	for i: int in _loads.size():
		var want: bool = desired[i] == 1
		var load: Load = _loads[i]
		if load.energized == want:
			continue
		if load is Coil:
			(load as Coil).set_energized(want)
			_note_toggle(load.designation)
		else:
			load.energized = want
	if _short and _short_since < 0.0:
		_short_since = time
		_log(result, "Short circuit: %s", [" → ".join(_find_short_path())])
	elif not _short and _short_since >= 0.0:
		_log(result, "Short circuit ended after %.1f ms", [(time - _short_since) * 1000.0])
		_short_since = -1.0
	_record_trace()


func _advance_armatures(dt: float, result: StepResult) -> void:
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


## Returns, per load, 1 if it has L on one terminal and N on the other through
## closed switching elements. Sets [member _short]; during a short every load
## is without power.
func _evaluate() -> PackedByteArray:
	var uf: UnionFind = UnionFind.new(_net_count)
	for i: int in _switches.size():
		if _switches[i].is_closed():
			uf.union(_switch_nets[2 * i], _switch_nets[2 * i + 1])

	var l_roots: Dictionary[int, bool] = {}
	for supply: PowerSupply in _l_supplies:
		l_roots[uf.find(_net_of_key[supply.designation])] = true
	var n_roots: Dictionary[int, bool] = {}
	for supply: PowerSupply in _n_supplies:
		n_roots[uf.find(_net_of_key[supply.designation])] = true

	_short = false
	for root: int in n_roots:
		if l_roots.has(root):
			_short = true
			break

	var result: PackedByteArray = PackedByteArray()
	result.resize(_loads.size())
	result.fill(0)
	if _short:
		return result
	for i: int in _loads.size():
		var a: int = uf.find(_load_nets[2 * i])
		var b: int = uf.find(_load_nets[2 * i + 1])
		if (l_roots.has(a) and n_roots.has(b)) or (l_roots.has(b) and n_roots.has(a)):
			result[i] = 1
	return result


## One byte per coil: bit 0 coil power, bit 1 timed output.
func _signature() -> PackedByteArray:
	var sig: PackedByteArray = PackedByteArray()
	for i: int in _coil_indices:
		var coil: Coil = _loads[i] as Coil
		var b: int = 1 if coil.energized else 0
		if coil is TimerRelay and (coil as TimerRelay).output:
			b |= 2
		sig.append(b)
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


## Shortest chain of closed switching elements from an L supply to an N supply:
## [L designation, element ids..., N designation].
func _find_short_path() -> PackedStringArray:
	var adjacency: Array[PackedInt32Array] = []
	adjacency.resize(_net_count)
	for n: int in _net_count:
		adjacency[n] = PackedInt32Array()
	for i: int in _switches.size():
		if _switches[i].is_closed():
			var a: int = _switch_nets[2 * i]
			var b: int = _switch_nets[2 * i + 1]
			adjacency[a].append_array(PackedInt32Array([i, b]))
			adjacency[b].append_array(PackedInt32Array([i, a]))

	var n_supply_of_net: Dictionary[int, PowerSupply] = {}
	for supply: PowerSupply in _n_supplies:
		n_supply_of_net[_net_of_key[supply.designation]] = supply

	var prev_net: PackedInt32Array = PackedInt32Array()
	var prev_switch: PackedInt32Array = PackedInt32Array()
	prev_net.resize(_net_count)
	prev_switch.resize(_net_count)
	prev_net.fill(-2)
	prev_switch.fill(-1)
	var start_supply: Dictionary[int, PowerSupply] = {}
	var queue: PackedInt32Array = PackedInt32Array()
	for supply: PowerSupply in _l_supplies:
		var net: int = _net_of_key[supply.designation]
		if prev_net[net] == -2:
			prev_net[net] = -1
			start_supply[net] = supply
			queue.append(net)

	var head: int = 0
	while head < queue.size():
		var net: int = queue[head]
		head += 1
		if n_supply_of_net.has(net):
			var middle: PackedStringArray = PackedStringArray()
			var cursor: int = net
			while prev_net[cursor] != -1:
				middle.append(_switches[prev_switch[cursor]].id)
				cursor = prev_net[cursor]
			middle.reverse()
			var path: PackedStringArray = PackedStringArray([start_supply[cursor].designation])
			path.append_array(middle)
			path.append(n_supply_of_net[net].designation)
			return path
		var edges: PackedInt32Array = adjacency[net]
		for e: int in range(0, edges.size(), 2):
			var other: int = edges[e + 1]
			if prev_net[other] == -2:
				prev_net[other] = net
				prev_switch[other] = edges[e]
				queue.append(other)
	return PackedStringArray()


## Fills the L and N reach of [StepResult]: everything joined to an L (or N)
## supply by wires and closed switching elements, whether or not current
## flows there. Loads do not pass L or N on. During a short a part reached by
## both counts as L.
func _find_live_parts(result: StepResult) -> void:
	var uf: UnionFind = UnionFind.new(_net_count)
	for i: int in _switches.size():
		if _switches[i].is_closed():
			uf.union(_switch_nets[2 * i], _switch_nets[2 * i + 1])
	var l_roots: Dictionary[int, bool] = {}
	for supply: PowerSupply in _l_supplies:
		l_roots[uf.find(_net_of_key[supply.designation])] = true
	var n_roots: Dictionary[int, bool] = {}
	for supply: PowerSupply in _n_supplies:
		n_roots[uf.find(_net_of_key[supply.designation])] = true
	for key: String in _net_of_key:
		var root: int = uf.find(_net_of_key[key])
		if l_roots.has(root):
			result.live_terminals.append(key)
		elif n_roots.has(root):
			result.neutral_terminals.append(key)
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in wires.size():
		var root: int = uf.find(_net_of_key[wires[i][0]])
		if l_roots.has(root):
			result.live_wires.append(i)
		elif n_roots.has(root):
			result.neutral_wires.append(i)


## Fills [member StepResult.current_wires] and [member StepResult.current_components].
##
## Graph: terminals are vertices; wires, closed switching elements and energized
## loads are edges. A virtual source edge joins all L supplies to all N supplies.
## A wire or element carries current exactly when it lies on a simple cycle
## through the source edge, i.e. in the same biconnected component. Dead-end
## branches and loops hanging off a single point stay dark. During a short the
## loads are off, so the result is the fault-current path.
func _find_current_paths(result: StepResult) -> void:
	if _l_supplies.is_empty() or _n_supplies.is_empty():
		return
	const WIRE := 0
	const SWITCH := 1
	const LOAD := 2
	const VIRTUAL := 3
	var terminal_count: int = _terminal_index.size()
	var v_l: int = terminal_count
	var v_n: int = terminal_count + 1
	# Edges as parallel arrays indexed by edge id.
	var edge_a: PackedInt32Array = PackedInt32Array()
	var edge_b: PackedInt32Array = PackedInt32Array()
	var edge_kind: PackedInt32Array = PackedInt32Array()
	var edge_ref: PackedInt32Array = PackedInt32Array()

	var wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in wires.size():
		edge_a.append(_terminal_index[wires[i][0]])
		edge_b.append(_terminal_index[wires[i][1]])
		edge_kind.append(WIRE)
		edge_ref.append(i)
	for i: int in _switches.size():
		if _switches[i].is_closed():
			var keys: PackedStringArray = _switches[i].get_terminal_keys()
			edge_a.append(_terminal_index[keys[0]])
			edge_b.append(_terminal_index[keys[1]])
			edge_kind.append(SWITCH)
			edge_ref.append(i)
	for i: int in _loads.size():
		if _loads[i].energized:
			var keys: PackedStringArray = _loads[i].get_terminal_keys()
			edge_a.append(_terminal_index[keys[0]])
			edge_b.append(_terminal_index[keys[1]])
			edge_kind.append(LOAD)
			edge_ref.append(i)
	for supply: PowerSupply in _l_supplies + _n_supplies:
		edge_a.append(v_l if supply.conductor == PowerSupply.Conductor.L else v_n)
		edge_b.append(_terminal_index[supply.designation])
		edge_kind.append(VIRTUAL)
		edge_ref.append(-1)
	var source_edge: int = edge_a.size()
	edge_a.append(v_l)
	edge_b.append(v_n)
	edge_kind.append(VIRTUAL)
	edge_ref.append(-1)

	var adjacency: Array[PackedInt32Array] = []
	adjacency.resize(terminal_count + 2)
	for i: int in adjacency.size():
		adjacency[i] = PackedInt32Array()
	for e: int in edge_a.size():
		if edge_a[e] != edge_b[e]:
			adjacency[edge_a[e]].append_array(PackedInt32Array([edge_b[e], e]))
			adjacency[edge_b[e]].append_array(PackedInt32Array([edge_a[e], e]))

	var block: PackedInt32Array = _biconnected_block(adjacency, v_l, source_edge)
	block.sort()
	for e: int in block:
		match edge_kind[e]:
			WIRE:
				result.current_wires.append(edge_ref[e])
			SWITCH:
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
