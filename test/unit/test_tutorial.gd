extends GutTest
## Lessons, the interface tour and the welcome card in the main window: a
## lesson starts on its own schematic, ticks its steps as the drawing and
## the simulation get there, rings what it is about, checks its goals and
## ends with another schematic; the tour shows every stop and waits for
## Simulate; the welcome card asks the language first and is offered once.

const Main: GDScript = preload("res://ui/main.gd")
const MAIN_SCENE: String = "res://main.tscn"
const SETTINGS: String = "user://settings.cfg"

var main: Main
var editor: SchematicEditor
var _settings: String = ""
var _had_settings: bool = false
var _locale: String = ""


func before_all() -> void:
	_had_settings = FileAccess.file_exists(SETTINGS)
	if _had_settings:
		_settings = FileAccess.get_file_as_string(SETTINGS)
	_locale = TranslationServer.get_locale()


func after_all() -> void:
	if _had_settings:
		var file: FileAccess = FileAccess.open(SETTINGS, FileAccess.WRITE)
		file.store_string(_settings)
		file.close()
	elif FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(SETTINGS)
	RecoveryFile.forget()
	TranslationServer.set_locale(_locale)
	get_tree().auto_accept_quit = true


func before_each() -> void:
	main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	add_child_autofree(main)
	main._recovery_dialog.hide()
	editor = main.editor
	TranslationServer.set_locale("en")


## Puts [param doc] in place as the lesson's schematic (as drawn by hand).
func _draw_lesson_schematic(doc: SchematicDocument) -> void:
	main._starting_lesson = true
	main._replace_document(doc, "")
	main._starting_lesson = false
	main._on_lesson_edited()


func test_lesson_starts_on_its_own_schematic() -> void:
	main._begin_lesson(1)
	assert_not_null(main._lesson_run)
	assert_eq(main._lesson_run.lesson.id, "start_stop")
	assert_true(main._lesson_bar.visible)
	assert_true(main.edit_doc.circuit.has_component_id("L1"))
	assert_true(main.edit_doc.circuit.has_component_id("N"))
	assert_eq(main._lesson_run.selected, 0)
	assert_false(main._dirty, "an untouched lesson leaves nothing to save")


func test_drawing_ticks_and_undo_unticks_a_step() -> void:
	main._begin_lesson(1)
	editor.history.record(DocumentSerializer.to_dict(main.edit_doc))
	main.edit_doc.add(PushButton.new("SB1", SwitchingElement.ContactType.NC), Vector2i(4, 4))
	editor._changed()
	assert_true(main._lesson_run.done[0])
	assert_eq(main._lesson_run.selected, 1, "the next step is shown")
	editor.undo()
	assert_false(main._lesson_run.done[0])
	assert_eq(main._lesson_run.selected, 0)


func test_steps_while_simulating_stay_done() -> void:
	main._begin_lesson(0)
	_draw_lesson_schematic(Lessons.lamp_and_switch().solution.call())
	var run: LessonRun = main._lesson_run
	assert_eq(run.current(), 7, "every drawing step done")
	main._switch_mode(Main.Mode.SIMULATE)
	assert_true(run.done[7], "switched to Simulate")
	assert_false(run.done[8])
	main.view.toggle_switch("RB1")
	main.view.step_once(0.2)
	assert_true(run.done[8], "the lamp lit")
	main._switch_mode(Main.Mode.EDIT)
	assert_true(run.done[7])
	assert_true(run.done[8])
	assert_eq(run.current(), -1)


func test_check_finishes_the_lesson() -> void:
	main._begin_lesson(1)
	main._check_lesson()
	assert_false(main._lesson_run.passed())
	assert_false(main._finished_lessons.has("start_stop"))
	_draw_lesson_schematic(Lessons.start_stop().solution.call())
	assert_true(main._lesson_run.results.is_empty(), "an edit drops the results")
	main._check_lesson()
	assert_true(main._lesson_run.passed())
	assert_true(main._finished_lessons.has("start_stop"))
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS)
	assert_has(config.get_value("tutorial", "finished", PackedStringArray()), "start_stop")


func test_failed_goal_rings_its_parts() -> void:
	main._begin_lesson(1)
	var doc: SchematicDocument = Lessons.start_stop().solution.call()
	doc.remove_wire(doc.wire_between("SB2:14", "KM1:14"))
	_draw_lesson_schematic(doc)
	main._check_lesson()
	assert_eq(main._lesson_panel.failed_roles(), PackedStringArray(["start", "coil"]))
	assert_has(main._lesson_marks._rings, "KM1")
	main._lesson_panel.show_where = false
	main._refresh_lesson_marks()
	assert_does_not_have(main._lesson_marks._rings, "KM1")


