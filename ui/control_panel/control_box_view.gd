class_name ControlBoxView
extends Control
## Draws one [ControlBox] (a control station) like the real thing: a grey
## housing with black label plates, coloured push buttons, selector switches
## (0 / I) and signal lamps. While simulating, a push button is held with the
## left mouse button, a switch turns over on click and a lamp lights while its
## lamp in the schematic has power. While editing, a click selects an item.

## A push button was pressed (true) or let go (false) while simulating.
signal button_held(designation: String, pressed: bool)
## A switch was clicked while simulating; a rotary cam switch is turned
## [param steps] positions to the right (negative: to the left), clicked
## right or left of the middle of its knob.
signal switch_toggled(designation: String, steps: int)
## An item was clicked while editing (-1: the housing beside the items).
signal item_clicked(item_index: int)
## An item was right-clicked (for its menu).
signal item_menu(item_index: int)

const CELL_W: float = ControlBox.CELL_W
const ROW_H: float = ControlBox.ROW_H
const PAD_X: float = ControlBox.PAD_X
## Room above the items for the cable gland and the screws.
const PAD_TOP: float = ControlBox.PAD_TOP
const PAD_BOTTOM: float = ControlBox.PAD_BOTTOM
const TITLE_H: float = ControlBox.TITLE_H
const PLATE := Vector2(64.0, 34.0)
const BEZEL_R: float = 21.0
## Half the side of a rotary cam switch's front plate (bigger than a
## selector switch).
const CAM_HALF: float = 27.0
const CAP_R: float = 15.5
const PLATE_FONT_SIZE: int = 12
const MIN_PLATE_FONT_SIZE: int = 9

## Real-world colours, the same in both themes (like the photographed box).
const SHELL := Color("3a3d41")
const COVER := Color("d5d8db")
const COVER_EDGE := Color("babec2")
const GLAND := Color("1f2023")
const SCREW := Color("c9cdd1")
const SCREW_EDGE := Color("868a8f")
const PLATE_COLOR := Color("1d1e20")
const PLATE_TEXT := Color("f2f2f2")
const BEZEL := Color("17181a")
const BEZEL_INNER := Color("2c2e31")
const MARK_TEXT := Color("3a3d41")
const TITLE_TEXT := Color("80858a")
## Designations on the plates ("-SB1", "-H1"), teal as on the schematic.
const PLATE_DESIGNATION := Color("5fd0c4")
const DESIGNATION_FONT_SIZE: int = 10
## Size of the keycaps of keys bound to the buttons and switches.
const KEY_FONT_SIZE: int = 10
## Cap, grip and lens colours by [constant ControlBoxItem.COLORS] name.
const COLORS: Dictionary[String, Color] = {
	"green": Color("2ea44f"),
	"red": Color("d63b3b"),
	"black": Color("2a2c2f"),
	"white": Color("efefeb"),
	"yellow": Color("f1c21b"),
	"blue": Color("2f6fd4"),
}

var document: SchematicDocument
## The station (or door, see [DoorView]) drawn: its index in
## [method SchematicDocument.control_panels].
var box_index: int = 0
## Operate the circuit (true) or select items for editing (false).
var simulating: bool = false
## Item selected for editing, -1 for none.
var selected: int = -1
## Draw the keys of the keyboard bound to the buttons and switches (off for exports).
var show_keys: bool = true

## Designation of the push button held with the mouse, "" for none.
var _held: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	update_minimum_size()


func box() -> ControlBox:
	if document == null:
		return null
	var panels: Array[ControlBox] = document.control_panels()
	return panels[box_index] if box_index >= 0 and box_index < panels.size() else null


func _get_minimum_size() -> Vector2:
	var b: ControlBox = box()
	return b.face_size() if b != null else Vector2.ZERO


## Cell of every item, in item order: rows of [member ControlBox.columns]
## items.
func _cells() -> Array[Rect2]:
	var cells: Array[Rect2] = []
	var b: ControlBox = box()
	if b == null:
		return cells
	var y: float = PAD_TOP
	var row_start: int = 0
	while row_start < b.items.size():
		var row_end: int = mini(row_start + b.columns, b.items.size())
		for i: int in range(row_start, row_end):
			cells.append(Rect2(PAD_X + (i - row_start) * CELL_W, y, CELL_W, ROW_H))
		y += ROW_H
		row_start = row_end
	return cells


