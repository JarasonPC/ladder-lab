class_name SclExport
extends RefCounted
## Writes the program of a compact CPU ([CompactPlc]) as an SCL source file
## for the programming software of the S7-1200 controllers it is modelled
## on (TIA Portal: Program blocks > External source files, then Generate
## blocks from source): a function block holding the program, its instance
## data block and the Main OB (OB1) calling it once a cycle. No nodes.
##
## The program does on the controller what it does in LadderLab, one scan
## per cycle: inputs, outputs and flags by the CPU's addresses (%I0.0,
## %Q0.0, %M0.0; analog values %IW64, %QW96 ... as words, 0-27648 for
## 0-10 V), timers as IEC timers (TON_TIME, TOF_TIME; RESET_TIMER where
## LadderLab resets one), counters, edges, latches and hysteresis in static
## variables of the function block. The function block diagram is worked
## through in LadderLab's signal order, each block's output a static
## variable (so a feedback loop reads the value of the cycle before, as in
## LadderLab); the ladder diagram rung by rung, power column by column
## through the cells, rows joined by links sharing it, as [PlcRuntime] does.
## Network inputs (NI, NAI) become static variables of the function block
## that LadderLab cannot fill on the controller: a warning says so.

## What is known of a ladder row's power while it is written: none, all
## (from the rail through wires only), some (in #p[i]).
const OFF: int = 0
const ON: int = 1
const SOME: int = 2
## Count of a counter at most (as [constant PlcCounter.MAX_VALUE]).
const COUNTER_MAX: int = PlcCounter.MAX_VALUE
## Block names: the function block, its instance data block.
const PREFIX: String = "LadderLab_"

var _plc: CompactPlc
var _program: PlcProgram
var _lines: PackedStringArray = PackedStringArray()
## Static variables in order: [name, type, start value or "", comment].
var _statics: Array[PackedStringArray] = []
var _declared: Dictionary[String, String] = {}
## Rows of the largest rung (temporary power of each row).
var _rows: int = 0
var _needs_edge: bool = false
var _needs_trigger: bool = false
## [English text with %s, args] each.
var _errors: Array[Array] = []
var _warnings: Array[Array] = []


## Name of the function block for PLC [param designation] ("LadderLab_A1").
static func block_name(designation: String) -> String:
	return PREFIX + designation


## The SCL source of [param plc]'s program as the PLC runs it now (its
## [member PlcProgram.language]): {"text": the file, "errors": what keeps
## it from working on the controller, "warnings": what works differently
## there; both [English text with %s, args]}. No text when there are errors.
static func export(plc: CompactPlc) -> Dictionary:
	var writer: SclExport = SclExport.new()
	writer._plc = plc
	writer._program = plc.program
	var body: PackedStringArray = writer._body()
	var text: String = "" if not writer._errors.is_empty() else writer._file(body)
	return {"text": text, "errors": writer._errors, "warnings": writer._warnings}


## Writes the SCL source of [param plc]'s program to [param path] (UTF-8 with
## a byte order mark, Windows line ends, as the programming software writes
## its own): what [method export] gives, with "saved" the file error (OK, or
## FAILED when there were errors and nothing was written).
static func save(plc: CompactPlc, path: String) -> Dictionary:
	var result: Dictionary = export(plc)
	result["saved"] = FAILED
	if (result["errors"] as Array).is_empty():
		result["saved"] = ProjectFile.write_atomically(path, String.chr(0xFEFF) + str(result["text"]))
	return result


# --- File --------------------------------------------------------------------------

