extends GutTest
## PLCs: inputs beyond 32, ladder rows, loops in the function block diagram,
## the program window and its test simulation.


## A PLC whose program never settles (scanned at no cost).
class RestlessPlc:
	extends Plc

	func _run() -> void:
		pending = true
		_cycle_left = CYCLE_TIME


func after_each() -> void:
	# Controls the windows took down are freed at the end of the frame.
	await wait_process_frames(1)


## A window showing [param plc] for editing.
func _window(plc: Plc) -> PlcWindow:
	var window: PlcWindow = PlcWindow.new("A1")
	window.bind(plc, false)
	add_child_autofree(window)
	return window


## Texts of the labels in the window's side panel.
func _side_texts(window: PlcWindow) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for child: Node in window._side.get_children():
		if child is Label:
			texts.append((child as Label).text)
	return texts


func _side_spins(window: PlcWindow) -> Array[SpinBox]:
	var spins: Array[SpinBox] = []
	for child: Node in window._side.get_children():
		if child is SpinBox:
			spins.append(child as SpinBox)
	return spins


func test_compact_plc_inputs_beyond_32_and_64() -> void:
	var mods: Array[Plc.Module] = []
	for m: int in 8:
		mods.append(Plc.Module.SM_DI8)
	var circuit: Circuit = Circuit.new()
	circuit.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS))
	circuit.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS))
	var a1: CompactPlc = circuit.add(CompactPlc.new("A1", null, mods, CompactPlc.Cpu.DI14_DQ10)) as CompactPlc
	assert_eq(a1.input_count(), 78)
	circuit.connect_terminals("+", "A1:L+")
	circuit.connect_terminals("A1:M", "-")
	circuit.connect_terminals("A1:1M", "-")
	for m: int in 8:
		circuit.connect_terminals("A1:%d.1M" % (m + 2), "-")
	circuit.connect_terminals("+", "A1:" + a1.get_terminal_names()[a1.input_terminal(31)])
	circuit.connect_terminals("+", "A1:" + a1.get_terminal_names()[a1.input_terminal(77)])
	Simulator.new(circuit).step()
	var on: Array[int] = []
	for k: int in a1.input_count():
		if a1.input_on(k):
			on.append(k)
	assert_eq(on, [31, 77] as Array[int], "only I32 (%I16.1) and I78 (%I36.7) are on")
	assert_eq(a1.runtime.inputs[31], 1)
	assert_eq(a1.runtime.inputs[77], 1)
	assert_eq(a1.runtime.inputs[13], 0, "I14 is no echo of I78")
	# Only I1 on: no other input of the 78 follows it.
	var states: PackedByteArray = PackedByteArray()
	states.resize(a1.input_count())
	states[0] = 1
	a1.update(true, states, a1.all_modules())
	var seen: int = 0
	for k: int in a1.input_count():
		seen += a1.runtime.inputs[k]
	assert_eq(seen, 1)


func test_deleting_a_row_keeps_rungs_apart() -> void:
	var p: PlcProgram = PlcProgram.new()
	p.language = PlcProgram.Language.LAD
	var r: PlcRung = p.ladder()
	r.set_cell(0, 0, {"kind": "no", "operand": "I1"})
	r.set_coil(0, {"kind": "coil", "operand": "Q1"})
	r.wire_to_coil(0)
	r.set_cell(1, 0, {"kind": "no", "operand": "I2"})
	r.set_link(0, 0, true)
	r.set_cell(2, 0, {"kind": "no", "operand": "I3"})
	r.set_coil(2, {"kind": "coil", "operand": "Q2"})
	r.wire_to_coil(2)
	r.remove_row(1)
	assert_eq(r.rung_groups(), [Vector2i(0, 0), Vector2i(1, 1)] as Array[Vector2i], "two rungs, as before")
	var rt: PlcRuntime = PlcRuntime.new(p)
	rt.inputs[0] = 1
	rt.scan_until_stable()
	assert_eq(rt.outputs[0], 1)
	assert_eq(rt.outputs[1], 0, "I1 does not switch Q2")
	# A link going on through the removed row still joins the rows round it.
	var through: PlcRung = PlcRung.new()
	through.set_cell(2, 0, {"kind": "no", "operand": "I3"})
	through.set_link(0, 0, true)
	through.set_link(1, 0, true)
	through.remove_row(1)
	assert_true(through.has_link(0, 0))
	# Insert and remove give the ladder back.
	var before: Dictionary = through.to_data()
	through.insert_row(1)
	through.remove_row(1)
	assert_eq(through.to_data(), before)


