class_name HeatRiseDialog
extends ConfirmationDialog
## The temperature rise of a switchboard ([HeatRise]) worked out from what
## is on its rails and what is filled in here: the enclosure (its size,
## from the mounting plate unless typed, how it is installed, ventilation
## openings, horizontal partitions), the air round it and the most the air
## inside may reach; the losses of each device at its rated current (an
## estimate until a maker's figure is typed over it), of the wires and
## terminals laid out and further losses. The result follows every change:
## Ae, k, c, the rise half way up and at the top, the temperature of each
## rail, the curve over the height, what the method could not cover. OK
## gives the settings back ([signal saved]).

## The settings were confirmed (see [method HeatRise.settings]).
signal saved(settings: Dictionary)

var _document: SchematicDocument
var _board: int = -1
var _plate: Vector2 = Vector2.ZERO
var _wires: Array = []
var _rails: Array[Rect2] = []
var _settings: Dictionary = {}
## The last calculation (see [method HeatRise.evaluate]).
var _evaluated: Dictionary = {}
## Fields being filled from the settings: their signals change nothing.
var _filling: bool = false

var _captions: Array[Label] = []
var _labels: Array[Label] = []
var _height: SpinBox
var _width: SpinBox
var _depth: SpinBox
var _plate_button: Button
var _mounting: OptionButton
var _vented: CheckBox
var _inlet: SpinBox
var _outlet: SpinBox
var _partitions: SpinBox
var _ambient: SpinBox
var _limit: SpinBox
var _extra: SpinBox
var _losses: Tree
var _loss_hint: Label
var _estimates_button: Button
var _results: Label
var _verdict: Label
var _warnings: Label
var _curve: HeatRiseCurve


func _init() -> void:
	min_size = Vector2i(980, 560)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	# The enclosure and the air round it.
	var left: VBoxContainer = _column(row, 250.0)
	_caption(left)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	left.add_child(grid)
	_height = _number(grid, 0.0, 5000.0, 10.0, " mm")
	_width = _number(grid, 0.0, 10000.0, 10.0, " mm")
	_depth = _number(grid, 0.0, 2000.0, 10.0, " mm")
	_plate_button = Button.new()
	_plate_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_plate_button.focus_mode = Control.FOCUS_NONE
	_plate_button.pressed.connect(func() -> void:
		for key: String in ["height", "width", "depth"]:
			_settings[key] = 0.0
		_fill())
	left.add_child(_plate_button)
	_caption(left)
	_mounting = OptionButton.new()
	_mounting.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_mounting.fit_to_longest_item = false
	_mounting.clip_text = true
	_mounting.item_selected.connect(func(index: int) -> void: _put("mounting", index))
	left.add_child(_mounting)
	_vented = CheckBox.new()
	_vented.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_vented.toggled.connect(func(on: bool) -> void:
		if _filling:
			return
		_settings["inlet"] = maxf(_inlet.value, 100.0) if on else 0.0
		if on and _settings["outlet"] < HeatRise.OUTLET_SHARE * _settings["inlet"]:
			_settings["outlet"] = ceilf(HeatRise.OUTLET_SHARE * _settings["inlet"])
		_fill())
	left.add_child(_vented)
	var vents: GridContainer = GridContainer.new()
	vents.columns = 2
	vents.add_theme_constant_override("h_separation", 8)
	left.add_child(vents)
	_inlet = _number(vents, 0.0, 20000.0, 10.0, " cm²")
	_outlet = _number(vents, 0.0, 20000.0, 10.0, " cm²")
	var more: GridContainer = GridContainer.new()
	more.columns = 2
	more.add_theme_constant_override("h_separation", 8)
	left.add_child(more)
	_partitions = _number(more, 0.0, HeatRise.MAX_PARTITIONS, 1.0, "")
	_ambient = _number(more, -40.0, 80.0, 1.0, " °C")
	_limit = _number(more, 0.0, 150.0, 1.0, " °C")
	_extra = _number(more, 0.0, 10000.0, 1.0, " W")
	var fields: Dictionary[String, SpinBox] = {"height": _height, "width": _width, "depth": _depth, "inlet": _inlet,
		"outlet": _outlet, "partitions": _partitions, "ambient": _ambient, "limit": _limit, "extra": _extra}
	for key: String in fields:
		var field: SpinBox = fields[key]
		field.value_changed.connect(func(value: float) -> void: _put(key, int(value) if key == "partitions" else value))
	# The losses.
	var middle: VBoxContainer = _column(row, 330.0)
	_caption(middle)
	_losses = Tree.new()
	_losses.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_losses.hide_root = true
	_losses.columns = 3
	_losses.column_titles_visible = true
	_losses.select_mode = Tree.SELECT_ROW
	_losses.set_column_expand(0, false)
	_losses.set_column_custom_minimum_width(0, 70)
	_losses.set_column_expand(2, false)
	_losses.set_column_custom_minimum_width(2, 90)
	_losses.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_losses.custom_minimum_size = Vector2(330, 260)
	_losses.item_edited.connect(_loss_typed)
	middle.add_child(_losses)
	_loss_hint = _muted(middle)
	_estimates_button = Button.new()
	_estimates_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_estimates_button.focus_mode = Control.FOCUS_NONE
	_estimates_button.pressed.connect(func() -> void:
		_settings["losses"] = {}
		_fill())
	middle.add_child(_estimates_button)
	# The result.
	var right: VBoxContainer = _column(row, 330.0)
	_caption(right)
	_results = Label.new()
	_results.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_results.custom_minimum_size.x = 320.0
	right.add_child(_results)
	_verdict = Label.new()
	_verdict.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_verdict.custom_minimum_size.x = 320.0
	right.add_child(_verdict)
	_curve = HeatRiseCurve.new()
	_curve.custom_minimum_size = Vector2(320, 180)
	_curve.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_curve)
	_warnings = _muted(right)
	_warnings.add_theme_color_override("font_color", AppTheme.warning)
	confirmed.connect(func() -> void: saved.emit(_settings.duplicate(true)))


