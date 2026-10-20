extends GutTest
## The floor plan of a residential installation: parts put on it onto a
## circuit of the single-line diagram, the lighting drawn on it and wired
## from it (one-way switches, two rockers, a staircase with an intermediate
## switch), outlets tagged with their circuit, rooms with their number,
## environment and illuminance.


func after_all() -> void:
	RecoveryFile.forget()


func _component(template: Dictionary, designation: String) -> CircuitComponent:
	var data: Dictionary = template.duplicate()
	data["designation"] = designation
	return DocumentSerializer.component_from_dict(data)


## A residential installation with FA1 (B10, lighting) and FA2 (B16, sockets).
func _house() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Hall", Rect2(0, 0, 3, 2)))
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Bathroom", Rect2(3, 0, 2.5, 2)))
	assert_true(doc.single_line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 10.0}, "FA1"), 0))
	assert_true(doc.single_line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 16.0}, "FA2"), 1))
	return doc


## Adds [param template] as [param designation] on circuit [param feeder], placed at [param at].
func _put(doc: SchematicDocument, template: Dictionary, designation: String, feeder: String, at: Vector2) -> void:
	assert_true(doc.single_line.add(doc, _component(template, designation), 0, -1, feeder))
	doc.floor_plan.place(designation, at, template["type"] == "luminaire")


func _simulate(doc: SchematicDocument) -> Simulator:
	for c: CircuitComponent in doc.circuit.get_components():
		if c is CircuitBreaker:
			(c as CircuitBreaker).switched_on = true
		elif c is CamSwitch:
			(c as CamSwitch).position = CamSwitch.ONE
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.step()
	return sim


func _lit(doc: SchematicDocument, designation: String) -> bool:
	return (doc.circuit.get_component(designation) as Luminaire).energized


func test_one_way_and_two_rockers() -> void:
	var doc: SchematicDocument = _house()
	_put(doc, {"type": "light_switch", "circuit": "1"}, "SF1", "FA1", Vector2(0.1, 1.0))
	_put(doc, {"type": "luminaire"}, "EA1", "FA1", Vector2(1.5, 1.0))
	_put(doc, {"type": "luminaire"}, "EA2", "FA1", Vector2(2.5, 1.0))
	_put(doc, {"type": "light_switch", "circuit": "5"}, "SF2", "FA1", Vector2(3.1, 1.0))
	_put(doc, {"type": "luminaire"}, "EA3", "FA1", Vector2(4.0, 0.5))
	_put(doc, {"type": "luminaire"}, "EA4", "FA1", Vector2(4.0, 1.5))
	_put(doc, {"type": "luminaire"}, "EA5", "FA1", Vector2(2.0, 0.3))
	var plan: FloorPlan = doc.floor_plan
	assert_true(plan.add_link("SF1", 0, "EA1", 0))
	assert_true(plan.add_link("EA1", 0, "EA2", 0), "a luminaire lit with another")
	assert_false(plan.add_link("EA1", 0, "EA2", 0), "not twice")
	assert_true(plan.add_link("SF2", 0, "EA3", 0))
	assert_true(plan.add_link("SF2", 1, "EA4", 0), "the second rocker")
	doc.update_single_line()
	var sim: Simulator = _simulate(doc)
	assert_false(_lit(doc, "EA1"), "switched off at the start")
	assert_false(_lit(doc, "EA2"))
	assert_true(_lit(doc, "EA5"), "a luminaire no switch is drawn to is always on")
	(doc.circuit.get_component("SF1") as LightSwitch).toggle()
	sim.step()
	assert_true(_lit(doc, "EA1"))
	assert_true(_lit(doc, "EA2"), "lit with EA1")
	(doc.circuit.get_component("SF2") as LightSwitch).toggle(1)
	sim.step()
	assert_false(_lit(doc, "EA3"))
	assert_true(_lit(doc, "EA4"), "the second rocker lights the second luminaire")


