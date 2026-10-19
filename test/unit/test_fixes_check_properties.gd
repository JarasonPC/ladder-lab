extends GutTest
## The circuit check, the properties panel and the edits it makes: terminal
## names, type changes, renames, undo.

const NO: SwitchingElement.ContactType = SwitchingElement.ContactType.NO

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
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, 30))
	view.load_document(doc, false)
	editor.active = true


func _place(template: Dictionary, cell: Vector2i) -> String:
	editor.begin_place(template)
	editor._mouse_point = Vector2(cell)
	editor._mouse_cell = cell
	editor._on_left_pressed(false)
	editor._cancel_tool()
	return editor.selected_components.keys()[0]


func _select(id: String) -> void:
	editor._clear_selection()
	editor.selected_components[id] = true
	editor._selection_updated()


func _data(id: String) -> Dictionary:
	return DocumentSerializer.component_to_dict(editor.document().circuit.get_component(id))


## Applies [param data] of [param id] with [param key] set to [param value].
func _edit(id: String, key: String, value: Variant) -> String:
	var data: Dictionary = _data(id)
	data[key] = value
	return editor.apply_properties(id, data)


func _ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for c: CircuitComponent in editor.document().circuit.get_components():
		ids.append(c.id)
	return ids


func _texts(doc: SchematicDocument) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for issue: Dictionary in CircuitCheck.run(doc):
		texts.append(issue["text"] % issue["args"])
	return texts


func _panel(component: CircuitComponent) -> PropertiesPanel:
	var panel: PropertiesPanel = PropertiesPanel.new()
	add_child_autofree(panel)
	panel.show_component(component)
	return panel


## The field under the caption [param caption] in [param panel].
func _field(panel: Node, caption: String) -> Control:
	for node: Node in panel.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.text == caption and label.get_parent() is VBoxContainer:
			var group: Node = label.get_parent()
			return group.get_child(label.get_index() + 1) as Control
	return null


func _dc_doc() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS), Vector2i(0, 0))
	doc.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS), Vector2i(0, 20))
	return doc


# 1
func test_names_given_by_hand_follow_a_new_number_of_terminals() -> void:
	var fuse: String = _place({"type": "fuse"}, Vector2i(14, 2))
	assert_eq(_edit(fuse, "terminals", ["1", "2X"]), "")
	assert_eq(_edit(fuse, "poles", 3), "", "not refused")
	assert_eq(_data(fuse)["terminals"], ["1", "2X", "3", "4", "5", "6"])
	assert_eq(_edit(fuse, "poles", 1), "")
	assert_eq(_data(fuse)["terminals"], ["1", "2X"])
	var timer: String = _place({"type": "timer", "mode": "on_delay", "delay": 3.0}, Vector2i(5, 10))
	assert_eq(_edit(timer, "terminals", ["A2", "A1"]), "")
	assert_eq(_edit(timer, "control_input", true), "")
	assert_eq(_data(timer)["terminals"], ["A2", "A1", "S"], "A1 and A2 stay swapped")
	assert_eq(_edit(timer, "terminals", ["A2", "A1", "B1"]), "")
	assert_eq(_edit(timer, "control_input", false), "")
	assert_eq(_data(timer)["terminals"], ["A2", "A1"])
	var relay: String = _place({"type": "overload_relay", "trip_delay": 5.0}, Vector2i(24, 2))
	assert_eq(_edit(relay, "poles", 3), "")
	assert_eq(_edit(relay, "terminals", ["1", "2", "3", "4", "5", "6X"]), "")
	assert_eq(_edit(relay, "poles", 0), "")
	assert_false(_data(relay).has("terminals"))


func test_compact_plc_keeps_names_given_by_hand_on_another_cpu() -> void:
	var a1: String = _place({"type": "plc", "family": "compact", "cpu": "8di6dq"}, Vector2i(30, 2))
	var plc: Plc = editor.document().circuit.get_component(a1) as Plc
	var names: PackedStringArray = plc.get_terminal_names()
	var q0: int = names.find("Q0.0")
	names[q0] = "MOTOR"
	assert_eq(_edit(a1, "terminals", Array(names)), "")
	assert_eq(_edit(a1, "cpu", "14di10dq"), "")
	plc = editor.document().circuit.get_component(a1) as Plc
	assert_eq((plc as CompactPlc).cpu, CompactPlc.Cpu.DI14_DQ10)
	assert_eq(plc.get_terminal_names()[plc.default_terminal_names().find("Q0.0")], "MOTOR", "the name stays on Q0.0")


