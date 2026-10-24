class_name HeatLossTable
extends VBoxContainer
## The losses of a switchboard's temperature rise calculation ([HeatRise])
## as a table with a text field for each value to give: a device's loss
## (W, from its maker), each group of wires' cross-section (mm²), the strip
## terminals' and further losses (W). A field not filled in says "enter" in
## the warning colour. Beside each its loss (W), under them the total.
## Used in the dialog and over the whole screen ([HeatRiseDialog]).

## [param value] was typed for row [param what] ([constant HeatRiseDialog.ROW_DEVICE]
## …) of [param name] (the device's designation, the current); null when
## the field was emptied or is not a number.
signal typed(what: String, name: String, value: Variant)

## Width of the text fields and of the first column.
var field_width: float = 80.0
var item_width: float = 64.0

var _grid: GridContainer
## Per row: {"what", "name", "field" (LineEdit), "loss" (Label)}.
var _rows: Array[Dictionary] = []
var _total: Label


func _init() -> void:
	add_theme_constant_override("separation", 4)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
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
	var titles: Array[String] = [tr("Item"), tr("What"), tr("Given"), tr("Loss (W)")]
	var widths: Array[float] = [item_width, -1.0, field_width, 70.0]
	for i: int in 4:
		var head: Label = _label(titles[i], widths[i])
		head.theme_type_variation = "MutedLabel"
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 3 else HORIZONTAL_ALIGNMENT_LEFT
		_grid.add_child(head)
	for device: Dictionary in losses["devices"]:
		_row(HeatRiseDialog.ROW_DEVICE, device["designation"], "-" + device["designation"], HeatRiseReport.device_text(doc, device["designation"]), device["power"], "W")
	for group: Dictionary in losses["groups"]:
		_row(HeatRiseDialog.ROW_WIRES, group["key"], "%s A" % group["key"], tr("Wires (%d, %s m), cross-section") % [group["count"], String.num(group["length"], 1)], group["section"], "mm²")
	if losses["terminal_count"] > 0:
		_row(HeatRiseDialog.ROW_TERMINALS, "", "", tr("Strip terminals (%d), all together") % losses["terminal_count"], losses["terminals"], "W")
	_row(HeatRiseDialog.ROW_EXTRA, "", "", tr("Further losses (lighting, fans, heaters …)"), losses["extra"], "W")
	_grid.add_child(Control.new())
	var total_title: Label = _label(tr("Total P"), -1.0)
	total_title.add_theme_color_override("font_color", AppTheme.accent)
	_grid.add_child(total_title)
	_grid.add_child(Control.new())
	_total = _label("", 70.0)
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_total.add_theme_color_override("font_color", AppTheme.accent)
	_grid.add_child(_total)
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
		var loss: Variant = by_row.get(row["what"] + "|" + row["name"])
		(row["loss"] as Label).text = String.num(loss, 1) if loss != null else ""
		var field: LineEdit = row["field"]
		field.placeholder_text = tr("enter")
	if _total != null:
		_total.text = String.num(losses["total"], 1) if losses["total"] != null else "?"


## The text field of row [param what] of [param name], null for none.
func field(what: String, name: String) -> LineEdit:
	for row: Dictionary in _rows:
		if row["what"] == what and row["name"] == name:
			return row["field"]
	return null


## The text fields, in the order of the rows.
func fields() -> Array[LineEdit]:
	var result: Array[LineEdit] = []
	for row: Dictionary in _rows:
		result.append(row["field"])
	return result


func _row(what: String, name: String, item: String, text: String, given: Variant, unit: String) -> void:
	_grid.add_child(_label(item, item_width))
	var description: Label = _label(text, -1.0)
	description.tooltip_text = text
	description.mouse_filter = Control.MOUSE_FILTER_PASS
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.clip_text = true
	_grid.add_child(description)
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
	_rows.append({"what": what, "name": name, "field": input, "loss": loss})


func _label(text: String, width: float) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.custom_minimum_size.x = maxf(width, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width < 0.0 else Control.SIZE_FILL
	return label
