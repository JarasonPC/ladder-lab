class_name PropertiesPanel
extends PanelContainer
## Edits the design properties of one selected component. Emits the changed
## component data; the editor applies it and reports failures back.

signal changed(component_id: String, data: Dictionary)

var _component_id: String = ""
var _data: Dictionary = {}
var _box: VBoxContainer
var _title: Label
var _message: Label


func _ready() -> void:
	custom_minimum_size = Vector2(220, 0)
	_box = VBoxContainer.new()
	add_child(_box)
	show_component(null)


## Shows the fields of [param component], or a hint when null.
func show_component(component: CircuitComponent) -> void:
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_title = _label(tr("Properties"))
	_title.add_theme_font_size_override("font_size", 16)
	if component == null:
		_component_id = ""
		_label(tr("Select one component to edit it."))
		return
	_component_id = component.id
	_data = DocumentSerializer.component_to_dict(component)
	var kind: String = _data["type"]
	match kind:
		"supply":
			_choice(tr("Conductor"), "conductor", ["L", "N"], ["L", "N"])
		"junction":
			_label(tr("Wire junction"))
		"push_button", "latching_switch", "contact":
			_text(tr("Designation"), "designation")
			_choice(tr("Contact"), "contact", ["NO", "NC"], [tr("NO (make)"), tr("NC (break)")])
			_number(tr("Contact number"), "sequence", 1, 9, 1)
			if kind == "contact":
				_check(tr("Delayed (timer contact)"), "delayed")
		"coil":
			_text(tr("Designation"), "designation")
			_choice(tr("Kind"), "kind", ["contactor", "relay"], [tr("Contactor"), tr("Relay")])
		"timer":
			_text(tr("Designation"), "designation")
			_choice(tr("Function"), "mode", ["on_delay", "off_delay"], [tr("On-delay"), tr("Off-delay")])
			_number(tr("Delay (s)"), "delay", 0.1, 3600.0, 0.1)
		"lamp", "motor":
			_text(tr("Designation"), "designation")
	_label(tr("Terminals: %s") % ", ".join(component.get_terminal_names()))
	_message = _label("")
	_message.add_theme_color_override("font_color", SchematicTheme.FAULT)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Shows why the last change was refused.
func show_error(text: String) -> void:
	if _message != null:
		_message.text = text


func _label(text: String) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(label)
	return label


func _emit(key: String, value: Variant) -> void:
	var data: Dictionary = _data.duplicate()
	data[key] = value
	changed.emit(_component_id, data)


func _text(caption: String, key: String) -> void:
	_label(caption)
	var edit: LineEdit = LineEdit.new()
	edit.text = _data[key]
	edit.text_submitted.connect(func(value: String) -> void: _emit(key, value.strip_edges()))
	edit.focus_exited.connect(func() -> void:
		if edit.text.strip_edges() != _data[key]:
			_emit(key, edit.text.strip_edges()))
	_box.add_child(edit)


func _choice(caption: String, key: String, values: Array, titles: Array) -> void:
	_label(caption)
	var option: OptionButton = OptionButton.new()
	option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for t: String in titles:
		option.add_item(t)
	option.select(values.find(_data[key]))
	option.item_selected.connect(func(i: int) -> void: _emit(key, values[i]))
	_box.add_child(option)


func _number(caption: String, key: String, min_value: float, max_value: float, step: float) -> void:
	_label(caption)
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = _data[key]
	spin.value_changed.connect(func(value: float) -> void: _emit(key, value))
	_box.add_child(spin)


func _check(caption: String, key: String) -> void:
	var box: CheckBox = CheckBox.new()
	box.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.text = caption
	box.button_pressed = _data[key]
	box.toggled.connect(func(on: bool) -> void: _emit(key, on))
	_box.add_child(box)
