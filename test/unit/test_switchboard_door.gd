extends GutTest
## The door of a switchboard: push buttons, switches and lamps on it like on
## a control station, saved with the switchboard, part of its place for the
## cables, wired inside through the door harness, drawn and operated.

const ExamplePower = preload("res://test/unit/example_power.gd")

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC


## An example with a switchboard and a station: the station's items moved
## onto the switchboard's door.
func _door_example() -> SchematicDocument:
	var doc: SchematicDocument = ExampleCircuits.build(9)
	doc.switchboards[0].door.items = doc.control_boxes[0].items
	doc.control_boxes.clear()
	doc.name_cables()
	return doc


func test_door_panels_are_edited_like_stations() -> void:
	var doc: SchematicDocument = SchematicDocument.new("door")
	doc.add(PushButton.new("SB1", NO), Vector2i(0, 0))
	doc.add(LatchingSwitch.new("RB1", NO), Vector2i(4, 0))
	doc.add(Lamp.new("H1"), Vector2i(8, 0))
	doc.add_control_box("Station")
	doc.add_switchboard()
	assert_eq(doc.control_panels().size(), 2, "the station, then the door")
	var door: int = doc.door_panel(0)
	assert_eq(door, 1)
	assert_eq(doc.door_panel(1), -1, "no such switchboard")
	assert_eq(doc.switchboards[0].door.columns, Switchboard.DOOR_COLUMNS)
	assert_eq(doc.add_control_item(door, ControlBoxItem.Kind.BUTTON).designation, "SB1")
	assert_eq(doc.add_control_item(0, ControlBoxItem.Kind.BUTTON).designation, "", "SB1 is on the door already")
	assert_eq(doc.fill_control_box(door), 2, "the switch and the lamp go on the door too")
	assert_true(doc.control_panel_devices().has("H1"))
	assert_true(Workspace.unplaced(doc).is_empty(), "nothing left without a place")
	assert_eq(Workspace.door_of(doc, "RB1"), 0)
	assert_eq(Workspace.station_of(doc, "RB1"), -1)
	doc.move_control_item(door, 2, -2)
	assert_eq(doc.switchboards[0].door.items[0].designation, "H1")
	doc.set_control_box(door, "ignored", 2)
	assert_eq(doc.switchboards[0].door.columns, 2)
	assert_eq(doc.switchboards[0].door.title, "", "a door has no text of its own")
	doc.remove_control_item(door, 0)
	assert_eq(doc.switchboards[0].door.items.size(), 2)
	# Renaming a device renames its item on the door.
	var button: PushButton = doc.circuit.get_component("SB1") as PushButton
	var data: Dictionary = DocumentSerializer.component_to_dict(button)
	data["designation"] = "SB7"
	assert_true(doc.replace_component(button.id, DocumentSerializer.component_from_dict(data)))
	assert_eq(doc.switchboards[0].door.items[0].designation, "SB7")


func test_door_saved_with_its_switchboard() -> void:
	var doc: SchematicDocument = _door_example()
	var loaded: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	var door: ControlBox = loaded.switchboards[0].door
	assert_eq(door.items.size(), doc.switchboards[0].door.items.size())
	assert_eq(door.items[0].designation, doc.switchboards[0].door.items[0].designation)
	assert_eq(door.items[0].color, doc.switchboards[0].door.items[0].color)
	var empty: Dictionary = Switchboard.new("RA2").to_data()
	assert_false(empty.has("door"), "an empty door is not saved")
	assert_eq(Switchboard.from_data(empty).door.columns, Switchboard.DOOR_COLUMNS)


func test_door_items_are_in_the_switchboard_for_the_cables() -> void:
	var doc: SchematicDocument = _door_example()
	for cable: Dictionary in WorkspaceCables.cables(doc):
		for end: String in [cable["a"], cable["b"]]:
			assert_false(end.begins_with("+ST"), "no station any more")
		assert_ne(cable["b"], "+RA1", "no cable from the switchboard to its own door")
	var names: PackedStringArray = PackedStringArray()
	for cable: Dictionary in WorkspaceCables.cables(doc):
		names.append("%s|%s" % [cable["a"], cable["b"]])
	assert_eq(names, PackedStringArray(["+RA1|-M1"]), "only the motor cable is left")


