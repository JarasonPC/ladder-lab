class_name SymbolEditor
extends ConfirmationDialog
## Draws a floor plan symbol of the user's own ([CustomSymbol]) for the
## library: its name, its category (typed, or one the library has picked
## from the list beside it), whether it goes on a wall, whether it is
## electrical (a load on a circuit: its power and supply), and its shapes
## drawn on a [SymbolCanvas] with the tools above it: the drawing tools, a
## picture taken in from an image file, turning, mirroring, copying and
## pasting, the grid. The panel beside the
## drawing sets the look of the shapes picked (or of new ones while none
## is): line width, style and colour, fill and its colour, a text's words,
## font, height, bold and italic, the angle of a text, rectangle, ellipse
## or picture, and the points of a shape picked alone typed in millimetres;
## Rotate (Ctrl+R) turns the shapes picked by an angle typed. OK keeps it ([signal saved]); it needs a name and
## a shape.

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
var _actions: Dictionary[String, Button] = {}
var _grid: OptionButton
var _picture: Button
## Edits the points of the polygon or polyline picked (toggled).
var _edit_points: Button
var _picture_file: FileDialog
var _message: AcceptDialog
var _rotate: Button
var _rotate_dialog: ConfirmationDialog
var _rotate_angle: SpinBox
var _rotate_label: Label
var _font: OptionButton
## The angle row, shown for texts, rectangles, ellipses and pictures.
var _angle_rows: Array[Control] = []
var _labels: Array[Label] = []
var _hint: Label
var _panel_title: Label
var _width: SpinBox
var _style: OptionButton
var _own_color: CheckBox
var _color: ColorPickerButton
var _filled: CheckBox
var _own_fill: CheckBox
var _fill: ColorPickerButton
var _text_rows: Array[Control] = []
var _text: LineEdit
var _text_size: SpinBox
var _angle: SpinBox
var _bold: CheckBox
var _italic: CheckBox
var _points_title: Label
var _points: GridContainer
## The symbol drawn (a copy; the one edited keeps its id).
var _def: CustomSymbol
## The fields are being filled (their signals are not changes then).
var _filling: bool = false


