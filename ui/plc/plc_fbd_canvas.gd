class_name PlcFbdCanvas
extends PlcCanvas
## Function block diagram (FBD) of a PLC program, drawn like the programming
## software of small Siemens PLCs: connectors I, Q, M, hi and lo, basic
## functions (& ≥1 1 =1, negated outputs with a circle) and special functions
## as boxes with their block number B001 above them and their set time or
## count below.
##
## Editing: choose a block in the palette and click to place it (repeatedly,
## Esc or a right click ends it); drag a block to move it; drag from a block's
## output (right) to another block's input (left) to connect them (an input
## takes one connection, a new one replaces it); drag a connection away from
## an input or right click the input to remove it; Delete removes the
## selected block.

## Pixels per grid cell at zoom 1.
const U: float = 20.0
## Empty cells around the drawing.
const MARGIN: float = 2.0
## Length of the pin leads, in cells.
const LEAD: float = 0.6
const PIN_RADIUS: float = 0.45

## Text written in a block, by type.
const SYMBOLS: Dictionary[String, String] = {"hi": "hi", "lo": "lo", "and": "&", "or": "≥1", "not": "1", "nand": "&", "nor": "≥1", "xor": "=1", "on_delay": "TON", "off_delay": "TOF", "latch": "RS", "pulse_relay": "TT", "counter": "CTUD"}
const NEGATED: PackedStringArray = ["not", "nand", "nor"]

## Number of the selected block, 0 for none.
var selected: int = 0

var _mouse: Vector2 = Vector2.ZERO
## Moving a block: its number, the grab point inside it (cells), whether it moved.
var _drag_block: int = 0
var _drag_grab: Vector2 = Vector2.ZERO
var _drag_moved: bool = false
## Drawing a connection from the output of block [member _wire_from].
var _wire_from: int = 0


func tools() -> Array[Dictionary]:
	var connectors: String = "Connectors"
	var basic: String = "Basic functions"
	var special: String = "Special functions"
	return [
		{"id": "", "title": "Select and connect", "symbol": "↖", "group": ""},
		{"id": "input", "title": "Input I", "symbol": "I", "group": connectors},
		{"id": "output", "title": "Output Q", "symbol": "Q", "group": connectors},
		{"id": "flag", "title": "Flag M", "symbol": "M", "group": connectors},
		{"id": "hi", "title": "Constant 1 (hi)", "symbol": "hi", "group": connectors},
		{"id": "lo", "title": "Constant 0 (lo)", "symbol": "lo", "group": connectors},
		{"id": "and", "title": "AND", "symbol": "&", "group": basic},
		{"id": "or", "title": "OR", "symbol": "≥1", "group": basic},
		{"id": "not", "title": "NOT", "symbol": "1o", "group": basic},
		{"id": "nand", "title": "NAND", "symbol": "&o", "group": basic},
		{"id": "nor", "title": "NOR", "symbol": "≥1o", "group": basic},
		{"id": "xor", "title": "XOR", "symbol": "=1", "group": basic},
		{"id": "on_delay", "title": "On-delay", "symbol": "TON", "group": special},
		{"id": "off_delay", "title": "Off-delay", "symbol": "TOF", "group": special},
		{"id": "latch", "title": "Latching relay", "symbol": "RS", "group": special},
		{"id": "pulse_relay", "title": "Pulse relay", "symbol": "TT", "group": special},
		{"id": "counter", "title": "Up/down counter", "symbol": "CTUD", "group": special},
	]


## English name of a block type.
static func type_title(type: String) -> String:
	match type:
		"input":
			return "Input"
		"output":
			return "Output"
		"flag":
			return "Flag"
		"hi":
			return "Constant 1 (hi)"
		"lo":
			return "Constant 0 (lo)"
		"and", "or", "not", "nand", "nor", "xor":
			return type.to_upper()
		"on_delay":
			return "On-delay"
		"off_delay":
			return "Off-delay"
		"latch":
			return "Latching relay"
		"pulse_relay":
			return "Pulse relay"
		"counter":
			return "Up/down counter"
	return type


