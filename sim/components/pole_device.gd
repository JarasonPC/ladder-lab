class_name PoleDevice
extends CircuitComponent
## Multi-pole device in the power circuit, terminals 1-2, 3-4, 5-6, 7-8 (one
## pole each, ČSN EN 60947 marking). Id "<designation>:1-2-3-4-5-6".

## Number of poles (1-4; design data). Three unless set otherwise.
var poles: int = 3:
	set(value):
		poles = clampi(value, 1, 4)
		_poles_changed()
		_update_id()


func default_terminal_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for i: int in 2 * poles:
		names.append(str(i + 1))
	return names


func switch_paths() -> Array[Vector2i]:
	var paths: Array[Vector2i] = []
	for p: int in poles:
		paths.append(Vector2i(2 * p, 2 * p + 1))
	return paths


## Called after [member poles] changed.
func _poles_changed() -> void:
	pass


func _update_id() -> void:
	id = "%s:%s" % [designation, "-".join(get_terminal_names())]
