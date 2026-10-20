class_name FloorPlanCanvas
extends Control
## The floor plan drawn on schematic paper (see [FloorPlan]): rooms with
## their names and areas, doors, the parts at their places with the symbols
## of Czech installation drawings ([PlanSymbols]), their designations and
## any height other than the standard one, the consumer unit and the cables
## worked out from the wiring (a tick per core). Wheel zooms at the mouse,
## right or middle drag pans.
##
## Edit mode, by [member tool]: SELECT drags rooms (with what is in them and
## the doors in their walls), their edges, parts and doors; ROOM draws a room
## by dragging; DOOR puts a door where a wall is clicked; PLACE puts
## [member placing] where it is clicked. Rooms snap to the walls of the
## others, switches, sockets and appliances onto the nearest wall. Delete
## takes the selection away, a double click renames a room. Simulate mode: a
## click on a switch switches its rocker (of two, the one on the side
## clicked); luminaires light up, working appliances and live sockets glow.

## Changes the plan: [param change] is called with the document.
signal edit_requested(change: Callable)
## Rocker [param rocker] of light switch [param designation] was clicked.
signal switch_toggled(designation: String, rocker: int)
## Room [param index] should be renamed.
signal rename_requested(index: int)
## [member placing] was put on the plan.
signal placed
## The consumer unit should open (a click on it while simulating, a double
## click while editing).
signal unit_requested

enum Tool { SELECT, ROOM, DOOR, PLACE }

## Pixels a metre at zoom 1.
const PX: float = 60.0
const MIN_ZOOM: float = 0.2
const MAX_ZOOM: float = 6.0
const ZOOM_STEP: float = 1.15
## Thickness of the walls drawn (m).
const WALL: float = 0.08
## A press this close to a room's edge (pixels) drags the edge.
const EDGE_GRAB: float = 6.0
## A part within this (m) of the mouse is under it.
const PART_GRAB: float = 0.25
## Height of the legend under the plan on a sheet (m).
const LEGEND_HEIGHT: float = 2.6
const LEGEND_WIDTH: float = 16.0
const NAME_SIZE: int = 14
const TEXT_SIZE: int = 11

var document: SchematicDocument
var editing: bool = false
var tool: Tool = Tool.SELECT:
	set(value):
		tool = value
		mouse_default_cursor_shape = Control.CURSOR_CROSS if value != Tool.SELECT else Control.CURSOR_ARROW
## Designation (or [constant FloorPlan.UNIT]) put by a click with Tool.PLACE.
var placing: String = ""
var zoom: float = 1.0
## Screen position of the plan's origin.
var offset: Vector2 = Vector2(60.0, 60.0)
## Drawn for a sheet: the legend of the symbols and the standard heights
## under the plan (see [method paper_area]).
var legend: bool = false
## What is selected: {"kind": "room" / "door" / "part", "index", "designation"}.
var selected: Dictionary = {}

var _press: Dictionary = {}
var _press_at: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _mouse: Vector2 = Vector2.ZERO
var _pan_button: MouseButton = MOUSE_BUTTON_NONE
var _pan_from: Vector2 = Vector2.ZERO


func _ready() -> void:
	focus_mode = Control.FOCUS_CLICK
	clip_contents = true


func plan() -> FloorPlan:
	return document.floor_plan if document != null else null


func to_plan(point: Vector2) -> Vector2:
	return (point - offset) / (PX * zoom)


func to_screen(point: Vector2) -> Vector2:
	return offset + point * PX * zoom


## What a sheet of the plan shows (m): the plan with a margin and, under
## it, room for the legend.
func paper_area() -> Rect2:
	var area: Rect2 = plan().bounds().grow(0.8)
	if not area.has_area():
		area = Rect2(0, 0, 4, 3)
	# The legend's two columns need their width.
	return Rect2(area.position, Vector2(maxf(area.size.x, LEGEND_WIDTH), area.size.y + LEGEND_HEIGHT))


## Shows everything, as large as fits.
func fit() -> void:
	var area: Rect2 = plan().bounds() if plan() != null else Rect2()
	if not area.has_area() or size.x < 10.0:
		zoom = 1.0
		offset = Vector2(60.0, 60.0)
		queue_redraw()
		return
	area = area.grow(1.0)
	zoom = clampf(minf(size.x / (area.size.x * PX), size.y / (area.size.y * PX)), MIN_ZOOM, 2.0)
	offset = size * 0.5 - area.get_center() * PX * zoom
	queue_redraw()


