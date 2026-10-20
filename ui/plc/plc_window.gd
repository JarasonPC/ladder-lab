class_name PlcWindow
extends Window
## The program of one PLC in a window of its own: the function block diagram
## (FBD) or the ladder diagram (LAD), switched at the top (the PLC runs the
## one shown), a palette of blocks or contacts and coils on the left, the
## selected element's operand, time or preset on the right.
##
## In Edit mode the program is edited on a copy; every finished change goes
## to the schematic through [signal program_edited] (undoable there). The
## Simulation button tests the program on its own, as in the programming
## software: a switch for each input I1-I8, a lamp for each output Q1-Q4
## (and those of the expansion modules), the
## time running; the diagram shows the signals while nothing can be edited.
## While the schematic is simulated it shows the running PLC (online view):
## the signals that are 1, the power flow, running times and counts.

## The program was changed: [param program] is its new data (see
## [method PlcProgram.to_data]).
signal program_edited(component_id: String, program: Dictionary)
signal undo_requested
signal redo_requested
## A key this window does not use (the main window's shortcuts).
signal key_pressed(event: InputEventKey)

## Wide enough for a whole row of the ladder diagram beside the palette and
## the side panel.
const SIZE: Vector2 = Vector2(1260, 720)
const PALETTE_WIDTH: float = 210.0
const SIDE_WIDTH: float = 250.0

## The PLC shown (in the edited schematic or in the simulation).
var component_id: String
var plc: Plc = null
var monitoring: bool = false

var _program: PlcProgram = null
## The program of the PLC shown, as last bound ([method _normalised]): an
## edit leaving the program like this changes nothing.
var _bound_data: Dictionary = {}
## Saving the program to a file of its own and reading one back.
var _export_button: Button
var _import_button: Button
var _file_dialog: FileDialog
var _error: AcceptDialog
var _fbd: PlcFbdCanvas
var _lad: PlcLadCanvas
var _fbd_scroll: ScrollContainer
var _lad_scroll: ScrollContainer
var _language_buttons: Array[Button] = []
var _mode_label: Label
var _palette: VBoxContainer
var _palette_group: ButtonGroup
var _tool_buttons: Dictionary[String, Button] = {}
var _side: VBoxContainer
var _live: Label = null
var _status: Label
## Testing the program on its own: a PLC of its own running a copy of the
## program, the input switches, the output lamps, the time.
var _sim_plc: Plc = null
var _sim_time: float = 0.0
var _sim_button: Button
var _io_bar: PanelContainer
var _io: HFlowContainer
var _input_switches: Array[Button] = []
var _output_lamps: Array[Panel] = []
## Test simulation: the volts set on each analog input, the volts shown of
## each analog output.
var _analog_inputs: Array[SpinBox] = []
var _analog_outputs: Array[Label] = []
## Test simulation: a switch for each network input NI the program reads
## from a partner (no partner answers here), and their operands.
var _network_switches: Array[Button] = []
var _network_operands: PackedStringArray = PackedStringArray()
## Operand read there chosen for a network input before its partner's
## address was given (kept until it is).
var _pending_remotes: Dictionary[String, String] = {}
var _sim_clock: Label


func _init(p_component_id: String) -> void:
	component_id = p_component_id
	visible = false
	# A window of its own on the desktop (dialogs and popups are drawn inside
	# the window they belong to).
	force_native = true
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	min_size = Vector2i(640, 400)
	wrap_controls = false


func _ready() -> void:
	size = Vector2i(SIZE * content_scale_factor)
	_build()
	close_requested.connect(queue_free)
	_show()
	show()


## Shows [param p_plc]: editable when [param simulating] is false, else its
## running state.
func bind(p_plc: Plc, simulating: bool) -> void:
	_bound_data = _normalised(p_plc.program)
	var same: bool = _program != null and not simulating and not monitoring and _bound_data == _normalised(_program)
	var same_io: bool = plc != null and _io_layout(plc) == _io_layout(p_plc)
	plc = p_plc
	monitoring = simulating
	if same and same_io:
		# This window's own change came back from the schematic, or something
		# else of the PLC changed: the program and what is being edited stay,
		# the names of its operands come from the new PLC.
		if is_node_ready():
			_fbd.address = plc.address
			_lad.address = plc.address
			_fbd.queue_redraw()
			_lad.queue_redraw()
		return
	_sim_plc = null
	if not same:
		_program = p_plc.program if simulating else p_plc.program.duplicate_program()
	if is_node_ready():
		_show()


