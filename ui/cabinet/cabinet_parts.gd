class_name CabinetParts
extends RefCounted
## Parts of the switchboard (rozvaděč) drawn to their real sizes in
## millimetres with a [CabinetPainter]: DIN rails, wire ducts, terminal
## blocks, circuit breakers, fuse holders, contactors, overload relays,
## relays and time relays, after photos of real devices but without maker
## names. Each part is drawn with its top-left corner at the painter's
## origin; DIN-rail parts are centred on the rail.

## Height of a modular device (breaker, fuse holder, time relay).
const MODULE_H: float = 90.0
## Width of one module (one pole of a breaker).
const MODULE_W: float = 18.0
const CONTACTOR := Vector2(45.0, 77.0)
const OVERLOAD := Vector2(45.0, 52.0)
const TERMINAL := Vector2(5.2, 47.0)
const END_STOP_W: float = 9.0
const RAIL_H: float = 35.0

const HOLE := Color("1d1f22")
const METAL := Color("d3d7da")
const METAL_DARK := Color("868c92")
const PRINT := Color("34383d")
const LED_GREEN := Color("39d353")
const LED_RED := Color("ff4545")
const LED_YELLOW := Color("ffb000")
const LED_OFF := Color("4a4d50")
const TRIP := Color("ff8a1f")
const DIAL_BLUE := Color("2f6fd4")


# --- Common details -------------------------------------------------------------

static func led(p: CabinetPainter, center: Vector2, color: Color, lit: bool, radius: float = 1.1) -> void:
	if lit:
		for i: int in 3:
			p.circle(center, radius * (1.6 + 0.7 * i), Color(color, 0.22 - 0.06 * i))
	p.circle(center, radius, color if lit else LED_OFF, Color(0, 0, 0, 0.4), 0.15)
	if lit:
		p.circle(center + Vector2(-0.3, -0.3) * radius, radius * 0.4, Color(1, 1, 1, 0.7))


## White designation label ("-KM1") centred on [param center].
static func label(p: CabinetPainter, center: Vector2, text: String, width_mm: float = 16.0) -> void:
	p.rect(Rect2(center - Vector2(width_mm * 0.5, 2.6), Vector2(width_mm, 5.2)), Color("fbfbf8"), 0.5, Color(0, 0, 0, 0.35), 0.15)
	p.text_centered(center, text, 3.2, Color("111111"), true, width_mm - 1.0)


## An empty place [param size] mm big for a device the circuit no longer
## has: a dashed outline with its name.
static func missing(p: CabinetPainter, size: Vector2, text: String) -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	p.rect(r, Color(0, 0, 0, 0.06), 1.0)
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k: int in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var length: float = a.distance_to(b)
		var t: float = 0.0
		while t < length:
			p.line(a.lerp(b, t / length), a.lerp(b, minf(t + 2.0, length) / length), Color("8a9096"), 0.25)
			t += 4.0
	p.text_centered(r.get_center(), text, 3.0, Color("6b7177"), true, size.x - 1.0)


# --- DIN rail, ducts, plate -----------------------------------------------------

## TS35 rail [param length] mm long with its mounting slots.
static func din_rail(p: CabinetPainter, length: float) -> void:
	var steel: Color = Color("e4e8eb")
	p.gradient(Rect2(0, 0, length, RAIL_H), steel.lightened(0.3), steel.darkened(0.1), 0.0, METAL_DARK, 0.2)
	p.gradient(Rect2(0, 5.0, length, 25.0), steel, steel.darkened(0.06))
	p.line(Vector2(0, 5.0), Vector2(length, 5.0), METAL_DARK, 0.2)
	p.line(Vector2(0, 30.0), Vector2(length, 30.0), METAL_DARK, 0.2)
	p.line(Vector2(0, 0.6), Vector2(length, 0.6), Color(1, 1, 1, 0.6), 0.2)
	var x: float = 5.0
	while x + 15.0 <= length - 3.0:
		p.rect(Rect2(x, 14.9, 15.0, 5.2), Color(0, 0, 0, 0.55), 2.6)
		x += 25.0


## Fingers of the wire ducts: width, the slot between two, how far they
## reach in from the sides, room before the first one.
const DUCT_FINGER: float = 6.0
const DUCT_SLOT: float = 4.0
const DUCT_DEPTH: float = 8.0
const DUCT_END: float = 1.5


## Number of slots between the fingers of a duct [param length] mm long.
static func duct_slots(length: float) -> int:
	return maxi(floori((length - 2.0 * DUCT_END - DUCT_FINGER) / (DUCT_FINGER + DUCT_SLOT)), 1)


## Centre of slot [param index] of a duct, from the duct's start.
static func duct_slot(index: int) -> float:
	return DUCT_END + DUCT_FINGER + DUCT_SLOT * 0.5 + (DUCT_FINGER + DUCT_SLOT) * index


## Slotted wire duct without its cover: the fingers along both sides and
## the floor between them. [param vertical] runs it down instead of across.
static func duct(p: CabinetPainter, length: float, thickness: float, vertical: bool) -> void:
	var base: Color = Color("9ea4a9")
	var r: Rect2 = Rect2(0, 0, thickness, length) if vertical else Rect2(0, 0, length, thickness)
	p.rect(r, base.darkened(0.35), 0.4, base.darkened(0.45), 0.2)
	var finger: float = DUCT_FINGER
	var gap: float = DUCT_SLOT
	var depth: float = DUCT_DEPTH
	var along: float = DUCT_END
	while along + finger <= length - 1.5:
		for side: int in 2:
			var f: Rect2
			if vertical:
				f = Rect2(0.0 if side == 0 else thickness - depth, along, depth, finger)
			else:
				f = Rect2(along, 0.0 if side == 0 else thickness - depth, finger, depth)
			p.gradient(f, base.lightened(0.1), base, 0.3, base.darkened(0.25), 0.12)
		along += finger + gap
	# Floor of the duct between the fingers.
	var floor_r: Rect2 = Rect2(depth, 0, thickness - 2 * depth, length) if vertical else Rect2(0, depth, length, thickness - 2 * depth)
	p.rect(floor_r.grow(-0.5), base.darkened(0.2))


## The enclosure's frame with the white mounting plate inside it.
static func plate(p: CabinetPainter, size: Vector2) -> void:
	var frame: Color = Color("b3b8bc")
	p.rect(Rect2(Vector2.ZERO, size), frame, 3.0, frame.darkened(0.35), 0.3)
	var inner: Rect2 = Rect2(Vector2(6, 6), size - Vector2(12, 12))
	p.rect(inner.grow(1.0), frame.darkened(0.45), 1.5)
	var c: Color = Color("efece4")
	p.gradient(inner, c.lightened(0.06), c.darkened(0.04), 1.0)
	for corner: Vector2 in [inner.position + Vector2(5, 5), Vector2(inner.end.x - 5, inner.position.y + 5), Vector2(inner.position.x + 5, inner.end.y - 5), inner.end - Vector2(5, 5)]:
		p.circle(corner, 2.4, METAL, METAL_DARK, 0.2)
		p.circle(corner, 0.9, METAL_DARK)


# --- Modular devices ------------------------------------------------------------------------

## Light grey of the modular devices (housing, lever, fuse carrier).
const MODULAR_BODY := Color("e7e9ea")
const MODULAR_FACE := Color("f1f2f3")
const MODULAR_EDGE := Color("aeb3b8")
const MODULAR_SHADE := Color("d3d7da")
const MODULAR_END := Color("60666c")
const MODULAR_PRINT := Color("3e4247")


## Height of the terminal screws of a breaker from its top and bottom.
const BREAKER_SCREW_Y: float = 11.0
## Height of the wire openings of a fuse holder from its top and bottom.
const FUSE_HOLE_TOP: float = 8.0
const FUSE_HOLE_BOTTOM: float = 7.5


## Terminal screw of a modular device: a round recess with a combination screw.
static func _modular_screw(p: CabinetPainter, center: Vector2, reach: Color = Color.TRANSPARENT) -> void:
	if reach.a > 0.0:
		p.circle(center, 3.75, Color(1, 1, 1, 0.85))
		p.circle(center, 3.45, reach)
	p.circle(center, 3.1, Color("8f959a"))
	p.circle(center, 2.75, Color("6d7378"))
	p.circle(center, 2.3, METAL, METAL_DARK, 0.15)
	p.circle(center + Vector2(-0.7, -0.7), 0.9, Color(1, 1, 1, 0.4))
	p.line(center + Vector2(-1.3, 0), center + Vector2(1.3, 0), METAL_DARK, 0.4)
	p.line(center + Vector2(0, -1.3), center + Vector2(0, 1.3), METAL_DARK, 0.4)


## Deep round wire opening of a fuse holder (the screw far inside).
static func _fuse_hole(p: CabinetPainter, center: Vector2, reach: Color = Color.TRANSPARENT) -> void:
	if reach.a > 0.0:
		p.circle(center, 3.85, Color(1, 1, 1, 0.85))
		p.circle(center, 3.55, reach)
	p.circle(center, 3.2, Color("9a9fa4"))
	p.circle(center, 2.8, Color("26282b"))
	p.circle(center + Vector2(0.2, 0.3), 1.5, Color("3a3d41"))
	p.line(center + Vector2(-0.9, 0.3), center + Vector2(1.3, 0.3), Color("55595e"), 0.3)


# --- Circuit breaker --------------------------------------------------------------

