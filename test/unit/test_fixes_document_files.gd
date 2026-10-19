extends GutTest
## Editing the schematic document, its workspace data and its files: wire
## numbers, strip terminals, renames and type changes, turning, pasting,
## loading damaged values and saving.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC
const PATH: String = "user://test_fixes_document_files.ladder"

var view: SchematicView
var editor: SchematicEditor


func after_all() -> void:
	DirAccess.remove_absolute(PATH + ".tmp")
	DirAccess.remove_absolute(PATH)


func _editor(doc: SchematicDocument) -> SchematicDocument:
	view = SchematicView.new()
	add_child_autofree(view)
	editor = SchematicEditor.new()
	editor.view = view
	add_child_autofree(editor)
	editor.document_replaced.connect(func(d: SchematicDocument) -> void: view.load_document(d, false))
	view.load_document(doc, false)
	editor.active = true
	return editor.document()


func _supplies() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, 16))
	return doc


func _at(cell: Vector2) -> void:
	editor._mouse_point = cell
	editor._mouse_cell = Vector2i(cell.round())


func _place(template: Dictionary, cell: Vector2i) -> void:
	editor.begin_place(template)
	_at(Vector2(cell))
	editor._on_left_pressed(false)
	editor._cancel_tool()


func _wire(key_a: String, key_b: String) -> void:
	for key: String in [key_a, key_b]:
		_at(Vector2(editor.document().terminal_cell(key)))
		editor._on_left_pressed(false)
		editor._on_left_released(false)


## Every strip terminal label with the nets it is on: a label on two nets
## would join them in the switchboard.
func _strip_nets(doc: SchematicDocument) -> Dictionary:
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	var result: Dictionary = {}
	var strips: Dictionary = CabinetDevices.strips(doc)
	for strip: String in strips:
		for t: Dictionary in strips[strip]:
			var nets: Dictionary = {}
			for key: String in t["keys"]:
				nets[net.get(key, -1) if net.has(key) else key] = true
			result["%s:%s" % [strip, t["label"]]] = nets.size()
	return result


func _routes(doc: SchematicDocument) -> Array:
	var result: Array = []
	for w: int in doc.get_wire_count():
		result.append(doc.get_route(w).corners.duplicate())
	return result


# --- Wire numbers ----------------------------------------------------------------

func test_numbering_never_joins_two_nets_through_page_connectors() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.pages = PackedStringArray(["a", "b"])
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	doc.add(PageConnector.new("PC1", "1"), Vector2i(2, 6), 2)
	doc.connect_terminals("L", "PC1")
	doc.add(PushButton.new("SB1", NO), Vector2i(6, 2))
	doc.add(PowerSupply.new("L.2", PowerSupply.Conductor.L), Vector2i(6, 0))
	doc.connect_terminals("L.2", "SB1:13")
	doc.add(PageConnector.new("PC2", "2"), Vector2i(6, 9), 2)
	doc.connect_terminals("SB1:14", "PC2")
	doc.page = 1
	doc.add(PageConnector.new("PC3", "1"), Vector2i(2, 2))
	doc.add(Lamp.new("H1"), Vector2i(2, 4))
	doc.connect_terminals("PC3", "H1:X1")
	doc.add(PageConnector.new("PC4", "2"), Vector2i(6, 2))
	doc.add(Lamp.new("H2"), Vector2i(6, 4))
	doc.connect_terminals("PC4", "H2:X1")
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(4, 12))
	doc.connect_terminals("H1:X2", "N")
	doc.connect_terminals("H2:X2", "N")
	var links: Array[PackedStringArray] = doc.circuit.get_links()
	doc.number_wires()
	assert_eq(doc.circuit.get_links(), links, "connector 1 on L keeps its partner alone")
	assert_eq((doc.circuit.get_component("PC2") as PageConnector).label, "2", "1 is skipped, it is L's connector label")
	Simulator.new(doc.circuit).step()
	assert_false((doc.circuit.get_component("H2") as Lamp).energized, "SB1 open: H2 stays dark")


