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
## software: a switch for each input I1-I8, a lamp for each output Q1-Q4, the
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

const SIZE: Vector2 = Vector2(1180, 720)
const SIDE_WIDTH: float = 250.0

## The PLC shown (in the edited schematic or in the simulation).
var component_id: String
var plc: Plc = null
var monitoring: bool = false

var _program: PlcProgram = null
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
var _input_switches: Array[Button] = []
var _output_lamps: Array[Panel] = []
var _sim_clock: Label


func _init(p_component_id: String) -> void:
	component_id = p_component_id
	visible = false
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
	var same: bool = _program != null and not simulating and not monitoring and p_plc.program.to_data() == _program.to_data()
	plc = p_plc
	monitoring = simulating
	if same:
		# This window's own change came back from the schematic.
		return
	_sim_plc = null
	_program = p_plc.program if simulating else p_plc.program.duplicate_program()
	if is_node_ready():
		_show()


## The simulation moved on: redraw the signals.
func show_step() -> void:
	if not (monitoring or _sim_plc != null) or not is_node_ready():
		return
	_canvas().queue_redraw()
	if _live != null:
		var info: Dictionary = _canvas().selection_info()
		_live.text = info.get("live", "")


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
	for k: int in Plc.OUTPUTS:
		_light(_output_lamps[k], _sim_plc.output_on(k))
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
	left.custom_minimum_size = Vector2(190, 0)
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
	for k: int in Plc.INPUTS:
		var switch: Button = Button.new()
		switch.toggle_mode = true
		switch.focus_mode = Control.FOCUS_NONE
		switch.text = "I%d" % (k + 1)
		switch.custom_minimum_size = Vector2(46, 34)
		switch.toggled.connect(func(_on: bool) -> void: _feed_inputs())
		io.add_child(switch)
		_input_switches.append(switch)
	io.add_child(VSeparator.new())
	for k: int in Plc.OUTPUTS:
		var lamp: Panel = Panel.new()
		lamp.custom_minimum_size = Vector2(46, 34)
		var name: Label = Label.new()
		name.text = "Q%d" % (k + 1)
		name.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lamp.add_child(name)
		io.add_child(lamp)
		_output_lamps.append(lamp)
		_light(lamp, false)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	io.add_child(spacer)
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
	_fbd.show_program(_program, _runtime())
	_lad.show_program(_program, _runtime())
	title = tr("%s – PLC program – LadderLab") % component_id
	_sim_button.visible = not monitoring
	_sim_button.set_pressed_no_signal(testing)
	_sim_button.text = tr("Stop simulation") if testing else tr("Simulation")
	_sim_button.tooltip_text = tr("Test the program on its own: switch the inputs and watch the outputs")
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
		_note(tr("Inputs I1-I8 are on with voltage against N. Each output Q1-Q4 is a relay contact between its two terminals."))
		return
	caption.text = tr(info["title"]) + ("  " + str(info["label"]) if not str(info.get("label", "")).is_empty() else "")
	var canvas: PlcCanvas = _canvas()
	if info.has("operand"):
		_caption(tr("Operand"))
		var option: OptionButton = OptionButton.new()
		var choices: PackedStringArray = PlcProgram.operands(info["areas"])
		for op: String in choices:
			option.add_item(op)
		option.select(choices.find(info["operand"]))
		option.disabled = monitoring or _sim_plc != null
		option.item_selected.connect(func(i: int) -> void: canvas.set_property("operand", choices[i]))
		_side.add_child(option)
	if info.has("time"):
		_caption(tr("Time (s)"))
		_side.add_child(_spin(float(info["time"]), 0.0, 3600.0, 0.01, func(v: float) -> void: canvas.set_property("time", v)))
	if info.has("preset"):
		_caption(tr("Preset (count)"))
		_side.add_child(_spin(float(info["preset"]), 1.0, 9999.0, 1.0, func(v: float) -> void: canvas.set_property("preset", int(v))))
	if monitoring:
		_live = Label.new()
		_live.theme_type_variation = "TimeLabel"
		_live.text = info.get("live", "")
		_side.add_child(_live)
	if not str(info.get("help", "")).is_empty():
		_note(tr(info["help"]))
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
		_sim_plc = Plc.new(component_id, _program.duplicate_program())
		_sim_time = 0.0
		_canvas().tool = ""
		_sim_plc.update(true, _input_bits())
		_sim_plc.snap()
	else:
		_sim_plc = null
		for switch: Button in _input_switches:
			switch.set_pressed_no_signal(false)
	_show()


## Bits of the input switches that are on.
func _input_bits() -> int:
	var bits: int = 0
	for k: int in _input_switches.size():
		if _input_switches[k].button_pressed:
			bits |= 1 << k
	return bits


func _feed_inputs() -> void:
	if _sim_plc != null:
		_sim_plc.update(true, _input_bits())
		_sim_plc.snap()
		show_step()


## Paints an output lamp of the test simulation lit or dark.
func _light(lamp: Panel, on: bool) -> void:
	lamp.add_theme_stylebox_override("panel", AppTheme.box(Color("ffb000") if on else AppTheme.bg2, 6, 0.0, 0.0, AppTheme.border, 1))
	(lamp.get_child(0) as Label).add_theme_color_override("font_color", Color("1d1f22") if on else AppTheme.text_muted)


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
	program_edited.emit(component_id, _program.to_data())


## Takes the keys the diagrams leave: undo and redo, the rest goes to the
## main window.
class KeyCatcher:
	extends Node

	var window: PlcWindow

	func _unhandled_input(event: InputEvent) -> void:
		var key: InputEventKey = event as InputEventKey
		if key == null or not key.pressed or key.echo:
			return
		var ctrl: bool = key.ctrl_pressed or key.meta_pressed
		if ctrl and key.keycode == KEY_Z and not key.shift_pressed:
			window.undo_requested.emit()
		elif ctrl and (key.keycode == KEY_Y or (key.keycode == KEY_Z and key.shift_pressed)):
			window.redo_requested.emit()
		else:
			window.key_pressed.emit(key)
		get_viewport().set_input_as_handled()
