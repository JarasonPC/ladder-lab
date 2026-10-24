class_name HeatLossTable
extends VBoxContainer
## The losses of a switchboard's temperature rise calculation ([HeatRise])
## as a table with a text field for each value to give: a device's loss
## (W, from its maker), each group of wires' cross-section (mm²), the strip
## terminals' and further losses (W). A field not filled in says "enter" in
## the warning colour. Beside each its loss (W), under them the total.
## A device's type from its maker has a text field of its own (column
## "Type"): typing completes it with a type already given to the same
## device (the same name and data: on these rails or another switchboard's)
## and the "▾" beside it lists them; a type taken from there brings its loss
## into an empty loss field ([method known]). Used in the dialog and over
## the whole screen ([HeatRiseDialog]).

## [param value] was typed for row [param what] ([constant HeatRiseDialog.ROW_DEVICE]
## …) of [param name] (the device's designation, the current); null when
## the field was emptied or is not a number; a device's type
## ([constant HeatRiseDialog.ROW_TYPE]) as text.
signal typed(what: String, name: String, value: Variant)

## Width of the text fields and of the first column.
var field_width: float = 80.0
var item_width: float = 64.0
var type_width: float = 96.0
## Least width of the description column.
var text_width: float = 120.0

var _grid: GridContainer
## Per row: {"what", "name", "field" (LineEdit), "type" (a device's LineEdit
## for its type, else null), "types" (its MenuButton of the types known),
## "loss" (Label)}.
var _rows: Array[Dictionary] = []
var _total: Label
var _total_title: Label
## The devices', wires' and terminals' losses at their rated currents.
var _rated: Label
## What the table shows: the document, its switchboard, the losses last
## shown, what each device is (by designation, see [method
## HeatRiseReport.device_text]).
var _doc: SchematicDocument
var _board: int = -1
var _latest: Dictionary = {}
var _texts: Dictionary[String, String] = {}


func _init() -> void:
	add_theme_constant_override("separation", 4)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_grid)


## The rows of [param losses] (see [method HeatRise.losses]) of
## switchboard [param board] of [param doc], every field filled with what is
## given.
func fill(doc: SchematicDocument, losses: Dictionary, board: int = -1) -> void:
	_doc = doc
	_board = board
	_latest = losses
	_texts.clear()
	for device: Dictionary in losses["devices"]:
		_texts[device["designation"]] = HeatRiseReport.device_text(doc, device["designation"])
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_rows.clear()
	# The heading row.
	var titles: Array[String] = [tr("Item"), tr("What"), tr("Type"), tr("Given"), tr("Loss (W)")]
	var widths: Array[float] = [item_width, -1.0, type_width, field_width, 70.0]
	for i: int in 5:
		var head: Label = _label(titles[i], widths[i])
		head.theme_type_variation = "MutedLabel"
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 4 else HORIZONTAL_ALIGNMENT_LEFT
		_grid.add_child(head)
	for device: Dictionary in losses["devices"]:
		_row(HeatRiseDialog.ROW_DEVICE, device["designation"], "-" + device["designation"], _texts[device["designation"]], device["power"], "W", device["type"])
	for group: Dictionary in losses["groups"]:
		_row(HeatRiseDialog.ROW_WIRES, group["key"], "%s A" % group["key"], tr("Wires (%d, %s m), cross-section") % [group["count"], String.num(group["length"], 1)], group["section"], "mm²")
	if losses["terminal_count"] > 0:
		_row(HeatRiseDialog.ROW_TERMINALS, "", "", tr("Strip terminals (%d), all together") % losses["terminal_count"], losses["terminals"], "W")
	_rated = _sum_row(tr("At the rated currents"))
	_row(HeatRiseDialog.ROW_EXTRA, "", "", tr("Further losses (lighting, fans, heaters …)"), losses["extra"], "W")
	_total = _sum_row("")
	_total_title = _grid.get_child(_grid.get_child_count() - 4)
	show_losses(losses)


