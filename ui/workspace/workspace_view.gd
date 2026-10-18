class_name WorkspaceView
extends VBoxContainer
## The workspace (Schematic | Workspace in the toolbar): a bar with the tools
## above the [WorkspaceCanvas], or above the switchboard, control station or
## cable opened from it ([CabinetPanel], [StationPanel], [CablePanel]), which then takes the
## canvas's room. Its [WorkspaceTree] (put beside it by the main window)
## stays meanwhile, as the map. A right click offers more: open in a new
## window, rename, delete; in Edit mode places are added here. Every change
## is emitted as one undoable edit of the document.

## A change of the workspace or a station: [param change] is called with the document.
signal edit_requested(change: Callable)
## A change of a switchboard (may relabel terminals on the drawing).
signal cabinet_edit_requested(change: Callable)
signal button_held(designation: String, pressed: bool)
signal switch_toggled(designation: String)
signal operate_requested(designation: String)
## Place [param place_name] should open in a window of its own.
signal window_requested(kind: Workspace.Place, place_name: String)
## Part [param designation] should be shown in the schematic.
signal schematic_requested(designation: String)
## A key should be bound to push button or switch [param designation].
signal key_bind_requested(designation: String)

enum MenuId { OPEN, WINDOW, RENAME, DELETE, SCHEMATIC, LEAVE_GROUP, ADD_SWITCHBOARD, ADD_STATION, ADD_GROUP, LINK, BIND_KEY }

var tree: WorkspaceTree
var canvas: WorkspaceCanvas
var _document: SchematicDocument
var _editing: bool = false
## The opened place: its kind and name ("" while the canvas shows).
var _opened_kind: Workspace.Place = Workspace.Place.SWITCHBOARD
var _opened: String = ""
## Key of the opened cable ("" for none, see [WorkspaceCables]).
var _opened_cable: String = ""
var _panel: Control
var _body: Control
var _bar: HBoxContainer
var _menu: PopupMenu
## What the menu was opened on, and where (workspace position).
var _menu_entry: Dictionary = {}
var _menu_at: Vector2 = Vector2.ZERO
var _rename_dialog: ConfirmationDialog
var _rename_name: LineEdit
var _rename_title: LineEdit
var _rename_error: Label
var _rename_labels: Array[Label] = []
var _renaming: Dictionary = {}
var _fit_pending: bool = true
var _link_dialog: ConfirmationDialog
var _link_grid: GridContainer
var _link_note: Label
## Group whose link the dialog edits, and the controls of each field.
var _linking: String = ""
var _link_fields: Dictionary[String, Control] = {}


func _init() -> void:
	tree = WorkspaceTree.new()
	tree.chosen.connect(_on_tree_chosen)
	tree.menu_requested.connect(func(entry: Dictionary, at: Vector2) -> void: _open_menu(entry, Vector2.ZERO, at))


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var bar: PanelContainer = PanelContainer.new()
	bar.theme_type_variation = "PageBar"
	add_child(bar)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 4)
	_bar.custom_minimum_size.y = 30.0
	bar.add_child(_bar)
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.clip_contents = true
	add_child(_body)
	canvas = WorkspaceCanvas.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.open_requested.connect(func(kind: Workspace.Place, place_name: String) -> void: open(kind, place_name))
	canvas.cable_requested.connect(open_cable)
	canvas.menu_requested.connect(func(item: Dictionary, at: Vector2) -> void:
		_open_menu(_entry_of(item), at, get_viewport().get_mouse_position()))
	canvas.edit_requested.connect(func(change: Callable) -> void: edit_requested.emit(change))
	canvas.resized.connect(func() -> void:
		if _fit_pending and canvas.size.x > 10.0:
			_fit_pending = false
			canvas.fit())
	_body.add_child(canvas)
	_menu = PopupMenu.new()
	_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_menu.id_pressed.connect(_on_menu)
	add_child(_menu)
	_build_rename_dialog()
	_build_link_dialog()
	_update_bar()


