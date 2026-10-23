extends GutTest
## Walls of the floor plan: where a wall between two rooms lies (no step
## where a wall goes on outside), each wall's own thickness and placing,
## slanting walls, walls drawn on their own closing into a room and joined
## to the walls they meet, stairs, and what moves along while a room, wall
## or door is dragged.


func _plan() -> FloorPlan:
	var plan: FloorPlan = FloorPlan.new()
	plan.outer_wall = FloorPlan.OUTER_WALL
	plan.inner_wall = FloorPlan.INNER_WALL
	return plan


func _between(plan: FloorPlan) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for piece: Dictionary in plan.wall_pieces():
		if int(piece["other"]) >= 0:
			list.append(piece)
	return list


func test_wall_between_rooms_out_of_the_way_of_one_going_on_outside() -> void:
	var plan: FloorPlan = _plan()
	# A hall whose top wall goes on outside past the kitchen above it.
	plan.rooms.append(FloorPlan.Room.new("Hall", Rect2(3, 2, 5, 1.2)))
	plan.rooms.append(FloorPlan.Room.new("Kitchen", Rect2(4, 0, 4, 2)))
	var shared: Array[Dictionary] = _between(plan)
	assert_eq(shared.size(), 1, "the wall between them once")
	var piece: Dictionary = shared[0]
	assert_eq(piece["room"], 0)
	assert_eq(Vector2(piece["out"]), Vector2.UP)
	assert_almost_eq(float(piece["from"]), 0.0, 1e-6, "the hall's face runs straight through")
	assert_almost_eq(float(piece["to"]), FloorPlan.INNER_WALL, 1e-6, "into the kitchen")
	assert_almost_eq(plan.wall_face(Vector2(5, 2), Vector2.DOWN), 0.0, 1e-6, "nothing of it in the hall")
	assert_almost_eq(plan.wall_face(Vector2(5, 2), Vector2.UP), FloorPlan.INNER_WALL, 1e-6)
	# Two rooms side by side, neither going on outside: on the middle of the line.
	var pair: FloorPlan = _plan()
	pair.rooms.append(FloorPlan.Room.new("Room", Rect2(0, 0, 3, 3)))
	pair.rooms.append(FloorPlan.Room.new("Room", Rect2(3, 0, 3, 3)))
	var middle: Dictionary = _between(pair)[0]
	assert_almost_eq(float(middle["from"]), -FloorPlan.INNER_WALL * 0.5, 1e-6)
	assert_almost_eq(float(middle["to"]), FloorPlan.INNER_WALL * 0.5, 1e-6)


func test_own_thickness_and_placing_of_a_wall_saved() -> void:
	var plan: FloorPlan = _plan()
	plan.rooms.append(FloorPlan.Room.new("Room", Rect2(0, 0, 3, 3)))
	plan.rooms.append(FloorPlan.Room.new("Room", Rect2(3, 0, 3, 3)))
	# The wall between them (room 0's right wall, 1) thicker, into room 0.
	plan.set_wall_look(0, 1, 0.25, FloorPlan.Align.INTO_THIS)
	assert_almost_eq(plan.rooms[1].wall_thickness(3), 0.25, 1e-6, "the other room's side along")
	var piece: Dictionary = _between(plan)[0]
	assert_almost_eq(float(piece["from"]), -0.25, 1e-6, "into room 0")
	assert_almost_eq(float(piece["to"]), 0.0, 1e-6)
	# An outside wall of its own thickness.
	plan.set_wall_look(0, 3, 0.45, FloorPlan.Align.AUTO)
	var outside: Dictionary = {}
	for p: Dictionary in plan.wall_pieces():
		if p["room"] == 0 and p["wall"] == 3:
			outside = p
	assert_almost_eq(float(outside["to"]), 0.45, 1e-6)
	var copy: FloorPlan = FloorPlan.from_data(plan.to_data())
	assert_almost_eq(copy.rooms[0].wall_thickness(3), 0.45, 1e-6, "saved")
	assert_eq(copy.rooms[0].wall_align(1), FloorPlan.Align.INTO_THIS)
	# The grown outline keeps each wall's thickness.
	var grown: PackedVector2Array = FloorPlan.grown(plan.rooms[0].points, PackedFloat32Array([0.3, 0.3, 0.3, 0.45]))
	assert_eq(grown.size(), 4)
	assert_true(grown[0].is_equal_approx(Vector2(-0.45, -0.3)))


