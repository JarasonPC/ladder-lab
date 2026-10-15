extends GutTest
## Fuses, breakers, overload relays, faults, multi-block buttons, changeover
## contacts and custom terminal names.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC

var doc: SchematicDocument
var sim: Simulator


## L - F1 fuse - S1 (NO) - H1 - N, and a second lamp H2 straight from L.
## S2 (NO) from F1:2 to N makes a short through the fuse; S3 (NO) from L to N
## makes one that bypasses it.
func _fused_doc() -> void:
	doc = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 30))
	doc.add(Fuse.new("F1"), Vector2i(3, 1))
	doc.add(LatchingSwitch.new("S1", NO), Vector2i(3, 6))
	doc.add(Lamp.new("H1"), Vector2i(3, 11))
	doc.add(Lamp.new("H2"), Vector2i(8, 11))
	doc.add(LatchingSwitch.new("S2", NO), Vector2i(12, 6))
	doc.add(LatchingSwitch.new("S3", NO), Vector2i(16, 6))
	for pair: Array in [["L", "F1:1"], ["F1:2", "S1:13"], ["S1:14", "H1:X1"], ["H1:X2", "N"], ["L", "H2:X1"], ["H2:X2", "N"], ["F1:2", "S2:13"], ["S2:14", "N"], ["L", "S3:13"], ["S3:14", "N"]]:
		doc.connect_terminals(pair[0], pair[1])
	sim = Simulator.new(doc.circuit)


func _switch(id: String, on: bool) -> void:
	(doc.circuit.get_component(id) as LatchingSwitch).set_switched_on(on)


func _lamp(id: String) -> bool:
	return (doc.circuit.get_component(id) as Lamp).energized


func test_fuse_blows_on_short_through_it_and_stays_blown() -> void:
	_fused_doc()
	_switch("S1", true)
	sim.step()
	assert_true(_lamp("H1"))
	_switch("S2", true)
	var r: StepResult = sim.step()
	var fuse: Fuse = doc.circuit.get_component("F1") as Fuse
	assert_true(fuse.tripped, "F1 blown")
	assert_false(r.short_circuit, "the fuse cleared the short")
	assert_false(_lamp("H1"), "everything after F1 is dead")
	assert_true(_lamp("H2"), "the rest of the circuit still works")
	assert_does_not_have(r.live_terminals, "S1:13")
	var texts: PackedStringArray = PackedStringArray()
	for e: Dictionary in r.events:
		texts.append(e["text"] % e["args"])
	assert_has(texts, "F1 blown")
	_switch("S2", false)
	sim.step()
	assert_false(_lamp("H1"), "stays blown after the short is gone")
	fuse.reset()
	sim.step()
	assert_true(_lamp("H1"), "a new fuse restores the circuit")


func test_short_bypassing_the_fuse_is_unprotected() -> void:
	_fused_doc()
	_switch("S3", true)
	var r: StepResult = sim.step()
	assert_false((doc.circuit.get_component("F1") as Fuse).tripped, "F1 is not in the fault path")
	assert_true(r.short_circuit, "reported as an unprotected short")
	assert_false(_lamp("H2"), "supply drops out while it lasts")


func test_breaker_trips_resets_and_switches() -> void:
	_fused_doc()
	doc.replace_component("F1", CircuitBreaker.new("F1"))
	var breaker: CircuitBreaker = doc.circuit.get_component("F1") as CircuitBreaker
	_switch("S1", true)
	_switch("S2", true)
	sim.step()
	assert_true(breaker.tripped)
	_switch("S2", false)
	breaker.toggle()
	sim.step()
	assert_false(breaker.tripped, "switching on resets the trip")
	assert_true(_lamp("H1"))
	breaker.toggle()
	sim.step()
	assert_false(_lamp("H1"), "switched off by hand")


func test_overload_relay_trips_after_delay_and_resets() -> void:
	doc = ExampleCircuits.star_delta()
	sim = Simulator.new(doc.circuit)
	var relay: OverloadRelay = doc.circuit.get_overload_relay("F3")
	assert_not_null(relay)
	(doc.circuit.get_component("S2") as PushButton).press()
	sim.step(0.1)
	(doc.circuit.get_component("S2") as PushButton).release()
	sim.step(0.1)
	assert_true(doc.circuit.get_coil("KM1").energized)
	relay.overloaded = true
	for i: int in 49:
		sim.step(0.1)
	assert_false(relay.tripped, "still within 5 s")
	assert_true(doc.circuit.get_coil("KM1").energized)
	sim.step(0.15)
	assert_true(relay.tripped, "trips after 5 s")
	assert_false(doc.circuit.get_coil("KM1").energized, "95-96 opened and stopped the motor")
	relay.overloaded = false
	relay.reset()
	sim.step(0.1)
	assert_false(doc.circuit.get_coil("KM1").energized, "reset does not restart: the self-hold is gone")


