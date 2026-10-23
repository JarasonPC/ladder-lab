class_name TrainingPick
extends RefCounted
## Picking and marking for wiring a training plan (see [TrainingPlan]) in a
## switchboard, on the back of its door or in a control station: the port
## under the mouse, the wire under it, and the marks drawn over the drawing
## (every port a small ring, filled once a wire lands on it, the one under
## the mouse and the one a wire starts at larger, a wire on its way to the
## mouse dashed, the wire picked in the accent colour, the ports a check
## found wrong in the fault colour).
## Positions in mm of the drawing; drawn at [param k] pixels a mm from
## [param origin]. No nodes.

## Ports the last check found wrong ("place|port", see [TrainingCheck]),
## ringed in every view of the training plan until the next check.
static var marked: PackedStringArray = PackedStringArray()
## The multimeter is in use while simulating: a click on a port puts a
## probe on it (see [Multimeter]); [member ohms] measures resistance.
static var probing: bool = false
static var ohms: bool = false
## Where the probes are ("place|port", "" for none): the red one, the black one.
static var probes: PackedStringArray = PackedStringArray(["", ""])
## The probe the next click puts down (0 red, 1 black).
static var next_probe: int = 0
## Colours of the probes' tips.
const PROBE_COLORS: Array[Color] = [Color(0.86, 0.13, 0.13), Color(0.08, 0.08, 0.08)]

## How far from a port (mm, and at least pixels) a click takes it.
const REACH_MM: float = 2.6
const REACH_PX: float = 9.0
## A port's ring (mm) at rest and marked.
const RING: float = 1.1
const RING_MARKED: float = 2.4


## The port of [param ports] (port -> mm) nearest [param at] (mm) within
## reach, "" for none.
static func port_at(ports: Dictionary[String, Vector2], at: Vector2, k: float) -> String:
	var reach: float = maxf(REACH_MM, REACH_PX / maxf(k, 0.01))
	var best: String = ""
	var nearest: float = reach
	for port: String in ports:
		var d: float = ports[port].distance_to(at)
		if d <= nearest:
			nearest = d
			best = port
	return best


## Index of the wire of [param wires] ({"points" in mm}) passing within
## reach of [param at] (mm), -1 for none.
static func wire_at(wires: Array[Dictionary], at: Vector2, k: float) -> int:
	var reach: float = maxf(1.2, 6.0 / maxf(k, 0.01))
	var best: int = -1
	var nearest: float = reach
	for w: int in wires.size():
		var points: PackedVector2Array = wires[w]["points"]
		for i: int in points.size() - 1:
			var d: float = at.distance_to(Geometry2D.get_closest_point_to_segment(at, points[i], points[i + 1]))
			if d <= nearest:
				nearest = d
				best = w
	return best


## Draws the marks on [param canvas]: [param state] {"hover", "start" (ports),
## "selected" (wire index, -1 none), "problems", "wired" (ports, see
## [method wired]), "mouse" (pixels,
## where a wire being drawn reaches), "probes" (the ports of the red and the
## black probe)}.
static func draw(canvas: CanvasItem, origin: Vector2, k: float, ports: Dictionary[String, Vector2], wires: Array[Dictionary], state: Dictionary) -> void:
	var px: Callable = func(mm: Vector2) -> Vector2: return origin + mm * k
	var accent: Color = AppTheme.accent
	var selected: int = state.get("selected", -1)
	if selected >= 0 and selected < wires.size():
		var points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in wires[selected]["points"]:
			points.append(px.call(point))
		canvas.draw_polyline(points, Color(accent, 0.85), maxf(3.0, 1.2 * k), true)
	var ring: float = maxf(RING * k, 2.5)
	for port: String in ports:
		canvas.draw_arc(px.call(ports[port]), ring, 0.0, TAU, 12, Color(accent, 0.55), 1.0, true)
	for port: String in state.get("wired", PackedStringArray()):
		if ports.has(port):
			canvas.draw_circle(px.call(ports[port]), ring, Color(accent, 0.8), true, -1.0, true)
	for port: String in state.get("problems", PackedStringArray()):
		if ports.has(port):
			canvas.draw_arc(px.call(ports[port]), maxf(RING_MARKED * k, 6.0), 0.0, TAU, 20, SchematicTheme.FAULT, 2.0, true)
	for key: String in ["hover", "start"]:
		var port: String = state.get(key, "")
		if ports.has(port):
			canvas.draw_arc(px.call(ports[port]), maxf(RING_MARKED * k, 6.0), 0.0, TAU, 20, accent, 2.5 if key == "start" else 1.5, true)
	# Each core's number in its cable (a supply core's conductor) beside its end.
	var font: Font = AppTheme.schematic_font()
	var size: int = clampi(roundi(1.8 * k), 9, 16)
	for port: String in ports:
		var label: String = core_label(port)
		if label.is_empty():
			continue
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at: Vector2 = px.call(ports[port]) + Vector2(-w * 0.5, -ring - 3.0)
		canvas.draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.75))
		canvas.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
	var start: String = state.get("start", "")
	if ports.has(start) and state.has("mouse"):
		canvas.draw_dashed_line(px.call(ports[start]), state["mouse"], accent, 2.0, 6.0)
	# The multimeter's probes: a red and a black tip with a white rim.
	var tips: PackedStringArray = state.get("probes", PackedStringArray())
	for i: int in tips.size():
		if ports.has(tips[i]):
			var at: Vector2 = px.call(ports[tips[i]])
			var r: float = maxf(1.4 * k, 5.0)
			canvas.draw_circle(at, r + 1.5, Color.WHITE)
			canvas.draw_circle(at, r, PROBE_COLORS[i])


