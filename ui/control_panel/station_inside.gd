class_name StationInside
extends RefCounted
## The inside of a control station ([ControlBox]) with its cover off, in
## millimetres: behind each push button or switch its contact blocks clipped
## side by side on the mounting adapter (NO, NC, CO; a lamp block between
## them in an illuminated one), behind a signal lamp its lamp block, behind a
## rotary cam switch its chambers, one a pole; every block with its screw
## terminals at the top and the bottom. The cables of the workspace (see
## [WorkspaceCables]) come in through glands in the top of the housing, a
## core of each to the terminal it lands on; terminals of one net are joined
## by short wires from terminal to terminal. Wires run in lanes of the
## channels above and below each row of devices and down the left side,
## coloured by conductor ([method CabinetDevices.conductors]), each with its
## wire number on a marker sleeve at its ends. Laid out by [method build];
## drawn by [StationInsideView]. No nodes.

## Room between the housing's edge and the items, the left side keeping
## room for the wires going down it too; the top above the first channel
## (the glands).
const FRAME: float = 8.0
const TOP: float = 16.0
## Room an item takes (without the channels between the rows).
const CELL := Vector2(76.0, 50.0)
## A contact block: its width (a changeover block, a cam switch's chamber
## wider), height, its screws from its middle.
const BLOCK := Vector2(10.0, 36.0)
const CO_BLOCK: float = 16.0
const CHAMBER: float = 13.0
const SCREW_Y: float = 12.0
## Size of the opening of a terminal's clamp in the block's face, where its
## wire goes in under the screw.
const OPENING := Vector2(3.6, 2.8)
## Lanes of wires in the channels and down the side.
const LANE: float = 2.4
## Least height of a channel between rows.
const CHANNEL: float = 9.0
## Room between the cores where they come in.
const CORE: float = 2.4
const WIRE_W: float = 1.6

## Size of the housing's inside (mm).
var size: Vector2 = Vector2.ZERO
## The items: {"item" (index in the station), "kind" ([enum ControlBoxItem.Kind]),
## "designation", "lamp", "cam" (a rotary cam switch), "rect", "center",
## "blocks": [{"kind" ("NO", "NC", "CO", "LAMP", "POLE"), "rect",
## "terminals": [{"name", "key", "at" (its screw), "entry" (where its wire
## goes in: the opening of its clamp in the block's top or bottom face, under
## the screw), "top"}]}]}.
var items: Array[Dictionary] = []
## Glands in the top: {"rect", "cable" (its name)}.
var glands: Array[Dictionary] = []
## Wires: {"net", "conductor", "points", "external" (a core starting at a
## gland), "mark", "markers" (sleeves as PackedVector2Array [from, to])}.
var wires: Array[Dictionary] = []
## Terminal key -> where it is: {"at", "entry", "top", "row"}.
var terminals: Dictionary[String, Dictionary] = {}

# Tops of the channels, x of the first lane down the side.
var _channels: PackedFloat32Array = PackedFloat32Array()
var _side_x: float = 0.0


## The inside of station [param box_index] of [param doc] (an empty one when
## there is no such station).
static func build(doc: SchematicDocument, box_index: int) -> StationInside:
	var inside: StationInside = StationInside.new()
	if doc == null or box_index < 0 or box_index >= doc.control_boxes.size():
		return inside
	var box: ControlBox = doc.control_boxes[box_index]
	inside._place_items(doc, box)
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	var conductor: Dictionary[int, CabinetDevices.Conductor] = CabinetDevices.conductors(doc.circuit, net)
	var marks: Dictionary[int, String] = CabinetWiring.wire_marks(doc, net)
	# The connections first, then the channels sized for them.
	var links: Array[Dictionary] = inside._links(doc, box, net)
	var rows: int = maxi(ceili(box.items.size() / float(box.columns)), 1)
	var lanes: PackedInt32Array = PackedInt32Array()
	lanes.resize(rows + 1)
	var side: int = 0
	for link: Dictionary in links:
		# One lane where both ends are in the same channel.
		for end: String in (["a"] if link["a_channel"] == link["b_channel"] else ["a", "b"]):
			var channel: int = link[end + "_channel"]
			link[end + "_lane"] = lanes[channel]
			lanes[channel] += 1
		if link["a_channel"] == link["b_channel"]:
			link["b_lane"] = link["a_lane"]
		else:
			link["side_lane"] = side
			side += 1
	inside._lay_out(box, rows, lanes, side)
	inside._route(links, net, conductor, marks)
	return inside


