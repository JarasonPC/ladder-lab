extends GutTest
## Analog signals: the temperature sensor's 0-10 V, analog inputs AI and
## outputs AQ of the PLC and its analog modules, analog blocks and ladder
## elements.

const NO := SwitchingElement.ContactType.NO

var circuit: Circuit
var sim: Simulator


func _dc() -> void:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS))
	circuit.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS))


func _sensor(designation: String) -> TemperatureSensor:
	var sensor: TemperatureSensor = circuit.add(TemperatureSensor.new(designation)) as TemperatureSensor
	circuit.connect_terminals("+", designation + ":L+")
	circuit.connect_terminals(designation + ":M", "-")
	return sensor


## AI1 -> threshold trigger (On 500, Off 400) -> Q1.
func _threshold_program() -> PlcProgram:
	var p: PlcProgram = PlcProgram.new()
	var ai: PlcBlock = p.add_block("analog_input", Vector2i(0, 0))
	var trigger: PlcBlock = p.add_block("analog_threshold", Vector2i(4, 0))
	var q1: PlcBlock = p.add_block("output", Vector2i(10, 0))
	trigger.inputs[0] = ai.id
	q1.inputs[0] = trigger.id
	return p


func test_sensor_output() -> void:
	var sensor: TemperatureSensor = TemperatureSensor.new("BT1")
	assert_eq(sensor.get_terminal_names(), PackedStringArray(["L+", "M", "U"]))
	assert_eq(sensor.rating, "24dc")
	assert_eq(sensor.output_volts(), 0.0, "nothing without its supply")
	sensor.temperature = 25.0
	assert_almost_eq(sensor.output_volts(true), 2.5, 0.001, "0-100 °C on 0-10 V")
	sensor.temperature = 150.0
	assert_almost_eq(sensor.output_volts(true), 10.0, 0.001, "held at 10 V")
	sensor.range_min = -50.0
	sensor.range_max = 150.0
	sensor.temperature = 50.0
	assert_almost_eq(sensor.output_volts(true), 5.0, 0.001)
	var copy: TemperatureSensor = DocumentSerializer.component_from_dict(JSON.parse_string(JSON.stringify(DocumentSerializer.component_to_dict(sensor)))) as TemperatureSensor
	assert_eq(copy.range_min, -50.0)
	assert_eq(copy.range_max, 150.0)
	assert_eq(copy.temperature, 50.0)
	assert_eq(copy.rating, "24dc")
	var bad: TemperatureSensor = DocumentSerializer.component_from_dict({"type": "temp_sensor", "designation": "BT2", "range_min": 80, "range_max": 10}) as TemperatureSensor
	assert_eq([bad.range_min, bad.range_max], [80.0, 81.0], "an empty range keeps its lower bound")


func test_operands() -> void:
	assert_true(PlcProgram.valid_operand("AI8", "AI"))
	assert_false(PlcProgram.valid_operand("AI41", "AI"))
	assert_false(PlcProgram.valid_operand("AI1", "IQM"), "not an input I")
	assert_false(PlcProgram.valid_operand("I1", "AI"))
	assert_true(PlcProgram.valid_operand("AQ2", "AQ"))
	assert_eq(PlcProgram.operand_index("AI3"), 2)
	assert_eq(PlcProgram.area_of("AQ1"), "AQ")
	assert_eq(PlcProgram.area_of("Q1"), "Q")
	assert_eq(PlcProgram.operands("AI").size(), 40)


func test_plc_reads_the_sensor_with_hysteresis() -> void:
	_dc()
	var plc: Plc = circuit.add(Plc.new("A1", _threshold_program())) as Plc
	plc.rating = "1224rc"
	circuit.connect_terminals("+", "A1:L1")
	circuit.connect_terminals("A1:N", "-")
	var sensor: TemperatureSensor = _sensor("BT1")
	circuit.connect_terminals("BT1:U", "A1:I7")
	sim = Simulator.new(circuit)
	sim.step()
	assert_eq(plc.analog_input_count(), 4, "I7, I8, I1, I2 of the 12/24 V version")
	assert_almost_eq(plc.analog_in[0], 2.0, 0.01, "20 °C: 2 V on AI1")
	assert_almost_eq(plc.runtime.analog_inputs[0], 200.0, 0.5)
	assert_false(plc.output_on(0))
	for step: Array in [[60.0, true], [45.0, true], [35.0, false], [55.0, true]]:
		sensor.temperature = step[0]
		sim.step()
		assert_eq(plc.output_on(0), step[1], "%.0f °C" % step[0])