## [param p]'s data as it is edited here (with its ladder diagram, which a
## new program lacks until it is shown), to tell whether two are the same.
static func _normalised(p: PlcProgram) -> Dictionary:
	var copy: PlcProgram = p.duplicate_program()
	copy.ladder()
	return copy.to_data()


## What the window shows of [param p] besides the program: its kind,
## version, inputs and outputs.
static func _io_layout(p: Plc) -> Array:
	return [p.get_script(), p.rating, p.default_terminal_names()]


## The simulation moved on: redraw the signals.
func show_step() -> void:
	if not (monitoring or _sim_plc != null) or not is_node_ready():
		return
	_canvas().queue_redraw()
	if _live != null:
		var info: Dictionary = _canvas().selection_info()
		_live.text = info.get("live", "")


## Shows the texts again in the language now chosen.
func retranslate() -> void:
	if is_node_ready():
		_show()


## State of the running program shown: the simulated PLC's, the one of the
## test simulation, or null while editing.
func _runtime() -> PlcRuntime:
	if monitoring:
		return plc.runtime
	return _sim_plc.runtime if _sim_plc != null else null


func _process(delta: float) -> void:
	if _sim_plc == null:
		return
	_sim_time += delta
	_sim_plc.advance(delta)
	_sim_plc.snap()
	_sim_clock.text = "%.1f s" % _sim_time
	for k: int in _output_lamps.size():
		_light(_output_lamps[k], _sim_plc.output_on(k))
	for k: int in _analog_outputs.size():
		_analog_outputs[k].text = "%s  %.2f V" % [_sim_plc.address("AQ%d" % (k + 1)).trim_prefix("%"), _sim_plc.analog_output_volts(k)]
	show_step()


func _canvas() -> PlcCanvas:
	return _lad if _program != null and _program.language == PlcProgram.Language.LAD else _fbd


# --- Building ----------------------------------------------------------------------

func _build() -> void:
	var root: PanelContainer = PanelContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_stylebox_override("panel", AppTheme.box(AppTheme.bg0, 0, 0.0, 0.0))
	add_child(root)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	root.add_child(column)

	var bar: PanelContainer = PanelContainer.new()
	bar.theme_type_variation = "Toolbar"
	column.add_child(bar)
	var tools: HBoxContainer = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	bar.add_child(tools)
	var track: PanelContainer = PanelContainer.new()
	track.theme_type_variation = "SegmentTrack"
	tools.add_child(track)
	var segments: HBoxContainer = HBoxContainer.new()
	segments.add_theme_constant_override("separation", 2)
	track.add_child(segments)
	var group: ButtonGroup = ButtonGroup.new()
	for language: int in [PlcProgram.Language.FBD, PlcProgram.Language.LAD]:
		var b: Button = Button.new()
		b.theme_type_variation = "SegmentButton"
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_language.bind(language))
		segments.add_child(b)
		_language_buttons.append(b)
	_sim_button = Button.new()
	_sim_button.toggle_mode = true
	_sim_button.focus_mode = Control.FOCUS_NONE
	_sim_button.icon = AppTheme.icon("simulate")
	_sim_button.toggled.connect(_set_test_simulation)
	tools.add_child(_sim_button)
	_mode_label = Label.new()
	_mode_label.theme_type_variation = "MutedLabel"
	_mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(_mode_label)
	_export_button = Button.new()
	_export_button.theme_type_variation = "ToolButton"
	_export_button.focus_mode = Control.FOCUS_NONE
	_export_button.icon = AppTheme.icon("download")
	_export_button.pressed.connect(_ask_file.bind(FileDialog.FILE_MODE_SAVE_FILE))
	tools.add_child(_export_button)
	_import_button = Button.new()
	_import_button.theme_type_variation = "ToolButton"
	_import_button.focus_mode = Control.FOCUS_NONE
	_import_button.pressed.connect(_ask_file.bind(FileDialog.FILE_MODE_OPEN_FILE))
	tools.add_child(_import_button)
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.file_selected.connect(_on_file_chosen)
	add_child(_file_dialog)
	_error = AcceptDialog.new()
	add_child(_error)
	for zoom_in: bool in [false, true]:
		var z: Button = Button.new()
		z.theme_type_variation = "ToolButton"
		z.focus_mode = Control.FOCUS_NONE
		z.icon = AppTheme.icon("zoom_in" if zoom_in else "zoom_out")
		z.tooltip_text = tr("Zoom in") if zoom_in else tr("Zoom out")
		z.pressed.connect(func() -> void: _canvas().zoom *= 1.2 if zoom_in else 1.0 / 1.2)
		tools.add_child(z)

	var middle: HBoxContainer = HBoxContainer.new()
	middle.add_theme_constant_override("separation", 0)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	var left: PanelContainer = PanelContainer.new()
	left.theme_type_variation = "LeftPanel"
	left.custom_minimum_size = Vector2(PALETTE_WIDTH, 0)
	middle.add_child(left)
	var palette_scroll: ScrollContainer = ScrollContainer.new()
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(palette_scroll)
	_palette = VBoxContainer.new()
	_palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette.add_theme_constant_override("separation", 1)
	palette_scroll.add_child(_palette)

	_fbd = PlcFbdCanvas.new()
	_lad = PlcLadCanvas.new()
	_fbd_scroll = _canvas_scroll(_fbd, middle)
	_lad_scroll = _canvas_scroll(_lad, middle)

	var right: PanelContainer = PanelContainer.new()
	right.theme_type_variation = "RightPanel"
	right.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	middle.add_child(right)
	var side_scroll: ScrollContainer = ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(side_scroll)
	_side = VBoxContainer.new()
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.add_theme_constant_override("separation", 12)
	side_scroll.add_child(_side)

	_io_bar = PanelContainer.new()
	_io_bar.theme_type_variation = "BottomPanel"
	_io_bar.visible = false
	column.add_child(_io_bar)
	var io: HBoxContainer = HBoxContainer.new()
	io.add_theme_constant_override("separation", 6)
	_io_bar.add_child(io)
	_io = HFlowContainer.new()
	_io.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_io.add_theme_constant_override("h_separation", 6)
	_io.add_theme_constant_override("v_separation", 6)
	io.add_child(_io)
	_sim_clock = Label.new()
	_sim_clock.theme_type_variation = "TimeLabel"
	io.add_child(_sim_clock)

	var status_bar: PanelContainer = PanelContainer.new()
	status_bar.theme_type_variation = "Statusbar"
	column.add_child(status_bar)
	_status = Label.new()
	_status.theme_type_variation = "MutedLabel"
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_bar.add_child(_status)

	var keys: KeyCatcher = KeyCatcher.new()
	keys.window = self
	add_child(keys)


