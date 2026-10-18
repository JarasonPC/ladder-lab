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
	"arrow_left": '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>',
	"arrow_right": '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>',
	"arrow_up": '<path d="m5 12 7-7 7 7"/><path d="M12 19V5"/>',
	"arrow_down": '<path d="M12 5v14"/><path d="m19 12-7 7-7-7"/>',
	"download": '<path d="M12 15V3"/><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5"/>',
	"datasheet": '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/>',
	"window": '<rect x="2" y="4" width="20" height="16" rx="2"/><path d="M2 9h20"/><path d="M6 6.5h.01"/><path d="M9 6.5h.01"/>',
	"cabinet": '<rect x="3" y="2" width="18" height="20" rx="2"/><path d="M3 9h18"/><path d="M3 16h18"/><path d="M7 4.5v3"/><path d="M10 4.5v3"/><path d="M13 4.5v3"/><path d="M7 11.5v3"/><path d="M12 11.5v3"/>',
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
	danger = Color("e5484d")
	warning = Color("e8962e")
	success = Color("30a46c")


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
	t.set_stylebox("panel", "PopupPanel", popup)

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
	t.set_color("title_color", "Window", text)
	t.set_font("title_font", "Window", bold_font())
	t.set_stylebox("panel", "AcceptDialog", box(popup_bg, RADIUS + 4, 14.0, 12.0))
	t.set_icon("close", "Window", icon("close", 16, text_muted))
	t.set_icon("close_pressed", "Window", icon("close", 16, text))
	return t
