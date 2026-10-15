class_name Placement
extends RefCounted
## Where a component sits on the schematic grid and how it is turned.
## The symbol is first mirrored (x -> -x) if [member mirrored], then rotated.

## Grid cell of the component origin (its first terminal).
var cell: Vector2i
## Clockwise quarter turns, 0..3.
var rotation: int
var mirrored: bool
## Page of the schematic the component is drawn on (see
## [member SchematicDocument.pages]).
var page: int = 0
## Markings moved by the user: marking key ("designation", "terminal:1",
## "purpose", "label") -> offset in cells on the drawing (upright).
var labels: Dictionary[String, Vector2] = {}
## Leads that end in a terminal of a terminal strip (drawn instead of the
## plain terminal square): terminal index -> its label, e.g. "4".
var strips: Dictionary[int, String] = {}


func _init(p_cell: Vector2i = Vector2i.ZERO, p_rotation: int = 0, p_mirrored: bool = false) -> void:
	cell = p_cell
	rotation = posmod(p_rotation, 4)
	mirrored = p_mirrored


## [member labels] as saved data: {key: [x, y]}.
func labels_to_data() -> Dictionary:
	var data: Dictionary = {}
	for key: String in labels:
		data[key] = [labels[key].x, labels[key].y]
	return data


## [member strips] as saved data: {"<index>": label}.
func strips_to_data() -> Dictionary:
	var data: Dictionary = {}
	for index: int in strips:
		data[str(index)] = strips[index]
	return data


## Reads [member strips] from [method strips_to_data] data; ignores anything malformed.
func strips_from_data(data: Variant) -> void:
	strips.clear()
	if not (data is Dictionary):
		return
	for key: Variant in data:
		if key is String and (key as String).is_valid_int() and int(key) >= 0 and data[key] is String:
			strips[int(key)] = data[key]


## Reads [member labels] from [method labels_to_data] data; ignores anything malformed.
func labels_from_data(data: Variant) -> void:
	labels.clear()
	if not (data is Dictionary):
		return
	for key: Variant in data:
		var v: Variant = data[key]
		if key is String and v is Array and (v as Array).size() == 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int):
			labels[key] = Vector2(float(v[0]), float(v[1]))
