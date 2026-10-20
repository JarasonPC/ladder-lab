class_name WorkspaceCanvas
extends Control
## The workspace on schematic paper: switchboards and control stations as
## solid tiles with their names, parts in the field (motors, limit switches,
## temperature sensors) as smaller tiles, groups as frames round their
## members, the cables between them (see [WorkspaceCables]) as tracks with
## their name, power cables thicker, Ethernet cables green. A click on a switchboard or
## station opens it, a click on a cable lists its cores; in Edit mode
## everything is dragged around (a part dropped into a group's frame joins
## the group, dropped outside leaves it). The wheel zooms at the mouse, a
## right or middle drag pans, a right click (no drag) asks for a menu.

## Switchboard or station [param place_name] was clicked: open it.
signal open_requested(kind: Workspace.Place, place_name: String)
## Cable [param key] ("+RA1|+ST1") was clicked: list its cores.
signal cable_requested(key: String)
## A right click: [param item] is the one under the mouse ({} for none, else
## like those of [method items]) at [param at] (workspace position).
signal menu_requested(item: Dictionary, at: Vector2)
## A change of the workspace: [param change] is called with the document.
signal edit_requested(change: Callable)
## A push button on a station shown as its face was pressed (true) or let
## go while simulating.
signal button_held(designation: String, pressed: bool)
## A switch on a station shown as its face was clicked while simulating.
signal switch_toggled(designation: String, steps: int)

## Reach (pixels) of the handle resizing a station's face.
const HANDLE: float = 9.0
const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 3.0
const ZOOM_STEP: float = 1.15
## Positions snap to this many units.
const SNAP: float = 4.0
const NAME_SIZE: int = 15
const TEXT_SIZE: int = 12
const SMALL_SIZE: int = 11
const CABLE_WIDTH: float = 2.0
const POWER_WIDTH: float = 3.5
## Room kept round tiles a cable passes by.
const CABLE_CLEARANCE: float = 8.0
## How far a cable runs straight out of its tile, the room between cables
## leaving one side, the radius of the corners.
const STUB: float = 14.0
const LANE: float = 8.0
const CORNER: float = 10.0
## Turns a second of the marks on a motor's tile at the motor's rated speed
## (the real speed would only flicker).
const SPIN_RATE: float = 1.5
## Sides of a tile, clockwise from the left.
const SIDE_LEFT: int = 0
const SIDE_TOP: int = 1
const SIDE_RIGHT: int = 2
const SIDE_BOTTOM: int = 3

var document: SchematicDocument:
	set(value):
		if value != document:
			# Another document (undo, redo, a new or opened file): a press,
			# drag or resize under way was of places it may not have.
			_press = {}
			_dragging = false
			_drag = Vector2.ZERO
			_resizing = -1
		document = value
## Things are dragged only while editing.
var editing: bool = false
var zoom: float = 1.0
## Screen position of the workspace origin.
var offset: Vector2 = Vector2(40.0, 40.0)
## Key of the selected item (see [method items]), "" for none.
var selected: String = ""
## Draw the keys of the keyboard bound to the stations' buttons (off for exports).
var show_keys: bool = true
## Where each part moved by a motor is while simulating (group name -> 0-1;
## empty while editing).
var travel_positions: Dictionary[String, float] = {}

## Item under the left press, its press position (screen) and how far it was dragged (workspace units).
var _press: Dictionary = {}
var _press_at: Vector2 = Vector2.ZERO
var _drag: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _pan_button: MouseButton = MOUSE_BUTTON_NONE
var _pan_from: Vector2 = Vector2.ZERO
var _panned: bool = false
## Stations shown as their face: station name -> its [ControlBoxView] over
## the canvas.
var _faces: Dictionary[String, ControlBoxView] = {}
## Station whose face is being resized by its corner handle (-1 for none),
## and the scale it is dragged to.
var _resizing: int = -1
var _resize_scale: float = 0.0
## Angle of the marks turning on each motor's tile while simulating
## (designation -> radians), and whether any turned at the last frame.
var _spin: Dictionary[String, float] = {}
var _spinning: bool = false
## Cables of the document, worked out again after it changed.
var _cables: Array[Dictionary] = []
var _cables_dirty: bool = true


## The document changed: its cables are worked out again.
func invalidate() -> void:
	_cables_dirty = true
	queue_redraw()


func cables() -> Array[Dictionary]:
	if _cables_dirty:
		_cables = WorkspaceCables.cables(document) if document != null else ([] as Array[Dictionary])
		_cables_dirty = false
	return _cables


