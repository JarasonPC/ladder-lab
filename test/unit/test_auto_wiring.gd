extends GutTest
## Wiring helpers: facing terminals wired straight, the poles beside a wire.


## Three phases, a breaker, main contacts, an overload relay and a motor
## one under another (as in the time relay example), no wires; KM2 stands
## to the right, out of line.
func _power_column() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(5, 0))
	doc.add(PowerSupply.new("L2", PowerSupply.Conductor.L2), Vector2i(7, 0))
	doc.add(PowerSupply.new("L3", PowerSupply.Conductor.L3), Vector2i(9, 0))
	doc.add(MotorBreaker.new("FA1"), Vector2i(5, 2))
	doc.add(MainContacts.new("KM1"), Vector2i(5, 10))
	doc.add(OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(5, 15))
	doc.add(ThreePhaseMotor.new("M1"), Vector2i(5, 20))
	return doc


func _all_ids(doc: SchematicDocument) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for c: CircuitComponent in doc.circuit.get_components():
		ids.append(c.id)
	return ids


## Pairs as sorted "a|b" texts, sorted, to compare regardless of order.
static func _sorted(pairs: Array[PackedStringArray]) -> Array[String]:
	var result: Array[String] = []
	for pair: PackedStringArray in pairs:
		var ends: Array = Array(pair)
		ends.sort()
		result.append("%s|%s" % ends)
	result.sort()
	return result


static func _column_wiring() -> Array[PackedStringArray]:
	var pairs: Array[PackedStringArray] = []
	for i: int in 3:
		pairs.append(PackedStringArray(["L%d" % (i + 1), "FA1:%d" % (2 * i + 1)]))
		pairs.append(PackedStringArray(["FA1:%d" % (2 * i + 2), "KM1:%d" % (2 * i + 1)]))
		pairs.append(PackedStringArray(["KM1:%d" % (2 * i + 2), "F1:%d" % (2 * i + 1)]))
		pairs.append(PackedStringArray(["F1:%d" % (2 * i + 2), "M1:%s" % ["U1", "V1", "W1"][i]]))
	return pairs


func test_facing_terminals_of_a_column_are_paired() -> void:
	var doc: SchematicDocument = _power_column()
	var pairs: Array[PackedStringArray] = doc.facing_pairs(_all_ids(doc))
	assert_eq(_sorted(pairs), _sorted(_column_wiring()), "every pole straight down, supplies met from below, PE left alone")
	assert_eq(doc.connect_pairs(pairs), 12)
	for w: int in doc.get_wire_count():
		assert_eq(doc.wire_points(w).size(), 2, "wire %d is straight" % w)
	assert_eq(doc.facing_pairs(_all_ids(doc)), [] as Array[PackedStringArray], "wired terminals are not paired again")


func test_facing_pairs_only_touch_the_given_parts() -> void:
	var doc: SchematicDocument = _power_column()
	var pairs: Array[PackedStringArray] = doc.facing_pairs(PackedStringArray(["KM1"]), _all_ids(doc))
	assert_eq(pairs.size(), 6, "three wires above KM1, three below")
	for pair: PackedStringArray in pairs:
		assert_true(pair[0].begins_with("KM1:") or pair[1].begins_with("KM1:"), "%s" % pair)
	assert_eq(doc.facing_pairs(PackedStringArray(["FA1", "F1"])), [] as Array[PackedStringArray], "KM1 stands between them")


func test_facing_pairs_skip_wired_terminals_and_what_is_in_the_way() -> void:
	var doc: SchematicDocument = _power_column()
	doc.connect_terminals("L1", "FA1:1")
	# A wire of another net along the middle column between FA1 and KM1.
	doc.add(Lamp.new("H1"), Vector2i(12, 4))
	doc.connect_terminals("H1:X1", "H1:X2", [Vector2i(7, 4), Vector2i(7, 9)] as Array[Vector2i])
	var pairs: Array[String] = _sorted(doc.facing_pairs(PackedStringArray(["L1", "L2", "FA1", "KM1"])))
	assert_false(pairs.has("FA1:1|L1"), "already wired")
	assert_true(pairs.has("FA1:3|L2"))
	assert_true(pairs.has("FA1:2|KM1:1"))
	assert_false(pairs.has("FA1:4|KM1:3"), "a wire runs along the way")
	assert_true(pairs.has("FA1:6|KM1:5"))


