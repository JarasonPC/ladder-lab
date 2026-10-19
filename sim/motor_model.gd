class_name MotorModel
extends RefCounted
## Electrical model of a three-phase induction motor of one [enum
## ThreePhaseMotor.Kind] and starting current ratio, shared by all motors
## alike (see [method of]).
##
## The motor is a set of windings, three per winding set (one set per speed),
## joined to the terminals and to internal star points. Each winding set is
## an induction machine: the voltages on its three windings are split into
## symmetrical components (positive, negative and zero sequence). The positive
## sequence turns the field clockwise (L1-L2-L3 on U-V-W), the negative one
## the other way; each meets the rotor with its own slip, so a motor fed
## unevenly (a lost phase, a reversed winding in delta) pulls both ways and
## draws a large current. Per winding (per unit of its rated voltage and
## current): a magnetizing current plus the rotor branch 1 / (r2 / s + j x),
## chosen so that the motor draws its rated current at its rated slip
## ([member slip_rated]) with its rated power factor, and [member
## start_ratio] times it at standstill. Torque is the rotor power of the positive sequence minus
## that of the negative one, 1 at rated slip. The rotor resistance grows with
## the slip as in the deep bars of real rotors ([member deep_bar]), as far as
## needed for a starting torque of [constant MIN_START_TORQUE] direct on line:
## without it a motor of small rated slip (2970 min⁻¹) would start with
## hardly any torque, and in star not at all.
##
## Units: potentials in phase voltages (L1 = 1∠0°, see [Phasor]), currents in
## amperes for a motor of rated current In.

const DEFAULT_SLIP: float = 0.04
const DEFAULT_POWER_FACTOR: float = 0.82
## Share of the rated load torque the driven machine needs at standstill; the
## rest grows with the square of the speed (fans, pumps), so the rated load is
## reached at rated speed.
const STATIC_LOAD: float = 0.25
## Least starting torque direct on line, in multiples of the rated torque
## (about the least IEC 60034-12 design N motors have).
const MIN_START_TORQUE: float = 1.6
const SQRT3: float = 1.7320508075688772

static var _cache: Dictionary[String, MotorModel] = {}

var start_ratio: float
## Slip at rated load and power factor (cos φ) at rated load.
var slip_rated: float
var power_factor: float
## Magnetizing current (per unit).
var magnetizing: float
## Rotor resistance and leakage reactance (per unit of the winding).
var r2: float
## Rotor resistance at standstill over that at rated slip (deep bars, 1 for
## none); in between it grows in proportion to the slip.
var deep_bar: float = 1.0
var x: float
## Rotor power per unit voltage at rated slip (torque 1).
var _g_rated: float
## Seconds the motor takes to run up to 95 % of its rated speed direct on line
## with rated load, per second of mechanical time constant.
var run_up_per_inertia: float
## Windings as (from node, to node, set); nodes 0.. are the winding terminals,
## the internal star points follow.
var windings: Array[Vector3i] = []
## Per winding set: synchronous speed (fraction of the fastest one), rated
## winding voltage (phase voltages) and rated winding current (multiples of
## the motor's rated line current).
var sync_speed: PackedFloat32Array = PackedFloat32Array()
var winding_voltage: PackedFloat32Array = PackedFloat32Array()
var winding_current: PackedFloat32Array = PackedFloat32Array()
## Per winding set: terminals of which one must be fed for the set to take
## part (empty: always).
var set_needs: Array[PackedInt32Array] = []
var terminal_count: int = 0
var node_count: int = 0


## The model of a motor of [param kind] whose starting current is
## [param ratio] times its rated current, with rated [param slip] and
## [param cos_phi].
static func of(kind: ThreePhaseMotor.Kind, ratio: float, slip: float = DEFAULT_SLIP, cos_phi: float = DEFAULT_POWER_FACTOR) -> MotorModel:
	var key: String = "%d/%.4f/%.5f/%.4f" % [kind, ratio, slip, cos_phi]
	if not _cache.has(key):
		_cache[key] = MotorModel.new(kind, ratio, slip, cos_phi)
	return _cache[key]


