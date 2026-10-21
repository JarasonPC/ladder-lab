class_name CustomSymbol
extends RefCounted
## A symbol of the floor plan drawn by the user (see [SymbolLibrary]): lines,
## rectangles, ellipses, arcs, curves and texts in metres, y down, about its
## origin: the middle of the symbol, or for one on a wall the point on the
## wall it hangs from (the room below it, as the other wall symbols are
## drawn upright). A drawing-only symbol is put on the plan as a
## [FloorPlan.Mark]; an electrical one is a load on a circuit, an
## [Appliance] that carries its [member id] (it is on the single-line
## diagram, the parts list and the simulation like any appliance). Its
## category groups it in the palette and the library. No nodes.

## What a shape is: a line from its first point to its second; a rectangle
## or an ellipse in the box of its two corners; an arc from its first point
## through its second to its third; a curve from its first point bent
## towards its second (a quadratic Bézier curve) to its third; a text centred
## on its point.
const KINDS: PackedStringArray = ["line", "rect", "ellipse", "arc", "curve", "text"]
## Points each kind takes.
const POINTS: Dictionary[String, int] = {"line": 2, "rect": 2, "ellipse": 2, "arc": 3, "curve": 3, "text": 1}
## Height of a new text (m), and the least and most.
const TEXT_SIZE: float = 0.12
const MIN_TEXT: float = 0.03
const MAX_TEXT: float = 1.0
## Farthest a point may be from the origin (m).
const REACH: float = 2.0
## Most shapes a symbol keeps, and the longest name, category and text.
const MAX_SHAPES: int = 200
const MAX_NAME: int = 60
const MAX_TEXT_LENGTH: int = 40
## Power of a new electrical symbol (W).
const DEFAULT_POWER: float = 100.0


## One shape of a symbol (see [constant KINDS]).
class Shape:
	var kind: String = "line"
	var points: PackedVector2Array = PackedVector2Array()
	## A rectangle or ellipse filled.
	var filled: bool = false
	var text: String = ""
	## Height of a text (m).
	var size: float = TEXT_SIZE

	func copy() -> Shape:
		var shape: Shape = Shape.new()
		shape.kind = kind
		shape.points = points.duplicate()
		shape.filled = filled
		shape.text = text
		shape.size = size
		return shape


## Its own, never changing, key ([method new_id]).
var id: String = ""
var name: String = ""
## Where the palette and the library list it ("" for none of its own).
var category: String = ""
## A load on a circuit rather than a drawing.
var electrical: bool = false
## An electrical symbol's rated power when put on the plan (W) and whether
## it is on 400 V between two phases.
var power: float = DEFAULT_POWER
var two_phases: bool = false
## Goes onto the nearest wall (its origin on the wall), else stays where it
## is put (on the ceiling).
var wall: bool = false
var shapes: Array[Shape] = []


## A key no other symbol has.
static func new_id() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(8)
	return bytes.hex_encode()


## A copy with the same [member id].
func copy() -> CustomSymbol:
	return from_data(to_data())


## What the shapes cover (m); a small box round the origin without any.
func bounds() -> Rect2:
	var result: Rect2 = Rect2()
	var first: bool = true
	for shape: Shape in shapes:
		var box: Rect2 = shape_bounds(shape)
		result = box if first else result.merge(box)
		first = false
	return result if not first else Rect2(-0.1, -0.1, 0.2, 0.2)


## What [param shape] covers (m).
static func shape_bounds(shape: Shape) -> Rect2:
	if shape.kind == "text":
		var half: Vector2 = Vector2(maxf(shape.text.length(), 1) * shape.size * 0.3, shape.size * 0.5)
		return Rect2(shape.points[0] - half, half * 2.0)
	var outline: PackedVector2Array = outline_of(shape)
	var box: Rect2 = Rect2(outline[0], Vector2.ZERO)
	for p: Vector2 in outline:
		box = box.expand(p)
	return box


