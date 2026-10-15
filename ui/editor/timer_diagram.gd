class_name TimerDiagram
extends Control
## Timing diagram of a time relay function, drawn like the ones in relay data
## sheets: supply U (A1-A2), control input S (for functions that use it) and
## output R as step curves, with the timed intervals dimensioned "t". The
## curves come from running a [TimerRelay] through a fixed scenario, so the
## diagram always shows what the simulation does. The time t is one unit.

const DURATION: float = 9.5
const STEP: float = 0.01
const LABEL_WIDTH: float = 26.0
const DIMENSION_HEIGHT: float = 18.0
const FONT_SIZE: int = 11
## Supply on / off in units of t.
const POWER_ON: float = 0.5
const POWER_OFF: float = 7.5
## Presses of S: [start, end] in units of t.
const PRESSES: Array = [[1.5, 2.0], [4.2, 4.6], [5.4, 6.4]]

var mode: TimerRelay.Mode = TimerRelay.Mode.ON_DELAY:
	set(value):
		mode = value
		_compute()
		queue_redraw()
## Height of one signal row; larger in the list of all functions.
var row_height: float = 24.0:
	set(value):
		row_height = value
		update_minimum_size()
		queue_redraw()
## Name of the control input on the drawing ("S", "TL", ...).
var input_name: String = "S":
	set(value):
		input_name = value
		queue_redraw()

var _power: PackedByteArray = PackedByteArray()
var _input: PackedByteArray = PackedByteArray()
var _output: PackedByteArray = PackedByteArray()
## Timed intervals as Vector2(start, end) in units of t.
var _runs: Array[Vector2] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compute()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(200, _row_count() * row_height + DIMENSION_HEIGHT + 10.0)


func _row_count() -> int:
	return 3 if TimerRelay.uses_control(mode) else 2


## Runs the scenario and samples U, S, R and the timed intervals.
func _compute() -> void:
	var relay: TimerRelay = TimerRelay.new("KT", mode, 1.0)
	relay.control_input = true
	_power.clear()
	_input.clear()
	_output.clear()
	_runs.clear()
	var run_start: float = -1.0
	var last_elapsed: float = 0.0
	var t: float = 0.0
	while t <= DURATION + 1e-9:
		var powered: bool = t >= POWER_ON and t < POWER_OFF
		var pressed: bool = false
		for p: Array in PRESSES:
			if t >= p[0] and t < p[1]:
				pressed = true
		relay.set_energized(powered)
		relay.set_control(pressed)
		var timing_before: bool = relay.get_remaining() > 0.0
		if timing_before and run_start < 0.0:
			run_start = t
		relay.advance(STEP)
		var timing: bool = relay.get_remaining() > 0.0
		# A timing run ends when its time is up; a new one may start at once.
		if run_start >= 0.0 and (not timing or relay.elapsed < last_elapsed):
			var end: float = t + STEP - (relay.elapsed if timing else 0.0)
			_runs.append(Vector2(run_start, end))
			run_start = end if timing else -1.0
		last_elapsed = relay.elapsed
		_power.append(1 if powered else 0)
		_input.append(1 if pressed else 0)
		_output.append(1 if relay.output else 0)
		t += STEP
	if run_start >= 0.0:
		_runs.append(Vector2(run_start, DURATION))
	update_minimum_size()


