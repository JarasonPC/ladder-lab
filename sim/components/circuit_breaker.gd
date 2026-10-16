class_name CircuitBreaker
extends ProtectiveDevice
## Circuit breaker (terminals 1-2). Trips on a short circuit through it, on
## an overcurrent after the time its thermal release takes, at once above the
## current of its magnetic release ([member characteristic] B, C or D; see
## [TripCurve]), and can be switched off and on by hand; switching on again
## resets a trip. It starts switched off.

enum Characteristic { B, C, D }

const DEFAULT_RATED_CURRENT: float = 6.0

var switched_on: bool = false
var characteristic: Characteristic = Characteristic.C


func _init(p_designation: String) -> void:
	super(p_designation)
	rated_current = DEFAULT_RATED_CURRENT


func curve_kind() -> TripCurve.Kind:
	return breaker_curve(characteristic)


## Curve of a breaker of characteristic [param c].
static func breaker_curve(c: Characteristic) -> TripCurve.Kind:
	match c:
		Characteristic.B:
			return TripCurve.Kind.BREAKER_B
		Characteristic.D:
			return TripCurve.Kind.BREAKER_D
	return TripCurve.Kind.BREAKER_C


## Marking as written on the breaker, e.g. "C16".
static func rating_text(c: Characteristic, amperes: float) -> String:
	return TripCurve.LETTERS[c] + Fuse.amperes_text(amperes)


func toggle() -> void:
	if tripped:
		tripped = false
		switched_on = true
	else:
		switched_on = not switched_on


func _closed_by_state() -> bool:
	return switched_on and not tripped
