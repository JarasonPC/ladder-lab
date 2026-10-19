extends GutTest
## Editing operations on SchematicDocument and Circuit.

const ExamplePower = preload("res://test/unit/example_power.gd")

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC


func _assert_routes_valid(doc: SchematicDocument) -> void:
	assert_eq(doc.get_wire_count(), doc.circuit.get_wires().size(), "routes stay parallel to wires")
	for w: int in doc.get_wire_count():
		var points: Array[Vector2i] = doc.wire_points(w)
		for s: int in range(1, points.size()):
			var d: Vector2i = points[s] - points[s - 1]
			assert_true(d.x == 0 or d.y == 0, "wire %d segment %d is orthogonal" % [w, s])


func _lamp_doc() -> SchematicDocument:
	# L - S1 - H1 - N
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, 12))
	doc.add(LatchingSwitch.new("S1", NO), Vector2i(5, 2))
	doc.add(Lamp.new("H1"), Vector2i(5, 7))
	doc.connect_terminals("L", "S1:13", [Vector2i(5, 1)] as Array[Vector2i])
	doc.connect_terminals("S1:14", "H1:X1")
	doc.connect_terminals("H1:X2", "N", [Vector2i(5, 12)] as Array[Vector2i])
	return doc


func test_remove_component_removes_its_wires() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_holding())
	var wires_before: int = doc.get_wire_count()
	doc.remove_component("SB1")
	assert_null(doc.circuit.get_component("SB1"))
	assert_null(doc.get_placement("SB1"))
	assert_eq(doc.get_wire_count(), wires_before - 3)
	_assert_routes_valid(doc)


func test_replace_no_with_nc_keeps_wiring() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_holding())
	assert_true(doc.replace_component("KM1:23-24", Contact.new("KM1", NC, 2)))
	assert_true(doc.circuit.has_terminal("KM1:21"))
	assert_false(doc.circuit.has_terminal("KM1:23"))
	var r: StepResult = Simulator.new(doc.circuit).step()
	assert_true(r.stable)
	assert_true((doc.circuit.get_component("H1") as Lamp).energized, "NC contact now lights H1 at rest")
	_assert_routes_valid(doc)


func test_renaming_coil_relinks_contacts() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_holding())
	assert_true(doc.replace_component("KM1", Coil.new("K5")))
	assert_null((doc.circuit.get_component("KM1:13-14") as Contact).linked_coil)
	assert_true(doc.replace_component("KM1:13-14", Contact.new("K5", NO, 1)))
	assert_eq((doc.circuit.get_component("K5:13-14") as Contact).linked_coil, doc.circuit.get_coil("K5"))


func test_replace_rejects_taken_designation() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_holding())
	assert_false(doc.replace_component("SB1", PushButton.new("SB0", NC)))
	assert_push_error("duplicate component id")
	assert_not_null(doc.circuit.get_component("SB1"))


func test_move_reroutes_attached_wires() -> void:
	var doc: SchematicDocument = _lamp_doc()
	doc.move_components(PackedStringArray(["H1"]), Vector2i(4, 1))
	assert_eq(doc.terminal_cell("H1:X1"), Vector2i(9, 8))
	_assert_routes_valid(doc)
	# The wire still leaves S1 downward, along the symbol axis.
	var points: Array[Vector2i] = doc.wire_points(1)
	assert_eq(points[1].x, 5)


func test_drag_back_restores_routes() -> void:
	var doc: SchematicDocument = _lamp_doc()
	var before: Array = []
	for w: int in doc.get_wire_count():
		before.append(doc.wire_points(w))
	var start: Dictionary = doc.drag_start(PackedStringArray(["S1"]))
	# The mouse wanders right, down and back again.
	for delta: Vector2i in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 1), Vector2i(0, 1)]:
		doc.drag_components(start, delta)
		assert_eq(doc.terminal_cell("S1:13"), Vector2i(5, 2) + delta)
		_assert_routes_valid(doc)
		for w: int in doc.get_wire_count():
			assert_true(SchematicDocument._route_simple(doc.wire_points(w)), "wire %d does not run over itself at %s" % [w, delta])
	doc.drag_components(start, Vector2i.ZERO)
	for w: int in doc.get_wire_count():
		assert_eq(doc.wire_points(w), before[w], "wire %d is back as it was" % w)


