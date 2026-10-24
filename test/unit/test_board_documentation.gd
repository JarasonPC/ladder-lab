extends GutTest
## A switchboard's documentation: the switchboard maker kept in the
## settings, what the switchboard is given (nothing assumed), saved with it,
## the temperature rise protocol's summary, parameters grouped by type and
## balance against the enclosure's power loss, the interface
## characteristics and the operating instructions with only the devices it
## has, all three in the export, and the dialog giving it.

var _maker: Dictionary = {}


func before_each() -> void:
	_maker = Manufacturer.data
	Manufacturer.data = {}


func after_each() -> void:
	Manufacturer.data = _maker


func after_all() -> void:
	RecoveryFile.forget()


## The consumer unit of a house: an RCD, three B16 breakers and a C10 one.
func _house() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	var line: SingleLine = doc.single_line
	line.add(doc, DocumentSerializer.component_from_dict({"type": "rcd", "poles": 4, "rated_current": 40.0, "designation": "FB1"}), 0)
	for i: int in 3:
		line.add(doc, DocumentSerializer.component_from_dict({"type": "breaker", "characteristic": "B", "rated_current": 16.0, "designation": "FA%d" % (i + 1)}), i, "FB1")
	line.add(doc, DocumentSerializer.component_from_dict({"type": "breaker", "characteristic": "C", "rated_current": 10.0, "designation": "FA4"}), 3, "FB1")
	doc.update_single_line()
	doc.ensure_consumer_unit()
	return doc


## Everything the temperature rise calculation of board [param b] needs.
func _heat(doc: SchematicDocument, b: int, changes: Dictionary = {}) -> void:
	var lost: Dictionary = HeatRise.evaluate(doc, b, HeatRiseReport.layout(doc, b).wiring.wires, {})["losses"]
	var s: Dictionary = {"height": 930.0, "width": 600.0, "depth": 140.0, "mounting": 1, "vented": false, "partitions": 0,
		"ambient": 25.0, "limit": 55.0, "rdf": 0.6, "extra": 0.0, "terminals": 0.0, "losses": {}, "sections": {}, "types": {}}
	for device: Dictionary in lost["devices"]:
		var designation: String = device["designation"]
		s["losses"][designation] = 2.0 if designation.begins_with("FA") else 4.0
		s["types"][designation] = "LTE-16B-1" if designation in ["FA1", "FA2", "FA3"] else "T-" + designation
	for group: Dictionary in lost["groups"]:
		s["sections"][group["key"]] = 2.5
	s.merge(changes, true)
	doc.switchboards[b].heat = HeatRise.settings(s)


## Every documentation field given.
func _all_documented() -> Dictionary:
	var d: Dictionary = {}
	for f: Dictionary in BoardDocumentation.fields():
		match f["kind"]:
			"text":
				d[f["key"]] = "given " + f["key"]
			"number":
				d[f["key"]] = 25.0
			"choice":
				d[f["key"]] = f["options"][0]
	return BoardDocumentation.clean(d)


func _all_text(rows: Array[Dictionary]) -> String:
	var all: String = ""
	for row: Dictionary in rows:
		all += str(row.get("text", "")) + " | ".join(PackedStringArray(row.get("cells", []).map(func(c: Variant) -> String: return str(c)))) + "\n"
	return all


func test_manufacturer_kept_as_given() -> void:
	assert_eq(Manufacturer.clean({"name": "  Jan Novák ", "phone": "", "unknown": "x", "web": 5}), {"name": "Jan Novák"}, "text only, trimmed, the empty and unknown left out")
	assert_eq(Manufacturer.missing().size(), 5, "nothing assumed: name, company ID, authorisation, address, a phone or e-mail")
	Manufacturer.data = Manufacturer.clean({"name": "Jan Novák", "id_number": "123", "authorisation": "1/EZ", "address": "Praha", "email": "a@b.cz"})
	assert_eq(Manufacturer.missing().size(), 0)
	assert_eq(Manufacturer.shown_name(), "Jan Novák", "the name without a trade name")
	Manufacturer.data["company"] = "Elektro"
	assert_eq(Manufacturer.shown_name(), "Elektro")
	assert_eq(InterfaceReport.maker_text(), "Jan Novák, 123\nAuthorisation: 1/EZ\nElektro, Praha")


