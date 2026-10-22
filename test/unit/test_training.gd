extends GutTest
## Training plans: the student's wires saved with the schematic, and the
## check of them against the schematic (see [TrainingCheck]).


func _plan(doc: SchematicDocument) -> SchematicDocument:
	doc.training = TrainingPlan.new()
	return doc


## [param doc] with the wires that make its plan right.
func _solved(doc: SchematicDocument) -> SchematicDocument:
	_plan(doc)
	var wires: Dictionary[String, Array] = TrainingCheck.solution(doc)
	for place: String in wires:
		for wire: PackedStringArray in wires[place]:
			doc.training.add_wire(place, wire[0], wire[1])
	return doc


func _texts(result: Dictionary) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for problem: Dictionary in result["problems"]:
		texts.append(str(problem["text"]) % problem["args"])
	return texts


func test_plan_saved_with_the_schematic() -> void:
	var doc: SchematicDocument = _plan(ExampleCircuits.build(0))
	doc.training.show_errors = false
	assert_true(doc.training.add_wire("+RA1", "t:KM1:13", "s:X2:3"))
	assert_false(doc.training.add_wire("+RA1", "s:X2:3", "t:KM1:13"), "the same wire again")
	assert_false(doc.training.add_wire("+RA1", "s:X2:3", "s:X2:3"), "a wire into its own terminal")
	var loaded: SchematicDocument = ProjectFile.from_dict(JSON.parse_string(JSON.stringify(ProjectFile.to_dict(doc))))["document"]
	assert_not_null(loaded.training)
	assert_false(loaded.training.show_errors)
	assert_eq(loaded.training.wires_of("+RA1"), [PackedStringArray(["t:KM1:13", "s:X2:3"])] as Array[PackedStringArray])
	var plain: SchematicDocument = ProjectFile.from_dict(ProjectFile.to_dict(ExampleCircuits.build(0)))["document"]
	assert_null(plain.training, "an ordinary schematic")


func test_places_and_ports() -> void:
	var all: Dictionary[String, Dictionary] = TrainingCheck.ports(ExampleCircuits.build(0))
	for id: String in ["+RA1|t:KM1:A1", "+RA1|s:X2:1", "+RA1|f:X2:1", "+RA1|t:FA1:1", "+ST1|t:SB0:11", "+ST1|t:H1:X1"]:
		assert_true(all.has(id), id)
	var cores: int = 0
	var supply: PackedStringArray = PackedStringArray()
	for id: String in all:
		if id.begins_with("+RA1|c:"):
			cores += 1
		if id.begins_with("+RA1|p:"):
			supply.append(all[id]["name"])
	assert_true(cores > 0, "the cores of the cables to the station and the motor")
	assert_eq(supply.size(), 5, "L1 L2 L3 N PE come in: %s" % ", ".join(supply))


func test_right_wiring_passes() -> void:
	var problems: PackedStringArray = PackedStringArray()
	for i: int in ExampleCircuits.count():
		var result: Dictionary = TrainingCheck.run(_solved(ExampleCircuits.build(i)))
		for text: String in _texts(result):
			problems.append("example %d: %s" % [i, text])
	assert_eq(problems, PackedStringArray())


func test_nothing_wired_is_all_missing() -> void:
	var result: Dictionary = TrainingCheck.run(_plan(ExampleCircuits.build(0)))
	assert_false(result["ok"])
	assert_eq(result["wires"], 0)
	for problem: Dictionary in result["problems"]:
		assert_eq(problem["kind"], "missing")


func test_mistakes_are_found() -> void:
	var doc: SchematicDocument = _solved(ExampleCircuits.build(0))
	# One wire taken away.
	var place: String = "+RA1"
	var taken: PackedStringArray = doc.training.wires_of(place)[0]
	doc.training.remove_wire(place, 0)
	var result: Dictionary = TrainingCheck.run(doc)
	assert_false(result["ok"])
	assert_eq(result["problems"].size(), 1, "\n".join(_texts(result)))
	assert_eq(result["problems"][0]["kind"], "missing")
	doc.training.add_wire(place, taken[0], taken[1])
	assert_true(TrainingCheck.run(doc)["ok"])
	# A wire between two nets.
	doc.training.add_wire(place, "t:KM1:A1", "t:KM1:A2")
	result = TrainingCheck.run(doc)
	var kinds: Array = result["problems"].map(func(p: Dictionary) -> String: return p["kind"])
	assert_true(kinds.has("wrong"), "\n".join(_texts(result)))
	assert_eq(result["problems"].filter(func(p: Dictionary) -> bool: return p["kind"] == "wrong")[0]["ports"], PackedStringArray(["+RA1|t:KM1:A1", "+RA1|t:KM1:A2"]))
	# Three wires in a contactor's terminal.
	doc = _solved(ExampleCircuits.build(0))
	var crowded: String = ""
	for wire: PackedStringArray in doc.training.wires_of(place):
		for port: String in wire:
			if port.begins_with("t:KM1:"):
				crowded = port
	doc.training.add_wire(place, crowded, "t:KM1:A1")
	doc.training.add_wire(place, crowded, "t:KM1:A2")
	kinds = TrainingCheck.run(doc)["problems"].map(func(p: Dictionary) -> String: return p["kind"])
	assert_true(kinds.has("crowded"))


