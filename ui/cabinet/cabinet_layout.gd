class_name CabinetLayout
extends RefCounted
## Where everything of the switchboard sits, in millimetres: the enclosure
## with its mounting plate, the wire ducts (across above, between and below
## the rails, down both sides), the DIN rails and every place on them with
## its device's drawing, label and the area that answers clicks. Built from
## the rails of one of [member SchematicDocument.switchboards] and the
## circuit (see [CabinetDevices]); the plate grows with the longest rail.

## Frame of the enclosure around the plate.
const FRAME: float = 6.0
## Width of the ducts down both sides, height of the ducts across, before
## they are sized to their wires (see [method duct_size]).
const SIDE_DUCT: float = 25.0
const DUCT: float = 28.0
## Most times the ducts are sized again for the wires' new ways.
const SIZE_ROUNDS: int = 4
## Room between the side ducts and the rails, between places on a rail, and
## between a duct and the parts above or below it (room for the wires'
## marker sleeves, see [CabinetWiring]).
const MARGIN: float = 5.0
const GAP: float = 2.0
const PAD: float = 20.0
## How far over or under its device a label sits on the plate: in the room
## between the duct and the device, past the wires' ferrules and marker
## sleeves.
const LABEL_OFF: float = 15.0
## Room on both sides of a contactor with an overload relay under it for
## the wires from the contactor's bottom terminals (see [CabinetWiring]),
## and more for the two wires of each auxiliary contact block mounted on
## its side (on the side with more of them).
const WIRE_CHANNEL: float = 6.0
const SIDE_BLOCK_CHANNEL: float = 3.0
## Narrowest room for the rails.
const MIN_CONTENT: float = 100.0
## Size of an empty place (device not in the circuit).
const MISSING := Vector2(18.0, 60.0)
## Height of an empty rail.
const EMPTY_ROW: float = 47.0

## Kind of a place besides [enum CabinetDevices.Kind]: a terminal strip, a
## device the circuit no longer has.
const STRIP: int = 100
const MISSING_DEVICE: int = 101
## Kind of a place the switchboard adds by itself: an N or PE distribution
## block (see [method bus_blocks]).
const BUS_BLOCK: int = 102
## Most loads taking N or PE in a switchboard before it gets a distribution
## block for it.
const BUS_LOADS: int = 2

var size: Vector2 = Vector2.ZERO
## The wiring the ducts were sized for (see [method build]); null when the
## sizing did not settle.
var wiring: CabinetWiring
## Ducts: {"rect": Rect2, "vertical": bool}: across from the top, then down
## the left and the right side.
var ducts: Array[Dictionary] = []
## DIN rails, one per [member Switchboard.rails].
var rails: Array[Rect2] = []
## Places on the rails: {"rail", "index" (-1 for a place the switchboard
## adds by itself), "kind" (CabinetDevices.Kind, STRIP, MISSING_DEVICE or
## BUS_BLOCK, its desc as in [method bus_blocks]), "designation", "desc" (see [method CabinetDevices.describe];
## for a strip {"terminals": [...], "bridges" (see
## [method CabinetWiring.strip_bridges])}), "origin" (top-left of the drawing),
## "size", "rect" (answers clicks), "label_at", "label_w" (no label when 0),
## and for a contactor with its overload relay "under_origin",
## "under_rect", "under_label_at", "under_designation", "channel" (room for
## wires on both sides)}.
var places: Array[Dictionary] = []


## Lays out switchboard [param board] of [param doc] (empty when there is no
## such switchboard); [param k] (pixels per mm) makes the terminal strips as
## wide as they are drawn. Each duct is as wide as the wires running through
## it need (see [method duct_size], [member CabinetWiring.lanes]).
static func build(doc: SchematicDocument, k: float, board: int = 0) -> CabinetLayout:
	# Laid out with ducts of the first size, wired, then again with each duct
	# as wide as the wires running through it need, until they all fit (the
	# wires take other ways as the ducts grow; a duct never gets narrower,
	# so it settles).
	var layout: CabinetLayout = _build(doc, k, board, [])
	var sizes: Array[float] = []
	for attempt: int in SIZE_ROUNDS:
		layout.wiring = CabinetWiring.build(doc, layout, k, board)
		var lanes: Array[int] = layout.wiring.lanes
		if lanes.size() != layout.ducts.size():
			return layout
		var grown: bool = false
		for d: int in lanes.size():
			var width: float = maxf(duct_size(lanes[d]), sizes[d] if d < sizes.size() else 0.0)
			if d >= sizes.size():
				sizes.append(width)
				grown = true
			elif width > sizes[d]:
				sizes[d] = width
				grown = true
		if not grown:
			return layout
		layout = _build(doc, k, board, sizes)
	return layout


