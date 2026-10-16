class_name CabinetView
extends Control
## Draws the switchboard (rozvaděč) of a document like the real thing (see
## [CabinetLayout], [CabinetParts]) with its wiring ([CabinetWiring]), as
## wide as the panel it sits in. While
## simulating, the devices show the circuit's state, terminals are ringed in
## the colour of the voltage that reaches them, and a click switches a
## breaker or fuse holder, replaces a blown fuse or resets a tripped overload
## relay. While editing, a click selects a place.

## A device was clicked while simulating ([param designation] of the
## breaker, fuse or overload relay).
signal operate_requested(designation: String)
## A place was clicked while editing (-1, -1: beside the places).
signal place_clicked(rail: int, index: int)
## The drawing was zoomed.
signal zoom_changed

## Rating printed on the breakers (the circuit does not model it).
const BREAKER_RATING: String = "C16"

var document: SchematicDocument
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
			zoom_changed.emit()

## Most zoom over fitting the width; one wheel step.
const MAX_ZOOM: float = 8.0
const ZOOM_STEP: float = 1.25

var _layout: CabinetLayout
## Wires of the last layout, laid out again after edits and when the scale changes.
var _wiring: CabinetWiring
var _wiring_k: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh()


## Lays the switchboard out again (after edits or a new document).
func refresh() -> void:
	_layout = CabinetLayout.build(document, _k()) if document != null else null
	_wiring = null
	update_minimum_size()
	queue_redraw()


## Pixels per millimetre: the plate fills the width of the panel, times
## the zoom.
func _k() -> float:
	if _layout == null or _layout.size.x <= 0.0:
		return 2.0
	return clampf(_fit_width() / _layout.size.x, 0.6, 6.0) * zoom


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


## Zooms by [param factor] keeping the point [param at] (pixels in the
## view) where it is on the screen, by scrolling the panel.
func zoom_at(factor: float, at: Vector2) -> void:
	var old_k: float = _k()
	zoom *= factor
	var shift: Vector2 = at / old_k * (_k() - old_k)
	await get_tree().process_frame
	_scroll_by(shift)


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
		queue_redraw()


# --- Input -----------------------------------------------------------------------------

func _place_at(position_px: Vector2, under: Array = []) -> int:
	if _layout == null:
		return -1
	return _layout.place_at(position_px / _k(), under)


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
	if document == null:
		return
	# Laid out again on every frame: the devices show the simulation state.
	var k: float = _k()
	var height: float = _layout.size.y if _layout != null else 0.0
	_layout = CabinetLayout.build(document, k)
	if not is_equal_approx(height, _layout.size.y):
		update_minimum_size.call_deferred()
	var p: CabinetPainter = CabinetPainter.new(self, k, Vector2.ZERO)
	CabinetParts.plate(p, _layout.size)
	for rail: Rect2 in _layout.rails:
		CabinetParts.din_rail(p.shifted(rail.position), rail.size.x)
	for duct: Dictionary in _layout.ducts:
		var r: Rect2 = duct["rect"]
		CabinetParts.duct(p.shifted(r.position), r.size.y if duct["vertical"] else r.size.x, r.size.x if duct["vertical"] else r.size.y, duct["vertical"])
	for place: Dictionary in _layout.places:
		_draw_place(p, place)
	if _wiring == null or not is_equal_approx(_wiring_k, k):
		_wiring = CabinetWiring.build(document, _layout, k)
		_wiring_k = k
	for wire: Dictionary in _wiring.wires:
		CabinetParts.wire(p, wire["points"], wire["conductor"], wire["width"], wire["external"])
	for gland: Rect2 in _wiring.glands:
		CabinetParts.cable_gland(p, gland)
	for place: Dictionary in _layout.places:
		if place["label_w"] > 0.0:
			CabinetParts.label(p, place["label_at"], "-" + str(place["designation"]), place["label_w"])
		if place.has("under_label_at"):
			CabinetParts.label(p, place["under_label_at"], "-" + str(place["under_designation"]), 12.0)
	if not simulating:
		for place: Dictionary in _layout.places:
			if Vector2i(place["rail"], place["index"]) == selected:
				var r: Rect2 = place["rect"]
				if place.has("under_rect"):
					r = r.merge(place["under_rect"])
				var px: Rect2 = Rect2(r.position * k, r.size * k).grow(3.0)
				draw_rect(px, AppTheme.accent, false, 2.0)


func _draw_place(p: CabinetPainter, place: Dictionary) -> void:
	var q: CabinetPainter = p.shifted(place["origin"])
	var desc: Dictionary = place["desc"]
	match place["kind"]:
		CabinetDevices.Kind.BREAKER:
			CabinetParts.breaker(q, desc["poles"], desc["on"], BREAKER_RATING if desc["poles"] > 1 else "B10", _pole_reach(desc))
		CabinetDevices.Kind.FUSE:
			CabinetParts.fuse_holder(q, desc["poles"], desc["closed"], desc["blown"], _pole_reach(desc))
		CabinetDevices.Kind.CONTACTOR:
			CabinetParts.contactor(q, desc["on"], desc["energized"], desc["aux"], _named_reach(desc), desc["poles"])
			if place.has("under_origin"):
				var under: Dictionary = place["under_desc"]
				CabinetParts.overload_relay(p.shifted(place["under_origin"]), under.get("tripped", false), "5", _named_reach(under))
		CabinetDevices.Kind.RELAY:
			CabinetParts.relay(q, desc["on"], desc["energized"], _named_reach(desc), desc["poles"])
		CabinetDevices.Kind.TIMER:
			CabinetParts.timer(q, desc["powered"], desc["output"], desc["code"], desc["control"], _named_reach(desc), desc["contacts"])
		CabinetDevices.Kind.OVERLOAD:
			CabinetParts.overload_relay(q, desc["tripped"], "5", _named_reach(desc))
		CabinetDevices.Kind.RECTIFIER:
			CabinetParts.rectifier(q, desc["on"], _named_reach(desc))
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
