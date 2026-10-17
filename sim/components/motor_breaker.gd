class_name MotorBreaker
extends PoleDevice
## Multi-pole circuit breaker (2-4 poles; 3 poles as a motor protective
## breaker, designation "Q1").
## It starts switched off. Fault current through any pole trips all poles, as
## does an overcurrent in any pole (thermal release after the time of its
## characteristic, magnetic release at once; see [TripCurve]); it is switched
## off and on by hand, and switching on resets a trip. The thermal release
## keeps its heat after a trip and cools down from there, so switched on again
## while still hot it trips sooner.

const DEFAULT_RATED_CURRENT: float = 16.0

var switched_on: bool = false
var tripped: bool = false
var rated_current: float = DEFAULT_RATED_CURRENT
var characteristic: CircuitBreaker.Characteristic = CircuitBreaker.Characteristic.C
## Heating up of the thermal release (simulation state).
var heat: TripCurve = TripCurve.new(TripCurve.Kind.BREAKER_C, DEFAULT_RATED_CURRENT)


func _init(p_designation: String) -> void:
	super(p_designation)
	_update_id()


func is_path_closed(_path: int) -> bool:
	return switched_on and not tripped


func trip_path(_path: int) -> bool:
	if tripped or not switched_on:
		return false
	tripped = true
	return true


func _heat() -> TripCurve:
	heat.kind = CircuitBreaker.breaker_curve(characteristic)
	heat.rated = rated_current
	return heat


func heat_up(dt: float, currents: PackedFloat32Array) -> bool:
	var closed: bool = is_path_closed(0)
	if _heat().advance(dt, TripCurve.largest(currents) if closed else 0.0) and closed:
		tripped = true
		return true
	return false


func time_to_heat_trip(currents: PackedFloat32Array) -> float:
	return _heat().time_to_trip(TripCurve.largest(currents)) if is_path_closed(0) else INF


func trips_instantly(currents: PackedFloat32Array) -> bool:
	if is_path_closed(0) and _heat().is_instant(TripCurve.largest(currents)):
		tripped = true
		return true
	return false


func toggle() -> void:
	if tripped:
		tripped = false
		switched_on = true
	else:
		switched_on = not switched_on


func protection_state() -> int:
	return (1 if tripped else 0) | (2 if switched_on else 0)
