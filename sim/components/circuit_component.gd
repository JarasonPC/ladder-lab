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
## Terminal names chosen instead of the standard marking, in the same order
## (e.g. ["5", "6"] for a block normally marked 7-8, or ["A2", "A1"] to swap a
## coil's terminals). Empty means the standard marking.
var custom_terminals: PackedStringArray = PackedStringArray():
	set(value):
		custom_terminals = value
		_update_id()


func _init(p_designation: String) -> void:
	designation = p_designation
	id = p_designation


## Local terminal names, e.g. ["A1", "A2"].
func get_terminal_names() -> PackedStringArray:
	var standard: PackedStringArray = default_terminal_names()
	if custom_terminals.size() == standard.size() and not custom_terminals.is_empty():
		return custom_terminals
	return standard


## Standard terminal marking of this component. Override.
func default_terminal_names() -> PackedStringArray:
	return PackedStringArray()


## False for components whose terminal is named by the designation itself.
func supports_custom_terminals() -> bool:
	return not default_terminal_names().is_empty()


## True if [param names] are usable terminal names: not empty, unique and
## without ":" or spaces.
static func valid_terminal_names(names: PackedStringArray) -> bool:
	var seen: Dictionary[String, bool] = {}
	for n: String in names:
		if n.is_empty() or n.contains(":") or n.contains(" ") or seen.has(n):
			return false
		seen[n] = true
	return true


## Recomputes [member id] after the terminal names changed. Override.
func _update_id() -> void:
	pass


## Switching paths as pairs of terminal indices, e.g. [(0, 1)] for a contact
## or three pairs for a three-pole device. Empty for parts that do not switch.
func switch_paths() -> Array[Vector2i]:
	return []


## Whether switching path [param _path] (see [method switch_paths]) conducts.
func is_path_closed(_path: int) -> bool:
	return false


## A short circuit's fault current flows through path [param _path]: fuses and
## breakers react. Returns true if the part changed state.
func trip_path(_path: int) -> bool:
	return false


## Protection state for loop detection (-1: not a protective part).
func protection_state() -> int:
	return -1


## Log text when [method trip_path] reacted, e.g. "%s blown".
func trip_message() -> String:
	return "%s tripped"


## Full terminal addresses used for wiring, e.g. ["K1:A1", "K1:A2"].
func get_terminal_keys() -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for t: String in get_terminal_names():
		keys.append(terminal_key(t))
	return keys


func terminal_key(terminal_name: String) -> String:
	return "%s:%s" % [designation, terminal_name]
