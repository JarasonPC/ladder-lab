class_name FloorPlan
extends RefCounted
## Floor plan of a house installation (see [member
## SchematicDocument.residential]): rooms put together like modules, doors in
## their walls, where the switches, sockets, luminaires and appliances of the
## schematic are, and the consumer unit. Lengths in metres, y down. The
## cables between them are worked out from the wiring ([method cables]),
## never drawn by hand. A residential installation's plan also has the
## lighting drawn on it ([member links]: which switch switches which
## luminaire), from which its single-line diagram wires them (see
## [method SingleLine.wire]), and its rooms a number, an environment and an
## illuminance for the legend. No nodes.

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
## Room sizes offered to start from (m), by English source name; an "l"
## cut (m) out of the lower right corner makes an L-shaped room.
const PRESETS: Array[Dictionary] = [
	{"name": "Living room", "size": Vector2(5.0, 4.0)},
	{"name": "Bedroom", "size": Vector2(4.0, 3.5)},
	{"name": "Kitchen", "size": Vector2(3.5, 3.0)},
	{"name": "Bathroom", "size": Vector2(2.5, 2.0)},
	{"name": "WC", "size": Vector2(1.2, 1.0)},
	{"name": "Hall", "size": Vector2(3.0, 1.5)},
	{"name": "Room", "size": Vector2(3.0, 3.0)},
	{"name": "Living room", "size": Vector2(6.0, 5.0), "l": Vector2(2.5, 2.0)},
]
## Where the consumer unit is kept in [member parts].
const UNIT: String = "+RD1"
## Directions a part on a wall faces into its room: right, down, left, up.
const FACING: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]


## Room numbers when none is set: the first room is this, the next one more.
const FIRST_NUMBER: int = 101
## Environments (prostředí) after ČSN 33 2000-5-51 offered for a room: normal,
## a bathroom (ČSN 33 2000-7-701), outdoors, an attic.
const ENVIRONMENTS: PackedStringArray = ["N", "ČSN 33 2000-7-701", "AB8, AD4", "AB7"]
## What each of [constant ENVIRONMENTS] means (English source text).
const ENVIRONMENT_NOTES: PackedStringArray = [
	"Normal: a dry room heated as usual, no water, dust or other influence beyond the normal range",
	"A room with a bath or shower: zones 0, 1 and 2 around it, parts in them IPX4 and more, every circuit behind a 30 mA RCD",
	"Outdoors: open air from -50 to +40 °C (AB8), water splashing from any direction (AD4), parts IP44 and more",
	"Sheltered but not heated, such as an attic or a garage: from -25 to +55 °C (AB7)",
]
## Illuminance (lx) of a room by its English source name after ČSN EN 12464-1,
## when none is set.
const LUX: Dictionary[String, String] = {"Living room": "150, 300/500", "Bedroom": "150", "Kitchen": "300/500", "Bathroom": "200", "WC": "100", "Hall": "100", "Room": "150"}


## Shortest wall of a room that is not a rectangle (m).
const MIN_WALL: float = 0.2


