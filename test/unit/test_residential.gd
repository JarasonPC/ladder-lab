extends GutTest
## House installations: schematics chosen as residential at File > New,
## their palette, light switches numbered as Czech installations number them
## (řazení 1, 2, 3, 5, 5A, 5B, 6, 7), luminaires and type E socket outlets
## with their mounting heights; how they switch, are saved, drawn and
## operated.

const Main: GDScript = preload("res://ui/main.gd")
const MAIN_SCENE: String = "res://main.tscn"
const SETTINGS: String = "user://settings.cfg"

var _settings: String = ""
var _had_settings: bool = false
var _locale: String = ""


func before_all() -> void:
	_had_settings = FileAccess.file_exists(SETTINGS)
	if _had_settings:
		_settings = FileAccess.get_file_as_string(SETTINGS)
	_locale = TranslationServer.get_locale()


func after_all() -> void:
	if _had_settings:
		var file: FileAccess = FileAccess.open(SETTINGS, FileAccess.WRITE)
		file.store_string(_settings)
		file.close()
	elif FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(SETTINGS)
	RecoveryFile.forget()
	TranslationServer.set_locale(_locale)
	get_tree().auto_accept_quit = true


## The pairs of terminals [param sw] joins now.
func _closed(sw: LightSwitch) -> Array[String]:
	var names: PackedStringArray = sw.get_terminal_names()
	var result: Array[String] = []
	var paths: Array[Vector2i] = sw.switch_paths()
	for i: int in paths.size():
		if sw.is_path_closed(i):
			result.append("%s-%s" % [names[paths[i].x], names[paths[i].y]])
	return result


func test_switch_numbers() -> void:
	var one: LightSwitch = LightSwitch.new("SF1")
	assert_eq(one.get_terminal_names(), PackedStringArray(["1", "2"]), "marked as ČSN EN 60669-1 marks them")
	assert_eq(_closed(one), [] as Array[String], "starts off")
	one.toggle()
	assert_eq(_closed(one), ["1-2"] as Array[String])
	var two_pole: LightSwitch = LightSwitch.new("SF2", "2")
	two_pole.toggle()
	assert_eq(_closed(two_pole), ["1-2", "3-4"] as Array[String])
	var four_pole: LightSwitch = LightSwitch.new("SF3", "03")
	four_pole.toggle()
	assert_eq(_closed(four_pole), ["1-2", "3-4", "5-6", "7-8"] as Array[String])
	var with_off: LightSwitch = LightSwitch.new("SF4", "4")
	var seen: Array = []
	for i: int in 4:
		with_off.toggle()
		seen.append(_closed(with_off))
	assert_eq(seen, [["1-2"], [], ["1-3"], []], "to 2, off, to 3, off")
	var series: LightSwitch = LightSwitch.new("SF5", "5")
	assert_eq(series.rocker_count(), 2)
	series.toggle(1)
	assert_eq(_closed(series), ["1-3"] as Array[String], "each rocker its own output")
	series.toggle(0)
	assert_eq(_closed(series), ["1-2", "1-3"] as Array[String])
	var double_two_way: LightSwitch = LightSwitch.new("SF6", "5B")
	assert_eq(_closed(double_two_way), ["1-2", "4-5"] as Array[String], "6+6 at rest")
	double_two_way.toggle(1)
	assert_eq(_closed(double_two_way), ["1-2", "4-6"] as Array[String])
	var staircase: LightSwitch = LightSwitch.new("SF7", "6")
	assert_eq(_closed(staircase), ["1-2"] as Array[String], "at rest on 2")
	staircase.toggle()
	assert_eq(_closed(staircase), ["1-3"] as Array[String], "switched over to 3, never both")
	var two_pole_two_way: LightSwitch = LightSwitch.new("SF8", "6/2")
	assert_eq(_closed(two_pole_two_way), ["1-3", "2-4"] as Array[String])
	two_pole_two_way.toggle()
	assert_eq(_closed(two_pole_two_way), ["1-5", "2-6"] as Array[String])
	var intermediate: LightSwitch = LightSwitch.new("SF9", "7")
	assert_eq(_closed(intermediate), ["1-2", "3-4"] as Array[String], "straight at rest")
	intermediate.toggle()
	assert_eq(_closed(intermediate), ["1-4", "3-2"] as Array[String], "crosswise switched over")
	intermediate.circuit = "5A"
	assert_eq(intermediate.circuit, "1", "5A (6+1) is not made any more: a one-way switch")
	assert_eq(intermediate.on.size(), 1)


