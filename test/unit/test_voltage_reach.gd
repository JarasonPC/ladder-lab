extends GutTest
## Which terminals and wires are at L potential.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC

var doc: SchematicDocument
var sim: Simulator


func before_each() -> void:
	doc = ExampleCircuits.self_holding()
	sim = Simulator.new(doc.circuit)


func _wire(a: String, b: String) -> int:
	var wires: Array[PackedStringArray] = doc.circuit.get_wires()
	for i: int in wires.size():
		if wires[i][0] == a and wires[i][1] == b:
			return i
	return -1


func test_voltage_reaches_up_to_open_contacts_at_rest() -> void:
	var r: StepResult = sim.step()
	for key: String in ["L", "S0:11", "S0:12", "S1:13", "K1:13", "K1:23"]:
		assert_has(r.live_terminals, key)
	for key: String in ["S1:14", "K1:14", "K1:A1", "K1:A2", "K1:24", "H1:X1", "N"]:
		assert_does_not_have(r.live_terminals, key)
	assert_has(r.live_wires, _wire("S0:12", "S1:13"), "dead-end wire is live although no current flows")
	assert_does_not_have(r.live_wires, _wire("S1:14", "K1:A1"))
	assert_eq(r.current_wires, PackedInt32Array(), "no current at rest")


func test_loads_do_not_pass_voltage_on() -> void:
	(doc.circuit.get_component("S1") as PushButton).press()
	var r: StepResult = sim.step()
	assert_has(r.live_terminals, "K1:A1")
	assert_does_not_have(r.live_terminals, "K1:A2")
	assert_does_not_have(r.live_wires, _wire("K1:A2", "N"))
	assert_has(r.live_terminals, "H1:X1")
	assert_does_not_have(r.live_terminals, "H1:X2")


func test_stop_cuts_voltage_reach() -> void:
	(doc.circuit.get_component("S0") as PushButton).press()
	var r: StepResult = sim.step()
	assert_has(r.live_terminals, "S0:11")
	assert_does_not_have(r.live_terminals, "S0:12")
	assert_does_not_have(r.live_wires, _wire("S0:12", "S1:13"))
