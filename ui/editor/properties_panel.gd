class_name PropertiesPanel
extends PanelContainer
## Edits the design properties of one selected component. Emits the changed
## component data; the editor applies it and reports failures back.

signal changed(component_id: String, data: Dictionary)
## Another type of the same family was chosen (see [method SchematicEditor.change_type]).
signal type_changed(component_id: String, template: Dictionary)
## The Rotate / Mirror buttons were pressed.
signal rotate_requested
signal mirror_requested
signal flip_requested

var _component_id: String = ""
var _data: Dictionary = {}
var _box: VBoxContainer
var _title: Label
var _message: Label
## Caption and field of the property being added.
var _group: VBoxContainer


func _ready() -> void:
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
			_choice(tr("Conductor"), "conductor", Array(DocumentSerializer.CONDUCTORS), ["L / L1", "N", "L2", "L3", tr("+ (DC)"), tr("- (DC)"), "PE"])
		"junction":
			_note(tr("Wire junction"), "MutedLabel")
		"connector":
			_note(tr("The wire continues on another page: it is joined to every page connector with the same label (usually the wire number). Right click it to go there."), "MutedLabel")
		"push_button", "latching_switch", "limit_switch", "contact":
			_choice(tr("Contact"), "contact", ["NO", "NC"], [tr("NO (make)"), tr("NC (break)")])
			_number(tr("Contact number"), "sequence", 1, 9, 1)
			if kind == "contact":
				_check(tr("Delayed (timer contact)"), "delayed")
		"coil":
			_choice(tr("Kind"), "kind", ["contactor", "relay"], [tr("Contactor"), tr("Relay")])
			_swap_coil_terminals(component)
			_milliseconds(tr("Pick-up time (ms)"), "pick_up")
			_milliseconds(tr("Drop-out time (ms)"), "drop_out")
		"timer":
			_choice(tr("Function"), "mode", Array(TimerRelay.MODE_NAMES), _timer_function_titles(_input_name(component as TimerRelay)))
			_all_functions_button(component as TimerRelay)
			if TimerRelay.uses_two_times((component as TimerRelay).mode):
				_number(tr("Time t1 (s)"), "delay", 0.1, 3600.0, 0.1)
				_number(tr("Time t2 (s)"), "delay2", 0.1, 3600.0, 0.1)
			else:
				_number(tr("Time t (s)"), "delay", 0.1, 3600.0, 0.1)
			_check(tr("Control input S (A1-S-A2)"), "control_input")
			_swap_coil_terminals(component)
			_timer_diagram(component as TimerRelay)
			_milliseconds(tr("Pick-up time (ms)"), "pick_up")
			_milliseconds(tr("Drop-out time (ms)"), "drop_out")
		"changeover":
			_number(tr("Contact number"), "sequence", 1, 9, 1)
			_check(tr("Delayed (timer contact)"), "delayed")
		"fuse", "breaker", "main_contacts":
			_choice(tr("Poles"), "poles", [1, 2, 3, 4], ["1", "2", "3", "4"])
		"overload_relay":
			_choice(tr("Poles"), "poles", [0, 3], [tr("None (contacts only)"), tr("3 (heaters in the power circuit)")])
			_number(tr("Trip delay (s)"), "trip_delay", 0.0, 3600.0, 0.5)
		"overload_contact":
			_choice(tr("Contact"), "contact", ["NO", "NC"], [tr("NO 97-98"), tr("NC 95-96")])
		"motor3":
			_check(tr("Draw as terminal box"), "terminal_box")
			if _data.has("connection"):
				_choice(tr("Bridges"), "connection", ["star", "delta"], [tr("Star (Y)"), tr("Delta (Δ)")])
			_number(tr("Run-down time (s)"), "coast_time", 0.0, 3600.0, 0.1)
			_number(tr("DC braking time (s)"), "brake_time", 0.0, 3600.0, 0.1)
	if not (component is Junction):
		_orientation()
	_group = null
	_note(tr("Double-click a marking on the drawing (designation, terminal number, label) to edit it."), "MutedLabel")
	_message = _note("", "MutedLabel")
	_message.add_theme_color_override("font_color", SchematicTheme.FAULT)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Shows the selected wire: its number is edited on the drawing.
func show_wire() -> void:
	show_component(null)
	for child: Node in _box.get_children():
		if child != _title:
			_box.remove_child(child)
			child.queue_free()
	_group = null
	_title.text = tr("Wire")
	_note(tr("Double-click the wire or its number to number it. All wires joined to this one get the same number."), "MutedLabel")


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


func _choice(caption: String, key: String, values: Array, titles: Array) -> void:
	_label(caption)
	var option: OptionButton = OptionButton.new()
	option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for t: String in titles:
		option.add_item(t)
	option.select(values.find(_data.get(key, values[0])))
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


