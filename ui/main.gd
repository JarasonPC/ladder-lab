extends Node
## Main window: toolbar, palette, schematic view, properties, check results and
## status bar, or the workspace with its switchboards and control stations
## (Schematic | Workspace). Edit mode edits the schematic; Simulate mode runs
## a copy of it, so the simulation never changes the design.
## All user-facing text is English source text passed through tr().

enum Mode { EDIT, SIMULATE }
## What the window shows: the schematic or the workspace.
enum Area { SCHEMATIC, WORKSPACE }
enum FileMenuId { NEW, OPEN, SAVE, SAVE_AS, EXPORT_PNG, EXPORT_PDF, TITLE_BLOCK, QUIT, ASSOCIATE, EXPORT_CSV }
enum ViewMenuId { FULLSCREEN, THEME_DARK, THEME_LIGHT, WHITE_PAPER, GRID, WIRE_NUMBERS, PATH_NUMBERS, VOLTAGE_VIEW, CURRENT_VIEW, DUCT_COVERS, SCALE = 20 }
enum SettingsMenuId { WIRE_POLES, WIRE_ON_DROP, CABLES_CZECH, CABLES_HARMONISED, LANGUAGE = 10 }
enum DialogPurpose { OPEN, SAVE, EXPORT_PNG, EXPORT_PDF, EXPORT_CSV }
enum PageMenuId { RENAME, MOVE_LEFT, MOVE_RIGHT, DELETE, WINDOW }
enum HelpMenuId { CHECK_UPDATES, CHECK_AT_START, WEBSITE, REPORT, ABOUT, DATASHEETS, TOUR }
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
## Width of the lesson panel until one is chosen.
const LESSON_WIDTH: float = 330.0
## Width of the control panel until one is chosen (a station of two columns).
const CONTROL_PANEL_WIDTH: float = 320.0

var mode: Mode = Mode.EDIT
var area: Area = Area.SCHEMATIC
## The schematic being designed (the simulation runs on a copy).
var edit_doc: SchematicDocument
var view: SchematicView
var camera: SchematicCamera
var editor: SchematicEditor

## File of the edited schematic, "" when it was never saved.
var _file_path: String = ""
var _dirty: bool = false
var _recent: PackedStringArray = PackedStringArray()
var _dialog_purpose: DialogPurpose = DialogPurpose.OPEN
## Runs after a successful save started from the unsaved-changes prompt.
var _after_save: Callable = Callable()
## Runs when the user chose to continue in the unsaved-changes prompt.
var _after_discard: Callable = Callable()

var _file_menu: MenuButton
var _recent_menu: PopupMenu
var _view_menu: MenuButton
var _settings_menu: MenuButton
var _help_menu: MenuButton
## Shown in the toolbar when a newer version is released; opens its page.
var _update_button: Button
var _update_checker: UpdateChecker
## Look for a newer version at every start (remembered).
var _check_updates: bool = true
## Windows opens .ladder files with this LadderLab (remembered; exported
## Windows builds only).
var _associate_files: bool = true
## Newer release found ({"version", "url", "notes"}), or {}.
var _new_release: Dictionary = {}
## The running check was asked for in the Help menu, so its result is shown.
var _manual_update_check: bool = false
var _update_dialog: ConfirmationDialog
## The update dialog offers the new version: its OK opens the release page.
var _offering_download: bool = false
var _about_dialog: AboutDialog
var _edit_button: Button
var _simulate_button: Button
var _schematic_button: Button
var _workspace_button: Button
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
## The simulation's speed, switching, view and clamp: a group of its own, so
## the toolbar can wrap between it and the run controls in a narrow window.
var _sim_options: HBoxContainer
var _switching_select: OptionButton
var _timing_panel: TimingPanel
var _key_strip: KeyStrip
var _run_button: Button
var _step_button: Button
var _speed_select: OptionButton
var _view_select: OptionButton
var _clamp_toggle: Button
var _reset_button: Button
var _time_label: Label
var _palette: Palette
var _side: VBoxContainer
## Resizable and zoomable side panels: palette (left), properties with the
## check results (right), the tree of the workspace (left).
var _palette_bar: SideBar
var _side_bar: SideBar
var _tree_bar: SideBar
## Width and zoom of each side panel by its settings name, as loaded.
var _bar_settings: Dictionary[String, Vector2] = {}
## Event log width and timing panel height, as loaded.
var _timing_size: Vector2 = Vector2(340.0, 220.0)
## Rows of the timing chart not shown (see [member TimingChart.hidden_rows]).
var _timing_hidden: Dictionary[String, bool] = {}
## Part of the window where the schematic is visible (between the panels).
var _canvas_area: Control
## Tabs of the pages above the schematic, and the button adding a page.
var _page_tabs: TabBar
var _page_add: MenuButton
var _page_row: HBoxContainer
var _page_bar: Control
## Right click menu of a page tab, for page [member _menu_page].
var _page_menu: PopupMenu
var _menu_page: int = -1
var _rename_dialog: ConfirmationDialog
var _rename_field: LineEdit
## Title block texts of the exported sheets: the schematic title ("title")
## and the [constant TitleBlock.FIELDS], each with its label.
var _title_block_dialog: ConfirmationDialog
var _title_block_edits: Dictionary[String, LineEdit] = {}
var _title_block_labels: Dictionary[String, Label] = {}
## True while the tabs are being filled (their signals are ignored).
var _updating_pages: bool = false
## Renders the pages for PNG and PDF export.
var _sheet_renderer: SheetRenderer
## Shows the sheets before they are exported; what it shows is saved.
var _export_preview: ExportPreview
## What a PDF export holds (see [method ExportPreview.contents]), remembered.
var _export_contents: Dictionary[String, bool] = {"schematic": true, "stations": true, "switchboards": true, "plc_programs": true, "timers": true, "workspace": true, "parts_list": true}
var _export_pdf: bool = false
## Largest paper of the exported sheets (user settings, "export"/"largest_paper").
var _export_paper: String = SheetLayout.DEFAULT_LARGEST
var _export_images: Array[Image] = []
var _export_layouts: Array[SheetLayout] = []
## Counts preview renderings, so only the latest one is shown.
var _export_render: int = 0
## Big red warning over the schematic during an unprotected short circuit.
var _short_banner: Label
var _properties: PropertiesPanel
var _datasheet_window: DatasheetWindow = null
## Switchboards, control stations and parts in the field (both modes).
var _workspace: WorkspaceView
## The floor plan of a house installation, shown in place of the workspace.
var _floor_plan: FloorPlanView
## The single-line diagram of a residential installation, in place of the schematic.
var _single_line: SingleLineView
## The next document shown fits the whole workspace into view (a new schematic).
var _workspace_fit: bool = true
## Asks for the key of a push button or switch.
var _key_prompt: KeyPrompt
## Push buttons held down by their keys.
var _keys_down: Dictionary[String, bool] = {}
var _check_panel: CheckPanel
var _status_label: Label
var _hint_label: Label
var _editor_hint: String = ""
## Timing chart and event log rolled out in Simulate mode (remembered).
var _show_chart: bool = false
var _show_log: bool = false
## The key strip shows only its title.
var _keys_rolled: bool = false
var _theme_variant: AppTheme.Variant = AppTheme.Variant.DARK
## Keep the schematic on white paper in the dark theme.
var _white_paper: bool = false
## Dot grid while editing (never while simulating).
var _edit_grid: bool = false
var _wire_numbers: bool = true
## Current path numbers shown (above the columns or left of the rows).
var _path_numbers: bool = true
## The palette shows a grid of symbols instead of the list.
var _palette_grid: bool = false
## Simulation shown as currents (current view) instead of voltages.
var _current_view: bool = false
## Chosen interface size (see UI_SCALES), 0 = automatic.
var _ui_scale: float = 0.0
var _locale_index: int = 0
var _file_dialog: FileDialog
var _unsaved_dialog: ConfirmationDialog
var _discard_button: Button
var _error_dialog: AcceptDialog
## Offers back the unsaved changes of a LadderLab that did not close properly
## (see [RecoveryFile]).
var _recovery_dialog: ConfirmationDialog
var _recovery_discard_button: Button
## The recovery file offered in [member _recovery_dialog].
var _recovery_path: String = ""
## Schematic | Workspace and Edit | Simulate (the tour points at them).
var _area_switch: Control
## What the schematic is: an industrial control circuit or a house installation.
var _environment_label: Label
var _new_dialog: NewSchematicDialog
var _mode_switch: Control
## The lesson being taken (see [LessonRun]), or null; its index in
## [method Lessons.all].
var _lesson_run: LessonRun = null
var _lesson_index: int = -1
var _lesson_panel: LessonPanel
var _lesson_bar: SideBar
## The control stations and switchboard doors beside the schematic of an
## industrial control circuit while simulating, and the tab they roll in to.
var _control_panel: ControlPanelView
var _control_bar: SideBar
var _control_tab: SideTab
## The control panel shows only its tab (remembered).
var _control_rolled: bool = false
## What the lesson points at on the drawing, and in the window.
var _lesson_marks: LessonMarks
var _lesson_rings: TutorialRings
## The step whose palette entry was last scrolled into view.
var _revealed_step: int = -1
## A lesson's start schematic is being put in place (the lesson stays).
var _starting_lesson: bool = false
## Ids of the lessons whose goals were all met (remembered).
var _finished_lessons: Dictionary[String, bool] = {}
## Lessons submenu of the Help menu.
var _lessons_menu: PopupMenu
var _tour: TourOverlay
## Mode and area to go back to when the tour ends.
var _tour_mode: Mode = Mode.EDIT
var _tour_area: Area = Area.SCHEMATIC
## Offered on the first start: the tour or the first lesson.
var _welcome: WelcomeCard
## The welcome card was answered (remembered).
var _welcomed: bool = false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	view = SchematicView.new()
	add_child(view)
	editor = SchematicEditor.new()
	editor.view = view
	add_child(editor)
	_lesson_marks = LessonMarks.new()
	_lesson_marks.view = view
	_lesson_marks.editor = editor
	add_child(_lesson_marks)
	camera = SchematicCamera.new()
	add_child(camera)
	camera.make_current()
	_load_settings()
	_apply_ui_scale()
	_apply_theme()
	TranslationServer.set_locale(LOCALES[_locale_index])
	if _associate_files:
		FileAssociation.register(tr("LadderLab schematic"))
	_build_ui()
	_build_dialogs()
	_update_checker = UpdateChecker.new()
	_update_checker.checked.connect(_on_update_checked)
	add_child(_update_checker)
	if _check_updates:
		_update_checker.check()
	_sheet_renderer = SheetRenderer.new()
	add_child(_sheet_renderer)
	view.stepped.connect(_on_stepped)
	# Logged once per step here: _on_stepped also runs to show the status again.
	view.stepped.connect(func(result: StepResult) -> void: _timing_panel.event_log.add_events(result.events))
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
	_palette.template_chosen.connect(func(t: Dictionary) -> void:
		if _single_line_shown():
			_single_line.begin_place(t)
		elif area == Area.WORKSPACE:
			_floor_plan.begin_place_template(t)
		else:
			editor.begin_place(t))
	_check_panel.issue_selected.connect(_on_issue_selected)
	view.loaded.connect(_on_view_loaded)
	editor.edited.connect(_workspace.refresh)
	view.stepped.connect(_workspace.show_step)
	view.stepped.connect(func(_result: StepResult) -> void: _workspace.show_travels(view.travel_positions()))
	_workspace.edit_requested.connect(_edit_workspace)
	_workspace.cabinet_edit_requested.connect(_edit_cabinet)
	_workspace.button_held.connect(view.hold_button)
	_workspace.switch_toggled.connect(view.toggle_switch)
	_control_panel.button_held.connect(view.hold_button)
	_control_panel.switch_toggled.connect(view.toggle_switch)
	_workspace.operate_requested.connect(view.operate_device)
	_workspace.window_requested.connect(open_place_window)
	_workspace.schematic_requested.connect(_show_in_schematic)
	_workspace.key_bind_requested.connect(_ask_key)
	editor.edited.connect(_floor_plan.refresh)
	view.stepped.connect(_floor_plan.show_step)
	_floor_plan.edit_requested.connect(_edit_workspace)
	_floor_plan.switch_toggled.connect(view.toggle_light_switch)
	_floor_plan.cabinet_edit_requested.connect(_edit_cabinet)
	_floor_plan.operate_requested.connect(view.operate_device)
	# The floor shown is the same in the schematic edited and the one simulated.
	_floor_plan.floor_changed.connect(func(index: int) -> void:
		edit_doc.floor = index
		if view.document != null:
			view.document.floor = index)
	editor.edited.connect(_single_line.refresh)
	view.stepped.connect(_single_line.show_step)
	_single_line.edit_requested.connect(_edit_workspace)
	_single_line.operate_requested.connect(view.operate_device)
	_single_line.switch_toggled.connect(view.toggle_switch)
	_single_line.test_requested.connect(view.press_test)
	_single_line.selection_changed.connect(_on_single_line_selected)
	_single_line.room_requested.connect(_show_room)
	editor.key_bind_requested.connect(_ask_key)
	editor.edited.connect(func() -> void:
		for window: PlaceWindow in _place_windows():
			window.refresh())
	view.stepped.connect(func(result: StepResult) -> void:
		for window: PlaceWindow in _place_windows():
			window.show_step(result))
	editor.plc_requested.connect(open_plc_window)
	view.plc_requested.connect(open_plc_window)
	_properties.plc_requested.connect(open_plc_window)
	editor.datasheet_requested.connect(open_datasheet)
	_properties.datasheet_requested.connect(open_datasheet)
	view.loaded.connect(_rebind_plc_windows)
	editor.edited.connect(_rebind_plc_windows)
	view.stepped.connect(func(_result: StepResult) -> void:
		for window: PlcWindow in _plc_windows():
			window.show_step())
	editor.edited.connect(_on_lesson_edited)
	view.stepped.connect(_on_lesson_stepped)
	view.rebuilt.connect(_refresh_lesson_marks)
	editor.active = true
	_start_blank()
	# A schematic double-clicked in the file manager comes as an argument.
	var start_file: String = FileAssociation.file_from_args(OS.get_cmdline_args())
	if not start_file.is_empty():
		open_file(start_file)
	# Marked alive while running, so another LadderLab started meanwhile does
	# not offer this one's unsaved changes.
	RecoveryFile.beat()
	var heartbeat: Timer = Timer.new()
	heartbeat.wait_time = RecoveryFile.BEAT
	heartbeat.autostart = true
	heartbeat.timeout.connect(func() -> void: RecoveryFile.beat())
	add_child(heartbeat)
	_offer_recovery()
	if not _welcomed:
		_welcome.show()


