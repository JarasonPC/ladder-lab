class_name SingleLineCanvas
extends Control
## The consumer unit of a residential installation drawn as its single-line
## diagram (see [SingleLine]), as Czech projects draw it: the supply through
## the main switch onto busbars L1, L2, L3 and N across the sheet, a surge
## protective device, the PE and N bars, and the circuits hanging down from
## a dot on their busbar (the phase written beside it), a group's under its
## RCD (an outline with its test button) from a busbar of their own with the
## group's N bar, a group under another one a level lower. Each circuit: its breaker (as on the schematic: the cross
## and the releases), designation and rating beside it, an AFDD with its
## caption and arc, the ripple control contact where it has one, the cable
## number on a ledger and the cable along the line, the symbol of what it
## feeds, where it goes and the room it goes to (a link to the floor plan).
## Only phases are drawn. Wheel zooms at the mouse, right or middle drag pans.
##
## Edit mode: a click selects a device or a part fed, Shift or Ctrl+click
## adds one or takes it out, a drag from an empty place selects what is in
## its box; with [method begin_place] the part from the palette goes where
## it is clicked (a breaker or RCD between the columns or into a group, a
## part onto the circuit under the mouse); the devices selected dragged
## move their circuits or groups; while placing or dragging the diagram
## makes room where they go. Delete takes the selection away. Simulate mode: the
## circuits in the colours of their voltage; a click switches the main
## switch, a breaker or RCD, the ripple control contact, or presses an RCD's
## test button.

## Changes the diagram: [param change] is called with the document.
signal edit_requested(change: Callable)
## Device or part [param designation] was selected ("" for none).
signal selection_changed(designation: String)
## Breaker or RCD [param designation] was clicked while simulating.
signal operate_requested(designation: String)
## The main switch or the ripple control contact was clicked while simulating.
signal switch_toggled(designation: String, steps: int)
## The test button of [param designation] was clicked while simulating.
signal test_requested(designation: String)
## The room link of a circuit was clicked.
signal room_requested(room: String)

const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 5.0
const ZOOM_STEP: float = 1.15
## Across the sheet, from one circuit to the next.
const SPACING: float = 74.0
## Gaps before and after a group, and before a circuit of an RCBO or AFDD
## (its release box beside it).
const GROUP_GAP: float = 0.95 * SPACING
const AFTER_GROUP: float = 0.6 * SPACING
const BOX_GAP: float = SPACING
## Down the sheet (u): the busbars, then the parts of a circuit.
const BUS_U: PackedFloat32Array = [0.0, 22.0, 44.0]
const N_U: float = 66.0
## Tops of the breaker of a circuit of its own, of the RCD, of a breaker in
## a group (each symbol 3 cells tall).
const BREAKER_U: float = 110.0
const RCD_U: float = 100.0
const GROUP_BREAKER_U: float = 222.0
## A group's N bar and busbar.
const N_BAR_U: float = 172.0
const SUB_BUS_U: float = 205.0
## Ripple control contact of a circuit of its own.
const HDO_U: float = 190.0
const LEDGER_U: float = 302.0
const LOAD_U: float = 410.0
const LOAD_R: float = 13.0
## Incoming: the main switch's column and its top, the SPD's column.
const MAIN_V: float = -100.0
const MAIN_U: float = -120.0
const SUPPLY_U: float = -175.0
const SPD_V: float = -18.0
const SPD_U: float = 136.0
const BAR_U: float = -76.0
## RCD: its N pole beside its phase pole, the release box right of it.
const N_POLE: float = 12.0
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
const LEVEL: float = SUB_BUS_U - 44.0
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
## Last simulation step shown (null in Edit mode).
var step: StepResult = null
## Drawn for a sheet: no selection, placing or hint.
var sheet: bool = false

