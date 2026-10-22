class_name FaultDialog
extends ConfirmationDialog
## Saving a schematic as a fault-finding task (see [TrainingFaults]): the
## faults to hide in its wiring, chosen one by one or at random, and
## whether the student is told which reports are right. The task is a
## training plan wired by the schematic ([method TrainingCheck.solution]).

## The task being made: a copy of the schematic, wired, with the faults.
var _task: SchematicDocument
var _errors: CheckBox
var _list: VBoxContainer
var _kind: OptionButton
var _target: OptionButton
var _choices: Array[Dictionary] = []
var _caption: Label
var _add_button: Button
var _random: Button


func _ready() -> void:
	min_size = Vector2i(520, 0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_caption = Label.new()
	_caption.theme_type_variation = "CaptionLabel"
	box.add_child(_caption)
	_list = VBoxContainer.new()
	box.add_child(_list)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	_kind = OptionButton.new()
	_kind.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for kind_title: String in TrainingFaults.KIND_TITLES:
		_kind.add_item(kind_title)
	_kind.item_selected.connect(func(_k: int) -> void: _fill_targets())
	row.add_child(_kind)
	_target = OptionButton.new()
	_target.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target.fit_to_longest_item = false
	_target.clip_text = true
	row.add_child(_target)
	_add_button = Button.new()
	_add_button.icon = AppTheme.icon("plus")
	_add_button.pressed.connect(func() -> void:
		if _target.selected >= 0 and _target.selected < _choices.size():
			_add(_choices[_target.selected]))
	row.add_child(_add_button)
	_random = Button.new()
	_random.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_random.pressed.connect(_add_random)
	box.add_child(_random)
	_errors = CheckBox.new()
	_errors.button_pressed = true
	box.add_child(_errors)
	retranslate()


func retranslate() -> void:
	if _caption == null:
		return
	title = tr("Save as fault-finding task")
	ok_button_text = tr("Save…")
	cancel_button_text = tr("Cancel")
	_caption.text = tr("Faults hidden in the wiring")
	for k: int in TrainingFaults.KIND_TITLES.size():
		_kind.set_item_text(k, tr(TrainingFaults.KIND_TITLES[k]))
	_add_button.text = tr("Add")
	_random.text = tr("Add a fault at random")
	_errors.text = tr("Tell the student which reports are right")
	_errors.tooltip_text = tr("Unticked, the student only learns when every fault is found")


## Opens the dialog for a task made of [param doc] (no faults chosen yet).
func open(doc: SchematicDocument) -> void:
	_task = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	_task.training = TrainingPlan.new()
	var wires: Dictionary[String, Array] = TrainingCheck.solution(_task)
	for place: String in wires:
		for wire: PackedStringArray in wires[place]:
			_task.training.add_wire(place, wire[0], wire[1], wire[2], wire[3])
	_fill_targets()
	_show_faults()
	popup_centered()


## The task to save: the schematic wired, the faults chosen hidden in it.
func task() -> SchematicDocument:
	_task.training.show_errors = _errors.button_pressed
	return _task


func _fill_targets() -> void:
	_choices = TrainingFaults.choices(_task, TrainingFaults.KINDS[maxi(_kind.selected, 0)])
	_target.clear()
	for choice: Dictionary in _choices:
		_target.add_item(TrainingFaults.text(choice))


func _add(fault: Dictionary) -> void:
	for kept: Dictionary in _task.training.faults:
		if TrainingFaults.same(kept, fault) or (fault["kind"] != "wire" and kept.get("id", "") == fault.get("id", "")):
			# One fault a part.
			return
	_task.training.faults.append(fault.duplicate())
	_show_faults()


## Adds a fault of a kind and a place chosen at random (one not hidden yet).
func _add_random() -> void:
	var all: Array[Dictionary] = []
	for kind: String in TrainingFaults.KINDS:
		all.append_array(TrainingFaults.choices(_task, kind))
	all.shuffle()
	var before: int = _task.training.faults.size()
	for fault: Dictionary in all:
		_add(fault)
		if _task.training.faults.size() > before:
			return


## The faults chosen, each with a button taking it away; OK only with one.
func _show_faults() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var faults: Array[Dictionary] = _task.training.faults
	for i: int in faults.size():
		var row: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%s: %s" % [tr(TrainingFaults.KIND_TITLES[TrainingFaults.KINDS.find(faults[i]["kind"])]), TrainingFaults.text(faults[i])]
		row.add_child(label)
		var remove: Button = Button.new()
		remove.icon = AppTheme.icon("delete")
		remove.theme_type_variation = "ToolButton"
		remove.tooltip_text = tr("Take this fault away")
		remove.pressed.connect(func() -> void:
			faults.remove_at(i)
			_show_faults())
		row.add_child(remove)
		_list.add_child(row)
	if faults.is_empty():
		var none: Label = Label.new()
		none.theme_type_variation = "MutedLabel"
		none.text = tr("No faults yet: add at least one.")
		_list.add_child(none)
	get_ok_button().disabled = faults.is_empty()
	reset_size()
