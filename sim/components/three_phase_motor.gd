class_name ThreePhaseMotor
extends CircuitComponent
## Three-phase motor (designation "M1"). [member kind] sets its terminals:
## STANDARD U1-V1-W1; STAR_DELTA also U2-V2-W2 (windings U1-U2, V1-V2, W1-W2;
## drawn as on the terminal board: U1 V1 W1 above W2 U2 V2);
## DAHLANDER 1U-1V-1W (low speed, delta) and 2U-2V-2W (high speed, double star
## with 1U, 1V, 1W joined); TWO_WINDINGS and THREE_WINDINGS have a separate
## star-connected winding per speed (1U-1V-1W, 2U-2V-2W, 3U-3V-3W).
## The simulator works out how it is fed: all three phases on the right
## terminals make it run (at [member speed] for multi-speed motors); the phase
## order L1-L2-L3 on the fed U-V-W is clockwise. Two phases only is a phase
## loss (hums, overheats); feeding two speeds at once or a wrong connection is
## MISWIRED (overheats too). The last terminal is PE (protective earth of the
## frame); it takes no part in the evaluation.
##
## DC braking: + and - of the DC source on two terminals joined by a
## winding (inside the motor or through the outer wiring) make it DC_BRAKING;
## DC together with a phase is MISWIRED. The shaft does not stop at once when
## the motor is switched off: it runs down in [member coast_time] from full
## speed, or in [member brake_time] while it is braked.
##
## Braking needs the rotor field: [member rotor_flux] is full while the motor
## runs and dies away with [constant ROTOR_TIME_CONSTANT] once it is switched
## off. DC applied at once meets the remaining field and brakes fully; applied
## later, the braking force builds up again only with the same time constant,
## so the motor stops later.
##
## Currents: fed with AC the motor is an induction machine ([MotorModel]) of
## [member rated_current] that draws [member start_ratio] times it at
## standstill. The simulator gives it the potentials of its terminals
## ([method set_supply]); it works out the current of each terminal
## ([member terminal_currents]) and the torque, and in realistic timing runs up
## against its load (rated torque at rated speed, more with [member
## overloaded]) in about [member run_up_time]: a star start draws a third of the
## current, a lost phase or a reversed winding much more. Under DC braking it
## draws [constant DC_BRAKING_CURRENT] times its rated current.

enum Kind { STANDARD, STAR_DELTA, DAHLANDER, TWO_WINDINGS, THREE_WINDINGS }
enum State { STOPPED, RUNNING, STAR, DELTA, PHASE_LOSS, MISWIRED, DC_BRAKING }
enum Direction { NONE, CLOCKWISE, COUNTERCLOCKWISE }

const DEFAULT_COAST_TIME: float = 5.0
const DEFAULT_BRAKE_TIME: float = 1.0
## Below this shaft speed the motor counts as stopped.
const STANDSTILL: float = 1e-6
## Seconds in which the rotor field falls to 37 % after switching off (and
## builds up again under DC braking); 100-500 ms in common motors.
const ROTOR_TIME_CONSTANT: float = 0.2
const DEFAULT_RATED_CURRENT: float = 8.0
const DEFAULT_START_RATIO: float = 6.0
const DEFAULT_RUN_UP_TIME: float = 1.0
const DEFAULT_RATED_POWER: float = 4.0
const DEFAULT_RATED_SPEED: float = 1440.0
## Line voltage of the supply, volts.
const RATED_VOLTAGE: float = 400.0
## Load of an overloaded motor, in multiples of the rated torque.
const OVERLOAD_FACTOR: float = 1.8
## DC braking current, in multiples of the rated current.
const DC_BRAKING_CURRENT: float = 2.0
## Longest step of the run-up calculation (seconds).
const MAX_STEP: float = 0.002

