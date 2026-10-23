extends GutTest
## Rooms of the floor plan made and changed: drawn by their corners, with
## their size typed, split by a wall, duplicated and moved, overlaps found,
## named as they are drawn, placed from the ready rooms, and the canvas's
## help while they are drawn and changed.


func after_all() -> void:
	RecoveryFile.forget()


func _house() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	return doc


func _canvas(doc: SchematicDocument) -> FloorPlanCanvas:
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.editing = true
	canvas.size = Vector2(1000, 700)
	return canvas


## Applies the edits [param canvas] asks for to [param doc] as the view does.
func _apply(canvas: FloorPlanCanvas, doc: SchematicDocument) -> Array[Callable]:
	var edits: Array[Callable] = []
	canvas.edit_requested.connect(func(change: Callable) -> void:
		edits.append(change)
		change.call(doc))
	return edits


func test_split_by_a_wall() -> void:
	var plan: FloorPlan = FloorPlan.new()
	plan.rooms.append(FloorPlan.Room.new("Living room", Rect2(0, 0, 6, 4)))
	plan.rooms[0].set_wall_thickness(0, 0.45)
	var dim: FloorPlan.Dimension = FloorPlan.Dimension.new()
	dim.room = 0
	plan.dimensions.append(dim)
	assert_eq(plan.split_room(0, PackedVector2Array([Vector2(0.5, 0), Vector2(0.5, 4)]), "Room 2"), -1, "a piece too narrow")
	assert_eq(plan.split_room(0, PackedVector2Array([Vector2(7, 0), Vector2(7, 4)]), "Room 2"), -1, "the line misses it")
	assert_eq(plan.split_room(0, PackedVector2Array([Vector2(3.5, 0), Vector2(3.5, 2)]), "Room 2"), -1, "not across it")
	var other: int = plan.split_room(0, PackedVector2Array([Vector2(3.5, 0), Vector2(3.5, 4)]), "Room 2")
	assert_eq(other, 1)
	assert_eq(plan.rooms[0].rect, Rect2(0, 0, 3.5, 4), "the larger piece kept")
	assert_eq(plan.rooms[1].rect, Rect2(3.5, 0, 2.5, 4))
	assert_eq(plan.rooms[1].name, "Room 2")
	assert_true(plan.rooms[0].is_rectangle() and plan.rooms[1].is_rectangle())
	assert_eq(plan.dimensions.size(), 0, "its chains dropped")
	for room: FloorPlan.Room in plan.rooms:
		var top: int = FloorPlan.wall_through(room.points, room.rect.position + Vector2(1, 0))
		assert_almost_eq(room.wall_thickness(top), 0.45, 0.0001, "the top wall keeps its thickness")
	assert_eq(plan.overlaps().size(), 0, "the halves share a wall, they do not overlap")
	# A bent wall: across, then down.
	var bent: int = plan.split_room(0, PackedVector2Array([Vector2(0, 1.5), Vector2(2, 1.5), Vector2(2, 4)]), "Hall")
	assert_eq(bent, 2)
	assert_eq(plan.rooms[2].points.size(), 4, "the corner piece a rectangle")
	assert_eq(plan.rooms[2].rect, Rect2(0, 1.5, 2, 2.5))
	assert_eq(plan.rooms[0].points.size(), 6, "the rest an L")
	assert_almost_eq(plan.rooms[0].area() + plan.rooms[2].area(), 3.5 * 4.0, 0.001, "nothing lost")
	# An L split across its leg, into two rectangles.
	var l_room: FloorPlan.Room = FloorPlan.preset_room(FloorPlan.PRESETS.size() - 1, Vector2(10, 0), "Living room")
	plan.rooms.append(l_room)
	assert_eq(l_room.points.size(), 6)
	var box: Rect2 = l_room.rect
	var cut: int = plan.split_room(3, PackedVector2Array([Vector2(box.position.x, 3.0), Vector2(box.end.x, 3.0)]), "Hall")
	if cut < 0:
		# The leg on the other side: cut it where the room is whole.
		cut = plan.split_room(3, PackedVector2Array([Vector2(box.position.x, 2.0), Vector2(box.end.x, 2.0)]), "Hall")
	assert_eq(cut, 4)
	assert_almost_eq(plan.rooms[3].area() + plan.rooms[4].area(), 6.0 * 5.0 - 2.5 * 2.0, 0.001, "nothing lost")
	assert_true(plan.rooms[3].is_square() and plan.rooms[4].is_square())


