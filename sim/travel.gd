class_name Travel
extends RefCounted
## A machine part moved by a motor between two end stops, e.g. a gate: its
## position runs from 0 to 1 with the motor's speed and direction (turning
## forward towards 1) and takes [member time] seconds end to end at full
## speed. Limit switches along its way are operated where it is: one at an
## end while the part is at that end, one between the ends while the part is
## within [constant BAND] of it. No nodes.

## Part of the way (each side) a limit switch between the ends is operated over.
const BAND: float = 0.02

## Name of what moves, e.g. the group "G1" it belongs to.
var name: String = ""
## The motor moving it ([ThreePhaseMotor] or [Motor]).
var motor: CircuitComponent
## Seconds from one end to the other at full speed.
var time: float = 10.0
## The limit switches and where they are (0-1), in the same order.
var switches: Array[LatchingSwitch] = []
var at: PackedFloat32Array = PackedFloat32Array()
## Where the part is, 0-1 (simulation state).
var position: float = 0.0


func _init(p_name: String = "", p_motor: CircuitComponent = null, p_time: float = 10.0, p_position: float = 0.0) -> void:
	name = p_name
	motor = p_motor
	time = maxf(p_time, 0.1)
	position = clampf(p_position, 0.0, 1.0)


func add_switch(switch: LatchingSwitch, where: float) -> void:
	switches.append(switch)
	at.append(clampf(where, 0.0, 1.0))


## Part of the way per second it moves now (negative towards 0).
func velocity() -> float:
	var speed: float = 0.0
	if motor is ThreePhaseMotor:
		var m: ThreePhaseMotor = motor as ThreePhaseMotor
		speed = m.shaft * (-1.0 if m.shaft_direction == ThreePhaseMotor.Direction.COUNTERCLOCKWISE else 1.0)
	elif motor is Load:
		speed = 1.0 if (motor as Load).energized and not (motor as Load).burnt else 0.0
	return speed / time


## True when switch [param i] is operated with the part at [param where].
func operated(i: int, where: float = -1.0) -> bool:
	var p: float = position if where < 0.0 else where
	if at[i] <= BAND:
		return p <= at[i] + BAND
	if at[i] >= 1.0 - BAND:
		return p >= at[i] - BAND
	return absf(p - at[i]) <= BAND


## Moves the part on by [param dt] seconds (it stops at the ends).
func advance(dt: float) -> void:
	position = clampf(position + velocity() * dt, 0.0, 1.0)


## Sets the switches to where the part is. Returns the switches that changed.
func apply() -> Array[LatchingSwitch]:
	var changed: Array[LatchingSwitch] = []
	for i: int in switches.size():
		var want: bool = operated(i)
		if switches[i].switched_on != want:
			switches[i].set_switched_on(want)
			changed.append(switches[i])
	return changed


## Seconds until the part reaches an end or a switch is operated or let go,
## INF while it stands still.
func time_to_next_event() -> float:
	var v: float = velocity()
	if absf(v) < 1e-9:
		return INF
	var edges: PackedFloat32Array = PackedFloat32Array([0.0, 1.0])
	for where: float in at:
		edges.append(where - BAND)
		edges.append(where + BAND)
	var best: float = INF
	for edge: float in edges:
		var d: float = (edge - position) / v
		if d > 1e-9:
			best = minf(best, d)
	return best
