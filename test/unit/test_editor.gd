extends GutTest
## SchematicEditor commands on a live SchematicView. Mouse position is set
## directly because headless runs have no pointer.

var view: SchematicView
var editor: SchematicEditor


func before_each() -> void:
	view = SchematicView.new()
	add_child_autofree(view)
	editor = SchematicEditor.new()
	editor.view = view
	add_child_autofree(editor)
	editor.document_replaced.connect(func(doc: SchematicDocument) -> void: view.load_document(doc, false))
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, 12))
	view.load_document(doc, false)
	editor.active = true


func _at(cell: Vector2) -> void:
	editor._mouse_point = cell
	editor._mouse_cell = Vector2i(cell.round())


func _place(template: Dictionary, cell: Vector2i) -> void:
	editor.begin_place(template)
	_at(Vector2(cell))
	editor._on_left_pressed(false)
	editor._cancel_tool()


func _wire(points: Array[Vector2]) -> void:
	_at(points[0])
	editor._on_left_pressed(false)
	editor._on_left_released(false)
	for i: int in range(1, points.size()):
		_at(points[i])
		editor._on_left_pressed(false)
		editor._on_left_released(false)


func test_place_wire_and_simulate() -> void:
	_place({"type": "latching_switch", "contact": "NO"}, Vector2i(5, 2))
	_place({"type": "lamp"}, Vector2i(5, 7))
	var doc: SchematicDocument = editor.document()
	assert_not_null(doc.circuit.get_component("RB1"))
	assert_not_null(doc.circuit.get_component("H1"))
	assert_eq(view.get_symbol("H1").position, Vector2(5, 7) * SymbolGeometry.GRID)
	_wire([Vector2(2, 1), Vector2(5, 1), Vector2(5, 2)])
	_wire([Vector2(5, 5), Vector2(5, 7)])
	_wire([Vector2(5, 10), Vector2(5, 12), Vector2(2, 12)])
	assert_eq(doc.get_wire_count(), 3)
	assert_eq(doc.get_route(0).corners, [Vector2i(5, 1)] as Array[Vector2i])
	(doc.circuit.get_component("RB1") as LatchingSwitch).set_switched_on(true)
	Simulator.new(doc.circuit).step()
	assert_true((doc.circuit.get_component("H1") as Lamp).energized)


func test_wire_ending_on_wire_adds_junction() -> void:
	_place({"type": "lamp"}, Vector2i(5, 4))
	_place({"type": "lamp"}, Vector2i(9, 4))
	_wire([Vector2(2, 1), Vector2(5, 1), Vector2(5, 4)])
	_wire([Vector2(9, 4), Vector2(9, 1), Vector2(3.9, 1.1)])
	var doc: SchematicDocument = editor.document()
	assert_not_null(doc.circuit.get_component("J1"))
	assert_eq(doc.get_placement("J1").cell, Vector2i(4, 1))
	assert_eq(doc.circuit.wires_of(doc.circuit.get_component("J1")).size(), 3)


func test_contact_takes_coil_designation_and_next_number() -> void:
	_place({"type": "coil", "kind": "contactor"}, Vector2i(5, 7))
	_place({"type": "contact", "contact": "NO"}, Vector2i(9, 2))
	_place({"type": "contact", "contact": "NC"}, Vector2i(12, 2))
	var doc: SchematicDocument = editor.document()
	assert_not_null(doc.circuit.get_component("KM1:13-14"))
	assert_not_null(doc.circuit.get_component("KM1:21-22"))


func test_coil_takes_the_contacts_drawn_before_it() -> void:
	for x: int in [3, 9, 15, 21]:
		_place({"type": "main_contacts"}, Vector2i(x, 2))
	var doc: SchematicDocument = editor.document()
	assert_not_null(doc.circuit.get_component("KM4:1-2-3-4-5-6"))
	_place({"type": "coil", "kind": "contactor"}, Vector2i(5, 7))
	assert_not_null(doc.circuit.get_coil("KM1"), "the coil of the first main contacts, not KM5")
	_place({"type": "coil", "kind": "contactor"}, Vector2i(9, 7))
	assert_not_null(doc.circuit.get_coil("KM2"))


