class_name CabinetView
extends Control
## Draws a switchboard (rozvaděč) of a document like the real thing (see
## [CabinetLayout], [CabinetParts]) with its wiring ([CabinetWiring]), as
## wide as the panel it sits in. While
## simulating, the devices show the circuit's state, terminals are ringed in
## the colour of the voltage that reaches them, and a click switches a
## breaker or fuse holder, replaces a blown fuse or resets a tripped overload
## relay. While editing, a click selects a place.
##
## Painted in layers ([Layer]: the plate with its rails and ducts, each place
## on its own with its labels, the wires, the selection) that are painted
## again only when what they show changed, so a simulation step paints only
## the devices that changed and moving the view paints nothing. While the
## zoom changes the layers painted last are scaled, and painted sharp again
## [constant ZOOM_SETTLE] seconds after the last change.

## A device was clicked while simulating ([param designation] of the
## breaker, fuse or overload relay).
signal operate_requested(designation: String)
## A place was clicked while editing, or beside the ports and wires while
## wiring (-1, -1: beside the places).
signal place_clicked(rail: int, index: int)
## Wiring a training plan ([member wiring_mode]): a wire was drawn from port
## [param a] to [param b] of [param place] ("+RA1", the back of its door
## "+RA1/door"), or the wire of pair [param index] there picked and deleted.
signal wire_drawn(place: String, a: String, b: String)
signal wire_removed(place: String, index: int)
## The wire of pair [param index] of [param place] was picked (-1: none).
signal wire_picked(place: String, index: int)
## The drawing was zoomed.
signal zoom_changed

var document: SchematicDocument
## Index of the switchboard drawn in [member SchematicDocument.switchboards].
var board: int = 0
## Operate the circuit (true) or select places for editing (false).
var simulating: bool = false
## Terminal key -> reach code of the last simulation step (see [StepResult]).
var reach: Dictionary[String, int] = {}
## Place selected for editing as (rail, index); (-1, -1) for none.
var selected: Vector2i = Vector2i(-1, -1)
## Zoom over fitting the plate to the width (1); above it the drawing is
## wider than the panel and scrolls (in a [ScrollContainer] parent).
var zoom: float = 1.0:
	set(value):
		var was: float = zoom
		zoom = clampf(value, 1.0, MAX_ZOOM)
		update_minimum_size()
		queue_redraw()
		if not is_equal_approx(was, zoom):
			if _settle != null and _painted_k > 0.0:
				_settle.start(ZOOM_SETTLE)
			zoom_changed.emit()

## The door is drawn open beside the switchboard (hinged on its right):
## its back with the contact blocks and their wires (see
## [method StationInside.build_door]), the door harness running in its
## conduit from the switchboard's bottom across to the door.
var door_open: bool = false:
	set(value):
		door_open = value
		_door = null
		_painted.clear()
		update_minimum_size()
		queue_redraw()

## Wiring a training plan (see [TrainingPlan]): the student's wires drawn in
## place of the switchboard's own, a click on a terminal starts a wire and
## a click on another lays it, a click on a wire picks it (Delete takes it
## away, Esc lets go); the ports ringed (see [TrainingPick]).
var wiring_mode: bool = false:
	set(value):
		if value == wiring_mode:
			return
		wiring_mode = value
		focus_mode = Control.FOCUS_CLICK if value else Control.FOCUS_NONE
		_start = {}
		_picked_wire = {}

## The wire ducts are drawn with their covers on, hiding the wires in them
## (View > Wire duct covers, saved in the settings); never on export (see
## [member open_ducts]).
static var duct_covers: bool = false
## Draws the ducts open whatever [member duct_covers] says (the export,
## which shows the wiring).
var open_ducts: bool = false

## Height the plate fits into at zoom 1 too (0: the width alone); the
## drawing is then centred across.
var fit_height: float = 0.0:
	set(value):
		fit_height = value
		update_minimum_size()
		queue_redraw()

## Most zoom over fitting the width; one wheel step.
const MAX_ZOOM: float = 8.0
const ZOOM_STEP: float = 1.25
## Seconds after the last zoom change before the drawing is painted sharp
## at the new scale (until then the last painting is scaled).
const ZOOM_SETTLE: float = 0.15
## The scale the plate fits at changes by less than this (a fraction) once
## it is laid out at it; at most this many layouts (see [method _draw]).
const SETTLED: float = 0.002
const SETTLE_ROUNDS: int = 4
## Room (mm) between the enclosure and the door opened beside it, and under
## both for the door harness's conduit.
const DOOR_GAP: float = 40.0
const CONDUIT_ROOM: float = 22.0

