extends GutTest
## Potentiometers: terminals 1-2-3, turns and how finely a notch sets them,
## the wiper's volts on a PLC's analog input, files, the item on a control
## station and its inside (lugs with fastons, numbered wires).

var circuit: Circuit
var sim: Simulator


## + - supplies, compact CPU A1 on them, RP1 with 1 on -, 3 on + (unless
## [param fed] is false) and its wiper on AI0.
func _build(pot: Potentiometer, fed: bool = true) -> CompactPlc:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS))
	circuit.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS))
	var a1: CompactPlc = circuit.add(CompactPlc.new("A1", null, [], CompactPlc.Cpu.DI8_DQ6)) as CompactPlc
	circuit.add(pot)
	circuit.connect_terminals("+", "A1:L+")
	circuit.connect_terminals("A1:M", "-")
	circuit.connect_terminals("A1:2M", "-")
	circuit.connect_terminals("RP1:1", "-")
	if fed:
		circuit.connect_terminals("RP1:3", "+")
	circuit.connect_terminals("RP1:2", "A1:AI0")
	sim = Simulator.new(circuit)
	sim.step()
	return a1


func test_terminals_and_turns() -> void:
	var pot: Potentiometer = Potentiometer.new("RP1")
	assert_eq(pot.get_terminal_names(), PackedStringArray(["1", "2", "3"]), "the ends 1 and 3, the wiper 2")
	assert_eq(pot.turns, 1)
	assert_almost_eq(pot.step(), 0.01, 1e-9, "a single-turn one: a notch is 1 % of its 270°")
	pot.turns = 10
	assert_almost_eq(pot.step(), 0.00075, 1e-9, "ten turns: a notch is 0.075 %")
	assert_eq(pot.travel_degrees(), 3600.0)
	pot.turns = 3
	assert_eq(pot.turns, 1, "only 1, 2, 5 or 10 turns")
	pot.turns = 5
	pot.turn(40)
	assert_almost_eq(pot.setting, 40 * 2.7 / 1800.0, 1e-6)
	pot.turn(-10000)
	assert_eq(pot.setting, 0.0, "it stops at the end")
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(pot)
	assert_eq([cells["1"], cells["2"], cells["3"]], [Vector2i(0, 0), Vector2i(2, 2), Vector2i(0, 4)])


func test_wiper_on_an_analog_input() -> void:
	var pot: Potentiometer = Potentiometer.new("RP1")
	pot.setting = 0.25
	var a1: CompactPlc = _build(pot)
	assert_almost_eq(a1.analog_in[0], 6.0, 0.01, "a quarter of 24 V")
	assert_almost_eq(pot.volts, 6.0, 0.01)
	pot.turn(10)
	sim.step()
	assert_almost_eq(a1.analog_in[0], 8.4, 0.01, "ten notches on: 35 %")


func test_no_volts_without_both_ends() -> void:
	var pot: Potentiometer = Potentiometer.new("RP1")
	pot.setting = 0.5
	var a1: CompactPlc = _build(pot, false)
	assert_eq(pot.volts, -1.0, "3 has no voltage")
	assert_almost_eq(a1.analog_in[0], 0.0, 0.001)


func test_saved_and_loaded() -> void:
	var pot: Potentiometer = Potentiometer.new("RP2", 5)
	pot.setting = 0.375
	var d: Dictionary = DocumentSerializer.component_to_dict(pot)
	assert_eq(d["setting"], 37.5, "saved in per cent")
	var copy: Potentiometer = DocumentSerializer.component_from_dict(JSON.parse_string(JSON.stringify(d))) as Potentiometer
	assert_eq([copy.designation, copy.turns], ["RP2", 5])
	assert_almost_eq(copy.setting, 0.375, 1e-6)
	var odd: Potentiometer = DocumentSerializer.component_from_dict({"type": "pot", "designation": "RP3", "turns": 7, "setting": 250}) as Potentiometer
	assert_eq([odd.turns, odd.setting], [1, 1.0], "unknown turns and a setting past the end load as the nearest")