func test_merging_two_wires_at_a_junction_keeps_the_number() -> void:
	var doc: SchematicDocument = _supplies()
	doc.add(PushButton.new("SB1", NO), Vector2i(2, 4))
	doc.add(Lamp.new("H1"), Vector2i(2, 10))
	doc.add(Lamp.new("H2"), Vector2i(6, 10))
	doc.connect_terminals("L", "SB1:13")
	doc.connect_terminals("SB1:14", "H1:X1")
	doc.connect_terminals("H1:X2", "N")
	doc.connect_terminals("H2:X2", "N")
	var j: String = doc.split_wire(1, Vector2i(2, 8))
	doc.connect_terminals(j, "H2:X1")
	doc.number_wires()
	doc.remove_component("H2")
	doc.cleanup_junctions()
	var w: int = doc.wire_between("SB1:14", "H1:X1")
	assert_gte(w, 0, "merged back into one wire")
	assert_eq(doc.get_route(w).number, "1")


# --- Strip terminals --------------------------------------------------------------

func test_splitting_a_strip_never_gives_two_terminals_one_number() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	var labels: Array[String] = ["2", "3", "X2:1", "X2:2"]
	for k: int in labels.size():
		var t: TerminalBlock = TerminalBlock.new("X%d" % (k + 1))
		t.label = labels[k]
		doc.add(t, Vector2i(2 + 3 * k, 2))
	doc.move_strip_terminals_along("X1", PackedStringArray(["3"]), -1)
	assert_eq(doc.move_strip_terminals("X1", PackedStringArray(["2", "3"]), "X2"), 2)
	var found: Array[String] = []
	for c: CircuitComponent in doc.circuit.get_components():
		found.append((c as TerminalBlock).label)
	assert_eq(found, ["X2:4", "X2:3", "X2:1", "X2:2"] as Array[String], "3 stays 3, 2 is taken there: the next free one")
	assert_eq(doc.strip_orders.get("X2", PackedStringArray()), PackedStringArray(["1", "2", "3", "4"]), "moved in the order they had")
	assert_false(doc.strip_orders.has("X1"), "the emptied strip has no order left")


func test_a_strip_moved_whole_keeps_its_order() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	for k: int in 3:
		var t: TerminalBlock = TerminalBlock.new("X%d" % (k + 1))
		t.label = str(k + 1)
		doc.add(t, Vector2i(2 + 3 * k, 2))
	doc.move_strip_terminals_along("X1", PackedStringArray(["3"]), -1)
	doc.move_strip_terminals_along("X1", PackedStringArray(["3"]), -1)
	doc.move_strip_terminals("X1", PackedStringArray(["1", "2", "3"]), "X5")
	var order: Array = []
	for t: Dictionary in CabinetDevices.strips(doc)["X5"]:
		order.append(t["label"])
	assert_eq(order, ["3", "1", "2"])


func test_a_palette_terminal_takes_a_number_no_lead_has() -> void:
	var doc: SchematicDocument = _editor(_supplies())
	_place({"type": "lamp"}, Vector2i(6, 4))
	_place({"type": "terminal"}, doc.terminal_cell("H1:X1"))
	assert_eq(doc.get_placement("H1").strips, {0: "1"} as Dictionary[int, String])
	_place({"type": "terminal"}, Vector2i(20, 4))
	assert_eq((doc.circuit.get_component("X1") as TerminalBlock).label, "2")


func test_pasted_strip_terminals_get_free_numbers() -> void:
	var doc: SchematicDocument = _editor(_supplies())
	_place({"type": "lamp"}, Vector2i(6, 4))
	_place({"type": "terminal"}, doc.terminal_cell("H1:X1"))
	_place({"type": "terminal"}, Vector2i(20, 4))
	editor._clear_selection()
	editor.selected_components["H1"] = true
	editor.selected_components["X1"] = true
	editor.copy_selection()
	_at(Vector2(10, 10))
	editor.paste()
	var nets: Dictionary = _strip_nets(doc)
	assert_eq(nets.size(), 4, "four terminals")
	for label: String in nets:
		assert_eq(nets[label], 1, "%s on one net" % label)


# --- Renames, type changes, deletes ---------------------------------------------

func test_a_type_change_takes_no_key_or_station_item_along() -> void:
	var doc: SchematicDocument = _supplies()
	doc.add(PushButton.new("SB1", NO), Vector2i(2, 4))
	doc.add(Lamp.new("H1"), Vector2i(2, 12))
	doc.connect_terminals("L", "SB1:13")
	doc.connect_terminals("SB1:14", "H1:X1")
	doc.add_control_box_for_all()
	assert_true(doc.set_key("SB1", "A"))
	doc.replace_component("SB1", LimitSwitch.new("SQ1", NO))
	assert_true(doc.key_bindings.is_empty(), "a limit switch takes no key")
	assert_eq(doc.control_boxes[0].items[0].designation, "SB1", "the button's item is left without its button")


