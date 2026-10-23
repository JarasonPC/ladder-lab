class_name PlanSymbols
extends RefCounted
## Symbols of the floor plan, as Czech installation drawings use them (ČSN
## EN 60617-11), drawn on any CanvasItem in its pixels: [param s] pixels a
## metre, the part at [param at], facing [param facing] into its room (a
## unit vector away from its wall; Vector2.ZERO on the ceiling). No nodes.
##
## Switch: a small circle with a line per contact slanting up to the right
## as in the legends of ČSN EN 60617-11 (drawn upright), ticks at its end (one a pole: 1, 2, 3, 4 ticks for switch 1, 2, 3, 03); a two-way
## rocker has a second line the other way (6; two ticks each for 6/2, a dot
## in the circle for 4 with its off position), two rockers two lines fanned
## out (5); the intermediate switch's lines cross (7). Socket: a stem from the
## wall to the back of a half circle open to the room; a double socket a
## second half circle on the same stem, just inside the first. Luminaire: a circle with a
## cross. Appliance: a square with its sign on a stem from the wall; an
## outlet for a later connection (vývod) the stem going on to an arrow.
## Consumer unit: a box on the wall with a second one inside it.

## Sizes in metres.
const SWITCH_RADIUS: float = 0.06
const SWITCH_LINE: float = 0.24
const TICK: float = 0.07
const SOCKET_RADIUS: float = 0.1
## Socket: the stem from the wall, and the second half circle of a double
## socket further in.
const SOCKET_STEM: float = 0.1
const SOCKET_GANG: float = 0.07
const LAMP_RADIUS: float = 0.12
## A wall luminaire's cross this far into the room from its wall (m).
const WALL_LAMP_OFFSET: float = 0.15
const APPLIANCE: float = 0.34
const UNIT := Vector2(0.6, 0.22)
## The inner box of the consumer unit, this far inside the outer one (m).
const UNIT_INSET: float = 0.05
## Colour of a lit luminaire's glow and of a working appliance.
const GLOW := Color(1.0, 0.86, 0.35, 0.55)


## Light switch [param sw].
static func draw_switch(item: CanvasItem, sw: LightSwitch, at: Vector2, facing: Vector2, s: float, color: Color, width: float) -> void:
	var into: Vector2 = facing if facing != Vector2.ZERO else Vector2.DOWN
	# The circle a little off the wall, the lines slanting into the room.
	var c: Vector2 = at + into * SWITCH_RADIUS * s
	item.draw_arc(c, SWITCH_RADIUS * s, 0.0, TAU, 20, color, width, true)
	# Up, as the legends draw it: a quarter turn back from into the room.
	var up: Vector2 = into.rotated(-PI / 2.0)
	var main: Vector2 = up.rotated(-PI / 4.0)
	match sw.circuit:
		"2":
			_line(item, c, main, 2, s, color, width)
		"3":
			_line(item, c, main, 3, s, color, width)
		"5":
			_line(item, c, main, 1, s, color, width)
			_line(item, c, up.rotated(PI / 12.0), 1, s, color, width)
		"6":
			_line(item, c, main, 1, s, color, width)
			_line(item, c, -main, 1, s, color, width)
		"03":
			_line(item, c, main, 4, s, color, width)
		"4":
			# Two-way with an off position: the two-way lines, a dot for off.
			_line(item, c, main, 1, s, color, width)
			_line(item, c, -main, 1, s, color, width)
			item.draw_circle(c, SWITCH_RADIUS * s * 0.35, color)
		"6/2":
			_line(item, c, main, 2, s, color, width)
			_line(item, c, -main, 2, s, color, width)
		"5B":
			_line(item, c, main, 1, s, color, width)
			_line(item, c, -main, 1, s, color, width)
			_line(item, c, up.rotated(PI / 12.0), 1, s, color, width)
			_line(item, c, -up.rotated(PI / 12.0), 1, s, color, width)
		"7":
			_line(item, c, main, 1, s, color, width)
			_line(item, c, -main, 1, s, color, width)
			_line(item, c, main.rotated(PI / 2.0), 1, s, color, width)
			_line(item, c, -main.rotated(PI / 2.0), 1, s, color, width)
		_:
			_line(item, c, main, 1, s, color, width)


## A switch's line from the circle at [param c] along [param dir], with
## [param ticks] ticks at its end.
static func _line(item: CanvasItem, c: Vector2, dir: Vector2, ticks: int, s: float, color: Color, width: float) -> void:
	var start: Vector2 = c + dir * SWITCH_RADIUS * s
	var end: Vector2 = c + dir * (SWITCH_RADIUS + SWITCH_LINE) * s
	item.draw_line(start, end, color, width, true)
	var across: Vector2 = dir.rotated(PI / 2.0)
	for t: int in ticks:
		var foot: Vector2 = end - dir * t * TICK * 0.55 * s
		item.draw_line(foot, foot + across * TICK * s, color, width, true)


