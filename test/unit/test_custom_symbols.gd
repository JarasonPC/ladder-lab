extends GutTest
## The user's own floor plan symbols: drawn from lines, shapes, curves and
## text, kept in a library by category, put on the plan as drawings (marks)
## or as loads on a circuit, saved with the schematic.

const LIBRARY: String = "user://test_symbols.json"

var _library: SymbolLibrary


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LIBRARY))
	_library = SymbolLibrary.new()
	_library.path = LIBRARY
	SymbolLibrary.set_shared(_library)


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LIBRARY))
	SymbolLibrary.set_shared(null)
	RecoveryFile.forget()


func _shape(kind: String, points: Array[Vector2]) -> CustomSymbol.Shape:
	var shape: CustomSymbol.Shape = CustomSymbol.Shape.new()
	shape.kind = kind
	shape.points = PackedVector2Array(points)
	return shape


## A TV socket: a box with "TV" in it, on a wall, in category "Data".
func _tv() -> CustomSymbol:
	var def: CustomSymbol = CustomSymbol.new()
	def.id = CustomSymbol.new_id()
	def.name = "TV socket"
	def.category = "Data"
	def.wall = true
	def.shapes.append(_shape("rect", [Vector2(-0.1, 0.0), Vector2(0.1, 0.15)]))
	var label: CustomSymbol.Shape = _shape("text", [Vector2(0.0, 0.075)])
	label.text = "TV"
	def.shapes.append(label)
	return def


## A ceiling fan: an electrical symbol of a circle and an arc, 60 W.
func _fan() -> CustomSymbol:
	var def: CustomSymbol = CustomSymbol.new()
	def.id = CustomSymbol.new_id()
	def.name = "Ceiling fan"
	def.category = "Ventilation"
	def.electrical = true
	def.power = 60.0
	var round: CustomSymbol.Shape = _shape("ellipse", [Vector2(-0.12, -0.12), Vector2(0.12, 0.12)])
	round.filled = true
	def.shapes.append(round)
	def.shapes.append(_shape("arc", [Vector2(-0.2, 0.0), Vector2(0.0, -0.2), Vector2(0.2, 0.0)]))
	def.shapes.append(_shape("curve", [Vector2(-0.2, 0.2), Vector2(0.0, 0.0), Vector2(0.2, 0.2)]))
	return def


func _component(template: Dictionary, designation: String) -> CircuitComponent:
	var data: Dictionary = template.duplicate()
	data["designation"] = designation
	return DocumentSerializer.component_from_dict(data)


## A residential installation of two rooms with FA1 (B16) for the new parts.
func _house() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Living room", Rect2(0, 0, 4, 3)))
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Bedroom", Rect2(4, 0, 3, 3)))
	assert_true(doc.single_line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 16.0}, "FA1"), 0))
	return doc


func test_shapes_saved_and_read_back() -> void:
	var def: CustomSymbol = _fan()
	var again: CustomSymbol = CustomSymbol.from_data(JSON.parse_string(JSON.stringify(def.to_data())))
	assert_eq(again.id, def.id)
	assert_eq(again.name, "Ceiling fan")
	assert_eq(again.category, "Ventilation")
	assert_true(again.electrical)
	assert_almost_eq(again.power, 60.0, 1e-6)
	assert_eq(again.shapes.size(), 3)
	assert_true(again.shapes[0].filled)
	assert_eq(again.shapes[1].kind, "arc")
	assert_almost_eq(again.shapes[2].points[1].y, 0.0, 1e-6)
	var tv: CustomSymbol = CustomSymbol.from_data(_tv().to_data())
	assert_true(tv.wall)
	assert_eq(tv.shapes[1].text, "TV")
	assert_almost_eq(tv.shapes[1].size, CustomSymbol.TEXT_SIZE, 1e-6)
	# Damaged shapes are left out, a symbol without an id is no symbol.
	var raw: Dictionary = def.to_data()
	raw["shapes"].append({"kind": "spiral", "points": [[0, 0]]})
	raw["shapes"].append({"kind": "line", "points": [[0, 0]]})
	raw["shapes"].append({"kind": "line", "points": [[0, 0], ["a", 1]]})
	raw["shapes"].append({"kind": "text", "points": [[0, 0]]})
	assert_eq(CustomSymbol.from_data(raw).shapes.size(), 3)
	assert_null(CustomSymbol.from_data({"name": "x"}))
	assert_null(CustomSymbol.from_data("x"))


