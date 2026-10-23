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
## illuminance for the legend; a staircase has its stairs drawn in it and
## no wall where they start. No nodes.

## Lengths snap to this (m).
const SNAP: float = 0.05
## A room's edge this close to another room's edge (m) snaps onto it: rooms
## share their walls.
const WALL_SNAP: float = 0.3
## A switch, socket or appliance dropped this close to a wall (m) goes onto it.
const ON_WALL: float = 0.5
## How far a wall part's symbol can be moved off its wall (m).
const MAX_OFFSET: float = 1.5
## Smallest room side (m).
const MIN_ROOM: float = 0.8
## Width of a door (m) when none is set.
const DOOR_WIDTH: float = 0.8
## How narrow and how wide a door can be (m; garage doors the widest).
const DOOR_MIN_WIDTH: float = 0.5
const DOOR_MAX_WIDTH: float = 5.0
## Kinds of door: hinged swinging one way, swinging both ways, sliding along
## the wall, sliding into the wall (a pocket door), folding, and a sectional
## garage door going up under the ceiling.
enum DoorKind { SWING, DOUBLE_ACTING, SLIDING, POCKET, FOLDING, GARAGE }
## How each [enum DoorKind] is saved.
const DOOR_KINDS: PackedStringArray = ["swing", "double_acting", "sliding", "pocket", "folding", "garage"]
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
## Where a wall between two rooms lies on their line: the program's choice
## (centred, or out of the way of the room whose wall goes on outside), on
## the line's middle, into the room it is set on, into the other room.
enum Align { AUTO, CENTRE, INTO_THIS, INTO_OTHER }
## Thickness of the walls of new plans (the outside ones and those between
## rooms; the user's default, set from the plan settings).
static var default_outer: float = OUTER_WALL
static var default_inner: float = INNER_WALL
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
## The going of a stair's tread (m), and how far from its ends the walking
## line starts and stops.
const TREAD: float = 0.28
const WALK_END: float = 0.25
## A layer's name is at most this long.
const MAX_LAYER_NAME: int = 40
## The layer every dimension and note is on, always: the program's own,
## never renamed nor taken away, nothing else put on it (shown or hidden by
## [member SchematicDocument.annotations_shown]; its name shown translated).
const ANNOTATIONS: String = "dimensions_and_notes"


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
	## A staircase: its stairs drawn in it (straight in a rectangle, turning
	## in an L), going up the other way with [member stairs_reverse].
	var stairs: bool = false
	var stairs_reverse: bool = false
	## Each wall's own thickness (m; 0 or missing: the plan's) and where it
	## lies between two rooms ([enum FloorPlan.Align]), by wall index.
	var thickness: PackedFloat32Array = PackedFloat32Array()
	var align: PackedInt32Array = PackedInt32Array()
	## Its walls taken away (by index): open there, no wall drawn.
	var open: PackedInt32Array = PackedInt32Array()

	## Whether wall [param k] was taken away (open, no wall there).
	func is_open(k: int) -> bool:
		return open.has(k)

	## Takes wall [param k] away ([param value] true) or puts it back.
	func set_open(k: int, value: bool) -> void:
		if value and not open.has(k):
			open.append(k)
		elif not value and open.has(k):
			open.remove_at(open.find(k))

	## Wall [param k]'s own thickness, 0 for the plan's.
	func wall_thickness(k: int) -> float:
		return thickness[k] if k < thickness.size() else 0.0

	## Where wall [param k] lies between two rooms ([enum FloorPlan.Align]).
	func wall_align(k: int) -> int:
		return align[k] if k < align.size() else 0

	## Gives wall [param k] its own [param value] thickness (0: the plan's).
	func set_wall_thickness(k: int, value: float) -> void:
		while thickness.size() < points.size():
			thickness.append(0.0)
		thickness[k] = value

	func set_wall_align(k: int, value: int) -> void:
		while align.size() < points.size():
			align.append(0)
		align[k] = value
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
		if points.size() != 4:
			return false
		for k: int in 4:
			if not FloorPlan.is_straight(wall(k)):
				return false
		return true

	## Whether every wall runs across or up and down.
	func is_square() -> bool:
		for k: int in points.size():
			if not FloorPlan.is_straight(wall(k)):
				return false
		return true

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

	## The way into the room from wall [param k]: right of it as drawn (a
	## wall across or up and down: exactly along an axis).
	func inward(k: int) -> Vector2:
		var w: PackedVector2Array = wall(k)
		var turned: Vector2 = (w[1] - w[0]).normalized().rotated(PI / 2.0)
		return turned.round() if is_equal_approx(w[0].x, w[1].x) or is_equal_approx(w[0].y, w[1].y) else turned


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
	## Its [enum DoorKind].
	var kind: int = DoorKind.SWING
	## Hinged (or sliding, folding away) at its end rather than its start.
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
	## The layer it is on: always [constant ANNOTATIONS].
	var layer: String = ANNOTATIONS


## A note printed with the plan: its text (lines split by line breaks), the
## point it points to and where its text starts (m).
## A wall drawn on its own (not yet round a room): its line from [member a]
## to [member b] and its thickness (m; 0: the plan's walls between rooms),
## lying on the middle of its line. Walls closing round a space become a
## room (see [method add_wall]).
class Wall:
	var a: Vector2 = Vector2.ZERO
	var b: Vector2 = Vector2.ZERO
	var thickness: float = 0.0

	func _init(p_a: Vector2 = Vector2.ZERO, p_b: Vector2 = Vector2.ZERO, p_thickness: float = 0.0) -> void:
		a = p_a
		b = p_b
		thickness = p_thickness


class Note:
	var text: String = ""
	var at: Vector2 = Vector2.ZERO
	var label: Vector2 = Vector2.ZERO
	## The layer it is on: always [constant ANNOTATIONS].
	var layer: String = ANNOTATIONS


## A piece of furniture or a fixture (one of [constant FIXTURES]): the
## rectangle it covers (m) and the way it faces into the room from its back
## (an index into [constant FACING]).
class Fixture:
	var kind: String = "table"
	var rect: Rect2 = Rect2()
	var facing: int = 1
	var layer: String = ""

	## Its width along its back and its depth (m).
	func extent() -> Vector2:
		return Vector2(rect.size.y, rect.size.x) if facing % 2 == 0 else rect.size

	## The middle of its back.
	func back() -> Vector2:
		return rect.get_center() - FACING[facing] * extent().y * 0.5


## A drawing-only symbol of the user's own ([CustomSymbol], by its id) on
## the plan: where its origin is (m) and, on a wall, the way it faces into
## the room (an index into [constant FACING]; -1 on the ceiling or the floor).
class Mark:
	var symbol: String = ""
	var at: Vector2 = Vector2.ZERO
	var facing: int = -1
	var layer: String = ""


## A layer of the floor plans of a schematic (its name), drawn or hidden on
## the screen and on the sheets. Parts, notes, dimensions, furniture and
## marks may be on one; the building, the consumer unit and what is on no
## layer are always drawn.
class Layer:
	var name: String = ""
	var shown: bool = true

	func _init(p_name: String = "", p_shown: bool = true) -> void:
		name = p_name
		shown = p_shown


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
## Walls drawn on their own, not round a room yet.
var walls: Array[Wall] = []
var doors: Array[Door] = []
var windows: Array[WindowOpening] = []
## Thickness of the outside walls and of those between rooms (m).
var outer_wall: float = default_outer
var inner_wall: float = default_inner
var dimensions: Array[Dimension] = []
var notes: Array[Note] = []
var fixtures: Array[Fixture] = []
var marks: Array[Mark] = []
## Where each part (by designation) and the consumer unit ([constant UNIT])
## are (m).
var parts: Dictionary[String, Vector2] = {}
## Which way each part on a wall faces into its room (index into
## [constant FACING]); parts in no entry (luminaires) are on the ceiling.
var facing: Dictionary[String, int] = {}
## How far each part on a wall has its symbol moved off the wall into the
## room (m), so that it does not cover the wall; parts in no entry are drawn
## on their wall.
var offsets: Dictionary[String, float] = {}
## The layer each part is on (by designation); parts in no entry are on none.
var part_layers: Dictionary[String, String] = {}
## The lighting drawn on the plan of a residential installation.
var links: Array[Link] = []


func is_empty() -> bool:
	return rooms.is_empty() and walls.is_empty() and doors.is_empty() and windows.is_empty() and parts.is_empty() and links.is_empty() and dimensions.is_empty() and notes.is_empty() and fixtures.is_empty() and marks.is_empty()


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


## A mark of symbol [param id] at [param point]: onto the nearest wall within
## [constant ON_WALL] facing into the room when [param on_wall] (where the
## point is when there is none), else there, snapped.
func mark_at_point(id: String, point: Vector2, on_wall: bool) -> Mark:
	var mark: Mark = Mark.new()
	mark.symbol = id
	mark.at = snap(point)
	if on_wall:
		var wall: Dictionary = wall_near(point)
		if not wall.is_empty():
			mark.at = wall["at"]
			mark.facing = int(wall["facing"])
	return mark


## Mark [param index] moved to [param to]: onto the nearest wall if it is on one.
func move_mark(index: int, to: Vector2) -> void:
	var mark: Mark = marks[index]
	var moved: Mark = mark_at_point(mark.symbol, to, mark.facing >= 0)
	mark.at = moved.at
	mark.facing = moved.facing if moved.facing >= 0 else mark.facing


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


