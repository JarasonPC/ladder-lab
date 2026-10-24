class_name SingleLineCanvas
extends Control
## The consumer unit of a residential installation drawn as its single-line
## diagram (see [SingleLine]), as Czech projects draw it: the supply through
## the main switch onto busbars L1, L2, L3 and N across the sheet, a surge
## protective device, the PE and N bars, and the circuits hanging down from
## a dot on their busbar (the phases written beside them), a group's under its
## RCD (an outline with its test button) from busbars of their own (one a
## phase) with the group's N bar, a group under another one a level lower.
## Every conductor a device switches is drawn on its own, a pole each (the
## phases and an N pole; the poles of one device joined by a dashed link),
## and they come together into one line only at the circuit's outlet. Each
## circuit: its breaker (as on the schematic: the cross and the releases),
## designation and rating beside it, an AFDD with its caption and arc, the
## ripple control contact where it has one, the cable number on a ledger and
## the cable along the line, every part it feeds (light switches aside) one
## under another with its designation, drawn as on the floor plan
## ([PlanSymbols], hung from the line: [method draw_load]), where it goes and
## the room it goes to (a link to the floor plan). Wheel zooms at the
## mouse, right or middle drag pans.
##
## A click selects a device (the main switch too) or a part fed, Shift or Ctrl+click
## adds one or takes it out, a drag from an empty place selects what is in
## its box; with [method begin_place] the part from the palette goes where
## it is clicked (a breaker or RCD between the columns or into a group, a
## part onto the circuit under the mouse, the main switch where the
## diagram has none; a breaker, RCBO or AFDD takes the first circuit
## waiting for its protection); the devices selected dragged
## move their circuits or groups; while placing or dragging the diagram
## makes room where they go. Delete takes the selection away. A house
## installation is not simulated: the diagram is only edited.

## Changes the diagram: [param change] is called with the document.
signal edit_requested(change: Callable)
## Device or part [param designation] was selected ("" for none).
signal selection_changed(designation: String)
## The room link of a circuit was clicked.
signal room_requested(room: String)

const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 5.0
const ZOOM_STEP: float = 1.15
## Across the sheet, from one circuit to the next.
const SPACING: float = 84.0
## Across, from one pole of a device to the next; between the conductors
## of the surge protective device.
const POLE: float = 32.0
const SPD_POLE: float = 10.0
## Down, from one busbar of a group of three phases to the next.
const SUB_GAP: float = 12.0
## Gaps before and after a group, and before a circuit of an RCBO or AFDD
## (its release box beside it).
const GROUP_GAP: float = 0.95 * SPACING
const AFTER_GROUP: float = 0.6 * SPACING
const BOX_GAP: float = SPACING
## Gap after a circuit with its release box, for the next one's texts.
const AFTER_BOX: float = 0.55 * SPACING
## Down the sheet (u): the busbars, then the parts of a circuit.
const BUS_U: PackedFloat32Array = [0.0, 22.0, 44.0]
const N_U: float = 66.0
## Tops of the breaker of a circuit of its own, of the RCD, of a breaker in
## a group (each symbol 3 cells tall).
const BREAKER_U: float = 110.0
const RCD_U: float = 100.0
const GROUP_BREAKER_U: float = 246.0
## A group's N bar and busbar.
const N_BAR_U: float = 172.0
const SUB_BUS_U: float = 205.0
## Ripple control contact of a circuit of its own.
const HDO_U: float = 190.0
const LEDGER_U: float = 302.0
## The poles of a circuit run down to here and come together a little lower.
const MERGE_U: float = 40.0
const JOIN_U: float = 24.0
const LOAD_U: float = 410.0
const LOAD_R: float = 13.0
## Down, from one part a circuit feeds to the next; a metre of the floor
## plan's symbols (pixels at zoom 1).
const LOAD_STEP: float = 36.0
const LOAD_SCALE: float = 100.0
## Incoming: the main switch's column and its top, the SPD's column.
const MAIN_V: float = -100.0
const MAIN_U: float = -120.0
const SUPPLY_U: float = -175.0
const SPD_V: float = -18.0
const SPD_U: float = 136.0
const BAR_U: float = -76.0
## RCD: the release box right of its last pole.
const RCD_BOX := Rect2(20, 22, 22, 16)
const TEST_BUTTON := Vector2(31, 12)
const OUTLINE := Rect2(-14, 4, 62, 54)
## Text sizes at zoom 1.
const DESIGNATION_SIZE: float = 11.5
const DATA_SIZE: float = 10.5
const DEST_SIZE: float = 12.5
const SMALL_SIZE: float = 9.5
## A device's hold, around its symbol and its texts (local u, v).
const DEVICE_GRAB := Rect2(-6, -50, 72, 94)
## How much lower a group under another one is drawn: its RCD hangs from the
## other's busbar as a group's from the lowest busbar.
const LEVEL: float = SUB_BUS_U + 2.0 * SUB_GAP - 44.0
## A circuit without the additional protection of a 30 mA RCD: its mark
## (above the cable's ledger) and what it says.
const MARK_U: float = 30.0
const NO_RCD_TEXT: String = "No RCD of 30 mA or less protects this circuit. ČSN 33 2000-4-41 asks for one on every circuit an ordinary person (laik) can reach: sockets, lighting and what is fed in a home."


var document: SchematicDocument
var editing: bool = false
var zoom: float = 1.0
## Screen position of the point (u 0, v 0): the first busbar at the first column.
var offset: Vector2 = Vector2(260.0, 260.0)
## Device or part selected last ("" for none): the one whose properties show.
var selected: String = ""
## Every device and part selected.
var selection: PackedStringArray = PackedStringArray()
## The palette template put down by a click ({} while not placing).
var placing: Dictionary = {}
## Drawn for a sheet: no selection, placing or hint.
var sheet: bool = false

## Laid out by [method _layout]: per circuit {"designation", "v" (its
## outlet, its poles about it), "group" (the device it is directly under or
## ""), "depth" (how many groups it is under), "n_u" (the row its N comes
## from)}, per group {"designation", "v0" (its first pole), "v1" (the last
## pole on its busbars), "end" (the last circuit under it), "depth",
## "parent", "n_u"}; the deepest group's depth; the most parts a circuit
## feeds.
var _circuits: Array[Dictionary] = []
var _groups: Array[Dictionary] = []
var _end_v: float = 0.0
var _depth: int = 0
var _most_parts: int = 0
## A drag from an empty place selecting what is in its box (from that point).
var _banding: bool = false
var _band_from: Vector2 = Vector2.ZERO
## The press added to or took from the selection (no drag, no narrowing).
var _press_modified: bool = false
## Over the diagram, see-through: the parts being placed or dragged where
## they go ([member ghost_of]; null on that layer itself).
var _ghost_layer: SingleLineCanvas
## On the ghost layer: the devices drawn, the diagram they are drawn in,
## its layout, and the part being placed (not in the document yet).
var ghost_of: PackedStringArray = PackedStringArray()
var _drawn: SingleLine
var _ghost_laid: Dictionary = {}
var _ghost: CircuitComponent
## Devices not drawn (they are on the ghost layer).
var _hidden: PackedStringArray = PackedStringArray()
var _mouse: Vector2 = Vector2.ZERO
var _press: String = ""
var _press_at: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _pan_button: MouseButton = MOUSE_BUTTON_NONE
var _pan_from: Vector2 = Vector2.ZERO
var _font: Font


func _ready() -> void:
	focus_mode = Control.FOCUS_CLICK
	clip_contents = true


## Makes the ghost layer over it (not for a sheet or the layer itself).
func _enter_tree() -> void:
	if _ghost_layer != null or get_parent() is SingleLineCanvas:
		return
	_ghost_layer = SingleLineCanvas.new()
	_ghost_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ghost_layer.modulate = Color(1, 1, 1, 0.45)
	add_child(_ghost_layer, false, Node.INTERNAL_MODE_FRONT)


## The diagram drawn: the one previewed while placing or dragging.
func _shown() -> SingleLine:
	return _drawn if _drawn != null else line()


## Component [param designation], or the part being placed.
func _part(designation: String) -> CircuitComponent:
	if _ghost != null and designation == _ghost.designation:
		return _ghost
	return document.circuit.get_component(designation)


func line() -> SingleLine:
	return document.single_line if document != null else null


## Screen point of local point [param u] (along a circuit, down) and
## [param v] (across, to the right).
func at(u: float, v: float) -> Vector2:
	return offset + Vector2(v, u) * zoom


## Local (u, v) of screen point [param point].
func local(point: Vector2) -> Vector2:
	var p: Vector2 = (point - offset) / zoom
	return Vector2(p.y, p.x)


## Where the drawing is (local x = v across, y = u down), for fitting it and for a sheet.
func extent() -> Rect2:
	_layout()
	return Rect2(MAIN_V - 3.0 * POLE - 150.0, SUPPLY_U - 30.0, _end_v - MAIN_V + 3.0 * POLE + 230.0, _load_u() + maxi(_most_parts - 1, 0) * LOAD_STEP + 160.0 - SUPPLY_U)


## Shows everything, as large as fits.
func fit() -> void:
	var area: Rect2 = extent()
	if size.x < 10.0:
		return
	zoom = clampf(minf(size.x / area.size.x, size.y / area.size.y), MIN_ZOOM, 1.6)
	offset = size * 0.5 - area.get_center() * zoom
	queue_redraw()