## Miniature circuit breaker (jistič), 1 to 4 poles, one module per pole:
## light grey housing and lever, the lever's ribbed grip in a dark recess
## at the bottom of the front (up = on), red window while on, green while
## off. A trip drops it to off, as on a real one.
static func breaker(p: CabinetPainter, poles: int, on: bool, rating: String = "B10", reach: Array = []) -> void:
	var w: float = MODULE_W * poles
	var cap: float = 22.5
	p.rect(Rect2(0, 0, w, MODULE_H), MODULAR_SHADE, 0.8, MODULAR_EDGE, 0.2)
	p.gradient(Rect2(0.3, 2.2, w - 0.6, cap - 2.2), MODULAR_BODY, MODULAR_SHADE)
	p.gradient(Rect2(0.3, cap + 45.0, w - 0.6, MODULE_H - cap - 47.2), MODULAR_SHADE, MODULAR_BODY)
	p.rect(Rect2(0, 0, w, 2.2), MODULAR_END, 0.6)
	p.rect(Rect2(0, MODULE_H - 2.2, w, 2.2), MODULAR_END, 0.6)
	# Raised front: a soft shadow under it, the face lit from above.
	p.rect(Rect2(0.2, cap + 45.0, w - 0.4, 0.8), Color(0, 0, 0, 0.12))
	p.gradient(Rect2(0.2, cap, w - 0.4, 45.0), MODULAR_FACE.lightened(0.3), MODULAR_FACE, 0.6, MODULAR_EDGE, 0.15)
	for i: int in poles:
		var x0: float = MODULE_W * i
		var cx: float = x0 + MODULE_W * 0.5
		_modular_screw(p, Vector2(cx, BREAKER_SCREW_Y), reach[2 * i] if 2 * i < reach.size() else Color.TRANSPARENT)
		_modular_screw(p, Vector2(cx, MODULE_H - BREAKER_SCREW_Y), reach[2 * i + 1] if 2 * i + 1 < reach.size() else Color.TRANSPARENT)
		p.text(Vector2(cx + 5.2, 17.0), str(2 * i + 1), 2.5, MODULAR_PRINT, -1, false)
		p.text(Vector2(cx + 5.2, MODULE_H - 15.0), str(2 * i + 2), 2.5, MODULAR_PRINT, -1, false)
		# Slot for a busbar under the top terminal.
		p.rect(Rect2(x0 + 4.0, 18.4, 6.5, 2.4), Color("c3c7cb"), 0.3, Color("9ba1a6"), 0.12)
		if i > 0:
			p.line(Vector2(x0, cap + 0.3), Vector2(x0, cap + 26.0), MODULAR_EDGE, 0.0)
		# Contact position window.
		var window: Color = Color("d3222b") if on else Color("2e9e48")
		p.rect(Rect2(x0 + 7.6, cap + 22.3, 4.7, 2.5), Color("8d9296"), 0.2)
		p.rect(Rect2(x0 + 7.9, cap + 22.6, 4.1, 1.9), window)
	# Printing on the first pole (rating, symbol, data), the I / O marks on the last.
	var c: Vector2 = Vector2(1.2, cap)
	p.text(c + Vector2(0, 16.4), rating, 4.2, MODULAR_PRINT, -1, true, 9.0)
	# Small switch symbol 1-2.
	var sx: float = c.x + 11.6
	p.line(Vector2(sx, cap + 11.0), Vector2(sx, cap + 12.6), MODULAR_PRINT, 0.15)
	p.line(Vector2(sx, cap + 14.4), Vector2(sx - 0.9, cap + 12.6), MODULAR_PRINT, 0.15)
	p.line(Vector2(sx, cap + 14.4), Vector2(sx, cap + 16.0), MODULAR_PRINT, 0.15)
	p.text(Vector2(sx + 0.9, cap + 11.8), "1", 1.1, MODULAR_PRINT, -1, false)
	p.text(Vector2(sx + 0.9, cap + 16.2), "2", 1.1, MODULAR_PRINT, -1, false)
	p.text(c + Vector2(0, 20.9), "~230/400V", 1.35, MODULAR_PRINT, -1, false)
	p.rect(Rect2(c + Vector2(0, 21.7), Vector2(5.2, 1.9)), Color.TRANSPARENT, 0.0, MODULAR_PRINT, 0.1)
	p.text_centered(c + Vector2(2.6, 22.65), "10000", 1.15, MODULAR_PRINT, false)
	p.rect(Rect2(c + Vector2(1.8, 23.6), Vector2(1.6, 1.9)), Color.TRANSPARENT, 0.0, MODULAR_PRINT, 0.1)
	p.text_centered(c + Vector2(2.6, 24.55), "3", 1.15, MODULAR_PRINT, false)
	var ix: float = w - 2.4
	p.text(Vector2(ix, cap + 19.9), "I", 1.7, MODULAR_PRINT)
	p.line(Vector2(ix, cap + 20.5), Vector2(ix, cap + 23.4), MODULAR_PRINT, 0.15)
	p.polygon(PackedVector2Array([Vector2(ix - 0.5, cap + 22.9), Vector2(ix + 0.5, cap + 22.9), Vector2(ix, cap + 23.7)]), MODULAR_PRINT)
	p.text(Vector2(ix, cap + 25.6), "O", 1.7, MODULAR_PRINT)
	# Lever: a dark recess, the lever body from its pivot, the ribbed grip.
	var recess: Rect2 = Rect2(0.5, cap + 26.4, w - 1.0, 18.0)
	p.gradient(recess, Color("6f767c"), Color("a3a9ae"), 1.4, Color("5d6369"), 0.15)
	var pivot: float = cap + 35.4
	var grip_y: float = cap + 26.9 if on else cap + 40.0
	var grip_h: float = 4.2
	var body_top: float = minf(grip_y + grip_h - 0.4, pivot)
	var body_bottom: float = maxf(grip_y + 0.4, pivot)
	for i: int in poles:
		var cx: float = MODULE_W * (i + 0.5)
		var body: Rect2 = Rect2(cx - 5.4, body_top, 10.8, body_bottom - body_top)
		p.rect(body.grow(0.3), Color(0, 0, 0, 0.3), 0.8)
		p.hgradient(Rect2(body.position.x, body.position.y, body.size.x * 0.5, body.size.y), Color("c4c9cd"), Color("f4f5f6"), 0.6)
		p.hgradient(Rect2(cx, body.position.y, body.size.x * 0.5, body.size.y), Color("f4f5f6"), Color("b9bec3"), 0.6)
		p.rect(body, Color.TRANSPARENT, 0.6, Color("8a9096"), 0.15)
	var grip: Rect2 = Rect2(0.8, grip_y, w - 1.6, grip_h)
	# Shadow on the side away from the pivot, then the grip with a dark edge.
	p.rect(Rect2(grip.position.x, grip.position.y + (0.7 if on else -0.7), grip.size.x, grip.size.y), Color(0, 0, 0, 0.35), 0.8)
	p.gradient(grip, Color("fbfbfc"), Color("d2d6d9"), 0.7, Color("6d7378"), 0.2)
	for r: int in 4:
		var ry: float = grip_y + 0.9 + r * 0.8
		p.line(Vector2(grip.position.x + 0.9, ry), Vector2(grip.end.x - 0.9, ry), Color(0, 0, 0, 0.3), 0.14)


# --- Fuse holder -------------------------------------------------------------------

## Height of a fuse holder (shorter than a breaker).
const FUSE_H: float = 82.0


## Fuse holder (pojistkový odpínač), [param poles] modules wide,
## [constant FUSE_H] high, centred like the other modular devices: a white
## carrier with a ledge at the top that swings down about its bottom to
## open. A blown fuse lights the LED in the slot under the ledge.
static func fuse_holder(p: CabinetPainter, poles: int, closed: bool, blown: bool, reach: Array = []) -> void:
	var w: float = MODULE_W * poles
	var top: float = (MODULE_H - FUSE_H) * 0.5
	var q: CabinetPainter = p.shifted(Vector2(0, top))
	q.rect(Rect2(0, 0, w, FUSE_H), MODULAR_SHADE, 0.8, MODULAR_EDGE, 0.2)
	q.gradient(Rect2(0.3, 0.3, w - 0.6, 20.0), MODULAR_FACE, MODULAR_BODY)
	q.gradient(Rect2(0.3, 66.0, w - 0.6, FUSE_H - 66.3), MODULAR_BODY, MODULAR_SHADE)
	for i: int in poles:
		var x0: float = MODULE_W * i
		var cx: float = x0 + MODULE_W * 0.5
		_fuse_hole(q, Vector2(cx, FUSE_HOLE_TOP), reach[2 * i] if 2 * i < reach.size() else Color.TRANSPARENT)
		_fuse_hole(q, Vector2(cx, FUSE_H - FUSE_HOLE_BOTTOM), reach[2 * i + 1] if 2 * i + 1 < reach.size() else Color.TRANSPARENT)
		if closed:
			_fuse_carrier(q, x0, i, poles, blown)
		else:
			_fuse_carrier_open(q, x0, blown)


## Closed carrier of pole [param pole]: the ledge, the slot with the LED,
## the printing (fuse size on the first pole, the fuse symbols of all
## poles on the second of three).
static func _fuse_carrier(p: CabinetPainter, x0: float, pole: int, poles: int, blown: bool) -> void:
	var cx: float = x0 + MODULE_W * 0.5
	var face: Rect2 = Rect2(x0 + 0.6, 24.0, MODULE_W - 1.2, 43.0)
	p.gradient(face, MODULAR_FACE.lightened(0.3), MODULAR_FACE, 1.6, MODULAR_EDGE, 0.15)
	# Rounded bottom edge where the carrier turns about its hinge.
	p.rect(Rect2(face.position.x + 0.6, face.end.y - 1.4, face.size.x - 1.2, 1.0), Color(0, 0, 0, 0.08), 0.5)
	# Ledge across the top: lit top face, shadow under it.
	p.rect(Rect2(x0 + 0.3, 26.6, MODULE_W - 0.6, 1.4), Color(0, 0, 0, 0.16), 0.4)
	p.gradient(Rect2(x0 + 0.3, 21.2, MODULE_W - 0.6, 5.6), Color("fbfbfc"), Color("dfe2e4"), 0.8, MODULAR_EDGE, 0.15)
	# Slot: dark, red while the LED shows a blown fuse.
	var slot: Rect2 = Rect2(cx - 1.1, 29.0, 2.2, 6.2)
	p.rect(slot, Color("2b2e31"), 0.3)
	if blown:
		for k: int in 3:
			p.rect(slot.grow(0.5 + 0.7 * k), Color(1.0, 0.25, 0.2, 0.2 - 0.05 * k), 0.8 + 0.7 * k)
		p.rect(slot.grow(-0.3), LED_RED, 0.3)
	var three: bool = poles == 3
	if not three or pole == 0:
		_fuse_symbol(p, Vector2(x0 + 4.0, 31.0), "1" if not three else "1", "2")
		# Switch-disconnector symbol on the right.
		var sx: float = x0 + 14.2
		p.line(Vector2(sx, 30.0), Vector2(sx, 31.2), MODULAR_PRINT, 0.15)
		p.line(Vector2(sx, 33.0), Vector2(sx - 0.9, 31.4), MODULAR_PRINT, 0.15)
		p.line(Vector2(sx, 33.0), Vector2(sx, 34.4), MODULAR_PRINT, 0.15)
		p.circle(Vector2(sx, 33.0), 0.25, MODULAR_PRINT)
	if pole == 0:
		p.text(Vector2(cx, 50.6), "10x38", 2.4, MODULAR_PRINT, 0, true, MODULE_W - 3.0)
		p.text(Vector2(cx, 54.4), "400V", 1.8, MODULAR_PRINT, 0, false)
	elif three and pole == 1:
		for k: int in 3:
			_fuse_symbol(p, Vector2(x0 + 4.6 + k * 4.4, 37.5), str(2 * k + 1), str(2 * k + 2))


