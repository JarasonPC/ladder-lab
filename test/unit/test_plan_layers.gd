extends GutTest
## Layers of the floor plans: made, renamed and taken away with what is on
## them on every floor, saved, what is on a hidden one neither drawn nor
## picked, new things put on the active one, and the Layers menu.


## A room 6 × 4 with a switch SF1 and a socket XD1 on its walls, a
## luminaire EA1 on the ceiling, a note, a dimension and a table; a second
## floor with a socket XD2.
func _house() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("house")
	doc.residential = true
	doc.add(LightSwitch.new("SF1"), Vector2i(0, 10))
	doc.add(Luminaire.new("EA1"), Vector2i(0, 16))
	doc.add(SocketOutlet.new("XD1"), Vector2i(10, 10))
	doc.add(SocketOutlet.new("XD2"), Vector2i(20, 10))
	var plan: FloorPlan = doc.floor_plan
	plan.rooms.append(FloorPlan.Room.new("Living room", Rect2(0, 0, 6, 4)))
	plan.place("SF1", Vector2(0.0, 1.0), false)
	plan.place("XD1", Vector2(3.0, 4.0), false)
	plan.place("EA1", Vector2(3.0, 2.0), true)
	plan.place(FloorPlan.UNIT, Vector2(0.0, 3.0), false)
	var note: FloorPlan.Note = FloorPlan.Note.new()
	note.text = "Heating"
	note.at = Vector2(1.0, 1.0)
	note.label = Vector2(1.5, 0.5)
	plan.notes.append(note)
	var dim: FloorPlan.Dimension = FloorPlan.Dimension.new()
	dim.a = Vector2(0.0, 2.0)
	dim.b = Vector2(2.0, 2.0)
	plan.dimensions.append(dim)
	plan.fixtures.append(plan.fixture_at_point("table", Vector2(4.5, 2.5)))
	doc.floor = doc.add_floor()
	doc.floor_plan.rooms.append(FloorPlan.Room.new("Bedroom", Rect2(0, 0, 4, 4)))
	doc.floor_plan.place("XD2", Vector2(2.0, 4.0), false)
	doc.floor = 0
	return doc


func test_layers_saved_renamed_and_removed() -> void:
	var doc: SchematicDocument = _house()
	assert_true(doc.add_plan_layer(" Heating "))
	assert_eq(doc.plan_layers[0].name, "Heating", "trimmed")
	assert_false(doc.add_plan_layer("Heating"), "a name once")
	assert_false(doc.add_plan_layer("  "), "not an empty one")
	assert_true(doc.add_plan_layer("Sockets"))
	var plan: FloorPlan = doc.floor_plan
	plan.set_part_layer("XD1", "Sockets")
	plan.set_part_layer(FloorPlan.UNIT, "Sockets")
	assert_eq(plan.layer_of(FloorPlan.UNIT), "", "the consumer unit on none")
	plan.set_item_layer("note", 0, "", "Heating")
	plan.set_item_layer("dimension", 0, "", "Heating")
	plan.set_item_layer("fixture", 0, "", "Heating")
	doc.floors[1].set_part_layer("XD2", "Sockets")
	doc.plan_layer("Heating").shown = false
	# Saved and read back.
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(copy.plan_layers.size(), 2)
	assert_false(copy.layer_shown("Heating"))
	assert_true(copy.layer_shown("Sockets"))
	assert_true(copy.layer_shown(""), "no layer always")
	assert_true(copy.layer_shown("Gone"), "a layer there is no more: as none")
	assert_eq(copy.floors[0].layer_of("XD1"), "Sockets")
	assert_eq(copy.floors[1].layer_of("XD2"), "Sockets")
	for kind: String in ["note", "dimension", "fixture"]:
		assert_eq(copy.floors[0].item_layer(kind, 0, ""), "Heating", kind)
	# Renamed: what is on it on every floor along.
	assert_false(doc.rename_plan_layer("Sockets", "Heating"), "not onto a name taken")
	assert_true(doc.rename_plan_layer("Sockets", "Power"))
	assert_eq(doc.floors[0].layer_of("XD1"), "Power")
	assert_eq(doc.floors[1].layer_of("XD2"), "Power")
	# A part renamed or taken off the plan takes its layer along.
	plan.rename("XD1", "XD5")
	assert_eq(plan.layer_of("XD5"), "Power")
	plan.remove("XD5")
	assert_false(plan.part_layers.has("XD5"))
	# Taken away: what was on it stays, on none.
	doc.remove_plan_layer("Heating")
	assert_eq(doc.plan_layers.size(), 1)
	assert_eq(plan.notes.size(), 1)
	assert_eq(plan.notes[0].layer, "")
	assert_eq(plan.fixtures[0].layer, "")


