class_name PlcLadCanvas
extends PlcCanvas
## Ladder diagram (LAD) of a PLC program, drawn as in Siemens programming
## software: networks one below the other, each with the power rail on the
## left, contacts -| |- and -|/|- with their operand above, and the coils at
## the end of the rows: -( )- -(S)- -(R)- -(SD)- -(SF)- -(CU)- -(CD)-, with
## a timer's time or a counter's preset below. While monitoring, the power
## flow is drawn in [constant PlcCanvas.ON].
##
## Editing: choose a contact, wire, branch or coil in the palette and click a
## cell (a coil goes to the end of the row clicked; the cells before it are
## wired up to the last element); drag with the wire tool to draw several
## wires; the branch tool links the right side of a cell with the row below
## (click again to remove it). With the select tool a click selects an
## element or, on its title, a network; Delete removes it. An empty row
## below each network takes new branches.

const ROW_H: float = 58.0
const CELL_W: float = 70.0
const COIL_W: float = 120.0
const HEADER_H: float = 30.0
const NETWORK_GAP: float = 16.0
const RAIL_X: float = 36.0
## Height of contacts and coils.
const BAR: float = 11.0

## Selected element: {"rung": n, "row": r, "column": c} (column COLUMNS is
## the coil), {"rung": n} for a whole network, {} for nothing.
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
		{"id": "wire", "title": "Wire", "symbol": "——", "group": contacts},
		{"id": "link", "title": "Branch (vertical link)", "symbol": "┬", "group": contacts},
		{"id": "coil", "title": "Coil", "symbol": "-( )-", "group": coils},
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
		"wire":
			return "Wire"
		"coil":
			return "Coil"
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
		"wire":
			return "Passes the power on."
		"coil":
			return "Its operand is 1 while the coil gets power."
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


## Short text in a coil: "", "S", "R", "SD", ...
static func coil_letters(kind: String) -> String:
	match kind:
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

## Rows drawn for network [param n]: its rows plus an empty one to grow into
## while editing.
func _rows_shown(n: int) -> int:
	var rows: int = program.rungs[n].row_count()
	return rows + 1 if editable() and rows < PlcRung.MAX_ROWS else rows


## Top of network [param n] at zoom 1.
func _network_top(n: int) -> float:
	var y: float = 10.0
	for i: int in n:
		y += HEADER_H + _rows_shown(i) * ROW_H + NETWORK_GAP
	return y


## Middle of row [param r] of network [param n] (the line), at zoom 1.
func _row_y(n: int, r: int) -> float:
	return _network_top(n) + HEADER_H + r * ROW_H + ROW_H * 0.6


func _cell_x(c: int) -> float:
	return RAIL_X + c * CELL_W


func _content_size() -> Vector2:
	var height: float = 80.0
	if program != null:
		height = _network_top(program.rungs.size()) + 40.0
	return Vector2(RAIL_X + PlcRung.COLUMNS * CELL_W + COIL_W + 40.0, height)


## {"rung", "row", "column"} under the pixel [param at] ({"rung", "header":
## true} on a network's title), {} for none.
func _hit(at: Vector2) -> Dictionary:
	var p: Vector2 = at / zoom
	for n: int in program.rungs.size():
		var top: float = _network_top(n)
		if p.y >= top and p.y < top + HEADER_H:
			return {"rung": n, "header": true}
		var rows_top: float = top + HEADER_H
		if p.y >= rows_top and p.y < rows_top + _rows_shown(n) * ROW_H and p.x >= RAIL_X:
			var r: int = int((p.y - rows_top) / ROW_H)
			var c: int = mini(int((p.x - RAIL_X) / CELL_W), PlcRung.COLUMNS)
			if p.x > _cell_x(PlcRung.COLUMNS) + COIL_W:
				return {}
			return {"rung": n, "row": r, "column": c}
	return {}


