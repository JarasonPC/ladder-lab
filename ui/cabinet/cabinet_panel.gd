class_name CabinetPanel
extends HBoxContainer
## One switchboard (rozvaděč) of the workspace, opened from it: its DIN rails
## ([CabinetRail]) with circuit breakers, fuse holders, contactors and
## overload relays, relays, time relays, bridge rectifiers, PLCs, frequency
## inverters and terminal strips, drawn by a [CabinetView]. While simulating
## they show the circuit and breakers, fuse holders and overload relays are
## operated on them. While editing, the tools beside the drawing add and fill
## rails; every change is emitted as one undoable edit of the document (see
## [method SchematicEditor.edit_cabinet]). Its door (Inside | Door | Door
## open at the top) is drawn by a [DoorView] and holds push buttons, switches
## and lamps like a control station, edited and operated the same way; Door
## open shows the switchboard with the door opened beside it, the back of the
## door with its contact blocks and wires and the door harness running from
## the switchboard to it ([member CabinetView.door_open]). Wiring a training
## plan whose student mounts the parts, the tools put the plan's parts on the
## rails and the door and arrange them (see [member TrainingPlan.mount_parts]).

## A breaker, fuse holder or overload relay was clicked while simulating.
signal operate_requested(designation: String)
## A change of the switchboard: [param change] is called with the document.
signal edit_requested(change: Callable)
## A change of its door (see [method SchematicEditor.edit_workspace]).
signal door_edit_requested(change: Callable)
## A push button on the door was pressed (true) or let go (false).
signal button_held(designation: String, pressed: bool)
## A switch on the door was turned (see [signal ControlBoxView.switch_toggled]).
signal switch_toggled(designation: String, steps: int)
## A key should be bound to push button or switch [param designation].
signal key_bind_requested(designation: String)

## English names of [enum CabinetDevices.Kind] (translated with tr()).
const KIND_TITLES: PackedStringArray = ["", "Circuit breaker", "Fuse holder", "Contactor", "Auxiliary relay", "Time relay", "Overload relay", "Bridge rectifier", "PLC", "Frequency inverter", "Network switch"]

## Name of the switchboard shown ([member Switchboard.name]).
var board_name: String = ""
## The door is shown instead of the inside.
var door_shown: bool = false:
	set(value):
		door_shown = value
		if value:
			door_open = false
		_press_side()
		_rebuild_queued = true
## The inside is shown with the door opened beside it.
var door_open: bool = false:
	set(value):
		door_open = value
		if value:
			door_shown = false
		_press_side()
		_rebuild_queued = true
