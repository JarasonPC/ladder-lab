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
## The check tests the function: the wiring is right when it works as the
## schematic does (see [TrainingFunction]), however it is wired; else when
## it joins what the schematic joins.
var check_function: bool = false
## Each check made: {"at" (Unix time), "ok", "mistakes"} (for the teacher).
var history: Array[Dictionary] = []
## When the first wire was laid (Unix time, 0 before).
var started: int = 0
## The student mounts the parts: the plan's rails, doors and stations start
## empty and [member layout] says what goes in each place.
var mount_parts: bool = false
## Where the teacher mounted the parts (with [member mount_parts]): place
## ("+RA1", "+RA1/door", "+ST1") -> its items in order, as saved by
## [method CabinetItem.to_data] (a switchboard's rails, the distribution
## blocks left out) or [method ControlBoxItem.to_data] (a door, a station).
var layout: Dictionary[String, Array] = {}
## A fault-finding task: the faults hidden in the wiring given (see
## [TrainingFaults]); the student's wires are then the plan's, never changed.
var faults: Array[Dictionary] = []
## The faults the student reported (as [member faults]) with "at" (Unix time).
var reports: Array[Dictionary] = []
## The student's wires: place ("+RA1", "+RA1/door", "+ST1") -> wires, each
## PackedStringArray([port, port, colour (of COLOURS; a core's own when
## landing a cable's core), number on its sleeves ("" none)]) (see
## [TrainingCheck] for the ports).
var wires: Dictionary[String, Array] = {}
## A copy simulated with the student's wires in place of the schematic's
## (see [TrainingSim]): the schematic as drawn, which the switchboards,
## stations and cables are laid out from (never saved).
var drawn: SchematicDocument = null
## In the copy simulated (see [member drawn]): the terminal key a
## multimeter's probe on each port ("place|port") touches, "" for none
## (never saved).
var probe_keys: Dictionary[String, String] = {}
## A copy with the parts mounted as [member layout] has them (see
## [method cabled_of]; never saved).
var _planned: SchematicDocument = null


## The schematic [param doc]'s places are laid out from: the one drawn when
## [param doc] is a copy simulated with the student's wires, else [param doc].
static func drawn_of(doc: SchematicDocument) -> SchematicDocument:
	return doc.training.drawn if doc != null and doc.training != null and doc.training.drawn != null else doc


## The schematic the cables of the workspace and the door harnesses are laid
## from: [method drawn_of] [param doc], or, where the student mounts the
## parts, a copy with them mounted where the plan has them: the cables are
## laid before, and stay as they are while the parts are mounted.
static func cabled_of(doc: SchematicDocument) -> SchematicDocument:
	doc = drawn_of(doc)
	if doc == null or doc.training == null or not doc.training.mount_parts:
		return doc
	if doc.training._planned == null:
		var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
		copy.training = null
		doc.training._mount_all(copy)
		doc.training._planned = copy
	return doc.training._planned


## Notes in [member layout] where the parts of [param doc] are mounted and
## takes them off its rails, doors and stations (the rails stay, empty),
## for the student to mount.
func take_parts(doc: SchematicDocument) -> void:
	mount_parts = true
	layout = {}
	for board: Switchboard in doc.switchboards:
		var here: String = "+" + board.name
		layout[here] = []
		for rail: CabinetRail in board.rails:
			for item: CabinetItem in rail.items:
				if item.kind != CabinetItem.Kind.BUS:
					layout[here].append(item.to_data())
			rail.items.clear()
		layout[here + "/door"] = _panel_data(board.door)
		board.door.items.clear()
	for box: ControlBox in doc.control_boxes:
		layout["+" + box.name] = _panel_data(box)
		box.items.clear()


## The items of [member layout] for [param place] not mounted there in
## [param doc] yet.
func unmounted(doc: SchematicDocument, place: String) -> Array[Dictionary]:
	var here: Dictionary[String, bool] = {}
	for data: Dictionary in mounted(doc, place):
		here[_item_key(data)] = true
	var result: Array[Dictionary] = []
	for data: Dictionary in layout.get(place, []):
		if not here.has(_item_key(data)):
			result.append(data)
	return result


