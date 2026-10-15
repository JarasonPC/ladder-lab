class_name TerminalBlock
extends CircuitComponent
## Terminal of a terminal strip (svorka, designation "X1", "X2", ...): a
## connection point placed on a wire, e.g. right at the lead of a component.
## Drawn as a circle with a slash; [member label] is free text written next
## to it ("6", "X1:10", ...). Electrically it only joins its wires.

## Text shown on the drawing; design data.
var label: String = ""


func get_terminal_names() -> PackedStringArray:
	return PackedStringArray([designation])


func get_terminal_keys() -> PackedStringArray:
	return PackedStringArray([designation])
