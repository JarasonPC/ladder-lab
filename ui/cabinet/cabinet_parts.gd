class_name CabinetParts
extends RefCounted
## Parts of the switchboard (rozvaděč) drawn to their real sizes in
## millimetres with a [CabinetPainter]: DIN rails, wire ducts, terminal
## blocks, circuit breakers, fuse holders, contactors, overload relays,
## relays and time relays. Each part is drawn with its top-left corner at the
## painter's origin; DIN-rail parts are centred on the rail.
## PREVIEW: every part has look variants ("A", "B", "C") to choose from.

## Height of a modular device (breaker, fuse holder, time relay).
const MODULE_H: float = 90.0
## Width of one module (one pole of a breaker).
const MODULE_W: float = 18.0
const CONTACTOR := Vector2(45.0, 80.0)
const OVERLOAD := Vector2(45.0, 58.0)
const RELAY := Vector2(27.0, 78.0)
const TERMINAL := Vector2(5.2, 47.0)
const END_STOP_W: float = 9.0
const RAIL_H: float = 35.0

const WHITE := Color("eef0f1")
const WHITE_SHADE := Color("d6dade")
const WHITE_EDGE := Color("9aa1a7")
const LIGHT_GREY := Color("c4c9cd")
const DARK_GREY := Color("53585e")
const HOLE := Color("1d1f22")
const METAL := Color("d3d7da")
const METAL_DARK := Color("868c92")
const PRINT := Color("34383d")
const PRINT_LIGHT := Color("eceef0")
const LED_GREEN := Color("39d353")
const LED_RED := Color("ff4545")
const LED_YELLOW := Color("ffb000")
const LED_OFF := Color("4a4d50")
const TRIP := Color("ff8a1f")
const DIAL_BLUE := Color("2f6fd4")
const STOP_RED := Color("d63b3b")


# --- Common details -------------------------------------------------------------

## Terminal screw seen from the front: a dark opening with a combination
## screw in it; [param reach] colours a ring around it (voltage reach).
static func screw(p: CabinetPainter, center: Vector2, radius: float = 2.6, reach: Color = Color.TRANSPARENT) -> void:
	var hole: float = radius * 1.15
	p.rect(Rect2(center - Vector2(hole, hole), Vector2(hole, hole) * 2.0), HOLE, radius * 0.35)
	if reach.a > 0.0:
		p.ring(center, radius * 0.98, reach, 0.6)
	p.circle(center, radius * 0.8, METAL, METAL_DARK, 0.15)
	p.circle(center + Vector2(-0.25, -0.25) * radius, radius * 0.35, Color(1, 1, 1, 0.35))
	var s: float = radius * 0.5
	p.line(center + Vector2(-s, 0), center + Vector2(s, 0), METAL_DARK, radius * 0.16)
	p.line(center + Vector2(0, -s), center + Vector2(0, s), METAL_DARK, radius * 0.16)


static func led(p: CabinetPainter, center: Vector2, color: Color, lit: bool, radius: float = 1.1) -> void:
	if lit:
		for i: int in 3:
			p.circle(center, radius * (1.6 + 0.7 * i), Color(color, 0.22 - 0.06 * i))
	p.circle(center, radius, color if lit else LED_OFF, Color(0, 0, 0, 0.4), 0.15)
	if lit:
		p.circle(center + Vector2(-0.3, -0.3) * radius, radius * 0.4, Color(1, 1, 1, 0.7))


## Designation label: "A" white plate, "B" teal print, "C" yellow plate.
static func label(p: CabinetPainter, center: Vector2, text: String, variant: String = "A", width_mm: float = 16.0) -> void:
	match variant:
		"B":
			p.text_centered(center, text, 3.4, Color("2c8b86"), true, width_mm + 6.0)
		"C":
			p.rect(Rect2(center - Vector2(width_mm * 0.5, 2.6), Vector2(width_mm, 5.2)), Color("f4d23c"), 0.5, Color("b89a14"), 0.15)
			p.text_centered(center, text, 3.2, PRINT, true, width_mm - 1.0)
		_:
			p.rect(Rect2(center - Vector2(width_mm * 0.5, 2.6), Vector2(width_mm, 5.2)), Color("fbfbf8"), 0.5, Color(0, 0, 0, 0.35), 0.15)
			p.text_centered(center, text, 3.2, Color("111111"), true, width_mm - 1.0)


