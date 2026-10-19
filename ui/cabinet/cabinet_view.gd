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
## A place was clicked while editing (-1, -1: beside the places).
signal place_clicked(rail: int, index: int)
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

var _layout: CabinetLayout
## Scale [member _layout] was laid out at; it is laid out again when the
## scale changes, while editing on every redraw, and after [method refresh].
var _layout_k: float = 0.0
## Wires of the last layout, laid out again after edits and when the scale changes.
var _wiring: CabinetWiring
var _wiring_k: float = 0.0

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
	_layout = CabinetLayout.build(document, _k(), board) if document != null else null
	_layout_k = _k()
	_wiring = null
	_painted.clear()
	update_minimum_size()
	queue_redraw()


## Pixels per millimetre: the plate fills the width of the panel, times
## the zoom.
func _k() -> float:
	if _layout == null or _layout.size.x <= 0.0:
		return 2.0
	var fit: float = _fit_width() / _layout.size.x
	if fit_height > 0.0 and _layout.size.y > 0.0:
		fit = minf(fit, fit_height / _layout.size.y)
	return clampf(fit, 0.6, 6.0) * zoom


## Where the plate's top-left corner is drawn: centred across while it is
## narrower than the view.
func _origin() -> Vector2:
	if _layout == null:
		return Vector2.ZERO
	return Vector2(maxf(0.0, floorf((size.x - _layout.size.x * _k()) * 0.5)), 0.0)


## Width the plate fills at zoom 1: the scrolling parent's, else its own.
func _fit_width() -> float:
	var parent: Control = get_parent() as Control
	var w: float = parent.size.x if parent is ScrollContainer else size.x
	return w if w > 1.0 else 260.0


func _get_minimum_size() -> Vector2:
	if _layout == null:
		return Vector2.ZERO
	var k: float = _k()
	return Vector2(floorf(_layout.size.x * k) if zoom > 1.0 else 0.0, ceilf(_layout.size.y * k))


## Size of the drawing as laid out last (after [method refresh]).
func drawn_size() -> Vector2:
	return _layout.size * _k() if _layout != null else Vector2.ZERO


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
	if event is InputEventMouseMotion:
		var under: Array = []
		var index: int = _place_at((event as InputEventMouseMotion).position, under)
		var clickable: bool = index >= 0 and (not simulating or not _operated(index, not under.is_empty()).is_empty())
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
	if index < 0:
		place_clicked.emit(-1, -1)
	else:
		place_clicked.emit(_layout.places[index]["rail"], _layout.places[index]["index"])
	accept_event()


func _get_tooltip(at_position: Vector2) -> String:
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
	var height: float = _layout.size.y if _layout != null else 0.0
	if _layout == null or not simulating or not is_equal_approx(_layout_k, k):
		_layout = CabinetLayout.build(document, k, board)
		_layout_k = k
	else:
		# The devices show the simulation state; the places stay where they are.
		for place: Dictionary in _layout.places:
			CabinetLayout.describe_again(document, place)
	if not is_equal_approx(height, _layout.size.y):
		update_minimum_size.call_deferred()
	if _wiring == null or not is_equal_approx(_wiring_k, k):
		_wiring = CabinetWiring.build(document, _layout, k, board)
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
	_repaint(_top, [at, _wiring.get_instance_id()])
	var mark: Rect2 = Rect2()
	if not simulating:
		for place: Dictionary in _layout.places:
			if Vector2i(place["rail"], place["index"]) == selected:
				mark = place["rect"]
				if place.has("under_rect"):
					mark = mark.merge(place["under_rect"])
	_repaint(_mark, [at, mark])


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


## The wires with their marker sleeves and the cable glands.
func _paint_top(canvas: CanvasItem) -> void:
	var p: CabinetPainter = _painter(canvas)
	for wire: Dictionary in _wiring.wires:
		CabinetParts.wire(p, wire["points"], wire["conductor"], wire["width"], wire["external"], wire["pins"])
	# The marker sleeves over every wire, so a wire running past never hides one.
	for wire: Dictionary in _wiring.wires:
		CabinetParts.wire_markers(p, wire["markers"], wire["mark"], wire["width"])
	for gland: Dictionary in _wiring.glands:
		CabinetParts.cable_gland(p, gland["rect"], gland["bottom"])
		if gland["bottom"]:
			# The cable's name (or the part it goes to), on a tag over the gland.
			var r: Rect2 = gland["rect"]
			CabinetParts.label(p, r.get_center() + Vector2(0.0, -0.6), str(gland["cable"]), r.size.x - 1.0)


## The outline of the place selected for editing.
func _paint_mark(canvas: CanvasItem) -> void:
	var mark: Rect2 = _painted[_mark][1]
	if mark.has_area():
		canvas.draw_rect(Rect2(_painted_origin + mark.position * _painted_k, mark.size * _painted_k).grow(3.0), AppTheme.accent, false, 2.0)


func _draw_place(p: CabinetPainter, place: Dictionary) -> void:
	var q: CabinetPainter = p.shifted(place["origin"])
	var desc: Dictionary = place["desc"]
	match place["kind"]:
		CabinetDevices.Kind.BREAKER, CabinetDevices.Kind.FUSE:
			CabinetParts.device(q, desc, {}, _pole_reach(desc))
		CabinetDevices.Kind.CONTACTOR, CabinetDevices.Kind.RELAY, CabinetDevices.Kind.TIMER, CabinetDevices.Kind.OVERLOAD, \
				CabinetDevices.Kind.RECTIFIER, CabinetDevices.Kind.PLC, CabinetDevices.Kind.VFD:
			CabinetParts.device(q, desc, _named_reach(desc))
			if place.has("under_origin"):
				var under: Dictionary = place["under_desc"]
				CabinetParts.overload_relay(p.shifted(place["under_origin"]), under.get("tripped", false), "5", _named_reach(under))
		CabinetLayout.STRIP:
			var items: Array = []
			for t: Dictionary in desc["terminals"]:
				items.append({"label": t["label"], "kind": t["kind"], "reach": _first_reach(t["keys"])})
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
