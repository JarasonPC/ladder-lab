extends GutTest
## Compact CPU (24 V DC, transistor outputs): terminals and addresses, inputs
## against 1M, outputs switching 3L+, analog inputs 0-27648, signal modules.

const NO := SwitchingElement.ContactType.NO

var circuit: Circuit
var sim: Simulator


## Q1 = I1, AQ... nothing: output %Q0.0 follows input %I0.0.
func _follow_program() -> PlcProgram:
	var p: PlcProgram = PlcProgram.new()
	var i1: PlcBlock = p.add_block("input", Vector2i(0, 0))
	var q1: PlcBlock = p.add_block("output", Vector2i(4, 0))
	q1.inputs[0] = i1.id
	return p


## + - supplies; the CPU on them with 1M on -, 3L+ on + (unless
## [param no_output_supply]); S1 from + to I0.0, H1 (24 V) on Q0.0.
func _build(p_cpu: CompactPlc.Cpu = CompactPlc.Cpu.DI8_DQ6, no_output_supply: bool = false) -> CompactPlc:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS))
	circuit.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS))
	var a1: CompactPlc = circuit.add(CompactPlc.new("A1", _follow_program(), [], p_cpu)) as CompactPlc
	circuit.add(PushButton.new("S1", NO))
	var h1: Lamp = circuit.add(Lamp.new("H1")) as Lamp
	h1.rating = "24v"
	circuit.connect_terminals("+", "A1:L+")
	circuit.connect_terminals("A1:M", "-")
	circuit.connect_terminals("A1:1M", "-")
	if not no_output_supply:
		circuit.connect_terminals("+", "A1:3L+")
	circuit.connect_terminals("A1:3M", "-")
	circuit.connect_terminals("+", "S1:13")
	circuit.connect_terminals("S1:14", "A1:I0.0")
	circuit.connect_terminals("A1:Q0.0", "H1:X1")
	circuit.connect_terminals("H1:X2", "-")
	sim = Simulator.new(circuit)
	sim.step()
	return a1


func test_cpu_sizes_and_addresses() -> void:
	var small: CompactPlc = CompactPlc.new("A1", null, [], CompactPlc.Cpu.DI6_DQ4)
	assert_eq(small.get_terminal_names(), PackedStringArray(["L+", "M", "1M", "I0.0", "I0.1", "I0.2", "I0.3", "I0.4", "I0.5", "2M", "AI0", "AI1", "3L+", "3M", "Q0.0", "Q0.1", "Q0.2", "Q0.3", "P1"]))
	assert_eq(small.input_count(), 6)
	assert_eq(small.output_count(), 4)
	assert_eq(small.analog_input_count(), 2)
	assert_eq(small.rating, CompactPlc.RATING)
	var large: CompactPlc = CompactPlc.new("A1", null, [], CompactPlc.Cpu.DI14_DQ10)
	assert_eq(large.input_count(), 14)
	assert_eq(large.output_count(), 10)
	assert_eq(large.address("I14"), "%I1.5")
	assert_eq(large.address("Q10"), "%Q1.1")
	assert_eq(large.address("I1"), "%I0.0")
	assert_eq(large.address("AI2"), "%IW66")
	assert_eq(large.address("M10"), "%M1.1")
	assert_eq(large.address("T3"), "T3")
	assert_eq(large.switch_paths()[0], Vector2i(large.get_terminal_names().find("3L+"), large.output_terminal(0)), "an output switches 3L+")
	assert_eq(large.input_reference(13), large.get_terminal_names().find("1M"))
	assert_true(large.terminal_on_bottom(large.get_terminal_names().find("3M")))
	assert_false(large.terminal_on_bottom(large.get_terminal_names().find("2M")))


func test_inputs_and_transistor_outputs() -> void:
	var a1: CompactPlc = _build()
	var h1: Lamp = circuit.get_component("H1") as Lamp
	assert_true(a1.energized, "24 V DC on L+ M")
	assert_false(h1.energized)
	(circuit.get_component("S1") as PushButton).press()
	sim.step()
	assert_true(a1.input_on(0), "%I0.0 with 24 V against 1M")
	assert_true(h1.energized, "%Q0.0 switches 3L+ to the lamp")


func test_outputs_need_their_supply() -> void:
	var a1: CompactPlc = _build(CompactPlc.Cpu.DI8_DQ6, true)
	(circuit.get_component("S1") as PushButton).press()
	sim.step()
	assert_true(a1.output_on(0))
	assert_false((circuit.get_component("H1") as Lamp).energized, "no 3L+, no voltage on the output")


func test_inputs_need_15_volts_and_burn_on_230() -> void:
	var a1: CompactPlc = _build()
	var twelve: PowerSupply = circuit.add(PowerSupply.new("+.2", PowerSupply.Conductor.DC_PLUS)) as PowerSupply
	twelve.voltage = 12.0
	circuit.connect_terminals("+.2", "A1:I0.1")
	sim = Simulator.new(circuit)
	sim.step()
	assert_false(a1.input_on(1), "12 V is too little")
	var other: CompactPlc = CompactPlc.new("A2", null)
	circuit.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	circuit.add(PowerSupply.new("N", PowerSupply.Conductor.N))
	circuit.add(other)
	circuit.connect_terminals("L", "A2:L+")
	circuit.connect_terminals("A2:M", "N")
	sim = Simulator.new(circuit)
	sim.step()
	assert_true(other.burnt, "230 V on a 24 V DC CPU")


