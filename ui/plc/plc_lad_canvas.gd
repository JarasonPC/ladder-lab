class_name PlcLadCanvas
extends PlcCanvas
## Ladder diagram (LAD) of a PLC program, drawn like the programming software
## of small Siemens PLCs: one power rail down the whole left side (as far as
## the diagram goes, and beyond), rows of contacts -| |-, -|/|-, -|P|-,
## -|N|- with their operand above, and the coils at the end of the rows:
## -( )- -(/)- -(S)- -(R)- -(SD)- -(SF)- -(CU)- -(CD)-, with a timer's time
## or a counter's preset below. There are no networks to add: rows joined by
## vertical links make one rung, numbered on the left of the rail, and the
## rungs run from the top (see [method PlcRung.rung_groups]). While
## monitoring, the power flow is drawn in red, the rest in blue.
##
## Editing: choose a contact, wire, branch or coil in the palette and click a
## cell anywhere along the rail (a coil goes to the end of the row clicked;
## the cells before it are wired up to the last element); drag with the wire
## tool to draw several wires; the branch tool links the right side of a cell
## with the row below (click again to remove it). With the select tool a
## click selects an element; Delete removes it, Insert puts an empty row
## above the selected one.

const ROW_H: float = 58.0
const CELL_W: float = 70.0
const COIL_W: float = 120.0
const TOP: float = 14.0
const RAIL_X: float = 44.0
## Height of contacts and coils.
const BAR: float = 11.0
## Empty rows shown below the last one used, to draw into.
const SPARE_ROWS: int = 6

## Selected element: {"row": r, "column": c} (column COLUMNS is the coil),
## {} for nothing.
var selected: Dictionary = {}

var _mouse: Vector2 = Vector2.ZERO
## Painting wires with the wire tool.
var _painting: bool = false
var _painted: bool = false


func tools() -> Array[Dictionary]:
	var contacts: String = "Contacts"
	var coils: String = "Coils"
	var timers: String = "Timers and counters"
	return [
		{"id": "", "title": "Select", "symbol": "↖", "group": ""},
		{"id": "no", "title": "NO contact", "symbol": "-| |-", "group": contacts},
		{"id": "nc", "title": "NC contact", "symbol": "-|/|-", "group": contacts},
		{"id": "pos", "title": "Rising edge contact", "symbol": "-|P|-", "group": contacts},
		{"id": "neg", "title": "Falling edge contact", "symbol": "-|N|-", "group": contacts},
		{"id": "wire", "title": "Wire", "symbol": "——", "group": contacts},
		{"id": "link", "title": "Branch (vertical link)", "symbol": "┬", "group": contacts},
		{"id": "coil", "title": "Coil", "symbol": "-( )-", "group": coils},
		{"id": "coil_not", "title": "Negated coil", "symbol": "-(/)-", "group": coils},
		{"id": "set", "title": "Set coil", "symbol": "-(S)-", "group": coils},
		{"id": "reset", "title": "Reset coil", "symbol": "-(R)-", "group": coils},
		{"id": "on_delay", "title": "On-delay timer", "symbol": "-(SD)-", "group": timers},
		{"id": "off_delay", "title": "Off-delay timer", "symbol": "-(SF)-", "group": timers},
		{"id": "count_up", "title": "Count up", "symbol": "-(CU)-", "group": timers},
		{"id": "count_down", "title": "Count down", "symbol": "-(CD)-", "group": timers},
		{"id": "erase", "title": "Erase", "symbol": "✕", "group": ""},
	]


## English name of a cell or coil kind.
static func kind_title(kind: String) -> String:
	match kind:
		"no":
			return "NO contact"
		"nc":
			return "NC contact"
		"pos":
			return "Rising edge contact"
		"neg":
			return "Falling edge contact"
		"wire":
			return "Wire"
		"coil":
			return "Coil"
		"coil_not":
			return "Negated coil"
		"set":
			return "Set coil"
		"reset":
			return "Reset coil"
		"on_delay":
			return "On-delay timer"
		"off_delay":
			return "Off-delay timer"
		"count_up":
			return "Count up"
		"count_down":
			return "Count down"
	return kind