func _init(kind: ThreePhaseMotor.Kind, ratio: float, slip: float = DEFAULT_SLIP, cos_phi: float = DEFAULT_POWER_FACTOR) -> void:
	start_ratio = clampf(ratio, 2.0, 12.0)
	slip_rated = clampf(slip, 0.005, 0.2)
	power_factor = clampf(cos_phi, 0.3, 0.97)
	_calibrate()
	_build_windings(kind)
	run_up_per_inertia = _run_up_time(1.0)


## Rated speed of winding set [param s] (fraction of the fastest synchronous speed).
func rated_speed(s: int) -> float:
	return sync_speed[s] * (1.0 - slip_rated)


## Load torque against the motor at [param speed] (signed), for a machine
## needing [param load] times the rated torque at rated speed.
func load_torque(speed: float, load: float) -> float:
	var n: float = absf(speed) / (1.0 - slip_rated)
	return load * (STATIC_LOAD + (1.0 - STATIC_LOAD) * n * n)


## Winding admittance (per unit) at slip [param s]: magnetizing current plus
## the rotor branch.
func admittance(s: float) -> Vector2:
	var r: float = rotor_resistance(s)
	var d: float = r * r + x * x * s * s
	return Vector2(s * r / d, -magnetizing - x * s * s / d)


## Rotor power per unit voltage at slip [param s].
func rotor_power(s: float) -> float:
	var r: float = rotor_resistance(s)
	return s * r / (r * r + x * x * s * s)


## Rotor resistance (per unit) at slip [param s]: [member r2] up to the rated
## slip, growing to [member deep_bar] times it at standstill (and on beyond).
func rotor_resistance(s: float) -> float:
	return r2 * (1.0 + (deep_bar - 1.0) * maxf(absf(s) - slip_rated, 0.0) / (1.0 - slip_rated))


## Solves the motor at [param speed]: [param potentials] of the winding
## terminals where [param fixed] is 1 (fed by a supply); terminals that are
## not fixed float, those with the same [param groups] value being joined
## outside. Returns [terminal currents (PackedVector2Array, amperes into the
## motor), torque (multiples of the rated torque, clockwise positive)].
func solve(potentials: PackedVector2Array, fixed: PackedByteArray, groups: PackedInt32Array, speed: float, rated_current: float) -> Array:
	# Unknown nodes: the floating groups, then the star points.
	var unknown: PackedInt32Array = PackedInt32Array()
	unknown.resize(node_count)
	unknown.fill(-1)
	var of_group: Dictionary[int, int] = {}
	var count: int = 0
	for t: int in terminal_count:
		if fixed[t] == 0:
			if not of_group.has(groups[t]):
				of_group[groups[t]] = count
				count += 1
			unknown[t] = of_group[groups[t]]
	for node: int in range(terminal_count, node_count):
		unknown[node] = count
		count += 1
	var matrices: Array[PackedVector2Array] = []
	var active: PackedByteArray = PackedByteArray()
	for s: int in sync_speed.size():
		var on: bool = set_needs[s].is_empty()
		for t: int in set_needs[s]:
			on = on or fixed[t] == 1
		active.append(1 if on else 0)
		if on:
			matrices.append(_winding_matrix(s, speed, rated_current))
		else:
			var none: PackedVector2Array = PackedVector2Array()
			none.resize(9)
			matrices.append(none)
	var potential: PackedVector2Array = PackedVector2Array()
	potential.resize(node_count)
	for t: int in terminal_count:
		potential[t] = potentials[t] if fixed[t] == 1 else Vector2.ZERO
	if count > 0:
		var m: PackedVector2Array = PackedVector2Array()
		m.resize(count * count)
		var b: PackedVector2Array = PackedVector2Array()
		b.resize(count)
		for r: int in count:
			# A tiny leak to N keeps a node that touches nothing solvable.
			m[r * count + r] = Vector2(1e-7 * maxf(rated_current, 1e-3), 0.0)
		for k: int in windings.size():
			var w: Vector3i = windings[k]
			var base: int = w.z * 3
			var mk: PackedVector2Array = matrices[w.z]
			for j: int in 3:
				var wj: Vector3i = windings[base + j]
				var coef: Vector2 = mk[(k - base) * 3 + j]
				# Current of winding k leaves node w.x and enters node w.y.
				for end: int in 2:
					var row_node: int = w.x if end == 0 else w.y
					var r: int = unknown[row_node]
					if r < 0:
						continue
					var c: Vector2 = coef if end == 0 else -coef
					for side: int in 2:
						var col_node: int = wj.x if side == 0 else wj.y
						var cc: Vector2 = c if side == 0 else -c
						var col: int = unknown[col_node]
						if col >= 0:
							m[r * count + col] += cc
						else:
							b[r] -= Phasor.mul(cc, potential[col_node])
		var solved: PackedVector2Array = Phasor.solve(m, b)
		for node: int in node_count:
			if unknown[node] >= 0:
				potential[node] = solved[unknown[node]]
	var currents: PackedVector2Array = PackedVector2Array()
	currents.resize(terminal_count)
	var torque: float = 0.0
	for s: int in sync_speed.size():
		var base: int = s * 3
		var v: PackedVector2Array = PackedVector2Array()
		for k: int in 3:
			var w: Vector3i = windings[base + k]
			v.append(potential[w.x] - potential[w.y])
		var mk: PackedVector2Array = matrices[s]
		for k: int in 3:
			var i: Vector2 = Vector2.ZERO
			for j: int in 3:
				i += Phasor.mul(mk[k * 3 + j], v[j])
			var w: Vector3i = windings[base + k]
			if w.x < terminal_count:
				currents[w.x] += i
			if w.y < terminal_count:
				currents[w.y] -= i
		var v1: Vector2 = (v[0] + Phasor.mul(Phasor.A, v[1]) + Phasor.mul(Phasor.A2, v[2])) / (3.0 * winding_voltage[s])
		var v2: Vector2 = (v[0] + Phasor.mul(Phasor.A2, v[1]) + Phasor.mul(Phasor.A, v[2])) / (3.0 * winding_voltage[s])
		var slip: float = 1.0 - speed / sync_speed[s]
		if active[s] == 0:
			continue
		# Weighted by the set's share of the rated power.
		var share: float = winding_voltage[s] * winding_current[s]
		torque += share * (v1.length_squared() * rotor_power(slip) - v2.length_squared() * rotor_power(2.0 - slip)) / _g_rated
	return [currents, torque]