var _layout: CabinetLayout
## Scale [member _layout] was laid out at; it is laid out again when the
## scale changes, while editing on every redraw, and after [method refresh].
var _layout_k: float = 0.0
## Scale [member _layout] and its wiring were built at, which it is painted
## at: the terminal strips' pitch is rounded to whole pixels at that scale,
## so painted at the scale it fits at (a little different) the wires would
## miss the terminals.
var _built_k: float = 0.0
## Wires of the last layout, laid out again after edits and when the scale changes.
var _wiring: CabinetWiring
var _wiring_k: float = 0.0
## The back of the door while [member door_open], laid out for the
## enclosure's size.
var _door: StationInside
var _door_layer: Layer

## The layers ([Layer]) under one node, which is scaled while zooming.
var _layers: Node2D
var _base: Layer
var _places: Array[Layer] = []
var _top: Layer
var _mark: Layer
## Layer -> what it was last painted from; painted again when that differs.
var _painted: Dictionary[Layer, Variant] = {}
## Scale and origin the layers were last painted at.
var _painted_k: float = 0.0
var _painted_origin: Vector2 = Vector2.ZERO
## Runs while the zoom is changing (see [constant ZOOM_SETTLE]).
var _settle: Timer
## Wiring a training plan: the port under the mouse and the one a wire
## starts at ({"place", "port"}), the wire picked ({"place", "index"}: its
## pair), where the mouse is (pixels).
var _hover: Dictionary = {}
var _start: Dictionary = {}
var _picked_wire: Dictionary = {}
var _mouse: Vector2 = Vector2.ZERO


## A part of the drawing painted on its own by [member paint] (called with
## the layer), so the rest stays as it was painted.
class Layer:
	extends Node2D

	var paint: Callable

	func _init(p_paint: Callable) -> void:
		paint = p_paint

	func _draw() -> void:
		paint.call(self)


func _init() -> void:
	_layers = Node2D.new()
	add_child(_layers, false, Node.INTERNAL_MODE_FRONT)
	_base = Layer.new(_paint_base)
	_layers.add_child(_base)
	_top = Layer.new(_paint_top)
	_layers.add_child(_top)
	_door_layer = Layer.new(_paint_door)
	_layers.add_child(_door_layer)
	_mark = Layer.new(_paint_mark)
	_layers.add_child(_mark)
	_settle = Timer.new()
	_settle.one_shot = true
	_settle.timeout.connect(queue_redraw)
	add_child(_settle, false, Node.INTERNAL_MODE_FRONT)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh()


## Lays the switchboard out again (after edits or a new document).
func refresh() -> void:
	var k: float = _k()
	_layout = CabinetLayout.build(document, k, board) if document != null else null
	_layout_k = k
	_built_k = k
	_wiring = null
	_door = null
	_painted.clear()
	update_minimum_size()
	queue_redraw()


## Size in mm of what is drawn: the plate, with the open door beside it and
## the conduit's room under both while [member door_open].
func _extent() -> Vector2:
	if _layout == null:
		return Vector2.ZERO
	if not door_open or document == null or board < 0 or board >= document.switchboards.size():
		return _layout.size
	var door: Vector2 = DoorView.size_of(document.switchboards[board].door, _layout.size)
	return Vector2(_layout.size.x + DOOR_GAP + door.x, maxf(_layout.size.y, door.y) + CONDUIT_ROOM)


## Pixels per millimetre: the plate fills the width of the panel, times
## the zoom.
func _k() -> float:
	var extent: Vector2 = _extent()
	if extent.x <= 0.0:
		return 2.0
	var fit: float = _fit_width() / extent.x
	if fit_height > 0.0 and extent.y > 0.0:
		fit = minf(fit, fit_height / extent.y)
	return clampf(fit, 0.6, 6.0) * zoom


## Where the plate's top-left corner is drawn: centred across while it is
## narrower than the view.
func _origin() -> Vector2:
	if _layout == null:
		return Vector2.ZERO
	return Vector2(maxf(0.0, floorf((size.x - _extent().x * _k()) * 0.5)), 0.0)


## Width the plate fills at zoom 1: the scrolling parent's, else its own.
func _fit_width() -> float:
	var parent: Control = get_parent() as Control
	var w: float = parent.size.x if parent is ScrollContainer else size.x
	return w if w > 1.0 else 260.0


