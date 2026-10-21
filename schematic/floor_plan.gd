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
## Width, sill height and height of a window (m) when none is set.
const WINDOW_WIDTH: float = 1.2
const WINDOW_SILL: float = 0.9
const WINDOW_HEIGHT: float = 1.25
## Thickness of the outside walls (drawn outside the rooms) and of the
## walls between rooms (on their line) when none is set (m).
const OUTER_WALL: float = 0.3
const INNER_WALL: float = 0.15
## Furniture and fixtures drawn faintly on the plan, by kind: their width
## along the wall their back is against and their depth into the room (m),
## and their names (English source text).
const FIXTURES: Dictionary[String, Vector2] = {
	"worktop": Vector2(2.4, 0.6), "bath": Vector2(1.7, 0.75), "shower": Vector2(0.9, 0.9),
	"basin": Vector2(0.6, 0.45), "wc": Vector2(0.4, 0.65), "bed": Vector2(1.6, 2.0),
	"wardrobe": Vector2(1.6, 0.6), "table": Vector2(1.4, 0.8), "sofa": Vector2(2.0, 0.9),
}
const FIXTURE_NAMES: Dictionary[String, String] = {
	"worktop": "Kitchen worktop", "bath": "Bath", "shower": "Shower tray", "basin": "Washbasin",
	"wc": "WC", "bed": "Double bed", "wardrobe": "Wardrobe", "table": "Table", "sofa": "Sofa",
}
## A socket put on the wall behind a kitchen worktop is this high (m).
const WORKTOP_SOCKET_HEIGHT: float = 1.1
## A fixture dropped this close to a wall (m) goes against it.
const AGAINST_WALL: float = 0.8
## Metres a pixel of an underlay loaded (a drawing scanned at 1:50 and
## 100 dpi is about this); set from two points of a known distance.
const UNDERLAY_SCALE: float = 0.0127
## Smallest and largest size of the symbols and texts, as a part of the usual one.
const MIN_SIZE: float = 0.5
const MAX_SIZE: float = 3.0
## A new dimension this far from its wall or line (m).
const DIMENSION_OFFSET: float = 0.5
## Thinnest and thickest wall offered (m).
const MIN_WALL_THICKNESS: float = 0.05
const MAX_WALL_THICKNESS: float = 0.8
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


## An opening in a wall: its middle on the wall, its width, whether the
## wall runs up and down.
class Opening:
	var at: Vector2 = Vector2.ZERO
	var width: float = DOOR_WIDTH
	var vertical: bool = false

	## Its two ends on the wall.
	func ends() -> PackedVector2Array:
		var along: Vector2 = Vector2.DOWN if vertical else Vector2.RIGHT
		return PackedVector2Array([at - along * width * 0.5, at + along * width * 0.5])


## A door in a wall and how it swings: its hinge at the start of its
## opening (left or top) or at the end ([member hinge_end]), its leaf opening
## down from a wall running across or left of one running up and down, or
## to the other side ([member opens_back]).
class Door extends Opening:
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


## A window in a wall: its sill and its height over the floor (m).
class WindowOpening extends Opening:
	var sill: float = WINDOW_SILL
	var height: float = WINDOW_HEIGHT

	func _init(p_at: Vector2 = Vector2.ZERO, p_vertical: bool = false, p_width: float = WINDOW_WIDTH) -> void:
		at = p_at
		vertical = p_vertical
		width = p_width


## A dimension printed with the plan: a chain along wall [member wall] of
## room [member room] (its corners, the parts on it and the ends of its
## doors and windows), or, with [member room] -1, between points
## [member a] and [member b]. [member offset]: how far from the wall
## outside its room (past the outside wall), or from the line a-b to its
## left as seen from a (m).
class Dimension:
	var room: int = -1
	var wall: int = 0
	var a: Vector2 = Vector2.ZERO
	var b: Vector2 = Vector2.ZERO
	var offset: float = DIMENSION_OFFSET


## A note printed with the plan: its text (lines split by line breaks), the
## point it points to and where its text starts (m).
class Note:
	var text: String = ""
	var at: Vector2 = Vector2.ZERO
	var label: Vector2 = Vector2.ZERO


