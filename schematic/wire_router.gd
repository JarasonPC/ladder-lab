class_name WireRouter
extends RefCounted
## Finds routes for wires on one page: along the grid lines, across and down
## only, never through a symbol, over a terminal of another net or along a
## wire of another net (any of these would look like a connection that is not
## there), with few corners and few crossings. Built once for a page; wires
## routed one after another are added with [method add_wire], so the next
## one keeps off them. No nodes.

## Costs: a cell of wire, a corner, crossing a wire of another net, a corner
## on a wire of another net (two corners touching look joined), a cell along
## a wire of the same net, and a cell that would look connected (through a
## symbol, over another net's terminal or along its wire). Routes that cannot
## avoid the last take as few such cells as they can.
const STEP: int = 4
const BEND: int = 3
const CROSS: int = 2
const TOUCH: int = 8
const SHARED: int = 1
const BLOCKED: int = 1000
## Leaving a terminal other than straight out along its lead: more than a
## hook past the end of the lead (a corner and two cells), less than a step
## out and back (two corners and two cells), which looks worse than leaving
## sideways.
const LEAD: int = 12
## Free cells around everything on the page.
const MARGIN: int = 4
## Cells around the ends of a wire searched first.
const WINDOW: int = 12
## Cells from an end within which a step that looks connected is taken as
## forced by the end's surroundings.
const NEAR_END: int = 2
## Fewer cells than this around an end that a wire can reach cleanly: the
## end is hemmed in.
const HEMMED: int = 24
## Nets in the edge and cell maps: none, or several.
const NONE: int = -1
const MANY: int = -2

## Unit steps by direction index: right, down, left, up.
const STEPS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var _origin: Vector2i
var _width: int
var _height: int
## Per cell: 1 if the edge to the right (h) or down (v) neighbour runs
## through a symbol.
var _body_h: PackedByteArray = PackedByteArray()
var _body_v: PackedByteArray = PackedByteArray()
## Per cell: the net of the wires along its right / down edge, or of the
## wires through it.
var _edge_h: PackedInt32Array = PackedInt32Array()
var _edge_v: PackedInt32Array = PackedInt32Array()
var _cell_net: PackedInt32Array = PackedInt32Array()
## Per cell: the net of the terminals on it.
var _terminal_net: PackedInt32Array = PackedInt32Array()
## Open states of [method find]: a binary heap of (estimate, state).
var _heap_key: PackedInt32Array = PackedInt32Array()
var _heap_state: PackedInt32Array = PackedInt32Array()
## Cost of the route the last search found, and whether it would look
## connected somewhere else than next to its ends.
var _found_cost: int = 0
var _blocked_midway: bool = false


## [param area]: cells routes may use (grown by [constant MARGIN]).
func _init(area: Rect2i) -> void:
	area = area.grow(MARGIN)
	_origin = area.position
	_width = area.size.x + 1
	_height = area.size.y + 1
	var cells: int = _width * _height
	_body_h.resize(cells)
	_body_v.resize(cells)
	_edge_h.resize(cells)
	_edge_h.fill(NONE)
	_edge_v.resize(cells)
	_edge_v.fill(NONE)
	_cell_net.resize(cells)
	_cell_net.fill(NONE)
	_terminal_net.resize(cells)
	_terminal_net.fill(NONE)


func has_cell(cell: Vector2i) -> bool:
	var c: Vector2i = cell - _origin
	return c.x >= 0 and c.y >= 0 and c.x < _width and c.y < _height


func _index(cell: Vector2i) -> int:
	return (cell.y - _origin.y) * _width + cell.x - _origin.x


static func _join(old: int, net: int) -> int:
	return net if old == NONE or old == net else MANY


