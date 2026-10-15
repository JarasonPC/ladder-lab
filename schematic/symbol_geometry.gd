class_name SymbolGeometry
extends RefCounted
## Grid geometry of symbols, independent of drawing. Units are grid cells
## unless noted. In local coordinates two-terminal symbols run from their first
## terminal down to the second; a [Placement] mirrors and rotates them, so
## current paths can run vertically or horizontally.

## Pixels per grid cell.
const GRID: int = 20
## Distance in cells between the two terminals of a two-terminal symbol.
const SPAN: int = 3

## Wire directions, used for junction detection.
const DIR_UP: int = 1
const DIR_RIGHT: int = 2
const DIR_DOWN: int = 4
const DIR_LEFT: int = 8


## Terminal name -> cell offset, before rotation.
static func local_terminals(c: CircuitComponent) -> Dictionary[String, Vector2i]:
	var names: PackedStringArray = c.get_terminal_names()
	var result: Dictionary[String, Vector2i] = {}
	if names.size() == 1:
		result[names[0]] = Vector2i.ZERO
	elif names.size() == 2:
		result[names[0]] = Vector2i.ZERO
		result[names[1]] = Vector2i(0, SPAN)
	return result


## Direction of the symbol lead leaving a terminal, before rotation
## (0 for supplies, whose symbol has no lead).
static func local_lead_direction(c: CircuitComponent, terminal_name: String) -> int:
	var names: PackedStringArray = c.get_terminal_names()
	if names.size() != 2:
		return 0
	return DIR_DOWN if terminal_name == names[0] else DIR_UP


## Clickable body, before rotation, in cells.
static func local_body(c: CircuitComponent) -> Rect2:
	if c is PowerSupply:
		return Rect2(-0.6, -1.4, 1.2, 1.8)
	if c is SwitchingElement:
		return Rect2(-1.6, 0.5, 2.4, 2.0)
	return Rect2(-1.0, 0.5, 2.0, 2.0)


## Local cell offset -> offset from the placement cell.
static func transform_cell(v: Vector2i, p: Placement) -> Vector2i:
	if p.mirrored:
		v.x = -v.x
	match p.rotation:
		1:
			return Vector2i(-v.y, v.x)
		2:
			return Vector2i(-v.x, -v.y)
		3:
			return Vector2i(v.y, -v.x)
	return v


static func transform_point(v: Vector2, p: Placement) -> Vector2:
	if p.mirrored:
		v.x = -v.x
	match p.rotation:
		1:
			return Vector2(-v.y, v.x)
		2:
			return Vector2(-v.x, -v.y)
		3:
			return Vector2(v.y, -v.x)
	return v


static func transform_rect(r: Rect2, p: Placement) -> Rect2:
	var a: Vector2 = transform_point(r.position, p)
	var b: Vector2 = transform_point(r.end, p)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


static func transform_direction(direction: int, p: Placement) -> int:
	var order: Array[int] = [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT]
	if p.mirrored:
		if direction == DIR_LEFT:
			direction = DIR_RIGHT
		elif direction == DIR_RIGHT:
			direction = DIR_LEFT
	var i: int = order.find(direction)
	if i < 0:
		return 0
	return order[posmod(i + p.rotation, 4)]


## Pixel transform for drawing a symbol in local coordinates (no translation).
static func draw_transform(p: Placement) -> Transform2D:
	var t: Transform2D = Transform2D(p.rotation * PI / 2.0, Vector2.ZERO)
	if p.mirrored:
		t = t * Transform2D.FLIP_X
	return t


## Direction bit for a unit step between neighbouring cells.
static func direction_of(step: Vector2i) -> int:
	if step == Vector2i.UP:
		return DIR_UP
	if step == Vector2i.RIGHT:
		return DIR_RIGHT
	if step == Vector2i.DOWN:
		return DIR_DOWN
	if step == Vector2i.LEFT:
		return DIR_LEFT
	return 0
