extends GutTest
## Symbols keep their texts off their lines, marks and one another in every
## orientation (four turns, mirrored or not).

const G: float = SymbolGeometry.GRID


## A symbol of [param data] turned [param rotation] times, mirrored or not,
## with terminal strips [param strips] (terminal index -> label), drawn.
func _symbol(data: Dictionary, rotation: int, mirrored: bool, strips: Dictionary = {}) -> SchematicSymbol:
	var c: CircuitComponent = DocumentSerializer.component_from_dict(data)
	var p: Placement = Placement.new(Vector2i(20, 20), rotation, mirrored)
	for k: int in strips:
		p.strips[k] = strips[k]
	var symbol: SchematicSymbol = SymbolFactory.create(c, p)
	symbol.live.resize(c.get_terminal_names().size())
	add_child_autofree(symbol)
	return symbol


## The eight orientations as [rotation, mirrored].
func _orientations() -> Array[Array]:
	var result: Array[Array] = []
	for mirrored: bool in [false, true]:
		for rotation: int in 4:
			result.append([rotation, mirrored])
	return result


## Box of the strip mark (circle and slash) of terminal [param index], node coordinates.
func _mark(symbol: SchematicSymbol, index: int) -> Rect2:
	var cell: Vector2i = SymbolGeometry.local_terminals(symbol.component)[symbol.component.get_terminal_names()[index]]
	return Rect2(symbol.to_upright(Vector2(cell) * G) - Vector2(7.5, 7.5), Vector2(15, 15))


## Text rects with the slack of the line height taken off: about where the
## glyphs are.
func _glyphs(r: Rect2) -> Rect2:
	return r.grow_individual(-1.0, -2.5, -1.0, -3.0)


func _assert_texts_apart(symbol: SchematicSymbol, what: String) -> void:
	var rects: Array[Rect2] = symbol.text_rects
	for i: int in rects.size():
		for j: int in range(i + 1, rects.size()):
			assert_false(_glyphs(rects[i]).intersects(_glyphs(rects[j])), "%s: %s and %s apart" % [what, rects[i], rects[j]])
		for k: int in symbol.placement.strips:
			assert_false(_glyphs(rects[i]).intersects(_mark(symbol, k)), "%s: %s off the strip mark of terminal %d" % [what, rects[i], k])


func test_turned_switching_symbols_pivot_on_the_left() -> void:
	var parts: Array = [
		[{"type": "contact", "contact": "NO", "designation": "KM1"}, ContactSymbol.PIVOT, ContactSymbol.FIXED_END],
		[{"type": "push_button", "contact": "NC", "designation": "SB1"}, ContactSymbol.PIVOT, ContactSymbol.FIXED_END],
		[{"type": "breaker", "designation": "FA1"}, BreakerSymbol.PIVOT, BreakerSymbol.FIXED_END],
		[{"type": "main_contacts", "designation": "KM1", "poles": 1}, MainContactsSymbol.PIVOT, MainContactsSymbol.FIXED_END],
		[{"type": "fuse", "designation": "FU1", "holder": true}, FuseSymbol.HOLDER_PIVOT, FuseSymbol.HOLDER_FIXED],
	]
	for part: Array in parts:
		for o: Array in _orientations():
			if o[0] % 2 == 1:
				var symbol: SchematicSymbol = _symbol(part[0], o[0], o[1])
				var t: Transform2D = symbol.shape_transform()
				assert_lt((t * part[1]).x, (t * part[2]).x, "%s turned %d times (mirrored %s): pivot left of the fixed contact" % [part[0]["type"], o[0], o[1]])