## Shows the workspace of [param doc]; [param editing] lets it be changed,
## otherwise the opened station or switchboard operates the simulation.
## [param fit] shows everything again (a new schematic).
func set_document(doc: SchematicDocument, editing: bool, fit: bool = false) -> void:
	_document = doc
	_editing = editing
	canvas.document = doc
	canvas.editing = editing
	tree.document = doc
	if fit:
		canvas.selected = ""
		if canvas.size.x > 10.0:
			canvas.fit()
		else:
			_fit_pending = true
	canvas.invalidate()
	if not _opened.is_empty() and _index(_opened_kind, _opened) < 0:
		close()
	if not _opened_cable.is_empty() and _cable(_opened_cable).is_empty():
		close()
	if _panel != null:
		_panel.call("set_document", doc, editing)
	refresh()


## Shows the document again after an edit.
func refresh() -> void:
	canvas.invalidate()
	if not _opened_cable.is_empty() and _cable(_opened_cable).is_empty():
		close()
		return
	tree.opened = _opened if _opened_cable.is_empty() else "=" + _opened_cable
	tree.refresh()
	if _panel != null:
		_panel.call("refresh")
	_update_bar()


func retranslate() -> void:
	tree.retranslate()
	if _panel != null:
		_panel.call("retranslate")
	_retranslate_dialog()
	_update_bar()
	canvas.queue_redraw()


## Where the parts moved by motors are (group name -> 0-1), while simulating.
func show_travels(positions: Dictionary[String, float]) -> void:
	if positions != canvas.travel_positions:
		canvas.travel_positions = positions
		canvas.queue_redraw()


## Voltage reach of the last simulation step, for an opened switchboard.
func show_step(result: StepResult) -> void:
	if _panel is CabinetPanel:
		(_panel as CabinetPanel).show_step(result)


## Opens switchboard or station [param place_name] in place of the canvas.
## [param designation] picks the place of that device in it (Edit mode).
func open(kind: Workspace.Place, place_name: String, designation: String = "", item_kind: String = "") -> void:
	if kind == Workspace.Place.GROUP or _index(kind, place_name) < 0:
		return
	if _opened != place_name or _panel == null:
		close()
		_opened_kind = kind
		_opened = place_name
		_panel = make_panel(kind, place_name)
		_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		forward_panel(_panel, self)
		_body.add_child(_panel)
		_panel.call("set_document", _document, _editing)
		canvas.visible = false
		canvas.selected = "+" + place_name
	if not designation.is_empty():
		if _panel is StationPanel:
			(_panel as StationPanel).select_device(designation)
		elif _panel is CabinetPanel:
			(_panel as CabinetPanel).select_item(CabinetItem.Kind.STRIP if item_kind == "strip" else CabinetItem.Kind.DEVICE, designation)
	refresh()


## Lists the cores of cable [param key] ("+RA1|+ST1") in place of the canvas.
func open_cable(key: String) -> void:
	if _cable(key).is_empty():
		return
	close()
	_opened_cable = key
	var cores: CablePanel = CablePanel.new()
	cores.cable_key = key
	_panel = cores
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(_panel)
	cores.set_document(_document, _editing)
	canvas.visible = false
	canvas.selected = "=" + key
	refresh()


## Shows the canvas again in place of the opened switchboard, station or cable.
func close() -> void:
	if _panel != null:
		_body.remove_child(_panel)
		_panel.queue_free()
		_panel = null
	_opened = ""
	_opened_cable = ""
	if canvas != null:
		canvas.visible = true
	if tree != null and is_inside_tree():
		refresh()


func is_open() -> bool:
	return not _opened.is_empty() or not _opened_cable.is_empty()


## Cable [param key] of the document shown, {} for none.
func _cable(key: String) -> Dictionary:
	for cable: Dictionary in canvas.cables():
		if cable["key"] == key:
			return cable
	return {}


## The panel that opens switchboard or station [param place_name].
static func make_panel(kind: Workspace.Place, place_name: String) -> Control:
	if kind == Workspace.Place.SWITCHBOARD:
		var board: CabinetPanel = CabinetPanel.new()
		board.board_name = place_name
		return board
	var station: StationPanel = StationPanel.new()
	station.station_name = place_name
	return station


