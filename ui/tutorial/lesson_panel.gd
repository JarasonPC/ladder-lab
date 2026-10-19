class_name LessonPanel
extends PanelContainer
## The lesson being taken, beside the schematic: its steps (each ticked by
## itself when it is done, the one shown in full with Show me), the
## progress, and Check, which runs the circuit and says which goals it
## meets, with a test run chart of the first one it does not. Built again
## from the [LessonRun] whenever something changes.

signal closed
## Another lesson, by its index in [method Lessons.all].
signal lesson_chosen(index: int)
signal restart_requested
signal check_requested
## Another step was shown in full (or Show me / Show where switched).
signal marks_changed

var run: LessonRun = null
## Index of the lesson in [method Lessons.all] and how many there are.
var index: int = 0
var count: int = 1
## Ids of the lessons finished before.
var finished: Dictionary[String, bool] = {}
## Show me is on: the step's parts and wires are drawn where they belong.
var show_me: bool = false
## Show where is on: the parts of the goal not met are ringed.
var show_where: bool = true

var _box: VBoxContainer
var _lessons_menu: MenuButton


func _ready() -> void:
	theme_type_variation = "RightPanel"
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	add_child(_box)
	rebuild()


## Shows [param p_run], lesson [param p_index] of [param p_count].
func show_run(p_run: LessonRun, p_index: int, p_count: int) -> void:
	run = p_run
	index = p_index
	count = p_count
	show_me = false
	show_where = true
	rebuild()


## Roles of the goal that failed first after a check (to ring them), or [].
func failed_roles() -> PackedStringArray:
	var roles: PackedStringArray = PackedStringArray()
	if run == null:
		return roles
	for r: Dictionary in run.results:
		if not r["passed"]:
			for row: Dictionary in r["rows"]:
				roles.append(row["role"])
			break
	return roles


func rebuild() -> void:
	if _box == null:
		return
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	if run == null:
		return
	_build_header()
	_build_steps()
	_box.add_child(HSeparator.new())
	_build_check()
	_build_footer()


func _build_header() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_box.add_child(row)
	var back: Button = _icon_button(row, "chevron_left", tr("Previous lesson"))
	back.disabled = index <= 0
	back.pressed.connect(func() -> void: lesson_chosen.emit(index - 1))
	var which: Label = _label(row, tr("Lesson %d of %d") % [index + 1, count], "HeaderLabel")
	which.text = which.text.to_upper()
	which.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var forward: Button = _icon_button(row, "chevron_right", tr("Next lesson"))
	forward.disabled = index >= count - 1
	forward.pressed.connect(func() -> void: lesson_chosen.emit(index + 1))
	var rest: Control = Control.new()
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rest)
	var close: Button = _icon_button(row, "close", tr("Close the lesson"))
	close.pressed.connect(func() -> void: closed.emit())

	var title: Label = _label(_box, tr(run.lesson.title), "TitleLabel")
	title.add_theme_font_size_override("font_size", 17)
	var summary: Label = _label(_box, tr(run.lesson.summary), "MutedLabel")
	summary.add_theme_font_size_override("font_size", AppTheme.FONT_SIZE - 1)
	var progress: Control = Control.new()
	progress.custom_minimum_size = Vector2(0, 6)
	var share: float = float(run.count_done()) / float(maxi(run.lesson.steps.size(), 1))
	progress.draw.connect(func() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, progress.size)
		progress.draw_rect(r, AppTheme.bg3)
		if share > 0.0:
			progress.draw_rect(Rect2(r.position, Vector2(r.size.x * share, r.size.y)), AppTheme.tutorial))
	_box.add_child(progress)
	_label(_box, tr("%d of %d steps done") % [run.count_done(), run.lesson.steps.size()], "MutedLabel")


func _build_steps() -> void:
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	_box.add_child(list)
	var current: int = run.current()
	for i: int in run.lesson.steps.size():
		var s: Lesson.Step = run.lesson.steps[i]
		var open: bool = i == run.selected
		var item: PanelContainer = PanelContainer.new()
		item.theme_type_variation = "LessonStep" if open else ""
		if not open:
			item.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		list.add_child(item)
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		item.add_child(column)
		var head: HBoxContainer = HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		head.custom_minimum_size = Vector2(0, 34)
		head.mouse_filter = Control.MOUSE_FILTER_STOP
		head.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		head.tooltip_text = tr("Show this step")
		head.gui_input.connect(func(event: InputEvent) -> void:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and run.selected != i:
				run.selected = i
				show_me = false
				rebuild()
				marks_changed.emit())
		column.add_child(head)
		var margin: Control = Control.new()
		margin.custom_minimum_size = Vector2(2, 0)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(margin)
		head.add_child(_badge(i + 1, run.done[i], i == current))
		var title: Label = _label(head, tr(s.title), "")
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if open:
			title.add_theme_font_override("font", AppTheme.bold_font())
		elif run.done[i]:
			title.add_theme_color_override("font_color", AppTheme.text_muted)
		if open:
			_build_details(column, s, run.done[i])


