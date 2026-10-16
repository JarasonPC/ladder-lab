class_name TripCurveDiagram
extends Control
## Time-current characteristic of a fuse, breaker or overload relay, drawn as
## in data sheets: trip time (log) over the current as a multiple of the rated
## current (log). Breakers show the band of their magnetic release and, faint,
## the other two characteristics; a starting current can be marked (the
## motor's Ia / In).

const FONT_SIZE: int = 10
const LEFT: float = 34.0
const BOTTOM: float = 18.0
const TOP: float = 6.0
const RIGHT: float = 8.0
## Shown span: multiples of In and seconds.
const X_MIN: float = 1.0
const X_MAX: float = 50.0
const Y_MIN: float = 0.005
const Y_MAX: float = 10000.0

var kind: TripCurve.Kind = TripCurve.Kind.BREAKER_C:
	set(value):
		kind = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(200, 170)


func _draw() -> void:
	var font: Font = AppTheme.ui_font()
	var plot: Rect2 = Rect2(LEFT, TOP, size.x - LEFT - RIGHT, size.y - TOP - BOTTOM)
	draw_rect(plot, AppTheme.chart_bg)
	var x_of: Callable = func(m: float) -> float:
		return plot.position.x + log(m / X_MIN) / log(X_MAX / X_MIN) * plot.size.x
	var y_of: Callable = func(t: float) -> float:
		return plot.end.y - log(clampf(t, Y_MIN, Y_MAX) / Y_MIN) / log(Y_MAX / Y_MIN) * plot.size.y
	for m: float in [1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0]:
		var x: float = x_of.call(m)
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), AppTheme.chart_grid)
		var text: String = str(int(m))
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		draw_string(font, Vector2(x - w * 0.5, size.y - 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, AppTheme.text_faint)
	draw_string(font, Vector2(plot.end.x - 22.0, plot.end.y - 4.0), "× In", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, AppTheme.text_faint)
	for t: float in [0.01, 0.1, 1.0, 10.0, 100.0, 1000.0, 10000.0]:
		var y: float = y_of.call(t)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), AppTheme.chart_grid)
		var label: String = ("%s s" % str(t)) if t < 1.0 else ("%d s" % int(t))
		if t >= 1000.0:
			label = "%dk s" % int(t / 1000.0)
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		draw_string(font, Vector2(LEFT - w - 3.0, y + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, AppTheme.text_faint)
	if TripCurve.MAGNETIC.has(kind):
		for other: TripCurve.Kind in TripCurve.MAGNETIC:
			if other != kind:
				_draw_curve(other, x_of, y_of, Color(AppTheme.text_muted, 0.35), 1.0)
		var band: Vector2 = TripCurve.MAGNETIC_BAND[kind]
		var x0: float = x_of.call(band.x)
		var x1: float = x_of.call(minf(band.y, X_MAX))
		draw_rect(Rect2(x0, plot.position.y, x1 - x0, plot.size.y), Color(AppTheme.accent, 0.12))
	_draw_curve(kind, x_of, y_of, AppTheme.accent, 2.0)


func _draw_curve(k: TripCurve.Kind, x_of: Callable, y_of: Callable, color: Color, width: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var first: float = TripCurve.points(k)[0].x
	var steps: int = 120
	for i: int in steps + 1:
		var m: float = first * pow(X_MAX / first, float(i) / steps)
		var t: float = TripCurve.trip_time(k, m)
		if t <= 0.0:
			# Magnetic release: straight down at its current.
			var magnetic: float = TripCurve.MAGNETIC[k]
			points.append(Vector2(x_of.call(magnetic), y_of.call(TripCurve.trip_time(k, magnetic * 0.9999))))
			points.append(Vector2(x_of.call(magnetic), y_of.call(Y_MIN)))
			break
		points.append(Vector2(x_of.call(m), y_of.call(t)))
	# From the top at the current it never trips below.
	points.insert(0, Vector2(points[0].x, y_of.call(Y_MAX)))
	draw_polyline(points, color, width, true)