## Laid out by [method _layout]: per circuit {"designation", "v", "group"
## (the RCD it is directly under or ""), "depth" (how many groups it is
## under)}, per group {"designation", "v0" (its RCD), "v1" (the last thing
## on its busbar), "end" (the last circuit under it), "depth", "parent"};
## the deepest group's depth.
var _circuits: Array[Dictionary] = []
var _groups: Array[Dictionary] = []
var _end_v: float = 0.0
var _depth: int = 0
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
	return Rect2(MAIN_V - 150.0, SUPPLY_U - 30.0, _end_v - MAIN_V + 230.0, _load_u() + 160.0 - SUPPLY_U)


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


## The layout of [param l] (see [member _circuits]); circuits of
## [param boxed] (designations) are taken for RCBOs or AFDDs.
func _layout_of(l: SingleLine, boxed: PackedStringArray = PackedStringArray()) -> Dictionary:
	var circuits: Array[Dictionary] = []
	var groups: Array[Dictionary] = []
	var laid: Dictionary = {"circuits": circuits, "groups": groups, "end_v": SPACING * 1.15, "depth": 0}
	if l != null:
		laid["end_v"] = _lay(l.columns, 0, "", SPACING * 1.15, laid, boxed, N_U)
	return laid


## Lays out circuits and groups [param list] under group [param parent]
## ("" for the busbars), [param depth] groups deep, from [param v], their N
## from row [param n_u]; returns where the next one would go.
func _lay(list: Array[RefCounted], depth: int, parent: String, v: float, laid: Dictionary, boxed: PackedStringArray, n_u: float) -> float:
	var after_group: bool = false
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
			if g.items.is_empty():
				v += SPACING
			else:
				# Under its N bar (an RCD's, an AFDD's), else the N it has.
				var n_under: float = _n_bar_u(depth) + 10.0 if SingleLine.has_n_pole(_part(g.device)) else n_u
				v = _lay(g.items, depth + 1, g.device, v, laid, boxed, n_under)
				entry["v1"] = _attach_v(laid, SingleLine.device_of(g.items.back()))
			entry["end"] = maxf(v - SPACING, float(entry["v0"]))
			after_group = true
		else:
			var designation: String = (item as SingleLine.Feeder).device
			var device: CircuitComponent = _part(designation) if document != null else null
			var is_boxed: bool = device is ResidualCurrentDevice or device is ArcFaultDevice or boxed.has(designation)
			# Room for the texts of an RCBO or AFDD (its box right of the one before).
			if after_group or (is_boxed and (depth == 0 or k > 0)):
				v += maxf(AFTER_GROUP if after_group else 0.0, BOX_GAP if is_boxed else 0.0)
			after_group = false
			(laid["circuits"] as Array[Dictionary]).append({"designation": designation, "v": v, "group": parent, "depth": depth})
			v += SPACING
	return v


## Where device [param designation] is laid out in [param laid]: a
## circuit's line or a group's RCD; NAN for nowhere.
static func _attach_v(laid: Dictionary, designation: String) -> float:
	for entry: Dictionary in laid["circuits"]:
		if entry["designation"] == designation:
			return entry["v"]
	for entry: Dictionary in laid["groups"]:
		if entry["designation"] == designation:
			return entry["v0"]
	return NAN


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
func _ledger_u() -> float:
	return LEDGER_U + _depth * LEVEL


func _load_u() -> float:
	return LOAD_U + _depth * LEVEL


func _circuit_entry(designation: String) -> Dictionary:
	for entry: Dictionary in _circuits:
		if entry["designation"] == designation:
			return entry
	return {}


# --- Finding things -------------------------------------------------------------------

