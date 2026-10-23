extends GutTest
## The floor plan of a house installation: rooms put together like modules
## (snapping to each other's walls, moved with what is in them), doors,
## parts put onto the nearest wall or the ceiling, the cables worked out from
## the wiring, saving, renaming, and the plan in the main window operating
## the simulation.

const Main: GDScript = preload("res://ui/main.gd")
const MAIN_SCENE: String = "res://main.tscn"
const SETTINGS: String = "user://settings.cfg"

var _settings: String = ""
var _had_settings: bool = false


func before_all() -> void:
	_had_settings = FileAccess.file_exists(SETTINGS)
	if _had_settings:
		_settings = FileAccess.get_file_as_string(SETTINGS)


func after_all() -> void:
	if _had_settings:
		var file: FileAccess = FileAccess.open(SETTINGS, FileAccess.WRITE)
		file.store_string(_settings)
		file.close()
	elif FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(SETTINGS)
	RecoveryFile.forget()
	get_tree().auto_accept_quit = true


## A hall (0-3 x 0-1.5) and a room right of it (3-7 x 0-4); a switch SF1
## lighting EA1, a socket XD1, the protection in the consumer unit.
func _house() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.residential = true
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(4, 0))
	doc.add(PowerSupply.new("PE", PowerSupply.Conductor.PE), Vector2i(8, 0))
	var breaker: CircuitBreaker = CircuitBreaker.new("FA1")
	doc.add(breaker, Vector2i(0, 4))
	doc.add(LightSwitch.new("SF1"), Vector2i(0, 10))
	doc.add(Luminaire.new("EA1"), Vector2i(0, 16))
	doc.add(SocketOutlet.new("XD1"), Vector2i(10, 10))
	for pair: Array in [["L1", "FA1:1"], ["FA1:2", "SF1:1"], ["SF1:2", "EA1:L"], ["EA1:N", "N"], ["EA1:PE", "PE"], ["FA1:2", "XD1:L"], ["XD1:N", "N"], ["XD1:PE", "PE"]]:
		assert_true(doc.connect_terminals(pair[0], pair[1]), "%s - %s" % pair)
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Hall", Rect2(0, 0, 3, 1.5)))
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Room", Rect2(3, 0, 4, 4)))
	return doc


func test_rooms_snap_to_each_others_walls() -> void:
	var plan: FloorPlan = _house().floor_plan
	var snapped: Rect2 = plan.snap_room(Rect2(7.13, 0.22, 3.0, 3.0))
	assert_eq(snapped.position, Vector2(7.0, 0.0), "onto the room's right wall and its top")
	var far: Rect2 = plan.snap_room(Rect2(9.02, 6.0, 2.0, 2.0))
	assert_eq(far.position, Vector2(9.0, 6.0), "far away only to the 5 cm grid")
	assert_eq(plan.free_spot(Vector2(2, 2)), Rect2(7, 0, 2, 2), "a new room right of the others")
	assert_eq(plan.room_at(Vector2(5, 2)), 1)
	assert_eq(plan.room_at(Vector2(5, 6)), -1)


func test_parts_go_onto_the_nearest_wall() -> void:
	var plan: FloorPlan = _house().floor_plan
	plan.place("SF1", Vector2(3.3, 1.0), false)
	assert_eq(plan.parts["SF1"], Vector2(3.0, 1.0), "onto the room's left wall")
	assert_eq(FloorPlan.FACING[plan.facing["SF1"]], Vector2.RIGHT, "facing into the room")
	plan.place("EA1", Vector2(5.03, 2.01), true)
	assert_eq(plan.parts["EA1"], Vector2(5.05, 2.0), "a luminaire stays where it is put")
	assert_false(plan.facing.has("EA1"), "on the ceiling")
	plan.place("XD1", Vector2(6.8, 3.9), false)
	assert_true(plan.facing.has("XD1"))
	plan.move_room(1, Vector2(3, 1))
	assert_eq(plan.parts["EA1"], Vector2(5.05, 3.0), "moved along with its room")
	assert_eq(plan.rooms[1].rect.position, Vector2(3, 1))


func test_cables_follow_the_wiring() -> void:
	var doc: SchematicDocument = _house()
	var plan: FloorPlan = doc.floor_plan
	assert_true(plan.unplaced(doc.circuit).has(FloorPlan.UNIT), "the unit for the breaker")
	plan.place(FloorPlan.UNIT, Vector2(0.1, 0.7), false)
	plan.place("SF1", Vector2(3.1, 1.0), false)
	plan.place("EA1", Vector2(5, 2), true)
	plan.place("XD1", Vector2(6.9, 2), false)
	assert_true(plan.unplaced(doc.circuit).is_empty())
	var cores: Dictionary[String, int] = {}
	for cable: Dictionary in plan.cables(doc.circuit):
		cores[cable["a"] + "|" + cable["b"]] = cable["cores"]
	var total: int = 0
	for key: String in cores:
		total += cores[key]
	# The breaker's output reaches the switch and the socket, N and PE the
	# light and the socket from the unit: two cores each; switched L one.
	assert_eq(total, 7, "each net a tree over its places")
	assert_true(cores.has("+RD1|SF1") or cores.has("SF1|XD1"), "the feed of the switch")
	assert_eq(cores.get("EA1|SF1", 0), 1, "the switched L to the light")


func test_saved_renamed_and_pruned() -> void:
	var doc: SchematicDocument = _house()
	doc.floor_plan.place("SF1", Vector2(3.1, 1.0), false)
	doc.floor_plan.place("EA1", Vector2(5, 2), true)
	doc.floor_plan.doors.append(FloorPlan.Door.new(Vector2(3, 0.75), true))
	var loaded: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	var plan: FloorPlan = loaded.floor_plan
	assert_eq(plan.rooms.size(), 2)
	assert_eq(plan.rooms[1].name, "Room")
	assert_eq(plan.rooms[1].rect, Rect2(3, 0, 4, 4))
	assert_eq(plan.doors.size(), 1)
	assert_true(plan.doors[0].vertical)
	assert_eq(plan.parts["SF1"], Vector2(3.0, 1.0))
	assert_eq(plan.facing["SF1"], 0)
	assert_false(plan.facing.has("EA1"))
	# A renamed part keeps its place; a deleted one leaves the plan.
	var data: Dictionary = DocumentSerializer.component_to_dict(loaded.circuit.get_component("SF1"))
	data["designation"] = "SF7"
	loaded.replace_component(loaded.circuit.get_component("SF1").id, DocumentSerializer.component_from_dict(data))
	assert_true(loaded.floor_plan.parts.has("SF7"))
	assert_false(loaded.floor_plan.parts.has("SF1"))
	loaded.remove_component(loaded.circuit.get_component("EA1").id)
	assert_false(loaded.floor_plan.parts.has("EA1"))
	var odd: FloorPlan = FloorPlan.from_data({"rooms": [{"name": "x", "rect": [0, 0, "a", 1]}, {"rect": [0, 0, 0.1, 5]}], "parts": {"SF1": [1]}})
	assert_eq(odd.rooms.size(), 1, "a damaged room is left out")
	assert_almost_eq(odd.rooms[0].rect.size.x, FloorPlan.MIN_ROOM, 0.0001, "too small a room is made the least size")
	assert_true(odd.parts.is_empty())


