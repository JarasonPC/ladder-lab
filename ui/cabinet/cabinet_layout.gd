class_name CabinetLayout
extends RefCounted
## Where everything of the switchboard sits, in millimetres: the enclosure
## with its mounting plate, the wire ducts (across above, between and below
## the rails, down both sides), the DIN rails and every place on them with
## its device's drawing, label and the area that answers clicks. Built from
## [member SchematicDocument.cabinet_rails] and the circuit (see
## [CabinetDevices]); the plate grows with the longest rail.

## Frame of the enclosure around the plate.
const FRAME: float = 6.0
## Width of the ducts down both sides, height of the ducts across.
const SIDE_DUCT: float = 25.0
const DUCT: float = 28.0
## Room between the side ducts and the rails, between places on a rail, and
## between a duct and the parts above or below it.
const MARGIN: float = 5.0
const GAP: float = 2.0
const PAD: float = 4.0
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

var size: Vector2 = Vector2.ZERO
## Ducts: {"rect": Rect2, "vertical": bool}.
var ducts: Array[Dictionary] = []
## DIN rails, one per [member SchematicDocument.cabinet_rails].
var rails: Array[Rect2] = []
## Places on the rails: {"rail", "index", "kind" (CabinetDevices.Kind, STRIP or
## MISSING_DEVICE), "designation", "desc" (see [method CabinetDevices.describe];
## for a strip {"terminals": [...]}), "origin" (top-left of the drawing),
## "size", "rect" (answers clicks), "label_at", "label_w" (no label when 0),
## and for a contactor with its overload relay "under_origin",
## "under_rect", "under_label_at", "under_designation"}.
var places: Array[Dictionary] = []


## Lays out the switchboard of [param doc]; [param k] (pixels per mm) makes
## the terminal strips as wide as they are drawn.
static func build(doc: SchematicDocument, k: float) -> CabinetLayout:
	var layout: CabinetLayout = CabinetLayout.new()
	var strips: Dictionary = CabinetDevices.strips(doc)
	# Each rail: its places relative to the rail's centre line and its extent.
	var rows: Array[Dictionary] = []
	var content: float = MIN_CONTENT
	for r: int in doc.cabinet_rails.size():
		var rail: CabinetRail = doc.cabinet_rails[r]
		var row: Dictionary = {"places": [], "top": -EMPTY_ROW * 0.5, "bottom": EMPTY_ROW * 0.5}
		var x: float = 0.0
		for i: int in rail.items.size():
			var place: Dictionary = _place(doc, strips, rail.items[i], k)
			place["rail"] = r
			place["index"] = i
			var slot: float = maxf(place["size"].x, place["label_w"])
			place["origin"] = Vector2(x + (slot - place["size"].x) * 0.5, place["origin"].y)
			x += slot + GAP
			row["places"].append(place)
			row["top"] = minf(row["top"], place["top"])
			row["bottom"] = maxf(row["bottom"], place["bottom"])
		content = maxf(content, x - GAP)
		rows.append(row)
	var x0: float = FRAME + SIDE_DUCT + MARGIN
	layout.size.x = 2.0 * x0 + content
	var y: float = FRAME + 2.0
	var across: Array[float] = [y]
	y += DUCT + PAD
	for row: Dictionary in rows:
		var cy: float = y - row["top"]
		layout.rails.append(Rect2(x0 - 2.0, cy - CabinetParts.RAIL_H * 0.5, content + 4.0, CabinetParts.RAIL_H))
		for place: Dictionary in row["places"]:
			_shift(place, Vector2(x0, cy))
			layout.places.append(place)
		y = cy + row["bottom"] + PAD
		across.append(y)
		y += DUCT + PAD
	if rows.is_empty():
		y += EMPTY_ROW
		across.append(y)
		y += DUCT + PAD
	layout.size.y = across[across.size() - 1] + DUCT + 2.0 + FRAME
	var duct_x: float = FRAME + SIDE_DUCT
	for duct_y: float in across:
		layout.ducts.append({"rect": Rect2(duct_x, duct_y, layout.size.x - 2.0 * duct_x, DUCT), "vertical": false})
	var down: float = layout.size.y - 2.0 * (FRAME + 2.0)
	layout.ducts.append({"rect": Rect2(FRAME + 2.0, FRAME + 2.0, SIDE_DUCT - 2.0, down), "vertical": true})
	layout.ducts.append({"rect": Rect2(layout.size.x - FRAME - SIDE_DUCT, FRAME + 2.0, SIDE_DUCT - 2.0, down), "vertical": true})
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


