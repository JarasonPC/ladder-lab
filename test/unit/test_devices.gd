extends GutTest
## Parts named alike work as one device whatever their type: contacts of a
## push button or switch, auxiliary contacts of a breaker; terminals of a
## coil swapped; PE supply points.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC


## L - [param first] - H1 - N and L - [param second] - H2 - N.
func _two_lamps(first: CircuitComponent, second: CircuitComponent) -> Circuit:
	var c: Circuit = Circuit.new()
	c.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	c.add(PowerSupply.new("N", PowerSupply.Conductor.N))
	c.add(first)
	c.add(second)
	c.add(Lamp.new("H1"))
	c.add(Lamp.new("H2"))
	var a: PackedStringArray = first.get_terminal_keys()
	var b: PackedStringArray = second.get_terminal_keys()
	c.connect_terminals("L", a[0])
	c.connect_terminals(a[1], "H1:X1")
	c.connect_terminals("H1:X2", "N")
	c.connect_terminals("L", b[0])
	c.connect_terminals(b[1], "H2:X1")
	c.connect_terminals("H2:X2", "N")
	return c


func _lit(c: Circuit, lamp: String) -> bool:
	return (c.get_component(lamp) as Lamp).energized


func test_a_plain_contact_named_like_a_button_is_one_of_its_blocks() -> void:
	var c: Circuit = _two_lamps(PushButton.new("SB1", NO), Contact.new("SB1", NO, 2))
	var sim: Simulator = Simulator.new(c)
	sim.step()
	assert_false(_lit(c, "H2"))
	(c.get_operator("SB1") as PushButton).press()
	sim.step()
	assert_true(_lit(c, "H1"))
	assert_true(_lit(c, "H2"), "the contact closes with the button")
	(c.get_operator("SB1") as PushButton).release()
	sim.step()
	assert_false(_lit(c, "H2"))
	assert_true((c.get_component("SB1:23-24") as Contact).has_device())


func test_contacts_follow_switches_and_limit_switches() -> void:
	var c: Circuit = _two_lamps(LimitSwitch.new("SQ1", NO), Contact.new("SQ1", NC, 2))
	var sim: Simulator = Simulator.new(c)
	sim.step()
	assert_true(_lit(c, "H2"), "NC closed at rest")
	(c.get_operator("SQ1") as LatchingSwitch).toggle()
	sim.step()
	assert_true(_lit(c, "H1"))
	assert_false(_lit(c, "H2"), "NC opened by the limit switch")


func test_a_button_and_a_switch_named_alike_share_one_actuator() -> void:
	var c: Circuit = _two_lamps(PushButton.new("SB1", NO), LatchingSwitch.new("SB1", NO, 2))
	var sim: Simulator = Simulator.new(c)
	(c.get_operator("SB1") as PushButton).press()
	sim.step()
	assert_true(_lit(c, "H1"))
	assert_true(_lit(c, "H2"))


func test_auxiliary_contact_of_a_breaker() -> void:
	var c: Circuit = _two_lamps(CircuitBreaker.new("FA1"), Contact.new("FA1", NO, 1))
	var sim: Simulator = Simulator.new(c)
	sim.step()
	assert_false(_lit(c, "H2"), "breaker off: NO open")
	(c.get_component("FA1") as CircuitBreaker).toggle()
	sim.step()
	assert_true(_lit(c, "H1"))
	assert_true(_lit(c, "H2"), "breaker on: NO closed")
	var changeover: ChangeoverContact = ChangeoverContact.new("FA1", 2)
	c.add(changeover)
	assert_true(changeover.is_path_closed(ChangeoverContact.PATH_NO))
	assert_false(changeover.is_path_closed(ChangeoverContact.PATH_NC))


func test_a_coil_still_wins_over_a_button() -> void:
	var c: Circuit = Circuit.new()
	c.add(PushButton.new("X5", NO))
	var contact: Contact = c.add(Contact.new("X5", NO, 2)) as Contact
	assert_not_null(contact.linked_actuator)
	c.add(Coil.new("X5"))
	assert_not_null(contact.linked_coil)
	assert_null(contact.linked_actuator)


func test_main_contacts_of_a_switch() -> void:
	var c: Circuit = Circuit.new()
	var switch: LatchingSwitch = c.add(LatchingSwitch.new("QS1", NO)) as LatchingSwitch
	var main: MainContacts = c.add(MainContacts.new("QS1")) as MainContacts
	var sim: Simulator = Simulator.new(c)
	sim.step()
	assert_false(main.is_path_closed(0))
	switch.toggle()
	sim.step()
	assert_true(main.is_path_closed(0))


func test_check_accepts_contacts_of_buttons() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PushButton.new("SB1", NO), Vector2i(2, 2))
	doc.add(Contact.new("SB1", NO, 2), Vector2i(6, 2))
	doc.add(Contact.new("KA9", NO, 1), Vector2i(10, 2))
	var texts: Array[String] = []
	for issue: Dictionary in CircuitCheck.run(doc):
		texts.append(issue["text"] % issue["args"])
	assert_does_not_have(texts, "Contact SB1:23-24 has no coil SB1.")
	assert_has(texts, "Contact KA9:13-14 has no coil KA9.")


