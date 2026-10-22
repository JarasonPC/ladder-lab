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
			doc.training.add_wire(place, wire[0], wire[1], wire[2], wire[3])
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
	assert_eq(loaded.training.wires_of("+RA1"), [PackedStringArray(["t:KM1:13", "s:X2:3", "CONTROL", ""])] as Array[PackedStringArray])
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
	doc.training.add_wire(place, taken[0], taken[1], taken[2], taken[3])
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
		for port: String in [wire[0], wire[1]]:
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


## The self-holding example as the student wired it ([param wires] a
## training plan's), simulated: whether KM1 holds after start was pressed
## and let go, and whether it pulled in while pressed.
func _runs(doc: SchematicDocument) -> Vector2i:
	var sim: SchematicDocument = ExamplePower.on(TrainingSim.build(doc))
	var simulator: Simulator = Simulator.new(sim.circuit)
	simulator.step()
	var start: PushButton = sim.circuit.get_operator("SB1") as PushButton
	start.press()
	simulator.step()
	var pulled: bool = sim.circuit.get_coil("KM1").energized
	start.release()
	simulator.step()
	return Vector2i(int(pulled), int(sim.circuit.get_coil("KM1").energized))


const ExamplePower = preload("res://test/unit/example_power.gd")


func test_simulated_as_the_student_wired_it() -> void:
	var doc: SchematicDocument = _solved(ExampleCircuits.build(0))
	var wires: int = doc.circuit.get_wires().size()
	assert_eq(_runs(doc), Vector2i(1, 1), "wired right: starts and holds")
	assert_eq(doc.circuit.get_wires().size(), wires, "the plan itself stays as drawn")
	assert_eq(_runs(_plan(ExampleCircuits.build(0))), Vector2i(0, 0), "nothing wired: nothing works")
	# The holding contact's wire left out: KM1 runs while start is held only.
	var holding: SchematicDocument = _solved(ExampleCircuits.build(0))
	var list: Array[PackedStringArray] = holding.training.wires_of("+RA1")
	for i: int in range(list.size() - 1, -1, -1):
		if list[i].has("t:KM1:14") and (list[i][0].begins_with("s:") or list[i][1].begins_with("s:") or list[i][0] == "t:KM1:A1" or list[i][1] == "t:KM1:A1"):
			holding.training.remove_wire("+RA1", i)
	assert_false(TrainingCheck.run(holding)["ok"])
	var result: Vector2i = _runs(holding)
	assert_eq(result.y, 0, "does not hold")


## Energized coils, lit lamps and motors with power of [param circuit] (designations).
func _state(circuit: Circuit) -> PackedStringArray:
	var on: PackedStringArray = PackedStringArray()
	for c: CircuitComponent in circuit.get_components():
		if (c is Coil and (c as Coil).energized) or (c is Lamp and (c as Lamp).energized) or (c is ThreePhaseMotor and (c as ThreePhaseMotor).ac_powered):
			on.append(c.designation)
	return on


func test_wired_right_it_works_as_the_schematic() -> void:
	for i: int in ExampleCircuits.count():
		var drawn: SchematicDocument = ExamplePower.on(ExampleCircuits.build(i))
		var wired: SchematicDocument = ExamplePower.on(TrainingSim.build(_solved(ExampleCircuits.build(i))))
		var a: Simulator = Simulator.new(drawn.circuit)
		var b: Simulator = Simulator.new(wired.circuit)
		a.step()
		b.step()
		assert_eq(_state(wired.circuit), _state(drawn.circuit), "example %d at rest" % i)
		for c: CircuitComponent in drawn.circuit.get_components():
			if not (c is PushButton) or drawn.circuit.get_operator(c.designation) != c:
				continue
			(c as PushButton).press()
			(wired.circuit.get_operator(c.designation) as PushButton).press()
			a.step()
			b.step()
			assert_eq(_state(wired.circuit), _state(drawn.circuit), "example %d, %s pressed" % [i, c.designation])
			(c as PushButton).release()
			(wired.circuit.get_operator(c.designation) as PushButton).release()
			a.step()
			b.step()
			assert_eq(_state(wired.circuit), _state(drawn.circuit), "example %d, %s let go" % [i, c.designation])


