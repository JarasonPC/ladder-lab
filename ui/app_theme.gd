class_name AppTheme
extends RefCounted
## The application look: colour tokens for a dark and a light variant, system
## fonts (crisp at any scale), small line icons rasterized from SVG at the
## screen resolution, and the Godot [Theme] built from them. Every panel,
## button and field gets its style from here, so the whole window is one style.
## The schematic paper keeps its own colours ([SchematicTheme]).

enum Variant { DARK, LIGHT }

## Base text size in logical pixels.
const FONT_SIZE: int = 14
const SMALL_FONT_SIZE: int = 12
const RADIUS: int = 6
const UI_FONTS: PackedStringArray = ["Inter", "Segoe UI Variable Text", "Segoe UI", "SF Pro Text", "Helvetica Neue", "Roboto", "Noto Sans", "Ubuntu", "Cantarell", "DejaVu Sans", "Arial", "sans-serif"]
const MONO_FONTS: PackedStringArray = ["JetBrains Mono", "Cascadia Mono", "Consolas", "SF Mono", "Menlo", "Roboto Mono", "Noto Sans Mono", "DejaVu Sans Mono", "monospace"]

static var variant: Variant = Variant.DARK

# Colour tokens, set by [method use].
## Toolbar, status bar and sunken fields.
static var bg0: Color
## Panels.
static var bg1: Color
## Hovered controls, filled fields.
static var bg2: Color
## Pressed controls.
static var bg3: Color
static var border: Color
static var border_strong: Color
static var text: Color
static var text_muted: Color
static var text_faint: Color
static var accent: Color
static var accent_hover: Color
static var accent_soft: Color
static var on_accent: Color
static var danger: Color
static var warning: Color
static var success: Color
static var popup_bg: Color
static var tooltip_bg: Color
static var chart_bg: Color
static var chart_grid: Color
## Lessons and the tour: what they point at, ring and propose (never the
## accent, which marks the selection, nor a colour of the wires).
static var tutorial: Color
static var tutorial_hover: Color
static var tutorial_soft: Color

static var _ui_font: SystemFont
static var _ui_bold: SystemFont
static var _mono_font: SystemFont
static var _schematic_font: SystemFont
static var _icons: Dictionary[String, Texture2D] = {}