var _document: SchematicDocument
var _editing: bool = false
var _selected: Vector2i = Vector2i(-1, -1)
## Terminals (by label) of the selected terminal strip picked to move to another strip.
var _picked: Dictionary[String, bool] = {}
## Editing tools beside the drawing (Edit mode only).
var _tools: PanelContainer
var _list: VBoxContainer
var _note: Label
var _view: CabinetView
## Scrolls the zoomed switchboard sideways.
var _across: ScrollContainer
var _zoom_row: HBoxContainer
var _rebuild_queued: bool = false
## Scrolls the switchboard down; hidden while the door is shown.
var _down: ScrollContainer
var _inside_button: Button
var _door_button: Button
var _open_button: Button
var _door: DoorView
## The colour and number of the wire laid or picked (wiring a training plan).
var _wire_bar: TrainingWireBar
## Item of the door selected for editing, -1 for none.
var _door_selected: int = -1
var _door_tools: ControlItemTools = ControlItemTools.new()
var _menu: PopupMenu
var _menu_device: String = ""
## The temperature rise of the switchboard worked out (Edit mode).
var _heat_dialog: HeatRiseDialog


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	margin.add_child(left)
	var top: HBoxContainer = HBoxContainer.new()
	left.add_child(top)
	# Inside | Door as one segmented switch.
	var track: PanelContainer = PanelContainer.new()
	track.theme_type_variation = "SegmentTrack"
	top.add_child(track)
	var segments: HBoxContainer = HBoxContainer.new()
	segments.add_theme_constant_override("separation", 2)
	track.add_child(segments)
	var sides: ButtonGroup = ButtonGroup.new()
	_inside_button = _button("", "cabinet")
	_door_button = _button("", "panel")
	_open_button = _button("", "cabinet")
	for side_button: Button in [_inside_button, _door_button, _open_button]:
		side_button.theme_type_variation = "SegmentButton"
		side_button.toggle_mode = true
		side_button.button_group = sides
		segments.add_child(side_button)
	_press_side()
	_inside_button.pressed.connect(func() -> void:
		door_shown = false
		door_open = false)
	_door_button.pressed.connect(func() -> void: door_shown = true)
	_open_button.pressed.connect(func() -> void: door_open = true)
	_zoom_row = HBoxContainer.new()
	_zoom_row.add_theme_constant_override("separation", 2)
	_zoom_row.alignment = BoxContainer.ALIGNMENT_END
	_zoom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_zoom_row)
	_note = Label.new()
	_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_note.theme_type_variation = "MutedLabel"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_note)
	_wire_bar = TrainingWireBar.new()
	_wire_bar.visible = false
	_wire_bar.edit_requested.connect(func(change: Callable) -> void: edit_requested.emit(change))
	left.add_child(_wire_bar)
	var down: ScrollContainer = ScrollContainer.new()
	down.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	down.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(down)
	_down = down
	_door = DoorView.new()
	_door.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_door.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_door)
	_door.button_held.connect(func(designation: String, pressed: bool) -> void: button_held.emit(designation, pressed))
	_door.switch_toggled.connect(func(designation: String, steps: int) -> void: switch_toggled.emit(designation, steps))
	_door.item_clicked.connect(func(index: int) -> void:
		_door_selected = index
		_rebuild_queued = true)
	_door.item_menu.connect(_open_door_menu)
	_door_tools.edit = func(change: Callable) -> void: door_edit_requested.emit(change)
	_door_tools.select = func(index: int) -> void: _door_selected = index
	_menu = PopupMenu.new()
	_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_menu.id_pressed.connect(func(_id: int) -> void: key_bind_requested.emit(_menu_device))
	add_child(_menu)
	_heat_dialog = HeatRiseDialog.new()
	_heat_dialog.saved.connect(func(settings: Dictionary) -> void:
		var board: String = board_name
		edit_requested.emit(func(doc: SchematicDocument) -> void:
			for sb: Switchboard in doc.switchboards:
				if sb.name == board:
					sb.heat = HeatRise.changed(settings)))
	add_child(_heat_dialog)
	_across = ScrollContainer.new()
	_across.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_across.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_across.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	down.add_child(_across)
	# Opened from the workspace, the whole switchboard fits in sight at first.
	down.resized.connect(func() -> void: _view.fit_height = maxf(down.size.y - 2.0, 0.0))
	_view = CabinetView.new()
	_across.add_child(_view)
	_view.zoom_changed.connect(_fill_zoom_row)
	_across.resized.connect(func() -> void:
		_view.update_minimum_size()
		_view.queue_redraw())
	_view.operate_requested.connect(func(designation: String) -> void: operate_requested.emit(designation))
	# Wiring a training plan: the student's wires, one undoable edit each.
	_view.wire_drawn.connect(func(place: String, a: String, b: String) -> void:
		var colour: String = TrainingWireBar.colour
		var number: String = TrainingWireBar.number
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.training.add_wire(place, a, b, colour, number)))
	_view.wire_picked.connect(func(place: String, index: int) -> void: _wire_bar.show_wire(_document, place, index))
	_view.wire_removed.connect(func(place: String, index: int) -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.training.remove_wire(place, index)))
	_view.place_clicked.connect(func(rail: int, index: int) -> void:
		if not _editing and not _mounting():
			return
		if Vector2i(rail, index) != _selected:
			_picked.clear()
		_selected = Vector2i(rail, index)
		_rebuild_queued = true)
	_tools = PanelContainer.new()
	_tools.theme_type_variation = "RightPanel"
	_tools.custom_minimum_size.x = 300.0
	add_child(_tools)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tools.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_rebuild()