## 3x3 admittance matrix (row-major, amperes per phase voltage) of the
## windings of set [param s] at [param speed]: circulant, built from the
## sequence admittances.
func _winding_matrix(s: int, speed: float, rated_current: float) -> PackedVector2Array:
	var slip: float = 1.0 - speed / sync_speed[s]
	var y1: Vector2 = admittance(slip)
	var y2: Vector2 = admittance(2.0 - slip)
	var y0: Vector2 = Phasor.inv(Vector2(r2, x))
	var scale: float = rated_current * winding_current[s] / winding_voltage[s]
	var m: Array[Vector2] = [
		(y0 + y1 + y2) / 3.0 * scale,
		(y0 + Phasor.mul(Phasor.A, y1) + Phasor.mul(Phasor.A2, y2)) / 3.0 * scale,
		(y0 + Phasor.mul(Phasor.A2, y1) + Phasor.mul(Phasor.A, y2)) / 3.0 * scale,
	]
	var out: PackedVector2Array = PackedVector2Array()
	for k: int in 3:
		for j: int in 3:
			out.append(m[posmod(j - k, 3)])
	return out


## Chooses x, r2 and the magnetizing current: rated current with the rated
## power factor at rated slip, start_ratio times it at standstill.
func _calibrate() -> void:
	deep_bar = 1.0
	_fit_reactance()
	if _start_torque() >= MIN_START_TORQUE:
		return
	# Up in steps to where the torque is reached, then narrowed down; where
	# the starting current allows no such torque, the most it allows.
	var best: float = 1.0
	var best_torque: float = _start_torque()
	var low: float = 1.0
	var high: float = 0.0
	var step: float = 1.0
	while step < 30.0 and high <= 0.0:
		step *= 1.2
		deep_bar = step
		_fit_reactance()
		var torque: float = _start_torque()
		if torque >= MIN_START_TORQUE:
			high = step
		else:
			low = step
			if torque > best_torque:
				best = step
				best_torque = torque
	if high <= 0.0:
		deep_bar = best
		_fit_reactance()
		return
	for i: int in 30:
		deep_bar = (low + high) * 0.5
		_fit_reactance()
		if _start_torque() < MIN_START_TORQUE:
			low = deep_bar
		else:
			high = deep_bar
	deep_bar = high
	_fit_reactance()


