class_name Rectifier
extends Load
## Full bridge rectifier (Graetz bridge, designation "TB1", ČSN EN 81346-2:
## TB converts AC to DC): AC input on ~1-~2, DC output on + and -.
## [member energized] tells that its input has voltage (two conductors of one
## source; the bridge rectifies DC of either polarity too). Then its + and -
## are poles of the DC source like the + and - supply points. The output is
## taken as isolated from the input (as behind a transformer).


func _init(p_designation: String) -> void:
	super(p_designation, "~1", "~2")


func default_terminal_names() -> PackedStringArray:
	return PackedStringArray(["~1", "~2", "+", "-"])
