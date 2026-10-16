extends GutTest
## Phase 7: three-phase supplies, main contacts, three-pole protection and
## three-phase motors (direction, star/delta, Dahlander, separate windings).

const NO := SwitchingElement.ContactType.NO
const K := ThreePhaseMotor.Kind
const ST := ThreePhaseMotor.State
const CW := ThreePhaseMotor.Direction.CLOCKWISE
const CCW := ThreePhaseMotor.Direction.COUNTERCLOCKWISE


## Breakers and fuse holders start switched off: these tests switch them on.
func _sim(doc: SchematicDocument, realistic: bool = false) -> Simulator:
	_switch_on_protection(doc)
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.mode = Simulator.Mode.REALISTIC if realistic else Simulator.Mode.IDEAL
	sim.step()
	return sim


func _switch_on_protection(doc: SchematicDocument) -> void:
	for c: CircuitComponent in doc.circuit.get_components():
		if c is Fuse or c is ThreePoleFuse or c is CircuitBreaker or c is MotorBreaker:
			c.set("switched_on", true)


## Steps [param seconds] in small steps; returns the event texts.
func _run(sim: Simulator, seconds: float, dt: float = 0.001) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	var t: float = 0.0
	while t < seconds - 1e-9:
		for e: Dictionary in sim.step(dt).events:
			texts.append(e["text"])
		t += dt
	return texts


func _press(doc: SchematicDocument, sim: Simulator, button: String, hold: float = 0.1) -> PackedStringArray:
	var b: PushButton = doc.circuit.get_component(button) as PushButton
	b.press()
	var texts: PackedStringArray = _run(sim, hold)
	b.release()
	texts.append_array(_run(sim, 0.1))
	return texts


func _motor(doc: SchematicDocument) -> ThreePhaseMotor:
	return doc.circuit.get_component("M1") as ThreePhaseMotor


func _three_supplies(doc: SchematicDocument) -> void:
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("L2", PowerSupply.Conductor.L2), Vector2i(2, 0))
	doc.add(PowerSupply.new("L3", PowerSupply.Conductor.L3), Vector2i(4, 0))


# --- Solver ---------------------------------------------------------------------

func test_coil_between_two_phases_pulls_in() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	_three_supplies(doc)
	doc.add(PowerSupply.new("L1.2", PowerSupply.Conductor.L), Vector2i(8, 0))
	doc.add(Coil.new("KM1"), Vector2i(0, 4))
	doc.add(Coil.new("KM2"), Vector2i(8, 4))
	doc.connect_terminals("L1", "KM1:A1")
	doc.connect_terminals("L2", "KM1:A2", [Vector2i(2, 7)] as Array[Vector2i])
	doc.connect_terminals("L1.2", "KM2:A1")
	doc.connect_terminals("L1", "KM2:A2", [Vector2i(0, 2), Vector2i(10, 2), Vector2i(10, 7), Vector2i(8, 7)] as Array[Vector2i])
	var r: StepResult = _sim(doc).last_result
	assert_true(doc.circuit.get_coil("KM1").energized, "400 V between L1 and L2")
	assert_false(doc.circuit.get_coil("KM2").energized, "L1 on both ends: no voltage")
	assert_false(r.short_circuit)
	assert_eq(r.terminal_reach["KM1:A1"], StepResult.REACH_L1)
	assert_eq(r.terminal_reach["KM1:A2"], StepResult.REACH_L2)


func test_phase_to_phase_short_is_found() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	_three_supplies(doc)
	var s1: LatchingSwitch = doc.add(LatchingSwitch.new("S1", NO), Vector2i(2, 3)) as LatchingSwitch
	doc.connect_terminals("L2", "S1:13")
	doc.connect_terminals("S1:14", "L3", [Vector2i(2, 7), Vector2i(4, 7)] as Array[Vector2i])
	var sim: Simulator = _sim(doc)
	assert_false(sim.last_result.short_circuit)
	s1.set_switched_on(true)
	var r: StepResult = sim.step()
	assert_true(r.short_circuit, "L2 - S1 - L3 is a short")
	assert_eq(r.short_circuit_path, PackedStringArray(["L2", "S1:13-14", "L3"]))


