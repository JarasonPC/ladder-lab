class_name SheetRenderer
extends Node
## Renders pages of a schematic for export (PNG, PDF): each page at rest on
## white paper, on the sheet chosen by [SheetLayout] with its frame and title
## block ([SheetFrame]), at [constant DPI] dots per inch of the paper.

const G: float = float(SymbolGeometry.GRID)
const DPI: float = 200.0
## Pages rendered in the same frame (each needs a viewport the size of its sheet).
const BATCH: int = 4

## Draw the wire numbers.
var wire_numbers: bool = true
## Draw the current path numbers.
var path_numbers: bool = true
## Texts of the title block: the schematic title, the file name (may be
## empty), and the page title of an untitled page ("Page %d"); the other
## fields come from [member SchematicDocument.title_block].
var title: String = ""
var file_name: String = ""
var untitled_page: String = "Page %d"
## Layouts of the pages rendered last, in the same order.
var layouts: Array[SheetLayout] = []


## Images of pages [param pages] of [param doc] (a coroutine: await it). The
## document itself is not touched; each page is drawn from a copy. Each page
## is drawn twice: first to measure everything it shows (texts too), then on
## the sheet fitted to that.
func render(doc: SchematicDocument, pages: PackedInt32Array) -> Array[Image]:
	var data: Dictionary = DocumentSerializer.to_dict(doc)
	var images: Array[Image] = []
	# Its own list: another rendering may start while this one waits.
	var sheet_layouts: Array[SheetLayout] = []
	var dark_paper: bool = SchematicTheme.dark
	SchematicTheme.use(false)
	for start: int in range(0, pages.size(), BATCH):
		var sheets: Array[Dictionary] = []
		for i: int in range(start, mini(start + BATCH, pages.size())):
			var copy: SchematicDocument = DocumentSerializer.from_dict(data)
			copy.page = pages[i]
			sheets.append(_sheet(copy, doc.pages.size()))
		await RenderingServer.frame_post_draw
		for sheet: Dictionary in sheets:
			_fit(sheet)
		await RenderingServer.frame_post_draw
		for sheet: Dictionary in sheets:
			var viewport: SubViewport = sheet["viewport"]
			var image: Image = viewport.get_texture().get_image()
			if image != null:
				image.convert(Image.FORMAT_RGB8)
			images.append(image)
			sheet_layouts.append(sheet["frame"].layout)
			viewport.queue_free()
	SchematicTheme.use(dark_paper)
	layouts = sheet_layouts
	return images


## A viewport drawing the current page of [param copy], first on a sheet
## around its parts and wires: {"viewport", "view", "frame", "background",
## "content"}.
func _sheet(copy: SchematicDocument, page_count: int) -> Dictionary:
	var viewport: SubViewport = SubViewport.new()
	viewport.transparent_bg = false
	var background: ColorRect = ColorRect.new()
	background.color = SchematicTheme.BACKGROUND
	viewport.add_child(background)
	var content: Node2D = Node2D.new()
	viewport.add_child(content)
	var view: SchematicView = SchematicView.new()
	# Exported sheets show the circuit alone, no keys of the keyboard.
	view.show_keys = false
	view.set_wire_numbers_visible(wire_numbers)
	view.set_path_numbers_visible(path_numbers)
	content.add_child(view)
	var frame: SheetFrame = SheetFrame.new()
	frame.title = title
	var page_title: String = copy.pages[copy.page]
	frame.page_title = tr(page_title) if not page_title.is_empty() else untitled_page % (copy.page + 1)
	frame.page_number = copy.page + 1
	frame.page_count = page_count
	frame.note = file_name
	frame.block = copy.title_block
	frame.date = Time.get_date_string_from_system()
	content.add_child(frame)
	add_child(viewport)
	view.load_document(copy, false)
	var sheet: Dictionary = {"viewport": viewport, "view": view, "frame": frame, "background": background, "content": content}
	# Room for the path numbers above or left of the drawing.
	_place(sheet, SheetLayout.fit(copy.bounds().grow_individual(2.5, 2.5, 1.0, 1.0)))
	return sheet


## Puts [param sheet] on the sheet fitted to all it drew, and draws it again.
func _fit(sheet: Dictionary) -> void:
	var view: SchematicView = sheet["view"]
	_place(sheet, SheetLayout.fit(view.drawn_extent().grow(0.5)))
	for symbol: Node in view.get_children():
		if symbol is CanvasItem:
			(symbol as CanvasItem).queue_redraw()


func _place(sheet: Dictionary, layout: SheetLayout) -> void:
	var k: float = layout.pixels_per_cell(DPI) / G
	var size: Vector2 = layout.sheet.size * G * k
	var viewport: SubViewport = sheet["viewport"]
	viewport.size = Vector2i(size.round())
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	(sheet["background"] as ColorRect).size = size
	var content: Node2D = sheet["content"]
	content.scale = Vector2(k, k)
	content.position = -layout.sheet.position * G * k
	var frame: SheetFrame = sheet["frame"]
	frame.layout = layout
	frame.queue_redraw()
