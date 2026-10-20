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
## The program of the PLC should be shown.
signal plc_requested(component_id: String)
## The datasheet of the shown part was asked for.
signal datasheet_requested(component_id: String)

var _component_id: String = ""
## The part shown (fields are built anew from it after a refused edit).
var _component: CircuitComponent = null
var _data: Dictionary = {}
var _box: VBoxContainer
var _title: Label
var _message: Label
## Caption and field of the property being added.
var _group: VBoxContainer
## Caption and field of each property shown, by its key (a lesson points at them).
var _fields: Dictionary[String, Control] = {}


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
	_fields.clear()
	_component = component
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
			if (component as PowerSupply).conductor == PowerSupply.Conductor.DC_PLUS:
				var titles: Array = []
				for v: float in PowerSupply.DC_VOLTAGES:
					titles.append(tr("10 V (reference)") if is_equal_approx(v, 10.0) else "%d V" % roundi(v))
				_choice(tr("Voltage against -"), "voltage", Array(PowerSupply.DC_VOLTAGES), titles)
			elif (component as PowerSupply).conductor != PowerSupply.Conductor.DC_MINUS:
				_note(tr("230 V between a phase and N, 400 V between two phases."), "MutedLabel")
		"junction":
			_note(tr("Wire junction"), "MutedLabel")
		"connector":
			_note(tr("The wire continues on another page: it is joined to every page connector with the same label (usually the wire number). Right click it to go there."), "MutedLabel")
		"push_button", "latching_switch", "limit_switch", "contact":
			_choice(tr("Contact"), "contact", ["NO", "NC"], [tr("NO (make)"), tr("NC (break)")])
			_number(tr("Contact number"), "sequence", 1, 9, 1)
			if kind == "latching_switch":
				_choice(tr("Positions"), "positions", ["0-I", "I-0-II"], [tr("0-I (off / on)"), tr("I-0-II (e.g. manual / off / auto)")])
				if _data.get("positions", "0-I") == "I-0-II":
					_choice(tr("Operated in position"), "operated_in", ["I", "II"], ["I", "II"])
			if kind == "contact":
				_check(tr("Delayed (timer contact)"), "delayed")
		"coil":
			_choice(tr("Kind"), "kind", ["contactor", "relay"], [tr("Contactor"), tr("Relay")])
			_swap_coil_terminals(component)
			_milliseconds(tr("Pick-up time (ms)"), "pick_up")
			_milliseconds(tr("Drop-out time (ms)"), "drop_out")
		"timer":
			_choice(tr("Function"), "mode", Array(TimerRelay.MODE_NAMES), TimerFunctionsPopup.function_titles(_input_name(component as TimerRelay)))
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
		"plc":
			_plc_program(component as Plc)
		"vfd":
			_choice(tr("Run and stop"), "control", Array(Vfd.CONTROL_NAMES), [tr("Terminals (DI1 run, DI2 reverse)"), tr("Keypad (I / O)")])
			_choice(tr("Setpoint"), "setpoint", Array(Vfd.SETPOINT_NAMES), [tr("Analog input AI1 (0-10 V)"), tr("Keypad")])
			_number(tr("Maximum frequency (Hz)"), "max_frequency", 1.0, Vfd.HIGHEST_FREQUENCY, 1.0)
			_number(tr("Ramp-up time (s)"), "ramp_up", 0.0, Vfd.LONGEST_RAMP, 0.1)
			_number(tr("Ramp-down time (s)"), "ramp_down", 0.0, Vfd.LONGEST_RAMP, 0.1)
			# Up to the maximum frequency, which the drive does not exceed.
			_number(tr("Fixed frequency, DI3 (Hz)"), "fixed_frequency", 0.0, float(_data["max_frequency"]), 0.5)
			_number(tr("Keypad setpoint (Hz)"), "keypad_frequency", 0.0, float(_data["max_frequency"]), 0.5)
			_group = null
			_note(tr("Supply 3 x 400 V on L1 L2 L3, the motor on U V W. DI1 runs, DI2 reverses, DI3 runs at the fixed frequency, DI4 stops the output at once (coast stop); the inputs are on with 24 V against DIC, from its own 24V-0V. AI1 takes 0-10 V (from its 10V reference, a PLC or a sensor) for 0 to the maximum frequency. DO2 closes while the motor runs. While simulating, click it for its keypad."), "MutedLabel")
		"temp_sensor":
			# Each bound stays a degree off the other one.
			_number(tr("Range from (°C)"), "range_min", TemperatureSensor.LOWEST, float(_data["range_max"]) - 1.0, 1.0)
			_number(tr("Range to (°C)"), "range_max", float(_data["range_min"]) + 1.0, TemperatureSensor.HIGHEST, 1.0)
			_number(tr("Temperature at the start (°C)"), "temperature", TemperatureSensor.LOWEST, TemperatureSensor.HIGHEST, 0.5)
			_group = null
			_note(tr("Supply 24 V DC on L+ and M; puts 0-10 V on U against M over its range. While simulating, click it to set the temperature."), "MutedLabel")
		"transmitter":
			var quantity: int = maxi(Transmitter.QUANTITY_NAMES.find(str(_data.get("quantity", ""))), 0)
			var unit: String = Transmitter.UNITS[quantity]
			_transmitter_quantity()
			# Each bound stays a step off the other one.
			var step: float = DocumentSerializer.TRANSMITTER_RANGE_STEP
			_number(tr("Range from (%s)") % unit, "range_min", Transmitter.LOWEST, float(_data["range_max"]) - step, step)
			_number(tr("Range to (%s)") % unit, "range_max", float(_data["range_min"]) + step, Transmitter.HIGHEST, step)
			_number(tr("Value at the start (%s)") % unit, "value", Transmitter.LOWEST, Transmitter.HIGHEST, step)
			_group = null
			_note(tr("Three wires as on its M12 plug: 1 (BN) +24 V DC, 3 (BU) 0 V, 2 (WH) the output, 0-10 V against 3 over its range. While simulating, click it to set the value."), "MutedLabel")
		"pot":
			var titles: Array = []
			for turns: int in Potentiometer.TURNS:
				titles.append(tr("1 turn (knob, 0-10 scale)") if turns == 1 else tr("%d turns (counting dial)") % turns)
			_choice(tr("Turns"), "turns", Array(Potentiometer.TURNS), titles)
			_number(tr("Set at the start (%)"), "setting", 0.0, 100.0, 0.1)
			_group = null
			_note(tr("A setpoint for an analog input: 1 on 0 V, 3 on a 10 V reference (a frequency inverter's 10V, an analog output) and the wiper 2 on the input gives 0-10 V. Mounted on a control station or a switchboard's door; while simulating, turn it there with the mouse wheel or by dragging, or click it in the schematic."), "MutedLabel")
		"proximity":
			_choice(tr("Sensing"), "sensing", Array(ProximitySensor.SENSING_NAMES), [tr("Inductive (metal)"), tr("Capacitive (any material)"), tr("Optical (diffuse light)"), tr("Magnetic (cylinder sensor)")])
			_choice(tr("Output"), "output", Array(ProximitySensor.OUTPUT_NAMES), [tr("PNP (switches +24 V to the output)"), tr("NPN (switches 0 V to the output)")])
			_choice(tr("Function"), "function", Array(ProximitySensor.FUNCTION_NAMES), [tr("NO (on while it detects)"), tr("NC (on while it detects nothing)"), tr("NO + NC (4 wires, antivalent)")])
			_group = null
			_note(tr("Wires as ČSN EN 60947-5-2 colours them: 1 (BN) +24 V DC, 3 (BU) 0 V, 4 (BK) the output, 2 (WH) the second output of the 4-wire version. A PNP output goes to a PLC input whose common is on 0 V, an NPN output to one whose common is on +24 V. While simulating, click it to put something in front of it or take it away; in a group with a mechanical link the moving part works it."), "MutedLabel")
		"network_switch":
			_note(tr("Supply 24 V DC on L+ and M. While it has its supply it joins the Ethernet cables plugged into its ports P1-P4 into one network, so more than two PLCs can talk to one another; a port lights up while it has a link."), "MutedLabel")
		"cam_switch":
			_choice(tr("Poles"), "poles", [1, 2, 3, 4], ["1", "2", "3", "4"])
			_choice(tr("Positions"), "positions", Array(CamSwitch.POSITION_NAMES), [tr("0-I (off / on)"), tr("I-0-II (forward / off / reverse)")])
			_group = null
			_note(tr("0-I: each pole closes 1-2, 3-4 ... in position I. I-0-II: each pole joins its common 2, 4 ... to 1, 3 ... in I and to 1', 3' ... in II. While simulating, a click turns it on to the next position (0, I, 0, II)."), "MutedLabel")
		"light_switch":
			var titles: Array = []
			for circuit: String in LightSwitch.CIRCUITS:
				titles.append(light_switch_title(circuit))
			_choice(tr("Switch number (řazení)"), "circuit", Array(LightSwitch.CIRCUITS), titles)
			_height(LightSwitch.STANDARD_HEIGHT)
			_group = null
			_note(tr("Wired as Czech installations number switches, the common marked P: 1 switches P to 1; 2 and 3 switch two or three poles; 5 has two rockers on one P, to 1 and to 2; 5A a one-way rocker to 1 and a two-way rocker to 2 or 3; 5B two two-way rockers, to 1 or 2 and to 3 or 4; 6 (staircase) switches P over from 1 to 2; 7 (intermediate) joins 1-3 and 2-4, switched over 1-4 and 2-3. While simulating, click the rocker to switch it over."), "MutedLabel")
		"luminaire":
			_number(tr("Rated power (W)"), "power", Luminaire.MIN_POWER, Luminaire.MAX_POWER, 1.0)
			_height(Luminaire.STANDARD_HEIGHT)
			_group = null
			_note(tr("230 V between L and N; PE goes to its frame. It lights while it has its voltage."), "MutedLabel")
		"socket":
			_choice(tr("Outlets"), "gangs", [1, 2], [tr("Single"), tr("Double")])
			_height(SocketOutlet.STANDARD_HEIGHT)
			_group = null
			_note(tr("Czech type E socket 16 A / 250 V with the protective pin: L, N and PE. While simulating it shows 230 V while it has its voltage."), "MutedLabel")
		"changeover":
			_number(tr("Contact number"), "sequence", 1, 9, 1)
			_check(tr("Delayed (timer contact)"), "delayed")
		"fuse", "breaker", "main_contacts":
			_choice(tr("Poles"), "poles", [1, 2, 3, 4], ["1", "2", "3", "4"])
			if kind == "breaker":
				_choice(tr("Characteristic"), "characteristic", ["B", "C", "D"], [tr("B (magnetic release 3-5x In)"), tr("C (magnetic release 5-10x In)"), tr("D (magnetic release 10-20x In)")])
			if kind == "breaker":
				_breaker_rating()
			elif kind == "fuse":
				_number(tr("Rated current In (A)"), "rated_current", DocumentSerializer.MIN_AMPERES, DocumentSerializer.MAX_AMPERES, 0.1)
			if kind != "main_contacts":
				_trip_curve(TripCurve.Kind.FUSE_GG if kind == "fuse" else CircuitBreaker.breaker_curve(TripCurve.LETTERS.find(_data["characteristic"]) as CircuitBreaker.Characteristic))
		"overload_relay":
			_choice(tr("Poles"), "poles", [0, 3], [tr("None (contacts only)"), tr("3 (heaters in the power circuit)")])
			if (component as OverloadRelay).poles == 3:
				_number(tr("Current setting Ir (A)"), "setting", DocumentSerializer.MIN_AMPERES, DocumentSerializer.MAX_AMPERES, 0.1)
				_trip_curve(TripCurve.Kind.OVERLOAD)
			else:
				_number(tr("Trip delay (s)"), "trip_delay", 0.0, 3600.0, 0.5)
		"overload_contact":
			_choice(tr("Contact"), "contact", ["NO", "NC"], [tr("NO 97-98"), tr("NC 95-96")])
		"motor3":
			_check(tr("Draw as terminal box"), "terminal_box")
			if _data.has("connection"):
				_choice(tr("Bridges"), "connection", ["star", "delta"], [tr("Star (Y)"), tr("Delta (Δ)")])
			_check(tr("Show rating plate"), "show_plate")
			_number(tr("Rated power (kW)"), "rated_power", 0.01, 10000.0, 0.01)
			_number(tr("Rated current In (A)"), "rated_current", DocumentSerializer.MIN_AMPERES, DocumentSerializer.MAX_AMPERES, 0.1)
			_number(tr("Rated speed (min⁻¹)"), "rated_speed", 100.0, 2990.0, 5.0)
			_number(tr("Power factor cos φ"), "power_factor", 0.3, 0.97, 0.01)
			_number(tr("Starting current Ia / In"), "start_ratio", DocumentSerializer.MIN_START_RATIO, DocumentSerializer.MAX_START_RATIO, 0.1)
			_number(tr("Load (% of rated torque)"), "load", 0.0, DocumentSerializer.MAX_LOAD, 5.0)
			_note(tr("Rated torque %s N·m. The load needs a quarter of it at standstill, the rest grows with the square of the speed (fan, pump).") % String.num(snappedf((component as ThreePhaseMotor).rated_torque(), 0.1)), "MutedLabel")
			_number(tr("Run-up time (s)"), "run_up_time", 0.0, 600.0, 0.1)
			_number(tr("Run-down time (s)"), "coast_time", 0.0, 3600.0, 0.1)
			_number(tr("DC braking time (s)"), "brake_time", 0.0, 3600.0, 0.1)
	if not VoltageRating.offered(kind).is_empty() and not (component is CompactPlc):
		_rating(component)
	if not (component is Junction):
		_orientation()
		_datasheet_button()
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