func test_strip_labels_keep_off_marks_names_and_ratings() -> void:
	var parts: Array = [
		[{"type": "push_button", "contact": "NO", "designation": "SB1"}, {0: "X2:3", 1: "X2:4"}],
		[{"type": "lamp", "designation": "H1", "rating": "230v"}, {0: "X2:7", 1: "X2:8"}],
		[{"type": "fuse", "designation": "FU1"}, {0: "X2:1", 1: "X2:2"}],
		[{"type": "coil", "designation": "KM1", "rating": "230ac"}, {0: "X2:1", 1: "X2:2"}],
		[{"type": "changeover", "designation": "KA1"}, {0: "X2:1", 1: "X2:2", 2: "X2:3"}],
		[{"type": "timer", "designation": "KT1", "mode": "on_delay", "delay": 3.0, "control_input": true, "rating": "230ac"}, {0: "X2:1", 2: "X2:9"}],
		[{"type": "rectifier", "designation": "TB1"}, {0: "X2:1", 1: "X2:2", 2: "X2:3", 3: "X2:4"}],
		[{"type": "temp_sensor", "designation": "BT1"}, {0: "X2:1", 1: "X2:2", 2: "X2:3"}],
		[{"type": "motor3", "designation": "M1"}, {0: "X3:1", 1: "X3:2", 2: "X3:3", 3: "X3:4"}],
		[{"type": "motor3", "designation": "M1", "motor_kind": "star_delta"}, {0: "X3:1", 1: "X3:2", 2: "X3:3", 3: "X3:4", 4: "X3:5", 5: "X3:6", 6: "X3:7"}],
		[{"type": "supply", "conductor": "L", "designation": "L1"}, {0: "X1:L1"}],
	]
	var symbols: Array[SchematicSymbol] = []
	for part: Array in parts:
		for o: Array in _orientations():
			symbols.append(_symbol(part[0], o[0], o[1], part[1]))
	await wait_process_frames(2)
	for symbol: SchematicSymbol in symbols:
		_assert_texts_apart(symbol, "%s turned %d (mirrored %s)" % [symbol.component.designation, symbol.placement.rotation, symbol.placement.mirrored])


func test_strip_labels_of_one_symbol_written_alike() -> void:
	var parts: Array = [
		[{"type": "motor3", "designation": "M1"}, {0: "9", 1: "10", 2: "11", 3: "12"}],
		[{"type": "motor3", "designation": "M1", "motor_kind": "star_delta"}, {0: "9", 1: "10", 2: "11", 3: "12", 4: "13", 5: "14", 6: "15"}],
		[{"type": "main_contacts", "designation": "KM1"}, {0: "X4:1", 1: "X4:2", 2: "X4:3", 3: "X4:4", 4: "X4:5", 5: "X4:6"}],
	]
	var symbols: Array[SchematicSymbol] = []
	for part: Array in parts:
		for o: Array in _orientations():
			symbols.append(_symbol(part[0], o[0], o[1], part[1]))
	await wait_process_frames(2)
	for symbol: SchematicSymbol in symbols:
		var what: String = "%s turned %d (mirrored %s)" % [symbol.component.designation, symbol.placement.rotation, symbol.placement.mirrored]
		var lines: Dictionary[int, int] = {}
		var heights: Dictionary[float, bool] = {}
		for m: Array in symbol.marking_rects:
			if m[0] == "strip":
				lines[m[1]] = lines.get(m[1], 0) + 1
				heights[(m[2] as Rect2).size.y] = true
		assert_eq(lines.size(), symbol.placement.strips.size(), what + ": every strip terminal labelled")
		for k: int in lines:
			assert_eq(lines[k], 1, "%s: the label of terminal %d on one line" % [what, k])
		assert_eq(heights.size(), 1, what + ": the labels in one size")
		var names: PackedStringArray = symbol.component.get_terminal_names()
		for m: Array in symbol.marking_rects:
			if m[0] == "strip":
				for k: int in names.size():
					if k != m[1]:
						assert_false(_glyphs(m[2]).intersects(_mark(symbol, k)), "%s: the label of terminal %d off terminal %d" % [what, m[1], k])
		_assert_texts_apart(symbol, what)


## Segments of a 3~ motor's PE lead, node coordinates.
func _pe_lead(symbol: SchematicSymbol) -> PackedVector2Array:
	var frame: Vector2 = ThreePhaseMotorSymbol.CENTER + Vector2.from_angle(PI * 0.88) * ThreePhaseMotorSymbol.RADIUS
	var pe: Vector2 = Vector2(SymbolGeometry.MOTOR_PE_CELL) * G
	return PackedVector2Array([symbol.to_upright(frame), symbol.to_upright(Vector2(pe.x, frame.y)), symbol.to_upright(pe)])


func _crosses(rect: Rect2, a: Vector2, b: Vector2) -> bool:
	var box: Rect2 = Rect2(a, Vector2.ZERO).expand(b).grow(1.0)
	return rect.intersects(box)


func test_running_motor_writes_its_state_clear_of_the_pe_lead() -> void:
	var symbols: Array[SchematicSymbol] = []
	for kind: String in ["standard", "dahlander"]:
		for o: Array in _orientations():
			var symbol: SchematicSymbol = _symbol({"type": "motor3", "designation": "M1", "motor_kind": kind}, o[0], o[1])
			var motor: ThreePhaseMotor = symbol.component as ThreePhaseMotor
			motor.state = ThreePhaseMotor.State.RUNNING
			motor.speed = 2 if kind == "dahlander" else 0
			motor.shaft = 1.0
			motor.rotor_speed = 0.96
			motor.line_currents = PackedFloat32Array([7.9, 7.9, 7.9])
			symbols.append(symbol)
	await wait_process_frames(2)
	for symbol: SchematicSymbol in symbols:
		var lead: PackedVector2Array = _pe_lead(symbol)
		for r: Rect2 in symbol.text_rects:
			for s: int in range(1, lead.size()):
				assert_false(_crosses(_glyphs(r), lead[s - 1], lead[s]), "turned %d (mirrored %s): %s off the PE lead" % [symbol.placement.rotation, symbol.placement.mirrored, r])
		_assert_texts_apart(symbol, "running motor")


