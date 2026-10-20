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
##
## Network inputs NI1-NI64 and network analog inputs NAI1-NAI32 read an
## operand of another PLC over Ethernet, as on the real logic modules: each
## names its partner by IP address and the operand read there ([member
## network]: I, Q or M of the partner for an NI, AI or AQ for an NAI). They
## are 0 while the partner cannot be reached.

enum Language { FBD, LAD }

const LANGUAGE_NAMES: PackedStringArray = ["fbd", "lad"]
## Count of each operand area: enough for the largest compact CPU with all
## its signal modules ([constant CompactPlc.CPU_MAX_INPUTS] ...); a PLC uses
## those it has.
const AREA_SIZES: Dictionary[String, int] = {"I": 80, "Q": 80, "M": 16, "T": 16, "C": 16, "AI": 40, "AQ": 16, "NI": 64, "NAI": 32}
## Areas holding analog values.
const ANALOG_AREAS: PackedStringArray = ["AI", "AQ", "NAI"]
## Areas named by more than one letter, the longest first: an areas string
## is read from the left, one of these where it starts there, else a letter.
const LONG_AREAS: PackedStringArray = ["NAI", "NI", "AI", "AQ"]
## Areas of the partner's operands a network input may read.
const REMOTE_AREAS: Dictionary[String, String] = {"NI": "IQM", "NAI": "AIAQ"}
## Most blocks of a function block diagram.
const MAX_BLOCKS: int = 200

var language: Language = Language.FBD
var blocks: Array[PlcBlock] = []
var rungs: Array[PlcRung] = []
## Where each network input reads: "NI1" -> {"ip": "192.168.0.2",
## "operand": "Q1"}; network inputs not in it read nothing.
var network: Dictionary[String, Dictionary] = {}


## True if [param operand] is an operand of one of the [param areas]
## ("IQM" ..., or "AI"), e.g. "I3", "M12" or "AI2".
static func valid_operand(operand: String, areas: String) -> bool:
	var area: String = area_of(operand)
	var number: String = operand.substr(area.length())
	# Plain digits only: no sign ("I+1") and no leading zero ("I01").
	if area.is_empty() or not area_list(areas).has(area) or not number.is_valid_int() or str(int(number)) != number:
		return false
	return int(number) >= 1 and int(number) <= AREA_SIZES[area]


## The areas of an areas string: "IQM" -> I, Q, M; "AI" -> AI; "IQMNI" ->
## I, Q, M, NI.
static func area_list(areas: String) -> PackedStringArray:
	var list: PackedStringArray = PackedStringArray()
	var i: int = 0
	while i < areas.length():
		var area: String = areas[i]
		for long: String in LONG_AREAS:
			if areas.substr(i, long.length()) == long:
				area = long
				break
		list.append(area)
		i += area.length()
	return list


## Area of an operand: "I", "Q", "AI", "NI" ... ("" when it is none).
static func area_of(operand: String) -> String:
	for area: String in LONG_AREAS:
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


## True for an IPv4 address written as four numbers 0-255 ("192.168.0.1").
static func valid_ip(ip: String) -> bool:
	var parts: PackedStringArray = ip.split(".")
	if parts.size() != 4:
		return false
	for part: String in parts:
		if not part.is_valid_int() or str(int(part)) != part or int(part) < 0 or int(part) > 255:
			return false
	return true


## Where network input [param operand] ("NI3", "NAI1") reads: {"ip",
## "operand"}; empty when it is not set.
func network_source(operand: String) -> Dictionary:
	return network.get(operand, {})


## Network input [param operand] reads [param remote] ("Q1", "AQ2") of the
## PLC at [param ip]; an empty ip clears it.
func set_network_source(operand: String, ip: String, remote: String) -> void:
	if ip.is_empty():
		network.erase(operand)
	elif _valid_source(operand, ip, remote):
		network[operand] = {"ip": ip, "operand": remote}


static func _valid_source(operand: String, ip: String, remote: String) -> bool:
	var area: String = area_of(operand)
	return REMOTE_AREAS.has(area) and valid_operand(operand, area) and valid_ip(ip) and valid_operand(remote, REMOTE_AREAS[area])


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
	var sources: Dictionary = {}
	for operand: String in network:
		sources[operand] = network[operand].duplicate()
	return {"language": LANGUAGE_NAMES[language], "blocks": block_data, "rungs": rung_data, "network": sources}


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
	var raw_network: Variant = data.get("network", {})
	if raw_network is Dictionary:
		for key: Variant in raw_network:
			var source: Variant = raw_network[key]
			if source is Dictionary:
				program.set_network_source(str(key), str(source.get("ip", "")), str(source.get("operand", "")))
	return program


## The ladder diagram (made when there is none yet).
func ladder() -> PlcRung:
	if rungs.is_empty():
		rungs.append(PlcRung.new())
	return rungs[0]


func duplicate_program() -> PlcProgram:
	return from_data(to_data())