func test_floor_plan_in_the_main_window() -> void:
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	add_child_autofree(main)
	main._recovery_dialog.hide()
	main._start_dialog.hide()
	TranslationServer.set_locale("en")
	main._replace_document(_house(), "")
	main._set_area(Main.Area.WORKSPACE)
	assert_true(main._floor_plan.visible, "the floor plan in place of the workspace")
	assert_false(main._workspace.visible)
	var plan_view: FloorPlanView = main._floor_plan
	assert_eq(plan_view._listed.size(), 4, "the unit and three parts to place")
	# Put the switch and the light on the plan through the tools.
	plan_view._on_listed(plan_view._listed.find("SF1"))
	assert_eq(plan_view.canvas.tool, FloorPlanCanvas.Tool.PLACE)
	plan_view.canvas._press_at = plan_view.canvas.to_screen(Vector2(3.2, 1.0))
	plan_view.canvas._mouse = plan_view.canvas._press_at
	plan_view.canvas._release({"kind": "new_part"}, plan_view.canvas._press_at)
	assert_eq(main.edit_doc.floor_plan.parts.get("SF1", Vector2.ZERO), Vector2(3.0, 1.0), "placed on the wall, undoable")
	main.editor.undo()
	assert_false(main.edit_doc.floor_plan.parts.has("SF1"), "undone")
	main.editor.redo()
	assert_true(main.edit_doc.floor_plan.parts.has("SF1"))
	plan_view._add_preset(0)
	assert_eq(plan_view.canvas.tool, FloorPlanCanvas.Tool.PLACE_ROOM, "a living room follows the mouse")
	assert_false(plan_view._list.visible, "no parts to place while a room is put")
	plan_view.canvas._press_at = plan_view.canvas.to_screen(Vector2(10.0, 2.0))
	plan_view.canvas._mouse = plan_view.canvas._press_at
	plan_view.canvas._release({"kind": "place_room"}, plan_view.canvas._press_at)
	assert_eq(main.edit_doc.floor_plan.rooms.size(), 3, "a living room put where clicked")
	plan_view.canvas.tool = FloorPlanCanvas.Tool.SELECT
	plan_view.canvas.selected = {}
	assert_true(plan_view._list.visible, "the parts to place with nothing picked")
	plan_view.canvas.selected = {"kind": "room", "index": 0}
	assert_false(plan_view._list.visible, "a room picked shows the room alone")
	assert_false(plan_view._list_title.visible)
	await wait_process_frames(2)
	# While simulating, a click on the switch on the plan switches it.
	main._set_mode(Main.Mode.SIMULATE)
	(main.view.document.circuit.get_component("FA1") as CircuitBreaker).switched_on = true
	main.view.step_once(0.0)
	var canvas: FloorPlanCanvas = plan_view.canvas
	assert_false(canvas.editing)
	canvas._operate(canvas.to_screen(canvas.symbol_center("SF1")))
	assert_true((main.view.document.circuit.get_component("SF1") as LightSwitch).on[0], "switched on from the plan")
	assert_true((main.view.document.circuit.get_component("EA1") as Luminaire).energized, "the light is on")
	await wait_process_frames(2)


func test_consumer_unit_made_once_with_the_devices() -> void:
	var doc: SchematicDocument = _house()
	var index: int = doc.ensure_consumer_unit()
	assert_eq(doc.switchboards[index].name, FloorPlan.UNIT.trim_prefix("+"), "switchboard RD1")
	var on_rails: PackedStringArray = PackedStringArray()
	for rail: CabinetRail in doc.switchboards[index].rails:
		for item: CabinetItem in rail.items:
			on_rails.append(item.designation)
	assert_has(on_rails, "FA1", "the breaker on its rail")
	assert_eq(doc.ensure_consumer_unit(), index, "made only once")
	assert_eq(doc.switchboards.size(), 1)


func test_consumer_unit_opened_from_the_plan() -> void:
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	add_child_autofree(main)
	main._recovery_dialog.hide()
	main._start_dialog.hide()
	main._replace_document(_house(), "")
	main._set_area(Main.Area.WORKSPACE)
	var plan_view: FloorPlanView = main._floor_plan
	plan_view.open_unit()
	assert_eq(main.edit_doc.switchboards.size(), 1, "RD1 made in Edit mode, undoably")
	assert_not_null(plan_view._unit, "the unit in place of the plan")
	assert_false(plan_view._body.visible)
	plan_view.close_unit()
	assert_null(plan_view._unit)
	assert_true(plan_view._body.visible, "back to the plan")
	main.editor.undo()
	assert_eq(main.edit_doc.switchboards.size(), 0, "undone")
	await wait_process_frames(2)


func test_floor_plan_sheet_in_the_export() -> void:
	var renderer: SheetRenderer = autofree(SheetRenderer.new())
	var doc: SchematicDocument = _house()
	doc.floor_plan.place("SF1", Vector2(3.0, 1.0), false)
	renderer.workspace = true
	var kinds: PackedStringArray = PackedStringArray()
	for spec: Dictionary in renderer.sheets(doc, PackedInt32Array([0])):
		kinds.append(spec["kind"])
	assert_eq(kinds, PackedStringArray(["page", "floor_plan"]), "the floor plan in place of the workspace")
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.legend = true
	var area: Rect2 = canvas.paper_area()
	assert_true(area.encloses(doc.floor_plan.bounds()), "the whole plan on the sheet")
	assert_gte(area.size.y, doc.floor_plan.bounds().size.y + FloorPlanCanvas.LEGEND_HEIGHT, "room for the legend of heights")


