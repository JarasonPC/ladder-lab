class_name SheetRenderer
extends Node
## Renders the sheets of an export (PNG, PDF): the pages of the schematic at
## rest, and, as chosen, the control stations ([StationsSheet]), each
## switchboard ([CabinetView]), the workspace ([WorkspaceCanvas]) and the parts
## list ([PartsSheet]), on white paper, each on the sheet chosen by
## [SheetLayout] with its frame and title block ([SheetFrame]), numbered in
## turn, at [constant DPI] dots per inch of the paper.

const G: float = float(SymbolGeometry.GRID)
const DPI: float = 200.0
## Pages rendered in the same frame (each needs a viewport the size of its sheet).
const BATCH: int = 4
## Width of a switchboard on its sheet, in world pixels.
const SWITCHBOARD_WIDTH: float = 50.0 * G

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
## What is exported: the pages asked for, the control stations, every
## switchboard, the workspace, the parts list.
var schematic: bool = true
var stations: bool = false
var switchboards: bool = false
var workspace: bool = false
var parts_list: bool = false
## Layouts of the pages rendered last, in the same order.
var layouts: Array[SheetLayout] = []


## What the sheets of an export of [param doc] show, in order: {"kind"
## ("page", "stations", "switchboard", "workspace", "parts") and "page",
## "boxes" (see [method StationsSheet.arrange]), "board" or "rows"}. Only
## what [param doc] has: stations, switchboards with something in them, a
## workspace with places or parts.
func sheets(doc: SchematicDocument, pages: PackedInt32Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if schematic:
		for page: int in pages:
			result.append({"kind": "page", "page": page})
	if stations:
		for boxes: Array in StationsSheet.arrange(doc):
			result.append({"kind": "stations", "boxes": boxes})
	if switchboards:
		for b: int in doc.switchboards.size():
			# An empty enclosure needs no sheet.
			var fitted: bool = false
			for rail: CabinetRail in doc.switchboards[b].rails:
				fitted = fitted or not rail.items.is_empty()
			if fitted:
				result.append({"kind": "switchboard", "board": b})
	if workspace and not (doc.places().is_empty() and Workspace.field_devices(doc.circuit).is_empty()):
		result.append({"kind": "workspace"})
	if parts_list:
		for rows: Array in PartsSheet.split(PartsList.new().rows(doc)):
			result.append({"kind": "parts", "rows": rows})
	return result


## Images of the sheets of [param doc] ([method sheets] of pages [param
## pages]) (a coroutine: await it). The document itself is not touched; each
## sheet is drawn from a copy. A page of the schematic is drawn twice: first
## to measure everything it shows (texts too), then on the sheet fitted to
## that.
func render(doc: SchematicDocument, pages: PackedInt32Array) -> Array[Image]:
	var data: Dictionary = DocumentSerializer.to_dict(doc)
	var images: Array[Image] = []
	# Its own list: another rendering may start while this one waits.
	var sheet_layouts: Array[SheetLayout] = []
	var dark_paper: bool = SchematicTheme.dark
	SchematicTheme.use(false)
	var specs: Array[Dictionary] = sheets(doc, pages)
	for start: int in range(0, specs.size(), BATCH):
		var batch: Array[Dictionary] = []
		for i: int in range(start, mini(start + BATCH, specs.size())):
			batch.append(_sheet(DocumentSerializer.from_dict(data), specs[i], i, specs.size()))
		await RenderingServer.frame_post_draw
		for sheet: Dictionary in batch:
			if sheet.has("view"):
				_fit(sheet)
		await RenderingServer.frame_post_draw
		for sheet: Dictionary in batch:
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


## A viewport drawing sheet [param spec] (number [param index] of [param
## count]) of [param copy]: {"viewport", "frame", "background", "content",
## and "view" for a page of the schematic, drawn first on a sheet around its
## parts and wires}.
func _sheet(copy: SchematicDocument, spec: Dictionary, index: int, count: int) -> Dictionary:
	var viewport: SubViewport = SubViewport.new()
	viewport.transparent_bg = false
	var background: ColorRect = ColorRect.new()
	background.color = SchematicTheme.BACKGROUND
	viewport.add_child(background)
	var content: Node2D = Node2D.new()
	viewport.add_child(content)
	var frame: SheetFrame = SheetFrame.new()
	frame.title = title
	frame.page_number = index + 1
	frame.page_count = count
	frame.note = file_name
	frame.block = copy.title_block
	frame.date = Time.get_date_string_from_system()
	var sheet: Dictionary = {"viewport": viewport, "frame": frame, "background": background, "content": content}
	var extent: Rect2 = Rect2()
	match spec["kind"]:
		"page":
			copy.page = spec["page"]
			var view: SchematicView = SchematicView.new()
			# Exported sheets show the circuit alone, no keys of the keyboard.
			view.show_keys = false
			view.set_wire_numbers_visible(wire_numbers)
			view.set_path_numbers_visible(path_numbers)
			content.add_child(view)
			var page_title: String = copy.pages[copy.page]
			frame.page_title = tr(page_title) if not page_title.is_empty() else untitled_page % (copy.page + 1)
			sheet["view"] = view
			# Room for the path numbers above or left of the drawing.
			extent = copy.bounds().grow_individual(2.5, 2.5, 1.0, 1.0)
		"stations":
			var boxes: StationsSheet = StationsSheet.new()
			boxes.document = copy
			boxes.placed = spec["boxes"]
			content.add_child(boxes)
			frame.page_title = tr("Control stations")
			extent = boxes.extent()
		"switchboard":
			var board: Switchboard = copy.switchboards[spec["board"]]
			var cabinet: CabinetView = CabinetView.new()
			cabinet.document = copy
			cabinet.board = spec["board"]
			cabinet.size = Vector2(SWITCHBOARD_WIDTH, G)
			content.add_child(cabinet)
			# Laid out again at the scale the width gives.
			cabinet.refresh()
			cabinet.size = cabinet.drawn_size()
			frame.page_title = "+%s  %s" % [board.name, board.title if not board.title.is_empty() else tr("Switchboard")]
			extent = Rect2(Vector2.ZERO, cabinet.size / G)
		"workspace":
			var canvas: WorkspaceCanvas = WorkspaceCanvas.new()
			canvas.document = copy
			canvas.show_keys = false
			var bounds: Rect2 = canvas.bounds().grow(30.0)
			canvas.offset = -bounds.position
			canvas.size = bounds.size
			content.add_child(canvas)
			frame.page_title = tr("Workspace")
			extent = Rect2(Vector2.ZERO, bounds.size / G)
		"parts":
			var table: PartsSheet = PartsSheet.new()
			table.rows = spec["rows"]
			content.add_child(table)
			frame.page_title = tr("Parts list")
			extent = table.extent()
	content.add_child(frame)
	add_child(viewport)
	if sheet.has("view"):
		(sheet["view"] as SchematicView).load_document(copy, false)
	_place(sheet, SheetLayout.fit(extent))
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