static func kind_help(kind: String) -> String:
	match kind:
		"no":
			return "Closed while its operand is 1."
		"nc":
			return "Closed while its operand is 0."
		"pos":
			return "Closed for one program cycle when its operand goes from 0 to 1."
		"neg":
			return "Closed for one program cycle when its operand goes from 1 to 0."
		"wire":
			return "Passes the power on."
		"coil":
			return "Its operand is 1 while the coil gets power."
		"coil_not":
			return "Its operand is 0 while the coil gets power, 1 otherwise."
		"set":
			return "Sets its operand to 1 when it gets power; it stays 1."
		"reset":
			return "Resets its operand to 0 when it gets power (a timer stops, a counter goes back to 0)."
		"on_delay":
			return "The timer T comes on when the coil has had power for the time; off with the power."
		"off_delay":
			return "The timer T is on with the power and goes off the time after the power went off."
		"count_up", "count_down":
			return "Counts each time the coil gets power. The counter's contacts C close when the count has reached the preset."
	return ""


## Short text in a coil: "", "/", "S", "R", "SD", ...
static func coil_letters(kind: String) -> String:
	match kind:
		"coil_not":
			return "/"
		"set":
			return "S"
		"reset":
			return "R"
		"on_delay":
			return "SD"
		"off_delay":
			return "SF"
		"count_up":
			return "CU"
		"count_down":
			return "CD"
	return ""


# --- Geometry ----------------------------------------------------------------------

func _ladder() -> PlcRung:
	return program.ladder()


## Rows that can be drawn into: the ones used and spare ones below, at
## least as many as fill the view.
func _rows_shown() -> int:
	var rows: int = _ladder().row_count() + SPARE_ROWS
	var view: float = size.y / zoom
	return clampi(maxi(rows, ceili((view - TOP) / ROW_H)), 1, PlcRung.MAX_ROWS)


## Middle of row [param r] (the line), at zoom 1.
func _row_y(r: int) -> float:
	return TOP + r * ROW_H + ROW_H * 0.6


func _cell_x(c: int) -> float:
	return RAIL_X + c * CELL_W


func _content_size() -> Vector2:
	var rows: int = (_ladder().row_count() if program != null else 1) + SPARE_ROWS
	return Vector2(RAIL_X + PlcRung.COLUMNS * CELL_W + COIL_W + 40.0, TOP + rows * ROW_H + 20.0)


## {"row", "column"} under the pixel [param at], {} for none.
func _hit(at: Vector2) -> Dictionary:
	var p: Vector2 = at / zoom
	if p.x < RAIL_X or p.y < TOP or p.x > _cell_x(PlcRung.COLUMNS) + COIL_W:
		return {}
	var r: int = int((p.y - TOP) / ROW_H)
	if r >= PlcRung.MAX_ROWS:
		return {}
	return {"row": r, "column": mini(int((p.x - RAIL_X) / CELL_W), PlcRung.COLUMNS)}


func _program_shown() -> void:
	if program == null:
		return
	if editable():
		program.ladder()
	if not _selection_valid():
		selected = {}


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


# --- Selection panel ---------------------------------------------------------------

func selection_info() -> Dictionary:
	if not _selection_valid():
		return {}
	var element: Dictionary = _selected_element()
	if element.is_empty():
		return {"title": "Empty place", "label": "", "help": "Choose a contact, wire or coil in the palette and click here to put it in.", "rows": true}
	var kind: String = element["kind"]
	var info: Dictionary = {"title": kind_title(kind), "label": "", "help": kind_help(kind), "rows": true}
	var areas: String = PlcRung.operand_areas(kind)
	if not areas.is_empty():
		info["operand"] = element["operand"]
		info["areas"] = areas
	if element.has("time"):
		info["time"] = element["time"]
	if element.has("preset"):
		info["preset"] = element["preset"]
	if runtime != null and element.has("operand"):
		var op: String = element["operand"]
		var lines: PackedStringArray = PackedStringArray(["%s = %d" % [op, 1 if runtime.operand_value(op) else 0]])
		if runtime.timers.has(op) and runtime.timers[op].running:
			lines.append("Ta = %s" % seconds(runtime.timers[op].elapsed))
		if runtime.counters.has(op):
			lines.append("Cv = %d" % runtime.counters[op].value)
		info["live"] = "\n".join(lines)
	return info


## True when the selection is a place in a row of the diagram (empty or not).
func _selection_valid() -> bool:
	return program != null and not program.rungs.is_empty() and selected.has("row") and int(selected["row"]) < program.rungs[0].row_count()


