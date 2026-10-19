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
## Rows of the chart were hidden or shown (to remember them).
signal rows_chosen

const WINDOWS: Array[float] = [0.02, 0.1, 0.5, 2.0, 10.0, 60.0]
const MIN_HEIGHT: float = 140.0
## Highest share of the window the panel may take (shown: of the height the
## bars above and below it leave).
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
## Opens the list of rows to show ([member _rows_menu]).
var _rows_button: Button
var _rows_menu: PopupMenu
var _hint: Label
## What the hint says, shown when it fits whole.
var _hint_text: String = ""
var _log_grip: Control
## Chart part, grip and log side by side.
var _split: HBoxContainer
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
	_split = split
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
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		_window_select.add_item(span_text(w))
	_window_select.item_selected.connect(func(i: int) -> void: chart.window = WINDOWS[i])
	tools.add_child(_window_select)
	_live = Button.new()
	_live.icon = AppTheme.icon("follow", 16)
	_live.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_live.focus_mode = Control.FOCUS_NONE
	_live.pressed.connect(func() -> void: chart.follow_now())
	tools.add_child(_live)
	_rows_button = Button.new()
	_rows_button.icon = AppTheme.icon("list", 16)
	_rows_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_rows_button.focus_mode = Control.FOCUS_NONE
	_rows_button.pressed.connect(_open_rows_menu)
	tools.add_child(_rows_button)
	_rows_menu = PopupMenu.new()
	_rows_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_rows_menu.hide_on_checkable_item_selection = false
	_rows_menu.id_pressed.connect(_on_rows_menu)
	add_child(_rows_menu)
	_hint = Label.new()
	_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hint.theme_type_variation = "MutedLabel"
	# The hint gives way first when the window is narrow.
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.clip_text = true
	_hint.resized.connect(_fit_hint)
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
	chart.follow_changed.connect(func(_following: bool) -> void: _show_hint())
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
	# The room left for the panel changes with the window, the interface
	# size and the bars beside it: sizes are fitted at every layout.
	var column: Container = get_parent() as Container
	if column != null:
		column.pre_sort_children.connect(_apply_sizes)
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
## The height and the log width give way when the window has no room for
## them (a small window, a large interface size); the chosen ones are kept.
func _apply_sizes() -> void:
	if event_log == null:
		return
	_fit_follow()
	custom_minimum_size.y = minf(panel_height, _room().y) if _show_chart or _show_log else 0.0
	event_log.custom_minimum_size.x = minf(log_width, _room().x) if _show_log and _show_chart else 0.0


## Follow shows its text when the window leaves room for it beside the
## log's smallest width, else only its icon (the text is then its tooltip).
func _fit_follow() -> void:
	var text: String = tr("Follow")
	var width: float = _live.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _live.get_theme_font_size("font_size")).x + _live.get_theme_constant("h_separation")
	var spare: float = _room().x - (0.0 if _live.text != "" else width)
	var log_needs: float = event_log.get_minimum_size().x if _show_log and _show_chart else 0.0
	var fits: bool = spare >= log_needs
	_live.text = text if fits else ""
	_live.tooltip_text = "" if fits else text


## Largest height the panel may take and width the log may take: a share of
## the height left by the bars above and below it, the width beside the
## chart's title and tools.
func _room() -> Vector2:
	var column: Container = get_parent() as Container
	if not is_inside_tree() or column == null:
		return Vector2(INF, INF)
	var window: Vector2 = get_viewport_rect().size
	var others: float = 0.0
	for child: Node in column.get_children():
		if child != self and child is Control and (child as Control).visible:
			others += (child as Control).get_combined_minimum_size().y
	var frame: Vector2 = get_theme_stylebox("panel").get_minimum_size()
	var gaps: float = 2.0 * _split.get_theme_constant("separation") + _log_grip.custom_minimum_size.x
	var width: float = window.x - frame.x - gaps - _chart_part.get_combined_minimum_size().x
	return Vector2(maxf(width, 0.0), maxf((window.y - others) * MAX_HEIGHT_SHARE, 0.0))


func retranslate() -> void:
	_chart_title.text = tr("Timing chart")
	_chart_title.tooltip_text = tr("Show or hide the timing chart")
	_window_label.text = tr("Time span:")
	_fit_follow()
	_rows_button.tooltip_text = tr("Choose what the timing chart shows")
	_show_hint()
	event_log.retranslate()
	_log_grip.tooltip_text = tr("Drag to share the width between the chart and the event log")
	chart.queue_redraw()


## The list of the chart's rows with a tick each, "Show all" and "Hide all"
## above them, under the Signals button.
func _open_rows_menu() -> void:
	_rows_menu.clear()
	_rows_menu.add_item(tr("Show all"), 0)
	_rows_menu.add_item(tr("Hide all"), 1)
	_rows_menu.add_separator()
	var rows: Array[Dictionary] = chart.choices()
	for i: int in rows.size():
		var label: String = tr("%s currents") % rows[i]["label"] if rows[i]["currents"] else str(rows[i]["label"])
		_rows_menu.add_check_item(label, 10 + i)
		_rows_menu.set_item_checked(_rows_menu.item_count - 1, not chart.hidden_rows.has(rows[i]["key"]))
		_rows_menu.set_item_metadata(_rows_menu.item_count - 1, rows[i]["key"])
	var at: Vector2 = _rows_button.get_screen_position() + Vector2(0.0, _rows_button.size.y)
	_rows_menu.popup(Rect2i(Vector2i(at), Vector2i.ZERO))


func _on_rows_menu(id: int) -> void:
	if id == 0 or id == 1:
		var now: Dictionary[String, bool] = {}
		if id == 1:
			for row: Dictionary in chart.choices():
				now[row["key"]] = true
		else:
			# Keys of rows of other schematics stay hidden.
			now = chart.hidden_rows.duplicate()
			for row: Dictionary in chart.choices():
				now.erase(row["key"])
		chart.hidden_rows = now
		for i: int in _rows_menu.item_count:
			if _rows_menu.is_item_checkable(i):
				_rows_menu.set_item_checked(i, id == 0)
	else:
		var index: int = _rows_menu.get_item_index(id)
		var shown: bool = not _rows_menu.is_item_checked(index)
		_rows_menu.set_item_checked(index, shown)
		chart.set_row_shown(str(_rows_menu.get_item_metadata(index)), shown)
	rows_chosen.emit()


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


## What to do with the chart: look back, or (while looking back) follow again.
func _show_hint() -> void:
	_hint_text = tr("Drag to look back, wheel zooms") if chart.follow else tr("Double click: follow")
	_fit_hint()


## The hint is shown whole or not at all.
func _fit_hint() -> void:
	var width: float = _hint.get_theme_font("font").get_string_size(_hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _hint.get_theme_font_size("font_size")).x
	_hint.text = _hint_text if width <= _hint.size.x else ""


## The span zoomed to by the wheel: one of the choices, or written in the
## field when it is between them.
func _on_window_changed(seconds: float) -> void:
	for i: int in WINDOWS.size():
		if is_equal_approx(WINDOWS[i], seconds):
			_window_select.select(i)
			return
	_window_select.select(-1)
	_window_select.text = span_text(seconds)


## A time span as the choices write it: "20 ms", "2 s", "2.4 s".
static func span_text(seconds: float) -> String:
	if seconds < 1.0:
		return "%d ms" % roundi(seconds * 1000.0)
	if is_equal_approx(seconds, roundf(seconds)):
		return "%d s" % roundi(seconds)
	return "%.1f s" % seconds