func test_rating_plate_beside_the_turned_motor() -> void:
	var symbols: Array[SchematicSymbol] = []
	for box: bool in [false, true]:
		for o: Array in _orientations():
			symbols.append(_symbol({"type": "motor3", "designation": "M1", "show_plate": true, "terminal_box": box}, o[0], o[1]))
	await wait_process_frames(2)
	for symbol: SchematicSymbol in symbols:
		var body: Rect2 = SymbolGeometry.transform_rect(SymbolGeometry.local_body(symbol.component), symbol.placement)
		var plate: Rect2 = symbol.marking_rect("plate")
		assert_true(plate.has_area())
		assert_false(plate.intersects(Rect2(body.position * G, body.size * G)), "turned %d (mirrored %s): the plate beside the motor" % [symbol.placement.rotation, symbol.placement.mirrored])


func test_overload_relay_numbers_outside_its_housing() -> void:
	var symbols: Array[SchematicSymbol] = []
	for o: Array in _orientations():
		symbols.append(_symbol({"type": "overload_relay", "designation": "F1", "poles": 3}, o[0], o[1]))
	await wait_process_frames(2)
	for symbol: SchematicSymbol in symbols:
		var housing: Rect2 = SymbolGeometry.transform_rect(OverloadRelaySymbol.HEATER_BOX, symbol.placement)
		for m: Array in symbol.marking_rects:
			if m[0] == "terminal":
				assert_false(_glyphs(m[2]).intersects(housing), "turned %d: %s clear of the housing" % [symbol.placement.rotation, symbol.component.get_terminal_names()[m[1]]])


func test_terminal_board_names_inside_the_board() -> void:
	var symbols: Array[SchematicSymbol] = []
	for data: Dictionary in [{"connection": "star"}, {"connection": "delta"}, {"motor_kind": "star_delta"}, {"motor_kind": "three_windings"}]:
		for o: Array in _orientations():
			var d: Dictionary = {"type": "motor3", "designation": "M1", "terminal_box": true}
			d.merge(data)
			symbols.append(_symbol(d, o[0], o[1]))
	await wait_process_frames(2)
	for symbol: SchematicSymbol in symbols:
		var motor: ThreePhaseMotor = symbol.component as ThreePhaseMotor
		var board: Rect2 = SymbolGeometry.transform_rect((symbol as ThreePhaseMotorSymbol)._board(motor), symbol.placement)
		for r: Rect2 in symbol.text_rects:
			var glyphs: Rect2 = _glyphs(r)
			assert_true(not glyphs.intersects(board) or board.grow(-1.0).encloses(glyphs), "%s turned %d (mirrored %s): %s not across the board's edge" % [motor.kind, symbol.placement.rotation, symbol.placement.mirrored, r])
		for i: int in motor.winding_terminal_count():
			var cell: Vector2 = SymbolGeometry.transform_point(Vector2(SymbolGeometry.motor_terminal_cell(i, motor.kind)) * G, symbol.placement)
			assert_false(board.grow(SchematicTheme.TERMINAL_SQUARE * 0.5).has_point(cell), "terminal %d outside the board" % i)
		_assert_texts_apart(symbol, "terminal board")


func test_turned_plc_writes_inside_its_display() -> void:
	var symbols: Array[SchematicSymbol] = []
	for o: Array in _orientations():
		var symbol: SchematicSymbol = _symbol({"type": "plc", "designation": "A1", "rating": "230rc"}, o[0], o[1])
		(symbol.component as Plc).energized = true
		symbols.append(symbol)
	await wait_process_frames(2)
	for symbol: SchematicSymbol in symbols:
		var display: Rect2 = SymbolGeometry.transform_rect(PlcSymbol.DISPLAY, symbol.placement)
		var inside: int = 0
		for r: Rect2 in symbol.text_rects:
			if _glyphs(r).intersects(display):
				inside += 1
				assert_true(display.encloses(_glyphs(r)), "turned %d: %s inside the display" % [symbol.placement.rotation, r])
		assert_gt(inside, 0, "the display is written")