## A room: its name and its inside (m), the outline of its walls, every one
## running across or up and down (a rectangle, an L, ...); in a residential
## installation its number, environment and illuminance ("" for the usual
## ones).
class Room:
	var name: String = ""
	## The corners in order, clockwise as drawn (y down); wall k runs from
	## corner k to corner k + 1.
	var points: PackedVector2Array = PackedVector2Array()
	var number: String = ""
	var environment: String = ""
	var lux: String = ""
	## Where its name or number and area are, from their place in its
	## top left corner (m).
	var label_offset: Vector2 = Vector2.ZERO
	## The rectangle round it; set, the room becomes that rectangle.
	var rect: Rect2:
		get:
			if points.is_empty():
				return Rect2()
			var r: Rect2 = Rect2(points[0], Vector2.ZERO)
			for p: Vector2 in points:
				r = r.expand(p)
			return r
		set(value):
			points = PackedVector2Array([value.position, Vector2(value.end.x, value.position.y), value.end, Vector2(value.position.x, value.end.y)])

	func _init(p_name: String = "", p_rect: Rect2 = Rect2()) -> void:
		name = p_name
		rect = p_rect

	func is_rectangle() -> bool:
		return points.size() == 4

	## Its floor area (m²).
	func area() -> float:
		var sum: float = 0.0
		for i: int in points.size():
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % points.size()]
			sum += a.x * b.y - b.x * a.y
		return absf(sum) * 0.5

	## Whether [param point] is in it or on its walls.
	func contains(point: Vector2, margin: float = 0.001) -> bool:
		if not rect.grow(margin).has_point(point):
			return false
		if Geometry2D.is_point_in_polygon(point, points):
			return true
		for k: int in points.size():
			if Geometry2D.get_closest_point_to_segment(point, points[k], points[(k + 1) % points.size()]).distance_to(point) <= margin:
				return true
		return false

	## Its top left corner (of the topmost, the leftmost): where its label goes.
	func corner() -> Vector2:
		var best: Vector2 = points[0]
		for p: Vector2 in points:
			if p.y < best.y - 0.001 or (absf(p.y - best.y) <= 0.001 and p.x < best.x):
				best = p
		return best

	## Wall [param k]: [from, to].
	func wall(k: int) -> PackedVector2Array:
		return PackedVector2Array([points[k], points[(k + 1) % points.size()]])

	## The way into the room from wall [param k]: right of it as drawn.
	func inward(k: int) -> Vector2:
		var w: PackedVector2Array = wall(k)
		return (w[1] - w[0]).normalized().rotated(PI / 2.0).round()


## A line of the lighting drawn between two parts: a light switch and a
## luminaire it switches, two switches of one staircase (their travellers),
## or two luminaires lit together. A port is which rocker or output of a
## switch with two (4, 5, 5B) the line leaves from.
class Link:
	var a: String = ""
	var b: String = ""
	var a_port: int = 0
	var b_port: int = 0

	func _init(p_a: String = "", p_a_port: int = 0, p_b: String = "", p_b_port: int = 0) -> void:
		a = p_a
		a_port = p_a_port
		b = p_b
		b_port = p_b_port

	## The other end of the link from [param designation].
	func other(designation: String) -> String:
		return b if designation == a else a

	## The port at the end of [param designation].
	func port(designation: String) -> int:
		return a_port if designation == a else b_port


## A door in a wall: its middle on the wall, its width, whether the wall
## runs up and down, and how it swings: its hinge at the start of its
## opening (left or top) or at the end ([member hinge_end]), its leaf opening
## down from a wall running across or left of one running up and down, or
## to the other side ([member opens_back]).
class Door:
	var at: Vector2 = Vector2.ZERO
	var width: float = DOOR_WIDTH
	var vertical: bool = false
	var hinge_end: bool = false
	var opens_back: bool = false
	## Two leaves, hinged at both ends, meeting in the middle.
	var double: bool = false

	## The next way it can swing: the four, a double click going round them.
	func turn() -> void:
		if hinge_end:
			opens_back = not opens_back
		hinge_end = not hinge_end

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
## The lighting drawn on the plan of a residential installation.
var links: Array[Link] = []


func is_empty() -> bool:
	return rooms.is_empty() and doors.is_empty() and parts.is_empty() and links.is_empty()


## Number of room [param index]: the one set, else counted from [constant FIRST_NUMBER].
func room_number(index: int) -> String:
	return rooms[index].number if not rooms[index].number.is_empty() else str(FIRST_NUMBER + index)


## Environment of room [param index]: the one set, else normal (a bathroom's after
## ČSN 33 2000-7-701).
func room_environment(index: int) -> String:
	if not rooms[index].environment.is_empty():
		return rooms[index].environment
	return ENVIRONMENTS[1] if rooms[index].name == "Bathroom" else ENVIRONMENTS[0]


## Illuminance (lx) of room [param index]: the one set, else the usual one for its name.
func room_lux(index: int) -> String:
	return rooms[index].lux if not rooms[index].lux.is_empty() else LUX.get(rooms[index].name, "150")


## Draws the lighting between [param a] (port [param a_port]) and [param b]:
## false for a part to itself or a link there already.
func add_link(a: String, a_port: int, b: String, b_port: int) -> bool:
	if a == b or a.is_empty() or b.is_empty():
		return false
	for link: Link in links:
		if (link.a == a and link.b == b and link.a_port == a_port and link.b_port == b_port) or (link.a == b and link.b == a and link.a_port == b_port and link.b_port == a_port):
			return false
	links.append(Link.new(a, a_port, b, b_port))
	return true


