class_name Coil
extends Load
## Coil of a relay or contactor (terminals A1-A2). Contacts with the same
## designation follow its [member armature].
##
## [member pick_up_time] and [member drop_out_time] are nominal values; the
## armature uses them scaled by a small fixed tolerance derived from the
## designation, so two identical relays started together do not stay in step
## forever (one of them wins, always the same one).

enum Kind { RELAY, CONTACTOR }
## Injected faults: OPEN (broken winding, never pulls in), STUCK (armature
## jammed where it is).
enum Fault { NONE, OPEN, STUCK }

## Default (pick-up, drop-out) seconds per kind.
const DEFAULT_PICK_UP: Dictionary[Kind, float] = {Kind.RELAY: 0.010, Kind.CONTACTOR: 0.020}
const DEFAULT_DROP_OUT: Dictionary[Kind, float] = {Kind.RELAY: 0.008, Kind.CONTACTOR: 0.015}
## Largest deviation from the nominal times (+-5 %).
const TOLERANCE: float = 0.05

var kind: Kind
var pick_up_time: float
var drop_out_time: float
var armature: Armature
var fault: Fault = Fault.NONE:
	set(value):
		fault = value
		_apply_fault()


func _init(p_designation: String, p_kind: Kind = Kind.CONTACTOR, p_pick_up: float = -1.0, p_drop_out: float = -1.0) -> void:
	super(p_designation, "A1", "A2")
	kind = p_kind
	pick_up_time = p_pick_up if p_pick_up >= 0.0 else DEFAULT_PICK_UP[kind]
	drop_out_time = p_drop_out if p_drop_out >= 0.0 else DEFAULT_DROP_OUT[kind]
	armature = _new_armature()


## Fixed factor in [1 - TOLERANCE, 1 + TOLERANCE] for this designation.
func timing_factor() -> float:
	var h: int = absi(designation.hash()) % 2001
	return 1.0 + TOLERANCE * (h / 1000.0 - 1.0)


## Called by the simulator when the coil gains or loses power.
func set_energized(value: bool) -> void:
	energized = value
	_sync_targets()


## Armature moved by the given contacts: delayed timer contacts have their own.
func get_armature(_delayed: bool) -> Armature:
	return armature


## A contactor coil draws more than a relay coil (holding current).
func rated_draw() -> float:
	return 0.05 if kind == Kind.CONTACTOR else 0.02


## Instant switching: every armature jumps to where it is heading.
func snap() -> void:
	armature.snap(armature.target)


## Advances timing logic (time relays) by [param _delta] seconds.
func advance(_delta: float) -> void:
	pass


## Moves the armatures by [param delta] seconds.
func move_armatures(delta: float) -> void:
	armature.advance(delta)


## Seconds until an armature switches a contact, reaches an end or a timer
## expires; INF when nothing is pending.
func time_to_next_event() -> float:
	return armature.time_to_next_event()


func _new_armature() -> Armature:
	var factor: float = timing_factor()
	return Armature.new(pick_up_time * factor, drop_out_time * factor)


func _sync_targets() -> void:
	armature.target = energized


func _apply_fault() -> void:
	armature.stuck = fault == Fault.STUCK
