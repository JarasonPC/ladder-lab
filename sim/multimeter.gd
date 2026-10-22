class_name Multimeter
extends RefCounted
## A multimeter on a simulated circuit: the voltage between two terminals,
## or the resistance between them. A voltmeter of [constant METER_OHMS] sees
## a supply through the loads (across an open contact in series with a
## coil the supply's voltage); an ohmmeter measures through the loads and
## the closed contacts and refuses where there is voltage. The loads are
## taken as plain resistances (coils, lamps, motor windings, see
## [method ohms_of]); AC supplies as phasors (L1 L2 L3 230 V apart by 120°,
## N and PE 0), DC supplies by their voltage against their - pole. No nodes.

## The voltmeter's own resistance.
const METER_OHMS: float = 1.0e7
## Resistances the loads are taken as.
const COIL_OHMS: float = 800.0
const LAMP_OHMS: float = 1500.0
const ELECTRONICS_OHMS: float = 5000.0
const LOAD_OHMS: float = 100.0
const WINDING_OHMS: float = 12.0
## Below this many volts an ohmmeter measures.
const LIVE_VOLTS: float = 1.0
## What reaches each node of a nearly floating net (siemens), so the
## equations always have a solution.
const LEAK: float = 1.0e-12


## Resistance of [param load] (INF: it does not conduct, a broken coil or
## a burnt-out part).
static func ohms_of(load: Load) -> float:
	if load.burnt or (load is Coil and (load as Coil).fault == Coil.Fault.OPEN):
		return INF
	if load is Coil:
		return COIL_OHMS
	if load is Lamp:
		return LAMP_OHMS
	if load is Plc or load is ProximitySensor or load is AnalogSensor or load is NetworkSwitch or load is Rectifier:
		return ELECTRONICS_OHMS
	return LOAD_OHMS


## The voltage between terminals [param a] and [param b] of [param sim]'s
## circuit ("" or a terminal it has not: the probe touches nothing):
## {"volts" (RMS for AC), "dc" (true for a DC voltage)}.
static func volts(sim: Simulator, a: String, b: String) -> Dictionary:
	var network: Dictionary = sim.meter_network()
	var group: PackedInt32Array = network["group"]
	var bits: Dictionary[int, int] = network["bits"]
	var na: int = sim.get_net_of(a)
	var nb: int = sim.get_net_of(b)
	if na < 0 or nb < 0:
		return {"volts": 0.0, "dc": false}
	var pa: int = group[na]
	var pb: int = group[nb]
	if pa == pb:
		return {"volts": 0.0, "dc": _kinds(bits.get(pa, 0)) == 2}
	# The nodes a probe reaches through the loads, up to the supplies.
	var edges: Array = network["loads"].duplicate()
	edges.append(Vector3(pa, pb, METER_OHMS))
	var nodes: Array[int] = _reached([pa, pb], edges, bits)
	var kinds: int = 0
	for node: int in nodes:
		kinds |= _kinds(bits.get(node, 0))
	if bits.has(pa) and bits.has(pb) and _kinds(bits[pa]) | _kinds(bits[pb]) == 3:
		# A mains conductor and a DC pole: two separate circuits.
		return {"volts": 0.0, "dc": false}
	var fixed: Dictionary[int, Vector2] = {}
	for node: int in nodes:
		if bits.has(node):
			fixed[node] = _potential(bits[node])
	var potentials: Dictionary[int, Vector2] = _solve(nodes, edges, fixed, {})
	return {"volts": (potentials[pa] - potentials[pb]).length(), "dc": kinds == 2}


## The resistance between terminals [param a] and [param b] (ohms, INF for
## none): -1 where there is voltage between them.
static func ohms(sim: Simulator, a: String, b: String) -> float:
	if volts(sim, a, b)["volts"] >= LIVE_VOLTS:
		return -1.0
	var network: Dictionary = sim.meter_network()
	var group: PackedInt32Array = network["group"]
	var na: int = sim.get_net_of(a)
	var nb: int = sim.get_net_of(b)
	if na < 0 or nb < 0:
		return INF
	var pa: int = group[na]
	var pb: int = group[nb]
	if pa == pb:
		return 0.0
	var edges: Array = network["loads"]
	var nodes: Array[int] = _reached([pa], edges, {})
	if not nodes.has(pb):
		return INF
	# One ampere into a, out at b: the voltage of a is the resistance.
	var potentials: Dictionary[int, Vector2] = _solve(nodes, edges, {pb: Vector2.ZERO}, {pa: Vector2(1.0, 0.0)})
	return potentials[pa].x


## A reading as the meter shows it: "230 V ~", "24.0 V ⎓", "812 Ω", "OL";
## [param reading] a voltage of [method volts] or ohms of [method ohms].
static func text(reading: Variant) -> String:
	if reading is Dictionary:
		var v: float = reading["volts"]
		return "%s V %s" % [_digits(v), "⎓" if reading["dc"] else "~"]
	var r: float = reading
	if r < 0.0:
		return "—"
	if r == INF:
		return "OL"
	if r >= 1000.0:
		return "%s kΩ" % _digits(r / 1000.0)
	return "%s Ω" % _digits(r)


