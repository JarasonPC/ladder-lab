class_name CustomSymbol
extends RefCounted
## A symbol of the floor plan drawn by the user (see [SymbolLibrary]): lines,
## polylines, polygons, rectangles, ellipses, arcs, curves and texts in
## metres, y down, about its origin: the middle of the symbol, or for one on
## a wall the point on the wall it hangs from (the room below it, as the
## other wall symbols are drawn upright). Each shape has its line width,
## line style and colour, a closed one its fill, a text its height, angle,
## bold and italic. A drawing-only symbol is put on the plan as a
## [FloorPlan.Mark]; an electrical one is a load on a circuit, an
## [Appliance] that carries its [member id] (it is on the single-line
## diagram, the parts list and the simulation like any appliance). Its
## category groups it in the palette and the library. No nodes.

## What a shape is: a line from its first point to its second; a polyline
## through its points; a polygon round them; a rectangle or an ellipse in
## the box of its two corners; an arc from its first point through its
## second to its third; a curve from its first point bent towards its
## second (a quadratic Bézier curve) to its third; a text centred on its
## point; a picture in the box of its two corners (an image file taken in,
## kept in the symbol as PNG).
const KINDS: PackedStringArray = ["line", "polyline", "polygon", "rect", "ellipse", "arc", "curve", "text", "image"]
## Points each kind takes; 0: from [constant MIN_POINTS] to [constant MAX_POINTS].
const POINTS: Dictionary[String, int] = {"line": 2, "polyline": 0, "polygon": 0, "rect": 2, "ellipse": 2, "arc": 3, "curve": 3, "text": 1, "image": 2}
const MIN_POINTS: Dictionary[String, int] = {"polyline": 2, "polygon": 3}
const MAX_POINTS: int = 100
## Kinds that can be filled (an arc or a curve closed by a straight line
## between its ends).
const FILLABLE: PackedStringArray = ["polygon", "rect", "ellipse", "arc", "curve"]
## Line styles: solid, dashed, dotted, dash and dot.
const STYLES: PackedStringArray = ["solid", "dash", "dot", "dashdot"]
## Thickest line (mm); 0 is as thin as the plan's own lines.
const MAX_WIDTH: float = 10.0
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
## A picture taken in is made at most this many pixels a side, and its
## longer side this long on the symbol (m); the most a symbol file keeps of
## one (bytes of its text).
const IMAGE_PIXELS: int = 512
const IMAGE_SIZE: float = 0.2
const MAX_IMAGE_DATA: int = 2000000
## Power of a new electrical symbol (W).
const DEFAULT_POWER: float = 100.0


## One shape of a symbol (see [constant KINDS]).
class Shape:
	var kind: String = "line"
	var points: PackedVector2Array = PackedVector2Array()
	## Line width (mm), 0 as thin as the plan's lines; one of [constant STYLES].
	var width: float = 0.0
	var style: String = "solid"
	## Its line colour ("" the plan's line colour) and, filled (only
	## [constant FILLABLE] kinds), its fill ("" its line colour).
	var color: String = ""
	var filled: bool = false
	var fill: String = ""
	var text: String = ""
	## A text's height (m) and its angle (degrees, anticlockwise).
	var size: float = TEXT_SIZE
	var angle: float = 0.0
	var bold: bool = false
	var italic: bool = false
	## A picture: the PNG file in Base64, and whether it is mirrored (left to
	## right, before it is turned by [member angle]).
	var image: String = ""
	var flipped: bool = false

	func copy() -> Shape:
		var shape: Shape = Shape.new()
		shape.kind = kind
		shape.points = points.duplicate()
		for key: String in ["width", "style", "color", "filled", "fill", "text", "size", "angle", "bold", "italic", "image", "flipped"]:
			shape.set(key, get(key))
		return shape

	## Takes the look of [param other] (width, style, colours, fill, a text's
	## height, bold and italic), not its points, text or angle.
	func take_style(other: Shape) -> void:
		for key: String in ["width", "style", "color", "fill", "size", "bold", "italic"]:
			set(key, other.get(key))
		filled = other.filled and kind in FILLABLE


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