## A piece of furniture or a fixture (one of [constant FIXTURES]): the
## rectangle it covers (m) and the way it faces into the room from its back
## (an index into [constant FACING]).
class Fixture:
	var kind: String = "table"
	var rect: Rect2 = Rect2()
	var facing: int = 1

	## Its width along its back and its depth (m).
	func extent() -> Vector2:
		return Vector2(rect.size.y, rect.size.x) if facing % 2 == 0 else rect.size

	## The middle of its back.
	func back() -> Vector2:
		return rect.get_center() - FACING[facing] * extent().y * 0.5


## Which floor it is: 0 the ground floor (1.NP), 1 the one over it (2.NP),
## -1 the basement (1.PP); and its name ("" for the usual one).
var level: int = 0
var name: String = ""
## The architect's drawing traced over (an image file, "" for none): where
## its top left corner is (m), metres a pixel, whether it shows.
var underlay: String = ""
var underlay_at: Vector2 = Vector2.ZERO
var underlay_scale: float = UNDERLAY_SCALE
var underlay_shown: bool = true
## Where north is: degrees clockwise from up on the plan.
var north: float = 0.0
## The legend of the rooms moved from its place right of the plan (m).
var legend_offset: Vector2 = Vector2.ZERO
## How large the symbols and the texts are drawn, 1 as usual (on the
## plan, its sheet and its legend).
var symbol_scale: float = 1.0
var text_scale: float = 1.0
var rooms: Array[Room] = []
var doors: Array[Door] = []
var windows: Array[WindowOpening] = []
## Thickness of the outside walls and of those between rooms (m).
var outer_wall: float = OUTER_WALL
var inner_wall: float = INNER_WALL
var dimensions: Array[Dimension] = []
var notes: Array[Note] = []
var fixtures: Array[Fixture] = []
## Where each part (by designation) and the consumer unit ([constant UNIT])
## are (m).
var parts: Dictionary[String, Vector2] = {}
## Which way each part on a wall faces into its room (index into
## [constant FACING]); parts in no entry (luminaires) are on the ceiling.
var facing: Dictionary[String, int] = {}
## The lighting drawn on the plan of a residential installation.
var links: Array[Link] = []


func is_empty() -> bool:
	return rooms.is_empty() and doors.is_empty() and windows.is_empty() and parts.is_empty() and links.is_empty() and dimensions.is_empty() and notes.is_empty() and fixtures.is_empty()


## A fixture of [param kind] at [param point]: its back against the wall
## within [constant AGAINST_WALL] (in the middle there), else facing down
## with its middle there.
func fixture_at_point(kind: String, point: Vector2) -> Fixture:
	var fixture: Fixture = Fixture.new()
	fixture.kind = kind
	var size: Vector2 = FIXTURES.get(kind, Vector2.ONE)
	var wall: Dictionary = wall_near(point, AGAINST_WALL)
	fixture.facing = int(wall["facing"]) if not wall.is_empty() else 1
	var into: Vector2 = FACING[fixture.facing]
	var along: Vector2 = into.orthogonal().abs()
	var back: Vector2 = wall["at"] if not wall.is_empty() else snap(point) - into * size.y * 0.5
	if not wall.is_empty():
		# Along the wall where the point is.
		back = snap(back + along * (point - back).dot(along))
	var center: Vector2 = back + into * size.y * 0.5
	var shape: Vector2 = Vector2(size.y, size.x) if fixture.facing % 2 == 0 else size
	fixture.rect = Rect2(center - shape * 0.5, shape)
	return fixture


## Fixture [param index] moved by [param by] (m), against a wall again when
## its back comes near one facing its way.
func move_fixture(index: int, by: Vector2) -> void:
	var fixture: Fixture = fixtures[index]
	fixture.rect.position += by
	var wall: Dictionary = wall_near(fixture.back(), 0.3)
	if not wall.is_empty() and int(wall["facing"]) == fixture.facing:
		fixture.rect.position += Vector2(wall["at"]) - fixture.back() - FACING[fixture.facing].orthogonal().abs() * (Vector2(wall["at"]) - fixture.back()).dot(FACING[fixture.facing].orthogonal().abs())


## Fixture [param index] [param width] wide along its back and [param depth]
## deep (m), its back where it was.
func resize_fixture(index: int, width: float, depth: float) -> void:
	var fixture: Fixture = fixtures[index]
	var back: Vector2 = fixture.back()
	var center: Vector2 = back + FACING[fixture.facing] * depth * 0.5
	var shape: Vector2 = Vector2(depth, width) if fixture.facing % 2 == 0 else Vector2(width, depth)
	fixture.rect = Rect2(center - shape * 0.5, shape)


