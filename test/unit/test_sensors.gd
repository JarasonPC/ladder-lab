extends GutTest
## Proximity sensors (PNP / NPN, NO / NC / antivalent) on PLC inputs and
## relays, and transmitters (pressure, level, flow) on analog inputs:
## terminals as on the real ones, simulation, files, mechanical links.

const NC := SwitchingElement.ContactType.NC

var circuit: Circuit
var sim: Simulator


## + - supplies, compact CPU A1 on them with its inputs' common 1M on
## [param common] ("-" for PNP sensors, "+" for NPN ones), sensor BG1 on
## + - (its 3 on - only with [param sensor_m]) with its output 4 on %I0.0 (and 2 on %I0.1 when antivalent).
func _build(sensor: ProximitySensor, common: String = "-", sensor_m: bool = true) -> CompactPlc:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS))
	circuit.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS))
	var a1: CompactPlc = circuit.add(CompactPlc.new("A1", null, [], CompactPlc.Cpu.DI8_DQ6)) as CompactPlc
	circuit.add(sensor)
	circuit.connect_terminals("+", "A1:L+")
	circuit.connect_terminals("A1:M", "-")
	circuit.connect_terminals("A1:1M", common)
	circuit.connect_terminals("+", "BG1:1")
	if sensor_m:
		circuit.connect_terminals("BG1:3", "-")
	circuit.connect_terminals("BG1:4", "A1:I0.0")
	if sensor.function == ProximitySensor.Function.ANTIVALENT:
		circuit.connect_terminals("BG1:2", "A1:I0.1")
	sim = Simulator.new(circuit)
	sim.step()
	return a1


func test_terminals_as_marked_on_real_sensors() -> void:
	var three: ProximitySensor = ProximitySensor.new("BG1")
	assert_eq(three.get_terminal_names(), PackedStringArray(["1", "3", "4"]), "1 BN L+, 3 BU M, 4 BK output")
	assert_eq([three.core_colour(0), three.core_colour(1), three.core_colour(2)], ["BN", "BU", "BK"])
	assert_eq(three.rating, "1030dc")
	assert_eq(VoltageRating.text(three.rating), "10-30 V DC")
	var four: ProximitySensor = ProximitySensor.new("BG2", ProximitySensor.Function.ANTIVALENT)
	assert_eq(four.get_terminal_names(), PackedStringArray(["1", "3", "4", "2"]), "4-wire: 2 WH the second output")
	assert_eq(four.core_colour(3), "WH")
	assert_eq(four.switch_paths(), [Vector2i(0, 2), Vector2i(0, 3)] as Array[Vector2i], "PNP: L+ to the outputs")
	four.output = ProximitySensor.Output.NPN
	assert_eq(four.switch_paths(), [Vector2i(1, 2), Vector2i(1, 3)] as Array[Vector2i], "NPN: M to the outputs")
	var transmitter: Transmitter = Transmitter.new("BP1")
	assert_eq(transmitter.get_terminal_names(), PackedStringArray(["1", "3", "2"]), "1 BN L+, 3 BU M, 2 WH output")
	assert_eq(transmitter.rating, "1530dc")
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(four)
	assert_eq([cells["1"], cells["3"], cells["4"], cells["2"]], [Vector2i(0, 0), Vector2i(0, 3), Vector2i(2, 0), Vector2i(4, 0)])


func test_pnp_sensor_on_a_plc_input() -> void:
	var sensor: ProximitySensor = ProximitySensor.new("BG1")
	var a1: CompactPlc = _build(sensor)
	assert_true(sensor.energized, "24 V DC on 1-3")
	assert_false(a1.input_on(0), "nothing in front of it")
	sensor.detecting = true
	sim.step()
	assert_true(sensor.output_on(0))
	assert_true(a1.input_on(0), "+24 V on %I0.0 against 1M on 0 V")
	sensor.detecting = false
	sim.step()
	assert_false(a1.input_on(0))


func test_npn_sensor_needs_the_common_on_plus() -> void:
	var sensor: ProximitySensor = ProximitySensor.new("BG1")
	sensor.output = ProximitySensor.Output.NPN
	var a1: CompactPlc = _build(sensor, "+")
	sensor.detecting = true
	sim.step()
	assert_true(a1.input_on(0), "0 V on %I0.0 against 1M on +24 V (sinking)")
	sensor.detecting = false
	sim.step()
	assert_false(a1.input_on(0))
	var wrong: ProximitySensor = ProximitySensor.new("BG1")
	wrong.output = ProximitySensor.Output.NPN
	var b1: CompactPlc = _build(wrong, "-")
	wrong.detecting = true
	sim.step()
	assert_false(b1.input_on(0), "an NPN output and 1M both on 0 V: no voltage")


