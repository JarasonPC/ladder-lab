extends GutTest
## L - S1 (NO 13-14) - S2 (NO 13-14) - N, lamp H1 between L and N.

var circuit: Circuit
var sim: Simulator
var s1: PushButton
var s2: PushButton
var h1: Lamp


func before_each() -> void:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	circuit.add(PowerSupply.new("N", PowerSupply.Conductor.N))
	s1 = circuit.add(PushButton.new("S1", SwitchingElement.ContactType.NO)) as PushButton
	s2 = circuit.add(PushButton.new("S2", SwitchingElement.ContactType.NO)) as PushButton
	h1 = circuit.add(Lamp.new("H1")) as Lamp
	circuit.connect_terminals("L", "S1:13")
	circuit.connect_terminals("S1:14", "S2:13")
	circuit.connect_terminals("S2:14", "N")
	circuit.connect_terminals("L", "H1:X1")
	circuit.connect_terminals("H1:X2", "N")
	sim = Simulator.new(circuit)


func test_no_short_while_line_is_open() -> void:
	s1.press()
	var r: StepResult = sim.step()
	assert_false(r.short_circuit)
	assert_eq(r.short_circuit_path, PackedStringArray())
	assert_true(h1.energized)


func test_short_reports_closing_line() -> void:
	s1.press()
	s2.press()
	var r: StepResult = sim.step()
	assert_true(r.short_circuit)
	assert_eq(r.short_circuit_path, PackedStringArray(["L", "S1", "S2", "N"]))
	assert_false(h1.energized, "supply is down during a short")


func test_direct_wire_short() -> void:
	circuit.connect_terminals("L", "N")
	var r: StepResult = sim.step()
	assert_true(r.short_circuit)
	assert_eq(r.short_circuit_path, PackedStringArray(["L", "N"]))


func test_short_through_relay_contact() -> void:
	circuit.add(Contact.new("K1", SwitchingElement.ContactType.NO, 1))
	circuit.add(Coil.new("K1"))
	circuit.connect_terminals("S1:14", "K1:A1")
	circuit.connect_terminals("K1:A2", "N")
	circuit.connect_terminals("L", "K1:13")
	circuit.connect_terminals("K1:14", "N")
	# S1 energizes K1, whose 13-14 contact shorts L-N; the supply collapses,
	# K1 drops, the short clears, K1 pulls in again.
	s1.press()
	var r: StepResult = sim.step()
	assert_true(r.is_oscillating())
	assert_eq(r.oscillating_tags, PackedStringArray(["K1"]))