## Shows switchboard [member board_name] of [param doc]; [param editing]
## offers the editing tools, otherwise it shows and operates the simulation
## of [param doc].
func set_document(doc: SchematicDocument, editing: bool) -> void:
	_document = doc
	_editing = editing
	if not editing and not _mounting():
		_selected = Vector2i(-1, -1)
		_door_selected = -1
	_rebuild()


## Whether a training plan is wired here whose student mounts the parts.
func _mounting() -> bool:
	return _document != null and _document.training != null and _document.training.drawn == null and _document.training.mount_parts


## Shows the document again after it was edited.
func refresh() -> void:
	_rebuild_queued = true


func retranslate() -> void:
	_rebuild()


## Selects the place of device or terminal strip [param designation] (Edit mode).
func select_item(kind: CabinetItem.Kind, designation: String) -> void:
	var b: int = _board()
	if b < 0 or not _editing:
		return
	var rails: Array[CabinetRail] = _document.switchboards[b].rails
	for r: int in rails.size():
		for i: int in rails[r].items.size():
			if rails[r].items[i].kind == kind and rails[r].items[i].designation == designation:
				_picked.clear()
				_selected = Vector2i(r, i)
				_rebuild()
				return


## Presses the segment of what is shown (inside, door, door open).
func _press_side() -> void:
	if _inside_button == null:
		return
	(_door_button if door_shown else (_open_button if door_open else _inside_button)).button_pressed = true


## Shows the door with the item of device [param designation] selected
## (Edit mode; also the lamp inside a button).
func select_door_device(designation: String) -> void:
	var b: int = _board()
	if b < 0:
		return
	door_shown = true
	if not _editing:
		return
	var items: Array[ControlBoxItem] = _document.switchboards[b].door.items
	for i: int in items.size():
		if items[i].designation == designation or items[i].lamp == designation:
			_door_selected = i
	_rebuild_queued = true


## Right click on door item [param index]: bind a key to its button or switch (Edit mode).
func _open_door_menu(index: int) -> void:
	var b: int = _board()
	if not _editing or b < 0 or index >= _document.switchboards[b].door.items.size():
		return
	var item: ControlBoxItem = _document.switchboards[b].door.items[index]
	if item.designation.is_empty() or not _document.can_have_key(item.designation):
		return
	_menu_device = item.designation
	_menu.clear()
	var key: String = _document.key_bindings.get(item.designation, "")
	_menu.add_item(tr("Bind a key…") + ("  [%s]" % key if not key.is_empty() else ""))
	_menu.reset_size()
	AppTheme.popup_at_mouse(_menu)


## Voltage reach of the last simulation step (terminal key -> reach code).
func show_step(result: StepResult) -> void:
	_view.reach = result.terminal_reach


func _process(_delta: float) -> void:
	if _rebuild_queued:
		_rebuild_queued = false
		_rebuild()
	if not _editing and is_visible_in_tree():
		# Levers, carriers, LEDs and voltage colours follow the simulation;
		# so do the buttons, switches and lamps on the door.
		if door_shown:
			_door.queue_redraw()
		else:
			_view.queue_redraw()


## Index of the switchboard shown, -1 when the document has none of that name.
func _board() -> int:
	if _document == null:
		return -1
	for b: int in _document.switchboards.size():
		if _document.switchboards[b].name == board_name:
			return b
	return -1


