class_name PlcRung
extends RefCounted
## A ladder diagram (LAD): rows of [constant COLUMNS] cells along the left
## power rail, each with a coil at its end. A cell is empty, a wire or a
## contact (NO -| |-, NC -|/|-, rising edge -|P|-, falling edge -|N|- of an
## operand I, Q, M, T or C); a vertical link at the right side of a cell joins
## its row with the row below (parallel branches). Rows joined by links make
## one rung ([method rung_groups]). Coils as in Siemens ladder diagrams:
## -( )- assignment, -(/)- negated assignment, -(S)- set, -(R)- reset (also of
## a timer or counter), -(SD)- on-delay timer, -(SF)- off-delay timer,
## -(CU)- / -(CD)- counting up and down with the counter's preset. Analog:
## comparing contacts -[AI1 >= v]- and -[AI1 < v]- close while the analog
## input is at or above / below the value, the coil -(AQ)- puts its value
## on an analog output while it has power (0 without).
##
## Cells and coils are Dictionaries: {} for empty, {"kind": "wire"},
## {"kind": "no" / "nc", "operand": "I1"}, {"kind": "ge" / "lt", "operand":
## "AI1", "value": 500}; coils {"kind": "coil", "operand": "Q1"} plus "time"
## (timer coils, seconds), "preset" (counter coils) or "value" (AQ coils).

const COLUMNS: int = 8
## Most rows of a ladder diagram.
const MAX_ROWS: int = 256
const CELL_KINDS: PackedStringArray = ["wire", "no", "nc", "pos", "neg", "ge", "lt"]
const COIL_KINDS: PackedStringArray = ["coil", "coil_not", "set", "reset", "on_delay", "off_delay", "count_up", "count_down", "analog"]
## Value a new comparing contact or AQ coil starts with.
const DEFAULT_VALUE: float = 500.0

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


## Inserts an empty row before [param row]; links that crossed the gap are
## kept across it.
func insert_row(row: int) -> void:
	if row_count() >= MAX_ROWS or row < 0 or row > row_count():
		return
	for c: int in COLUMNS:
		_cells.insert(row * COLUMNS, {})
	var fresh: PackedByteArray = PackedByteArray()
	fresh.resize(COLUMNS)
	if row > 0:
		for c: int in COLUMNS:
			fresh[c] = _links[(row - 1) * COLUMNS + c]
	var before: PackedByteArray = _links.slice(0, row * COLUMNS)
	before.append_array(fresh)
	before.append_array(_links.slice(row * COLUMNS))
	_links = before
	_coils.insert(row, {})


## Appends the rows of [param other] below these.
func append(other: PlcRung) -> void:
	var start: int = row_count()
	if is_empty():
		start = 0
		_cells.clear()
		_links.clear()
		_coils.clear()
	for r: int in other.row_count():
		if row_count() >= MAX_ROWS:
			return
		add_row()
		for c: int in COLUMNS:
			_cells[(start + r) * COLUMNS + c] = other.get_cell(r, c).duplicate()
			_links[(start + r) * COLUMNS + c] = 1 if other.has_link(r, c) else 0
		_coils[start + r] = other.get_coil(r).duplicate()


## Rows grouped into rungs: each group is the first and the last row of rows
## joined by vertical links, top to bottom; empty rows are left out.
func rung_groups() -> Array[Vector2i]:
	var groups: Array[Vector2i] = []
	var r0: int = 0
	while r0 < row_count():
		var r1: int = r0
		while r1 < row_count() - 1 and _row_has_links(r1):
			r1 += 1
		var empty: bool = true
		for r: int in range(r0, r1 + 1):
			empty = empty and is_row_empty(r)
		if not empty:
			groups.append(Vector2i(r0, r1))
		r0 = r1 + 1
	return groups


## Removes row [param row]; a link from the row above still joins the row
## below only where the removed row's link went on down to it, so rows that
## were apart stay apart.
func remove_row(row: int) -> void:
	if row < 0 or row >= row_count() or row_count() <= 1:
		return
	if row > 0:
		for c: int in COLUMNS:
			if not has_link(row, c):
				_links[(row - 1) * COLUMNS + c] = 0
	for c: int in COLUMNS:
		_cells.remove_at(row * COLUMNS)
		_links.remove_at(row * COLUMNS)
	_coils.remove_at(row)


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
		"no", "nc", "pos", "neg":
			return "IQMTC"
		"coil", "coil_not", "set":
			return "QM"
		"reset":
			return "QMTC"
		"on_delay", "off_delay":
			return "T"
		"count_up", "count_down":
			return "C"
		"ge", "lt":
			return "AI"
		"analog":
			return "AQ"
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
	if not ["no", "nc", "pos", "neg", "ge", "lt"].has(kind):
		return {}
	var op: String = str((d as Dictionary).get("operand", ""))
	if not PlcProgram.valid_operand(op, operand_areas(kind)):
		return {}
	var cell: Dictionary = {"kind": kind, "operand": op}
	if kind == "ge" or kind == "lt":
		cell["value"] = _value(d as Dictionary)
	return cell


static func _value(d: Dictionary) -> float:
	var v: Variant = d.get("value", DEFAULT_VALUE)
	return clampf(float(v), -PlcBlock.MAX_ANALOG, PlcBlock.MAX_ANALOG) if (v is int or v is float) else DEFAULT_VALUE


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
	elif kind == "analog":
		coil["value"] = clampf(_value(data), 0.0, PlcBlock.MAX_ANALOG)
	return coil
