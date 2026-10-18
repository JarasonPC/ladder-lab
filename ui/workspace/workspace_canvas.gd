class_name WorkspaceCanvas
extends Control
## The workspace on schematic paper: switchboards and control stations as
## solid tiles with their names, parts in the field (motors, limit switches,
## temperature sensors) as smaller tiles, groups as frames round their
## members, the cables between them (see [WorkspaceCables]) as lines with
## their name, bent round tiles in their way. A click on a switchboard or
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

const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 3.0
const ZOOM_STEP: float = 1.15
## Positions snap to this many units.
const SNAP: float = 4.0
const NAME_SIZE: int = 15
const TEXT_SIZE: int = 12
const SMALL_SIZE: int = 11
const CABLE_WIDTH: float = 2.5
## Room kept round tiles a cable passes by.
const CABLE_CLEARANCE: float = 8.0

var document: SchematicDocument
## Things are dragged only while editing.
var editing: bool = false
var zoom: float = 1.0
## Screen position of the workspace origin.
var offset: Vector2 = Vector2(40.0, 40.0)
## Key of the selected item (see [method items]), "" for none.
var selected: String = ""

## Item under the left press, its press position (screen) and how far it was dragged (workspace units).
var _press: Dictionary = {}
var _press_at: Vector2 = Vector2.ZERO
var _drag: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _pan_button: MouseButton = MOUSE_BUTTON_NONE
var _pan_from: Vector2 = Vector2.ZERO
var _panned: bool = false
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
## "text"}; straight from tile to tile, bent when a tile is in its way.
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
	var font: Font = AppTheme.schematic_font()
	for cable: Dictionary in cables():
		if not tiles.has(cable["a"]) or not tiles.has(cable["b"]):
			continue
		var a: Vector2 = tiles[cable["a"]].get_center()
		var b: Vector2 = tiles[cable["b"]].get_center()
		var others: Array[Rect2] = []
		for key: String in areas:
			if key != cable["a"] and key != cable["b"]:
				others.append(areas[key].grow(CABLE_CLEARANCE))
		var points: PackedVector2Array = PackedVector2Array([a, b])
		if _blocked(points, others) > 0:
			# Bent to the side where fewer tiles are in the way.
			var normal: Vector2 = (b - a).orthogonal().normalized()
			var bend: float = clampf(a.distance_to(b) * 0.35, 40.0, 180.0)
			var best: int = 1 << 20
			for side: float in [-1.0, 1.0, -2.0, 2.0]:
				var curve: PackedVector2Array = _curve(a, b, (a + b) * 0.5 + normal * bend * side)
				var hits: int = _blocked(curve, others)
				if hits < best:
					best = hits
					points = curve
				if hits == 0:
					break
		var middle: Vector2 = points[int(points.size() / 2.0)] if points.size() > 2 else _middle_between(a, b, areas[cable["a"]], areas[cable["b"]])
		var text: String = "%s · %s" % [cable["name"], WorkspaceCables.cores_text(cable)]
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x + 10.0
		result.append({"cable": cable, "points": points, "tag": Rect2(middle - Vector2(w, 16.0) * 0.5, Vector2(w, 16.0)), "text": text})
	return result


## The middle of the part of the line [param a]-[param b] outside both
## places [param area_a] and [param area_b] (where its tag goes).
static func _middle_between(a: Vector2, b: Vector2, area_a: Rect2, area_b: Rect2) -> Vector2:
	var from: float = 0.0
	var to: float = 1.0
	for k: int in 65:
		var t: float = k / 64.0
		if area_a.has_point(a.lerp(b, t)):
			from = t
	for k: int in range(64, -1, -1):
		var t: float = k / 64.0
		if area_b.has_point(a.lerp(b, t)):
			to = t
	if to <= from:
		return (a + b) * 0.5
	return a.lerp(b, (from + to) * 0.5)


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