func test_staircase_with_an_intermediate_switch() -> void:
	var doc: SchematicDocument = _house()
	_put(doc, {"type": "light_switch", "circuit": "6"}, "SF1", "FA1", Vector2(0.1, 1.0))
	_put(doc, {"type": "light_switch", "circuit": "7"}, "SF2", "FA1", Vector2(1.5, 0.0))
	_put(doc, {"type": "light_switch", "circuit": "6"}, "SF3", "FA1", Vector2(2.9, 1.0))
	_put(doc, {"type": "luminaire"}, "EA1", "FA1", Vector2(1.5, 1.0))
	var plan: FloorPlan = doc.floor_plan
	plan.add_link("SF1", 0, "SF2", 0)
	plan.add_link("SF2", 0, "SF3", 0)
	plan.add_link("SF3", 0, "EA1", 0)
	doc.update_single_line()
	var sim: Simulator = _simulate(doc)
	assert_false(_lit(doc, "EA1"), "all at rest: off")
	var expected: bool = false
	for designation: String in ["SF1", "SF2", "SF3", "SF1", "SF3", "SF2"]:
		(doc.circuit.get_component(designation) as LightSwitch).toggle()
		sim.step()
		expected = not expected
		assert_eq(_lit(doc, "EA1"), expected, "every switch turns it over (%s)" % designation)


func test_parts_put_on_the_plan_onto_a_circuit_and_tagged() -> void:
	var doc: SchematicDocument = _house()
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.editing = true
	canvas.size = Vector2(800, 600)
	canvas.tool = FloorPlanCanvas.Tool.PLACE
	canvas.placing_template = {"type": "socket", "gangs": 2}
	canvas.circuit = "FA2"
	var edits: Array[Callable] = []
	canvas.edit_requested.connect(func(change: Callable) -> void: edits.append(change))
	canvas._press_at = canvas.to_screen(Vector2(1.0, 1.9))
	canvas._release({"kind": "new_part"}, canvas._press_at)
	canvas._release({"kind": "new_part"}, canvas.to_screen(Vector2(2.0, 1.9)))
	for change: Callable in edits:
		change.call(doc)
	doc.update_single_line()
	assert_eq(doc.single_line.feeder_of("FA2").loads, PackedStringArray(["XD1", "XD2"]), "on the circuit chosen")
	assert_eq(doc.floor_plan.parts.get("XD1", Vector2.ZERO), Vector2(1.0, 2.0), "onto the wall")
	assert_eq(doc.single_line.tag("XD2", doc.circuit), "Z 2.2", "circuit 2, the second outlet")
	assert_eq(doc.single_line.tag("FA1", doc.circuit), "")
	_simulate(doc)
	assert_true((doc.circuit.get_component("XD1") as SocketOutlet).energized, "wired to its circuit")


func test_rooms_and_links_saved_renamed_and_removed() -> void:
	var doc: SchematicDocument = _house()
	var plan: FloorPlan = doc.floor_plan
	assert_eq(plan.room_number(1), "102", "counted from 101")
	assert_eq(plan.room_environment(1), "ČSN 33 2000-7-701", "a bathroom")
	assert_eq(plan.room_environment(0), "N")
	assert_eq(plan.room_lux(0), "100", "a hall")
	plan.rooms[0].number = "1.01"
	plan.rooms[0].lux = "150"
	_put(doc, {"type": "light_switch", "circuit": "1"}, "SF1", "FA1", Vector2(0.1, 1.0))
	_put(doc, {"type": "luminaire"}, "EA1", "FA1", Vector2(1.5, 1.0))
	plan.add_link("SF1", 0, "EA1", 0)
	doc.update_single_line()
	var again: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(again.floor_plan.room_number(0), "1.01")
	assert_eq(again.floor_plan.room_lux(0), "150")
	assert_eq(again.floor_plan.links.size(), 1)
	assert_eq(again.get_wire_count(), doc.get_wire_count(), "wired the same from the plan")
	var sw: CircuitComponent = doc.circuit.get_component("SF1")
	assert_true(doc.replace_component(sw.id, _component(DocumentSerializer.component_to_dict(sw), "SF9")))
	assert_eq(plan.links[0].a, "SF9", "the link follows a rename")
	doc.remove_component(doc.circuit.get_component("EA1").id)
	assert_true(plan.links.is_empty(), "gone with its luminaire")