func test_a_cut_into_three_is_refused() -> void:
	# A U: a line across both arms would make three pieces.
	var plan: FloorPlan = FloorPlan.new()
	var u: FloorPlan.Room = FloorPlan.outline_room(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 2), Vector2(2, 2), Vector2(2, 0), Vector2(3, 0), Vector2(3, 3), Vector2(0, 3)]), "U")
	assert_not_null(u)
	plan.rooms.append(u)
	assert_eq(plan.split_room(0, PackedVector2Array([Vector2(0, 1), Vector2(3, 1)]), "x"), -1, "across both arms")
	assert_eq(plan.split_room(0, PackedVector2Array([Vector2(1, 1), Vector2(2, 1)]), "x"), -1, "outside it, between its arms")
	assert_eq(plan.rooms.size(), 1)


func test_rooms_by_their_corners() -> void:
	var l_room: FloorPlan.Room = FloorPlan.outline_room(PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 2), Vector2(2, 2), Vector2(2, 3), Vector2(0, 3)]), "L")
	assert_not_null(l_room)
	assert_eq(l_room.points.size(), 6)
	assert_almost_eq(l_room.area(), 10.0, 0.001)
	# A corner on a straight run is left out.
	var plain: FloorPlan.Room = FloorPlan.outline_room(PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(4, 0), Vector2(4, 3), Vector2(0, 3)]), "R")
	assert_true(plain.is_rectangle())
	var slanted: FloorPlan.Room = FloorPlan.outline_room(PackedVector2Array([Vector2(0, 0), Vector2(4, 1), Vector2(4, 3), Vector2(0, 3)]), "slanted")
	assert_not_null(slanted, "a slanting wall")
	assert_almost_eq(slanted.area(), 10.0, 0.001)
	assert_null(FloorPlan.outline_room(PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 0.5), Vector2(0, 0.5)]), "thin"), "too narrow")
	assert_not_null(FloorPlan.outline_room(PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 3)]), "three"), "three corners, one wall slanting")
	assert_null(FloorPlan.outline_room(PackedVector2Array([Vector2(0, 0), Vector2(4, 3), Vector2(4, 0), Vector2(0, 3)]), "crossed"), "crossing itself")


func test_overlaps_and_duplicates() -> void:
	var plan: FloorPlan = FloorPlan.new()
	plan.rooms.append(FloorPlan.Room.new("A", Rect2(0, 0, 4, 3)))
	plan.rooms.append(FloorPlan.Room.new("B", Rect2(4, 0, 3, 3)))
	assert_eq(plan.overlaps().size(), 0, "sharing a wall")
	plan.rooms.append(FloorPlan.Room.new("C", Rect2(3, 2, 2, 2)))
	var found: Array[PackedVector2Array] = plan.overlaps()
	assert_eq(found.size(), 2, "C over A and over B")
	assert_almost_eq(FloorPlan.polygon_area(found[0]) + FloorPlan.polygon_area(found[1]), 2.0, 0.001)
	plan.rooms.remove_at(2)
	plan.rooms[1].environment = "AB7"
	plan.rooms[1].number = "205"
	var twin: int = plan.duplicate_room(1)
	assert_eq(plan.rooms[twin].rect, Rect2(7, 0, 3, 3), "beside it")
	assert_eq(plan.rooms[twin].environment, "AB7")
	assert_eq(plan.rooms[twin].number, "", "a number of its own")
	var again: int = plan.duplicate_room(0)
	assert_eq(plan.rooms[again].rect.position, Vector2(10, 0), "right of all where beside it is taken")
	assert_eq(plan.overlaps().size(), 0)


## A key [param code] (and its letter) pressed on [param canvas].
func _key(canvas: FloorPlanCanvas, code: Key, unicode: int = 0) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = code
	key.unicode = unicode
	key.pressed = true
	canvas._gui_input(key)


func _type(canvas: FloorPlanCanvas, digits: String) -> void:
	for ch: String in digits:
		_key(canvas, KEY_0 + int(ch), ch.unicode_at(0))


func _click(canvas: FloorPlanCanvas, at: Vector2) -> void:
	canvas._press_at = canvas.to_screen(at)
	canvas._mouse = canvas._press_at
	canvas._dragging = false
	canvas._release(canvas._pressed(canvas._press_at), canvas._press_at)


