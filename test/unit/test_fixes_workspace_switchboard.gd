extends GutTest
## Workspace, control stations and switchboards: clicks in the tree, edits
## while simulating, places followed when renamed, cable tracks, and the
## switchboard's devices, wires and glands.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC


# --- Workspace tree -------------------------------------------------------------------

func _tree_item(tree: Tree, item: TreeItem, prefix: String) -> TreeItem:
	var child: TreeItem = item.get_first_child()
	while child != null:
		if child.get_text(0).begins_with(prefix):
			return child
		var found: TreeItem = _tree_item(tree, child, prefix)
		if found != null:
			return found
		child = child.get_next()
	return null


func test_tree_opens_an_entry_after_the_click_and_not_on_a_right_click() -> void:
	var tree: WorkspaceTree = WorkspaceTree.new()
	add_child_autofree(tree)
	tree.document = ExampleCircuits.build(9)
	tree.refresh()
	var items: Tree = tree.get("_tree")
	watch_signals(tree)
	_tree_item(items, items.get_root(), "-SB1").select(0)
	assert_signal_not_emitted(tree, "chosen", "the tree is rebuilt when an entry opens: not in the middle of its click")
	await wait_process_frames(2)
	assert_signal_emitted(tree, "chosen")
	assert_eq((get_signal_parameters(tree, "chosen")[0] as Dictionary)["designation"], "SB1")
	# A right click selects the entry too, but only asks for its menu.
	var second: TreeItem = _tree_item(items, items.get_root(), "-SB2")
	second.select(0)
	items.item_mouse_selected.emit(Vector2.ZERO, MOUSE_BUTTON_RIGHT)
	await wait_process_frames(2)
	assert_signal_emit_count(tree, "chosen", 1, "a right click opens nothing")
	assert_signal_emitted(tree, "menu_requested")
	assert_eq((get_signal_parameters(tree, "menu_requested")[0] as Dictionary)["designation"], "SB2", "the menu of the entry clicked")


func test_tree_lists_the_lamps_inside_buttons() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(0)
	doc.control_boxes[0].items[0].lamp = "H9"
	var tree: WorkspaceTree = WorkspaceTree.new()
	add_child_autofree(tree)
	tree.document = doc
	tree.refresh()
	var items: Tree = tree.get("_tree")
	var lamp: TreeItem = _tree_item(items, items.get_root(), "-H9")
	assert_not_null(lamp, "the lamp of an illuminated button is on the station")
	if lamp != null:
		assert_eq((lamp.get_metadata(0) as Dictionary)["name"], doc.control_boxes[0].name)
	(tree.get("_search") as LineEdit).text = "h9"
	tree.refresh()
	assert_not_null(_tree_item(items, items.get_root(), "-H9"), "and the search finds it")


# --- Stations -------------------------------------------------------------------------

func _station_panel(doc: SchematicDocument) -> StationPanel:
	var panel: StationPanel = StationPanel.new()
	panel.station_name = doc.control_boxes[0].name
	add_child_autofree(panel)
	panel.set_document(doc, true)
	return panel


func test_station_text_typed_before_simulating_edits_nothing() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(0)
	var panel: StationPanel = _station_panel(doc)
	var field: LineEdit = null
	for child: Node in (panel.get("_list") as VBoxContainer).get_children():
		if child is LineEdit:
			field = child as LineEdit
			break
	watch_signals(panel)
	field.text = "Typed"
	# The simulation starts on a copy of the document: the field loses its focus.
	panel.set_document(DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc)), false)
	field.focus_exited.emit()
	assert_signal_not_emitted(panel, "edit_requested", "the simulation's copy is never edited")


func test_changing_an_items_kind_picks_a_device_not_on_a_station() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(0)
	var box: ControlBox = doc.control_boxes[0]
	var lamp: int = -1
	for i: int in box.items.size():
		if box.items[i].kind == ControlBoxItem.Kind.LAMP:
			lamp = i
	assert_true(lamp >= 0)
	var panel: StationPanel = _station_panel(doc)
	panel.select_device(box.items[lamp].designation)
	var kinds: OptionButton = null
	for option: Node in (panel.get("_list") as VBoxContainer).find_children("*", "OptionButton", true, false):
		if (option as OptionButton).item_count == StationPanel.KIND_TITLES.size():
			kinds = option as OptionButton
	watch_signals(panel)
	kinds.item_selected.emit(ControlBoxItem.Kind.BUTTON)
	var change: Callable = get_signal_parameters(panel, "edit_requested")[0]
	change.call(doc)
	var shown: Dictionary[String, int] = {}
	for item: ControlBoxItem in box.items:
		if not item.designation.is_empty():
			shown[item.designation] = shown.get(item.designation, 0) + 1
	for designation: String in shown:
		assert_eq(shown[designation], 1, "-%s once on the station" % designation)


# --- Places followed when renamed --------------------------------------------------------

