class_name StationPanel
extends HBoxContainer
## One control station of the workspace ([ControlBox]), opened from it: its
## push buttons, switches and signal lamps drawn large by a [ControlBoxView].
## While simulating they operate the circuit and show its lamps. While
## editing, the tools beside it fill the station: click an item to choose its
## device, colour, plate text and a signal lamp inside it (illuminated
## button). Every change is emitted as one undoable edit of the document (see
## [method SchematicEditor.edit_workspace]).

## A push button was pressed (true) or let go (false) on the station.
signal button_held(designation: String, pressed: bool)
## A switch was turned over on the station.
signal switch_toggled(designation: String, steps: int)
## A change of the station: [param change] is called with the document.
signal edit_requested(change: Callable)
## A key should be bound to push button or switch [param designation].
signal key_bind_requested(designation: String)

## English names of [enum ControlBoxItem.Kind] (translated with tr()).
const KIND_TITLES: PackedStringArray = ["Push button", "Switch", "Signal lamp"]
## English name of a switch item showing a rotary cam switch.
const CAM_SWITCH_TITLE: String = "Rotary cam switch"
## English name of what [param item] shows (translated with tr()): its kind,
## a rotary cam switch for a switch item showing one.
static func item_title(doc: SchematicDocument, item: ControlBoxItem) -> String:
	if item.kind == ControlBoxItem.Kind.SWITCH and doc != null and doc.circuit.get_operator(item.designation) is CamSwitch:
		return CAM_SWITCH_TITLE
	return KIND_TITLES[item.kind]


## How large the station is drawn at first (Ctrl+wheel zooms it).
const ZOOM: float = 2.0

## Name of the station shown ([member ControlBox.name]).
var station_name: String = ""
var _document: SchematicDocument
var _editing: bool = false
var _selected_item: int = -1
## Editing tools beside the drawing (Edit mode only).
var _tools: PanelContainer
var _list: VBoxContainer
var _note: Label
var _view: ControlBoxView
var _rebuild_queued: bool = false
var _item_tools: ControlItemTools = ControlItemTools.new()
var _menu: PopupMenu
var _menu_device: String = ""


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(left)
	_note = Label.new()
	_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_note.theme_type_variation = "MutedLabel"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_note)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var zoom_box: ZoomBox = ZoomBox.new()
	zoom_box.zoom = ZOOM
	center.add_child(zoom_box)
	_view = ControlBoxView.new()
	_view.button_held.connect(func(designation: String, pressed: bool) -> void: button_held.emit(designation, pressed))
	_view.switch_toggled.connect(func(designation: String, steps: int) -> void: switch_toggled.emit(designation, steps))
	_view.item_clicked.connect(func(index: int) -> void:
		_selected_item = index
		_rebuild_queued = true)
	_view.item_menu.connect(_open_item_menu)
	_item_tools.edit = func(change: Callable) -> void: edit_requested.emit(change)
	_item_tools.select = func(index: int) -> void: _selected_item = index
	_menu = PopupMenu.new()
	_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_menu.id_pressed.connect(func(_id: int) -> void: key_bind_requested.emit(_menu_device))
	add_child(_menu)
	zoom_box.add_child(_view)
	_tools = PanelContainer.new()
	_tools.theme_type_variation = "RightPanel"
	_tools.custom_minimum_size.x = 300.0
	add_child(_tools)
	var tools_scroll: ScrollContainer = ScrollContainer.new()
	tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tools.add_child(tools_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	tools_scroll.add_child(_list)
	_rebuild()


## Shows station [member station_name] of [param doc]; [param editing]
## offers the editing tools, otherwise it operates the simulation of [param doc].
func set_document(doc: SchematicDocument, editing: bool) -> void:
	_document = doc
	_editing = editing
	if not editing:
		_selected_item = -1
	_rebuild()


## Shows the document again after it was edited (devices renamed, items changed).
func refresh() -> void:
	_rebuild_queued = true


func retranslate() -> void:
	_rebuild()


## Selects the item showing device [param designation] (Edit mode).
func select_device(designation: String) -> void:
	var b: int = _box()
	if b < 0 or not _editing:
		return
	var items: Array[ControlBoxItem] = _document.control_boxes[b].items
	for i: int in items.size():
		if items[i].designation == designation or items[i].lamp == designation:
			_selected_item = i
			_rebuild()
			return


## Right click on item [param index]: bind a key to its button or switch (Edit mode).
func _open_item_menu(index: int) -> void:
	var b: int = _box()
	if not _editing or b < 0 or index >= _document.control_boxes[b].items.size():
		return
	var item: ControlBoxItem = _document.control_boxes[b].items[index]
	if item.designation.is_empty() or not _document.can_have_key(item.designation):
		return
	_menu_device = item.designation
	_menu.clear()
	var key: String = _document.key_bindings.get(item.designation, "")
	_menu.add_item(tr("Bind a key…") + ("  [%s]" % key if not key.is_empty() else ""))
	_menu.reset_size()
	AppTheme.popup_at_mouse(_menu)


func _process(_delta: float) -> void:
	if _rebuild_queued:
		_rebuild_queued = false
		_rebuild()
	if not _editing and is_visible_in_tree():
		# Buttons, switches and lamps follow the simulation.
		_view.queue_redraw()


## Index of the station shown, -1 when the document has none of that name.
func _box() -> int:
	if _document == null:
		return -1
	for b: int in _document.control_boxes.size():
		if _document.control_boxes[b].name == station_name:
			return b
	return -1


func _rebuild() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var b: int = _box()
	_tools.visible = _editing and b >= 0
	_view.document = _document
	_view.box_index = b
	_view.simulating = not _editing
	if b < 0:
		_note.visible = false
		_view.update_minimum_size()
		_view.queue_redraw()
		return
	var box: ControlBox = _document.control_boxes[b]
	_item_tools.document = _document
	_item_tools.panel = b
	_item_tools.list = _list
	_item_tools.editing = _editing
	if _selected_item >= box.items.size():
		_selected_item = -1
	_view.selected = _selected_item
	_view.update_minimum_size()
	_view.queue_redraw()
	_note.visible = box.items.is_empty()
	_note.text = tr("No push buttons, switches or lamps on this station yet.") if _editing else tr("No push buttons, switches or lamps on this station yet. Add them in Edit mode.")
	if not _editing:
		return
	var tools: ControlItemTools = _item_tools
	tools.make_caption(_list, tr("Text on the station"))
	_list.add_child(tools.make_text_field(box.title, tr("Text on the station"), func(text: String) -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.set_control_box(b, text, box.columns))))
	tools.make_caption(_list, tr("Items in a row"))
	var columns: OptionButton = tools.make_option(_list)
	for n: int in range(1, ControlBox.MAX_COLUMNS + 1):
		columns.add_icon_item(AppTheme.icon("columns"), str(n))
	columns.select(box.columns - 1)
	columns.item_selected.connect(func(k: int) -> void:
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.set_control_box(b, box.title, k + 1)))
	tools.add_buttons()
	tools.add_all_button(tr("Put every push button, switch and signal lamp that is not on a station yet on this one"))
	if _selected_item >= 0:
		_list.add_child(HSeparator.new())
		tools.item_editor(_selected_item)