func test_arcs_curves_bounds_and_picking() -> void:
	# An arc through the top of a circle of 0.2 m round the origin.
	var arc: PackedVector2Array = CustomSymbol.arc_points(Vector2(-0.2, 0.0), Vector2(0.0, -0.2), Vector2(0.2, 0.0))
	assert_almost_eq(arc[0].x, -0.2, 1e-5)
	assert_almost_eq(arc[arc.size() - 1].x, 0.2, 1e-5)
	for p: Vector2 in arc:
		assert_almost_eq(p.length(), 0.2, 1e-5, "on the circle")
		assert_true(p.y <= 1e-5, "over the top, through the middle point")
	assert_eq(CustomSymbol.arc_points(Vector2(0, 0), Vector2(1, 1), Vector2(2, 2)).size(), 2, "three points in line: a line")
	var def: CustomSymbol = _fan()
	var box: Rect2 = def.bounds()
	assert_almost_eq(box.position.x, -0.2, 1e-5)
	assert_almost_eq(box.position.y, -0.2, 1e-5)
	assert_almost_eq(box.end.y, 0.2, 1e-5)
	assert_eq(def.shape_at(Vector2(0.2, 0.2), 0.01), 2, "the curve's end")
	assert_eq(def.shape_at(Vector2(0.05, 0.05), 0.01), 0, "inside the filled circle")
	assert_eq(def.shape_at(Vector2(0.0, -0.2), 0.01), 1, "on the arc")
	assert_eq(def.shape_at(Vector2(1.0, 1.0), 0.01), -1)
	assert_eq(CustomSymbol.new().bounds().size, Vector2(0.2, 0.2), "a small box without shapes")


func test_library_kept_by_category_in_its_file() -> void:
	var tv: CustomSymbol = _tv()
	var fan: CustomSymbol = _fan()
	var other: CustomSymbol = _tv()
	other.name = "Data socket"
	other.category = ""
	var changes: Array[int] = [0]
	_library.changed.connect(func() -> void: changes[0] += 1)
	_library.put(tv)
	_library.put(fan)
	_library.put(other)
	assert_eq(changes[0], 3)
	assert_eq(_library.categories(), PackedStringArray(["", "Data", "Ventilation"]))
	var names: PackedStringArray = []
	for def: CustomSymbol in _library.sorted():
		names.append(def.name)
	assert_eq(names, PackedStringArray(["Data socket", "TV socket", "Ceiling fan"]), "by category, then by name")
	# Changed in place, kept apart from the copy put in.
	tv.name = "TV and satellite socket"
	assert_eq(_library.find(tv.id).name, "TV socket", "a copy is kept")
	_library.put(tv)
	assert_eq(_library.symbols.size(), 3)
	assert_eq(_library.find(tv.id).name, "TV and satellite socket")
	var read: SymbolLibrary = SymbolLibrary.new()
	read.path = LIBRARY
	read.load_file()
	assert_eq(read.symbols.size(), 3, "written to its file")
	assert_eq(read.find(fan.id).shapes.size(), 3)
	_library.remove(fan.id)
	read.load_file()
	assert_null(read.find(fan.id))
	assert_eq(read.categories(), PackedStringArray(["", "Data"]))


