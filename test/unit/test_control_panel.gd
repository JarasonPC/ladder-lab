extends GutTest
## Control boxes of the operator panel: editing them in the document, saving,
## following renamed devices, and operating the circuit through them.

const ExamplePower = preload("res://test/unit/example_power.gd")

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC


func _doc() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("panel")
	doc.add(PushButton.new("SB0", NC), Vector2i(0, 0))
	doc.add(PushButton.new("SB1", NO, 1), Vector2i(4, 0))
	doc.add(PushButton.new("SB1", NC, 2), Vector2i(8, 0))
	doc.add(LatchingSwitch.new("RB1", NO), Vector2i(12, 0))
	doc.add(LimitSwitch.new("SQ1", NO), Vector2i(16, 0))
	doc.add(Lamp.new("H1"), Vector2i(20, 0))
	doc.add(Coil.new("KM1"), Vector2i(24, 0))
	return doc


func test_devices_by_kind() -> void:
	var doc: SchematicDocument = _doc()
	assert_eq(doc.control_devices(ControlBoxItem.Kind.BUTTON), PackedStringArray(["SB0", "SB1"]), "each button once, blocks share it")
	assert_eq(doc.control_devices(ControlBoxItem.Kind.SWITCH), PackedStringArray(["RB1"]), "limit switches are worked by the machine")
	assert_eq(doc.control_devices(ControlBoxItem.Kind.LAMP), PackedStringArray(["H1"]))


func test_new_items_take_the_next_free_device() -> void:
	var doc: SchematicDocument = _doc()
	doc.add_control_box("Panel", 2)
	assert_eq(doc.add_control_item(0, ControlBoxItem.Kind.BUTTON).designation, "SB0")
	assert_eq(doc.add_control_item(0, ControlBoxItem.Kind.BUTTON).designation, "SB1")
	assert_eq(doc.add_control_item(0, ControlBoxItem.Kind.BUTTON).designation, "", "no button left")
	assert_eq(doc.add_control_item(0, ControlBoxItem.Kind.SWITCH).color, "black")
	assert_eq(doc.control_boxes[0].items.size(), 4)
	assert_null(doc.add_control_item(3, ControlBoxItem.Kind.LAMP), "no such box")


func test_box_for_all_devices() -> void:
	var doc: SchematicDocument = _doc()
	var lamp: Lamp = doc.circuit.get_component("H1") as Lamp
	lamp.purpose = "Running"
	var box: ControlBox = doc.add_control_box_for_all()
	var names: PackedStringArray = PackedStringArray()
	for item: ControlBoxItem in box.items:
		names.append("%s %s %s" % [ControlBoxItem.KINDS[item.kind], item.designation, item.color])
	assert_eq(names, PackedStringArray(["button SB0 red", "button SB1 green", "switch RB1 black", "lamp H1 green"]), "a button that only breaks is a red stop button")
	assert_eq(box.items[3].label, "Running", "a lamp shows its purpose")
	assert_null(doc.add_control_box_for_all(), "everything is on the panel already")


func test_move_remove_and_set_items() -> void:
	var doc: SchematicDocument = _doc()
	doc.add_control_box()
	doc.add_control_item(0, ControlBoxItem.Kind.BUTTON)
	doc.add_control_item(0, ControlBoxItem.Kind.LAMP)
	doc.move_control_item(0, 1, -1)
	assert_eq(doc.control_boxes[0].items[0].designation, "H1")
	doc.move_control_item(0, 0, -5)
	assert_eq(doc.control_boxes[0].items[0].designation, "H1", "clamped")
	var data: Dictionary = doc.control_boxes[0].items[1].to_data()
	data["label"] = "Stop"
	data["color"] = "red"
	data["lamp"] = "H1"
	assert_true(doc.set_control_item(0, 1, data))
	var item: ControlBoxItem = doc.control_boxes[0].items[1]
	assert_eq([item.label, item.color, item.lamp], ["Stop", "red", "H1"])
	assert_false(doc.set_control_item(0, 1, {"kind": "rocket"}), "malformed data is refused")
	doc.remove_control_item(0, 0)
	assert_eq(doc.control_boxes[0].items.size(), 1)
	doc.add_control_box("second")
	assert_eq(doc.control_boxes[1].name, "ST2", "stations are named in turn")
	doc.set_control_box(1, "  Main  ", 9)
	assert_eq([doc.control_boxes[1].title, doc.control_boxes[1].columns], ["Main", ControlBox.MAX_COLUMNS])
	doc.remove_place(Workspace.Place.STATION, 0)
	assert_eq(doc.control_boxes.size(), 1)
	assert_eq(doc.control_boxes[0].title, "Main")