func _rebuild() -> void:
	if _list == null:
		return
	# A text typed on a door item and not entered yet is committed before its
	# field goes (see StationPanel).
	_door_tools.document = _document
	_door_tools.editing = _editing
	_door_tools.commit_pending()
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var b: int = _board()
	_tools.visible = (_editing or _mounting()) and b >= 0
	_inside_button.text = tr("Inside")
	_inside_button.tooltip_text = tr("The DIN rails with the devices and their wiring")
	_door_button.text = tr("Door")
	_door_button.tooltip_text = tr("The push buttons, switches and signal lamps on the door")
	_open_button.text = tr("Door open")
	_open_button.tooltip_text = tr("The switchboard with its door opened beside it: the back of the door with its contact blocks and wires, the door harness running across to it")
	if _view.door_open != door_open:
		_view.door_open = door_open
	_down.visible = not door_shown
	_door.visible = door_shown
	_wire_bar.visible = false
	_zoom_row.visible = not door_shown
	if b < 0:
		_note.visible = false
		_view.document = null
		_view.refresh()
		_door.document = null
		return
	if door_shown:
		_rebuild_door(b)
		return
	var rails: Array[CabinetRail] = _document.switchboards[b].rails
	if _selected.x >= rails.size() or (_selected.x >= 0 and _selected.y >= rails[_selected.x].items.size()):
		_selected = Vector2i(-1, -1)
	# A training plan is wired here, and runs as wired (a simulated copy).
	var training: bool = _document.training != null
	var wiring: bool = training and _document.training.drawn == null
	_note.visible = rails.is_empty() or wiring
	_note.text = tr("No DIN rails yet. Fill the switchboard from the schematic, or add a rail and put devices on it.") if _editing else tr("No DIN rails yet. Make them in Edit mode.")
	if wiring:
		_note.text = tr("Click a terminal or a cable's core, then where the wire goes. Click a wire and press Delete to take it away.")
		if _mounting():
			_note.text = tr("Mount the parts with the tools on the right (a click on a part picks it), then wire them: click a terminal or a cable's core, then where the wire goes. Click a wire and press Delete to take it away.")
		if _document.training.locked():
			_note.text = tr("The switchboard is wired. Run it in Simulate to look for the faults.")
	_wire_bar.visible = wiring and not _document.training.locked()
	if wiring:
		_wire_bar.refresh(_document)
	_view.document = _document
	_view.board = b
	_view.wiring_mode = training
	_view.simulating = not _editing and not wiring
	_view.selected = _selected
	_fill_zoom_row()
	_view.refresh()
	if not _editing:
		if _mounting():
			_mount_tools(b)
		return
	if _selected.y < 0 and _selected.x >= 0 and _view.place_of(_selected.x, _selected.y).is_empty():
		# The distribution block picked is not there any more.
		_selected = Vector2i(-1, -1)
		_view.selected = _selected
	if _selected.x >= 0 and _selected.y < 0:
		_bus_editor(b, _selected.x, _view.place_of(_selected.x, _selected.y))
	elif _selected.x >= 0:
		_place_editor(b, _selected.x, _selected.y)
	for r: int in rails.size():
		_rail_row(b, r)
	_list.add_child(HSeparator.new())
	var add_rail: Button = _button(tr("Add rail"), "plus")
	add_rail.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_rail.tooltip_text = tr("Add an empty DIN rail at the bottom")
	add_rail.pressed.connect(func() -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.add_cabinet_rail(b)))
	_list.add_child(add_rail)
	var fill: Button = _button(tr("Fill from the schematic"), "cabinet")
	fill.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fill.tooltip_text = tr("Add rails with every device and terminal strip of the schematic that is not in a switchboard yet")
	fill.disabled = _document.cabinet_unplaced().is_empty()
	fill.pressed.connect(func() -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.fill_cabinet(b)))
	_list.add_child(fill)
	_list.add_child(HSeparator.new())
	_heat_tools(b)