func test_marks_on_walls_moved_with_rooms_and_saved() -> void:
	var doc: SchematicDocument = _house()
	var plan: FloorPlan = doc.floor_plan
	var tv: CustomSymbol = _tv()
	doc.use_symbol(tv)
	# On a wall: onto the nearest one, facing into the room.
	var mark: FloorPlan.Mark = plan.mark_at_point(tv.id, Vector2(1.0, 2.8), true)
	assert_eq(mark.at, Vector2(1.0, 3.0))
	assert_eq(mark.facing, 3, "facing up into the room")
	plan.marks.append(mark)
	var free: FloorPlan.Mark = plan.mark_at_point(tv.id, Vector2(2.02, 1.53), false)
	assert_eq(free.facing, -1)
	assert_true(free.at.is_equal_approx(Vector2(2.0, 1.55)), "where it was put, snapped")
	plan.marks.append(free)
	plan.move_mark(0, Vector2(0.2, 1.0))
	assert_eq(plan.marks[0].at, Vector2(0.0, 1.0), "moved, onto the left wall")
	assert_eq(plan.marks[0].facing, 0)
	plan.move_room(0, Vector2(0.0, 1.0))
	assert_eq(plan.marks[0].at, Vector2(0.0, 2.0), "with its room")
	assert_true(plan.marks[1].at.is_equal_approx(Vector2(2.0, 2.55)))
	plan.set_edge(0, 3, -0.5)
	assert_eq(plan.marks[0].at, Vector2(-0.5, 2.0), "with its wall")
	var again: FloorPlan = FloorPlan.from_data(JSON.parse_string(JSON.stringify(plan.to_data())))
	assert_eq(again.marks.size(), 2)
	assert_eq(again.marks[0].symbol, tv.id)
	assert_eq(again.marks[0].facing, 0)
	assert_eq(again.marks[1].facing, -1)
	var only_marks: FloorPlan = FloorPlan.new()
	only_marks.marks.append(free)
	assert_false(only_marks.is_empty())


func test_schematic_keeps_the_symbols_it_uses() -> void:
	var doc: SchematicDocument = _house()
	var tv: CustomSymbol = _tv()
	var fan: CustomSymbol = _fan()
	var unused: CustomSymbol = _tv()
	_library.put(tv)
	_library.put(fan)
	doc.use_symbol(tv)
	doc.use_symbol(unused)
	doc.floor_plan.marks.append(doc.floor_plan.mark_at_point(tv.id, Vector2(1.0, 0.1), true))
	var fan_template: Dictionary = Palette.symbol_entries()[1]["template"]
	assert_eq(fan_template["symbol"], fan.id, "the fan comes after the TV socket: by category")
	var designation: String = FloorPlanCanvas.add_part(doc, fan_template, 1, Vector2(2.0, 1.5))
	assert_eq(designation, "EB1")
	assert_true(doc.symbols.has(fan.id), "taken into the schematic when put in")
	assert_eq(doc.used_symbols(), PackedStringArray([tv.id, fan.id] if tv.id < fan.id else [fan.id, tv.id]), "not the one put on nothing")
	# Saved and read back on a computer without the library.
	var text: String = JSON.stringify(ProjectFile.to_dict(doc))
	_library.remove(tv.id)
	_library.remove(fan.id)
	var read: Dictionary = ProjectFile.parse(text)
	var opened: SchematicDocument = read["document"]
	assert_eq(opened.symbols.size(), 2)
	assert_eq(opened.symbol(fan.id).name, "Ceiling fan")
	assert_eq(opened.floor_plan.marks.size(), 1)
	var part: Appliance = opened.circuit.get_component("EB1") as Appliance
	assert_eq(part.symbol, fan.id)
	assert_eq(part.title, "Ceiling fan")
	assert_true(part.ceiling, "a symbol not on a wall goes on the ceiling")
	assert_almost_eq(part.power, 60.0, 1e-6)
	# A new drawing of it renames its loads.
	var renamed: CustomSymbol = fan.copy()
	renamed.name = "Fan"
	opened.use_symbol(renamed)
	assert_eq((opened.circuit.get_component("EB1") as Appliance).title, "Fan")