func test_lamp_items_have_no_lamp_under_them_or_black_lens() -> void:
	var item: ControlBoxItem = ControlBoxItem.from_data({"kind": "lamp", "designation": "H1", "color": "black", "lamp": "H2"})
	assert_eq(item.color, "green")
	assert_eq(item.lamp, "")
	assert_eq(ControlBoxItem.from_data({"kind": "button", "color": "black", "lamp": "H1"}).color, "white", "a lit cap is never black")
	assert_null(ControlBoxItem.from_data("nope"))
	assert_eq(ControlBoxItem.from_data({"kind": "button", "designation": "S:1"}).designation, "", "unusable designation")


func test_saved_and_loaded() -> void:
	var doc: SchematicDocument = _doc()
	var box: ControlBox = doc.add_control_box("Machine 1", 2)
	doc.add_control_item(0, ControlBoxItem.Kind.BUTTON)
	box.items[0].label = "Start"
	box.items[0].lamp = "H1"
	doc.add_control_item(0, ControlBoxItem.Kind.SWITCH)
	var data: Dictionary = DocumentSerializer.to_dict(doc)
	var copy: SchematicDocument = DocumentSerializer.from_dict(data)
	assert_eq(DocumentSerializer.to_dict(copy), data)
	assert_eq(copy.control_boxes[0].title, "Machine 1")
	assert_eq(copy.control_boxes[0].items[0].lamp, "H1")
	var text: String = JSON.stringify({"format": ProjectFile.FORMAT, "version": ProjectFile.VERSION, "document": data})
	var loaded: SchematicDocument = ProjectFile.parse(text)["document"]
	assert_eq(DocumentSerializer.to_dict(loaded), data, "the same after a save as JSON")


func test_older_files_and_damaged_boxes() -> void:
	var text: String = '{"format": "ladder-lab", "version": 9, "document": {"components": [{"type": "lamp", "designation": "H1", "cell": [0, 0]}], "wires": []}}'
	assert_true(ProjectFile.parse(text)["document"].control_boxes.is_empty(), "version 9 has no boxes")
	text = '{"format": "ladder-lab", "version": 10, "document": {"components": [], "wires": [], "control_boxes": ["x", {"columns": "two", "items": [{"kind": "lamp", "designation": "H1"}, 5]}]}}'
	var doc: SchematicDocument = ProjectFile.parse(text)["document"]
	assert_eq(doc.control_boxes.size(), 1, "malformed boxes are left out")
	assert_eq(doc.control_boxes[0].columns, 1)
	assert_eq(doc.control_boxes[0].items.size(), 1, "malformed items are left out")


func test_renaming_a_device_renames_its_items() -> void:
	var doc: SchematicDocument = _doc()
	doc.add_control_box()
	doc.add_control_item(0, ControlBoxItem.Kind.BUTTON)
	doc.add_control_item(0, ControlBoxItem.Kind.BUTTON)
	doc.control_boxes[0].items[0].lamp = "H1"
	doc.replace_component("H1", Lamp.new("H7"))
	assert_eq(doc.control_boxes[0].items[0].lamp, "H7")
	doc.replace_component("SB0", PushButton.new("SB5", NC))
	assert_eq(doc.control_boxes[0].items[0].designation, "SB5")
	doc.replace_component("SB1:13-14", PushButton.new("SB6", NO, 1))
	assert_eq(doc.control_boxes[0].items[1].designation, "SB1", "SB1 still has its other block")
	doc.replace_component("SB1:21-22", PushButton.new("SB6", NC, 2))
	assert_eq(doc.control_boxes[0].items[1].designation, "SB6", "the whole button was renamed")


func test_examples_have_a_control_box() -> void:
	for index: int in ExampleCircuits.count():
		var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.build(index))
		var devices: int = 0
		for kind: int in 3:
			devices += doc.control_devices(kind).size()
		assert_eq(doc.control_boxes.is_empty(), devices == 0, doc.title)
	var forward_reverse: SchematicDocument = ExamplePower.on(ExampleCircuits.forward_reverse())
	var items: Array[ControlBoxItem] = forward_reverse.control_boxes[0].items
	assert_eq([items[0].label, items[0].lamp, items[2].color], ["Forward", "H1", "red"])


func test_control_box_operates_the_simulation() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.build(1))
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(doc, true)
	var h1: Lamp = doc.circuit.get_component("H1") as Lamp
	view.set_realistic_timing(false)
	assert_false(h1.energized)
	view.hold_button("SB1", true)
	view.hold_button("SB1", false)
	assert_true(h1.energized, "forward runs and holds itself, its lamp is lit")
	view.hold_button("SB0", true)
	assert_false(h1.energized, "stop")
	view.hold_button("SB0", false)
	view.hold_button("KM1", true)
	assert_false(h1.energized, "only push buttons are held")


func test_control_box_switch_toggles() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.build(2))
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(doc, true)
	var rb1: LatchingSwitch = doc.circuit.get_component("RB1") as LatchingSwitch
	view.toggle_switch("RB1")
	assert_true(rb1.switched_on)
	view.toggle_switch("RB1")
	assert_false(rb1.switched_on)
