extends GutTest
## The single-line diagram of a residential installation's consumer unit:
## circuits and RCD groups in columns, wired from the diagram with N and PE
## (never drawn), the main switch, the ripple control contact, saving,
## moving, renaming and taking parts away, and the diagram in the main window.

const Main: GDScript = preload("res://ui/main.gd")
const MAIN_SCENE: String = "res://main.tscn"


func after_all() -> void:
	RecoveryFile.forget()
	get_tree().auto_accept_quit = true


func _component(template: Dictionary, designation: String) -> CircuitComponent:
	var data: Dictionary = template.duplicate()
	data["designation"] = designation
	return DocumentSerializer.component_from_dict(data)


## A residential installation: FA1 (B10) feeding luminaire EA1; RCD FB1
## with FA2 (B16) feeding socket XD1 under it; FA3 (B16, ripple control)
## feeding water heater EB1.
func _house() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	doc.update_single_line()
	var line: SingleLine = doc.single_line
	assert_true(line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 10.0}, "FA1"), 0))
	assert_true(line.add(doc, _component({"type": "luminaire"}, "EA1"), 0, -1, "FA1"))
	assert_true(line.add(doc, _component({"type": "rcd", "poles": 2}, "FB1"), 1))
	assert_true(line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 16.0}, "FA2"), 0, 1))
	assert_true(line.add(doc, _component({"type": "socket", "gangs": 1}, "XD1"), 0, -1, "FA2"))
	assert_true(line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 16.0}, "FA3"), 2))
	assert_true(line.add(doc, _component({"type": "appliance", "kind": "water_heater"}, "EB1"), 0, -1, "FA3"))
	line.feeder_of("FA3").hdo = true
	line.wire(doc)
	return doc


func _switch_all_on(circuit: Circuit) -> void:
	for c: CircuitComponent in circuit.get_components():
		if c is CircuitBreaker:
			(c as CircuitBreaker).switched_on = true
		elif c is MotorBreaker:
			(c as MotorBreaker).switched_on = true
		elif c is CamSwitch:
			(c as CamSwitch).position = CamSwitch.ONE


func test_columns_and_phases() -> void:
	var doc: SchematicDocument = _house()
	var line: SingleLine = doc.single_line
	assert_eq(line.columns.size(), 3, "a circuit, a group, a circuit")
	assert_true(line.columns[1] is SingleLine.Group)
	assert_eq(line.feeders().size(), 3)
	assert_eq(line.group_holding(line.feeder_of("FA2")), line.group_of("FB1"))
	assert_eq(line.feeder_of("FA2").phase, line.group_of("FB1").phase, "under a two-pole RCD on its phase")
	# Phases taken in turn, the least used first.
	assert_ne(line.feeder_of("FA1").phase, line.group_of("FB1").phase)
	assert_eq(line.cable_number(line.feeder_of("FA3")), 3)
	assert_eq(SingleLine.cable_text(line.feeder_of("FA1"), doc.circuit), "CYKY-J 3×1,5", "10 A: 1.5 mm²")
	assert_eq(SingleLine.cable_text(line.feeder_of("FA2"), doc.circuit), "CYKY-J 3×2,5")
	assert_false(line.add(doc, _component({"type": "breaker", "poles": 3}, "FA4"), 0, 1), "no three-pole circuit under a two-pole RCD")
	assert_null(doc.circuit.get_component("FA4"))
	assert_false(line.add(doc, _component({"type": "rcd", "poles": 2}, "FB2"), 0, 1), "no group in a group")


