class_name CabinetView
extends Control
## Draws the switchboard (rozvaděč) of a document like the real thing (see
## [CabinetLayout], [CabinetParts]), as wide as the panel it sits in. While
## simulating, the devices show the circuit's state, terminals are ringed in
## the colour of the voltage that reaches them, and a click switches a
## breaker or fuse holder, replaces a blown fuse or resets a tripped overload
## relay. While editing, a click selects a place.

## A device was clicked while simulating ([param designation] of the
## breaker, fuse or overload relay).
signal operate_requested(designation: String)
## A place was clicked while editing (-1, -1: beside the places).
signal place_clicked(rail: int, index: int)

## Rating printed on the breakers (the circuit does not model it).
const BREAKER_RATING: String = "C16"

var document: SchematicDocument
## Operate the circuit (true) or select places for editing (false).
var simulating: bool = false
## Terminal key -> reach code of the last simulation step (see [StepResult]).
var reach: Dictionary[String, int] = {}
## Place selected for editing as (rail, index); (-1, -1) for none.
var selected: Vector2i = Vector2i(-1, -1)

var _layout: CabinetLayout


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh()


## Lays the switchboard out again (after edits or a new document).
func refresh() -> void:
	_layout = CabinetLayout.build(document, _k()) if document != null else null
	update_minimum_size()
	queue_redraw()


## Pixels per millimetre: the plate fills the width.
func _k() -> float:
	if _layout == null or _layout.size.x <= 0.0:
		return 2.0
	return clampf((size.x if size.x > 1.0 else 260.0) / _layout.size.x, 0.6, 6.0)


func _get_minimum_size() -> Vector2:
	if _layout == null:
		return Vector2.ZERO
	return Vector2(0.0, ceilf(_layout.size.y * _k()))


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
