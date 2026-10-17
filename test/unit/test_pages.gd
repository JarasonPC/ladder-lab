extends GutTest
## Schematics on several pages joined by page connectors, and the export
## of the pages (sheet layout, PDF file).

const ExamplePower = preload("res://test/unit/example_power.gd")

const NO := SwitchingElement.ContactType.NO


## Page 0: L - RB1 - connector [param label_a]. Page 1: connector
## [param label_b] - H1 - N.
func _two_pages(label_a: String = "5", label_b: String = "5") -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("pages")
	doc.pages = PackedStringArray(["Control circuit", "Signalling circuit"])
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	doc.add(LatchingSwitch.new("RB1", NO), Vector2i(5, 2))
	doc.add(PageConnector.new("PC1", label_a), Vector2i(5, 8), 2)
	doc.connect_terminals("L", "RB1:13", [Vector2i(5, 1)] as Array[Vector2i])
	doc.connect_terminals("RB1:14", "PC1")
	doc.page = 1
	doc.add(PageConnector.new("PC2", label_b), Vector2i(5, 3))
	doc.add(Lamp.new("H1"), Vector2i(5, 5))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, 12))
	doc.connect_terminals("PC2", "H1:X1")
	doc.connect_terminals("H1:X2", "N", [Vector2i(5, 12)] as Array[Vector2i])
	doc.page = 0
	return doc


func test_connectors_with_the_same_label_join_the_pages() -> void:
	var doc: SchematicDocument = _two_pages()
	var sim: Simulator = Simulator.new(doc.circuit)
	(doc.circuit.get_component("RB1") as LatchingSwitch).set_switched_on(true)
	var r: StepResult = sim.step()
	assert_true((doc.circuit.get_component("H1") as Lamp).energized, "the lamp on page 2 lights")
	assert_eq(sim.get_net_of("RB1:14"), sim.get_net_of("H1:X1"))
	assert_has(r.current_components, "H1", "current flows through the link")
	assert_eq(r.current_wires.size(), doc.get_wire_count(), "on both pages")
	assert_eq(r.terminal_reach.get("PC2", 0), StepResult.REACH_L1)


func test_connectors_with_other_labels_stay_apart() -> void:
	var doc: SchematicDocument = _two_pages("5", "6")
	(doc.circuit.get_component("RB1") as LatchingSwitch).set_switched_on(true)
	Simulator.new(doc.circuit).step()
	assert_false((doc.circuit.get_component("H1") as Lamp).energized)
	# Relabelling the connector links the pages again.
	var sim: Simulator = Simulator.new(doc.circuit)
	doc.circuit.set_connector_label(doc.circuit.get_component("PC2") as PageConnector, "5")
	sim.step()
	assert_true((doc.circuit.get_component("H1") as Lamp).energized)


func test_queries_look_at_the_current_page() -> void:
	var doc: SchematicDocument = _two_pages()
	assert_eq(doc.page_of("H1"), 1)
	assert_eq(doc.wire_page(0), 0)
	assert_eq(doc.wires_on_page(0), PackedInt32Array([0, 1]))
	assert_eq(doc.wires_on_page(1), PackedInt32Array([2, 3]))
	assert_eq(doc.component_at(Vector2(5, 3.5)), doc.circuit.get_component("RB1"))
	assert_eq(doc.terminal_at(Vector2(5, 5)), "RB1:14")
	doc.page = 1
	assert_eq(doc.component_at(Vector2(5, 6.5)), doc.circuit.get_component("H1"))
	assert_eq(doc.terminal_at(Vector2(5, 5)), "H1:X1")
	assert_eq(doc.wire_at(Vector2(5, 4)), 2)
	assert_true(doc.bounds().has_point(Vector2(5, 7)))
	assert_lt(doc.bounds(0).end.y, 10.0, "page 1 ends below its connector")
	assert_gte(doc.bounds(1).end.y, 12.0, "page 2 reaches down to N")
	doc.add(Lamp.new("H2"), Vector2i(9, 5))
	assert_eq(doc.page_of("H2"), 1, "new parts go on the page shown")
	doc.page = 7
	assert_eq(doc.page, 1, "clamped to the pages there are")