## Shows why the last change was refused; the fields show the part as it
## stayed, not the refused value.
func show_error(text: String) -> void:
	if not text.is_empty() and _component != null and is_instance_valid(_component):
		show_component(_component)
	if _message != null:
		_message.text = text


## Global rectangle of the caption and field of property [param key] while
## part [param component_id] is shown, else an empty one.
func field_rect(component_id: String, key: String) -> Rect2:
	var field: Control = _fields.get(key, null)
	if component_id != _component_id or field == null or not is_instance_valid(field) or not field.is_visible_in_tree():
		return Rect2()
	return field.get_global_rect()


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


func _choice(caption: String, key: String, values: Array, titles: Array) -> OptionButton:
	_label(caption)
	var option: OptionButton = OptionButton.new()
	option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for t: String in titles:
		option.add_item(t)
	option.select(values.find(_data.get(key, values[0])))
	option.item_selected.connect(func(i: int) -> void: _emit(key, values[i]))
	_add(option)
	_fields[key] = _group
	return option


func _number(caption: String, key: String, min_value: float, max_value: float, step: float) -> void:
	_label(caption)
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = _data[key]
	spin.value_changed.connect(func(value: float) -> void: _emit(key, value))
	_add(spin)
	_fields[key] = _group


## What a transmitter measures; another quantity starts with its own range
## and value.
func _transmitter_quantity() -> void:
	var option: OptionButton = _choice(tr("Measures"), "quantity", Array(Transmitter.QUANTITY_NAMES), [tr("Pressure (bar)"), tr("Level (m)"), tr("Flow (m³/h)")])
	for connection: Dictionary in option.item_selected.get_connections():
		option.item_selected.disconnect(connection["callable"])
	option.item_selected.connect(func(i: int) -> void:
		var data: Dictionary = _data.duplicate()
		data["quantity"] = Transmitter.QUANTITY_NAMES[i]
		data["range_min"] = Transmitter.DEFAULT_MIN[i]
		data["range_max"] = Transmitter.DEFAULT_MAX[i]
		data["value"] = Transmitter.DEFAULT_VALUE[i]
		changed.emit(_component_id, data))


