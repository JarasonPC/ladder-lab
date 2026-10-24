class_name HeatRiseDialog
extends ConfirmationDialog
## The temperature rise of a switchboard ([HeatRise]) worked out from what
## is on its rails and what the user gives here, nothing assumed: the
## enclosure (its size, how it is installed, whether it has ventilation
## openings and how large, horizontal partitions), the air round it and the
## most the air inside may reach; each device's loss at its rated current
## (from its maker), the cross-section of the wires on the nets of each rated
## current (their lengths come from the wiring laid out), what the strip
## terminals lose and further losses. An empty field is not given. Until all
## is, the result says what is missing; then it follows every change: Ae, k,
## c, the rise half way up and at the top, the temperature of each rail, the
## curve over the height, what the method could not cover. OK gives the
## settings back ([signal saved]).

## The settings were confirmed (see [method HeatRise.settings]).
signal saved(settings: Dictionary)

## Rows of the losses table by what they ask (metadata of column 0).
const ROW_DEVICE: String = "device"
const ROW_WIRES: String = "wires"
const ROW_TERMINALS: String = "terminals"
const ROW_EXTRA: String = "extra"

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
var _fields: Dictionary[String, LineEdit] = {}
var _plate_note: Label
var _mounting_label: Label
var _mounting: OptionButton
var _vented_label: Label
var _vented: OptionButton
var _partitions: OptionButton
var _losses: Tree
var _loss_hint: Label
var _results: Label
var _verdict: Label
var _warnings: Label
var _curve: HeatRiseCurve


func _init() -> void:
	min_size = Vector2i(1020, 560)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	# The enclosure and the air round it.
	var left: VBoxContainer = _column(row, 260.0)
	_caption(left)
	var grid: GridContainer = _grid(left)
	for key: String in ["height", "width", "depth"]:
		_field(grid, key, " mm")
	_plate_note = _muted(left)
	_caption(left)
	_mounting_label = _plain(left)
	_mounting = _option(left)
	_mounting.item_selected.connect(func(index: int) -> void: _choose("mounting", index - 1))
	_vented_label = _plain(left)
	_vented = _option(left)
	_vented.item_selected.connect(func(index: int) -> void: _choose("vented", null if index == 0 else index == 2))
	var vents: GridContainer = _grid(left)
	_field(vents, "inlet", " cm²")
	_field(vents, "outlet", " cm²")
	var more: GridContainer = _grid(left)
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	more.add_child(label)
	_labels.append(label)
	_partitions = OptionButton.new()
	_partitions.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_partitions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_partitions.item_selected.connect(func(index: int) -> void: _choose("partitions", index - 1))
	more.add_child(_partitions)
	_field(more, "ambient", " °C")
	_field(more, "limit", " °C")
	# The losses.
	var middle: VBoxContainer = _column(row, 380.0)
	_caption(middle)
	_losses = Tree.new()
	_losses.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_losses.hide_root = true
	_losses.columns = 4
	_losses.column_titles_visible = true
	_losses.select_mode = Tree.SELECT_ROW
	_losses.set_column_expand(0, false)
	_losses.set_column_custom_minimum_width(0, 64)
	for c: int in [2, 3]:
		_losses.set_column_expand(c, false)
		_losses.set_column_custom_minimum_width(c, 76)
	_losses.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_losses.custom_minimum_size = Vector2(380, 280)
	_losses.item_edited.connect(_cell_typed)
	middle.add_child(_losses)
	_loss_hint = _muted(middle)
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
		tr("Horizontal partitions"), tr("Ambient temperature"), tr("Most allowed inside")]
	for i: int in _labels.size():
		_labels[i].text = labels[i]
	_fields["limit"].tooltip_text = tr("The warmest the air round the devices may get: see their makers' data")
	_plate_note.text = tr("The mounting plate as laid out: %s × %s mm (width × height); the enclosure is larger.") % [String.num(_plate.x, 0), String.num(_plate.y, 0)] if _plate.x > 0.0 else ""
	_mounting_label.text = tr("How the enclosure is installed")
	_vented_label.text = tr("Ventilation openings")
	var choose: String = tr("— choose —")
	_mounting.clear()
	_mounting.add_item(choose)
	for mounting: Dictionary in HeatRise.MOUNTINGS:
		_mounting.add_item("%d · %s" % [mounting["curve"], tr(mounting["title"])])
	_mounting.tooltip_text = tr("How the enclosure is installed (fig. 1 of the method): which of its surfaces give off heat")
	_vented.clear()
	for text: String in [choose, tr("Without ventilation openings"), tr("With ventilation openings")]:
		_vented.add_item(text)
	_partitions.clear()
	_partitions.add_item(choose)
	for n: int in HeatRise.MAX_PARTITIONS + 1:
		_partitions.add_item(str(n))
	_losses.set_column_title(0, tr("Item"))
	_losses.set_column_title(1, tr("What"))
	_losses.set_column_title(2, tr("Given"))
	_losses.set_column_title(3, tr("Loss (W)"))
	_loss_hint.text = tr("Type each device's loss at its rated current from its maker's data, and the cross-section of the wires on the nets of each rated current: their lengths come from the wiring laid out and the loss as annex H of ČSN EN 61439-1 reckons it at 70 °C. An empty cell is not given.")
	_fill()
	popup_centered_clamped(Vector2i(1100, 680), 0.92)