## Moves corner [param k] of room [param index] to [param at], with the
## same corner of every room sharing it (their walls keep meeting there).
## A corner where the walls round the rooms go straight through (the end of
## a wall between two rooms on an outside wall, or one ending on another
## room's wall) slides along that wall only, never past its ends. Walls
## across or up and down stay so (they move as with [method set_edge]),
## unless [param free] or one of them slants: then the corner goes where it
## is put, the walls meeting there slanting. Refused (false) where a room
## would cross itself, turn round or have a wall shorter than
## [constant MIN_WALL].
func set_corner(index: int, k: int, at: Vector2, free: bool = false) -> bool:
	var point: Vector2 = rooms[index].points[k]
	var group: Array[Vector2i] = corners_at(point)
	var line: PackedVector2Array = corner_line(point)
	if not line.is_empty():
		at = _on_line(at, line)
	var straight: bool = not free
	for c: Vector2i in group:
		var n: int = rooms[c.x].points.size()
		if not is_straight(rooms[c.x].wall((c.y + n - 1) % n)) or not is_straight(rooms[c.x].wall(c.y)):
			straight = false
	if straight:
		# Each wall meeting there moved across (with the walls on its line).
		var before: Array[PackedVector2Array] = _outlines()
		for c: Vector2i in group:
			var n: int = rooms[c.x].points.size()
			for wall: int in [(c.y + n - 1) % n, c.y]:
				var w: PackedVector2Array = rooms[c.x].wall(wall)
				if Geometry2D.get_closest_point_to_segment(point, w[0], w[1]).distance_to(point) < 0.01:
					set_edge(c.x, wall, at.x if is_equal_approx(w[0].x, w[1].x) else at.y)
		return _outlines() != before
	return _move_corners(group, at)