## Where each cable is drawn: {"cable" (see [method WorkspaceCables.cables]),
## "points" (polyline, workspace units), "tag" (Rect2 of its name tag),
## "text", "power" (it carries power cores), "network" (an Ethernet cable,
## drawn in the network colour), "ports" (where it leaves its two ends)}. Cables run as tracks: out of the side of each end facing the
## other, each from a point of its own along that side, at right angles with
## rounded corners, round the places in their way where they can.
func cable_paths() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if document == null:
		return result
	var tiles: Dictionary[String, Rect2] = {}
	# The whole place with its texts, which a cable keeps clear of.
	var areas: Dictionary[String, Rect2] = {}
	for item: Dictionary in items():
		if item["kind"] != "group":
			tiles[item["key"]] = _tile_rect(item)
			areas[item["key"]] = item["rect"]
	var shown: Array[Dictionary] = []
	for cable: Dictionary in cables():
		if tiles.has(cable["a"]) and tiles.has(cable["b"]):
			shown.append(cable)
	# The sides each cable leaves its ends by: the shortest clear route from
	# the middles of the sides, preferring the sides facing each other.
	var sides: Array[Vector2i] = []
	var on_side: Dictionary[String, Array] = {}
	for c: int in shown.size():
		var ta: Rect2 = tiles[shown[c]["a"]]
		var tb: Rect2 = tiles[shown[c]["b"]]
		var aa: Rect2 = areas[shown[c]["a"]]
		var ab: Rect2 = areas[shown[c]["b"]]
		var others: Array[Rect2] = _obstacles(areas, shown[c])
		var best: Vector2i = Vector2i(SIDE_RIGHT, SIDE_LEFT)
		var best_score: float = INF
		for side_a: int in 4:
			for side_b: int in 4:
				var route: PackedVector2Array = _route(_port(ta, aa, side_a, 0.5), side_a, _port(tb, ab, side_b, 0.5), side_b, 0.0, others)
				if route.is_empty():
					continue
				var score: float = _blocked(route, others) * 10000.0 + _length(route) + route.size() * 20.0
				if score < best_score:
					best_score = score
					best = Vector2i(side_a, side_b)
		sides.append(best)
		for end: int in 2:
			var key: String = "%s/%d" % [shown[c][["a", "b"][end]], [best.x, best.y][end]]
			if not on_side.has(key):
				on_side[key] = []
			on_side[key].append(Vector2i(c, end))
	# Points along each side: in line with where each cable goes, as far as
	# the side reaches, kept a lane apart.
	var port_at: Dictionary[Vector2i, Vector2] = {}
	var lane: Dictionary[Vector2i, float] = {}
	# Twice: the second time each side lines up with the ports of the first.
	for round: int in 2:
		for key: String in on_side:
			var list: Array = on_side[key]
			var side: int = int(key.get_slice("/", 1))
			var across: bool = side == SIDE_LEFT or side == SIDE_RIGHT
			var owner: String = key.get_slice("/", 0)
			var tile: Rect2 = tiles[owner]
			var low: float = (tile.position.y if across else tile.position.x) + 6.0
			var high: float = (tile.end.y if across else tile.end.x) - 6.0
			var wanted: Dictionary[Vector2i, float] = {}
			for end: Vector2i in list:
				# First towards the other place, then towards its port.
				var other: Vector2 = port_at.get(Vector2i(end.x, 1 - end.y), tiles[shown[end.x][["b", "a"][end.y]]].get_center())
				wanted[end] = clampf(other.y if across else other.x, low, high)
			list.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return wanted[p] < wanted[q])
			# Closer together than a lane when the side is too short for them all.
			var step: float = minf(LANE, (high - low) / maxf(list.size() - 1, 1))
			var at: PackedFloat32Array = PackedFloat32Array()
			for i: int in list.size():
				at.append(wanted[list[i]] if i == 0 else maxf(wanted[list[i]], at[i - 1] + step))
			for i: int in range(list.size() - 1, -1, -1):
				at[i] = minf(at[i], high if i == list.size() - 1 else at[i + 1] - step)
			for i: int in list.size():
				var t: float = (at[i] - (tile.position.y if across else tile.position.x)) / (tile.size.y if across else tile.size.x)
				port_at[list[i]] = _port(tile, areas[owner], side, t)
				lane[list[i]] = (i - (list.size() - 1) * 0.5) * LANE
	var taken: Array[Rect2] = []
	for c: int in shown.size():
		var cable: Dictionary = shown[c]
		var pa: Vector2 = port_at[Vector2i(c, 0)]
		var pb: Vector2 = port_at[Vector2i(c, 1)]
		var best: PackedVector2Array = _route(pa, sides[c].x, pb, sides[c].y, lane[Vector2i(c, 0)], _obstacles(areas, cable))
		if best.is_empty():
			# Its ports moved along their sides leave no way out at right
			# angles: from the middles of the sides, as they were chosen.
			pa = _port(tiles[cable["a"]], areas[cable["a"]], sides[c].x, 0.5)
			pb = _port(tiles[cable["b"]], areas[cable["b"]], sides[c].y, 0.5)
			best = _route(pa, sides[c].x, pb, sides[c].y, 0.0, _obstacles(areas, cable))
		if best.is_empty():
			best = PackedVector2Array([pa, pb])
		var corners: PackedVector2Array = _straightened(best)
		var tag: Dictionary = _tag(corners, cable, taken)
		taken.append(tag["tag"])
		var power: bool = false
		for core: Dictionary in cable["cores"]:
			power = power or core["conductor"] == CabinetDevices.Conductor.POWER
		var network: bool = int(cable.get("use", -1)) == WorkspaceCables.Use.ETHERNET
		result.append({"cable": cable, "points": _rounded(corners, CORNER), "tag": tag["tag"], "text": tag["text"], "power": power, "network": network, "ports": PackedVector2Array([pa, pb])})
	return result