## A corridor lit from three places: two-way switches at the ends, an
## intermediate one between them.
func _corridor() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("corridor")
	doc.residential = true
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 30))
	doc.add(PowerSupply.new("PE", PowerSupply.Conductor.PE), Vector2i(4, 30))
	doc.add(LightSwitch.new("SF1", "6"), Vector2i(0, 4), 2)
	doc.add(LightSwitch.new("SF2", "7"), Vector2i(0, 10))
	doc.add(LightSwitch.new("SF3", "6"), Vector2i(0, 16))
	doc.add(Luminaire.new("EA1"), Vector2i(1, 22))
	for pair: Array in [["L1", "SF1:1"], ["SF1:2", "SF2:1"], ["SF1:3", "SF2:3"],
			["SF2:2", "SF3:2"], ["SF2:4", "SF3:3"], ["SF3:1", "EA1:L"], ["EA1:N", "N"], ["EA1:PE", "PE"]]:
		assert_true(doc.connect_terminals(pair[0], pair[1]), "%s - %s" % pair)
	return doc


func test_corridor_switched_from_any_place() -> void:
	var doc: SchematicDocument = _corridor()
	var lamp: Luminaire = doc.circuit.get_component("EA1") as Luminaire
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.step()
	assert_true(lamp.energized, "all at rest: 2 to 2 straight through, lit")
	for designation: String in ["SF1", "SF2", "SF3", "SF2", "SF1", "SF3"]:
		var was: bool = lamp.energized
		(doc.circuit.get_component(designation) as LightSwitch).toggle()
		var r: StepResult = sim.step()
		assert_false(r.short_circuit)
		assert_ne(lamp.energized, was, "%s switches the light over" % designation)


func test_luminaire_draws_its_power() -> void:
	var lamp: Luminaire = Luminaire.new("EA1")
	assert_eq(lamp.get_terminal_names(), PackedStringArray(["L", "N", "PE"]))
	lamp.power = 230.0
	assert_almost_eq(lamp.rated_draw(), 1.0, 0.0001)
	assert_eq(lamp.rating, "230v")


func test_saved_and_loaded() -> void:
	var doc: SchematicDocument = _corridor()
	(doc.circuit.get_component("SF2") as LightSwitch).height = 1.1
	(doc.circuit.get_component("EA1") as Luminaire).power = 15.0
	doc.add(SocketOutlet.new("XD1", 2), Vector2i(10, 4))
	(doc.circuit.get_component("XD1") as SocketOutlet).height = 1.15
	var data: Dictionary = DocumentSerializer.to_dict(doc)
	assert_eq(data["environment"], "prototype")
	var loaded: SchematicDocument = DocumentSerializer.from_dict(data)
	assert_true(loaded.residential)
	var sw: LightSwitch = loaded.circuit.get_component("SF2") as LightSwitch
	assert_eq(sw.circuit, "7")
	assert_almost_eq(sw.height, 1.1, 0.001)
	assert_almost_eq((loaded.circuit.get_component("SF1") as LightSwitch).height, LightSwitch.STANDARD_HEIGHT, 0.001)
	assert_almost_eq((loaded.circuit.get_component("EA1") as Luminaire).power, 15.0, 0.001)
	var socket: SocketOutlet = loaded.circuit.get_component("XD1") as SocketOutlet
	assert_eq(socket.gangs, 2)
	assert_almost_eq(socket.height, 1.15, 0.001)
	assert_eq(loaded.circuit.get_wires().size(), doc.circuit.get_wires().size())
	data.erase("environment")
	assert_false(DocumentSerializer.from_dict(data).residential, "older files are industrial")
	assert_false(DocumentSerializer.to_dict(SchematicDocument.new()).has("environment"))
	var odd: LightSwitch = DocumentSerializer.component_from_dict({"type": "light_switch", "designation": "SF9", "circuit": "9", "height": -3}) as LightSwitch
	assert_eq(odd.circuit, "1")
	assert_eq(odd.height, 0.0, "heights stay above the floor")


