class_name PlcBlock
extends RefCounted
## One block of a function block diagram (FBD), numbered B001, B002, ... as
## in the programming software of small PLCs. Connectors bring the inputs I,
## the outputs Q and the flags M into the diagram (and hi / lo, the constant
## signals); basic functions (AND, OR, NOT, NAND, NOR, XOR) and special
## functions (on-delay, off-delay, latching relay, pulse relay, up/down
## counter) work on them. Every block has one output; each of its input pins
## takes the output of one block ([member inputs], 0 where nothing is
## connected). Outputs and flags pass their value on, so they can be fed back.
##
## Analog: connectors AI and AQ bring the analog inputs and outputs (0-1000
## for 0-10 V); the analog threshold trigger switches its digital output on
## above On and off at Off (of gain x Ax + offset), the analog comparator
## the same on the difference Ax - Ay, the analog amplifier passes gain x
## Ax + offset on. An analog pin fed by a digital block reads 0 or 1000.

## Saved block types.
const TYPES: PackedStringArray = ["input", "output", "flag", "hi", "lo", "and", "or", "not", "nand", "nor", "xor", "on_delay", "off_delay", "latch", "pulse_relay", "counter", "analog_input", "analog_output", "analog_threshold", "analog_compare", "analog_amplifier"]
## Types that bring an operand (I, Q, M, AI or AQ) into the diagram.
const CONNECTORS: PackedStringArray = ["input", "output", "flag", "hi", "lo", "analog_input", "analog_output"]
## Types whose output is an analog value.
const ANALOG_OUTPUTS: PackedStringArray = ["analog_input", "analog_output", "analog_amplifier"]
## Analog values: 0-1000 for 0-10 V.
const ANALOG_MAX: float = 1000.0
const MAX_GAIN: float = 10.0
const MAX_ANALOG: float = 32767.0
const DEFAULT_TIME: float = 3.0
const DEFAULT_PRESET: int = 5
## Longest set time in seconds.
const MAX_TIME: float = 360000.0

## Block number (B001 = 1).
var id: int
var type: String
## Position on the diagram, in grid cells (top left corner).
var cell: Vector2i = Vector2i.ZERO
## "I1", "Q2", "M3" for connectors of inputs, outputs and flags.
var operand: String = ""
## Block number feeding each input pin, 0 where nothing is connected.
var inputs: PackedInt32Array = PackedInt32Array()
## Set time of on- and off-delays, seconds.
var time: float = DEFAULT_TIME
## Count at which a counter's output comes on.
var preset: int = DEFAULT_PRESET
## Analog blocks: gain and offset of the value read, thresholds on and off.
var gain: float = 1.0
var offset: float = 0.0
var on: float = 500.0
var off: float = 400.0


func _init(p_id: int, p_type: String, p_cell: Vector2i = Vector2i.ZERO) -> void:
	id = p_id
	type = p_type
	cell = p_cell
	inputs.resize(pin_names(p_type).size())
	inputs.fill(0)
	match p_type:
		"input":
			operand = "I1"
		"output":
			operand = "Q1"
		"flag":
			operand = "M1"
		"analog_input":
			operand = "AI1"
		"analog_output":
			operand = "AQ1"


## Names of the input pins of a block type ("" for the inputs of basic
## functions, which have no names).
static func pin_names(p_type: String) -> PackedStringArray:
	match p_type:
		"output", "flag", "not", "analog_output":
			return PackedStringArray([""])
		"and", "or", "nand", "nor":
			return PackedStringArray(["", "", "", ""])
		"xor":
			return PackedStringArray(["", ""])
		"on_delay":
			return PackedStringArray(["Trg"])
		"off_delay":
			return PackedStringArray(["Trg", "R"])
		"latch":
			return PackedStringArray(["S", "R"])
		"pulse_relay":
			return PackedStringArray(["Trg", "S", "R"])
		"counter":
			return PackedStringArray(["R", "Cnt", "Dir"])
		"analog_threshold", "analog_amplifier":
			return PackedStringArray(["Ax"])
		"analog_compare":
			return PackedStringArray(["Ax", "Ay"])
	return PackedStringArray()