func test_moved_wire_does_not_loop() -> void:
	# Step by step, the routes left behind used to grow hooks and loops.
	var doc: SchematicDocument = _lamp_doc()
	for step: Vector2i in [Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		doc.move_components(PackedStringArray(["S1"]), step)
		for w: int in doc.get_wire_count():
			assert_true(SchematicDocument._route_simple(doc.wire_points(w)), "wire %d does not run over itself" % w)
	assert_eq(doc.wire_points(1), [Vector2i(5, 5), Vector2i(5, 7)] as Array[Vector2i], "straight again")


func test_moved_wire_avoids_other_terminals() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Lamp.new("H1"), Vector2i(0, 0))
	doc.add(Lamp.new("H2"), Vector2i(6, 6))
	doc.add(Lamp.new("H3"), Vector2i(3, 5))
	doc.connect_terminals("H1:X2", "H2:X1")
	doc.normalize_route(0)
	var points: Array[Vector2i] = doc.wire_points(0)
	for s: int in range(1, points.size()):
		assert_false(SchematicDocument._on_segment(Vector2i(3, 5), points[s - 1], points[s]), "the wire keeps off H3:X1")
	_assert_routes_valid(doc)


func test_moving_both_ends_moves_corners() -> void:
	var doc: SchematicDocument = _lamp_doc()
	doc.move_components(PackedStringArray(["L", "S1"]), Vector2i(0, -1))
	assert_eq(doc.get_route(0).corners, [Vector2i(5, 0)] as Array[Vector2i])
	_assert_routes_valid(doc)


func test_rotate_and_mirror_keep_wires_orthogonal() -> void:
	var doc: SchematicDocument = _lamp_doc()
	doc.rotate_component("H1")
	_assert_routes_valid(doc)
	assert_eq(doc.terminal_cell("H1:X2"), Vector2i(2, 7))
	var before: Vector2i = doc.terminal_cell("S1:14")
	doc.mirror_component("S1")
	assert_eq(doc.terminal_cell("S1:14"), before, "mirroring keeps the terminals in place")
	assert_true(doc.get_placement("S1").mirrored)


func test_split_wire_inserts_junction() -> void:
	var doc: SchematicDocument = _lamp_doc()
	var sim: Simulator = Simulator.new(doc.circuit)
	var key: String = doc.split_wire(0, Vector2i(4, 1))
	assert_eq(key, "J1")
	assert_eq(doc.get_wire_count(), 4)
	_assert_routes_valid(doc)
	assert_eq(sim.get_net_of("L"), sim.get_net_of("S1:13"), "split keeps L connected to S1")
	# Branch a second lamp off the new junction.
	doc.add(Lamp.new("H2"), Vector2i(8, 3))
	doc.connect_terminals("J1", "H2:X1", [Vector2i(4, 0), Vector2i(8, 0)] as Array[Vector2i])
	doc.connect_terminals("H2:X2", "N", [Vector2i(8, 12)] as Array[Vector2i])
	sim.step()
	assert_true((doc.circuit.get_component("H2") as Lamp).energized)
	var junctions: Array[Vector2i] = doc.junction_cells()
	junctions.sort()
	assert_eq(junctions, [Vector2i(4, 1), Vector2i(5, 12)] as Array[Vector2i])


func test_split_at_wire_end_returns_terminal() -> void:
	var doc: SchematicDocument = _lamp_doc()
	assert_eq(doc.split_wire(0, Vector2i(2, 1)), "L")
	assert_eq(doc.split_wire(0, Vector2i(9, 9)), "")


func test_cleanup_merges_junction_with_two_wires() -> void:
	var doc: SchematicDocument = _lamp_doc()
	doc.split_wire(0, Vector2i(4, 1))
	doc.add(Lamp.new("H2"), Vector2i(8, 3))
	doc.connect_terminals("J1", "H2:X1", [Vector2i(4, 0), Vector2i(8, 0)] as Array[Vector2i])
	doc.remove_component("H2")
	doc.cleanup_junctions()
	assert_null(doc.circuit.get_component("J1"))
	assert_eq(doc.get_wire_count(), 3)
	assert_eq(doc.wire_points(2), [Vector2i(2, 1), Vector2i(5, 1), Vector2i(5, 2)] as Array[Vector2i])
	var sim: Simulator = Simulator.new(doc.circuit)
	(doc.circuit.get_component("S1") as LatchingSwitch).set_switched_on(true)
	sim.step()
	assert_true((doc.circuit.get_component("H1") as Lamp).energized)


