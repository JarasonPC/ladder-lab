class_name Armature
extends RefCounted
## Moving part of a relay or contactor. [member position] runs from 0
## (released) to 1 (pulled in) over the pick-up time while [member target] is
## true, and back over the drop-out time when it is false; it reverses at once
## if the target changes on the way.
##
## Contacts switch at fixed points of the travel, so NC contacts break before
## NO contacts make:
## pulling in, NC breaks at [constant NC_BREAK], NO makes at [constant NO_MAKE];
## releasing, NO opens at [constant NO_RELEASE], NC closes at [constant NC_REMAKE].
## The small gap between break and re-make points keeps a relay that cuts off
## its own coil buzzing at a finite rate instead of switching endlessly in one
## instant.

const NC_BREAK: float = 0.3
const NC_REMAKE: float = 0.2
const NO_MAKE: float = 1.0
const NO_RELEASE: float = 0.9
## Shortest allowed switching time, so time always moves on.
const MIN_TIME: float = 0.0001
const _EPSILON: float = 1e-9

var position: float = 0.0
var target: bool = false
## Seconds from 0 to 1.
var pick_up_time: float = 0.02
## Seconds from 1 to 0.
var drop_out_time: float = 0.015
## State of the NO contacts.
var no_closed: bool = false
## State of the NC contacts (true = opened).
var nc_open: bool = false
## Injected fault: the armature is jammed and does not move at all.
var stuck: bool = false


func _init(p_pick_up: float = 0.02, p_drop_out: float = 0.015) -> void:
	pick_up_time = maxf(p_pick_up, MIN_TIME)
	drop_out_time = maxf(p_drop_out, MIN_TIME)


## Jumps to the end position (instant switching).
func snap(on: bool) -> void:
	target = on
	if stuck:
		return
	position = 1.0 if on else 0.0
	_update_contacts()


func is_moving() -> bool:
	return (target and position < 1.0) or (not target and position > 0.0)


## Travel per second: positive while pulling in, negative while releasing.
func speed() -> float:
	if stuck:
		return 0.0
	if target and position < 1.0:
		return 1.0 / pick_up_time
	if not target and position > 0.0:
		return -1.0 / drop_out_time
	return 0.0


## Seconds until a contact switches or the armature reaches an end, or INF.
func time_to_next_event() -> float:
	var v: float = speed()
	if v > 0.0:
		var next: float = 1.0
		if not nc_open and position < NC_BREAK - _EPSILON:
			next = NC_BREAK
		return (next - position) / v
	if v < 0.0:
		var next_down: float = 0.0
		if no_closed and position > NO_RELEASE + _EPSILON:
			next_down = NO_RELEASE
		elif nc_open and position > NC_REMAKE + _EPSILON:
			next_down = NC_REMAKE
		return (position - next_down) / -v
	return INF


func advance(delta: float) -> void:
	position = clampf(position + speed() * delta, 0.0, 1.0)
	for point: float in [0.0, NC_REMAKE, NC_BREAK, NO_RELEASE, 1.0]:
		if absf(position - point) < _EPSILON:
			position = point
	_update_contacts()


func _update_contacts() -> void:
	if position >= NO_MAKE - _EPSILON:
		no_closed = true
	elif position <= NO_RELEASE + _EPSILON:
		no_closed = false
	if position >= NC_BREAK - _EPSILON:
		nc_open = true
	elif position <= NC_REMAKE + _EPSILON:
		nc_open = false
