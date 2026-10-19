extends GutTest
## Export and datasheets: renders on white paper that overlap, the preview
## while it renders again, datasheet titles, texts and page breaks, the
## device front's labels, the stations and parts list sheets, the PDF date
## and the texts of the examples in Czech.

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)


## Renders overlap (sheets rendered again at every tick of the preview,
## datasheets): the paper shown comes back only when the last one ends.
func test_white_paper_ends_with_the_last_render() -> void:
	var dark: bool = SchematicTheme.dark
	SchematicTheme.use(true)
	SheetRenderer.begin_white_paper()
	SheetRenderer.begin_white_paper()
	assert_false(SchematicTheme.dark)
	SheetRenderer.end_white_paper()
	assert_false(SchematicTheme.dark, "still white while one render goes on")
	SheetRenderer.end_white_paper()
	assert_true(SchematicTheme.dark)
	SchematicTheme.use(dark)


func test_preview_cannot_save_while_rendering_again() -> void:
	var preview: ExportPreview = ExportPreview.new()
	add_child_autofree(preview)
	var image: Image = Image.create(8, 8, false, Image.FORMAT_RGB8)
	var layouts: Array[SheetLayout] = [SheetLayout.fit(Rect2(0.0, 0.0, 10.0, 10.0))]
	preview.show_sheets([image], layouts)
	assert_false(preview.get_ok_button().disabled)
	preview.rendering()
	assert_true(preview.get_ok_button().disabled, "nothing to save until the new sheets are there")
	assert_null(preview._picture.texture, "the sheet rendered before is not shown")


func test_empty_switchboards_have_no_sheet() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add_switchboard(Vector2.ZERO)
	assert_false(SheetRenderer.available(doc)["switchboards"], "an empty switchboard")
	var full: SchematicDocument = ExampleCircuits.build(0)
	assert_true(SheetRenderer.available(full)["switchboards"])


func test_compact_plc_title_for_every_cpu() -> void:
	var title: String = ""
	for entry: Dictionary in Palette.ENTRIES:
		if entry["template"].get("family", "") == "compact":
			title = entry["title"]
	for cpu: String in CompactPlc.CPU_NAMES:
		var sheet: Datasheet = _plc({"type": "plc", "family": "compact", "cpu": cpu}, [])
		assert_eq(sheet.title, title, cpu)


func test_no_datasheet_text_past_the_margins() -> void:
	for locale: String in ["en", "cs"]:
		TranslationServer.set_locale(locale)
		for sheet: Datasheet in _all_sheets():
			for page: DatasheetLayout in DatasheetLayout.compose(sheet):
				for item: Dictionary in page.items:
					if item["type"] != "text":
						continue
					var rect: Rect2 = item["rect"]
					var inside: bool = rect.position.x >= DatasheetLayout.MARGIN - 0.5 and rect.end.x <= DatasheetLayout.PAGE.x - DatasheetLayout.MARGIN + 0.5
					assert_true(inside, "%s %s page %d: %s" % [locale, sheet.title, page.page_number, item["text"]])


func test_a_heading_never_ends_a_datasheet_page() -> void:
	for locale: String in ["en", "cs"]:
		TranslationServer.set_locale(locale)
		for sheet: Datasheet in _all_sheets():
			var headings: PackedStringArray = PackedStringArray()
			for row: PackedStringArray in sheet.terminals:
				if row[0].is_empty():
					headings.append(row[1])
			for page: DatasheetLayout in DatasheetLayout.compose(sheet):
				# The last text of the terminal table on the page.
				var last: String = ""
				for item: Dictionary in page.items:
					if item["type"] == "text" and item["color"] == DatasheetLayout.Ink.TEAL and item["size"] != 18 and item["size"] != 12:
						last = item["text"]
				assert_false(headings.has(last), "%s %s page %d ends with %s" % [locale, sheet.title, page.page_number, last])


func test_coil_lists_its_main_contacts() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(7)
	var coil: Coil = null
	for c: CircuitComponent in doc.circuit.get_components():
		if c is Coil and c.designation == "KM1":
			coil = c
	var listed: PackedStringArray = PackedStringArray()
	for row: PackedStringArray in Datasheet.of(coil, doc).terminals:
		listed.append(row[0])
	for terminal: String in ["1", "2", "3", "4", "5", "6", "13", "14"]:
		assert_has(listed, terminal, "terminal %s of KM1" % terminal)


func test_front_labels_clear_of_each_other() -> void:
	var sheets: Array[Datasheet] = [
		_plc({"type": "plc", "family": "compact", "cpu": "14di10dq"}, ["sm_di8dq8", "sm_ai4"]),
		_plc({"type": "plc", "family": "compact", "cpu": "14di10dq"}, ["sm_di8dq8", "sm_di8dq8", "sm_di8dq8", "sm_di8dq8", "sm_di8dq8", "sm_di8dq8", "sm_di8dq8", "sm_di8dq8"]),
		_plc({"type": "plc"}, ["8di8dq", "8di8dq"]),
	]
	for entry: Dictionary in Palette.ENTRIES:
		if entry["template"]["type"] == "vfd":
			sheets.append(Datasheet.of_template(entry["template"]))
	for sheet: Datasheet in sheets:
		var pages: Array[DatasheetLayout] = DatasheetLayout.compose(sheet)
		var area: Rect2 = pages[-1].item("front")["rect"]
		var device: Vector2 = CabinetParts.device_size(sheet.front)
		var k: float = DatasheetFront.scale_for(device, area.size)
		var room: float = (area.size.y - device.y * k) * 0.5 - 12.0
		var points: Dictionary = CabinetParts.terminal_points(int(sheet.front["kind"]), sheet.front)
		for top: bool in [true, false]:
			var side: Array = []
			for name: String in points:
				var p: Vector3 = points[name]
				if (p.y < device.y * 0.5) == top:
					side.append([name, p.x * k])
			side.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
			var names: PackedStringArray = PackedStringArray()
			var xs: PackedFloat32Array = PackedFloat32Array()
			for t: Array in side:
				names.append(t[0])
				xs.append(t[1])
			var arranged: Dictionary = DatasheetFront.arrange(names, xs, room)
			var labels: Array = arranged["labels"]
			for i: int in labels.size():
				var others: Array = labels.slice(0, i) + labels.slice(i + 1)
				var label: Array = labels[i]
				assert_true(DatasheetFront._free(others, label[0], label[1], label[2], label[3]), "%s label %s" % [sheet.title, names[i]])
				assert_true(float(label[0] + 1) * float(arranged["depth"]) <= room, "%s label %s within the room" % [sheet.title, names[i]])


