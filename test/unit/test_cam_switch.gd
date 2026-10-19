extends GutTest
## Rotary cam switches: 1-4 poles, positions 0-I or I-0-II (forward / off /
## reverse), how they switch, are saved, drawn and operated.

const CW := ThreePhaseMotor.Direction.CLOCKWISE
const CCW := ThreePhaseMotor.Direction.COUNTERCLOCKWISE
const CHANGEOVER := CamSwitch.Positions.CHANGEOVER


func test_terminals_and_paths() -> void:
	var on_off: CamSwitch = CamSwitch.new("RB1")
	assert_eq(on_off.get_terminal_names(), PackedStringArray(["1", "2", "3", "4", "5", "6"]))
	assert_eq(on_off.id, "RB1:1-2-3-4-5-6")
	var reversing: CamSwitch = CamSwitch.new("RB2", CHANGEOVER, 2)
	assert_eq(reversing.get_terminal_names(), PackedStringArray(["1", "1'", "2", "3", "3'", "4"]))
	assert_eq(reversing.switch_paths(), [Vector2i(2, 0), Vector2i(2, 1), Vector2i(5, 3), Vector2i(5, 4)] as Array[Vector2i])
	reversing.poles = 4
	assert_eq(reversing.get_terminal_names().size(), 12)


func test_positions_and_turning() -> void:
	var cam: CamSwitch = CamSwitch.new("RB1", CHANGEOVER, 1)
	assert_eq(cam.position, CamSwitch.OFF, "starts at 0")
	assert_false(cam.is_path_closed(0))
	assert_false(cam.is_path_closed(1))
	cam.turn(-1)
	assert_eq(cam.position, CamSwitch.ONE, "turned left to I")
	assert_true(cam.is_path_closed(0))
	assert_false(cam.is_path_closed(1), "never both sides")
	cam.turn(-1)
	assert_eq(cam.position, CamSwitch.ONE, "stops at its end")
	cam.turn(2)
	assert_eq(cam.position, CamSwitch.TWO, "through 0 to II")
	assert_true(cam.is_path_closed(1))
	# A click turns it on: 0, I, 0, II, 0 ...
	var seen: Array[int] = []
	cam.position = CamSwitch.OFF
	for i: int in 5:
		cam.step_on()
		seen.append(cam.position)
	assert_eq(seen, [CamSwitch.ONE, CamSwitch.OFF, CamSwitch.TWO, CamSwitch.OFF, CamSwitch.ONE])
	var on_off: CamSwitch = CamSwitch.new("RB2")
	on_off.position = CamSwitch.TWO
	assert_eq(on_off.position, CamSwitch.OFF, "0-I has no position II")
	on_off.step_on()
	assert_true(on_off.is_path_closed(2))
	on_off.turn(-1)
	assert_false(on_off.is_path_closed(0))


## A motor on an I-0-II switch: L1 L2 L3 on the commons, U V W on the I
## sides and U W V on the II sides.
func _reversing() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("cam")
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("L2", PowerSupply.Conductor.L2), Vector2i(3, 0))
	doc.add(PowerSupply.new("L3", PowerSupply.Conductor.L3), Vector2i(6, 0))
	doc.add(CamSwitch.new("RB1", CHANGEOVER, 3), Vector2i(0, 4))
	doc.add(ThreePhaseMotor.new("M1"), Vector2i(0, 12))
	for pair: Array in [["L1", "RB1:2"], ["L2", "RB1:4"], ["L3", "RB1:6"],
			["RB1:1", "M1:U1"], ["RB1:3", "M1:V1"], ["RB1:5", "M1:W1"],
			["RB1:1'", "M1:U1"], ["RB1:3'", "M1:W1"], ["RB1:5'", "M1:V1"]]:
		assert_true(doc.connect_terminals(pair[0], pair[1]), "%s - %s" % pair)
	return doc


func test_forward_off_reverse_runs_a_motor_both_ways() -> void:
	var doc: SchematicDocument = _reversing()
	var cam: CamSwitch = doc.circuit.get_component("RB1") as CamSwitch
	var motor: ThreePhaseMotor = doc.circuit.get_component("M1") as ThreePhaseMotor
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.step()
	assert_eq(motor.direction, ThreePhaseMotor.Direction.NONE, "0: off")
	cam.turn(-1)
	var r: StepResult = sim.step()
	assert_false(r.short_circuit)
	assert_eq(motor.direction, CW, "I: forward")
	cam.turn(2)
	r = sim.step()
	assert_false(r.short_circuit, "the I and II sides are never joined")
	assert_eq(motor.direction, CCW, "II: L2 and L3 swapped")
	cam.turn(-1)
	sim.step()
	assert_eq(motor.direction, ThreePhaseMotor.Direction.NONE)