## Bold and italic faces of the fonts texts were drawn in, by font and face.
static var _faces: Dictionary[String, Font] = {}
## Pictures drawn, by the hash of their data (null: one that cannot be read).
static var _pictures: Dictionary[int, Texture2D] = {}


## A key no other symbol has.
static func new_id() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(8)
	return bytes.hex_encode()


## A copy with the same [member id].
func copy() -> CustomSymbol:
	return from_data(to_data())


## What the shapes cover (m); a small box round the origin without any.
func bounds() -> Rect2:
	var result: Rect2 = bounds_of(shapes)
	return result if not shapes.is_empty() else Rect2(-0.1, -0.1, 0.2, 0.2)


## What the shapes of [param list] cover together (m).
static func bounds_of(list: Array[Shape]) -> Rect2:
	var result: Rect2 = Rect2()
	for i: int in list.size():
		var box: Rect2 = shape_bounds(list[i])
		result = box if i == 0 else result.merge(box)
	return result


## What [param shape] covers (m).
static func shape_bounds(shape: Shape) -> Rect2:
	var outline: PackedVector2Array = text_corners(shape) if shape.kind == "text" else outline_of(shape)
	var box: Rect2 = Rect2(outline[0], Vector2.ZERO)
	for p: Vector2 in outline:
		box = box.expand(p)
	return box


## The corners of the box round a text (m), turned by its angle.
static func text_corners(shape: Shape) -> PackedVector2Array:
	var half: Vector2 = Vector2(maxf(shape.text.length(), 1) * shape.size * 0.3, shape.size * 0.5)
	var corners: PackedVector2Array = PackedVector2Array()
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		corners.append(shape.points[0] + corner.rotated(-deg_to_rad(shape.angle)))
	return corners


## The points [param shape] is drawn through, round again to the first for
## a closed one (a text: its point).
static func outline_of(shape: Shape) -> PackedVector2Array:
	var p: PackedVector2Array = shape.points
	match shape.kind:
		"polygon":
			var round: PackedVector2Array = p.duplicate()
			round.append(p[0])
			return round
		"rect", "image":
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


## Whether [param shape] ends where it starts (its outline is round).
static func closed(shape: Shape) -> bool:
	return shape.kind in ["polygon", "rect", "ellipse"]


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


# --- Changing shapes ---------------------------------------------------------------

## [param shape] moved by [param by] (m).
static func move_shape(shape: Shape, by: Vector2) -> void:
	for k: int in shape.points.size():
		shape.points[k] += by


## [param shape] turned a quarter round [param about], clockwise as seen
## when [param clockwise]; a text's angle turns along.
static func turn_shape(shape: Shape, about: Vector2, clockwise: bool) -> void:
	for k: int in shape.points.size():
		var d: Vector2 = shape.points[k] - about
		shape.points[k] = about + (Vector2(-d.y, d.x) if clockwise else Vector2(d.y, -d.x))
	shape.angle = wrapf(shape.angle + (-90.0 if clockwise else 90.0), -180.0, 180.0)


## [param shape] mirrored across [param about]: left to right when
## [param across] (about the line up and down through it), else top to
## bottom. A text keeps reading from left to right.
static func mirror_shape(shape: Shape, about: Vector2, across: bool) -> void:
	for k: int in shape.points.size():
		var p: Vector2 = shape.points[k]
		shape.points[k] = Vector2(2.0 * about.x - p.x, p.y) if across else Vector2(p.x, 2.0 * about.y - p.y)
	if shape.kind == "image":
		# The picture itself mirrored.
		shape.flipped = not shape.flipped
		shape.angle = wrapf(-shape.angle if across else 180.0 - shape.angle, -180.0, 180.0)
		return
	var angle: float = 180.0 - shape.angle if across else -shape.angle
	if cos(deg_to_rad(angle)) < -1e-6:
		angle += 180.0
	shape.angle = wrapf(angle, -180.0, 180.0)