## English description of what a block type does.
static func type_help(type: String) -> String:
	match type:
		"input":
			return "Brings an input of the PLC into the diagram: 1 while the input has voltage."
		"output":
			return "Switches an output relay of the PLC: its contact closes while the input of this block is 1. Its own output can be fed back."
		"flag":
			return "Stores a signal as a flag M; its output can be used elsewhere in the diagram."
		"hi", "lo":
			return "A fixed signal 1 or 0."
		"and":
			return "1 when all connected inputs are 1 (unconnected inputs count as 1)."
		"or":
			return "1 when at least one input is 1."
		"not":
			return "Inverts its input."
		"nand":
			return "AND with an inverted output."
		"nor":
			return "OR with an inverted output."
		"xor":
			return "1 when exactly one of its two inputs is 1."
		"on_delay":
			return "The output comes on when the trigger Trg has been 1 for the time T; off with Trg."
		"off_delay":
			return "The output is on with the trigger Trg and goes off the time T after Trg went off; R switches it off at once."
		"latch":
			return "S sets the output, R resets it; R wins when both are 1."
		"pulse_relay":
			return "Every rising edge on Trg switches the output over; S sets it, R resets it (R wins)."
		"counter":
			return "Counts the rising edges on Cnt, up or down while Dir is 1; R sets the count to 0. The output is on while the count has reached the preset."
	return ""


# --- Geometry ----------------------------------------------------------------------

## Size of a block in cells (the pins are one cell apart; special functions
## at least two cells high, for their name and pin names).
static func block_size(b: PlcBlock) -> Vector2i:
	if PlcBlock.CONNECTORS.has(b.type):
		return Vector2i(3, 2)
	var basic: bool = PlcBlock.pin_names(b.type).has("")
	return Vector2i(4, maxi(b.inputs.size(), 1 if basic else 2) + 1)


## Body of a block in cells.
static func body_rect(b: PlcBlock) -> Rect2:
	var s: Vector2i = block_size(b)
	return Rect2(Vector2(b.cell) + Vector2(0, 0.5), Vector2(s.x, s.y - 1))


## End of the lead of input pin [param pin], in cells.
static func input_point(b: PlcBlock, pin: int) -> Vector2:
	return Vector2(b.cell.x - LEAD, b.cell.y + 1 + pin)


## End of the output lead, in cells.
static func output_point(b: PlcBlock) -> Vector2:
	var s: Vector2i = block_size(b)
	return Vector2(b.cell.x + s.x + LEAD, b.cell.y + s.y * 0.5)


func _px(cells: Vector2) -> Vector2:
	return (cells + Vector2(MARGIN, MARGIN)) * U * zoom


func _cells(pixel: Vector2) -> Vector2:
	return pixel / (U * zoom) - Vector2(MARGIN, MARGIN)


func _content_size() -> Vector2:
	var extent: Vector2 = Vector2(40, 24)
	if program != null:
		for b: PlcBlock in program.blocks:
			extent = extent.max(Vector2(b.cell + block_size(b)) + Vector2(6, 4))
	return (extent + Vector2(MARGIN, MARGIN)) * U


func _program_shown() -> void:
	if program == null or program.block(selected) == null:
		selected = 0
	_drag_block = 0
	_wire_from = 0


# --- Selection panel ---------------------------------------------------------------

func selection_info() -> Dictionary:
	var b: PlcBlock = program.block(selected) if program != null else null
	if b == null:
		return {}
	var info: Dictionary = {"title": type_title(b.type), "label": b.label(), "help": type_help(b.type)}
	var area: String = PlcBlock.operand_area(b.type)
	if not area.is_empty():
		info["operand"] = b.operand
		info["areas"] = area
	if PlcBlock.uses_time(b.type):
		info["time"] = b.time
	if b.type == "counter":
		info["preset"] = b.preset
	if runtime != null:
		info["live"] = _live_text(b)
	return info


