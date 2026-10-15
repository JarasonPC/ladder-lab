extends Node
## Main window: toolbar, palette, schematic view, properties and status bar.
## Edit mode edits the schematic; Simulate mode runs a copy of it, so the
## simulation never changes the design.
## All user-facing text is English source text passed through tr().

enum Mode { EDIT, SIMULATE }

const SPEEDS: Array[float] = [0.5, 1.0, 2.0, 5.0]
const LOCALES: PackedStringArray = ["en", "cs"]
## Language names are shown in their own language, never translated.
const LOCALE_NAMES: PackedStringArray = ["English", "Čeština"]

var mode: Mode = Mode.EDIT
## The schematic being designed (the simulation runs on a copy).
var edit_doc: SchematicDocument
var view: SchematicView
var camera: SchematicCamera
var editor: SchematicEditor

var _edit_button: Button
var _simulate_button: Button
var _circuit_label: Label
var _circuit_select: OptionButton
var _new_button: Button
var _layout_label: Label
var _layout_select: OptionButton
var _edit_tools: HBoxContainer
var _undo_button: Button
var _redo_button: Button
var _rotate_button: Button
var _mirror_button: Button
var _delete_button: Button
var _sim_tools: HBoxContainer
var _run_button: Button
var _step_button: Button
var _speed_label: Label
var _speed_select: OptionButton
var _reset_button: Button
var _time_label: Label
var _language_select: OptionButton
var _palette: Palette
var _properties: PropertiesPanel
var _status_label: Label
var _hint_label: Label
var _editor_hint: String = ""


func _ready() -> void:
	RenderingServer.set_default_clear_color(SchematicTheme.BACKGROUND)
	view = SchematicView.new()
	add_child(view)
	editor = SchematicEditor.new()
	editor.view = view
	add_child(editor)
	camera = SchematicCamera.new()
	add_child(camera)
	camera.make_current()
	_build_ui()
	view.stepped.connect(_on_stepped)
	editor.document_replaced.connect(_on_document_replaced)
	editor.selection_changed.connect(func(c: CircuitComponent) -> void: _properties.show_component(c))
	editor.hint_changed.connect(_on_editor_hint)
	_properties.changed.connect(_on_properties_changed)
	_palette.template_chosen.connect(func(t: Dictionary) -> void: editor.begin_place(t))
	editor.active = true
	_load_example()


func _process(_delta: float) -> void:
	_undo_button.disabled = not editor.history.can_undo()
	_redo_button.disabled = not editor.history.can_redo()
	var has_selection: bool = not editor.selected_components.is_empty()
	_rotate_button.disabled = not has_selection and editor.tool != SchematicEditor.Tool.PLACE
	_mirror_button.disabled = _rotate_button.disabled
	_delete_button.disabled = not has_selection and editor.selected_wires.is_empty()


