class_name PropertiesPanel
extends PanelContainer
## Edits the design properties of one selected component. Emits the changed
## component data; the editor applies it and reports failures back.

signal changed(component_id: String, data: Dictionary)
## Another type of the same family was chosen (see [method SchematicEditor.change_type]).
signal type_changed(component_id: String, template: Dictionary)

var _component_id: String = ""
var _data: Dictionary = {}
var _box: VBoxContainer
var _title: Label
var _message: Label
## Caption and field of the property being added.
var _group: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(250, 0)
	theme_type_variation = "RightPanel"
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	add_child(_box)
	show_component(null)


## Shows the fields of [param component], or a hint when null.
func show_component(component: CircuitComponent) -> void:
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_group = null
	_title = _note(tr("Properties"), "TitleLabel")
	if component == null:
		_component_id = ""
		_note(tr("Select one component to edit it."), "MutedLabel")
		return
	_component_id = component.id
	_data = DocumentSerializer.component_to_dict(component)
	var kind: String = _data["type"]
	var options: Array[Dictionary] = SchematicEditor.type_options(component)
	if options.size() > 1:
		_label(tr("Type"))
		var type_select: OptionButton = OptionButton.new()
		type_select.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		for i: int in options.size():
			type_select.add_item(tr(options[i]["title"]))
			if SchematicEditor.matches_template(component, options[i]["template"]):
				type_select.select(i)
		var id: String = component.id
		type_select.item_selected.connect(func(i: int) -> void: type_changed.emit(id, options[i]["template"]))
		_add(type_select)
	match kind:
		"supply":
			_choice(tr("Conductor"), "conductor", ["L", "L2", "L3", "N"], ["L / L1", "L2", "L3", "N"])
		"junction":
			_note(tr("Wire junction"), "MutedLabel")
		"push_button", "latching_switch", "contact":
			_text(tr("Designation"), "designation")
			_choice(tr("Contact"), "contact", ["NO", "NC"], [tr("NO (make)"), tr("NC (break)")])
			_number(tr("Contact number"), "sequence", 1, 9, 1)
			if kind == "contact":
				_check(tr("Delayed (timer contact)"), "delayed")
		"coil":
			_text(tr("Designation"), "designation")
			_choice(tr("Kind"), "kind", ["contactor", "relay"], [tr("Contactor"), tr("Relay")])
			_milliseconds(tr("Pick-up time (ms)"), "pick_up")
			_milliseconds(tr("Drop-out time (ms)"), "drop_out")
		"timer":
			_text(tr("Designation"), "designation")
			_choice(tr("Function"), "mode", ["on_delay", "off_delay"], [tr("On-delay"), tr("Off-delay")])
			_number(tr("Delay (s)"), "delay", 0.1, 3600.0, 0.1)
			_milliseconds(tr("Pick-up time (ms)"), "pick_up")
			_milliseconds(tr("Drop-out time (ms)"), "drop_out")
		"changeover":
			_text(tr("Designation"), "designation")
			_number(tr("Contact number"), "sequence", 1, 9, 1)
			_check(tr("Delayed (timer contact)"), "delayed")
		"fuse", "breaker", "fuse3", "breaker3", "main_contacts", "motor3":
			_text(tr("Designation"), "designation")
		"overload_relay":
			_text(tr("Designation"), "designation")
			_number(tr("Trip delay (s)"), "trip_delay", 0.0, 3600.0, 0.5)
		"overload_contact":
			_text(tr("Designation"), "designation")
			_choice(tr("Contact"), "contact", ["NO", "NC"], [tr("NO 97-98"), tr("NC 95-96")])
		"lamp":
			_text(tr("Designation"), "designation")
			_text(tr("Label above the lamp"), "purpose", tr("e.g. Running, Fault"))
		"motor":
			_text(tr("Designation"), "designation")
	if component.supports_custom_terminals():
		_terminals(component)
	_group = null
	_message = _note("", "MutedLabel")
	_message.add_theme_color_override("font_color", SchematicTheme.FAULT)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Shows why the last change was refused.
