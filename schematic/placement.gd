class_name Placement
extends RefCounted
## Where a component sits on the schematic grid and how it is turned.
## The symbol is first mirrored (x -> -x) if [member mirrored], then rotated.

## Grid cell of the component origin (its first terminal).
var cell: Vector2i
## Clockwise quarter turns, 0..3.
var rotation: int
var mirrored: bool


func _init(p_cell: Vector2i = Vector2i.ZERO, p_rotation: int = 0, p_mirrored: bool = false) -> void:
	cell = p_cell
	rotation = posmod(p_rotation, 4)
	mirrored = p_mirrored
