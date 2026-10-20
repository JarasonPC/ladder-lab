class_name PartsList
extends RefCounted
## The parts list of a schematic for the export: every device by where it
## sits (each switchboard with its terminal strips, each control station,
## each group, the other parts in the field, what has no place yet), then the
## cables of the workspace. Within a place, identical parts (same name and
## data) are one row with their count; each switchboard and station lists
## the cable glands of the cables coming in. A residential installation's:
## the consumer unit, each floor's parts, what is on no floor, the boxes in
## the walls and ceilings and the metres of each cable (see
## [method SingleLine.cable_length]). Made with new() (its texts are
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
	for b: int in doc.switchboards.size():
		var board: Switchboard = doc.switchboards[b]
		var part: Array[Dictionary] = []
		var buses: Array[Dictionary] = CabinetLayout.bus_blocks(doc, b, strips, net)
		var apart: Dictionary[int, bool] = CabinetLayout.bus_nets(buses)
		for rail: CabinetRail in board.rails:
			for item: CabinetItem in rail.items:
				if item.kind == CabinetItem.Kind.STRIP:
					part.append(_strip(item.designation, strips))
					part.append_array(_bridges(item.designation, strips, CabinetDevices.supply_nets(doc.circuit, net), apart))
					continue
				part.append(_device(doc, item.designation))
				# An overload relay fitted under its contactor.
				if under.has(item.designation):
					part.append(_device(doc, under[item.designation]))
		# The distribution blocks the switchboard adds by itself.
		for bus: Dictionary in buses:
			part.append({"designation": "", "quantity": 1, "name": tr("N distribution block") if bus["neutral"] else tr("PE distribution block"), "data": tr_n("%d connection", "%d connections", bus["connections"]) % bus["connections"]})
		# The buttons, switches and lamps on its door.
		part.append_array(_controls(doc, board.door))
		part.append_array(_glands(doc, "+" + board.name))
		_add(result, "+%s  %s" % [board.name, board.title if not board.title.is_empty() else tr("Switchboard")], part)
	if doc.environment == SchematicDocument.Kind.RESIDENTIAL:
		_installation(doc, result)
		return result
	for box: ControlBox in doc.control_boxes:
		var part: Array[Dictionary] = _controls(doc, box)
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


## The rest of a residential installation's list: each floor's parts, those
## on no floor, the boxes and the cables.
func _installation(doc: SchematicDocument, result: Array[Dictionary]) -> void:
	var wall_boxes: int = 0
	var ceiling_boxes: int = 0
	for f: int in doc.floors.size():
		var part: Array[Dictionary] = []
		var designations: Array = doc.floors[f].parts.keys()
		designations.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
		for designation: String in designations:
			var c: CircuitComponent = doc.circuit.get_component(designation)
			if c == null:
				continue
			part.append(_device(doc, designation))
			if c is SocketOutlet:
				wall_boxes += (c as SocketOutlet).gangs
			elif c is LightSwitch or c is Appliance:
				wall_boxes += 1
			elif c is Luminaire:
				ceiling_boxes += 1
		_add(result, tr("On the floor plan") if doc.floors.size() == 1 else tr("Floor %s") % doc.floors[f].floor_name(), part)
	var missing: Array[Dictionary] = []
	for designation: String in doc.unplaced_parts():
		if designation != FloorPlan.UNIT:
			missing.append(_device(doc, designation))
	_add(result, tr("Not on a floor plan"), missing)
	var material: Array[Dictionary] = []
	if wall_boxes > 0:
		material.append({"designation": "", "quantity": wall_boxes, "name": tr("Wall box KU 68"), "data": tr("for switches, sockets (one a gang) and appliance outlets")})
	if ceiling_boxes > 0:
		material.append({"designation": "", "quantity": ceiling_boxes, "name": tr("Luminaire box"), "data": tr("on the ceiling or the wall, one a luminaire")})
	for cable: Dictionary in cable_totals(doc):
		material.append({"designation": cable["designations"], "quantity": 1, "name": tr("Cable"), "data": "%s   %d m" % [cable["type"], cable["metres"]]})
	_add(result, tr("Installation material"), material)


