extends GutTest
## Editing PLC programs in the diagrams of the PLC window.


func test_lad_editing_builds_a_running_rung() -> void:
	var program: PlcProgram = PlcProgram.new()
	program.language = PlcProgram.Language.LAD
	var canvas: PlcLadCanvas = autofree(PlcLadCanvas.new())
	canvas.show_program(program, null)
	assert_eq(program.rungs.size(), 1, "a ladder to draw into")
	watch_signals(canvas)
	canvas._apply("no", 0, 0, true)
	canvas._apply("coil", 0, 3, true)
	var rung: PlcRung = program.ladder()
	assert_eq(rung.get_cell(0, 0), {"kind": "no", "operand": "I1"})
	assert_eq(rung.get_coil(0), {"kind": "coil", "operand": "Q1"})
	assert_eq(rung.get_cell(0, PlcRung.COLUMNS - 1).get("kind", ""), "wire", "wired up to the coil")
	assert_eq(canvas.selection_info()["operand"], "Q1")
	canvas.set_property("operand", "Q3")
	assert_signal_emitted(canvas, "changed")
	assert_eq(rung.get_coil(0)["operand"], "Q3")
	# A second coil on a branch takes the next free output.
	canvas._apply("link", 0, 0, true)
	canvas._apply("coil", 1, 0, true)
	assert_eq(rung.get_coil(1)["operand"], "Q1")
	var runtime: PlcRuntime = PlcRuntime.new(program)
	runtime.inputs[0] = 1
	runtime.scan_until_stable()
	assert_eq(runtime.outputs[2], 1)
	assert_eq(runtime.outputs[0], 1)
	canvas.selected = {"row": 0, "column": PlcRung.COLUMNS}
	canvas.delete_selection()
	assert_true(rung.get_coil(0).is_empty())


func test_lad_places_anywhere_along_the_rail() -> void:
	var program: PlcProgram = PlcProgram.new()
	program.language = PlcProgram.Language.LAD
	var canvas: PlcLadCanvas = autofree(PlcLadCanvas.new())
	canvas.show_program(program, null)
	canvas._apply("no", 5, 0, true)
	canvas._apply("coil", 5, 0, true)
	var rung: PlcRung = program.ladder()
	assert_eq(rung.row_count(), 6, "the rows above stay empty")
	assert_eq(rung.rung_groups(), [Vector2i(5, 5)] as Array[Vector2i])
	canvas.selected = {"row": 5, "column": 0}
	canvas.insert_row()
	assert_eq(rung.get_cell(6, 0)["operand"], "I1", "moved down by the new row")
	canvas.selected = {"row": 6, "column": 0}
	canvas.delete_row()
	assert_eq(rung.row_count(), 1, "the empty rows at the bottom go")
	assert_true(rung.is_empty())


func test_monitoring_is_read_only() -> void:
	var program: PlcProgram = ExampleCircuits.plc_start_stop_program()
	var canvas: PlcFbdCanvas = autofree(PlcFbdCanvas.new())
	canvas.show_program(program, PlcRuntime.new(program))
	canvas.selected = 6
	canvas.set_property("time", 1.0)
	canvas.delete_selection()
	assert_eq(program.block(6).time, 5.0)
	assert_eq(program.blocks.size(), 7)


func test_fbd_editing() -> void:
	var program: PlcProgram = ExampleCircuits.plc_start_stop_program()
	var canvas: PlcFbdCanvas = autofree(PlcFbdCanvas.new())
	canvas.show_program(program, null)
	canvas.selected = 6
	assert_eq(canvas.selection_info()["time"], 5.0)
	canvas.set_property("time", 2.5)
	assert_eq(program.block(6).time, 2.5)
	# Every connection has an orthogonal route.
	for b: PlcBlock in program.blocks:
		for p: int in b.inputs.size():
			if b.inputs[p] > 0:
				var route: PackedVector2Array = canvas._route(program.block(b.inputs[p]), b, p)
				for i: int in route.size() - 1:
					assert_true(route[i].x == route[i + 1].x or route[i].y == route[i + 1].y)
	canvas.selected = 5
	canvas.delete_selection()
	assert_null(program.block(5))
	assert_eq(program.block(3).inputs[1], 0, "the connection from the removed block went with it")


func test_fbd_copy_and_paste_keeps_inner_connections() -> void:
	var program: PlcProgram = ExampleCircuits.plc_start_stop_program()
	var canvas: PlcFbdCanvas = autofree(PlcFbdCanvas.new())
	canvas.show_program(program, null)
	# B003 (OR) and B004 (AND): OR feeds AND; OR's inputs come from outside.
	canvas.chosen = {3: true, 4: true}
	canvas.copy_selection()
	canvas.paste()
	assert_eq(program.blocks.size(), 9)
	var new_or: PlcBlock = program.block(8)
	var new_and: PlcBlock = program.block(9)
	assert_eq(new_or.type, "or")
	assert_eq(new_and.inputs[0], 8, "the copy of AND is fed by the copy of OR")
	assert_eq(new_or.inputs[0], 0, "connections from blocks not copied are left out")
	assert_eq(canvas.chosen.keys().size(), 2, "the copies are selected")
	canvas.delete_selection()
	assert_eq(program.blocks.size(), 7)


