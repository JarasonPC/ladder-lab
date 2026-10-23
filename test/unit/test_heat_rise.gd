extends GutTest
## The temperature rise of a switchboard by calculation (IEC 890 / ČSN 33
## 7107): the method's two worked examples, small and ventilated enclosures,
## sections, the curve over the height, the settings saved, the losses of
## devices, wires and terminals, and the switchboard panel's heat rise dialog.


func after_all() -> void:
	RecoveryFile.forget()


func _settings(changes: Dictionary) -> Dictionary:
	var s: Dictionary = HeatRise.settings({})
	s.merge(changes, true)
	return s


func test_example_one_closed_free_on_all_sides() -> void:
	# 2200 x 1000 x 500 mm, free on all sides, closed, 300 W.
	var r: Dictionary = HeatRise.calculate(Vector3(2200, 1000, 500), _settings({"mounting": 0}), 300.0)
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
	var s: Dictionary = _settings({"mounting": 1, "inlet": 1220.0, "outlet": 1800.0, "partitions": 2})
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


func test_small_enclosure_and_warnings() -> void:
	# A consumer unit 500 x 400 x 110 mm on a wall: Ae under 1.25 m².
	var r: Dictionary = HeatRise.calculate(Vector3(500, 400, 110), _settings({}), 30.0)
	var section: Dictionary = r["section"]
	assert_true(section["small"])
	assert_almost_eq(section["ae"], 0.4*0.11*1.4 + 0.2*0.9 + 0.2*0.5 + 2*0.11*0.5*0.9, 1e-4)
	assert_almost_eq(section["k"], HeatRise.SMALL_K * pow(section["ae"], HeatRise.SMALL_EXP), 1e-6, "fig. 6")
	assert_eq(section["factor"], "g")
	assert_almost_eq(section["c"], 1.215, 0.01, "fig. 7 at g = 1.25")
	assert_almost_eq(HeatRise.rise_at(r, 0.9), r["top"], 1e-6, "the top quarter as warm as the top")
	assert_almost_eq(HeatRise.rise_at(r, 0.5), r["half"], 1e-6)
	assert_between(HeatRise.rise_at(r, 0.0), 0.0, r["half"], "the line on down, on the safe side")
	# Openings on a small one: reckoned closed, said so; too small outlets; partitions.
	var s: Dictionary = _settings({"inlet": 100.0, "outlet": 50.0, "partitions": 4})
	r = HeatRise.calculate(Vector3(500, 400, 110), s, 30.0)
	var texts: Array = r["warnings"].map(func(w: Dictionary) -> String: return w["text"])
	assert_false(r["section"]["vented"])
	assert_eq(texts.size(), 3, str(texts))
	# A large closed one past fig. 2 is reckoned in sections.
	r = HeatRise.calculate(Vector3(2200, 1400, 1200), _settings({"mounting": 0}), 500.0)
	assert_eq(r["sections"], 2, "over 11.5 m² of Ae")
	assert_lt(r["section"]["ae"], HeatRise.MAX_AE)
	# The curve over the height of a large one: a straight line.
	r = HeatRise.calculate(Vector3(2200, 1000, 500), _settings({"mounting": 0}), 300.0)
	assert_almost_eq(HeatRise.rise_at(r, 0.75), (r["half"] + r["top"]) / 2.0, 1e-6)


func test_settings_kept_and_cleaned() -> void:
	var s: Dictionary = HeatRise.settings({"height": 800, "mounting": 9, "partitions": "two", "ambient": 40, "losses": {"FA1": 2.5, "KM1": -1}})
	assert_eq(s["height"], 800.0)
	assert_eq(s["mounting"], HeatRise.DEFAULTS["mounting"], "out of range")
	assert_eq(s["partitions"], 0, "wrong type")
	assert_eq(s["ambient"], 40.0)
	assert_eq(s["losses"], {"FA1": 2.5}, "a negative loss dropped")
	assert_eq(HeatRise.changed(s), {"height": 800.0, "ambient": 40.0, "losses": {"FA1": 2.5}})
	assert_eq(HeatRise.enclosure(HeatRise.settings({}), Vector2(530, 712), false), Vector3(800, 600, 250), "from the plate, rounded up")
	assert_eq(HeatRise.enclosure(HeatRise.settings({"depth": 300}), Vector2(530, 712), true), Vector3(800, 600, 300))
	assert_eq(HeatRise.enclosure(HeatRise.settings({}), Vector2(300, 400), true).z, HeatRise.UNIT_DEPTH, "a consumer unit")