func _init() -> void:
	min_size = Vector2i(1040, 660)
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
		canvas.queue_redraw()
		_update())
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
	var icons: PackedStringArray = ["select", "shape_line", "shape_polyline", "shape_polygon", "shape_rect", "shape_ellipse", "shape_arc", "shape_curve", "shape_text"]
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
	_edit_points = _tool_button(tools, "edit_points")
	_edit_points.toggle_mode = true
	_edit_points.toggled.connect(func(on: bool) -> void:
		if on:
			_tools[0].button_pressed = true
		canvas.editing_points = on
		_edit_points.set_pressed_no_signal(canvas.editing_points))
	_picture = _tool_button(tools, "plan_underlay")
	_picture.pressed.connect(func() -> void:
		_picture_file.title = tr("Picture")
		_picture_file.popup_centered_ratio(0.6))
	_picture_file = FileDialog.new()
	_picture_file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_picture_file.access = FileDialog.ACCESS_FILESYSTEM
	_picture_file.use_native_dialog = true
	_picture_file.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp, *.svg, *.bmp ; Images"])
	_picture_file.file_selected.connect(add_picture)
	add_child(_picture_file)
	_message = AcceptDialog.new()
	add_child(_message)
	_rotate_dialog = ConfirmationDialog.new()
	var rotate_row: HBoxContainer = HBoxContainer.new()
	_rotate_dialog.add_child(rotate_row)
	_rotate_label = Label.new()
	_rotate_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rotate_row.add_child(_rotate_label)
	_rotate_angle = SpinBox.new()
	_rotate_angle.min_value = -360.0
	_rotate_angle.max_value = 360.0
	_rotate_angle.step = 0.5
	_rotate_angle.value = 45.0
	_rotate_angle.suffix = "°"
	rotate_row.add_child(_rotate_angle)
	# The angle as typed, Enter or OK (the field takes it only after the
	# dialog would have closed).
	_rotate_angle.get_line_edit().text_submitted.connect(func(_text: String) -> void:
		_rotate_dialog.hide()
		_rotate_by_typed())
	_rotate_dialog.confirmed.connect(_rotate_by_typed)
	add_child(_rotate_dialog)
	tools.add_child(VSeparator.new())
	var actions: Array[Array] = [
		["turn", "rotate", func() -> void: canvas.turn_selected(true)],
		["turn_back", "rotate_back", func() -> void: canvas.turn_selected(false)],
		["rotate", "rotate_any", _ask_rotate],
		["mirror", "mirror", func() -> void: canvas.mirror_selected(true)],
		["flip", "flip", func() -> void: canvas.mirror_selected(false)],
		["", "", Callable()],
		["copy", "copy", func() -> void: canvas.copy_selected()],
		["paste", "paste", func() -> void: canvas.paste()],
		["duplicate", "duplicate", func() -> void: canvas.duplicate_selected()],
		["delete", "delete", func() -> void: canvas.delete_selected()],
	]
	for action: Array in actions:
		if (action[0] as String).is_empty():
			tools.add_child(VSeparator.new())
			continue
		var button: Button = _tool_button(tools, action[1])
		button.pressed.connect(action[2])
		_actions[action[0]] = button
	var rest: Control = Control.new()
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(rest)
	_grid = OptionButton.new()
	_grid.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_grid.item_selected.connect(func(index: int) -> void:
		canvas.grid = SymbolCanvas.GRIDS[index]
		canvas.queue_redraw())
	tools.add_child(_grid)
	for action: Array in [["undo", "undo", func() -> void: canvas.undo()], ["redo", "redo", func() -> void: canvas.redo()], ["fit", "fit", func() -> void: canvas.fit()]]:
		var button: Button = _tool_button(tools, action[1])
		button.pressed.connect(action[2])
		_actions[action[0]] = button
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var paper: PanelContainer = PanelContainer.new()
	paper.theme_type_variation = "Card"
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(paper)
	canvas = SymbolCanvas.new()
	canvas.custom_minimum_size = Vector2(700, 440)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.changed.connect(_show_selected)
	canvas.selection_changed.connect(_show_selected)
	canvas.rotate_requested.connect(_ask_rotate)
	canvas.points_mode_changed.connect(func(on: bool) -> void:
		_edit_points.set_pressed_no_signal(on)
		_update())
	paper.add_child(canvas)
	body.add_child(_build_panel())
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