## Fuse symbol (a box with the line through it) with its terminal numbers.
static func _fuse_symbol(p: CabinetPainter, at: Vector2, top: String, bottom: String) -> void:
	p.text(at + Vector2(0, -0.2), top, 1.2, MODULAR_PRINT, 0, false)
	p.line(at + Vector2(0, 0.3), at + Vector2(0, 6.3), MODULAR_PRINT, 0.15)
	p.rect(Rect2(at + Vector2(-0.7, 1.8), Vector2(1.4, 3.0)), Color.TRANSPARENT, 0.0, MODULAR_PRINT, 0.12)
	p.text(at + Vector2(0, 7.9), bottom, 1.2, MODULAR_PRINT, 0, false)


## Opened carrier: swung down about its bottom, so the empty socket shows
## above it, then the carrier's top with the fuse cartridge in it and its
## front, foreshortened.
static func _fuse_carrier_open(p: CabinetPainter, x0: float, blown: bool) -> void:
	var cx: float = x0 + MODULE_W * 0.5
	var inner: float = MODULE_W - 1.2
	p.rect(Rect2(x0 + 0.6, 21.0, inner, 25.0), Color("2d3033"), 0.8)
	p.rect(Rect2(cx - 3.0, 22.4, 6.0, 2.0), METAL_DARK, 0.4)
	# Top of the carrier, lit, with the cartridge's end cap.
	p.gradient(Rect2(x0 + 0.6, 45.0, inner, 9.0), Color("fbfbfc"), Color("dcdfe2"), 1.0, MODULAR_EDGE, 0.15)
	p.rect(Rect2(cx - 4.4, 46.2, 8.8, 6.6), Color("f4f1e8"), 2.0, Color(0, 0, 0, 0.3), 0.15)
	p.circle(Vector2(cx, 49.5), 2.6, METAL, METAL_DARK, 0.15)
	if blown:
		p.circle(Vector2(cx, 49.5), 1.2, LED_RED)
	p.gradient(Rect2(x0 + 0.6, 54.0, inner, 13.0), MODULAR_FACE.lightened(0.2), MODULAR_SHADE, 1.0, MODULAR_EDGE, 0.15)
	p.rect(Rect2(x0 + 0.3, 63.5, MODULE_W - 0.6, 3.2), Color("e6e8ea"), 0.8, MODULAR_EDGE, 0.15)


# --- Contactor, relay, overload relay -------------------------------------------

const BLOCK_BODY := Color("4b4f54")
const BLOCK_DARK := Color("404348")
const BLOCK_LIGHT := Color("53575d")
const BLOCK_RECESS := Color("2a2c2f")
const BLOCK_TEAL := Color("5fb8ac")
const BLOCK_WHITE := Color("e2e4e6")
## Screw columns of a contactor: power terminals of three or four poles,
## the inner tiers (two auxiliary contacts and the coil), the auxiliary
## contact block on the front.
const CONTACTOR_POWER_X: Array[float] = [11.2, 23.1, 35.0]
const CONTACTOR_POWER_X4: Array[float] = [9.4, 18.6, 27.8, 37.0]
const CONTACTOR_INNER_X: Array[float] = [16.8, 26.9, 37.8]
const AUX_BLOCK_X: Array[float] = [7.6, 17.9, 28.2, 38.5]
## Heights across a contactor clear of its screws and markings, under the
## auxiliary contact block, the inner bottom tier and the power outputs:
## wires from its bottom terminals run out to the side there when an
## overload relay sits under it.
const CONTACTOR_OUT_Y: Array[float] = [54.7, 66.2, 75.2]
## Screw columns of an overload relay: power outputs, auxiliary contacts
## 97 98 95 96.
const OVERLOAD_OUT_X: Array[float] = [12.0, 25.0, 37.6]
const OVERLOAD_AUX_X: Array[float] = [6.2, 17.7, 28.7, 39.7]
const OVERLOAD_AUX: PackedStringArray = ["97", "98", "95", "96"]


## Screw of a contactor or overload relay: a dark round well with a silver
## combination screw; [param reach] rings the well.
static func _block_screw(p: CabinetPainter, center: Vector2, radius: float, reach: Color = Color.TRANSPARENT, empty: bool = false) -> void:
	if reach.a > 0.0:
		p.circle(center, radius + 1.25, Color(1, 1, 1, 0.85))
		p.circle(center, radius + 0.95, reach)
	p.circle(center, radius + 0.55, Color("1c1d20"))
	if empty:
		p.circle(center + Vector2(0.3, 0.4), radius * 0.6, Color("111214"))
		return
	p.circle(center, radius, Color("c3c8cc"), Color("7d8389"), 0.15)
	p.circle(center + Vector2(-0.35, -0.35) * radius, radius * 0.45, Color(1, 1, 1, 0.35))
	var s: float = radius * 0.62
	p.line(center + Vector2(-s, 0), center + Vector2(s, 0), Color("5d6369"), radius * 0.2)
	p.line(center + Vector2(0, -s), center + Vector2(0, s), Color("5d6369"), radius * 0.2)
	var d: float = s * 0.55
	p.line(center + Vector2(-d, -d), center + Vector2(d, d), Color("7d8389"), radius * 0.1)


## Power terminal name as printed in teal: the big digit and the small
## conductor name after it ("1" "L1"), ending left of [param right].
static func _power_label(p: CabinetPainter, at: Vector2, digit: String, name: String, small: bool = false) -> void:
	p.text(at, digit, 2.3 if small else 2.8, BLOCK_TEAL, -1, false)
	p.text(at + Vector2(1.6 if small else 1.9, -0.1), name, 1.4 if small else 1.7, BLOCK_TEAL, -1, false)