## A switch for each input and a lamp for each output of the PLC (with its
## expansion modules), made again when their count changed.
func _build_io() -> void:
	var inputs: int = plc.input_count() if plc != null else Plc.BASE_INPUTS
	var outputs: int = plc.output_count() if plc != null else Plc.BASE_OUTPUTS
	var analog_in: int = plc.analog_input_count() if plc != null else 0
	var analog_out: int = plc.analog_output_count() if plc != null else 0
	var network: PackedStringArray = _network_inputs()
	if _input_switches.size() == inputs and _output_lamps.size() == outputs and _analog_inputs.size() == analog_in and _analog_outputs.size() == analog_out and network == _network_operands:
		return
	for child: Node in _io.get_children():
		_io.remove_child(child)
		child.queue_free()
	_input_switches.clear()
	_output_lamps.clear()
	_analog_inputs.clear()
	_analog_outputs.clear()
	_network_switches.clear()
	_network_operands = network
	for k: int in inputs:
		var switch: Button = Button.new()
		switch.toggle_mode = true
		switch.focus_mode = Control.FOCUS_NONE
		switch.text = plc.address("I%d" % (k + 1)).trim_prefix("%") if plc != null else "I%d" % (k + 1)
		switch.custom_minimum_size = Vector2(46, 34)
		switch.toggled.connect(func(_on: bool) -> void: _feed_inputs())
		_io.add_child(switch)
		_input_switches.append(switch)
	_io.add_child(VSeparator.new())
	for k: int in outputs:
		var lamp: Panel = Panel.new()
		lamp.custom_minimum_size = Vector2(46, 34)
		var name: Label = Label.new()
		name.text = plc.address("Q%d" % (k + 1)).trim_prefix("%") if plc != null else "Q%d" % (k + 1)
		name.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lamp.add_child(name)
		_io.add_child(lamp)
		_output_lamps.append(lamp)
		_light(lamp, false)
	if analog_in + analog_out > 0:
		_io.add_child(VSeparator.new())
	for k: int in analog_in:
		var spin: SpinBox = SpinBox.new()
		spin.prefix = plc.address("AI%d" % (k + 1)).trim_prefix("%") if plc != null else "AI%d" % (k + 1)
		spin.suffix = "V"
		spin.min_value = 0.0
		spin.max_value = Plc.ANALOG_VOLTS
		spin.step = 0.1
		spin.custom_minimum_size = Vector2(120, 34)
		spin.tooltip_text = tr("Volts on the analog input (0-10 V = 0-%d)") % roundi(_full_scale())
		spin.value_changed.connect(func(_v: float) -> void: _feed_inputs())
		_io.add_child(spin)
		_analog_inputs.append(spin)
	for k: int in analog_out:
		var label: Label = Label.new()
		label.theme_type_variation = "TimeLabel"
		label.text = "AQ%d  0.00 V" % (k + 1)
		label.custom_minimum_size = Vector2(110, 34)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_io.add_child(label)
		_analog_outputs.append(label)
	if not network.is_empty():
		_io.add_child(VSeparator.new())
	for op: String in network:
		var switch: Button = Button.new()
		switch.toggle_mode = true
		switch.focus_mode = Control.FOCUS_NONE
		switch.text = op
		switch.custom_minimum_size = Vector2(46, 34)
		switch.tooltip_text = tr("Stands for what the partner PLC sends (in the schematic it comes over Ethernet)")
		switch.toggled.connect(func(_on: bool) -> void: _feed_inputs())
		_io.add_child(switch)
		_network_switches.append(switch)


