extends GutTest
## Currents: loads draw them, they spread over wires and switching paths,
## three-phase motors draw what their windings and speed give, protective
## devices trip after their time-current characteristic.

const ExamplePower = preload("res://test/unit/example_power.gd")

const NO := SwitchingElement.ContactType.NO
const ST := ThreePhaseMotor.State
const K := ThreePhaseMotor.Kind


func _sim(doc: SchematicDocument, realistic: bool = false) -> Simulator:
	for c: CircuitComponent in doc.circuit.get_components():
		if c is Fuse or c is ThreePoleFuse or c is CircuitBreaker or c is MotorBreaker:
			c.set("switched_on", true)
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.mode = Simulator.Mode.REALISTIC if realistic else Simulator.Mode.IDEAL
	sim.step()
	return sim


## Steps [param seconds] in [param dt] steps; returns the event texts (filled in).
func _run(sim: Simulator, seconds: float, dt: float = 0.01) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	var t: float = 0.0
	while t < seconds - 1e-9:
		for e: Dictionary in sim.step(dt).events:
			texts.append(e["text"] % e["args"])
		t += dt
	return texts


func _press(doc: SchematicDocument, sim: Simulator, button: String) -> PackedStringArray:
	var b: PushButton = doc.circuit.get_component(button) as PushButton
	b.press()
	var texts: PackedStringArray = _run(sim, 0.1)
	b.release()
	texts.append_array(_run(sim, 0.1))
	return texts


func _motor(doc: SchematicDocument) -> ThreePhaseMotor:
	return doc.circuit.get_component("M1") as ThreePhaseMotor


func _three_supplies(doc: SchematicDocument) -> void:
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("L2", PowerSupply.Conductor.L2), Vector2i(2, 0))
	doc.add(PowerSupply.new("L3", PowerSupply.Conductor.L3), Vector2i(4, 0))


## A motor straight on the supplies, its terminals wired as [param feed]
## (terminal -> supply).
func _motor_on(kind: ThreePhaseMotor.Kind, feed: Dictionary) -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new()
	_three_supplies(doc)
	doc.add(ThreePhaseMotor.new("M1", kind), Vector2i(0, 6))
	for terminal: String in feed:
		doc.connect_terminals(feed[terminal], "M1:" + terminal)
	return doc


# --- Spreading the current --------------------------------------------------------

func test_lamp_current_flows_in_every_wire_of_its_path() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 20))
	doc.add(LatchingSwitch.new("S1", NO), Vector2i(3, 2))
	doc.add(Lamp.new("H1"), Vector2i(3, 8))
	doc.add(Lamp.new("H2"), Vector2i(8, 8))
	doc.connect_terminals("L", "S1:13")
	doc.connect_terminals("S1:14", "H1:X1")
	doc.connect_terminals("H1:X2", "N")
	doc.connect_terminals("L", "H2:X1")
	var sim: Simulator = _sim(doc)
	(doc.circuit.get_component("S1") as LatchingSwitch).set_switched_on(true)
	var r: StepResult = sim.step()
	for w: int in 3:
		assert_almost_eq(r.wire_currents[w], Lamp.RATED_DRAW, 1e-6, "wire %d of the lit lamp" % w)
	assert_eq(r.wire_currents[3], 0.0, "H2 has no return: no current")
	assert_almost_eq(r.terminal_currents["S1:13"], Lamp.RATED_DRAW, 1e-6)
	assert_false(r.terminal_currents.has("H2:X1"))


func test_parallel_contacts_share_the_current() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_holding())
	var sim: Simulator = _sim(doc)
	var start: PushButton = doc.circuit.get_component("SB1") as PushButton
	start.press()
	var r: StepResult = sim.step()
	var through_button: float = r.terminal_currents.get("SB1:13", 0.0)
	var through_hold: float = r.terminal_currents.get("KM1:13", 0.0)
	assert_gt(through_button, 0.0)
	assert_almost_eq(through_button, through_hold, 1e-6, "start button and hold contact in parallel")
	start.release()
	r = sim.step()
	assert_false(r.terminal_currents.has("SB1:13"), "released: only the hold contact carries it")
	assert_almost_eq(r.terminal_currents["KM1:13"], 2.0 * through_hold, 1e-6)