## Contactor (stykač) 45 x 77 mm drawn after the photographed one: an
## anthracite housing with two tiers of terminals at each end (power
## terminals with teal names outside, coil and auxiliary contacts inside),
## the window with the contact carrier in the middle (dark while the coil
## holds it, light while it is dropped out), the label holder under it. [param poles]: 3 main
## poles (also for 1 or 2: the unused ones stay free, as on a real one) or
## 4. [param aux] names the auxiliary contacts ([top number, kind, bottom
## number]): the first two are built in, up to four more sit in an
## auxiliary contact block clipped onto the front. [param highlight] glows
## round the window while the coil has power. [param reach]: terminal name
## -> colour of voltage reach.
static func contactor(p: CabinetPainter, on: bool, highlight: bool = false, aux: Array = [["13", "NO", "14"], ["21", "NC", "22"]], reach: Dictionary = {}, poles: int = 3) -> void:
	var w: float = CONTACTOR.x
	var h: float = CONTACTOR.y
	var four: bool = poles >= 4
	var power_x: Array[float] = CONTACTOR_POWER_X4 if four else CONTACTOR_POWER_X
	# Outer tiers with the power terminals; the inner tiers cover half of
	# the top wells.
	p.rect(Rect2(3.0, 0, w - 6.0, 6.5), BLOCK_DARK, 0.8, Color("2e3034"), 0.15)
	p.rect(Rect2(3.0, h - 11.5, w - 6.0, 11.5), BLOCK_DARK, 0.8, Color("2e3034"), 0.15)
	var n: int = power_x.size()
	var radius: float = 2.1 if four else 2.3
	for j: int in n:
		_block_screw(p, Vector2(power_x[j], 5.6), radius, reach.get(str(2 * j + 1), Color.TRANSPARENT))
	p.gradient(Rect2(0, 5.1, w, h - 16.6), BLOCK_LIGHT, BLOCK_BODY, 1.0, Color("2e3034"), 0.15)
	var shift: float = 6.3 if four else 7.4
	for j: int in n:
		_power_label(p, Vector2(power_x[j] - shift, 3.6), str(2 * j + 1), "L" + str(j + 1), four)
		_block_screw(p, Vector2(power_x[j] + 0.6, h - 6.9), radius + 0.1, reach.get(str(2 * j + 2), Color.TRANSPARENT))
		_power_label(p, Vector2(power_x[j] + 0.4 - shift, h - 1.6), str(2 * j + 2), "T" + str(j + 1), four)
	# Inner tiers: auxiliary contacts and the coil.
	var inner_x: Array[float] = CONTACTOR_INNER_X
	var top_names: Array = [aux[0][0], aux[1][0], "A1"]
	var bottom_names: Array = [aux[0][2], aux[1][2], "A2"]
	for j: int in 3:
		_block_screw(p, Vector2(inner_x[j], 12.7), 2.6, reach.get(top_names[j], Color.TRANSPARENT))
		_block_screw(p, Vector2(inner_x[j] + 0.8, 58.8), 2.6, reach.get(bottom_names[j], Color.TRANSPARENT))
	for k: int in 2:
		var lx: float = inner_x[k]
		p.text(Vector2(lx - 2.9, 8.5), aux[k][0], 1.9, BLOCK_WHITE)
		p.text(Vector2(lx + 3.6, 8.5), aux[k][1], 1.9, BLOCK_WHITE)
		p.text(Vector2(lx - 2.3, 64.6), aux[k][2], 1.9, BLOCK_WHITE)
		p.text(Vector2(lx + 4.0, 64.6), aux[k][1], 1.9, BLOCK_WHITE)
	p.text(Vector2(40.6, 8.5), "A1", 1.9, BLOCK_WHITE)
	p.text(Vector2(42.2, 64.6), "A2", 1.9, BLOCK_WHITE)
	p.line(Vector2(0.4, 17.3), Vector2(w - 0.4, 17.3), Color("36393d"), 0.2)
	p.line(Vector2(0.4, 53.2), Vector2(w - 0.4, 53.2), Color("36393d"), 0.2)
	# Left: a slot for accessories; the QR sticker below.
	p.rect(Rect2(2.9, 30.4, 7.6, 9.6), BLOCK_RECESS, 0.4)
	p.rect(Rect2(6.4, 30.8, 0.9, 8.8), Color("5a5e63"))
	_qr(p, Rect2(1.7, 54.0, 9.4, 10.8))
	# Middle: the raised front with the window and the label holder.
	var front: Rect2 = Rect2(11.6, 17.5, 22.2, 35.5)
	p.gradient(front, BLOCK_LIGHT.lightened(0.05), BLOCK_BODY, 0.6, Color("34373b"), 0.2)
	var window: Rect2 = Rect2(12.4, 27.2, 20.6, 13.2)
	if highlight and on:
		for i: int in 3:
			p.rect(window.grow(1.0 + i), Color(1.0, 0.55, 0.25, 0.25 - 0.07 * i), 1.0 + i)
	p.rect(Rect2(17.6, 18.0, 10.2, 9.6), Color("383b3f"), 0.4)
	p.rect(window, Color("221e1c"), 0.5)
	# The contact carrier: an H centred in the window, dark while pulled in,
	# light while dropped out; a light edge keeps the dark one visible.
	var carrier: Color = _carrier_color(on)
	var edge: Color = carrier.lightened(0.3)
	p.rect(Rect2(18.6, 19.0, 8.2, 8.0), carrier, 0.4, edge, 0.15)
	p.rect(Rect2(15.2, 28.4, 4.8, 10.6), carrier, 0.4, edge, 0.15)
	p.rect(Rect2(25.4, 28.4, 4.8, 10.6), carrier, 0.4, edge, 0.15)
	p.rect(Rect2(20.0, 31.4, 5.4, 2.4), carrier.lightened(0.08), 0.2)
	p.rect(Rect2(22.0, 28.0, 1.4, 11.0), carrier.lightened(0.12), 0.2)
	p.rect(Rect2(12.9, 42.0, 19.6, 9.2), BLOCK_LIGHT.lightened(0.04), 0.5, Color("383b3f"), 0.2)
	# Right: the auxiliary contact symbol and a second slot.
	var sx: Vector2 = Vector2(37.0, 19.4)
	p.text(sx + Vector2(0, 0.8), aux[0][0], 1.1, BLOCK_WHITE, 0, false)
	p.text(sx + Vector2(4.4, 0.8), aux[1][0], 1.1, BLOCK_WHITE, 0, false)
	p.text(sx + Vector2(0, 2.0), aux[0][1], 1.0, BLOCK_WHITE, 0, false)
	p.text(sx + Vector2(4.4, 2.0), aux[1][1], 1.0, BLOCK_WHITE, 0, false)
	p.line(sx + Vector2(0, 2.6), sx + Vector2(0, 7.6), BLOCK_WHITE, 0.12)
	p.line(sx + Vector2(4.4, 2.6), sx + Vector2(4.4, 7.6), BLOCK_WHITE, 0.12)
	p.line(sx + Vector2(-0.7, 4.6), sx + Vector2(4.4, 5.6), BLOCK_WHITE, 0.12)
	p.text(sx + Vector2(0, 9.0), aux[0][2], 1.1, BLOCK_WHITE, 0, false)
	p.text(sx + Vector2(4.4, 9.0), aux[1][2], 1.1, BLOCK_WHITE, 0, false)
	p.rect(Rect2(34.0, 30.4, 8.0, 9.2), BLOCK_RECESS, 0.4)
	p.rect(Rect2(34.3, 30.8, 2.6, 8.4), Color("8c9094"), 0.2)
	if aux.size() > 2:
		_aux_block(p, on, highlight, aux.slice(2, 6), reach)


## Where the designation label of a contactor goes: on its label holder, or
## on the auxiliary contact block when it has one.
static func contactor_label_at(aux_count: int) -> Vector2:
	return Vector2(22.7, 38.4) if aux_count > 2 else Vector2(22.7, 46.6)


## Auxiliary contact block clipped onto the front of a contactor: up to four
## contacts, numbers at the top and bottom screws, a window with its slider
## (it moves with the contactor) and room for the label.
static func _aux_block(p: CabinetPainter, on: bool, highlight: bool, aux: Array, reach: Dictionary) -> void:
	var r: Rect2 = Rect2(1.2, 16.4, CONTACTOR.x - 2.4, 37.4)
	p.rect(r.grow(0.4), Color(0, 0, 0, 0.35), 1.2)
	p.gradient(r, BLOCK_LIGHT.lightened(0.08), BLOCK_BODY.lightened(0.02), 1.0, Color("2b2d31"), 0.2)
	var xs: Array[float] = AUX_BLOCK_X
	for k: int in aux.size():
		var c: Array = aux[k]
		_block_screw(p, Vector2(xs[k], 22.4), 2.3, reach.get(c[0], Color.TRANSPARENT))
		_block_screw(p, Vector2(xs[k], 48.0), 2.3, reach.get(c[2], Color.TRANSPARENT))
		p.text(Vector2(xs[k], 28.0), str(c[0]) + " " + str(c[1]), 1.6, BLOCK_WHITE, 0, true, 9.4)
		p.text(Vector2(xs[k], 44.0), str(c[2]) + " " + str(c[1]), 1.6, BLOCK_WHITE, 0, true, 9.4)
	var window: Rect2 = Rect2(17.0, 29.4, 11.4, 4.6)
	if highlight and on:
		for i: int in 3:
			p.rect(window.grow(1.0 + i), Color(1.0, 0.55, 0.25, 0.25 - 0.07 * i), 1.0 + i)
	p.rect(window, Color("221e1c"), 0.4)
	var slider: Color = _carrier_color(on)
	p.rect(Rect2(window.get_center().x - 2.5, window.position.y + 0.8, 5.0, 3.0), slider, 0.3, slider.lightened(0.3), 0.15)
	p.rect(Rect2(12.9, 35.0, 19.6, 7.0), BLOCK_LIGHT.lightened(0.04), 0.5, Color("383b3f"), 0.2)


## Colour of a contactor's contact carrier: dark while pulled in, light
## while dropped out.
static func _carrier_color(on: bool) -> Color:
	return Color("2a2320") if on else Color("74665c")


## Simplified QR code sticker (the same pattern every time).
static func _qr(p: CabinetPainter, r: Rect2) -> void:
	p.rect(r, Color("f4f4f2"), 0.3)
	var n: int = 15
	var cell: float = minf(r.size.x, r.size.y - 1.0) / (n + 2)
	var o: Vector2 = r.position + Vector2((r.size.x - cell * n) * 0.5, (r.size.y - cell * n) * 0.5)
	var seed: int = 12345
	for y: int in n:
		for x: int in n:
			var corner: bool = (x < 4 and y < 4) or (x >= n - 4 and y < 4) or (x < 4 and y >= n - 4)
			var on: bool
			if corner:
				var fx: int = x if x < 4 else x - (n - 4)
				var fy: int = y if y < 4 else y - (n - 4)
				on = fx == 0 or fy == 0 or fx == 3 or fy == 3 or (fx == 1 or fx == 2) and (fy == 1 or fy == 2)
				on = on and not (fx == 3 or fy == 3) if (x >= n - 4 or y >= n - 4) else on
			else:
				seed = (seed * 1103515245 + 12345) & 0x7fffffff
				on = (seed >> 16) % 2 == 0
			if on:
				p.rect(Rect2(o + Vector2(x, y) * cell, Vector2(cell, cell)), Color("1a1a1a"))