func test_opened_place_and_its_window_follow_a_rename() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(9)
	var view: WorkspaceView = WorkspaceView.new()
	add_child_autofree(view)
	autofree(view.tree)
	view.set_document(doc, true)
	view.open(Workspace.Place.SWITCHBOARD, "RA1")
	var window: PlaceWindow = PlaceWindow.new(Workspace.Place.SWITCHBOARD, "RA1")
	add_child_autofree(window)
	window.set_document(doc, true)
	assert_true(doc.rename_place(Workspace.Place.SWITCHBOARD, 0, "RA7", ""))
	window.refresh()
	view.refresh()
	assert_false(window.is_queued_for_deletion(), "the window stays open")
	assert_eq(window.place_name, "RA7")
	assert_true(view.is_open())
	# Undo: the document comes back with its old name.
	var undone: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_true(undone.rename_place(Workspace.Place.SWITCHBOARD, 0, "RA1", ""))
	view.set_document(undone, true)
	window.set_document(undone, true)
	assert_true(view.is_open(), "the opened place stays open")
	assert_eq(view.get("_opened"), "RA1")
	assert_eq(window.place_name, "RA1")
	# Gone: closed.
	undone.remove_place(Workspace.Place.SWITCHBOARD, 0)
	view.set_document(undone, true)
	assert_false(view.is_open())
	assert_eq(WorkspaceView.follow_place(undone, Workspace.Place.SWITCHBOARD, "RA1", Vector2i(0, 1)), -1)


# --- Workspace canvas --------------------------------------------------------------------

## Example 0 with [param count] limit switches wired from the switchboard.
func _many_field_parts(count: int) -> SchematicDocument:
	var doc: SchematicDocument = ExampleCircuits.build(0)
	for i: int in count:
		var switch: LimitSwitch = LimitSwitch.new("SQ%d" % (i + 1), NO)
		doc.add(switch, Vector2i(40 + 3 * i, 10))
		doc.connect_terminals("FA2:2", switch.get_terminal_keys()[0])
		doc.connect_terminals(switch.get_terminal_keys()[1], "KM1:A1")
	doc.name_cables()
	return doc


func test_many_cables_on_one_side_run_at_right_angles_with_their_tags_apart() -> void:
	var canvas: WorkspaceCanvas = WorkspaceCanvas.new()
	add_child_autofree(canvas)
	canvas.document = _many_field_parts(8)
	var paths: Array[Dictionary] = canvas.cable_paths()
	assert_eq(paths.size(), 10)
	for i: int in paths.size():
		var points: PackedVector2Array = paths[i]["points"]
		for k: int in points.size() - 1:
			var run: Vector2 = points[k + 1] - points[k]
			# Rounded corners are short; a run longer than a corner is straight.
			if run.length() > 2.0 * WorkspaceCanvas.CORNER:
				assert_true(absf(run.x) < 0.5 or absf(run.y) < 0.5, "%s runs at right angles" % paths[i]["cable"]["name"])
		for j: int in range(i + 1, paths.size()):
			assert_false((paths[i]["tag"] as Rect2).intersects(paths[j]["tag"]), "tags of %s and %s apart" % [paths[i]["cable"]["name"], paths[j]["cable"]["name"]])


func test_an_empty_group_moves_while_dragged() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(0)
	doc.add_group(Vector2(0.0, 400.0))
	var canvas: WorkspaceCanvas = WorkspaceCanvas.new()
	add_child_autofree(canvas)
	canvas.document = doc
	var group: Dictionary = {}
	for item: Dictionary in canvas.items():
		if item["kind"] == "group":
			group = item
	canvas.set("_press", group)
	canvas.set("_dragging", true)
	canvas.set("_drag", Vector2(200.0, 0.0))
	for item: Dictionary in canvas.items():
		if item["kind"] == "group":
			assert_eq((item["rect"] as Rect2).position, (group["rect"] as Rect2).position + Vector2(200.0, 0.0))
	canvas.set("_dragging", false)
	canvas.set("_press", {})


func test_renamed_cable_between_two_parts_keeps_its_name_when_one_is_moved() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(0)
	var a: LimitSwitch = LimitSwitch.new("SQ1", NC)
	var b: LimitSwitch = LimitSwitch.new("SQ2", NC)
	doc.add(a, Vector2i(40, 10))
	doc.add(b, Vector2i(44, 10))
	doc.connect_terminals(a.get_terminal_keys()[1], b.get_terminal_keys()[0])
	doc.connect_terminals("FA2:2", a.get_terminal_keys()[0])
	doc.connect_terminals(b.get_terminal_keys()[1], "KM1:A1")
	doc.place_field_device("SQ2", Vector2(500.0, 300.0))
	doc.name_cables()
	var key: String = ""
	for cable: Dictionary in WorkspaceCables.cables(doc):
		if str(cable["key"]).contains("SQ1") and str(cable["key"]).contains("SQ2"):
			key = cable["key"]
	assert_true(doc.rename_cable(key, "WLOOP"))
	doc.name_cables()
	doc.place_field_device("SQ1", Vector2(300.0, 300.0))
	doc.name_cables()
	var names: PackedStringArray = PackedStringArray()
	for cable: Dictionary in WorkspaceCables.cables(doc):
		names.append(cable["name"])
	assert_has(names, "WLOOP")


func test_new_place_is_right_of_a_group_of_parts_not_put_anywhere() -> void:
	var doc: SchematicDocument = _many_field_parts(4)
	doc.switchboards.clear()
	doc.control_boxes.clear()
	doc.field_positions.clear()
	var group: WorkspaceGroup = doc.add_group(Vector2(0.0, 300.0))
	group.members = PackedStringArray(["M1", "SQ1", "SQ2", "SQ3", "SQ4"])
	var frame: Rect2 = Workspace.group_rect(group, Workspace.field_positions(doc))
	assert_false(Rect2(doc.free_spot(), Workspace.PLACE_SIZE).intersects(frame))


# --- Switchboards --------------------------------------------------------------------------