## Body of a modular device: shoulders with the terminals at the top and
## the bottom, a raised front cap in the middle.
static func _modular_body(p: CabinetPainter, w: float, body: Color, shade: Color, edge: Color) -> void:
	p.rect(Rect2(0, 0, w, MODULE_H), shade, 1.2, edge, 0.2)
	p.gradient(Rect2(0.6, 21.0, w - 1.2, 48.0), body.lightened(0.15), body, 1.0, edge, 0.15)


# --- DIN rail, ducts, plate -----------------------------------------------------

## TS35 rail [param length] mm long: "A" with mounting slots, "B" plain.
static func din_rail(p: CabinetPainter, length: float, variant: String = "A") -> void:
	var steel: Color = Color("e4e8eb")
	p.gradient(Rect2(0, 0, length, RAIL_H), steel.lightened(0.3), steel.darkened(0.1), 0.0, METAL_DARK, 0.2)
	p.gradient(Rect2(0, 5.0, length, 25.0), steel, steel.darkened(0.06))
	p.line(Vector2(0, 5.0), Vector2(length, 5.0), METAL_DARK, 0.2)
	p.line(Vector2(0, 30.0), Vector2(length, 30.0), METAL_DARK, 0.2)
	p.line(Vector2(0, 0.6), Vector2(length, 0.6), Color(1, 1, 1, 0.6), 0.2)
	if variant == "A":
		var x: float = 5.0
		while x + 15.0 <= length - 3.0:
			p.rect(Rect2(x, 14.9, 15.0, 5.2), Color(0, 0, 0, 0.55), 2.6)
			x += 25.0


## Slotted wire duct: "A" open (fingers and the wires' channel seen), "B"
## with its cover on. [param vertical] runs it down instead of across.
static func duct(p: CabinetPainter, length: float, thickness: float, vertical: bool, variant: String = "A") -> void:
	var base: Color = Color("9ea4a9")
	var r: Rect2 = Rect2(0, 0, thickness, length) if vertical else Rect2(0, 0, length, thickness)
	if variant == "B":
		p.rect(r, base.lightened(0.12), 0.6, base.darkened(0.3), 0.2)
		var inner: Rect2 = r.grow(-2.0)
		p.rect(inner, base.lightened(0.2), 0.4, base.darkened(0.1), 0.15)
		return
	p.rect(r, base.darkened(0.35), 0.4, base.darkened(0.45), 0.2)
	var finger: float = 6.0
	var gap: float = 4.0
	var depth: float = 8.0
	var along: float = 1.5
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


## Mounting plate inside the enclosure: "A" galvanized, "B" white,
## "C" orange, "D" dark.
static func plate(p: CabinetPainter, size: Vector2, variant: String = "A") -> void:
	var frame: Color = Color("b3b8bc")
	p.rect(Rect2(Vector2.ZERO, size), frame, 3.0, frame.darkened(0.35), 0.3)
	var inner: Rect2 = Rect2(Vector2(6, 6), size - Vector2(12, 12))
	p.rect(inner.grow(1.0), frame.darkened(0.45), 1.5)
	var c: Color
	match variant:
		"B":
			c = Color("efece4")
		"C":
			c = Color("e07a2a")
		"D":
			c = Color("2c3036")
		_:
			c = Color("c9cdd0")
	p.gradient(inner, c.lightened(0.06), c.darkened(0.04), 1.0)
	for corner: Vector2 in [inner.position + Vector2(5, 5), Vector2(inner.end.x - 5, inner.position.y + 5), Vector2(inner.position.x + 5, inner.end.y - 5), inner.end - Vector2(5, 5)]:
		p.circle(corner, 2.4, METAL, METAL_DARK, 0.2)
		p.circle(corner, 0.9, METAL_DARK)


# --- Circuit breaker --------------------------------------------------------------