## Thermal overload relay (tepelné relé) 45 x 52 mm drawn after the
## photographed one, fitted under its contactor: the current dial, the TEST
## slider with the trip window (orange after a trip), the H / A reset
## selector, the blue reset and red stop tabs in a dark recess, the 95-98
## auxiliary terminals and the power terminals 2/T1 4/T2 6/T3 below.
## A trip pushes the blue reset tab out.
static func overload_relay(p: CabinetPainter, tripped: bool, setting: String = "5", reach: Dictionary = {}) -> void:
	var w: float = OVERLOAD.x
	var h: float = OVERLOAD.y
	var holes_x: Array[float] = OVERLOAD_OUT_X
	p.rect(Rect2(3.6, h - 9.6, w - 7.2, 9.6), BLOCK_DARK, 0.8, Color("2e3034"), 0.15)
	var out: PackedStringArray = ["2", "4", "6"]
	for j: int in 3:
		_block_screw(p, Vector2(holes_x[j], h - 9.4), 2.3, reach.get(out[j], Color.TRANSPARENT), true)
	p.gradient(Rect2(0, 0, w, h - 9.6), BLOCK_LIGHT, BLOCK_BODY, 0.8, Color("2e3034"), 0.15)
	for j: int in 3:
		_power_label(p, Vector2(holes_x[j] - 7.4, h - 2.4), out[j], "T" + str(j + 1))
	p.text(Vector2(9.0, 5.4), "70 23 04   17:48 E2 1", 1.15, Color(BLOCK_WHITE, 0.7), -1, false)
	# Front: dial, TEST slider, H / A selector.
	p.rect(Rect2(0.8, 7.0, 27.0, 24.4), Color.TRANSPARENT, 0.6, Color("383b3f"), 0.15)
	var dial: Vector2 = Vector2(9.1, 25.0)
	for t: int in 5:
		var a: float = lerpf(PI * 1.05, PI * 1.95, t / 4.0)
		p.line(dial + Vector2(cos(a), sin(a)) * 4.1, dial + Vector2(cos(a), sin(a)) * 4.9, BLOCK_WHITE, 0.15)
	p.circle(dial, 3.4, Color("2f3236"), Color("1f2124"), 0.2)
	p.line(dial + Vector2(-2.2, 0), dial + Vector2(2.2, 0), Color("6b7075"), 0.6)
	p.line(dial + Vector2(0, -2.2), dial + Vector2(0, 2.2), Color("6b7075"), 0.6)
	p.polygon(PackedVector2Array([dial + Vector2(2.6, -0.8), dial + Vector2(2.6, 0.8), dial + Vector2(4.0, 0.0)]), BLOCK_WHITE)
	p.text(dial + Vector2(-5.4, 1.1), "4", 1.8, BLOCK_WHITE)
	p.text(dial + Vector2(-1.0, -4.8), setting, 1.8, BLOCK_WHITE)
	p.text(dial + Vector2(5.3, -2.4), "6", 1.8, BLOCK_WHITE)
	p.rect(Rect2(13.9, 14.2, 1.9, 1.8), Color("1d1e21"), 0.3)
	p.text(Vector2(21.8, 9.6), "TEST", 1.9, BLOCK_WHITE, 0, false)
	p.line(Vector2(19.8, 10.7), Vector2(24.6, 10.7), BLOCK_WHITE, 0.15)
	p.polygon(PackedVector2Array([Vector2(19.4, 10.7), Vector2(20.4, 10.2), Vector2(20.4, 11.2)]), BLOCK_WHITE)
	p.rect(Rect2(19.1, 13.1, 5.4, 5.6), Color("222427"), 0.4)
	p.rect(Rect2(19.8, 13.8, 4.0, 4.2), TRIP if tripped else Color("34373b"), 0.3)
	p.text(Vector2(18.0, 18.6), "O", 1.6, BLOCK_WHITE, 0, false)
	p.text(Vector2(25.6, 18.6), "I", 1.6, BLOCK_WHITE, 0, false)
	p.text(Vector2(21.8, 21.8), "H", 2.0, BLOCK_WHITE, 0, false)
	p.rect(Rect2(19.8, 23.0, 4.4, 3.8), Color("2b2e31"), 0.3)
	p.rect(Rect2(19.8, 26.9, 4.4, 0.5), DIAL_BLUE)
	p.text(Vector2(22.0, 30.6), "A", 2.0, BLOCK_WHITE, 0, false)
	# Recess with the reset (blue) and stop (red) tabs.
	p.rect(Rect2(28.4, 1.2, 15.8, 30.0), BLOCK_RECESS, 0.6)
	p.rect(Rect2(29.6, 3.0, 5.0, 26.4), Color("35383c"), 0.3)
	var out_by: float = 0.8 if tripped else 0.0
	if tripped:
		p.rect(Rect2(36.6, 7.4, 4.6, 7.6), Color(0, 0, 0, 0.45), 0.4)
	var blue: Color = Color("3d80d8").lightened(0.12 if tripped else 0.0)
	p.gradient(Rect2(36.0 - out_by, 6.6 - out_by, 4.6, 4.4), blue.lightened(0.12), blue, 0.4)
	p.rect(Rect2(36.0 - out_by, 11.0 - out_by, 2.6, 3.2), blue.darkened(0.08), 0.3)
	var red: Color = Color("e5333d")
	p.polygon(PackedVector2Array([Vector2(36.8, 21.0), Vector2(38.6, 21.0), Vector2(38.6, 19.3), Vector2(41.3, 19.3), Vector2(41.3, 27.9), Vector2(36.8, 27.9)]), red, red.darkened(0.3), 0.12)
	# Auxiliary contacts 95-98.
	var aux_x: Array[float] = OVERLOAD_AUX_X
	var aux: PackedStringArray = OVERLOAD_AUX
	var kinds: PackedStringArray = ["NO", "NO", "NC", "NC"]
	for k: int in 4:
		_block_screw(p, Vector2(aux_x[k], 36.0), 2.4, reach.get(aux[k], Color.TRANSPARENT), k < 2)
		p.text(Vector2(aux_x[k] - 1.9, 41.4), aux[k], 1.7, BLOCK_WHITE)
		p.text(Vector2(aux_x[k] + 2.7, 41.4), kinds[k], 1.7, BLOCK_WHITE)


const SOCKET_BLUE := Color("3c86d6")


## Size of an auxiliary relay with [param poles] changeover contacts: a
## 6.2 mm relay module for one, a slim socket for two, a wide one for three
## or four.
static func relay_size(poles: int) -> Vector2:
	if poles <= 1:
		return Vector2(6.2, 93.0)
	return Vector2(15.8, 78.0) if poles == 2 else Vector2(27.0, 78.0)


## Auxiliary relay (pomocné relé) with 1 to 4 changeover contacts: a
## plug-in relay in a blue screw socket with three stepped tiers of contact
## terminals (common, NO, NC: 11 14 12, 21 24 22, ...) and the coil A2 A1 at
## the bottom; three or four contacts take the wide socket. Through the
## clear cover: the coil, one contact blade per pole (they move while on)
## and the LED; the blue test button and the light grey retaining clip in
## front. [param highlight] glows round it while the coil has power.
static func relay(p: CabinetPainter, on: bool, highlight: bool = false, reach: Dictionary = {}, poles: int = 2) -> void:
	poles = clampi(poles, 1, 4)
	if poles == 1:
		_slim_relay(p, on, highlight, reach)
		return
	var size: Vector2 = relay_size(poles)
	var w: float = size.x
	var h: float = size.y
	var wide: bool = poles > 2
	# Screw columns: contact k's terminals.
	var columns: Array[float] = _relay_columns(poles, w)
	var tiers: PackedStringArray = ["COM", "NO", "NC"]
	var functions: PackedStringArray = ["1", "4", "2"]
	for t: int in 3:
		var y0: float = 11.0 * t
		p.gradient(Rect2(0, y0, w, 11.4), SOCKET_BLUE.lightened(0.12), SOCKET_BLUE.darkened(0.08), 0.8, SOCKET_BLUE.darkened(0.4), 0.15)
		for k: int in columns.size():
			var name: String = str(k + 1) + functions[t]
			_block_screw(p, Vector2(columns[k], y0 + 4.6), 2.0, reach.get(name, Color.TRANSPARENT))
			p.text(Vector2(columns[k], y0 + 9.6), name, 1.6, Color.WHITE)
		if not wide:
			p.text_centered(Vector2(w * 0.5 if poles == 2 else 4.6, y0 + 4.6), tiers[t], 1.3, Color.WHITE, true)
	# Coil tier at the bottom.
	p.gradient(Rect2(0, h - 10.0, w, 10.0), SOCKET_BLUE.lightened(0.12), SOCKET_BLUE.darkened(0.08), 0.8, SOCKET_BLUE.darkened(0.4), 0.15)
	_block_screw(p, Vector2(3.9, h - 4.6), 2.0, reach.get("A2", Color.TRANSPARENT))
	_block_screw(p, Vector2(w - 3.9, h - 4.6), 2.0, reach.get("A1", Color.TRANSPARENT))
	p.text(Vector2(w * 0.5, h - 1.4), "A2  A1", 1.4, Color.WHITE)
	# The relay.
	var body: Rect2 = Rect2(1.0, 33.4, w - 2.0, 35.0)
	if highlight and on:
		for i: int in 3:
			p.rect(body.grow(1.0 + i), Color(1.0, 0.55, 0.25, 0.22 - 0.06 * i), 1.0 + i)
	p.rect(body, Color(0.82, 0.9, 0.96, 0.92), 0.8, Color("7e99b0"), 0.18)
	# Inside, seen through the cover beside the label plate.
	var plate_w: float = 5.6 if not wide else 7.4
	var inside: float = 1.7 + plate_w + 0.8
	p.rect(Rect2(inside, 37.0, 4.6, 12.0), Color("b8733d"), 0.6, Color("7a4a25"), 0.12)
	for g: int in 5:
		p.line(Vector2(inside + 0.2, 38.4 + g * 2.2), Vector2(inside + 4.4, 38.4 + g * 2.2), Color(0, 0, 0, 0.2), 0.15)
	var arm: float = 1.2 if on else 0.0
	p.rect(Rect2(inside - 0.4, 50.0 - arm * 0.5, w - inside - 1.8, 1.0), Color("8f969c"))
	var blades: float = (w - inside - 3.0) / poles
	for c: int in poles:
		var bx: float = inside + 0.4 + blades * c
		p.rect(Rect2(bx, 52.0, 0.8, 9.0), Color("d9b45a"))
		p.rect(Rect2(bx + (0.9 if on else 0.0), 52.4, 0.6, 3.0), Color("c08a3a"))
	led(p, Vector2(w - 3.2, 63.6), LED_GREEN, on, 0.8)
	# Label plate: coil and contact ratings.
	p.rect(Rect2(1.7, 35.0, plate_w, 24.0), Color("eceeef"), 0.4, Color("b5babf"), 0.12)
	var px: float = 1.7 + plate_w * 0.5
	p.text(Vector2(px, 40.0), "24V", 1.4, PRINT)
	p.text(Vector2(px, 42.2), "DC", 1.4, PRINT)
	p.text(Vector2(px, 46.0), "8A" if poles <= 2 else "7A", 1.3, PRINT, 0, false)
	p.text(Vector2(px, 48.0), "250V~", 1.1, PRINT, 0, false)
	p.text(Vector2(px, 51.6), "%dCO" % poles, 1.3, PRINT, 0, true)
	# Lockable test button and the retaining clip.
	p.rect(Rect2(1.8, 61.0, 4.4, 5.6), SOCKET_BLUE.darkened(0.1), 0.6)
	p.rect(Rect2(3.1, 61.8 + (1.2 if on else 0.0), 1.8, 2.6), Color.WHITE, 0.3)
	p.polygon(PackedVector2Array([Vector2(6.6, 60.4), Vector2(w - 1.4, 59.2), Vector2(w - 1.4, h - 9.4), Vector2(6.6, h - 9.4)]), Color("e3e5e7"), Color("a6abb0"), 0.15)


