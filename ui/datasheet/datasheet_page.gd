class_name DatasheetPage
extends Control
## One page of a datasheet, drawn from its [DatasheetLayout] in points on the
## schematic paper (white for export, dark with the dark paper): texts,
## rules and table shading drawn here, the part's symbol, its function
## diagram and its device front as children. Shown scaled; text is rendered
## for the scale (see [member CanvasItem.oversampling_with_scale]).

var layout: DatasheetLayout
var sheet: Datasheet


func _init(p_sheet: Datasheet, p_layout: DatasheetLayout) -> void:
	sheet = p_sheet
	layout = p_layout
	custom_minimum_size = DatasheetLayout.PAGE
	size = DatasheetLayout.PAGE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	for item: Dictionary in layout.items:
		match item["type"]:
			"symbol":
				_add_symbol(item)
			"diagram":
				_add_diagram(item)
			"front":
				var front: DatasheetFront = DatasheetFront.new(sheet.front)
				front.position = (item["rect"] as Rect2).position
				front.size = (item["rect"] as Rect2).size
				add_child(front)


func _add_symbol(item: Dictionary) -> void:
	var symbol: SchematicSymbol = SymbolFactory.create(sheet.component, Placement.new(Vector2i.ZERO, 0, false))
	symbol.position = item["origin"]
	symbol.scale = Vector2.ONE * float(item["scale"])
	add_child(symbol)


func _add_diagram(item: Dictionary) -> void:
	var rect: Rect2 = item["rect"]
	var diagram: Control
	if sheet.diagram == Datasheet.Diagram.TIMER:
		var timer: TimerDiagram = TimerDiagram.new()
		timer.paper = true
		timer.mode = sheet.timer_mode
		timer.input_name = sheet.control_name
		timer.row_height = DatasheetLayout.TIMER_ROW
		diagram = timer
	else:
		var curve: TripCurveDiagram = TripCurveDiagram.new()
		curve.paper = true
		curve.kind = sheet.trip_kind
		diagram = curve
	diagram.position = rect.position
	diagram.size = rect.size
	add_child(diagram)


## Colour of [param ink] on the paper now in use.
static func color(ink: DatasheetLayout.Ink) -> Color:
	match ink:
		DatasheetLayout.Ink.PAPER:
			return SchematicTheme.BACKGROUND
		DatasheetLayout.Ink.MUTED:
			return SchematicTheme.PATH_TEXT
		DatasheetLayout.Ink.TEAL:
			return SchematicTheme.DESIGNATION
		DatasheetLayout.Ink.RULE:
			return Color(SchematicTheme.TEXT, 0.28)
		DatasheetLayout.Ink.TINT:
			return Color(SchematicTheme.TEXT, 0.045)
	return SchematicTheme.TEXT


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SchematicTheme.BACKGROUND)
	for item: Dictionary in layout.items:
		match item["type"]:
			"text":
				draw_string(DatasheetLayout.font(item["font"]), item["at"], item["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, item["size"], color(item["color"]))
			"box":
				draw_rect(item["rect"], color(item["fill"]))
			"line":
				draw_line(item["from"], item["to"], color(item["color"]), item["width"], true)