func _process(_delta: float) -> void:
	_undo_button.disabled = not editor.history.can_undo()
	_redo_button.disabled = not editor.history.can_redo()
	var has_selection: bool = not editor.selected_components.is_empty()
	_rotate_button.disabled = not has_selection and editor.tool != SchematicEditor.Tool.PLACE
	_mirror_button.disabled = _rotate_button.disabled
	_flip_button.disabled = _rotate_button.disabled
	_delete_button.disabled = not has_selection and editor.selected_wires.is_empty()
	_update_side_bar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_confirm_discard(_quit)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# A key let go elsewhere never comes back: let its buttons go now.
		_release_bound_keys()


## Space runs or pauses the simulation and bound keys operate their buttons
## and switches, unless a text field is being typed in (taken before the
## controls, so a focused list or button does not eat them).
func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null:
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	# A key let go while typing still lets its button go.
	if (focus is LineEdit or focus is TextEdit) and key.pressed:
		return
	if _bound_key(key):
		get_viewport().set_input_as_handled()
		return
	if not key.pressed or key.echo or key.keycode != KEY_SPACE:
		return
	if _toggle_run_key(key):
		get_viewport().set_input_as_handled()


## While simulating, a key bound to a push button holds it down while the key
## is down; one bound to a switch turns it over. Returns true when the key is bound.
func _bound_key(key: InputEventKey) -> bool:
	if mode != Mode.SIMULATE or view.document == null:
		return false
	var designation: String = view.document.device_of_key(OS.get_keycode_string(key.keycode))
	if designation.is_empty():
		return false
	if not key.pressed:
		# Let go whatever modifiers went down meanwhile, or the button stays held.
		if _keys_down.erase(designation):
			view.hold_button(designation, false)
		return true
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return false
	if key.echo:
		return true
	var device: CircuitComponent = view.document.circuit.get_operator(designation)
	if device is PushButton:
		_keys_down[designation] = true
		view.hold_button(designation, true)
	elif device is LatchingSwitch or device is CamSwitch:
		view.toggle_switch(designation)
	return true


func _release_bound_keys() -> void:
	for designation: String in _keys_down.keys():
		view.hold_button(designation, false)
	_keys_down.clear()


func _unhandled_input(event: InputEvent) -> void:
	if _shortcut(event):
		get_viewport().set_input_as_handled()


## A key pressed in a page window: the same shortcuts as here.
func _on_window_key(key: InputEventKey) -> void:
	if _bound_key(key) or not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE:
		_toggle_run_key(key)
	else:
		_shortcut(key)


## Space alone, while simulating: run or pause. Returns true when it did.
func _toggle_run_key(key: InputEventKey) -> bool:
	if mode != Mode.SIMULATE or key.ctrl_pressed or key.meta_pressed or key.alt_pressed or key.shift_pressed:
		return false
	_on_run_pressed()
	return true