## Passes the signals of [param panel] (see [method make_panel]) on as those
## of the same name of [param target]; a switchboard's edits as its
## cabinet_edit_requested.
static func forward_panel(panel: Control, target: Object) -> void:
	if panel is CabinetPanel:
		panel.connect("edit_requested", func(change: Callable) -> void: target.emit_signal("cabinet_edit_requested", change))
		panel.connect("operate_requested", func(designation: String) -> void: target.emit_signal("operate_requested", designation))
	else:
		panel.connect("edit_requested", func(change: Callable) -> void: target.emit_signal("edit_requested", change))
		panel.connect("key_bind_requested", func(designation: String) -> void: target.emit_signal("key_bind_requested", designation))
		panel.connect("button_held", func(designation: String, pressed: bool) -> void: target.emit_signal("button_held", designation, pressed))
		panel.connect("switch_toggled", func(designation: String) -> void: target.emit_signal("switch_toggled", designation))


func _index(kind: Workspace.Place, place_name: String) -> int:
	if _document == null:
		return -1
	var list: Array = _document.switchboards if kind == Workspace.Place.SWITCHBOARD else (_document.control_boxes if kind == Workspace.Place.STATION else _document.groups)
	for i: int in list.size():
		if list[i].get("name") == place_name:
			return i
	return -1


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_visible_in_tree():
		return
	if key.keycode == KEY_ESCAPE and is_open():
		close()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_DELETE and _editing and not is_open() and canvas.selected.begins_with("+"):
		for item: Dictionary in canvas.items():
			if item["key"] == canvas.selected:
				_delete(_entry_of(item))
				get_viewport().set_input_as_handled()
				return


# --- Bar --------------------------------------------------------------------------------

func _update_bar() -> void:
	if _bar == null:
		return
	for child: Node in _bar.get_children():
		_bar.remove_child(child)
		child.queue_free()
	if not _opened_cable.is_empty():
		var cable: Dictionary = _cable(_opened_cable)
		var back_to: Button = _tool("chevron_left", tr("Back to the workspace") + "  (Esc)")
		back_to.pressed.connect(close)
		_bar.add_child(back_to)
		var cable_label: Label = _label(str(cable.get("name", "")))
		cable_label.add_theme_font_override("font", AppTheme.bold_font())
		_bar.add_child(cable_label)
		var ends: Label = _label("%s – %s" % [cable.get("a", ""), cable.get("b", "")])
		ends.theme_type_variation = "MutedLabel"
		ends.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bar.add_child(ends)
		if _editing:
			var rename_cable: Button = _tool("edit", tr("Rename…"))
			rename_cable.pressed.connect(func() -> void: _rename({"place": -1, "name": _opened_cable, "designation": "", "kind": "cable"}))
			_bar.add_child(rename_cable)
		var shut_cable: Button = _tool("close", tr("Back to the workspace") + "  (Esc)")
		shut_cable.pressed.connect(close)
		_bar.add_child(shut_cable)
		return
	if is_open():
		var place: RefCounted = _place_of(_opened_kind, _opened)
		var back: Button = _tool("chevron_left", tr("Back to the workspace") + "  (Esc)")
		back.pressed.connect(close)
		_bar.add_child(back)
		var icon: TextureRect = TextureRect.new()
		icon.texture = WorkspaceTile.icon(WorkspaceTile.of_place(_opened_kind), 20)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		_bar.add_child(icon)
		var name_label: Label = _label("+" + _opened)
		name_label.add_theme_font_override("font", AppTheme.bold_font())
		_bar.add_child(name_label)
		var title: String = str(place.get("title")) if place != null else ""
		var title_label: Label = _label(title if not title.is_empty() else (tr("Switchboard") if _opened_kind == Workspace.Place.SWITCHBOARD else tr("Control station")))
		title_label.theme_type_variation = "MutedLabel"
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bar.add_child(title_label)
		if _editing:
			var rename: Button = _tool("edit", tr("Rename…"))
			rename.pressed.connect(func() -> void: _rename({"place": _opened_kind, "name": _opened}))
			_bar.add_child(rename)
		var window: Button = _tool("window", tr("Open in a new window"))
		window.pressed.connect(func() -> void:
			var kind: Workspace.Place = _opened_kind
			var place_name: String = _opened
			close()
			window_requested.emit(kind, place_name))
		_bar.add_child(window)
		var shut: Button = _tool("close", tr("Back to the workspace") + "  (Esc)")
		shut.pressed.connect(close)
		_bar.add_child(shut)
		return
	if _editing:
		var adds: Array = [[Workspace.Place.SWITCHBOARD, tr("Switchboard"), tr("Add a switchboard")], [Workspace.Place.STATION, tr("Control station"), tr("Add a control station")], [Workspace.Place.GROUP, tr("Group"), tr("Add a group: a frame for parts in the field that belong together, e.g. a gate with its motor and limit switches")]]
		for add: Array in adds:
			var button: Button = Button.new()
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			button.focus_mode = Control.FOCUS_NONE
			button.theme_type_variation = "ToolButton"
			button.icon = AppTheme.icon("plus")
			button.text = add[1]
			button.tooltip_text = add[2]
			var kind: Workspace.Place = add[0]
			button.pressed.connect(func() -> void: _add(kind, null))
			_bar.add_child(button)
	var hint: Label = _label(tr("Click a switchboard, control station or cable to open it, right click for more."))
	hint.tooltip_text = tr("Wheel zooms, right or middle drag pans.") + ("\n" + tr("Drag parts into a group's frame to put them in it.") if _editing else "")
	hint.mouse_filter = Control.MOUSE_FILTER_PASS
	hint.theme_type_variation = "MutedLabel"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.clip_text = true
	_bar.add_child(hint)
	var fit: Button = _tool("fit", tr("Show everything"))
	fit.pressed.connect(canvas.fit)
	_bar.add_child(fit)


