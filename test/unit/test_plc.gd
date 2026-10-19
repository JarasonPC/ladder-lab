extends GutTest
## PLC: supply L1-N, inputs against N, relay outputs, programs in FBD and LAD.
##
## L - Q (switch, NO 13-14) - A1 L1, A1 N - N
## L - S1 (button NO 13-14) - A1 I1;  L - S2 (button NC 11-12) - A1 I2
## L - A1 Q1.1, A1 Q1.2 - H1 - N;  L - A1 Q2.1, A1 Q2.2 - H2 - N

const ExamplePower = preload("res://test/unit/example_power.gd")

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC

var circuit: Circuit
var sim: Simulator
var plc: Plc
var power: LatchingSwitch
var s1: PushButton
var s2: PushButton
var h1: Lamp
var h2: Lamp


func _build(program: PlcProgram, realistic: bool = false) -> void:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	circuit.add(PowerSupply.new("N", PowerSupply.Conductor.N))
	power = circuit.add(LatchingSwitch.new("Q", NO)) as LatchingSwitch
	plc = circuit.add(Plc.new("A1", program)) as Plc
	s1 = circuit.add(PushButton.new("S1", NO)) as PushButton
	s2 = circuit.add(PushButton.new("S2", NC)) as PushButton
	h1 = circuit.add(Lamp.new("H1")) as Lamp
	h2 = circuit.add(Lamp.new("H2")) as Lamp
	circuit.connect_terminals("L", "Q:13")
	circuit.connect_terminals("Q:14", "A1:L1")
	circuit.connect_terminals("A1:N", "N")
	circuit.connect_terminals("L", "S1:13")
	circuit.connect_terminals("S1:14", "A1:I1")
	circuit.connect_terminals("L", "S2:11")
	circuit.connect_terminals("S2:12", "A1:I2")
	circuit.connect_terminals("L", "A1:Q1.1")
	circuit.connect_terminals("A1:Q1.2", "H1:X1")
	circuit.connect_terminals("H1:X2", "N")
	circuit.connect_terminals("L", "A1:Q2.1")
	circuit.connect_terminals("A1:Q2.2", "H2:X1")
	circuit.connect_terminals("H2:X2", "N")
	sim = Simulator.new(circuit)
	sim.mode = Simulator.Mode.REALISTIC if realistic else Simulator.Mode.IDEAL
	power.set_switched_on(true)
	sim.step()


func _run(seconds: float, dt: float = 0.05) -> void:
	for i: int in roundi(seconds / dt):
		sim.step(dt)


func _click(button: PushButton) -> void:
	button.press()
	sim.step()
	button.release()
	sim.step()


## FBD: Q1 = (I1 OR Q1) AND I2 - start I1, stop I2 (NC), self-holding.
func _fbd_self_hold() -> PlcProgram:
	var p: PlcProgram = PlcProgram.new()
	var i1: PlcBlock = p.add_block("input", Vector2i(0, 0))
	var i2: PlcBlock = p.add_block("input", Vector2i(0, 4))
	i2.operand = "I2"
	var gate_or: PlcBlock = p.add_block("or", Vector2i(4, 0))
	var gate_and: PlcBlock = p.add_block("and", Vector2i(8, 0))
	var q1: PlcBlock = p.add_block("output", Vector2i(12, 0))
	gate_or.inputs[0] = i1.id
	gate_or.inputs[1] = q1.id
	gate_and.inputs[0] = gate_or.id
	gate_and.inputs[1] = i2.id
	q1.inputs[0] = gate_and.id
	return p


func test_terminals_and_paths() -> void:
	var a1: Plc = Plc.new("A1")
	var names: PackedStringArray = a1.get_terminal_names()
	assert_eq(names.size(), 18)
	assert_eq(names[0], "L1")
	assert_eq(names[1], "N")
	assert_eq(names[a1.input_terminal(0)], "I1")
	assert_eq(names[a1.output_terminal(3)], "Q4.1")
	assert_eq(names[a1.output_terminal(3) + 1], "Q4.2")
	assert_eq(a1.switch_paths().size(), 4)


