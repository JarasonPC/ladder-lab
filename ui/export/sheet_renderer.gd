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
## Most pixels along a sheet's longer side: large sheets (A1, A0) are
## rendered at fewer dots per inch.
const MAX_PIXELS: float = 8192.0
## Rows of a ladder diagram on one sheet (A4 portrait at about full size).
const LADDER_ROWS: int = 16
## Pages rendered in the same frame (each needs a viewport the size of its sheet).
const BATCH: int = 4
## Width of a switchboard on its sheet, in world pixels.
const SWITCHBOARD_WIDTH: float = 50.0 * G

## Draw the wire numbers.
## Largest paper the sheets go on ("A5" to "A0", see [method SheetLayout.fit]).
var largest_paper: String = SheetLayout.DEFAULT_LARGEST
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
var plc_programs: bool = false
## Layouts of the pages rendered last, in the same order.
var layouts: Array[SheetLayout] = []

## Renders on white paper going on now (sheets and datasheets), and the
## paper shown before the first of them began: renders overlap (the preview
## renders again at every tick), so only the last one to end puts it back.
static var _white_renders: int = 0
static var _shown_dark: bool = false


## Puts [SchematicTheme] on white paper for a render; [method end_white_paper]
## when it is done.
static func begin_white_paper() -> void:
	if _white_renders == 0:
		_shown_dark = SchematicTheme.dark
		SchematicTheme.use(false)
	_white_renders += 1


## Ends a render begun with [method begin_white_paper]: the last one to end
## puts the paper shown back.
static func end_white_paper() -> void:
	_white_renders -= 1
	if _white_renders == 0:
		SchematicTheme.use(_shown_dark)


## What [param doc] has sheets of: {"stations", "switchboards" (one with
## something in it), "workspace" (places or parts)}.
static func available(doc: SchematicDocument) -> Dictionary[String, bool]:
	var fitted: bool = false
	for board: Switchboard in doc.switchboards:
		fitted = fitted or _fitted(board)
	return {
		"stations": not doc.control_boxes.is_empty(),
		"switchboards": fitted,
		"workspace": not doc.floor_plan.is_empty() if doc.residential else not (doc.places().is_empty() and Workspace.field_devices(doc.circuit).is_empty()),
		"plc_programs": not _programs(doc).is_empty(),
	}


## The PLCs of [param doc] with a program, in circuit order.
static func _programs(doc: SchematicDocument) -> Array[Plc]:
	var result: Array[Plc] = []
	for c: CircuitComponent in doc.circuit.get_components():
		if c is Plc and not (c as Plc).program.is_empty():
			result.append(c as Plc)
	return result


## True when something sits on the rails or the door of [param board] (an
## empty enclosure needs no sheet).
static func _fitted(board: Switchboard) -> bool:
	if not board.door.items.is_empty():
		return true
	for rail: CabinetRail in board.rails:
		if not rail.items.is_empty():
			return true
	return false