static func _curve(a: Vector2, b: Vector2, control: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 25:
		var t: float = i / 24.0
		points.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	return points


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
		result.append({"key": "+" + group.name, "kind": "group", "index": g, "name": group.name, "rect": Workspace.group_rect(group, positions), "tile": WorkspaceTile.Kind.GROUP})
	for b: int in document.switchboards.size():
		var board: Switchboard = document.switchboards[b]
		result.append({"key": "+" + board.name, "kind": "switchboard", "index": b, "name": board.name, "rect": Rect2(_moved("+" + board.name, board.position), Workspace.PLACE_SIZE), "tile": WorkspaceTile.Kind.SWITCHBOARD})
	for s: int in document.control_boxes.size():
		var box: ControlBox = document.control_boxes[s]
		result.append({"key": "+" + box.name, "kind": "station", "index": s, "name": box.name, "rect": Rect2(_moved("+" + box.name, box.position), Workspace.PLACE_SIZE), "tile": WorkspaceTile.Kind.STATION})
	for designation: String in positions:
		var c: CircuitComponent = Workspace.field_component(document.circuit, designation)
		result.append({"key": "-" + designation, "kind": "field", "index": -1, "name": designation, "rect": Rect2(positions[designation], Workspace.FIELD_SIZE), "tile": WorkspaceTile.of_field(Workspace.field_kind(c))})
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


## Shows everything, as large as fits (at most 125 %).
func fit() -> void:
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for item: Dictionary in items():
		bounds = item["rect"] if first else bounds.merge(item["rect"])
		first = false
	if first or size.x < 10.0 or size.y < 10.0:
		zoom = 1.0
		offset = Vector2(40.0, 40.0)
		queue_redraw()
		return
	bounds = bounds.grow(40.0)
	zoom = clampf(minf(size.x / bounds.size.x, size.y / bounds.size.y), MIN_ZOOM, 1.25)
	offset = size * 0.5 - bounds.get_center() * zoom
	queue_redraw()


## Centres the view on item [param key] and selects it.
func show_item(key: String) -> void:
	for item: Dictionary in items():
		if item["key"] == key:
			selected = key
			offset = size * 0.5 - (item["rect"] as Rect2).get_center() * zoom
			queue_redraw()
			return


func _process(_delta: float) -> void:
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# The release went elsewhere: drop it where it is.
		_drop()


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
				if item["kind"] == "switchboard" or item["kind"] == "station":
					open_requested.emit(Workspace.Place.SWITCHBOARD if item["kind"] == "switchboard" else Workspace.Place.STATION, item["name"])
				elif item["kind"] == "cable":
					cable_requested.emit(item["name"])


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
		return
	var list: Array[Dictionary] = items()
	if list.is_empty():
		var font: Font = get_theme_font("font", "Label")
		var hint: String = tr("Add a switchboard or a control station with the buttons above.") if editing else tr("The workspace is empty. Add switchboards and control stations in Edit mode.")
		draw_string(font, Vector2(0.0, size.y * 0.5), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, get_theme_font_size("font_size", "Label"), SchematicTheme.PATH_TEXT)
		return
	draw_set_transform(offset, 0.0, Vector2(zoom, zoom))
	for item: Dictionary in list:
		if item["kind"] == "group":
			_draw_group(item)
	var paths: Array[Dictionary] = cable_paths()
	for path: Dictionary in paths:
		var on: bool = selected == "=" + str(path["cable"]["key"])
		draw_polyline(path["points"], SchematicTheme.SELECTED if on else SchematicTheme.LINE, CABLE_WIDTH + (1.0 if on else 0.0), true)
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
		draw_string(font, Vector2(tag.position.x, tag.position.y + 12.0), path["text"], HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, SMALL_SIZE, SchematicTheme.TEXT)
	draw_set_transform(Vector2.ZERO)


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


func _draw_place(item: Dictionary) -> void:
	var rect: Rect2 = item["rect"]
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
	else:
		var box: ControlBox = document.control_boxes[item["index"]]
		title = box.title if not box.title.is_empty() else tr("Control station")
		summary = tr_n("%d item", "%d items", box.items.size()) % box.items.size()
	# The texts on paper, over any cable passing behind them.
	draw_rect(Rect2(tile.end.x + 4.0, rect.position.y, rect.end.x - tile.end.x - 4.0, rect.size.y), SchematicTheme.BACKGROUND)
	draw_string(font, Vector2(x, rect.position.y + 17.0), "+" + str(item["name"]), HORIZONTAL_ALIGNMENT_LEFT, w, NAME_SIZE, SchematicTheme.DESIGNATION)
	draw_string(font, Vector2(x, rect.position.y + 34.0), title, HORIZONTAL_ALIGNMENT_LEFT, w, TEXT_SIZE, SchematicTheme.TEXT)
	draw_string(font, Vector2(x, rect.position.y + 50.0), summary, HORIZONTAL_ALIGNMENT_LEFT, w, SMALL_SIZE, SchematicTheme.PATH_TEXT)


func _draw_field(item: Dictionary) -> void:
	var rect: Rect2 = item["rect"]
	var tile: Rect2 = Rect2(rect.position + Vector2((rect.size.x - Workspace.FIELD_TILE) * 0.5, 0.0), Vector2(Workspace.FIELD_TILE, Workspace.FIELD_TILE))
	if selected == item["key"]:
		if item["tile"] == WorkspaceTile.Kind.MOTOR:
			draw_arc(tile.get_center(), tile.size.x * 0.5 + 4.0, 0.0, TAU, 48, SchematicTheme.SELECTED, 2.0, true)
		else:
			draw_rect(tile.grow(4.0), SchematicTheme.SELECTED, false, 2.0, true)
	WorkspaceTile.draw(self, item["tile"], tile)
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
	return "Motor"