## Rated current of a breaker, one of the [constant CircuitBreaker.STANDARD_RATINGS]
## (a value from an older file that is not among them stays in the list).
func _breaker_rating() -> void:
	var values: Array = []
	values.assign(CircuitBreaker.STANDARD_RATINGS)
	var current: float = float(_data["rated_current"])
	var known: bool = false
	for v: float in values:
		known = known or is_equal_approx(v, current)
	if not known:
		values.append(current)
		values.sort()
	var titles: Array = []
	for v: float in values:
		titles.append(Fuse.amperes_text(v) + " A")
	_label(tr("Rated current In (A)"))
	var option: OptionButton = OptionButton.new()
	option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for t: String in titles:
		option.add_item(t)
	for i: int in values.size():
		if is_equal_approx(values[i], current):
			option.select(i)
	option.item_selected.connect(func(i: int) -> void: _emit("rated_current", values[i]))
	_add(option)


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


## Button opening the datasheet of the part.
func _datasheet_button() -> void:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = tr("Datasheet")
	button.icon = AppTheme.icon("datasheet")
	button.tooltip_text = tr("Terminals, technical data and device front of this part") + "  (F1)"
	var id: String = _component_id
	button.pressed.connect(func() -> void: datasheet_requested.emit(id))
	_group = null
	_add(button)


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
		popup.setup(TimerFunctionsPopup.function_titles(_input_name(timer)), timer.mode, _input_name(timer))
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