## Relay module 6.2 mm wide with one changeover contact, seen from the
## front on the rail: the coil terminals A2 and A1 on stepped tiers at the
## top, the LED, the end of the plug-in relay with its black ejector, then
## the contact terminals 14, 11 and 12 on stepped tiers.
## Tiers of the 6.2 mm relay module [param h] mm high, from the outside in:
## [top, height, terminal, screw y, label y].
static func _slim_relay_tiers(h: float) -> Array:
	return [
		[0.0, 11.0, "A2", 5.2, 10.0], [10.0, 9.4, "A1", 14.2, 18.6],
		[h - 22.0, 8.0, "14", h - 18.4, h - 14.6], [h - 15.0, 7.0, "11", h - 11.8, h - 8.4], [h - 8.4, 8.4, "12", h - 5.4, h - 1.0],
	]


## Screw columns of an auxiliary relay with [param poles] changeover
## contacts in a socket [param w] mm wide (two or more contacts): the slim
## socket keeps its two places, the wide one spreads them.
static func _relay_columns(poles: int, w: float) -> Array[float]:
	var columns: Array[float] = []
	if poles > 2:
		var pitch: float = (w - 4.6) / poles
		for k: int in poles:
			columns.append(2.3 + pitch * (k + 0.5))
	else:
		columns = [w - 3.9, 3.9]
	return columns


static func _slim_relay(p: CabinetPainter, on: bool, highlight: bool, reach: Dictionary) -> void:
	var size: Vector2 = relay_size(1)
	var w: float = size.x
	var h: float = size.y
	var tiers: Array = _slim_relay_tiers(h)
	for t: Array in tiers:
		p.gradient(Rect2(0, t[0], w, t[1]), SOCKET_BLUE.lightened(0.14), SOCKET_BLUE.darkened(0.1), 0.5, SOCKET_BLUE.darkened(0.45), 0.15)
	# Middle: the socket's front with the LED and the relay in it.
	var mid: Rect2 = Rect2(0, 19.0, w, h - 41.0)
	p.gradient(mid, SOCKET_BLUE.lightened(0.2), SOCKET_BLUE, 0.5, SOCKET_BLUE.darkened(0.45), 0.15)
	for t: Array in tiers:
		_block_screw(p, Vector2(w * 0.5, t[3]), 1.5, reach.get(t[2], Color.TRANSPARENT))
		p.text(Vector2(w * 0.5, t[4]), t[2], 1.5, Color.WHITE)
	led(p, Vector2(w * 0.5, 23.6), LED_GREEN, on, 0.9)
	var relay: Rect2 = Rect2(0.6, 27.0, w - 1.2, 28.0)
	if highlight and on:
		for i: int in 3:
			p.rect(relay.grow(0.8 + i), Color(1.0, 0.55, 0.25, 0.25 - 0.07 * i), 0.8 + i)
	p.gradient(relay, Color("f4f3ee"), Color("dedcd3"), 0.4, Color("a9a79d"), 0.15)
	# Ejector: black lever over the end of the relay, notched.
	var ej: Rect2 = Rect2(0.3, 52.0, w - 0.6, 15.0)
	p.gradient(ej, Color("34363a"), Color("1b1c1f"), 0.5, Color("0e0f10"), 0.15)
	p.rect(Rect2(1.4, 56.0, w - 2.8, 3.0), Color("0f1012"), 0.3)
	p.rect(Rect2(1.4, 61.0, w - 2.8, 3.0), Color("0f1012"), 0.3)


# --- Time relay -------------------------------------------------------------------

## Function codes on the first function dial of the time relay, OFF to test.
const TIMER_DIAL_1: PackedStringArray = ["OFF", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "test"]
const TIMER_DIAL_2: PackedStringArray = ["1s", "10", "1m", "10", "1h", "10", "100"]
const TIMER_DIAL_3: PackedStringArray = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
const TIMER_DIAL_4: PackedStringArray = ["OFF", "F10", "F11", "F12", "F13", "F14", "F15", "F16", "F17", "F18"]


## Multifunction time relay (časové relé), one module wide, light grey,
## with 1 to 3 changeover contacts: the coil A1 A2 and the control input
## on the outer top tier, the contacts 16 15 18 on the outer bottom tier,
## 26 25 28 on the inner bottom tier and 36 35 38 on the inner top tier
## (tiers without contacts stay plain); four white dials (function, range,
## fine time, function) with their scales, LED bars U (green, power) and R
## (yellow, output). The function dials point at [param code] ("F1" to
## "F12", see [method timer_dials]).
## Screw columns of the time relay.
const TIMER_X: Array[float] = [3.6, 9.0, 14.4]


## Terminal rows of the time relay: [names, mark y (-1: none), name y,
## screw y, shown].
static func _timer_rows(control: String, contacts: int) -> Array:
	var h: float = MODULE_H
	return [
		[["A1", "A2", control], 2.2, 6.6, 9.4, true],
		[["36", "35", "38"], 13.4, 18.0, 21.4, contacts >= 3],
		[["26", "25", "28"], -1.0, h - 13.4, h - 17.2, contacts >= 2],
		[["16", "15", "18"], h - 2.8, h - 4.0, h - 8.6, true],
	]


static func timer(p: CabinetPainter, powered: bool, output: bool, code: String = "F2", control: String = "S", reach: Dictionary = {}, contacts: int = 1) -> void:
	var w: float = MODULE_W
	var h: float = MODULE_H
	# Tiers, outer ones lowest, then the raised front.
	for t: Array in [[0.0, 12.6], [12.0, 13.6], [h - 20.6, 8.6], [h - 12.6, 12.6]]:
		p.gradient(Rect2(0.3, t[0], w - 0.6, t[1]), MODULAR_FACE, MODULAR_SHADE, 0.6, MODULAR_EDGE, 0.15)
	var xs: Array[float] = TIMER_X
	for row: Array in _timer_rows(control, contacts):
		if not row[4]:
			continue
		for j: int in 3:
			var name: String = row[0][j]
			if row[1] >= 0.0:
				p.rect(Rect2(xs[j] - 1.8, row[1], 3.6, 1.5), Color("3a3d41"), 0.3)
			p.text(Vector2(xs[j], row[2]), name, 1.9, MODULAR_PRINT, 0, false, 5.2)
			_modular_screw_small(p, Vector2(xs[j], row[3]), reach.get(name, Color.TRANSPARENT))
	var front: Rect2 = Rect2(0.3, 25.0, w - 0.6, 45.0)
	p.rect(Rect2(front.position.x, front.end.y, front.size.x, 0.8), Color(0, 0, 0, 0.12))
	p.gradient(front, MODULAR_FACE.lightened(0.3), MODULAR_FACE, 0.6, MODULAR_EDGE, 0.15)
	var dials: Vector2i = timer_dials(code)
	var steps: Array[int] = [dials.x, 2, 4, dials.y]
	var scales: Array = [TIMER_DIAL_1, TIMER_DIAL_2, TIMER_DIAL_3, TIMER_DIAL_4]
	var marks: PackedStringArray = ["fc", "t", "t", "fc"]
	for d: int in 4:
		var c: Vector2 = Vector2(8.6, 32.6 + d * 10.2)
		_timer_dial(p, c, scales[d], steps[d])
		p.text(Vector2(w - 1.0, c.y + 0.8), marks[d], 2.0, MODULAR_PRINT, 1, true)
	_led_bar(p, Rect2(1.0, 40.8, 1.2, 4.0), LED_GREEN, powered)
	_led_bar(p, Rect2(1.0, 51.0, 1.2, 4.0), LED_YELLOW, output)
	p.text(Vector2(1.6, 46.8), "U", 1.6, MODULAR_PRINT)
	p.text(Vector2(1.6, 57.0), "R", 1.6, MODULAR_PRINT)


## Steps of the two function dials for function [param code]: F1 to F8 and
## F9 (test) on the first dial with the second at OFF, F10 to F12 on the
## second with the first at OFF. The true off-delay has no code of its own;
## it is shown as the first free function of the second dial (F13).
static func timer_dials(code: String) -> Vector2i:
	var n: int = int(code.trim_prefix("F")) if code.trim_prefix("F").is_valid_int() else 13
	if n >= 1 and n <= 9:
		return Vector2i(n, 0)
	return Vector2i(0, clampi(n - 9, 1, 9))


static func _modular_screw_small(p: CabinetPainter, center: Vector2, reach: Color) -> void:
	if reach.a > 0.0:
		p.circle(center, 2.75, Color(1, 1, 1, 0.85))
		p.circle(center, 2.45, reach)
	p.circle(center, 2.1, Color("a1a6ab"))
	p.circle(center, 1.75, METAL, METAL_DARK, 0.12)
	p.line(center + Vector2(-1.0, 0), center + Vector2(1.0, 0), METAL_DARK, 0.3)
	p.line(center + Vector2(0, -1.0), center + Vector2(0, 1.0), METAL_DARK, 0.3)


## White dial with a cross grip and its pointer at step [param step] of
## [param scale], the scale printed round it (open at the bottom).
static func _timer_dial(p: CabinetPainter, c: Vector2, scale: PackedStringArray, step: int) -> void:
	var n: int = scale.size()
	for i: int in n:
		var a: float = lerpf(PI * 0.78, PI * 2.22, float(i) / (n - 1))
		var along: Vector2 = Vector2(cos(a), sin(a))
		p.line(c + along * 3.1, c + along * 3.6, MODULAR_PRINT, 0.12)
		p.text_centered(c + along * 5.0, scale[i], 1.0, MODULAR_PRINT, false)
	p.circle(c + Vector2(0.2, 0.3), 2.9, Color(0, 0, 0, 0.18))
	p.circle(c, 2.8, Color("fafafa"), Color("b9bec3"), 0.15)
	var a2: float = lerpf(PI * 0.78, PI * 2.22, float(step) / (n - 1))
	for k: int in 2:
		var g: float = a2 + PI * 0.25 + k * PI * 0.5
		p.line(c - Vector2(cos(g), sin(g)) * 1.8, c + Vector2(cos(g), sin(g)) * 1.8, Color("d6d9dc"), 0.7)
	p.polygon(PackedVector2Array([c + Vector2(cos(a2), sin(a2)) * 2.6, c + Vector2(cos(a2 + 0.5), sin(a2 + 0.5)) * 1.6, c + Vector2(cos(a2 - 0.5), sin(a2 - 0.5)) * 1.6]), Color("9aa0a5"))


