class_name DatasheetFront
extends Control
## The device front on a datasheet: the device as the switchboard view draws
## it ([method CabinetParts.device]), as large as fits (at most twice its
## real size), with a label on a leader line at every terminal: those on its
## upper half above it, the others below, staggered where they would
## overlap.

## Points per millimetre at real size.
const PT_PER_MM: float = 72.0 / 25.4
const MAX_SCALE: float = 2.0
const LABEL_SIZE: int = 8
const LABEL_H: float = 13.0
## Rows of labels above and below the device.
const LEVELS: int = 4
const ROOM: float = 14.0 + LEVELS * LABEL_H

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
	_labels(top, origin, k, origin.y - 10.0, -1.0)
	_labels(bottom, origin, k, origin.y + device.y * k + 10.0, 1.0)


## Labels of [param terminals] ([name, Vector3]) in rows from [param edge]
## away from the device ([param away]: -1 up, 1 down): each in the row
## nearest the device where it overlaps no other label, no leader line runs
## through it and its own leader runs through no label nearer the device.
func _labels(terminals: Array, origin: Vector2, k: float, edge: float, away: float) -> void:
	var font: Font = AppTheme.mono_font()
	var ink: Color = SchematicTheme.DESIGNATION
	var rule: Color = Color(SchematicTheme.TEXT, 0.35)
	# Placed labels: [level, left, right, leader x].
	var placed: Array = []
	for t: Array in terminals:
		var name: String = t[0]
		var p: Vector3 = t[1]
		var screw: Vector2 = origin + Vector2(p.x, p.y) * k
		var w: float = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x + 6.0
		var level: int = 0
		while level < LEVELS - 1 and not _free(placed, level, screw.x - w * 0.5, screw.x + w * 0.5, screw.x):
			level += 1
		placed.append([level, screw.x - w * 0.5, screw.x + w * 0.5, screw.x])
		var center_y: float = edge + away * (LABEL_H * (level + 0.5))
		var box: Rect2 = Rect2(screw.x - w * 0.5, center_y - LABEL_H * 0.5 + 1.0, w, LABEL_H - 2.0)
		var from: Vector2 = screw + Vector2(0.0, away * p.z * k)
		var to: Vector2 = Vector2(screw.x, box.end.y if away < 0.0 else box.position.y)
		draw_line(from, to, rule, 0.6, true)
		draw_circle(screw, 1.4, ink)
		draw_rect(box, SchematicTheme.BACKGROUND)
		draw_rect(box, ink, false, 0.6, true)
		draw_string(font, Vector2(box.position.x + 3.0, center_y + LABEL_SIZE * 0.36), name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, ink)


## True when a label from [param left] to [param right] with its leader at
## [param x] fits in row [param level] among [param placed] labels.
static func _free(placed: Array, level: int, left: float, right: float, x: float) -> bool:
	const GAP: float = 2.0
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
