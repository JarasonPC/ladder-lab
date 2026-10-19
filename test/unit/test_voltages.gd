extends GutTest
## Rated voltages: supplies of 230 / 400 V AC and 12-220 V DC; coils, lamps
## and PLCs work on their voltage, not below it, and burn out far above it.

const NO := SwitchingElement.ContactType.NO

var circuit: Circuit
var sim: Simulator


## A supply between [param a] and [param b] (supply designations) feeding
## [param load] (its first terminal on [param a]).
func _feed(load: Load, a: String, b: String) -> void:
	circuit.add(load)
	var keys: PackedStringArray = load.get_terminal_keys()
	circuit.connect_terminals(a, keys[0])
	circuit.connect_terminals(keys[1], b)


func _supplies(dc_volts: float = 24.0) -> void:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("L1", PowerSupply.Conductor.L))
	circuit.add(PowerSupply.new("L2", PowerSupply.Conductor.L2))
	circuit.add(PowerSupply.new("N", PowerSupply.Conductor.N))
	var plus: PowerSupply = PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS)
	plus.voltage = dc_volts
	circuit.add(plus)
	circuit.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS))


func _coil(designation: String, rating: String) -> Coil:
	var coil: Coil = Coil.new(designation)
	coil.rating = rating
	return coil


func _logged(result: StepResult, text: String) -> bool:
	for e: Dictionary in result.events:
		if (str(e["text"]) % e["args"]) == text:
			return true
	return false


func test_ratings() -> void:
	assert_eq(VoltageRating.state("24dc", 24.0, true), VoltageRating.State.WORKS)
	assert_eq(VoltageRating.state("24dc", 20.0, true), VoltageRating.State.OFF, "below 85 %")
	assert_eq(VoltageRating.state("24dc", 48.0, true), VoltageRating.State.BURNS)
	assert_eq(VoltageRating.state("24dc", 24.0, false), VoltageRating.State.OFF, "a DC coil does not pull in on AC")
	assert_eq(VoltageRating.state("230ac", 220.0, true), VoltageRating.State.BURNS, "an AC coil burns out on DC")
	assert_eq(VoltageRating.state("230ac", 398.0, false), VoltageRating.State.BURNS)
	assert_eq(VoltageRating.state("230v", 220.0, true), VoltageRating.State.WORKS, "a lamp lights on DC too")
	assert_eq(VoltageRating.state("", 12.0, true), VoltageRating.State.WORKS, "no rating: any voltage")
	assert_eq(VoltageRating.state("230rc", 110.0, true), VoltageRating.State.WORKS, "115-240 V AC/DC")
	assert_eq(VoltageRating.state("1224rc", 12.0, true), VoltageRating.State.WORKS)
	assert_eq(VoltageRating.state("1224rc", 230.0, false), VoltageRating.State.BURNS)
	assert_eq(VoltageRating.text("24dc"), "24 V DC")
	assert_eq(VoltageRating.text("230ac"), "230 V AC")
	assert_eq(VoltageRating.text("24v"), "24 V")
	assert_eq(VoltageRating.text("1224rc"), "12/24 V DC")
	assert_eq(VoltageRating.text(""), "")


func test_coils_on_ac() -> void:
	_supplies()
	var km1: Coil = _coil("KM1", "230ac")
	var km2: Coil = _coil("KM2", "400ac")
	var km3: Coil = _coil("KM3", "400ac")
	var km4: Coil = _coil("KM4", "230ac")
	_feed(km1, "L1", "N")
	_feed(km2, "L1", "N")
	_feed(km3, "L1", "L2")
	_feed(km4, "L1", "L2")
	sim = Simulator.new(circuit)
	var r: StepResult = sim.step()
	assert_true(km1.energized, "230 V coil between L1 and N")
	assert_false(km2.energized, "a 400 V coil does not pull in on 230 V")
	assert_true(km3.energized, "400 V between two phases")
	assert_false(km4.energized)
	assert_true(km4.burnt, "a 230 V coil burns out on 400 V")
	assert_true(_logged(r, "KM4 burnt out: too high a voltage for 230 V AC"))
	assert_false(km1.burnt)
	sim.step()
	assert_true(km4.burnt, "it stays burnt out")