func test_orthogonalize() -> void:
	var points: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 4)]
	assert_eq(SchematicDocument.orthogonalize(points, SchematicDocument.AXIS_VERTICAL),
		[Vector2i(0, 0), Vector2i(0, 4), Vector2i(3, 4)] as Array[Vector2i])
	assert_eq(SchematicDocument.orthogonalize(points),
		[Vector2i(0, 0), Vector2i(3, 0), Vector2i(3, 4)] as Array[Vector2i])
	var collinear: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 2), Vector2i(0, 2), Vector2i(0, 5)]
	assert_eq(SchematicDocument.orthogonalize(collinear), [Vector2i(0, 0), Vector2i(0, 5)] as Array[Vector2i])


func test_hit_queries() -> void:
	var doc: SchematicDocument = _lamp_doc()
	assert_eq(doc.terminal_at(Vector2(5.1, 4.9)), "S1:14")
	assert_eq(doc.terminal_at(Vector2(6.0, 6.0)), "")
	assert_eq(doc.wire_at(Vector2(3.5, 1.1)), 0)
	assert_eq(doc.wire_cell_near(0, Vector2(3.4, 1.2)), Vector2i(3, 1))
	assert_eq(doc.wire_at(Vector2(8.0, 8.0)), -1)


func test_designation_helpers() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_holding())
	assert_eq(doc.next_designation("SB"), "SB2")
	assert_eq(doc.next_designation("KM"), "KM2")
	assert_eq(doc.next_designation("KT"), "KT1")
	assert_eq(doc.next_contact_sequence("KM1"), 3)
	assert_eq(doc.next_supply_designation(PowerSupply.Conductor.L), "L1.3")


func test_serializer_round_trip() -> void:
	for index: int in ExampleCircuits.count() * 2:
		var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.build(index / 2, index % 2 == 1))
		var data: Dictionary = DocumentSerializer.to_dict(doc)
		var copy: SchematicDocument = DocumentSerializer.from_dict(data)
		assert_eq(DocumentSerializer.to_dict(copy), data, "%s survives a round trip" % doc.title)
	var original: SchematicDocument = ExamplePower.on(ExampleCircuits.self_holding())
	# Breakers are not saved switched on: a restored copy starts with them off.
	var restored: SchematicDocument = ExamplePower.on(DocumentSerializer.from_dict(DocumentSerializer.to_dict(original)))
	var sim: Simulator = Simulator.new(restored.circuit)
	(restored.circuit.get_component("SB1") as PushButton).press()
	sim.step()
	(restored.circuit.get_component("SB1") as PushButton).release()
	sim.step()
	assert_true((restored.circuit.get_component("KM1") as Coil).energized, "restored copy still self-holds")


func test_undo_history() -> void:
	var history: UndoHistory = UndoHistory.new()
	assert_false(history.can_undo())
	history.record({"v": 1})
	history.record({"v": 2})
	assert_eq(history.undo({"v": 3}), {"v": 2})
	assert_true(history.can_redo())
	assert_eq(history.redo({"v": 2}), {"v": 3})
	history.undo({"v": 3})
	history.record({"v": 9})
	assert_false(history.can_redo(), "a new edit clears redo")


func test_rotated_symbol_wires_do_not_cross_own_terminals() -> void:
	for horizontal: bool in [false, true]:
		var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.build(1, horizontal))
		for turn: int in 4:
			doc.rotate_component("H1")
			_assert_routes_valid(doc)
			var u1: Vector2i = doc.terminal_cell("H1:X1")
			var u2: Vector2i = doc.terminal_cell("H1:X2")
			for w: int in doc.circuit.wires_of(doc.circuit.get_component("H1")):
				var wire: PackedStringArray = doc.circuit.get_wires()[w]
				var other: Vector2i = u1 if wire.has("H1:X2") else u2
				var points: Array[Vector2i] = doc.wire_points(w)
				for s: int in range(1, points.size()):
					assert_false(SchematicDocument._on_segment(other, points[s - 1], points[s]),
						"turn %d: wire %s runs over %s" % [turn, wire, other])