func _get_minimum_size() -> Vector2:
	if _layout == null:
		return Vector2.ZERO
	var k: float = _k()
	return Vector2(floorf(_extent().x * k) if zoom > 1.0 else 0.0, ceilf(_extent().y * k))


## Size of the plate in mm as laid out last (after [method refresh]).
func plate_size() -> Vector2:
	return _layout.size if _layout != null else Vector2.ZERO


## Size of the drawing as laid out last (after [method refresh]).
func drawn_size() -> Vector2:
	return _extent() * _k() if _layout != null else Vector2.ZERO


## Zooms by [param factor] keeping the point [param at] (pixels in the
## view) where it is on the screen, by scrolling the panel.
func zoom_at(factor: float, at: Vector2) -> void:
	# The point of the plate under the mouse (the plate is drawn from
	# [method _origin], centred while narrower than the view).
	var on_plate: Vector2 = (at - _origin()) / _k()
	zoom *= factor
	await get_tree().process_frame
	_scroll_by(_origin() + on_plate * _k() - at)


## Scrolls the switchboard sideways (its own scroller) and down (the panel's).
func _scroll_by(by: Vector2) -> void:
	var across: ScrollContainer = get_parent() as ScrollContainer
	if across != null:
		across.scroll_horizontal += roundi(by.x)
	var node: Node = get_parent().get_parent() if across != null else get_parent()
	while node != null and not (node is ScrollContainer):
		node = node.get_parent()
	if node != null:
		(node as ScrollContainer).scroll_vertical += roundi(by.y)


## Ctrl+wheel over the drawing zooms it (before the panel's own zoom takes it).
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not is_visible_in_tree():
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or not (mb.ctrl_pressed or mb.meta_pressed):
		return
	if mb.button_index != MOUSE_BUTTON_WHEEL_UP and mb.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	var at: Vector2 = get_global_transform_with_canvas().affine_inverse() * mb.position
	# Over the part of the drawing shown (the scroller cuts the rest off).
	var shown: Control = get_parent() as Control if get_parent() is ScrollContainer else self
	var in_shown: Vector2 = shown.get_global_transform_with_canvas().affine_inverse() * mb.position
	if not Rect2(Vector2.ZERO, size).has_point(at) or not Rect2(Vector2.ZERO, shown.size).has_point(in_shown):
		return
	zoom_at(ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP, at)
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		update_minimum_size()
		queue_redraw()
	elif what == NOTIFICATION_THEME_CHANGED:
		_painted.clear()
		queue_redraw()


# --- Input -----------------------------------------------------------------------------

func _place_at(position_px: Vector2, under: Array = []) -> int:
	if _layout == null:
		return -1
	return _layout.place_at((position_px - _origin()) / _k(), under)


## Designation a click at the place operates while simulating, "" for none.
func _operated(index: int, under: bool) -> String:
	if index < 0:
		return ""
	var place: Dictionary = _layout.places[index]
	if under:
		return place.get("under_designation", "")
	match place["kind"]:
		CabinetDevices.Kind.BREAKER, CabinetDevices.Kind.FUSE, CabinetDevices.Kind.OVERLOAD:
			return place["designation"]
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0:
		# Right or middle drag moves a zoomed switchboard.
		_scroll_by(-(event as InputEventMouseMotion).relative)
		accept_event()
		return
	if wiring_mode and not simulating:
		_wiring_input(event)
		return
	if wiring_mode and simulating and TrainingPick.probing:
		_probe_input(event)
		return
	if event is InputEventMouseMotion:
		var under: Array = []
		var index: int = _place_at((event as InputEventMouseMotion).position, under)
		var clickable: bool = index >= 0 and (simulating and not _operated(index, not under.is_empty()).is_empty() or not simulating and _selectable(_layout.places[index]))
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var under: Array = []
	var index: int = _place_at(mb.position, under)
	if simulating:
		var designation: String = _operated(index, not under.is_empty())
		if not designation.is_empty():
			operate_requested.emit(designation)
			accept_event()
		return
	if index < 0 or not _selectable(_layout.places[index]):
		# Nothing, or a place the switchboard adds by itself.
		place_clicked.emit(-1, -1)
	else:
		place_clicked.emit(_layout.places[index]["rail"], _layout.places[index]["index"])
	accept_event()


