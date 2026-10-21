extends GutTest
## The workspace: switchboards, control stations and groups with their names
## and places, the parts in the field, what has no place yet, saving and
## loading (also older files with one switchboard).

const NO := SwitchingElement.ContactType.NO


func _doc() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("workspace")
	doc.add(Coil.new("KM1"), Vector2i(0, 0))
	doc.add(PushButton.new("SB1", NO), Vector2i(4, 0))
	doc.add(ThreePhaseMotor.new("M1"), Vector2i(8, 0))
	doc.add(LimitSwitch.new("SQ1", NO), Vector2i(16, 0))
	doc.add(LimitSwitch.new("SQ2", NO), Vector2i(20, 0))
	doc.add(TemperatureSensor.new("BT1"), Vector2i(24, 0))
	doc.add(Lamp.new("H1"), Vector2i(28, 0))
	return doc


func test_parts_in_the_field() -> void:
	var doc: SchematicDocument = _doc()
	assert_eq(Workspace.field_devices(doc.circuit), PackedStringArray(["M1", "SQ1", "SQ2", "BT1"]), "motors, limit switches and sensors")
	assert_eq(Workspace.field_kind(doc.circuit.get_component("M1")), Workspace.Field.MOTOR)
	assert_eq(Workspace.field_kind(doc.circuit.get_component("BT1")), Workspace.Field.SENSOR)
	assert_eq(Workspace.field_kind(doc.circuit.get_component("KM1")), Workspace.Field.NONE)
	var positions: Dictionary[String, Vector2] = Workspace.field_positions(doc)
	assert_eq(positions.size(), 4, "each has a place before it is put anywhere")
	assert_ne(positions["M1"], positions["SQ1"], "side by side")


func test_places_are_named_in_turn() -> void:
	var doc: SchematicDocument = _doc()
	assert_eq(doc.add_switchboard().name, "RA1")
	assert_eq(doc.add_switchboard().name, "RA2")
	assert_eq(doc.add_control_box().name, "ST1")
	assert_eq(doc.add_group().name, "G1")
	assert_ne(doc.switchboards[0].position, doc.switchboards[1].position, "a new place goes to a free spot")
	assert_true(doc.switchboards[1].position.x >= doc.switchboards[0].position.x + Workspace.PLACE_SIZE.x)
	doc.remove_place(Workspace.Place.SWITCHBOARD, 0)
	assert_eq(doc.next_place_name(Workspace.Place.SWITCHBOARD), "RA1", "the first free number")


func test_rename_places() -> void:
	var doc: SchematicDocument = _doc()
	doc.add_switchboard()
	doc.add_control_box()
	assert_true(doc.rename_place(Workspace.Place.STATION, 0, "+ST7", "  Gate, inside "))
	assert_eq([doc.control_boxes[0].name, doc.control_boxes[0].title], ["ST7", "Gate, inside"])
	assert_false(doc.rename_place(Workspace.Place.STATION, 0, "RA1", ""), "another place has the name")
	assert_false(doc.rename_place(Workspace.Place.STATION, 0, "S T", ""), "no spaces")
	assert_false(doc.rename_place(Workspace.Place.STATION, 0, "", ""), "not empty")
	assert_true(doc.rename_place(Workspace.Place.SWITCHBOARD, 0, "RA1", "Main"), "its own name again")
	assert_eq(doc.switchboards[0].title, "Main")


