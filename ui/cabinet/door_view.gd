class_name DoorView
extends ControlBoxView
## Draws the door of a switchboard (rozvaděč) with its push buttons,
## switches and signal lamps ([member Switchboard.door]) like the real
## thing, in millimetres (see [CabinetPainter]): a light grey door as large
## as the enclosure (larger when its items need the room), two quarter-turn
## locks on the left, the switchboard's designation at the top left and the
## yellow warning sign at the top, the items in rows, each a 22 mm device
## with a black label holder under it; selector switches carry yellow tags
## with their positions above, rotary cam switches a bigger square front.
## Operated and edited as a control station ([ControlBoxView]).

## Least room a door item takes and the most it is given (the items share
## out the door's width and height), how far down the first row starts
## (under the warning sign), the room left and right of the rows and under
## the last.
const PITCH := Vector2(64.0, 80.0)
const MAX_PITCH := Vector2(130.0, 125.0)
const TOP: float = 110.0
const SIDE: float = 40.0
const BOTTOM: float = 60.0
## Middle of the device and of its label holder from the top of its cell.
const DEVICE_Y: float = 34.0
const HOLDER_Y: float = 66.0
const HOLDER := Vector2(44.0, 18.0)
## Radius of the bezel of a 22 mm device, half the side of a cam switch's front.
const RING: float = 15.0
const CAM: float = 24.0

## Real-world colours (RAL 7035 door, yellow tags), the same in both themes.
const DOOR := Color("d6d8d4")
const DOOR_EDGE := Color("a9ada8")
const LOCK := Color("c4c8cb")
const LOCK_DARK := Color("7d8287")
const PRINT := Color("26282b")
const TAG := Color("f2d22e")
const HOLDER_INSERT := Color("f7f7f2")

## Index of the switchboard whose door is drawn.
var board: int = 0
## Size (mm) of the enclosure, the door at least as large.
var enclosure: Vector2 = Vector2(400.0, 600.0)


func _get_minimum_size() -> Vector2:
	return Vector2(160.0, 220.0)


## Size of the door in mm: the enclosure's, larger only where its items do
## not fit with [constant PITCH] between them.
func door_size() -> Vector2:
	var b: ControlBox = box()
	var columns: int = b.columns if b != null else 1
	return Vector2(maxf(enclosure.x, 2.0 * SIDE + columns * PITCH.x), maxf(enclosure.y, TOP + _rows() * PITCH.y + BOTTOM))


func _rows() -> int:
	var b: ControlBox = box()
	return maxi(ceili(b.items.size() / float(b.columns)), 1) if b != null else 1


## Room each item takes on a door of [param door] mm: the width shared out
## by the columns, the height by the rows, within [constant PITCH] -
## [constant MAX_PITCH].
func _pitch(door: Vector2) -> Vector2:
	var b: ControlBox = box()
	var columns: int = b.columns if b != null else 1
	return Vector2(clampf((door.x - 2.0 * SIDE) / columns, PITCH.x, MAX_PITCH.x), clampf((door.y - TOP - BOTTOM) / _rows(), PITCH.y, MAX_PITCH.y))


## Pixels per mm: the whole door in sight.
func _k() -> float:
	var door: Vector2 = door_size()
	return maxf(minf((size.x - 8.0) / door.x, (size.y - 8.0) / door.y), 0.05)


## Pixel position of the door's top-left corner: centred.
func _origin() -> Vector2:
	return ((size - door_size() * _k()) * 0.5).floor()


## Cell of every item in mm: rows of the door's columns, centred across.
func _mm_cells() -> Array[Rect2]:
	var cells: Array[Rect2] = []
	var b: ControlBox = box()
	if b == null:
		return cells
	var door: Vector2 = door_size()
	var pitch: Vector2 = _pitch(door)
	var y: float = TOP
	var row_start: int = 0
	while row_start < b.items.size():
		var row_end: int = mini(row_start + b.columns, b.items.size())
		var left: float = door.x * 0.5 - b.columns * pitch.x * 0.5
		for i: int in range(row_start, row_end):
			cells.append(Rect2(left + (i - row_start) * pitch.x, y, pitch.x, pitch.y))
		y += pitch.y
		row_start = row_end
	return cells