# --- UI construction ------------------------------------------------------------

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var top: PanelContainer = PanelContainer.new()
	root.add_child(top)
	# Wraps onto a second row when the window (or a translation) is too narrow.
	var bar: HFlowContainer = HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 6)
	bar.add_theme_constant_override("v_separation", 4)
	top.add_child(bar)

	var mode_group: ButtonGroup = ButtonGroup.new()
	_edit_button = _button(bar, func() -> void: _set_mode(Mode.EDIT))
	_simulate_button = _button(bar, func() -> void: _set_mode(Mode.SIMULATE))
	for b: Button in [_edit_button, _simulate_button]:
		b.toggle_mode = true
		b.button_group = mode_group
	_edit_button.button_pressed = true
	bar.add_child(VSeparator.new())

	_circuit_label = _label(bar)
	_circuit_select = _option(bar)
	_circuit_select.fit_to_longest_item = false
	_circuit_select.clip_text = true
	_circuit_select.custom_minimum_size = Vector2(210, 0)
	for i: int in ExampleCircuits.count():
		_circuit_select.add_item("")
	_circuit_select.item_selected.connect(func(_i: int) -> void: _load_example())
	_new_button = _button(bar, _new_document)
	_layout_label = _label(bar)
	_layout_select = _option(bar)
	_layout_select.add_item("")
	_layout_select.add_item("")
	_layout_select.item_selected.connect(_on_layout_selected)
	bar.add_child(VSeparator.new())

	_edit_tools = HBoxContainer.new()
	bar.add_child(_edit_tools)
	_undo_button = _button(_edit_tools, func() -> void: editor.undo())
	_redo_button = _button(_edit_tools, func() -> void: editor.redo())
	_rotate_button = _button(_edit_tools, func() -> void: editor.rotate_selection())
	_mirror_button = _button(_edit_tools, func() -> void: editor.mirror_selection())
	_delete_button = _button(_edit_tools, func() -> void: editor.delete_selection())

	_sim_tools = HBoxContainer.new()
	bar.add_child(_sim_tools)
	_run_button = _button(_sim_tools, _on_run_pressed)
	_step_button = _button(_sim_tools, func() -> void: view.step_once())
	_speed_label = _label(_sim_tools)
	_speed_select = _option(_sim_tools)
	for s: float in SPEEDS:
		_speed_select.add_item("×%s" % str(s))
	_speed_select.select(SPEEDS.find(1.0))
	_speed_select.item_selected.connect(func(i: int) -> void: view.speed = SPEEDS[i])
	_reset_button = _button(_sim_tools, _start_simulation)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_time_label = _label(bar)
	_language_select = _option(bar)
	for language: String in LOCALE_NAMES:
		_language_select.add_item(language)
	_language_select.item_selected.connect(_on_language_selected)

	var middle: HBoxContainer = HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(middle)
	_palette = Palette.new()
	middle.add_child(_palette)
	var canvas_area: Control = Control.new()
	canvas_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(canvas_area)
	_properties = PropertiesPanel.new()
	middle.add_child(_properties)

	var bottom: PanelContainer = PanelContainer.new()
	root.add_child(bottom)
	var status: HBoxContainer = HBoxContainer.new()
	bottom.add_child(status)
	_status_label = _label(status)
	status.add_child(VSeparator.new())
	_hint_label = _label(status)
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.clip_text = true
	_retranslate()
	_update_mode_ui()


func _label(parent: Control) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	parent.add_child(label)
	return label


func _button(parent: Control, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


func _option(parent: Control) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	option.focus_mode = Control.FOCUS_NONE
	parent.add_child(option)
	return option


## Sets every static text; called on start and when the language changes.
func _retranslate() -> void:
	_edit_button.text = tr("Edit")
	_simulate_button.text = tr("Simulate")
	_circuit_label.text = tr("Circuit:")
	for i: int in ExampleCircuits.count():
		_circuit_select.set_item_text(i, tr(ExampleCircuits.TITLES[i]))
	_new_button.text = tr("New")
	_new_button.tooltip_text = tr("Start an empty schematic with L and N supplies")
	_layout_label.text = tr("Layout:")
	_layout_select.set_item_text(0, tr("Vertical"))
	_layout_select.set_item_text(1, tr("Horizontal"))
	_undo_button.text = tr("Undo")
	_redo_button.text = tr("Redo")
	_rotate_button.text = tr("Rotate")
	_rotate_button.tooltip_text = tr("Rotate by 90° (R)")
	_mirror_button.text = tr("Mirror")
	_mirror_button.tooltip_text = tr("Mirror across the symbol axis (F)")
	_delete_button.text = tr("Delete")
	_step_button.text = tr("Step")
	_step_button.tooltip_text = tr("Advance the simulation by 0.1 s")
	_speed_label.text = tr("Speed:")
	_reset_button.text = tr("Reset")
	_reset_button.tooltip_text = tr("Restart the simulation from the initial state")
	_palette.retranslate()
	_properties.show_component(_single_selected())
	editor._emit_hint()
	_update_run_button()
	_on_stepped(view.last_result)


func _update_mode_ui() -> void:
	var editing: bool = mode == Mode.EDIT
	_edit_tools.visible = editing
	_palette.visible = editing
	_properties.visible = editing
	_sim_tools.visible = not editing
	_time_label.visible = not editing
	_update_run_button()
	_on_stepped(view.last_result)


func _update_run_button() -> void:
	_run_button.text = tr("Pause") if view.running else tr("Run")
	_step_button.disabled = view.running


# --- Documents and modes ----------------------------------------------------------

func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	editor.active = mode == Mode.EDIT
	if mode == Mode.SIMULATE:
		_start_simulation()
	else:
		view.load_document(edit_doc, false)
	_update_mode_ui()


## (Re)starts the simulation on a fresh copy of the edited schematic.
func _start_simulation() -> void:
	view.load_document(DocumentSerializer.from_dict(DocumentSerializer.to_dict(edit_doc)), true)
	view.running = true
	_update_run_button()


func _show_document(doc: SchematicDocument, fit: bool) -> void:
	edit_doc = doc
	if mode == Mode.SIMULATE:
		_start_simulation()
	else:
		view.load_document(edit_doc, false)
	_layout_select.select(1 if doc.horizontal else 0)
	if fit:
		_fit_camera()


func _load_example() -> void:
	if edit_doc != null:
		editor.history.record(DocumentSerializer.to_dict(edit_doc))
	_show_document(ExampleCircuits.build(_circuit_select.selected, _layout_select.selected == 1), true)
	editor._clear_selection()


func _new_document() -> void:
	editor.history.record(DocumentSerializer.to_dict(edit_doc))
	var doc: SchematicDocument = SchematicDocument.new(tr("New schematic"))
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, 16))
	if _layout_select.selected == 1:
		doc.transpose()
	_show_document(doc, true)
	editor._clear_selection()