## The links of part [param designation].
func links_of(designation: String) -> Array[Link]:
	var result: Array[Link] = []
	for link: Link in links:
		if link.a == designation or link.b == designation:
			result.append(link)
	return result


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


## A room of preset [param index] (see [constant PRESETS]) with its corner at
## [param at]; [param room_name] for its name.
static func preset_room(index: int, at: Vector2, room_name: String) -> Room:
	var preset: Dictionary = PRESETS[index]
	var size: Vector2 = preset["size"]
	var room: Room = Room.new(room_name, Rect2(at, size))
	if preset.has("l"):
		var cut: Vector2 = preset["l"]
		room.points = PackedVector2Array([at, at + Vector2(size.x, 0), at + Vector2(size.x, size.y - cut.y), at + size - cut, at + Vector2(size.x - cut.x, size.y), at + Vector2(0, size.y)])
	return room


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


## Moves room [param index] (the corner of the rectangle round it) to
## [param to], taking along the parts in it and on its walls and the doors
## in its walls.
func move_room(index: int, to: Vector2) -> void:
	var room: Room = rooms[index]
	var by: Vector2 = to - room.rect.position
	for designation: String in parts.keys():
		if room.contains(parts[designation], 0.01):
			parts[designation] += by
	for door: Door in doors:
		if room.contains(door.at, 0.01):
			door.at += by
	for i: int in room.points.size():
		room.points[i] += by


## Coordinate of side [param side] (0 left, 1 top, 2 right, 3 bottom) of [param r].
static func edge(r: Rect2, side: int) -> float:
	return [r.position.x, r.position.y, r.end.x, r.end.y][side]


## Wall of a rectangular room on side [param side] (0 left, 1 top, 2 right,
## 3 bottom), as its corners run (top, right, bottom, left).
static func side_wall(side: int) -> int:
	return (side + 3) % 4


## Moves wall [param side] (0 left, 1 top, 2 right, 3 bottom) of rectangular
## room [param index] to [param at] (see [method set_edge]).
func set_wall(index: int, side: int, at: float) -> void:
	set_edge(index, side_wall(side), at)


## [param points] with wall [param k] moved to [param at] (its x when it
## runs up and down, else its y).
static func with_edge(points: PackedVector2Array, k: int, at: float) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	var n: int = points.size()
	var vertical: bool = is_equal_approx(points[k].x, points[(k + 1) % n].x)
	for i: int in [k, (k + 1) % n]:
		if vertical:
			result[i].x = at
		else:
			result[i].y = at
	return result


## Moves wall [param k] of room [param index] to [param at] (its x when it
## runs up and down, else its y, snapped), never making the walls beside it
## shorter than [constant MIN_WALL] (a rectangle no smaller than
## [constant MIN_ROOM]) nor turning them round: a wall of another room on
## the same line along it moves along (they keep sharing it), and the parts
## and doors on it move with it.
func set_edge(index: int, k: int, at: float) -> void:
	var room: Room = rooms[index]
	var w: PackedVector2Array = room.wall(k)
	var vertical: bool = is_equal_approx(w[0].x, w[1].x)
	var old: float = w[0].x if vertical else w[0].y
	var span: Vector2 = Vector2(minf(w[0].y, w[1].y), maxf(w[0].y, w[1].y)) if vertical else Vector2(minf(w[0].x, w[1].x), maxf(w[0].x, w[1].x))
	var moving: Array[Vector2i] = [Vector2i(index, k)]
	for i: int in rooms.size():
		if i == index:
			continue
		for j: int in rooms[i].points.size():
			var o: PackedVector2Array = rooms[i].wall(j)
			if is_equal_approx(o[0].x, o[1].x) != vertical:
				continue
			var o_at: float = o[0].x if vertical else o[0].y
			var o_span: Vector2 = Vector2(minf(o[0].y, o[1].y), maxf(o[0].y, o[1].y)) if vertical else Vector2(minf(o[0].x, o[1].x), maxf(o[0].x, o[1].x))
			if absf(o_at - old) < 0.001 and minf(span.y, o_span.y) - maxf(span.x, o_span.x) > 0.001:
				moving.append(Vector2i(i, j))
	at = snappedf(at, SNAP)
	for m: Vector2i in moving:
		at = _clamp_edge(rooms[m.x], m.y, at)
	var by: float = at - old
	if is_zero_approx(by):
		return
	for designation: String in parts.keys():
		var p: Vector2 = parts[designation]
		var along: float = p.y if vertical else p.x
		if absf((p.x if vertical else p.y) - old) < 0.01 and along >= span.x - 0.01 and along <= span.y + 0.01:
			parts[designation] = p + (Vector2(by, 0) if vertical else Vector2(0, by))
	for door: Door in doors:
		var along_door: float = door.at.y if vertical else door.at.x
		if absf((door.at.x if vertical else door.at.y) - old) < 0.01 and along_door >= span.x and along_door <= span.y:
			door.at += Vector2(by, 0) if vertical else Vector2(0, by)
	for m: Vector2i in moving:
		rooms[m.x].points = with_edge(rooms[m.x].points, m.y, at)