func _selected_element() -> Dictionary:
	if not selected.has("row") or program.rungs.is_empty():
		return {}
	var rung: PlcRung = program.rungs[0]
	var r: int = selected["row"]
	if r >= rung.row_count():
		return {}
	if int(selected["column"]) >= PlcRung.COLUMNS:
		return rung.get_coil(r)
	return rung.get_cell(r, selected["column"])


func set_property(key: String, value: Variant) -> void:
	if not editable():
		return
	var element: Dictionary = _selected_element()
	if element.is_empty() or not element.has(key):
		return
	match key:
		"operand":
			element["operand"] = str(value)
		"time":
			element["time"] = clampf(float(value), 0.0, PlcBlock.MAX_TIME)
		"preset":
			element["preset"] = clampi(int(value), 1, PlcCounter.MAX_VALUE)
	queue_redraw()
	changed.emit()


func delete_selection() -> void:
	if not editable() or not selected.has("row"):
		return
	_apply("erase", selected["row"], selected["column"], false)
	update_size()
	queue_redraw()
	selection_changed.emit()
	changed.emit()


## Puts an empty row above the selected one (the elements below move down).
func insert_row() -> void:
	if not editable() or not selected.has("row") or int(selected["row"]) >= _ladder().row_count():
		return
	_ladder().insert_row(selected["row"])
	selected["row"] = int(selected["row"]) + 1
	update_size()
	queue_redraw()
	changed.emit()


## Removes the row of the selection (the rows below move up).
func delete_row() -> void:
	if not editable() or not selected.has("row") or int(selected["row"]) >= _ladder().row_count():
		return
	var rung: PlcRung = _ladder()
	if rung.row_count() == 1:
		# The last row is emptied instead.
		for c: int in PlcRung.COLUMNS:
			rung.set_cell(0, c, {})
		rung.set_coil(0, {})
	else:
		rung.remove_row(selected["row"])
	rung.trim()
	selected = {}
	update_size()
	queue_redraw()
	selection_changed.emit()
	changed.emit()


# --- Input -------------------------------------------------------------------------

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
		if _painting and tool == "wire":
			var hit: Dictionary = _hit(_mouse)
			if hit.has("row") and int(hit["column"]) < PlcRung.COLUMNS and (hit["row"] >= _ladder().row_count() or _ladder().get_cell(hit["row"], hit["column"]).get("kind", "") != "wire"):
				_apply("wire", hit["row"], hit["column"], true)
				_painted = true
		queue_redraw()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		_mouse = mb.position
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press()
			elif _painting:
				_painting = false
				if _painted:
					changed.emit()
			accept_event()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		var key: InputEventKey = event as InputEventKey
		match key.keycode:
			KEY_DELETE, KEY_BACKSPACE:
				delete_selection()
				accept_event()
			KEY_INSERT:
				insert_row()
				accept_event()
			KEY_ESCAPE:
				if not tool.is_empty():
					tool_finished.emit()
				else:
					selected = {}
					selection_changed.emit()
					queue_redraw()
				accept_event()


func _right_click(_at: Vector2) -> void:
	if not tool.is_empty():
		tool_finished.emit()


func _press() -> void:
	var hit: Dictionary = _hit(_mouse)
	if tool.is_empty() or not editable():
		selected = hit
		if not _selection_valid():
			selected = {}
		selection_changed.emit()
		queue_redraw()
		return
	if not hit.has("row"):
		return
	_apply(tool, hit["row"], hit["column"], true)
	if tool == "wire":
		_painting = true
		_painted = true
	else:
		changed.emit()