## Laying and picking the student's wires (see [member wiring_mode]).
func _wiring_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
		var hit: Dictionary = _port_under(_mouse)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hit.is_empty() else Control.CURSOR_ARROW
		if hit != _hover or not _start.is_empty():
			_hover = hit
			queue_redraw()
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).keycode:
			KEY_DELETE, KEY_BACKSPACE:
				if not _picked_wire.is_empty() and not document.training.locked():
					var picked: Dictionary = _picked_wire
					_pick({})
					wire_removed.emit(picked["place"], picked["index"])
					accept_event()
			KEY_ESCAPE:
				if not _start.is_empty() or not _picked_wire.is_empty():
					_start = {}
					_pick({})
					queue_redraw()
					accept_event()
		return
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	grab_focus()
	var at: Vector2 = (event as InputEventMouseButton).position
	# A fault-finding task's wiring is given: wires are picked, not laid.
	var hit: Dictionary = _port_under(at) if not document.training.locked() else {}
	if not hit.is_empty():
		_pick({})
		if not _start.is_empty() and _start["place"] == hit["place"] and _start["port"] != hit["port"]:
			var from: Dictionary = _start
			_start = {}
			wire_drawn.emit(hit["place"], from["port"], hit["port"])
		elif _start == hit:
			_start = {}
		else:
			_start = hit
		queue_redraw()
		accept_event()
		return
	_start = {}
	_pick(_wire_under(at))
	if _picked_wire.is_empty():
		# Neither a port nor a wire: the place there is picked (the student
		# mounting the parts moves it).
		var index: int = _place_at(at, [])
		if index >= 0 and _layout.places[index]["index"] >= 0:
			place_clicked.emit(_layout.places[index]["rail"], _layout.places[index]["index"])
		else:
			place_clicked.emit(-1, -1)
	queue_redraw()
	accept_event()


## Measuring with the multimeter while a training plan runs: a click on a
## port puts the next probe on it (see [TrainingPick]).
func _probe_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit: Dictionary = _port_under((event as InputEventMouseMotion).position)
		mouse_default_cursor_shape = Control.CURSOR_CROSS if not hit.is_empty() else Control.CURSOR_ARROW
		if hit != _hover:
			_hover = hit
			queue_redraw()
		return
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var hit: Dictionary = _port_under((event as InputEventMouseButton).position)
	if not hit.is_empty():
		TrainingPick.put_probe(hit["place"] + "|" + hit["port"])
		queue_redraw()
		accept_event()


## Picks the wire [param picked] ({"place", "index"}, {} for none).
func _pick(picked: Dictionary) -> void:
	if picked == _picked_wire:
		return
	_picked_wire = picked
	wire_picked.emit(picked.get("place", ""), picked.get("index", -1))


## The switchboard's place in a training plan ("+RA1") and its door's.
func training_place(on_door: bool = false) -> String:
	if document == null or board < 0 or board >= document.switchboards.size():
		return ""
	return "+" + document.switchboards[board].name + ("/door" if on_door else "")


## Where the open door's back is drawn from (mm from the plate's corner).
func _door_at() -> Vector2:
	return Vector2(_layout.size.x + DOOR_GAP, 0.0) if _layout != null else Vector2.ZERO


## The port at [param position_px] ({"place", "port"}), {} for none.
func _port_under(position_px: Vector2) -> Dictionary:
	if _wiring == null or _painted_k <= 0.0:
		return {}
	var at: Vector2 = (position_px - _painted_origin) / _painted_k
	var port: String = TrainingPick.port_at(_wiring.ports, at, _painted_k)
	if not port.is_empty():
		return {"place": training_place(), "port": port}
	if door_open and _door != null:
		port = TrainingPick.port_at(_door.ports, at - _door_at(), _painted_k)
		if not port.is_empty():
			return {"place": training_place(true), "port": port}
	return {}


## The student's wire at [param position_px] ({"place", "index"}: its pair), {} for none.
func _wire_under(position_px: Vector2) -> Dictionary:
	if _wiring == null or _painted_k <= 0.0:
		return {}
	var at: Vector2 = (position_px - _painted_origin) / _painted_k
	var w: int = TrainingPick.wire_at(_wiring.wires, at, _painted_k)
	if w >= 0 and w < _wiring.pairs.size():
		return {"place": training_place(), "index": _wiring.pairs[w]}
	if door_open and _door != null:
		w = TrainingPick.wire_at(_door.wires, at - _door_at(), _painted_k)
		if w >= 0 and w < _door.pairs.size():
			return {"place": training_place(true), "index": _door.pairs[w]}
	return {}


