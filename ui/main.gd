extends Node
## Main window: toolbar, schematic view and status bar.
## All user-facing text is English source text passed through tr().

const SPEEDS: Array[float] = [0.5, 1.0, 2.0, 5.0]
const LOCALES: PackedStringArray = ["en", "cs"]
## Language names are shown in their own language, never translated.
const LOCALE_NAMES: PackedStringArray = ["English", "Čeština"]

var view: SchematicView
var camera: SchematicCamera

var _circuit_select: OptionButton
var _layout_select: OptionButton
var _run_button: Button
var _step_button: Button
var _speed_select: OptionButton
var _reset_button: Button
var _language_select: OptionButton
var _circuit_label: Label
var _layout_label: Label
var _speed_label: Label
var _time_label: Label
var _status_label: Label
var _hint_label: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(SchematicTheme.BACKGROUND)
	view = SchematicView.new()
	add_child(view)
	camera = SchematicCamera.new()
	add_child(camera)
	camera.make_current()
	_build_ui()
	view.stepped.connect(_on_stepped)
	_load_example()


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var top: PanelContainer = PanelContainer.new()
	root.add_child(top)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	top.add_child(bar)

	_circuit_label = _label(bar)
	_circuit_select = OptionButton.new()
	_circuit_select.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for i: int in ExampleCircuits.count():
		_circuit_select.add_item("")
	_circuit_select.item_selected.connect(func(_i: int) -> void: _load_example())
	bar.add_child(_circuit_select)

	_layout_label = _label(bar)
	_layout_select = OptionButton.new()
	_layout_select.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_layout_select.add_item("")
	_layout_select.add_item("")
	_layout_select.item_selected.connect(_on_layout_selected)
	bar.add_child(_layout_select)

	bar.add_child(VSeparator.new())
	_run_button = _button(bar, _on_run_pressed)
	_step_button = _button(bar, func() -> void: view.step_once())
	_speed_label = _label(bar)
	_speed_select = OptionButton.new()
	_speed_select.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for s: float in SPEEDS:
		_speed_select.add_item("×%s" % str(s))
	_speed_select.select(SPEEDS.find(1.0))
	_speed_select.item_selected.connect(func(i: int) -> void: view.speed = SPEEDS[i])
	bar.add_child(_speed_select)
	_reset_button = _button(bar, _load_example)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_time_label = _label(bar)
	_language_select = OptionButton.new()
	_language_select.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for language: String in LOCALE_NAMES:
		_language_select.add_item(language)
	_language_select.item_selected.connect(_on_language_selected)
	bar.add_child(_language_select)

	var middle: Control = Control.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(middle)

	var bottom: PanelContainer = PanelContainer.new()
	root.add_child(bottom)
	var status: HBoxContainer = HBoxContainer.new()
	bottom.add_child(status)
	_status_label = _label(status)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label = _label(status)
	_retranslate()


func _label(parent: Control) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	parent.add_child(label)
	return label


func _button(parent: Control, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


## Sets every static text; called on start and when the language changes.
func _retranslate() -> void:
	_circuit_label.text = tr("Circuit:")
	for i: int in ExampleCircuits.count():
		_circuit_select.set_item_text(i, tr(ExampleCircuits.TITLES[i]))
	_layout_label.text = tr("Layout:")
	_layout_select.set_item_text(0, tr("Vertical"))
	_layout_select.set_item_text(1, tr("Horizontal"))
	_step_button.text = tr("Step")
	_step_button.tooltip_text = tr("Advance the simulation by 0.1 s")
	_speed_label.text = tr("Speed:")
	_reset_button.text = tr("Reset")
	_reset_button.tooltip_text = tr("Reload the circuit in its initial state")
	_hint_label.text = tr("Click buttons and switches to operate them. Right or middle drag pans, wheel zooms.")
	_update_run_button()
	_on_stepped(view.last_result)


func _update_run_button() -> void:
	_run_button.text = tr("Pause") if view.running else tr("Run")
	_step_button.disabled = view.running


func _load_example() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(_circuit_select.selected, _layout_select.selected == 1)
	view.load_document(doc)
	_fit_camera()


func _fit_camera() -> void:
	var b: Rect2 = view.document.bounds()
	camera.fit(Rect2(b.position * SymbolGeometry.GRID, b.size * SymbolGeometry.GRID))


func _on_layout_selected(index: int) -> void:
	if view.document.horizontal != (index == 1):
		view.document.transpose()
		view.refresh_layout()
		_fit_camera()


func _on_run_pressed() -> void:
	view.running = not view.running
	_update_run_button()


func _on_language_selected(index: int) -> void:
	TranslationServer.set_locale(LOCALES[index])
	_retranslate()


func _on_stepped(result: StepResult) -> void:
	if _time_label == null:
		return
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