# 2
func test_check_wants_only_the_common_of_a_digital_signal_module() -> void:
	var doc: SchematicDocument = _dc_doc()
	var plc: CompactPlc = CompactPlc.new("A1", null, [Plc.Module.SM_DI8] as Array[Plc.Module], CompactPlc.Cpu.DI14_DQ10)
	doc.add(plc, Vector2i(5, 5))
	var keys: PackedStringArray = plc.get_terminal_keys()
	doc.connect_terminals("+", keys[0])
	doc.connect_terminals("-", keys[1])
	doc.connect_terminals("-", keys[plc.module_terminal(0)])
	assert_eq(_texts(doc), PackedStringArray())


# 3
func test_fuse_turned_into_a_fuse_holder_keeps_its_rating() -> void:
	var fuse: String = _place({"type": "fuse"}, Vector2i(14, 2))
	assert_eq(_edit(fuse, "rated_current", 2.0), "")
	assert_eq(editor.change_type(fuse, {"type": "fuse", "holder": true}), "")
	assert_true(_data(fuse)["holder"])
	assert_eq(_data(fuse)["rated_current"], 2.0)
	assert_eq(editor.change_type(fuse, {"type": "fuse"}), "")
	assert_false(_data(fuse).has("holder"), "back to a plain fuse")
	assert_eq(_data(fuse)["rated_current"], 2.0)


func test_compact_plc_of_any_cpu_is_the_compact_palette_part() -> void:
	var compact: CompactPlc = CompactPlc.new("A1", null, [] as Array[Plc.Module], CompactPlc.Cpu.DI14_DQ10)
	assert_true(SchematicEditor.matches_template(compact, {"type": "plc", "family": "compact", "cpu": "8di6dq"}))
	assert_false(SchematicEditor.matches_template(compact, {"type": "plc"}))
	assert_false(SchematicEditor.matches_template(Plc.new("A2"), {"type": "plc", "family": "compact", "cpu": "8di6dq"}))


# 4
func test_renamed_coil_takes_every_contact_along() -> void:
	var coil: String = _place({"type": "coil"}, Vector2i(5, 10))
	_select(coil)
	_place({"type": "contact", "contact": "NO"}, Vector2i(5, 3))
	editor._clear_selection()
	var orphan: String = _place({"type": "contact", "contact": "NO"}, Vector2i(9, 3))
	assert_eq(_edit(orphan, "designation", "KM9"), "")
	assert_eq(_edit("KM9:23-24", "sequence", 1), "")
	assert_eq(_edit("KM1", "designation", "KM9"), "")
	assert_eq(_ids(), PackedStringArray(["L", "N", "KM9", "KM9:23-24", "KM9:13-14"]), "the contact took the next free number")
	for text: String in _texts(editor.document()):
		assert_false(text.contains("has no coil"), text)


func test_rename_refused_when_main_contacts_would_clash() -> void:
	var coil: String = _place({"type": "coil"}, Vector2i(5, 10))
	_select(coil)
	_place({"type": "main_contacts"}, Vector2i(5, 3))
	editor._clear_selection()
	var orphan: String = _place({"type": "main_contacts"}, Vector2i(12, 3))
	assert_eq(_edit(orphan, "designation", "KM9"), "")
	assert_eq(_edit("KM1", "designation", "KM9"), "KM9:1-2-3-4-5-6 is already used in this circuit.")
	assert_not_null(editor.document().circuit.get_component("KM1"), "nothing renamed")


# 5
func test_sensor_range_bounds_keep_off_each_other() -> void:
	var sensor: String = _place({"type": "temp_sensor"}, Vector2i(26, 10))
	assert_eq(_edit(sensor, "range_max", 50.0), "")
	var panel: PropertiesPanel = _panel(editor.document().circuit.get_component(sensor))
	var low: SpinBox = _field(panel, "Range from (°C)") as SpinBox
	var high: SpinBox = _field(panel, "Range to (°C)") as SpinBox
	assert_eq(low.max_value, 49.0, "the lower bound stays under the upper one")
	assert_eq(high.min_value, 1.0)
	var emitted: Array[Dictionary] = []
	panel.changed.connect(func(_id: String, data: Dictionary) -> void: emitted.append(data))
	low.value = 60.0
	assert_eq(emitted.size(), 1)
	assert_eq(editor.apply_properties(sensor, emitted[0]), "")
	assert_eq(_data(sensor)["range_min"], 49.0)
	assert_eq(_data(sensor)["range_max"], 50.0)


# 6
func test_type_change_keeps_an_unticked_delay() -> void:
	var timer: String = _place({"type": "timer", "mode": "on_delay", "delay": 3.0}, Vector2i(5, 10))
	_select(timer)
	var contact: String = _place({"type": "contact", "contact": "NO"}, Vector2i(9, 2))
	assert_eq(contact, "KT1:17-18")
	assert_eq(_edit(contact, "delayed", false), "")
	assert_eq(editor.change_type("KT1:13-14", {"type": "contact", "contact": "NC"}), "")
	assert_not_null(editor.document().circuit.get_component("KT1:11-12"), "still not delayed")


