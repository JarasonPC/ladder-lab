extends GutTest
## Simulation fixes: shorts that drop out only their own source, a frequency
## inverter tripping on a short of its output or 24 V, limit switches along a
## mechanical link, time relays with zero times and their event log, instant
## switching with a buzzing relay or an interlock, currents on rectifiers and
## between two + poles.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC

var circuit: Circuit


func _supplies(names: Array) -> void:
	circuit = Circuit.new()
	var conductors: Dictionary = {"L": PowerSupply.Conductor.L, "L1": PowerSupply.Conductor.L, "L2": PowerSupply.Conductor.L2, "L3": PowerSupply.Conductor.L3, "N": PowerSupply.Conductor.N, "+": PowerSupply.Conductor.DC_PLUS, "-": PowerSupply.Conductor.DC_MINUS}
	for name: String in names:
		circuit.add(PowerSupply.new(name, conductors[name]))


func _wire(pairs: Array) -> void:
	for pair: Array in pairs:
		circuit.connect_terminals(pair[0], pair[1])


func _texts(r: StepResult) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for e: Dictionary in r.events:
		texts.append(e["text"] % e["args"])
	return texts


func _sim(realistic: bool) -> Simulator:
	var sim: Simulator = Simulator.new(circuit)
	sim.mode = Simulator.Mode.REALISTIC if realistic else Simulator.Mode.IDEAL
	return sim


## TA1 on L1 L2 L3 run by S1 from its 24 V; S9 puts L1 (through FU1) on its
## output U; S2 joins its 24V to its 0V; H1 on L1-N.
func _drive() -> Vfd:
	_supplies(["L1", "L2", "L3", "N"])
	var drive: Vfd = circuit.add(Vfd.new("TA1")) as Vfd
	circuit.add(Fuse.new("FU1"))
	circuit.add(Lamp.new("H1"))
	for s: String in ["S1", "S2", "S9"]:
		circuit.add(LatchingSwitch.new(s, NO))
	_wire([["L1", "TA1:L1"], ["L2", "TA1:L2"], ["L3", "TA1:L3"], ["TA1:DIC", "TA1:0V"], ["TA1:24V", "S1:13"], ["S1:14", "TA1:DI1"], ["TA1:10V", "TA1:AI1"], ["L1", "FU1:1"], ["FU1:2", "S9:13"], ["S9:14", "TA1:U"], ["TA1:24V", "S2:13"], ["S2:14", "TA1:0V"], ["L1", "H1:X1"], ["H1:X2", "N"]])
	return drive


func _switch(designation: String, on: bool) -> void:
	(circuit.get_component(designation) as LatchingSwitch).set_switched_on(on)


func test_short_on_a_drive_output_trips_the_drive_not_the_mains() -> void:
	for realistic: bool in [false, true]:
		var drive: Vfd = _drive()
		var sim: Simulator = _sim(realistic)
		_switch("S1", true)
		sim.step(0.5)
		assert_true(drive.output, "runs")
		_switch("S9", true)
		var r: StepResult = sim.step(0.1)
		assert_true(drive.tripped, "the short on U trips it")
		assert_false(drive.output)
		assert_has(_texts(r), "TA1: short circuit, output off")
		assert_false(r.short_circuit, "which ends the short")
		assert_false((circuit.get_component("FU1") as Fuse).tripped, "the fuse stays")
		assert_true((circuit.get_component("H1") as Lamp).energized, "the mains goes on")
		r = sim.step(0.1)
		assert_false(drive.output, "stays off while the run command stays")
		assert_does_not_have(_texts(r), "TA1: short circuit, output off", "logged once")
		_switch("S9", false)
		sim.step(0.1)
		assert_false(drive.output)
		_switch("S1", false)
		sim.step(0.1)
		_switch("S1", true)
		sim.step(0.5)
		assert_false(drive.tripped, "a new run command")
		assert_true(drive.output, "runs again")


func test_short_on_a_drive_24v_leaves_the_mains() -> void:
	for realistic: bool in [false, true]:
		var drive: Vfd = _drive()
		var sim: Simulator = _sim(realistic)
		_switch("S1", true)
		sim.step(0.5)
		_switch("S2", true)
		var r: StepResult = sim.step(0.1)
		assert_true(r.short_circuit, "nothing interrupts it")
		assert_eq(r.short_circuit_path, PackedStringArray(["TA1:24V", "S2:13-14", "TA1:0V"]))
		assert_has(r.current_components, "S2:13-14", "the fault path is shown")
		assert_true(drive.tripped)
		assert_false(drive.output)
		assert_true((circuit.get_component("H1") as Lamp).energized, "the mains lamp stays lit")
		r = sim.step(0.1)
		assert_does_not_have(_texts(r), "TA1: short circuit, output off", "logged once")