func _cells() -> Array[Rect2]:
	var k: float = _k()
	var origin: Vector2 = _origin()
	var cells: Array[Rect2] = []
	for cell: Rect2 in _mm_cells():
		cells.append(Rect2(origin + cell.position * k, cell.size * k))
	return cells


func _knob_of(cell: Rect2) -> Vector2:
	return cell.position + Vector2(cell.size.x * 0.5, DEVICE_Y * _k())


# --- Drawing -------------------------------------------------------------------------

func _draw() -> void:
	var b: ControlBox = box()
	if b == null:
		return
	var k: float = _k()
	var p: CabinetPainter = CabinetPainter.new(self, k, _origin())
	var door: Vector2 = door_size()
	_door(p, door)
	if b.items.is_empty() and not simulating:
		p.text_centered(Vector2(door.x * 0.5, TOP + PITCH.y * 0.4), tr("Empty"), 9.0, Color(PRINT, 0.45))
	var cells: Array[Rect2] = _mm_cells()
	for i: int in cells.size():
		_door_item(p, b.items[i], cells[i])
	if not simulating and selected >= 0 and selected < cells.size():
		var mark: Rect2 = _cells()[selected].grow(-2.0)
		_rounded(mark, Color.TRANSPARENT, 6, AppTheme.accent, 2)


## The door itself: its face, the locks, the switchboard's designation and
## title, the warning sign.
func _door(p: CabinetPainter, door: Vector2) -> void:
	p.gradient(Rect2(Vector2.ZERO, door), DOOR.lightened(0.05), DOOR.darkened(0.04), 4.0, DOOR_EDGE, 0.6)
	p.rect(Rect2(Vector2(4.0, 4.0), door - Vector2(8.0, 8.0)), Color.TRANSPARENT, 3.0, Color(1, 1, 1, 0.35), 0.4)
	for y: float in [70.0, door.y - 70.0]:
		var at: Vector2 = Vector2(24.0, y)
		p.circle(at + Vector2(0.4, 0.8), 10.0, Color(0, 0, 0, 0.12))
		p.circle(at, 10.0, LOCK, LOCK_DARK, 0.3)
		p.circle(at, 6.5, LOCK.darkened(0.12), LOCK_DARK, 0.2)
		p.line(at + Vector2(-3.5, 3.5), at + Vector2(3.5, -3.5), LOCK_DARK, 1.6)
	if document != null and board >= 0 and board < document.switchboards.size():
		var switchboard: Switchboard = document.switchboards[board]
		p.text(Vector2(44.0, 42.0), "+" + switchboard.name, 16.0, PRINT, -1, true, door.x * 0.5 - 70.0)
		if not switchboard.title.is_empty():
			p.text(Vector2(44.0, 54.0), switchboard.title, 6.0, Color(PRINT, 0.75), -1, false, door.x * 0.5 - 70.0)
	_warning(p, Vector2(door.x * 0.5, 22.0))


## The yellow sign warning of the electrical equipment, its top middle at
## [param top].
func _warning(p: CabinetPainter, top: Vector2) -> void:
	var plate: Rect2 = Rect2(top - Vector2(24.0, 0.0), Vector2(48.0, 58.0))
	p.rect(plate, Color("fbfbf6"), 1.0, Color(0, 0, 0, 0.2), 0.2)
	var a: Vector2 = Vector2(top.x, top.y + 4.0)
	var triangle: PackedVector2Array = PackedVector2Array([a, a + Vector2(19.0, 32.0), a + Vector2(-19.0, 32.0)])
	p.polygon(triangle, TAG, PRINT, 1.6)
	var bolt: PackedVector2Array = PackedVector2Array([
		a + Vector2(2.5, 9.0), a + Vector2(-4.0, 21.0), a + Vector2(0.0, 21.0),
		a + Vector2(-2.5, 30.0), a + Vector2(4.5, 17.0), a + Vector2(0.5, 17.0),
	])
	p.polygon(bolt, PRINT)
	var band: Rect2 = Rect2(plate.position.x + 2.0, top.y + 39.0, plate.size.x - 4.0, 17.0)
	p.rect(band, TAG, 0.6)
	p.text_centered(band.get_center() + Vector2(0.0, -3.0), tr("WARNING"), 5.5, PRINT, true, band.size.x - 2.0)
	p.text_centered(band.get_center() + Vector2(0.0, 4.0), tr("Electrical equipment!"), 2.8, PRINT, true, band.size.x - 2.0)