func _program_shown() -> void:
	if program == null:
		return
	if editable() and program.rungs.is_empty():
		# Something to draw into.
		program.rungs.append(PlcRung.new())
	if selected.has("rung") and int(selected["rung"]) >= program.rungs.size():
		selected = {}


# --- Selection panel ---------------------------------------------------------------

func selection_info() -> Dictionary:
	if program == null or not selected.has("rung") or int(selected["rung"]) >= program.rungs.size():
		return {}
	var n: int = selected["rung"]
	if not selected.has("row"):
		return {"title": "Network", "label": str(n + 1), "help": "Delete removes the whole network."}
	var element: Dictionary = _selected_element()
	if element.is_empty():
		return {}
	var kind: String = element["kind"]
	var info: Dictionary = {"title": kind_title(kind), "label": "", "help": kind_help(kind)}
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


func _selected_element() -> Dictionary:
	if not selected.has("row"):
		return {}
	var rung: PlcRung = program.rungs[selected["rung"]]
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
	if not editable() or not selected.has("rung"):
		return
	var n: int = selected["rung"]
	if not selected.has("row"):
		program.rungs.remove_at(n)
		if program.rungs.is_empty():
			program.rungs.append(PlcRung.new())
		selected = {}
	else:
		_apply("erase", n, selected["row"], selected["column"], false)
	update_size()
	queue_redraw()
	selection_changed.emit()
	changed.emit()


## Adds an empty network after the selected one (else at the end) and
## selects it.
func add_network() -> void:
	if not editable() or program.rungs.size() >= PlcProgram.MAX_RUNGS:
		return
	var at: int = int(selected["rung"]) + 1 if selected.has("rung") else program.rungs.size()
	program.rungs.insert(at, PlcRung.new())
	selected = {"rung": at}
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
			if hit.has("row") and int(hit["column"]) < PlcRung.COLUMNS and program.rungs[hit["rung"]].get_cell(hit["row"], hit["column"]).get("kind", "") != "wire":
				_apply("wire", hit["rung"], hit["row"], hit["column"], true)
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
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not tool.is_empty():
			tool_finished.emit()
			accept_event()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		var key: InputEventKey = event as InputEventKey
		if key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE:
			delete_selection()
			accept_event()
		elif key.keycode == KEY_ESCAPE and not tool.is_empty():
			tool_finished.emit()
			accept_event()


func _press() -> void:
	var hit: Dictionary = _hit(_mouse)
	if tool.is_empty() or not editable() or hit.has("header"):
		if hit.has("header"):
			selected = {"rung": hit["rung"]}
		elif hit.has("row"):
			selected = hit
			if _selected_element().is_empty():
				selected = {}
		else:
			selected = {}
		selection_changed.emit()
		queue_redraw()
		return
	if not hit.has("row"):
		return
	_apply(tool, hit["rung"], hit["row"], hit["column"], true)
	if tool == "wire":
		_painting = true
		_painted = true
	else:
		changed.emit()


## Puts element [param what] (a tool) at row [param r], column [param c] of
## network [param n]; [param select] selects it.
func _apply(what: String, n: int, r: int, c: int, select: bool) -> void:
	var rung: PlcRung = program.rungs[n]
	rung.ensure_rows(r + 1)
	if r >= rung.row_count():
		return
	var at_coil: bool = c >= PlcRung.COLUMNS
	match what:
		"no", "nc":
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
		selected = {"rung": n, "row": r, "column": c}
	elif not select:
		selected = {}
	update_size()
	queue_redraw()
	selection_changed.emit()


## First operand of [param area] no coil writes yet (else the first one).
func _free_operand(area: String) -> String:
	var used: Dictionary[String, bool] = {}
	for rung: PlcRung in program.rungs:
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
	if program == null:
		return
	for n: int in program.rungs.size():
		_draw_network(n)


