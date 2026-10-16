extends GutTest
## Editing PLC programs in the diagrams of the PLC window.


func test_lad_editing_builds_a_running_rung() -> void:
	var program: PlcProgram = PlcProgram.new()
	program.language = PlcProgram.Language.LAD
	var canvas: PlcLadCanvas = autofree(PlcLadCanvas.new())
	canvas.show_program(program, null)
	assert_eq(program.rungs.size(), 1, "an empty network to draw into")
	watch_signals(canvas)
	canvas._apply("no", 0, 0, 0, true)
	canvas._apply("coil", 0, 0, 3, true)
	var rung: PlcRung = program.rungs[0]
	assert_eq(rung.get_cell(0, 0), {"kind": "no", "operand": "I1"})
	assert_eq(rung.get_coil(0), {"kind": "coil", "operand": "Q1"})
	assert_eq(rung.get_cell(0, PlcRung.COLUMNS - 1).get("kind", ""), "wire", "wired up to the coil")
	assert_eq(canvas.selection_info()["operand"], "Q1")
	canvas.set_property("operand", "Q3")
	assert_signal_emitted(canvas, "changed")
	assert_eq(rung.get_coil(0)["operand"], "Q3")
	# A second coil takes the next free output.
	canvas._apply("link", 0, 0, 0, true)
	canvas._apply("coil", 0, 1, 0, true)
	assert_eq(rung.get_coil(1)["operand"], "Q1")
	var runtime: PlcRuntime = PlcRuntime.new(program)
	runtime.inputs[0] = 1
	runtime.scan_until_stable()
	assert_eq(runtime.outputs[2], 1)
	canvas.selected = {"rung": 0, "row": 0, "column": PlcRung.COLUMNS}
	canvas.delete_selection()
	assert_true(rung.get_coil(0).is_empty())


func test_lad_networks_added_and_removed() -> void:
	var program: PlcProgram = PlcProgram.new()
	program.language = PlcProgram.Language.LAD
	var canvas: PlcLadCanvas = autofree(PlcLadCanvas.new())
	canvas.show_program(program, null)
	canvas.add_network()
	assert_eq(program.rungs.size(), 2)
	canvas.selected = {"rung": 0}
	canvas.delete_selection()
	assert_eq(program.rungs.size(), 1)


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
