class_name ResidualCurrentDevice
extends MotorBreaker
## Residual current device (proudový chránič, designation "FB1", ČSN EN
## 61008): 2 poles (phase 1-2, neutral N-N') or 4 poles (1-2, 3-4, 5-6,
## N-N'). It compares the currents through its poles: what goes out on the
## phases and does not come back on its N leaves through the protective
## conductor or a person, and from [constant TRIP_SHARE] of its rated
## residual current on it trips (see [Simulator]). A fault current of a short
## through one of its poles alone (a phase on PE) trips it too; a short
## between its poles (L-N) does not. With [member overcurrent] it is an RCBO
## (proudový chránič s jističem, ČSN EN 61009): it also trips as a circuit
## breaker of its characteristic. Its test button T trips it while it is on.
## It starts switched off.

## Rated residual currents sold, amperes (offered in the properties).
const RESIDUAL_RATINGS: Array[float] = [0.01, 0.03, 0.1, 0.3]
## Rated currents of an RCD without overcurrent release, amperes.
const RCD_RATINGS: Array[float] = [16.0, 25.0, 40.0, 63.0]
## Share of the rated residual current from which it trips (it must trip
## between half of it and all of it).
const TRIP_SHARE: float = 0.7
## Types: AC trips on AC residual currents only, A also on pulsating DC.
const TYPES: PackedStringArray = ["AC", "A"]

## Rated residual current IΔn, amperes (design data).
var residual_rating: float = 0.03
## Type "AC" or "A" (design data).
var type: String = "A"
## Has an overcurrent release too: an RCBO (design data).
var overcurrent: bool = false


func _init(p_designation: String, p_poles: int = 2) -> void:
	super(p_designation)
	poles = p_poles
	rated_current = 40.0


func _poles_changed() -> void:
	if poles != 2 and poles != 4:
		poles = 4 if poles > 2 else 2


## Phases 1-2 (3-4, 5-6), then the neutral N-N'.
func default_terminal_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for p: int in poles - 1:
		names.append(str(2 * p + 1))
		names.append(str(2 * p + 2))
	names.append("N")
	names.append("N'")
	return names


func heat_up(dt: float, currents: PackedFloat32Array) -> bool:
	return super(dt, currents) if overcurrent else false


func time_to_heat_trip(currents: PackedFloat32Array) -> float:
	return super(currents) if overcurrent else INF


func trips_instantly(currents: PackedFloat32Array) -> bool:
	return super(currents) if overcurrent else false


## A short's fault current through it trips its overcurrent release (an
## RCBO); a residual of a short is found by [method residual_short].
func trip_path(path: int) -> bool:
	return super(path) if overcurrent else false


## Trips on residual current [param amperes] (of the phasor sum of its
## poles' currents) from [constant TRIP_SHARE] of its rating on. Returns
## true when it trips.
func residual_trips(amperes: float) -> bool:
	if is_path_closed(0) and amperes >= residual_rating * TRIP_SHARE:
		tripped = true
		return true
	return false


## A short's fault current flows through [param fault_poles] of its poles:
## through one alone it does not come back, so it trips. Returns true when
## it trips.
func residual_short(fault_poles: int) -> bool:
	if fault_poles == 1 and is_path_closed(0):
		tripped = true
		return true
	return false


## Presses the test button T: trips it while it is on. Returns true when it did.
func test() -> bool:
	if is_path_closed(0):
		tripped = true
		return true
	return false
