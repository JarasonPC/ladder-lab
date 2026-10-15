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
	assert_not_null(doc.circuit.get_component("S1"))
	assert_not_null(doc.circuit.get_component("H1"))
	assert_eq(view.get_symbol("H1").position, Vector2(5, 7) * SymbolGeometry.GRID)
	_wire([Vector2(2, 1), Vector2(5, 1), Vector2(5, 2)])
	_wire([Vector2(5, 5), Vector2(5, 7)])
	_wire([Vector2(5, 10), Vector2(5, 12), Vector2(2, 12)])
	assert_eq(doc.get_wire_count(), 3)
	assert_eq(doc.get_route(0).corners, [Vector2i(5, 1)] as Array[Vector2i])
	(doc.circuit.get_component("S1") as LatchingSwitch).set_switched_on(true)
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
	assert_not_null(doc.circuit.get_component("K1:13-14"))
	assert_not_null(doc.circuit.get_component("K1:21-22"))


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
	var data: Dictionary = DocumentSerializer.component_to_dict(editor.document().circuit.get_component("S2"))
	data["contact"] = "NC"
	assert_eq(editor.apply_properties("S2", data), "")
	assert_true(editor.document().circuit.has_terminal("S2:11"))
	data["designation"] = "S1"
	assert_ne(editor.apply_properties("S2", data), "", "S1 is taken")
	assert_not_null(editor.document().circuit.get_component("S2"))


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
	assert_eq(editor.change_type("S1", {"type": "latching_switch", "contact": "NC"}), "")
	assert_true(doc.circuit.get_component("S1") is LatchingSwitch)
	assert_eq(doc.circuit.get_wires()[0][1], "S1:11", "wire moved to the NC terminal")
	assert_eq(editor.change_type("S1", {"type": "push_button", "contact": "NO"}), "")
	assert_true(doc.circuit.get_component("S1") is PushButton, "button keeps the S designation")
	editor.undo()
	assert_true(editor.document().circuit.get_component("S1") is LatchingSwitch, "undoable")


func test_change_switch_to_contacts_follows_coils() -> void:
	_place({"type": "coil", "kind": "contactor"}, Vector2i(9, 6))
	_place({"type": "timer", "mode": "on_delay", "delay": 3.0}, Vector2i(13, 6))
	_place({"type": "push_button", "contact": "NO"}, Vector2i(5, 2))
	var doc: SchematicDocument = editor.document()
	assert_eq(editor.change_type("S1", {"type": "contact", "contact": "NO"}), "")
	assert_not_null(doc.circuit.get_component("K1:13-14"), "a contact belongs to the coil")
	assert_eq(editor.change_type("K1:13-14", {"type": "contact", "contact": "NC", "delayed": true}), "")
	var timer_contact: Contact = doc.circuit.get_component("KT1:15-16") as Contact
	assert_not_null(timer_contact, "a delayed contact moves to the timer")
	assert_true(timer_contact.linked_coil is TimerRelay)
	assert_eq(editor.change_type("KT1:15-16", {"type": "latching_switch", "contact": "NO"}), "")
	assert_not_null(doc.circuit.get_component("S1"), "back to a switch with a new S designation")


func test_type_options_and_matching() -> void:
	var options: Array[Dictionary] = SchematicEditor.type_options(PushButton.new("S1", SwitchingElement.ContactType.NC))
	assert_eq(options.size(), 8, "buttons, switches, contacts, delayed contacts")
	assert_eq(SchematicEditor.type_options(Lamp.new("H1")).size(), 2)
	assert_eq(SchematicEditor.type_options(Junction.new("J1")).size(), 0)
	assert_true(SchematicEditor.matches_template(Contact.new("K1", SwitchingElement.ContactType.NO), {"type": "contact", "contact": "NO"}))
	assert_false(SchematicEditor.matches_template(Contact.new("K1", SwitchingElement.ContactType.NO, 1, true), {"type": "contact", "contact": "NO"}))


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
