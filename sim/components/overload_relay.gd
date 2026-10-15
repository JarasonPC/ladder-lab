class_name OverloadRelay
extends CircuitComponent
## Thermal overload relay (designation "F3"). Its contacts sit in the control
## circuit (see [OverloadContact]). With [member poles] 3 its heaters are wired
## into the power circuit (1-2, 3-4, 5-6) and it heats while the motor it
## feeds is overloaded or has lost a phase; with 0 poles it is a box that
## heats only with the injected [member overloaded] fault. It trips after
## [member trip_delay] seconds of heating; [method reset] is its reset button.

const DEFAULT_TRIP_DELAY: float = 5.0
const _EPSILON: float = 1e-9

var trip_delay: float
## 0: control circuit only; 3: heaters in the power circuit.
var poles: int = 0
## Set by the simulator: a motor fed through the heaters draws overcurrent.
var motor_overcurrent: bool = false
## The protected motor draws too much current.
var overloaded: bool = false:
	set(value):
		overloaded = value
		if not value:
			elapsed = 0.0
var tripped: bool = false
## Seconds of overload counted so far.
var elapsed: float = 0.0


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


func is_heating() -> bool:
	return overloaded or motor_overcurrent


func protection_state() -> int:
	return 1 if tripped else 0


func _update_id() -> void:
	id = designation if poles == 0 else "%s:%s" % [designation, "-".join(get_terminal_names())]


func reset() -> void:
	tripped = false
	elapsed = 0.0


## Counts overload time; returns true when the relay trips during [param delta].
func advance(delta: float) -> bool:
	if not is_heating():
		# Cools down at once when the overload is gone.
		elapsed = 0.0
		return false
	if tripped:
		return false
	elapsed += delta
	if elapsed + _EPSILON >= trip_delay:
		tripped = true
		return true
	return false


## Seconds until it trips, or INF.
func time_to_trip() -> float:
	return maxf(trip_delay - elapsed, 0.0) if is_heating() and not tripped else INF
