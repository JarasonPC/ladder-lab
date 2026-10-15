extends GutTest
## Forward/reverse with electrical interlock (blokování):
## L - S0 (STOP) - S1 (FWD) - K2 21-22 - K1 A1-A2 - N, K1 13-14 parallel to S1
##           \--- S2 (REV) - K1 21-22 - K2 A1-A2 - N, K2 13-14 parallel to S2
## Motor M1 is fed by K1 33-34 or K2 33-34.

var circuit: Circuit
var sim: Simulator
var stop: PushButton
var fwd: PushButton
var rev: PushButton
var k1: Coil
var k2: Coil
var m1: Motor


func before_each() -> void:
	const NO := SwitchingElement.ContactType.NO
	const NC := SwitchingElement.ContactType.NC
	circuit = Circuit.new()
	circuit.add(PowerRail.new("L", PowerRail.Conductor.L))
	circuit.add(PowerRail.new("N", PowerRail.Conductor.N))
	stop = circuit.add(PushButton.new("S0", NC)) as PushButton
	fwd = circuit.add(PushButton.new("S1", NO)) as PushButton
	rev = circuit.add(PushButton.new("S2", NO)) as PushButton
	for tag: String in ["K1", "K2"]:
		circuit.add(Contact.new(tag, NO, 1))
		circuit.add(Contact.new(tag, NC, 2))
		circuit.add(Contact.new(tag, NO, 3))
	k1 = circuit.add(Coil.new("K1")) as Coil
	k2 = circuit.add(Coil.new("K2")) as Coil
	m1 = circuit.add(Motor.new("M1")) as Motor

	circuit.connect_terminals("L", "S0:11")
	# Forward branch.
	circuit.connect_terminals("S0:12", "S1:13")
	circuit.connect_terminals("S0:12", "K1:13")
	circuit.connect_terminals("S1:14", "K1:14")
	circuit.connect_terminals("S1:14", "K2:21")
	circuit.connect_terminals("K2:22", "K1:A1")
	circuit.connect_terminals("K1:A2", "N")
	# Reverse branch.
	circuit.connect_terminals("S0:12", "S2:13")
	circuit.connect_terminals("S0:12", "K2:13")
	circuit.connect_terminals("S2:14", "K2:14")
	circuit.connect_terminals("S2:14", "K1:21")
	circuit.connect_terminals("K1:22", "K2:A1")
	circuit.connect_terminals("K2:A2", "N")
	# Motor.
	circuit.connect_terminals("L", "K1:33")
	circuit.connect_terminals("L", "K2:33")
	circuit.connect_terminals("K1:34", "M1:U1")
	circuit.connect_terminals("K2:34", "M1:U1")
	circuit.connect_terminals("M1:U2", "N")
	sim = Simulator.new(circuit)


func _tap(button: PushButton) -> void:
	button.press()
	sim.step()
	button.release()
	sim.step()


func test_forward_runs() -> void:
	_tap(fwd)
	assert_true(k1.energized)
	assert_false(k2.energized)
	assert_true(m1.energized)


func test_reverse_blocked_while_forward_runs() -> void:
	_tap(fwd)
	rev.press()
	var r: StepResult = sim.step()
	assert_true(r.stable)
	assert_true(k1.energized)
	assert_false(k2.energized, "K1 21-22 interlock keeps K2 off")
	rev.release()
	sim.step()
	assert_true(k1.energized)
	assert_false(k2.energized)


func test_reverse_after_stop() -> void:
	_tap(fwd)
	_tap(stop)
	assert_false(k1.energized)
	assert_false(m1.energized)
	_tap(rev)
	assert_false(k1.energized)
	assert_true(k2.energized)
	assert_true(m1.energized)


func test_both_pressed_from_rest_has_one_winner() -> void:
	fwd.press()
	rev.press()
	var r: StepResult = sim.step()
	assert_true(r.stable)
	assert_false(r.is_oscillating())
	assert_ne(k1.energized, k2.energized, "exactly one contactor pulls in")
	assert_true(k1.energized, "K1 was added first, so it wins the race")
	assert_true(m1.energized)
