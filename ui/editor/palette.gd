class_name Palette
extends PanelContainer
## Component palette for the editor. Each entry shows the symbol and emits a
## component template (see [DocumentSerializer]) when chosen.

signal template_chosen(template: Dictionary)

## Entries: English title (translated with tr()) and component template.
const ENTRIES: Array[Dictionary] = [
	{"title": "L supply", "template": {"type": "supply", "conductor": "L"}},
	{"title": "N supply", "template": {"type": "supply", "conductor": "N"}},
	{"title": "L2 supply", "template": {"type": "supply", "conductor": "L2"}},
	{"title": "L3 supply", "template": {"type": "supply", "conductor": "L3"}},
	{"title": "Push button NO", "template": {"type": "push_button", "contact": "NO"}},
	{"title": "Push button NC", "template": {"type": "push_button", "contact": "NC"}},
	{"title": "Switch NO", "template": {"type": "latching_switch", "contact": "NO"}},
	{"title": "Switch NC", "template": {"type": "latching_switch", "contact": "NC"}},
	{"title": "Contact NO", "template": {"type": "contact", "contact": "NO"}},
	{"title": "Contact NC", "template": {"type": "contact", "contact": "NC"}},
	{"title": "Delayed contact NO", "template": {"type": "contact", "contact": "NO", "delayed": true}},
	{"title": "Delayed contact NC", "template": {"type": "contact", "contact": "NC", "delayed": true}},
	{"title": "Changeover contact", "template": {"type": "changeover"}},
	{"title": "Delayed changeover contact", "template": {"type": "changeover", "delayed": true}},
	{"title": "Contactor coil", "template": {"type": "coil", "kind": "contactor"}},
	{"title": "Relay coil", "template": {"type": "coil", "kind": "relay"}},
	{"title": "On-delay timer", "template": {"type": "timer", "mode": "on_delay", "delay": 3.0}},
	{"title": "Off-delay timer", "template": {"type": "timer", "mode": "off_delay", "delay": 3.0}},
	{"title": "Lamp", "template": {"type": "lamp"}},
	{"title": "Motor", "template": {"type": "motor"}},
	{"title": "Fuse", "template": {"type": "fuse"}},
	{"title": "Circuit breaker", "template": {"type": "breaker"}},
	{"title": "Overload relay", "template": {"type": "overload_relay", "trip_delay": 5.0}},
	{"title": "Overload contact NC", "template": {"type": "overload_contact", "contact": "NC"}},
	{"title": "Overload contact NO", "template": {"type": "overload_contact", "contact": "NO"}},
	{"title": "Main contacts", "template": {"type": "main_contacts"}},
	{"title": "Fuse 3-pole", "template": {"type": "fuse3"}},
	{"title": "Motor breaker 3-pole", "template": {"type": "breaker3"}},
	{"title": "Overload relay 3-pole", "template": {"type": "overload_relay", "trip_delay": 5.0, "poles": 3}},
	{"title": "Motor 3~", "template": {"type": "motor3", "motor_kind": "standard"}},
	{"title": "Motor 3~ star/delta", "template": {"type": "motor3", "motor_kind": "star_delta"}},
	{"title": "Motor 3~ Dahlander", "template": {"type": "motor3", "motor_kind": "dahlander"}},
	{"title": "Motor 3~ two windings", "template": {"type": "motor3", "motor_kind": "two_windings"}},
	{"title": "Motor 3~ three windings", "template": {"type": "motor3", "motor_kind": "three_windings"}},
]

const ICON_SCALE: float = 0.7
## Three-pole symbols and motors are drawn upright and smaller.
const LARGE_ICON_SCALE: float = 0.38
## Paper tile behind each symbol, at the left of its row.
const TILE := Rect2(6, 4, 54, 34)

var _buttons: Array[Button] = []
var _tiles: Array[Panel] = []
var _symbols: Array[SchematicSymbol] = []
var _headers: Array[Label] = []
var _header_titles: PackedStringArray = []


## Palette section of a template.
static func group_of(template: Dictionary) -> String:
	match template["type"]:
		"supply":
			return "supplies"
		"push_button", "latching_switch":
			return "buttons"
		"contact", "changeover":
			return "contacts"
		"coil", "timer":
			return "coils"
		"lamp", "motor":
			return "loads"
		"fuse", "breaker", "overload_contact":
			return "protection"
		"overload_relay":
			return "power" if int(template.get("poles", 0)) == 3 else "protection"
	return "power"