func test_lamp_purpose_above_its_designation() -> void:
	var symbols: Array[SchematicSymbol] = []
	for o: Array in _orientations():
		symbols.append(_symbol({"type": "lamp", "designation": "H1", "purpose": "Running", "rating": "230v"}, o[0], o[1]))
	await wait_process_frames(2)
	for symbol: SchematicSymbol in symbols:
		var purpose: Rect2 = symbol.marking_rect("purpose")
		var designation: Rect2 = symbol.marking_rect("designation")
		assert_lt(purpose.get_center().y, designation.get_center().y, "turned %d (mirrored %s): purpose over the designation" % [symbol.placement.rotation, symbol.placement.mirrored])
		var body: Rect2 = SymbolGeometry.transform_rect(SymbolGeometry.local_body(symbol.component), symbol.placement)
		assert_false(_glyphs(purpose).intersects(Rect2(body.position * G, body.size * G)), "the purpose clear of the lamp")
		_assert_texts_apart(symbol, "lamp")


func test_fault_mark_beside_the_body() -> void:
	var symbols: Array[SchematicSymbol] = []
	for data: Dictionary in [{"type": "coil", "designation": "KM1"}, {"type": "contact", "contact": "NO", "designation": "KM1"}, {"type": "motor3", "designation": "M1"}, {"type": "motor3", "designation": "M1", "motor_kind": "three_windings", "terminal_box": true}]:
		for o: Array in _orientations():
			symbols.append(_symbol(data, o[0], o[1]))
	await wait_process_frames(2)
	for symbol: SchematicSymbol in symbols:
		var bolt: Rect2 = Rect2(symbol.to_upright(symbol.fault_anchor()) - Vector2(4.0, 9.5), Vector2(8.0, 19.0))
		var body: Rect2 = SymbolGeometry.transform_rect(SymbolGeometry.local_body(symbol.component), symbol.placement)
		assert_false(bolt.intersects(Rect2(body.position * G, body.size * G)), "%s turned %d: the bolt off the body" % [symbol.component.designation, symbol.placement.rotation])
		for r: Rect2 in symbol.text_rects:
			assert_false(bolt.intersects(_glyphs(r)), "%s turned %d: the bolt off %s" % [symbol.component.designation, symbol.placement.rotation, r])


func test_time_relay_code_fits_its_box() -> void:
	var symbols: Array[SchematicSymbol] = []
	for o: Array in _orientations():
		symbols.append(_symbol({"type": "timer", "designation": "KT1", "mode": "cycle_pause_first", "delay": 3.0, "delay2": 2.0}, o[0], o[1]))
	await wait_process_frames(2)
	for symbol: SchematicSymbol in symbols:
		var box: Rect2 = SymbolGeometry.transform_rect(CoilSymbol.TIMER_BOX, symbol.placement)
		var written: bool = false
		for r: Rect2 in symbol.text_rects:
			if r.get_center().distance_to(box.get_center()) < 2.0:
				written = true
				assert_lte(r.size.x, box.size.x, "turned %d: F10 as wide as its box at most" % symbol.placement.rotation)
		assert_true(written, "the code is written")


func test_strip_slash_leans_right_however_turned() -> void:
	for o: Array in _orientations():
		var p: Placement = Placement.new(Vector2i.ZERO, o[0], o[1])
		var up_right: Vector2 = SymbolGeometry.draw_transform(p).basis_xform(TerminalBlockSymbol.slash(p))
		assert_gt(up_right.x, 0.0, "turned %d: '/'" % o[0])
		assert_lt(up_right.y, 0.0, "turned %d: '/'" % o[0])


func test_closed_no_blade_lies_along_its_lead() -> void:
	assert_eq(ContactSymbol.NO_CLOSED_TIP.x, ContactSymbol.FIXED_END.x)
	assert_eq(ContactSymbol.NO_CLOSED_TIP.x, ContactSymbol.PIVOT.x)


func test_plc_example_contact_clear_of_the_plc() -> void:
	var doc: SchematicDocument = ExampleCircuits.plc_start_stop()
	var contact: CircuitComponent = doc.circuit.get_component("KM1:13-14")
	var symbol: SchematicSymbol = SymbolFactory.create(contact, doc.get_placement(contact.id))
	symbol.live.resize(2)
	add_child_autofree(symbol)
	await wait_process_frames(2)
	var designation: Rect2 = symbol.marking_rect("designation")
	designation.position += symbol.position
	var plc: Rect2 = doc.component_body(doc.circuit.get_component("A1"))
	assert_false(_glyphs(designation).intersects(Rect2(plc.position * G, plc.size * G)), "-KM1 clear of the PLC's box")
