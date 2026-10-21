class_name SymbolEditor
extends ConfirmationDialog
## Draws a floor plan symbol of the user's own ([CustomSymbol]) for the
## library: its name, its category (typed, or one the library has picked
## from the list beside it), whether it goes on a wall, whether it is
## electrical (a load on a circuit: its power and supply), and its shapes
## drawn on a [SymbolCanvas] with the tools above it. OK keeps it
## ([signal saved]); it needs a name and a shape.

## [param def] was drawn (a new symbol or one changed; the same id).
signal saved(def: CustomSymbol)

var canvas: SymbolCanvas
var _name: LineEdit
var _category: LineEdit
var _categories: MenuButton
var _wall: CheckBox
var _electrical: CheckBox
var _power: SpinBox
var _two_phases: CheckBox
var _tools: Array[Button] = []
var _filled: CheckBox
var _text: LineEdit
var _text_size: SpinBox
var _labels: Array[Label] = []
var _hint: Label
var _undo: Button
var _redo: Button
var _delete: Button
var _fit: Button
## The symbol drawn (a copy; the one edited keeps its id).
var _def: CustomSymbol
## The text fields are being filled (their signals are not changes then).
var _filling: bool = false


func _init() -> void:
	min_size = Vector2i(820, 600)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var fields: HBoxContainer = HBoxContainer.new()
	fields.add_theme_constant_override("separation", 8)
	box.add_child(fields)
	_name = LineEdit.new()
	_name.max_length = CustomSymbol.MAX_NAME
	_name.custom_minimum_size.x = 220.0
	_name.text_changed.connect(func(_text: String) -> void: _update())
	_add_field(fields, _name)
	_category = LineEdit.new()
	_category.max_length = CustomSymbol.MAX_NAME
	_category.custom_minimum_size.x = 160.0
	_add_field(fields, _category)
	_categories = MenuButton.new()
	_categories.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_categories.flat = false
	_categories.theme_type_variation = "ToolButton"
	_categories.icon = AppTheme.icon("chevron_down")
	_categories.about_to_popup.connect(_fill_categories)
	_categories.get_popup().index_pressed.connect(func(index: int) -> void:
		_category.text = _categories.get_popup().get_item_metadata(index))
	fields.add_child(_categories)
	var options: HBoxContainer = HBoxContainer.new()
	options.add_theme_constant_override("separation", 12)
	box.add_child(options)
	_wall = _check(options)
	_wall.toggled.connect(func(on: bool) -> void:
		canvas.symbol.wall = on
		canvas.queue_redraw())
	_electrical = _check(options)
	_electrical.toggled.connect(func(_on: bool) -> void: _update())
	_power = SpinBox.new()
	_power.min_value = Appliance.MIN_POWER
	_power.max_value = Appliance.MAX_POWER
	_power.step = 1.0
	_power.suffix = "W"
	_power.custom_minimum_size.x = 110.0
	_add_field(options, _power)
	_two_phases = _check(options)
	var tools: HBoxContainer = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	box.add_child(tools)
	var group: ButtonGroup = ButtonGroup.new()
	var icons: PackedStringArray = ["select", "shape_line", "shape_rect", "shape_ellipse", "shape_arc", "shape_curve", "shape_text"]
	for k: int in icons.size():
		var button: Button = _tool_button(tools, icons[k])
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = k == 0
		var tool: SymbolCanvas.Tool = k as SymbolCanvas.Tool
		button.toggled.connect(func(on: bool) -> void:
			if on:
				canvas.tool = tool
				_update())
		_tools.append(button)
	tools.add_child(VSeparator.new())
	_filled = _check(tools)
	_filled.toggled.connect(func(on: bool) -> void:
		canvas.filled = on
		if _filling:
			return
		var shape: CustomSymbol.Shape = _selected_shape()
		if shape != null and shape.kind in ["rect", "ellipse"] and shape.filled != on:
			canvas.change_selected(func(s: CustomSymbol.Shape) -> void: s.filled = on))
	_text = LineEdit.new()
	_text.max_length = CustomSymbol.MAX_TEXT_LENGTH
	_text.custom_minimum_size.x = 120.0
	_text.text = "TV"
	_text.text_changed.connect(func(value: String) -> void:
		canvas.text = value
		if _filling:
			return
		var shape: CustomSymbol.Shape = _selected_shape()
		if shape != null and shape.kind == "text" and not value.strip_edges().is_empty():
			canvas.change_selected(func(s: CustomSymbol.Shape) -> void: s.text = value.strip_edges()))
	_add_field(tools, _text)
	_text_size = SpinBox.new()
	_text_size.min_value = CustomSymbol.MIN_TEXT * 1000.0
	_text_size.max_value = CustomSymbol.MAX_TEXT * 1000.0
	_text_size.step = 5.0
	_text_size.value = CustomSymbol.TEXT_SIZE * 1000.0
	_text_size.suffix = "mm"
	_text_size.custom_minimum_size.x = 100.0
	_text_size.value_changed.connect(func(value: float) -> void:
		canvas.text_size = value / 1000.0
		if _filling:
			return
		var shape: CustomSymbol.Shape = _selected_shape()
		if shape != null and shape.kind == "text":
			canvas.change_selected(func(s: CustomSymbol.Shape) -> void: s.size = value / 1000.0))
	_add_field(tools, _text_size)
	var rest: Control = Control.new()
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(rest)
	_undo = _tool_button(tools, "undo")
	_undo.pressed.connect(func() -> void: canvas.undo())
	_redo = _tool_button(tools, "redo")
	_redo.pressed.connect(func() -> void: canvas.redo())
	_delete = _tool_button(tools, "delete")
	_delete.pressed.connect(func() -> void: canvas.delete_selected())
	_fit = _tool_button(tools, "fit")
	_fit.pressed.connect(func() -> void: canvas.fit())
	var paper: PanelContainer = PanelContainer.new()
	paper.theme_type_variation = "Card"
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(paper)
	canvas = SymbolCanvas.new()
	canvas.custom_minimum_size = Vector2(760, 400)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.changed.connect(_update)
	canvas.selection_changed.connect(_show_selected)
	paper.add_child(canvas)
	_hint = Label.new()
	_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hint.theme_type_variation = "MutedLabel"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 760.0
	box.add_child(_hint)
	confirmed.connect(func() -> void:
		_def.name = _name.text.strip_edges()
		_def.category = _category.text.strip_edges()
		_def.wall = _wall.button_pressed
		_def.electrical = _electrical.button_pressed
		_def.power = _power.value
		_def.two_phases = _two_phases.button_pressed
		saved.emit(_def))


