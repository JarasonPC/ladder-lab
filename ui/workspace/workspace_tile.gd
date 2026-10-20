class_name WorkspaceTile
extends RefCounted
## The solid tiles of the workspace: a coloured square (a circle for a
## motor) with a white sign of what it is. Drawn on the workspace canvas
## and, as icons, in its tree. The signs are laid out on a 32 x 32 grid.

enum Kind { SWITCHBOARD, STATION, MOTOR, LIMIT_SWITCH, SENSOR, GROUP, INDUCTIVE, CAPACITIVE, MAGNETIC, LIGHT, PRESSURE, LEVEL, FLOW, TEMPERATURE }

const SIGN := Color.WHITE
const SIGN_WIDTH: float = 1.8

static var _icons: Dictionary[String, Texture2D] = {}


## Tile kind of a part in the field ([enum Workspace.Field]).
static func of_field(field: Workspace.Field) -> Kind:
	match field:
		Workspace.Field.LIMIT_SWITCH:
			return Kind.LIMIT_SWITCH
		Workspace.Field.SENSOR:
			return Kind.SENSOR
	return Kind.MOTOR


## Tile kind of part [param c] in the field: a sensor by what it senses or
## measures (a threaded sensor barrel, a light sensor, a gauge, a tank, a
## pipe, a thermometer), else by its [enum Workspace.Field].
static func of_part(c: CircuitComponent) -> Kind:
	if c is ProximitySensor:
		match (c as ProximitySensor).sensing:
			ProximitySensor.Sensing.CAPACITIVE:
				return Kind.CAPACITIVE
			ProximitySensor.Sensing.MAGNETIC:
				return Kind.MAGNETIC
			ProximitySensor.Sensing.OPTICAL:
				return Kind.LIGHT
		return Kind.INDUCTIVE
	if c is Transmitter:
		match (c as Transmitter).quantity:
			Transmitter.Quantity.LEVEL:
				return Kind.LEVEL
			Transmitter.Quantity.FLOW:
				return Kind.FLOW
		return Kind.PRESSURE
	if c is TemperatureSensor:
		return Kind.TEMPERATURE
	return of_field(Workspace.field_kind(c))


## Tile kind of a place ([enum Workspace.Place]).
static func of_place(place: Workspace.Place) -> Kind:
	match place:
		Workspace.Place.SWITCHBOARD:
			return Kind.SWITCHBOARD
		Workspace.Place.STATION:
			return Kind.STATION
	return Kind.GROUP


static func color(kind: Kind) -> Color:
	match kind:
		Kind.SWITCHBOARD:
			return SchematicTheme.TILE_SWITCHBOARD
		Kind.STATION:
			return SchematicTheme.TILE_STATION
		Kind.GROUP:
			return SchematicTheme.GROUP_EDGE
	return SchematicTheme.TILE_FIELD


## Draws a [param kind] tile filling [param rect] on [param item].
static func draw(item: CanvasItem, kind: Kind, rect: Rect2) -> void:
	var fill: Color = color(kind)
	if kind == Kind.MOTOR:
		item.draw_circle(rect.get_center(), rect.size.x * 0.5, fill, true, -1.0, true)
	else:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = fill
		box.set_corner_radius_all(int(round(rect.size.x * 0.18)))
		box.anti_aliasing = true
		box.draw(item.get_canvas_item(), rect)
	var k: float = rect.size.x / 32.0
	var at: Callable = func(x: float, y: float) -> Vector2: return rect.position + Vector2(x, y) * k
	var w: float = SIGN_WIDTH * k
	match kind:
		Kind.SWITCHBOARD:
			_rect(item, Rect2(at.call(8, 6), Vector2(16, 20) * k), w)
			for y: float in [12.0, 17.0, 22.0]:
				item.draw_line(at.call(11, y), at.call(21, y), SIGN, w, true)
		Kind.STATION:
			_rect(item, Rect2(at.call(10.5, 4), Vector2(11, 24) * k), w)
			for y: float in [10.0, 16.0, 22.0]:
				item.draw_arc(at.call(16, y), 2.4 * k, 0.0, TAU, 24, SIGN, w, true)
		Kind.MOTOR:
			item.draw_arc(at.call(16, 16), 10.5 * k, 0.0, TAU, 48, SIGN, w, true)
			var font: Font = AppTheme.schematic_font()
			var size: int = maxi(1, roundi(11.0 * k))
			item.draw_string(font, at.call(16, 16) + Vector2(-16.0 * k, 4.0 * k), "M", HORIZONTAL_ALIGNMENT_CENTER, 32.0 * k, size, SIGN)
		Kind.LIMIT_SWITCH:
			_rect(item, Rect2(at.call(8, 15), Vector2(16, 12) * k), w)
			item.draw_line(at.call(16, 15), at.call(20.5, 8.5), SIGN, w, true)
			item.draw_arc(at.call(21.8, 6.8), 2.4 * k, 0.0, TAU, 24, SIGN, w, true)
		Kind.SENSOR:
			_rect(item, Rect2(at.call(6, 8), Vector2(20, 16) * k), w)
			item.draw_line(at.call(6, 24), at.call(26, 8), SIGN, w, true)
		Kind.INDUCTIVE, Kind.CAPACITIVE, Kind.MAGNETIC:
			# A threaded barrel, its cable out of the back.
			_rect(item, Rect2(at.call(5, 11), Vector2(16, 10) * k), w)
			for x: float in [9.0, 12.5, 16.0]:
				item.draw_line(at.call(x, 11), at.call(x, 21), SIGN, w, true)
			item.draw_polyline(PackedVector2Array([at.call(21, 16), at.call(24, 16), at.call(27, 19), at.call(27, 26)]), SIGN, w, true)
		Kind.LIGHT:
			_rect(item, Rect2(at.call(10, 8), Vector2(16, 16) * k), w)
			item.draw_arc(at.call(14, 13), 2.0 * k, 0.0, TAU, 16, SIGN, w, true)
			item.draw_arc(at.call(14, 19), 2.0 * k, 0.0, TAU, 16, SIGN, w, true)
			item.draw_line(at.call(7, 13), at.call(5, 13), SIGN, w, true)
			item.draw_line(at.call(7, 19), at.call(5, 19), SIGN, w, true)
		Kind.PRESSURE:
			item.draw_arc(at.call(16, 15), 9.0 * k, 0.0, TAU, 32, SIGN, w, true)
			item.draw_line(at.call(16, 15), at.call(21, 10), SIGN, w, true)
			item.draw_polyline(PackedVector2Array([at.call(14, 24), at.call(14, 28), at.call(18, 28), at.call(18, 24)]), SIGN, w, true)
		Kind.LEVEL:
			_rect(item, Rect2(at.call(8, 7), Vector2(16, 19) * k), w)
			var wave: PackedVector2Array = PackedVector2Array()
			for i: int in 9:
				wave.append(at.call(8.0 + 2.0 * i, 16.0 - 1.5 * sin(i * PI * 0.5)))
			item.draw_polyline(wave, SIGN, w, true)
		Kind.FLOW:
			item.draw_line(at.call(4, 11), at.call(28, 11), SIGN, w, true)
			item.draw_line(at.call(4, 21), at.call(28, 21), SIGN, w, true)
			item.draw_line(at.call(9, 16), at.call(22, 16), SIGN, w, true)
			item.draw_polyline(PackedVector2Array([at.call(18, 13), at.call(22, 16), at.call(18, 19)]), SIGN, w, true)
		Kind.TEMPERATURE:
			_rect(item, Rect2(at.call(13, 5), Vector2(6, 16) * k), w)
			item.draw_arc(at.call(16, 24), 4.5 * k, 0.0, TAU, 24, SIGN, w, true)
			item.draw_circle(at.call(16, 24), 2.4 * k, SIGN, true, -1.0, true)


