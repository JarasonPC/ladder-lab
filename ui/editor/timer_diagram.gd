class_name TimerDiagram
extends Control
## Timing diagram of a time relay function, like the ones in relay data
## sheets: supply Un, control input S (for functions that use it) and output R.
## The curves come from running a [TimerRelay] through a fixed scenario, so the
## diagram always shows what the simulation does. The time t is one unit.

const DURATION: float = 9.5
const STEP: float = 0.01
const ROW_HEIGHT: float = 22.0
const LABEL_WIDTH: float = 26.0
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
## Name of the control input on the drawing ("S", "TL", ...).
var input_name: String = "S"

var _power: PackedByteArray = PackedByteArray()
var _input: PackedByteArray = PackedByteArray()
var _output: PackedByteArray = PackedByteArray()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compute()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _get_minimum_size() -> Vector2:
	var rows: int = 3 if TimerRelay.uses_control(mode) else 2
	return Vector2(200, rows * ROW_HEIGHT + 18.0)


## Runs the scenario and samples Un, S and R.
func _compute() -> void:
	var relay: TimerRelay = TimerRelay.new("KT", mode, 1.0)
	relay.control_input = true
	_power.clear()
	_input.clear()
	_output.clear()
	var t: float = 0.0
	while t <= DURATION + 1e-9:
		var powered: bool = t >= POWER_ON and t < POWER_OFF
		var pressed: bool = false
		for p: Array in PRESSES:
			if t >= p[0] and t < p[1]:
				pressed = true
		relay.set_energized(powered)
		relay.set_control(pressed)
		relay.advance(STEP)
		_power.append(1 if powered else 0)
		_input.append(1 if pressed else 0)
		_output.append(1 if relay.output else 0)
		t += STEP
	update_minimum_size()


func _draw() -> void:
	var font: Font = AppTheme.ui_font()
	draw_rect(Rect2(Vector2.ZERO, size), AppTheme.chart_bg)
	draw_rect(Rect2(Vector2.ZERO, size), AppTheme.border, false, 1.0)
	var rows: Array = [["Un", _power]]
	if TimerRelay.uses_control(mode):
		rows.append([input_name, _input])
	rows.append(["R", _output])
	var plot_x: float = LABEL_WIDTH
	var plot_w: float = size.x - LABEL_WIDTH - 8.0
	for r: int in rows.size():
		var top: float = 6.0 + r * ROW_HEIGHT
		var base: float = top + ROW_HEIGHT - 6.0
		draw_string(font, Vector2(6.0, base - 2.0), rows[r][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AppTheme.text_muted)
		draw_line(Vector2(plot_x, base), Vector2(plot_x + plot_w, base), AppTheme.chart_grid, 1.0)
		var samples: PackedByteArray = rows[r][1]
		var color: Color = AppTheme.accent if r == rows.size() - 1 else Color(AppTheme.accent, 0.55)
		var i: int = 0
		while i < samples.size():
			if samples[i] == 1:
				var j: int = i
				while j < samples.size() and samples[j] == 1:
					j += 1
				var x0: float = plot_x + float(i) / samples.size() * plot_w
				var x1: float = plot_x + float(j) / samples.size() * plot_w
				draw_rect(Rect2(x0, top + 2.0, maxf(x1 - x0, 1.5), base - top - 2.0), color)
				i = j
			else:
				i += 1
	# Scale: the time t.
	var unit: float = plot_w / DURATION
	var y: float = size.y - 6.0
	draw_line(Vector2(plot_x, y), Vector2(plot_x + unit, y), AppTheme.text_muted, 1.0)
	draw_line(Vector2(plot_x, y - 3.0), Vector2(plot_x, y + 1.0), AppTheme.text_muted, 1.0)
	draw_line(Vector2(plot_x + unit, y - 3.0), Vector2(plot_x + unit, y + 1.0), AppTheme.text_muted, 1.0)
	draw_string(font, Vector2(plot_x + unit + 4.0, y + 3.0), "t", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AppTheme.text_muted)
