class_name SingleLineView
extends VBoxContainer
## The single-line diagram of a residential installation's consumer unit
## (the Schematic area of a residential schematic): a bar with Delete and
## Fit over the [SingleLineCanvas] and, in Edit mode, a panel beside it with
## what the diagram keeps of the selected circuit (its phase, where it goes,
## the room, its cable, ripple control) or, with nothing selected, of the
## supply (its cable, the SPD). Every change is emitted as one undoable edit
## of the document.

## A change of the diagram: [param change] is called with the document.
signal edit_requested(change: Callable)
## Device or part [param designation] was selected ("" for none).
signal selection_changed(designation: String)
## A breaker or RCD was clicked while simulating.
signal operate_requested(designation: String)
## The main switch or the ripple control contact was clicked while simulating.
signal switch_toggled(designation: String, steps: int)
## A test button was clicked while simulating.
signal test_requested(designation: String)
## A circuit's room link was clicked.
signal room_requested(room: String)

var canvas: SingleLineCanvas
var _document: SchematicDocument
var _editing: bool = false
var _fit_pending: bool = true
var _delete_button: Button
var _fit_button: Button
var _side: PanelContainer
var _title: Label
var _phase_label: Label
var _phase: OptionButton
var _destination_label: Label
var _destination: LineEdit
var _room_label: Label
var _room: OptionButton
var _cable_label: Label
var _cable: LineEdit
var _hdo: CheckBox
var _spd: CheckBox
var _hint: Label
## What a circuit without a 30 mA RCD lacks.
var _warning: Label
## Rooms offered, by item index of [member _room] (the first: none).
var _rooms: PackedStringArray = PackedStringArray()
## Device of the circuit the panel shows ("" for the supply, a group's RCD
## for a group), so text typed goes to it even once another is selected.
var _shown: String = ""


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var bar_panel: PanelContainer = PanelContainer.new()
	bar_panel.theme_type_variation = "PageBar"
	add_child(bar_panel)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	bar.custom_minimum_size.y = 30.0
	bar_panel.add_child(bar)
	_delete_button = Button.new()
	_delete_button.theme_type_variation = "ToolButton"
	_delete_button.focus_mode = Control.FOCUS_NONE
	_delete_button.icon = AppTheme.icon("delete")
	_delete_button.pressed.connect(func() -> void: canvas.delete_selected())
	bar.add_child(_delete_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_fit_button = Button.new()
	_fit_button.theme_type_variation = "ToolButton"
	_fit_button.focus_mode = Control.FOCUS_NONE
	_fit_button.pressed.connect(func() -> void: canvas.fit())
	bar.add_child(_fit_button)

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	add_child(body)
	canvas = SingleLineCanvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.edit_requested.connect(func(change: Callable) -> void: edit_requested.emit(change))
	canvas.selection_changed.connect(func(designation: String) -> void:
		_fill()
		selection_changed.emit(designation))
	canvas.operate_requested.connect(func(designation: String) -> void: operate_requested.emit(designation))
	canvas.switch_toggled.connect(func(designation: String, steps: int) -> void: switch_toggled.emit(designation, steps))
	canvas.test_requested.connect(func(designation: String) -> void: test_requested.emit(designation))
	canvas.room_requested.connect(func(room: String) -> void: room_requested.emit(room))
	canvas.resized.connect(func() -> void:
		if _fit_pending and canvas.size.x > 10.0 and _document != null:
			_fit_pending = false
			canvas.fit())
	body.add_child(canvas)

	_side = PanelContainer.new()
	_side.theme_type_variation = "LeftPanel"
	_side.custom_minimum_size.x = 220.0
	body.add_child(_side)
	var fields: VBoxContainer = VBoxContainer.new()
	fields.add_theme_constant_override("separation", 6)
	_side.add_child(fields)
	_title = _label(fields, "HeaderLabel")
	_phase_label = _label(fields)
	_phase = OptionButton.new()
	_phase.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for ph: String in ["L1", "L2", "L3"]:
		_phase.add_item(ph)
	_phase.item_selected.connect(func(index: int) -> void:
		var designation: String = canvas.selected
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.single_line.set_phase(doc, designation, index + 1)))
	fields.add_child(_phase)
	_destination_label = _label(fields)
	_destination = LineEdit.new()
	_destination.text_submitted.connect(func(_text: String) -> void: _apply_text())
	_destination.focus_exited.connect(_apply_text)
	fields.add_child(_destination)
	_room_label = _label(fields)
	_room = OptionButton.new()
	_room.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_room.item_selected.connect(func(index: int) -> void:
		var room: String = _rooms[index] if index < _rooms.size() else ""
		_edit_feeder(func(f: SingleLine.Feeder) -> void: f.room = room))
	fields.add_child(_room)
	_cable_label = _label(fields)
	_cable = LineEdit.new()
	_cable.text_submitted.connect(func(_text: String) -> void: _apply_text())
	_cable.focus_exited.connect(_apply_text)
	fields.add_child(_cable)
	_hdo = CheckBox.new()
	_hdo.toggled.connect(func(on: bool) -> void: _edit_feeder(func(f: SingleLine.Feeder) -> void: f.hdo = on))
	fields.add_child(_hdo)
	_spd = CheckBox.new()
	_spd.toggled.connect(func(on: bool) -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.single_line.spd = on))
	fields.add_child(_spd)
	_warning = _label(fields)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.custom_minimum_size.x = 200.0
	_warning.add_theme_color_override("font_color", SchematicTheme.WARNING)
	_hint = _label(fields, "MutedLabel")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 200.0
	retranslate()


