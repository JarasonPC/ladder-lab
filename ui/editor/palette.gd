class_name Palette
extends PanelContainer
## Component palette for the editor. Each entry shows the symbol and emits a
## component template (see [DocumentSerializer]) when chosen. Shown as a list
## (symbol and name, in titled groups) or as a grid of symbols alone (the
## name in the tooltip), switched by the buttons at its top ([member grid]).

signal template_chosen(template: Dictionary)
## The list or the grid was chosen (to remember it).
signal grid_toggled(grid: bool)

## Entries: English title (translated with tr()) and component template.
const ENTRIES: Array[Dictionary] = [
	{"title": "L1 supply", "template": {"type": "supply", "conductor": "L"}},
	{"title": "L2 supply", "template": {"type": "supply", "conductor": "L2"}},
	{"title": "L3 supply", "template": {"type": "supply", "conductor": "L3"}},
	{"title": "N supply", "template": {"type": "supply", "conductor": "N"}},
	{"title": "PE supply", "template": {"type": "supply", "conductor": "PE"}},
	{"title": "+ supply (DC)", "template": {"type": "supply", "conductor": "+"}},
	{"title": "- supply (DC)", "template": {"type": "supply", "conductor": "-"}},
	{"title": "Bridge rectifier", "template": {"type": "rectifier"}},
	{"title": "Terminal (strip terminal X)", "template": {"type": "terminal"}},
	{"title": "Page connector", "template": {"type": "connector"}},
	{"title": "Push button NO", "template": {"type": "push_button", "contact": "NO"}},
	{"title": "Push button NC", "template": {"type": "push_button", "contact": "NC"}},
	{"title": "Switch NO", "template": {"type": "latching_switch", "contact": "NO"}},
	{"title": "Switch NC", "template": {"type": "latching_switch", "contact": "NC"}},
	{"title": "Rotary cam switch (0-I or I-0-II)", "template": {"type": "cam_switch", "poles": 3, "positions": "0-I"}},
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
	{"title": "Overload relay", "template": {"type": "overload_relay", "trip_delay": 5.0, "poles": 3}},
	{"title": "Main contacts", "template": {"type": "main_contacts"}},
	{"title": "Motor 3~", "template": {"type": "motor3", "motor_kind": "standard"}},
	{"title": "Motor 3~ star/delta", "template": {"type": "motor3", "motor_kind": "star_delta"}},
	{"title": "Motor 3~ Dahlander", "template": {"type": "motor3", "motor_kind": "dahlander"}},
	{"title": "Motor 3~ two windings", "template": {"type": "motor3", "motor_kind": "two_windings"}},
	{"title": "Motor 3~ three windings", "template": {"type": "motor3", "motor_kind": "three_windings"}},
	{"title": "Frequency inverter (VFD) 3~ 400 V", "template": {"type": "vfd"}},
	{"title": "PLC (logic module, 8 inputs, 4 relay outputs)", "template": {"type": "plc"}},
	{"title": "Compact PLC (CPU 24 V DC, transistor outputs)", "template": {"type": "plc", "family": "compact", "cpu": "8di6dq"}},
	{"title": "Temperature sensor (0-10 V)", "template": {"type": "temp_sensor"}},
	{"title": "Transmitter: pressure, level, flow (0-10 V)", "template": {"type": "transmitter", "quantity": "pressure"}},
	{"title": "Proximity sensor (PNP / NPN)", "template": {"type": "proximity", "sensing": "inductive", "output": "pnp", "function": "no"}},
	{"title": "Network switch (Ethernet, 4 ports)", "template": {"type": "network_switch"}},
]

## Largest scale of a symbol on its tile; smaller when it would not fit.
const MAX_ICON_SCALE: float = 0.7
const ICON_PADDING: float = 3.0
## Paper tile behind each symbol, at the left of its row.
const TILE := Rect2(6, 4, 54, 34)

## Symbols alone in a grid instead of the list with names.
var grid: bool = false:
	set(value):
		if value == grid:
			return
		grid = value
		if _list != null:
			_build()

var _list: VBoxContainer
var _list_button: Button
var _grid_button: Button
var _buttons: Array[Button] = []
var _tiles: Array[Panel] = []
var _symbols: Array[SchematicSymbol] = []
var _headers: Array[Label] = []
var _header_titles: PackedStringArray = []


## Palette section of a template.
static func group_of(template: Dictionary) -> String:
	match template["type"]:
		"supply", "terminal", "rectifier", "connector":
			return "supplies"
		"push_button", "latching_switch", "limit_switch", "cam_switch":
			return "buttons"
		"contact", "changeover":
			return "contacts"
		"coil", "timer":
			return "coils"
		"lamp", "motor":
			return "loads"
		"fuse", "breaker", "overload_relay", "overload_contact":
			return "protection"
		"plc", "temp_sensor", "transmitter", "proximity", "network_switch":
			return "plc"
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
		"plc":
			return tr("PLC and sensors")
	return tr("Power circuit")


func _ready() -> void:
	theme_type_variation = "LeftPanel"
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	add_child(outer)
	var switch: HBoxContainer = HBoxContainer.new()
	switch.alignment = BoxContainer.ALIGNMENT_END
	switch.add_theme_constant_override("separation", 2)
	outer.add_child(switch)
	var group: ButtonGroup = ButtonGroup.new()
	for as_grid: bool in [false, true]:
		var button: Button = Button.new()
		button.theme_type_variation = "ToolButton"
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.button_group = group
		button.icon = AppTheme.icon("grid" if as_grid else "list")
		button.button_pressed = as_grid == grid
		button.pressed.connect(func() -> void:
			grid = as_grid
			grid_toggled.emit(as_grid))
		switch.add_child(button)
		if as_grid:
			_grid_button = button
		else:
			_list_button = button
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 1)
	scroll.add_child(_list)
	_build()