func show_error(text: String) -> void:
	if _message != null:
		_message.text = text


## Text on its own line (title, hint, error).
func _note(text: String, variation: String) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.theme_type_variation = variation
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(label)
	return label


## Starts a property: a small caption with its field below.
func _label(text: String) -> Label:
	_group = VBoxContainer.new()
	_group.add_theme_constant_override("separation", 4)
	_box.add_child(_group)
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.theme_type_variation = "CaptionLabel"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_group.add_child(label)
	return label


func _add(control: Control) -> void:
	(_group if _group != null else _box).add_child(control)


func _emit(key: String, value: Variant) -> void:
	var data: Dictionary = _data.duplicate()
	data[key] = value
	changed.emit(_component_id, data)


func _text(caption: String, key: String, placeholder: String = "") -> void:
	_label(caption)
	var edit: LineEdit = LineEdit.new()
	var current: String = str(_data.get(key, ""))
	edit.text = current
	edit.placeholder_text = placeholder
	edit.text_submitted.connect(func(value: String) -> void: _emit(key, value.strip_edges()))
	edit.focus_exited.connect(func() -> void:
		if edit.text.strip_edges() != current:
			_emit(key, edit.text.strip_edges()))
	_add(edit)


func _choice(caption: String, key: String, values: Array, titles: Array) -> void:
	_label(caption)
	var option: OptionButton = OptionButton.new()
	option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for t: String in titles:
		option.add_item(t)
	option.select(values.find(_data[key]))
	option.item_selected.connect(func(i: int) -> void: _emit(key, values[i]))
	_add(option)


func _number(caption: String, key: String, min_value: float, max_value: float, step: float) -> void:
	_label(caption)
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = _data[key]
	spin.value_changed.connect(func(value: float) -> void: _emit(key, value))
	_add(spin)


## A time stored in seconds, edited in milliseconds.
func _milliseconds(caption: String, key: String) -> void:
	_label(caption)
	var spin: SpinBox = SpinBox.new()
	spin.min_value = 0.1
	spin.max_value = 1000.0
	spin.step = 0.1
	spin.value = float(_data[key]) * 1000.0
	spin.value_changed.connect(func(value: float) -> void: _emit(key, value / 1000.0))
	_add(spin)


## Terminal names as "13-14" (or "15-16-18"), editable, plus a button that
## swaps the two terminals of a two-terminal part (A1-A2 -> A2-A1).
func _terminals(component: CircuitComponent) -> void:
	_label(tr("Terminals"))
	var row: HBoxContainer = HBoxContainer.new()
	_add(row)
	var names: PackedStringArray = component.get_terminal_names()
	var edit: LineEdit = LineEdit.new()
	edit.text = "-".join(names)
	edit.tooltip_text = tr("Rename the terminals, e.g. 13-14 to 53-54. Empty restores the standard marking.")
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var submit: Callable = func(text: String) -> void:
		var parts: Array = []
		for p: String in text.split("-"):
			parts.append(p.strip_edges())
		if text.strip_edges().is_empty():
			parts = Array(component.default_terminal_names())
		if PackedStringArray(parts) != names:
			_emit("terminals", parts)
	edit.text_submitted.connect(submit)
	edit.focus_exited.connect(func() -> void: submit.call(edit.text))
	row.add_child(edit)
	if names.size() == 2:
		var swap: Button = Button.new()
		swap.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		swap.text = tr("Swap")
		swap.tooltip_text = tr("Swap the terminal names, e.g. A1-A2 to A2-A1")
		swap.pressed.connect(func() -> void: _emit("terminals", [names[1], names[0]]))
		row.add_child(swap)


func _check(caption: String, key: String) -> void:
	var box: CheckBox = CheckBox.new()
	box.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.text = caption
	box.button_pressed = _data[key]
	box.toggled.connect(func(on: bool) -> void: _emit(key, on))
	_group = null
	_box.add_child(box)
