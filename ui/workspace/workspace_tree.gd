class_name WorkspaceTree
extends VBoxContainer
## The tree beside the workspace: every switchboard with its devices and
## terminal strips, every control station with its buttons, switches and
## lamps, every group with its parts, the parts in the field outside groups,
## the cables and what has no place yet. A search field above it filters by name. It
## stays while a switchboard or station is opened, as the map of the workspace.

## An entry was clicked: [param entry] is {"place" ([enum Workspace.Place] or
## -1), "name" (the place's name, ""), "designation" (a device, strip or part
## in the field; "" for the place itself; for a cable its key in "name"),
## "kind" ("place", "device", "strip", "control", "field", "cable", "")}.
signal chosen(entry: Dictionary)
## An entry was right-clicked at [param at] (screen position).
signal menu_requested(entry: Dictionary, at: Vector2)

var document: SchematicDocument
## Name of the opened place, or "=" and the key of the opened cable, shown
## selected ("" for none).
var opened: String = ""

var _search: LineEdit
var _tree: Tree
## Headings rolled in, by their key ("+RA1", "field", "unplaced").
var _collapsed: Dictionary[String, bool] = {}
var _filling: bool = false
## Entry selected in the Tree, opened once its click is over ({} for none).
var _pending: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_search = LineEdit.new()
	_search.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_search.clear_button_enabled = true
	_search.right_icon = AppTheme.icon("search", 16)
	_search.text_changed.connect(func(_text: String) -> void: refresh())
	add_child(_search)
	_tree = Tree.new()
	_tree.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.allow_rmb_select = true
	_tree.item_selected.connect(func() -> void:
		var item: TreeItem = _tree.get_selected()
		if item != null and not _filling:
			# Opened after the Tree's own mouse handling: opening rebuilds the
			# tree, which the Tree refuses in the middle of a click.
			_pending = item.get_metadata(0)
			_choose.call_deferred())
	_tree.item_mouse_selected.connect(func(at: Vector2, button: int) -> void:
		if button != MOUSE_BUTTON_RIGHT:
			return
		# A right click asks for the menu of the entry it selected (the tree
		# is not rebuilt before that) and opens nothing.
		_pending = {}
		var item: TreeItem = _tree.get_selected()
		if item != null:
			menu_requested.emit(item.get_metadata(0), _tree.get_screen_position() + at))
	_tree.item_collapsed.connect(func(item: TreeItem) -> void:
		if _filling:
			return
		var key: String = item.get_meta("key", "")
		if item.collapsed:
			_collapsed[key] = true
		else:
			_collapsed.erase(key))
	add_child(_tree)
	retranslate()


func _choose() -> void:
	var entry: Dictionary = _pending
	_pending = {}
	if not entry.is_empty():
		chosen.emit(entry)


func retranslate() -> void:
	_search.placeholder_text = tr("Find a device…")
	refresh()


## Fills the tree again from [member document].
func refresh() -> void:
	if _tree == null:
		return
	_filling = true
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	if document != null:
		_fill(root)
	_filling = false