## A symbol body: wires may not cross its inside.
func add_body(body: Rect2) -> void:
	# Vertical edges on grid lines strictly inside the body, horizontal ones
	# likewise.
	for x: int in range(floori(body.position.x) + 1, ceili(body.end.x)):
		for y: int in range(floori(body.position.y), ceili(body.end.y)):
			var cell: Vector2i = Vector2i(x, y)
			if has_cell(cell) and has_cell(cell + Vector2i.DOWN):
				_body_v[_index(cell)] = 1
	for y: int in range(floori(body.position.y) + 1, ceili(body.end.y)):
		for x: int in range(floori(body.position.x), ceili(body.end.x)):
			var cell: Vector2i = Vector2i(x, y)
			if has_cell(cell) and has_cell(cell + Vector2i.RIGHT):
				_body_h[_index(cell)] = 1


func add_terminal(cell: Vector2i, net: int) -> void:
	if has_cell(cell):
		var i: int = _index(cell)
		_terminal_net[i] = _join(_terminal_net[i], net)


## A wire of [param net] already drawn along [param points].
func add_wire(points: Array[Vector2i], net: int) -> void:
	for s: int in range(1, points.size()):
		var a: Vector2i = points[s - 1] - _origin
		var b: Vector2i = points[s] - _origin
		var lo: Vector2i = Vector2i(mini(a.x, b.x), mini(a.y, b.y))
		var hi: Vector2i = Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
		if lo.x < 0 or lo.y < 0 or hi.x >= _width or hi.y >= _height:
			continue
		var i: int = lo.y * _width + lo.x
		var stride: int = 1 if a.y == b.y else _width
		for k: int in (hi - lo).x + (hi - lo).y + 1:
			_cell_net[i] = _join(_cell_net[i], net)
			if k < (hi - lo).x + (hi - lo).y:
				if a.y == b.y:
					_edge_h[i] = _join(_edge_h[i], net)
				else:
					_edge_v[i] = _join(_edge_v[i], net)
			i += stride


static func _other(value: int, net: int) -> bool:
	return value == MANY or (value != NONE and value != net)


## Cost of the edge from [param cell] one step in direction [param d]
## (index into [constant STEPS]) for a wire of [param net], or -1 off the
## area.
func _edge_cost(cell: Vector2i, d: int, net: int) -> int:
	var next: Vector2i = cell + STEPS[d]
	if not has_cell(next):
		return -1
	var lower: int = _index(cell if d < 2 else next)
	var body: int = _body_h[lower] if d % 2 == 0 else _body_v[lower]
	var edge: int = _edge_h[lower] if d % 2 == 0 else _edge_v[lower]
	if body != 0 or _other(edge, net):
		return STEP + BLOCKED
	return STEP + (SHARED if edge == net else 0)


## True if the route [param points] of a wire of [param net] (from terminal
## to terminal) crosses no symbol, runs over no terminal of another net
## between its ends and along no wire of another net.
func is_clear(points: Array[Vector2i], net: int) -> bool:
	var last: Vector2i = points[points.size() - 1]
	for s: int in range(1, points.size()):
		var unit: Vector2i = (points[s] - points[s - 1]).sign()
		var d: int = STEPS.find(unit)
		var cell: Vector2i = points[s - 1]
		while cell != points[s]:
			var step: int = _edge_cost(cell, d, net)
			if step < 0 or step >= BLOCKED:
				return false
			cell += unit
			if cell != last and _other(_terminal_net[_index(cell)], net):
				return false
	return true


## Cost of the route [param points] (from terminal to terminal) of a wire
## of [param net] leaving its ends along [param out_a] and [param out_b], as
## [method find] counts it.
func cost(points: Array[Vector2i], net: int, out_a: Vector2i, out_b: Vector2i) -> int:
	var total: int = 0
	var last: Vector2i = points[points.size() - 1]
	var d_in: int = -1
	for s: int in range(1, points.size()):
		var unit: Vector2i = (points[s] - points[s - 1]).sign()
		var d: int = STEPS.find(unit)
		var cell: Vector2i = points[s - 1]
		while cell != points[s]:
			var step: int = _edge_cost(cell, d, net)
			if step < 0:
				return 1 << 30
			total += step
			if d_in < 0:
				if out_a != Vector2i.ZERO and unit != out_a:
					total += LEAD
			elif _other(_cell_net[_index(cell)], net):
				total += BEND + TOUCH if d != d_in else CROSS
			elif d != d_in:
				total += BEND
			d_in = d
			cell += unit
			if cell == last:
				if out_b != Vector2i.ZERO and unit != -out_b:
					total += LEAD
			elif _other(_terminal_net[_index(cell)], net):
				total += BLOCKED
	return total