func test_groups_take_their_members_along() -> void:
	var doc: SchematicDocument = _doc()
	var group: WorkspaceGroup = doc.add_group(Vector2(0, 300))
	doc.place_field_device("M1", Vector2(40, 340), 0)
	doc.place_field_device("SQ1", Vector2(200, 340), 0)
	assert_eq(group.members, PackedStringArray(["M1", "SQ1"]))
	var frame: Rect2 = Workspace.group_rect(group, Workspace.field_positions(doc))
	assert_true(frame.has_point(Vector2(40, 340)) and frame.has_point(Vector2(200, 340) + Workspace.FIELD_SIZE - Vector2.ONE), "the frame is round its members")
	doc.move_place(Workspace.Place.GROUP, 0, frame.position + Vector2(100, 50))
	assert_eq(doc.field_positions["M1"], Vector2(140, 390), "members move with the group")
	assert_eq(doc.field_positions["SQ1"], Vector2(300, 390))
	doc.place_field_device("SQ1", Vector2(600, 0), -1)
	assert_eq(group.members, PackedStringArray(["M1"]), "taken out of the group")
	doc.place_field_device("KM1", Vector2(0, 0), 0)
	assert_false(doc.field_positions.has("KM1"), "only parts in the field")
	doc.remove_place(Workspace.Place.GROUP, 0)
	assert_eq(doc.field_positions["M1"], Vector2(140, 390), "its parts stay where they are")


func test_group_frame_resized() -> void:
	var doc: SchematicDocument = _doc()
	var group: WorkspaceGroup = doc.add_group(Vector2(0, 300))
	doc.place_field_device("M1", Vector2(40, 340), 0)
	var fit: Rect2 = Workspace.group_rect(group, Workspace.field_positions(doc))
	doc.set_group_size(0, Vector2(500, 300))
	var frame: Rect2 = Workspace.group_rect(group, Workspace.field_positions(doc))
	assert_eq(frame, Rect2(fit.position, Vector2(500, 300)), "larger from the corner round its members")
	doc.set_group_size(0, Vector2(500, 10))
	assert_eq(group.size, Vector2(500, fit.size.y), "never smaller than round its members")
	doc.set_group_size(0, fit.size - Vector2(20, 20))
	assert_eq(group.size, Vector2.ZERO, "as small as round its members: just round them again")
	doc.set_group_size(0, Vector2(9000, 9000))
	assert_eq(group.size, WorkspaceGroup.MAX_SIZE)
	doc.set_group_size(0, Vector2(500, 300))
	doc.place_field_device("SQ1", Vector2(800, 340), 0)
	assert_eq(Workspace.group_rect(group, Workspace.field_positions(doc)).end.x, 800 + Workspace.FIELD_SIZE.x + Workspace.GROUP_PAD, "a member beyond it widens it")
	var empty: WorkspaceGroup = doc.add_group(Vector2(0, 900))
	doc.set_group_size(1, Vector2(400, 200))
	assert_eq(Workspace.group_rect(empty, Workspace.field_positions(doc)), Rect2(Vector2(0, 900), Vector2(400, 200)), "an empty frame too")
	var data: Dictionary = JSON.parse_string(JSON.stringify(DocumentSerializer.to_dict(doc)))
	assert_eq(DocumentSerializer.from_dict(data).groups[1].size, Vector2(400, 200), "saved and loaded")
	data["groups"][1]["size"] = [-5, 100]
	assert_eq(DocumentSerializer.from_dict(data).groups[1].size, Vector2.ZERO, "a wrong size is left out")


func test_renamed_part_keeps_its_place() -> void:
	var doc: SchematicDocument = _doc()
	doc.add_group()
	doc.place_field_device("M1", Vector2(8, 8), 0)
	doc.replace_component("M1", ThreePhaseMotor.new("M2"))
	assert_eq(doc.field_positions.get("M2"), Vector2(8, 8))
	assert_eq(doc.groups[0].members, PackedStringArray(["M2"]))


func test_unplaced() -> void:
	var doc: SchematicDocument = _doc()
	var missing: Array[Dictionary] = Workspace.unplaced(doc)
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in missing:
		names.append("%s %s" % [entry["kind"], entry["designation"]])
	assert_eq(names, PackedStringArray(["device KM1", "control SB1", "control H1"]))
	doc.add_switchboard()
	doc.fill_cabinet(0)
	doc.add_control_box_for_all()
	assert_true(Workspace.unplaced(doc).is_empty())
	assert_eq(Workspace.switchboard_of(doc, CabinetItem.Kind.DEVICE, "KM1"), 0)
	assert_eq(Workspace.station_of(doc, "H1"), 0)