## Fills the palette as a list or a grid.
func _build() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_tiles.clear()
	_symbols.clear()
	_headers.clear()
	_header_titles.clear()
	if _grid_button != null:
		_grid_button.set_pressed_no_signal(grid)
		_list_button.set_pressed_no_signal(not grid)
	var group: String = ""
	var row: Container = _list
	for entry: Dictionary in ENTRIES:
		var template: Dictionary = entry["template"]
		if group_of(template) != group:
			group = group_of(template)
			if grid:
				# Groups apart, without titles.
				if not _buttons.is_empty():
					_list.add_child(HSeparator.new())
				var flow: HFlowContainer = HFlowContainer.new()
				flow.add_theme_constant_override("h_separation", 1)
				flow.add_theme_constant_override("v_separation", 1)
				_list.add_child(flow)
				row = flow
			else:
				var header: Label = Label.new()
				header.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
				header.theme_type_variation = "HeaderLabel"
				header.custom_minimum_size = Vector2(0, 30 if _headers.is_empty() else 38)
				header.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
				_list.add_child(header)
				_headers.append(header)
				_header_titles.append(group)
		var button: Button = Button.new()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.theme_type_variation = "ListButton"
		button.focus_mode = Control.FOCUS_NONE
		if grid:
			button.custom_minimum_size = TILE.size + 2.0 * TILE.position
		else:
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(0, TILE.size.y + 2.0 * TILE.position.y)
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
		row.add_child(button)
		_buttons.append(button)
	retranslate()


## The button of the first entry whose template has every key of
## [param template] with the same value, or null.
func entry_button(template: Dictionary) -> Button:
	for i: int in mini(ENTRIES.size(), _buttons.size()):
		var entry: Dictionary = ENTRIES[i]["template"]
		var same: bool = true
		for key: Variant in template:
			if not entry.has(key) or entry[key] != template[key]:
				same = false
				break
		if same:
			return _buttons[i]
	return null


## Global rectangle of the entry of [param template] as far as the list
## shows it; empty when it is scrolled away or the palette is hidden.
func entry_rect(template: Dictionary) -> Rect2:
	var button: Button = entry_button(template)
	if button == null or not button.is_visible_in_tree():
		return Rect2()
	var shown: Rect2 = (_list.get_parent() as Control).get_global_rect()
	var r: Rect2 = button.get_global_rect()
	return r if shown.encloses(r) else Rect2()


## Scrolls the list so the entry of [param template] is in view.
func reveal(template: Dictionary) -> void:
	var button: Button = entry_button(template)
	if button != null and button.is_inside_tree():
		(_list.get_parent() as ScrollContainer).ensure_control_visible(button)


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
	if _list_button != null:
		_list_button.tooltip_text = tr("Show the parts as a list with their names")
		_grid_button.tooltip_text = tr("Show the parts as a grid of symbols")
	for i: int in _buttons.size():
		_buttons[i].text = "" if grid else tr(ENTRIES[i]["title"])
		_buttons[i].tooltip_text = tr(ENTRIES[i]["title"]) if grid else ""
	for i: int in _headers.size():
		_headers[i].text = _group_title(_header_titles[i]).to_upper()


## Draws the symbol on a paper tile at the left of the button, scaled to fit
## it: two-terminal symbols and supplies lying horizontally, fuses, breakers,
## three-pole devices, motors and the temperature sensor upright. Supplies
## show their conductor name in the circle.
func _add_icon(button: Button, template: Dictionary) -> void:
	var data: Dictionary = template.duplicate()
	var conductor: String = str(data.get("conductor", ""))
	data["designation"] = ("L1" if conductor == "L" else conductor) if not conductor.is_empty() else "X1"
	# The rating a new part gets (coils show its AC / DC mark).
	var ratings: PackedStringArray = VoltageRating.offered(data["type"]) if data.get("family", "") != "compact" else PackedStringArray()
	if not ratings.is_empty() and not data.has("rating"):
		data["rating"] = ratings[0]
	var component: CircuitComponent = DocumentSerializer.component_from_dict(data)
	var supply: bool = component is PowerSupply
	var upright: bool = component is ThreePhaseMotor or component is AnalogSensor or component is ProximitySensor or component is ProtectiveDevice or component.get_terminal_names().size() > 3
	var placement: Placement = Placement.new(Vector2i.ZERO, 0, false) if upright else Placement.new(Vector2i.ZERO, 3, true)
	if component is ChangeoverContact:
		# Its common terminal (the pivot) comes on the left only turned once.
		placement = Placement.new(Vector2i.ZERO, 1, true)
	var symbol: SchematicSymbol = SymbolFactory.create(component, placement)
	symbol.show_labels = supply
	symbol.preview = true
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
	# Extent of the drawing: body and terminals (or the smaller version a
	# wide symbol draws here), turned like the placement.
	var g: float = float(SymbolGeometry.GRID)
	var local: Rect2 = symbol.preview_rect()
	if not local.has_area():
		local = SymbolGeometry.local_body(component)
		for cell: Vector2i in SymbolGeometry.local_terminals(component).values():
			local = local.expand(Vector2(cell))
		local = Rect2(local.position * g, local.size * g)
	local = local.grow(2.0 if supply else 6.0)
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