## What the marks of the wiring show in [param place] (see [method TrainingPick.draw]).
func _marks_of(place: String, pairs: Array[int]) -> Dictionary:
	var state: Dictionary = {"selected": -1}
	if _hover.get("place", "") == place:
		state["hover"] = _hover["port"]
	if _start.get("place", "") == place:
		state["start"] = _start["port"]
		state["mouse"] = _mouse
	if _picked_wire.get("place", "") == place:
		state["selected"] = pairs.find(_picked_wire["index"])
	state["problems"] = TrainingPick.marked_in(place)
	if simulating:
		state["problems"] = PackedStringArray()
		state["probes"] = TrainingPick.probes_in(place)
	return state


## True for a place picked by a click in Edit mode: a rail item, or a
## distribution block the switchboard put by itself (to be moved).
static func _selectable(place: Dictionary) -> bool:
	return place["index"] >= 0 or place["kind"] == CabinetLayout.BUS_BLOCK


## The place laid out for rail [param rail] and index [param index] (see
## [member CabinetLayout.places]), {} for none.
func place_of(rail: int, index: int) -> Dictionary:
	if _layout != null:
		for place: Dictionary in _layout.places:
			if place["rail"] == rail and place["index"] == index:
				return place
	return {}


func _get_tooltip(at_position: Vector2) -> String:
	if wiring_mode and (not simulating or TrainingPick.probing):
		var hit: Dictionary = _port_under(at_position)
		if not hit.is_empty():
			return TrainingPick.port_text(hit["port"])
	var under: Array = []
	var index: int = _place_at(at_position, under)
	if index < 0:
		return ""
	var place: Dictionary = _layout.places[index]
	if not under.is_empty():
		return tr("Overload relay") + " -" + str(place["under_designation"])
	var text: String
	match place["kind"]:
		CabinetLayout.STRIP:
			text = tr("Terminal strip") + " -" + str(place["designation"])
		CabinetLayout.MISSING_DEVICE:
			return "-%s – %s" % [place["designation"], tr("not in the schematic")]
		CabinetLayout.BUS_BLOCK:
			return tr("N distribution block") if place["desc"]["neutral"] else tr("PE distribution block")
		_:
			text = tr(CabinetPanel.KIND_TITLES[place["kind"]]) + " -" + str(place["designation"])
	if simulating and not _operated(index, false).is_empty():
		text += "\n" + tr("Click to operate it")
	return text


# --- Drawing ---------------------------------------------------------------------------

func _draw() -> void:
	_layers.visible = document != null
	if document == null:
		return
	var k: float = _k()
	if not _settle.is_stopped() and _painted_k > 0.0:
		# Zooming: the last painting scaled until the zoom settles.
		var scale: float = k / _painted_k
		_layers.scale = Vector2(scale, scale)
		_layers.position = _origin() - _painted_origin * scale
		return
	var height: float = _extent().y
	if _layout == null or not is_equal_approx(_layout_k, k):
		# Laid out for the scale shown (edits lay it out again, see [method
		# refresh]). The plate is a little wider or narrower at each scale
		# (the terminal strips are snapped to whole pixels), so laid out
		# again until the scale it fits at settles, then shown at the scale
		# last laid out at.
		_wiring = null
		for round: int in SETTLE_ROUNDS:
			_layout = CabinetLayout.build(document, k, board)
			_built_k = k
			_layout_k = k
			var fits: float = _k()
			_layout_k = fits
			if absf(fits / k - 1.0) < SETTLED:
				break
			k = fits
	elif simulating:
		# The devices show the simulation state; the places stay where they are.
		for place: Dictionary in _layout.places:
			CabinetLayout.describe_again(document, place)
	k = _built_k
	if not is_equal_approx(height, _extent().y):
		update_minimum_size.call_deferred()
	if _wiring == null or not is_equal_approx(_wiring_k, k):
		if wiring_mode and document.training != null:
			_wiring = CabinetWiring.build_given(document, _layout, k, board, document.training.wires_of(training_place()))
		else:
			_wiring = _layout.wiring if _layout.wiring != null else CabinetWiring.build(document, _layout, k, board)
		_wiring_k = k
	_layers.scale = Vector2.ONE
	_layers.position = Vector2.ZERO
	_painted_k = k
	_painted_origin = _origin()
	var at: Array = [k, _painted_origin]
	_repaint(_base, [at, _layout.size, _layout.rails, _layout.ducts])
	while _places.size() < _layout.places.size():
		var layer: Layer = Layer.new(_paint_place.bind(_places.size()))
		_layers.add_child(layer)
		_layers.move_child(layer, _top.get_index())
		_places.append(layer)
	while _places.size() > _layout.places.size():
		var gone: Layer = _places.pop_back()
		_painted.erase(gone)
		gone.queue_free()
	for i: int in _places.size():
		var place: Dictionary = _layout.places[i]
		_repaint(_places[i], [at, place, _place_reach(place)])
	_repaint(_top, [at, _wiring.get_instance_id(), _covered()])
	if door_open and _door == null:
		# The harness comes into the door at the height it leaves the switchboard.
		var across: float = -1.0
		for gland: Dictionary in _wiring.glands:
			if gland.get("door", false):
				across = (gland["rect"] as Rect2).get_center().y
		if wiring_mode and document.training != null:
			_door = StationInside.build_door_given(document, board, _layout.size, across, document.training.wires_of(training_place(true)))
		else:
			_door = StationInside.build_door(document, board, _layout.size, across)
	_repaint(_door_layer, [at, _door.get_instance_id() if door_open else 0, _door_reach()])
	var mark: Rect2 = Rect2()
	if not simulating:
		for place: Dictionary in _layout.places:
			if Vector2i(place["rail"], place["index"]) == selected:
				mark = place["rect"]
				if place.has("under_rect"):
					mark = mark.merge(place["under_rect"])
	var marks: Array = []
	if wiring_mode and (not simulating or TrainingPick.probing):
		var door_pairs: Array[int] = []
		if door_open and _door != null:
			door_pairs = _door.pairs
		marks = [_marks_of(training_place(), _wiring.pairs), _marks_of(training_place(true), door_pairs)]
	_repaint(_mark, [at, mark, marks])


