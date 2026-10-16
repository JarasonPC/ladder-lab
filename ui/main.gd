extends Node
## Main window: toolbar, palette, schematic view, properties, check results and
## status bar. Edit mode edits the schematic; Simulate mode runs a copy of it,
## so the simulation never changes the design.
## All user-facing text is English source text passed through tr().

enum Mode { EDIT, SIMULATE }
enum FileMenuId { NEW, OPEN, SAVE, SAVE_AS, EXPORT_PNG, EXPORT_PDF, QUIT }
enum ViewMenuId { FULLSCREEN, THEME_DARK, THEME_LIGHT, WHITE_PAPER, GRID, WIRE_NUMBERS, LANGUAGE = 10, SCALE = 20 }
enum DialogPurpose { OPEN, SAVE, EXPORT_PNG, EXPORT_PDF }
enum PageMenuId { RENAME, MOVE_LEFT, MOVE_RIGHT, DELETE }
## Titles offered for a new page (English source text: saved like that and
## shown translated, as every page title).
const PAGE_PRESETS: PackedStringArray = ["Power section", "Control section", "Signalling section"]

const SPEEDS: Array[float] = [0.01, 0.1, 0.5, 1.0, 2.0, 5.0]
## Simulated seconds per press of Step at speed x1.
const STEP_SECONDS: float = 0.1
const LOCALES: PackedStringArray = ["en", "cs"]
## Language names are shown in their own language, never translated.
const LOCALE_NAMES: PackedStringArray = ["English", "Čeština"]
## Interface sizes offered in the View menu; 0 follows the screen.
const UI_SCALES: Array[float] = [0.0, 1.0, 1.25, 1.5, 1.75, 2.0]
const SETTINGS_PATH: String = "user://settings.cfg"
const MAX_RECENT: int = 8

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
var _view_menu: MenuButton
var _edit_button: Button
var _simulate_button: Button
var _circuit_select: OptionButton
var _layout_select: OptionButton
var _edit_tools: HBoxContainer
var _undo_button: Button
var _redo_button: Button
var _rotate_button: Button
var _mirror_button: Button
var _flip_button: Button
var _delete_button: Button
var _check_button: Button
var _number_button: Button
var _numbers_toggle: Button
var _sim_tools: HBoxContainer
var _switching_select: OptionButton
var _chart_button: Button
var _log_button: Button
var _timing_panel: TimingPanel
var _run_button: Button
var _step_button: Button
var _speed_select: OptionButton
var _reset_button: Button
var _time_label: Label
var _palette: Palette
var _side: VBoxContainer
## Resizable and zoomable side panels: palette (left), properties with the
## check results and the control panel (right).
var _palette_bar: SideBar
var _side_bar: SideBar
var _control_bar: SideBar
## Width and zoom of each side panel by its settings name, as loaded.
var _bar_settings: Dictionary[String, Vector2] = {}
## Event log width and timing panel height, as loaded.
var _timing_size: Vector2 = Vector2(340.0, 220.0)
## Part of the window where the schematic is visible (between the panels).
var _canvas_area: Control
## Tabs of the pages above the schematic, and the button adding a page.
var _page_tabs: TabBar
var _page_add: MenuButton
var _page_row: HBoxContainer
## Right click menu of a page tab, for page [member _menu_page].
var _page_menu: PopupMenu
var _menu_page: int = -1
var _rename_dialog: ConfirmationDialog
var _rename_field: LineEdit
## True while the tabs are being filled (their signals are ignored).
var _updating_pages: bool = false
## Renders the pages for PNG and PDF export.
var _sheet_renderer: SheetRenderer
## Big red warning over the schematic during an unprotected short circuit.
var _short_banner: Label
var _properties: PropertiesPanel
## Control boxes with the buttons, switches and lamps (both modes).
var _control_panel: ControlPanel
var _panel_toggle: Button
var _show_control_panel: bool = true
var _check_panel: CheckPanel
var _status_label: Label
var _hint_label: Label
var _editor_hint: String = ""
## Timing chart and event log shown in Simulate mode (remembered).
var _show_chart: bool = true
var _show_log: bool = true
var _theme_variant: AppTheme.Variant = AppTheme.Variant.DARK
## Keep the schematic on white paper in the dark theme.
var _white_paper: bool = false
## Dot grid while editing (never while simulating).
var _edit_grid: bool = false
var _wire_numbers: bool = true
## Chosen interface size (see UI_SCALES), 0 = automatic.
var _ui_scale: float = 0.0
var _locale_index: int = 0
var _file_dialog: FileDialog
var _unsaved_dialog: ConfirmationDialog
var _discard_button: Button
var _error_dialog: AcceptDialog


