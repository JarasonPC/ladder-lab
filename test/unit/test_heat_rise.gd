extends GutTest
## The temperature rise of a switchboard by calculation (IEC 890 / ČSN 33
## 7107): the method's two worked examples, small and ventilated enclosures,
## sections, the curve over the height, nothing assumed (what is not given
## is asked for), the settings saved, the losses of devices, wires and
## terminals, and the switchboard panel's heat rise dialog.


func after_all() -> void:
	RecoveryFile.forget()


## Everything the calculation needs about the enclosure and the air.
func _given(changes: Dictionary) -> Dictionary:
	var s: Dictionary = {"mounting": 1, "vented": false, "partitions": 0, "ambient": 35.0, "limit": 55.0}
	s.merge(changes, true)
	return s


func test_example_one_closed_free_on_all_sides() -> void:
	# 2200 x 1000 x 500 mm, free on all sides, closed, 300 W.
	var r: Dictionary = HeatRise.calculate(Vector3(2200, 1000, 500), _given({"mounting": 0}), 300.0)
	var section: Dictionary = r["section"]
	assert_eq(r["sections"], 1)
	assert_almost_eq(section["ae"], 6.64, 0.005, "Ae as the method's table")
	assert_almost_eq(section["k"], 0.135, 0.003, "k off fig. 2")
	assert_eq(section["d"], 1.0)
	assert_almost_eq(section["factor_value"], 5.80, 0.01, "f")
	assert_almost_eq(section["c"], 1.44, 0.01, "c off fig. 3, curve 1")
	assert_almost_eq(r["half"], 13.2, 0.4, "Δt0,5 13.2 K")
	assert_almost_eq(r["top"], 19.1, 0.5, "Δt1,0 19.1 K")
	assert_eq(r["warnings"].size(), 0)


func test_example_two_ventilated_in_two_sections() -> void:
	# 2200 high, 2900 wide, 800 deep, for wall mounting, openings 1220 / 1800 cm²,
	# two partitions, 2200 W: two halves of 1450 mm.
	var s: Dictionary = _given({"vented": true, "inlet": 1220.0, "outlet": 1800.0, "partitions": 2})
	var r: Dictionary = HeatRise.calculate(Vector3(2200, 2900, 800), s, 2200.0)
	var section: Dictionary = r["section"]
	assert_eq(r["sections"], 2, "wider than 1.5 m")
	assert_almost_eq(section["width"], 1.45, 0.001)
	assert_almost_eq(section["ae"], 7.674, 0.005, "the fictitious dividing wall not counted")
	assert_almost_eq(section["power"], 1100.0, 0.01)
	assert_almost_eq(section["k"], 0.071, 0.002, "k off fig. 4 at 610 cm²")
	assert_eq(section["d"], 1.10)
	assert_eq(section["x"], 0.715)
	assert_almost_eq(section["factor_value"], 2.50, 0.01)
	assert_almost_eq(section["c"], 1.87, 0.015, "c off fig. 5")
	assert_almost_eq(r["half"], 11.7, 0.3)
	assert_almost_eq(r["top"], 21.8, 0.5)
	s["ambient"] = 40.0
	s["limit"] = 60.0
	r = HeatRise.calculate(Vector3(2200, 2900, 800), s, 2200.0)
	assert_almost_eq(r["temperature"], 61.7, 0.5, "40 °C around it")
	assert_false(r["ok"], "warmer than 60 °C")
	# Openings typed but said to be none: closed.
	s["vented"] = false
	assert_false(HeatRise.calculate(Vector3(2200, 2900, 800), s, 2200.0)["section"]["vented"])