## Place of [param item], relative to the rail's centre line at x = 0.
static func _place(doc: SchematicDocument, strips: Dictionary, item: CabinetItem, k: float) -> Dictionary:
	var place: Dictionary = {"designation": item.designation, "label_w": 0.0}
	if item.kind == CabinetItem.Kind.STRIP:
		var terminals: Array = strips.get(item.designation, [])
		place["kind"] = STRIP if not terminals.is_empty() else MISSING_DEVICE
		place["desc"] = {"terminals": terminals}
		if not terminals.is_empty():
			_box(place, Vector2(CabinetParts.terminal_strip_width(terminals.size(), k), CabinetParts.TERMINAL.y))
			return place
	else:
		var desc: Dictionary = CabinetDevices.describe(doc, item.designation)
		place["desc"] = desc
		place["kind"] = desc.get("kind", MISSING_DEVICE)
	match place["kind"]:
		CabinetDevices.Kind.BREAKER, CabinetDevices.Kind.FUSE:
			_box(place, Vector2(CabinetParts.MODULE_W * int(place["desc"]["poles"]), CabinetParts.MODULE_H))
			var top_gap: float = 3.5 if place["kind"] == CabinetDevices.Kind.BREAKER else 0.5
			_label(place, Vector2(place["size"].x * 0.5, -top_gap), minf(maxf(place["size"].x - 2.0, 14.0), 16.0))
		CabinetDevices.Kind.TIMER:
			_box(place, Vector2(CabinetParts.MODULE_W, CabinetParts.MODULE_H))
			_label(place, Vector2(CabinetParts.MODULE_W * 0.5, -3.5), 14.0)
		CabinetDevices.Kind.RELAY:
			var relay: Vector2 = CabinetParts.relay_size(int(place["desc"]["poles"]))
			_box(place, relay)
			_label(place, Vector2(relay.x * 0.5, -3.5), clampf(relay.x, 11.0, 14.0))
		CabinetDevices.Kind.CONTACTOR:
			_box(place, CabinetParts.CONTACTOR)
			var aux: int = (place["desc"]["aux"] as Array).size()
			_label(place, CabinetParts.contactor_label_at(aux), 16.0)
			var overload: String = place["desc"].get("overload", "")
			if not overload.is_empty():
				place["under_designation"] = overload
				place["under_desc"] = CabinetDevices.describe(doc, overload)
				place["under_origin"] = Vector2(0.0, place["origin"].y + CabinetParts.CONTACTOR.y)
				place["under_rect"] = Rect2(place["under_origin"], CabinetParts.OVERLOAD)
				place["under_label_at"] = place["under_origin"] + Vector2(CabinetParts.OVERLOAD.x * 0.5, CabinetParts.OVERLOAD.y + 4.0)
				place["bottom"] = place["under_label_at"].y + 2.6
		CabinetDevices.Kind.RECTIFIER:
			_box(place, CabinetParts.RECTIFIER)
			_label(place, Vector2(CabinetParts.RECTIFIER.x * 0.5, -3.5), 14.0)
		CabinetDevices.Kind.OVERLOAD:
			_box(place, CabinetParts.OVERLOAD)
			_label(place, Vector2(CabinetParts.OVERLOAD.x * 0.5, CabinetParts.OVERLOAD.y + 4.0), 12.0)
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


## Puts the place's label centred at [param at] relative to its drawing.
static func _label(place: Dictionary, at: Vector2, width: float) -> void:
	place["label_at"] = place["origin"] + at
	place["label_w"] = width
	place["top"] = minf(place["top"], place["label_at"].y - 2.6)
	place["bottom"] = maxf(place["bottom"], place["label_at"].y + 2.6)


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
