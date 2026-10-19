class_name EventLog
extends VBoxContainer
## Timestamped list of simulation events ([member StepResult.events]).
## Keeps the newest [constant MAX_ENTRIES]; texts are translated when shown.
## Its title rolls the list in and out ([member expanded]).

## The title was clicked to roll the list in or out.
signal expand_toggled(expanded: bool)

const MAX_ENTRIES: int = 500

## The list is shown (rolled out); rolled in, only the title stays.
var expanded: bool = true:
	set(value):
		expanded = value
		if _list != null:
			_list.visible = expanded
			_clear.visible = expanded
			_title.icon = AppTheme.icon("chevron_down" if expanded else "chevron_right", 16)

var _entries: Array[Dictionary] = []
var _title: Button
var _clear: Button
var _list: ItemList
## New entries were added: the list scrolls to its end once it is laid out.
var _to_end: bool = false


func _ready() -> void:
	var header: HBoxContainer = HBoxContainer.new()
	add_child(header)
	_title = TimingPanel.rollout_button()
	_title.pressed.connect(func() -> void:
		expanded = not expanded
		expand_toggled.emit(expanded))
	header.add_child(_title)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(gap)
	_clear = Button.new()
	_clear.theme_type_variation = "ToolButton"
	_clear.add_theme_font_size_override("font_size", AppTheme.SMALL_FONT_SIZE)
	_clear.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_clear.focus_mode = Control.FOCUS_NONE
	_clear.pressed.connect(clear)
	header.add_child(_clear)
	_list = ItemList.new()
	_list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.focus_mode = Control.FOCUS_NONE
	add_child(_list)
	# The scroll bar learns the new length only when the list is laid out.
	_list.get_v_scroll_bar().changed.connect(func() -> void:
		if _to_end:
			_to_end = false
			_list.get_v_scroll_bar().value = _list.get_v_scroll_bar().max_value)
	expanded = expanded
	retranslate()


func add_events(events: Array[Dictionary]) -> void:
	if events.is_empty():
		return
	for e: Dictionary in events:
		_entries.append(e)
		_list.add_item(_format(e))
	while _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
		_list.remove_item(0)
	_to_end = true
	_list.get_v_scroll_bar().value = _list.get_v_scroll_bar().max_value


func clear() -> void:
	_entries.clear()
	_list.clear()


func retranslate() -> void:
	_title.text = tr("Event log")
	_title.tooltip_text = tr("Show or hide the event log")
	_clear.text = tr("Clear")
	_list.clear()
	for e: Dictionary in _entries:
		_list.add_item(_format(e))


func _format(e: Dictionary) -> String:
	return "%8.4f s  %s" % [e["time"], tr(e["text"]) % e["args"]]