func test_default_wall_thickness_for_new_plans() -> void:
	var outer: float = FloorPlan.default_outer
	var inner: float = FloorPlan.default_inner
	FloorPlan.default_outer = 0.4
	FloorPlan.default_inner = 0.1
	var fresh: FloorPlan = FloorPlan.new()
	assert_almost_eq(fresh.outer_wall, 0.4, 1e-6)
	assert_almost_eq(fresh.inner_wall, 0.1, 1e-6)
	# A plan saved with the usual walls keeps them.
	var old: FloorPlan = FloorPlan.from_data({"rooms": [{"name": "Room", "rect": [0, 0, 3, 3]}]})
	assert_almost_eq(old.outer_wall, FloorPlan.OUTER_WALL, 1e-6)
	FloorPlan.default_outer = outer
	FloorPlan.default_inner = inner


func test_slanting_walls() -> void:
	var plan: FloorPlan = _plan()
	plan.rooms.append(FloorPlan.Room.new("Room", Rect2(0, 0, 3, 3)))
	# Its right wall turned to slant: 300° from the top right corner.
	assert_true(plan.set_wall_angle(0, 1, 300.0, 3.2))
	var room: FloorPlan.Room = plan.rooms[0]
	assert_false(room.is_rectangle())
	assert_false(room.is_square())
	assert_almost_eq(FloorPlan.wall_angle(room.wall(1)), 300.0, 0.05)
	assert_false(plan.set_wall_angle(0, 1, 100.0, 9.0), "never crossing itself")
	# Saved and loaded as it is.
	var copy: FloorPlan = FloorPlan.from_data(plan.to_data())
	assert_eq(copy.rooms[0].points.size(), 4)
	assert_true(copy.rooms[0].points[2].is_equal_approx(room.points[2]))
	# A part put on the slanting wall stays on it, facing the nearest way in.
	var near: Dictionary = plan.wall_near((room.points[1] + room.points[2]) * 0.5 + Vector2(-0.1, 0.0))
	assert_false(near["straight"])
	assert_almost_eq(Geometry2D.get_closest_point_to_segment(near["at"], room.points[1], room.points[2]).distance_to(near["at"]), 0.0, 0.002)
	assert_eq(FloorPlan.FACING[near["facing"]], Vector2.LEFT)
	# A slanting wall is not dragged across; its corner moves where it is put.
	var before: PackedVector2Array = room.points.duplicate()
	plan.set_edge(0, 1, 5.0)
	assert_eq(room.points, before)
	plan.set_corner(0, 2, Vector2(3.5, 3.0))
	assert_true(room.points[2].is_equal_approx(Vector2(3.5, 3.0)))
	# A room by its corners with a slanting wall.
	var drawn: FloorPlan.Room = FloorPlan.outline_room(PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(2, 3)]), "Room")
	assert_not_null(drawn)
	assert_almost_eq(drawn.area(), 6.0, 1e-6)
	# Joined with a rectangle beside it.
	var pair: FloorPlan = _plan()
	pair.rooms.append(FloorPlan.Room.new("Room", Rect2(0, 0, 2, 2)))
	var wedge: FloorPlan.Room = FloorPlan.Room.new("Room")
	wedge.points = PackedVector2Array([Vector2(2, 0), Vector2(4, 0), Vector2(2, 2)])
	pair.rooms.append(wedge)
	assert_true(pair.join_rooms(0, 1))
	assert_almost_eq(pair.rooms[0].area(), 6.0, 1e-6)


