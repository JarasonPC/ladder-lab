extends GutTest
## DC supply points + / -, DC braking of three-phase motors and the run-down
## of the shaft after switching off.

const NO := SwitchingElement.ContactType.NO
const K := ThreePhaseMotor.Kind
const ST := ThreePhaseMotor.State


func _sim(doc: SchematicDocument, realistic: bool = false) -> Simulator:
	for c: CircuitComponent in doc.circuit.get_components():
		if c is Fuse or c is ThreePoleFuse or c is CircuitBreaker or c is MotorBreaker:
			c.set("switched_on", true)
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.mode = Simulator.Mode.REALISTIC if realistic else Simulator.Mode.IDEAL
	sim.step()
	return sim


## Steps [param seconds] in small steps; returns the events (time and text).
func _run(sim: Simulator, seconds: float, dt: float = 0.01) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var steps: int = roundi(seconds / dt)
	for i: int in steps:
		events.append_array(sim.step(dt).events)
	return events


func _press(doc: SchematicDocument, sim: Simulator, button: String) -> Array[Dictionary]:
	var b: PushButton = doc.circuit.get_component(button) as PushButton
	b.press()
	var events: Array[Dictionary] = _run(sim, 0.1)
	b.release()
	return events


## Time of the first event with [param text] for [param designation], or -1.
func _time_of(events: Array[Dictionary], text: String) -> float:
	for e: Dictionary in events:
		if e["text"] == text:
			return e["time"]
	return -1.0


func _motor(doc: SchematicDocument) -> ThreePhaseMotor:
	return doc.circuit.get_component("M1") as ThreePhaseMotor


func _dc_supplies(doc: SchematicDocument) -> void:
	doc.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS), Vector2i(0, 0))
	doc.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS), Vector2i(2, 0))


# --- DC supply ------------------------------------------------------------------

func test_coil_works_between_the_dc_poles_only() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	_dc_supplies(doc)
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(8, 0))
	doc.add(Coil.new("KA1"), Vector2i(0, 4))
	doc.add(Coil.new("KA2"), Vector2i(8, 4))
	doc.connect_terminals("+", "KA1:A1")
	doc.connect_terminals("-", "KA1:A2", [Vector2i(2, 7)] as Array[Vector2i])
	doc.connect_terminals("+", "KA2:A1", [Vector2i(0, 2), Vector2i(8, 2)] as Array[Vector2i])
	doc.connect_terminals("N", "KA2:A2", [Vector2i(10, 0), Vector2i(10, 7), Vector2i(8, 7)] as Array[Vector2i])
	var r: StepResult = _sim(doc).last_result
	assert_true(doc.circuit.get_coil("KA1").energized, "DC between + and -")
	assert_false(doc.circuit.get_coil("KA2").energized, "the DC source is separate from N")
	assert_false(r.short_circuit)
	assert_eq(r.terminal_reach["KA1:A1"], StepResult.REACH_DC_PLUS)
	assert_eq(r.terminal_reach["KA1:A2"], StepResult.REACH_DC_MINUS)
	assert_has(r.neutral_terminals, "KA1:A2", "- is a return conductor like N")
	assert_has(r.live_terminals, "KA1:A1")
	assert_has(r.current_components, "KA1")


func test_dc_pole_joined_to_a_phase_is_a_short() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	_dc_supplies(doc)
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(6, 0))
	doc.add(LatchingSwitch.new("RB1", NO), Vector2i(0, 4))
	doc.connect_terminals("+", "RB1:13")
	doc.connect_terminals("L1", "RB1:14", [Vector2i(6, 7), Vector2i(0, 7)] as Array[Vector2i])
	var sim: Simulator = _sim(doc)
	assert_false(sim.last_result.short_circuit)
	(doc.circuit.get_component("RB1") as LatchingSwitch).toggle()
	var r: StepResult = sim.step()
	assert_true(r.short_circuit)
	assert_eq(r.short_circuit_path, PackedStringArray(["L1", "RB1:13-14", "+"]))