## [param at] for wall [param k] of [param room] kept so that the walls
## beside it stay at least as long as they must, the way they run.
static func _clamp_edge(room: Room, k: int, at: float) -> float:
	var n: int = room.points.size()
	var least: float = MIN_ROOM if room.is_rectangle() else MIN_WALL
	var vertical: bool = is_equal_approx(room.points[k].x, room.points[(k + 1) % n].x)
	# The far ends of the walls before and after it.
	for far: Vector2 in [room.points[(k + n - 1) % n], room.points[(k + 2) % n]]:
		var near: Vector2 = room.points[k]
		var from: float = far.x if vertical else far.y
		var now: float = near.x if vertical else near.y
		if now > from:
			at = maxf(at, from + least)
		else:
			at = minf(at, from - least)
	return at


## Gives wall [param k] of room [param index] the length [param length]
## (m): its start stays, the wall after it moves.
func set_wall_length(index: int, k: int, length: float) -> void:
	var w: PackedVector2Array = rooms[index].wall(k)
	var direction: Vector2 = (w[1] - w[0]).normalized()
	var by: float = maxf(length, MIN_WALL) - w[0].distance_to(w[1])
	var n: int = rooms[index].points.size()
	var next: PackedVector2Array = rooms[index].wall((k + 1) % n)
	var vertical_next: bool = is_equal_approx(next[0].x, next[1].x)
	var at: float = (next[0].x + direction.x * by) if vertical_next else (next[0].y + direction.y * by)
	set_edge(index, (k + 1) % n, at)


## Gives rectangular room [param index] the inside [param size] (m): its
## right and bottom walls move (see [method set_edge]).
func resize_room(index: int, size: Vector2) -> void:
	set_wall(index, 2, rooms[index].rect.position.x + maxf(size.x, MIN_ROOM))
	set_wall(index, 3, rooms[index].rect.position.y + maxf(size.y, MIN_ROOM))


