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
	assert_true(line.add(doc, _component({"type": "luminaire"}, "EA1"), 0, "", "FA1"))
	assert_true(line.add(doc, _component({"type": "rcd", "poles": 2}, "FB1"), 1))
	assert_true(line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 16.0}, "FA2"), 0, "FB1"))
	assert_true(line.add(doc, _component({"type": "socket", "gangs": 1}, "XD1"), 0, "", "FA2"))
	assert_true(line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 16.0}, "FA3"), 2))
	assert_true(line.add(doc, _component({"type": "appliance", "kind": "water_heater"}, "EB1"), 0, "", "FA3"))
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
	assert_false(line.add(doc, _component({"type": "breaker", "poles": 3}, "FA4"), 0, "FB1"), "no three-pole circuit under a two-pole RCD")
	assert_null(doc.circuit.get_component("FA4"))
	assert_false(line.add(doc, _component({"type": "rcd", "poles": 4}, "FB2"), 0, "FB1"), "no four-pole RCD under a two-pole one")


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
	assert_true(line.add(doc, _component({"type": "breaker", "poles": 3, "characteristic": "B", "rated_current": 16.0}, "FA1"), 0, "FB1"))
	assert_true(line.add(doc, _component({"type": "appliance", "kind": "hob"}, "EB1"), 0, "", "FA1"))
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
	assert_true(line.move(doc, "FA3", 1, "FB1"))
	assert_eq(line.group_of("FB1").items.size(), 2)
	assert_eq((line.group_of("FB1").items[1] as SingleLine.Feeder).device, "FA3")
	assert_true(line.move(doc, "FA1", 1))
	assert_true(line.columns[0] is SingleLine.Group)
	assert_eq((line.columns[1] as SingleLine.Feeder).device, "FA1")
	assert_false(line.move(doc, "FB1", 0, "FB1"), "a group never goes under itself")
	line.set_phase(doc, "FB1", 3)
	for f: RefCounted in line.group_of("FB1").items:
		assert_eq((f as SingleLine.Feeder).phase, 3, "its circuits along")
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
	main._start_dialog.hide()
	TranslationServer.set_locale("en")
	main._new_document(SchematicDocument.Kind.RESIDENTIAL)
	assert_eq(main.edit_doc.environment, SchematicDocument.Kind.RESIDENTIAL)
	assert_eq(main.area, Main.Area.WORKSPACE, "a new house starts on its floor plan")
	main._set_area(Main.Area.SCHEMATIC)
	assert_true(main._single_line.visible, "the single-line diagram in place of the schematic")
	assert_false(main.view.visible)
	assert_eq(main._palette.entries(), Palette.INSTALLATION_ENTRIES)
	var canvas: SingleLineCanvas = main._single_line.canvas
	await wait_process_frames(2)
	# A breaker put under the busbars, a socket onto its circuit.
	main._palette.template_chosen.emit(Palette.INSTALLATION_ENTRIES[1]["template"])
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


## A selective 300 mA four-pole RCD FB1 over a 30 mA two-pole one FB2 with
## breaker FA1 feeding water heater EB1 under it, and breaker FA2 feeding
## socket XD1 under FB1 alone.
func _nested() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	var line: SingleLine = doc.single_line
	assert_true(line.add(doc, _component({"type": "rcd", "poles": 4, "residual": 0.3, "selective": true}, "FB1"), 0))
	assert_true(line.add(doc, _component({"type": "rcd", "poles": 2, "residual": 0.03}, "FB2"), 0, "FB1"))
	assert_true(line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 16.0}, "FA1"), 0, "FB2"))
	assert_true(line.add(doc, _component({"type": "appliance", "kind": "water_heater"}, "EB1"), 0, "", "FA1"))
	assert_true(line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 16.0}, "FA2"), 1, "FB1"))
	assert_true(line.add(doc, _component({"type": "socket", "gangs": 1}, "XD1"), 0, "", "FA2"))
	return doc