func test_main_contacts_take_auxiliary_contacts_drawn_before_them() -> void:
	_place({"type": "contact", "contact": "NO"}, Vector2i(5, 2))
	var doc: SchematicDocument = editor.document()
	assert_not_null(doc.circuit.get_component("KM1:13-14"))
	_place({"type": "main_contacts"}, Vector2i(9, 2))
	assert_not_null(doc.circuit.get_component("KM1:1-2-3-4-5-6"), "KM1, not KM2")
	_place({"type": "main_contacts"}, Vector2i(15, 2))
	assert_not_null(doc.circuit.get_component("KM2:1-2-3-4-5-6"))
	_place({"type": "contact", "contact": "NC"}, Vector2i(22, 2))
	assert_not_null(doc.circuit.get_component("KM1:21-22"), "contacts without a coil stay with KM1")


func test_time_relay_takes_its_delayed_contacts() -> void:
	_place({"type": "timer", "mode": "on_delay", "delay": 3.0}, Vector2i(5, 7))
	var doc: SchematicDocument = editor.document()
	_place({"type": "contact", "contact": "NO"}, Vector2i(9, 2))
	assert_not_null(doc.circuit.get_component("KT1:17-18"))
	editor.selected_components.clear()
	editor.selected_components["KT1"] = true
	editor.delete_selection()
	_place({"type": "timer", "mode": "on_delay", "delay": 3.0}, Vector2i(5, 7))
	assert_true(doc.circuit.get_coil("KT1") is TimerRelay, "the new time relay takes KT1 back")


func test_coil_turned_into_time_relay_becomes_kt() -> void:
	_place({"type": "coil", "kind": "contactor"}, Vector2i(5, 7))
	assert_eq(editor.change_type("KM1", {"type": "timer", "mode": "on_delay", "delay": 3.0}), "")
	var doc: SchematicDocument = editor.document()
	assert_true(doc.circuit.get_coil("KT1") is TimerRelay)
	assert_eq(editor.change_type("KT1", {"type": "coil"}), "")
	assert_not_null(doc.circuit.get_coil("KM1"), "and back")
	_place({"type": "contact", "contact": "NO"}, Vector2i(9, 2))
	assert_eq(editor.change_type("KM1", {"type": "timer", "mode": "on_delay", "delay": 3.0}), "")
	assert_true(doc.circuit.get_coil("KM1") is TimerRelay, "with contacts it keeps its designation")


func test_undo_redo_and_delete() -> void:
	_place({"type": "lamp"}, Vector2i(5, 4))
	_wire([Vector2(2, 1), Vector2(5, 1), Vector2(5, 4)])
	assert_eq(editor.document().get_wire_count(), 1)
	editor.undo()
	assert_eq(editor.document().get_wire_count(), 0)
	assert_not_null(editor.document().circuit.get_component("H1"))
	editor.redo()
	assert_eq(editor.document().get_wire_count(), 1)
	editor.selected_components["H1"] = true
	editor.delete_selection()
	assert_null(editor.document().circuit.get_component("H1"))
	assert_eq(editor.document().get_wire_count(), 0)
	editor.undo()
	assert_not_null(editor.document().circuit.get_component("H1"))


func test_properties_change_and_conflict() -> void:
	_place({"type": "push_button", "contact": "NO"}, Vector2i(5, 2))
	_place({"type": "push_button", "contact": "NO"}, Vector2i(9, 2))
	var data: Dictionary = DocumentSerializer.component_to_dict(editor.document().circuit.get_component("SB2"))
	data["contact"] = "NC"
	assert_eq(editor.apply_properties("SB2", data), "")
	assert_true(editor.document().circuit.has_terminal("SB2:11"))
	data["contact"] = "NO"
	data["designation"] = "SB1"
	assert_ne(editor.apply_properties("SB2", data), "", "SB1 13-14 is taken")
	assert_not_null(editor.document().circuit.get_component("SB2"))
	data["contact"] = "NC"
	data["sequence"] = 2
	assert_eq(editor.apply_properties("SB2", data), "", "SB1 21-22 is a second block of S1")
	assert_eq((editor.document().circuit.get_component("SB1:21-22") as PushButton).actuator,
		(editor.document().circuit.get_component("SB1:13-14") as PushButton).actuator, "blocks share the button")


