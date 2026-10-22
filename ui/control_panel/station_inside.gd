class_name StationInside
extends RefCounted
## The inside of a control station ([ControlBox]) with its cover off, in
## millimetres: behind each push button or switch its contact blocks clipped
## side by side on the mounting adapter (NO, NC, CO; a lamp block between
## them in an illuminated one), behind a signal lamp its lamp block, behind a
## rotary cam switch its chambers, one a pole; every block with its screw
## terminals at the top and the bottom; behind a potentiometer its round
## body with three solder lugs on top, the wires pushed on with insulated
## fastons. The cables of the workspace (see
## [WorkspaceCables]) come in through glands in the top of the housing, a
## core of each to the terminal it lands on; terminals of one net are joined
## by short wires from terminal to terminal. Wires run in lanes of the
## channels above and below each row of devices and down the left side,
## coloured by conductor ([method CabinetDevices.conductors]), each with its
## wire number on a marker sleeve at its ends. Laid out by [method build];
## drawn by [StationInsideView]. The back of a switchboard's door is laid out
## the same way ([method build_door]): its devices behind their places on
## the front (seen from behind, so mirrored), the door harness coming in at
## the bottom on the hinge side (the left, seen from behind) from the
## switchboard. No nodes.

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
## A potentiometer's body (radius), its lugs (the middle of each above the
## body's middle, their tops) and the length of a faston on a lug.
const POT_R: float = 11.0
const LUG_Y: float = 13.0
const LUG_TOP: float = 15.5
const FASTON: float = 7.0
## Half the height of the back of the biggest device (a cam switch's square).
const BACK_HALF: float = 24.0
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
## "blocks": [{"kind" ("NO", "NC", "CO", "LAMP", "POLE", "POT"), "rect",
## "terminals": [{"name", "key", "at" (its screw, a potentiometer's lug),
## "entry" (where its wire goes into the contact: the block's top or bottom
## face, under the screw; the top of a lug's faston), "top"}]}]}.
var items: Array[Dictionary] = []
## Glands in the top: {"rect", "cable" (its name)}; on a door the harness's
## conduit at the bottom ("cable" [constant CabinetWiring.DOOR]).
var glands: Array[Dictionary] = []
## The back of a switchboard's door (see [method build_door]).
var door: bool = false
## Wires: {"net", "conductor", "points", "external" (a core starting at a
## gland), "mark", "markers" (sleeves as PackedVector2Array [from, to]),
## "pins" (as for [method CabinetParts.wire]: -1 at an end in a faston)}.
var wires: Array[Dictionary] = []
## Terminal key -> where it is: {"at", "entry", "top", "row", "faston"
## (a potentiometer's lug)}.
var terminals: Dictionary[String, Dictionary] = {}

## The ports of a training plan laid out by [method build_given] (see
## [TrainingCheck]): port -> where it is (mm; a terminal's screw, a core's
## end at its gland).
var ports: Dictionary[String, Vector2] = {}
## Index in the pairs given to [method build_given] of each of [member wires].
var pairs: Array[int] = []

# The door harness's cores (see [method build_door_given]); each port's link end.
var _harness: Array[Dictionary] = []
var _port_ends: Dictionary[String, Variant] = {}
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
	# The nets as the cables run them: supply points of one conductor joined.
	var net: Dictionary[String, int] = WorkspaceCables.nets(doc.circuit)
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