func test_dc_supply_designations_and_file() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	assert_eq(doc.next_supply_designation(PowerSupply.Conductor.DC_PLUS), "+")
	assert_eq(doc.next_supply_designation(PowerSupply.Conductor.DC_MINUS), "-")
	_dc_supplies(doc)
	assert_eq(doc.next_supply_designation(PowerSupply.Conductor.DC_PLUS), "+.2")
	assert_eq(PowerSupply.new("-.2", PowerSupply.Conductor.DC_MINUS).conductor_name(), "-")
	var motor: ThreePhaseMotor = ThreePhaseMotor.new("M1")
	motor.coast_time = 7.5
	motor.brake_time = 0.8
	doc.add(motor, Vector2i(6, 4))
	var parsed: Dictionary = ProjectFile.parse(JSON.stringify({"format": ProjectFile.FORMAT, "version": ProjectFile.VERSION, "document": DocumentSerializer.to_dict(doc)}))
	var copy: SchematicDocument = parsed["document"]
	assert_eq((copy.circuit.get_component("+") as PowerSupply).conductor, PowerSupply.Conductor.DC_PLUS)
	assert_eq((copy.circuit.get_component("-") as PowerSupply).conductor, PowerSupply.Conductor.DC_MINUS)
	assert_eq(_motor(copy).coast_time, 7.5)
	assert_eq(_motor(copy).brake_time, 0.8)
	var old: ThreePhaseMotor = DocumentSerializer.component_from_dict({"type": "motor3", "designation": "M2"}) as ThreePhaseMotor
	assert_eq(old.coast_time, ThreePhaseMotor.DEFAULT_COAST_TIME, "files before version 11 get the default times")
	assert_eq(old.brake_time, ThreePhaseMotor.DEFAULT_BRAKE_TIME)


# --- DC through the windings ----------------------------------------------------

func test_dc_needs_a_winding_between_the_poles() -> void:
	var p: PackedInt32Array = PackedInt32Array([1, -1, 0, 0, 0, 0, 0, 0, 0])
	var apart: PackedInt32Array = PackedInt32Array([10, 11, 12, 13, 14, 15, -1, -1, -1])
	assert_true(ThreePhaseMotor.carries_dc(K.STANDARD, p, apart), "U1-V1 through the star of a standard motor")
	assert_true(ThreePhaseMotor.carries_dc(K.DAHLANDER, p, apart))
	assert_false(ThreePhaseMotor.carries_dc(K.STAR_DELTA, p, apart), "U1 and V1 belong to separate windings")
	var star: PackedInt32Array = PackedInt32Array([10, 11, 12, 20, 20, 20, -1, -1, -1])
	assert_true(ThreePhaseMotor.carries_dc(K.STAR_DELTA, p, star), "U2-V2-W2 joined in a star point")
	var one_winding: PackedInt32Array = PackedInt32Array([1, 0, 0, -1, 0, 0, 0, 0, 0])
	assert_true(ThreePhaseMotor.carries_dc(K.STAR_DELTA, one_winding, apart), "U1-U2 is one winding")
	assert_false(ThreePhaseMotor.carries_dc(K.TWO_WINDINGS, one_winding, apart), "1U and 2U are separate windings")


func test_dc_on_a_motor_brakes_and_with_a_phase_is_miswired() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	_dc_supplies(doc)
	doc.add(ThreePhaseMotor.new("M1"), Vector2i(0, 4))
	doc.connect_terminals("+", "M1:U1")
	doc.connect_terminals("-", "M1:V1")
	var sim: Simulator = _sim(doc)
	assert_eq(_motor(doc).state, ST.DC_BRAKING)
	assert_false(_motor(doc).is_running())
	assert_false(_motor(doc).is_turning(), "DC alone does not turn the motor")
	doc.add(PowerSupply.new("L3", PowerSupply.Conductor.L3), Vector2i(4, 0))
	doc.connect_terminals("L3", "M1:W1")
	sim.step()
	assert_eq(_motor(doc).state, ST.MISWIRED, "AC and DC together")


