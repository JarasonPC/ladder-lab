extends GutTest
## The main window and the editor together: the marking editor across Edit /
## Simulate, mode and area switches, keys bound to buttons, the event log,
## the example list, page windows, unsaved changes and recovery.

const Main: GDScript = preload("res://ui/main.gd")
const MAIN_SCENE: String = "res://main.tscn"
const SETTINGS: String = "user://settings.cfg"
const ORPHANS: PackedStringArray = ["zz-test-fixes-editor-app-a", "zz-test-fixes-editor-app-b"]

var main: Main
var editor: SchematicEditor
## What the main window changes for the whole program, put back afterwards.
var _settings: String = ""
var _had_settings: bool = false
var _dark_paper: bool = false
var _variant: AppTheme.Variant = AppTheme.Variant.DARK
var _naming: WorkspaceCables.Naming = WorkspaceCables.Naming.CZECH
var _locale: String = ""
var _scale: float = 1.0


func before_all() -> void:
	_had_settings = FileAccess.file_exists(SETTINGS)
	if _had_settings:
		_settings = FileAccess.get_file_as_string(SETTINGS)
	_dark_paper = SchematicTheme.dark
	_variant = AppTheme.variant
	_naming = WorkspaceCables.naming
	_locale = TranslationServer.get_locale()
	_scale = get_tree().root.content_scale_factor


func after_all() -> void:
	if _had_settings:
		var file: FileAccess = FileAccess.open(SETTINGS, FileAccess.WRITE)
		file.store_string(_settings)
		file.close()
	elif FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(SETTINGS)
	RecoveryFile.forget()
	AppTheme.use(_variant)
	SchematicTheme.use(_dark_paper)
	WorkspaceCables.naming = _naming
	TranslationServer.set_locale(_locale)
	get_tree().root.content_scale_factor = _scale
	get_tree().auto_accept_quit = true


func before_each() -> void:
	main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	add_child_autofree(main)
	main._recovery_dialog.hide()
	editor = main.editor
	TranslationServer.set_locale("en")


func after_each() -> void:
	for name: String in ORPHANS:
		RecoveryFile.remove(RecoveryFile.DIR.path_join(name + "." + ProjectFile.EXTENSION))


func _example(index: int) -> void:
	main._circuit_select.select(index)
	main._load_example()


func _first(doc: SchematicDocument, type: Variant) -> CircuitComponent:
	for c: CircuitComponent in doc.circuit.get_components():
		if is_instance_of(c, type):
			return c
	return null


func _start_button(doc: SchematicDocument) -> String:
	for c: CircuitComponent in doc.circuit.get_components():
		if c is PushButton and (c as PushButton).contact_type == SwitchingElement.ContactType.NO:
			return c.designation
	return ""


func _key(code: Key, pressed: bool, ctrl: bool = false) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = pressed
	key.ctrl_pressed = ctrl
	return key


## Example 0 simulated with key A bound to its start button; returns the button.
func _simulate_with_key() -> PushButton:
	_example(0)
	var start: String = _start_button(main.edit_doc)
	editor.edit_workspace(func(d: SchematicDocument) -> void: d.set_key(start, "A"))
	main._set_mode(Main.Mode.SIMULATE)
	return main.view.document.circuit.get_operator(start) as PushButton


func test_marking_typed_when_simulate_is_clicked_renames_in_the_schematic() -> void:
	_example(0)
	var coil: CircuitComponent = _first(main.edit_doc, Coil)
	editor._edit_marking(coil, "designation", -1)
	editor._inline.text = "KM9"
	main._set_mode(Main.Mode.SIMULATE)
	assert_null(editor._inline, "the field is gone in Simulate mode")
	assert_not_null(main.edit_doc.circuit.get_component("KM9"), "renamed in the schematic")
	assert_not_null(main.view.document.circuit.get_component("KM9"), "and so in the simulation")


func test_undo_closes_the_marking_editor() -> void:
	_example(0)
	editor.number_wires()
	editor._edit_marking(_first(main.edit_doc, Coil), "designation", -1)
	editor.undo()
	assert_null(editor._inline)


func test_new_schematic_closes_the_marking_editor() -> void:
	_example(0)
	editor._edit_marking(_first(main.edit_doc, Coil), "designation", -1)
	main._new_document()
	assert_null(editor._inline)