## Puts [param template] where the next click goes.
func begin_place(template: Dictionary) -> void:
	placing = template
	_ghost = null
	if document != null and str(template.get("type", "")) in ["breaker", "rcd", "afdd"]:
		var data: Dictionary = template.duplicate()
		data["designation"] = new_designation(document, template)
		_ghost = DocumentSerializer.component_from_dict(data)
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	queue_redraw()


func end_place() -> void:
	placing = {}
	_ghost = null
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


# --- Layout -----------------------------------------------------------------------------

func _layout() -> void:
	_apply(_layout_of(line()))


func _apply(laid: Dictionary) -> void:
	_circuits = laid["circuits"]
	_groups = laid["groups"]
	_end_v = laid["end_v"]
	_depth = laid["depth"]
	_most_parts = laid["parts"]


## The layout of [param l] (see [member _circuits]); circuits of
## [param boxed] (designations) are taken for RCBOs or AFDDs.
func _layout_of(l: SingleLine, boxed: PackedStringArray = PackedStringArray()) -> Dictionary:
	var circuits: Array[Dictionary] = []
	var groups: Array[Dictionary] = []
	var laid: Dictionary = {"circuits": circuits, "groups": groups, "end_v": SPACING * 1.15, "depth": 0, "parts": 0}
	if l != null:
		laid["end_v"] = _lay(l.columns, 0, "", SPACING * 1.15, laid, boxed, N_U)
	return laid


## Lays out circuits and groups [param list] under group [param parent]
## ("" for the busbars), [param depth] groups deep, from [param v], their N
## from row [param n_u]; returns where the next one would go.
func _lay(list: Array[RefCounted], depth: int, parent: String, v: float, laid: Dictionary, boxed: PackedStringArray, n_u: float) -> float:
	var after_group: bool = false
	# The last circuit had its release box right of it.
	var after_box: bool = false
	for k: int in list.size():
		var item: RefCounted = list[k]
		if item is SingleLine.Group:
			var g: SingleLine.Group = item as SingleLine.Group
			# Room for its RCD's texts, left of it.
			if depth == 0 or k > 0:
				v += GROUP_GAP
			var entry: Dictionary = {"designation": g.device, "v0": v, "v1": v, "end": v, "depth": depth, "parent": parent, "n_u": n_u}
			(laid["groups"] as Array[Dictionary]).append(entry)
			laid["depth"] = maxi(int(laid["depth"]), depth)
			var head: CircuitComponent = _part(g.device) if document != null else null
			var head_width: float = (pole_count(head) - 1) * POLE
			if g.items.is_empty():
				v += SPACING + head_width
			else:
				# Under its N bar (an RCD's, an AFDD's), else the N it has.
				var n_under: float = _n_bar_u(depth) + 10.0 if SingleLine.has_n_pole(head) else n_u
				# Under a device of three phases its circuits start right of its
				# poles, so none hangs in line with a pole as if fed by it.
				var start: float = v + head_width + POLE if SingleLine.phase_count(head) > 1 else v
				v = _lay(g.items, depth + 1, g.device, start, laid, boxed, n_under)
				entry["v1"] = maxf(_attach_end(laid, g.items), entry["v0"] + head_width)
				v = maxf(v, float(entry["v0"]) + head_width + SPACING)
			entry["end"] = maxf(v - SPACING, float(entry["v0"]))
			after_group = true
			after_box = false
		else:
			var designation: String = (item as SingleLine.Feeder).device
			var device: CircuitComponent = _part(designation) if document != null else null
			var is_boxed: bool = device is ResidualCurrentDevice or device is ArcFaultDevice or boxed.has(designation)
			# Room for the texts of an RCBO or AFDD (its box right of the one before).
			if after_group or (is_boxed and (depth == 0 or k > 0)):
				v += maxf(AFTER_GROUP if after_group else 0.0, BOX_GAP if is_boxed else 0.0)
			elif after_box:
				v += AFTER_BOX
			after_group = false
			after_box = is_boxed
			# Its poles about its outlet.
			var half: float = (pole_count(device) - 1) * POLE * 0.5 if device != null else 0.0
			v += half
			(laid["circuits"] as Array[Dictionary]).append({"designation": designation, "v": v, "group": parent, "depth": depth, "n_u": n_u})
			if document != null:
				laid["parts"] = maxi(int(laid["parts"]), _parts_of(item as SingleLine.Feeder).size())
			v += SPACING + half
	return v


## The last pole of what is in [param list] in [param laid] (across): how far a group's busbars go.
func _attach_end(laid: Dictionary, list: Array[RefCounted]) -> float:
	var end: float = -INF
	for item: RefCounted in list:
		var designation: String = SingleLine.device_of(item)
		var c: CircuitComponent = _part(designation)
		for entry: Dictionary in laid["circuits"]:
			if entry["designation"] == designation:
				end = maxf(end, float(entry["v"]) + (pole_count(c) - 1) * POLE * 0.5)
		for entry: Dictionary in laid["groups"]:
			if entry["designation"] == designation:
				end = maxf(end, float(entry["v0"]) + (pole_count(c) - 1) * POLE)
	return end


## How many poles device [param c] has drawn: its phases and its N pole.
static func pole_count(c: CircuitComponent) -> int:
	if c == null:
		return 1
	return SingleLine.phase_count(c) + (1 if SingleLine.has_n_pole(c) else 0)


## The parts circuit [param f] feeds that the diagram draws (light switches left out).
func _parts_of(f: SingleLine.Feeder) -> Array[CircuitComponent]:
	var list: Array[CircuitComponent] = []
	if f == null:
		return list
	for designation: String in f.loads:
		var c: CircuitComponent = document.circuit.get_component(designation)
		if c != null and not (c is LightSwitch):
			list.append(c)
	return list


func _group_entry(designation: String) -> Dictionary:
	for entry: Dictionary in _groups:
		if entry["designation"] == designation:
			return entry
	return {}


## Rows (u) of a group [param depth] deep: its RCD, N bar and busbar.
static func _rcd_u(depth: int) -> float:
	return RCD_U + depth * LEVEL


static func _n_bar_u(depth: int) -> float:
	return N_BAR_U + depth * LEVEL


static func _sub_bus_u(depth: int) -> float:
	return SUB_BUS_U + depth * LEVEL


## Top of the breaker of a circuit under [param depth] groups.
static func _breaker_u(depth: int) -> float:
	return BREAKER_U if depth == 0 else GROUP_BREAKER_U + (depth - 1) * LEVEL


## The rows of the cables and of what they feed: lower for groups in groups.
## The cables' ledger: under the lowest breaker, with room for its poles to
## come together over it (a breaker in a group is lower than one of its own).
func _ledger_u() -> float:
	if _groups.is_empty():
		return LEDGER_U
	return maxf(LEDGER_U, _breaker_u(_depth + 1) + 60.0 + MERGE_U + 22.0)


func _load_u() -> float:
	return _ledger_u() + LOAD_U - LEDGER_U


func _circuit_entry(designation: String) -> Dictionary:
	for entry: Dictionary in _circuits:
		if entry["designation"] == designation:
			return entry
	return {}


# --- Finding things -------------------------------------------------------------------

## What is under screen point [param point]: {"kind": "device" / "load" /
## "main" / "hdo" / "test" / "room" / "warning", "designation"}, {} for nothing.
func thing_at(point: Vector2) -> Dictionary:
	_layout()
	var p: Vector2 = local(point)
	var u: float = p.x
	var v: float = p.y
	if line().main_switch and v > _main_v(0) - 24.0 and v < _main_v(3) + 10.0 and u > MAIN_U - 6.0 and u < MAIN_U + 66.0:
		return {"kind": "main", "designation": SingleLine.MAIN}
	for g: Dictionary in _groups:
		var head: CircuitComponent = document.circuit.get_component(g["designation"])
		var poles: PackedFloat32Array = _group_poles(g["v0"], head)
		var ru: float = _rcd_u(g["depth"])
		if _has_box(head) and Vector2(u, v).distance_to(Vector2(ru + TEST_BUTTON.y, poles[poles.size() - 1] + TEST_BUTTON.x)) < 6.0:
			return {"kind": "test", "designation": g["designation"]}
		if _grab(ru, poles).has_point(Vector2(u, v)):
			return {"kind": "device", "designation": g["designation"]}
	for entry: Dictionary in _circuits:
		var cv: float = entry["v"]
		var f: SingleLine.Feeder = line().feeder_of(entry["designation"])
		if f == null:
			continue
		var top: float = _breaker_u(entry["depth"])
		var device: CircuitComponent = document.circuit.get_component(f.device)
		var poles: PackedFloat32Array = _circuit_poles(cv, device)
		if _has_box(device) and Vector2(u, v).distance_to(Vector2(top + TEST_BUTTON.y, poles[poles.size() - 1] + TEST_BUTTON.x)) < 6.0:
			return {"kind": "test", "designation": f.device}
		if _grab(top, poles).has_point(Vector2(u, v)):
			return {"kind": "device", "designation": f.device}
		if line().switched_by_hdo(f) and absf(v - poles[0]) < 14.0 and u > HDO_U - 4.0 and u < HDO_U + 44.0:
			return {"kind": "hdo", "designation": SingleLine.HDO}
		if line().lacks_rcd(f, document.circuit) and Vector2(u, v).distance_to(Vector2(_ledger_u() - MARK_U, cv + 14.0)) < 9.0:
			return {"kind": "warning", "designation": f.device}
		var parts: Array[CircuitComponent] = _parts_of(f)
		for i: int in parts.size():
			if v > cv - 4.0 and v < cv + SPACING - 14.0 and absf(u - _part_u(i)) < LOAD_STEP * 0.5:
				return {"kind": "load", "designation": parts[i].designation}
		var below: float = _part_u(maxi(parts.size() - 1, 0)) + 18.0
		if not f.room.is_empty() and v > cv + 6.0 and v < cv + 22.0 and u > below and u < below + 100.0:
			return {"kind": "room", "designation": f.room}
	return {}