func test_drag_wire_segment_sideways() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Lamp.new("H1"), Vector2i(0, 0))
	doc.add(Lamp.new("H2"), Vector2i(6, 0))
	# H1:X2 (0,3) -> (0,5) -> (6,5) -> H2:X2 (6,3)
	doc.connect_terminals("H1:X2", "H2:X2", [Vector2i(0, 5), Vector2i(6, 5)] as Array[Vector2i])
	var points: Array[Vector2i] = doc.wire_points(0)
	assert_eq(doc.wire_segment_at(0, Vector2(3.0, 5.1)), 1, "the bottom segment")
	doc.drag_wire_segment(0, points, 1, Vector2i(2, 3))
	assert_eq(doc.get_route(0).corners, [Vector2i(0, 8), Vector2i(6, 8)] as Array[Vector2i], "moved down 3, sideways part ignored")
	doc.drag_wire_segment(0, points, 1, Vector2i(0, -2))
	assert_eq(doc.wire_points(0), [Vector2i(0, 3), Vector2i(6, 3)] as Array[Vector2i], "back in line with the terminals: corners merge")
	# A straight wire dragged sideways gets two new corners next to its ends.
	var straight: Array[Vector2i] = doc.wire_points(0)
	doc.drag_wire_segment(0, straight, 0, Vector2i(0, 2))
	assert_eq(doc.get_route(0).corners, [Vector2i(0, 5), Vector2i(6, 5)] as Array[Vector2i])


func test_terminal_block_on_a_wire() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_holding())
	var w: int = -1
	for i: int in doc.circuit.get_wires().size():
		if doc.circuit.get_wires()[i] == PackedStringArray(["KM1:A2", "N"]):
			w = i
	var block: TerminalBlock = TerminalBlock.new("X1")
	block.label = "10"
	var cell: Vector2i = doc.wire_points(w)[1]
	cell.y -= 1
	assert_eq(doc.split_wire(w, cell, block), "X1")
	assert_true(doc.circuit.has_component_id("X1"))
	var sim: Simulator = Simulator.new(doc.circuit)
	(doc.circuit.get_component("SB1") as PushButton).press()
	sim.step()
	assert_true(doc.circuit.get_coil("KM1").energized, "the terminal passes the circuit on")
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq((copy.circuit.get_component("X1") as TerminalBlock).label, "10")


func _wire_of(doc: SchematicDocument, a: String, b: String) -> int:
	var wires: Array[PackedStringArray] = doc.circuit.get_wires()
	for i: int in wires.size():
		if wires[i] == PackedStringArray([a, b]):
			return i
	return -1


func test_wire_numbers_follow_the_net() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_holding())
	doc.number_wires()
	var hold: int = _wire_of(doc, "SB1:14", "KM1:14")
	var coil: int = _wire_of(doc, "SB1:14", "KM1:A1")
	assert_ne(doc.get_route(hold).number, "")
	assert_eq(doc.get_route(hold).number, doc.get_route(coil).number, "one net, one number")
	assert_ne(doc.get_route(_wire_of(doc, "SB0:12", "SB1:13")).number, doc.get_route(hold).number, "another net")
	assert_eq(doc.get_route(_wire_of(doc, "L1.2", "FA2:1")).number, "", "supply nets stay unnumbered")
	assert_eq(doc.get_route(_wire_of(doc, "KM1:A2", "N")).number, "")
	doc.set_wire_number(coil, "208")
	assert_eq(doc.get_route(hold).number, "208", "renaming one wire renames its net")
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(copy.get_route(hold).number, "208")
	# Splitting a wire keeps the number on both halves.
	doc.split_wire(coil, doc.wire_points(coil)[0] + Vector2i(0, 1))
	assert_eq(doc.get_route(doc.get_wire_count() - 1).number, "208")


func test_wire_number_places_and_offsets() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_holding())
	doc.number_wires()
	var ends: Array[Vector2i] = doc.wire_number_ends()
	var seen: Dictionary[String, bool] = {}
	for e: Vector2i in ends:
		var key: String = doc.circuit.get_wires()[e.x][e.y]
		assert_false(seen.has(key), "one number per terminal: " + key)
		seen[key] = true
		assert_false(doc.circuit.get_terminal_owner(key) is Junction, "no numbers at junctions")
	var w: int = ends[0].x
	var end: int = ends[0].y
	var before: Vector2 = doc.wire_number_point(w, end)
	doc.set_wire_number_offset(w, end, Vector2(1.5, -0.5))
	assert_eq(doc.wire_number_point(w, end), before + Vector2(1.5, -0.5), "a dragged number moves")
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(copy.get_route(w).number_offsets[end], Vector2(1.5, -0.5), "the offset is saved")


