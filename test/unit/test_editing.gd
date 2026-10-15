extends GutTest
## Editing operations on SchematicDocument and Circuit.

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
	var doc: SchematicDocument = ExampleCircuits.self_holding()
	var wires_before: int = doc.get_wire_count()
	doc.remove_component("SB1")
	assert_null(doc.circuit.get_component("SB1"))
	assert_null(doc.get_placement("SB1"))
	assert_eq(doc.get_wire_count(), wires_before - 3)
	_assert_routes_valid(doc)


func test_replace_no_with_nc_keeps_wiring() -> void:
	var doc: SchematicDocument = ExampleCircuits.self_holding()
	assert_true(doc.replace_component("KM1:23-24", Contact.new("KM1", NC, 2)))
	assert_true(doc.circuit.has_terminal("KM1:21"))
	assert_false(doc.circuit.has_terminal("KM1:23"))
	var r: StepResult = Simulator.new(doc.circuit).step()
	assert_true(r.stable)
	assert_true((doc.circuit.get_component("H1") as Lamp).energized, "NC contact now lights H1 at rest")
	_assert_routes_valid(doc)


func test_renaming_coil_relinks_contacts() -> void:
	var doc: SchematicDocument = ExampleCircuits.self_holding()
	assert_true(doc.replace_component("KM1", Coil.new("K5")))
	assert_null((doc.circuit.get_component("KM1:13-14") as Contact).linked_coil)
	assert_true(doc.replace_component("KM1:13-14", Contact.new("K5", NO, 1)))
	assert_eq((doc.circuit.get_component("K5:13-14") as Contact).linked_coil, doc.circuit.get_coil("K5"))


func test_replace_rejects_taken_designation() -> void:
	var doc: SchematicDocument = ExampleCircuits.self_holding()
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
	var doc: SchematicDocument = ExampleCircuits.self_holding()
	assert_eq(doc.next_designation("SB"), "SB2")
	assert_eq(doc.next_designation("KM"), "KM2")
	assert_eq(doc.next_designation("KT"), "KT1")
	assert_eq(doc.next_contact_sequence("KM1"), 3)
	assert_eq(doc.next_supply_designation(PowerSupply.Conductor.L), "L.2")


func test_serializer_round_trip() -> void:
	for index: int in ExampleCircuits.count() * 2:
		var doc: SchematicDocument = ExampleCircuits.build(index / 2, index % 2 == 1)
		var data: Dictionary = DocumentSerializer.to_dict(doc)
		var copy: SchematicDocument = DocumentSerializer.from_dict(data)
		assert_eq(DocumentSerializer.to_dict(copy), data, "%s survives a round trip" % doc.title)
	var original: SchematicDocument = ExampleCircuits.self_holding()
	var restored: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(original))
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
		var doc: SchematicDocument = ExampleCircuits.build(1, horizontal)
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
	var doc: SchematicDocument = ExampleCircuits.self_holding()
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
	var doc: SchematicDocument = ExampleCircuits.self_holding()
	doc.number_wires()
	var hold: int = _wire_of(doc, "SB1:14", "KM1:14")
	var coil: int = _wire_of(doc, "SB1:14", "KM1:A1")
	assert_ne(doc.get_route(hold).number, "")
	assert_eq(doc.get_route(hold).number, doc.get_route(coil).number, "one net, one number")
	assert_ne(doc.get_route(_wire_of(doc, "SB0:12", "SB1:13")).number, doc.get_route(hold).number, "another net")
	assert_eq(doc.get_route(_wire_of(doc, "L", "FU1:1")).number, "", "supply nets stay unnumbered")
	assert_eq(doc.get_route(_wire_of(doc, "KM1:A2", "N")).number, "")
	doc.set_wire_number(coil, "208")
	assert_eq(doc.get_route(hold).number, "208", "renaming one wire renames its net")
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(copy.get_route(hold).number, "208")
	# Splitting a wire keeps the number on both halves.
	doc.split_wire(coil, doc.wire_points(coil)[0] + Vector2i(0, 1))
	assert_eq(doc.get_route(doc.get_wire_count() - 1).number, "208")


func test_wire_number_places_and_offsets() -> void:
	var doc: SchematicDocument = ExampleCircuits.self_holding()
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
	assert_eq(doc.wire_number_point(0, doc.wire_number_ends()[0].y), Vector2(2, 5.5), "in its middle")


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