func test_losses_of_devices_wires_and_terminals() -> void:
	assert_eq(HeatRise.section_for(2.0), HeatRise.CONTROL_SECTION)
	assert_eq(HeatRise.section_for(16.0), 1.5)
	assert_eq(HeatRise.section_for(20.0), 2.5)
	# 10 A in 2 m of 1.5 mm² (it takes 16 A): 10² · 12.1 mΩ · 1.2 · 2 m.
	assert_almost_eq(HeatRise.conductor_loss(10.0, 2.0), 100.0 * 0.0121 * 1.2 * 2.0, 1e-6)
	var breaker: CircuitBreaker = CircuitBreaker.new("FA1")
	breaker.rated_current = 16.0
	assert_eq(HeatRise.estimate(breaker), 3.5, "ČSN EN 60898-1 at 16 A")
	var rcd: ResidualCurrentDevice = ResidualCurrentDevice.new("FB1", 4)
	rcd.rated_current = 40.0
	assert_eq(HeatRise.estimate(rcd), 30.0, "four poles of 7.5 W")
	var doc: SchematicDocument = ExampleCircuits.build(ExampleCircuits.TITLES.find("Direct-on-line start 3~"))
	if doc.switchboards.is_empty():
		doc.add_switchboard()
	doc.fill_cabinet(0)
	var s: Dictionary = HeatRise.settings({"losses": {"KM1": 7.0}, "extra": 5.0})
	var layout: CabinetLayout = CabinetLayout.build(doc, 1.0, 0)
	var losses: Dictionary = HeatRise.losses(doc, 0, layout.wiring.wires, s)
	var names: Array = losses["devices"].map(func(d: Dictionary) -> String: return d["designation"])
	assert_true(names.has("KM1"), str(names))
	assert_gt(names.size(), 2, str(names))
	var km1: Dictionary = losses["devices"].filter(func(d: Dictionary) -> bool: return d["designation"] == "KM1")[0]
	assert_eq(km1["power"], 7.0, "set by hand")
	assert_true(km1["set"])
	assert_eq(km1["estimate"], HeatRise.CONTACTOR)
	assert_gt(losses["wire_count"], 0)
	assert_gt(losses["wire_length"], 0.0)
	assert_gt(losses["wires"], 0.0, "power wires carry their breaker's current")
	var sum: float = losses["wires"] + losses["terminals"] + 5.0
	for device: Dictionary in losses["devices"]:
		sum += device["power"]
	assert_almost_eq(losses["total"], sum, 1e-6)


func _filled_board() -> SchematicDocument:
	var doc: SchematicDocument = ExampleCircuits.build(ExampleCircuits.TITLES.find("Direct-on-line start 3~"))
	if doc.switchboards.is_empty():
		doc.add_switchboard()
	doc.fill_cabinet(0)
	return doc


func test_settings_saved_with_the_switchboard() -> void:
	var doc: SchematicDocument = _filled_board()
	doc.switchboards[0].heat = HeatRise.changed(HeatRise.settings({"width": 600.0, "inlet": 200.0, "outlet": 250.0, "losses": {"KM1": 6.0}}))
	var again: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(again.switchboards[0].heat, {"width": 600.0, "inlet": 200.0, "outlet": 250.0, "losses": {"KM1": 6.0}})
	doc.switchboards[0].heat = {}
	assert_false(doc.switchboards[0].to_data().has("heat"), "nothing saved for the defaults")


func test_panel_shows_the_rise_and_the_dialog_saves_what_is_filled_in() -> void:
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
	var list: VBoxContainer = panel.get("_list")
	var open: Button = null
	var summary: Label = null
	for child: Node in list.get_children():
		if child is Button and (child as Button).text == "Temperature rise…":
			open = child
		if child is Label and (child as Label).text.begins_with("Temperature rise:"):
			summary = child
	assert_not_null(open, "the button under the tools")
	assert_not_null(summary, "how warm it gets, under the tools")
	assert_false(open.disabled)
	open.pressed.emit()
	var dialog: HeatRiseDialog = panel.get("_heat_dialog")
	assert_true(dialog.visible)
	var evaluated: Dictionary = dialog.evaluated()
	assert_gt(evaluated["size"].x, 0.0, "sized by the mounting plate")
	assert_gt(evaluated["losses"]["total"], 0.0)
	# Fill in: 40 °C around, ventilation openings, a contactor's figure.
	(dialog.get("_ambient") as SpinBox).value = 40.0
	(dialog.get("_vented") as CheckBox).button_pressed = true
	assert_gt(dialog.settings()["inlet"], 0.0, "openings given")
	assert_gte(dialog.settings()["outlet"], HeatRise.OUTLET_SHARE * dialog.settings()["inlet"], "outlets 1.1 times")
	var tree: Tree = dialog.get("_losses")
	var row: TreeItem = tree.get_root().get_first_child()
	var designation: String = row.get_metadata(0)
	row.set_range(2, 12.5)
	tree.item_edited.emit()
	await wait_process_frames(1)
	assert_eq(dialog.settings()["losses"], {designation: 12.5}, "typed over the estimate")
	assert_string_contains((dialog.get("_results") as Label).text, "Δt1,0")
	dialog.confirmed.emit()
	dialog.hide()
	var heat: Dictionary = doc.switchboards[0].heat
	assert_eq(heat["ambient"], 40.0)
	assert_gt(heat["inlet"], 0.0)
	assert_eq(heat["losses"], {designation: 12.5})
	assert_false(heat.has("height"), "the size still follows the plate")
	# Back to the estimates.
	open.pressed.emit()
	(dialog.get("_estimates_button") as Button).pressed.emit()
	assert_eq(dialog.settings()["losses"], {})
	dialog.hide()
