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
## Texts of the title block: the schematic title, the file name (may be
## empty), and the page title of an untitled page ("Page %d").
var title: String = ""
var file_name: String = ""
var untitled_page: String = "Page %d"
var page_caption: String = "Page"
## Layouts of the pages rendered last, in the same order.
var layouts: Array[SheetLayout] = []


## Images of pages [param pages] of [param doc] (a coroutine: await it). The
## document itself is not touched; each page is drawn from a copy.
func render(doc: SchematicDocument, pages: PackedInt32Array) -> Array[Image]:
	var data: Dictionary = DocumentSerializer.to_dict(doc)
	var images: Array[Image] = []
	layouts.clear()
	var dark_paper: bool = SchematicTheme.dark
	SchematicTheme.use(false)
	for start: int in range(0, pages.size(), BATCH):
		var viewports: Array[SubViewport] = []
		for i: int in range(start, mini(start + BATCH, pages.size())):
			var copy: SchematicDocument = DocumentSerializer.from_dict(data)
			copy.page = pages[i]
			viewports.append(_sheet(copy, doc.pages.size()))
		await RenderingServer.frame_post_draw
		for viewport: SubViewport in viewports:
			var image: Image = viewport.get_texture().get_image()
			if image != null:
				image.convert(Image.FORMAT_RGB8)
			images.append(image)
			viewport.queue_free()
	SchematicTheme.use(dark_paper)
	return images


## A viewport drawing the current page of [param copy] on its sheet.
func _sheet(copy: SchematicDocument, page_count: int) -> SubViewport:
	# Room for the path numbers above or left of the drawing.
	var layout: SheetLayout = SheetLayout.fit(copy.bounds().grow_individual(2.5, 2.5, 1.0, 1.0))
	layouts.append(layout)
	var k: float = layout.pixels_per_cell(DPI) / G
	var size: Vector2 = layout.sheet.size * G * k
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(size.round())
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var background: ColorRect = ColorRect.new()
	background.color = SchematicTheme.BACKGROUND
	background.size = size
	viewport.add_child(background)
	var content: Node2D = Node2D.new()
	content.scale = Vector2(k, k)
	content.position = -layout.sheet.position * G * k
	viewport.add_child(content)
	var view: SchematicView = SchematicView.new()
	view.set_wire_numbers_visible(wire_numbers)
	content.add_child(view)
	var frame: SheetFrame = SheetFrame.new()
	frame.layout = layout
	frame.title = title
	var page_title: String = copy.pages[copy.page]
	frame.page_title = tr(page_title) if not page_title.is_empty() else untitled_page % (copy.page + 1)
	frame.page_number = copy.page + 1
	frame.page_count = page_count
	frame.page_caption = page_caption
	var date: String = Time.get_date_string_from_system()
	frame.note = date if file_name.is_empty() else "%s   %s" % [file_name, date]
	content.add_child(frame)
	add_child(viewport)
	view.load_document(copy, false)
	return viewport