func test_short_wire_shows_its_number_once() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Fuse.new("F1"), Vector2i(2, 2))
	doc.add(PushButton.new("S1", SwitchingElement.ContactType.NC), Vector2i(2, 6))
	doc.connect_terminals("F1:2", "S1:11")
	doc.set_wire_number(0, "1")
	assert_eq(doc.wire_number_ends().size(), 1, "a one-cell wire is numbered once")
	assert_eq(doc.wire_number_point(0, doc.wire_number_ends()[0].y), Vector2(2, 5.4), "next to the upper terminal")


func test_wire_number_sits_next_to_the_terminal() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Fuse.new("F1"), Vector2i(2, 2))
	doc.add(PushButton.new("S1", SwitchingElement.ContactType.NC), Vector2i(2, 10))
	doc.connect_terminals("S1:11", "F1:2")
	doc.set_wire_number(0, "1")
	var ends: Array[Vector2i] = doc.wire_number_ends()
	assert_eq(ends.size(), 2)
	var points: Array[Vector2] = []
	for e: Vector2i in ends:
		points.append(doc.wire_number_point(e.x, e.y))
	assert_true(points.has(Vector2(2, 5.4)), "below F1:2 at (2, 5)")
	assert_true(points.has(Vector2(2, 9.6)), "above S1:11 at (2, 10)")
	assert_eq(doc.wire_number_direction(0, 0), Vector2i.UP, "from S1:11 up")
	assert_true(doc.wire_number_vertical(0, 1))


func test_flip_swaps_the_ends_in_place() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Contact.new("KM1", SwitchingElement.ContactType.NO, 1), Vector2i(4, 2))
	doc.flip_component("KM1:13-14")
	assert_eq(doc.terminal_cell("KM1:13"), Vector2i(4, 5), "13 goes down")
	assert_eq(doc.terminal_cell("KM1:14"), Vector2i(4, 2), "14 comes up")
	doc.flip_component("KM1:13-14")
	assert_eq(doc.terminal_cell("KM1:13"), Vector2i(4, 2), "flipped twice: as before")
	var p: Placement = doc.get_placement("KM1:13-14")
	assert_eq([p.rotation, p.mirrored], [0, false])
	# Turned into a horizontal path, mirroring left-right swaps the ends and
	# mirroring top-bottom keeps them (as seen on the drawing).
	doc.rotate_component("KM1:13-14")
	var a: Vector2i = doc.terminal_cell("KM1:13")
	var b: Vector2i = doc.terminal_cell("KM1:14")
	doc.mirror_component("KM1:13-14")
	assert_eq([doc.terminal_cell("KM1:13"), doc.terminal_cell("KM1:14")], [b, a])
	doc.flip_component("KM1:13-14")
	assert_eq([doc.terminal_cell("KM1:13"), doc.terminal_cell("KM1:14")], [b, a], "top-bottom keeps the ends")


## Wires that would look connected to something they are not: through a
## symbol, over a terminal of another net, along a wire of another net.
func _misleading_wires(doc: SchematicDocument) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var nets: Dictionary[String, int] = doc._terminal_nets()
	var wires: Array[PackedStringArray] = doc.circuit.get_wires()
	var edges: Dictionary[Vector4i, int] = {}
	for w: int in doc.get_wire_count():
		var net: int = nets[wires[w][0]]
		var points: Array[Vector2i] = doc.wire_points(w)
		for s: int in range(1, points.size()):
			var unit: Vector2i = (points[s] - points[s - 1]).sign()
			var cell: Vector2i = points[s - 1]
			while cell != points[s]:
				var edge: Vector4i = Vector4i(mini(cell.x, cell.x + unit.x), mini(cell.y, cell.y + unit.y), maxi(cell.x, cell.x + unit.x), maxi(cell.y, cell.y + unit.y))
				if edges.get(edge, net) != net:
					found.append("wire %d runs along another net at %s" % [w, edge])
				edges[edge] = net
				cell += unit
			for c: CircuitComponent in doc.components_on_page(doc.wire_page(w)):
				var body: Rect2 = doc._obstacle(c)
				if body.has_area() and SchematicDocument._crosses(points[s - 1], points[s], body):
					found.append("wire %d crosses %s" % [w, c.id])
				for key: String in c.get_terminal_keys():
					if nets.get(key, -1) != net and SchematicDocument._on_segment(doc.terminal_cell(key), points[s - 1], points[s]):
						found.append("wire %d runs over %s" % [w, key])
	return found