## The hold of a device whose symbol's top is [param top], its poles at [param poles] (local u, v).
static func _grab(top: float, poles: PackedFloat32Array) -> Rect2:
	var first: float = poles[0]
	var last: float = poles[poles.size() - 1]
	return Rect2(top + DEVICE_GRAB.position.x, first + DEVICE_GRAB.position.y, DEVICE_GRAB.size.x, DEVICE_GRAB.size.y + last - first)


## Whether [param c] has a release box: an RCD, RCBO or AFDD.
static func _has_box(c: CircuitComponent) -> bool:
	return c is ResidualCurrentDevice or c is ArcFaultDevice


## Across, the poles of a circuit's device [param c] about its outlet at [param v].
static func _circuit_poles(v: float, c: CircuitComponent) -> PackedFloat32Array:
	var n: int = pole_count(c)
	var list: PackedFloat32Array = PackedFloat32Array()
	for k: int in n:
		list.append(v + (k - (n - 1) * 0.5) * POLE)
	return list


## Across, the poles of a group's device [param c] from its first at [param v0].
static func _group_poles(v0: float, c: CircuitComponent) -> PackedFloat32Array:
	var list: PackedFloat32Array = PackedFloat32Array()
	for k: int in pole_count(c):
		list.append(v0 + k * POLE)
	return list


## Across, pole [param k] of the main switch (L1 L2 L3 N, N on [constant MAIN_V]).
static func _main_v(k: int) -> float:
	return MAIN_V + (k - 3) * POLE


## Down, the row phase [param ph] comes from under device [param parent]:
## a busbar of its group (one a phase under a device of three), or the
## main busbar of that phase for "".
func _row_u(parent: String, ph: int) -> float:
	if parent.is_empty():
		return BUS_U[clampi(ph, 1, 3) - 1]
	var g: Dictionary = _group_entry(parent)
	if g.is_empty():
		return BUS_U[clampi(ph, 1, 3) - 1]
	var three: bool = SingleLine.phase_count(_part(parent)) > 1
	return _sub_bus_u(g["depth"]) + ((clampi(ph, 1, 3) - 1) * SUB_GAP if three else 0.0)


## Down, part [param index] of a circuit's parts.
func _part_u(index: int) -> float:
	return _load_u() + index * LOAD_STEP


## Where [param template] (or the devices being dragged, [param moving])
## would go at screen point [param point]: {"index": in the columns or the
## group's items, counted without the ones moved, "into": the group's RCD
## or "", "feeder": the circuit fed or ""}, {} for nowhere.
func drop_target(point: Vector2, template: Dictionary, moving: PackedStringArray = PackedStringArray()) -> Dictionary:
	_layout()
	var p: Vector2 = local(point)
	var u: float = p.x
	var v: float = p.y
	var kind: String = str(template.get("type", ""))
	if moving.is_empty() and kind == "cam_switch":
		return {} if line().main_switch else {"index": 0, "into": "", "feeder": "", "main": true}
	if moving.is_empty() and kind in ["socket", "luminaire", "appliance"]:
		for entry: Dictionary in _circuits:
			if absf(v - float(entry["v"])) < SPACING * 0.5:
				return {"feeder": entry["designation"], "index": 0, "into": ""}
		return {}
	# Into the deepest group under whose busbar it is, within what is under
	# it, or under a circuit feeding nothing (below its breaker).
	var into: String = ""
	var deepest: int = -1
	for g: Dictionary in _groups:
		if int(g["depth"]) <= deepest or u < _sub_bus_u(g["depth"]) - 20.0:
			continue
		if v < float(g["v0"]) - SPACING * 0.5 or v > float(g["end"]) + SPACING * 0.5:
			continue
		if _moves_along(g["designation"], moving):
			continue
		into = g["designation"]
		deepest = g["depth"]
	for entry: Dictionary in _circuits:
		var designation: String = entry["designation"]
		if int(entry["depth"]) <= deepest or absf(v - float(entry["v"])) > SPACING * 0.35:
			continue
		if u < _breaker_u(entry["depth"]) + 64.0 or u > _ledger_u() - 6.0:
			continue
		if moving.has(designation) or _moves_along(designation, moving) or not line().can_hold(designation):
			continue
		into = designation
		deepest = entry["depth"]
	if not into.is_empty():
		var poles: Array[int] = []
		if moving.is_empty():
			poles.append(_template_poles(template))
		for designation: String in moving:
			poles.append(SingleLine.phase_count(document.circuit.get_component(designation)))
		for n: int in poles:
			if not line().fits_poles(document, n, into):
				return {}
	var parent: SingleLine.Group = line().group_of(into) if not into.is_empty() else null
	var list: Array[RefCounted] = []
	if parent != null:
		list = parent.items
	elif into.is_empty():
		list = line().columns
	var index: int = 0
	for item: RefCounted in list:
		if moving.has(SingleLine.device_of(item)):
			continue
		var span: Vector2 = _span(item)
		if v > (span.x + span.y) * 0.5:
			index += 1
	return {"index": index, "into": into, "feeder": ""}


## Whether device [param designation] is one of [param moving] or under one.
func _moves_along(designation: String, moving: PackedStringArray) -> bool:
	var at: RefCounted = line().item_of(designation)
	for m: String in moving:
		var item: RefCounted = line().item_of(m)
		if item is SingleLine.Group and line().is_under(at, item as SingleLine.Group):
			return true
	return moving.has(designation)


## Phases a device made from [param template] takes.
static func _template_poles(template: Dictionary) -> int:
	match str(template.get("type", "")):
		"rcd":
			return 3 if int(template.get("poles", 2)) == 4 else 1
		"breaker":
			var poles: int = int(template.get("poles", 1))
			return mini(poles - (1 if poles == 4 or (poles == 2 and template.get("n_pole", false) == true) else 0), 3)
	return 1


## Across (v) what circuit or group [param item] takes: from its left to its right.
func _span(item: RefCounted) -> Vector2:
	if item is SingleLine.Group:
		var g: Dictionary = _group_entry((item as SingleLine.Group).device)
		return Vector2(float(g["v0"]) - SPACING * 0.5, float(g["end"]) + SPACING * 0.5)
	var c: Dictionary = _circuit_entry((item as SingleLine.Feeder).device)
	return Vector2(float(c["v"]) - SPACING * 0.5, float(c["v"]) + SPACING * 0.5)


## The diagram as it would be with [param template] or [param moving] put
## where [param target] says: {"laid": its layout, "marks": where the parts
## put go (v), "into": the group they go into or ""}.
func _preview(target: Dictionary, template: Dictionary, moving: PackedStringArray) -> Dictionary:
	var copy: SingleLine = SingleLine.from_data(line().to_data())
	var parent: SingleLine.Group = copy.open_group(target["into"]) if not str(target["into"]).is_empty() else null
	var placed: Array[RefCounted] = []
	var boxed: PackedStringArray = PackedStringArray()
	if moving.is_empty():
		if _ghost == null:
			return {}
		var head: bool = SingleLine.heads_group(_ghost)
		placed.append(SingleLine.Group.new(_ghost.designation) if head else SingleLine.Feeder.new(_ghost.designation))
		if not head and SingleLine.has_n_pole(_ghost):
			boxed.append(_ghost.designation)
	else:
		for item: RefCounted in copy.items():
			if not moving.has(SingleLine.device_of(item)):
				continue
			var along: bool = false
			var g: SingleLine.Group = copy.group_holding(item)
			while g != null:
				along = along or moving.has(g.device)
				g = copy.group_holding(g)
			if not along:
				placed.append(item)
		for item: RefCounted in placed:
			copy.list_holding(item).erase(item)
	var list: Array[RefCounted] = parent.items if parent != null else copy.columns
	var at: int = clampi(int(target["index"]), 0, list.size())
	for k: int in placed.size():
		list.insert(at + k, placed[k])
		if parent != null and SingleLine._single_phase(document.circuit, parent.device):
			copy._set_phase_of(placed[k], parent.phase)
	var laid: Dictionary = _layout_of(copy, boxed)
	# What goes, with what is under it: drawn on the ghost layer.
	var shown: PackedStringArray = PackedStringArray()
	for item: RefCounted in placed:
		var list_of: Array[RefCounted] = [item]
		if item is SingleLine.Group:
			SingleLine._collect((item as SingleLine.Group).items, list_of)
		for sub: RefCounted in list_of:
			shown.append(SingleLine.device_of(sub))
	return {"laid": laid, "line": copy, "shown": shown}