func test_colour_and_number_checked() -> void:
	var doc: SchematicDocument = _solved(ExampleCircuits.build(0))
	var place: String = "+RA1"
	# A wire between two terminals (not landing a core), N or the control phase.
	var index: int = -1
	var list: Array[PackedStringArray] = doc.training.wires_of(place)
	for i: int in list.size():
		if list[i][0].begins_with("t:") and list[i][1].begins_with("t:") and list[i][2] == "CONTROL":
			index = i
	assert_true(index >= 0)
	var wire: PackedStringArray = list[index]
	doc.training.set_look(place, index, "PE", wire[3])
	var result: Dictionary = TrainingCheck.run(doc)
	assert_eq(result["problems"].map(func(p: Dictionary) -> String: return p["kind"]), ["colour"], "\n".join(_texts(result)))
	doc.training.set_look(place, index, "CONTROL", "")
	assert_true(TrainingCheck.run(doc)["ok"] or wire[3].is_empty(), "no number: right unless the plan wants numbers")
	doc.training.numbers_required = true
	if not wire[3].is_empty():
		assert_eq(TrainingCheck.run(doc)["problems"].map(func(p: Dictionary) -> String: return p["kind"]), ["number"])
	doc.training.set_look(place, index, "CONTROL", "999")
	assert_true(TrainingCheck.run(doc)["problems"].any(func(p: Dictionary) -> bool: return p["kind"] == "number"), "a wrong number")
	var loaded: SchematicDocument = ProjectFile.from_dict(JSON.parse_string(JSON.stringify(ProjectFile.to_dict(doc))))["document"]
	assert_true(loaded.training.numbers_required)
	assert_eq(loaded.training.wires_of(place)[index], PackedStringArray([wire[0], wire[1], "CONTROL", "999"]))


func test_function_check_accepts_any_wiring_that_works() -> void:
	var doc: SchematicDocument = _solved(ExampleCircuits.build(0))
	doc.training.check_function = true
	assert_true(TrainingCheck.run(doc)["ok"], "wired as the schematic: works")
	# The holding contact left out: it no longer holds.
	var list: Array[PackedStringArray] = doc.training.wires_of("+RA1")
	for i: int in range(list.size() - 1, -1, -1):
		if list[i][0] == "t:KM1:14" or list[i][1] == "t:KM1:14":
			doc.training.remove_wire("+RA1", i)
	var result: Dictionary = TrainingCheck.run(doc)
	assert_false(result["ok"])
	var kinds: Array = result["problems"].map(func(p: Dictionary) -> String: return p["kind"])
	assert_eq(kinds, ["function"], "\n".join(_texts(result)))
	# Nothing wired: the first difference already when switching on (nothing works either way)
	# or when start is pressed.
	var empty: SchematicDocument = _plan(ExampleCircuits.build(0))
	empty.training.check_function = true
	assert_false(TrainingCheck.run(empty)["ok"])
	for i: int in ExampleCircuits.count():
		var solved: SchematicDocument = _solved(ExampleCircuits.build(i))
		solved.training.check_function = true
		assert_true(TrainingCheck.run(solved)["ok"], "example %d: %s" % [i, "\n".join(_texts(TrainingCheck.run(solved)))])


func test_checks_and_start_kept_with_the_plan() -> void:
	var doc: SchematicDocument = _plan(ExampleCircuits.build(0))
	doc.training.check_function = true
	doc.training.started = 1700000000
	doc.training.history.append({"at": 1700000600, "ok": false, "mistakes": 3})
	var loaded: SchematicDocument = ProjectFile.from_dict(JSON.parse_string(JSON.stringify(ProjectFile.to_dict(doc))))["document"]
	assert_true(loaded.training.check_function)
	assert_eq(loaded.training.started, 1700000000)
	assert_eq(loaded.training.history, [{"at": 1700000600, "ok": false, "mistakes": 3}] as Array[Dictionary])


