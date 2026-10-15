class_name SwitchingElement
extends CircuitComponent
## Two-terminal element that is either open or closed.
##
## Terminals follow ČSN EN 60947-1: the first digit is the sequence number of the
## contact block, the second its function (1-2 NC, 3-4 NO, 5-6 delayed NC,
## 7-8 delayed NO). Sequence 1 gives NO 13-14 and NC 11-12. The id names the
## block, e.g. "S1:13-14", so one device can have several blocks.
##
## Most elements are moved by an [Armature] (a relay's, or a button's own
## actuator); NO blocks close when it has made, NC blocks open once it has
## broken. A [enum Fault] injected in the simulation overrides that.

enum ContactType { NO, NC }
enum Fault { NONE, WELDED, OPEN }

var contact_type: ContactType
## Sequence digit of the contact block (0 gives single-digit terminals "3"/"4").
var sequence: int
## Injected fault: WELDED stays closed, OPEN never closes.
var fault: Fault = Fault.NONE
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
	id = "%s:%s-%s" % [designation, _terminals[0], _terminals[1]]


func get_terminal_names() -> PackedStringArray:
	return _terminals


## Moving part that operates this block, or null.
func get_armature() -> Armature:
	return null


## True when the element is operated (button pressed, coil pulled in, ...).
func is_actuated() -> bool:
	var a: Armature = get_armature()
	return a != null and a.no_closed


func is_closed() -> bool:
	match fault:
		Fault.WELDED:
			return true
		Fault.OPEN:
			return false
	return _closed_by_state()


## Position 0..1 of the moving part (for drawing it in motion).
func get_travel() -> float:
	var a: Armature = get_armature()
	return a.position if a != null else 0.0


func _closed_by_state() -> bool:
	var a: Armature = get_armature()
	if a == null:
		return contact_type == ContactType.NC
	return a.no_closed if contact_type == ContactType.NO else not a.nc_open