func test_two_switchboards_share_out_the_devices() -> void:
	var doc: SchematicDocument = _doc()
	doc.add(Coil.new("KA1"), Vector2i(32, 0))
	doc.add_switchboard()
	doc.add_switchboard()
	doc.add_cabinet_rail(1)
	assert_not_null(doc.add_cabinet_item(1, 0, CabinetItem.Kind.DEVICE, "KA1"))
	assert_null(doc.add_cabinet_item(0, 0, CabinetItem.Kind.DEVICE, "KA1"), "one place in all switchboards")
	assert_eq(doc.fill_cabinet(0), 1, "the rest goes into the first")
	assert_eq(doc.switchboards[0].rails[0].items[0].designation, "KM1")
	assert_eq(CabinetLayout.build(doc, 2.0, 1).places.size(), 1, "each switchboard is laid out on its own")
	assert_eq(CabinetLayout.build(doc, 2.0, 5).places.size(), 0, "no such switchboard")


func test_saved_and_loaded() -> void:
	var doc: SchematicDocument = _doc()
	doc.add_switchboard().title = "Main"
	doc.add_control_box("Gate, inside").position = Vector2(300, 0)
	doc.add_group().title = "Gate"
	doc.place_field_device("M1", Vector2(10, 400), 0)
	var data: Dictionary = DocumentSerializer.to_dict(doc)
	var copy: SchematicDocument = DocumentSerializer.from_dict(data)
	assert_eq(DocumentSerializer.to_dict(copy), data)
	assert_eq([copy.switchboards[0].name, copy.switchboards[0].title], ["RA1", "Main"])
	assert_eq([copy.control_boxes[0].name, copy.control_boxes[0].position], ["ST1", Vector2(300, 0)])
	assert_eq(copy.groups[0].members, PackedStringArray(["M1"]))
	assert_eq(copy.field_positions["M1"], Vector2(10, 400))
	# As read from a file: plain arrays and dictionaries.
	data = JSON.parse_string(JSON.stringify(data))
	data["field"]["KM1"] = [1, 2]
	data["groups"].append(5)
	data["switchboards"].append({"name": "RA1", "rails": []})
	var loaded: SchematicDocument = DocumentSerializer.from_dict(data)
	assert_false(loaded.field_positions.has("KM1"), "only parts in the field have a place")
	assert_eq(loaded.groups.size(), 1, "malformed groups are left out")
	assert_eq(loaded.switchboards[1].name, "RA2", "a name used twice is given anew")


func test_older_file_gets_a_workspace() -> void:
	var text: String = '{"format": "ladder-lab", "version": 23, "document": {"components": [{"type": "coil", "designation": "KM1", "cell": [0, 0]}], "wires": [], "control_boxes": [{"columns": 1, "items": []}, {"title": "Two", "columns": 2, "items": []}], "cabinet": [{"items": [{"kind": "device", "designation": "KM1"}]}]}}'
	var doc: SchematicDocument = ProjectFile.parse(text)["document"]
	assert_eq(doc.switchboards.size(), 1, "the switchboard of the file")
	assert_eq(doc.switchboards[0].name, "RA1")
	assert_eq(doc.switchboards[0].rails[0].items[0].designation, "KM1")
	assert_eq([doc.control_boxes[0].name, doc.control_boxes[1].name], ["ST1", "ST2"], "each control box is a station")
	var spots: Array[Vector2] = [doc.switchboards[0].position, doc.control_boxes[0].position, doc.control_boxes[1].position]
	assert_true(spots[1].x > spots[0].x and spots[2].x > spots[1].x, "side by side, not on top of each other")
	assert_eq(ProjectFile.to_dict(doc)["version"], ProjectFile.VERSION)
