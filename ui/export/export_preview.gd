class_name ExportPreview
extends ConfirmationDialog
## Shows the sheets about to be exported (PNG: the page shown, PDF: every
## page) as they will be saved, one at a time with page buttons, and the
## paper each is on. The wire numbers can be left out. OK asks where to save.

## Wire numbers were switched on or off: render the sheets again.
signal wire_numbers_toggled(on: bool)

var _picture: TextureRect
var _status: Label
var _previous: Button
var _next: Button
var _numbers: CheckBox
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


## Opens the preview for a PNG ([param pdf] false) or PDF export, empty
## until [method show_sheets] fills it.
func open(pdf: bool) -> void:
	title = tr("Export PDF") if pdf else tr("Export PNG")
	ok_button_text = tr("Save PDF…") if pdf else tr("Save PNG…")
	cancel_button_text = tr("Cancel")
	_numbers.text = tr("Wire numbers")
	_images.clear()
	_layouts.clear()
	_picture.texture = null
	_status.text = tr("Rendering…")
	_update_buttons()
	popup_centered_ratio(0.75)


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