func test_wall_lengths_set_like_in_cad() -> void:
	var doc: SchematicDocument = _house()
	var plan: FloorPlan = doc.floor_plan
	plan.place("SF1", Vector2(3.0, 1.0), false)
	plan.doors.append(FloorPlan.Door.new(Vector2(3.0, 0.75), true))
	# The hall's right wall is the room's left wall: both move, and what is on it.
	plan.set_wall(0, 2, 3.5)
	assert_eq(plan.rooms[0].rect, Rect2(0, 0, 3.5, 1.5))
	assert_eq(plan.rooms[1].rect, Rect2(3.5, 0, 3.5, 4), "the room sharing the wall keeps sharing it")
	assert_eq(plan.parts["SF1"], Vector2(3.5, 1.0), "the switch on the wall moves with it")
	assert_eq(plan.doors[0].at, Vector2(3.5, 0.75), "the door too")
	plan.set_wall(0, 2, 0.1)
	assert_almost_eq(plan.rooms[0].rect.size.x, FloorPlan.MIN_ROOM, 0.001, "never smaller than a room can be")
	plan.resize_room(1, Vector2(5.0, 2.5))
	assert_eq(plan.rooms[1].rect.size, Vector2(5.0, 2.5), "typed as its width and height")
	# The canvas shows the selected room's dimensions and asks for a length.
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.editing = true
	canvas.selected = {"kind": "room", "index": 1}
	var asked: Array[Vector2i] = []
	canvas.length_requested.connect(func(index: int, side: int) -> void: asked.append(Vector2i(index, side)))
	var top: Vector2 = canvas.to_screen(Vector2(plan.rooms[1].rect.get_center().x, plan.rooms[1].rect.position.y - canvas._dimension_gap()))
	assert_eq(canvas.dimension_at(top), Vector2i(1, 0), "its width over its top wall")


func test_plan_palette_draws_the_plan_symbols() -> void:
	var palette: Palette = autofree(Palette.new())
	add_child(palette)
	palette.environment = SchematicDocument.Kind.RESIDENTIAL
	palette.plan = true
	assert_eq(palette.entries(), Palette.PLAN_ENTRIES)
	var glyphs: int = 0
	for button: Button in palette._buttons:
		for tile: Node in button.get_children():
			for child: Node in tile.get_children():
				if child is PlanGlyph:
					glyphs += 1
	assert_eq(glyphs, Palette.PLAN_ENTRIES.size(), "every part as the plan draws it")


func test_door_swing_and_undo_on_the_plan() -> void:
	var door: FloorPlan.Door = FloorPlan.Door.new(Vector2(3, 1), true)
	var seen: Dictionary[String, bool] = {}
	for k: int in 4:
		seen["%s %s" % [door.hinge_end, door.opens_back]] = true
		door.turn()
	assert_eq(seen.size(), 4, "a double click goes round the four ways")
	assert_false(door.hinge_end or door.opens_back, "and back")
	var plan: FloorPlan = FloorPlan.new()
	door.hinge_end = true
	door.opens_back = true
	plan.doors.append(door)
	var again: FloorPlan = FloorPlan.from_data(plan.to_data())
	assert_true(again.doors[0].hinge_end and again.doors[0].opens_back, "saved")
	# Ctrl+Z on the floor plan undoes its last edit.
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	add_child_autofree(main)
	main._recovery_dialog.hide()
	main._start_dialog.hide()
	main._replace_document(_house(), "")
	main._set_area(Main.Area.WORKSPACE)
	main._floor_plan._add_preset(0)
	var plan_canvas: FloorPlanCanvas = main._floor_plan.canvas
	plan_canvas._press_at = plan_canvas.to_screen(Vector2(10.0, 2.0))
	plan_canvas._mouse = plan_canvas._press_at
	plan_canvas._release({"kind": "place_room"}, plan_canvas._press_at)
	assert_eq(main.edit_doc.floor_plan.rooms.size(), 3)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_Z
	key.ctrl_pressed = true
	key.pressed = true
	assert_true(main._shortcut(key))
	assert_eq(main.edit_doc.floor_plan.rooms.size(), 2, "undone by Ctrl+Z")
	key.keycode = KEY_Y
	main._shortcut(key)
	assert_eq(main.edit_doc.floor_plan.rooms.size(), 3, "redone by Ctrl+Y")
	await wait_process_frames(2)


func test_l_shaped_rooms_double_doors_and_labels() -> void:
	var plan: FloorPlan = FloorPlan.new()
	plan.rooms.append(FloorPlan.Room.new("Living room", Rect2(0, 0, 4, 3)))
	plan.rooms.append(FloorPlan.Room.new("Room", Rect2(0, 3, 2, 2)))
	plan.rooms.append(FloorPlan.Room.new("Hall", Rect2(10, 0, 2, 2)))
	assert_false(plan.join_rooms(0, 2), "rooms apart do not join")
	assert_true(plan.join_rooms(0, 1), "touching along a wall: one room")
	assert_eq(plan.rooms.size(), 2)
	var room: FloorPlan.Room = plan.rooms[0]
	assert_eq(room.points.size(), 6, "an L")
	assert_almost_eq(room.area(), 16.0, 0.001)
	assert_eq(room.name, "Living room", "the first keeps its name")
	assert_true(room.contains(Vector2(1, 4)))
	assert_false(room.contains(Vector2(3, 4)), "the corner cut out is not in it")
	var wall: Dictionary = plan.wall_near(Vector2(3, 3.2))
	assert_eq(wall["at"], Vector2(3, 3), "onto the inner wall of the L")
	assert_eq(FloorPlan.FACING[wall["facing"]], Vector2.UP)
	# Each wall's length is typed: the wall after it moves.
	for k: int in room.points.size():
		var w: PackedVector2Array = room.wall(k)
		if w[0] == Vector2(2, 5) and w[1] == Vector2(0, 5):
			plan.set_wall_length(0, (k + 5) % 6, 2.5)
	assert_almost_eq(room.area(), 4 * 3 + 2 * 2.5, 0.001, "the leg made longer")
	var preset: FloorPlan.Room = FloorPlan.preset_room(FloorPlan.PRESETS.size() - 1, Vector2.ZERO, "Living room")
	assert_eq(preset.points.size(), 6, "an L-shaped room to start from")
	plan.doors.append(FloorPlan.Door.new(Vector2(4, 1.5), true, 1.6))
	plan.doors[0].double = true
	room.label_offset = Vector2(0.5, 1.0)
	var again: FloorPlan = FloorPlan.from_data(plan.to_data())
	assert_eq(again.rooms[0].points, room.points, "saved as its outline")
	assert_true(again.doors[0].double, "a double door")
	assert_eq(again.rooms[0].label_offset, Vector2(0.5, 1.0), "the label where it was moved")