func test_rotate_selection_turns_component() -> void:
	_place({"type": "lamp"}, Vector2i(5, 4))
	editor.selected_components["H1"] = true
	editor.rotate_selection()
	assert_eq(editor.document().get_placement("H1").rotation, 1)
	editor.mirror_selection()
	assert_true(editor.document().get_placement("H1").mirrored)


func _press_key(code: Key) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.keycode = code
	e.pressed = true
	editor._unhandled_input(e)


func test_r_and_delete_keys_act_on_clicked_component() -> void:
	_place({"type": "lamp"}, Vector2i(5, 4))
	_at(Vector2(5, 5.5))
	editor._on_left_pressed(false)
	editor._on_left_released(false)
	assert_true(editor.selected_components.has("H1"), "click selects")
	_press_key(KEY_R)
	assert_eq(editor.document().get_placement("H1").rotation, 1, "R rotates")
	_press_key(KEY_DELETE)
	assert_null(editor.document().circuit.get_component("H1"), "Delete removes")


func test_change_switch_type_keeps_wires() -> void:
	_place({"type": "latching_switch", "contact": "NO"}, Vector2i(5, 2))
	_wire([Vector2(2, 1), Vector2(5, 1), Vector2(5, 2)])
	var doc: SchematicDocument = editor.document()
	assert_eq(editor.change_type("RB1", {"type": "latching_switch", "contact": "NC"}), "")
	assert_true(doc.circuit.get_component("RB1") is LatchingSwitch)
	assert_eq(doc.circuit.get_wires()[0][1], "RB1:11", "wire moved to the NC terminal")
	assert_eq(editor.change_type("RB1", {"type": "push_button", "contact": "NO"}), "")
	assert_true(doc.circuit.get_component("SB1") is PushButton, "a push button is SB")
	assert_eq(doc.circuit.get_wires()[0][1], "SB1:13", "keeping its wire")
	editor.undo()
	assert_true(editor.document().circuit.get_component("RB1") is LatchingSwitch, "undoable")


func test_change_switch_to_contacts_follows_coils() -> void:
	_place({"type": "coil", "kind": "contactor"}, Vector2i(9, 6))
	_place({"type": "timer", "mode": "on_delay", "delay": 3.0}, Vector2i(13, 6))
	_place({"type": "push_button", "contact": "NO"}, Vector2i(5, 2))
	var doc: SchematicDocument = editor.document()
	assert_eq(editor.change_type("SB1", {"type": "contact", "contact": "NO"}), "")
	assert_not_null(doc.circuit.get_component("KM1:13-14"), "a contact belongs to the coil")
	assert_eq(editor.change_type("KM1:13-14", {"type": "contact", "contact": "NC", "delayed": true}), "")
	var timer_contact: Contact = doc.circuit.get_component("KT1:15-16") as Contact
	assert_not_null(timer_contact, "a delayed contact moves to the timer")
	assert_true(timer_contact.linked_coil is TimerRelay)
	assert_eq(editor.change_type("KT1:15-16", {"type": "latching_switch", "contact": "NO"}), "")
	assert_not_null(doc.circuit.get_component("RB1"), "back to a switch with a new RB designation")


func test_type_options_and_matching() -> void:
	var options: Array[Dictionary] = SchematicEditor.type_options(PushButton.new("S1", SwitchingElement.ContactType.NC))
	assert_eq(options.size(), 8, "buttons, switches, limit switches, contacts (delayed is a property)")
	assert_eq(SchematicEditor.type_options(Lamp.new("H1")).size(), 2)
	assert_eq(SchematicEditor.type_options(Junction.new("J1")).size(), 0)
	assert_true(SchematicEditor.matches_template(Contact.new("K1", SwitchingElement.ContactType.NO), {"type": "contact", "contact": "NO"}))
	assert_true(SchematicEditor.matches_template(Contact.new("K1", SwitchingElement.ContactType.NO, 1, true), {"type": "contact", "contact": "NO"}), "a delayed contact is a contact")