func test_page_editing_keeps_parts_on_their_pages() -> void:
	var doc: SchematicDocument = _two_pages()
	doc.page = 1
	assert_eq(doc.add_page("Power circuit", 0), 0)
	assert_eq(doc.pages, PackedStringArray(["Power circuit", "Control circuit", "Signalling circuit"]))
	assert_eq(doc.page, 2, "the page shown stays the same page")
	assert_eq(doc.page_of("RB1"), 1)
	assert_eq(doc.page_of("H1"), 2)
	doc.move_page(2, 0)
	assert_eq(doc.pages, PackedStringArray(["Signalling circuit", "Power circuit", "Control circuit"]))
	assert_eq(doc.page_of("H1"), 0)
	assert_eq(doc.page_of("RB1"), 2)
	assert_eq(doc.page, 0)
	doc.rename_page(1, "  Power  ")
	assert_eq(doc.pages[1], "Power")
	assert_true(doc.remove_page(0))
	assert_null(doc.circuit.get_component("H1"), "parts of a removed page go with it")
	assert_null(doc.circuit.get_component("PC2"))
	assert_eq(doc.get_wire_count(), 2)
	assert_eq(doc.page_of("RB1"), 1)
	assert_true(doc.remove_page(0))
	assert_false(doc.remove_page(0), "the last page stays")
	assert_eq(doc.pages, PackedStringArray(["Control circuit"]))
	assert_eq(doc.page_name(0), "Control circuit")
	doc.rename_page(0, "")
	assert_eq(doc.page_name(0), "Page 1")


func test_pages_are_saved_and_checked() -> void:
	var doc: SchematicDocument = _two_pages()
	doc.page = 1
	var data: Dictionary = DocumentSerializer.to_dict(doc)
	var copy: SchematicDocument = DocumentSerializer.from_dict(data)
	assert_eq(DocumentSerializer.to_dict(copy), data)
	assert_eq(copy.pages, doc.pages)
	assert_eq(copy.page, 1)
	assert_eq(copy.page_of("H1"), 1)
	assert_eq((copy.circuit.get_component("PC2") as PageConnector).label, "5")
	var bad_page: Dictionary = data.duplicate(true)
	bad_page["components"][3]["page"] = 2
	assert_null(DocumentSerializer.from_dict(bad_page), "a page that does not exist")
	var across: Dictionary = data.duplicate(true)
	across["wires"].append({"a": "RB1:13", "b": "H1:X2", "corners": []})
	assert_null(DocumentSerializer.from_dict(across), "a wire between two pages")
	var text: String = '{"format": "ladder-lab", "version": 10, "document": {"title": "old", "components": [{"type": "lamp", "designation": "H1", "cell": [0, 0]}], "wires": []}}'
	var old: SchematicDocument = ProjectFile.parse(text)["document"]
	assert_eq(old.pages, PackedStringArray([""]), "older files have one page")
	assert_eq(old.page_of("H1"), 0)


func test_numbering_runs_over_the_pages() -> void:
	var doc: SchematicDocument = _two_pages("x", "x")
	doc.number_wires()
	assert_eq(doc.get_route(1).number, "1", "RB1:14 - PC1")
	assert_eq(doc.get_route(2).number, "1", "the same net on page 2")
	assert_eq(doc.get_route(0).number, "", "fed straight from L")
	assert_eq(doc.get_route(3).number, "", "fed straight from N")
	assert_eq((doc.circuit.get_component("PC1") as PageConnector).label, "1", "the connectors carry the wire number")
	assert_eq((doc.circuit.get_component("PC2") as PageConnector).label, "1")
	assert_eq(doc.wire_net(1), PackedInt32Array([1, 2]))
	doc.set_wire_number(2, "17")
	assert_eq(doc.get_route(1).number, "17")
	assert_eq((doc.circuit.get_component("PC1") as PageConnector).label, "17")
	assert_eq(doc.circuit.get_links(), [PackedStringArray(["PC1", "PC2"])] as Array[PackedStringArray])
	# The connector shows the number itself, the wire end there does not.
	doc.page = 1
	assert_eq(doc.wire_number_ends(), [Vector2i(2, 1)] as Array[Vector2i])