func test_designations_kept_clear_of_each_other() -> void:
	var doc: SchematicDocument = _house()
	doc.floor_plan.place("SF1", Vector2(3.0, 1.0), false)
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	var font: Font = ThemeDB.fallback_font
	var s: float = FloorPlanCanvas.PX
	var center: Vector2 = Vector2(200, 200)
	# A switch back to back on the right: the designation goes left of it.
	canvas._taken = [Rect2(center + Vector2(12, -12), Vector2(24, 24))]
	var spot: Vector2 = canvas._label_spot("SF1", center, Vector2.RIGHT, "-SF1", "", s, font)
	assert_lt(spot.x, center.x, "to the other side, clear of the other symbol")
	var again: Vector2 = canvas._label_spot("SF1", center, Vector2.RIGHT, "-SF1", "", s, font)
	assert_ne(again, spot, "never on a designation already there")
	assert_eq(canvas._taken.size(), 3, "each takes its place")


func test_wall_luminaire_goes_onto_a_wall() -> void:
	var lamp: Luminaire = DocumentSerializer.component_from_dict({"type": "luminaire", "wall": true, "designation": "EA2"}) as Luminaire
	assert_true(lamp.wall)
	assert_almost_eq(lamp.height, Luminaire.WALL_HEIGHT, 1e-6, "its own standard height")
	var again: Luminaire = DocumentSerializer.component_from_dict(DocumentSerializer.component_to_dict(lamp)) as Luminaire
	assert_true(again.wall, "saved and loaded")
	assert_false(FloorPlanCanvas.on_ceiling(lamp))
	assert_true(FloorPlanCanvas.on_ceiling(Luminaire.new("EA1")))
	var doc: SchematicDocument = _house()
	doc.add(lamp, Vector2i(20, 16))
	doc.floor_plan.place("EA2", Vector2(3.9, 0.1), FloorPlanCanvas.on_ceiling(lamp))
	assert_true(doc.floor_plan.facing.has("EA2"), "on the wall, facing into the room")
	var titles: PackedStringArray = PackedStringArray()
	for entry: Dictionary in Palette.PLAN_ENTRIES:
		titles.append(entry["title"])
	assert_true(titles.has("Wall luminaire"))


func test_windows_and_wall_thickness() -> void:
	var doc: SchematicDocument = _house()
	var plan: FloorPlan = doc.floor_plan
	var window: FloorPlan.WindowOpening = FloorPlan.WindowOpening.new(Vector2(5.0, 0.0), false)
	window.sill = 1.1
	plan.windows.append(window)
	plan.outer_wall = 0.45
	# The hall and the room share x = 3 from y 0 to 1.5: the wall between them.
	var pieces: Array[PackedVector2Array] = plan.inner_pieces()
	assert_eq(pieces.size(), 1, "one wall between rooms")
	assert_eq(pieces[0], PackedVector2Array([Vector2(3, 0), Vector2(3, 1.5)]))
	assert_true(plan.inner_wall_at(Vector2(3.0, 1.0), Vector2.RIGHT), "between the hall and the room")
	assert_false(plan.inner_wall_at(Vector2(3.0, 3.0), Vector2.RIGHT), "below the hall: an outside wall")
	assert_true(plan.bounds().grow(0.001).encloses(Rect2(-0.45, -0.45, 7.9, 4.9)), "the outside walls are in the bounds")
	# A window moves with its room, and is saved.
	plan.move_room(1, Vector2(3.0, 1.0))
	assert_eq(plan.windows[0].at, Vector2(5.0, 1.0))
	var again: FloorPlan = FloorPlan.from_data(plan.to_data())
	assert_eq(again.windows.size(), 1)
	assert_almost_eq(again.windows[0].sill, 1.1, 1e-6)
	assert_almost_eq(again.windows[0].width, FloorPlan.WINDOW_WIDTH, 1e-6)
	assert_almost_eq(again.outer_wall, 0.45, 1e-6)
	assert_almost_eq(again.inner_wall, FloorPlan.INNER_WALL, 1e-6)
	assert_false(FloorPlan.from_data({"rooms": []}).to_data().has("walls"), "the usual walls are not written")
	# A socket on the wall between rooms is drawn at the wall's face: the
	# wall lies in the hall, out of the way of the room, whose wall goes on
	# outside below the hall.
	plan.move_room(1, Vector2(3.0, 0.0))
	plan.place("XD1", Vector2(3.0, 1.0), false)
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	var into: Vector2 = FloorPlan.FACING[plan.facing["XD1"]]
	var piece: Dictionary = plan.wall_piece_at(Vector2(3.0, 1.0))
	assert_almost_eq(float(piece["to"]) - float(piece["from"]), FloorPlan.INNER_WALL, 1e-6)
	assert_almost_eq(canvas._face("XD1").length(), 0.0 if into == Vector2.RIGHT else FloorPlan.INNER_WALL, 1e-6)


func test_dimension_chains_and_free_dimensions() -> void:
	var doc: SchematicDocument = _house()
	var plan: FloorPlan = doc.floor_plan
	# The room's top wall (3,0)-(7,0): a socket at x 4, a window 5.5 wide 1.2.
	plan.place("XD1", Vector2(4.0, 0.05), false)
	plan.windows.append(FloorPlan.WindowOpening.new(Vector2(5.5, 0.0), false))
	var chain: FloorPlan.Dimension = FloorPlan.Dimension.new()
	chain.room = 1
	chain.wall = 0
	plan.dimensions.append(chain)
	var stops: PackedFloat32Array = plan.dimension_stops(chain)
	assert_eq(stops.size(), 5, "the corners, the socket and the window's ends")
	assert_almost_eq(stops[1], 1.0, 0.002)
	assert_almost_eq(stops[2], 1.9, 0.002)
	assert_almost_eq(stops[3], 3.1, 0.002)
	var free: FloorPlan.Dimension = FloorPlan.Dimension.new()
	free.a = Vector2(0, 0)
	free.b = Vector2(0, 1.5)
	free.offset = -0.4
	plan.dimensions.append(free)
	assert_eq(plan.dimension_stops(free).size(), 2, "a free one: its two ends")
	var again: FloorPlan = FloorPlan.from_data(plan.to_data())
	assert_eq(again.dimensions.size(), 2)
	assert_eq(again.dimensions[0].room, 1)
	assert_eq(again.dimensions[1].b, Vector2(0, 1.5))
	assert_almost_eq(again.dimensions[1].offset, -0.4, 1e-6)
	# The canvas finds it on its line and catches the corners.
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	var line: PackedVector2Array = canvas._dimension_geometry(0)["line"]
	assert_almost_eq(line[0].y, -(plan.outer_wall + FloorPlan.DIMENSION_OFFSET), 1e-4, "past the outside wall")
	assert_eq(canvas.saved_dimension_at(canvas.to_screen((line[0] + line[1]) * 0.5)), 0)
	assert_eq(canvas._feature_point(Vector2(3.05, 0.03)), Vector2(3, 0), "a corner caught")
	# A room taken away takes its chains; a later room's move up.
	plan.remove_room(0)
	assert_eq(plan.dimensions.size(), 2)
	assert_eq(plan.dimensions[0].room, 0, "the room after it is now first")
	plan.remove_room(0)
	assert_eq(plan.dimensions.size(), 1, "its chain gone, the free one kept")