## Miniature circuit breaker (jistič), [param poles] modules wide.
## "A": black lever with a red/green window, "B": grey lever, blue rating tag.
static func breaker(p: CabinetPainter, poles: int, on: bool, tripped: bool, variant: String = "A", rating: String = "C16", reach: Array = []) -> void:
	var w: float = MODULE_W * poles
	_modular_body(p, w, WHITE, WHITE_SHADE, WHITE_EDGE)
	var lever_y: float = 33.0 if on else 43.0
	for i: int in poles:
		var cx: float = MODULE_W * (i + 0.5)
		screw(p, Vector2(cx, 9.0), 2.6, reach[2 * i] if 2 * i < reach.size() else Color.TRANSPARENT)
		screw(p, Vector2(cx, 81.0), 2.6, reach[2 * i + 1] if 2 * i + 1 < reach.size() else Color.TRANSPARENT)
		p.text(Vector2(cx, 18.6), str(2 * i + 1), 2.3, PRINT)
		p.text(Vector2(cx, 75.2), str(2 * i + 2), 2.3, PRINT)
		if variant == "A":
			var window: Color = (TRIP if tripped else (Color("e0322f") if on else Color("2ea44f")))
			p.rect(Rect2(cx - 3.0, 23.6, 6.0, 3.4), HOLE, 0.5)
			p.rect(Rect2(cx - 2.4, 24.1, 4.8, 2.4), window, 0.3)
		p.rect(Rect2(cx - 4.6, 30.0, 9.2, 26.0), HOLE, 1.0)
		p.text(Vector2(cx + 6.0, 33.0), "I", 2.0, PRINT)
		p.text(Vector2(cx + 6.0, 55.0), "O", 2.0, PRINT)
	var lever_top: Color = Color("3a3d42") if variant == "A" else Color("dfe2e5")
	var lever_bottom: Color = Color("141517") if variant == "A" else Color("a5abb0")
	if poles > 1:
		# The levers are joined by a bar.
		p.rect(Rect2(MODULE_W * 0.5 - 2.0, lever_y + 4.5, w - MODULE_W + 4.0, 3.0), lever_bottom, 0.5)
	for i: int in poles:
		var cx: float = MODULE_W * (i + 0.5)
		p.gradient(Rect2(cx - 3.6, lever_y, 7.2, 12.0), lever_top, lever_bottom, 1.0, Color(0, 0, 0, 0.6), 0.15)
		for g: int in 3:
			var gy: float = lever_y + (2.0 if on else 6.5) + g * 1.3
			p.line(Vector2(cx - 2.4, gy), Vector2(cx + 2.4, gy), Color(1, 1, 1, 0.18 if variant == "A" else 0.6), 0.25)
		p.line(Vector2(cx - 3.0, lever_y + 0.6), Vector2(cx + 3.0, lever_y + 0.6), Color(1, 1, 1, 0.35), 0.25)
	if variant == "B":
		p.rect(Rect2(w * 0.5 - 6.0, 59.5, 12.0, 6.0), DIAL_BLUE, 0.6)
		p.text_centered(Vector2(w * 0.5, 62.5), rating, 3.2, Color.WHITE, true, 11.0)
		if tripped:
			p.rect(Rect2(MODULE_W * 0.5 - 2.5, 23.5, 5.0, 3.0), TRIP, 0.5)
	else:
		p.text_centered(Vector2(w * 0.5, 62.5), rating, 3.4, PRINT, true, w - 2.0)


# --- Fuse holder -------------------------------------------------------------------

