class_name EventLog
extends VBoxContainer
## Timestamped list of simulation events ([member StepResult.events]).
## Keeps the newest [constant MAX_ENTRIES]; texts are translated when shown.

const MAX_ENTRIES: int = 500

var _entries: Array[Dictionary] = []
var _title: Label
var _clear: Button
var _list: ItemList


func _ready() -> void:
	var header: HBoxContainer = HBoxContainer.new()
	add_child(header)
	_title = Label.new()
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_clear = Button.new()
	_clear.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_clear.focus_mode = Control.FOCUS_NONE
	_clear.pressed.connect(clear)
	header.add_child(_clear)
	_list = ItemList.new()
	_list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.focus_mode = Control.FOCUS_NONE
	add_child(_list)
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
	_list.get_v_scroll_bar().value = _list.get_v_scroll_bar().max_value


func clear() -> void:
	_entries.clear()
	_list.clear()


func retranslate() -> void:
	_title.text = tr("Event log")
	_clear.text = tr("Clear")
	_list.clear()
	for e: Dictionary in _entries:
		_list.add_item(_format(e))


func _format(e: Dictionary) -> String:
	return "%9.4f s   %s" % [e["time"], tr(e["text"]) % e["args"]]