## Paints [param layer] again when [param state] (what it shows) differs
## from what it was last painted from.
func _repaint(layer: Layer, state: Array) -> void:
	if _painted.get(layer) == state:
		return
	_painted[layer] = state.duplicate(true)
	layer.queue_redraw()


## The voltage colours a place shows (all its terminals).
func _place_reach(place: Dictionary) -> Array:
	var result: Array = []
	if not simulating:
		return result
	var desc: Dictionary = place["desc"]
	if place["kind"] == CabinetLayout.STRIP:
		for t: Dictionary in desc["terminals"]:
			result.append(_first_reach(t["keys"]))
		return result
	for d: Dictionary in [desc, place.get("under_desc", {})]:
		var terminals: Dictionary = d.get("terminals", {})
		for name: String in terminals:
			result.append(_color(terminals[name]))
	return result


func _painter(canvas: CanvasItem) -> CabinetPainter:
	return CabinetPainter.new(canvas, _painted_k, _painted_origin)


## The plate with its DIN rails and ducts.
func _paint_base(canvas: CanvasItem) -> void:
	var p: CabinetPainter = _painter(canvas)
	CabinetParts.plate(p, _layout.size)
	for rail: Rect2 in _layout.rails:
		CabinetParts.din_rail(p.shifted(rail.position), rail.size.x)
	for duct: Dictionary in _layout.ducts:
		var r: Rect2 = duct["rect"]
		CabinetParts.duct(p.shifted(r.position), r.size.y if duct["vertical"] else r.size.x, r.size.x if duct["vertical"] else r.size.y, duct["vertical"])


## A place with its labels, under the wires running past them.
func _paint_place(canvas: CanvasItem, index: int) -> void:
	if index >= _layout.places.size():
		return
	var p: CabinetPainter = _painter(canvas)
	var place: Dictionary = _layout.places[index]
	_draw_place(p, place)
	if place["label_w"] > 0.0:
		CabinetParts.label(p, place["label_at"], "-" + str(place["designation"]), place["label_w"])
	if place.has("under_label_at"):
		CabinetParts.label(p, place["under_label_at"], "-" + str(place["under_designation"]), 12.0)


## The ducts' covers are drawn (see [member duct_covers]).
func _covered() -> bool:
	return duct_covers and not open_ducts


