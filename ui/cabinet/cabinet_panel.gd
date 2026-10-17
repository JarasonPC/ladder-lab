class_name CabinetPanel
extends PanelContainer
## Switchboard (rozvaděč) beside the schematic: the DIN rails of the document
## ([CabinetRail]) with its circuit breakers, fuse holders, contactors and
## overload relays, relays, time relays, bridge rectifiers, PLCs and terminal strips, drawn by a
## [CabinetView]. While simulating they show the circuit and breakers, fuse
## holders and overload relays are operated on them. While editing, rails
## are added and filled here; every change is emitted as one undoable edit
## of the document (see [method SchematicEditor.edit_cabinet]).

## The title was clicked: the panel rolls in to a tab.
signal roll_in_requested
## The window button was clicked: the panel moves to a window of its own.
signal window_requested
## A breaker, fuse holder or overload relay was clicked while simulating.
signal operate_requested(designation: String)
## A change of the switchboard: [param change] is called with the document.
signal edit_requested(change: Callable)

## English names of [enum CabinetDevices.Kind] (translated with tr()).
const KIND_TITLES: PackedStringArray = ["", "Circuit breaker", "Fuse holder", "Contactor", "Auxiliary relay", "Time relay", "Overload relay", "Bridge rectifier", "PLC"]

var _document: SchematicDocument
var _editing: bool = false
var _selected: Vector2i = Vector2i(-1, -1)
## Terminals (by label) of the selected terminal strip picked to move to another strip.
var _picked: Dictionary[String, bool] = {}
var _title: Button
var _header: HBoxContainer
var _window_button: Button
## Shown in a window of its own ([PanelWindow]): no title row, the window has it.
var in_window: bool = false:
	set(value):
		in_window = value
		if _header != null:
			_header.visible = not value
var _list: VBoxContainer
var _view: CabinetView
## Scrolls the zoomed switchboard sideways.
var _across: ScrollContainer
var _zoom_row: HBoxContainer
var _rebuild_queued: bool = false


func _ready() -> void:
	theme_type_variation = "RightPanel"
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	add_child(outer)
	# The title rolls the panel in to a tab (see [member SideBar.rolled]).
	_title = TimingPanel.rollout_button()
	_title.icon = AppTheme.icon("chevron_down", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.pressed.connect(func() -> void: roll_in_requested.emit())
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 2)
	_header.visible = not in_window
	_header.add_child(_title)
	_window_button = _tool("window", "")
	_window_button.pressed.connect(func() -> void: window_requested.emit())
	_header.add_child(_window_button)
	outer.add_child(_header)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_across = ScrollContainer.new()
	_across.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_across.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_across.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zoom_row = HBoxContainer.new()
	_zoom_row.add_theme_constant_override("separation", 2)
	_zoom_row.alignment = BoxContainer.ALIGNMENT_END
	_view = CabinetView.new()
	_across.add_child(_view)
	_view.zoom_changed.connect(_fill_zoom_row)
	_across.resized.connect(func() -> void:
		_view.update_minimum_size()
		_view.queue_redraw())
	_view.operate_requested.connect(func(designation: String) -> void: operate_requested.emit(designation))
	_view.place_clicked.connect(func(rail: int, index: int) -> void:
		if Vector2i(rail, index) != _selected:
			_picked.clear()
		_selected = Vector2i(rail, index)
		_rebuild_queued = true)
	_rebuild()


## Shows the switchboard of [param doc]; [param editing] offers the editing
## tools, otherwise it shows and operates the simulation of [param doc].
func set_document(doc: SchematicDocument, editing: bool) -> void:
	_document = doc
	_editing = editing
	if not editing:
		_selected = Vector2i(-1, -1)
	_rebuild()


## Shows the document again after it was edited.
func refresh() -> void:
	_rebuild_queued = true


func retranslate() -> void:
	_rebuild()


## Voltage reach of the last simulation step (terminal key -> reach code).
func show_step(result: StepResult) -> void:
	_view.reach = result.terminal_reach


func _process(_delta: float) -> void:
	if _rebuild_queued:
		_rebuild_queued = false
		_rebuild()
	if not _editing and is_visible_in_tree():
		# Levers, carriers, LEDs and voltage colours follow the simulation.
		_view.queue_redraw()


