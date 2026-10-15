class_name TimerFunctionsPopup
extends PopupPanel
## All functions of the multifunction time relay at once, each with its
## timing diagram. Clicking one chooses it.

## The function [param mode_name] (from [constant TimerRelay.MODE_NAMES]) was chosen.
signal function_chosen(mode_name: String)

const COLUMNS: int = 2
const CARD_WIDTH: float = 360.0


## Fills the list: [param titles] in [enum TimerRelay.Mode] order, the current
## function [param current] highlighted, the control input named [param input_name].
func setup(titles: Array, current: TimerRelay.Mode, input_name: String) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title: Label = Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = tr("Time relay functions")
	box.add_child(title)
	var hint: Label = Label.new()
	hint.theme_type_variation = "MutedLabel"
	hint.text = tr("U supply A1-A2, %s control input, R output (delayed contacts), t the set time. Click a function to use it.") % input_name
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(COLUMNS * CARD_WIDTH, 0)
	box.add_child(hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	# Functions in the order of their codes F1..F9, the true off-delay last.
	var order: Array[int] = []
	for m: int in TimerRelay.MODE_NAMES.size():
		order.append(m)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ca: String = TimerRelay.MODE_CODES[a] if not TimerRelay.MODE_CODES[a].is_empty() else "Z"
		var cb: String = TimerRelay.MODE_CODES[b] if not TimerRelay.MODE_CODES[b].is_empty() else "Z"
		return ca < cb)
	for m: int in order:
		grid.add_child(_card(m, titles[m], m == current, input_name))
	var screen: Vector2 = Vector2(get_tree().root.get_visible_rect().size) if is_inside_tree() else Vector2(1000, 800)
	size = Vector2i(int(COLUMNS * CARD_WIDTH + 60.0), int(minf(760.0, screen.y - 80.0)))


func _card(m: int, title: String, active: bool, input_name: String) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "FunctionCardActive" if active else "FunctionCard"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
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
	inner.add_child(diagram)
	var mode_name: String = TimerRelay.MODE_NAMES[m]
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			hide()
			function_chosen.emit(mode_name))
	return card
