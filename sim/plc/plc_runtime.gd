class_name PlcRuntime
extends RefCounted
## Runs a [PlcProgram]: one [method scan] reads the input image, works through
## the program and writes the outputs, flags, timers and counters, like one
## cycle of a PLC. The time between scans comes from [method advance].
##
## Function block diagram: the blocks are worked through in signal order
## (a block after the blocks that feed it); where outputs are fed back (a
## loop) the block with the lowest number goes first and reads the value the
## other blocks had in the scan before. Basic functions without any connected
## input give 0; unconnected inputs of AND / NAND count as 1, of the others
## as 0.
##
## Ladder diagram: the rungs (rows joined by vertical links, see
## [method PlcRung.rung_groups]) are worked through from the top; in each,
## power flows from the left rail column by column through closed contacts
## and wires, vertical links join the rows they connect; each row's coil gets
## what reaches the end of its row. Coils act at once, so the rungs below see
## the new values in the same scan. Edge contacts -|P|- / -|N|- close for one
## scan when their operand went from 0 to 1 / from 1 to 0.
##
## Analog values run 0-[member full_scale] for 0-10 V: [member analog_inputs] are read,
## [member analog_outputs] written by the AQ connectors and AQ coils; the
## comparing contacts read the analog inputs.

## Scans [method scan_until_stable] makes at most.
const MAX_SCANS: int = 32

var program: PlcProgram
## Process image of the inputs I1-I24 (1 = voltage on the input).
var inputs: PackedByteArray = PackedByteArray()
var outputs: PackedByteArray = PackedByteArray()
var flags: PackedByteArray = PackedByteArray()
## Analog inputs AI1-AI8 (0-1000 for 0-10 V) and outputs AQ1-AQ8.
var analog_inputs: PackedFloat32Array = PackedFloat32Array()
var analog_outputs: PackedFloat32Array = PackedFloat32Array()
## Value for 10 V (1000 for the logic modules, 27648 for the compact CPUs).
var full_scale: float = PlcBlock.ANALOG_MAX
## Function block diagram: output of every block after the last scan, and
## the value of blocks with an analog output.
var values: Dictionary[int, bool] = {}
var analog: Dictionary[int, float] = {}
## Timers: "T1".. of the ladder diagram, "B3" (the block) of the function
## block diagram; counters alike.
var timers: Dictionary[String, PlcTimer] = {}
var counters: Dictionary[String, PlcCounter] = {}
## Ladder diagram, for showing the power flow: per network, 1 where power
## reaches the right side of a cell (row * COLUMNS + column), and per row,
## whether its coil gets power.
var rung_power: Array[PackedByteArray] = []
var coil_power: Array[PackedByteArray] = []

## Latching and pulse relays of the function block diagram (by block number)
## and the last value of their edge-triggered inputs.
var _states: Dictionary[int, bool] = {}
var _edges: Dictionary[int, bool] = {}
## Ladder diagram: the operand of each edge contact in the scan before
## ("rung:row:column").
var _cell_edges: Dictionary[String, bool] = {}
## Order in which the blocks are worked through (block numbers).
var _order: PackedInt32Array = PackedInt32Array()


func _init(p_program: PlcProgram) -> void:
	program = p_program
	reset()


## Everything back to 0 (the PLC lost its power).
func reset() -> void:
	inputs.resize(PlcProgram.AREA_SIZES["I"])
	inputs.fill(0)
	outputs.resize(PlcProgram.AREA_SIZES["Q"])
	outputs.fill(0)
	flags.resize(PlcProgram.AREA_SIZES["M"])
	flags.fill(0)
	analog_inputs.resize(PlcProgram.AREA_SIZES["AI"])
	analog_inputs.fill(0.0)
	analog_outputs.resize(PlcProgram.AREA_SIZES["AQ"])
	analog_outputs.fill(0.0)
	values.clear()
	analog.clear()
	timers.clear()
	counters.clear()
	_states.clear()
	_edges.clear()
	_cell_edges.clear()
	rung_power.clear()
	coil_power.clear()
	_order = _signal_order()


## One program cycle.
func scan() -> void:
	if program.language == PlcProgram.Language.FBD:
		_scan_fbd()
	else:
		_scan_lad()


## Scans until a scan changes nothing (at most [param limit] scans). Returns
## false when the program kept changing (it switches itself on and off).
func scan_until_stable(limit: int = MAX_SCANS) -> bool:
	for i: int in limit:
		var before: Array = snapshot()
		scan()
		if snapshot() == before:
			return true
	return false