## How warm switchboard [param b] gets inside with what is on its rails (see
## [HeatRise]), and the button opening the calculation to fill in.
func _heat_tools(b: int) -> void:
	var layout: CabinetLayout = _view.layout()
	if not _document.switchboards[b].rails.is_empty() and layout != null and layout.size.x > 0.0:
		var evaluated: Dictionary = HeatRise.evaluate(_document, b, layout.size, layout.wiring.wires if layout.wiring != null else [])
		var r: Dictionary = evaluated["result"]
		var s: Dictionary = evaluated["settings"]
		var summary: Label = Label.new()
		summary.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.text = tr("Temperature rise: at the top about %s °C (%s °C around, at most %s °C), %s W lost inside") % [
			String.num(r["temperature"], 0), String.num(s["ambient"], 0), String.num(s["limit"], 0), String.num(evaluated["losses"]["total"], 0)]
		summary.add_theme_color_override("font_color", AppTheme.success if r["ok"] else AppTheme.danger)
		_list.add_child(summary)
	var open: Button = _button(tr("Temperature rise…"), "thermometer")
	open.alignment = HORIZONTAL_ALIGNMENT_LEFT
	open.tooltip_text = tr("Work out how warm the air inside gets (IEC 890 / ČSN 33 7107): fill in the enclosure, how it is installed and the devices' losses")
	open.disabled = layout == null or _document.switchboards[b].rails.is_empty()
	open.pressed.connect(func() -> void: _heat_dialog.open(_document, b, _view.layout()))
	_list.add_child(open)


## The student mounting the parts of a training plan in switchboard
## [param b]: what is left to mount, the part picked, the rails.
func _mount_tools(b: int) -> void:
	var left: int = _unplaced(b).size()
	var count: Label = Label.new()
	count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	count.theme_type_variation = "MutedLabel"
	count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	count.text = tr_n("%d part to mount", "%d parts to mount", left) % left if left > 0 else tr("Every part is mounted.")
	_list.add_child(count)
	if _selected.x >= 0 and _selected.y >= 0:
		_place_editor(b, _selected.x, _selected.y)
	for r: int in _document.switchboards[b].rails.size():
		_rail_row(b, r)
	_list.add_child(HSeparator.new())
	var add_rail: Button = _button(tr("Add rail"), "plus")
	add_rail.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_rail.tooltip_text = tr("Add an empty DIN rail at the bottom")
	add_rail.pressed.connect(func() -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.add_cabinet_rail(b)))
	_list.add_child(add_rail)


## What can be put on the rails of switchboard [param b]: what has no place
## in a switchboard yet, or, while the student mounts the parts of a
## training plan, what the plan has there and is not mounted yet.
func _unplaced(b: int) -> Array[CabinetItem]:
	if not _mounting():
		return _document.cabinet_unplaced()
	var result: Array[CabinetItem] = []
	for data: Dictionary in _document.training.unmounted(_document, "+" + _document.switchboards[b].name):
		var item: CabinetItem = CabinetItem.from_data(data)
		if item != null and not _document.cabinet_has(item.kind, item.designation):
			result.append(item)
	return result