func test_parallel_pairs_follow_the_wire_drawn() -> void:
	var doc: SchematicDocument = _power_column()
	doc.add(MainContacts.new("KM2"), Vector2i(13, 10))
	assert_eq(_sorted(doc.parallel_pairs("FA1:2", "KM2:1")), ["FA1:4|KM2:3", "FA1:6|KM2:5"])
	assert_eq(_sorted(doc.parallel_pairs("KM2:3", "FA1:4")), ["FA1:2|KM2:1", "FA1:6|KM2:5"], "from a middle pole both ways")
	assert_eq(_sorted(doc.parallel_pairs("L2", "FA1:3")), ["FA1:1|L1", "FA1:5|L3"], "supply points in a row count as poles")
	assert_eq(_sorted(doc.parallel_pairs("F1:6", "M1:W1")), ["F1:2|M1:U1", "F1:4|M1:V1"], "the motor's PE leaves another way")
	assert_eq(doc.parallel_pairs("FA1:2", "FA1:3"), [] as Array[PackedStringArray], "one part")
	doc.connect_terminals("FA1:4", "KM2:3")
	assert_eq(_sorted(doc.parallel_pairs("FA1:2", "KM2:1")), ["FA1:6|KM2:5"], "wired poles drop out of the row")
	doc.connect_terminals("FA1:2", "KM2:1")
	assert_eq(doc.connect_pairs(doc.parallel_pairs("FA1:2", "KM2:1")), 1)
	assert_eq(doc.get_wire_count(), doc.circuit.get_wires().size())
	for w: int in doc.get_wire_count():
		var points: Array[Vector2i] = doc.wire_points(w)
		for s: int in range(1, points.size()):
			var d: Vector2i = points[s] - points[s - 1]
			assert_true(d.x == 0 or d.y == 0, "wire %d segment %d is orthogonal" % [w, s])


# --- In the editor ----------------------------------------------------------------

func _editor(doc: SchematicDocument) -> SchematicEditor:
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	var editor: SchematicEditor = SchematicEditor.new()
	editor.view = view
	add_child_autofree(editor)
	editor.document_replaced.connect(func(replaced: SchematicDocument) -> void: view.load_document(replaced, false))
	view.load_document(doc, false)
	editor.active = true
	return editor


func _at(editor: SchematicEditor, cell: Vector2) -> void:
	editor._mouse_point = cell
	editor._mouse_cell = Vector2i(cell.round())


func _click(editor: SchematicEditor, cell: Vector2, shift: bool = false) -> void:
	_at(editor, cell)
	editor._on_left_pressed(shift)
	editor._on_left_released(shift)


func test_wire_facing_terminals_of_the_selection_in_one_step() -> void:
	var editor: SchematicEditor = _editor(_power_column())
	editor.select_all()
	assert_eq(editor.wire_facing_terminals(), 12)
	assert_eq(_sorted(editor.document().circuit.get_wires()), _sorted(_column_wiring()))
	editor.undo()
	assert_eq(editor.document().get_wire_count(), 0, "one undo step")


func test_right_click_menu_offers_wiring_facing_terminals() -> void:
	var editor: SchematicEditor = _editor(_power_column())
	editor.select_all()
	_at(editor, Vector2(6, 12))
	editor._open_context_menu()
	var menu: PopupMenu = editor._menu
	var index: int = menu.get_item_index(SchematicEditor.MenuId.WIRE_FACING)
	assert_true(index >= 0, "always in the menu with two or more parts selected")
	assert_string_contains(menu.get_item_text(index), "(12)")
	assert_false(menu.is_item_disabled(index))
	menu.hide()