func _on_document_replaced(doc: SchematicDocument) -> void:
	_show_document(doc, false)


func _fit_camera() -> void:
	var b: Rect2 = view.document.bounds()
	camera.fit(Rect2(b.position * SymbolGeometry.GRID, b.size * SymbolGeometry.GRID))


func _on_layout_selected(index: int) -> void:
	if edit_doc.horizontal == (index == 1):
		return
	editor.history.record(DocumentSerializer.to_dict(edit_doc))
	edit_doc.transpose()
	if view.document != edit_doc:
		view.document.transpose()
		view.refresh_layout()
	else:
		view.rebuild()
	_fit_camera()


func _on_properties_changed(component_id: String, data: Dictionary) -> void:
	var error: String = editor.apply_properties(component_id, data)
	if not error.is_empty():
		_properties.show_error(error)


func _single_selected() -> CircuitComponent:
	if editor == null or edit_doc == null or editor.selected_components.size() != 1:
		return null
	return edit_doc.circuit.get_component(editor.selected_components.keys()[0])


func _on_run_pressed() -> void:
	view.running = not view.running
	_update_run_button()


func _on_language_selected(index: int) -> void:
	TranslationServer.set_locale(LOCALES[index])
	_retranslate()


func _on_editor_hint(text: String) -> void:
	_editor_hint = text
	if mode == Mode.EDIT and _status_label != null:
		_status_label.text = text


func _on_stepped(result: StepResult) -> void:
	if _time_label == null:
		return
	if mode == Mode.EDIT:
		_status_label.text = _editor_hint
		_status_label.remove_theme_color_override("font_color")
		_hint_label.text = tr("Right or middle drag pans, wheel zooms.")
		return
	_hint_label.text = tr("Click buttons and switches to operate them. Right or middle drag pans, wheel zooms.")
	_time_label.text = tr("Time: %.1f s") % view.sim_time
	if result.short_circuit:
		_status_label.text = tr("Short circuit: %s") % " → ".join(result.short_circuit_path)
		_status_label.add_theme_color_override("font_color", SchematicTheme.FAULT)
	elif result.is_oscillating():
		_status_label.text = tr("Oscillation: %s keeps switching on and off") % ", ".join(result.oscillating_tags)
		_status_label.add_theme_color_override("font_color", SchematicTheme.WARNING)
	else:
		_status_label.text = tr("Running") if view.running else tr("Paused")
		_status_label.remove_theme_color_override("font_color")