func test_copy_paste_at_mouse_and_select_all() -> void:
	_place({"type": "lamp"}, Vector2i(5, 4))
	editor.selected_components["H1"] = true
	editor.copy_selection()
	_at(Vector2(12, 4))
	editor.paste()
	var doc: SchematicDocument = editor.document()
	assert_eq(doc.get_placement("H2").cell, Vector2i(12, 4))
	assert_eq(editor.selected_components.keys(), ["H2"], "pasted part is selected")
	editor.cut_selection()
	assert_null(doc.circuit.get_component("H2"))
	editor.select_all()
	assert_eq(editor.selected_components.size(), 3, "L, N and H1")


func test_rename_and_swap_terminals_in_properties() -> void:
	_place({"type": "coil", "kind": "relay"}, Vector2i(5, 4))
	_wire([Vector2(2, 1), Vector2(5, 1), Vector2(5, 4)])
	var doc: SchematicDocument = editor.document()
	var data: Dictionary = DocumentSerializer.component_to_dict(doc.circuit.get_component("KA1"))
	data["terminals"] = ["A2", "A1"]
	assert_eq(editor.apply_properties("KA1", data), "")
	assert_eq(doc.circuit.get_wires()[0][1], "KA1:A2", "the wire at the top now ends on A2")
	_place({"type": "push_button", "contact": "NO"}, Vector2i(10, 4))
	data = DocumentSerializer.component_to_dict(doc.circuit.get_component("SB1"))
	data["terminals"] = ["5", "6"]
	assert_eq(editor.apply_properties("SB1:13-14", data), "")
	assert_not_null(doc.circuit.get_component("SB1:5-6"))
	data["terminals"] = ["5", "5"]
	assert_ne(editor.apply_properties("SB1:5-6", data), "", "duplicate names are refused")
	editor.undo()
	assert_not_null(editor.document().circuit.get_component("SB1:13-14"), "undoable")


func test_protection_parts_get_f_designations() -> void:
	_place({"type": "fuse"}, Vector2i(5, 4))
	_place({"type": "overload_relay", "trip_delay": 5.0}, Vector2i(10, 4))
	_place({"type": "overload_contact", "contact": "NC"}, Vector2i(15, 4))
	var doc: SchematicDocument = editor.document()
	assert_true(doc.circuit.get_component("FU1") is Fuse, "a fuse is FU")
	assert_true(doc.circuit.get_component("F1") is OverloadRelay, "an overload relay is F")
	assert_not_null(doc.circuit.get_component("F1:95-96"), "the contact belongs to the overload relay")
	assert_eq(editor.change_type("FU1", {"type": "breaker"}), "")
	assert_true(doc.circuit.get_component("FA1") is CircuitBreaker, "a circuit breaker is FA")


func test_changeover_contact_follows_coil_and_changes_type() -> void:
	_place({"type": "timer", "mode": "on_delay", "delay": 3.0}, Vector2i(5, 8))
	_place({"type": "changeover", "delayed": true}, Vector2i(10, 2))
	var doc: SchematicDocument = editor.document()
	assert_not_null(doc.circuit.get_component("KT1:15-16-18"))
	var instant: Dictionary = DocumentSerializer.component_to_dict(editor.document().circuit.get_component("KT1:15-16-18"))
	instant["delayed"] = false
	assert_eq(editor.apply_properties("KT1:15-16-18", instant), "", "unticking Delayed keeps it on the timer")
	assert_not_null(doc.circuit.get_component("KT1:11-12-14"), "instantaneous changeover of the same timer")