## Opens with a copy of [param def] (a new symbol: [code]null[/code]).
func open(def: CustomSymbol) -> void:
	_retranslate()
	_def = def.copy() if def != null else CustomSymbol.new()
	if def == null:
		_def.id = CustomSymbol.new_id()
	title = tr("New symbol") if def == null else tr("Symbol %s") % def.name
	_name.text = _def.name
	_category.text = _def.category
	_wall.set_pressed_no_signal(_def.wall)
	_electrical.set_pressed_no_signal(_def.electrical)
	_power.set_value_no_signal(_def.power)
	_two_phases.set_pressed_no_signal(_def.two_phases)
	_tools[0].button_pressed = true
	canvas.tool = SymbolCanvas.Tool.SELECT
	canvas.edit(_def)
	_update()
	popup_centered()
	canvas.fit()
	_name.grab_focus()


func _update() -> void:
	if _def == null:
		return
	var electrical: bool = _electrical.button_pressed
	_power.editable = electrical
	_two_phases.disabled = not electrical
	get_ok_button().disabled = _name.text.strip_edges().is_empty() or _def.shapes.is_empty()
	_delete.disabled = canvas.selected < 0
	var hints: PackedStringArray = [
		tr("Click a shape to pick it, drag it to move it, drag its squares to move its points; Delete takes it away."),
		tr("Drag from one end of the line to the other."),
		tr("Drag from corner to corner."),
		tr("Drag from corner to corner of the box round the ellipse."),
		tr("Drag from one end of the arc to the other, then click where it goes through."),
		tr("Drag from one end of the curve to the other, then click where it bends towards."),
		tr("Type the text beside the tools, then click where its middle goes."),
	]
	var wall_hint: String = tr("The wall is the grey band at the top: the symbol hangs from it into the room, drawn upright on every wall.") if _wall.button_pressed else tr("The axes cross where the symbol's middle goes.")
	_hint.text = hints[canvas.tool] + " " + wall_hint + " " + tr("Ctrl+Z undoes; wheel zooms; right drag pans.")