# --- Finding things -------------------------------------------------------------------

## Where part [param designation]'s symbol is centred (m).
func symbol_center(designation: String) -> Vector2:
	var at: Vector2 = plan().parts[designation]
	if not plan().facing.has(designation):
		return at
	var into: Vector2 = FloorPlan.FACING[plan().facing[designation]]
	return at + into * 0.15


## The part under screen point [param point], "" for none.
func part_at(point: Vector2) -> String:
	var m: Vector2 = to_plan(point)
	var best: float = PART_GRAB
	var found: String = ""
	for designation: String in plan().parts:
		var d: float = symbol_center(designation).distance_to(m)
		if d < best:
			best = d
			found = designation
	return found


## The door under screen point [param point], -1 for none.
func door_at(point: Vector2) -> int:
	var m: Vector2 = to_plan(point)
	for i: int in plan().doors.size():
		var door: FloorPlan.Door = plan().doors[i]
		var half: Vector2 = Vector2(0.15, door.width * 0.5) if door.vertical else Vector2(door.width * 0.5, 0.15)
		if Rect2(door.at - half, half * 2.0).has_point(m):
			return i
	return -1


## The edge of a room under screen point [param point]: Vector2i(room, side
## 0 left, 1 top, 2 right, 3 bottom), (-1, -1) for none.
func edge_at(point: Vector2) -> Vector2i:
	var m: Vector2 = to_plan(point)
	var grab: float = EDGE_GRAB / (PX * zoom)
	var inside: int = plan().room_at(m)
	var order: Array[int] = []
	if inside >= 0:
		order.append(inside)
	for i: int in range(plan().rooms.size() - 1, -1, -1):
		if i != inside:
			order.append(i)
	for i: int in order:
		var r: Rect2 = plan().rooms[i].rect
		if not r.grow(grab).has_point(m):
			continue
		var distances: Array[float] = [absf(m.x - r.position.x), absf(m.y - r.position.y), absf(m.x - r.end.x), absf(m.y - r.end.y)]
		for side: int in 4:
			if distances[side] <= grab:
				return Vector2i(i, side)
	return Vector2i(-1, -1)


# --- Input ----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if document == null:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and editing and (key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE):
		delete_selected()
		accept_event()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		_on_button(mb)
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	_mouse = motion.position
	if _pan_button != MOUSE_BUTTON_NONE:
		offset += motion.relative
	elif not _press.is_empty() and not _dragging and motion.position.distance_to(_press_at) >= SchematicEditor.CLICK_SLOP:
		_dragging = true
	elif _press.is_empty():
		var over: String = part_at(motion.position)
		tooltip_text = _tooltip(over) if not over.is_empty() else ""
	if tool != Tool.SELECT or _dragging or _pan_button != MOUSE_BUTTON_NONE:
		queue_redraw()
	accept_event()


func _on_button(mb: InputEventMouseButton) -> void:
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var at: Vector2 = to_plan(mb.position)
				zoom = clampf(zoom * (ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP), MIN_ZOOM, MAX_ZOOM)
				offset = mb.position - at * PX * zoom
				queue_redraw()
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_pan_button = mb.button_index
				_pan_from = mb.position
			elif mb.button_index == _pan_button:
				_pan_button = MOUSE_BUTTON_NONE
				if mb.button_index == MOUSE_BUTTON_RIGHT and mb.position.distance_to(_pan_from) < SchematicEditor.CLICK_SLOP and tool != Tool.SELECT:
					# A right click ends drawing rooms, doors or placing.
					tool = Tool.SELECT
					placing = ""
					queue_redraw()
		MOUSE_BUTTON_LEFT:
			if not editing:
				if mb.pressed:
					_operate(mb.position)
				return
			if mb.pressed and mb.double_click and tool == Tool.SELECT:
				if part_at(mb.position) == FloorPlan.UNIT:
					unit_requested.emit()
					_press = {}
					return
				var room: int = plan().room_at(to_plan(mb.position))
				if room >= 0 and part_at(mb.position).is_empty():
					rename_requested.emit(room)
				_press = {}
				return
			if mb.pressed:
				_press_at = mb.position
				_dragging = false
				_press = _pressed(mb.position)
				if _press["kind"] in ["room", "door", "part", "edge"]:
					selected = _press
				elif tool == Tool.SELECT:
					selected = {}
				queue_redraw()
			elif not _press.is_empty():
				var press: Dictionary = _press
				_press = {}
				_release(press, mb.position)
				_dragging = false
				queue_redraw()