func test_three_phase_parts_from_the_palette() -> void:
	_place({"type": "coil", "kind": "contactor"}, Vector2i(20, 4))
	var x: int = 5
	var wanted: PackedStringArray = ["L2 supply", "L1 supply", "L3 supply", "Main contacts", "Fuse", "Circuit breaker", "Overload relay", "Motor 3~", "Motor 3~ star/delta", "Motor 3~ Dahlander", "Motor 3~ two windings", "Motor 3~ three windings"]
	for title: String in wanted:
		for entry: Dictionary in Palette.ENTRIES:
			if entry["title"] == title:
				_place(entry["template"], Vector2i(x, 20))
		x += 8
	var doc: SchematicDocument = editor.document()
	# One part per family; the poles are set in the properties.
	for id: String in ["FU1", "FA1", "F1"]:
		var poles: Dictionary = DocumentSerializer.component_to_dict(doc.circuit.get_component(id))
		poles["poles"] = 3
		assert_eq(editor.apply_properties(id, poles), "", id + " gets three poles")
	for id: String in ["L2", "L1", "L3", "KM1:1-2-3-4-5-6", "FU1:1-2-3-4-5-6", "FA1:1-2-3-4-5-6", "F1:1-2-3-4-5-6", "M1", "M2", "M3", "M4", "M5"]:
		assert_true(doc.circuit.has_component_id(id), id + " placed")
	assert_eq((doc.circuit.get_component("L1") as PowerSupply).conductor, PowerSupply.Conductor.L, "L next to L2 is called L1")
	assert_eq((doc.circuit.get_component("M2") as ThreePhaseMotor).kind, ThreePhaseMotor.Kind.STAR_DELTA)
	assert_eq((doc.circuit.get_component("KM1:1-2-3-4-5-6") as MainContacts).linked_coil, doc.circuit.get_coil("KM1"))
	# Change to: only motor kinds with as many terminals.
	var titles: Array = SchematicEditor.type_options(doc.circuit.get_component("M2")).map(func(e: Dictionary) -> String: return e["title"])
	assert_eq(titles, ["Motor 3~ star/delta", "Motor 3~ Dahlander", "Motor 3~ two windings"])
	assert_eq(editor.change_type("M2", {"type": "motor3", "motor_kind": "dahlander"}), "")
	assert_eq((doc.circuit.get_component("M2") as ThreePhaseMotor).kind, ThreePhaseMotor.Kind.DAHLANDER)
	assert_eq(editor.change_type("FU1:1-2-3-4-5-6", {"type": "breaker"}), "")
	assert_true(doc.circuit.get_component("FA2:1-2-3-4-5-6") is MotorBreaker, "a three-pole fuse becomes a three-pole breaker FA")
	var data: Dictionary = DocumentSerializer.component_to_dict(doc.circuit.get_component("L2"))
	data["conductor"] = "L3"
	assert_eq(editor.apply_properties("L2", data), "")
	assert_true(doc.circuit.has_component_id("L3.2"), "a second L3 point")


func test_one_coil_entry_named_by_kind() -> void:
	_place({"type": "coil"}, Vector2i(5, 4))
	var doc: SchematicDocument = editor.document()
	assert_not_null(doc.circuit.get_coil("KM1"), "a new coil is a contactor KM")
	var data: Dictionary = DocumentSerializer.component_to_dict(doc.circuit.get_coil("KM1"))
	data["kind"] = "relay"
	assert_eq(editor.apply_properties("KM1", data), "")
	assert_not_null(doc.circuit.get_coil("KA1"), "turned into a relay it becomes KA")
	assert_eq(doc.circuit.get_coil("KA1").kind, Coil.Kind.RELAY)
	_place({"type": "contact", "contact": "NO"}, Vector2i(9, 4))
	data = DocumentSerializer.component_to_dict(doc.circuit.get_coil("KA1"))
	data["kind"] = "contactor"
	assert_eq(editor.apply_properties("KA1", data), "")
	assert_not_null(doc.circuit.get_coil("KA1"), "with a contact on it the name stays")


func test_contact_of_an_overload_relay() -> void:
	_place({"type": "overload_relay", "trip_delay": 5.0}, Vector2i(10, 3))
	# Placed while the relay is selected, a contact is its overload contact.
	_place({"type": "contact", "contact": "NO"}, Vector2i(18, 3))
	assert_true(editor.document().circuit.get_component("F1:97-98") is OverloadContact)
	editor._clear_selection()
	_place({"type": "contact", "contact": "NC"}, Vector2i(14, 3))
	var doc: SchematicDocument = editor.document()
	var contact: CircuitComponent = null
	for c: CircuitComponent in doc.circuit.get_components():
		if c is Contact and not (c is OverloadContact):
			contact = c
	var data: Dictionary = DocumentSerializer.component_to_dict(contact)
	data["designation"] = "F1"
	assert_eq(editor.apply_properties(contact.id, data), "")
	assert_true(doc.circuit.get_component("F1:95-96") is OverloadContact, "a contact designated like the overload relay becomes its 95-96")
	data = DocumentSerializer.component_to_dict(doc.circuit.get_component("F1:95-96"))
	data["designation"] = "KA1"
	assert_eq(editor.apply_properties("F1:95-96", data), "")
	assert_true(doc.circuit.get_component("KA1:11-12") is Contact, "and back to a plain contact")