func test_a_plain_edit_does_not_re_route_wires() -> void:
	var rerouted: Array[String] = []
	for i: int in 3:
		var doc: SchematicDocument = ExampleCircuits.build(i)
		for c: CircuitComponent in doc.circuit.get_components().duplicate():
			var before: Array = _routes(doc)
			doc.page = doc.page_of(c.id)
			doc.replace_component(c.id, DocumentSerializer.component_from_dict(DocumentSerializer.component_to_dict(c)))
			if _routes(doc) != before:
				rerouted.append("example %d, %s" % [i, c.id])
	assert_eq(rerouted, [] as Array[String])


func test_a_deleted_device_leaves_no_key_group_or_link_behind() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PushButton.new("SB1", NO), Vector2i(2, 4))
	doc.set_key("SB1", "A")
	doc.add(Motor.new("M1"), Vector2i(6, 4))
	doc.add(LimitSwitch.new("SQ1", NO), Vector2i(10, 4))
	doc.add_group()
	doc.place_field_device("M1", Vector2(10, 10), 0)
	doc.place_field_device("SQ1", Vector2(100, 10), 0)
	assert_true(doc.set_group_link(0, "M1", 5.0, 0.0, {"SQ1": 1.0}))
	doc.remove_component("SB1")
	doc.remove_component("M1")
	doc.remove_component("SQ1")
	assert_true(doc.key_bindings.is_empty())
	assert_true(doc.field_positions.is_empty())
	assert_eq(doc.groups[0].to_data(), {"name": "G1", "position": [0.0, 0.0], "members": []})
	doc.add(PushButton.new(doc.next_device_designation("SB"), NO), Vector2i(2, 4))
	doc.add(ThreePhaseMotor.new("M1"), Vector2i(6, 4))
	assert_eq(doc.key_bindings.get("SB1", ""), "", "a new SB1 has no key")
	assert_true(Workspace.travels(doc).is_empty(), "a new M1 drives nothing")


func test_a_part_of_two_blocks_keeps_one_place_and_one_key() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Motor.new("M1"), Vector2i(2, 4))
	doc.add(LimitSwitch.new("SQ1", NO), Vector2i(6, 4))
	doc.add(LimitSwitch.new("SQ2", NC), Vector2i(10, 4))
	doc.add(PushButton.new("SB1", NO), Vector2i(14, 4))
	doc.add(PushButton.new("SB2", NC), Vector2i(18, 4))
	doc.set_key("SB1", "A")
	doc.set_key("SB2", "B")
	doc.add_group()
	doc.place_field_device("M1", Vector2(10, 10), 0)
	doc.place_field_device("SQ1", Vector2(100, 10), 0)
	doc.place_field_device("SQ2", Vector2(200, 10), 0)
	doc.set_group_link(0, "M1", 5.0, 0.0, {"SQ1": 1.0, "SQ2": 0.0})
	assert_true(doc.replace_component("SQ2", LimitSwitch.new("SQ1", NC, 2)))
	assert_eq(doc.groups[0].members, PackedStringArray(["M1", "SQ1"]))
	assert_eq(doc.groups[0].stops, {"SQ1": 1.0} as Dictionary[String, float])
	assert_eq(doc.field_positions["SQ1"], Vector2(100, 10))
	assert_true(doc.replace_component("SB2", PushButton.new("SB1", NC, 2)))
	assert_eq(doc.key_bindings, {"SB1": "A"} as Dictionary[String, String])
	doc.place_field_device("SQ1", Vector2(300, 300), -1)
	assert_eq(Workspace.group_of(doc, "SQ1"), -1, "taken out of the group")


func test_dragged_terminal_markings_follow_a_cpu_change() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	var small: CompactPlc = doc.add(CompactPlc.new("A1", null, [], CompactPlc.Cpu.DI6_DQ4), Vector2i(4, 4)) as CompactPlc
	var q0: int = small.get_terminal_names().find("Q0.0")
	doc.set_label_offset("A1", "terminal:%d" % q0, Vector2(1, 1))
	doc.set_label_offset("A1", "designation", Vector2(2, 0))
	var data: Dictionary = DocumentSerializer.component_to_dict(small)
	data["cpu"] = "14di10dq"
	var large: CompactPlc = DocumentSerializer.component_from_dict(data) as CompactPlc
	assert_true(doc.replace_component("A1", large))
	var moved: int = large.get_terminal_names().find("Q0.0")
	assert_ne(moved, q0, "Q0.0 is another terminal on the larger CPU")
	assert_eq(doc.get_placement("A1").labels, {"terminal:%d" % moved: Vector2(1, 1), "designation": Vector2(2, 0)} as Dictionary[String, Vector2])


