extends GutTest
## The SCL export of a compact CPU's program: the source reads as the
## subset of SCL the export writes (blocks, declarations, statements), and
## run cycle by cycle on a process image (SclRunner) it switches the
## outputs, flags and analog outputs exactly as LadderLab's PLC runtime does
## with the same inputs at the same times: hand-made programs using every
## block and ladder element, and random ones.

const SclRunner = preload("res://test/unit/scl_runner.gd")

## Milliseconds a cycle.
const CYCLE_MS: int = 10


## A compact CPU (8 DI / 6 DQ) with an analog output module (AQ1, AQ2).
func _cpu(program: PlcProgram) -> CompactPlc:
	return CompactPlc.new("A1", program, [Plc.Module.SM_AQ2], CompactPlc.Cpu.DI8_DQ6)


## Runs [param plc]'s program for [param cycles] cycles in both, inputs
## changed at random ([param seed]); returns the first difference ("" for
## none).
func _run_both(plc: CompactPlc, cycles: int, seed: int) -> String:
	var result: Dictionary = SclExport.export(plc)
	if not (result["errors"] as Array).is_empty():
		return "export errors: %s" % str(result["errors"])
	var runner: SclRunner = SclRunner.new(result["text"])
	if not runner.error.is_empty():
		return "SCL: " + runner.error
	var runtime: PlcRuntime = PlcRuntime.new(plc.program.duplicate_program())
	runtime.full_scale = plc.full_scale()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	for k: int in cycles:
		for i: int in plc.input_count():
			if rng.randf() < 0.08:
				var on: bool = rng.randf() < 0.5
				runtime.inputs[i] = 1 if on else 0
				runner.image[plc.address("I%d" % (i + 1))] = on
		for i: int in plc.analog_input_count():
			if rng.randf() < 0.05:
				var word: int = rng.randi_range(0, 27648)
				runtime.analog_inputs[i] = float(word)
				runner.image[plc.address("AI%d" % (i + 1))] = word
		runtime.scan()
		runner.cycle()
		for q: int in plc.output_count():
			var address: String = plc.address("Q%d" % (q + 1))
			if (runtime.outputs[q] != 0) != bool(runner.image.get(address, false)):
				return "cycle %d: %s is %s in LadderLab" % [k, address, runtime.outputs[q] != 0]
		for m: int in PlcProgram.AREA_SIZES["M"]:
			var address: String = plc.address("M%d" % (m + 1))
			if (runtime.flags[m] != 0) != bool(runner.image.get(address, false)):
				return "cycle %d: %s is %s in LadderLab" % [k, address, runtime.flags[m] != 0]
		for a: int in plc.analog_output_count():
			var address: String = plc.address("AQ%d" % (a + 1))
			var word: int = int(runner.image.get(address, 0))
			var value: int = word - 0x10000 if word >= 0x8000 else word
			if roundi(runtime.analog_outputs[a]) != value:
				return "cycle %d: %s is %d in LadderLab, %d in SCL" % [k, address, roundi(runtime.analog_outputs[a]), value]
		runtime.advance(CYCLE_MS / 1000.0)
		runner.clock += CYCLE_MS
	return ""


# --- Hand-made programs -----------------------------------------------------------

func test_source_has_the_three_blocks() -> void:
	var p: PlcProgram = PlcProgram.new()
	var i1: PlcBlock = p.add_block("input", Vector2i.ZERO)
	var q1: PlcBlock = p.add_block("output", Vector2i(4, 0))
	q1.inputs[0] = i1.id
	var text: String = SclExport.export(_cpu(p))["text"]
	assert_string_contains(text, "FUNCTION_BLOCK \"LadderLab_A1\"")
	assert_string_contains(text, "DATA_BLOCK \"LadderLab_A1_DB\"")
	assert_string_contains(text, "ORGANIZATION_BLOCK \"Main\"")
	assert_string_contains(text, "\"LadderLab_A1_DB\"();")
	assert_string_contains(text, "%Q0.0 := #B002;")
	assert_eq(SclRunner.new(text).error, "")