func test_coil_between_two_phases_draws_more() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	_three_supplies(doc)
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 20))
	doc.add(Coil.new("K1"), Vector2i(0, 8))
	doc.add(Coil.new("K2"), Vector2i(4, 8))
	doc.connect_terminals("L1", "K1:A1")
	doc.connect_terminals("K1:A2", "N")
	doc.connect_terminals("L2", "K2:A1")
	doc.connect_terminals("K2:A2", "L3")
	var r: StepResult = _sim(doc).last_result
	assert_almost_eq(r.terminal_currents["K2:A1"] / r.terminal_currents["K1:A1"], sqrt(3.0), 1e-4, "400 V instead of 230 V")


# --- Motors -------------------------------------------------------------------------

func test_motor_draws_rated_current_at_rated_speed() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.direct_on_line())
	var sim: Simulator = _sim(doc)
	_press(doc, sim, "SB1")
	var m: ThreePhaseMotor = _motor(doc)
	for p: int in 3:
		assert_almost_eq(m.line_currents[p], m.rated_current, 0.01)
	assert_almost_eq(m.rpm(), m.rated_speed, 1.0)
	var r: StepResult = sim.last_result
	for key: String in ["FA1:1", "KM1:2", "F1:5", "M1:U1"]:
		assert_almost_eq(r.terminal_currents[key], m.rated_current, 0.01, key)
	assert_almost_eq(doc.circuit.get_overload_relay("F1").current, m.rated_current, 0.01)


func test_starting_current_until_up_to_speed() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.direct_on_line())
	var sim: Simulator = _sim(doc, true)
	var m: ThreePhaseMotor = _motor(doc)
	var start: PushButton = doc.circuit.get_component("SB1") as PushButton
	start.press()
	_run(sim, 0.05)
	assert_almost_eq(m.max_line_current(), m.start_ratio * m.rated_current, 0.5, "starting current at standstill")
	var texts: PackedStringArray = _run(sim, 3.0)
	assert_has(texts, "M1 up to speed")
	assert_almost_eq(m.max_line_current(), m.rated_current, 0.05, "rated current once up to speed")
	assert_false(doc.circuit.get_overload_relay("F1").tripped, "a normal start does not trip the overload relay")
	assert_gt(doc.circuit.get_overload_relay("F1").heat.progress, 0.0, "but warms it up")


func test_star_draws_a_third_of_delta() -> void:
	var star: SchematicDocument = _motor_on(K.STAR_DELTA, {"U1": "L1", "V1": "L2", "W1": "L3"})
	star.connect_terminals("M1:U2", "M1:V2")
	star.connect_terminals("M1:V2", "M1:W2")
	var delta: SchematicDocument = _motor_on(K.STAR_DELTA, {"U1": "L1", "W2": "L1", "V1": "L2", "U2": "L2", "W1": "L3", "V2": "L3"})
	for doc: SchematicDocument in [star, delta]:
		var sim: Simulator = _sim(doc, true)
		sim.step(0.001)
	assert_eq(_motor(star).state, ST.STAR)
	assert_eq(_motor(delta).state, ST.DELTA)
	assert_almost_eq(_motor(star).max_line_current() / _motor(delta).max_line_current(), 1.0 / 3.0, 0.01, "starting currents")
	var m: ThreePhaseMotor = _motor(delta)
	assert_almost_eq(m.terminal_currents[0].length() * sqrt(3.0), m.max_line_current(), 0.01, "winding current is line current / √3")


func test_star_delta_example_relay_sees_the_winding_current() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.star_delta_3())
	var sim: Simulator = _sim(doc)
	_press(doc, sim, "SB2")
	assert_eq(_motor(doc).state, ST.DELTA)
	var relay: OverloadRelay = doc.circuit.get_overload_relay("F1")
	assert_almost_eq(relay.current, _motor(doc).rated_current / sqrt(3.0), 0.01)
	assert_almost_eq(relay.setting, relay.current, 0.05, "set to In / √3")


func test_lost_phase_at_standstill_hums_and_draws_much() -> void:
	var doc: SchematicDocument = _motor_on(K.STANDARD, {"U1": "L1", "V1": "L2"})
	_sim(doc, true).step(1.0)
	var m: ThreePhaseMotor = _motor(doc)
	assert_eq(m.state, ST.PHASE_LOSS)
	assert_false(m.is_turning(), "no starting torque on one phase")
	assert_almost_eq(m.line_currents[0], sqrt(3.0) / 2.0 * m.start_ratio * m.rated_current, 0.5)
	assert_almost_eq(m.line_currents[2], 0.0, 1e-3)


