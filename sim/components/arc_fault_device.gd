class_name ArcFaultDevice
extends MotorBreaker
## Arc fault detection device with a circuit breaker (AFDD, detektor
## obloukových poruch, designation "FB1", ČSN EN 62606), phase 1-2 and neutral
## N-N'. It trips as a circuit breaker of its characteristic, and at once
## when an arc burns in a loose connection of a part it feeds (a load with
## [member Load.arcing], see [Simulator]). Its test button trips it while it
## is on. It starts switched off.


func _init(p_designation: String) -> void:
	super(p_designation)
	poles = 2
	rated_current = 16.0
	characteristic = CircuitBreaker.Characteristic.B


func _poles_changed() -> void:
	if poles != 2:
		poles = 2


func default_terminal_names() -> PackedStringArray:
	return PackedStringArray(["1", "2", "N", "N'"])


## An arc's current flows through it: it trips. Returns true when it did.
func arc_trips() -> bool:
	if is_path_closed(0):
		tripped = true
		return true
	return false


## Presses the test button: trips it while it is on.
func test() -> bool:
	return arc_trips()