func test_contacts_follow_a_time_relay_turned_into_a_coil() -> void:
	var timer: String = _place({"type": "timer", "mode": "on_delay", "delay": 3.0}, Vector2i(5, 10))
	_select(timer)
	_place({"type": "contact", "contact": "NO"}, Vector2i(9, 2))
	assert_eq(editor.change_type(timer, {"type": "coil"}), "")
	assert_not_null(editor.document().circuit.get_component("KT1:13-14"), "a plain contact now")
	for text: String in _texts(editor.document()):
		assert_false(text.contains("not a timer"), text)
	assert_eq(editor.change_type("KT1", {"type": "timer", "mode": "on_delay", "delay": 3.0}), "")
	assert_not_null(editor.document().circuit.get_component("KT1:17-18"), "delayed again")
	editor.undo()
	assert_not_null(editor.document().circuit.get_component("KT1:13-14"), "one undoable edit")


# 7
func test_refused_edit_shows_the_part_as_it_stayed() -> void:
	var coil: String = _place({"type": "coil"}, Vector2i(5, 10))
	_select(coil)
	var first: String = _place({"type": "contact", "contact": "NO"}, Vector2i(5, 3))
	_select(coil)
	_place({"type": "contact", "contact": "NO"}, Vector2i(9, 3))
	var panel: PropertiesPanel = _panel(editor.document().circuit.get_component(first))
	panel.changed.connect(func(id: String, data: Dictionary) -> void: panel.show_error(editor.apply_properties(id, data)))
	var number: SpinBox = _field(panel, "Contact number") as SpinBox
	number.value = 2.0
	assert_eq(panel._message.text, "KM1:23-24 is already used in this circuit.")
	number = _field(panel, "Contact number") as SpinBox
	assert_eq(number.value, 1.0, "the field shows the number the contact kept")


# 8
func test_cancelled_wire_keeps_what_can_be_redone() -> void:
	_place({"type": "lamp"}, Vector2i(14, 5))
	_place({"type": "lamp"}, Vector2i(18, 5))
	editor.undo()
	assert_true(editor.history.can_redo())
	editor._start_wire("H1:X1")
	editor._finish_wire("H1:X1", -1)
	assert_true(editor.history.can_redo(), "a wire ending where it started changes nothing")
	editor.redo()
	assert_not_null(editor.document().circuit.get_component("H2"))


func test_discarded_state_gives_back_the_redo_stack() -> void:
	var history: UndoHistory = UndoHistory.new()
	history.record({"v": 1})
	assert_eq(history.undo({"v": 2}), {"v": 1})
	history.record({"v": 1})
	assert_false(history.can_redo())
	history.discard_last()
	assert_true(history.can_redo())
	assert_false(history.can_undo())
	assert_eq(history.redo({"v": 1}), {"v": 2})


# 9
func test_check_supplies_per_source() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L2", PowerSupply.Conductor.L2), Vector2i(0, 0))
	doc.add(PowerSupply.new("L3", PowerSupply.Conductor.L3), Vector2i(0, 20))
	doc.add(Lamp.new("H1"), Vector2i(5, 5))
	doc.connect_terminals("L2", "H1:X1")
	doc.connect_terminals("H1:X2", "L3")
	assert_eq(_texts(doc), PackedStringArray(), "a load between two phases")
	doc = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS), Vector2i(0, 20))
	doc.add(Lamp.new("H1"), Vector2i(5, 5))
	doc.connect_terminals("L", "H1:X1")
	doc.connect_terminals("H1:X2", "-")
	assert_eq(_texts(doc), PackedStringArray(["The circuit has no N supply.", "The circuit has no + supply."]))
	doc = _dc_doc()
	doc.add(Lamp.new("H1"), Vector2i(5, 5))
	doc.connect_terminals("+", "H1:X1")
	doc.connect_terminals("H1:X2", "-")
	assert_eq(_texts(doc), PackedStringArray(), "DC alone")


