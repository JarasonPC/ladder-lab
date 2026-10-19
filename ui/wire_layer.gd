class_name WireLayer
extends Node2D
## Draws the grid, the wires and junction dots of a page of a
## [SchematicDocument] (the current page unless [member page] is set).
## Voltage view: wires reached by a phase are drawn in that phase's colour,
## wires reached by N in the neutral colour. Current view ([member
## current_view]): only wires that carry current are coloured, the thicker
## the more current, with the current written in the middle of their longest
## segment. During a short the fault-current path blinks on top.

const G: float = float(SymbolGeometry.GRID)

var document: SchematicDocument
## Reach code per wire (see [StepResult]); empty or 0 for wires without voltage.
var wire_reach: PackedByteArray = PackedByteArray()
## Wires carrying the short-circuit current (empty when there is no short).
var fault_wires: Dictionary[int, bool] = {}
var blink_on: bool = true
## Dot grid behind the drawing (off unless chosen for editing).
var show_grid: bool = false
## Wire numbers at the wire ends.
var show_numbers: bool = true
## Draw the current path numbers.
var show_path_numbers: bool = true
## Current per wire in amperes (see [member StepResult.wire_currents]).
var wire_currents: PackedFloat32Array = PackedFloat32Array()
## Current view instead of voltage view.
var current_view: bool = false
## Clamp meters: wire index -> grid point (see [member SchematicView.clamps]).
var clamps: Dictionary[int, Vector2] = {}
## A short circuit lasts (clamp meters show it instead of a value).
var short_circuit: bool = false
## Smallest current shown, amperes.
const MIN_CURRENT: float = 0.0005
## Page drawn; -1: the document's current page.
var page: int = -1

var _junctions: Array[Vector2i] = []
## [Vector2i(wire, end), Rect2 in cells] of the numbers drawn last.
var _number_rects: Array = []
## Boxes (in cells) of the current path numbers drawn last.
var _path_rects: Array[Rect2] = []


func set_document(doc: SchematicDocument) -> void:
	document = doc
	refresh_layout()


## Recomputes cached geometry after placements changed.
func refresh_layout() -> void:
	_junctions = document.junction_cells(page) if document != null else []
	queue_redraw()


func _draw() -> void:
	if document == null:
		return
	if show_grid:
		var area: Rect2 = document.bounds(page).grow(4.0)
		for x: int in range(floori(area.position.x), ceili(area.end.x) + 1):
			for y: int in range(floori(area.position.y), ceili(area.end.y) + 1):
				draw_rect(Rect2(Vector2(x, y) * G - Vector2.ONE, Vector2(2, 2)), SchematicTheme.GRID_DOT)

	# Dead wires first, then N and DC -, then the phases and DC + on top.
	var wires: PackedInt32Array = document.wires_on_page(page)
	for pass_codes: Array in [[StepResult.REACH_NONE], [StepResult.REACH_N, StepResult.REACH_PE, StepResult.REACH_DC_MINUS], [StepResult.REACH_L1, StepResult.REACH_L2, StepResult.REACH_L3, StepResult.REACH_DC_PLUS, StepResult.REACH_SEVERAL]]:
		for w: int in wires:
			var code: int = _reach(w)
			if pass_codes.has(code):
				var width: float = SchematicTheme.LINE_WIDTH if code == StepResult.REACH_NONE else SchematicTheme.LIVE_WIDTH
				if current_view and code != StepResult.REACH_NONE:
					width = current_width(wire_currents[w])
				draw_polyline(_pixels(w), SchematicTheme.reach_color(code), width)
	if blink_on:
		for w: int in fault_wires:
			if wires.has(w):
				draw_polyline(_pixels(w), SchematicTheme.FAULT, SchematicTheme.LIVE_WIDTH)
	for w: int in document.circuit.broken_wires:
		if wires.has(w):
			_draw_break(w)
	for cell: Vector2i in _junctions:
		draw_circle(Vector2(cell) * G, 3.6, SchematicTheme.reach_color(_reach_at(cell, wires)))
	if show_numbers:
		_draw_wire_numbers()
	if current_view and fault_wires.is_empty():
		_draw_currents(wires)
	_draw_clamps(wires)
	if show_path_numbers:
		_draw_path_numbers()
	else:
		_path_rects.clear()