var kind: Kind
var state: State = State.STOPPED
var direction: Direction = Direction.NONE
## Running speed step of multi-speed motors (1 = lowest), else 0.
var speed: int = 0
## Injected fault: the motor is overloaded (heats its overload relay).
var overloaded: bool = false
## Drawing only: show the terminal board instead of the motor circle (a
## standard motor with star or delta bridges between U1 V1 W1 / W2 U2 V2).
var terminal_box: bool = false
## Bridges on the terminal board: delta (true) or star (false); drawing only.
var delta_bridges: bool = false
## Seconds the shaft takes to run down from full speed when switched off.
var coast_time: float = DEFAULT_COAST_TIME
## Seconds the shaft takes to stop from full speed with DC braking.
var brake_time: float = DEFAULT_BRAKE_TIME
## Shaft speed as a fraction of the running speed, 0 at standstill
## (simulation state, never saved).
var shaft: float = 0.0
## Direction the shaft turns in while it runs down.
var shaft_direction: Direction = Direction.NONE
## Rotor field, 1 while running (simulation state, never saved).
var rotor_flux: float = 0.0
## Rated (full load) line current in amperes.
var rated_current: float = DEFAULT_RATED_CURRENT
## Starting current as a multiple of the rated current.
var start_ratio: float = DEFAULT_START_RATIO
## Seconds to run up direct on line with rated load (sets the inertia).
var run_up_time: float = DEFAULT_RUN_UP_TIME
## Rated output power, kW (rating plate).
var rated_power: float = DEFAULT_RATED_POWER
## Rated speed at rated load, min⁻¹ (of the fastest speed of multi-speed
## motors); with the synchronous speed it gives the rated slip.
var rated_speed: float = DEFAULT_RATED_SPEED
## Power factor cos φ at rated load.
var power_factor: float = MotorModel.DEFAULT_POWER_FACTOR
## Draw its rating plate beside it (design data).
var show_plate: bool = false
## Signed shaft speed: fraction of the synchronous speed of the fastest
## winding, clockwise positive (simulation state).
var rotor_speed: float = 0.0
## Current into each winding terminal, amperes (phasors; DC on the real axis).
var terminal_currents: PackedVector2Array = PackedVector2Array()
## Currents in the lines L1, L2, L3 feeding it, amperes (set by the simulator).
var line_currents: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])
## Fed with AC: the windings have voltage (set by [method set_supply]).
var ac_powered: bool = false
## Torque at the present speed (multiples of the rated torque).
var torque: float = 0.0
## Rated speed of the speed step it last ran at: [member shaft] is the speed
## as a fraction of it.
var _reference: float = 1.0 - MotorModel.DEFAULT_SLIP
var _potentials: PackedVector2Array = PackedVector2Array()
var _fixed: PackedByteArray = PackedByteArray()
var _groups: PackedInt32Array = PackedInt32Array()
## DC braking: share of the DC current into each terminal (+ positive).
var _dc_share: PackedFloat32Array = PackedFloat32Array()


func _init(p_designation: String, p_kind: Kind = Kind.STANDARD) -> void:
	super(p_designation)
	kind = p_kind


func default_terminal_names() -> PackedStringArray:
	var names: PackedStringArray
	match kind:
		Kind.STAR_DELTA:
			names = PackedStringArray(["U1", "V1", "W1", "U2", "V2", "W2"])
		Kind.DAHLANDER, Kind.TWO_WINDINGS:
			names = PackedStringArray(["1U", "1V", "1W", "2U", "2V", "2W"])
		Kind.THREE_WINDINGS:
			names = PackedStringArray(["1U", "1V", "1W", "2U", "2V", "2W", "3U", "3V", "3W"])
		_:
			names = PackedStringArray(["U1", "V1", "W1"])
	names.append("PE")
	return names


## Number of winding terminals (all terminals but PE).
func winding_terminal_count() -> int:
	return default_terminal_names().size() - 1


## Number of speeds (1 for single-speed motors).
func speed_count() -> int:
	match kind:
		Kind.DAHLANDER, Kind.TWO_WINDINGS:
			return 2
		Kind.THREE_WINDINGS:
			return 3
	return 1


func is_running() -> bool:
	return state == State.RUNNING or state == State.STAR or state == State.DELTA


## The shaft turns: the motor runs or has not run down yet.
func is_turning() -> bool:
	return shaft > 0.0


## Seconds until the shaft stands still while it runs down (switched off or
## braked); INF while it is driven or stands still.
func time_to_standstill() -> float:
	if ac_powered or is_running() or shaft <= 0.0:
		return INF
	if _stops_at_once():
		return 0.0
	if state != State.DC_BRAKING:
		return shaft * coast_time
	# The slowdown grows with time; find where it reaches the shaft speed
	# (the upper end, so advancing by the result surely stops the shaft).
	var low: float = 0.0
	var high: float = (shaft + _extra_braking() * (1.0 - rotor_flux) * ROTOR_TIME_CONSTANT) * brake_time
	for i: int in 60:
		var mid: float = (low + high) * 0.5
		if _slowdown(mid) >= shaft:
			high = mid
		else:
			low = mid
	return high