## The cables of [param doc]: "name a b cores" each.
func _cable_list(doc: SchematicDocument) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for cable: Dictionary in WorkspaceCables.cables(doc):
		result.append("%s %s %s %d" % [cable["name"], cable["a"], cable["b"], cable["cores"].size()])
	return result


## Mounts the parts of [param doc]'s plan as the student would, each place's
## in the other order (a switchboard's on its first rail).
func _mount(doc: SchematicDocument) -> void:
	for b: int in doc.switchboards.size():
		var here: String = "+" + doc.switchboards[b].name
		var items: Array = doc.training.layout.get(here, []).duplicate()
		items.reverse()
		for data: Dictionary in items:
			var item: CabinetItem = CabinetItem.from_data(data)
			assert_not_null(doc.add_cabinet_item(b, 0, item.kind, item.designation), item.designation)
		_mount_panel(doc, doc.door_panel(b), here + "/door")
	for k: int in doc.control_boxes.size():
		_mount_panel(doc, k, "+" + doc.control_boxes[k].name)


func _mount_panel(doc: SchematicDocument, panel: int, place: String) -> void:
	var items: Array = doc.training.layout.get(place, []).duplicate()
	items.reverse()
	for data: Dictionary in items:
		doc.add_control_item(panel, ControlBoxItem.KINDS.find(data["kind"]) as ControlBoxItem.Kind)
		assert_true(doc.set_control_item(panel, doc.control_panels()[panel].items.size() - 1, data))


func test_student_mounts_the_parts() -> void:
	for i: int in ExampleCircuits.count():
		var drawn: SchematicDocument = ExampleCircuits.build(i)
		var doc: SchematicDocument = _plan(ExampleCircuits.build(i))
		doc.training.take_parts(doc)
		doc = ProjectFile.from_dict(JSON.parse_string(JSON.stringify(ProjectFile.to_dict(doc))))["document"]
		assert_true(doc.training.mount_parts, "kept with the plan")
		var parts: int = 0
		for place: String in doc.training.layout:
			parts += doc.training.layout[place].size()
		assert_true(parts > 0)
		for board: Switchboard in doc.switchboards:
			assert_false(board.rails.is_empty(), "the rails stay")
			for rail: CabinetRail in board.rails:
				assert_true(rail.items.is_empty(), "taken off the rails")
			assert_true(board.door.items.is_empty())
		for box: ControlBox in doc.control_boxes:
			assert_true(box.items.is_empty(), "taken off the stations")
		assert_eq(_cable_list(doc), _cable_list(drawn), "the cables laid as the plan has them")
		var mounts: int = 0
		for problem: Dictionary in TrainingCheck.run(doc)["problems"]:
			if problem["kind"] == "mount":
				mounts += 1
		assert_eq(mounts, parts, "every part still to mount")
		_mount(doc)
		assert_eq(_cable_list(doc), _cable_list(drawn))
		var wires: Dictionary[String, Array] = TrainingCheck.solution(doc)
		for place: String in wires:
			for wire: PackedStringArray in wires[place]:
				doc.training.add_wire(place, wire[0], wire[1], wire[2], wire[3])
		var result: Dictionary = TrainingCheck.run(doc)
		assert_true(result["ok"], "example %d mounted in another order and wired: %s" % [i, "; ".join(_texts(result))])


func test_wires_go_with_a_part_taken_off() -> void:
	var doc: SchematicDocument = _plan(ExampleCircuits.build(0))
	doc.training.take_parts(doc)
	_mount(doc)
	var wires: Dictionary[String, Array] = TrainingCheck.solution(doc)
	for place: String in wires:
		for wire: PackedStringArray in wires[place]:
			doc.training.add_wire(place, wire[0], wire[1], wire[2], wire[3])
	var before: int = doc.training.wire_count()
	var rail: CabinetRail = doc.switchboards[0].rails[0]
	var at: int = -1
	for k: int in rail.items.size():
		if rail.items[k].designation == "KM1":
			at = k
	assert_true(at >= 0)
	doc.remove_cabinet_item(0, 0, at)
	TrainingCheck.drop_loose_wires(doc)
	assert_true(doc.training.wire_count() < before, "the wires to -KM1 are gone")
	for wire: PackedStringArray in doc.training.wires_of("+RA1"):
		assert_false(wire[0].begins_with("t:KM1:") or wire[1].begins_with("t:KM1:"), " – ".join(wire))
	assert_true(_texts(TrainingCheck.run(doc)).has("-KM1 is not mounted yet (+RA1)."))