## Shows the calculation of switchboard [param b] of [param doc] laid out
## as [param layout] (its mounting plate, rails and wires).
func open(doc: SchematicDocument, b: int, layout: CabinetLayout) -> void:
	_document = doc
	_board = b
	_plate = layout.size if layout != null else Vector2.ZERO
	_wires = layout.wiring.wires if layout != null and layout.wiring != null else []
	_rails = layout.rails if layout != null else []
	_settings = HeatRise.settings(doc.switchboards[b].heat)
	title = tr("Temperature rise of +%s") % doc.switchboards[b].name
	ok_button_text = tr("OK")
	cancel_button_text = tr("Cancel")
	var captions: Array[String] = [tr("Enclosure"), tr("Installation and air"), tr("Power lost at the rated currents"), tr("Result")]
	for i: int in _captions.size():
		_captions[i].text = captions[i].to_upper()
	var labels: Array[String] = [tr("Height"), tr("Width"), tr("Depth"), tr("Inlet openings"), tr("Outlet openings"),
		tr("Horizontal partitions"), tr("Ambient temperature"), tr("Most allowed inside"), tr("Further losses")]
	for i: int in _labels.size():
		_labels[i].text = labels[i]
	_extra.tooltip_text = tr("Losses of what is not drawn: lighting, fans, heaters, transformers …")
	_limit.tooltip_text = tr("The warmest the air round the devices may get: see their makers' data (55 °C is common; breakers are rated at 30 °C and carry less above it)")
	_plate_button.text = tr("Size from the mounting plate")
	_plate_button.tooltip_text = tr("The enclosure round the mounting plate as laid out, rounded up to 50 mm")
	_vented.text = tr("Ventilation openings")
	_mounting.clear()
	for mounting: Dictionary in HeatRise.MOUNTINGS:
		_mounting.add_item("%d · %s" % [mounting["curve"], tr(mounting["title"])])
	_mounting.tooltip_text = tr("How the enclosure is installed (fig. 1 of the method): which of its surfaces give off heat")
	_losses.set_column_title(0, tr("Device"))
	_losses.set_column_title(1, tr("Kind"))
	_losses.set_column_title(2, tr("Loss (W)"))
	_loss_hint.text = tr("Estimates (breakers and RCDs the most ČSN EN 60898-1 allows); type the maker's figure over them. Wires and terminals from the wiring laid out, at the rated current of the breaker or fuse on their net.")
	_estimates_button.text = tr("Back to the estimates")
	_fill()
	popup_centered_clamped(Vector2i(1060, 680), 0.92)


