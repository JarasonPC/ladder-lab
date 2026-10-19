class_name DatasheetFront
extends Control
## The device front on a datasheet: the device as the switchboard view draws
## it ([method CabinetParts.device]), as large as fits (at most twice its
## real size), with a label on a leader line at every terminal: those on its
## upper half above it, the others below, staggered in as many rows as they
## need where they would overlap ([method arrange]); terminals close together
## get smaller labels, standing upright when lying ones do not fit.

## Points per millimetre at real size.
const PT_PER_MM: float = 72.0 / 25.4
const MAX_SCALE: float = 2.0
const LABEL_SIZE: int = 8
const LABEL_H: float = 13.0
## Rows of labels the device leaves room for at least, above and below it.
const LEVELS: int = 4
const ROOM: float = 14.0 + LEVELS * LABEL_H
## Labels tried in turn, until all fit: [upright, text size].
const STYLES: Array[Array] = [[false, 8], [false, 7], [true, 8], [true, 7], [true, 6], [true, 5]]
## Room between two labels, and between a label and a leader passing it.
const GAP: float = 1.0

var desc: Dictionary


func _init(p_desc: Dictionary) -> void:
	desc = p_desc
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Points per millimetre the device is drawn at in [param area].
static func scale_for(device: Vector2, area: Vector2) -> float:
	return minf(MAX_SCALE * PT_PER_MM, minf((area.x - 8.0) / device.x, (area.y - 2.0 * ROOM) / device.y))


func _draw() -> void:
	var device: Vector2 = CabinetParts.device_size(desc)
	if device == Vector2.ZERO:
		return
	var k: float = scale_for(device, size)
	var origin: Vector2 = ((size - device * k) * 0.5).round()
	CabinetParts.device(CabinetPainter.new(self, k, origin), desc)
	var points: Dictionary = CabinetParts.terminal_points(int(desc["kind"]), desc)
	var top: Array = []
	var bottom: Array = []
	for name: String in points:
		var p: Vector3 = points[name]
		(top if p.y < device.y * 0.5 else bottom).append([name, p])
	var by_x: Callable = func(a: Array, b: Array) -> bool: return (a[1] as Vector3).x < (b[1] as Vector3).x
	top.sort_custom(by_x)
	bottom.sort_custom(by_x)
	var below: float = origin.y + device.y * k + 10.0
	_labels(top, origin, k, origin.y - 10.0, -1.0, origin.y - 10.0)
	_labels(bottom, origin, k, below, 1.0, size.y - below)


## Labels of [param terminals] ([name, Vector3]) in rows from [param edge]
## away from the device ([param away]: -1 up, 1 down), at most [param room]
## deep, as [method arrange] places them.
func _labels(terminals: Array, origin: Vector2, k: float, edge: float, away: float, room: float) -> void:
	var names: PackedStringArray = PackedStringArray()
	var xs: PackedFloat32Array = PackedFloat32Array()
	for t: Array in terminals:
		names.append(t[0])
		xs.append(origin.x + (t[1] as Vector3).x * k)
	var arranged: Dictionary = arrange(names, xs, room)
	var font: Font = AppTheme.mono_font()
	var text_size: int = arranged["size"]
	var upright: bool = arranged["upright"]
	var depth: float = arranged["depth"]
	var ink: Color = SchematicTheme.DESIGNATION
	var rule: Color = Color(SchematicTheme.TEXT, 0.35)
	for i: int in terminals.size():
		var p: Vector3 = terminals[i][1]
		var screw: Vector2 = origin + Vector2(p.x, p.y) * k
		var label: Array = arranged["labels"][i]
		var near: float = edge + away * (depth * int(label[0]) + 1.0)
		var length: float = label[4]
		var box: Rect2 = Rect2(label[1], minf(near, near + away * length), float(label[2]) - float(label[1]), length)
		draw_line(screw + Vector2(0.0, away * p.z * k), Vector2(screw.x, near), rule, 0.6, true)
		draw_circle(screw, 1.4, ink)
		draw_rect(box, SchematicTheme.BACKGROUND)
		draw_rect(box, ink, false, 0.6, true)
		if upright:
			# Read from below, the baseline on the right of the box.
			draw_set_transform(Vector2(box.get_center().x + text_size * 0.36, box.end.y - 3.0), -PI * 0.5)
			draw_string(font, Vector2.ZERO, names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, ink)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_string(font, Vector2(box.position.x + 3.0, box.get_center().y + text_size * 0.36), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, ink)


## Labels of the terminals [param names] with their leaders at [param xs]
## (in order along the device), in rows at most [param room] deep in all:
## {"size" (of the text), "upright", "depth" (of a row), "labels": [row,
## left, right, leader x, length across the rows] each}. Each label goes in
## the row nearest the device where it overlaps no other label, no leader
## runs through it and its own leader runs through no label nearer the
## device; the first of [constant STYLES] with which every label finds such a
## row (the last one when none does).
static func arrange(names: PackedStringArray, xs: PackedFloat32Array, room: float) -> Dictionary:
	var font: Font = AppTheme.mono_font()
	var result: Dictionary = {}
	for style: Array in STYLES:
		var upright: bool = style[0]
		var text_size: int = style[1]
		var h: float = LABEL_H * text_size / LABEL_SIZE
		var widths: Array[float] = []
		var longest: float = 0.0
		for name: String in names:
			widths.append(font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x + 6.0)
			longest = maxf(longest, widths[-1])
		var depth: float = longest + 2.0 if upright else h
		var levels: int = maxi(1, floori(room / depth))
		var labels: Array = []
		var fits: bool = true
		for i: int in names.size():
			var half: float = (h - 2.0 if upright else widths[i]) * 0.5
			var left: float = xs[i] - half
			var right: float = xs[i] + half
			var level: int = 0
			while level < levels - 1 and not _free(labels, level, left, right, xs[i]):
				level += 1
			fits = fits and _free(labels, level, left, right, xs[i])
			labels.append([level, left, right, xs[i], widths[i] if upright else h - 2.0])
		result = {"size": text_size, "upright": upright, "depth": depth, "labels": labels}
		if fits:
			break
	return result


## True when a label from [param left] to [param right] with its leader at
## [param x] fits in row [param level] among [param placed] labels.
static func _free(placed: Array, level: int, left: float, right: float, x: float) -> bool:
	for other: Array in placed:
		var o_level: int = other[0]
		if o_level == level and left < other[2] + GAP and right > other[1] - GAP:
			return false
		# Its leader would cross a label nearer the device.
		if o_level < level and x > other[1] - GAP and x < other[2] + GAP:
			return false
		# A leader of a label farther out would cross it.
		if o_level > level and other[3] > left - GAP and other[3] < right + GAP:
			return false
	return true