## Moves the running timers on by [param delta] seconds.
func advance(delta: float) -> void:
	for timer: PlcTimer in timers.values():
		timer.advance(delta)


## Seconds until a running timer ends, INF when none runs.
func time_to_next_timer() -> float:
	var soonest: float = INF
	for timer: PlcTimer in timers.values():
		soonest = minf(soonest, timer.time_left())
	return soonest


## State that a scan may change: outputs, flags, block outputs, relays,
## timers and counters.
func snapshot() -> Array:
	var block_values: PackedByteArray = PackedByteArray()
	for id: int in _order:
		block_values.append(1 if values.get(id, false) else 0)
		block_values.append(1 if _states.get(id, false) else 0)
	var timer_states: PackedByteArray = PackedByteArray()
	for key: String in timers:
		timer_states.append((1 if timers[key].running else 0) | (2 if timers[key].output else 0))
	var counts: PackedInt32Array = PackedInt32Array()
	for key: String in counters:
		counts.append(counters[key].value)
	var edges: PackedByteArray = PackedByteArray()
	for id: int in _edges:
		edges.append(1 if _edges[id] else 0)
	for key: String in _cell_edges:
		edges.append(1 if _cell_edges[key] else 0)
	var analog_values: PackedFloat32Array = PackedFloat32Array()
	for id: int in _order:
		analog_values.append(analog.get(id, 0.0))
	return [outputs.duplicate(), flags.duplicate(), block_values, timer_states, counts, edges, analog_outputs.duplicate(), analog_values]


## Value of operand [param operand] ("I1", "Q2", "M3", "T4", "C5").
func operand_value(operand: String) -> bool:
	var i: int = PlcProgram.operand_index(operand)
	match operand.left(1):
		"I":
			return i < inputs.size() and inputs[i] != 0
		"Q":
			return i < outputs.size() and outputs[i] != 0
		"M":
			return i < flags.size() and flags[i] != 0
		"T":
			return timers.has(operand) and timers[operand].output
		"C":
			return counters.has(operand) and counters[operand].output()
	return false


## Value of analog operand [param operand] ("AI1", "AQ2").
func analog_value(operand: String) -> float:
	var i: int = PlcProgram.operand_index(operand)
	match PlcProgram.area_of(operand):
		"AI":
			return analog_inputs[i] if i >= 0 and i < analog_inputs.size() else 0.0
		"AQ":
			return analog_outputs[i] if i >= 0 and i < analog_outputs.size() else 0.0
	return 0.0


# --- Function block diagram ------------------------------------------------------

## Block numbers in signal order (see the class description).
func _signal_order() -> PackedInt32Array:
	var by_id: Dictionary[int, PlcBlock] = {}
	for b: PlcBlock in program.blocks:
		by_id[b.id] = b
	var ids: Array[int] = []
	ids.assign(by_id.keys())
	ids.sort()
	var waiting: Dictionary[int, int] = {}
	for id: int in ids:
		var count: int = 0
		for source: int in by_id[id].inputs:
			if source > 0 and by_id.has(source):
				count += 1
		waiting[id] = count
	var order: PackedInt32Array = PackedInt32Array()
	var done: Dictionary[int, bool] = {}
	while order.size() < ids.size():
		var next: int = -1
		for id: int in ids:
			if not done.has(id) and waiting[id] == 0:
				next = id
				break
		if next < 0:
			# A loop: the lowest number goes first.
			for id: int in ids:
				if not done.has(id):
					next = id
					break
		done[next] = true
		order.append(next)
		for id: int in ids:
			if done.has(id):
				continue
			for source: int in by_id[id].inputs:
				if source == next:
					waiting[id] -= 1
	return order


func _scan_fbd() -> void:
	if _order.size() != program.blocks.size():
		_order = _signal_order()
	for id: int in _order:
		var b: PlcBlock = program.block(id)
		if b != null:
			values[id] = _evaluate_block(b)