func test_markings_are_edited_in_place() -> void:
	_place({"type": "coil"}, Vector2i(10, 3))
	_place({"type": "lamp"}, Vector2i(14, 3))
	var doc: SchematicDocument = editor.document()
	editor._inline_target = {"component": "KM1", "kind": "designation", "index": -1}
	editor._commit_inline("-KM5")
	assert_true(doc.circuit.has_component_id("KM5"), "designation edited, the dash is the prefix")
	editor._inline_target = {"component": "KM5", "kind": "terminal", "index": 1}
	editor._commit_inline("A3")
	assert_eq(doc.circuit.get_component("KM5").get_terminal_names(), PackedStringArray(["A1", "A3"]))
	editor._inline_target = {"component": "H1", "kind": "purpose", "index": -1}
	editor._commit_inline("Running")
	assert_eq((doc.circuit.get_component("H1") as Lamp).purpose, "Running")
	_place({"type": "timer", "mode": "on_delay", "delay": 1.0}, Vector2i(18, 3))
	var timer_id: String = ""
	for c: CircuitComponent in doc.circuit.get_components():
		if c is TimerRelay:
			timer_id = c.id
	assert_true(editor._edit_marking(doc.circuit.get_component(timer_id), "terminal", 0), "A1 of a time relay opens (it can swap with A2)")
	editor._close_inline()
	editor.undo()
	editor.undo()
	assert_eq((editor.document().circuit.get_component("H1") as Lamp).purpose, "", "undoable")


func test_contacts_of_a_time_relay_are_delayed() -> void:
	_place({"type": "timer", "mode": "on_delay", "delay": 3.0}, Vector2i(5, 8))
	# Placed while the time relay is selected: its delayed contact.
	_place({"type": "contact", "contact": "NO"}, Vector2i(10, 2))
	var doc: SchematicDocument = editor.document()
	assert_true(doc.circuit.has_component_id("KT1:17-18"), "a contact of KT1 is delayed by default")
	_place({"type": "coil"}, Vector2i(15, 8))
	_place({"type": "contact", "contact": "NC"}, Vector2i(20, 2))
	assert_true(doc.circuit.has_component_id("KM1:11-12"))
	editor._inline_target = {"component": "KM1:11-12", "kind": "designation", "index": -1}
	editor._commit_inline("KT1")
	assert_true(editor.document().circuit.has_component_id("KT1:15-16"), "designated to KT1, it becomes delayed")
	var timer: TimerRelay = editor.document().circuit.get_coil("KT1") as TimerRelay
	var data: Dictionary = DocumentSerializer.component_to_dict(timer)
	data["control_input"] = true
	assert_eq(editor.apply_properties(timer.id, data), "")
	var titles: Array = SchematicEditor.type_options(editor.document().circuit.get_coil("KT1")).map(func(e: Dictionary) -> String: return e["title"])
	assert_eq(titles.size(), 2, "with S the type can still be changed")


