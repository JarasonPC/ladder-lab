extends GutTest
## The switchboard (rozvaděč): which devices and terminal strips it shows and
## how they look, editing its rails in the document, saving, following
## renamed devices.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC


func _doc() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("cabinet")
	doc.add_switchboard()
	var breaker: MotorBreaker = MotorBreaker.new("FA1")
	doc.add(breaker, Vector2i(0, 0))
	var fuse: Fuse = Fuse.new("FU1")
	fuse.holder = true
	doc.add(fuse, Vector2i(4, 0))
	doc.add(Coil.new("KM1"), Vector2i(8, 0))
	doc.add(MainContacts.new("KM1"), Vector2i(12, 0))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(16, 0))
	doc.add(OverloadRelay.new("F1", 5.0, 3), Vector2i(20, 0))
	doc.add(OverloadContact.new("F1", NC), Vector2i(24, 0))
	doc.add(Coil.new("KA1", Coil.Kind.RELAY), Vector2i(28, 0))
	for k: int in 3:
		doc.add(Contact.new("KA1", NO if k != 1 else NC, k + 1), Vector2i(32 + 4 * k, 0))
	doc.add(TimerRelay.new("KT1", TimerRelay.Mode.ON_DELAY, 2.0), Vector2i(48, 0))
	doc.add(Contact.new("KT1", NO, 1, true), Vector2i(52, 0))
	doc.add(Lamp.new("H1"), Vector2i(56, 0))
	for t: Array in [["X1", "1"], ["X2", "X2:3"], ["X3", "PE"], ["X4", "N"]]:
		var block: TerminalBlock = TerminalBlock.new(t[0])
		block.label = t[1]
		doc.add(block, Vector2i(60, 4 * doc.circuit.get_components().size()))
	doc.set_strip_terminal(doc.circuit.get_component("H1").id, 0, "2")
	# The overload relay is fitted under KM1: its heaters follow the main contacts.
	for pole: int in 3:
		doc.connect_terminals("KM1:%d" % (2 * pole + 2), "F1:%d" % (2 * pole + 1))
	return doc


func test_devices_and_kinds() -> void:
	var doc: SchematicDocument = _doc()
	assert_eq(CabinetDevices.devices(doc), PackedStringArray(["FA1", "FU1", "KM1", "KA1", "KT1"]), "contacts, lamps and the fitted overload relay are no places of their own")
	assert_eq(CabinetDevices.overloads_under_contactors(doc.circuit), {"KM1": "F1"})
	assert_eq(CabinetDevices.kind_of(doc.circuit.get_component("H1")), CabinetDevices.Kind.NONE)


func test_overload_relay_without_contactor_is_its_own_place() -> void:
	var doc: SchematicDocument = _doc()
	doc.remove_wire(0)
	doc.remove_wire(0)
	doc.remove_wire(0)
	assert_true(CabinetDevices.devices(doc).has("F1"))
	assert_eq(CabinetDevices.describe(doc, "KM1")["overload"], "")


func test_descriptions_follow_poles_and_contacts() -> void:
	var doc: SchematicDocument = _doc()
	var breaker: Dictionary = CabinetDevices.describe(doc, "FA1")
	assert_eq(breaker["poles"], 3)
	assert_false(breaker["on"], "breakers start switched off")
	var fuse: Dictionary = CabinetDevices.describe(doc, "FU1")
	assert_eq(fuse["poles"], 1)
	assert_false(fuse["closed"], "fuse holders start open")
	var contactor: Dictionary = CabinetDevices.describe(doc, "KM1")
	assert_eq(contactor["poles"], 3)
	assert_eq(contactor["aux"], [["13", "NO", "14"], ["21", "NC", "22"]], "the unused built-in contact keeps its numbers")
	assert_eq(contactor["overload"], "F1")
	assert_eq(contactor["terminals"]["A1"], "KM1:A1")
	assert_eq(contactor["terminals"]["6"], "KM1:6")
	var relay: Dictionary = CabinetDevices.describe(doc, "KA1")
	assert_eq(relay["poles"], 3, "a relay has a changeover contact for every contact it uses")
	assert_eq(relay["terminals"]["21"], "KA1:21")
	assert_eq(relay["terminals"]["22"], "KA1:22", "the NC contact sits on the NC side")
	assert_eq(relay["terminals"]["34"], "KA1:34")
	var timer: Dictionary = CabinetDevices.describe(doc, "KT1")
	assert_eq(timer["contacts"], 1)
	assert_eq(timer["code"], "F2")
	assert_eq(timer["terminals"]["15"], "KT1:17", "a delayed NO contact uses common and NO side")
	assert_eq(timer["terminals"]["18"], "KT1:18")
	var overload: Dictionary = CabinetDevices.describe(doc, "F1")
	assert_false(overload["tripped"])
	assert_eq(overload["terminals"]["95"], "F1:95")
	assert_eq(CabinetDevices.describe(doc, "H1"), {})


