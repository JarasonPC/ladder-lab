class_name TrainingPanel
extends PanelContainer
## A training plan being wired (see [TrainingPlan]), beside the schematic and
## the workspace: what to do, how many wires are laid, and Check wiring,
## which says whether the wiring is right and, where the plan lets it, lists
## the mistakes (a click on one opens its place). While it runs in Simulate,
## a multimeter measures between two terminals (see [Multimeter]).

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
## The plan runs in Simulate: the multimeter is offered.
var simulating: bool = false:
	set(value):
		if value != simulating:
			simulating = value
			rebuild()
## What the multimeter shows: called with no arguments, returns the reading
## as shown ("" while a probe is not on a terminal).
var reading: Callable
var _display: Label
var _probe_text: Label
var _since_read: float = 0.0
## Readings a second.
const READ_RATE: float = 8.0


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


## The multimeter: measuring on or off, volts or ohms, where the probes
## are and what it reads.
func _meter() -> void:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "FunctionCard"
	_box.add_child(card)
	var fields: VBoxContainer = VBoxContainer.new()
	fields.add_theme_constant_override("separation", 6)
	card.add_child(fields)
	var on: Button = Button.new()
	on.toggle_mode = true
	on.focus_mode = Control.FOCUS_NONE
	on.icon = AppTheme.icon("meter")
	on.text = tr("Multimeter")
	on.tooltip_text = tr("While it is on, a click on a terminal puts a probe on it (red, then black) instead of operating the part")
	on.button_pressed = TrainingPick.probing
	on.toggled.connect(func(pressed: bool) -> void:
		TrainingPick.probing = pressed
		rebuild())
	fields.add_child(on)
	if not TrainingPick.probing:
		return
	var modes: HBoxContainer = HBoxContainer.new()
	modes.add_theme_constant_override("separation", 2)
	fields.add_child(modes)
	var group: ButtonGroup = ButtonGroup.new()
	for ohms: bool in [false, true]:
		var mode: Button = Button.new()
		mode.theme_type_variation = "SegmentButton"
		mode.toggle_mode = true
		mode.button_group = group
		mode.focus_mode = Control.FOCUS_NONE
		mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode.text = tr("Resistance Ω") if ohms else tr("Voltage V")
		mode.tooltip_text = tr("Switch the supply off first: with voltage there the meter shows —") if ohms else tr("AC or DC, as it finds")
		mode.button_pressed = TrainingPick.ohms == ohms
		mode.pressed.connect(func() -> void: TrainingPick.ohms = ohms)
		modes.add_child(mode)
	_display = Label.new()
	_display.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_display.add_theme_font_size_override("font_size", 30)
	_display.add_theme_font_override("font", AppTheme.bold_font())
	fields.add_child(_display)
	_probe_text = Label.new()
	_probe_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_probe_text.theme_type_variation = "MutedLabel"
	_probe_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(_probe_text)
	_read()


func _process(delta: float) -> void:
	if _display == null or not is_instance_valid(_display) or not is_visible_in_tree():
		return
	_since_read += delta
	if _since_read >= 1.0 / READ_RATE:
		_read()


## Shows what the meter reads and where its probes are.
func _read() -> void:
	_since_read = 0.0
	if _display == null or not is_instance_valid(_display):
		return
	var shown: String = reading.call() if reading.is_valid() else ""
	_display.text = shown if not shown.is_empty() else "- - -"
	var lines: PackedStringArray = PackedStringArray()
	var names: PackedStringArray = [tr("Red"), tr("Black")]
	for i: int in 2:
		var id: String = TrainingPick.probes[i]
		var where: String = tr("click a terminal")
		if not id.is_empty():
			where = id.get_slice("|", 0) + " " + TrainingPick.port_text(id.substr(id.find("|") + 1))
		lines.append("%s: %s" % [names[i], where])
	_probe_text.text = "\n".join(lines)


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
	_display = null
	_probe_text = null
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
	if simulating:
		_meter()
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