func set_property(key: String, value: Variant) -> void:
	var b: PlcBlock = program.block(selected)
	if b == null or not editable():
		return
	match key:
		"operand":
			b.operand = str(value)
		"time":
			b.time = clampf(float(value), 0.0, PlcBlock.MAX_TIME)
		"preset":
			b.preset = clampi(int(value), 1, PlcCounter.MAX_VALUE)
	queue_redraw()
	changed.emit()


func delete_selection() -> void:
	if not editable() or program.block(selected) == null:
		return
	program.remove_block(selected)
	selected = 0
	update_size()
	queue_redraw()
	selection_changed.emit()
	changed.emit()


## State of a block while monitoring: its output, its time or count.
func _live_text(b: PlcBlock) -> String:
	var key: String = "B%d" % b.id
	var parts: PackedStringArray = PackedStringArray(["%s = %d" % [tr("Output"), 1 if runtime.values.get(b.id, false) else 0]])
	if runtime.timers.has(key) and runtime.timers[key].running:
		parts.append("Ta = %s" % seconds(runtime.timers[key].elapsed))
	if runtime.counters.has(key):
		parts.append("Cv = %d" % runtime.counters[key].value)
	return "\n".join(parts)


# --- Input -------------------------------------------------------------------------

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
		if _drag_block > 0 and editable():
			var b: PlcBlock = program.block(_drag_block)
			if b != null:
				var to: Vector2i = Vector2i((_cells(_mouse) - _drag_grab).round())
				to = to.max(Vector2i(0, 0))
				if to != b.cell:
					b.cell = to
					_drag_moved = true
					update_size()
		queue_redraw()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		_mouse = mb.position
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press()
			else:
				_release()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not tool.is_empty() or _wire_from > 0:
				_wire_from = 0
				tool_finished.emit()
			elif editable():
				var pin: Vector2i = _input_pin_at(_cells(_mouse))
				if pin.x > 0 and program.block(pin.x).inputs[pin.y] > 0:
					program.block(pin.x).inputs[pin.y] = 0
					changed.emit()
			queue_redraw()
			accept_event()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		var key: InputEventKey = event as InputEventKey
		if key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE:
			delete_selection()
			accept_event()
		elif key.keycode == KEY_ESCAPE and (not tool.is_empty() or _wire_from > 0):
			_wire_from = 0
			tool_finished.emit()
			queue_redraw()
			accept_event()


func _press() -> void:
	var at: Vector2 = _cells(_mouse)
	if not tool.is_empty():
		if editable():
			var b: PlcBlock = program.add_block(tool, _place_cell(at))
			if b != null:
				selected = b.id
				update_size()
				selection_changed.emit()
				changed.emit()
		return
	if editable():
		var out: int = _output_pin_at(at)
		if out > 0:
			_wire_from = out
			return
		var pin: Vector2i = _input_pin_at(at)
		if pin.x > 0 and program.block(pin.x).inputs[pin.y] > 0:
			# Pick the connection up from the input: drop it elsewhere to remove it.
			_wire_from = program.block(pin.x).inputs[pin.y]
			program.block(pin.x).inputs[pin.y] = 0
			return
	var hit: PlcBlock = _block_at(at)
	selected = hit.id if hit != null else 0
	if hit != null and editable():
		_drag_block = hit.id
		_drag_grab = at - Vector2(hit.cell)
		_drag_moved = false
	selection_changed.emit()
	queue_redraw()


func _release() -> void:
	if _wire_from > 0:
		var pin: Vector2i = _input_pin_at(_cells(_mouse))
		if pin.x > 0 and pin.x != _wire_from:
			program.block(pin.x).inputs[pin.y] = _wire_from
		_wire_from = 0
		changed.emit()
	elif _drag_block > 0 and _drag_moved:
		changed.emit()
	_drag_block = 0
	queue_redraw()


## Top left cell for a new block whose middle is at [param at].
func _place_cell(at: Vector2) -> Vector2i:
	var s: Vector2i = block_size(PlcBlock.new(0, tool))
	return Vector2i((at - Vector2(s) * 0.5).round()).max(Vector2i(0, 0))