func test_reversed_delta_winding_draws_lots_of_current() -> void:
	# W winding the wrong way round: W1 on L1, W2 on L3.
	var doc: SchematicDocument = _motor_on(K.STAR_DELTA, {"U1": "L1", "W1": "L1", "V1": "L2", "U2": "L2", "W2": "L3", "V2": "L3"})
	var sim: Simulator = _sim(doc, true)
	sim.step(5.0)
	var m: ThreePhaseMotor = _motor(doc)
	assert_gt(m.max_line_current(), 4.0 * m.rated_current, "pulls both ways")
	# Negative sequence 2/3, positive 1/3 of the voltage: it turns the wrong
	# way, weakly, below its rated speed.
	assert_lt(m.rotor_speed, 0.0, "runs backwards")
	assert_lt(absf(m.rotor_speed), m.model().rated_speed(0))


func test_reversing_while_running_draws_more_than_starting() -> void:
	var doc: SchematicDocument = _motor_on(K.STANDARD, {"U1": "L1", "V1": "L2", "W1": "L3"})
	var sim: Simulator = _sim(doc, true)
	sim.step(3.0)
	var m: ThreePhaseMotor = _motor(doc)
	assert_gt(m.rotor_speed, 0.9)
	# The same motor at that speed with two phases swapped.
	var plug: SchematicDocument = _motor_on(K.STANDARD, {"U1": "L3", "V1": "L2", "W1": "L1"})
	var reversed: ThreePhaseMotor = _motor(plug)
	reversed.rotor_speed = m.rotor_speed
	var plug_sim: Simulator = _sim(plug, true)
	assert_gt(reversed.max_line_current(), m.start_ratio * m.rated_current, "plugging: slip near 2")
	plug_sim.step(5.0)
	assert_lt(reversed.rotor_speed, -0.9, "turns the other way in the end")


func test_dc_braking_current() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.dc_braking())
	var sim: Simulator = _sim(doc)
	_press(doc, sim, "SB1")
	_press(doc, sim, "SB0")
	var m: ThreePhaseMotor = _motor(doc)
	assert_eq(m.state, ST.DC_BRAKING)
	assert_almost_eq(m.max_current(), ThreePhaseMotor.DC_BRAKING_CURRENT * m.rated_current, 0.01)


func test_rating_plate_values() -> void:
	var m: ThreePhaseMotor = ThreePhaseMotor.new("M1", K.STAR_DELTA)
	assert_eq(m.synchronous_rpm(), 1500.0)
	assert_almost_eq(m.rated_slip(), 0.04, 1e-6)
	assert_almost_eq(m.efficiency(), 4000.0 / (sqrt(3.0) * 400.0 * 8.0 * 0.82), 1e-6)
	assert_eq(m.plate_voltage(), PackedStringArray(["400/690 V", "Δ/Y"]))
	m.rated_speed = 2880.0
	assert_eq(m.synchronous_rpm(), 3000.0)
	var dahlander: ThreePhaseMotor = ThreePhaseMotor.new("M2", K.DAHLANDER)
	assert_eq(dahlander.rated_speeds(), PackedFloat32Array([720.0, 1440.0]))


func test_power_factor_sets_the_rated_current_angle() -> void:
	for cos_phi: float in [0.7, 0.82, 0.9]:
		var model: MotorModel = MotorModel.of(K.STANDARD, 6.0, 0.04, cos_phi)
		var y: Vector2 = model.admittance(0.04)
		assert_almost_eq(y.length(), 1.0, 1e-3)
		assert_almost_eq(y.x / y.length(), cos_phi, 1e-3)
		assert_almost_eq(model.admittance(1.0).length(), 6.0, 0.01)


# --- Protection ---------------------------------------------------------------------

func test_breakers_default_to_ratings_sold() -> void:
	var ratings: Array[float] = CircuitBreaker.STANDARD_RATINGS
	var sorted: Array[float] = ratings.duplicate()
	sorted.sort()
	assert_eq(ratings, sorted, "offered from the smallest")
	assert_has(ratings, CircuitBreaker.DEFAULT_RATED_CURRENT)
	assert_has(ratings, MotorBreaker.DEFAULT_RATED_CURRENT)
	for c: CircuitComponent in ExampleCircuits.build(0).circuit.get_components():
		if c is CircuitBreaker:
			assert_has(ratings, (c as CircuitBreaker).rated_current, c.designation)
		elif c is MotorBreaker:
			assert_has(ratings, (c as MotorBreaker).rated_current, c.designation)