func _file(body: PackedStringArray) -> String:
	var fb: String = block_name(_plc.designation)
	var out: PackedStringArray = PackedStringArray()
	out.append("// Program of PLC %s, exported by LadderLab for the S7-1200 (CPU %s, %s)." % [_plc.designation, _cpu_text(), "LAD" if _program.language == PlcProgram.Language.LAD else "FBD"])
	out.append("// TIA Portal: Program blocks > External source files > Add new external file,")
	out.append("// then right click it > Generate blocks from source. Main [OB1] calls the program.")
	out.append("")
	out.append("FUNCTION_BLOCK \"%s\"" % fb)
	out.append("{ S7_Optimized_Access := 'TRUE' }")
	out.append("VERSION : 0.1")
	out.append("   VAR ")
	for s: PackedStringArray in _statics:
		var line: String = "      %s : %s" % [s[0], s[1]]
		if not s[2].is_empty():
			line += " := " + s[2]
		line += ";"
		if not s[3].is_empty():
			line += "   // " + s[3]
		out.append(line)
	out.append("   END_VAR")
	if _rows > 0 or _needs_edge or _needs_trigger:
		out.append("")
		out.append("   VAR_TEMP ")
		if _rows > 0:
			out.append("      p : Array[0..%d] of Bool;   // power reaching the right side of each row" % (_rows - 1))
		if _needs_edge:
			out.append("      e : Bool;   // an edge contact closed")
		if _needs_trigger:
			out.append("      trg : Bool;   // a pulse relay's Trg")
		out.append("   END_VAR")
	out.append("")
	out.append("")
	out.append("BEGIN")
	for line: String in body:
		out.append(("\t" + line) if not line.is_empty() else "")
	out.append("END_FUNCTION_BLOCK")
	out.append("")
	out.append("DATA_BLOCK \"%s_DB\"" % fb)
	out.append("{ S7_Optimized_Access := 'TRUE' }")
	out.append("VERSION : 0.1")
	out.append("NON_RETAIN")
	out.append("\"%s\"" % fb)
	out.append("")
	out.append("BEGIN")
	out.append("")
	out.append("END_DATA_BLOCK")
	out.append("")
	out.append("ORGANIZATION_BLOCK \"Main\"")
	out.append("TITLE = \"Main Program Sweep (Cycle)\"")
	out.append("{ S7_Optimized_Access := 'TRUE' }")
	out.append("VERSION : 0.1")
	out.append("   VAR_INPUT ")
	out.append("      Initial_Call : Bool;   // Initial call of this OB")
	out.append("      Remanence : Bool;   // =True, if remanent data are available")
	out.append("   END_VAR")
	out.append("")
	out.append("")
	out.append("BEGIN")
	out.append("\t\"%s_DB\"();" % fb)
	out.append("END_ORGANIZATION_BLOCK")
	out.append("")
	return "\r\n".join(out)


func _cpu_text() -> String:
	return "%d DI / %d DQ" % [CompactPlc.CPU_INPUTS[_plc.cpu], CompactPlc.CPU_OUTPUTS[_plc.cpu]]


## Declares static variable [param name] once; returns it as written in
## the code ("#T1").
func _static(name: String, type: String, start: String = "", comment: String = "") -> String:
	if not _declared.has(name):
		_declared[name] = type
		_statics.append(PackedStringArray([name, type, start, comment]))
	return "#" + name


# --- Operands ----------------------------------------------------------------------

## A digital operand read, as SCL.
func _bool(operand: String) -> String:
	match PlcProgram.area_of(operand):
		"I", "Q", "M":
			return _address(operand)
		"T":
			if _declared.has(operand):
				return "#%s.Q" % operand
			return "FALSE"
		"C":
			return "(%s >= %s)" % [_counter(operand), "#" + operand + "_PV"]
		"NI":
			_network(operand)
			return _static(operand, "Bool", "", "network input: %s" % _source(operand))
	return "FALSE"


## An analog operand read, as a Real.
func _analog(operand: String) -> String:
	match PlcProgram.area_of(operand):
		"AI", "AQ":
			return "INT_TO_REAL(WORD_TO_INT(%s))" % _address(operand)
		"NAI":
			_network(operand)
			return _static(operand, "Real", "", "network analog input: %s" % _source(operand))
	return "0.0"


## A digital output or flag written.
func _write(operand: String, value: String) -> String:
	return "%s := %s;" % [_address(operand), value]


## An analog output written from a Real.
func _write_analog(operand: String, value: String) -> String:
	return "%s := INT_TO_WORD(REAL_TO_INT(%s));" % [_address(operand), value]


## The CPU's address of [param operand]; an error where the CPU and its
## modules have no such input or output.
func _address(operand: String) -> String:
	var address: String = _plc.address(operand)
	if not address.begins_with("%"):
		_error("%s is not on this CPU or its modules.", [operand])
		return "FALSE"
	return address


func _counter(operand: String) -> String:
	_static(operand + "_PV", "DInt", "1", "preset of " + operand)
	return _static(operand, "DInt", "", "count of " + operand)


