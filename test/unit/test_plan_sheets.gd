extends GutTest
## The sheets of a house installation's floor plan: the legend of the
## symbols used with their counts, the lighting and socket plans apart,
## printed at a true scale with the Czech title block, and the bill of
## materials with the boxes and cable metres.


func _component(template: Dictionary, designation: String) -> CircuitComponent:
	var data: Dictionary = template.duplicate()
	data["designation"] = designation
	return DocumentSerializer.component_from_dict(data)


## A room 6 × 4 with the consumer unit, a breaker FA1 feeding a switch, two
## luminaires and a wall luminaire, and FA2 feeding two sockets and a double one.
func _house() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	var line: SingleLine = doc.single_line
	line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 10.0}, "FA1"), 0)
	line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 16.0}, "FA2"), 1)
	var plan: FloorPlan = doc.floor_plan
	plan.rooms.append(FloorPlan.Room.new("Living room", Rect2(0, 0, 6, 4)))
	plan.place(FloorPlan.UNIT, Vector2(0.0, 3.0), false)
	FloorPlanCanvas.add_part(doc, {"type": "light_switch", "circuit": "1"}, "FA1", Vector2(0.0, 1.0))
	FloorPlanCanvas.add_part(doc, {"type": "luminaire"}, "FA1", Vector2(2.0, 2.0))
	FloorPlanCanvas.add_part(doc, {"type": "luminaire"}, "FA1", Vector2(4.0, 2.0))
	FloorPlanCanvas.add_part(doc, {"type": "luminaire", "wall": true}, "FA1", Vector2(6.0, 2.0))
	FloorPlanCanvas.add_part(doc, {"type": "socket", "gangs": 1}, "FA2", Vector2(2.0, 4.0))
	FloorPlanCanvas.add_part(doc, {"type": "socket", "gangs": 1}, "FA2", Vector2(3.0, 4.0))
	FloorPlanCanvas.add_part(doc, {"type": "socket", "gangs": 2}, "FA2", Vector2(4.0, 4.0))
	plan.add_link("SF1", 0, "EA1", 0)
	line.wire(doc)
	return doc


func test_legend_of_what_is_on_the_sheet() -> void:
	var doc: SchematicDocument = _house()
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.legend = true
	var titles: PackedStringArray = PackedStringArray()
	var counts: Array[int] = []
	for row: Dictionary in canvas.legend_rows():
		titles.append(row["title"])
		counts.append(row["count"])
	assert_eq(titles.size(), 7, "switch, socket, double socket, luminaire, wall luminaire, unit, cable")
	assert_eq(counts, [1, 2, 1, 2, 1, 1, 0])
	# The lighting plan: no sockets.
	canvas.layer = "lighting"
	assert_false(canvas.layer_shows("XD1"))
	assert_true(canvas.layer_shows("SF1"))
	assert_true(canvas.layer_shows(FloorPlan.UNIT))
	assert_eq(canvas.legend_rows().size(), 5)
	canvas.layer = "power"
	assert_eq(canvas.legend_rows().size(), 3, "the sockets and the unit")


func test_sheets_apart_at_a_true_scale() -> void:
	var doc: SchematicDocument = _house()
	doc.title_block.stage = "DPS"
	var renderer: SheetRenderer = autofree(SheetRenderer.new())
	add_child(renderer)
	renderer.schematic = false
	renderer.workspace = true
	renderer.split_plan = true
	var layers: PackedStringArray = PackedStringArray()
	for spec: Dictionary in renderer.sheets(doc, PackedInt32Array([0])):
		layers.append(spec.get("layer", ""))
	assert_eq(layers, PackedStringArray(["lighting", "power"]))
	var sheet: Dictionary = renderer._sheet(DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc)), {"kind": "floor_plan", "floor": 0}, 0, 1)
	var frame: SheetFrame = sheet["frame"]
	assert_eq(frame.scale_text, "1:50", "a small house at 1:50")
	var layout: SheetLayout = frame.layout
	assert_almost_eq(FloorPlanCanvas.PX / float(SymbolGeometry.GRID) * layout.cell_mm, 20.0, 1e-4, "20 mm a metre")
	assert_eq(frame.block.stage, "DPS")
	(sheet["viewport"] as Node).queue_free()


func test_bill_of_materials_and_csv() -> void:
	var doc: SchematicDocument = _house()
	var rows: Array[Dictionary] = PartsList.new().rows(doc)
	var headings: PackedStringArray = PackedStringArray()
	var material: Dictionary[String, Dictionary] = {}
	var in_material: bool = false
	for row: Dictionary in rows:
		if row.get("heading", false):
			headings.append(row["text"])
			in_material = row["text"] == "Installation material"
		elif in_material:
			material[str(row["name"]) + " " + str(row["data"]).get_slice(" ", 0)] = row
	assert_true(headings.has("On the floor plan"))
	assert_true(headings.has("Installation material"))
	assert_eq(int(material["Wall box KU 68 for"]["quantity"]), 5, "the switch, two sockets and a double one")
	assert_eq(int(material["Luminaire box on"]["quantity"]), 3)
	var cables: Array[Dictionary] = PartsList.cable_totals(doc)
	assert_eq(cables.size(), 2, "1.5 mm² for the lighting, 2.5 mm² for the sockets")
	assert_eq(cables[0]["type"], "CYKY-J 3×1,5")
	assert_gt(int(cables[0]["metres"]), 0)
	var csv: String = PartsList.to_csv(rows, PackedStringArray(["Place", "Designation", "Quantity", "Name", "Data"]))
	assert_true(csv.begins_with("Place,Designation,Quantity,Name,Data\n"))
	assert_true(csv.contains("Installation material,"), "each row with its place")
	assert_eq(PartsList._csv_row(PackedStringArray(["a, b", "say \"hi\""])), "\"a, b\",\"say \"\"hi\"\"\"")