func test_expansion_module_terminals() -> void:
	var modules: Array[Plc.Module] = [Plc.Module.DI4_DQ4, Plc.Module.DI8_DQ8]
	var a1: Plc = Plc.new("A1", null, modules)
	var names: PackedStringArray = a1.get_terminal_names()
	assert_eq(names.slice(0, 18), Plc.standard_terminal_names(), "the PLC's own terminals first, unchanged")
	assert_eq(names.slice(18, 26), PackedStringArray(["2L1", "2N", "I9", "I10", "I11", "I12", "Q5.1", "Q5.2"]))
	assert_eq(names[a1.module_terminal(1)], "3L1")
	assert_eq(a1.input_count(), 20)
	assert_eq(a1.output_count(), 16)
	assert_eq(names[a1.input_terminal(19)], "I20")
	assert_eq(names[a1.output_terminal(15) + 1], "Q16.2")
	assert_eq(a1.input_module(7), -1)
	assert_eq(a1.input_module(8), 0)
	assert_eq(a1.output_module(8), 1)
	assert_eq(a1.switch_paths().size(), 16)
	assert_eq(a1.output_armatures.size(), 16)
	assert_eq(a1.module_terminals(0), Vector2i(18, 32))
	assert_eq(a1.module_terminals(1).y, names.size())


func test_modules_fit_up_to_24_inputs_and_20_outputs() -> void:
	var two_large: Array[Plc.Module] = [Plc.Module.DI8_DQ8, Plc.Module.DI8_DQ8]
	assert_true(Plc.modules_fit(two_large), "24 inputs, 20 outputs")
	var four_small: Array[Plc.Module] = [Plc.Module.DI4_DQ4, Plc.Module.DI4_DQ4, Plc.Module.DI4_DQ4, Plc.Module.DI4_DQ4]
	assert_true(Plc.modules_fit(four_small))
	four_small.append(Plc.Module.DI4_DQ4)
	assert_false(Plc.modules_fit(four_small))
	two_large.append(Plc.Module.DI4_DQ4)
	assert_false(Plc.modules_fit(two_large))
	var saved: Array = ["8di8dq", "8di8dq", "4di4dq", "nonsense"]
	assert_eq(DocumentSerializer.plc_modules(saved).size(), 2, "modules beyond what the PLC takes are left out")


## L - Q - A1 L1 / N as in _build; L - Q2 (switch) - A1 2L1, A1 2N - N;
## L - S1 - A1 I9; L - A1 Q5.1, A1 Q5.2 - H1 - N. Program: Q5 = I9.
func _build_module(realistic: bool = false) -> LatchingSwitch:
	var p: PlcProgram = PlcProgram.new()
	var i9: PlcBlock = p.add_block("input", Vector2i(0, 0))
	i9.operand = "I9"
	var q5: PlcBlock = p.add_block("output", Vector2i(4, 0))
	q5.operand = "Q5"
	q5.inputs[0] = i9.id
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	circuit.add(PowerSupply.new("N", PowerSupply.Conductor.N))
	power = circuit.add(LatchingSwitch.new("Q", NO)) as LatchingSwitch
	var module_power: LatchingSwitch = circuit.add(LatchingSwitch.new("Q2", NO)) as LatchingSwitch
	var modules: Array[Plc.Module] = [Plc.Module.DI4_DQ4]
	plc = circuit.add(Plc.new("A1", p, modules)) as Plc
	s1 = circuit.add(PushButton.new("S1", NO)) as PushButton
	h1 = circuit.add(Lamp.new("H1")) as Lamp
	circuit.connect_terminals("L", "Q:13")
	circuit.connect_terminals("Q:14", "A1:L1")
	circuit.connect_terminals("A1:N", "N")
	circuit.connect_terminals("L", "Q2:13")
	circuit.connect_terminals("Q2:14", "A1:2L1")
	circuit.connect_terminals("A1:2N", "N")
	circuit.connect_terminals("L", "S1:13")
	circuit.connect_terminals("S1:14", "A1:I9")
	circuit.connect_terminals("L", "A1:Q5.1")
	circuit.connect_terminals("A1:Q5.2", "H1:X1")
	circuit.connect_terminals("H1:X2", "N")
	sim = Simulator.new(circuit)
	sim.mode = Simulator.Mode.REALISTIC if realistic else Simulator.Mode.IDEAL
	power.set_switched_on(true)
	module_power.set_switched_on(true)
	sim.step()
	return module_power