func test_motor_evaluation() -> void:
	var none: Array[bool] = [false, false, false]
	var star2: Array[bool] = [false, true, false]
	var star1: Array[bool] = [true, false, false]
	var cases: Array = [
		[K.STANDARD, [1, 2, 3], none, [ST.RUNNING, CW, 0]],
		[K.STANDARD, [2, 3, 1], none, [ST.RUNNING, CW, 0]],
		[K.STANDARD, [3, 2, 1], none, [ST.RUNNING, CCW, 0]],
		[K.STANDARD, [1, 2, 0], none, [ST.PHASE_LOSS, ThreePhaseMotor.Direction.NONE, 0]],
		[K.STANDARD, [0, 0, 0], none, [ST.STOPPED, ThreePhaseMotor.Direction.NONE, 0]],
		[K.STAR_DELTA, [1, 2, 3, 0, 0, 0], star2, [ST.STAR, CW, 0]],
		[K.STAR_DELTA, [1, 2, 3, 2, 3, 1], none, [ST.DELTA, CW, 0]],
		[K.STAR_DELTA, [1, 3, 2, 3, 2, 1], none, [ST.DELTA, CCW, 0]],
		[K.STAR_DELTA, [1, 2, 3, 0, 0, 0], none, [ST.STOPPED, ThreePhaseMotor.Direction.NONE, 0]],
		[K.DAHLANDER, [1, 2, 3, 0, 0, 0], none, [ST.RUNNING, CW, 1]],
		[K.DAHLANDER, [0, 0, 0, 1, 2, 3], star1, [ST.RUNNING, CW, 2]],
		[K.DAHLANDER, [1, 2, 3, 1, 2, 3], none, [ST.MISWIRED, ThreePhaseMotor.Direction.NONE, 0]],
		[K.TWO_WINDINGS, [0, 0, 0, 3, 2, 1], none, [ST.RUNNING, CCW, 2]],
		[K.TWO_WINDINGS, [1, 2, 3, 1, 2, 3], none, [ST.MISWIRED, ThreePhaseMotor.Direction.NONE, 0]],
		[K.THREE_WINDINGS, [0, 0, 0, 0, 0, 0, 1, 2, 3], [false, false, false], [ST.RUNNING, CW, 3]],
		[K.THREE_WINDINGS, [0, 0, 0, 1, 0, 3, 0, 0, 0], [false, false, false], [ST.PHASE_LOSS, ThreePhaseMotor.Direction.NONE, 0]],
	]
	for c: Array in cases:
		var phases: PackedInt32Array = PackedInt32Array(c[1])
		var points: Array[bool] = []
		points.assign(c[2])
		assert_eq(ThreePhaseMotor.evaluate(c[0], phases, points), c[3], "%s %s" % [K.keys()[c[0]], c[1]])


# --- Examples -------------------------------------------------------------------

func test_direct_on_line_runs_clockwise() -> void:
	for realistic: bool in [false, true]:
		var doc: SchematicDocument = ExampleCircuits.direct_on_line()
		var sim: Simulator = _sim(doc, realistic)
		assert_eq(_motor(doc).state, ST.STOPPED)
		_press(doc, sim, "SB1")
		assert_eq(_motor(doc).state, ST.RUNNING, "runs after START (realistic %s)" % realistic)
		assert_eq(_motor(doc).direction, CW)
		_press(doc, sim, "SB0")
		assert_eq(_motor(doc).state, ST.STOPPED, "stops after STOP")


