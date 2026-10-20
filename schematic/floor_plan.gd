class_name FloorPlan
extends RefCounted
## Floor plan of a house installation (see [member
## SchematicDocument.residential]): rooms put together like modules, doors in
## their walls, where the switches, sockets, luminaires and appliances of the
## schematic are, and the consumer unit. Lengths in metres, y down. The
## cables between them are worked out from the wiring ([method cables]),
## never drawn by hand. No nodes.

## Lengths snap to this (m).
const SNAP: float = 0.05
## A room's edge this close to another room's edge (m) snaps onto it: rooms
## share their walls.
const WALL_SNAP: float = 0.3
## A switch, socket or appliance dropped this close to a wall (m) goes onto it.
const ON_WALL: float = 0.5
## Smallest room side (m).
const MIN_ROOM: float = 0.8
## Width of a door (m) when none is set.
const DOOR_WIDTH: float = 0.8
## Room sizes offered to start from (m), by English source name.
const PRESETS: Array[Dictionary] = [
	{"name": "Living room", "size": Vector2(5.0, 4.0)},
	{"name": "Bedroom", "size": Vector2(4.0, 3.5)},
	{"name": "Kitchen", "size": Vector2(3.5, 3.0)},
	{"name": "Bathroom", "size": Vector2(2.5, 2.0)},
	{"name": "WC", "size": Vector2(1.2, 1.0)},
	{"name": "Hall", "size": Vector2(3.0, 1.5)},
	{"name": "Room", "size": Vector2(3.0, 3.0)},
]
## Where the consumer unit is kept in [member parts].
const UNIT: String = "+RD1"
## Directions a part on a wall faces into its room: right, down, left, up.
const FACING: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]


## A room: its name and its inside (m).
class Room:
	var name: String = ""
	var rect: Rect2 = Rect2()

	func _init(p_name: String = "", p_rect: Rect2 = Rect2()) -> void:
		name = p_name
		rect = p_rect


## A door in a wall: its middle on the wall, its width, and whether the wall
## runs up and down.
class Door:
	var at: Vector2 = Vector2.ZERO
	var width: float = DOOR_WIDTH
	var vertical: bool = false

	func _init(p_at: Vector2 = Vector2.ZERO, p_vertical: bool = false, p_width: float = DOOR_WIDTH) -> void:
		at = p_at
		vertical = p_vertical
		width = p_width


var rooms: Array[Room] = []
var doors: Array[Door] = []
## Where each part (by designation) and the consumer unit ([constant UNIT])
## are (m).
var parts: Dictionary[String, Vector2] = {}
## Which way each part on a wall faces into its room (index into
## [constant FACING]); parts in no entry (luminaires) are on the ceiling.
var facing: Dictionary[String, int] = {}


func is_empty() -> bool:
	return rooms.is_empty() and doors.is_empty() and parts.is_empty()


## True for parts drawn on the plan: light switches, sockets, luminaires and
## appliances; the protective devices and supplies are in the consumer unit.
static func placeable(c: CircuitComponent) -> bool:
	return c is LightSwitch or c is SocketOutlet or c is Luminaire or c is Appliance


## True for parts that sit in the consumer unit.
static func in_unit(c: CircuitComponent) -> bool:
	return c is PowerSupply or c is ProtectiveDevice or c is MotorBreaker or c is ThreePoleFuse


## Designations of the parts of [param circuit] that can be placed, in
## circuit order, each once.
static func placeable_parts(circuit: Circuit) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for c: CircuitComponent in circuit.get_components():
		if placeable(c) and not result.has(c.designation):
			result.append(c.designation)
	return result


## Parts of [param circuit] not placed yet, with the consumer unit first
## when it is not placed and the circuit has something for it.
func unplaced(circuit: Circuit) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not parts.has(UNIT):
		for c: CircuitComponent in circuit.get_components():
			if in_unit(c) and not (c is PowerSupply):
				result.append(UNIT)
				break
	for designation: String in placeable_parts(circuit):
		if not parts.has(designation):
			result.append(designation)
	return result


static func snap(v: Vector2) -> Vector2:
	return v.snappedf(SNAP)


## [param rect] snapped: its corner to [constant SNAP], and its edges onto
## the edges of the other rooms (not room [param skip]) within
## [constant WALL_SNAP], keeping its size.
func snap_room(rect: Rect2, skip: int = -1) -> Rect2:
	var at: Vector2 = snap(rect.position)
	var best: Vector2 = Vector2(WALL_SNAP, WALL_SNAP)
	var shift: Vector2 = Vector2.ZERO
	for i: int in rooms.size():
		if i == skip:
			continue
		var other: Rect2 = rooms[i].rect
		for mine: float in [at.x, at.x + rect.size.x]:
			for theirs: float in [other.position.x, other.end.x]:
				if absf(theirs - mine) < best.x:
					best.x = absf(theirs - mine)
					shift.x = theirs - mine
		for mine: float in [at.y, at.y + rect.size.y]:
			for theirs: float in [other.position.y, other.end.y]:
				if absf(theirs - mine) < best.y:
					best.y = absf(theirs - mine)
					shift.y = theirs - mine
	return Rect2(at + shift, rect.size)