## The distribution blocks switchboard [param board] of [param doc] gets
## ([param strips] as [method CabinetDevices.strips], [param net] its nets),
## N first, then PE: for each of N (the nets of the N supply) and PE taken by
## more than BUS_LOADS loads there (strip terminals on it but the one the
## incoming conductor lands on, devices' terminals on it), one with the
## smallest of [constant CabinetParts.BUS_SIZES] connections taking them and
## the incoming wire: {"connections", "neutral" (an N block), "after" (the
## strip the incoming conductor lands on, "" for none), "key" (a terminal
## key on it), "nets" (the nets it joins)}.
static func bus_blocks(doc: SchematicDocument, board: int, strips: Dictionary, net: Dictionary[String, int]) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	if board < 0 or board >= doc.switchboards.size():
		return blocks
	var conductor: Dictionary[int, CabinetDevices.Conductor] = CabinetDevices.conductors(doc.circuit, net)
	var neutral: Dictionary[int, bool] = {}
	var earth: Dictionary[int, bool] = {}
	for c: CircuitComponent in doc.circuit.get_components():
		if c is PowerSupply and (c as PowerSupply).conductor == PowerSupply.Conductor.N and net.has(c.get_terminal_keys()[0]):
			neutral[net[c.get_terminal_keys()[0]]] = true
	for n: int in conductor:
		if conductor[n] == CabinetDevices.Conductor.PE:
			earth[n] = true
	for which: int in 2:
		var nets: Dictionary[int, bool] = neutral if which == 0 else earth
		var on: Callable = func(key: String) -> bool: return net.has(key) and nets.has(net[key])
		var loads: int = 0
		var after: String = ""
		var key: String = ""
		for rail: CabinetRail in doc.switchboards[board].rails:
			for item: CabinetItem in rail.items:
				if item.kind == CabinetItem.Kind.STRIP:
					for t: Dictionary in strips.get(item.designation, []):
						var hit: String = ""
						var supply: String = ""
						for k: String in t["keys"]:
							if on.call(k):
								hit = k
								if doc.circuit.get_terminal_owner(k) is PowerSupply:
									supply = k
						if not supply.is_empty():
							if after.is_empty():
								after = item.designation
								key = supply
						elif not hit.is_empty():
							loads += 1
							key = hit if key.is_empty() else key
					continue
				var terminals: Dictionary = CabinetDevices.describe(doc, item.designation).get("terminals", {})
				for name: String in terminals:
					if on.call(terminals[name]):
						loads += 1
						key = terminals[name] if key.is_empty() else key
		if loads <= BUS_LOADS:
			continue
		var connections: int = loads + 1
		for size: int in CabinetParts.BUS_SIZES:
			if size >= loads + 1:
				connections = size
				break
		blocks.append({"connections": connections, "neutral": which == 0, "after": after, "key": key, "nets": PackedInt32Array(nets.keys())})
	return blocks


## The nets the distribution [param blocks] (of [method bus_blocks]) join.
static func bus_nets(blocks: Array[Dictionary]) -> Dictionary[int, bool]:
	var result: Dictionary[int, bool] = {}
	for block: Dictionary in blocks:
		for n: int in block["nets"]:
			result[n] = true
	return result


## Width of a duct just holding [param wires] side by side between its
## fingers (see [CabinetWiring]), in whole millimetres (one wire's room for
## none).
static func duct_size(wires: int) -> float:
	return ceilf(maxi(wires - 1, 0) * CabinetWiring.LANE + CabinetWiring.WIRE_W + 2.0 * CabinetParts.DUCT_DEPTH - 0.001)


