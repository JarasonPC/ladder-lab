class_name FloorPlanView
extends VBoxContainer
## The floor plan of a house installation (Schematic | Floor plan in the
## toolbar of a residential schematic): a bar with the tools above the list
## of parts not placed yet and the [FloorPlanCanvas]. In Edit mode rooms are
## drawn (Room, by dragging) or added ready-made (Add room), doors put in
## walls (Door), and a part chosen in the list is put where the plan is
## clicked next. A residential installation also draws its lighting (Wire),
## takes new parts from the palette ([method begin_place_template]) onto
## the circuit chosen beside the plan (where a selected part's circuit is
## changed too), and gives each room its number, environment and
## illuminance. Every change is emitted as one undoable edit of the document.

## A change of the plan: [param change] is called with the document.
signal edit_requested(change: Callable)
## Rocker [param rocker] of light switch [param designation] was clicked
## while simulating.
signal switch_toggled(designation: String, rocker: int)
## A change of the consumer unit's rails (see [CabinetPanel]).
signal cabinet_edit_requested(change: Callable)
## Device [param designation] of the consumer unit was operated while
## simulating (a breaker switched, a fuse replaced).
signal operate_requested(designation: String)

var canvas: FloorPlanCanvas
var _document: SchematicDocument
var _editing: bool = false
var _fit_pending: bool = true
var _bar: HBoxContainer
var _select_button: Button
var _room_button: Button
var _door_button: Button
var _wire_button: Button
var _circuit_title: Label
var _circuit: OptionButton
## Circuits offered (their devices), by item index of [member _circuit] (the first: none).
var _circuits: PackedStringArray = PackedStringArray()
## The circuit for new parts was chosen (else the first is taken).
var _circuit_picked: bool = false
var _room_fields: GridContainer
var _number_field: LineEdit
var _environment_field: OptionButton
var _lux_field: LineEdit
var _presets: MenuButton
var _delete_button: Button
var _fit_button: Button
var _side: VBoxContainer
var _list_title: Label
var _list: ItemList
var _list_hint: Label
## Designations in the list, by item index.
var _listed: PackedStringArray = PackedStringArray()
## The consumer unit opened in place of the plan, null while the plan shows.
var _unit: CabinetPanel
var _back_button: Button
var _body: HBoxContainer
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
	_back_button = Button.new()
	_back_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_back_button.theme_type_variation = "ToolButton"
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.icon = AppTheme.icon("chevron_left")
	_back_button.visible = false
	_back_button.pressed.connect(close_unit)
	_bar.add_child(_back_button)
	_select_button = _tool_button("select", FloorPlanCanvas.Tool.SELECT, group)
	_room_button = _tool_button("room", FloorPlanCanvas.Tool.ROOM, group)
	_door_button = _tool_button("door", FloorPlanCanvas.Tool.DOOR, group)
	_wire_button = _tool_button("wire", FloorPlanCanvas.Tool.WIRE, group)
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
	_body = body
	var side_panel: PanelContainer = PanelContainer.new()
	side_panel.theme_type_variation = "LeftPanel"
	side_panel.custom_minimum_size.x = 200.0
	body.add_child(side_panel)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 6)
	side_panel.add_child(_side)
	_circuit_title = Label.new()
	_circuit_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_circuit_title.theme_type_variation = "HeaderLabel"
	_side.add_child(_circuit_title)
	_circuit = OptionButton.new()
	_circuit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_circuit.item_selected.connect(_on_circuit_chosen)
	_side.add_child(_circuit)
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
	canvas.unit_requested.connect(open_unit)
	canvas.placed.connect(func() -> void:
		_select_button.button_pressed = true
		_list.deselect_all())
	canvas.selection_changed.connect(_fill_circuits)
	canvas.resized.connect(func() -> void:
		if _fit_pending and canvas.size.x > 10.0 and _document != null:
			_fit_pending = false
			canvas.fit())
	body.add_child(canvas)

	_rename_dialog = ConfirmationDialog.new()
	var dialog_column: VBoxContainer = VBoxContainer.new()
	_rename_dialog.add_child(dialog_column)
	_rename_field = LineEdit.new()
	_rename_field.custom_minimum_size = Vector2(260, 0)
	dialog_column.add_child(_rename_field)
	_rename_dialog.register_text_enter(_rename_field)
	# A residential installation's room: its number, environment, illuminance.
	_room_fields = GridContainer.new()
	_room_fields.columns = 2
	dialog_column.add_child(_room_fields)
	_number_field = LineEdit.new()
	_environment_field = OptionButton.new()
	_environment_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for environment: String in FloorPlan.ENVIRONMENTS:
		_environment_field.add_item(environment)
	_lux_field = LineEdit.new()
	for field: Control in [_number_field, _environment_field, _lux_field]:
		var label: Label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_room_fields.add_child(label)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_room_fields.add_child(field)
		if field is LineEdit:
			_rename_dialog.register_text_enter(field as LineEdit)
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
				canvas.placing_template = {}
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
	if _unit != null:
		if _board_index(FloorPlan.UNIT.trim_prefix("+")) < 0:
			close_unit()
		else:
			_unit.set_document(doc, editing)
	if not editing:
		canvas.tool = FloorPlanCanvas.Tool.SELECT
		canvas.placing = ""
		canvas.placing_template = {}
		_select_button.set_pressed_no_signal(true)
	if fit:
		canvas.selected = {}
		if canvas.size.x > 10.0:
			canvas.fit()
		else:
			_fit_pending = true
	refresh()