func _build_details(column: VBoxContainer, s: Lesson.Step, done: bool) -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	column.add_child(margin)
	var details: VBoxContainer = VBoxContainer.new()
	details.add_theme_constant_override("separation", 10)
	margin.add_child(details)
	_label(details, tr(s.text), "")
	if not s.hint.is_empty():
		var tip: PanelContainer = PanelContainer.new()
		tip.theme_type_variation = "HintBox"
		details.add_child(tip)
		var tip_row: HBoxContainer = HBoxContainer.new()
		tip_row.add_theme_constant_override("separation", 8)
		tip.add_child(tip_row)
		var bulb: TextureRect = TextureRect.new()
		bulb.texture = AppTheme.icon("hint", 16, AppTheme.tutorial_hover if AppTheme.variant == AppTheme.Variant.DARK else AppTheme.tutorial)
		bulb.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		bulb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tip_row.add_child(bulb)
		_label(tip_row, tr(s.hint), "").add_theme_font_size_override("font_size", AppTheme.SMALL_FONT_SIZE + 1)
	var drawn: bool = not s.show.is_empty() or not s.wires.is_empty()
	if drawn and not done:
		var show: Button = Button.new()
		show.theme_type_variation = "TutorialButton"
		show.focus_mode = Control.FOCUS_NONE
		show.toggle_mode = true
		show.button_pressed = show_me
		show.text = tr("Hide") if show_me else tr("Show me")
		show.tooltip_text = tr("Draw where the parts and wires of this step go")
		show.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		show.toggled.connect(func(on: bool) -> void:
			show_me = on
			show.text = tr("Hide") if on else tr("Show me")
			marks_changed.emit())
		details.add_child(show)
	var note: String
	if done:
		note = tr("Done.")
	elif s.simulating:
		note = tr("Ticked by itself as soon as it happens while simulating.")
	else:
		note = tr("Ticked by itself as soon as the drawing has it.")
	_label(details, note, "MutedLabel")


func _build_check() -> void:
	_label(_box, tr("Check your circuit"), "TitleLabel")
	_label(_box, tr("Runs the circuit and tests what it should do."), "MutedLabel")
	var check: Button = Button.new()
	check.theme_type_variation = "TutorialButton"
	check.focus_mode = Control.FOCUS_NONE
	check.icon = AppTheme.icon("check")
	check.text = tr("Check again") if not run.results.is_empty() else tr("Check circuit")
	check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	check.pressed.connect(func() -> void: check_requested.emit())
	_box.add_child(check)
	if run.results.is_empty():
		return
	var met: int = 0
	for r: Dictionary in run.results:
		if r["passed"]:
			met += 1
	var goals: int = run.results.size()
	var headline: Label = _label(_box, tr("All goals met. Lesson complete!") if met == goals else tr("%d of %d goals met") % [met, goals], "TitleLabel")
	headline.add_theme_color_override("font_color", AppTheme.success if met == goals else AppTheme.text)
	var first_failed: bool = true
	for g: int in goals:
		var r: Dictionary = run.results[g]
		var goal: Lesson.Goal = run.lesson.goals[g]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_box.add_child(row)
		var mark: TextureRect = TextureRect.new()
		mark.texture = AppTheme.icon("tick" if r["passed"] else "close", 16, AppTheme.success if r["passed"] else AppTheme.warning)
		mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(mark)
		var names: Array = []
		for role: String in goal.names:
			names.append(_designation(role))
		var text: Label = _label(row, tr(goal.title) % names, "")
		if not r["passed"] and first_failed:
			first_failed = false
			text.add_theme_font_override("font", AppTheme.bold_font())
			_build_failure(goal, r)
	if met == goals and index < count - 1:
		var next: Button = Button.new()
		next.theme_type_variation = "TutorialButton"
		next.focus_mode = Control.FOCUS_NONE
		next.text = tr("Next lesson")
		next.icon = AppTheme.icon("arrow_right")
		next.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		next.pressed.connect(func() -> void: lesson_chosen.emit(index + 1))
		_box.add_child(next)