## Moves corner [param k] of room [param index] to [param at]: the two
## walls meeting there go along (see [method set_edge]).
func set_corner(index: int, k: int, at: Vector2) -> void:
	var room: Room = rooms[index]
	var n: int = room.points.size()
	for wall: int in [(k + n - 1) % n, k]:
		var w: PackedVector2Array = rooms[index].wall(wall)
		set_edge(index, wall, at.x if is_equal_approx(w[0].x, w[1].x) else at.y)


## Opening [param opening] with end [param which] (0 its left or top end)
## pulled to [param to] along its wall, the other end staying: its width
## kept from [param low] to [param high] (m).
static func stretch_opening(opening: Opening, which: int, to: Vector2, low: float, high: float) -> void:
	var ends: PackedVector2Array = opening.ends()
	var along: Vector2 = Vector2.DOWN if opening.vertical else Vector2.RIGHT
	var fixed: Vector2 = ends[1 - which]
	var reach: float = (to - fixed).dot(along) * (1.0 if which == 1 else -1.0)
	var width: float = clampf(snappedf(reach, SNAP), low, high)
	opening.width = width
	opening.at = fixed + along * width * 0.5 * (1.0 if which == 1 else -1.0)


## The rectangle of [param rect] with corner [param which] (0 top left,
## clockwise) pulled to [param to], the opposite one staying, at least
## [param least] (m) a side.
static func stretch_rect(rect: Rect2, which: int, to: Vector2, least: float = 0.2) -> Rect2:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var fixed: Vector2 = corners[(which + 2) % 4]
	var moved: Vector2 = snap(to)
	var a: Vector2 = Vector2(minf(fixed.x, moved.x), minf(fixed.y, moved.y))
	var size: Vector2 = (moved - fixed).abs()
	if size.x < least:
		a.x = fixed.x - least if moved.x < fixed.x else fixed.x
	if size.y < least:
		a.y = fixed.y - least if moved.y < fixed.y else fixed.y
	return Rect2(a, Vector2(maxf(size.x, least), maxf(size.y, least)))


## Fixture [param index] turned a quarter round its middle.
func turn_fixture(index: int) -> void:
	var fixture: Fixture = fixtures[index]
	var center: Vector2 = fixture.rect.get_center()
	fixture.facing = (fixture.facing + 1) % 4
	var size: Vector2 = Vector2(fixture.rect.size.y, fixture.rect.size.x)
	fixture.rect = Rect2(center - size * 0.5, size)


## Whether [param point] on a wall is behind a kitchen worktop: on the
## worktop's back.
func over_worktop(point: Vector2) -> bool:
	for fixture: Fixture in fixtures:
		if fixture.kind != "worktop":
			continue
		var along: Vector2 = FACING[fixture.facing].orthogonal().abs()
		var back: Vector2 = fixture.back()
		var off: Vector2 = point - back
		if absf(off.dot(FACING[fixture.facing])) < 0.06 and absf(off.dot(along)) <= fixture.extent().x * 0.5 + 0.001:
			return true
	return false


## The ends of dimension [param dim] (m): its wall's, or its two points.
func dimension_ends(dim: Dimension) -> PackedVector2Array:
	if dim.room >= 0 and dim.room < rooms.size() and dim.wall < rooms[dim.room].points.size():
		return rooms[dim.room].wall(dim.wall)
	return PackedVector2Array([dim.a, dim.b])


## Where dimension [param dim] is cut, as distances from its first end (m),
## in order: its ends and, along a wall, the parts on it and the ends of
## its doors and windows.
func dimension_stops(dim: Dimension) -> PackedFloat32Array:
	var ends: PackedVector2Array = dimension_ends(dim)
	var length: float = ends[0].distance_to(ends[1])
	var stops: PackedFloat32Array = PackedFloat32Array([0.0, length])
	if dim.room >= 0 and length > 0.001:
		var dir: Vector2 = (ends[1] - ends[0]) / length
		var points: Array[Vector2] = []
		for designation: String in parts:
			if facing.has(designation):
				points.append(parts[designation])
		for opening: Opening in openings():
			points.append_array(Array(opening.ends()))
		for p: Vector2 in points:
			var t: float = (p - ends[0]).dot(dir)
			if t > 0.01 and t < length - 0.01 and (ends[0] + dir * t).distance_to(p) < 0.02:
				stops.append(snappedf(t, 0.001))
	stops.sort()
	var result: PackedFloat32Array = PackedFloat32Array()
	for t: float in stops:
		if result.is_empty() or t - result[result.size() - 1] > 0.005:
			result.append(t)
	return result