func _label(text: String) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _tool(icon_name: String, tooltip: String) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = "ToolButton"
	button.icon = AppTheme.icon(icon_name)
	button.tooltip_text = tooltip
	return button


# --- Tree, menu, editing -----------------------------------------------------------------

## Entry like those of [signal WorkspaceTree.chosen] for a canvas item.
func _entry_of(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	match item["kind"]:
		"switchboard":
			return {"place": Workspace.Place.SWITCHBOARD, "name": item["name"], "designation": "", "kind": "place"}
		"station":
			return {"place": Workspace.Place.STATION, "name": item["name"], "designation": "", "kind": "place"}
		"group":
			return {"place": Workspace.Place.GROUP, "name": item["name"], "designation": "", "kind": "place"}
		"cable":
			return {"place": -1, "name": item["name"], "designation": "", "kind": "cable"}
	return {"place": -1, "name": "", "designation": item["name"], "kind": "field"}


func _on_tree_chosen(entry: Dictionary) -> void:
	var place: int = entry.get("place", -1)
	if place == Workspace.Place.SWITCHBOARD or place == Workspace.Place.STATION:
		open(place, entry["name"], entry["designation"], entry["kind"])
	elif place == Workspace.Place.GROUP:
		close()
		canvas.show_item("+" + str(entry["name"]))
	elif entry.get("kind", "") == "field":
		close()
		canvas.show_item("-" + str(entry["designation"]))
	elif entry.get("kind", "") == "cable":
		open_cable(entry["name"])


## The menu for [param entry] ({} on empty paper at workspace position
## [param at]), shown at screen position [param screen].
func _open_menu(entry: Dictionary, at: Vector2, screen: Vector2) -> void:
	_menu_entry = entry
	_menu_at = at
	_menu.clear()
	var place: int = entry.get("place", -1)
	var kind: String = entry.get("kind", "")
	if kind == "place" and place != Workspace.Place.GROUP:
		_menu.add_item(tr("Open"), MenuId.OPEN)
		_menu.add_item(tr("Open in a new window"), MenuId.WINDOW)
		_menu.set_item_tooltip(_menu.item_count - 1, tr("Shows it in a window of its own, e.g. on a second monitor; while simulating, it works there too"))
	if kind == "control" and _editing and _document.can_have_key(entry["designation"]):
		var key: String = _document.key_bindings.get(entry["designation"], "")
		_menu.add_item(tr("Bind a key…") + ("  [%s]" % key if not key.is_empty() else ""), MenuId.BIND_KEY)
	if kind == "cable":
		_menu.add_item(tr("Show the cores"), MenuId.OPEN)
		if _editing:
			_menu.add_item(tr("Rename…"), MenuId.RENAME)
	if kind == "field":
		_menu.add_item(tr("Show in the schematic"), MenuId.SCHEMATIC)
		if _editing and Workspace.group_of(_document, entry["designation"]) >= 0:
			_menu.add_item(tr("Take out of the group"), MenuId.LEAVE_GROUP)
	if _editing and kind == "place":
		if _menu.item_count > 0:
			_menu.add_separator()
		if place == Workspace.Place.GROUP:
			_menu.add_item(tr("Mechanical link…"), MenuId.LINK)
			_menu.set_item_tooltip(_menu.item_count - 1, tr("A motor of the group moves a part (e.g. the gate) that operates the group's limit switches while simulating"))
		_menu.add_item(tr("Rename…"), MenuId.RENAME)
		_menu.add_item(tr("Delete"), MenuId.DELETE)
		_menu.set_item_tooltip(_menu.item_count - 1, tr("A switchboard's devices and a station's buttons lose their place, a group's parts stay where they are (Ctrl+Z brings it back)"))
	if _editing and entry.is_empty():
		_menu.add_item(tr("Add a switchboard here"), MenuId.ADD_SWITCHBOARD)
		_menu.add_item(tr("Add a control station here"), MenuId.ADD_STATION)
		_menu.add_item(tr("Add a group here"), MenuId.ADD_GROUP)
	if _menu.item_count == 0:
		return
	_menu.reset_size()
	_menu.popup_on_parent(Rect2i(Vector2i(screen), Vector2i.ZERO))


func _on_menu(id: int) -> void:
	var entry: Dictionary = _menu_entry
	match id:
		MenuId.OPEN:
			if entry["kind"] == "cable":
				open_cable(entry["name"])
			else:
				open(entry["place"], entry["name"])
		MenuId.WINDOW:
			if _opened == entry["name"]:
				close()
			window_requested.emit(entry["place"], entry["name"])
		MenuId.RENAME:
			_rename(entry)
		MenuId.DELETE:
			_delete(entry)
		MenuId.SCHEMATIC:
			schematic_requested.emit(entry["designation"])
		MenuId.LEAVE_GROUP:
			var designation: String = entry["designation"]
			var at: Vector2 = Workspace.field_positions(_document).get(designation, Vector2.ZERO)
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.place_field_device(designation, at, -1))
		MenuId.ADD_SWITCHBOARD:
			_add(Workspace.Place.SWITCHBOARD, _menu_at.snappedf(WorkspaceCanvas.SNAP))
		MenuId.ADD_STATION:
			_add(Workspace.Place.STATION, _menu_at.snappedf(WorkspaceCanvas.SNAP))
		MenuId.ADD_GROUP:
			_add(Workspace.Place.GROUP, _menu_at.snappedf(WorkspaceCanvas.SNAP))
		MenuId.LINK:
			_open_link(entry["name"])
		MenuId.BIND_KEY:
			key_bind_requested.emit(entry["designation"])


