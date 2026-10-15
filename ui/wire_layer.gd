class_name WireLayer
extends Node2D
## Draws the grid, all wires and junction dots of a [SchematicDocument].
## Wires at L potential (voltage reach) are drawn on top in the live colour;
## during a short the fault-current path blinks on top of that.

const G: float = float(SymbolGeometry.GRID)

var document: SchematicDocument
var live_wires: Dictionary[int, bool] = {}
## Wires carrying the short-circuit current (empty when there is no short).
var fault_wires: Dictionary[int, bool] = {}
var blink_on: bool = true

var _junctions: Array[Vector2i] = []


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
	var area: Rect2 = document.bounds().grow(4.0)
	for x: int in range(floori(area.position.x), ceili(area.end.x) + 1):
		for y: int in range(floori(area.position.y), ceili(area.end.y) + 1):
			draw_rect(Rect2(Vector2(x, y) * G - Vector2.ONE, Vector2(2, 2)), SchematicTheme.GRID_DOT)

	for w: int in document.get_wire_count():
		if not live_wires.has(w):
			draw_polyline(_pixels(w), SchematicTheme.LINE, SchematicTheme.LINE_WIDTH)
	for w: int in document.get_wire_count():
		if live_wires.has(w):
			draw_polyline(_pixels(w), SchematicTheme.LIVE, SchematicTheme.LIVE_WIDTH)
	if blink_on:
		for w: int in fault_wires:
			draw_polyline(_pixels(w), SchematicTheme.FAULT, SchematicTheme.LIVE_WIDTH)
	for cell: Vector2i in _junctions:
		draw_circle(Vector2(cell) * G, 4.0, SchematicTheme.LIVE if _on_live_wire(cell) else SchematicTheme.LINE)
	_draw_path_numbers()


## Numbers the current paths: above the columns of a vertical drawing, left of
## the rows of a horizontal one.
func _draw_path_numbers() -> void:
	var paths: PackedFloat32Array = document.current_paths()
	if paths.is_empty():
		return
	var b: Rect2 = document.bounds()
	var font: Font = ThemeDB.fallback_font
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
		draw_rect(rect, SchematicTheme.TERMINAL_TEXT, false, 1.0)
		var text: String = str(i + 1)
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, center + Vector2(-w * 0.5, font.get_ascent(size) * 0.5 - 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SchematicTheme.TERMINAL_TEXT)


func _on_live_wire(cell: Vector2i) -> bool:
	for w: int in live_wires:
		var points: Array[Vector2i] = document.wire_points(w)
		for s: int in range(1, points.size()):
			if SchematicDocument._on_segment(cell, points[s - 1], points[s]):
				return true
	return false


func _pixels(wire_index: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for p: Vector2i in document.wire_points(wire_index):
		points.append(Vector2(p) * G)
	return points