func test_typed_distance_and_arrays() -> void:
	var doc: SchematicDocument = _house()
	var plan: FloorPlan = doc.floor_plan
	# The room's top wall from (3,0) to (7,0), a door at 4.5 (ends 4.1 and 4.9).
	plan.doors.append(FloorPlan.Door.new(Vector2(4.5, 0.0), false))
	var ref: Dictionary = plan.wall_reference(Vector2(5.3, 0.0))
	assert_eq(ref["from"], Vector2(4.9, 0.0), "the door's end is nearer than a corner")
	assert_almost_eq(float(ref["distance"]), 0.4, 1e-4)
	assert_eq(plan.at_distance(Vector2(5.3, 0.0), 0.15), Vector2(5.05, 0.0), "150 mm from the door frame")
	assert_eq(plan.at_distance(Vector2(6.8, 0.0), 0.3), Vector2(6.7, 0.0), "300 mm from the corner")
	plan.place_on_wall("XD1", Vector2(5.05, 0.0))
	assert_eq(plan.parts["XD1"], Vector2(5.05, 0.0), "exactly there, not on the grid")
	# Arrays.
	assert_eq(plan.grid_points(1, 2, 2), PackedVector2Array([Vector2(4, 1), Vector2(6, 1), Vector2(4, 3), Vector2(6, 3)]))
	assert_eq(plan.row_points(1, 2, 2), PackedVector2Array([Vector2(4, 4), Vector2(6, 4)]), "the bottom wall, from its left end, evenly")
	assert_eq(plan.row_points(1, 0, 5, 0.5, 1.5), PackedVector2Array([Vector2(3.5, 0), Vector2(5, 0), Vector2(6.5, 0)]), "every 1.5 m from 0.5 m, as far as it goes")
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	doc.single_line.add(doc, _component_of({"type": "breaker"}, "FA9"), 0)
	var made: String = FloorPlanCanvas.add_part(doc, {"type": "socket", "gangs": 2}, doc.single_line.feeder_of("FA9").number, Vector2(4, 4), true, 3)
	assert_false(made.is_empty())
	assert_eq(plan.facing[made], 3, "facing up into the room")
	assert_true(doc.single_line.feeder_of("FA9").loads.has(made), "on the circuit")
	# Typed while placing on the canvas.
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.editing = true
	canvas.selected = {"kind": "part", "designation": "XD1"}
	assert_true(canvas._takes_distance())
	var edits: Array[Callable] = []
	canvas.edit_requested.connect(func(change: Callable) -> void: edits.append(change))
	for code: int in [KEY_2, KEY_0, KEY_0]:
		var key: InputEventKey = InputEventKey.new()
		key.pressed = true
		key.keycode = code
		key.unicode = OS.get_keycode_string(code).unicode_at(0)
		canvas._type_distance(key)
	assert_eq(canvas._typed, "200")
	var enter: InputEventKey = InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	canvas._type_distance(enter)
	assert_eq(edits.size(), 1)
	edits[0].call(doc)
	assert_eq(plan.parts["XD1"], Vector2(5.1, 0.0), "200 mm from the door frame")


func _component_of(template: Dictionary, designation: String) -> CircuitComponent:
	var data: Dictionary = template.duplicate()
	data["designation"] = designation
	return DocumentSerializer.component_from_dict(data)


func test_notes_and_furniture() -> void:
	var doc: SchematicDocument = _house()
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	var plan: FloorPlan = doc.floor_plan
	# A worktop dropped near the room's top wall goes against it, facing down.
	var worktop: FloorPlan.Fixture = plan.fixture_at_point("worktop", Vector2(5.0, 0.4))
	assert_eq(worktop.facing, 1)
	assert_eq(worktop.rect, Rect2(3.8, 0.0, 2.4, 0.6), "its back on the wall, in the middle where dropped")
	plan.fixtures.append(worktop)
	assert_true(plan.over_worktop(Vector2(4.5, 0.0)))
	assert_false(plan.over_worktop(Vector2(6.5, 0.0)), "past its end")
	doc.single_line.add(doc, _component_of({"type": "breaker"}, "FA9"), 0)
	var socket: String = FloorPlanCanvas.add_part(doc, {"type": "socket", "gangs": 2}, doc.single_line.feeder_of("FA9").number, Vector2(4.5, 0.1))
	assert_almost_eq((doc.circuit.get_component(socket) as SocketOutlet).height, FloorPlan.WORKTOP_SOCKET_HEIGHT, 1e-6, "over the worktop at 1.10 m")
	# Turned, resized, moved with its room, saved.
	plan.turn_fixture(0)
	assert_eq(plan.fixtures[0].facing, 2)
	assert_eq(plan.fixtures[0].rect.size, Vector2(0.6, 2.4))
	plan.resize_fixture(0, 3.0, 0.65)
	assert_almost_eq(plan.fixtures[0].extent().x, 3.0, 1e-6)
	var note: FloorPlan.Note = FloorPlan.Note.new()
	note.text = "Vývod pro digestoř\nh 2,20"
	note.at = Vector2(5.0, 1.0)
	note.label = Vector2(5.5, 0.5)
	plan.notes.append(note)
	plan.move_room(1, Vector2(3.0, 1.0))
	assert_eq(plan.notes[0].at, Vector2(5.0, 2.0), "the note moves with its room")
	var again: FloorPlan = FloorPlan.from_data(plan.to_data())
	assert_eq(again.notes.size(), 1)
	assert_eq(again.notes[0].text, "Vývod pro digestoř\nh 2,20")
	assert_eq(again.fixtures.size(), 1)
	assert_eq(again.fixtures[0].kind, "worktop")
	assert_eq(again.fixtures[0].facing, 2)
	# The canvas finds them.
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	assert_eq(canvas.note_at(canvas.to_screen(plan.notes[0].at))["end"], "anchor")
	assert_eq(canvas.fixture_at(canvas.to_screen(plan.fixtures[0].rect.get_center())), 0)