## Devices of each item and their blocks, laid out round the middle of the
## item's cell (the rows are placed by [method _lay_out]).
func _place_items(doc: SchematicDocument, box: ControlBox) -> void:
	for i: int in box.items.size():
		var item: ControlBoxItem = box.items[i]
		var blocks: Array[Dictionary] = []
		var cam: bool = false
		match item.kind:
			ControlBoxItem.Kind.LAMP:
				blocks.append_array(_lamp_blocks(doc, item.designation))
			_:
				var device: CircuitComponent = doc.circuit.get_operator(item.designation)
				if device is CamSwitch:
					cam = true
					blocks.append_array(_cam_blocks(device as CamSwitch))
				else:
					blocks.append_array(_contact_blocks(doc, item.designation))
				var lamp: Array[Dictionary] = _lamp_blocks(doc, item.lamp)
				if not lamp.is_empty():
					# The lamp of an illuminated one in the middle of its blocks.
					blocks.insert(blocks.size() / 2, lamp[0])
		items.append({"item": i, "kind": item.kind, "designation": item.designation, "lamp": item.lamp, "cam": cam, "blocks": blocks})


## The contact blocks of push button or switch [param designation]: every
## part of the circuit with its designation that switches with it.
static func _contact_blocks(doc: SchematicDocument, designation: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if designation.is_empty():
		return result
	for c: CircuitComponent in doc.circuit.get_components():
		if c.designation != designation:
			continue
		var names: PackedStringArray = c.get_terminal_names()
		var keys: PackedStringArray = c.get_terminal_keys()
		if c is ChangeoverContact:
			# Common below, the NC and NO sides on top.
			result.append({"kind": "CO", "terminals": [_terminal(names[1], keys[1], true), _terminal(names[2], keys[2], true), _terminal(names[0], keys[0], false)]})
		elif c is SwitchingElement:
			var nc: bool = (c as SwitchingElement).contact_type == SwitchingElement.ContactType.NC
			result.append({"kind": "NC" if nc else "NO", "terminals": [_terminal(names[0], keys[0], true), _terminal(names[1], keys[1], false)]})
	return result


## The lamp block of signal lamp [param designation] (X1 on top, X2 below).
static func _lamp_blocks(doc: SchematicDocument, designation: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lamp: CircuitComponent = doc.circuit.get_component(designation) if not designation.is_empty() else null
	if lamp is Lamp:
		var names: PackedStringArray = lamp.get_terminal_names()
		var keys: PackedStringArray = lamp.get_terminal_keys()
		result.append({"kind": "LAMP", "terminals": [_terminal(names[0], keys[0], true), _terminal(names[1], keys[1], false)]})
	return result


## A chamber of rotary cam switch [param cam] for each pole: its line side
## (and II side) on top, the load side (the common) below.
static func _cam_blocks(cam: CamSwitch) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var names: PackedStringArray = cam.get_terminal_names()
	var keys: PackedStringArray = cam.get_terminal_keys()
	var per: int = cam.pole_terminals()
	for p: int in cam.poles:
		var list: Array = []
		for t: int in per:
			list.append(_terminal(names[p * per + t], keys[p * per + t], t < per - 1))
		result.append({"kind": "POLE", "terminals": list})
	return result


static func _terminal(name: String, key: String, top: bool) -> Dictionary:
	return {"name": name, "key": key, "top": top}


## Width of a block of [param kind].
static func block_width(kind: String) -> float:
	match kind:
		"CO":
			return CO_BLOCK
		"POLE":
			return CHAMBER
	return BLOCK.x


## The wires to lay: a core of each cable coming in to the terminal it
## lands on, and between the terminals of one net here the shortest links
## from those already joined. Each {"net", "a", "b" (a terminal key, or a
## gland core: {"cable", "core"}), "a_channel", "b_channel", "external"}.
func _links(doc: SchematicDocument, box: ControlBox, net: Dictionary[String, int]) -> Array[Dictionary]:
	var links: Array[Dictionary] = []
	var here: String = "+" + box.name
	# Terminal key -> its row and whether it is on top, from the items.
	var columns: int = box.columns
	var at: Dictionary[String, Vector2] = {}
	for entry: Dictionary in items:
		var row: int = int(entry["item"] / columns)
		var column: int = entry["item"] % columns
		for block: Dictionary in entry["blocks"]:
			for t: Dictionary in block["terminals"]:
				terminals[t["key"]] = {"row": row, "top": t["top"]}
				at[t["key"]] = Vector2(column, row)
	var joined: Dictionary[int, PackedStringArray] = {}
	for cable: Dictionary in WorkspaceCables.cables(doc):
		var end: String = "a" if cable["a"] == here else ("b" if cable["b"] == here else "")
		if end.is_empty():
			continue
		var index: int = glands.size()
		glands.append({"cable": cable["name"], "cores": 0})
		for core: Dictionary in cable["cores"]:
			# The first terminal here of those it lands on.
			var key: String = ""
			for landing: String in core[end]:
				if terminals.has(landing):
					key = landing
					break
			if key.is_empty():
				continue
			var n: int = net.get(key, -1)
			links.append({"net": n, "a": {"gland": index, "core": glands[index]["cores"]}, "b": key, "a_channel": 0, "b_channel": _channel(key), "external": true})
			glands[index]["cores"] += 1
			if not joined.has(n):
				joined[n] = PackedStringArray()
			joined[n].append(key)
	# The other terminals of each net: each to the nearest one joined already.
	var by_net: Dictionary[int, PackedStringArray] = {}
	for key: String in terminals:
		if net.has(key):
			if not by_net.has(net[key]):
				by_net[net[key]] = PackedStringArray()
			by_net[net[key]].append(key)
	for n: int in by_net:
		var keys: PackedStringArray = by_net[n]
		if keys.size() < 2 and not joined.has(n):
			continue
		var done: PackedStringArray = joined.get(n, PackedStringArray()).duplicate()
		var left: Array = Array(keys).filter(func(k: String) -> bool: return not done.has(k))
		if done.is_empty():
			done.append(left.pop_front())
		while not left.is_empty():
			var best: Vector3i = Vector3i(-1, -1, 1 << 30)
			for i: int in left.size():
				for j: int in done.size():
					var d: Vector2 = at[left[i]] - at[done[j]]
					var cost: int = roundi(absf(d.x) * 4.0 + absf(d.y) * 5.0) + (0 if terminals[left[i]]["top"] == terminals[done[j]]["top"] else 1)
					if cost < best.z:
						best = Vector3i(i, j, cost)
			var key: String = left[best.x]
			links.append({"net": n, "a": done[best.y], "b": key, "a_channel": _channel(done[best.y]), "b_channel": _channel(key), "external": false})
			done.append(key)
			left.remove_at(best.x)
	return links


## Channel a wire to terminal [param key] runs in: the one above its row for
## a terminal on top, else the one below.
func _channel(key: String) -> int:
	var t: Dictionary = terminals[key]
	return int(t["row"]) + (0 if t["top"] else 1)


## Rows of [constant CELL] with a channel above, between and below them as
## high as its [param lanes] need, the left side as wide as its
## [param side] lanes; places the items, their blocks and terminals, and
## the glands.
func _lay_out(box: ControlBox, rows: int, lanes: PackedInt32Array, side: int) -> void:
	var left: float = FRAME + side * LANE + (4.0 if side > 0 else 0.0)
	var columns_used: int = clampi(box.items.size(), 1, box.columns)
	var channel_y: PackedFloat32Array = PackedFloat32Array()
	var y: float = TOP
	var row_y: PackedFloat32Array = PackedFloat32Array()
	for r: int in rows + 1:
		var h: float = maxf(CHANNEL, lanes[r] * LANE + 5.0)
		channel_y.append(y)
		y += h
		if r < rows:
			row_y.append(y)
			y += CELL.y
	size = Vector2(left + columns_used * CELL.x + FRAME, y + FRAME)
	_channels = channel_y
	_side_x = FRAME + 2.0
	for entry: Dictionary in items:
		var row: int = int(entry["item"] / box.columns)
		var column: int = entry["item"] % box.columns
		var cell: Rect2 = Rect2(left + column * CELL.x, row_y[row], CELL.x, CELL.y)
		entry["rect"] = cell
		entry["center"] = cell.get_center()
		var total: float = 0.0
		for block: Dictionary in entry["blocks"]:
			total += block_width(block["kind"])
		var x: float = cell.get_center().x - total * 0.5
		for block: Dictionary in entry["blocks"]:
			var w: float = block_width(block["kind"])
			block["rect"] = Rect2(x, cell.get_center().y - BLOCK.y * 0.5, w, BLOCK.y)
			var tops: Array = block["terminals"].filter(func(t: Dictionary) -> bool: return t["top"])
			for t: Dictionary in block["terminals"]:
				var same: Array = tops if t["top"] else block["terminals"].filter(func(o: Dictionary) -> bool: return not o["top"])
				var k: int = same.find(t)
				var tx: float = x + w * (k + 1) / float(same.size() + 1)
				t["at"] = Vector2(tx, cell.get_center().y + (-SCREW_Y if t["top"] else SCREW_Y))
				t["entry"] = Vector2(tx, block["rect"].position.y if t["top"] else block["rect"].end.y)
				terminals[t["key"]]["at"] = t["at"]
				terminals[t["key"]]["entry"] = t["entry"]
			x += w
	# Glands side by side in the middle of the top.
	var widths: float = 0.0
	for gland: Dictionary in glands:
		widths += maxf(gland["cores"] * CORE + 4.0, 12.0) + 6.0
	var gx: float = size.x * 0.5 - widths * 0.5
	for gland: Dictionary in glands:
		var w: float = maxf(gland["cores"] * CORE + 4.0, 12.0)
		gland["rect"] = Rect2(gx + 3.0, -2.0, w, 8.0)
		gx += w + 6.0


## Height of lane [param lane] of channel [param channel].
func _lane_y(channel: int, lane: int) -> float:
	return _channels[channel] + 3.0 + lane * LANE


## The points of every link (see [method _links]): out of its terminal up or
## down into its lane of the channel, along it, down the side in a lane of
## its own to the other channel where needed, and into the other terminal.
func _route(links: Array[Dictionary], net: Dictionary[String, int], conductor: Dictionary[int, CabinetDevices.Conductor], marks: Dictionary[int, String]) -> void:
	for link: Dictionary in links:
		var a: Vector2 = _end(link["a"])
		var b: Vector2 = _end(link["b"])
		var ya: float = _lane_y(link["a_channel"], link["a_lane"])
		var yb: float = _lane_y(link["b_channel"], link["b_lane"])
		var points: PackedVector2Array = PackedVector2Array([a, Vector2(a.x, ya)])
		if link["a_channel"] == link["b_channel"]:
			points.append(Vector2(b.x, ya))
		else:
			var x: float = _side_x + link["side_lane"] * LANE
			points.append(Vector2(x, ya))
			points.append(Vector2(x, yb))
			points.append(Vector2(b.x, yb))
		points.append(b)
		var n: int = link["net"]
		var c: CabinetDevices.Conductor = conductor.get(n, CabinetDevices.Conductor.CONTROL)
		var markers: Array[PackedVector2Array] = []
		var mark: String = marks.get(n, "")
		if not mark.is_empty():
			var length: float = maxf(mark.length() * CabinetParts.MARKER_CHAR + CabinetParts.MARKER_ENDS, CabinetParts.MARKER_MIN)
			for end: int in 2:
				if end == 0 and link["external"]:
					continue
				var tip: Vector2 = points[0] if end == 0 else points[points.size() - 1]
				var next: Vector2 = points[1] if end == 0 else points[points.size() - 2]
				var along: Vector2 = (next - tip).normalized()
				var room: float = tip.distance_to(next)
				var from: float = minf(CabinetParts.MARKER_FROM, maxf(room - length, 0.0))
				if room > from + 1.0:
					markers.append(PackedVector2Array([tip + along * from, tip + along * minf(from + length, room)]))
		wires.append({"net": n, "conductor": c, "points": _simplified(points), "external": link["external"], "mark": mark, "markers": markers})


## Where link end [param end] is: the opening of a terminal's clamp, or a
## core coming in at its gland.
func _end(end: Variant) -> Vector2:
	if end is Dictionary:
		var gland: Rect2 = glands[end["gland"]]["rect"]
		return Vector2(gland.position.x + 2.0 + (end["core"] + 0.5) * CORE, gland.end.y)
	return terminals[end]["entry"]


## [param points] without points repeated or in line.
static func _simplified(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		if not result.is_empty() and result[result.size() - 1].is_equal_approx(point):
			continue
		if result.size() >= 2:
			var a: Vector2 = result[result.size() - 2]
			var b: Vector2 = result[result.size() - 1]
			if is_zero_approx((b - a).cross(point - b)):
				result[result.size() - 1] = point
				continue
		result.append(point)
	return result