func test_moved_wire_keeps_off_other_symbols() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Lamp.new("H1"), Vector2i(0, 0))
	doc.add(Lamp.new("H2"), Vector2i(0, 9))
	# H3 lies across the straight way from H1:X2 (0, 3) down to H2:X1 (0, 9).
	doc.add(Lamp.new("H3"), Vector2i(2, 6), 1)
	doc.connect_terminals("H1:X2", "H2:X1")
	doc.normalize_route(0)
	_assert_routes_valid(doc)
	assert_eq(_misleading_wires(doc), PackedStringArray())
	assert_true(SchematicDocument._route_simple(doc.wire_points(0)))


func test_moved_wire_keeps_off_wires_of_other_nets() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	for x: int in [0, 2, 4, 6]:
		doc.add(Lamp.new("H%d" % x), Vector2i(x, 0))
	doc.connect_terminals("H0:X2", "H6:X2", [Vector2i(0, 5), Vector2i(6, 5)] as Array[Vector2i])
	# Drawn along the first wire for a stretch: re-routed beside it.
	doc.connect_terminals("H2:X2", "H4:X2", [Vector2i(2, 5), Vector2i(4, 5)] as Array[Vector2i])
	assert_eq(_misleading_wires(doc).size(), 2)
	doc.normalize_route(1)
	_assert_routes_valid(doc)
	assert_eq(_misleading_wires(doc), PackedStringArray())
	assert_eq(doc.wire_points(0), [Vector2i(0, 3), Vector2i(0, 5), Vector2i(6, 5), Vector2i(6, 3)] as Array[Vector2i], "the other wire stays")


func test_part_dropped_on_a_wire_moves_the_wire_aside() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Lamp.new("H1"), Vector2i(0, 0))
	doc.add(Lamp.new("H2"), Vector2i(0, 10))
	doc.add(Lamp.new("H3"), Vector2i(6, 5))
	doc.connect_terminals("H1:X2", "H2:X1")
	var start: Dictionary = doc.drag_start(PackedStringArray(["H3"]))
	# H3 lands with its terminals on the wire, which is not its own.
	doc.drag_components(start, Vector2i(-6, 0))
	_assert_routes_valid(doc)
	assert_eq(_misleading_wires(doc), PackedStringArray())
	doc.drag_components(start, Vector2i.ZERO)
	assert_eq(doc.wire_points(0), [Vector2i(0, 3), Vector2i(0, 10)] as Array[Vector2i], "dragged away again: straight as before")


func test_hemmed_in_terminal_is_left_sideways() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Lamp.new("H1"), Vector2i(0, 0))
	doc.add(Lamp.new("H2"), Vector2i(0, 4))
	doc.add(Lamp.new("H3"), Vector2i(4, 9))
	# H2:X1 sits right below H1:X2, where its wire would leave.
	doc.connect_terminals("H1:X2", "H3:X1")
	doc.normalize_route(0)
	_assert_routes_valid(doc)
	assert_eq(_misleading_wires(doc), PackedStringArray())


func test_rerouted_wire_without_corners_takes_no_hook() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Lamp.new("H1"), Vector2i(0, 0))
	# Lying, its X1 at (6, 6) facing right.
	doc.add(Lamp.new("H2"), Vector2i(6, 6), 1)
	doc.connect_terminals("H1:X2", "H2:X1")
	doc.normalize_route(0)
	var points: Array[Vector2i] = doc.wire_points(0)
	assert_true(SchematicDocument._route_simple(points))
	# Down from H1:X2 (0, 3), across beyond H2:X1, down and back into it.
	assert_eq(points.size(), 5, "three corners: %s" % [points])
	var length: int = 0
	for s: int in range(1, points.size()):
		length += (points[s] - points[s - 1]).abs().x + (points[s] - points[s - 1]).abs().y
	assert_eq(length, 11, "no detour: %s" % [points])