## The back of the door of switchboard [param board] of [param doc], the
## enclosure [param enclosure] mm (see [method DoorView.size_of]): each
## device behind its place on the front, mirrored as seen from behind; a
## core of the door harness ([method CabinetWiring.door_harness]) to the
## first terminal of its net here, the others joined to it. The harness
## comes in through a fitting in the hinge edge (the left, seen from
## behind) at height [param across] (where it leaves the switchboard; below
## the rows when negative).
static func build_door(doc: SchematicDocument, board: int, enclosure: Vector2, across: float = -1.0) -> StationInside:
	var inside: StationInside = StationInside.new()
	inside.door = true
	if doc == null or board < 0 or board >= doc.switchboards.size():
		return inside
	var box: ControlBox = doc.switchboards[board].door
	inside._place_items(doc, box)
	var net: Dictionary[String, int] = WorkspaceCables.nets(doc.circuit)
	var conductor: Dictionary[int, CabinetDevices.Conductor] = CabinetDevices.conductors(doc.circuit, net)
	var marks: Dictionary[int, String] = CabinetWiring.wire_marks(doc, net)
	var rows: int = maxi(ceili(box.items.size() / float(box.columns)), 1)
	var harness: PackedInt32Array = PackedInt32Array()
	for core: Dictionary in CabinetWiring.door_harness(doc, board):
		harness.append(core["net"])
	var links: Array[Dictionary] = inside._links(doc, box, net, harness, rows)
	var lanes: PackedInt32Array = PackedInt32Array()
	lanes.resize(rows + 1)
	var side: int = 0
	for link: Dictionary in links:
		if link["external"]:
			# A harness core goes up the hinge side to its channel at once.
			link["a_channel"] = link["b_channel"]
			link["side_lane"] = side
			side += 1
		for end: String in (["a"] if link["a_channel"] == link["b_channel"] else ["a", "b"]):
			var channel: int = link[end + "_channel"]
			link[end + "_lane"] = lanes[channel]
			lanes[channel] += 1
		if link["a_channel"] == link["b_channel"]:
			link["b_lane"] = link["a_lane"]
		elif not link.has("side_lane"):
			link["side_lane"] = side
			side += 1
	inside._lay_out_door(box, enclosure, rows, lanes, across)
	inside._route(links, net, conductor, marks)
	return inside


## The inside of station [param box_index] of [param doc] with the student's
## wires of a training plan ([param given]: two ports of [TrainingCheck]
## each) in place of its own, laid the same way; sets [member ports] and
## [member pairs]. Pairs naming a port it has not are left out.
static func build_given(doc: SchematicDocument, box_index: int, given: Array[PackedStringArray]) -> StationInside:
	var inside: StationInside = StationInside.new()
	if doc == null or box_index < 0 or box_index >= doc.control_boxes.size():
		return inside
	var box: ControlBox = doc.control_boxes[box_index]
	inside._place_items(doc, box)
	var rows: int = maxi(ceili(box.items.size() / float(box.columns)), 1)
	var links: Array[Dictionary] = inside._given_links(doc, box, given, rows)
	var lanes: PackedInt32Array = PackedInt32Array()
	lanes.resize(rows + 1)
	var side: int = 0
	for link: Dictionary in links:
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
	inside._finish_given(doc, links)
	return inside


## The back of the door of switchboard [param board] (see [method build_door])
## with the student's wires [param given] in place of its own, as
## [method build_given].
static func build_door_given(doc: SchematicDocument, board: int, enclosure: Vector2, across: float, given: Array[PackedStringArray]) -> StationInside:
	var inside: StationInside = StationInside.new()
	inside.door = true
	if doc == null or board < 0 or board >= doc.switchboards.size():
		return inside
	var box: ControlBox = doc.switchboards[board].door
	inside._place_items(doc, box)
	var rows: int = maxi(ceili(box.items.size() / float(box.columns)), 1)
	inside._harness = CabinetWiring.door_harness(doc, board)
	var links: Array[Dictionary] = inside._given_links(doc, box, given, rows)
	var lanes: PackedInt32Array = PackedInt32Array()
	lanes.resize(rows + 1)
	var side: int = 0
	for link: Dictionary in links:
		if link["external"]:
			link["a_channel"] = link["b_channel"]
			link["side_lane"] = side
			side += 1
		for end: String in (["a"] if link["a_channel"] == link["b_channel"] else ["a", "b"]):
			var channel: int = link[end + "_channel"]
			link[end + "_lane"] = lanes[channel]
			lanes[channel] += 1
		if link["a_channel"] == link["b_channel"]:
			link["b_lane"] = link["a_lane"]
		elif not link.has("side_lane"):
			link["side_lane"] = side
			side += 1
	inside._lay_out_door(box, enclosure, rows, lanes, across)
	inside._finish_given(doc, links)
	return inside