## Where the name tag of [param cable] goes on its track [param corners]:
## {"tag" (Rect2), "text"}. On the longest straight run, with the name and
## the type on one line, on two on a short run, only the name on a shorter
## one; moved along its run, or onto another run, to keep clear of the tags
## in [param taken]; where none is clear, in the middle of the longest run.
static func _tag(corners: PackedVector2Array, cable: Dictionary, taken: Array[Rect2]) -> Dictionary:
	var font: Font = AppTheme.schematic_font()
	var type: String = WorkspaceCables.type_and_length(cable)
	var texts: PackedStringArray = ["%s · %s" % [cable["name"], type], "%s\n%s" % [cable["name"], type], cable["name"]]
	var sizes: Array[Vector2] = []
	for i: int in texts.size():
		var w: float = (font.get_multiline_string_size(texts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE) if i == 1 else font.get_string_size(texts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE)).x + 10.0
		sizes.append(Vector2(w, 30.0 if i == 1 else 16.0))
	var runs: Array = range(corners.size() - 1)
	runs.sort_custom(func(i: int, j: int) -> bool: return corners[i].distance_to(corners[i + 1]) > corners[j].distance_to(corners[j + 1]))
	var fallback: Dictionary = {}
	for i: int in runs:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var middle: Vector2 = (a + b) * 0.5
		var room: float = a.distance_to(b) - 8.0
		# Along a vertical run the tag's height counts.
		var upright: bool = absf(a.x - b.x) < 1.0
		for t: int in texts.size():
			var along: float = sizes[t].y if upright else sizes[t].x
			if along > room and t < texts.size() - 1:
				continue
			if fallback.is_empty():
				fallback = {"tag": Rect2(middle - sizes[t] * 0.5, sizes[t]), "text": texts[t]}
			# From the middle outwards, as far as the run takes it.
			var slack: float = maxf(room - along, 0.0) * 0.5
			var step: float = 0.0
			while step <= slack:
				for sign: float in [1.0, -1.0]:
					var rect: Rect2 = Rect2(middle + (b - a).normalized() * step * sign - sizes[t] * 0.5, sizes[t])
					var clear: bool = true
					for other: Rect2 in taken:
						clear = clear and not other.grow(2.0).intersects(rect)
					if clear:
						return {"tag": rect, "text": texts[t]}
				step += LANE
	return fallback


## The places a cable keeps clear of: all but its own ends.
func _obstacles(areas: Dictionary[String, Rect2], cable: Dictionary) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for key: String in areas:
		if key != cable["a"] and key != cable["b"]:
			result.append(areas[key].grow(CABLE_CLEARANCE))
	return result


## A right-angled route from [param pa] leaving by [param side_a] to
## [param pb] coming in by [param side_b], its middle run moved by
## [param shift]; of the ways it can go, the one with fewest places of
## [param others] in its way. Empty when the sides cannot be joined going
## outwards from both.
static func _route(pa: Vector2, side_a: int, pb: Vector2, side_b: int, shift: float, others: Array[Rect2]) -> PackedVector2Array:
	var na: Vector2 = _normal(side_a)
	var nb: Vector2 = _normal(side_b)
	var sa: Vector2 = pa + na * STUB
	var sb: Vector2 = pb + nb * STUB
	var a_across: bool = side_a == SIDE_LEFT or side_a == SIDE_RIGHT
	var b_across: bool = side_b == SIDE_LEFT or side_b == SIDE_RIGHT
	var routes: Array[PackedVector2Array] = []
	if a_across and b_across:
		for share: float in [0.5, 0.3, 0.7, 0.15, 0.85]:
			var mx: float = _shifted(lerpf(sa.x, sb.x, share), shift, sa.x, na.x, sb.x, nb.x)
			if (mx - sa.x) * na.x >= 0.0 and (mx - sb.x) * nb.x >= 0.0:
				routes.append(PackedVector2Array([pa, sa, Vector2(mx, sa.y), Vector2(mx, sb.y), sb, pb]))
	elif not a_across and not b_across:
		for share: float in [0.5, 0.3, 0.7, 0.15, 0.85]:
			var my: float = _shifted(lerpf(sa.y, sb.y, share), shift, sa.y, na.y, sb.y, nb.y)
			if (my - sa.y) * na.y >= 0.0 and (my - sb.y) * nb.y >= 0.0:
				routes.append(PackedVector2Array([pa, sa, Vector2(sa.x, my), Vector2(sb.x, my), sb, pb]))
	else:
		var corner: Vector2 = Vector2(sb.x, sa.y) if a_across else Vector2(sa.x, sb.y)
		if (corner - sa).dot(na) >= 0.0 and (corner - sb).dot(nb) >= 0.0:
			routes.append(PackedVector2Array([pa, sa, corner, sb, pb]))
	var best: PackedVector2Array = PackedVector2Array()
	var fewest: int = 1 << 20
	for route: PackedVector2Array in routes:
		var hits: int = _blocked(route, others)
		if hits < fewest:
			fewest = hits
			best = route
		if hits == 0:
			break
	return best


## The middle run at [param middle] moved by [param shift], but no further
## than the stubs' ends [param a] and [param b] allow (the run must lie
## out along both their normals [param na], [param nb]): with many cables
## on one side a large shift would leave no route at all.
static func _shifted(middle: float, shift: float, a: float, na: float, b: float, nb: float) -> float:
	var low: float = -INF
	var high: float = INF
	for end: Vector2 in [Vector2(a, na), Vector2(b, nb)]:
		if end.y > 0.0:
			low = maxf(low, end.x)
		elif end.y < 0.0:
			high = minf(high, end.x)
	if low > high or middle < low or middle > high:
		return middle + shift
	return clampf(middle + shift, low, high)