## The selected shape's fill, text and size in the fields.
func _show_selected() -> void:
	var shape: CustomSymbol.Shape = _selected_shape()
	_filling = true
	if shape != null and shape.kind in ["rect", "ellipse"]:
		_filled.button_pressed = shape.filled
	if shape != null and shape.kind == "text":
		_text.text = shape.text
		canvas.text = shape.text
		_text_size.value = shape.size * 1000.0
	_filling = false
	_update()


func _selected_shape() -> CustomSymbol.Shape:
	if canvas == null or canvas.selected < 0 or canvas.selected >= canvas.symbol.shapes.size():
		return null
	return canvas.symbol.shapes[canvas.selected]


func _fill_categories() -> void:
	var popup: PopupMenu = _categories.get_popup()
	popup.clear()
	for category: String in SymbolLibrary.shared().categories():
		if category.is_empty():
			continue
		popup.add_item(category)
		popup.set_item_metadata(popup.item_count - 1, category)
	if popup.item_count == 0:
		popup.add_item(tr("No categories yet: type one"))
		popup.set_item_disabled(0, true)
		popup.set_item_metadata(0, "")


func _retranslate() -> void:
	ok_button_text = tr("Save to my symbols")
	cancel_button_text = tr("Cancel")
	# The labels of the fields in the order they were made.
	var texts: PackedStringArray = [tr("Name"), tr("Category"), tr("Power"), tr("Text"), tr("Height")]
	for k: int in _labels.size():
		_labels[k].text = texts[k]
	_name.placeholder_text = tr("e.g. TV socket, smoke detector")
	_category.placeholder_text = tr("e.g. Data, Fire alarm")
	_categories.tooltip_text = tr("Pick a category the library has")
	_wall.text = tr("On a wall")
	_wall.tooltip_text = tr("Put onto the nearest wall, facing into the room; else where it is clicked (on the ceiling)")
	_electrical.text = tr("Electrical: a load on a circuit")
	_electrical.tooltip_text = tr("Put on the plan on the circuit chosen, like an appliance: it is on the single-line diagram and in the consumer unit's circuits, draws its power while simulating and is in the parts list")
	_two_phases.text = tr("400 V between two phases")
	_filled.text = tr("Filled")
	var tips: PackedStringArray = [tr("Select and move"), tr("Line"), tr("Rectangle"), tr("Ellipse or circle"), tr("Arc through three points"), tr("Curve"), tr("Text")]
	for k: int in _tools.size():
		_tools[k].tooltip_text = tips[k]
	_undo.tooltip_text = tr("Undo")
	_redo.tooltip_text = tr("Redo")
	_delete.tooltip_text = tr("Delete the shape picked")
	_fit.tooltip_text = tr("Show all")


func _add_field(row: HBoxContainer, field: Control) -> void:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(label)
	_labels.append(label)
	row.add_child(field)


func _check(row: HBoxContainer) -> CheckBox:
	var check: CheckBox = CheckBox.new()
	check.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(check)
	return check


func _tool_button(row: HBoxContainer, icon_name: String) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.theme_type_variation = "ToolButton"
	button.focus_mode = Control.FOCUS_NONE
	button.icon = AppTheme.icon(icon_name)
	row.add_child(button)
	return button