func _block_at(at: Vector2) -> PlcBlock:
	for i: int in range(program.blocks.size() - 1, -1, -1):
		if body_rect(program.blocks[i]).grow(0.15).has_point(at):
			return program.blocks[i]
	return null


## Block whose output lead is at [param at], 0 for none.
func _output_pin_at(at: Vector2) -> int:
	for b: PlcBlock in program.blocks:
		var end: Vector2 = output_point(b)
		if at.distance_to(end) < PIN_RADIUS or Rect2(end - Vector2(LEAD, 0.25), Vector2(LEAD, 0.5)).has_point(at):
			return b.id
	return 0


## (block, pin) of the input lead at [param at], x = 0 for none.
func _input_pin_at(at: Vector2) -> Vector2i:
	for b: PlcBlock in program.blocks:
		for p: int in b.inputs.size():
			var end: Vector2 = input_point(b, p)
			if at.distance_to(end) < PIN_RADIUS or Rect2(end - Vector2(0, 0.3), Vector2(LEAD, 0.6)).has_point(at):
				return Vector2i(b.id, p)
	return Vector2i.ZERO


# --- Drawing -----------------------------------------------------------------------

func _draw() -> void:
	super()
	if program == null:
		return
	if editable():
		_draw_grid()
	for b: PlcBlock in program.blocks:
		for p: int in b.inputs.size():
			var source: PlcBlock = program.block(b.inputs[p])
			if source != null:
				_draw_connection(_route(source, b, p), _value(source.id))
	for b: PlcBlock in program.blocks:
		_draw_block(b, Color(1, 1, 1, 1))
	if _wire_from > 0 and program.block(_wire_from) != null:
		var from: Vector2 = _px(output_point(program.block(_wire_from)))
		draw_line(from, _mouse, AppTheme.accent, 2.0, true)
		var target: Vector2i = _input_pin_at(_cells(_mouse))
		if target.x > 0:
			draw_circle(_px(input_point(program.block(target.x), target.y)), 5.0 * zoom, AppTheme.accent)
	if not tool.is_empty() and editable() and get_rect().has_point(_mouse + position):
		var ghost: PlcBlock = PlcBlock.new(0, tool, _place_cell(_cells(_mouse)))
		_draw_block(ghost, Color(1, 1, 1, 0.45))


func _draw_grid() -> void:
	var dot: Color = SchematicTheme.GRID_DOT
	var step: float = U * zoom
	var count: Vector2i = Vector2i(size / step) + Vector2i.ONE
	for x: int in count.x:
		for y: int in count.y:
			draw_rect(Rect2(Vector2(x, y) * step - Vector2.ONE, Vector2(2, 2)), dot)


func _value(id: int) -> bool:
	return runtime != null and runtime.values.get(id, false)


## Orthogonal route (cells) from the output of [param source] to input pin
## [param pin] of [param target]: across with one step, the step placed
## near the input (each pin of a block steps at its own place) and moved
## left until it passes no block; when the input lies to the left, out to
## the right, below every block on the way and back up into the input.
func _route(source: PlcBlock, target: PlcBlock, pin: int) -> PackedVector2Array:
	var from: Vector2 = output_point(source)
	var to: Vector2 = input_point(target, pin)
	var step: float = to.x - 0.4 - 0.3 * pin
	if step >= from.x + 0.3:
		while step > from.x + 0.3 and _crosses_block(step, from.y, to.y):
			step -= 0.5
		step = maxf(step, from.x + 0.3)
		return PackedVector2Array([from, Vector2(step, from.y), Vector2(step, to.y), to])
	var out: float = from.x + 0.4
	var below: float = 0.0
	for b: PlcBlock in program.blocks:
		var r: Rect2 = body_rect(b)
		if r.end.x >= step and r.position.x <= out:
			below = maxf(below, r.end.y)
	below += 0.6 + 0.3 * pin
	while _crosses_block(out, from.y, below):
		out += 0.5
	return PackedVector2Array([from, Vector2(out, from.y), Vector2(out, below), Vector2(step, below), Vector2(step, to.y), to])