func test_rooms_drawn_with_their_size_typed() -> void:
	var doc: SchematicDocument = _house()
	var canvas: FloorPlanCanvas = _canvas(doc)
	_apply(canvas, doc)
	var drawn: Array[int] = []
	canvas.room_drawn.connect(func(index: int) -> void: drawn.append(index))
	canvas.tool = FloorPlanCanvas.Tool.ROOM
	# Two clicks: corner to corner.
	_click(canvas, Vector2(0, 0))
	assert_eq(doc.floor_plan.rooms.size(), 0, "the first corner")
	_click(canvas, Vector2(4.02, 3.0))
	assert_eq(doc.floor_plan.rooms.size(), 1)
	assert_eq(doc.floor_plan.rooms[0].rect, Rect2(0, 0, 4, 3), "on the grid")
	assert_eq(drawn, [0] as Array[int], "to be named")
	# A click, the size typed: right of it, up from it as the mouse is.
	_click(canvas, Vector2(4, 3))
	canvas._mouse = canvas.to_screen(Vector2(6, 1))
	_type(canvas, "3500")
	_key(canvas, KEY_TAB)
	_type(canvas, "2000")
	_key(canvas, KEY_ENTER)
	assert_eq(doc.floor_plan.rooms.size(), 2)
	assert_true(doc.floor_plan.rooms[1].rect.is_equal_approx(Rect2(4, 1, 3.5, 2)), "3.50 × 2.00 m up and right of the corner")
	# Too small, or Esc: nothing.
	_click(canvas, Vector2(10, 0))
	_type(canvas, "500")
	_key(canvas, KEY_ENTER)
	assert_eq(doc.floor_plan.rooms.size(), 2, "narrower than a room")
	_click(canvas, Vector2(10, 0))
	_key(canvas, KEY_ESCAPE)
	assert_true(is_nan(canvas._room_from.x), "Esc forgets the corner")


func test_rooms_drawn_by_their_corners() -> void:
	var doc: SchematicDocument = _house()
	var canvas: FloorPlanCanvas = _canvas(doc)
	_apply(canvas, doc)
	canvas.tool = FloorPlanCanvas.Tool.OUTLINE
	# An L: clicked corners, a wall typed; the mouse only says which way.
	_click(canvas, Vector2(0, 0))
	_click(canvas, Vector2(4.0, 0.1))
	assert_eq(canvas._corners[1], Vector2(4, 0), "straight across")
	canvas._mouse = canvas.to_screen(Vector2(4.1, 1.0))
	_type(canvas, "2000")
	_key(canvas, KEY_ENTER)
	assert_true(canvas._corners[2].is_equal_approx(Vector2(4, 2)), "2.00 m down")
	_click(canvas, Vector2(2, 2.05))
	_click(canvas, Vector2(2.03, 3))
	_click(canvas, Vector2(0.1, 3))
	assert_true(canvas._corners[5].is_equal_approx(Vector2(0, 3)), "level with the first corner")
	_click(canvas, Vector2(0, 0))
	assert_eq(doc.floor_plan.rooms.size(), 1, "closed on its first corner")
	assert_eq(doc.floor_plan.rooms[0].points.size(), 6)
	assert_almost_eq(doc.floor_plan.rooms[0].area(), 10.0, 0.001)
	assert_eq(canvas._corners.size(), 0)
	# Enter closes it the short way round; Backspace takes a corner back.
	_click(canvas, Vector2(6, 0))
	_click(canvas, Vector2(9, 0))
	_click(canvas, Vector2(9, 1))
	_key(canvas, KEY_BACKSPACE)
	assert_eq(canvas._corners.size(), 2)
	canvas._mouse = canvas.to_screen(Vector2(9, 2.5))
	_click(canvas, Vector2(9, 2.5))
	_key(canvas, KEY_ENTER)
	assert_eq(doc.floor_plan.rooms.size(), 2)
	assert_eq(doc.floor_plan.rooms[1].rect, Rect2(6, 0, 3, 2.5), "a rectangle closed by one more corner")