## The layout with ducts [param sizes] wide, in the order of [member ducts]
## (none given: DUCT and SIDE_DUCT).
static func _build(doc: SchematicDocument, k: float, board: int, sizes: Array[float]) -> CabinetLayout:
	var layout: CabinetLayout = CabinetLayout.new()
	var strips: Dictionary = CabinetDevices.strips(doc)
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	var buses: Array[Dictionary] = bus_blocks(doc, board, strips, net)
	var apart: Dictionary[int, bool] = bus_nets(buses)
	var board_rails: Array[CabinetRail] = doc.switchboards[board].rails if board >= 0 and board < doc.switchboards.size() else ([] as Array[CabinetRail])
	# Each rail: its places relative to the rail's centre line and its extent.
	var rows: Array[Dictionary] = []
	var content: float = MIN_CONTENT
	# Overload relays fitted under a contactor in a switchboard are drawn
	# there, not again where they are on a rail.
	var fitted: Dictionary[String, bool] = {}
	var under: Dictionary[String, String] = CabinetDevices.overloads_under_contactors(doc.circuit)
	for contactor: String in under:
		if doc.cabinet_has(CabinetItem.Kind.DEVICE, contactor):
			fitted[under[contactor]] = true
	for r: int in board_rails.size():
		var rail: CabinetRail = board_rails[r]
		var row: Dictionary = {"places": [], "top": -EMPTY_ROW * 0.5, "bottom": EMPTY_ROW * 0.5}
		var x: float = 0.0
		for i: int in rail.items.size():
			if rail.items[i].kind == CabinetItem.Kind.DEVICE and fitted.has(rail.items[i].designation):
				continue
			var place: Dictionary = _place(doc, strips, rail.items[i], k, net, apart)
			place["rail"] = r
			place["index"] = i
			var slot: float = maxf(place["size"].x + 2.0 * place.get("channel", 0.0), place["label_w"])
			place["origin"] = Vector2(x + (slot - place["size"].x) * 0.5, place["origin"].y)
			x += slot + GAP
			var added: Array[Dictionary] = [place]
			# The distribution blocks after the strip their incoming
			# conductor lands on (else at the end of the last rail).
			var last: bool = r == board_rails.size() - 1 and i == rail.items.size() - 1
			for bus: Dictionary in buses:
				if not ((rail.items[i].kind == CabinetItem.Kind.STRIP and rail.items[i].designation == bus["after"]) or (bus["after"].is_empty() and last)):
					continue
				var block: Dictionary = {"designation": "N" if bus["neutral"] else "PE", "label_w": 0.0, "kind": BUS_BLOCK, "desc": bus, "rail": r, "index": -1}
				_box(block, CabinetParts.bus_size(bus["connections"]))
				# Room on its left for its wires' leads (see [CabinetWiring]).
				var room: float = CabinetWiring.BUS_LEAD + ceili(bus["connections"] / 2.0) * CabinetWiring.LANE + CabinetWiring.WIRE_W
				block["origin"] = Vector2(x + room, block["origin"].y)
				x += block["size"].x + room + GAP
				added.append(block)
			for put: Dictionary in added:
				row["places"].append(put)
				row["top"] = minf(row["top"], put["top"])
				row["bottom"] = maxf(row["bottom"], put["bottom"])
		content = maxf(content, x - GAP)
		rows.append(row)
	# Wide enough for a slot of the bottom duct to each field cable (the
	# duct reaches MARGIN past the rails on both sides).
	var slots: int = CabinetWiring.bottom_slots(doc, board, strips)
	if slots > 0:
		var pitch: float = CabinetParts.DUCT_FINGER + CabinetParts.DUCT_SLOT
		content = maxf(content, slots * pitch + 2.0 * CabinetParts.DUCT_END + CabinetParts.DUCT_FINGER - 2.0 * MARGIN + 0.1)
	var count: int = maxi(rows.size(), 1) + 1
	var across_size: Callable = func(d: int) -> float: return sizes[d] if sizes.size() == count + 2 else DUCT
	# The side ducts' slots: the duct and the room against the frame.
	var left: float = sizes[count] + 2.0 if sizes.size() == count + 2 else SIDE_DUCT
	var right: float = sizes[count + 1] + 2.0 if sizes.size() == count + 2 else SIDE_DUCT
	var x0: float = FRAME + left + MARGIN
	layout.size.x = x0 + content + MARGIN + right + FRAME
	var y: float = FRAME + 2.0
	var across: Array[float] = [y]
	y += across_size.call(0) + PAD
	for row: Dictionary in rows:
		var cy: float = y - row["top"]
		layout.rails.append(Rect2(x0 - 2.0, cy - CabinetParts.RAIL_H * 0.5, content + 4.0, CabinetParts.RAIL_H))
		for place: Dictionary in row["places"]:
			_shift(place, Vector2(x0, cy))
			layout.places.append(place)
		y = cy + row["bottom"] + PAD
		across.append(y)
		y += across_size.call(across.size() - 1) + PAD
	if rows.is_empty():
		y += EMPTY_ROW
		across.append(y)
		y += across_size.call(across.size() - 1) + PAD
	layout.size.y = across[across.size() - 1] + across_size.call(across.size() - 1) + 2.0 + FRAME
	var duct_x: float = FRAME + left
	for d: int in across.size():
		layout.ducts.append({"rect": Rect2(duct_x, across[d], layout.size.x - FRAME - right - duct_x, across_size.call(d)), "vertical": false})
	var down: float = layout.size.y - 2.0 * (FRAME + 2.0)
	layout.ducts.append({"rect": Rect2(FRAME + 2.0, FRAME + 2.0, left - 2.0, down), "vertical": true})
	layout.ducts.append({"rect": Rect2(layout.size.x - FRAME - right, FRAME + 2.0, right - 2.0, down), "vertical": true})
	return layout