## The door of switchboard [param b] and, while editing, its tools: items
## in a row, buttons adding items, the selected item's fields.
func _rebuild_door(b: int) -> void:
	var door: ControlBox = _document.switchboards[b].door
	if _door_selected >= door.items.size():
		_door_selected = -1
	_view.document = _document
	_view.board = b
	_view.refresh()
	var panel: int = _document.door_panel(b)
	_door.document = _document
	_door.box_index = panel
	_door.board = b
	_door.simulating = not _editing and not _mounting()
	_door.selected = _door_selected
	if _view.plate_size().x > 0.0:
		_door.enclosure = _view.plate_size()
	_door.queue_redraw()
	_note.visible = door.items.is_empty()
	_note.text = tr("No push buttons, switches or lamps on this door yet.") if _editing else tr("No push buttons, switches or lamps on this door yet. Add them in Edit mode.")
	if not _editing and _mounting():
		_note.text = tr("Put the parts on the door with the tools on the right.")
	if not _editing and not _mounting():
		return
	var tools: ControlItemTools = _door_tools
	tools.document = _document
	tools.panel = panel
	tools.list = _list
	tools.editing = _editing
	tools.make_caption(_list, tr("Items in a row"))
	var columns: OptionButton = tools.make_option(_list)
	for n: int in range(1, ControlBox.MAX_COLUMNS + 1):
		columns.add_icon_item(AppTheme.icon("columns"), str(n))
	columns.select(door.columns - 1)
	columns.item_selected.connect(func(k: int) -> void:
		door_edit_requested.emit(func(doc: SchematicDocument) -> void: doc.set_control_box(panel, "", k + 1)))
	if not _editing:
		tools.add_mount_choice("+" + _document.switchboards[b].name + "/door")
		if _door_selected >= 0:
			_list.add_child(HSeparator.new())
			tools.mount_editor(_door_selected)
		return
	tools.add_buttons()
	tools.add_all_button(tr("Put every push button, switch and signal lamp that is not on a station or a door yet on this door"))
	if _door_selected >= 0:
		_list.add_child(HSeparator.new())
		tools.item_editor(_door_selected)


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
func _rail_row(b: int, r: int) -> void:
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
	var unplaced: Array[CabinetItem] = _unplaced(b)
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
		_selected = Vector2i(r, _document.switchboards[b].rails[r].items.size())
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.add_cabinet_item(b, r, item.kind, item.designation)))
	row.add_child(add)
	var up: Button = _tool("arrow_up", tr("Move the rail up"))
	up.disabled = r == 0
	up.pressed.connect(func() -> void:
		_selected = Vector2i(-1, -1)
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_cabinet_rail(b, r, -1)))
	row.add_child(up)
	var remove: Button = _tool("delete", tr("Delete the rail"))
	remove.pressed.connect(func() -> void:
		_selected = Vector2i(-1, -1)
		edit_requested.emit(func(doc: SchematicDocument) -> void:
			doc.remove_cabinet_rail(b, r)
			# The student's wires to the parts taken off go with them.
			TrainingCheck.drop_loose_wires(doc)))
	row.add_child(remove)
	_list.add_child(row)


## The selected place: what it is, move it along its rail or to another rail, remove it.
func _place_editor(b: int, r: int, i: int) -> void:
	var rails: Array[CabinetRail] = _document.switchboards[b].rails
	var item: CabinetItem = rails[r].items[i]
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
	var count: int = rails[r].items.size()
	for step: int in [-1, 1]:
		var move: Button = _tool("arrow_left" if step < 0 else "arrow_right", tr("Move it one place left") if step < 0 else tr("Move it one place right"))
		move.disabled = i + step < 0 or i + step >= count
		move.pressed.connect(func() -> void:
			_selected = Vector2i(r, i + step)
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_cabinet_item(b, r, i, step)))
		actions.add_child(move)
	for step: int in [-1, 1]:
		var to_rail: Button = _tool("arrow_up" if step < 0 else "arrow_down", tr("Move it to the rail above") if step < 0 else tr("Move it to the rail below"))
		to_rail.disabled = r + step < 0 or r + step >= rails.size()
		to_rail.pressed.connect(func() -> void:
			_selected = Vector2i(r + step, rails[r + step].items.size())
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_cabinet_item_to_rail(b, r, i, step)))
		actions.add_child(to_rail)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	if item.kind == CabinetItem.Kind.BUS:
		# The switchboard adds it while it is needed: it moves, it is not removed.
		return
	var remove: Button = _button(tr("Remove"), "delete")
	remove.pressed.connect(func() -> void:
		_selected = Vector2i(-1, -1)
		edit_requested.emit(func(doc: SchematicDocument) -> void:
			doc.remove_cabinet_item(b, r, i)
			TrainingCheck.drop_loose_wires(doc)))
	actions.add_child(remove)
	if item.kind == CabinetItem.Kind.STRIP and not _mounting():
		_strip_split(fields, item.designation)