func _supplies(doc: SchematicDocument) -> void:
	for s: Array in [["L1", PowerSupply.Conductor.L], ["L2", PowerSupply.Conductor.L2], ["L3", PowerSupply.Conductor.L3], ["N", PowerSupply.Conductor.N], ["PE", PowerSupply.Conductor.PE]]:
		doc.add(PowerSupply.new(s[0], s[1]), Vector2i(4 * doc.circuit.get_components().size(), 0))


func _add(doc: SchematicDocument, c: CircuitComponent) -> CircuitComponent:
	var n: int = doc.circuit.get_components().size()
	doc.add(c, Vector2i(4 + (n % 12) * 8, 4 + (n / 12) * 14))
	return c


## A lamp outside on strip terminal [param label], from [param from] to N.
func _lamp(doc: SchematicDocument, name: String, from: String, label: String) -> void:
	var lamp: Lamp = _add(doc, Lamp.new(name)) as Lamp
	doc.connect_terminals(from, name + ":X1")
	doc.connect_terminals(name + ":X2", "N")
	doc.set_strip_terminal(lamp.id, 0, label)


func _wiring(doc: SchematicDocument, board: int = 0) -> CabinetWiring:
	return CabinetWiring.build(doc, CabinetLayout.build(doc, 4.0, board), 4.0, board)


func _wire(wiring: CabinetWiring, key: String) -> bool:
	for wire: Dictionary in wiring.wires:
		if wire["from"] == key or wire["to"] == key:
			return true
	return false


static func _distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## Wires of switchboard [param board] passing over a screw of a device of
## [param kinds] that they do not end at: "wire over device:terminal".
func _over_screws(doc: SchematicDocument, kinds: Array, board: int = 0) -> PackedStringArray:
	var layout: CabinetLayout = CabinetLayout.build(doc, 4.0, board)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 4.0, board)
	var screws: Array[Dictionary] = []
	for place: Dictionary in layout.places:
		var sets: Array = [[place["kind"], place["desc"], place["origin"], place["designation"]]]
		if place.has("under_origin"):
			sets.append([CabinetDevices.Kind.OVERLOAD, place["under_desc"], place["under_origin"], place["under_designation"]])
		for set: Array in sets:
			if not kinds.has(set[0]):
				continue
			var terminals: Dictionary = (set[1] as Dictionary).get("terminals", {})
			var points: Dictionary = CabinetParts.terminal_points(set[0], set[1])
			for name: String in points:
				var p: Vector3 = points[name]
				screws.append({"at": set[2] + Vector2(p.x, p.y), "r": p.z, "key": terminals.get(name, ""), "name": "%s:%s" % [set[3], name], "device": set[3]})
	# The auxiliary contact block on a contactor's front: its wires run
	# straight on over the contactor's own tiers, in front of their screws.
	var block: Dictionary[String, String] = {}
	for place: Dictionary in layout.places:
		if place["kind"] == CabinetDevices.Kind.CONTACTOR:
			var aux: Array = place["desc"]["aux"]
			for k: int in range(CabinetParts.AUX_BUILT_IN, mini(aux.size(), CabinetParts.AUX_BUILT_IN + CabinetParts.AUX_FRONT)):
				for name: String in [str(aux[k][0]), str(aux[k][2])]:
					block[place["desc"]["terminals"].get(name, "")] = place["designation"]
	var result: PackedStringArray = PackedStringArray()
	for wire: Dictionary in wiring.wires:
		var path: PackedVector2Array = wire["points"]
		for screw: Dictionary in screws:
			if screw["key"] == wire["from"] or screw["key"] == wire["to"]:
				continue
			if block.get(wire["from"], "") == screw["device"] or block.get(wire["to"], "") == screw["device"]:
				continue
			for i: int in path.size() - 1:
				if _distance(screw["at"], path[i], path[i + 1]) < screw["r"] + wire["width"] * 0.5 - 0.3:
					result.append("%s-%s over %s" % [wire["from"], wire["to"], screw["name"]])
					break
	return result


func test_lone_overload_relay_is_wired_on_both_sides() -> void:
	var doc: SchematicDocument = SchematicDocument.new("lone")
	_supplies(doc)
	var breaker: MotorBreaker = _add(doc, MotorBreaker.new("FA1")) as MotorBreaker
	breaker.poles = 3
	_add(doc, OverloadRelay.new("F1", 5.0, 3))
	var motor: ThreePhaseMotor = _add(doc, ThreePhaseMotor.new("M1")) as ThreePhaseMotor
	for k: int in 3:
		doc.connect_terminals(["L1", "L2", "L3"][k], "FA1:%d" % (2 * k + 1))
		doc.connect_terminals("FA1:%d" % (2 * k + 2), "F1:%d" % (2 * k + 1))
		doc.connect_terminals("F1:%d" % (2 * k + 2), "M1:" + ["U1", "V1", "W1"][k])
		doc.set_strip_terminal(motor.id, k, "X2:%d" % (k + 1))
	doc.add_switchboard()
	doc.fill_cabinet(0)
	var wiring: CabinetWiring = _wiring(doc)
	for key: String in ["FA1:2", "FA1:4", "FA1:6", "F1:1", "F1:3", "F1:5", "F1:2"]:
		assert_true(_wire(wiring, key), key + " is wired")


func test_overload_relay_on_a_rail_and_under_its_contactor_is_drawn_once() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(9)
	var under: Dictionary[String, String] = CabinetDevices.overloads_under_contactors(doc.circuit)
	assert_false(under.is_empty())
	var relay: String = under.values()[0]
	doc.add_cabinet_item(0, 0, CabinetItem.Kind.DEVICE, relay)
	var count: int = 0
	for place: Dictionary in CabinetLayout.build(doc, 4.0).places:
		if place["designation"] == relay or place.get("under_designation", "") == relay:
			count += 1
	assert_eq(count, 1)


