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

## Colours a student's wire can have, by [enum CabinetDevices.Conductor]
## name: the control circuit's phase red, N light blue, the main power
## circuit grey, PE green-yellow.
const COLOURS: PackedStringArray = ["CONTROL", "NEUTRAL", "POWER", "PE"]

## The check lists the mistakes (else it only says whether the wiring is right).
var show_errors: bool = true
## The check wants every wire to carry its wire number on its sleeves (a
## number written is checked anyway).
var numbers_required: bool = false
## The student's wires: place ("+RA1", "+RA1/door", "+ST1") -> wires, each
## PackedStringArray([port, port, colour (of COLOURS; a core's own when
## landing a cable's core), number on its sleeves ("" none)]) (see
## [TrainingCheck] for the ports).
var wires: Dictionary[String, Array] = {}
## A copy simulated with the student's wires in place of the schematic's
## (see [TrainingSim]): the schematic as drawn, which the switchboards,
## stations and cables are laid out from (never saved).
var drawn: SchematicDocument = null


## The schematic [param doc]'s places are laid out from: the one drawn when
## [param doc] is a copy simulated with the student's wires, else [param doc].
static func drawn_of(doc: SchematicDocument) -> SchematicDocument:
	return doc.training.drawn if doc != null and doc.training != null and doc.training.drawn != null else doc


## Adds a wire between ports [param a] and [param b] of [param place] of
## [param colour] (one of [constant COLOURS]) with [param number] on its
## sleeves; false for a wire from a port to itself or one there already.
func add_wire(place: String, a: String, b: String, colour: String = "CONTROL", number: String = "") -> bool:
	if a == b or has_wire(place, a, b):
		return false
	if not wires.has(place):
		wires[place] = []
	wires[place].append(PackedStringArray([a, b, colour if COLOURS.has(colour) else COLOURS[0], number.strip_edges()]))
	return true


## Gives wire [param index] of [param place] [param colour] and
## [param number] on its sleeves.
func set_look(place: String, index: int, colour: String, number: String) -> void:
	var list: Array = wires.get(place, [])
	if index >= 0 and index < list.size():
		var wire: PackedStringArray = list[index]
		list[index] = PackedStringArray([wire[0], wire[1], colour if COLOURS.has(colour) else wire[2], number.strip_edges()])


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
			list.append(Array(wire))
		places[place] = list
	return {"show_errors": show_errors, "numbers_required": numbers_required, "wires": places}


## A plan from saved data (values of the wrong type are left out).
static func from_data(data: Variant) -> TrainingPlan:
	var plan: TrainingPlan = TrainingPlan.new()
	if not (data is Dictionary):
		return plan
	plan.show_errors = (data as Dictionary).get("show_errors", true) != false
	plan.numbers_required = (data as Dictionary).get("numbers_required", false) == true
	var places: Variant = (data as Dictionary).get("wires", {})
	if places is Dictionary:
		for place: Variant in places:
			var list: Variant = places[place]
			if not (list is Array):
				continue
			for wire: Variant in list:
				if wire is Array and (wire as Array).size() >= 2 and (wire as Array).all(func(v: Variant) -> bool: return v is String):
					plan.add_wire(str(place), wire[0], wire[1], wire[2] if wire.size() > 2 else COLOURS[0], wire[3] if wire.size() > 3 else "")
	return plan