func test_show_me_draws_the_missing_parts_and_wires() -> void:
	main._begin_lesson(1)
	var run: LessonRun = main._lesson_run
	assert_eq(main._lesson_marks.get_child_count(), 0)
	main._lesson_panel.show_me = true
	main._refresh_lesson_marks()
	assert_eq(main._lesson_marks.get_child_count(), 1, "the stop button drawn faintly")
	run.selected = 3
	main._refresh_lesson_marks()
	assert_eq(main._lesson_marks._ghost_wires.size(), 4, "the four wires of the row")
	assert_eq(main._lesson_marks.get_child_count(), 3, "and the parts they lead to")
	main._switch_mode(Main.Mode.SIMULATE)
	assert_eq(main._lesson_marks.get_child_count(), 0, "never while simulating")


func test_every_palette_step_finds_its_entry() -> void:
	for lesson: Lesson in Lessons.all():
		for s: Lesson.Step in lesson.steps:
			if s.palette.is_empty():
				continue
			var button: Button = main._palette.entry_button(s.palette)
			assert_not_null(button, "%s: %s" % [lesson.id, s.title])


func test_another_schematic_ends_the_lesson() -> void:
	main._begin_lesson(0)
	main._new_document()
	assert_null(main._lesson_run)
	assert_false(main._lesson_bar.visible)
	assert_eq(main._lesson_rings.targets.size(), 0)


func test_lesson_panel_builds_in_every_state() -> void:
	for i: int in Lessons.all().size():
		main._begin_lesson(i)
		_draw_lesson_schematic(main._lesson_run.lesson.solution.call())
		main._check_lesson()
		assert_true(main._lesson_run.passed(), main._lesson_run.lesson.id)
		for s: int in main._lesson_run.lesson.steps.size():
			main._lesson_run.selected = s
			main._lesson_panel.rebuild()
		TranslationServer.set_locale("cs")
		main._lesson_panel.rebuild()
		TranslationServer.set_locale("en")
	assert_eq(main._finished_lessons.size(), Lessons.all().size())
	# The panels built again are freed by the next frame.
	await wait_process_frames(2)


func test_tour_shows_every_stop_and_puts_the_mode_back() -> void:
	# Room for the drawing between the panels, as in a real window.
	var size: Vector2i = get_tree().root.size
	get_tree().root.size = Vector2i(1440, 900)
	main.start_tour()
	assert_true(main._tour.visible)
	var tour: TourOverlay = main._tour
	for i: int in tour.steps.size():
		tour.show_step(i)
		await wait_process_frames(2)
		var s: TourOverlay.Step = tour.steps[i]
		if s.target.is_valid():
			assert_true((s.target.call() as Rect2).has_area(), "stop %d is shown: %s" % [i, s.target.call()])
	main._switch_mode(Main.Mode.EDIT)
	tour.show_step(4)
	assert_eq(main.mode, Main.Mode.EDIT)
	assert_true(tour._waiting_box.visible, "waits for Simulate")
	tour._on_next()
	assert_eq(main.mode, Main.Mode.SIMULATE, "Next clicked Simulate")
	tour.show_step(tour.steps.size() - 1)
	tour._on_next()
	assert_false(tour.visible)
	assert_eq(main.mode, Main.Mode.EDIT, "back in Edit as before")
	get_tree().root.size = size


func test_esc_leaves_the_tour() -> void:
	main.start_tour()
	var esc: InputEventKey = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	main._tour._input(esc)
	assert_false(main._tour.visible)


func test_welcome_is_answered_once() -> void:
	main._welcomed = false
	main._welcome.show()
	main._answer_welcome()
	assert_false(main._welcome.visible)
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS)
	assert_true(config.get_value("tutorial", "welcomed", false))


# --- The lessons followed in the editor, as their texts say -----------------------------

## Places a part from the palette entry of [param template] at [param cell]
## and stops placing (right click); returns its designation.
func _place(template: Dictionary, cell: Vector2i) -> String:
	var button: Button = main._palette.entry_button(template)
	button.pressed.emit()
	editor._place_at(cell)
	var placed: String = editor.selected_components.keys()[0]
	editor._cancel_tool()
	return main.edit_doc.circuit.get_component(placed).designation