func test_walls_drawn_on_their_own_close_into_a_room() -> void:
	var plan: FloorPlan = _plan()
	assert_eq(plan.add_wall(Vector2(0, 0), Vector2(4, 0), 0.0, "Room"), -1)
	assert_eq(plan.add_wall(Vector2(4, 0), Vector2(4, 3), 0.25, "Room"), -1)
	assert_eq(plan.add_wall(Vector2(4, 3), Vector2(0, 3), 0.0, "Room"), -1)
	assert_eq(plan.walls.size(), 3, "open: walls on their own")
	var copy: FloorPlan = FloorPlan.from_data(plan.to_data())
	assert_eq(copy.walls.size(), 3, "saved")
	assert_almost_eq(copy.walls[1].thickness, 0.25, 1e-6)
	# The last one closes them round a space: a room within them.
	var index: int = plan.add_wall(Vector2(0, 3), Vector2(0, 0), 0.0, "Room")
	assert_eq(index, 0)
	assert_true(plan.walls.is_empty(), "the walls are the room's now")
	var room: FloorPlan.Room = plan.rooms[0]
	var half: float = FloorPlan.INNER_WALL * 0.5
	assert_true(room.rect.is_equal_approx(Rect2(half, half, 4.0 - half - 0.125, 3.0 - 2.0 * half)), "inside the walls: %s" % room.rect)
	var thick: int = 0
	for k: int in room.points.size():
		if is_equal_approx(room.wall_thickness(k), 0.25):
			thick += 1
	assert_eq(thick, 1, "each wall keeps its thickness")
	# Drawn the other way round, and with a slanting wall, it closes too.
	var other: FloorPlan = _plan()
	other.add_wall(Vector2(0, 0), Vector2(0, 3), 0.0, "Room")
	other.add_wall(Vector2(0, 3), Vector2(3, 0), 0.0, "Room")
	assert_eq(other.add_wall(Vector2(3, 0), Vector2(0, 0), 0.0, "Room"), 0)
	assert_false(other.rooms[0].is_square())
	# An end dragged onto another wall's closes them.
	var dragged: FloorPlan = _plan()
	dragged.add_wall(Vector2(0, 0), Vector2(3, 0), 0.0, "Room")
	dragged.add_wall(Vector2(3, 0), Vector2(3, 3), 0.0, "Room")
	dragged.add_wall(Vector2(3, 3), Vector2(0, 3), 0.0, "Room")
	dragged.add_wall(Vector2(0, 3), Vector2(0, 0.5), 0.0, "Room")
	assert_eq(dragged.move_wall_end(3, 1, Vector2(0, 0), "Room"), 0)


func test_stairs() -> void:
	var straight: Dictionary = FloorPlan.stair_lines(FloorPlan.Room.new("Hall", Rect2(0, 0, 1.2, 4)).points, false)
	assert_eq((straight["treads"] as Array).size(), int(4.0 / FloorPlan.TREAD))
	var walk: PackedVector2Array = straight["walk"]
	assert_true(walk[0].y < walk[walk.size() - 1].y, "up along the longer side")
	var reverse: PackedVector2Array = FloorPlan.stair_lines(FloorPlan.Room.new("Hall", Rect2(0, 0, 1.2, 4)).points, true)["walk"]
	assert_true(reverse[0].is_equal_approx(walk[walk.size() - 1]), "the other way")
	var l: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(3, 0), Vector2(3, 1.2), Vector2(1.2, 1.2), Vector2(1.2, 4), Vector2(0, 4)])
	var turning: Dictionary = FloorPlan.stair_lines(l, false)
	var turns: PackedVector2Array = turning["walk"]
	assert_eq(turns.size(), 3, "turning in the square where the arms meet")
	assert_true(turns[1].is_equal_approx(Vector2(0.6, 0.6)))
	var plan: FloorPlan = _plan()
	var room: FloorPlan.Room = FloorPlan.Room.new("Hall", Rect2(0, 0, 1.2, 4))
	room.stairs = true
	room.stairs_reverse = true
	plan.rooms.append(room)
	var copy: FloorPlan = FloorPlan.from_data(plan.to_data())
	assert_true(copy.rooms[0].stairs)
	assert_true(copy.rooms[0].stairs_reverse)
	# No wall where the stairs start: going up the other way, the bottom wall.
	assert_eq(plan.open_wall(0), 2)
	for piece: Dictionary in plan.wall_pieces():
		assert_false(piece["room"] == 0 and piece["wall"] == 2, "the start left open")
	# Entered from a hall below it: no wall between them there either.
	plan.rooms.append(FloorPlan.Room.new("Hall", Rect2(0, 4, 3, 2)))
	for piece: Dictionary in plan.wall_pieces():
		var a: Vector2 = piece["a"]
		var b: Vector2 = piece["b"]
		assert_false(is_equal_approx(a.y, 4.0) and is_equal_approx(b.y, 4.0) and a.x < 1.2 and b.x < 1.21, "open into the hall")
	room.stairs_reverse = false
	assert_eq(plan.open_wall(0), 0, "turned round: the top wall")
	assert_eq(FloorPlan.stair_start_wall(l, false), 4, "an L: across the end of its arm")