func test_small_enclosure_and_warnings() -> void:
	# A consumer unit 500 x 400 x 110 mm on a wall: Ae under 1.25 m².
	var r: Dictionary = HeatRise.calculate(Vector3(500, 400, 110), _given({}), 30.0)
	var section: Dictionary = r["section"]
	assert_true(section["small"])
	assert_almost_eq(section["ae"], 0.4*0.11*1.4 + 0.2*0.9 + 0.2*0.5 + 2*0.11*0.5*0.9, 1e-4)
	assert_almost_eq(section["k"], HeatRise.SMALL_K * pow(section["ae"], HeatRise.SMALL_EXP), 1e-6, "fig. 6")
	assert_eq(section["factor"], "g")
	assert_almost_eq(section["c"], 1.215, 0.01, "fig. 7 at g = 1.25")
	assert_almost_eq(HeatRise.rise_at(r, 0.9), r["top"], 1e-6, "the top quarter as warm as the top")
	assert_almost_eq(HeatRise.rise_at(r, 0.5), r["half"], 1e-6)
	assert_between(HeatRise.rise_at(r, 0.0), 0.0, r["half"], "the line on down, on the safe side")
	# Openings on a small one: reckoned closed, said so; too small outlets.
	r = HeatRise.calculate(Vector3(500, 400, 110), _given({"vented": true, "inlet": 100.0, "outlet": 50.0}), 30.0)
	assert_false(r["section"]["vented"])
	assert_eq(r["warnings"].size(), 2, str(r["warnings"]))
	# A large closed one past fig. 2 is reckoned in sections.
	r = HeatRise.calculate(Vector3(2200, 1400, 1200), _given({"mounting": 0}), 500.0)
	assert_eq(r["sections"], 2, "over 11.5 m² of Ae")
	assert_lt(r["section"]["ae"], HeatRise.MAX_AE)
	# The curve over the height of a large one: a straight line.
	r = HeatRise.calculate(Vector3(2200, 1000, 500), _given({"mounting": 0}), 300.0)
	assert_almost_eq(HeatRise.rise_at(r, 0.75), (r["half"] + r["top"]) / 2.0, 1e-6)


func test_settings_keep_only_what_was_given() -> void:
	assert_eq(HeatRise.settings({}), {}, "nothing assumed")
	var s: Dictionary = HeatRise.settings({"height": 800, "mounting": 9, "partitions": "two", "ambient": 40, "vented": 1,
		"losses": {"FA1": 2.5, "KM1": -1}, "sections": {"16": 1.5, "2": 0}})
	assert_eq(s, {"height": 800.0, "ambient": 40.0, "losses": {"FA1": 2.5}, "sections": {"16": 1.5}},
		"a wrong mounting, partitions, ventilation, a negative loss and a zero cross-section not taken")
	assert_null(HeatRise.enclosure(s), "width and depth missing")
	s["width"] = 600.0
	s["depth"] = 250.0
	assert_eq(HeatRise.enclosure(s), Vector3(800, 600, 250))


func _filled_board() -> SchematicDocument:
	var doc: SchematicDocument = ExampleCircuits.build(ExampleCircuits.TITLES.find("Direct-on-line start 3~"))
	if doc.switchboards.is_empty():
		doc.add_switchboard()
	doc.fill_cabinet(0)
	return doc