## Name of the control input of [param timer] ("S" unless renamed).
func _input_name(timer: TimerRelay) -> String:
	var names: PackedStringArray = timer.get_terminal_names()
	return names[2] if names.size() > 2 else "S"


## Rated voltage of a coil, time relay, lamp or PLC: below it the part does
## not work, far above it burns out.
func _rating(component: CircuitComponent) -> void:
	var kind: String = _data["type"]
	var values: Array = Array(VoltageRating.offered(kind))
	var titles: Array = []
	for name: String in values:
		titles.append(VoltageRating.text(name))
	if str(_data.get("rating", "")).is_empty():
		values.push_front("")
		titles.push_front(tr("Not set (works on any voltage)"))
	var option: OptionButton = _choice(tr("PLC version (supply and inputs)") if kind == "plc" else tr("Rated voltage"), "rating", values, titles)
	if component is Plc:
		# A version whose own analog inputs leave too few for the modules.
		for i: int in values.size():
			option.set_item_disabled(i, not Plc.modules_fit((component as Plc).modules, values[i]))
	_group = null
	_note(tr("Too low a voltage and the part does not work; far too high a voltage (or DC on an AC coil) burns it out while simulating."), "MutedLabel")


## What the PLC runs, with the button that opens its program.
func _plc_program(plc: Plc) -> void:
	_label(tr("Program"))
	var language: String = tr("Ladder diagram (LAD)") if plc.program.language == PlcProgram.Language.LAD else tr("Function block diagram (FBD)")
	var info: Label = Label.new()
	info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	info.text = language
	_add(info)
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.theme_type_variation = "PrimaryButton"
	button.text = tr("Program the PLC…")
	button.tooltip_text = tr("Opens the program in a window of its own (also by double-clicking the PLC)")
	var id: String = plc.id
	button.pressed.connect(func() -> void: plc_requested.emit(id))
	_add(button)
	_ip_address()
	if plc is CompactPlc:
		_choice(tr("CPU"), "cpu", Array(CompactPlc.CPU_NAMES), [tr("6 inputs, 4 outputs, 2 analog inputs (no signal modules)"), tr("8 inputs, 6 outputs, 2 analog inputs (2 signal modules)"), tr("14 inputs, 10 outputs, 2 analog inputs (8 signal modules)")])
	_plc_modules(plc)
	_group = null
	if plc is CompactPlc:
		_note(tr("24 V DC on L+ and M. Inputs are on with 24 V against their common 1M (from 15 V on), the analog inputs AI0 AI1 read 0-10 V against 2M as 0-27648, the transistor outputs switch the output supply 3L+ to their terminal. The program writes them by address: %I0.0, %Q0.0, %IW64."), "MutedLabel")
		return
	var note: String = tr("Inputs I1-I8 are on with voltage against N. Each output Q1-Q4 is a relay contact between its two terminals.")
	if plc.input_count() > Plc.BASE_INPUTS:
		note += " " + tr("Expansion modules: inputs I9-I%d and outputs Q5-Q%d, each module working while its own L1-N has voltage; its inputs are on with voltage against its own N.") % [plc.input_count(), plc.output_count()]
	if plc.analog_input_count() + plc.analog_output_count() > 0:
		note += " " + tr("Analog inputs read 0-10 V as 0-1000 (the 12/24 V and 24 V versions: I7, I8, I1, I2 as AI1-AI4); analog outputs put 0-1000 out as 0-10 V. Analog modules need 24 V DC on L+ and M.")
	_note(note, "MutedLabel")