func _network(operand: String) -> void:
	var key: String = "network:" + operand
	if not _declared.has(key):
		_declared[key] = ""
		var source: Dictionary = _program.network_source(operand)
		if source.is_empty():
			_warnings.append(["Network input %s has no partner and stays 0 on the controller.", [operand]])
		else:
			_warnings.append(["Network input %s stays 0 on the controller: fill the variable %s of the function block yourself, e.g. with a GET of %s from %s.", [operand, operand, source["operand"], source["ip"]]])


func _source(operand: String) -> String:
	var source: Dictionary = _program.network_source(operand)
	return "%s of %s" % [source["operand"], source["ip"]] if not source.is_empty() else "no partner set"


func _error(text: String, args: Array) -> void:
	for e: Array in _errors:
		if e[0] == text and e[1] == args:
			return
	_errors.append([text, args])


static func _time(seconds: float) -> String:
	return "T#%dMS" % roundi(seconds * 1000.0)


## A Real literal: "500.0", "(-2.5)", "0.123457" (six decimals at most,
## about what a Real of the controller holds).
static func _real(value: float) -> String:
	var text: String = String.num(value, 6)
	if not text.contains("."):
		text += ".0"
	# In brackets when negative, never two operators in a row ("a + -2.5").
	return "(%s)" % text if value < 0.0 else text


# --- Program -----------------------------------------------------------------------

func _body() -> PackedStringArray:
	if _program.language == PlcProgram.Language.FBD:
		return _fbd()
	return _lad()


## Function block diagram: each block in signal order, its output in static
## variable B001 (and B001_A, the value of a block with an analog output).
func _fbd() -> PackedStringArray:
	var body: PackedStringArray = PackedStringArray()
	if _program.blocks.is_empty():
		body.append("// The function block diagram is empty.")
		return body
	# Every block's output first, so a block fed from further on (a loop)
	# reads the value of the cycle before.
	for b: PlcBlock in _program.blocks:
		_static(b.label(), "Bool", "", b.type + (" " + b.operand if not b.operand.is_empty() else ""))
		if PlcBlock.ANALOG_OUTPUTS.has(b.type):
			_static(b.label() + "_A", "Real", "", "its value")
	var order: PackedInt32Array = PlcRuntime.new(_program).block_order()
	for id: int in order:
		var b: PlcBlock = _program.block(id)
		if b == null:
			continue
		body.append("// %s %s" % [b.label(), b.type + (" " + b.operand if not b.operand.is_empty() else "")])
		body.append_array(_block(b))
	return body