# --- Input ----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if document == null:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and editing:
		if key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE:
			delete_selected()
			accept_event()
		elif key.keycode == KEY_ESCAPE and not placing.is_empty():
			end_place()
			accept_event()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		_on_button(mb)
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	_mouse = motion.position
	if _pan_button != MOUSE_BUTTON_NONE:
		offset += motion.relative
		queue_redraw()
	elif not _press.is_empty() and not _dragging and motion.position.distance_to(_press_at) >= SchematicEditor.CLICK_SLOP:
		_dragging = true
	if not placing.is_empty() or _dragging or _banding or _pan_button != MOUSE_BUTTON_NONE:
		queue_redraw()
	tooltip_text = _tooltip(thing_at(motion.position))
	accept_event()


func _on_button(mb: InputEventMouseButton) -> void:
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var before: Vector2 = (mb.position - offset) / zoom
				zoom = clampf(zoom * (ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP), MIN_ZOOM, MAX_ZOOM)
				offset = mb.position - before * zoom
				queue_redraw()
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_pan_button = mb.button_index
				_pan_from = mb.position
			elif mb.button_index == _pan_button:
				_pan_button = MOUSE_BUTTON_NONE
				# A right click ends placing.
				if mb.button_index == MOUSE_BUTTON_RIGHT and mb.position.distance_to(_pan_from) < SchematicEditor.CLICK_SLOP and not placing.is_empty():
					end_place()
		MOUSE_BUTTON_LEFT:
			if not editing:
				return
			if mb.pressed:
				if not placing.is_empty():
					_place(mb.position)
					return
				var thing: Dictionary = thing_at(mb.position)
				if thing.get("kind", "") == "room":
					room_requested.emit(thing["designation"])
					return
				var adding: bool = mb.shift_pressed or mb.ctrl_pressed or mb.meta_pressed
				var designation: String = thing.get("designation", "") if thing.get("kind", "") in ["device", "load", "main"] else ""
				_press_at = mb.position
				_dragging = false
				_press_modified = adding
				if designation.is_empty():
					# A box from here selects what is in it.
					if not adding:
						_select("")
					_banding = true
					_band_from = mb.position
					_press = ""
					return
				if adding:
					_toggle(designation)
				elif not selection.has(designation):
					_select(designation)
				else:
					# Kept with the others to drag them all.
					_set_primary(designation)
				_press = designation if thing.get("kind", "") == "device" and selection.has(designation) else ""
			elif _banding:
				_banding = false
				_select_box(_band_from, mb.position, _press_modified)
				queue_redraw()
			elif not _press.is_empty():
				var moving: String = _press
				_press = ""
				if _dragging:
					_dragging = false
					_move(_moving_with(moving), mb.position)
				elif not _press_modified:
					_select(moving)
				queue_redraw()


func _select(designation: String) -> void:
	var only: PackedStringArray = PackedStringArray([designation]) if not designation.is_empty() else PackedStringArray()
	if designation == selected and selection == only:
		return
	selection = only
	selected = designation
	selection_changed.emit(designation)
	queue_redraw()


## [param designation] is the one whose properties show, the selection kept.
func _set_primary(designation: String) -> void:
	if designation != selected:
		selected = designation
		selection_changed.emit(designation)
	queue_redraw()


## Adds [param designation] to the selection or takes it out.
func _toggle(designation: String) -> void:
	if selection.has(designation):
		selection.remove_at(selection.find(designation))
		_set_primary(selection[selection.size() - 1] if not selection.is_empty() else "")
	else:
		selection.append(designation)
		_set_primary(designation)


## Selects the devices and parts in the box from screen point [param a] to
## [param b] (with [param adding] besides those selected).
func _select_box(a: Vector2, b: Vector2, adding: bool) -> void:
	_layout()
	var box: Rect2 = Rect2(local(a), Vector2.ZERO).expand(local(b))
	if box.size.length() * zoom < SchematicEditor.CLICK_SLOP:
		return
	var found: PackedStringArray = selection.duplicate() if adding else PackedStringArray()
	for point: Dictionary in _anchors():
		if box.has_point(point["at"]) and not found.has(point["designation"]):
			found.append(point["designation"])
	selection = found
	_set_primary(found[found.size() - 1] if not found.is_empty() else "")


## Where each device and part fed is (local u, v): {"designation", "at"}.
func _anchors() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if line().main_switch:
		list.append({"designation": SingleLine.MAIN, "at": Vector2(MAIN_U + 30.0, _main_v(0))})
	for g: Dictionary in _groups:
		list.append({"designation": g["designation"], "at": Vector2(_rcd_u(g["depth"]) + 30.0, g["v0"])})
	for entry: Dictionary in _circuits:
		list.append({"designation": entry["designation"], "at": Vector2(_breaker_u(entry["depth"]) + 30.0, entry["v"])})
		var parts: Array[CircuitComponent] = _parts_of(line().feeder_of(entry["designation"]))
		for i: int in parts.size():
			list.append({"designation": parts[i].designation, "at": Vector2(_part_u(i), float(entry["v"]) + 20.0)})
	return list


## The devices dragged along with [param designation]: the ones selected,
## when it is one of them.
func _moving_with(designation: String) -> PackedStringArray:
	if not selection.has(designation):
		return PackedStringArray([designation])
	var list: PackedStringArray = PackedStringArray()
	for d: String in selection:
		if line().item_of(d) != null:
			list.append(d)
	return list


## Selects [param designation] without telling (it was selected elsewhere).
func show_selected(designation: String) -> void:
	selected = designation
	selection = PackedStringArray([designation]) if not designation.is_empty() else PackedStringArray()
	queue_redraw()


func _place(point: Vector2) -> void:
	var target: Dictionary = drop_target(point, placing)
	if target.is_empty():
		return
	var template: Dictionary = placing.duplicate()
	var index: int = target["index"]
	var into: String = target["into"]
	var feeder: String = target["feeder"]
	# A breaker, RCBO or AFDD protects the first circuit waiting for it.
	var waiting: SingleLine.Feeder = line().first_waiting()
	var number: int = waiting.number if waiting != null else 0
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		var data: Dictionary = template.duplicate()
		data["designation"] = new_designation(doc, template)
		var c: CircuitComponent = DocumentSerializer.component_from_dict(data)
		if c != null:
			doc.single_line.add(doc, c, index, into, feeder, number))


func _move(designations: PackedStringArray, point: Vector2) -> void:
	var target: Dictionary = drop_target(point, {"type": "breaker"}, designations)
	if target.is_empty():
		return
	var index: int = target["index"]
	var into: String = target["into"]
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.single_line.move_many(doc, designations, index, into))


## Takes the selection away in one edit: each device (what is under an RCD
## stays; a circuit's parts on a floor plan wait for another device, the
## others go with it), each part fed.
func delete_selected() -> void:
	var chosen: PackedStringArray = PackedStringArray()
	for designation: String in selection:
		if document.circuit.get_component(designation) != null:
			chosen.append(designation)
	if chosen.is_empty():
		return
	_select("")
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		var gone: PackedStringArray = PackedStringArray()
		for designation: String in chosen:
			gone.append(designation)
			var f: SingleLine.Feeder = doc.single_line.feeder_of(designation)
			if f != null:
				for load: String in f.loads:
					if doc.floor_of(load) < 0:
						gone.append(load)
		for d: String in gone:
			var c: CircuitComponent = doc.circuit.get_component(d)
			if c != null:
				doc.remove_component(c.id))


## Designation of a new part made from [param template] in [param doc].
static func new_designation(doc: SchematicDocument, template: Dictionary) -> String:
	match str(template.get("type", "")):
		"cam_switch":
			return SingleLine.MAIN
		"breaker":
			return doc.next_device_designation("FA")
		"rcd", "afdd":
			return doc.next_designation("FB")
		"light_switch":
			return doc.next_designation("SF")
		"luminaire":
			return doc.next_designation("EA")
		"socket":
			return doc.next_designation("XD")
		"appliance":
			return doc.next_designation(Appliance.letters(maxi(Appliance.KIND_NAMES.find(str(template.get("kind", ""))), 0) as Appliance.Kind))
	return doc.next_designation("X")


func _tooltip(thing: Dictionary) -> String:
	match thing.get("kind", ""):
		"main":
			return tr("Main switch: Delete takes it away (the supply then goes straight onto the busbars)")
		"hdo":
			return tr("Ripple control contactor (HDO, low tariff)")
		"room":
			return tr("Show room %s on the floor plan") % thing["designation"]
		"warning":
			return NO_RCD_TEXT
		"device":
			return tr("Drag to move its circuit (the ones selected along); Shift+click selects more; Delete takes them away")
	return ""


# --- Drawing --------------------------------------------------------------------------