## Socket outlet [param socket]; [param live]: it has its voltage.
static func draw_socket(item: CanvasItem, socket: SocketOutlet, at: Vector2, facing: Vector2, s: float, color: Color, width: float, live: bool) -> void:
	var into: Vector2 = facing if facing != Vector2.ZERO else Vector2.DOWN
	var r: float = SOCKET_RADIUS * s
	var back: Vector2 = at + into * SOCKET_STEM * s
	item.draw_line(at, back, color, width, true)
	var angle: float = into.angle()
	for gang: int in socket.gangs:
		# The half circle's back on the stem, open to the room.
		var c: Vector2 = back + into * (r + gang * SOCKET_GANG * s)
		if live and gang == 0:
			var fill: PackedVector2Array = PackedVector2Array()
			for k: int in 13:
				fill.append(c + Vector2.from_angle(angle + PI / 2.0 + PI * k / 12.0) * r)
			item.draw_colored_polygon(fill, GLOW)
		item.draw_arc(c, r, angle + PI / 2.0, angle + PI * 1.5, 16, color, width, true)


## Luminaire; [param lit]: it lights.
## A luminaire, as Czech installation plans draw it: a cross, on the ceiling
## at [param at]; a wall luminaire ([param facing] into the room from its
## wall at [param at]) with a line on its wall's side. [param lit]: it glows.
static func draw_luminaire(item: CanvasItem, at: Vector2, s: float, color: Color, width: float, lit: bool, facing: Vector2 = Vector2.ZERO) -> void:
	var r: float = LAMP_RADIUS * s
	var c: Vector2 = at + facing * WALL_LAMP_OFFSET * s
	if lit:
		for k: int in 4:
			item.draw_circle(c, r * (4.5 - k), Color(GLOW, 0.12 + 0.08 * k))
		item.draw_circle(c, r * 0.8, Color(1.0, 0.95, 0.7))
	var d: float = r * 0.7071
	item.draw_line(c + Vector2(-d, -d), c + Vector2(d, d), color, width, true)
	item.draw_line(c + Vector2(-d, d), c + Vector2(d, -d), color, width, true)
	if facing != Vector2.ZERO:
		# The line on the wall's side, across the cross's width.
		var side: Vector2 = facing.orthogonal() * d
		var back: Vector2 = c - facing * d
		item.draw_line(back - side, back + side, color, width, true)
		item.draw_line(at, back, color, width, true)


## Appliance [param appliance] on a stem from its wall; [param working]: it
## draws its power.
static func draw_appliance(item: CanvasItem, appliance: Appliance, at: Vector2, facing: Vector2, s: float, color: Color, width: float, working: bool) -> void:
	var into: Vector2 = facing if facing != Vector2.ZERO else Vector2.DOWN
	var half: float = APPLIANCE * 0.5 * s
	if appliance.kind == Appliance.Kind.OUTLET:
		# The stem on to an arrow: the cable goes on from here.
		var tip: Vector2 = at + into * APPLIANCE * s
		item.draw_line(at, tip, color, width, true)
		var side: Vector2 = into.orthogonal() * half * 0.5
		item.draw_colored_polygon(PackedVector2Array([tip, tip - into * half * 0.7 + side, tip - into * half * 0.7 - side]), GLOW if working else color)
		return
	var c: Vector2 = at + into * (0.08 * s + half)
	item.draw_line(at, c - into * half, color, width, true)
	var box: Rect2 = Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0)
	item.draw_rect(box, GLOW if working else SchematicTheme.BACKGROUND)
	item.draw_rect(box, color, false, width)
	_sign(item, appliance.kind, c, half * 0.6, color, width)


static func _sign(item: CanvasItem, kind: Appliance.Kind, c: Vector2, r: float, color: Color, width: float) -> void:
	match kind:
		Appliance.Kind.MICROWAVE:
			for k: int in 3:
				var wave: PackedVector2Array = PackedVector2Array()
				for i: int in 9:
					wave.append(c + Vector2(-r + r * 0.25 * i, -r * 0.6 + r * 0.6 * k + sin(i * PI / 2.0) * r * 0.2))
				item.draw_polyline(wave, color, width, true)
		Appliance.Kind.WASHING_MACHINE, Appliance.Kind.DISHWASHER:
			item.draw_arc(c, r, 0.0, TAU, 20, color, width, true)
			item.draw_arc(c, r * 0.4, 0.0, TAU, 12, color, width, true)
		Appliance.Kind.FRIDGE:
			for k: int in 3:
				var d: Vector2 = Vector2.from_angle(k * PI / 3.0) * r
				item.draw_line(c - d, c + d, color, width, true)
		_:
			var zig: PackedVector2Array = PackedVector2Array([c + Vector2(-r, 0)])
			for i: int in 6:
				zig.append(c + Vector2(-r * 0.8 + r * 0.32 * i, -r * 0.45 if i % 2 == 0 else r * 0.45))
			zig.append(c + Vector2(r, 0))
			item.draw_polyline(zig, color, width, true)