## Modular fuse holder (pojistkový odpínač) with a carrier that swings down
## to open. "A": grey body, black carrier, LED shows a blown fuse.
## "B": white body, grey carrier with a window on the fuse.
static func fuse_holder(p: CabinetPainter, poles: int, closed: bool, blown: bool, variant: String = "A", rating: String = "10A", reach: Array = []) -> void:
	var w: float = MODULE_W * poles
	var body: Color = LIGHT_GREY if variant == "A" else WHITE
	var shade: Color = body.darkened(0.08)
	p.rect(Rect2(0, 0, w, MODULE_H), shade, 1.2, WHITE_EDGE.darkened(0.1), 0.2)
	var carrier: Color = Color("33373c") if variant == "A" else Color("8e959b")
	var carrier_light: Color = carrier.lightened(0.18)
	for i: int in poles:
		var x0: float = MODULE_W * i
		var cx: float = x0 + MODULE_W * 0.5
		screw(p, Vector2(cx, 9.0), 2.6, reach[2 * i] if 2 * i < reach.size() else Color.TRANSPARENT)
		screw(p, Vector2(cx, 81.0), 2.6, reach[2 * i + 1] if 2 * i + 1 < reach.size() else Color.TRANSPARENT)
		p.text(Vector2(cx, 18.6), str(2 * i + 1), 2.3, PRINT)
		p.text(Vector2(cx, 75.2), str(2 * i + 2), 2.3, PRINT)
		var cr: Rect2 = Rect2(x0 + 1.4, 21.0, MODULE_W - 2.8, 48.0)
		if closed:
			p.gradient(cr, carrier_light, carrier, 1.2, Color(0, 0, 0, 0.6), 0.15)
			# Lifting tab at the top, finger grips at the bottom.
			p.rect(Rect2(cx - 3.0, 22.0, 6.0, 2.0), carrier_light.lightened(0.15), 0.5)
			for g: int in 4:
				p.line(Vector2(x0 + 4.0, 59.0 + g * 2.0), Vector2(x0 + MODULE_W - 4.0, 59.0 + g * 2.0), Color(0, 0, 0, 0.35), 0.35)
			if variant == "B":
				p.rect(Rect2(cx - 3.2, 30.0, 6.4, 16.0), Color(0.75, 0.85, 0.9, 0.6), 0.6, Color(0, 0, 0, 0.4), 0.15)
				p.rect(Rect2(cx - 2.2, 31.5, 4.4, 13.0), Color("f2efe6"), 0.4)
				if blown:
					p.circle(Vector2(cx, 33.5), 1.3, LED_RED)
				p.text(Vector2(cx, 53.0), rating, 2.4, PRINT_LIGHT, 0, true, MODULE_W - 4.0)
			else:
				led(p, Vector2(cx, 29.0), LED_RED, blown, 1.1)
				p.text(Vector2(cx, 40.0), rating, 2.4, PRINT_LIGHT, 0, true, MODULE_W - 4.0)
				p.text(Vector2(cx, 44.5), "gG", 2.0, PRINT_LIGHT.darkened(0.25), 0, true)
		else:
			# Swung down about its bottom: the empty socket above it, the
			# carrier's top with the fuse cartridge, its front foreshortened.
			p.rect(Rect2(cr.position.x, 21.0, cr.size.x, 28.0), HOLE, 1.0)
			p.rect(Rect2(cx - 3.0, 22.5, 6.0, 2.2), METAL_DARK, 0.4)
			p.gradient(Rect2(cr.position.x, 47.0, cr.size.x, 8.0), carrier.lightened(0.3), carrier_light, 1.0, Color(0, 0, 0, 0.6), 0.15)
			p.rect(Rect2(cx - 4.0, 48.0, 8.0, 6.0), Color("f2efe6"), 1.5, Color(0, 0, 0, 0.35), 0.15)
			p.circle(Vector2(cx, 51.0), 2.3, METAL, METAL_DARK, 0.15)
			if blown:
				p.circle(Vector2(cx, 51.0), 1.1, LED_RED)
			p.gradient(Rect2(cr.position.x, 55.0, cr.size.x, 14.0), carrier_light, carrier, 1.0, Color(0, 0, 0, 0.6), 0.15)
			for g: int in 3:
				p.line(Vector2(x0 + 4.0, 60.0 + g * 2.0), Vector2(x0 + MODULE_W - 4.0, 60.0 + g * 2.0), Color(0, 0, 0, 0.35), 0.35)


# --- Contactor, relay, overload relay -------------------------------------------

