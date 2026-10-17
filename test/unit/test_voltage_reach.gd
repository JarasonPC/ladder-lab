extends GutTest
## Which terminals and wires are at L potential.

const ExamplePower = preload("res://test/unit/example_power.gd")

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC

var doc: SchematicDocument
var sim: Simulator


func before_each() -> void:
	doc = ExamplePower.on(ExampleCircuits.self_holding())
	sim = Simulator.new(doc.circuit)


func _wire(a: String, b: String) -> int:
	var wires: Array[PackedStringArray] = doc.circuit.get_wires()
	for i: int in wires.size():
		if wires[i][0] == a and wires[i][1] == b:
			return i
	return -1


func test_voltage_reaches_up_to_open_contacts_at_rest() -> void:
	var r: StepResult = sim.step()
	for key: String in ["L1.2", "SB0:11", "SB0:12", "SB1:13", "KM1:13", "KM1:23"]:
		assert_has(r.live_terminals, key)
	for key: String in ["SB1:14", "KM1:14", "KM1:A1", "KM1:A2", "KM1:24", "H1:X1", "N"]:
		assert_does_not_have(r.live_terminals, key)
	assert_has(r.live_wires, _wire("SB0:12", "SB1:13"), "dead-end wire is live although no current flows")
	assert_does_not_have(r.live_wires, _wire("SB1:14", "KM1:A1"))
	assert_eq(r.current_wires, PackedInt32Array(), "no current at rest")


func test_loads_do_not_pass_voltage_on() -> void:
	(doc.circuit.get_component("SB1") as PushButton).press()
	var r: StepResult = sim.step()
	assert_has(r.live_terminals, "KM1:A1")
	assert_does_not_have(r.live_terminals, "KM1:A2")
	assert_does_not_have(r.live_wires, _wire("KM1:A2", "N"))
	assert_has(r.live_terminals, "H1:X1")
	assert_does_not_have(r.live_terminals, "H1:X2")


func test_stop_cuts_voltage_reach() -> void:
	(doc.circuit.get_component("SB0") as PushButton).press()
	var r: StepResult = sim.step()
	assert_has(r.live_terminals, "SB0:11")
	assert_does_not_have(r.live_terminals, "SB0:12")
	assert_does_not_have(r.live_wires, _wire("SB0:12", "SB1:13"))


func test_n_reach_up_to_loads_and_open_contacts() -> void:
	var r: StepResult = sim.step()
	for key: String in ["N", "KM1:A2", "H1:X2"]:
		assert_has(r.neutral_terminals, key)
	for key: String in ["KM1:A1", "SB1:14", "L", "SB0:11"]:
		assert_does_not_have(r.neutral_terminals, key)
	assert_has(r.neutral_wires, _wire("KM1:A2", "N"))
	assert_does_not_have(r.neutral_wires, _wire("SB1:14", "KM1:A1"))


func test_n_reach_through_closed_contact() -> void:
	# An NC contact on the N side passes N on until it opens.
	var d: SchematicDocument = SchematicDocument.new()
	d.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 0))
	var s1: PushButton = d.add(PushButton.new("SB1", NC), Vector2i(3, 0)) as PushButton
	d.connect_terminals("N", "SB1:12")
	var s: Simulator = Simulator.new(d.circuit)
	assert_has(s.step().neutral_terminals, "SB1:11")
	s1.press()
	assert_does_not_have(s.step().neutral_terminals, "SB1:11")


func test_short_counts_as_l() -> void:
	var d: SchematicDocument = ExamplePower.on(ExampleCircuits.short_circuit())
	var s: Simulator = Simulator.new(d.circuit)
	(d.circuit.get_component("SB1") as PushButton).press()
	(d.circuit.get_component("SB2") as PushButton).press()
	var r: StepResult = s.step()
	assert_has(r.live_terminals, "N")
	assert_eq(r.neutral_terminals, PackedStringArray())