func test_wired_with_n_and_pe_and_simulated() -> void:
	var doc: SchematicDocument = _house()
	for designation: String in SingleLine.SUPPLIES:
		assert_not_null(doc.circuit.get_component(designation), "supply %s made" % designation)
	assert_true(doc.circuit.get_component(SingleLine.MAIN) is CamSwitch, "the main switch")
	assert_true(doc.circuit.get_component(SingleLine.HDO) is LatchingSwitch, "a ripple control contact")
	var circuit: Circuit = doc.circuit
	_switch_all_on(circuit)
	var sim: Simulator = Simulator.new(circuit)
	sim.step()
	assert_true((circuit.get_component("EA1") as Luminaire).energized, "the light")
	assert_true((circuit.get_component("XD1") as SocketOutlet).energized, "the socket, through the RCD's N")
	assert_false((circuit.get_component("EB1") as Appliance).energized, "the water heater waits for low tariff")
	(circuit.get_component(SingleLine.HDO) as LatchingSwitch).toggle()
	sim.step()
	assert_true((circuit.get_component("EB1") as Appliance).energized, "on low tariff")
	# The RCD's test button trips it: the socket goes dead, the light stays.
	assert_true((circuit.get_component("FB1") as ResidualCurrentDevice).test())
	sim.step()
	assert_false((circuit.get_component("XD1") as SocketOutlet).energized)
	assert_true((circuit.get_component("EA1") as Luminaire).energized)
	# The main switch off: everything dead.
	(circuit.get_component(SingleLine.MAIN) as CamSwitch).position = CamSwitch.OFF
	sim.step()
	assert_false((circuit.get_component("EA1") as Luminaire).energized)


func test_three_pole_hob_and_four_pole_group() -> void:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	var line: SingleLine = doc.single_line
	assert_true(line.add(doc, _component({"type": "rcd", "poles": 4}, "FB1"), 0))
	assert_true(line.add(doc, _component({"type": "breaker", "poles": 3, "characteristic": "B", "rated_current": 16.0}, "FA1"), 0, 0))
	assert_true(line.add(doc, _component({"type": "appliance", "kind": "hob"}, "EB1"), 0, -1, "FA1"))
	assert_eq(line.phases_of(line.feeder_of("FA1"), doc.circuit), PackedInt32Array([1, 2, 3]))
	assert_eq(SingleLine.cable_text(line.feeder_of("FA1"), doc.circuit), "CYKY-J 5×2,5")
	_switch_all_on(doc.circuit)
	Simulator.new(doc.circuit).step()
	assert_true((doc.circuit.get_component("EB1") as Appliance).energized, "the hob between L1 and L2")


func test_saved_and_loaded() -> void:
	var doc: SchematicDocument = _house()
	doc.single_line.feeder_of("FA2").destination = "Kitchen"
	doc.single_line.feeder_of("FA2").room = "Kitchen"
	doc.single_line.supply_cable = "CYKY-J 5×16"
	var data: Dictionary = DocumentSerializer.to_dict(doc)
	assert_eq(data["environment"], "installation")
	var again: SchematicDocument = DocumentSerializer.from_dict(data)
	assert_eq(again.environment, SchematicDocument.Kind.RESIDENTIAL)
	assert_eq(again.single_line.columns.size(), 3)
	assert_eq(again.single_line.feeder_of("FA2").destination, "Kitchen")
	assert_eq(again.single_line.feeder_of("FA2").room, "Kitchen")
	assert_eq(again.single_line.feeder_of("FA3").loads, PackedStringArray(["EB1"]))
	assert_true(again.single_line.feeder_of("FA3").hdo)
	assert_eq(again.single_line.supply_cable, "CYKY-J 5×16")
	assert_eq(again.get_wire_count(), doc.get_wire_count(), "wired the same")
	# A residential prototype saved before version 41 said "residential".
	var old: SchematicDocument = DocumentSerializer.from_dict({"title": "x", "components": [], "wires": [], "environment": "residential"})
	assert_eq(old.environment, SchematicDocument.Kind.PROTOTYPE)
	var prototype: SchematicDocument = SchematicDocument.new("p")
	prototype.residential = true
	assert_eq(DocumentSerializer.to_dict(prototype)["environment"], "prototype")


func test_moved_renamed_and_removed() -> void:
	var doc: SchematicDocument = _house()
	var line: SingleLine = doc.single_line
	# FA3 into the group, then FA1 after the group.
	assert_true(line.move(doc, "FA3", 1, 1))
	assert_eq(line.group_of("FB1").feeders.size(), 2)
	assert_eq(line.group_of("FB1").feeders[1].device, "FA3")
	assert_true(line.move(doc, "FA1", 1))
	assert_true(line.columns[0] is SingleLine.Group)
	assert_eq((line.columns[1] as SingleLine.Feeder).device, "FA1")
	assert_false(line.move(doc, "FB1", 0, 0), "a group never goes into a group")
	line.set_phase(doc, "FB1", 3)
	for f: SingleLine.Feeder in line.group_of("FB1").feeders:
		assert_eq(f.phase, 3, "its circuits along")
	var breaker: CircuitComponent = doc.circuit.get_component("FA1")
	var renamed: CircuitComponent = _component(DocumentSerializer.component_to_dict(breaker), "FA9")
	assert_true(doc.replace_component(breaker.id, renamed))
	assert_not_null(line.feeder_of("FA9"), "the diagram follows a rename")
	# The RCD taken away: its circuits stay where it was.
	doc.remove_component(doc.circuit.get_component("FB1").id)
	doc.update_single_line()
	assert_null(line.group_of("FB1"))
	assert_eq(line.columns.size(), 3)
	assert_not_null(line.feeder_of("FA2"))
	doc.remove_component(doc.circuit.get_component("XD1").id)
	assert_true(line.feeder_of("FA2").loads.is_empty(), "a part taken away is no longer fed")


