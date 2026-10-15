class_name WireRoute
extends RefCounted
## Drawing route of one circuit wire: the grid corners between its two
## terminals. Segments are horizontal or vertical.

var corners: Array[Vector2i] = []


func _init(p_corners: Array[Vector2i] = []) -> void:
	corners = p_corners.duplicate()