func test_230_v_version_has_no_analog_inputs() -> void:
	var a1: Plc = Plc.new("A1")
	a1.rating = "230rc"
	assert_eq(a1.analog_input_count(), 0)
	a1.rating = "24rc"
	assert_eq(a1.analog_input_count(), 4)
	assert_eq(a1.analog_input_terminal(0), a1.input_terminal(6), "AI1 on I7")
	assert_eq(a1.analog_input_terminal(2), a1.input_terminal(0), "AI3 on I1")


func test_analog_modules() -> void:
	var modules: Array[Plc.Module] = [Plc.Module.DI4_DQ4, Plc.Module.AI2, Plc.Module.AQ2]
	var a1: Plc = Plc.new("A1", null, modules)
	var names: PackedStringArray = a1.get_terminal_names()
	assert_eq(names.slice(a1.module_terminal(1), a1.module_terminal(2)), PackedStringArray(["3L+", "3M", "3U1", "3U2"]))
	assert_eq(names.slice(a1.module_terminal(2), a1.port_terminal()), PackedStringArray(["4L+", "4M", "AQ1", "AQ2"]))
	assert_eq(a1.analog_input_count(), 2, "the 230 V version: AI1, AI2 on the module")
	assert_eq(names[a1.analog_input_terminal(0)], "3U1")
	a1.rating = "1224rc"
	assert_eq(a1.analog_input_count(), 6)
	assert_eq(names[a1.analog_input_terminal(4)], "3U1", "AI5 after the PLC's own four")
	assert_eq(a1.analog_output_count(), 2)
	assert_eq(a1.module_rating(1), Plc.ANALOG_MODULE_RATING)
	assert_eq(a1.module_rating(0), "1224rc", "a digital module as the PLC")
	var four: Array[Plc.Module] = [Plc.Module.AI2, Plc.Module.AI2, Plc.Module.AI2, Plc.Module.AI2]
	assert_true(Plc.modules_fit(four, "230rc"), "8 analog inputs")
	assert_false(Plc.modules_fit(four, "1224rc"), "4 of its own and 8 more")
	var cells: Array[Vector2i] = SymbolGeometry.plc_terminal_cells(a1)
	var seen: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		assert_false(seen.has(cell), "one terminal per cell: %s" % cell)
		seen[cell] = true
	assert_eq(cells[a1.analog_output_terminal(0)].y, SymbolGeometry.PLC_HEIGHT, "analog outputs below")
	assert_eq(cells[a1.analog_input_terminal(0)].y, 0, "analog inputs on top")


## A 230 V PLC with a 2 AI and a 2 AQ module: the sensor on AI1, AQ1 =
## 2 x AI1 read by a second PLC on its AI1 (I7).
func test_analog_module_inputs_and_outputs() -> void:
	_dc()
	circuit.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	circuit.add(PowerSupply.new("N", PowerSupply.Conductor.N))
	var p: PlcProgram = PlcProgram.new()
	var ai: PlcBlock = p.add_block("analog_input", Vector2i(0, 0))
	var amp: PlcBlock = p.add_block("analog_amplifier", Vector2i(4, 0))
	amp.gain = 2.0
	var aq: PlcBlock = p.add_block("analog_output", Vector2i(10, 0))
	amp.inputs[0] = ai.id
	aq.inputs[0] = amp.id
	var modules: Array[Plc.Module] = [Plc.Module.AI2, Plc.Module.AQ2]
	var a1: Plc = circuit.add(Plc.new("A1", p, modules)) as Plc
	a1.rating = "230rc"
	circuit.connect_terminals("L", "A1:L1")
	circuit.connect_terminals("A1:N", "N")
	for m: String in ["2", "3"]:
		circuit.connect_terminals("+", "A1:%sL+" % m)
		circuit.connect_terminals("A1:%sM" % m, "-")
	var sensor: TemperatureSensor = _sensor("BT1")
	sensor.temperature = 20.0
	circuit.connect_terminals("BT1:U", "A1:2U1")
	var a2: Plc = circuit.add(Plc.new("A2", PlcProgram.new())) as Plc
	a2.rating = "1224rc"
	circuit.connect_terminals("+", "A2:L1")
	circuit.connect_terminals("A2:N", "-")
	circuit.connect_terminals("A1:AQ1", "A2:I7")
	sim = Simulator.new(circuit)
	sim.step()
	assert_true(a1.module_on(0))
	assert_almost_eq(a1.runtime.analog_inputs[0], 200.0, 0.5)
	assert_almost_eq(a1.analog_output_volts(0), 4.0, 0.01, "2 x 200 = 400: 4 V")
	sim.step()
	assert_almost_eq(a2.analog_in[0], 4.0, 0.01, "read on the other PLC")
	sensor.temperature = 80.0
	sim.step()
	sim.step()
	assert_almost_eq(a1.analog_output_volts(0), 10.0, 0.01, "held at 10 V")