## What a press at [param point] takes hold of.
func _pressed(point: Vector2) -> Dictionary:
	match tool:
		Tool.ROOM:
			return {"kind": "new_room"}
		Tool.DOOR:
			return {"kind": "new_door"}
		Tool.PLACE:
			return {"kind": "new_part"}
	var part: String = part_at(point)
	if not part.is_empty():
		return {"kind": "part", "designation": part}
	var door: int = door_at(point)
	if door >= 0:
		return {"kind": "door", "index": door}
	var edge: Vector2i = edge_at(point)
	if edge.x >= 0:
		return {"kind": "edge", "index": edge.x, "side": edge.y}
	var room: int = plan().room_at(to_plan(point))
	if room >= 0:
		return {"kind": "room", "index": room}
	return {"kind": "empty"}


func _release(press: Dictionary, point: Vector2) -> void:
	var m: Vector2 = to_plan(point)
	var by: Vector2 = FloorPlan.snap(to_plan(point) - to_plan(_press_at))
	match press["kind"]:
		"new_room":
			var rect: Rect2 = _drawn_room()
			if rect.size.x >= FloorPlan.MIN_ROOM and rect.size.y >= FloorPlan.MIN_ROOM:
				var room_name: String = _next_room_name()
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.rooms.append(FloorPlan.Room.new(room_name, rect)))
		"new_door":
			var wall: Dictionary = plan().wall_near(m, 0.3)
			if not wall.is_empty():
				var at: Vector2 = wall["at"]
				var vertical: bool = int(wall["facing"]) % 2 == 0
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.doors.append(FloorPlan.Door.new(at, vertical)))
		"new_part":
			var designation: String = placing
			if not designation.is_empty():
				var ceiling: bool = document.circuit.get_component(designation) is Luminaire
				placing = ""
				tool = Tool.SELECT
				edit_requested.emit(func(doc: SchematicDocument) -> void:
					doc.floor_plan.place(designation, m, ceiling)
					if designation == FloorPlan.UNIT:
						doc.ensure_consumer_unit())
				placed.emit()
		"part":
			if _dragging:
				var designation: String = press["designation"]
				var ceiling: bool = document.circuit.get_component(designation) is Luminaire
				var to: Vector2 = plan().parts[designation] + by
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.place(designation, to, ceiling))
		"door":
			if _dragging:
				var index: int = press["index"]
				var wall: Dictionary = plan().wall_near(m, 0.3)
				if not wall.is_empty():
					var at: Vector2 = wall["at"]
					var vertical: bool = int(wall["facing"]) % 2 == 0
					edit_requested.emit(func(doc: SchematicDocument) -> void:
						doc.floor_plan.doors[index].at = at
						doc.floor_plan.doors[index].vertical = vertical)
		"room":
			if _dragging and by != Vector2.ZERO:
				var index: int = press["index"]
				var to: Rect2 = plan().snap_room(Rect2(plan().rooms[index].rect.position + by, plan().rooms[index].rect.size), index)
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.move_room(index, to.position))
		"edge":
			if _dragging:
				var index: int = press["index"]
				var rect: Rect2 = _resized(index, press["side"])
				edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.rooms[index].rect = rect)


## A click while simulating: a switch's rocker is switched.
func _operate(point: Vector2) -> void:
	var designation: String = part_at(point)
	if designation == FloorPlan.UNIT:
		unit_requested.emit()
		return
	var sw: LightSwitch = document.circuit.get_component(designation) as LightSwitch if not designation.is_empty() else null
	if sw == null:
		return
	var rocker: int = 0
	if sw.rocker_count() > 1:
		var center: Vector2 = to_screen(symbol_center(designation))
		var into: Vector2 = FloorPlan.FACING[plan().facing.get(designation, 1)]
		# Seen from the room, the left rocker is the first.
		rocker = 0 if (point - center).dot(into.rotated(-PI / 2.0)) < 0.0 else 1
	switch_toggled.emit(designation, rocker)