static func _length(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total


## Where a cable leaves a tile on [param side] at [param t] (0-1) along it:
## on the right past the place's texts, at the bottom under a part's name.
static func _port(tile: Rect2, area: Rect2, side: int, t: float) -> Vector2:
	match side:
		SIDE_LEFT:
			return Vector2(tile.position.x, tile.position.y + tile.size.y * t)
		SIDE_RIGHT:
			return Vector2(area.end.x, tile.position.y + tile.size.y * t)
		SIDE_TOP:
			return Vector2(tile.position.x + tile.size.x * t, tile.position.y)
	return Vector2(tile.position.x + tile.size.x * t, area.end.y)


static func _normal(side: int) -> Vector2:
	return [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN][side]


## [param points] without repeated points and points on a straight line.
static func _straightened(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		if not result.is_empty() and result[result.size() - 1].distance_to(p) < 0.01:
			continue
		if result.size() >= 2:
			var a: Vector2 = result[result.size() - 2]
			var b: Vector2 = result[result.size() - 1]
			if absf((b - a).cross(p - b)) < 0.01:
				result[result.size() - 1] = p
				continue
		result.append(p)
	return result


## [param corners] with every corner rounded off by [param radius] (less
## where the runs beside it are short).
static func _rounded(corners: PackedVector2Array, radius: float) -> PackedVector2Array:
	if corners.size() < 3:
		return corners
	var result: PackedVector2Array = PackedVector2Array([corners[0]])
	for i: int in range(1, corners.size() - 1):
		var p: Vector2 = corners[i]
		var a: Vector2 = corners[i - 1]
		var b: Vector2 = corners[i + 1]
		var r: float = minf(radius, minf(p.distance_to(a), p.distance_to(b)) * 0.5)
		var from: Vector2 = p + (a - p).normalized() * r
		var to: Vector2 = p + (b - p).normalized() * r
		for k: int in 7:
			var t: float = k / 6.0
			result.append(from.lerp(p, t).lerp(p.lerp(to, t), t))
	result.append(corners[corners.size() - 1])
	return result


## How many points of [param points] (sampled along it) lie in [param rects].
static func _blocked(points: PackedVector2Array, rects: Array[Rect2]) -> int:
	var hits: int = 0
	for i: int in points.size() - 1:
		for k: int in 8:
			var at: Vector2 = points[i].lerp(points[i + 1], k / 8.0)
			for rect: Rect2 in rects:
				if rect.has_point(at):
					hits += 1
	return hits


## The tile of a place or part (not its texts).
static func _tile_rect(item: Dictionary) -> Rect2:
	var rect: Rect2 = item["rect"]
	if item["kind"] == "field":
		return Rect2(rect.position + Vector2((rect.size.x - Workspace.FIELD_TILE) * 0.5, 0.0), Vector2(Workspace.FIELD_TILE, Workspace.FIELD_TILE))
	return Rect2(rect.position, Vector2(Workspace.TILE, Workspace.TILE))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK


## Everything on the workspace, groups first (drawn under the rest): each
## {"key", "kind" ("switchboard", "station", "group", "field"), "index" (in
## its list; -1 for a part in the field), "name" (place name or designation),
## "rect" (workspace units, while dragging where it is dragged to), "tile"
## ([enum WorkspaceTile.Kind])}.
func items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if document == null:
		return result
	var positions: Dictionary[String, Vector2] = _positions()
	for g: int in document.groups.size():
		var group: WorkspaceGroup = document.groups[g]
		var rect: Rect2 = Workspace.group_rect(group, positions)
		var empty: bool = true
		for member: String in group.members:
			empty = empty and not positions.has(member)
		if empty:
			# A frame without members is dragged by its own position.
			rect.position = _moved("+" + group.name, group.position)
		result.append({"key": "+" + group.name, "kind": "group", "index": g, "name": group.name, "rect": rect, "tile": WorkspaceTile.Kind.GROUP})
	for b: int in document.switchboards.size():
		var board: Switchboard = document.switchboards[b]
		result.append({"key": "+" + board.name, "kind": "switchboard", "index": b, "name": board.name, "rect": Rect2(_moved("+" + board.name, board.position), Workspace.PLACE_SIZE), "tile": WorkspaceTile.Kind.SWITCHBOARD})
	for s: int in document.control_boxes.size():
		var box: ControlBox = document.control_boxes[s]
		var box_size: Vector2 = Workspace.place_size(box)
		if s == _resizing:
			box_size = box.face_size() * _resize_scale
		result.append({"key": "+" + box.name, "kind": "station", "index": s, "name": box.name, "rect": Rect2(_moved("+" + box.name, box.position), box_size), "tile": WorkspaceTile.Kind.STATION})
	for designation: String in positions:
		var c: CircuitComponent = Workspace.field_component(document.circuit, designation)
		result.append({"key": "-" + designation, "kind": "field", "index": -1, "name": designation, "rect": Rect2(positions[designation], Workspace.FIELD_SIZE), "tile": WorkspaceTile.of_part(c)})
	return result


## The item under screen point [param point], {} for none (parts in the
## field before places before groups).
func item_at(point: Vector2) -> Dictionary:
	var at: Vector2 = to_workspace(point)
	var paths: Array[Dictionary] = cable_paths()
	for path: Dictionary in paths:
		if (path["tag"] as Rect2).has_point(at):
			return _cable_item(path)
	var found: Dictionary = _place_at(at)
	if not found.is_empty():
		return found
	# Near a cable's line (a few pixels on the screen).
	var reach: float = 5.0 / zoom
	for path: Dictionary in paths:
		var points: PackedVector2Array = path["points"]
		for i: int in points.size() - 1:
			if Geometry2D.get_closest_point_to_segment(at, points[i], points[i + 1]).distance_to(at) <= reach:
				return _cable_item(path)
	return {}


## A cable under the mouse tells its name, type and ends.
func _get_tooltip(at_position: Vector2) -> String:
	var found: Dictionary = item_at(at_position)
	if found.get("kind", "") != "cable":
		return ""
	for cable: Dictionary in cables():
		if cable["key"] == found["name"]:
			return "%s  %s\n%s – %s" % [cable["name"], WorkspaceCables.type_and_length(cable), cable["a"], cable["b"]]
	return ""


func _cable_item(path: Dictionary) -> Dictionary:
	return {"key": "=" + str(path["cable"]["key"]), "kind": "cable", "index": -1, "name": path["cable"]["key"], "rect": path["tag"], "tile": -1}


## The place, part or group at workspace point [param at], {} for none.
func _place_at(at: Vector2) -> Dictionary:
	var list: Array[Dictionary] = items()
	for i: int in range(list.size() - 1, -1, -1):
		var rect: Rect2 = list[i]["rect"]
		if list[i]["kind"] == "group":
			# A group answers on its heading and frame, not over its members.
			if rect.has_point(at) and not rect.grow(-Workspace.GROUP_PAD * 0.5).has_point(at) or Rect2(rect.position, Vector2(rect.size.x, Workspace.GROUP_HEAD)).has_point(at):
				return list[i]
		elif rect.has_point(at):
			return list[i]
	return {}


func to_workspace(point: Vector2) -> Vector2:
	return (point - offset) / zoom


## What everything covers (places, parts, groups, cables and their tags),
## in workspace units; empty without anything.
func bounds() -> Rect2:
	var result: Rect2 = Rect2()
	var first: bool = true
	for item: Dictionary in items():
		result = item["rect"] if first else result.merge(item["rect"])
		first = false
	if first:
		return result
	for path: Dictionary in cable_paths():
		result = result.merge(path["tag"])
		for point: Vector2 in path["points"]:
			result = result.expand(point)
	return result


## Shows everything, as large as fits (at most 125 %).
func fit() -> void:
	var area: Rect2 = bounds()
	if not area.has_area() or size.x < 10.0 or size.y < 10.0:
		zoom = 1.0
		offset = Vector2(40.0, 40.0)
		queue_redraw()
		return
	area = area.grow(40.0)
	zoom = clampf(minf(size.x / area.size.x, size.y / area.size.y), MIN_ZOOM, 1.25)
	offset = size * 0.5 - area.get_center() * zoom
	queue_redraw()


## Centres the view on item [param key] and selects it.
func show_item(key: String) -> void:
	for item: Dictionary in items():
		if item["key"] == key:
			selected = key
			offset = size * 0.5 - (item["rect"] as Rect2).get_center() * zoom
			queue_redraw()
			return


func _process(delta: float) -> void:
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# The release went elsewhere: drop it where it is.
		_drop()
	# Motors turning while simulating: their marks go round.
	var turning: bool = false
	if not editing and document != null and is_visible_in_tree():
		for designation: String in Workspace.field_devices(document.circuit):
			var share: float = motor_turn(designation)
			if share != 0.0:
				_spin[designation] = fmod(_spin.get(designation, 0.0) + share * SPIN_RATE * TAU * delta, TAU)
				turning = true
	if turning or _spinning:
		queue_redraw()
	_spinning = turning
	if not editing:
		# Lamps and buttons of the stations shown as their face follow the simulation.
		for face: ControlBoxView in _faces.values():
			face.queue_redraw()


## How fast motor [param designation] in the field turns while simulating:
## a share of its rated speed, clockwise positive (a 1~ motor 1 while it
## has power); 0 standing still and while editing.
func motor_turn(designation: String) -> float:
	if editing or document == null:
		return 0.0
	var c: CircuitComponent = Workspace.field_component(document.circuit, designation)
	if c is ThreePhaseMotor:
		return (c as ThreePhaseMotor).top_speed_share()
	if c is Motor:
		return 1.0 if (c as Motor).energized and not (c as Motor).burnt else 0.0
	return 0.0


# --- Input -----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		_on_button(mb)
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	if _pan_button != MOUSE_BUTTON_NONE:
		if motion.position.distance_to(_pan_from) >= SchematicEditor.CLICK_SLOP:
			_panned = true
		if _panned:
			offset += motion.relative
			queue_redraw()
	elif _resizing >= 0:
		var box: ControlBox = document.control_boxes[_resizing]
		_resize_scale = ControlBox.valid_face((to_workspace(motion.position).x - box.position.x) / box.face_size().x)
		queue_redraw()
	elif not _press.is_empty():
		if not _dragging and editing and _press["kind"] != "cable" and motion.position.distance_to(_press_at) >= SchematicEditor.CLICK_SLOP:
			_dragging = true
		if _dragging:
			_drag = ((motion.position - _press_at) / zoom).snappedf(SNAP)
			queue_redraw()
	else:
		var hover: Dictionary = item_at(motion.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hover.is_empty() and (hover["kind"] in ["switchboard", "station", "cable"] or editing) else Control.CURSOR_ARROW
	accept_event()


func _on_button(mb: InputEventMouseButton) -> void:
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_zoom_at(mb.position, ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_pan_button = mb.button_index
				_pan_from = mb.position
				_panned = false
			elif mb.button_index == _pan_button:
				_pan_button = MOUSE_BUTTON_NONE
				if mb.button_index == MOUSE_BUTTON_RIGHT and not _panned:
					var item: Dictionary = item_at(mb.position)
					if not item.is_empty():
						selected = item["key"]
						queue_redraw()
					menu_requested.emit(item, to_workspace(mb.position))
		MOUSE_BUTTON_LEFT:
			if mb.pressed and editing and _handle_at(mb.position) >= 0:
				_resizing = _handle_at(mb.position)
				_resize_scale = document.control_boxes[_resizing].face_scale
				return
			if not mb.pressed and _resizing >= 0:
				var index: int = _resizing
				var scale: float = _resize_scale
				_resizing = -1
				queue_redraw()
				if not is_equal_approx(scale, document.control_boxes[index].face_scale):
					edit_requested.emit(func(doc: SchematicDocument) -> void: doc.set_station_face(index, scale))
				return
			if mb.pressed:
				_press = item_at(mb.position)
				_press_at = mb.position
				_drag = Vector2.ZERO
				_dragging = false
				selected = _press.get("key", "")
				queue_redraw()
			elif _dragging:
				_drop()
			elif not _press.is_empty():
				var item: Dictionary = _press
				_press = {}
				if item["kind"] == "station" and not editing and document.control_boxes[item["index"]].face_scale > 0.0:
					# Its face is operated where it is (its menu still opens it).
					pass
				elif item["kind"] == "switchboard" or item["kind"] == "station":
					open_requested.emit(Workspace.Place.SWITCHBOARD if item["kind"] == "switchboard" else Workspace.Place.STATION, item["name"])
				elif item["kind"] == "cable":
					cable_requested.emit(item["name"])


## Station whose resize handle (the bottom right corner of its face, while
## selected) is under screen point [param point], -1 for none.
func _handle_at(point: Vector2) -> int:
	for item: Dictionary in items():
		if item["kind"] == "station" and selected == item["key"] and document.control_boxes[item["index"]].face_scale > 0.0:
			var corner: Vector2 = offset + (item["rect"] as Rect2).end * zoom
			if point.distance_to(corner) <= HANDLE:
				return item["index"]
	return -1


func _zoom_at(point: Vector2, factor: float) -> void:
	var at: Vector2 = to_workspace(point)
	zoom = clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	offset = point - at * zoom
	queue_redraw()


## Ends a drag: the item moves where it was dragged (one undoable edit).
func _drop() -> void:
	var item: Dictionary = _press
	var by: Vector2 = _drag
	_press = {}
	_dragging = false
	_drag = Vector2.ZERO
	queue_redraw()
	if item.is_empty() or by == Vector2.ZERO:
		return
	var to: Vector2 = (item["rect"] as Rect2).position + by
	var index: int = item["index"]
	match item["kind"]:
		"switchboard":
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_place(Workspace.Place.SWITCHBOARD, index, to))
		"station":
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_place(Workspace.Place.STATION, index, to))
		"group":
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.move_place(Workspace.Place.GROUP, index, to))
		"field":
			var designation: String = item["name"]
			var group: int = _group_under(designation, Rect2(to, Workspace.FIELD_SIZE).get_center())
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.place_field_device(designation, to, group))


