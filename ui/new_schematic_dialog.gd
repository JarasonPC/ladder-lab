class_name NewSchematicDialog
extends ConfirmationDialog
## Asks what a new schematic will be, once and for good (see [member
## SchematicDocument.environment]): an industrial control circuit, a
## residential prototype or a residential installation. Each is a card with
## its icon; a double click on a card takes it at once. Kinds still being
## made are shown locked and cannot be chosen.

## [param environment] (a [enum SchematicDocument.Kind]) was chosen.
signal chosen(environment: int)

## Size of the icons on the cards.
const ICON_SIZE: int = 40
## The cards, in [enum SchematicDocument.Kind] order.
const ICONS: PackedStringArray = ["factory", "bulb", "house"]
## Kinds not finished yet: their cards carry a lock and cannot be chosen
## (schematics of them made before still open).
const LOCKED: Array[int] = [SchematicDocument.Kind.PROTOTYPE]

var _cards: Array[Button] = []
var _note: Label
## The card chosen last (offered first the next time).
var _environment: int = SchematicDocument.Kind.INDUSTRIAL


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
	for environment: int in ICONS.size():
		var card: Button = Button.new()
		card.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		card.toggle_mode = true
		card.button_group = group
		card.icon = AppTheme.icon("lock" if environment in LOCKED else ICONS[environment], ICON_SIZE)
		card.disabled = environment in LOCKED
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.custom_minimum_size = Vector2(220, 170)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.toggled.connect(func(on: bool) -> void:
			if on:
				_environment = environment)
		card.gui_input.connect(func(event: InputEvent) -> void:
			var click: InputEventMouseButton = event as InputEventMouseButton
			if click != null and click.double_click and click.button_index == MOUSE_BUTTON_LEFT and not card.disabled:
				_environment = environment
				hide()
				chosen.emit(environment))
		row.add_child(card)
		_cards.append(card)
	add_child(column)
	confirmed.connect(func() -> void: chosen.emit(_environment))


## Name of [param environment] as the toolbar shows it.
static func environment_name(environment: int) -> String:
	match environment:
		SchematicDocument.Kind.PROTOTYPE:
			return TranslationServer.translate("Prototype residential")
		SchematicDocument.Kind.RESIDENTIAL:
			return TranslationServer.translate("Residential")
	return TranslationServer.translate("Industrial")


## What [param environment] is for, a line.
static func environment_text(environment: int) -> String:
	match environment:
		SchematicDocument.Kind.PROTOTYPE:
			return TranslationServer.translate("Light switches, luminaires and sockets drawn and wired freely, to try circuits out")
		SchematicDocument.Kind.RESIDENTIAL:
			return TranslationServer.translate("A house installation: the consumer unit as a single-line diagram, with its floor plan")
	return TranslationServer.translate("Control circuits: contactors, time relays, motors, PLCs, switchboards")


## Shows the cards, the one chosen last pressed.
func ask() -> void:
	title = tr("New schematic")
	ok_button_text = tr("Create")
	cancel_button_text = tr("Cancel")
	_note.text = tr("What will you draw? It cannot be changed later.")
	for environment: int in _cards.size():
		var text: String = tr("Not ready yet: coming in a later version") if environment in LOCKED else environment_text(environment)
		_cards[environment].text = environment_name(environment) + "\n" + text
	_cards[_environment].button_pressed = true
	# At the interface size of the window it is asked from.
	content_scale_factor = get_parent().get_window().content_scale_factor
	reset_size()
	popup_centered()
