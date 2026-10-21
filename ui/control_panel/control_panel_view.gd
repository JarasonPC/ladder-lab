class_name ControlPanelView
extends PanelContainer
## The control panel beside the schematic of an industrial control circuit
## while simulating: every control station and switchboard door with push
## buttons, switches or lamps on it, each drawn by a [ControlBoxView] under
## its name and title and fitted to the panel's width, so the circuit is
## operated with the schematic in view; under them the mechanical links of
## the workspace's groups, each a [TravelView] showing where its part is and
## which limit switches it operates. Its title rolls it in to a narrow tab at
## the edge of the window ([SideTab]).

## A push button was pressed (true) or let go (false).
signal button_held(designation: String, pressed: bool)
## A switch was turned over (see [signal ControlBoxView.switch_toggled]).
signal switch_toggled(designation: String, steps: int)
## The title was clicked: the panel rolls in to its tab.
signal roll_requested

var _document: SchematicDocument
var _title: Button
var _note: Label
var _links_caption: Label
var _list: VBoxContainer
var _links: VBoxContainer
var _views: Array[ControlBoxView] = []
## The mechanical links of the simulation, and their views.
var _travels: Array[Travel] = []
var _travel_views: Array[TravelView] = []


func _ready() -> void:
	theme_type_variation = "RightPanel"
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_title = TimingPanel.rollout_button()
	_title.icon = AppTheme.icon("chevron_right", 16)
	_title.pressed.connect(func() -> void: roll_requested.emit())
	column.add_child(_title)
	_note = Label.new()
	_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_note.theme_type_variation = "MutedLabel"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	column.add_child(_list)
	_links_caption = Label.new()
	_links_caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_links_caption.theme_type_variation = "MutedLabel"
	column.add_child(_links_caption)
	_links = VBoxContainer.new()
	_links.add_theme_constant_override("separation", 6)
	column.add_child(_links)
	retranslate()


## Shows the stations and doors of [param doc] (the simulation's copy) and
## the parts its motors move ([param travels], see [member Simulator.travels]).
func set_document(doc: SchematicDocument, travels: Array[Travel] = []) -> void:
	_document = doc
	_travels = travels
	_rebuild()


func retranslate() -> void:
	if _title == null:
		return
	_title.text = tr("Control panel")
	_title.tooltip_text = tr("Roll the control panel in to a tab at the edge of the window")
	_note.text = tr("No push buttons, switches or lamps on a control station or switchboard door yet. Put them there on the workspace in Edit mode.")
	_links_caption.text = tr("Mechanical links")
	_rebuild()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		# Buttons, switches, lamps and the moving parts follow the simulation.
		for view: ControlBoxView in _views:
			view.queue_redraw()
		for travel_view: TravelView in _travel_views:
			travel_view.queue_redraw()


func _rebuild() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_views.clear()
	var panels: Array[ControlBox] = []
	if _document != null:
		panels = _document.control_panels()
	for i: int in panels.size():
		if panels[i].items.is_empty():
			continue
		var caption: Label = Label.new()
		caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		caption.theme_type_variation = "MutedLabel"
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.text = _caption(i)
		_list.add_child(caption)
		var view: ControlBoxView = ControlBoxView.new()
		view.document = _document
		view.box_index = i
		view.simulating = true
		view.button_held.connect(func(designation: String, pressed: bool) -> void: button_held.emit(designation, pressed))
		view.switch_toggled.connect(func(designation: String, steps: int) -> void: switch_toggled.emit(designation, steps))
		var fit: _Fit = _Fit.new()
		fit.add_child(view)
		_list.add_child(fit)
		_views.append(view)
	for child: Node in _links.get_children():
		_links.remove_child(child)
		child.queue_free()
	_travel_views.clear()
	for travel: Travel in _travels:
		var travel_view: TravelView = TravelView.new()
		travel_view.travel = travel
		var group: WorkspaceGroup = _group(travel.name)
		travel_view.title = group.title if group != null else ""
		_links.add_child(travel_view)
		_travel_views.append(travel_view)
	_links_caption.visible = not _travel_views.is_empty()
	_note.visible = _views.is_empty() and _travel_views.is_empty()


## The workspace group named [param group_name], or null.
func _group(group_name: String) -> WorkspaceGroup:
	if _document != null:
		for group: WorkspaceGroup in _document.groups:
			if group.name == group_name:
				return group
	return null


## Name and title of control panel [param index] (a station, or the door of
## a switchboard).
func _caption(index: int) -> String:
	var stations: int = _document.control_boxes.size()
	if index < stations:
		var box: ControlBox = _document.control_boxes[index]
		return "+%s  %s" % [box.name, box.title if not box.title.is_empty() else tr("Control station")]
	return "+%s  %s" % [_document.switchboards[index - stations].name, tr("Door")]


## Shows its one child at its natural size, scaled down to the box's width
## when it is wider (never scaled up), in the middle.
class _Fit extends Container:
	func _init() -> void:
		oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED

	func _child() -> Control:
		return get_child(0) as Control if get_child_count() > 0 else null

	func _scale_of(natural: Vector2) -> float:
		return minf(1.0, size.x / natural.x) if natural.x > 0.0 and size.x > 0.0 else 1.0

	func _get_minimum_size() -> Vector2:
		var child: Control = _child()
		if child == null:
			return Vector2.ZERO
		var natural: Vector2 = child.get_combined_minimum_size()
		return Vector2(0.0, natural.y * _scale_of(natural))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			update_minimum_size()
		elif what == NOTIFICATION_SORT_CHILDREN:
			var child: Control = _child()
			if child == null:
				return
			var natural: Vector2 = child.get_combined_minimum_size()
			var s: float = _scale_of(natural)
			child.scale = Vector2(s, s)
			child.size = natural
			child.position = Vector2((size.x - natural.x * s) * 0.5, 0.0)
