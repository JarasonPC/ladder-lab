extends GutTest
## L - S1 (latching, NO 13-14) - KT1 A1-A2 - N
## L - KT1 17-18 (delayed NO) - H1 - N
## L - KT1 13-14 (instantaneous NO) - H2 - N

var circuit: Circuit
var sim: Simulator
var s1: LatchingSwitch
var kt1: TimerRelay
var h1: Lamp
var h2: Lamp


func _build(mode: TimerRelay.Mode, delay: float) -> void:
	const NO := SwitchingElement.ContactType.NO
	circuit = Circuit.new()
	circuit.add(PowerRail.new("L", PowerRail.Conductor.L))
	circuit.add(PowerRail.new("N", PowerRail.Conductor.N))
	s1 = circuit.add(LatchingSwitch.new("S1", NO)) as LatchingSwitch
	kt1 = circuit.add(TimerRelay.new("KT1", mode, delay)) as TimerRelay
	circuit.add(Contact.new("KT1", NO, 1, true))
	circuit.add(Contact.new("KT1", NO, 1))
	h1 = circuit.add(Lamp.new("H1")) as Lamp
	h2 = circuit.add(Lamp.new("H2")) as Lamp

	circuit.connect_terminals("L", "S1:13")
	circuit.connect_terminals("S1:14", "KT1:A1")
	circuit.connect_terminals("KT1:A2", "N")
	circuit.connect_terminals("L", "KT1:17")
	circuit.connect_terminals("KT1:18", "H1:X1")
	circuit.connect_terminals("H1:X2", "N")
	circuit.connect_terminals("L", "KT1:13")
	circuit.connect_terminals("KT1:14", "H2:X1")
	circuit.connect_terminals("H2:X2", "N")
	sim = Simulator.new(circuit)
	sim.step()


func _run(seconds: float, dt: float) -> void:
	for i: int in roundi(seconds / dt):
		sim.step(dt)


func test_on_delay_switches_lamp_after_delay() -> void:
	_build(TimerRelay.Mode.ON_DELAY, 3.0)
	s1.set_switched_on(true)
	sim.step()
	assert_true(kt1.energized)
	assert_true(h2.energized, "instantaneous contact follows the coil")
	assert_false(h1.energized)
	_run(2.5, 0.5)
	assert_false(h1.energized, "still timing at 2.5 s")
	sim.step(0.5)
	assert_true(h1.energized, "on at 3.0 s")


func test_on_delay_resets_when_power_removed() -> void:
	_build(TimerRelay.Mode.ON_DELAY, 3.0)
	s1.set_switched_on(true)
	sim.step()
	_run(3.0, 0.5)
	assert_true(h1.energized)
	s1.set_switched_on(false)
	sim.step()
	assert_false(h1.energized, "on-delay output drops instantly")
	s1.set_switched_on(true)
	sim.step()
	_run(2.0, 0.5)
	assert_false(h1.energized, "timer restarted from zero")
	_run(1.0, 0.5)
	assert_true(h1.energized)


func test_off_delay_holds_output_after_power_removed() -> void:
	_build(TimerRelay.Mode.OFF_DELAY, 2.0)
	s1.set_switched_on(true)
	sim.step()
	assert_true(h1.energized, "off-delay output follows power on instantly")
	s1.set_switched_on(false)
	sim.step()
	assert_false(h2.energized)
	assert_true(h1.energized)
	_run(1.5, 0.5)
	assert_true(h1.energized, "still timing at 1.5 s")
	sim.step(0.5)
	assert_false(h1.energized, "off at 2.0 s")