func test_forward_reverse_turns_both_ways() -> void:
	var doc: SchematicDocument = ExampleCircuits.forward_reverse_3()
	var sim: Simulator = _sim(doc, true)
	_press(doc, sim, "SB1")
	assert_eq(_motor(doc).direction, CW, "KM1 forward")
	var texts: PackedStringArray = _press(doc, sim, "SB2")
	assert_eq(_motor(doc).direction, CW, "KM1 interlocks KM2")
	assert_false(texts.has("Short circuit: %s"))
	_press(doc, sim, "SB0")
	_press(doc, sim, "SB2")
	assert_true(_motor(doc).is_running())
	assert_eq(_motor(doc).direction, CCW, "KM2 swaps L1 and L3")


func test_phase_loss_trips_the_overload_relay() -> void:
	var doc: SchematicDocument = ExampleCircuits.direct_on_line()
	var sim: Simulator = _sim(doc)
	_press(doc, sim, "SB1")
	(doc.circuit.get_component("FU1") as ThreePoleFuse).blown[1] = 1
	sim.step()
	assert_eq(_motor(doc).state, ST.PHASE_LOSS)
	var relay: OverloadRelay = doc.circuit.get_overload_relay("F1")
	var lines: PackedFloat32Array = sim.motor_line_currents(0)
	assert_almost_eq(lines[1], 0.0, 1e-3, "nothing flows in L2")
	assert_gt(lines[0], 1.5 * _motor(doc).rated_current, "the other two lines carry much more")
	sim.step(30.0)
	assert_false(relay.tripped, "class 10 takes longer at this current")
	sim.step(120.0)
	assert_true(relay.tripped)
	assert_false(doc.circuit.get_coil("KM1").energized, "95-96 dropped KM1")
	assert_eq(_motor(doc).state, ST.STOPPED)


func test_overloaded_motor_trips_its_relay() -> void:
	var doc: SchematicDocument = ExampleCircuits.direct_on_line()
	var sim: Simulator = _sim(doc)
	_motor(doc).overloaded = true
	sim.step(10.0)
	assert_false(doc.circuit.get_overload_relay("F1").tripped, "a stopped motor draws no current")
	_press(doc, sim, "SB1")
	assert_gt(_motor(doc).max_current(), 1.5 * _motor(doc).rated_current, "draws more than its rated current")
	sim.step(10.0)
	assert_false(doc.circuit.get_overload_relay("F1").tripped, "not at once")
	sim.step(300.0)
	assert_true(doc.circuit.get_overload_relay("F1").tripped)
	assert_false(_motor(doc).is_running())


func test_star_delta_3_switches_without_short() -> void:
	var doc: SchematicDocument = ExampleCircuits.star_delta_3()
	var sim: Simulator = _sim(doc, true)
	var start: PushButton = doc.circuit.get_component("SB2") as PushButton
	start.press()
	var texts: PackedStringArray = _run(sim, 0.2)
	assert_eq(_motor(doc).state, ST.STAR, "star while START is held")
	assert_eq(_motor(doc).direction, CW)
	start.release()
	texts.append_array(_run(sim, 0.2))
	assert_eq(_motor(doc).state, ST.DELTA, "delta after letting go")
	assert_eq(_motor(doc).direction, CW, "same direction in delta")
	assert_false(texts.has("Short circuit: %s"), "star and delta never overlap")


func test_dahlander_speeds() -> void:
	var doc: SchematicDocument = ExampleCircuits.dahlander()
	var sim: Simulator = _sim(doc, true)
	var texts: PackedStringArray = _press(doc, sim, "SB1")
	assert_eq([_motor(doc).state, _motor(doc).speed], [ST.RUNNING, 1], "low speed")
	texts.append_array(_press(doc, sim, "SB2"))
	assert_eq(_motor(doc).speed, 1, "KM1 21-22 keeps high speed off")
	_press(doc, sim, "SB0")
	texts.append_array(_press(doc, sim, "SB2"))
	assert_eq([_motor(doc).state, _motor(doc).speed], [ST.RUNNING, 2], "high speed")
	assert_true(doc.circuit.get_coil("KM3").energized, "star point closed")
	assert_false(texts.has("Short circuit: %s"))