## The cables of a residential installation's circuits by type: {"type",
## "metres" (whole, rounded up, from the floor plan), "designations" of the
## circuits' cables ("-WD1…-WD3")}; circuits not on a plan are left out.
static func cable_totals(doc: SchematicDocument) -> Array[Dictionary]:
	var line: SingleLine = doc.single_line
	var by_type: Dictionary[String, float] = {}
	var names: Dictionary[String, PackedStringArray] = {}
	for f: SingleLine.Feeder in line.feeders():
		var length: float = line.cable_length(f, doc)
		if length < 0.0:
			continue
		var type: String = SingleLine.cable_text(f, doc.circuit)
		by_type[type] = by_type.get(type, 0.0) + length
		if not names.has(type):
			names[type] = PackedStringArray()
		names[type].append("-WD%d" % line.cable_number(f))
	var result: Array[Dictionary] = []
	var types: Array = by_type.keys()
	types.sort()
	for type: String in types:
		result.append({"type": type, "metres": ceili(by_type[type]), "designations": designations(names[type])})
	return result


## [param rows] as CSV (comma separated, quoted where needed): a heading row
## then the place, designation, quantity, name and data of each part.
static func to_csv(rows: Array[Dictionary], headings: PackedStringArray) -> String:
	var lines: PackedStringArray = PackedStringArray([_csv_row(headings)])
	var place: String = ""
	for row: Dictionary in rows:
		if row.get("heading", false):
			place = str(row["text"])
			continue
		lines.append(_csv_row(PackedStringArray([place, str(row["designation"]), str(row.get("quantity", 1)), str(row["name"]), str(row["data"])])))
	return "\n".join(lines) + "\n"


static func _csv_row(cells: PackedStringArray) -> String:
	var out: PackedStringArray = PackedStringArray()
	for cell: String in cells:
		out.append("\"%s\"" % cell.replace("\"", "\"\"") if cell.contains(",") or cell.contains("\"") or cell.contains("\n") else cell)
	return ",".join(out)


## Rows of the push buttons, switches and lamps on [param box] (a station or
## a door), with the lamps inside buttons.
func _controls(doc: SchematicDocument, box: ControlBox) -> Array[Dictionary]:
	var part: Array[Dictionary] = []
	for item: ControlBoxItem in box.items:
		if not item.designation.is_empty():
			part.append(_control(doc, item))
		if not item.lamp.is_empty() and item.lamp != item.designation:
			part.append(_device(doc, item.lamp))
	return part


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
func _bridges(strip: String, strips: Dictionary, net: Dictionary[String, int], apart: Dictionary[int, bool]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var joined: Array[bool] = CabinetWiring.strip_bridges(strips.get(strip, []), net, apart)
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
	if part is CamSwitch:
		return tr(StationPanel.CAM_SWITCH_TITLE)
	var control: int = ControlBoxItem.kind_of(part)
	if control >= 0:
		return tr(StationPanel.KIND_TITLES[control])
	var field: Workspace.Field = Workspace.field_kind(part)
	if field != Workspace.Field.NONE:
		return tr(WorkspaceCanvas.field_title(WorkspaceTile.of_part(part)))
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
		elif c is CamSwitch:
			fact = CamSwitch.POSITION_NAMES[(c as CamSwitch).positions] + (", " + tr("%d poles") % (c as CamSwitch).poles if (c as CamSwitch).poles > 1 else "")
		elif c is MainContacts and (c as MainContacts).poles > 1:
			fact = tr("%d poles") % (c as MainContacts).poles
		elif c is OverloadRelay:
			fact = "Ir %s A" % _num((c as OverloadRelay).setting)
		elif c is ThreePhaseMotor:
			var motor: ThreePhaseMotor = c as ThreePhaseMotor
			fact = "%s kW, %s A" % [_num(motor.rated_power), _num(motor.rated_current)]
		elif c is AnalogSensor:
			var sensor: AnalogSensor = c as AnalogSensor
			fact = "%s…%s %s, 0-10 V" % [_num(sensor.range_min), _num(sensor.range_max), sensor.unit()]
		elif c is Potentiometer:
			fact = tr_n("%s kΩ, %d turn", "%s kΩ, %d turns", (c as Potentiometer).turns) % [_num(Potentiometer.RESISTANCE / 1000.0), (c as Potentiometer).turns]
		elif c is ProximitySensor:
			var proximity: ProximitySensor = c as ProximitySensor
			fact = "%s, %s %s" % [Datasheet.of(c, doc).summary, ProximitySensor.OUTPUT_TEXTS[proximity.output], ProximitySensor.FUNCTION_TEXTS[proximity.function]]
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
