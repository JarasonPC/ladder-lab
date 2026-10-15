class_name CircuitComponent
extends RefCounted
## Base class for every element of a circuit.
##
## [member designation] is the device reference designation (ČSN EN 81346-2),
## e.g. "K1", "S1", "H1". Terminals are addressed as "<designation>:<terminal>",
## e.g. "K1:A1" or "K1:13", following ČSN EN 60445 / ČSN EN 60947 marking.

## Device reference designation, e.g. "K1".
var designation: String
## Unique id inside a circuit. Equal to [member designation] unless a device is
## made of several components (contact blocks use "K1:13-14").
var id: String


func _init(p_designation: String) -> void:
	designation = p_designation
	id = p_designation


## Local terminal names, e.g. ["A1", "A2"].
func get_terminal_names() -> PackedStringArray:
	return PackedStringArray()


## Full terminal addresses used for wiring, e.g. ["K1:A1", "K1:A2"].
func get_terminal_keys() -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for t: String in get_terminal_names():
		keys.append(terminal_key(t))
	return keys


func terminal_key(terminal_name: String) -> String:
	return "%s:%s" % [designation, terminal_name]