## IP address of a PLC's Ethernet port, set when Enter is pressed or the
## field is left (an address that is not one stays as it was).
func _ip_address() -> void:
	_label(tr("IP address (Ethernet port P1)"))
	var field: LineEdit = LineEdit.new()
	field.text = str(_data.get("ip", Plc.DEFAULT_IP))
	field.placeholder_text = Plc.DEFAULT_IP
	field.tooltip_text = tr("Subnet mask %s: PLCs talk to one another when the first three numbers of their addresses are the same and no two have the same address.") % Plc.SUBNET_MASK
	var apply: Callable = func() -> void:
		var ip: String = field.text.strip_edges()
		if not PlcProgram.valid_ip(ip):
			field.text = str(_data.get("ip", Plc.DEFAULT_IP))
		elif ip != str(_data.get("ip", "")):
			_emit("ip", ip)
	field.text_submitted.connect(func(_text: String) -> void: apply.call())
	field.focus_exited.connect(apply)
	_add(field)
	_fields["ip"] = _group


## Expansion modules clipped on to the right of the PLC, as on the real one:
## a module is added after the last one and the last one taken off (the
## inputs and outputs of the others keep their numbers).
func _plc_modules(plc: Plc) -> void:
	var compact: bool = plc is CompactPlc
	if compact and CompactPlc.CPU_MODULES[(plc as CompactPlc).cpu] == 0:
		return
	_label(tr("Signal modules") if compact else tr("Expansion modules"))
	if plc.modules.is_empty():
		var none: Label = Label.new()
		none.theme_type_variation = "MutedLabel"
		none.text = tr("None") if compact else tr("None: inputs I1-I8, outputs Q1-Q4")
		_add(none)
	for m: int in plc.modules.size():
		var row: Label = Label.new()
		row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.text = "%d: %s (%s)" % [m + 2, _module_title(plc.modules[m]), ", ".join(_module_operands(plc, m))]
		_add(row)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	var add: MenuButton = MenuButton.new()
	add.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add.flat = false
	add.text = tr("Add module")
	add.tooltip_text = tr("Clips one more module on to the right (as many as the CPU takes)") if compact else tr("Clips one more module on to the right (up to 24 inputs and 20 outputs in all)")
	var popup: PopupMenu = add.get_popup()
	popup.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for kind: int in Plc.MODULE_NAMES.size():
		if Plc.is_signal_module(kind as Plc.Module) != compact:
			continue
		var longer: Array[Plc.Module] = plc.modules.duplicate()
		longer.append(kind as Plc.Module)
		popup.add_item(_module_title(kind as Plc.Module), kind)
		var fits: bool = CompactPlc.modules_fit_cpu(longer, (plc as CompactPlc).cpu) if compact else Plc.modules_fit(longer, plc.rating)
		popup.set_item_disabled(popup.get_item_count() - 1, not fits)
	popup.id_pressed.connect(func(kind: int) -> void:
		var list: Array[Plc.Module] = plc.modules.duplicate()
		list.append(kind as Plc.Module)
		_emit_modules(list))
	buttons.add_child(add)
	var remove: Button = Button.new()
	remove.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	remove.text = tr("Remove last")
	remove.tooltip_text = tr("Takes off the module on the far right; wires on its terminals go with it")
	remove.disabled = plc.modules.is_empty()
	remove.pressed.connect(func() -> void:
		var list: Array[Plc.Module] = plc.modules.duplicate()
		list.pop_back()
		_emit_modules(list))
	buttons.add_child(remove)
	_add(buttons)