func test_rcd_under_rcd_wired_and_selective() -> void:
	var doc: SchematicDocument = _nested()
	var line: SingleLine = doc.single_line
	assert_eq(line.columns.size(), 1)
	assert_eq(line.group_holding(line.group_of("FB2")), line.group_of("FB1"))
	assert_eq(line.depth_of(line.feeder_of("FA1")), 2)
	assert_eq(line.feeder_of("FA1").phase, line.group_of("FB2").phase, "on the phase of the two-pole RCD it is under")
	assert_eq(line.column_of("FA1"), 0)
	var circuit: Circuit = doc.circuit
	_switch_all_on(circuit)
	var sim: Simulator = Simulator.new(circuit)
	sim.step()
	var heater: Appliance = circuit.get_component("EB1") as Appliance
	assert_true(heater.energized, "through both RCDs")
	assert_true((circuit.get_component("XD1") as SocketOutlet).energized)
	# An insulation fault under the 30 mA one: it alone trips, the selective one waits.
	heater.frame_fault = true
	sim.step()
	assert_true((circuit.get_component("FB2") as ResidualCurrentDevice).tripped)
	assert_false((circuit.get_component("FB1") as ResidualCurrentDevice).tripped, "selective: stays on")
	assert_true((circuit.get_component("XD1") as SocketOutlet).energized, "the socket keeps its supply")
	# Not selective, both trip.
	heater.frame_fault = false
	(circuit.get_component("FB1") as ResidualCurrentDevice).selective = false
	# Everything reset (the breaker tripped on the fault current too).
	for c: CircuitComponent in circuit.get_components():
		if c is MotorBreaker:
			(c as MotorBreaker).tripped = false
		elif c is CircuitBreaker:
			(c as CircuitBreaker).tripped = false
	_switch_all_on(circuit)
	sim.step()
	assert_true(heater.energized)
	heater.frame_fault = true
	sim.step()
	assert_true((circuit.get_component("FB1") as ResidualCurrentDevice).tripped, "not selective: trips too")


func test_nested_groups_saved_moved_and_removed() -> void:
	var doc: SchematicDocument = _nested()
	var again: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	var line: SingleLine = again.single_line
	assert_not_null(line.group_of("FB2"))
	assert_eq(line.group_holding(line.group_of("FB2")), line.group_of("FB1"), "saved under it")
	assert_eq(line.group_holding(line.feeder_of("FA1")), line.group_of("FB2"))
	assert_true((again.circuit.get_component("FB1") as ResidualCurrentDevice).selective)
	assert_eq(again.get_wire_count(), doc.get_wire_count())
	line = doc.single_line
	assert_false(line.move(doc, "FB1", 0, "FB2"), "never under one under it")
	# Both circuits together out onto the busbars, in their order.
	assert_true(line.move_many(doc, PackedStringArray(["FA2", "FA1"]), 1))
	assert_eq(line.columns.size(), 3)
	assert_eq((line.columns[1] as SingleLine.Feeder).device, "FA1")
	assert_eq((line.columns[2] as SingleLine.Feeder).device, "FA2")
	# The group moved with what is under it; the one taken away leaves its circuits.
	assert_true(line.move_many(doc, PackedStringArray(["FA1"]), 0, "FB2"))
	doc.remove_component(doc.circuit.get_component("FB2").id)
	doc.update_single_line()
	assert_eq(line.group_holding(line.feeder_of("FA1")), line.group_of("FB1"), "now under the 300 mA one")


func test_rcd_types_and_the_30_ma_rule() -> void:
	var rcd: ResidualCurrentDevice = _component({"type": "rcd", "rcd_type": "B", "selective": true}, "FB1") as ResidualCurrentDevice
	assert_eq(rcd.type, "B")
	assert_eq(rcd.type_text(), "B S")
	for type: String in ["AC", "A", "F", "B", "B+"]:
		var again: ResidualCurrentDevice = _component({"type": "rcd", "rcd_type": type}, "FB1") as ResidualCurrentDevice
		assert_eq(again.type, type)
	var doc: SchematicDocument = _nested()
	var line: SingleLine = doc.single_line
	assert_false(line.lacks_rcd(line.feeder_of("FA1"), doc.circuit), "under the 30 mA one")
	assert_true(line.lacks_rcd(line.feeder_of("FA2"), doc.circuit), "the socket under 300 mA alone")
	assert_almost_eq(line.residual_protection(line.feeder_of("FA2"), doc.circuit), 0.3, 1e-6)


