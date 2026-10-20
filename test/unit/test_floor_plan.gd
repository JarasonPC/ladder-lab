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
	assert_eq(main.edit_doc.floor_plan.rooms.size(), 3, "a living room added")
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
	var top: Vector2 = canvas.to_screen(Vector2(plan.rooms[1].rect.get_center().x, plan.rooms[1].rect.position.y - FloorPlanCanvas.DIMENSION_GAP))
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
	main._replace_document(_house(), "")
	main._set_area(Main.Area.WORKSPACE)
	main._floor_plan._add_preset(0)
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