func test_unprotected_short_drops_out_its_own_source_only() -> void:
	for realistic: bool in [false, true]:
		_supplies(["L", "N", "+", "-"])
		var h1: Lamp = circuit.add(Lamp.new("H1")) as Lamp
		var h2: Lamp = circuit.add(Lamp.new("H2")) as Lamp
		h2.rating = "24v"
		circuit.add(LatchingSwitch.new("S1", NO))
		circuit.add(LatchingSwitch.new("S2", NO))
		_wire([["L", "H1:X1"], ["H1:X2", "N"], ["+", "H2:X1"], ["H2:X2", "-"], ["+", "S1:13"], ["S1:14", "-"], ["L", "S2:13"], ["S2:14", "N"]])
		var sim: Simulator = _sim(realistic)
		sim.step(0.1)
		_switch("S1", true)
		var r: StepResult = sim.step(0.1)
		assert_true(r.short_circuit)
		assert_false(h2.energized, "the DC source drops out")
		assert_true(h1.energized, "the mains goes on")
		assert_has(r.current_components, "S1:13-14", "the fault path is shown")
		assert_does_not_have(r.current_components, "H1", "and nothing else")
		_switch("S1", false)
		_switch("S2", true)
		r = sim.step(0.1)
		assert_true(r.short_circuit)
		assert_false(h1.energized, "the mains drops out")
		assert_true(h2.energized, "the DC source goes on")


## L - M1 - N moves G1 from 0 to 1 in 2 s past SQ5.
func _link(where: float) -> Travel:
	_supplies(["L", "N"])
	var m: Motor = circuit.add(Motor.new("M1")) as Motor
	var sq: LimitSwitch = circuit.add(LimitSwitch.new("SQ5", NO)) as LimitSwitch
	_wire([["L", "M1:U1"], ["M1:U2", "N"]])
	var travel: Travel = Travel.new("G1", m, 2.0, 0.0)
	travel.add_switch(sq, where)
	return travel


func test_limit_switch_along_the_way_in_one_long_step() -> void:
	for where: float in [0.3, 0.33, 0.5, 0.6, 0.7]:
		var travel: Travel = _link(where)
		var sim: Simulator = _sim(true)
		sim.travels = [travel]
		sim.step()
		var times: Dictionary = {}
		for e: Dictionary in sim.step(3.0).events:
			times[e["text"] % e["args"]] = e["time"]
		assert_almost_eq(times.get("SQ5 actuated", -1.0), (where - Travel.BAND) * 2.0, 1e-6, "actuated at %s" % where)
		assert_almost_eq(times.get("SQ5 let go", -1.0), (where + Travel.BAND) * 2.0, 1e-6, "let go at %s" % where)


func test_dahlander_at_low_speed_moves_the_part_slower() -> void:
	_supplies(["L1", "L2", "L3"])
	var m: ThreePhaseMotor = circuit.add(ThreePhaseMotor.new("M1", ThreePhaseMotor.Kind.DAHLANDER)) as ThreePhaseMotor
	_wire([["L1", "M1:1U"], ["L2", "M1:1V"], ["L3", "M1:1W"]])
	var sim: Simulator = _sim(false)
	var travel: Travel = Travel.new("G1", m, 10.0, 0.0)
	sim.travels = [travel]
	sim.step()
	sim.step(1.0)
	assert_eq(m.speed, 1, "low speed")
	assert_almost_eq(travel.position, 0.1 * m.rpm() / m.rated_speed, 0.002, "at the speed it turns, the fastest one taking 10 s")


func test_link_moves_on_when_a_step_has_too_many_events() -> void:
	var travel: Travel = _link(0.9)
	travel.time = 10.0
	circuit.add(Coil.new("K1"))
	circuit.add(LatchingSwitch.new("S1", NO))
	_wire([["L", "S1:13"], ["S1:14", "K1:A1"], ["K1:A2", "N"]])
	var sim: Simulator = _sim(true)
	sim.travels = [travel]
	sim.max_events = 1
	sim.step()
	_switch("S1", true)
	sim.step(1.0)
	assert_almost_eq(travel.position, 0.1, 1e-6, "the whole second")


func test_cycling_time_relay_with_zero_times_takes_time() -> void:
	_supplies(["L", "N"])
	var kt: TimerRelay = circuit.add(TimerRelay.new("KT1", TimerRelay.Mode.CYCLE_PULSE_FIRST, 0.0)) as TimerRelay
	kt.delay2 = 0.0
	_wire([["L", "KT1:A1"], ["KT1:A2", "N"]])
	var sim: Simulator = _sim(true)
	sim.step()
	var r: StepResult = sim.step(0.016)
	assert_lt(r.iterations, 100, "a cycle of the shortest steps, not endless switching")
	assert_lt(sim.time, 0.0161 + 1e-9)