func test_several_selected_dragged_and_deleted() -> void:
	var doc: SchematicDocument = _house()
	var canvas: SingleLineCanvas = autofree(SingleLineCanvas.new())
	canvas.document = doc
	canvas.editing = true
	canvas.size = Vector2(1600, 900)
	var edits: Array[Callable] = []
	canvas.edit_requested.connect(func(change: Callable) -> void: edits.append(change))
	canvas._layout()
	# A box round FA1 and the RCD selects both.
	var fa1: float = canvas._circuit_entry("FA1")["v"]
	var group: Dictionary = canvas._group_entry("FB1")
	canvas._select_box(canvas.at(SingleLineCanvas.RCD_U - 10.0, fa1 - 20.0), canvas.at(SingleLineCanvas.BREAKER_U + 50.0, float(group["v0"]) + 20.0), false)
	assert_eq(canvas.selection, PackedStringArray(["FB1", "FA1"]))
	canvas._toggle("FA3")
	assert_eq(canvas.selection.size(), 3, "Shift+click adds")
	canvas._toggle("FA3")
	assert_eq(canvas.selection.size(), 2, "and takes out")
	# Dragged right of FA3: both go there, in order.
	var fa3: float = canvas._circuit_entry("FA3")["v"]
	canvas._move(canvas._moving_with("FA1"), canvas.at(SingleLineCanvas.BREAKER_U, fa3 + SingleLineCanvas.SPACING))
	assert_eq(edits.size(), 1)
	edits[0].call(doc)
	assert_eq(SingleLine.device_of(doc.single_line.columns[0]), "FA3")
	assert_eq(SingleLine.device_of(doc.single_line.columns[1]), "FA1")
	assert_eq(SingleLine.device_of(doc.single_line.columns[2]), "FB1")
	# Deleted in one edit.
	canvas._layout()
	canvas.selection = PackedStringArray(["FA1", "FA3"])
	canvas.delete_selected()
	assert_eq(edits.size(), 2)
	edits[1].call(doc)
	assert_null(doc.circuit.get_component("FA1"))
	assert_null(doc.circuit.get_component("FA3"))
	assert_null(doc.circuit.get_component("EB1"), "with what it fed, as it is on no floor plan")
	assert_eq(doc.single_line.columns.size(), 1)


func test_ghost_marks_where_it_goes() -> void:
	var doc: SchematicDocument = _house()
	var canvas: SingleLineCanvas = autofree(SingleLineCanvas.new())
	canvas.document = doc
	canvas.editing = true
	canvas._layout()
	var fa3: float = canvas._circuit_entry("FA3")["v"]
	var point: Vector2 = canvas.at(SingleLineCanvas.BREAKER_U, fa3 + SingleLineCanvas.SPACING)
	var template: Dictionary = {"type": "breaker", "characteristic": "B", "rated_current": 16.0}
	var target: Dictionary = canvas.drop_target(point, template)
	assert_eq(target["index"], 3, "after the last column")
	canvas.begin_place(template)
	var preview: Dictionary = canvas._preview(target, template, PackedStringArray())
	var ghost: String = canvas._ghost.designation
	assert_eq(preview["shown"], PackedStringArray([ghost]), "the breaker to be drawn see-through")
	var ghost_v: float = canvas._attach_end(preview["laid"], [SingleLine.Feeder.new(ghost)])
	assert_almost_eq(ghost_v, fa3 + SingleLineCanvas.SPACING, 0.01, "where the new circuit will be")
	doc.single_line.add(doc, _component(template, ghost), target["index"], target["into"])
	canvas._layout()
	assert_almost_eq(float(canvas._circuit_entry(ghost)["v"]), ghost_v, 0.01)
	canvas.end_place()
	# Under the RCD's busbar: into its group, an RCD too.
	var group: Dictionary = canvas._group_entry("FB1")
	var into: Dictionary = canvas.drop_target(canvas.at(SingleLineCanvas.GROUP_BREAKER_U + 10.0, float(group["v0"]) + SingleLineCanvas.SPACING * 0.4), {"type": "rcd", "poles": 2})
	assert_eq(into["into"], "FB1")
	assert_eq(into["index"], 1)
	assert_true(canvas.drop_target(canvas.at(SingleLineCanvas.GROUP_BREAKER_U + 10.0, float(group["v0"])), {"type": "rcd", "poles": 4}).is_empty(), "no four-pole RCD under a two-pole one")


