class_name StationInsideView
extends Control
## Draws the inside of a control station ([StationInside]) with its cover
## off, in millimetres (see [CabinetPainter]), as large as fits: the grey
## housing, the backs of the devices with their contact blocks (NO green,
## NC red, CO both, lamp blocks white) and their screw terminals with their
## numbers, each device's designation on a label, the cable glands in the top
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
	for entry: Dictionary in _inside.items:
		_device(p, entry)
	for wire: Dictionary in _inside.wires:
		CabinetParts.wire(p, wire["points"], wire["conductor"], StationInside.WIRE_W, wire["external"], Vector2.ZERO)
	for wire: Dictionary in _inside.wires:
		CabinetParts.wire_markers(p, wire["markers"], wire["mark"], StationInside.WIRE_W)
	for gland: Dictionary in _inside.glands:
		var g: Rect2 = gland["rect"]
		CabinetParts.cable_gland(p, g)
		CabinetParts.label(p, Vector2(g.get_center().x, g.position.y - 3.0), str(gland["cable"]), maxf(g.size.x, 10.0))


## The back of a device: its actuator's housing behind the adapter, the
## blocks on it with their terminals, its designation on a label under it.
func _device(p: CabinetPainter, entry: Dictionary) -> void:
	var center: Vector2 = entry["center"]
	if entry["cam"]:
		p.rect(Rect2(center - Vector2(24.0, 24.0), Vector2(48.0, 48.0)), BACK, 2.0)
	else:
		p.circle(center, 15.0, BACK)
	var blocks: Array = entry["blocks"]
	if not blocks.is_empty():
		var first: Rect2 = blocks[0]["rect"]
		var span: Rect2 = first
		for block: Dictionary in blocks:
			span = span.merge(block["rect"])
		# The mounting adapter the blocks clip on.
		p.rect(Rect2(span.position.x - 2.5, center.y - 5.0, span.size.x + 5.0, 10.0), ADAPTER, 1.0)
		for block: Dictionary in blocks:
			_block(p, block)
	elif not entry["designation"].is_empty():
		p.text_centered(center, "?", 6.0, CabinetParts.METAL)
	var designations: PackedStringArray = PackedStringArray()
	for designation: String in [entry["designation"], entry["lamp"]]:
		if not designation.is_empty():
			designations.append("-" + designation)
	if not designations.is_empty():
		# At the top left of its cell, clear of the wires going to the blocks.
		var cell: Rect2 = entry["rect"]
		var width: float = minf(cell.size.x * 0.5 - 4.0, 8.0 + 6.0 * designations.size())
		CabinetParts.label(p, cell.position + Vector2(width * 0.5 + 2.0, 4.0), " ".join(designations), width)


## A block: its body with a coloured band (NO green, NC red, a lamp block's
## lens), its screws ringed in the voltage reaching them and their numbers.
func _block(p: CabinetPainter, block: Dictionary) -> void:
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
			var lit: bool = _lamp_lit(block)
			if lit:
				p.circle(r.get_center(), 5.5, Color(1.0, 0.92, 0.55, 0.35))
			p.circle(r.get_center(), 3.2, Color("fff2b0") if lit else Color("d8d6c8"), BLOCK_EDGE, 0.2)
	for t: Dictionary in block["terminals"]:
		var at: Vector2 = t["at"]
		# The opening of its clamp in the face, the wire going in under the
		# screw, the clamp's plate showing inside.
		var entry: Vector2 = t["entry"]
		var opening: Rect2 = Rect2(entry.x - StationInside.OPENING.x * 0.5, entry.y if t["top"] else entry.y - StationInside.OPENING.y, StationInside.OPENING.x, StationInside.OPENING.y)
		p.rect(opening, BACK, 0.4)
		var plate_y: float = opening.end.y - 0.5 if t["top"] else opening.position.y + 0.5
		p.line(Vector2(opening.position.x + 0.4, plate_y), Vector2(opening.end.x - 0.4, plate_y), CabinetParts.METAL_DARK, 0.5)
		var color: Color = _reach_color(t["key"])
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