func _door_item(p: CabinetPainter, item: ControlBoxItem, cell: Rect2) -> void:
	var center: Vector2 = cell.position + Vector2(cell.size.x * 0.5, DEVICE_Y)
	var color: Color = COLORS.get(item.color, COLORS["green"])
	var light: int = (1 if _lit(item.lamp) else 0) if _illuminated(item) else -1
	match item.kind:
		ControlBoxItem.Kind.BUTTON:
			_door_button(p, center, color, _travel(item.designation), light)
		ControlBoxItem.Kind.SWITCH:
			var cam: CamSwitch = _device(item.designation) as CamSwitch
			if cam != null:
				_door_cam(p, center, color, cam, light)
			else:
				_door_switch(p, center, color, _turn(item.designation), light, _three_positions(item.designation))
		ControlBoxItem.Kind.LAMP:
			_door_lamp(p, center, color, _lit(item.designation))
	_holder(p, cell.position + Vector2(cell.size.x * 0.5, HOLDER_Y), item)
	if not _assigned(item):
		# Not connected to the schematic: faded.
		p.rect(cell.grow(-1.0), Color(DOOR, 0.6), 2.0)
	var key: String = document.key_bindings.get(item.designation, "") if item.kind != ControlBoxItem.Kind.LAMP and show_keys else ""
	if not key.is_empty():
		var held: bool = simulating and item.kind == ControlBoxItem.Kind.BUTTON and _travel(item.designation) > 0.5
		var cap: Vector2 = Keycap.size_of(key, KEY_FONT_SIZE)
		var under: Vector2 = p.px(cell.position + Vector2(cell.size.x * 0.5, HOLDER_Y + HOLDER.y * 0.5 + 2.0))
		Keycap.draw(self, Vector2(under.x - cap.x * 0.5, under.y), key, KEY_FONT_SIZE, held)


## The black label holder under a device with its white insert: the plate
## text over the designations, or the designations alone.
func _holder(p: CabinetPainter, center: Vector2, item: ControlBoxItem) -> void:
	p.rect(Rect2(center - HOLDER * 0.5, HOLDER), BEZEL_INNER.darkened(0.4), 1.2)
	var insert: Rect2 = Rect2(center - HOLDER * 0.5 + Vector2(2.0, 2.0), HOLDER - Vector2(4.0, 4.0))
	p.rect(insert, HOLDER_INSERT, 0.4)
	var marks: PackedStringArray = PackedStringArray()
	for designation: String in [item.designation, item.lamp if _illuminated(item) else ""]:
		if not designation.is_empty():
			marks.append("-" + designation)
	var designations: String = " ".join(marks)
	if item.label.is_empty() or designations.is_empty():
		var only: String = item.label if not item.label.is_empty() else (designations if not designations.is_empty() else "?")
		p.text_centered(insert.get_center(), only, 5.0, PRINT, true, insert.size.x - 1.5)
		return
	p.text_centered(insert.get_center() + Vector2(0.0, -2.3), item.label, 4.4, PRINT, true, insert.size.x - 1.5)
	p.text_centered(insert.get_center() + Vector2(0.0, 3.2), designations, 3.2, Color(PRINT, 0.7), true, insert.size.x - 1.5)


## Glow round an illuminated button, switch or lamp that is lit.
func _door_glow(p: CabinetPainter, center: Vector2, radius: float, color: Color, lit: bool) -> void:
	if lit:
		for k: int in 3:
			p.circle(center, radius + 1.5 + 2.5 * k, Color(color, 0.22 - 0.065 * k))


## Push button: a black bezel and a flat cap that sinks in while pressed.
func _door_button(p: CabinetPainter, center: Vector2, color: Color, travel: float, light: int) -> void:
	_door_glow(p, center, RING, color, light == 1)
	p.circle(center, RING, BEZEL_INNER.darkened(0.45))
	p.ring(center, RING - 0.6, Color(1, 1, 1, 0.1), 0.6)
	p.circle(center, RING - 2.5, BEZEL_INNER.darkened(0.2))
	var cap: Color = _lit_color(color, light).darkened(0.15 * travel)
	var radius: float = 11.0 - 1.0 * travel
	p.circle(center, radius, cap.darkened(0.18) if light != 1 else cap.lightened(0.25))
	p.circle(center, radius - 1.2, cap)
	if light == 1:
		p.circle(center, radius * 0.55, Color(1, 1, 1, 0.22))