## Puts element [param what] (a tool) at row [param r], column [param c];
## [param select] selects it.
func _apply(what: String, r: int, c: int, select: bool) -> void:
	var rung: PlcRung = _ladder()
	rung.ensure_rows(r + 1)
	if r >= rung.row_count():
		return
	var at_coil: bool = c >= PlcRung.COLUMNS
	match what:
		"no", "nc", "pos", "neg":
			if at_coil:
				return
			var old: Dictionary = rung.get_cell(r, c)
			var operand: String = str(old.get("operand", ""))
			if not PlcProgram.valid_operand(operand, PlcRung.operand_areas(what)):
				operand = "I1"
			rung.set_cell(r, c, {"kind": what, "operand": operand})
		"wire":
			if at_coil:
				return
			rung.set_cell(r, c, {"kind": "wire"})
		"link":
			if at_coil:
				return
			rung.set_link(r, c, not rung.has_link(r, c))
		"erase":
			if at_coil:
				rung.set_coil(r, {})
			else:
				rung.set_cell(r, c, {})
				rung.set_link(r, c, false)
			select = false
		_:
			if not PlcRung.COIL_KINDS.has(what):
				return
			var old_coil: Dictionary = rung.get_coil(r)
			var coil: Dictionary = {"kind": what}
			var areas: String = PlcRung.operand_areas(what)
			var operand: String = str(old_coil.get("operand", ""))
			coil["operand"] = operand if PlcProgram.valid_operand(operand, areas) else _free_operand(areas.left(1))
			if what == "on_delay" or what == "off_delay":
				coil["time"] = old_coil.get("time", PlcBlock.DEFAULT_TIME)
			elif what == "count_up" or what == "count_down":
				coil["preset"] = old_coil.get("preset", PlcBlock.DEFAULT_PRESET)
			rung.set_coil(r, coil)
			rung.wire_to_coil(r)
			c = PlcRung.COLUMNS
	rung.trim()
	if select and r < rung.row_count():
		selected = {"row": r, "column": c}
	elif not select:
		selected = {}
	update_size()
	queue_redraw()
	selection_changed.emit()


## First operand of [param area] no coil writes yet (else the first one).
func _free_operand(area: String) -> String:
	var used: Dictionary[String, bool] = {}
	var rung: PlcRung = _ladder()
	for r: int in rung.row_count():
		var coil: Dictionary = rung.get_coil(r)
		if not coil.is_empty() and coil["kind"] != "reset":
			used[coil["operand"]] = true
	for op: String in PlcProgram.operands(area):
		if not used.has(op):
			return op
	return area + "1"


# --- Drawing -----------------------------------------------------------------------

func _draw() -> void:
	super()
	if program == null or program.rungs.is_empty():
		return
	var z: float = zoom
	var rung: PlcRung = program.rungs[0]
	var power: PackedByteArray = runtime.rung_power[0] if runtime != null and not runtime.rung_power.is_empty() else PackedByteArray()
	var coil_power: PackedByteArray = runtime.coil_power[0] if runtime != null and not runtime.coil_power.is_empty() else PackedByteArray()
	# The power rail, all the way down.
	draw_line(Vector2(RAIL_X * z, 0.0), Vector2(RAIL_X * z, size.y), signal_color(true), 3.0 * z)
	# Rung numbers left of the rail.
	var groups: Array[Vector2i] = rung.rung_groups()
	for g: int in groups.size():
		text(str(g + 1), Vector2((RAIL_X - 8.0) * z, _row_y(groups[g].x) * z), 11, SchematicTheme.DESIGNATION, 1)
		if g > 0:
			var y_top: float = (TOP + groups[g].x * ROW_H) * z
			draw_dashed_line(Vector2((RAIL_X + 4.0) * z, y_top), Vector2(_cell_x(PlcRung.COLUMNS) * z + COIL_W * z, y_top), Color(SchematicTheme.LINE, 0.12), 1.0, 4.0 * z)
	for r: int in _rows_shown():
		var y: float = _row_y(r) * z
		if y - ROW_H * z > size.y:
			break
		var real: bool = r < rung.row_count()
		for c: int in PlcRung.COLUMNS:
			var x0: float = _cell_x(c) * z
			var x1: float = _cell_x(c + 1) * z
			if selected.get("row", -1) == r and selected.get("column", -1) == c:
				draw_rect(Rect2(Vector2(x0 + 2.0 * z, y - 28.0 * z), Vector2(CELL_W - 4.0, 46.0) * z), Color(AppTheme.accent, 0.2))
			var cell: Dictionary = rung.get_cell(r, c) if real else {}
			var left_on: bool = c == 0 or (power.size() > 0 and real and power[r * PlcRung.COLUMNS + c - 1] != 0)
			var right_on: bool = power.size() > 0 and real and power[r * PlcRung.COLUMNS + c] != 0
			_draw_cell(cell, x0, x1, y, left_on and real, right_on)
			if real and rung.has_link(r, c):
				draw_line(Vector2(x1, y), Vector2(x1, _row_y(r + 1) * z), signal_color(right_on), 1.8 * z, true)
			if cell.is_empty() and editable():
				draw_circle(Vector2((x0 + x1) * 0.5, y), 1.5 * z, SchematicTheme.GRID_DOT)
		var coil: Dictionary = rung.get_coil(r) if real else {}
		_draw_coil(r, coil, y, coil_power.size() > r and coil_power[r] != 0)