## Links of the student's wires [param given] (see [method _links]): the
## terminals of the items, the cores of the cables ending here (of the door
## harness on a door) at their glands.
func _given_links(doc: SchematicDocument, box: ControlBox, given: Array[PackedStringArray], rows: int) -> Array[Dictionary]:
	var ws: Dictionary[String, int] = WorkspaceCables.nets(doc.circuit)
	for entry: Dictionary in items:
		var row: int = int(entry["item"] / box.columns)
		for block: Dictionary in entry["blocks"]:
			for t: Dictionary in block["terminals"]:
				terminals[t["key"]] = {"row": row, "top": t["top"]}
	# Port -> link end, and its net.
	var ends: Dictionary[String, Variant] = {}
	var nets: Dictionary[String, int] = {}
	for key: String in terminals:
		ends["t:" + key] = key
		nets["t:" + key] = ws.get(key, -1)
	if door:
		glands.append({"cable": CabinetWiring.DOOR, "cores": _harness.size()})
		for i: int in _harness.size():
			ends["c:%s:%d" % [CabinetWiring.DOOR, i]] = {"gland": 0, "core": i}
			nets["c:%s:%d" % [CabinetWiring.DOOR, i]] = _harness[i]["net"]
	else:
		var here: String = "+" + box.name
		for cable: Dictionary in WorkspaceCables.cables(doc):
			if cable["a"] != here and cable["b"] != here:
				continue
			for i: int in cable["cores"].size():
				ends["c:%s:%d" % [cable["name"], i]] = {"gland": glands.size(), "core": i}
				nets["c:%s:%d" % [cable["name"], i]] = cable["cores"][i]["net"]
			glands.append({"cable": cable["name"], "cores": cable["cores"].size()})
	var links: Array[Dictionary] = []
	for p: int in given.size():
		var pair: PackedStringArray = given[p]
		if not ends.has(pair[0]) or not ends.has(pair[1]):
			continue
		var a: Variant = ends[pair[0]]
		var b: Variant = ends[pair[1]]
		if b is Dictionary and not (a is Dictionary):
			var swap: Variant = a
			a = b
			b = swap
		var core_channel: int = rows if door else 0
		links.append({"net": nets[pair[0]], "a": a, "b": b, "a_channel": core_channel if a is Dictionary else _channel(a), "b_channel": core_channel if b is Dictionary else _channel(b), "external": a is Dictionary, "pair": p})
	for port: String in ends:
		_port_ends[port] = ends[port]
	return links


## Routes the student's [param links] and sets [member ports] and [member pairs].
func _finish_given(doc: SchematicDocument, links: Array[Dictionary]) -> void:
	var ws: Dictionary[String, int] = WorkspaceCables.nets(doc.circuit)
	_route(links, ws, CabinetDevices.conductors(doc.circuit, ws), CabinetWiring.wire_marks(doc, ws))
	for link: Dictionary in links:
		pairs.append(link["pair"])
	for port: String in _port_ends:
		var end: Variant = _port_ends[port]
		if end is Dictionary:
			ports[port] = _end(end)
		elif terminals[end].has("at"):
			ports[port] = terminals[end]["at"]


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
			ControlBoxItem.Kind.POT:
				blocks.append_array(_pot_blocks(doc, item.designation))
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


