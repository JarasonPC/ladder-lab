class_name PartsList
extends RefCounted
## The parts list of a schematic for the export: every device by where it
## sits (each switchboard with its terminal strips, each control station,
## each group, the other parts in the field, what has no place yet), then the
## cables of the workspace. Within a place, identical parts (same name and
## data) are one row with their count; each switchboard and station lists
## the cable glands of the cables coming in. Made with new() (its texts are
## translated). No nodes.

## Rows of the list: {"heading": true, "text"} starts a place, the others are
## {"designation" ("-KM1", "-KM1…-KM3", "W1"), "quantity", "name"
## ("Contactor"), "data" (ratings, e.g. "230 V AC", "C16, 3 poles",
## "CGSG-J 4x2,5  +RA1 – -M1", "1 NO + 1 NC")}. The texts are translated.
func rows(doc: SchematicDocument) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var under: Dictionary[String, String] = CabinetDevices.overloads_under_contactors(doc.circuit)
	var strips: Dictionary = CabinetDevices.strips(doc)
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	for board: Switchboard in doc.switchboards:
		var part: Array[Dictionary] = []
		for rail: CabinetRail in board.rails:
			for item: CabinetItem in rail.items:
				if item.kind == CabinetItem.Kind.STRIP:
					part.append(_strip(item.designation, strips))
					part.append_array(_bridges(item.designation, strips, net))
					continue
				part.append(_device(doc, item.designation))
				# An overload relay fitted under its contactor.
				if under.has(item.designation):
					part.append(_device(doc, under[item.designation]))
		part.append_array(_glands(doc, "+" + board.name))
		_add(result, "+%s  %s" % [board.name, board.title if not board.title.is_empty() else tr("Switchboard")], part)
	for box: ControlBox in doc.control_boxes:
		var part: Array[Dictionary] = []
		for item: ControlBoxItem in box.items:
			if not item.designation.is_empty():
				part.append(_control(doc, item))
			if not item.lamp.is_empty() and item.lamp != item.designation:
				part.append(_device(doc, item.lamp))
		part.append_array(_glands(doc, "+" + box.name))
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
		cables.append({"designation": cable["name"], "quantity": 1, "name": tr("Cable"), "data": "%s   %s – %s" % [WorkspaceCables.type_and_length(cable), cable["a"], cable["b"]]})
	_add(result, tr("Cables"), cables)
	return result


## Adds the rows of a place under [param heading], identical parts (same
## name and data) as one row with their count.
func _add(result: Array[Dictionary], heading: String, part: Array[Dictionary]) -> void:
	if part.is_empty():
		return
	result.append({"heading": true, "text": heading})
	var merged: Array[Dictionary] = []
	var at: Dictionary[String, int] = {}
	var names: Array[PackedStringArray] = []
	for row: Dictionary in part:
		var key: String = "%s|%s" % [row["name"], row["data"]]
		if at.has(key):
			var i: int = at[key]
			merged[i]["quantity"] = int(merged[i].get("quantity", 1)) + int(row.get("quantity", 1))
			names[i].append(str(row["designation"]))
		else:
			at[key] = merged.size()
			merged.append(row.duplicate())
			names.append(PackedStringArray([str(row["designation"])]))
	for i: int in merged.size():
		merged[i]["designation"] = designations(names[i])
	result.append_array(merged)


## Designations written short: runs of the same letters with numbers in
## turn as "-KM1…-KM3", the rest after commas: "-KM1…-KM3, -KA5".
static func designations(list: PackedStringArray) -> String:
	var out: PackedStringArray = PackedStringArray()
	var i: int = 0
	while i < list.size():
		var j: int = i
		while j + 1 < list.size() and _next_in_turn(list[j], list[j + 1]):
			j += 1
		out.append(list[i] if j == i else ("%s, %s" % [list[i], list[j]] if j == i + 1 else "%s…%s" % [list[i], list[j]]))
		i = j + 1
	return ", ".join(out)


