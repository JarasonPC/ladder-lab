class_name HeatRiseDialog
extends ConfirmationDialog
## The temperature rise of a switchboard ([HeatRise]) worked out from what
## is on its rails and what the user gives here, nothing assumed: the
## enclosure (its size, how it is installed, whether it has ventilation
## openings and how large, horizontal partitions), the air round it and the
## most the air inside may reach; each device's loss at its rated current
## (from its maker), the cross-section of the wires on the nets of each rated
## current (their lengths come from the wiring laid out), what the strip
## terminals lose and further losses; for the protocol, the power loss the
## enclosure takes (from its maker) and each device's type from its maker.
## An empty field is not given. Until all
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
## A device's type from its maker (text, by designation).
const ROW_TYPE: String = "type"

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
var _losses: HeatLossTable
## The losses table over the whole screen, and the button opening it.
var _wide: AcceptDialog
var _wide_losses: HeatLossTable
var _wide_hint: Label
var _wide_button: Button
var _loss_hint: Label
var _results: Label
var _verdict: Label
var _warnings: Label
var _curve: HeatRiseCurve
## The "?" beside the RDF field and the help it opens: what RDF is and the
## values the standards assume, to put in.
var _rdf_help_button: Button
var _rdf_help: RdfHelpDialog


func _init() -> void:
	min_size = Vector2i(1180, 560)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	# The enclosure and the air round it.
	# The enclosure's column scrolls: with the RDF table it is taller than the others.
	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.custom_minimum_size = Vector2(290, 420)
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_scroll)
	var left: VBoxContainer = _column(row, 270.0)
	row.remove_child(left)
	left_scroll.add_child(left)
	_caption(left)
	var grid: GridContainer = _grid(left)
	for key: String in ["height", "width", "depth"]:
		_field(grid, key, " mm")
	_field(grid, "enclosure_loss", " W")
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
	# The rated diversity factor, one for the switchboard; its help ("?") says
	# what it is and has the values the standards give to put in.
	_caption(left)
	var rdf_grid: GridContainer = _grid(left)
	_field(rdf_grid, "rdf", "")
	_rdf_help_button = Button.new()
	_rdf_help_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_rdf_help_button.focus_mode = Control.FOCUS_NONE
	_rdf_help_button.text = "?"
	_rdf_help_button.custom_minimum_size.x = 30.0
	_rdf_help_button.pressed.connect(func() -> void: _rdf_help.open())
	var rdf_box: Control = _fields["rdf"].get_parent()
	rdf_box.add_child(_rdf_help_button)
	rdf_box.move_child(_rdf_help_button, 1)
	_rdf_help = RdfHelpDialog.new()
	_rdf_help.chosen.connect(func(rdf: float) -> void:
		_settings["rdf"] = rdf
		_fill())
	add_child(_rdf_help)
	# The losses.
	var middle: VBoxContainer = _column(row, 540.0)
	_caption(middle)
	_losses = HeatLossTable.new()
	_losses.custom_minimum_size = Vector2(540, 260)
	_losses.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_losses.typed.connect(_loss_typed)
	middle.add_child(_losses)
	_wide_button = Button.new()
	_wide_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_wide_button.focus_mode = Control.FOCUS_NONE
	_wide_button.icon = AppTheme.icon("window")
	_wide_button.pressed.connect(func() -> void:
		_wide_losses.fill(_document, _evaluated["losses"], _board)
		_wide.popup_centered_ratio(0.97))
	middle.add_child(_wide_button)
	_loss_hint = _muted(middle)
	# The same table over the whole screen: every row, the whole of each text.
	_wide = AcceptDialog.new()
	_wide.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var wide_column: VBoxContainer = VBoxContainer.new()
	_wide.add_child(wide_column)
	_wide_hint = _muted(wide_column)
	_wide_losses = HeatLossTable.new()
	_wide_losses.field_width = 140.0
	_wide_losses.item_width = 100.0
	_wide_losses.type_width = 200.0
	_wide_losses.text_width = 360.0
	_wide_losses.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wide_losses.typed.connect(_loss_typed)
	wide_column.add_child(_wide_losses)
	_wide.visibility_changed.connect(func() -> void:
		if not _wide.visible:
			_losses.fill(_document, _evaluated["losses"], _board))
	add_child(_wide)
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
	var captions: Array[String] = [tr("Enclosure"), tr("Installation and air"), tr("Rated diversity factor"), tr("Power lost at the rated currents"), tr("Result")]
	_rdf_help_button.tooltip_text = tr("What the rated diversity factor is, and the values the standards assume")
	# Framed like a field beside it, so it reads as a button (the theme's are flat).
	_rdf_help_button.add_theme_stylebox_override("normal", AppTheme.box(AppTheme.bg1, AppTheme.RADIUS, 9.0, 4.0, AppTheme.border, 1))
	_rdf_help_button.add_theme_stylebox_override("hover", AppTheme.box(AppTheme.bg2, AppTheme.RADIUS, 9.0, 4.0, AppTheme.border_strong, 1))
	_rdf_help_button.add_theme_stylebox_override("pressed", AppTheme.box(AppTheme.accent_soft, AppTheme.RADIUS, 9.0, 4.0, AppTheme.accent, 1))
	_rdf_help_button.add_theme_stylebox_override("hover_pressed", AppTheme.box(AppTheme.accent_soft, AppTheme.RADIUS, 9.0, 4.0, AppTheme.accent, 1))
	for i: int in _captions.size():
		_captions[i].text = captions[i].to_upper()
	var labels: Array[String] = [tr("Height"), tr("Width"), tr("Depth"), tr("Power loss it takes"), tr("Inlet openings"), tr("Outlet openings"),
		tr("Horizontal partitions"), tr("Ambient temperature"), tr("Most allowed inside"), tr("RDF")]
	for i: int in _labels.size():
		_labels[i].text = labels[i]
	_fields["limit"].tooltip_text = tr("The warmest the air round the devices may get: see their makers' data")
	_fields["enclosure_loss"].tooltip_text = tr("The power loss the enclosure takes as its maker gives it (W): the protocol's balance against the losses inside, not needed for the calculation")
	for key: String in _fields:
		_fields[key].add_theme_color_override("font_placeholder_color", AppTheme.warning)
		_fields[key].placeholder_text = tr("enter")
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
	_wide_button.text = tr("Whole list over the screen")
	_wide.title = tr("Power lost in +%s") % doc.switchboards[b].name
	_wide.ok_button_text = tr("Close")
	_wide_hint.text = tr("Type each device's loss at its rated current from its maker's data and the cross-section of each group of wires into the fields; an empty field is not given.")
	_loss_hint.text = tr("Type each device's loss at its rated current from its maker's data, and the cross-section of the wires on the nets of each rated current, into the fields: their lengths come from the wiring laid out and the loss as annex H of ČSN EN 61439-1 reckons it at 70 °C. An empty field is not given.")
	_fill()
	_losses.fill(_document, _evaluated["losses"], _board)
	popup_centered_clamped(Vector2i(1260, 680), 0.92)


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
	var value: Variant = number(text)
	if key == "rdf" and value != null and (value <= 0.0 or value > 1.0):
		value = null
	if key == "enclosure_loss" and value != null and value <= 0.0:
		value = null
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