## [param shape] [param factor] times as large about [param about]; a
## text's height too, its lines as wide as they were.
static func scale_shape(shape: Shape, about: Vector2, factor: float) -> void:
	for k: int in shape.points.size():
		shape.points[k] = about + (shape.points[k] - about) * factor
	if shape.kind == "text":
		shape.size = clampf(shape.size * factor, MIN_TEXT, MAX_TEXT)


# --- Drawing ----------------------------------------------------------------------

## Draws the shapes on [param item], [param s] pixels a metre, the origin
## at [param at]: in their own colours (those of the plan's line colour in
## [param color]), or all in [param color] with [param recolor] (selected,
## a ghost); lines [param width] wide where a shape has no width of its
## own; texts in [param font].
func draw(item: CanvasItem, at: Vector2, s: float, color: Color, width: float, font: Font = null, recolor: bool = false) -> void:
	draw_shapes(item, shapes, at, s, color, width, font, recolor)


static func draw_shapes(item: CanvasItem, list: Array[Shape], at: Vector2, s: float, color: Color, width: float, font: Font = null, recolor: bool = false) -> void:
	for shape: Shape in list:
		draw_shape(item, shape, at, s, color, width, font, recolor)


## The line colour of [param shape] when the plan's is [param plan_color].
static func line_color(shape: Shape, plan_color: Color) -> Color:
	return Color.html(shape.color) if not shape.color.is_empty() and Color.html_is_valid(shape.color) else plan_color


## The fill of [param shape] when the plan's line colour is [param plan_color].
static func fill_color(shape: Shape, plan_color: Color) -> Color:
	return Color.html(shape.fill) if not shape.fill.is_empty() and Color.html_is_valid(shape.fill) else line_color(shape, plan_color)


static func draw_shape(item: CanvasItem, shape: Shape, at: Vector2, s: float, color: Color, width: float, font: Font = null, recolor: bool = false) -> void:
	var stroke: Color = color if recolor else line_color(shape, color)
	if shape.kind == "text":
		_draw_text(item, shape, at, s, stroke, font)
		return
	if shape.kind == "image":
		_draw_image(item, shape, at, s, color, width, recolor)
		return
	var screen: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in outline_of(shape):
		screen.append(at + p * s)
	if shape.filled and shape.kind in FILLABLE:
		var area: PackedVector2Array = screen.slice(0, screen.size() - 1) if closed(shape) else screen
		if area.size() >= 3 and not Geometry2D.triangulate_polygon(area).is_empty():
			item.draw_colored_polygon(area, color if recolor else fill_color(shape, color))
	if screen.size() >= 2:
		var line: float = maxf(shape.width / 1000.0 * s, 1.0) if shape.width > 0.0 else width
		stroke_line(item, screen, stroke, line, shape.style)


## A line through [param points] (screen) in [param style] (see
## [constant STYLES]), its dashes and dots spaced by its [param width].
static func stroke_line(item: CanvasItem, points: PackedVector2Array, color: Color, width: float, style: String) -> void:
	if style == "solid" or not STYLES.has(style):
		item.draw_polyline(points, color, width, true)
		return
	var u: float = maxf(width, 1.0)
	# Each step of the pattern: how long, and whether it is drawn (a dash)
	# or a dot or a gap.
	var pattern: Array[Array] = [[6.0 * u + 3.0, "dash"], [3.0 * u + 3.0, "gap"]]
	if style == "dot":
		pattern = [[0.0, "dot"], [2.5 * u + 3.0, "gap"]]
	elif style == "dashdot":
		pattern = [[6.0 * u + 3.0, "dash"], [2.0 * u + 2.5, "gap"], [0.0, "dot"], [2.0 * u + 2.5, "gap"]]
	var step: int = 0
	var left: float = pattern[0][0]
	for k: int in points.size() - 1:
		var a: Vector2 = points[k]
		var b: Vector2 = points[k + 1]
		var length: float = a.distance_to(b)
		if length <= 0.0001:
			continue
		var done: float = 0.0
		while true:
			if pattern[step][1] == "dot":
				item.draw_circle(a.lerp(b, done / length), u * 0.6, color)
				step = (step + 1) % pattern.size()
				left = pattern[step][0]
				continue
			var take: float = minf(left, length - done)
			if pattern[step][1] == "dash":
				item.draw_line(a.lerp(b, done / length), a.lerp(b, (done + take) / length), color, width, true)
			done += take
			left -= take
			if left <= 0.0001:
				step = (step + 1) % pattern.size()
				left = pattern[step][0]
			if done >= length - 0.0001:
				break


