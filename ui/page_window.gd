class_name PageWindow
extends Window
## One page of the schematic in a window of its own (e.g. on a second
## monitor), beside the page the main window shows. It follows the main view:
## the same schematic and the same simulation, so buttons and switches
## operated here act on the running circuit; edits made in the main window
## show up here. Right or middle drag pans, the wheel zooms; a page connector
## clicked while simulating shows its partner page in this window.

## A key was pressed in this window (the main window handles the shortcuts).
signal key_pressed(event: InputEventKey)

const SIZE: Vector2 = Vector2(960, 680)

var view: SchematicView
var camera: SchematicCamera
var _source: SchematicView


## A window showing page [param page] of what [param source] shows.
func _init(source: SchematicView, page: int) -> void:
	_source = source
	view = SchematicView.new()
	view.page = page
	visible = false
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	min_size = Vector2i(320, 240)


func _ready() -> void:
	size = Vector2i(SIZE * content_scale_factor)
	add_child(view)
	view.follow(_source)
	view.rebuilt.connect(_update_title)
	view.page_requested.connect(show_page)
	camera = SchematicCamera.new()
	add_child(camera)
	camera.make_current()
	close_requested.connect(queue_free)
	window_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey:
			key_pressed.emit(event as InputEventKey))
	_update_title()
	show()
	# Fit once the window has its size.
	await get_tree().process_frame
	fit()


## Shows page [param index]; with [param focus_id], centred on that component.
func show_page(index: int, focus_id: String = "") -> void:
	if index < 0 or index >= view.document.pages.size():
		return
	view.page = index
	view.rebuild()
	var focus: CircuitComponent = view.document.circuit.get_component(focus_id) if not focus_id.is_empty() else null
	if focus != null:
		camera.look_at_world(view.document.component_body(focus).get_center() * SymbolGeometry.GRID)
	else:
		fit()


## Page [param index] is about to be moved to place [param to]: this window
## goes on showing the page it shows, wherever that one ends up.
func page_moved(index: int, to: int) -> void:
	to = clampi(to, 0, view.document.pages.size() - 1)
	if view.page == index:
		view.page = to
	elif index < view.page and view.page <= to:
		view.page -= 1
	elif to <= view.page and view.page < index:
		view.page += 1


## Page [param index] is about to be deleted: the window showing it closes,
## the others go on showing their pages.
func page_removed(index: int) -> void:
	if view.page == index:
		queue_free()
	elif view.page > index:
		view.page -= 1


## The title in the language now chosen.
func retranslate() -> void:
	_update_title()


## Zooms and moves so the whole page is seen.
func fit() -> void:
	# Path numbers are drawn outside the bounds, above or left of the drawing.
	var b: Rect2 = view.document.bounds(view.page).grow_individual(2.5, 2.5, 0.0, 0.0)
	camera.fit(Rect2(b.position * SymbolGeometry.GRID, b.size * SymbolGeometry.GRID))


## Page number and title, as on the page tabs.
func _update_title() -> void:
	var page_title: String = view.document.pages[view.page]
	var text: String = tr("Page %d") % (view.page + 1) if page_title.is_empty() else "%d  %s" % [view.page + 1, tr(page_title)]
	title = "%s – LadderLab" % text