func test_more_auxiliary_contacts_and_four_poles() -> void:
	var doc: SchematicDocument = _doc()
	for k: int in 3:
		doc.add(Contact.new("KM1", NC if k == 0 else NO, k + 2), Vector2i(70 + 4 * k, 0))
	var mains: MainContacts = MainContacts.new("KM2")
	mains.poles = 4
	doc.add(Coil.new("KM2"), Vector2i(90, 0))
	doc.add(mains, Vector2i(94, 0))
	assert_eq((CabinetDevices.describe(doc, "KM1")["aux"] as Array).size(), 4, "two more go to the auxiliary contact block")
	assert_eq(CabinetDevices.describe(doc, "KM2")["poles"], 4)


func test_terminal_strips() -> void:
	var doc: SchematicDocument = _doc()
	var strips: Dictionary = CabinetDevices.strips(doc)
	assert_eq(strips.keys(), ["X1", "X2"])
	var labels: PackedStringArray = PackedStringArray()
	for t: Dictionary in strips["X1"]:
		labels.append("%s %s" % [t["label"], t["kind"]])
	assert_eq(labels, PackedStringArray(["1 L", "2 L", "N N", "PE PE"]), "numbers first, terminals on leads too")
	assert_eq(strips["X2"][0]["label"], "3")
	assert_eq(CabinetDevices.split_label("X5:12"), PackedStringArray(["X5", "12"]))


func test_fill_cabinet() -> void:
	var doc: SchematicDocument = _doc()
	assert_eq(doc.fill_cabinet(0), 3)
	var rails: Array[PackedStringArray] = []
	for rail: CabinetRail in doc.switchboards[0].rails:
		var names: PackedStringArray = PackedStringArray()
		for item: CabinetItem in rail.items:
			names.append(item.designation)
		rails.append(names)
	assert_eq(rails[0], PackedStringArray(["FA1", "FU1", "KT1", "KA1"]), "protection, then time relays, then relays")
	assert_eq(rails[1], PackedStringArray(["KM1"]), "contactors, the overload relay under its contactor")
	assert_eq(rails[2], PackedStringArray(["X1", "X2"]))
	assert_eq(doc.switchboards[0].rails[2].items[0].kind, CabinetItem.Kind.STRIP)
	assert_eq(doc.fill_cabinet(0), 0, "everything has a place already")
	assert_true(doc.cabinet_unplaced().is_empty())


func test_edit_rails_and_items() -> void:
	var doc: SchematicDocument = _doc()
	doc.add_cabinet_rail(0)
	doc.add_cabinet_rail(0)
	assert_not_null(doc.add_cabinet_item(0, 0, CabinetItem.Kind.DEVICE, "KM1"))
	assert_null(doc.add_cabinet_item(0, 1, CabinetItem.Kind.DEVICE, "KM1"), "one place per device")
	assert_null(doc.add_cabinet_item(0, 5, CabinetItem.Kind.DEVICE, "KA1"), "no such rail")
	doc.add_cabinet_item(0, 0, CabinetItem.Kind.DEVICE, "KA1")
	doc.move_cabinet_item(0, 0, 1, -1)
	assert_eq(doc.switchboards[0].rails[0].items[0].designation, "KA1")
	assert_true(doc.move_cabinet_item_to_rail(0, 0, 0, 1))
	assert_eq(doc.switchboards[0].rails[1].items[0].designation, "KA1")
	assert_false(doc.move_cabinet_item_to_rail(0, 1, 0, 1), "no rail below")
	doc.move_cabinet_rail(0, 1, -1)
	assert_eq(doc.switchboards[0].rails[0].items[0].designation, "KA1")
	doc.remove_cabinet_item(0, 0, 0)
	assert_true(doc.switchboards[0].rails[0].items.is_empty())
	doc.remove_cabinet_rail(0, 0)
	assert_eq(doc.switchboards[0].rails.size(), 1)


