extends GutTest
## Full bridge rectifier: DC on its outputs while its input has voltage.

const NO := SwitchingElement.ContactType.NO


## L - FU1 - TB1 ~1, TB1 ~2 - N; RB1 switches TB1's DC onto coil KA1, RB2
## joins + and - (a short on the DC side). Without [param fused] TB1 is fed
## straight from L.
func _circuit(fused: bool = true) -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(4, 0))
	if fused:
		var fuse: Fuse = Fuse.new("FU1")
		fuse.holder = true
		fuse.switched_on = true
		doc.add(fuse, Vector2i(0, 2))
	doc.add(Rectifier.new("TB1"), Vector2i(0, 7))
	doc.add(LatchingSwitch.new("RB1", NO), Vector2i(0, 12))
	doc.add(Coil.new("KA1"), Vector2i(0, 17))
	doc.add(LatchingSwitch.new("RB2", NO, 2), Vector2i(6, 12))
	if fused:
		doc.connect_terminals("L", "FU1:1")
		doc.connect_terminals("FU1:2", "TB1:~1")
	else:
		doc.connect_terminals("L", "TB1:~1")
	doc.connect_terminals("N", "TB1:~2")
	doc.connect_terminals("TB1:+", "RB1:13")
	doc.connect_terminals("RB1:14", "KA1:A1")
	doc.connect_terminals("KA1:A2", "TB1:-")
	doc.connect_terminals("TB1:+", "RB2:23")
	doc.connect_terminals("RB2:24", "TB1:-")
	return doc


func _wire(doc: SchematicDocument, a: String, b: String) -> int:
	var wires: Array[PackedStringArray] = doc.circuit.get_wires()
	for i: int in wires.size():
		if wires[i][0] == a and wires[i][1] == b:
			return i
	return -1


func _toggle(doc: SchematicDocument, designation: String) -> void:
	(doc.circuit.get_component(designation) as LatchingSwitch).toggle()


func test_terminals_and_geometry() -> void:
	var tb: Rectifier = Rectifier.new("TB1")
	assert_eq(tb.get_terminal_keys(), PackedStringArray(["TB1:~1", "TB1:~2", "TB1:+", "TB1:-"]))
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(tb)
	assert_eq(cells["~1"], Vector2i(0, 0))
	assert_eq(cells["~2"], Vector2i(2, 0))
	assert_eq(cells["+"], Vector2i(0, 3))
	assert_eq(cells["-"], Vector2i(2, 3))
	var copy: CircuitComponent = DocumentSerializer.component_from_dict(DocumentSerializer.component_to_dict(tb))
	assert_true(copy is Rectifier)
	assert_eq(copy.designation, "TB1")


func test_rectifier_feeds_a_dc_coil() -> void:
	var doc: SchematicDocument = _circuit()
	var sim: Simulator = Simulator.new(doc.circuit)
	var r: StepResult = sim.step()
	var tb: Rectifier = doc.circuit.get_component("TB1") as Rectifier
	assert_true(tb.energized, "the input has voltage")
	assert_eq(r.terminal_reach["TB1:+"], StepResult.REACH_DC_PLUS)
	assert_eq(r.terminal_reach["TB1:-"], StepResult.REACH_DC_MINUS)
	assert_eq(r.terminal_reach["RB1:13"], StepResult.REACH_DC_PLUS)
	assert_false(doc.circuit.get_coil("KA1").energized)
	assert_does_not_have(r.current_components, "TB1", "feeding nothing, it draws nothing")
	assert_does_not_have(r.current_wires, _wire(doc, "L", "FU1:1"))
	_toggle(doc, "RB1")
	r = sim.step()
	assert_true(doc.circuit.get_coil("KA1").energized, "DC from the rectifier")
	assert_has(r.current_components, "KA1")
	assert_has(r.current_components, "TB1")
	assert_has(r.current_wires, _wire(doc, "RB1:14", "KA1:A1"), "DC current")
	assert_has(r.current_wires, _wire(doc, "L", "FU1:1"), "AC current into the rectifier")
	assert_has(r.current_wires, _wire(doc, "N", "TB1:~2"))


func test_no_input_no_output() -> void:
	var doc: SchematicDocument = _circuit()
	_toggle(doc, "RB1")
	(doc.circuit.get_component("FU1") as Fuse).toggle()
	var r: StepResult = Simulator.new(doc.circuit).step()
	assert_false((doc.circuit.get_component("TB1") as Rectifier).energized)
	assert_false(r.terminal_reach.has("TB1:+"))
	assert_false(doc.circuit.get_coil("KA1").energized)


func test_short_on_the_dc_side_blows_the_fuse_in_front() -> void:
	var doc: SchematicDocument = _circuit()
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.step()
	_toggle(doc, "RB2")
	var r: StepResult = sim.step()
	assert_true((doc.circuit.get_component("FU1") as Fuse).tripped, "the fault current flows through FU1")
	assert_false(r.short_circuit, "and is interrupted")
	assert_false((doc.circuit.get_component("TB1") as Rectifier).energized)


func test_unprotected_dc_short_is_reported() -> void:
	var doc: SchematicDocument = _circuit(false)
	_toggle(doc, "RB2")
	var r: StepResult = Simulator.new(doc.circuit).step()
	assert_true(r.short_circuit)
	assert_eq(r.short_circuit_path, PackedStringArray(["TB1:+", "RB2:23-24", "TB1:-"]))
	assert_has(r.current_wires, _wire(doc, "N", "TB1:~2"), "fault current on the AC side too")


func test_dc_input_of_either_polarity() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS), Vector2i(0, 0))
	doc.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS), Vector2i(2, 0))
	doc.add(Rectifier.new("TB1"), Vector2i(0, 4))
	doc.connect_terminals("-", "TB1:~1")
	doc.connect_terminals("+", "TB1:~2")
	var r: StepResult = Simulator.new(doc.circuit).step()
	assert_true((doc.circuit.get_component("TB1") as Rectifier).energized)
	assert_eq(r.terminal_reach["TB1:+"], StepResult.REACH_DC_PLUS)