func _block(b: PlcBlock) -> PackedStringArray:
	var out: String = "#" + b.label()
	var lines: PackedStringArray = PackedStringArray()
	var connected: bool = false
	for source: int in b.inputs:
		connected = connected or source > 0
	match b.type:
		"input", "network_input":
			lines.append("%s := %s;" % [out, _bool(b.operand)])
		"analog_input", "network_analog_input":
			lines.append("%s_A := %s;" % [out, _analog(b.operand)])
			lines.append("%s := %s_A > 0.0;" % [out, out])
		"analog_output":
			lines.append("%s_A := LIMIT(MN := 0.0, IN := %s, MX := %s);" % [out, _analog_pin(b, 0), _real(_plc.full_scale())])
			lines.append(_write_analog(b.operand, out + "_A"))
			lines.append("%s := %s_A > 0.0;" % [out, out])
		"analog_amplifier":
			lines.append("%s_A := LIMIT(MN := %s, IN := %s * %s + %s, MX := %s);" % [out, _real(-PlcBlock.MAX_ANALOG), _real(b.gain), _analog_pin(b, 0), _real(b.offset), _real(PlcBlock.MAX_ANALOG)])
			lines.append("%s := %s_A > 0.0;" % [out, out])
		"analog_threshold", "analog_compare":
			var x: String = "(%s * %s + %s)" % [_real(b.gain), _analog_pin(b, 0), _real(b.offset)] if b.type == "analog_threshold" else "(%s - %s)" % [_analog_pin(b, 0), _analog_pin(b, 1)]
			if b.on >= b.off:
				lines.append("IF %s > %s THEN" % [x, _real(b.on)])
				lines.append("\t%s := TRUE;" % out)
				lines.append("ELSIF %s <= %s THEN" % [x, _real(b.off)])
				lines.append("\t%s := FALSE;" % out)
				lines.append("END_IF;")
			else:
				lines.append("%s := %s >= %s AND %s < %s;" % [out, x, _real(b.on), x, _real(b.off)])
		"hi":
			lines.append("%s := TRUE;" % out)
		"lo":
			lines.append("%s := FALSE;" % out)
		"output", "flag":
			lines.append("%s := %s;" % [out, _pin(b, 0, false)])
			lines.append(_write(b.operand, out))
		"and", "nand":
			var terms: PackedStringArray = PackedStringArray()
			for p: int in b.inputs.size():
				if b.inputs[p] > 0:
					terms.append(_pin(b, p, true))
			var all: String = " AND ".join(terms) if connected else "FALSE"
			lines.append("%s := %s;" % [out, all if b.type == "and" else ("NOT (%s)" % all if connected else "FALSE")])
		"or", "nor":
			var terms: PackedStringArray = PackedStringArray()
			for p: int in b.inputs.size():
				if b.inputs[p] > 0:
					terms.append(_pin(b, p, false))
			var any: String = " OR ".join(terms) if connected else "FALSE"
			lines.append("%s := %s;" % [out, any if b.type == "or" else ("NOT (%s)" % any if connected else "FALSE")])
		"xor":
			lines.append("%s := %s XOR %s;" % [out, _pin(b, 0, false), _pin(b, 1, false)])
		"not":
			lines.append("%s := %s;" % [out, "NOT %s" % _pin(b, 0, false) if connected else "FALSE"])
		"on_delay":
			var timer: String = _static(b.label() + "_T", "TON_TIME", "", "on-delay of " + b.label())
			lines.append("%s(IN := %s, PT := %s);" % [timer, _pin(b, 0, false), _time(b.time)])
			lines.append("%s := %s.Q;" % [out, timer])
		"off_delay":
			var timer: String = _static(b.label() + "_T", "TOF_TIME", "", "off-delay of " + b.label())
			if b.inputs[1] > 0:
				lines.append("IF %s THEN" % _pin(b, 1, false))
				lines.append("\tRESET_TIMER(%s);" % timer)
				lines.append("\t%s := FALSE;" % out)
				lines.append("ELSE")
				lines.append("\t%s(IN := %s, PT := %s);" % [timer, _pin(b, 0, false), _time(b.time)])
				lines.append("\t%s := %s.Q;" % [out, timer])
				lines.append("END_IF;")
			else:
				lines.append("%s(IN := %s, PT := %s);" % [timer, _pin(b, 0, false), _time(b.time)])
				lines.append("%s := %s.Q;" % [out, timer])
		"latch":
			# Reset wins.
			lines.append("IF %s THEN" % _pin(b, 1, false))
			lines.append("\t%s := FALSE;" % out)
			lines.append("ELSIF %s THEN" % _pin(b, 0, false))
			lines.append("\t%s := TRUE;" % out)
			lines.append("END_IF;")
		"pulse_relay":
			var edge: String = _static(b.label() + "_E", "Bool", "", "Trg in the cycle before")
			# Trg as it is before the relay switches (it may be its own output).
			_needs_trigger = true
			lines.append("#trg := %s;" % _pin(b, 0, false))
			lines.append("IF %s THEN" % _pin(b, 2, false))
			lines.append("\t%s := FALSE;" % out)
			lines.append("ELSIF %s THEN" % _pin(b, 1, false))
			lines.append("\t%s := TRUE;" % out)
			lines.append("ELSIF #trg AND NOT %s THEN" % edge)
			lines.append("\t%s := NOT %s;" % [out, out])
			lines.append("END_IF;")
			lines.append("%s := #trg;" % edge)
		"counter":
			var count: String = _static(b.label() + "_CV", "DInt", "", "count of " + b.label())
			var edge: String = _static(b.label() + "_E", "Bool", "", "Cnt in the cycle before")
			var cnt: String = _pin(b, 1, false)
			lines.append("IF %s THEN" % _pin(b, 0, false))
			lines.append("\t%s := 0;" % count)
			lines.append("ELSIF %s AND NOT %s THEN" % [cnt, edge])
			lines.append("\tIF %s THEN" % _pin(b, 2, false))
			lines.append("\t\tIF %s > 0 THEN" % count)
			lines.append("\t\t\t%s := %s - 1;" % [count, count])
			lines.append("\t\tEND_IF;")
			lines.append("\tELSIF %s < %d THEN" % [count, COUNTER_MAX])
			lines.append("\t\t%s := %s + 1;" % [count, count])
			lines.append("\tEND_IF;")
			lines.append("END_IF;")
			lines.append("%s := %s;" % [edge, cnt])
			lines.append("%s := %s >= %d;" % [out, count, maxi(b.preset, 1)])
	return lines