func test_plc_program_edit_keeps_the_selection() -> void:
	_example(ExampleCircuits.TITLES.find("PLC: start/stop with an on-delay"))
	var plc: Plc = _first(main.edit_doc, Plc) as Plc
	var lamp: CircuitComponent = _first(main.edit_doc, Lamp)
	editor.selected_components[lamp.id] = true
	editor._selection_updated()
	var data: Dictionary = DocumentSerializer.component_to_dict(plc)
	main._on_plc_program_edited(plc.id, data["program"])
	assert_eq(editor.selected_components.keys(), [lamp.id])
	editor.delete_selection()
	assert_not_null(main.edit_doc.circuit.get_component(plc.id), "Delete removes the lamp, not the PLC")


func test_simulate_while_simulating_goes_on() -> void:
	_example(0)
	main._set_mode(Main.Mode.SIMULATE)
	var doc: SchematicDocument = main.view.document
	main.view.step_once(0.5)
	var time: float = main.view.sim_time
	main._set_mode(Main.Mode.SIMULATE)
	assert_same(main.view.document, doc)
	assert_eq(main.view.sim_time, time)


func test_key_released_with_ctrl_down_lets_the_button_go() -> void:
	var button: PushButton = _simulate_with_key()
	main._input(_key(KEY_A, true))
	assert_true(button.pressed)
	main._input(_key(KEY_A, false, true))
	assert_false(button.pressed)


func test_key_released_in_the_datasheet_window_lets_the_button_go() -> void:
	var button: PushButton = _simulate_with_key()
	main._input(_key(KEY_A, true))
	var window: DatasheetWindow = main.open_datasheets()
	for child: Node in window.get_children():
		if child is DatasheetWindow._Keys:
			(child as DatasheetWindow._Keys)._unhandled_input(_key(KEY_A, false))
	assert_false(button.pressed)


func test_plc_window_lets_buttons_go_and_keeps_space() -> void:
	_example(ExampleCircuits.TITLES.find("PLC: start/stop with an on-delay"))
	var start: String = _start_button(main.edit_doc)
	editor.edit_workspace(func(d: SchematicDocument) -> void: d.set_key(start, "A"))
	main._set_mode(Main.Mode.SIMULATE)
	var button: PushButton = main.view.document.circuit.get_operator(start) as PushButton
	var window: PlcWindow = main.open_plc_window(_first(main.view.document, Plc).id)
	var catcher: PlcWindow.KeyCatcher = null
	for child: Node in window.get_children():
		if child is PlcWindow.KeyCatcher:
			catcher = child as PlcWindow.KeyCatcher
	main._input(_key(KEY_A, true))
	catcher._unhandled_input(_key(KEY_A, false))
	assert_false(button.pressed, "released in the PLC window")
	var running: bool = main.view.running
	catcher._unhandled_input(_key(KEY_SPACE, true))
	assert_eq(main.view.running, running, "Space pans there, it does not pause")


func test_f1_opens_the_selected_part_after_the_help_menu_was_opened() -> void:
	_example(0)
	main._rebuild_help_menu()
	var lamp: CircuitComponent = _first(main.edit_doc, Lamp)
	editor.selected_components[lamp.id] = true
	editor._selection_updated()
	var f1: InputEventKey = _key(KEY_F1, true)
	get_tree().root.push_input(f1)
	var shown: String = main._datasheet_window.sheet.title
	assert_eq(shown, main.open_datasheet(lamp.id).sheet.title)


func test_event_log_gets_each_event_once() -> void:
	_example(0)
	main._set_mode(Main.Mode.SIMULATE)
	for c: CircuitComponent in main.view.document.circuit.get_components():
		if c is CircuitBreaker:
			main.view.operate_device(c.designation)
	main.view.hold_button(_start_button(main.view.document), true)
	# Until a step logs something: the contactor pulling in.
	for i: int in 100:
		if not main.view.last_result.events.is_empty():
			break
		main.view.step_once(0.02)
	assert_false(main.view.last_result.events.is_empty())
	var count: int = main._timing_panel.event_log._entries.size()
	main._set_area(Main.Area.WORKSPACE)
	main._set_area(Main.Area.SCHEMATIC)
	main._retranslate()
	assert_eq(main._timing_panel.event_log._entries.size(), count)


