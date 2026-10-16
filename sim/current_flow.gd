class_name CurrentFlow
extends RefCounted
## Spreads the currents the loads draw over the circuit: what flows in every
## wire and through every closed switching path.
##
## Loads are taken as current sources (they draw what they draw whatever the
## wiring) and the supplies as ideal voltage sources, so for the current
## distribution every net with a supply point is one node at fixed potential
## (the supplies shorted, superposition). The other nets are nodes joined by
## the closed switching paths, each with the same small resistance: parallel
## paths share the current. Wires are ideal; within a net the current runs
## along a tree of its wires (a wire closing a loop inside one net carries
## nothing), and what the net's loads and paths do not balance comes from its
## supply point.

var _terminal_count: int = 0
var _net_count: int = 0
var _net_of: PackedInt32Array = PackedInt32Array()
var _wire_count: int = 0
## Terminals in tree order (each after its parent), with the parent terminal
## (-1 for a root) and the wire to it (-1 for a page link).
var _order: PackedInt32Array = PackedInt32Array()
var _parent: PackedInt32Array = PackedInt32Array()
var _parent_wire: PackedInt32Array = PackedInt32Array()

## Results of [method solve]: current into the part at each terminal
## (phasors, amperes), magnitude per wire, current through each closed path
## given (from its first terminal to the second).
var terminal_currents: PackedVector2Array = PackedVector2Array()
var wire_currents: PackedFloat32Array = PackedFloat32Array()
var path_currents: PackedVector2Array = PackedVector2Array()


## [param net_of]: net of every terminal; [param edges]: terminal pairs joined
## by wires and page links, [param edge_wires] the wire index of each (-1 for a link).
func setup(net_of: PackedInt32Array, net_count: int, edges: PackedInt32Array, edge_wires: PackedInt32Array, wire_count: int) -> void:
	_terminal_count = net_of.size()
	_net_of = net_of
	_net_count = net_count
	_wire_count = wire_count
	var adjacency: Array[PackedInt32Array] = []
	adjacency.resize(_terminal_count)
	for t: int in _terminal_count:
		adjacency[t] = PackedInt32Array()
	for e: int in edge_wires.size():
		var a: int = edges[2 * e]
		var b: int = edges[2 * e + 1]
		if a == b:
			continue
		adjacency[a].append_array(PackedInt32Array([b, edge_wires[e]]))
		adjacency[b].append_array(PackedInt32Array([a, edge_wires[e]]))
	_order.clear()
	_parent.resize(_terminal_count)
	_parent.fill(-2)
	_parent_wire.resize(_terminal_count)
	_parent_wire.fill(-1)
	for root: int in _terminal_count:
		if _parent[root] != -2:
			continue
		_parent[root] = -1
		var head: int = _order.size()
		_order.append(root)
		while head < _order.size():
			var t: int = _order[head]
			head += 1
			var next: PackedInt32Array = adjacency[t]
			for i: int in range(0, next.size(), 2):
				var u: int = next[i]
				if _parent[u] == -2:
					_parent[u] = t
					_parent_wire[u] = next[i + 1]
					_order.append(u)


## Solves for [param draws] (current drawn by the parts at each terminal) with
## the closed switching paths [param paths] (terminal pairs). Terminals in
## [param sources] (supply points, outputs of working rectifiers) feed their
## nets, which are held at fixed potential.
func solve(draws: PackedVector2Array, paths: PackedInt32Array, sources: PackedInt32Array) -> void:
	var path_count: int = paths.size() / 2
	var ground: PackedByteArray = PackedByteArray()
	ground.resize(_net_count)
	for t: int in sources:
		ground[_net_of[t]] = 1
	var injection: PackedVector2Array = PackedVector2Array()
	injection.resize(_net_count)
	for t: int in _terminal_count:
		if draws[t] != Vector2.ZERO:
			injection[_net_of[t]] += draws[t]
	# Groups of free nets joined by paths.
	var uf: UnionFind = UnionFind.new(_net_count)
	var touching: Array[PackedInt32Array] = []
	touching.resize(_net_count)
	for n: int in _net_count:
		touching[n] = PackedInt32Array()
	for p: int in path_count:
		var a: int = _net_of[paths[2 * p]]
		var b: int = _net_of[paths[2 * p + 1]]
		if a == b:
			continue
		touching[a].append(p)
		touching[b].append(p)
		if ground[a] == 0 and ground[b] == 0:
			uf.union(a, b)
	var members: Dictionary[int, PackedInt32Array] = {}
	for n: int in _net_count:
		if ground[n] == 0 and not touching[n].is_empty():
			var root: int = uf.find(n)
			if not members.has(root):
				members[root] = PackedInt32Array()
			members[root].append(n)
	var potential: PackedVector2Array = PackedVector2Array()
	potential.resize(_net_count)
	for root: int in members:
		var nets: PackedInt32Array = members[root]
		var loaded: bool = false
		for n: int in nets:
			if injection[n] != Vector2.ZERO:
				loaded = true
				break
		if not loaded:
			continue
		var count: int = nets.size()
		var index: Dictionary[int, int] = {}
		for i: int in count:
			index[nets[i]] = i
		var m: PackedVector2Array = PackedVector2Array()
		m.resize(count * count)
		var rhs: PackedVector2Array = PackedVector2Array()
		rhs.resize(count)
		var grounded: bool = false
		for i: int in count:
			var n: int = nets[i]
			rhs[i] = -injection[n]
			for p: int in touching[n]:
				var a: int = _net_of[paths[2 * p]]
				var other: int = _net_of[paths[2 * p + 1]] if a == n else a
				m[i * count + i] += Phasor.ONE
				if ground[other] == 1:
					grounded = true
				else:
					m[i * count + index[other]] -= Phasor.ONE
		if not grounded:
			# Joined to no supply (e.g. a star bridge): only differences count.
			for c: int in count:
				m[c] = Vector2.ZERO
			m[0] = Phasor.ONE
			rhs[0] = Vector2.ZERO
		var solved: PackedVector2Array = Phasor.solve(m, rhs)
		for i: int in count:
			potential[nets[i]] = solved[i]
	terminal_currents = draws.duplicate()
	path_currents.resize(path_count)
	for p: int in path_count:
		var ta: int = paths[2 * p]
		var tb: int = paths[2 * p + 1]
		var i: Vector2 = potential[_net_of[ta]] - potential[_net_of[tb]]
		path_currents[p] = i
		terminal_currents[ta] += i
		terminal_currents[tb] -= i
	# What a net does not balance comes from its supply point.
	var balance: PackedVector2Array = PackedVector2Array()
	balance.resize(_net_count)
	for t: int in _terminal_count:
		balance[_net_of[t]] += terminal_currents[t]
	var fed: PackedByteArray = PackedByteArray()
	fed.resize(_net_count)
	for t: int in sources:
		var n: int = _net_of[t]
		if fed[n] == 0:
			fed[n] = 1
			terminal_currents[t] -= balance[n]
	# Along the wires: each wire carries what the terminals beyond it take.
	wire_currents.resize(_wire_count)
	wire_currents.fill(0.0)
	var subtree: PackedVector2Array = terminal_currents.duplicate()
	for k: int in range(_order.size() - 1, 0, -1):
		var t: int = _order[k]
		var parent: int = _parent[t]
		if parent < 0:
			continue
		subtree[parent] += subtree[t]
		if _parent_wire[t] >= 0:
			wire_currents[_parent_wire[t]] = subtree[t].length()