func _module_title(module: Plc.Module) -> String:
	match module:
		Plc.Module.DI4_DQ4:
			return tr("4 inputs, 4 relay outputs")
		Plc.Module.DI8_DQ8:
			return tr("8 inputs, 8 relay outputs")
		Plc.Module.AI2:
			return tr("2 analog inputs 0-10 V")
		Plc.Module.SM_DI8:
			return tr("8 inputs 24 V DC")
		Plc.Module.SM_DQ8:
			return tr("8 transistor outputs 24 V DC")
		Plc.Module.SM_DI8_DQ8:
			return tr("8 inputs, 8 transistor outputs 24 V DC")
		Plc.Module.SM_AI4:
			return tr("4 analog inputs 0-10 V")
	return tr("2 analog outputs 0-10 V")


## Ranges of the operands of module [param m]: "I9-I12", "Q5-Q8", "AI5-AI6".
static func _module_operands(plc: Plc, m: int) -> PackedStringArray:
	var found: Dictionary[String, PackedInt32Array] = {"I": PackedInt32Array(), "Q": PackedInt32Array(), "AI": PackedInt32Array(), "AQ": PackedInt32Array()}
	for k: int in plc.input_count():
		if plc.input_module(k) == m:
			found["I"].append(k + 1)
	for k: int in plc.output_count():
		if plc.output_module(k) == m:
			found["Q"].append(k + 1)
	for k: int in plc.analog_input_count():
		if plc.analog_input_module(k) == m:
			found["AI"].append(k + 1)
	for k: int in plc.analog_output_count():
		if plc.analog_output_module(k) == m:
			found["AQ"].append(k + 1)
	var ranges: PackedStringArray = PackedStringArray()
	for area: String in found:
		var numbers: PackedInt32Array = found[area]
		if not numbers.is_empty():
			var first: String = "%s%d" % [area, numbers[0]]
			var last: String = "%s%d" % [area, numbers[numbers.size() - 1]]
			ranges.append("%s-%s" % [plc.address(first), plc.address(last)])
	return ranges