func test_right_wiring_passes_over_two_switchboards_and_a_door() -> void:
	var problems: PackedStringArray = PackedStringArray()
	for i: int in ExampleCircuits.count():
		var split: SchematicDocument = ExampleCircuits.build(i)
		var devices: PackedStringArray = CabinetDevices.devices(split)
		split.add_switchboard()
		var rail: CabinetRail = split.add_cabinet_rail(1)
		for r: CabinetRail in split.switchboards[0].rails:
			for item: CabinetItem in r.items.duplicate():
				if item.designation == "X2" or devices.find(item.designation) % 2 == 1:
					r.items.erase(item)
					rail.items.append(item)
		var door: SchematicDocument = ExampleCircuits.build(i)
		for box: ControlBox in door.control_boxes:
			door.switchboards[0].door.items.append_array(box.items)
		door.control_boxes.clear()
		for entry: Array in [["split", split], ["door", door]]:
			for text: String in _texts(TrainingCheck.run(_solved(entry[1]))):
				problems.append("example %d %s: %s" % [i, entry[0], text])
	assert_eq(problems, PackedStringArray())


func test_student_wires_laid_in_the_switchboard() -> void:
	for i: int in [0, 7, 9, 12, 14]:
		var doc: SchematicDocument = _solved(ExampleCircuits.build(i))
		var all: Dictionary[String, Dictionary] = TrainingCheck.ports(doc)
		var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
		var given: Array[PackedStringArray] = doc.training.wires_of("+RA1")
		var wiring: CabinetWiring = CabinetWiring.build_given(doc, layout, 2.0, 0, given)
		for id: String in all:
			if all[id]["place"] == "+RA1":
				assert_true(wiring.ports.has(all[id]["id"]), "example %d: port %s laid out" % [i, id])
		assert_eq(wiring.wires.size(), given.size(), "example %d: a wire for each pair" % i)
		assert_eq(wiring.pairs.size(), given.size())
		for wire: Dictionary in wiring.wires:
			assert_true((wire["points"] as PackedVector2Array).size() >= 2)


func test_student_wires_laid_in_stations_and_on_the_door() -> void:
	var doc: SchematicDocument = _solved(ExampleCircuits.build(9))
	var given: Array[PackedStringArray] = doc.training.wires_of("+ST1")
	var inside: StationInside = StationInside.build_given(doc, 0, given)
	assert_eq(inside.wires.size(), given.size())
	assert_eq(inside.pairs.size(), given.size())
	var all: Dictionary[String, Dictionary] = TrainingCheck.ports(doc)
	for id: String in all:
		if all[id]["place"] == "+ST1":
			assert_true(inside.ports.has(all[id]["id"]), id)
	var door: SchematicDocument = ExampleCircuits.build(9)
	for box: ControlBox in door.control_boxes:
		door.switchboards[0].door.items.append_array(box.items)
	door.control_boxes.clear()
	_solved(door)
	var layout: CabinetLayout = CabinetLayout.build(door, 2.0)
	var back: StationInside = StationInside.build_door_given(door, 0, layout.size, -1.0, door.training.wires_of("+RA1/door"))
	assert_false(back.wires.is_empty())
	assert_eq(back.wires.size(), door.training.wires_of("+RA1/door").size())
	all = TrainingCheck.ports(door)
	for id: String in all:
		if all[id]["place"] == "+RA1/door":
			assert_true(back.ports.has(all[id]["id"]), id)


func _click(view: Control, at: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	view.call("_gui_input", press)


func test_wires_laid_by_clicking_in_the_switchboard() -> void:
	var doc: SchematicDocument = _plan(ExampleCircuits.build(0))
	var view: CabinetView = CabinetView.new()
	view.document = doc
	view.wiring_mode = true
	view.size = Vector2(900, 1400)
	add_child_autofree(view)
	await wait_process_frames(3)
	var wiring: CabinetWiring = view.get("_wiring")
	var origin: Vector2 = view.get("_painted_origin")
	var k: float = view.get("_painted_k")
	assert_true(wiring.ports.has("t:KM1:A2"))
	var drawn: Array = []
	view.wire_drawn.connect(func(place: String, a: String, b: String) -> void: drawn.append([place, a, b]))
	_click(view, origin + wiring.ports["t:KM1:A2"] * k)
	_click(view, origin + wiring.ports["s:X1:N"] * k)
	assert_eq(drawn, [["+RA1", "t:KM1:A2", "s:X1:N"]], "a click on each terminal lays a wire")
	doc.training.add_wire("+RA1", "t:KM1:A2", "s:X1:N")
	view.refresh()
	await wait_process_frames(3)
	wiring = view.get("_wiring")
	origin = view.get("_painted_origin")
	k = view.get("_painted_k")
	assert_eq(wiring.wires.size(), 1)
	var points: PackedVector2Array = wiring.wires[0]["points"]
	var removed: Array = []
	view.wire_removed.connect(func(place: String, index: int) -> void: removed.append([place, index]))
	# Picked by a click on it, taken away by Delete.
	_click(view, origin + (points[0] + points[1]) * 0.5 * k)
	var delete: InputEventKey = InputEventKey.new()
	delete.keycode = KEY_DELETE
	delete.pressed = true
	view.call("_gui_input", delete)
	assert_eq(removed, [["+RA1", 0]])