## True when a vertical line at [param x] from [param y0] to [param y1]
## (cells) runs through a block.
func _crosses_block(x: float, y0: float, y1: float) -> bool:
	for b: PlcBlock in program.blocks:
		var r: Rect2 = body_rect(b).grow(0.1)
		if x > r.position.x and x < r.end.x and maxf(y0, y1) > r.position.y and minf(y0, y1) < r.end.y:
			return true
	return false


func _draw_connection(route: PackedVector2Array, on: bool) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in route:
		points.append(_px(p))
	draw_polyline(points, signal_color(on), (2.2 if on and runtime != null else 1.5) * zoom, true)


func _draw_block(b: PlcBlock, tint: Color) -> void:
	var line: Color = SchematicTheme.LINE * tint
	var on: bool = _value(b.id)
	var body: Rect2 = body_rect(b)
	var r: Rect2 = Rect2(_px(body.position), body.size * U * zoom)
	var connector: bool = PlcBlock.CONNECTORS.has(b.type)
	var fill: Color = SchematicTheme.BACKGROUND
	if runtime != null and on and connector:
		fill = Color(ON, 0.25)
	draw_rect(r, fill)
	if b.id == selected and b.id > 0:
		draw_rect(r.grow(4.0 * zoom), Color(AppTheme.accent, 0.25))
	draw_rect(r, line, false, 1.6 * zoom)
	# Input leads with their names.
	for p: int in b.inputs.size():
		var end: Vector2 = _px(input_point(b, p))
		var source: int = b.inputs[p]
		draw_line(end, end + Vector2(LEAD * U * zoom, 0), signal_color(source > 0 and _value(source)) * tint, 1.5 * zoom, true)
		var pin_name: String = PlcBlock.pin_names(b.type)[p]
		if not pin_name.is_empty():
			text(pin_name, Vector2(r.position.x + 3.0 * zoom, end.y), 9, SchematicTheme.TEXT * tint, -1)
	# Output lead (inputs and constants too: they feed others).
	var out: Vector2 = _px(output_point(b))
	var out_start: Vector2 = Vector2(r.end.x, out.y)
	if NEGATED.has(b.type):
		var radius: float = 3.5 * zoom
		draw_arc(out_start + Vector2(radius, 0), radius, 0.0, TAU, 16, line, 1.4 * zoom, true)
		out_start.x += 2.0 * radius
	draw_line(out_start, out, signal_color(on) * tint, 1.5 * zoom, true)
	# Name in the block, number above, parameter below.
	var symbol: String = b.operand if not PlcBlock.operand_area(b.type).is_empty() else SYMBOLS.get(b.type, "")
	var centre: Vector2 = r.get_center()
	if b.inputs.size() > 1 and not connector:
		centre.y = r.position.y + 0.6 * U * zoom
	text(symbol, centre + Vector2(4.0 * zoom if not PlcBlock.pin_names(b.type).has("") and b.inputs.size() > 0 else 0.0, 0), 12, SchematicTheme.TEXT * tint)
	if b.id > 0:
		text(b.label(), Vector2(r.position.x, r.position.y - 7.0 * zoom), 9, SchematicTheme.DESIGNATION * tint, -1)
	var below: String = ""
	if PlcBlock.uses_time(b.type):
		below = "T = " + seconds(b.time)
	elif b.type == "counter":
		below = "On = %d" % b.preset
	if runtime != null:
		var key: String = "B%d" % b.id
		if runtime.timers.has(key) and runtime.timers[key].running:
			below = "Ta = %s / %s" % [seconds(runtime.timers[key].elapsed), seconds(b.time)]
		elif runtime.counters.has(key):
			below = "Cv = %d / %d" % [runtime.counters[key].value, b.preset]
	if not below.is_empty():
		# Above the block on the right, clear of the lines below it.
		text(below, Vector2(r.end.x, r.position.y - 7.0 * zoom), 9, SchematicTheme.TEXT * tint, 1)