func _ready() -> void:
	get_tree().auto_accept_quit = false
	view = SchematicView.new()
	add_child(view)
	editor = SchematicEditor.new()
	editor.view = view
	add_child(editor)
	camera = SchematicCamera.new()
	add_child(camera)
	camera.make_current()
	_load_settings()
	_apply_ui_scale()
	_apply_theme()
	TranslationServer.set_locale(LOCALES[_locale_index])
	_build_ui()
	_build_dialogs()
	_sheet_renderer = SheetRenderer.new()
	add_child(_sheet_renderer)
	view.stepped.connect(_on_stepped)
	view.page_requested.connect(_show_page)
	editor.page_requested.connect(_show_page)
	editor.edited.connect(_refresh_pages)
	view.event_logged.connect(func(text: String, args: Array) -> void:
		var entries: Array[Dictionary] = [{"time": view.sim_time, "text": text, "args": args}]
		_timing_panel.event_log.add_events(entries))
	editor.document_replaced.connect(_on_document_replaced)
	editor.selection_changed.connect(_on_selection_changed)
	editor.hint_changed.connect(_on_editor_hint)
	editor.edited.connect(_mark_dirty)
	_properties.changed.connect(_on_properties_changed)
	_properties.rotate_requested.connect(func() -> void: editor.rotate_selection())
	_properties.mirror_requested.connect(func() -> void: editor.mirror_selection())
	_properties.flip_requested.connect(func() -> void: editor.flip_selection())
	_properties.type_changed.connect(_on_type_changed)
	_palette.template_chosen.connect(func(t: Dictionary) -> void: editor.begin_place(t))
	_check_panel.issue_selected.connect(_on_issue_selected)
	view.loaded.connect(func() -> void: _control_panel.set_document(view.document, mode == Mode.EDIT))
	editor.edited.connect(_control_panel.refresh)
	_control_panel.edit_requested.connect(editor.edit_control_panel)
	_control_panel.button_held.connect(view.hold_button)
	_control_panel.switch_toggled.connect(view.toggle_switch)
	editor.active = true
	_load_example()


func _process(_delta: float) -> void:
	_undo_button.disabled = not editor.history.can_undo()
	_redo_button.disabled = not editor.history.can_redo()
	var has_selection: bool = not editor.selected_components.is_empty()
	_rotate_button.disabled = not has_selection and editor.tool != SchematicEditor.Tool.PLACE
	_mirror_button.disabled = _rotate_button.disabled
	_flip_button.disabled = _rotate_button.disabled
	_delete_button.disabled = not has_selection and editor.selected_wires.is_empty()


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
	root.add_theme_constant_override("separation", 0)
	layer.add_child(root)

	var top: PanelContainer = PanelContainer.new()
	top.theme_type_variation = "Toolbar"
	root.add_child(top)
	# Wraps onto a second row when the window (or a translation) is too narrow.
	var bar: HFlowContainer = HFlowContainer.new()
	top.add_child(bar)

	var brand: Label = Label.new()
	brand.text = "LadderLab"
	brand.theme_type_variation = "BrandLabel"
	brand.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	brand.custom_minimum_size = Vector2(0, 32)
	brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(brand)
	bar.add_child(_spacer(6))
	_file_menu = _menu(bar)
	_recent_menu = PopupMenu.new()
	_recent_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_recent_menu.index_pressed.connect(_on_recent_pressed)
	_file_menu.get_popup().add_child(_recent_menu)
	_file_menu.get_popup().id_pressed.connect(_on_file_menu)
	_view_menu = _menu(bar)
	_view_menu.get_popup().id_pressed.connect(_on_view_menu)
	_view_menu.about_to_popup.connect(_rebuild_view_menu)
	bar.add_child(VSeparator.new())

	# Edit | Simulate as one segmented switch.
	var track: PanelContainer = PanelContainer.new()
	track.theme_type_variation = "SegmentTrack"
	bar.add_child(track)
	var segments: HBoxContainer = HBoxContainer.new()
	segments.add_theme_constant_override("separation", 2)
	track.add_child(segments)
	var mode_group: ButtonGroup = ButtonGroup.new()
	_edit_button = _button(segments, func() -> void: _set_mode(Mode.EDIT), "edit")
	_simulate_button = _button(segments, func() -> void: _set_mode(Mode.SIMULATE), "simulate")
	for b: Button in [_edit_button, _simulate_button]:
		b.theme_type_variation = "SegmentButton"
		b.toggle_mode = true
		b.button_group = mode_group
	_edit_button.button_pressed = true
	bar.add_child(VSeparator.new())

	_circuit_select = _option(bar)
	_circuit_select.fit_to_longest_item = false
	_circuit_select.clip_text = true
	_circuit_select.custom_minimum_size = Vector2(220, 0)
	for i: int in ExampleCircuits.count():
		_circuit_select.add_item("")
	_circuit_select.item_selected.connect(_on_example_selected)
	_layout_select = _option(bar)
	_layout_select.add_item("")
	_layout_select.add_item("")
	_layout_select.item_selected.connect(_on_layout_selected)
	_numbers_toggle = _tool(bar, func() -> void: _set_wire_numbers(_numbers_toggle.button_pressed), "wire_numbers")
	_numbers_toggle.toggle_mode = true
	_numbers_toggle.button_pressed = _wire_numbers
	_panel_toggle = _tool(bar, func() -> void: _set_control_panel(_panel_toggle.button_pressed), "panel")
	_panel_toggle.toggle_mode = true
	_panel_toggle.button_pressed = _show_control_panel
	bar.add_child(VSeparator.new())

	_edit_tools = HBoxContainer.new()
	_edit_tools.add_theme_constant_override("separation", 2)
	bar.add_child(_edit_tools)
	_undo_button = _tool(_edit_tools, func() -> void: editor.undo(), "undo")
	_redo_button = _tool(_edit_tools, func() -> void: editor.redo(), "redo")
	_edit_tools.add_child(_spacer(8))
	_rotate_button = _tool(_edit_tools, func() -> void: editor.rotate_selection(), "rotate")
	_mirror_button = _tool(_edit_tools, func() -> void: editor.mirror_selection(), "mirror")
	_flip_button = _tool(_edit_tools, func() -> void: editor.flip_selection(), "flip")
	_delete_button = _tool(_edit_tools, func() -> void: editor.delete_selection(), "delete")
	_edit_tools.add_child(_spacer(8))
	_number_button = _tool(_edit_tools, func() -> void: editor.number_wires(), "hash")
	_check_button = _button(_edit_tools, func() -> void: _check_panel.run(edit_doc), "check")

	_sim_tools = HBoxContainer.new()
	_sim_tools.add_theme_constant_override("separation", 4)
	bar.add_child(_sim_tools)
	_run_button = _button(_sim_tools, _on_run_pressed, "pause")
	_run_button.theme_type_variation = "PrimaryButton"
	_run_button.custom_minimum_size = Vector2(96, 0)
	_step_button = _tool(_sim_tools, func() -> void: view.step_once(STEP_SECONDS * view.speed), "step")
	_reset_button = _tool(_sim_tools, _start_simulation, "reset")
	_time_label = _label(_sim_tools)
	_time_label.theme_type_variation = "TimeLabel"
	_time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sim_tools.add_child(_spacer(6))
	_speed_select = _option(_sim_tools)
	for s: float in SPEEDS:
		_speed_select.add_item("×%s" % str(s))
	_speed_select.select(SPEEDS.find(1.0))
	_speed_select.item_selected.connect(func(i: int) -> void: view.speed = SPEEDS[i])
	_switching_select = _option(_sim_tools)
	_switching_select.add_item("")
	_switching_select.add_item("")
	_switching_select.item_selected.connect(_on_switching_selected)
	_sim_tools.add_child(VSeparator.new())
	_chart_button = _tool(_sim_tools, _on_timing_parts_toggled, "chart")
	_chart_button.toggle_mode = true
	_chart_button.button_pressed = _show_chart
	_log_button = _tool(_sim_tools, _on_timing_parts_toggled, "log")
	_log_button.toggle_mode = true
	_log_button.button_pressed = _show_log


	var middle: HBoxContainer = HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(middle)
	_palette = Palette.new()
	_palette_bar = _side_panel(middle, _palette, "palette", false)
	var canvas_column: VBoxContainer = VBoxContainer.new()
	canvas_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_column.add_theme_constant_override("separation", 0)
	middle.add_child(canvas_column)
	canvas_column.add_child(_build_page_bar())
	_canvas_area = Control.new()
	_canvas_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_column.add_child(_canvas_area)
	_short_banner = Label.new()
	_short_banner.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_short_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_short_banner.add_theme_font_override("font", AppTheme.bold_font())
	_short_banner.add_theme_font_size_override("font_size", 20)
	_short_banner.add_theme_color_override("font_color", Color.WHITE)
	var banner_style: StyleBoxFlat = AppTheme.box(AppTheme.danger, 10, 22.0, 10.0)
	banner_style.shadow_color = Color(0, 0, 0, 0.25)
	banner_style.shadow_size = 12
	banner_style.shadow_offset = Vector2(0, 4)
	_short_banner.add_theme_stylebox_override("normal", banner_style)
	_short_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_short_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_short_banner.position.y = 16.0
	_short_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_short_banner.hide()
	_canvas_area.add_child(_short_banner)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 0)
	_properties = PropertiesPanel.new()
	_properties.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side.add_child(_properties)
	_check_panel = CheckPanel.new()
	_side.add_child(_check_panel)
	_side_bar = _side_panel(middle, _side, "properties", true)
	_control_panel = ControlPanel.new()
	_control_bar = _side_panel(middle, _control_panel, "control_panel", true)

	_timing_panel = TimingPanel.new()
	_timing_panel.panel_height = _timing_size.y
	_timing_panel.log_width = _timing_size.x
	_timing_panel.resized_by_user.connect(_save_settings)
	root.add_child(_timing_panel)

	var bottom: PanelContainer = PanelContainer.new()
	bottom.theme_type_variation = "Statusbar"
	root.add_child(bottom)
	var status: HBoxContainer = HBoxContainer.new()
	status.add_theme_constant_override("separation", 12)
	bottom.add_child(status)
	_status_label = _label(status)
	_status_label.add_theme_font_size_override("font_size", AppTheme.SMALL_FONT_SIZE)
	_hint_label = _label(status)
	_hint_label.theme_type_variation = "MutedLabel"
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.clip_text = true
	_retranslate()
	_update_mode_ui()


