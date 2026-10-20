class_name StationInsideView
extends Control
## Draws the inside of a control station ([StationInside]) with its cover
## off, in millimetres (see [CabinetPainter]), as large as fits: the grey
## housing, the backs of the devices with their contact blocks (NO green,
## NC red, CO both, lamp blocks white) and their screw terminals with their
## numbers, a potentiometer's round body with its lugs and fastons, each
## device's designation on a label, the cable glands in the top
## and the wires. While simulating the terminals are ringed in the colour of
## the voltage that reaches them and the lamp blocks light.

var document: SchematicDocument
## Index of the station drawn in [member SchematicDocument.control_boxes].
var box_index: int = 0
var simulating: bool = false
## Terminal key -> reach code of the last simulation step (see [StepResult]).
var reach: Dictionary[String, int] = {}

const SHELL := Color("3a3d41")
const INSIDE := Color("c9ccd0")
const BACK := Color("1c1d20")
const ADAPTER := Color("4a4e53")
const BLOCK_BODY := Color("e9eae6")
const BLOCK_EDGE := Color("9a9e9f")
const NO_BAND := Color("2ea44f")
const NC_BAND := Color("d63b3b")
const LAMP_BODY := Color("f4f4f0")
const PRINT := Color("26282b")
const POT_BODY := Color("6b6f74")
const POT_EDGE := Color("45484c")
const BRASS := Color("d7b46a")
const BRASS_DARK := Color("9c7c3a")
## Insulation of a faston for 0.5-1.5 mm² (red as sold).
const FASTON_SLEEVE := Color("c8393b")
## Pixels a wire number is written at least: below it the numbers on the
## sleeves are written beside them as well.
const NUMBER_PX: float = 7.0

var _inside: StationInside


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _get_minimum_size() -> Vector2:
	return Vector2(160.0, 200.0)


## Lays the inside out again (after edits or a new document).
func refresh() -> void:
	_inside = StationInside.build(document, box_index)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _k() -> float:
	if _inside == null or _inside.size.x <= 0.0:
		return 1.0
	return clampf(minf((size.x - 16.0) / _inside.size.x, (size.y - 16.0) / (_inside.size.y + 4.0)), 0.3, 12.0)


func _draw() -> void:
	if _inside == null or _inside.size.x <= 0.0:
		return
	var k: float = _k()
	var origin: Vector2 = ((size - _inside.size * k) * 0.5).floor() + Vector2(0.0, 2.0 * k)
	var p: CabinetPainter = CabinetPainter.new(self, k, origin)
	var r: Rect2 = Rect2(Vector2.ZERO, _inside.size)
	p.rect(r.grow(2.0), SHELL, 3.5)
	p.gradient(r, INSIDE.lightened(0.05), INSIDE.darkened(0.05), 2.0)
	for corner: Vector2 in [Vector2(4, 4), Vector2(r.end.x - 4, 4), Vector2(4, r.end.y - 4), r.end - Vector2(4, 4)]:
		p.circle(corner, 2.2, CabinetParts.METAL, CabinetParts.METAL_DARK, 0.2)
	paint(p, _inside, _reach_color, _lamp_lit)
	for gland: Dictionary in _inside.glands:
		var g: Rect2 = gland["rect"]
		CabinetParts.cable_gland(p, g)
		CabinetParts.label(p, Vector2(g.get_center().x, g.position.y - 3.0), str(gland["cable"]), maxf(g.size.x, 10.0))


## The devices and wires of [param inside] (also the back of a switchboard's
## door, see [CabinetView]): [param reach_color] gives a terminal key's
## voltage colour, [param lamp_lit] whether a lamp block's lamp is lit.
static func paint(p: CabinetPainter, inside: StationInside, reach_color: Callable, lamp_lit: Callable) -> void:
	for entry: Dictionary in inside.items:
		_device(p, entry, reach_color, lamp_lit)
	for wire: Dictionary in inside.wires:
		CabinetParts.wire(p, wire["points"], wire["conductor"], StationInside.WIRE_W, wire["external"], wire.get("pins", Vector2.ZERO))
	for wire: Dictionary in inside.wires:
		CabinetParts.wire_markers(p, wire["markers"], wire["mark"], StationInside.WIRE_W)
	# Drawn too small for the numbers on the sleeves to be read: each number
	# written beside its sleeve.
	if (StationInside.WIRE_W + CabinetParts.MARKER_GROW) * 0.82 * p.k < NUMBER_PX:
		for wire: Dictionary in inside.wires:
			for span: PackedVector2Array in wire["markers"]:
				_number_beside(p, span, wire["mark"])