## Digital value at pin [param pin] of [param b]: the output of the block
## feeding it, [param unconnected] when none does.
func _pin(b: PlcBlock, pin: int, unconnected: bool) -> String:
	var source: int = b.inputs[pin] if pin < b.inputs.size() else 0
	if source <= 0:
		return "TRUE" if unconnected else "FALSE"
	return "#" + _program.block(source).label()


## Analog value at pin [param pin]: that of an analog block, full scale or
## 0 from a digital one, 0 when nothing is connected.
func _analog_pin(b: PlcBlock, pin: int) -> String:
	var source: int = b.inputs[pin] if pin < b.inputs.size() else 0
	if source <= 0:
		return "0.0"
	var from: PlcBlock = _program.block(source)
	if PlcBlock.ANALOG_OUTPUTS.has(from.type):
		return "#%s_A" % from.label()
	return "SEL(G := #%s, IN0 := 0.0, IN1 := %s)" % [from.label(), _real(_plc.full_scale())]


## Ladder diagram: every rung, power column by column (#p: what reaches the
## right side of each row's cell), rows joined by a link sharing it; then the
## coils, row by row.
func _lad() -> PackedStringArray:
	var body: PackedStringArray = PackedStringArray()
	var rung: PlcRung = _program.ladder() if not _program.rungs.is_empty() else null
	if rung == null or rung.is_empty():
		body.append("// The ladder diagram is empty.")
		return body
	# Timers by the kind of their first timer coil.
	for r: int in rung.row_count():
		var coil: Dictionary = rung.get_coil(r)
		if coil.get("kind", "") in ["on_delay", "off_delay"]:
			var type: String = "TON_TIME" if coil["kind"] == "on_delay" else "TOF_TIME"
			if _declared.has(coil["operand"]) and _declared[coil["operand"]] != type:
				_warnings.append(["Timer %s is both an on-delay and an off-delay: it is exported as the first of them.", [coil["operand"]]])
			_static(coil["operand"], type, "", "on-delay" if type == "TON_TIME" else "off-delay")
	var number: int = 0
	for group: Vector2i in rung.rung_groups():
		number += 1
		var rows: int = group.y - group.x + 1
		_rows = maxi(_rows, rows)
		body.append("// Rung %d" % number)
		# What is known of each row's power while writing: ON from the rail
		# through wires only, OFF past an empty cell, else in #p[i].
		var state: Array[int] = []
		for i: int in rows:
			state.append(ON)
		for c: int in PlcRung.COLUMNS:
			for i: int in rows:
				body.append_array(_cell(rung.get_cell(group.x + i, c), i, "E%d_%d" % [group.x + i, c], state))
			# Rows joined by vertical links share the power at this column.
			var a: int = 0
			while a < rows:
				var e: int = a
				while e < rows - 1 and rung.has_link(group.x + e, c):
					e += 1
				if e > a:
					body.append_array(_join(a, e, state))
				a = e + 1
		for i: int in rows:
			body.append_array(_coil(rung.get_coil(group.x + i), ["FALSE", "TRUE", "#p[%d]" % i][state[i]]))
		body.append("")
	if _needs_edge:
		_static("Started", "Bool", "", "the first cycle has run (no edge in it)")
		body.append("#Started := TRUE;")
	return body