## Signal lamp: a black body, a coloured rim and a domed lens, glowing while lit.
func _door_lamp(p: CabinetPainter, center: Vector2, color: Color, lit: bool) -> void:
	_door_glow(p, center, RING, color, lit)
	p.circle(center, RING, BEZEL_INNER.darkened(0.45))
	var rim: Color = color.lightened(0.4) if lit else Color.from_hsv(color.h, color.s * 0.7, color.v * 0.7)
	var lens: Color = color.lightened(0.15) if lit else Color.from_hsv(color.h, color.s * 0.8, color.v * 0.5)
	p.circle(center, 12.5, rim)
	p.circle(center, 10.0, lens, rim.darkened(0.25), 0.3)
	if lit:
		p.circle(center, 6.0, Color(1, 1, 1, 0.25))
	p.circle(center + Vector2(-3.2, -3.2), 3.6, Color(1, 1, 1, 0.14))
	p.circle(center + Vector2(-3.8, -3.8), 1.4, Color(1, 1, 1, 0.45 if lit else 0.3))


## Selector switch: a black bezel and grip, yellow tags with its positions
## above it (0 I, or I 0 II); [param turn] as [method ControlBoxView._turn].
func _door_switch(p: CabinetPainter, center: Vector2, color: Color, turn: float, light: int, three: bool) -> void:
	var marks: PackedStringArray = PackedStringArray(["I", "0", "II"]) if three else PackedStringArray(["0", "I"])
	for m: int in marks.size():
		var x: float = -14.0 + 28.0 * m / float(marks.size() - 1)
		var tag: Rect2 = Rect2(center + Vector2(x - 5.0, -RING - 12.0 - (2.0 if three and m == 1 else 0.0)), Vector2(10.0, 7.0))
		p.rect(tag, TAG, 0.5)
		p.text_centered(tag.get_center(), marks[m], 4.0, PRINT)
	_door_glow(p, center, RING, color, light == 1)
	p.circle(center, RING, BEZEL_INNER.darkened(0.45))
	p.circle(center, RING - 2.0, BEZEL_INNER)
	var along: Vector2 = Vector2.UP.rotated(turn * PI * 0.25)
	var across: Vector2 = Vector2(-along.y, along.x)
	var grip: Color = _lit_color(color if color.get_luminance() > 0.1 else Color("45484c"), light)
	p.polygon(PackedVector2Array([
		center + along * 11.5 + across * 3.5, center + along * 11.5 - across * 3.5,
		center - along * 11.5 - across * 3.5, center - along * 11.5 + across * 3.5,
	]), grip, grip.darkened(0.35), 0.3)
	p.line(center, center + along * 9.5, Color(1, 1, 1, 0.85), 1.2)


## Rotary cam switch: bigger than the 22 mm devices, a square black front
## with its positions in white round a broad handle.
func _door_cam(p: CabinetPainter, center: Vector2, color: Color, cam: CamSwitch, light: int) -> void:
	_door_glow(p, center, CAM, color, light == 1)
	p.rect(Rect2(center - Vector2(CAM, CAM), Vector2(CAM, CAM) * 2.0), BEZEL_INNER.darkened(0.45), 1.5, Color(1, 1, 1, 0.1), 0.3)
	for position: int in cam.knob_positions():
		var out: Vector2 = Vector2.UP.rotated(deg_to_rad(_cam_degrees(cam, position)))
		p.text_centered(center + out * (CAM - 5.0), CamSwitch.MARKS[position], 4.5, PLATE_TEXT)
	p.circle(center, 12.0, BEZEL_INNER, Color(1, 1, 1, 0.12), 0.3)
	var along: Vector2 = Vector2.UP.rotated(deg_to_rad(_cam_degrees(cam, cam.position)))
	var across: Vector2 = Vector2(-along.y, along.x)
	var grip: Color = _lit_color(color if color.get_luminance() > 0.1 else Color("5c6167"), light)
	p.polygon(PackedVector2Array([
		center + along * 15.0 + across * 3.5, center + along * 15.0 - across * 3.5,
		center - along * 13.0 - across * 5.5, center - along * 13.0 + across * 5.5,
	]), grip, grip.lightened(0.25), 0.3)
	p.line(center + along * 4.0, center + along * 13.0, Color(1, 1, 1, 0.9), 1.4)