func test_anything_nests_under_a_breaker() -> void:
	var doc: SchematicDocument = _house()
	var line: SingleLine = doc.single_line
	# A main B32 breaker with circuits under it: it heads a group once they are.
	assert_true(line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 32.0}, "FA5"), 0))
	assert_false(line.can_hold("FA1"), "a circuit feeding something holds nothing")
	assert_true(line.can_hold("FA5"))
	assert_true(line.move_many(doc, PackedStringArray(["FA3", "FB1"]), 0, "FA5"))
	assert_not_null(line.group_of("FA5"))
	assert_eq(line.group_holding(line.group_of("FB1")), line.group_of("FA5"))
	assert_eq(line.feeder_of("FA3").phase, line.group_of("FA5").phase, "on the phase of the one-pole breaker")
	assert_false(line.add(doc, _component({"type": "breaker", "poles": 3}, "FA6"), 0, "FA5"), "no three poles under one")
	var circuit: Circuit = doc.circuit
	_switch_all_on(circuit)
	var sim: Simulator = Simulator.new(circuit)
	sim.step()
	assert_true((circuit.get_component("XD1") as SocketOutlet).energized, "through the breaker and the RCD")
	(circuit.get_component("FA5") as CircuitBreaker).switched_on = false
	sim.step()
	assert_false((circuit.get_component("XD1") as SocketOutlet).energized, "the breaker over it off")
	assert_true((circuit.get_component("EA1") as Luminaire).energized, "the light not under it")
	# Everything out again: a circuit once more.
	assert_true(line.move_many(doc, PackedStringArray(["FA3", "FB1"]), 0))
	assert_null(line.group_of("FA5"))
	assert_not_null(line.feeder_of("FA5"))
	# Dropped below its breaker on the diagram.
	var canvas: SingleLineCanvas = autofree(SingleLineCanvas.new())
	canvas.document = doc
	canvas._layout()
	var fa5: float = canvas._circuit_entry("FA5")["v"]
	var target: Dictionary = canvas.drop_target(canvas.at(SingleLineCanvas.BREAKER_U + 90.0, fa5), {"type": "breaker"})
	assert_eq(target["into"], "FA5")
	assert_eq(target["index"], 0)


func test_cable_length_voltage_drop_and_loop_impedance() -> void:
	var doc: SchematicDocument = _house()
	var line: SingleLine = doc.single_line
	var f: SingleLine.Feeder = line.feeder_of("FA2")
	assert_eq(line.cable_length(f, doc), -1.0, "nothing on the plan yet")
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Room", Rect2(0, 0, 20, 10)))
	doc.floor_plan.place(FloorPlan.UNIT, Vector2(0.0, 5.0), false)
	doc.floor_plan.place("XD1", Vector2(10.0, 0.0), false)
	# 10 across, 5 up, the unit's drop 0.9 and the socket's 2.1, a tenth more.
	var length: float = line.cable_length(f, doc)
	assert_almost_eq(length, (10.0 + 5.0 + 0.9 + 2.1) * SingleLine.CABLE_RESERVE, 0.01)
	assert_almost_eq(SingleLine.cable_section("CYKY-J 3×2,5"), 2.5, 1e-6)
	assert_almost_eq(SingleLine.cable_section("CYKY-J 5x1,5"), 1.5, 1e-6)
	# B16 over 2.5 mm²: 2 · L · 16 A · 0.0225 / 2.5 / 230 V.
	var drop: float = line.voltage_drop(f, doc, length)
	assert_almost_eq(drop, 2.0 * length * 16.0 * SingleLine.COPPER / 2.5 / 230.0 * 100.0, 1e-4)
	assert_eq(line.drop_limit(f, doc.circuit), SingleLine.OTHER_DROP)
	assert_eq(line.drop_limit(line.feeder_of("FA1"), doc.circuit), SingleLine.LIGHTING_DROP, "lighting alone")
	assert_true(line.disconnects_in_time(f, doc, length), "B16: 80 A needs at most 2.9 Ω")
	line.supply_impedance = 2.8
	assert_false(line.disconnects_in_time(f, doc, length), "a weak supply")
	var again: SingleLine = SingleLine.from_data(line.to_data())
	assert_almost_eq(again.supply_impedance, 2.8, 1e-6)
	var check: Dictionary = SingleLineView.checks(line, f, doc)
	assert_true(check["bad"])