## The wires with their marker sleeves and the cable glands; the ducts'
## covers over the wires in them.
func _paint_top(canvas: CanvasItem) -> void:
	var p: CabinetPainter = _painter(canvas)
	for wire: Dictionary in _wiring.wires:
		CabinetParts.wire(p, wire["points"], wire["conductor"], wire["width"], wire["external"], wire["pins"])
	for twin: Dictionary in _wiring.twins:
		CabinetParts.twin_ferrule(p, twin["at"], twin["up"], twin["width"])
	if _covered():
		for duct: Dictionary in _layout.ducts:
			var r: Rect2 = duct["rect"]
			CabinetParts.duct_cover(p.shifted(r.position), r.size.y if duct["vertical"] else r.size.x, r.size.x if duct["vertical"] else r.size.y, duct["vertical"])
	# The marker sleeves over every wire, so a wire running past never hides one.
	for wire: Dictionary in _wiring.wires:
		CabinetParts.wire_markers(p, wire["markers"], wire["mark"], wire["width"])
	for gland: Dictionary in _wiring.glands:
		var r: Rect2 = gland["rect"]
		if gland.get("door", false):
			# The door harness's fitting in the hinge side wall, tagged as such.
			CabinetParts.door_fitting(p, r)
			CabinetParts.label(p, Vector2(r.position.x - 6.0, r.position.y - 3.5), tr("Door"), 10.0)
			continue
		CabinetParts.cable_gland(p, r, gland["bottom"])
		if gland["bottom"]:
			# The cable's name (or the part it goes to), on a tag over the gland.
			CabinetParts.label(p, r.get_center() + Vector2(0.0, -0.6), str(gland["cable"]), r.size.x - 1.0)


## What the back of the open door shows of the simulation: the voltage
## colours of its terminals, its lamps lit.
func _door_reach() -> Array:
	var result: Array = []
	if not door_open or _door == null or not simulating:
		return result
	for key: String in _door.terminals:
		result.append(_color(key))
	for entry: Dictionary in _door.items:
		for block: Dictionary in entry["blocks"]:
			if block["kind"] == "LAMP":
				result.append(_lamp_lit(block))
	return result


func _lamp_lit(block: Dictionary) -> bool:
	if not simulating or block["terminals"].is_empty():
		return false
	var lamp: CircuitComponent = document.circuit.get_terminal_owner(block["terminals"][0]["key"])
	return lamp is Lamp and (lamp as Lamp).energized


## The door opened beside the switchboard: its back with its devices and
## wires, the hinges on the side by the switchboard, the locks' latches on
## the other; the door harness's conduit from the switchboard's bottom,
## under it, across and up into the door.
func _paint_door(canvas: CanvasItem) -> void:
	if not door_open or _door == null or _layout == null:
		return
	var p: CabinetPainter = _painter(canvas)
	var at: Vector2 = Vector2(_layout.size.x + DOOR_GAP, 0.0)
	var q: CabinetPainter = p.shifted(at)
	var door: Rect2 = Rect2(Vector2.ZERO, _door.size)
	q.gradient(door, DoorView.DOOR.darkened(0.04), DoorView.DOOR.darkened(0.12), 4.0, DoorView.DOOR_EDGE, 0.6)
	# The folded edge and the stiffening frame inside it.
	q.rect(door.grow(-6.0), Color.TRANSPARENT, 3.0, Color(0, 0, 0, 0.18), 0.8)
	for y: float in [70.0, door.size.y - 70.0]:
		# The hinges on the side by the switchboard, the locks' latches on the other.
		q.rect(Rect2(-3.0, y - 30.0, 6.0, 60.0), CabinetParts.METAL_DARK, 1.5, CabinetParts.METAL_DARK.darkened(0.3), 0.3)
		var lock: Vector2 = Vector2(door.size.x - 24.0, y)
		q.circle(lock, 7.0, DoorView.LOCK.darkened(0.15), DoorView.LOCK_DARK, 0.3)
		q.rect(Rect2(lock.x - 2.5, lock.y - 14.0, 5.0, 28.0), DoorView.LOCK_DARK, 1.0)
	StationInsideView.paint(q, _door, _color, _lamp_lit)
	if _door.glands.is_empty() or _door.glands[0]["cores"] == 0:
		return
	var entry: Rect2 = _door.glands[0]["rect"]
	# The conduit straight across the hinge, from the fitting in the
	# switchboard's wall to the one in the door's edge.
	var exit: Rect2 = Rect2()
	for gland: Dictionary in _wiring.glands:
		if gland.get("door", false):
			exit = gland["rect"]
	if exit.has_area():
		var points: PackedVector2Array = PackedVector2Array([Vector2(exit.end.x, exit.get_center().y), at + Vector2(entry.position.x, entry.get_center().y)])
		CabinetParts.conduit(p, points, minf(maxf(entry.size.y * 0.6, 5.0), 12.0))
		# The wire numbers of its cores on a tag over the conduit.
		var numbers: PackedStringArray = PackedStringArray()
		for wire: Dictionary in _door.wires:
			if wire["external"] and not str(wire["mark"]).is_empty() and not numbers.has(wire["mark"]):
				numbers.append(wire["mark"])
		if not numbers.is_empty():
			var text: String = " ".join(numbers)
			var width: float = clampf(text.length() * 2.2 + 3.0, 10.0, maxf(DOOR_GAP + 30.0, 10.0))
			CabinetParts.label(p, (points[0] + points[1]) * 0.5 + Vector2(0.0, -entry.size.y * 0.5 - 4.0), text, width)
	CabinetParts.door_fitting(q, entry)