## What went wrong in the first goal not met: the part that did not do what
## it should, the test run as a chart, and Show where.
func _build_failure(goal: Lesson.Goal, r: Dictionary) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "FunctionCard"
	_box.add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	if not str(r["missing"]).is_empty():
		_label(column, tr("Draw the parts of the steps above first."), "")
		return
	_label(column, failure_text(goal, r), "")
	var chart: TestRunChart = TestRunChart.new()
	chart.rows = r["rows"]
	chart.failed = r["phase"]
	chart.custom_minimum_size = Vector2(0, 18 + 24 * (r["rows"] as Array).size())
	column.add_child(chart)
	_label(column, tr("A dashed line shows what should have happened."), "MutedLabel")
	var steps: PackedStringArray = PackedStringArray()
	for i: int in goal.phases.size():
		steps.append("%d  %s" % [i + 1, phase_text(goal.phases[i])])
	_label(column, "\n".join(steps), "MutedLabel")
	var where: Button = Button.new()
	where.theme_type_variation = "TutorialButton"
	where.focus_mode = Control.FOCUS_NONE
	where.toggle_mode = true
	where.button_pressed = show_where
	where.text = tr("Hide where") if show_where else tr("Show where")
	where.tooltip_text = tr("Ring the parts of this test on the drawing")
	where.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	where.toggled.connect(func(on: bool) -> void:
		show_where = on
		where.text = tr("Hide where") if on else tr("Show where")
		marks_changed.emit())
	column.add_child(where)


## The sentence saying what went wrong in [param r], a result of [param goal].
func failure_text(goal: Lesson.Goal, r: Dictionary) -> String:
	if r["short"]:
		return tr("A short circuit stopped the test run at step %d.") % (r["phase"] + 1)
	var phase: int = r["phase"]
	for row: Dictionary in r["rows"]:
		var expected: Variant = (row["expected"] as Array)[phase]
		if expected == null or bool(expected) == bool((row["got"] as Array)[phase]):
			continue
		var text: String = tr("At step %d %s should be on, but it is off.") if expected else tr("At step %d %s should be off, but it is on.")
		return text % [phase + 1, row["label"]]
	return tr(goal.title)


## What phase [param phase] of a test run does, e.g. "press SB2".
func phase_text(phase: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for action: Array in phase.get("do", []):
		var who: String = _designation(action[0])
		match action[1]:
			"press":
				parts.append(tr("press %s") % who)
			"release":
				parts.append(tr("release %s") % who)
			"on":
				parts.append(tr("turn %s on") % who)
			"off":
				parts.append(tr("turn %s off") % who)
			"trip":
				parts.append(tr("trip %s") % who)
	var wait: float = float(phase.get("wait", 0.0))
	var timer: String = str(phase.get("wait_delay", ""))
	if not timer.is_empty():
		parts.append(tr("wait the delay of %s") % _designation(timer))
	elif wait > 0.0:
		parts.append(tr("wait %s s") % String.num(wait, 1))
	return ", ".join(parts)


func _build_footer() -> void:
	_box.add_child(HSeparator.new())
	var row: HBoxContainer = HBoxContainer.new()
	_box.add_child(row)
	var restart: Button = Button.new()
	restart.focus_mode = Control.FOCUS_NONE
	restart.text = tr("Start again")
	restart.icon = AppTheme.icon("reset")
	restart.tooltip_text = tr("Start the lesson again from its first step")
	restart.pressed.connect(func() -> void: restart_requested.emit())
	row.add_child(restart)
	var rest: Control = Control.new()
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rest)
	_lessons_menu = MenuButton.new()
	_lessons_menu.focus_mode = Control.FOCUS_NONE
	_lessons_menu.text = tr("All lessons")
	_lessons_menu.icon = AppTheme.icon("lesson")
	_lessons_menu.flat = true
	var popup: PopupMenu = _lessons_menu.get_popup()
	var lessons: Array[Lesson] = Lessons.all()
	for i: int in lessons.size():
		popup.add_check_item("%d. %s" % [i + 1, tr(lessons[i].title)], i)
		popup.set_item_checked(i, finished.has(lessons[i].id))
	popup.id_pressed.connect(func(id: int) -> void: lesson_chosen.emit(id))
	row.add_child(_lessons_menu)