## What is under screen point [param point]: {"kind": "device" / "load" /
## "main" / "hdo" / "test" / "room", "designation"}, {} for nothing.
func thing_at(point: Vector2) -> Dictionary:
	_layout()
	var p: Vector2 = local(point)
	var u: float = p.x
	var v: float = p.y
	if absf(v - MAIN_V) < 24.0 and u > MAIN_U - 6.0 and u < MAIN_U + 66.0:
		return {"kind": "main", "designation": SingleLine.MAIN}
	for g: Dictionary in _groups:
		var gv: float = g["v0"]
		var ru: float = _rcd_u(g["depth"])
		if SingleLine.has_n_pole(document.circuit.get_component(g["designation"])) and Vector2(u, v).distance_to(Vector2(ru + TEST_BUTTON.y, gv + TEST_BUTTON.x)) < 6.0:
			return {"kind": "test", "designation": g["designation"]}
		if Rect2(ru + DEVICE_GRAB.position.x, gv + DEVICE_GRAB.position.y, DEVICE_GRAB.size.x, DEVICE_GRAB.size.y + N_POLE).has_point(Vector2(u, v)):
			return {"kind": "device", "designation": g["designation"]}
	for entry: Dictionary in _circuits:
		var cv: float = entry["v"]
		var f: SingleLine.Feeder = line().feeder_of(entry["designation"])
		if f == null:
			continue
		var top: float = _breaker_u(entry["depth"])
		var device: CircuitComponent = document.circuit.get_component(f.device)
		if (device is ResidualCurrentDevice or device is ArcFaultDevice) and Vector2(u, v).distance_to(Vector2(top + TEST_BUTTON.y, cv + TEST_BUTTON.x)) < 6.0:
			return {"kind": "test", "designation": f.device}
		if Rect2(top + DEVICE_GRAB.position.x, cv + DEVICE_GRAB.position.y, DEVICE_GRAB.size.x, DEVICE_GRAB.size.y).has_point(Vector2(u, v)):
			return {"kind": "device", "designation": f.device}
		if line().switched_by_hdo(f) and absf(v - cv) < 14.0 and u > HDO_U - 4.0 and u < HDO_U + 44.0:
			return {"kind": "hdo", "designation": SingleLine.HDO}
		if line().lacks_rcd(f, document.circuit) and Vector2(u, v).distance_to(Vector2(_ledger_u() - MARK_U, cv + 14.0)) < 9.0:
			return {"kind": "warning", "designation": f.device}
		var end: CircuitComponent = SingleLine.end_part(f, document.circuit)
		if end != null and absf(v - cv) < 18.0 and absf(u - _load_u()) < 18.0:
			return {"kind": "load", "designation": end.designation}
		if not f.room.is_empty() and v > cv + 6.0 and v < cv + 22.0 and u > _load_u() + 18.0 and u < _load_u() + 120.0:
			return {"kind": "room", "designation": f.room}
	return {}


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
			return int(template.get("poles", 1))
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
				if mb.pressed:
					_operate(mb.position)
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
				var designation: String = thing.get("designation", "") if thing.get("kind", "") in ["device", "load"] else ""
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
	for g: Dictionary in _groups:
		list.append({"designation": g["designation"], "at": Vector2(_rcd_u(g["depth"]) + 30.0, g["v0"])})
	for entry: Dictionary in _circuits:
		list.append({"designation": entry["designation"], "at": Vector2(_breaker_u(entry["depth"]) + 30.0, entry["v"])})
		var f: SingleLine.Feeder = line().feeder_of(entry["designation"])
		var end: CircuitComponent = SingleLine.end_part(f, document.circuit) if f != null else null
		if end != null:
			list.append({"designation": end.designation, "at": Vector2(_load_u(), entry["v"])})
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


func _operate(point: Vector2) -> void:
	var thing: Dictionary = thing_at(point)
	match thing.get("kind", ""):
		"main", "hdo":
			switch_toggled.emit(thing["designation"], 0)
		"device":
			operate_requested.emit(thing["designation"])
		"test":
			test_requested.emit(thing["designation"])
		"room":
			room_requested.emit(thing["designation"])


func _place(point: Vector2) -> void:
	var target: Dictionary = drop_target(point, placing)
	if target.is_empty():
		return
	var template: Dictionary = placing.duplicate()
	var index: int = target["index"]
	var into: String = target["into"]
	var feeder: String = target["feeder"]
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		var data: Dictionary = template.duplicate()
		data["designation"] = new_designation(doc, template)
		var c: CircuitComponent = DocumentSerializer.component_from_dict(data)
		if c != null:
			doc.single_line.add(doc, c, index, into, feeder))