## Moves the shaft on by [param dt] seconds in the present state: full speed
## while running, else slowing down. Returns true when it came to a standstill.
func advance_shaft(dt: float) -> bool:
	if ac_powered:
		var left: float = dt
		while left > 0.0:
			var h: float = minf(left, MAX_STEP)
			var before: float = rotor_speed
			_accelerate(h)
			left -= h
			if absf(rotor_speed - before) < 1e-10 * h / MAX_STEP:
				break
		rotor_flux = 1.0
		_sync_shaft()
		update_currents()
		return false
	if is_running():
		# Running with no supply given (not simulated): at rated speed.
		shaft = 1.0
		shaft_direction = direction
		rotor_flux = 1.0
		_sync_speed()
		return false
	var turning: bool = shaft > 0.0
	if turning:
		shaft = 0.0 if _stops_at_once() else shaft - _slowdown(dt)
	# The rotor field dies away, or builds up again under DC.
	var fade: float = exp(-dt / ROTOR_TIME_CONSTANT)
	rotor_flux = 1.0 - (1.0 - rotor_flux) * fade if state == State.DC_BRAKING else rotor_flux * fade
	if turning and shaft <= STANDSTILL:
		shaft = 0.0
		shaft_direction = Direction.NONE
		_sync_speed()
		return true
	_sync_speed()
	return false


func _stops_at_once() -> bool:
	return coast_time <= 0.0 or (state == State.DC_BRAKING and brake_time <= 0.0)


## Braking beyond running down freely, per second at full rotor field.
func _extra_braking() -> float:
	return maxf(1.0 / brake_time - 1.0 / coast_time, 0.0)


## Drop of the shaft speed over the next [param dt] seconds: running down
## freely, plus braking in proportion to the rotor field while DC flows.
func _slowdown(dt: float) -> float:
	var drop: float = dt / coast_time
	if state == State.DC_BRAKING:
		# Integral of the rotor field 1 - (1 - flux) * e^(-t / T) over dt.
		var field: float = dt - (1.0 - rotor_flux) * ROTOR_TIME_CONSTANT * (1.0 - exp(-dt / ROTOR_TIME_CONSTANT))
		drop += _extra_braking() * field
	return drop


func model() -> MotorModel:
	return MotorModel.of(kind, start_ratio, rated_slip(), power_factor)


## Synchronous speed of the fastest winding at 50 Hz (min⁻¹): 3000 / pole pairs.
func synchronous_rpm() -> float:
	var pairs: int = maxi(1, floori(3000.0 / maxf(rated_speed, 1.0) + 1e-9))
	return 3000.0 / pairs


## Slip at rated load, from [member rated_speed].
func rated_slip() -> float:
	return clampf(1.0 - rated_speed / synchronous_rpm(), 0.005, 0.2)


## Efficiency at rated load: rated power over the power drawn from the
## 400 V supply at rated current and power factor.
func efficiency() -> float:
	return rated_power * 1000.0 / (MotorModel.SQRT3 * RATED_VOLTAGE * rated_current * power_factor)


## Speed of the shaft now, min⁻¹ (negative counterclockwise).
func rpm() -> float:
	return rotor_speed * synchronous_rpm()


## Rated speed of each speed step, min⁻¹, slowest first.
func rated_speeds() -> PackedFloat32Array:
	var speeds: PackedFloat32Array = PackedFloat32Array()
	var steps: int = speed_count()
	for k: int in steps:
		speeds.append(rated_speed * (0.5 if kind == Kind.DAHLANDER and k == 0 else float(k + 1) / steps))
	return speeds


## Rated voltages and connections as on the rating plate, e.g. ["400/690 V", "Δ/Y"].
func plate_voltage() -> PackedStringArray:
	match kind:
		Kind.STAR_DELTA:
			return PackedStringArray(["400/690 V", "Δ/Y"])
		Kind.DAHLANDER:
			return PackedStringArray(["400 V", "Δ/YY"])
		Kind.TWO_WINDINGS:
			return PackedStringArray(["400 V", "Y/Y"])
		Kind.THREE_WINDINGS:
			return PackedStringArray(["400 V", "Y/Y/Y"])
	return PackedStringArray(["400 V", "Y"])