func test_floors_and_underlay() -> void:
	var doc: SchematicDocument = _house()
	doc.floor_plan.place("SF1", Vector2(3.0, 1.0), false)
	assert_eq(doc.floor_plan.floor_name(), "1.NP")
	assert_eq(doc.floor_plan.room_number(0), "101")
	var upper: int = doc.add_floor()
	assert_eq(upper, 1)
	assert_eq(doc.floors[1].floor_name(), "2.NP")
	var basement: int = doc.add_floor(true)
	assert_eq(basement, 0, "the basement first, lowest")
	assert_eq(doc.floors[0].floor_name(), "1.PP")
	assert_eq(doc.floor, 1, "the floor shown stays the ground floor")
	doc.floors[0].rooms.append(FloorPlan.Room.new("Cellar", Rect2(0, 0, 4, 3)))
	assert_eq(doc.floors[0].room_number(0), "001")
	doc.floors[2].rooms.append(FloorPlan.Room.new("Bedroom", Rect2(0, 0, 4, 3)))
	assert_eq(doc.floors[2].room_number(0), "201")
	# A part placed upstairs is placed; one on no floor is listed.
	doc.floors[2].place("EA1", Vector2(1.0, 1.0), true)
	assert_eq(doc.floor_of("EA1"), 2)
	assert_eq(doc.unplaced_parts(), PackedStringArray(["+RD1", "XD1"]), "the consumer unit and the socket")
	# Taken away everywhere when its part goes.
	doc.remove_component(doc.circuit.get_component("EA1").id)
	assert_eq(doc.floor_of("EA1"), -1)
	# Saved with all floors and the underlay.
	doc.floors[2].underlay = "/tmp/plan.png"
	doc.floors[2].underlay_at = Vector2(-1, -1)
	FloorPlanView.scale_underlay(doc.floors[2], Vector2(1, 1), 2.0)
	assert_almost_eq(doc.floors[2].underlay_scale, FloorPlan.UNDERLAY_SCALE * 2.0, 1e-9)
	assert_eq(doc.floors[2].underlay_at, Vector2(-3, -3), "the point kept where it was")
	var again: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(again.floors.size(), 3)
	assert_eq(again.floors[0].level, -1)
	assert_eq(again.floors[2].rooms[0].name, "Bedroom")
	assert_eq(again.floors[2].underlay, "/tmp/plan.png")
	assert_eq(again.floor, 1)
	assert_eq(again.floor_of("SF1"), 1)
	# A sheet a floor with something on it.
	var renderer: SheetRenderer = autofree(SheetRenderer.new())
	renderer.workspace = true
	renderer.schematic = false
	var floors: Array = []
	for spec: Dictionary in renderer.sheets(again, PackedInt32Array([0])):
		floors.append(spec.get("floor", -1))
	assert_eq(floors, [0, 1, 2])


func test_handles_resize_what_is_selected() -> void:
	var doc: SchematicDocument = _house()
	var plan: FloorPlan = doc.floor_plan
	# The room's top right corner (7, 0) pulled to (8, -1): its top and right walls follow.
	plan.set_corner(1, 1, Vector2(8.0, -1.0))
	assert_eq(plan.rooms[1].rect, Rect2(3, -1, 5, 5))
	# A door's right end pulled out: its left end stays.
	var door: FloorPlan.Door = FloorPlan.Door.new(Vector2(5.0, 4.0), false)
	FloorPlan.stretch_opening(door, 1, Vector2(6.0, 4.1), 0.5, 3.0)
	assert_almost_eq(door.width, 1.4, 1e-4)
	assert_eq(door.ends()[0], Vector2(4.6, 4.0), "the other end stays")
	FloorPlan.stretch_opening(door, 0, Vector2(6.0, 4.0), 0.5, 3.0)
	assert_almost_eq(door.width, 0.5, 1e-4, "never narrower than a door can be")
	# A fixture's corner pulled; the opposite one stays.
	assert_eq(FloorPlan.stretch_rect(Rect2(1, 1, 2, 1), 2, Vector2(4.0, 3.0)), Rect2(1, 1, 3, 2))
	assert_eq(FloorPlan.stretch_rect(Rect2(1, 1, 2, 1), 0, Vector2(3.1, 0.0)), Rect2(3, 0, 0.2, 2), "past the other corner: at least its least side")
	# The canvas shows the handles of the selection and the room legend moves.
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.editing = true
	canvas.selected = {"kind": "room", "index": 0}
	assert_eq(canvas.handles().size(), 4, "a room's corners")
	assert_eq(canvas.handle_at(canvas.to_screen(Vector2(3, 0)))["kind"], "corner")
	plan.legend_offset = Vector2(-2, 6)
	assert_eq(FloorPlan.from_data(plan.to_data()).legend_offset, Vector2(-2, 6))


func test_symbol_and_text_sizes() -> void:
	var doc: SchematicDocument = _house()
	var plan: FloorPlan = doc.floor_plan
	plan.place("SF1", Vector2(3.0, 1.0), false)
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	assert_eq(canvas._sized(FloorPlanCanvas.TEXT_SIZE), FloorPlanCanvas.TEXT_SIZE, "as usual")
	var usual: float = canvas.symbol_center("SF1").distance_to(plan.parts["SF1"])
	plan.symbol_scale = 2.0
	plan.text_scale = 1.5
	assert_eq(canvas._sized(FloorPlanCanvas.TEXT_SIZE), roundi(FloorPlanCanvas.TEXT_SIZE * 1.5))
	assert_almost_eq(canvas.symbol_center("SF1").distance_to(plan.parts["SF1"]), usual + FloorPlanCanvas.WALL_SYMBOL_OFFSET, 1e-4, "a larger symbol's middle further in")
	var again: FloorPlan = FloorPlan.from_data(plan.to_data())
	assert_almost_eq(again.symbol_scale, 2.0, 1e-6)
	assert_almost_eq(again.text_scale, 1.5, 1e-6)
	assert_false(FloorPlan.from_data({"rooms": []}).to_data().has("sizes"), "the usual sizes are not written")