## Keyboard shortcuts of the window. Returns true when [param event] was one.
func _shortcut(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return false
	var key: InputEventKey = event as InputEventKey
	var ctrl: bool = key.ctrl_pressed or key.meta_pressed
	var handled: bool = true
	match key.keycode:
		KEY_F11:
			_toggle_fullscreen()
		KEY_F1:
			var part: CircuitComponent = _single_selected() if mode == Mode.EDIT else null
			if part != null and not (part is Junction):
				open_datasheet(part.id)
			else:
				open_datasheets()
		KEY_S when ctrl and key.shift_pressed:
			_save_as()
		KEY_S when ctrl:
			_save()
		KEY_O when ctrl:
			_confirm_discard(_show_open_dialog)
		KEY_N when ctrl:
			_confirm_discard(_new_dialog.ask)
		KEY_Q when ctrl:
			_confirm_discard(_quit)
		# Undo and redo where the editor does not take the keys itself: the
		# floor plan, the workspace, the single-line diagram.
		KEY_Z when ctrl and mode == Mode.EDIT and not editor.active:
			if key.shift_pressed:
				editor.redo()
			else:
				editor.undo()
		KEY_Y when ctrl and mode == Mode.EDIT and not editor.active:
			editor.redo()
		_:
			handled = false
	return handled


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
	_settings_menu = _menu(bar)
	_settings_menu.get_popup().id_pressed.connect(_on_settings_menu)
	_settings_menu.about_to_popup.connect(_rebuild_settings_menu)
	_help_menu = _menu(bar)
	_help_menu.get_popup().id_pressed.connect(_on_help_menu)
	_help_menu.about_to_popup.connect(_rebuild_help_menu)
	# F1 is shown in the menu but handled by _shortcut, which opens the
	# selected part's datasheet (the menu would always open the list).
	_help_menu.set_disable_shortcuts(true)
	_update_button = _button(bar, func() -> void: OS.shell_open(_new_release.get("url", ReleaseCheck.RELEASES_PAGE)), "download")
	_update_button.theme_type_variation = "PrimaryButton"
	_update_button.visible = false
	bar.add_child(VSeparator.new())
	_environment_label = _label(bar)
	_environment_label.theme_type_variation = "MutedLabel"
	_environment_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_spacer(4))

	# Schematic | Workspace as one segmented switch.
	var area_track: PanelContainer = PanelContainer.new()
	area_track.theme_type_variation = "SegmentTrack"
	bar.add_child(area_track)
	_area_switch = area_track
	var area_segments: HBoxContainer = HBoxContainer.new()
	area_segments.add_theme_constant_override("separation", 2)
	area_track.add_child(area_segments)
	var area_group: ButtonGroup = ButtonGroup.new()
	_schematic_button = _button(area_segments, func() -> void: _set_area(Area.SCHEMATIC), "schematic")
	_workspace_button = _button(area_segments, func() -> void: _set_area(Area.WORKSPACE), "workspace")
	for b: Button in [_schematic_button, _workspace_button]:
		b.theme_type_variation = "SegmentButton"
		b.toggle_mode = true
		b.button_group = area_group
	_schematic_button.button_pressed = true
	bar.add_child(_spacer(4))

	# Edit | Simulate as one segmented switch.
	var track: PanelContainer = PanelContainer.new()
	track.theme_type_variation = "SegmentTrack"
	bar.add_child(track)
	_mode_switch = track
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

	_layout_select = _option(bar)
	_layout_select.add_item("")
	_layout_select.add_item("")
	_layout_select.item_selected.connect(_on_layout_selected)
	_numbers_toggle = _tool(bar, func() -> void: _set_wire_numbers(_numbers_toggle.button_pressed), "wire_numbers")
	_numbers_toggle.toggle_mode = true
	_numbers_toggle.button_pressed = _wire_numbers
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
	_sim_options = HBoxContainer.new()
	_sim_options.add_theme_constant_override("separation", 4)
	bar.add_child(_sim_options)
	_speed_select = _option(_sim_options)
	for s: float in SPEEDS:
		_speed_select.add_item("×%s" % str(s))
	_speed_select.select(SPEEDS.find(1.0))
	_speed_select.item_selected.connect(func(i: int) -> void: view.speed = SPEEDS[i])
	_switching_select = _option(_sim_options)
	_switching_select.add_item("")
	_switching_select.add_item("")
	_switching_select.item_selected.connect(_on_switching_selected)
	_view_select = _option(_sim_options)
	_view_select.add_item("")
	_view_select.add_item("")
	_view_select.item_selected.connect(func(i: int) -> void: _set_current_view(i == 1))
	_clamp_toggle = _tool(_sim_options, func() -> void:
		view.clamp_tool = _clamp_toggle.button_pressed
		for window: PageWindow in _page_windows():
			window.view.clamp_tool = _clamp_toggle.button_pressed, "clamp")
	_clamp_toggle.toggle_mode = true


	var middle: HBoxContainer = HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(middle)
	_palette = Palette.new()
	_palette.grid = _palette_grid
	_palette.grid_toggled.connect(func(on: bool) -> void:
		_palette_grid = on
		_save_settings())
	_palette_bar = _side_panel(middle, _palette, "palette", false)
	_workspace = WorkspaceView.new()
	_tree_bar = _side_panel(middle, _workspace.tree, "workspace_tree", false)
	var canvas_column: VBoxContainer = VBoxContainer.new()
	canvas_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_column.add_theme_constant_override("separation", 0)
	middle.add_child(canvas_column)
	_page_bar = _build_page_bar()
	canvas_column.add_child(_page_bar)
	_canvas_area = Control.new()
	_canvas_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_column.add_child(_canvas_area)
	_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas_area.add_child(_workspace)
	_floor_plan = FloorPlanView.new()
	_floor_plan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_floor_plan.visible = false
	_canvas_area.add_child(_floor_plan)
	_single_line = SingleLineView.new()
	_single_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_single_line.visible = false
	_canvas_area.add_child(_single_line)
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
	_lesson_panel = LessonPanel.new()
	_lesson_panel.finished = _finished_lessons
	_lesson_bar = _side_panel(middle, _lesson_panel, "lesson", true)
	_lesson_bar.hide()
	_lesson_panel.closed.connect(_close_lesson)
	_lesson_panel.lesson_chosen.connect(start_lesson)
	_lesson_panel.restart_requested.connect(func() -> void: start_lesson(_lesson_index))
	_lesson_panel.check_requested.connect(_check_lesson)
	_lesson_panel.marks_changed.connect(_refresh_lesson_marks)
	_control_panel = ControlPanelView.new()
	_control_bar = _side_panel(middle, _control_panel, "control_panel", true)
	_control_panel.roll_requested.connect(func() -> void: _set_control_rolled(true))
	_control_tab = SideTab.new()
	_control_tab.pressed.connect(func() -> void: _set_control_rolled(false))
	middle.add_child(_control_tab)
	_welcome = WelcomeCard.new()
	# The language first, before the tour or a lesson is offered in it.
	_welcome.languages = LOCALE_NAMES
	_welcome.language_chosen.connect(set_language)
	_welcome.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_welcome.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_welcome.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	_welcome.hide()
	_welcome.tour_chosen.connect(func() -> void:
		_answer_welcome()
		start_tour())
	_welcome.lesson_chosen.connect(func() -> void:
		_answer_welcome()
		start_lesson(0))
	_welcome.dismissed.connect(_answer_welcome)
	_canvas_area.add_child(_welcome)

	_timing_panel = TimingPanel.new()
	_timing_panel.panel_height = _timing_size.y
	_timing_panel.log_width = _timing_size.x
	_timing_panel.resized_by_user.connect(_save_settings)
	_timing_panel.rows_chosen.connect(_save_settings)
	_timing_panel.parts_toggled.connect(_on_timing_parts_toggled)
	_key_strip = KeyStrip.new()
	_key_strip.rolled = _keys_rolled
	_key_strip.rolled_changed.connect(func(rolled: bool) -> void:
		_keys_rolled = rolled
		_save_settings())
	root.add_child(_key_strip)
	root.add_child(_timing_panel)
	_timing_panel.chart.hidden_rows = _timing_hidden

	var bottom: PanelContainer = PanelContainer.new()
	bottom.theme_type_variation = "Statusbar"
	root.add_child(bottom)
	var status: HBoxContainer = HBoxContainer.new()
	status.add_theme_constant_override("separation", 12)
	bottom.add_child(status)
	_status_label = _label(status)
	_status_label.add_theme_font_size_override("font_size", AppTheme.SMALL_FONT_SIZE)
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	get_viewport().size_changed.connect(_fit_status_label)
	_hint_label = _label(status)
	_hint_label.theme_type_variation = "MutedLabel"
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.clip_text = true
	var rings_layer: CanvasLayer = CanvasLayer.new()
	rings_layer.layer = 2
	add_child(rings_layer)
	_lesson_rings = TutorialRings.new()
	rings_layer.add_child(_lesson_rings)
	var tour_layer: CanvasLayer = CanvasLayer.new()
	tour_layer.layer = 3
	add_child(tour_layer)
	_tour = TourOverlay.new()
	tour_layer.add_child(_tour)
	_tour.steps = _tour_steps()
	_tour.finished.connect(_on_tour_finished)
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
			_move_page(edit_doc.page, to))
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
	_export_preview = ExportPreview.new()
	_export_preview.confirmed.connect(func() -> void:
		_show_file_dialog(DialogPurpose.EXPORT_PDF if _export_pdf else DialogPurpose.EXPORT_PNG))
	_export_preview.wire_numbers_toggled.connect(func(_on: bool) -> void: _render_preview())
	_export_preview.contents_changed.connect(func() -> void:
		_export_contents = _export_preview.ticks()
		_save_settings()
		_render_preview())
	_export_preview.paper_changed.connect(func() -> void:
		_export_paper = _export_preview.largest_paper()
		_save_settings()
		_render_preview())
	add_child(_export_preview)
	_error_dialog = AcceptDialog.new()
	add_child(_error_dialog)
	_recovery_dialog = ConfirmationDialog.new()
	_recovery_discard_button = _recovery_dialog.add_button("", true, "discard")
	# A copy offered after another was restored replaces that one: ask first.
	_recovery_dialog.confirmed.connect(func() -> void: _confirm_discard(_restore_recovery))
	_recovery_dialog.custom_action.connect(func(_action: StringName) -> void:
		_recovery_dialog.hide()
		RecoveryFile.remove(_recovery_path)
		_offer_recovery())
	add_child(_recovery_dialog)
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
	_title_block_dialog = ConfirmationDialog.new()
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	for field: String in ["title"] + Array(TitleBlock.FIELDS):
		_title_block_labels[field] = _label(grid)
		var edit: LineEdit = LineEdit.new()
		edit.custom_minimum_size = Vector2(320, 0)
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(edit)
		_title_block_dialog.register_text_enter(edit)
		_title_block_edits[field] = edit
	_title_block_dialog.add_child(grid)
	_title_block_dialog.confirmed.connect(_apply_title_block)
	add_child(_title_block_dialog)
	_update_dialog = ConfirmationDialog.new()
	_update_dialog.dialog_autowrap = true
	_update_dialog.min_size = Vector2i(440, 0)
	_update_dialog.confirmed.connect(func() -> void:
		if _offering_download:
			OS.shell_open(_new_release["url"]))
	add_child(_update_dialog)
	_about_dialog = AboutDialog.new()
	add_child(_about_dialog)
	_new_dialog = NewSchematicDialog.new()
	_new_dialog.chosen.connect(_new_document)
	add_child(_new_dialog)
	_key_prompt = KeyPrompt.new()
	_key_prompt.chosen.connect(func(designation: String, key: String) -> void:
		# The same key again (or none taken off none) changes nothing.
		if key != edit_doc.key_bindings.get(designation, ""):
			editor.edit_workspace(func(doc: SchematicDocument) -> void: doc.set_key(designation, key)))
	add_child(_key_prompt)
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
	_settings_menu.text = tr("Settings")
	_help_menu.text = tr("Help")
	_update_new_release_button()
	_schematic_button.text = tr("Schematic")
	_schematic_button.tooltip_text = tr("The circuit diagram, page by page")
	_workspace_button.text = tr("Workspace")
	_workspace_button.tooltip_text = tr("Switchboards, control stations and the motors, limit switches and sensors in the field")
	_edit_button.text = tr("Edit")
	_simulate_button.text = tr("Simulate")
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
	_number_button.tooltip_text = tr("Number the wires: every net gets its own number, all wire ends of a net the same")
	_check_button.text = tr("Check")
	_check_button.tooltip_text = tr("Look for unconnected terminals, contacts without a coil and other mistakes")
	_switching_select.set_item_text(0, tr("Realistic"))
	_switching_select.set_item_text(1, tr("Ideal"))
	_switching_select.tooltip_text = tr("Realistic: relays need their pick-up and drop-out time, NC contacts break before NO contacts make. Ideal: relays switch instantly.")
	_run_button.tooltip_text = tr("Run or pause the simulation") + "  (" + tr("Space") + ")"
	_step_button.tooltip_text = tr("Step") + " – " + tr("Advance the simulation by 0.1 s times the speed")
	_speed_select.tooltip_text = tr("Simulation speed")
	_view_select.set_item_text(0, tr("Voltages"))
	_view_select.set_item_text(1, tr("Currents"))
	_clamp_toggle.tooltip_text = tr("Clamp meter: click a wire to clamp it and read its current, click it again to take the meter off")
	_view_select.tooltip_text = tr("Voltage view: wires coloured by the voltage that reaches them. Current view: only what carries current is coloured, the thicker the more, with the current written on each wire.")
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
	_page_tabs.tooltip_text = tr("Pages of the schematic: click to show one, drag to reorder, double-click to rename, right click for more (also: open a page in a new window)")
	_refresh_pages()
	_palette.retranslate()
	_update_environment()
	for bar: SideBar in [_palette_bar, _side_bar, _tree_bar, _lesson_bar, _control_bar]:
		bar.retranslate()
	_control_panel.retranslate()
	_control_tab.title = tr("Control panel")
	_control_tab.tooltip_text = tr("Control panel: the control stations and switchboard doors, to operate the circuit beside the schematic")
	_workspace.retranslate()
	_floor_plan.retranslate()
	_single_line.retranslate()
	for window: PlaceWindow in _place_windows():
		window.retranslate()
	for window: PlcWindow in _plc_windows():
		window.retranslate()
	for window: PageWindow in _page_windows():
		window.retranslate()
	if _datasheet_window != null:
		_datasheet_window.retranslate()
	_timing_panel.retranslate()
	_key_strip.retranslate()
	_lesson_panel.rebuild()
	_tour.retranslate()
	_welcome.retranslate()
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
	_recovery_dialog.title = tr("Recover unsaved changes")
	_recovery_dialog.ok_button_text = tr("Restore")
	_recovery_dialog.cancel_button_text = tr("Later")
	_recovery_discard_button.text = tr("Discard")
	_rename_dialog.title = tr("Rename page")
	_rename_dialog.ok_button_text = tr("Rename")
	_rename_dialog.cancel_button_text = tr("Cancel")
	_title_block_dialog.title = tr("Title block")
	_title_block_dialog.ok_button_text = tr("OK")
	_title_block_dialog.cancel_button_text = tr("Cancel")
	for field: String in _title_block_labels:
		_title_block_labels[field].text = _title_block_caption(field)
	_title_block_edits["date"].placeholder_text = tr("Date of the export")
	_update_dialog.title = tr("Updates")
	_about_dialog.retranslate()


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
	popup.add_item(tr("Export as PDF…"), FileMenuId.EXPORT_PDF)
	popup.add_item(tr("Export parts list as CSV…"), FileMenuId.EXPORT_CSV)
	popup.set_item_tooltip(popup.item_count - 1, tr("The parts list (and a house's boxes and cable metres) for a spreadsheet"))
	popup.add_item(tr("Title block…"), FileMenuId.TITLE_BLOCK)
	popup.set_item_tooltip(popup.item_count - 1, tr("Texts of the title block on exported sheets: drawn by, checked by, company, ..."))
	if FileAssociation.available():
		popup.add_separator()
		popup.add_check_item(tr("Open .ladder files with LadderLab"), FileMenuId.ASSOCIATE)
		popup.set_item_checked(popup.item_count - 1, _associate_files)
		popup.set_item_tooltip(popup.item_count - 1, tr("A double-click on a .ladder file in Explorer opens it in this LadderLab (registered for your Windows user only); turning it off removes the registration"))
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
	popup.add_check_item(tr("Current path numbers"), ViewMenuId.PATH_NUMBERS)
	popup.set_item_checked(popup.item_count - 1, _path_numbers)
	popup.set_item_tooltip(popup.item_count - 1, tr("Number the current paths above the columns (left of the rows), also on export"))
	popup.add_check_item(tr("Grid while editing"), ViewMenuId.GRID)
	popup.set_item_checked(popup.item_count - 1, _edit_grid)
	popup.add_check_item(tr("Wire duct covers"), ViewMenuId.DUCT_COVERS)
	popup.set_item_checked(popup.item_count - 1, CabinetView.duct_covers)
	popup.set_item_tooltip(popup.item_count - 1, tr("Draw the wire ducts in the switchboards with their covers on, hiding the wires in them (the export shows them open)"))
	popup.add_separator(tr("Simulation"))
	popup.add_radio_check_item(tr("Voltage view"), ViewMenuId.VOLTAGE_VIEW)
	popup.set_item_checked(popup.item_count - 1, not _current_view)
	popup.add_radio_check_item(tr("Current view"), ViewMenuId.CURRENT_VIEW)
	popup.set_item_checked(popup.item_count - 1, _current_view)
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
	elif id == ViewMenuId.PATH_NUMBERS:
		_set_path_numbers(not _path_numbers)
	elif id == ViewMenuId.VOLTAGE_VIEW or id == ViewMenuId.CURRENT_VIEW:
		_set_current_view(id == ViewMenuId.CURRENT_VIEW)
	elif id == ViewMenuId.GRID:
		_edit_grid = not _edit_grid
		_update_mode_ui()
		_save_settings()
	elif id == ViewMenuId.DUCT_COVERS:
		CabinetView.duct_covers = not CabinetView.duct_covers
		# The layout stays: the switchboards (in place windows too) are only painted again.
		for node: Node in find_children("*", "Control", true, false):
			if node is CabinetView:
				node.queue_redraw()
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