func test_electrical_symbol_is_a_load_on_its_circuit() -> void:
	var doc: SchematicDocument = _house()
	var fan: CustomSymbol = _fan()
	fan.wall = true
	fan.power = 2300.0
	_library.put(fan)
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.editing = true
	canvas.size = Vector2(800, 600)
	canvas.tool = FloorPlanCanvas.Tool.PLACE
	canvas.placing_template = Palette.symbol_entries()[0]["template"]
	canvas.circuit = 1
	assert_false(canvas._template_on_ceiling(canvas.placing_template), "on a wall")
	var edits: Array[Callable] = []
	canvas.edit_requested.connect(func(change: Callable) -> void: edits.append(change))
	canvas._press_at = canvas.to_screen(Vector2(1.0, 0.2))
	canvas._release({"kind": "new_part"}, canvas._press_at)
	for change: Callable in edits:
		change.call(doc)
	doc.update_single_line()
	assert_eq(doc.single_line.feeder_of("FA1").loads, PackedStringArray(["EB1"]), "on the circuit chosen")
	assert_eq(doc.floor_plan.parts["EB1"], Vector2(1.0, 0.0), "onto the wall")
	assert_eq(doc.floor_plan.facing["EB1"], 1)
	assert_eq(doc.single_line.tag("EB1", doc.circuit), "Z 1.1", "tagged as an appliance")
	for c: CircuitComponent in doc.circuit.get_components():
		if c is CircuitBreaker:
			(c as CircuitBreaker).switched_on = true
		elif c is CamSwitch:
			(c as CamSwitch).position = CamSwitch.ONE
	var sim: Simulator = Simulator.new(doc.circuit)
	var result: StepResult = sim.step()
	var part: Appliance = doc.circuit.get_component("EB1") as Appliance
	assert_true(part.energized, "wired to its circuit and working")
	assert_almost_eq(part.rated_draw(), 10.0, 1e-6, "2300 W at 230 V")
	assert_not_null(result)
	# Its name everywhere it is listed.
	assert_eq(Datasheet.of(part, doc).title, "Ceiling fan")
	assert_eq(ApplianceSymbol.title_of(part), "Ceiling fan")
	var rows: Array[Dictionary] = canvas.legend_rows()
	var titles: PackedStringArray = []
	for row: Dictionary in rows:
		titles.append(str(row["title"]))
	assert_true(titles.has("Ceiling fan"), "in the legend")


func test_marks_put_from_the_palette_found_and_in_the_legend() -> void:
	var doc: SchematicDocument = _house()
	var tv: CustomSymbol = _tv()
	_library.put(tv)
	var entries: Array[Dictionary] = Palette.symbol_entries()
	assert_eq(entries.size(), 1)
	assert_eq(entries[0]["group"], "custom:Data")
	assert_eq(entries[0]["template"], {"type": "custom_symbol", "symbol": tv.id})
	var palette: Palette = autofree(Palette.new())
	palette.environment = SchematicDocument.Kind.RESIDENTIAL
	palette.plan = true
	var parts: int = Palette.PLAN_ENTRIES.filter(func(entry: Dictionary) -> bool: return Palette.entry_group(entry) != "furniture").size()
	assert_eq(palette.entries().size(), parts + 1, "the plan's parts, then the user's symbols")
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.editing = true
	canvas.size = Vector2(800, 600)
	canvas.tool = FloorPlanCanvas.Tool.PLACE
	canvas.placing_template = entries[0]["template"]
	var edits: Array[Callable] = []
	canvas.edit_requested.connect(func(change: Callable) -> void: edits.append(change))
	for at: Vector2 in [Vector2(1.0, 0.2), Vector2(2.0, 0.2)]:
		canvas._press_at = canvas.to_screen(at)
		canvas._release({"kind": "new_part"}, canvas._press_at)
	for change: Callable in edits:
		change.call(doc)
	assert_eq(doc.floor_plan.marks.size(), 2)
	assert_true(doc.symbols.has(tv.id))
	assert_eq(doc.floor_plan.marks[1].at, Vector2(2.0, 0.0), "onto the wall")
	# Found under the mouse (hanging from the wall into the room), in the
	# legend with their count.
	canvas.tool = FloorPlanCanvas.Tool.SELECT
	var inside: Vector2 = canvas.to_screen(Vector2(2.0, 0.1))
	assert_eq(canvas.mark_at(inside), 1)
	assert_eq(canvas._pressed(inside)["kind"], "mark")
	var found: bool = false
	for row: Dictionary in canvas.legend_rows():
		if row["title"] == "TV socket":
			found = true
			assert_eq(row["count"], 2)
	assert_true(found, "in the legend")
	canvas.selected = {"kind": "mark", "index": 0}
	canvas.delete_selected()
	edits.back().call(doc)
	assert_eq(doc.floor_plan.marks.size(), 1)