## Takes room [param index] away, with the dimensions along its walls.
func remove_room(index: int) -> void:
	rooms.remove_at(index)
	_forget_room(index, -1)


## Dimensions along the walls of room [param gone] are dropped (and of
## [param also], its walls changed); the rooms after [param gone] are one
## further forward.
func _forget_room(gone: int, also: int) -> void:
	for i: int in range(dimensions.size() - 1, -1, -1):
		var dim: Dimension = dimensions[i]
		if dim.room < 0:
			continue
		if dim.room == gone or dim.room == also:
			dimensions.remove_at(i)
		elif dim.room > gone:
			dim.room -= 1


## The doors and the windows.
func openings() -> Array[Opening]:
	var list: Array[Opening] = []
	list.append_array(doors)
	list.append_array(windows)
	return list


## Whether the wall at [param point], seen from the room on the side of
## [param into], is between two rooms (another room behind it).
func inner_wall_at(point: Vector2, into: Vector2) -> bool:
	return room_at(point - into * 0.05) >= 0 and room_at(point + into * 0.05) >= 0


## The walls between rooms, each piece once: [from, to] on their line (m).
func inner_pieces() -> Array[PackedVector2Array]:
	var shapes: Array[PackedVector2Array] = []
	for room: Room in rooms:
		shapes.append(room.points)
	return inner_pieces_of(shapes)