## True when [param b] is [param a] with its number one higher ("-KM1", "-KM2").
static func _next_in_turn(a: String, b: String) -> bool:
	var split_a: PackedStringArray = _letters_number(a)
	var split_b: PackedStringArray = _letters_number(b)
	return not split_a[1].is_empty() and split_a[0] == split_b[0] and not split_b[1].is_empty() and int(split_b[1]) == int(split_a[1]) + 1


static func _letters_number(designation: String) -> PackedStringArray:
	var n: int = designation.length()
	while n > 0 and designation[n - 1] >= "0" and designation[n - 1] <= "9":
		n -= 1
	return PackedStringArray([designation.left(n), designation.substr(n)])


func _strip(strip: String, strips: Dictionary) -> Dictionary:
	var count: int = (strips.get(strip, []) as Array).size()
	return {"designation": "-" + strip, "quantity": 1, "name": tr("Terminal strip"), "data": tr_n("%d terminal", "%d terminals", count) % count}


## The plug-in bridges of strip [param strip] (see
## [method CabinetWiring.strip_bridges]): one row for each number of poles.
func _bridges(strip: String, strips: Dictionary, net: Dictionary[String, int]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var joined: Array[bool] = CabinetWiring.strip_bridges(strips.get(strip, []), net)
	var poles: int = 1
	for i: int in joined.size() + 1:
		if i < joined.size() and joined[i]:
			poles += 1
			continue
		if poles > 1:
			result.append({"designation": "-" + strip, "quantity": 1, "name": tr("Plug-in bridge"), "data": tr_n("%d pole", "%d poles", poles) % poles})
		poles = 1
	return result


## The cable glands of place [param place] ("+RA1"): one for each cable
## coming in, sized for it (see [method WorkspaceCables.gland]); those of one
## size are one row, the cables they take as the designation.
func _glands(doc: SchematicDocument, place: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for cable: Dictionary in WorkspaceCables.cables(doc):
		if cable["a"] != place and cable["b"] != place:
			continue
		var gland: Dictionary = WorkspaceCables.gland(cable)
		var data: String = tr("for Ø %s mm, none fits") % _num(WorkspaceCables.outer_diameter(cable))
		if not gland.is_empty():
			data = tr("%s, clamps Ø %s–%s mm") % [gland["size"], _num(gland["from"]), _num(gland["to"])]
		rows.append({"designation": cable["name"], "quantity": 1, "name": tr("Cable gland"), "data": data})
	return rows


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
	return {"designation": "-" + designation, "quantity": 1, "name": name_of(doc, designation), "data": data_of(doc, designation)}


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
	var contacts: String = contacts_of(doc, designation)
	if not contacts.is_empty():
		facts.append(contacts)
	return ", ".join(facts)


## The contact blocks device [param designation] needs: of a button, switch
## or limit switch all its blocks ("1 NO + 1 NC"), of a contactor, relay,
## time relay or breaker its auxiliary contacts ("aux. 2 NO + 1 NC"), changeover
## contacts as CO; "" for none.
func contacts_of(doc: SchematicDocument, designation: String) -> String:
	var no: int = 0
	var nc: int = 0
	var co: int = 0
	var operated: bool = false
	for c: CircuitComponent in doc.circuit.get_components():
		if c.designation != designation:
			continue
		if c is PushButton or c is LatchingSwitch:
			operated = true
		if c is ChangeoverContact:
			co += 1
		elif c is SwitchingElement and not (c is OverloadContact):
			if (c as SwitchingElement).contact_type == SwitchingElement.ContactType.NO:
				no += 1
			else:
				nc += 1
	var parts: PackedStringArray = PackedStringArray()
	if no > 0:
		parts.append(tr("%d NO") % no)
	if nc > 0:
		parts.append(tr("%d NC") % nc)
	if co > 0:
		parts.append(tr("%d CO") % co)
	if parts.is_empty():
		return ""
	return " + ".join(parts) if operated else tr("aux. %s") % " + ".join(parts)


func _num(value: float) -> String:
	return str(snappedf(value, 0.01)).trim_suffix(".0")
