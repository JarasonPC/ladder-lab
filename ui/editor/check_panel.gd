class_name CheckPanel
extends PanelContainer
## Shows the result of [CircuitCheck]. Clicking an issue asks the editor to
## select the components involved.

signal issue_selected(ids: PackedStringArray)

var _title: Label
var _list: VBoxContainer
var _close: Button
var _issues: Array[Dictionary] = []


func _ready() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	add_child(box)
	var header: HBoxContainer = HBoxContainer.new()
	box.add_child(header)
	_title = Label.new()
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 16)
	header.add_child(_title)
	_close = Button.new()
	_close.text = "×"
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(hide)
	header.add_child(_close)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	hide()


## Runs the check on [param doc] and shows the result.
func run(doc: SchematicDocument) -> void:
	_issues = CircuitCheck.run(doc)
	for child: Node in _list.get_children():
		child.free()
	if _issues.is_empty():
		_title.text = tr("Check")
		_add_row(tr("No problems found."), PackedStringArray())
	else:
		_title.text = tr_n("Check: %d problem", "Check: %d problems", _issues.size()) % _issues.size()
		for issue: Dictionary in _issues:
			_add_row(tr(issue["text"]) % issue["args"], issue["ids"])
	show()


func _add_row(text: String, ids: PackedStringArray) -> void:
	var row: Button = Button.new()
	row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.text = text
	row.flat = true
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.custom_minimum_size = Vector2(200, 0)
	row.disabled = ids.is_empty()
	row.pressed.connect(func() -> void: issue_selected.emit(ids))
	_list.add_child(row)