## Operand areas a connector may name: "I", "Q", "M" or "" (none).
static func operand_area(p_type: String) -> String:
	match p_type:
		"input":
			return "I"
		"output":
			return "Q"
		"flag":
			return "M"
		"analog_input":
			return "AI"
		"analog_output":
			return "AQ"
	return ""


## True for blocks with gain and offset (threshold trigger, amplifier).
static func uses_gain(p_type: String) -> bool:
	return p_type == "analog_threshold" or p_type == "analog_amplifier"


## True for blocks switching at thresholds On and Off.
static func uses_thresholds(p_type: String) -> bool:
	return p_type == "analog_threshold" or p_type == "analog_compare"


static func uses_time(p_type: String) -> bool:
	return p_type == "on_delay" or p_type == "off_delay"


## "B001".
func label() -> String:
	return "B%03d" % id


func to_data() -> Dictionary:
	var d: Dictionary = {"id": id, "type": type, "cell": [cell.x, cell.y]}
	if not operand_area(type).is_empty():
		d["operand"] = operand
	if not inputs.is_empty():
		d["inputs"] = Array(inputs)
	if uses_time(type):
		d["time"] = time
	if type == "counter":
		d["preset"] = preset
	if uses_gain(type):
		d["gain"] = gain
		d["offset"] = offset
	if uses_thresholds(type):
		d["on"] = on
		d["off"] = off
	return d


## A block from saved data, or null when it is not one.
static func from_data(d: Variant) -> PlcBlock:
	if not (d is Dictionary):
		return null
	var data: Dictionary = d
	var raw_id: Variant = data.get("id", 0)
	var raw_type: String = str(data.get("type", ""))
	var raw_cell: Variant = data.get("cell", [0, 0])
	if not (raw_id is int or raw_id is float) or int(raw_id) < 1 or not TYPES.has(raw_type):
		return null
	if not (raw_cell is Array and (raw_cell as Array).size() == 2 and (raw_cell[0] is int or raw_cell[0] is float) and (raw_cell[1] is int or raw_cell[1] is float)):
		return null
	var block: PlcBlock = PlcBlock.new(int(raw_id), raw_type, Vector2i(int(raw_cell[0]), int(raw_cell[1])))
	var area: String = operand_area(raw_type)
	if not area.is_empty():
		var op: String = str(data.get("operand", block.operand))
		if PlcProgram.valid_operand(op, area):
			block.operand = op
	var raw_inputs: Variant = data.get("inputs", [])
	if raw_inputs is Array:
		for i: int in mini((raw_inputs as Array).size(), block.inputs.size()):
			var source: Variant = raw_inputs[i]
			if (source is int or source is float) and int(source) > 0:
				block.inputs[i] = int(source)
	var raw_time: Variant = data.get("time", DEFAULT_TIME)
	if (raw_time is int or raw_time is float) and float(raw_time) >= 0.0:
		block.time = minf(float(raw_time), MAX_TIME)
	var raw_preset: Variant = data.get("preset", DEFAULT_PRESET)
	if raw_preset is int or raw_preset is float:
		block.preset = clampi(int(raw_preset), 1, PlcCounter.MAX_VALUE)
	block.gain = _number(data, "gain", 1.0, -MAX_GAIN, MAX_GAIN)
	block.offset = _number(data, "offset", 0.0, -MAX_ANALOG, MAX_ANALOG)
	block.on = _number(data, "on", 500.0, -MAX_ANALOG, MAX_ANALOG)
	block.off = _number(data, "off", 400.0, -MAX_ANALOG, MAX_ANALOG)
	return block


static func _number(data: Dictionary, key: String, fallback: float, low: float, high: float) -> float:
	var raw: Variant = data.get(key, fallback)
	return clampf(float(raw), low, high) if raw is int or raw is float else fallback