func test_every_block_of_the_function_block_diagram() -> void:
	var p: PlcProgram = PlcProgram.new()
	var b: Dictionary = {}
	for name: String in ["input", "output", "flag", "hi", "lo", "and", "or", "not", "nand", "nor", "xor", "on_delay", "off_delay", "latch", "pulse_relay", "counter", "analog_input", "analog_output", "analog_threshold", "analog_compare", "analog_amplifier"]:
		b[name] = p.add_block(name, Vector2i(0, 4 * b.size()))
	var i2: PlcBlock = p.add_block("input", Vector2i(0, 100))
	i2.operand = "I2"
	var i3: PlcBlock = p.add_block("input", Vector2i(0, 104))
	i3.operand = "I3"
	b["and"].inputs[0] = b["input"].id
	b["and"].inputs[1] = i2.id
	b["or"].inputs[0] = b["and"].id
	b["or"].inputs[1] = b["latch"].id
	b["not"].inputs[0] = i3.id
	b["nand"].inputs[0] = b["input"].id
	b["nand"].inputs[2] = i3.id
	b["nor"].inputs[1] = i2.id
	b["xor"].inputs[0] = b["input"].id
	b["xor"].inputs[1] = i3.id
	b["on_delay"].inputs[0] = b["xor"].id
	b["on_delay"].time = 0.25
	b["off_delay"].inputs[0] = i2.id
	b["off_delay"].inputs[1] = i3.id
	b["off_delay"].time = 0.4
	b["latch"].inputs[0] = b["on_delay"].id
	b["latch"].inputs[1] = b["not"].id
	b["pulse_relay"].inputs[0] = b["input"].id
	b["pulse_relay"].inputs[2] = b["nor"].id
	b["counter"].inputs[0] = b["not"].id
	b["counter"].inputs[1] = i2.id
	b["counter"].inputs[2] = b["off_delay"].id
	b["counter"].preset = 3
	b["output"].inputs[0] = b["or"].id
	b["flag"].operand = "M3"
	b["flag"].inputs[0] = b["counter"].id
	var q2: PlcBlock = p.add_block("output", Vector2i(10, 0))
	q2.operand = "Q2"
	q2.inputs[0] = b["pulse_relay"].id
	var q3: PlcBlock = p.add_block("output", Vector2i(10, 4))
	q3.operand = "Q3"
	q3.inputs[0] = b["analog_threshold"].id
	var q4: PlcBlock = p.add_block("output", Vector2i(10, 8))
	q4.operand = "Q4"
	q4.inputs[0] = b["analog_compare"].id
	b["analog_threshold"].inputs[0] = b["analog_input"].id
	b["analog_threshold"].on = 15000.0
	b["analog_threshold"].off = 9000.0
	b["analog_compare"].inputs[0] = b["analog_input"].id
	b["analog_compare"].inputs[1] = b["analog_amplifier"].id
	b["analog_compare"].on = 4000.0
	b["analog_compare"].off = 12000.0
	b["analog_amplifier"].inputs[0] = b["hi"].id
	b["analog_amplifier"].gain = 0.4
	b["analog_amplifier"].offset = 120.0
	b["analog_output"].inputs[0] = b["analog_input"].id
	assert_eq(_run_both(_cpu(p), 3000, 1), "")


func test_every_element_of_the_ladder_diagram() -> void:
	var p: PlcProgram = PlcProgram.new()
	p.language = PlcProgram.Language.LAD
	var r: PlcRung = p.ladder()
	# Q1 = (I1 OR Q1) AND NOT I2: start / stop with a branch.
	r.set_cell(0, 0, {"kind": "no", "operand": "I1"})
	r.set_cell(1, 0, {"kind": "no", "operand": "Q1"})
	r.set_link(0, 0, true)
	r.set_cell(0, 1, {"kind": "nc", "operand": "I2"})
	for c: int in range(2, PlcRung.COLUMNS):
		r.set_cell(0, c, {"kind": "wire"})
	r.set_coil(0, {"kind": "coil", "operand": "Q1"})
	# T1 on-delay from Q1, T2 off-delay from I3, reset by I4.
	r.set_cell(3, 0, {"kind": "no", "operand": "Q1"})
	r.set_coil(3, {"kind": "on_delay", "operand": "T1", "time": 0.3})
	r.set_cell(5, 0, {"kind": "no", "operand": "I3"})
	r.set_coil(5, {"kind": "off_delay", "operand": "T2", "time": 0.5})
	r.set_cell(7, 0, {"kind": "no", "operand": "I4"})
	r.set_coil(7, {"kind": "reset", "operand": "T2"})
	r.set_cell(9, 0, {"kind": "no", "operand": "T1"})
	r.set_coil(9, {"kind": "coil", "operand": "Q2"})
	r.set_cell(11, 0, {"kind": "nc", "operand": "T2"})
	r.set_coil(11, {"kind": "coil_not", "operand": "M1"})
	# Edges: set on a rising edge of I5, reset on a falling one of I6.
	r.set_cell(13, 0, {"kind": "pos", "operand": "I5"})
	r.set_coil(13, {"kind": "set", "operand": "M2"})
	r.set_cell(15, 0, {"kind": "neg", "operand": "I6"})
	r.set_coil(15, {"kind": "reset", "operand": "M2"})
	# Counter C1 up on I7, down on I8, reset by I5 AND I6.
	r.set_cell(17, 0, {"kind": "no", "operand": "I7"})
	r.set_coil(17, {"kind": "count_up", "operand": "C1", "preset": 3})
	r.set_cell(19, 0, {"kind": "no", "operand": "I8"})
	r.set_coil(19, {"kind": "count_down", "operand": "C1", "preset": 3})
	r.set_cell(21, 0, {"kind": "no", "operand": "I5"})
	r.set_cell(21, 1, {"kind": "no", "operand": "I6"})
	r.set_coil(21, {"kind": "reset", "operand": "C1"})
	r.set_cell(23, 0, {"kind": "no", "operand": "C1"})
	r.set_coil(23, {"kind": "coil", "operand": "Q3"})
	# Analog: AQ1 = 800 while AI1 >= 12000, Q4 while AI2 < 5000.
	r.set_cell(25, 0, {"kind": "ge", "operand": "AI1", "value": 12000.0})
	r.set_coil(25, {"kind": "analog", "operand": "AQ1", "value": 800.0})
	r.set_cell(27, 0, {"kind": "lt", "operand": "AI2", "value": 5000.0})
	r.set_coil(27, {"kind": "coil", "operand": "Q4"})
	assert_eq(_run_both(_cpu(p), 3000, 2), "")