func _move(designations: PackedStringArray, point: Vector2) -> void:
	var target: Dictionary = drop_target(point, {"type": "breaker"}, designations)
	if target.is_empty():
		return
	var index: int = target["index"]
	var into: String = target["into"]
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.single_line.move_many(doc, designations, index, into))


## Takes the selection away in one edit: each device with what its circuit
## feeds (what is under an RCD stays), each part fed.
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
				gone.append_array(f.loads)
		for d: String in gone:
			var c: CircuitComponent = doc.circuit.get_component(d)
			if c != null:
				doc.remove_component(c.id))


## Designation of a new part made from [param template] in [param doc].
static func new_designation(doc: SchematicDocument, template: Dictionary) -> String:
	match str(template.get("type", "")):
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
			return tr("Main switch: click to switch it while simulating") if not editing else tr("Main switch")
		"hdo":
			return tr("Ripple control contactor (HDO, low tariff): click to switch it while simulating")
		"test":
			return tr("Test button: click to press it while simulating")
		"room":
			return tr("Show room %s on the floor plan") % thing["designation"]
		"warning":
			return NO_RCD_TEXT
		"device":
			return tr("Click to switch it while simulating") if not editing else tr("Drag to move its circuit (the ones selected along); Shift+click selects more; Delete takes them away")
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
		var v: float = _circuit_entry(fed["feeder"]).get("v", 0.0)
		draw_arc(at(_load_u(), v), (LOAD_R + 6.0) * zoom, 0.0, TAU, 32, SchematicTheme.HOVER, 2.0, true)
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


## Colour of the voltage that reaches terminal [param key] while simulating.
func _reach(key: String) -> Color:
	if step == null or key.is_empty():
		return SchematicTheme.LINE
	return SchematicTheme.reach_color(step.terminal_reach.get(key, StepResult.REACH_NONE))


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


func _main_keys() -> PackedStringArray:
	var main: CircuitComponent = document.circuit.get_component(SingleLine.MAIN)
	return main.get_terminal_keys() if main != null else PackedStringArray(["", "", "", "", "", "", "", ""])


func _draw_busbars() -> void:
	var keys: PackedStringArray = _main_keys()
	var v0: float = MAIN_V - 14.0
	var v1: float = _end_v - SPACING * 0.4
	for k: int in 3:
		var color: Color = _reach(keys[2 * k + 1])
		_seg(BUS_U[k], v0, BUS_U[k], v1, color, 1.6)
		_across(BUS_U[k], v1, [["L%d" % (k + 1), 12.0, SchematicTheme.TEXT]], false, 8.0)
	var n_color: Color = _reach(keys[7])
	_seg(N_U, v0, N_U, v1, n_color, 1.6)
	_across(N_U, v1, [["N", 12.0, SchematicTheme.TEXT]], false, 8.0)