func test_nothing_assumed_only_what_makes_sense_kept() -> void:
	var d: Dictionary = BoardDocumentation.clean({"un": 400, "ui": -5.0, "ina": "125", "earthing": "TN-C-S", "pollution": "7",
		"customer": "  Jakub ", "ip": "", "elsewhere": "x", "rdf": 0.6})
	assert_eq(d, {"un": 400.0, "earthing": "TN-C-S", "customer": "Jakub"})
	var board: Switchboard = Switchboard.new("RD1")
	assert_eq(BoardDocumentation.missing(board).size(), BoardDocumentation.HEADER.size() + BoardDocumentation.CHARACTERISTICS.size(), "every field asked for")
	assert_eq(BoardDocumentation.CHARACTERISTICS.size(), 26)
	board.documentation = d
	assert_eq(BoardDocumentation.shown(board, "un"), "400 V")
	assert_eq(BoardDocumentation.shown(board, "earthing"), "TN-C-S")
	assert_eq(BoardDocumentation.shown(board, "ui"), "", "not given")
	# The diversity factor and the size are the temperature rise calculation's.
	assert_eq(BoardDocumentation.shown(board, "rdf"), "")
	board.heat = HeatRise.settings({"rdf": 0.6, "height": 930.0, "width": 600.0, "depth": 140.0})
	assert_eq(BoardDocumentation.shown(board, "rdf"), "0.6")
	assert_eq(BoardDocumentation.shown(board, "dimensions"), "930 × 600 × 140")
	board.documentation = _all_documented()
	assert_eq(BoardDocumentation.missing(board).size(), 0)
	assert_eq(BoardDocumentation.standard(board), "ČSN EN 61439-3", "DBO")
	assert_eq(BoardDocumentation.conflicts({"ina": 25.0, "inc": 40.0, "un": 400.0, "ue": 230.0}).size(), 2, "Inc over InA, Ue under Un")


func test_saved_with_the_switchboard() -> void:
	var doc: SchematicDocument = _house()
	var board: Switchboard = doc.switchboards[0]
	board.documentation = BoardDocumentation.clean({"serial_number": "24004", "ina": 125.0, "assembly": "DBO"})
	board.heat = HeatRise.settings({"enclosure_loss": 110.0, "types": {"FA1": " LTE-16B-1 ", "FA2": ""}})
	assert_eq(board.heat, {"enclosure_loss": 110.0, "types": {"FA1": "LTE-16B-1"}}, "a type trimmed, an empty one not given")
	var again: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(again.switchboards[0].documentation, board.documentation)
	assert_eq(again.switchboards[0].heat, board.heat)
	board.documentation = {}
	assert_false(board.to_data().has("documentation"), "nothing saved while nothing is given")
	assert_eq(HeatRise.settings({"enclosure_loss": 0.0}), {}, "the enclosure takes more than 0 W")