func test_single_line_in_the_main_window() -> void:
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	add_child_autofree(main)
	main._recovery_dialog.hide()
	TranslationServer.set_locale("en")
	main._new_document(SchematicDocument.Kind.RESIDENTIAL)
	assert_eq(main.edit_doc.environment, SchematicDocument.Kind.RESIDENTIAL)
	assert_true(main._single_line.visible, "the single-line diagram in place of the schematic")
	assert_false(main.view.visible)
	assert_eq(main._palette.entries(), Palette.INSTALLATION_ENTRIES)
	var canvas: SingleLineCanvas = main._single_line.canvas
	await wait_process_frames(2)
	# A breaker put under the busbars, a socket onto its circuit.
	main._palette.template_chosen.emit(Palette.INSTALLATION_ENTRIES[0]["template"])
	assert_false(canvas.placing.is_empty())
	canvas._place(canvas.at(SingleLineCanvas.BREAKER_U, SingleLineCanvas.SPACING))
	assert_eq(main.edit_doc.single_line.feeders().size(), 1, "a circuit, undoably")
	var breaker: String = main.edit_doc.single_line.feeders()[0].device
	canvas.end_place()
	canvas.begin_place({"type": "socket", "gangs": 1})
	canvas._layout()
	var v: float = canvas._circuits[0]["v"]
	canvas._place(canvas.at(SingleLineCanvas.LOAD_U, v))
	assert_eq(main.edit_doc.single_line.feeder_of(breaker).loads.size(), 1)
	main.editor.undo()
	assert_true(main.edit_doc.single_line.feeder_of(breaker).loads.is_empty(), "undone")
	main.editor.redo()
	# Selected on the diagram, its properties show.
	canvas.end_place()
	canvas._select(breaker)
	assert_eq(main.editor.selected_components.size(), 1)
	# While simulating the main switch and the breaker switch the socket on.
	main._set_mode(Main.Mode.SIMULATE)
	await wait_process_frames(2)
	assert_false(canvas.editing)
	canvas._operate(canvas.at(SingleLineCanvas.MAIN_U + 30.0, SingleLineCanvas.MAIN_V))
	canvas._operate(canvas.at(SingleLineCanvas.BREAKER_U + 30.0, v))
	var socket: SocketOutlet = null
	for c: CircuitComponent in main.view.document.circuit.get_components():
		if c is SocketOutlet:
			socket = c as SocketOutlet
	assert_true(socket.energized, "switched on from the diagram")
	await wait_process_frames(2)


func test_single_line_sheet_in_the_export() -> void:
	var renderer: SheetRenderer = autofree(SheetRenderer.new())
	var doc: SchematicDocument = _house()
	var kinds: PackedStringArray = PackedStringArray()
	for spec: Dictionary in renderer.sheets(doc, PackedInt32Array([0])):
		kinds.append(spec["kind"])
	assert_eq(kinds, PackedStringArray(["single_line"]), "the diagram in place of the pages")
	var canvas: SingleLineCanvas = autofree(SingleLineCanvas.new())
	canvas.document = doc
	var area: Rect2 = canvas.extent()
	canvas._layout()
	for entry: Dictionary in canvas._circuits:
		assert_true(area.has_point(Vector2(entry["v"], SingleLineCanvas.LOAD_U)), "every circuit on the sheet")
	assert_true(area.has_point(Vector2(SingleLineCanvas.MAIN_V, SingleLineCanvas.SUPPLY_U)), "the supply too")
