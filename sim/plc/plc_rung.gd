class_name PlcRung
extends RefCounted
## One network of a ladder diagram (LAD): rows of [constant COLUMNS] cells
## between the left power rail and a coil at the end of each row. A cell is
## empty, a wire or a contact (NO -| |- or NC -|/|- of an operand I, Q, M,
## T or C); a vertical link at the right side of a cell joins its row with the
## row below (parallel branches). Coils as in Siemens ladder diagrams:
## -( )- assignment, -(S)- set, -(R)- reset (also of a timer or counter),
## -(SD)- on-delay timer, -(SF)- off-delay timer, -(CU)- / -(CD)- counting up
## and down with the counter's preset.
##
## Cells and coils are Dictionaries: {} for empty, {"kind": "wire"},
## {"kind": "no" / "nc", "operand": "I1"}; coils {"kind": "coil", "operand":
## "Q1"} plus "time" (timer coils, seconds) or "preset" (counter coils).

const COLUMNS: int = 8
## Most rows of one network.
const MAX_ROWS: int = 16
const CELL_KINDS: PackedStringArray = ["wire", "no", "nc"]
const COIL_KINDS: PackedStringArray = ["coil", "set", "reset", "on_delay", "off_delay", "count_up", "count_down"]

var _cells: Array[Dictionary] = []
## One per cell: 1 where a vertical link joins the right side of the cell
## with the row below.
var _links: PackedByteArray = PackedByteArray()
var _coils: Array[Dictionary] = []


func _init() -> void:
	add_row()


func row_count() -> int:
	return _coils.size()


func add_row() -> void:
	if row_count() >= MAX_ROWS:
		return
	for c: int in COLUMNS:
		_cells.append({})
	_links.resize(_links.size() + COLUMNS)
	_coils.append({})


func remove_row(row: int) -> void:
	if row < 0 or row >= row_count() or row_count() <= 1:
		return
	for c: int in COLUMNS:
		_cells.remove_at(row * COLUMNS)
		_links.remove_at(row * COLUMNS)
	_coils.remove_at(row)
	if row == row_count():
		# The links of the new last row lead nowhere.
		for c: int in COLUMNS:
			_links[(row - 1) * COLUMNS + c] = 0


## Rows until [param rows] exist (at most [constant MAX_ROWS]).
func ensure_rows(rows: int) -> void:
	while row_count() < mini(rows, MAX_ROWS):
		add_row()


## Drops empty rows at the bottom (one row always stays).
func trim() -> void:
	while row_count() > 1 and is_row_empty(row_count() - 1) and (row_count() < 2 or not _row_has_links(row_count() - 2)):
		remove_row(row_count() - 1)


func is_row_empty(row: int) -> bool:
	if not _coils[row].is_empty():
		return false
	for c: int in COLUMNS:
		if not _cells[row * COLUMNS + c].is_empty() or _links[row * COLUMNS + c] != 0:
			return false
	return true


func is_empty() -> bool:
	for r: int in row_count():
		if not is_row_empty(r):
			return false
	return true


func get_cell(row: int, column: int) -> Dictionary:
	return _cells[row * COLUMNS + column]


func set_cell(row: int, column: int, cell: Dictionary) -> void:
	ensure_rows(row + 1)
	if row < row_count():
		_cells[row * COLUMNS + column] = cell


func has_link(row: int, column: int) -> bool:
	return row < row_count() - 1 and _links[row * COLUMNS + column] != 0


## Links the right side of cell ([param row], [param column]) with the row
## below.
func set_link(row: int, column: int, on: bool) -> void:
	ensure_rows(row + 2)
	if row < row_count() - 1:
		_links[row * COLUMNS + column] = 1 if on else 0


func get_coil(row: int) -> Dictionary:
	return _coils[row]


func set_coil(row: int, coil: Dictionary) -> void:
	ensure_rows(row + 1)
	if row < row_count():
		_coils[row] = coil


## Fills the empty cells left of the coil of [param row] with wire, back to
## the nearest element or branch, so a coil placed at the end of a row is
## joined to what is drawn before it.
func wire_to_coil(row: int) -> void:
	# First column of the empty run before the coil.
	var start: int = COLUMNS
	while start > 0 and get_cell(row, start - 1).is_empty() and not _joined_right(row, start - 1):
		start -= 1
	if start == 0 and row > 0:
		# Nothing drawn in this row yet: no wire from the power rail, the row
		# may become a branch.
		return
	for c: int in range(start, COLUMNS):
		_cells[row * COLUMNS + c] = {"kind": "wire"}