## Opens the consumer unit (switchboard "RD1") in place of the plan, made
## first in Edit mode when there is none.
func open_unit() -> void:
	if _document == null:
		return
	var unit_name: String = FloorPlan.UNIT.trim_prefix("+")
	if _board_index(unit_name) < 0:
		if not _editing:
			return
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.ensure_consumer_unit())
	if _unit == null:
		_unit = CabinetPanel.new()
		_unit.board_name = unit_name
		_unit.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_unit.edit_requested.connect(func(change: Callable) -> void: cabinet_edit_requested.emit(change))
		_unit.door_edit_requested.connect(func(change: Callable) -> void: edit_requested.emit(change))
		_unit.operate_requested.connect(func(designation: String) -> void: operate_requested.emit(designation))
		add_child(_unit)
		_unit.set_document(_document, _editing)
	_body.visible = false
	refresh()


## Back from the consumer unit to the plan.
func close_unit() -> void:
	if _unit != null:
		_unit.queue_free()
		_unit = null
	_body.visible = true
	refresh()


func _board_index(board_name: String) -> int:
	for i: int in _document.switchboards.size():
		if _document.switchboards[i].name == board_name:
			return i
	return -1


## Follows an edit of the document.
func refresh() -> void:
	if _document == null:
		return
	var plan_shown: bool = _unit == null
	if _unit != null:
		_unit.refresh()
	_back_button.visible = not plan_shown
	_back_button.text = tr("Floor plan") if not plan_shown else ""
	for button: Control in [_select_button, _room_button, _door_button, _presets, _delete_button]:
		button.visible = _editing and plan_shown
	_wire_button.visible = _editing and plan_shown and canvas.installation()
	_fill_circuits()
	_fit_button.visible = plan_shown
	(_side.get_parent() as Control).visible = _editing
	_listed = _document.floor_plan.unplaced(_document.circuit)
	_list.clear()
	for designation: String in _listed:
		_list.add_item(_entry_text(designation))
	_list_hint.text = tr("Pick a part, then click where it goes: switches, sockets and appliances go onto the nearest wall, luminaires on the ceiling.") if not _listed.is_empty() else tr("Every part is on the plan.")
	canvas.queue_redraw()


## The simulation stepped: lights, sockets and appliances are drawn anew.
func show_step(result: StepResult) -> void:
	canvas.queue_redraw()
	if _unit != null:
		_unit.show_step(result)


func retranslate() -> void:
	_select_button.tooltip_text = tr("Select and move rooms, doors and parts; drag a room's edge to resize it")
	_room_button.tooltip_text = tr("Draw a room by dragging; it snaps to the walls of the others")
	_door_button.tooltip_text = tr("Put a door in a wall by clicking it")
	_wire_button.tooltip_text = tr("Draw the lighting: drag from a light switch (of two rockers, from the side of the one) to a luminaire it switches, or to the other switch of a staircase; it is wired by itself")
	var labels: Array[String] = [tr("Number"), tr("Environment (ČSN 33 2000-5-51)"), tr("Illuminance (lx)")]
	for k: int in labels.size():
		(_room_fields.get_child(2 * k) as Label).text = labels[k]
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
	_rename_dialog.title = tr("Room")
	_rename_dialog.ok_button_text = tr("OK")
	_rename_dialog.cancel_button_text = tr("Cancel")
	if _document != null:
		refresh()