func _draw() -> void:
	if get_parent() is SingleLineCanvas:
		_draw_ghost()
		return
	draw_rect(Rect2(Vector2.ZERO, size), SchematicTheme.BACKGROUND)
	if document == null:
		return
	_font = get_theme_default_font()
	# While placing or dragging, the diagram as it will be, the parts put
	# marked where they go.
	var preview: Dictionary = {}
	var fed: Dictionary = {}
	if editing and not sheet and (not placing.is_empty() or (_dragging and not _press.is_empty())):
		var moving: PackedStringArray = _moving_with(_press) if placing.is_empty() else PackedStringArray()
		var target: Dictionary = drop_target(_mouse, placing if not placing.is_empty() else {"type": "breaker"}, moving)
		if not target.is_empty() and str(target["feeder"]).is_empty():
			preview = _preview(target, placing, moving)
		elif not target.is_empty():
			fed = target
	_hidden = PackedStringArray()
	_drawn = null
	if preview.is_empty():
		_layout()
	else:
		_apply(preview["laid"])
		_drawn = preview["line"]
		_hidden = preview["shown"]
	_show_ghost(preview)
	_draw_busbars()
	_draw_incoming()
	for g: Dictionary in _groups:
		if not _hidden.has(g["designation"]):
			_draw_group(g)
	for entry: Dictionary in _circuits:
		if not _hidden.has(entry["designation"]):
			_draw_circuit(entry)
	_drawn = null
	if sheet:
		return
	if not fed.is_empty():
		# Where the part goes: under the circuit's last part.
		var v: float = _circuit_entry(fed["feeder"]).get("v", 0.0)
		var next: int = _parts_of(line().feeder_of(fed["feeder"])).size()
		draw_arc(at(_part_u(next), v + 18.0), (LOAD_R + 6.0) * zoom, 0.0, TAU, 32, SchematicTheme.HOVER, 2.0, true)
	if _banding:
		var box: Rect2 = Rect2(_band_from, Vector2.ZERO).expand(_mouse)
		draw_rect(box, Color(SchematicTheme.SELECTED, 0.12))
		draw_rect(box, SchematicTheme.SELECTED, false, 1.0)
	if line().columns.is_empty() and editing:
		draw_string(_font, Vector2(20, 30), tr("Pick a circuit breaker or an RCD in the palette and click under the busbars to add a circuit."), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(SchematicTheme.LINE, 0.6))


## Shows the parts placed or dragged of [param preview] on the ghost layer
## (nothing for an empty one).
func _show_ghost(preview: Dictionary) -> void:
	if _ghost_layer == null:
		return
	_ghost_layer.document = document
	_ghost_layer.zoom = zoom
	_ghost_layer.offset = offset
	_ghost_layer._ghost = _ghost
	_ghost_layer.ghost_of = preview.get("shown", PackedStringArray())
	_ghost_layer._ghost_laid = preview.get("laid", {})
	_ghost_layer._drawn = preview.get("line", null)
	_ghost_layer.queue_redraw()


## On the ghost layer: the parts placed or dragged, where they go.
func _draw_ghost() -> void:
	if ghost_of.is_empty() or document == null or _ghost_laid.is_empty():
		return
	_font = get_theme_default_font()
	_apply(_ghost_laid)
	for g: Dictionary in _groups:
		if ghost_of.has(g["designation"]):
			_draw_group(g)
	for entry: Dictionary in _circuits:
		if ghost_of.has(entry["designation"]):
			_draw_circuit(entry)


func _width(color: Color) -> float:
	return clampf(1.4 * zoom, 1.0, 3.0) * (1.4 if color != SchematicTheme.LINE else 1.0)


func _seg(u1: float, v1: float, u2: float, v2: float, color: Color = SchematicTheme.LINE, width: float = -1.0) -> void:
	draw_line(at(u1, v1), at(u2, v2), color, _width(color) if width < 0.0 else width * zoom, true)


func _poly(points: PackedVector2Array, color: Color, width: float = -1.0) -> void:
	var screen: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		screen.append(at(p.x, p.y))
	draw_polyline(screen, color, _width(color) if width < 0.0 else width * zoom, true)


func _dot(u: float, v: float, color: Color) -> void:
	draw_circle(at(u, v), 2.7 * zoom, color)


