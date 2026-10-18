class_name StationPanel
extends HBoxContainer
## One control station of the workspace ([ControlBox]), opened from it: its
## push buttons, switches and signal lamps drawn large by a [ControlBoxView].
## While simulating they operate the circuit and show its lamps. While
## editing, the tools beside it fill the station: click an item to choose its
## device, colour, plate text and a signal lamp inside it (illuminated
## button). Every change is emitted as one undoable edit of the document (see
## [method SchematicEditor.edit_workspace]).

## A push button was pressed (true) or let go (false) on the station.
signal button_held(designation: String, pressed: bool)
## A switch was turned over on the station.
signal switch_toggled(designation: String)
## A change of the station: [param change] is called with the document.
signal edit_requested(change: Callable)
## A key should be bound to push button or switch [param designation].
signal key_bind_requested(designation: String)

## English names of [enum ControlBoxItem.Kind] (translated with tr()).
const KIND_TITLES: PackedStringArray = ["Push button", "Switch", "Signal lamp"]
## How large the station is drawn at first (Ctrl+wheel zooms it).
const ZOOM: float = 2.0

## Name of the station shown ([member ControlBox.name]).
var station_name: String = ""
var _document: SchematicDocument
var _editing: bool = false
var _selected_item: int = -1
## Editing tools beside the drawing (Edit mode only).
var _tools: PanelContainer
var _list: VBoxContainer
var _note: Label
var _view: ControlBoxView
var _rebuild_queued: bool = false
var _swatches: Dictionary[String, Texture2D] = {}
var _menu: PopupMenu
var _menu_device: String = ""


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(left)
	_note = Label.new()
	_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_note.theme_type_variation = "MutedLabel"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_note)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var zoom_box: ZoomBox = ZoomBox.new()
	zoom_box.zoom = ZOOM
	center.add_child(zoom_box)
	_view = ControlBoxView.new()
	_view.button_held.connect(func(designation: String, pressed: bool) -> void: button_held.emit(designation, pressed))
	_view.switch_toggled.connect(func(designation: String) -> void: switch_toggled.emit(designation))
	_view.item_clicked.connect(func(index: int) -> void:
		_selected_item = index
		_rebuild_queued = true)
	_view.item_menu.connect(_open_item_menu)
	_menu = PopupMenu.new()
	_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_menu.id_pressed.connect(func(_id: int) -> void: key_bind_requested.emit(_menu_device))
	add_child(_menu)
	zoom_box.add_child(_view)
	_tools = PanelContainer.new()
	_tools.theme_type_variation = "RightPanel"
	_tools.custom_minimum_size.x = 300.0
	add_child(_tools)
	var tools_scroll: ScrollContainer = ScrollContainer.new()
	tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tools.add_child(tools_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	tools_scroll.add_child(_list)
	_rebuild()


## Shows station [member station_name] of [param doc]; [param editing]
## offers the editing tools, otherwise it operates the simulation of [param doc].
func set_document(doc: SchematicDocument, editing: bool) -> void:
	_document = doc
	_editing = editing
	if not editing:
		_selected_item = -1
	_rebuild()


## Shows the document again after it was edited (devices renamed, items changed).
func refresh() -> void:
	_rebuild_queued = true


func retranslate() -> void:
	_rebuild()


## Selects the item showing device [param designation] (Edit mode).
func select_device(designation: String) -> void:
	var b: int = _box()
	if b < 0 or not _editing:
		return
	var items: Array[ControlBoxItem] = _document.control_boxes[b].items
	for i: int in items.size():
		if items[i].designation == designation or items[i].lamp == designation:
			_selected_item = i
			_rebuild()
			return


## Right click on item [param index]: bind a key to its button or switch (Edit mode).
func _open_item_menu(index: int) -> void:
	var b: int = _box()
	if not _editing or b < 0 or index >= _document.control_boxes[b].items.size():
		return
	var item: ControlBoxItem = _document.control_boxes[b].items[index]
	if item.designation.is_empty() or not _document.can_have_key(item.designation):
		return
	_menu_device = item.designation
	_menu.clear()
	var key: String = _document.key_bindings.get(item.designation, "")
	_menu.add_item(tr("Bind a key…") + ("  [%s]" % key if not key.is_empty() else ""))
	_menu.reset_size()
	_menu.popup_on_parent(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i.ZERO))


func _process(_delta: float) -> void:
	if _rebuild_queued:
		_rebuild_queued = false
		_rebuild()
	if not _editing and is_visible_in_tree():
		# Buttons, switches and lamps follow the simulation.
		_view.queue_redraw()


## Index of the station shown, -1 when the document has none of that name.
func _box() -> int:
	if _document == null:
		return -1
	for b: int in _document.control_boxes.size():
		if _document.control_boxes[b].name == station_name:
			return b
	return -1


func _rebuild() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var b: int = _box()
	_tools.visible = _editing and b >= 0
	_view.document = _document
	_view.box_index = b
	_view.simulating = not _editing
	if b < 0:
		_note.visible = false
		_view.update_minimum_size()
		_view.queue_redraw()
		return
	var box: ControlBox = _document.control_boxes[b]
	if _selected_item >= box.items.size():
		_selected_item = -1
	_view.selected = _selected_item
	_view.update_minimum_size()
	_view.queue_redraw()
	_note.visible = box.items.is_empty()
	_note.text = tr("No push buttons, switches or lamps on this station yet.") if _editing else tr("No push buttons, switches or lamps on this station yet. Add them in Edit mode.")
	if not _editing:
		return
	_caption(_list, tr("Text on the station"))
	_list.add_child(_text_field(box.title, tr("Text on the station"), func(text: String) -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.set_control_box(b, text, box.columns))))
	_caption(_list, tr("Items in a row"))
	var columns: OptionButton = _option(_list)
	for n: int in range(1, ControlBox.MAX_COLUMNS + 1):
		columns.add_icon_item(AppTheme.icon("columns"), str(n))
	columns.select(box.columns - 1)
	columns.item_selected.connect(func(k: int) -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.set_control_box(b, box.title, k + 1)))
	_add_buttons(b)
	var add_all: Button = _button(tr("Add all the others"), "panel")
	add_all.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_all.tooltip_text = tr("Put every push button, switch and signal lamp that is not on a station yet on this one")
	add_all.disabled = not _has_unlisted_devices()
	add_all.pressed.connect(func() -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.fill_control_box(b)))
	_list.add_child(add_all)
	if _selected_item >= 0:
		_list.add_child(HSeparator.new())
		_item_editor(b, _selected_item)


## Buttons that add a push button, a switch or a lamp to station [param b].
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
			_selected_item = _document.control_boxes[b].items.size()
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
			_selected_item = i + step
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_control_item(b, i, step)))
		actions.add_child(move)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var remove: Button = _button(tr("Remove"), "delete")
	remove.pressed.connect(func() -> void:
		_selected_item = -1
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