## Joins rooms [param a] and [param b] into one (room [param a] with its
## name and number; an L-shaped room of two rectangles, and so on): false
## when they do not touch along a wall.
func join_rooms(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0 or a >= rooms.size() or b >= rooms.size():
		return false
	var outline: PackedVector2Array = union_outline([rooms[a].points, rooms[b].points])
	if outline.is_empty():
		return false
	rooms[a].points = outline
	rooms.remove_at(b)
	return true


## The outline of the polygons [param shapes] (every side across or up and
## down) put together, clockwise as drawn; empty when they do not make one
## piece without holes.
static func union_outline(shapes: Array[PackedVector2Array]) -> PackedVector2Array:
	var xs: PackedFloat32Array = PackedFloat32Array()
	var ys: PackedFloat32Array = PackedFloat32Array()
	for shape: PackedVector2Array in shapes:
		for p: Vector2 in shape:
			if not _has_near(xs, p.x):
				xs.append(p.x)
			if not _has_near(ys, p.y):
				ys.append(p.y)
	xs.sort()
	ys.sort()
	var inside: Dictionary[Vector2i, bool] = {}
	for i: int in xs.size() - 1:
		for j: int in ys.size() - 1:
			var center: Vector2 = Vector2((xs[i] + xs[i + 1]) * 0.5, (ys[j] + ys[j + 1]) * 0.5)
			for shape: PackedVector2Array in shapes:
				if Geometry2D.is_point_in_polygon(center, shape):
					inside[Vector2i(i, j)] = true
					break
	if inside.is_empty():
		return PackedVector2Array()
	# The cells' sides on the border, each clockwise as drawn: next corner by corner.
	var next: Dictionary[Vector2i, Vector2i] = {}
	for cell: Vector2i in inside:
		var sides: Array = [
			[Vector2i(0, -1), Vector2i(cell.x, cell.y), Vector2i(cell.x + 1, cell.y)],
			[Vector2i(1, 0), Vector2i(cell.x + 1, cell.y), Vector2i(cell.x + 1, cell.y + 1)],
			[Vector2i(0, 1), Vector2i(cell.x + 1, cell.y + 1), Vector2i(cell.x, cell.y + 1)],
			[Vector2i(-1, 0), Vector2i(cell.x, cell.y + 1), Vector2i(cell.x, cell.y)],
		]
		for side: Array in sides:
			if not inside.has(cell + (side[0] as Vector2i)):
				if next.has(side[1]):
					# Two pieces touching at a corner only.
					return PackedVector2Array()
				next[side[1]] = side[2]
	var start: Vector2i = next.keys()[0]
	var loop: Array[Vector2i] = [start]
	var at: Vector2i = next[start]
	while at != start:
		loop.append(at)
		if loop.size() > next.size():
			return PackedVector2Array()
		at = next[at]
	if loop.size() != next.size():
		# More than one piece, or a hole.
		return PackedVector2Array()
	var outline: PackedVector2Array = PackedVector2Array()
	for k: int in loop.size():
		var before: Vector2i = loop[(k + loop.size() - 1) % loop.size()]
		var after: Vector2i = loop[(k + 1) % loop.size()]
		# Corners only: not on a straight run.
		if (loop[k] - before).sign() != (after - loop[k]).sign():
			outline.append(Vector2(xs[loop[k].x], ys[loop[k].y]))
	return outline


static func _has_near(values: PackedFloat32Array, v: float) -> bool:
	for x: float in values:
		if absf(x - v) < 0.001:
			return true
	return false


## Index of the room holding [param point], the last one drawn first; -1.
func room_at(point: Vector2) -> int:
	for i: int in range(rooms.size() - 1, -1, -1):
		if rooms[i].contains(point):
			return i
	return -1


## The wall point nearest to [param point] within [param reach] (m), and the
## way into the room from there: {"at", "facing"}; {} when no wall is near.
func wall_near(point: Vector2, reach: float = ON_WALL) -> Dictionary:
	var best: float = reach
	var result: Dictionary = {}
	for room: Room in rooms:
		# Inside the room counts first: the wall is seen from there.
		var inside: bool = room.contains(point)
		for k: int in room.points.size():
			var w: PackedVector2Array = room.wall(k)
			var on: Vector2 = Geometry2D.get_closest_point_to_segment(point, w[0], w[1])
			var d: float = on.distance_to(point)
			if d < best or (inside and is_equal_approx(d, best)):
				best = d
				result = {"at": snap(on), "facing": maxi(FACING.find(room.inward(k)), 0)}
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


## Takes part [param designation] off the plan, with its links.
func remove(designation: String) -> void:
	parts.erase(designation)
	facing.erase(designation)
	for i: int in range(links.size() - 1, -1, -1):
		if links[i].a == designation or links[i].b == designation:
			links.remove_at(i)


## Part [param old_designation] was renamed [param new_designation].
func rename(old_designation: String, new_designation: String) -> void:
	if parts.has(old_designation) and not parts.has(new_designation):
		parts[new_designation] = parts[old_designation]
		if facing.has(old_designation):
			facing[new_designation] = facing[old_designation]
	for link: Link in links:
		if link.a == old_designation:
			link.a = new_designation
		if link.b == old_designation:
			link.b = new_designation
	parts.erase(old_designation)
	facing.erase(old_designation)


## Drops what is kept of parts [param circuit] no longer has.
func prune(circuit: Circuit) -> void:
	var placeable_now: PackedStringArray = placeable_parts(circuit)
	for designation: String in parts.keys():
		if designation != UNIT and not placeable_now.has(designation):
			remove(designation)
	for i: int in range(links.size() - 1, -1, -1):
		if not placeable_now.has(links[i].a) or not placeable_now.has(links[i].b):
			links.remove_at(i)


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
		var rd: Dictionary = {"name": room.name, "rect": [room.rect.position.x, room.rect.position.y, room.rect.size.x, room.rect.size.y]}
		if room.label_offset != Vector2.ZERO:
			rd["label"] = [room.label_offset.x, room.label_offset.y]
		if not room.is_rectangle():
			var corners: Array = []
			for p: Vector2 in room.points:
				corners.append([p.x, p.y])
			rd["points"] = corners
		for key: String in ["number", "environment", "lux"]:
			if not str(room.get(key)).is_empty():
				rd[key] = room.get(key)
		room_list.append(rd)
	var door_list: Array = []
	for door: Door in doors:
		var dd: Dictionary = {"at": [door.at.x, door.at.y], "width": door.width, "vertical": door.vertical}
		if door.hinge_end:
			dd["hinge_end"] = true
		if door.opens_back:
			dd["opens_back"] = true
		if door.double:
			dd["double"] = true
		door_list.append(dd)
	var placed: Dictionary = {}
	for designation: String in parts:
		var entry: Array = [parts[designation].x, parts[designation].y]
		if facing.has(designation):
			entry.append(facing[designation])
		placed[designation] = entry
	var result: Dictionary = {"rooms": room_list, "doors": door_list, "parts": placed}
	if not links.is_empty():
		var link_list: Array = []
		for link: Link in links:
			link_list.append([link.a, link.a_port, link.b, link.b_port])
		result["links"] = link_list
	return result


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
				var room: Room = Room.new(str(rd.get("name", "")), Rect2(float(r[0]), float(r[1]), size.x, size.y))
				if _numbers(rd.get("label", []), 2):
					room.label_offset = Vector2(clampf(float(rd["label"][0]), -50.0, 50.0), clampf(float(rd["label"][1]), -50.0, 50.0))
				var corners: Variant = rd.get("points", [])
				if corners is Array and (corners as Array).size() >= 6:
					var outline: PackedVector2Array = PackedVector2Array()
					for c: Variant in corners:
						if _numbers(c, 2):
							outline.append(Vector2(float(c[0]), float(c[1])))
					# Only walls across or up and down, as one piece.
					var shape: PackedVector2Array = union_outline([outline]) if outline.size() == (corners as Array).size() else PackedVector2Array()
					if not shape.is_empty():
						room.points = shape
				for key: String in ["number", "environment", "lux"]:
					if rd.get(key, "") is String:
						room.set(key, (rd[key] as String).strip_edges() if rd.has(key) else "")
				plan.rooms.append(room)
	var door_list: Variant = d.get("doors", [])
	if door_list is Array:
		for dd: Variant in door_list:
			if dd is Dictionary and _numbers(dd.get("at", []), 2):
				var width: Variant = dd.get("width", DOOR_WIDTH)
				var door: Door = Door.new(Vector2(float(dd["at"][0]), float(dd["at"][1])), dd.get("vertical", false) == true, clampf(float(width), 0.5, 3.0) if (width is float or width is int) else DOOR_WIDTH)
				door.hinge_end = dd.get("hinge_end", false) == true
				door.opens_back = dd.get("opens_back", false) == true
				door.double = dd.get("double", false) == true
				plan.doors.append(door)
	var placed: Variant = d.get("parts", {})
	if placed is Dictionary:
		for designation: Variant in placed:
			var entry: Variant = placed[designation]
			if designation is String and _numbers(entry, 2):
				plan.parts[designation] = Vector2(float(entry[0]), float(entry[1]))
				if (entry as Array).size() > 2 and (entry[2] is int or entry[2] is float) and int(entry[2]) >= 0 and int(entry[2]) < 4:
					plan.facing[designation] = int(entry[2])
	var link_list: Variant = d.get("links", [])
	if link_list is Array:
		for ld: Variant in link_list:
			if ld is Array and (ld as Array).size() == 4 and ld[0] is String and ld[2] is String and (ld[1] is int or ld[1] is float) and (ld[3] is int or ld[3] is float):
				plan.add_link(ld[0], clampi(int(ld[1]), 0, 1), ld[2], clampi(int(ld[3]), 0, 1))
	return plan


static func _numbers(value: Variant, count: int) -> bool:
	if not (value is Array) or (value as Array).size() < count:
		return false
	for i: int in count:
		if not (value[i] is float or value[i] is int) or not is_finite(float(value[i])):
			return false
	return true
