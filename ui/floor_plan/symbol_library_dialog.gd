class_name SymbolLibraryDialog
extends AcceptDialog
## The user's own floor plan symbols ([SymbolLibrary]) by category, the one
## picked drawn beside the list: New, Edit (or a double click), Duplicate
## and Delete; Import takes the symbols of a file in (see
## [method SymbolLibrary.import_file]), Export writes all of them or the
## picked one's category to a file to share. The palette of a residential installation's floor plan offers
## them under their categories.

## [param def] was drawn and kept in the library (new or changed).
signal symbol_saved(def: CustomSymbol)

var _tree: Tree
## The symbol picked, drawn on schematic paper.
var _paper: Panel
var _preview: PlanGlyph
var _about: Label
var _new: Button
var _edit: Button
var _duplicate: Button
var _remove: Button
var _editor: SymbolEditor
var _confirm: ConfirmationDialog
var _import: Button
var _export: MenuButton
var _import_file: FileDialog
var _export_file: FileDialog
## What the export writes: the symbols' ids (all of them when empty).
var _exporting: PackedStringArray = PackedStringArray()
## What an import or an export did, or why it could not.
var _message: AcceptDialog


func _init() -> void:
	min_size = Vector2i(560, 420)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_tree = Tree.new()
	_tree.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tree.hide_root = true
	_tree.custom_minimum_size = Vector2(300, 340)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_update)
	_tree.item_activated.connect(func() -> void: _open_editor(_picked()))
	row.add_child(_tree)
	var side: VBoxContainer = VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	row.add_child(side)
	_paper = Panel.new()
	_paper.custom_minimum_size = Vector2(160, 120)
	side.add_child(_paper)
	_preview = PlanGlyph.new()
	_preview.size = _paper.custom_minimum_size
	_preview.custom_scale = 400.0
	_paper.add_child(_preview)
	_about = Label.new()
	_about.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_about.theme_type_variation = "MutedLabel"
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about.custom_minimum_size.x = 160.0
	side.add_child(_about)
	_new = _button(side, func() -> void: _open_editor(null))
	_edit = _button(side, func() -> void: _open_editor(_picked()))
	_duplicate = _button(side, func() -> void:
		var picked: CustomSymbol = _picked()
		if picked == null:
			return
		var twin: CustomSymbol = picked.copy()
		twin.id = CustomSymbol.new_id()
		twin.name = tr("%s (copy)") % picked.name
		SymbolLibrary.shared().put(twin)
		_fill(twin.id))
	_remove = _button(side, func() -> void:
		if _picked() != null:
			_confirm.dialog_text = tr("Delete %s from your symbols? Schematics using it keep their copy.") % _picked().name
			_confirm.reset_size()
			_confirm.popup_centered())
	side.add_child(HSeparator.new())
	_import = _button(side, func() -> void:
		_import_file.title = tr("Import symbols")
		_import_file.popup_centered_ratio(0.6))
	_export = MenuButton.new()
	_export.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_export.flat = false
	_export.about_to_popup.connect(_fill_export)
	_export.get_popup().id_pressed.connect(_ask_export)
	side.add_child(_export)
	var filter: String = "*.%s ; %s" % [SymbolLibrary.EXTENSION, tr("LadderLab symbols")]
	_import_file = FileDialog.new()
	_import_file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_file.access = FileDialog.ACCESS_FILESYSTEM
	_import_file.use_native_dialog = true
	_import_file.filters = PackedStringArray([filter])
	_import_file.file_selected.connect(_import_symbols)
	add_child(_import_file)
	_export_file = FileDialog.new()
	_export_file.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_file.access = FileDialog.ACCESS_FILESYSTEM
	_export_file.use_native_dialog = true
	_export_file.filters = PackedStringArray([filter])
	_export_file.file_selected.connect(_export_symbols)
	add_child(_export_file)
	_message = AcceptDialog.new()
	add_child(_message)
	_editor = SymbolEditor.new()
	_editor.saved.connect(func(def: CustomSymbol) -> void:
		SymbolLibrary.shared().put(def)
		_fill(def.id)
		symbol_saved.emit(def))
	add_child(_editor)
	_confirm = ConfirmationDialog.new()
	_confirm.confirmed.connect(func() -> void:
		var picked: CustomSymbol = _picked()
		if picked != null:
			SymbolLibrary.shared().remove(picked.id)
			_fill(""))
	add_child(_confirm)


## Shows the library, [param id] picked ("" for none).
func open(id: String = "") -> void:
	title = tr("My symbols")
	ok_button_text = tr("Close")
	_new.text = tr("New symbol…")
	_edit.text = tr("Edit…")
	_duplicate.text = tr("Duplicate")
	_remove.text = tr("Delete")
	_import.text = tr("Import…")
	_import.tooltip_text = tr("Take in the symbols of a file someone shared; one you have already is drawn as in the file")
	_export.text = tr("Export")
	_export.tooltip_text = tr("Write your symbols to a file to share or keep")
	_message.ok_button_text = tr("OK")
	_confirm.title = tr("Delete symbol")
	_confirm.ok_button_text = tr("Delete")
	_confirm.cancel_button_text = tr("Cancel")
	var edge: Color = Color(1, 1, 1, 0.1) if SchematicTheme.dark else Color(0, 0, 0, 0.08)
	_paper.add_theme_stylebox_override("panel", AppTheme.box(SchematicTheme.BACKGROUND, 5, 0.0, 0.0, edge, 1))
	_fill(id)
	popup_centered()