func test_door_harness_inside_the_switchboard() -> void:
	var doc: SchematicDocument = _door_example()
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	var cores: int = 0
	for wire: Dictionary in wiring.wires:
		if wire["external"] and wire["cable"] == CabinetWiring.DOOR:
			cores += 1
	assert_gt(cores, 0, "the strip terminals to the door's devices send their cores to the door")
	var harness: Array[Dictionary] = []
	for gland: Dictionary in wiring.glands:
		if gland["door"]:
			harness.append(gland)
	assert_eq(harness.size(), 1, "one door harness")
	assert_false(harness[0]["bottom"], "not out through the bottom of the enclosure")
	var fitting: Rect2 = harness[0]["rect"]
	assert_gt(fitting.end.x, layout.size.x - CabinetLayout.FRAME, "its fitting is in the right wall, the door's hinge side")
	for wire: Dictionary in wiring.wires:
		if wire["external"] and wire["cable"] == CabinetWiring.DOOR:
			var points: PackedVector2Array = wire["points"]
			assert_true(fitting.has_point(points[0] + Vector2(0.5, 0.0)), "each core starts at the fitting")
			for point: Vector2 in points:
				assert_true(Rect2(Vector2.ZERO, layout.size).has_point(point), "and stays inside the enclosure")
	assert_gt(CabinetWiring.bottom_slots(doc, 0, CabinetDevices.strips(doc)), 0)


func test_parts_list_and_tree_show_the_door() -> void:
	var doc: SchematicDocument = _door_example()
	var rows: Array[Dictionary] = PartsList.new().rows(doc)
	var under_board: bool = false
	var in_board: bool = false
	for row: Dictionary in rows:
		if row.get("heading", false):
			in_board = str(row["text"]).begins_with("+RA1")
		elif in_board and str(row.get("designation", "")).contains("SB"):
			under_board = true
	assert_true(under_board, "the door's buttons are listed under the switchboard")


func test_door_drawn_and_operated() -> void:
	var doc: SchematicDocument = ExamplePower.on(_door_example())
	doc.realistic_timing = false
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(doc)
	var panel: CabinetPanel = CabinetPanel.new()
	panel.board_name = "RA1"
	add_child_autofree(panel)
	panel.size = Vector2(900, 700)
	var held: Array = []
	panel.button_held.connect(func(designation: String, pressed: bool) -> void:
		held.append([designation, pressed])
		view.hold_button(designation, pressed))
	panel.set_document(view.document, false)
	panel.door_shown = true
	await wait_process_frames(3)
	var door: DoorView = panel.get("_door")
	assert_true(door.visible, "the door is shown in place of the inside")
	assert_eq(door.box(), view.document.switchboards[0].door)
	door.size = Vector2(600, 600)
	var cells: Array[Rect2] = door._cells()
	assert_eq(cells.size(), doc.switchboards[0].door.items.size())
	var start: int = -1
	for i: int in doc.switchboards[0].door.items.size():
		var item: ControlBoxItem = doc.switchboards[0].door.items[i]
		var c: CircuitComponent = view.document.circuit.get_operator(item.designation)
		if c is PushButton and (c as PushButton).contact_type == NO:
			start = i
			break
	assert_gt(start, -1)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = door._knob_of(cells[start])
	door._gui_input(press)
	assert_eq(held.size(), 1, "a click on the door holds its button")
	assert_true(held[0][1])
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	door._gui_input(release)
	assert_eq(held.size(), 2)
	assert_false(held[1][1])
	# Edit mode: the tools edit the door as one workspace edit.
	var edits: Array[Callable] = []
	panel.door_edit_requested.connect(func(change: Callable) -> void: edits.append(change))
	panel.set_document(doc, true)
	await wait_process_frames(2)
	door.item_clicked.emit(0)
	await wait_process_frames(2)
	var list: VBoxContainer = panel.get("_list")
	var remove: Button = null
	for button: Button in list.find_children("*", "Button", true, false):
		if button.text == "Remove":
			remove = button
	assert_not_null(remove, "the selected item's fields are shown")
	remove.pressed.emit()
	assert_eq(edits.size(), 1)
	var count: int = doc.switchboards[0].door.items.size()
	edits[0].call(doc)
	assert_eq(doc.switchboards[0].door.items.size(), count - 1)