func test_long_station_title_keeps_the_next_station_away() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	var long: ControlBox = doc.add_control_box("Main control of the conveyor line number two", 1)
	long.items = [ControlBoxItem.new(ControlBoxItem.Kind.LAMP, "H1", "green")]
	var next: ControlBox = doc.add_control_box("", 1)
	next.items = [ControlBoxItem.new(ControlBoxItem.Kind.BUTTON, "SB1", "green")]
	var font: Font = AppTheme.schematic_font()
	var caption: float = font.get_string_size("+" + long.name, HORIZONTAL_ALIGNMENT_LEFT, -1, StationsSheet.CAPTION_SIZE).x + StationsSheet.CAPTION_GAP
	caption += font.get_string_size(long.title, HORIZONTAL_ALIGNMENT_LEFT, -1, StationsSheet.CAPTION_SIZE - 2).x
	assert_gt(caption, StationsSheet.box_size(doc, 0).x, "the title is wider than its station")
	var placed: Array = StationsSheet.arrange(doc)[0]
	assert_eq(placed.size(), 2)
	assert_true(placed[1]["at"].x >= placed[0]["at"].x + caption, "the next station starts after the title")


func test_parts_list_cell_shrinks_then_ends_with_an_ellipsis() -> void:
	var font: Font = AppTheme.schematic_font()
	var short: Dictionary = PartsSheet.fit(font, "-KM1", 100.0)
	assert_eq([short["text"], short["size"]], ["-KM1", PartsSheet.TEXT_SIZE])
	var text: String = "CGSG-J 12x2,5   +RA1 – +ST1, green, Start of the conveyor forwards, 230 V AC"
	var width: float = 200.0
	var fitted: Dictionary = PartsSheet.fit(font, text, width)
	assert_eq(fitted["size"], PartsSheet.MIN_TEXT_SIZE)
	assert_true(str(fitted["text"]).ends_with("…"))
	assert_true(font.get_string_size(fitted["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fitted["size"]).x <= width)


func test_pdf_date_has_its_time_zone() -> void:
	var t: Dictionary = {"year": 2026, "month": 3, "day": 14, "hour": 9, "minute": 30, "second": 5}
	assert_eq(PdfWriter.date_text(t, 60), "D:20260314093005+01'00'")
	assert_eq(PdfWriter.date_text(t, -330), "D:20260314093005-05'30'")
	assert_eq(PdfWriter.date_text(t, 0), "D:20260314093005Z")


func test_example_texts_in_czech() -> void:
	TranslationServer.set_locale("cs")
	var doc: SchematicDocument = ExampleCircuits.build(0)
	var lamp: Lamp = doc.circuit.get_component("H1") as Lamp
	assert_eq(lamp.purpose, "Běží")
	var stop: String = ""
	for box: ControlBox in ExampleCircuits.build(1).control_boxes:
		for item: ControlBoxItem in box.items:
			if item.designation == "SB0":
				stop = item.label
	assert_eq(stop, String(TranslationServer.translate("Stop")))


## Datasheets of every palette part, every time relay function and PLCs
## with many modules.
func _all_sheets() -> Array[Datasheet]:
	var sheets: Array[Datasheet] = []
	for entry: Dictionary in Palette.ENTRIES:
		sheets.append(Datasheet.of_template(entry["template"]))
	var timer: Datasheet = Datasheet.of_template({"type": "timer"})
	for mode: int in TimerRelay.Mode.values():
		(timer.component as TimerRelay).mode = mode as TimerRelay.Mode
		sheets.append(Datasheet.of(timer.component, timer.document))
	for cpu: String in CompactPlc.CPU_NAMES:
		sheets.append(_plc({"type": "plc", "family": "compact", "cpu": cpu}, ["sm_di8dq8", "sm_di8dq8", "sm_ai4", "sm_aq2", "sm_di8", "sm_dq8", "sm_ai4", "sm_aq2"]))
	sheets.append(_plc({"type": "plc"}, ["8di8dq", "8di8dq", "2ai", "2aq", "2ai", "2aq"]))
	var doc: SchematicDocument = ExampleCircuits.build(9)
	for c: CircuitComponent in doc.circuit.get_components():
		if c is Coil or c is TimerRelay:
			sheets.append(Datasheet.of(c, doc))
	return sheets


## The datasheet of a PLC made from [param template] with [param modules].
func _plc(template: Dictionary, modules: Array) -> Datasheet:
	var d: Dictionary = template.duplicate()
	d["designation"] = "A1"
	d["modules"] = modules
	var c: CircuitComponent = DocumentSerializer.component_from_dict(d)
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(c, Vector2i.ZERO)
	return Datasheet.of(c, doc)