func test_saved_and_loaded() -> void:
	var doc: SchematicDocument = _reversing()
	var cam: CamSwitch = doc.circuit.get_component("RB1") as CamSwitch
	var d: Dictionary = DocumentSerializer.component_to_dict(cam)
	assert_eq(d["type"], "cam_switch")
	assert_eq(d["positions"], "I-0-II")
	assert_eq(d["poles"], 3)
	var loaded: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	var again: CamSwitch = loaded.circuit.get_component("RB1") as CamSwitch
	assert_not_null(again)
	assert_eq(again.positions, CHANGEOVER)
	assert_eq(again.poles, 3)
	assert_eq(loaded.circuit.get_wires().size(), doc.circuit.get_wires().size(), "wires to the II sides too")
	var plain: CamSwitch = DocumentSerializer.component_from_dict({"type": "cam_switch", "designation": "RB3", "positions": "?", "poles": 9}) as CamSwitch
	assert_eq(plain.positions, CamSwitch.Positions.OFF_ON, "unknown positions load as 0-I")
	assert_eq(plain.poles, 3)


func test_geometry() -> void:
	var cam: CamSwitch = CamSwitch.new("RB1", CHANGEOVER, 2)
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(cam)
	assert_eq(cells["1"], Vector2i(0, 0))
	assert_eq(cells["1'"], Vector2i(2, 0))
	assert_eq(cells["2"], Vector2i(1, SymbolGeometry.SPAN))
	assert_eq(cells["3"], Vector2i(SymbolGeometry.CAM_CHANGEOVER_SPACING, 0))
	assert_eq(SymbolGeometry.local_lead_direction(cam, "2"), SymbolGeometry.DIR_UP)
	assert_eq(SymbolGeometry.local_lead_direction(cam, "3'"), SymbolGeometry.DIR_DOWN)
	var on_off: CamSwitch = CamSwitch.new("RB2", CamSwitch.Positions.OFF_ON, 4)
	assert_eq(SymbolGeometry.local_terminals(on_off)["8"], Vector2i(6, SymbolGeometry.SPAN))
	var body: Rect2 = SymbolGeometry.local_body(on_off)
	assert_true(body.has_point(Vector2(6.0, 1.5)), "covers the last pole")
	assert_true(body.has_point(Vector2(-1.4, 1.5)), "and the actuator")


func test_placed_from_the_palette_as_a_switch_rb() -> void:
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	var editor: SchematicEditor = SchematicEditor.new()
	editor.view = view
	add_child_autofree(editor)
	view.load_document(SchematicDocument.new("cam"), false)
	editor.active = true
	var template: Dictionary = {}
	for entry: Dictionary in Palette.ENTRIES:
		if entry["template"]["type"] == "cam_switch":
			template = entry["template"]
	assert_false(template.is_empty(), "in the palette")
	editor.begin_place(template)
	editor._mouse_point = Vector2(4, 4)
	editor._mouse_cell = Vector2i(4, 4)
	editor._on_left_pressed(false)
	editor._cancel_tool()
	var cam: CamSwitch = editor.document().circuit.get_component("RB1") as CamSwitch
	assert_not_null(cam, "designated RB1")
	assert_eq(cam.poles, 3)
	var symbol: SchematicSymbol = SymbolFactory.create(cam, editor.document().get_placement(cam.id))
	assert_true(symbol is CamSwitchSymbol)
	symbol.free()
	assert_eq(Palette.group_of(template), "buttons")