## The outline of the place selected for editing; wiring a training plan,
## the ports and the wire being drawn or picked (see [TrainingPick]).
func _paint_mark(canvas: CanvasItem) -> void:
	var mark: Rect2 = _painted[_mark][1]
	if mark.has_area():
		canvas.draw_rect(Rect2(_painted_origin + mark.position * _painted_k, mark.size * _painted_k).grow(3.0), AppTheme.accent, false, 2.0)
	var marks: Array = _painted[_mark][2]
	if marks.is_empty() or _wiring == null:
		return
	TrainingPick.draw(canvas, _painted_origin, _painted_k, _wiring.ports, _wiring.wires, marks[0])
	if door_open and _door != null:
		TrainingPick.draw(canvas, _painted_origin + _door_at() * _painted_k, _painted_k, _door.ports, _door.wires, marks[1])


func _draw_place(p: CabinetPainter, place: Dictionary) -> void:
	var q: CabinetPainter = p.shifted(place["origin"])
	var desc: Dictionary = place["desc"]
	match place["kind"]:
		CabinetDevices.Kind.BREAKER, CabinetDevices.Kind.FUSE:
			CabinetParts.device(q, desc, {}, _pole_reach(desc))
		CabinetDevices.Kind.CONTACTOR, CabinetDevices.Kind.RELAY, CabinetDevices.Kind.TIMER, CabinetDevices.Kind.OVERLOAD, \
				CabinetDevices.Kind.RECTIFIER, CabinetDevices.Kind.PLC, CabinetDevices.Kind.VFD, CabinetDevices.Kind.SWITCH:
			CabinetParts.device(q, desc, _named_reach(desc))
			if place.has("under_origin"):
				var under: Dictionary = place["under_desc"]
				CabinetParts.overload_relay(p.shifted(place["under_origin"]), under.get("tripped", false), "5", _named_reach(under))
		CabinetLayout.BUS_BLOCK:
			CabinetParts.bus_block(q, desc["connections"], desc["neutral"])
		CabinetLayout.STRIP:
			var items: Array = []
			var bridges: Array = desc.get("bridges", [])
			for i: int in desc["terminals"].size():
				var t: Dictionary = desc["terminals"][i]
				items.append({"label": t["label"], "kind": t["kind"], "reach": _first_reach(t["keys"]), "bridge": i < bridges.size() and bridges[i]})
			CabinetParts.terminal_strip(q, place["designation"], items)
		_:
			CabinetParts.missing(q, place["size"], "-" + str(place["designation"]))


## Colour of the voltage reaching terminal [param key]; transparent for none
## (and always while editing).
func _color(key: String) -> Color:
	var code: int = reach.get(key, StepResult.REACH_NONE) if simulating else StepResult.REACH_NONE
	return Color.TRANSPARENT if code == StepResult.REACH_NONE else SchematicTheme.reach_color(code)


func _first_reach(keys: PackedStringArray) -> Color:
	for key: String in keys:
		var color: Color = _color(key)
		if color.a > 0.0:
			return color
	return Color.TRANSPARENT


## Terminal name on the device -> voltage colour.
func _named_reach(desc: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var terminals: Dictionary = desc.get("terminals", {})
	for name: String in terminals:
		var color: Color = _color(terminals[name])
		if color.a > 0.0:
			result[name] = color
	return result


## Voltage colours of terminals 1, 2, 3, ... of a breaker or fuse holder.
func _pole_reach(desc: Dictionary) -> Array:
	var result: Array = []
	var terminals: Dictionary = desc.get("terminals", {})
	for t: int in 2 * int(desc["poles"]):
		result.append(_color(terminals.get(str(t + 1), "")))
	return result