func _draw_incoming() -> void:
	var keys: PackedStringArray = _main_keys()
	var line_color: Color = SchematicTheme.LINE
	var supply: String = line().supply_cable if not line().supply_cable.is_empty() else SingleLine.SUPPLY_CABLE
	_seg(SUPPLY_U, MAIN_V, MAIN_U, MAIN_V, _reach(keys[0]))
	_across(SUPPLY_U + 8.0, MAIN_V, [[tr("Incoming supply"), DESIGNATION_SIZE, designation_color()], [supply, DATA_SIZE, data_color()]], true, 10.0)
	# The main switch: a switch-disconnector, four poles shown as one.
	var main: CamSwitch = document.circuit.get_component(SingleLine.MAIN) as CamSwitch
	var closed: bool = main != null and main.position != CamSwitch.OFF
	_switch(MAIN_U, MAIN_V, _reach(keys[0]), _reach(keys[1]), closed, "circle")
	_across(MAIN_U + 30.0, MAIN_V, [[_dash(SingleLine.MAIN), DESIGNATION_SIZE, designation_color()], [_amps(SingleLine.MAIN_RATING), DATA_SIZE, data_color()]], true, 18.0)
	_seg(MAIN_U + 60.0, MAIN_V, N_U, MAIN_V, _reach(keys[1]))
	for k: int in 3:
		_dot(BUS_U[k], MAIN_V, _reach(keys[2 * k + 1]))
	_dot(N_U, MAIN_V, _reach(keys[7]))
	if line().spd:
		# The surge protective device on all phases and N to earth.
		_seg(BUS_U[0], SPD_V, SPD_U - 6.0, SPD_V, _reach(keys[1]))
		for k: int in 3:
			_dot(BUS_U[k], SPD_V, _reach(keys[2 * k + 1]))
		_dot(N_U, SPD_V, _reach(keys[7]))
		var box: Rect2 = Rect2(at(SPD_U, SPD_V - 9.0), Vector2(18.0, 28.0) * zoom)
		draw_rect(box, SchematicTheme.BACKGROUND)
		draw_rect(box, line_color, false, _width(line_color))
		_seg(SPD_U + 4.0, SPD_V, SPD_U + 22.0, SPD_V, line_color, 1.1)
		_poly(PackedVector2Array([Vector2(SPD_U + 16.0, SPD_V - 3.5), Vector2(SPD_U + 22.0, SPD_V), Vector2(SPD_U + 16.0, SPD_V + 3.5)]), line_color, 1.1)
		_seg(SPD_U - 6.0, SPD_V, SPD_U, SPD_V, line_color)
		_seg(SPD_U + 28.0, SPD_V, SPD_U + 60.0, SPD_V, line_color)
		for k: int in 3:
			var half: float = 9.0 - 3.0 * k
			_seg(SPD_U + 60.0 + 4.0 * k, SPD_V - half, SPD_U + 60.0 + 4.0 * k, SPD_V + half, line_color)
		_across(SPD_U + 14.0, SPD_V, [["-FC1", DESIGNATION_SIZE, designation_color()], [tr("SPD T1+T2"), DATA_SIZE, data_color()]], true, 16.0)
	# The PE and N bars over the busbars.
	var pe0: float = SPACING * 1.0
	var pe1: float = SPACING * 2.4
	_bar(BAR_U, pe0, pe1, Color("3aa34a"), Color("f2d21b"))
	_across(BAR_U + 5.0, pe1, [["PE", 11.0, SchematicTheme.TEXT]], false, 6.0)
	var pm: float = (pe0 + pe1) * 0.5
	_seg(BAR_U, pm, SUPPLY_U + 25.0, pm, SchematicTheme.PE if step != null else line_color)
	_across(SUPPLY_U + 25.0, pm, [[tr("Earth electrode"), DATA_SIZE, designation_color()]], false, 6.0)
	var n0: float = SPACING * 2.9
	var n1: float = SPACING * 4.3
	_bar(BAR_U, n0, n1, SchematicTheme.NEUTRAL)
	_across(BAR_U + 5.0, n1, [["N", 11.0, SchematicTheme.TEXT]], false, 6.0)
	var nm: float = (n0 + n1) * 0.5
	_seg(BAR_U + 10.0, nm, N_U, nm, _reach(keys[7]))
	_dot(N_U, nm, _reach(keys[7]))


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
## first [param span] left of it), joined to the blade by a dashed link;
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
		var rect: Rect2 = Rect2(at(u + OUTLINE.position.y, v + OUTLINE.position.x), Vector2(OUTLINE.size.x, OUTLINE.size.y) * zoom)
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
		return CircuitBreaker.rating_text((c as MotorBreaker).characteristic, (c as MotorBreaker).rated_current)
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
	var v: float = g["v0"]
	var v1: float = g["v1"]
	var depth: int = g["depth"]
	var ru: float = _rcd_u(depth)
	var keys: PackedStringArray = head.get_terminal_keys()
	var phases: int = SingleLine.phase_count(head)
	var n_pole: bool = SingleLine.has_n_pole(head)
	# From the busbars, or from the busbar of the group it is under.
	var bus_u: float = BUS_U[group.phase - 1] if phases == 1 else BUS_U[0]
	if depth > 0:
		bus_u = _sub_bus_u(depth - 1)
	var color_in: Color = _reach(keys[0])
	var color_out: Color = _reach(keys[1])
	var chosen: bool = selection.has(designation) and not sheet and ghost_of.is_empty()
	if chosen:
		draw_rect(Rect2(at(ru - 6.0, v - 58.0), Vector2(110.0, 72.0) * zoom), Color(SchematicTheme.SELECTED, 0.15))
	_seg(bus_u, v, ru, v, color_in)
	if phases == 1 or depth > 0:
		_dot(bus_u, v, color_in)
	else:
		for k: int in 3:
			_dot(BUS_U[k], v, _reach(keys[2 * k]))
	var closed: bool = head.is_path_closed(0)
	var tripped: bool = (head as MotorBreaker).tripped if head is MotorBreaker else (head as CircuitBreaker).tripped if head is CircuitBreaker else false
	var labels: Array = []
	var n_in: Color = SchematicTheme.LINE
	var n_out: Color = SchematicTheme.LINE
	if n_pole:
		# The N from the busbar or the N bar over it, through its N pole.
		n_in = _reach(keys[2 * phases])
		n_out = _reach(keys[2 * phases + 1])
		_seg(g["n_u"], v + N_POLE, ru, v + N_POLE, n_in)
		if is_equal_approx(float(g["n_u"]), N_U):
			_dot(N_U, v + N_POLE, n_in)
		_switch(ru, v + N_POLE, n_in, n_out, closed, "", tripped)
		draw_dashed_line(at(ru + BreakerSymbol.LINK_Y, v), at(ru + BreakerSymbol.LINK_Y, v + N_POLE), SchematicTheme.LINE, maxf(1.2 * zoom, 1.0), 3.0 * zoom)
	if SingleLine.heads_group(head):
		_switch(ru, v, color_in, color_out, closed, "", tripped)
		labels = [[_dash(designation), DESIGNATION_SIZE, designation_color()], [rating_of(head), DATA_SIZE, data_color()]]
	else:
		_breaker(ru, v, color_in, color_out, closed, tripped)
		labels = _device_labels(head)
	if n_pole:
		_release_box(ru, v + N_POLE, head is ArcFaultDevice, N_POLE, true, tripped)
	_across(ru + 30.0, v, labels, true, 20.0)
	if phases == 1:
		_across((N_U if depth == 0 else _sub_bus_u(depth - 1)) + 12.0, v, [["L%d" % group.phase, SMALL_SIZE, data_color()]], false, 5.0)
	# The group's busbar, and with an N pole its N bar, long enough for the
	# groups under it.
	var sub_u: float = _sub_bus_u(depth)
	_seg(ru + 60.0, v, sub_u, v, color_out)
	_seg(sub_u, v, sub_u, v1, color_out, 1.6)
	if n_pole:
		var bar_end: float = v + 6.0 + SPACING * 0.95
		for other: Dictionary in _groups:
			if other["parent"] == designation:
				bar_end = maxf(bar_end, float(other["v0"]) + N_POLE + 8.0)
		var number: int = 1
		for other: Dictionary in _groups:
			if other == g:
				break
			if SingleLine.has_n_pole(_part(other["designation"])):
				number += 1
		_seg(ru + 60.0, v + N_POLE, _n_bar_u(depth), v + N_POLE, n_out)
		_bar(_n_bar_u(depth), v + 6.0, bar_end, SchematicTheme.NEUTRAL)
		_across(_n_bar_u(depth) + 5.0, bar_end, [["N%d" % number, DATA_SIZE, SchematicTheme.TEXT]], false, 5.0)
	for entry: Dictionary in _circuits:
		if entry["group"] == designation and float(entry["v"]) < v1:
			_dot(sub_u, entry["v"], color_out)
	for other: Dictionary in _groups:
		if other["parent"] == designation and float(other["v0"]) < v1:
			_dot(sub_u, other["v0"], color_out)


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
	var in_group: bool = depth > 0
	var keys: PackedStringArray = device.get_terminal_keys()
	var phases: PackedInt32Array = _shown().phases_of(f, document.circuit, device)
	var top: float = _breaker_u(depth)
	var start: float = _sub_bus_u(depth - 1) if in_group else BUS_U[phases[0] - 1]
	var color_in: Color = _reach(keys[0])
	var color_out: Color = _reach(keys[1])
	var chosen: bool = selection.has(f.device) and not sheet and ghost_of.is_empty()
	if chosen:
		draw_rect(Rect2(at(top - 6.0, v - 56.0), Vector2(108.0, 72.0) * zoom), Color(SchematicTheme.SELECTED, 0.15))
	if phases.size() > 1 and not in_group:
		start = BUS_U[0]
	_seg(start, v, top, v, color_in)
	if not in_group:
		if phases.size() > 1:
			for ph: int in phases:
				_dot(BUS_U[ph - 1], v, _reach(keys[2 * phases.find(ph)]))
		else:
			_dot(start, v, color_in)
	var names: PackedStringArray = PackedStringArray()
	for ph: int in phases:
		names.append("L%d" % ph)
	var phase_text: String = " ".join(names)
	_across((_sub_bus_u(depth - 1) if in_group else N_U) + 12.0, v, [[phase_text, SMALL_SIZE, data_color()]], false, 5.0)
	var closed: bool = device.is_path_closed(0)
	var tripped: bool = (device as MotorBreaker).tripped if device is MotorBreaker else (device as CircuitBreaker).tripped if device is CircuitBreaker else false
	_breaker(top, v, color_in, color_out, closed, tripped)
	if device is ArcFaultDevice:
		_release_box(top, v, true, 0.0, true, tripped)
	elif device is ResidualCurrentDevice:
		_release_box(top, v, false, 0.0, true, tripped)
	_across(top + 30.0, v, _device_labels(device), true, 25.0)
	# Down to what it feeds, through the ripple control contact.
	var u: float = top + 60.0
	var out_color: Color = color_out
	if _shown().switched_by_hdo(f):
		_seg(u, v, HDO_U, v, out_color)
		var contact: CircuitComponent = _hdo_contact(f)
		var contact_keys: PackedStringArray = contact.get_terminal_keys() if contact != null else PackedStringArray(["", ""])
		var hdo_closed: bool = contact != null and contact.is_path_closed(0)
		_switch(HDO_U - 10.0, v, out_color, _reach(contact_keys[1]), hdo_closed, "arc")
		_across(HDO_U + 20.0, v, [[_dash(SingleLine.HDO), DATA_SIZE, designation_color()], [tr("HDO"), SMALL_SIZE, SchematicTheme.TEXT]], true, 16.0)
		out_color = _reach(contact_keys[1])
		u = HDO_U + 50.0
	var load: CircuitComponent = SingleLine.end_part(f, document.circuit)
	var load_u: float = _load_u()
	var ledger_u: float = _ledger_u()
	var load_top: float = load_u - (10.0 if load is SocketOutlet or load is Luminaire else LOAD_R) if load != null else load_u - LOAD_R
	_seg(u, v, load_top, v, out_color)
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
	if load != null:
		_load(load, load_u, v, selection.has(load.designation) and not sheet)
		var count: int = SingleLine.end_count(f, document.circuit)
		if count > 1:
			_across(load_u, v, [["%d×" % count, DATA_SIZE, SchematicTheme.TEXT]], false, LOAD_R + 5.0)
	var destination: String = f.destination
	if destination.is_empty():
		destination = _kind_name(load) if load != null else tr("Spare")
	_along(load_u + 22.0, v, destination, DEST_SIZE, SchematicTheme.TEXT)
	if not f.room.is_empty():
		_along(load_u + 22.0, v + 14.0, "→ " + f.room, DATA_SIZE, link_color(), false, true)


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
		return tr(["Water heater", "Oven", "Induction hob", "Microwave", "Washing machine", "Dishwasher", "Heater", "Fridge", "Kettle"][(c as Appliance).kind])
	return ""