## The corners of the rooms at [param point]: Vector2i(room, corner) each.
func corners_at(point: Vector2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i: int in rooms.size():
		for j: int in rooms[i].points.size():
			if rooms[i].points[j].distance_to(point) < 0.01:
				result.append(Vector2i(i, j))
	return result


## The wall a corner at [param point] slides along: [its far end, the
## other]; empty when it can go anywhere. That is where the walls round the
## rooms meeting there (not walls between two of them) go straight through
## it, or where it is on another room's wall (not at its end).
func corner_line(point: Vector2) -> PackedVector2Array:
	var group: Array[Vector2i] = corners_at(point)
	var mine: Dictionary[int, bool] = {}
	for c: Vector2i in group:
		mine[c.x] = true
	for i: int in rooms.size():
		if mine.has(i):
			continue
		for k: int in rooms[i].points.size():
			var w: PackedVector2Array = rooms[i].wall(k)
			if w[0].distance_to(point) > 0.01 and w[1].distance_to(point) > 0.01 and Geometry2D.get_closest_point_to_segment(point, w[0], w[1]).distance_to(point) < 0.01:
				return w
	if mine.size() < 2:
		return PackedVector2Array()
	var far: PackedVector2Array = PackedVector2Array()
	for c: Vector2i in group:
		var n: int = rooms[c.x].points.size()
		for wall: int in [(c.y + n - 1) % n, c.y]:
			if not _shared_wall(c.x, wall):
				var w: PackedVector2Array = rooms[c.x].wall(wall)
				far.append(w[1] if w[0].distance_to(point) < 0.01 else w[0])
	if far.size() == 2 and (far[0] - point).normalized().dot((far[1] - point).normalized()) < -0.999:
		return far
	return PackedVector2Array()


## Whether wall [param k] of room [param index] is shared: another room has
## a wall on its line along a stretch of it.
func _shared_wall(index: int, k: int) -> bool:
	var w: PackedVector2Array = rooms[index].wall(k)
	var length: float = w[0].distance_to(w[1])
	if length < 0.001:
		return false
	var dir: Vector2 = (w[1] - w[0]) / length
	for i: int in rooms.size():
		if i == index:
			continue
		for j: int in rooms[i].points.size():
			var o: PackedVector2Array = rooms[i].wall(j)
			if absf((o[0] - w[0]).cross(dir)) > 0.002 or absf((o[1] - w[0]).cross(dir)) > 0.002:
				continue
			var t0: float = (o[0] - w[0]).dot(dir)
			var t1: float = (o[1] - w[0]).dot(dir)
			if minf(maxf(t0, t1), length) - maxf(minf(t0, t1), 0.0) > 0.001:
				return true
	return false


## [param at] put onto wall [param line] ([its ends]), at least
## [constant MIN_WALL] from either end.
static func _on_line(at: Vector2, line: PackedVector2Array) -> Vector2:
	var length: float = line[0].distance_to(line[1])
	var dir: Vector2 = (line[1] - line[0]) / length
	var t: float = clampf((at - line[0]).dot(dir), MIN_WALL, length - MIN_WALL)
	return (line[0] + dir * t).snappedf(0.001)


## Every room's outline (to tell whether an edit changed one).
func _outlines() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for room: Room in rooms:
		result.append(room.points.duplicate())
	return result


## Corners [param group] (Vector2i(room, corner)) moved to [param at]
## together, the parts on their walls along; refused (false, nothing
## changed) where a room would cross itself, turn round or have a wall
## shorter than [constant MIN_WALL].
func _move_corners(group: Array[Vector2i], at: Vector2) -> bool:
	var shapes: Dictionary[int, PackedVector2Array] = {}
	for c: Vector2i in group:
		var points: PackedVector2Array = shapes.get(c.x, rooms[c.x].points)
		var moved: PackedVector2Array = with_corner(points, c.y, at)
		if moved.is_empty() or polygon_area(_clockwise(moved)) < MIN_ROOM * MIN_ROOM * 0.5 or _clockwise(moved) != moved:
			return false
		shapes[c.x] = moved
	# Each wall that moves (a wall two rooms share once): [before, after].
	var walls_moved: Array[PackedVector2Array] = []
	for c: Vector2i in group:
		var n: int = rooms[c.x].points.size()
		for wall: int in [(c.y + n - 1) % n, c.y]:
			var old: PackedVector2Array = rooms[c.x].wall(wall)
			var seen: bool = false
			for i: int in range(0, walls_moved.size(), 2):
				var other: PackedVector2Array = walls_moved[i]
				if (other[0].distance_to(old[0]) < 0.01 and other[1].distance_to(old[1]) < 0.01) or (other[0].distance_to(old[1]) < 0.01 and other[1].distance_to(old[0]) < 0.01):
					seen = true
			if not seen:
				walls_moved.append(old)
				walls_moved.append(PackedVector2Array([shapes[c.x][wall], shapes[c.x][(wall + 1) % n]]))
	# What is on a wall that moves keeps its share of the way along it.
	for i: int in range(0, walls_moved.size(), 2):
		var old: PackedVector2Array = walls_moved[i]
		var now: PackedVector2Array = walls_moved[i + 1]
		var length: float = old[0].distance_to(old[1])
		if length < 0.001:
			continue
		for designation: String in parts.keys():
			if facing.has(designation) and Geometry2D.get_closest_point_to_segment(parts[designation], old[0], old[1]).distance_to(parts[designation]) < 0.01:
				var t: float = old[0].distance_to(parts[designation]) / length
				parts[designation] = (now[0].lerp(now[1], t)).snappedf(0.001)
		for mark: Mark in marks:
			if mark.facing >= 0 and Geometry2D.get_closest_point_to_segment(mark.at, old[0], old[1]).distance_to(mark.at) < 0.01:
				mark.at = now[0].lerp(now[1], old[0].distance_to(mark.at) / length)
		if is_straight(now) and is_equal_approx(old[0].x, old[1].x) == is_equal_approx(now[0].x, now[1].x):
			for opening: Opening in openings():
				if Geometry2D.get_closest_point_to_segment(opening.at, old[0], old[1]).distance_to(opening.at) < 0.01:
					opening.at = (now[0].lerp(now[1], old[0].distance_to(opening.at) / length)).snappedf(0.001)
	for index: int in shapes:
		rooms[index].points = shapes[index]
	return true


## A copy of the rooms alone (no parts, doors or anything else on the
## plan), to try an edit of their shapes on.
func rooms_copy() -> FloorPlan:
	var copy: FloorPlan = FloorPlan.new()
	copy.outer_wall = outer_wall
	copy.inner_wall = inner_wall
	for room: Room in rooms:
		var twin: Room = Room.new(room.name)
		twin.points = room.points.duplicate()
		twin.thickness = room.thickness.duplicate()
		twin.align = room.align.duplicate()
		copy.rooms.append(twin)
	return copy


## Moves slanting wall [param k] of room [param index] [param by] m out of
## the room (into it when negative), keeping its direction, with the walls
## of other rooms on its line along it: the walls beside each slide along
## their own lines to meet it. Refused (false) where a room would cross
## itself, turn round or have a wall shorter than [constant MIN_WALL].
func move_wall(index: int, k: int, by: float) -> bool:
	var w: PackedVector2Array = rooms[index].wall(k)
	var length: float = w[0].distance_to(w[1])
	if length < 0.001 or is_zero_approx(by):
		return false
	var dir: Vector2 = (w[1] - w[0]) / length
	var out: Vector2 = -dir.rotated(PI / 2.0)
	var shift: Vector2 = out * by
	var shapes: Dictionary[int, PackedVector2Array] = {}
	for i: int in rooms.size():
		var points: PackedVector2Array = rooms[i].points
		var n: int = points.size()
		for j: int in n:
			var o: PackedVector2Array = rooms[i].wall(j)
			if absf((o[0] - w[0]).cross(dir)) > 0.002 or absf((o[1] - w[0]).cross(dir)) > 0.002:
				continue
			var t0: float = (o[0] - w[0]).dot(dir)
			var t1: float = (o[1] - w[0]).dot(dir)
			if (i == index and j != k) or (i != index and minf(maxf(t0, t1), length) - maxf(minf(t0, t1), 0.0) <= 0.001):
				continue
			var moved: PackedVector2Array = shapes.get(i, points).duplicate()
			var before: Vector2 = points[(j + n - 1) % n]
			var after: Vector2 = points[(j + 2) % n]
			var hit0: Variant = Geometry2D.line_intersects_line(o[0] + shift, dir, before, o[0] - before)
			var hit1: Variant = Geometry2D.line_intersects_line(o[1] + shift, dir, after, o[1] - after)
			moved[j] = (hit0 as Vector2).snappedf(0.001) if hit0 != null else o[0] + shift
			moved[(j + 1) % n] = (hit1 as Vector2).snappedf(0.001) if hit1 != null else o[1] + shift
			shapes[i] = moved
	for i: int in shapes:
		var moved: PackedVector2Array = shapes[i]
		if not _simple(moved) or _clockwise(moved) != moved or polygon_area(moved) < MIN_ROOM * MIN_ROOM * 0.5:
			return false
		for j: int in moved.size():
			if moved[j].distance_to(moved[(j + 1) % moved.size()]) < MIN_WALL:
				return false
	for designation: String in parts.keys():
		if facing.has(designation) and Geometry2D.get_closest_point_to_segment(parts[designation], w[0], w[1]).distance_to(parts[designation]) < 0.01:
			parts[designation] += shift
	for mark: Mark in marks:
		if mark.facing >= 0 and Geometry2D.get_closest_point_to_segment(mark.at, w[0], w[1]).distance_to(mark.at) < 0.01:
			mark.at += shift
	for i: int in shapes:
		rooms[i].points = shapes[i]
	return true


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


## Takes room [param index] away, with the dimensions along its walls and
## the doors and windows in them.
func remove_room(index: int) -> void:
	var outline: PackedVector2Array = rooms[index].points
	for list: Array in [doors, windows]:
		for j: int in range(list.size() - 1, -1, -1):
			if wall_through(outline, (list[j] as Opening).at) >= 0:
				list.remove_at(j)
	rooms.remove_at(index)
	_forget_room(index, -1)


## The room on the other side of wall [param k] of room [param index] (a
## wall of it on the same line along a stretch of it), -1 for none.
func room_behind(index: int, k: int) -> int:
	var w: PackedVector2Array = rooms[index].wall(k)
	var length: float = w[0].distance_to(w[1])
	if length < 0.001:
		return -1
	var dir: Vector2 = (w[1] - w[0]) / length
	for i: int in rooms.size():
		if i == index:
			continue
		for j: int in rooms[i].points.size():
			var o: PackedVector2Array = rooms[i].wall(j)
			if absf((o[0] - w[0]).cross(dir)) > 0.002 or absf((o[1] - w[0]).cross(dir)) > 0.002:
				continue
			var t0: float = (o[0] - w[0]).dot(dir)
			var t1: float = (o[1] - w[0]).dot(dir)
			if minf(maxf(t0, t1), length) - maxf(minf(t0, t1), 0.0) > 0.01:
				return i
	return -1


## Takes wall [param k] of room [param index] away, with the doors and
## windows in it: a wall between it and another room joins the two (room
## [param index] keeping its name, see [method join_rooms]); an outside
## wall leaves the room open there (no wall drawn; [method Room.set_open]
## puts it back). Returns whether anything changed.
func remove_room_wall(index: int, k: int) -> bool:
	var w: PackedVector2Array = rooms[index].wall(k)
	var behind: int = room_behind(index, k)
	if behind >= 0:
		if not join_rooms(index, behind):
			return false
	else:
		rooms[index].set_open(k, true)
	for list: Array in [doors, windows]:
		for j: int in range(list.size() - 1, -1, -1):
			var at: Vector2 = (list[j] as Opening).at
			if Geometry2D.get_closest_point_to_segment(at, w[0], w[1]).distance_to(at) < 0.02:
				list.remove_at(j)
	return true


## Adds room [param room] where it is put: a room it is put into or over
## gives up what it covers, so that they share walls and never overlap.
## A room it cuts in two becomes two (the larger keeps all it had, the
## other its name); one it lies wholly inside is cut across through it, up
## and down, into two so; one it covers wholly goes. Returns the new room's
## index.
func put_room(room: Room) -> int:
	var gone: Array[int] = []
	var more: Array[Room] = []
	for i: int in rooms.size():
		var other: Room = rooms[i]
		if not other.rect.intersects(room.rect):
			continue
		var covered: float = 0.0
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(other.points, room.points):
			covered += polygon_area(piece)
		if covered < 0.01:
			continue
		var rest: Array[PackedVector2Array] = _outside_of(other.points, room.points)
		if rest.is_empty():
			gone.append(i)
			continue
		rest.sort_custom(func(a: PackedVector2Array, b: PackedVector2Array) -> bool: return polygon_area(a) > polygon_area(b))
		var kept: Room = Room.new()
		kept.points = rest[0]
		_carry_wall_looks(other, kept)
		other.points = kept.points
		other.thickness = kept.thickness
		other.align = kept.align
		other.open = kept.open
		other.label_offset = Vector2.ZERO
		for d: int in range(dimensions.size() - 1, -1, -1):
			if dimensions[d].room == i:
				dimensions.remove_at(d)
		for k: int in range(1, rest.size()):
			var piece_room: Room = Room.new(other.name)
			piece_room.points = rest[k]
			_carry_wall_looks(other, piece_room)
			more.append(piece_room)
	for k: int in range(gone.size() - 1, -1, -1):
		rooms.remove_at(gone[k])
		_forget_room(gone[k], -1)
	rooms.append_array(more)
	rooms.append(room)
	return rooms.size() - 1


## What of outline [param a] lies outside outline [param b]: its pieces,
## clockwise, none smaller than half [constant MIN_ROOM] squared; where
## [param b] lies wholly inside [param a], cut across through it up and
## down first (an outline has no hole).
static func _outside_of(a: PackedVector2Array, b: PackedVector2Array) -> Array[PackedVector2Array]:
	var clipped: Array[PackedVector2Array] = Geometry2D.clip_polygons(a, b)
	var holes: bool = clipped.size() > 1 and clipped.any(func(p: PackedVector2Array) -> bool: return Geometry2D.is_polygon_clockwise(p))
	if holes:
		var box: Rect2 = Rect2(b[0], Vector2.ZERO)
		for p: Vector2 in b:
			box = box.expand(p)
		var x: float = box.get_center().x
		var far: float = 1000.0
		clipped = []
		for half: PackedVector2Array in [PackedVector2Array([Vector2(-far, -far), Vector2(x, -far), Vector2(x, far), Vector2(-far, far)]), PackedVector2Array([Vector2(x, -far), Vector2(far, -far), Vector2(far, far), Vector2(x, far)])]:
			for side: PackedVector2Array in Geometry2D.intersect_polygons(a, half):
				clipped.append_array(Geometry2D.clip_polygons(side, b))
	var result: Array[PackedVector2Array] = []
	for piece: PackedVector2Array in clipped:
		var snapped_piece: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in piece:
			snapped_piece.append(p.snappedf(0.001))
		var outline: PackedVector2Array = _clockwise(_without_straight_on(_without_repeats(snapped_piece)))
		if outline.size() >= 3 and polygon_area(outline) >= MIN_ROOM * MIN_ROOM * 0.5:
			result.append(outline)
	return result


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


## Whether wall [param w] ([from, to]) runs across or up and down (not slanting).
static func is_straight(w: PackedVector2Array) -> bool:
	return absf(w[0].x - w[1].x) < 0.0005 or absf(w[0].y - w[1].y) < 0.0005


## The walls of the plan piece by piece, where they lie: every wall of every
## room cut where another room's corner is on its line, each piece {"room",
## "wall" (its index in the room), "a", "b" (its ends, clockwise for its
## room), "out" (the way out of its room), "from", "to" (where its band
## lies across the line, along "out", m), "other" (the room behind it, -1
## for none: an outside wall), "other_wall"}. An outside wall lies outside
## its room, as thick as set ([member Room.thickness], else
## [member outer_wall]); a wall between two rooms is listed once, as thick
## as the thicker set on either side (else [member inner_wall]), where its
## [enum Align] puts it: by itself centred, but out of the way of a room
## whose wall goes on outside (the longer way, when both do: so that room's
## face runs straight through).
## With [param shown] the rooms' outlines as drawn (being dragged), else
## their own.
func wall_pieces(shown: Array[PackedVector2Array] = []) -> Array[Dictionary]:
	var shapes: Array[PackedVector2Array] = shown
	if shapes.size() != rooms.size():
		shapes = []
		for room: Room in rooms:
			shapes.append(room.points)
	var raw: Array[Dictionary] = []
	# How long the outside pieces of a wall are, by "room|wall".
	var outside: Dictionary[String, float] = {}
	for index: int in rooms.size():
		var points: PackedVector2Array = shapes[index]
		for k: int in points.size():
			var a: Vector2 = points[k]
			var b: Vector2 = points[(k + 1) % points.size()]
			var length: float = a.distance_to(b)
			if length < 0.001:
				continue
			var dir: Vector2 = (b - a) / length
			var out: Vector2 = -dir.rotated(PI / 2.0)
			if is_equal_approx(a.x, b.x) or is_equal_approx(a.y, b.y):
				out = out.round()
			var cuts: PackedFloat32Array = PackedFloat32Array([0.0, length])
			for other: PackedVector2Array in shapes:
				for p: Vector2 in other:
					var t: float = (p - a).dot(dir)
					if t > 0.001 and t < length - 0.001 and absf((p - a).cross(dir)) < 0.001:
						cuts.append(t)
			cuts.sort()
			for i: int in cuts.size() - 1:
				if cuts[i + 1] - cuts[i] < 0.001:
					continue
				var m: Vector2 = a + dir * (cuts[i] + cuts[i + 1]) * 0.5
				var behind: int = -1
				for j: int in shapes.size():
					if j != index and Geometry2D.is_point_in_polygon(m + out * 0.05, shapes[j]):
						behind = j
				raw.append({"room": index, "wall": k, "a": a + dir * cuts[i], "b": a + dir * cuts[i + 1], "out": out, "other": behind})
				if behind < 0:
					var key: String = "%d|%d" % [index, k]
					outside[key] = outside.get(key, 0.0) + cuts[i + 1] - cuts[i]
	# Where a staircase starts there is no wall.
	var open: PackedInt32Array = PackedInt32Array()
	for index: int in rooms.size():
		open.append(stair_start_wall(shapes[index], rooms[index].stairs_reverse) if rooms[index].stairs else -1)
	var pieces: Array[Dictionary] = []
	for piece: Dictionary in raw:
		var index: int = piece["room"]
		var k: int = piece["wall"]
		var room: Room = rooms[index]
		var other: int = piece["other"]
		if open[index] == k or room.is_open(k):
			continue
		if other >= 0 and (open[other] == _wall_through(shapes[other], (Vector2(piece["a"]) + Vector2(piece["b"])) * 0.5) or rooms[other].is_open(_wall_through(shapes[other], (Vector2(piece["a"]) + Vector2(piece["b"])) * 0.5))):
			continue
		if other < 0:
			var t: float = room.wall_thickness(k)
			piece["from"] = 0.0
			piece["to"] = t if t > 0.0 else outer_wall
			piece["other_wall"] = -1
			pieces.append(piece)
			continue
		if other < index:
			continue
		var m: Vector2 = (Vector2(piece["a"]) + Vector2(piece["b"])) * 0.5
		var j: int = _wall_through(shapes[other], m)
		piece["other_wall"] = j
		var thick: float = maxf(room.wall_thickness(k), rooms[other].wall_thickness(j) if j >= 0 else 0.0)
		if thick <= 0.0:
			thick = inner_wall
		# Into room "room" is along -out.
		var mode: int = room.wall_align(k)
		if mode == Align.AUTO and j >= 0:
			mode = [Align.AUTO, Align.CENTRE, Align.INTO_OTHER, Align.INTO_THIS][rooms[other].wall_align(j)]
		if mode == Align.AUTO:
			# Out of the way of the room whose wall goes on outside the
			# longer way.
			var mine: float = outside.get("%d|%d" % [index, k], 0.0)
			var theirs: float = outside.get("%d|%d" % [other, j], 0.0) if j >= 0 else 0.0
			mode = Align.CENTRE if mine == 0.0 and theirs == 0.0 else Align.INTO_OTHER if mine >= theirs else Align.INTO_THIS
		match mode:
			Align.INTO_OTHER:
				piece["from"] = 0.0
				piece["to"] = thick
			Align.INTO_THIS:
				piece["from"] = -thick
				piece["to"] = 0.0
			_:
				piece["from"] = -thick * 0.5
				piece["to"] = thick * 0.5
		pieces.append(piece)
	return pieces


## Whether outline [param points] has a corner at [param point] of more
## than a right angle (and less than a straight one) inside it.
static func obtuse_corner(points: PackedVector2Array, point: Vector2) -> bool:
	var n: int = points.size()
	for k: int in n:
		if points[k].distance_to(point) > 0.002:
			continue
		var u: Vector2 = (points[(k + n - 1) % n] - point).normalized()
		var v: Vector2 = (points[(k + 1) % n] - point).normalized()
		return u.dot(v) < -0.001 and u.dot(v) > -0.999 and Geometry2D.is_point_in_polygon(point + (u + v).normalized() * 0.01, points)
	return false


## The wall of outline [param points] point [param point] is on, -1 for none.
static func _wall_through(points: PackedVector2Array, point: Vector2) -> int:
	for k: int in points.size():
		if Geometry2D.get_closest_point_to_segment(point, points[k], points[(k + 1) % points.size()]).distance_to(point) < 0.002:
			return k
	return -1


## The piece of wall (see [method wall_pieces]) point [param point] is on,
## {} for none.
func wall_piece_at(point: Vector2) -> Dictionary:
	for piece: Dictionary in wall_pieces():
		if Geometry2D.get_closest_point_to_segment(point, piece["a"], piece["b"]).distance_to(point) < 0.01:
			return piece
	return {}


## How far the wall at [param point] reaches into the room on the side of
## [param into] (m): where a part on it is drawn from.
func wall_face(point: Vector2, into: Vector2) -> float:
	var piece: Dictionary = wall_piece_at(point)
	if piece.is_empty():
		return 0.0
	var along_out: float = -into.dot(piece["out"])
	# The band [from, to] along "out" of its room; the room on our side is
	# the one "into" points into.
	if along_out > 0.0:
		return maxf(0.0, -float(piece["from"]))
	return maxf(0.0, float(piece["to"]))


## Thickness of free wall [param wall] (m).
func free_thickness(wall: Wall) -> float:
	return wall.thickness if wall.thickness > 0.0 else inner_wall


## The outlines the free walls are drawn with, by index ([param shown]:
## their ends as drawn, being dragged; else their own). Each is its band,
## its ends joined to what they are on: an end shared with one other free
## wall mitred with it, an end on a room's wall cut along that wall in the
## middle of its band, any other end square half its thickness past it.
func free_wall_outlines(shown: Array[PackedVector2Array] = []) -> Array[PackedVector2Array]:
	var ends: Array[PackedVector2Array] = shown
	if ends.size() != walls.size():
		ends = []
		for wall: Wall in walls:
			ends.append(PackedVector2Array([wall.a, wall.b]))
	var pieces: Array[Dictionary] = []
	if not walls.is_empty():
		pieces = wall_pieces()
	var result: Array[PackedVector2Array] = []
	for i: int in walls.size():
		var a: Vector2 = ends[i][0]
		var b: Vector2 = ends[i][1]
		var half: float = free_thickness(walls[i]) * 0.5
		if a.distance_to(b) < 0.001:
			result.append(PackedVector2Array())
			continue
		var dir: Vector2 = (b - a).normalized()
		var side: Vector2 = dir.orthogonal() * half
		# Each end's corners on the side of +side and of -side.
		var start: PackedVector2Array = _free_wall_end(i, a, dir, half, ends, pieces)
		var finish: PackedVector2Array = _free_wall_end(i, b, -dir, half, ends, pieces)
		var outline: PackedVector2Array = PackedVector2Array([start[1], finish[0], finish[1], start[0]])
		if Geometry2D.triangulate_polygon(outline).is_empty():
			outline = PackedVector2Array([a - dir * half - side, b + dir * half - side, b + dir * half + side, a - dir * half + side])
		result.append(outline)
	return result


## The corners of free wall [param index]'s band at its end [param end],
## the wall going on from it along [param away], [param half] its half
## thickness: [the corner on the side of away.orthogonal(), the other].
func _free_wall_end(index: int, end: Vector2, away: Vector2, half: float, ends: Array[PackedVector2Array], pieces: Array[Dictionary]) -> PackedVector2Array:
	var normal: Vector2 = away.orthogonal()
	var square: PackedVector2Array = PackedVector2Array([end + normal * half - away * half, end - normal * half - away * half])
	# Another free wall from this end: mitred with it.
	var joined: Array[int] = []
	for j: int in ends.size():
		if j != index and (ends[j][0].distance_to(end) < 0.01 or ends[j][1].distance_to(end) < 0.01):
			joined.append(j)
	if joined.size() == 1:
		var j: int = joined[0]
		var other: Vector2 = ends[j][1] if ends[j][0].distance_to(end) < 0.01 else ends[j][0]
		if other.distance_to(end) < 0.001:
			return square
		var their_away: Vector2 = (other - end).normalized()
		var their_half: float = free_thickness(walls[j]) * 0.5
		var corners: PackedVector2Array = PackedVector2Array()
		for sign: float in [1.0, -1.0]:
			# This wall's side goes on as the other side of the other wall.
			var hit: Variant = Geometry2D.line_intersects_line(end + normal * half * sign, away, end - their_away.orthogonal() * their_half * sign, their_away)
			var corner: Vector2 = hit if hit != null else end + normal * half * sign
			if corner.distance_to(end) > 4.0 * maxf(half, their_half):
				return square
			corners.append(corner)
		return corners
	if not joined.is_empty():
		return square
	# On another free wall's line: cut along it.
	for j: int in ends.size():
		if j != index and Geometry2D.get_closest_point_to_segment(end, ends[j][0], ends[j][1]).distance_to(end) < 0.01:
			return _cut_along(end, away, normal, half, ends[j][0], ends[j][1] - ends[j][0], square)
	# On a room's wall: cut along it in the middle of its band.
	for piece: Dictionary in pieces:
		var pa: Vector2 = piece["a"]
		var pb: Vector2 = piece["b"]
		if Geometry2D.get_closest_point_to_segment(end, pa, pb).distance_to(end) <= 0.01:
			var middle: Vector2 = pa + Vector2(piece["out"]) * (float(piece["from"]) + float(piece["to"])) * 0.5
			return _cut_along(end, away, normal, half, middle, pb - pa, square)
	return square


## The corners of a band's end at [param end] (going on along [param away],
## [param half] its half thickness to either side of [param normal]) cut
## along the line through [param through] along [param line];
## [param square] when it runs along that line rather than onto it.
static func _cut_along(end: Vector2, away: Vector2, normal: Vector2, half: float, through: Vector2, line: Vector2, square: PackedVector2Array) -> PackedVector2Array:
	if absf(line.normalized().cross(away)) < 0.2:
		return square
	var corners: PackedVector2Array = PackedVector2Array()
	for sign: float in [1.0, -1.0]:
		var hit: Variant = Geometry2D.line_intersects_line(end + normal * half * sign, away, through, line)
		if hit == null:
			return square
		corners.append(hit)
	return corners


## Adds a free wall from [param a] to [param b] ([param thickness] m, 0:
## the plan's); when it closes the free walls round a space (the shortest
## way back from its end to its start along them), those walls become room
## [param room_name]: its inside within them, each its wall with its
## thickness. Returns the new room's index, else -1.
func add_wall(a: Vector2, b: Vector2, thickness: float, room_name: String) -> int:
	if a.distance_to(b) < 0.01:
		return -1
	walls.append(Wall.new(a, b, thickness))
	var loop: Array[int] = _loop_through(walls.size() - 1)
	if loop.is_empty():
		return -1
	# The corners round the loop, from the new wall on.
	var corners: PackedVector2Array = PackedVector2Array()
	var halves: PackedFloat32Array = PackedFloat32Array()
	var at: Vector2 = a
	for index: int in loop:
		var wall: Wall = walls[index]
		corners.append(at)
		halves.append(free_thickness(wall) * 0.5)
		at = wall.b if wall.a.distance_to(at) < 0.01 else wall.a
	var own: PackedFloat32Array = PackedFloat32Array()
	for index: int in loop:
		own.append(walls[index].thickness)
	if not _simple(corners) or polygon_area(corners) < MIN_ROOM * MIN_ROOM * 0.5:
		return -1
	var sum: float = 0.0
	for i: int in corners.size():
		sum += corners[i].cross(corners[(i + 1) % corners.size()])
	if sum < 0.0:
		# Anticlockwise as drawn: turned round (wall k runs from corner k).
		corners.reverse()
		var first: Vector2 = corners[corners.size() - 1]
		corners.remove_at(corners.size() - 1)
		corners.insert(0, first)
		halves.reverse()
		own.reverse()
	# The room's inside: within the walls, half a wall in from their lines.
	var negative: PackedFloat32Array = PackedFloat32Array()
	for h: float in halves:
		negative.append(-h)
	var inside: PackedVector2Array = grown(corners, negative)
	if inside.size() != corners.size() or not _simple(inside):
		return -1
	var room: Room = Room.new(room_name)
	room.points = inside
	for k: int in inside.size():
		room.set_wall_thickness(k, halves[k] * 2.0)
	loop.sort()
	for i: int in range(loop.size() - 1, -1, -1):
		walls.remove_at(loop[i])
	rooms.append(room)
	return rooms.size() - 1


## Moves end [param which] (0: a, 1: b) of free wall [param index] to
## [param to] (the other ends there go along); a room [param room_name] is
## made when the walls close round a space now. Returns its index, else -1.
func move_wall_end(index: int, which: int, to: Vector2, room_name: String) -> int:
	var wall: Wall = walls[index]
	var from: Vector2 = wall.a if which == 0 else wall.b
	var other: Vector2 = wall.b if which == 0 else wall.a
	if other.distance_to(to) < 0.01:
		return -1
	for w: Wall in walls:
		if w.a.distance_to(from) < 0.01:
			w.a = to
		if w.b.distance_to(from) < 0.01:
			w.b = to
	# Closing a space: made again through add_wall, as when drawn.
	var moved: Wall = walls[index]
	walls.remove_at(index)
	return add_wall(moved.a, moved.b, moved.thickness, room_name)


## The free walls round a space with free wall [param index]: the shortest
## way along the others from its end back to its start, the wall first;
## empty for none.
func _loop_through(index: int) -> Array[int]:
	var start: Vector2 = walls[index].a
	var goal: Vector2 = walls[index].b
	# Dijkstra over the walls' ends.
	var best: Dictionary[int, float] = {}
	var back: Dictionary[int, int] = {}
	var ends: Dictionary[int, Vector2] = {}
	var todo: Array[int] = []
	for i: int in walls.size():
		if i == index:
			continue
		for end: int in 2:
			var p: Vector2 = walls[i].a if end == 0 else walls[i].b
			if p.distance_to(goal) < 0.01:
				var key: int = i * 2 + (1 - end)
				best[key] = walls[i].a.distance_to(walls[i].b)
				back[key] = -1
				ends[key] = walls[i].b if end == 0 else walls[i].a
				todo.append(key)
	while not todo.is_empty():
		var current: int = todo[0]
		for key: int in todo:
			if best[key] < best[current]:
				current = key
		todo.erase(current)
		var p: Vector2 = ends[current]
		if p.distance_to(start) < 0.01:
			var loop: Array[int] = [index]
			var path: Array[int] = []
			var key: int = current
			while key >= 0:
				path.insert(0, key / 2)
				key = back[key]
			loop.append_array(path)
			return loop
		for i: int in walls.size():
			if i == index or i == current / 2:
				continue
			for end: int in 2:
				var q: Vector2 = walls[i].a if end == 0 else walls[i].b
				if q.distance_to(p) >= 0.01:
					continue
				var key: int = i * 2 + (1 - end)
				var cost: float = best[current] + walls[i].a.distance_to(walls[i].b)
				if not best.has(key) or cost < best[key] - 1e-6:
					var used: bool = false
					var trace: int = current
					while trace >= 0:
						used = used or trace / 2 == i
						trace = back[trace]
					if used:
						continue
					best[key] = cost
					back[key] = current
					ends[key] = walls[i].b if end == 0 else walls[i].a
					if not todo.has(key):
						todo.append(key)
	return []


## Outline [param points] grown outwards by [param offsets] (m, one a
## wall), the walls' lines meeting in mitres.
static func grown(points: PackedVector2Array, offsets: PackedFloat32Array) -> PackedVector2Array:
	var n: int = points.size()
	var result: PackedVector2Array = PackedVector2Array()
	for k: int in n:
		# Corner k joins wall k - 1 and wall k.
		var before: int = (k + n - 1) % n
		var a0: Vector2 = points[before]
		var a1: Vector2 = points[k]
		var b1: Vector2 = points[(k + 1) % n]
		var da: Vector2 = (a1 - a0).normalized()
		var db: Vector2 = (b1 - a1).normalized()
		var pa: Vector2 = a1 - da.rotated(PI / 2.0) * offsets[before]
		var pb: Vector2 = a1 - db.rotated(PI / 2.0) * offsets[k]
		var meet: Variant = Geometry2D.line_intersects_line(pa, da, pb, db)
		if meet == null or (meet as Vector2).distance_to(a1) > 4.0 * maxf(absf(offsets[before]), absf(offsets[k])) + 0.01:
			# Straight on (or nearly): both ends.
			result.append(pa)
			result.append(pb)
		else:
			result.append(meet)
	return result


## Wall [param k] of room [param index] given thickness [param value] (0:
## the plan's) and placing [param mode] ([enum Align]); the walls of other
## rooms along it on its line take the same thickness.
func set_wall_look(index: int, k: int, value: float, mode: int) -> void:
	var room: Room = rooms[index]
	var w: PackedVector2Array = room.wall(k)
	room.set_wall_thickness(k, value)
	room.set_wall_align(k, mode)
	var dir: Vector2 = (w[1] - w[0]).normalized()
	for i: int in rooms.size():
		if i == index:
			continue
		for j: int in rooms[i].points.size():
			var o: PackedVector2Array = rooms[i].wall(j)
			# On the same line, overlapping.
			if absf((o[0] - w[0]).cross(dir)) > 0.001 or absf((o[1] - w[0]).cross(dir)) > 0.001:
				continue
			var t0: float = (o[0] - w[0]).dot(dir)
			var t1: float = (o[1] - w[0]).dot(dir)
			if minf(maxf(t0, t1), w[0].distance_to(w[1])) - maxf(minf(t0, t1), 0.0) > 0.001:
				rooms[i].set_wall_thickness(j, value)
				rooms[i].set_wall_align(j, Align.AUTO)


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
## [constant WALL_SNAP], keeping its size; onto an edge of a room beside it
## (along a stretch of it) within [method gap_reach], so that no gap is
## left between them for a wall of no set thickness.
func snap_room(rect: Rect2, skip: int = -1) -> Rect2:
	var at: Vector2 = snap(rect.position)
	var best: Vector2 = Vector2(WALL_SNAP, WALL_SNAP)
	var shift: Vector2 = Vector2.ZERO
	var reach: float = gap_reach()
	for i: int in rooms.size():
		if i == skip:
			continue
		var other: Rect2 = rooms[i].rect
		var beside_x: bool = minf(at.y + rect.size.y, other.end.y) - maxf(at.y, other.position.y) > 0.01
		var beside_y: bool = minf(at.x + rect.size.x, other.end.x) - maxf(at.x, other.position.x) > 0.01
		for mine: float in [at.x, at.x + rect.size.x]:
			for theirs: float in [other.position.x, other.end.x]:
				var near: float = absf(theirs - mine) - (reach - WALL_SNAP if beside_x else 0.0)
				if near < best.x:
					best.x = near
					shift.x = theirs - mine
		for mine: float in [at.y, at.y + rect.size.y]:
			for theirs: float in [other.position.y, other.end.y]:
				var near: float = absf(theirs - mine) - (reach - WALL_SNAP if beside_y else 0.0)
				if near < best.y:
					best.y = near
					shift.y = theirs - mine
	return Rect2(at + shift, rect.size)


## How near the walls of two rooms beside each other snap together (m):
## nearer than their two outside walls, the gap between them would be drawn
## as a wall of no set thickness, so they are put wall to wall instead
## (the wall between rooms drawn there).
func gap_reach() -> float:
	return maxf(WALL_SNAP, 2.0 * outer_wall + 0.01)


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
	for mark: Mark in marks:
		if room.contains(mark.at, 0.01):
			mark.at += by
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
	if not is_straight(w):
		return
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
	for mark: Mark in marks:
		var along_mark: float = mark.at.y if vertical else mark.at.x
		if mark.facing >= 0 and absf((mark.at.x if vertical else mark.at.y) - old) < 0.01 and along_mark >= span.x - 0.01 and along_mark <= span.y + 0.01:
			mark.at += Vector2(by, 0) if vertical else Vector2(0, by)
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
	if not is_straight(next) or not is_straight(w):
		# Its end corner moved along it (with the rooms sharing that corner).
		set_corner(index, (k + 1) % n, w[1] + direction * by, true)
		return
	var vertical_next: bool = is_equal_approx(next[0].x, next[1].x)
	var at: float = (next[0].x + direction.x * by) if vertical_next else (next[0].y + direction.y * by)
	set_edge(index, (k + 1) % n, at)


## Direction of wall [param w] ([from, to]): degrees anticlockwise from the
## right (y down), 0 to 360.
static func wall_angle(w: PackedVector2Array) -> float:
	return snappedf(fposmod(rad_to_deg(-(w[1] - w[0]).angle()), 360.0), 0.01)


## Turns wall [param k] of room [param index] about its start to
## [param degrees] (anticlockwise from the right) at [param length] m:
## its end corner moves there, the walls beside it slanting as they must.
## Refused when the room would cross itself.
func set_wall_angle(index: int, k: int, degrees: float, length: float) -> bool:
	var room: Room = rooms[index]
	var n: int = room.points.size()
	var start: Vector2 = room.points[k]
	var end: Vector2 = start + Vector2.from_angle(deg_to_rad(-degrees)) * maxf(length, MIN_WALL)
	# The rooms sharing its end corner keep sharing it.
	return _move_corners(corners_at(room.points[(k + 1) % n]), end.snappedf(0.001))


## [param points] with corner [param k] at [param at]; empty when the
## outline would cross itself or its walls beside it be shorter than
## [constant MIN_WALL].
static func with_corner(points: PackedVector2Array, k: int, at: Vector2) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	var n: int = points.size()
	result[k] = at
	if at.distance_to(result[(k + 1) % n]) < MIN_WALL or at.distance_to(result[(k + n - 1) % n]) < MIN_WALL:
		return PackedVector2Array()
	if not _simple(result):
		return PackedVector2Array()
	return result


## Outlines [param a] and [param b] (with slanting walls) put together,
## clockwise; empty when they do not touch along a wall or make a hole.
static func _merged(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(a, b)
	if merged.size() != 1:
		return PackedVector2Array()
	var outline: PackedVector2Array = _without_straight_on(merged[0])
	# Touching at a corner only, they make one outline through it.
	if absf(polygon_area(outline) - polygon_area(a) - polygon_area(b)) > 0.001 or outline.size() < 3 or not _simple(outline):
		return PackedVector2Array()
	return _clockwise(outline)


## [param points] without the corners where the outline goes straight on.
static func _without_straight_on(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var n: int = points.size()
	for k: int in n:
		var a: Vector2 = points[(k + n - 1) % n]
		var b: Vector2 = points[k]
		var c: Vector2 = points[(k + 1) % n]
		if absf((b - a).normalized().cross((c - b).normalized())) > 0.0005:
			result.append(b)
	return result


## Whether outline [param points] crosses itself nowhere.
static func _simple(points: PackedVector2Array) -> bool:
	var n: int = points.size()
	for i: int in n:
		for j: int in range(i + 2, n):
			if i == 0 and j == n - 1:
				continue
			if Geometry2D.segment_intersects_segment(points[i], points[(i + 1) % n], points[j], points[(j + 1) % n]) != null:
				return false
	return true


## [param points] clockwise as drawn (y down).
static func _clockwise(points: PackedVector2Array) -> PackedVector2Array:
	var sum: float = 0.0
	for i: int in points.size():
		sum += points[i].x * points[(i + 1) % points.size()].y - points[(i + 1) % points.size()].x * points[i].y
	if sum >= 0.0:
		return points
	var turned: PackedVector2Array = points.duplicate()
	turned.reverse()
	return turned


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
	var outline: PackedVector2Array = union_outline([rooms[a].points, rooms[b].points]) if rooms[a].is_square() and rooms[b].is_square() else _merged(rooms[a].points, rooms[b].points)
	if outline.is_empty():
		return false
	# Each wall keeps the thickness, alignment and opening it had (a wall
	# taken away keeps its ends as corners, so that only it stays open).
	var gaps: Array[PackedVector2Array] = []
	for room: Room in [rooms[a], rooms[b]]:
		for k: int in room.open:
			if k < room.points.size():
				gaps.append(room.wall(k))
	outline = _with_corners_at(outline, gaps)
	var joined: Room = Room.new()
	joined.points = outline
	_carry_wall_looks(rooms[a], joined)
	_carry_wall_looks(rooms[b], joined)
	rooms[a].points = outline
	rooms[a].thickness = joined.thickness
	rooms[a].align = joined.align
	rooms[a].open = joined.open
	rooms.remove_at(b)
	_forget_room(b, a)
	return true


## Outline [param points] with a corner where an end of one of
## [param segments] lies along one of its walls (not at its ends).
static func _with_corners_at(points: PackedVector2Array, segments: Array[PackedVector2Array]) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	for segment: PackedVector2Array in segments:
		for p: Vector2 in segment:
			for k: int in result.size():
				var a: Vector2 = result[k]
				var b: Vector2 = result[(k + 1) % result.size()]
				if p.distance_to(a) > 0.01 and p.distance_to(b) > 0.01 and Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 0.002:
					result.insert(k + 1, p)
					break
	return result


## Room [param index] split in two by a wall along [param line]: its
## corners, the first and the last on the room's walls, the others inside
## it, the wall straight or bent. The room keeps the larger piece, a new
## room [param new_name] (the last) gets the other; the walls of the pieces
## that lie on the room's walls keep their thickness and alignment. Refused
## (-1) when the line does not cut it into two pieces, each at least
## [constant MIN_ROOM] across; else the new room's index. The chains of
## dimensions along its walls are dropped.
func split_room(index: int, line: PackedVector2Array, new_name: String) -> int:
	if index < 0 or index >= rooms.size() or line.size() < 2:
		return -1
	var room: Room = rooms[index]
	var a: Vector2 = line[0]
	var b: Vector2 = line[line.size() - 1]
	var i: int = wall_through(room.points, a)
	var j: int = wall_through(room.points, b)
	if i < 0 or j < 0 or a.distance_to(b) < 0.01:
		return -1
	# Through the room: every corner between the ends and every stretch's middle inside.
	for k: int in range(1, line.size()):
		if not Geometry2D.is_point_in_polygon((line[k - 1] + line[k]) * 0.5, room.points):
			return -1
		if k < line.size() - 1 and not Geometry2D.is_point_in_polygon(line[k], room.points):
			return -1
	var inner: PackedVector2Array = line.slice(1, line.size() - 1)
	var back: PackedVector2Array = inner.duplicate()
	back.reverse()
	var pieces: Array[PackedVector2Array] = []
	for piece: PackedVector2Array in [
			PackedVector2Array([a]) + inner + PackedVector2Array([b]) + _corners_between(room.points, b, j, a, i),
			PackedVector2Array([b]) + back + PackedVector2Array([a]) + _corners_between(room.points, a, i, b, j)]:
		var outline: PackedVector2Array = _clockwise(_without_straight_on(_without_repeats(piece)))
		if outline.size() < 3 or not _simple(outline) or polygon_area(outline) < MIN_ROOM * MIN_ROOM * 0.5:
			return -1
		# Nowhere narrower than MIN_ROOM.
		if Geometry2D.offset_polygon(outline, -MIN_ROOM * 0.5 + 0.001).size() != 1:
			return -1
		pieces.append(outline)
	if polygon_area(pieces[1]) > polygon_area(pieces[0]):
		pieces.reverse()
	var other: Room = Room.new(new_name)
	other.points = pieces[1]
	_carry_wall_looks(room, other)
	var kept: Room = Room.new()
	kept.points = pieces[0]
	_carry_wall_looks(room, kept)
	room.points = kept.points
	room.thickness = kept.thickness
	room.align = kept.align
	room.open = kept.open
	room.label_offset = Vector2.ZERO
	rooms.append(other)
	for d: int in range(dimensions.size() - 1, -1, -1):
		if dimensions[d].room == index:
			dimensions.remove_at(d)
	return rooms.size() - 1


## The wall of outline [param points] that point [param p] lies on, -1 for none.
static func wall_through(points: PackedVector2Array, p: Vector2) -> int:
	for k: int in points.size():
		if Geometry2D.get_closest_point_to_segment(p, points[k], points[(k + 1) % points.size()]).distance_to(p) < 0.01:
			return k
	return -1


## The corners of outline [param points] going round it from [param p] (on
## wall [param i]) to [param q] (on wall [param j]), neither of them.
static func _corners_between(points: PackedVector2Array, p: Vector2, i: int, q: Vector2, j: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if i == j and points[i].distance_to(q) >= points[i].distance_to(p):
		return result
	var k: int = (i + 1) % points.size()
	while true:
		result.append(points[k])
		if k == j:
			break
		k = (k + 1) % points.size()
	return result


## [param points] without a corner on the one before it (the last on the first too).
static func _without_repeats(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		if result.is_empty() or result[result.size() - 1].distance_to(p) > 0.001:
			result.append(p)
	if result.size() > 1 and result[0].distance_to(result[result.size() - 1]) <= 0.001:
		result.remove_at(result.size() - 1)
	return result


## Gives the walls of [param piece] that lie on a wall of [param room] that
## wall's own thickness and alignment.
static func _carry_wall_looks(room: Room, piece: Room) -> void:
	for k: int in piece.points.size():
		var p: Vector2 = piece.points[k]
		var q: Vector2 = piece.points[(k + 1) % piece.points.size()]
		for w: int in room.points.size():
			var a: Vector2 = room.points[w]
			var b: Vector2 = room.points[(w + 1) % room.points.size()]
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 0.01 and Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) < 0.01:
				if room.wall_thickness(w) > 0.0:
					piece.set_wall_thickness(k, room.wall_thickness(w))
				if room.wall_align(w) != 0:
					piece.set_wall_align(k, room.wall_align(w))
				if room.is_open(w):
					piece.set_open(k, true)
				break


## The stairs of a staircase of outline [param points]: {"treads": lines
## across the way up, [constant TREAD] apart, "walk": the walking line from
## its start to its end (the way up; turned round with [param reverse])}.
## A rectangle has a straight flight along its longer side; an L (six
## corners, walls across or up and down) a flight in each arm turning in the
## square where they meet, with winders from the inner corner; any other
## outline a straight flight along the longer side of the rectangle round
## it, cut to the outline.
static func stair_lines(points: PackedVector2Array, reverse: bool) -> Dictionary:
	var treads: Array[PackedVector2Array] = []
	var walk: PackedVector2Array = PackedVector2Array()
	var box: Rect2 = Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		box = box.expand(p)
	var reflex: int = _l_corner(points)
	if reflex >= 0:
		var p: Vector2 = points[reflex]
		# The corner of the box the L lacks, and the one across from it.
		var k: Vector2 = Vector2.ZERO
		for c: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
			if not Geometry2D.is_point_in_polygon(c + (box.get_center() - c).normalized() * 0.01, points):
				k = c
		var o: Vector2 = box.position + box.end - k
		# The arm along x, the arm along y, the square where they meet.
		var arm_x: Rect2 = Rect2(Vector2(minf(p.x, k.x), minf(o.y, p.y)), Vector2(absf(k.x - p.x), absf(p.y - o.y)))
		var arm_y: Rect2 = Rect2(Vector2(minf(o.x, p.x), minf(p.y, k.y)), Vector2(absf(p.x - o.x), absf(k.y - p.y)))
		var sx: float = signf(k.x - p.x)
		var sy: float = signf(k.y - p.y)
		var t: float = TREAD
		while t < arm_y.size.y - 0.001:
			treads.append(PackedVector2Array([Vector2(arm_y.position.x, p.y + sy * t), Vector2(arm_y.end.x, p.y + sy * t)]))
			t += TREAD
		t = TREAD
		while t < arm_x.size.x - 0.001:
			treads.append(PackedVector2Array([Vector2(p.x + sx * t, arm_x.position.y), Vector2(p.x + sx * t, arm_x.end.y)]))
			t += TREAD
		# Winders in the square, from the inner corner.
		treads.append(PackedVector2Array([p, o]))
		treads.append(PackedVector2Array([p, Vector2(o.x, (o.y + p.y) * 0.5)]))
		treads.append(PackedVector2Array([p, Vector2((o.x + p.x) * 0.5, o.y)]))
		var mid_y: float = (o.x + p.x) * 0.5
		var mid_x: float = (o.y + p.y) * 0.5
		walk = PackedVector2Array([Vector2(mid_y, k.y - sy * WALK_END), Vector2(mid_y, mid_x), Vector2(k.x - sx * WALK_END, mid_x)])
	else:
		var along_x: bool = box.size.x >= box.size.y
		var length: float = box.size.x if along_x else box.size.y
		var start: float = box.position.x if along_x else box.position.y
		var t: float = TREAD
		while t < length - 0.001:
			var line: PackedVector2Array = PackedVector2Array([Vector2(start + t, box.position.y - 1.0), Vector2(start + t, box.end.y + 1.0)]) if along_x else PackedVector2Array([Vector2(box.position.x - 1.0, start + t), Vector2(box.end.x + 1.0, start + t)])
			for piece: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(line, points):
				treads.append(piece)
			t += TREAD
		var c: Vector2 = box.get_center()
		walk = PackedVector2Array([Vector2(box.position.x + WALK_END, c.y), Vector2(box.end.x - WALK_END, c.y)]) if along_x else PackedVector2Array([Vector2(c.x, box.position.y + WALK_END), Vector2(c.x, box.end.y - WALK_END)])
	if reverse:
		walk.reverse()
	return {"treads": treads, "walk": walk}


## The wall of a staircase of outline [param points] its stairs start at
## (the one across the walking line's start, nearest it; see
## [method stair_lines]): left open, no wall there. -1 for none.
static func stair_start_wall(points: PackedVector2Array, reverse: bool) -> int:
	var walk: PackedVector2Array = stair_lines(points, reverse)["walk"]
	if walk.size() < 2:
		return -1
	var start: Vector2 = walk[0]
	var way: Vector2 = (walk[1] - walk[0]).normalized()
	var best: int = -1
	var nearest: float = INF
	for k: int in points.size():
		var a: Vector2 = points[k]
		var b: Vector2 = points[(k + 1) % points.size()]
		if absf((b - a).normalized().dot(way)) > 0.5:
			continue
		var d: float = Geometry2D.get_closest_point_to_segment(start, a, b).distance_to(start)
		if d < nearest:
			nearest = d
			best = k
	return best


## The wall of room [param index] left open: where a staircase starts, -1 for none.
func open_wall(index: int) -> int:
	var room: Room = rooms[index]
	return stair_start_wall(room.points, room.stairs_reverse) if room.stairs else -1


## The inner corner of an L-shaped outline [param points] (six corners,
## walls across or up and down), -1 for another shape.
static func _l_corner(points: PackedVector2Array) -> int:
	var n: int = points.size()
	if n != 6:
		return -1
	var found: int = -1
	for i: int in n:
		var a: Vector2 = points[(i + n - 1) % n]
		var b: Vector2 = points[i]
		var c: Vector2 = points[(i + 1) % n]
		if not (is_equal_approx(a.x, b.x) or is_equal_approx(a.y, b.y)) or not (is_equal_approx(b.x, c.x) or is_equal_approx(b.y, c.y)):
			return -1
		# Clockwise as drawn (y down): an inner corner turns the other way.
		if (b - a).cross(c - b) < 0.0:
			if found >= 0:
				return -1
			found = i
	return found


## [param points] put on the [constant SNAP] grid (cuts of a polygon come
## back a hair off it).
static func _tidy(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		result.append(p.snapped(Vector2(0.0001, 0.0001)))
	return result


## Area of polygon [param points] (m²).
static func polygon_area(points: PackedVector2Array) -> float:
	var sum: float = 0.0
	for i: int in points.size():
		sum += points[i].cross(points[(i + 1) % points.size()])
	return absf(sum) * 0.5


## A room [param room_name] of the corners [param corners] clicked (every
## wall across or up and down; a corner on a straight run left out); null
## when they do not make one room without crossings at least
## [constant MIN_ROOM] across.
static func outline_room(corners: PackedVector2Array, room_name: String) -> Room:
	if corners.size() < 3:
		return null
	var square: bool = corners.size() >= 4
	for k: int in corners.size():
		square = square and is_straight(PackedVector2Array([corners[k], corners[(k + 1) % corners.size()]]))
	if not Geometry2D.triangulate_polygon(corners).size() > 0:
		return null
	# Slanting walls: the corners as they are, clockwise, without crossings.
	var outline: PackedVector2Array = union_outline([corners]) if square else (_clockwise(_without_straight_on(corners)) if _simple(corners) else PackedVector2Array())
	if outline.is_empty():
		return null
	var room: Room = Room.new(room_name)
	room.points = outline
	if room.rect.size.x < MIN_ROOM - 0.001 or room.rect.size.y < MIN_ROOM - 0.001:
		return null
	return room


## Where rooms overlap: each piece shared by two rooms (more than a sliver
## along a shared wall).
func overlaps() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for i: int in rooms.size():
		for j: int in range(i + 1, rooms.size()):
			if not rooms[i].rect.intersects(rooms[j].rect):
				continue
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(rooms[i].points, rooms[j].points):
				if polygon_area(piece) > 0.01:
					result.append(piece)
	return result


## A copy of room [param index] (its name, environment and illuminance, not
## its number) right beside it, or right of all the rooms where that is
## taken; returns its index.
func duplicate_room(index: int) -> int:
	var room: Room = rooms[index]
	var twin: Room = Room.new(room.name)
	twin.points = room.points.duplicate()
	twin.environment = room.environment
	twin.lux = room.lux
	twin.stairs = room.stairs
	twin.stairs_reverse = room.stairs_reverse
	var by: Vector2 = Vector2(room.rect.size.x, 0.0)
	var free: bool = true
	for other: Room in rooms:
		var shifted: Rect2 = Rect2(room.rect.position + by, room.rect.size).grow(-0.01)
		if other.rect.intersects(shifted):
			free = false
	if not free:
		by = free_spot(room.rect.size).position - room.rect.position
	for k: int in twin.points.size():
		twin.points[k] += by
	rooms.append(twin)
	return rooms.size() - 1


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
				var straight: bool = is_straight(w)
				# On a slanting wall: the way of FACING nearest to into the room.
				var facing: int = FACING.find(room.inward(k))
				if facing < 0:
					var into: Vector2 = room.inward(k)
					for f: int in FACING.size():
						if facing < 0 or FACING[f].dot(into) > FACING[facing].dot(into):
							facing = f
				result = {"at": snap(on) if straight else on.snappedf(0.001), "facing": facing, "straight": straight}
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
		offsets.erase(designation)
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


## Moves the symbol of part [param designation] on a wall [param offset] m
## off it into the room (0: on the wall).
func set_offset(designation: String, offset: float) -> void:
	offset = clampf(snappedf(offset, 0.01), 0.0, MAX_OFFSET)
	if offset > 0.0 and facing.has(designation):
		offsets[designation] = offset
	else:
		offsets.erase(designation)


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
	offsets.erase(designation)
	part_layers.erase(designation)
	unlink(designation)


## Takes the links of part [param designation] away (one on another floor
## may be linked to it through a staircase).
func unlink(designation: String) -> void:
	for i: int in range(links.size() - 1, -1, -1):
		if links[i].a == designation or links[i].b == designation:
			links.remove_at(i)


## Part [param old_designation] was renamed [param new_designation].
func rename(old_designation: String, new_designation: String) -> void:
	if parts.has(old_designation) and not parts.has(new_designation):
		parts[new_designation] = parts[old_designation]
		if facing.has(old_designation):
			facing[new_designation] = facing[old_designation]
		if offsets.has(old_designation):
			offsets[new_designation] = offsets[old_designation]
		if part_layers.has(old_designation):
			part_layers[new_designation] = part_layers[old_designation]
	for link: Link in links:
		if link.a == old_designation:
			link.a = new_designation
		if link.b == old_designation:
			link.b = new_designation
	parts.erase(old_designation)
	facing.erase(old_designation)
	offsets.erase(old_designation)
	part_layers.erase(old_designation)


## The layer part [param designation] is on ("" for none).
func layer_of(designation: String) -> String:
	return part_layers.get(designation, "")


## Puts part [param designation] on layer [param layer_name] ("" none).
func set_part_layer(designation: String, layer_name: String) -> void:
	if layer_name.is_empty():
		part_layers.erase(designation)
	elif parts.has(designation) and designation != UNIT:
		part_layers[designation] = layer_name


## The note, dimension, fixture or mark [param index] by [param kind] ("note",
## "dimension", "fixture", "mark"); null for none.
func layered_item(kind: String, index: int) -> Object:
	var list: Array = {"note": notes, "dimension": dimensions, "fixture": fixtures, "mark": marks}.get(kind, [])
	return list[index] if index >= 0 and index < list.size() else null


## The layer of what selection [param kind] names ("" for none): part
## [param designation], or the note, dimension, fixture or mark [param index].
func item_layer(kind: String, index: int, designation: String) -> String:
	if kind == "part":
		return layer_of(designation)
	var item: Object = layered_item(kind, index)
	return str(item.get("layer")) if item != null else ""


## Puts what selection [param kind] names on layer [param layer_name] (""
## none): part [param designation], or the fixture or mark [param index]
## (dimensions and notes stay on [constant ANNOTATIONS]).
func set_item_layer(kind: String, index: int, designation: String, layer_name: String) -> void:
	if kind in ["note", "dimension"] or layer_name == ANNOTATIONS:
		# Dimensions and notes stay on theirs, nothing else goes on it.
		return
	if kind == "part":
		set_part_layer(designation, layer_name)
		return
	var item: Object = layered_item(kind, index)
	if item != null:
		item.set("layer", layer_name)


## The notes, dimensions, fixtures and marks (each with its layer).
func layered() -> Array[Object]:
	var result: Array[Object] = []
	result.append_array(notes)
	result.append_array(dimensions)
	result.append_array(fixtures)
	result.append_array(marks)
	return result


## Layer [param old_name] is called [param new_name] ("": it is gone, what
## was on it is on none).
func rename_layer(old_name: String, new_name: String) -> void:
	for item: Object in layered():
		if item.get("layer") == old_name:
			item.set("layer", new_name)
	for designation: String in part_layers.keys():
		if part_layers[designation] == old_name:
			set_part_layer(designation, new_name)


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
		var thickest: float = outer_wall
		for t: float in room.thickness:
			thickest = maxf(thickest, t)
		var walled: Rect2 = room.rect.grow(thickest)
		result = walled if first else result.merge(walled)
		first = false
	for wall: Wall in walls:
		var span: Rect2 = Rect2(wall.a, Vector2.ZERO).expand(wall.b).grow(free_thickness(wall))
		result = span if first else result.merge(span)
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
		if room.stairs:
			rd["stairs"] = "reverse" if room.stairs_reverse else "up"
		var thicknesses: Array = []
		var aligns: Array = []
		for k: int in room.points.size():
			thicknesses.append(room.wall_thickness(k))
			aligns.append(room.wall_align(k))
		if thicknesses.any(func(t: float) -> bool: return t > 0.0):
			rd["thickness"] = thicknesses
		if aligns.any(func(a: int) -> bool: return a != 0):
			rd["align"] = aligns
		if not room.open.is_empty():
			rd["open"] = Array(room.open)
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
		if door.kind != DoorKind.SWING:
			dd["kind"] = DOOR_KINDS[door.kind]
		door_list.append(dd)
	var placed: Dictionary = {}
	for designation: String in parts:
		var entry: Array = [parts[designation].x, parts[designation].y]
		if facing.has(designation):
			entry.append(facing[designation])
			if offsets.has(designation):
				entry.append(offsets[designation])
		placed[designation] = entry
	var result: Dictionary = {"rooms": room_list, "doors": door_list, "parts": placed}
	if not part_layers.is_empty():
		result["part_layers"] = part_layers.duplicate()
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
			fixture_list.append(_with_layer({"kind": fixture.kind, "rect": [fixture.rect.position.x, fixture.rect.position.y, fixture.rect.size.x, fixture.rect.size.y], "facing": fixture.facing}, fixture.layer))
		result["fixtures"] = fixture_list
	if not walls.is_empty():
		var wall_list: Array = []
		for wall: Wall in walls:
			var wd: Dictionary = {"a": [wall.a.x, wall.a.y], "b": [wall.b.x, wall.b.y]}
			if wall.thickness > 0.0:
				wd["thickness"] = wall.thickness
			wall_list.append(wd)
		result["free_walls"] = wall_list
	if not marks.is_empty():
		var mark_list: Array = []
		for mark: Mark in marks:
			var md: Dictionary = {"symbol": mark.symbol, "at": [mark.at.x, mark.at.y]}
			if mark.facing >= 0:
				md["facing"] = mark.facing
			mark_list.append(_with_layer(md, mark.layer))
		result["marks"] = mark_list
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


## [param data] with "layer" [param layer_name] when it is on one.
static func _with_layer(data: Dictionary, layer_name: String) -> Dictionary:
	if not layer_name.is_empty():
		data["layer"] = layer_name
	return data


## The layer name read from [param data] ("" for none or a damaged one).
static func _layer_in(data: Dictionary) -> String:
	return (data["layer"] as String).strip_edges().left(MAX_LAYER_NAME) if data.get("layer", null) is String else ""


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
				if corners is Array and (corners as Array).size() >= 3:
					var outline: PackedVector2Array = PackedVector2Array()
					for c: Variant in corners:
						if _numbers(c, 2):
							outline.append(Vector2(float(c[0]), float(c[1])))
					var square: bool = true
					for k: int in outline.size():
						square = square and is_straight(PackedVector2Array([outline[k], outline[(k + 1) % outline.size()]]))
					# As one piece; slanting walls without crossings.
					var shape: PackedVector2Array = PackedVector2Array()
					if outline.size() == (corners as Array).size():
						if square and outline.size() >= 6:
							shape = union_outline([outline])
						elif not square and _simple(outline) and polygon_area(outline) > 0.0001:
							shape = _clockwise(outline)
					if not shape.is_empty():
						room.points = shape
				for key: String in ["number", "environment", "lux"]:
					if rd.get(key, "") is String:
						room.set(key, (rd[key] as String).strip_edges() if rd.has(key) else "")
				room.stairs = rd.get("stairs", "") in ["up", "reverse"]
				room.stairs_reverse = rd.get("stairs", "") == "reverse"
				var thicknesses: Variant = rd.get("thickness", [])
				if thicknesses is Array and (thicknesses as Array).size() == room.points.size():
					for k: int in room.points.size():
						var t: Variant = thicknesses[k]
						if (t is float or t is int) and float(t) > 0.0:
							room.set_wall_thickness(k, clampf(float(t), MIN_WALL_THICKNESS, MAX_WALL_THICKNESS))
				var aligns: Variant = rd.get("align", [])
				if aligns is Array and (aligns as Array).size() == room.points.size():
					for k: int in room.points.size():
						var a: Variant = aligns[k]
						if a is float or a is int:
							room.set_wall_align(k, clampi(int(a), 0, Align.size() - 1))
				var opened: Variant = rd.get("open", [])
				if opened is Array:
					for k: Variant in opened:
						if (k is float or k is int) and int(k) >= 0 and int(k) < room.points.size():
							room.set_open(int(k), true)
				plan.rooms.append(room)
	var door_list: Variant = d.get("doors", [])
	if door_list is Array:
		for dd: Variant in door_list:
			if dd is Dictionary and _numbers(dd.get("at", []), 2):
				var width: Variant = dd.get("width", DOOR_WIDTH)
				var door: Door = Door.new(Vector2(float(dd["at"][0]), float(dd["at"][1])), dd.get("vertical", false) == true, clampf(float(width), DOOR_MIN_WIDTH, DOOR_MAX_WIDTH) if (width is float or width is int) else DOOR_WIDTH)
				door.kind = maxi(DOOR_KINDS.find(str(dd.get("kind", ""))), DoorKind.SWING)
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
	# A plan saved without them has the usual walls, whatever new plans start with.
	plan.outer_wall = OUTER_WALL
	plan.inner_wall = INNER_WALL
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
				fixture.layer = _layer_in(fd)
				plan.fixtures.append(fixture)
	var wall_list: Variant = d.get("free_walls", [])
	if wall_list is Array:
		for wd: Variant in wall_list:
			if wd is Dictionary and _numbers(wd.get("a", []), 2) and _numbers(wd.get("b", []), 2):
				var wall: Wall = Wall.new(Vector2(float(wd["a"][0]), float(wd["a"][1])), Vector2(float(wd["b"][0]), float(wd["b"][1])))
				var t: Variant = wd.get("thickness", 0.0)
				wall.thickness = clampf(float(t), MIN_WALL_THICKNESS, MAX_WALL_THICKNESS) if (t is float or t is int) and float(t) > 0.0 else 0.0
				if wall.a.distance_to(wall.b) > 0.001:
					plan.walls.append(wall)
	var mark_list: Variant = d.get("marks", [])
	if mark_list is Array:
		for md: Variant in mark_list:
			if md is Dictionary and md.get("symbol", null) is String and not (md["symbol"] as String).is_empty() and _numbers(md.get("at", []), 2):
				var mark: Mark = Mark.new()
				mark.symbol = (md["symbol"] as String).left(40)
				mark.at = Vector2(float(md["at"][0]), float(md["at"][1]))
				var face: Variant = md.get("facing", -1)
				mark.facing = clampi(int(face), -1, 3) if (face is int or face is float) else -1
				mark.layer = _layer_in(md)
				plan.marks.append(mark)
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
					if (entry as Array).size() > 3 and (entry[3] is int or entry[3] is float):
						plan.set_offset(designation, float(entry[3]))
	var layer_list: Variant = d.get("part_layers", {})
	if layer_list is Dictionary:
		for designation: Variant in layer_list:
			if designation is String:
				plan.set_part_layer(designation, _layer_in({"layer": layer_list[designation]}))
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