func _draw_network(n: int) -> void:
	var z: float = zoom
	var rung: PlcRung = program.rungs[n]
	var top: float = _network_top(n) * z
	var header_selected: bool = selected.get("rung", -1) == n and not selected.has("row")
	if header_selected:
		draw_rect(Rect2(Vector2(4.0 * z, top), Vector2(_content_size().x - 8.0, HEADER_H) * z), Color(AppTheme.accent, 0.2))
	text(tr("Network %d") % (n + 1), Vector2(8.0 * z, top + HEADER_H * 0.5 * z), 12, SchematicTheme.DESIGNATION, -1)
	var rows: int = _rows_shown(n)
	var power: PackedByteArray = runtime.rung_power[n] if runtime != null and n < runtime.rung_power.size() else PackedByteArray()
	var coil_power: PackedByteArray = runtime.coil_power[n] if runtime != null and n < runtime.coil_power.size() else PackedByteArray()
	# Power rail.
	var rail_top: float = top + HEADER_H * z + 6.0 * z
	var rail_bottom: float = _row_y(n, rung.row_count() - 1) * z + 18.0 * z
	draw_line(Vector2(RAIL_X * z, rail_top), Vector2(RAIL_X * z, rail_bottom), signal_color(true), 3.0 * z)
	for r: int in rows:
		var y: float = _row_y(n, r) * z
		var real: bool = r < rung.row_count()
		for c: int in PlcRung.COLUMNS:
			var x0: float = _cell_x(c) * z
			var x1: float = _cell_x(c + 1) * z
			if selected.get("rung", -1) == n and selected.get("row", -1) == r and selected.get("column", -1) == c:
				draw_rect(Rect2(Vector2(x0 + 2.0 * z, y - 28.0 * z), Vector2(CELL_W - 4.0, 46.0) * z), Color(AppTheme.accent, 0.2))
			var cell: Dictionary = rung.get_cell(r, c) if real else {}
			var left_on: bool = c == 0 or (power.size() > 0 and power[r * PlcRung.COLUMNS + c - 1] != 0)
			var right_on: bool = power.size() > 0 and power[r * PlcRung.COLUMNS + c] != 0 and real
			_draw_cell(cell, x0, x1, y, left_on and real, right_on)
			if real and rung.has_link(r, c):
				var y_next: float = _row_y(n, r + 1) * z
				draw_line(Vector2(x1, y), Vector2(x1, y_next), signal_color(right_on), 1.8 * z, true)
			if cell.is_empty() and editable():
				draw_circle(Vector2((x0 + x1) * 0.5, y), 1.5 * z, SchematicTheme.GRID_DOT)
		var coil: Dictionary = rung.get_coil(r) if real else {}
		var coil_on: bool = coil_power.size() > r and coil_power[r] != 0
		_draw_coil(n, r, coil, y, coil_on)


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
	var closed: Color = signal_color(left_on and right_on)
	draw_line(Vector2(a, y - bar), Vector2(a, y + bar), closed, 1.8 * z, true)
	draw_line(Vector2(b, y - bar), Vector2(b, y + bar), closed, 1.8 * z, true)
	if kind == "nc":
		draw_line(Vector2(a + 2.0 * z, y + bar), Vector2(b - 2.0 * z, y - bar), closed, 1.5 * z, true)
	var operand: String = cell.get("operand", "")
	text(operand, Vector2(cx, y - bar - 9.0 * z), 11, SchematicTheme.DESIGNATION)


func _draw_coil(n: int, r: int, coil: Dictionary, y: float, on: bool) -> void:
	var z: float = zoom
	var x0: float = _cell_x(PlcRung.COLUMNS) * z
	var cx: float = x0 + COIL_W * 0.5 * z
	if selected.get("rung", -1) == n and selected.get("row", -1) == r and selected.get("column", -1) == PlcRung.COLUMNS:
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
	text(coil["operand"], Vector2(cx, y - BAR * z - 9.0 * z), 11, SchematicTheme.DESIGNATION)
	var below: String = ""
	var op: String = coil["operand"]
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