## True for a button or switch with a signal lamp inside it.
static func _illuminated(item: ControlBoxItem) -> bool:
	return item.kind != ControlBoxItem.Kind.LAMP and not item.lamp.is_empty()


## Index of the item under [param point], or -1.
func _item_at(point: Vector2) -> int:
	var cells: Array[Rect2] = _cells()
	for i: int in cells.size():
		if cells[i].has_point(point):
			return i
	return -1


# --- State of the devices --------------------------------------------------------

func _device(designation: String) -> CircuitComponent:
	if designation.is_empty() or document == null:
		return null
	# A button's name may be shared with contacts of the button.
	var operator: CircuitComponent = document.circuit.get_operator(designation)
	return operator if operator != null else document.circuit.get_component(designation)


## True when the item shows a device of its kind that the circuit has.
func _assigned(item: ControlBoxItem) -> bool:
	var c: CircuitComponent = _device(item.designation)
	return c != null and ControlBoxItem.kind_of(c) == item.kind


## How far the button or switch is operated, 0..1.
func _travel(designation: String) -> float:
	var c: CircuitComponent = _device(designation)
	return (c as SwitchingElement).get_travel() if c is SwitchingElement else 0.0


## How far switch [param designation] is turned, -1 (left) .. 1 (right):
## 0-I from 0 at the left to I at the right, I-0-II from I at the left
## through 0 (up) to II at the right.
func _turn(designation: String) -> float:
	var c: CircuitComponent = _device(designation)
	if not (c is LatchingSwitch):
		return -1.0
	var switch: LatchingSwitch = c as LatchingSwitch
	if switch.three_positions:
		return switch.actuator_two.position - switch.actuator.position
	return switch.actuator.position * 2.0 - 1.0


## True for a selector switch with the positions I-0-II.
func _three_positions(designation: String) -> bool:
	var c: CircuitComponent = _device(designation)
	return c is LatchingSwitch and (c as LatchingSwitch).three_positions


func _lit(designation: String) -> bool:
	var c: CircuitComponent = _device(designation)
	return c is Lamp and (c as Lamp).energized


# --- Input -------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: int = _item_at((event as InputEventMouseMotion).position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered >= 0 and _clickable(hovered) else Control.CURSOR_ARROW
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT and (event as InputEventMouseButton).pressed:
		var at: int = _item_at((event as InputEventMouseButton).position)
		if at >= 0:
			item_menu.emit(at)
			accept_event()
		return
	if not (event is InputEventMouseButton) or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		if not _held.is_empty():
			button_held.emit(_held, false)
			_held = ""
			accept_event()
		return
	var index: int = _item_at(mb.position)
	if not simulating:
		item_clicked.emit(index)
		accept_event()
		return
	if index < 0 or not _clickable(index):
		return
	var item: ControlBoxItem = box().items[index]
	if item.kind == ControlBoxItem.Kind.BUTTON:
		_held = item.designation
		button_held.emit(_held, true)
	elif _device(item.designation) is CamSwitch or _three_positions(item.designation):
		switch_toggled.emit(item.designation, -1 if mb.position.x < _knob_of(_cells()[index]).x else 1)
	else:
		switch_toggled.emit(item.designation, 0)
	accept_event()


func _clickable(index: int) -> bool:
	if not simulating:
		return true
	var item: ControlBoxItem = box().items[index]
	return item.kind != ControlBoxItem.Kind.LAMP and _assigned(item)


func _get_tooltip(at_position: Vector2) -> String:
	var index: int = _item_at(at_position)
	if index < 0:
		return ""
	var item: ControlBoxItem = box().items[index]
	var text: String = tr(StationPanel.item_title(document, item))
	if item.designation.is_empty():
		text += " – " + tr("no device chosen")
	else:
		text += " -" + item.designation
		if not _assigned(item):
			text += " – " + tr("not in the schematic")
	if _illuminated(item):
		text += "\n" + tr("Signal lamp") + " -" + item.lamp
	return text


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


