extends Node
## Main window: toolbar, palette, schematic view, properties, check results and
## status bar. Edit mode edits the schematic; Simulate mode runs a copy of it,
## so the simulation never changes the design.
## All user-facing text is English source text passed through tr().

enum Mode { EDIT, SIMULATE }
enum FileMenuId { NEW, OPEN, SAVE, SAVE_AS, EXPORT_PNG, QUIT }
enum DialogPurpose { OPEN, SAVE, EXPORT }

const SPEEDS: Array[float] = [0.5, 1.0, 2.0, 5.0]
const LOCALES: PackedStringArray = ["en", "cs"]
## Language names are shown in their own language, never translated.
const LOCALE_NAMES: PackedStringArray = ["English", "Čeština"]
const SETTINGS_PATH: String = "user://settings.cfg"
const MAX_RECENT: int = 8
const EXPORT_MARGIN: float = 40.0

var mode: Mode = Mode.EDIT
## The schematic being designed (the simulation runs on a copy).
var edit_doc: SchematicDocument
var view: SchematicView
var camera: SchematicCamera
var editor: SchematicEditor

## File of the edited schematic, "" when it was never saved.
var _file_path: String = ""
var _dirty: bool = false
var _example_index: int = 0
var _recent: PackedStringArray = PackedStringArray()
var _dialog_purpose: DialogPurpose = DialogPurpose.OPEN
## Runs after a successful save started from the unsaved-changes prompt.
var _after_save: Callable = Callable()
## Runs when the user chose to continue in the unsaved-changes prompt.
var _after_discard: Callable = Callable()

var _file_menu: MenuButton
var _recent_menu: PopupMenu
var _edit_button: Button
var _simulate_button: Button
var _circuit_label: Label
var _circuit_select: OptionButton
var _layout_label: Label
var _layout_select: OptionButton
var _edit_tools: HBoxContainer
var _undo_button: Button
var _redo_button: Button
var _rotate_button: Button
var _mirror_button: Button
var _delete_button: Button
var _check_button: Button
var _sim_tools: HBoxContainer
var _run_button: Button
var _step_button: Button
var _speed_label: Label
var _speed_select: OptionButton
var _reset_button: Button
var _time_label: Label
var _fullscreen_button: Button
var _language_select: OptionButton
var _palette: Palette
var _side: VBoxContainer
## Part of the window where the schematic is visible (between the panels).
var _canvas_area: Control
var _properties: PropertiesPanel
var _check_panel: CheckPanel
var _status_label: Label
var _hint_label: Label
var _editor_hint: String = ""
var _file_dialog: FileDialog
var _unsaved_dialog: ConfirmationDialog
var _discard_button: Button
var _error_dialog: AcceptDialog


func _ready() -> void:
	get_tree().auto_accept_quit = false
	RenderingServer.set_default_clear_color(SchematicTheme.BACKGROUND)
	view = SchematicView.new()
	add_child(view)
	editor = SchematicEditor.new()
	editor.view = view
	add_child(editor)
	camera = SchematicCamera.new()
	add_child(camera)
	camera.make_current()
	_load_settings()
	_build_ui()
	_build_dialogs()
	view.stepped.connect(_on_stepped)
	editor.document_replaced.connect(_on_document_replaced)
	editor.selection_changed.connect(func(c: CircuitComponent) -> void: _properties.show_component(c))
	editor.hint_changed.connect(_on_editor_hint)
	editor.edited.connect(_mark_dirty)
	_properties.changed.connect(_on_properties_changed)
	_properties.type_changed.connect(_on_type_changed)
	_palette.template_chosen.connect(func(t: Dictionary) -> void: editor.begin_place(t))
	_check_panel.issue_selected.connect(_on_issue_selected)
	editor.active = true
	_load_example()