func test_cross_references_and_new_labels() -> void:
	var doc: SchematicDocument = _two_pages()
	assert_eq(doc.connector_reference("PC1"), "/2.1", "page 2, current path 1")
	assert_eq(doc.connector_reference("PC2"), "/1.1")
	var targets: Array[Dictionary] = doc.connector_targets("PC1")
	assert_eq(targets.size(), 1)
	assert_eq(targets[0]["id"], "PC2")
	doc.add(PageConnector.new("PC3", "8"), Vector2i(12, 8))
	assert_eq(doc.next_connector_label(), "9", "nothing on another page waits for a partner")
	doc.page = 1
	assert_eq(doc.next_connector_label(), "8", "continues the open connector of page 1")
	assert_eq(CircuitCheck.run(doc).size(), 1)
	assert_eq(CircuitCheck.run(doc)[0]["text"], "Page connector %s is not connected to a wire.")
	doc.connect_terminals("PC3", "RB1:13", [Vector2i(12, 1)] as Array[Vector2i])
	assert_eq(CircuitCheck.run(doc)[0]["text"], "Page connector %s does not continue anywhere: no other page connector has its label.")


func test_split_wire_keeps_the_page_of_the_wire() -> void:
	var doc: SchematicDocument = _two_pages()
	var key: String = doc.split_wire(2, Vector2i(5, 4))
	assert_eq(doc.page_of(key), 1, "the junction joins the wire on page 2 while page 1 is shown")


func test_paste_goes_to_the_page_shown() -> void:
	var doc: SchematicDocument = _two_pages()
	var data: Dictionary = doc.extract(PackedStringArray(["H1", "PC2"]))
	doc.page = 0
	var ids: PackedStringArray = doc.insert(data, Vector2i(10, 0))
	assert_eq(ids, PackedStringArray(["PC3", "H2"]))
	for id: String in ids:
		assert_eq(doc.page_of(id), 0)
	assert_eq(doc.get_wire_count(), 5)


func test_example_on_three_pages_works_together() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.direct_on_line_pages())
	assert_eq(doc.pages.size(), 3)
	assert_eq(doc.page_of("M1"), 0)
	assert_eq(doc.page_of("KM1"), 1)
	assert_eq(doc.page_of("H3"), 2)
	var label: String = (doc.circuit.get_component("PC1") as PageConnector).label
	assert_false(label.is_empty())
	assert_eq((doc.circuit.get_component("PC2") as PageConnector).label, label)
	assert_eq(CircuitCheck.run(doc), [] as Array[Dictionary])
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.mode = Simulator.Mode.IDEAL
	sim.step()
	assert_true((doc.circuit.get_component("H1") as Lamp).energized, "control voltage shown on the signalling page")
	assert_false((doc.circuit.get_component("H3") as Lamp).energized)
	(doc.circuit.get_component("SB1") as PushButton).press()
	sim.step()
	(doc.circuit.get_component("SB1") as PushButton).release()
	sim.step()
	assert_true(doc.circuit.get_coil("KM1").energized, "KM1 holds")
	assert_true((doc.circuit.get_component("H3") as Lamp).energized, "running lamp on page 3")
	assert_eq((doc.circuit.get_component("M1") as ThreePhaseMotor).state, ThreePhaseMotor.State.RUNNING, "the motor on page 1 runs")


func test_sheet_layout_picks_the_paper() -> void:
	var small: SheetLayout = SheetLayout.fit(Rect2(0, 0, 30, 20))
	assert_eq(small.paper_name, "A4")
	assert_false(small.portrait)
	assert_almost_eq(small.cell_mm, SheetLayout.CELL_MM, 1e-6)
	assert_almost_eq(small.sheet.size.x, 297.0 / 5.0, 1e-4)
	assert_true(small.frame.encloses(Rect2(0, 0, 30, 20)))
	assert_true(small.title_block.end.y <= small.frame.end.y + 1e-4)
	assert_true(small.title_block.position.y >= 20.0, "the title block is below the drawing")
	var tall: SheetLayout = SheetLayout.fit(Rect2(0, 0, 20, 40))
	assert_eq(tall.paper_name, "A4")
	assert_true(tall.portrait)
	var wide: SheetLayout = SheetLayout.fit(Rect2(0, 0, 70, 40))
	assert_eq(wide.paper_name, "A3")
	assert_almost_eq(wide.cell_mm, SheetLayout.CELL_MM, 1e-6)
	var huge: SheetLayout = SheetLayout.fit(Rect2(-10, -10, 200, 60))
	assert_eq(huge.paper_name, "A3")
	assert_lt(huge.cell_mm, SheetLayout.CELL_MM, "scaled down to fit")
	assert_true(huge.frame.encloses(Rect2(-10, -10, 200, 60)))
	assert_almost_eq(huge.paper_points().x, 420.0 / 25.4 * 72.0, 1e-3)