func test_parts_turned_together_keep_their_places() -> void:
	var doc: SchematicDocument = _lamp_doc()
	var ids: PackedStringArray = PackedStringArray(["S1", "H1"])
	var cells: Array = []
	for w: int in doc.get_wire_count():
		cells.append(doc.wire_points(w))
	doc.rotate_components(ids)
	# The column S1 - H1 becomes a row: all four terminals on one line, the
	# wire between them straight.
	var row: int = doc.terminal_cell("S1:13").y
	for key: String in ["S1:14", "H1:X1", "H1:X2"]:
		assert_eq(doc.terminal_cell(key).y, row, key)
	assert_eq(doc.wire_points(1).size(), 2, "S1 - H1 still straight")
	assert_eq(doc.get_placement("S1").rotation, 1)
	assert_eq(doc.get_placement("H1").rotation, 1)
	_assert_routes_valid(doc)
	assert_eq(_misleading_wires(doc), PackedStringArray())
	for turn: int in 3:
		doc.rotate_components(ids)
	assert_eq(doc.get_placement("S1").cell, Vector2i(5, 2), "four turns: back in place")
	assert_eq(doc.get_placement("H1").cell, Vector2i(5, 7))
	assert_eq(doc.wire_points(1), cells[1])


func test_parts_turned_together_come_back_after_four_turns() -> void:
	# The middle of the terminals, (1, 1.5), is no point to turn about (a
	# turn would leave the cells): the parts turn about a terminal next to
	# it, the same one every time.
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Lamp.new("H1"), Vector2i(0, 0))
	doc.add(Lamp.new("H2"), Vector2i(2, 0))
	doc.connect_terminals("H1:X2", "H2:X2", [Vector2i(0, 5), Vector2i(2, 5)] as Array[Vector2i])
	var ids: PackedStringArray = PackedStringArray(["H1", "H2"])
	var before: Array[Vector2i] = doc.wire_points(0)
	for clockwise: bool in [true, false]:
		var seen: Array = []
		for turn: int in 4:
			doc.rotate_components(ids, clockwise)
			seen.append([doc.get_placement("H1").cell, doc.get_placement("H2").cell])
			_assert_routes_valid(doc)
		assert_eq(doc.get_placement("H1").cell, Vector2i(0, 0), "four turns: back in place (%s)" % [seen])
		assert_eq(doc.get_placement("H2").cell, Vector2i(2, 0))
		assert_eq(doc.get_placement("H1").rotation, 0)
		assert_eq(doc.wire_points(0), before)
	doc.rotate_components(ids)
	doc.rotate_components(ids, false)
	assert_eq([doc.get_placement("H1").cell, doc.get_placement("H2").cell], [Vector2i(0, 0), Vector2i(2, 0)], "a turn back undoes a turn")
	assert_eq(doc.wire_points(0), before)


func test_parts_mirrored_together_swap_places() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Lamp.new("H1"), Vector2i(0, 0))
	doc.add(Coil.new("KM1"), Vector2i(4, 0))
	doc.connect_terminals("H1:X2", "KM1:A2", [Vector2i(0, 5), Vector2i(4, 5)] as Array[Vector2i])
	var ids: PackedStringArray = PackedStringArray(["H1", "KM1"])
	doc.mirror_components(ids)
	assert_eq(doc.terminal_cell("H1:X1"), Vector2i(4, 0), "left to right")
	assert_eq(doc.terminal_cell("KM1:A1"), Vector2i(0, 0))
	assert_eq(doc.wire_points(0), [Vector2i(4, 3), Vector2i(4, 5), Vector2i(0, 5), Vector2i(0, 3)] as Array[Vector2i], "the wire between them is mirrored too")
	doc.flip_components(ids)
	assert_eq(doc.terminal_cell("H1:X1"), Vector2i(4, 3), "top to bottom")
	assert_eq(doc.terminal_cell("H1:X2"), Vector2i(4, 0))
	assert_eq(doc.wire_points(0), [Vector2i(4, 0), Vector2i(4, -2), Vector2i(0, -2), Vector2i(0, 0)] as Array[Vector2i])
	doc.flip_components(ids)
	doc.mirror_components(ids)
	assert_eq(doc.get_placement("H1").cell, Vector2i(0, 0), "mirrored twice: as before")
	assert_eq(doc.get_placement("KM1").cell, Vector2i(4, 0))
	assert_eq(doc.wire_points(0), [Vector2i(0, 3), Vector2i(0, 5), Vector2i(4, 5), Vector2i(4, 3)] as Array[Vector2i])