## The consumer unit on its wall: a box with a second one inside it.
static func draw_unit(item: CanvasItem, at: Vector2, facing: Vector2, s: float, color: Color, width: float) -> void:
	var into: Vector2 = facing if facing != Vector2.ZERO else Vector2.DOWN
	var along: Vector2 = into.rotated(PI / 2.0)
	for inset: float in [0.0, UNIT_INSET]:
		var a: Vector2 = at + along * (UNIT.x * 0.5 - inset) * s + into * inset * s
		var b: Vector2 = at - along * (UNIT.x * 0.5 - inset) * s + into * inset * s
		var depth: Vector2 = into * (UNIT.y - 2.0 * inset) * s
		item.draw_polyline(PackedVector2Array([a, b, b + depth, a + depth, a]), color, width, true)


## Furniture or a fixture of [param kind] (see [constant FloorPlan.FIXTURES])
## over screen rectangle [param rect], facing [param into] from its back:
## its outline and what tells it apart (a bath's tub, a shower's cross, a
## basin's bowl, a WC's cistern and bowl, a bed's pillows, a sofa's back and
## arms, a wardrobe's diagonal, a worktop's front edge).
static func draw_fixture(item: CanvasItem, kind: String, rect: Rect2, into: Vector2, color: Color, width: float) -> void:
	var along: Vector2 = into.orthogonal().abs()
	var w: float = absf(rect.size.dot(along))
	var d: float = absf(rect.size.dot(into))
	var back: Vector2 = rect.get_center() - into * d * 0.5
	# A point u across (from the middle), v out from the back.
	var at: Callable = func(u: float, v: float) -> Vector2: return back + along * u + into * v
	var box: Callable = func(u0: float, v0: float, u1: float, v1: float) -> void:
		item.draw_polyline(PackedVector2Array([at.call(u0, v0), at.call(u1, v0), at.call(u1, v1), at.call(u0, v1), at.call(u0, v0)]), color, width, true)
	var oval: Callable = func(cu: float, cv: float, ru: float, rv: float) -> void:
		var points: PackedVector2Array = PackedVector2Array()
		for k: int in 25:
			var t: float = TAU * k / 24.0
			points.append(at.call(cu + cos(t) * ru, cv + sin(t) * rv))
		item.draw_polyline(points, color, width, true)
	box.call(-w * 0.5, 0.0, w * 0.5, d)
	match kind:
		"worktop":
			item.draw_line(at.call(-w * 0.5, d * 0.85), at.call(w * 0.5, d * 0.85), color, width, true)
		"bath":
			box.call(-w * 0.5 + d * 0.1, d * 0.1, w * 0.5 - d * 0.1, d * 0.9)
			item.draw_arc(at.call(-w * 0.5 + d * 0.25, d * 0.5), d * 0.06, 0.0, TAU, 12, color, width, true)
		"shower":
			item.draw_line(at.call(-w * 0.5, 0.0), at.call(w * 0.5, d), color, width, true)
			item.draw_line(at.call(w * 0.5, 0.0), at.call(-w * 0.5, d), color, width, true)
		"basin":
			oval.call(0.0, d * 0.55, w * 0.38, d * 0.33)
		"wc":
			box.call(-w * 0.45, 0.0, w * 0.45, d * 0.25)
			oval.call(0.0, d * 0.6, w * 0.38, d * 0.36)
		"bed":
			var pillows: int = 2 if w > d * 0.6 else 1
			var pw: float = w / pillows
			for k: int in pillows:
				box.call(-w * 0.5 + pw * k + pw * 0.12, d * 0.05, -w * 0.5 + pw * (k + 1) - pw * 0.12, d * 0.2)
			item.draw_line(at.call(-w * 0.5, d * 0.3), at.call(w * 0.5, d * 0.3), color, width, true)
		"wardrobe":
			item.draw_line(at.call(-w * 0.5, 0.0), at.call(w * 0.5, d), color, width, true)
		"sofa":
			box.call(-w * 0.5, 0.0, w * 0.5, d * 0.25)
			box.call(-w * 0.5, 0.0, -w * 0.5 + d * 0.2, d)
			box.call(w * 0.5 - d * 0.2, 0.0, w * 0.5, d)