# --- Turning, wires, paste ---------------------------------------------------------

func test_parts_turn_together_with_an_overload_relay_without_poles() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Lamp.new("H1"), Vector2i(12, 4))
	doc.add(Lamp.new("H2"), Vector2i(16, 4))
	doc.connect_terminals("H1:X2", "H2:X2")
	doc.add(OverloadRelay.new("F1", 5.0, 0), Vector2i(6, 4))
	var ids: PackedStringArray = PackedStringArray(["H1", "F1", "H2"])
	var cells: Array[Vector2i] = [doc.get_placement("H1").cell, doc.get_placement("F1").cell, doc.get_placement("H2").cell]
	doc.mirror_components(ids)
	assert_ne(doc.get_placement("H1").cell, doc.get_placement("H2").cell, "not on top of each other")
	doc.mirror_components(ids)
	for k: int in 4:
		doc.rotate_components(ids)
	assert_eq([doc.get_placement("H1").cell, doc.get_placement("F1").cell, doc.get_placement("H2").cell], cells, "back where they were")


func test_a_second_wire_between_the_same_terminals_is_not_drawn() -> void:
	var doc: SchematicDocument = _editor(_supplies())
	_place({"type": "lamp"}, Vector2i(6, 4))
	_wire("L", "H1:X1")
	_wire("L", "H1:X1")
	_wire("H1:X1", "L")
	assert_eq(doc.get_wire_count(), 1)


func test_a_junction_pasted_without_its_wires_goes() -> void:
	var doc: SchematicDocument = _editor(_supplies())
	_place({"type": "lamp"}, Vector2i(6, 4))
	_place({"type": "lamp"}, Vector2i(10, 4))
	doc.connect_terminals("L", "H1:X1", [Vector2i(6, 1)] as Array[Vector2i])
	var j: String = doc.split_wire(0, Vector2i(4, 1))
	assert_eq(j, "J1")
	doc.connect_terminals(j, "H2:X1")
	editor._clear_selection()
	editor.selected_components[j] = true
	editor.copy_selection()
	_at(Vector2(20, 20))
	editor.paste()
	var junctions: int = 0
	for c: CircuitComponent in doc.circuit.get_components():
		if c is Junction:
			junctions += 1
			assert_gte(doc.circuit.wires_of(c).size(), 3, c.id)
	assert_eq(junctions, 1)


# --- Workspace ---------------------------------------------------------------------

func test_a_part_leaving_its_group_leaves_the_link() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Motor.new("M1"), Vector2i(2, 4))
	doc.add(LimitSwitch.new("SQ1", NO), Vector2i(6, 4))
	doc.add_group()
	doc.place_field_device("M1", Vector2(10, 10), 0)
	doc.place_field_device("SQ1", Vector2(100, 10), 0)
	doc.set_group_link(0, "M1", 5.0, 0.0, {"SQ1": 1.0})
	doc.place_field_device("SQ1", Vector2(700, 600), -1)
	assert_true(doc.groups[0].stops.is_empty())
	doc.place_field_device("M1", Vector2(600, 600), -1)
	assert_eq(doc.groups[0].drive, "")
	doc.place_field_device("M1", Vector2(10, 10), 0)
	assert_true(Workspace.travels(doc).is_empty(), "back in the group, it drives nothing until linked again")


func test_a_new_place_keeps_off_a_group_frame() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	for k: int in 4:
		doc.add(Motor.new("M%d" % (k + 1)), Vector2i(2 + 4 * k, 4))
	doc.add_group(Vector2.ZERO)
	doc.groups[0].members = PackedStringArray(["M1", "M2", "M3", "M4"])
	var frame: Rect2 = Workspace.group_rect(doc.groups[0], Workspace.field_positions(doc))
	assert_false(frame.intersects(Rect2(doc.free_spot(), Workspace.PLACE_SIZE)))
	doc.place_field_device("M1", Vector2(0, -300), 0)
	frame = Workspace.group_rect(doc.groups[0], Workspace.field_positions(doc))
	assert_eq(doc.free_spot().y, frame.position.y, "level with the frame's top")