func _fill(root: TreeItem) -> void:
	var filter: String = _search.text.strip_edges().to_lower()
	for board: Switchboard in document.switchboards:
		var head: TreeItem = _place(root, Workspace.Place.SWITCHBOARD, board.name, board.title if not board.title.is_empty() else tr("Switchboard"))
		for rail: CabinetRail in board.rails:
			for place: CabinetItem in rail.items:
				var strip: bool = place.kind == CabinetItem.Kind.STRIP
				var c: CircuitComponent = CabinetDevices.device(document.circuit, place.designation)
				var what: String = tr("Terminal strip") if strip else (tr(CabinetPanel.KIND_TITLES[CabinetDevices.kind_of(c)]) if c != null else tr("not in the schematic"))
				_entry(head, "-" + place.designation, what, {"place": Workspace.Place.SWITCHBOARD, "name": board.name, "designation": place.designation, "kind": "strip" if strip else "device"}, filter)
		_finish(head, filter)
	for box: ControlBox in document.control_boxes:
		var head: TreeItem = _place(root, Workspace.Place.STATION, box.name, box.title if not box.title.is_empty() else tr("Control station"))
		for item: ControlBoxItem in box.items:
			var what: String = tr(StationPanel.KIND_TITLES[item.kind])
			if not item.label.is_empty():
				what += " · " + item.label
			if not item.designation.is_empty():
				_entry(head, "-" + item.designation, what, {"place": Workspace.Place.STATION, "name": box.name, "designation": item.designation, "kind": "control"}, filter)
			if not item.lamp.is_empty():
				# The signal lamp inside an illuminated button or switch.
				_entry(head, "-" + item.lamp, tr(StationPanel.KIND_TITLES[ControlBoxItem.Kind.LAMP]), {"place": Workspace.Place.STATION, "name": box.name, "designation": item.lamp, "kind": "control"}, filter)
		_finish(head, filter)
	for group: WorkspaceGroup in document.groups:
		var head: TreeItem = _place(root, Workspace.Place.GROUP, group.name, group.title if not group.title.is_empty() else tr("Group"))
		for member: String in group.members:
			_field(head, member, filter)
		_finish(head, filter)
	var loose: PackedStringArray = PackedStringArray()
	for designation: String in Workspace.field_devices(document.circuit):
		if Workspace.group_of(document, designation) < 0:
			loose.append(designation)
	if not loose.is_empty():
		var head: TreeItem = _heading(root, "field", tr("In the field"))
		for designation: String in loose:
			_field(head, designation, filter)
		_finish(head, filter)
	var cables: Array[Dictionary] = WorkspaceCables.cables(document)
	if not cables.is_empty():
		var head: TreeItem = _heading(root, "cables", tr("Cables"))
		head.set_tooltip_text(0, tr("Worked out from the wiring: the cores between each two places"))
		for cable: Dictionary in cables:
			var item: TreeItem = _entry(head, cable["name"], "%s – %s  (%s)" % [cable["a"], cable["b"], WorkspaceCables.type_text(cable)], {"place": -1, "name": cable["key"], "designation": "", "kind": "cable"}, filter)
			if item != null and opened == "=" + str(cable["key"]):
				item.select(0)
		_finish(head, filter)
	var missing: Array[Dictionary] = Workspace.unplaced(document)
	if not missing.is_empty():
		var head: TreeItem = _heading(root, "unplaced", tr("Unplaced (%d)") % missing.size())
		head.set_tooltip_text(0, tr("Devices and terminal strips not in a switchboard, buttons, switches and lamps not on a control station"))
		for entry: Dictionary in missing:
			var what: String = tr("Terminal strip") if entry["kind"] == "strip" else ""
			_entry(head, "-" + str(entry["designation"]), what, {"place": -1, "name": "", "designation": entry["designation"], "kind": entry["kind"]}, filter)
		_finish(head, filter)


## A place heading: its tile, "+RA1" and its title.
func _place(root: TreeItem, kind: Workspace.Place, place_name: String, title: String) -> TreeItem:
	var item: TreeItem = _heading(root, "+" + place_name, "+%s   %s" % [place_name, title])
	item.set_icon(0, WorkspaceTile.icon(WorkspaceTile.of_place(kind), 18))
	item.set_metadata(0, {"place": kind, "name": place_name, "designation": "", "kind": "place"})
	if place_name == opened:
		item.select(0)
	return item


func _heading(root: TreeItem, key: String, text: String) -> TreeItem:
	var item: TreeItem = _tree.create_item(root)
	item.set_text(0, text)
	item.set_meta("key", key)
	item.set_metadata(0, {"place": -1, "name": "", "designation": "", "kind": ""})
	item.collapsed = _collapsed.has(key)
	return item


func _field(head: TreeItem, designation: String, filter: String) -> void:
	var c: CircuitComponent = Workspace.field_component(document.circuit, designation)
	if c == null:
		return
	var tile: WorkspaceTile.Kind = WorkspaceTile.of_field(Workspace.field_kind(c))
	var item: TreeItem = _entry(head, "-" + designation, tr(WorkspaceCanvas.field_title(tile)), {"place": -1, "name": "", "designation": designation, "kind": "field"}, filter)
	if item != null:
		item.set_icon(0, WorkspaceTile.icon(tile, 16))


## An entry under [param head]; null when [param filter] hides it.
func _entry(head: TreeItem, text: String, what: String, entry: Dictionary, filter: String) -> TreeItem:
	if not filter.is_empty() and not text.to_lower().contains(filter) and not what.to_lower().contains(filter):
		return null
	var item: TreeItem = _tree.create_item(head)
	item.set_text(0, text if what.is_empty() else "%s   %s" % [text, what])
	item.set_metadata(0, entry)
	return item


## While filtering, a heading shows only when something under it (or its own
## name) matches, rolled out.
func _finish(head: TreeItem, filter: String) -> void:
	if filter.is_empty():
		return
	if head.get_child_count() == 0 and not head.get_text(0).to_lower().contains(filter):
		head.free()
	else:
		head.collapsed = false
