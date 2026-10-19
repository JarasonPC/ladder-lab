class_name ExportPreview
extends ConfirmationDialog
## Shows the sheets about to be exported (PNG: the page shown, PDF: every
## page) as they will be saved, one at a time with page buttons, and the
## paper each is on. The wire numbers can be left out; a PDF holds, as
## ticked, the schematic, the control stations, the switchboards, the
## workspace and the parts list. OK asks where to save.

## Wire numbers were switched on or off: render the sheets again.
signal wire_numbers_toggled(on: bool)
## What the PDF holds was changed ([method contents]): render the sheets again.
signal contents_changed
## The largest paper was changed ([method largest_paper]): render the sheets again.
signal paper_changed

## What a PDF can hold, in order (keys of [method contents]).
const CONTENTS: PackedStringArray = ["schematic", "stations", "switchboards", "workspace", "parts_list"]
const CONTENT_TITLES: PackedStringArray = ["Schematic", "Control stations", "Switchboards", "Workspace", "Parts list"]

var _picture: TextureRect
var _status: Label
var _previous: Button
var _next: Button
var _numbers: CheckBox
var _paper_label: Label
var _paper: OptionButton
var _contents_row: HBoxContainer
var _contents: Dictionary[String, CheckBox] = {}
var _images: Array[Image] = []
var _layouts: Array[SheetLayout] = []
var _index: int = 0


func _init() -> void:
	min_size = Vector2i(720, 560)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var paper: PanelContainer = PanelContainer.new()
	paper.theme_type_variation = "Card"
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(paper)
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# The sheet is shown much smaller than it is: mipmaps keep thin lines.
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_picture.custom_minimum_size = Vector2(640, 420)
	paper.add_child(_picture)
	var bar: HBoxContainer = HBoxContainer.new()
	box.add_child(bar)
	_previous = _tool(bar, "arrow_left", func() -> void: _show(_index - 1))
	_status = Label.new()
	_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_status.theme_type_variation = "MutedLabel"
	_status.custom_minimum_size = Vector2(220, 0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_status)
	_next = _tool(bar, "arrow_right", func() -> void: _show(_index + 1))
	var rest: Control = Control.new()
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(rest)
	_numbers = CheckBox.new()
	_numbers.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_numbers.button_pressed = true
	_numbers.toggled.connect(func(on: bool) -> void: wire_numbers_toggled.emit(on))
	bar.add_child(_numbers)
	_paper_label = Label.new()
	_paper_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	bar.add_child(_paper_label)
	_paper = OptionButton.new()
	_paper.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for size: Dictionary in SheetLayout.PAPERS:
		_paper.add_item(size["name"])
	_paper.select(SheetLayout.paper_index(SheetLayout.DEFAULT_LARGEST))
	_paper.item_selected.connect(func(_index: int) -> void: paper_changed.emit())
	bar.add_child(_paper)
	_contents_row = HBoxContainer.new()
	_contents_row.add_theme_constant_override("separation", 12)
	box.add_child(_contents_row)
	for key: String in CONTENTS:
		var check: CheckBox = CheckBox.new()
		check.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		check.button_pressed = true
		check.toggled.connect(func(_on: bool) -> void:
			_update_numbers()
			contents_changed.emit())
		_contents_row.add_child(check)
		_contents[key] = check


## Opens the preview for a PNG ([param pdf] false) or PDF export, empty
## until [method show_sheets] fills it. A PDF holds what [param chosen] says
## (see [method contents]); what [param available] has false is greyed out
## (the schematic has nothing of it).
func open(pdf: bool, chosen: Dictionary = {}, available: Dictionary = {}, largest: String = SheetLayout.DEFAULT_LARGEST) -> void:
	title = tr("Export PDF") if pdf else tr("Export PNG")
	_paper_label.text = tr("Largest sheet")
	_paper.tooltip_text = tr("Pages go on the smallest sheet they fit on, up to this one; larger pages are scaled down onto it")
	_paper.select(maxi(SheetLayout.paper_index(largest), 0))
	ok_button_text = tr("Save PDF…") if pdf else tr("Save PNG…")
	cancel_button_text = tr("Cancel")
	_numbers.text = tr("Wire numbers")
	_contents_row.visible = pdf
	for i: int in CONTENTS.size():
		var check: CheckBox = _contents[CONTENTS[i]]
		check.text = tr(CONTENT_TITLES[i])
		check.set_pressed_no_signal(bool(chosen.get(CONTENTS[i], true)))
		check.disabled = not bool(available.get(CONTENTS[i], true))
	_update_numbers()
	rendering()
	popup_centered_ratio(0.75)


## The largest paper chosen ("A5" to "A0").
func largest_paper() -> String:
	return SheetLayout.PAPERS[maxi(_paper.selected, 0)]["name"]


## Empty until [method show_sheets] brings the sheets rendered again: what
## was shown before is out of date, and is neither shown nor saved meanwhile.
func rendering() -> void:
	_images = []
	_layouts = []
	_picture.texture = null
	_status.text = tr("Rendering…")
	_update_buttons()


## What the PDF is to hold, by the keys of [constant CONTENTS]; what has
## nothing to show is left out.
func contents() -> Dictionary[String, bool]:
	var result: Dictionary[String, bool] = {}
	for key: String in CONTENTS:
		result[key] = _contents[key].button_pressed and not _contents[key].disabled
	return result


## The ticks as they are, also of what has nothing to show (to remember them).
func ticks() -> Dictionary[String, bool]:
	var result: Dictionary[String, bool] = {}
	for key: String in CONTENTS:
		result[key] = _contents[key].button_pressed
	return result


## Wire numbers only matter with the schematic in.
func _update_numbers() -> void:
	_numbers.disabled = _contents_row.visible and not _contents["schematic"].button_pressed


## True when the wire numbers are to be drawn.
func wire_numbers() -> bool:
	return _numbers.button_pressed


## Shows the rendered sheets (and keeps the page shown, if there is one).
func show_sheets(images: Array[Image], layouts: Array[SheetLayout]) -> void:
	_images = images
	_layouts = layouts
	_show(_index if _index < images.size() else 0)


func _show(index: int) -> void:
	if _images.is_empty():
		_picture.texture = null
		_status.text = tr("Nothing to export: tick what the PDF is to hold.")
		_update_buttons()
		return
	_index = clampi(index, 0, _images.size() - 1)
	var image: Image = _images[_index]
	_picture.texture = null
	if image != null:
		var shown: Image = image.duplicate() as Image
		shown.generate_mipmaps()
		_picture.texture = ImageTexture.create_from_image(shown)
	var layout: SheetLayout = _layouts[_index]
	var orientation: String = tr("portrait") if layout.portrait else tr("landscape")
	var scale: String = "" if is_equal_approx(layout.cell_mm, SheetLayout.CELL_MM) else "  ·  %d %%" % roundi(layout.cell_mm / SheetLayout.CELL_MM * 100.0)
	_status.text = tr("Page %d / %d") % [_index + 1, _images.size()] + "  ·  %s %s%s" % [layout.paper_name, orientation, scale]
	_update_buttons()


func _update_buttons() -> void:
	_previous.disabled = _index <= 0 or _images.size() < 2
	_next.disabled = _index >= _images.size() - 1
	_previous.visible = _images.size() > 1
	_next.visible = _images.size() > 1
	get_ok_button().disabled = _images.is_empty()


func _tool(parent: Control, icon_name: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = "ToolButton"
	button.icon = AppTheme.icon(icon_name)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