## The group whose frame (without part [param designation]) holds
## [param point], -1 for none.
func _group_under(designation: String, point: Vector2) -> int:
	var positions: Dictionary[String, Vector2] = Workspace.field_positions(document)
	positions.erase(designation)
	for g: int in range(document.groups.size() - 1, -1, -1):
		var group: WorkspaceGroup = document.groups[g]
		var others: WorkspaceGroup = WorkspaceGroup.new(group.name, group.position)
		for member: String in group.members:
			if member != designation:
				others.members.append(member)
		if Workspace.group_rect(others, positions).has_point(point):
			return g
	return -1


## Where the parts in the field are drawn: a dragged part, or the members of
## a dragged group, where they are dragged to.
func _positions() -> Dictionary[String, Vector2]:
	var positions: Dictionary[String, Vector2] = Workspace.field_positions(document)
	if not _dragging:
		return positions
	if _press["kind"] == "field" and positions.has(_press["name"]):
		positions[_press["name"]] += _drag
	elif _press["kind"] == "group":
		for member: String in document.groups[_press["index"]].members:
			if positions.has(member):
				positions[member] += _drag
	return positions


func _moved(key: String, at: Vector2) -> Vector2:
	return at + _drag if _dragging and _press.get("key", "") == key else at


# --- Drawing --------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SchematicTheme.BACKGROUND)
	if document == null:
		_place_faces([])
		return
	var list: Array[Dictionary] = items()
	if list.is_empty():
		# The faces of stations of another document go too.
		_place_faces([])
		var font: Font = get_theme_font("font", "Label")
		var hint: String = tr("Add a switchboard or a control station with the buttons above.") if editing else tr("The workspace is empty. Add switchboards and control stations in Edit mode.")
		draw_string(font, Vector2(0.0, size.y * 0.5), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, get_theme_font_size("font_size", "Label"), SchematicTheme.PATH_TEXT)
		return
	draw_set_transform(offset, 0.0, Vector2(zoom, zoom))
	for item: Dictionary in list:
		if item["kind"] == "group":
			_draw_group(item)
	var paths: Array[Dictionary] = cable_paths()
	var control: Color = SchematicTheme.LINE.lerp(SchematicTheme.BACKGROUND, 0.3)
	for path: Dictionary in paths:
		var on: bool = selected == "=" + str(path["cable"]["key"])
		var color: Color = SchematicTheme.SELECTED if on else (SchematicTheme.LINE if path["power"] else (SchematicTheme.NETWORK if path["network"] else control))
		draw_polyline(path["points"], color, (POWER_WIDTH if path["power"] else CABLE_WIDTH) + (1.0 if on else 0.0), true)
		# A dot where it leaves each end, like a gland.
		for port: Vector2 in path["ports"]:
			draw_circle(port, 2.5, color, true, -1.0, true)
	_draw_links(list)
	for item: Dictionary in list:
		match item["kind"]:
			"group":
				pass
			"field":
				_draw_field(item)
			_:
				_draw_place(item)
	var font: Font = AppTheme.schematic_font()
	for path: Dictionary in paths:
		var on: bool = selected == "=" + str(path["cable"]["key"])
		var tag: Rect2 = path["tag"]
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = SchematicTheme.BACKGROUND
		box.border_color = SchematicTheme.SELECTED if on else SchematicTheme.LINE
		box.set_border_width_all(2 if on else 1)
		box.set_corner_radius_all(4)
		box.anti_aliasing = true
		box.draw(get_canvas_item(), tag)
		draw_multiline_string(font, Vector2(tag.position.x, tag.position.y + 12.0), path["text"], HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, SMALL_SIZE, -1, SchematicTheme.TEXT)
	draw_set_transform(Vector2.ZERO)
	_place_faces(list)


