class_name Palette
extends PanelContainer
## Component palette for the editor. Each entry shows the symbol and emits a
## component template (see [DocumentSerializer]) when chosen.

signal template_chosen(template: Dictionary)

## Entries: English title (translated with tr()) and component template.
const ENTRIES: Array[Dictionary] = [
	{"title": "L supply", "template": {"type": "supply", "conductor": "L"}},
	{"title": "N supply", "template": {"type": "supply", "conductor": "N"}},
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
]

const ICON_SCALE: float = 0.7

var _buttons: Array[Button] = []


func _ready() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry: Dictionary in ENTRIES:
		var button: Button = Button.new()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(210, 44)
		button.add_theme_constant_override("h_separation", 0)
		var template: Dictionary = entry["template"]
		button.pressed.connect(func() -> void: template_chosen.emit(template.duplicate()))
		_add_icon(button, template)
		list.add_child(button)
		_buttons.append(button)
	retranslate()


func retranslate() -> void:
	for i: int in _buttons.size():
		_buttons[i].text = "              " + tr(ENTRIES[i]["title"])


## Draws the symbol lying horizontally at the left of the button.
func _add_icon(button: Button, template: Dictionary) -> void:
	var data: Dictionary = template.duplicate()
	data["designation"] = "L" if data.get("conductor", "") == "L" else ("N" if data.has("conductor") else "X1")
	var component: CircuitComponent = DocumentSerializer.component_from_dict(data)
	var placement: Placement = Placement.new(Vector2i.ZERO, 3, true)
	var symbol: SchematicSymbol = SymbolFactory.create(component, placement)
	symbol.show_labels = false
	symbol.scale = Vector2(ICON_SCALE, ICON_SCALE)
	# Symbols are drawn for the light schematic paper, so give them a tile of it.
	var paper: ColorRect = ColorRect.new()
	paper.color = SchematicTheme.BACKGROUND
	paper.position = Vector2(4, 4)
	paper.size = Vector2(54, 36)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(paper)
	var span: float = SymbolGeometry.SPAN * SymbolGeometry.GRID * ICON_SCALE
	symbol.position = Vector2(10.0 + (span * 0.5 if component is PowerSupply else 0.0), 23.0)
	button.add_child(symbol)
