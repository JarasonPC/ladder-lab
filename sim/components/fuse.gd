class_name Fuse
extends ProtectiveDevice
## Fuse (designation "F2", terminals 1-2), gG. Blows on a short circuit
## through it, or on an overcurrent after the time of its characteristic (see
## [TripCurve]); [method ProtectiveDevice.reset] replaces it. In a fuse holder
## ([member holder], fuse disconnector) it can also be opened and closed by
## hand.

## Mounted in a fuse holder that can be opened (design data).
var holder: bool = false
## A fuse holder is closed (simulation state; holders start open).
var switched_on: bool = false

const DEFAULT_RATED_CURRENT: float = 6.0


func _init(p_designation: String) -> void:
	super(p_designation)
	rated_current = DEFAULT_RATED_CURRENT


## A rated current as written on devices: "16", "0.5", "2.5".
static func amperes_text(amperes: float) -> String:
	if is_equal_approx(amperes, roundf(amperes)):
		return str(roundi(amperes))
	return String.num(amperes, 2)


func _closed_by_state() -> bool:
	return not tripped and (switched_on or not holder)


## Opens or closes a fuse holder.
func toggle() -> void:
	if holder:
		switched_on = not switched_on


func protection_state() -> int:
	return (1 if tripped else 0) | (2 if switched_on else 0)


func trip_message() -> String:
	return "%s blown"
