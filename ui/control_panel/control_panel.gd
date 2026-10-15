class_name ControlPanel
extends PanelContainer
## Operator panel beside the schematic: the control boxes of the document
## ([ControlBox]) with their push buttons, switches and signal lamps. While
## simulating they operate the circuit and show its lamps. While editing,
## boxes are added and filled here: click an item to choose its device,
## colour, plate text and a signal lamp inside it (illuminated button). Every change is emitted as
## one undoable edit of the document (see [method SchematicEditor.edit_control_panel]).

## A push button was pressed (true) or let go (false) on a control box.
signal button_held(designation: String, pressed: bool)
## A switch was turned over on a control box.
signal switch_toggled(designation: String)
## A change of the control panel: [param change] is called with the document.
signal edit_requested(change: Callable)

## English names of [enum ControlBoxItem.Kind] (translated with tr()).
const KIND_TITLES: PackedStringArray = ["Push button", "Switch", "Signal lamp"]

var _document: SchematicDocument
var _editing: bool = false
var _selected_box: int = -1
var _selected_item: int = -1
var _title: Label
var _list: VBoxContainer
var _views: Array[ControlBoxView] = []
var _rebuild_queued: bool = false
var _swatches: Dictionary[String, Texture2D] = {}


func _ready() -> void:
	theme_type_variation = "RightPanel"
	custom_minimum_size = Vector2(250, 0)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	add_child(outer)
	_title = Label.new()
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.theme_type_variation = "TitleLabel"
	outer.add_child(_title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_rebuild()


## Shows the boxes of [param doc]; [param editing] offers the editing tools,
## otherwise the boxes operate the simulation of [param doc].
func set_document(doc: SchematicDocument, editing: bool) -> void:
	_document = doc
	_editing = editing
	if not editing or _selected_box >= doc.control_boxes.size():
		_select(-1, -1)
	elif _selected_box >= 0 and _selected_item >= doc.control_boxes[_selected_box].items.size():
		_selected_item = -1
	_rebuild()


## Shows the document again after it was edited (devices renamed, boxes changed).
func refresh() -> void:
	_rebuild_queued = true


func retranslate() -> void:
	_rebuild()


func _process(_delta: float) -> void:
	if _rebuild_queued:
		_rebuild_queued = false
		if _document != null and _selected_box >= _document.control_boxes.size():
			_select(-1, -1)
		elif _document != null and _selected_box >= 0 and _selected_item >= _document.control_boxes[_selected_box].items.size():
			_selected_item = -1
		_rebuild()
	if not _editing and is_visible_in_tree():
		# Buttons, switches and lamps follow the simulation.
		for view: ControlBoxView in _views:
			view.queue_redraw()


func _select(box_index: int, item_index: int) -> void:
	_selected_box = box_index
	_selected_item = item_index


func _rebuild() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_views.clear()
	_title.text = tr("Control panel")
	if _document == null:
		return
	if _document.control_boxes.is_empty():
		if _editing:
			_note(tr("No control boxes yet. Add a box and put the push buttons, switches and signal lamps of the schematic on it."))
		else:
			_note(tr("No control boxes yet. Add them in Edit mode."))
	for b: int in _document.control_boxes.size():
		if _editing:
			_box_header(b)
		var view: ControlBoxView = ControlBoxView.new()
		view.document = _document
		view.box_index = b
		view.simulating = not _editing
		view.selected = _selected_item if b == _selected_box else -1
		view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		view.button_held.connect(func(designation: String, pressed: bool) -> void: button_held.emit(designation, pressed))
		view.switch_toggled.connect(func(designation: String) -> void: switch_toggled.emit(designation))
		view.item_clicked.connect(func(index: int) -> void:
			_select(b, index)
			_rebuild_queued = true)
		_list.add_child(view)
		_views.append(view)
		if _editing:
			_add_buttons(b)
			if b == _selected_box and _selected_item >= 0:
				_item_editor(b, _selected_item)
	if _editing:
		_list.add_child(HSeparator.new())
		var add_box: Button = _button(tr("Add box"), "plus")
		add_box.alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_box.tooltip_text = tr("Add an empty control box")
		add_box.pressed.connect(func() -> void:
			_select(_document.control_boxes.size(), -1)
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.add_control_box()))
		_list.add_child(add_box)
		var add_all: Button = _button(tr("Box with all devices"), "panel")
		add_all.alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_all.tooltip_text = tr("Add a control box with every push button, switch and signal lamp that is not on the panel yet")
		add_all.disabled = not _has_unlisted_devices()
		add_all.pressed.connect(func() -> void:
			_select(_document.control_boxes.size(), -1)
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.add_control_box_for_all()))
		_list.add_child(add_all)


