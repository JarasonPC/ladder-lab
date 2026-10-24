class_name SingleLineView
extends VBoxContainer
## The single-line diagram of a residential installation's consumer unit
## (the Schematic area of a residential schematic): a bar with Delete and
## Fit over the [SingleLineCanvas] and, in Edit mode, a panel beside it with
## what the diagram keeps of the selected circuit (the circuit its device
## protects, chosen from those waiting for protection, its phase, where it
## goes, the room, its cable, ripple control) or, with nothing selected, of
## the supply (its cable, the SPD) and the circuits made on the floor plan
## that nothing protects yet. Every change is emitted as one undoable edit
## of the document.

## A change of the diagram: [param change] is called with the document.
signal edit_requested(change: Callable)
## Device or part [param designation] was selected ("" for none).
signal selection_changed(designation: String)
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
## The circuit the selected device protects: its own, a waiting one, or a new one.
var _number_label: Label
var _number: OptionButton
## Circuit numbers offered, by item index of [member _number] (0: a new one).
var _numbers: PackedInt32Array = PackedInt32Array()
## The circuits waiting for their protection.
var _waiting_label: Label
var _waiting: Label
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
## A circuit's cable length from the plan, its voltage drop and loop impedance.
var _checks: Label
## The supply's loop impedance at the consumer unit.
var _ze_label: Label
var _ze: SpinBox
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
	_number_label = _label(fields)
	_number = OptionButton.new()
	_number.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_number.item_selected.connect(func(index: int) -> void:
		var f: SingleLine.Feeder = _feeder()
		if f == null or index >= _numbers.size():
			return
		var device: String = f.device
		var number: int = _numbers[index]
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.single_line.assign(doc, device, number)))
	fields.add_child(_number)
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
	_ze_label = _label(fields)
	_ze = SpinBox.new()
	_ze.min_value = 0.01
	_ze.max_value = 10.0
	_ze.step = 0.01
	_ze.suffix = "Ω"
	_ze.value_changed.connect(func(value: float) -> void:
		if _document != null and not is_equal_approx(value, _document.single_line.supply_impedance):
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.single_line.supply_impedance = value))
	fields.add_child(_ze)
	_waiting_label = _label(fields, "HeaderLabel")
	_waiting = _label(fields)
	_waiting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_waiting.custom_minimum_size.x = 200.0
	_checks = _label(fields)
	_checks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_checks.custom_minimum_size.x = 200.0
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
## otherwise it is only shown. [param fit] shows all of it again.
func set_document(doc: SchematicDocument, editing: bool, fit: bool = false) -> void:
	_document = doc
	_editing = editing
	canvas.document = doc
	canvas.editing = editing
	if not editing:
		canvas.end_place()
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
	_ze_label.visible = _spd.visible
	_ze.visible = _spd.visible
	_ze.set_value_no_signal(line.supply_impedance)
	_checks.visible = feeder_shown
	if feeder_shown:
		var check: Dictionary = SingleLineView.checks(line, f, _document)
		_checks.text = check["text"]
		_checks.add_theme_color_override("font_color", SchematicTheme.WARNING if check["bad"] else SchematicTheme.TEXT)
	_phase_label.visible = feeder_shown or group != null
	_phase.visible = _phase_label.visible
	_number_label.visible = feeder_shown
	_number.visible = feeder_shown
	var waiting: Array[SingleLine.Feeder] = line.waiting.duplicate()
	waiting.sort_custom(func(a: SingleLine.Feeder, b: SingleLine.Feeder) -> bool: return a.number < b.number)
	_waiting_label.visible = not feeder_shown and group == null
	_waiting.visible = _waiting_label.visible
	var listed: PackedStringArray = PackedStringArray()
	for w: SingleLine.Feeder in waiting:
		listed.append(SingleLineView.circuit_text(w, _document))
	_waiting.text = "\n".join(listed) if not listed.is_empty() else tr("None: every circuit of the floor plan is protected.")
	_shown = f.device if feeder_shown else group.device if group != null else ""
	if feeder_shown:
		_title.text = tr("Circuit %d (%s)") % [f.number, "-" + f.device]
		_numbers = PackedInt32Array([f.number])
		_number.clear()
		_number.add_item(SingleLineView.circuit_text(f, _document))
		for w: SingleLine.Feeder in waiting:
			_numbers.append(w.number)
			_number.add_item(SingleLineView.circuit_text(w, _document))
		if not f.loads.is_empty():
			_numbers.append(0)
			_number.add_item(tr("A new circuit (spare), this one waiting"))
		_number.select(0)
		_number.disabled = _numbers.size() < 2
		_destination.text = f.destination
		_destination.placeholder_text = tr("Where it goes, e.g. Kitchen sockets")
		_cable.text = f.cable
		_cable.placeholder_text = SingleLine.cable_text(SingleLine.Feeder.new(f.device), _document.circuit)
		_rooms = PackedStringArray([""])
		_room.clear()
		_room.add_item(tr("No room"))
		for plan: FloorPlan in _document.floors:
			for room: FloorPlan.Room in plan.rooms:
				if _rooms.has(room.name):
					continue
				_rooms.append(room.name)
				_room.add_item(tr(room.name) if _document.floors.size() == 1 else "%s  %s" % [plan.floor_name(), tr(room.name)])
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
	_hint.text = tr("Pick a breaker or an RCD in the palette and click between the circuits; under a group's busbar, or below the breaker of a circuit feeding nothing, to put it under that device (a 30 mA RCD under a selective 300 mA one, breakers under a breaker); a socket, luminaire or appliance onto a circuit. A breaker, RCBO or AFDD put in protects the first circuit of the floor plan waiting for one; choose another in its Circuit. Its poles, characteristic and rating are set in its properties. Drag a breaker or RCD to move it. Shift+click or a box drawn from an empty place selects several, to drag or delete together.")