func test_cleared_stuck_fault_in_ideal_mode() -> void:
	_supplies(["L", "N"])
	var k1: Coil = circuit.add(Coil.new("K1")) as Coil
	circuit.add(Contact.new("K1", NO))
	var h1: Lamp = circuit.add(Lamp.new("H1")) as Lamp
	circuit.add(LatchingSwitch.new("S1", NO))
	_wire([["L", "S1:13"], ["S1:14", "K1:A1"], ["K1:A2", "N"], ["L", "K1:13"], ["K1:14", "H1:X1"], ["H1:X2", "N"]])
	var sim: Simulator = _sim(false)
	_switch("S1", true)
	sim.step()
	k1.fault = Coil.Fault.STUCK
	_switch("S1", false)
	sim.step()
	assert_true(h1.energized, "stuck pulled in")
	k1.fault = Coil.Fault.NONE
	sim.step()
	assert_false(h1.energized, "released at once")


func test_timed_output_switched_with_the_power_is_logged() -> void:
	for mode: TimerRelay.Mode in [TimerRelay.Mode.PULSE_ON_POWER, TimerRelay.Mode.ON_DELAY]:
		_supplies(["L", "N"])
		circuit.add(TimerRelay.new("KT1", mode, 1.0))
		circuit.add(LatchingSwitch.new("S1", NO))
		_wire([["L", "S1:13"], ["S1:14", "KT1:A1"], ["KT1:A2", "N"]])
		var sim: Simulator = _sim(true)
		sim.step()
		_switch("S1", true)
		var on: PackedStringArray = _texts(sim.step(1.5))
		_switch("S1", false)
		var off: PackedStringArray = _texts(sim.step(0.5))
		assert_eq(on.count("KT1 timed output on"), 1, TimerRelay.code_of(mode))
		assert_eq(on.count("KT1 timed output off") + off.count("KT1 timed output off"), 1, TimerRelay.code_of(mode))
		if mode == TimerRelay.Mode.ON_DELAY:
			assert_has(off, "KT1 timed output off", "F2 goes off with the power")


func test_blown_pole_keeps_its_heat() -> void:
	var fuse: ThreePoleFuse = ThreePoleFuse.new("FU1")
	fuse.rated_current = 2.0
	var currents: PackedFloat32Array = PackedFloat32Array([6.0, 0.0, 0.0])
	var blew: bool = false
	for i: int in 1000:
		if fuse.heat_up(0.1, currents):
			blew = true
			break
	assert_true(blew)
	assert_eq(fuse.blown[0], 1)
	assert_almost_eq(fuse.heat[0].progress, 1.0, 1e-6, "as hot as when it blew, like a single fuse")
	fuse.reset()
	assert_true(fuse.heat.is_empty(), "a new fuse is cold")


func test_buzzing_relay_does_not_hold_up_the_others() -> void:
	_supplies(["L", "N"])
	circuit.add(Contact.new("KA1", NC, 1))
	circuit.add(Coil.new("KA1", Coil.Kind.RELAY))
	var sb1: PushButton = circuit.add(PushButton.new("SB1", NO, 1)) as PushButton
	var ka2: Coil = circuit.add(Coil.new("KA2", Coil.Kind.RELAY)) as Coil
	_wire([["L", "KA1:11"], ["KA1:12", "KA1:A1"], ["KA1:A2", "N"], ["L", "SB1:13"], ["SB1:14", "KA2:A1"], ["KA2:A2", "N"]])
	var sim: Simulator = _sim(false)
	sim.step()
	sb1.press()
	var r: StepResult = sim.step(0.1)
	assert_true(ka2.energized, "KA2 pulls in")
	assert_eq(r.oscillating_tags, PackedStringArray(["KA1"]))
	assert_false(r.stable)
	sb1.release()
	r = sim.step(0.1)
	assert_false(ka2.energized, "and drops out")
	assert_eq(r.oscillating_tags, PackedStringArray(["KA1"]))