## Load torque against the shaft now (multiples of the rated torque).
func load_factor() -> float:
	return OVERLOAD_FACTOR if overloaded else 1.0


## Set by the simulator: [param potentials] of the winding terminals (see
## [Phasor]) where [param fixed] is 1, terminals joined outside sharing a
## [param groups] value; [param dc_polarity] +1 / -1 on terminals on the DC
## poles while it is braked.
func set_supply(potentials: PackedVector2Array, fixed: PackedByteArray, groups: PackedInt32Array, dc_polarity: PackedInt32Array) -> void:
	_potentials = potentials
	_fixed = fixed
	_groups = groups
	ac_powered = false
	for i: int in fixed.size():
		for j: int in range(i + 1, fixed.size()):
			if fixed[i] == 1 and fixed[j] == 1 and not potentials[i].is_equal_approx(potentials[j]):
				ac_powered = true
	_dc_share.resize(dc_polarity.size())
	_dc_share.fill(0.0)
	if state == State.DC_BRAKING:
		var plus: int = dc_polarity.count(1)
		var minus: int = dc_polarity.count(-1)
		for i: int in dc_polarity.size():
			if dc_polarity[i] == 1:
				_dc_share[i] = 1.0 / plus
			elif dc_polarity[i] == -1:
				_dc_share[i] = -1.0 / minus
	if ac_powered:
		var sets: int = model().sync_speed.size()
		var step: int = clampi(speed - 1, 0, sets - 1) if speed > 0 else sets - 1
		if kind == Kind.STAR_DELTA or kind == Kind.STANDARD:
			step = 0
		_reference = model().rated_speed(step)
	update_currents()


## Works out [member terminal_currents] and [member torque] at the present speed.
func update_currents() -> void:
	var count: int = winding_terminal_count()
	if ac_powered:
		var solved: Array = model().solve(_potentials, _fixed, _groups, rotor_speed, rated_current)
		terminal_currents = solved[0]
		torque = solved[1]
		return
	terminal_currents.resize(count)
	terminal_currents.fill(Vector2.ZERO)
	torque = 0.0
	if state == State.DC_BRAKING:
		for i: int in mini(count, _dc_share.size()):
			terminal_currents[i] = Vector2(_dc_share[i] * DC_BRAKING_CURRENT * rated_current, 0.0)


## Largest line current (see [member line_currents]), amperes.
func max_line_current() -> float:
	return maxf(line_currents[0], maxf(line_currents[1], line_currents[2]))


## Largest current of a winding terminal, amperes.
func max_current() -> float:
	var most: float = 0.0
	for i: Vector2 in terminal_currents:
		most = maxf(most, i.length())
	return most


## Jumps to the speed the motor settles at with the present supply (instant
## switching): the first speed in the direction it is pushed where its torque
## meets the load.
func snap_speed() -> void:
	if not ac_powered:
		return
	var at: Callable = func(n: float) -> float:
		var solved: Array = model().solve(_potentials, _fixed, _groups, n, rated_current)
		return solved[1]
	var load: float = load_factor()
	var n: float = rotor_speed
	var drive: float = at.call(n)
	var push: float = drive - signf(n) * model().load_torque(n, load)
	if n == 0.0 and absf(drive) <= model().load_torque(0.0, load):
		update_currents()
		return
	var direction_sign: float = signf(push)
	if direction_sign == 0.0:
		update_currents()
		return
	var step: float = 0.02 * direction_sign
	var accel: Callable = func(v: float) -> float:
		var t: float = at.call(v)
		if v == 0.0:
			return 0.0 if absf(t) <= model().load_torque(0.0, load) else t
		return t - signf(v) * model().load_torque(v, load)
	var limit: float = 1.2
	while absf(n + step) <= limit:
		var next: float = n + step
		if signf(next) != signf(n) and n != 0.0:
			# Through standstill: the load holds it there unless the torque wins.
			if absf(at.call(0.0)) <= model().load_torque(0.0, load):
				rotor_speed = 0.0
				_sync_shaft()
				update_currents()
				return
		if signf(accel.call(next)) != direction_sign:
			var low: float = n
			var high: float = next
			for i: int in 40:
				var mid: float = (low + high) * 0.5
				if signf(accel.call(mid)) == direction_sign:
					low = mid
				else:
					high = mid
			n = (low + high) * 0.5
			break
		n = next
	rotor_speed = n
	_sync_shaft()
	update_currents()