## Three digits at most past a leading one, as a meter's display.
static func _digits(value: float) -> String:
	if value >= 100.0:
		return "%d" % roundi(value)
	if value >= 10.0:
		return "%.1f" % value
	return "%.2f" % value


## 1 for AC supply bits, 2 for DC, 3 for both, 0 for none.
static func _kinds(mask: int) -> int:
	return (1 if mask & PowerSupply.AC_BITS != 0 else 0) | (2 if mask & PowerSupply.DC_BITS != 0 else 0)


## Potential of a node supply bits [param mask] reach (a phasor, volts).
static func _potential(mask: int) -> Vector2:
	match mask:
		PowerSupply.BIT_L1, PowerSupply.BIT_VFD_U:
			return Vector2(PowerSupply.PHASE_VOLTS, 0.0)
		PowerSupply.BIT_L2, PowerSupply.BIT_VFD_V:
			return Vector2.from_angle(-TAU / 3.0) * PowerSupply.PHASE_VOLTS
		PowerSupply.BIT_L3, PowerSupply.BIT_VFD_W:
			return Vector2.from_angle(TAU / 3.0) * PowerSupply.PHASE_VOLTS
	if mask != 0 and (mask & (mask - 1)) == 0 and mask & PowerSupply.DC_PLUS_BITS != 0:
		return Vector2(PowerSupply.dc_volts(mask), 0.0)
	# N, PE, a - pole, a short.
	return Vector2.ZERO


## The nodes reached from [param from] along [param edges] ([a, b, ohms]),
## not on past a node of [param stops].
static func _reached(from: Array, edges: Array, stops: Dictionary) -> Array[int]:
	var seen: Dictionary[int, bool] = {}
	var queue: Array[int] = []
	for node: int in from:
		if not seen.has(node):
			seen[node] = true
			queue.append(node)
	while not queue.is_empty():
		var node: int = queue.pop_back()
		if stops.has(node) and not from.has(node):
			continue
		for edge: Vector3 in edges:
			var other: int = -1
			if int(edge.x) == node:
				other = int(edge.y)
			elif int(edge.y) == node:
				other = int(edge.x)
			if other >= 0 and not seen.has(other):
				seen[other] = true
				queue.append(other)
	var result: Array[int] = []
	for node: int in seen:
		result.append(node)
	return result


## Node potentials (phasors) of the resistor network [param edges] over
## [param nodes]: [param fixed] held, [param injected] currents fed in.
static func _solve(nodes: Array[int], edges: Array, fixed: Dictionary[int, Vector2], injected: Dictionary) -> Dictionary[int, Vector2]:
	var index: Dictionary[int, int] = {}
	for node: int in nodes:
		if not fixed.has(node):
			index[node] = index.size()
	var n: int = index.size()
	# The conductances, row by row (real), and the right side (phasors).
	var matrix: PackedFloat64Array = PackedFloat64Array()
	matrix.resize(n * n)
	var right: PackedVector2Array = PackedVector2Array()
	right.resize(n)
	for i: int in n:
		matrix[i * n + i] = LEAK
	for node: int in injected:
		if index.has(node):
			right[index[node]] += injected[node]
	for edge: Vector3 in edges:
		var a: int = int(edge.x)
		var b: int = int(edge.y)
		if a == b or not (index.has(a) or fixed.has(a)) or not (index.has(b) or fixed.has(b)):
			continue
		var g: float = 1.0 / edge.z
		for pair: Array in [[a, b], [b, a]]:
			if not index.has(pair[0]):
				continue
			var i: int = index[pair[0]]
			matrix[i * n + i] += g
			if index.has(pair[1]):
				matrix[i * n + index[pair[1]]] -= g
			else:
				right[i] += fixed[pair[1]] * g
	# Gaussian elimination (symmetric and diagonally dominant: no pivoting).
	for col: int in n:
		var d: float = matrix[col * n + col]
		for r: int in range(col + 1, n):
			var f: float = matrix[r * n + col] / d
			if f == 0.0:
				continue
			for c: int in range(col, n):
				matrix[r * n + c] -= f * matrix[col * n + c]
			right[r] -= right[col] * f
	var solution: PackedVector2Array = PackedVector2Array()
	solution.resize(n)
	for r: int in range(n - 1, -1, -1):
		var sum: Vector2 = right[r]
		for c: int in range(r + 1, n):
			sum -= solution[c] * matrix[r * n + c]
		solution[r] = sum / matrix[r * n + r]
	var result: Dictionary[int, Vector2] = fixed.duplicate()
	for node: int in index:
		result[node] = solution[index[node]]
	return result
