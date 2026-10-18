extends GutTest
## The parts list and the sheets of a PDF export: devices by their place,
## terminal strips, cables; stations and rows shared out over sheets; what
## the export holds as ticked.

const NO := SwitchingElement.ContactType.NO


## +RA1 holds the breaker FA1, contactor KM1 and strip X2; +ST1 has the start
## button SB1; M1 is in the field, wired from X2.
func _doc() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("parts")
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 40))
	var breaker: CircuitBreaker = CircuitBreaker.new("FA1")
	doc.add(breaker, Vector2i(0, 4))
	doc.add(Coil.new("KM1"), Vector2i(0, 30))
	doc.add(PushButton.new("SB1", NO), Vector2i(0, 12))
	var motor: ThreePhaseMotor = ThreePhaseMotor.new("M1")
	motor.rated_power = 4.0
	motor.rated_current = 8.2
	doc.add(motor, Vector2i(20, 30))
	var block: TerminalBlock = TerminalBlock.new("X5")
	block.label = "X2:1"
	doc.add(block, Vector2i(10, 8))
	doc.connect_terminals("L", "X5")
	doc.connect_terminals("X5", "SB1:13")
	doc.connect_terminals("SB1:14", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N")
	doc.add_switchboard()
	doc.add_cabinet_rail(0)
	doc.add_cabinet_item(0, 0, CabinetItem.Kind.DEVICE, "FA1")
	doc.add_cabinet_item(0, 0, CabinetItem.Kind.DEVICE, "KM1")
	doc.add_cabinet_item(0, 0, CabinetItem.Kind.STRIP, "X2")
	var station: ControlBox = doc.add_control_box("Gate")
	var start: ControlBoxItem = ControlBoxItem.new(ControlBoxItem.Kind.BUTTON, "SB1", "green")
	start.label = "Start"
	station.items.append(start)
	return doc


func _texts(rows: Array[Dictionary]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for row: Dictionary in rows:
		result.append(row["text"] if row.get("heading", false) else "%s|%s|%s" % [row["designation"], row["name"], row["data"]])
	return result


func test_parts_by_place() -> void:
	var texts: PackedStringArray = _texts(PartsList.new().rows(_doc()))
	assert_eq(texts[0], "+RA1  Switchboard")
	assert_true(texts[1].begins_with("-FA1|Circuit breaker|Circuit breaker C"), texts[1])
	assert_eq(texts[2], "-KM1|Contactor|")
	assert_eq(texts[3], "-X2|Terminal strip|1 terminal")
	assert_eq(texts[4], "+ST1  Gate")
	assert_eq(texts[5], "-SB1|Push button|Green, „Start“")
	assert_eq(texts[6], "In the field")
	assert_eq(texts[7], "-M1|Motor|4 kW, 8.2 A")
	assert_true(texts.has("Cables"))
	for text: String in texts:
		assert_false(text.contains("not in the schematic"), text)


func test_unplaced_parts() -> void:
	var doc: SchematicDocument = _doc()
	doc.control_boxes.clear()
	var texts: PackedStringArray = _texts(PartsList.new().rows(doc))
	var at: int = texts.find("Not placed")
	assert_true(at >= 0)
	assert_eq(texts[at + 1], "-SB1|Push button|")


func test_rows_shared_out_over_sheets() -> void:
	var rows: Array[Dictionary] = []
	for i: int in 100:
		rows.append({"heading": i % 10 == 0, "text": "+P%d" % i, "designation": "-D%d" % i, "name": "", "data": ""})
	var sheets: Array[Array] = PartsSheet.split(rows)
	var count: int = 0
	for sheet: Array in sheets:
		count += sheet.size()
		assert_false(sheet[sheet.size() - 1].get("heading", false), "a heading never ends a sheet")
	assert_eq(count, 100)
	assert_gt(sheets.size(), 2)


func test_stations_shared_out_over_sheets() -> void:
	var doc: SchematicDocument = _doc()
	for i: int in 12:
		var box: ControlBox = doc.add_control_box()
		for j: int in 4:
			box.items.append(ControlBoxItem.new(ControlBoxItem.Kind.BUTTON, "SB1"))
	var sheets: Array[Array] = StationsSheet.arrange(doc)
	var count: int = 0
	for sheet: Array in sheets:
		count += sheet.size()
		for entry: Dictionary in sheet:
			var end: Vector2 = entry["at"] + StationsSheet.box_size(doc, entry["box"])
			assert_true(end.x <= StationsSheet.ROOM.x and end.y + StationsSheet.CAPTION_H <= StationsSheet.ROOM.y, "every station fits its sheet")
	assert_eq(count, 13)
	assert_gt(sheets.size(), 1)


func test_export_holds_what_is_ticked() -> void:
	var renderer: SheetRenderer = autofree(SheetRenderer.new())
	var doc: SchematicDocument = _doc()
	var kinds: PackedStringArray = PackedStringArray()
	for spec: Dictionary in renderer.sheets(doc, PackedInt32Array([0])):
		kinds.append(spec["kind"])
	assert_eq(kinds, PackedStringArray(["page"]), "the schematic alone by default")
	renderer.stations = true
	renderer.switchboards = true
	renderer.workspace = true
	renderer.parts_list = true
	kinds.clear()
	for spec: Dictionary in renderer.sheets(doc, PackedInt32Array([0])):
		kinds.append(spec["kind"])
	assert_eq(kinds, PackedStringArray(["page", "stations", "switchboard", "workspace", "parts"]))
	doc.add_switchboard()
	kinds.clear()
	for spec: Dictionary in renderer.sheets(doc, PackedInt32Array([0])):
		kinds.append(spec["kind"])
	assert_eq(kinds.count("switchboard"), 1, "an empty switchboard has no sheet")
	renderer.schematic = false
	doc.switchboards.clear()
	doc.control_boxes.clear()
	kinds.clear()
	for spec: Dictionary in renderer.sheets(doc, PackedInt32Array([0])):
		kinds.append(spec["kind"])
	assert_eq(kinds, PackedStringArray(["workspace", "parts"]), "nothing for what the schematic does not have")