func test_editor_lets_a_contact_take_a_buttons_name() -> void:
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	var editor: SchematicEditor = SchematicEditor.new()
	editor.view = view
	add_child_autofree(editor)
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PushButton.new("SB1", NO), Vector2i(2, 2))
	doc.add(Contact.new("KM1", NO, 2), Vector2i(6, 2))
	doc.add(Coil.new("KM1"), Vector2i(10, 2))
	doc.add(Lamp.new("H1"), Vector2i(14, 2))
	view.load_document(doc, false)
	editor.active = true
	var data: Dictionary = DocumentSerializer.component_to_dict(doc.circuit.get_component("KM1:23-24"))
	data["designation"] = "SB1"
	assert_eq(editor.apply_properties("KM1:23-24", data), "")
	var block: PushButton = doc.circuit.get_component("SB1:23-24") as PushButton
	assert_not_null(block, "renamed: one more block of the push button")
	assert_eq(block.actuator, (doc.circuit.get_operator("SB1") as PushButton).actuator)
	var lamp: Dictionary = DocumentSerializer.component_to_dict(doc.circuit.get_component("H1"))
	lamp["designation"] = "SB1"
	assert_ne(editor.apply_properties("H1", lamp), "", "a lamp is no part of a button")
	var coil: Dictionary = DocumentSerializer.component_to_dict(doc.circuit.get_component("KM1"))
	coil["designation"] = "SB1"
	assert_ne(editor.apply_properties("KM1", coil), "", "a coil and a button are two devices")
	# A new contact placed while the button is selected belongs to it.
	editor.selected_components = {"SB1:13-14": true}
	assert_eq(editor._new_designation({"type": "contact", "contact": "NO"}), "SB1")


func test_pe_has_the_potential_of_n() -> void:
	var c: Circuit = Circuit.new()
	c.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	c.add(PowerSupply.new("PE", PowerSupply.Conductor.PE))
	c.add(PowerSupply.new("N", PowerSupply.Conductor.N))
	c.add(Lamp.new("H1"))
	c.add(Lamp.new("H2"))
	c.connect_terminals("L", "H1:X1")
	c.connect_terminals("H1:X2", "N")
	c.connect_terminals("H2:X2", "PE")
	var r: StepResult = Simulator.new(c).step()
	assert_true((c.get_component("H1") as Lamp).energized)
	assert_false(r.short_circuit)
	assert_eq(r.terminal_reach.get("H2:X2", 0), StepResult.REACH_PE, "drawn in the PE colour")
	assert_true(StepResult.is_return(StepResult.REACH_PE))
	assert_eq((c.get_component("PE") as PowerSupply).conductor_name(), "PE")


func test_a_phase_touching_pe_blows_the_fuse() -> void:
	var c: Circuit = Circuit.new()
	c.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	c.add(PowerSupply.new("PE", PowerSupply.Conductor.PE))
	var fuse: Fuse = c.add(Fuse.new("FU1")) as Fuse
	c.connect_terminals("L", "FU1:1")
	c.connect_terminals("FU1:2", "PE")
	Simulator.new(c).step()
	assert_true(fuse.tripped, "an earth fault is a short to N")


func test_pe_supply_is_saved_and_named() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	assert_eq(doc.next_supply_designation(PowerSupply.Conductor.PE), "PE")
	doc.add(PowerSupply.new("PE", PowerSupply.Conductor.PE), Vector2i(2, 2))
	assert_eq(doc.next_supply_designation(PowerSupply.Conductor.PE), "PE.2")
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq((copy.circuit.get_component("PE") as PowerSupply).conductor, PowerSupply.Conductor.PE)
	var texts: Array[String] = []
	for issue: Dictionary in CircuitCheck.run(doc):
		texts.append(issue["text"])
	assert_has(texts, "The circuit has no N supply.", "PE is no N")


func test_time_relay_with_a1_and_a2_swapped() -> void:
	# S counts against A2, wherever A2 is.
	var timer: TimerRelay = TimerRelay.new("KT1", TimerRelay.Mode.ON_DELAY, 1.0)
	timer.control_input = true
	timer.custom_terminals = PackedStringArray(["A2", "A1", "S"])
	assert_eq(timer.a2_index(), 0)
	assert_eq(timer.id, "KT1")
	var c: Circuit = Circuit.new()
	c.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	c.add(PowerSupply.new("N", PowerSupply.Conductor.N))
	c.add(timer)
	c.connect_terminals("L", "KT1:A1")
	c.connect_terminals("N", "KT1:A2")
	c.connect_terminals("L", "KT1:S")
	Simulator.new(c).step()
	assert_true(timer.energized, "powered on A1-A2 with A2 on top")
	assert_true(timer.control, "S has voltage against A2")


func test_terminals_swap_when_renamed_to_each_other() -> void:
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	var editor: SchematicEditor = SchematicEditor.new()
	editor.view = view
	add_child_autofree(editor)
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Coil.new("KM1"), Vector2i(2, 2))
	var timer: TimerRelay = TimerRelay.new("KT1", TimerRelay.Mode.ON_DELAY, 1.0)
	timer.control_input = true
	doc.add(timer, Vector2i(6, 2))
	view.load_document(doc, false)
	editor.active = true
	editor._inline_target = {"component": "KM1", "kind": "terminal", "index": 0}
	editor._commit_inline("A2")
	assert_eq(doc.circuit.get_component("KM1").get_terminal_names(), PackedStringArray(["A2", "A1"]))
	editor._inline_target = {"component": "KT1", "kind": "terminal", "index": 1}
	editor._commit_inline("A1")
	assert_eq(doc.circuit.get_component("KT1").get_terminal_names(), PackedStringArray(["A2", "A1", "S"]), "a time relay's A1 and A2 swap too")
	editor._inline_target = {"component": "KT1", "kind": "terminal", "index": 0}
	editor._commit_inline("B9")
	assert_eq(doc.circuit.get_component("KT1").get_terminal_names(), PackedStringArray(["A2", "A1", "S"]), "but are not renamed")
	editor._inline_target = {"component": "KT1", "kind": "terminal", "index": 2}
	editor._commit_inline("TL")
	assert_eq(doc.circuit.get_component("KT1").get_terminal_names(), PackedStringArray(["A2", "A1", "TL"]), "S is renamed")