func _canvas_scroll(canvas: PlcCanvas, parent: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var paper: Control = canvas
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(paper)
	canvas.changed.connect(_on_canvas_changed)
	canvas.selection_changed.connect(_build_side)
	canvas.tool_finished.connect(func() -> void: _set_tool(""))
	return scroll


## Everything shown again for [member _program] and [member monitoring].
func _show() -> void:
	if _program == null:
		return
	var lad: bool = _program.language == PlcProgram.Language.LAD
	_language_buttons[0].text = tr("Function block diagram (FBD)")
	_language_buttons[1].text = tr("Ladder diagram (LAD)")
	_language_buttons[1 if lad else 0].set_pressed_no_signal(true)
	_language_buttons[0 if lad else 1].set_pressed_no_signal(false)
	for b: Button in _language_buttons:
		b.disabled = monitoring
		b.tooltip_text = tr("The PLC runs the program shown here.")
	_fbd_scroll.visible = not lad
	_lad_scroll.visible = lad
	var testing: bool = _sim_plc != null
	for b: Button in _language_buttons:
		b.disabled = monitoring or testing
	_export_button.text = tr("Export…")
	_export_button.tooltip_text = tr("Saves the program to a file of its own, to use it in another PLC")
	_import_button.text = tr("Import…")
	_import_button.tooltip_text = tr("Replaces the program with one saved to a file (Ctrl+Z brings it back)")
	_import_button.disabled = monitoring or testing
	if plc != null:
		_fbd.address = plc.address
		_lad.address = plc.address
	_fbd.full_scale = _full_scale()
	_lad.full_scale = _full_scale()
	_fbd.show_program(_program, _runtime())
	_lad.show_program(_program, _runtime())
	title = tr("%s – PLC program – LadderLab") % component_id
	_sim_button.visible = not monitoring
	_sim_button.set_pressed_no_signal(testing)
	_sim_button.text = tr("Stop simulation") if testing else tr("Simulation")
	_sim_button.tooltip_text = tr("Test the program on its own: switch the inputs and watch the outputs")
	_build_io()
	_io_bar.visible = testing
	if monitoring:
		_mode_label.text = tr("Online: the program running in the simulation (switch to Edit to change it)")
		_mode_label.add_theme_color_override("font_color", AppTheme.success)
	elif testing:
		_mode_label.text = tr("Simulation: switch the inputs below; red is 1, blue is 0")
		_mode_label.add_theme_color_override("font_color", AppTheme.warning)
	else:
		_mode_label.text = tr("Editing the program of %s") % component_id
		_mode_label.remove_theme_color_override("font_color")
	_build_palette()
	_build_side()


func _build_palette() -> void:
	for child: Node in _palette.get_children():
		_palette.remove_child(child)
		child.queue_free()
	_tool_buttons.clear()
	_palette_group = ButtonGroup.new()
	var group: String = "-"
	for entry: Dictionary in _canvas().tools():
		if entry["group"] != group:
			group = entry["group"]
			if not group.is_empty():
				var header: Label = Label.new()
				header.theme_type_variation = "HeaderLabel"
				header.text = tr(group).to_upper()
				header.custom_minimum_size = Vector2(0, 30)
				header.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
				_palette.add_child(header)
		var b: Button = Button.new()
		b.theme_type_variation = "ListButton"
		b.toggle_mode = true
		b.button_group = _palette_group
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s   %s" % [entry["symbol"], tr(entry["title"])]
		# Long titles are cut short (in full in the tooltip), so the palette
		# keeps its width and leaves the room to the diagram.
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = tr(entry["title"])
		b.disabled = (monitoring or _sim_plc != null) and entry["id"] != ""
		b.button_pressed = entry["id"] == _canvas().tool
		var id: String = entry["id"]
		b.pressed.connect(func() -> void: _set_tool(id))
		_palette.add_child(b)
		_tool_buttons[id] = b
	_update_status()


func _set_tool(id: String) -> void:
	_canvas().tool = id
	if _tool_buttons.has(id):
		_tool_buttons[id].set_pressed_no_signal(true)
	_update_status()


func _update_status() -> void:
	var view: String = tr("Middle or right drag (or Space+drag) pans, Ctrl+wheel zooms.")
	if monitoring or _sim_plc != null:
		_status.text = tr("Click an element to see its state.") + " " + view
	elif _canvas() == _fbd:
		if _canvas().tool.is_empty():
			_status.text = tr("Drag an output (right) to an input (left) to connect; drag on empty paper to select several blocks.") + " " + view
		else:
			_status.text = tr("Click to place the block. Esc or a right click ends placing.")
	else:
		if _canvas().tool.is_empty():
			_status.text = tr("Click a place to select it; Delete removes it, Insert puts an empty row above it.") + " " + view
		elif _canvas().tool == "link":
			_status.text = tr("Click a cell to link its right side with the row below (click again to remove the link).")
		elif _canvas().tool == "wire":
			_status.text = tr("Click where the wire starts, then click to add corners; it ends on the rail, an element or another wire, or with a double click. Backspace takes back the last corner, Esc drops the wire.")
		else:
			_status.text = tr("Click a cell to put the element there (coils go to the end of the row). Esc or a right click ends it.")


## The side panel for what the diagram has selected.
func _build_side() -> void:
	for child: Node in _side.get_children():
		_side.remove_child(child)
		child.queue_free()
	_live = null
	var caption: Label = Label.new()
	caption.theme_type_variation = "TitleLabel"
	_side.add_child(caption)
	var info: Dictionary = _canvas().selection_info()
	if info.is_empty():
		caption.text = tr("Properties")
		_note(tr("Select a block or an element to see and set its operand, time or preset.") if _canvas() == _fbd else tr("Select a contact or coil to see and set its operand, time or preset."))
		_note(_io_note())
		return
	caption.text = tr(info["title"]) + ("  " + str(info["label"]) if not str(info.get("label", "")).is_empty() else "")
	var canvas: PlcCanvas = _canvas()
	if info.has("operand"):
		_caption(tr("Operand"))
		var option: OptionButton = OptionButton.new()
		var choices: PackedStringArray = _operand_choices(info["areas"], info["operand"])
		for op: String in choices:
			option.add_item(plc.address(op) if plc != null else op)
		option.select(choices.find(info["operand"]))
		option.disabled = monitoring or _sim_plc != null
		option.item_selected.connect(func(i: int) -> void: canvas.set_property("operand", choices[i]))
		_side.add_child(option)
		if PlcProgram.REMOTE_AREAS.has(PlcProgram.area_of(info["operand"])):
			_network_source(info["operand"])
	if info.has("time"):
		_caption(tr("Time (s)"))
		_side.add_child(_spin(float(info["time"]), 0.0, PlcBlock.MAX_TIME, 0.01, func(v: float) -> void: canvas.set_property("time", v)))
	if info.has("preset"):
		_caption(tr("Preset (count)"))
		_side.add_child(_spin(float(info["preset"]), 1.0, PlcCounter.MAX_VALUE, 1.0, func(v: float) -> void: canvas.set_property("preset", int(v))))
	# An analog output takes no value below 0.
	var lowest_value: float = 0.0 if info.get("areas", "") == "AQ" else -PlcBlock.MAX_ANALOG
	for p: Array in [["gain", tr("Gain"), -PlcBlock.MAX_GAIN, PlcBlock.MAX_GAIN, 0.01], ["offset", tr("Offset"), -PlcBlock.MAX_ANALOG, PlcBlock.MAX_ANALOG, 1.0], ["on", tr("On threshold"), -PlcBlock.MAX_ANALOG, PlcBlock.MAX_ANALOG, 1.0], ["off", tr("Off threshold"), -PlcBlock.MAX_ANALOG, PlcBlock.MAX_ANALOG, 1.0], ["value", tr("Value (0-%d = 0-10 V)") % roundi(_full_scale()), lowest_value, PlcBlock.MAX_ANALOG, 1.0]]:
		if info.has(p[0]):
			var key: String = p[0]
			_caption(p[1])
			_side.add_child(_spin(float(info[key]), p[2], p[3], p[4], func(v: float) -> void: canvas.set_property(key, v)))
	if monitoring or _sim_plc != null:
		_live = Label.new()
		_live.theme_type_variation = "TimeLabel"
		_live.text = info.get("live", "")
		_side.add_child(_live)
	if not str(info.get("help", "")).is_empty():
		# Analog help texts name the program's value for 10 V.
		var help: String = tr(info["help"])
		_note(help % roundi(_full_scale()) if help.contains("%d") else help)
	if not monitoring and _sim_plc == null:
		var delete: Button = Button.new()
		delete.icon = AppTheme.icon("delete")
		delete.text = tr("Delete")
		delete.focus_mode = Control.FOCUS_NONE
		delete.pressed.connect(func() -> void: canvas.delete_selection())
		_side.add_child(delete)
		if info.get("rows", false):
			var rows: HBoxContainer = HBoxContainer.new()
			var insert: Button = Button.new()
			insert.text = tr("Insert row")
			insert.icon = AppTheme.icon("plus")
			insert.tooltip_text = tr("An empty row above this one (Insert)")
			insert.focus_mode = Control.FOCUS_NONE
			insert.pressed.connect(func() -> void: _lad.insert_row())
			rows.add_child(insert)
			var remove: Button = Button.new()
			remove.text = tr("Delete row")
			remove.icon = AppTheme.icon("delete")
			remove.focus_mode = Control.FOCUS_NONE
			remove.pressed.connect(func() -> void: _lad.delete_row())
			rows.add_child(remove)
			_side.add_child(rows)


## Where network input [param operand] reads: the partner's IP address
## (set when Enter is pressed or the field is left) and its operand.
func _network_source(operand: String) -> void:
	var source: Dictionary = _program.network_source(operand)
	var editable: bool = not monitoring and _sim_plc == null
	_caption(tr("Partner PLC (IP address)"))
	var field: LineEdit = LineEdit.new()
	field.text = str(source.get("ip", ""))
	field.placeholder_text = "192.168.0.2"
	field.editable = editable
	_side.add_child(field)
	_caption(tr("Operand read there"))
	var option: OptionButton = OptionButton.new()
	var choices: PackedStringArray = PlcProgram.operands(PlcProgram.REMOTE_AREAS[PlcProgram.area_of(operand)])
	for op: String in choices:
		option.add_item(op)
	option.select(maxi(choices.find(str(source.get("operand", _pending_remotes.get(operand, choices[0])))), 0))
	option.disabled = not editable
	_side.add_child(option)
	var apply: Callable = func() -> void:
		if not is_instance_valid(field):
			return
		var ip: String = field.text.strip_edges()
		if not ip.is_empty() and not PlcProgram.valid_ip(ip):
			field.text = str(_program.network_source(operand).get("ip", ""))
			return
		if ip.is_empty():
			# No partner yet: the operand chosen waits for its address.
			_pending_remotes[operand] = choices[option.selected]
		else:
			_pending_remotes.erase(operand)
		_program.set_network_source(operand, ip, choices[option.selected])
		_on_canvas_changed()
	field.text_submitted.connect(func(_text: String) -> void: apply.call())
	field.focus_exited.connect(apply)
	option.item_selected.connect(func(_i: int) -> void: apply.call())
	if plc != null and str(source.get("ip", "")) == plc.ip_address:
		_note(tr("That is this PLC's own address."))
	_note(tr("Read over Ethernet from the PLC at this address (subnet mask %s; this PLC: %s); 0 while it cannot be reached. Wire the Ethernet ports P1 of the PLCs together, through a network switch for more than two.") % [Plc.SUBNET_MASK, plc.ip_address if plc != null else Plc.DEFAULT_IP])


func _caption(value: String) -> void:
	var label: Label = Label.new()
	label.theme_type_variation = "CaptionLabel"
	label.text = value
	_side.add_child(label)


func _note(value: String) -> void:
	var label: Label = Label.new()
	label.theme_type_variation = "MutedLabel"
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(SIDE_WIDTH - 30.0, 0)
	_side.add_child(label)


func _spin(value: float, low: float, high: float, step: float, on_change: Callable) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	spin.editable = not monitoring and _sim_plc == null
	spin.value_changed.connect(on_change)
	return spin


# --- Changes -----------------------------------------------------------------------

## Starts ([param on]) or stops testing the program on its own.
func _set_test_simulation(on: bool) -> void:
	if on and not monitoring:
		_sim_plc = plc.duplicate_plc(_program.duplicate_program()) if plc != null else Plc.new(component_id, _program.duplicate_program())
		_sim_time = 0.0
		_canvas().tool = ""
		_sim_plc.update(true, _input_states(), _sim_plc.all_modules(), _analog_volts(), _network_states())
		_sim_plc.snap()
	else:
		_sim_plc = null
		for switch: Button in _input_switches + _network_switches:
			switch.set_pressed_no_signal(false)
		for spin: SpinBox in _analog_inputs:
			spin.set_value_no_signal(0.0)
	_show()


## Operands of [param areas] to choose from: the inputs and outputs the PLC
## has (with its expansion modules), the others all; [param current] stays
## among them.
func _operand_choices(areas: String, current: String) -> PackedStringArray:
	var inputs: int = plc.input_count() if plc != null else Plc.BASE_INPUTS
	var outputs: int = plc.output_count() if plc != null else Plc.BASE_OUTPUTS
	var choices: PackedStringArray = PackedStringArray()
	for op: String in PlcProgram.operands(areas):
		var n: int = PlcProgram.operand_index(op)
		var limits: Dictionary[String, int] = {"I": inputs, "Q": outputs, "AI": plc.analog_input_count() if plc != null else 0, "AQ": plc.analog_output_count() if plc != null else 0}
		var fitted: bool = n < limits.get(PlcProgram.area_of(op), PlcProgram.AREA_SIZES.get(PlcProgram.area_of(op), 0))
		if fitted or op == current:
			choices.append(op)
	return choices


## What the inputs and outputs of the PLC are, for the hint in the side panel.
func _io_note() -> String:
	if plc is CompactPlc:
		return tr("24 V DC on L+ and M. Inputs are on with 24 V against their common 1M (from 15 V on), the analog inputs AI0 AI1 read 0-10 V against 2M as 0-27648, the transistor outputs switch the output supply 3L+ to their terminal. The program writes them by address: %I0.0, %Q0.0, %IW64.")
	var note: String = tr("Inputs I1-I8 are on with voltage against N. Each output Q1-Q4 is a relay contact between its two terminals.")
	if plc != null and plc.input_count() > Plc.BASE_INPUTS:
		note += " " + tr("Expansion modules: inputs I9-I%d and outputs Q5-Q%d, each module working while its own L1-N has voltage; its inputs are on with voltage against its own N.") % [plc.input_count(), plc.output_count()]
	if plc != null and plc.analog_input_count() + plc.analog_output_count() > 0:
		note += " " + tr("Analog inputs read 0-10 V as 0-1000 (the 12/24 V and 24 V versions: I7, I8, I1, I2 as AI1-AI4); analog outputs put 0-1000 out as 0-10 V. Analog modules need 24 V DC on L+ and M.")
	return note


## 1 for each input that is on: its switch is, or (an input that is also an
## analog input) the volts set on it reach the input's threshold.
func _input_states() -> PackedByteArray:
	var states: PackedByteArray = PackedByteArray()
	for switch: Button in _input_switches:
		states.append(1 if switch.button_pressed else 0)
	if _sim_plc != null:
		var threshold: float = VoltageRating.input_threshold(_sim_plc.rating)
		for k: int in _analog_inputs.size():
			var digital: int = _sim_plc.analog_input_digital(k)
			if digital >= 0 and digital < states.size() and _analog_inputs[k].value >= threshold:
				states[digital] = 1
	return states


## The network inputs NI the program reads from a partner, in order.
func _network_inputs() -> PackedStringArray:
	var list: PackedStringArray = PackedStringArray()
	if _program == null:
		return list
	var used: Dictionary[String, Dictionary] = _program.used_network()
	for op: String in PlcProgram.operands("NI"):
		if used.has(op):
			list.append(op)
	return list


## NI values of the test simulation: 1 for each switched on.
func _network_states() -> PackedByteArray:
	var states: PackedByteArray = PackedByteArray()
	if _network_switches.is_empty():
		return states
	states.resize(PlcProgram.AREA_SIZES["NI"])
	for k: int in _network_switches.size():
		if _network_switches[k].button_pressed:
			states[PlcProgram.operand_index(_network_operands[k])] = 1
	return states


## The program's value for 10 V on the PLC shown.
func _full_scale() -> float:
	return plc.full_scale() if plc != null else PlcBlock.ANALOG_MAX


## Volts set on the analog inputs of the test simulation.
func _analog_volts() -> PackedFloat32Array:
	var volts: PackedFloat32Array = PackedFloat32Array()
	for spin: SpinBox in _analog_inputs:
		volts.append(spin.value)
	return volts


func _feed_inputs() -> void:
	if _sim_plc != null:
		_sim_plc.update(true, _input_states(), _sim_plc.all_modules(), _analog_volts(), _network_states())
		_sim_plc.snap()
		show_step()


## Paints an output lamp of the test simulation lit or dark.
func _light(lamp: Panel, on: bool) -> void:
	lamp.add_theme_stylebox_override("panel", AppTheme.box(Color("ffb000") if on else AppTheme.bg2, 6, 0.0, 0.0, AppTheme.border, 1))
	(lamp.get_child(0) as Label).add_theme_color_override("font_color", Color("1d1f22") if on else AppTheme.text_muted)


## Asks where to save the program ([param mode] save) or which program file
## to read (open).
func _ask_file(mode: FileDialog.FileMode) -> void:
	_file_dialog.file_mode = mode
	_file_dialog.title = tr("Export PLC program") if mode == FileDialog.FILE_MODE_SAVE_FILE else tr("Import PLC program")
	_file_dialog.filters = PackedStringArray(["*.%s ; %s" % [ProjectFile.PLC_EXTENSION, tr("PLC program")]])
	if mode == FileDialog.FILE_MODE_SAVE_FILE:
		_file_dialog.current_file = "%s.%s" % [component_id.get_slice(":", 0) if not component_id.is_empty() else "plc", ProjectFile.PLC_EXTENSION]
	_file_dialog.popup_centered_ratio(0.6)


func _on_file_chosen(path: String) -> void:
	if _file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		if path.get_extension().to_lower() != ProjectFile.PLC_EXTENSION:
			path += "." + ProjectFile.PLC_EXTENSION
		if ProjectFile.save_plc_program(_program, path) != OK:
			_show_error(tr("Could not save %s.") % path.get_file())
		return
	import_program(path)


## Replaces the program with the one in file [param path] (one undoable
## edit). Returns false when the file is not a PLC program.
func import_program(path: String) -> bool:
	if monitoring or _sim_plc != null:
		return false
	var result: Dictionary = ProjectFile.load_plc_program(path)
	if result.has("error"):
		_show_error(tr(result["error"]) % path.get_file())
		return false
	_program = result["program"]
	_show()
	_on_canvas_changed()
	return true


func _show_error(text: String) -> void:
	_error.dialog_text = text
	_error.popup_centered()


func _on_language(language: int) -> void:
	if monitoring or _program.language == language:
		return
	_program.language = language as PlcProgram.Language
	_show()
	_on_canvas_changed()


func _on_canvas_changed() -> void:
	if monitoring or _sim_plc != null:
		return
	_canvas().update_size()
	if _normalised(_program) == _bound_data:
		# A wire dropped on paper, a wire drawn over one ...: no undo step.
		return
	program_edited.emit(component_id, _program.to_data())


## Takes the keys the diagrams leave: undo and redo, the rest goes to the
## main window, releases too (a push button held by its key lets go). Space
## stays here: held, it lets a left drag move the diagram.
class KeyCatcher:
	extends Node

	var window: PlcWindow

	func _unhandled_input(event: InputEvent) -> void:
		var key: InputEventKey = event as InputEventKey
		if key == null or key.echo or key.keycode == KEY_SPACE:
			return
		var ctrl: bool = key.ctrl_pressed or key.meta_pressed
		if key.pressed and ctrl and key.keycode == KEY_Z and not key.shift_pressed:
			window.undo_requested.emit()
		elif key.pressed and ctrl and (key.keycode == KEY_Y or (key.keycode == KEY_Z and key.shift_pressed)):
			window.redo_requested.emit()
		else:
			window.key_pressed.emit(key)
		get_viewport().set_input_as_handled()