## The items mounted in [param place] of [param doc] (as in [member layout]).
static func mounted(doc: SchematicDocument, place: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var name: String = place.trim_prefix("+").get_slice("/", 0)
	for board: Switchboard in doc.switchboards:
		if board.name != name:
			continue
		if place.ends_with("/door"):
			return _panel_data(board.door)
		for rail: CabinetRail in board.rails:
			for item: CabinetItem in rail.items:
				if item.kind != CabinetItem.Kind.BUS:
					result.append(item.to_data())
		return result
	for box: ControlBox in doc.control_boxes:
		if box.name == name:
			return _panel_data(box)
	return result


## The items of [param box] with a device, as saved.
static func _panel_data(box: ControlBox) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: ControlBoxItem in box.items:
		if not item.designation.is_empty():
			result.append(item.to_data())
	return result


static func _item_key(data: Dictionary) -> String:
	return str(data.get("kind", "")) + "|" + str(data.get("designation", ""))


## Mounts every part of [member layout] in [param doc] (a switchboard's on
## one rail: only where they are counts for the cables).
func _mount_all(doc: SchematicDocument) -> void:
	for board: Switchboard in doc.switchboards:
		var rail: CabinetRail = CabinetRail.new()
		for data: Variant in layout.get("+" + board.name, []):
			var item: CabinetItem = CabinetItem.from_data(data)
			if item != null:
				rail.items.append(item)
		board.rails = [rail]
		_fill_panel(board.door, layout.get("+" + board.name + "/door", []))
	for box: ControlBox in doc.control_boxes:
		_fill_panel(box, layout.get("+" + box.name, []))


static func _fill_panel(box: ControlBox, list: Array) -> void:
	box.items.clear()
	for data: Variant in list:
		var item: ControlBoxItem = ControlBoxItem.from_data(data)
		if item != null:
			box.items.append(item)


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
	var d: Dictionary = {"show_errors": show_errors, "numbers_required": numbers_required, "check_function": check_function, "history": history.duplicate(true), "started": started, "wires": places}
	if mount_parts:
		d["mount_parts"] = true
		d["layout"] = layout.duplicate(true)
	if not faults.is_empty():
		d["faults"] = faults.duplicate(true)
		d["reports"] = reports.duplicate(true)
	return d


## A fault-finding task: the wiring is given and stays as it is.
func locked() -> bool:
	return not faults.is_empty()


## A plan from saved data (values of the wrong type are left out).
static func from_data(data: Variant) -> TrainingPlan:
	var plan: TrainingPlan = TrainingPlan.new()
	if not (data is Dictionary):
		return plan
	plan.show_errors = (data as Dictionary).get("show_errors", true) != false
	plan.numbers_required = (data as Dictionary).get("numbers_required", false) == true
	plan.check_function = (data as Dictionary).get("check_function", false) == true
	var started_at: Variant = (data as Dictionary).get("started", 0)
	plan.started = int(started_at) if started_at is float or started_at is int else 0
	var checks: Variant = (data as Dictionary).get("history", [])
	if checks is Array:
		for check: Variant in checks:
			if not (check is Dictionary):
				continue
			var at: Variant = (check as Dictionary).get("at", null)
			var mistakes: Variant = (check as Dictionary).get("mistakes", 0)
			if at is float or at is int:
				plan.history.append({"at": int(at), "ok": (check as Dictionary).get("ok", false) == true, "mistakes": int(mistakes) if mistakes is float or mistakes is int else 0})
	for key: String in ["faults", "reports"]:
		var list: Variant = (data as Dictionary).get(key, [])
		if not (list is Array):
			continue
		for fault: Variant in list:
			if fault is Dictionary and (fault as Dictionary).get("kind", null) is String:
				(plan.faults if key == "faults" else plan.reports).append(fault)
	plan.mount_parts = (data as Dictionary).get("mount_parts", false) == true
	var mounts: Variant = (data as Dictionary).get("layout", {})
	if mounts is Dictionary:
		for place: Variant in mounts:
			if not (place is String) or not (mounts[place] is Array):
				continue
			var list: Array = []
			for item: Variant in mounts[place]:
				if item is Dictionary and (item as Dictionary).get("designation", null) is String:
					list.append(item)
			plan.layout[place] = list
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