## The panel beside the drawing: the look of the shapes picked (or of new
## ones), a text's words and face, a shape's points.
func _build_panel() -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.x = 250.0
	var panel: VBoxContainer = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	_panel_title = Label.new()
	_panel_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_panel_title.theme_type_variation = "HeaderLabel"
	panel.add_child(_panel_title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	panel.add_child(grid)
	_width = SpinBox.new()
	_width.max_value = CustomSymbol.MAX_WIDTH
	_width.step = 0.1
	_width.suffix = "mm"
	_width.value_changed.connect(func(value: float) -> void: _apply(func(shape: CustomSymbol.Shape) -> void: shape.width = value))
	_add_row(grid, _width)
	_style = OptionButton.new()
	_style.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_style.item_selected.connect(func(index: int) -> void:
		var style: String = CustomSymbol.STYLES[index]
		_apply(func(shape: CustomSymbol.Shape) -> void: shape.style = style))
	_add_row(grid, _style)
	var line_row: HBoxContainer = HBoxContainer.new()
	_own_color = _check(line_row)
	_color = _color_button(line_row)
	_own_color.toggled.connect(func(_on: bool) -> void: _apply_color())
	_color.color_changed.connect(func(_c: Color) -> void: _apply_color())
	_add_row(grid, line_row)
	_filled = _check(null)
	_filled.toggled.connect(func(on: bool) -> void: _apply(func(shape: CustomSymbol.Shape) -> void: shape.filled = on and shape.kind in CustomSymbol.FILLABLE))
	_add_row(grid, _filled)
	var fill_row: HBoxContainer = HBoxContainer.new()
	_own_fill = _check(fill_row)
	_fill = _color_button(fill_row)
	_own_fill.toggled.connect(func(_on: bool) -> void: _apply_fill())
	_fill.color_changed.connect(func(_c: Color) -> void: _apply_fill())
	_add_row(grid, fill_row)
	_text = LineEdit.new()
	_text.max_length = CustomSymbol.MAX_TEXT_LENGTH
	_text.text = "TV"
	_text.text_changed.connect(func(value: String) -> void:
		canvas.text = value
		if not value.strip_edges().is_empty():
			_apply(func(shape: CustomSymbol.Shape) -> void:
				if shape.kind == "text":
					shape.text = value.strip_edges()))
	_text_rows.append_array(_add_row(grid, _text))
	_font = OptionButton.new()
	_font.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_font.fit_to_longest_item = false
	_font.clip_text = true
	_font.item_selected.connect(func(index: int) -> void:
		var family: String = str(_font.get_item_metadata(index))
		_apply(func(shape: CustomSymbol.Shape) -> void:
			if shape.kind == "text" or shape == canvas.look:
				shape.font = family))
	_text_rows.append_array(_add_row(grid, _font))
	_text_size = SpinBox.new()
	_text_size.min_value = CustomSymbol.MIN_TEXT * 1000.0
	_text_size.max_value = CustomSymbol.MAX_TEXT * 1000.0
	_text_size.step = 5.0
	_text_size.value = CustomSymbol.TEXT_SIZE * 1000.0
	_text_size.suffix = "mm"
	_text_size.value_changed.connect(func(value: float) -> void: _apply(func(shape: CustomSymbol.Shape) -> void: shape.size = value / 1000.0))
	_text_rows.append_array(_add_row(grid, _text_size))
	_angle = SpinBox.new()
	_angle.min_value = -180.0
	_angle.max_value = 180.0
	_angle.step = 1.0
	_angle.suffix = "°"
	_angle.value_changed.connect(func(value: float) -> void: _apply(func(shape: CustomSymbol.Shape) -> void:
		if shape.kind == "text" or shape.kind in CustomSymbol.BOXED or shape == canvas.look:
			shape.angle = value))
	_angle_rows.append_array(_add_row(grid, _angle))
	var face: HBoxContainer = HBoxContainer.new()
	_bold = _check(face)
	_italic = _check(face)
	_bold.toggled.connect(func(on: bool) -> void: _apply(func(shape: CustomSymbol.Shape) -> void: shape.bold = on))
	_italic.toggled.connect(func(on: bool) -> void: _apply(func(shape: CustomSymbol.Shape) -> void: shape.italic = on))
	_text_rows.append_array(_add_row(grid, face))
	_points_title = Label.new()
	_points_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_points_title.theme_type_variation = "HeaderLabel"
	panel.add_child(_points_title)
	_points = GridContainer.new()
	_points.columns = 3
	panel.add_child(_points)
	return scroll


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
	_show_selected()
	popup_centered()
	canvas.fit()
	_name.grab_focus()


## Adds the picture of image file [param path] to the symbol (made at most
## [constant CustomSymbol.IMAGE_PIXELS] a side), picked to be moved and
## scaled; tells why not when the file cannot be read.
func add_picture(path: String) -> void:
	var image: Image = Image.load_from_file(path) if FileAccess.file_exists(path) else null
	if image == null or image.is_empty():
		_message.title = tr("Picture")
		_message.dialog_text = tr("%s cannot be read.") % path.get_file()
		_message.ok_button_text = tr("OK")
		_message.reset_size()
		_message.popup_centered()
		return
	_tools[0].button_pressed = true
	canvas.add_shape(CustomSymbol.image_shape(image))


## Changes the shapes picked with [param change] (one undo step), or the
## look of new shapes while none is.
func _apply(change: Callable) -> void:
	if _filling or canvas == null:
		return
	if canvas.selection.is_empty():
		change.call(canvas.look)
	else:
		canvas.change_selected(change)


func _apply_color() -> void:
	var html: String = _html(_color.color) if _own_color.button_pressed else ""
	_color.disabled = not _own_color.button_pressed
	_apply(func(shape: CustomSymbol.Shape) -> void: shape.color = html)


func _apply_fill() -> void:
	var html: String = _html(_fill.color) if _own_fill.button_pressed else ""
	_fill.disabled = not _own_fill.button_pressed
	_apply(func(shape: CustomSymbol.Shape) -> void: shape.fill = html)


static func _html(color: Color) -> String:
	return color.to_html(not is_equal_approx(color.a, 1.0))


## The look of the first shape picked (or of new shapes) in the panel, and
## the points of one picked alone.
func _show_selected() -> void:
	if canvas == null:
		return
	var picked: Array[CustomSymbol.Shape] = canvas.selected_shapes()
	var shape: CustomSymbol.Shape = picked[0] if not picked.is_empty() else canvas.look
	_filling = true
	if picked.is_empty():
		_panel_title.text = tr("New shapes").to_upper()
	elif picked.size() == 1:
		_panel_title.text = _kind_title(shape.kind).to_upper()
	else:
		_panel_title.text = (tr_n("%d shape", "%d shapes", picked.size()) % picked.size()).to_upper()
	_width.value = shape.width
	_style.select(maxi(CustomSymbol.STYLES.find(shape.style), 0))
	_own_color.button_pressed = not shape.color.is_empty()
	_color.disabled = shape.color.is_empty()
	_color.color = CustomSymbol.line_color(shape, SchematicTheme.LINE)
	_filled.button_pressed = shape.filled
	_own_fill.button_pressed = not shape.fill.is_empty()
	_fill.disabled = shape.fill.is_empty()
	_fill.color = CustomSymbol.fill_color(shape, SchematicTheme.LINE)
	var texts: bool = picked.is_empty() or picked.any(func(s: CustomSymbol.Shape) -> bool: return s.kind == "text")
	for row: Control in _text_rows:
		row.visible = texts
	var turned: bool = texts or picked.any(func(s: CustomSymbol.Shape) -> bool: return s.kind in CustomSymbol.BOXED)
	for row: Control in _angle_rows:
		row.visible = turned
	var angled: Array[CustomSymbol.Shape] = picked.filter(func(s: CustomSymbol.Shape) -> bool: return s.kind == "text" or s.kind in CustomSymbol.BOXED)
	var angle_of: CustomSymbol.Shape = angled[0] if not angled.is_empty() else shape
	if shape.kind == "text":
		_text.text = shape.text
		canvas.text = shape.text
	_text_size.value = shape.size * 1000.0
	_angle.value = angle_of.angle
	_show_font(shape.font)
	_bold.button_pressed = shape.bold
	_italic.button_pressed = shape.italic
	_fill_points()
	_filling = false
	_update()


## Fields for the points of the one shape picked (x and y in millimetres).
func _fill_points() -> void:
	var shape: CustomSymbol.Shape = canvas.symbol.shapes[canvas.selected] if canvas.selected >= 0 else null
	var count: int = shape.points.size() if shape != null else 0
	_points_title.visible = count > 0
	if _points.get_child_count() != count * 3:
		for child: Node in _points.get_children():
			_points.remove_child(child)
			child.queue_free()
		for k: int in count:
			var label: Label = Label.new()
			label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			label.text = str(k + 1)
			_points.add_child(label)
			for axis: int in 2:
				var field: SpinBox = SpinBox.new()
				field.min_value = -CustomSymbol.REACH * 1000.0
				field.max_value = CustomSymbol.REACH * 1000.0
				field.step = 0.1
				field.prefix = "xy"[axis]
				field.custom_minimum_size.x = 96.0
				var point: int = k
				var along: int = axis
				field.value_changed.connect(func(value: float) -> void:
					_apply(func(s: CustomSymbol.Shape) -> void:
						if point < s.points.size():
							var p: Vector2 = CustomSymbol.handle_points(s)[point]
							p[along] = value / 1000.0
							CustomSymbol.set_handle(s, point, p)))
				_points.add_child(field)
	var shown: PackedVector2Array = CustomSymbol.handle_points(shape) if shape != null else PackedVector2Array()
	for k: int in count:
		for axis: int in 2:
			var field: SpinBox = _points.get_child(k * 3 + 1 + axis) as SpinBox
			if not field.get_line_edit().has_focus():
				field.set_value_no_signal(shown[k][axis] * 1000.0)


## The font list: the plan's font, then the computer's families; a family
## the computer lacks (a symbol from another one) is listed as missing.
func _fill_fonts() -> void:
	_font.clear()
	_font.add_item(tr("Plan font"))
	_font.set_item_metadata(0, "")
	for family: String in CustomSymbol.families():
		_font.add_item(family)
		_font.set_item_metadata(_font.item_count - 1, family)


## Family [param family] picked in the font list.
func _show_font(family: String) -> void:
	for i: int in _font.item_count:
		if str(_font.get_item_metadata(i)) == family:
			_font.select(i)
			return
	_font.add_item(tr("%s (missing here)") % family)
	_font.set_item_metadata(_font.item_count - 1, family)
	_font.select(_font.item_count - 1)


## Turns the shapes picked by the angle typed in the Rotate dialog.
func _rotate_by_typed() -> void:
	_rotate_angle.apply()
	canvas.rotate_selected(_rotate_angle.value)


## Asks the angle the shapes picked turn by.
func _ask_rotate() -> void:
	if canvas.selection.is_empty():
		return
	_rotate_dialog.title = tr("Rotate")
	_rotate_label.text = tr("Angle, anticlockwise")
	_rotate_dialog.ok_button_text = tr("Rotate")
	_rotate_dialog.cancel_button_text = tr("Cancel")
	_rotate_dialog.reset_size()
	_rotate_dialog.popup_centered()
	_rotate_angle.get_line_edit().grab_focus()
	_rotate_angle.get_line_edit().select_all()


func _kind_title(kind: String) -> String:
	match kind:
		"line":
			return tr("Line")
		"polyline":
			return tr("Polyline")
		"polygon":
			return tr("Polygon")
		"rect":
			return tr("Rectangle")
		"ellipse":
			return tr("Ellipse or circle")
		"arc":
			return tr("Arc through three points")
		"curve":
			return tr("Curve")
		"image":
			return tr("Picture")
	return tr("Text")


func _update() -> void:
	if _def == null:
		return
	var electrical: bool = _electrical.button_pressed
	_power.editable = electrical
	_two_phases.disabled = not electrical
	get_ok_button().disabled = _name.text.strip_edges().is_empty() or _def.shapes.is_empty()
	var none: bool = canvas.selection.is_empty()
	_edit_points.disabled = not canvas.can_edit_points()
	for key: String in ["turn", "turn_back", "rotate", "mirror", "flip", "copy", "duplicate", "delete"]:
		_actions[key].disabled = none
	_actions["paste"].disabled = SymbolCanvas.clipboard.is_empty()
	var hints: PackedStringArray = [
		tr("Click a shape to pick it, Shift or Ctrl+click to pick more, or drag a box round them; drag to move them, drag a point's square to move it, a corner of the box round them to scale them, the round handle over it to turn them (Shift: by 15°)."),
		tr("Drag from one end of the line to the other."),
		tr("Click each point; a double click, Enter or a right click ends the line."),
		tr("Click each corner; a click on the first, a double click, Enter or a right click closes it."),
		tr("Drag from corner to corner."),
		tr("Drag from corner to corner of the box round the ellipse."),
		tr("Drag from one end of the arc to the other, then click where it goes through."),
		tr("Drag from one end of the curve to the other, then click where it bends towards."),
		tr("Type the text in the panel, then click where its middle goes."),
	]
	var wall_hint: String = tr("The wall is the grey band at the top: the symbol hangs from it into the room, drawn upright on every wall.") if _wall.button_pressed else tr("The axes cross where the symbol's middle goes.")
	var hint: String = hints[canvas.tool]
	if canvas.editing_points:
		hint = tr("Editing points: drag a point to move it; click an edge, or drag the plus in its middle, to put a point in; Delete or Ctrl+click takes the point clicked out. Esc or a click elsewhere ends it.")
	_hint.text = hint + " " + wall_hint + " " + tr("Points snap to the points of other shapes. R turns a quarter, Ctrl+R by any angle, F mirrors (Shift: the other way); Ctrl+C, X, V, D copy, cut, paste, duplicate; Ctrl+Z undoes; wheel zooms; right drag pans.")


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
	var texts: PackedStringArray = [tr("Name"), tr("Category"), tr("Power"), tr("Line width"), tr("Line style"), tr("Line colour"), tr("Filled"), tr("Fill colour"), tr("Text"), tr("Font"), tr("Height"), tr("Angle"), tr("Face")]
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
	_width.tooltip_text = tr("0: as thin as the plan's own lines")
	_style.clear()
	for title: String in [tr("Solid"), tr("Dashed"), tr("Dotted"), tr("Dash and dot")]:
		_style.add_item(title)
	_own_color.text = tr("Own")
	_own_color.tooltip_text = tr("A colour of its own; else the plan's line colour (black on paper)")
	_own_fill.text = tr("Own")
	_own_fill.tooltip_text = tr("A fill colour of its own; else its line colour")
	_bold.text = tr("Bold")
	_italic.text = tr("Italic")
	_points_title.text = tr("Points (mm)").to_upper()
	_fill_fonts()
	_grid.clear()
	for step: float in SymbolCanvas.GRIDS:
		_grid.add_item(tr("Grid %s mm") % String.num(step * 1000.0, 3) if step > 0.0 else tr("No grid"))
	_grid.select(maxi(SymbolCanvas.GRIDS.find(canvas.grid), 0))
	_edit_points.tooltip_text = tr("Edit points of the polygon or polyline picked: move, put in and take out its points (or double-click it)")
	_picture.tooltip_text = tr("Picture: take in an image file (PNG, JPG, WebP, SVG); it is kept in the symbol and moved, scaled, turned and mirrored like the other shapes")
	var tips: PackedStringArray = [tr("Select and move"), tr("Line"), tr("Polyline"), tr("Polygon"), tr("Rectangle"), tr("Ellipse or circle"), tr("Arc through three points"), tr("Curve"), tr("Text")]
	for k: int in _tools.size():
		_tools[k].tooltip_text = tips[k]
	var action_tips: Dictionary[String, String] = {
		"turn": tr("Turn a quarter clockwise (R)"), "turn_back": tr("Turn a quarter anticlockwise (Shift+R)"),
		"rotate": tr("Rotate by an angle (Ctrl+R)"),
		"mirror": tr("Mirror left to right (F)"), "flip": tr("Mirror top to bottom (Shift+F)"),
		"copy": tr("Copy (Ctrl+C)"), "paste": tr("Paste (Ctrl+V)"), "duplicate": tr("Duplicate (Ctrl+D)"),
		"delete": tr("Delete the shapes picked"), "undo": tr("Undo"), "redo": tr("Redo"), "fit": tr("Show all"),
	}
	for key: String in action_tips:
		_actions[key].tooltip_text = action_tips[key]


func _add_field(row: HBoxContainer, field: Control) -> void:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(label)
	_labels.append(label)
	row.add_child(field)


## A row of the panel: a label and [param field]; returns both.
func _add_row(grid: GridContainer, field: Control) -> Array[Control]:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	grid.add_child(label)
	_labels.append(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(field)
	return [label, field]


func _check(row: Container) -> CheckBox:
	var check: CheckBox = CheckBox.new()
	check.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if row != null:
		row.add_child(check)
	return check


func _color_button(row: HBoxContainer) -> ColorPickerButton:
	var button: ColorPickerButton = ColorPickerButton.new()
	button.custom_minimum_size = Vector2(48, 24)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)
	return button


func _tool_button(row: HBoxContainer, icon_name: String) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.theme_type_variation = "ToolButton"
	button.focus_mode = Control.FOCUS_NONE
	button.icon = AppTheme.icon(icon_name)
	row.add_child(button)
	return button
