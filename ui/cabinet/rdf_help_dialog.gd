class_name RdfHelpDialog
extends ConfirmationDialog
## What the rated diversity factor RDF is ([HeatRise]), opened by the "?"
## beside its field in [HeatRiseDialog]: a short explanation and, as a
## table, the values ČSN EN 61439-3 (household boards, DBO) and ČSN EN
## 61439-2 (power switchgear, PSC) assume when the maker gives none ([constant HeatRise.RDF_TABLE]). A value picked
## (a double click, or picked and Use) is put in ([signal chosen]).

## The value [param rdf] was picked to be put in.
signal chosen(rdf: float)

var _hint: Label
var _tree: Tree


func _init() -> void:
	min_size = Vector2i(600, 440)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_hint = Label.new()
	_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hint.theme_type_variation = "MutedLabel"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 560.0
	column.add_child(_hint)
	_tree = Tree.new()
	_tree.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tree.hide_root = true
	_tree.columns = 3
	_tree.column_titles_visible = true
	_tree.select_mode = Tree.SELECT_SINGLE
	_tree.set_column_expand(0, true)
	_tree.set_column_custom_minimum_width(0, 300)
	for c: int in [1, 2]:
		_tree.set_column_expand(c, false)
		_tree.set_column_custom_minimum_width(c, 110)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(560, 250)
	_tree.cell_selected.connect(func() -> void: get_ok_button().disabled = picked() == null)
	_tree.item_activated.connect(func() -> void:
		if picked() != null:
			hide()
			chosen.emit(picked()))
	column.add_child(_tree)
	confirmed.connect(func() -> void:
		if picked() != null:
			chosen.emit(picked()))


## Shows the explanation and the table, nothing picked.
func open() -> void:
	title = tr("Rated diversity factor RDF")
	ok_button_text = tr("Use")
	cancel_button_text = tr("Close")
	_hint.text = tr("The rated diversity factor RDF (součinitel soudobosti) is one for the whole switchboard (ČSN EN 61439-1): the share of their rated currents the outgoing circuits carry together for a long time. Loaded at RDF times their rated currents, the devices, wires and strip terminals lose RDF² times what they lose at them; further losses stay as they are. 1 is without diversity, as IEC 890 reckons. Take the maker's or the project's value; when there is none, the standards assume these for household distribution boards (DBO, ČSN EN 61439-3) and power switchgear (PSC, ČSN EN 61439-2); pick one and Use, or double-click it:")
	_tree.set_column_title(0, tr("What"))
	_tree.set_column_title(1, tr("Household"))
	_tree.set_column_title(2, tr("Power switchgear"))
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	for entry: Array in HeatRise.RDF_TABLE:
		var item: TreeItem = _tree.create_item(root)
		item.set_text(0, tr(entry[0]))
		item.set_selectable(0, false)
		for c: int in [1, 2]:
			# Household boards (DBO) first, then power switchgear (PSC).
			var value: Variant = entry[2 if c == 1 else 1]
			item.set_text_alignment(c, HORIZONTAL_ALIGNMENT_CENTER)
			item.set_text(c, String.num(value, 1) if value != null else "–")
			item.set_metadata(c, value)
			item.set_selectable(c, value != null)
			if value == null:
				item.set_custom_color(c, AppTheme.text_faint)
	get_ok_button().disabled = true
	popup_centered_clamped(Vector2i(640, 520), 0.9)


## The value of the cell picked, null for none.
func picked() -> Variant:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return null
	var column: int = _tree.get_selected_column()
	return item.get_metadata(column) if column > 0 else null
