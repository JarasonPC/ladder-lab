class_name CabinetPainter
extends RefCounted
## Draws onto a [CanvasItem] in millimetres: [member k] pixels per millimetre
## from [member origin]. Parts of the switchboard (rozvaděč) are drawn to
## their real sizes with it, so they line up on the DIN rails at any zoom.
## Filled shapes get an antialiased outline one pixel wide.

var canvas: CanvasItem
## Pixels per millimetre.
var k: float = 2.2
## Pixel position of the millimetre origin.
var origin: Vector2 = Vector2.ZERO


func _init(p_canvas: CanvasItem, p_k: float = 2.2, p_origin: Vector2 = Vector2.ZERO) -> void:
	canvas = p_canvas
	k = p_k
	origin = p_origin


## Pixel position of a point in millimetres.
func px(at: Vector2) -> Vector2:
	return origin + at * k


## Moves the origin by [param offset] millimetres.
func shifted(offset: Vector2) -> CabinetPainter:
	return CabinetPainter.new(canvas, k, origin + offset * k)


## [param mm] rounded to whole pixels.
func snap(mm: float) -> float:
	return roundf(mm * k) / k


## The same painter with its origin on a whole pixel.
func snapped() -> CabinetPainter:
	return CabinetPainter.new(canvas, k, origin.round())


## Line width in pixels for [param mm] millimetres, never thinner than one pixel.
func width(mm: float) -> float:
	return maxf(mm * k, 1.0)


func rect(r: Rect2, fill: Color, radius: float = 0.0, edge: Color = Color.TRANSPARENT, edge_mm: float = 0.0) -> void:
	var points: PackedVector2Array = rounded(r, radius)
	if fill.a > 0.0:
		canvas.draw_colored_polygon(points, fill)
	_outline(points, edge if edge.a > 0.0 else fill, edge_mm if edge.a > 0.0 else 0.0)


## Rectangle shaded from [param top] to [param bottom].
func gradient(r: Rect2, top: Color, bottom: Color, radius: float = 0.0, edge: Color = Color.TRANSPARENT, edge_mm: float = 0.0) -> void:
	var points: PackedVector2Array = rounded(r, radius)
	var colors: PackedColorArray = PackedColorArray()
	var y0: float = px(r.position).y
	var h: float = maxf(r.size.y * k, 0.001)
	for point: Vector2 in points:
		colors.append(top.lerp(bottom, clampf((point.y - y0) / h, 0.0, 1.0)))
	canvas.draw_polygon(points, colors)
	_outline(points, edge if edge.a > 0.0 else bottom, edge_mm if edge.a > 0.0 else 0.0)


## Rectangle shaded from [param left] to [param right].
func hgradient(r: Rect2, left: Color, right: Color, radius: float = 0.0) -> void:
	var points: PackedVector2Array = rounded(r, radius)
	var colors: PackedColorArray = PackedColorArray()
	var x0: float = px(r.position).x
	var w: float = maxf(r.size.x * k, 0.001)
	for point: Vector2 in points:
		colors.append(left.lerp(right, clampf((point.x - x0) / w, 0.0, 1.0)))
	canvas.draw_polygon(points, colors)


func circle(center: Vector2, radius: float, fill: Color, edge: Color = Color.TRANSPARENT, edge_mm: float = 0.0) -> void:
	if fill.a > 0.0:
		canvas.draw_circle(px(center), radius * k, fill, true, -1.0, true)
	if edge.a > 0.0:
		canvas.draw_arc(px(center), radius * k, 0.0, TAU, 32, edge, width(edge_mm), true)


func ring(center: Vector2, radius: float, color: Color, mm: float, from: float = 0.0, to: float = TAU) -> void:
	canvas.draw_arc(px(center), radius * k, from, to, 32, color, width(mm), true)


func line(a: Vector2, b: Vector2, color: Color, mm: float = 0.0) -> void:
	canvas.draw_line(px(a), px(b), color, width(mm), true)


func polygon(points: PackedVector2Array, fill: Color, edge: Color = Color.TRANSPARENT, edge_mm: float = 0.0) -> void:
	var scaled: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(px(point))
	canvas.draw_colored_polygon(scaled, fill)
	_outline(scaled, edge if edge.a > 0.0 else fill, edge_mm if edge.a > 0.0 else 0.0)


## Text with its baseline at [param at]; [param align] -1 left, 0 centre, 1 right.
func text(at: Vector2, s: String, size_mm: float, color: Color, align: int = 0, bold: bool = true, max_mm: float = -1.0) -> void:
	var font: Font = AppTheme.bold_font() if bold else AppTheme.ui_font()
	var font_size: int = maxi(roundi(size_mm * k), 5)
	if max_mm > 0.0:
		while font_size > 5 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_mm * k:
			font_size -= 1
	var w: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var p: Vector2 = px(at)
	p.x -= w * (0.5 if align == 0 else (1.0 if align > 0 else 0.0))
	canvas.draw_string(font, p.round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Text centred on [param center] (both ways).
func text_centered(center: Vector2, s: String, size_mm: float, color: Color, bold: bool = true, max_mm: float = -1.0) -> void:
	var font: Font = AppTheme.bold_font() if bold else AppTheme.ui_font()
	var font_size: int = maxi(roundi(size_mm * k), 5)
	var shift: float = (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5 / k
	text(center + Vector2(0.0, shift), s, size_mm, color, 0, bold, max_mm)


## Pixel outline of a rectangle with rounded corners.
func rounded(r: Rect2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var rad: float = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	if rad * k < 0.6:
		for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			points.append(px(corner))
		return points
	var centers: Array[Vector2] = [
		Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad),
	]
	var steps: int = clampi(int(rad * k), 2, 8)
	for c: int in 4:
		var start: float = -PI * 0.5 + c * PI * 0.5
		for s: int in steps + 1:
			var a: float = start + PI * 0.5 * s / steps
			points.append(px(centers[c] + Vector2(cos(a), sin(a)) * rad))
	return points


func _outline(points: PackedVector2Array, color: Color, mm: float) -> void:
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	canvas.draw_polyline(closed, color, maxf(mm * k, 1.0), true)
