class_name WireLayer
extends Node2D
## Draws the grid, the wires and junction dots of the current page of a
## [SchematicDocument].
## Wires reached by a phase are drawn in that phase's colour, wires reached by
## N in the neutral colour; during a short the fault-current path blinks on top.

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

var _junctions: Array[Vector2i] = []
## [Vector2i(wire, end), Rect2 in cells] of the numbers drawn last.
var _number_rects: Array = []


func set_document(doc: SchematicDocument) -> void:
	document = doc
	refresh_layout()


## Recomputes cached geometry after placements changed.
func refresh_layout() -> void:
	_junctions = document.junction_cells() if document != null else []
	queue_redraw()


func _draw() -> void:
	if document == null:
		return
	if show_grid:
		var area: Rect2 = document.bounds().grow(4.0)
		for x: int in range(floori(area.position.x), ceili(area.end.x) + 1):
			for y: int in range(floori(area.position.y), ceili(area.end.y) + 1):
				draw_rect(Rect2(Vector2(x, y) * G - Vector2.ONE, Vector2(2, 2)), SchematicTheme.GRID_DOT)

	# Dead wires first, then N and DC -, then the phases and DC + on top.
	var wires: PackedInt32Array = document.wires_on_page()
	for pass_codes: Array in [[StepResult.REACH_NONE], [StepResult.REACH_N, StepResult.REACH_DC_MINUS], [StepResult.REACH_L1, StepResult.REACH_L2, StepResult.REACH_L3, StepResult.REACH_DC_PLUS, StepResult.REACH_SEVERAL]]:
		for w: int in wires:
			var code: int = _reach(w)
			if pass_codes.has(code):
				var width: float = SchematicTheme.LINE_WIDTH if code == StepResult.REACH_NONE else SchematicTheme.LIVE_WIDTH
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
	_draw_path_numbers()


## Writes the wire numbers at the wire ends listed by
## [method SchematicDocument.wire_number_ends]: beside a vertical wire, above
## a horizontal one, moved by the offset the user dragged them by.
func _draw_wire_numbers() -> void:
	_number_rects.clear()
	var font: Font = AppTheme.schematic_font()
	var size: int = 10
	for e: Vector2i in document.wire_number_ends():
		var number: String = document.get_route(e.x).number
		var at: Vector2 = document.wire_number_point(e.x, e.y) * G
		var text_size: Vector2 = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var pos: Vector2
		if document.wire_number_vertical(e.x, e.y):
			pos = at + Vector2(-text_size.x - 4.0, font.get_ascent(size) * 0.5)
		else:
			pos = at + Vector2(-text_size.x * 0.5, -4.0)
		draw_string(font, pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SchematicTheme.WIRE_NUMBER)
		var rect: Rect2 = Rect2(pos - Vector2(0.0, font.get_ascent(size)), text_size).grow(2.0)
		_number_rects.append([e, Rect2(rect.position / G, rect.size / G)])


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
## the rows of a horizontal one.
func _draw_path_numbers() -> void:
	var paths: PackedFloat32Array = document.current_paths()
	if paths.is_empty():
		return
	var b: Rect2 = document.bounds()
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
		draw_rect(rect, SchematicTheme.BACKGROUND)
		draw_rect(rect, SchematicTheme.PATH_TEXT, false, 1.0)
		var text: String = str(i + 1)
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, center + Vector2(-w * 0.5, font.get_ascent(size) * 0.5 - 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SchematicTheme.PATH_TEXT)


func _reach(wire_index: int) -> int:
	return wire_reach[wire_index] if wire_index < wire_reach.size() else StepResult.REACH_NONE


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