## Text along a circuit, read from the bottom up, from [param u] down (or
## centred on it with [param middle]), centred on [param v].
func _along(u: float, v: float, text: String, text_size: float, color: Color, middle: bool = false, underline: bool = false) -> void:
	var fs: int = maxi(roundi(text_size * zoom), 1)
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var start: Vector2 = at(u, v) + Vector2(0, width * 0.5 if middle else width)
	draw_set_transform(start, -PI / 2.0)
	var baseline: float = (_font.get_ascent(fs) - _font.get_descent(fs)) * 0.5
	draw_string(_font, Vector2(0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	if underline:
		draw_line(Vector2(0, baseline + 2.0), Vector2(width, baseline + 2.0), color, maxf(zoom, 1.0))
	draw_set_transform(Vector2.ZERO)


## Lines of text across, beside the circuit at [param u]: before it (to the
## left) or after it, [param gap] away. [param lines]: [text, size, colour].
func _across(u: float, v: float, lines: Array, before: bool, gap: float = 14.0) -> void:
	var lh: float = 13.0 * zoom
	var y0: float = at(u, v).y - (lines.size() - 1) * lh * 0.5
	for i: int in lines.size():
		var text: String = lines[i][0]
		var fs: int = maxi(roundi(float(lines[i][1]) * zoom), 1)
		var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x: float = at(u, v).x - gap * zoom - width if before else at(u, v).x + gap * zoom
		var baseline: float = (_font.get_ascent(fs) - _font.get_descent(fs)) * 0.5
		draw_string(_font, Vector2(x, y0 + i * lh + baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lines[i][2])


## Designations as on the drawing: "-FA1".
static func _dash(designation: String) -> String:
	return "-" + designation


static func designation_color() -> Color:
	return Color("5fd08a") if SchematicTheme.dark else Color("1c9a3c")


static func data_color() -> Color:
	return Color("e08ccb") if SchematicTheme.dark else Color("c92f93")


static func link_color() -> Color:
	return Color("86adff") if SchematicTheme.dark else Color("2453d1")


static func afdd_color() -> Color:
	return Color("ff7d6b") if SchematicTheme.dark else Color("e2261c")


func _draw_busbars() -> void:
	var v1: float = _end_v - SPACING * 0.4
	# Each from where its conductor comes onto it.
	for k: int in 3:
		_seg(BUS_U[k], _main_v(k), BUS_U[k], v1, SchematicTheme.LINE, 1.6)
		_across(BUS_U[k], v1, [["L%d" % (k + 1), 12.0, SchematicTheme.TEXT]], false, 8.0)
	_seg(N_U, _main_v(3), N_U, v1, SchematicTheme.LINE, 1.6)
	_across(N_U, v1, [["N", 12.0, SchematicTheme.TEXT]], false, 8.0)


func _draw_incoming() -> void:
	var line_color: Color = SchematicTheme.LINE
	var supply: String = line().supply_cable if not line().supply_cable.is_empty() else SingleLine.SUPPLY_CABLE
	var main: CamSwitch = document.circuit.get_component(SingleLine.MAIN) as CamSwitch
	# L1 L2 L3 and N each on its own, through the main switch's poles when
	# there is one, onto their busbars.
	var bus: PackedFloat32Array = PackedFloat32Array([BUS_U[0], BUS_U[1], BUS_U[2], N_U])
	for k: int in 4:
		var v: float = _main_v(k)
		if main == null:
			_seg(SUPPLY_U, v, bus[k], v, SchematicTheme.LINE)
		else:
			_seg(SUPPLY_U, v, MAIN_U, v, SchematicTheme.LINE)
			_switch(MAIN_U, v, SchematicTheme.LINE, SchematicTheme.LINE, main.position != CamSwitch.OFF, "circle")
			_seg(MAIN_U + 60.0, v, bus[k], v, SchematicTheme.LINE)
		_dot(bus[k], v, SchematicTheme.LINE)
	_across(SUPPLY_U + 8.0, _main_v(0), [[tr("Incoming supply"), DESIGNATION_SIZE, designation_color()], [supply, DATA_SIZE, data_color()]], true, 10.0)
	if main != null:
		_link(MAIN_U, _main_v(0), _main_v(3))
		var chosen: bool = selection.has(SingleLine.MAIN) and not sheet
		if chosen:
			draw_rect(Rect2(at(MAIN_U - 6.0, _main_v(0) - 56.0), Vector2(72.0, _main_v(3) - _main_v(0) + 70.0) * zoom), Color(SchematicTheme.SELECTED, 0.15))
		_across(MAIN_U + 30.0, _main_v(0), [[_dash(SingleLine.MAIN), DESIGNATION_SIZE, designation_color()], [_amps(SingleLine.MAIN_RATING), DATA_SIZE, data_color()]], true, 18.0)
	if line().spd:
		# The surge protective device on each phase and N, to earth.
		var box_u: float = SPD_U
		for k: int in 4:
			var v: float = SPD_V + k * SPD_POLE
			_seg(bus[k], v, box_u, v, SchematicTheme.LINE)
			_dot(bus[k], v, SchematicTheme.LINE)
		var vc: float = SPD_V + 1.5 * SPD_POLE
		var box: Rect2 = Rect2(at(box_u, SPD_V - 6.0), Vector2(3.0 * SPD_POLE + 12.0, 28.0) * zoom)
		draw_rect(box, SchematicTheme.BACKGROUND)
		draw_rect(box, line_color, false, _width(line_color))
		_seg(box_u + 4.0, vc, box_u + 22.0, vc, line_color, 1.1)
		_poly(PackedVector2Array([Vector2(box_u + 16.0, vc - 3.5), Vector2(box_u + 22.0, vc), Vector2(box_u + 16.0, vc + 3.5)]), line_color, 1.1)
		_seg(box_u + 28.0, vc, box_u + 60.0, vc, line_color)
		for k: int in 3:
			var half: float = 9.0 - 3.0 * k
			_seg(box_u + 60.0 + 4.0 * k, vc - half, box_u + 60.0 + 4.0 * k, vc + half, line_color)
		_across(box_u + 14.0, SPD_V - 6.0, [["-FC1", DESIGNATION_SIZE, designation_color()], [tr("SPD T1+T2"), DATA_SIZE, data_color()]], true, 10.0)
	# The PE and N bars over the busbars.
	var pe0: float = SPACING * 1.0
	var pe1: float = SPACING * 2.4
	_bar(BAR_U, pe0, pe1, Color("3aa34a"), Color("f2d21b"))
	_across(BAR_U + 5.0, pe1, [["PE", 11.0, SchematicTheme.TEXT]], false, 6.0)
	var pm: float = (pe0 + pe1) * 0.5
	_seg(BAR_U, pm, SUPPLY_U + 25.0, pm, line_color)
	_across(SUPPLY_U + 25.0, pm, [[tr("Earth electrode"), DATA_SIZE, designation_color()]], false, 6.0)
	var n0: float = SPACING * 2.9
	var n1: float = SPACING * 4.3
	_bar(BAR_U, n0, n1, SchematicTheme.NEUTRAL)
	_across(BAR_U + 5.0, n1, [["N", 11.0, SchematicTheme.TEXT]], false, 6.0)
	var nm: float = (n0 + n1) * 0.5
	_seg(BAR_U + 10.0, nm, N_U, nm, SchematicTheme.LINE)
	_dot(N_U, nm, SchematicTheme.LINE)


## The dashed link joining the poles of a device from [param v0] to
## [param v1] across, at its link's height under its top [param u].
func _link(u: float, v0: float, v1: float) -> void:
	if v1 - v0 < 1.0:
		return
	var tip: float = BreakerSymbol.CLOSED_TIP.x
	draw_dashed_line(at(u + BreakerSymbol.LINK_Y, v0 + tip), at(u + BreakerSymbol.LINK_Y, v1 + tip - 4.0), SchematicTheme.LINE, maxf(1.2 * zoom, 1.0), 3.0 * zoom)

## A bar of terminals from [param v0] to [param v1] at [param u] (10 deep);
## [param stripes] over [param fill] as on a PE bar.
func _bar(u: float, v0: float, v1: float, fill: Color, stripes: Color = Color.TRANSPARENT) -> void:
	var rect: Rect2 = Rect2(at(u, v0), Vector2(v1 - v0, 10.0) * zoom)
	draw_rect(rect, fill)
	if stripes.a > 0.0:
		var x: float = 0.0
		while x < v1 - v0:
			var a: float = minf(x + 5.0, v1 - v0)
			draw_rect(Rect2(at(u, v0 + x), Vector2(a - x, 10.0) * zoom), stripes)
			x += 10.0
	draw_rect(rect, SchematicTheme.LINE, false, maxf(zoom, 1.0))
	for k: int in 3:
		var c: Vector2 = at(u + 5.0, v0 + (v1 - v0) * (k + 1) / 4.0)
		draw_circle(c, 3.2 * zoom, SchematicTheme.BACKGROUND)
		draw_arc(c, 3.2 * zoom, 0.0, TAU, 12, SchematicTheme.LINE, maxf(0.9 * zoom, 1.0), true)
		draw_line(c + Vector2(-2.2, 2.2) * zoom, c + Vector2(2.2, -2.2) * zoom, SchematicTheme.LINE, maxf(0.9 * zoom, 1.0), true)


## A plain switch 60 long from [param u] down at [param v]: the fixed
## contact with [param mark] ("circle", "arc" or ""), the blade from its pivot.
func _switch(u: float, v: float, color_in: Color, color_out: Color, closed: bool, mark: String, tripped: bool = false) -> Vector2:
	var tip: Vector2 = SchematicSymbol.blade_tip(BreakerSymbol.PIVOT, BreakerSymbol.CLOSED_TIP, BreakerSymbol.OPEN_TIP, 0.0 if closed else 1.0)
	_seg(u, v, u + BreakerSymbol.FIXED_END.y, v, color_in)
	_seg(u + BreakerSymbol.PIVOT.y, v, u + 60.0, v, color_out)
	var blade: Color = SchematicTheme.WARNING if tripped else color_out
	_seg(u + BreakerSymbol.PIVOT.y, v, u + tip.y, v + tip.x, blade, 2.0)
	var f: Vector2 = Vector2(u + BreakerSymbol.FIXED_END.y, v)
	if mark == "circle":
		draw_circle(at(f.x, f.y), 2.4 * zoom, SchematicTheme.BACKGROUND)
		draw_arc(at(f.x, f.y), 2.4 * zoom, 0.0, TAU, 12, color_in, maxf(1.1 * zoom, 1.0), true)
	elif mark == "arc":
		_poly(PackedVector2Array([f + Vector2(-3, 0), f + Vector2(0, 3), f + Vector2(3, 0)]), color_in, 1.1)
	return tip


## A circuit breaker as on the schematic (see [BreakerSymbol]): the cross on
## the fixed contact, the thermal and magnetic releases on the blade.
func _breaker(u: float, v: float, color_in: Color, color_out: Color, closed: bool, tripped: bool) -> void:
	var tip: Vector2 = SchematicSymbol.blade_tip(BreakerSymbol.PIVOT, BreakerSymbol.CLOSED_TIP, BreakerSymbol.OPEN_TIP, 0.0 if closed else 1.0)
	var pivot: Vector2 = BreakerSymbol.PIVOT
	var turn: float = (tip - pivot).angle() - (BreakerSymbol.CLOSED_TIP - pivot).angle()
	var on_blade: Callable = func(p: Vector2) -> Vector2:
		var q: Vector2 = pivot + (p - pivot).rotated(turn)
		return Vector2(u + q.y, v + q.x)
	_seg(u, v, u + BreakerSymbol.FIXED_END.y, v, color_in)
	var c: float = BreakerSymbol.CROSS
	var f: Vector2 = Vector2(u + BreakerSymbol.FIXED_END.y, v)
	_seg(f.x - c, f.y - c, f.x + c, f.y + c, color_in, 1.2)
	_seg(f.x - c, f.y + c, f.x + c, f.y - c, color_in, 1.2)
	_seg(u + pivot.y, v, u + 60.0, v, color_out)
	var mark: Color = SchematicTheme.WARNING if tripped else SchematicTheme.LINE
	_seg(u + pivot.y, v, u + tip.y, v + tip.x, SchematicTheme.WARNING if tripped else color_out, 2.0)
	var thermal: PackedVector2Array = PackedVector2Array([on_blade.call(Vector2(BreakerSymbol._blade_x(BreakerSymbol.CLOSED_TIP, BreakerSymbol.THERMAL_Y), BreakerSymbol.THERMAL_Y))])
	for p: Vector2 in BreakerSymbol.THERMAL:
		thermal.append(on_blade.call(p))
	_poly(thermal, mark, 1.1)
	var magnetic: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in BreakerSymbol.MAGNETIC:
		magnetic.append(on_blade.call(p))
	_poly(magnetic, mark, 1.1)
	var a: Vector2 = on_blade.call(Vector2(BreakerSymbol.MAGNETIC[0].x, BreakerSymbol.MAGNETIC_Y))
	var b: Vector2 = on_blade.call(Vector2(BreakerSymbol._blade_x(BreakerSymbol.CLOSED_TIP, BreakerSymbol.MAGNETIC_Y), BreakerSymbol.MAGNETIC_Y))
	_seg(a.x, a.y, b.x, b.y, mark, 1.1)


## The release box of an RCD or RCBO (IΔ, worked by the ring round its
## leads) or of an AFDD (an arc), right of its last pole at [param v] (the
## first [param span] left of it), joined to the blades by a dashed link;
## with [param outline] the device's outline and its test button.
func _release_box(u: float, v: float, arc: bool, span: float, outline: bool, tripped: bool) -> void:
	var mark: Color = SchematicTheme.WARNING if tripped else SchematicTheme.LINE
	var box: Rect2 = Rect2(at(u + RCD_BOX.position.y, v + RCD_BOX.position.x), Vector2(RCD_BOX.size.x, RCD_BOX.size.y) * zoom)
	var link_u: float = u + BreakerSymbol.LINK_Y
	draw_dashed_line(at(link_u, v + 2.0), at(link_u, v + RCD_BOX.position.x), mark, maxf(1.2 * zoom, 1.0), 3.0 * zoom)
	draw_rect(box, SchematicTheme.BACKGROUND)
	draw_rect(box, mark, false, maxf(1.1 * zoom, 1.0))
	if arc:
		var c: Vector2 = Vector2(u + RCD_BOX.get_center().y, v + RCD_BOX.get_center().x)
		_poly(PackedVector2Array([c + Vector2(0, -7), c + Vector2(0, -4), c + Vector2(-4, -1), c + Vector2(4, 1), c + Vector2(0, 4), c + Vector2(0, 7)]), afdd_color(), 1.1)
	else:
		var fs: int = maxi(roundi(9.0 * zoom), 1)
		var text_width: float = _font.get_string_size("IΔ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, box.get_center() + Vector2(-text_width * 0.5, (_font.get_ascent(fs) - _font.get_descent(fs)) * 0.5), "IΔ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, mark)
		# The summation transformer round the leads under the pivots.
		var ring_u: float = u + RcdSymbol.RING_Y
		var center: Vector2 = Vector2(ring_u, v - span * 0.5)
		var ring: PackedVector2Array = PackedVector2Array()
		for k: int in 25:
			var t: float = TAU * k / 24.0
			ring.append(center + Vector2(sin(t) * RcdSymbol.RING_HEIGHT * 0.5, cos(t) * (span * 0.5 + 6.0)))
		_poly(ring, mark, 1.1)
		_poly(PackedVector2Array([Vector2(ring_u, v + 6.0), Vector2(ring_u, v + RCD_BOX.get_center().x), Vector2(u + RCD_BOX.end.y, v + RCD_BOX.get_center().x)]), mark, 1.1)
	if outline:
		var left: float = v - span + OUTLINE.position.x
		var rect: Rect2 = Rect2(at(u + OUTLINE.position.y, left), Vector2(OUTLINE.size.x + span, OUTLINE.size.y) * zoom)
		var dim: Color = Color(SchematicTheme.LINE, 0.55)
		for side: int in 4:
			var a: Vector2 = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)][side]
			var b: Vector2 = [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position][side]
			draw_dashed_line(a, b, dim, maxf(zoom, 1.0), 4.0 * zoom)
		var button: Vector2 = at(u + TEST_BUTTON.y, v + TEST_BUTTON.x)
		draw_circle(button, 4.5 * zoom, SchematicTheme.BACKGROUND)
		draw_arc(button, 4.5 * zoom, 0.0, TAU, 16, SchematicTheme.LINE, maxf(zoom, 1.0), true)
		var fs: int = maxi(roundi(7.5 * zoom), 1)
		var w: float = _font.get_string_size("T", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, button + Vector2(-w * 0.5, (_font.get_ascent(fs) - _font.get_descent(fs)) * 0.5), "T", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, SchematicTheme.LINE)

## Marking written on [param c]: "B16", an RCD "40/0,03 A typ A", an RCBO
## "B16/0,03 A typ A".
func rating_of(c: CircuitComponent) -> String:
	if c is CircuitBreaker:
		return CircuitBreaker.rating_text((c as CircuitBreaker).characteristic, (c as CircuitBreaker).rated_current)
	if c is ResidualCurrentDevice:
		var rcd: ResidualCurrentDevice = c as ResidualCurrentDevice
		var current: String = CircuitBreaker.rating_text(rcd.characteristic, rcd.rated_current) if rcd.overcurrent else Fuse.amperes_text(rcd.rated_current)
		return tr("%s/%s A type %s") % [current, _decimal(String.num(rcd.residual_rating, 3)), rcd.type_text()]
	if c is MotorBreaker:
		# With its poles: "B16/1+N", "C20/3".
		var phases: int = SingleLine.phase_count(c)
		return "%s/%d%s" % [CircuitBreaker.rating_text((c as MotorBreaker).characteristic, (c as MotorBreaker).rated_current), phases, "+N" if SingleLine.has_n_pole(c) else ""]
	return ""


## [param text] with the decimal comma where the language writes one.
static func _decimal(text: String) -> String:
	return text.replace(".", ",") if TranslationServer.get_locale().begins_with("cs") else text


static func _amps(amperes: float) -> String:
	return "%s A" % Fuse.amperes_text(amperes)


func _draw_group(g: Dictionary) -> void:
	var designation: String = g["designation"]
	var head: CircuitComponent = _part(designation)
	var group: SingleLine.Group = _shown().group_of(designation)
	if head == null or group == null:
		return
	var v0: float = g["v0"]
	var v1: float = g["v1"]
	var depth: int = g["depth"]
	var parent: String = g["parent"]
	var ru: float = _rcd_u(depth)
	var phases: int = SingleLine.phase_count(head)
	var n_pole: bool = SingleLine.has_n_pole(head)
	var poles: PackedFloat32Array = _group_poles(v0, head)
	var last: float = poles[poles.size() - 1]
	var chosen: bool = selection.has(designation) and not sheet and ghost_of.is_empty()
	if chosen:
		draw_rect(Rect2(at(ru - 6.0, v0 - 58.0), Vector2(110.0 + last - v0, 72.0) * zoom), Color(SchematicTheme.SELECTED, 0.15))
	var closed: bool = head.is_path_closed(0)
	var tripped: bool = (head as MotorBreaker).tripped if head is MotorBreaker else (head as CircuitBreaker).tripped if head is CircuitBreaker else false
	var label_u: float = (N_U if parent.is_empty() else _row_u(parent, 3)) + 12.0
	# Each phase from its busbar through its pole onto the group's busbar
	# of that phase.
	for k: int in phases:
		var ph: int = group.phase if phases == 1 else k + 1
		var pv: float = poles[k]
		var color_in: Color = SchematicTheme.LINE
		var color_out: Color = SchematicTheme.LINE
		var source: float = _row_u(parent, ph)
		_seg(source, pv, ru, pv, color_in)
		_dot(source, pv, color_in)
		if SingleLine.heads_group(head):
			_switch(ru, pv, color_in, color_out, closed, "", tripped)
		else:
			_breaker(ru, pv, color_in, color_out, closed, tripped)
		_across(label_u, pv, [["L%d" % ph, SMALL_SIZE, data_color()]], false, 3.0)
		var row: float = _sub_bus_u(depth) + ((ph - 1) * SUB_GAP if phases > 1 else 0.0)
		_seg(ru + 60.0, pv, row, pv, color_out)
		_seg(row, pv, row, maxf(v1, pv), color_out, 1.6)
	if n_pole:
		# The N from the busbar or the N bar over it, through its N pole onto its N bar.
		var nv: float = poles[phases]
		var n_in: Color = SchematicTheme.LINE
		var n_out: Color = SchematicTheme.LINE
		_seg(g["n_u"], nv, ru, nv, n_in)
		_dot(g["n_u"], nv, n_in)
		_switch(ru, nv, n_in, n_out, closed, "", tripped)
		_across(label_u, nv, [["N", SMALL_SIZE, data_color()]], false, 3.0)
		# Long enough for what takes its N from it.
		var bar_u: float = _n_bar_u(depth)
		var bar_end: float = nv + SPACING * 0.95
		for other: Dictionary in _groups:
			if float(other["n_u"]) == bar_u + 10.0 and _under(other["designation"], group):
				var other_poles: PackedFloat32Array = _group_poles(other["v0"], _part(other["designation"]))
				bar_end = maxf(bar_end, other_poles[other_poles.size() - 1] + 8.0)
		for entry: Dictionary in _circuits:
			if float(entry["n_u"]) == bar_u + 10.0 and _under(entry["designation"], group):
				var entry_poles: PackedFloat32Array = _circuit_poles(entry["v"], _part(entry["designation"]))
				bar_end = maxf(bar_end, entry_poles[entry_poles.size() - 1] + 8.0)
		var number: int = 1
		for other: Dictionary in _groups:
			if other == g:
				break
			if SingleLine.has_n_pole(_part(other["designation"])):
				number += 1
		_seg(ru + 60.0, nv, bar_u, nv, n_out)
		_bar(bar_u, nv - 6.0, bar_end, SchematicTheme.NEUTRAL)
		_across(bar_u + 5.0, bar_end, [["N%d" % number, DATA_SIZE, SchematicTheme.TEXT]], false, 5.0)
	_link(ru, v0, last)
	if _has_box(head):
		_release_box(ru, last, head is ArcFaultDevice, last - v0, true, tripped)
	var labels: Array = []
	if SingleLine.heads_group(head):
		labels = [[_dash(designation), DESIGNATION_SIZE, designation_color()], [rating_of(head), DATA_SIZE, data_color()]]
	else:
		labels = _device_labels(head)
	_across(ru + 30.0, v0, labels, true, 20.0)


## Whether device [param designation] is under [param group] in the diagram drawn.
func _under(designation: String, group: SingleLine.Group) -> bool:
	var item: RefCounted = _shown().item_of(designation)
	return item != null and item != group and _shown().is_under(item, group)

## The texts beside breaker, RCBO or AFDD [param device]: "AFDD", its
## designation and its marking (an RCBO's breaker marking over its residual
## current).
func _device_labels(device: CircuitComponent) -> Array:
	var labels: Array = []
	if device is ArcFaultDevice:
		labels.append(["AFDD", 12.0, afdd_color()])
	labels.append([_dash(device.designation), DESIGNATION_SIZE, designation_color()])
	if device is ResidualCurrentDevice:
		var rcbo: ResidualCurrentDevice = device as ResidualCurrentDevice
		labels.append([CircuitBreaker.rating_text(rcbo.characteristic, rcbo.rated_current), DATA_SIZE, data_color()])
		labels.append([tr("%s A type %s") % [_decimal(String.num(rcbo.residual_rating, 3)), rcbo.type_text()], DATA_SIZE, data_color()])
	else:
		labels.append([rating_of(device), DATA_SIZE, data_color()])
	return labels


func _draw_circuit(entry: Dictionary) -> void:
	var f: SingleLine.Feeder = _shown().feeder_of(entry["designation"])
	var device: CircuitComponent = _part(f.device) if f != null else null
	if device == null:
		return
	var v: float = entry["v"]
	var depth: int = entry["depth"]
	var parent: String = entry["group"]
	var phases: PackedInt32Array = _shown().phases_of(f, document.circuit, device)
	var top: float = _breaker_u(depth)
	var poles: PackedFloat32Array = _circuit_poles(v, device)
	var first: float = poles[0]
	var last: float = poles[poles.size() - 1]
	var chosen: bool = selection.has(f.device) and not sheet and ghost_of.is_empty()
	if chosen:
		draw_rect(Rect2(at(top - 6.0, first - 56.0), Vector2(108.0 + last - first, 72.0) * zoom), Color(SchematicTheme.SELECTED, 0.15))
	var closed: bool = device.is_path_closed(0)
	var tripped: bool = (device as MotorBreaker).tripped if device is MotorBreaker else (device as CircuitBreaker).tripped if device is CircuitBreaker else false
	var label_u: float = (N_U if parent.is_empty() else _row_u(parent, 3)) + 12.0
	# Each phase from its busbar through its pole, the N through an N pole.
	var outs: Array[Color] = []
	for k: int in phases.size():
		var pv: float = poles[k]
		var color_in: Color = SchematicTheme.LINE
		var color_out: Color = SchematicTheme.LINE
		var source: float = _row_u(parent, phases[k])
		_seg(source, pv, top, pv, color_in)
		_dot(source, pv, color_in)
		_breaker(top, pv, color_in, color_out, closed, tripped)
		_across(label_u, pv, [["L%d" % phases[k], SMALL_SIZE, data_color()]], false, 3.0)
		outs.append(color_out)
	if SingleLine.has_n_pole(device):
		var nv: float = poles[phases.size()]
		var n_in: Color = SchematicTheme.LINE
		var n_out: Color = SchematicTheme.LINE
		_seg(entry["n_u"], nv, top, nv, n_in)
		_dot(entry["n_u"], nv, n_in)
		_switch(top, nv, n_in, n_out, closed, "", tripped)
		_across(label_u, nv, [["N", SMALL_SIZE, data_color()]], false, 3.0)
		outs.append(n_out)
	_link(top, first, last)
	if _has_box(device):
		_release_box(top, last, device is ArcFaultDevice, last - first, true, tripped)
	_across(top + 30.0, first, _device_labels(device), true, 25.0)
	# Down to the outlet, the first pole through the ripple control contact;
	# the poles come together there into one line.
	var u: float = top + 60.0
	var ledger_u: float = _ledger_u()
	var merge_u: float = ledger_u - MERGE_U
	var join_u: float = ledger_u - JOIN_U
	var hdo: bool = _shown().switched_by_hdo(f)
	if hdo:
		_seg(u, first, HDO_U, first, outs[0])
		var contact: CircuitComponent = _hdo_contact(f)
		var hdo_closed: bool = contact != null and contact.is_path_closed(0)
		_switch(HDO_U - 10.0, first, outs[0], SchematicTheme.LINE, hdo_closed, "arc")
		_across(HDO_U + 20.0, first, [[_dash(SingleLine.HDO), DATA_SIZE, designation_color()], [tr("HDO"), SMALL_SIZE, SchematicTheme.TEXT]], true, 16.0)
		outs[0] = SchematicTheme.LINE
	for k: int in poles.size():
		var from_u: float = HDO_U + 50.0 if k == 0 and hdo else u
		_seg(from_u, poles[k], merge_u, poles[k], outs[k])
		_seg(merge_u, poles[k], join_u, v, outs[k])
	var out_color: Color = outs[0]
	var parts: Array[CircuitComponent] = _parts_of(f)
	var end_u: float = _part_u(parts.size() - 1) if not parts.is_empty() else _load_u() - LOAD_R
	_seg(join_u, v, end_u, v, out_color)
	# The cable: its number on a ledger, its type along the line.
	_seg(ledger_u, v, ledger_u, v + 30.0, SchematicTheme.LINE, 1.0)
	_across(ledger_u - 7.0, v + 8.0, [["-WD%d" % _shown().cable_number(f), DATA_SIZE, designation_color()]], false, 2.0)
	_along(ledger_u + 6.0, v - 7.0, SingleLine.cable_text(f, document.circuit), DATA_SIZE, data_color())
	# Its length from the plan and its voltage drop, red over the limit (not
	# for a part being placed, not in the document yet).
	var length: float = _shown().cable_length(f, document) if document.circuit.get_component(f.device) != null else -1.0
	if length >= 0.0:
		var drop: float = _shown().voltage_drop(f, document, length)
		var over: bool = drop > _shown().drop_limit(f, document.circuit)
		var text: String = "%d m" % roundi(length) + (("  ΔU %s %%" % _decimal(String.num(drop, 1))) if drop >= 0.0 else "")
		_along(ledger_u + 6.0, v + 7.0, text, SMALL_SIZE, SchematicTheme.WARNING if over else SchematicTheme.TEXT)
	if not sheet and ghost_of.is_empty() and _shown().lacks_rcd(f, document.circuit):
		_rcd_warning(ledger_u - MARK_U, v)
	# Every part it feeds, one under another, with its designation.
	for i: int in parts.size():
		var part: CircuitComponent = parts[i]
		var part_chosen: bool = selection.has(part.designation) and not sheet
		var color: Color = SchematicTheme.HOVER if part_chosen else SchematicTheme.LINE
		var def: CustomSymbol = document.symbol((part as Appliance).symbol) if part is Appliance else null
		draw_load(self, part, at(_part_u(i), v), zoom, color, _width(SchematicTheme.LINE), false, def, _font)
		if i < parts.size() - 1:
			_dot(_part_u(i), v, out_color)
		_across(_part_u(i) - 9.0, v, [[_dash(part.designation), SMALL_SIZE, designation_color()]], false, 44.0)
	var destination: String = f.destination
	if destination.is_empty():
		destination = _kind_name(parts[0]) if not parts.is_empty() else tr("Spare")
	var below: float = (_part_u(parts.size() - 1) if not parts.is_empty() else _load_u()) + 22.0
	_along(below, v, destination, DEST_SIZE, SchematicTheme.TEXT)
	if not f.room.is_empty():
		_along(below, v + 14.0, "→ " + f.room, DATA_SIZE, link_color(), false, true)

## The mark of a circuit without a 30 mA RCD: a warning triangle right of
## its line at [param u].
func _rcd_warning(u: float, v: float) -> void:
	var c: Vector2 = at(u, v + 14.0)
	var h: float = 7.0 * zoom
	var triangle: PackedVector2Array = PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, h * 0.8), c + Vector2(-h, h * 0.8)])
	draw_colored_polygon(triangle, SchematicTheme.WARNING)
	var fs: int = maxi(roundi(9.0 * zoom), 1)
	var w: float = _font.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, c + Vector2(-w * 0.5, h * 0.65), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, SchematicTheme.BACKGROUND)


