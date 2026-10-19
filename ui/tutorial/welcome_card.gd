class_name WelcomeCard
extends PanelContainer
## Offered over the corner of the drawing on the first start: the tour of
## the window, the first lesson, or neither. It never blocks the window.

signal tour_chosen
signal lesson_chosen
signal dismissed

var _title: Label
var _text: Label
var _tour: Button
var _lesson: Button
var _later: Button


func _ready() -> void:
	theme_type_variation = "TourCard"
	custom_minimum_size = Vector2(340, 0)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	_title = Label.new()
	_title.theme_type_variation = "TitleLabel"
	_title.add_theme_font_size_override("font_size", 18)
	column.add_child(_title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(300, 0)
	column.add_child(_text)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_tour = _button(row, "TutorialButton", "target")
	_tour.pressed.connect(func() -> void: tour_chosen.emit())
	_lesson = _button(row, "TutorialButton", "lesson")
	_lesson.pressed.connect(func() -> void: lesson_chosen.emit())
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	_later = _button(row, "", "")
	_later.pressed.connect(func() -> void: dismissed.emit())
	for c: Control in [_title, _text]:
		c.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	retranslate()


func retranslate() -> void:
	if _title == null:
		return
	_title.text = tr("Welcome to LadderLab")
	_text.text = tr("New here? Take a short tour of the window, or learn to draw your first circuit in a lesson.")
	_tour.text = tr("Take the tour")
	_lesson.text = tr("First lesson")
	_later.text = tr("Not now")


func _button(parent: Control, variation: String, icon_name: String) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.theme_type_variation = variation
	button.focus_mode = Control.FOCUS_NONE
	if not icon_name.is_empty():
		button.icon = AppTheme.icon(icon_name, 16)
	parent.add_child(button)
	return button