func test_rooms_split_and_placed() -> void:
	var doc: SchematicDocument = _house()
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Living room", Rect2(0, 0, 6, 4)))
	var canvas: FloorPlanCanvas = _canvas(doc)
	_apply(canvas, doc)
	var drawn: Array[int] = []
	canvas.room_drawn.connect(func(index: int) -> void: drawn.append(index))
	canvas.tool = FloorPlanCanvas.Tool.WALL
	# Walls clicked from the top wall down to the bottom one: snapped onto them.
	_click(canvas, Vector2(2.48, 0.05))
	assert_eq(canvas._corners, PackedVector2Array([Vector2(2.5, 0)]), "onto the wall, on the grid")
	_click(canvas, Vector2(2.52, 2.0))
	assert_eq(canvas._corners.size(), 2, "inside the room it waits")
	# Snapped onto a wall: dimensions to both its ends are drawn (in a frame).
	add_child(canvas)
	canvas._mouse = canvas.to_screen(Vector2(2.53, 3.95))
	canvas.queue_redraw()
	await get_tree().process_frame
	remove_child(canvas)
	assert_eq(canvas._split_room, 0)
	assert_eq(doc.floor_plan.walls.size(), 0, "no wall on its own")
	canvas._mouse = canvas.to_screen(Vector2(2.53, 3.95))
	assert_eq(canvas._next_wall_point(), Vector2(2.5, 4), "straight on onto the bottom wall")
	_click(canvas, Vector2(2.53, 3.95))
	assert_eq(doc.floor_plan.rooms.size(), 2)
	assert_eq(doc.floor_plan.rooms[0].rect, Rect2(2.5, 0, 3.5, 4), "the larger piece kept")
	assert_eq(doc.floor_plan.rooms[1].rect, Rect2(0, 0, 2.5, 4))
	assert_true(canvas._corners.is_empty(), "the drawing ends")
	# Walls inside a room ended by a right click stay, as walls on their own.
	_click(canvas, Vector2(4.0, 0.0))
	_click(canvas, Vector2(4.0, 1.0))
	assert_eq(doc.floor_plan.walls.size(), 0)
	canvas._end_walls()
	assert_eq(doc.floor_plan.walls.size(), 1)
	doc.floor_plan.walls.clear()
	canvas.tool = FloorPlanCanvas.Tool.SELECT
	assert_eq(drawn, [1] as Array[int], "the new room to be named")
	# A ready room follows the mouse and snaps onto the walls.
	canvas.begin_place_room(3)
	assert_eq(canvas.tool, FloorPlanCanvas.Tool.PLACE_ROOM)
	canvas._mouse = canvas.to_screen(Vector2(7.4, 1.1))
	var ghost: FloorPlan.Room = canvas._placed_room()
	assert_eq(ghost.name, "Bathroom")
	assert_almost_eq(ghost.rect.position.x, 6.0, 1e-6, "onto the wall beside it")
	_click(canvas, Vector2(7.4, 1.1))
	assert_eq(doc.floor_plan.rooms.size(), 3)
	assert_eq(canvas.tool, FloorPlanCanvas.Tool.PLACE_ROOM, "again until Esc")
	_key(canvas, KEY_ESCAPE)
	assert_eq(canvas.tool, FloorPlanCanvas.Tool.SELECT)


func test_rooms_duplicated_and_nudged() -> void:
	var doc: SchematicDocument = _house()
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Bedroom", Rect2(0, 0, 4, 3)))
	var canvas: FloorPlanCanvas = _canvas(doc)
	_apply(canvas, doc)
	canvas.selected = {"kind": "room", "index": 0}
	var duplicate: InputEventKey = InputEventKey.new()
	duplicate.keycode = KEY_D
	duplicate.ctrl_pressed = true
	duplicate.pressed = true
	canvas._gui_input(duplicate)
	assert_eq(doc.floor_plan.rooms.size(), 2)
	assert_eq(doc.floor_plan.rooms[1].rect, Rect2(4, 0, 4, 3))
	assert_eq(canvas.selected.get("index", -1), 1, "the copy picked")
	_key(canvas, KEY_DOWN)
	assert_true(doc.floor_plan.rooms[1].rect.position.is_equal_approx(Vector2(4, FloorPlan.SNAP)), "5 cm down")
	var far: InputEventKey = InputEventKey.new()
	far.keycode = KEY_RIGHT
	far.shift_pressed = true
	far.pressed = true
	canvas._gui_input(far)
	assert_true(doc.floor_plan.rooms[1].rect.position.is_equal_approx(Vector2(4.5, FloorPlan.SNAP)), "with Shift 50 cm")


## A floor plan view editing [param doc], each edit applied and shown.
func _view(doc: SchematicDocument) -> FloorPlanView:
	var view: FloorPlanView = FloorPlanView.new()
	add_child_autofree(view)
	view.set_document(doc, true)
	view.edit_requested.connect(func(change: Callable) -> void:
		change.call(doc)
		view.refresh())
	return view