func _group_title(group: String) -> String:
	match group:
		"supplies":
			return tr("Supplies")
		"buttons":
			return tr("Buttons and switches")
		"contacts":
			return tr("Contacts")
		"coils":
			return tr("Coils")
		"loads":
			return tr("Loads")
		"protection":
			return tr("Protection")
	return tr("Power circuit")


func _ready() -> void:
	theme_type_variation = "LeftPanel"
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 1)
	scroll.add_child(list)
	var group: String = ""
	for entry: Dictionary in ENTRIES:
		var template: Dictionary = entry["template"]
		if group_of(template) != group:
			group = group_of(template)
			var header: Label = Label.new()
			header.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			header.theme_type_variation = "HeaderLabel"
			header.custom_minimum_size = Vector2(0, 30 if _headers.is_empty() else 38)
			header.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			list.add_child(header)
			_headers.append(header)
			_header_titles.append(group)
		var button: Button = Button.new()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.theme_type_variation = "ListButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(236, TILE.size.y + 2.0 * TILE.position.y)
		button.focus_mode = Control.FOCUS_NONE
		# An empty icon keeps the room for the symbol tile.
		var room: PlaceholderTexture2D = PlaceholderTexture2D.new()
		room.size = TILE.size
		button.icon = room
		button.add_theme_constant_override("h_separation", 10)
		button.add_theme_color_override("icon_normal_color", Color.TRANSPARENT)
		button.add_theme_color_override("icon_hover_color", Color.TRANSPARENT)
		button.add_theme_color_override("icon_pressed_color", Color.TRANSPARENT)
		button.add_theme_color_override("icon_hover_pressed_color", Color.TRANSPARENT)
		button.pressed.connect(func() -> void: template_chosen.emit(template.duplicate()))
		_add_icon(button, template)
		list.add_child(button)
		_buttons.append(button)
	retranslate()


## Repaints the symbol tiles after the schematic paper changed (dark / white).
func refresh_paper() -> void:
	for tile: Panel in _tiles:
		_style_tile(tile)
	for symbol: SchematicSymbol in _symbols:
		symbol.queue_redraw()


func _style_tile(tile: Panel) -> void:
	var edge: Color = Color(1, 1, 1, 0.1) if SchematicTheme.dark else Color(0, 0, 0, 0.08)
	tile.add_theme_stylebox_override("panel", AppTheme.box(SchematicTheme.BACKGROUND, 5, 0.0, 0.0, edge, 1))


func retranslate() -> void:
	for i: int in _buttons.size():
		_buttons[i].text = tr(ENTRIES[i]["title"])
	for i: int in _headers.size():
		_headers[i].text = _group_title(_header_titles[i]).to_upper()


## Draws the symbol lying horizontally on a paper tile at the left of the button.
func _add_icon(button: Button, template: Dictionary) -> void:
	var data: Dictionary = template.duplicate()
	data["designation"] = str(data["conductor"]) if data.has("conductor") else "X1"
	var component: CircuitComponent = DocumentSerializer.component_from_dict(data)
	var large: bool = component.get_terminal_names().size() > 3 or component is ThreePhaseMotor
	var placement: Placement = Placement.new(Vector2i.ZERO, 0, false) if large else Placement.new(Vector2i.ZERO, 3, true)
	var symbol: SchematicSymbol = SymbolFactory.create(component, placement)
	symbol.show_labels = false
	symbol.scale = Vector2.ONE * (LARGE_ICON_SCALE if large else ICON_SCALE)
	# Symbols are drawn for the light schematic paper, so give them a tile of it.
	var paper: Panel = Panel.new()
	_tiles.append(paper)
	_symbols.append(symbol)
	_style_tile(paper)
	paper.position = TILE.position
	paper.size = TILE.size
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(paper)
	var span: float = SymbolGeometry.SPAN * SymbolGeometry.GRID * ICON_SCALE
	var at: Vector2 = Vector2(6.0 + (span * 0.5 if component is PowerSupply else 0.0), 18.0)
	if large:
		at = Vector2(10.0, 5.0) if not (component is ThreePhaseMotor) else Vector2(7.0, 1.0)
	symbol.position = TILE.position + at
	button.add_child(symbol)