## Around a station shown as its face (drawn by its [ControlBoxView] over
## the canvas): its name above it, the selection and, while editing, the
## handle resizing it.
func _draw_face_frame(item: Dictionary) -> void:
	var rect: Rect2 = item["rect"]
	var font: Font = AppTheme.schematic_font()
	draw_string(font, rect.position + Vector2(0.0, -6.0), "+" + str(item["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, SchematicTheme.DESIGNATION)
	if selected == item["key"]:
		draw_rect(rect.grow(4.0), SchematicTheme.SELECTED, false, 2.0, true)
		if editing:
			var corner: Vector2 = rect.end + Vector2(4.0, 4.0)
			draw_colored_polygon(PackedVector2Array([corner, corner - Vector2(12.0, 0.0), corner - Vector2(0.0, 12.0)]), SchematicTheme.SELECTED)


## Puts a [ControlBoxView] over each station shown as its face, at its place
## and scale; the others go. While simulating its buttons and switches work.
func _place_faces(list: Array[Dictionary]) -> void:
	var shown: Dictionary[String, bool] = {}
	for item: Dictionary in list:
		if item["kind"] != "station":
			continue
		var box: ControlBox = document.control_boxes[item["index"]]
		if box.face_scale <= 0.0:
			continue
		shown[box.name] = true
		var face: ControlBoxView = _faces.get(box.name, null)
		if face == null:
			face = ControlBoxView.new()
			face.button_held.connect(func(designation: String, pressed: bool) -> void: button_held.emit(designation, pressed))
			face.switch_toggled.connect(func(designation: String, steps: int) -> void: switch_toggled.emit(designation, steps))
			add_child(face)
			_faces[box.name] = face
		face.document = document
		face.box_index = item["index"]
		face.simulating = not editing
		face.show_keys = show_keys
		# Editing: the canvas takes the clicks (select, drag, open); simulating,
		# the face takes those on its buttons and passes on the rest.
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE if editing else Control.MOUSE_FILTER_PASS
		var rect: Rect2 = item["rect"]
		var face_size: Vector2 = box.face_size()
		face.size = face_size
		face.position = offset + rect.position * zoom
		face.scale = Vector2.ONE * (rect.size.x / face_size.x) * zoom
		face.queue_redraw()
	for name: String in _faces.keys():
		if not shown.has(name):
			_faces[name].queue_free()
			_faces.erase(name)


## The mechanical links of groups: a dashed line (IEC mechanical link) from
## the motor to each limit switch its part operates; like the simulation
## (see [method Workspace.travels]), only between members of the group.
func _draw_links(list: Array[Dictionary]) -> void:
	var tiles: Dictionary[String, Rect2] = {}
	for item: Dictionary in list:
		if item["kind"] == "field":
			tiles[item["name"]] = _tile_rect(item)
	for group: WorkspaceGroup in document.groups:
		if group.drive.is_empty() or not tiles.has(group.drive) or not group.members.has(group.drive):
			continue
		for designation: String in group.stops:
			if tiles.has(designation) and group.members.has(designation):
				draw_dashed_line(tiles[group.drive].get_center(), tiles[designation].get_center(), SchematicTheme.LINE, 1.5, 6.0, true, true)


func _draw_group(item: Dictionary) -> void:
	var group: WorkspaceGroup = document.groups[item["index"]]
	var rect: Rect2 = item["rect"]
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = SchematicTheme.GROUP_FILL
	box.border_color = SchematicTheme.SELECTED if selected == item["key"] else SchematicTheme.GROUP_EDGE
	box.set_border_width_all(2 if selected == item["key"] else 1)
	box.set_corner_radius_all(12)
	box.anti_aliasing = true
	box.draw(get_canvas_item(), rect)
	var font: Font = AppTheme.schematic_font()
	var at: Vector2 = rect.position + Vector2(12.0, 18.0)
	draw_string(font, at, "+" + group.name, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE + 1, SchematicTheme.DESIGNATION)
	at.x += font.get_string_size("+" + group.name, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE + 1).x + 8.0
	draw_string(font, at, group.title if not group.title.is_empty() else tr("Group"), HORIZONTAL_ALIGNMENT_LEFT, rect.end.x - at.x - 8.0, TEXT_SIZE, SchematicTheme.PATH_TEXT)
	if group.members.has(group.drive):
		# The way the part travels along the bottom of the frame: a tick for
		# each limit switch, the part where it starts (or is, while simulating).
		var from: Vector2 = Vector2(rect.position.x + 14.0, rect.end.y - 9.0)
		var length: float = rect.size.x - 28.0
		draw_line(from, from + Vector2(length, 0.0), SchematicTheme.GROUP_EDGE, 4.0, true)
		for designation: String in group.stops:
			if not group.members.has(designation):
				continue
			var x: float = from.x + length * group.stops[designation]
			draw_line(Vector2(x, from.y - 5.0), Vector2(x, from.y + 5.0), SchematicTheme.LINE, 1.5, true)
		var simulating: bool = travel_positions.has(group.name)
		var at_x: float = from.x + length * (travel_positions[group.name] if simulating else group.start)
		if simulating:
			draw_line(from, Vector2(at_x, from.y), SchematicTheme.SELECTED, 4.0, true)
		draw_circle(Vector2(at_x, from.y), 4.5, SchematicTheme.SELECTED if simulating else SchematicTheme.BACKGROUND, true, -1.0, true)
		draw_circle(Vector2(at_x, from.y), 4.5, SchematicTheme.SELECTED, false, 1.5, true)


func _draw_place(item: Dictionary) -> void:
	var rect: Rect2 = item["rect"]
	if item["kind"] == "station" and document.control_boxes[item["index"]].face_scale > 0.0:
		_draw_face_frame(item)
		return
	var tile: Rect2 = Rect2(rect.position, Vector2(Workspace.TILE, Workspace.TILE))
	if selected == item["key"]:
		draw_rect(tile.grow(4.0), SchematicTheme.SELECTED, false, 2.0, true)
	WorkspaceTile.draw(self, item["tile"], tile)
	var font: Font = AppTheme.schematic_font()
	var x: float = tile.end.x + 12.0
	var w: float = rect.end.x - x
	var title: String
	var summary: String
	if item["kind"] == "switchboard":
		var board: Switchboard = document.switchboards[item["index"]]
		title = board.title if not board.title.is_empty() else tr("Switchboard")
		var devices: int = 0
		var strips: int = 0
		for rail: CabinetRail in board.rails:
			for place: CabinetItem in rail.items:
				if place.kind == CabinetItem.Kind.STRIP:
					strips += 1
				else:
					devices += 1
		summary = tr_n("%d device", "%d devices", devices) % devices + ", " + tr_n("%d terminal strip", "%d terminal strips", strips) % strips
		if not board.door.items.is_empty():
			# And what is on its door.
			summary += ", " + tr_n("%d item", "%d items", board.door.items.size()) % board.door.items.size()
	else:
		var box: ControlBox = document.control_boxes[item["index"]]
		title = box.title if not box.title.is_empty() else tr("Control station")
		summary = tr_n("%d item", "%d items", box.items.size()) % box.items.size()
	# The texts on paper, over any cable passing behind them.
	draw_rect(Rect2(tile.end.x + 4.0, rect.position.y, rect.end.x - tile.end.x - 4.0, rect.size.y), SchematicTheme.BACKGROUND)
	draw_string(font, Vector2(x, rect.position.y + 17.0), "+" + str(item["name"]), HORIZONTAL_ALIGNMENT_LEFT, w, NAME_SIZE, SchematicTheme.DESIGNATION)
	draw_string(font, Vector2(x, rect.position.y + 34.0), title, HORIZONTAL_ALIGNMENT_LEFT, w, TEXT_SIZE, SchematicTheme.TEXT)
	var keys: PackedStringArray = PackedStringArray()
	if show_keys:
		var items: Array[ControlBoxItem] = document.control_boxes[item["index"]].items if item["kind"] == "station" else document.switchboards[item["index"]].door.items
		for station_item: ControlBoxItem in items:
			var key: String = document.key_bindings.get(station_item.designation, "") if station_item.kind != ControlBoxItem.Kind.LAMP else ""
			if not key.is_empty():
				keys.append(key)
	if keys.is_empty():
		draw_string(font, Vector2(x, rect.position.y + 50.0), summary, HORIZONTAL_ALIGNMENT_LEFT, w, SMALL_SIZE, SchematicTheme.PATH_TEXT)
	else:
		# The keys that operate its buttons and switches, in place of the summary.
		var at: Vector2 = Vector2(x, rect.position.y + 40.0)
		for key: String in keys:
			if at.x + Keycap.size_of(key, 10).x > rect.end.x:
				break
			at.x = Keycap.draw(self, at, key, 10).end.x + 3.0


func _draw_field(item: Dictionary) -> void:
	var rect: Rect2 = item["rect"]
	var tile: Rect2 = Rect2(rect.position + Vector2((rect.size.x - Workspace.FIELD_TILE) * 0.5, 0.0), Vector2(Workspace.FIELD_TILE, Workspace.FIELD_TILE))
	if selected == item["key"]:
		if item["tile"] == WorkspaceTile.Kind.MOTOR:
			draw_arc(tile.get_center(), tile.size.x * 0.5 + 4.0, 0.0, TAU, 48, SchematicTheme.SELECTED, 2.0, true)
		else:
			draw_rect(tile.grow(4.0), SchematicTheme.SELECTED, false, 2.0, true)
	WorkspaceTile.draw(self, item["tile"], tile)
	if item["tile"] == WorkspaceTile.Kind.MOTOR and motor_turn(item["name"]) != 0.0:
		# Three marks going round on the ring of the motor's sign.
		var turn: float = _spin.get(item["name"], 0.0)
		var radius: float = tile.size.x * 10.5 / 32.0
		for i: int in 3:
			var start: float = turn + i * TAU / 3.0
			draw_arc(tile.get_center(), radius, start, start + 0.7, 8, SchematicTheme.CURRENT, WorkspaceTile.SIGN_WIDTH * tile.size.x / 32.0 * 1.8, true)
	var font: Font = AppTheme.schematic_font()
	draw_string(font, Vector2(rect.position.x, tile.end.y + 16.0), "-" + str(item["name"]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, TEXT_SIZE + 1, SchematicTheme.DESIGNATION)
	draw_string(font, Vector2(rect.position.x, tile.end.y + 30.0), tr(field_title(item["tile"])), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, SMALL_SIZE, SchematicTheme.PATH_TEXT)


## English name of a part in the field by its tile (translated by the caller).
static func field_title(tile: WorkspaceTile.Kind) -> String:
	match tile:
		WorkspaceTile.Kind.LIMIT_SWITCH:
			return "Limit switch"
		WorkspaceTile.Kind.SENSOR:
			return "Sensor"
		WorkspaceTile.Kind.INDUCTIVE:
			return "Inductive sensor"
		WorkspaceTile.Kind.CAPACITIVE:
			return "Capacitive sensor"
		WorkspaceTile.Kind.MAGNETIC:
			return "Magnetic sensor"
		WorkspaceTile.Kind.LIGHT:
			return "Light sensor"
		WorkspaceTile.Kind.PRESSURE:
			return "Pressure"
		WorkspaceTile.Kind.LEVEL:
			return "Level"
		WorkspaceTile.Kind.FLOW:
			return "Flow"
		WorkspaceTile.Kind.TEMPERATURE:
			return "Temperature"
	return "Motor"