func test_geometry() -> void:
	for circuit: String in LightSwitch.CIRCUITS:
		var sw: LightSwitch = LightSwitch.new("SF1", circuit)
		var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(sw)
		var seen: Dictionary[Vector2i, bool] = {}
		for name: String in sw.get_terminal_names():
			assert_false(seen.has(cells[name]), "%s: terminal %s has a cell of its own" % [circuit, name])
			seen[cells[name]] = true
			var want: int = SymbolGeometry.DIR_DOWN if cells[name].y == 0 else SymbolGeometry.DIR_UP
			assert_eq(SymbolGeometry.local_lead_direction(sw, name), want, "%s: lead of %s" % [circuit, name])
		var body: Rect2 = SymbolGeometry.local_body(sw)
		for rocker: int in sw.rocker_count():
			for x: float in SymbolGeometry.light_switch_pivots(sw, rocker):
				assert_true(body.has_point(Vector2(x / SymbolGeometry.GRID, 1.5)), "%s: the body covers its blades" % circuit)
				assert_eq(SymbolGeometry.light_switch_rocker_at(sw, x), rocker, "%s: a click on a blade switches its rocker" % circuit)
	var socket: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(SocketOutlet.new("XD1"))
	assert_eq(socket["PE"], Vector2i(SymbolGeometry.POLE_SPACING, 0), "the protective pin in the middle")
	for rotation: int in 4:
		for mirrored: bool in [false, true]:
			var p: Placement = Placement.new(Vector2i.ZERO, rotation, mirrored)
			var v: Vector2 = Vector2(1.5, -0.25)
			assert_eq(SymbolGeometry.untransform_point(SymbolGeometry.transform_point(v, p), p), v)


func test_palette_offers_house_parts() -> void:
	var palette: Palette = Palette.new()
	add_child_autofree(palette)
	assert_eq(palette.entries(), Palette.ENTRIES)
	palette.residential = true
	assert_eq(palette.entries(), Palette.RESIDENTIAL_ENTRIES)
	var types: Dictionary[String, bool] = {}
	for entry: Dictionary in Palette.RESIDENTIAL_ENTRIES:
		types[entry["template"]["type"]] = true
		assert_not_null(DocumentSerializer.component_from_dict(entry["template"].merged({"designation": "X1"})), entry["title"])
	assert_false(types.has("coil"), "no contactors")
	for circuit: String in LightSwitch.CIRCUITS:
		assert_not_null(palette.entry_button({"type": "light_switch", "circuit": circuit}), "switch no. " + circuit)
	var titles: Array[String] = []
	for entry: Dictionary in Palette.all_entries():
		assert_false(titles.has(entry["title"]), "%s once in the parts library" % entry["title"])
		titles.append(entry["title"])


func test_placed_with_their_designations() -> void:
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	var editor: SchematicEditor = SchematicEditor.new()
	editor.view = view
	add_child_autofree(editor)
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.residential = true
	view.load_document(doc, false)
	editor.active = true
	var x: int = 2
	for template: Dictionary in [{"type": "light_switch", "circuit": "5B"}, {"type": "luminaire"}, {"type": "socket", "gangs": 1}]:
		editor.begin_place(template)
		editor._mouse_point = Vector2(x, 4)
		editor._mouse_cell = Vector2i(x, 4)
		editor._on_left_pressed(false)
		editor._cancel_tool()
		x += 12
	var circuit: Circuit = editor.document().circuit
	assert_true(circuit.get_component("SF1") is LightSwitch, "light switch SF1")
	assert_eq((circuit.get_component("SF1") as LightSwitch).circuit, "5B")
	assert_true(circuit.get_component("EA1") is Luminaire, "luminaire EA1")
	assert_true(circuit.get_component("XD1") is SocketOutlet, "socket outlet XD1")
	# Another number from the properties keeps the part and its height.
	var data: Dictionary = DocumentSerializer.component_to_dict(circuit.get_component("SF1"))
	data["circuit"] = "6"
	data["height"] = 1.0
	assert_eq(editor.apply_properties(circuit.get_component("SF1").id, data), "")
	var changed: LightSwitch = editor.document().circuit.get_component("SF1") as LightSwitch
	assert_eq(changed.circuit, "6")
	assert_almost_eq(changed.height, 1.0, 0.001)