## Rows [param a] to [param e] joined by links: each gets what any of them
## has.
func _join(a: int, e: int, state: Array[int]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var any: int = OFF
	var terms: PackedStringArray = PackedStringArray()
	for i: int in range(a, e + 1):
		if state[i] == ON:
			any = ON
		elif state[i] == SOME and any != ON:
			any = SOME
			terms.append("#p[%d]" % i)
	if any != SOME:
		for i: int in range(a, e + 1):
			state[i] = any
		return lines
	var first: String = terms[0]
	if terms.size() > 1:
		lines.append("%s := %s;" % [first, " OR ".join(terms)])
	for i: int in range(a, e + 1):
		if "#p[%d]" % i != first:
			lines.append("#p[%d] := %s;" % [i, first])
		state[i] = SOME
	return lines


## Row [param i]'s power through [param cell] ([param state]: what is known
## of it, see [method _lad]); edge contacts keep their operand in
## [param edge] (looked at even without power, as in LadderLab).
func _cell(cell: Dictionary, i: int, edge: String, state: Array[int]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var condition: String = ""
	match str(cell.get("kind", "")):
		"wire":
			return lines
		"no":
			condition = _bool(cell["operand"])
		"nc":
			condition = "NOT " + _bool(cell["operand"])
		"pos", "neg":
			_needs_edge = true
			var now: String = _bool(cell["operand"])
			var before: String = _static(edge, "Bool", "", "%s in the cycle before" % cell["operand"])
			if cell["kind"] == "pos":
				lines.append("#e := #Started AND %s AND NOT %s;" % [now, before])
			else:
				lines.append("#e := #Started AND %s AND NOT %s;" % [before, now])
			lines.append("%s := %s;" % [before, now])
			condition = "#e"
		"ge":
			condition = "%s >= %s" % [_analog(cell["operand"]), _real(float(cell.get("value", PlcRung.DEFAULT_VALUE)))]
		"lt":
			condition = "%s < %s" % [_analog(cell["operand"]), _real(float(cell.get("value", PlcRung.DEFAULT_VALUE)))]
		_:
			state[i] = OFF
			return lines
	var p: String = "#p[%d]" % i
	if state[i] == ON:
		lines.append("%s := %s;" % [p, condition])
		state[i] = SOME
	elif state[i] == SOME:
		lines.append("%s := %s AND %s;" % [p, p, condition])
	return lines


## A row's coil with [param power] reaching it.
func _coil(coil: Dictionary, power: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if coil.is_empty():
		return lines
	var operand: String = coil["operand"]
	match str(coil["kind"]):
		"coil":
			lines.append(_write(operand, power))
		"coil_not":
			lines.append(_write(operand, "NOT " + power))
		"set":
			lines.append("IF %s THEN" % power)
			lines.append("\t" + _write(operand, "TRUE"))
			lines.append("END_IF;")
		"reset":
			match PlcProgram.area_of(operand):
				"T":
					if _declared.has(operand):
						lines.append("IF %s THEN" % power)
						lines.append("\tRESET_TIMER(#%s);" % operand)
						lines.append("END_IF;")
				"C":
					lines.append("IF %s THEN" % power)
					lines.append("\t%s := 0;" % _counter(operand))
					lines.append("END_IF;")
				_:
					lines.append("IF %s THEN" % power)
					lines.append("\t" + _write(operand, "FALSE"))
					lines.append("END_IF;")
		"on_delay", "off_delay":
			lines.append("#%s(IN := %s, PT := %s);" % [operand, power, _time(float(coil.get("time", PlcBlock.DEFAULT_TIME)))])
		"analog":
			lines.append("IF %s THEN" % power)
			lines.append("\t" + _write_analog(operand, _real(float(coil.get("value", PlcRung.DEFAULT_VALUE)))))
			lines.append("ELSE")
			lines.append("\t" + _write_analog(operand, "0.0"))
			lines.append("END_IF;")
		"count_up", "count_down":
			var count: String = _counter(operand)
			var last: String = _static(operand + ("_CU" if coil["kind"] == "count_up" else "_CD"), "Bool", "", "count input in the cycle before")
			lines.append("#%s_PV := %d;" % [operand, maxi(int(coil.get("preset", PlcBlock.DEFAULT_PRESET)), 1)])
			if coil["kind"] == "count_up":
				lines.append("IF %s AND NOT %s AND %s < %d THEN" % [power, last, count, COUNTER_MAX])
				lines.append("\t%s := %s + 1;" % [count, count])
			else:
				lines.append("IF %s AND NOT %s AND %s > 0 THEN" % [power, last, count])
				lines.append("\t%s := %s - 1;" % [count, count])
			lines.append("END_IF;")
			lines.append("%s := %s;" % [last, power])
	return lines
