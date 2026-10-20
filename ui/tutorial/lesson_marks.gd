class_name LessonMarks
extends Node2D
## What a lesson points at on the drawing, in world space over the
## schematic: pulsing rings round the parts a step is about, round the
## terminals of the wires it asks for and along the wires it asks to delete
## (crossed out); with Show me the parts still to place drawn faintly where
## they go (the lesson's solution lined up with the schematic by its anchor)
## and the wires still to draw as marching dashes. In the tutorial colour,
## never the selection's.

const G: float = float(SymbolGeometry.GRID)
## Room between a part and its ring, in pixels.
const RING_GAP: float = 7.0
## Radius of the ring round a terminal to wire, in pixels.
const TERMINAL_RING: float = 11.0
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
## Terminals of the wires still to draw (world pixels).
var _terminals: Array[Vector2] = []
## Wires to delete: polylines in world pixels.
var _cuts: Array[PackedVector2Array] = []
## The editor drawing wires: while a wire starts from a terminal of a wire
## still to draw, a guide runs to the terminal it should end on.
var editor: SchematicEditor
## Terminal keys of each wire still to draw on the page shown.
var _pending: Array[PackedStringArray] = []
## The schematic the marks were made from (terminals joined by wires).
var _edited: LessonCheck = null
var _time: float = 0.0


func _ready() -> void:
	z_index = 2


## Rings the parts of [param ring_roles]; while [param editing], the
## terminals of the wires [param step] asks for and the wires it asks to
## delete; with [param ghosts] also draws its parts and wires still missing.
## [param edited] is the schematic as the lesson sees it; the drawing shown
## is [member view]'s.
func show_marks(lesson: Lesson, step: Lesson.Step, edited: LessonCheck, ring_roles: PackedStringArray, editing: bool, ghosts: bool) -> void:
	clear()
	if lesson == null or edited == null or view == null or view.document == null:
		return
	var doc: SchematicDocument = view.document
	for role: String in ring_roles:
		if edited.has(role):
			var id: String = edited.part(role).id
			if doc.circuit.has_component_id(id) and doc.page_of(id) == _page(doc):
				_rings.append(id)
	if editing and step != null:
		_mark_wiring(step, edited, doc)
	if editing and ghosts and step != null:
		_build_ghosts(lesson, step, edited, doc)
	queue_redraw()


## The terminals of the wires of [param step] not drawn yet, on parts the
## schematic has, and the wires it asks to delete that are still there.
func _mark_wiring(step: Lesson.Step, edited: LessonCheck, doc: SchematicDocument) -> void:
	for wire: Array in step.wires:
		var a: String = edited.key(wire[0], wire[1])
		var b: String = edited.key(wire[2], wire[3])
		if not a.is_empty() and not b.is_empty() and edited.joined(a, b):
			continue
		for key: String in [a, b]:
			if _on_page(key, doc):
				var point: Vector2 = Vector2(doc.terminal_cell(key)) * G
				if not _terminals.has(point):
					_terminals.append(point)
		if _on_page(a, doc) and _on_page(b, doc):
			_pending.append(PackedStringArray([a, b]))
	_edited = edited
	for wire: Array in step.cut:
		var a: String = edited.key(wire[0], wire[1])
		var b: String = edited.key(wire[2], wire[3])
		if not _on_page(a, doc) or not _on_page(b, doc):
			continue
		var index: int = doc.wire_between(a, b)
		if index < 0:
			continue
		var path: PackedVector2Array = PackedVector2Array()
		for cell: Vector2i in doc.wire_points(index):
			path.append(Vector2(cell) * G)
		_cuts.append(path)


## True when a part of the page shown stands where [param body] (grid
## units) would be drawn: a part placed there, whatever it is, hides the
## faint one.
func _taken(body: Rect2, doc: SchematicDocument) -> bool:
	var inner: Rect2 = body.grow(-0.2)
	for c: CircuitComponent in doc.components_on_page(_page(doc)):
		if not (c is Junction) and doc.component_body(c).intersects(inner):
			return true
	return false


## True when terminal [param key] is on a part of the page shown.
func _on_page(key: String, doc: SchematicDocument) -> bool:
	if key.is_empty() or not doc.circuit.has_terminal(key):
		return false
	return doc.page_of(doc.circuit.get_terminal_owner(key).id) == _page(doc)


