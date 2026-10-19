class_name LessonMarks
extends Node2D
## What a lesson points at on the drawing, in world space over the
## schematic: pulsing rings round the parts a step is about, and with Show
## me the parts still to place drawn faintly where they go (the lesson's
## solution lined up with the schematic by its anchor) and the wires still
## to draw as marching dashes. In the tutorial colour, never the selection's.

const G: float = float(SymbolGeometry.GRID)
## Room between a part and its ring, in pixels.
const RING_GAP: float = 7.0
const DASH: float = 7.0
const GAP: float = 5.0
## Pixels a second the dashes of a wire to draw march along it.
const MARCH: float = 22.0

var view: SchematicView
## Ids of the parts ringed (in the document shown).
var _rings: PackedStringArray = PackedStringArray()
## Bodies of the parts drawn faintly (world pixels).
var _ghost_bodies: Array[Rect2] = []
## Wires to draw: polylines in world pixels.
var _ghost_wires: Array[PackedVector2Array] = []
var _time: float = 0.0


func _ready() -> void:
	z_index = 2


## Rings the parts of [param ring_roles] and, with [param ghosts], draws the
## parts and wires of [param step] still missing. [param edited] is the
## schematic as the lesson sees it; the drawing shown is [member view]'s.
func show_marks(lesson: Lesson, step: Lesson.Step, edited: LessonCheck, ring_roles: PackedStringArray, ghosts: bool) -> void:
	clear()
	if lesson == null or edited == null or view == null or view.document == null:
		return
	var doc: SchematicDocument = view.document
	for role: String in ring_roles:
		if edited.has(role):
			var id: String = edited.part(role).id
			if doc.circuit.has_component_id(id) and doc.page_of(id) == _page(doc):
				_rings.append(id)
	if ghosts and step != null:
		_build_ghosts(lesson, step, edited, doc)
	queue_redraw()


## The page of [param doc] the view shows.
func _page(doc: SchematicDocument) -> int:
	return view.page if view.page >= 0 else doc.page


func clear() -> void:
	for child: Node in get_children():
		child.free()
	_rings.clear()
	_ghost_bodies.clear()
	_ghost_wires.clear()
	queue_redraw()


func has_marks() -> bool:
	return not _rings.is_empty() or not _ghost_bodies.is_empty() or not _ghost_wires.is_empty()


func _build_ghosts(lesson: Lesson, step: Lesson.Step, edited: LessonCheck, doc: SchematicDocument) -> void:
	var solution: SchematicDocument = lesson.solution.call()
	if doc.horizontal:
		solution.transpose()
	# The solution where the schematic's anchor (its first supply) is.
	var offset: Vector2i = Vector2i.ZERO
	var anchor_id: String = lesson.parts.get(lesson.anchor, "")
	if edited.has(lesson.anchor) and doc.circuit.has_component_id(edited.part(lesson.anchor).id) and solution.circuit.has_component_id(anchor_id):
		offset = doc.get_placement(edited.part(lesson.anchor).id).cell - solution.get_placement(anchor_id).cell
	# The parts of the step, and those its wires lead to, still missing.
	var shown: PackedStringArray = step.show.duplicate()
	for wire: Array in step.wires:
		for role: String in [wire[0], wire[2]]:
			if not shown.has(role):
				shown.append(role)
	for role: String in shown:
		if edited.has(role) or not lesson.parts.has(role):
			continue
		var c: CircuitComponent = solution.circuit.get_component(lesson.parts[role])
		if c == null:
			continue
		var p: Placement = solution.get_placement(c.id)
		var placement: Placement = Placement.new(p.cell + offset, p.rotation, p.mirrored)
		var symbol: SchematicSymbol = SymbolFactory.create(c, placement)
		symbol.modulate = Color(1, 1, 1, 0.45)
		add_child(symbol)
		var body: Rect2 = solution.component_body(c)
		body.position += Vector2(offset)
		_ghost_bodies.append(Rect2(body.position * G, body.size * G))
	for wire: Array in step.wires:
		var a: String = edited.key(wire[0], wire[1])
		var b: String = edited.key(wire[2], wire[3])
		if not a.is_empty() and not b.is_empty() and edited.joined(a, b):
			continue
		var from: Variant = _terminal_point(wire[0], wire[1], edited, doc, solution, lesson, offset)
		var to: Variant = _terminal_point(wire[2], wire[3], edited, doc, solution, lesson, offset)
		if from == null or to == null:
			continue
		var start: Vector2 = from
		var end: Vector2 = to
		var path: PackedVector2Array = PackedVector2Array([start])
		if not is_equal_approx(start.x, end.x) and not is_equal_approx(start.y, end.y):
			# Down (or across, lying) first, as the current paths run.
			path.append(Vector2(end.x, start.y) if doc.horizontal else Vector2(start.x, end.y))
		path.append(end)
		_ghost_wires.append(path)