## The walls between the rooms of outlines [param shapes] (see [method inner_pieces]).
static func inner_pieces_of(shapes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	var seen: Dictionary[String, bool] = {}
	for index: int in shapes.size():
		var points: PackedVector2Array = shapes[index]
		for k: int in points.size():
			var w0: Vector2 = points[k]
			var w1: Vector2 = points[(k + 1) % points.size()]
			var vertical: bool = is_equal_approx(w0.x, w1.x)
			var line: float = w0.x if vertical else w0.y
			var a: float = minf(w0.y, w1.y) if vertical else minf(w0.x, w1.x)
			var b: float = maxf(w0.y, w1.y) if vertical else maxf(w0.x, w1.x)
			# Cut where the other rooms' corners on this line are.
			var cuts: PackedFloat32Array = PackedFloat32Array([a, b])
			for other: PackedVector2Array in shapes:
				for p: Vector2 in other:
					var on: float = p.x if vertical else p.y
					var along: float = p.y if vertical else p.x
					if absf(on - line) < 0.001 and along > a + 0.001 and along < b - 0.001:
						cuts.append(along)
			cuts.sort()
			var out: Vector2 = -(w1 - w0).normalized().rotated(PI / 2.0).round()
			for i: int in cuts.size() - 1:
				if cuts[i + 1] - cuts[i] < 0.001:
					continue
				var mid: float = (cuts[i] + cuts[i + 1]) * 0.5
				var m: Vector2 = Vector2(line, mid) if vertical else Vector2(mid, line)
				var behind: bool = false
				for j: int in shapes.size():
					if j != index and Geometry2D.is_point_in_polygon(m + out * 0.05, shapes[j]):
						behind = true
				if not behind:
					continue
				var key: String = "%s|%.3f|%.3f|%.3f" % [vertical, line, cuts[i], cuts[i + 1]]
				if seen.has(key):
					continue
				seen[key] = true
				pieces.append(PackedVector2Array([Vector2(line, cuts[i]), Vector2(line, cuts[i + 1])] if vertical else [Vector2(cuts[i], line), Vector2(cuts[i + 1], line)]))
	return pieces


## Number of room [param index]: the one set, else counted from
## [constant FIRST_NUMBER] on the ground floor, from 201 on the next, from
## 001 in the basement.
func room_number(index: int) -> String:
	if not rooms[index].number.is_empty():
		return rooms[index].number
	return "%03d" % (FIRST_NUMBER + level * 100 + index) if level >= -1 else "%d%02d" % [level, index + 1]


## Its name as shown: the one set, else 1.NP, 2.NP ... or 1.PP, 2.PP ...
func floor_name() -> String:
	if not name.is_empty():
		return name
	return "%d.NP" % (level + 1) if level >= 0 else "%d.PP" % -level


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
## and windows in its walls.
func move_room(index: int, to: Vector2) -> void:
	var room: Room = rooms[index]
	var by: Vector2 = to - room.rect.position
	for designation: String in parts.keys():
		if room.contains(parts[designation], 0.01):
			parts[designation] += by
	for opening: Opening in openings():
		if room.contains(opening.at, 0.01):
			opening.at += by
	for note: Note in notes:
		if room.contains(note.at, 0.01):
			note.at += by
			note.label += by
	for fixture: Fixture in fixtures:
		if room.contains(fixture.rect.get_center(), 0.01):
			fixture.rect.position += by
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
## the same line along it moves along (they keep sharing it), and the parts,
## doors and windows on it move with it.
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
	for opening: Opening in openings():
		var along_door: float = opening.at.y if vertical else opening.at.x
		if absf((opening.at.x if vertical else opening.at.y) - old) < 0.01 and along_door >= span.x and along_door <= span.y:
			opening.at += Vector2(by, 0) if vertical else Vector2(0, by)
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
	_forget_room(b, a)
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


## Where a distance along the wall at [param point] is measured from: the
## nearest of the wall's corners and the ends of the doors and windows in
## it, {"from", "dir" (from there towards the point), "distance", "wall"
## ([from, to] of the wall)}; {} when no wall is there.
func wall_reference(point: Vector2) -> Dictionary:
	var best: float = 0.02
	var wall: PackedVector2Array = PackedVector2Array()
	for room: Room in rooms:
		for k: int in room.points.size():
			var w: PackedVector2Array = room.wall(k)
			var d: float = Geometry2D.get_closest_point_to_segment(point, w[0], w[1]).distance_to(point)
			if d < best:
				best = d
				wall = w
	if wall.is_empty():
		return {}
	var along: Vector2 = (wall[1] - wall[0]).normalized()
	var stops: Array[Vector2] = [wall[0], wall[1]]
	for opening: Opening in openings():
		for end: Vector2 in opening.ends():
			if Geometry2D.get_closest_point_to_segment(end, wall[0], wall[1]).distance_to(end) < 0.02:
				stops.append(end)
	var from: Vector2 = wall[0]
	for stop: Vector2 in stops:
		if stop.distance_to(point) < from.distance_to(point):
			from = stop
	var dir: Vector2 = (point - from).normalized() if point.distance_to(from) > 0.001 else along
	# Along the wall either way.
	dir = along if dir.dot(along) >= 0.0 else -along
	return {"from": from, "dir": dir, "distance": (point - from).dot(dir), "wall": wall}


## The point [param distance] (m) along the wall at [param point] from its
## reference (see [method wall_reference]), kept on the wall; [param point] when no wall is there.
func at_distance(point: Vector2, distance: float) -> Vector2:
	var ref: Dictionary = wall_reference(point)
	if ref.is_empty():
		return point
	var wall: PackedVector2Array = ref["wall"]
	var target: Vector2 = Vector2(ref["from"]) + Vector2(ref["dir"]) * maxf(distance, 0.0)
	return Geometry2D.get_closest_point_to_segment(target, wall[0], wall[1])


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


## Puts part [param designation] exactly at [param point] on a wall (not
## snapped to the grid), facing into the room there (or [param face], an
## index into [constant FACING]).
func place_on_wall(designation: String, point: Vector2, face: int = -1) -> void:
	var wall: Dictionary = wall_near(point, 0.05)
	if wall.is_empty() and face < 0:
		place(designation, point, false)
		return
	parts[designation] = point
	facing[designation] = face if face >= 0 else int(wall["facing"])


## Points spread over room [param index] in [param rows] × [param columns]
## (each in the middle of its cell of the rectangle round it, those in the
## room kept), for luminaires on its ceiling.
func grid_points(index: int, rows: int, columns: int) -> PackedVector2Array:
	var room: Room = rooms[index]
	var r: Rect2 = room.rect
	var result: PackedVector2Array = PackedVector2Array()
	for j: int in maxi(rows, 1):
		for i: int in maxi(columns, 1):
			var p: Vector2 = r.position + Vector2(r.size.x * (i + 0.5) / maxi(columns, 1), r.size.y * (j + 0.5) / maxi(rows, 1))
			if room.contains(p):
				result.append(snap(p))
	return result


## [param count] points along wall [param k] of room [param index]: spread
## evenly (each in the middle of its share) when [param spacing] is 0, else
## from [param start] (m from the wall's left or top end) every
## [param spacing], as far as the wall goes.
func row_points(index: int, k: int, count: int, start: float = 0.0, spacing: float = 0.0) -> PackedVector2Array:
	var w: PackedVector2Array = rooms[index].wall(k)
	if w[1].x < w[0].x or w[1].y < w[0].y:
		w = PackedVector2Array([w[1], w[0]])
	var length: float = w[0].distance_to(w[1])
	var dir: Vector2 = (w[1] - w[0]) / length if length > 0.0 else Vector2.RIGHT
	var result: PackedVector2Array = PackedVector2Array()
	for i: int in maxi(count, 1):
		var t: float = length * (i + 0.5) / maxi(count, 1) if spacing <= 0.0 else start + i * spacing
		if t < 0.0 or t > length + 0.001:
			break
		result.append(w[0] + dir * t)
	return result


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
		# With the outside walls round it.
		var walled: Rect2 = room.rect.grow(outer_wall)
		result = walled if first else result.merge(walled)
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
	if level != 0:
		result["level"] = level
	if not is_zero_approx(north):
		result["north"] = north
	if legend_offset != Vector2.ZERO:
		result["legend"] = [legend_offset.x, legend_offset.y]
	if not is_equal_approx(symbol_scale, 1.0) or not is_equal_approx(text_scale, 1.0):
		result["sizes"] = [symbol_scale, text_scale]
	if not name.is_empty():
		result["name"] = name
	if not underlay.is_empty():
		result["underlay"] = {"path": underlay, "at": [underlay_at.x, underlay_at.y], "scale": underlay_scale, "shown": underlay_shown}
	if not windows.is_empty():
		var window_list: Array = []
		for window: WindowOpening in windows:
			var wd: Dictionary = {"at": [window.at.x, window.at.y], "width": window.width, "vertical": window.vertical}
			if not is_equal_approx(window.sill, WINDOW_SILL):
				wd["sill"] = window.sill
			if not is_equal_approx(window.height, WINDOW_HEIGHT):
				wd["height"] = window.height
			window_list.append(wd)
		result["windows"] = window_list
	if not is_equal_approx(outer_wall, OUTER_WALL) or not is_equal_approx(inner_wall, INNER_WALL):
		result["walls"] = [outer_wall, inner_wall]
	if not notes.is_empty():
		var note_list: Array = []
		for note: Note in notes:
			note_list.append({"text": note.text, "at": [note.at.x, note.at.y], "label": [note.label.x, note.label.y]})
		result["notes"] = note_list
	if not fixtures.is_empty():
		var fixture_list: Array = []
		for fixture: Fixture in fixtures:
			fixture_list.append({"kind": fixture.kind, "rect": [fixture.rect.position.x, fixture.rect.position.y, fixture.rect.size.x, fixture.rect.size.y], "facing": fixture.facing})
		result["fixtures"] = fixture_list
	if not dimensions.is_empty():
		var dimension_list: Array = []
		for dim: Dimension in dimensions:
			if dim.room >= 0:
				dimension_list.append({"room": dim.room, "wall": dim.wall, "offset": dim.offset})
			else:
				dimension_list.append({"a": [dim.a.x, dim.a.y], "b": [dim.b.x, dim.b.y], "offset": dim.offset})
		result["dimensions"] = dimension_list
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
	var raw_level: Variant = d.get("level", 0)
	plan.level = clampi(int(raw_level), -5, 50) if (raw_level is int or raw_level is float) else 0
	plan.name = (d["name"] as String).strip_edges().left(40) if d.get("name", null) is String else ""
	plan.north = fposmod(_length(d.get("north", 0.0), 0.0, -3600.0, 3600.0), 360.0)
	if _numbers(d.get("sizes", []), 2):
		plan.symbol_scale = clampf(float(d["sizes"][0]), MIN_SIZE, MAX_SIZE)
		plan.text_scale = clampf(float(d["sizes"][1]), MIN_SIZE, MAX_SIZE)
	if _numbers(d.get("legend", []), 2):
		plan.legend_offset = Vector2(clampf(float(d["legend"][0]), -200.0, 200.0), clampf(float(d["legend"][1]), -200.0, 200.0))
	var under: Variant = d.get("underlay", null)
	if under is Dictionary and (under as Dictionary).get("path", null) is String:
		plan.underlay = under["path"]
		if _numbers(under.get("at", []), 2):
			plan.underlay_at = Vector2(float(under["at"][0]), float(under["at"][1]))
		plan.underlay_scale = _length(under.get("scale", UNDERLAY_SCALE), UNDERLAY_SCALE, 0.00001, 10.0)
		plan.underlay_shown = under.get("shown", true) != false
	var window_list: Variant = d.get("windows", [])
	if window_list is Array:
		for wd: Variant in window_list:
			if wd is Dictionary and _numbers(wd.get("at", []), 2):
				var window: WindowOpening = WindowOpening.new(Vector2(float(wd["at"][0]), float(wd["at"][1])), wd.get("vertical", false) == true, _length(wd.get("width", WINDOW_WIDTH), WINDOW_WIDTH, 0.3, 6.0))
				window.sill = _length(wd.get("sill", WINDOW_SILL), WINDOW_SILL, 0.0, 3.0)
				window.height = _length(wd.get("height", WINDOW_HEIGHT), WINDOW_HEIGHT, 0.2, 3.0)
				plan.windows.append(window)
	if _numbers(d.get("walls", []), 2):
		plan.outer_wall = clampf(float(d["walls"][0]), MIN_WALL_THICKNESS, MAX_WALL_THICKNESS)
		plan.inner_wall = clampf(float(d["walls"][1]), MIN_WALL_THICKNESS, MAX_WALL_THICKNESS)
	var note_list: Variant = d.get("notes", [])
	if note_list is Array:
		for nd: Variant in note_list:
			if nd is Dictionary and nd.get("text", null) is String and _numbers(nd.get("at", []), 2) and _numbers(nd.get("label", []), 2):
				var note: Note = Note.new()
				note.text = (nd["text"] as String).left(500)
				note.at = Vector2(float(nd["at"][0]), float(nd["at"][1]))
				note.label = Vector2(float(nd["label"][0]), float(nd["label"][1]))
				plan.notes.append(note)
	var fixture_list: Variant = d.get("fixtures", [])
	if fixture_list is Array:
		for fd: Variant in fixture_list:
			if fd is Dictionary and FIXTURES.has(str(fd.get("kind", ""))) and _numbers(fd.get("rect", []), 4):
				var fixture: Fixture = Fixture.new()
				fixture.kind = str(fd["kind"])
				var fr: Array = fd["rect"]
				fixture.rect = Rect2(float(fr[0]), float(fr[1]), clampf(float(fr[2]), 0.1, 10.0), clampf(float(fr[3]), 0.1, 10.0))
				var face: Variant = fd.get("facing", 1)
				fixture.facing = clampi(int(face), 0, 3) if (face is int or face is float) else 1
				plan.fixtures.append(fixture)
	var dimension_list: Variant = d.get("dimensions", [])
	if dimension_list is Array:
		for dd: Variant in dimension_list:
			if not (dd is Dictionary):
				continue
			var dim: Dimension = Dimension.new()
			dim.offset = _length(dd.get("offset", DIMENSION_OFFSET), DIMENSION_OFFSET, -20.0, 20.0)
			var room: Variant = dd.get("room", -1)
			var wall: Variant = dd.get("wall", 0)
			if (room is int or room is float) and (wall is int or wall is float) and int(room) >= 0 and int(room) < plan.rooms.size() and int(wall) >= 0 and int(wall) < plan.rooms[int(room)].points.size():
				dim.room = int(room)
				dim.wall = int(wall)
			elif _numbers(dd.get("a", []), 2) and _numbers(dd.get("b", []), 2):
				dim.a = Vector2(float(dd["a"][0]), float(dd["a"][1]))
				dim.b = Vector2(float(dd["b"][0]), float(dd["b"][1]))
			else:
				continue
			plan.dimensions.append(dim)
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


## [param value] as a length from [param low] to [param high], else [param fallback].
static func _length(value: Variant, fallback: float, low: float, high: float) -> float:
	return clampf(float(value), low, high) if (value is float or value is int) and is_finite(float(value)) else fallback


static func _numbers(value: Variant, count: int) -> bool:
	if not (value is Array) or (value as Array).size() < count:
		return false
	for i: int in count:
		if not (value[i] is float or value[i] is int) or not is_finite(float(value[i])):
			return false
	return true