## Index in [member places] of the place at [param point] (mm), -1 for none.
## [param under] is set true when the point is on an overload relay fitted
## under a contactor.
func place_at(point: Vector2, under: Array = []) -> int:
	for i: int in places.size():
		var place: Dictionary = places[i]
		if place.has("under_rect") and (place["under_rect"] as Rect2).has_point(point):
			under.append(true)
			return i
		if (place["rect"] as Rect2).has_point(point):
			return i
	return -1


## Describes the device of [param place] again (its simulation state
## changed); where it is stays as laid out.
static func describe_again(doc: SchematicDocument, place: Dictionary) -> void:
	if place["kind"] == STRIP or place["kind"] == MISSING_DEVICE or place["kind"] == BUS_BLOCK:
		return
	var desc: Dictionary = CabinetDevices.describe(doc, place["designation"])
	if place["kind"] == CabinetDevices.Kind.OVERLOAD:
		desc["standalone"] = true
	place["desc"] = desc
	if place.has("under_designation"):
		place["under_desc"] = CabinetDevices.describe(doc, place["under_designation"])


## Place of [param item], relative to the rail's centre line at x = 0.
static func _place(doc: SchematicDocument, strips: Dictionary, item: CabinetItem, k: float, net: Dictionary[String, int], apart: Dictionary[int, bool]) -> Dictionary:
	var place: Dictionary = {"designation": item.designation, "label_w": 0.0}
	if item.kind == CabinetItem.Kind.STRIP:
		var terminals: Array = strips.get(item.designation, [])
		place["kind"] = STRIP if not terminals.is_empty() else MISSING_DEVICE
		place["desc"] = {"terminals": terminals, "bridges": CabinetWiring.strip_bridges(terminals, net, apart)}
		if not terminals.is_empty():
			_box(place, Vector2(CabinetParts.terminal_strip_width(terminals.size(), k), CabinetParts.TERMINAL.y))
			return place
	else:
		var desc: Dictionary = CabinetDevices.describe(doc, item.designation)
		place["desc"] = desc
		place["kind"] = desc.get("kind", MISSING_DEVICE)
	match place["kind"]:
		CabinetDevices.Kind.BREAKER, CabinetDevices.Kind.FUSE:
			_box(place, CabinetParts.device_size(place["desc"]))
			_label(place, Vector2(place["size"].x * 0.5, -LABEL_OFF), minf(maxf(place["size"].x - 2.0, 14.0), 16.0))
		CabinetDevices.Kind.TIMER:
			_box(place, CabinetParts.device_size(place["desc"]))
			_label(place, Vector2(CabinetParts.MODULE_W * 0.5, -LABEL_OFF), 14.0)
		CabinetDevices.Kind.RELAY:
			var relay: Vector2 = CabinetParts.device_size(place["desc"])
			_box(place, relay)
			_label(place, Vector2(relay.x * 0.5, -LABEL_OFF), clampf(relay.x, 11.0, 14.0))
		CabinetDevices.Kind.CONTACTOR:
			_box(place, CabinetParts.device_size(place["desc"]))
			var aux: int = (place["desc"]["aux"] as Array).size()
			_label(place, CabinetParts.contactor_label_at(aux), 16.0)
			var overload: String = place["desc"].get("overload", "")
			if not overload.is_empty():
				place["under_designation"] = overload
				# The first side block goes on the right (see CabinetParts.side_blocks).
				place["channel"] = WIRE_CHANNEL + SIDE_BLOCK_CHANNEL * ceili(CabinetParts.side_block_count(aux) / 2.0)
				place["under_desc"] = CabinetDevices.describe(doc, overload)
				# Under the contactor itself, between its side blocks.
				place["under_origin"] = Vector2(CabinetParts.contactor_left(aux), place["origin"].y + CabinetParts.CONTACTOR.y)
				place["under_rect"] = Rect2(place["under_origin"], CabinetParts.OVERLOAD)
				place["under_label_at"] = place["under_origin"] + Vector2(CabinetParts.OVERLOAD.x * 0.5, CabinetParts.OVERLOAD.y + LABEL_OFF)
				place["bottom"] = place["under_rect"].end.y
		CabinetDevices.Kind.RECTIFIER:
			_box(place, CabinetParts.device_size(place["desc"]))
			_label(place, Vector2(CabinetParts.RECTIFIER.x * 0.5, -LABEL_OFF), 14.0)
		CabinetDevices.Kind.VFD:
			_box(place, CabinetParts.device_size(place["desc"]))
			_label(place, Vector2(CabinetParts.VFD.x * 0.5, -LABEL_OFF), 16.0)
		CabinetDevices.Kind.PLC:
			_box(place, CabinetParts.device_size(place["desc"]))
			_label(place, Vector2(CabinetParts.PLC.x * 0.5, -LABEL_OFF), 16.0)
		CabinetDevices.Kind.OVERLOAD:
			# On a rail of its own: on a mounting unit with the terminals
			# of its heaters (1, 3, 5) on top.
			place["desc"]["standalone"] = true
			_box(place, CabinetParts.device_size(place["desc"]))
			_label(place, Vector2(CabinetParts.OVERLOAD.x * 0.5, place["size"].y + LABEL_OFF), 12.0)
		_:
			place["kind"] = MISSING_DEVICE
			_box(place, MISSING)
	return place