func test_dahlander_both_speeds_is_miswired() -> void:
	var doc: SchematicDocument = ExampleCircuits.dahlander()
	var sim: Simulator = _sim(doc)
	(doc.circuit.get_component("KM2:1-2-3-4-5-6") as MainContacts).fault = SwitchingElement.Fault.WELDED
	_press(doc, sim, "SB1")
	assert_eq(_motor(doc).state, ST.MISWIRED)
	assert_gt(_motor(doc).max_current(), 4.0 * _motor(doc).rated_current, "half windings across the line voltage")
	sim.step(20.0)
	assert_true(doc.circuit.get_overload_relay("F1").tripped, "overheats and trips")


func test_two_windings_speeds() -> void:
	var doc: SchematicDocument = ExampleCircuits.two_windings()
	var sim: Simulator = _sim(doc, true)
	var texts: PackedStringArray = _press(doc, sim, "SB2")
	assert_eq([_motor(doc).state, _motor(doc).speed], [ST.RUNNING, 1], "SB2 low speed")
	texts.append_array(_press(doc, sim, "SB3", 0.2))
	assert_eq([_motor(doc).state, _motor(doc).speed], [ST.RUNNING, 2], "SB3 switches to high speed without STOP (button interlock)")
	assert_false(texts.has("Short circuit: %s"))
	assert_false(doc.circuit.get_coil("KM1").energized)
	_press(doc, sim, "SB1")
	assert_eq(_motor(doc).state, ST.STOPPED, "SB1 stops")


# --- Three-pole protection ------------------------------------------------------

## L1, L2, L3 - [param device] at (0, 2) - S1 joins 2 and 4 (and 6 with
## [param with_l3]): a phase-to-phase short.
func _protected_short(device: CircuitComponent, with_l3: bool) -> Array:
	var doc: SchematicDocument = SchematicDocument.new()
	_three_supplies(doc)
	doc.add(device, Vector2i(0, 2))
	for i: int in 3:
		doc.connect_terminals(["L1", "L2", "L3"][i], "%s:%d" % [device.designation, 2 * i + 1])
	var s1: LatchingSwitch = doc.add(LatchingSwitch.new("S1", NO), Vector2i(0, 7)) as LatchingSwitch
	doc.connect_terminals(device.designation + ":2", "S1:13", [Vector2i(0, 6)] as Array[Vector2i])
	doc.connect_terminals(device.designation + ":4", "S1:13", [Vector2i(2, 6), Vector2i(0, 6)] as Array[Vector2i])
	if with_l3:
		doc.connect_terminals("S1:14", device.designation + ":6", [Vector2i(0, 11), Vector2i(4, 11)] as Array[Vector2i])
	else:
		doc.connect_terminals("S1:14", device.designation + ":2", [Vector2i(-2, 10), Vector2i(-2, 5)] as Array[Vector2i])
	var sim: Simulator = _sim(doc)
	return [doc, sim, s1]


func test_three_pole_fuse_blows_only_the_poles_with_fault_current() -> void:
	var fuse: ThreePoleFuse = ThreePoleFuse.new("F1")
	var setup: Array = _protected_short(fuse, false)
	var sim: Simulator = setup[1]
	(setup[2] as LatchingSwitch).set_switched_on(true)
	var r: StepResult = sim.step()
	assert_eq(fuse.blown, PackedByteArray([1, 1, 0]), "L1 and L2 blow, L3 stays")
	assert_false(r.short_circuit, "the short is cleared")
	fuse.reset()
	assert_false(fuse.any_blown())


func test_motor_breaker_trips_all_poles() -> void:
	var breaker: MotorBreaker = MotorBreaker.new("Q1")
	breaker.switched_on = true
	var setup: Array = _protected_short(breaker, true)
	var sim: Simulator = setup[1]
	(setup[2] as LatchingSwitch).set_switched_on(true)
	var r: StepResult = sim.step()
	assert_true(breaker.tripped)
	for pole: int in 3:
		assert_false(breaker.is_path_closed(pole))
	assert_false(r.short_circuit)
	(setup[2] as LatchingSwitch).set_switched_on(false)
	breaker.toggle()
	assert_true(breaker.is_path_closed(0), "switching on resets the trip")