func test_contact_faults() -> void:
	doc = ExampleCircuits.self_holding()
	sim = Simulator.new(doc.circuit)
	var hold: Contact = doc.circuit.get_component("K1:13-14") as Contact
	hold.fault = SwitchingElement.Fault.WELDED
	sim.step()
	assert_true(doc.circuit.get_coil("K1").energized, "a welded hold contact starts K1 by itself")
	hold.fault = SwitchingElement.Fault.OPEN
	(doc.circuit.get_component("S1") as PushButton).press()
	sim.step()
	(doc.circuit.get_component("S1") as PushButton).release()
	sim.step()
	assert_false(doc.circuit.get_coil("K1").energized, "a burnt hold contact does not hold")
	hold.fault = SwitchingElement.Fault.NONE
	(doc.circuit.get_component("S1") as PushButton).press()
	sim.step()
	(doc.circuit.get_component("S1") as PushButton).release()
	sim.step()
	assert_true(doc.circuit.get_coil("K1").energized, "cleared fault: holds again")


func test_coil_faults() -> void:
	doc = ExampleCircuits.self_holding()
	sim = Simulator.new(doc.circuit)
	var k1: Coil = doc.circuit.get_coil("K1")
	k1.fault = Coil.Fault.OPEN
	(doc.circuit.get_component("S1") as PushButton).press()
	var r: StepResult = sim.step()
	assert_false(k1.energized, "open coil does not pull in")
	assert_has(r.live_terminals, "K1:A1", "although voltage reaches it")
	k1.fault = Coil.Fault.NONE
	sim.step()
	assert_true(k1.energized)
	k1.fault = Coil.Fault.STUCK
	(doc.circuit.get_component("S1") as PushButton).release()
	(doc.circuit.get_component("S0") as PushButton).press()
	sim.step()
	assert_true(k1.armature.no_closed, "a stuck armature does not release")
	assert_true(_lamp("H1"), "so H1 stays on")


func test_broken_wire() -> void:
	doc = ExampleCircuits.self_holding()
	sim = Simulator.new(doc.circuit)
	var lamp_wire: int = -1
	var wires: Array[PackedStringArray] = doc.circuit.get_wires()
	for i: int in wires.size():
		if wires[i][0] == "K1:24":
			lamp_wire = i
	doc.circuit.set_wire_broken(lamp_wire, true)
	(doc.circuit.get_component("S1") as PushButton).press()
	sim.step()
	assert_true(doc.circuit.get_coil("K1").energized)
	assert_false(_lamp("H1"), "the broken wire feeds no more")
	doc.circuit.set_wire_broken(lamp_wire, false)
	sim.step()
	assert_true(_lamp("H1"))


func test_multi_block_button_moves_all_blocks_nc_first() -> void:
	doc = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 20))
	var no_block: PushButton = doc.add(PushButton.new("S1", NO, 1), Vector2i(3, 2)) as PushButton
	var nc_block: PushButton = doc.add(PushButton.new("S1", NC, 2), Vector2i(7, 2)) as PushButton
	doc.add(Lamp.new("H1"), Vector2i(3, 8))
	doc.add(Lamp.new("H2"), Vector2i(7, 8))
	for pair: Array in [["L", "S1:13"], ["S1:14", "H1:X1"], ["H1:X2", "N"], ["L", "S1:21"], ["S1:22", "H2:X1"], ["H2:X2", "N"]]:
		doc.connect_terminals(pair[0], pair[1])
	assert_eq(no_block.actuator, nc_block.actuator, "one button")
	sim = Simulator.new(doc.circuit)
	sim.mode = Simulator.Mode.REALISTIC
	sim.step()
	assert_true(_lamp("H2"))
	nc_block.press()
	assert_true(no_block.pressed, "pressing one block presses the button")
	sim.step(PushButton.TRAVEL_TIME * 0.5)
	assert_false(_lamp("H2"), "NC block broken half way")
	assert_false(_lamp("H1"), "NO block not made yet")
	sim.step(PushButton.TRAVEL_TIME)
	assert_true(_lamp("H1"))