## Emits the PLC with expansion modules [param list]; terminal names given
## by hand stay on the terminals that are left
## ([method SchematicEditor.adapt_terminals]).
func _emit_modules(list: Array[Plc.Module]) -> void:
	var names: Array[String] = []
	for module: Plc.Module in list:
		names.append(Plc.MODULE_NAMES[module])
	_emit("modules", names)


## Mounting height over the floor of a part of a house installation, with
## the standard height it starts with.
func _height(standard: float) -> void:
	_number(tr("Mounting height (m)"), "height", 0.0, DocumentSerializer.MAX_HEIGHT, 0.05)
	_group = null
	_note(tr("Standard: %s m. A height other than the standard one is written beside the part.") % String.num(standard, 2).pad_decimals(2), "MutedLabel")


## Name of light switch number [param circuit] (řazení) as offered.
static func light_switch_title(circuit: String) -> String:
	match circuit:
		"2":
			return TranslationServer.translate("2 - two-pole")
		"3":
			return TranslationServer.translate("3 - three-pole")
		"5":
			return TranslationServer.translate("5 - series (two rockers)")
		"5A":
			return TranslationServer.translate("5A - one-way and two-way")
		"5B":
			return TranslationServer.translate("5B - double two-way")
		"6":
			return TranslationServer.translate("6 - two-way (staircase)")
		"7":
			return TranslationServer.translate("7 - intermediate")
	return TranslationServer.translate("1 - one-way")


## Time-current characteristic of a protective device.
func _trip_curve(curve: TripCurve.Kind) -> void:
	_label(tr("Time-current characteristic"))
	var diagram: TripCurveDiagram = TripCurveDiagram.new()
	diagram.kind = curve
	_add(diagram)


## Timing diagram of the chosen function (Un, S, R).
func _timer_diagram(timer: TimerRelay) -> void:
	_label(tr("Function diagram"))
	var diagram: TimerDiagram = TimerDiagram.new()
	var names: PackedStringArray = timer.get_terminal_names()
	diagram.input_name = names[2] if names.size() > 2 else "S"
	diagram.mode = timer.mode
	_add(diagram)
