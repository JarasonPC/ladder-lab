class_name Lamp
extends Load
## Signal lamp (designation "H1", terminals X1-X2).


func _init(p_designation: String) -> void:
	super(p_designation, "X1", "X2")