func test_dc_voltages() -> void:
	_supplies(12.0)
	var ka1: Coil = _coil("KA1", "12dc")
	var ka2: Coil = _coil("KA2", "24dc")
	var ka3: Coil = _coil("KA3", "230ac")
	var h1: Lamp = Lamp.new("H1")
	h1.rating = "12v"
	_feed(ka1, "+", "-")
	_feed(ka2, "+", "-")
	_feed(ka3, "+", "-")
	_feed(h1, "+", "-")
	sim = Simulator.new(circuit)
	sim.step()
	assert_true(ka1.energized)
	assert_false(ka2.energized, "12 V is too little for a 24 V coil")
	assert_false(ka2.burnt)
	assert_true(h1.energized)
	assert_false(ka3.burnt, "12 V DC is too little to burn a 230 V AC coil")


func test_dc_on_an_ac_coil_burns_it() -> void:
	_supplies(220.0)
	var ka1: Coil = _coil("KA1", "230ac")
	var ka2: Coil = _coil("KA2", "220dc")
	_feed(ka1, "+", "-")
	_feed(ka2, "L1", "N")
	sim = Simulator.new(circuit)
	sim.step()
	assert_true(ka1.burnt, "no reactance on DC")
	assert_false(ka2.energized, "a DC coil does not pull in on AC")
	assert_false(ka2.burnt)


func test_supplies_of_two_voltages_joined_are_a_short() -> void:
	_supplies(24.0)
	var plus12: PowerSupply = PowerSupply.new("+.2", PowerSupply.Conductor.DC_PLUS)
	plus12.voltage = 12.0
	circuit.add(plus12)
	var s1: LatchingSwitch = circuit.add(LatchingSwitch.new("S1", NO)) as LatchingSwitch
	circuit.connect_terminals("+", "S1:13")
	circuit.connect_terminals("S1:14", "+.2")
	sim = Simulator.new(circuit)
	assert_false(sim.step().short_circuit)
	s1.set_switched_on(true)
	assert_true(sim.step().short_circuit, "24 V and 12 V joined")
	var same: Circuit = Circuit.new()
	same.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS))
	same.add(PowerSupply.new("+.2", PowerSupply.Conductor.DC_PLUS))
	same.connect_terminals("+", "+.2")
	assert_false(Simulator.new(same).step().short_circuit, "two supplies of the same voltage")


func test_plc_versions() -> void:
	_supplies(24.0)
	var a1: Plc = Plc.new("A1")
	a1.rating = "1224rc"
	var a2: Plc = Plc.new("A2")
	a2.rating = "1224rc"
	var a3: Plc = Plc.new("A3")
	a3.rating = "230rc"
	_feed(a1, "+", "-")
	_feed(a2, "L1", "N")
	_feed(a3, "L1", "N")
	circuit.connect_terminals("+", "A1:I1")
	circuit.connect_terminals("L1", "A3:I1")
	sim = Simulator.new(circuit)
	var r: StepResult = sim.step()
	assert_true(a1.energized, "12/24 V DC on 24 V")
	assert_eq(a1.inputs, PackedByteArray([1, 0, 0, 0, 0, 0, 0, 0]), "a 24 V input")
	assert_true(a2.burnt, "230 V on a 12/24 V PLC")
	assert_true(_logged(r, "A2 burnt out: too high a voltage for 12/24 V DC"))
	assert_true(a3.energized)
	assert_eq(a3.inputs, PackedByteArray([1, 0, 0, 0, 0, 0, 0, 0]))


