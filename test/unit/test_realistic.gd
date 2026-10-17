extends GutTest
## Realistic switching: armatures take time, NC breaks before NO makes.

const ExamplePower = preload("res://test/unit/example_power.gd")

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC


func _sim(doc: SchematicDocument) -> Simulator:
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.mode = Simulator.Mode.REALISTIC
	return sim


func _run(sim: Simulator, seconds: float, dt: float = 1.0 / 60.0) -> StepResult:
	var r: StepResult = sim.step()
	var left: float = seconds
	while left > 1e-9:
		r = sim.step(minf(dt, left))
		left -= dt
	return r


func _lamp(doc: SchematicDocument, id: String) -> bool:
	return (doc.circuit.get_component(id) as Lamp).energized


## L - S1 - KM1 coil - N; KM1 13-14 lights H1, KM1 21-22 lights H2.
func _changeover_doc() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 20))
	doc.add(LatchingSwitch.new("S1", NO), Vector2i(2, 2))
	doc.add(Coil.new("KM1"), Vector2i(2, 8))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(6, 2))
	doc.add(Lamp.new("H1"), Vector2i(6, 8))
	doc.add(Contact.new("KM1", NC, 2), Vector2i(10, 2))
	doc.add(Lamp.new("H2"), Vector2i(10, 8))
	for pair: Array in [["L", "S1:13"], ["S1:14", "KM1:A1"], ["KM1:A2", "N"], ["L", "KM1:13"], ["KM1:14", "H1:X1"], ["H1:X2", "N"], ["L", "KM1:21"], ["KM1:22", "H2:X1"], ["H2:X2", "N"]]:
		doc.connect_terminals(pair[0], pair[1])
	return doc


func test_ideal_is_the_solver_default() -> void:
	assert_eq(Simulator.new(Circuit.new()).mode, Simulator.Mode.IDEAL)


func test_tolerance_is_fixed_per_designation_and_within_5_percent() -> void:
	var a: Coil = Coil.new("KM1")
	assert_eq(a.timing_factor(), Coil.new("KM1").timing_factor())
	assert_ne(a.timing_factor(), Coil.new("KM2").timing_factor())
	for name: String in ["KM1", "KM2", "KM3", "KT1", "K10"]:
		var f: float = Coil.new(name).timing_factor()
		assert_between(f, 0.95, 1.05)
	assert_almost_eq(a.armature.pick_up_time, 0.020 * a.timing_factor(), 1e-9)
	assert_almost_eq(Coil.new("K5", Coil.Kind.RELAY).pick_up_time, 0.010, 1e-9)


func test_nc_breaks_before_no_makes() -> void:
	var doc: SchematicDocument = _changeover_doc()
	var sim: Simulator = _sim(doc)
	var t_up: float = (doc.circuit.get_coil("KM1") as Coil).armature.pick_up_time
	sim.step()
	assert_true(_lamp(doc, "H2"), "NC closed at rest")
	(doc.circuit.get_component("S1") as LatchingSwitch).set_switched_on(true)
	sim.step(2.0 * Armature.MIN_TIME)
	assert_true(doc.circuit.get_coil("KM1").energized, "coil gets power once the snap-action switch has moved")
	sim.step(Armature.NC_BREAK * t_up * 0.9)
	assert_true(_lamp(doc, "H2"), "NC still closed early in the travel")
	assert_false(_lamp(doc, "H1"))
	sim.step(Armature.NC_BREAK * t_up * 0.2)
	assert_false(_lamp(doc, "H2"), "NC has broken")
	assert_false(_lamp(doc, "H1"), "NO not made yet: both open")
	sim.step(t_up)
	assert_true(_lamp(doc, "H1"), "NO made at the end of the travel")
	assert_false(_lamp(doc, "H2"))


func test_release_opens_no_before_nc_closes() -> void:
	var doc: SchematicDocument = _changeover_doc()
	var sim: Simulator = _sim(doc)
	var t_down: float = (doc.circuit.get_coil("KM1") as Coil).armature.drop_out_time
	(doc.circuit.get_component("S1") as LatchingSwitch).set_switched_on(true)
	_run(sim, 0.1)
	(doc.circuit.get_component("S1") as LatchingSwitch).set_switched_on(false)
	sim.step()
	sim.step((1.0 - Armature.NO_RELEASE) * t_down * 1.1)
	assert_false(_lamp(doc, "H1"), "NO opened first")
	assert_false(_lamp(doc, "H2"), "NC not closed yet")
	sim.step(t_down)
	assert_true(_lamp(doc, "H2"), "NC closed near the end")


func test_self_holding_needs_full_pick_up() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_holding())
	var sim: Simulator = _sim(doc)
	var start: PushButton = doc.circuit.get_component("SB1") as PushButton
	var k1: Coil = doc.circuit.get_coil("KM1")
	start.press()
	_run(sim, 0.005, 0.001)
	start.release()
	_run(sim, 0.1)
	assert_false(k1.energized, "a 5 ms tap is too short for a 20 ms contactor")
	start.press()
	_run(sim, 0.05)
	start.release()
	var r: StepResult = _run(sim, 0.2)
	assert_true(k1.energized, "holds after a full pick-up")
	assert_true(r.stable)
	assert_false(r.is_oscillating())