## Line icons (24 × 24, 2 px stroke), drawn white and tinted by the theme.
const ICON_PATHS: Dictionary[String, String] = {
	"edit": '<path d="M21.17 6.81a1 1 0 0 0-3.99-3.99L3.84 16.17a2 2 0 0 0-.5.83l-1.32 4.35a.5.5 0 0 0 .62.62l4.35-1.32a2 2 0 0 0 .83-.5z"/><path d="m15 5 4 4"/>',
	"simulate": '<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/>',
	"undo": '<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
	"redo": '<path d="m15 14 5-5-5-5"/><path d="M20 9H9.5a5.5 5.5 0 0 0 0 11H13"/>',
	"rotate": '<path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/>',
	"flip": '<path d="m7 3 5 5 5-5z"/><path d="m7 21 5-5 5 5z"/><path d="M20 12h2"/><path d="M14 12h2"/><path d="M8 12h2"/><path d="M2 12h2"/>',
	"mirror": '<path d="m3 7 5 5-5 5z"/><path d="m21 7-5 5 5 5z"/><path d="M12 20v2"/><path d="M12 14v2"/><path d="M12 8v2"/><path d="M12 2v2"/>',
	"delete": '<path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><path d="M10 11v6"/><path d="M14 11v6"/>',
	"check": '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
	"play": '<path d="M6 4.5v15a1 1 0 0 0 1.5.86l12.5-7.5a1 1 0 0 0 0-1.72L7.5 3.64A1 1 0 0 0 6 4.5z" fill="#ffffff"/>',
	"pause": '<rect x="6" y="4" width="4" height="16" rx="1" fill="#ffffff"/><rect x="14" y="4" width="4" height="16" rx="1" fill="#ffffff"/>',
	"step": '<path d="M5 5v14"/><path d="M9 5.5v13a.8.8 0 0 0 1.2.7l10.4-6.5a.8.8 0 0 0 0-1.4L10.2 4.8A.8.8 0 0 0 9 5.5z"/>',
	"reset": '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>',
	"close": '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
	"follow": '<path d="M5 12h14"/><path d="m13 6 6 6-6 6"/>',
	"chevron_down": '<path d="m6 9 6 6 6-6"/>',
	"chevron_right": '<path d="m9 18 6-6-6-6"/>',
	"chevron_left": '<path d="m15 18-6-6 6-6"/>',
	"zoom_in": '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/><path d="M11 8v6"/><path d="M8 11h6"/>',
	"zoom_out": '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/><path d="M8 11h6"/>',
	"fit": '<path d="M8 3H5a2 2 0 0 0-2 2v3"/><path d="M21 8V5a2 2 0 0 0-2-2h-3"/><path d="M3 16v3a2 2 0 0 0 2 2h3"/><path d="M16 21h3a2 2 0 0 0 2-2v-3"/>',
	"grid": '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
	"menu": '<path d="M4 6h16"/><path d="M4 12h16"/><path d="M4 18h16"/>',
	"list": '<path d="M8 6h13"/><path d="M8 12h13"/><path d="M8 18h13"/><path d="M3 6h.01"/><path d="M3 12h.01"/><path d="M3 18h.01"/>',
	"clamp": '<path d="M7 10a5 5 0 1 1 10 0"/><path d="M10 10h4"/><rect x="7" y="13" width="10" height="9" rx="1.5"/><path d="M10 17h4"/>',
	"wire_numbers": '<path d="M2 19h20"/><path d="M5 7l2-2v10"/><path d="M12 7a2.5 2.5 0 1 1 4.5 1.5L12 15h5"/>',
	"hash": '<path d="M4 9h16"/><path d="M4 15h16"/><path d="M10 3 8 21"/><path d="m16 3-2 18"/>',
	"panel": '<rect x="6" y="2" width="12" height="20" rx="2"/><circle cx="12" cy="7" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="12" cy="17" r="2"/>',
	"columns": '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 3v18"/><path d="M15 3v18"/>',
	"plus": '<path d="M12 5v14"/><path d="M5 12h14"/>',
	"folder": '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>',
	"lock": '<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
	"arrow_left": '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>',
	"arrow_right": '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>',
	"arrow_up": '<path d="m5 12 7-7 7 7"/><path d="M12 19V5"/>',
	"arrow_down": '<path d="M12 5v14"/><path d="m19 12-7 7-7-7"/>',
	"download": '<path d="M12 15V3"/><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5"/>',
	"datasheet": '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/>',
	"window": '<rect x="2" y="4" width="20" height="16" rx="2"/><path d="M2 9h20"/><path d="M6 6.5h.01"/><path d="M9 6.5h.01"/>',
	"search": '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
	"schematic": '<path d="M5 3v18"/><path d="M19 3v18"/><path d="M5 8h4"/><path d="M15 8h4"/><path d="M9 6v4"/><path d="M15 6v4"/><path d="M5 16h14"/>',
	"select": '<path d="M4 3l7 17 2.5-7.5L21 10z"/>',
	"room": '<rect x="4" y="5" width="16" height="14"/><rect x="2.5" y="3.5" width="3" height="3" fill="#ffffff"/><rect x="18.5" y="17.5" width="3" height="3" fill="#ffffff"/>',
	"door": '<path d="M2 20h4M19 20h3"/><path d="M6 20V7"/><path d="M6 7a13 13 0 0 1 13 13"/>',
	"plan_window": '<path d="M2 8h5v8H2"/><path d="M22 8h-5v8h5"/><path d="M7 10.5h10M7 13.5h10"/>',
	"plan_dimension": '<path d="M4 7v12M20 7v12"/><path d="M4 13h16"/><path d="M7.5 10 4 13l3.5 3M16.5 10l3.5 3-3.5 3"/>',
	"plan_measure": '<path d="M3 16 16 3l5 5L8 21z"/><path d="M7 12l2 2M10 9l2 2M13 6l2 2"/>',
	"plan_array": '<rect x="3" y="3" width="18" height="18"/><path d="M7 7l2 2M9 7l-2 2M15 7l2 2M17 7l-2 2M7 15l2 2M9 15l-2 2M15 15l2 2M17 15l-2 2"/>',
	"plan_note": '<circle cx="5" cy="19" r="1.5"/><path d="M6 18 12 9h9"/><path d="M12 5h9"/>',
	"plan_underlay": '<rect x="3" y="5" width="18" height="14" stroke-dasharray="2 2"/><path d="M7 15l3-4 3 3 2-2 3 3"/>',
	"plan_floors": '<path d="M12 3 3 8l9 5 9-5z"/><path d="M3 12l9 5 9-5"/><path d="M3 16l9 5 9-5"/>',
	"plan_layers": '<path d="M2 12s3.5-6.5 10-6.5S22 12 22 12s-3.5 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
	"walls": '<path d="M3 6h11M18 6h3M3 12h4M11 12h10M3 18h13M20 18h1"/><circle cx="16" cy="6" r="2"/><circle cx="9" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>',
	"house": '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9v12h14V9"/><path d="M10 21v-6h4v6"/>',
	"join": '<path d="M3 4h10v7h8v9H3z"/><path d="M13 12v7" stroke-dasharray="2 2"/><path d="M9 15h8M14 12l3 3-3 3"/>',
	"wire": '<circle cx="5.5" cy="18.5" r="2.5"/><path d="M7.3 16.7 10 14"/><path d="M8 18.5h6V11"/><circle cx="17" cy="7" r="4"/><path d="M14.2 4.2l5.6 5.6M19.8 4.2l-5.6 5.6"/>',
	"bulb": '<path d="M9 18h6"/><path d="M10 21h4"/><path d="M12 3a6 6 0 0 0-4 10.5c.8.8 1 1.6 1 2.5h6c0-.9.2-1.7 1-2.5A6 6 0 0 0 12 3z"/>',
	"factory": '<path d="M2 21h20"/><path d="M3 21V11l5 3v-3l5 3V5h4l1 16"/><path d="M7 18h2"/><path d="M12 18h2"/>',
	"workspace": '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="8.5" y="14" width="7" height="7" rx="1.5"/><path d="M6.5 10v2h11v-2"/><path d="M12 12v2"/>',
	"lesson": '<path d="M2 4h6a4 4 0 0 1 4 4v13a3 3 0 0 0-3-3H2z"/><path d="M22 4h-6a4 4 0 0 0-4 4v13a3 3 0 0 1 3-3h7z"/>',
	"hint": '<path d="M9 18h6"/><path d="M10 22h4"/><path d="M15.09 14c.18-.98.65-1.74 1.41-2.5A4.65 4.65 0 0 0 18 8 6 6 0 0 0 6 8c0 1 .23 2.23 1.5 3.5A4.61 4.61 0 0 1 8.91 14"/>',
	"target": '<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/>',
	"meter": '<rect x="5" y="2" width="14" height="20" rx="2"/><rect x="8" y="5" width="8" height="5"/><circle cx="12" cy="16" r="3"/><path d="M12 16l1.5-1.5"/>',
	"thermometer": '<path d="M14 4v10.54a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0Z"/><path d="M12 15V9"/>',
	"tick": '<path d="M20 6 9 17l-5-5"/>',
	"cabinet": '<rect x="3" y="2" width="18" height="20" rx="2"/><path d="M3 9h18"/><path d="M3 16h18"/><path d="M7 4.5v3"/><path d="M10 4.5v3"/><path d="M13 4.5v3"/><path d="M7 11.5v3"/><path d="M12 11.5v3"/>',
	"shape_line": '<path d="M5 19 19 5"/>',
	"shape_polyline": '<path d="M3 18 9 8l6 8 6-11"/>',
	"shape_polygon": '<path d="M12 3 21 10 17.5 21h-11L3 10z"/>',
	"rotate_back": '<path d="M3 12a9 9 0 1 0 9-9c-2.52 0-4.93 1-6.74 2.74L3 8"/><path d="M3 3v5h5"/>',
	"plan_wall": '<path d="M3 20L10 6l11 4" stroke-width="3.2"/><circle cx="3" cy="20" r="1.8" fill="#ffffff"/><circle cx="10" cy="6" r="1.8" fill="#ffffff"/><circle cx="21" cy="10" r="1.8" fill="#ffffff"/>',
	"room_outline": '<path d="M4 4h16v9h-7v7H4z"/><circle cx="4" cy="4" r="1.8" fill="#ffffff"/><circle cx="20" cy="4" r="1.8" fill="#ffffff"/><circle cx="20" cy="13" r="1.8" fill="#ffffff"/><circle cx="13" cy="13" r="1.8" fill="#ffffff"/><circle cx="13" cy="20" r="1.8" fill="#ffffff"/><circle cx="4" cy="20" r="1.8" fill="#ffffff"/>',
	"room_split": '<rect x="3" y="4" width="18" height="16"/><path d="M12 2v20" stroke-dasharray="3 2"/><path d="M9 12H5M7 10l-2 2 2 2M15 12h4M17 10l2 2-2 2"/>',
	"room_add": '<rect x="3" y="5" width="15" height="14"/><path d="M19 2v6M16 5h6" stroke-width="2.4"/><path d="M3 13h6v6"/>',
	"edit_points": '<path d="M4 18 9 6l7 4 4 9z"/><rect x="2.5" y="16.5" width="3" height="3" fill="#ffffff"/><rect x="7.5" y="4.5" width="3" height="3" fill="#ffffff"/><rect x="14.5" y="8.5" width="3" height="3" fill="#ffffff"/><rect x="18.5" y="17.5" width="3" height="3" fill="#ffffff"/>',
	"rotate_any": '<path d="M20 12a8 8 0 1 1-2.34-5.66"/><path d="M20 3v4h-4"/><path d="M12 12l4.5-2.5"/><path d="M12 12h5"/>',
	"copy": '<rect x="8" y="8" width="13" height="13" rx="2"/><path d="M4 16V5a1 1 0 0 1 1-1h11"/>',
	"paste": '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V2h6v2"/><path d="M9 11h6"/><path d="M9 15h6"/>',
	"duplicate": '<rect x="3" y="3" width="12" height="12" rx="2"/><rect x="9" y="9" width="12" height="12" rx="2"/>',
	"shape_rect":'<rect x="4" y="6" width="16" height="12"/>',
	"shape_ellipse": '<ellipse cx="12" cy="12" rx="9" ry="6"/>',
	"shape_arc": '<path d="M4 18a8 8 0 0 1 16 0"/>',
	"shape_curve": '<path d="M4 18C8 4 16 20 20 6"/>',
	"shape_text": '<path d="M5 6V4h14v2"/><path d="M12 4v16"/><path d="M9 20h6"/>',
	"symbols": '<circle cx="7" cy="7" r="3.5"/><rect x="13.5" y="3.5" width="7" height="7"/><path d="M3.5 20.5 10.5 13.5"/><path d="M14 17h6"/><path d="M17 14v6"/>',
}


