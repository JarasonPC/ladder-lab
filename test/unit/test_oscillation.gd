extends GutTest
## L - S1 (NO 13-14) - K1 11-12 (NC) - K1 A1-A2 - N:
## K1 cuts off its own coil as soon as it pulls in.

var circuit: Circuit
var sim: Simulator
var s1: PushButton
var k1: Coil


func before_each() -> void:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	circuit.add(PowerSupply.new("N", PowerSupply.Conductor.N))
	s1 = circuit.add(PushButton.new("S1", SwitchingElement.ContactType.NO)) as PushButton
	circuit.add(Contact.new("K1", SwitchingElement.ContactType.NC, 1))
	k1 = circuit.add(Coil.new("K1")) as Coil
	circuit.connect_terminals("L", "S1:13")
	circuit.connect_terminals("S1:14", "K1:11")
	circuit.connect_terminals("K1:12", "K1:A1")
	circuit.connect_terminals("K1:A2", "N")
	sim = Simulator.new(circuit)


func test_self_cutoff_reports_oscillation() -> void:
	s1.press()
	var r: StepResult = sim.step()
	assert_false(r.stable)
	assert_true(r.is_oscillating())
	assert_eq(r.oscillating_tags, PackedStringArray(["K1"]))
	assert_lt(r.iterations, sim.max_iterations)


func test_oscillation_is_reported_every_step_until_fixed() -> void:
	s1.press()
	sim.step()
	assert_true(sim.step(0.1).is_oscillating())
	s1.release()
	var r: StepResult = sim.step(0.1)
	assert_true(r.stable)
	assert_false(r.is_oscillating())
	assert_false(k1.energized)


func test_iteration_cap_stops_settling() -> void:
	sim.max_iterations = 2
	s1.press()
	var r: StepResult = sim.step()
	assert_false(r.stable)
	assert_eq(r.iterations, 2)
	assert_eq(r.oscillating_tags, PackedStringArray(["K1"]))