## The reactance for [member start_ratio] times the rated current at
## standstill (with the [member deep_bar] set).
func _fit_reactance() -> void:
	var low: float = 0.005
	var high: float = 0.5 / power_factor - 1e-6
	for i: int in 60:
		_set_reactance((low + high) * 0.5)
		if admittance(1.0).length() > start_ratio:
			low = x
		else:
			high = x
	_g_rated = rotor_power(slip_rated)


## Starting torque direct on line, in multiples of the rated torque.
func _start_torque() -> float:
	return rotor_power(1.0) / rotor_power(slip_rated)


## With reactance [param react]: r2 so the active rated current is the power
## factor, the magnetizing current making up the rest of the rated current.
func _set_reactance(react: float) -> void:
	x = react
	var c: float = power_factor
	# R / (R² + x²) = c, the larger root (the motor's working side).
	var big_r: float = (1.0 + sqrt(maxf(1.0 - 4.0 * c * c * x * x, 0.0))) / (2.0 * c)
	r2 = big_r * slip_rated
	magnetizing = maxf(sqrt(1.0 - c * c) - x / (big_r * big_r + x * x), 0.0)


## Seconds to run up direct on line with rated load to 95 % of rated speed,
## for a mechanical time constant [param inertia].
func _run_up_time(inertia: float) -> float:
	var n: float = 0.0
	var t: float = 0.0
	var dt: float = 0.0005
	var target: float = 0.95 * (1.0 - slip_rated)
	while n < target and t < 100.0:
		var torque: float = rotor_power(1.0 - n) / _g_rated
		n += (torque - load_torque(n, 1.0)) / inertia * dt
		t += dt
	return t


func _build_windings(kind: ThreePhaseMotor.Kind) -> void:
	match kind:
		ThreePhaseMotor.Kind.STAR_DELTA:
			# U1-U2, V1-V2, W1-W2, each rated for the line voltage (delta).
			terminal_count = 6
			_add_set(1.0, SQRT3, 1.0 / SQRT3, [Vector2i(0, 3), Vector2i(1, 4), Vector2i(2, 5)])
		ThreePhaseMotor.Kind.DAHLANDER:
			# Low speed: delta between 1U, 1V, 1W (each side two halves in
			# series, the middle taps 2U, 2V, 2W free). High speed: from each
			# tap a half to both corners of its side, a double star once 1U,
			# 1V, 1W are joined; these take part only while a tap is fed.
			terminal_count = 6
			_add_set(0.5, SQRT3, 1.0 / SQRT3, [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0)])
			var taps: PackedInt32Array = PackedInt32Array([3, 4, 5])
			_add_set(1.0, 1.0, 0.5, [Vector2i(3, 0), Vector2i(4, 1), Vector2i(5, 2)], taps)
			_add_set(1.0, 1.0, 0.5, [Vector2i(3, 1), Vector2i(4, 2), Vector2i(5, 0)], taps)
		ThreePhaseMotor.Kind.TWO_WINDINGS, ThreePhaseMotor.Kind.THREE_WINDINGS:
			var sets: int = 2 if kind == ThreePhaseMotor.Kind.TWO_WINDINGS else 3
			terminal_count = 3 * sets
			for s: int in sets:
				var star: int = terminal_count + s
				_add_set(float(s + 1) / sets, 1.0, 1.0, [Vector2i(3 * s, star), Vector2i(3 * s + 1, star), Vector2i(3 * s + 2, star)])
		_:
			# Star inside, rated for the phase voltage.
			terminal_count = 3
			_add_set(1.0, 1.0, 1.0, [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)])
	node_count = terminal_count
	for w: Vector3i in windings:
		node_count = maxi(node_count, maxi(w.x, w.y) + 1)


func _add_set(sync: float, voltage: float, current: float, ends: Array[Vector2i], needs: PackedInt32Array = PackedInt32Array()) -> void:
	var s: int = sync_speed.size()
	set_needs.append(needs)
	sync_speed.append(sync)
	winding_voltage.append(voltage)
	winding_current.append(current)
	for e: Vector2i in ends:
		windings.append(Vector3i(e.x, e.y, s))
