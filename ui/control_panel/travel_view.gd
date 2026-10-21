class_name TravelView
extends Control
## The mechanical link of a group of the workspace while simulating, in the
## control panel beside the schematic: the group's name and title with where
## its part is in per cent, the motor moving it and which way it turns, and
## the way from one end to the other with a tick for each limit switch or
## proximity sensor along it (its designation beside it, lit while the part
## operates it) and the part where it is, an arrow showing where it goes.
## Follows the [Travel] of the simulation (see [member Simulator.travels]).

const PAD: float = 10.0
const TRACK_WIDTH: float = 4.0
const TICK: float = 6.0
const PART_RADIUS: float = 5.5
## Room between two designations on one row beside the way.
const LABEL_GAP: float = 6.0

var travel: Travel
## Free text of the group, e.g. "Gate"; may be empty.
var title: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _get_minimum_size() -> Vector2:
	return Vector2(160.0, 4.0 * _line() + 2.0 * PAD + TRACK_WIDTH + TICK)


## Height of a line of text.
func _line() -> float:
	return get_theme_font("font", "Label").get_height(AppTheme.SMALL_FONT_SIZE) + 4.0


func _get_tooltip(_at_position: Vector2) -> String:
	if travel == null or travel.motor == null:
		return ""
	return tr("Where the part moved by %s is, and the limit switches along its way (lit while it operates them)") % ("-" + travel.motor.designation)


func _draw() -> void:
	if travel == null:
		return
	var font: Font = get_theme_font("font", "Label")
	var small: int = AppTheme.SMALL_FONT_SIZE
	var big: int = get_theme_font_size("font_size", "Label")
	var line: float = _line()
	var ascent: float = font.get_ascent(small)
	draw_style_box(get_theme_stylebox("panel", "Card"), Rect2(Vector2.ZERO, size))
	# "+G1  Gate" and where the part is in per cent.
	var y: float = PAD + font.get_ascent(big)
	var readout: String = "%d %%" % roundi(travel.position * 100.0)
	var readout_w: float = font.get_string_size(readout, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	draw_string(font, Vector2(size.x - PAD - readout_w, y), readout, HORIZONTAL_ALIGNMENT_LEFT, -1, big, AppTheme.accent)
	var heading: String = "+" + travel.name + ("  " + title if not title.is_empty() else "")
	draw_string(font, Vector2(PAD, y), heading, HORIZONTAL_ALIGNMENT_LEFT, maxf(size.x - 3.0 * PAD - readout_w, 0.0), big, AppTheme.text)
	# The motor and which way it turns.
	var v: float = travel.velocity()
	var state: String = tr("Stopped") if absf(v) < 1e-9 else (tr("Running forwards") if v > 0.0 else tr("Running in reverse"))
	y += line + 2.0
	var motor: String = "-" + travel.motor.designation if travel.motor != null else ""
	draw_string(font, Vector2(PAD, y), motor, HORIZONTAL_ALIGNMENT_LEFT, -1, small, AppTheme.text)
	var motor_w: float = font.get_string_size(motor + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	draw_string(font, Vector2(PAD + motor_w, y), state, HORIZONTAL_ALIGNMENT_LEFT, maxf(size.x - 2.0 * PAD - motor_w, 0.0), small, AppTheme.text if absf(v) >= 1e-9 else AppTheme.text_muted)
	# The way, the designations of the switches above and below it.
	var from: float = PAD + PART_RADIUS
	var length: float = maxf(size.x - 2.0 * from, 1.0)
	var track_y: float = y + line + TICK + 4.0
	draw_line(Vector2(from, track_y), Vector2(from + length, track_y), AppTheme.border_strong, TRACK_WIDTH, true)
	var at_x: float = from + length * travel.position
	draw_line(Vector2(from, track_y), Vector2(at_x, track_y), AppTheme.accent, TRACK_WIDTH, true)
	var rows: Array[float] = [-INF, -INF]
	var order: Array[int] = []
	for i: int in travel.switches.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return travel.at[a] < travel.at[b])
	for i: int in order:
		var x: float = from + length * travel.at[i]
		var operated: bool = Travel.is_on(travel.switches[i])
		var color: Color = AppTheme.warning if operated else AppTheme.text_muted
		draw_line(Vector2(x, track_y - TICK), Vector2(x, track_y + TICK), color, 2.0 if operated else 1.5, true)
		var label: String = "-" + travel.switches[i].designation
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
		var left: float = clampf(x - w * 0.5, LABEL_GAP, maxf(size.x - w - LABEL_GAP, LABEL_GAP))
		# Below the way, above it where the one before is in the way.
		var row: int = 0 if left >= rows[0] else (1 if left >= rows[1] else 0)
		rows[row] = left + w + LABEL_GAP
		var baseline: float = track_y + TICK + 2.0 + ascent if row == 0 else track_y - TICK - 4.0
		draw_string(font, Vector2(left, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, small, AppTheme.text if operated else AppTheme.text_muted)
	# The part, an arrow ahead of it while it moves.
	if absf(v) >= 1e-9:
		var dir: float = signf(v)
		var tip: Vector2 = Vector2(at_x + dir * (PART_RADIUS + 9.0), track_y)
		var back: float = tip.x - dir * 7.0
		draw_colored_polygon(PackedVector2Array([tip, Vector2(back, track_y - 5.0), Vector2(back, track_y + 5.0)]), AppTheme.accent)
	draw_circle(Vector2(at_x, track_y), PART_RADIUS, AppTheme.accent, true, -1.0, true)
	draw_circle(Vector2(at_x, track_y), PART_RADIUS, AppTheme.bg1, false, 1.5, true)