func test_pdf_file_structure() -> void:
	var pdf: PdfWriter = PdfWriter.new()
	pdf.title = "Ovládací část"
	var image: Image = Image.create(8, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	pdf.add_page(image, Vector2(841.89, 595.28))
	pdf.add_page(image, Vector2(595.28, 841.89))
	var bytes: PackedByteArray = pdf.to_bytes()
	# Binary bytes as dots, so text positions are byte offsets.
	var plain: PackedByteArray = bytes.duplicate()
	for i: int in plain.size():
		if plain[i] == 0 or plain[i] > 127:
			plain[i] = 0x2E
	var text: String = plain.get_string_from_ascii()
	assert_true(text.begins_with("%PDF-1.4"))
	assert_true(text.ends_with("%%EOF\n"))
	assert_string_contains(text, "/Count 2")
	assert_string_contains(text, "/MediaBox [0 0 595.28 841.89]")
	assert_string_contains(text, PdfWriter.text_string("Ovládací část"))
	assert_eq(PdfWriter.text_string("Aá"), "<FEFF004100E1>")
	# Every entry of the cross-reference table points at its object.
	var tail: String = text.substr(text.rfind("startxref"))
	var xref: int = int(tail.split("\n")[1])
	assert_eq(bytes.slice(xref, xref + 4).get_string_from_ascii(), "xref")
	var rows: PackedStringArray = text.substr(xref).split("\n")
	var count: int = int(rows[1].split(" ")[1])
	assert_eq(count, 10, "catalog, pages, info and three objects per page")
	for n: int in range(1, count):
		var offset: int = int(rows[2 + n].substr(0, 10))
		assert_eq(text.substr(offset, ("%d 0 obj" % n).length()), "%d 0 obj" % n, "object %d at its offset" % n)
	# The picture is zlib data (FlateDecode) of the RGB pixels.
	var start: int = text.find("stream\n", text.find("/Subtype /Image")) + 7
	var length_at: int = text.find("/Length ", text.find("/Subtype /Image")) + 8
	var length: int = int(text.substr(length_at, 12))
	var pixels: PackedByteArray = bytes.slice(start, start + length).decompress(8 * 6 * 3, FileAccess.COMPRESSION_DEFLATE)
	assert_eq(pixels.size(), 8 * 6 * 3)
	assert_eq(Array(pixels.slice(0, 3)), [255, 0, 0])
	assert_eq(bytes[start], 0x78, "zlib header")


func test_page_window_view_follows_the_main_view() -> void:
	var main_view: SchematicView = SchematicView.new()
	add_child_autofree(main_view)
	main_view.load_document(_two_pages(), true)
	main_view.simulator.mode = Simulator.Mode.IDEAL
	main_view.running = false
	var window_view: SchematicView = SchematicView.new()
	window_view.page = 1
	add_child_autofree(window_view)
	window_view.follow(main_view)
	assert_eq(main_view.document.page, 0, "the main window still shows page 1")
	assert_not_null(window_view.get_symbol("H1"), "the window shows page 2")
	assert_null(window_view.get_symbol("L"))
	assert_not_null(main_view.get_symbol("L"))
	var events: Array = []
	main_view.event_logged.connect(func(text: String, _args: Array) -> void: events.append(text))
	# Operated in the window, the main simulation goes on.
	(main_view.document.circuit.get_component("RB1") as LatchingSwitch).set_switched_on(true)
	window_view._apply(window_view.simulator.step())
	assert_true((main_view.document.circuit.get_component("H1") as Lamp).energized)
	assert_eq(main_view.last_result, window_view.last_result, "the main view shows the step too")
	assert_eq(window_view.get_symbol("H1").live[0], StepResult.REACH_L1)
	window_view._log("Fault removed", [])
	assert_eq(events, ["Fault removed"], "logged through the main view")
	# A document loaded in the main view is followed.
	main_view.load_document(_two_pages(), false)
	assert_eq(window_view.document, main_view.document)
	assert_false(window_view.simulating)
	assert_not_null(window_view.get_symbol("H1"))
	# A removed page: the window shows the last one left.
	main_view.document.remove_page(1)
	main_view.rebuild()
	assert_eq(window_view.page, 0)
	assert_not_null(window_view.get_symbol("L"))