func _process(_delta: float) -> void:
	_undo_button.disabled = not editor.history.can_undo()
	_redo_button.disabled = not editor.history.can_redo()
	var has_selection: bool = not editor.selected_components.is_empty()
	_rotate_button.disabled = not has_selection and editor.tool != SchematicEditor.Tool.PLACE
	_mirror_button.disabled = _rotate_button.disabled
	_delete_button.disabled = not has_selection and editor.selected_wires.is_empty()
	_fullscreen_button.set_pressed_no_signal(_is_fullscreen())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_confirm_discard(func() -> void: get_tree().quit())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	var key: InputEventKey = event as InputEventKey
	var ctrl: bool = key.ctrl_pressed or key.meta_pressed
	var handled: bool = true
	match key.keycode:
		KEY_F11:
			_toggle_fullscreen()
		KEY_S when ctrl and key.shift_pressed:
			_save_as()
		KEY_S when ctrl:
			_save()
		KEY_O when ctrl:
			_confirm_discard(_show_open_dialog)
		KEY_N when ctrl:
			_confirm_discard(_new_document)
		KEY_Q when ctrl:
			_confirm_discard(func() -> void: get_tree().quit())
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


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

	_file_menu = MenuButton.new()
	_file_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_file_menu.flat = false
	_file_menu.focus_mode = Control.FOCUS_NONE
	bar.add_child(_file_menu)
	_recent_menu = PopupMenu.new()
	_recent_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_recent_menu.index_pressed.connect(_on_recent_pressed)
	_file_menu.get_popup().add_child(_recent_menu)
	_file_menu.get_popup().id_pressed.connect(_on_file_menu)

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
	_circuit_select.item_selected.connect(_on_example_selected)
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
	_check_button = _button(_edit_tools, func() -> void: _check_panel.run(edit_doc))

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
	_fullscreen_button = _button(bar, _toggle_fullscreen)
	_fullscreen_button.toggle_mode = true
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
	_canvas_area = Control.new()
	_canvas_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(_canvas_area)
	_side = VBoxContainer.new()
	middle.add_child(_side)
	_properties = PropertiesPanel.new()
	_properties.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side.add_child(_properties)
	_check_panel = CheckPanel.new()
	_check_panel.custom_minimum_size = Vector2(220, 0)
	_side.add_child(_check_panel)

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


func _build_dialogs() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)
	_unsaved_dialog = ConfirmationDialog.new()
	_discard_button = _unsaved_dialog.add_button("", true, "discard")
	_unsaved_dialog.confirmed.connect(func() -> void: _save(_after_discard))
	_unsaved_dialog.custom_action.connect(func(_action: StringName) -> void:
		_unsaved_dialog.hide()
		_after_discard.call())
	add_child(_unsaved_dialog)
	_error_dialog = AcceptDialog.new()
	add_child(_error_dialog)
	_retranslate_dialogs()


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
	_file_menu.text = tr("File")
	_rebuild_file_menu()
	_edit_button.text = tr("Edit")
	_simulate_button.text = tr("Simulate")
	_circuit_label.text = tr("Example:")
	for i: int in ExampleCircuits.count():
		_circuit_select.set_item_text(i, tr(ExampleCircuits.TITLES[i]))
	_layout_label.text = tr("Layout:")
	_layout_select.set_item_text(0, tr("Vertical"))
	_layout_select.set_item_text(1, tr("Horizontal"))
	_undo_button.text = tr("Undo")
	_undo_button.tooltip_text = "Ctrl+Z"
	_redo_button.text = tr("Redo")
	_redo_button.tooltip_text = "Ctrl+Y"
	_rotate_button.text = tr("Rotate (R)")
	_rotate_button.tooltip_text = tr("Rotate by 90°")
	_mirror_button.text = tr("Mirror (F)")
	_mirror_button.tooltip_text = tr("Mirror across the symbol axis")
	_delete_button.text = tr("Delete (Del)")
	_check_button.text = tr("Check")
	_check_button.tooltip_text = tr("Look for unconnected terminals, contacts without a coil and other mistakes")
	_step_button.text = tr("Step")
	_step_button.tooltip_text = tr("Advance the simulation by 0.1 s")
	_speed_label.text = tr("Speed:")
	_reset_button.text = tr("Reset")
	_reset_button.tooltip_text = tr("Restart the simulation from the initial state")
	_fullscreen_button.text = tr("Fullscreen")
	_fullscreen_button.tooltip_text = "F11"
	_palette.retranslate()
	_properties.show_component(_single_selected())
	if _check_panel.visible:
		_check_panel.run(edit_doc)
	editor._emit_hint()
	_update_run_button()
	_update_title()
	_on_stepped(view.last_result)
	if _unsaved_dialog != null:
		_retranslate_dialogs()


func _retranslate_dialogs() -> void:
	_unsaved_dialog.title = tr("Unsaved changes")
	_unsaved_dialog.ok_button_text = tr("Save")
	_unsaved_dialog.cancel_button_text = tr("Cancel")
	_discard_button.text = tr("Don't save")
	_error_dialog.title = tr("Error")


