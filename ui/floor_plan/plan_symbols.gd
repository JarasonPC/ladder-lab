class_name PlanSymbols
extends RefCounted
## Symbols of the floor plan, as Czech installation drawings use them (ČSN
## EN 60617-11), drawn on any CanvasItem in its pixels: [param s] pixels a
## metre, the part at [param at], facing [param facing] into its room (a
## unit vector away from its wall; Vector2.ZERO on the ceiling). No nodes.
##
## Switch: a small circle with a line per contact into the room, ticks at
## its end (one a pole: 1, 2, 3, 4 ticks for switch 1, 2, 3, 03); a two-way
## rocker has a second line the other way (6; two ticks each for 6/2, a dot
## in the circle for 4 with its off position), two rockers two lines fanned
## out (5); the intermediate switch's lines cross (7). Socket: a half circle open
## to the room on a stem from the wall, its diameter drawn past it for the
## protective pin; a double socket two of them. Luminaire: a circle with a
## cross. Appliance: a square with its sign on a stem from the wall.
## Consumer unit: an oblong on the wall, half filled.

## Sizes in metres.
const SWITCH_RADIUS: float = 0.06
const SWITCH_LINE: float = 0.24
const TICK: float = 0.07
const SOCKET_RADIUS: float = 0.1
const LAMP_RADIUS: float = 0.12
const APPLIANCE: float = 0.34
const UNIT := Vector2(0.6, 0.22)
## Colour of a lit luminaire's glow and of a working appliance.
const GLOW := Color(1.0, 0.86, 0.35, 0.55)


## Light switch [param sw].
static func draw_switch(item: CanvasItem, sw: LightSwitch, at: Vector2, facing: Vector2, s: float, color: Color, width: float) -> void:
	var into: Vector2 = facing if facing != Vector2.ZERO else Vector2.DOWN
	# The circle a little off the wall, the lines slanting into the room.
	var c: Vector2 = at + into * SWITCH_RADIUS * s
	item.draw_arc(c, SWITCH_RADIUS * s, 0.0, TAU, 20, color, width, true)
	var main: Vector2 = into.rotated(-PI / 4.0)
	match sw.circuit:
		"2":
			_line(item, c, main, 2, s, color, width)
		"3":
			_line(item, c, main, 3, s, color, width)
		"5":
			_line(item, c, main, 1, s, color, width)
			_line(item, c, into.rotated(PI / 12.0), 1, s, color, width)
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
			_line(item, c, into.rotated(PI / 12.0), 1, s, color, width)
			_line(item, c, -into.rotated(PI / 12.0), 1, s, color, width)
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
	var across: Vector2 = into.rotated(PI / 2.0)
	var r: float = SOCKET_RADIUS * s
	var offsets: PackedFloat32Array = PackedFloat32Array([0.0]) if socket.gangs == 1 else PackedFloat32Array([-r * 1.05, r * 1.05])
	for o: float in offsets:
		var base: Vector2 = at + across * o + into * 0.1 * s
		item.draw_line(at + across * o, base, color, width, true)
		# The diameter past the half circle: the protective pin.
		item.draw_line(base - across * r * 1.25, base + across * r * 1.25, color, width, true)
		var angle: float = into.angle()
		if live:
			var fill: PackedVector2Array = PackedVector2Array([base])
			for k: int in 13:
				fill.append(base + Vector2.from_angle(angle - PI / 2.0 + PI * k / 12.0) * r)
			item.draw_colored_polygon(fill, GLOW)
		item.draw_arc(base, r, angle - PI / 2.0, angle + PI / 2.0, 16, color, width, true)


## Luminaire; [param lit]: it lights.
static func draw_luminaire(item: CanvasItem, at: Vector2, s: float, color: Color, width: float, lit: bool) -> void:
	var r: float = LAMP_RADIUS * s
	if lit:
		for k: int in 4:
			item.draw_circle(at, r * (4.5 - k), Color(GLOW, 0.12 + 0.08 * k))
		item.draw_circle(at, r, Color(1.0, 0.95, 0.7))
	item.draw_arc(at, r, 0.0, TAU, 24, color, width, true)
	var d: float = r * 0.7071
	item.draw_line(at + Vector2(-d, -d), at + Vector2(d, d), color, width, true)
	item.draw_line(at + Vector2(-d, d), at + Vector2(d, -d), color, width, true)


## Appliance [param appliance] on a stem from its wall; [param working]: it
## draws its power.
static func draw_appliance(item: CanvasItem, appliance: Appliance, at: Vector2, facing: Vector2, s: float, color: Color, width: float, working: bool) -> void:
	var into: Vector2 = facing if facing != Vector2.ZERO else Vector2.DOWN
	var half: float = APPLIANCE * 0.5 * s
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


## The consumer unit on its wall.
static func draw_unit(item: CanvasItem, at: Vector2, facing: Vector2, s: float, color: Color, width: float) -> void:
	var into: Vector2 = facing if facing != Vector2.ZERO else Vector2.DOWN
	var along: Vector2 = into.rotated(PI / 2.0)
	var a: Vector2 = at - along * UNIT.x * 0.5 * s
	var b: Vector2 = at + along * UNIT.x * 0.5 * s
	var depth: Vector2 = into * UNIT.y * s
	var outline: PackedVector2Array = PackedVector2Array([a, b, b + depth, a + depth, a])
	item.draw_colored_polygon(PackedVector2Array([a, b, a + depth]), color)
	item.draw_polyline(outline, color, width, true)