## Cheapest route of a wire of [param net] from [param start] to
## [param end], best leaving [param start] along [param out_a] and
## [param end] along [param out_b] (zero: any way). Returns all its points,
## start and end included, or an empty array when an end is off the area.
func find(start: Vector2i, end: Vector2i, out_a: Vector2i, out_b: Vector2i, net: int) -> Array[Vector2i]:
	if not has_cell(start) or not has_cell(end) or start == end:
		return []
	# Most routes stay near their ends: search there first, and the whole
	# area for a clean route only when the one found would look connected
	# along the way (a way around a long symbol); next to its ends (a
	# terminal hemmed in) the whole area would not help.
	var near: Rect2i = Rect2i(start - _origin, Vector2i.ZERO).expand(end - _origin).grow(WINDOW)
	near = near.intersection(Rect2i(0, 0, _width, _height))
	if _hemmed(end, net) and not _hemmed(start, net):
		# The search pays for a forced step as soon as it is taken: starting
		# at the hemmed-in end, it does not first go through every clean
		# route to the other one.
		var back: Array[Vector2i] = find(end, start, out_b, out_a, net)
		back.reverse()
		return back
	var route: Array[Vector2i] = _search(start, end, out_a, out_b, net, near)
	if _found_cost >= BLOCKED and near.size != Vector2i(_width, _height) and _blocked_midway:
		var clean: Array[Vector2i] = _search(start, end, out_a, out_b, net, Rect2i(0, 0, _width, _height), true)
		if not clean.is_empty():
			route = clean
	return route


## True if a wire of [param net] can get only a few cells away from
## [param cell] without looking connected somewhere.
func _hemmed(cell: Vector2i, net: int) -> bool:
	var seen: Dictionary[int, bool] = {_index(cell): true}
	var queue: Array[Vector2i] = [cell]
	var k: int = 0
	while k < queue.size():
		if queue.size() >= HEMMED:
			return false
		var at: Vector2i = queue[k]
		k += 1
		for d: int in 4:
			var step: int = _edge_cost(at, d, net)
			if step < 0 or step >= BLOCKED:
				continue
			var next: Vector2i = at + STEPS[d]
			var i: int = _index(next)
			if not seen.has(i) and not _other(_terminal_net[i], net):
				seen[i] = true
				queue.append(next)
	return true


