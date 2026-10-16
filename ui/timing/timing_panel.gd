class_name TimingPanel
extends PanelContainer
## Bottom panel in Simulate mode: timing chart with its zoom choice next to
## the event log. Either part rolls in to its title and out again by a click
## on the title ([method show_parts]); with both rolled in only the titles stay.
## Its top edge is dragged to make it taller or lower, the grip between the
## chart and the log to share the width.

## The height or the log width was changed by dragging (to remember them).
signal resized_by_user
## The chart or the log was rolled in or out by clicking its title.
signal parts_toggled(show_chart: bool, show_log: bool)

const WINDOWS: Array[float] = [0.02, 0.1, 0.5, 2.0, 10.0, 60.0]
const MIN_HEIGHT: float = 140.0
## Highest share of the window the panel may take.
const MAX_HEIGHT_SHARE: float = 0.75
const MIN_LOG_WIDTH: float = 180.0
const MAX_LOG_WIDTH: float = 900.0
## Band at the top edge that resizes the panel.
const EDGE: float = 6.0

var chart: TimingChart
var event_log: EventLog
var _chart_part: VBoxContainer
var _chart_title: Button
## Time span, Follow and the hint: shown with the chart only.
var _chart_tools: HBoxContainer
var _chart_card: PanelContainer
## Rolled out: the chart, the event log.
var _show_chart: bool = true
var _show_log: bool = true
var _window_label: Label
var _window_select: OptionButton
var _live: Button
var _hint: Label
var _log_grip: Control
## Dragging the top edge.
var _dragging_edge: bool = false

var panel_height: float = 220.0:
	set(value):
		var top: float = maxf(MIN_HEIGHT, get_viewport_rect().size.y * MAX_HEIGHT_SHARE) if is_inside_tree() else 10000.0
		panel_height = clampf(value, MIN_HEIGHT, top)
		_apply_sizes()
var log_width: float = 340.0:
	set(value):
		log_width = clampf(value, MIN_LOG_WIDTH, MAX_LOG_WIDTH)
		_apply_sizes()


## Header button that rolls a part of the panel in and out: an arrow and the
## part's title.
static func rollout_button() -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = "ListButton"
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("h_separation", 4)
	return button


func _ready() -> void:
	custom_minimum_size = Vector2(0, panel_height)
	theme_type_variation = "BottomPanel"
	var split: HBoxContainer = HBoxContainer.new()
	split.add_theme_constant_override("separation", 3)
	add_child(split)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	_chart_part = left
	var header: HBoxContainer = HBoxContainer.new()
	left.add_child(header)
	_chart_title = rollout_button()
	_chart_title.pressed.connect(func() -> void: _toggle(not _show_chart, _show_log))
	header.add_child(_chart_title)
	var tools: HBoxContainer = HBoxContainer.new()
	header.add_child(tools)
	_chart_tools = tools
	_window_label = Label.new()
	_window_label.theme_type_variation = "MutedLabel"
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
	_live.icon = AppTheme.icon("follow", 16)
	_live.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_live.focus_mode = Control.FOCUS_NONE
	_live.pressed.connect(func() -> void:
		chart.follow = true
		chart.queue_redraw())
	tools.add_child(_live)
	_hint = Label.new()
	_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hint.theme_type_variation = "MutedLabel"
	tools.add_child(_hint)
	# The chart sits in a rounded card.
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "Card"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	left.add_child(card)
	_chart_card = card
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	chart = TimingChart.new()
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.window_changed.connect(_on_window_changed)
	scroll.add_child(chart)
	_log_grip = Control.new()
	_log_grip.custom_minimum_size = Vector2(8, 0)
	_log_grip.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_log_grip.gui_input.connect(_on_log_grip_input)
	split.add_child(_log_grip)
	event_log = EventLog.new()
	event_log.expand_toggled.connect(func(expanded: bool) -> void: _toggle(_show_chart, expanded))
	split.add_child(event_log)
	_window_select.select(WINDOWS.find(0.1))
	chart.window = 0.1
	_apply_parts()
	retranslate()


## Rolls the timing chart and the event log out ([code]true[/code]) or in;
## a part rolled out alone takes the full width.
func show_parts(show_chart: bool, show_log: bool) -> void:
	_show_chart = show_chart
	_show_log = show_log
	if event_log != null:
		_apply_parts()


func _toggle(show_chart: bool, show_log: bool) -> void:
	show_parts(show_chart, show_log)
	parts_toggled.emit(show_chart, show_log)


func _apply_parts() -> void:
	event_log.expanded = _show_log
	_chart_tools.visible = _show_chart
	_chart_card.visible = _show_chart
	_chart_title.icon = AppTheme.icon("chevron_down" if _show_chart else "chevron_right", 16)
	_log_grip.visible = _show_chart and _show_log
	# The chart keeps the free width unless the log is rolled out alone.
	_chart_part.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _show_chart or not _show_log else Control.SIZE_FILL
	event_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _show_log and not _show_chart else Control.SIZE_FILL
	_apply_sizes()


## Rolled-in parts shrink to their titles, the whole panel when both are.
func _apply_sizes() -> void:
	if event_log == null:
		return
	custom_minimum_size.y = panel_height if _show_chart or _show_log else 0.0
	event_log.custom_minimum_size.x = log_width if _show_log and _show_chart else 0.0


func retranslate() -> void:
	_chart_title.text = tr("Timing chart")
	_chart_title.tooltip_text = tr("Show or hide the timing chart")
	_window_label.text = tr("Time span:")
	_live.text = tr("Follow")
	_hint.text = tr("Drag to look back, wheel zooms")
	event_log.retranslate()
	_log_grip.tooltip_text = tr("Drag to share the width between the chart and the event log")
	chart.queue_redraw()


## The top edge: drag up to make the panel taller.
func _gui_input(event: InputEvent) -> void:
	# Wheel left over the panel (the log at its end) is not for the schematic.
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
				accept_event()
				return
	if not (_show_chart or _show_log):
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _dragging_edge:
			panel_height = size.y - motion.relative.y
			accept_event()
		mouse_default_cursor_shape = Control.CURSOR_VSIZE if _dragging_edge or motion.position.y < EDGE else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.position.y < EDGE:
			_dragging_edge = true
			accept_event()
		elif not mb.pressed and _dragging_edge:
			_dragging_edge = false
			resized_by_user.emit()
			accept_event()


## The grip between chart and log: drag left to make the log wider.
func _on_log_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		log_width = event_log.size.x - (event as InputEventMouseMotion).relative.x
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		resized_by_user.emit()


func _on_window_changed(seconds: float) -> void:
	var best: int = 0
	for i: int in WINDOWS.size():
		if absf(log10(WINDOWS[i]) - log10(seconds)) < absf(log10(WINDOWS[best]) - log10(seconds)):
			best = i
	_window_select.select(best)


static func log10(x: float) -> float:
	return log(x) / log(10.0)