## Takes the selection away: a room (what is in it stays), a door, or a
## part off the plan.
func delete_selected() -> void:
	match selected.get("kind", ""):
		"room", "edge":
			var index: int = selected["index"]
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.rooms.remove_at(index))
		"door":
			var door: int = selected["index"]
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.doors.remove_at(door))
		"part":
			var designation: String = selected["designation"]
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.remove(designation))
	selected = {}
	queue_redraw()


## The room being drawn with Tool.ROOM, snapped.
func _drawn_room() -> Rect2:
	var a: Vector2 = FloorPlan.snap(to_plan(_press_at))
	var b: Vector2 = FloorPlan.snap(to_plan(_mouse))
	var rect: Rect2 = Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
	return _snap_corners(rect)


## [param rect] with each edge snapped onto a near wall of the rooms (but
## room [param skip]).
func _snap_corners(rect: Rect2, skip: int = -1) -> Rect2:
	var edges: Array[float] = [rect.position.x, rect.position.y, rect.end.x, rect.end.y]
	for side: int in 4:
		edges[side] = _snap_edge(edges[side], side % 2 == 1, skip)
	return Rect2(Vector2(edges[0], edges[1]), Vector2(edges[2] - edges[0], edges[3] - edges[1]))


## Coordinate [param v] (y when [param horizontal_edge]) onto the nearest
## wall within [constant FloorPlan.WALL_SNAP].
func _snap_edge(v: float, horizontal_edge: bool, skip: int) -> float:
	var best: float = FloorPlan.WALL_SNAP
	var result: float = v
	for i: int in plan().rooms.size():
		if i == skip:
			continue
		var r: Rect2 = plan().rooms[i].rect
		for theirs: float in ([r.position.y, r.end.y] if horizontal_edge else [r.position.x, r.end.x]):
			if absf(theirs - v) < best:
				best = absf(theirs - v)
				result = theirs
	return result


## Room [param index] with its edge [param side] where the mouse is.
func _resized(index: int, side: int) -> Rect2:
	var r: Rect2 = plan().rooms[index].rect
	var m: Vector2 = FloorPlan.snap(to_plan(_mouse))
	var edges: Array[float] = [r.position.x, r.position.y, r.end.x, r.end.y]
	edges[side] = _snap_edge(m.y if side % 2 == 1 else m.x, side % 2 == 1, index)
	# Never smaller than a room can be, nor turned inside out.
	match side:
		0:
			edges[0] = minf(edges[0], edges[2] - FloorPlan.MIN_ROOM)
		1:
			edges[1] = minf(edges[1], edges[3] - FloorPlan.MIN_ROOM)
		2:
			edges[2] = maxf(edges[2], edges[0] + FloorPlan.MIN_ROOM)
		3:
			edges[3] = maxf(edges[3], edges[1] + FloorPlan.MIN_ROOM)
	return Rect2(Vector2(edges[0], edges[1]), Vector2(edges[2] - edges[0], edges[3] - edges[1]))


func _next_room_name() -> String:
	var n: int = plan().rooms.size() + 1
	return tr("Room %d") % n


func _tooltip(designation: String) -> String:
	if designation == FloorPlan.UNIT:
		return tr("Consumer unit %s") % FloorPlan.UNIT + "\n" + (tr("Double-click to open it") if editing else tr("Click to open it and switch its breakers"))
	var c: CircuitComponent = document.circuit.get_component(designation)
	if c == null:
		return designation
	var text: String = "-" + designation
	if c is LightSwitch:
		text += "  " + PropertiesPanel.light_switch_title((c as LightSwitch).circuit)
		if not editing:
			text += "\n" + tr("Click to switch it")
	elif c is Appliance:
		text += "  " + ApplianceSymbol.kind_title((c as Appliance).kind)
	var height: float = float(c.get("height"))
	return text + "\n" + tr("Mounting height %s m") % String.num(height, 2).pad_decimals(2)