func test_renamed_device_keeps_its_place() -> void:
	var doc: SchematicDocument = _doc()
	doc.fill_cabinet(0)
	doc.rename_cabinet_device("KA1", "KA7")
	assert_eq(doc.switchboards[0].rails[0].items[3].designation, "KA7")


func test_saved_and_loaded() -> void:
	var doc: SchematicDocument = _doc()
	doc.fill_cabinet(0)
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(DocumentSerializer.to_dict(copy), DocumentSerializer.to_dict(doc))
	assert_eq(copy.switchboards[0].rails.size(), 3)
	var data: Dictionary = DocumentSerializer.to_dict(doc)
	data.erase("switchboards")
	data["cabinet"] = [{"items": [{"kind": "device", "designation": "KM1"}, {"kind": "rocket", "designation": "R1"}, "x"]}, 5]
	var loaded: SchematicDocument = DocumentSerializer.from_dict(data)
	assert_eq(loaded.switchboards.size(), 1, "the rails of an older file are switchboard RA1")
	assert_eq(loaded.switchboards[0].name, "RA1")
	assert_eq(loaded.switchboards[0].rails.size(), 1, "malformed rails and items are left out")
	assert_eq(loaded.switchboards[0].rails[0].items.size(), 1)


func test_layout_places_and_clicks() -> void:
	var doc: SchematicDocument = _doc()
	doc.fill_cabinet(0)
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	assert_eq(layout.rails.size(), 3)
	assert_eq(layout.places.size(), 7)
	assert_eq(layout.ducts.size(), 6, "across above, between and below three rails, down both sides")
	var contactor: Dictionary = layout.places[4]
	assert_eq(contactor["designation"], "KM1")
	assert_eq(contactor["under_designation"], "F1", "the overload relay hangs under its contactor")
	var under: Array = []
	assert_eq(layout.place_at((contactor["under_rect"] as Rect2).get_center(), under), 4)
	assert_eq(under, [true])
	assert_eq(layout.place_at(Vector2(-5, -5)), -1)
	var rail: Rect2 = layout.rails[0]
	for place: Dictionary in layout.places.slice(0, 4):
		assert_true((place["rect"] as Rect2).get_center().y > rail.position.y and (place["rect"] as Rect2).get_center().y < rail.end.y, "%s sits on its rail" % place["designation"])
	assert_true(layout.size.x >= rail.end.x + CabinetLayout.SIDE_DUCT, "the plate holds the rails and the side ducts")


func test_layout_marks_missing_devices() -> void:
	var doc: SchematicDocument = _doc()
	doc.add_cabinet_rail(0)
	doc.switchboards[0].rails[0].items.append(CabinetItem.new(CabinetItem.Kind.DEVICE, "KM9"))
	doc.switchboards[0].rails[0].items.append(CabinetItem.new(CabinetItem.Kind.STRIP, "X7"))
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	assert_eq(layout.places[0]["kind"], CabinetLayout.MISSING_DEVICE)
	assert_eq(layout.places[1]["kind"], CabinetLayout.MISSING_DEVICE, "a strip without terminals")


func test_bridge_rectifier() -> void:
	var doc: SchematicDocument = _doc()
	doc.add(Rectifier.new("TB1"), Vector2i(100, 0))
	assert_true(CabinetDevices.devices(doc).has("TB1"))
	var rectifier: Dictionary = CabinetDevices.describe(doc, "TB1")
	assert_eq(rectifier["kind"], CabinetDevices.Kind.RECTIFIER)
	assert_false(rectifier["on"], "no voltage on its input")
	assert_eq(rectifier["terminals"]["+"], "TB1:+")
	doc.fill_cabinet(0)
	var first: PackedStringArray = PackedStringArray()
	for item: CabinetItem in doc.switchboards[0].rails[0].items:
		first.append(item.designation)
	assert_eq(first, PackedStringArray(["FA1", "FU1", "KT1", "KA1", "TB1"]), "rectifiers after the relays")


