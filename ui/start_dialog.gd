class_name StartDialog
extends AcceptDialog
## Shown at every start: a new project or one opened from a file, each a card
## with its icon. A tick asks for the interface tour, which starts once the
## project is open.

## Create project was chosen.
signal create_chosen
## Open project was chosen.
signal open_chosen

## Size of the icons on the cards.
const ICON_SIZE: int = 40

var _create: Button
var _open: Button
var _tour: CheckBox
var _tour_note: Label


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# The cards are the answers.
	get_ok_button().hide()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	_create = _card(row, "plus")
	_create.pressed.connect(func() -> void:
		hide()
		create_chosen.emit())
	_open = _card(row, "folder")
	_open.pressed.connect(func() -> void:
		hide()
		open_chosen.emit())
	_tour = CheckBox.new()
	_tour.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(_tour)
	_tour_note = Label.new()
	_tour_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tour_note.theme_type_variation = "MutedLabel"
	column.add_child(_tour_note)
	add_child(column)


func _card(parent: Control, icon_name: String) -> Button:
	var card: Button = Button.new()
	card.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	card.icon = AppTheme.icon(icon_name, ICON_SIZE)
	card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	card.custom_minimum_size = Vector2(220, 130)
	parent.add_child(card)
	return card


## Whether the tour is to start once the project is open.
func wants_tour() -> bool:
	return _tour.button_pressed


## Shows the cards; the tour ticked when [param tour] is true.
func ask(tour: bool) -> void:
	title = tr("Welcome to LadderLab")
	_create.text = tr("Create project")
	_open.text = tr("Open project")
	_tour.text = tr("Program guide")
	_tour_note.text = tr("A short tour of the window, once the project is open.")
	_tour.button_pressed = tour
	# At the interface size of the window it is asked from.
	content_scale_factor = get_parent().get_window().content_scale_factor
	reset_size()
	popup_centered()