static func _draw_text(item: CanvasItem, shape: Shape, at: Vector2, s: float, color: Color, font: Font) -> void:
	var used: Font = face(font if font != null else ThemeDB.fallback_font, shape.bold, shape.italic)
	var height: int = maxi(roundi(shape.size * s), 1)
	if height < 3 or shape.text.is_empty():
		return
	var text_size: Vector2 = used.get_string_size(shape.text, HORIZONTAL_ALIGNMENT_LEFT, -1, height)
	var middle: Vector2 = at + shape.points[0] * s
	var baseline: Vector2 = Vector2(-text_size.x * 0.5, (used.get_ascent(height) - used.get_descent(height)) * 0.5)
	if is_zero_approx(shape.angle):
		item.draw_string(used, middle + baseline, shape.text, HORIZONTAL_ALIGNMENT_LEFT, -1, height, color)
		return
	item.draw_set_transform(middle, -deg_to_rad(shape.angle))
	item.draw_string(used, baseline, shape.text, HORIZONTAL_ALIGNMENT_LEFT, -1, height, color)
	item.draw_set_transform(Vector2.ZERO)


## A picture in its box, turned and mirrored as it is; tinted in
## [param color] with [param recolor]; a crossed box for one that cannot be read.
static func _draw_image(item: CanvasItem, shape: Shape, at: Vector2, s: float, color: Color, width: float, recolor: bool) -> void:
	var box: Rect2 = Rect2(at + shape.points[0] * s, (shape.points[1] - shape.points[0]) * s).abs()
	var texture: Texture2D = picture(shape.image)
	if texture == null:
		item.draw_rect(box, color, false, width)
		item.draw_line(box.position, box.end, color, width, true)
		item.draw_line(Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), color, width, true)
		return
	# Turned a quarter or three, the picture lies across its box.
	var size: Vector2 = box.size if posmod(roundi(shape.angle / 90.0), 2) == 0 else Vector2(box.size.y, box.size.x)
	item.draw_set_transform(box.get_center(), -deg_to_rad(shape.angle), Vector2(-1.0 if shape.flipped else 1.0, 1.0))
	item.draw_texture_rect(texture, Rect2(-size * 0.5, size), false, Color(color, 0.7) if recolor else Color.WHITE)
	item.draw_set_transform(Vector2.ZERO)


## The picture of PNG data [param data] (Base64), null when it cannot be read.
static func picture(data: String) -> Texture2D:
	var key: int = data.hash()
	if not _pictures.has(key):
		var image: Image = Image.new()
		var bytes: PackedByteArray = Marshalls.base64_to_raw(data) if not data.is_empty() else PackedByteArray()
		# Only what starts as a PNG file does is read.
		var png: bool = bytes.size() > 8 and bytes.slice(0, 8) == PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
		_pictures[key] = ImageTexture.create_from_image(image) if png and image.load_png_from_buffer(bytes) == OK else null
	return _pictures[key]