## Rotate and Mirror buttons for the selected part.
func _orientation() -> void:
	_label(tr("Orientation"))
	var row: HBoxContainer = HBoxContainer.new()
	var rotate: Button = Button.new()
	rotate.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rotate.text = tr("Rotate")
	rotate.icon = AppTheme.icon("rotate")
	rotate.tooltip_text = tr("Rotate by 90°") + "  (R)"
	rotate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotate.pressed.connect(func() -> void: rotate_requested.emit())
	row.add_child(rotate)
	var mirror: Button = Button.new()
	mirror.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	mirror.text = tr("Mirror")
	mirror.icon = AppTheme.icon("mirror")
	mirror.tooltip_text = tr("Mirror left-right, across the symbol axis") + "  (F)"
	mirror.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mirror.pressed.connect(func() -> void: mirror_requested.emit())
	row.add_child(mirror)
	var flip: Button = Button.new()
	flip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	flip.text = tr("Flip")
	flip.icon = AppTheme.icon("flip")
	flip.tooltip_text = tr("Mirror top-bottom: the upper and lower terminals swap") + "  (Shift+F)"
	flip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flip.pressed.connect(func() -> void: flip_requested.emit())
	row.add_child(flip)
	_add(row)


## Button swapping the names A1 and A2 of a coil (A2 on top).
func _swap_coil_terminals(coil: CircuitComponent) -> void:
	var names: PackedStringArray = coil.get_terminal_names()
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = tr("Swap A1 and A2")
	button.tooltip_text = tr("A2 on top, A1 below (or back). Double-clicking A1 and typing A2 does the same.")
	button.pressed.connect(func() -> void:
		var swapped: PackedStringArray = names.duplicate()
		swapped[0] = names[1]
		swapped[1] = names[0]
		_emit("terminals", Array(swapped)))
	_add(button)


## Button with a list icon beside the function choice that shows every
## function with its diagram at once.
func _all_functions_button(timer: TimerRelay) -> void:
	var option: Control = _group.get_child(_group.get_child_count() - 1)
	_group.remove_child(option)
	var row: HBoxContainer = HBoxContainer.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(option)
	var button: Button = Button.new()
	button.theme_type_variation = "ToolButton"
	button.icon = AppTheme.icon("list")
	button.tooltip_text = tr("Show all functions with their diagrams")
	button.pressed.connect(func() -> void:
		var popup: TimerFunctionsPopup = TimerFunctionsPopup.new()
		popup.popup_hide.connect(popup.queue_free)
		add_child(popup)
		var names: PackedStringArray = timer.get_terminal_names()
		popup.setup(_timer_function_titles(_input_name(timer)), timer.mode, _input_name(timer))
		popup.function_chosen.connect(func(mode_name: String) -> void: _emit("mode", mode_name))
		popup.popup_centered(popup.size))
	row.add_child(button)
	_group.add_child(row)


func _check(caption: String, key: String) -> void:
	var box: CheckBox = CheckBox.new()
	box.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.text = caption
	box.button_pressed = bool(_data.get(key, false))
	box.toggled.connect(func(on: bool) -> void: _emit(key, on))
	_group = null
	_box.add_child(box)


## Titles of the time relay functions, in [constant TimerRelay.MODE_NAMES] order.
## [param input]: name of the control input (S, TL, ...) written in the titles.
func _timer_function_titles(input: String) -> Array:
	return [
		tr("F2 – On-delay"),
		tr("Off-delay (on power loss)"),
		tr("F1 – Pulse after power on"),
		tr("F3 – Pulse when %s is pressed") % input,
		tr("F4 – On-delay after %s is released") % input,
		tr("F5 – Pulse after %s is released") % input,
		tr("F6 – Impulse relay (no memory)"),
		tr("F7 – Pulse generator"),
		tr("F8 – Shifted pulse"),
		tr("F9 – Test (always on)"),
		tr("F10 – Cycler starting with the pause (t2 off, t1 on)"),
		tr("F11 – Cycler starting with the pulse (t1 on, t2 off)"),
		tr("F12 – On-delay t1 and off-delay t2 with %s") % input,
	]


## Name of the control input of [param timer] ("S" unless renamed).
func _input_name(timer: TimerRelay) -> String:
	var names: PackedStringArray = timer.get_terminal_names()
	return names[2] if names.size() > 2 else "S"


## Timing diagram of the chosen function (Un, S, R).
func _timer_diagram(timer: TimerRelay) -> void:
	_label(tr("Function diagram"))
	var diagram: TimerDiagram = TimerDiagram.new()
	var names: PackedStringArray = timer.get_terminal_names()
	diagram.input_name = names[2] if names.size() > 2 else "S"
	diagram.mode = timer.mode
	_add(diagram)
