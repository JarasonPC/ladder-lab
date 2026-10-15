extends GutTest
## Which wires and elements carry current.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC

var circuit: Circuit
var sim: Simulator


func _new_circuit() -> void:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	circuit.add(PowerSupply.new("N", PowerSupply.Conductor.N))


func _wire(a: String, b: String) -> int:
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in wires.size():
		if (wires[i][0] == a and wires[i][1] == b) or (wires[i][0] == b and wires[i][1] == a):
			return i
	fail_test("no wire %s - %s" % [a, b])
	return -1


func _assert_wires(r: StepResult, lit: Array[String], dark: Array[String]) -> void:
	for pair: String in lit:
		var ends: PackedStringArray = pair.split(" ")
		assert_has(r.current_wires, _wire(ends[0], ends[1]), "%s carries current" % pair)
	for pair: String in dark:
		var ends: PackedStringArray = pair.split(" ")
		assert_does_not_have(r.current_wires, _wire(ends[0], ends[1]), "%s carries no current" % pair)


func _build_self_holding() -> PushButton:
	_new_circuit()
	circuit.add(PushButton.new("S0", NC))
	var start: PushButton = circuit.add(PushButton.new("S1", NO)) as PushButton
	circuit.add(Contact.new("K1", NO, 1))
	circuit.add(Contact.new("K1", NO, 2))
	circuit.add(Coil.new("K1"))
	circuit.add(Lamp.new("H1"))
	circuit.connect_terminals("L", "S0:11")
	circuit.connect_terminals("S0:12", "S1:13")
	circuit.connect_terminals("S0:12", "K1:13")
	circuit.connect_terminals("S1:14", "K1:14")
	circuit.connect_terminals("S1:14", "K1:A1")
	circuit.connect_terminals("K1:A2", "N")
	circuit.connect_terminals("L", "K1:23")
	circuit.connect_terminals("K1:24", "H1:X1")
	circuit.connect_terminals("H1:X2", "N")
	sim = Simulator.new(circuit)
	return start


func test_no_current_at_rest() -> void:
	_build_self_holding()
	var r: StepResult = sim.step()
	assert_eq(r.current_wires, PackedInt32Array())
	assert_eq(r.current_components, PackedStringArray())


func test_parallel_paths_both_carry_current() -> void:
	var start: PushButton = _build_self_holding()
	start.press()
	var r: StepResult = sim.step()
	_assert_wires(r, ["L S0:11", "S0:12 S1:13", "S0:12 K1:13", "S1:14 K1:14", "S1:14 K1:A1", "K1:A2 N", "L K1:23", "K1:24 H1:X1", "H1:X2 N"], [])
	for id: String in ["S0", "S1", "K1:13-14", "K1", "K1:23-24", "H1"]:
		assert_has(r.current_components, id)


func test_open_branch_is_dark_after_release() -> void:
	var start: PushButton = _build_self_holding()
	start.press()
	sim.step()
	start.release()
	var r: StepResult = sim.step()
	_assert_wires(r, ["L S0:11", "S0:12 K1:13", "S1:14 K1:14", "S1:14 K1:A1", "K1:A2 N"], ["S0:12 S1:13"])
	assert_does_not_have(r.current_components, "S1")
	assert_has(r.current_components, "K1:13-14")


func test_dead_end_and_dangling_loop_are_dark() -> void:
	_new_circuit()
	(circuit.add(LatchingSwitch.new("S1", NO)) as LatchingSwitch).set_switched_on(true)
	(circuit.add(LatchingSwitch.new("S2", NO)) as LatchingSwitch).set_switched_on(true)
	(circuit.add(LatchingSwitch.new("S3", NO)) as LatchingSwitch).set_switched_on(true)
	(circuit.add(LatchingSwitch.new("S4", NO)) as LatchingSwitch).set_switched_on(true)
	circuit.add(Lamp.new("H1"))
	circuit.connect_terminals("L", "S1:13")
	circuit.connect_terminals("S1:14", "H1:X1")
	circuit.connect_terminals("H1:X2", "N")
	# Dead end: closed S2 leads nowhere.
	circuit.connect_terminals("S1:14", "S2:13")
	# Loop hanging off S1:14 only.
	circuit.connect_terminals("S1:14", "S3:13")
	circuit.connect_terminals("S3:14", "S4:13")
	circuit.connect_terminals("S4:14", "S1:14")
	sim = Simulator.new(circuit)
	var r: StepResult = sim.step()
	assert_true((circuit.get_component("H1") as Lamp).energized)
	_assert_wires(r, ["L S1:13", "S1:14 H1:X1", "H1:X2 N"], ["S1:14 S2:13", "S1:14 S3:13", "S3:14 S4:13", "S4:14 S1:14"])
	assert_eq(r.current_components, PackedStringArray(["S1", "H1"]))


func test_short_circuit_shows_fault_current() -> void:
	_new_circuit()
	var s1: PushButton = circuit.add(PushButton.new("S1", NO)) as PushButton
	var s2: PushButton = circuit.add(PushButton.new("S2", NO)) as PushButton
	circuit.add(Lamp.new("H1"))
	circuit.connect_terminals("L", "S1:13")
	circuit.connect_terminals("S1:14", "S2:13")
	circuit.connect_terminals("S2:14", "N")
	circuit.connect_terminals("L", "H1:X1")
	circuit.connect_terminals("H1:X2", "N")
	sim = Simulator.new(circuit)
	s1.press()
	s2.press()
	var r: StepResult = sim.step()
	assert_true(r.short_circuit)
	_assert_wires(r, ["L S1:13", "S1:14 S2:13", "S2:14 N"], ["L H1:X1", "H1:X2 N"])
	assert_eq(r.current_components, PackedStringArray(["S1", "S2"]))
