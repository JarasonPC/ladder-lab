class_name TrainingPanel
extends PanelContainer
## A training plan being wired (see [TrainingPlan]), beside the schematic and
## the workspace: what to do, how many wires are laid, and Check wiring,
## which says whether the wiring is right and, where the plan lets it, lists
## the mistakes (a click on one opens its place).

## Check wiring was clicked.
signal check_requested
## A mistake was clicked: the "place|port" ids it names.
signal problem_selected(ports: PackedStringArray)

var _box: VBoxContainer
var _count: Label
var _result: VBoxContainer
## The last check ({} before the first, see [method TrainingCheck.run]) and
## whether the plan lists the mistakes.
var _last: Dictionary = {}
var _show_errors: bool = true
var _wires: int = 0
## The checks made and when the first wire was laid (see [TrainingPlan]).
var _history: Array[Dictionary] = []
var _started: int = 0
## The student mounts the parts first (see [member TrainingPlan.mount_parts]).
var _mount: bool = false


func _ready() -> void:
	theme_type_variation = "RightPanel"
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_box)
	rebuild()


## Shows the plan of [param doc] (its wires counted); a check made before
## stays until [method show_result] or [method clear_result].
func show_plan(doc: SchematicDocument) -> void:
	_show_errors = doc == null or doc.training == null or doc.training.show_errors
	_wires = doc.training.wire_count() if doc != null and doc.training != null else 0
	_history = []
	_started = 0
	_mount = doc != null and doc.training != null and doc.training.mount_parts
	if doc != null and doc.training != null:
		_history = doc.training.history
		_started = doc.training.started
	rebuild()


## Shows [param result] of [method TrainingCheck.run].
func show_result(result: Dictionary) -> void:
	_last = result
	rebuild()


## Drops the check shown (the wiring changed since).
func clear_result() -> void:
	_last = {}
	rebuild()


func rebuild() -> void:
	if _box == null:
		return
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	var title: Label = Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = tr("Training: wiring")
	_box.add_child(title)
	var text: Label = Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = tr("Wire the switchboard, the back of its door and the control stations by the schematic. Open them on the workspace; the cables between them are laid, land their cores. Then check the wiring, or try it in Simulate: it runs as you wired it.")
	if _mount:
		text.text = tr("Mount the parts in the switchboard, on its door and on the control stations (the tools beside each list what belongs there), then wire them by the schematic. Open them on the workspace; the cables between them are laid, land their cores. Then check the work, or try it in Simulate: it runs as you wired it.")
	_box.add_child(text)
	_count = Label.new()
	_count.theme_type_variation = "MutedLabel"
	_count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_count.text = tr_n("%d wire laid", "%d wires laid", _wires) % _wires
	_box.add_child(_count)
	if not _history.is_empty():
		# For the teacher: how many checks, how the last one went, how long.
		var record: Label = Label.new()
		record.theme_type_variation = "MutedLabel"
		record.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		record.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var last: Dictionary = _history[_history.size() - 1]
		var lines: PackedStringArray = [tr_n("Checked %d time", "Checked %d times", _history.size()) % _history.size()]
		lines.append(tr("last: right") if last["ok"] else tr_n("last: %d mistake", "last: %d mistakes", last["mistakes"]) % last["mistakes"])
		if _started > 0:
			var minutes: int = maxi(roundi((last["at"] - _started) / 60.0), 0)
			lines.append(tr_n("%d minute from the first wire to the last check", "%d minutes from the first wire to the last check", minutes) % minutes)
		record.text = "\n".join(lines)
		_box.add_child(record)
	var check: Button = Button.new()
	check.theme_type_variation = "PrimaryButton"
	check.text = tr("Check wiring")
	check.icon = AppTheme.icon("check")
	check.pressed.connect(func() -> void: check_requested.emit())
	_box.add_child(check)
	if _last.is_empty():
		return
	_result = VBoxContainer.new()
	_result.add_theme_constant_override("separation", 4)
	_box.add_child(_result)
	var verdict: Label = Label.new()
	verdict.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verdict.add_theme_font_override("font", AppTheme.bold_font())
	var problems: Array = _last["problems"]
	if _last["ok"]:
		verdict.text = tr("The wiring is right.")
		verdict.add_theme_color_override("font_color", AppTheme.success)
	else:
		verdict.text = tr_n("Not right yet: %d mistake.", "Not right yet: %d mistakes.", problems.size()) % problems.size()
		verdict.add_theme_color_override("font_color", AppTheme.danger)
	_result.add_child(verdict)
	if not _show_errors:
		return
	for problem: Dictionary in problems:
		var row: Button = Button.new()
		row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.theme_type_variation = "ListButton"
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(160, 0)
		row.text = tr(problem["text"]) % problem["args"]
		var ports: PackedStringArray = problem["ports"]
		row.pressed.connect(func() -> void: problem_selected.emit(ports))
		_result.add_child(row)