func test_changeover_contact() -> void:
	doc = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 20))
	var s1: LatchingSwitch = doc.add(LatchingSwitch.new("S1", NO), Vector2i(3, 2)) as LatchingSwitch
	doc.add(TimerRelay.new("KT1", TimerRelay.Mode.ON_DELAY, 1.0), Vector2i(3, 8))
	var changeover: ChangeoverContact = doc.add(ChangeoverContact.new("KT1", 1, true), Vector2i(8, 2)) as ChangeoverContact
	doc.add(Lamp.new("H1"), Vector2i(8, 8))
	doc.add(Lamp.new("H2"), Vector2i(12, 8))
	assert_eq(changeover.id, "KT1:15-16-18")
	assert_eq(doc.terminal_cell("KT1:15"), Vector2i(8, 5), "common below")
	assert_eq(doc.terminal_cell("KT1:18"), Vector2i(8, 2), "NO above")
	assert_eq(doc.terminal_cell("KT1:16"), Vector2i(9, 2), "NC one cell right")
	for pair: Array in [["L", "S1:13"], ["S1:14", "KT1:A1"], ["KT1:A2", "N"], ["L", "KT1:15"], ["KT1:18", "H1:X1"], ["H1:X2", "N"], ["KT1:16", "H2:X1"], ["H2:X2", "N"]]:
		doc.connect_terminals(pair[0], pair[1])
	sim = Simulator.new(doc.circuit)
	sim.step()
	assert_true(_lamp("H2"), "common-NC closed at rest")
	assert_false(_lamp("H1"))
	s1.set_switched_on(true)
	sim.step()
	sim.step(1.0)
	assert_false(_lamp("H2"))
	assert_true(_lamp("H1"), "common-NO after the delay")
	assert_eq(CircuitCheck.run(doc).size(), 0)


func test_custom_terminals_rename_and_swap_keep_wires() -> void:
	doc = ExampleCircuits.self_holding()
	var data: Dictionary = DocumentSerializer.component_to_dict(doc.circuit.get_component("K1"))
	data["terminals"] = ["A2", "A1"]
	assert_true(doc.replace_component("K1", DocumentSerializer.component_from_dict(data)))
	assert_eq(doc.circuit.get_component("K1").get_terminal_names(), PackedStringArray(["A2", "A1"]))
	assert_eq(doc.terminal_cell("K1:A2"), Vector2i(5, 17), "A2 now at the top")
	var wires: Array[PackedStringArray] = doc.circuit.get_wires()
	assert_true(wires.any(func(w: PackedStringArray) -> bool: return w[0] == "S1:14" and w[1] == "K1:A2"), "the top wire stays at the top")
	data = DocumentSerializer.component_to_dict(doc.circuit.get_component("S1:13-14"))
	data["terminals"] = ["5", "6"]
	assert_true(doc.replace_component("S1:13-14", DocumentSerializer.component_from_dict(data)))
	assert_not_null(doc.circuit.get_component("S1:5-6"))
	var sim2: Simulator = Simulator.new(doc.circuit)
	(doc.circuit.get_component("S1") as PushButton).press()
	sim2.step()
	assert_true(doc.circuit.get_coil("K1").energized, "renamed parts still work")
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_not_null(copy.circuit.get_component("S1:5-6"), "custom names are saved")


func test_invalid_custom_terminals_are_refused() -> void:
	for names: Array in [["1"], ["5", "5"], ["5", "a b"], ["5", "x:y"]]:
		assert_null(DocumentSerializer.component_from_dict({"type": "push_button", "designation": "S1", "contact": "NO", "terminals": names}), str(names))


func test_check_reports_overload_contact_without_relay() -> void:
	doc = SchematicDocument.new()
	doc.add(OverloadContact.new("F9", NC), Vector2i(0, 0))
	var texts: PackedStringArray = PackedStringArray()
	for issue: Dictionary in CircuitCheck.run(doc):
		texts.append(issue["text"] % issue["args"])
	assert_has(texts, "Overload contact F9:95-96 has no overload relay F9.")


func _reversing(realistic: bool) -> void:
	doc = ExampleCircuits.forward_reverse_buttons()
	sim = Simulator.new(doc.circuit)
	sim.mode = Simulator.Mode.REALISTIC if realistic else Simulator.Mode.IDEAL
	var fwd: PushButton = doc.circuit.get_component("S1") as PushButton
	var rev: PushButton = doc.circuit.get_component("S2") as PushButton
	var k1: Coil = doc.circuit.get_coil("K1")
	var k2: Coil = doc.circuit.get_coil("K2")
	var run: Callable = func(seconds: float) -> void:
		var t: float = 0.0
		while t < seconds:
			sim.step(0.0005)
			t += 0.0005
			if k1.armature.no_closed and k2.armature.no_closed:
				fail_test("K1 and K2 closed together")
				return
	sim.step()
	fwd.press()
	run.call(0.1)
	fwd.release()
	run.call(0.1)
	assert_true(k1.energized and not k2.energized, "forward")
	rev.press()
	run.call(0.1)
	rev.release()
	run.call(0.1)
	assert_true(k2.energized and not k1.energized, "reverse straight from forward, without STOP")
	assert_true((doc.circuit.get_component("H2") as Lamp).energized, "reverse lamp")
	assert_false((doc.circuit.get_component("H1") as Lamp).energized)


func test_button_interlock_reverses_without_stop_ideal() -> void:
	_reversing(false)


func test_button_interlock_reverses_without_stop_realistic() -> void:
	_reversing(true)