# --- Schematic and editor -------------------------------------------------------

func test_supply_designations_follow_the_conductor() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	assert_eq(doc.next_supply_designation(PowerSupply.Conductor.L), "L1", "a new phase supply is L1")
	assert_eq(doc.next_supply_designation(PowerSupply.Conductor.L2), "L2")
	doc.add(PowerSupply.new("L2", PowerSupply.Conductor.L2), Vector2i(0, 0))
	assert_eq(doc.next_supply_designation(PowerSupply.Conductor.L), "L1", "L1 next to L2")
	assert_eq(doc.next_supply_designation(PowerSupply.Conductor.L2), "L2.2")
	assert_eq(doc.next_supply_designation(PowerSupply.Conductor.L3), "L3")
	assert_eq(PowerSupply.new("L1.2", PowerSupply.Conductor.L).conductor_name(), "L1")


func test_examples_have_no_check_errors() -> void:
	for index: int in range(7, ExampleCircuits.count()):
		var doc: SchematicDocument = ExampleCircuits.build(index)
		assert_eq(CircuitCheck.run(doc), [] as Array[Dictionary], doc.title)
		assert_eq(doc.circuit.get_wires().size(), doc.get_wire_count())


func test_three_phase_round_trip() -> void:
	for index: int in range(7, ExampleCircuits.count()):
		var doc: SchematicDocument = ExampleCircuits.build(index)
		var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
		assert_not_null(copy, doc.title)
		assert_eq(DocumentSerializer.to_dict(copy), DocumentSerializer.to_dict(doc), doc.title)


func test_motor_pe_terminal() -> void:
	var motor: ThreePhaseMotor = ThreePhaseMotor.new("M1", K.THREE_WINDINGS)
	assert_eq(motor.get_terminal_names()[motor.winding_terminal_count()], "PE")
	assert_eq(motor.winding_terminal_count(), 9)
	var doc: SchematicDocument = ExampleCircuits.direct_on_line()
	assert_eq(doc.terminal_cell("M1:PE"), doc.get_placement("M1").cell + SymbolGeometry.MOTOR_PE_CELL)
	# PE does not count as a winding: the motor still runs clockwise.
	var sim: Simulator = _sim(doc)
	_press(doc, sim, "SB1")
	assert_eq([_motor(doc).state, _motor(doc).direction], [ST.RUNNING, CW])


func test_version_4_custom_motor_terminals_get_pe() -> void:
	var c: CircuitComponent = DocumentSerializer.component_from_dict({"type": "motor3", "designation": "M1", "terminals": ["A", "B", "C"]})
	assert_not_null(c)
	assert_eq(c.get_terminal_names(), PackedStringArray(["A", "B", "C", "PE"]))


func test_lamp_purpose_is_saved() -> void:
	var lamp: Lamp = Lamp.new("H3")
	lamp.purpose = "Chod"
	var d: Dictionary = DocumentSerializer.component_to_dict(lamp)
	assert_eq(d["purpose"], "Chod")
	assert_eq((DocumentSerializer.component_from_dict(d) as Lamp).purpose, "Chod")
	assert_false(DocumentSerializer.component_to_dict(Lamp.new("H1")).has("purpose"), "no empty purpose in files")


func test_fuse_holders_open_and_blow() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	_three_supplies(doc)
	var holder: ThreePoleFuse = ThreePoleFuse.new("F1")
	holder.holder = true
	doc.add(holder, Vector2i(0, 2))
	for i: int in 3:
		doc.connect_terminals(["L1", "L2", "L3"][i], "F1:%d" % (2 * i + 1))
	var lamp: Lamp = doc.add(Lamp.new("H1"), Vector2i(0, 7)) as Lamp
	doc.connect_terminals("F1:2", "H1:X1")
	doc.connect_terminals("H1:X2", "F1:4", [Vector2i(0, 12), Vector2i(2, 12)] as Array[Vector2i])
	var sim: Simulator = _sim(doc)
	assert_true(lamp.energized, "400 V through the closed holder")
	holder.toggle()
	sim.step()
	assert_false(lamp.energized, "opened holder")
	holder.toggle()
	sim.step()
	assert_true(lamp.energized)
	var single: Fuse = Fuse.new("F2")
	single.holder = true
	assert_false(single.is_closed(), "a holder starts open")
	single.toggle()
	assert_true(single.is_closed())
	single.toggle()
	assert_false(single.is_closed(), "a 1-pole holder opens too")
	assert_true(DocumentSerializer.component_from_dict(DocumentSerializer.component_to_dict(single)).holder)
	assert_false(Fuse.new("F3").holder)