func _rebuild() -> void:
	if _list == null:
		return
	for kept: Control in [_zoom_row, _across]:
		if kept.get_parent() == _list:
			_list.remove_child(kept)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_title.text = tr("Switchboard")
	_title.tooltip_text = tr("Roll the panel in")
	_window_button.tooltip_text = tr("Open in a new window")
	if _document == null:
		return
	if _selected.x >= _document.cabinet_rails.size() or (_selected.x >= 0 and _selected.y >= _document.cabinet_rails[_selected.x].items.size()):
		_selected = Vector2i(-1, -1)
	if _document.cabinet_rails.is_empty():
		_note(tr("No DIN rails yet. Fill the switchboard from the schematic, or add a rail and put devices on it.") if _editing else tr("No switchboard yet. Make it in Edit mode."))
	_view.document = _document
	_view.simulating = not _editing
	_view.selected = _selected
	_fill_zoom_row()
	_list.add_child(_zoom_row)
	_list.add_child(_across)
	_view.refresh()
	if not _editing:
		return
	if _selected.x >= 0:
		_place_editor(_selected.x, _selected.y)
	for r: int in _document.cabinet_rails.size():
		_rail_row(r)
	_list.add_child(HSeparator.new())
	var add_rail: Button = _button(tr("Add rail"), "plus")
	add_rail.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_rail.tooltip_text = tr("Add an empty DIN rail at the bottom")
	add_rail.pressed.connect(func() -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.add_cabinet_rail()))
	_list.add_child(add_rail)
	var fill: Button = _button(tr("Fill from the schematic"), "cabinet")
	fill.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fill.tooltip_text = tr("Add rails with every device and terminal strip of the schematic that is not in the switchboard yet")
	fill.disabled = _document.cabinet_unplaced().is_empty()
	fill.pressed.connect(func() -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.fill_cabinet()))
	_list.add_child(fill)


## Zooming the drawing: out, in, back to the panel width (made once,
## their state and tooltips brought up to date here).
func _fill_zoom_row() -> void:
	if _zoom_row.get_child_count() == 0:
		for step: float in [1.0 / CabinetView.ZOOM_STEP, CabinetView.ZOOM_STEP, 0.0]:
			var button: Button = _tool("zoom_out" if step < 1.0 and step > 0.0 else ("zoom_in" if step > 1.0 else "fit"), "")
			button.pressed.connect(func() -> void: _zoom_by(step if step > 0.0 else 1.0 / _view.zoom))
			_zoom_row.add_child(button)
	var hint: String = tr("Ctrl+wheel over the switchboard zooms it, right or middle drag moves it.")
	var buttons: Array[Node] = _zoom_row.get_children()
	(buttons[0] as Button).tooltip_text = tr("Zoom out") + "\n" + hint
	(buttons[0] as Button).disabled = _view.zoom <= 1.0
	(buttons[1] as Button).tooltip_text = tr("Zoom in") + "\n" + hint
	(buttons[1] as Button).disabled = _view.zoom >= CabinetView.MAX_ZOOM
	(buttons[2] as Button).tooltip_text = tr("Fit the switchboard to the panel width")
	(buttons[2] as Button).disabled = _view.zoom <= 1.0


## Zooms about the middle of the part of the drawing in sight.
func _zoom_by(factor: float) -> void:
	var middle: Vector2 = Vector2(_across.scroll_horizontal + _across.size.x * 0.5, 0.0)
	_view.zoom_at(factor, middle)


## Rail [param r]: its name, a menu that adds a device or strip, move up, delete.
func _rail_row(r: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var name_label: Label = Label.new()
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.text = tr("Rail %d") % (r + 1)
	name_label.custom_minimum_size.x = 56.0
	row.add_child(name_label)
	var add: OptionButton = OptionButton.new()
	add.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add.focus_mode = Control.FOCUS_NONE
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.fit_to_longest_item = false
	var unplaced: Array[CabinetItem] = _document.cabinet_unplaced()
	add.add_icon_item(AppTheme.icon("plus"), tr("Add…"))
	for item: CabinetItem in unplaced:
		add.add_item(_item_title(item))
	add.select(0)
	add.disabled = unplaced.is_empty()
	add.tooltip_text = tr("Put a device or terminal strip on this rail")
	add.item_selected.connect(func(k: int) -> void:
		if k == 0:
			return
		var item: CabinetItem = unplaced[k - 1]
		_selected = Vector2i(r, _document.cabinet_rails[r].items.size())
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.add_cabinet_item(r, item.kind, item.designation)))
	row.add_child(add)
	var up: Button = _tool("arrow_up", tr("Move the rail up"))
	up.disabled = r == 0
	up.pressed.connect(func() -> void:
		_selected = Vector2i(-1, -1)
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_cabinet_rail(r, -1)))
	row.add_child(up)
	var remove: Button = _tool("delete", tr("Delete the rail"))
	remove.pressed.connect(func() -> void:
		_selected = Vector2i(-1, -1)
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.remove_cabinet_rail(r)))
	row.add_child(remove)
	_list.add_child(row)