## Adds a place of [param kind] at [param at] (a free spot when null) and shows it.
func _add(kind: Workspace.Place, at: Variant) -> void:
	if _document == null:
		return
	var place_name: String = _document.next_place_name(kind)
	match kind:
		Workspace.Place.SWITCHBOARD:
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.add_switchboard(at))
		Workspace.Place.STATION:
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.add_control_box("", 1, at))
		Workspace.Place.GROUP:
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.add_group(at))
	close()
	if at == null:
		canvas.show_item("+" + place_name)
	else:
		canvas.selected = "+" + place_name
		canvas.queue_redraw()


func _delete(entry: Dictionary) -> void:
	var index: int = _index(entry["place"], entry["name"])
	if index < 0:
		return
	var kind: Workspace.Place = entry["place"]
	if _opened == entry["name"]:
		close()
	canvas.selected = ""
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.remove_place(kind, index))


func _place_of(kind: Workspace.Place, place_name: String) -> RefCounted:
	var index: int = _index(kind, place_name)
	if index < 0:
		return null
	if kind == Workspace.Place.SWITCHBOARD:
		return _document.switchboards[index]
	return _document.control_boxes[index] if kind == Workspace.Place.STATION else _document.groups[index]


func _build_rename_dialog() -> void:
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var column: VBoxContainer = VBoxContainer.new()
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	column.add_child(grid)
	for i: int in 2:
		var caption: Label = Label.new()
		caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		grid.add_child(caption)
		_rename_labels.append(caption)
		var field: LineEdit = LineEdit.new()
		field.custom_minimum_size = Vector2(260, 0)
		grid.add_child(field)
		_rename_dialog.register_text_enter(field)
		if i == 0:
			_rename_name = field
		else:
			_rename_title = field
	_rename_error = Label.new()
	_rename_error.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_rename_error.add_theme_color_override("font_color", AppTheme.danger)
	_rename_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_rename_error)
	_rename_dialog.add_child(column)
	_rename_dialog.confirmed.connect(_apply_rename)
	add_child(_rename_dialog)
	_retranslate_dialog()