func _rebuild_file_menu() -> void:
	var popup: PopupMenu = _file_menu.get_popup()
	popup.clear()
	popup.add_item(tr("New"), FileMenuId.NEW, KEY_MASK_CTRL | KEY_N)
	popup.add_item(tr("Open…"), FileMenuId.OPEN, KEY_MASK_CTRL | KEY_O)
	popup.add_submenu_node_item(tr("Open recent"), _recent_menu)
	popup.set_item_disabled(popup.item_count - 1, _recent.is_empty())
	popup.add_separator()
	popup.add_item(tr("Save"), FileMenuId.SAVE, KEY_MASK_CTRL | KEY_S)
	popup.add_item(tr("Save as…"), FileMenuId.SAVE_AS, KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_S)
	popup.add_item(tr("Export PNG…"), FileMenuId.EXPORT_PNG)
	popup.add_separator()
	popup.add_item(tr("Quit"), FileMenuId.QUIT, KEY_MASK_CTRL | KEY_Q)
	_recent_menu.clear()
	for path: String in _recent:
		_recent_menu.add_item(path.get_file())
		_recent_menu.set_item_tooltip(_recent_menu.item_count - 1, path)


func _update_mode_ui() -> void:
	var editing: bool = mode == Mode.EDIT
	_edit_tools.visible = editing
	_palette.visible = editing
	_side.visible = editing
	_sim_tools.visible = not editing
	_time_label.visible = not editing
	_update_run_button()
	_on_stepped(view.last_result)


func _update_run_button() -> void:
	_run_button.text = tr("Pause") if view.running else tr("Run")
	_step_button.disabled = view.running


func _update_title() -> void:
	var name: String = _file_path.get_file() if not _file_path.is_empty() else tr("Untitled")
	get_window().title = "%s%s – LadderLab" % [name, "*" if _dirty else ""]


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
	_check_panel.hide()
	if fit:
		_fit_camera()


## Replaces the edited schematic with a new one that has no file yet.
func _replace_document(doc: SchematicDocument, path: String) -> void:
	editor.history.clear()
	editor._clear_selection()
	_show_document(doc, true)
	_file_path = path
	_dirty = false
	_update_title()


func _load_example() -> void:
	_example_index = _circuit_select.selected
	_replace_document(ExampleCircuits.build(_example_index, _layout_select.selected == 1), "")


func _on_example_selected(index: int) -> void:
	# Keep showing the current example until the user agreed to leave the schematic.
	_circuit_select.select(_example_index)
	_confirm_discard(func() -> void:
		_circuit_select.select(index)
		_load_example())


func _new_document() -> void:
	var doc: SchematicDocument = SchematicDocument.new(tr("New schematic"))
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, 16))
	if _layout_select.selected == 1:
		doc.transpose()
	_replace_document(doc, "")


func _on_document_replaced(doc: SchematicDocument) -> void:
	_show_document(doc, false)


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		_update_title()
	if _check_panel.visible:
		_check_panel.run(edit_doc)


func _fit_camera() -> void:
	# Path numbers are drawn outside the bounds, above or left of the drawing.
	var b: Rect2 = view.document.bounds().grow_individual(2.5, 2.5, 0.0, 0.0)
	camera.fit(Rect2(b.position * SymbolGeometry.GRID, b.size * SymbolGeometry.GRID), _canvas_area.get_global_rect())


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
	editor.queue_redraw()
	_mark_dirty()
	_fit_camera()


func _on_properties_changed(component_id: String, data: Dictionary) -> void:
	var error: String = editor.apply_properties(component_id, data)
	if not error.is_empty():
		_properties.show_error(error)


func _on_type_changed(component_id: String, template: Dictionary) -> void:
	var error: String = editor.change_type(component_id, template)
	if not error.is_empty():
		_properties.show_error(error)


func _on_issue_selected(ids: PackedStringArray) -> void:
	editor._clear_selection()
	for id: String in ids:
		editor.selected_components[id] = true
	editor._selection_updated()
	if not ids.is_empty():
		var body: Rect2 = edit_doc.component_body(edit_doc.circuit.get_component(ids[0]))
		camera.look_at_world(body.get_center() * SymbolGeometry.GRID, _canvas_area.get_global_rect())


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


func _is_fullscreen() -> bool:
	var m: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if _is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)


# --- Files ----------------------------------------------------------------------

func _on_file_menu(id: int) -> void:
	match id:
		FileMenuId.NEW:
			_confirm_discard(_new_document)
		FileMenuId.OPEN:
			_confirm_discard(_show_open_dialog)
		FileMenuId.SAVE:
			_save()
		FileMenuId.SAVE_AS:
			_save_as()
		FileMenuId.EXPORT_PNG:
			_show_file_dialog(DialogPurpose.EXPORT)
		FileMenuId.QUIT:
			_confirm_discard(func() -> void: get_tree().quit())


func _on_recent_pressed(index: int) -> void:
	var path: String = _recent[index]
	_confirm_discard(func() -> void: open_file(path))


## Runs [param action] right away, or after asking what to do with unsaved
## changes (save first, discard, or cancel).
func _confirm_discard(action: Callable) -> void:
	if not _dirty:
		action.call()
		return
	_after_discard = action
	var name: String = _file_path.get_file() if not _file_path.is_empty() else tr("Untitled")
	_unsaved_dialog.dialog_text = tr("Save changes to %s?") % name
	_unsaved_dialog.popup_centered()