## A picture shape of [param image], made at most [constant IMAGE_PIXELS]
## a side, its longer side [constant IMAGE_SIZE] long about the origin.
static func image_shape(image: Image) -> Shape:
	var copy: Image = image.duplicate() as Image
	if copy.is_compressed():
		copy.decompress()
	var longest: int = maxi(copy.get_width(), copy.get_height())
	if longest > IMAGE_PIXELS:
		var factor: float = float(IMAGE_PIXELS) / longest
		copy.resize(maxi(roundi(copy.get_width() * factor), 1), maxi(roundi(copy.get_height() * factor), 1), Image.INTERPOLATE_LANCZOS)
	var shape: Shape = Shape.new()
	shape.kind = "image"
	shape.image = Marshalls.raw_to_base64(copy.save_png_to_buffer())
	var half: Vector2 = Vector2(copy.get_width(), copy.get_height()) / float(maxi(copy.get_width(), copy.get_height())) * IMAGE_SIZE * 0.5
	shape.points = PackedVector2Array([(-half).snapped(Vector2(0.001, 0.001)), half.snapped(Vector2(0.001, 0.001))])
	return shape


## [param font] bold and / or italic (itself when neither).
static func face(font: Font, bold: bool, italic: bool) -> Font:
	if not bold and not italic:
		return font
	var key: String = "%d/%s/%s" % [font.get_instance_id(), bold, italic]
	if not _faces.has(key):
		var variation: FontVariation = FontVariation.new()
		variation.base_font = font
		if bold:
			variation.variation_embolden = 0.8
		if italic:
			variation.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.2, 1.0), Vector2.ZERO)
		_faces[key] = variation
	return _faces[key]


## Draws it as large as fits in screen rectangle [param box] (at most
## [param most] pixels a metre), centred there.
func draw_fitted(item: CanvasItem, box: Rect2, most: float, color: Color, width: float, font: Font = null, recolor: bool = false) -> void:
	var extent: Rect2 = bounds()
	var s: float = minf(most, minf(box.size.x / maxf(extent.size.x, 0.01), box.size.y / maxf(extent.size.y, 0.01)))
	draw(item, box.get_center() - extent.get_center() * s, s, color, width, font, recolor)


## The shape nearest to [param point] (m) within [param reach] (m), -1 for
## none; inside a filled shape or a text's box is on it.
func shape_at(point: Vector2, reach: float) -> int:
	var best: float = reach
	var found: int = -1
	for i: int in range(shapes.size() - 1, -1, -1):
		var d: float = distance_to(shapes[i], point)
		if d < best:
			best = d
			found = i
	return found


## How far [param point] (m) is from [param shape]: 0 inside a filled one
## or a text's box.
static func distance_to(shape: Shape, point: Vector2) -> float:
	if shape.kind == "text":
		return 0.0 if Geometry2D.is_point_in_polygon(point, text_corners(shape)) else shape_bounds(shape).get_center().distance_to(point)
	if shape.kind == "image" and shape_bounds(shape).has_point(point):
		return 0.0
	var outline: PackedVector2Array = outline_of(shape)
	if shape.filled and shape.kind in FILLABLE and outline.size() >= 3 and Geometry2D.is_point_in_polygon(point, outline):
		return 0.0
	var d: float = outline[0].distance_to(point)
	for k: int in outline.size() - 1:
		d = minf(d, Geometry2D.get_closest_point_to_segment(point, outline[k], outline[k + 1]).distance_to(point))
	return d


# --- Files ------------------------------------------------------------------------

func to_data() -> Dictionary:
	var shape_list: Array = []
	for shape: Shape in shapes:
		shape_list.append(shape_to_data(shape))
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