func test_hidden_layer_neither_drawn_nor_picked() -> void:
	var doc: SchematicDocument = _house()
	doc.add_plan_layer("Hidden")
	var plan: FloorPlan = doc.floor_plan
	plan.add_link("SF1", 0, "EA1", 0)
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.editing = true
	var switch_at: Vector2 = canvas.to_screen(canvas.symbol_center("SF1"))
	var note_at: Vector2 = canvas.to_screen(plan.notes[0].at)
	var table_at: Vector2 = canvas.to_screen(plan.fixtures[0].rect.get_center())
	var dimension_at: Vector2 = canvas.to_screen((canvas._dimension_geometry(0)["line"] as PackedVector2Array)[0])
	assert_eq(canvas.part_at(switch_at), "SF1")
	assert_eq(canvas.note_at(note_at)["index"], 0)
	assert_eq(canvas.fixture_at(table_at), 0)
	assert_eq(canvas.saved_dimension_at(dimension_at), 0)
	plan.set_part_layer("SF1", "Hidden")
	for kind: String in ["note", "dimension", "fixture"]:
		plan.set_item_layer(kind, 0, "", "Hidden")
	assert_eq(canvas.part_at(switch_at), "SF1", "shown while its layer is")
	doc.plan_layer("Hidden").shown = false
	assert_eq(canvas.part_at(switch_at), "", "hidden")
	assert_true(canvas.note_at(note_at).is_empty())
	assert_eq(canvas.fixture_at(table_at), -1)
	assert_eq(canvas.saved_dimension_at(dimension_at), -1)
	assert_false(canvas.layer_shows("SF1"))
	assert_false(canvas._link_shown(plan.links[0]), "its lines with it")
	assert_true(canvas.layer_shows("EA1"), "what is on none stays")
	assert_true(canvas.layer_shows(FloorPlan.UNIT))
	# A right click on something hidden: no layer menu for it.
	assert_true(canvas._layered_at(switch_at).is_empty())
	doc.plan_layer("Hidden").shown = true
	assert_eq(canvas._layered_at(switch_at), {"kind": "part", "designation": "SF1"})


func test_new_things_go_on_the_active_layer() -> void:
	var doc: SchematicDocument = _house()
	doc.add_plan_layer("Furniture")
	var canvas: FloorPlanCanvas = autofree(FloorPlanCanvas.new())
	canvas.document = doc
	canvas.editing = true
	canvas.edit_requested.connect(func(change: Callable) -> void: change.call(doc))
	canvas.active_layer = "Gone"
	assert_eq(canvas.new_layer(), "", "a layer there is not: none")
	canvas.active_layer = "Furniture"
	canvas.tool = FloorPlanCanvas.Tool.PLACE
	canvas.placing_template = {"type": "fixture", "kind": "bed"}
	canvas._put_part(Vector2(1.0, 2.5), false)
	assert_eq(doc.floor_plan.fixtures.size(), 2)
	assert_eq(doc.floor_plan.fixtures[1].layer, "Furniture")
	# A part from the list of those not on a plan.
	doc.floor_plan.remove("EA1")
	canvas.placing_template = {}
	canvas.placing = "EA1"
	canvas._put_part(Vector2(2.0, 2.0), false)
	assert_eq(doc.floor_plan.layer_of("EA1"), "Furniture")


func test_layers_menu() -> void:
	var doc: SchematicDocument = _house()
	var view: FloorPlanView = autofree(FloorPlanView.new())
	add_child(view)
	view.set_document(doc, true)
	view.edit_requested.connect(func(change: Callable) -> void:
		change.call(doc)
		view.refresh())
	view._layer_asked = "new"
	view._layer_name.text = "Lighting"
	view._apply_layer_name()
	assert_eq(doc.plan_layers.size(), 1)
	assert_eq(view.canvas.active_layer, "Lighting", "a new layer takes what is put on next")
	view._fill_layers_menu()
	assert_gt(view._layers_menu.get_popup().item_count, 3)
	# Hidden from the menu: neither the selection nor the layer new things go on.
	view.canvas.selected = {"kind": "part", "designation": "SF1"}
	view._on_layers_menu(100)
	assert_false(doc.layer_shown("Lighting"))
	assert_eq(view.canvas.active_layer, "")
	assert_true(view.canvas.selected.is_empty())
	# Chosen to put things on: shown again.
	view._on_layers_menu(201)
	assert_eq(view.canvas.active_layer, "Lighting")
	assert_true(doc.layer_shown("Lighting"))
	# The selection right-clicked put on it.
	view.canvas.selected = {"kind": "note", "index": 0}
	view._on_layer_picked(1)
	assert_eq(doc.floor_plan.notes[0].layer, "Lighting")
	view._layer_asked = "rename"
	view._layer_name.text = "Light"
	view._apply_layer_name()
	assert_eq(doc.floor_plan.notes[0].layer, "Light")
	assert_eq(view.canvas.active_layer, "Light")
	view._on_layers_menu(2)
	assert_true(doc.plan_layers.is_empty())
	assert_eq(doc.floor_plan.notes[0].layer, "", "on none once its layer is gone")
