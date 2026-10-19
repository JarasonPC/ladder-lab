class_name PartsList
extends RefCounted
## The parts list of a schematic for the export: every device by where it
## sits (each switchboard with its terminal strips, each control station,
## each group, the other parts in the field, what has no place yet), then the
## cables of the workspace. Made with new() (its texts are translated). No
## nodes.

## Rows of the list: {"heading": true, "text"} starts a place, the others are
## {"designation" ("-KM1", "W1"), "name" ("Contactor"), "data" (ratings,
## e.g. "230 V AC", "C16, 3 poles", "CGSG-J 4x2,5  +RA1 – -M1")}. The
## texts are translated.
func rows(doc: SchematicDocument) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var under: Dictionary[String, String] = CabinetDevices.overloads_under_contactors(doc.circuit)
	var strips: Dictionary = CabinetDevices.strips(doc)
	for board: Switchboard in doc.switchboards:
		var part: Array[Dictionary] = []
		for rail: CabinetRail in board.rails:
			for item: CabinetItem in rail.items:
				if item.kind == CabinetItem.Kind.STRIP:
					part.append(_strip(item.designation, strips))
					continue
				part.append(_device(doc, item.designation))
				# An overload relay fitted under its contactor.
				if under.has(item.designation):
					part.append(_device(doc, under[item.designation]))
		_add(result, "+%s  %s" % [board.name, board.title if not board.title.is_empty() else tr("Switchboard")], part)
	for box: ControlBox in doc.control_boxes:
		var part: Array[Dictionary] = []
		for item: ControlBoxItem in box.items:
			if not item.designation.is_empty():
				part.append(_control(doc, item))
			if not item.lamp.is_empty() and item.lamp != item.designation:
				part.append(_device(doc, item.lamp))
		_add(result, "+%s  %s" % [box.name, box.title if not box.title.is_empty() else tr("Control station")], part)
	for group: WorkspaceGroup in doc.groups:
		var part: Array[Dictionary] = []
		for member: String in group.members:
			if Workspace.field_component(doc.circuit, member) != null:
				part.append(_device(doc, member))
		_add(result, "+%s  %s" % [group.name, group.title if not group.title.is_empty() else tr("Group")], part)
	var loose: Array[Dictionary] = []
	for designation: String in Workspace.field_devices(doc.circuit):
		if Workspace.group_of(doc, designation) < 0:
			loose.append(_device(doc, designation))
	_add(result, tr("In the field"), loose)
	var missing: Array[Dictionary] = []
	for entry: Dictionary in Workspace.unplaced(doc):
		missing.append(_strip(entry["designation"], strips) if entry["kind"] == "strip" else _device(doc, entry["designation"]))
	_add(result, tr("Not placed"), missing)
	var cables: Array[Dictionary] = []
	for cable: Dictionary in WorkspaceCables.cables(doc):
		cables.append({"designation": cable["name"], "name": tr("Cable"), "data": "%s   %s – %s" % [WorkspaceCables.type_and_length(cable), cable["a"], cable["b"]]})
	_add(result, tr("Cables"), cables)
	return result


func _add(result: Array[Dictionary], heading: String, part: Array[Dictionary]) -> void:
	if part.is_empty():
		return
	result.append({"heading": true, "text": heading})
	result.append_array(part)


func _strip(strip: String, strips: Dictionary) -> Dictionary:
	var count: int = (strips.get(strip, []) as Array).size()
	return {"designation": "-" + strip, "name": tr("Terminal strip"), "data": tr_n("%d terminal", "%d terminals", count) % count}


## A push button, switch or lamp of a station: its plate text and colour.
func _control(doc: SchematicDocument, item: ControlBoxItem) -> Dictionary:
	var row: Dictionary = _device(doc, item.designation)
	var facts: PackedStringArray = PackedStringArray()
	var colour: int = ControlBoxItem.COLORS.find(item.color)
	if colour >= 0:
		facts.append(tr(ControlBoxItem.COLOR_TITLES[colour]))
	if not item.label.is_empty():
		facts.append("„%s“" % item.label)
	if not str(row["data"]).is_empty():
		facts.append(row["data"])
	row["data"] = ", ".join(facts)
	return row


func _device(doc: SchematicDocument, designation: String) -> Dictionary:
	return {"designation": "-" + designation, "name": name_of(doc, designation), "data": data_of(doc, designation)}


## The part that stands for device [param designation]: the device in the
## switchboard, the button or switch operated, the part in the field, else
## its first part; null when the schematic has none.
static func main_part(doc: SchematicDocument, designation: String) -> CircuitComponent:
	for found: CircuitComponent in [CabinetDevices.device(doc.circuit, designation), doc.circuit.get_operator(designation), Workspace.field_component(doc.circuit, designation)]:
		if found != null:
			return found
	return doc.circuit.get_component(designation)


## What device [param designation] is: as the switchboard, station or
## workspace calls it, else the title of its datasheet.
func name_of(doc: SchematicDocument, designation: String) -> String:
	var part: CircuitComponent = main_part(doc, designation)
	if part == null:
		return tr("not in the schematic")
	var cabinet: CabinetDevices.Kind = CabinetDevices.kind_of(part)
	if cabinet != CabinetDevices.Kind.NONE:
		return tr(CabinetPanel.KIND_TITLES[cabinet])
	var control: int = ControlBoxItem.kind_of(part)
	if control >= 0:
		return tr(StationPanel.KIND_TITLES[control])
	var field: Workspace.Field = Workspace.field_kind(part)
	if field != Workspace.Field.NONE:
		return tr(WorkspaceCanvas.field_title(WorkspaceTile.of_field(field)))
	return Datasheet.of(part, doc).title


## Ratings of device [param designation] (all its parts), e.g. "230 V AC",
## "Circuit breaker C16, 3 poles", "4 kW, 8.2 A".
func data_of(doc: SchematicDocument, designation: String) -> String:
	var facts: PackedStringArray = PackedStringArray()
	for c: CircuitComponent in doc.circuit.get_components():
		if c.designation != designation:
			continue
		var fact: String = ""
		if c is ProtectiveDevice or c is MotorBreaker or c is ThreePoleFuse:
			fact = Datasheet.of(c, doc).summary
		elif c is MainContacts and (c as MainContacts).poles > 1:
			fact = tr("%d poles") % (c as MainContacts).poles
		elif c is OverloadRelay:
			fact = "Ir %s A" % _num((c as OverloadRelay).setting)
		elif c is ThreePhaseMotor:
			var motor: ThreePhaseMotor = c as ThreePhaseMotor
			fact = "%s kW, %s A" % [_num(motor.rated_power), _num(motor.rated_current)]
		elif c is TemperatureSensor:
			var sensor: TemperatureSensor = c as TemperatureSensor
			fact = "%s…%s °C, 0-10 V" % [_num(sensor.range_min), _num(sensor.range_max)]
		elif c.get("rating") is String:
			fact = VoltageRating.text(c.get("rating"))
		if not fact.is_empty() and not facts.has(fact):
			facts.append(fact)
	return ", ".join(facts)


func _num(value: float) -> String:
	return str(snappedf(value, 0.01)).trim_suffix(".0")