static func _led_bar(p: CabinetPainter, r: Rect2, color: Color, lit: bool) -> void:
	if lit:
		for i: int in 3:
			p.rect(r.grow(0.5 + 0.6 * i), Color(color, 0.22 - 0.06 * i), 0.6 + 0.6 * i)
	p.rect(r, color if lit else color.darkened(0.6), 0.2)


# --- Bridge rectifier ---------------------------------------------------------------

## Size of a bridge rectifier: one module.
const RECTIFIER := Vector2(18.0, 90.0)
## Height of the rectifier's screws from its top and bottom.
const RECTIFIER_SCREW_Y: float = 8.6


## Bridge rectifier (usměrňovač, TB), one dark module like the contactors:
## the AC input ~1 ~2 on the top tier, the DC output + and - on the bottom
## tier (teal names), the bridge symbol on the front and a green LED that
## lights while the input has voltage ([param on]).
static func rectifier(p: CabinetPainter, on: bool, reach: Dictionary = {}) -> void:
	var w: float = RECTIFIER.x
	var h: float = RECTIFIER.y
	var edge: Color = Color("2e3034")
	for t: Array in [[0.0, 13.0], [h - 13.0, 13.0]]:
		p.gradient(Rect2(0.3, t[0], w - 0.6, t[1]), BLOCK_LIGHT, BLOCK_DARK, 0.6, edge, 0.15)
	var xs: Array[float] = [w * 0.28, w * 0.72]
	var top: PackedStringArray = ["~1", "~2"]
	var bottom: PackedStringArray = ["+", "-"]
	for j: int in 2:
		_block_screw(p, Vector2(xs[j], RECTIFIER_SCREW_Y), 2.1, reach.get(top[j], Color.TRANSPARENT))
		_block_screw(p, Vector2(xs[j], h - RECTIFIER_SCREW_Y), 2.1, reach.get(bottom[j], Color.TRANSPARENT))
		p.text(Vector2(xs[j], 4.4), top[j], 2.0, BLOCK_TEAL, 0, false)
		p.text(Vector2(xs[j], h - 2.4), "−" if bottom[j] == "-" else "+", 2.6, BLOCK_TEAL, 0, true)
	var front: Rect2 = Rect2(0.3, 13.0, w - 0.6, h - 26.0)
	p.rect(Rect2(front.position.x, front.end.y, front.size.x, 0.8), Color(0, 0, 0, 0.15))
	p.gradient(front, BLOCK_LIGHT.lightened(0.05), BLOCK_BODY, 0.6, edge, 0.2)
	_bridge_symbol(p, Vector2(w * 0.5, 34.0), 4.6, BLOCK_WHITE)
	p.text(Vector2(w * 0.5, 43.6), "~ / =", 1.9, BLOCK_WHITE, 0, true)
	led(p, Vector2(w * 0.5, 50.0), LED_GREEN, on, 1.0)
	p.text(Vector2(w * 0.5, 54.2), "DC", 1.6, BLOCK_WHITE, 0, true)


## Bridge (Graetz) symbol: a square on its corner with a diode on each side,
## AC at the left and right corners, + at the top, - at the bottom.
static func _bridge_symbol(p: CabinetPainter, c: Vector2, r: float, ink: Color) -> void:
	var top: Vector2 = c + Vector2(0, -r)
	var bottom: Vector2 = c + Vector2(0, r)
	var left: Vector2 = c + Vector2(-r, 0)
	var right: Vector2 = c + Vector2(r, 0)
	# Each diode conducts towards the + corner.
	for side: Array in [[left, top], [right, top], [bottom, left], [bottom, right]]:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		p.line(a, b, ink, 0.15)
		var mid: Vector2 = a.lerp(b, 0.5)
		var along: Vector2 = (b - a).normalized()
		var across: Vector2 = Vector2(-along.y, along.x)
		var s: float = r * 0.19
		p.polygon(PackedVector2Array([mid - along * s + across * s, mid - along * s - across * s, mid + along * s]), ink)
		p.line(mid + along * s + across * s * 1.1, mid + along * s - across * s * 1.1, ink, 0.18)
	p.text(top + Vector2(0, -0.8), "+", 1.8, ink, 0, true)
	p.text(bottom + Vector2(0, 2.6), "−", 1.8, ink, 0, true)


# --- Terminal blocks ----------------------------------------------------------------

## A strip of push-in terminal blocks (svorkovnice) between two end stops
## with the strip's name on the first one. [param items]: {"label", "kind":
## "L" | "N" | "PE", "reach": Color}; "reach" rings the wire entries (voltage
## reach). Terminals sit on whole pixels so every one looks the same.
## Returns the width in mm.
static func terminal_strip(p: CabinetPainter, group: String, items: Array) -> float:
	var q: CabinetPainter = p.snapped()
	var pitch: float = q.snap(TERMINAL.x)
	var x: float = 0.0
	_end_stop(q, x, group)
	x += q.snap(END_STOP_W)
	for item: Dictionary in items:
		_terminal(q, x, pitch, item)
		x += pitch
	# End plate.
	q.hgradient(Rect2(x, 0.8, q.snap(1.4), TERMINAL.y - 1.6), TERMINAL_GREY.darkened(0.15), TERMINAL_GREY.darkened(0.35), 0.3)
	x += q.snap(1.4)
	_end_stop(q, x, "")
	return x + q.snap(END_STOP_W)


## Width in mm of a terminal strip of [param count] terminals with its end
## plate and end stops (as [method terminal_strip] draws it at [param k]
## pixels per mm).
static func terminal_strip_width(count: int, k: float = 0.0) -> float:
	if k <= 0.0:
		return 2.0 * END_STOP_W + count * TERMINAL.x + 1.4
	var snap: Callable = func(mm: float) -> float: return roundf(mm * k) / k
	return 2.0 * snap.call(END_STOP_W) + count * snap.call(TERMINAL.x) + snap.call(1.4)


const TERMINAL_GREY := Color("b4b9bd")
## Height of a push-in terminal's wire entries from its ends.
const TERMINAL_ENTRY: float = 3.4
const PUSH_ORANGE := Color("f28c1b")


static func _terminal_color(kind: String) -> Color:
	match kind:
		"N":
			return Color("2f7fd0")
		"PE":
			return Color("3f9e4a")
	return TERMINAL_GREY


## One push-in terminal [param w] mm wide: at both ends a wire entry with
## the clamp's spring inside, the orange push button that opens it and a
## test socket; the marker tag in the middle.
static func _terminal(p: CabinetPainter, x: float, w: float, item: Dictionary) -> void:
	var kind: String = item.get("kind", "L")
	var body: Color = _terminal_color(kind)
	var h: float = TERMINAL.y
	# Body: lit from the left, a groove on the right where the next one starts.
	p.hgradient(Rect2(x, 0, w, h), body.lightened(0.16), body.darkened(0.1), 0.0)
	if kind == "PE":
		p.hgradient(Rect2(x + p.snap(w * 0.36), 0, p.snap(w * 0.28), h), Color("f6dc3c"), Color("e2c425"))
	p.line(Vector2(x + w - 0.5 / p.k, 0), Vector2(x + w - 0.5 / p.k, h), body.darkened(0.45), 0.0)
	p.line(Vector2(x + 0.5 / p.k, 0), Vector2(x + 0.5 / p.k, h), body.lightened(0.35), 0.0)
	var reach: Color = item.get("reach", Color.TRANSPARENT)
	var cx: float = x + w * 0.5
	var bw: float = p.snap(w - 1.8)
	for end: int in 2:
		# Distances from the end of the terminal, mirrored for the bottom.
		var at: Callable = func(d: float) -> float: return d if end == 0 else h - d
		# Wire entry: a rounded square opening, the spring's edge inside it.
		var entry: Vector2 = Vector2(cx, at.call(TERMINAL_ENTRY))
		if reach.a > 0.0:
			# Voltage reach: a coloured frame with a light edge, seen on any body colour.
			p.rect(Rect2(entry - Vector2(2.45, 2.45), Vector2(4.9, 4.9)), Color(1, 1, 1, 0.85), 1.3)
			p.rect(Rect2(entry - Vector2(2.1, 2.1), Vector2(4.2, 4.2)), reach, 1.1)
		p.rect(Rect2(entry - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), HOLE, 0.8)
		p.rect(Rect2(entry + Vector2(-1.0, 0.3 if end == 0 else -0.8), Vector2(2.0, 0.5)), METAL_DARK, 0.2)
		# Push button: the same on every terminal, lighter towards the wire entry.
		var top: float = at.call(6.6) if end == 0 else at.call(11.4)
		var button: Rect2 = Rect2(cx - bw * 0.5, top, bw, 4.8)
		p.rect(button.grow(0.25), body.darkened(0.4), 0.9)
		if end == 0:
			p.gradient(button, PUSH_ORANGE.lightened(0.18), PUSH_ORANGE.darkened(0.08), 0.7)
		else:
			p.gradient(button, PUSH_ORANGE.darkened(0.08), PUSH_ORANGE.lightened(0.18), 0.7)
		p.line(Vector2(cx - bw * 0.3, button.get_center().y), Vector2(cx + bw * 0.3, button.get_center().y), PUSH_ORANGE.darkened(0.35), 0.35)
		# Test socket.
		p.circle(Vector2(cx, at.call(14.2)), 0.7, HOLE)
	# Marker tag with the terminal name.
	var tag: Rect2 = Rect2(x + p.snap(0.5), h * 0.5 - 4.5, w - p.snap(1.0), 9.0)
	p.rect(tag, Color("fbfbf8"), 0.3, Color(0, 0, 0, 0.25), 0.0)
	p.text_centered(tag.get_center(), str(item.get("label", "")), 2.4, Color("111111"), true, w - 0.8)