# --- Drawing -------------------------------------------------------------------------

func _draw() -> void:
	var b: ControlBox = box()
	if b == null:
		return
	var w: float = size.x
	# Cable gland on top, the dark shell and the light cover in front of it.
	_rounded(Rect2(w * 0.5 - 18.0, 0.0, 36.0, 14.0), GLAND, 4)
	_rounded(Rect2(0.0, 8.0, w, size.y - 8.0), SHELL, 10)
	var cover: Rect2 = Rect2(2.0, 9.0, w - 9.0, size.y - 13.0)
	_rounded(cover, COVER, 9, COVER_EDGE)
	for corner: Vector2 in [cover.position + Vector2(10, 10), Vector2(cover.end.x - 10, cover.position.y + 10), Vector2(cover.position.x + 10, cover.end.y - 10), cover.end - Vector2(10, 10)]:
		_screw(corner)
	var cells: Array[Rect2] = _cells()
	if b.items.is_empty() and not simulating:
		var font: Font = AppTheme.ui_font()
		var text: String = tr("Empty")
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_FONT_SIZE)
		draw_string(font, Vector2(w * 0.5 - text_size.x * 0.5, PAD_TOP + ROW_H * 0.5 + font.get_ascent(PLATE_FONT_SIZE) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_FONT_SIZE, TITLE_TEXT)
	for i: int in cells.size():
		_draw_item(b.items[i], cells[i])
	if not simulating and selected >= 0 and selected < cells.size():
		_rounded(cells[selected].grow(-2.0), Color.TRANSPARENT, 6, AppTheme.accent, 2)
	if not b.title.is_empty():
		var bold: Font = AppTheme.bold_font()
		# Between the cover's bottom screws, cut short with an ellipsis.
		var room: float = cover.size.x - 2.0 * 18.0
		var title: String = b.title
		while title.length() > 1 and bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_FONT_SIZE).x > room:
			title = title.left(title.length() - 2) + "…"
		var title_size: Vector2 = bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_FONT_SIZE)
		var at: Vector2 = Vector2(w * 0.5 - 3.5 - title_size.x * 0.5, size.y - PAD_BOTTOM * 0.5 - 4.0)
		# Embossed lettering, like the maker's name on the cover.
		draw_string(bold, at + Vector2(0, 1), title, HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_FONT_SIZE, Color(1, 1, 1, 0.6))
		draw_string(bold, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_FONT_SIZE, TITLE_TEXT)


func _draw_item(item: ControlBoxItem, cell: Rect2) -> void:
	var cy: float = cell.position.y + ROW_H * 0.5
	var plate: Rect2 = Rect2(cell.position.x + 6.0, cy - PLATE.y * 0.5, PLATE.x, PLATE.y)
	_rounded(plate, PLATE_COLOR, 3)
	var marks: PackedStringArray = PackedStringArray()
	for designation: String in [item.designation, item.lamp if _illuminated(item) else ""]:
		if not designation.is_empty():
			marks.append("-" + designation)
	_plate_text(plate, item.label, " ".join(marks))
	var center: Vector2 = _knob_of(cell)
	var color: Color = COLORS.get(item.color, COLORS["green"])
	# -1: no lamp inside, 0: its lamp is off, 1: lit.
	var light: int = (1 if _lit(item.lamp) else 0) if _illuminated(item) else -1
	match item.kind:
		ControlBoxItem.Kind.BUTTON:
			_draw_button(center, color, _travel(item.designation), light)
		ControlBoxItem.Kind.SWITCH:
			var cam: CamSwitch = _device(item.designation) as CamSwitch
			if cam != null:
				_draw_cam_switch(center, color, cam, light)
			else:
				_draw_switch(center, color, _turn(item.designation), light, _three_positions(item.designation))
		ControlBoxItem.Kind.LAMP:
			_draw_lamp(center, BEZEL_R - 1.0, color, _lit(item.designation))
	if not _assigned(item):
		# Not connected to the schematic: faded.
		draw_rect(cell.grow(-1.0), Color(COVER, 0.55))
	var key: String = document.key_bindings.get(item.designation, "") if item.kind != ControlBoxItem.Kind.LAMP and show_keys else ""
	if not key.is_empty():
		# The key that operates it, on the cover under the label plate (clear
		# of the button and the next row).
		var held: bool = simulating and item.kind == ControlBoxItem.Kind.BUTTON and _travel(item.designation) > 0.5
		var cap: Vector2 = Keycap.size_of(key, KEY_FONT_SIZE)
		Keycap.draw(self, Vector2(plate.get_center().x - cap.x * 0.5, plate.end.y + 1.0), key, KEY_FONT_SIZE, held)


