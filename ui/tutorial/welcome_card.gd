class_name WelcomeCard
extends PanelContainer
## Offered over the corner of the drawing on the first start: the language of
## the program, before the start window asks for a project in it.

## A language was chosen: its index in [member languages].
signal language_chosen(index: int)

## Names of the languages offered, each in its own language (never translated).
var languages: PackedStringArray = PackedStringArray()


func _ready() -> void:
	theme_type_variation = "TourCard"
	custom_minimum_size = Vector2(340, 0)
	# The language, asked in every language at once: the program cannot
	# know yet which one can be read.
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	add_child(page)
	var heading: Label = _label(page)
	heading.theme_type_variation = "TitleLabel"
	heading.add_theme_font_size_override("font_size", 18)
	heading.text = "Welcome · Vítejte"
	_label(page).text = "Choose the language of LadderLab.\nVyberte jazyk aplikace LadderLab."
	var choices: HBoxContainer = HBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	page.add_child(choices)
	for i: int in languages.size():
		var choice: Button = Button.new()
		choice.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		choice.theme_type_variation = "TutorialButton"
		choice.focus_mode = Control.FOCUS_NONE
		choice.text = languages[i]
		choice.pressed.connect(func() -> void: language_chosen.emit(i))
		choices.add_child(choice)
	# Just as big as the page, keeping its right and bottom edges where its
	# anchors put them (it grows to the left and up).
	offset_left = offset_right
	offset_top = offset_bottom


func _label(parent: Control) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(300, 0)
	parent.add_child(label)
	return label