## True when a vertical link meets the right side of cell ([param row],
## [param column]), from this row or from the row above.
func _joined_right(row: int, column: int) -> bool:
	return has_link(row, column) or (row > 0 and has_link(row - 1, column))


## Areas of the operands a cell or coil kind can name ("IQMTC" ...).
static func operand_areas(kind: String) -> String:
	match kind:
		"no", "nc":
			return "IQMTC"
		"coil", "set":
			return "QM"
		"reset":
			return "QMTC"
		"on_delay", "off_delay":
			return "T"
		"count_up", "count_down":
			return "C"
	return ""


func _row_has_links(row: int) -> bool:
	for c: int in COLUMNS:
		if _links[row * COLUMNS + c] != 0:
			return true
	return false


func to_data() -> Dictionary:
	var rows: Array[Dictionary] = []
	for r: int in row_count():
		var cells: Array = []
		for c: int in COLUMNS:
			var cell: Dictionary = get_cell(r, c)
			cells.append(null if cell.is_empty() else cell.duplicate())
		var row: Dictionary = {"cells": cells}
		var links: Array[int] = []
		for c: int in COLUMNS:
			if has_link(r, c):
				links.append(c)
		if not links.is_empty():
			row["links"] = links
		if not _coils[r].is_empty():
			row["coil"] = _coils[r].duplicate()
		rows.append(row)
	return {"rows": rows}


## A network from saved data; invalid cells, coils and links are left out.
static func from_data(d: Variant) -> PlcRung:
	var rung: PlcRung = PlcRung.new()
	if not (d is Dictionary) or not ((d as Dictionary).get("rows", null) is Array):
		return rung
	var rows: Array = (d as Dictionary)["rows"]
	rung.ensure_rows(rows.size())
	for r: int in mini(rows.size(), MAX_ROWS):
		if not (rows[r] is Dictionary):
			continue
		var row: Dictionary = rows[r]
		var cells: Variant = row.get("cells", [])
		if cells is Array:
			for c: int in mini((cells as Array).size(), COLUMNS):
				rung._cells[r * COLUMNS + c] = _valid_cell(cells[c])
		rung._coils[r] = _valid_coil(row.get("coil", null))
		var links: Variant = row.get("links", [])
		if links is Array and r < rows.size() - 1:
			for c: Variant in links:
				if (c is int or c is float) and int(c) >= 0 and int(c) < COLUMNS:
					rung._links[r * COLUMNS + int(c)] = 1
	return rung


static func _valid_cell(d: Variant) -> Dictionary:
	if not (d is Dictionary):
		return {}
	var kind: String = str((d as Dictionary).get("kind", ""))
	if kind == "wire":
		return {"kind": "wire"}
	if kind != "no" and kind != "nc":
		return {}
	var op: String = str((d as Dictionary).get("operand", ""))
	return {"kind": kind, "operand": op} if PlcProgram.valid_operand(op, operand_areas(kind)) else {}


static func _valid_coil(d: Variant) -> Dictionary:
	if not (d is Dictionary):
		return {}
	var data: Dictionary = d
	var kind: String = str(data.get("kind", ""))
	var op: String = str(data.get("operand", ""))
	if not COIL_KINDS.has(kind) or not PlcProgram.valid_operand(op, operand_areas(kind)):
		return {}
	var coil: Dictionary = {"kind": kind, "operand": op}
	if kind == "on_delay" or kind == "off_delay":
		var t: Variant = data.get("time", PlcBlock.DEFAULT_TIME)
		coil["time"] = clampf(float(t), 0.0, PlcBlock.MAX_TIME) if (t is int or t is float) else PlcBlock.DEFAULT_TIME
	elif kind == "count_up" or kind == "count_down":
		var p: Variant = data.get("preset", PlcBlock.DEFAULT_PRESET)
		coil["preset"] = clampi(int(p), 1, PlcCounter.MAX_VALUE) if (p is int or p is float) else PlcBlock.DEFAULT_PRESET
	return coil