# --- Drawing --------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SchematicTheme.BACKGROUND)
	if document == null:
		return
	var s: float = PX * zoom
	var font: Font = get_theme_default_font()
	if editing:
		_draw_grid(s)
	var rooms: Array[Rect2] = []
	for i: int in plan().rooms.size():
		rooms.append(_shown_room(i))
	for rect: Rect2 in rooms:
		draw_rect(Rect2(to_screen(rect.position), rect.size * s), Color(SchematicTheme.LINE, 0.03))
	var wall: float = maxf(WALL * s, 2.0)
	for i: int in rooms.size():
		var r: Rect2 = Rect2(to_screen(rooms[i].position), rooms[i].size * s)
		var chosen: bool = selected.get("kind", "") in ["room", "edge"] and selected.get("index", -1) == i
		draw_rect(r, SchematicTheme.HOVER if chosen else SchematicTheme.LINE, false, wall)
	for i: int in plan().doors.size():
		_draw_door(plan().doors[i], s, wall, selected.get("kind", "") == "door" and selected.get("index", -1) == i)
	for i: int in rooms.size():
		# Name and area in the room's corner, clear of its ceiling light.
		var room: FloorPlan.Room = plan().rooms[i]
		var corner: Vector2 = to_screen(rooms[i].position) + Vector2(wall + 6.0, wall + 4.0 + font.get_ascent(NAME_SIZE))
		draw_string(font, corner, tr(room.name), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, Color(SchematicTheme.LINE, 0.55))
		var area: String = "%s m²" % String.num(rooms[i].size.x * rooms[i].size.y, 1)
		draw_string(font, corner + Vector2(0, NAME_SIZE + 1), area, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, Color(SchematicTheme.LINE, 0.45))
	_draw_cables(s, font)
	for designation: String in plan().parts:
		_draw_part(designation, s, font)
	if editing and tool == Tool.ROOM and _press.get("kind", "") == "new_room":
		var drawn: Rect2 = _drawn_room()
		draw_rect(Rect2(to_screen(drawn.position), drawn.size * s), SchematicTheme.HOVER, false, wall)
		var dims: String = "%s × %s m" % [String.num(drawn.size.x, 2), String.num(drawn.size.y, 2)]
		draw_string(font, to_screen(drawn.end) + Vector2(6, 0), dims, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.TEXT)
	if editing and tool == Tool.PLACE and not placing.is_empty():
		var m: Vector2 = to_plan(_mouse)
		var wall_point: Dictionary = {} if document.circuit.get_component(placing) is Luminaire else plan().wall_near(m)
		var at: Vector2 = wall_point.get("at", FloorPlan.snap(m))
		draw_circle(to_screen(at), 4.0, SchematicTheme.HOVER)
		draw_string(font, to_screen(at) + Vector2(8, -6), ("-" if placing != FloorPlan.UNIT else "") + placing, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.DESIGNATION)
	if legend:
		_draw_legend(s, font)
	if plan().rooms.is_empty() and editing:
		var hint: String = tr("Draw a room: pick Room and drag, or add one of the ready rooms.")
		draw_string(font, Vector2(20, 30), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, Color(SchematicTheme.LINE, 0.6))