func _evaluate_block(b: PlcBlock) -> bool:
	var connected: bool = false
	for source: int in b.inputs:
		connected = connected or source > 0
	match b.type:
		"input":
			return operand_value(b.operand)
		"analog_input":
			analog[b.id] = analog_value(b.operand)
			return analog[b.id] > 0.0
		"analog_output":
			var value: float = clampf(_analog_pin(b, 0), 0.0, full_scale)
			analog_outputs[PlcProgram.operand_index(b.operand)] = value
			analog[b.id] = value
			return value > 0.0
		"analog_amplifier":
			analog[b.id] = clampf(b.gain * _analog_pin(b, 0) + b.offset, -PlcBlock.MAX_ANALOG, PlcBlock.MAX_ANALOG)
			return analog[b.id] > 0.0
		"analog_threshold", "analog_compare":
			var x: float = b.gain * _analog_pin(b, 0) + b.offset if b.type == "analog_threshold" else _analog_pin(b, 0) - _analog_pin(b, 1)
			var state: bool = _states.get(b.id, false)
			if b.on >= b.off:
				# Comes on above On, goes off at Off and below.
				if x > b.on:
					state = true
				elif x <= b.off:
					state = false
			else:
				# On between On and Off.
				state = x >= b.on and x < b.off
			_states[b.id] = state
			return state
		"hi":
			return true
		"lo":
			return false
		"output":
			var q: bool = _pin(b, 0, false)
			outputs[PlcProgram.operand_index(b.operand)] = 1 if q else 0
			return q
		"flag":
			var m: bool = _pin(b, 0, false)
			flags[PlcProgram.operand_index(b.operand)] = 1 if m else 0
			return m
		"and", "nand":
			var all: bool = connected
			for p: int in b.inputs.size():
				all = all and _pin(b, p, true)
			return all if b.type == "and" else (connected and not all)
		"or", "nor":
			var any: bool = false
			for p: int in b.inputs.size():
				any = any or _pin(b, p, false)
			return any if b.type == "or" else (connected and not any)
		"xor":
			return _pin(b, 0, false) != _pin(b, 1, false)
		"not":
			return connected and not _pin(b, 0, false)
		"on_delay", "off_delay":
			var timer: PlcTimer = _timer("B%d" % b.id, PlcTimer.Kind.ON_DELAY if b.type == "on_delay" else PlcTimer.Kind.OFF_DELAY)
			timer.preset = b.time
			timer.update(_pin(b, 0, false), b.type == "off_delay" and _pin(b, 1, false))
			return timer.output
		"latch":
			# Reset wins.
			var latched: bool = _states.get(b.id, false)
			if _pin(b, 1, false):
				latched = false
			elif _pin(b, 0, false):
				latched = true
			_states[b.id] = latched
			return latched
		"pulse_relay":
			var trigger: bool = _pin(b, 0, false)
			var rising: bool = trigger and not _edges.get(b.id, false)
			_edges[b.id] = trigger
			var state: bool = _states.get(b.id, false)
			if _pin(b, 2, false):
				state = false
			elif _pin(b, 1, false):
				state = true
			elif rising:
				state = not state
			_states[b.id] = state
			return state
		"counter":
			var counter: PlcCounter = _counter("B%d" % b.id)
			counter.preset = b.preset
			var count: bool = _pin(b, 1, false)
			var counted: bool = count and not _edges.get(b.id, false)
			_edges[b.id] = count
			if _pin(b, 0, false):
				counter.reset()
			elif counted:
				counter.value = clampi(counter.value + (-1 if _pin(b, 2, false) else 1), 0, PlcCounter.MAX_VALUE)
			return counter.output()
	return false


## Value at input pin [param pin] of [param b]: the output of the block
## connected to it, [param unconnected] when none is.
func _pin(b: PlcBlock, pin: int, unconnected: bool) -> bool:
	var source: int = b.inputs[pin] if pin < b.inputs.size() else 0
	return values.get(source, false) if source > 0 else unconnected


## Analog value at input pin [param pin] of [param b]: that of an analog
## block, 1000 or 0 from a digital one, 0 when nothing is connected.
func _analog_pin(b: PlcBlock, pin: int) -> float:
	var source: int = b.inputs[pin] if pin < b.inputs.size() else 0
	if source <= 0:
		return 0.0
	if analog.has(source):
		return analog[source]
	return full_scale if values.get(source, false) else 0.0


func _timer(key: String, kind: PlcTimer.Kind) -> PlcTimer:
	if not timers.has(key) or timers[key].kind != kind:
		timers[key] = PlcTimer.new(kind)
	return timers[key]


func _counter(key: String) -> PlcCounter:
	if not counters.has(key):
		counters[key] = PlcCounter.new()
	return counters[key]