## Wire number [param mark] on a little white tag beside sleeve
## [param span]: right of a sleeve running up and down, over one lying.
static func _number_beside(p: CabinetPainter, span: PackedVector2Array, mark: String) -> void:
	var size_mm: float = maxf(NUMBER_PX / p.k, 3.0)
	var middle: Vector2 = (span[0] + span[1]) * 0.5
	var tag: Vector2 = Vector2(mark.length() * size_mm * 0.62 + 1.2, size_mm + 1.0)
	var lying: bool = absf(span[1].x - span[0].x) >= absf(span[1].y - span[0].y)
	var center: Vector2 = middle + (Vector2(0.0, -tag.y * 0.5 - 2.0) if lying else Vector2(tag.x * 0.5 + 2.0, 0.0))
	p.rect(Rect2(center - tag * 0.5, tag), Color(1, 1, 1, 0.9), 0.4, Color(0, 0, 0, 0.3), 0.15)
	p.text_centered(center, mark, size_mm, PRINT)


## The back of a device: its actuator's housing behind the adapter, the
## blocks on it with their terminals, its designation on a label under it.
static func _device(p: CabinetPainter, entry: Dictionary, reach_color: Callable, lamp_lit: Callable) -> void:
	var center: Vector2 = entry["center"]
	var blocks: Array = entry["blocks"]
	if not blocks.is_empty() and blocks[0]["kind"] == "POT":
		_pot(p, center, blocks[0], reach_color)
		_device_label(p, entry)
		return
	if entry["cam"]:
		p.rect(Rect2(center - Vector2.ONE * StationInside.BACK_HALF, Vector2.ONE * 2.0 * StationInside.BACK_HALF), BACK, 2.0)
	else:
		p.circle(center, 15.0, BACK)
	if not blocks.is_empty():
		var first: Rect2 = blocks[0]["rect"]
		var span: Rect2 = first
		for block: Dictionary in blocks:
			span = span.merge(block["rect"])
		# The mounting adapter the blocks clip on.
		p.rect(Rect2(span.position.x - 2.5, center.y - 5.0, span.size.x + 5.0, 10.0), ADAPTER, 1.0)
		for block: Dictionary in blocks:
			_block(p, block, reach_color, lamp_lit)
	elif not entry["designation"].is_empty():
		p.text_centered(center, "?", 6.0, CabinetParts.METAL)
	_device_label(p, entry)


## The designations of item [param entry] on a label.
static func _device_label(p: CabinetPainter, entry: Dictionary) -> void:
	var center: Vector2 = entry["center"]
	var designations: PackedStringArray = PackedStringArray()
	for designation: String in [entry["designation"], entry["lamp"]]:
		if not designation.is_empty():
			designations.append("-" + designation)
	if not designations.is_empty():
		# At the top left of its cell (on a door left of the device, the
		# channel running over the cell), clear of the wires to the blocks.
		var cell: Rect2 = entry["rect"]
		var width: float = minf(cell.size.x * 0.5 - 4.0, 8.0 + 6.0 * designations.size())
		var at: Vector2 = cell.position + Vector2(width * 0.5 + 2.0, 4.0)
		if entry.get("door", false):
			at = center - Vector2(StationInside.BACK_HALF + width * 0.5 + 2.0, 0.0)
		CabinetParts.label(p, at, " ".join(designations), width)