func test_trip_curves() -> void:
	assert_eq(TripCurve.trip_time(TripCurve.Kind.BREAKER_C, 1.0), INF, "no trip at the rated current")
	assert_eq(TripCurve.trip_time(TripCurve.Kind.BREAKER_B, 5.0), 0.0, "B: magnetic at 5 In")
	assert_gt(TripCurve.trip_time(TripCurve.Kind.BREAKER_C, 7.0), 1.0, "C: thermal only at 7 In")
	assert_eq(TripCurve.trip_time(TripCurve.Kind.BREAKER_C, 10.0), 0.0)
	assert_gt(TripCurve.trip_time(TripCurve.Kind.BREAKER_D, 15.0), 0.0)
	assert_eq(TripCurve.trip_time(TripCurve.Kind.BREAKER_D, 20.0), 0.0)
	var t145: float = TripCurve.trip_time(TripCurve.Kind.BREAKER_C, 1.45)
	assert_true(t145 > 60.0 and t145 < 3600.0, "conventional tripping current within an hour")
	var t72: float = TripCurve.trip_time(TripCurve.Kind.OVERLOAD, 7.2)
	assert_true(t72 > 4.0 and t72 <= 10.0, "class 10")
	var last: float = INF
	for m: float in [1.3, 2.0, 3.0, 5.0, 10.0, 30.0]:
		var t: float = TripCurve.trip_time(TripCurve.Kind.FUSE_GG, m)
		assert_lt(t, last, "inverse time")
		last = t


func test_heat_accumulates_and_cools() -> void:
	var heat: TripCurve = TripCurve.new(TripCurve.Kind.OVERLOAD, 10.0)
	var t: float = TripCurve.trip_time(TripCurve.Kind.OVERLOAD, 3.0)
	assert_false(heat.advance(t * 0.5, 30.0))
	assert_almost_eq(heat.progress, 0.5, 1e-6)
	assert_almost_eq(heat.time_to_trip(30.0), t * 0.5, 1e-6)
	heat.advance(120.0, 10.0)
	assert_lt(heat.progress, 0.25, "cools at the rated current")
	assert_true(heat.advance(1000.0, 30.0))


## DOL power circuit with its three-pole breaker FA1 set to
## [param characteristic] and [param amperes].
func _dol_with_breaker(characteristic: CircuitBreaker.Characteristic, amperes: float) -> SchematicDocument:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.direct_on_line())
	var breaker: MotorBreaker = doc.circuit.get_component("FA1:1-2-3-4-5-6") as MotorBreaker
	breaker.characteristic = characteristic
	breaker.rated_current = amperes
	return doc


## DOL power circuit with fuses FU1 instead of breaker FA1.
func _dol_with_fuses() -> SchematicDocument:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.direct_on_line())
	doc.replace_component("FA1:1-2-3-4-5-6", ThreePoleFuse.new("FU1"))
	return doc


func test_b_breaker_trips_on_the_starting_current() -> void:
	var doc: SchematicDocument = _dol_with_breaker(CircuitBreaker.Characteristic.B, 6.0)
	var sim: Simulator = _sim(doc, true)
	var texts: PackedStringArray = _press(doc, sim, "SB1")
	assert_has(texts, "FA1 tripped (short-circuit release)")
	assert_true((doc.circuit.get_component("FA1:1-2-3-4-5-6") as MotorBreaker).tripped)
	assert_false(_motor(doc).is_running())


func test_d_breaker_lets_the_motor_start() -> void:
	var doc: SchematicDocument = _dol_with_breaker(CircuitBreaker.Characteristic.D, 6.0)
	var sim: Simulator = _sim(doc, true)
	_press(doc, sim, "SB1")
	_run(sim, 2.0)
	assert_false((doc.circuit.get_component("FA1:1-2-3-4-5-6") as MotorBreaker).tripped, "48 A is below 20 x 6 A, too short for the thermal release")
	assert_true(_motor(doc).is_running())
	assert_lt(_motor(doc).max_line_current(), 1.1 * _motor(doc).rated_current)
	sim.step(4000.0)
	assert_true((doc.circuit.get_component("FA1:1-2-3-4-5-6") as MotorBreaker).tripped, "8 A on a 6 A breaker trips in the end")