## [param value] typed in the losses table for row [param what] of
## [param name]: a device's loss or maker's type (text), a cross-section,
## the strip terminals' or the further losses (null: not given).
func _loss_typed(what: String, name: String, value: Variant) -> void:
	match what:
		ROW_TYPE:
			var types: Dictionary = _settings.get("types", {})
			if value == null or str(value).strip_edges().is_empty():
				types.erase(name)
			else:
				types[name] = str(value).strip_edges()
			if types.is_empty():
				_settings.erase("types")
			else:
				_settings["types"] = types
		ROW_DEVICE, ROW_WIRES:
			var store: String = "losses" if what == ROW_DEVICE else "sections"
			var given: Dictionary = _settings.get(store, {})
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
	_refresh()


## [param text] as a number (a decimal comma too), null when it is empty or
## not a number or negative.
static func number(text: String) -> Variant:
	var t: String = text.strip_edges().replace(",", ".")
	if t.is_empty() or not t.is_valid_float() or t.to_float() < 0.0:
		return null
	return t.to_float()


## The fields from the settings, then the table and the result.
func _fill() -> void:
	_filling = true
	for key: String in _fields:
		var field: LineEdit = _fields[key]
		field.text = shown(_settings.get(key)) if not field.has_focus() else field.text
	_mounting.select(int(_settings.get("mounting", -1)) + 1)
	_vented.select(0 if not _settings.has("vented") else (2 if _settings["vented"] else 1))
	_partitions.select(int(_settings.get("partitions", -1)) + 1)
	var vented: bool = _settings.get("vented", false)
	for key: String in ["inlet", "outlet"]:
		_fields[key].editable = vented
		_fields[key].placeholder_text = tr("enter") if vented else "—"
	_filling = false
	_refresh()


## The losses beside the fields and the result again (the fields as they
## are).
func _refresh() -> void:
	_evaluated = HeatRise.evaluate(_document, _board, _wires, _settings)
	_losses.show_losses(_evaluated["losses"])
	if _wide.visible:
		_wide_losses.show_losses(_evaluated["losses"])
	_fill_result()


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
static func shown(value: Variant) -> String:
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
