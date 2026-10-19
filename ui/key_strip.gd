class_name KeyStrip
extends PanelContainer
## A strip above the timing panel while simulating: every key bound to a
## push button or switch with what it operates (the plate text, or the
## designation, and its station), lit while the button is held, a switch
## with its position (I or 0). Its title rolls it in and out ([member rolled]).

## Rolled in or out by its title (to remember it).
signal rolled_changed(rolled: bool)

const KEY_FONT_SIZE: int = 11

var document: SchematicDocument
## Only the title shows.
var rolled: bool = false:
	set(value):
		rolled = value
		if _chips != null:
			_chips.visible = not rolled
			_title.icon = AppTheme.icon("chevron_right" if rolled else "chevron_down", 16)

var _title: Button
var _chips: _Chips


func _ready() -> void:
	theme_type_variation = "Statusbar"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_title = TimingPanel.rollout_button()
	_title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_title.pressed.connect(func() -> void:
		rolled = not rolled
		rolled_changed.emit(rolled))
	row.add_child(_title)
	_chips = _Chips.new()
	_chips.strip = self
	_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_chips)
	rolled = rolled
	retranslate()


func retranslate() -> void:
	_title.text = tr("Keys")
	_title.tooltip_text = tr("Keys of the keyboard bound to buttons and switches (right click on one in Edit mode: Bind a key…)")


## True when the document has keys to show.
func has_keys() -> bool:
	return document != null and not document.key_bindings.is_empty()


func _process(_delta: float) -> void:
	if is_visible_in_tree() and not rolled:
		# Held buttons and switches follow the simulation.
		_chips.update_minimum_size()
		_chips.queue_redraw()


## The keys, side by side, wrapping onto more rows when they do not fit.
class _Chips extends Control:
	var strip: KeyStrip

	func _entries() -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		var doc: SchematicDocument = strip.document
		if doc == null:
			return result
		var designations: Array = doc.key_bindings.keys()
		designations.sort_custom(func(a: String, b: String) -> bool: return doc.key_bindings[a].naturalnocasecmp_to(doc.key_bindings[b]) < 0)
		for designation: String in designations:
			var device: CircuitComponent = doc.circuit.get_operator(designation)
			if device == null:
				continue
			var text: String = "-" + designation
			var where: String = ""
			for box: ControlBox in doc.control_boxes:
				for item: ControlBoxItem in box.items:
					if item.designation == designation:
						where = "+" + box.name
						if not item.label.is_empty():
							text = item.label
			var lit: bool = device is PushButton and (device as SwitchingElement).get_travel() > 0.5
			if device is LatchingSwitch:
				# The positions as marked on switches: I on, 0 off.
				text += "  " + CamSwitch.MARKS[(device as LatchingSwitch).get_position()]
			elif device is CamSwitch:
				text += "  " + CamSwitch.MARKS[(device as CamSwitch).position]
			result.append({"key": doc.key_bindings[designation], "text": text, "where": where, "lit": lit})
		return result

	func _layout() -> Array[Dictionary]:
		var font: Font = get_theme_font("font", "Label")
		var font_size: int = get_theme_font_size("font_size", "Label")
		var x: float = 0.0
		var y: float = 4.0
		var row_h: float = Keycap.size_of("W", KEY_FONT_SIZE).y + 6.0
		var placed: Array[Dictionary] = []
		for entry: Dictionary in _entries():
			var cap: Vector2 = Keycap.size_of(entry["key"], KEY_FONT_SIZE)
			var w: float = cap.x + 6.0 + font.get_string_size(entry["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if not str(entry["where"]).is_empty():
				w += 6.0 + font.get_string_size(entry["where"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1).x
			if x > 0.0 and x + w > size.x:
				x = 0.0
				y += row_h
			entry["at"] = Vector2(x, y)
			placed.append(entry)
			x += w + 22.0
		return placed

	func _get_minimum_size() -> Vector2:
		var placed: Array[Dictionary] = _layout()
		var bottom: float = 0.0
		for entry: Dictionary in placed:
			bottom = maxf(bottom, (entry["at"] as Vector2).y + Keycap.size_of(entry["key"], KEY_FONT_SIZE).y + 4.0)
		return Vector2(0.0, bottom)

	func _draw() -> void:
		var font: Font = get_theme_font("font", "Label")
		var font_size: int = get_theme_font_size("font_size", "Label")
		var text_color: Color = get_theme_color("font_color", "Label")
		var muted: Color = AppTheme.text_muted
		for entry: Dictionary in _layout():
			var cap: Rect2 = Keycap.draw(self, entry["at"], entry["key"], KEY_FONT_SIZE, entry["lit"])
			var baseline: float = cap.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
			var x: float = cap.end.x + 6.0
			draw_string(font, Vector2(x, baseline), entry["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
			x += font.get_string_size(entry["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 6.0
			if not str(entry["where"]).is_empty():
				draw_string(font, Vector2(x, baseline), entry["where"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, muted)
