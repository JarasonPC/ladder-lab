class_name ThreePhaseMotor
extends CircuitComponent
## Three-phase motor (designation "M1"). [member kind] sets its terminals:
## STANDARD U1-V1-W1; STAR_DELTA also U2-V2-W2 (windings U1-U2, V1-V2, W1-W2);
## DAHLANDER 1U-1V-1W (low speed, delta) and 2U-2V-2W (high speed, double star
## with 1U, 1V, 1W joined); TWO_WINDINGS and THREE_WINDINGS have a separate
## star-connected winding per speed (1U-1V-1W, 2U-2V-2W, 3U-3V-3W).
## The simulator works out how it is fed: all three phases on the right
## terminals make it run (at [member speed] for multi-speed motors); the phase
## order L1-L2-L3 on the fed U-V-W is clockwise. Two phases only is a phase
## loss (hums, overheats); feeding two speeds at once or a wrong connection is
## MISWIRED (overheats too).

enum Kind { STANDARD, STAR_DELTA, DAHLANDER, TWO_WINDINGS, THREE_WINDINGS }
enum State { STOPPED, RUNNING, STAR, DELTA, PHASE_LOSS, MISWIRED }
enum Direction { NONE, CLOCKWISE, COUNTERCLOCKWISE }

var kind: Kind
var state: State = State.STOPPED
var direction: Direction = Direction.NONE
## Running speed step of multi-speed motors (1 = lowest), else 0.
var speed: int = 0
## Injected fault: the motor is overloaded (heats its overload relay).
var overloaded: bool = false


func _init(p_designation: String, p_kind: Kind = Kind.STANDARD) -> void:
	super(p_designation)
	kind = p_kind


func default_terminal_names() -> PackedStringArray:
	match kind:
		Kind.STAR_DELTA:
			return PackedStringArray(["U1", "V1", "W1", "U2", "V2", "W2"])
		Kind.DAHLANDER, Kind.TWO_WINDINGS:
			return PackedStringArray(["1U", "1V", "1W", "2U", "2V", "2W"])
		Kind.THREE_WINDINGS:
			return PackedStringArray(["1U", "1V", "1W", "2U", "2V", "2W", "3U", "3V", "3W"])
	return PackedStringArray(["U1", "V1", "W1"])


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


## Draws more current than it should: overloaded, missing a phase or miswired.
func is_overcurrent() -> bool:
	return state == State.PHASE_LOSS or state == State.MISWIRED or (overloaded and is_running())


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