func test_analog_compare_and_amplifier_blocks() -> void:
	var p: PlcProgram = PlcProgram.new()
	var x: PlcBlock = p.add_block("analog_input", Vector2i(0, 0))
	var y: PlcBlock = p.add_block("analog_input", Vector2i(0, 4))
	y.operand = "AI2"
	var cmp: PlcBlock = p.add_block("analog_compare", Vector2i(4, 0))
	cmp.on = 100.0
	cmp.off = 50.0
	cmp.inputs[0] = x.id
	cmp.inputs[1] = y.id
	var q1: PlcBlock = p.add_block("output", Vector2i(10, 0))
	q1.inputs[0] = cmp.id
	var runtime: PlcRuntime = PlcRuntime.new(p)
	runtime.analog_inputs[0] = 500.0
	runtime.analog_inputs[1] = 450.0
	runtime.scan_until_stable()
	assert_eq(runtime.outputs[0], 0, "a difference of 50")
	runtime.analog_inputs[0] = 600.0
	runtime.scan_until_stable()
	assert_eq(runtime.outputs[0], 1, "150 above 100")
	runtime.analog_inputs[0] = 520.0
	runtime.scan_until_stable()
	assert_eq(runtime.outputs[0], 1, "70: still on")
	runtime.analog_inputs[0] = 480.0
	runtime.scan_until_stable()
	assert_eq(runtime.outputs[0], 0, "30: off")
	var data: Dictionary = JSON.parse_string(JSON.stringify(p.to_data()))
	var copy: PlcProgram = PlcProgram.from_data(data)
	assert_eq(copy.block(cmp.id).on, 100.0)
	assert_eq(copy.block(cmp.id).off, 50.0)
	assert_eq(copy.block(y.id).operand, "AI2")


func test_ladder_compare_contacts_and_analog_coil() -> void:
	var p: PlcProgram = PlcProgram.new()
	p.language = PlcProgram.Language.LAD
	var rung: PlcRung = p.ladder()
	rung.set_cell(0, 0, {"kind": "ge", "operand": "AI1", "value": 300.0})
	rung.set_coil(0, {"kind": "coil", "operand": "Q1"})
	rung.wire_to_coil(0)
	rung.add_row()
	rung.set_cell(1, 0, {"kind": "lt", "operand": "AI1", "value": 300.0})
	rung.set_coil(1, {"kind": "analog", "operand": "AQ1", "value": 750.0})
	rung.wire_to_coil(1)
	var copy: PlcProgram = PlcProgram.from_data(JSON.parse_string(JSON.stringify(p.to_data())))
	assert_eq(copy.ladder().get_cell(0, 0), {"kind": "ge", "operand": "AI1", "value": 300.0})
	assert_eq(copy.ladder().get_coil(1)["value"], 750.0)
	var runtime: PlcRuntime = PlcRuntime.new(copy)
	runtime.analog_inputs[0] = 299.0
	runtime.scan_until_stable()
	assert_eq(runtime.outputs[0], 0)
	assert_eq(runtime.analog_outputs[0], 750.0, "below 300: AQ1 = 750")
	runtime.analog_inputs[0] = 300.0
	runtime.scan_until_stable()
	assert_eq(runtime.outputs[0], 1, "at 300")
	assert_eq(runtime.analog_outputs[0], 0.0, "the AQ coil without power")


func test_temperature_set_while_simulating() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS), Vector2i(0, 0))
	doc.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS), Vector2i(0, 8))
	doc.add(TemperatureSensor.new("BT1"), Vector2i(0, 3))
	doc.connect_terminals("+", "BT1:L+")
	doc.connect_terminals("BT1:M", "-")
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(doc, true)
	var sensor: TemperatureSensor = view.document.circuit.get_component("BT1") as TemperatureSensor
	assert_true(sensor.energized)
	view.set_temperature("BT1", 75.0)
	assert_eq(sensor.temperature, 75.0)
	assert_almost_eq(sensor.output_volts(), 7.5, 0.001)