## Contactor (stykač) 45 mm wide: "A" dark body with a light front, "B" light
## body, "C" modular contactor two modules wide. The window shows the
## armature: 0 dropped out, I pulled in. [param highlight] rings the window
## while the coil has power.
static func contactor(p: CabinetPainter, on: bool, variant: String = "A", top: PackedStringArray = ["A1", "1/L1", "3/L2", "5/L3", "13NO"], bottom: PackedStringArray = ["A2", "2/T1", "4/T2", "6/T3", "14NO"], highlight: bool = false, reach: Array = []) -> void:
	if variant == "C":
		_modular_contactor(p, on, highlight)
		return
	var w: float = CONTACTOR.x
	var h: float = CONTACTOR.y
	var base: Color = DARK_GREY if variant == "A" else Color("d4d8db")
	var front: Color = Color("a7adb2") if variant == "A" else Color("f3f4f5")
	var text_on_base: Color = PRINT_LIGHT if variant == "A" else PRINT
	p.gradient(Rect2(0, 0, w, h), base.lightened(0.1), base.darkened(0.08), 1.6, base.darkened(0.45), 0.2)
	var n: int = top.size()
	var pitch: float = w / n
	for j: int in n:
		var cx: float = pitch * (j + 0.5)
		screw(p, Vector2(cx, 6.5), 2.5, reach[j] if j < reach.size() else Color.TRANSPARENT)
		screw(p, Vector2(cx, h - 6.5), 2.5, reach[n + j] if n + j < reach.size() else Color.TRANSPARENT)
		p.text(Vector2(cx, 14.0), top[j], 1.9, text_on_base, 0, true, pitch - 0.6)
		p.text(Vector2(cx, h - 11.8), bottom[j], 1.9, text_on_base, 0, true, pitch - 0.6)
	var front_r: Rect2 = Rect2(3.0, 17.0, w - 6.0, h - 36.0)
	p.gradient(front_r, front.lightened(0.08), front.darkened(0.06), 1.4, base.darkened(0.3), 0.2)
	# Slot for an auxiliary contact block on the front.
	p.rect(Rect2(front_r.position.x + 3.0, front_r.position.y + 2.5, front_r.size.x - 6.0, 4.0), front.darkened(0.18), 0.6)
	var window_c: Vector2 = Vector2(w * 0.5, front_r.position.y + 15.0)
	if highlight and on:
		for i: int in 3:
			p.rect(Rect2(window_c - Vector2(8.0 + i, 5.0 + i), Vector2(16.0 + 2 * i, 10.0 + 2 * i)), Color(1.0, 0.55, 0.25, 0.25 - 0.07 * i), 2.0 + i)
	p.rect(Rect2(window_c - Vector2(6.5, 3.6), Vector2(13.0, 7.2)), HOLE, 0.8)
	var slider_x: float = 2.6 if on else -2.6
	p.rect(Rect2(window_c + Vector2(slider_x - 3.0, -2.8), Vector2(6.0, 5.6)), Color("f4f4f2") if not on else Color("ffd84a"), 0.4)
	p.text_centered(window_c + Vector2(slider_x, 0.0), "I" if on else "0", 3.2, PRINT)
	# Label holder.
	p.rect(Rect2(front_r.position.x + 4.0, front_r.end.y - 11.0, front_r.size.x - 8.0, 7.0), front.darkened(0.12), 0.5)