## The page of [param doc] the view shows.
func _page(doc: SchematicDocument) -> int:
	return view.page if view.page >= 0 else doc.page


func clear() -> void:
	for child: Node in get_children():
		child.free()
	_rings.clear()
	_ghost_bodies.clear()
	_ghost_wires.clear()
	_terminals.clear()
	_cuts.clear()
	_pending.clear()
	_edited = null
	queue_redraw()


func has_marks() -> bool:
	return not _rings.is_empty() or not _ghost_bodies.is_empty() or not _ghost_wires.is_empty() or not _terminals.is_empty() or not _cuts.is_empty()


## Where the wire being drawn should end: the other terminal of a wire still
## to draw that starts at its terminal (or at one joined to it); "" for none.
func guide_target() -> String:
	var start: String = editor.wire_start() if editor != null else ""
	if start.is_empty() or _edited == null:
		return ""
	# Its own terminal first, then one already wired to it.
	for joined: bool in [false, true]:
		for pair: PackedStringArray in _pending:
			for end: int in 2:
				if pair[end] == start or (joined and _edited.joined(start, pair[end])):
					return pair[1 - end]
	return ""


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
		var body: Rect2 = solution.component_body(c)
		body.position += Vector2(offset)
		if _taken(body, doc):
			continue
		var p: Placement = solution.get_placement(c.id)
		var placement: Placement = Placement.new(p.cell + offset, p.rotation, p.mirrored)
		var symbol: SchematicSymbol = SymbolFactory.create(c, placement)
		symbol.modulate = Color(1, 1, 1, 0.45)
		add_child(symbol)
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
	for point: Vector2 in _terminals:
		_terminal_ring(point, color, pulse, zoom, 1.0)
	var target: String = guide_target()
	if not target.is_empty() and view.document.circuit.has_terminal(target):
		# The wire being drawn: dashes from its start to where it should end.
		var from: Vector2 = Vector2(view.document.terminal_cell(editor.wire_start())) * G
		var to: Vector2 = Vector2(view.document.terminal_cell(target)) * G
		var path: PackedVector2Array = PackedVector2Array([from])
		if not is_equal_approx(from.x, to.x) and not is_equal_approx(from.y, to.y):
			path.append(Vector2(to.x, from.y) if view.document.horizontal else Vector2(from.x, to.y))
		path.append(to)
		_dashed(path, color, width * 1.6, -_time * MARCH / zoom, zoom)
		_terminal_ring(to, color, pulse, zoom, 1.5)
	for path: PackedVector2Array in _cuts:
		draw_polyline(path, Color(color, 0.35 + 0.35 * pulse), width * 4.0, true)
		# Crossed out at the middle of its longest run.
		var middle: Vector2 = _middle(path)
		var arm: float = 7.0 / zoom
		draw_line(middle + Vector2(-arm, -arm), middle + Vector2(arm, arm), color, width * 1.5, true)
		draw_line(middle + Vector2(-arm, arm), middle + Vector2(arm, -arm), color, width * 1.5, true)
	for path: PackedVector2Array in _ghost_wires:
		_dashed(path, color, width * 1.4, -_time * MARCH / zoom, zoom)
		for point: Vector2 in [path[0], path[path.size() - 1]]:
			draw_circle(point, 3.5 / zoom, color, true, -1.0, true)


## A terminal to wire: a filled disc with a thick ring and a ring pulsing
## out of it, [param scale] times the usual size.
func _terminal_ring(point: Vector2, color: Color, pulse: float, zoom: float, scale: float) -> void:
	var radius: float = TERMINAL_RING * scale / zoom
	draw_circle(point, radius, Color(color, 0.22), true, -1.0, true)
	draw_arc(point, radius + (4.0 + 12.0 * pulse) * scale / zoom, 0.0, TAU, 40, Color(color, 0.55 * (1.0 - pulse)), 3.0 / zoom, true)
	draw_arc(point, radius, 0.0, TAU, 40, color, 3.0 / zoom, true)


## Middle of the longest run of [param path].
static func _middle(path: PackedVector2Array) -> Vector2:
	var best: float = -1.0
	var middle: Vector2 = path[0]
	for k: int in range(1, path.size()):
		var length: float = path[k - 1].distance_to(path[k])
		if length > best:
			best = length
			middle = (path[k - 1] + path[k]) * 0.5
	return middle


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