## Tabs of the pages (click to show one, drag to reorder, double-click to
## rename, right click for more) and, right after the last tab, a button
## adding a page.
func _build_page_bar() -> Control:
	var bar: PanelContainer = PanelContainer.new()
	bar.theme_type_variation = "PageBar"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.resized.connect(_fit_page_tabs)
	bar.add_child(row)
	_page_row = row
	_page_tabs = TabBar.new()
	_page_tabs.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_page_tabs.focus_mode = Control.FOCUS_NONE
	_page_tabs.max_tab_width = 260
	_page_tabs.tab_changed.connect(func(tab: int) -> void:
		if not _updating_pages:
			_show_page(tab))
	_page_tabs.tab_rmb_clicked.connect(_open_page_menu)
	_page_tabs.active_tab_rearranged.connect(func(to: int) -> void:
		if not _updating_pages:
			var from: int = edit_doc.page
			editor.edit_pages(func(doc: SchematicDocument) -> void: doc.move_page(from, to)))
	_page_tabs.gui_input.connect(func(event: InputEvent) -> void:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb != null and mb.pressed and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT and mode == Mode.EDIT:
			var tab: int = _page_tabs.get_tab_idx_at_point(mb.position)
			if tab >= 0:
				_show_rename_dialog(tab))
	row.add_child(_page_tabs)
	_page_add = _menu(row)
	_page_add.theme_type_variation = "ToolButton"
	_page_add.icon = AppTheme.icon("plus")
	_page_add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rest: Control = Control.new()
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rest)
	_page_add.get_popup().id_pressed.connect(func(id: int) -> void:
		_add_page(PAGE_PRESETS[id] if id < PAGE_PRESETS.size() else ""))
	_page_menu = PopupMenu.new()
	_page_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_page_menu.id_pressed.connect(_on_page_menu)
	bar.add_child(_page_menu)
	return bar


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
	_rename_dialog = ConfirmationDialog.new()
	_rename_field = LineEdit.new()
	_rename_field.custom_minimum_size = Vector2(280, 0)
	_rename_dialog.add_child(_rename_field)
	_rename_dialog.register_text_enter(_rename_field)
	_rename_dialog.confirmed.connect(func() -> void:
		var index: int = _menu_page
		var title: String = _rename_field.text.strip_edges()
		if title == _page_title(index):
			return
		editor.edit_pages(func(doc: SchematicDocument) -> void: doc.rename_page(index, title)))
	add_child(_rename_dialog)
	_retranslate_dialogs()