## What the sheets of an export of [param doc] show, in order: {"kind"
## ("page", or "single_line" for a residential installation, "stations",
## "switchboard", "workspace" or "floor_plan", "parts") and "page",
## "boxes" (see [method StationsSheet.arrange]), "board" or "rows"}. Only
## what [param doc] has: stations, switchboards with something in them, a
## workspace with places or parts.
func sheets(doc: SchematicDocument, pages: PackedInt32Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if schematic:
		if doc.environment == SchematicDocument.Kind.RESIDENTIAL:
			# A residential installation's single-line diagram in place of the pages.
			result.append({"kind": "single_line"})
		else:
			for page: int in pages:
				result.append({"kind": "page", "page": page})
	if stations:
		for boxes: Array in StationsSheet.arrange(doc):
			result.append({"kind": "stations", "boxes": boxes})
	if switchboards:
		for b: int in doc.switchboards.size():
			if _fitted(doc.switchboards[b]):
				result.append({"kind": "switchboard", "board": b})
	if plc_programs:
		for plc: Plc in _programs(doc):
			if plc.program.language == PlcProgram.Language.LAD:
				for rows: Vector2i in PlcLadCanvas.paper_pages(plc.program.rungs[0], LADDER_ROWS):
					result.append({"kind": "plc", "id": plc.id, "rows": rows})
			else:
				result.append({"kind": "plc", "id": plc.id})
	if workspace and available(doc)["workspace"]:
		# A house installation's floor plan in place of the workspace.
		result.append({"kind": "floor_plan" if doc.residential else "workspace"})
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
	begin_white_paper()
	var specs: Array[Dictionary] = sheets(doc, pages)
	# A page alone (a PNG) keeps its number in the schematic; the sheets of a
	# PDF are numbered in turn.
	var single: bool = specs.size() == 1 and specs[0]["kind"] == "page"
	for start: int in range(0, specs.size(), BATCH):
		var batch: Array[Dictionary] = []
		for i: int in range(start, mini(start + BATCH, specs.size())):
			var number: int = int(specs[0]["page"]) if single else i
			batch.append(_sheet(DocumentSerializer.from_dict(data), specs[i], number, doc.pages.size() if single else specs.size()))
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
	end_white_paper()
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
			cabinet.open_ducts = true
			cabinet.size = Vector2(SWITCHBOARD_WIDTH, G)
			content.add_child(cabinet)
			# Laid out again at the scale the width gives.
			cabinet.refresh()
			cabinet.size = cabinet.drawn_size()
			frame.page_title = "+%s  %s" % [board.name, board.title if not board.title.is_empty() else tr("Switchboard")]
			extent = Rect2(Vector2.ZERO, cabinet.size / G)
			if not board.door.items.is_empty():
				# Its door beside it, at the same scale.
				var door: DoorView = DoorView.new()
				door.document = copy
				door.board = spec["board"]
				door.box_index = copy.door_panel(spec["board"])
				door.show_keys = false
				door.enclosure = cabinet.plate_size()
				var k: float = cabinet.drawn_size().x / maxf(cabinet.plate_size().x, 1.0)
				door.size = door.door_size() * k + Vector2(8.0, 8.0)
				door.position = Vector2(cabinet.size.x + 2.0 * G, -4.0)
				content.add_child(door)
				extent = extent.merge(Rect2(door.position / G, door.size / G))
		"plc":
			var plc: Plc = copy.circuit.get_component(spec["id"]) as Plc
			var lad: bool = plc.program.language == PlcProgram.Language.LAD
			var diagram: PlcCanvas = PlcLadCanvas.new() if lad else PlcFbdCanvas.new()
			diagram.paper = true
			if lad:
				(diagram as PlcLadCanvas).paper_rows = spec["rows"]
			# Kept with the sheet: the diagram writes operands through it.
			sheet["plc"] = plc
			diagram.address = plc.address
			diagram.full_scale = plc.full_scale()
			diagram.show_program(plc.program, null)
			diagram.size = diagram.custom_minimum_size
			content.add_child(diagram)
			frame.page_title = "-%s  %s" % [plc.designation, tr("Ladder diagram (LAD)") if lad else tr("Function block diagram (FBD)")]
			extent = Rect2(Vector2.ZERO, diagram.size / G)
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
		"single_line":
			var diagram: SingleLineCanvas = SingleLineCanvas.new()
			diagram.document = copy
			diagram.sheet = true
			var area: Rect2 = diagram.extent()
			diagram.offset = -area.position
			diagram.size = area.size
			content.add_child(diagram)
			frame.page_title = tr("Consumer unit %s") % FloorPlan.UNIT
			extent = Rect2(Vector2.ZERO, diagram.size / G)
		"floor_plan":
			var plan: FloorPlanCanvas = FloorPlanCanvas.new()
			plan.document = copy
			plan.legend = true
			var area: Rect2 = plan.paper_area()
			plan.offset = -area.position * FloorPlanCanvas.PX
			plan.size = area.size * FloorPlanCanvas.PX
			content.add_child(plan)
			frame.page_title = tr("Floor plan")
			extent = Rect2(Vector2.ZERO, plan.size / G)
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
	# A floor plan as large as its paper takes, as plans are printed.
	_place(sheet, SheetLayout.fit(extent, largest_paper, spec["kind"] == "floor_plan"))
	return sheet


## Puts [param sheet] on the sheet fitted to all it drew, and draws it again.
func _fit(sheet: Dictionary) -> void:
	var view: SchematicView = sheet["view"]
	_place(sheet, SheetLayout.fit(view.drawn_extent().grow(0.5), largest_paper))
	for symbol: Node in view.get_children():
		if symbol is CanvasItem:
			(symbol as CanvasItem).queue_redraw()


func _place(sheet: Dictionary, layout: SheetLayout) -> void:
	var dpi: float = minf(DPI, MAX_PIXELS / (maxf(layout.paper_mm.x, layout.paper_mm.y) / SheetLayout.MM_PER_INCH))
	var k: float = layout.pixels_per_cell(dpi) / G
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