func test_circuits_numbered_made_on_the_plan_and_protected() -> void:
	var doc: SchematicDocument = _house()
	var line: SingleLine = doc.single_line
	assert_eq(line.feeder_of("FA1").number, 1, "numbered in the order they came")
	assert_eq(line.feeder_of("FA3").number, 3)
	# Parts put on circuit 4, which nothing protects yet.
	doc.add(_component({"type": "socket", "gangs": 2}, "XD2"), SingleLine.hidden_cell(doc))
	doc.add(_component({"type": "socket", "gangs": 1}, "XD3"), SingleLine.hidden_cell(doc))
	line.feed("XD2", 4)
	line.feed("XD3", 4)
	doc.update_single_line()
	assert_eq(line.waiting.size(), 1, "a circuit waiting for its protection")
	assert_eq(line.feeder_feeding("XD2").number, 4)
	assert_eq(line.feeder_feeding("XD2").device, "")
	assert_eq(line.tag("XD3", doc.circuit), "Z 4.2", "tagged by its circuit's number")
	assert_eq(line.next_number(), 5)
	assert_eq(doc.get_wire_count() > 0, true)
	for wire: PackedStringArray in doc.circuit.get_wires():
		assert_false(wire[0].begins_with("XD2") or wire[1].begins_with("XD2"), "not wired while nothing protects it")
	# Saved and loaded with its number.
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(copy.single_line.waiting.size(), 1)
	assert_eq(copy.single_line.feeder_feeding("XD3").number, 4)
	# A breaker put in protects the first circuit waiting.
	assert_true(line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 16.0}, "FA4"), 3, "", "", line.first_waiting().number))
	assert_true(line.waiting.is_empty())
	assert_eq(line.feeder_of("FA4").number, 4)
	assert_eq(line.feeder_of("FA4").loads, PackedStringArray(["XD2", "XD3"]))
	# Another breaker, then the circuit moved onto it: FA4's waits no more, FA5 protects it.
	assert_true(line.add(doc, _component({"type": "breaker", "characteristic": "B", "rated_current": 16.0}, "FA5"), 4))
	assert_eq(line.feeder_of("FA5").number, 5, "a new spare circuit")
	assert_true(line.assign(doc, "FA4", 0), "FA4 takes a new circuit, its own waits")
	assert_eq(line.waiting.size(), 1)
	assert_true(line.assign(doc, "FA5", 4))
	assert_eq(line.feeder_of("FA5").loads.size(), 2)
	assert_eq(line.feeder_of("FA5").number, 4)
	# Deleting its breaker: the circuit waits again, its parts kept.
	doc.remove_component(doc.circuit.get_component("FA5").id)
	doc.update_single_line()
	assert_not_null(doc.circuit.get_component("XD2"))
	assert_eq(line.feeder_feeding("XD2").number, 4)
	assert_eq(line.feeder_feeding("XD2").device, "")


