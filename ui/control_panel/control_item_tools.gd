class_name ControlItemTools
extends RefCounted
## The editing tools of the push buttons, switches and lamps on one panel (a
## control station or a switchboard door, see
## [method SchematicDocument.control_panels]): buttons that add items, the
## fields of the selected item, and the controls they are made of. Every
## change goes to [member edit] as one edit of the document.

var document: SchematicDocument
## Index of the panel in [method SchematicDocument.control_panels].
var panel: int = -1
## Where the tools are put.
var list: VBoxContainer
## The tools edit (false while simulating: text fields left then commit nothing).
var editing: bool = false
## Called with a change (a Callable taking the document).
var edit: Callable
## Called with the item to select after a change (-1 for none).
var select: Callable
var _swatches: Dictionary[String, Texture2D] = {}


## Buttons that add a push button, a switch or a lamp to the panel.
func add_buttons() -> void:
	var b: int = panel
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var titles: PackedStringArray = [tr("Button"), tr("Switch"), tr("Lamp")]
	var tips: PackedStringArray = [tr("Add a push button"), tr("Add a switch"), tr("Add a signal lamp")]
	for kind: int in 3:
		var add: Button = make_button(titles[kind], "plus")
		add.tooltip_text = tips[kind]
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add.pressed.connect(func() -> void:
			commit_pending()
			select.call(document.control_panels()[b].items.size())
			edit.call(func(doc: SchematicDocument) -> void: doc.add_control_item(b, kind as ControlBoxItem.Kind)))
		row.add_child(add)
	list.add_child(row)


## Button that puts every push button, switch and lamp not on a station or
## a door yet on the panel; [param tooltip] says so.
func add_all_button(tooltip: String) -> void:
	var b: int = panel
	var add_all: Button = make_button(tr("Add all the others"), "panel")
	add_all.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_all.tooltip_text = tooltip
	add_all.disabled = not _has_unlisted_devices()
	add_all.pressed.connect(func() -> void:
		commit_pending()
		edit.call(func(doc: SchematicDocument) -> void: doc.fill_control_box(b)))
	list.add_child(add_all)


## Fields of item [param i]: kind, device, plate text, colour, lamp inside it.
func item_editor(i: int) -> void:
	var b: int = panel
	var item: ControlBoxItem = document.control_panels()[b].items[i]
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "FunctionCard"
	list.add_child(card)
	var fields: VBoxContainer = VBoxContainer.new()
	fields.add_theme_constant_override("separation", 4)
	card.add_child(fields)
	var apply: Callable = func(changed: Dictionary) -> void:
		edit.call(func(doc: SchematicDocument) -> void: doc.set_control_item(b, i, changed))
	# The item as it is now, with a plate text typed before committed first
	# (the tools take no focus, so the text field still has it).
	var data: Callable = func() -> Dictionary:
		commit_pending()
		return document.control_panels()[b].items[i].to_data()

	make_caption(fields, tr("Kind"))
	var kinds: OptionButton = make_option(fields)
	for t: String in StationPanel.KIND_TITLES:
		kinds.add_item(tr(t))
	kinds.select(item.kind)
	kinds.item_selected.connect(func(k: int) -> void:
		# The first device of the new kind not on a station or door yet: one
		# already on one would show twice.
		var changed: Dictionary = data.call()
		var listed: Dictionary[String, bool] = document.control_panel_devices()
		changed["kind"] = ControlBoxItem.KINDS[k]
		changed["designation"] = ""
		for d: String in document.control_devices(k):
			if not listed.has(d):
				changed["designation"] = d
				break
		changed["color"] = ControlBoxItem.default_color(k as ControlBoxItem.Kind)
		apply.call(changed))

	make_caption(fields, tr("Device"))
	var devices: PackedStringArray = document.control_devices(item.kind)
	var choices: PackedStringArray = PackedStringArray([""])
	choices.append_array(devices)
	if not item.designation.is_empty() and not devices.has(item.designation):
		choices.append(item.designation)
	var device: OptionButton = make_option(fields)
	for d: String in choices:
		if d.is_empty():
			device.add_item(tr("None"))
		elif devices.has(d):
			device.add_item(d)
		else:
			device.add_item(tr("%s (not in the schematic)") % d)
	device.select(choices.find(item.designation))
	device.item_selected.connect(func(k: int) -> void:
		var changed: Dictionary = data.call()
		changed["designation"] = choices[k]
		apply.call(changed))

	make_caption(fields, tr("Text on the plate"))
	fields.add_child(make_text_field(item.label, item.designation, func(text: String) -> void:
		# The field also commits when it goes with the tools after another
		# change: then the item may have moved, or be gone.
		var at: int = document.control_panels()[b].items.find(item) if b < document.control_panels().size() else -1
		if at < 0:
			return
		var changed: Dictionary = item.to_data()
		changed["label"] = text
		edit.call(func(doc: SchematicDocument) -> void: doc.set_control_item(b, at, changed))))

	make_caption(fields, tr("Colour"))
	# Lamps and lit caps are never black.
	var palette: PackedStringArray = ControlBoxItem.LAMP_COLORS if item.kind == ControlBoxItem.Kind.LAMP or not item.lamp.is_empty() else ControlBoxItem.COLORS
	fields.add_child(make_color_choice(palette, item.color, func(color: String) -> void:
		var changed: Dictionary = data.call()
		changed["color"] = color
		apply.call(changed)))

	if item.kind != ControlBoxItem.Kind.LAMP:
		make_caption(fields, tr("Signal lamp inside (illuminated)"))
		var lamps: PackedStringArray = PackedStringArray([""])
		lamps.append_array(document.control_devices(ControlBoxItem.Kind.LAMP))
		if not item.lamp.is_empty() and not lamps.has(item.lamp):
			lamps.append(item.lamp)
		var lamp: OptionButton = make_option(fields)
		for d: String in lamps:
			lamp.add_item(tr("None") if d.is_empty() else d)
		lamp.select(lamps.find(item.lamp))
		lamp.item_selected.connect(func(k: int) -> void:
			var changed: Dictionary = data.call()
			changed["lamp"] = lamps[k]
			apply.call(changed))

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 2)
	fields.add_child(actions)
	var count: int = document.control_panels()[b].items.size()
	for step: int in [-1, 1]:
		var move: Button = make_tool("arrow_left" if step < 0 else "arrow_right", tr("Move it one place back") if step < 0 else tr("Move it one place on"))
		move.disabled = i + step < 0 or i + step >= count
		move.pressed.connect(func() -> void:
			commit_pending()
			select.call(i + step)
			edit.call(func(doc: SchematicDocument) -> void: doc.move_control_item(b, i, step)))
		actions.add_child(move)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var remove: Button = make_button(tr("Remove"), "delete")
	remove.pressed.connect(func() -> void:
		commit_pending()
		select.call(-1)
		edit.call(func(doc: SchematicDocument) -> void: doc.remove_control_item(b, i)))
	actions.add_child(remove)