func _label(parent: Control) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	parent.add_child(label)
	return label


## Button with text and an optional icon from [method AppTheme.icon].
func _button(parent: Control, on_pressed: Callable, icon_name: String = "") -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.focus_mode = Control.FOCUS_NONE
	if not icon_name.is_empty():
		button.icon = AppTheme.icon(icon_name)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


## Icon-only toolbar button; its name is in the tooltip.
func _tool(parent: Control, on_pressed: Callable, icon_name: String) -> Button:
	var button: Button = _button(parent, on_pressed, icon_name)
	button.theme_type_variation = "ToolButton"
	return button


func _menu(parent: Control) -> MenuButton:
	var menu: MenuButton = MenuButton.new()
	menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	menu.focus_mode = Control.FOCUS_NONE
	menu.switch_on_hover = true
	parent.add_child(menu)
	return menu


func _spacer(width: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(width, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


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
	_view_menu.text = tr("View")
	_edit_button.text = tr("Edit")
	_simulate_button.text = tr("Simulate")
	_circuit_select.tooltip_text = tr("Example circuit")
	for i: int in ExampleCircuits.count():
		_circuit_select.set_item_text(i, tr(ExampleCircuits.TITLES[i]))
	_layout_select.tooltip_text = tr("Direction of the current paths")
	_layout_select.set_item_text(0, tr("Vertical"))
	_layout_select.set_item_text(1, tr("Horizontal"))
	_undo_button.tooltip_text = tr("Undo") + "  (Ctrl+Z)"
	_redo_button.tooltip_text = tr("Redo") + "  (Ctrl+Y)"
	_rotate_button.tooltip_text = tr("Rotate by 90°") + "  (R)"
	_mirror_button.tooltip_text = tr("Mirror left-right, across the symbol axis") + "  (F)"
	_flip_button.tooltip_text = tr("Mirror top-bottom: the upper and lower terminals swap") + "  (Shift+F)"
	_delete_button.tooltip_text = tr("Delete") + "  (Del)"
	_numbers_toggle.tooltip_text = tr("Show wire numbers (drag a number to move it)")
	_panel_toggle.tooltip_text = tr("Show the control panel: boxes with the push buttons, switches and signal lamps")
	_number_button.tooltip_text = tr("Number the wires: every net gets its own number, all wire ends of a net the same")
	_check_button.text = tr("Check")
	_check_button.tooltip_text = tr("Look for unconnected terminals, contacts without a coil and other mistakes")
	_switching_select.set_item_text(0, tr("Realistic"))
	_switching_select.set_item_text(1, tr("Ideal"))
	_switching_select.tooltip_text = tr("Realistic: relays need their pick-up and drop-out time, NC contacts break before NO contacts make. Ideal: relays switch instantly.")
	_chart_button.tooltip_text = tr("Show or hide the timing chart")
	_log_button.tooltip_text = tr("Show or hide the event log")
	_step_button.tooltip_text = tr("Step") + " – " + tr("Advance the simulation by 0.1 s times the speed")
	_speed_select.tooltip_text = tr("Simulation speed")
	_time_label.tooltip_text = tr("Simulation time")
	_time_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_reset_button.tooltip_text = tr("Reset") + " – " + tr("Restart the simulation from the initial state")
	_page_add.tooltip_text = tr("Add a page")
	var page_popup: PopupMenu = _page_add.get_popup()
	page_popup.clear()
	for i: int in PAGE_PRESETS.size():
		page_popup.add_item(tr(PAGE_PRESETS[i]), i)
	page_popup.add_separator()
	page_popup.add_item(tr("Empty page"), PAGE_PRESETS.size())
	_page_tabs.tooltip_text = tr("Pages of the schematic: click to show one, drag to reorder, double-click to rename, right click for more")
	_refresh_pages()
	_palette.retranslate()
	for bar: SideBar in [_palette_bar, _side_bar, _control_bar]:
		bar.retranslate()
	_control_panel.retranslate()
	_timing_panel.retranslate()
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
	_rename_dialog.title = tr("Rename page")
	_rename_dialog.ok_button_text = tr("Rename")
	_rename_dialog.cancel_button_text = tr("Cancel")


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
	popup.add_item(tr("Export page as PNG…"), FileMenuId.EXPORT_PNG)
	popup.add_item(tr("Export all pages as PDF…"), FileMenuId.EXPORT_PDF)
	popup.add_separator()
	popup.add_item(tr("Quit"), FileMenuId.QUIT, KEY_MASK_CTRL | KEY_Q)
	_recent_menu.clear()
	for path: String in _recent:
		_recent_menu.add_item(path.get_file())
		_recent_menu.set_item_tooltip(_recent_menu.item_count - 1, path)


func _rebuild_view_menu() -> void:
	var popup: PopupMenu = _view_menu.get_popup()
	popup.clear()
	popup.add_check_item(tr("Fullscreen"), ViewMenuId.FULLSCREEN, KEY_F11)
	popup.set_item_checked(0, _is_fullscreen())
	popup.add_separator(tr("Theme"))
	popup.add_radio_check_item(tr("Dark"), ViewMenuId.THEME_DARK)
	popup.set_item_checked(popup.item_count - 1, _theme_variant == AppTheme.Variant.DARK)
	popup.add_radio_check_item(tr("Light"), ViewMenuId.THEME_LIGHT)
	popup.set_item_checked(popup.item_count - 1, _theme_variant == AppTheme.Variant.LIGHT)
	popup.add_check_item(tr("White schematic paper"), ViewMenuId.WHITE_PAPER)
	popup.set_item_checked(popup.item_count - 1, _white_paper or _theme_variant == AppTheme.Variant.LIGHT)
	popup.set_item_disabled(popup.item_count - 1, _theme_variant == AppTheme.Variant.LIGHT)
	popup.set_item_tooltip(popup.item_count - 1, tr("Draw the schematic on white paper in the dark theme, as in the guide"))
	popup.add_check_item(tr("Wire numbers"), ViewMenuId.WIRE_NUMBERS)
	popup.set_item_checked(popup.item_count - 1, _wire_numbers)
	popup.add_check_item(tr("Grid while editing"), ViewMenuId.GRID)
	popup.set_item_checked(popup.item_count - 1, _edit_grid)
	popup.add_separator(tr("Language"))
	for i: int in LOCALE_NAMES.size():
		popup.add_radio_check_item(LOCALE_NAMES[i], ViewMenuId.LANGUAGE + i)
		popup.set_item_checked(popup.item_count - 1, i == _locale_index)
	popup.add_separator(tr("Interface size"))
	for i: int in UI_SCALES.size():
		var title: String = tr("Automatic") if UI_SCALES[i] == 0.0 else "%d %%" % roundi(UI_SCALES[i] * 100.0)
		popup.add_radio_check_item(title, ViewMenuId.SCALE + i)
		popup.set_item_checked(popup.item_count - 1, is_equal_approx(UI_SCALES[i], _ui_scale))


func _on_view_menu(id: int) -> void:
	if id == ViewMenuId.FULLSCREEN:
		_toggle_fullscreen()
	elif id == ViewMenuId.THEME_DARK or id == ViewMenuId.THEME_LIGHT:
		_theme_variant = AppTheme.Variant.DARK if id == ViewMenuId.THEME_DARK else AppTheme.Variant.LIGHT
		_apply_theme()
		_save_settings()
	elif id == ViewMenuId.WIRE_NUMBERS:
		_set_wire_numbers(not _wire_numbers)
	elif id == ViewMenuId.GRID:
		_edit_grid = not _edit_grid
		_update_mode_ui()
		_save_settings()
	elif id == ViewMenuId.WHITE_PAPER:
		_white_paper = not _white_paper
		_apply_theme()
		_save_settings()
	elif id >= ViewMenuId.SCALE:
		_ui_scale = UI_SCALES[id - ViewMenuId.SCALE]
		_apply_ui_scale()
		_save_settings()
		_fit_camera_later()
	elif id >= ViewMenuId.LANGUAGE:
		set_language(id - ViewMenuId.LANGUAGE)


## Puts the [AppTheme] in place for every control and window, including popups
## that are not under the main panel.
func _apply_theme() -> void:
	AppTheme.use(_theme_variant)
	var theme: Theme = AppTheme.build()
	var base: Theme = ThemeDB.get_default_theme()
	base.merge_with(theme)
	base.default_font = AppTheme.ui_font()
	base.default_font_size = AppTheme.FONT_SIZE
	get_tree().root.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)
	# The schematic: dark paper in the dark theme unless white paper is chosen.
	SchematicTheme.use(_theme_variant == AppTheme.Variant.DARK and not _white_paper)
	RenderingServer.set_default_clear_color(SchematicTheme.BACKGROUND)
	if _palette != null:
		_palette.refresh_paper()


## Interface size: the chosen one, or the screen's scale (HiDPI and Windows
## display scaling). Text and icons are drawn at the real resolution, so they
## stay sharp at every size.
func _apply_ui_scale() -> void:
	var factor: float = _ui_scale
	if factor <= 0.0:
		factor = DisplayServer.screen_get_scale()
		if factor <= 1.0 and OS.get_name() == "Windows":
			factor = DisplayServer.screen_get_dpi() / 96.0
		factor = clampf(snappedf(factor, 0.25), 1.0, 3.0)
	get_window().content_scale_factor = factor


## Puts [param content] into a resizable, zoomable [SideBar] added to
## [param parent], with the width and zoom remembered as [param key].
func _side_panel(parent: Control, content: Control, key: String, grip_left: bool) -> SideBar:
	var bar: SideBar = SideBar.new(content, grip_left)
	bar.name = key
	var saved: Vector2 = _bar_settings.get(key, Vector2(250.0, 1.0))
	bar.width = saved.x
	bar.zoom = saved.y
	bar.changed.connect(_save_settings)
	parent.add_child(bar)
	return bar


func _set_control_panel(on: bool) -> void:
	_show_control_panel = on
	_panel_toggle.set_pressed_no_signal(on)
	_control_bar.visible = on
	_save_settings()
	_fit_camera_later()


func _set_wire_numbers(on: bool) -> void:
	_wire_numbers = on
	_numbers_toggle.set_pressed_no_signal(on)
	view.set_wire_numbers_visible(on)
	_save_settings()


func _update_mode_ui() -> void:
	var editing: bool = mode == Mode.EDIT
	view.set_grid_visible(editing and _edit_grid)
	view.set_wire_numbers_visible(_wire_numbers)
	_edit_tools.visible = editing
	_palette_bar.visible = editing
	_side_bar.visible = editing
	_control_bar.visible = _show_control_panel
	_sim_tools.visible = not editing
	_time_label.visible = not editing
	_timing_panel.show_parts(_show_chart, _show_log)
	if editing:
		_timing_panel.visible = false
	_update_run_button()
	_refresh_pages()
	_on_stepped(view.last_result)


func _update_run_button() -> void:
	_run_button.text = tr("Pause") if view.running else tr("Run")
	_run_button.icon = AppTheme.icon("pause" if view.running else "play")
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
	_fit_camera_later()


## Fits the view once the panels have their new sizes (after this frame).
func _fit_camera_later() -> void:
	await get_tree().process_frame
	_fit_camera()


## (Re)starts the simulation on a fresh copy of the edited schematic.
func _on_timing_parts_toggled() -> void:
	_show_chart = _chart_button.button_pressed
	_show_log = _log_button.button_pressed
	_update_mode_ui()
	_save_settings()
	_fit_camera_later()


func _start_simulation() -> void:
	view.load_document(DocumentSerializer.from_dict(DocumentSerializer.to_dict(edit_doc)), true)
	view.running = true
	_timing_panel.chart.set_document(view.document, view.trace)
	_timing_panel.event_log.clear()
	_update_run_button()


func _on_switching_selected(index: int) -> void:
	var realistic: bool = index == 0
	if edit_doc.realistic_timing == realistic:
		return
	editor.history.record(DocumentSerializer.to_dict(edit_doc))
	edit_doc.realistic_timing = realistic
	if view.document != edit_doc:
		view.set_realistic_timing(realistic)
	_mark_dirty()


func _show_document(doc: SchematicDocument, fit: bool) -> void:
	edit_doc = doc
	if mode == Mode.SIMULATE:
		_start_simulation()
	else:
		view.load_document(edit_doc, false)
	_layout_select.select(1 if doc.horizontal else 0)
	_switching_select.select(0 if doc.realistic_timing else 1)
	_check_panel.hide()
	_refresh_pages()
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
	if not ids.is_empty() and edit_doc.circuit.get_component(ids[0]) != null and edit_doc.page_of(ids[0]) != edit_doc.page:
		_show_page(edit_doc.page_of(ids[0]))
	editor._clear_selection()
	for id: String in ids:
		editor.selected_components[id] = true
	editor._selection_updated()
	if not ids.is_empty():
		var body: Rect2 = edit_doc.component_body(edit_doc.circuit.get_component(ids[0]))
		camera.look_at_world(body.get_center() * SymbolGeometry.GRID, _canvas_area.get_global_rect())


## Properties of the one selected component, or the number of the one
## selected wire.
func _on_selection_changed(c: CircuitComponent) -> void:
	if c == null and editor.selected_components.is_empty() and editor.selected_wires.size() == 1:
		_properties.show_wire()
	else:
		_properties.show_component(c)


func _single_selected() -> CircuitComponent:
	if editor == null or edit_doc == null or editor.selected_components.size() != 1:
		return null
	return edit_doc.circuit.get_component(editor.selected_components.keys()[0])


func _on_run_pressed() -> void:
	view.running = not view.running
	_update_run_button()


func set_language(index: int) -> void:
	_locale_index = index
	TranslationServer.set_locale(LOCALES[index])
	_retranslate()
	_save_settings()


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
			_show_file_dialog(DialogPurpose.EXPORT_PNG)
		FileMenuId.EXPORT_PDF:
			_show_file_dialog(DialogPurpose.EXPORT_PDF)
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
		DialogPurpose.EXPORT_PNG, DialogPurpose.EXPORT_PDF:
			var pdf: bool = purpose == DialogPurpose.EXPORT_PDF
			_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			_file_dialog.title = tr("Export PDF") if pdf else tr("Export PNG")
			_file_dialog.filters = PackedStringArray(["*.pdf ; PDF"] if pdf else ["*.png ; PNG"])
			var base: String = _file_path.get_file().get_basename() if not _file_path.is_empty() else tr("schematic")
			if not pdf and edit_doc.pages.size() > 1:
				base += "-%d" % (edit_doc.page + 1)
			_file_dialog.current_file = base + (".pdf" if pdf else ".png")
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
		DialogPurpose.EXPORT_PNG:
			if path.get_extension().to_lower() != "png":
				path += ".png"
			export_png(path)
		DialogPurpose.EXPORT_PDF:
			if path.get_extension().to_lower() != "pdf":
				path += ".pdf"
			export_pdf(path)


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


## Saves the page shown as a PNG image: the drawing at rest on white paper,
## on a sheet with a frame and title block (see [SheetRenderer]).
func export_png(path: String) -> void:
	_prepare_export()
	var images: Array[Image] = await _sheet_renderer.render(edit_doc, PackedInt32Array([edit_doc.page]))
	if images.is_empty() or images[0] == null or images[0].save_png(path) != OK:
		_show_error(tr("Could not save %s.") % path.get_file())


## Saves every page as one page of a PDF document.
func export_pdf(path: String) -> void:
	_prepare_export()
	var pages: PackedInt32Array = PackedInt32Array()
	for i: int in edit_doc.pages.size():
		pages.append(i)
	var images: Array[Image] = await _sheet_renderer.render(edit_doc, pages)
	var pdf: PdfWriter = PdfWriter.new()
	pdf.title = tr(edit_doc.title)
	for i: int in images.size():
		if images[i] == null:
			_show_error(tr("Could not save %s.") % path.get_file())
			return
		pdf.add_page(images[i], _sheet_renderer.layouts[i].paper_points())
	if pdf.save(path) != OK:
		_show_error(tr("Could not save %s.") % path.get_file())


## Texts of the title block and what to draw, as chosen in the window.
func _prepare_export() -> void:
	_sheet_renderer.wire_numbers = _wire_numbers
	_sheet_renderer.file_name = _file_path.get_file()
	_sheet_renderer.title = tr(edit_doc.title)
	_sheet_renderer.untitled_page = tr("Page %d")
	_sheet_renderer.page_caption = tr("Page")


# --- Pages ------------------------------------------------------------------------

## Fills the page tabs from the document shown.
func _refresh_pages() -> void:
	if _page_tabs == null or view.document == null:
		return
	var doc: SchematicDocument = view.document
	_updating_pages = true
	_page_tabs.tab_count = doc.pages.size()
	for i: int in doc.pages.size():
		var title: String = tr("Page %d") % (i + 1) if doc.pages[i].is_empty() else "%d  %s" % [i + 1, tr(doc.pages[i])]
		_page_tabs.set_tab_title(i, title)
	_page_tabs.current_tab = doc.page
	_page_tabs.drag_to_rearrange_enabled = mode == Mode.EDIT
	_page_add.visible = mode == Mode.EDIT
	_updating_pages = false
	_fit_page_tabs()


## The tabs take only the room they need, so the add button follows the
## last one; when they do not fit, they share the bar and are clipped.
func _fit_page_tabs() -> void:
	if _page_tabs == null or _page_row == null:
		return
	_page_tabs.clip_tabs = false
	var room: float = _page_row.size.x - (_page_add.size.x + 8.0 if _page_add.visible else 0.0)
	var fits: bool = _page_tabs.get_combined_minimum_size().x <= room
	_page_tabs.clip_tabs = not fits
	_page_tabs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if fits else Control.SIZE_EXPAND_FILL
	# The filler after the add button only takes the room the tabs leave.
	(_page_row.get_child(_page_row.get_child_count() - 1) as Control).visible = fits


## Shows page [param index]; with [param focus_id], centred on that component.
func _show_page(index: int, focus_id: String = "") -> void:
	if index < 0 or index >= edit_doc.pages.size():
		return
	editor.leave_page()
	edit_doc.page = index
	view.show_page(index)
	_refresh_pages()
	var focus: CircuitComponent = view.document.circuit.get_component(focus_id) if not focus_id.is_empty() else null
	if focus != null:
		camera.look_at_world(view.document.component_body(focus).get_center() * SymbolGeometry.GRID, _canvas_area.get_global_rect())
	else:
		_fit_camera()


## Adds a page titled [param title] after the last one and shows it (undoable).
func _add_page(title: String) -> void:
	editor.edit_pages(func(doc: SchematicDocument) -> void: doc.page = doc.add_page(title))
	_fit_camera()


func _open_page_menu(tab: int) -> void:
	if mode != Mode.EDIT:
		return
	_menu_page = tab
	_page_menu.clear()
	_page_menu.add_item(tr("Rename…"), PageMenuId.RENAME)
	_page_menu.add_item(tr("Move left"), PageMenuId.MOVE_LEFT)
	_page_menu.set_item_disabled(_page_menu.item_count - 1, tab == 0)
	_page_menu.add_item(tr("Move right"), PageMenuId.MOVE_RIGHT)
	_page_menu.set_item_disabled(_page_menu.item_count - 1, tab == edit_doc.pages.size() - 1)
	_page_menu.add_separator()
	_page_menu.add_item(tr("Delete page"), PageMenuId.DELETE)
	_page_menu.set_item_disabled(_page_menu.item_count - 1, edit_doc.pages.size() <= 1)
	_page_menu.set_item_tooltip(_page_menu.item_count - 1, tr("Removes the page with everything drawn on it (Ctrl+Z brings it back)"))
	_page_menu.reset_size()
	_page_menu.popup_on_parent(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i.ZERO))