## Settings that change how the program works rather than what it shows:
## wiring helpers, cable type names, language.
func _rebuild_settings_menu() -> void:
	var popup: PopupMenu = _settings_menu.get_popup()
	popup.clear()
	popup.add_separator(tr("Wiring"))
	popup.add_check_item(tr("Wire all poles at once"), SettingsMenuId.WIRE_POLES)
	popup.set_item_checked(popup.item_count - 1, editor.wire_all_poles)
	popup.set_item_tooltip(popup.item_count - 1, tr("A wire drawn between multi-pole parts takes the poles beside it along (Shift: that wire alone)"))
	popup.add_check_item(tr("Wire parts placed in line (EPLAN style)"), SettingsMenuId.WIRE_ON_DROP)
	popup.set_item_checked(popup.item_count - 1, editor.wire_on_drop)
	popup.set_item_tooltip(popup.item_count - 1, tr("A part placed or dropped gets straight wires to the free terminals it faces"))
	popup.add_separator(tr("Cable types"))
	popup.add_radio_check_item(tr("Czech (CGSG, JYTY, CYKY)"), SettingsMenuId.CABLES_CZECH)
	popup.set_item_checked(popup.item_count - 1, WorkspaceCables.naming == WorkspaceCables.Naming.CZECH)
	popup.add_radio_check_item(tr("European (H07RN-F, H05VV5-F, NYY)"), SettingsMenuId.CABLES_HARMONISED)
	popup.set_item_checked(popup.item_count - 1, WorkspaceCables.naming == WorkspaceCables.Naming.HARMONISED)
	popup.add_separator(tr("Language"))
	for i: int in LOCALE_NAMES.size():
		popup.add_radio_check_item(LOCALE_NAMES[i], SettingsMenuId.LANGUAGE + i)
		popup.set_item_checked(popup.item_count - 1, i == _locale_index)


func _on_settings_menu(id: int) -> void:
	if id == SettingsMenuId.WIRE_POLES:
		editor.wire_all_poles = not editor.wire_all_poles
		editor._emit_hint()
		_save_settings()
	elif id == SettingsMenuId.WIRE_ON_DROP:
		editor.wire_on_drop = not editor.wire_on_drop
		_save_settings()
	elif id == SettingsMenuId.CABLES_CZECH or id == SettingsMenuId.CABLES_HARMONISED:
		WorkspaceCables.naming = WorkspaceCables.Naming.HARMONISED if id == SettingsMenuId.CABLES_HARMONISED else WorkspaceCables.Naming.CZECH
		_workspace.refresh()
		for window: PlaceWindow in _place_windows():
			window.refresh()
		_save_settings()
	elif id >= SettingsMenuId.LANGUAGE:
		set_language(id - SettingsMenuId.LANGUAGE)


func _rebuild_help_menu() -> void:
	var popup: PopupMenu = _help_menu.get_popup()
	popup.clear()
	popup.add_item(tr("Part datasheets…"), HelpMenuId.DATASHEETS, KEY_F1)
	popup.add_separator()
	popup.add_item(tr("Interface tour"), HelpMenuId.TOUR)
	popup.set_item_tooltip(popup.item_count - 1, tr("A short walk through the window: what each part of it is for"))
	if _lessons_menu == null:
		_lessons_menu = PopupMenu.new()
		_lessons_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_lessons_menu.id_pressed.connect(start_lesson)
		popup.add_child(_lessons_menu)
	_lessons_menu.clear()
	var lessons: Array[Lesson] = Lessons.all()
	for i: int in lessons.size():
		_lessons_menu.add_check_item("%d. %s" % [i + 1, tr(lessons[i].title)], i)
		_lessons_menu.set_item_checked(i, _finished_lessons.has(lessons[i].id))
		_lessons_menu.set_item_tooltip(i, tr(lessons[i].summary))
	popup.add_submenu_node_item(tr("Lessons"), _lessons_menu)
	popup.add_separator()
	popup.add_item(tr("Check for updates…"), HelpMenuId.CHECK_UPDATES)
	popup.add_check_item(tr("Check for updates at startup"), HelpMenuId.CHECK_AT_START)
	popup.set_item_checked(popup.item_count - 1, _check_updates)
	popup.add_separator()
	popup.add_item(tr("LadderLab on GitHub"), HelpMenuId.WEBSITE)
	popup.add_item(tr("Report a problem…"), HelpMenuId.REPORT)
	popup.set_item_tooltip(popup.item_count - 1, tr("Describe the problem on GitHub; attaching the .ladder file helps"))
	popup.add_separator()
	popup.add_item(tr("About LadderLab"), HelpMenuId.ABOUT)


func _on_help_menu(id: int) -> void:
	match id:
		HelpMenuId.CHECK_UPDATES:
			_manual_update_check = true
			_offering_download = false
			_update_dialog.dialog_text = tr("Checking for updates…")
			_update_dialog.ok_button_text = tr("OK")
			_update_dialog.get_cancel_button().visible = false
			_update_dialog.get_ok_button().disabled = true
			_update_dialog.popup_centered()
			_update_checker.check()
		HelpMenuId.CHECK_AT_START:
			_check_updates = not _check_updates
			_save_settings()
		HelpMenuId.WEBSITE:
			OS.shell_open(ReleaseCheck.PROJECT_PAGE)
		HelpMenuId.REPORT:
			OS.shell_open(ReleaseCheck.ISSUES_PAGE)
		HelpMenuId.ABOUT:
			_about_dialog.open()
		HelpMenuId.DATASHEETS:
			open_datasheets()
		HelpMenuId.TOUR:
			start_tour()


## The answer of a check: a newer version shows the toolbar button; a check
## from the Help menu also says what was found (the one at start is quiet).
func _on_update_checked(result: UpdateChecker.Result, release: Dictionary) -> void:
	if result == UpdateChecker.Result.NEWER:
		_new_release = release
	elif result == UpdateChecker.Result.LATEST:
		_new_release = {}
	_update_new_release_button()
	if not _manual_update_check:
		return
	_manual_update_check = false
	var dialog: ConfirmationDialog = _update_dialog
	dialog.get_ok_button().disabled = false
	match result:
		UpdateChecker.Result.NEWER:
			var text: String = tr("LadderLab %s is available (you have %s).") % [release["version"], ReleaseCheck.current_version()]
			var notes: String = ReleaseCheck.plain_text(release["notes"], 600)
			dialog.dialog_text = text if notes.is_empty() else text + "\n\n" + notes
			dialog.ok_button_text = tr("Download")
			_offering_download = true
			dialog.cancel_button_text = tr("Later")
			dialog.get_cancel_button().visible = true
		UpdateChecker.Result.LATEST:
			dialog.dialog_text = tr("You have the latest version (%s).") % ReleaseCheck.current_version()
		_:
			dialog.dialog_text = tr("Could not check for updates. Check the internet connection and try again.")
	# The text changed: let the dialog fit it.
	dialog.reset_size()
	dialog.popup_centered()


func _update_new_release_button() -> void:
	_update_button.visible = not _new_release.is_empty()
	if _update_button.visible:
		_update_button.text = tr("Version %s available") % _new_release["version"]
		_update_button.tooltip_text = tr("Download the new version from its release page")


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
	if _datasheet_window != null:
		_datasheet_window.refresh_paper()


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
	for window: PageWindow in _page_windows():
		window.content_scale_factor = factor
	for window: PlcWindow in _plc_windows():
		window.content_scale_factor = factor
	for window: PlaceWindow in _place_windows():
		window.content_scale_factor = factor
	if _datasheet_window != null:
		_datasheet_window.content_scale_factor = factor


## Puts [param content] into a resizable, zoomable [SideBar] added to
## [param parent], with the width and zoom remembered as [param key].
func _side_panel(parent: Control, content: Control, key: String, grip_left: bool) -> SideBar:
	var bar: SideBar = SideBar.new(content, grip_left)
	bar.name = key
	var saved: Vector2 = _bar_settings.get(key, Vector2(_bar_width(key), 1.0))
	bar.width = saved.x
	bar.zoom = saved.y
	bar.changed.connect(_save_settings)
	parent.add_child(bar)
	return bar


## Width of side panel [param key] until one is chosen.
static func _bar_width(key: String) -> float:
	match key:
		"lesson":
			return LESSON_WIDTH
		"control_panel":
			return CONTROL_PANEL_WIDTH
	return 250.0


## The control panel beside the schematic of an industrial control circuit
## while simulating, or the tab it is rolled in to.
func _update_control_panel() -> void:
	var shown: bool = area == Area.SCHEMATIC and mode == Mode.SIMULATE and edit_doc != null and edit_doc.environment == SchematicDocument.Kind.INDUSTRIAL
	_control_bar.visible = shown and not _control_rolled
	_control_tab.visible = shown and _control_rolled


## Rolls the control panel in to its tab ([param rolled]) or out again.
func _set_control_rolled(rolled: bool) -> void:
	_control_rolled = rolled
	_update_control_panel()
	_save_settings()


## The properties (and check results) beside the schematic: only in Edit
## mode while something is selected or the check results are shown.
func _update_side_bar() -> void:
	_side_bar.visible = area == Area.SCHEMATIC and mode == Mode.EDIT and (not editor.selected_components.is_empty() or not editor.selected_wires.is_empty() or _check_panel.visible)


## Shows the simulation as currents ([param on]) or as voltages.
func _set_current_view(on: bool) -> void:
	_current_view = on
	_view_select.select(1 if on else 0)
	view.set_current_view(on)
	for window: PageWindow in _page_windows():
		window.view.set_current_view(on)
	_save_settings()


func _set_wire_numbers(on: bool) -> void:
	_wire_numbers = on
	_numbers_toggle.set_pressed_no_signal(on)
	view.set_wire_numbers_visible(on)
	for window: PageWindow in _page_windows():
		window.view.set_wire_numbers_visible(on)
	_save_settings()


func _set_path_numbers(on: bool) -> void:
	_path_numbers = on
	view.set_path_numbers_visible(on)
	for window: PageWindow in _page_windows():
		window.view.set_path_numbers_visible(on)
	_save_settings()