## Circuit [param f] as listed: its number, where it goes (else the kind
## of its first part, "Spare") and how many parts it feeds.
static func circuit_text(f: SingleLine.Feeder, doc: SchematicDocument) -> String:
	var where: String = f.destination
	var parts: int = 0
	for designation: String in f.loads:
		var c: CircuitComponent = doc.circuit.get_component(designation)
		if c == null or c is LightSwitch:
			continue
		parts += 1
		if where.is_empty():
			if c is SocketOutlet:
				where = TranslationServer.translate("Sockets")
			elif c is Luminaire:
				where = TranslationServer.translate("Lighting")
			elif c is Appliance:
				where = ApplianceSymbol.title_of(c as Appliance)
	if where.is_empty():
		where = TranslationServer.translate("Spare")
	if parts == 0:
		return "%d  %s" % [f.number, where]
	return "%d  %s (%s)" % [f.number, where, TranslationServer.translate_plural("%d part", "%d parts", parts) % parts]


## What the plan says of circuit [param f] of [param line]: {"text": its
## cable length, voltage drop and loop impedance as lines, "bad": one of
## them out of bounds, "length", "drop" (-1 when not known)}.
static func checks(line: SingleLine, f: SingleLine.Feeder, doc: SchematicDocument) -> Dictionary:
	var length: float = line.cable_length(f, doc)
	if length < 0.0:
		return {"text": TranslationServer.translate("Put the consumer unit and the circuit's parts on the floor plan to work out its cable's length and voltage drop."), "bad": false, "length": -1.0, "drop": -1.0}
	var drop: float = line.voltage_drop(f, doc, length)
	var limit: float = line.drop_limit(f, doc.circuit)
	var z: float = line.loop_impedance(f, doc, length)
	var trips: bool = line.disconnects_in_time(f, doc, length)
	var lines: PackedStringArray = PackedStringArray()
	lines.append(TranslationServer.translate("Cable about %s m (from the plan, with 10 %% reserve)") % roundi(length))
	if drop >= 0.0:
		lines.append(TranslationServer.translate("Voltage drop %s %% at In (at most %s %%)") % [SingleLineCanvas._decimal(String.num(drop, 1)), SingleLineCanvas._decimal(String.num(limit, 0))])
	if z >= 0.0:
		lines.append((TranslationServer.translate("Loop impedance %s Ω: trips at once on a fault") if trips else TranslationServer.translate("Loop impedance %s Ω: too high to trip at once on a fault")) % SingleLineCanvas._decimal(String.num(z, 2)))
	return {"text": "\n".join(lines), "bad": drop > limit or (z >= 0.0 and not trips), "length": length, "drop": drop}


func retranslate() -> void:
	_delete_button.tooltip_text = tr("Delete the selected breaker, RCD or part (Delete)")
	_fit_button.text = tr("Show all")
	_phase_label.text = tr("Phase")
	_number_label.text = tr("Circuit")
	_waiting_label.text = tr("Circuits waiting for protection").to_upper()
	_destination_label.text = tr("Destination")
	_room_label.text = tr("Room on the floor plan")
	_cable_label.text = tr("Cable")
	_hdo.text = tr("Switched by ripple control (HDO)")
	_spd.text = tr("Surge protective device (SPD)")
	_ze_label.text = tr("Loop impedance of the supply Ze")
	_fill()