func test_expansion_module_inputs_and_outputs() -> void:
	var module_power: LatchingSwitch = _build_module()
	assert_true(plc.module_on(0))
	assert_false(h1.energized)
	s1.press()
	sim.step()
	assert_eq(plc.inputs, PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0]), "I9 is on")
	assert_true(h1.energized, "Q5 on the module switches the lamp")
	module_power.set_switched_on(false)
	sim.step()
	assert_false(plc.module_on(0))
	assert_true(plc.energized, "the PLC goes on working")
	assert_false(h1.energized, "a module without its supply switches nothing")
	module_power.set_switched_on(true)
	sim.step()
	assert_true(h1.energized)
	power.set_switched_on(false)
	sim.step()
	assert_false(plc.module_on(0), "a module works only with the PLC")
	assert_false(h1.energized)


func test_expansion_module_draws_current_and_logs() -> void:
	var module_power: LatchingSwitch = _build_module(true)
	_run(0.2)
	var key: String = "A1:2L1"
	assert_almost_eq(sim.last_result.terminal_currents.get(key, 0.0), Plc.MODULE_DRAW, 0.001, "the module draws from its own supply")
	module_power.set_switched_on(false)
	var logged: bool = false
	for i: int in 4:
		for e: Dictionary in sim.step(0.05).events:
			logged = logged or (str(e["text"]) % e["args"]) == "A1: expansion module 1 switched off"
	assert_true(logged, "switching off is logged")


func test_fbd_start_stop_self_holding() -> void:
	_build(_fbd_self_hold())
	assert_true(plc.energized)
	assert_eq(plc.inputs, PackedByteArray([0, 1, 0, 0, 0, 0, 0, 0]), "I2 has voltage through the NC stop button")
	assert_false(h1.energized)
	_click(s1)
	assert_true(h1.energized, "started and holding after the button is released")
	_click(s2)
	assert_false(h1.energized, "stopped")
	assert_eq(sim.last_result.oscillating_tags.size(), 0)


func test_unpowered_plc_does_nothing() -> void:
	_build(_fbd_self_hold())
	_click(s1)
	assert_true(h1.energized)
	power.set_switched_on(false)
	sim.step()
	assert_false(plc.energized)
	assert_false(h1.energized)
	power.set_switched_on(true)
	sim.step()
	assert_false(h1.energized, "the program starts again from 0")


func test_input_needs_voltage_against_n() -> void:
	_build(_fbd_self_hold())
	circuit.remove(circuit.get_component("N"))
	sim.step()
	assert_false(plc.energized)
	assert_eq(plc.inputs, PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]))


func test_fbd_on_delay() -> void:
	var p: PlcProgram = PlcProgram.new()
	var i1: PlcBlock = p.add_block("input", Vector2i.ZERO)
	var ton: PlcBlock = p.add_block("on_delay", Vector2i(4, 0))
	ton.time = 2.0
	var q1: PlcBlock = p.add_block("output", Vector2i(8, 0))
	ton.inputs[0] = i1.id
	q1.inputs[0] = ton.id
	_build(p)
	s1.press()
	sim.step()
	_run(1.9)
	assert_false(h1.energized)
	_run(0.2)
	assert_true(h1.energized)
	s1.release()
	sim.step()
	assert_false(h1.energized)


func test_fbd_off_delay_and_large_step() -> void:
	var p: PlcProgram = PlcProgram.new()
	var i1: PlcBlock = p.add_block("input", Vector2i.ZERO)
	var tof: PlcBlock = p.add_block("off_delay", Vector2i(4, 0))
	tof.time = 1.0
	var q1: PlcBlock = p.add_block("output", Vector2i(8, 0))
	tof.inputs[0] = i1.id
	q1.inputs[0] = tof.id
	_build(p)
	_click(s1)
	assert_true(h1.energized)
	sim.step(0.9)
	assert_true(h1.energized)
	sim.step(5.0)
	assert_false(h1.energized)


func test_fbd_pulse_relay_toggles() -> void:
	var p: PlcProgram = PlcProgram.new()
	var i1: PlcBlock = p.add_block("input", Vector2i.ZERO)
	var toggle: PlcBlock = p.add_block("pulse_relay", Vector2i(4, 0))
	var q1: PlcBlock = p.add_block("output", Vector2i(8, 0))
	toggle.inputs[0] = i1.id
	q1.inputs[0] = toggle.id
	_build(p)
	_click(s1)
	assert_true(h1.energized)
	_click(s1)
	assert_false(h1.energized)
	_click(s1)
	assert_true(h1.energized)