# --- Ladder diagram ----------------------------------------------------------------

func _scan_lad() -> void:
	rung_power.resize(program.rungs.size())
	coil_power.resize(program.rungs.size())
	for n: int in program.rungs.size():
		var rung: PlcRung = program.rungs[n]
		var rows: int = rung.row_count()
		var power: PackedByteArray = PackedByteArray()
		power.resize(rows * PlcRung.COLUMNS)
		var coils: PackedByteArray = PackedByteArray()
		coils.resize(rows)
		for group: Vector2i in rung.rung_groups():
			_scan_rows(n, rung, group.x, group.y, power, coils)
		rung_power[n] = power
		coil_power[n] = coils


## Power flow through rows [param r0] to [param r1] (one rung) of ladder
## [param rung], then its coils.
func _scan_rows(n: int, rung: PlcRung, r0: int, r1: int, power: PackedByteArray, coils: PackedByteArray) -> void:
	var count: int = r1 - r0 + 1
	var left: PackedByteArray = PackedByteArray()
	left.resize(count)
	left.fill(1)
	for c: int in PlcRung.COLUMNS:
		var right: PackedByteArray = PackedByteArray()
		right.resize(count)
		for i: int in count:
			# Every cell is looked at, so edge contacts follow their operand.
			var closed: bool = _conducts(rung.get_cell(r0 + i, c), "%d:%d:%d" % [n, r0 + i, c])
			right[i] = 1 if left[i] != 0 and closed else 0
		# Rows joined by vertical links share the power at this column.
		var a: int = 0
		while a < count:
			var b: int = a
			while b < count - 1 and rung.has_link(r0 + b, c):
				b += 1
			var any: int = 0
			for i: int in range(a, b + 1):
				any |= right[i]
			for i: int in range(a, b + 1):
				right[i] = any
				power[(r0 + i) * PlcRung.COLUMNS + c] = any
			a = b + 1
		left = right
	for i: int in count:
		coils[r0 + i] = left[i]
		_apply_coil(rung.get_coil(r0 + i), left[i] != 0)


func _conducts(cell: Dictionary, place: String) -> bool:
	match str(cell.get("kind", "")):
		"wire":
			return true
		"no":
			return operand_value(cell["operand"])
		"nc":
			return not operand_value(cell["operand"])
		"pos", "neg":
			var now: bool = operand_value(cell["operand"])
			var before: bool = _cell_edges.get(place, now)
			_cell_edges[place] = now
			return now and not before if cell["kind"] == "pos" else before and not now
		"ge":
			return analog_value(cell["operand"]) >= float(cell.get("value", PlcRung.DEFAULT_VALUE))
		"lt":
			return analog_value(cell["operand"]) < float(cell.get("value", PlcRung.DEFAULT_VALUE))
	return false


func _apply_coil(coil: Dictionary, power: bool) -> void:
	if coil.is_empty():
		return
	var operand: String = coil["operand"]
	match str(coil["kind"]):
		"coil":
			_write(operand, power)
		"coil_not":
			_write(operand, not power)
		"set":
			if power:
				_write(operand, true)
		"reset":
			if power:
				match operand.left(1):
					"T":
						if timers.has(operand):
							timers[operand].reset()
					"C":
						_counter(operand).reset()
					_:
						_write(operand, false)
		"on_delay", "off_delay":
			var timer: PlcTimer = _timer(operand, PlcTimer.Kind.ON_DELAY if coil["kind"] == "on_delay" else PlcTimer.Kind.OFF_DELAY)
			timer.preset = float(coil.get("time", PlcBlock.DEFAULT_TIME))
			timer.update(power)
		"analog":
			var i: int = PlcProgram.operand_index(operand)
			analog_outputs[i] = float(coil.get("value", PlcRung.DEFAULT_VALUE)) if power else 0.0
		"count_up", "count_down":
			var counter: PlcCounter = _counter(operand)
			counter.preset = int(coil.get("preset", PlcBlock.DEFAULT_PRESET))
			if coil["kind"] == "count_up":
				counter.count_up(power)
			else:
				counter.count_down(power)


func _write(operand: String, value: bool) -> void:
	var i: int = PlcProgram.operand_index(operand)
	match operand.left(1):
		"Q":
			outputs[i] = 1 if value else 0
		"M":
			flags[i] = 1 if value else 0