func test_markings_are_selected_and_dragged() -> void:
	_place({"type": "lamp"}, Vector2i(10, 3))
	await wait_frames(2)
	var symbol: SchematicSymbol = view.get_symbol("H1")
	var r: Rect2 = symbol.marking_rect("designation")
	assert_true(r.has_area(), "the designation was drawn")
	var at: Vector2 = (symbol.position + r.get_center()) / SymbolGeometry.GRID
	editor._clear_selection()
	_at(at)
	editor._on_left_pressed(false)
	assert_eq(editor.selected_marking.get("kind", ""), "designation", "a click highlights the marking")
	assert_true(editor.selected_components.has("H1"), "and selects its part")
	_at(at + Vector2(-1.5, 0.5))
	editor._on_mouse_moved()
	editor._on_left_released(false)
	var p: Placement = editor.document().get_placement("H1")
	assert_eq(p.labels.get("designation", Vector2.ZERO), Vector2(-1.5, 0.5), "dragged")
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(editor.document()))
	assert_eq(copy.get_placement("H1").labels.get("designation", Vector2.ZERO), Vector2(-1.5, 0.5), "saved")
	editor.undo()
	assert_true(editor.document().get_placement("H1").labels.is_empty(), "undoable")


## Bad names typed into markings are refused with a message and change nothing.
func test_bad_markings_are_refused() -> void:
	_place({"type": "coil"}, Vector2i(10, 3))
	_place({"type": "coil"}, Vector2i(14, 3))
	_place({"type": "lamp"}, Vector2i(18, 3))
	var doc: SchematicDocument = editor.document()
	var hints: Array[String] = []
	editor.hint_changed.connect(func(text: String) -> void: hints.append(text))
	var before: Dictionary = DocumentSerializer.to_dict(doc)
	for bad: String in ["", "-", "   ", "KM:1", "K M1", "KM2", "L", "N", "H1"]:
		hints.clear()
		editor._inline_target = {"component": "KM1", "kind": "designation", "index": -1}
		editor._commit_inline(bad)
		assert_true(editor.document().circuit.has_component_id("KM1"), "'%s' refused" % bad)
		assert_false(hints.is_empty(), "'%s' explained" % bad)
	# ("A2" is no mistake: A1 and A2 swap, see test_devices.gd.)
	for bad: String in ["", "A 1", "A:1"]:
		hints.clear()
		editor._inline_target = {"component": "KM1", "kind": "terminal", "index": 0}
		editor._commit_inline(bad)
		assert_eq(editor.document().circuit.get_component("KM1").get_terminal_names(), PackedStringArray(["A1", "A2"]), "terminal '%s' refused" % bad)
	assert_eq(DocumentSerializer.to_dict(editor.document()), before, "nothing changed")
	# Fine names, including Czech letters, are taken.
	editor._inline_target = {"component": "H1", "kind": "designation", "index": -1}
	editor._commit_inline("  -HŘ2 ")
	assert_true(editor.document().circuit.has_component_id("HŘ2"), "trimmed, dash dropped")
	editor._inline_target = {"component": "HŘ2", "kind": "purpose", "index": -1}
	editor._commit_inline("  Chod  ")
	assert_eq((editor.document().circuit.get_component("HŘ2") as Lamp).purpose, "Chod")


func test_renaming_a_coil_takes_its_contacts_along() -> void:
	_place({"type": "coil"}, Vector2i(10, 6))
	_place({"type": "contact", "contact": "NO"}, Vector2i(14, 2))
	_place({"type": "main_contacts"}, Vector2i(20, 2))
	editor._inline_target = {"component": "KM1", "kind": "designation", "index": -1}
	editor._commit_inline("KM7")
	var doc: SchematicDocument = editor.document()
	assert_true(doc.circuit.has_component_id("KM7:13-14"), "the contact follows its coil")
	assert_true(doc.circuit.has_component_id("KM7:1-2-3-4-5-6"), "and the main contacts")
	editor.undo()
	assert_true(editor.document().circuit.has_component_id("KM1:13-14"), "one undo step")


func test_terminal_on_a_lead() -> void:
	_place({"type": "lamp"}, Vector2i(10, 3))
	_place({"type": "terminal"}, Vector2i(10, 6))
	var doc: SchematicDocument = editor.document()
	assert_eq(doc.get_placement("H1").strips, {1: "1"} as Dictionary[int, String], "X2 of the lamp ends in strip terminal 1")
	assert_false(doc.circuit.get_components().any(func(c: CircuitComponent) -> bool: return c is TerminalBlock), "no separate terminal")
	editor._inline_target = {"component": "H1", "kind": "strip", "index": 1}
	editor._commit_inline("X3:7")
	assert_eq(editor.document().get_placement("H1").strips[1], "X3:7", "renamed in place")
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(editor.document()))
	assert_eq(copy.get_placement("H1").strips[1], "X3:7", "saved")
	editor.selected_marking = {"component": "H1", "kind": "strip", "index": 1}
	editor.delete_selection()
	assert_true(editor.document().circuit.has_component_id("H1"), "Delete removes the terminal, not the lamp")
	assert_true(editor.document().get_placement("H1").strips.is_empty())