func test_back_of_the_door_is_wired_from_the_harness() -> void:
	var doc: SchematicDocument = _door_example()
	var harness: Array[Dictionary] = CabinetWiring.door_harness(doc, 0)
	assert_gt(harness.size(), 0, "the strip terminals to the door's devices send a core each to the door")
	var enclosure: Vector2 = CabinetLayout.build(doc, 2.0).size
	var back: StationInside = StationInside.build_door(doc, 0, enclosure, 560.0)
	assert_true(back.door)
	assert_eq(back.size, DoorView.size_of(doc.switchboards[0].door, enclosure), "the door's own size")
	# Seen from behind the items are mirrored: the first one of a row on the right.
	var front: Array[Rect2] = DoorView.cells_of(doc.switchboards[0].door, enclosure)
	for entry: Dictionary in back.items:
		var cell: Rect2 = front[entry["item"]]
		assert_almost_eq((entry["center"] as Vector2).x, back.size.x - cell.get_center().x, 0.01)
	var cores: int = 0
	var entries: Array[Vector2] = []
	for key: String in back.terminals:
		entries.append(back.terminals[key]["entry"])
	for wire: Dictionary in back.wires:
		var points: PackedVector2Array = wire["points"]
		assert_has(entries, points[points.size() - 1], "every wire goes straight into a contact")
		if wire["external"]:
			cores += 1
			assert_lt(points[0].x, StationInside.FRAME + 2.0, "harness cores come in through the hinge edge")
			assert_true((back.glands[0]["rect"] as Rect2).grow(0.5).has_point(points[0]), "out of its fitting")
	assert_eq(cores, harness.size(), "a core for each of the harness's nets")
	assert_almost_eq((back.glands[0]["rect"] as Rect2).get_center().y, 560.0, 0.01, "at the height it leaves the switchboard")


func test_door_open_beside_the_switchboard() -> void:
	var doc: SchematicDocument = _door_example()
	var view: CabinetView = CabinetView.new()
	view.document = doc
	add_child_autofree(view)
	view.size = Vector2(800, 600)
	view.refresh()
	var closed: Vector2 = view.drawn_size()
	view.door_open = true
	await wait_process_frames(2)
	var opened: Vector2 = view.drawn_size()
	assert_gt(opened.x / opened.y, closed.x / closed.y * 1.5, "the door beside the switchboard")
	assert_not_null(view.get("_door"), "the back of the door laid out")
	var panel: CabinetPanel = CabinetPanel.new()
	panel.board_name = "RA1"
	add_child_autofree(panel)
	panel.set_document(doc, true)
	panel.door_open = true
	await wait_process_frames(2)
	assert_true((panel.get("_view") as CabinetView).door_open)
	assert_false(panel.door_shown)
	panel.door_shown = true
	assert_false(panel.door_open, "one at a time")


func test_harness_cores_carry_their_wire_numbers() -> void:
	var doc: SchematicDocument = _door_example()
	doc.number_wires()
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var cores: int = 0
	for wire: Dictionary in layout.wiring.wires:
		if wire["external"] and wire["cable"] == CabinetWiring.DOOR:
			cores += 1
			assert_false(str(wire["mark"]).is_empty(), "a numbered net")
			var start: Vector2 = (wire["points"] as PackedVector2Array)[0]
			var at_fitting: bool = false
			for span: PackedVector2Array in wire["markers"]:
				# On its first run, out of the fitting (moved along it off the others).
				at_fitting = at_fitting or (is_equal_approx(span[0].y, start.y) and span[0].x > layout.size.x * 0.5)
			assert_true(at_fitting, "a sleeve where the core comes out of the fitting in the wall")
	assert_gt(cores, 0)
	var back: StationInside = StationInside.build_door(doc, 0, layout.size, 560.0)
	for wire: Dictionary in back.wires:
		if wire["external"]:
			var start: Vector2 = (wire["points"] as PackedVector2Array)[0]
			var at_fitting: bool = false
			for span: PackedVector2Array in wire["markers"]:
				at_fitting = at_fitting or span[0].distance_to(start) < 12.0
			assert_true(at_fitting, "and where it comes out of the fitting in the door's edge")
