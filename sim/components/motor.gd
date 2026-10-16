class_name Motor
extends Load
## Motor as a simple load (designation "M1", terminals U1-U2).


func _init(p_designation: String) -> void:
	super(p_designation, "U1", "U2")


func rated_draw() -> float:
	return 2.0