func test_field_cables_have_the_cores_of_their_workspace_cables() -> void:
	for example: int in ExampleCircuits.count():
		var doc: SchematicDocument = ExampleCircuits.build(example)
		var cores: Dictionary[String, int] = {}
		for cable: Dictionary in WorkspaceCables.cables(doc):
			cores[cable["name"]] = (cable["cores"] as Array).size()
		for b: int in doc.switchboards.size():
			var gland: Dictionary[String, int] = {}
			for wire: Dictionary in _wiring(doc, b).wires:
				if wire["external"] and cores.has(wire["cable"]):
					gland[wire["cable"]] = gland.get(wire["cable"], 0) + 1
			for cable: String in gland:
				assert_eq(gland[cable], cores[cable], "%s of example %d" % [cable, example])


func test_supply_points_of_two_conductors_wired_together() -> void:
	var doc: SchematicDocument = SchematicDocument.new("short")
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, 16))
	doc.add(PowerSupply.new("L.2", PowerSupply.Conductor.L), Vector2i(10, 1))
	doc.add(PowerSupply.new("N.2", PowerSupply.Conductor.N), Vector2i(10, 16))
	for i: int in 3:
		doc.add(Fuse.new("FU%d" % (i + 1)), Vector2i(4 + 4 * i, 4))
	doc.connect_terminals("L", "FU1:1")
	doc.connect_terminals("N", "FU2:1")
	doc.connect_terminals("L.2", "N")
	doc.connect_terminals("N.2", "FU3:1")
	doc.add_switchboard()
	doc.fill_cabinet(0)
	var wiring: CabinetWiring = _wiring(doc)
	assert_not_null(wiring)
	for key: String in ["FU1:1", "FU2:1", "FU3:1"]:
		assert_true(_wire(wiring, key), key + " is fed")