## A potentiometer from behind: its round body with the shaft's nut, three
## brass solder lugs on top (ringed in the voltage reaching them) with their
## numbers on the body, and a red insulated faston pushed on each, the wire
## leaving its top.
static func _pot(p: CabinetPainter, center: Vector2, block: Dictionary, reach_color: Callable) -> void:
	for t: Dictionary in block["terminals"]:
		var at: Vector2 = t["at"]
		var color: Color = reach_color.call(t["key"])
		if color.a > 0.0:
			p.circle(at, 2.4, Color(1, 1, 1, 0.85))
			p.circle(at, 2.1, color)
		p.rect(Rect2(at.x - 1.2, center.y - StationInside.LUG_TOP, 2.4, StationInside.LUG_TOP - StationInside.POT_R + 3.0), BRASS, 0.3, BRASS_DARK, 0.15)
		p.circle(at, 0.55, BRASS_DARK)
		# The faston: its metal receptacle on the lug, the sleeve over it.
		var top: float = center.y - StationInside.LUG_TOP - StationInside.FASTON
		p.rect(Rect2(at.x - 1.5, top + StationInside.FASTON - 2.2, 3.0, 2.2), CabinetParts.METAL, 0.2, CabinetParts.METAL_DARK, 0.12)
		p.rect(Rect2(at.x - 1.7, top, 3.4, StationInside.FASTON - 2.0), FASTON_SLEEVE, 0.7, FASTON_SLEEVE.darkened(0.4), 0.15)
		p.line(Vector2(at.x - 0.9, top + 0.8), Vector2(at.x - 0.9, top + StationInside.FASTON - 2.8), FASTON_SLEEVE.lightened(0.35), 0.3)
	p.circle(center, StationInside.POT_R, POT_BODY, POT_EDGE, 0.3)
	p.ring(center, StationInside.POT_R * 0.78, POT_BODY.lightened(0.12), 0.25)
	p.circle(center, 3.4, CabinetParts.METAL, CabinetParts.METAL_DARK, 0.2)
	for t: Dictionary in block["terminals"]:
		p.text_centered(Vector2(t["at"].x, center.y - StationInside.LUG_Y + 6.5), t["name"], 2.4, Color(1, 1, 1, 0.85))


## A block: its body with a coloured band (NO green, NC red, a lamp block's
## lens), its screws ringed in the voltage reaching them and their numbers.
static func _block(p: CabinetPainter, block: Dictionary, reach_color: Callable, lamp_lit: Callable) -> void:
	var r: Rect2 = block["rect"]
	var kind: String = block["kind"]
	var lamp: bool = kind == "LAMP"
	p.rect(r.grow(-0.3), LAMP_BODY if lamp else (BACK.lightened(0.15) if kind == "POLE" else BLOCK_BODY), 0.8, BLOCK_EDGE, 0.2)
	var band: Rect2 = Rect2(r.position.x + 1.2, r.get_center().y - 3.0, r.size.x - 2.4, 6.0)
	match kind:
		"NO":
			p.rect(band, NO_BAND, 0.5)
		"NC":
			p.rect(band, NC_BAND, 0.5)
		"CO":
			p.rect(Rect2(band.position, Vector2(band.size.x * 0.5, band.size.y)), NC_BAND, 0.5)
			p.rect(Rect2(band.position + Vector2(band.size.x * 0.5, 0.0), Vector2(band.size.x * 0.5, band.size.y)), NO_BAND, 0.5)
		"LAMP":
			var lit: bool = lamp_lit.call(block)
			if lit:
				p.circle(r.get_center(), 5.5, Color(1.0, 0.92, 0.55, 0.35))
			p.circle(r.get_center(), 3.2, Color("fff2b0") if lit else Color("d8d6c8"), BLOCK_EDGE, 0.2)
	for t: Dictionary in block["terminals"]:
		var at: Vector2 = t["at"]
		var color: Color = reach_color.call(t["key"])
		if color.a > 0.0:
			p.circle(at, 2.6, Color(1, 1, 1, 0.85))
			p.circle(at, 2.3, color)
		p.circle(at, 1.9, CabinetParts.METAL, CabinetParts.METAL_DARK, 0.15)
		p.line(at + Vector2(-1.1, 0.0), at + Vector2(1.1, 0.0), CabinetParts.METAL_DARK, 0.35)
		p.line(at + Vector2(0.0, -1.1), at + Vector2(0.0, 1.1), CabinetParts.METAL_DARK, 0.35)
		var ink: Color = CabinetParts.METAL if kind == "POLE" else PRINT
		var y: float = at.y + (4.3 if t["top"] else -2.6)
		p.text(Vector2(at.x, y), t["name"], 2.4, ink, 0, true, r.size.x - 0.6)


## True while the lamp of lamp block [param block] has power.
func _lamp_lit(block: Dictionary) -> bool:
	if not simulating or document == null or block["terminals"].is_empty():
		return false
	var lamp: CircuitComponent = document.circuit.get_terminal_owner(block["terminals"][0]["key"])
	return lamp is Lamp and (lamp as Lamp).energized


## Colour of the voltage reaching terminal [param key]; transparent for none
## (and always while editing).
func _reach_color(key: String) -> Color:
	var code: int = reach.get(key, StepResult.REACH_NONE) if simulating else StepResult.REACH_NONE
	return Color.TRANSPARENT if code == StepResult.REACH_NONE else SchematicTheme.reach_color(code)