func _retranslate_dialog() -> void:
	if _rename_dialog == null:
		return
	_rename_dialog.title = tr("Rename")
	_rename_dialog.ok_button_text = tr("Rename")
	_rename_dialog.cancel_button_text = tr("Cancel")
	_rename_labels[0].text = tr("Designation")
	_rename_labels[1].text = tr("Text")
	_rename_title.placeholder_text = tr("e.g. Gate, inside")


func _rename(entry: Dictionary) -> void:
	var cable: bool = entry.get("kind", "") == "cable"
	var place: RefCounted = null if cable else _place_of(entry["place"], entry["name"])
	if place == null and (not cable or _cable(entry["name"]).is_empty()):
		return
	_renaming = entry
	# A cable has a name only.
	_rename_labels[1].visible = not cable
	_rename_title.visible = not cable
	_rename_labels[0].text = tr("Name") if cable else tr("Designation")
	_rename_name.text = str(_cable(entry["name"])["name"]) if cable else "+" + str(place.get("name"))
	_rename_title.text = "" if cable else str(place.get("title"))
	_rename_error.text = ""
	_rename_error.visible = false
	_rename_dialog.reset_size()
	_rename_dialog.popup_centered()
	_rename_name.grab_focus()
	_rename_name.select_all()


func _apply_rename() -> void:
	var entry: Dictionary = _renaming
	if entry.get("kind", "") == "cable":
		_apply_cable_rename(entry["name"], _rename_name.text.strip_edges())
		return
	var index: int = _index(entry["place"], entry["name"])
	if index < 0:
		return
	var kind: Workspace.Place = entry["place"]
	var new_name: String = _rename_name.text.strip_edges().trim_prefix("+")
	var new_title: String = _rename_title.text.strip_edges()
	var probe: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(_document))
	if probe == null or not probe.rename_place(kind, index, new_name, new_title):
		_rename_error.text = tr("Use a designation without spaces or colons that no other switchboard, station or group has.")
		_rename_error.visible = true
		_rename_dialog.reset_size()
		_rename_dialog.popup_centered.call_deferred()
		return
	var reopen: bool = _opened == entry["name"]
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.rename_place(kind, index, new_name, new_title))
	if canvas.selected == "+" + str(entry["name"]):
		canvas.selected = "+" + new_name
	if reopen:
		_opened = new_name
		if _panel is CabinetPanel:
			(_panel as CabinetPanel).board_name = new_name
		elif _panel is StationPanel:
			(_panel as StationPanel).station_name = new_name
	refresh()


func _apply_cable_rename(key: String, new_name: String) -> void:
	if _cable(key).get("name", "") == new_name:
		return
	var probe: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(_document))
	if probe == null or not probe.rename_cable(key, new_name):
		_rename_error.text = tr("Use a name without spaces or colons that no other cable has.")
		_rename_error.visible = true
		_rename_dialog.reset_size()
		_rename_dialog.popup_centered.call_deferred()
		return
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.rename_cable(key, new_name))
	refresh()


# --- Mechanical link -----------------------------------------------------------------------

func _build_link_dialog() -> void:
	_link_dialog = ConfirmationDialog.new()
	_link_dialog.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_link_note = Label.new()
	_link_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_link_note.theme_type_variation = "MutedLabel"
	_link_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_link_note.custom_minimum_size.x = 380.0
	column.add_child(_link_note)
	_link_grid = GridContainer.new()
	_link_grid.columns = 2
	_link_grid.add_theme_constant_override("h_separation", 12)
	column.add_child(_link_grid)
	_link_dialog.add_child(column)
	_link_dialog.confirmed.connect(_apply_link)
	add_child(_link_dialog)


