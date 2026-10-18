extends GutTest
## Mechanical links: a motor moves a part (a gate) between its ends and the
## part operates the limit switches where they are.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC


## L through the NC contact of SQ2 (closed end) to motor M1, back to N; the
## gate group G1 holds M1, SQ1 (open end, 0) and SQ2 (closed end, 1).
func _doc() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("gate")
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 20))
	doc.add(LimitSwitch.new("SQ1", NO), Vector2i(8, 6))
	doc.add(LimitSwitch.new("SQ2", NC), Vector2i(0, 6))
	doc.add(Motor.new("M1"), Vector2i(0, 12))
	doc.connect_terminals("L", "SQ2:11")
	doc.connect_terminals("SQ2:12", "M1:U1")
	doc.connect_terminals("M1:U2", "N")
	doc.add_group()
	for designation: String in ["M1", "SQ1", "SQ2"]:
		doc.place_field_device(designation, Vector2(0, 0), 0)
	assert_true(doc.set_group_link(0, "M1", 2.0, 0.0, {"SQ1": 0.0, "SQ2": 1.0}))
	return doc


func test_link_is_checked() -> void:
	var doc: SchematicDocument = _doc()
	assert_false(doc.set_group_link(0, "SQ1", 2.0, 0.0, {}), "a limit switch does not drive")
	assert_false(doc.set_group_link(0, "M9", 2.0, 0.0, {}), "only a motor of the group drives")
	assert_true(doc.set_group_link(0, "M1", 0.0, 2.0, {"SQ1": 0.5, "M1": 0.5, "X": 1.0}))
	var group: WorkspaceGroup = doc.groups[0]
	assert_eq([group.travel_time, group.start], [0.1, 1.0], "clamped")
	assert_eq(group.stops.keys(), ["SQ1"], "only limit switches of the group")
	assert_true(doc.set_group_link(0, "", 1.0, 0.0, {}), "the link can be taken off")
	assert_eq(Workspace.travels(doc).size(), 0)


func test_saved_loaded_and_renamed() -> void:
	var doc: SchematicDocument = _doc()
	var copy: SchematicDocument = DocumentSerializer.from_dict(JSON.parse_string(JSON.stringify(DocumentSerializer.to_dict(doc))))
	var group: WorkspaceGroup = copy.groups[0]
	assert_eq([group.drive, group.travel_time, group.start], ["M1", 2.0, 0.0])
	assert_eq(group.stops, {"SQ1": 0.0, "SQ2": 1.0})
	doc.replace_component("M1", Motor.new("M7"))
	assert_eq(doc.groups[0].drive, "M7", "a renamed motor still drives")


func test_gate_runs_to_its_end_and_stops() -> void:
	var doc: SchematicDocument = _doc()
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.travels = Workspace.travels(doc)
	var travel: Travel = sim.travels[0]
	sim.step()
	var sq1: LimitSwitch = doc.circuit.get_operator("SQ1") as LimitSwitch
	var sq2: LimitSwitch = doc.circuit.get_operator("SQ2") as LimitSwitch
	assert_true(sq1.switched_on, "the gate starts at the open end, on SQ1")
	assert_false(sq2.switched_on)
	assert_true((doc.circuit.get_component("M1") as Motor).energized, "the motor runs")
	for i: int in 10:
		sim.step(0.1)
	assert_almost_eq(travel.position, 0.5, 0.01, "halfway after 1 s of 2 s")
	assert_false(sq1.switched_on, "SQ1 let go")
	for i: int in 20:
		sim.step(0.1)
	assert_true(sq2.switched_on, "the closed end reached")
	assert_false((doc.circuit.get_component("M1") as Motor).energized, "SQ2 cut the motor off")
	assert_true(travel.position >= 1.0 - Travel.BAND)


func test_realistic_gate_stops_at_its_switch() -> void:
	var doc: SchematicDocument = _doc()
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.mode = Simulator.Mode.REALISTIC
	sim.travels = Workspace.travels(doc)
	sim.step()
	for i: int in 30:
		sim.step(0.1)
	var travel: Travel = sim.travels[0]
	assert_true((doc.circuit.get_operator("SQ2") as LimitSwitch).switched_on)
	assert_false((doc.circuit.get_component("M1") as Motor).energized)
	assert_almost_eq(travel.position, 1.0 - Travel.BAND, 0.005, "it stops where SQ2 is reached (the motor has no run-down)")


func test_travel_events() -> void:
	var travel: Travel = Travel.new("G1", null, 4.0, 0.5)
	assert_eq(travel.time_to_next_event(), INF, "no motor: it stands")
	var m: Motor = Motor.new("M1")
	m.energized = true
	travel.motor = m
	travel.add_switch(LimitSwitch.new("SQ1", NO), 0.75)
	assert_almost_eq(travel.time_to_next_event(), (0.75 - Travel.BAND - 0.5) * 4.0, 1e-6, "until it reaches SQ1")
	assert_true(travel.operated(0, 0.76))
	assert_false(travel.operated(0, 0.8))