func _update_mode_ui() -> void:
	var editing: bool = mode == Mode.EDIT
	var schematic: bool = area == Area.SCHEMATIC
	view.set_grid_visible(editing and _edit_grid)
	view.set_wire_numbers_visible(_wire_numbers)
	view.set_path_numbers_visible(_path_numbers)
	view.set_current_view(_current_view)
	_view_select.select(1 if _current_view else 0)
	# A residential installation shows its single-line diagram in place of the schematic.
	var single_line: bool = schematic and edit_doc != null and edit_doc.environment == SchematicDocument.Kind.RESIDENTIAL
	view.visible = schematic and not single_line
	_single_line.visible = single_line
	editor.active = editing and schematic and not single_line
	_page_bar.visible = schematic and not single_line
	var residential: bool = edit_doc != null and edit_doc.residential
	_workspace.visible = not schematic and not residential
	_floor_plan.visible = not schematic and residential
	_tree_bar.visible = not schematic and not residential
	_edit_tools.visible = editing and schematic
	for tool: Control in [_rotate_button, _mirror_button, _flip_button, _number_button, _check_button]:
		tool.visible = not single_line
	_numbers_toggle.visible = schematic and not single_line
	_layout_select.visible = schematic and not single_line
	_clamp_toggle.visible = schematic and not single_line
	# A residential installation's floor plan takes its parts from the palette too.
	var plan_parts: bool = not schematic and edit_doc != null and edit_doc.environment == SchematicDocument.Kind.RESIDENTIAL
	_palette.plan = plan_parts
	_palette_bar.visible = editing and (schematic or plan_parts)
	_lesson_bar.visible = schematic and _lesson_run != null
	_update_side_bar()
	_update_control_panel()
	_sim_tools.visible = not editing
	_sim_options.visible = not editing
	_time_label.visible = not editing
	_timing_panel.show_parts(_show_chart, _show_log)
	_timing_panel.visible = not editing
	_key_strip.document = view.document
	_key_strip.visible = not editing and _key_strip.has_keys()
	_update_run_button()
	_refresh_pages()
	_on_stepped(view.last_result)
	_refresh_lesson_marks()


## Palette and toolbar for what the schematic is: a house installation has
## its floor plan where an industrial control circuit has its workspace.
func _update_environment() -> void:
	var residential: bool = edit_doc != null and edit_doc.residential
	var environment: SchematicDocument.Kind = edit_doc.environment if edit_doc != null else SchematicDocument.Kind.INDUSTRIAL
	_palette.environment = environment
	_environment_label.text = NewSchematicDialog.environment_name(environment)
	_environment_label.tooltip_text = NewSchematicDialog.environment_text(environment)
	_update_control_panel()
	# A house installation has its floor plan in place of the workspace.
	_workspace_button.text = tr("Floor plan") if residential else tr("Workspace")
	_workspace_button.icon = AppTheme.icon("house" if residential else "workspace")
	_workspace_button.tooltip_text = tr("Rooms, and where the switches, sockets, luminaires and appliances are, with the cables between them") if residential else tr("Switchboards, control stations and the motors, limit switches and sensors in the field")
	if area == Area.WORKSPACE:
		_workspace.visible = not residential
		_floor_plan.visible = residential
		_tree_bar.visible = not residential
	elif _single_line.visible != _single_line_shown():
		# The schematic or the single-line diagram, by what the schematic is.
		_update_mode_ui()


func _update_run_button() -> void:
	_run_button.text = tr("Pause") if view.running else tr("Run")
	_run_button.icon = AppTheme.icon("pause" if view.running else "play")
	_step_button.disabled = view.running


func _update_title() -> void:
	var name: String = _file_path.get_file() if not _file_path.is_empty() else tr("Untitled")
	get_window().title = "%s%s – LadderLab" % [name, "*" if _dirty else ""]


# --- Documents and modes ----------------------------------------------------------

func _set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	if mode == Mode.SIMULATE:
		# Leaving Edit mode first finishes a marking being typed, in the
		# schematic rather than in the copy the simulation runs on.
		editor.active = false
		_start_simulation()
	else:
		view.load_document(edit_doc, false)
	_update_mode_ui()
	_fit_camera_later()


## An edit of the workspace or a control station (undoable). Taken in Edit
## mode only: a text field finished after Simulate was clicked would change
## the copy the simulation runs on.
func _edit_workspace(change: Callable) -> void:
	if mode == Mode.EDIT:
		editor.edit_workspace(change)


## An edit of a switchboard (undoable), in Edit mode only as above.
func _edit_cabinet(change: Callable) -> void:
	if mode == Mode.EDIT:
		editor.edit_cabinet(change)


## Asks for the key of push button or switch [param designation] (Edit mode).
func _ask_key(designation: String) -> void:
	if mode != Mode.EDIT or not edit_doc.can_have_key(designation):
		return
	var what: String = ""
	for box: ControlBox in edit_doc.control_panels():
		for item: ControlBoxItem in box.items:
			if item.designation == designation and not item.label.is_empty():
				what = item.label
	_key_prompt.ask(designation, what, edit_doc.key_bindings.get(designation, ""))


## Shows the schematic or the workspace; the simulation runs on in both.
func _set_area(new_area: Area) -> void:
	if new_area == area:
		return
	area = new_area
	_schematic_button.set_pressed_no_signal(area == Area.SCHEMATIC)
	_workspace_button.set_pressed_no_signal(area == Area.WORKSPACE)
	_update_mode_ui()
	if area == Area.SCHEMATIC:
		_fit_camera_later()


## Part [param designation] of the workspace shown in the schematic: its page,
## centred on it (selected while editing).
func _show_in_schematic(designation: String) -> void:
	var c: CircuitComponent = Workspace.field_component(edit_doc.circuit, designation)
	if c == null:
		return
	_set_area(Area.SCHEMATIC)
	await get_tree().process_frame
	_show_page(edit_doc.page_of(c.id), c.id)
	if mode == Mode.EDIT:
		editor._clear_selection()
		editor.selected_components[c.id] = true
		editor._selection_updated()


## The schematic or simulation shown was (re)loaded: the workspace and its
## windows follow it.
func _on_view_loaded() -> void:
	_workspace.set_document(view.document, mode == Mode.EDIT, _workspace_fit)
	_workspace.show_travels(view.travel_positions())
	_floor_plan.set_document(view.document, mode == Mode.EDIT, _workspace_fit)
	_single_line.set_document(view.document, mode == Mode.EDIT, _workspace_fit)
	var travels: Array[Travel] = []
	if mode == Mode.SIMULATE and view.simulator != null:
		travels = view.simulator.travels
	_control_panel.set_document(view.document, travels)
	_workspace_fit = false
	for window: PlaceWindow in _place_windows():
		window.set_document(view.document, mode == Mode.EDIT)


## Fits the view once the panels have their new sizes (after this frame).
func _fit_camera_later() -> void:
	await get_tree().process_frame
	_fit_camera()


## The chart or the log was rolled in or out on the timing panel.
func _on_timing_parts_toggled(show_chart: bool, show_log: bool) -> void:
	_show_chart = show_chart
	_show_log = show_log
	_save_settings()
	_fit_camera_later()


## (Re)starts the simulation on a fresh copy of the edited schematic.
func _start_simulation() -> void:
	_keys_down.clear()
	# Cleared before loading: loading runs the first step, which logs too.
	_timing_panel.event_log.clear()
	view.load_document(DocumentSerializer.from_dict(DocumentSerializer.to_dict(edit_doc)), true)
	view.running = true
	_timing_panel.chart.set_document(view.document, view.trace)
	_key_strip.document = view.document
	_key_strip.visible = mode == Mode.SIMULATE and _key_strip.has_keys()
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
	_update_environment()
	if mode == Mode.SIMULATE:
		_start_simulation()
	else:
		view.load_document(edit_doc, false)
	_layout_select.select(1 if doc.horizontal else 0)
	_switching_select.select(0 if doc.realistic_timing else 1)
	_refresh_pages()
	if fit:
		_fit_camera()


## Replaces the edited schematic with a new one that has no file yet. Another
## schematic than a lesson's own ends the lesson.
func _replace_document(doc: SchematicDocument, path: String) -> void:
	if not _starting_lesson:
		_close_lesson()
	_workspace_fit = true
	editor.history.clear()
	# Also drops a marking being typed, which belongs to the schematic replaced.
	editor.leave_page()
	# Check results of another schematic (an undo keeps them, re-checked).
	_check_panel.hide()
	_show_document(doc, true)
	_file_path = path
	_dirty = false
	RecoveryFile.remove()
	_update_title()


## An empty schematic of one page, as the program starts.
func _start_blank() -> void:
	_replace_document(SchematicDocument.new(tr("New schematic")), "")


## A new schematic of [param environment] (a [enum
## SchematicDocument.Kind]): with an L and an N supply point (a
## residential prototype also with its PE), a residential installation with
## its supply and main switch (see [SingleLine]).
func _new_document(environment: int = SchematicDocument.Kind.INDUSTRIAL) -> void:
	var doc: SchematicDocument = SchematicDocument.new(tr("New schematic"))
	doc.environment = environment as SchematicDocument.Kind
	if doc.environment == SchematicDocument.Kind.RESIDENTIAL:
		doc.update_single_line()
		_replace_document(doc, "")
		return
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, 16))
	if doc.residential:
		doc.add(PowerSupply.new("PE", PowerSupply.Conductor.PE), Vector2i(2, 19))
	if _layout_select.selected == 1:
		doc.transpose()
	_replace_document(doc, "")


func _on_document_replaced(doc: SchematicDocument) -> void:
	_show_document(doc, false)


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		_update_title()
	# Kept after every edit, so a crash or freeze loses no more than the edit
	# under way.
	RecoveryFile.write(edit_doc, _file_path)
	if _check_panel.visible:
		_check_panel.run(edit_doc)


func _fit_camera() -> void:
	# Path numbers are drawn outside the bounds, above or left of the drawing.
	var b: Rect2 = view.document.bounds().grow_individual(2.5, 2.5, 0.0, 0.0)
	if view.document.components_on_page(-1).is_empty():
		# An empty page: the top left part of the paper, where drawing starts.
		b = Rect2(-2.5, -2.5, 32.0, 20.0)
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


## Whether the single-line diagram of a residential installation shows.
func _single_line_shown() -> bool:
	return area == Area.SCHEMATIC and edit_doc != null and edit_doc.environment == SchematicDocument.Kind.RESIDENTIAL


## A part chosen on the single-line diagram shows its properties.
func _on_single_line_selected(designation: String) -> void:
	editor._clear_selection()
	var c: CircuitComponent = edit_doc.circuit.get_component(designation) if not designation.is_empty() else null
	if c != null:
		editor.selected_components[c.id] = true
	editor._selection_updated()
	_update_side_bar()


## Room [param room] shown on the floor plan (selected).
func _show_room(room: String) -> void:
	_set_area(Area.WORKSPACE)
	for f: int in edit_doc.floors.size():
		for i: int in edit_doc.floors[f].rooms.size():
			if edit_doc.floors[f].rooms[i].name == room:
				# On its floor.
				_floor_plan.show_floor(f)
				_floor_plan.canvas.selected = {"kind": "room", "index": i}
				_floor_plan.canvas.queue_redraw()
				return


func _single_selected() -> CircuitComponent:
	if editor == null or edit_doc == null or editor.selected_components.size() != 1:
		return null
	return edit_doc.circuit.get_component(editor.selected_components.keys()[0])


func _on_run_pressed() -> void:
	view.running = not view.running
	_update_run_button()
	# Paused, no step comes to say so.
	_show_status(view.last_result)


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


# --- Lessons and the tour ------------------------------------------------------------

