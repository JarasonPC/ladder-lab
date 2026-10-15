class_name OverloadRelay
extends CircuitComponent
## Thermal overload relay (designation "F3"). In the control circuit only its
## contacts are wired (see [OverloadContact]); the relay itself has no control
## terminals. While [member overloaded] (an injected fault for now) it trips
## after [member trip_delay] seconds; [method reset] is its reset button.

const DEFAULT_TRIP_DELAY: float = 5.0
const _EPSILON: float = 1e-9

var trip_delay: float
## The protected motor draws too much current.
var overloaded: bool = false:
	set(value):
		overloaded = value
		if not value:
			elapsed = 0.0
var tripped: bool = false
## Seconds of overload counted so far.
var elapsed: float = 0.0


func _init(p_designation: String, p_trip_delay: float = DEFAULT_TRIP_DELAY) -> void:
	super(p_designation)
	trip_delay = maxf(p_trip_delay, 0.0)


func get_terminal_names() -> PackedStringArray:
	return PackedStringArray()


func reset() -> void:
	tripped = false
	elapsed = 0.0


## Counts overload time; returns true when the relay trips during [param delta].
func advance(delta: float) -> bool:
	if not overloaded or tripped:
		return false
	elapsed += delta
	if elapsed + _EPSILON >= trip_delay:
		tripped = true
		return true
	return false


## Seconds until it trips, or INF.
func time_to_trip() -> float:
	return maxf(trip_delay - elapsed, 0.0) if overloaded and not tripped else INF