## Text on the box, items per row, move up and delete.
func _box_header(b: int) -> void:
	var box: ControlBox = _document.control_boxes[b]
	if b > 0:
		_list.add_child(HSeparator.new())
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var title: LineEdit = _text_field(box.title, tr("Text on the box"), func(text: String) -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.set_control_box(b, text, box.columns)))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var columns: OptionButton = _option(row)
	for n: int in range(1, ControlBox.MAX_COLUMNS + 1):
		columns.add_icon_item(AppTheme.icon("columns"), str(n))
	columns.select(box.columns - 1)
	columns.tooltip_text = tr("Items in a row")
	columns.item_selected.connect(func(k: int) -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.set_control_box(b, box.title, k + 1)))
	var up: Button = _tool("arrow_up", tr("Move the box up"))
	up.disabled = b == 0
	up.pressed.connect(func() -> void:
		_select(b - 1 if _selected_box == b else _selected_box, _selected_item)
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_control_box(b, -1)))
	row.add_child(up)
	var remove: Button = _tool("delete", tr("Delete the box"))
	remove.pressed.connect(func() -> void:
		_select(-1, -1)
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.remove_control_box(b)))
	row.add_child(remove)
	_list.add_child(row)


## Buttons that add a push button, a switch or a lamp to box [param b].
func _add_buttons(b: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var titles: PackedStringArray = [tr("Button"), tr("Switch"), tr("Lamp")]
	var tips: PackedStringArray = [tr("Add a push button"), tr("Add a switch"), tr("Add a signal lamp")]
	for kind: int in 3:
		var add: Button = _button(titles[kind], "plus")
		add.tooltip_text = tips[kind]
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add.pressed.connect(func() -> void:
			_select(b, _document.control_boxes[b].items.size())
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.add_control_item(b, kind as ControlBoxItem.Kind)))
		row.add_child(add)
	_list.add_child(row)


## Fields of the selected item: kind, device, plate text, colour, lamp inside it.
func _item_editor(b: int, i: int) -> void:
	var item: ControlBoxItem = _document.control_boxes[b].items[i]
	var data: Dictionary = item.to_data()
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "FunctionCard"
	_list.add_child(card)
	var fields: VBoxContainer = VBoxContainer.new()
	fields.add_theme_constant_override("separation", 4)
	card.add_child(fields)
	var apply: Callable = func(changed: Dictionary) -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.set_control_item(b, i, changed))

	_caption(fields, tr("Kind"))
	var kinds: OptionButton = _option(fields)
	for t: String in KIND_TITLES:
		kinds.add_item(tr(t))
	kinds.select(item.kind)
	kinds.item_selected.connect(func(k: int) -> void:
		var devices: PackedStringArray = _document.control_devices(k)
		var changed: Dictionary = data.duplicate()
		changed["kind"] = ControlBoxItem.KINDS[k]
		changed["designation"] = devices[0] if not devices.is_empty() else ""
		changed["color"] = ControlBoxItem.default_color(k as ControlBoxItem.Kind)
		apply.call(changed))

	_caption(fields, tr("Device"))
	var devices: PackedStringArray = _document.control_devices(item.kind)
	var choices: PackedStringArray = PackedStringArray([""])
	choices.append_array(devices)
	if not item.designation.is_empty() and not devices.has(item.designation):
		choices.append(item.designation)
	var device: OptionButton = _option(fields)
	for d: String in choices:
		if d.is_empty():
			device.add_item(tr("None"))
		elif devices.has(d):
			device.add_item(d)
		else:
			device.add_item(tr("%s (not in the schematic)") % d)
	device.select(choices.find(item.designation))
	device.item_selected.connect(func(k: int) -> void:
		var changed: Dictionary = data.duplicate()
		changed["designation"] = choices[k]
		apply.call(changed))

	_caption(fields, tr("Text on the plate"))
	fields.add_child(_text_field(item.label, item.designation, func(text: String) -> void:
		var changed: Dictionary = data.duplicate()
		changed["label"] = text
		apply.call(changed)))

	_caption(fields, tr("Colour"))
	# Lamps and lit caps are never black.
	var palette: PackedStringArray = ControlBoxItem.LAMP_COLORS if item.kind == ControlBoxItem.Kind.LAMP or not item.lamp.is_empty() else ControlBoxItem.COLORS
	fields.add_child(_color_choice(palette, item.color, func(color: String) -> void:
		var changed: Dictionary = data.duplicate()
		changed["color"] = color
		apply.call(changed)))

	if item.kind != ControlBoxItem.Kind.LAMP:
		_caption(fields, tr("Signal lamp inside (illuminated)"))
		var lamps: PackedStringArray = PackedStringArray([""])
		lamps.append_array(_document.control_devices(ControlBoxItem.Kind.LAMP))
		if not item.lamp.is_empty() and not lamps.has(item.lamp):
			lamps.append(item.lamp)
		var lamp: OptionButton = _option(fields)
		for d: String in lamps:
			lamp.add_item(tr("None") if d.is_empty() else d)
		lamp.select(lamps.find(item.lamp))
		lamp.item_selected.connect(func(k: int) -> void:
			var changed: Dictionary = data.duplicate()
			changed["lamp"] = lamps[k]
			apply.call(changed))

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 2)
	fields.add_child(actions)
	var count: int = _document.control_boxes[b].items.size()
	for step: int in [-1, 1]:
		var move: Button = _tool("arrow_left" if step < 0 else "arrow_right", tr("Move it one place back") if step < 0 else tr("Move it one place on"))
		move.disabled = i + step < 0 or i + step >= count
		move.pressed.connect(func() -> void:
			_select(b, i + step)
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_control_item(b, i, step)))
		actions.add_child(move)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var remove: Button = _button(tr("Remove"), "delete")
	remove.pressed.connect(func() -> void:
		_select(b, -1)
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.remove_control_item(b, i)))
	actions.add_child(remove)