# 10
func test_check_hints_on_circuits_that_cannot_work() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 20))
	doc.add(TimerRelay.new("KT1", TimerRelay.Mode.PULSE_ON_PRESS, 2.0), Vector2i(5, 10))
	doc.add(Contact.new("KT1", NO, 1, true), Vector2i(10, 2))
	var plc: Plc = Plc.new("A1", null, [Plc.Module.AI2] as Array[Plc.Module])
	plc.rating = "230rc"
	doc.add(plc, Vector2i(20, 5))
	var keys: PackedStringArray = plc.get_terminal_keys()
	doc.connect_terminals("L", keys[0])
	doc.connect_terminals("N", keys[1])
	doc.connect_terminals("L", keys[plc.module_supply(0)])
	doc.connect_terminals("N", keys[plc.module_supply(0) + 1])
	var texts: PackedStringArray = _texts(doc)
	assert_has(texts, "Function F3 of time relay KT1 works with its control input S, which is turned off.")
	assert_has(texts, "Analog module 2 of A1 takes 24 V DC on A1:2L+ and A1:2M, not the AC supply.")
	doc = _dc_doc()
	var cpu: CompactPlc = CompactPlc.new("A1", null, [] as Array[Plc.Module], CompactPlc.Cpu.DI8_DQ6)
	doc.add(cpu, Vector2i(5, 5))
	keys = cpu.get_terminal_keys()
	var names: PackedStringArray = cpu.get_terminal_names()
	doc.connect_terminals("+", keys[0])
	doc.connect_terminals("-", keys[1])
	assert_eq(_texts(doc), PackedStringArray(), "inputs and outputs not used")
	doc.connect_terminals("+", keys[names.find("I0.0")])
	var lamp: Lamp = Lamp.new("H1")
	doc.add(lamp, Vector2i(20, 5))
	doc.connect_terminals(keys[names.find("Q0.0")], "H1:X1")
	doc.connect_terminals("H1:X2", "-")
	assert_eq(_texts(doc), PackedStringArray([
		"Terminal A1:1M is not connected, but the inputs or outputs using it are.",
		"Terminal A1:3L+ is not connected, but the inputs or outputs using it are.",
		"Terminal A1:3M is not connected, but the inputs or outputs using it are."]))


# 11
func test_changeover_and_main_contacts_cannot_take_an_overload_relay_name() -> void:
	_place({"type": "overload_relay", "trip_delay": 5.0}, Vector2i(20, 10))
	var changeover: String = _place({"type": "changeover"}, Vector2i(5, 3))
	assert_eq(_edit(changeover, "designation", "F1"), "F1 is already the designation of another device.")
	editor._clear_selection()
	var contacts: String = _place({"type": "main_contacts"}, Vector2i(10, 3))
	assert_eq(_edit(contacts, "designation", "F1"), "F1 is already the designation of another device.")
	var contact: String = _place({"type": "contact", "contact": "NC"}, Vector2i(15, 3))
	assert_eq(_edit(contact, "designation", "F1"), "")
	assert_not_null(editor.document().circuit.get_component("F1:95-96"), "a plain contact becomes its overload contact")


# 12
func test_plc_versions_too_small_for_the_modules_are_disabled() -> void:
	var a1: String = _place({"type": "plc"}, Vector2i(10, 5))
	assert_eq(_edit(a1, "modules", ["2ai", "2ai", "2ai", "2ai"]), "")
	var panel: PropertiesPanel = _panel(editor.document().circuit.get_component(a1))
	var version: OptionButton = _field(panel, "PLC version (supply and inputs)") as OptionButton
	var values: PackedStringArray = VoltageRating.offered("plc")
	for i: int in values.size():
		assert_eq(version.is_item_disabled(i), Plc.ANALOG_VERSIONS.has(values[i]), values[i])


# 13
func test_inverter_frequencies_are_limited_to_the_maximum() -> void:
	var drive: String = _place({"type": "vfd"}, Vector2i(32, 10))
	assert_eq(_edit(drive, "max_frequency", 30.0), "")
	var panel: PropertiesPanel = _panel(editor.document().circuit.get_component(drive))
	assert_eq((_field(panel, "Fixed frequency, DI3 (Hz)") as SpinBox).max_value, 30.0)
	assert_eq((_field(panel, "Keypad setpoint (Hz)") as SpinBox).max_value, 30.0)


# 14
func test_coil_turned_into_a_time_relay_keeps_swapped_terminals_and_set_times() -> void:
	var coil: String = _place({"type": "coil"}, Vector2i(5, 10))
	assert_eq(_edit(coil, "terminals", ["A2", "A1"]), "")
	assert_eq(_edit(coil, "pick_up", 0.05), "")
	assert_eq(editor.change_type(coil, {"type": "timer", "mode": "on_delay", "delay": 3.0}), "")
	var timer: TimerRelay = editor.document().circuit.get_component("KT1") as TimerRelay
	assert_eq(timer.get_terminal_names(), PackedStringArray(["A2", "A1"]))
	assert_almost_eq(timer.pick_up_time, 0.05, 1e-9)
	var plain: String = _place({"type": "coil"}, Vector2i(15, 10))
	assert_eq(editor.change_type(plain, {"type": "timer", "mode": "on_delay", "delay": 3.0}), "")
	var other: TimerRelay = editor.document().circuit.get_component("KT2") as TimerRelay
	assert_almost_eq(other.pick_up_time, Coil.DEFAULT_PICK_UP[Coil.Kind.RELAY], 1e-9, "default times become the time relay's")
