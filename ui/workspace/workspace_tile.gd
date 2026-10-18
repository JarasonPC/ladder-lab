class_name WorkspaceTile
extends RefCounted
## The solid tiles of the workspace: a coloured square (a circle for a
## motor) with a white sign of what it is. Drawn on the workspace canvas
## and, as icons, in its tree. The signs are laid out on a 32 x 32 grid.

enum Kind { SWITCHBOARD, STATION, MOTOR, LIMIT_SWITCH, SENSOR, GROUP }

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
		Kind.GROUP:
			tile = '<rect x="2" y="5" width="28" height="22" rx="5" fill="%s" fill-opacity="0.35" stroke="%s" stroke-width="2" stroke-dasharray="4 3"/>' % [hex, hex]
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 32 32">%s<g fill="none" stroke="#ffffff" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [size, size, tile, SIGN_WIDTH * 1.2, sign]
	var texture: Texture2D = DPITexture.create_from_string(svg)
	_icons[key] = texture
	return texture