## Middle of the button, switch or lamp of the item in [param cell], right
## of its label plate.
func _knob_of(cell: Rect2) -> Vector2:
	return Vector2(cell.position.x + 6.0 + PLATE.x + 14.0 + BEZEL_R, cell.position.y + ROW_H * 0.5)


## Label plate: the text in white with the designations in teal under it;
## only the designations (bigger) when there is no text.
func _plate_text(plate: Rect2, label: String, marks: String) -> void:
	var font: Font = AppTheme.bold_font()
	if label.is_empty() or marks.is_empty():
		var only: String = label if not label.is_empty() else (marks if not marks.is_empty() else "?")
		_line_text(plate, only, PLATE_FONT_SIZE, PLATE_TEXT if marks.is_empty() else PLATE_DESIGNATION, plate.get_center().y + _middle(font, PLATE_FONT_SIZE))
		return
	var top: float = plate.position.y + 4.0 + font.get_ascent(PLATE_FONT_SIZE)
	_line_text(plate, label, PLATE_FONT_SIZE, PLATE_TEXT, top)
	_line_text(plate, marks, DESIGNATION_FONT_SIZE, PLATE_DESIGNATION, top + 2.0 + font.get_ascent(DESIGNATION_FONT_SIZE))


## Offset from the middle of a line to its baseline.
static func _middle(font: Font, font_size: int) -> float:
	return (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5


## One line centred across [param rect] on [param baseline], smaller when it
## is long, cut off when it still does not fit.
func _line_text(rect: Rect2, text: String, font_size: int, color: Color, baseline: float) -> void:
	var font: Font = AppTheme.bold_font()
	var room: float = rect.size.x - 8.0
	var fitted: int = font_size
	while fitted > MIN_PLATE_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > room:
		fitted -= 1
	while text.length() > 1 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > room:
		text = text.left(text.length() - 2) + "…"
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x
	draw_string(font, Vector2(rect.get_center().x - width * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted, color)


## Push button: a matte black bezel and a flat matte cap that sinks in while
## pressed (no gloss). [param light]: -1 plain cap, 0 illuminated cap with its
## lamp off, 1 lit.
func _draw_button(center: Vector2, color: Color, travel: float, light: int = -1) -> void:
	_glow(center, color, light)
	draw_circle(center, BEZEL_R, BEZEL, true, -1.0, true)
	draw_arc(center, BEZEL_R - 0.8, 0.0, TAU, 48, Color(1, 1, 1, 0.08), 1.2, true)
	draw_circle(center, BEZEL_R - 3.5, BEZEL_INNER.darkened(0.3), true, -1.0, true)
	var radius: float = CAP_R - 1.5 * travel
	var cap: Color = _lit_color(color, light).darkened(0.15 * travel)
	draw_circle(center, radius, cap.darkened(0.18) if light != 1 else cap.lightened(0.25), true, -1.0, true)
	draw_circle(center, radius - 1.6, cap, true, -1.0, true)
	if light == 1:
		# The lamp shines through the middle of the translucent cap.
		draw_circle(center, radius * 0.55, Color(1, 1, 1, 0.22), true, -1.0, true)


## Colour of a cap or grip: as it is, or as a translucent part with a lamp
## behind it (dull while the lamp is off, bright while it is lit).
static func _lit_color(color: Color, light: int) -> Color:
	match light:
		0:
			return Color.from_hsv(color.h, color.s * 0.75, color.v * 0.7)
		1:
			return color.lightened(0.3)
	return color


## Halo around an illuminated button or switch whose lamp is lit.
func _glow(center: Vector2, color: Color, light: int) -> void:
	if light == 1:
		for k: int in 3:
			draw_circle(center, BEZEL_R + 1.0 + 3.0 * k, Color(color, 0.2 - 0.06 * k), true, -1.0, true)


## Selector switch with positions 0 (turned left) and I (turned right), or
## with [param three] I (left), 0 (up) and II (right); [param turn] -1 (left)
## .. 1 (right) as [method _turn]. An illuminated one ([param light] as for
## [method _draw_button]) has a lit grip.
func _draw_switch(center: Vector2, color: Color, turn: float, light: int = -1, three: bool = false) -> void:
	_glow(center, color, light)
	var font: Font = AppTheme.bold_font()
	var marks: PackedStringArray = PackedStringArray(["I", "0", "II"]) if three else PackedStringArray(["0", "I"])
	for mark: int in marks.size():
		var text: String = marks[mark]
		var mark_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var x: float = (-18.0 + 36.0 * mark / float(marks.size() - 1))
		var at: Vector2 = center + Vector2(x, -BEZEL_R + 1.0 - (5.0 if three and mark == 1 else 0.0))
		draw_string(font, Vector2(at.x - mark_size.x * 0.5, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MARK_TEXT)
	draw_circle(center, BEZEL_R, BEZEL, true, -1.0, true)
	draw_circle(center, BEZEL_R - 3.0, BEZEL_INNER, true, -1.0, true)
	var angle: float = turn * PI * 0.25
	var along: Vector2 = Vector2(sin(angle), -cos(angle))
	var across: Vector2 = Vector2(-along.y, along.x)
	var grip: Color = _lit_color(color if color.get_luminance() > 0.1 else Color("45484c"), light)
	var points: PackedVector2Array = PackedVector2Array([
		center + along * 15.0 + across * 4.5, center + along * 15.0 - across * 4.5,
		center - along * 15.0 - across * 4.5, center - along * 15.0 + across * 4.5,
	])
	draw_colored_polygon(points, grip)
	points.append(points[0])
	draw_polyline(points, grip.darkened(0.35), 1.0, true)
	draw_line(center, center + along * 12.0, Color(1, 1, 1, 0.85), 2.0, true)


## Rotary cam switch: a square black front plate with its positions marked
## round the knob in white (0 up, I to the right; I-0-II: I up left, 0 up,
## II up right), a round boss and a broad handle across it, its pointer end
## (with a white stripe) at the position it is in.
func _draw_cam_switch(center: Vector2, color: Color, cam: CamSwitch, light: int = -1) -> void:
	_glow(center, color, light)
	# Bigger than a selector switch, as the real ones are.
	var half: float = CAM_HALF
	_rounded(Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), BEZEL, 3, Color(1, 1, 1, 0.08))
	var font: Font = AppTheme.bold_font()
	for position: int in cam.knob_positions():
		var out: Vector2 = Vector2.UP.rotated(deg_to_rad(_cam_degrees(cam, position)))
		var text: String = CamSwitch.MARKS[position]
		var mark_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		var at: Vector2 = center + out * (half - 6.0)
		draw_string(font, at + Vector2(-mark_size.x * 0.5, font.get_ascent(9) * 0.5 - 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, PLATE_TEXT)
	draw_circle(center, 13.0, BEZEL_INNER, true, -1.0, true)
	draw_arc(center, 13.0, 0.0, TAU, 32, Color(1, 1, 1, 0.12), 1.0, true)
	var along: Vector2 = Vector2.UP.rotated(deg_to_rad(_cam_degrees(cam, cam.position)))
	var across: Vector2 = Vector2(-along.y, along.x)
	# A black grip on the black plate would vanish: it is moulded lighter.
	var grip: Color = _lit_color(color if color.get_luminance() > 0.1 else Color("5c6167"), light)
	var points: PackedVector2Array = PackedVector2Array([
		center + along * 16.0 + across * 3.5, center + along * 16.0 - across * 3.5,
		center - along * 14.0 - across * 5.5, center - along * 14.0 + across * 5.5,
	])
	draw_colored_polygon(points, grip)
	points.append(points[0])
	draw_polyline(points, grip.lightened(0.25), 1.0, true)
	draw_line(center + along * 4.0, center + along * 14.0, Color(1, 1, 1, 0.9), 2.0, true)


## Angle of the handle (degrees from straight up, clockwise) in [param position].
static func _cam_degrees(cam: CamSwitch, position: int) -> float:
	if cam.positions == CamSwitch.Positions.CHANGEOVER:
		return [0.0, -50.0, 50.0][position]
	return 90.0 if position == CamSwitch.ONE else 0.0


## Signal lamp: a black collar, a translucent coloured rim and a domed lens
## with a little gloss; it glows while the lamp has power.
func _draw_lamp(center: Vector2, radius: float, color: Color, lit: bool) -> void:
	if lit:
		for k: int in 3:
			draw_circle(center, radius + 2.0 + 3.0 * k, Color(color, 0.2 - 0.06 * k), true, -1.0, true)
	draw_circle(center, radius, BEZEL, true, -1.0, true)
	var rim_r: float = radius * 0.88
	var lens_r: float = radius * 0.72
	var rim: Color = color.lightened(0.4) if lit else Color.from_hsv(color.h, color.s * 0.7, color.v * 0.7)
	var lens: Color = color.lightened(0.15) if lit else Color.from_hsv(color.h, color.s * 0.8, color.v * 0.5)
	draw_circle(center, rim_r, rim, true, -1.0, true)
	draw_circle(center, lens_r, lens, true, -1.0, true)
	draw_arc(center, lens_r, 0.0, TAU, 48, rim.darkened(0.25), 1.0, true)
	if lit:
		draw_circle(center, lens_r * 0.6, Color(1, 1, 1, 0.22), true, -1.0, true)
	# Slight diagonal lines across the lens, like the ribs of a moulded lens.
	var spacing: float = maxf(lens_r / 3.5, 2.5)
	var along: Vector2 = Vector2(1.0, -1.0).normalized()
	var across: Vector2 = Vector2(1.0, 1.0).normalized()
	var line_color: Color = Color(1, 1, 1, 0.1) if lit else Color(0, 0, 0, 0.14)
	var offset: float = -floorf(lens_r / spacing) * spacing
	while offset < lens_r:
		var half: float = sqrt(lens_r * lens_r - offset * offset) - 0.8
		if half > 0.5:
			var middle: Vector2 = center + across * offset
			draw_line(middle - along * half, middle + along * half, line_color, 1.0, true)
		offset += spacing
	# Some gloss: a soft sheen and a reflection on the rim, upper left.
	draw_circle(center + Vector2(-0.3, -0.3) * lens_r, lens_r * 0.42, Color(1, 1, 1, 0.12), true, -1.0, true)
	draw_circle(center + Vector2(-0.38, -0.38) * lens_r, lens_r * 0.15, Color(1, 1, 1, 0.45 if lit else 0.3), true, -1.0, true)
	draw_arc(center, (rim_r + lens_r) * 0.5, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.4 if lit else 0.25), maxf(1.0, (rim_r - lens_r) * 0.6), true)


func _screw(at: Vector2) -> void:
	draw_circle(at, 5.0, SCREW, true, -1.0, true)
	draw_arc(at, 5.0, 0.0, TAU, 24, SCREW_EDGE, 1.0, true)
	draw_line(at + Vector2(-2.6, 2.6), at + Vector2(2.6, -2.6), SCREW_EDGE, 1.4, true)


func _rounded(rect: Rect2, fill: Color, radius: int, edge: Color = Color.TRANSPARENT, edge_width: int = 1) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.draw_center = fill.a > 0.0
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	if edge.a > 0.0:
		style.border_color = edge
		style.set_border_width_all(edge_width)
	draw_style_box(style, rect)