func test_fbd_counter() -> void:
	var p: PlcProgram = PlcProgram.new()
	var i1: PlcBlock = p.add_block("input", Vector2i.ZERO)
	var counter: PlcBlock = p.add_block("counter", Vector2i(4, 0))
	counter.preset = 3
	var q1: PlcBlock = p.add_block("output", Vector2i(8, 0))
	counter.inputs[1] = i1.id
	q1.inputs[0] = counter.id
	_build(p)
	_click(s1)
	_click(s1)
	assert_false(h1.energized)
	_click(s1)
	assert_true(h1.energized)


func test_fbd_basic_functions() -> void:
	var p: PlcProgram = PlcProgram.new()
	var hi: PlcBlock = p.add_block("hi", Vector2i.ZERO)
	var lo: PlcBlock = p.add_block("lo", Vector2i(0, 2))
	var results: Dictionary[String, bool] = {"and": false, "or": true, "nand": true, "nor": false, "xor": true}
	var gates: Dictionary[String, PlcBlock] = {}
	for type: String in results:
		var g: PlcBlock = p.add_block(type, Vector2i(4, 0))
		g.inputs[0] = hi.id
		g.inputs[1] = lo.id
		gates[type] = g
	var inverter: PlcBlock = p.add_block("not", Vector2i(4, 0))
	inverter.inputs[0] = lo.id
	var lonely: PlcBlock = p.add_block("and", Vector2i(4, 0))
	var runtime: PlcRuntime = PlcRuntime.new(p)
	assert_true(runtime.scan_until_stable())
	for type: String in results:
		assert_eq(runtime.values[gates[type].id], results[type], type)
	assert_true(runtime.values[inverter.id])
	assert_false(runtime.values[lonely.id], "nothing connected gives 0")


## LAD: network 1: I1 (NO) in parallel with Q1, I2 (NO, through the NC
## button) in series, coil Q1; network 2: Q1 - on-delay coil T1 2 s;
## network 3: T1 - coil Q2.
func _lad_program() -> PlcProgram:
	var p: PlcProgram = PlcProgram.new()
	p.language = PlcProgram.Language.LAD
	var hold: PlcRung = PlcRung.new()
	hold.set_cell(0, 0, {"kind": "no", "operand": "I1"})
	hold.set_cell(0, 1, {"kind": "no", "operand": "I2"})
	hold.set_coil(0, {"kind": "coil", "operand": "Q1"})
	hold.wire_to_coil(0)
	hold.set_cell(1, 0, {"kind": "no", "operand": "Q1"})
	hold.set_link(0, 0, true)
	var delay: PlcRung = PlcRung.new()
	delay.set_cell(0, 0, {"kind": "no", "operand": "Q1"})
	delay.set_coil(0, {"kind": "on_delay", "operand": "T1", "time": 2.0})
	delay.wire_to_coil(0)
	var after: PlcRung = PlcRung.new()
	after.set_cell(0, 0, {"kind": "no", "operand": "T1"})
	after.set_coil(0, {"kind": "coil", "operand": "Q2"})
	after.wire_to_coil(0)
	p.rungs.append_array([hold, delay, after])
	return p


func test_wire_to_coil_fills_the_row() -> void:
	var rung: PlcRung = PlcRung.new()
	rung.set_cell(0, 2, {"kind": "no", "operand": "I1"})
	rung.set_coil(0, {"kind": "coil", "operand": "Q1"})
	rung.wire_to_coil(0)
	assert_true(rung.get_cell(0, 1).is_empty())
	for c: int in range(3, PlcRung.COLUMNS):
		assert_eq(rung.get_cell(0, c).get("kind", ""), "wire")


func test_lad_self_holding_and_timer() -> void:
	_build(_lad_program())
	assert_false(h1.energized)
	_click(s1)
	assert_true(h1.energized, "held through the parallel Q1 contact")
	_run(1.9)
	assert_false(h2.energized)
	_run(0.2)
	assert_true(h2.energized, "T1 ended 2 s after Q1 came on")
	_click(s2)
	assert_false(h1.energized)
	assert_false(h2.energized)