## Draws a wire from terminal [param a] to terminal [param b].
func _wire(a: String, b: String) -> void:
	editor._start_wire(a)
	editor._mouse_cell = main.edit_doc.terminal_cell(b)
	editor._mouse_point = Vector2(editor._mouse_cell)
	editor._finish_wire(b, -1)
	assert_true(main.edit_doc.wire_between(a, b) >= 0, "wire %s - %s" % [a, b])


## Clicks part [param id] (selects it alone).
func _select(id: String) -> void:
	editor._clear_selection()
	editor.selected_components[main.edit_doc.circuit.get_component(id).id] = true
	editor._selection_updated()


## Sets [param values] in the properties of part [param id].
func _set_properties(id: String, values: Dictionary) -> void:
	var data: Dictionary = DocumentSerializer.component_to_dict(main.edit_doc.circuit.get_component(id))
	data.merge(values, true)
	assert_eq(editor.apply_properties(main.edit_doc.circuit.get_component(id).id, data), "")


func _simulate(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		main.view.step_once(0.05)
		t += 0.05


func _expect_current(step: int) -> void:
	assert_eq(main._lesson_run.current(), step, "%s: next step %d" % [main._lesson_run.lesson.id, step])


func test_lesson_1_followed_in_the_editor() -> void:
	main._begin_lesson(0)
	assert_eq(_place(Lessons.SUPPLY_L, Vector2i(4, 1)), "L1")
	assert_eq(_place(Lessons.SUPPLY_N, Vector2i(4, 16)), "N")
	assert_eq(_place(Lessons.SWITCH_NO, Vector2i(4, 4)), "RB1")
	assert_eq(_place(Lessons.LAMP, Vector2i(4, 10)), "H1")
	_expect_current(4)
	_wire("L1", "RB1:13")
	_wire("RB1:14", "H1:X1")
	_wire("H1:X2", "N")
	_expect_current(7)
	main._switch_mode(Main.Mode.SIMULATE)
	main.view.toggle_switch("RB1")
	_simulate(0.2)
	_expect_current(-1)
	main._switch_mode(Main.Mode.EDIT)
	main._check_lesson()
	assert_true(main._lesson_run.passed())


func test_lesson_2_followed_in_the_editor() -> void:
	main._begin_lesson(1)
	assert_eq(_place(Lessons.BUTTON_NC, Vector2i(4, 4)), "SB1")
	assert_eq(_place(Lessons.BUTTON_NO, Vector2i(4, 10)), "SB2")
	assert_eq(_place(Lessons.COIL, Vector2i(4, 16)), "KM1")
	_wire("L1", "SB1:11")
	_wire("SB1:12", "SB2:13")
	_wire("SB2:14", "KM1:A1")
	_wire("KM1:A2", "N")
	_expect_current(4)
	main._switch_mode(Main.Mode.SIMULATE)
	main.view.hold_button("SB2", true)
	_simulate(0.3)
	main.view.hold_button("SB2", false)
	_simulate(0.3)
	_expect_current(5)
	main._switch_mode(Main.Mode.EDIT)
	var hold: String = _place(Lessons.CONTACT_NO, Vector2i(8, 10))
	assert_eq(hold, "KM1")
	assert_true(main.edit_doc.circuit.has_component_id("KM1:13-14"), "the self-holding contact is 13-14")
	_wire("KM1:13", "SB2:13")
	_wire("KM1:14", "SB2:14")
	_expect_current(7)
	_place(Lessons.CONTACT_NO, Vector2i(12, 10))
	assert_true(main.edit_doc.circuit.has_component_id("KM1:23-24"), "the second contact is 23-24")
	assert_eq(_place(Lessons.LAMP, Vector2i(12, 16)), "H1")
	_wire("L1", "KM1:23")
	_wire("KM1:24", "H1:X1")
	_wire("H1:X2", "N")
	_expect_current(9)
	main._switch_mode(Main.Mode.SIMULATE)
	main.view.hold_button("SB2", true)
	_simulate(0.3)
	main.view.hold_button("SB2", false)
	_simulate(0.3)
	_expect_current(-1)
	main._switch_mode(Main.Mode.EDIT)
	main._check_lesson()
	assert_true(main._lesson_run.passed())


func test_lesson_3_followed_in_the_editor() -> void:
	main._begin_lesson(2)
	assert_eq(_place(Lessons.SWITCH_NO, Vector2i(4, 4)), "RB1")
	assert_eq(_place(Lessons.TIMER, Vector2i(4, 10)), "KT1")
	_wire("L1", "RB1:13")
	_wire("RB1:14", "KT1:A1")
	_wire("KT1:A2", "N")
	_expect_current(3)
	_select("KT1")
	assert_eq(_place(Lessons.CONTACT_NO, Vector2i(10, 4)), "KT1")
	assert_true(main.edit_doc.circuit.has_component_id("KT1:17-18"), "the delayed contact is 17-18")
	assert_eq(_place(Lessons.LAMP, Vector2i(10, 10)), "H1")
	_wire("L1", "KT1:17")
	_wire("KT1:18", "H1:X1")
	_wire("H1:X2", "N")
	_expect_current(5)
	main._switch_mode(Main.Mode.SIMULATE)
	main.view.toggle_switch("RB1")
	_simulate(3.5)
	_expect_current(6)
	main._switch_mode(Main.Mode.EDIT)
	_set_properties("KT1", {"delay": 5.0})
	_expect_current(-1)
	main._check_lesson()
	assert_true(main._lesson_run.passed())


func test_lesson_4_followed_in_the_editor() -> void:
	main._begin_lesson(3)
	assert_eq(_place(Lessons.BREAKER, Vector2i(5, 2)), "FA1")
	_expect_current(0)
	_set_properties("FA1", {"poles": 3})
	_expect_current(1)
	assert_eq(_place(Lessons.MAIN_CONTACTS, Vector2i(5, 7)), "KM1")
	assert_eq(_place(Lessons.OVERLOAD_RELAY, Vector2i(5, 12)), "F1")
	assert_eq(_place(Lessons.MOTOR3, Vector2i(5, 17)), "M1")
	var poles: Array = [["L1", "1", "U1"], ["L2", "3", "V1"], ["L3", "5", "W1"]]
	for p: Array in poles:
		var out: String = str(int(p[1]) + 1)
		_wire(p[0], "FA1:" + p[1])
		_wire("FA1:" + out, "KM1:" + p[1])
		_wire("KM1:" + out, "F1:" + p[1])
		_wire("F1:" + out, "M1:" + p[2])
	_expect_current(5)
	var feed: int = main.edit_doc.wire_between("L1.2", "SB1:11")
	editor._clear_selection()
	editor.selected_wires[feed] = true
	editor.delete_selection()
	_select("F1")
	assert_eq(_place(Lessons.CONTACT_NC, Vector2i(18, 3)), "F1")
	assert_true(main.edit_doc.circuit.has_component_id("F1:95-96"), "the overload contact is 95-96")
	_wire("L1.2", "F1:95")
	_wire("F1:96", "SB1:11")
	_expect_current(6)
	main._switch_mode(Main.Mode.SIMULATE)
	main.view.operate_device("FA1")
	main.view.hold_button("SB2", true)
	_simulate(0.3)
	main.view.hold_button("SB2", false)
	_simulate(3.0)
	_expect_current(7)
	main.view.operate_device("F1")
	_simulate(0.3)
	_expect_current(-1)
	main._switch_mode(Main.Mode.EDIT)
	main._check_lesson()
	assert_true(main._lesson_run.passed())


func test_the_tour_ticks_no_lesson_step() -> void:
	main._begin_lesson(0)
	main.start_tour()
	main._tour.show_step(4)
	main._tour._on_next()
	main.view.step_once(0.1)
	assert_eq(main.mode, Main.Mode.SIMULATE)
	assert_false(main._lesson_run.done[7], "Simulate clicked by the tour")
	main._tour.stop(false)
	assert_eq(main.mode, Main.Mode.EDIT)


func test_tour_started_again_from_its_last_stop_puts_back_the_first_mode() -> void:
	main.start_tour()
	main._tour.show_step(6)
	main._tour.show_step(main._tour.steps.size() - 1)
	assert_eq(main.mode, Main.Mode.SIMULATE, "the tour simulates from its sixth stop on")
	main.start_tour()
	main._tour.stop(true)
	assert_eq(main.mode, Main.Mode.EDIT)


func test_welcome_asks_the_language_first() -> void:
	main._welcomed = false
	var welcome: WelcomeCard = main._welcome
	assert_true(welcome.asking_language(), "the language before the tour and the lesson")
	assert_false(welcome._tour.is_visible_in_tree())
	var czech: Button = welcome._language_page.get_child(2).get_child(1)
	assert_eq(czech.text, "Čeština")
	czech.pressed.emit()
	assert_eq(TranslationServer.get_locale(), "cs")
	assert_eq(main._locale_index, 1)
	assert_false(welcome.asking_language())
	assert_eq(welcome._tour.text, "Projít prohlídku", "offered in the language chosen")
	assert_false(main._welcomed, "answered only with the tour, the lesson or Not now")
	TranslationServer.set_locale("en")