## The symbol of what a circuit feeds, centred at [param u], [param v].
func _load(c: CircuitComponent, u: float, v: float, chosen: bool) -> void:
	var color: Color = SchematicTheme.HOVER if chosen else SchematicTheme.LINE
	var on: bool = step != null and c is Load and (c as Load).energized
	var center: Vector2 = at(u, v)
	var r: float = LOAD_R * zoom
	var width: float = _width(SchematicTheme.LINE)
	if c is SocketOutlet:
		# Open away from the busbars, as on the floor plan.
		if on:
			var fill: PackedVector2Array = PackedVector2Array()
			for k: int in 13:
				fill.append(center + Vector2.from_angle(PI + PI * k / 12.0) * 10.0 * zoom)
			draw_colored_polygon(fill, PlanSymbols.GLOW)
		draw_arc(center, 10.0 * zoom, PI, TAU, 16, color, width, true)
		return
	if c is Luminaire:
		draw_circle(center, 10.0 * zoom, SchematicTheme.LAMP_ON if on else SchematicTheme.BACKGROUND)
		draw_arc(center, 10.0 * zoom, 0.0, TAU, 24, color, width, true)
		var d: float = 7.0 * zoom
		draw_line(center + Vector2(-d, -d), center + Vector2(d, d), color, width, true)
		draw_line(center + Vector2(-d, d), center + Vector2(d, -d), color, width, true)
		return
	var appliance: Appliance = c as Appliance
	if appliance == null:
		return
	if appliance.kind == Appliance.Kind.WATER_HEATER:
		draw_circle(center, r, PlanSymbols.GLOW if on else SchematicTheme.BACKGROUND)
		draw_arc(center, r, 0.0, TAU, 24, color, width, true)
		for k: int in range(-9, 10, 3):
			var h: float = sqrt(LOAD_R * LOAD_R - k * k) * zoom
			draw_line(center + Vector2(k * zoom, -h), center + Vector2(k * zoom, h), color, maxf(0.8 * zoom, 1.0), true)
		return
	var box: Rect2 = Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)
	draw_rect(box, PlanSymbols.GLOW if on else SchematicTheme.BACKGROUND)
	draw_rect(box, color, false, width)
	var thin: float = maxf(1.1 * zoom, 1.0)
	match appliance.kind:
		Appliance.Kind.HOB:
			for a: float in [-6.5, 6.5]:
				for b: float in [-6.5, 6.5]:
					draw_arc(center + Vector2(a, b) * zoom, 3.6 * zoom, 0.0, TAU, 12, color, thin, true)
		Appliance.Kind.FRIDGE:
			for k: int in 3:
				var d: Vector2 = Vector2.from_angle(PI / 2.0 + k * PI / 3.0) * 8.0 * zoom
				draw_line(center - d, center + d, color, thin, true)
		Appliance.Kind.WASHING_MACHINE, Appliance.Kind.DISHWASHER:
			draw_arc(center, 8.0 * zoom, 0.0, TAU, 20, color, thin, true)
			draw_arc(center, 3.0 * zoom, 0.0, TAU, 12, color, thin, true)
		Appliance.Kind.MICROWAVE:
			for k: int in 3:
				var wave: PackedVector2Array = PackedVector2Array()
				for i: int in 9:
					wave.append(center + Vector2(-8.0 + 2.0 * i, -5.0 + 5.0 * k + sin(i * PI / 2.0) * 1.6) * zoom)
				draw_polyline(wave, color, thin, true)
		Appliance.Kind.OVEN:
			draw_rect(Rect2(center - Vector2(8, 6) * zoom, Vector2(16, 12) * zoom), color, false, thin)
		_:
			var zig: PackedVector2Array = PackedVector2Array([center + Vector2(-9, 0) * zoom])
			for i: int in 6:
				zig.append(center + Vector2(-7.0 + 2.8 * i, -4.0 if i % 2 == 0 else 4.0) * zoom)
			zig.append(center + Vector2(9, 0) * zoom)
			draw_polyline(zig, color, thin, true)