## Designation of the part playing [param role] in the schematic, else the
## one the lesson gives it.
func _designation(role: String) -> String:
	if run.edited != null and run.edited.has(role):
		return run.edited.designation(role)
	return run.lesson.default_designation(role)


func _label(parent: Control, text: String, variation: String) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(60, 0)
	parent.add_child(label)
	return label


func _icon_button(parent: Control, icon_name: String, tip: String) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = "ToolButton"
	button.focus_mode = Control.FOCUS_NONE
	button.icon = AppTheme.icon(icon_name, 16)
	button.tooltip_text = tip
	parent.add_child(button)
	return button


## A step's number in a circle: filled with a tick when done, ringed in the
## tutorial colour when it is the next to do.
func _badge(number: int, done: bool, next: bool) -> Control:
	var badge: Control = Control.new()
	badge.custom_minimum_size = Vector2(22, 22)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func() -> void:
		var c: Vector2 = badge.size * 0.5
		if done:
			badge.draw_circle(c, 11.0, AppTheme.tutorial, true, -1.0, true)
			badge.draw_texture(AppTheme.icon("tick", 14, Color.WHITE), c - Vector2(7, 7))
			return
		badge.draw_circle(c, 10.0, AppTheme.tutorial if next else AppTheme.border_strong, false, 2.0 if next else 1.5, true)
		var font: Font = AppTheme.bold_font()
		var text: String = str(number)
		var size: int = AppTheme.SMALL_FONT_SIZE
		var w: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		badge.draw_string(font, c + Vector2(-w.x * 0.5, font.get_ascent(size) * 0.5 - 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, AppTheme.text if next else AppTheme.text_muted))
	return badge


## A test run of a goal: a row per part, on (high) or off (low) after each
## step of the run; where a part was expected otherwise, a dashed line shows
## what was expected, and the step that went wrong is shaded.
class TestRunChart:
	extends Control
	var rows: Array = []
	var failed: int = -1

	func _draw() -> void:
		var font: Font = AppTheme.ui_font()
		var size_px: int = AppTheme.SMALL_FONT_SIZE
		var phases: int = (rows[0]["got"] as Array).size() if not rows.is_empty() else 0
		if phases == 0:
			return
		var label_w: float = 44.0
		var top: float = 4.0
		var row_h: float = 24.0
		var plot: Rect2 = Rect2(label_w, top, size.x - label_w - 4.0, row_h * rows.size())
		var step_w: float = plot.size.x / phases
		if failed >= 0 and failed < phases:
			draw_rect(Rect2(plot.position.x + failed * step_w, plot.position.y - 2.0, step_w, plot.size.y + 4.0), Color(AppTheme.warning, 0.14))
		for i: int in phases:
			var x: float = plot.position.x + (i + 0.5) * step_w
			var n: String = str(i + 1)
			var nw: float = font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
			draw_string(font, Vector2(x - nw * 0.5, plot.end.y + 14.0), n, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, AppTheme.text_faint)
		for r: int in rows.size():
			var row: Dictionary = rows[r]
			var y_low: float = top + row_h * (r + 1) - 5.0
			var y_high: float = top + row_h * r + 7.0
			draw_string(font, Vector2(0.0, y_low), str(row["label"]), HORIZONTAL_ALIGNMENT_LEFT, label_w - 4.0, size_px, AppTheme.text_muted)
			var got: Array = row["got"]
			var expected: Array = row["expected"]
			var expecting: bool = expected.any(func(v: Variant) -> bool: return v != null)
			var line: Color = AppTheme.tutorial_hover if expecting else AppTheme.text_muted
			var points: PackedVector2Array = PackedVector2Array()
			for i: int in phases:
				var y: float = y_high if got[i] else y_low
				points.append(Vector2(plot.position.x + i * step_w, y))
				points.append(Vector2(plot.position.x + (i + 1) * step_w, y))
			draw_polyline(points, line, 2.0, true)
			for i: int in phases:
				if expected[i] == null or bool(expected[i]) == bool(got[i]):
					continue
				var y: float = y_high if expected[i] else y_low
				draw_dashed_line(Vector2(plot.position.x + i * step_w, y), Vector2(plot.position.x + (i + 1) * step_w, y), AppTheme.success, 2.0, 4.0)