func test_on_a_station_and_turned_from_it() -> void:
	var doc: SchematicDocument = _reversing()
	assert_eq(ControlBoxItem.kind_of(doc.circuit.get_component("RB1")), ControlBoxItem.Kind.SWITCH)
	assert_true(doc.control_devices(ControlBoxItem.Kind.SWITCH).has("RB1"))
	assert_true(doc.can_have_key("RB1"))
	assert_eq(doc.circuit.get_operator("RB1"), doc.circuit.get_component("RB1"))
	var box: ControlBox = doc.add_control_box_for_all()
	assert_eq(box.items.size(), 1)
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(doc)
	var sim_cam: CamSwitch = view.document.circuit.get_component("RB1") as CamSwitch
	view.toggle_switch("RB1", 1)
	assert_eq(sim_cam.position, CamSwitch.TWO, "turned right to II")
	view.toggle_switch("RB1", -1)
	assert_eq(sim_cam.position, CamSwitch.OFF)
	view.toggle_switch("RB1")
	assert_eq(sim_cam.position, CamSwitch.ONE, "a key turns it on to the next position")


func test_datasheet() -> void:
	var sheet: Datasheet = Datasheet.of_template({"type": "cam_switch", "poles": 3, "positions": "I-0-II"})
	assert_eq(sheet.letters, "RB")
	assert_eq(sheet.terminals.size(), 9, "three rows a pole")
	assert_false(sheet.summary.is_empty())


## L - RB1 13-14 (operated in I) - H1 - N and L - RB1 23-24 (operated in
## II) - H2 - N: an I-0-II selector switch.
func _selector() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("selector")
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 14))
	for i: int in 2:
		var block: LatchingSwitch = LatchingSwitch.new("RB1", SwitchingElement.ContactType.NO, i + 1)
		block.three_positions = true
		block.side = i + 1
		doc.add(block, Vector2i(4 + 4 * i, 2))
		doc.add(Lamp.new("H%d" % (i + 1)), Vector2i(4 + 4 * i, 8))
		doc.connect_terminals("L", "RB1:%d3" % (i + 1))
		doc.connect_terminals("RB1:%d4" % (i + 1), "H%d:X1" % (i + 1))
		doc.connect_terminals("H%d:X2" % (i + 1), "N")
	return doc


func test_selector_switch_with_three_positions() -> void:
	var doc: SchematicDocument = _selector()
	var first: LatchingSwitch = doc.circuit.get_operator("RB1") as LatchingSwitch
	var h1: Lamp = doc.circuit.get_component("H1") as Lamp
	var h2: Lamp = doc.circuit.get_component("H2") as Lamp
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.step()
	assert_false(h1.energized or h2.energized, "0: neither block")
	first.turn(-1)
	sim.step()
	assert_true(h1.energized, "I operates the block of I")
	assert_false(h2.energized)
	first.turn(2)
	sim.step()
	assert_false(h1.energized)
	assert_true(h2.energized, "II the block of II")
	assert_eq(first.get_position(), 2)
	var seen: Array[int] = []
	first.set_position(0)
	for i: int in 4:
		first.toggle()
		seen.append(first.get_position())
	assert_eq(seen, [1, 0, 2, 0], "a click turns it on: I, 0, II, 0")
	var plain: LatchingSwitch = LatchingSwitch.new("RB2", SwitchingElement.ContactType.NO)
	plain.set_position(2)
	assert_eq(plain.get_position(), 0, "0-I has no position II")
	plain.toggle()
	assert_true(plain.switched_on)


func test_selector_switch_saved_and_turned_from_a_station() -> void:
	var doc: SchematicDocument = _selector()
	var d: Dictionary = DocumentSerializer.component_to_dict(doc.circuit.get_component("RB1:23-24"))
	assert_eq(d["positions"], "I-0-II")
	assert_eq(d["operated_in"], "II")
	assert_false(DocumentSerializer.component_to_dict(LatchingSwitch.new("RB2", SwitchingElement.ContactType.NO)).has("positions"), "0-I as before")
	var loaded: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	var block: LatchingSwitch = loaded.circuit.get_component("RB1:23-24") as LatchingSwitch
	assert_true(block.three_positions)
	assert_eq(block.side, 2)
	doc.add_control_box_for_all()
	doc.realistic_timing = false
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(doc)
	view.toggle_switch("RB1", 1)
	var shown: SchematicDocument = view.document
	assert_eq((shown.circuit.get_operator("RB1") as LatchingSwitch).get_position(), 2, "turned right to II")
	assert_true((shown.circuit.get_component("H2") as Lamp).energized)
	view.toggle_switch("RB1", -1)
	view.toggle_switch("RB1", -1)
	assert_true((shown.circuit.get_component("H1") as Lamp).energized, "on to I")