func test_main_contact_named_like_an_auxiliary_contact() -> void:
	var doc: SchematicDocument = SchematicDocument.new("aux")
	_supplies(doc)
	_add(doc, Coil.new("KM1"))
	# Main contacts with terminal 5 renamed 13.
	var data: Dictionary = DocumentSerializer.component_to_dict(MainContacts.new("KM1"))
	data["terminals"] = ["1", "2", "3", "4", "13", "6"]
	_add(doc, DocumentSerializer.component_from_dict(data))
	doc.connect_terminals("L1", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N")
	doc.add_switchboard()
	doc.fill_cabinet(0)
	var aux: Array = CabinetDevices.describe(doc, "KM1")["aux"]
	assert_eq(aux.size(), 2, "two built-in auxiliary contacts")
	assert_false(aux[0][0] == "13" or aux[1][0] == "13", "the spare ones keep clear of the renamed terminal")
	assert_true(_wire(_wiring(doc), "KM1:A1"))


func test_glands_side_by_side_without_overlapping() -> void:
	var doc: SchematicDocument = SchematicDocument.new("glands")
	_supplies(doc)
	doc.connect_terminals("L1", (_add(doc, CircuitBreaker.new("FA1")) as CircuitBreaker).get_terminal_keys()[0])
	# Lamps with no station: a cable for each, more than the duct has slots.
	for i: int in 30:
		_lamp(doc, "H%d" % (i + 1), "FA1:2", str(i + 1))
	doc.add_switchboard()
	doc.fill_cabinet(0)
	var layout: CabinetLayout = CabinetLayout.build(doc, 4.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 4.0)
	var bottom: Array[Rect2] = []
	for gland: Dictionary in wiring.glands:
		if gland["bottom"]:
			bottom.append(gland["rect"])
	assert_eq(bottom.size(), 30)
	for i: int in bottom.size():
		assert_true(bottom[i].position.x >= CabinetLayout.FRAME and bottom[i].end.x <= layout.size.x - CabinetLayout.FRAME, "inside the enclosure")
		for j: int in range(i + 1, bottom.size()):
			assert_false(bottom[i].grow(-0.05).intersects(bottom[j]), "glands %d and %d apart" % [i, j])


func test_wires_keep_off_the_screws_of_contactors_overload_relays_and_inverters() -> void:
	var doc: SchematicDocument = SchematicDocument.new("screws")
	_supplies(doc)
	doc.connect_terminals("L1", (_add(doc, CircuitBreaker.new("FA1")) as CircuitBreaker).get_terminal_keys()[0])
	# KM1 with six auxiliary contacts (four on the front block) and a
	# changeover one, KM2 with four main poles, KM3 with F3 under it.
	_add(doc, Coil.new("KM1"))
	_add(doc, MainContacts.new("KM1"))
	doc.connect_terminals("FA1:2", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N")
	for s: int in range(1, 6):
		var c: Contact = _add(doc, Contact.new("KM1", NO if s % 2 == 1 else NC, s)) as Contact
		doc.connect_terminals("FA1:2", c.get_terminal_keys()[0])
		_lamp(doc, "H1%d" % s, c.get_terminal_keys()[1], "1%d" % s)
	_add(doc, Coil.new("KM2"))
	var four: MainContacts = MainContacts.new("KM2")
	four.poles = 4
	_add(doc, four)
	doc.connect_terminals("KM1:13", "KM2:A1")
	doc.connect_terminals("KM2:A2", "N")
	for k: int in 4:
		doc.connect_terminals(["L1", "L2", "L3", "N"][k], "KM2:%d" % (2 * k + 1))
	_add(doc, Coil.new("KM3"))
	_add(doc, MainContacts.new("KM3"))
	_add(doc, Contact.new("KM3", NO, 1))
	_add(doc, Contact.new("KM3", NC, 2))
	_add(doc, OverloadRelay.new("F3", 5.0, 3))
	_add(doc, OverloadContact.new("F3", NC))
	_add(doc, OverloadContact.new("F3", NO))
	doc.connect_terminals("FA1:2", "F3:95")
	doc.connect_terminals("F3:96", "KM3:13")
	doc.connect_terminals("KM3:14", "KM3:A1")
	doc.connect_terminals("KM3:A2", "N")
	doc.connect_terminals("FA1:2", "F3:97")
	_lamp(doc, "H30", "F3:98", "30")
	_lamp(doc, "H31", "KM3:22", "31")
	doc.connect_terminals("FA1:2", "KM3:21")
	for k: int in 3:
		doc.connect_terminals(["L1", "L2", "L3"][k], "KM3:%d" % (2 * k + 1))
		doc.connect_terminals("KM3:%d" % (2 * k + 2), "F3:%d" % (2 * k + 1))
	# An inverter with control wires and its motor.
	_add(doc, Vfd.new("TA1"))
	for k: int in 3:
		doc.connect_terminals(["L1", "L2", "L3"][k], "TA1:" + ["L1", "L2", "L3"][k])
	for t: String in ["DI1", "DI2", "DI4"]:
		doc.connect_terminals("TA1:24V", "TA1:" + t)
	doc.connect_terminals("TA1:0V", "TA1:DIC")
	doc.connect_terminals("FA1:2", "TA1:DO2C")
	_lamp(doc, "H40", "TA1:DO2NO", "40")
	var motor: ThreePhaseMotor = _add(doc, ThreePhaseMotor.new("M1")) as ThreePhaseMotor
	for k: int in 3:
		doc.connect_terminals("TA1:" + ["U", "V", "W"][k], "M1:" + ["U1", "V1", "W1"][k])
		doc.set_strip_terminal(motor.id, k, "X2:%d" % (k + 1))
	doc.add_switchboard()
	doc.fill_cabinet(0)
	assert_eq(_over_screws(doc, [CabinetDevices.Kind.CONTACTOR, CabinetDevices.Kind.OVERLOAD, CabinetDevices.Kind.VFD]), PackedStringArray())


func test_changeover_contact_on_a_contactor_is_wired_on_both_sides() -> void:
	var doc: SchematicDocument = SchematicDocument.new("changeover")
	_supplies(doc)
	_add(doc, Coil.new("KM1"))
	_add(doc, MainContacts.new("KM1"))
	_add(doc, ChangeoverContact.new("KM1", 1))
	doc.connect_terminals("L1", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N")
	doc.connect_terminals("L1", "KM1:11")
	_lamp(doc, "H1", "KM1:12", "1")
	_lamp(doc, "H2", "KM1:14", "2")
	doc.add_switchboard()
	doc.fill_cabinet(0)
	var wiring: CabinetWiring = _wiring(doc)
	for key: String in ["KM1:11", "KM1:12", "KM1:14"]:
		assert_true(_wire(wiring, key), key + " is wired")
	assert_eq((CabinetDevices.describe(doc, "KM1")["aux"] as Array).size(), 2)
	for s: int in range(2, 7):
		_add(doc, Contact.new("KM1", NO, s))
	assert_eq((CabinetDevices.describe(doc, "KM1")["aux"] as Array).size(), 7, "an NC and an NO place for the changeover contact, five more")


func test_net_continuing_into_another_switchboard_leaves_in_its_cable() -> void:
	var doc: SchematicDocument = SchematicDocument.new("two")
	_supplies(doc)
	_add(doc, Vfd.new("TA1"))
	for k: int in 3:
		doc.connect_terminals(["L1", "L2", "L3"][k], "TA1:" + ["L1", "L2", "L3"][k])
	var motor: ThreePhaseMotor = _add(doc, ThreePhaseMotor.new("M1")) as ThreePhaseMotor
	for k: int in 3:
		doc.connect_terminals("TA1:" + ["U", "V", "W"][k], "M1:" + ["U1", "V1", "W1"][k])
		doc.set_strip_terminal(motor.id, k, "X9:%d" % (k + 1))
	doc.add_switchboard()
	doc.fill_cabinet(0)
	doc.add_switchboard()
	var rail: CabinetRail = doc.add_cabinet_rail(1)
	for first: CabinetRail in doc.switchboards[0].rails:
		for item: CabinetItem in first.items.duplicate():
			if item.designation == "X9":
				first.items.erase(item)
				rail.items.append(item)
	var between: String = ""
	for cable: Dictionary in WorkspaceCables.cables(doc):
		if cable["key"] == "+RA1|+RA2":
			between = cable["name"]
	assert_ne(between, "")
	for b: int in 2:
		var wiring: CabinetWiring = _wiring(doc, b)
		var cores: int = 0
		for wire: Dictionary in wiring.wires:
			if wire["external"] and wire["cable"] == between:
				cores += 1
		assert_eq(cores, 3, "U V W in cable %s at +RA%d" % [between, b + 1])
	for key: String in ["TA1:U", "TA1:V", "TA1:W"]:
		assert_true(_wire(_wiring(doc, 0), key), key + " is wired")


func test_relay_and_time_relay_with_more_contacts_than_one_has() -> void:
	var doc: SchematicDocument = SchematicDocument.new("contacts")
	_supplies(doc)
	_add(doc, Coil.new("KA1", Coil.Kind.RELAY))
	doc.connect_terminals("L1", "KA1:A1")
	doc.connect_terminals("KA1:A2", "N")
	for s: int in range(1, 7):
		_add(doc, ChangeoverContact.new("KA1", s))
		doc.connect_terminals("L1", "KA1:%d1" % s)
		_lamp(doc, "HA%d" % s, "KA1:%d4" % s, "A%d" % s)
	_add(doc, TimerRelay.new("KT1", TimerRelay.Mode.ON_DELAY, 1.0))
	doc.connect_terminals("L1", "KT1:A1")
	doc.connect_terminals("KT1:A2", "N")
	for s: int in range(1, 5):
		_add(doc, ChangeoverContact.new("KT1", s, true))
		doc.connect_terminals("L1", "KT1:%d5" % s)
		_lamp(doc, "HT%d" % s, "KT1:%d8" % s, "T%d" % s)
	doc.add_switchboard()
	doc.fill_cabinet(0)
	var wiring: CabinetWiring = _wiring(doc)
	for key: String in ["KA1:54", "KA1:64", "KT1:48"]:
		assert_true(_wire(wiring, key), key + " is wired, on a second relay")
	var second: bool = false
	for wire: Dictionary in wiring.wires:
		if wire["from"] == "KA1:A1" and wire["to"] == "KA1:A1":
			second = true
	assert_true(second, "the second relay's coil wired to the first one's")
	assert_eq(CabinetParts.device_size(CabinetDevices.describe(doc, "KT1")).x, 2.0 * CabinetParts.MODULE_W, "two time relays")


func test_compact_plc_screws_keep_apart() -> void:
	var modules: Array[Plc.Module] = [Plc.Module.SM_DI8_DQ8, Plc.Module.SM_DQ8]
	var doc: SchematicDocument = SchematicDocument.new("plc")
	_supplies(doc)
	_add(doc, CompactPlc.new("A1", null, modules, CompactPlc.Cpu.DI14_DQ10))
	doc.add_switchboard()
	doc.fill_cabinet(0)
	var points: Dictionary = CabinetParts.terminal_points(CabinetDevices.Kind.PLC, CabinetDevices.describe(doc, "A1"))
	var list: Array = points.values()
	for i: int in list.size():
		for j: int in range(i + 1, list.size()):
			var a: Vector3 = list[i]
			var b: Vector3 = list[j]
			assert_true(Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)) >= a.z + b.z + 0.5, "screws %s and %s apart" % [points.keys()[i], points.keys()[j]])


func test_rectifier_minus_output_is_wired_like_the_dc_minus_pole() -> void:
	var doc: SchematicDocument = SchematicDocument.new("dc")
	_supplies(doc)
	_add(doc, Rectifier.new("TB1"))
	_add(doc, Coil.new("K1", Coil.Kind.RELAY))
	doc.connect_terminals("L1", "TB1:~1")
	doc.connect_terminals("TB1:~2", "N")
	doc.connect_terminals("TB1:+", "K1:A1")
	doc.connect_terminals("K1:A2", "TB1:-")
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	var conductor: Dictionary[int, CabinetDevices.Conductor] = CabinetDevices.conductors(doc.circuit, net)
	assert_eq(conductor[net["TB1:-"]], CabinetDevices.Conductor.NEUTRAL)
	assert_eq(conductor[net["TB1:+"]], CabinetDevices.Conductor.CONTROL)


func test_cam_switch_of_three_poles_is_wired_as_main_power() -> void:
	# L1 fed only through a 3-pole cam switch is a phase of the main power
	# circuit like L2 and L3, not the control circuit's.
	var doc: SchematicDocument = SchematicDocument.new("cam")
	_supplies(doc)
	_add(doc, CamSwitch.new("RB1"))
	doc.connect_terminals("L1", "RB1:1")
	doc.connect_terminals("L2", "RB1:3")
	doc.connect_terminals("L3", "RB1:5")
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	var conductor: Dictionary[int, CabinetDevices.Conductor] = CabinetDevices.conductors(doc.circuit, net)
	for key: String in ["L1", "RB1:2", "RB1:4", "RB1:6"]:
		assert_eq(conductor[net[key]], CabinetDevices.Conductor.POWER, key)


func test_ctrl_wheel_zoom_keeps_the_point_under_the_mouse() -> void:
	var down: ScrollContainer = ScrollContainer.new()
	down.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	down.size = Vector2(900.0, 600.0)
	add_child_autofree(down)
	var across: ScrollContainer = ScrollContainer.new()
	across.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	across.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	down.add_child(across)
	var view: CabinetView = CabinetView.new()
	view.document = ExampleCircuits.build(9)
	across.add_child(view)
	await wait_process_frames(3)
	# Fitted to a height: drawn centred, a little narrower than the view;
	# one zoom step makes it wider.
	var width: float = view.drawn_size().x
	view.fit_height = view.drawn_size().y * 0.85
	await wait_process_frames(3)
	var origin: Vector2 = view.call("_origin")
	assert_true(origin.x > 20.0, "the plate is drawn centred, narrower than the view")
	var at: Vector2 = Vector2(width * 0.5, 200.0)
	var on_plate: Vector2 = (at - origin) / float(view.call("_k"))
	var on_screen: Vector2 = view.get_global_transform() * at
	await view.zoom_at(CabinetView.ZOOM_STEP, at)
	await wait_process_frames(3)
	var now: Vector2 = view.get_global_transform() * (view.call("_origin") + on_plate * float(view.call("_k")))
	assert_almost_eq(now.x, on_screen.x, 2.0, "the point under the mouse stays there")
	assert_almost_eq(now.y, on_screen.y, 2.0)


func test_wires_go_into_the_strip_terminals_at_any_width() -> void:
	# The terminal pitch is rounded to whole pixels: the strips are painted
	# at the scale the wires were laid out at, not the one the plate fits.
	var view: CabinetView = CabinetView.new()
	view.document = ExampleCircuits.build(9)
	add_child_autofree(view)
	var missed: int = 0
	for width: int in range(700, 1300, 3):
		view.size = Vector2(width, 600.0)
		view.queue_redraw()
		await wait_process_frames(2)
		var k: float = view.get("_painted_k")
		var layout: CabinetLayout = view.get("_layout")
		var wiring: CabinetWiring = view.get("_wiring")
		var pitch: float = roundf(CabinetParts.TERMINAL.x * k)
		for place: Dictionary in layout.places:
			if place["kind"] != CabinetLayout.STRIP:
				continue
			var origin: Vector2 = place["origin"]
			var count: int = place["desc"]["terminals"].size()
			# Pixels from the first terminal's left edge of the wire ends
			# going into each terminal (wires sharing one spread around its middle).
			var ends: Dictionary[int, Array] = {}
			for wire: Dictionary in wiring.wires:
				var points: PackedVector2Array = wire["points"]
				for end: Vector2 in [points[0], points[points.size() - 1]]:
					var x: float = (end.x - origin.x) * k - roundf(CabinetParts.END_STOP_W * k)
					if absf(end.y - origin.y - CabinetParts.TERMINAL_ENTRY) < 0.01 and x > 0.0 and x < count * pitch:
						var i: int = floori(x / pitch)
						ends[i] = ends.get(i, []) + [x]
			for i: int in ends:
				var sum: float = 0.0
				for x: float in ends[i]:
					sum += x
				if absf(sum / ends[i].size() - (i + 0.5) * pitch) > 0.5:
					missed += 1
	assert_eq(missed, 0, "every wire goes into the middle of its terminal")


func test_switchboard_paints_again_only_what_changed() -> void:
	var view: CabinetView = CabinetView.new()
	view.document = ExampleCircuits.build(9)
	view.simulating = true
	view.size = Vector2(900.0, 600.0)
	add_child_autofree(view)
	await wait_process_frames(3)
	var painted: Dictionary = view.get("_painted")
	var before: Dictionary = painted.duplicate()
	view.queue_redraw()
	await wait_process_frames(2)
	for layer: Variant in before:
		assert_true(is_same(painted[layer], before[layer]), "nothing changed, nothing painted")
	# Voltage on one contactor's terminals: only its place is painted again.
	var layout: CabinetLayout = view.get("_layout")
	var contactor: Dictionary = {}
	for place: Dictionary in layout.places:
		if contactor.is_empty() and place["kind"] == CabinetDevices.Kind.CONTACTOR:
			contactor = place
	var reach: Dictionary[String, int] = {}
	for name: String in contactor["desc"]["terminals"]:
		reach[contactor["desc"]["terminals"][name]] = StepResult.REACH_L1
	view.reach = reach
	before = painted.duplicate()
	view.queue_redraw()
	await wait_process_frames(2)
	var again: int = 0
	for layer: Variant in before:
		if not is_same(painted[layer], before[layer]):
			again += 1
	assert_eq(again, 1, "the contactor alone")
	# Zooming scales the painting until the zoom settles.
	var layers: Node2D = view.get("_layers")
	view.zoom = 2.0
	await wait_process_frames(2)
	assert_gt(layers.scale.x, 1.5, "scaled while zooming")
	await wait_seconds(CabinetView.ZOOM_SETTLE + 0.1)
	await wait_process_frames(2)
	assert_eq(layers.scale, Vector2.ONE, "painted sharp at the new scale")


func test_field_core_leaves_from_the_terminal_on_the_buttons_lead() -> void:
	# X2:6 on the breaker's lead on page 1, a page connector on to page 2,
	# where X2:7 and X2:9 sit on the leads of two buttons on a station: the
	# core to the station leaves from a button's terminal, not from X2:6.
	var doc: SchematicDocument = SchematicDocument.new("cores")
	doc.pages = PackedStringArray(["Power", "Control"])
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	var breaker: CircuitBreaker = CircuitBreaker.new("FA2")
	doc.add(breaker, Vector2i(5, 4))
	doc.add(PageConnector.new("PC1", "101"), Vector2i(5, 12))
	doc.connect_terminals("L", breaker.get_terminal_keys()[0])
	doc.connect_terminals(breaker.get_terminal_keys()[1], "PC1")
	doc.get_placement(breaker.id).strips[1] = "X2:6"
	doc.page = 1
	doc.add(PageConnector.new("PC2", "101"), Vector2i(20, 3))
	doc.add(PushButton.new("SB2", SwitchingElement.ContactType.NO), Vector2i(5, 5))
	doc.add(PushButton.new("SB1", SwitchingElement.ContactType.NC), Vector2i(10, 5))
	doc.add(Coil.new("KA1"), Vector2i(5, 12))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, 20))
	doc.connect_terminals("PC2", "SB2:13")
	doc.connect_terminals("PC2", "SB1:11")
	doc.connect_terminals("SB2:14", "KA1:A1")
	doc.connect_terminals("SB1:12", "KA1:A1")
	doc.connect_terminals("KA1:A2", "N")
	doc.get_placement(doc.circuit.get_component("SB2").id).strips = {0: "X2:7", 1: "X2:8"}
	doc.get_placement(doc.circuit.get_component("SB1").id).strips = {0: "X2:9", 1: "X2:10"}
	doc.page = 0
	doc.add_switchboard()
	doc.fill_cabinet(0)
	var box: ControlBox = doc.add_control_box("Station")
	box.items.append(ControlBoxItem.new(ControlBoxItem.Kind.BUTTON, "SB1", "red"))
	box.items.append(ControlBoxItem.new(ControlBoxItem.Kind.BUTTON, "SB2"))
	var wiring: CabinetWiring = CabinetWiring.build(doc, CabinetLayout.build(doc, 2.0, 0), 2.0, 0)
	var out: PackedStringArray = PackedStringArray()
	for wire: Dictionary in wiring.wires:
		if wire["external"] and str(wire["from"]).begins_with("W"):
			out.append(wire["to"])
	assert_true(out.has("SB2:13"), "the core of net 101 leaves from X2:7: %s" % [out])
	assert_false(out.has(breaker.get_terminal_keys()[1]), "not from X2:6 on the breaker's lead")