func test_nc_and_antivalent_outputs() -> void:
	var nc: ProximitySensor = ProximitySensor.new("BG1", ProximitySensor.Function.NC)
	var a1: CompactPlc = _build(nc)
	assert_true(a1.input_on(0), "NC: on while nothing is in front of it")
	nc.detecting = true
	sim.step()
	assert_false(a1.input_on(0))
	var both: ProximitySensor = ProximitySensor.new("BG1", ProximitySensor.Function.ANTIVALENT)
	var b1: CompactPlc = _build(both)
	assert_eq([b1.input_on(0), b1.input_on(1)], [false, true], "4 off, 2 on")
	both.detecting = true
	sim.step()
	assert_eq([b1.input_on(0), b1.input_on(1)], [true, false], "4 on, 2 off")


func test_no_output_without_its_supply() -> void:
	var sensor: ProximitySensor = ProximitySensor.new("BG1", ProximitySensor.Function.NC)
	_build(sensor, "-", false)
	assert_false(sensor.energized, "its 0 V is missing")
	assert_false(sensor.output_on(0), "an NC output stays off without the supply")
	assert_false((circuit.get_component("A1") as CompactPlc).input_on(0))


func test_relay_on_the_output_in_realistic_timing() -> void:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS))
	circuit.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS))
	var sensor: ProximitySensor = circuit.add(ProximitySensor.new("BG1")) as ProximitySensor
	var coil: Coil = circuit.add(Coil.new("KA1")) as Coil
	coil.rating = "24dc"
	circuit.connect_terminals("+", "BG1:1")
	circuit.connect_terminals("BG1:3", "-")
	circuit.connect_terminals("BG1:4", "KA1:A1")
	circuit.connect_terminals("KA1:A2", "-")
	sim = Simulator.new(circuit)
	sim.mode = Simulator.Mode.REALISTIC
	sim.step(0.1)
	assert_true(sensor.energized)
	assert_false(coil.energized)
	sensor.detecting = true
	sim.step(0.0002)
	assert_false(sensor.output_on(0), "the output takes its switching time")
	sim.step(0.1)
	assert_true(sensor.output_on(0))
	assert_true(coil.energized, "the relay on the output gets 24 V")
	assert_true(sim.last_result.stable)


func test_saved_and_loaded() -> void:
	var sensor: ProximitySensor = ProximitySensor.new("BG3", ProximitySensor.Function.ANTIVALENT)
	sensor.sensing = ProximitySensor.Sensing.OPTICAL
	sensor.output = ProximitySensor.Output.NPN
	var copy: ProximitySensor = DocumentSerializer.component_from_dict(JSON.parse_string(JSON.stringify(DocumentSerializer.component_to_dict(sensor)))) as ProximitySensor
	assert_eq([copy.designation, copy.sensing, copy.output, copy.function], ["BG3", ProximitySensor.Sensing.OPTICAL, ProximitySensor.Output.NPN, ProximitySensor.Function.ANTIVALENT])
	assert_eq(copy.output_armatures.size(), 2)
	assert_eq(copy.rating, "1030dc")
	var odd: ProximitySensor = DocumentSerializer.component_from_dict({"type": "proximity", "designation": "BG4", "sensing": "x", "output": 5, "function": "?"}) as ProximitySensor
	assert_eq([odd.sensing, odd.output, odd.function], [ProximitySensor.Sensing.INDUCTIVE, ProximitySensor.Output.PNP, ProximitySensor.Function.NO], "unknown values load as defaults")
	var transmitter: Transmitter = Transmitter.new("BL1", Transmitter.Quantity.LEVEL)
	transmitter.range_max = 3.0
	transmitter.value = 1.5
	var loaded: Transmitter = DocumentSerializer.component_from_dict(JSON.parse_string(JSON.stringify(DocumentSerializer.component_to_dict(transmitter)))) as Transmitter
	assert_eq([loaded.quantity, loaded.range_min, loaded.range_max, loaded.value], [Transmitter.Quantity.LEVEL, 0.0, 3.0, 1.5])
	var empty: Transmitter = DocumentSerializer.component_from_dict({"type": "transmitter", "designation": "BP2", "range_min": 4, "range_max": 4}) as Transmitter
	assert_almost_eq(empty.range_max, 4.1, 0.0001, "an empty range keeps its lower bound")


