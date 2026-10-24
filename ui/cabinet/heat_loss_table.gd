class_name HeatLossTable
extends VBoxContainer
## The losses of a switchboard's temperature rise calculation ([HeatRise])
## as a table with a text field for each value to give: a device's loss
## (W, from its maker), each group of wires' cross-section (mm²), the strip
## terminals' and further losses (W). A field not filled in says "enter" in
## the warning colour. Beside each its loss (W), under them the total.
## A device's type from its maker has a text field of its own (column
## "Type"). Devices alike (the same name and data, type and loss as given,
## [method HeatRiseReport.device_groups]) are one row, "-FA1…-FA4" with how
## many: their type and loss are given once for all of them, the loss
## beside them all together. Used in the dialog and over the whole screen ([HeatRiseDialog]).

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
## Per row: {"what", "name" (the first of "names"), "names" (the devices'
## designations, a wire group's current, else ""), "field" (LineEdit),
## "type" (the devices' LineEdit for their type, else null), "loss" (Label)}.
var _rows: Array[Dictionary] = []
var _total: Label
var _total_title: Label
## The devices', wires' and terminals' losses at their rated currents.
var _rated: Label


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
## [param doc], every field filled with what is given.
func fill(doc: SchematicDocument, losses: Dictionary) -> void:
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
	for alike: Dictionary in HeatRiseReport.device_groups(doc, losses):
		var names: PackedStringArray = PackedStringArray()
		for designation: String in alike["designations"]:
			names.append(designation.trim_prefix("-"))
		var text: String = HeatRiseReport.device_text(doc, names[0])
		if names.size() > 1:
			text = tr("%d × %s") % [names.size(), text]
		_row(HeatRiseDialog.ROW_DEVICE, names, PartsList.designations(alike["designations"]), text, alike["power"], "W", alike["type"])
	for group: Dictionary in losses["groups"]:
		_row(HeatRiseDialog.ROW_WIRES, PackedStringArray([group["key"]]), "%s A" % group["key"], tr("Wires (%d, %s m), cross-section") % [group["count"], String.num(group["length"], 1)], group["section"], "mm²")
	if losses["terminal_count"] > 0:
		_row(HeatRiseDialog.ROW_TERMINALS, PackedStringArray([""]), "", tr("Strip terminals (%d), all together") % losses["terminal_count"], losses["terminals"], "W")
	_rated = _sum_row(tr("At the rated currents"))
	_row(HeatRiseDialog.ROW_EXTRA, PackedStringArray([""]), "", tr("Further losses (lighting, fans, heaters …)"), losses["extra"], "W")
	_total = _sum_row("")
	_total_title = _grid.get_child(_grid.get_child_count() - 4)
	show_losses(losses)


## The loss beside each field and the total from [param losses], the fields
## as they are.
func show_losses(losses: Dictionary) -> void:
	var by_row: Dictionary = {}
	for device: Dictionary in losses["devices"]:
		by_row[HeatRiseDialog.ROW_DEVICE + "|" + device["designation"]] = device["power"]
	for group: Dictionary in losses["groups"]:
		by_row[HeatRiseDialog.ROW_WIRES + "|" + group["key"]] = group["power"]
	by_row[HeatRiseDialog.ROW_TERMINALS + "|"] = losses["terminals"]
	by_row[HeatRiseDialog.ROW_EXTRA + "|"] = losses["extra"]
	for row: Dictionary in _rows:
		# Devices alike lose together.
		var loss: Variant = 0.0
		for name: String in row["names"]:
			var part: Variant = by_row.get(row["what"] + "|" + name)
			loss = null if loss == null or part == null else loss + part
		(row["loss"] as Label).text = String.num(loss, 1) if loss != null else ""
		var field: LineEdit = row["field"]
		field.placeholder_text = tr("enter")
	if _total != null:
		_rated.text = String.num(losses["rated"], 1) if losses["rated"] != null else "?"
		_total.text = String.num(losses["total"], 1) if losses["total"] != null else "?"
		var rdf: String = String.num(losses["rdf"], 2) if losses["rdf"] != null else "?"
		_total_title.text = tr("Total P (RDF = %s)") % rdf
		_total_title.tooltip_text = tr("Total P = RDF² · %s + further losses (RDF = %s)") % [_rated.text, rdf]
		_total_title.mouse_filter = Control.MOUSE_FILTER_PASS


## The text field of row [param what] of [param name] (a device's
## designation: the row of it and the devices alike), null for none.
func field(what: String, name: String) -> LineEdit:
	for row: Dictionary in _rows:
		if row["what"] == what and (row["names"] as PackedStringArray).has(name):
			return row["field"]
	return null


## The text field for the type of device [param name], null for none.
func type_field(name: String) -> LineEdit:
	for row: Dictionary in _rows:
		if row["what"] == HeatRiseDialog.ROW_DEVICE and (row["names"] as PackedStringArray).has(name):
			return row["type"]
	return null


## The text fields, in the order of the rows.
func fields() -> Array[LineEdit]:
	var result: Array[LineEdit] = []
	for row: Dictionary in _rows:
		result.append(row["field"])
	return result


## A row of [param names] (devices alike: what is typed goes to each); [param
## type] is the devices' type as given (null: a row that is not a device's,
## without a type field).
func _row(what: String, names: PackedStringArray, item: String, text: String, given: Variant, unit: String, type: Variant = null) -> void:
	var shown_names: String = item.trim_prefix("-")
	_grid.add_child(_label(item, item_width))
	var description: Label = _label(text, -1.0)
	description.custom_minimum_size.x = text_width
	description.tooltip_text = text
	description.mouse_filter = Control.MOUSE_FILTER_PASS
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.clip_text = true
	_grid.add_child(description)
	var type_input: LineEdit = null
	if type != null:
		type_input = LineEdit.new()
		type_input.custom_minimum_size.x = type_width
		type_input.select_all_on_focus = true
		type_input.text = str(type)
		type_input.placeholder_text = tr("enter")
		type_input.add_theme_color_override("font_placeholder_color", AppTheme.warning)
		type_input.tooltip_text = tr("Type of -%s from its maker (e.g. its order code)") % shown_names
		type_input.text_changed.connect(func(value: String) -> void:
			for name: String in names:
				typed.emit(HeatRiseDialog.ROW_TYPE, name, value))
		_grid.add_child(type_input)
	else:
		var none: Control = Control.new()
		none.custom_minimum_size.x = type_width
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
	input.tooltip_text = tr("Loss of -%s at its rated current, from its maker (W)") % shown_names if what == HeatRiseDialog.ROW_DEVICE else (tr("Cross-section of these wires (mm²)") if what == HeatRiseDialog.ROW_WIRES else tr("W"))
	input.text_changed.connect(func(value: String) -> void:
		for name: String in names:
			typed.emit(what, name, HeatRiseDialog.number(value)))
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
	_rows.append({"what": what, "name": names[0], "names": names, "field": input, "type": type_input, "loss": loss})


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