func test_a_wire_between_poles_takes_the_others_along() -> void:
	var editor: SchematicEditor = _editor(_power_column())
	var doc: SchematicDocument = editor.document()
	editor.wire_all_poles = true
	_click(editor, Vector2(doc.terminal_cell("FA1:2")))
	_click(editor, Vector2(doc.terminal_cell("KM1:1")))
	assert_eq(_sorted(editor.document().circuit.get_wires()), ["FA1:2|KM1:1", "FA1:4|KM1:3", "FA1:6|KM1:5"])
	doc = editor.document()
	_click(editor, Vector2(doc.terminal_cell("KM1:2")))
	_click(editor, Vector2(doc.terminal_cell("F1:1")), true)
	assert_eq(editor.document().get_wire_count(), 4, "Shift: that wire alone")
	editor.wire_all_poles = false
	_click(editor, Vector2(doc.terminal_cell("KM1:4")))
	_click(editor, Vector2(doc.terminal_cell("F1:3")))
	assert_eq(editor.document().get_wire_count(), 5, "turned off: one wire")


func test_parts_placed_or_dropped_in_line_are_wired() -> void:
	var doc: SchematicDocument = _power_column()
	doc.remove_component("KM1")
	var editor: SchematicEditor = _editor(doc)
	editor.wire_on_drop = true
	editor.begin_place({"type": "main_contacts"})
	_at(editor, Vector2(5, 10))
	editor._update_ghost_wires()
	assert_eq(editor._ghost_wires.size(), 6, "shown before the click")
	assert_null(editor.document().circuit.get_component("KM1"), "only shown")
	editor._on_left_pressed(false)
	editor._cancel_tool()
	assert_eq(editor.document().get_wire_count(), 6, "three wires above, three below")
	editor.undo()
	assert_eq(editor.document().get_wire_count(), 0, "placed and wired in one step")
	# Dragged into line from the side.
	editor.begin_place({"type": "main_contacts"})
	_at(editor, Vector2(20, 10))
	editor._on_left_pressed(false)
	editor._cancel_tool()
	assert_eq(editor.document().get_wire_count(), 0, "out of line")
	var body: Vector2 = editor.document().component_body(editor.document().circuit.get_component("KM1")).get_center()
	_at(editor, body)
	editor._on_left_pressed(false)
	_at(editor, body - Vector2(15, 0))
	editor._on_mouse_moved()
	assert_eq(editor._drop_pairs.size(), 6, "shown while dragging")
	editor._on_left_released(false)
	assert_eq(editor.document().get_wire_count(), 6)
	editor.undo()
	assert_eq(editor.document().get_wire_count(), 0, "dropped and wired in one step")
	assert_eq(editor.document().get_placement("KM1").cell, Vector2i(20, 10))


func test_facing_terminals_wired_elsewhere_pair_when_asked() -> void:
	var doc: SchematicDocument = _power_column()
	# FA1:2 wired to a lamp beside: down the column first, then across.
	doc.add(Lamp.new("H1"), Vector2i(12, 4))
	var below: Vector2i = doc.terminal_cell("FA1:2") + Vector2i(0, 1)
	doc.connect_terminals("FA1:2", "H1:X1", [below, Vector2i(12, below.y)] as Array[Vector2i])
	assert_false(_sorted(doc.facing_pairs(PackedStringArray(["FA1", "KM1"]))).has("FA1:2|KM1:1"), "only free terminals")
	var pairs: Array[PackedStringArray] = doc.facing_pairs(PackedStringArray(["FA1", "KM1"]), PackedStringArray(), true)
	assert_eq(_sorted(pairs), ["FA1:2|KM1:1", "FA1:4|KM1:3", "FA1:6|KM1:5"], "along the wire of its own net")
	doc.connect_pairs(pairs)
	assert_eq(doc.facing_pairs(PackedStringArray(["FA1", "KM1"]), PackedStringArray(), true), [] as Array[PackedStringArray], "joined already")


func test_wire_facing_terminals_takes_wired_ones_too() -> void:
	var doc: SchematicDocument = _power_column()
	doc.connect_terminals("KM1:2", "F1:1")
	var editor: SchematicEditor = _editor(doc)
	editor.select_all()
	assert_eq(editor.wire_facing_terminals(), 11, "every pole but the one wired")
	assert_true(_sorted(editor.document().circuit.get_wires()).has("F1:2|M1:U1"))
	assert_true(_sorted(editor.document().circuit.get_wires()).has("FA1:2|KM1:1"), "KM1 has a wired terminal")
