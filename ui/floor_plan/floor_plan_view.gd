class_name FloorPlanView
extends VBoxContainer
## The floor plan of a house installation (Schematic | Floor plan in the
## toolbar of a residential schematic): a bar with the tools above the list
## of parts not placed yet and the [FloorPlanCanvas]. In Edit mode rooms are
## drawn (Room, by dragging) or added ready-made (Add room), doors put in
## walls (Door), and a part chosen in the list is put where the plan is
## clicked next. Every change is emitted as one undoable edit of the document.

## A change of the plan: [param change] is called with the document.
signal edit_requested(change: Callable)
## Rocker [param rocker] of light switch [param designation] was clicked
## while simulating.
signal switch_toggled(designation: String, rocker: int)

var canvas: FloorPlanCanvas
var _document: SchematicDocument
var _editing: bool = false
var _fit_pending: bool = true
var _bar: HBoxContainer
var _select_button: Button
var _room_button: Button
var _door_button: Button
var _presets: MenuButton
var _delete_button: Button
var _fit_button: Button
var _side: VBoxContainer
var _list_title: Label
var _list: ItemList
var _list_hint: Label
## Designations in the list, by item index.
var _listed: PackedStringArray = PackedStringArray()
var _rename_dialog: ConfirmationDialog
var _rename_field: LineEdit
var _renaming: int = -1


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var bar: PanelContainer = PanelContainer.new()
	bar.theme_type_variation = "PageBar"
	add_child(bar)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 4)
	_bar.custom_minimum_size.y = 30.0
	bar.add_child(_bar)
	var group: ButtonGroup = ButtonGroup.new()
	_select_button = _tool_button("select", FloorPlanCanvas.Tool.SELECT, group)
	_room_button = _tool_button("room", FloorPlanCanvas.Tool.ROOM, group)
	_door_button = _tool_button("door", FloorPlanCanvas.Tool.DOOR, group)
	_select_button.set_pressed_no_signal(true)
	_presets = MenuButton.new()
	_presets.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_presets.flat = false
	_presets.theme_type_variation = "ToolButton"
	_presets.get_popup().id_pressed.connect(_add_preset)
	_bar.add_child(_presets)
	_delete_button = Button.new()
	_delete_button.theme_type_variation = "ToolButton"
	_delete_button.focus_mode = Control.FOCUS_NONE
	_delete_button.icon = AppTheme.icon("delete")
	_delete_button.pressed.connect(func() -> void: canvas.delete_selected())
	_bar.add_child(_delete_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.add_child(spacer)
	_fit_button = Button.new()
	_fit_button.theme_type_variation = "ToolButton"
	_fit_button.focus_mode = Control.FOCUS_NONE
	_fit_button.pressed.connect(func() -> void: canvas.fit())
	_bar.add_child(_fit_button)

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	add_child(body)
	var side_panel: PanelContainer = PanelContainer.new()
	side_panel.theme_type_variation = "LeftPanel"
	side_panel.custom_minimum_size.x = 200.0
	body.add_child(side_panel)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 6)
	side_panel.add_child(_side)
	_list_title = Label.new()
	_list_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list_title.theme_type_variation = "HeaderLabel"
	_side.add_child(_list_title)
	_list = ItemList.new()
	_list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_listed)
	_side.add_child(_list)
	_list_hint = Label.new()
	_list_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list_hint.theme_type_variation = "MutedLabel"
	_list_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list_hint.custom_minimum_size.x = 180.0
	_side.add_child(_list_hint)

	canvas = FloorPlanCanvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.edit_requested.connect(func(change: Callable) -> void: edit_requested.emit(change))
	canvas.switch_toggled.connect(func(designation: String, rocker: int) -> void: switch_toggled.emit(designation, rocker))
	canvas.rename_requested.connect(_ask_rename)
	canvas.placed.connect(func() -> void:
		_select_button.button_pressed = true
		_list.deselect_all())
	canvas.resized.connect(func() -> void:
		if _fit_pending and canvas.size.x > 10.0 and _document != null:
			_fit_pending = false
			canvas.fit())
	body.add_child(canvas)

	_rename_dialog = ConfirmationDialog.new()
	_rename_field = LineEdit.new()
	_rename_field.custom_minimum_size = Vector2(260, 0)
	_rename_dialog.add_child(_rename_field)
	_rename_dialog.register_text_enter(_rename_field)
	_rename_dialog.confirmed.connect(_apply_rename)
	add_child(_rename_dialog)
	retranslate()


