extends GutTest
## The external influences of ČSN 33 2000-5-51 as a room's environment: the
## list, classes joined one per category, what they mean, a bathroom still
## known with influences added, and the room panel's List button opening
## the table whose ticks become the room's environment.


func after_all() -> void:
	RecoveryFile.forget()


func _house() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Hall", Rect2(0, 0, 3, 2)))
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Bathroom", Rect2(3, 0, 2.5, 2)))
	return doc


func _view(doc: SchematicDocument) -> FloorPlanView:
	var view: FloorPlanView = FloorPlanView.new()
	add_child_autofree(view)
	view.set_document(doc, true)
	view.edit_requested.connect(func(change: Callable) -> void:
		change.call(doc)
		view.refresh())
	return view


func test_the_list() -> void:
	var codes: PackedStringArray = PackedStringArray()
	for group: Dictionary in ExternalInfluences.GROUPS:
		for category: Dictionary in group["categories"]:
			for entry: Array in category["classes"]:
				assert_false(codes.has(entry[0]), "%s once" % entry[0])
				codes.append(entry[0])
	assert_eq(ExternalInfluences.GROUPS.size(), 3, "environment, utilisation, buildings")
	for code: String in ["AA1", "AA8", "AB8", "AC2", "AD8", "AE6", "AF4", "AG3", "AH3", "AK2", "AL2", "AM-1-3", "AM-4", "AM-9-4", "AM-22-4", "AM-31-4", "AM-41-1", "AN3", "AP4", "AQ3", "AR3", "AS3", "BA5", "BC4", "BD4", "BE4", "CA2", "CB4"]:
		assert_true(codes.has(code), code)
	assert_eq(ExternalInfluences.category_of("AD4"), "AD")
	assert_eq(ExternalInfluences.category_of("AM-22-3"), "AM-22")
	assert_eq(ExternalInfluences.category_of("N"), "")
	assert_eq(ExternalInfluences.describe("AD4"), "Presence of water: splashes")
	assert_eq(ExternalInfluences.describe("AM-4"), "Voltage unbalance", "a class that is its category")


func test_translated_by_their_category() -> void:
	var locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("cs")
	var water: String = ExternalInfluences.describe("AD1")
	var corrosion: String = ExternalInfluences.describe("AF1")
	var wind: String = ExternalInfluences.describe("AS3")
	var range: String = ExternalInfluences.describe("AA5")
	TranslationServer.set_locale(locale)
	assert_eq(water, "Voda: zanedbatelná")
	assert_eq(corrosion, "Korozivní působení: zanedbatelné", "the same English word, another Czech one")
	assert_eq(wind, "Vítr: velký")
	assert_eq(range, "Teplota okolí: +5 °C … +40 °C", "ranges as they are")


func test_classes_joined_one_per_category_in_the_order_of_the_list() -> void:
	assert_eq(ExternalInfluences.join(PackedStringArray(["AD4", "BE2", "AB8"])), "AB8, AD4, BE2")
	assert_eq(ExternalInfluences.join(PackedStringArray(["AD2", "AD4"])), "AD4", "the last of a category")
	assert_eq(ExternalInfluences.join(PackedStringArray(["XY1"])), "", "not a class")
	assert_eq(ExternalInfluences.classes_of("ČSN 33 2000-7-701, AD4, BE2"), PackedStringArray(["AD4", "BE2"]))
	assert_eq(FloorPlan.with_influences("N", PackedStringArray(["AD4", "AB8"])), "AB8, AD4", "a preset's text")
	assert_eq(FloorPlan.with_influences("AB8, AD4", PackedStringArray()), "N", "none ticked: normal")
	assert_eq(FloorPlan.with_influences("ČSN 33 2000-7-701", PackedStringArray(["AD3"])), "ČSN 33 2000-7-701, AD3", "a bathroom stays one")
	assert_eq(FloorPlan.with_influences("ČSN 33 2000-7-701, AD3", PackedStringArray()), "ČSN 33 2000-7-701")