func test_wall_symbols_moved_off_their_wall() -> void:
	var doc: SchematicDocument = _house()
	var plan: FloorPlan = doc.floor_plan
	plan.place("SF1", Vector2(3.3, 1.0), false)
	plan.place("EA1", Vector2(5.0, 2.0), true)
	plan.set_offset("EA1", 0.4)
	assert_false(plan.offsets.has("EA1"), "a luminaire on the ceiling is on no wall")
	plan.set_offset("SF1", 9.0)
	assert_eq(plan.offsets["SF1"], FloorPlan.MAX_OFFSET, "never further than MAX_OFFSET")
	plan.set_offset("SF1", 0.234)
	assert_almost_eq(plan.offsets["SF1"], 0.23, 1e-6, "to the centimetre")
	var loaded: FloorPlan = FloorPlan.from_data(plan.to_data())
	assert_almost_eq(loaded.offsets.get("SF1", 0.0), 0.23, 1e-6, "saved")
	assert_false(loaded.offsets.has("EA1"))
	plan.place("SF1", Vector2(3.3, 2.0), false)
	assert_true(plan.offsets.has("SF1"), "moved along its wall it stays off it")
	plan.rename("SF1", "SF2")
	assert_true(plan.offsets.has("SF2"), "renamed along")
	plan.set_offset("SF2", 0.0)
	assert_false(plan.offsets.has("SF2"), "back on its wall")
	# Dragged off its wall by its handle on the canvas.
	plan.place("SF2", Vector2(3.3, 1.0), false)
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.editing = true
	canvas.size = Vector2(1000, 700)
	canvas.edit_requested.connect(func(change: Callable) -> void: change.call(doc))
	var before: Vector2 = canvas.symbol_center("SF2")
	canvas.selected = {"kind": "part", "designation": "SF2"}
	var handle: Dictionary = canvas.handles()[0]
	assert_eq(handle["kind"], "part_offset", "a part on a wall has the handle")
	assert_eq(canvas.handle_at(canvas.to_screen(handle["at"]))["kind"], "part_offset")
	canvas._press_at = canvas.to_screen(handle["at"])
	canvas._press = canvas._pressed(canvas._press_at)
	canvas._dragging = true
	canvas._mouse = canvas.to_screen(handle["at"] + Vector2(0.5, 0.3))
	assert_almost_eq(canvas.symbol_center("SF2").x, before.x + 0.5, 1e-4, "shown off its wall while dragged")
	var press: Dictionary = canvas._press
	canvas._press = {}
	canvas._release(press, canvas._mouse)
	assert_almost_eq(plan.offsets["SF2"], 0.5, 1e-6, "into the room only, as far as dragged")
	assert_almost_eq(canvas.symbol_center("SF2").x, before.x + 0.5, 1e-4)
	canvas.selected = {"kind": "part", "designation": "EA1"}
	assert_true(canvas.handles().is_empty(), "a luminaire on the ceiling has none")


func test_ghosts_and_previews_drawn() -> void:
	var doc: SchematicDocument = _house()
	var canvas: FloorPlanCanvas = FloorPlanCanvas.new()
	canvas.document = doc
	canvas.editing = true
	canvas.size = Vector2(1000, 700)
	add_child_autofree(canvas)
	# The door and the window a click would put in, drawn where they go.
	for tool: FloorPlanCanvas.Tool in [FloorPlanCanvas.Tool.DOOR, FloorPlanCanvas.Tool.WINDOW]:
		canvas.tool = tool
		canvas._mouse = canvas.to_screen(Vector2(5.0, 4.05))
		canvas.queue_redraw()
		await get_tree().process_frame
	# A corner the hall and the room share, dragged: both rooms shown moved.
	canvas.tool = FloorPlanCanvas.Tool.SELECT
	canvas.selected = {"kind": "room", "index": 0}
	canvas._press_at = canvas.to_screen(Vector2(3, 0))
	canvas._press = canvas._pressed(canvas._press_at)
	assert_eq(canvas._press["kind"], "corner")
	canvas._dragging = true
	canvas._mouse = canvas.to_screen(Vector2(3.5, 0.2))
	var preview: FloorPlan = canvas._room_preview()
	assert_not_null(preview)
	assert_eq(canvas._shown_points(0), preview.rooms[0].points)
	assert_true(canvas._shown_points(1).has(Vector2(3.5, 0)), "the room beside it moves along")
	canvas.queue_redraw()
	await get_tree().process_frame
	canvas._dragging = false
	assert_null(canvas._room_preview())


func test_door_kinds_turned_by_their_corner() -> void:
	var doc: SchematicDocument = _house()
	var plan: FloorPlan = doc.floor_plan
	# Saved by kind, a garage door wide.
	var garage: FloorPlan.Door = FloorPlan.Door.new(Vector2(5, 4), false, 4.0)
	garage.kind = FloorPlan.DoorKind.GARAGE
	plan.doors.append(garage)
	var again: FloorPlan = FloorPlan.from_data(plan.to_data())
	assert_eq(again.doors[0].kind, FloorPlan.DoorKind.GARAGE)
	assert_almost_eq(again.doors[0].width, 4.0, 1e-6)
	plan.doors.clear()
	var canvas: FloorPlanCanvas = FloorPlanCanvas.new()
	canvas.document = doc
	canvas.editing = true
	canvas.size = Vector2(1000, 700)
	canvas.edit_requested.connect(func(change: Callable) -> void: change.call(doc))
	add_child_autofree(canvas)
	# Put in of the kind chosen last, every kind drawn.
	for kind: int in FloorPlan.DOOR_KINDS.size():
		canvas.door_kind = kind
		canvas.tool = FloorPlanCanvas.Tool.DOOR
		canvas._mouse = canvas.to_screen(Vector2(5.0, 3.95))
		canvas.queue_redraw()
		await get_tree().process_frame
	canvas.door_kind = FloorPlan.DoorKind.SWING
	canvas._release({"kind": "new_door"}, canvas.to_screen(Vector2(5.0, 3.95)))
	assert_eq(plan.doors.size(), 1)
	var door: FloorPlan.Door = plan.doors[0]
	assert_false(door.hinge_end or door.opens_back)
	# Taken by its leaf too, not only in the wall.
	var leaf: Vector2 = canvas.door_corner(door)
	assert_eq(canvas.door_at(canvas.to_screen(door.at.lerp(leaf, 0.5))), 0, "the swing is part of it")
	canvas.tool = FloorPlanCanvas.Tool.SELECT
	canvas.selected = {"kind": "door", "index": 0}
	var handle: Dictionary = canvas.handle_at(canvas.to_screen(leaf))
	assert_eq(handle.get("kind", ""), "door_swing", "a handle at the end of its leaf")
	# Dragged to the corner at its other end, on the other side of the wall.
	canvas._press_at = canvas.to_screen(leaf)
	canvas._press = handle
	canvas._dragging = true
	var other: Vector2 = door.at + Vector2(door.width * 0.5, 0.0) - FloorPlanCanvas.door_across(door) * door.width
	canvas._mouse = canvas.to_screen(other)
	var shown: FloorPlan.Door = canvas._shown_opening("door", 0) as FloorPlan.Door
	assert_true(shown.hinge_end and shown.opens_back, "shown turned while dragged")
	canvas.queue_redraw()
	await get_tree().process_frame
	canvas._press = {}
	canvas._release(handle, canvas._mouse)
	canvas._dragging = false
	assert_true(door.hinge_end, "hinged at its other end")
	assert_true(door.opens_back, "opening to the other side")