func test_motors_turn_on_the_workspace_while_simulating() -> void:
	var doc: SchematicDocument = SchematicDocument.new("turning")
	var motor: ThreePhaseMotor = ThreePhaseMotor.new("M1")
	doc.add(motor, Vector2i(10, 10))
	var single: Motor = Motor.new("M2")
	doc.add(single, Vector2i(20, 10))
	var canvas: WorkspaceCanvas = WorkspaceCanvas.new()
	canvas.document = doc
	canvas.size = Vector2(600.0, 400.0)
	add_child_autofree(canvas)
	assert_eq(canvas.motor_turn("M1"), 0.0, "standing still")
	motor.shaft = 1.0
	motor.rotor_speed = -motor.model().rated_speed(0)
	single.energized = true
	assert_almost_eq(canvas.motor_turn("M1"), -1.0, 0.01, "full speed, counterclockwise")
	assert_eq(canvas.motor_turn("M2"), 1.0, "a 1~ motor with power")
	await wait_process_frames(3)
	var spin: Dictionary = canvas.get("_spin")
	assert_true(spin.has("M1") and spin.has("M2"), "their marks go round")
	canvas.editing = true
	assert_eq(canvas.motor_turn("M1"), 0.0, "not while editing")


func test_station_shown_as_its_face_on_the_workspace() -> void:
	var doc: SchematicDocument = SchematicDocument.new("face")
	doc.add(PushButton.new("SB1", NO), Vector2i(5, 5))
	var box: ControlBox = doc.add_control_box("Gate", 1, Vector2(100.0, 50.0))
	box.items.append(ControlBoxItem.new(ControlBoxItem.Kind.BUTTON, "SB1"))
	assert_eq(Workspace.place_size(box), Workspace.PLACE_SIZE, "a tile at first")
	doc.set_station_face(0, ControlBox.DEFAULT_FACE)
	assert_eq(Workspace.place_size(box), box.face_size() * ControlBox.DEFAULT_FACE)
	doc.set_station_face(0, 9.0)
	assert_eq(box.face_scale, ControlBox.MAX_FACE, "kept within its limits")
	doc.set_station_face(0, ControlBox.DEFAULT_FACE)
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(copy.control_boxes[0].face_scale, ControlBox.DEFAULT_FACE, "saved")
	var canvas: WorkspaceCanvas = WorkspaceCanvas.new()
	canvas.document = doc
	canvas.size = Vector2(800.0, 600.0)
	add_child_autofree(canvas)
	await wait_process_frames(2)
	var faces: Dictionary = canvas.get("_faces")
	assert_true(faces.has(box.name), "drawn as the station")
	var face: ControlBoxView = faces[box.name]
	assert_almost_eq(face.scale.x, ControlBox.DEFAULT_FACE * canvas.zoom, 0.001)
	assert_eq(face.position, canvas.offset + box.position * canvas.zoom)
	# Simulating, its buttons operate the circuit.
	watch_signals(canvas)
	face.button_held.emit("SB1", true)
	assert_signal_emitted_with_parameters(canvas, "button_held", ["SB1", true])
	# Editing, its corner resizes it (one undoable edit at the release).
	canvas.editing = true
	canvas.selected = "+" + box.name
	canvas.queue_redraw()
	await wait_process_frames(1)
	var rect: Rect2 = Rect2(box.position, Workspace.place_size(box))
	var corner: Vector2 = canvas.offset + rect.end * canvas.zoom
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = corner
	canvas._gui_input(press)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = canvas.offset + (box.position + Vector2(box.face_size().x, 0.0)) * canvas.zoom
	canvas._gui_input(motion)
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	canvas._gui_input(release)
	assert_signal_emitted(canvas, "edit_requested")
	var change: Callable = get_signal_parameters(canvas, "edit_requested")[0]
	change.call(doc)
	assert_almost_eq(box.face_scale, 1.0, 0.01, "dragged to full size")
	doc.set_station_face(0, 0.0)
	canvas.queue_redraw()
	await wait_process_frames(2)
	assert_false(faces.has(box.name), "back to its tile")