func _tool_button(icon_name: String, tool: FloorPlanCanvas.Tool, group: ButtonGroup) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.theme_type_variation = "ToolButton"
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.button_group = group
	button.icon = AppTheme.icon(icon_name)
	button.toggled.connect(func(on: bool) -> void:
		if on:
			canvas.tool = tool
			if tool != FloorPlanCanvas.Tool.PLACE:
				canvas.placing = ""
				_list.deselect_all())
	_bar.add_child(button)
	return button


## Shows the plan of [param doc]; [param editing] lets it be changed,
## otherwise its switches operate the simulation. [param fit] shows all of
## it again (a new schematic).
func set_document(doc: SchematicDocument, editing: bool, fit: bool = false) -> void:
	_document = doc
	_editing = editing
	canvas.document = doc
	canvas.editing = editing
	if not editing:
		canvas.tool = FloorPlanCanvas.Tool.SELECT
		canvas.placing = ""
		_select_button.set_pressed_no_signal(true)
	if fit:
		canvas.selected = {}
		if canvas.size.x > 10.0:
			canvas.fit()
		else:
			_fit_pending = true
	refresh()


## Follows an edit of the document.
func refresh() -> void:
	if _document == null:
		return
	for button: Control in [_select_button, _room_button, _door_button, _presets, _delete_button]:
		button.visible = _editing
	(_side.get_parent() as Control).visible = _editing
	_listed = _document.floor_plan.unplaced(_document.circuit)
	_list.clear()
	for designation: String in _listed:
		_list.add_item(_entry_text(designation))
	_list_hint.text = tr("Pick a part, then click where it goes: switches, sockets and appliances go onto the nearest wall, luminaires on the ceiling.") if not _listed.is_empty() else tr("Every part is on the plan.")
	canvas.queue_redraw()


## The simulation stepped: lights, sockets and appliances are drawn anew.
func show_step(_result: StepResult) -> void:
	canvas.queue_redraw()


func retranslate() -> void:
	_select_button.tooltip_text = tr("Select and move rooms, doors and parts; drag a room's edge to resize it")
	_room_button.tooltip_text = tr("Draw a room by dragging; it snaps to the walls of the others")
	_door_button.tooltip_text = tr("Put a door in a wall by clicking it")
	_presets.text = tr("Add room")
	var popup: PopupMenu = _presets.get_popup()
	popup.clear()
	for i: int in FloorPlan.PRESETS.size():
		var preset: Dictionary = FloorPlan.PRESETS[i]
		var size: Vector2 = preset["size"]
		popup.add_item("%s  %s × %s m" % [tr(preset["name"]), String.num(size.x, 2), String.num(size.y, 2)], i)
	_delete_button.tooltip_text = tr("Take the selected room, door or part away")
	_fit_button.text = tr("Show all")
	_list_title.text = tr("Not on the plan").to_upper()
	_rename_dialog.title = tr("Rename room")
	_rename_dialog.ok_button_text = tr("Rename")
	_rename_dialog.cancel_button_text = tr("Cancel")
	if _document != null:
		refresh()


func _entry_text(designation: String) -> String:
	if designation == FloorPlan.UNIT:
		return tr("Consumer unit %s") % FloorPlan.UNIT
	var c: CircuitComponent = _document.circuit.get_component(designation)
	var what: String = ""
	if c is LightSwitch:
		what = tr("Switch no. %s") % (c as LightSwitch).circuit
	elif c is SocketOutlet:
		what = tr("Socket outlet")
	elif c is Luminaire:
		what = tr("Luminaire")
	elif c is Appliance:
		what = ApplianceSymbol.kind_title((c as Appliance).kind)
	return "-%s  %s" % [designation, what]


func _on_listed(index: int) -> void:
	if index < 0 or index >= _listed.size():
		return
	canvas.placing = _listed[index]
	canvas.tool = FloorPlanCanvas.Tool.PLACE
	_select_button.set_pressed_no_signal(false)
	_room_button.set_pressed_no_signal(false)
	_door_button.set_pressed_no_signal(false)
	canvas.grab_focus()


func _add_preset(index: int) -> void:
	var preset: Dictionary = FloorPlan.PRESETS[index]
	var room_name: String = preset["name"]
	var rect: Rect2 = _document.floor_plan.free_spot(preset["size"])
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.rooms.append(FloorPlan.Room.new(room_name, rect)))
	canvas.queue_redraw()


func _ask_rename(index: int) -> void:
	_renaming = index
	_rename_field.text = tr(_document.floor_plan.rooms[index].name)
	_rename_dialog.reset_size()
	_rename_dialog.popup_centered()
	_rename_field.select_all()
	_rename_field.grab_focus()


func _apply_rename() -> void:
	var index: int = _renaming
	var room_name: String = _rename_field.text.strip_edges()
	if index < 0 or index >= _document.floor_plan.rooms.size() or room_name.is_empty():
		return
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.rooms[index].name = room_name)