func test_staircase_lighting_across_floors_and_the_floor_below() -> void:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	for designation: String in ["SF1", "SF2"]:
		var sw: LightSwitch = LightSwitch.new(designation)
		sw.circuit = "6"
		doc.add(sw, Vector2i(0, 10 if designation == "SF1" else 14))
	doc.add(Luminaire.new("EA1"), Vector2i(0, 18))
	var stairs: FloorPlan.Room = FloorPlan.Room.new("Staircase", Rect2(4, 5.5, 1.2, 3.5))
	stairs.stairs = true
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Hall", Rect2(0, 5.5, 4, 3.5)))
	doc.floor_plan.rooms.append(stairs)
	doc.floor_plan.place("SF1", Vector2(4.05, 8.6), false)
	doc.floor = doc.add_floor()
	var upper_stairs: FloorPlan.Room = FloorPlan.Room.new("Staircase", Rect2(4, 5.5, 1.2, 3.5))
	upper_stairs.stairs = true
	doc.floor_plan.rooms.append(upper_stairs)
	doc.floor_plan.place("SF2", Vector2(5.15, 6.0), false)
	doc.floor_plan.place("EA1", Vector2(4.6, 7.2), true)
	var canvas: FloorPlanCanvas = FloorPlanCanvas.new()
	canvas.document = doc
	canvas.editing = true
	canvas.size = Vector2(1000, 700)
	canvas.edit_requested.connect(func(change: Callable) -> void: change.call(doc))
	add_child_autofree(canvas)
	# Upstairs: the switch at the foot of the stairs shown in the staircase.
	var ghosts: Dictionary = canvas.stair_ghosts()
	assert_true(ghosts.has("SF1"), "the switch downstairs, in the staircase")
	assert_false(ghosts["SF1"]["up"])
	var ghost: Vector2 = canvas.to_screen(ghosts["SF1"]["at"])
	assert_eq(canvas.ghost_at(ghost), "SF1")
	# The lighting drawn from the switch upstairs to it, and to the light.
	canvas.tool = FloorPlanCanvas.Tool.WIRE
	for target: Vector2 in [ghost, canvas.to_screen(canvas.symbol_center("EA1"))]:
		canvas._press_at = canvas.to_screen(canvas.symbol_center("SF2"))
		var press: Dictionary = canvas._pressed(canvas._press_at)
		assert_eq(press.get("kind", ""), "new_link")
		canvas._release(press, target)
	assert_eq(doc.floor_plan.links.size(), 2)
	var graph: Dictionary[String, PackedStringArray] = SingleLine.lighting_graph(doc)
	assert_true(graph.has("SF1#0") and graph.has("EA1"), "a staircase over two floors")
	canvas.queue_redraw()
	await get_tree().process_frame
	# The floor below drawn under this one, its corners caught.
	assert_eq(canvas.reference_floor(), 0)
	assert_true(canvas._room_point(Vector2(0.05, 5.45)).distance_to(Vector2(0, 5.5)) < 1e-4, "onto the corner of the floor below")
	var below: PackedVector2Array = doc.floors[0].building_outlines()[0]
	below.append(below[0])
	assert_false(canvas._off_walls(below).is_empty(), "shown while nothing is drawn over it")
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Hall", Rect2(0, 5.5, 4, 3.5)))
	assert_true(canvas._off_walls(below).is_empty(), "hidden under the walls drawn over it")
	doc.floor_plan.rooms.remove_at(doc.floor_plan.rooms.size() - 1)
	# Downstairs: the link drawn upstairs shows to the switch and light upstairs.
	doc.floor = 0
	assert_true(canvas.stair_ghosts().has("SF2"))
	assert_true(canvas.stair_ghosts().has("EA1"))
	assert_eq(canvas.reference_floor(), 1, "the lowest floor drawn over the one above")
	canvas.queue_redraw()
	await get_tree().process_frame
	# The switch downstairs taken off the plan: its link upstairs goes too.
	canvas.tool = FloorPlanCanvas.Tool.SELECT
	canvas.selected = {"kind": "part", "designation": "SF1"}
	canvas.delete_selected()
	assert_eq(doc.floors[1].links.size(), 1, "only the light's link stays")


func test_floor_added_over_the_one_below() -> void:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.environment = SchematicDocument.Kind.RESIDENTIAL
	var plan: FloorPlan = doc.floor_plan
	plan.rooms.append(FloorPlan.Room.new("Living room", Rect2(0, 0, 6, 5)))
	plan.rooms.append(FloorPlan.Room.new("Hall", Rect2(0, 5, 4, 3)))
	var stairs: FloorPlan.Room = FloorPlan.Room.new("Staircase", Rect2(4, 5, 2, 3))
	stairs.stairs = true
	plan.rooms.append(stairs)
	var view: FloorPlanView = autofree(FloorPlanView.new())
	add_child(view)
	view.set_document(doc, true)
	view.edit_requested.connect(func(change: Callable) -> void:
		change.call(doc)
		view.refresh())
	view._on_floor_menu(0)
	assert_eq(doc.floors.size(), 2)
	var upper: FloorPlan = doc.floors[1]
	assert_eq(doc.floor_plan, upper, "the new floor shown")
	assert_eq(upper.rooms.size(), 2, "the house's outline and its staircase")
	var area: float = 0.0
	for room: FloorPlan.Room in upper.rooms:
		area += room.area()
	assert_almost_eq(area, 6.0 * 8.0, 1e-3, "the whole house")
	assert_true(upper.rooms.any(func(r: FloorPlan.Room) -> bool: return r.stairs and r.rect == Rect2(4, 5, 2, 3)), "the staircase in its place")
	assert_eq(upper.overlaps().size(), 0)