## The points [param shape] is drawn through (a text: its point).
static func outline_of(shape: Shape) -> PackedVector2Array:
	var p: PackedVector2Array = shape.points
	match shape.kind:
		"rect":
			return PackedVector2Array([p[0], Vector2(p[1].x, p[0].y), p[1], Vector2(p[0].x, p[1].y), p[0]])
		"ellipse":
			var c: Vector2 = (p[0] + p[1]) * 0.5
			var r: Vector2 = (p[1] - p[0]).abs() * 0.5
			var round: PackedVector2Array = PackedVector2Array()
			for k: int in 41:
				round.append(c + Vector2(cos(TAU * k / 40.0) * r.x, sin(TAU * k / 40.0) * r.y))
			return round
		"arc":
			return arc_points(p[0], p[1], p[2])
		"curve":
			var curve: PackedVector2Array = PackedVector2Array()
			for k: int in 25:
				var t: float = k / 24.0
				curve.append(p[0].lerp(p[1], t).lerp(p[1].lerp(p[2], t), t))
			return curve
	return p.duplicate()


## An arc from [param a] through [param b] to [param c]; a straight line
## when the three are in line.
static func arc_points(a: Vector2, b: Vector2, c: Vector2) -> PackedVector2Array:
	var d: float = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(d) < 1e-9:
		return PackedVector2Array([a, c])
	var aa: float = a.length_squared()
	var bb: float = b.length_squared()
	var cc: float = c.length_squared()
	var center: Vector2 = Vector2(aa * (b.y - c.y) + bb * (c.y - a.y) + cc * (a.y - b.y), aa * (c.x - b.x) + bb * (a.x - c.x) + cc * (b.x - a.x)) / d
	var start: float = (a - center).angle()
	var through: float = wrapf((b - center).angle() - start, 0.0, TAU)
	var sweep: float = wrapf((c - center).angle() - start, 0.0, TAU)
	if through > sweep:
		# The other way round.
		sweep -= TAU
	var radius: float = a.distance_to(center)
	var steps: int = clampi(ceili(absf(sweep) / (PI / 24.0)), 2, 96)
	var result: PackedVector2Array = PackedVector2Array()
	for k: int in steps + 1:
		result.append(center + Vector2.from_angle(start + sweep * k / steps) * radius)
	return result


## Draws the shapes on [param item], [param s] pixels a metre, the origin
## at [param at]: lines [param width] wide in [param color], texts in
## [param font].
func draw(item: CanvasItem, at: Vector2, s: float, color: Color, width: float, font: Font = null) -> void:
	draw_shapes(item, shapes, at, s, color, width, font)


static func draw_shapes(item: CanvasItem, list: Array[Shape], at: Vector2, s: float, color: Color, width: float, font: Font = null) -> void:
	for shape: Shape in list:
		draw_shape(item, shape, at, s, color, width, font)


static func draw_shape(item: CanvasItem, shape: Shape, at: Vector2, s: float, color: Color, width: float, font: Font = null) -> void:
	if shape.kind == "text":
		var used: Font = font if font != null else ThemeDB.fallback_font
		var height: int = maxi(roundi(shape.size * s), 1)
		if height < 3 or shape.text.is_empty():
			return
		var text_size: Vector2 = used.get_string_size(shape.text, HORIZONTAL_ALIGNMENT_LEFT, -1, height)
		var middle: Vector2 = at + shape.points[0] * s
		var baseline: Vector2 = middle + Vector2(-text_size.x * 0.5, (used.get_ascent(height) - used.get_descent(height)) * 0.5)
		item.draw_string(used, baseline, shape.text, HORIZONTAL_ALIGNMENT_LEFT, -1, height, color)
		return
	var screen: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in outline_of(shape):
		screen.append(at + p * s)
	if shape.filled and shape.kind in ["rect", "ellipse"]:
		var area: PackedVector2Array = screen.slice(0, screen.size() - 1)
		if area.size() >= 3 and not Geometry2D.triangulate_polygon(area).is_empty():
			item.draw_colored_polygon(area, color)
	if screen.size() >= 2:
		item.draw_polyline(screen, color, width, true)


## Draws it as large as fits in screen rectangle [param box] (at most
## [param most] pixels a metre), centred there.
func draw_fitted(item: CanvasItem, box: Rect2, most: float, color: Color, width: float, font: Font = null) -> void:
	var extent: Rect2 = bounds()
	var s: float = minf(most, minf(box.size.x / maxf(extent.size.x, 0.01), box.size.y / maxf(extent.size.y, 0.01)))
	draw(item, box.get_center() - extent.get_center() * s, s, color, width, font)