## The loss beside each field and the total from [param losses], the fields
## as they are.
func show_losses(losses: Dictionary) -> void:
	_latest = losses
	var by_row: Dictionary = {}
	for device: Dictionary in losses["devices"]:
		by_row[HeatRiseDialog.ROW_DEVICE + "|" + device["designation"]] = device["power"]
	for group: Dictionary in losses["groups"]:
		by_row[HeatRiseDialog.ROW_WIRES + "|" + group["key"]] = group["power"]
	by_row[HeatRiseDialog.ROW_TERMINALS + "|"] = losses["terminals"]
	by_row[HeatRiseDialog.ROW_EXTRA + "|"] = losses["extra"]
	for row: Dictionary in _rows:
		var loss: Variant = by_row.get(row["what"] + "|" + row["name"])
		(row["loss"] as Label).text = String.num(loss, 1) if loss != null else ""
		var field: LineEdit = row["field"]
		field.placeholder_text = tr("enter")
		if row["types"] != null:
			(row["types"] as MenuButton).disabled = known(row["name"]).is_empty()
	if _total != null:
		_rated.text = String.num(losses["rated"], 1) if losses["rated"] != null else "?"
		_total.text = String.num(losses["total"], 1) if losses["total"] != null else "?"
		var rdf: String = String.num(losses["rdf"], 2) if losses["rdf"] != null else "?"
		_total_title.text = tr("Total P (RDF = %s)") % rdf
		_total_title.tooltip_text = tr("Total P = RDF² · %s + further losses (RDF = %s)") % [_rated.text, rdf]
		_total_title.mouse_filter = Control.MOUSE_FILTER_PASS


## The text field of row [param what] of [param name], null for none.
func field(what: String, name: String) -> LineEdit:
	for row: Dictionary in _rows:
		if row["what"] == what and row["name"] == name:
			return row["field"]
	return null


## The text field for the type of device [param name], null for none.
func type_field(name: String) -> LineEdit:
	for row: Dictionary in _rows:
		if row["what"] == HeatRiseDialog.ROW_DEVICE and row["name"] == name:
			return row["type"]
	return null


## The types already given to devices the same as [param designation]
## (what [method HeatRiseReport.device_text] says of them alike), on these
## rails as the losses last shown have them and in the other switchboards,
## each with its loss as given there (null: none): {type: loss}.
func known(designation: String) -> Dictionary:
	var result: Dictionary = {}
	if _doc == null or not _texts.has(designation):
		return result
	var text: String = _texts[designation]
	for device: Dictionary in _latest.get("devices", []):
		var type: String = device["type"]
		if device["designation"] != designation and not type.is_empty() and _texts.get(device["designation"], "") == text:
			if result.get(type) == null:
				result[type] = device["power"]
	for b: int in _doc.switchboards.size():
		if b == _board:
			continue
		var heat: Dictionary = HeatRise.settings(_doc.switchboards[b].heat)
		var types: Dictionary = heat.get("types", {})
		for other: String in types:
			if result.get(types[other]) == null and HeatRiseReport.device_text(_doc, other) == text:
				result[types[other]] = heat.get("losses", {}).get(other)
	return result


## The text fields, in the order of the rows.
func fields() -> Array[LineEdit]:
	var result: Array[LineEdit] = []
	for row: Dictionary in _rows:
		result.append(row["field"])
	return result


