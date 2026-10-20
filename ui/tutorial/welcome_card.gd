class_name WelcomeCard
extends PanelContainer
## Offered over the corner of the drawing on the first start: first the
## language of the program, then the tour of the window, the first lesson,
## or neither. It never blocks the window.

## A language was chosen: its index in [member languages].
signal language_chosen(index: int)
signal tour_chosen
signal lesson_chosen
signal dismissed

## Names of the languages offered, each in its own language (never translated).
var languages: PackedStringArray = PackedStringArray()

var _language_page: VBoxContainer
var _offer_page: VBoxContainer
var _title: Label
var _text: Label
var _tour: Button
var _lesson: Button
var _later: Button


func _ready() -> void:
	theme_type_variation = "TourCard"
	custom_minimum_size = Vector2(340, 0)
	var pages: VBoxContainer = VBoxContainer.new()
	add_child(pages)

	# The language, asked in every language at once: the program cannot
	# know yet which one can be read.
	_language_page = VBoxContainer.new()
	_language_page.add_theme_constant_override("separation", 10)
	pages.add_child(_language_page)
	var heading: Label = _label(_language_page)
	heading.theme_type_variation = "TitleLabel"
	heading.add_theme_font_size_override("font_size", 18)
	heading.text = "Welcome · Vítejte"
	_label(_language_page).text = "Choose the language of LadderLab.\nVyberte jazyk aplikace LadderLab."
	var choices: HBoxContainer = HBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	_language_page.add_child(choices)
	for i: int in languages.size():
		var choice: Button = _button(choices, "TutorialButton", "")
		choice.text = languages[i]
		choice.pressed.connect(func() -> void:
			language_chosen.emit(i)
			show_offer())

	_offer_page = VBoxContainer.new()
	_offer_page.add_theme_constant_override("separation", 10)
	pages.add_child(_offer_page)
	_title = _label(_offer_page)
	_title.theme_type_variation = "TitleLabel"
	_title.add_theme_font_size_override("font_size", 18)
	_text = _label(_offer_page)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_offer_page.add_child(row)
	_tour = _button(row, "TutorialButton", "target")
	_tour.pressed.connect(func() -> void: tour_chosen.emit())
	_lesson = _button(row, "TutorialButton", "lesson")
	_lesson.pressed.connect(func() -> void: lesson_chosen.emit())
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	_later = _button(row, "", "")
	_later.pressed.connect(func() -> void: dismissed.emit())
	ask_language()
	retranslate()


## Shows the language choice (the first page).
func ask_language() -> void:
	if _language_page == null:
		return
	_language_page.show()
	_offer_page.hide()
	_fit()


## Shows the tour and the first lesson (once the language is chosen).
func show_offer() -> void:
	_language_page.hide()
	_offer_page.show()
	_fit()


## Just as big as the page shown, keeping its right and bottom edges where
## its anchors put them (it grows to the left and up).
func _fit() -> void:
	offset_left = offset_right
	offset_top = offset_bottom


## True while the language is asked for.
func asking_language() -> bool:
	return _language_page != null and _language_page.visible


func retranslate() -> void:
	if _title == null:
		return
	_title.text = tr("Welcome to LadderLab")
	_text.text = tr("New here? Take a short tour of the window, or learn to draw your first circuit in a lesson.")
	_tour.text = tr("Take the tour")
	_lesson.text = tr("First lesson")
	_later.text = tr("Not now")


func _label(parent: Control) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(300, 0)
	parent.add_child(label)
	return label


func _button(parent: Control, variation: String, icon_name: String) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.theme_type_variation = variation
	button.focus_mode = Control.FOCUS_NONE
	if not icon_name.is_empty():
		button.icon = AppTheme.icon(icon_name, 16)
	parent.add_child(button)
	return button