func test_fbd_loop_starts_on_the_loop() -> void:
	# B1 = XOR(I1, B4), B4 = OR(I1, M1), M1 = B4: the loop is B4 and B5; B1
	# and the counter B2 it feeds come after it.
	var p: PlcProgram = PlcProgram.new()
	var xor: PlcBlock = p.add_block("xor", Vector2i(20, 0))
	var counter: PlcBlock = p.add_block("counter", Vector2i(30, 0))
	var i1: PlcBlock = p.add_block("input", Vector2i(0, 0))
	var gate_or: PlcBlock = p.add_block("or", Vector2i(10, 0))
	var m1: PlcBlock = p.add_block("flag", Vector2i(15, 5))
	gate_or.inputs[0] = i1.id
	gate_or.inputs[1] = m1.id
	m1.inputs[0] = gate_or.id
	xor.inputs[0] = i1.id
	xor.inputs[1] = gate_or.id
	counter.inputs[1] = xor.id
	counter.preset = 1
	var rt: PlcRuntime = PlcRuntime.new(p)
	assert_eq(rt._order, PackedInt32Array([3, 4, 1, 2, 5]))
	rt.scan_until_stable()
	rt.inputs[0] = 1
	rt.scan_until_stable()
	assert_eq(rt.counters["B2"].value, 0, "I1 XOR (I1 OR M1) never is 1")


func test_long_step_keeps_the_cycle_time_at_zero() -> void:
	var plc: RestlessPlc = RestlessPlc.new("A1")
	plc.update(true, PackedByteArray(), 0)
	var timer: PlcTimer = PlcTimer.new(PlcTimer.Kind.ON_DELAY, 1000.0)
	timer.update(true)
	plc.runtime.timers["T1"] = timer
	# Longer than the scans the guard allows: the rest of the step is skipped.
	plc.advance(200.0)
	assert_eq(plc._cycle_left, 0.0)
	var elapsed: float = timer.elapsed
	plc.advance(0.005)
	assert_gt(timer.elapsed, elapsed, "the timer goes on, never back")


func test_operands_are_plain_numbers() -> void:
	assert_false(PlcProgram.valid_operand("I+1", "I"))
	assert_false(PlcProgram.valid_operand("I01", "I"))
	assert_false(PlcProgram.valid_operand("Q-1", "Q"))
	assert_true(PlcProgram.valid_operand("I10", "I"))


func test_modules_checked_with_the_version_on_load() -> void:
	var d: Dictionary = {"type": "plc", "designation": "A1", "rating": "24rc", "modules": ["2ai", "2ai", "2ai", "2ai"]}
	var plc: Plc = DocumentSerializer.component_from_dict(d) as Plc
	assert_eq(plc.modules.size(), 2, "4 analog inputs of its own and 2 x 2 more")
	d["rating"] = "230rc"
	assert_eq((DocumentSerializer.component_from_dict(d) as Plc).modules.size(), 4)


func test_analog_volts_switch_the_input_they_are_on() -> void:
	var circuit: Circuit = Circuit.new()
	circuit.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS))
	circuit.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS))
	var a1: Plc = circuit.add(Plc.new("A1")) as Plc
	a1.rating = "1224rc"
	circuit.connect_terminals("+", "A1:L1")
	circuit.connect_terminals("A1:N", "-")
	var sensor: TemperatureSensor = circuit.add(TemperatureSensor.new("BT1")) as TemperatureSensor
	circuit.connect_terminals("+", "BT1:L+")
	circuit.connect_terminals("BT1:M", "-")
	circuit.connect_terminals("BT1:U", "A1:I7")
	sensor.temperature = 100.0
	var sim: Simulator = Simulator.new(circuit)
	sim.step()
	assert_almost_eq(a1.runtime.analog_inputs[0], 1000.0, 0.5, "AI1 reads 10 V")
	assert_true(a1.input_on(6), "10 V is over the threshold of I7")
	sensor.temperature = 50.0
	sim.step()
	assert_false(a1.input_on(6), "5 V is not")