func _on_page_menu(id: int) -> void:
	var index: int = _menu_page
	match id:
		PageMenuId.RENAME:
			_show_rename_dialog(index)
		PageMenuId.MOVE_LEFT, PageMenuId.MOVE_RIGHT:
			var to: int = index + (-1 if id == PageMenuId.MOVE_LEFT else 1)
			editor.edit_pages(func(doc: SchematicDocument) -> void: doc.move_page(index, to))
		PageMenuId.DELETE:
			editor.edit_pages(func(doc: SchematicDocument) -> void: doc.remove_page(index))
			_fit_camera()


## Title of page [param index] as shown ("" when untitled).
func _page_title(index: int) -> String:
	return tr(edit_doc.pages[index]) if not edit_doc.pages[index].is_empty() else ""


func _show_rename_dialog(index: int) -> void:
	_menu_page = index
	_rename_dialog.dialog_text = tr("Title of page %d:") % (index + 1)
	_rename_field.text = _page_title(index)
	_rename_dialog.popup_centered()
	_rename_field.grab_focus()
	_rename_field.select_all()


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
		_show_chart = config.get_value("view", "timing_chart", true)
		_show_log = config.get_value("view", "event_log", true)
		_theme_variant = AppTheme.Variant.LIGHT if config.get_value("view", "theme", "dark") == "light" else AppTheme.Variant.DARK
		_white_paper = bool(config.get_value("view", "white_paper", false))
		_edit_grid = bool(config.get_value("view", "grid", false))
		_wire_numbers = bool(config.get_value("view", "wire_numbers", true))
		_show_control_panel = bool(config.get_value("view", "control_panel", true))
		_timing_size = Vector2(float(config.get_value("view", "event_log_width", 340.0)), float(config.get_value("view", "timing_height", 220.0)))
		for key: String in ["palette", "properties", "control_panel"]:
			_bar_settings[key] = Vector2(float(config.get_value("view", key + "_width", 250.0)), float(config.get_value("view", key + "_zoom", 1.0)))
		_ui_scale = float(config.get_value("view", "ui_scale", 0.0))
		_locale_index = maxi(LOCALES.find(str(config.get_value("view", "language", "en"))), 0)


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("files", "recent", _recent)
	config.set_value("view", "timing_chart", _show_chart)
	config.set_value("view", "event_log", _show_log)
	config.set_value("view", "theme", "light" if _theme_variant == AppTheme.Variant.LIGHT else "dark")
	config.set_value("view", "ui_scale", _ui_scale)
	config.set_value("view", "white_paper", _white_paper)
	config.set_value("view", "grid", _edit_grid)
	config.set_value("view", "wire_numbers", _wire_numbers)
	config.set_value("view", "control_panel", _show_control_panel)
	if _timing_panel != null:
		config.set_value("view", "timing_height", _timing_panel.panel_height)
		config.set_value("view", "event_log_width", _timing_panel.log_width)
	for bar: SideBar in [_palette_bar, _side_bar, _control_bar]:
		if bar != null:
			config.set_value("view", bar.name + "_width", bar.width)
			config.set_value("view", bar.name + "_zoom", bar.zoom)
	config.set_value("view", "language", LOCALES[_locale_index])
	config.save(SETTINGS_PATH)