func test_network_inputs_become_variables_with_a_warning() -> void:
	var p: PlcProgram = PlcProgram.new()
	var ni: PlcBlock = p.add_block("network_input", Vector2i.ZERO)
	var q1: PlcBlock = p.add_block("output", Vector2i(4, 0))
	q1.inputs[0] = ni.id
	p.set_network_source("NI1", "192.168.0.2", "Q1")
	var result: Dictionary = SclExport.export(_cpu(p))
	assert_string_contains(result["text"], "NI1 : Bool;")
	assert_eq((result["warnings"] as Array).size(), 1)
	assert_eq(_run_both(_cpu(p), 50, 3), "")


func test_operands_the_cpu_lacks_are_errors() -> void:
	var p: PlcProgram = PlcProgram.new()
	var q: PlcBlock = p.add_block("output", Vector2i.ZERO)
	q.operand = "Q9"
	var result: Dictionary = SclExport.export(CompactPlc.new("A1", p, [], CompactPlc.Cpu.DI8_DQ6))
	assert_eq(result["text"], "")
	assert_eq(result["errors"], [["%s is not on this CPU or its modules.", ["Q9"]]])


# --- Random programs --------------------------------------------------------------

func test_random_function_block_diagrams() -> void:
	var types: PackedStringArray = ["input", "output", "flag", "hi", "lo", "and", "or", "not", "nand", "nor", "xor", "on_delay", "off_delay", "latch", "pulse_relay", "counter", "analog_input", "analog_output", "analog_threshold", "analog_compare", "analog_amplifier"]
	for seed: int in 40:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 1000 + seed
		var p: PlcProgram = PlcProgram.new()
		for k: int in rng.randi_range(4, 30):
			var b: PlcBlock = p.add_block(types[rng.randi_range(0, types.size() - 1)], Vector2i(0, 4 * k))
			match b.type:
				"input":
					b.operand = "I%d" % rng.randi_range(1, 8)
				"output":
					b.operand = "Q%d" % rng.randi_range(1, 6)
				"flag":
					b.operand = "M%d" % rng.randi_range(1, 16)
				"analog_input":
					b.operand = "AI%d" % rng.randi_range(1, 2)
				"analog_output":
					b.operand = "AQ%d" % rng.randi_range(1, 2)
			b.time = rng.randi_range(0, 40) * 0.01
			b.preset = rng.randi_range(1, 4)
			b.gain = rng.randf_range(-2.0, 2.0)
			b.offset = rng.randf_range(-3000.0, 3000.0)
			b.on = rng.randf_range(0.0, 27648.0)
			b.off = rng.randf_range(0.0, 27648.0)
		for b: PlcBlock in p.blocks:
			for pin: int in b.inputs.size():
				if rng.randf() < 0.75:
					b.inputs[pin] = p.blocks[rng.randi_range(0, p.blocks.size() - 1)].id
		var result: String = _run_both(_cpu(p), 600, seed)
		assert_eq(result, "", "random FBD %d" % seed)
		if not result.is_empty():
			print(SclExport.export(_cpu(p))["text"])
			return


