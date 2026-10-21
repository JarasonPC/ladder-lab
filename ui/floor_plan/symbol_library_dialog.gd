class_name SymbolLibraryDialog
extends AcceptDialog
## The user's own floor plan symbols ([SymbolLibrary]) by category, the one
## picked drawn beside the list: New, Edit (or a double click), Duplicate
## and Delete. The palette of a residential installation's floor plan offers
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
			head.set_text(0, def.category if not def.category.is_empty() else tr("My symbols"))
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