## The settings being edited.
func settings() -> Dictionary:
	return _settings


## The last calculation (see [method HeatRise.evaluate]).
func evaluated() -> Dictionary:
	return _evaluated


## A number typed in field [param key]: given, or not when it is empty or
## not a number.
func _typed(key: String, text: String) -> void:
	if _filling:
		return
	var value: Variant = _number(text)
	if value == null:
		_settings.erase(key)
	else:
		_settings[key] = value
	_refresh()


## [param value] chosen for [param key] (null or a negative index: none).
func _choose(key: String, value: Variant) -> void:
	if _filling:
		return
	if value == null or (value is int and value < 0):
		_settings.erase(key)
	else:
		_settings[key] = value
	_fill()


## A cell typed in the losses table: a device's loss, a cross-section, the
## strip terminals' or the further losses (empty: not given).
func _cell_typed() -> void:
	for item: TreeItem in _losses.get_root().get_children():
		var what: Variant = item.get_metadata(0)
		if what == null:
			continue
		var value: Variant = _number(item.get_text(2))
		match what:
			ROW_DEVICE, ROW_WIRES:
				var store: String = "losses" if what == ROW_DEVICE else "sections"
				var given: Dictionary = _settings.get(store, {})
				var name: String = item.get_metadata(1)
				if value == null or (what == ROW_WIRES and value <= 0.0):
					given.erase(name)
				else:
					given[name] = value
				if given.is_empty():
					_settings.erase(store)
				else:
					_settings[store] = given
			_:
				var key: String = "terminals" if what == ROW_TERMINALS else "extra"
				if value == null:
					_settings.erase(key)
				else:
					_settings[key] = value
	_refresh.call_deferred()


## [param text] as a number (a decimal comma too), null when it is empty or
## not a number or negative.
static func _number(text: String) -> Variant:
	var t: String = text.strip_edges().replace(",", ".")
	if t.is_empty() or not t.is_valid_float() or t.to_float() < 0.0:
		return null
	return t.to_float()


## The fields from the settings, then the table and the result.
func _fill() -> void:
	_filling = true
	for key: String in _fields:
		var field: LineEdit = _fields[key]
		field.text = _shown(_settings.get(key)) if not field.has_focus() else field.text
	_mounting.select(int(_settings.get("mounting", -1)) + 1)
	_vented.select(0 if not _settings.has("vented") else (2 if _settings["vented"] else 1))
	_partitions.select(int(_settings.get("partitions", -1)) + 1)
	var vented: bool = _settings.get("vented", false)
	for key: String in ["inlet", "outlet"]:
		_fields[key].editable = vented
		_fields[key].placeholder_text = "" if vented else "—"
	_filling = false
	_refresh()


## The table and the result again (the fields as they are).
func _refresh() -> void:
	_evaluated = HeatRise.evaluate(_document, _board, _wires, _settings)
	_fill_losses()
	_fill_result()


