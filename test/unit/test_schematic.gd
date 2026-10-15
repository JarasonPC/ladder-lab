extends GutTest


func test_rotated_terminals() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Lamp.new("H1"), Vector2i(10, 10), 1)
	doc.add(Lamp.new("H2"), Vector2i(10, 10), 2)
	assert_eq(doc.terminal_cell("H1:X1"), Vector2i(10, 10))
	assert_eq(doc.terminal_cell("H1:X2"), Vector2i(7, 10), "quarter turn clockwise points left")
	assert_eq(doc.terminal_cell("H2:X2"), Vector2i(10, 7))


func test_mirrored_terminals_and_lead() -> void:
	var p: Placement = Placement.new(Vector2i.ZERO, 3, true)
	assert_eq(SymbolGeometry.transform_cell(Vector2i(0, 3), p), Vector2i(3, 0), "runs left to right")
	assert_eq(SymbolGeometry.transform_cell(Vector2i(-1, 1), p), Vector2i(1, -1), "left side ends up on top")
	assert_eq(SymbolGeometry.transform_direction(SymbolGeometry.DIR_DOWN, p), SymbolGeometry.DIR_RIGHT)
	var t: Transform2D = SymbolGeometry.draw_transform(p)
	assert_almost_eq(t * Vector2(-20, 20), Vector2(20, -20), Vector2(0.001, 0.001), "draw transform matches grid transform")


func test_transpose_makes_horizontal_paths() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(0, true)
	assert_true(doc.horizontal)
	assert_eq(doc.terminal_cell("S1:13"), Vector2i(12, 5))
	assert_eq(doc.terminal_cell("S1:14"), Vector2i(15, 5))
	var cells: Array[Vector2i] = doc.junction_cells()
	cells.sort()
	assert_eq(cells, [Vector2i(6, 5), Vector2i(11, 5), Vector2i(16, 5), Vector2i(22, 5)] as Array[Vector2i])
	doc.transpose()
	assert_false(doc.horizontal)
	assert_eq(doc.terminal_cell("S1:14"), Vector2i(5, 15))


func test_rotated_body_hit() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Lamp.new("H1"), Vector2i(10, 10), 1)
	assert_eq(doc.component_at(Vector2(8.5, 10.0)).id, "H1")
	assert_null(doc.component_at(Vector2(10.0, 11.5)))


func test_component_at() -> void:
	var doc: SchematicDocument = ExampleCircuits.self_holding()
	assert_eq(doc.component_at(Vector2(5.0, 13.5)).id, "S1:13-14")
	assert_eq(doc.component_at(Vector2(8.0, 13.5)).id, "KM1:13-14")
	assert_eq(doc.component_at(Vector2(5.0, 18.5)).id, "KM1")
	assert_null(doc.component_at(Vector2(0.0, 0.0)))


func test_junction_dots() -> void:
	var doc: SchematicDocument = ExampleCircuits.self_holding()
	var cells: Array[Vector2i] = doc.junction_cells()
	cells.sort()
	assert_eq(cells, [Vector2i(5, 6), Vector2i(5, 11), Vector2i(5, 16), Vector2i(5, 22)] as Array[Vector2i])


func test_examples_are_consistent() -> void:
	for index: int in ExampleCircuits.count() * 2:
		var doc: SchematicDocument = ExampleCircuits.build(index / 2, index % 2 == 1)
		assert_not_null(doc, "example %d builds" % index)
		assert_eq(doc.get_wire_count(), doc.circuit.get_wires().size())
		for c: CircuitComponent in doc.circuit.get_components():
			assert_not_null(doc.get_placement(c.id), "%s is placed" % c.id)
		for w: int in doc.get_wire_count():
			var points: Array[Vector2i] = doc.wire_points(w)
			for s: int in range(1, points.size()):
				var d: Vector2i = points[s] - points[s - 1]
				assert_true(d.x == 0 or d.y == 0, "%s wire %d segment %d is orthogonal" % [doc.title, w, s])
		var r: StepResult = Simulator.new(doc.circuit).step()
		assert_true(r.stable, "%s settles at rest" % doc.title)


func test_wires_do_not_cross_symbol_bodies() -> void:
	# A wire running through a symbol would look like a connection that is not there.
	var crossings: PackedStringArray = PackedStringArray()
	for index: int in ExampleCircuits.count() * 2:
		var doc: SchematicDocument = ExampleCircuits.build(index / 2, index % 2 == 1)
		for w: int in doc.get_wire_count():
			var points: Array[Vector2i] = doc.wire_points(w)
			for s: int in range(1, points.size()):
				var a: Vector2 = Vector2(points[s - 1])
				var b: Vector2 = Vector2(points[s])
				for k: int in range(1, 20):
					var p: Vector2 = a.lerp(b, k / 20.0)
					var hit: CircuitComponent = doc.component_at(p)
					if hit != null and not (hit is PowerSupply):
						var body: Rect2 = doc.component_body(hit)
						# Leads run along the symbol axis; only the middle of the body counts.
						var core: Rect2 = body.grow(-0.45)
						if core.has_point(p):
							crossings.append("%s wire %d crosses %s" % [doc.title, w, hit.id])
	assert_eq(crossings, PackedStringArray())


func test_mixed_horizontal_and_vertical_symbols() -> void:
	# S1 lies horizontally (turned and mirrored), KM1 stands vertically.
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, 6))
	var s1: PushButton = doc.add(PushButton.new("S1", SwitchingElement.ContactType.NO), Vector2i(4, 1), 3, true) as PushButton
	var k1: Coil = doc.add(Coil.new("KM1"), Vector2i(9, 1)) as Coil
	assert_eq(doc.terminal_cell("S1:14"), Vector2i(7, 1))
	assert_true(doc.connect_terminals("L", "S1:13"))
	assert_true(doc.connect_terminals("S1:14", "KM1:A1"))
	assert_true(doc.connect_terminals("KM1:A2", "N", [Vector2i(9, 6)] as Array[Vector2i]))
	var sim: Simulator = Simulator.new(doc.circuit)
	s1.press()
	var r: StepResult = sim.step()
	assert_true(k1.energized)
	assert_eq(r.current_wires, PackedInt32Array([0, 1, 2]))
	assert_eq(doc.junction_cells(), [] as Array[Vector2i])


func test_crossing_wires_get_no_dot() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	for name: String in ["H1", "H2", "H3", "H4"]:
		doc.add(Lamp.new(name), Vector2i(0, 0) if name == "H1" else (Vector2i(10, 0) if name == "H2" else (Vector2i(4, -6) if name == "H3" else Vector2i(4, 6))))
	# H1:X2 (0,3) -> H2:X1 (10,0) along y = 3; H3:X2 (4,-3) -> H4:X1 (4,6) along x = 4.
	doc.connect_terminals("H1:X2", "H2:X1", [Vector2i(10, 3)] as Array[Vector2i])
	doc.connect_terminals("H3:X2", "H4:X1")
	assert_does_not_have(doc.junction_cells(), Vector2i(4, 3), "a crossing is not a junction")