func test_plc_input_overvoltage_burns_it() -> void:
	_supplies(24.0)
	var a1: Plc = Plc.new("A1")
	a1.rating = "1224rc"
	_feed(a1, "+", "-")
	var s1: LatchingSwitch = circuit.add(LatchingSwitch.new("S1", NO)) as LatchingSwitch
	var plus48: PowerSupply = PowerSupply.new("+.2", PowerSupply.Conductor.DC_PLUS)
	plus48.voltage = 48.0
	circuit.add(plus48)
	circuit.connect_terminals("+.2", "S1:13")
	circuit.connect_terminals("S1:14", "A1:I2")
	sim = Simulator.new(circuit)
	sim.step()
	assert_true(a1.energized)
	s1.set_switched_on(true)
	sim.step()
	assert_true(a1.burnt, "48 V on a 12/24 V input")
	assert_false(a1.energized)


func test_burnt_out_lamp_draws_nothing_and_is_replaced() -> void:
	_supplies()
	var h1: Lamp = Lamp.new("H1")
	h1.rating = "24v"
	_feed(h1, "L1", "N")
	sim = Simulator.new(circuit)
	var r: StepResult = sim.step()
	assert_true(h1.burnt)
	assert_false(h1.energized)
	assert_does_not_have(r.current_components, "H1")
	SchematicView._clear_fault(h1)
	assert_false(h1.burnt, "replaced")


func test_saved_and_loaded() -> void:
	var plus: PowerSupply = PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS)
	plus.voltage = 48.0
	var copy: PowerSupply = DocumentSerializer.component_from_dict(JSON.parse_string(JSON.stringify(DocumentSerializer.component_to_dict(plus)))) as PowerSupply
	assert_eq(copy.voltage, 48.0)
	assert_eq(copy.source_bit(), PowerSupply.BIT_DC_48)
	var old: PowerSupply = DocumentSerializer.component_from_dict({"type": "supply", "designation": "+", "conductor": "+"}) as PowerSupply
	assert_eq(old.voltage, 24.0, "files before version 20: 24 V")
	assert_eq(old.source_bit(), PowerSupply.BIT_DC_PLUS)
	var bad: PowerSupply = DocumentSerializer.component_from_dict({"type": "supply", "designation": "+", "conductor": "+", "voltage": 13}) as PowerSupply
	assert_eq(bad.voltage, 24.0, "a voltage not offered is left out")
	for load: Load in [_coil("KA1", "24dc"), Lamp.new("H1"), Plc.new("A1"), TimerRelay.new("KT1", TimerRelay.Mode.ON_DELAY, 1.0)]:
		if load is Lamp:
			load.rating = "230v"
		elif load is Plc:
			load.rating = "1224rc"
		elif load is TimerRelay:
			load.rating = "48dc"
		var back: Load = DocumentSerializer.component_from_dict(JSON.parse_string(JSON.stringify(DocumentSerializer.component_to_dict(load)))) as Load
		assert_eq(back.rating, load.rating, load.designation)
	assert_eq((DocumentSerializer.component_from_dict({"type": "coil", "designation": "KA9"}) as Load).rating, "", "older files: works on any voltage")
	assert_eq((DocumentSerializer.component_from_dict({"type": "coil", "designation": "KA9", "rating": "999x"}) as Load).rating, "", "unknown ratings are left out")
	assert_false(DocumentSerializer.component_to_dict(Coil.new("KA2")).has("rating"))


func test_rectifier_output_is_its_own_source() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(4, 0))
	doc.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS), Vector2i(8, 0))
	doc.add(Rectifier.new("TB1"), Vector2i(0, 4))
	var ka1: Coil = Coil.new("KA1")
	ka1.rating = "220dc"
	doc.add(ka1, Vector2i(0, 9))
	doc.connect_terminals("L", "TB1:~1")
	doc.connect_terminals("N", "TB1:~2")
	doc.connect_terminals("TB1:+", "KA1:A1")
	doc.connect_terminals("KA1:A2", "TB1:-")
	var s: Simulator = Simulator.new(doc.circuit)
	var r: StepResult = s.step()
	assert_true(ka1.energized, "207 V DC from the rectifier works a 220 V DC coil")
	assert_eq(r.terminal_reach["TB1:+"], StepResult.REACH_DC_PLUS)
	doc.connect_terminals("+", "TB1:+")
	assert_true(Simulator.new(doc.circuit).step().short_circuit, "a DC supply joined to the rectifier's output")