## Modular (installation) contactor, two modules wide.
static func _modular_contactor(p: CabinetPainter, on: bool, highlight: bool) -> void:
	var w: float = MODULE_W * 2.0
	_modular_body(p, w, WHITE, WHITE_SHADE, WHITE_EDGE)
	var top: PackedStringArray = ["A1", "1", "3", "5"]
	var bottom: PackedStringArray = ["A2", "2", "4", "6"]
	for j: int in 4:
		var cx: float = 4.5 + 9.0 * j
		screw(p, Vector2(cx, 9.0), 2.3)
		screw(p, Vector2(cx, 81.0), 2.3)
		p.text(Vector2(cx, 18.0), top[j], 2.0, PRINT, 0, true, 8.5)
		p.text(Vector2(cx, 75.6), bottom[j], 2.0, PRINT, 0, true, 8.5)
	var window_c: Vector2 = Vector2(w * 0.5, 30.0)
	if highlight and on:
		for i: int in 3:
			p.circle(window_c, 4.2 + i * 1.2, Color(1.0, 0.55, 0.25, 0.25 - 0.07 * i))
	p.circle(window_c, 3.6, HOLE)
	p.circle(window_c, 2.8, Color("e0322f") if on else Color("2ea44f"))
	p.text_centered(window_c, "I" if on else "0", 2.6, Color.WHITE)
	# Manual selector: AUTO / 0 / I.
	p.rect(Rect2(w * 0.5 - 9.0, 40.0, 18.0, 7.0), HOLE, 1.0)
	p.gradient(Rect2(w * 0.5 - 8.0, 41.0, 6.0, 5.0), Color("4a4e53"), Color("1f2124"), 0.8)
	p.text(Vector2(w * 0.5 - 5.0, 52.0), "AUTO", 1.7, PRINT)
	p.text(Vector2(w * 0.5 + 2.0, 52.0), "0", 1.7, PRINT)
	p.text(Vector2(w * 0.5 + 6.5, 52.0), "I", 1.7, PRINT)
	p.text_centered(Vector2(w * 0.5, 61.5), "25A  AC-1", 2.2, PRINT, true, w - 4.0)


## Thermal overload relay (tepelné relé) fitted under a contactor: blue
## current dial, reset (blue) and stop (red) buttons, trip window.
static func overload_relay(p: CabinetPainter, tripped: bool, variant: String = "A", setting: String = "1,6", reach: Array = []) -> void:
	var w: float = OVERLOAD.x
	var h: float = OVERLOAD.y
	var base: Color = DARK_GREY if variant == "A" else Color("d4d8db")
	var front: Color = Color("a7adb2") if variant == "A" else Color("f3f4f5")
	var text_on_base: Color = PRINT_LIGHT if variant == "A" else PRINT
	p.gradient(Rect2(0, 0, w, h), base.lightened(0.06), base.darkened(0.08), 1.6, base.darkened(0.45), 0.2)
	var aux: PackedStringArray = ["95", "96", "97", "98"]
	for j: int in 4:
		var cx: float = 23.0 + 6.2 * j
		screw(p, Vector2(cx, 5.5), 2.1)
		p.text(Vector2(cx, 12.0), aux[j], 1.8, text_on_base)
	var main: PackedStringArray = ["2/T1", "4/T2", "6/T3"]
	for j: int in 3:
		var cx: float = 9.0 + 13.5 * j
		screw(p, Vector2(cx, h - 6.5), 2.5, reach[j] if j < reach.size() else Color.TRANSPARENT)
		p.text(Vector2(cx, h - 11.8), main[j], 1.9, text_on_base)
	var front_r: Rect2 = Rect2(3.0, 15.0, w - 6.0, h - 33.0)
	p.gradient(front_r, front.lightened(0.08), front.darkened(0.06), 1.4, base.darkened(0.3), 0.2)
	# Current dial with its scale.
	var dial: Vector2 = Vector2(13.0, front_r.get_center().y)
	p.circle(dial, 7.0, Color(0, 0, 0, 0.15))
	for t: int in 7:
		var a: float = lerpf(PI * 0.8, PI * 2.2, t / 6.0)
		p.line(dial + Vector2(cos(a), sin(a)) * 7.6, dial + Vector2(cos(a), sin(a)) * 8.6, PRINT, 0.2)
	p.circle(dial, 5.8, DIAL_BLUE, DIAL_BLUE.darkened(0.4), 0.2)
	p.circle(dial + Vector2(-1.5, -1.5), 2.0, Color(1, 1, 1, 0.18))
	var pointer: float = PI * 1.55
	p.line(dial, dial + Vector2(cos(pointer), sin(pointer)) * 5.0, Color.WHITE, 0.6)
	p.text(dial + Vector2(0, 9.5), setting + " A", 1.8, PRINT)
	# Reset and stop buttons, trip window.
	var reset_c: Vector2 = Vector2(29.0, front_r.position.y + 7.0)
	var stop_c: Vector2 = Vector2(37.5, front_r.position.y + 7.0)
	var popped: float = 0.6 if tripped else 0.0
	p.circle(reset_c + Vector2(0.4, 0.6), 3.4 + popped, Color(0, 0, 0, 0.3))
	p.circle(reset_c, 3.2 + popped, DIAL_BLUE.lightened(0.15 if tripped else 0.0), DIAL_BLUE.darkened(0.4), 0.2)
	p.text_centered(reset_c, "R", 2.6, Color.WHITE)
	p.circle(stop_c, 3.2, STOP_RED, STOP_RED.darkened(0.4), 0.2)
	p.text_centered(stop_c, "S", 2.4, Color.WHITE)
	var window: Rect2 = Rect2(26.0, front_r.position.y + 13.5, 15.0, 4.6)
	p.rect(window, HOLE, 0.6)
	p.rect(window.grow(-0.7), TRIP if tripped else Color("2ea44f"), 0.4)
	p.text_centered(window.get_center(), "TRIP" if tripped else "", 2.0, PRINT)