func test_forward_reverse_race_has_one_winner() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.forward_reverse())
	var sim: Simulator = _sim(doc)
	(doc.circuit.get_component("SB1") as PushButton).press()
	(doc.circuit.get_component("SB2") as PushButton).press()
	var r: StepResult = _run(sim, 0.2)
	var k1: Coil = doc.circuit.get_coil("KM1")
	var k2: Coil = doc.circuit.get_coil("KM2")
	assert_ne(k1.energized, k2.energized, "exactly one contactor wins")
	assert_false(r.is_oscillating())
	var faster: Coil = k1 if k1.armature.pick_up_time < k2.armature.pick_up_time else k2
	assert_true(faster.energized, "the faster contactor wins")


func test_self_cutoff_chatters_at_expected_rate() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_cutoff())
	var sim: Simulator = _sim(doc)
	(doc.circuit.get_component("SB1") as PushButton).press()
	var r: StepResult = _run(sim, 0.6)
	assert_eq(r.oscillating_tags, PackedStringArray(["KM1"]))
	var a: Armature = doc.circuit.get_coil("KM1").armature
	var period: float = (Armature.NC_BREAK - Armature.NC_REMAKE) * (a.pick_up_time + a.drop_out_time)
	assert_almost_eq(r.chatter_hz["KM1"], 1.0 / period, 1.0 / period * 0.1)
	assert_lt(r.iterations, sim.max_events)


func test_on_delay_adds_output_pick_up() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.time_relays())
	var sim: Simulator = _sim(doc)
	var kt1: TimerRelay = doc.circuit.get_coil("KT1") as TimerRelay
	(doc.circuit.get_component("RB1") as LatchingSwitch).set_switched_on(true)
	sim.step()
	_run(sim, 3.0 + kt1.output_armature.pick_up_time * 0.5, 0.001)
	assert_false(_lamp(doc, "H1"), "delay over, output relay still moving")
	_run(sim, kt1.output_armature.pick_up_time, 0.001)
	assert_true(_lamp(doc, "H1"))


func test_brief_short_is_logged() -> void:
	# A fast relay KM1 makes its NO before contactor KM2 has broken its NC:
	# L - KM1:13-14 - KM2:21-22 - N is closed for a few milliseconds.
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 30))
	var s1: LatchingSwitch = doc.add(LatchingSwitch.new("S1", NO), Vector2i(2, 2)) as LatchingSwitch
	doc.add(Coil.new("KM1", Coil.Kind.RELAY, 0.002, 0.002), Vector2i(2, 8))
	doc.add(Coil.new("KM2", Coil.Kind.CONTACTOR, 0.030, 0.015), Vector2i(6, 8))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(10, 2))
	doc.add(Contact.new("KM2", NC, 1), Vector2i(10, 8))
	for pair: Array in [["L", "S1:13"], ["S1:14", "KM1:A1"], ["S1:14", "KM2:A1"], ["KM1:A2", "N"], ["KM2:A2", "N"], ["L", "KM1:13"], ["KM1:14", "KM2:11"], ["KM2:12", "N"]]:
		doc.connect_terminals(pair[0], pair[1])
	var sim: Simulator = _sim(doc)
	sim.step()
	s1.set_switched_on(true)
	var texts: PackedStringArray = PackedStringArray()
	for i: int in 100:
		for e: Dictionary in sim.step(0.001).events:
			texts.append(e["text"])
	assert_has(texts, "Short circuit: %s")
	assert_has(texts, "Short circuit ended after %.1f ms")


func test_events_and_trace() -> void:
	var doc: SchematicDocument = _changeover_doc()
	var sim: Simulator = _sim(doc)
	sim.trace = TraceRecorder.new()
	(doc.circuit.get_component("S1") as LatchingSwitch).set_switched_on(true)
	var texts: PackedStringArray = PackedStringArray()
	for i: int in 10:
		for e: Dictionary in sim.step(0.01).events:
			texts.append(e["text"] % e["args"])
	assert_has(texts, "KM1 pulled in")
	var t_up: float = doc.circuit.get_coil("KM1").armature.pick_up_time
	assert_almost_eq(sim.trace.value_at("KM1/armature", t_up * 0.5, true), 0.5, 0.01, "armature position is linear in time")
	assert_eq(sim.trace.value_at("KM1", 0.005), 1.0)
	assert_eq(sim.trace.value_at("H1", t_up * 0.5), 0.0)
	assert_eq(sim.trace.value_at("H1", t_up * 1.01), 1.0)


func test_trace_recorder_keeps_history_bounded() -> void:
	var trace: TraceRecorder = TraceRecorder.new()
	trace.history_seconds = 1.0
	for i: int in 1000:
		trace.record("X", i * 0.01, float(i % 2))
	assert_lt(trace.times("X").size(), 200)
	assert_eq(trace.value_at("X", 9.985), 0.0, "sample 998 (value 0) is the last one before")
	assert_eq(trace.value_at("X", 9.995), 1.0)