func test_terminal_box_view_is_saved() -> void:
	var motor: ThreePhaseMotor = ThreePhaseMotor.new("M1")
	motor.terminal_box = true
	motor.delta_bridges = true
	var d: Dictionary = DocumentSerializer.component_to_dict(motor)
	assert_eq([d["terminal_box"], d["connection"]], [true, "delta"])
	var copy: ThreePhaseMotor = DocumentSerializer.component_from_dict(d) as ThreePhaseMotor
	assert_true(copy.terminal_box and copy.delta_bridges)
	var dahlander: ThreePhaseMotor = ThreePhaseMotor.new("M2", K.DAHLANDER)
	dahlander.terminal_box = true
	var dd: Dictionary = DocumentSerializer.component_to_dict(dahlander)
	assert_true(dd["terminal_box"], "every motor can be drawn as its terminal box")
	assert_false(dd.has("connection"), "bridges only on standard motors")
	assert_true((DocumentSerializer.component_from_dict(dd) as ThreePhaseMotor).terminal_box)


func test_poles_are_a_property() -> void:
	for n: int in [1, 2, 3, 4]:
		var f: Dictionary = {"type": "fuse", "designation": "F1", "poles": n}
		var fuse: CircuitComponent = DocumentSerializer.component_from_dict(f)
		assert_eq(fuse.get_terminal_names().size(), 2 * n, "fuse with %d poles" % n)
		assert_eq(fuse.switch_paths().size(), n)
		var b: CircuitComponent = DocumentSerializer.component_from_dict({"type": "breaker", "designation": "Q1", "poles": n})
		if n == 1:
			assert_true(b is CircuitBreaker)
		else:
			assert_true(b is MotorBreaker)
		assert_eq(b.get_terminal_names().size(), 2 * n)
		var m: MainContacts = DocumentSerializer.component_from_dict({"type": "main_contacts", "designation": "KM1", "poles": n}) as MainContacts
		assert_eq(m.switch_paths().size(), n)
		assert_eq(int(DocumentSerializer.component_to_dict(m)["poles"]), n)
	var four: ThreePoleFuse = DocumentSerializer.component_from_dict({"type": "fuse", "designation": "F1", "poles": 4}) as ThreePoleFuse
	assert_eq(four.blown.size(), 4)
	assert_eq(four.get_terminal_names(), PackedStringArray(["1", "2", "3", "4", "5", "6", "7", "8"]))
	assert_eq(DocumentSerializer.component_to_dict(four)["type"], "fuse")
	# Files before version 9.
	assert_eq((DocumentSerializer.component_from_dict({"type": "fuse3", "designation": "F1"}) as ThreePoleFuse).poles, 3)
	assert_eq((DocumentSerializer.component_from_dict({"type": "breaker3", "designation": "Q1"}) as MotorBreaker).poles, 3)


func test_star_delta_ends_as_on_the_terminal_board() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(ThreePhaseMotor.new("M1", K.STAR_DELTA), Vector2i(0, 0))
	assert_eq(doc.terminal_cell("M1:W2"), Vector2i(0, 4), "W2 under U1")
	assert_eq(doc.terminal_cell("M1:U2"), Vector2i(2, 4), "U2 under V1")
	assert_eq(doc.terminal_cell("M1:V2"), Vector2i(4, 4), "V2 under W1")
