class_name SwitchingElement
extends CircuitComponent
## Two-terminal element that is either open or closed.
##
## Terminals follow ČSN EN 60947-1: the first digit is the sequence number of the
## contact block, the second its function (1-2 NC, 3-4 NO, 5-6 delayed NC,
## 7-8 delayed NO). Sequence 1 gives NO 13-14 and NC 11-12.

enum ContactType { NO, NC }

var contact_type: ContactType
## Sequence digit of the contact block (0 gives single-digit terminals "3"/"4").
var sequence: int
var _terminals: PackedStringArray


func _init(p_designation: String, p_type: ContactType, p_sequence: int = 1, p_delayed: bool = false) -> void:
	super(p_designation)
	contact_type = p_type
	sequence = p_sequence
	var first: int = 1 if p_type == ContactType.NC else 3
	if p_delayed:
		first += 4
	var prefix: String = "" if p_sequence == 0 else str(p_sequence)
	_terminals = PackedStringArray([prefix + str(first), prefix + str(first + 1)])


func get_terminal_names() -> PackedStringArray:
	return _terminals


## True when the element is operated (button pressed, coil pulled in, ...).
func is_actuated() -> bool:
	return false


func is_closed() -> bool:
	return is_actuated() if contact_type == ContactType.NO else not is_actuated()