func test_window_rebind_takes_the_new_plc() -> void:
	var p: PlcProgram = PlcProgram.new()
	p.add_block("input", Vector2i(0, 0))
	p.ladder()
	var plc: CompactPlc = CompactPlc.new("A1", p)
	var window: PlcWindow = _window(plc)
	var mods: Array[Plc.Module] = [Plc.Module.SM_DI8]
	var bigger: CompactPlc = CompactPlc.new("A1", PlcProgram.from_data(p.to_data()), mods)
	window.bind(bigger, false)
	plc = null
	assert_true(window._fbd.address.is_valid(), "the old PLC is gone")
	assert_eq(window._fbd.address.call("I9"), "%I8.0")
	assert_eq(window._lad.address.call("I1"), "%I0.0")
	# The same PLC made again (any edit of the schematic): the names stay.
	var again: CompactPlc = CompactPlc.new("A1", PlcProgram.from_data(p.to_data()), mods)
	window.bind(again, false)
	bigger = null
	assert_true(window._fbd.address.is_valid())
	assert_eq(window._fbd.address.call("I1"), "%I0.0")


func test_test_simulation_of_a_new_plc_survives_other_edits() -> void:
	var p: PlcProgram = PlcProgram.new()
	p.add_block("input", Vector2i(0, 0))
	var window: PlcWindow = _window(Plc.new("A1", p))
	window._set_test_simulation(true)
	window.bind(Plc.new("A1", PlcProgram.from_data(p.to_data())), false)
	assert_not_null(window._sim_plc, "the program without a ladder is the same")


func test_edits_changing_nothing_make_no_undo_step() -> void:
	var window: PlcWindow = _window(Plc.new("A1", ExampleCircuits.plc_start_stop_program()))
	watch_signals(window)
	var fbd: PlcFbdCanvas = window._fbd
	# A connection drawn from an output and dropped on empty paper.
	fbd._mouse = fbd._px(PlcFbdCanvas.output_point(window._program.blocks[0]))
	fbd._press(false)
	fbd._mouse = Vector2(5, 700)
	fbd._release()
	# Delete on an empty place of the ladder.
	window._lad.selected = {"row": 1, "column": 5}
	window._lad.delete_selection()
	assert_signal_not_emitted(window, "program_edited")
	fbd.selected = 6
	fbd.set_property("time", 1.0)
	assert_signal_emit_count(window, "program_edited", 1, "a real change")


func test_insert_row_on_a_full_ladder_does_nothing() -> void:
	var program: PlcProgram = PlcProgram.new()
	program.language = PlcProgram.Language.LAD
	var canvas: PlcLadCanvas = autofree(PlcLadCanvas.new())
	canvas.show_program(program, null)
	program.ladder().set_cell(PlcRung.MAX_ROWS - 1, 0, {"kind": "wire"})
	canvas.selected = {"row": 3, "column": 0}
	watch_signals(canvas)
	canvas.insert_row()
	assert_eq(canvas.selected, {"row": 3, "column": 0})
	assert_signal_not_emitted(canvas, "changed")


func test_cancelled_connection_goes_back_to_its_input() -> void:
	var program: PlcProgram = ExampleCircuits.plc_start_stop_program()
	var canvas: PlcFbdCanvas = autofree(PlcFbdCanvas.new())
	canvas.show_program(program, null)
	var target: PlcBlock = null
	var pin: int = -1
	for b: PlcBlock in program.blocks:
		for k: int in b.inputs.size():
			if target == null and b.inputs[k] > 0:
				target = b
				pin = k
	var before: Dictionary = program.to_data()
	for cancel: int in 2:
		canvas._mouse = canvas._px(PlcFbdCanvas.input_point(target, pin) + Vector2(0.2, 0))
		canvas._press(false)
		assert_eq(target.inputs[pin], 0, "picked up")
		if cancel == 0:
			var esc: InputEventKey = InputEventKey.new()
			esc.keycode = KEY_ESCAPE
			esc.pressed = true
			canvas._canvas_input(esc)
		else:
			canvas._right_click(canvas._mouse)
		assert_eq(program.to_data(), before, "Esc or a right click puts it back")


