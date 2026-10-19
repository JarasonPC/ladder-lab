class_name ThreePoleFuse
extends PoleDevice
## Multi-pole fuse, 2-4 fuses in one (1-2, 3-4, 5-6, 7-8; three unless set
## otherwise), gG. Each pole blows on its own when fault current flows
## through it or an overcurrent lasts as long as its characteristic allows;
## [method reset] replaces the blown ones. In a multi-pole fuse holder
## ([member holder]) all poles are opened and closed together by hand.

const DEFAULT_RATED_CURRENT: float = 16.0

## 1 for each blown pole.
var blown: PackedByteArray = PackedByteArray([0, 0, 0])
## Rated current of each fuse, amperes (gG).
var rated_current: float = DEFAULT_RATED_CURRENT
## Heating up of each fuse (simulation state).
var heat: Array[TripCurve] = []
## Mounted in a fuse holder that can be opened (design data).
var holder: bool = false
## A fuse holder is closed (simulation state; holders start open).
var switched_on: bool = false


func _init(p_designation: String) -> void:
	super(p_designation)
	_update_id()


func is_path_closed(path: int) -> bool:
	return blown[path] == 0 and (switched_on or not holder)


## Opens or closes a fuse holder.
func toggle() -> void:
	if holder:
		switched_on = not switched_on


func trip_path(path: int) -> bool:
	if not is_path_closed(path):
		return false
	blown[path] = 1
	return true


func heat_up(dt: float, currents: PackedFloat32Array) -> bool:
	var any: bool = false
	for p: int in poles:
		var current: float = currents[p] if is_path_closed(p) else 0.0
		if _heat(p).advance(dt, current) and is_path_closed(p):
			blown[p] = 1
			any = true
	return any


func time_to_heat_trip(currents: PackedFloat32Array) -> float:
	var soonest: float = INF
	for p: int in poles:
		if is_path_closed(p):
			soonest = minf(soonest, _heat(p).time_to_trip(currents[p]))
	return soonest


## The fuse of pole [param p], set to the present rating.
func _heat(p: int) -> TripCurve:
	while heat.size() <= p:
		heat.append(TripCurve.new(TripCurve.Kind.FUSE_GG, rated_current))
	heat[p].rated = rated_current
	return heat[p]


func any_blown() -> bool:
	return blown.has(1)


func reset() -> void:
	blown = PackedByteArray()
	blown.resize(poles)
	heat.clear()


func protection_state() -> int:
	var state: int = 16 if switched_on else 0
	for p: int in blown.size():
		state |= blown[p] << p
	return state


func _poles_changed() -> void:
	reset()


func trip_message() -> String:
	return "%s blown"