## The legend under the plan: the symbols used and the heights parts are
## mounted at unless another one is written beside them.
func _draw_legend(s: float, font: Font) -> void:
	var area: Rect2 = paper_area()
	var top: Vector2 = to_screen(Vector2(area.position.x + 0.4, area.end.y - LEGEND_HEIGHT + 0.5))
	var color: Color = SchematicTheme.LINE
	draw_string(font, top, tr("Legend"), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, color)
	var rows: Array = [
		["switch", tr("Switch (its number: lines and ticks)"), tr("%s m over the floor") % _num(LightSwitch.STANDARD_HEIGHT)],
		["socket", tr("Socket outlet 230 V with the protective pin"), tr("%s m over the floor") % _num(SocketOutlet.STANDARD_HEIGHT)],
		["luminaire", tr("Luminaire"), tr("on the ceiling, %s m") % _num(Luminaire.STANDARD_HEIGHT)],
		["appliance", tr("Appliance, its connection"), tr("%s m over the floor") % _num(Appliance.STANDARD_HEIGHT)],
		["unit", tr("Consumer unit"), ""],
		["cable", tr("Cable, a tick per core"), ""],
	]
	var width: float = clampf(1.6 * zoom, 1.0, 2.5)
	for i: int in rows.size():
		var column: int = i / 3
		var at: Vector2 = top + Vector2(column * 8.0 * s, (0.45 + (i % 3) * 0.55) * s)
		var symbol: Vector2 = at + Vector2(0.3 * s, -0.08 * s)
		match rows[i][0]:
			"switch":
				PlanSymbols.draw_switch(self, LightSwitch.new("SF0"), symbol + Vector2(0, -0.1 * s), Vector2.DOWN, s, color, width)
			"socket":
				PlanSymbols.draw_socket(self, SocketOutlet.new("XD0"), symbol + Vector2(0, -0.1 * s), Vector2.DOWN, s, color, width, false)
			"luminaire":
				PlanSymbols.draw_luminaire(self, symbol, s, color, width, false)
			"appliance":
				PlanSymbols.draw_appliance(self, Appliance.new("EB0"), symbol + Vector2(0, -0.25 * s), Vector2.DOWN, s * 0.7, color, width, false)
			"unit":
				PlanSymbols.draw_unit(self, symbol + Vector2(0, -0.1 * s), Vector2.DOWN, s * 0.8, color, width)
			"cable":
				draw_dashed_line(symbol - Vector2(0.25 * s, 0), symbol + Vector2(0.25 * s, 0), SchematicTheme.DESIGNATION, 1.4, 6.0)
				for k: int in 3:
					var p: Vector2 = symbol + Vector2((k - 1) * 4.0, 0)
					draw_line(p + Vector2(-3, 5), p + Vector2(3, -5), SchematicTheme.DESIGNATION, 1.2, true)
		var text: String = rows[i][1] + ("  –  " + rows[i][2] if not str(rows[i][2]).is_empty() else "")
		draw_string(font, at + Vector2(0.75 * s, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.TEXT)
	var note: String = tr("Heights are to the middle of the box; a height other than these is written beside the part (h).")
	draw_string(font, top + Vector2(0, 2.0 * s), note, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.TEXT)


static func _num(metres: float) -> String:
	return String.num(metres, 2).pad_decimals(2)


func _draw_grid(s: float) -> void:
	var from: Vector2 = to_plan(Vector2.ZERO).floor()
	var to: Vector2 = to_plan(size).ceil()
	var color: Color = Color(SchematicTheme.LINE, 0.06)
	for x: float in range(int(from.x), int(to.x) + 1):
		draw_line(to_screen(Vector2(x, from.y)), to_screen(Vector2(x, to.y)), color, 1.0)
	for y: float in range(int(from.y), int(to.y) + 1):
		draw_line(to_screen(Vector2(from.x, y)), to_screen(Vector2(to.x, y)), color, 1.0)


## Room [param index] as shown: where it is dragged or resized to.
func _shown_room(index: int) -> Rect2:
	var rect: Rect2 = plan().rooms[index].rect
	if not _dragging or _press.get("index", -1) != index:
		return rect
	match _press.get("kind", ""):
		"room":
			var by: Vector2 = FloorPlan.snap(to_plan(_mouse) - to_plan(_press_at))
			return plan().snap_room(Rect2(rect.position + by, rect.size), index)
		"edge":
			return _resized(index, _press["side"])
	return rect


## Where part [param designation] is shown: where it is dragged to.
func _shown_at(designation: String) -> Vector2:
	var at: Vector2 = plan().parts[designation]
	if _dragging and _press.get("kind", "") == "part" and _press.get("designation", "") == designation:
		return FloorPlan.snap(at + to_plan(_mouse) - to_plan(_press_at))
	if _dragging and _press.get("kind", "") == "room":
		var index: int = _press["index"]
		if plan().rooms[index].rect.grow(0.01).has_point(at):
			return at + _shown_room(index).position - plan().rooms[index].rect.position
	return at


func _draw_door(door: FloorPlan.Door, s: float, wall: float, chosen: bool) -> void:
	var along: Vector2 = Vector2.DOWN if door.vertical else Vector2.RIGHT
	var a: Vector2 = to_screen(door.at - along * door.width * 0.5)
	var b: Vector2 = to_screen(door.at + along * door.width * 0.5)
	# The opening in the wall, the leaf and its swing.
	draw_line(a, b, SchematicTheme.BACKGROUND, wall + 2.0)
	var color: Color = SchematicTheme.HOVER if chosen else Color(SchematicTheme.LINE, 0.7)
	var across: Vector2 = along.rotated(PI / 2.0)
	var leaf: Vector2 = a + across * door.width * s
	draw_line(a, leaf, color, 1.5, true)
	var start: float = (b - a).angle()
	draw_arc(a, door.width * s, start, start + PI / 2.0, 16, color, 1.0, true)
	draw_line(a - along * 2.0, a + along * 2.0, SchematicTheme.LINE, wall)
	draw_line(b - along * 2.0, b + along * 2.0, SchematicTheme.LINE, wall)


func _draw_cables(s: float, font: Font) -> void:
	var color: Color = SchematicTheme.DESIGNATION
	for cable: Dictionary in plan().cables(document.circuit):
		var a: Vector2 = to_screen(_cable_end(cable["a"]))
		var b: Vector2 = to_screen(_cable_end(cable["b"]))
		var corner: Vector2 = Vector2(b.x, a.y)
		draw_dashed_line(a, corner, color, 1.4, 6.0, true, true)
		draw_dashed_line(corner, b, color, 1.4, 6.0, true, true)
		# A tick per core across the longer run, a number past five.
		var longer: PackedVector2Array = PackedVector2Array([a, corner]) if a.distance_to(corner) >= corner.distance_to(b) else PackedVector2Array([corner, b])
		if longer[0].distance_to(longer[1]) < 1.0:
			continue
		var mid: Vector2 = (longer[0] + longer[1]) * 0.5
		var dir: Vector2 = (longer[1] - longer[0]).normalized()
		var tick: Vector2 = dir.rotated(PI / 3.0) * 6.0
		var cores: int = cable["cores"]
		for k: int in mini(cores, 5):
			var p: Vector2 = mid + dir * (k - (mini(cores, 5) - 1) * 0.5) * 4.0
			draw_line(p - tick, p + tick, color, 1.2, true)
		if cores > 5:
			draw_string(font, mid + dir.rotated(PI / 2.0) * 12.0, str(cores), HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)


## Where a cable to [param designation] ends: its symbol (m).
func _cable_end(designation: String) -> Vector2:
	var shown: Vector2 = _shown_at(designation)
	return shown + symbol_center(designation) - plan().parts[designation]


func _draw_part(designation: String, s: float, font: Font) -> void:
	var at: Vector2 = to_screen(_shown_at(designation))
	var into: Vector2 = FloorPlan.FACING[plan().facing[designation]] if plan().facing.has(designation) else Vector2.ZERO
	var chosen: bool = selected.get("kind", "") == "part" and selected.get("designation", "") == designation
	var color: Color = SchematicTheme.HOVER if chosen else SchematicTheme.LINE
	var width: float = clampf(1.6 * zoom, 1.0, 2.5)
	var label: String = designation
	var height_text: String = ""
	if designation == FloorPlan.UNIT:
		PlanSymbols.draw_unit(self, at, into, s, color, width)
	else:
		var c: CircuitComponent = document.circuit.get_component(designation)
		label = "-" + designation
		if c is LightSwitch:
			PlanSymbols.draw_switch(self, c as LightSwitch, at, into, s, color, width)
			if not is_equal_approx((c as LightSwitch).height, LightSwitch.STANDARD_HEIGHT):
				height_text = _height((c as LightSwitch).height)
		elif c is SocketOutlet:
			var socket: SocketOutlet = c as SocketOutlet
			PlanSymbols.draw_socket(self, socket, at, into, s, color, width, not editing and socket.energized)
			if not is_equal_approx(socket.height, SocketOutlet.STANDARD_HEIGHT):
				height_text = _height(socket.height)
		elif c is Luminaire:
			PlanSymbols.draw_luminaire(self, at, s, color, width, not editing and (c as Load).energized)
			if not is_equal_approx((c as Luminaire).height, Luminaire.STANDARD_HEIGHT):
				height_text = _height((c as Luminaire).height)
		elif c is Appliance:
			PlanSymbols.draw_appliance(self, c as Appliance, at, into, s, color, width, not editing and (c as Load).energized)
			if not is_equal_approx((c as Appliance).height, Appliance.STANDARD_HEIGHT):
				height_text = _height((c as Appliance).height)
	# The designation beside the symbol, away from its wall.
	var center: Vector2 = to_screen(_shown_at(designation) + symbol_center(designation) - plan().parts[designation])
	var text_at: Vector2 = center + Vector2(0.22 * s + 2.0, -2.0)
	draw_string(font, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, SchematicTheme.DESIGNATION)
	if not height_text.is_empty():
		draw_string(font, text_at + Vector2(0, TEXT_SIZE), height_text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE - 1, SchematicTheme.TEXT)


static func _height(height: float) -> String:
	return "h %s" % String.num(height, 2).pad_decimals(2)