# --- Status -----------------------------------------------------------------------

## Status text for the first blown fuse, tripped breaker or overload relay.
func _tripped_protection() -> String:
	if view.document == null:
		return ""
	for c: CircuitComponent in view.document.circuit.get_components():
		if c is Fuse and (c as Fuse).tripped:
			return tr("%s blown – click it to replace the fuse") % c.designation
		if c is ThreePoleFuse and (c as ThreePoleFuse).any_blown():
			return tr("%s blown – click it to replace the fuse") % c.designation
		if (c is CircuitBreaker and (c as CircuitBreaker).tripped) or (c is MotorBreaker and (c as MotorBreaker).tripped):
			return tr("%s tripped – click it to switch it on again") % c.designation
		if c is OverloadRelay and (c as OverloadRelay).tripped:
			return tr("%s tripped by overload – click it to reset") % c.designation
	return ""


## Motors that lost a phase or are wrongly connected, for the status line.
func _motor_trouble() -> String:
	if view.document == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for c: CircuitComponent in view.document.circuit.get_components():
		if c is ThreePhaseMotor:
			match (c as ThreePhaseMotor).state:
				ThreePhaseMotor.State.PHASE_LOSS:
					parts.append(tr("%s: phase loss – the motor hums and overheats") % c.designation)
				ThreePhaseMotor.State.MISWIRED:
					parts.append(tr("%s: windings wrongly connected") % c.designation)
	return ", ".join(parts)


