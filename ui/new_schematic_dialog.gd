class_name NewSchematicDialog
extends ConfirmationDialog
## Asks what a new schematic will be, once and for good: an industrial
## control circuit or a house installation (see [member
## SchematicDocument.residential]). Each is a card with its icon; a double
## click on a card takes it at once.

## [param residential] was chosen.
signal chosen(residential: bool)

## Size of the icons on the cards.
const ICON_SIZE: int = 40

var _cards: Array[Button] = []
var _note: Label
## The card chosen last (offered first the next time).
var _residential: bool = false


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_note = Label.new()
	_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(_note)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var group: ButtonGroup = ButtonGroup.new()
	for residential: bool in [false, true]:
		var card: Button = Button.new()
		card.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		card.toggle_mode = true
		card.button_group = group
		card.icon = AppTheme.icon("house" if residential else "factory", ICON_SIZE)
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.custom_minimum_size = Vector2(220, 150)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.toggled.connect(func(on: bool) -> void:
			if on:
				_residential = residential)
		card.gui_input.connect(func(event: InputEvent) -> void:
			var click: InputEventMouseButton = event as InputEventMouseButton
			if click != null and click.double_click and click.button_index == MOUSE_BUTTON_LEFT:
				_residential = residential
				hide()
				chosen.emit(residential))
		row.add_child(card)
		_cards.append(card)
	add_child(column)
	confirmed.connect(func() -> void: chosen.emit(_residential))


## Shows the cards, the one chosen last pressed.
func ask() -> void:
	title = tr("New schematic")
	ok_button_text = tr("Create")
	cancel_button_text = tr("Cancel")
	_note.text = tr("What will you draw? It cannot be changed later.")
	_cards[0].text = tr("Industrial") + "\n" + tr("Control circuits: contactors, time relays, motors, PLCs, switchboards")
	_cards[1].text = tr("Residential") + "\n" + tr("House installation: light switches, luminaires, socket outlets")
	_cards[1 if _residential else 0].button_pressed = true
	# At the interface size of the window it is asked from.
	content_scale_factor = get_parent().get_window().content_scale_factor
	reset_size()
	popup_centered()