func _fill_losses() -> void:
	var losses: Dictionary = _evaluated["losses"]
	_losses.clear()
	var root: TreeItem = _losses.create_item()
	for device: Dictionary in losses["devices"]:
		_row(root, ROW_DEVICE, device["designation"], device["designation"], tr(CabinetPanel.KIND_TITLES[device["kind"]]), device["power"], device["power"], tr("W, from the maker"))
	for group: Dictionary in losses["groups"]:
		var what: String = tr("Wires (%d, %s m), cross-section mm²") % [group["count"], String.num(group["length"], 1)]
		_row(root, ROW_WIRES, group["key"], "%s A" % group["key"], what, group["section"], group["power"], tr("mm²"))
	if losses["terminal_count"] > 0:
		_row(root, ROW_TERMINALS, "", "", tr("Strip terminals (%d), all together") % losses["terminal_count"], losses["terminals"], losses["terminals"], tr("W"))
	_row(root, ROW_EXTRA, "", "", tr("Further losses (lighting, fans, heaters …)"), losses["extra"], losses["extra"], tr("W"))
	var total: TreeItem = _losses.create_item(root)
	total.set_text(1, tr("Total P"))
	total.set_text(3, String.num(losses["total"], 1) if losses["total"] != null else "?")
	total.set_text_alignment(3, HORIZONTAL_ALIGNMENT_RIGHT)
	for c: int in 4:
		total.set_custom_color(c, AppTheme.accent)


## A row of the losses table asking [param what] ([param name] the device or
## the current), [param given] typed in column 2 (null: not given yet,
## marked), [param loss] in column 3.
func _row(root: TreeItem, what: String, name: String, item_text: String, text: String, given: Variant, loss: Variant, unit: String) -> void:
	var item: TreeItem = _losses.create_item(root)
	item.set_metadata(0, what)
	item.set_metadata(1, name)
	item.set_text(0, item_text)
	item.set_text(1, text)
	item.set_tooltip_text(1, text)
	item.set_text(2, _shown(given))
	item.set_editable(2, true)
	item.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)
	item.set_tooltip_text(2, unit)
	item.set_text(3, String.num(loss, 1) if loss != null else "")
	item.set_text_alignment(3, HORIZONTAL_ALIGNMENT_RIGHT)
	if given == null:
		item.set_custom_bg_color(2, Color(AppTheme.warning, 0.25))
		item.set_tooltip_text(2, tr("Not given yet (%s)") % unit)


func _fill_result() -> void:
	var gaps: Array = _evaluated["missing"]
	if not gaps.is_empty():
		var lines: PackedStringArray = PackedStringArray([tr("Still to give:")])
		for gap: Dictionary in gaps:
			lines.append("• " + (tr(gap["text"]) % gap["args"] if not (gap["args"] as Array).is_empty() else tr(gap["text"])))
		_results.text = "\n".join(lines)
		_verdict.text = ""
		_warnings.text = ""
		_curve.result = {}
		_curve.queue_redraw()
		return
	var r: Dictionary = _evaluated["result"]
	var section: Dictionary = r["section"]
	var size: Vector3 = _evaluated["size"]
	var lines: PackedStringArray = PackedStringArray()
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
	var from_top: float = (size.x - _plate.y) / 2.0 + rail.get_center().y
	return clampf(1.0 - from_top / size.x, 0.0, 1.0)


## A number as typed back into its field ("" for none).
static func _shown(value: Variant) -> String:
	if value == null:
		return ""
	return HeatRise._num(float(value)) if absf(float(value) - roundf(float(value))) < 0.005 else String.num(float(value), 3)


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


func _plain(column: VBoxContainer) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(label)
	return label


func _grid(column: VBoxContainer) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	column.add_child(grid)
	return grid


func _option(column: VBoxContainer) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	option.fit_to_longest_item = false
	option.clip_text = true
	column.add_child(option)
	return option


## A labelled number field for [param key] ([param unit] after it); empty
## while not given.
func _field(grid: GridContainer, key: String, unit: String) -> void:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	grid.add_child(label)
	_labels.append(label)
	var box: HBoxContainer = HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(box)
	var field: LineEdit = LineEdit.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.select_all_on_focus = true
	field.text_changed.connect(func(text: String) -> void: _typed(key, text))
	box.add_child(field)
	var suffix: Label = Label.new()
	suffix.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	suffix.theme_type_variation = "MutedLabel"
	suffix.text = unit.strip_edges()
	suffix.custom_minimum_size.x = 30.0
	box.add_child(suffix)
	_fields[key] = field