func _label(parent: Control, variation: String = "") -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if not variation.is_empty():
		label.theme_type_variation = variation
	parent.add_child(label)
	return label


## Shows the diagram of [param doc]; [param editing] lets it be changed,
## otherwise it operates the simulation. [param fit] shows all of it again.
func set_document(doc: SchematicDocument, editing: bool, fit: bool = false) -> void:
	_document = doc
	_editing = editing
	canvas.document = doc
	canvas.editing = editing
	if not editing:
		canvas.end_place()
		canvas.step = null
	if fit:
		_fit_pending = true
		if canvas.size.x > 10.0:
			_fit_pending = false
			canvas.fit()
	refresh()


## Follows an edit of the document.
func refresh() -> void:
	if _document == null:
		return
	if not canvas.selected.is_empty() and _document.circuit.get_component(canvas.selected) == null:
		canvas.show_selected("")
	_delete_button.visible = _editing
	_side.visible = _editing
	_fill()
	canvas.queue_redraw()


func show_step(result: StepResult) -> void:
	canvas.step = result if not _editing else null
	canvas.queue_redraw()


## Puts the palette's [param template] where the diagram is clicked next.
func begin_place(template: Dictionary) -> void:
	canvas.begin_place(template)
	canvas.grab_focus()


## The selected circuit (of the device selected, or of the part fed), or null.
func _feeder() -> SingleLine.Feeder:
	if _document == null or canvas.selected.is_empty():
		return null
	var f: SingleLine.Feeder = _document.single_line.feeder_of(canvas.selected)
	return f if f != null else _document.single_line.feeder_feeding(canvas.selected)


func _edit_feeder(change: Callable) -> void:
	var f: SingleLine.Feeder = _feeder()
	if f == null:
		return
	var device: String = f.device
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		var target: SingleLine.Feeder = doc.single_line.feeder_of(device)
		if target != null:
			change.call(target))


## Takes the destination and cable typed (each only when it changed) into
## what the panel shows.
func _apply_text() -> void:
	if _document == null:
		return
	var f: SingleLine.Feeder = _document.single_line.feeder_of(_shown) if not _shown.is_empty() else null
	if f == null and not _shown.is_empty():
		return
	if f == null:
		var cable: String = _cable.text.strip_edges()
		if cable != _document.single_line.supply_cable:
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.single_line.supply_cable = cable)
		return
	var destination: String = _destination.text.strip_edges()
	var cable: String = _cable.text.strip_edges()
	if destination != f.destination or cable != f.cable:
		var device: String = f.device
		edit_requested.emit(func(doc: SchematicDocument) -> void:
			var target: SingleLine.Feeder = doc.single_line.feeder_of(device)
			if target != null:
				target.destination = destination
				target.cable = cable)