## Opens the editor on a new symbol at once.
func new_symbol() -> void:
	_open_editor(null)


func _fill(id: String) -> void:
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var heads: Dictionary[String, TreeItem] = {}
	for def: CustomSymbol in SymbolLibrary.shared().sorted():
		if not heads.has(def.category):
			var head: TreeItem = _tree.create_item(root)
			head.set_text(0, _category_title(def.category))
			head.set_selectable(0, false)
			head.set_custom_color(0, AppTheme.text_muted)
			heads[def.category] = head
		var item: TreeItem = _tree.create_item(heads[def.category])
		item.set_text(0, tr("%s (load)") % def.name if def.electrical else def.name)
		item.set_metadata(0, def.id)
		if def.id == id:
			item.select(0)
	if heads.is_empty():
		var empty: TreeItem = _tree.create_item(root)
		empty.set_text(0, tr("No symbols yet: draw one with New symbol."))
		empty.set_selectable(0, false)
	_update()


## The export menu: every symbol, or only the picked one's category.
func _fill_export() -> void:
	var popup: PopupMenu = _export.get_popup()
	popup.clear()
	popup.add_item(tr("All symbols…"), 0)
	popup.set_item_disabled(0, SymbolLibrary.shared().symbols.is_empty())
	var picked: CustomSymbol = _picked()
	if picked != null:
		popup.add_item(tr("Only the category %s…") % _category_title(picked.category), 1)


func _ask_export(id: int) -> void:
	var picked: CustomSymbol = _picked()
	_exporting = PackedStringArray()
	var file_name: String = "symbols"
	if id == 1 and picked != null:
		for def: CustomSymbol in SymbolLibrary.shared().symbols:
			if def.category == picked.category:
				_exporting.append(def.id)
		file_name = _category_title(picked.category).validate_filename()
	_export_file.title = tr("Export symbols")
	_export_file.current_file = "%s.%s" % [file_name, SymbolLibrary.EXTENSION]
	_export_file.popup_centered_ratio(0.6)


func _export_symbols(file_path: String) -> void:
	if file_path.get_extension().is_empty():
		file_path += "." + SymbolLibrary.EXTENSION
	var count: int = _exporting.size() if not _exporting.is_empty() else SymbolLibrary.shared().symbols.size()
	if SymbolLibrary.shared().export_file(file_path, _exporting) != OK:
		_tell(tr("Export symbols"), tr("%s cannot be written.") % file_path.get_file())
		return
	_tell(tr("Export symbols"), tr_n("%d symbol written to %s.", "%d symbols written to %s.", count) % [count, file_path.get_file()])


func _import_symbols(file_path: String) -> void:
	var result: Dictionary = SymbolLibrary.shared().import_file(file_path)
	if result.has("error"):
		_tell(tr("Import symbols"), tr(str(result["error"])) % file_path.get_file())
		return
	var added: PackedStringArray = result["added"]
	var replaced: PackedStringArray = result["replaced"]
	# The schematic takes the new drawings of the symbols it uses.
	for id: String in replaced:
		symbol_saved.emit(SymbolLibrary.shared().find(id))
	var first: String = added[0] if not added.is_empty() else (replaced[0] if not replaced.is_empty() else "")
	_fill(first)
	var text: String = tr_n("%d new symbol", "%d new symbols", added.size()) % added.size()
	if not replaced.is_empty():
		text += ", " + tr("%d already in your library, now drawn as in the file") % replaced.size()
	_tell(tr("Import symbols"), text + ".")


func _tell(heading: String, text: String) -> void:
	_message.title = heading
	_message.dialog_text = text
	_message.reset_size()
	_message.popup_centered()


## How category [param category] is listed ("" is "My symbols").
func _category_title(category: String) -> String:
	return category if not category.is_empty() else tr("My symbols")


func _picked() -> CustomSymbol:
	var item: TreeItem = _tree.get_selected()
	if item == null or item.get_metadata(0) == null:
		return null
	return SymbolLibrary.shared().find(str(item.get_metadata(0)))


func _update() -> void:
	var picked: CustomSymbol = _picked()
	for button: Button in [_edit, _duplicate, _remove]:
		button.disabled = picked == null
	_preview.custom = picked
	_preview.queue_redraw()
	if picked == null:
		_about.text = ""
	elif picked.electrical:
		_about.text = tr("A load on a circuit, %s, %s") % [ApplianceSymbol.power_text(picked.power), "400 V" if picked.two_phases else "230 V"] + ("; " + tr("on a wall") if picked.wall else "")
	else:
		_about.text = tr("A drawing on the plan") + ("; " + tr("on a wall") if picked.wall else "")


func _open_editor(def: CustomSymbol) -> void:
	_editor.open(def)


func _button(column: VBoxContainer, action: Callable) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.pressed.connect(action)
	column.add_child(button)
	return button