## [method find] within [param window] (cells counted from the area's
## corner), without any step that would look connected if [param clean];
## sets [member _found_cost] and [member _blocked_midway].
func _search(start: Vector2i, end: Vector2i, out_a: Vector2i, out_b: Vector2i, net: int, window: Rect2i, clean: bool = false) -> Array[Vector2i]:
	var w: int = _width
	var left: int = window.position.x
	var top: int = window.position.y
	var right: int = window.end.x - 1
	var bottom: int = window.end.y - 1
	var states: int = w * _height * 4
	var costs: PackedInt32Array = PackedInt32Array()
	costs.resize(states)
	costs.fill(1 << 30)
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(states)
	var done: PackedByteArray = PackedByteArray()
	done.resize(states)
	_heap_key.clear()
	_heap_state.clear()
	var first: int = STEPS.find(out_a)
	var arrive: int = STEPS.find(-out_b)
	var start_index: int = _index(start)
	var end_index: int = _index(end)
	var end_x: int = end.x - _origin.x
	var end_y: int = end.y - _origin.y
	# A state is a cell index * 4 + the direction it was entered in.
	var origin_state: int = start_index * 4 + maxi(first, 0)
	costs[origin_state] = 0
	parent[origin_state] = -1
	_push(0, origin_state)
	var found: int = -1
	while not _heap_state.is_empty():
		var state: int = _pop()
		if done[state] != 0:
			continue
		done[state] = 1
		var index: int = state >> 2
		if index == end_index:
			found = state
			break
		var d_in: int = state & 3
		var x: int = index % w
		var y: int = index / w
		var at_start: bool = index == start_index
		var crossed: bool = not at_start and _other(_cell_net[index], net)
		var base: int = costs[state]
		for d: int in 4:
			var next: int
			var lower: int
			var nx: int = x
			var ny: int = y
			if d == 0:
				if x >= right:
					continue
				next = index + 1
				lower = index
				nx += 1
			elif d == 1:
				if y >= bottom:
					continue
				next = index + w
				lower = index
				ny += 1
			elif d == 2:
				if x <= left:
					continue
				next = index - 1
				lower = next
				nx -= 1
			else:
				if y <= top:
					continue
				next = index - w
				lower = next
				ny -= 1
			if next == start_index:
				continue
			var step: int = STEP
			var edge: int = _edge_h[lower] if d & 1 == 0 else _edge_v[lower]
			if (_body_h[lower] if d & 1 == 0 else _body_v[lower]) != 0 or _other(edge, net):
				step += BLOCKED
			elif edge == net:
				step += SHARED
			if next == end_index:
				if arrive >= 0 and d != arrive:
					step += LEAD
			elif _other(_terminal_net[next], net):
				step += BLOCKED
			if clean and step >= BLOCKED:
				continue
			if at_start:
				if first >= 0 and d != first:
					step += LEAD
			elif d == (d_in + 2) & 3:
				continue
			elif d != d_in:
				step += BEND + (TOUCH if crossed else 0)
			elif crossed:
				step += CROSS
			var s: int = next * 4 + d
			var c: int = base + step
			if c < costs[s]:
				costs[s] = c
				parent[s] = state
				_push(c + (absi(nx - end_x) + absi(ny - end_y)) * STEP, s)
	_found_cost = costs[found] if found >= 0 else 1 << 30
	_blocked_midway = false
	if found < 0:
		return []
	var cells: Array[Vector2i] = []
	var at: int = found
	while at >= 0:
		var i: int = at >> 2
		var cell: Vector2i = _origin + Vector2i(i % w, i / w)
		cells.append(cell)
		var before: int = parent[at]
		if before >= 0 and costs[at] - costs[before] >= BLOCKED:
			var near: int = mini(_distance(cell, start), _distance(cell, end))
			if near > NEAR_END:
				_blocked_midway = true
		at = before
	cells.reverse()
	return cells


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _push(key: int, state: int) -> void:
	_heap_key.append(key)
	_heap_state.append(state)
	var i: int = _heap_key.size() - 1
	while i > 0:
		var up: int = (i - 1) / 2
		if _heap_key[up] <= key:
			break
		_heap_key[i] = _heap_key[up]
		_heap_state[i] = _heap_state[up]
		i = up
	_heap_key[i] = key
	_heap_state[i] = state


func _pop() -> int:
	var top: int = _heap_state[0]
	var last: int = _heap_key.size() - 1
	var key: int = _heap_key[last]
	var state: int = _heap_state[last]
	_heap_key.resize(last)
	_heap_state.resize(last)
	if last == 0:
		return top
	var i: int = 0
	while true:
		var child: int = i * 2 + 1
		if child >= last:
			break
		if child + 1 < last and _heap_key[child + 1] < _heap_key[child]:
			child += 1
		if _heap_key[child] >= key:
			break
		_heap_key[i] = _heap_key[child]
		_heap_state[i] = _heap_state[child]
		i = child
	_heap_key[i] = key
	_heap_state[i] = state
	return top