## Fills the panel with the selection's circuit, group or the supply.
func _fill() -> void:
	if _document == null or _title == null:
		return
	var line: SingleLine = _document.single_line
	var f: SingleLine.Feeder = _feeder()
	var group: SingleLine.Group = line.group_of(canvas.selected) if not canvas.selected.is_empty() else null
	var feeder_shown: bool = f != null
	for c: Control in [_destination_label, _destination, _room_label, _room, _hdo]:
		c.visible = feeder_shown
	_cable_label.visible = feeder_shown or group == null
	_cable.visible = _cable_label.visible
	_spd.visible = not feeder_shown and group == null
	_phase_label.visible = feeder_shown or group != null
	_phase.visible = _phase_label.visible
	_shown = f.device if feeder_shown else group.device if group != null else ""
	if feeder_shown:
		_title.text = tr("Circuit %s") % ("-" + f.device)
		_destination.text = f.destination
		_destination.placeholder_text = tr("Where it goes, e.g. Kitchen sockets")
		_cable.text = f.cable
		_cable.placeholder_text = SingleLine.cable_text(SingleLine.Feeder.new(f.device), _document.circuit)
		_rooms = PackedStringArray([""])
		_room.clear()
		_room.add_item(tr("No room"))
		for room: FloorPlan.Room in _document.floor_plan.rooms:
			_rooms.append(room.name)
			_room.add_item(tr(room.name))
		_room.select(maxi(_rooms.find(f.room), 0))
		var holder: SingleLine.Group = line.group_holding(f)
		_hdo.set_pressed_no_signal(f.hdo)
		_hdo.disabled = holder != null
		var phases: PackedInt32Array = line.phases_of(f, _document.circuit)
		var rcd: ResidualCurrentDevice = _document.circuit.get_component(holder.device) as ResidualCurrentDevice if holder != null else null
		_phase.select(f.phase - 1)
		_phase.disabled = phases.size() > 1 or (rcd != null and rcd.poles == 2)
	elif group != null:
		_title.text = tr("Group %s") % ("-" + group.device)
		var rcd: ResidualCurrentDevice = _document.circuit.get_component(group.device) as ResidualCurrentDevice
		var holder: SingleLine.Group = line.group_holding(group)
		var holder_rcd: ResidualCurrentDevice = _document.circuit.get_component(holder.device) as ResidualCurrentDevice if holder != null else null
		_phase.select(group.phase - 1)
		_phase.disabled = rcd == null or rcd.poles != 2 or (holder_rcd != null and holder_rcd.poles == 2)
	else:
		_title.text = tr("Incoming supply")
		_cable.text = line.supply_cable
		_cable.placeholder_text = SingleLine.SUPPLY_CABLE
		_spd.set_pressed_no_signal(line.spd)
	_warning.visible = feeder_shown and line.lacks_rcd(f, _document.circuit)
	_warning.text = tr(SingleLineCanvas.NO_RCD_TEXT)
	_hint.text = tr("Pick a breaker or an RCD in the palette and click between the circuits; under a group's busbar, or below the breaker of a circuit feeding nothing, to put it under that device (a 30 mA RCD under a selective 300 mA one, breakers under a breaker); a socket, luminaire or appliance onto a circuit. Drag a breaker or RCD to move it. Shift+click or a box drawn from an empty place selects several, to drag or delete together.")


func retranslate() -> void:
	_delete_button.tooltip_text = tr("Delete the selected breaker, RCD or part (Delete)")
	_fit_button.text = tr("Show all")
	_phase_label.text = tr("Phase")
	_destination_label.text = tr("Destination")
	_room_label.text = tr("Room on the floor plan")
	_cable_label.text = tr("Cable")
	_hdo.text = tr("Switched by ripple control (HDO)")
	_spd.text = tr("Surge protective device (SPD)")
	_fill()