func test_main_switch_taken_away_and_put_back() -> void:
	var doc: SchematicDocument = _house()
	var line: SingleLine = doc.single_line
	assert_not_null(doc.circuit.get_component(SingleLine.MAIN))
	assert_false(line.add(doc, _component({"type": "cam_switch", "poles": 4, "positions": "0-I"}, SingleLine.MAIN), 0), "only one")
	doc.remove_component(doc.circuit.get_component(SingleLine.MAIN).id)
	doc.update_single_line()
	assert_false(line.main_switch)
	assert_null(doc.circuit.get_component(SingleLine.MAIN), "not made again")
	# The busbars straight from the supply: the luminaire lights once its breaker is on.
	(doc.circuit.get_component("FA1") as CircuitBreaker).switched_on = true
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.step()
	assert_true((doc.circuit.get_component("EA1") as Luminaire).energized)
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_false(copy.single_line.main_switch, "saved without it")
	assert_null(copy.circuit.get_component(SingleLine.MAIN))
	# Put back from the palette.
	var canvas: SingleLineCanvas = autofree(SingleLineCanvas.new())
	canvas.document = doc
	canvas.editing = true
	var template: Dictionary = Palette.INSTALLATION_ENTRIES[0]["template"]
	assert_eq(SingleLineCanvas.new_designation(doc, template), SingleLine.MAIN)
	assert_true(canvas.drop_target(canvas.at(0.0, 0.0), template).get("main", false))
	assert_true(line.add(doc, _component(template, SingleLine.MAIN), 0))
	assert_true(line.main_switch)
	assert_true(doc.circuit.get_component(SingleLine.MAIN) is CamSwitch)
	assert_true(canvas.drop_target(canvas.at(0.0, 0.0), template).is_empty(), "no second one")


func test_poles_drawn_apart_and_parts_one_under_another() -> void:
	var doc: SchematicDocument = _house()
	var line: SingleLine = doc.single_line
	assert_true(line.add(doc, _component({"type": "breaker", "poles": 4, "characteristic": "B", "rated_current": 16.0}, "FA4"), 3))
	assert_true(SingleLine.has_n_pole(doc.circuit.get_component("FA4")), "four poles: three phases and N")
	assert_eq(line.phases_of(line.feeder_of("FA4"), doc.circuit), PackedInt32Array([1, 2, 3]))
	assert_true(line.add(doc, _component({"type": "socket", "gangs": 1}, "XD2"), 0, "", "FA2"))
	var canvas: SingleLineCanvas = autofree(SingleLineCanvas.new())
	canvas.document = doc
	canvas._layout()
	assert_eq(SingleLineCanvas.pole_count(doc.circuit.get_component("FA4")), 4)
	var v: float = canvas._circuit_entry("FA4")["v"]
	var poles: PackedFloat32Array = SingleLineCanvas._circuit_poles(v, doc.circuit.get_component("FA4"))
	assert_almost_eq(poles[3] - poles[0], 3.0 * SingleLineCanvas.POLE, 0.01, "a pole each")
	assert_almost_eq((poles[0] + poles[3]) * 0.5, v, 0.01, "about the outlet")
	# Each part of FA2 is drawn and picked on its own.
	var fa2: float = canvas._circuit_entry("FA2")["v"]
	assert_eq(canvas.thing_at(canvas.at(canvas._part_u(0), fa2 + 15.0)).get("designation", ""), "XD1")
	assert_eq(canvas.thing_at(canvas.at(canvas._part_u(1), fa2 + 15.0)).get("designation", ""), "XD2")


func test_breaker_of_a_phase_and_n() -> void:
	var doc: SchematicDocument = _house()
	var line: SingleLine = doc.single_line
	var template: Dictionary = Palette.INSTALLATION_ENTRIES[2]["template"]
	assert_eq(template.get("n_pole"), true, "1+N in the palette")
	assert_true(line.add(doc, _component(template, "FA4"), 3))
	var breaker: MotorBreaker = doc.circuit.get_component("FA4") as MotorBreaker
	assert_true(breaker.n_pole)
	assert_true(SingleLine.has_n_pole(breaker))
	assert_eq(line.phases_of(line.feeder_of("FA4"), doc.circuit).size(), 1, "one phase")
	assert_eq(SingleLineCanvas.pole_count(breaker), 2)
	assert_true(line.add(doc, _component({"type": "socket", "gangs": 1}, "XD4"), 0, "", "FA4"))
	# The socket's N through the breaker's N pole.
	var through: bool = false
	for wire: PackedStringArray in doc.circuit.get_wires():
		if (wire[0] == "FA4:4" and wire[1] == "XD4:N") or (wire[1] == "FA4:4" and wire[0] == "XD4:N"):
			through = true
	assert_true(through, "N through its second pole")
	var canvas: SingleLineCanvas = autofree(SingleLineCanvas.new())
	assert_eq(canvas.rating_of(breaker), "B16/1+N")
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_true((copy.circuit.get_component("FA4") as MotorBreaker).n_pole, "saved")
