class_name WireRoute
extends RefCounted
## Drawing route of one circuit wire: the grid corners between its two
## terminals. Segments are horizontal or vertical.

var corners: Array[Vector2i] = []
## Wire number shown at the wire ends ("" for none). All wires of one net
## (joined at terminals, junctions and terminal blocks) carry the same number.
var number: String = ""
## Offsets (in cells) of the number at the two ends, set by dragging it.
var number_offsets: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]


func _init(p_corners: Array[Vector2i] = []) -> void:
	corners = p_corners.duplicate()