func test_lad_set_reset_and_counter() -> void:
	var p: PlcProgram = PlcProgram.new()
	p.language = PlcProgram.Language.LAD
	var count: PlcRung = PlcRung.new()
	count.set_cell(0, 0, {"kind": "no", "operand": "I1"})
	count.set_coil(0, {"kind": "count_up", "operand": "C1", "preset": 2})
	count.wire_to_coil(0)
	var set_q: PlcRung = PlcRung.new()
	set_q.set_cell(0, 0, {"kind": "no", "operand": "C1"})
	set_q.set_coil(0, {"kind": "set", "operand": "Q1"})
	set_q.wire_to_coil(0)
	var reset_q: PlcRung = PlcRung.new()
	reset_q.set_cell(0, 0, {"kind": "nc", "operand": "I2"})
	reset_q.set_coil(0, {"kind": "reset", "operand": "Q1"})
	reset_q.wire_to_coil(0)
	reset_q.set_coil(1, {"kind": "reset", "operand": "C1"})
	reset_q.set_link(0, 0, true)
	reset_q.wire_to_coil(1)
	p.rungs.append_array([count, set_q, reset_q])
	_build(p)
	_click(s1)
	assert_false(h1.energized)
	_click(s1)
	assert_true(h1.energized, "set when the count reached 2")
	assert_eq(plc.runtime.counters["C1"].value, 2)
	_click(s2)
	assert_false(h1.energized, "reset")
	assert_eq(plc.runtime.counters["C1"].value, 0)


func test_program_switching_itself_is_reported() -> void:
	var p: PlcProgram = PlcProgram.new()
	var q1: PlcBlock = p.add_block("output", Vector2i(8, 0))
	var inverter: PlcBlock = p.add_block("not", Vector2i(4, 0))
	inverter.inputs[0] = q1.id
	q1.inputs[0] = inverter.id
	_build(p)
	assert_true(sim.last_result.oscillating_tags.has("A1"))


## Q8 (on an expansion module) wired back to I1 through NOT by S1: reported
## like an output among Q1-Q7.
func test_output_switching_itself_through_the_wiring_is_reported_beyond_q7() -> void:
	var p: PlcProgram = PlcProgram.new()
	var i1: PlcBlock = p.add_block("input", Vector2i(0, 0))
	i1.operand = "I1"
	var inverter: PlcBlock = p.add_block("not", Vector2i(4, 0))
	inverter.inputs[0] = i1.id
	var q8: PlcBlock = p.add_block("output", Vector2i(8, 0))
	q8.operand = "Q8"
	q8.inputs[0] = inverter.id
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	circuit.add(PowerSupply.new("N", PowerSupply.Conductor.N))
	var modules: Array[Plc.Module] = [Plc.Module.DI4_DQ4]
	plc = circuit.add(Plc.new("A1", p, modules)) as Plc
	var loop: LatchingSwitch = circuit.add(LatchingSwitch.new("S1", NO)) as LatchingSwitch
	for t: Array in [["L", "A1:L1"], ["A1:N", "N"], ["L", "A1:2L1"], ["A1:2N", "N"], ["L", "A1:Q8.1"], ["A1:Q8.2", "S1:13"], ["S1:14", "A1:I1"]]:
		circuit.connect_terminals(t[0], t[1])
	sim = Simulator.new(circuit)
	sim.step()
	loop.set_switched_on(true)
	sim.step()
	assert_true(sim.last_result.oscillating_tags.has("A1"))


func test_realistic_output_relay_switching_time() -> void:
	_build(_fbd_self_hold(), true)
	s1.press()
	sim.step(0.005)
	assert_false(h1.energized, "the output relay is still pulling in")
	sim.step(0.05)
	assert_true(h1.energized)


func test_realistic_timer_in_steps() -> void:
	var p: PlcProgram = _lad_program()
	_build(p, true)
	s1.press()
	_run(0.1, 0.02)
	s1.release()
	_run(1.8, 0.02)
	assert_false(h2.energized)
	_run(0.3, 0.02)
	assert_true(h2.energized)


func test_program_saved_and_loaded() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	var program: PlcProgram = ExampleCircuits.plc_start_stop_program()
	program.language = PlcProgram.Language.LAD
	doc.add(Plc.new("A1", program), Vector2i(2, 2))
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_not_null(copy)
	var loaded: Plc = copy.circuit.get_component("A1") as Plc
	assert_not_null(loaded)
	assert_eq(loaded.program.language, PlcProgram.Language.LAD)
	assert_eq(loaded.program.to_data(), program.to_data())


