class_name BoardDocumentationDialog
extends ConfirmationDialog
## What a switchboard's documentation is given ([BoardDocumentation]): who
## it is made for and by whose system, its type, serial number and the
## enclosure's material, then its interface characteristics numbered as
## ČSN EN 61439-1 lists them. Nothing is filled in: a text or number field
## says "enter" in the warning colour until typed, a choice starts at
## "— choose —". The rated diversity factor and the dimensions are shown as
## the temperature rise calculation has them (given there), the switchboard
## maker as Settings > Switchboard manufacturer… has it. OK gives the data
## back ([signal saved]).

## The data were confirmed (see [method BoardDocumentation.clean]).
signal saved(data: Dictionary)

var _board: Switchboard
var _data: Dictionary = {}
var _filling: bool = false

var _intro: Label
var _maker_title: Label
var _maker: Label
var _header_caption: Label
var _characteristics_caption: Label
## Per field key: its title label, its input (LineEdit, TextEdit,
## OptionButton or a Label for what comes from elsewhere).
var _titles: Dictionary[String, Label] = {}
var _inputs: Dictionary[String, Control] = {}
var _status: Label


func _init() -> void:
	min_size = Vector2i(820, 560)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	_intro = _muted(column)
	var maker_row: HBoxContainer = HBoxContainer.new()
	maker_row.add_theme_constant_override("separation", 8)
	column.add_child(maker_row)
	_maker_title = _plain(maker_row, 300.0)
	_maker = _plain(maker_row, 360.0)
	_maker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_caption = _caption(column)
	var header: GridContainer = _grid(column)
	for f: Dictionary in BoardDocumentation.HEADER:
		_row(header, f, "")
	_characteristics_caption = _caption(column)
	var characteristics: GridContainer = _grid(column)
	for i: int in BoardDocumentation.CHARACTERISTICS.size():
		_row(characteristics, BoardDocumentation.CHARACTERISTICS[i], "%d." % (i + 1))
	_status = _muted(column)
	_status.add_theme_color_override("font_color", AppTheme.warning)
	confirmed.connect(func() -> void: saved.emit(BoardDocumentation.clean(_data)))


## Shows what switchboard [param board] is given.
func open(board: Switchboard) -> void:
	_board = board
	_data = BoardDocumentation.clean(board.documentation)
	title = tr("Documentation of +%s") % board.name
	ok_button_text = tr("OK")
	cancel_button_text = tr("Cancel")
	_intro.text = tr("What the switchboard's interface characteristics, operating instructions and temperature rise protocol say about it beyond the drawing. Nothing is assumed: an empty field is not given.")
	_maker_title.text = tr("Switchboard manufacturer")
	var maker: String = InterfaceReport.maker_text().replace("\n", ", ")
	_maker.text = maker if not maker.is_empty() else tr("not given: Settings > Switchboard manufacturer…")
	_maker.add_theme_color_override("font_color", AppTheme.warning if maker.is_empty() else AppTheme.text)
	_header_caption.text = tr("Switchboard").to_upper()
	_characteristics_caption.text = tr("Interface characteristics (ČSN EN 61439-1)").to_upper()
	var choose: String = tr("— choose —")
	for f: Dictionary in BoardDocumentation.fields():
		_titles[f["key"]].text = tr(f["title"])
		var input: Control = _inputs[f["key"]]
		if input is OptionButton:
			var option: OptionButton = input
			option.clear()
			option.add_item(choose)
			for text: String in f["options"]:
				option.add_item(tr(text))
		elif input is LineEdit:
			(input as LineEdit).placeholder_text = tr("enter")
		elif input is TextEdit:
			(input as TextEdit).placeholder_text = tr("enter")
	(_inputs["assembly"] as OptionButton).tooltip_text = tr("DBO: a distribution board operated by ordinary persons (ČSN EN 61439-3); PSC: power switchgear and controlgear (ČSN EN 61439-2)")
	_fill()
	popup_centered_clamped(Vector2i(900, 720), 0.9)


## The data being edited.
func data() -> Dictionary:
	return _data