## Auxiliary relay: "A" plug-in relay in a socket (clear cover, coil and
## LED inside), "B" control relay shaped like a contactor.
static func relay(p: CabinetPainter, on: bool, variant: String = "A", highlight: bool = false) -> void:
	if variant == "B":
		contactor(p, on, "A", ["A1", "13", "21", "33", "43"], ["A2", "14", "22", "34", "44"], highlight)
		return
	var w: float = RELAY.x
	var h: float = RELAY.y
	var socket: Color = Color("3b3f44")
	p.gradient(Rect2(0, 0, w, h), socket.lightened(0.08), socket.darkened(0.1), 1.4, socket.darkened(0.5), 0.2)
	var top: PackedStringArray = ["12", "14", "22", "24"]
	var bottom: PackedStringArray = ["11", "21", "A1", "A2"]
	for j: int in 4:
		var cx: float = 3.9 + 6.4 * j
		screw(p, Vector2(cx, 5.5), 2.2)
		screw(p, Vector2(cx, h - 5.5), 2.2)
		p.text(Vector2(cx, 11.8), top[j], 1.8, PRINT_LIGHT)
		p.text(Vector2(cx, h - 9.8), bottom[j], 1.8, PRINT_LIGHT)
	# The relay: a clear cover with the coil, the armature and the contacts in it.
	var cover: Rect2 = Rect2(3.0, 16.0, w - 6.0, 42.0)
	if highlight and on:
		for i: int in 3:
			p.rect(cover.grow(1.0 + i), Color(1.0, 0.55, 0.25, 0.22 - 0.06 * i), 2.0 + i)
	p.rect(cover, Color("d8e3e8"), 1.2, Color("8aa0aa"), 0.2)
	p.rect(Rect2(cover.position.x + 2.0, cover.position.y + 16.0, 8.0, 18.0), Color("b8733d"), 1.0, Color("7a4a25"), 0.15)
	for g: int in 6:
		p.line(Vector2(cover.position.x + 2.5, cover.position.y + 18.0 + g * 2.6), Vector2(cover.position.x + 9.5, cover.position.y + 18.0 + g * 2.6), Color(0, 0, 0, 0.2), 0.2)
	var arm_y: float = cover.position.y + (13.0 if on else 11.5)
	p.rect(Rect2(cover.position.x + 1.5, arm_y, 12.0, 1.4), Color("8f969c"))
	for c: int in 2:
		var x: float = cover.position.x + 12.5 + c * 3.0
		p.rect(Rect2(x, cover.position.y + 6.0, 1.6, 26.0), Color("d9b45a"), 0.3)
	led(p, Vector2(cover.end.x - 3.0, cover.position.y + 4.0), LED_RED, on, 1.0)
	# Test button with the mechanical flag.
	p.rect(Rect2(cover.end.x - 5.5, cover.end.y - 6.0, 4.0, 4.0), Color("f39200") if on else Color("c9b49a"), 0.6)
	# Retaining clip.
	p.rect(Rect2(w * 0.5 - 6.0, cover.end.y + 0.5, 12.0, 2.0), Color("23262a"), 0.6)