func test_line_up_in_a_row() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Lamp.new("H1"), Vector2i(0, 0))
	doc.add(Lamp.new("H2"), Vector2i(9, 1))
	doc.add(Coil.new("KM1"), Vector2i(4, 6))
	doc.add(Junction.new("J1"), Vector2i(12, 8))
	doc.connect_terminals("H1:X2", "H2:X2", [Vector2i(0, 5), Vector2i(9, 5)] as Array[Vector2i])
	doc.line_up(PackedStringArray(["H2", "KM1", "H1", "J1"]), false, 2)
	assert_eq(doc.get_placement("H1").cell, Vector2i(0, 0), "the first part stays")
	assert_eq(doc.get_placement("J1").cell, Vector2i(12, 8), "junctions stay with their wires")
	# Left to right as they stood: H1, KM1, H2; first terminals on one row,
	# two free cells between neighbours.
	var order: Array[String] = ["H1", "KM1", "H2"]
	for i: int in order.size():
		var c: CircuitComponent = doc.circuit.get_component(order[i])
		assert_eq(doc.terminal_cell(c.get_terminal_keys()[0]).y, 0, order[i])
		if i > 0:
			var before: Rect2i = doc.component_cells(doc.circuit.get_component(order[i - 1]))
			assert_eq(doc.component_cells(c).position.x - before.end.x, 2, "%s two cells on" % order[i])
	_assert_routes_valid(doc)


func test_line_up_in_a_column_moves_wires_along() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(Contact.new("K1", NO), Vector2i(3, 0))
	doc.add(Lamp.new("H1"), Vector2i(8, 9))
	doc.add(Lamp.new("H2"), Vector2i(10, 20))
	doc.connect_terminals("H1:X2", "H2:X1")
	var cells: Dictionary[String, Rect2i] = doc.line_up_cells(PackedStringArray(["H1", "H2", "K1:13-14"]), true, 3)
	doc.line_up(PackedStringArray(["H1", "H2", "K1:13-14"]), true, 3)
	for id: String in cells:
		assert_eq(doc.component_cells(doc.circuit.get_component(id)), cells[id], id)
	assert_eq(doc.terminal_cell("H1:X1").x, 3, "one column")
	assert_eq(doc.terminal_cell("H2:X1").x, 3)
	assert_eq(doc.component_cells(doc.circuit.get_component("H1")).position.y, doc.component_cells(doc.circuit.get_component("K1:13-14")).end.y + 3)
	assert_eq(doc.component_cells(doc.circuit.get_component("H2")).position.y, doc.component_cells(doc.circuit.get_component("H1")).end.y + 3)
	_assert_routes_valid(doc)
	assert_eq(doc.wire_points(0).back(), doc.terminal_cell("H2:X1"))


func test_examples_stay_clean_when_parts_move_and_turn() -> void:
	# Every part of an example nudged, and the control column of the first
	# one turned: no wire ends up looking connected where it is not, as long
	# as the parts themselves do not overlap.
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_holding())
	doc.rotate_components(PackedStringArray(["SB0", "SB1", "KM1:13-14", "KM1"]))
	_assert_routes_valid(doc)
	assert_eq(_misleading_wires(doc), PackedStringArray())
	for w: int in doc.get_wire_count():
		assert_true(SchematicDocument._route_simple(doc.wire_points(w)), "wire %d" % w)
	doc = ExamplePower.on(ExampleCircuits.self_holding())
	var start: Dictionary = doc.drag_start(PackedStringArray(["H1"]))
	for delta: Vector2i in [Vector2i(-1, 0), Vector2i(-2, 1), Vector2i(-3, 2), Vector2i(-6, 2)]:
		doc.drag_components(start, delta)
		_assert_routes_valid(doc)
		assert_eq(_misleading_wires(doc), PackedStringArray(), "H1 moved by %s" % delta)