func test_reset_keeps_the_events_of_the_first_step() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, 16))
	doc.connect_terminals("L", "N")
	main._replace_document(doc, "")
	main._set_mode(Main.Mode.SIMULATE)
	# Reset.
	main._start_simulation()
	assert_false(main.view.last_result.events.is_empty(), "the short is logged in the first step")
	assert_eq(main._timing_panel.event_log._entries.size(), main.view.last_result.events.size())


func test_example_list_shows_its_placeholder_after_new() -> void:
	_example(0)
	main._new_document()
	assert_eq(main._circuit_select.selected, -1)
	assert_eq(main._circuit_select.text, "Example circuits…")
	main._mark_dirty()
	main._on_example_selected(2)
	main._unsaved_dialog.hide()
	assert_eq(main._circuit_select.text, "Example circuits…", "still shown while asking about unsaved changes")


func test_page_window_follows_its_page() -> void:
	editor.edit_pages(func(d: SchematicDocument) -> void: d.add_page("Control section"))
	editor.edit_pages(func(d: SchematicDocument) -> void: d.add_page("Signalling section"))
	var last: PageWindow = main.open_page_window(2)
	var first: PageWindow = main.open_page_window(0)
	main._menu_page = 2
	main._on_page_menu(Main.PageMenuId.MOVE_LEFT)
	assert_eq(last.view.page, 1)
	assert_eq(first.view.page, 0)
	main._menu_page = 0
	main._on_page_menu(Main.PageMenuId.DELETE)
	assert_true(first.is_queued_for_deletion(), "the window of a deleted page closes")
	assert_eq(last.view.page, 0)
	assert_eq(main.edit_doc.pages[last.view.page], "Signalling section")


func test_unchanged_marking_and_key_change_nothing() -> void:
	_example(0)
	editor._edit_marking(_first(main.edit_doc, Lamp), "purpose", -1)
	editor._inline.text_submitted.emit(editor._inline.text)
	assert_false(editor.history.can_undo(), "same purpose")
	main._key_prompt.chosen.emit(_start_button(main.edit_doc), "")
	assert_false(editor.history.can_undo(), "no key taken off a button without one")
	assert_false(main._dirty)


func test_part_dragged_away_and_back_changes_nothing() -> void:
	_example(0)
	var lamp: CircuitComponent = _first(main.edit_doc, Lamp)
	var centre: Vector2 = main.edit_doc.component_body(lamp).get_center()
	editor._mouse_point = centre
	editor._mouse_cell = Vector2i(centre.round())
	editor._on_left_pressed(false)
	editor._press_moved = true
	editor._drag_to(Vector2i(3, 0))
	editor._drag_to(Vector2i.ZERO)
	editor._on_left_released(false)
	assert_false(editor.history.can_undo())
	assert_false(main._dirty)


func test_view_refresh_keeps_the_placing_tool() -> void:
	editor.begin_place({"type": "lamp"})
	main._update_mode_ui()
	assert_eq(editor.tool, SchematicEditor.Tool.PLACE)


func test_undo_keeps_the_check_results() -> void:
	_example(0)
	main._check_panel.run(main.edit_doc)
	main._check_panel.show()
	editor.number_wires()
	editor.undo()
	assert_true(main._check_panel.visible)
	main._new_document()
	assert_false(main._check_panel.visible, "another schematic has no results yet")


func test_restore_offers_the_next_copy() -> void:
	var paths: PackedStringArray = PackedStringArray()
	for name: String in ORPHANS:
		var path: String = RecoveryFile.DIR.path_join(name + "." + ProjectFile.EXTENSION)
		RecoveryFile.write(SchematicDocument.new(name), "", path)
		paths.append(path)
	main._recovery_path = paths[0]
	main._restore_recovery()
	assert_true(main._recovery_dialog.visible, "the other copy is offered")
	assert_ne(main._recovery_path, paths[0])
	main._recovery_dialog.hide()


func test_plc_and_page_windows_follow_the_language() -> void:
	_example(ExampleCircuits.TITLES.find("PLC: start/stop with an on-delay"))
	var plc_window: PlcWindow = main.open_plc_window(_first(main.edit_doc, Plc).id)
	var page_window: PageWindow = main.open_page_window(0)
	var plc_title: String = plc_window.title
	TranslationServer.set_locale("cs")
	main._retranslate()
	var page_title: String = page_window.title
	var plc_now: String = plc_window.title
	TranslationServer.set_locale("en")
	main._retranslate()
	assert_true(page_title.begins_with("Stránka 1"), page_title)
	assert_ne(plc_now, plc_title)