func test_a_renamed_cable_between_field_parts_keeps_its_name_when_one_is_moved() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Motor.new("M1"), Vector2i(2, 4))
	doc.add(LimitSwitch.new("SQ1", NO), Vector2i(6, 4))
	doc.connect_terminals("M1:" + doc.circuit.get_component("M1").get_terminal_names()[0], "SQ1:13")
	doc.name_cables()
	var key: String = WorkspaceCables.cables(doc)[0]["key"]
	assert_true(doc.rename_cable(key, "WLOOP"))
	doc.place_field_device("SQ1", Vector2(500, 300))
	doc.name_cables()
	assert_eq(WorkspaceCables.cables(doc)[0]["name"], "WLOOP")


# --- Files -------------------------------------------------------------------------

func test_wrongly_typed_values_load_with_defaults() -> void:
	var d: Dictionary = JSON.parse_string(JSON.stringify(ProjectFile.to_dict(ExampleCircuits.build(2))))
	var document: Dictionary = d["document"]
	document["horizontal"] = null
	document["switching"] = {}
	document["pages"] = [1]
	document["page"] = "1"
	document["components"][1]["rotation"] = [1]
	document["components"][1]["mirrored"] = "yes"
	document["wires"][0]["number"] = {"a": 1}
	for c: Dictionary in document["components"]:
		match c["type"]:
			"timer":
				c["delay"] = []
				c["control_input"] = "yes"
			"motor3":
				c["terminal_box"] = "x"
				c["show_plate"] = []
			"coil":
				c["kind"] = []
	var result: Dictionary = ProjectFile.from_dict(d)
	assert_true(result.has("document"), "loaded")
	var doc: SchematicDocument = result["document"]
	assert_false(doc.horizontal)
	assert_eq(doc.pages, PackedStringArray([""]))
	assert_eq(doc.get_route(0).number, "")


func test_time_relay_times_are_held_within_limits() -> void:
	var zero: TimerRelay = DocumentSerializer.component_from_dict({"type": "timer", "designation": "KT1", "mode": "cycle_pause_first", "delay": 0, "delay2": 0}) as TimerRelay
	assert_eq([zero.delay, zero.delay2], [DocumentSerializer.SHORTEST_DELAY, DocumentSerializer.SHORTEST_DELAY])
	var long: TimerRelay = DocumentSerializer.component_from_dict({"type": "timer", "designation": "KT1", "mode": "on_delay", "delay": 1e9, "delay2": 1e9}) as TimerRelay
	assert_eq([long.delay, long.delay2], [DocumentSerializer.LONGEST_DELAY, DocumentSerializer.LONGEST_DELAY])


func test_inverter_frequencies_survive_a_lower_maximum() -> void:
	var drive: Vfd = DocumentSerializer.component_from_dict({"type": "vfd", "designation": "TA1", "max_frequency": 30, "fixed_frequency": 40, "keypad_frequency": 50}) as Vfd
	var data: Dictionary = DocumentSerializer.component_to_dict(drive)
	data["max_frequency"] = 50
	drive = DocumentSerializer.component_from_dict(data) as Vfd
	assert_eq([drive.fixed_frequency, drive.keypad_frequency], [40.0, 50.0])


func test_a_crossed_temperature_range_keeps_its_lower_bound() -> void:
	var sensor: TemperatureSensor = DocumentSerializer.component_from_dict({"type": "temp_sensor", "designation": "BT1", "range_min": 60, "range_max": 50}) as TemperatureSensor
	assert_eq([sensor.range_min, sensor.range_max], [60.0, 61.0])
	var top: TemperatureSensor = DocumentSerializer.component_from_dict({"type": "temp_sensor", "designation": "BT1", "range_min": TemperatureSensor.HIGHEST, "range_max": 0}) as TemperatureSensor
	assert_eq([top.range_min, top.range_max], [TemperatureSensor.HIGHEST - 1.0, TemperatureSensor.HIGHEST])


func test_a_failed_save_keeps_the_file_saved_before() -> void:
	assert_eq(ProjectFile.save(ExampleCircuits.build(0), PATH), OK)
	var saved: String = FileAccess.get_file_as_string(PATH)
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "nothing left beside it")
	# The temporary file cannot be written: a directory is in its way.
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	assert_ne(ProjectFile.save(ExampleCircuits.build(1), PATH), OK)
	DirAccess.remove_absolute(PATH + ".tmp")
	assert_eq(FileAccess.get_file_as_string(PATH), saved)
	assert_true(ProjectFile.load_file(PATH).has("document"))