func test_plc() -> void:
	var doc: SchematicDocument = _doc()
	doc.add(Rectifier.new("TB1"), Vector2i(100, 0))
	doc.add(Plc.new("A1"), Vector2i(100, 10))
	assert_true(CabinetDevices.devices(doc).has("A1"))
	assert_false(CabinetDevices.is_outside(doc.circuit, doc.circuit.get_component("A1")), "it sits on a rail")
	var plc: Dictionary = CabinetDevices.describe(doc, "A1")
	assert_eq(plc["kind"], CabinetDevices.Kind.PLC)
	assert_false(plc["powered"])
	assert_eq(plc["terminals"]["Q4.2"], "A1:Q4.2")
	assert_eq((plc["outputs"] as Array).size(), Plc.BASE_OUTPUTS)
	var points: Dictionary = CabinetParts.terminal_points(CabinetDevices.Kind.PLC, plc)
	assert_eq(points.size(), Plc.standard_terminal_names().size(), "a screw for every terminal")
	for name: String in points:
		var at: Vector3 = points[name]
		assert_true(Rect2(Vector2.ZERO, CabinetParts.PLC).has_point(Vector2(at.x, at.y)), name)
	doc.fill_cabinet(0)
	var first: PackedStringArray = PackedStringArray()
	for item: CabinetItem in doc.switchboards[0].rails[0].items:
		first.append(item.designation)
	assert_eq(first, PackedStringArray(["FA1", "FU1", "KT1", "KA1", "TB1", "A1"]), "PLCs after the rectifiers")


func test_plc_with_expansion_modules() -> void:
	var doc: SchematicDocument = _doc()
	var modules: Array[Plc.Module] = [Plc.Module.DI4_DQ4, Plc.Module.DI8_DQ8]
	doc.add(Plc.new("A1", null, modules), Vector2i(100, 10))
	var plc: Dictionary = CabinetDevices.describe(doc, "A1")
	assert_eq(plc["modules"], ["4di4dq", "8di8dq"])
	assert_eq((plc["inputs"] as Array).size(), 20)
	assert_eq((plc["outputs"] as Array).size(), 16)
	assert_eq(plc["terminals"]["3L1"], "A1:3L1")
	var size: Vector2 = CabinetParts.plc_size(plc)
	assert_eq(size, Vector2(CabinetParts.PLC.x + 36.0 + 72.0, CabinetParts.PLC.y), "two and four modules wide beside the PLC")
	var points: Dictionary = CabinetParts.terminal_points(CabinetDevices.Kind.PLC, plc)
	assert_eq(points.size(), Plc.standard_terminal_names(modules).size(), "a screw for every terminal")
	var seen: Dictionary[Vector2, String] = {}
	for name: String in points:
		var at: Vector3 = points[name]
		assert_true(Rect2(Vector2.ZERO, size).has_point(Vector2(at.x, at.y)), name)
		assert_false(seen.has(Vector2(at.x, at.y)), "%s apart from %s" % [name, seen.get(Vector2(at.x, at.y), "")])
		seen[Vector2(at.x, at.y)] = name
	assert_true(points["2L1"].x > CabinetParts.PLC.x and points["2L1"].x < CabinetParts.PLC.x + 36.0, "the first module's supply on it")
	assert_true(points["Q9.1"].x > CabinetParts.PLC.x + 36.0, "the second module's outputs on it")
	assert_eq(points["Q4.2"], CabinetParts.terminal_points(CabinetDevices.Kind.PLC, CabinetDevices.describe(_plain_plc_doc(), "A1"))["Q4.2"], "the PLC's own screws stay where they were")


func _plain_plc_doc() -> SchematicDocument:
	var doc: SchematicDocument = _doc()
	doc.add(Plc.new("A1"), Vector2i(100, 10))
	return doc


func test_plc_terminals_keep_their_marking_when_renamed() -> void:
	var doc: SchematicDocument = _doc()
	var a1: Plc = Plc.new("A1")
	var names: PackedStringArray = a1.default_terminal_names()
	names[2] = "START"
	a1.custom_terminals = names
	doc.add(a1, Vector2i(100, 10))
	var plc: Dictionary = CabinetDevices.describe(doc, "A1")
	assert_eq(plc["terminals"]["I1"], "A1:START")
	assert_eq(plc["names"]["I1"], "START", "printed with the name of the schematic")