func test_paste_with_the_mouse_away_goes_beside_the_copies() -> void:
	var program: PlcProgram = PlcProgram.new()
	program.add_block("and", Vector2i(10, 10))
	var canvas: PlcFbdCanvas = autofree(PlcFbdCanvas.new())
	canvas.size = Vector2(2000, 2000)
	canvas.show_program(program, null)
	canvas._notification(Control.NOTIFICATION_MOUSE_ENTER)
	canvas._mouse = canvas._px(Vector2(30, 30))
	canvas._notification(Control.NOTIFICATION_MOUSE_EXIT)
	canvas.select_all()
	canvas.copy_selection()
	canvas.paste()
	assert_eq(program.blocks[1].cell, Vector2i(12, 12), "not where the mouse left the diagram")


func test_test_simulation_shows_the_selected_blocks_state() -> void:
	var window: PlcWindow = _window(Plc.new("A1", ExampleCircuits.plc_start_stop_program()))
	window._set_test_simulation(true)
	window._fbd.selected = 6
	window._build_side()
	var live: bool = false
	for text: String in _side_texts(window):
		live = live or text.begins_with("Output =")
	assert_true(live, "Output = 0 under the block's properties")


func test_side_panel_takes_the_whole_range() -> void:
	var program: PlcProgram = PlcProgram.new()
	var counter: PlcBlock = program.add_block("counter", Vector2i(0, 0))
	counter.preset = 500000
	var timer: PlcBlock = program.add_block("on_delay", Vector2i(0, 6))
	timer.time = 7200.0
	program.ladder().set_coil(0, {"kind": "analog", "operand": "AQ1", "value": 100.0})
	var window: PlcWindow = _window(Plc.new("A1", program))
	window._fbd.selected = counter.id
	window._build_side()
	assert_eq(_side_spins(window)[0].value, 500000.0)
	window._fbd.selected = timer.id
	window._build_side()
	assert_eq(_side_spins(window)[0].value, 7200.0)
	window._on_language(PlcProgram.Language.LAD)
	window._lad.selected = {"row": 0, "column": PlcRung.COLUMNS}
	window._build_side()
	assert_eq(_side_spins(window)[0].min_value, 0.0, "no AQ value below 0")


func test_compact_plc_analog_scale_in_the_window() -> void:
	var window: PlcWindow = _window(CompactPlc.new("A1", PlcProgram.new()))
	window._lad._apply("ge", 0, 0, true)
	assert_eq(window._program.ladder().get_cell(0, 0)["value"], 13824.0, "half of 0-27648")
	window._lad.selected = {"row": 0, "column": 0}
	window._on_language(PlcProgram.Language.LAD)
	window._build_side()
	var help: bool = false
	for text: String in _side_texts(window):
		help = help or text.contains("0-27648")
	assert_true(help, "the help names the CPU's scale")
	window._on_language(PlcProgram.Language.FBD)
	window._fbd.tool = "analog_threshold"
	window._fbd._mouse = Vector2(200, 200)
	window._fbd._press(false)
	var block: PlcBlock = window._program.blocks[0]
	assert_almost_eq(block.on, 13824.0, 0.01)
	assert_almost_eq(block.off, 11059.2, 0.01)


func test_analog_volts_switch_the_input_in_the_test_simulation() -> void:
	var plc: Plc = Plc.new("A1", PlcProgram.new())
	plc.rating = "1224rc"
	var window: PlcWindow = _window(plc)
	window._set_test_simulation(true)
	window._analog_inputs[0].value = 10.0
	assert_true(window._sim_plc.input_on(6), "10 V on AI1 switches I7 on")


func test_a_ladder_row_fits_the_window() -> void:
	var window: PlcWindow = _window(Plc.new("A1", PlcProgram.new()))
	window._on_language(PlcProgram.Language.LAD)
	await wait_process_frames(3)
	assert_gte(window._lad_scroll.size.x, window._lad.custom_minimum_size.x, "the coils are in view")


func test_keys_go_to_the_main_window_but_space() -> void:
	var window: PlcWindow = _window(Plc.new("A1", PlcProgram.new()))
	var catcher: Node = null
	for child: Node in window.get_children():
		if child is PlcWindow.KeyCatcher:
			catcher = child
	watch_signals(window)
	var release: InputEventKey = InputEventKey.new()
	release.keycode = KEY_B
	release.pressed = false
	catcher._unhandled_input(release)
	assert_signal_emitted(window, "key_pressed", "a key let go reaches main")
	var space: InputEventKey = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	catcher._unhandled_input(space)
	assert_signal_emit_count(window, "key_pressed", 1, "Space stays for moving the diagram")