## Puts a new part made from the palette's [param template] where the plan
## is clicked next (on the circuit chosen), again until a right click.
func begin_place_template(template: Dictionary) -> void:
	canvas.placing = ""
	canvas.placing_template = template
	canvas.tool = FloorPlanCanvas.Tool.PLACE
	for button: Button in [_select_button, _room_button, _door_button, _wire_button]:
		button.set_pressed_no_signal(false)
	_list.deselect_all()
	canvas.grab_focus()


## The circuit picker of a residential installation: the circuit of the
## selected part (changed there), or the one new parts go on.
func _fill_circuits() -> void:
	if _document == null or _circuit == null:
		return
	var shown: bool = canvas.installation()
	_circuit_title.visible = shown
	_circuit.visible = shown
	if not shown:
		return
	var line: SingleLine = _document.single_line
	var part: String = canvas.selected.get("designation", "") if canvas.selected.get("kind", "") == "part" else ""
	if part == FloorPlan.UNIT:
		part = ""
	_circuit_title.text = (tr("Circuit of -%s") % part if not part.is_empty() else tr("Circuit for new parts")).to_upper()
	_circuits = PackedStringArray([""])
	_circuit.clear()
	_circuit.add_item(tr("No circuit"))
	for f: SingleLine.Feeder in line.feeders():
		_circuits.append(f.device)
		var where: String = f.destination
		if where.is_empty():
			var end: CircuitComponent = SingleLine.end_part(f, _document.circuit)
			where = ""
			if end is SocketOutlet:
				where = tr("Sockets")
			elif end is Luminaire:
				where = tr("Lighting")
			elif end is Appliance:
				where = ApplianceSymbol.kind_title((end as Appliance).kind)
		_circuit.add_item(("-%s  %s" % [f.device, where]).strip_edges())
	var current: String = canvas.circuit
	if not part.is_empty():
		var fed: SingleLine.Feeder = line.feeder_feeding(part)
		current = fed.device if fed != null else ""
	elif (current.is_empty() and not _circuit_picked) or not _circuits.has(current):
		current = _circuits[1] if _circuits.size() > 1 else ""
		canvas.circuit = current
	_circuit.select(maxi(_circuits.find(current), 0))


func _on_circuit_chosen(index: int) -> void:
	var device: String = _circuits[index] if index < _circuits.size() else ""
	var part: String = canvas.selected.get("designation", "") if canvas.selected.get("kind", "") == "part" else ""
	if part.is_empty() or part == FloorPlan.UNIT:
		canvas.circuit = device
		_circuit_picked = true
		return
	# The selected part moves to the circuit chosen.
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		var old: SingleLine.Feeder = doc.single_line.feeder_feeding(part)
		if old != null:
			old.loads.remove_at(old.loads.find(part))
		var f: SingleLine.Feeder = doc.single_line.feeder_of(device)
		if f != null:
			f.loads.append(part))


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
	_room_fields.visible = canvas.installation()
	var plan: FloorPlan = _document.floor_plan
	_number_field.text = plan.rooms[index].number
	_number_field.placeholder_text = str(FloorPlan.FIRST_NUMBER + index)
	_environment_field.select(maxi(FloorPlan.ENVIRONMENTS.find(plan.room_environment(index)), 0))
	_lux_field.text = plan.rooms[index].lux
	_lux_field.placeholder_text = plan.room_lux(index)
	_rename_dialog.reset_size()
	_rename_dialog.popup_centered()
	_rename_field.select_all()
	_rename_field.grab_focus()


func _apply_rename() -> void:
	var index: int = _renaming
	var room_name: String = _rename_field.text.strip_edges()
	if index < 0 or index >= _document.floor_plan.rooms.size() or room_name.is_empty():
		return
	var number: String = _number_field.text.strip_edges()
	var environment: String = FloorPlan.ENVIRONMENTS[maxi(_environment_field.selected, 0)]
	var lux: String = _lux_field.text.strip_edges()
	var details: bool = _room_fields.visible
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		var room: FloorPlan.Room = doc.floor_plan.rooms[index]
		room.name = room_name
		if details:
			room.number = number
			room.lux = lux
			# The usual one for the room is kept as none set.
			room.environment = ""
			if environment != doc.floor_plan.room_environment(index):
				room.environment = environment)
