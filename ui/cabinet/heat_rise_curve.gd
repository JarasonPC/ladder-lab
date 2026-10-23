class_name HeatRiseCurve
extends Control
## The temperature curve of a switchboard's calculation ([HeatRise]): the
## temperature of the air inside (across) over the height of the enclosure
## (up, 0 the floor, 1 the top) as figs. 8 and 9 of the method draw it, the
## air round it and the most allowed as upright lines, and a mark for each
## rail at its height.

## The calculation drawn ({} for none, see [method HeatRise.calculate]).
var result: Dictionary = {}
var ambient: float = 35.0
var limit: float = 55.0
## The rails: (height 0..1, rail number).
var marks: Array[Vector2] = []

const PAD_LEFT: float = 36.0
const PAD_BOTTOM: float = 22.0
const PAD: float = 8.0


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size() - 3
	var muted: Color = AppTheme.text_muted
	var area: Rect2 = Rect2(PAD_LEFT, PAD, size.x - PAD_LEFT - PAD, size.y - PAD - PAD_BOTTOM)
	if area.size.x <= 10.0 or area.size.y <= 10.0:
		return
	draw_rect(area, Color(muted, 0.08))
	if result.is_empty():
		return
	var top: float = ambient + float(result["top"])
	var low: float = floorf(ambient / 5.0) * 5.0
	var high: float = ceilf((maxf(top, limit) + 2.0) / 5.0) * 5.0
	var to_x: Callable = func(t: float) -> float: return area.position.x + (t - low) / (high - low) * area.size.x
	var to_y: Callable = func(h: float) -> float: return area.end.y - h * area.size.y
	# Grid: every 5 °C across, the half and three quarters of the height up.
	var t: float = low
	while t <= high + 0.01:
		var x: float = to_x.call(t)
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(muted, 0.25))
		if int(roundf(t)) % 10 == 0:
			draw_string(font, Vector2(x - 24.0, area.end.y + font_size + 4.0), "%d °C" % roundi(t), HORIZONTAL_ALIGNMENT_CENTER, 48.0, font_size, muted)
		t += 5.0
	for h: float in [0.0, 0.5, 0.75, 1.0]:
		var y: float = to_y.call(h)
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(muted, 0.25))
		draw_string(font, Vector2(2.0, y + font_size * 0.35), String.num(h, 2), HORIZONTAL_ALIGNMENT_RIGHT, PAD_LEFT - 6.0, font_size, muted)
	# The air round it, and the most allowed.
	var ax: float = to_x.call(ambient)
	draw_dashed_line(Vector2(ax, area.position.y), Vector2(ax, area.end.y), muted, 1.0, 4.0)
	var lx: float = to_x.call(limit)
	draw_line(Vector2(lx, area.position.y), Vector2(lx, area.end.y), AppTheme.danger, 1.5)
	# The curve: solid where the method gives it, dashed under the middle.
	var colour: Color = AppTheme.success if result.get("ok", true) else AppTheme.danger
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 41:
		var h: float = i / 40.0
		points.append(Vector2(to_x.call(ambient + HeatRise.rise_at(result, h)), to_y.call(h)))
	for i: int in range(1, points.size()):
		if i <= 20:
			draw_dashed_line(points[i - 1], points[i], colour, 2.0, 4.0)
		else:
			draw_line(points[i - 1], points[i], colour, 2.0, true)
	for h: float in [0.5, 1.0]:
		draw_circle(Vector2(to_x.call(ambient + HeatRise.rise_at(result, h)), to_y.call(h)), 3.5, colour)
	for mark: Vector2 in marks:
		var at: Vector2 = Vector2(to_x.call(ambient + HeatRise.rise_at(result, mark.x)), to_y.call(mark.x))
		draw_circle(at, 2.5, AppTheme.accent)
		draw_string(font, at + Vector2(6.0, font_size * 0.35), str(int(mark.y)), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, AppTheme.accent)