static func _rect(item: CanvasItem, r: Rect2, w: float) -> void:
	item.draw_polyline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]), SIGN, w, true)


## The tile as an icon [param size] logical pixels large (for the tree).
static func icon(kind: Kind, size: int = 18) -> Texture2D:
	var fill: Color = color(kind)
	if kind == Kind.GROUP:
		fill = SchematicTheme.GROUP_EDGE
	var key: String = "%d/%d/%s" % [kind, size, fill.to_html()]
	if _icons.has(key):
		return _icons[key]
	var hex: String = "#" + fill.to_html(false)
	var tile: String = '<circle cx="16" cy="16" r="16" fill="%s"/>' % hex if kind == Kind.MOTOR else '<rect width="32" height="32" rx="6" fill="%s"/>' % hex
	var sign: String = ""
	match kind:
		Kind.SWITCHBOARD:
			sign = '<rect x="8" y="6" width="16" height="20"/><path d="M11 12h10M11 17h10M11 22h10"/>'
		Kind.STATION:
			sign = '<rect x="10.5" y="4" width="11" height="24"/><circle cx="16" cy="10" r="2.4"/><circle cx="16" cy="16" r="2.4"/><circle cx="16" cy="22" r="2.4"/>'
		Kind.MOTOR:
			sign = '<circle cx="16" cy="16" r="10.5"/><path d="M11.5 20v-8l4.5 5 4.5-5v8"/>'
		Kind.LIMIT_SWITCH:
			sign = '<rect x="8" y="15" width="16" height="12"/><path d="M16 15l4.5-6.5"/><circle cx="21.8" cy="6.8" r="2.4"/>'
		Kind.SENSOR:
			sign = '<rect x="6" y="8" width="20" height="16"/><path d="M6 24L26 8"/>'
		Kind.INDUCTIVE, Kind.CAPACITIVE, Kind.MAGNETIC:
			sign = '<rect x="5" y="11" width="16" height="10"/><path d="M9 11v10M12.5 11v10M16 11v10M21 16h3l3 3v7"/>'
		Kind.LIGHT:
			sign = '<rect x="10" y="8" width="16" height="16"/><circle cx="14" cy="13" r="2"/><circle cx="14" cy="19" r="2"/><path d="M7 13H5M7 19H5"/>'
		Kind.PRESSURE:
			sign = '<circle cx="16" cy="15" r="9"/><path d="M16 15l5-5M14 24v4h4v-4"/>'
		Kind.LEVEL:
			sign = '<rect x="8" y="7" width="16" height="19"/><path d="M8 16q2-3 4 0t4 0t4 0t4 0"/>'
		Kind.FLOW:
			sign = '<path d="M4 11h24M4 21h24M9 16h13M18 13l4 3-4 3"/>'
		Kind.TEMPERATURE:
			sign = '<rect x="13" y="5" width="6" height="16" rx="3"/><circle cx="16" cy="24" r="4.5"/><circle cx="16" cy="24" r="2.4" fill="#ffffff"/>'
		Kind.GROUP:
			tile = '<rect x="2" y="5" width="28" height="22" rx="5" fill="%s" fill-opacity="0.35" stroke="%s" stroke-width="2" stroke-dasharray="4 3"/>' % [hex, hex]
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 32 32">%s<g fill="none" stroke="#ffffff" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [size, size, tile, SIGN_WIDTH * 1.2, sign]
	var texture: Texture2D = DPITexture.create_from_string(svg)
	_icons[key] = texture
	return texture