## Clamp meters: jaws around the wire and a display beside them with the
## current of the wire (in either view).
func _draw_clamps(wires: PackedInt32Array) -> void:
	var font: Font = AppTheme.schematic_font()
	var size: int = 11
	for w: int in clamps:
		if not wires.has(w):
			continue
		var at: Vector2 = clamps[w] * G
		var points: Array[Vector2i] = document.wire_points(w)
		var vertical: bool = false
		for s: int in range(1, points.size()):
			var a: Vector2 = Vector2(points[s - 1]) * G
			var b: Vector2 = Vector2(points[s]) * G
			if Geometry2D.get_closest_point_to_segment(at, a, b).distance_to(at) < 0.5:
				vertical = is_equal_approx(a.x, b.x)
				break
		# Jaws: a ring open on the side of the display.
		var side: Vector2 = Vector2(1, 0) if vertical else Vector2(0, -1)
		var open_angle: float = side.angle()
		draw_arc(at, 8.0, open_angle + 0.5, open_angle + TAU - 0.5, 24, SchematicTheme.TEXT, 2.5, true)
		var text: String
		var color: Color = SchematicTheme.TEXT
		if fault_wires.has(w):
			text = tr("short")
			color = SchematicTheme.FAULT
		else:
			text = SchematicTheme.amperes(wire_currents[w]) if w < wire_currents.size() and wire_currents[w] >= MIN_CURRENT else "0.00 A"
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var box_size: Vector2 = text_size + Vector2(10.0, 6.0)
		var handle: Vector2 = at + side * 8.0
		var box_at: Vector2 = handle + side * 10.0
		var box: Rect2 = Rect2(box_at - Vector2(0.0, box_size.y * 0.5), box_size) if vertical else Rect2(box_at - Vector2(box_size.x * 0.5, box_size.y), box_size)
		draw_line(handle, box_at, SchematicTheme.TEXT, 2.0)
		draw_rect(box, SchematicTheme.BACKGROUND)
		draw_rect(box, SchematicTheme.CURRENT, false, 1.5)
		draw_string(font, box.position + Vector2(5.0, 3.0 + font.get_ascent(size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Writes the current of every wire carrying one beside its longest segment:
## right of a vertical one, above a horizontal one.
func _draw_currents(wires: PackedInt32Array) -> void:
	var font: Font = AppTheme.schematic_font()
	var size: int = 9
	for w: int in wires:
		if w >= wire_currents.size() or wire_currents[w] < MIN_CURRENT:
			continue
		var points: Array[Vector2i] = document.wire_points(w)
		if points.size() < 2:
			continue
		var best: int = 1
		for s: int in range(1, points.size()):
			if Vector2(points[s] - points[s - 1]).length() > Vector2(points[best] - points[best - 1]).length():
				best = s
		var a: Vector2 = Vector2(points[best - 1]) * G
		var b: Vector2 = Vector2(points[best]) * G
		var middle: Vector2 = (a + b) * 0.5
		var text: String = SchematicTheme.amperes(wire_currents[w])
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var pos: Vector2
		if is_equal_approx(a.x, b.x):
			pos = middle + Vector2(4.0, font.get_ascent(size) * 0.5)
		else:
			pos = middle + Vector2(-text_size.x * 0.5, -4.0)
		draw_rect(Rect2(pos - Vector2(1.0, font.get_ascent(size)), text_size + Vector2(2.0, 0.0)), SchematicTheme.BACKGROUND)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SchematicTheme.CURRENT)


## Writes the wire numbers at the wire ends listed by
## [method SchematicDocument.wire_number_ends] next to the terminal: beside a
## vertical wire, above a horizontal one (running away from the terminal),
## moved by the offset the user dragged them by.
func _draw_wire_numbers() -> void:
	_number_rects.clear()
	var font: Font = AppTheme.schematic_font()
	var size: int = 10
	for e: Vector2i in document.wire_number_ends(page):
		var number: String = document.get_route(e.x).number
		var at: Vector2 = document.wire_number_point(e.x, e.y) * G
		var text_size: Vector2 = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var pos: Vector2
		var direction: Vector2i = document.wire_number_direction(e.x, e.y)
		if direction.x == 0:
			pos = at + Vector2(-text_size.x - 4.0, font.get_ascent(size) * 0.5)
		elif direction.x > 0:
			pos = at + Vector2(0.0, -4.0)
		else:
			pos = at + Vector2(-text_size.x, -4.0)
		draw_string(font, pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SchematicTheme.WIRE_NUMBER)
		var rect: Rect2 = Rect2(pos - Vector2(0.0, font.get_ascent(size)), text_size).grow(2.0)
		_number_rects.append([e, Rect2(rect.position / G, rect.size / G)])


## Everything this layer drew last outside the wires, in cells: wire numbers
## and current path numbers (empty Rect2 when nothing).
func drawn_extent() -> Rect2:
	var r: Rect2 = Rect2()
	var first: bool = true
	for entry: Array in _number_rects:
		r = (entry[1] as Rect2) if first else r.merge(entry[1])
		first = false
	for rect: Rect2 in _path_rects:
		r = rect if first else r.merge(rect)
		first = false
	return r


## Box (in cells) around the number of wire end [param end] as last drawn,
## or an empty Rect2.
func wire_number_rect(end: Vector2i) -> Rect2:
	for entry: Array in _number_rects:
		if entry[0] == end:
			return entry[1]
	return Rect2()


## Wire end whose number is written at grid point [param point], as
## Vector2i(wire, end), or Vector2i(-1, -1).
func wire_number_at(point: Vector2) -> Vector2i:
	if not show_numbers:
		return Vector2i(-1, -1)
	for i: int in range(_number_rects.size() - 1, -1, -1):
		if (_number_rects[i][1] as Rect2).has_point(point):
			return _number_rects[i][0]
	return Vector2i(-1, -1)


## Numbers the current paths: above the columns of a vertical drawing, left of
## the rows of a horizontal one; the number alone, no box.
func _draw_path_numbers() -> void:
	_path_rects.clear()
	var paths: PackedFloat32Array = document.current_paths(2.0, page)
	if paths.is_empty():
		return
	var b: Rect2 = document.bounds(page)
	var font: Font = AppTheme.schematic_font()
	var size: int = SchematicTheme.LABEL_SIZE
	var box: Vector2 = Vector2(1.4, 1.0) * G
	for i: int in paths.size():
		var center: Vector2
		if document.horizontal:
			center = Vector2(b.position.x - 2.0, paths[i]) * G
		else:
			center = Vector2(paths[i], b.position.y - 1.5) * G
		var rect: Rect2 = Rect2(center - box * 0.5, box)
		_path_rects.append(Rect2(rect.position / G, rect.size / G))
		var text: String = str(i + 1)
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, center + Vector2(-w * 0.5, font.get_ascent(size) * 0.5 - 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SchematicTheme.PATH_TEXT)


## Line width of a wire carrying [param amperes] in the current view: from
## the live width at a few milliamperes to about twice it at 100 A.
static func current_width(amperes: float) -> float:
	var decades: float = clampf(log(maxf(amperes, 0.001) / 0.01) / log(10.0), 0.0, 4.0)
	return SchematicTheme.LIVE_WIDTH + decades * 0.7


## Reach code of a wire as drawn: in the current view only while it carries current.
func _reach(wire_index: int) -> int:
	if wire_index >= wire_reach.size():
		return StepResult.REACH_NONE
	if current_view and (wire_index >= wire_currents.size() or wire_currents[wire_index] < MIN_CURRENT) and not fault_wires.has(wire_index):
		return StepResult.REACH_NONE
	return wire_reach[wire_index]


## Reach code of the [param wires] through a junction cell (they all share one net).
func _reach_at(cell: Vector2i, wires: PackedInt32Array) -> int:
	for w: int in wires:
		if _reach(w) == StepResult.REACH_NONE:
			continue
		var points: Array[Vector2i] = document.wire_points(w)
		for s: int in range(1, points.size()):
			if SchematicDocument._on_segment(cell, points[s - 1], points[s]):
				return _reach(w)
	return StepResult.REACH_NONE


## Marks a broken wire: a gap with a red cross in the middle of its longest segment.
func _draw_break(wire_index: int) -> void:
	var points: Array[Vector2i] = document.wire_points(wire_index)
	var best: int = 1
	for s: int in range(1, points.size()):
		if Vector2(points[s] - points[s - 1]).length() > Vector2(points[best] - points[best - 1]).length():
			best = s
	var middle: Vector2 = (Vector2(points[best - 1]) + Vector2(points[best])) * 0.5 * G
	draw_circle(middle, 7.0, SchematicTheme.BACKGROUND)
	draw_line(middle + Vector2(-5, -5), middle + Vector2(5, 5), SchematicTheme.FAULT, 2.5)
	draw_line(middle + Vector2(-5, 5), middle + Vector2(5, -5), SchematicTheme.FAULT, 2.5)


func _pixels(wire_index: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for p: Vector2i in document.wire_points(wire_index):
		points.append(Vector2(p) * G)
	return points