func _show_open_dialog() -> void:
	_show_file_dialog(DialogPurpose.OPEN)


func _show_file_dialog(purpose: DialogPurpose) -> void:
	_dialog_purpose = purpose
	match purpose:
		DialogPurpose.OPEN:
			_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			_file_dialog.title = tr("Open schematic")
			_file_dialog.filters = PackedStringArray(["*.%s ; %s" % [ProjectFile.EXTENSION, tr("LadderLab schematic")]])
		DialogPurpose.SAVE:
			_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			_file_dialog.title = tr("Save schematic")
			_file_dialog.filters = PackedStringArray(["*.%s ; %s" % [ProjectFile.EXTENSION, tr("LadderLab schematic")]])
			_file_dialog.current_file = (_file_path.get_file() if not _file_path.is_empty() else tr("schematic") + "." + ProjectFile.EXTENSION)
		DialogPurpose.EXPORT:
			_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			_file_dialog.title = tr("Export PNG")
			_file_dialog.filters = PackedStringArray(["*.png ; PNG"])
			var base: String = _file_path.get_file().get_basename() if not _file_path.is_empty() else tr("schematic")
			_file_dialog.current_file = base + ".png"
	_file_dialog.popup_centered_ratio(0.6)


func _on_file_selected(path: String) -> void:
	match _dialog_purpose:
		DialogPurpose.OPEN:
			open_file(path)
		DialogPurpose.SAVE:
			if path.get_extension().to_lower() != ProjectFile.EXTENSION:
				path += "." + ProjectFile.EXTENSION
			if save_file(path) and _after_save.is_valid():
				var then: Callable = _after_save
				_after_save = Callable()
				then.call()
		DialogPurpose.EXPORT:
			if path.get_extension().to_lower() != "png":
				path += ".png"
			export_png(path)


## Saves to the current file, or asks for one. [param then] runs after a
## successful save.
func _save(then: Callable = Callable()) -> void:
	if _file_path.is_empty():
		_save_as(then)
	elif save_file(_file_path) and then.is_valid():
		then.call()


func _save_as(then: Callable = Callable()) -> void:
	_after_save = then
	_show_file_dialog(DialogPurpose.SAVE)


## Writes the edited schematic to [param path]. Returns true on success.
func save_file(path: String) -> bool:
	if ProjectFile.save(edit_doc, path) != OK:
		_show_error(tr("Could not save %s.") % path.get_file())
		return false
	_file_path = path
	_dirty = false
	_remember_recent(path)
	_update_title()
	return true


## Opens a .ladder file in the editor. Returns true on success.
func open_file(path: String) -> bool:
	var result: Dictionary = ProjectFile.load_file(path)
	if result.has("error"):
		_show_error(tr(result["error"]) % path.get_file())
		if not FileAccess.file_exists(path):
			_recent.erase(path)
			_save_settings()
			_rebuild_file_menu()
		return false
	_replace_document(result["document"], path)
	_remember_recent(path)
	_update_title()
	return true


## Renders the edited schematic at rest (100 % scale) and saves it as PNG.
func export_png(path: String) -> void:
	var b: Rect2 = edit_doc.bounds()
	var origin: Vector2 = b.position * SymbolGeometry.GRID - Vector2(EXPORT_MARGIN, EXPORT_MARGIN * 2.0)
	var size: Vector2 = b.size * SymbolGeometry.GRID + Vector2(EXPORT_MARGIN * 2.0, EXPORT_MARGIN * 3.0)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(size.ceil())
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var background: ColorRect = ColorRect.new()
	background.color = SchematicTheme.BACKGROUND
	background.size = size
	viewport.add_child(background)
	var copy: SchematicView = SchematicView.new()
	copy.position = -origin
	viewport.add_child(copy)
	add_child(viewport)
	copy.load_document(DocumentSerializer.from_dict(DocumentSerializer.to_dict(edit_doc)), false)
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	if image == null or image.save_png(path) != OK:
		_show_error(tr("Could not save %s.") % path.get_file())


func _show_error(text: String) -> void:
	_error_dialog.dialog_text = text
	_error_dialog.popup_centered()


func _remember_recent(path: String) -> void:
	_recent.erase(path)
	_recent.insert(0, path)
	if _recent.size() > MAX_RECENT:
		_recent.resize(MAX_RECENT)
	_save_settings()
	_rebuild_file_menu()


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_recent = config.get_value("files", "recent", PackedStringArray())


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("files", "recent", _recent)
	config.save(SETTINGS_PATH)


# --- Status -----------------------------------------------------------------------

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