func test_symbol_canvas_draws_and_undoes() -> void:
	var canvas: SymbolCanvas = autofree(SymbolCanvas.new())
	canvas.size = Vector2(600, 400)
	var def: CustomSymbol = CustomSymbol.new()
	canvas.edit(def)
	canvas.tool = SymbolCanvas.Tool.LINE
	canvas._press_at = canvas.to_screen(Vector2(-0.1, 0.0))
	canvas._release({"kind": "new"}, canvas.to_screen(Vector2(0.1, 0.0)))
	assert_eq(def.shapes.size(), 1)
	assert_eq(def.shapes[0].kind, "line")
	# An arc: dragged end to end, then clicked where it goes through.
	canvas.tool = SymbolCanvas.Tool.ARC
	canvas._press_at = canvas.to_screen(Vector2(-0.1, 0.1))
	canvas._release({"kind": "new"}, canvas.to_screen(Vector2(0.1, 0.1)))
	assert_eq(def.shapes.size(), 1, "waits for its middle point")
	assert_eq(canvas._pressed(canvas.to_screen(Vector2(0.0, 0.2)))["kind"], "middle")
	canvas._release({"kind": "middle"}, canvas.to_screen(Vector2(0.0, 0.2)))
	assert_eq(def.shapes.size(), 2)
	assert_eq(def.shapes[1].kind, "arc")
	assert_almost_eq(def.shapes[1].points[1].y, 0.2, 1e-6)
	canvas.tool = SymbolCanvas.Tool.TEXT
	canvas.text = "SD"
	canvas._release({"kind": "new"}, canvas.to_screen(Vector2(0.0, -0.1)))
	assert_eq(def.shapes[2].text, "SD")
	canvas.undo()
	assert_eq(def.shapes.size(), 2)
	canvas.redo()
	assert_eq(def.shapes.size(), 3)
	# Picked and moved, a point dragged by its handle.
	canvas.tool = SymbolCanvas.Tool.SELECT
	assert_eq(canvas._pressed(canvas.to_screen(Vector2(0.05, 0.0)))["kind"], "shape")
	assert_eq(canvas.selected, 0)
	canvas._dragging = true
	canvas._press_at = canvas.to_screen(Vector2(0.05, 0.0))
	canvas._release({"kind": "shape"}, canvas.to_screen(Vector2(0.05, 0.05)))
	assert_almost_eq(def.shapes[0].points[0].y, 0.05, 1e-6, "moved")
	assert_eq(canvas.handle_at(canvas.to_screen(Vector2(0.1, 0.05))), 1)
	canvas._release({"kind": "handle", "which": 1}, canvas.to_screen(Vector2(0.2, 0.05)))
	assert_almost_eq(def.shapes[0].points[1].x, 0.2, 1e-6)
	canvas.delete_selected()
	assert_eq(def.shapes.size(), 2)
	canvas.undo()
	assert_eq(def.shapes.size(), 3)