## The ports a wire of [param wires] (the student's wires of a place, see
## [method TrainingPlan.wires_of]) lands on.
static func wired(wires: Array[PackedStringArray]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for wire: PackedStringArray in wires:
		for port: String in wire.slice(0, 2):
			if not result.has(port):
				result.append(port)
	return result


## Puts the next probe on port [param id] ("place|port"), the other one next.
static func put_probe(id: String) -> void:
	probes[next_probe] = id
	next_probe = 1 - next_probe


## Takes both probes off.
static func clear_probes() -> void:
	probes = PackedStringArray(["", ""])
	next_probe = 0


## The ports of [member probes] in [param place]: [red, black], "" for one
## elsewhere or not put down.
static func probes_in(place: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray(["", ""])
	for i: int in 2:
		if probes[i].begins_with(place + "|"):
			result[i] = probes[i].substr(place.length() + 1)
	return result


## The ports of [member marked] in [param place].
static func marked_in(place: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for id: String in marked:
		if id.begins_with(place + "|"):
			result.append(id.substr(place.length() + 1))
	return result


## Port [param port] (see [TrainingCheck]) as shown: "-KM1:13", "-X2-4",
## "-X2-4 (field side)", "W2/3", "supply +", ...
static func port_text(port: String) -> String:
	var rest: String = port.substr(2)
	match port.left(2):
		"t:":
			return "-" + rest
		"s:":
			return "-" + CabinetDevices.terminal_text(rest)
		"f:":
			return "-" + CabinetDevices.terminal_text(rest) + " " + TranslationServer.translate("(field side)")
		"b:":
			return TranslationServer.translate("N distribution block") if rest == "N" else TranslationServer.translate("PE distribution block")
		"p:":
			return TranslationServer.translate("supply") + " " + core_label(port)
		"c:":
			var colon: int = rest.rfind(":")
			var cable: String = rest.left(colon)
			var core: int = int(rest.substr(colon + 1)) + 1
			if cable == CabinetWiring.DOOR:
				return TranslationServer.translate("door harness") + " /%d" % core
			return "%s/%d" % [cable, core]
	return port


## What is written beside the end of a core (port [param port]): its number
## in its cable, a supply core's conductor ("L1", "N", "+24 V"); "" for a
## port that is no core.
static func core_label(port: String) -> String:
	if port.begins_with("c:"):
		return str(int(port.substr(port.rfind(":") + 1)) + 1)
	if port.begins_with("p:"):
		var key: String = port.substr(2)
		var supply: PowerSupply = PowerSupply.new("", int(key.get_slice("@", 0)) as PowerSupply.Conductor)
		if key.contains("@"):
			supply.voltage = float(key.get_slice("@", 1))
		return TrainingCheck.supply_name(supply)
	return ""
