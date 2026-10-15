class_name Palette
extends PanelContainer
## Component palette for the editor. Each entry shows the symbol and emits a
## component template (see [DocumentSerializer]) when chosen.

signal template_chosen(template: Dictionary)

## Entries: English title (translated with tr()) and component template.
const ENTRIES: Array[Dictionary] = [
	{"title": "L1 supply", "template": {"type": "supply", "conductor": "L"}},
	{"title": "L2 supply", "template": {"type": "supply", "conductor": "L2"}},
	{"title": "L3 supply", "template": {"type": "supply", "conductor": "L3"}},
	{"title": "N supply", "template": {"type": "supply", "conductor": "N"}},
	{"title": "+ supply (DC)", "template": {"type": "supply", "conductor": "+"}},
	{"title": "- supply (DC)", "template": {"type": "supply", "conductor": "-"}},
	{"title": "Terminal (strip terminal X)", "template": {"type": "terminal"}},
	{"title": "Push button NO", "template": {"type": "push_button", "contact": "NO"}},
	{"title": "Push button NC", "template": {"type": "push_button", "contact": "NC"}},
	{"title": "Switch NO", "template": {"type": "latching_switch", "contact": "NO"}},
	{"title": "Switch NC", "template": {"type": "latching_switch", "contact": "NC"}},
	{"title": "Limit switch NO", "template": {"type": "limit_switch", "contact": "NO"}},
	{"title": "Limit switch NC", "template": {"type": "limit_switch", "contact": "NC"}},
	{"title": "Contact NO", "template": {"type": "contact", "contact": "NO"}},
	{"title": "Contact NC", "template": {"type": "contact", "contact": "NC"}},
	{"title": "Changeover contact", "template": {"type": "changeover"}},
	{"title": "Coil (contactor KM / relay KA)", "template": {"type": "coil"}},
	{"title": "Time relay (multifunction)", "template": {"type": "timer", "mode": "on_delay", "delay": 3.0}},
	{"title": "Lamp", "template": {"type": "lamp"}},
	{"title": "Motor", "template": {"type": "motor"}},
	{"title": "Fuse", "template": {"type": "fuse"}},
	{"title": "Fuse holder", "template": {"type": "fuse", "holder": true}},
	{"title": "Circuit breaker", "template": {"type": "breaker"}},
	{"title": "Overload relay", "template": {"type": "overload_relay", "trip_delay": 5.0}},
	{"title": "Main contacts", "template": {"type": "main_contacts"}},
	{"title": "Motor 3~", "template": {"type": "motor3", "motor_kind": "standard"}},
	{"title": "Motor 3~ star/delta", "template": {"type": "motor3", "motor_kind": "star_delta"}},
	{"title": "Motor 3~ Dahlander", "template": {"type": "motor3", "motor_kind": "dahlander"}},
	{"title": "Motor 3~ two windings", "template": {"type": "motor3", "motor_kind": "two_windings"}},
	{"title": "Motor 3~ three windings", "template": {"type": "motor3", "motor_kind": "three_windings"}},
]

## Largest scale of a symbol on its tile; smaller when it would not fit.
const MAX_ICON_SCALE: float = 0.7
const ICON_PADDING: float = 3.0
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
		"supply", "terminal":
			return "supplies"
		"push_button", "latching_switch", "limit_switch":
			return "buttons"
		"contact", "changeover":
			return "contacts"
		"coil", "timer":
			return "coils"
		"lamp", "motor":
			return "loads"
		"fuse", "breaker", "overload_relay", "overload_contact":
			return "protection"
	return "power"


func _group_title(group: String) -> String:
	match group:
		"supplies":
			return tr("Supplies and terminals")
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
		button.custom_minimum_size = Vector2(0, TILE.size.y + 2.0 * TILE.position.y)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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


## Draws the symbol on a paper tile at the left of the button, scaled to fit
## it: two-terminal symbols and supplies lying horizontally, three-pole
## devices and motors upright. Supplies show their conductor name in the circle.
func _add_icon(button: Button, template: Dictionary) -> void:
	var data: Dictionary = template.duplicate()
	var conductor: String = str(data.get("conductor", ""))
	data["designation"] = ("L1" if conductor == "L" else conductor) if not conductor.is_empty() else "X1"
	var component: CircuitComponent = DocumentSerializer.component_from_dict(data)
	var supply: bool = component is PowerSupply
	var upright: bool = component is ThreePhaseMotor or component.get_terminal_names().size() > 3
	var placement: Placement = Placement.new(Vector2i.ZERO, 0, false) if upright else Placement.new(Vector2i.ZERO, 3, true)
	var symbol: SchematicSymbol = SymbolFactory.create(component, placement)
	symbol.show_labels = supply
	# Symbols are drawn for the light schematic paper, so give them a tile of it.
	var paper: Panel = Panel.new()
	_tiles.append(paper)
	_symbols.append(symbol)
	_style_tile(paper)
	paper.position = TILE.position
	paper.size = TILE.size
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.clip_contents = true
	button.add_child(paper)
	# Extent of the drawing: body and terminals, turned like the placement.
	var g: float = float(SymbolGeometry.GRID)
	var local: Rect2 = SymbolGeometry.local_body(component)
	for cell: Vector2i in SymbolGeometry.local_terminals(component).values():
		local = local.expand(Vector2(cell))
	local = Rect2(local.position * g, local.size * g).grow(2.0 if supply else 6.0)
	var t: Transform2D = SymbolGeometry.draw_transform(placement)
	var extent: Rect2 = Rect2(t * local.position, Vector2.ZERO)
	for corner: Vector2 in [local.end, Vector2(local.position.x, local.end.y), Vector2(local.end.x, local.position.y)]:
		extent = extent.expand(t * corner)
	var room: Vector2 = TILE.size - Vector2.ONE * 2.0 * ICON_PADDING
	# Supplies at full size, so the conductor name in the circle stays readable.
	var s: float = minf(1.0 if supply else MAX_ICON_SCALE, minf(room.x / extent.size.x, room.y / extent.size.y))
	symbol.scale = Vector2(s, s)
	symbol.position = TILE.size * 0.5 - extent.get_center() * s
	paper.add_child(symbol)