## The shape nearest to [param point] (m) within [param reach] (m), -1 for none.
func shape_at(point: Vector2, reach: float) -> int:
	var best: float = reach
	var found: int = -1
	for i: int in range(shapes.size() - 1, -1, -1):
		var shape: Shape = shapes[i]
		var d: float = INF
		if shape.kind == "text" or (shape.filled and shape.kind in ["rect", "ellipse"]):
			if shape_bounds(shape).has_point(point):
				d = 0.0
		if d > 0.0:
			var outline: PackedVector2Array = outline_of(shape)
			for k: int in outline.size() - 1:
				d = minf(d, Geometry2D.get_closest_point_to_segment(point, outline[k], outline[k + 1]).distance_to(point))
			if outline.size() == 1:
				d = outline[0].distance_to(point)
		if d < best:
			best = d
			found = i
	return found


func to_data() -> Dictionary:
	var shape_list: Array = []
	for shape: Shape in shapes:
		var points: Array = []
		for p: Vector2 in shape.points:
			points.append([snappedf(p.x, 0.0001), snappedf(p.y, 0.0001)])
		var sd: Dictionary = {"kind": shape.kind, "points": points}
		if shape.filled:
			sd["filled"] = true
		if shape.kind == "text":
			sd["text"] = shape.text
			sd["size"] = shape.size
		shape_list.append(sd)
	var result: Dictionary = {"id": id, "name": name, "shapes": shape_list}
	if not category.is_empty():
		result["category"] = category
	if wall:
		result["wall"] = true
	if electrical:
		result["electrical"] = true
		result["power"] = power
		if two_phases:
			result["two_phases"] = true
	return result


## Reads a symbol; null without an id. Damaged shapes are left out.
static func from_data(raw: Variant) -> CustomSymbol:
	if not (raw is Dictionary):
		return null
	var d: Dictionary = raw
	if not (d.get("id", null) is String) or (d["id"] as String).strip_edges().is_empty():
		return null
	var symbol: CustomSymbol = CustomSymbol.new()
	symbol.id = (d["id"] as String).strip_edges().left(40)
	symbol.name = (d["name"] as String).strip_edges().left(MAX_NAME) if d.get("name", null) is String else ""
	symbol.category = (d["category"] as String).strip_edges().left(MAX_NAME) if d.get("category", null) is String else ""
	symbol.wall = d.get("wall", false) == true
	symbol.electrical = d.get("electrical", false) == true
	var watts: Variant = d.get("power", DEFAULT_POWER)
	symbol.power = clampf(float(watts), Appliance.MIN_POWER, Appliance.MAX_POWER) if (watts is float or watts is int) and is_finite(float(watts)) else DEFAULT_POWER
	symbol.two_phases = d.get("two_phases", false) == true
	var shape_list: Variant = d.get("shapes", [])
	if shape_list is Array:
		for sd: Variant in shape_list:
			if symbol.shapes.size() >= MAX_SHAPES:
				break
			var shape: Shape = _shape_from(sd)
			if shape != null:
				symbol.shapes.append(shape)
	return symbol


static func _shape_from(raw: Variant) -> Shape:
	if not (raw is Dictionary) or not KINDS.has(str(raw.get("kind", ""))) or not (raw.get("points", null) is Array):
		return null
	var shape: Shape = Shape.new()
	shape.kind = str(raw["kind"])
	var list: Array = raw["points"]
	if list.size() != POINTS[shape.kind]:
		return null
	for p: Variant in list:
		if not (p is Array) or (p as Array).size() != 2 or not ((p[0] is float or p[0] is int) and (p[1] is float or p[1] is int)) or not is_finite(float(p[0])) or not is_finite(float(p[1])):
			return null
		shape.points.append(Vector2(clampf(float(p[0]), -REACH, REACH), clampf(float(p[1]), -REACH, REACH)))
	shape.filled = raw.get("filled", false) == true and shape.kind in ["rect", "ellipse"]
	if shape.kind == "text":
		if not (raw.get("text", null) is String):
			return null
		shape.text = (raw["text"] as String).strip_edges().left(MAX_TEXT_LENGTH)
		var height: Variant = raw.get("size", TEXT_SIZE)
		shape.size = clampf(float(height), MIN_TEXT, MAX_TEXT) if (height is float or height is int) and is_finite(float(height)) else TEXT_SIZE
	return shape