func _draw() -> void:
	var font: Font = AppTheme.ui_font()
	draw_rect(Rect2(Vector2.ZERO, size), AppTheme.chart_bg)
	draw_rect(Rect2(Vector2.ZERO, size), AppTheme.border, false, 1.0)
	var rows: Array = [["U", _power, AppTheme.text_muted]]
	if TimerRelay.uses_control(mode):
		rows.append([input_name, _input, AppTheme.warning])
	rows.append(["R", _output, AppTheme.accent])
	var plot_x: float = LABEL_WIDTH
	var plot_w: float = size.x - LABEL_WIDTH - 10.0
	var top_y: float = 6.0
	var bottom_y: float = top_y + rows.size() * row_height
	var x_of: Callable = func(time: float) -> float:
		return plot_x + time / DURATION * plot_w
	# A line through all the rows at every rising and falling edge.
	var edges: Dictionary[int, bool] = {}
	for row: Array in rows:
		var samples: PackedByteArray = row[1]
		for i: int in range(1, samples.size()):
			if samples[i] != samples[i - 1]:
				edges[i] = true
	for i: int in edges:
		var x: float = x_of.call(float(i) * STEP)
		_dashed_vertical(x, top_y, bottom_y, Color(AppTheme.text_muted, 0.7))
	for r: int in rows.size():
		var top: float = top_y + r * row_height + 5.0
		var base: float = top_y + (r + 1) * row_height - 3.0
		var name: String = rows[r][0]
		draw_string(font, Vector2(8.0, base - 1.0), name, HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH - 10.0, FONT_SIZE, AppTheme.text)
		draw_line(Vector2(plot_x, base), Vector2(plot_x + plot_w, base), AppTheme.chart_grid, 1.0)
		_draw_signal(rows[r][1], rows[r][2], top, base, x_of)
	# Dimensions of the timed intervals.
	var dim_y: float = bottom_y + 7.0
	for run: Vector2 in _runs:
		var x0: float = x_of.call(run.x)
		var x1: float = x_of.call(run.y)
		if x1 - x0 < 4.0:
			continue
		var color: Color = AppTheme.text_muted
		draw_line(Vector2(x0, dim_y - 4.0), Vector2(x0, dim_y + 4.0), color, 1.0)
		draw_line(Vector2(x1, dim_y - 4.0), Vector2(x1, dim_y + 4.0), color, 1.0)
		draw_line(Vector2(x0, dim_y), Vector2(x1, dim_y), color, 1.0)
		_arrow(Vector2(x0, dim_y), 1.0, color)
		_arrow(Vector2(x1, dim_y), -1.0, color)
		var length: float = run.y - run.x
		var text: String = ""
		if absf(length - 1.0) < 0.05:
			text = "t"
		elif absf(length - TimerRelay.GENERATOR_PULSE) < 0.05:
			text = "%s s" % str(TimerRelay.GENERATOR_PULSE)
		else:
			continue
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 1).x
		var label_pos: Vector2 = Vector2((x0 + x1) * 0.5 - w * 0.5, dim_y + 12.0)
		draw_string(font, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 1, AppTheme.text_muted)


## Step curve of one signal with a soft fill under its high parts.
func _draw_signal(samples: PackedByteArray, color: Color, top: float, base: float, x_of: Callable) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var level: int = samples[0] if samples.size() > 0 else 0
	points.append(Vector2(x_of.call(0.0), base if level == 0 else top))
	for i: int in range(1, samples.size()):
		if samples[i] != level:
			var x: float = x_of.call(float(i) * STEP)
			points.append(Vector2(x, base if level == 0 else top))
			level = samples[i]
			points.append(Vector2(x, base if level == 0 else top))
	points.append(Vector2(x_of.call(DURATION), base if level == 0 else top))
	for i: int in range(0, points.size() - 1):
		if is_equal_approx(points[i].y, top) and is_equal_approx(points[i + 1].y, top):
			draw_rect(Rect2(points[i].x, top, points[i + 1].x - points[i].x, base - top), Color(color, 0.18))
	draw_polyline(points, color, 2.0, true)


func _dashed_vertical(x: float, from_y: float, to_y: float, color: Color) -> void:
	var y: float = from_y
	while y < to_y:
		draw_line(Vector2(x, y), Vector2(x, minf(y + 3.0, to_y)), color, 1.0)
		y += 6.0


## Arrow head with its point at [param tip]; its body lies on the side
## [param inward] (1 right, -1 left), inside the dimensioned interval.
func _arrow(tip: Vector2, inward: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(5.0 * inward, -2.5), tip + Vector2(5.0 * inward, 2.5)]), color)