func test_what_an_environment_means() -> void:
	assert_eq(FloorPlan.environment_note("AB7"), FloorPlan.ENVIRONMENT_NOTES[3], "a preset's note")
	var note: String = FloorPlan.environment_note("AD4, BE2")
	assert_string_contains(note, "AD4 Presence of water: splashes")
	assert_string_contains(note, "BE2 Nature of processed or stored materials: fire risks")
	assert_string_contains(FloorPlan.environment_note("ČSN 33 2000-7-701, AD3"), FloorPlan.ENVIRONMENT_NOTES[1])
	assert_eq(FloorPlan.environment_note("something"), "")


func test_a_bathroom_with_influences_is_still_a_bathroom() -> void:
	var plan: FloorPlan = _house().floor_plan
	assert_false(plan.is_bathroom(0))
	assert_true(plan.is_bathroom(1), "by its name")
	plan.rooms[1].environment = "ČSN 33 2000-7-701, AD4"
	assert_true(plan.is_bathroom(1), "with an influence added")
	plan.rooms[1].environment = "AD4"
	assert_false(plan.is_bathroom(1))


func test_list_button_opens_the_table_and_its_ticks_become_the_environment() -> void:
	var doc: SchematicDocument = _house()
	var view: FloorPlanView = _view(doc)
	var canvas: FloorPlanCanvas = view.canvas
	canvas.size = Vector2(1000, 700)
	canvas.selected = {"kind": "room", "index": 0}
	var field: OptionButton = view.get("_environment_field")
	var button: Button = view.get("_influences_button")
	var dialog: InfluencesDialog = view.get("_influences_dialog")
	assert_eq(field.get_parent(), button.get_parent(), "the List button beside the field")
	assert_eq(field.item_count, FloorPlan.ENVIRONMENTS.size(), "only the presets")
	button.pressed.emit()
	assert_true(dialog.visible, "the table shown")
	assert_eq(dialog.ticked().size(), 0, "a normal room: nothing ticked")
	var rows: Dictionary = dialog.get("_rows")
	var tree: Tree = dialog.get("_tree")
	for code: String in ["AD2", "AD4", "BE2"]:
		var row: TreeItem = rows[code]
		row.set_checked(0, true)
		dialog.call("_ticked_item", row)
	assert_eq(dialog.ticked(), PackedStringArray(["AD4", "BE2"]), "one class of a category")
	assert_not_null(tree.get_root())
	dialog.confirmed.emit()
	dialog.hide()
	assert_eq(doc.floor_plan.room_environment(0), "AD4, BE2")
	assert_eq(field.item_count, FloorPlan.ENVIRONMENTS.size() + 1, "its own offered after the presets")
	assert_eq(field.get_item_text(field.selected), "AD4, BE2")
	assert_string_contains((view.get("_environment_note") as Label).text, "AD4")
	# Opened again, its classes are ticked; a preset picked takes their place.
	button.pressed.emit()
	assert_eq(dialog.ticked(), PackedStringArray(["AD4", "BE2"]))
	dialog.hide()
	field.select(3)
	field.item_selected.emit(3)
	assert_eq(doc.floor_plan.room_environment(0), "AB7")
	# Ticks matching a preset pick the preset.
	button.pressed.emit()
	for code: String in rows:
		(rows[code] as TreeItem).set_checked(0, code in ["AB8", "AD4"])
	dialog.confirmed.emit()
	dialog.hide()
	assert_eq(doc.floor_plan.room_environment(0), "AB8, AD4")
	assert_eq(field.selected, 2, "the outdoor preset")
	assert_eq(field.item_count, FloorPlan.ENVIRONMENTS.size())
	# Saved and loaded as it is.
	var again: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(again.floor_plan.room_environment(0), "AB8, AD4")
	canvas.selected = {}
