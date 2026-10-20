class_name LightSwitch
extends CircuitComponent
## Light switch of a house installation (vypínač, designation "SF1"), wired
## and numbered as switches for fixed installations are (ČSN EN 60669-1,
## řazení). One or two rockers, each switched over by a click; snap action,
## it moves at once. Terminals as on the switch, the incoming ones first.
##
## [code]1[/code] one-way (jednopólový): 1 to 2 while on.
## [code]2[/code], [code]3[/code], [code]03[/code] two-, three- and
## four-pole: 1-2, 3-4 (5-6, 7-8) while on.
## [code]4[/code] two-way with an off position (přepínač s polohou vypnuto):
## 1 to 2, off, 1 to 3; a click turns it on to the next (2, off, 3, off).
## [code]5[/code] series (sériový, lustrový): two rockers on one incoming 1,
## 1 to 2 by the first, 1 to 3 by the second.
## [code]5B[/code] double two-way (6+6, dvojitý střídavý): two two-way
## rockers, 1 to 2 or 3 by the first, 4 to 5 or 6 by the second.
## [code]6[/code] two-way (střídavý, schodišťový): 1 to 2, switched over to 3.
## [code]6/2[/code] two-pole two-way: 1 to 3 and 2 to 4, switched over 1 to 5
## and 2 to 6.
## [code]7[/code] intermediate (křížový): 1 to 2 and 3 to 4, switched over
## crosswise 1 to 4 and 3 to 2.

## Switch numbers (řazení) as saved and shown, in the order offered.
const CIRCUITS: PackedStringArray = ["1", "2", "3", "03", "4", "5", "5B", "6", "6/2", "7"]
## Mounting height over the floor (m) when none is set: Czech practice
## (ČSN 33 2130) puts switches 1.2 m up, beside the door on the handle side.
const STANDARD_HEIGHT: float = 1.2
## Switch 4 off ([member position]).
const OFF: int = 0

## Switch number (řazení), one of [constant CIRCUITS] (design data).
var circuit: String = "1":
	set(value):
		circuit = value if CIRCUITS.has(value) else "1"
		on.resize(rocker_count())
		position = OFF
		_update_id()
## Each rocker switched over (on, or a two-way rocker on its second side).
## Simulation state; all off at the start.
var on: Array[bool] = [false]
## Switch 4: where its rocker is, [constant OFF], 1 (1 to 2) or 2 (1 to 3).
## Simulation state.
var position: int = OFF
## Mounting height over the floor in metres (design data).
var height: float = STANDARD_HEIGHT
## Switch 4 went off from 1 to 2 last: the next click goes on to 3.
var _from_one: bool = false


func _init(p_designation: String, p_circuit: String = "1") -> void:
	super(p_designation)
	circuit = p_circuit


func default_terminal_names() -> PackedStringArray:
	var count: int = 2
	match circuit:
		"2", "7":
			count = 4
		"3", "5B", "6/2":
			count = 6
		"03":
			count = 8
		"4", "5", "6":
			count = 3
	var names: PackedStringArray = PackedStringArray()
	for i: int in count:
		names.append(str(i + 1))
	return names


## Rockers it has: two for 5 and 5B, else one.
func rocker_count() -> int:
	return 2 if circuit in ["5", "5B"] else 1


## Poles switched together by the rocker of a multi-pole switch (2, 3, 03),
## else 1.
func poles() -> int:
	match circuit:
		"2":
			return 2
		"3":
			return 3
		"03":
			return 4
	return 1


## Pairs of terminal indices it can join, in the order [method
## is_path_closed] takes them.
func switch_paths() -> Array[Vector2i]:
	match circuit:
		"2", "3", "03":
			var paths: Array[Vector2i] = []
			for p: int in poles():
				paths.append(Vector2i(2 * p, 2 * p + 1))
			return paths
		"4", "5", "6":
			return [Vector2i(0, 1), Vector2i(0, 2)]
		"5B":
			return [Vector2i(0, 1), Vector2i(0, 2), Vector2i(3, 4), Vector2i(3, 5)]
		"6/2":
			return [Vector2i(0, 2), Vector2i(0, 4), Vector2i(1, 3), Vector2i(1, 5)]
		"7":
			# Straight 1-2 and 3-4, crosswise 1-4 and 3-2.
			return [Vector2i(0, 1), Vector2i(2, 3), Vector2i(0, 3), Vector2i(2, 1)]
	return [Vector2i(0, 1)]


func is_path_closed(path: int) -> bool:
	match circuit:
		"2", "3", "03":
			return on[0]
		"4":
			return position == path + 1
		"5":
			return on[path]
		"6", "6/2":
			return on[0] == (path % 2 == 1)
		"5B":
			return on[path / 2] == (path % 2 == 1)
		"7":
			return on[0] == (path >= 2)
	return on[0]


## Switches rocker [param rocker] over (switch 4 on to its next position:
## 2, off, 3, off).
func toggle(rocker: int = 0) -> void:
	if circuit == "4":
		if position == OFF:
			position = 2 if _from_one else 1
		else:
			_from_one = position == 1
			position = OFF
		return
	if rocker >= 0 and rocker < on.size():
		on[rocker] = not on[rocker]


func _update_id() -> void:
	id = "%s:%s" % [designation, "-".join(get_terminal_names())]