func test_doors_and_windows_dragged_along() -> void:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Room", Rect2(0, 0, 4, 3)))
	doc.floor_plan.doors.append(FloorPlan.Door.new(Vector2(2, 3), false))
	doc.floor_plan.windows.append(FloorPlan.WindowOpening.new(Vector2(4, 1.5), true))
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.editing = true
	canvas.zoom = 1.0
	canvas.offset = Vector2(100, 100)
	# The room dragged 1 m right: its door and window go along as it moves.
	canvas._press = {"kind": "room", "index": 0}
	canvas._press_at = canvas.to_screen(Vector2(2, 1))
	canvas._mouse = canvas.to_screen(Vector2(3, 1))
	canvas._dragging = true
	assert_true(canvas._shown_opening("door", 0).at.is_equal_approx(Vector2(3, 3)))
	assert_true(canvas._shown_opening("window", 0).at.is_equal_approx(Vector2(5, 1.5)))
	# The door itself dragged along the wall shows where it goes.
	canvas._press = {"kind": "door", "index": 0}
	canvas._mouse = canvas.to_screen(Vector2(1, 2.95))
	assert_true(canvas._shown_opening("door", 0).at.is_equal_approx(Vector2(1, 3)))
	# The right wall dragged: the window on it moves with it.
	canvas._press = {"kind": "edge", "index": 0, "side": 1}
	canvas._mouse = canvas.to_screen(Vector2(4.5, 1))
	assert_true(canvas._shown_opening("window", 0).at.is_equal_approx(Vector2(4.5, 1.5)))
	canvas._dragging = false


func test_slanting_walls_joined_all_the_way() -> void:
	var plan: FloorPlan = _plan()
	plan.rooms.append(FloorPlan.Room.new("Room", Rect2(0, 0, 6, 4)))
	# A free wall slanting up onto the room's top wall: its end cut along
	# that wall, in the middle of its band (outside the room), not square.
	plan.walls.append(FloorPlan.Wall.new(Vector2(2, 3), Vector2(3, 0)))
	var outline: PackedVector2Array = plan.free_wall_outlines()[0]
	var middle: float = -plan.outer_wall * 0.5
	assert_almost_eq(outline[1].y, middle, 1e-4, "both corners at the top on the middle of the top wall's band")
	assert_almost_eq(outline[2].y, middle, 1e-4)
	assert_almost_eq(outline[0].distance_to(outline[3]), plan.inner_wall, 1e-4, "square at its free end")
	# Two free walls from one end at a right angle: mitred, the outer corner shared.
	plan.walls.clear()
	plan.walls.append(FloorPlan.Wall.new(Vector2(10, 0), Vector2(14, 0)))
	plan.walls.append(FloorPlan.Wall.new(Vector2(10, 0), Vector2(10, 3)))
	var outlines: Array[PackedVector2Array] = plan.free_wall_outlines()
	var half: float = plan.inner_wall * 0.5
	assert_true(_near(outlines[0], Vector2(10 - half, -half)), "the outer corner")
	assert_true(_near(outlines[1], Vector2(10 - half, -half)), "the same on the other wall")
	assert_true(_near(outlines[0], Vector2(10 + half, half)) and _near(outlines[1], Vector2(10 + half, half)), "the inner corner")
	# A wall between two rooms meeting the outside wall at a slant runs on
	# into it: the room with the corner of more than a right angle there
	# does not cut it off.
	var left: FloorPlan.Room = FloorPlan.outline_room(PackedVector2Array([Vector2(0, 10), Vector2(3, 10), Vector2(2, 14), Vector2(0, 14)]), "Left")
	var right: FloorPlan.Room = FloorPlan.outline_room(PackedVector2Array([Vector2(3, 10), Vector2(6, 10), Vector2(6, 14), Vector2(2, 14)]), "Right")
	assert_true(FloorPlan.obtuse_corner(right.points, Vector2(3, 10)), "the right room's corner at the top")
	assert_false(FloorPlan.obtuse_corner(left.points, Vector2(3, 10)), "the left room's is sharp")
	assert_false(FloorPlan.obtuse_corner(left.points, Vector2(1, 10)), "no corner there")
	assert_false(FloorPlan.obtuse_corner(left.points, Vector2(0, 10)), "a right angle")


func _near(points: PackedVector2Array, p: Vector2) -> bool:
	for q: Vector2 in points:
		if q.distance_to(p) < 1e-4:
			return true
	return false


func _area(plan: FloorPlan) -> float:
	var sum: float = 0.0
	for room: FloorPlan.Room in plan.rooms:
		sum += room.area()
	return sum