func test_tripped_breaker_keeps_its_heat_and_cools_down() -> void:
	var doc: SchematicDocument = _dol_with_breaker(CircuitBreaker.Characteristic.D, 6.0)
	var breaker: MotorBreaker = doc.circuit.get_component("FA1:1-2-3-4-5-6") as MotorBreaker
	var sim: Simulator = _sim(doc, true)
	_press(doc, sim, "SB1")
	_run(sim, 2.0)
	var guard: int = 0
	while not breaker.tripped and guard < 1000:
		sim.step(10.0)
		guard += 1
	assert_true(breaker.tripped)
	assert_gt(breaker.heat.progress, 0.85, "the bimetal is still hot after the trip")
	var hot: float = breaker.heat.progress
	sim.step(TripCurve.COOLING_TIME[TripCurve.Kind.BREAKER_D])
	assert_almost_eq(breaker.heat.progress, hot * exp(-1.0), 0.05, "and cools down slowly")
	breaker.toggle()
	assert_false(breaker.tripped)
	assert_gt(breaker.heat.progress, 0.3, "switching on does not cool it")


func test_overload_relay_keeps_its_heat_after_reset() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.direct_on_line())
	var relay: OverloadRelay = doc.circuit.get_overload_relay("F1")
	relay.setting = _motor(doc).rated_current / 1.5
	var sim: Simulator = _sim(doc, true)
	_press(doc, sim, "SB1")
	var guard: int = 0
	while not relay.tripped and guard < 100:
		sim.step(10.0)
		guard += 1
	assert_true(relay.tripped)
	assert_gt(relay.heat.progress, 0.9, "the heaters are still hot after the trip")
	relay.reset()
	assert_false(relay.tripped)
	assert_gt(relay.heat.progress, 0.9, "the reset button does not cool them")
	var hot: float = relay.heat.progress
	sim.step(TripCurve.COOLING_TIME[TripCurve.Kind.OVERLOAD])
	assert_almost_eq(relay.heat.progress, hot * exp(-1.0), 0.05, "they cool down slowly")


func test_small_fuse_blows_during_the_start() -> void:
	var doc: SchematicDocument = _dol_with_fuses()
	(doc.circuit.get_component("FU1:1-2-3-4-5-6") as ThreePoleFuse).rated_current = 6.0
	var sim: Simulator = _sim(doc, true)
	var start: PushButton = doc.circuit.get_component("SB1") as PushButton
	start.press()
	var texts: PackedStringArray = _run(sim, 2.0)
	assert_has(texts, "FU1 blown")
	assert_true((doc.circuit.get_component("FU1:1-2-3-4-5-6") as ThreePoleFuse).any_blown())


func test_ratings_saved() -> void:
	var doc: SchematicDocument = _dol_with_fuses()
	var m: ThreePhaseMotor = _motor(doc)
	m.rated_current = 15.5
	m.start_ratio = 7.5
	m.run_up_time = 2.5
	m.rated_power = 7.5
	m.rated_speed = 2900.0
	m.power_factor = 0.86
	m.show_plate = true
	doc.get_placement("M1").labels["plate"] = Vector2(2, -1)
	(doc.circuit.get_component("FU1:1-2-3-4-5-6") as ThreePoleFuse).rated_current = 25.0
	doc.circuit.get_overload_relay("F1").setting = 15.5
	var breaker: CircuitBreaker = doc.circuit.get_component("FA2") as CircuitBreaker
	breaker.characteristic = CircuitBreaker.Characteristic.D
	breaker.rated_current = 4.0
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	var m2: ThreePhaseMotor = _motor(copy)
	assert_eq([m2.rated_current, m2.start_ratio, m2.run_up_time, m2.rated_power, m2.rated_speed, m2.power_factor, m2.show_plate], [15.5, 7.5, 2.5, 7.5, 2900.0, 0.86, true])
	assert_eq(copy.get_placement("M1").labels.get("plate"), Vector2(2, -1))
	assert_eq((copy.circuit.get_component("FU1:1-2-3-4-5-6") as ThreePoleFuse).rated_current, 25.0)
	assert_eq(copy.circuit.get_overload_relay("F1").setting, 15.5)
	var b2: CircuitBreaker = copy.circuit.get_component("FA2") as CircuitBreaker
	assert_eq([b2.characteristic, b2.rated_current], [CircuitBreaker.Characteristic.D, 4.0])
	var old: Dictionary = DocumentSerializer.to_dict(doc)
	for c: Dictionary in old["components"]:
		for key: String in ["rated_current", "start_ratio", "run_up_time", "rated_power", "rated_speed", "power_factor", "setting", "characteristic"]:
			c.erase(key)
	var older: SchematicDocument = DocumentSerializer.from_dict(old)
	assert_eq(_motor(older).rated_current, ThreePhaseMotor.DEFAULT_RATED_CURRENT, "files before version 16 get the defaults")
	assert_eq(older.circuit.get_overload_relay("F1").setting, OverloadRelay.DEFAULT_SETTING)