## Where a new room of [param size] goes: right of the others, top aligned.
func free_spot(size: Vector2) -> Rect2:
	if rooms.is_empty():
		return Rect2(Vector2.ZERO, size)
	var right: float = -INF
	var top: float = INF
	for room: Room in rooms:
		right = maxf(right, room.rect.end.x)
		top = minf(top, room.rect.position.y)
	return Rect2(Vector2(right, top), size)


## Moves room [param index] to [param to], taking along the parts in it
## and on its walls and the doors in its walls.
func move_room(index: int, to: Vector2) -> void:
	var rect: Rect2 = rooms[index].rect
	var by: Vector2 = to - rect.position
	var area: Rect2 = rect.grow(0.01)
	for designation: String in parts.keys():
		if area.has_point(parts[designation]):
			parts[designation] += by
	for door: Door in doors:
		if area.has_point(door.at):
			door.at += by
	rooms[index].rect = Rect2(to, rect.size)


## Index of the room holding [param point], the last one drawn first; -1.
func room_at(point: Vector2) -> int:
	for i: int in range(rooms.size() - 1, -1, -1):
		if rooms[i].rect.grow(0.001).has_point(point):
			return i
	return -1


## The wall point nearest to [param point] within [param reach] (m), and the
## way into the room from there: {"at", "facing"}; {} when no wall is near.
func wall_near(point: Vector2, reach: float = ON_WALL) -> Dictionary:
	var best: float = reach
	var result: Dictionary = {}
	for room: Room in rooms:
		var r: Rect2 = room.rect
		# Left, top, right, bottom wall: the point on it and the way in.
		var sides: Array = [
			[Vector2(r.position.x, clampf(point.y, r.position.y, r.end.y)), 0],
			[Vector2(clampf(point.x, r.position.x, r.end.x), r.position.y), 1],
			[Vector2(r.end.x, clampf(point.y, r.position.y, r.end.y)), 2],
			[Vector2(clampf(point.x, r.position.x, r.end.x), r.end.y), 3],
		]
		for side: Array in sides:
			var on: Vector2 = side[0]
			var d: float = on.distance_to(point)
			# Inside the room counts first: the wall is seen from there.
			var inside: bool = r.has_point(point)
			if d < best or (inside and is_equal_approx(d, best)):
				best = d
				result = {"at": snap(on), "facing": side[1]}
	return result


## Puts part [param designation] at [param point]: a switch, socket,
## appliance or the consumer unit near a wall onto it facing into the room,
## a luminaire where it is (on the ceiling).
func place(designation: String, point: Vector2, on_ceiling: bool) -> void:
	facing.erase(designation)
	var wall: Dictionary = {} if on_ceiling else wall_near(point)
	if wall.is_empty():
		parts[designation] = snap(point)
	else:
		parts[designation] = wall["at"]
		facing[designation] = wall["facing"]


## Takes part [param designation] off the plan.
func remove(designation: String) -> void:
	parts.erase(designation)
	facing.erase(designation)


## Part [param old_designation] was renamed [param new_designation].
func rename(old_designation: String, new_designation: String) -> void:
	if parts.has(old_designation) and not parts.has(new_designation):
		parts[new_designation] = parts[old_designation]
		if facing.has(old_designation):
			facing[new_designation] = facing[old_designation]
	remove(old_designation)


## Drops what is kept of parts [param circuit] no longer has.
func prune(circuit: Circuit) -> void:
	var placeable_now: PackedStringArray = placeable_parts(circuit)
	for designation: String in parts.keys():
		if designation != UNIT and not placeable_now.has(designation):
			remove(designation)


