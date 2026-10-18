extends GutTest
## Cables of the workspace worked out from the wiring: a gate opened from two
## control stations, its stop buttons looped through from one to the other.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC


## +RA1 holds KM1 and strip X2; +ST1 has SB1 (stop) and SB2 (open), +ST2
## has SB4 (stop). L comes through X2:1 to SB1, SB1 goes straight on to SB4,
## SB4 back through X2:2 to SB2, SB2 to the coil.
func _doc() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("gate")
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 40))
	doc.add(Coil.new("KM1"), Vector2i(0, 30))
	doc.add(PushButton.new("SB1", NC), Vector2i(0, 6))
	doc.add(PushButton.new("SB4", NC), Vector2i(0, 12))
	doc.add(PushButton.new("SB2", NO), Vector2i(0, 18))
	doc.add(Motor.new("M1"), Vector2i(20, 30))
	for t: Array in [["X5", "X2:1"], ["X6", "X2:2"]]:
		var block: TerminalBlock = TerminalBlock.new(t[0])
		block.label = t[1]
		doc.add(block, Vector2i(10, 4 * doc.circuit.get_components().size()))
	doc.connect_terminals("L", "X5")
	doc.connect_terminals("X5", "SB1:11")
	doc.connect_terminals("SB1:12", "SB4:11")
	doc.connect_terminals("SB4:12", "X6")
	doc.connect_terminals("X6", "SB2:13")
	doc.connect_terminals("SB2:14", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N")
	doc.connect_terminals("N", "M1:U2")
	doc.connect_terminals("L", "M1:U1")
	doc.add_switchboard()
	doc.add_cabinet_rail(0)
	doc.add_cabinet_item(0, 0, CabinetItem.Kind.DEVICE, "KM1")
	doc.add_cabinet_item(0, 0, CabinetItem.Kind.STRIP, "X2")
	var inside: ControlBox = doc.add_control_box("Gate, inside")
	inside.items.append(ControlBoxItem.new(ControlBoxItem.Kind.BUTTON, "SB1", "red"))
	inside.items.append(ControlBoxItem.new(ControlBoxItem.Kind.BUTTON, "SB2"))
	var outside: ControlBox = doc.add_control_box("Gate, outside")
	outside.items.append(ControlBoxItem.new(ControlBoxItem.Kind.BUTTON, "SB4", "red"))
	return doc


func _by_ends(list: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for cable: Dictionary in list:
		result[cable["key"]] = cable
	return result


func test_cables_follow_the_wiring() -> void:
	var cables: Dictionary = _by_ends(WorkspaceCables.cables(_doc()))
	assert_eq(cables.keys(), ["+RA1|+ST1", "+RA1|+ST2", "+RA1|-M1", "+ST1|+ST2"])
	var inside: Dictionary = cables["+RA1|+ST1"]
	var landed: PackedStringArray = PackedStringArray()
	for core: Dictionary in inside["cores"]:
		landed.append("%s>%s" % [",".join(core["a"]), ",".join(core["b"])])
	assert_eq(landed, PackedStringArray(["X2:1>SB1:11", "X2:2>SB2:13", "KM1:A1>SB2:14"]), "each core: what it lands on at both ends")
	assert_eq((inside["cores"] as Array).size(), 3, "L in through X2:1, back from X2:2, out to the coil")
	assert_eq((cables["+ST1|+ST2"]["cores"] as Array).size(), 1, "the stop buttons looped through from station to station")
	assert_eq(cables["+ST1|+ST2"]["cores"][0]["a"], PackedStringArray(["SB1:12"]))
	assert_eq(cables["+ST1|+ST2"]["cores"][0]["b"], PackedStringArray(["SB4:11"]))
	assert_eq((cables["+RA1|+ST2"]["cores"] as Array).size(), 1, "SB4 back to X2:2: a star from the strip")
	assert_eq(cables["+RA1|+ST2"]["cores"][0]["a"], PackedStringArray(["X2:2"]))


func test_names_in_turn_kept_and_renamed() -> void:
	var doc: SchematicDocument = _doc()
	var names: PackedStringArray = PackedStringArray()
	for cable: Dictionary in WorkspaceCables.cables(doc):
		names.append(cable["name"])
	assert_eq(names, PackedStringArray(["W1", "W2", "W3", "W4"]))
	doc.name_cables()
	assert_eq(doc.cable_names["+ST1|+ST2"], "W4")
	assert_true(doc.rename_cable("+ST1|+ST2", "W10"))
	assert_false(doc.rename_cable("+RA1|+ST1", "W10"), "another cable has the name")
	assert_false(doc.rename_cable("+RA1|+ST1", "W 1"), "no spaces")
	assert_false(doc.rename_cable("+RA9|+ST1", "W11"), "no such cable")
	# A new cable takes the first free name, the others keep theirs.
	doc.add_switchboard()
	doc.add_cabinet_rail(1)
	doc.control_boxes[1].items.clear()
	doc.name_cables()
	var cables: Dictionary = _by_ends(WorkspaceCables.cables(doc))
	assert_false(cables.has("+ST1|+ST2"), "SB4 has no place now")
	assert_false(doc.cable_names.has("+ST1|+ST2"), "the name of a cable that is gone is dropped")
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(copy.cable_names, doc.cable_names, "names are saved")


func test_cores_text() -> void:
	assert_eq(WorkspaceCables.cores_text({"cores": [{"conductor": CabinetDevices.Conductor.CONTROL}, {"conductor": CabinetDevices.Conductor.PE}]}), "2G")
	assert_eq(WorkspaceCables.cores_text({"cores": [{"conductor": CabinetDevices.Conductor.CONTROL}]}), "1")


func test_nothing_placed_no_cables() -> void:
	var doc: SchematicDocument = _doc()
	doc.switchboards.clear()
	doc.control_boxes.clear()
	assert_eq(WorkspaceCables.cables(doc).size(), 0, "parts in the field alone need no cable")


func test_switchboard_field_cables_take_the_workspace_names() -> void:
	var doc: SchematicDocument = _doc()
	var names: Dictionary = {}
	for cable: Dictionary in WorkspaceCables.cables(doc):
		names[cable["name"]] = cable["key"]
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0, 0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0, 0)
	var bottom: PackedStringArray = PackedStringArray()
	for gland: Dictionary in wiring.glands:
		if gland["bottom"]:
			bottom.append(gland["cable"])
	assert_false(bottom.is_empty())
	for cable: String in bottom:
		assert_true(names.has(cable) and str(names[cable]).begins_with("+RA1|"), "%s is a cable of the workspace from +RA1" % cable)
	doc.control_boxes.clear()
	wiring = CabinetWiring.build(doc, CabinetLayout.build(doc, 2.0, 0), 2.0, 0)
	for gland: Dictionary in wiring.glands:
		if gland["bottom"]:
			assert_true(str(gland["cable"]).begins_with("-SB"), "a button with no place: its own cable, named after it")


func test_renamed_places_keep_their_cables_names() -> void:
	var doc: SchematicDocument = _doc()
	doc.name_cables()
	assert_true(doc.rename_cable("+RA1|+ST1", "W-inside"))
	assert_true(doc.rename_place(Workspace.Place.STATION, 0, "ST7", "Gate, inside"))
	doc.replace_component("M1", Motor.new("M5"))
	doc.name_cables()
	var cables: Dictionary = _by_ends(WorkspaceCables.cables(doc))
	assert_eq(cables["+RA1|+ST7"]["name"], "W-inside")
	assert_eq(cables["+RA1|-M5"]["name"], "W3", "the motor's cable keeps its number")