func test_networks_of_older_programs_follow_one_another() -> void:
	var p: PlcProgram = PlcProgram.from_data(_lad_program().to_data())
	assert_eq(p.rungs.size(), 1, "one ladder along one power rail")
	var ladder: PlcRung = p.ladder()
	assert_eq(ladder.row_count(), 4)
	assert_eq(ladder.rung_groups(), [Vector2i(0, 1), Vector2i(2, 2), Vector2i(3, 3)] as Array[Vector2i])
	assert_eq(ladder.get_coil(3)["operand"], "Q2")
	_build(p)
	_click(s1)
	assert_true(h1.energized)
	_run(2.1)
	assert_true(h2.energized)


func test_lad_edge_contacts_and_negated_coil() -> void:
	var p: PlcProgram = PlcProgram.new()
	p.language = PlcProgram.Language.LAD
	var ladder: PlcRung = p.ladder()
	# Every rising edge of I1 counts, every falling edge of I1 sets M1.
	ladder.set_cell(0, 0, {"kind": "pos", "operand": "I1"})
	ladder.set_coil(0, {"kind": "count_up", "operand": "C1", "preset": 2})
	ladder.wire_to_coil(0)
	ladder.set_cell(1, 0, {"kind": "neg", "operand": "I1"})
	ladder.set_coil(1, {"kind": "set", "operand": "M1"})
	ladder.wire_to_coil(1)
	ladder.set_cell(2, 0, {"kind": "no", "operand": "C1"})
	ladder.set_coil(2, {"kind": "coil", "operand": "Q1"})
	ladder.wire_to_coil(2)
	ladder.set_cell(3, 0, {"kind": "no", "operand": "M1"})
	ladder.set_coil(3, {"kind": "coil_not", "operand": "Q2"})
	ladder.wire_to_coil(3)
	_build(p)
	assert_true(h2.energized, "negated coil: Q2 on while M1 is 0")
	s1.press()
	sim.step()
	assert_eq(plc.runtime.counters["C1"].value, 1)
	assert_true(h2.energized, "no falling edge yet")
	s1.release()
	sim.step()
	assert_false(h2.energized, "the falling edge set M1")
	s1.press()
	sim.step()
	s1.release()
	sim.step()
	assert_eq(plc.runtime.counters["C1"].value, 2, "one count per rising edge")
	assert_true(h1.energized)


func test_insert_row_keeps_links() -> void:
	var ladder: PlcRung = PlcRung.new()
	ladder.set_cell(0, 0, {"kind": "no", "operand": "I1"})
	ladder.set_cell(1, 0, {"kind": "no", "operand": "I2"})
	ladder.set_link(0, 0, true)
	ladder.insert_row(1)
	assert_eq(ladder.row_count(), 3)
	assert_true(ladder.has_link(0, 0))
	assert_true(ladder.has_link(1, 0), "the link goes on across the new row")
	assert_eq(ladder.get_cell(2, 0)["operand"], "I2")


func test_damaged_program_parts_left_out() -> void:
	var data: Dictionary = {"language": "fbd", "blocks": [
		{"id": 1, "type": "input", "cell": [0, 0], "operand": "I81"},
		{"id": 1, "type": "and", "cell": [0, 0]},
		{"id": 2, "type": "frobnicate", "cell": [0, 0]},
		{"id": 3, "type": "output", "cell": [4, 0], "operand": "Q2", "inputs": [7]},
	], "rungs": [{"rows": [{"cells": [{"kind": "no", "operand": "X1"}, {"kind": "wire"}], "coil": {"kind": "coil", "operand": "I1"}}]}]}
	var p: PlcProgram = PlcProgram.from_data(data)
	assert_eq(p.blocks.size(), 2)
	assert_eq(p.blocks[0].operand, "I1", "invalid operand replaced by the default")
	assert_eq(p.blocks[1].operand, "Q2")
	assert_eq(p.blocks[1].inputs[0], 0, "connection to a missing block dropped")
	assert_true(p.rungs[0].get_cell(0, 0).is_empty())
	assert_eq(p.rungs[0].get_cell(0, 1)["kind"], "wire")
	assert_true(p.rungs[0].get_coil(0).is_empty())