## The cables between the placed parts and the consumer unit, worked out
## from the wiring: for every net, the shortest tree (by distance along
## the walls' directions) over the places on it; the nets between two
## places are the cores of one cable. Each: {"a", "b": designations or
## [constant UNIT], "cores": count, "from", "to": points (m)}.
func cables(circuit: Circuit) -> Array[Dictionary]:
	# Nets: terminals joined by wires and page connectors.
	var keys: PackedStringArray = PackedStringArray()
	var index: Dictionary[String, int] = {}
	var owner: Array[String] = []
	for c: CircuitComponent in circuit.get_components():
		var node: String = ""
		if placeable(c) and parts.has(c.designation):
			node = c.designation
		elif in_unit(c) and parts.has(UNIT):
			node = UNIT
		for key: String in c.get_terminal_keys():
			index[key] = keys.size()
			keys.append(key)
			owner.append(node)
	var uf: UnionFind = UnionFind.new(keys.size())
	for wire: PackedStringArray in circuit.get_wires():
		uf.union(index[wire[0]], index[wire[1]])
	for link: PackedStringArray in circuit.get_links():
		uf.union(index[link[0]], index[link[1]])
	var nets: Dictionary[int, PackedStringArray] = {}
	for i: int in keys.size():
		if owner[i].is_empty():
			continue
		var root: int = uf.find(i)
		var nodes: PackedStringArray = nets.get(root, PackedStringArray())
		if not nodes.has(owner[i]):
			nodes.append(owner[i])
		nets[root] = nodes
	var cores: Dictionary[String, int] = {}
	for root: int in nets:
		var nodes: PackedStringArray = nets[root]
		if nodes.size() < 2:
			continue
		# Prim's tree from the first place on the net.
		var joined: PackedStringArray = PackedStringArray([nodes[0]])
		var left: PackedStringArray = nodes.slice(1)
		while not left.is_empty():
			var pick: Vector2i = Vector2i(-1, -1)
			var shortest: float = INF
			for a: int in joined.size():
				for b: int in left.size():
					var d: float = _manhattan(parts[joined[a]], parts[left[b]])
					if d < shortest:
						shortest = d
						pick = Vector2i(a, b)
			var from: String = joined[pick.x]
			var to: String = left[pick.y]
			var key: String = from + "|" + to if from < to else to + "|" + from
			cores[key] = cores.get(key, 0) + 1
			joined.append(to)
			left.remove_at(pick.y)
	var result: Array[Dictionary] = []
	for key: String in cores:
		var ends: PackedStringArray = key.split("|")
		result.append({"a": ends[0], "b": ends[1], "cores": cores[key], "from": parts[ends[0]], "to": parts[ends[1]]})
	return result


static func _manhattan(a: Vector2, b: Vector2) -> float:
	return absf(a.x - b.x) + absf(a.y - b.y)


## What covers everything (m); empty without anything.
func bounds() -> Rect2:
	var result: Rect2 = Rect2()
	var first: bool = true
	for room: Room in rooms:
		result = room.rect if first else result.merge(room.rect)
		first = false
	for designation: String in parts:
		result = Rect2(parts[designation], Vector2.ZERO) if first else result.expand(parts[designation])
		first = false
	return result


func to_data() -> Dictionary:
	var room_list: Array = []
	for room: Room in rooms:
		room_list.append({"name": room.name, "rect": [room.rect.position.x, room.rect.position.y, room.rect.size.x, room.rect.size.y]})
	var door_list: Array = []
	for door: Door in doors:
		door_list.append({"at": [door.at.x, door.at.y], "width": door.width, "vertical": door.vertical})
	var placed: Dictionary = {}
	for designation: String in parts:
		var entry: Array = [parts[designation].x, parts[designation].y]
		if facing.has(designation):
			entry.append(facing[designation])
		placed[designation] = entry
	return {"rooms": room_list, "doors": door_list, "parts": placed}


## Reads a plan; damaged rooms, doors and parts are left out.
static func from_data(raw: Variant) -> FloorPlan:
	var plan: FloorPlan = FloorPlan.new()
	if not (raw is Dictionary):
		return plan
	var d: Dictionary = raw
	var room_list: Variant = d.get("rooms", [])
	if room_list is Array:
		for rd: Variant in room_list:
			if rd is Dictionary and _numbers(rd.get("rect", []), 4):
				var r: Array = rd["rect"]
				var size: Vector2 = Vector2(maxf(float(r[2]), MIN_ROOM), maxf(float(r[3]), MIN_ROOM))
				plan.rooms.append(Room.new(str(rd.get("name", "")), Rect2(float(r[0]), float(r[1]), size.x, size.y)))
	var door_list: Variant = d.get("doors", [])
	if door_list is Array:
		for dd: Variant in door_list:
			if dd is Dictionary and _numbers(dd.get("at", []), 2):
				var width: Variant = dd.get("width", DOOR_WIDTH)
				plan.doors.append(Door.new(Vector2(float(dd["at"][0]), float(dd["at"][1])), dd.get("vertical", false) == true, clampf(float(width), 0.5, 3.0) if (width is float or width is int) else DOOR_WIDTH))
	var placed: Variant = d.get("parts", {})
	if placed is Dictionary:
		for designation: Variant in placed:
			var entry: Variant = placed[designation]
			if designation is String and _numbers(entry, 2):
				plan.parts[designation] = Vector2(float(entry[0]), float(entry[1]))
				if (entry as Array).size() > 2 and (entry[2] is int or entry[2] is float) and int(entry[2]) >= 0 and int(entry[2]) < 4:
					plan.facing[designation] = int(entry[2])
	return plan


static func _numbers(value: Variant, count: int) -> bool:
	if not (value is Array) or (value as Array).size() < count:
		return false
	for i: int in count:
		if not (value[i] is float or value[i] is int) or not is_finite(float(value[i])):
			return false
	return true