func test_nothing_estimated_everything_asked_for() -> void:
	var doc: SchematicDocument = _filled_board()
	var wires: Array = CabinetLayout.build(doc, 1.0, 0).wiring.wires
	var e: Dictionary = HeatRise.evaluate(doc, 0, wires, {})
	var losses: Dictionary = e["losses"]
	assert_eq(e["result"], {}, "no calculation while anything is missing")
	assert_null(losses["total"])
	assert_gt(losses["devices"].size(), 2)
	for device: Dictionary in losses["devices"]:
		assert_null(device["power"], "no loss assumed for -%s" % device["designation"])
	assert_gt(losses["groups"].size(), 0, "the wires by the current of their net")
	for group: Dictionary in losses["groups"]:
		assert_null(group["section"])
		assert_gt(group["length"], 0.0)
	var texts: Array = e["missing"].map(func(g: Dictionary) -> String: return g["text"])
	for text: String in ["The enclosure's height", "The enclosure's width", "The enclosure's depth", "How the enclosure is installed",
			"Whether it has ventilation openings", "The horizontal partitions", "The ambient temperature", "The most allowed inside",
			"The loss of -%s", "The cross-section of the wires carrying %s A", "The loss of the strip terminals", "The further losses"]:
		assert_true(texts.has(text), text)
	# All given: worked out, the total the sum of what was given.
	var s: Dictionary = _given({"height": 800.0, "width": 600.0, "depth": 250.0, "terminals": 0.5, "extra": 2.0})
	s["losses"] = {}
	for device: Dictionary in losses["devices"]:
		s["losses"][device["designation"]] = 3.0
	s["sections"] = {}
	for group: Dictionary in losses["groups"]:
		s["sections"][group["key"]] = 2.5
	e = HeatRise.evaluate(doc, 0, wires, s)
	assert_eq(e["missing"].size(), 0, str(e["missing"]))
	var sum: float = 0.5 + 2.0 + 3.0 * losses["devices"].size()
	for group: Dictionary in e["losses"]["groups"]:
		assert_almost_eq(group["power"], HeatRise.conductor_loss(group["amperes"], group["length"], 2.5), 1e-9)
		sum += group["power"]
	assert_almost_eq(e["losses"]["total"], sum, 1e-6)
	assert_false(e["result"].is_empty())
	# Annex H: 10 A in 2 m of 2.5 mm²: 10² · 7.41 mΩ · 1.2 · 2 m.
	assert_almost_eq(HeatRise.conductor_loss(10.0, 2.0, 2.5), 100.0 * 0.00741 * 1.2 * 2.0, 1e-5)
	# Ventilated asks for its openings.
	s["vented"] = true
	texts = HeatRise.evaluate(doc, 0, wires, s)["missing"].map(func(g: Dictionary) -> String: return g["text"])
	assert_eq(texts, ["The inlet openings", "The outlet openings"])


func test_settings_saved_with_the_switchboard() -> void:
	var doc: SchematicDocument = _filled_board()
	doc.switchboards[0].heat = HeatRise.settings({"width": 600.0, "vented": true, "inlet": 200.0, "losses": {"KM1": 6.0}, "sections": {"16": 2.5}})
	var again: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(again.switchboards[0].heat, {"width": 600.0, "vented": true, "inlet": 200.0, "losses": {"KM1": 6.0}, "sections": {"16": 2.5}})
	doc.switchboards[0].heat = {}
	assert_false(doc.switchboards[0].to_data().has("heat"), "nothing saved while nothing is given")


func test_panel_asks_and_the_dialog_saves_what_is_given() -> void:
	var doc: SchematicDocument = _filled_board()
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
		if child is Button and (child as Button).text == "Temperature rise…":
			open = child
		if child is Label and (child as Label).text.begins_with("Temperature rise:"):
			summary = child
	assert_not_null(open)
	assert_not_null(summary)
	assert_string_contains(summary.text, "still to give", "nothing worked out from guesses")
	open.pressed.emit()
	var dialog: HeatRiseDialog = panel.get("_heat_dialog")
	assert_true(dialog.visible)
	var fields: Dictionary = dialog.get("_fields")
	for key: String in fields:
		assert_eq((fields[key] as LineEdit).text, "", "%s empty until given" % key)
	assert_string_contains((dialog.get("_results") as Label).text, "Still to give")
	# Give it all.
	for pair: Array in [["height", "800"], ["width", "600"], ["depth", "250"], ["ambient", "35"], ["limit", "55"]]:
		(fields[pair[0]] as LineEdit).text = pair[1]
		(fields[pair[0]] as LineEdit).text_changed.emit(pair[1])
	(dialog.get("_mounting") as OptionButton).select(2)
	(dialog.get("_mounting") as OptionButton).item_selected.emit(2)
	(dialog.get("_vented") as OptionButton).select(1)
	(dialog.get("_vented") as OptionButton).item_selected.emit(1)
	(dialog.get("_partitions") as OptionButton).select(1)
	(dialog.get("_partitions") as OptionButton).item_selected.emit(1)
	var tree: Tree = dialog.get("_losses")
	for item: TreeItem in tree.get_root().get_children():
		match item.get_metadata(0):
			HeatRiseDialog.ROW_DEVICE:
				item.set_text(2, "3,5")
			HeatRiseDialog.ROW_WIRES:
				item.set_text(2, "2.5")
			HeatRiseDialog.ROW_TERMINALS, HeatRiseDialog.ROW_EXTRA:
				item.set_text(2, "0")
	tree.item_edited.emit()
	await wait_process_frames(1)
	assert_eq(dialog.evaluated()["missing"].size(), 0, str(dialog.evaluated()["missing"]))
	assert_string_contains((dialog.get("_results") as Label).text, "Δt1,0")
	var s: Dictionary = dialog.settings()
	assert_eq(s["mounting"], 1, "the second of the list")
	assert_eq(s["vented"], false)
	assert_eq(s["partitions"], 0)
	assert_eq((s["losses"] as Dictionary).values()[0], 3.5, "a decimal comma taken")
	dialog.confirmed.emit()
	dialog.hide()
	assert_eq(doc.switchboards[0].heat["height"], 800.0)
	assert_eq(doc.switchboards[0].heat["extra"], 0.0, "0 given, not assumed")
	await wait_process_frames(1)
	for child: Node in (panel.get("_list") as VBoxContainer).get_children():
		if child is Label and (child as Label).text.begins_with("Temperature rise:"):
			summary = child
		if child is Button and (child as Button).text == "Temperature rise…":
			open = child
	assert_string_contains(summary.text, "at the top about")
	# A cell emptied is not given any more.
	open.pressed.emit()
	(fields["depth"] as LineEdit).text = ""
	(fields["depth"] as LineEdit).text_changed.emit("")
	assert_false(dialog.settings().has("depth"))
	dialog.hide()