func test_transmitter_on_an_analog_input() -> void:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS))
	circuit.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS))
	var a1: CompactPlc = circuit.add(CompactPlc.new("A1", null, [], CompactPlc.Cpu.DI8_DQ6)) as CompactPlc
	var bp: Transmitter = circuit.add(Transmitter.new("BP1")) as Transmitter
	circuit.connect_terminals("+", "A1:L+")
	circuit.connect_terminals("A1:M", "-")
	circuit.connect_terminals("A1:2M", "-")
	circuit.connect_terminals("+", "BP1:1")
	circuit.connect_terminals("BP1:3", "-")
	circuit.connect_terminals("BP1:2", "A1:AI0")
	sim = Simulator.new(circuit)
	sim.step()
	assert_true(bp.energized)
	assert_almost_eq(a1.analog_in[0], 2.0, 0.01, "2 bar of 0-10 bar: 2 V")
	bp.set_measured(7.5)
	sim.step()
	assert_almost_eq(a1.analog_in[0], 7.5, 0.01)
	assert_almost_eq(a1.runtime.analog_inputs[0], 20736.0, 1.0, "7.5 V of 27648 at 10 V")
	bp.set_measured(50.0)
	sim.step()
	assert_almost_eq(a1.analog_in[0], 10.0, 0.01, "held at 10 V")


func test_transmitter_set_while_simulating() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS), Vector2i(0, 0))
	doc.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS), Vector2i(0, 8))
	doc.add(Transmitter.new("BF1", Transmitter.Quantity.FLOW), Vector2i(0, 3))
	doc.add(ProximitySensor.new("BG1"), Vector2i(8, 3))
	doc.connect_terminals("+", "BF1:1")
	doc.connect_terminals("BF1:3", "-")
	doc.connect_terminals("+", "BG1:1")
	doc.connect_terminals("BG1:3", "-")
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(doc, true)
	var flow: Transmitter = view.document.circuit.get_component("BF1") as Transmitter
	view.set_measured("BF1", 10.0)
	assert_almost_eq(flow.output_volts(), 5.0, 0.001, "10 of 0-20 m³/h")
	var sensor: ProximitySensor = view.document.circuit.get_component("BG1") as ProximitySensor
	view.set_detecting("BG1", true)
	assert_true(sensor.detecting)
	# Documents simulate in realistic timing: the output takes its switching time.
	view.simulator.step(0.01)
	assert_true(sensor.output_on(0))


func test_moving_part_works_a_proximity_sensor() -> void:
	# M1 runs through the NC contact of KA1; BG2 at the far end pulls KA1 in.
	var doc: SchematicDocument = SchematicDocument.new("gate")
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 20))
	doc.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS), Vector2i(10, 0))
	doc.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS), Vector2i(10, 20))
	doc.add(Contact.new("KA1", NC), Vector2i(0, 6))
	doc.add(Motor.new("M1"), Vector2i(0, 12))
	doc.add(ProximitySensor.new("BG2"), Vector2i(10, 6))
	var coil: Coil = Coil.new("KA1")
	coil.rating = "24dc"
	doc.add(coil, Vector2i(16, 12))
	doc.connect_terminals("L", "KA1:11")
	doc.connect_terminals("KA1:12", "M1:U1")
	doc.connect_terminals("M1:U2", "N")
	doc.connect_terminals("+", "BG2:1")
	doc.connect_terminals("BG2:3", "-")
	doc.connect_terminals("BG2:4", "KA1:A1")
	doc.connect_terminals("KA1:A2", "-")
	assert_eq(Workspace.field_kind(doc.circuit.get_component("BG2")), Workspace.Field.SENSOR)
	doc.add_group()
	for designation: String in ["M1", "BG2"]:
		doc.place_field_device(designation, Vector2(0, 0), 0)
	assert_true(doc.set_group_link(0, "M1", 1.0, 0.0, {"BG2": 1.0}))
	assert_eq(doc.groups[0].stops.keys(), ["BG2"], "a proximity sensor is a stop")
	sim = Simulator.new(doc.circuit)
	sim.travels = Workspace.travels(doc)
	sim.step()
	var sensor: ProximitySensor = doc.circuit.get_component("BG2") as ProximitySensor
	assert_false(sensor.detecting)
	assert_true((doc.circuit.get_component("M1") as Motor).energized)
	for i: int in 15:
		sim.step(0.1)
	assert_true(sensor.detecting, "the part reached the sensor")
	assert_true(doc.circuit.get_coil("KA1").energized)
	assert_false((doc.circuit.get_component("M1") as Motor).energized, "KA1 cut the motor off")