func test_protocol_summary_parameters_and_balance() -> void:
	var doc: SchematicDocument = _house()
	_heat(doc, 0)
	var e: Dictionary = HeatRise.evaluate(doc, 0, HeatRiseReport.layout(doc, 0).wiring.wires)
	assert_eq(e["missing"].size(), 0, str(e["missing"]))
	assert_null(HeatRise.balance(e["settings"], e["losses"]), "no balance without the enclosure's power loss")
	# The breakers alike in type, data and loss are one row.
	var groups: Array[Dictionary] = HeatRiseReport.device_groups(doc, e["losses"])
	var b16: Array = groups.filter(func(g: Dictionary) -> bool: return g["type"] == "LTE-16B-1")
	assert_eq(b16.size(), 1)
	assert_eq(b16[0]["designations"], PackedStringArray(["-FA1", "-FA2", "-FA3"]))
	assert_eq(b16[0]["data"], "B16", "the name left out of the data")
	assert_eq(groups.filter(func(g: Dictionary) -> bool: return g["name"] == "Circuit breaker").size(), 2, "B16 and C10")
	var all: String = _all_text(HeatRiseReport.new().rows(doc, 0))
	for part: String in ["Summary", "Parameters", "Circuit breaker | LTE-16B-1 | B16 | -FA1…-FA3 | 2 | 3 | 6", "Remaining available power loss | not given",
			"Power loss the enclosure takes (from its maker)", "Not decided", "The power loss the enclosure takes (from its maker)", "Switchboard type (in Documentation…)"]:
		assert_string_contains(all, part)
	_heat(doc, 0, {"enclosure_loss": 110.0})
	doc.switchboards[0].documentation = BoardDocumentation.clean({"board_type": "BF-U-5/120-C", "material": "Metal", "location": "Indoor installation"})
	e = HeatRise.evaluate(doc, 0, HeatRiseReport.layout(doc, 0).wiring.wires)
	var balance: float = HeatRise.balance(e["settings"], e["losses"])
	assert_almost_eq(balance, 110.0 - e["losses"]["total"], 0.001)
	all = _all_text(HeatRiseReport.new().rows(doc, 0))
	assert_string_contains(all, "Remaining available power loss | %s W" % HeatRiseReport._n(balance, 2))
	assert_string_contains(all, "Enclosure BF-U-5/120-C: the power loss it takes | -110")
	assert_string_contains(all, "Overall balance (below 0: the enclosure takes more) | %s" % HeatRiseReport._n(-balance, 2))
	assert_string_contains(all, "Complies" if e["result"]["ok"] else "Does not comply")
	assert_false(all.contains("Still to give for the protocol"), "all given")
	# More than the enclosure takes.
	_heat(doc, 0, {"enclosure_loss": 1.0})
	assert_string_contains(_all_text(HeatRiseReport.new().rows(doc, 0)), "Does not comply")


func test_interface_characteristics() -> void:
	var doc: SchematicDocument = _house()
	var rows: Array[Dictionary] = InterfaceReport.new().rows(doc, 0, "source")
	var all: String = _all_text(rows)
	assert_string_contains(all, "Interface characteristics of switchboard +RD1")
	assert_string_contains(all, "26 | Operating conditions | not given")
	assert_string_contains(all, "Switchboard manufacturer | not given")
	assert_string_contains(all, "Rated voltage (Un) (Documentation…)", "listed as still to give")
	assert_string_contains(all, "Rated diversity factor (RDF) (Temperature rise…)")
	assert_string_contains(all, "Company ID (IČ) (Settings > Switchboard manufacturer…)")
	Manufacturer.data = Manufacturer.clean({"name": "Jan Novák", "id_number": "123", "authorisation": "1/EZ", "address": "Praha", "phone": "1"})
	_heat(doc, 0)
	doc.switchboards[0].documentation = _all_documented()
	rows = InterfaceReport.new().rows(doc, 0)
	all = _all_text(rows)
	assert_string_contains(all, "Distribution board (DBO)")
	assert_string_contains(all, "1 | Rated voltage (Un) | 25 V")
	assert_string_contains(all, "8 | Rated diversity factor (RDF) | 0.6")
	assert_string_contains(all, "24 | Overall dimensions")
	assert_string_contains(all, "930 × 600 × 140")
	assert_false(all.contains("Still to give"), "all given")
	# The long rows wrap rather than shrink; every sheet fits.
	assert_true(rows.filter(func(r: Dictionary) -> bool: return r["type"] == "table" and not r["head"]).all(func(r: Dictionary) -> bool: return r["wrap"]))
	for sheet: Array in ReportSheet.split(rows):
		var height: float = 0.0
		for row: Dictionary in sheet:
			height += ReportSheet.height_of(row)
		assert_lte(height, ReportSheet.SIZE.y + 0.01)
	var long: Dictionary = ReportSheet._wrapped(rows.filter(func(r: Dictionary) -> bool: return r["type"] == "table" and str(r["cells"][0]) == "10")[0])
	assert_gt(ReportSheet.height_of(long), ReportSheet.HEIGHTS["table"], "item 10's long title on several lines")


