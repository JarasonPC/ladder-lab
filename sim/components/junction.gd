class_name Junction
extends CircuitComponent
## Connection point where a wire branches off another wire. Has a single
## terminal addressed by its designation (e.g. "J1"); electrically it only
## joins the wires attached to it.


func get_terminal_names() -> PackedStringArray:
	return PackedStringArray([designation])


func get_terminal_keys() -> PackedStringArray:
	return PackedStringArray([designation])
