class_name PlcProgram
extends RefCounted
## Program of a small PLC (logic module): a function block diagram (FBD) or a
## ladder diagram (LAD), as in the programming software of small Siemens
## PLCs. Both are kept; [member language] tells which one the PLC runs.
##
## Operands: inputs I1-I80, outputs Q1-Q80 (as many as the [Plc] has with its
## modules), flags M1-M16, analog inputs AI1-AI40 and analog outputs
## AQ1-AQ16 (values 0-1000 for 0-10 V, 0-27648 on the compact CPUs); the
## ladder diagram
## also has timers T1-T16 and counters C1-C16 (the function block diagram
## has its timers and counters in its blocks). Design data only: the
## [PlcRuntime] of the [Plc] runs it.

enum Language { FBD, LAD }

const LANGUAGE_NAMES: PackedStringArray = ["fbd", "lad"]
## Count of each operand area: enough for the largest compact CPU with all
## its signal modules ([constant CompactPlc.CPU_MAX_INPUTS] ...); a PLC uses
## those it has.
const AREA_SIZES: Dictionary[String, int] = {"I": 80, "Q": 80, "M": 16, "T": 16, "C": 16, "AI": 40, "AQ": 16}
## Areas named by two letters: an areas string that is one of them means it
## alone (else every letter of it is an area).
const ANALOG_AREAS: PackedStringArray = ["AI", "AQ"]
## Most blocks of a function block diagram.
const MAX_BLOCKS: int = 200

var language: Language = Language.FBD
var blocks: Array[PlcBlock] = []
var rungs: Array[PlcRung] = []


## True if [param operand] is an operand of one of the [param areas]
## ("IQM" ..., or "AI"), e.g. "I3", "M12" or "AI2".
static func valid_operand(operand: String, areas: String) -> bool:
	var area: String = area_of(operand)
	var number: String = operand.substr(area.length())
	if area.is_empty() or not area_list(areas).has(area) or not number.is_valid_int() or number.begins_with("0"):
		return false
	return int(number) >= 1 and int(number) <= AREA_SIZES[area]


## The areas of an areas string: "IQM" -> I, Q, M; "AI" -> AI.
static func area_list(areas: String) -> PackedStringArray:
	if ANALOG_AREAS.has(areas):
		return PackedStringArray([areas])
	var list: PackedStringArray = PackedStringArray()
	for area: String in areas:
		list.append(area)
	return list


## Area of an operand: "I", "Q", "AI" ... ("" when it is none).
static func area_of(operand: String) -> String:
	for area: String in ANALOG_AREAS:
		if operand.begins_with(area):
			return area
	return operand.left(1) if AREA_SIZES.has(operand.left(1)) else ""


## Every operand of [param areas], in order: "I1".."I24", "Q1"...
static func operands(areas: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for area: String in area_list(areas):
		for n: int in AREA_SIZES.get(area, 0):
			result.append("%s%d" % [area, n + 1])
	return result


## Index (0-based) of an operand within its area: "Q3" -> 2, "AI2" -> 1.
static func operand_index(operand: String) -> int:
	return int(operand.substr(area_of(operand).length())) - 1


func block(id: int) -> PlcBlock:
	for b: PlcBlock in blocks:
		if b.id == id:
			return b
	return null


## Number for a new block: one above the highest.
func next_block_id() -> int:
	var highest: int = 0
	for b: PlcBlock in blocks:
		highest = maxi(highest, b.id)
	return highest + 1


## Adds a block of [param type] at [param cell]; returns it (null when the
## diagram is full).
func add_block(type: String, cell: Vector2i) -> PlcBlock:
	if blocks.size() >= MAX_BLOCKS or not PlcBlock.TYPES.has(type):
		return null
	var b: PlcBlock = PlcBlock.new(next_block_id(), type, cell)
	blocks.append(b)
	return b


## Removes block [param id] and every connection from it.
func remove_block(id: int) -> void:
	for i: int in range(blocks.size() - 1, -1, -1):
		if blocks[i].id == id:
			blocks.remove_at(i)
	for b: PlcBlock in blocks:
		for p: int in b.inputs.size():
			if b.inputs[p] == id:
				b.inputs[p] = 0


## True when the program in [member language] has nothing in it.
func is_empty() -> bool:
	if language == Language.FBD:
		return blocks.is_empty()
	for rung: PlcRung in rungs:
		if not rung.is_empty():
			return false
	return true


func to_data() -> Dictionary:
	var block_data: Array[Dictionary] = []
	for b: PlcBlock in blocks:
		block_data.append(b.to_data())
	var rung_data: Array[Dictionary] = []
	for rung: PlcRung in rungs:
		rung_data.append(rung.to_data())
	return {"language": LANGUAGE_NAMES[language], "blocks": block_data, "rungs": rung_data}


## A program from saved data. Malformed parts are left out (a block with a
## number already used, connections to missing blocks), so a damaged program
## never stops a schematic from loading.
static func from_data(d: Variant) -> PlcProgram:
	var program: PlcProgram = PlcProgram.new()
	if not (d is Dictionary):
		return program
	var data: Dictionary = d
	program.language = maxi(LANGUAGE_NAMES.find(str(data.get("language", "fbd"))), 0) as Language
	var raw_blocks: Variant = data.get("blocks", [])
	if raw_blocks is Array:
		for bd: Variant in raw_blocks:
			var b: PlcBlock = PlcBlock.from_data(bd)
			if b != null and program.block(b.id) == null and program.blocks.size() < MAX_BLOCKS:
				program.blocks.append(b)
	for b: PlcBlock in program.blocks:
		for p: int in b.inputs.size():
			if program.block(b.inputs[p]) == null:
				b.inputs[p] = 0
	# One ladder along one power rail: networks of older programs follow
	# one another.
	var raw_rungs: Variant = data.get("rungs", [])
	if raw_rungs is Array:
		for rd: Variant in raw_rungs:
			var rung: PlcRung = PlcRung.from_data(rd)
			if program.rungs.is_empty():
				program.rungs.append(rung)
			elif not rung.is_empty():
				program.rungs[0].append(rung)
	return program


## The ladder diagram (made when there is none yet).
func ladder() -> PlcRung:
	if rungs.is_empty():
		rungs.append(PlcRung.new())
	return rungs[0]


func duplicate_program() -> PlcProgram:
	return from_data(to_data())