func test_instructions_have_only_the_devices_fitted() -> void:
	var doc: SchematicDocument = _house()
	Manufacturer.data = Manufacturer.clean({"company": "NášElektrikář.cz", "phone": "608 516 076"})
	var found: Dictionary = InstructionsReport.devices(doc, 0)
	assert_eq(found["rcds"], PackedStringArray(["-FB1"]))
	assert_eq(found["breakers"].size(), 4)
	assert_true(found["afdds"].is_empty())
	var all: String = _all_text(InstructionsReport.new().rows(doc, 0))
	for part: String in ["Operating and maintenance instructions of switchboard +RD1", "NášElektrikář.cz", "Phone: 608 516 076",
			"switchboards made by NášElektrikář.cz", "a. Main switch", "b. Circuit breaker", "c. Residual current device (RCD)",
			"every 6 months", "In this switchboard: -FB1", "X. Conclusion and special arrangements", "other than NášElektrikář.cz",
			"Additional protection | residual current device RCD (FI)", "Voltage system | not given"]:
		assert_string_contains(all, part)
	assert_false(all.contains("Arc fault detection device with breaker (AFDD)"), "no AFDD fitted")
	assert_false(all.contains("Other devices"), "nothing else fitted")
	# An industrial board: contactors and an overload relay are other devices.
	var plant: SchematicDocument = ExampleCircuits.build(ExampleCircuits.TITLES.find("Direct-on-line start 3~"))
	if plant.switchboards.is_empty():
		plant.add_switchboard()
	plant.fill_cabinet(0)
	all = _all_text(InstructionsReport.new().rows(plant, 0))
	assert_string_contains(all, "Other devices")
	assert_false(all.contains("Residual current device (RCD)"))


func test_export_has_the_documents() -> void:
	var doc: SchematicDocument = _house()
	_heat(doc, 0)
	var available: Dictionary = SheetRenderer.available(doc)
	assert_true(available["interface"])
	assert_true(available["instructions"])
	var renderer: SheetRenderer = SheetRenderer.new()
	renderer.schematic = false
	renderer.heat_rise = true
	renderer.interface = true
	renderer.instructions = true
	var kinds: Array = renderer.sheets(doc, PackedInt32Array()).map(func(spec: Dictionary) -> String: return spec["kind"])
	assert_eq(kinds.front(), "heat_rise")
	assert_true(kinds.has("interface"))
	assert_eq(kinds.back(), "instructions", "the protocol, the characteristics, the instructions")
	assert_lt(kinds.rfind("heat_rise"), kinds.find("interface"))
	renderer.heat_rise = false
	renderer.instructions = false
	assert_true(renderer.sheets(doc, PackedInt32Array()).all(func(spec: Dictionary) -> bool: return spec["kind"] == "interface"), "only what is chosen")
	renderer.free()
	assert_true(ExportPreview.CONTENTS.has("interface"))
	assert_true(ExportPreview.CONTENTS.has("instructions"))


func test_dialog_gives_what_is_typed() -> void:
	var doc: SchematicDocument = _house()
	var dialog: BoardDocumentationDialog = BoardDocumentationDialog.new()
	add_child_autofree(dialog)
	var got: Array[Dictionary] = []
	dialog.saved.connect(func(data: Dictionary) -> void: got.append(data))
	dialog.open(doc.switchboards[0])
	var inputs: Dictionary = dialog.get("_inputs")
	var un: LineEdit = inputs["un"]
	assert_eq(un.text, "", "empty until given")
	assert_eq(un.placeholder_text, "enter")
	assert_eq((inputs["earthing"] as OptionButton).selected, 0, "— choose —")
	assert_string_contains((inputs["rdf"] as Label).text, "Temperature rise", "given there")
	un.text = "400"
	un.text_changed.emit("400")
	(inputs["earthing"] as OptionButton).select(3)
	(inputs["earthing"] as OptionButton).item_selected.emit(3)
	var customer: LineEdit = inputs["customer"]
	customer.text = "Jakub Menzel"
	customer.text_changed.emit("Jakub Menzel")
	var additional: TextEdit = inputs["additional"]
	additional.text = "a\nb"
	additional.text_changed.emit()
	(inputs["inc"] as LineEdit).text_changed.emit("40")
	(inputs["ina"] as LineEdit).text_changed.emit("25")
	assert_string_contains((dialog.get("_status") as Label).text, "larger than the rated current of the assembly")
	dialog.confirmed.emit()
	assert_eq(got.size(), 1)
	assert_eq(got[0], {"un": 400.0, "earthing": "TN-C-S", "customer": "Jakub Menzel", "additional": "a\nb", "inc": 40.0, "ina": 25.0})
	dialog.hide()