static func _static_init() -> void:
	use(Variant.DARK)


## Switches the colour tokens to [param new_variant].
static func use(new_variant: Variant) -> void:
	variant = new_variant
	_icons.clear()
	if variant == Variant.DARK:
		bg0 = Color("15171c")
		bg1 = Color("1c1f25")
		bg2 = Color("272b33")
		bg3 = Color("323743")
		border = Color("2a2e36")
		border_strong = Color("3b414d")
		text = Color("e8eaef")
		text_muted = Color("a0a8b6")
		text_faint = Color("6c7482")
		accent = Color("4c8dff")
		accent_hover = Color("6ea2ff")
		popup_bg = Color("23272e")
		tooltip_bg = Color("0e1013")
		chart_bg = Color("16181d")
		chart_grid = Color(1, 1, 1, 0.07)
	else:
		bg0 = Color("f1f3f6")
		bg1 = Color("ffffff")
		bg2 = Color("e9ecf1")
		bg3 = Color("dde1e8")
		border = Color("dfe3e9")
		border_strong = Color("c5cbd4")
		text = Color("1a1e25")
		text_muted = Color("596273")
		text_faint = Color("8b94a3")
		accent = Color("2f6fec")
		accent_hover = Color("4a82f0")
		popup_bg = Color("ffffff")
		tooltip_bg = Color("1a1e25")
		chart_bg = Color("fbfbfd")
		chart_grid = Color(0, 0, 0, 0.07)
	accent_soft = Color(accent, 0.18)
	on_accent = Color.WHITE
	# Darker on light surfaces, so warnings in text stay readable.
	danger = Color("e5484d") if variant == Variant.DARK else Color("cd2b31")
	warning = Color("e8962e") if variant == Variant.DARK else Color("ad5700")
	success = Color("30a46c") if variant == Variant.DARK else Color("18794e")
	tutorial = Color("a855f7") if variant == Variant.DARK else Color("7e22ce")
	tutorial_hover = Color("b77af9") if variant == Variant.DARK else Color("9333ea")
	tutorial_soft = Color(tutorial, 0.16)