# --- Running down and braking ---------------------------------------------------

func test_motor_runs_down_after_switching_off() -> void:
	for realistic: bool in [false, true]:
		var doc: SchematicDocument = ExampleCircuits.direct_on_line()
		var sim: Simulator = _sim(doc, realistic)
		_press(doc, sim, "SB1")
		_run(sim, 3.0)
		var m: ThreePhaseMotor = _motor(doc)
		assert_almost_eq(m.shaft, 1.0, 0.001, "up to rated speed")
		var events: Array[Dictionary] = _press(doc, sim, "SB0")
		assert_true(_time_of(events, "%s switched off, runs down") >= 0.0)
		assert_eq(m.state, ST.STOPPED)
		assert_true(m.is_turning(), "still turning just after STOP")
		assert_eq(m.shaft_direction, ThreePhaseMotor.Direction.CLOCKWISE)
		var off_at: float = sim.time - 0.1
		events = _run(sim, m.coast_time + 0.5)
		assert_false(m.is_turning(), "stopped after the run-down time (realistic %s)" % realistic)
		var stopped_at: float = _time_of(events, "%s stopped")
		assert_almost_eq(stopped_at - off_at, m.coast_time, 0.1)


func test_dc_braking_example_stops_the_motor_quickly() -> void:
	for realistic: bool in [false, true]:
		var doc: SchematicDocument = ExampleCircuits.dc_braking()
		var sim: Simulator = _sim(doc, realistic)
		var m: ThreePhaseMotor = _motor(doc)
		_press(doc, sim, "SB1")
		_run(sim, 1.0)
		assert_true(m.is_running())
		assert_false(doc.circuit.get_coil("KM2").energized)
		var pressed_at: float = sim.time
		var events: Array[Dictionary] = _press(doc, sim, "SB0")
		assert_false(doc.circuit.get_coil("KM1").energized)
		assert_true(doc.circuit.get_coil("KM2").energized, "KM2 brakes as soon as KM1 has released")
		assert_eq(m.state, ST.DC_BRAKING)
		assert_false(sim.last_result.short_circuit)
		events.append_array(_run(sim, 3.0))
		var stopped_at: float = _time_of(events, "%s stopped")
		assert_gt(stopped_at, 0.0, "the motor stopped (realistic %s)" % realistic)
		assert_almost_eq(stopped_at - pressed_at, m.brake_time, 0.15, "stopped in the braking time, not the run-down time")
		assert_false(doc.circuit.get_coil("KM2").energized, "KT1 ended the braking")
		assert_eq(m.state, ST.STOPPED)
		# KM1 cannot start during braking: its branch has KM2's NC contact.
		_press(doc, sim, "SB1")
		assert_true(m.is_running(), "starts again after braking")


func test_braking_is_strongest_right_after_switching_off() -> void:
	var at_once: ThreePhaseMotor = ThreePhaseMotor.new("M1")
	var late: ThreePhaseMotor = ThreePhaseMotor.new("M2")
	for m: ThreePhaseMotor in [at_once, late]:
		m.state = ST.RUNNING
		m.advance_shaft(0.0)
		m.state = ST.STOPPED
	late.advance_shaft(1.0)
	assert_almost_eq(late.shaft, 1.0 - 1.0 / late.coast_time, 1e-6)
	assert_lt(late.rotor_flux, 0.01, "the rotor field has died away")
	for m: ThreePhaseMotor in [at_once, late]:
		m.state = ST.DC_BRAKING
	assert_almost_eq(at_once.time_to_standstill(), at_once.brake_time, 1e-6, "full braking with the rotor field still there")
	var late_time: float = late.time_to_standstill()
	assert_gt(late_time, late.shaft * late.brake_time + 0.1, "late braking first has to build the field up again")
	assert_false(late.advance_shaft(late_time * 0.99))
	assert_true(late.advance_shaft(late_time * 0.02), "stops at the predicted time")
	assert_eq(late.shaft, 0.0)
