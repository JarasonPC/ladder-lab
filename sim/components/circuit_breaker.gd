class_name CircuitBreaker
extends ProtectiveDevice
## Circuit breaker (terminals 1-2). Trips on a short circuit through it and
## can be switched off and on by hand; switching on again resets a trip.

var switched_on: bool = true


func toggle() -> void:
	if tripped:
		tripped = false
		switched_on = true
	else:
		switched_on = not switched_on


func _closed_by_state() -> bool:
	return switched_on and not tripped
