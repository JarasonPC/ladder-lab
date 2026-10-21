class_name CablePanel
extends MarginContainer
## The cores of one cable of the workspace, opened from it: a list with a row
## per core, its wire number and what it lands on at each end (a strip
## terminal "X2:3", a device terminal "SB1:13"); the PE core last, marked PE.
## Above it the cable's name and type, and what can be set on it in Edit mode
## (its type name, cross-section and length) with the voltage drop over its
## length ([method WorkspaceCables.voltage_drop]).

## A change of the document (undoable), made by [param change].
signal edit_requested(change: Callable)

## Key of the cable shown ("+RA1|+ST1", see [method WorkspaceCables.cables]).
var cable_key: String = ""
var _document: SchematicDocument
var _editing: bool = false
var _note: Label
var _type: LineEdit
var _section: OptionButton
var _length: SpinBox
var _drop: Label
var _list: Tree


func _ready() -> void:
	for side: String in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 16)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_note = Label.new()
	_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_note.theme_type_variation = "MutedLabel"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)
	var fields: HFlowContainer = HFlowContainer.new()
	fields.add_theme_constant_override("h_separation", 16)
	column.add_child(fields)
	_type = LineEdit.new()
	_type.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_type.custom_minimum_size.x = 180.0
	_type.max_length = 40
	_type.text_submitted.connect(func(_text: String) -> void: _apply())
	_type.focus_exited.connect(_apply)
	_section = OptionButton.new()
	_section.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_section.item_selected.connect(func(_index: int) -> void: _apply())
	_length = SpinBox.new()
	_length.min_value = 0.0
	_length.max_value = WorkspaceCables.MAX_LENGTH
	_length.step = 0.1
	_length.suffix = "m"
	_length.custom_minimum_size.x = 120.0
	_length.value_changed.connect(func(_value: float) -> void: _apply())
	for field: Array in [["type", _type], ["section", _section], ["length", _length]]:
		var pair: HBoxContainer = HBoxContainer.new()
		var caption: Label = Label.new()
		caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		caption.set_meta("caption", field[0])
		pair.add_child(caption)
		pair.add_child(field[1])
		fields.add_child(pair)
	_drop = Label.new()
	_drop.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_drop.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_drop)
	_list = Tree.new()
	_list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.hide_root = true
	_list.columns = 4
	_list.column_titles_visible = true
	_list.select_mode = Tree.SELECT_ROW
	column.add_child(_list)
	_rebuild()


func set_document(doc: SchematicDocument, editing: bool) -> void:
	_document = doc
	_editing = editing
	_rebuild()


func refresh() -> void:
	_rebuild()


func retranslate() -> void:
	_rebuild()


## The cable shown, {} when the document has no such cable.
func cable() -> Dictionary:
	if _document == null:
		return {}
	for found: Dictionary in WorkspaceCables.cables(_document):
		if found["key"] == cable_key:
			return found
	return {}


func _rebuild() -> void:
	if _list == null:
		return
	_list.clear()
	var shown: Dictionary = cable()
	if shown.is_empty():
		_note.text = ""
		return
	var cores: Array = shown["cores"]
	_fill_fields(shown)
	_note.text = "%s %s.  " % [shown["name"], WorkspaceCables.type_text(shown)] + tr_n("%d core between %s and %s, worked out from the wiring of the schematic.", "%d cores between %s and %s, worked out from the wiring of the schematic.", cores.size()) % [cores.size(), shown["a"], shown["b"]]
	_list.set_column_title(0, tr("Core"))
	_list.set_column_title(1, tr("Wire number"))
	_list.set_column_title(2, str(shown["a"]))
	_list.set_column_title(3, str(shown["b"]))
	for c: int in 4:
		_list.set_column_title_alignment(c, HORIZONTAL_ALIGNMENT_LEFT)
		_list.set_column_expand(c, c >= 2)
		_list.set_column_custom_minimum_width(c, 90 if c < 2 else 160)
	var root: TreeItem = _list.create_item()
	var n: int = 0
	for core: Dictionary in cores:
		var row: TreeItem = _list.create_item(root)
		var pe: bool = core["conductor"] == CabinetDevices.Conductor.PE
		if not pe:
			n += 1
		row.set_text(0, "PE" if pe else str(n))
		if pe:
			row.set_custom_color(0, SchematicTheme.PE)
		row.set_text(1, str(core["number"]))
		# Nothing to land on (a net through a switchboard without a strip terminal): a dash.
		row.set_text(2, ", ".join(core["a"]) if not (core["a"] as PackedStringArray).is_empty() else "–")
		row.set_text(3, ", ".join(core["b"]) if not (core["b"] as PackedStringArray).is_empty() else "–")


## The fields with what is set on cable [param shown], and its voltage drop.
func _fill_fields(shown: Dictionary) -> void:
	for pair: Node in _type.get_parent().get_parent().get_children():
		var caption: Label = pair.get_child(0) as Label
		match str(caption.get_meta("caption")):
			"type":
				caption.text = tr("Type")
			"section":
				caption.text = tr("Cross-section")
			"length":
				caption.text = tr("Length")
	var by_use: Dictionary = shown.duplicate()
	by_use["type"] = ""
	_type.placeholder_text = WorkspaceCables.type_name(by_use)
	if not _type.has_focus():
		_type.text = str(shown["type"])
	_section.clear()
	_section.add_item(tr("By the current (%s mm²)") % WorkspaceCables.section_text(float(shown["auto_section"])))
	var given: float = float(_document.cable_settings.get(cable_key, {}).get("section", 0.0))
	_section.select(0)
	for choice: float in WorkspaceCables.CHOICES:
		_section.add_item("%s mm²" % WorkspaceCables.section_text(choice))
		if is_equal_approx(choice, given):
			_section.select(_section.item_count - 1)
	_length.set_value_no_signal(float(shown["length"]))
	for field: Control in [_type, _section, _length]:
		field.set("editable" if field != _section else "disabled", _editing if field != _section else not _editing)
	var drop: Dictionary = WorkspaceCables.voltage_drop(_document, shown)
	_drop.remove_theme_color_override("font_color")
	if float(shown["length"]) <= 0.0:
		_drop.text = tr("Give the cable's length to work out its voltage drop.")
	elif drop.is_empty():
		_drop.text = tr("Voltage drop: no load current to reckon with.")
	else:
		_drop.text = tr("Voltage drop %s V (%s %% of %d V) at %s A.") % [_number(drop["volts"]), _number(drop["percent"]), roundi(drop["of"]), _number(drop["amps"])]
		if float(drop["percent"]) > WorkspaceCables.DROP_LIMIT:
			_drop.text += " " + tr("More than the %s %% usually kept to: a larger cross-section is needed.") % _number(WorkspaceCables.DROP_LIMIT)
			_drop.add_theme_color_override("font_color", AppTheme.warning)


## A number written with at most two decimals and a decimal comma where the
## language has one.
func _number(value: float) -> String:
	var text: String = String.num(snappedf(value, 0.01)).trim_suffix(".0")
	return text.replace(".", ",") if TranslationServer.get_locale().begins_with("cs") else text


## Sends what the fields say as a change of the cable (when it changed).
func _apply() -> void:
	if not _editing or _document == null:
		return
	var key: String = cable_key
	var type: String = _type.text
	var section: float = 0.0 if _section.selected <= 0 else WorkspaceCables.CHOICES[_section.selected - 1]
	var length: float = _length.value
	if WorkspaceCables.settings(type, section, length) == _document.cable_settings.get(key, {}):
		return
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.set_cable(key, type, section, length))