func test_fbd_selection_moves_together() -> void:
	var program: PlcProgram = ExampleCircuits.plc_start_stop_program()
	var canvas: PlcFbdCanvas = autofree(PlcFbdCanvas.new())
	canvas.size = Vector2(1000, 800)
	canvas.show_program(program, null)
	canvas.select_all()
	var before: Dictionary[int, Vector2i] = {}
	for b: PlcBlock in program.blocks:
		before[b.id] = b.cell
	# Grab B004 and drag it two cells right and one down.
	var grab: Vector2 = canvas._px(PlcFbdCanvas.body_rect(program.block(4)).get_center())
	canvas._mouse = grab
	canvas._press(false)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = grab + Vector2(2, 1) * PlcFbdCanvas.U
	canvas._canvas_input(motion)
	canvas._release()
	for b: PlcBlock in program.blocks:
		assert_eq(b.cell, before[b.id] + Vector2i(2, 1), b.label())


func test_lad_wire_is_drawn_like_a_schematic_wire() -> void:
	var program: PlcProgram = PlcProgram.new()
	program.language = PlcProgram.Language.LAD
	var canvas: PlcLadCanvas = autofree(PlcLadCanvas.new())
	canvas.show_program(program, null)
	canvas._apply("no", 0, 0, true)
	canvas._apply("coil", 0, 0, true)
	var rung: PlcRung = program.ladder()
	canvas.tool = "wire"
	watch_signals(canvas)
	# From the rail down to row 1 and along it to the side after cell 2: the
	# first run goes down the rail, the corner on row 1 is added by the click.
	canvas._mouse = canvas._side_point(Vector2i(0, 0))
	canvas._press()
	canvas._mouse = canvas._side_point(Vector2i(3, 1))
	canvas._press()
	assert_eq(canvas._wire_points, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(3, 1)] as Array[Vector2i], "a corner on empty paper")
	assert_signal_not_emitted(canvas, "changed", "nothing laid yet")
	# Up to the main row, which it joins: the wire ends there.
	canvas._mouse = canvas._side_point(Vector2i(3, 0))
	canvas._press()
	assert_true(canvas._wire_points.is_empty(), "ended on the main row")
	assert_signal_emit_count(canvas, "changed", 1)
	for c: int in 3:
		assert_eq(rung.get_cell(1, c), {"kind": "wire"}, "wire along row 1")
	assert_true(rung.has_link(0, 2), "linked up to the main row")
	assert_eq(rung.get_cell(0, 0)["kind"], "no", "elements stay")
	assert_eq(rung.rung_groups(), [Vector2i(0, 1)] as Array[Vector2i])


func test_lad_wire_runs_on_from_the_row_and_can_be_dropped() -> void:
	var program: PlcProgram = PlcProgram.new()
	program.language = PlcProgram.Language.LAD
	var canvas: PlcLadCanvas = autofree(PlcLadCanvas.new())
	canvas.show_program(program, null)
	canvas._apply("no", 0, 0, true)
	var rung: PlcRung = program.ladder()
	canvas.tool = "wire"
	# From the contact's right side the first run goes along the row.
	canvas._wire_click(Vector2i(1, 0))
	assert_eq(canvas._route_to(Vector2i(4, 2)), [Vector2i(1, 0), Vector2i(4, 0), Vector2i(4, 2)] as Array[Vector2i])
	canvas._wire_click(Vector2i(4, 2))
	var esc: InputEventKey = InputEventKey.new()
	esc.keycode = KEY_BACKSPACE
	esc.pressed = true
	canvas._canvas_input(esc)
	assert_eq(canvas._wire_points, [Vector2i(1, 0), Vector2i(4, 0)] as Array[Vector2i], "Backspace takes the last corner back")
	esc.keycode = KEY_ESCAPE
	canvas._canvas_input(esc)
	assert_true(canvas._wire_points.is_empty(), "Esc drops the wire")
	assert_eq(canvas.tool, "wire", "the tool stays")
	# A double click on paper ends the wire there.
	canvas._wire_click(Vector2i(1, 0))
	canvas._wire_click(Vector2i(5, 0))
	canvas._wire_click(Vector2i(5, 0))
	assert_true(canvas._wire_points.is_empty())
	for c: int in range(1, 5):
		assert_eq(rung.get_cell(0, c), {"kind": "wire"})
	assert_true(rung.get_cell(0, 5).is_empty())


func test_lad_shows_where_the_tool_puts_its_element() -> void:
	var program: PlcProgram = PlcProgram.new()
	program.language = PlcProgram.Language.LAD
	var canvas: PlcLadCanvas = autofree(PlcLadCanvas.new())
	canvas.show_program(program, null)
	canvas._mouse_inside = true
	canvas._mouse = Vector2(PlcLadCanvas.RAIL_X + PlcLadCanvas.CELL_W * 2.5, canvas._row_y(1))
	canvas.tool = "nc"
	assert_eq(canvas._aim(), {"row": 1, "column": 2})
	canvas.tool = "set"
	assert_eq(canvas._aim(), {"row": 1, "column": PlcRung.COLUMNS}, "coils at the end of the row")
	canvas.tool = "wire"
	assert_eq(canvas._aim(), {}, "wires have their own preview")
	canvas.tool = ""
	assert_eq(canvas._aim(), {})
	canvas.tool = "no"
	canvas._mouse_inside = false
	assert_eq(canvas._aim(), {}, "nothing while the mouse is off the diagram")
	assert_true(program.ladder().is_empty(), "the preview changes nothing")
