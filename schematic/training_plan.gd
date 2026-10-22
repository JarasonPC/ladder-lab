class_name TrainingPlan
extends RefCounted
## A wiring exercise made of a schematic (saved as a training plan, .ladplan):
## the student sees the schematic, the switchboards with their devices and
## terminal strips, the doors and the control stations, all without wires,
## and wires them terminal to terminal (see [TrainingCheck]); the cables
## between the places are laid already, their cores still to be landed.
## Holds what the teacher chose and the student's wires. No nodes.

## Extension of a training plan file (a .ladder file holding a plan).
const EXTENSION: String = "ladplan"

## The check lists the mistakes (else it only says whether the wiring is right).
var show_errors: bool = true
## The student's wires: place ("+RA1", "+RA1/door", "+ST1") -> wires, each
## PackedStringArray([port, port]) (see [TrainingCheck] for the ports).
var wires: Dictionary[String, Array] = {}


## Adds a wire between ports [param a] and [param b] of [param place];
## false for a wire from a port to itself or one there already.
func add_wire(place: String, a: String, b: String) -> bool:
	if a == b or has_wire(place, a, b):
		return false
	if not wires.has(place):
		wires[place] = []
	wires[place].append(PackedStringArray([a, b]))
	return true


## Whether [param place] has a wire between [param a] and [param b] (either way).
func has_wire(place: String, a: String, b: String) -> bool:
	for wire: PackedStringArray in wires.get(place, []):
		if (wire[0] == a and wire[1] == b) or (wire[0] == b and wire[1] == a):
			return true
	return false


## Takes wire [param index] of [param place] away.
func remove_wire(place: String, index: int) -> void:
	var list: Array = wires.get(place, [])
	if index >= 0 and index < list.size():
		list.remove_at(index)
		if list.is_empty():
			wires.erase(place)


## The wires of [param place].
func wires_of(place: String) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	for wire: PackedStringArray in wires.get(place, []):
		result.append(wire)
	return result


## Number of wires in all places.
func wire_count() -> int:
	var count: int = 0
	for place: String in wires:
		count += wires[place].size()
	return count


func to_data() -> Dictionary:
	var places: Dictionary = {}
	for place: String in wires:
		var list: Array = []
		for wire: PackedStringArray in wires[place]:
			list.append([wire[0], wire[1]])
		places[place] = list
	return {"show_errors": show_errors, "wires": places}


## A plan from saved data (values of the wrong type are left out).
static func from_data(data: Variant) -> TrainingPlan:
	var plan: TrainingPlan = TrainingPlan.new()
	if not (data is Dictionary):
		return plan
	plan.show_errors = (data as Dictionary).get("show_errors", true) != false
	var places: Variant = (data as Dictionary).get("wires", {})
	if places is Dictionary:
		for place: Variant in places:
			var list: Variant = places[place]
			if not (list is Array):
				continue
			for wire: Variant in list:
				if wire is Array and (wire as Array).size() == 2 and wire[0] is String and wire[1] is String:
					plan.add_wire(str(place), wire[0], wire[1])
	return plan