func test_analog_inputs_in_27648() -> void:
	var a1: CompactPlc = _build()
	var bt1: TemperatureSensor = circuit.add(TemperatureSensor.new("BT1")) as TemperatureSensor
	bt1.temperature = 50.0
	circuit.connect_terminals("+", "BT1:L+")
	circuit.connect_terminals("BT1:M", "-")
	circuit.connect_terminals("BT1:U", "A1:AI0")
	circuit.connect_terminals("A1:2M", "-")
	sim = Simulator.new(circuit)
	sim.step()
	assert_almost_eq(a1.analog_in[0], 5.0, 0.01)
	assert_almost_eq(a1.runtime.analog_inputs[0], 13824.0, 1.0, "5 V: half of 27648")


func test_signal_modules() -> void:
	var two: Array[Plc.Module] = [Plc.Module.SM_DI8, Plc.Module.SM_DQ8]
	assert_false(CompactPlc.modules_fit_cpu(two, CompactPlc.Cpu.DI6_DQ4), "the smallest CPU takes none")
	assert_true(CompactPlc.modules_fit_cpu(two, CompactPlc.Cpu.DI8_DQ6))
	var three: Array[Plc.Module] = [Plc.Module.SM_DI8, Plc.Module.SM_DQ8, Plc.Module.SM_AI4]
	assert_false(CompactPlc.modules_fit_cpu(three, CompactPlc.Cpu.DI8_DQ6), "two at most")
	assert_true(CompactPlc.modules_fit_cpu(three, CompactPlc.Cpu.DI14_DQ10))
	var logic: Array[Plc.Module] = [Plc.Module.DI4_DQ4]
	assert_false(CompactPlc.modules_fit_cpu(logic, CompactPlc.Cpu.DI14_DQ10), "no logic module expansions")
	assert_false(Plc.modules_fit(two), "no signal modules on a logic module")
	var a1: CompactPlc = CompactPlc.new("A1", null, three, CompactPlc.Cpu.DI14_DQ10)
	var names: PackedStringArray = a1.get_terminal_names()
	assert_eq(names.slice(a1.module_terminal(0), a1.module_terminal(1)), PackedStringArray(["2.1M", "I8.0", "I8.1", "I8.2", "I8.3", "I8.4", "I8.5", "I8.6", "I8.7"]))
	assert_eq(names[a1.module_terminal(1)], "3.L+")
	assert_eq(names[a1.output_terminal(10)], "Q12.0", "the second slot: byte 12")
	assert_eq(a1.address("I15"), "%I8.0")
	assert_eq(a1.address("Q11"), "%Q12.0")
	assert_eq(a1.address("AI3"), "%IW128", "the third slot's analog values: word 96 + 2 x 16")
	assert_eq(a1.module_supply(0), -1, "an input module works with the CPU")
	assert_eq(names[a1.module_supply(2)], "4.L+", "an analog module needs 24 V")
	var cells: Array[Vector2i] = SymbolGeometry.plc_terminal_cells(a1)
	var seen: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		assert_false(seen.has(cell), "one terminal per cell: %s" % cell)
		seen[cell] = true


func test_signal_module_outputs() -> void:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS))
	circuit.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS))
	var p: PlcProgram = PlcProgram.new()
	var hi: PlcBlock = p.add_block("hi", Vector2i(0, 0))
	var q7: PlcBlock = p.add_block("output", Vector2i(4, 0))
	q7.operand = "Q7"
	q7.inputs[0] = hi.id
	var modules: Array[Plc.Module] = [Plc.Module.SM_DQ8]
	var a1: CompactPlc = circuit.add(CompactPlc.new("A1", p, modules)) as CompactPlc
	var h1: Lamp = circuit.add(Lamp.new("H1")) as Lamp
	circuit.connect_terminals("+", "A1:L+")
	circuit.connect_terminals("A1:M", "-")
	circuit.connect_terminals("+", "A1:2.L+")
	circuit.connect_terminals("A1:Q8.0", "H1:X1")
	circuit.connect_terminals("H1:X2", "-")
	sim = Simulator.new(circuit)
	sim.step()
	assert_eq(a1.address("Q7"), "%Q8.0")
	assert_true(a1.module_on(0))
	assert_true(h1.energized, "%Q8.0 on the signal module")


func test_saved_loaded_and_cpu_changed_keeps_wires() -> void:
	var modules: Array[Plc.Module] = [Plc.Module.SM_DI8]
	var a1: CompactPlc = CompactPlc.new("A1", _follow_program(), modules, CompactPlc.Cpu.DI8_DQ6)
	var d: Dictionary = DocumentSerializer.component_to_dict(a1)
	assert_eq(d["family"], "compact")
	assert_eq(d["cpu"], "8di6dq")
	var copy: CompactPlc = DocumentSerializer.component_from_dict(JSON.parse_string(JSON.stringify(d))) as CompactPlc
	assert_not_null(copy)
	assert_eq(copy.cpu, CompactPlc.Cpu.DI8_DQ6)
	assert_eq(copy.modules, modules)
	assert_eq(copy.rating, CompactPlc.RATING)
	var small: Dictionary = d.duplicate()
	small["cpu"] = "6di4dq"
	assert_true((DocumentSerializer.component_from_dict(small) as CompactPlc).modules.is_empty(), "the smallest CPU takes no modules")
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS), Vector2i(0, 0))
	doc.add(CompactPlc.new("A1", null), Vector2i(4, 4))
	var corner: Array[Vector2i] = [Vector2i(30, 0)]
	doc.connect_terminals("+", "A1:3L+", corner)
	var larger: Dictionary = DocumentSerializer.component_to_dict(doc.circuit.get_component("A1"))
	larger["cpu"] = "14di10dq"
	assert_true(doc.replace_component("A1", DocumentSerializer.component_from_dict(larger)))
	assert_eq(doc.circuit.get_wires()[0], PackedStringArray(["+", "A1:3L+"]), "the wire stays on 3L+, wherever it moved")