## The body of potentiometer [param designation]: its lugs 1, 2, 3 on top.
static func _pot_blocks(doc: SchematicDocument, designation: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pot: CircuitComponent = doc.circuit.get_component(designation) if not designation.is_empty() else null
	if pot is Potentiometer:
		var names: PackedStringArray = pot.get_terminal_names()
		var keys: PackedStringArray = pot.get_terminal_keys()
		result.append({"kind": "POT", "terminals": [_terminal(names[0], keys[0], true), _terminal(names[1], keys[1], true), _terminal(names[2], keys[2], true)]})
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
		"POT":
			return 2.0 * POT_R + 4.0
	return BLOCK.x


## The wires to lay: a core of each cable coming in to the terminal it
## lands on (on a door, a core of the harness for each of [param harness]'s
## nets, coming in to the channel under row [param rows] - 1), and between
## the terminals of one net here the shortest links from those already
## joined. Each {"net", "a", "b" (a terminal key, or a gland core:
## {"gland", "core"}), "a_channel", "b_channel", "external"}.
func _links(doc: SchematicDocument, box: ControlBox, net: Dictionary[String, int], harness: PackedInt32Array = PackedInt32Array(), rows: int = 0) -> Array[Dictionary]:
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
	if door:
		glands.append({"cable": CabinetWiring.DOOR, "cores": 0})
		for n: int in harness:
			# The first terminal of the net, in the order of the items.
			var key: String = ""
			for entry: Dictionary in items:
				for block: Dictionary in entry["blocks"]:
					for t: Dictionary in block["terminals"]:
						if key.is_empty() and net.get(t["key"], -1) == n:
							key = t["key"]
			if key.is_empty() or joined.has(n):
				continue
			links.append({"net": n, "a": {"gland": 0, "core": glands[0]["cores"]}, "b": key, "a_channel": rows, "b_channel": _channel(key), "external": true})
			glands[0]["cores"] += 1
			joined[n] = PackedStringArray([key])
	for cable: Dictionary in (WorkspaceCables.cables(doc) if not door else []):
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
		_place_blocks(entry)
	# Glands side by side in the middle of the top.
	var widths: float = 0.0
	for gland: Dictionary in glands:
		widths += maxf(gland["cores"] * CORE + 4.0, 12.0) + 6.0
	var gx: float = size.x * 0.5 - widths * 0.5
	for gland: Dictionary in glands:
		var w: float = maxf(gland["cores"] * CORE + 4.0, 12.0)
		gland["rect"] = Rect2(gx + 3.0, -2.0, w, 8.0)
		gx += w + 6.0


## The back of a door of [param box] (enclosure [param enclosure] mm): each
## item behind its cell on the front, mirrored; the channel above each row
## over its blocks, the one under a row under them, [param lanes] each; the
## harness's fitting in the left edge (the hinge side seen from behind) at
## height [param across].
func _lay_out_door(box: ControlBox, enclosure: Vector2, rows: int, lanes: PackedInt32Array, across: float) -> void:
	size = DoorView.size_of(box, enclosure)
	var cells: Array[Rect2] = DoorView.cells_of(box, enclosure)
	var centres: PackedFloat32Array = PackedFloat32Array()
	for entry: Dictionary in items:
		var front: Rect2 = cells[entry["item"]]
		var cell: Rect2 = Rect2(size.x - front.end.x, front.position.y, front.size.x, front.size.y)
		entry["rect"] = cell
		entry["center"] = cell.position + Vector2(cell.size.x * 0.5, DoorView.DEVICE_Y)
		entry["door"] = true
		_place_blocks(entry)
		var row: int = int(entry["item"] / box.columns)
		while centres.size() <= row:
			centres.append(entry["center"].y)
	# The first channel over the first row's blocks, every other one under
	# the blocks of the row above it (the rows are far enough apart).
	_channels = PackedFloat32Array()
	for r: int in rows + 1:
		if centres.is_empty():
			_channels.append(size.y - 30.0)
		elif r == 0:
			_channels.append(centres[0] - BACK_HALF - 4.0 - lanes[0] * LANE)
		else:
			_channels.append(centres[mini(r, centres.size()) - 1] + BACK_HALF + 2.0)
	_side_x = FRAME + 6.0
	if not glands.is_empty():
		var h: float = maxf(glands[0]["cores"] * CORE + 4.0, 10.0)
		var y: float = across if across >= 0.0 else size.y - 40.0
		glands[0]["rect"] = Rect2(-1.0, clampf(y - h * 0.5, 10.0, size.y - h - 10.0), FRAME + 1.0, h)


## The blocks of item [param entry] side by side round its centre, their
## terminals' screws and where their wires go into the contacts.
func _place_blocks(entry: Dictionary) -> void:
	var center: Vector2 = entry["center"]
	var total: float = 0.0
	for block: Dictionary in entry["blocks"]:
		total += block_width(block["kind"])
	var x: float = center.x - total * 0.5
	for block: Dictionary in entry["blocks"]:
		var w: float = block_width(block["kind"])
		block["rect"] = Rect2(x, center.y - BLOCK.y * 0.5, w, BLOCK.y)
		var tops: Array = block["terminals"].filter(func(t: Dictionary) -> bool: return t["top"])
		for t: Dictionary in block["terminals"]:
			var same: Array = tops if t["top"] else block["terminals"].filter(func(o: Dictionary) -> bool: return not o["top"])
			var k: int = same.find(t)
			var tx: float = x + w * (k + 1) / float(same.size() + 1)
			t["at"] = Vector2(tx, center.y + (-SCREW_Y if t["top"] else SCREW_Y))
			t["entry"] = Vector2(tx, block["rect"].position.y if t["top"] else block["rect"].end.y)
			if block["kind"] == "POT":
				# Lugs a little apart, the wire coming out of the top of its faston.
				tx = center.x + (k - 1) * POT_R * 0.6
				t["at"] = Vector2(tx, center.y - LUG_Y)
				t["entry"] = Vector2(tx, center.y - LUG_TOP - FASTON)
				terminals[t["key"]]["faston"] = true
			terminals[t["key"]]["at"] = t["at"]
			terminals[t["key"]]["entry"] = t["entry"]
		x += w


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
		if door and link["external"]:
			# Out of the fitting in the hinge edge, up the side to the channel.
			var xs: float = _side_x + link["side_lane"] * LANE
			points = PackedVector2Array([a, Vector2(xs, a.y), Vector2(xs, yb), Vector2(b.x, yb)])
		elif link["a_channel"] == link["b_channel"]:
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
				if end == 0 and link["external"] and not door:
					# A cable's core is marked at its terminal; one of the door
					# harness where it comes out of its fitting too.
					continue
				var tip: Vector2 = points[0] if end == 0 else points[points.size() - 1]
				var next: Vector2 = points[1] if end == 0 else points[points.size() - 2]
				var along: Vector2 = (next - tip).normalized()
				var room: float = tip.distance_to(next)
				var from: float = minf(CabinetParts.MARKER_FROM, maxf(room - length, 0.0))
				if room > from + 1.0:
					markers.append(PackedVector2Array([tip + along * from, tip + along * minf(from + length, room)]))
		var pins: Vector2 = Vector2(-1.0 if _in_faston(link["a"]) else 0.0, -1.0 if _in_faston(link["b"]) else 0.0)
		wires.append({"net": n, "conductor": c, "points": _simplified(points), "external": link["external"], "mark": mark, "markers": markers, "pins": pins})


## True when link end [param end] is a potentiometer's lug (the wire's end
## is in its faston, no ferrule).
func _in_faston(end: Variant) -> bool:
	return end is String and terminals[end].get("faston", false)


## Where link end [param end] is: where a wire goes into a terminal's
## contact, or a core coming in at its gland.
func _end(end: Variant) -> Vector2:
	if end is Dictionary:
		# A core comes out under a gland in the top, over the conduit at a
		# door's bottom.
		var gland: Rect2 = glands[end["gland"]]["rect"]
		if door:
			return Vector2(gland.end.x, gland.position.y + 2.0 + (end["core"] + 0.5) * CORE)
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