## Starts lesson [param index] of [method Lessons.all] on its own schematic,
## after asking what to do with unsaved changes.
func start_lesson(index: int) -> void:
	if index < 0 or index >= Lessons.all().size():
		return
	_confirm_discard(func() -> void: _begin_lesson(index))


func _begin_lesson(index: int) -> void:
	var lesson: Lesson = Lessons.all()[index]
	_answer_welcome()
	_tour.stop(false)
	_set_area(Area.SCHEMATIC)
	_switch_mode(Mode.EDIT)
	_starting_lesson = true
	_replace_document(lesson.start.call(), "")
	_starting_lesson = false
	_lesson_index = index
	_lesson_run = LessonRun.new(lesson)
	_lesson_run.update(edit_doc)
	_lesson_run.follow()
	_revealed_step = -1
	_lesson_panel.show_run(_lesson_run, index, Lessons.all().size())
	_update_mode_ui()
	_fit_camera_later()


## Ends the lesson taken (the schematic stays).
func _close_lesson() -> void:
	if _lesson_run == null:
		return
	_lesson_run = null
	_lesson_index = -1
	_lesson_panel.show_run(null, 0, 1)
	_lesson_bar.hide()
	_lesson_marks.clear()
	_lesson_rings.targets = []


## The schematic changed: the lesson's drawing steps are looked at again
## (the next step to do is shown when one was ticked or unticked).
func _on_lesson_edited() -> void:
	if _lesson_run == null:
		return
	if _lesson_run.update(edit_doc):
		_lesson_run.follow()
		_lesson_panel.show_me = false
	_lesson_panel.rebuild()
	_refresh_lesson_marks()


## A step of the simulation: the lesson's steps done while simulating.
func _on_lesson_stepped(_result: StepResult) -> void:
	# The tour switches to Simulate by itself: that does not count.
	if _lesson_run == null or mode != Mode.SIMULATE or _tour.visible:
		return
	if _lesson_run.update_live(view.document):
		_lesson_run.follow()
		_lesson_panel.show_me = false
		_lesson_panel.rebuild()
		_refresh_lesson_marks()


## Check in the lesson panel: runs the lesson's goals on the schematic.
func _check_lesson() -> void:
	if _lesson_run == null:
		return
	_lesson_run.check(edit_doc)
	var id: String = _lesson_run.lesson.id
	if _lesson_run.passed() and not _finished_lessons.has(id):
		_finished_lessons[id] = true
		_save_settings()
	_lesson_panel.show_where = true
	_lesson_panel.rebuild()
	_refresh_lesson_marks()


## Rings and Show me of the step shown in the lesson panel: its parts on
## the drawing, its palette entry and the toolbar control it needs; the
## parts of a goal not met after a check.
func _refresh_lesson_marks() -> void:
	if _lesson_marks == null or _lesson_rings == null:
		return
	var run: LessonRun = _lesson_run
	_lesson_marks.visible = area == Area.SCHEMATIC
	if run == null or area != Area.SCHEMATIC:
		_lesson_marks.clear()
		_lesson_rings.targets = []
		return
	var step: Lesson.Step = run.lesson.steps[run.selected]
	var open: bool = not run.done[run.selected]
	var roles: PackedStringArray = PackedStringArray()
	if open:
		roles.append_array(step.focus)
	if _lesson_panel.show_where:
		roles.append_array(_lesson_panel.failed_roles())
	var editing: bool = open and mode == Mode.EDIT
	_lesson_marks.show_marks(run.lesson, step, run.edited, roles, editing, _lesson_panel.show_me)
	var targets: Array[Callable] = []
	# The palette entry of each part still to place (the first scrolled into view).
	var revealed: bool = _revealed_step == run.selected
	for place: Array in step.places:
		if not editing or run.edited.has(place[0]):
			continue
		var template: Dictionary = place[1]
		targets.append(func() -> Rect2: return _palette.entry_rect(template))
		if not revealed:
			revealed = true
			_revealed_step = run.selected
			_palette.reveal(template)
	# The field of the property to set, while its part is selected.
	if editing and not step.property.is_empty() and run.edited.has(step.property[0]):
		var id: String = run.edited.part(step.property[0]).id
		var key: String = step.property[1]
		targets.append(func() -> Rect2: return _properties.field_rect(id, key))
	if open and mode == Mode.EDIT and (step.control == "simulate" or step.simulating):
		targets.append(func() -> Rect2: return _visible_rect(_simulate_button))
	elif open and mode == Mode.SIMULATE and step.control == "edit":
		targets.append(func() -> Rect2: return _visible_rect(_edit_button))
	_lesson_rings.targets = targets


## Edit or Simulate, as if its button was clicked.
func _switch_mode(new_mode: Mode) -> void:
	_edit_button.set_pressed_no_signal(new_mode == Mode.EDIT)
	_simulate_button.set_pressed_no_signal(new_mode == Mode.SIMULATE)
	_set_mode(new_mode)


## Global rectangle of [param control] while it is shown, else an empty one.
func _visible_rect(control: Control) -> Rect2:
	return control.get_global_rect() if control != null and control.is_visible_in_tree() else Rect2()


## The welcome card was answered: it is not offered again.
func _answer_welcome() -> void:
	_welcome.hide()
	if not _welcomed:
		_welcomed = true
		_save_settings()


## Starts the interface tour; the mode and area it leaves are put back when
## it ends.
func start_tour() -> void:
	_answer_welcome()
	# Started again from its own last stop (the Help menu), it keeps what
	# was there before it.
	if not _tour.visible:
		_tour_mode = mode
		_tour_area = area
	_tour.start()


func _on_tour_finished(_completed: bool) -> void:
	_set_area(_tour_area)
	_switch_mode(_tour_mode)


func _tour_steps() -> Array[TourOverlay.Step]:
	var editing: Callable = func() -> void:
		_set_area(Area.SCHEMATIC)
		_switch_mode(Mode.EDIT)
	var simulating: Callable = func() -> void:
		_set_area(Area.SCHEMATIC)
		_switch_mode(Mode.SIMULATE)
	var steps: Array[TourOverlay.Step] = []
	steps.append(_tour_step("Welcome to LadderLab", "This short tour shows you around the window. Press Esc to leave it at any time.",
		Callable(), editing))
	steps.append(_tour_step("The parts", "Every part you can draw is here. Click one, then click on the page to place it; R turns it before you place it.",
		func() -> Rect2: return _visible_rect(_palette_bar), editing))
	steps.append(_tour_step("The page", "Click a terminal to start a wire and another terminal to finish it. Drag with the right or middle mouse button to move around, turn the wheel to zoom.",
		func() -> Rect2: return _visible_rect(_canvas_area), editing))
	steps.append(_tour_step("Editing tools", "Undo and redo, rotate, mirror and delete. Check looks for terminals left unconnected and other mistakes.",
		func() -> Rect2: return _visible_rect(_edit_tools), editing))
	var simulate: TourOverlay.Step = _tour_step("Try the circuit", "Simulate runs the circuit: you press its buttons and watch the contactors switch. The drawing cannot be changed meanwhile.",
		func() -> Rect2: return _visible_rect(_simulate_button), func() -> void: _set_area(Area.SCHEMATIC))
	simulate.waits = func() -> bool: return mode == Mode.SIMULATE
	simulate.act = func() -> void: _switch_mode(Mode.SIMULATE)
	simulate.waiting = "Click Simulate, or press Next."
	steps.append(simulate)
	steps.append(_tour_step("Time", "Time runs from the moment you switch to Simulate. Pause it with Space, step through it, or start again with Reset. Realistic switching gives relays their pick-up and drop-out times.",
		func() -> Rect2: return _visible_rect(_sim_tools).merge(_visible_rect(_sim_options)) if _sim_tools.is_visible_in_tree() else Rect2(), simulating))
	steps.append(_tour_step("Timing chart and event log", "They record when each part switched. Click their titles to show or hide them.",
		func() -> Rect2: return _visible_rect(_timing_panel), simulating))
	steps.append(_tour_step("Workspace", "Switchboards, control stations and the parts in the field, with the cables between them worked out from the wiring.",
		func() -> Rect2: return _visible_rect(_area_switch), func() -> void: _set_area(Area.SCHEMATIC)))
	steps.append(_tour_step("Lessons", "Lessons in the Help menu teach you to draw circuits step by step and check what you drew. This tour is there too.",
		func() -> Rect2: return _visible_rect(_help_menu), Callable()))
	return steps


func _tour_step(title: String, text: String, target: Callable, prepare: Callable) -> TourOverlay.Step:
	var step: TourOverlay.Step = TourOverlay.Step.new()
	step.title = title
	step.text = text
	step.target = target
	step.prepare = prepare
	return step


# --- Files ----------------------------------------------------------------------

func _on_file_menu(id: int) -> void:
	match id:
		FileMenuId.NEW:
			_confirm_discard(_new_dialog.ask)
		FileMenuId.OPEN:
			_confirm_discard(_show_open_dialog)
		FileMenuId.SAVE:
			_save()
		FileMenuId.SAVE_AS:
			_save_as()
		FileMenuId.EXPORT_PNG:
			_open_export_preview(false)
		FileMenuId.EXPORT_PDF:
			_open_export_preview(true)
		FileMenuId.EXPORT_CSV:
			_show_file_dialog(DialogPurpose.EXPORT_CSV)
		FileMenuId.TITLE_BLOCK:
			_show_title_block_dialog()
		FileMenuId.QUIT:
			_confirm_discard(_quit)
		FileMenuId.ASSOCIATE:
			_associate_files = not _associate_files
			if _associate_files:
				FileAssociation.register(tr("LadderLab schematic"))
			else:
				FileAssociation.unregister()
			_save_settings()
			_rebuild_file_menu()


func _on_recent_pressed(index: int) -> void:
	var path: String = _recent[index]
	_confirm_discard(func() -> void: open_file(path))


## Quits; unsaved changes were saved or given up by then.
func _quit() -> void:
	RecoveryFile.forget()
	get_tree().quit()


## Offers the unsaved changes kept by a LadderLab that did not close properly
## (crashed, froze or was killed; also one still frozen), the newest first.
## "Later" keeps them for the next start.
func _offer_recovery() -> void:
	var found: PackedStringArray = RecoveryFile.orphans()
	if found.is_empty():
		return
	_recovery_path = found[0]
	var result: Dictionary = RecoveryFile.read(_recovery_path)
	if result.has("error"):
		RecoveryFile.remove(_recovery_path)
		_offer_recovery()
		return
	var file: String = result["file"]
	var name: String = file.get_file() if not file.is_empty() else tr("Untitled")
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var when: String = Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(_recovery_path) + bias, true)
	_recovery_dialog.dialog_text = tr("LadderLab did not close properly. Restore the unsaved changes to %s from %s?") % [name, when]
	_recovery_dialog.popup_centered()


## Opens the offered recovery file as the edited schematic, with its changes
## still unsaved (Save writes them to the file they were made to).
func _restore_recovery() -> void:
	var result: Dictionary = RecoveryFile.read(_recovery_path)
	if result.has("error"):
		_show_error(tr(result["error"]) % _recovery_path.get_file())
		RecoveryFile.remove(_recovery_path)
		return
	_replace_document(result["document"], result["file"])
	_mark_dirty()
	RecoveryFile.remove(_recovery_path)
	# Copies of other sessions that did not close properly come next.
	_offer_recovery()


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
		DialogPurpose.EXPORT_CSV:
			_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			_file_dialog.title = tr("Export parts list as CSV")
			_file_dialog.filters = PackedStringArray(["*.csv ; CSV"])
			_file_dialog.current_file = (_file_path.get_file().get_basename() if not _file_path.is_empty() else tr("schematic")) + ".csv"
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
			_save_png(path, _export_images)
		DialogPurpose.EXPORT_PDF:
			if path.get_extension().to_lower() != "pdf":
				path += ".pdf"
			_save_pdf(path, _export_images, _export_layouts)
		DialogPurpose.EXPORT_CSV:
			if path.get_extension().to_lower() != "csv":
				path += ".csv"
			_save_csv(path)


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
	RecoveryFile.remove()
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
	_prepare_export({})
	_save_png(path, await _sheet_renderer.render(edit_doc, PackedInt32Array([edit_doc.page])))