func test_designation_prefixes_and_limit_switch() -> void:
	_place({"type": "push_button", "contact": "NO"}, Vector2i(4, 2))
	_place({"type": "latching_switch", "contact": "NO"}, Vector2i(8, 2))
	_place({"type": "limit_switch", "contact": "NC"}, Vector2i(12, 2))
	_place({"type": "fuse"}, Vector2i(16, 2))
	_place({"type": "breaker"}, Vector2i(20, 2))
	var doc: SchematicDocument = editor.document()
	assert_true(doc.circuit.get_component("SB1") is PushButton, "push button SB")
	assert_true(doc.circuit.get_component("RB1") is LatchingSwitch, "rotary switch RB")
	assert_true(doc.circuit.get_component("SQ1") is LimitSwitch, "limit switch SQ")
	assert_true(doc.circuit.get_component("FU1") is Fuse, "fuse FU")
	assert_true(doc.circuit.get_component("FA1") is CircuitBreaker, "circuit breaker FA")
	var limit: LimitSwitch = doc.circuit.get_component("SQ1") as LimitSwitch
	assert_true(limit.is_closed(), "an NC limit switch is closed at rest")
	limit.toggle()
	limit.actuator.snap(limit.actuator.target)
	assert_false(limit.is_closed(), "operated it opens")
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_true(copy.circuit.get_component("SQ1") is LimitSwitch, "saved as a limit switch")


func test_main_contacts_go_to_a_contactor_without_them() -> void:
	var doc: SchematicDocument = editor.document()
	# Power section first: no coils yet, every set gets its own contactor.
	_place({"type": "main_contacts"}, Vector2i(5, 20))
	editor._clear_selection()
	_place({"type": "main_contacts"}, Vector2i(13, 20))
	assert_true(doc.circuit.has_component_id("KM1:1-2-3-4-5-6"))
	assert_true(doc.circuit.has_component_id("KM2:1-2-3-4-5-6"), "the second set is KM2, not refused as KM1")
	# The coils drawn later; a third coil gets main contacts of its own,
	# even while a coil whose main contacts are drawn is selected.
	_place({"type": "coil"}, Vector2i(5, 4))
	_place({"type": "coil"}, Vector2i(9, 4))
	_place({"type": "coil"}, Vector2i(13, 4))
	assert_not_null(doc.circuit.get_coil("KM3"))
	editor._clear_selection()
	editor.selected_components["KM1"] = true
	_place({"type": "main_contacts"}, Vector2i(21, 20))
	assert_true(doc.circuit.has_component_id("KM3:1-2-3-4-5-6"), "KM3 is the contactor without main contacts")
	editor._clear_selection()
	_place({"type": "main_contacts"}, Vector2i(29, 20))
	assert_true(doc.circuit.has_component_id("KM4:1-2-3-4-5-6"), "all contactors have theirs: a new KM")


func test_overload_contact_taken_is_not_refused() -> void:
	_place({"type": "overload_relay", "trip_delay": 5.0}, Vector2i(10, 3))
	_place({"type": "coil"}, Vector2i(20, 3))
	var doc: SchematicDocument = editor.document()
	var count: int = doc.circuit.get_components().size()
	for x: int in [14, 18]:
		editor._clear_selection()
		editor.selected_components["F1"] = true
		_place({"type": "contact", "contact": "NC"}, Vector2i(x, 8))
	assert_eq(doc.circuit.get_components().size(), count + 2, "both contacts placed")
	assert_true(doc.circuit.get_component("F1:95-96") is OverloadContact, "the first is the relay's 95-96")
	assert_true(doc.circuit.has_component_id("KM1:11-12"), "its 95-96 taken, the second goes to the coil")
