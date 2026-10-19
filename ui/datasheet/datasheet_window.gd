class_name DatasheetWindow
extends Window
## Datasheets in a window of their own: the list of parts on the left (the
## part opened from the schematic first, then every palette part by group),
## the pages of the chosen one on the right, zoomed with the buttons or
## Ctrl+wheel, and exported as a PDF document (always on white paper).

## A key this window does not use (the main window's shortcuts).
signal key_pressed(event: InputEventKey)

const SIZE: Vector2 = Vector2(1040, 860)
const LIST_WIDTH: float = 250.0
## Pixels per point of the exported pages (200 dpi).
const EXPORT_SCALE: float = 200.0 / 72.0
const ZOOM_STEP: float = 1.2

var sheet: Datasheet = null

## The part opened from the schematic (a list item of its own), or null.
var _part: Datasheet = null
var _list: ItemList
var _title: Label
var _zoom: ZoomBox
var _pages: VBoxContainer
var _export_button: Button
var _file_dialog: FileDialog
var _error: AcceptDialog
## List item -> palette entry index; -1 for the part from the schematic.
var _entries: Dictionary[int, int] = {}


func _init() -> void:
	visible = false
	# A window of its own on the desktop (dialogs and popups are drawn inside
	# the window they belong to).
	force_native = true
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	min_size = Vector2i(560, 400)
	wrap_controls = false


func _ready() -> void:
	size = Vector2i(SIZE * content_scale_factor)
	_build()
	close_requested.connect(hide)
	retranslate()


## Shows the datasheet of [param c] in [param doc] (a part of the schematic).
func show_part(c: CircuitComponent, doc: SchematicDocument) -> void:
	_part = Datasheet.of(c, doc)
	_fill_list()
	_list.select(_index_of_entry(-1))
	_show(_part)


## Shows the datasheet of palette entry [param index].
func show_entry(index: int) -> void:
	_fill_list()
	_list.select(_index_of_entry(index))
	_list.ensure_current_is_visible()
	_show(Datasheet.of_template(Palette.ENTRIES[index]["template"]))


## Builds the shown datasheet again (the language or the paper changed).
func retranslate() -> void:
	if not is_node_ready():
		return
	_export_button.text = tr("Export PDF…")
	_export_button.tooltip_text = tr("Save the datasheet as a PDF document")
	var selected: PackedInt32Array = _list.get_selected_items()
	if _part != null:
		_part = Datasheet.of(_part.component, _part.document)
	_fill_list()
	if not selected.is_empty() and selected[0] < _list.item_count:
		_list.select(selected[0])
	if _part != null and sheet != null and sheet.component == _part.component:
		_show(_part)
	elif sheet != null:
		_show(Datasheet.of(sheet.component, sheet.document))


func _build() -> void:
	var root: PanelContainer = PanelContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_stylebox_override("panel", AppTheme.box(AppTheme.bg0, 0, 0.0, 0.0))
	add_child(root)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	root.add_child(column)
	var bar: PanelContainer = PanelContainer.new()
	bar.theme_type_variation = "Toolbar"
	column.add_child(bar)
	var tools: HBoxContainer = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	bar.add_child(tools)
	_title = Label.new()
	_title.theme_type_variation = "TitleLabel"
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tools.add_child(_title)
	for zoom_in: bool in [false, true]:
		var z: Button = Button.new()
		z.theme_type_variation = "ToolButton"
		z.focus_mode = Control.FOCUS_NONE
		z.icon = AppTheme.icon("zoom_in" if zoom_in else "zoom_out")
		z.tooltip_text = tr("Zoom in") if zoom_in else tr("Zoom out")
		z.pressed.connect(func() -> void: _zoom.zoom *= ZOOM_STEP if zoom_in else 1.0 / ZOOM_STEP)
		tools.add_child(z)
	_export_button = Button.new()
	_export_button.theme_type_variation = "PrimaryButton"
	_export_button.focus_mode = Control.FOCUS_NONE
	_export_button.icon = AppTheme.icon("download")
	_export_button.pressed.connect(_ask_export)
	tools.add_child(_export_button)
	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(split)
	_list = ItemList.new()
	_list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	_list.item_selected.connect(_on_item_selected)
	split.add_child(_list)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_zoom = ZoomBox.new()
	_zoom.zoom = 1.25
	center.add_child(_zoom)
	_pages = VBoxContainer.new()
	_pages.add_theme_constant_override("separation", 18)
	_zoom.add_child(_pages)
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.filters = PackedStringArray(["*.pdf ; PDF"])
	_file_dialog.file_selected.connect(func(path: String) -> void: export_pdf(path if path.get_extension().to_lower() == "pdf" else path + ".pdf"))
	add_child(_file_dialog)
	_error = AcceptDialog.new()
	add_child(_error)
	var keys: _Keys = _Keys.new()
	keys.window = self
	add_child(keys)