func test_room_named_as_drawn_and_in_its_panel() -> void:
	var doc: SchematicDocument = _house()
	var view: FloorPlanView = _view(doc)
	var canvas: FloorPlanCanvas = view.canvas
	canvas.size = Vector2(1000, 700)
	canvas.tool = FloorPlanCanvas.Tool.ROOM
	_click(canvas, Vector2(0, 0))
	_click(canvas, Vector2(3, 2.5))
	assert_eq(doc.floor_plan.rooms.size(), 1)
	var picker: PopupMenu = view.get("_name_picker")
	assert_eq(picker.get_item_text(3), "Bathroom", "the usual names offered")
	picker.id_pressed.emit(3)
	assert_eq(doc.floor_plan.rooms[0].name, "Bathroom")
	assert_eq(doc.floor_plan.room_environment(0), "ČSN 33 2000-7-701", "a bathroom's environment by its name")
	# The panel shows the room picked and takes what is typed.
	canvas.selected = {"kind": "room", "index": 0}
	assert_true((view.get("_room_box") as Control).visible)
	var name_field: LineEdit = view.get("_rename_field")
	assert_eq(name_field.text, "Bathroom")
	name_field.text = "Shower room"
	name_field.text_submitted.emit(name_field.text)
	assert_eq(doc.floor_plan.rooms[0].name, "Shower room")
	(view.get("_width_field") as SpinBox).value = 3.5
	assert_almost_eq(doc.floor_plan.rooms[0].rect.size.x, 3.5, 1e-6, "its width typed")
	assert_string_contains((view.get("_area_label") as Label).text, "8.75")
	# Nothing changed, no edit.
	var edits: Array[int] = [0]
	view.edit_requested.connect(func(_change: Callable) -> void: edits[0] += 1)
	name_field.text_submitted.emit(name_field.text)
	assert_eq(edits[0], 0, "no edit for nothing changed")
	canvas.selected = {}
	assert_false((view.get("_room_box") as Control).visible, "hidden with no room picked")


func test_room_menu() -> void:
	var doc: SchematicDocument = _house()
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Kitchen", Rect2(0, 0, 3, 3)))
	var view: FloorPlanView = _view(doc)
	var canvas: FloorPlanCanvas = view.canvas
	canvas.size = Vector2(1000, 700)
	var menus: Array[int] = []
	canvas.room_menu_requested.connect(func(index: int, _at: Vector2) -> void: menus.append(index))
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.position = canvas.to_screen(Vector2(1.5, 1.5))
	right.pressed = true
	canvas._on_button(right)
	right.pressed = false
	canvas._on_button(right)
	assert_eq(menus, [0] as Array[int], "a right click on a room opens its menu")
	var menu: PopupMenu = view.get("_room_menu")
	menu.id_pressed.emit(1)
	assert_eq(doc.floor_plan.rooms.size(), 2, "duplicated")
	assert_eq(doc.floor_plan.rooms[1].name, "Kitchen")
	view.set("_menu_room", 0)
	menu.id_pressed.emit(2)
	assert_eq(canvas.tool, FloorPlanCanvas.Tool.WALL, "split: walls drawn across it")
	view.set("_menu_room", 1)
	menu.id_pressed.emit(4)
	assert_eq(doc.floor_plan.rooms.size(), 1, "deleted")


func test_what_the_mouse_is_over_lights_up() -> void:
	var doc: SchematicDocument = _house()
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Hall", Rect2(0, 0, 4, 3)))
	var canvas: FloorPlanCanvas = _canvas(doc)
	canvas._hover_at(canvas.to_screen(Vector2(4.0, 1.5)))
	assert_eq(canvas._hover.get("kind", ""), "edge", "the right wall")
	assert_eq(canvas.mouse_default_cursor_shape, Control.CURSOR_HSIZE, "resized across it")
	canvas._hover_at(canvas.to_screen(Vector2(2.0, 3.0)))
	assert_eq(canvas.mouse_default_cursor_shape, Control.CURSOR_VSIZE)
	canvas._hover_at(canvas.to_screen(Vector2(2.0, 1.5)))
	assert_eq(canvas._hover.get("kind", ""), "room")
	assert_eq(canvas.mouse_default_cursor_shape, Control.CURSOR_MOVE, "moved")
	canvas._hover_at(canvas.to_screen(Vector2(9.0, 9.0)))
	assert_true(canvas._hover.is_empty())
	# A corner dragged snaps onto the wall of the room beside.
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Room", Rect2(4.0, 0.0, 3.0, 2.0)))
	canvas._mouse = canvas.to_screen(Vector2(3.0, 2.12))
	assert_true(canvas._corner_target(0).is_equal_approx(Vector2(3.0, 2.0)), "onto the other room's wall")
