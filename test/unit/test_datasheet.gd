extends GutTest
## Datasheets of the parts: one for every palette part, every terminal of the
## part described, the technical data and diagrams that belong to it, the
## device front for parts in the switchboard, and the pages they are laid
## out on.

const NO := SwitchingElement.ContactType.NO


func test_every_palette_part_has_a_datasheet() -> void:
	for entry: Dictionary in Palette.ENTRIES:
		var sheet: Datasheet = Datasheet.of_template(entry["template"])
		var title: String = entry["title"]
		assert_eq(sheet.title, title, title)
		assert_false(sheet.summary.is_empty(), "summary of " + title)
		assert_false(sheet.description.is_empty(), "description of " + title)
		assert_false(sheet.data.is_empty(), "technical data of " + title)
		var described: PackedStringArray = PackedStringArray()
		for row: PackedStringArray in sheet.terminals:
			assert_eq(row.size(), 3)
			if not row[0].is_empty():
				assert_false(row[1].is_empty() or row[2].is_empty(), "%s terminal %s" % [title, row[0]])
				described.append(row[0])
		if sheet.component is PowerSupply or sheet.component is TerminalBlock or sheet.component is PageConnector:
			# Named by its designation (supplies) or its label (terminals, page connectors).
			assert_eq(described.size(), 1, "the connection point of " + title)
			continue
		for name: String in sheet.component.get_terminal_names():
			assert_has(described, name, "%s terminal %s" % [title, name])


func test_terminals_follow_the_part() -> void:
	var timer: Dictionary = {"type": "timer", "mode": "on_delay", "delay": 3.0, "control_input": true}
	var sheet: Datasheet = Datasheet.of_template(timer)
	assert_eq(_terminals(sheet), PackedStringArray(["A1", "A2", "S", "15", "16", "18"]), "its contacts as on the device while none is drawn")
	assert_eq(sheet.diagram, Datasheet.Diagram.TIMER)
	assert_eq(sheet.table.size(), TimerRelay.MODE_NAMES.size(), "every time function listed")
	var fuse: Datasheet = Datasheet.of_template({"type": "fuse", "poles": 3, "holder": true})
	assert_eq(_terminals(fuse), PackedStringArray(["1", "2", "3", "4", "5", "6"]))
	assert_eq(fuse.diagram, Datasheet.Diagram.TRIP_CURVE)
	assert_eq(fuse.trip_kind, TripCurve.Kind.FUSE_GG)
	var breaker: Datasheet = Datasheet.of_template({"type": "breaker", "characteristic": "B", "rated_current": 2.0})
	assert_eq(breaker.trip_kind, TripCurve.Kind.BREAKER_B)
	assert_true(breaker.summary.contains("B2"), breaker.summary)
	var plc: Datasheet = Datasheet.of_template({"type": "plc", "modules": ["8di8dq"]})
	assert_true(_terminals(plc).has("Q12.2"), "the module's outputs are described")


func test_renamed_terminals_and_contacts_of_the_device() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	var coil: Coil = Coil.new("KA3", Coil.Kind.RELAY)
	coil.rating = "24dc"
	doc.add(coil, Vector2i.ZERO)
	doc.add(Contact.new("KA3", NO, 1), Vector2i(4, 0))
	doc.add(ChangeoverContact.new("KA3", 2), Vector2i(8, 0))
	var sheet: Datasheet = Datasheet.of(coil, doc)
	assert_eq(_terminals(sheet), PackedStringArray(["A1", "A2", "13", "14", "21", "22", "24"]))
	assert_eq(sheet.letters, "KA")
	assert_false(sheet.front.is_empty(), "a relay sits in the switchboard")
	var data: Dictionary = {}
	for row: PackedStringArray in sheet.data:
		data[row[0]] = row[1]
	assert_eq(data["Rated voltage"], "24 V DC")
	assert_eq(data["On AC"], "does not pull in")
	var contact: Contact = doc.circuit.get_components()[1] as Contact
	var contact_sheet: Datasheet = Datasheet.of(contact, doc)
	assert_true(contact_sheet.terminals[0][2].contains("coil KA3 has pulled in"), contact_sheet.terminals[0][2])
	assert_true(contact_sheet.front.is_empty(), "contacts have no front of their own")


func test_front_only_for_switchboard_devices() -> void:
	assert_false(Datasheet.of_template({"type": "breaker"}).front.is_empty())
	assert_false(Datasheet.of_template({"type": "vfd"}).front.is_empty())
	assert_true(Datasheet.of_template({"type": "lamp"}).front.is_empty())
	assert_true(Datasheet.of_template({"type": "motor3", "motor_kind": "standard"}).front.is_empty())


func test_pages() -> void:
	for entry: Dictionary in Palette.ENTRIES:
		var sheet: Datasheet = Datasheet.of_template(entry["template"])
		var pages: Array[DatasheetLayout] = DatasheetLayout.compose(sheet)
		assert_gt(pages.size(), 0, entry["title"])
		assert_eq(pages[-1].front, not sheet.front.is_empty(), "front page of " + str(entry["title"]))
		var rows: int = 0
		for page: DatasheetLayout in pages:
			assert_eq(page.page_count, pages.size())
			rows += page.terminal_rows
			for item: Dictionary in page.items:
				if item.has("rect"):
					var r: Rect2 = item["rect"]
					assert_true(Rect2(Vector2.ZERO, DatasheetLayout.PAGE).encloses(r), "%s: %s inside the page" % [entry["title"], item])
		assert_eq(rows, sheet.terminals.size(), "every terminal row on a page: " + str(entry["title"]))


func test_long_terminal_lists_continue_on_more_pages() -> void:
	var plc: Dictionary = {"type": "plc", "family": "compact", "cpu": "14di10dq", "modules": ["sm_di8dq8", "sm_di8dq8", "sm_di8dq8", "sm_di8dq8"]}
	var sheet: Datasheet = Datasheet.of_template(plc)
	var pages: Array[DatasheetLayout] = DatasheetLayout.compose(sheet)
	assert_gt(pages.size(), 2, "terminal pages and the front")
	var rows: int = 0
	for page: DatasheetLayout in pages:
		rows += page.terminal_rows
	assert_eq(rows, sheet.terminals.size())


func _terminals(sheet: Datasheet) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for row: PackedStringArray in sheet.terminals:
		if not row[0].is_empty():
			result.append(row[0])
	return result
