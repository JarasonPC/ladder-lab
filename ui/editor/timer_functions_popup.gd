class_name TimerFunctionsPopup
extends PopupPanel
## All functions of the multifunction time relay at once, each with its
## timing diagram. Clicking one chooses it. Sized to the window: as many
## columns as fit, the diagrams as wide as their column.

## The function [param mode_name] (from [constant TimerRelay.MODE_NAMES]) was chosen.
signal function_chosen(mode_name: String)

## Narrowest card; the window decides how many columns fit.
const MIN_CARD_WIDTH: float = 340.0
const MAX_COLUMNS: int = 4
## Part of the window the list takes.
const WINDOW_SHARE: float = 0.9


## Titles of the time relay functions, in [constant TimerRelay.MODE_NAMES] order.
## [param input]: name of the control input (S, TL, ...) written in the titles.
static func function_titles(input: String) -> Array:
	var titles: Array = []
	for title: String in ["F2 – On-delay", "Off-delay (on power loss)", "F1 – Pulse after power on", "F3 – Pulse when %s is pressed", "F4 – On-delay after %s is released", "F5 – Pulse after %s is released", "F6 – Impulse relay (no memory)", "F7 – Pulse generator", "F8 – Shifted pulse", "F9 – Test (always on)", "F10 – Cycler starting with the pause (t2 off, t1 on)", "F11 – Cycler starting with the pulse (t1 on, t2 off)", "F12 – On-delay t1 and off-delay t2 with %s"]:
		var text: String = String(TranslationServer.translate(title))
		titles.append(text % input if text.contains("%s") else text)
	return titles


## Fills the list: [param titles] in [enum TimerRelay.Mode] order, the current
## function [param current] highlighted, the control input named [param input_name].
func setup(titles: Array, current: TimerRelay.Mode, input_name: String) -> void:
	# Rounded corners and shadow of the panel style, nothing square behind.
	transparent = true
	transparent_bg = true
	var window: Vector2 = Vector2(get_tree().root.get_visible_rect().size) if is_inside_tree() else Vector2(1280, 800)
	var width: float = maxf(window.x * WINDOW_SHARE, MIN_CARD_WIDTH + 40.0)
	var columns: int = clampi(int((width - 40.0) / MIN_CARD_WIDTH), 1, MAX_COLUMNS)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title: Label = Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = tr("Time relay functions")
	box.add_child(title)
	var hint: Label = Label.new()
	hint.theme_type_variation = "MutedLabel"
	hint.text = tr("U supply A1-A2, %s control input, R output (delayed contacts), t the set time (t1, t2 where there are two). Click a function to use it.") % input_name
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(width - 40.0, 0)
	box.add_child(hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	# Functions in the order of their codes F1..F9, the true off-delay last.
	var order: Array[int] = []
	for m: int in TimerRelay.MODE_NAMES.size():
		order.append(m)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _code_number(a) < _code_number(b))
	for m: int in order:
		grid.add_child(_card(m, titles[m], m == current, input_name))
	size = Vector2i(int(width), int(window.y * WINDOW_SHARE))


## Number of the function code (F1 -> 1), 99 for the true off-delay.
static func _code_number(m: int) -> int:
	var code: String = TimerRelay.MODE_CODES[m]
	return int(code.substr(1)) if not code.is_empty() else 99


func _card(m: int, title: String, active: bool, input_name: String) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "FunctionCardActive" if active else "FunctionCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = tr("Use this function")
	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	var label: Label = Label.new()
	label.text = title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(label)
	var diagram: TimerDiagram = TimerDiagram.new()
	diagram.input_name = input_name
	diagram.mode = m as TimerRelay.Mode
	diagram.row_height = 30.0
	inner.add_child(diagram)
	var mode_name: String = TimerRelay.MODE_NAMES[m]
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			hide()
			function_chosen.emit(mode_name))
	return card