## [param shape] as saved: what differs from a new shape's look only.
static func shape_to_data(shape: Shape) -> Dictionary:
	var points: Array = []
	for p: Vector2 in shape.points:
		points.append([snappedf(p.x, 0.0001), snappedf(p.y, 0.0001)])
	var sd: Dictionary = {"kind": shape.kind, "points": points}
	if shape.width > 0.0:
		sd["width"] = shape.width
	if shape.style != "solid":
		sd["style"] = shape.style
	if not shape.color.is_empty():
		sd["color"] = shape.color
	if shape.filled:
		sd["filled"] = true
		if not shape.fill.is_empty():
			sd["fill"] = shape.fill
	if shape.kind == "text":
		sd["text"] = shape.text
		sd["size"] = shape.size
		if not is_zero_approx(shape.angle):
			sd["angle"] = shape.angle
		if shape.bold:
			sd["bold"] = true
		if shape.italic:
			sd["italic"] = true
	if shape.kind == "image":
		sd["image"] = shape.image
		if not is_zero_approx(shape.angle):
			sd["angle"] = shape.angle
		if shape.flipped:
			sd["flipped"] = true
	return sd


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
	symbol.power = _number(d.get("power", DEFAULT_POWER), DEFAULT_POWER, Appliance.MIN_POWER, Appliance.MAX_POWER)
	symbol.two_phases = d.get("two_phases", false) == true
	var shape_list: Variant = d.get("shapes", [])
	if shape_list is Array:
		for sd: Variant in shape_list:
			if symbol.shapes.size() >= MAX_SHAPES:
				break
			var shape: Shape = shape_from_data(sd)
			if shape != null:
				symbol.shapes.append(shape)
	return symbol


## Reads a shape; null for a damaged one.
static func shape_from_data(raw: Variant) -> Shape:
	if not (raw is Dictionary) or not KINDS.has(str(raw.get("kind", ""))) or not (raw.get("points", null) is Array):
		return null
	var shape: Shape = Shape.new()
	shape.kind = str(raw["kind"])
	var list: Array = raw["points"]
	if POINTS[shape.kind] > 0 and list.size() != POINTS[shape.kind]:
		return null
	if POINTS[shape.kind] == 0 and (list.size() < MIN_POINTS[shape.kind] or list.size() > MAX_POINTS):
		return null
	for p: Variant in list:
		if not (p is Array) or (p as Array).size() != 2 or not ((p[0] is float or p[0] is int) and (p[1] is float or p[1] is int)) or not is_finite(float(p[0])) or not is_finite(float(p[1])):
			return null
		shape.points.append(Vector2(clampf(float(p[0]), -REACH, REACH), clampf(float(p[1]), -REACH, REACH)))
	shape.width = _number(raw.get("width", 0.0), 0.0, 0.0, MAX_WIDTH)
	shape.style = str(raw.get("style", "solid")) if STYLES.has(str(raw.get("style", "solid"))) else "solid"
	shape.color = _color(raw.get("color", ""))
	shape.filled = raw.get("filled", false) == true and shape.kind in FILLABLE
	shape.fill = _color(raw.get("fill", ""))
	if shape.kind == "text":
		if not (raw.get("text", null) is String):
			return null
		shape.text = (raw["text"] as String).strip_edges().left(MAX_TEXT_LENGTH)
		shape.size = _number(raw.get("size", TEXT_SIZE), TEXT_SIZE, MIN_TEXT, MAX_TEXT)
		shape.angle = _number(raw.get("angle", 0.0), 0.0, -360.0, 360.0)
		shape.bold = raw.get("bold", false) == true
		shape.italic = raw.get("italic", false) == true
	if shape.kind == "image":
		if not (raw.get("image", null) is String) or (raw["image"] as String).is_empty() or (raw["image"] as String).length() > MAX_IMAGE_DATA:
			return null
		shape.image = raw["image"]
		shape.angle = _number(raw.get("angle", 0.0), 0.0, -360.0, 360.0)
		shape.flipped = raw.get("flipped", false) == true
	return shape


static func _number(value: Variant, fallback: float, low: float, high: float) -> float:
	return clampf(float(value), low, high) if (value is float or value is int) and is_finite(float(value)) else fallback


## A colour as saved ("rrggbb" or "rrggbbaa"), "" for none or a damaged one.
static func _color(value: Variant) -> String:
	return (value as String).left(9) if value is String and not (value as String).is_empty() and Color.html_is_valid(value) else ""
