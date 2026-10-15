class_name TimingPanel
extends PanelContainer
## Bottom panel in Simulate mode: timing chart with its zoom choice next to
## the event log. Either part can be shown or hidden ([method show_parts]).

const WINDOWS: Array[float] = [0.02, 0.1, 0.5, 2.0, 10.0]

var chart: TimingChart
var event_log: EventLog
var _chart_part: VBoxContainer
var _window_label: Label
var _window_select: OptionButton
var _live: Button
var _hint: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0, 210)
	var split: HBoxContainer = HBoxContainer.new()
	add_child(split)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	_chart_part = left
	var tools: HBoxContainer = HBoxContainer.new()
	left.add_child(tools)
	_window_label = Label.new()
	_window_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tools.add_child(_window_label)
	_window_select = OptionButton.new()
	_window_select.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_window_select.focus_mode = Control.FOCUS_NONE
	for w: float in WINDOWS:
		_window_select.add_item(("%d ms" % roundi(w * 1000.0)) if w < 1.0 else ("%d s" % roundi(w)))
	_window_select.item_selected.connect(func(i: int) -> void: chart.window = WINDOWS[i])
	tools.add_child(_window_select)
	_live = Button.new()
	_live.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_live.focus_mode = Control.FOCUS_NONE
	_live.pressed.connect(func() -> void:
		chart.follow = true
		chart.queue_redraw())
	tools.add_child(_live)
	_hint = Label.new()
	_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	tools.add_child(_hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	chart = TimingChart.new()
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.window_changed.connect(_on_window_changed)
	scroll.add_child(chart)
	event_log = EventLog.new()
	event_log.custom_minimum_size = Vector2(330, 0)
	split.add_child(event_log)
	_window_select.select(WINDOWS.find(0.1))
	chart.window = 0.1
	retranslate()


## Shows the timing chart and/or the event log; the event log takes the full
## width when it is shown alone.
func show_parts(show_chart: bool, show_log: bool) -> void:
	_chart_part.visible = show_chart
	event_log.visible = show_log
	event_log.size_flags_horizontal = Control.SIZE_FILL if show_chart else Control.SIZE_EXPAND_FILL
	visible = show_chart or show_log


func retranslate() -> void:
	_window_label.text = tr("Time span:")
	_live.text = tr("Follow")
	_hint.text = tr("Drag to look back, wheel zooms")
	event_log.retranslate()
	chart.queue_redraw()


func _on_window_changed(seconds: float) -> void:
	var best: int = 0
	for i: int in WINDOWS.size():
		if absf(log10(WINDOWS[i]) - log10(seconds)) < absf(log10(WINDOWS[best]) - log10(seconds)):
			best = i
	_window_select.select(best)


static func log10(x: float) -> float:
	return log(x) / log(10.0)