func _has_unlisted_devices() -> bool:
	var listed: Dictionary[String, bool] = _document.control_panel_devices()
	for kind: int in 3:
		for designation: String in _document.control_devices(kind):
			if not listed.has(designation):
				return true
	return false


# --- Controls ---------------------------------------------------------------------

func _note(text: String) -> void:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.theme_type_variation = "MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_list.add_child(label)


func _caption(parent: Control, text: String) -> void:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.theme_type_variation = "CaptionLabel"
	label.text = text
	parent.add_child(label)


func _option(parent: Control) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	option.focus_mode = Control.FOCUS_NONE
	parent.add_child(option)
	return option


func _button(text: String, icon_name: String) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.focus_mode = Control.FOCUS_NONE
	button.text = text
	button.icon = AppTheme.icon(icon_name)
	return button


func _tool(icon_name: String, tooltip: String) -> Button:
	var button: Button = _button("", icon_name)
	button.theme_type_variation = "ToolButton"
	button.tooltip_text = tooltip
	return button


## Line edit that reports its text once, when Enter is pressed or it loses
## focus, and only when the text changed.
func _text_field(text: String, placeholder: String, on_commit: Callable) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	field.text = text
	field.placeholder_text = placeholder
	var state: Dictionary = {"done": false}
	var commit: Callable = func() -> void:
		if state["done"] or field.text.strip_edges() == text:
			return
		state["done"] = true
		on_commit.call(field.text.strip_edges())
	field.text_submitted.connect(func(_submitted: String) -> void: commit.call())
	field.focus_exited.connect(commit)
	return field


## Colour choice with a round swatch before each name.
func _color_choice(names: PackedStringArray, current: String, on_chosen: Callable) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	option.focus_mode = Control.FOCUS_NONE
	for color_name: String in names:
		option.add_icon_item(_swatch(color_name), tr(ControlBoxItem.COLOR_TITLES[ControlBoxItem.COLORS.find(color_name)]))
	option.select(maxi(names.find(current), 0))
	option.item_selected.connect(func(k: int) -> void: on_chosen.call(names[k]))
	return option


func _swatch(color_name: String) -> Texture2D:
	if not _swatches.has(color_name):
		var hex: String = "#" + ControlBoxView.COLORS[color_name].to_html(false)
		var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><circle cx="8" cy="8" r="6.5" fill="%s" stroke="#808080" stroke-width="1"/></svg>' % hex
		_swatches[color_name] = DPITexture.create_from_string(svg)
	return _swatches[color_name]