func test_on_a_control_station() -> void:
	var doc: SchematicDocument = SchematicDocument.new("pot")
	doc.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS), Vector2i(0, 0))
	doc.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS), Vector2i(0, 10))
	doc.add(Potentiometer.new("RP1", 10), Vector2i(0, 3))
	doc.add(Potentiometer.new("RP2"), Vector2i(6, 3))
	for designation: String in ["RP1", "RP2"]:
		doc.connect_terminals("+", designation + ":3")
		doc.connect_terminals(designation + ":1", "-")
	assert_eq(ControlBoxItem.kind_of(doc.circuit.get_component("RP1")), ControlBoxItem.Kind.POT)
	var unplaced: Array[Dictionary] = Workspace.unplaced(doc)
	assert_true(unplaced.any(func(e: Dictionary) -> bool: return e["designation"] == "RP1"), "not on a station yet")
	doc.add_control_box_for_all()
	var item: ControlBoxItem = doc.control_boxes[0].items[0]
	assert_eq([item.kind, item.designation], [ControlBoxItem.Kind.POT, "RP1"])
	var loaded: ControlBoxItem = ControlBoxItem.from_data({"kind": "pot", "designation": "RP1", "color": "red", "lamp": "H1"})
	assert_eq([loaded.color, loaded.lamp], ["black", ""], "a black knob, never lit")
	var inside: StationInside = StationInside.build(doc, 0)
	var block: Dictionary = inside.items[0]["blocks"][0]
	assert_eq(block["kind"], "POT")
	assert_eq(block["terminals"].map(func(t: Dictionary) -> String: return t["name"]), ["1", "2", "3"], "three lugs")
	for t: Dictionary in block["terminals"]:
		assert_true(t["top"])
		assert_lt(t["entry"].y, t["at"].y, "the wire leaves the top of the faston on the lug")
	var into_lugs: int = 0
	for wire: Dictionary in inside.wires:
		for end: int in 2:
			var tip: Vector2 = wire["points"][0] if end == 0 else wire["points"][wire["points"].size() - 1]
			if block["terminals"].any(func(t: Dictionary) -> bool: return t["entry"] == tip):
				into_lugs += 1
				assert_eq(wire["pins"][end], -1.0, "no ferrule in a faston")
	assert_eq(into_lugs, 2, "1 and 3 joined to the other potentiometer's")
	assert_true(inside.wires.all(func(w: Dictionary) -> bool: return not w["mark"].is_empty() or w["markers"].is_empty()), "numbered wires carry their sleeves")


func test_turned_while_simulating() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS), Vector2i(0, 0))
	doc.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS), Vector2i(0, 10))
	doc.add(Potentiometer.new("RP1"), Vector2i(0, 3))
	doc.connect_terminals("+", "RP1:3")
	doc.connect_terminals("RP1:1", "-")
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(doc, true)
	var pot: Potentiometer = view.document.circuit.get_component("RP1") as Potentiometer
	view.toggle_switch("RP1", 50)
	assert_almost_eq(pot.setting, 0.5, 1e-6, "fifty notches of a single-turn one: half way")
	assert_almost_eq(pot.volts, 12.0, 0.01)
	view.set_pot("RP1", 0.1)
	assert_almost_eq(pot.volts, 2.4, 0.01)


func test_workspace_tiles_by_kind() -> void:
	var optical: ProximitySensor = ProximitySensor.new("BG1")
	optical.sensing = ProximitySensor.Sensing.OPTICAL
	assert_eq(WorkspaceTile.of_part(ProximitySensor.new("BG2")), WorkspaceTile.Kind.INDUCTIVE)
	assert_eq(WorkspaceTile.of_part(optical), WorkspaceTile.Kind.LIGHT)
	assert_eq(WorkspaceTile.of_part(Transmitter.new("BL1", Transmitter.Quantity.LEVEL)), WorkspaceTile.Kind.LEVEL)
	assert_eq(WorkspaceTile.of_part(TemperatureSensor.new("BT1")), WorkspaceTile.Kind.TEMPERATURE)
	assert_eq(WorkspaceTile.of_part(LimitSwitch.new("SQ1", SwitchingElement.ContactType.NO)), WorkspaceTile.Kind.LIMIT_SWITCH)
	assert_eq(WorkspaceCanvas.field_title(WorkspaceTile.Kind.FLOW), "Flow")


func test_station_face_turns_it_by_the_wheel_and_a_drag() -> void:
	var doc: SchematicDocument = SchematicDocument.new("pot")
	doc.add(Potentiometer.new("RP1", 10), Vector2i(0, 3))
	doc.add_control_box_for_all()
	var face: ControlBoxView = ControlBoxView.new()
	face.document = doc
	face.simulating = true
	add_child_autofree(face)
	watch_signals(face)
	var at: Vector2 = Vector2(ControlBox.PAD_X + 100.0, ControlBox.PAD_TOP + ControlBox.ROW_H * 0.5)
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = at
	face._gui_input(wheel)
	assert_signal_emitted_with_parameters(face, "switch_toggled", ["RP1", 1])
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.shift_pressed = true
	face._gui_input(wheel)
	assert_signal_emitted_with_parameters(face, "switch_toggled", ["RP1", -ControlBoxView.COARSE])
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	face._gui_input(press)
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.relative = Vector2(0.0, -3.0 * ControlBoxView.DRAG_PX)
	drag.position = at
	face._gui_input(drag)
	assert_signal_emitted_with_parameters(face, "switch_toggled", ["RP1", 3])