## Saves every page as one page of a PDF document, with the sheets chosen
## for a PDF (stations, switchboards, workspace, parts list).
func export_pdf(path: String) -> void:
	_prepare_export(_export_contents)
	var images: Array[Image] = await _sheet_renderer.render(edit_doc, _all_pages())
	_save_pdf(path, images, _sheet_renderer.layouts.duplicate())


## Writes the parts list to [param path] as CSV.
func _save_csv(path: String) -> void:
	var headings: PackedStringArray = PackedStringArray([tr("Place"), tr("Designation"), tr("Quantity"), tr("Name"), tr("Data")])
	var text: String = PartsList.to_csv(PartsList.new().rows(edit_doc), headings)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_show_error(tr("Could not save %s.") % path.get_file())
		return
	# A byte order mark: spreadsheets then read the UTF-8 (č, ř) right.
	file.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))
	file.store_string(text)
	file.close()


func _save_png(path: String, images: Array[Image]) -> void:
	if images.is_empty() or images[0] == null or images[0].save_png(path) != OK:
		_show_error(tr("Could not save %s.") % path.get_file())


func _save_pdf(path: String, images: Array[Image], layouts: Array[SheetLayout]) -> void:
	var pdf: PdfWriter = PdfWriter.new()
	pdf.title = tr(edit_doc.title)
	for i: int in images.size():
		if images[i] == null:
			_show_error(tr("Could not save %s.") % path.get_file())
			return
		pdf.add_page(images[i], layouts[i].paper_points())
	if images.is_empty() or pdf.save(path) != OK:
		_show_error(tr("Could not save %s.") % path.get_file())


func _all_pages() -> PackedInt32Array:
	var pages: PackedInt32Array = PackedInt32Array()
	for i: int in edit_doc.pages.size():
		pages.append(i)
	return pages


## Shows the sheets of a PNG (the page shown) or PDF (every page) export
## before asking where to save them.
func _open_export_preview(pdf: bool) -> void:
	_export_pdf = pdf
	_export_images.clear()
	_export_layouts.clear()
	_export_preview.open(pdf, _export_contents, SheetRenderer.available(edit_doc), _export_paper, edit_doc.residential)
	_render_preview()


## Renders the sheets the preview shows, as they will be saved; until they
## are there, the preview shows nothing and cannot be saved.
func _render_preview() -> void:
	_export_render += 1
	var ticket: int = _export_render
	var pdf: bool = _export_pdf
	_export_images = []
	_export_layouts = []
	_export_preview.rendering()
	_prepare_export(_export_preview.contents() if pdf else {})
	_sheet_renderer.wire_numbers = _export_preview.wire_numbers()
	var images: Array[Image] = await _sheet_renderer.render(edit_doc, _all_pages() if pdf else PackedInt32Array([edit_doc.page]))
	if ticket != _export_render:
		return
	_export_images = images
	_export_layouts = _sheet_renderer.layouts.duplicate()
	_export_preview.show_sheets(_export_images, _export_layouts)


## Texts of the title block and what to draw, as chosen in the window; a
## PDF holds what [param contents] says (see [method ExportPreview.contents]),
## the schematic alone when it is empty.
func _prepare_export(contents: Dictionary) -> void:
	_sheet_renderer.largest_paper = _export_paper
	_sheet_renderer.schematic = contents.get("schematic", true)
	_sheet_renderer.stations = contents.get("stations", false)
	_sheet_renderer.switchboards = contents.get("switchboards", false)
	_sheet_renderer.plc_programs = contents.get("plc_programs", false)
	_sheet_renderer.timers = contents.get("timers", false)
	_sheet_renderer.workspace = contents.get("workspace", false)
	_sheet_renderer.parts_list = contents.get("parts_list", false)
	_sheet_renderer.wire_numbers = _wire_numbers
	_sheet_renderer.path_numbers = _path_numbers
	_sheet_renderer.file_name = _file_path.get_file()
	_sheet_renderer.title = tr(edit_doc.title)
	_sheet_renderer.untitled_page = tr("Page %d")


func _title_block_caption(field: String) -> String:
	match field:
		"title":
			return tr("Title")
		"company":
			return tr("Company")
		"project":
			return tr("Project")
		"stage":
			return tr("Stage (DUR, DSP, DPS …)")
		"drawing_number":
			return tr("Drawing no.")
		"revision":
			return tr("Revision")
		"drawn_by":
			return tr("Drawn by")
		"checked_by":
			return tr("Checked by")
		"date":
			return tr("Date")
	return field


func _show_title_block_dialog() -> void:
	_title_block_edits["title"].text = tr(edit_doc.title)
	for field: String in TitleBlock.FIELDS:
		_title_block_edits[field].text = edit_doc.title_block.get(field)
	_title_block_dialog.popup_centered()
	_title_block_edits["drawn_by"].grab_focus()


## Puts the texts of the title block dialog into the schematic (undoable).
func _apply_title_block() -> void:
	var block: TitleBlock = TitleBlock.new()
	for field: String in TitleBlock.FIELDS:
		block.set(field, _title_block_edits[field].text)
	var title: String = _title_block_edits["title"].text.strip_edges()
	# An unchanged title stays English source text, shown translated.
	if title == tr(edit_doc.title):
		title = edit_doc.title
	var snapshot: Dictionary = DocumentSerializer.to_dict(edit_doc)
	if not edit_doc.set_title_block(title, block):
		return
	editor.history.record(snapshot)
	if view.document != edit_doc:
		view.document.set_title_block(title, block)
	_mark_dirty()


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
	_menu_page = tab
	_page_menu.clear()
	_page_menu.add_item(tr("Open in a new window"), PageMenuId.WINDOW)
	_page_menu.set_item_tooltip(_page_menu.item_count - 1, tr("Shows the page in a window of its own, e.g. on a second monitor; while simulating, buttons and switches work there too"))
	if mode != Mode.EDIT:
		_popup_page_menu()
		return
	_page_menu.add_separator()
	_page_menu.add_item(tr("Rename…"), PageMenuId.RENAME)
	_page_menu.add_item(tr("Move left"), PageMenuId.MOVE_LEFT)
	_page_menu.set_item_disabled(_page_menu.item_count - 1, tab == 0)
	_page_menu.add_item(tr("Move right"), PageMenuId.MOVE_RIGHT)
	_page_menu.set_item_disabled(_page_menu.item_count - 1, tab == edit_doc.pages.size() - 1)
	_page_menu.add_separator()
	_page_menu.add_item(tr("Delete page"), PageMenuId.DELETE)
	_page_menu.set_item_disabled(_page_menu.item_count - 1, edit_doc.pages.size() <= 1)
	_page_menu.set_item_tooltip(_page_menu.item_count - 1, tr("Removes the page with everything drawn on it (Ctrl+Z brings it back)"))
	_popup_page_menu()


func _popup_page_menu() -> void:
	_page_menu.reset_size()
	AppTheme.popup_at_mouse(_page_menu)


func _on_page_menu(id: int) -> void:
	var index: int = _menu_page
	match id:
		PageMenuId.RENAME:
			_show_rename_dialog(index)
		PageMenuId.MOVE_LEFT, PageMenuId.MOVE_RIGHT:
			_move_page(index, index + (-1 if id == PageMenuId.MOVE_LEFT else 1))
		PageMenuId.DELETE:
			_remove_page(index)
			_fit_camera()
		PageMenuId.WINDOW:
			open_page_window(index)


## Moves page [param index] to place [param to] (undoable); page windows
## go on showing the pages they showed.
func _move_page(index: int, to: int) -> void:
	for window: PageWindow in _page_windows():
		window.page_moved(index, to)
	editor.edit_pages(func(doc: SchematicDocument) -> void: doc.move_page(index, to))


## Deletes page [param index] with everything on it (undoable); a window
## showing it closes, the others go on showing their pages.
func _remove_page(index: int) -> void:
	if edit_doc.pages.size() <= 1:
		return
	for window: PageWindow in _page_windows():
		window.page_removed(index)
	editor.edit_pages(func(doc: SchematicDocument) -> void: doc.remove_page(index))


## Opens page [param index] in a window of its own, following the main view
## (same schematic, same simulation). Returns the window.
func open_page_window(index: int) -> PageWindow:
	var window: PageWindow = PageWindow.new(view, index)
	window.content_scale_factor = get_window().content_scale_factor
	window.key_pressed.connect(_on_window_key)
	add_child(window)
	window.view.set_wire_numbers_visible(_wire_numbers)
	window.view.set_path_numbers_visible(_path_numbers)
	window.view.set_current_view(_current_view)
	window.view.clamp_tool = _clamp_toggle.button_pressed
	return window


## Opens switchboard or control station [param place_name] of the workspace
## in a window of its own (or brings its window to the front), showing the
## same schematic or simulation. Returns the window.
func open_place_window(kind: Workspace.Place, place_name: String) -> PlaceWindow:
	for open: PlaceWindow in _place_windows():
		if open.kind == kind and open.place_name == place_name:
			open.grab_focus()
			return open
	var window: PlaceWindow = PlaceWindow.new(kind, place_name)
	window.content_scale_factor = get_window().content_scale_factor
	window.key_pressed.connect(_on_window_key)
	window.edit_requested.connect(_edit_workspace)
	window.cabinet_edit_requested.connect(_edit_cabinet)
	window.button_held.connect(view.hold_button)
	window.switch_toggled.connect(view.toggle_switch)
	window.operate_requested.connect(view.operate_device)
	window.key_bind_requested.connect(_ask_key)
	add_child(window)
	window.set_document(view.document, mode == Mode.EDIT)
	return window


## Shows the datasheet of part [param component_id] of the schematic shown
## (in the datasheet window, opened if needed).
func open_datasheet(component_id: String) -> DatasheetWindow:
	var part: CircuitComponent = view.document.circuit.get_component(component_id)
	var window: DatasheetWindow = _datasheet()
	if part != null:
		window.show_part(part, view.document)
	return window


## Shows the datasheets of the palette parts, at the first one unless one is shown.
func open_datasheets() -> DatasheetWindow:
	var window: DatasheetWindow = _datasheet()
	if window.sheet == null:
		window.show_entry(0)
	return window


func _datasheet() -> DatasheetWindow:
	if _datasheet_window == null:
		_datasheet_window = DatasheetWindow.new()
		_datasheet_window.content_scale_factor = get_window().content_scale_factor
		_datasheet_window.key_pressed.connect(_on_window_key)
		add_child(_datasheet_window)
	_datasheet_window.show()
	_datasheet_window.grab_focus()
	return _datasheet_window