## Switchboard 0 of [param doc] with everything its calculation needs given.
func _all_given(doc: SchematicDocument, changes: Dictionary = {}) -> void:
	var wires: Array = HeatRiseReport.layout(doc, 0).wiring.wires
	var lost: Dictionary = HeatRise.evaluate(doc, 0, wires, {})["losses"]
	var s: Dictionary = _given({"height": 800.0, "width": 600.0, "depth": 250.0, "terminals": 0.5, "extra": 0.0, "losses": {}, "sections": {}})
	for device: Dictionary in lost["devices"]:
		s["losses"][device["designation"]] = 3.0
	for group: Dictionary in lost["groups"]:
		s["sections"][group["key"]] = 2.5
	s.merge(changes, true)
	doc.switchboards[0].heat = HeatRise.settings(s)


func test_device_tells_what_it_is() -> void:
	var doc: SchematicDocument = _filled_board()
	var lost: Dictionary = HeatRise.evaluate(doc, 0, [], {})["losses"]
	for device: Dictionary in lost["devices"]:
		var c: CircuitComponent = CabinetDevices.device(doc.circuit, device["designation"])
		var text: String = HeatRiseReport.device_text(doc, device["designation"])
		if c is CircuitBreaker or c is MotorBreaker:
			assert_string_contains(text, "%d" % roundi(float(c.get("rated_current"))), "the rated current of -%s: %s" % [device["designation"], text])
			assert_false(text.begins_with("Circuit breaker, Circuit breaker"), "named once")
		if c is OverloadRelay:
			assert_string_contains(text, "Ir ")


