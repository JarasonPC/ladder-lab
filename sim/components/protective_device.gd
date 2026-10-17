class_name ProtectiveDevice
extends SwitchingElement
## Fuse or circuit breaker in a conductor (terminals 1-2). A short circuit
## whose fault current flows through it trips it (see [Simulator]); it then
## stays open until reset. A trip keeps the heat of the thermal release, which
## cools down from there; a new fuse ([method reset]) is cold.

var tripped: bool = false
## Rated current in amperes.
var rated_current: float = 10.0
## Heating up of the device (simulation state).
var heat: TripCurve = TripCurve.new(TripCurve.Kind.FUSE_GG, 10.0)


func _init(p_designation: String) -> void:
	super(p_designation, ContactType.NC, 0)


## Time-current characteristic of the device.
func curve_kind() -> TripCurve.Kind:
	return TripCurve.Kind.FUSE_GG


func _heat() -> TripCurve:
	heat.kind = curve_kind()
	heat.rated = rated_current
	return heat


func heat_up(dt: float, currents: PackedFloat32Array) -> bool:
	var current: float = currents[0] if is_closed() else 0.0
	if _heat().advance(dt, current) and is_closed():
		tripped = true
		return true
	return false


func time_to_heat_trip(currents: PackedFloat32Array) -> float:
	return _heat().time_to_trip(currents[0]) if is_closed() else INF


func trips_instantly(currents: PackedFloat32Array) -> bool:
	if is_closed() and _heat().is_instant(currents[0]):
		tripped = true
		return true
	return false


func _update_id() -> void:
	id = designation


func trip() -> void:
	tripped = true


func trip_path(_path: int) -> bool:
	if tripped or not is_closed():
		return false
	trip()
	return true


func protection_state() -> int:
	return 1 if tripped else 0


func reset() -> void:
	tripped = false
	heat.progress = 0.0


func _closed_by_state() -> bool:
	return not tripped