func test_operands() -> void:
	assert_true(PlcProgram.valid_operand("I8", "IQ"))
	assert_true(PlcProgram.valid_operand("I24", "IQ"), "inputs of the expansion modules")
	assert_false(PlcProgram.valid_operand("I81", "IQ"))
	assert_true(PlcProgram.valid_operand("Q20", "Q"))
	assert_false(PlcProgram.valid_operand("Q81", "Q"))
	assert_false(PlcProgram.valid_operand("Q1", "I"))
	assert_false(PlcProgram.valid_operand("M01", "M"))
	assert_eq(PlcProgram.operands("Q").size(), 80)
	assert_eq(PlcProgram.operands("Q")[3], "Q4")


func test_example_runs_in_both_languages() -> void:
	for language: int in [PlcProgram.Language.FBD, PlcProgram.Language.LAD]:
		var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.plc_start_stop())
		(doc.circuit.get_component("A1") as Plc).program.language = language as PlcProgram.Language
		var example_sim: Simulator = Simulator.new(doc.circuit)
		example_sim.step()
		var start: PushButton = doc.circuit.get_component("SB1") as PushButton
		var lamp1: Lamp = doc.circuit.get_component("H1") as Lamp
		var lamp2: Lamp = doc.circuit.get_component("H2") as Lamp
		assert_false(lamp1.energized)
		start.press()
		example_sim.step()
		start.release()
		example_sim.step()
		assert_true(lamp1.energized, "language %d" % language)
		for i: int in 49:
			example_sim.step(0.1)
		assert_false(lamp2.energized)
		example_sim.step(0.2)
		assert_true(lamp2.energized, "language %d" % language)
		assert_eq(CircuitCheck.run(doc), [] as Array[Dictionary])


func test_expansion_modules_saved_and_loaded() -> void:
	var modules: Array[Plc.Module] = [Plc.Module.DI8_DQ8, Plc.Module.DI4_DQ4]
	var a1: Plc = Plc.new("A1", null, modules)
	var names: PackedStringArray = a1.default_terminal_names()
	names[a1.input_terminal(8)] = "LEVEL"
	a1.custom_terminals = names
	var d: Dictionary = DocumentSerializer.component_to_dict(a1)
	assert_eq(d["modules"], ["8di8dq", "4di4dq"])
	var loaded: Plc = DocumentSerializer.component_from_dict(JSON.parse_string(JSON.stringify(d))) as Plc
	assert_eq(loaded.modules, modules)
	assert_eq(loaded.get_terminal_names()[loaded.input_terminal(8)], "LEVEL")
	assert_false(DocumentSerializer.component_to_dict(Plc.new("A2")).has("modules"), "nothing saved without modules")
	assert_true((DocumentSerializer.component_from_dict({"type": "plc", "designation": "A3"}) as Plc).modules.is_empty(), "older files: no modules")


func test_symbol_grows_with_its_modules() -> void:
	var modules: Array[Plc.Module] = [Plc.Module.DI4_DQ4, Plc.Module.DI8_DQ8]
	var a1: Plc = Plc.new("A1", null, modules)
	var cells: Array[Vector2i] = SymbolGeometry.plc_terminal_cells(a1)
	assert_eq(cells.size(), a1.get_terminal_names().size())
	var plain: Array[Vector2i] = SymbolGeometry.plc_terminal_cells(Plc.new("A2"))
	assert_eq(cells.slice(0, plain.size()), plain, "the PLC's own terminals stay put")
	assert_eq(cells[a1.module_terminal(0)], Vector2i(21, 0), "the first module a cell right of the PLC's box")
	assert_eq(cells[a1.output_terminal(4)], Vector2i(21, SymbolGeometry.PLC_HEIGHT))
	assert_eq(cells[a1.module_terminal(1)], Vector2i(42, 0))
	assert_eq(SymbolGeometry.plc_width(a1), 82)
	var seen: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		assert_false(seen.has(cell), "one terminal per cell: %s" % cell)
		seen[cell] = true
	assert_eq(SymbolGeometry.local_lead_direction(a1, "2L1"), SymbolGeometry.DIR_DOWN)
	assert_eq(SymbolGeometry.local_lead_direction(a1, "Q16.2"), SymbolGeometry.DIR_UP)