## Asks how group [param group_name]'s part moves: which motor drives it,
## how long it takes end to end, where it starts and where its limit switches are.
func _open_link(group_name: String) -> void:
	var index: int = _index(Workspace.Place.GROUP, group_name)
	if index < 0:
		return
	var group: WorkspaceGroup = _document.groups[index]
	_linking = group_name
	_link_fields.clear()
	for child: Node in _link_grid.get_children():
		_link_grid.remove_child(child)
		child.queue_free()
	_link_dialog.title = tr("Mechanical link") + " +" + group_name
	_link_dialog.ok_button_text = tr("OK")
	_link_dialog.cancel_button_text = tr("Cancel")
	_link_note.text = tr("The motor moves the part from one end (0 %) to the other (100 %): turning forwards (clockwise) towards 100 %, backwards towards 0 %. A limit switch at an end is operated while the part is there, one in between while the part passes it.")
	var motors: PackedStringArray = PackedStringArray([""])
	var switches: PackedStringArray = PackedStringArray()
	for member: String in group.members:
		var kind: Workspace.Field = Workspace.field_kind(Workspace.field_component(_document.circuit, member))
		if kind == Workspace.Field.MOTOR:
			motors.append(member)
		elif kind == Workspace.Field.LIMIT_SWITCH:
			switches.append(member)
	var drive: OptionButton = OptionButton.new()
	drive.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for motor: String in motors:
		drive.add_item(tr("None") if motor.is_empty() else "-" + motor)
	drive.select(maxi(motors.find(group.drive), 0))
	drive.set_meta("choices", motors)
	_link_row(tr("Motor"), drive)
	_link_fields["drive"] = drive
	var seconds: SpinBox = _spin(0.1, 3600.0, 0.1, group.travel_time, " s")
	_link_row(tr("End to end in"), seconds)
	_link_fields["time"] = seconds
	var start: SpinBox = _spin(0.0, 100.0, 1.0, group.start * 100.0, " %")
	_link_row(tr("Starts at"), start)
	_link_fields["start"] = start
	for i: int in switches.size():
		var designation: String = switches[i]
		# New switches: the first at 0 %, the next at 100 %.
		var where: float = group.stops.get(designation, 0.0 if i == 0 else 1.0)
		var used: CheckBox = CheckBox.new()
		used.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		used.text = "-" + designation
		used.button_pressed = group.stops.has(designation) or group.drive.is_empty()
		_link_grid.add_child(used)
		var at: SpinBox = _spin(0.0, 100.0, 1.0, where * 100.0, " %")
		_link_grid.add_child(at)
		_link_fields["sq:" + designation] = used
		_link_fields["at:" + designation] = at
	if motors.size() < 2:
		_link_note.text = tr("Put a motor of the field into this group first (drag it into the frame).")
	_link_dialog.reset_size()
	_link_dialog.popup_centered()


func _link_row(caption: String, field: Control) -> void:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = caption
	_link_grid.add_child(label)
	_link_grid.add_child(field)


func _spin(lowest: float, highest: float, step: float, value: float, suffix: String) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = lowest
	spin.max_value = highest
	spin.step = step
	spin.value = value
	spin.suffix = suffix.strip_edges()
	spin.custom_minimum_size.x = 120.0
	return spin


func _apply_link() -> void:
	var index: int = _index(Workspace.Place.GROUP, _linking)
	if index < 0 or not _link_fields.has("drive"):
		return
	var drive_field: OptionButton = _link_fields["drive"] as OptionButton
	var motors: PackedStringArray = drive_field.get_meta("choices")
	var drive: String = motors[maxi(drive_field.selected, 0)]
	var seconds: float = (_link_fields["time"] as SpinBox).value
	var start: float = (_link_fields["start"] as SpinBox).value / 100.0
	var stops: Dictionary = {}
	for key: String in _link_fields:
		if key.begins_with("sq:") and (_link_fields[key] as CheckBox).button_pressed:
			var designation: String = key.substr(3)
			stops[designation] = (_link_fields["at:" + designation] as SpinBox).value / 100.0
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.set_group_link(index, drive, seconds, start, stops))