## A row; [param type] is the device's type as given (null: a row that is
## not a device's, without a type field).
func _row(what: String, name: String, item: String, text: String, given: Variant, unit: String, type: Variant = null) -> void:
	_grid.add_child(_label(item, item_width))
	var description: Label = _label(text, -1.0)
	description.custom_minimum_size.x = text_width
	description.tooltip_text = text
	description.mouse_filter = Control.MOUSE_FILTER_PASS
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.clip_text = true
	_grid.add_child(description)
	var type_input: LineEdit = null
	var types_menu: MenuButton = null
	if type != null:
		type_input = LineEdit.new()
		type_input.custom_minimum_size.x = type_width
		type_input.select_all_on_focus = true
		type_input.text = str(type)
		type_input.placeholder_text = tr("enter")
		type_input.add_theme_color_override("font_placeholder_color", AppTheme.warning)
		type_input.tooltip_text = tr("Type of -%s from its maker (e.g. its order code)") % name
		type_input.text_changed.connect(func(value: String) -> void: _type_typed(type_input, name, value))
		type_input.text_submitted.connect(func(_value: String) -> void: _type_taken(name))
		type_input.focus_exited.connect(func() -> void: _type_taken(name))
		var type_box: HBoxContainer = HBoxContainer.new()
		type_box.add_theme_constant_override("separation", 2)
		type_box.add_child(type_input)
		types_menu = MenuButton.new()
		types_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		types_menu.flat = false
		types_menu.icon = AppTheme.icon("chevron_down")
		types_menu.focus_mode = Control.FOCUS_NONE
		types_menu.tooltip_text = tr("Types already given to the same device")
		types_menu.disabled = known(name).is_empty()
		types_menu.about_to_popup.connect(func() -> void:
			var popup: PopupMenu = types_menu.get_popup()
			popup.clear()
			for known_type: String in known(name):
				popup.add_item(known_type))
		types_menu.get_popup().index_pressed.connect(func(index: int) -> void:
			type_input.text = types_menu.get_popup().get_item_text(index)
			type_input.set_meta("typed", type_input.text)
			typed.emit(HeatRiseDialog.ROW_TYPE, name, type_input.text)
			_type_taken(name))
		type_box.add_child(types_menu)
		_grid.add_child(type_box)
	else:
		var none: Control = Control.new()
		none.custom_minimum_size.x = type_width + 30.0
		_grid.add_child(none)
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var input: LineEdit = LineEdit.new()
	input.custom_minimum_size.x = field_width
	input.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	input.select_all_on_focus = true
	input.text = HeatRiseDialog.shown(given)
	input.placeholder_text = tr("enter")
	input.add_theme_color_override("font_placeholder_color", AppTheme.warning)
	input.tooltip_text = tr("Loss of -%s at its rated current, from its maker (W)") % name if what == HeatRiseDialog.ROW_DEVICE else (tr("Cross-section of these wires (mm²)") if what == HeatRiseDialog.ROW_WIRES else tr("W"))
	input.text_changed.connect(func(value: String) -> void: typed.emit(what, name, HeatRiseDialog.number(value)))
	box.add_child(input)
	var unit_label: Label = Label.new()
	unit_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	unit_label.theme_type_variation = "MutedLabel"
	unit_label.text = unit
	unit_label.custom_minimum_size.x = 34.0
	box.add_child(unit_label)
	_grid.add_child(box)
	var loss: Label = _label("", 70.0)
	loss.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_grid.add_child(loss)
	_rows.append({"what": what, "name": name, "field": input, "type": type_input, "types": types_menu, "loss": loss})


## [param value] typed as the type of device [param name] in [param input]:
## while letters are added at its end, completed with a type the same
## device has elsewhere (the rest selected, so typing on replaces it).
func _type_typed(input: LineEdit, name: String, value: String) -> void:
	var before: String = input.get_meta("typed", "")
	input.set_meta("typed", value)
	if value.length() > before.length() and not value.is_empty() and input.caret_column == value.length():
		for type: String in known(name):
			if type.length() > value.length() and type.to_lower().begins_with(value.to_lower()):
				input.text = type
				input.caret_column = type.length()
				input.select(value.length(), type.length())
				value = type
				break
	typed.emit(HeatRiseDialog.ROW_TYPE, name, value)


## The type of device [param name] taken: one the same device has elsewhere
## brings its loss into the loss field while that is empty.
func _type_taken(name: String) -> void:
	for row: Dictionary in _rows:
		if row["what"] != HeatRiseDialog.ROW_DEVICE or row["name"] != name:
			continue
		var field: LineEdit = row["field"]
		var power: Variant = known(name).get((row["type"] as LineEdit).text.strip_edges())
		if field.text.strip_edges().is_empty() and power != null:
			field.text = HeatRiseDialog.shown(power)
			typed.emit(HeatRiseDialog.ROW_DEVICE, name, float(power))


## A row of a sum: [param title] across, its value (returned) on the right.
func _sum_row(title: String) -> Label:
	_grid.add_child(Control.new())
	var heading: Label = _label(title, -1.0)
	heading.custom_minimum_size.x = text_width
	heading.add_theme_color_override("font_color", AppTheme.accent)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grid.add_child(heading)
	_grid.add_child(Control.new())
	_grid.add_child(Control.new())
	var value: Label = _label("", 70.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_color_override("font_color", AppTheme.accent)
	_grid.add_child(value)
	return value


func _label(text: String, width: float) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.custom_minimum_size.x = maxf(width, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width < 0.0 else Control.SIZE_FILL
	return label