func _strip_labels(doc: SchematicDocument, strip: String) -> Array:
	var labels: Array = []
	for t: Dictionary in CabinetDevices.strips(doc).get(strip, []):
		labels.append(t["label"])
	return labels


func test_strip_terminals_move_along_the_strip() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(9)
	assert_eq(_strip_labels(doc, "X3"), ["1", "2", "3", "4", "5", "6", "7"], "U1 V1 W1 U2 V2 W2 PE of the motor")
	assert_true(doc.move_strip_terminals_along("X3", PackedStringArray(["4"]), -1))
	assert_eq(_strip_labels(doc, "X3"), ["1", "2", "4", "3", "5", "6", "7"])
	assert_false(doc.move_strip_terminals_along("X3", PackedStringArray(["1"]), -1), "the first one stays")
	assert_true(doc.move_strip_terminals_along("X3", PackedStringArray(["5", "6"]), 1))
	assert_eq(_strip_labels(doc, "X3"), ["1", "2", "4", "3", "7", "5", "6"], "picked terminals move together")
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(_strip_labels(copy, "X3"), ["1", "2", "4", "3", "7", "5", "6"], "the order is saved")



func test_terminal_labels_on_one_line() -> void:
	assert_eq(CabinetDevices.terminal_text("X2:6"), "X2-6")
	assert_eq(CabinetDevices.terminal_text("6"), "X1-6", "strip X1 written too")
	assert_eq(CabinetDevices.terminal_text("X1:PE"), "X1-PE")
	assert_eq(CabinetDevices.terminal_text(""), "")
	assert_eq(CabinetDevices.label_from_text("X2-6"), "X2:6", "typed as drawn")
	assert_eq(CabinetDevices.label_from_text("X2:6"), "X2:6")
	assert_eq(CabinetDevices.label_from_text("X1-7"), "7", "on X1 the number alone")
	assert_eq(CabinetDevices.label_from_text(" 8 "), "8")
	assert_eq(CabinetDevices.label_from_text("PE"), "PE")


func test_duct_sizes_follow_their_wires() -> void:
	var fingers: float = 2.0 * CabinetParts.DUCT_DEPTH
	assert_eq(CabinetLayout.duct_size(0), ceilf(fingers + CabinetWiring.WIRE_W), "an empty duct: room for one wire")
	assert_eq(CabinetLayout.duct_size(1), CabinetLayout.duct_size(0))
	assert_eq(CabinetLayout.duct_size(5), ceilf(fingers + CabinetWiring.WIRE_W + 4.0 * CabinetWiring.LANE), "just wide enough, whole millimetres")
	assert_true(CabinetLayout.duct_size(12) > CabinetLayout.duct_size(11))
	for example: int in [0, 6, 10, 14]:
		var doc: SchematicDocument = ExampleCircuits.build(example)
		var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
		var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
		assert_eq(wiring.lanes.size(), layout.ducts.size())
		var widths: Array[float] = []
		for d: int in layout.ducts.size():
			var r: Rect2 = layout.ducts[d]["rect"]
			var width: float = r.size.x if layout.ducts[d]["vertical"] else r.size.y
			widths.append(width)
			assert_true(width >= CabinetLayout.duct_size(wiring.lanes[d]), "%d: duct %d holds its %d wires side by side" % [example, d, wiring.lanes[d]])
		assert_true(widths.max() > widths.min(), "%d: busier ducts are wider" % example)


func test_duct_covers_paint_the_wires_again_but_never_on_export() -> void:
	var view: CabinetView = CabinetView.new()
	view.document = ExampleCircuits.build(9)
	view.size = Vector2(900.0, 600.0)
	add_child_autofree(view)
	await wait_process_frames(3)
	var top: Node2D = view.get("_top")
	var painted: Dictionary = view.get("_painted")
	var open: Variant = painted[top]
	CabinetView.duct_covers = true
	view.queue_redraw()
	await wait_process_frames(3)
	var covered: Variant = painted[top]
	assert_ne(covered, open, "the wires and covers are painted again")
	assert_true(view.call("_covered"))
	view.open_ducts = true
	assert_false(view.call("_covered"), "the export draws the ducts open")
	CabinetView.duct_covers = false
