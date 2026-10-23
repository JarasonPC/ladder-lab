class_name InfluencesDialog
extends ConfirmationDialog
## The external influences of ČSN 33 2000-5-51 ([ExternalInfluences]) as a
## table: the groups and their categories, each class a row with a check box,
## its code and what it means. At most one class of a category is ticked (a
## tick takes the other's away); OK gives the ticked ones to the room.

## [param codes] were ticked when OK was pressed (in the order of the list).
signal chosen(codes: PackedStringArray)

var _tree: Tree
var _hint: Label
## The class rows by code.
var _rows: Dictionary[String, TreeItem] = {}


func _init() -> void:
	min_size = Vector2i(620, 460)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_hint = Label.new()
	_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hint.theme_type_variation = "MutedLabel"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 580.0
	column.add_child(_hint)
	_tree = Tree.new()
	_tree.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tree.hide_root = true
	_tree.columns = 2
	_tree.column_titles_visible = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.set_column_expand(0, false)
	_tree.set_column_custom_minimum_width(0, 120)
	_tree.set_column_expand(1, true)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(580, 360)
	_tree.item_edited.connect(_ticked)
	# A click anywhere on a class's row ticks it.
	_tree.item_activated.connect(func() -> void:
		var item: TreeItem = _tree.get_selected()
		if item != null and item.is_editable(0):
			item.set_checked(0, not item.is_checked(0))
			_ticked_item(item))
	column.add_child(_tree)
	confirmed.connect(func() -> void: chosen.emit(ticked()))


## Shows the table with the classes in [param environment] (a room's,
## "AB8, AD4") ticked.
func open(environment: String) -> void:
	title = tr("External influences (ČSN 33 2000-5-51)")
	ok_button_text = tr("OK")
	cancel_button_text = tr("Cancel")
	_hint.text = tr("Tick the influences of the room, at most one class of each; with none ticked the room is normal (N).")
	_tree.set_column_title(0, tr("Code"))
	_tree.set_column_title(1, tr("Meaning"))
	_fill(ExternalInfluences.classes_of(environment))
	popup_centered_clamped(Vector2i(700, 640), 0.9)


## The codes ticked, in the order of the list.
func ticked() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for code: String in _rows:
		if _rows[code].is_checked(0):
			result.append(code)
	return result


func _fill(codes: PackedStringArray) -> void:
	_tree.clear()
	_rows.clear()
	var root: TreeItem = _tree.create_item()
	var first: TreeItem = null
	for group: Dictionary in ExternalInfluences.GROUPS:
		var head: TreeItem = _tree.create_item(root)
		head.set_text(0, group["code"])
		head.set_text(1, tr(group["title"]).to_upper())
		_heading(head, AppTheme.text_muted)
		for category: Dictionary in group["categories"]:
			var classes: Array = category["classes"]
			# A class that is the category itself (AM-4) is one row.
			var lone: bool = classes.size() == 1 and (classes[0][1] as String).is_empty()
			var parent: TreeItem = head
			if not lone:
				parent = _tree.create_item(head)
				parent.set_text(0, category["code"])
				parent.set_text(1, tr(category["title"]))
				_heading(parent, AppTheme.text_muted if classes.is_empty() else Color.TRANSPARENT)
			for entry: Array in classes:
				var item: TreeItem = _tree.create_item(parent)
				item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
				item.set_editable(0, true)
				item.set_text(0, entry[0])
				item.set_text(1, tr(category["title"]) if lone else ExternalInfluences.text(category["code"], entry[1]))
				item.set_checked(0, codes.has(entry[0]))
				item.set_metadata(0, category["code"])
				_rows[entry[0]] = item
				if first == null and codes.has(entry[0]):
					first = item
	if first != null:
		_tree.scroll_to_item.call_deferred(first, true)


## A row that only heads others: not ticked nor picked.
func _heading(item: TreeItem, color: Color) -> void:
	for c: int in 2:
		item.set_selectable(c, false)
		if color != Color.TRANSPARENT:
			item.set_custom_color(c, color)


func _ticked() -> void:
	var item: TreeItem = _tree.get_edited()
	if item != null:
		_ticked_item(item)


## One class of a category at most: ticking [param item] takes the tick
## off the others of its category.
func _ticked_item(item: TreeItem) -> void:
	if not item.is_checked(0):
		return
	var category: String = item.get_metadata(0)
	for code: String in _rows:
		var other: TreeItem = _rows[code]
		if other != item and other.get_metadata(0) == category:
			other.set_checked(0, false)