# --- Time relay -------------------------------------------------------------------

## Multifunction time relay (časové relé), one module wide: LEDs U (power)
## and R (output). "A" with dials, "B" with a display counting down.
## [param state]: 0 no power, 1 timing, 2 output on.
static func timer(p: CabinetPainter, state: int, variant: String = "A", function: String = "F1", remaining: String = "2,4s") -> void:
	var w: float = MODULE_W
	_modular_body(p, w, WHITE, WHITE_SHADE, WHITE_EDGE)
	var top: PackedStringArray = ["A1", "S", "A2"]
	var bottom: PackedStringArray = ["15", "16", "18"]
	for j: int in 3:
		var cx: float = 3.6 + 5.4 * j
		screw(p, Vector2(cx, 8.0), 2.0)
		screw(p, Vector2(cx, 82.0), 2.0)
		p.text(Vector2(cx, 15.5), top[j], 1.8, PRINT)
		p.text(Vector2(cx, 77.0), bottom[j], 1.8, PRINT)
	led(p, Vector2(5.0, 25.0), LED_GREEN, state >= 1, 1.0)
	led(p, Vector2(13.0, 25.0), LED_YELLOW, state == 2, 1.0)
	p.text(Vector2(5.0, 30.0), "U", 1.8, PRINT)
	p.text(Vector2(13.0, 30.0), "R", 1.8, PRINT)
	if variant == "B":
		var lcd: Rect2 = Rect2(2.2, 33.0, w - 4.4, 13.0)
		p.rect(lcd.grow(0.6), HOLE, 0.8)
		var lit: bool = state >= 1
		p.rect(lcd, Color("b7c9a0") if lit else Color("7f8a74"), 0.4)
		if lit:
			p.text(Vector2(lcd.position.x + 1.0, lcd.position.y + 4.0), function, 2.0, Color("1d2a16"), -1)
			p.text(Vector2(lcd.end.x - 0.8, lcd.end.y - 1.6), remaining if state == 1 else "0,0s", 3.0, Color("1d2a16"), 1, true, lcd.size.x - 1.0)
		for b: int in 2:
			var bc: Vector2 = Vector2(5.5 + 7.0 * b, 52.0)
			p.circle(bc, 2.2, Color("5b6066"), Color("2a2d30"), 0.2)
		p.text(Vector2(5.5, 58.0), "SET", 1.6, PRINT)
		p.text(Vector2(12.5, 58.0), "F", 1.6, PRINT)
	else:
		for d: int in 3:
			var c: Vector2 = Vector2(w * 0.5, 37.5 + d * 10.0)
			var r: float = 3.3 if d < 2 else 3.8
			for t: int in 9:
				var a: float = lerpf(PI * 0.75, PI * 2.25, t / 8.0)
				p.line(c + Vector2(cos(a), sin(a)) * (r + 0.6), c + Vector2(cos(a), sin(a)) * (r + 1.4), PRINT, 0.18)
			p.circle(c, r, Color("6c7177") if d < 2 else Color("2f6fd4"), Color("2a2d30"), 0.2)
			var a2: float = [PI * 1.1, PI * 1.6, PI * 1.9][d]
			p.line(c, c + Vector2(cos(a2), sin(a2)) * (r - 0.5), Color.WHITE, 0.5)
	p.text(Vector2(w * 0.5, 67.0), function, 2.6, PRINT)


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


const TERMINAL_GREY := Color("b4b9bd")
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
		var entry: Vector2 = Vector2(cx, at.call(3.4))
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
	screw(p, Vector2(x + w * 0.5, TERMINAL.y * 0.5 + 9.0), 1.6)
	if not group.is_empty():
		var tag: Rect2 = Rect2(x + p.snap(1.2), TERMINAL.y * 0.5 - 8.0, w - p.snap(2.4), 9.0)
		p.rect(tag, Color("fbfbf8"), 0.3, Color(0, 0, 0, 0.25), 0.0)
		p.text_centered(tag.get_center(), group, 2.6, Color("111111"), true, w - 2.6)
