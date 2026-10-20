class_name LightSwitch
extends CircuitComponent
## Light switch of a house installation (vypínač, designation "SF1"), wired
## as Czech installations number them (řazení). One or two rockers, each
## switched over by a click; snap action, it moves at once.
##
## The common terminal is marked P (přívod), as on Czech wiring diagrams.
## [code]1[/code] one-way (jednopólový): P to 1 while on.
## [code]2[/code] two-pole (dvoupólový): 1-2 and 3-4 while on.
## [code]3[/code] three-pole (třípólový): 1-2, 3-4 and 5-6 while on.
## [code]5[/code] series (sériový, lustrový): two rockers on one common P,
## P to 1 by the first, P to 2 by the second.
## [code]5A[/code] one-way and two-way on one common P: P to 1 by the first
## rocker, P to 2 or 3 by the second.
## [code]5B[/code] double two-way (dvojitý střídavý) on one common P: P to 1
## or 2 by the first rocker, P to 3 or 4 by the second.
## [code]6[/code] two-way (střídavý, schodišťový): P to 1, switched over to 2.
## [code]7[/code] intermediate (křížový): 3 to 1 and 4 to 2, switched over
## crosswise to 3 to 2 and 4 to 1.

## Switch numbers (řazení) as saved and shown, in the order offered.
const CIRCUITS: PackedStringArray = ["1", "2", "3", "5", "5A", "5B", "6", "7"]
## Mounting height over the floor (m) when none is set: Czech practice
## (ČSN 33 2130) puts switches 1.2 m up, beside the door on the handle side.
const STANDARD_HEIGHT: float = 1.2

## Switch number (řazení), one of [constant CIRCUITS] (design data).
var circuit: String = "1":
	set(value):
		circuit = value if CIRCUITS.has(value) else "1"
		on.resize(rocker_count())
		_update_id()
## Mounting height over the floor in metres (design data).
var height: float = STANDARD_HEIGHT
## Each rocker switched over (on, or a two-way rocker on its second side).
## Simulation state; all off at the start.
var on: Array[bool] = [false]


func _init(p_designation: String, p_circuit: String = "1") -> void:
	super(p_designation)
	circuit = p_circuit


func default_terminal_names() -> PackedStringArray:
	match circuit:
		"2":
			return PackedStringArray(["1", "2", "3", "4"])
		"3":
			return PackedStringArray(["1", "2", "3", "4", "5", "6"])
		"5", "6":
			return PackedStringArray(["P", "1", "2"])
		"5A":
			return PackedStringArray(["P", "1", "2", "3"])
		"5B":
			return PackedStringArray(["P", "1", "2", "3", "4"])
		"7":
			return PackedStringArray(["1", "2", "3", "4"])
	return PackedStringArray(["P", "1"])


## Rockers it has: two for 5, 5A and 5B, else one.
func rocker_count() -> int:
	return 2 if circuit in ["5", "5A", "5B"] else 1


## Poles switched together by one rocker of a multi-pole switch (2 and 3),
## else 1.
func poles() -> int:
	return 2 if circuit == "2" else (3 if circuit == "3" else 1)


## Rocker [param rocker] is a two-way one (it switches over between two
## outputs rather than on and off).
func is_two_way(rocker: int) -> bool:
	match circuit:
		"6", "7", "5B":
			return true
		"5A":
			return rocker == 1
	return false


## Pairs of terminal indices it can join, in the order [method
## is_path_closed] takes them.
func switch_paths() -> Array[Vector2i]:
	match circuit:
		"2", "3":
			var paths: Array[Vector2i] = []
			for p: int in poles():
				paths.append(Vector2i(2 * p, 2 * p + 1))
			return paths
		"5", "6":
			return [Vector2i(0, 1), Vector2i(0, 2)]
		"5A":
			return [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]
		"5B":
			return [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)]
		"7":
			# Straight 3-1 and 4-2, crosswise 3-2 and 4-1.
			return [Vector2i(2, 0), Vector2i(3, 1), Vector2i(2, 1), Vector2i(3, 0)]
	return [Vector2i(0, 1)]


func is_path_closed(path: int) -> bool:
	match circuit:
		"2", "3":
			return on[0]
		"5":
			return on[path]
		"6":
			return on[0] == (path == 1)
		"5A":
			return on[0] if path == 0 else on[1] == (path == 2)
		"5B":
			return on[path / 2] == (path % 2 == 1)
		"7":
			return on[0] == (path >= 2)
	return on[0]


## Switches rocker [param rocker] over.
func toggle(rocker: int = 0) -> void:
	if rocker >= 0 and rocker < on.size():
		on[rocker] = not on[rocker]


func _update_id() -> void:
	id = "%s:%s" % [designation, "-".join(get_terminal_names())]