## Opens the program of PLC [param component_id] in its window (or brings
## its window to the front): editable in Edit mode, running while simulating.
func open_plc_window(component_id: String) -> PlcWindow:
	for open: PlcWindow in _plc_windows():
		if open.component_id == component_id:
			open.grab_focus()
			return open
	var plc: Plc = view.document.circuit.get_component(component_id) as Plc
	if plc == null:
		return null
	var window: PlcWindow = PlcWindow.new(component_id)
	window.content_scale_factor = get_window().content_scale_factor
	window.bind(plc, mode == Mode.SIMULATE)
	window.program_edited.connect(_on_plc_program_edited)
	window.undo_requested.connect(func() -> void:
		if mode == Mode.EDIT:
			editor.undo())
	window.redo_requested.connect(func() -> void:
		if mode == Mode.EDIT:
			editor.redo())
	window.key_pressed.connect(_on_window_key)
	add_child(window)
	return window


## A PLC window changed its program: put it into the schematic (undoable).
func _on_plc_program_edited(component_id: String, program: Dictionary) -> void:
	var plc: Plc = edit_doc.circuit.get_component(component_id) as Plc
	if mode != Mode.EDIT or plc == null:
		return
	var data: Dictionary = DocumentSerializer.component_to_dict(plc)
	data["program"] = program
	var error: String = editor.apply_properties(component_id, data)
	if not error.is_empty():
		_show_error(error)


## The PLC windows show the PLCs of the schematic or simulation now shown;
## a window whose PLC is gone closes.
func _rebind_plc_windows() -> void:
	for window: PlcWindow in _plc_windows():
		var plc: Plc = view.document.circuit.get_component(window.component_id) as Plc
		if plc == null:
			window.queue_free()
		else:
			window.bind(plc, mode == Mode.SIMULATE)


func _plc_windows() -> Array[PlcWindow]:
	var windows: Array[PlcWindow] = []
	for child: Node in get_children():
		if child is PlcWindow and not child.is_queued_for_deletion():
			windows.append(child as PlcWindow)
	return windows


## The windows of switchboards and control stations that are open.
func _place_windows() -> Array[PlaceWindow]:
	var windows: Array[PlaceWindow] = []
	for child: Node in get_children():
		if child is PlaceWindow and not child.is_queued_for_deletion():
			windows.append(child as PlaceWindow)
	return windows


## The page windows that are open.
func _page_windows() -> Array[PageWindow]:
	var windows: Array[PageWindow] = []
	for child: Node in get_children():
		if child is PageWindow and not child.is_queued_for_deletion():
			windows.append(child as PageWindow)
	return windows


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
		_show_chart = config.get_value("view", "timing_chart", false)
		_show_log = config.get_value("view", "event_log", false)
		_keys_rolled = bool(config.get_value("view", "keys_rolled", false))
		_control_rolled = bool(config.get_value("view", "control_panel_rolled", false))
		for key: String in ExportPreview.CONTENTS:
			_export_contents[key] = bool(config.get_value("export", key, true))
		var paper: String = str(config.get_value("export", "largest_paper", SheetLayout.DEFAULT_LARGEST))
		_export_paper = paper if SheetLayout.paper_index(paper) >= 0 else SheetLayout.DEFAULT_LARGEST
		WorkspaceCables.naming = WorkspaceCables.Naming.HARMONISED if config.get_value("view", "cable_types", "czech") == "harmonised" else WorkspaceCables.Naming.CZECH
		_theme_variant = AppTheme.Variant.LIGHT if config.get_value("view", "theme", "dark") == "light" else AppTheme.Variant.DARK
		_white_paper = bool(config.get_value("view", "white_paper", false))
		_edit_grid = bool(config.get_value("view", "grid", false))
		CabinetView.duct_covers = bool(config.get_value("view", "duct_covers", false))
		_wire_numbers = bool(config.get_value("view", "wire_numbers", true))
		_path_numbers = bool(config.get_value("view", "path_numbers", true))
		_palette_grid = bool(config.get_value("view", "palette_grid", false))
		_current_view = bool(config.get_value("view", "current_view", false))
		editor.wire_all_poles = bool(config.get_value("editor", "wire_all_poles", false))
		editor.wire_on_drop = bool(config.get_value("editor", "wire_on_drop", false))
		_timing_size = Vector2(float(config.get_value("view", "event_log_width", 340.0)), float(config.get_value("view", "timing_height", 220.0)))
		var hidden_rows: Variant = config.get_value("view", "timing_hidden", PackedStringArray())
		if hidden_rows is PackedStringArray or hidden_rows is Array:
			for key: Variant in hidden_rows:
				_timing_hidden[str(key)] = true
		for key: String in ["palette", "properties", "workspace_tree", "lesson", "control_panel"]:
			_bar_settings[key] = Vector2(float(config.get_value("view", key + "_width", _bar_width(key))), float(config.get_value("view", key + "_zoom", 1.0)))
		_ui_scale = float(config.get_value("view", "ui_scale", 0.0))
		_locale_index = maxi(LOCALES.find(str(config.get_value("view", "language", "en"))), 0)
		_check_updates = bool(config.get_value("updates", "check_at_start", true))
		_associate_files = bool(config.get_value("files", "associate", true))
		_welcomed = bool(config.get_value("tutorial", "welcomed", false))
		var finished: Variant = config.get_value("tutorial", "finished", PackedStringArray())
		if finished is PackedStringArray or finished is Array:
			for id: Variant in finished:
				_finished_lessons[str(id)] = true


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("files", "recent", _recent)
	config.set_value("view", "timing_chart", _show_chart)
	config.set_value("view", "event_log", _show_log)
	config.set_value("view", "keys_rolled", _keys_rolled)
	config.set_value("view", "control_panel_rolled", _control_rolled)
	for key: String in _export_contents:
		config.set_value("export", key, _export_contents[key])
	config.set_value("export", "largest_paper", _export_paper)
	config.set_value("view", "cable_types", "harmonised" if WorkspaceCables.naming == WorkspaceCables.Naming.HARMONISED else "czech")
	config.set_value("view", "theme", "light" if _theme_variant == AppTheme.Variant.LIGHT else "dark")
	config.set_value("view", "ui_scale", _ui_scale)
	config.set_value("view", "white_paper", _white_paper)
	config.set_value("view", "grid", _edit_grid)
	config.set_value("view", "duct_covers", CabinetView.duct_covers)
	config.set_value("view", "wire_numbers", _wire_numbers)
	config.set_value("view", "path_numbers", _path_numbers)
	config.set_value("view", "palette_grid", _palette_grid)
	config.set_value("view", "current_view", _current_view)
	config.set_value("editor", "wire_all_poles", editor.wire_all_poles)
	config.set_value("editor", "wire_on_drop", editor.wire_on_drop)
	if _timing_panel != null:
		config.set_value("view", "timing_height", _timing_panel.panel_height)
		config.set_value("view", "event_log_width", _timing_panel.log_width)
		config.set_value("view", "timing_hidden", PackedStringArray(_timing_panel.chart.hidden_rows.keys()))
	for bar: SideBar in [_palette_bar, _side_bar, _tree_bar, _lesson_bar, _control_bar]:
		if bar != null:
			config.set_value("view", bar.name + "_width", bar.width)
			config.set_value("view", bar.name + "_zoom", bar.zoom)
	config.set_value("view", "language", LOCALES[_locale_index])
	config.set_value("updates", "check_at_start", _check_updates)
	config.set_value("files", "associate", _associate_files)
	config.set_value("tutorial", "welcomed", _welcomed)
	config.set_value("tutorial", "finished", PackedStringArray(_finished_lessons.keys()))
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
	if mode == Mode.EDIT and area == Area.SCHEMATIC and _status_label != null:
		_status_label.text = text
		_fit_status_label()


## The status keeps its whole text while the window has room for it, the
## hint beside it giving way first; a status longer than the window is cut
## short.
func _fit_status_label() -> void:
	if _status_label == null:
		return
	var row: HBoxContainer = _status_label.get_parent() as HBoxContainer
	var bar: Control = row.get_parent() as Control
	var room: float = get_viewport().get_visible_rect().size.x - bar.get_theme_stylebox("panel").get_minimum_size().x - row.get_theme_constant("separation") - _hint_label.get_combined_minimum_size().x
	var font: Font = _status_label.get_theme_font("font")
	var need: float = font.get_string_size(_status_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _status_label.get_theme_font_size("font_size")).x + _status_label.get_theme_stylebox("normal").get_minimum_size().x
	_status_label.custom_minimum_size.x = clampf(ceilf(need), 0.0, floorf(room))


func _on_stepped(result: StepResult) -> void:
	if _time_label == null:
		return
	_short_banner.visible = mode == Mode.SIMULATE and result.short_circuit
	if _short_banner.visible:
		_short_banner.text = tr("NO FUSE and SHORT CIRCUIT!")
	if mode == Mode.EDIT:
		# The workspace has its hints in its own bar.
		_status_label.text = _editor_hint if area == Area.SCHEMATIC else ""
		_status_label.remove_theme_color_override("font_color")
		if _single_line_shown():
			_status_label.text = ""
			_hint_label.text = tr("Pick a part in the palette and click where it goes; Delete takes the selection away. Right or middle drag pans, wheel zooms.")
		elif area == Area.SCHEMATIC:
			_hint_label.text = tr("Right or middle drag pans, wheel zooms.")
		elif edit_doc != null and edit_doc.residential:
			_hint_label.text = tr("Double-click a room to edit it, a dimension of the selected room to type its length (or select a wall and press Enter); Delete takes the selection away; a right click ends drawing. Right or middle drag pans, wheel zooms.")
		else:
			_hint_label.text = ""
		_fit_status_label()
		return
	if _single_line_shown():
		_hint_label.text = tr("Click the main switch, a breaker, an RCD or its test button to operate it. Right or middle drag pans, wheel zooms.")
	elif area == Area.SCHEMATIC:
		_hint_label.text = tr("Click buttons and switches to operate them. Right or middle drag pans, wheel zooms.")
	elif edit_doc != null and edit_doc.residential:
		_hint_label.text = tr("Click a light switch on the plan to switch it (of two rockers, the side clicked). Right or middle drag pans, wheel zooms.")
	else:
		_hint_label.text = tr("Open a control station to press its buttons, a switchboard to switch its breakers.")
	_time_label.text = "%.3f s" % view.sim_time
	_timing_panel.chart.set_time(view.sim_time)
	_show_status(result)


## The status bar while simulating: a fault or warning of [param result],
## else running or paused. In the app theme's colours: the bar is not
## schematic paper.
func _show_status(result: StepResult) -> void:
	var tripped: String = _tripped_protection()
	if result.short_circuit:
		_status_label.text = tr("NO FUSE and SHORT CIRCUIT! %s") % " → ".join(result.short_circuit_path)
		_status_label.add_theme_color_override("font_color", AppTheme.danger)
	elif not tripped.is_empty():
		_status_label.text = tripped
		_status_label.add_theme_color_override("font_color", AppTheme.warning)
	elif not _motor_trouble().is_empty():
		_status_label.text = _motor_trouble()
		_status_label.add_theme_color_override("font_color", AppTheme.danger)
	elif not result.chatter_hz.is_empty():
		var parts: PackedStringArray = PackedStringArray()
		for designation: String in result.chatter_hz:
			parts.append(tr("%s is chattering (about %d Hz)") % [designation, roundi(result.chatter_hz[designation])])
		_status_label.text = ", ".join(parts)
		_status_label.add_theme_color_override("font_color", AppTheme.warning)
	elif result.is_oscillating():
		_status_label.text = tr("Oscillation: %s keeps switching on and off") % ", ".join(result.oscillating_tags)
		_status_label.add_theme_color_override("font_color", AppTheme.warning)
	else:
		_status_label.text = tr("Running") if view.running else tr("Paused")
		_status_label.remove_theme_color_override("font_color")
	_fit_status_label()