## The settings being edited.
func settings() -> Dictionary:
	return _settings


## The last calculation (see [method HeatRise.evaluate]).
func evaluated() -> Dictionary:
	return _evaluated


func _put(key: String, value: Variant) -> void:
	if _filling:
		return
	_settings[key] = value
	_fill()


## A loss typed in the table: the devices' losses as the table has them,
## kept by hand where they differ from the estimate.
func _loss_typed() -> void:
	var losses: Dictionary = _settings["losses"]
	for item: TreeItem in _losses.get_root().get_children():
		if item.get_metadata(0) == null:
			continue
		var designation: String = item.get_metadata(0)
		var value: float = maxf(item.get_range(2), 0.0)
		if is_equal_approx(value, float(item.get_metadata(2))):
			losses.erase(designation)
		else:
			losses[designation] = value
	_fill.call_deferred()


## The fields, the table and the result from the settings.
func _fill() -> void:
	_filling = true
	_evaluated = HeatRise.evaluate(_document, _board, _plate, _wires, _settings)
	var size: Vector3 = _evaluated["size"]
	_height.value = size.x
	_width.value = size.y
	_depth.value = size.z
	_plate_button.disabled = _settings["height"] == 0.0 and _settings["width"] == 0.0 and _settings["depth"] == 0.0
	_mounting.select(_settings["mounting"])
	var vented: bool = _settings["inlet"] > 0.0
	_vented.button_pressed = vented
	_inlet.editable = vented
	_outlet.editable = vented
	_inlet.value = _settings["inlet"]
	_outlet.value = _settings["outlet"]
	_partitions.value = _settings["partitions"]
	_ambient.value = _settings["ambient"]
	_limit.value = _settings["limit"]
	_extra.value = _settings["extra"]
	_filling = false
	_fill_losses()
	_fill_result()


func _fill_losses() -> void:
	var losses: Dictionary = _evaluated["losses"]
	_losses.clear()
	var root: TreeItem = _losses.create_item()
	for device: Dictionary in losses["devices"]:
		var item: TreeItem = _losses.create_item(root)
		item.set_text(0, device["designation"])
		item.set_text(1, tr(CabinetPanel.KIND_TITLES[device["kind"]]))
		item.set_cell_mode(2, TreeItem.CELL_MODE_RANGE)
		item.set_range_config(2, 0.0, 10000.0, 0.1)
		item.set_range(2, device["power"])
		item.set_editable(2, true)
		item.set_metadata(0, device["designation"])
		item.set_metadata(2, device["estimate"])
		if not device["set"]:
			item.set_custom_color(2, AppTheme.text_muted)
			item.set_tooltip_text(2, tr("Estimate: type the maker's figure"))
	var rows: Array[Array] = [
		[tr("Wires (%d, %s m)") % [losses["wire_count"], String.num(losses["wire_length"], 1)], losses["wires"]],
		[tr("Strip terminals (%d)") % losses["terminal_count"], losses["terminals"]],
		[tr("Further losses"), losses["extra"]],
	]
	for entry: Array in rows:
		var item: TreeItem = _losses.create_item(root)
		item.set_text(1, entry[0])
		item.set_text(2, String.num(entry[1], 1))
		item.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)
		item.set_selectable(1, false)
	var total: TreeItem = _losses.create_item(root)
	total.set_text(1, tr("Total P"))
	total.set_text(2, String.num(losses["total"], 1))
	total.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)
	for c: int in 3:
		total.set_custom_color(c, AppTheme.accent)