func test_symbols_draw_and_rockers_are_clicked() -> void:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.residential = true
	var x: int = 2
	for circuit: String in LightSwitch.CIRCUITS:
		doc.add(LightSwitch.new("SF%d" % x, circuit), Vector2i(x, 4))
		x += 10
	doc.add(Luminaire.new("EA1"), Vector2i(2, 12))
	doc.add(SocketOutlet.new("XD1", 2), Vector2i(10, 12))
	(doc.circuit.get_component("XD1") as SocketOutlet).height = 1.2
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(doc, true)
	await wait_process_frames(2)
	for c: CircuitComponent in view.document.circuit.get_components():
		var symbol: SchematicSymbol = view._symbols.get(c.id, null)
		assert_not_null(symbol, c.id)
		assert_true(symbol.marking_rects.size() > 0, "%s drawn with its markings" % c.id)
	assert_eq(LightSwitchSymbol.height_text(1.2), "h = 1.20 m")
	# A click on the right rocker of a 5B switches the second rocker only.
	var series: LightSwitch = null
	for c: CircuitComponent in view.document.circuit.get_components():
		if c is LightSwitch and (c as LightSwitch).circuit == "5B":
			series = c as LightSwitch
	var placed: Placement = view.document.get_placement(series.id)
	var right: float = SymbolGeometry.light_switch_pivots(series, 1)[0]
	var point: Vector2 = (Vector2(placed.cell) * SymbolGeometry.GRID + Vector2(right, 1.5 * SymbolGeometry.GRID))
	assert_eq(SymbolGeometry.light_switch_rocker_at(series, SymbolGeometry.untransform_point(point - Vector2(placed.cell) * SymbolGeometry.GRID, placed).x), 1)


func test_datasheets() -> void:
	for circuit: String in LightSwitch.CIRCUITS:
		var sheet: Datasheet = Datasheet.of_template({"type": "light_switch", "circuit": circuit})
		assert_eq(sheet.letters, "SF")
		assert_eq(sheet.group, "Light switches")
		assert_eq(sheet.terminals.size(), sheet.component.get_terminal_names().size(), "every terminal of no. " + circuit)
	var socket: Datasheet = Datasheet.of_template({"type": "socket", "gangs": 2})
	assert_eq(socket.title, "Double socket outlet 230 V (type E)")
	assert_eq(Datasheet.of_template({"type": "luminaire"}).letters, "EA")


func test_new_residential_schematic_in_the_main_window() -> void:
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	add_child_autofree(main)
	main._recovery_dialog.hide()
	TranslationServer.set_locale("en")
	main._new_document(true)
	assert_true(main.edit_doc.residential)
	assert_true(main._palette.residential, "the palette offers house parts")
	assert_eq(main._workspace_button.text, "Floor plan", "a floor plan in place of the workspace")
	assert_eq(main._environment_label.text, "Prototype residential")
	assert_true(main.edit_doc.circuit.get_component("PE") is PowerSupply, "starts with L, N and PE")
	main._new_document(false)
	assert_false(main._palette.residential)
	assert_eq(main._workspace_button.text, "Workspace")
	assert_eq(main._environment_label.text, "Industrial")
	main._new_dialog.ask()
	assert_true(main._new_dialog.visible)
	main._new_dialog._cards[1].button_pressed = true
	main._new_dialog.get_ok_button().pressed.emit()
	assert_true(main.edit_doc.residential, "Create makes the card chosen")
