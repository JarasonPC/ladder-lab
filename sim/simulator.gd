class_name Simulator
extends RefCounted
## Solves a [Circuit]: which loads have power and which contacts are operated.
##
## Each [method step] advances the timers by the given time, then settles the
## circuit: power is traced from L through closed switching elements, the coils
## that should change are found and the first one (in the order components were
## added) is switched, which may move its contacts. This repeats until nothing
## wants to change. Switching one coil at a time models the fact that real relays
## never operate at exactly the same instant, so races have a defined winner.
##
## A circuit state seen twice while settling is an oscillation (e.g. a relay
## whose own NC contact feeds its coil); it is reported in [StepResult] instead
## of looping. [member max_iterations] is a hard cap on top of that.

const DEFAULT_MAX_ITERATIONS: int = 1000

var circuit: Circuit
var max_iterations: int = DEFAULT_MAX_ITERATIONS
var last_result: StepResult = StepResult.new()

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
var _l_rails: Array[PowerRail] = []
var _n_rails: Array[PowerRail] = []
var _short: bool = false


func _init(p_circuit: Circuit) -> void:
	circuit = p_circuit


## Advances timers by [param delta] seconds, then settles the circuit.
func step(delta: float = 0.0) -> StepResult:
	_ensure_built()
	if delta > 0.0:
		for i: int in _coil_indices:
			(_loads[i] as Coil).advance(delta)
	last_result = _settle()
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
	_l_rails.clear()
	_n_rails.clear()
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
		elif c is PowerRail:
			var rail: PowerRail = c as PowerRail
			if rail.conductor == PowerRail.Conductor.L:
				_l_rails.append(rail)
			else:
				_n_rails.append(rail)


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
	result.short_circuit = _short
	if _short:
		result.short_circuit_path = _find_short_path()
	return result


## Returns, per load, 1 if it has L on one terminal and N on the other through
## closed switching elements. Sets [member _short]; during a short every load
## is without power.
func _evaluate() -> PackedByteArray:
	var uf: UnionFind = UnionFind.new(_net_count)
	for i: int in _switches.size():
		if _switches[i].is_closed():
			uf.union(_switch_nets[2 * i], _switch_nets[2 * i + 1])

	var l_roots: Dictionary[int, bool] = {}
	for rail: PowerRail in _l_rails:
		l_roots[uf.find(_net_of_key[rail.designation])] = true
	var n_roots: Dictionary[int, bool] = {}
	for rail: PowerRail in _n_rails:
		n_roots[uf.find(_net_of_key[rail.designation])] = true

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


## Shortest chain of closed switching elements from an L rail to an N rail:
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

	var n_rail_of_net: Dictionary[int, PowerRail] = {}
	for rail: PowerRail in _n_rails:
		n_rail_of_net[_net_of_key[rail.designation]] = rail

	var prev_net: PackedInt32Array = PackedInt32Array()
	var prev_switch: PackedInt32Array = PackedInt32Array()
	prev_net.resize(_net_count)
	prev_switch.resize(_net_count)
	prev_net.fill(-2)
	prev_switch.fill(-1)
	var start_rail: Dictionary[int, PowerRail] = {}
	var queue: PackedInt32Array = PackedInt32Array()
	for rail: PowerRail in _l_rails:
		var net: int = _net_of_key[rail.designation]
		if prev_net[net] == -2:
			prev_net[net] = -1
			start_rail[net] = rail
			queue.append(net)

	var head: int = 0
	while head < queue.size():
		var net: int = queue[head]
		head += 1
		if n_rail_of_net.has(net):
			var middle: PackedStringArray = PackedStringArray()
			var cursor: int = net
			while prev_net[cursor] != -1:
				middle.append(_switches[prev_switch[cursor]].id)
				cursor = prev_net[cursor]
			middle.reverse()
			var path: PackedStringArray = PackedStringArray([start_rail[cursor].designation])
			path.append_array(middle)
			path.append(n_rail_of_net[net].designation)
			return path
		var edges: PackedInt32Array = adjacency[net]
		for e: int in range(0, edges.size(), 2):
			var other: int = edges[e + 1]
			if prev_net[other] == -2:
				prev_net[other] = net
				prev_switch[other] = edges[e]
				queue.append(other)
	return PackedStringArray()