func _fill_result() -> void:
	var r: Dictionary = _evaluated["result"]
	var section: Dictionary = r["section"]
	var size: Vector3 = _evaluated["size"]
	var lines: PackedStringArray = PackedStringArray()
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		_results.text = tr("Give the enclosure's size (nothing is on the rails yet to size it by).")
		_verdict.text = ""
		_warnings.text = ""
		_curve.result = {}
		_curve.queue_redraw()
		return
	if r["sections"] > 1:
		lines.append(tr("Reckoned in %d sections %s m wide (the warmest shown).") % [r["sections"], String.num(section["width"], 2)])
	var parts: PackedStringArray = PackedStringArray()
	for surface: Array in section["surfaces"]:
		parts.append("%s %s × %s" % [tr(surface[0]), String.num(surface[1], 3), String.num(surface[2], 1)])
	lines.append("Ae = %s m²  (%s)" % [String.num(section["ae"], 3), ", ".join(parts)])
	lines.append("P = %s W" % String.num(section["power"], 1))
	lines.append("k = %s,  d = %s,  x = %s" % [String.num(section["k"], 4), String.num(section["d"], 2), String.num(section["x"], 3)])
	lines.append("Δt0,5 = k · d · Pˣ = %s K" % String.num(section["half"], 1))
	lines.append("%s = %s  →  c = %s" % [section["factor"], String.num(section["factor_value"], 2), String.num(section["c"], 3)])
	lines.append("Δt1,0 = c · Δt0,5 = %s K" % String.num(section["top"], 1))
	var rails: PackedStringArray = PackedStringArray()
	for i: int in _rails.size():
		rails.append(tr("Rail %d: %s °C") % [i + 1, String.num(_settings["ambient"] + HeatRise.rise_at(r, _height_of(_rails[i], size)), 0)])
	if not rails.is_empty():
		lines.append(", ".join(rails))
	_results.text = "\n".join(lines)
	var top: String = String.num(r["temperature"], 1)
	if r["ok"]:
		_verdict.text = tr("At the top %s °C: within %s °C.") % [top, String.num(_settings["limit"], 0)]
		_verdict.add_theme_color_override("font_color", AppTheme.success)
	else:
		_verdict.text = tr("At the top %s °C: warmer than %s °C. Make the enclosure larger, give it ventilation openings or lose less power inside.") % [top, String.num(_settings["limit"], 0)]
		_verdict.add_theme_color_override("font_color", AppTheme.danger)
	var notes: PackedStringArray = PackedStringArray()
	for w: Dictionary in r["warnings"]:
		notes.append("• " + (tr(w["text"]) % w["args"] if not (w["args"] as Array).is_empty() else tr(w["text"])))
	_warnings.text = "\n".join(notes)
	_curve.result = r
	_curve.ambient = _settings["ambient"]
	_curve.limit = _settings["limit"]
	_curve.marks.clear()
	for i: int in _rails.size():
		_curve.marks.append(Vector2(_height_of(_rails[i], size), i + 1))
	_curve.queue_redraw()


## Where on the height (0 the floor, 1 the top) the middle of rail
## [param rail] (mm on the plate) is, the plate in the middle of an
## enclosure [param size] high.
func _height_of(rail: Rect2, size: Vector3) -> float:
	if size.x <= 0.0:
		return 0.5
	var from_top: float = (size.x - _plate.y) / 2.0 + rail.get_center().y
	return clampf(1.0 - from_top / size.x, 0.0, 1.0)


func _column(row: HBoxContainer, width: float) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.custom_minimum_size.x = width
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	return column


func _caption(column: VBoxContainer) -> void:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.theme_type_variation = "HeaderLabel"
	column.add_child(label)
	_captions.append(label)


func _muted(column: VBoxContainer) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.theme_type_variation = "MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 240.0
	column.add_child(label)
	return label


func _number(grid: GridContainer, low: float, high: float, step: float, suffix: String) -> SpinBox:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	grid.add_child(label)
	_labels.append(label)
	var field: SpinBox = SpinBox.new()
	field.min_value = low
	field.max_value = high
	field.step = step
	field.suffix = suffix
	field.select_all_on_focus = true
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(field)
	return field