func _fill() -> void:
	_filling = true
	for f: Dictionary in BoardDocumentation.fields():
		var input: Control = _inputs[f["key"]]
		var value: Variant = _data.get(f["key"])
		match f["kind"]:
			"text":
				var text: String = str(value) if value != null else ""
				if input is LineEdit and not input.has_focus():
					(input as LineEdit).text = text
				elif input is TextEdit and not input.has_focus():
					(input as TextEdit).text = text
			"number":
				if not input.has_focus():
					(input as LineEdit).text = HeatRiseDialog.shown(value)
			"choice":
				(input as OptionButton).select((f["options"] as Array).find(value) + 1 if value != null else 0)
			"heat":
				var shown: String = BoardDocumentation.shown(_board, f["key"])
				var label: Label = input
				label.text = shown if not shown.is_empty() else tr("give it in Temperature rise…")
				label.add_theme_color_override("font_color", AppTheme.text if not shown.is_empty() else AppTheme.warning)
	_filling = false
	_refresh()


## What is still to give and what does not fit together.
func _refresh() -> void:
	var probe: Switchboard = Switchboard.new()
	probe.heat = _board.heat
	probe.documentation = _data
	var lines: PackedStringArray = PackedStringArray()
	var gaps: int = BoardDocumentation.missing(probe).size()
	if gaps > 0:
		lines.append(tr_n("%d value still to give", "%d values still to give", gaps) % gaps)
	for note: String in BoardDocumentation.conflicts(_data):
		lines.append(tr(note))
	_status.text = "\n".join(lines)


## [param value] given for field [param key] (null or "": not given).
func _put(key: String, value: Variant) -> void:
	if _filling:
		return
	if value == null or (value is String and (value as String).strip_edges().is_empty()):
		_data.erase(key)
	else:
		_data[key] = value
	_refresh()


## A row of field [param f]: [param number], its title, its input, its unit.
func _row(grid: GridContainer, f: Dictionary, number: String) -> void:
	var count: Label = _plain(grid, 28.0)
	count.text = number
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var title: Label = _plain(grid, 360.0)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titles[f["key"]] = title
	var key: String = f["key"]
	var input: Control
	match f["kind"]:
		"text":
			if f.get("long", false):
				var area: TextEdit = TextEdit.new()
				area.custom_minimum_size = Vector2(300, 70)
				area.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
				area.add_theme_color_override("font_placeholder_color", AppTheme.warning)
				area.text_changed.connect(func() -> void: _put(key, area.text))
				input = area
			else:
				var line: LineEdit = LineEdit.new()
				line.add_theme_color_override("font_placeholder_color", AppTheme.warning)
				line.text_changed.connect(func(text: String) -> void: _put(key, text))
				input = line
		"number":
			var field: LineEdit = LineEdit.new()
			field.alignment = HORIZONTAL_ALIGNMENT_RIGHT
			field.select_all_on_focus = true
			field.add_theme_color_override("font_placeholder_color", AppTheme.warning)
			field.text_changed.connect(func(text: String) -> void:
				var value: Variant = HeatRiseDialog.number(text)
				_put(key, value if value != null and value > 0.0 else null))
			input = field
		"choice":
			var option: OptionButton = OptionButton.new()
			option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			option.fit_to_longest_item = false
			option.clip_text = true
			var options: Array = f["options"]
			option.item_selected.connect(func(index: int) -> void: _put(key, options[index - 1] if index > 0 else null))
			input = option
		_:
			var label: Label = Label.new()
			label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			input = label
	input.custom_minimum_size.x = maxf(input.custom_minimum_size.x, 300.0)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(input)
	_inputs[key] = input
	var unit: Label = _plain(grid, 34.0)
	unit.theme_type_variation = "MutedLabel"
	unit.text = f.get("unit", "")


func _grid(column: VBoxContainer) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	return grid


func _caption(column: VBoxContainer) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.theme_type_variation = "HeaderLabel"
	column.add_child(label)
	return label


func _muted(column: VBoxContainer) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.theme_type_variation = "MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 760.0
	column.add_child(label)
	return label


func _plain(parent: Control, width: float) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.custom_minimum_size.x = width
	parent.add_child(label)
	return label