static func ui_font() -> Font:
	if _ui_font == null:
		_ui_font = _system_font(UI_FONTS, 400)
	return _ui_font


static func bold_font() -> Font:
	if _ui_bold == null:
		_ui_bold = _system_font(UI_FONTS, 600)
	return _ui_bold


static func mono_font() -> Font:
	if _mono_font == null:
		_mono_font = _system_font(MONO_FONTS, 400)
	return _mono_font


## Font for text drawn on the schematic: a signed distance field font, so it
## stays sharp at every zoom level of the camera.
static func schematic_font() -> Font:
	if _schematic_font == null:
		_schematic_font = _system_font(UI_FONTS, 500)
		_schematic_font.multichannel_signed_distance_field = true
		_schematic_font.msdf_size = 64
		_schematic_font.msdf_pixel_range = 12
	return _schematic_font


static func _system_font(names: PackedStringArray, weight: int) -> SystemFont:
	var font: SystemFont = SystemFont.new()
	font.font_names = names
	font.font_weight = weight
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_LIGHT
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	font.allow_system_fallback = true
	return font


## Icon [param name] from [constant ICON_PATHS] at [param size] logical
## pixels. It is re-rasterized for the screen scale, so it never blurs.
static func icon(name: String, size: int = 18, color: Color = Color.WHITE) -> Texture2D:
	var key: String = "%s/%d/%s" % [name, size, color.to_html()]
	if _icons.has(key):
		return _icons[key]
	var hex: String = "#" + color.to_html(false)
	var body: String = ICON_PATHS[name].replace("#ffffff", hex)
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [size, size, hex, body]
	var texture: Texture2D = DPITexture.create_from_string(svg)
	_icons[key] = texture
	return texture


## Check box mark drawn in the accent colour (or an empty box).
static func _check_icon(checked: bool, radio: bool) -> Texture2D:
	var key: String = "check/%s/%s/%s" % [checked, radio, accent.to_html()]
	if _icons.has(key):
		return _icons[key]
	var a: String = "#" + accent.to_html(false)
	var b: String = "#" + border_strong.to_html(false)
	var f: String = "#" + bg0.to_html(false)
	var body: String
	if radio:
		body = '<circle cx="8" cy="8" r="6.5" fill="%s" stroke="%s" stroke-width="1.5"/>' % [f, a if checked else b]
		if checked:
			body += '<circle cx="8" cy="8" r="3.5" fill="%s"/>' % a
	elif checked:
		body = '<rect x="1" y="1" width="14" height="14" rx="3.5" fill="%s"/><path d="m4.5 8.2 2.3 2.3 4.7-4.9" fill="none" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>' % a
	else:
		body = '<rect x="1.75" y="1.75" width="12.5" height="12.5" rx="3" fill="%s" stroke="%s" stroke-width="1.5"/>' % [f, b]
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">%s</svg>' % body
	var texture: Texture2D = DPITexture.create_from_string(svg)
	_icons[key] = texture
	return texture


## Round slider grabber: white with a ring in [param ring].
static func _grabber_icon(ring: Color) -> Texture2D:
	var key: String = "grabber/%s" % ring.to_html()
	if _icons.has(key):
		return _icons[key]
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><circle cx="8" cy="8" r="6" fill="#ffffff" stroke="#%s" stroke-width="2.5"/></svg>' % ring.to_html(false)
	var texture: Texture2D = DPITexture.create_from_string(svg)
	_icons[key] = texture
	return texture


## Opens [param popup] (a menu or a panel) at the mouse, [param gap] logical
## pixels beside it, drawn at the interface size of the window it belongs
## to. A popup of a window of the system is placed in the window's pixels
## (the mouse is read in its scaled content); a menu under a zoomed drawing
## would also take its zoom.
static func popup_at_mouse(popup: Window, gap: Vector2 = Vector2.ZERO) -> void:
	var host: Window = popup.get_parent().get_window()
	if host.gui_embed_subwindows:
		# Drawn inside the window: placed in its scaled content and scaled
		# with it, kept inside it.
		var corner: Vector2i = Vector2i(host.get_mouse_position() + gap)
		popup.popup(Rect2i(corner, Vector2i.ZERO))
		# Opening gives a menu under a zoomed drawing the drawing's zoom.
		popup.content_scale_factor = 1.0
		popup.min_size = Vector2i.ZERO
		popup.reset_size()
		var room: Vector2i = Vector2i(host.get_visible_rect().size)
		popup.position = corner.clamp(Vector2i.ZERO, (room - popup.size).max(Vector2i.ZERO))
		return
	var factor: float = host.content_scale_factor
	var at: Vector2 = (host.get_mouse_position() + gap) * factor
	popup.content_scale_factor = factor
	popup.reset_size()
	popup.popup_on_parent(Rect2i(Vector2i(at), Vector2i.ZERO))
	if not is_equal_approx(popup.content_scale_factor, factor):
		# The menu took the scale of the canvas it is under: back to the
		# window's, sized and kept on the screen again.
		popup.content_scale_factor = factor
		popup.min_size = Vector2i.ZERO
		popup.reset_size()
		var screen: Rect2i = DisplayServer.screen_get_usable_rect(popup.current_screen)
		popup.position = (host.position + Vector2i(at)).clamp(screen.position, screen.end - popup.size)


