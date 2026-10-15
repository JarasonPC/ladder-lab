extends GutTest
## Start/stop with a self-holding contact:
## L - S0 (STOP, NC 11-12) - S1 (START, NO 13-14) - K1 A1-A2 - N,
## K1 13-14 in parallel with S1, K1 23-24 switches lamp H1.

var circuit: Circuit
var sim: Simulator
var stop: PushButton
var start: PushButton
var k1: Coil
var h1: Lamp


func before_each() -> void:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	circuit.add(PowerSupply.new("N", PowerSupply.Conductor.N))
	stop = circuit.add(PushButton.new("S0", SwitchingElement.ContactType.NC)) as PushButton
	start = circuit.add(PushButton.new("S1", SwitchingElement.ContactType.NO)) as PushButton
	circuit.add(Contact.new("K1", SwitchingElement.ContactType.NO, 1))
	circuit.add(Contact.new("K1", SwitchingElement.ContactType.NO, 2))
	k1 = circuit.add(Coil.new("K1")) as Coil
	h1 = circuit.add(Lamp.new("H1")) as Lamp

	circuit.connect_terminals("L", "S0:11")
	circuit.connect_terminals("S0:12", "S1:13")
	circuit.connect_terminals("S0:12", "K1:13")
	circuit.connect_terminals("S1:14", "K1:14")
	circuit.connect_terminals("S1:14", "K1:A1")
	circuit.connect_terminals("K1:A2", "N")
	circuit.connect_terminals("L", "K1:23")
	circuit.connect_terminals("K1:24", "H1:X1")
	circuit.connect_terminals("H1:X2", "N")
	sim = Simulator.new(circuit)


func test_starts_off() -> void:
	var r: StepResult = sim.step()
	assert_true(r.stable)
	assert_false(k1.energized)
	assert_false(h1.energized)


func test_start_pulls_in_and_holds() -> void:
	start.press()
	sim.step()
	assert_true(k1.energized)
	assert_true(h1.energized)
	start.release()
	var r: StepResult = sim.step()
	assert_true(r.stable)
	assert_false(r.is_oscillating())
	assert_true(k1.energized, "self-holding contact keeps K1 on")
	assert_true(h1.energized)


func test_stop_drops_out_and_stays_off() -> void:
	start.press()
	sim.step()
	start.release()
	sim.step()
	stop.press()
	sim.step()
	assert_false(k1.energized)
	assert_false(h1.energized)
	stop.release()
	sim.step()
	assert_false(k1.energized, "hold contact is open, K1 stays off")


func test_stop_dominates_start() -> void:
	start.press()
	stop.press()
	sim.step()
	assert_false(k1.energized)