func test_random_ladder_diagrams() -> void:
	var cells: PackedStringArray = ["", "wire", "wire", "no", "no", "nc", "pos", "neg", "ge", "lt"]
	var coils: PackedStringArray = ["coil", "coil_not", "set", "reset", "on_delay", "off_delay", "count_up", "count_down", "analog"]
	for seed: int in 40:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 2000 + seed
		var p: PlcProgram = PlcProgram.new()
		p.language = PlcProgram.Language.LAD
		var r: PlcRung = p.ladder()
		var rows: int = rng.randi_range(1, 14)
		r.ensure_rows(rows)
		for row: int in rows:
			for c: int in PlcRung.COLUMNS:
				var kind: String = cells[rng.randi_range(0, cells.size() - 1)]
				var cell: Dictionary = {} if kind.is_empty() else {"kind": kind}
				if kind in ["no", "nc", "pos", "neg"]:
					var area: String = "IIIQMTC"[rng.randi_range(0, 6)]
					var top: int = {"I": 8, "Q": 6, "M": 16, "T": 4, "C": 3}[area]
					cell["operand"] = "%s%d" % [area, rng.randi_range(1, top)]
				elif kind in ["ge", "lt"]:
					cell["operand"] = "AI%d" % rng.randi_range(1, 2)
					cell["value"] = float(rng.randi_range(0, 27648))
				r.set_cell(row, c, cell)
				if row < rows - 1 and rng.randf() < 0.15:
					r.set_link(row, c, true)
			if rng.randf() < 0.8:
				var kind: String = coils[rng.randi_range(0, coils.size() - 1)]
				var coil: Dictionary = {"kind": kind}
				match kind:
					"coil", "coil_not", "set":
						coil["operand"] = "Q%d" % rng.randi_range(1, 6) if rng.randf() < 0.5 else "M%d" % rng.randi_range(1, 16)
					"reset":
						coil["operand"] = ["Q%d" % rng.randi_range(1, 6), "M%d" % rng.randi_range(1, 16), "T%d" % rng.randi_range(1, 4), "C%d" % rng.randi_range(1, 3)][rng.randi_range(0, 3)]
					"on_delay":
						# T1, T2 on-delays, T3, T4 off-delays: one kind each.
						coil["operand"] = "T%d" % rng.randi_range(1, 2)
						coil["time"] = rng.randi_range(0, 40) * 0.01
					"off_delay":
						coil["operand"] = "T%d" % rng.randi_range(3, 4)
						coil["time"] = rng.randi_range(0, 40) * 0.01
					"count_up", "count_down":
						coil["operand"] = "C%d" % rng.randi_range(1, 3)
						coil["preset"] = rng.randi_range(1, 4)
					"analog":
						coil["operand"] = "AQ%d" % rng.randi_range(1, 2)
						coil["value"] = float(rng.randi_range(0, 27648))
				r.set_coil(row, coil)
		var result: String = _run_both(_cpu(p), 600, seed)
		assert_eq(result, "", "random LAD %d" % seed)
		if not result.is_empty():
			print(SclExport.export(_cpu(p))["text"])
			return


func test_saved_file_and_the_plc_window() -> void:
	var p: PlcProgram = PlcProgram.new()
	var i1: PlcBlock = p.add_block("input", Vector2i.ZERO)
	var q1: PlcBlock = p.add_block("output", Vector2i(4, 0))
	q1.inputs[0] = i1.id
	var path: String = OS.get_user_data_dir().path_join("scl_export_test.scl")
	var result: Dictionary = SclExport.save(_cpu(p), path)
	assert_eq(result["saved"], OK)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	assert_eq(bytes.slice(0, 3), PackedByteArray([0xEF, 0xBB, 0xBF]), "UTF-8 with a byte order mark")
	var text: String = bytes.slice(3).get_string_from_utf8()
	assert_true(text.contains("\r\n"), "Windows line ends")
	assert_eq(SclRunner.new(text).error, "")
	DirAccess.remove_absolute(path)
	# The window saves the program it shows.
	var window: PlcWindow = PlcWindow.new("A1")
	window.bind(_cpu(p), false)
	add_child_autofree(window)
	await wait_process_frames(2)
	assert_false(window._scl_button.disabled)
	window.export_scl(path.get_basename())
	assert_true(FileAccess.file_exists(path), ".scl added to the name")
	DirAccess.remove_absolute(path)
	var logic: PlcWindow = PlcWindow.new("A2")
	logic.bind(Plc.new("A2", p), false)
	add_child_autofree(logic)
	await wait_process_frames(2)
	assert_true(logic._scl_button.disabled, "for the compact CPU only")