## The distribution block [param place] the switchboard put by itself on
## rail [param r]: moving it puts it on the rail as an item, where it then
## stays (see [method SchematicDocument.place_bus_block]).
func _bus_editor(b: int, r: int, place: Dictionary) -> void:
	var rails: Array[CabinetRail] = _document.switchboards[b].rails
	var name: String = place["designation"]
	var slot: int = place["slot"]
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "FunctionCard"
	_list.add_child(card)
	var fields: VBoxContainer = VBoxContainer.new()
	fields.add_theme_constant_override("separation", 4)
	card.add_child(fields)
	var heading: Label = Label.new()
	heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	heading.text = _bus_title(name)
	fields.add_child(heading)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 2)
	fields.add_child(actions)
	for step: int in [-1, 1]:
		var move: Button = _tool("arrow_left" if step < 0 else "arrow_right", tr("Move it one place left") if step < 0 else tr("Move it one place right"))
		# It stands before the item at slot: one place left is before the
		# item before it, one place right after the item after it.
		var at: int = slot + step
		move.disabled = at < 0 or at > rails[r].items.size()
		move.pressed.connect(func() -> void:
			_selected = Vector2i(r, at)
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.place_bus_block(b, r, at, name)))
		actions.add_child(move)
	for step: int in [-1, 1]:
		var to_rail: Button = _tool("arrow_up" if step < 0 else "arrow_down", tr("Move it to the rail above") if step < 0 else tr("Move it to the rail below"))
		to_rail.disabled = r + step < 0 or r + step >= rails.size()
		to_rail.pressed.connect(func() -> void:
			_selected = Vector2i(r + step, rails[r + step].items.size())
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.place_bus_block(b, r + step, rails[r + step].items.size(), name)))
		actions.add_child(to_rail)


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
	hint.text = tr("Pick terminals to move them along the strip or to another strip.")
	fields.add_child(hint)
	var move: OptionButton = OptionButton.new()
	var along: Array[Button] = []
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
			move.disabled = _picked.is_empty()
			for button: Button in along:
				button.disabled = _picked.is_empty())
		flow.add_child(pick)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	fields.add_child(row)
	for step: int in [-1, 1]:
		var shift: Button = _tool("arrow_left" if step < 0 else "arrow_right", tr("Move the picked terminals one place left") if step < 0 else tr("Move the picked terminals one place right"))
		shift.disabled = _picked.is_empty()
		shift.pressed.connect(func() -> void:
			var picked: PackedStringArray = PackedStringArray(_picked.keys())
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_strip_terminals_along(strip, picked, step)))
		row.add_child(shift)
		along.append(shift)
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
	move.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	row.add_child(move)


## "Contactor -KM1", "Terminal strip -X1", "N distribution block".
func _item_title(item: CabinetItem) -> String:
	if item.kind == CabinetItem.Kind.STRIP:
		return tr("Terminal strip") + " -" + item.designation
	if item.kind == CabinetItem.Kind.BUS:
		return _bus_title(item.designation)
	var c: CircuitComponent = CabinetDevices.device(_document.circuit, item.designation)
	if c == null:
		return "-%s (%s)" % [item.designation, tr("not in the schematic")]
	return tr(KIND_TITLES[CabinetDevices.kind_of(c)]) + " -" + item.designation


## "N distribution block" or "PE distribution block" for [param name] "N" or "PE".
func _bus_title(name: String) -> String:
	return tr("N distribution block") if name == "N" else tr("PE distribution block")


# --- Controls ---------------------------------------------------------------------

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