func _on_editor_hint(text: String) -> void:
	_editor_hint = text
	if mode == Mode.EDIT and _status_label != null:
		_status_label.text = text


func _on_stepped(result: StepResult) -> void:
	if _time_label == null:
		return
	_short_banner.visible = mode == Mode.SIMULATE and result.short_circuit
	if _short_banner.visible:
		_short_banner.text = tr("NO FUSE and SHORT CIRCUIT!")
	if mode == Mode.EDIT:
		_status_label.text = _editor_hint
		_status_label.remove_theme_color_override("font_color")
		_hint_label.text = tr("Right or middle drag pans, wheel zooms.")
		return
	_hint_label.text = tr("Click buttons and switches to operate them. Right or middle drag pans, wheel zooms.")
	_time_label.text = "%.3f s" % view.sim_time
	_timing_panel.chart.set_time(view.sim_time)
	_timing_panel.event_log.add_events(result.events)
	var tripped: String = _tripped_protection()
	if result.short_circuit:
		_status_label.text = tr("NO FUSE and SHORT CIRCUIT! %s") % " → ".join(result.short_circuit_path)
		_status_label.add_theme_color_override("font_color", SchematicTheme.FAULT)
	elif not tripped.is_empty():
		_status_label.text = tripped
		_status_label.add_theme_color_override("font_color", SchematicTheme.WARNING)
	elif not _motor_trouble().is_empty():
		_status_label.text = _motor_trouble()
		_status_label.add_theme_color_override("font_color", SchematicTheme.FAULT)
	elif not result.chatter_hz.is_empty():
		var parts: PackedStringArray = PackedStringArray()
		for designation: String in result.chatter_hz:
			parts.append(tr("%s is chattering (about %d Hz)") % [designation, roundi(result.chatter_hz[designation])])
		_status_label.text = ", ".join(parts)
		_status_label.add_theme_color_override("font_color", SchematicTheme.WARNING)
	elif result.is_oscillating():
		_status_label.text = tr("Oscillation: %s keeps switching on and off") % ", ".join(result.oscillating_tags)
		_status_label.add_theme_color_override("font_color", SchematicTheme.WARNING)
	else:
		_status_label.text = tr("Running") if view.running else tr("Paused")
		_status_label.remove_theme_color_override("font_color")
