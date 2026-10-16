extends GutTest
## PLC: supply L1-N, inputs against N, relay outputs, programs in FBD and LAD.
##
## L - Q (switch, NO 13-14) - A1 L1, A1 N - N
## L - S1 (button NO 13-14) - A1 I1;  L - S2 (button NC 11-12) - A1 I2
## L - A1 Q1.1, A1 Q1.2 - H1 - N;  L - A1 Q2.1, A1 Q2.2 - H2 - N

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
	assert_eq(names[Plc.input_terminal(0)], "I1")
	assert_eq(names[Plc.output_terminal(3)], "Q4.1")
	assert_eq(names[Plc.output_terminal(3) + 1], "Q4.2")
	assert_eq(a1.switch_paths().size(), 4)


func test_fbd_start_stop_self_holding() -> void:
	_build(_fbd_self_hold())
	assert_true(plc.energized)
	assert_eq(plc.inputs, 2, "I2 has voltage through the NC stop button")
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
	assert_eq(plc.inputs, 0)


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
	var program: PlcProgram = _lad_program()
	program.blocks = _fbd_self_hold().blocks
	doc.add(Plc.new("A1", program), Vector2i(2, 2))
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_not_null(copy)
	var loaded: Plc = copy.circuit.get_component("A1") as Plc
	assert_not_null(loaded)
	assert_eq(loaded.program.language, PlcProgram.Language.LAD)
	assert_eq(loaded.program.to_data(), program.to_data())


func test_damaged_program_parts_left_out() -> void:
	var data: Dictionary = {"language": "fbd", "blocks": [
		{"id": 1, "type": "input", "cell": [0, 0], "operand": "I9"},
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
	assert_false(PlcProgram.valid_operand("I9", "IQ"))
	assert_false(PlcProgram.valid_operand("Q1", "I"))
	assert_false(PlcProgram.valid_operand("M01", "M"))
	assert_eq(PlcProgram.operands("Q"), PackedStringArray(["Q1", "Q2", "Q3", "Q4"]))


func test_example_runs_in_both_languages() -> void:
	for language: int in [PlcProgram.Language.FBD, PlcProgram.Language.LAD]:
		var doc: SchematicDocument = ExampleCircuits.plc_start_stop()
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