## The OptionButtons in [param node] whose first item is "Add…".
func _add_choices(node: Node) -> Array[OptionButton]:
	var result: Array[OptionButton] = []
	for child: Node in node.find_children("*", "OptionButton", true, false):
		var option: OptionButton = child as OptionButton
		if option.item_count > 1 and option.get_item_text(0) == "Add…":
			result.append(option)
	return result


func test_parts_mounted_with_the_panels_tools() -> void:
	var doc: SchematicDocument = _plan(ExampleCircuits.build(0))
	doc.training.take_parts(doc)
	var edits: Array[Callable] = []
	var board: CabinetPanel = CabinetPanel.new()
	board.board_name = doc.switchboards[0].name
	board.size = Vector2(1200, 900)
	add_child_autofree(board)
	board.edit_requested.connect(func(change: Callable) -> void: edits.append(change))
	board.set_document(doc, false)
	await wait_process_frames(2)
	var choices: Array[OptionButton] = _add_choices(board)
	assert_eq(choices.size(), doc.switchboards[0].rails.size(), "an Add… on each rail")
	var left: int = doc.training.unmounted(doc, "+RA1").size()
	assert_eq(choices[0].item_count, left + 1)
	choices[0].item_selected.emit(1)
	assert_eq(edits.size(), 1)
	edits[0].call(doc)
	board.refresh()
	await wait_process_frames(2)
	assert_eq(doc.training.unmounted(doc, "+RA1").size(), left - 1, "one part mounted")
	var station: StationPanel = StationPanel.new()
	station.station_name = doc.control_boxes[0].name
	station.size = Vector2(1200, 900)
	add_child_autofree(station)
	station.edit_requested.connect(func(change: Callable) -> void: edits.append(change))
	station.set_document(doc, false)
	await wait_process_frames(2)
	assert_false(station.inside_shown, "the front, where the parts are mounted")
	var on_station: Array[OptionButton] = _add_choices(station)
	assert_eq(on_station.size(), 1)
	var place: String = "+" + doc.control_boxes[0].name
	var to_mount: int = doc.training.unmounted(doc, place).size()
	on_station[0].item_selected.emit(1)
	edits[1].call(doc)
	assert_eq(doc.training.unmounted(doc, place).size(), to_mount - 1)
	assert_eq(doc.control_boxes[0].items[0].to_data(), doc.training.layout[place][0], "as the plan has it")


func test_multimeter_on_the_student_wiring() -> void:
	var doc: SchematicDocument = _solved(ExampleCircuits.build(0))
	var copy: SchematicDocument = ExamplePower.on(TrainingSim.build(doc))
	var sim: Simulator = Simulator.new(copy.circuit)
	sim.step()
	var keys: Dictionary[String, String] = copy.training.probe_keys
	for id: String in ["+RA1|t:KM1:A1", "+RA1|t:KM1:A2", "+RA1|p:" + CabinetDevices.supply_key(_l1(doc)), "+ST1|t:SB1:13", "+ST1|t:SB1:14"]:
		assert_false(keys.get(id, "").is_empty(), id)
	var l1: String = keys["+RA1|p:" + CabinetDevices.supply_key(_l1(doc))]
	assert_almost_eq(Multimeter.volts(sim, keys["+ST1|t:SB1:13"], keys["+ST1|t:SB1:14"])["volts"], 230.0, 1.0, "across the open start button")
	assert_almost_eq(Multimeter.volts(sim, l1, keys["+RA1|t:KM1:A2"])["volts"], 230.0, 1.0)


func _l1(doc: SchematicDocument) -> PowerSupply:
	for c: CircuitComponent in doc.circuit.get_components():
		if c is PowerSupply and (c as PowerSupply).conductor == PowerSupply.Conductor.L:
			return c as PowerSupply
	return null
