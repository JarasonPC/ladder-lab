class_name Workspace
extends RefCounted
## Queries about the workspace of a [SchematicDocument]: its places
## (switchboards, control stations, groups), the parts outside them that
## stand in the field (motors, limit switches, temperature sensors) and
## where everything sits. Positions are workspace units (pixels at zoom 1).
## No nodes; edits go through [SchematicDocument].

enum Place { SWITCHBOARD, STATION, GROUP }
## What a part in the field is drawn as.
enum Field { NONE = -1, MOTOR, LIMIT_SWITCH, SENSOR }

## Name prefix of each kind of place, in [enum Place] order ("+RA1", "+ST1", "+G1").
const PREFIXES: PackedStringArray = ["RA", "ST", "G"]
## Side of the tile of a switchboard or station, and the room it takes with
## its name under it (its title and contents show in the tooltip).
const TILE: float = 56.0
const PLACE_SIZE := Vector2(88.0, 80.0)
## Side of the tile of a part in the field, and the room it takes with its
## designation under it.
const FIELD_TILE: float = 44.0
const FIELD_SIZE := Vector2(88.0, 80.0)
## Room inside a group's frame round its members; its heading above them.
const GROUP_PAD: float = 18.0
const GROUP_HEAD: float = 26.0
## Size of a group's frame while it has no members.
const EMPTY_GROUP := Vector2(220.0, 120.0)
## Distance between places put side by side.
const SPACING: float = 60.0


## A location designation as saved: without "+", "" when unusable (spaces, colons).
static func place_name(value: Variant) -> String:
	var text: String = str(value).strip_edges().trim_prefix("+")
	return "" if text.contains(":") or text.contains(" ") else text


## A position saved as [x, y], [constant Vector2.ZERO] when malformed.
static func position_from(value: Variant) -> Vector2:
	if value is Array and (value as Array).size() == 2 and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int):
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


## Size of the tile of [param place] (a switchboard or station) on the
## workspace; a station shown as its face as large as the face at its scale.
static func place_size(place: RefCounted) -> Vector2:
	if place is ControlBox and (place as ControlBox).face_scale > 0.0:
		return (place as ControlBox).face_size() * (place as ControlBox).face_scale
	return PLACE_SIZE


## Tile of a switchboard or station at [param position] (not shown as its
## face): at the top in the middle of its room, its name under it.
static func place_tile(position: Vector2) -> Rect2:
	return Rect2(position + Vector2((PLACE_SIZE.x - TILE) * 0.5, 0.0), Vector2(TILE, TILE))


## How [param c] stands in the field, [constant Field.NONE] when it is not a
## part of its own there.
static func field_kind(c: CircuitComponent) -> Field:
	if c is ThreePhaseMotor or c is Motor:
		return Field.MOTOR
	if c is LimitSwitch:
		return Field.LIMIT_SWITCH
	if c is AnalogSensor or c is ProximitySensor:
		return Field.SENSOR
	return Field.NONE


## Whether [param c] can be operated by a mechanical link: a limit switch or
## a proximity sensor.
static func is_stop(c: CircuitComponent) -> bool:
	return c is LimitSwitch or c is ProximitySensor


## Designations of the parts in the field, in circuit order (each once).
static func field_devices(circuit: Circuit) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for c: CircuitComponent in circuit.get_components():
		if field_kind(c) != Field.NONE and not result.has(c.designation):
			result.append(c.designation)
	return result


## The component a part in the field is drawn for, or null.
static func field_component(circuit: Circuit, designation: String) -> CircuitComponent:
	for c: CircuitComponent in circuit.get_components():
		if c.designation == designation and field_kind(c) != Field.NONE:
			return c
	return null


## Where each part in the field sits: where it was put, else in a row under
## everything else (a member of a group without a place: in its frame).
static func field_positions(doc: SchematicDocument) -> Dictionary[String, Vector2]:
	var result: Dictionary[String, Vector2] = {}
	var loose: PackedStringArray = PackedStringArray()
	for designation: String in field_devices(doc.circuit):
		if doc.field_positions.has(designation):
			result[designation] = doc.field_positions[designation]
		else:
			loose.append(designation)
	if loose.is_empty():
		return result
	var bottom: float = 0.0
	var left: float = INF
	var known: Array[Rect2] = []
	for board: Switchboard in doc.switchboards:
		known.append(Rect2(board.position, PLACE_SIZE))
	for box: ControlBox in doc.control_boxes:
		known.append(Rect2(box.position, place_size(box)))
	for designation: String in result:
		known.append(Rect2(result[designation], FIELD_SIZE))
	for group: WorkspaceGroup in doc.groups:
		known.append(Rect2(group.position, EMPTY_GROUP))
	for rect: Rect2 in known:
		bottom = maxf(bottom, rect.end.y)
		left = minf(left, rect.position.x)
	var row: Vector2 = Vector2(0.0 if left == INF else left, bottom + SPACING if not known.is_empty() else 0.0)
	var in_group: Dictionary[String, Vector2] = {}
	for group: WorkspaceGroup in doc.groups:
		var at: Vector2 = group.position + Vector2(GROUP_PAD, GROUP_HEAD)
		for member: String in group.members:
			if loose.has(member):
				in_group[member] = at
				at.x += FIELD_SIZE.x
	for designation: String in loose:
		if in_group.has(designation):
			result[designation] = in_group[designation]
		else:
			result[designation] = row
			row.x += FIELD_SIZE.x + 12.0
	return result