## One cell from [param x0] to [param x1] on the line at [param y].
func _draw_cell(cell: Dictionary, x0: float, x1: float, y: float, left_on: bool, right_on: bool) -> void:
	var z: float = zoom
	var kind: String = cell.get("kind", "")
	if kind.is_empty():
		return
	if kind == "wire":
		draw_line(Vector2(x0, y), Vector2(x1, y), signal_color(right_on), 1.8 * z, true)
		return
	var cx: float = (x0 + x1) * 0.5
	var a: float = cx - 8.0 * z
	var b: float = cx + 8.0 * z
	var bar: float = BAR * z
	draw_line(Vector2(x0, y), Vector2(a, y), signal_color(left_on), 1.8 * z, true)
	draw_line(Vector2(b, y), Vector2(x1, y), signal_color(right_on), 1.8 * z, true)
	# The contact in red when it is closed and has power, whatever reaches
	# its right side from a parallel branch.
	var closed: Color = signal_color(left_on and _closed(cell))
	draw_line(Vector2(a, y - bar), Vector2(a, y + bar), closed, 1.8 * z, true)
	draw_line(Vector2(b, y - bar), Vector2(b, y + bar), closed, 1.8 * z, true)
	match kind:
		"nc":
			draw_line(Vector2(a + 2.0 * z, y + bar), Vector2(b - 2.0 * z, y - bar), closed, 1.5 * z, true)
		"pos":
			text("P", Vector2(cx, y), 10, SchematicTheme.TEXT)
		"neg":
			text("N", Vector2(cx, y), 10, SchematicTheme.TEXT)
	text(cell.get("operand", ""), Vector2(cx, y - bar - 9.0 * z), 11, SchematicTheme.DESIGNATION)


## True when contact [param cell] is closed in the running program (edge
## contacts are closed for a single cycle only and are drawn open).
func _closed(cell: Dictionary) -> bool:
	if runtime == null:
		return false
	match str(cell.get("kind", "")):
		"no":
			return runtime.operand_value(cell["operand"])
		"nc":
			return not runtime.operand_value(cell["operand"])
	return false


func _draw_coil(r: int, coil: Dictionary, y: float, on: bool) -> void:
	var z: float = zoom
	var x0: float = _cell_x(PlcRung.COLUMNS) * z
	var cx: float = x0 + COIL_W * 0.5 * z
	if selected.get("row", -1) == r and selected.get("column", -1) == PlcRung.COLUMNS:
		draw_rect(Rect2(Vector2(x0 + 2.0 * z, y - 28.0 * z), Vector2(COIL_W - 4.0, 46.0) * z), Color(AppTheme.accent, 0.2))
	if coil.is_empty():
		return
	var radius: float = 13.0 * z
	var color: Color = signal_color(on)
	draw_line(Vector2(x0, y), Vector2(cx - radius * 0.9, y), color, 1.8 * z, true)
	draw_arc(Vector2(cx + radius * 0.05, y), radius, PI * 0.72, PI * 1.28, 12, color, 1.8 * z, true)
	draw_arc(Vector2(cx - radius * 0.05, y), radius, -PI * 0.28, PI * 0.28, 12, color, 1.8 * z, true)
	var kind: String = coil["kind"]
	text(coil_letters(kind), Vector2(cx, y), 10, SchematicTheme.TEXT)
	var op: String = coil["operand"]
	text(op, Vector2(cx, y - BAR * z - 9.0 * z), 11, SchematicTheme.DESIGNATION)
	var below: String = ""
	if coil.has("time"):
		below = seconds(coil["time"])
		if runtime != null and runtime.timers.has(op) and runtime.timers[op].running:
			below = "%s / %s" % [seconds(runtime.timers[op].elapsed), seconds(coil["time"])]
	elif coil.has("preset"):
		below = "PV %d" % coil["preset"]
		if runtime != null and runtime.counters.has(op):
			below = "CV %d / %d" % [runtime.counters[op].value, coil["preset"]]
	if not below.is_empty():
		text(below, Vector2(cx, y + BAR * z + 9.0 * z), 10, SchematicTheme.TEXT)