## The parts in the list: the part from the schematic, then the palette by group.
func _fill_list() -> void:
	_list.clear()
	_entries.clear()
	if _part != null:
		_header(tr("In the schematic"))
		_entries[_list.add_item("-%s  %s" % [_part.component.designation, _part.title])] = -1
	var group: String = ""
	for i: int in Palette.ENTRIES.size():
		var template: Dictionary = Palette.ENTRIES[i]["template"]
		if Palette.group_of(template) != group:
			group = Palette.group_of(template)
			_header(Datasheet.of_template(template).group)
		_entries[_list.add_item(tr(Palette.ENTRIES[i]["title"]))] = i


func _header(text: String) -> void:
	var index: int = _list.add_item(text.to_upper(), null, false)
	_list.set_item_disabled(index, true)
	_list.set_item_custom_fg_color(index, AppTheme.text_faint)


func _index_of_entry(entry: int) -> int:
	for item: int in _entries:
		if _entries[item] == entry:
			return item
	return -1


func _on_item_selected(index: int) -> void:
	if not _entries.has(index):
		return
	var entry: int = _entries[index]
	_show(_part if entry < 0 else Datasheet.of_template(Palette.ENTRIES[entry]["template"]))


func _show(p_sheet: Datasheet) -> void:
	sheet = p_sheet
	title = tr("Datasheet – %s") % sheet.title
	_title.text = sheet.title if sheet != _part else "-%s  %s" % [sheet.component.designation, sheet.title]
	for child: Node in _pages.get_children():
		_pages.remove_child(child)
		child.queue_free()
	for layout: DatasheetLayout in DatasheetLayout.compose(sheet):
		var page: DatasheetPage = DatasheetPage.new(sheet, layout)
		_pages.add_child(page)


## Repaints the pages after the schematic paper changed (dark / white).
func refresh_paper() -> void:
	if sheet != null and is_node_ready():
		_show(sheet)


func _ask_export() -> void:
	_file_dialog.title = tr("Export PDF")
	var base: String = sheet.component.designation if sheet == _part else sheet.title.validate_filename()
	_file_dialog.current_file = "%s-%s.pdf" % [tr("datasheet"), base]
	_file_dialog.popup_centered_ratio(0.6)


## Saves the pages shown as a PDF document of A4 pages on white paper.
func export_pdf(path: String) -> void:
	var images: Array[Image] = await render_pages(sheet)
	var pdf: PdfWriter = PdfWriter.new()
	pdf.title = tr("Datasheet – %s") % sheet.title
	for image: Image in images:
		if image == null:
			break
		pdf.add_page(image, DatasheetLayout.PAGE)
	if pdf.page_count() != images.size() or images.is_empty() or pdf.save(path) != OK:
		_error.dialog_text = tr("Could not save %s.") % path.get_file()
		_error.popup_centered()


## Images of the pages of [param p_sheet] on white paper at [constant
## EXPORT_SCALE] (a coroutine: await it).
func render_pages(p_sheet: Datasheet) -> Array[Image]:
	var dark_paper: bool = SchematicTheme.dark
	SchematicTheme.use(false)
	var viewports: Array[SubViewport] = []
	for layout: DatasheetLayout in DatasheetLayout.compose(p_sheet):
		var viewport: SubViewport = SubViewport.new()
		viewport.transparent_bg = false
		viewport.size = Vector2i((DatasheetLayout.PAGE * EXPORT_SCALE).round())
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var holder: Control = Control.new()
		holder.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
		viewport.add_child(holder)
		var page: DatasheetPage = DatasheetPage.new(p_sheet, layout)
		page.scale = Vector2.ONE * EXPORT_SCALE
		holder.add_child(page)
		add_child(viewport)
		viewports.append(viewport)
	await RenderingServer.frame_post_draw
	var images: Array[Image] = []
	for viewport: SubViewport in viewports:
		var image: Image = viewport.get_texture().get_image()
		if image != null:
			image.convert(Image.FORMAT_RGB8)
		images.append(image)
		viewport.queue_free()
	SchematicTheme.use(dark_paper)
	return images


## Keys this window does not use: Escape closes it, the others go to the
## main window's shortcuts.
class _Keys:
	extends Node

	var window: DatasheetWindow

	func _unhandled_input(event: InputEvent) -> void:
		var key: InputEventKey = event as InputEventKey
		if key == null or not key.pressed or key.echo:
			return
		if key.keycode == KEY_ESCAPE:
			window.hide()
		else:
			window.key_pressed.emit(key)
		get_viewport().set_input_as_handled()