func test_interlocked_reversing_in_ideal_mode_blows_nothing() -> void:
	_supplies(["L1", "L2", "L3", "N"])
	var fu: ThreePoleFuse = ThreePoleFuse.new("FU1")
	fu.rated_current = 25.0
	circuit.add(fu)
	circuit.add(MainContacts.new("KM1"))
	circuit.add(MainContacts.new("KM2"))
	var m: ThreePhaseMotor = circuit.add(ThreePhaseMotor.new("M1")) as ThreePhaseMotor
	circuit.add(LatchingSwitch.new("SA1", NO, 1))
	var km1: Coil = circuit.add(Coil.new("KM1")) as Coil
	circuit.add(Contact.new("KM1", NC, 2))
	var km2: Coil = circuit.add(Coil.new("KM2")) as Coil
	for i: int in 3:
		_wire([[["L1", "L2", "L3"][i], "FU1:%d" % (2 * i + 1)], ["FU1:%d" % (2 * i + 2), "KM1:%d" % (2 * i + 1)], ["FU1:%d" % (2 * i + 2), "KM2:%d" % (2 * i + 1)]])
	# KM2 with L1 and L3 swapped; fed through KM1's NC 21-22.
	_wire([["KM1:2", "M1:U1"], ["KM1:4", "M1:V1"], ["KM1:6", "M1:W1"], ["KM2:2", "M1:W1"], ["KM2:4", "M1:V1"], ["KM2:6", "M1:U1"], ["L1", "SA1:13"], ["SA1:14", "KM1:A1"], ["KM1:A2", "N"], ["L1", "KM1:21"], ["KM1:22", "KM2:A1"], ["KM2:A2", "N"]])
	var sim: Simulator = _sim(false)
	sim.step()
	sim.step(1.0)
	assert_eq(m.direction, ThreePhaseMotor.Direction.COUNTERCLOCKWISE)
	_switch("SA1", true)
	var r: StepResult = sim.step(1.0)
	assert_true(km1.energized)
	assert_false(km2.energized, "KM1's NC drops KM2")
	assert_false(fu.any_blown(), "the two never are on together")
	assert_does_not_have(_texts(r), "FU1 blown")
	assert_eq(m.direction, ThreePhaseMotor.Direction.CLOCKWISE)


func test_time_relay_sees_s_change_with_its_power() -> void:
	for mode: TimerRelay.Mode in [TimerRelay.Mode.PULSE_ON_PRESS, TimerRelay.Mode.PULSE_AFTER_RELEASE, TimerRelay.Mode.TOGGLE]:
		_supplies(["L", "N"])
		var kt: TimerRelay = TimerRelay.new("KT1", mode, 1.0)
		kt.control_input = true
		circuit.add(kt)
		var sb1: PushButton = circuit.add(PushButton.new("SB1", NO, 1)) as PushButton
		circuit.add(PushButton.new("SB1", NC, 2))
		_wire([["L", "SB1:13"], ["SB1:14", "KT1:A1"], ["KT1:A2", "N"], ["L", "SB1:21"], ["SB1:22", "KT1:S"]])
		var sim: Simulator = _sim(false)
		sim.step()
		sb1.press()
		sim.step(0.1)
		assert_true(kt.energized)
		assert_false(kt.control)
		assert_false(kt.output, "%s: S was released as the power came" % TimerRelay.code_of(mode))


func test_rectifier_current_returns_on_its_own_minus() -> void:
	_supplies(["L", "N", "-"])
	circuit.add(Rectifier.new("TB1"))
	var h1: Lamp = circuit.add(Lamp.new("H1")) as Lamp
	_wire([["L", "TB1:~1"], ["TB1:~2", "N"], ["TB1:+", "H1:X1"], ["H1:X2", "-"], ["-", "TB1:-"]])
	var r: StepResult = _sim(false).step()
	assert_true(h1.energized)
	assert_almost_eq(r.terminal_currents.get("TB1:-", 0.0), Load.RATED_DRAW, 1e-6, "back into the rectifier")
	assert_almost_eq(r.terminal_currents.get("-", 0.0), 0.0, 1e-6, "not into the - supply")


func test_load_between_two_plus_poles_draws_current() -> void:
	_supplies(["+"])
	var plus12: PowerSupply = PowerSupply.new("+.2", PowerSupply.Conductor.DC_PLUS)
	plus12.voltage = 12.0
	circuit.add(plus12)
	circuit.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS))
	var h1: Lamp = circuit.add(Lamp.new("H1")) as Lamp
	h1.rating = "12v"
	_wire([["+", "H1:X1"], ["H1:X2", "+.2"]])
	var r: StepResult = _sim(false).step()
	assert_true(h1.energized, "12 V across it")
	assert_almost_eq(r.terminal_currents.get("H1:X1", 0.0), Load.RATED_DRAW, 1e-6)
	assert_almost_eq(r.terminal_currents.get("+", 0.0), Load.RATED_DRAW, 1e-6, "from the 24 V pole")