func test_panel_opens_the_documentation() -> void:
	var doc: SchematicDocument = _house()
	var panel: CabinetPanel = CabinetPanel.new()
	panel.board_name = doc.switchboards[0].name
	add_child_autofree(panel)
	panel.size = Vector2(1200, 800)
	panel.edit_requested.connect(func(change: Callable) -> void:
		change.call(doc)
		panel.refresh())
	panel.set_document(doc, true)
	await wait_process_frames(2)
	var open: Button = null
	var summary: Label = null
	for child: Node in (panel.get("_list") as VBoxContainer).get_children():
		if child is Button and (child as Button).text == "Documentation…":
			open = child
		if child is Label and (child as Label).text.begins_with("Documentation:"):
			summary = child
	assert_not_null(open)
	assert_string_contains(summary.text, "still to give")
	open.pressed.emit()
	var dialog: BoardDocumentationDialog = panel.get("_documentation_dialog")
	assert_true(dialog.visible)
	var serial: LineEdit = (dialog.get("_inputs") as Dictionary)["serial_number"]
	serial.text_changed.emit("24004")
	dialog.confirmed.emit()
	dialog.hide()
	assert_eq(doc.switchboards[0].documentation, {"serial_number": "24004"})


func test_type_completed_from_the_same_device() -> void:
	var doc: SchematicDocument = _house()
	doc.switchboards[0].heat = HeatRise.settings({"types": {"FA1": "LTE-16B-1"}, "losses": {"FA1": 1.8}})
	var dialog: HeatRiseDialog = HeatRiseDialog.new()
	add_child_autofree(dialog)
	dialog.open(doc, 0, HeatRiseReport.layout(doc, 0))
	var table: HeatLossTable = dialog.get("_losses")
	var rows: Array = table.get("_rows")
	var devices: Array = rows.filter(func(r: Dictionary) -> bool: return r["what"] == HeatRiseDialog.ROW_DEVICE)
	assert_eq(devices.size(), 5, "each device its own row")
	assert_eq(table.known("FA2"), {"LTE-16B-1": 1.8}, "the same B16 elsewhere")
	assert_eq(table.known("FA4"), {}, "the C10 is another device")
	var fa2: Dictionary = devices.filter(func(r: Dictionary) -> bool: return r["name"] == "FA2")[0]
	assert_false((fa2["types"] as MenuButton).disabled)
	var fa4: Dictionary = devices.filter(func(r: Dictionary) -> bool: return r["name"] == "FA4")[0]
	assert_true((fa4["types"] as MenuButton).disabled, "nothing to offer")
	# Typing completes it, the rest selected.
	var input: LineEdit = fa2["type"]
	input.grab_focus()
	input.text = "lt"
	input.caret_column = 2
	input.text_changed.emit("lt")
	assert_eq(input.text, "LTE-16B-1")
	assert_eq(input.get_selected_text(), "E-16B-1")
	assert_eq(dialog.settings()["types"]["FA2"], "LTE-16B-1")
	# Taken: its loss comes along into the empty field.
	input.text_submitted.emit(input.text)
	assert_eq(dialog.settings()["losses"]["FA2"], 1.8)
	assert_eq((fa2["field"] as LineEdit).text, "1.8")
	# A different type stays its own.
	var fa3: Dictionary = devices.filter(func(r: Dictionary) -> bool: return r["name"] == "FA3")[0]
	(fa3["type"] as LineEdit).text = "X"
	(fa3["type"] as LineEdit).caret_column = 1
	(fa3["type"] as LineEdit).text_changed.emit("X")
	assert_eq(dialog.settings()["types"]["FA3"], "X")
	dialog.hide()
