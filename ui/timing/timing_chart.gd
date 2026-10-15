class_name TimingChart
extends Control
## Oscilloscope-like view of a [TraceRecorder]: one row per coil (power as a
## shaded band, armature position as a line from released to pulled in), per
## timer output and per lamp or motor. Follows the simulation time; drag to
## look back, mouse wheel to zoom, double click to follow again.

signal window_changed(seconds: float)

const ROW_HEIGHT: float = 28.0
const LABEL_WIDTH: float = 70.0
const HEADER_HEIGHT: float = 18.0
const MIN_WINDOW: float = 0.005
const MAX_WINDOW: float = 60.0
const POWER_BAND := Color(0.9, 0.28, 0.3, 0.2)
const LOAD_BAND := Color(1.0, 0.76, 0.2, 0.32)

var trace: TraceRecorder
## Visible time span in seconds.
var window: float = 0.5:
	set(value):
		window = clampf(value, MIN_WINDOW, MAX_WINDOW)
		queue_redraw()
## True while the right edge follows the simulation time.
var follow: bool = true

## Rows: "label", "band" (signal shown as shaded band), "line" (analog signal),
## "step" (digital signal drawn as a step line).
var _rows: Array[Dictionary] = []
var _now: float = 0.0
var _end: float = 0.0
var _dragging: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


## Builds the rows for the coils, timers and loads of [param doc].
func set_document(doc: SchematicDocument, p_trace: TraceRecorder) -> void:
	trace = p_trace
	_rows.clear()
	for c: CircuitComponent in doc.circuit.get_components():
		if c is Coil:
			_rows.append({"label": c.designation, "band": c.designation, "line": c.designation + "/armature", "step": ""})
			if c is TimerRelay:
				_rows.append({"label": c.designation + " ◷", "band": "", "line": c.designation + "/output", "step": ""})
		elif c is Lamp or c is Motor or c is ThreePhaseMotor:
			_rows.append({"label": c.designation, "band": "", "line": "", "step": c.designation})
	custom_minimum_size = Vector2(200, HEADER_HEIGHT + ROW_HEIGHT * maxi(_rows.size(), 1) + 4)
	follow = true
	_now = 0.0
	_end = 0.0
	queue_redraw()


## Moves the right edge along with the simulation (unless the user scrolled back).
func set_time(now: float) -> void:
	_now = now
	if follow:
		_end = now
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			window = window / 1.25
			window_changed.emit(window)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			window = window * 1.25
			window_changed.emit(window)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.double_click:
				follow = true
				_end = _now
		accept_event()
		queue_redraw()
	elif event is InputEventMouseMotion and _dragging:
		var plot_width: float = maxf(size.x - LABEL_WIDTH, 1.0)
		follow = false
		_end = clampf(_end - (event as InputEventMouseMotion).relative.x / plot_width * window, window * 0.5, _now)
		accept_event()
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), AppTheme.chart_bg)
	if trace == null:
		return
	var font: Font = AppTheme.ui_font()
	var start: float = _end - window
	var plot: Rect2 = Rect2(LABEL_WIDTH, HEADER_HEIGHT, size.x - LABEL_WIDTH, size.y - HEADER_HEIGHT)
	_draw_grid(plot, start, font)
	for r: int in _rows.size():
		var row: Dictionary = _rows[r]
		var top: float = HEADER_HEIGHT + r * ROW_HEIGHT
		var low: float = top + ROW_HEIGHT - 4.0
		var high: float = top + 5.0
		draw_line(Vector2(plot.position.x, top + ROW_HEIGHT), Vector2(size.x, top + ROW_HEIGHT), AppTheme.chart_grid)
		draw_string(font, Vector2(10, top + ROW_HEIGHT * 0.5 + 5), row["label"], HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH - 12, 13, AppTheme.text)
		if row["band"] != "":
			_draw_bands(row["band"], start, plot, top + 2.0, ROW_HEIGHT - 4.0, POWER_BAND)
		if row["step"] != "":
			_draw_bands(row["step"], start, plot, high, low - high, LOAD_BAND)
			_draw_series(row["step"], start, plot, low, high, false, AppTheme.text_muted)
		if row["line"] != "":
			_draw_series(row["line"], start, plot, low, high, true, AppTheme.danger)
	if not follow:
		draw_string(font, Vector2(size.x - 206, size.y - 6), tr("Double click: follow"), HORIZONTAL_ALIGNMENT_RIGHT, 200, 11, AppTheme.text_faint)


func _x(t: float, start: float, plot: Rect2) -> float:
	return plot.position.x + (t - start) / window * plot.size.x


## Vertical grid with time labels at a 1-2-5 step.
func _draw_grid(plot: Rect2, start: float, font: Font) -> void:
	var raw: float = window / 6.0
	var magnitude: float = pow(10.0, floorf(log(raw) / log(10.0)))
	var step: float = magnitude
	for m: float in [1.0, 2.0, 5.0, 10.0]:
		if magnitude * m >= raw:
			step = magnitude * m
			break
	var t: float = ceilf(start / step) * step
	while t <= _end:
		var x: float = _x(t, start, plot)
		draw_line(Vector2(x, HEADER_HEIGHT), Vector2(x, size.y), AppTheme.chart_grid)
		var text: String = ("%d ms" % roundi(t * 1000.0)) if window < 2.0 else ("%.1f s" % t)
		draw_string(font, Vector2(x + 3, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AppTheme.text_faint)
		t += step


## Shades the intervals where a digital signal is 1.
func _draw_bands(signal_name: String, start: float, plot: Rect2, top: float, height: float, color: Color) -> void:
	var times: PackedFloat64Array = trace.times(signal_name)
	var values: PackedFloat32Array = trace.values(signal_name)
	if times.is_empty():
		return
	var i: int = maxi(times.bsearch(start, true) - 1, 0)
	while i < times.size() and times[i] <= _end:
		var from: float = maxf(times[i], start)
		var to: float = times[i + 1] if i + 1 < times.size() else _now
		to = minf(to, _end)
		if values[i] > 0.5 and to > from:
			var x0: float = _x(from, start, plot)
			draw_rect(Rect2(x0, top, maxf(_x(to, start, plot) - x0, 1.0), height), color)
		i += 1


## Draws a signal between [param low] (0) and [param high] (1): linear for
## analog signals, as steps for digital ones.
func _draw_series(signal_name: String, start: float, plot: Rect2, low: float, high: float, analog: bool, color: Color) -> void:
	var times: PackedFloat64Array = trace.times(signal_name)
	var values: PackedFloat32Array = trace.values(signal_name)
	if times.is_empty() or times[0] > _end:
		return
	var points: PackedVector2Array = PackedVector2Array()
	var first_t: float = maxf(start, times[0])
	var y_of: Callable = func(v: float) -> float: return lerpf(low, high, v)
	points.append(Vector2(_x(first_t, start, plot), y_of.call(trace.value_at(signal_name, first_t, analog))))
	var i: int = times.bsearch(first_t, false)
	while i < times.size() and times[i] <= _end:
		var x: float = _x(times[i], start, plot)
		if not analog:
			points.append(Vector2(x, points[points.size() - 1].y))
		points.append(Vector2(x, y_of.call(values[i])))
		i += 1
	var last_t: float = minf(_end, _now)
	if last_t > first_t:
		points.append(Vector2(_x(last_t, start, plot), y_of.call(trace.value_at(signal_name, last_t, analog))))
	if points.size() >= 2:
		draw_polyline(points, color, 2.0)