## Frame of [param group] round its members at [param positions] (see
## [method field_positions]); while it has none, [constant EMPTY_GROUP] at its position.
static func group_rect(group: WorkspaceGroup, positions: Dictionary[String, Vector2]) -> Rect2:
	var rect: Rect2 = Rect2()
	var found: bool = false
	for member: String in group.members:
		if not positions.has(member):
			continue
		var r: Rect2 = Rect2(positions[member], FIELD_SIZE)
		rect = r if not found else rect.merge(r)
		found = true
	if not found:
		return Rect2(group.position, EMPTY_GROUP)
	return rect.grow_individual(GROUP_PAD, GROUP_HEAD, GROUP_PAD, GROUP_PAD)


## The group [param designation] (a part in the field) is a member of, -1 for none.
static func group_of(doc: SchematicDocument, designation: String) -> int:
	for g: int in doc.groups.size():
		if doc.groups[g].members.has(designation):
			return g
	return -1


## Index of the switchboard holding device or terminal strip
## [param designation] on a rail, -1 for none.
static func switchboard_of(doc: SchematicDocument, kind: CabinetItem.Kind, designation: String) -> int:
	for b: int in doc.switchboards.size():
		for rail: CabinetRail in doc.switchboards[b].rails:
			for item: CabinetItem in rail.items:
				if item.kind == kind and item.designation == designation:
					return b
	return -1


## Index of the control station showing device [param designation] (also as
## the lamp inside a button), -1 for none.
static func station_of(doc: SchematicDocument, designation: String) -> int:
	for s: int in doc.control_boxes.size():
		for item: ControlBoxItem in doc.control_boxes[s].items:
			if item.designation == designation or item.lamp == designation:
				return s
	return -1


## Index of the switchboard with device [param designation] on its door
## (also as the lamp inside a button), -1 for none.
static func door_of(doc: SchematicDocument, designation: String) -> int:
	for b: int in doc.switchboards.size():
		for item: ControlBoxItem in doc.switchboards[b].door.items:
			if item.designation == designation or item.lamp == designation:
				return b
	return -1


## What has no place yet: devices and terminal strips not in a switchboard,
## push buttons, switches, lamps and potentiometers not on a control
## station or a door. Each
## {"kind": "device", "strip" or "control", "designation"}, in that order.
static func unplaced(doc: SchematicDocument) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: CabinetItem in doc.cabinet_unplaced():
		result.append({"kind": "strip" if item.kind == CabinetItem.Kind.STRIP else "device", "designation": item.designation})
	var listed: Dictionary[String, bool] = doc.control_panel_devices()
	for kind: int in [ControlBoxItem.Kind.BUTTON, ControlBoxItem.Kind.SWITCH, ControlBoxItem.Kind.LAMP, ControlBoxItem.Kind.POT]:
		for designation: String in doc.control_devices(kind):
			if not listed.has(designation):
				result.append({"kind": "control", "designation": designation})
	return result


## The machine parts moved by motors (the mechanical links of the groups,
## see [method SchematicDocument.set_group_link]) for a simulation of
## [param doc]: only a member motor drives, only member limit switches and
## proximity sensors count.
static func travels(doc: SchematicDocument) -> Array[Travel]:
	var result: Array[Travel] = []
	for group: WorkspaceGroup in doc.groups:
		if group.drive.is_empty() or not group.members.has(group.drive):
			continue
		var motor: CircuitComponent = field_component(doc.circuit, group.drive)
		if field_kind(motor) != Field.MOTOR:
			continue
		var travel: Travel = Travel.new(group.name, motor, group.travel_time, group.start)
		for designation: String in group.stops:
			var switch: CircuitComponent = doc.circuit.get_operator(designation)
			if switch == null:
				switch = field_component(doc.circuit, designation)
			if group.members.has(designation) and is_stop(switch):
				travel.add_switch(switch, group.stops[designation])
		result.append(travel)
	return result