func test_corners_rooms_share_move_together() -> void:
	var plan: FloorPlan = _plan()
	plan.rooms.append(FloorPlan.Room.new("Room", Rect2(0, 0, 6, 4)))
	# Split by a slanting wall: its bottom end dragged along the bottom wall
	# moves the corner of both rooms (no gap opens between them).
	assert_eq(plan.split_room(0, PackedVector2Array([Vector2(4, 0), Vector2(2, 4)]), "Room 2"), 1)
	var bottom: Vector2 = Vector2(2, 4)
	assert_eq(plan.corners_at(bottom).size(), 2, "both rooms have the corner")
	var line: PackedVector2Array = plan.corner_line(bottom)
	assert_true(line.has(Vector2(0, 4)) and line.has(Vector2(6, 4)), "it slides along the bottom wall")
	var c: Vector2i = plan.corners_at(bottom)[0]
	assert_true(plan.set_corner(c.x, c.y, Vector2(1.0, 4.6)))
	var moved: Vector2 = Vector2(1, 4)
	assert_eq(plan.corners_at(moved).size(), 2, "both moved, onto the bottom wall")
	assert_almost_eq(_area(plan), 24.0, 1e-4, "nothing lost, nothing overlapping")
	assert_eq(plan.overlaps().size(), 0)
	# Never past the end of the wall it slides on.
	c = plan.corners_at(moved)[0]
	plan.set_corner(c.x, c.y, Vector2(-3.0, 4.0))
	assert_eq(plan.corners_at(Vector2(FloorPlan.MIN_WALL, 4)).size(), 2)
	# The top end slides along the top wall only.
	c = plan.corners_at(Vector2(4, 0))[0]
	assert_true(plan.set_corner(c.x, c.y, Vector2(5, 2)))
	assert_eq(plan.corners_at(Vector2(5, 0)).size(), 2)
	# A move that would cross a room over itself is refused, nothing changed.
	var before: Array = [plan.rooms[0].points.duplicate(), plan.rooms[1].points.duplicate()]
	var single: FloorPlan = _plan()
	single.rooms.append(FloorPlan.outline_room(PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(2, 3)]), "Room"))
	single.rooms.append(FloorPlan.outline_room(PackedVector2Array([Vector2(4, 0), Vector2(8, 0), Vector2(2, 3)]), "Room 2"))
	var shape: Array = [single.rooms[0].points.duplicate(), single.rooms[1].points.duplicate()]
	var tip: Vector2i = single.corners_at(Vector2(2, 3))[0]
	assert_false(single.set_corner(tip.x, tip.y, Vector2(6, -2)), "it would turn a room round")
	assert_eq([single.rooms[0].points, single.rooms[1].points], shape)
	assert_eq([plan.rooms[0].points, plan.rooms[1].points], before)


func test_walls_between_rooms_stay_straight_unless_free() -> void:
	var plan: FloorPlan = _plan()
	plan.rooms.append(FloorPlan.Room.new("Left", Rect2(0, 0, 3, 4)))
	plan.rooms.append(FloorPlan.Room.new("Right", Rect2(3, 0, 3, 4)))
	# The top end of the wall between them dragged along the top: the whole
	# wall moves, up and down as it was.
	plan.set_corner(0, 1, Vector2(4.0, -0.7))
	assert_eq(plan.rooms[0].rect, Rect2(0, 0, 4, 4))
	assert_eq(plan.rooms[1].rect, Rect2(4, 0, 2, 4))
	# With Shift (free) only its end moves: the wall slants.
	plan.set_corner(0, 1, Vector2(3.0, 0.0), true)
	assert_true(_near(plan.rooms[0].points, Vector2(3, 0)) and _near(plan.rooms[1].points, Vector2(3, 0)))
	assert_true(_near(plan.rooms[0].points, Vector2(4, 4)), "its bottom end stays")
	assert_almost_eq(_area(plan), 24.0, 1e-4)
	# The slanting wall dragged sideways: both rooms follow it.
	var k: int = FloorPlan.wall_through(plan.rooms[0].points, Vector2(3.5, 2.0))
	assert_true(plan.move_wall(0, k, 0.5))
	assert_almost_eq(plan.rooms[0].points[k].y, 0.0, 1e-4, "its top end along the top wall")
	assert_gt(plan.rooms[0].points[k].x, 3.4)
	assert_eq(plan.corners_at(plan.rooms[0].points[k]).size(), 2, "still shared")
	assert_almost_eq(_area(plan), 24.0, 1e-4)
	assert_false(plan.move_wall(0, k, 9.0), "never crossing the room over")
	# Turned in the wall dialog: the other room keeps the corner.
	var top: Vector2 = plan.rooms[0].points[k]
	var end: Vector2 = plan.rooms[0].points[(k + 1) % plan.rooms[0].points.size()]
	assert_true(plan.set_wall_angle(0, k, FloorPlan.wall_angle(PackedVector2Array([top, end])), top.distance_to(end) - 0.5))
	assert_eq(plan.corners_at(plan.rooms[0].points[(k + 1) % plan.rooms[0].points.size()]).size(), 2)
