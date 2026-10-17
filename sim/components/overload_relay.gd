class_name OverloadRelay
extends CircuitComponent
## Thermal overload relay (designation "F3"). Its contacts sit in the control
## circuit (see [OverloadContact]). With [member poles] 3 its heaters are wired
## into the power circuit (1-2, 3-4, 5-6): it heats with the largest heater
## current against its [member setting] and trips after the time of trip
## class 10 (see [TripCurve]): an overloaded motor, a lost phase, a start that
## lasts too long. With 0 poles it is a box that heats only with the injected
## [member overloaded] fault, which trips any relay after [member trip_delay]
## seconds. [method test_trip] is its test button (trips it by hand),
## [method reset] its reset button.

const DEFAULT_TRIP_DELAY: float = 5.0
const DEFAULT_SETTING: float = 8.0
const _EPSILON: float = 1e-9

var trip_delay: float
## 0: control circuit only; 3: heaters in the power circuit.
var poles: int = 0
## Current setting Ir (the rated current of the motor it protects), amperes.
var setting: float = DEFAULT_SETTING
## Injected fault: the protected motor draws too much current.
var overloaded: bool = false:
	set(value):
		overloaded = value
		if not value:
			elapsed = 0.0
var tripped: bool = false
## Seconds of the injected overload counted so far.
var elapsed: float = 0.0
## Largest heater current last seen, amperes (simulation state).
var current: float = 0.0
## Heating up of the bimetals (simulation state).
var heat: TripCurve = TripCurve.new(TripCurve.Kind.OVERLOAD, DEFAULT_SETTING)


func _init(p_designation: String, p_trip_delay: float = DEFAULT_TRIP_DELAY, p_poles: int = 0) -> void:
	super(p_designation)
	trip_delay = maxf(p_trip_delay, 0.0)
	poles = 3 if p_poles == 3 else 0
	_update_id()


func default_terminal_names() -> PackedStringArray:
	if poles == 3:
		return PackedStringArray(["1", "2", "3", "4", "5", "6"])
	return PackedStringArray()


## The heaters always conduct.
func switch_paths() -> Array[Vector2i]:
	if poles == 3:
		return [Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5)]
	return []


func is_path_closed(_path: int) -> bool:
	return true


## Heats up: the injected overload, or a heater current above the setting.
func is_heating() -> bool:
	return overloaded or (poles == 3 and _heat().is_heating(current))


func protection_state() -> int:
	return 1 if tripped else 0


func _update_id() -> void:
	id = designation if poles == 0 else "%s:%s" % [designation, "-".join(get_terminal_names())]


## Test button: trips the relay by hand. Returns false if it already was.
func test_trip() -> bool:
	if tripped:
		return false
	tripped = true
	return true


## Resets the trip; the heaters keep their heat and cool down on their own,
## so a motor started again while they are still hot trips sooner.
func reset() -> void:
	tripped = false
	elapsed = 0.0


## Counts the injected overload; returns true when the relay trips during [param delta].
func advance(delta: float) -> bool:
	if not overloaded:
		elapsed = 0.0
		return false
	if tripped:
		return false
	elapsed += delta
	if elapsed + _EPSILON >= trip_delay:
		tripped = true
		return true
	return false


## Seconds until the injected overload trips it, or INF.
func time_to_trip() -> float:
	return maxf(trip_delay - elapsed, 0.0) if overloaded and not tripped else INF


func _heat() -> TripCurve:
	heat.rated = setting
	return heat


func heat_up(dt: float, currents: PackedFloat32Array) -> bool:
	if poles != 3:
		return false
	current = TripCurve.largest(currents)
	if _heat().advance(dt, current) and not tripped:
		tripped = true
		return true
	return false


func time_to_heat_trip(currents: PackedFloat32Array) -> float:
	if poles != 3 or tripped:
		return INF
	return _heat().time_to_trip(TripCurve.largest(currents))