## Settled at a steady speed (or held at standstill): nothing changes
## until the supply does.
func is_settled() -> bool:
	if not ac_powered:
		return true
	var load: float = model().load_torque(rotor_speed, load_factor())
	if rotor_speed == 0.0:
		return absf(torque) <= load
	var accel: float = (torque - signf(rotor_speed) * load) / (maxf(run_up_time, 0.01) / model().run_up_per_inertia)
	return absf(accel) < 1e-4


## One step of the run-up: torque against load and inertia.
func _accelerate(h: float) -> void:
	var solved: Array = model().solve(_potentials, _fixed, _groups, rotor_speed, rated_current)
	var drive: float = solved[1]
	var load: float = model().load_torque(rotor_speed, load_factor())
	var inertia: float = maxf(run_up_time, 0.01) / model().run_up_per_inertia
	if rotor_speed == 0.0:
		if absf(drive) <= load:
			return
		rotor_speed = signf(drive) * minf((absf(drive) - load) / inertia * h, 0.01)
		return
	var next: float = rotor_speed + (drive - signf(rotor_speed) * load) / inertia * h
	if signf(next) != signf(rotor_speed):
		next = 0.0
	rotor_speed = next


## [member shaft] and its direction from [member rotor_speed].
func _sync_shaft() -> void:
	shaft = absf(rotor_speed) / _reference
	if shaft <= STANDSTILL:
		shaft = 0.0
		shaft_direction = Direction.NONE
	else:
		shaft_direction = Direction.CLOCKWISE if rotor_speed > 0.0 else Direction.COUNTERCLOCKWISE


## [member rotor_speed] from [member shaft] and its direction.
func _sync_speed() -> void:
	var sign: float = -1.0 if shaft_direction == Direction.COUNTERCLOCKWISE else 1.0
	rotor_speed = sign * shaft * _reference


## Works out [state, direction, speed] from the phase on each terminal
## ([param phases]: 1-3 for L1-L3, 0 for none, N or several, in terminal
## order) and [param star_points]: for each group of three terminals, whether
## they meet in a point with no phase on it.
static func evaluate(motor_kind: Kind, phases: PackedInt32Array, star_points: Array[bool]) -> Array:
	match motor_kind:
		Kind.STAR_DELTA:
			return _evaluate_star_delta(phases, star_points[1])
		Kind.DAHLANDER:
			return _evaluate_dahlander(phases, star_points[0])
		Kind.TWO_WINDINGS, Kind.THREE_WINDINGS:
			return _evaluate_windings(phases, 2 if motor_kind == Kind.TWO_WINDINGS else 3)
	var group: PackedInt32Array = phases.slice(0, 3)
	match _distinct(group):
		3:
			return [State.RUNNING, _direction(group), 0]
		2:
			return [State.PHASE_LOSS, Direction.NONE, 0]
	return [State.STOPPED, Direction.NONE, 0]


static func _evaluate_star_delta(phases: PackedInt32Array, star_point: bool) -> Array:
	var line: PackedInt32Array = phases.slice(0, 3)
	var ends: PackedInt32Array = phases.slice(3, 6)
	if _distinct(line) == 3 and star_point:
		return [State.STAR, _direction(line), 0]
	var pairs: Dictionary[int, bool] = {}
	var with_voltage: int = 0
	for i: int in 3:
		if line[i] != 0 and ends[i] != 0 and line[i] != ends[i]:
			with_voltage += 1
			pairs[mini(line[i], ends[i]) * 10 + maxi(line[i], ends[i])] = true
	if with_voltage == 3 and pairs.size() == 3:
		return [State.DELTA, _direction(line), 0]
	if _distinct(phases) == 2 and (with_voltage > 0 or star_point):
		return [State.PHASE_LOSS, Direction.NONE, 0]
	if with_voltage > 0:
		return [State.MISWIRED, Direction.NONE, 0]
	return [State.STOPPED, Direction.NONE, 0]


