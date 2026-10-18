class_name CablePanel
extends MarginContainer
## The cores of one cable of the workspace, opened from it: a list with a row
## per core, its wire number and what it lands on at each end (a strip
## terminal "X2:3", a device terminal "SB1:13"); the PE core last, marked PE.
## Above it the cable's name and type.

## Key of the cable shown ("+RA1|+ST1", see [method WorkspaceCables.cables]).
var cable_key: String = ""
var _document: SchematicDocument
var _note: Label
var _list: Tree


func _ready() -> void:
	for side: String in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 16)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_note = Label.new()
	_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_note.theme_type_variation = "MutedLabel"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)
	_list = Tree.new()
	_list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.hide_root = true
	_list.columns = 4
	_list.column_titles_visible = true
	_list.select_mode = Tree.SELECT_ROW
	column.add_child(_list)
	_rebuild()


func set_document(doc: SchematicDocument, _editing: bool) -> void:
	_document = doc
	_rebuild()


func refresh() -> void:
	_rebuild()


func retranslate() -> void:
	_rebuild()


## The cable shown, {} when the document has no such cable.
func cable() -> Dictionary:
	if _document == null:
		return {}
	for found: Dictionary in WorkspaceCables.cables(_document):
		if found["key"] == cable_key:
			return found
	return {}


func _rebuild() -> void:
	if _list == null:
		return
	_list.clear()
	var shown: Dictionary = cable()
	if shown.is_empty():
		_note.text = ""
		return
	var cores: Array = shown["cores"]
	_note.text = "%s %s.  " % [shown["name"], WorkspaceCables.type_text(shown)] + tr_n("%d core between %s and %s, worked out from the wiring of the schematic.", "%d cores between %s and %s, worked out from the wiring of the schematic.", cores.size()) % [cores.size(), shown["a"], shown["b"]]
	_list.set_column_title(0, tr("Core"))
	_list.set_column_title(1, tr("Wire number"))
	_list.set_column_title(2, str(shown["a"]))
	_list.set_column_title(3, str(shown["b"]))
	for c: int in 4:
		_list.set_column_title_alignment(c, HORIZONTAL_ALIGNMENT_LEFT)
		_list.set_column_expand(c, c >= 2)
		_list.set_column_custom_minimum_width(c, 90 if c < 2 else 160)
	var root: TreeItem = _list.create_item()
	var n: int = 0
	for core: Dictionary in cores:
		var row: TreeItem = _list.create_item(root)
		var pe: bool = core["conductor"] == CabinetDevices.Conductor.PE
		if not pe:
			n += 1
		row.set_text(0, "PE" if pe else str(n))
		if pe:
			row.set_custom_color(0, SchematicTheme.PE)
		row.set_text(1, str(core["number"]))
		row.set_text(2, ", ".join(core["a"]))
		row.set_text(3, ", ".join(core["b"]))