## The selected place: what it is, move it along its rail or to another rail, remove it.
func _place_editor(r: int, i: int) -> void:
	var item: CabinetItem = _document.cabinet_rails[r].items[i]
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "FunctionCard"
	_list.add_child(card)
	var fields: VBoxContainer = VBoxContainer.new()
	fields.add_theme_constant_override("separation", 4)
	card.add_child(fields)
	var heading: Label = Label.new()
	heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	heading.text = _item_title(item)
	fields.add_child(heading)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 2)
	fields.add_child(actions)
	var count: int = _document.cabinet_rails[r].items.size()
	for step: int in [-1, 1]:
		var move: Button = _tool("arrow_left" if step < 0 else "arrow_right", tr("Move it one place left") if step < 0 else tr("Move it one place right"))
		move.disabled = i + step < 0 or i + step >= count
		move.pressed.connect(func() -> void:
			_selected = Vector2i(r, i + step)
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_cabinet_item(r, i, step)))
		actions.add_child(move)
	for step: int in [-1, 1]:
		var to_rail: Button = _tool("arrow_up" if step < 0 else "arrow_down", tr("Move it to the rail above") if step < 0 else tr("Move it to the rail below"))
		to_rail.disabled = r + step < 0 or r + step >= _document.cabinet_rails.size()
		to_rail.pressed.connect(func() -> void:
			_selected = Vector2i(r + step, _document.cabinet_rails[r + step].items.size())
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_cabinet_item_to_rail(r, i, step)))
		actions.add_child(to_rail)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var remove: Button = _button(tr("Remove"), "delete")
	remove.pressed.connect(func() -> void:
		_selected = Vector2i(-1, -1)
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.remove_cabinet_item(r, i)))
	actions.add_child(remove)
	if item.kind == CabinetItem.Kind.STRIP:
		_strip_split(fields, item.designation)


## Splitting terminal strip [param strip]: its terminals to pick and where
## to move the picked ones (another strip or a new one).
func _strip_split(fields: VBoxContainer, strip: String) -> void:
	var terminals: Array = CabinetDevices.strips(_document).get(strip, [])
	if terminals.is_empty():
		return
	var labels: PackedStringArray = PackedStringArray()
	for t: Dictionary in terminals:
		labels.append(t["label"])
	for label: String in _picked.keys():
		if not labels.has(label):
			_picked.erase(label)
	var hint: Label = Label.new()
	hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	hint.theme_type_variation = "MutedLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = tr("Pick terminals to move them to another strip.")
	fields.add_child(hint)
	var move: OptionButton = OptionButton.new()
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 2)
	fields.add_child(flow)
	for label: String in labels:
		var pick: Button = Button.new()
		pick.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		pick.focus_mode = Control.FOCUS_NONE
		pick.toggle_mode = true
		pick.text = label
		pick.custom_minimum_size.x = 28.0
		pick.button_pressed = _picked.has(label)
		pick.toggled.connect(func(on: bool) -> void:
			if on:
				_picked[label] = true
			else:
				_picked.erase(label)
			move.disabled = _picked.is_empty())
		flow.add_child(pick)
	var targets: PackedStringArray = PackedStringArray()
	for other: String in CabinetDevices.strips(_document):
		if other != strip:
			targets.append(other)
	var fresh: String = _document.next_strip_name()
	move.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	move.focus_mode = Control.FOCUS_NONE
	move.fit_to_longest_item = false
	move.add_item(tr("Move to…"))
	for other: String in targets:
		move.add_item(tr("Terminal strip") + " -" + other)
	move.add_item(tr("New strip -%s") % fresh)
	targets.append(fresh)
	move.select(0)
	move.disabled = _picked.is_empty()
	move.tooltip_text = tr("Move the picked terminals to another terminal strip")
	move.item_selected.connect(func(k: int) -> void:
		if k == 0 or _picked.is_empty():
			return
		var picked: PackedStringArray = PackedStringArray(_picked.keys())
		var target: String = targets[k - 1]
		_picked.clear()
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_strip_terminals(strip, picked, target)))
	fields.add_child(move)


## "Contactor -KM1", "Terminal strip -X1".
func _item_title(item: CabinetItem) -> String:
	if item.kind == CabinetItem.Kind.STRIP:
		return tr("Terminal strip") + " -" + item.designation
	var c: CircuitComponent = CabinetDevices.device(_document.circuit, item.designation)
	if c == null:
		return "-%s (%s)" % [item.designation, tr("not in the schematic")]
	return tr(KIND_TITLES[CabinetDevices.kind_of(c)]) + " -" + item.designation


# --- Controls ---------------------------------------------------------------------

func _note(text: String) -> void:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.theme_type_variation = "MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_list.add_child(label)


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