## Flat rounded box.
static func box(bg: Color, radius: int = RADIUS, margin_h: float = 10.0, margin_v: float = 6.0, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	if border_width > 0:
		s.border_color = border_color
		s.set_border_width_all(border_width)
	s.anti_aliasing = true
	s.anti_aliasing_size = 0.75
	return s


## Frames [param button] like a text field beside it, so a small button
## next to one reads as a button (the theme's buttons are flat); in the
## current variant's colours.
static func frame(button: BaseButton) -> void:
	button.add_theme_stylebox_override("normal", box(bg1, RADIUS, 9.0, 4.0, border, 1))
	button.add_theme_stylebox_override("hover", box(bg2, RADIUS, 9.0, 4.0, border_strong, 1))
	button.add_theme_stylebox_override("pressed", box(accent_soft, RADIUS, 9.0, 4.0, accent, 1))
	button.add_theme_stylebox_override("hover_pressed", box(accent_soft, RADIUS, 9.0, 4.0, accent, 1))
	button.add_theme_stylebox_override("disabled", box(bg1, RADIUS, 9.0, 4.0, Color(border, 0.5), 1))


## Marks text field or drop-down field [param control] as a value still to
## give ([param missing]): a thicker edge on its left and a thin frame in
## the warning colour; unmarked, it looks as the theme draws it.
static func mark_missing(control: Control, missing: bool) -> void:
	var edit: bool = control is LineEdit
	if not missing:
		control.remove_theme_stylebox_override("normal")
		return
	var s: StyleBoxFlat = box(bg0 if edit else bg2, RADIUS, 9.0 if edit else 10.0, 5.0, Color(warning, 0.55), 1)
	s.border_width_left = 3
	control.add_theme_stylebox_override("normal", s)


## Whether [param control] is marked by [method mark_missing].
static func marked_missing(control: Control) -> bool:
	return control.has_theme_stylebox_override("normal")


static func _line(color: Color, vertical: bool) -> StyleBoxLine:
	var s: StyleBoxLine = StyleBoxLine.new()
	s.color = color
	s.thickness = 1
	s.vertical = vertical
	return s


## The Godot theme for the current variant.
static func build() -> Theme:
	var t: Theme = Theme.new()
	t.default_font = ui_font()
	t.default_font_size = FONT_SIZE
	var none: StyleBoxEmpty = StyleBoxEmpty.new()

	# Labels.
	t.set_color("font_color", "Label", text)
	for v: Array in [["MutedLabel", text_muted, SMALL_FONT_SIZE], ["CaptionLabel", text_muted, SMALL_FONT_SIZE], ["HeaderLabel", text_faint, 11]]:
		t.set_type_variation(v[0], "Label")
		t.set_color("font_color", v[0], v[1])
		t.set_font_size("font_size", v[0], v[2])
	t.set_font("font", "HeaderLabel", bold_font())
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", bold_font())
	t.set_font_size("font_size", "TitleLabel", 15)
	t.set_type_variation("BrandLabel", "Label")
	t.set_font("font", "BrandLabel", bold_font())
	t.set_font_size("font_size", "BrandLabel", 16)
	t.set_type_variation("TimeLabel", "Label")
	t.set_font("font", "TimeLabel", mono_font())
	t.set_font_size("font_size", "TimeLabel", 13)
	t.set_color("font_color", "TimeLabel", text)
	t.set_stylebox("normal", "TimeLabel", box(bg2, RADIUS, 10.0, 4.0))

	# Buttons: flat until hovered; toggled buttons in the accent colour.
	for type: String in ["Button", "MenuButton"]:
		t.set_stylebox("normal", type, box(Color.TRANSPARENT))
		t.set_stylebox("hover", type, box(bg2))
		t.set_stylebox("pressed", type, box(accent_soft))
		t.set_stylebox("hover_pressed", type, box(accent_soft))
		t.set_stylebox("disabled", type, box(Color.TRANSPARENT))
		t.set_stylebox("focus", type, none)
		t.set_color("font_color", type, text)
		t.set_color("font_hover_color", type, text)
		t.set_color("font_pressed_color", type, accent_hover if variant == Variant.DARK else accent)
		t.set_color("font_hover_pressed_color", type, accent_hover if variant == Variant.DARK else accent)
		t.set_color("font_focus_color", type, text)
		t.set_color("font_disabled_color", type, text_faint)
		t.set_color("icon_normal_color", type, text_muted)
		t.set_color("icon_hover_color", type, text)
		t.set_color("icon_pressed_color", type, accent_hover if variant == Variant.DARK else accent)
		t.set_color("icon_hover_pressed_color", type, accent_hover if variant == Variant.DARK else accent)
		t.set_color("icon_focus_color", type, text)
		t.set_color("icon_disabled_color", type, Color(text_faint, 0.6))
		t.set_constant("h_separation", type, 7)
	t.set_stylebox("pressed", "MenuButton", box(bg2))
	t.set_color("font_pressed_color", "MenuButton", text)
	# Square icon-only buttons in toolbars.
	t.set_type_variation("ToolButton", "Button")
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var s: StyleBoxFlat = (t.get_stylebox(state, "Button") as StyleBoxFlat).duplicate()
		s.content_margin_left = 7.0
		s.content_margin_right = 7.0
		t.set_stylebox(state, "ToolButton", s)
	# Main action (Run): filled accent.
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", box(accent, RADIUS, 12.0))
	t.set_stylebox("hover", "PrimaryButton", box(accent_hover, RADIUS, 12.0))
	t.set_stylebox("pressed", "PrimaryButton", box(accent.darkened(0.12), RADIUS, 12.0))
	t.set_stylebox("hover_pressed", "PrimaryButton", box(accent_hover, RADIUS, 12.0))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		t.set_color(c, "PrimaryButton", on_accent)
	# Segmented switch (Edit | Simulate): a sunken track with a raised thumb.
	t.set_type_variation("SegmentTrack", "PanelContainer")
	t.set_stylebox("panel", "SegmentTrack", box(bg0 if variant == Variant.LIGHT else Color("101216"), RADIUS + 2, 3.0, 3.0, border, 1))
	t.set_type_variation("SegmentButton", "Button")
	t.set_stylebox("normal", "SegmentButton", box(Color.TRANSPARENT, RADIUS, 12.0, 4.0))
	t.set_stylebox("hover", "SegmentButton", box(Color.TRANSPARENT, RADIUS, 12.0, 4.0))
	var thumb: StyleBoxFlat = box(bg3 if variant == Variant.DARK else Color.WHITE, RADIUS, 12.0, 4.0)
	thumb.shadow_color = Color(0, 0, 0, 0.18)
	thumb.shadow_size = 2
	thumb.shadow_offset = Vector2(0, 1)
	t.set_stylebox("pressed", "SegmentButton", thumb)
	t.set_stylebox("hover_pressed", "SegmentButton", thumb)
	t.set_color("font_color", "SegmentButton", text_muted)
	t.set_color("font_hover_color", "SegmentButton", text)
	t.set_color("font_pressed_color", "SegmentButton", text)
	t.set_color("font_hover_pressed_color", "SegmentButton", text)
	t.set_color("icon_normal_color", "SegmentButton", text_muted)
	t.set_color("icon_pressed_color", "SegmentButton", accent_hover if variant == Variant.DARK else accent)
	t.set_color("icon_hover_pressed_color", "SegmentButton", accent_hover if variant == Variant.DARK else accent)
	# Rows in lists (palette, check results).
	t.set_type_variation("ListButton", "Button")
	t.set_stylebox("normal", "ListButton", box(Color.TRANSPARENT, RADIUS, 6.0, 4.0))
	t.set_stylebox("hover", "ListButton", box(bg2, RADIUS, 6.0, 4.0))
	t.set_stylebox("pressed", "ListButton", box(accent_soft, RADIUS, 6.0, 4.0))
	t.set_stylebox("hover_pressed", "ListButton", box(accent_soft, RADIUS, 6.0, 4.0))
	t.set_stylebox("disabled", "ListButton", box(Color.TRANSPARENT, RADIUS, 6.0, 4.0))
	t.set_color("font_disabled_color", "ListButton", text_muted)

	# Drop-down fields.
	var field: StyleBoxFlat = box(bg2, RADIUS, 10.0, 5.0)
	t.set_stylebox("normal", "OptionButton", field)
	t.set_stylebox("hover", "OptionButton", box(bg3, RADIUS, 10.0, 5.0))
	t.set_stylebox("pressed", "OptionButton", box(bg3, RADIUS, 10.0, 5.0))
	t.set_stylebox("hover_pressed", "OptionButton", box(bg3, RADIUS, 10.0, 5.0))
	t.set_stylebox("disabled", "OptionButton", box(Color(bg2, 0.5), RADIUS, 10.0, 5.0))
	t.set_stylebox("focus", "OptionButton", none)
	t.set_icon("arrow", "OptionButton", icon("chevron_down", 14, text_muted))
	t.set_constant("arrow_margin", "OptionButton", 8)
	t.set_constant("h_separation", "OptionButton", 8)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "OptionButton", text)
	t.set_color("font_disabled_color", "OptionButton", text_faint)

	# Menus.
	var popup: StyleBoxFlat = box(popup_bg, RADIUS + 2, 6.0, 6.0, border_strong if variant == Variant.DARK else border, 1)
	popup.shadow_color = Color(0, 0, 0, 0.35 if variant == Variant.DARK else 0.14)
	popup.shadow_size = 10
	popup.shadow_offset = Vector2(0, 3)
	t.set_stylebox("panel", "PopupMenu", popup)
	var popup_panel: StyleBoxFlat = popup.duplicate()
	popup_panel.set_content_margin_all(14.0)
	t.set_stylebox("panel", "PopupPanel", popup_panel)
	t.set_stylebox("hover", "PopupMenu", box(accent_soft, RADIUS - 1, 8.0, 4.0))
	t.set_stylebox("separator", "PopupMenu", _line(border, false))
	t.set_color("font_color", "PopupMenu", text)
	t.set_color("font_hover_color", "PopupMenu", text)
	t.set_color("font_disabled_color", "PopupMenu", text_faint)
	t.set_color("font_accelerator_color", "PopupMenu", text_faint)
	t.set_color("font_separator_color", "PopupMenu", text_faint)
	t.set_constant("v_separation", "PopupMenu", 8)
	t.set_constant("h_separation", "PopupMenu", 10)
	t.set_constant("item_start_padding", "PopupMenu", 10)
	t.set_constant("item_end_padding", "PopupMenu", 12)
	t.set_icon("submenu", "PopupMenu", icon("chevron_right", 14, text_muted))
	t.set_icon("checked", "PopupMenu", _check_icon(true, false))
	t.set_icon("unchecked", "PopupMenu", _check_icon(false, false))
	t.set_icon("radio_checked", "PopupMenu", _check_icon(true, true))
	t.set_icon("radio_unchecked", "PopupMenu", _check_icon(false, true))

	# Text fields.
	var edit: StyleBoxFlat = box(bg0, RADIUS, 9.0, 5.0, border_strong if variant == Variant.LIGHT else border, 1)
	var edit_focus: StyleBoxFlat = box(bg0, RADIUS, 9.0, 5.0, accent, 1)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", edit_focus)
	t.set_stylebox("read_only", "LineEdit", box(bg1, RADIUS, 9.0, 5.0, border, 1))
	t.set_color("font_color", "LineEdit", text)
	t.set_color("font_placeholder_color", "LineEdit", text_faint)
	t.set_color("caret_color", "LineEdit", accent)
	t.set_color("selection_color", "LineEdit", Color(accent, 0.35))
	t.set_color("font_selected_color", "LineEdit", text)

	# Check boxes.
	for type: String in ["CheckBox", "CheckButton"]:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(state, type, box(Color.TRANSPARENT, RADIUS, 2.0, 4.0))
		t.set_stylebox("focus", type, none)
		t.set_color("font_color", type, text)
		t.set_color("font_hover_color", type, text)
		t.set_color("font_pressed_color", type, text)
		t.set_color("font_hover_pressed_color", type, text)
		t.set_constant("h_separation", type, 8)
	t.set_icon("checked", "CheckBox", _check_icon(true, false))
	t.set_icon("unchecked", "CheckBox", _check_icon(false, false))

	# Sliders: a thin track, filled in the accent colour up to a round grabber.
	t.set_stylebox("slider", "HSlider", box(bg3, 3, 0.0, 2.0))
	t.set_stylebox("grabber_area", "HSlider", box(accent, 3, 0.0, 2.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(accent_hover, 3, 0.0, 2.0))
	t.set_icon("grabber", "HSlider", _grabber_icon(accent))
	t.set_icon("grabber_highlight", "HSlider", _grabber_icon(accent_hover))
	t.set_icon("grabber_disabled", "HSlider", _grabber_icon(border_strong))
	# Spin boxes (their field is a LineEdit): arrows in the text colours.
	for arrow: String in ["up", "down"]:
		t.set_color(arrow + "_icon_modulate", "SpinBox", text_muted)
		t.set_color(arrow + "_hover_icon_modulate", "SpinBox", text)
		t.set_color(arrow + "_pressed_icon_modulate", "SpinBox", accent)
		t.set_color(arrow + "_disabled_icon_modulate", "SpinBox", text_faint)
		t.set_stylebox(arrow + "_background", "SpinBox", none)
		t.set_stylebox(arrow + "_background_hovered", "SpinBox", box(bg2, RADIUS - 2, 0.0, 0.0))
		t.set_stylebox(arrow + "_background_pressed", "SpinBox", box(accent_soft, RADIUS - 2, 0.0, 0.0))
		t.set_stylebox(arrow + "_background_disabled", "SpinBox", none)
	t.set_stylebox("field_and_buttons_separator", "SpinBox", none)
	t.set_stylebox("up_down_buttons_separator", "SpinBox", none)

	# Panels.
	t.set_stylebox("panel", "PanelContainer", box(bg1, 0, 0.0, 0.0))
	t.set_stylebox("panel", "Panel", box(bg1, 0, 0.0, 0.0))
	var toolbar: StyleBoxFlat = box(bg0, 0, 10.0, 6.0)
	toolbar.border_color = border
	toolbar.border_width_bottom = 1
	t.set_type_variation("Toolbar", "PanelContainer")
	t.set_stylebox("panel", "Toolbar", toolbar)
	var status: StyleBoxFlat = box(bg0, 0, 12.0, 4.0)
	status.border_color = border
	status.border_width_top = 1
	t.set_type_variation("Statusbar", "PanelContainer")
	t.set_stylebox("panel", "Statusbar", status)
	# Page tabs above the schematic.
	var page_bar: StyleBoxFlat = box(bg0, 0, 8.0, 0.0)
	page_bar.content_margin_top = 4.0
	page_bar.border_color = border
	page_bar.border_width_bottom = 1
	t.set_type_variation("PageBar", "PanelContainer")
	t.set_stylebox("panel", "PageBar", page_bar)
	# The shown page: lifted onto the panel colour, with an accent line on top.
	var tab_selected: StyleBoxFlat = box(bg1, RADIUS, 12.0, 5.0)
	tab_selected.corner_radius_bottom_left = 0
	tab_selected.corner_radius_bottom_right = 0
	tab_selected.border_color = accent
	tab_selected.border_width_top = 2
	t.set_stylebox("tab_selected", "TabBar", tab_selected)
	t.set_stylebox("tab_unselected", "TabBar", box(Color.TRANSPARENT, RADIUS, 12.0, 5.0))
	t.set_stylebox("tab_hovered", "TabBar", box(bg2, RADIUS, 12.0, 5.0))
	t.set_stylebox("tab_disabled", "TabBar", box(Color.TRANSPARENT, RADIUS, 12.0, 5.0))
	t.set_stylebox("tab_focus", "TabBar", none)
	t.set_stylebox("button_pressed", "TabBar", box(bg2))
	t.set_stylebox("button_highlight", "TabBar", box(bg2))
	t.set_color("font_selected_color", "TabBar", text)
	t.set_color("font_unselected_color", "TabBar", text_muted)
	t.set_color("font_hovered_color", "TabBar", text)
	t.set_color("font_disabled_color", "TabBar", text_faint)
	t.set_color("drop_mark_color", "TabBar", accent)
	t.set_constant("h_separation", "TabBar", 6)
	t.set_icon("increment", "TabBar", icon("chevron_right", 14, text_muted))
	t.set_icon("decrement", "TabBar", icon("arrow_left", 14, text_muted))
	var bottom: StyleBoxFlat = box(bg1, 0, 12.0, 8.0)
	bottom.border_color = border
	bottom.border_width_top = 1
	t.set_type_variation("BottomPanel", "PanelContainer")
	t.set_stylebox("panel", "BottomPanel", bottom)
	var left: StyleBoxFlat = box(bg1, 0, 8.0, 10.0)
	left.border_color = border
	left.border_width_right = 1
	t.set_type_variation("LeftPanel", "PanelContainer")
	t.set_stylebox("panel", "LeftPanel", left)
	var right: StyleBoxFlat = box(bg1, 0, 14.0, 12.0)
	right.border_color = border
	right.border_width_left = 1
	t.set_type_variation("RightPanel", "PanelContainer")
	t.set_stylebox("panel", "RightPanel", right)
	var section: StyleBoxFlat = right.duplicate()
	section.border_width_top = 1
	t.set_type_variation("RightSection", "PanelContainer")
	t.set_stylebox("panel", "RightSection", section)
	# Lessons: the step shown, its tip, the lesson's main action (Check)
	# and the tour's card.
	t.set_type_variation("LessonStep", "PanelContainer")
	t.set_stylebox("panel", "LessonStep", box(bg2, RADIUS + 2, 0.0, 0.0, border_strong, 1))
	t.set_type_variation("HintBox", "PanelContainer")
	t.set_stylebox("panel", "HintBox", box(tutorial_soft, RADIUS, 10.0, 7.0))
	t.set_type_variation("TutorialButton", "Button")
	t.set_stylebox("normal", "TutorialButton", box(tutorial.darkened(0.08) if variant == Variant.DARK else tutorial, RADIUS, 12.0))
	t.set_stylebox("hover", "TutorialButton", box(tutorial_hover, RADIUS, 12.0))
	t.set_stylebox("pressed", "TutorialButton", box(tutorial.darkened(0.2), RADIUS, 12.0))
	t.set_stylebox("hover_pressed", "TutorialButton", box(tutorial_hover, RADIUS, 12.0))
	t.set_stylebox("disabled", "TutorialButton", box(bg2, RADIUS, 12.0))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		t.set_color(c, "TutorialButton", on_accent)
	var tour_card: StyleBoxFlat = box(popup_bg, RADIUS + 6, 18.0, 14.0, border_strong if variant == Variant.DARK else border, 1)
	tour_card.shadow_color = Color(0, 0, 0, 0.35)
	tour_card.shadow_size = 18
	tour_card.shadow_offset = Vector2(0, 6)
	t.set_type_variation("TourCard", "PanelContainer")
	t.set_stylebox("panel", "TourCard", tour_card)
	t.set_type_variation("TutorialLabel", "Label")
	t.set_color("font_color", "TutorialLabel", tutorial_hover if variant == Variant.DARK else tutorial)
	t.set_font("font", "TutorialLabel", bold_font())
	t.set_font_size("font_size", "TutorialLabel", SMALL_FONT_SIZE)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", box(chart_bg, RADIUS + 2, 1.0, 1.0, border, 1))
	t.set_type_variation("FunctionCard", "PanelContainer")
	t.set_stylebox("panel", "FunctionCard", box(bg2, RADIUS + 2, 10.0, 8.0, border, 1))
	t.set_type_variation("FunctionCardActive", "PanelContainer")
	t.set_stylebox("panel", "FunctionCardActive", box(bg2, RADIUS + 2, 10.0, 8.0, accent, 2))
	t.set_stylebox("panel", "ScrollContainer", none)

	# Separators.
	t.set_stylebox("separator", "VSeparator", _line(border_strong if variant == Variant.LIGHT else border, true))
	t.set_stylebox("separator", "HSeparator", _line(border, false))
	t.set_constant("separation", "VSeparator", 14)
	t.set_constant("separation", "HSeparator", 12)
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("h_separation", "HFlowContainer", 6)
	t.set_constant("v_separation", "HFlowContainer", 4)

	# Lists.
	t.set_stylebox("panel", "ItemList", box(bg0, RADIUS + 2, 6.0, 6.0, border, 1))
	t.set_stylebox("focus", "ItemList", none)
	t.set_stylebox("hovered", "ItemList", box(bg2, RADIUS - 2, 6.0, 2.0))
	t.set_stylebox("selected", "ItemList", box(accent_soft, RADIUS - 2, 6.0, 2.0))
	t.set_stylebox("selected_focus", "ItemList", box(accent_soft, RADIUS - 2, 6.0, 2.0))
	t.set_stylebox("cursor", "ItemList", none)
	t.set_stylebox("cursor_unfocused", "ItemList", none)
	t.set_color("font_color", "ItemList", text)
	t.set_color("font_hovered_color", "ItemList", text)
	t.set_color("font_selected_color", "ItemList", text)
	t.set_color("guide_color", "ItemList", Color.TRANSPARENT)
	t.set_font("font", "ItemList", mono_font())
	t.set_font_size("font_size", "ItemList", SMALL_FONT_SIZE)
	t.set_constant("v_separation", "ItemList", 5)

	# Thin scroll bars.
	for type: String in ["VScrollBar", "HScrollBar"]:
		var track: StyleBoxFlat = box(Color.TRANSPARENT, 4, 3.0, 3.0)
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, track)
		t.set_stylebox("grabber", type, box(Color(text_muted, 0.35), 4, 3.0, 3.0))
		t.set_stylebox("grabber_highlight", type, box(Color(text_muted, 0.55), 4, 3.0, 3.0))
		t.set_stylebox("grabber_pressed", type, box(Color(text_muted, 0.7), 4, 3.0, 3.0))
		for i: String in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
			t.set_icon(i, type, PlaceholderTexture2D.new())
			(t.get_icon(i, type) as PlaceholderTexture2D).size = Vector2.ZERO

	# Tooltips.
	t.set_stylebox("panel", "TooltipPanel", box(tooltip_bg, RADIUS, 9.0, 5.0))
	t.set_color("font_color", "TooltipLabel", Color("f2f4f7"))
	t.set_font_size("font_size", "TooltipLabel", SMALL_FONT_SIZE)

	# Dialogs.
	var window: StyleBoxFlat = box(popup_bg, RADIUS + 4, 0.0, 0.0, border_strong if variant == Variant.DARK else border, 1)
	window.expand_margin_top = 30.0
	window.shadow_color = Color(0, 0, 0, 0.4)
	window.shadow_size = 16
	t.set_stylebox("embedded_border", "Window", window)
	t.set_stylebox("embedded_unfocused_border", "Window", window)
	t.set_constant("title_height", "Window", int(window.expand_margin_top))
	t.set_color("title_color", "Window", text)
	t.set_font("title_font", "Window", bold_font())
	t.set_stylebox("panel", "AcceptDialog", box(popup_bg, RADIUS + 4, 14.0, 12.0))
	t.set_icon("close", "Window", icon("close", 16, text_muted))
	t.set_icon("close_pressed", "Window", icon("close", 16, text))
	return t