## The ripple control contact of circuit [param f], or null.
func _hdo_contact(f: SingleLine.Feeder) -> CircuitComponent:
	var n: int = 0
	for other: SingleLine.Feeder in line().feeders():
		if other == f:
			break
		if line().switched_by_hdo(other):
			n += 1
	var k: int = 0
	for c: CircuitComponent in document.circuit.get_components():
		if c.designation == SingleLine.HDO and c is LatchingSwitch:
			if k == n:
				return c
			k += 1
	return null


## What a part is called when its circuit has no destination written.
func _kind_name(c: CircuitComponent) -> String:
	if c is SocketOutlet:
		return tr("Sockets")
	if c is Luminaire:
		return tr("Lighting")
	if c is Appliance:
		return ApplianceSymbol.title_of(c as Appliance)
	return ""


## Part [param c] a circuit feeds drawn as on the floor plan ([PlanSymbols]),
## hung from its circuit's line at screen point [param at] to the right, at
## zoom [param z]; [param on]: it works (lit, live). A luminaire is drawn
## alike on a wall or the ceiling; an appliance drawn with the user's own
## symbol [param def] has it in its box.
static func draw_load(item: CanvasItem, c: CircuitComponent, at: Vector2, z: float, color: Color, width: float, on: bool, def: CustomSymbol, font: Font) -> void:
	var s: float = LOAD_SCALE * z
	if c is SocketOutlet:
		PlanSymbols.draw_socket(item, c as SocketOutlet, at, Vector2.RIGHT, s, color, width, on)
	elif c is Luminaire:
		var center: Vector2 = at + Vector2.RIGHT * (PlanSymbols.LAMP_RADIUS + 0.06) * s
		item.draw_line(at, center, color, width, true)
		PlanSymbols.draw_luminaire(item, center, s, color, width, on)
	elif c is Appliance and def != null:
		var half: float = PlanSymbols.APPLIANCE * 0.35 * s
		var box: Rect2 = Rect2(at + Vector2(0.06 * s, -half), Vector2(half, half) * 2.0)
		item.draw_line(at, at + Vector2(0.06 * s, 0.0), color, width, true)
		item.draw_rect(box, PlanSymbols.GLOW if on else SchematicTheme.BACKGROUND)
		item.draw_rect(box, color, false, width)
		def.draw_fitted(item, box.grow(-2.0 * z), INF, color, maxf(width * 0.8, 1.0), font)
	elif c is Appliance:
		PlanSymbols.draw_appliance(item, c as Appliance, at, Vector2.RIGHT, s * 0.7, color, width, on)
