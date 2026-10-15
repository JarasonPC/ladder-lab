class_name PoleDevice
extends CircuitComponent
## Three-pole device in the power circuit, terminals 1-2, 3-4, 5-6 (one pole
## each, ČSN EN 60947 marking). Id "<designation>:1-2-3-4-5-6".


func default_terminal_names() -> PackedStringArray:
	return PackedStringArray(["1", "2", "3", "4", "5", "6"])


func switch_paths() -> Array[Vector2i]:
	return [Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5)]


func _update_id() -> void:
	id = "%s:%s" % [designation, "-".join(get_terminal_names())]