## Where terminal [param index] of the part of [param role] is (world
## pixels): on the schematic's part, else on the part drawn faintly; null
## when neither is on the page shown.
func _terminal_point(role: String, index: int, edited: LessonCheck, doc: SchematicDocument, solution: SchematicDocument, lesson: Lesson, offset: Vector2i) -> Variant:
	if edited.has(role):
		var key: String = edited.key(role, index)
		var id: String = edited.part(role).id
		if key.is_empty() or not doc.circuit.has_component_id(id) or doc.page_of(id) != _page(doc):
			return null
		return Vector2(doc.terminal_cell(key)) * G
	var c: CircuitComponent = solution.circuit.get_component(lesson.parts.get(role, ""))
	if c == null or index >= c.get_terminal_keys().size():
		return null
	return Vector2(solution.terminal_cell(c.get_terminal_keys()[index]) + offset) * G


func _process(delta: float) -> void:
	if not visible or not has_marks():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if view == null or view.document == null:
		return
	var color: Color = AppTheme.tutorial
	var pulse: float = 0.5 + 0.5 * sin(_time * TAU / 1.6)
	var zoom: float = maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)
	var width: float = 2.0 / zoom
	for id: String in _rings:
		if not view.document.circuit.has_component_id(id):
			continue
		var body: Rect2 = view.document.component_body(view.document.circuit.get_component(id))
		var r: Rect2 = Rect2(body.position * G, body.size * G).grow(RING_GAP / zoom)
		_round_rect(r.grow((2.0 + 6.0 * pulse) / zoom), Color(color, 0.35 * (1.0 - pulse)), width * 2.0)
		_round_rect(r, color, width)
	for body: Rect2 in _ghost_bodies:
		var r: Rect2 = body.grow(RING_GAP / zoom)
		draw_rect(r, Color(color, 0.08))
		_dashed(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]), color, width, 0.0, zoom)
	for path: PackedVector2Array in _ghost_wires:
		_dashed(path, color, width * 1.4, -_time * MARCH / zoom, zoom)
		for point: Vector2 in [path[0], path[path.size() - 1]]:
			draw_circle(point, 3.5 / zoom, color, true, -1.0, true)


## Rounded rectangle outline, as a polyline.
func _round_rect(r: Rect2, color: Color, width: float) -> void:
	var radius: float = minf(minf(r.size.x, r.size.y) * 0.5, 8.0 * width)
	var points: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [r.position + Vector2(radius, radius), Vector2(r.end.x - radius, r.position.y + radius), r.end - Vector2(radius, radius), Vector2(r.position.x + radius, r.end.y - radius)]
	for k: int in 4:
		for i: int in 7:
			var a: float = PI + k * PI * 0.5 + i * PI / 12.0
			points.append(corners[k] + Vector2(cos(a), sin(a)) * radius)
	points.append(points[0])
	draw_polyline(points, color, width, true)


## Dashed polyline whose dashes start [param phase] pixels along it.
func _dashed(path: PackedVector2Array, color: Color, width: float, phase: float, zoom: float) -> void:
	var dash: float = DASH / zoom
	var period: float = (DASH + GAP) / zoom
	var along: float = fposmod(phase, period) - period
	for k: int in range(1, path.size()):
		var a: Vector2 = path[k - 1]
		var b: Vector2 = path[k]
		var length: float = a.distance_to(b)
		if length <= 0.0:
			continue
		var direction: Vector2 = (b - a) / length
		var t: float = along
		while t < length:
			var s0: float = maxf(t, 0.0)
			var s1: float = minf(t + dash, length)
			if s1 > s0:
				draw_line(a + direction * s0, a + direction * s1, color, width, true)
			t += period
		along = t - length - period