## Commits a text typed into a field of the tools and not yet entered, before
## another change of the panel.
func commit_pending() -> void:
	if list == null or not list.is_inside_tree():
		return
	var focused: Control = list.get_viewport().gui_get_focus_owner()
	if focused != null and list.is_ancestor_of(focused):
		focused.release_focus()


func _has_unlisted_devices() -> bool:
	var listed: Dictionary[String, bool] = document.control_panel_devices()
	for kind: int in 3:
		for designation: String in document.control_devices(kind):
			if not listed.has(designation):
				return true
	return false


# --- Controls ---------------------------------------------------------------------

func make_caption(parent: Control, text: String) -> void:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.theme_type_variation = "CaptionLabel"
	label.text = text
	parent.add_child(label)


func make_option(parent: Control) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	option.focus_mode = Control.FOCUS_NONE
	parent.add_child(option)
	return option


func make_button(text: String, icon_name: String) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.focus_mode = Control.FOCUS_NONE
	button.text = text
	button.icon = AppTheme.icon(icon_name)
	return button


func make_tool(icon_name: String, tooltip: String) -> Button:
	var button: Button = make_button("", icon_name)
	button.theme_type_variation = "ToolButton"
	button.tooltip_text = tooltip
	return button


## Line edit that reports its text once, when Enter is pressed or it loses
## focus, and only when the text changed. Not when it loses focus because
## the simulation started: the panel then shows the simulation's copy of
## the document, which is never edited.
func make_text_field(text: String, placeholder: String, on_commit: Callable) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	field.text = text
	field.placeholder_text = placeholder
	var state: Dictionary = {"done": false}
	var edited: SchematicDocument = document
	var commit: Callable = func() -> void:
		if state["done"] or field.text.strip_edges() == text or not editing or document != edited:
			return
		state["done"] = true
		on_commit.call(field.text.strip_edges())
	field.text_submitted.connect(func(_submitted: String) -> void: commit.call())
	field.focus_exited.connect(commit)
	return field


## Colour choice with a round swatch before each name.
func make_color_choice(names: PackedStringArray, current: String, on_chosen: Callable) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	option.focus_mode = Control.FOCUS_NONE
	for color_name: String in names:
		option.add_icon_item(_swatch(color_name), tr(ControlBoxItem.COLOR_TITLES[ControlBoxItem.COLORS.find(color_name)]))
	option.select(maxi(names.find(current), 0))
	option.item_selected.connect(func(k: int) -> void: on_chosen.call(names[k]))
	return option


func _swatch(color_name: String) -> Texture2D:
	if not _swatches.has(color_name):
		var hex: String = "#" + ControlBoxView.COLORS[color_name].to_html(false)
		var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><circle cx="8" cy="8" r="6.5" fill="%s" stroke="#808080" stroke-width="1"/></svg>' % hex
		_swatches[color_name] = DPITexture.create_from_string(svg)
	return _swatches[color_name]