func test_designations_clear_their_symbols_at_any_size() -> void:
	var doc: SchematicDocument = _house()
	var wide: CustomSymbol = CustomSymbol.new()
	wide.id = CustomSymbol.new_id()
	wide.name = "Heat pump"
	wide.electrical = true
	wide.wall = true
	wide.shapes.append(_shape("rect", [Vector2(-0.5, 0.0), Vector2(0.5, 0.4)]))
	_library.put(wide)
	var pump: String = FloorPlanCanvas.add_part(doc, Palette.symbol_entries()[0]["template"], 1, Vector2(2.0, 0.1))
	var socket: String = FloorPlanCanvas.add_part(doc, {"type": "socket", "gangs": 1}, 1, Vector2(5.5, 0.1))
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.size = Vector2(1200, 800)
	var font: Font = ThemeDB.fallback_font
	for size: float in [1.0, 2.0]:
		doc.floor_plan.symbol_scale = size
		var s: float = FloorPlanCanvas.PX * canvas.zoom * size
		var ascent: float = font.get_ascent(canvas._sized(FloorPlanCanvas.TEXT_SIZE))
		canvas._taken = [canvas._symbol_box(pump, s), canvas._symbol_box(socket, s)]
		# A palette symbol's designation just into the room, as before.
		var center: Vector2 = canvas.to_screen(canvas.symbol_center(socket))
		var spot: Vector2 = canvas._label_spot(socket, center, Vector2.DOWN, "-" + socket, "", s, font)
		assert_almost_eq(spot.y, center.y + 0.22 * s + 2.0 + ascent, 0.01, "into the room, the first spot (size %s)" % size)
		# The user's wide symbol: just under its drawing, not over it.
		var own: Rect2 = canvas._symbol_box(pump, s)
		center = canvas.to_screen(canvas.symbol_center(pump))
		spot = canvas._label_spot(pump, center, Vector2.DOWN, "-" + pump, "", s, font)
		assert_almost_eq(spot.y - ascent, own.end.y + 0.02 * s + 2.0, 0.01, "past its own box (size %s)" % size)


func test_symbols_exported_and_imported() -> void:
	var tv: CustomSymbol = _tv()
	var fan: CustomSymbol = _fan()
	_library.put(tv)
	_library.put(fan)
	var file: String = "user://test_export." + SymbolLibrary.EXTENSION
	assert_eq(_library.export_file(file), OK)
	var only_data: String = "user://test_export_data." + SymbolLibrary.EXTENSION
	assert_eq(_library.export_file(only_data, PackedStringArray([tv.id])), OK)
	# Someone else's library takes them in.
	var other: SymbolLibrary = SymbolLibrary.new()
	other.path = "user://test_other_symbols.json"
	var mine: CustomSymbol = _tv()
	mine.name = "My own"
	other.put(mine)
	var changes: Array[int] = [0]
	other.changed.connect(func() -> void: changes[0] += 1)
	var result: Dictionary = other.import_file(only_data)
	assert_eq(result["added"], PackedStringArray([tv.id]), "only the category exported")
	assert_eq(other.symbols.size(), 2, "added to what it had")
	assert_eq(changes[0], 1)
	# The whole file: what it has already is drawn as in the file.
	tv.shapes.clear()
	_library.put(tv)
	assert_eq(_library.export_file(file), OK)
	result = other.import_file(file)
	assert_eq(result["added"], PackedStringArray([fan.id]))
	assert_eq(result["replaced"], PackedStringArray([tv.id]))
	assert_eq(other.find(tv.id).shapes.size(), 0, "the file's drawing")
	assert_eq(other.find(fan.id).shapes.size(), 3)
	assert_true(other.find(fan.id).electrical)
	var read: SymbolLibrary = SymbolLibrary.new()
	read.path = other.path
	read.load_file()
	assert_eq(read.symbols.size(), 3, "kept in its file")
	# Files that are not symbols, or from a newer version, are refused.
	var junk: String = "user://test_junk." + SymbolLibrary.EXTENSION
	ProjectFile.write_atomically(junk, "{\"format\": \"ladder-lab\", \"symbols\": []}")
	assert_true(other.import_file(junk).has("error"))
	ProjectFile.write_atomically(junk, JSON.stringify({"format": SymbolLibrary.FORMAT, "version": SymbolLibrary.VERSION + 1, "symbols": []}))
	assert_eq(other.import_file(junk)["error"], "%s was saved by a newer version of LadderLab.")
	assert_true(other.import_file("user://test_missing." + SymbolLibrary.EXTENSION).has("error"))
	assert_eq(other.symbols.size(), 3, "nothing taken from them")
	for path: String in [file, only_data, junk, other.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
