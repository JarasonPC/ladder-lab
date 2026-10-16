class_name TripCurve
extends RefCounted
## Time-current characteristics of the protective devices: how long a
## current of a given multiple of the rated current takes to trip them.
## Typical curves in the middle of the bands the standards allow:
## circuit breakers ČSN EN 60898-1 (thermal release, conventional tripping
## current 1.45 In, instantaneous magnetic release at 5 In for B, 10 In for C,
## 20 In for D: the currents at which they surely trip), fuses gG
## (ČSN EN 60269), overload relays of trip class 10 (ČSN EN 60947-4-1, from
## cold). Between the points the time is interpolated on log-log scales.
##
## [method advance] counts the heating up of one device as the share of its
## trip time used ([member progress], it trips at 1); below the current at
## which it never trips the device cools down again with
## [constant COOLING_TIME].

enum Kind { BREAKER_B, BREAKER_C, BREAKER_D, FUSE_GG, OVERLOAD }

const BREAKER_THERMAL: PackedVector2Array = [Vector2(1.13, 7200.0), Vector2(1.2, 2400.0), Vector2(1.45, 600.0), Vector2(2.0, 100.0), Vector2(2.55, 35.0), Vector2(3.0, 20.0), Vector2(4.0, 9.0), Vector2(5.0, 5.0), Vector2(7.0, 2.5), Vector2(10.0, 1.2), Vector2(20.0, 0.4), Vector2(50.0, 0.1)]
const FUSE_GG: PackedVector2Array = [Vector2(1.25, 10000.0), Vector2(1.6, 1800.0), Vector2(2.0, 300.0), Vector2(2.5, 60.0), Vector2(3.0, 20.0), Vector2(4.0, 5.0), Vector2(5.0, 2.0), Vector2(6.0, 1.0), Vector2(8.0, 0.3), Vector2(10.0, 0.12), Vector2(15.0, 0.03), Vector2(20.0, 0.012), Vector2(50.0, 0.002)]
const OVERLOAD_CLASS_10: PackedVector2Array = [Vector2(1.1, 7200.0), Vector2(1.2, 1200.0), Vector2(1.5, 240.0), Vector2(2.0, 80.0), Vector2(3.0, 30.0), Vector2(4.0, 17.0), Vector2(5.0, 12.0), Vector2(6.0, 9.0), Vector2(7.2, 7.0), Vector2(8.0, 6.0), Vector2(10.0, 4.5), Vector2(20.0, 2.0)]
## Multiple of In at which the magnetic release trips at once (B, C, D).
const MAGNETIC: Dictionary[Kind, float] = {Kind.BREAKER_B: 5.0, Kind.BREAKER_C: 10.0, Kind.BREAKER_D: 20.0}
## Band of the magnetic release given by the standard (lower, upper multiple).
const MAGNETIC_BAND: Dictionary[Kind, Vector2] = {Kind.BREAKER_B: Vector2(3, 5), Kind.BREAKER_C: Vector2(5, 10), Kind.BREAKER_D: Vector2(10, 20)}
## Seconds in which the heat falls to 37 % once the current is low again.
const COOLING_TIME: Dictionary[Kind, float] = {Kind.BREAKER_B: 60.0, Kind.BREAKER_C: 60.0, Kind.BREAKER_D: 60.0, Kind.FUSE_GG: 20.0, Kind.OVERLOAD: 120.0}
## Characteristic letters of the breakers.
const LETTERS: PackedStringArray = ["B", "C", "D"]

var kind: Kind
## Rated current (setting of an overload relay), amperes.
var rated: float
## Share of the trip time used so far (0 cold, 1 trips).
var progress: float = 0.0


func _init(p_kind: Kind, p_rated: float) -> void:
	kind = p_kind
	rated = p_rated


## Points (multiple of In, seconds) of the inverse-time part of [param k].
static func points(k: Kind) -> PackedVector2Array:
	match k:
		Kind.FUSE_GG:
			return FUSE_GG
		Kind.OVERLOAD:
			return OVERLOAD_CLASS_10
	return BREAKER_THERMAL


## Seconds a current of [param multiple] times In takes to trip a cold
## device of characteristic [param k]: INF below the lowest point, 0 at or
## above the magnetic release of a breaker.
static func trip_time(k: Kind, multiple: float) -> float:
	if MAGNETIC.has(k) and multiple >= MAGNETIC[k]:
		return 0.0
	var curve: PackedVector2Array = points(k)
	if multiple < curve[0].x:
		return INF
	for i: int in range(1, curve.size()):
		if multiple <= curve[i].x:
			var a: Vector2 = curve[i - 1]
			var b: Vector2 = curve[i]
			var f: float = log(multiple / a.x) / log(b.x / a.x)
			return exp(lerpf(log(a.y), log(b.y), f))
	# Beyond the last point: on along the last stretch.
	var p: Vector2 = curve[curve.size() - 2]
	var q: Vector2 = curve[curve.size() - 1]
	var slope: float = log(q.y / p.y) / log(q.x / p.x)
	return q.y * pow(multiple / q.x, slope)


## True when [param current] trips the magnetic release at once.
func is_instant(current: float) -> bool:
	return MAGNETIC.has(kind) and rated > 0.0 and current >= MAGNETIC[kind] * rated


## Heats or cools for [param dt] seconds at [param current] amperes;
## returns true when the device trips.
func advance(dt: float, current: float) -> bool:
	var t: float = trip_time(kind, current / rated) if rated > 0.0 else INF
	if t == INF:
		progress *= exp(-dt / COOLING_TIME[kind])
		return false
	if t <= 0.0:
		progress = 1.0
		return true
	progress += dt / t
	if progress >= 1.0 - 1e-9:
		progress = 1.0
		return true
	return false


## Seconds until [param current] trips the device, INF if it never does.
func time_to_trip(current: float) -> float:
	var t: float = trip_time(kind, current / rated) if rated > 0.0 else INF
	return INF if t == INF else maxf(t * (1.0 - progress), 0.0)


## Largest of [param currents] (the pole that heats most).
static func largest(currents: PackedFloat32Array) -> float:
	var most: float = 0.0
	for i: float in currents:
		most = maxf(most, i)
	return most


## Heating up: the current is above the one it never trips at.
func is_heating(current: float) -> bool:
	return rated > 0.0 and trip_time(kind, current / rated) < INF