func test_protocol_shows_the_whole_calculation() -> void:
	var doc: SchematicDocument = _filled_board()
	_all_given(doc)
	var rows: Array[Dictionary] = HeatRiseReport.new().rows(doc, 0)
	var texts: PackedStringArray = PackedStringArray()
	for row: Dictionary in rows:
		if row.has("text"):
			texts.append(row["text"])
		if row.has("cells"):
			texts.append(" | ".join(PackedStringArray(row["cells"].map(func(c: Variant) -> String: return str(c)))))
	var all: String = "\n".join(texts)
	for part: String in ["1. Data given", "2. Power lost at the rated currents P", "3. Effective cooling surface Ae", "4. Temperature rise",
			"5. Temperature of the air inside", "Height of the enclosure h | 800 mm", "R20 (mΩ/m)", "Ae | ", "k · d · P^x", "c · Δt0,5", "Rail 1", "Result: at the top"]:
		assert_string_contains(all, part)
	var e: Dictionary = HeatRise.evaluate(doc, 0, HeatRiseReport.layout(doc, 0).wiring.wires)
	assert_string_contains(all, "%s K" % HeatRiseReport._n(e["result"]["top"], 2), "Δt1,0 as worked out")
	assert_eq(rows.filter(func(r: Dictionary) -> bool: return r["type"] == "curve").size(), 1, "the curve")
	# Shared out over A4 sheets: every row once, a table going on repeats its heading.
	var sheets: Array[Array] = HeatRiseSheet.split(rows)
	assert_gt(sheets.size(), 0)
	for sheet: Array in sheets:
		var height: float = 0.0
		for row: Dictionary in sheet:
			height += HeatRiseSheet.HEIGHTS[row["type"]]
		assert_lte(height, HeatRiseSheet.SIZE.y + 0.01, "fits its sheet")
	# Not all given: says what is missing, no calculation.
	doc.switchboards[0].heat.erase("ambient")
	rows = HeatRiseReport.new().rows(doc, 0)
	var headings: Array = rows.filter(func(r: Dictionary) -> bool: return r["type"] == "heading").map(func(r: Dictionary) -> String: return r["text"])
	assert_true(headings.has("Not worked out: still to give"))
	assert_false(headings.has("4. Temperature rise"))


func test_protocol_of_a_ventilated_board_in_sections() -> void:
	var doc: SchematicDocument = _filled_board()
	_all_given(doc, {"height": 2200.0, "width": 2900.0, "depth": 800.0, "vented": true, "inlet": 1220.0, "outlet": 1800.0, "partitions": 2})
	var rows: Array[Dictionary] = HeatRiseReport.new().rows(doc, 0)
	var all: String = ""
	for row: Dictionary in rows:
		all += str(row.get("text", "")) + " ".join(PackedStringArray(row.get("cells", []).map(func(c: Variant) -> String: return str(c)))) + "\n"
	assert_string_contains(all, "reckoned in 2 sections")
	assert_string_contains(all, "fig. 4 (with openings): inlet 610 cm²")
	assert_string_contains(all, "table 5 (with openings), 2 partitions")
	assert_string_contains(all, "fig. 5: inlet 610 cm²")


func test_export_has_the_protocol() -> void:
	var doc: SchematicDocument = _filled_board()
	_all_given(doc)
	assert_true(SheetRenderer.available(doc)["heat_rise"])
	var renderer: SheetRenderer = SheetRenderer.new()
	renderer.schematic = false
	renderer.heat_rise = true
	var specs: Array[Dictionary] = renderer.sheets(doc, PackedInt32Array())
	assert_gt(specs.size(), 0)
	for spec: Dictionary in specs:
		assert_eq(spec["kind"], "heat_rise")
		assert_eq(spec["board"], 0)
	renderer.heat_rise = false
	assert_eq(renderer.sheets(doc, PackedInt32Array()).size(), 0, "only when chosen")
	renderer.free()
	assert_true(ExportPreview.CONTENTS.has("heat_rise"))


func test_whole_list_over_the_screen_takes_what_is_typed() -> void:
	var doc: SchematicDocument = _filled_board()
	var dialog: HeatRiseDialog = HeatRiseDialog.new()
	add_child_autofree(dialog)
	dialog.open(doc, 0, HeatRiseReport.layout(doc, 0))
	(dialog.get("_wide_button") as Button).pressed.emit()
	var wide: AcceptDialog = dialog.get("_wide")
	assert_true(wide.visible)
	var tree: Tree = dialog.get("_wide_losses")
	var first: TreeItem = tree.get_root().get_first_child()
	assert_string_contains(first.get_text(1), ",", "what tells the device apart: %s" % first.get_text(1))
	var designation: String = first.get_metadata(1)
	first.set_text(2, "4,2")
	tree.item_edited.emit()
	await wait_process_frames(1)
	assert_eq(dialog.settings()["losses"][designation], 4.2)
	wide.hide()
	var small: Tree = dialog.get("_losses")
	assert_eq(small.get_root().get_first_child().get_text(2), "4.2", "the dialog's table follows")
	dialog.hide()