## Sets the place's drawing [param size], centred on the rail.
static func _box(place: Dictionary, size: Vector2) -> void:
	place["size"] = size
	place["origin"] = Vector2(0.0, -size.y * 0.5)
	place["rect"] = Rect2(place["origin"], size)
	place["top"] = place["origin"].y
	place["bottom"] = place["origin"].y + size.y


## Puts the place's label centred at [param at] relative to its drawing:
## on the device's front or on the plate in the room over or under it (see
## [constant LABEL_OFF]), so it takes no room of its own.
static func _label(place: Dictionary, at: Vector2, width: float) -> void:
	place["label_at"] = place["origin"] + at
	place["label_w"] = width


## Moves a place laid out at x = 0 on a rail at y = 0 by [param offset]
## (its x along the rail is in its origin already).
static func _shift(place: Dictionary, offset: Vector2) -> void:
	var dx: float = place["origin"].x
	var by: Vector2 = Vector2(offset.x + dx, offset.y)
	place["origin"] = Vector2(offset.x + dx, place["origin"].y + offset.y)
	place["rect"] = Rect2(place["origin"], place["size"])
	if place.has("label_at"):
		place["label_at"] += by
	if place.has("under_origin"):
		place["under_origin"] += by
		place["under_rect"] = Rect2(place["under_origin"], CabinetParts.OVERLOAD)
		place["under_label_at"] += by