static func _end_stop(p: CabinetPainter, x: float, group: String) -> void:
	var w: float = p.snap(END_STOP_W)
	var r: Rect2 = Rect2(x + p.snap(0.5), 5.0, w - p.snap(1.0), TERMINAL.y - 10.0)
	p.hgradient(r, Color("50555b"), Color("2a2d31"), 1.0)
	p.rect(r, Color.TRANSPARENT, 1.0, Color("16181a"), 0.0)
	_block_screw(p, Vector2(x + w * 0.5, TERMINAL.y * 0.5 + 9.0), 1.4)
	if not group.is_empty():
		var tag: Rect2 = Rect2(x + p.snap(1.2), TERMINAL.y * 0.5 - 8.0, w - p.snap(2.4), 9.0)
		p.rect(tag, Color("fbfbf8"), 0.3, Color(0, 0, 0, 0.25), 0.0)
		p.text_centered(tag.get_center(), group, 2.6, Color("111111"), true, w - 2.6)


## Centre of the top wire entry of terminal [param index] of a terminal
## strip (as [method terminal_strip] draws it at [param k] pixels per mm).
static func strip_entry(index: int, k: float) -> Vector2:
	var snap: Callable = func(mm: float) -> float: return roundf(mm * k) / k
	var pitch: float = snap.call(TERMINAL.x)
	return Vector2(snap.call(END_STOP_W) + pitch * (index + 0.5), TERMINAL_ENTRY)


# --- Terminals and wires -----------------------------------------------------------

## Where the wires go into a device of [param kind] ([enum CabinetDevices.Kind])
## as [param desc] describes it (see [method CabinetDevices.describe]):
## terminal name -> Vector3 (x, y: centre of the screw from the device's
## top-left corner; z: the screw's radius, where a wire ends).
static func terminal_points(kind: int, desc: Dictionary) -> Dictionary:
	var points: Dictionary = {}
	match kind:
		CabinetDevices.Kind.BREAKER, CabinetDevices.Kind.FUSE:
			var fuse: bool = kind == CabinetDevices.Kind.FUSE
			var top: float = (MODULE_H - FUSE_H) * 0.5 + FUSE_HOLE_TOP if fuse else BREAKER_SCREW_Y
			var bottom: float = (MODULE_H + FUSE_H) * 0.5 - FUSE_HOLE_BOTTOM if fuse else MODULE_H - BREAKER_SCREW_Y
			for i: int in int(desc.get("poles", 1)):
				var cx: float = MODULE_W * (i + 0.5)
				points[str(2 * i + 1)] = Vector3(cx, top, 3.1)
				points[str(2 * i + 2)] = Vector3(cx, bottom, 3.1)
		CabinetDevices.Kind.CONTACTOR:
			var four: bool = int(desc.get("poles", 3)) >= 4
			var power_x: Array[float] = CONTACTOR_POWER_X4 if four else CONTACTOR_POWER_X
			var radius: float = 2.1 if four else 2.3
			for j: int in power_x.size():
				points[str(2 * j + 1)] = Vector3(power_x[j], 5.6, radius + 0.55)
				points[str(2 * j + 2)] = Vector3(power_x[j] + 0.6, CONTACTOR.y - 6.9, radius + 0.65)
			var aux: Array = desc.get("aux", [["13", "NO", "14"], ["21", "NC", "22"]])
			var top_names: Array = [aux[0][0], aux[1][0], "A1"]
			var bottom_names: Array = [aux[0][2], aux[1][2], "A2"]
			for j: int in 3:
				points[top_names[j]] = Vector3(CONTACTOR_INNER_X[j], 12.7, 3.15)
				points[bottom_names[j]] = Vector3(CONTACTOR_INNER_X[j] + 0.8, 58.8, 3.15)
			for k: int in mini(aux.size() - 2, 4):
				points[aux[k + 2][0]] = Vector3(AUX_BLOCK_X[k], 22.4, 2.85)
				points[aux[k + 2][2]] = Vector3(AUX_BLOCK_X[k], 48.0, 2.85)
		CabinetDevices.Kind.OVERLOAD:
			for j: int in 3:
				points[str(2 * j + 2)] = Vector3(OVERLOAD_OUT_X[j], OVERLOAD.y - 9.4, 2.85)
			for k: int in 4:
				points[OVERLOAD_AUX[k]] = Vector3(OVERLOAD_AUX_X[k], 36.0, 2.95)
		CabinetDevices.Kind.RELAY:
			var poles: int = clampi(int(desc.get("poles", 2)), 1, 4)
			var size: Vector2 = relay_size(poles)
			if poles == 1:
				for t: Array in _slim_relay_tiers(size.y):
					points[t[2]] = Vector3(size.x * 0.5, t[3], 2.05)
			else:
				var columns: Array[float] = _relay_columns(poles, size.x)
				var functions: PackedStringArray = ["1", "4", "2"]
				for t: int in 3:
					for k: int in columns.size():
						points[str(k + 1) + functions[t]] = Vector3(columns[k], 11.0 * t + 4.6, 2.55)
				points["A2"] = Vector3(3.9, size.y - 4.6, 2.55)
				points["A1"] = Vector3(size.x - 3.9, size.y - 4.6, 2.55)
		CabinetDevices.Kind.TIMER:
			for row: Array in _timer_rows(desc.get("control", "S"), int(desc.get("contacts", 1))):
				if row[4]:
					for j: int in 3:
						points[row[0][j]] = Vector3(TIMER_X[j], row[3], 2.1)
		CabinetDevices.Kind.RECTIFIER:
			var xs: Array[float] = [RECTIFIER.x * 0.28, RECTIFIER.x * 0.72]
			var top: PackedStringArray = ["~1", "~2"]
			var bottom: PackedStringArray = ["+", "-"]
			for j: int in 2:
				points[top[j]] = Vector3(xs[j], RECTIFIER_SCREW_Y, 2.65)
				points[bottom[j]] = Vector3(xs[j], RECTIFIER.y - RECTIFIER_SCREW_Y, 2.65)
	return points


## Insulation colours of the wires ([enum CabinetDevices.Conductor]): red
## for the phase of the control circuit, light blue for the neutral, grey
## for the main power circuit, green and yellow for PE.
const WIRE_COLORS: Array[Color] = [Color("d6262b"), Color("5cb8f0"), Color("a3a8ad"), Color("3faa3c")]
const WIRE_PE_STRIPE := Color("f2d630")
## Length of the bare ferrule at each end of a wire.
const FERRULE: float = 1.8


## A wire of [param conductor] ([enum CabinetDevices.Conductor]) along
## [param points] (mm), [param width] mm thick: bends rounded, shaded like
## round insulation, a ferrule at both ends ([param bare_start]: none at
## the first, a core coming out of a cable).
static func wire(p: CabinetPainter, points: PackedVector2Array, conductor: int, width: float, bare_start: bool = false) -> void:
	if points.size() < 2:
		return
	var color: Color = WIRE_COLORS[conductor]
	var path: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in _rounded_path(points, width * 1.6):
		path.append(p.px(point))
	var w: float = maxf(width * p.k, 1.5)
	p.canvas.draw_polyline(path, color.darkened(0.5), w + 1.0, true)
	p.canvas.draw_polyline(path, color, maxf(w - 0.6, 1.0), true)
	if conductor == CabinetDevices.Conductor.PE:
		p.canvas.draw_polyline(path, WIRE_PE_STRIPE, maxf(w * 0.4, 1.0), true)
	elif w >= 3.0:
		# Light along the top and left of the round insulation.
		var shine: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in path:
			shine.append(point - Vector2(1, 1) * w * 0.18)
		p.canvas.draw_polyline(shine, color.lightened(0.35), maxf(w * 0.22, 1.0), true)
	for end: int in range(1 if bare_start else 0, 2):
		var tip: Vector2 = points[0] if end == 0 else points[points.size() - 1]
		var next: Vector2 = points[1] if end == 0 else points[points.size() - 2]
		var back: Vector2 = tip + (next - tip).normalized() * minf(FERRULE, tip.distance_to(next))
		p.line(tip, back, METAL_DARK, width + 0.2)
		p.line(tip, back, METAL, maxf(width - 0.5, 0.3))


## [param points] with every bend rounded off to [param radius] mm (less
## where the legs are short).
static func _rounded_path(points: PackedVector2Array, radius: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array([points[0]])
	for i: int in range(1, points.size() - 1):
		var a: Vector2 = points[i - 1]
		var corner: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var r: float = minf(radius, minf(a.distance_to(corner), b.distance_to(corner)) * 0.5)
		if r < 0.05:
			result.append(corner)
			continue
		var from: Vector2 = corner + (a - corner).normalized() * r
		var to: Vector2 = corner + (b - corner).normalized() * r
		for s: int in 5:
			var t: float = s / 4.0
			result.append(from.lerp(corner, t).lerp(corner.lerp(to, t), t))
	result.append(points[points.size() - 1])
	return result


## Cable gland [param r] (mm) in the top of the enclosure where a supply
## cable comes in: the black cable, the grey nut on the frame and the
## black sealing insert the cores come out of.
static func cable_gland(p: CabinetPainter, r: Rect2) -> void:
	var cable: Rect2 = Rect2(r.position.x + r.size.x * 0.18, r.position.y, r.size.x * 0.64, r.size.y * 0.5)
	p.hgradient(cable, Color("2b2d30"), Color("15161a"), 0.6)
	var nut: Rect2 = Rect2(r.position.x, r.position.y + r.size.y * 0.35, r.size.x, r.size.y * 0.65)
	p.gradient(nut, Color("8a9095"), Color("5d6368"), 0.8, Color("3d4145"), 0.2)
	for i: int in range(1, 4):
		var x: float = nut.position.x + nut.size.x * i / 4.0
		p.line(Vector2(x, nut.position.y + 0.4), Vector2(x, nut.end.y - 0.4), Color(0, 0, 0, 0.25), 0.2)
	p.rect(Rect2(cable.position.x, nut.end.y - 1.2, cable.size.x, 1.2), Color("1a1b1e"), 0.4)