## Low speed: phases on 1U-1V-1W, 2U-2V-2W free. High speed: phases on
## 2U-2V-2W with 1U, 1V, 1W joined in a star point.
static func _evaluate_dahlander(phases: PackedInt32Array, low_terminals_joined: bool) -> Array:
	var low: PackedInt32Array = phases.slice(0, 3)
	var high: PackedInt32Array = phases.slice(3, 6)
	var low_count: int = _distinct(low)
	var high_count: int = _distinct(high)
	if high_count == 0:
		match low_count:
			3:
				return [State.RUNNING, _direction(low), 1]
			2:
				return [State.PHASE_LOSS, Direction.NONE, 0]
			_:
				return [State.STOPPED, Direction.NONE, 0]
	if low_count == 0 and low_terminals_joined:
		match high_count:
			3:
				return [State.RUNNING, _direction(high), 2]
			2:
				return [State.PHASE_LOSS, Direction.NONE, 0]
	if high_count >= 2 or low_count >= 1:
		return [State.MISWIRED, Direction.NONE, 0]
	return [State.STOPPED, Direction.NONE, 0]


static func _evaluate_windings(phases: PackedInt32Array, windings: int) -> Array:
	var running: int = 0
	var lost: bool = false
	var result: Array = [State.STOPPED, Direction.NONE, 0]
	for w: int in windings:
		var group: PackedInt32Array = phases.slice(3 * w, 3 * w + 3)
		match _distinct(group):
			3:
				running += 1
				result = [State.RUNNING, _direction(group), w + 1]
			2:
				lost = true
	if running > 1:
		return [State.MISWIRED, Direction.NONE, 0]
	if lost:
		return [State.MISWIRED if running == 1 else State.PHASE_LOSS, Direction.NONE, 0]
	return result


## True when DC flows through the windings: a terminal on + ([param polarity]
## 1) and one on - (-1) are joined by a winding or a chain of them, the
## terminals with the same [param roots] (group of nets) being joined outside.
static func carries_dc(motor_kind: Kind, polarity: PackedInt32Array, roots: PackedInt32Array) -> bool:
	var count: int = polarity.size()
	var uf: UnionFind = UnionFind.new(count)
	for group: PackedInt32Array in winding_groups(motor_kind):
		for i: int in range(1, group.size()):
			if group[i] < count:
				uf.union(group[0], group[i])
	for i: int in count:
		for j: int in range(i + 1, count):
			if roots[i] >= 0 and roots[i] == roots[j]:
				uf.union(i, j)
	for i: int in count:
		for j: int in count:
			if polarity[i] == 1 and polarity[j] == -1 and uf.find(i) == uf.find(j):
				return true
	return false


## Winding terminals joined inside the motor, as groups of terminal indices:
## the star or delta of a standard motor and of each separate winding, the
## three windings U1-U2, V1-V2, W1-W2 of a star/delta motor, all six
## terminals of a Dahlander motor.
static func winding_groups(motor_kind: Kind) -> Array[PackedInt32Array]:
	match motor_kind:
		Kind.STAR_DELTA:
			return [PackedInt32Array([0, 3]), PackedInt32Array([1, 4]), PackedInt32Array([2, 5])]
		Kind.DAHLANDER:
			return [PackedInt32Array([0, 1, 2, 3, 4, 5])]
		Kind.TWO_WINDINGS:
			return [PackedInt32Array([0, 1, 2]), PackedInt32Array([3, 4, 5])]
		Kind.THREE_WINDINGS:
			return [PackedInt32Array([0, 1, 2]), PackedInt32Array([3, 4, 5]), PackedInt32Array([6, 7, 8])]
	return [PackedInt32Array([0, 1, 2])]


static func _distinct(group: PackedInt32Array) -> int:
	var seen: Dictionary[int, bool] = {}
	for p: int in group:
		if p != 0:
			seen[p] = true
	return seen.size()


## L1-L2-L3 (or any rotation of it) on the three terminals is clockwise.
static func _direction(group: PackedInt32Array) -> Direction:
	var cyclic: bool = group[1] == group[0] % 3 + 1 and group[2] == group[1] % 3 + 1
	return Direction.CLOCKWISE if cyclic else Direction.COUNTERCLOCKWISE
