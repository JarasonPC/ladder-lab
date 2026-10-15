class_name SchematicEditor
extends Node2D
## Edits the document shown by a [SchematicView] (in editing mode).
##
## Select: click a symbol or wire (Shift adds), drag symbols to move them,
## drag on empty space for a selection box.
## Wire: click a terminal to start, click empty cells to add corners, finish on
## a terminal or on a wire (a junction is inserted there).
## Place: choose a palette entry, click to place (repeatable), R/F turn the
## symbol before placing. Right click or Esc ends the current tool.
## Right click opens a menu with "Change to" (switch a contact, coil or load
## to another type, keeping its wires), rotate, mirror, cut/copy/paste, delete.
## Keys: R rotate, F mirror, Delete remove, Ctrl+Z undo, Ctrl+Y redo,
## Ctrl+X/C/V cut/copy/paste, Ctrl+A select all.

## The document content changed (for unsaved-changes tracking).
signal edited
signal document_replaced(doc: SchematicDocument)
signal selection_changed(component: CircuitComponent)
signal hint_changed(text: String)

enum Tool { SELECT, PLACE, WIRE }

const G: float = float(SymbolGeometry.GRID)
const CLICK_SLOP: float = 6.0

enum MenuId { ROTATE, MIRROR, FLIP, CUT, COPY, PASTE, DELETE, SELECT_ALL }
const SELECTION_COLOR := Color("2d7ff9")
const PREVIEW_COLOR := Color(0.18, 0.5, 0.98, 0.8)

var view: SchematicView
var history: UndoHistory = UndoHistory.new()
var active: bool = false:
	set(value):
		active = value
		_cancel_tool()
		visible = value

var tool: Tool = Tool.SELECT
var selected_components: Dictionary[String, bool] = {}
var selected_wires: Dictionary[int, bool] = {}

var _mouse_cell: Vector2i = Vector2i.ZERO
var _mouse_point: Vector2 = Vector2.ZERO
# Placing.
var _template: Dictionary = {}
var _ghost: SchematicSymbol = null
var _ghost_rotation: int = 0
var _ghost_mirrored: bool = false
# Wiring: start terminal and fixed points so far (start cell first).
var _wire_start: String = ""
var _wire_points: Array[Vector2i] = []
# Dragging selected symbols.
var _dragging: bool = false
var _drag_origin: Vector2i = Vector2i.ZERO
var _drag_applied: Vector2i = Vector2i.ZERO
var _drag_recorded: bool = false
## Dragging one segment of a wire sideways (tidying the route).
var _wire_drag: int = -1
var _wire_drag_segment: int = -1
var _wire_drag_points: Array[Vector2i] = []
var _wire_drag_origin: Vector2i = Vector2i.ZERO
var _wire_drag_recorded: bool = false
## Dragging a wire number: Vector2i(wire, end), or (-1, -1).
var _number_drag: Vector2i = Vector2i(-1, -1)
var _number_drag_offset: Vector2 = Vector2.ZERO
var _number_drag_origin: Vector2 = Vector2.ZERO
var _number_drag_recorded: bool = false
## Editing a marking in place (double click): the field and what it edits,
## {"component": id, "kind": ..., "index": ...} or {"wire": index}.
var _inline: LineEdit = null
var _inline_target: Dictionary = {}
var _inline_layer: CanvasLayer = null
## The marking clicked last, highlighted: {"component": id, "kind": ..., "index": ...}.
var selected_marking: Dictionary = {}
## Dragging the selected marking.
var _marking_drag: bool = false
var _marking_drag_origin: Vector2 = Vector2.ZERO
var _marking_drag_offset: Vector2 = Vector2.ZERO
var _marking_drag_recorded: bool = false
# Selection box.
var _boxing: bool = false
var _box_origin: Vector2 = Vector2.ZERO
# Clipboard: data from SchematicDocument.extract and its top-left cell.
var _clipboard: Dictionary = {}
var _clipboard_origin: Vector2i = Vector2i.ZERO
# Context menu.
var _right_press: Vector2 = Vector2.ZERO
var _menu: PopupMenu
var _change_menu: PopupMenu
var _change_options: Array[Dictionary] = []


func _ready() -> void:
	_menu = PopupMenu.new()
	_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_menu)
	_change_menu = PopupMenu.new()
	_change_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_menu.add_child(_change_menu)
	_menu.id_pressed.connect(_on_menu_id)
	_change_menu.id_pressed.connect(func(i: int) -> void:
		if selected_components.size() == 1:
			change_type(selected_components.keys()[0], _change_options[i]["template"]))


## Palette entries of the same family as [param c] (switching elements,
## coils, loads or supplies) with as many terminals; empty for junctions.
static func type_options(c: CircuitComponent) -> Array[Dictionary]:
	var current: Dictionary = DocumentSerializer.component_to_dict(c)
	var family: String = _family(current["type"])
	var result: Array[Dictionary] = []
	if family.is_empty():
		return result
	var terminals: int = c.get_terminal_names().size()
	for entry: Dictionary in Palette.ENTRIES:
		if _family(entry["template"]["type"]) != family:
			continue
		var data: Dictionary = entry["template"].duplicate()
		data["designation"] = str(data.get("conductor", "X1"))
		if current.has("poles") and not data.has("poles"):
			data["poles"] = current["poles"]
		var trial: CircuitComponent = DocumentSerializer.component_from_dict(data)
		# A time relay with its control input S can still turn into a coil
		# (the S wire goes); otherwise only types with as many terminals.
		if trial != null and (trial.get_terminal_names().size() == terminals or family == "coil"):
			result.append(entry)
	return result


## True if [param c] is what [param template] would create.
static func matches_template(c: CircuitComponent, template: Dictionary) -> bool:
	var d: Dictionary = DocumentSerializer.component_to_dict(c)
	if template["type"] == "timer":
		# One multifunction time relay, whatever its function and inputs.
		return c is TimerRelay
	for key: String in template:
		if key == "delay":
			continue
		if d.get(key, false) != template[key]:
			return false
	if d.get("holder", false) != template.get("holder", false):
		return false
	return true


static func _family(kind: String) -> String:
	match kind:
		"push_button", "latching_switch", "contact":
			return "switching"
		"coil", "timer":
			return "coil"
		"changeover":
			return "changeover"
		"lamp", "motor":
			return "load"
		"fuse", "breaker":
			return "protection"
		"motor3":
			return "motor3"
		"overload_contact":
			return "overload_contact"
		"supply":
			return "supply"
	return ""


func document() -> SchematicDocument:
	return view.document


# --- Commands -------------------------------------------------------------------

## Starts placing components made from [param template].
func begin_place(template: Dictionary) -> void:
	_cancel_tool()
	tool = Tool.PLACE
	_template = template
	_ghost_rotation = 3 if document().horizontal else 0
	_ghost_mirrored = document().horizontal
	_rebuild_ghost()
	_emit_hint()


func undo() -> void:
	if not history.can_undo():
		return
	_cancel_tool()
	_restore(history.undo(DocumentSerializer.to_dict(document())))


func redo() -> void:
	if not history.can_redo():
		return
	_cancel_tool()
	_restore(history.redo(DocumentSerializer.to_dict(document())))


func delete_selection() -> void:
	if selected_components.is_empty() and selected_wires.is_empty():
		return
	_record()
	var doc: SchematicDocument = document()
	var wires: Array = selected_wires.keys()
	wires.sort()
	wires.reverse()
	for w: int in wires:
		doc.remove_wire(w)
	for id: String in selected_components:
		doc.remove_component(id)
	doc.cleanup_junctions()
	_clear_selection()
	_changed()


func rotate_selection() -> void:
	if tool == Tool.PLACE:
		_ghost_rotation = posmod(_ghost_rotation + 1, 4)
		_rebuild_ghost()
		return
	if selected_components.is_empty():
		return
	_record()
	for id: String in selected_components:
		document().rotate_component(id)
	_changed()


func mirror_selection() -> void:
	if tool == Tool.PLACE:
		# Left to right as seen: along the axis of a horizontal symbol.
		_ghost_mirrored = not _ghost_mirrored
		if _ghost_rotation % 2 == 1:
			_ghost_rotation = (_ghost_rotation + 2) % 4
		_rebuild_ghost()
		return
	if selected_components.is_empty():
		return
	_record()
	for id: String in selected_components:
		document().mirror_component(id)
	_changed()


## Mirrors the selection (or the part being placed) top to bottom.
func flip_selection() -> void:
	if tool == Tool.PLACE:
		_ghost_mirrored = not _ghost_mirrored
		if _ghost_rotation % 2 == 0:
			_ghost_rotation = (_ghost_rotation + 2) % 4
		_rebuild_ghost()
		return
	if selected_components.is_empty():
		return
	_record()
	for id: String in selected_components:
		document().flip_component(id)
	_changed()


## Applies properties edited in the [PropertiesPanel]. Returns an error text,
## or "" on success.
func apply_properties(component_id: String, data: Dictionary) -> String:
	var doc: SchematicDocument = document()
	var old: CircuitComponent = doc.circuit.get_component(component_id)
	if old == null:
		return ""
	if data["type"] == "supply":
		var conductor: PowerSupply.Conductor = _conductor(data)
		if conductor != (old as PowerSupply).conductor:
			data["designation"] = doc.next_supply_designation(conductor)
	data["designation"] = String(data.get("designation", "x")).strip_edges()
	if String(data["designation"]).is_empty():
		return tr("The designation must not be empty.")
	if String(data["designation"]).contains(":") or String(data["designation"]).contains(" "):
		return tr("A designation must not contain spaces or colons.")
	if old is Coil and data.get("kind", "") != "":
		# A contactor turned into a relay (or back) takes the new kind's
		# default times, unless its times had been set by hand.
		var coil: Coil = old as Coil
		var new_kind: Coil.Kind = Coil.Kind.RELAY if data["kind"] == "relay" else Coil.Kind.CONTACTOR
		if new_kind != coil.kind and is_equal_approx(coil.pick_up_time, Coil.DEFAULT_PICK_UP[coil.kind]) and is_equal_approx(coil.drop_out_time, Coil.DEFAULT_DROP_OUT[coil.kind]):
			data.erase("pick_up")
			data.erase("drop_out")
		# A KM coil turned into a relay becomes KA (and back), as long as no
		# contacts carry its designation yet (they would lose their coil).
		var old_prefix: String = "KA" if coil.kind == Coil.Kind.RELAY else "KM"
		var new_prefix: String = "KA" if new_kind == Coil.Kind.RELAY else "KM"
		if new_kind != coil.kind and not (old is TimerRelay) and data["designation"] == old.designation and SchematicDocument._designation_prefix(old.designation) == old_prefix:
			var shared: bool = false
			for c: CircuitComponent in doc.circuit.get_components():
				if c != old and c.designation == old.designation:
					shared = true
			if not shared:
				data["designation"] = doc.next_designation(new_prefix)
	_follow_device(data, old.designation)
	var replacement: CircuitComponent = DocumentSerializer.component_from_dict(data)
	if replacement == null:
		return tr("Terminal names must all be different, without spaces or colons.")
	var snapshot: Dictionary = DocumentSerializer.to_dict(doc)
	if not _can_replace(old, replacement):
		return tr("%s is already used in this circuit.") % replacement.id
	if not _designation_free(old, replacement):
		return tr("%s is already the designation of another device.") % replacement.designation
	history.record(snapshot)
	doc.replace_component(component_id, replacement)
	if replacement.designation != old.designation and (old is Coil or old is OverloadRelay):
		# The device was renamed: its contacts go along with it.
		for part: CircuitComponent in doc.circuit.get_components():
			if part.designation != old.designation or _designation_group(part) != _designation_group(old):
				continue
			var part_data: Dictionary = DocumentSerializer.component_to_dict(part)
			part_data["designation"] = replacement.designation
			var renamed: CircuitComponent = DocumentSerializer.component_from_dict(part_data)
			if renamed != null and _can_replace(part, renamed):
				doc.replace_component(part.id, renamed)
	selected_components.clear()
	selected_components[replacement.id] = true
	_changed()
	return ""


## Turns a component into another type of the same family (e.g. a switch NO
## into a delayed contact NC), keeping its place and wires. Designations
## follow the new type: a contact belongs to a coil, a button gets an S name.
## Returns an error text, or "" on success.
func change_type(component_id: String, template: Dictionary) -> String:
	var doc: SchematicDocument = document()
	var old: CircuitComponent = doc.circuit.get_component(component_id)
	if old == null or matches_template(old, template):
		return ""
	var data: Dictionary = template.duplicate()
	var old_data: Dictionary = DocumentSerializer.component_to_dict(old)
	if old_data.has("poles") and not data.has("poles"):
		data["poles"] = old_data["poles"]
	match _family(template["type"]):
		"switching":
			var element: SwitchingElement = old as SwitchingElement
			var to_contact: bool = template["type"] == "contact"
			var designation: String = old.designation if (old is Contact) == to_contact else _new_designation(template)
			if to_contact and template.get("delayed", false) and not (doc.circuit.get_coil(designation) is TimerRelay):
				for c: CircuitComponent in doc.circuit.get_components():
					if c is TimerRelay:
						designation = c.designation
						break
			data["designation"] = designation
			data["sequence"] = element.sequence
			var trial: CircuitComponent = DocumentSerializer.component_from_dict(data)
			if not _can_replace(old, trial):
				data["sequence"] = doc.next_contact_sequence(designation)
		"changeover":
			var changeover: ChangeoverContact = old as ChangeoverContact
			var target: String = old.designation
			if template.get("delayed", false) and not (doc.circuit.get_coil(target) is TimerRelay):
				for c: CircuitComponent in doc.circuit.get_components():
					if c is TimerRelay:
						target = c.designation
						break
			data["designation"] = target
			data["sequence"] = changeover.sequence
			if not _can_replace(old, DocumentSerializer.component_from_dict(data)):
				data["sequence"] = doc.next_contact_sequence(target)
		"coil":
			data["designation"] = old.designation
			if old is TimerRelay and template["type"] == "timer":
				data["delay"] = (old as TimerRelay).delay
		"load":
			data["designation"] = _new_designation(template)
		_:
			data["designation"] = old.designation
	return apply_properties(component_id, data)


func copy_selection() -> void:
	if selected_components.is_empty():
		return
	var ids: PackedStringArray = PackedStringArray(selected_components.keys())
	_clipboard = document().extract(ids)
	var first: bool = true
	for id: String in ids:
		var cell: Vector2i = document().get_placement(id).cell
		_clipboard_origin = cell if first else Vector2i(mini(_clipboard_origin.x, cell.x), mini(_clipboard_origin.y, cell.y))
		first = false


func cut_selection() -> void:
	copy_selection()
	delete_selection()


## Pastes the clipboard with its top-left corner at the mouse cell.
func paste() -> void:
	if _clipboard.is_empty():
		return
	_record()
	var ids: PackedStringArray = document().insert(_clipboard, _mouse_cell - _clipboard_origin)
	_clear_selection()
	for id: String in ids:
		selected_components[id] = true
	_changed()


func select_all() -> void:
	_cancel_tool()
	for c: CircuitComponent in document().circuit.get_components():
		selected_components[c.id] = true
	for w: int in document().get_wire_count():
		selected_wires[w] = true
	_selection_updated()


func has_clipboard() -> bool:
	return not _clipboard.is_empty()


# --- Input ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not active or view.document == null:
		return
	if event is InputEventMouseMotion:
		_update_mouse()
		_on_mouse_moved()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		_update_mouse()
		if mb.pressed:
			# Keys like R and Delete must reach the editor, not a text field
			# in the properties panel that kept the focus.
			get_viewport().gui_release_focus()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and mb.double_click and (tool == Tool.SELECT or (tool == Tool.WIRE and _wire_points.size() <= 1)):
				if edit_marking_at(_mouse_point):
					get_viewport().set_input_as_handled()
					return
			if mb.pressed:
				_on_left_pressed(mb.shift_pressed)
			else:
				_on_left_released(mb.shift_pressed)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_press = mb.position
				if tool != Tool.SELECT:
					_cancel_tool()
			elif tool == Tool.SELECT and mb.position.distance_to(_right_press) < CLICK_SLOP:
				_open_context_menu()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		_on_key(event as InputEventKey)


func _on_key(key: InputEventKey) -> void:
	var handled: bool = true
	var ctrl: bool = key.ctrl_pressed or key.meta_pressed
	match key.keycode:
		KEY_Z when ctrl and key.shift_pressed:
			redo()
		KEY_Z when ctrl:
			undo()
		KEY_Y when ctrl:
			redo()
		KEY_C when ctrl:
			copy_selection()
		KEY_X when ctrl:
			cut_selection()
		KEY_V when ctrl:
			paste()
		KEY_A when ctrl:
			select_all()
		KEY_R:
			rotate_selection()
		KEY_F when key.shift_pressed:
			flip_selection()
		KEY_F, KEY_M:
			mirror_selection()
		KEY_DELETE:
			delete_selection()
		KEY_BACKSPACE:
			if tool == Tool.WIRE and _wire_points.size() > 1:
				_wire_points.remove_at(_wire_points.size() - 1)
				queue_redraw()
			else:
				delete_selection()
		KEY_ESCAPE:
			if tool != Tool.SELECT:
				_cancel_tool()
			else:
				_clear_selection()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _open_context_menu() -> void:
	var doc: SchematicDocument = document()
	var hit: CircuitComponent = doc.component_at(_mouse_point)
	if hit != null and not selected_components.has(hit.id):
		_clear_selection()
		selected_components[hit.id] = true
		_selection_updated()
	var has_selection: bool = not selected_components.is_empty() or not selected_wires.is_empty()
	_menu.clear()
	_change_menu.clear()
	_change_options.clear()
	if hit != null and selected_components.size() == 1:
		_change_options = type_options(hit)
		if _change_options.size() > 1:
			for i: int in _change_options.size():
				_change_menu.add_radio_check_item(tr(_change_options[i]["title"]), i)
				_change_menu.set_item_checked(i, matches_template(hit, _change_options[i]["template"]))
			_menu.add_submenu_node_item(tr("Change to"), _change_menu)
			_menu.add_separator()
	if not selected_components.is_empty():
		_menu.add_item(tr("Rotate"), MenuId.ROTATE, KEY_R)
		_menu.add_item(tr("Mirror left-right"), MenuId.MIRROR, KEY_F)
		_menu.add_item(tr("Mirror top-bottom"), MenuId.FLIP, KEY_MASK_SHIFT | KEY_F)
		_menu.add_separator()
		_menu.add_item(tr("Cut"), MenuId.CUT, KEY_MASK_CTRL | KEY_X)
		_menu.add_item(tr("Copy"), MenuId.COPY, KEY_MASK_CTRL | KEY_C)
	_menu.add_item(tr("Paste"), MenuId.PASTE, KEY_MASK_CTRL | KEY_V)
	_menu.set_item_disabled(_menu.get_item_index(MenuId.PASTE), _clipboard.is_empty())
	if has_selection:
		_menu.add_item(tr("Delete"), MenuId.DELETE, KEY_DELETE)
	_menu.add_separator()
	_menu.add_item(tr("Select all"), MenuId.SELECT_ALL, KEY_MASK_CTRL | KEY_A)
	_menu.reset_size()
	_menu.popup_on_parent(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i.ZERO))


func _on_menu_id(id: int) -> void:
	match id:
		MenuId.ROTATE:
			rotate_selection()
		MenuId.MIRROR:
			mirror_selection()
		MenuId.FLIP:
			flip_selection()
		MenuId.CUT:
			cut_selection()
		MenuId.COPY:
			copy_selection()
		MenuId.PASTE:
			paste()
		MenuId.DELETE:
			delete_selection()
		MenuId.SELECT_ALL:
			select_all()


func _update_mouse() -> void:
	_mouse_point = get_local_mouse_position() / G
	_mouse_cell = Vector2i(_mouse_point.round())


func _on_mouse_moved() -> void:
	match tool:
		Tool.PLACE:
			if _ghost != null:
				_ghost.position = Vector2(_mouse_cell) * G
		Tool.SELECT:
			if _dragging:
				_drag_to(_mouse_cell - _drag_origin)
			elif _wire_drag >= 0:
				_drag_wire_to(_mouse_cell - _wire_drag_origin)
			elif _number_drag.x >= 0:
				_drag_number_to(_mouse_point - _number_drag_origin)
			elif _marking_drag:
				_drag_marking_to(_mouse_point - _marking_drag_origin)
	queue_redraw()


func _on_left_pressed(shift: bool) -> void:
	var doc: SchematicDocument = document()
	match tool:
		Tool.PLACE:
			_place_at(_mouse_cell)
		Tool.WIRE:
			var key: String = doc.terminal_at(_mouse_point)
			if not key.is_empty() and key != _wire_start:
				_finish_wire(key, -1)
				return
			var w: int = doc.wire_at(_mouse_point)
			if w >= 0 and key.is_empty():
				_finish_wire("", w)
				return
			var preview: Array[Vector2i] = _preview_points()
			for i: int in range(1, preview.size()):
				if preview[i] != _wire_points[_wire_points.size() - 1]:
					_wire_points.append(preview[i])
		Tool.SELECT:
			var label: Vector2i = view.wire_number_at(_mouse_point)
			if label.x >= 0 and not shift:
				# Wire numbers can be dragged to a tidier place.
				_number_drag = label
				_number_drag_offset = doc.get_route(label.x).number_offsets[label.y]
				_number_drag_origin = _mouse_point
				_number_drag_recorded = false
				return
			var marking: Dictionary = _marking_at(_mouse_point)
			if not marking.is_empty() and not shift:
				# A click highlights the marking (and selects its part); a
				# drag moves it, a double click edits it.
				_clear_selection()
				selected_components[marking["component"]] = true
				selected_marking = marking
				var key_name: String = SchematicSymbol.marking_key(marking["kind"], marking["index"])
				_marking_drag = true
				_marking_drag_origin = _mouse_point
				_marking_drag_offset = doc.get_placement(marking["component"]).labels.get(key_name, Vector2.ZERO)
				_marking_drag_recorded = false
				_selection_updated()
				return
			var key: String = doc.terminal_at(_mouse_point, 0.3)
			var hit: CircuitComponent = doc.component_at(_mouse_point)
			if not key.is_empty() and not shift:
				_start_wire(key)
				return
			if hit != null:
				selected_marking = {}
				if shift:
					if selected_components.has(hit.id):
						selected_components.erase(hit.id)
					else:
						selected_components[hit.id] = true
				elif not selected_components.has(hit.id):
					_clear_selection()
					selected_components[hit.id] = true
				_dragging = true
				_drag_origin = _mouse_cell
				_drag_applied = Vector2i.ZERO
				_drag_recorded = false
				_selection_updated()
				return
			if not key.is_empty():
				_start_wire(key)
				return
			var w: int = doc.wire_at(_mouse_point)
			if w >= 0:
				if not shift:
					_clear_selection()
				if selected_wires.has(w) and shift:
					selected_wires.erase(w)
				else:
					selected_wires[w] = true
					# Dragging the segment under the mouse moves it sideways.
					_wire_drag = w
					_wire_drag_segment = doc.wire_segment_at(w, _mouse_point)
					_wire_drag_points = doc.wire_points(w)
					_wire_drag_origin = _mouse_cell
					_wire_drag_recorded = false
				_selection_updated()
				return
			if not shift:
				_clear_selection()
			_boxing = true
			_box_origin = _mouse_point
	queue_redraw()


func _on_left_released(shift: bool) -> void:
	if _marking_drag:
		_marking_drag = false
		if _marking_drag_recorded:
			_changed()
	if _number_drag.x >= 0:
		_number_drag = Vector2i(-1, -1)
		if _number_drag_recorded:
			_changed()
	if _wire_drag >= 0:
		_wire_drag = -1
		if _wire_drag_recorded:
			_changed()
	if _dragging:
		_dragging = false
		if _drag_recorded:
			_changed()
	if _boxing:
		_boxing = false
		var box: Rect2 = Rect2(_box_origin, Vector2.ZERO).expand(_mouse_point)
		if box.size.length() > 0.3:
			if not shift:
				_clear_selection()
			_select_in_box(box)
	queue_redraw()


# --- Tools ----------------------------------------------------------------------

func _place_at(cell: Vector2i) -> void:
	var doc: SchematicDocument = document()
	var data: Dictionary = _template.duplicate()
	data["designation"] = _new_designation(data)
	if ["contact", "changeover", "push_button", "latching_switch"].has(data["type"]):
		data["sequence"] = doc.next_contact_sequence(data["designation"])
	if data["type"] == "terminal" and str(data.get("label", "")).is_empty():
		data["label"] = str(data["designation"]).trim_prefix("X")
	_follow_device(data)
	var c: CircuitComponent = DocumentSerializer.component_from_dict(data)
	if not _can_add(c):
		hint_changed.emit(tr("%s is already used in this circuit.") % c.id)
		return
	_record()
	var on_wire: int = doc.wire_at(Vector2(cell)) if c is TerminalBlock else -1
	if on_wire >= 0:
		# A terminal placed on a wire is inserted into it.
		doc.split_wire(on_wire, cell, c)
	else:
		doc.add(c, cell, _ghost_rotation, _ghost_mirrored)
	_clear_selection()
	selected_components[c.id] = true
	_changed()
	_rebuild_ghost()


## Which parts may share a designation: a relay or contactor with its
## contacts, an overload relay with its contacts, buttons or switches of one
## actuator. Other parts have a designation of their own.
static func _designation_group(c: CircuitComponent) -> String:
	if c is OverloadRelay or c is OverloadContact:
		return "overload"
	if c is Coil or c is Contact or c is ChangeoverContact or c is MainContacts:
		return "relay"
	if c is PushButton:
		return "push_button"
	if c is LatchingSwitch:
		return "switch"
	return ""


## True when [param replacement] (replacing [param old]) may carry its
## designation: no other device has it, only parts of the same device (one
## coil, one overload relay).
func _designation_free(old: CircuitComponent, replacement: CircuitComponent) -> bool:
	var group: String = _designation_group(replacement)
	for c: CircuitComponent in document().circuit.get_components():
		if c == old or c.designation != replacement.designation:
			continue
		if group.is_empty() or _designation_group(c) != group:
			return false
		if (c is Coil and replacement is Coil) or (c is OverloadRelay and replacement is OverloadRelay):
			return false
	return true


## A contact follows the device it is designated to: a contact (or
## changeover) of a time relay KT is delayed (unless unticked later, while its
## designation stays); a contact designated like an overload relay (e.g. "F2")
## becomes its overload contact (95-96 / 97-98, drawn with the thermal
## actuator); an overload contact designated otherwise becomes a plain
## contact again. [param old_designation]: before the edit ("" when new).
func _follow_device(data: Dictionary, old_designation: String = "") -> void:
	var doc: SchematicDocument = document()
	var designation: String = str(data.get("designation", ""))
	if (data["type"] == "contact" or data["type"] == "changeover") and (not data.has("delayed") or designation != old_designation):
		data["delayed"] = doc.circuit.get_coil(designation) is TimerRelay
	var relay: OverloadRelay = doc.circuit.get_overload_relay(str(data.get("designation", "")))
	if data["type"] == "contact" and relay != null and not data.get("delayed", false):
		data["type"] = "overload_contact"
		data.erase("sequence")
		data.erase("terminals")
	elif data["type"] == "overload_contact" and relay == null:
		data["type"] = "contact"
		data["sequence"] = doc.next_contact_sequence(str(data["designation"]))
		data.erase("terminals")


func _new_designation(data: Dictionary) -> String:
	var doc: SchematicDocument = document()
	match data["type"]:
		"supply":
			return doc.next_supply_designation(_conductor(data))
		"push_button", "latching_switch":
			return doc.next_designation("S")
		"fuse", "overload_relay":
			return doc.next_designation("F")
		"breaker":
			return doc.next_designation("Q")
		"main_contacts":
			# Belongs to the selected contactor, else to the first one.
			for id: String in selected_components:
				var picked: CircuitComponent = doc.circuit.get_component(id)
				if picked is Coil and not (picked is TimerRelay):
					return picked.designation
			for c: CircuitComponent in doc.circuit.get_components():
				if c is Coil and not (c is TimerRelay) and (c as Coil).kind == Coil.Kind.CONTACTOR:
					return c.designation
			return "KM1"
		"overload_contact":
			for id: String in selected_components:
				var chosen: CircuitComponent = doc.circuit.get_component(id)
				if chosen is OverloadRelay:
					return chosen.designation
			for c: CircuitComponent in doc.circuit.get_components():
				if c is OverloadRelay:
					return c.designation
			return "F1"
		"contact", "changeover":
			# Belongs to the selected coil (or overload relay), else to the
			# first coil of the right kind.
			var want_timer: bool = data.get("delayed", false)
			for id: String in selected_components:
				var relay: CircuitComponent = doc.circuit.get_component(id)
				if relay is OverloadRelay and data["type"] == "contact" and not want_timer:
					return relay.designation
			for id: String in selected_components:
				var selected: CircuitComponent = doc.circuit.get_component(id)
				if selected is Coil and (selected is TimerRelay or not want_timer):
					return selected.designation
			for c: CircuitComponent in doc.circuit.get_components():
				if c is Coil and (c is TimerRelay) == want_timer:
					return c.designation
			return "KT1" if want_timer else "KM1"
		"coil":
			# Contactor KM, auxiliary (control) relay KA.
			return doc.next_designation("KA" if data.get("kind", "contactor") == "relay" else "KM")
		"timer":
			return doc.next_designation("KT")
		"lamp":
			return doc.next_designation("H")
		"motor", "motor3":
			return doc.next_designation("M")
		"terminal":
			return doc.next_designation("X")
	return doc.next_designation("X")


static func _conductor(data: Dictionary) -> PowerSupply.Conductor:
	return maxi(DocumentSerializer.CONDUCTORS.find(str(data.get("conductor", "L"))), 0) as PowerSupply.Conductor


func _start_wire(key: String) -> void:
	_clear_selection()
	tool = Tool.WIRE
	_wire_start = key
	_wire_points = [document().terminal_cell(key)]
	_emit_hint()
	queue_redraw()


## Finishes the wire on terminal [param key], or on wire [param wire_index]
## (splitting it with a junction).
func _finish_wire(key: String, wire_index: int) -> void:
	var doc: SchematicDocument = document()
	_record()
	var end_key: String = key
	var preview: Array[Vector2i] = _preview_points()
	if wire_index >= 0:
		var cell: Vector2i = doc.wire_cell_near(wire_index, _mouse_point)
		preview = _route_to(cell)
		end_key = doc.split_wire(wire_index, cell)
	if end_key.is_empty() or end_key == _wire_start:
		history.discard_last()
		_cancel_tool()
		return
	var points: Array[Vector2i] = _wire_points.duplicate()
	for i: int in range(1, preview.size()):
		points.append(preview[i])
	points[points.size() - 1] = doc.terminal_cell(end_key)
	var clean: Array[Vector2i] = SchematicDocument.orthogonalize(points, doc.terminal_axis(_wire_start), doc.terminal_axis(end_key))
	doc.connect_terminals(_wire_start, end_key, clean.slice(1, clean.size() - 1))
	tool = Tool.SELECT
	_wire_start = ""
	_wire_points.clear()
	_changed()
	_emit_hint()


## Points from the last fixed wire point to the mouse cell, with one elbow.
func _preview_points() -> Array[Vector2i]:
	var target: Vector2i = _mouse_cell
	var key: String = document().terminal_at(_mouse_point)
	if not key.is_empty():
		target = document().terminal_cell(key)
	return _route_to(target)


func _route_to(target: Vector2i) -> Array[Vector2i]:
	var last: Vector2i = _wire_points[_wire_points.size() - 1]
	var result: Array[Vector2i] = [last]
	if last.x != target.x and last.y != target.y:
		var vertical_first: bool
		if _wire_points.size() == 1:
			vertical_first = document().terminal_axis(_wire_start) != SchematicDocument.AXIS_HORIZONTAL
		else:
			var prev: Vector2i = _wire_points[_wire_points.size() - 2]
			# Continue straight on from the previous segment.
			vertical_first = prev.x == last.x
		result.append(Vector2i(last.x, target.y) if vertical_first else Vector2i(target.x, last.y))
	if target != last:
		result.append(target)
	return result


func _drag_to(delta: Vector2i) -> void:
	if delta == _drag_applied or selected_components.is_empty():
		return
	if not _drag_recorded:
		_record()
		_drag_recorded = true
	document().move_components(PackedStringArray(selected_components.keys()), delta - _drag_applied)
	_drag_applied = delta
	view.rebuild()


## Numbers the net of wire [param index] (undoable).
func set_wire_number(index: int, number: String) -> void:
	_record()
	document().set_wire_number(index, number)
	_changed()


## Numbers all nets automatically (undoable).
func number_wires() -> void:
	_record()
	document().number_wires()
	_changed()


func _drag_wire_to(offset: Vector2i) -> void:
	if _wire_drag_segment < 0:
		return
	if not _wire_drag_recorded:
		if offset == Vector2i.ZERO:
			return
		_record()
		_wire_drag_recorded = true
	document().drag_wire_segment(_wire_drag, _wire_drag_points, _wire_drag_segment, offset)
	view.refresh_layout()
	queue_redraw()


## Opens a field over the marking at grid point [param point] to edit it in
## place: a wire number, a designation, a terminal name, a lamp label or a
## terminal label. On a part without a marking there, its designation (lamp:
## its label, terminal: its label); on a wire, its number. Returns false when
## there is nothing to edit.
func edit_marking_at(point: Vector2) -> bool:
	var doc: SchematicDocument = document()
	var pixel: Vector2 = point * G
	var number: Vector2i = view.wire_number_at(point)
	if number.x >= 0:
		return _open_inline({"wire": number.x}, doc.get_route(number.x).number, pixel)
	var marking: Dictionary = _marking_at(point)
	if not marking.is_empty():
		return _edit_marking(doc.circuit.get_component(marking["component"]), marking["kind"], marking["index"])
	var hit: CircuitComponent = doc.component_at(point)
	if hit != null:
		var kind: String = "designation"
		if hit is Lamp:
			kind = "purpose"
		elif hit is TerminalBlock:
			kind = "label"
		return _edit_marking(hit, kind, -1)
	var w: int = doc.wire_at(point)
	if w >= 0:
		return _open_inline({"wire": w}, doc.get_route(w).number, pixel)
	return false


## The marking written at grid point [param point]:
## {"component": id, "kind": ..., "index": ...}, or {}.
func _marking_at(point: Vector2) -> Dictionary:
	var pixel: Vector2 = point * G
	for c: CircuitComponent in document().circuit.get_components():
		var symbol: SchematicSymbol = view.get_symbol(c.id)
		if symbol == null:
			continue
		for m: Array in symbol.marking_rects:
			var rect: Rect2 = (m[2] as Rect2).grow(2.0)
			if rect.has_point(pixel - symbol.position):
				return {"component": c.id, "kind": m[0], "index": m[1]}
	return {}


func _edit_marking(c: CircuitComponent, kind: String, index: int) -> bool:
	if c is Junction or c is PowerSupply:
		return false
	if kind == "terminal" and c is TimerRelay and index < 2:
		# A1-A2 of a time relay are fixed; only its control input is renamed.
		hint_changed.emit(tr("A1 and A2 of a time relay do not change."))
		return false
	var text: String = c.designation
	match kind:
		"terminal":
			text = c.get_terminal_names()[index]
		"purpose":
			text = (c as Lamp).purpose
		"label":
			text = (c as TerminalBlock).label
	var symbol: SchematicSymbol = view.get_symbol(c.id)
	var rect: Rect2 = symbol.marking_rect(kind, index)
	var at: Vector2 = symbol.position + (rect.position if rect.has_area() else Vector2.ZERO)
	if not rect.has_area() and kind == "purpose":
		at = symbol.position + symbol.marking_rect("designation").position - Vector2(0, 18)
	return _open_inline({"component": c.id, "kind": kind, "index": index}, text, at)


func _open_inline(target: Dictionary, text: String, at: Vector2) -> bool:
	_close_inline()
	if tool != Tool.SELECT:
		_cancel_tool()
	_inline_target = target
	_inline = LineEdit.new()
	_inline.text = text
	_inline.select_all_on_focus = true
	# On a screen layer with its font sized to the zoom, so the text stays
	# sharp (scaled with the drawing it would be blurred).
	if _inline_layer == null:
		_inline_layer = CanvasLayer.new()
		_inline_layer.layer = 5
		add_child(_inline_layer)
	var to_screen: Transform2D = get_global_transform_with_canvas()
	var zoom: float = to_screen.get_scale().x
	var font_size: int = int(clampf(13.0 * zoom, 11.0, 48.0))
	_inline.position = to_screen * (at - Vector2(4, 4))
	_inline.custom_minimum_size = Vector2(maxf(60.0, 0.75 * font_size * (text.length() + 3)), 0)
	_inline.add_theme_font_size_override("font_size", font_size)
	_inline_layer.add_child(_inline)
	_inline.text_submitted.connect(func(value: String) -> void: _commit_inline(value))
	_inline.focus_exited.connect(func() -> void:
		if _inline != null:
			_commit_inline(_inline.text))
	_inline.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
			_close_inline()
			get_viewport().set_input_as_handled())
	_inline.grab_focus()
	_inline.select_all()
	return true


func _close_inline() -> void:
	if _inline == null:
		return
	var field: LineEdit = _inline
	_inline = null
	_inline_target = {}
	field.queue_free()


func _commit_inline(value: String) -> void:
	var target: Dictionary = _inline_target
	_close_inline()
	value = value.strip_edges()
	if target.has("wire"):
		if target["wire"] < document().get_wire_count() and value != document().get_route(target["wire"]).number:
			set_wire_number(target["wire"], value)
		return
	var c: CircuitComponent = document().circuit.get_component(target.get("component", ""))
	if c == null:
		return
	var data: Dictionary = DocumentSerializer.component_to_dict(c)
	match target["kind"]:
		"designation":
			value = value.trim_prefix("-")
			if value == c.designation:
				return
			data["designation"] = value
		"terminal":
			var names: Array = Array(c.get_terminal_names())
			if value == names[target["index"]]:
				return
			names[target["index"]] = value
			data["terminals"] = names
		"purpose":
			data["purpose"] = value
		"label":
			data["label"] = value
	var error: String = apply_properties(c.id, data)
	if not error.is_empty():
		hint_changed.emit(error)


## Moves the selected marking, in steps of a tenth of a cell.
func _drag_marking_to(delta: Vector2) -> void:
	if not _marking_drag_recorded:
		if delta.length() < 0.1:
			return
		_record()
		_marking_drag_recorded = true
	var offset: Vector2 = ((_marking_drag_offset + delta) * 10.0).round() / 10.0
	var id: String = selected_marking["component"]
	document().set_label_offset(id, SchematicSymbol.marking_key(selected_marking["kind"], selected_marking["index"]), offset)
	var symbol: SchematicSymbol = view.get_symbol(id)
	if symbol != null:
		symbol.queue_redraw()
	queue_redraw()


## Moves the dragged wire number, in steps of a tenth of a cell.
func _drag_number_to(delta: Vector2) -> void:
	if not _number_drag_recorded:
		if delta.length() < 0.1:
			return
		_record()
		_number_drag_recorded = true
	var offset: Vector2 = ((_number_drag_offset + delta) * 10.0).round() / 10.0
	document().set_wire_number_offset(_number_drag.x, _number_drag.y, offset)
	view.refresh_layout()


func _select_in_box(box: Rect2) -> void:
	var doc: SchematicDocument = document()
	for c: CircuitComponent in doc.circuit.get_components():
		if box.intersects(doc.component_body(c)):
			selected_components[c.id] = true
	for w: int in doc.get_wire_count():
		var inside: bool = true
		for p: Vector2i in doc.wire_points(w):
			if not box.has_point(Vector2(p)):
				inside = false
				break
		if inside:
			selected_wires[w] = true
	_selection_updated()


func _cancel_tool() -> void:
	tool = Tool.SELECT
	_wire_start = ""
	_wire_points.clear()
	_dragging = false
	_boxing = false
	if _ghost != null:
		_ghost.free()
		_ghost = null
	_emit_hint()
	queue_redraw()


func _rebuild_ghost() -> void:
	if _ghost != null:
		_ghost.free()
		_ghost = null
	var data: Dictionary = _template.duplicate()
	data["designation"] = _new_designation(data)
	var placement: Placement = Placement.new(_mouse_cell, _ghost_rotation, _ghost_mirrored)
	_ghost = SymbolFactory.create(DocumentSerializer.component_from_dict(data), placement)
	_ghost.modulate = Color(1, 1, 1, 0.5)
	add_child(_ghost)


# --- State ----------------------------------------------------------------------

func _record() -> void:
	history.record(DocumentSerializer.to_dict(document()))


func _restore(snapshot: Dictionary) -> void:
	_clear_selection()
	document_replaced.emit(DocumentSerializer.from_dict(snapshot))
	edited.emit()
	queue_redraw()


## Call after every edit of the document.
func _changed() -> void:
	# Indices of wires may have shifted; keep only valid ones.
	for w: int in selected_wires.keys():
		if w >= document().get_wire_count():
			selected_wires.erase(w)
	for id: String in selected_components.keys():
		if not document().circuit.has_component_id(id):
			selected_components.erase(id)
	if not selected_marking.is_empty() and not document().circuit.has_component_id(selected_marking["component"]):
		selected_marking = {}
	view.rebuild()
	_selection_updated()
	edited.emit()


func _clear_selection() -> void:
	selected_marking = {}
	selected_components.clear()
	selected_wires.clear()
	_selection_updated()


func _selection_updated() -> void:
	var single: CircuitComponent = null
	if selected_components.size() == 1 and selected_wires.is_empty():
		single = document().circuit.get_component(selected_components.keys()[0])
	selection_changed.emit(single)
	queue_redraw()


func _can_add(c: CircuitComponent) -> bool:
	var circuit: Circuit = document().circuit
	if circuit.has_component_id(c.id):
		return false
	for key: String in c.get_terminal_keys():
		if circuit.has_terminal(key):
			return false
	return true


func _can_replace(old: CircuitComponent, replacement: CircuitComponent) -> bool:
	var circuit: Circuit = document().circuit
	if replacement.id != old.id and circuit.has_component_id(replacement.id):
		return false
	for key: String in replacement.get_terminal_keys():
		var owner: CircuitComponent = circuit.get_terminal_owner(key)
		if owner != null and owner != old:
			return false
	return true


func _emit_hint() -> void:
	match tool:
		Tool.PLACE:
			hint_changed.emit(tr("Click to place. R rotates, F mirrors left-right, Shift+F top-bottom. Right click or Esc stops placing."))
		Tool.WIRE:
			hint_changed.emit(tr("Click empty cells for corners, finish on a terminal or a wire. Backspace removes a corner, Esc cancels."))
		_:
			hint_changed.emit(tr("Click a terminal to draw a wire. Drag parts, wires or wire numbers to move them. Double-click a marking to edit it. Right click for more. R rotates, F / Shift+F mirror, Del deletes."))


# --- Drawing --------------------------------------------------------------------

## Guide lines across the view through every terminal of the part being
## placed, to line it up with the parts and wires already drawn.
func _draw_placement_guides() -> void:
	var placement: Placement = Placement.new(_mouse_cell, _ghost_rotation, _ghost_mirrored)
	var cells: Array[Vector2i] = []
	for cell: Vector2i in SymbolGeometry.local_terminals(_ghost.component).values():
		cells.append(_mouse_cell + SymbolGeometry.transform_cell(cell, placement))
	_draw_guides(cells)


## Lines across the view through the rows and columns of [param cells].
func _draw_guides(cells: Array[Vector2i]) -> void:
	var visible: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	var color: Color = Color(SchematicTheme.LINE, 0.13)
	var xs: Dictionary[int, bool] = {}
	var ys: Dictionary[int, bool] = {}
	for at: Vector2i in cells:
		xs[at.x] = true
		ys[at.y] = true
	for x: int in xs:
		draw_line(Vector2(x * G, visible.position.y), Vector2(x * G, visible.end.y), color, 3.0)
	for y: int in ys:
		draw_line(Vector2(visible.position.x, y * G), Vector2(visible.end.x, y * G), color, 3.0)


func _draw() -> void:
	if not active or view.document == null:
		return
	var doc: SchematicDocument = document()
	if tool == Tool.PLACE and _ghost != null:
		_draw_placement_guides()
	elif _dragging and _drag_recorded:
		# Guide lines through the terminals of the parts being moved.
		var cells: Array[Vector2i] = []
		for id: String in selected_components:
			var moved: CircuitComponent = doc.circuit.get_component(id)
			if moved != null:
				for key: String in moved.get_terminal_keys():
					cells.append(doc.terminal_cell(key))
		_draw_guides(cells)
	# Unconnected terminals.
	var connected: Dictionary[String, bool] = {}
	for wire: PackedStringArray in doc.circuit.get_wires():
		connected[wire[0]] = true
		connected[wire[1]] = true
	for c: CircuitComponent in doc.circuit.get_components():
		if c is Junction:
			continue
		for key: String in c.get_terminal_keys():
			if not connected.has(key):
				draw_arc(Vector2(doc.terminal_cell(key)) * G, 3.5, 0.0, TAU, 12, SchematicTheme.TERMINAL_TEXT, 1.5)
	# Selection.
	for id: String in selected_components:
		var c: CircuitComponent = doc.circuit.get_component(id)
		if c != null:
			var body: Rect2 = Rect2(doc.component_body(c).position * G, doc.component_body(c).size * G).grow(3.0)
			if _dragging and _drag_recorded:
				# Highlight what is being dragged.
				draw_rect(body, Color(SELECTION_COLOR, 0.15))
				draw_rect(body, SELECTION_COLOR, false, 2.5)
			else:
				draw_rect(body, SELECTION_COLOR, false, 1.5)
	for w: int in selected_wires:
		if w < doc.get_wire_count():
			if w == _wire_drag and _wire_drag_recorded:
				draw_polyline(_pixels(doc.wire_points(w)), Color(SELECTION_COLOR, 0.3), 10.0)
			draw_polyline(_pixels(doc.wire_points(w)), SELECTION_COLOR, 4.0)
	# The selected marking.
	if not selected_marking.is_empty():
		var symbol: SchematicSymbol = view.get_symbol(selected_marking["component"])
		if symbol != null:
			var r: Rect2 = symbol.marking_rect(selected_marking["kind"], selected_marking["index"])
			if r.has_area():
				var box: Rect2 = Rect2(symbol.position + r.position, r.size).grow(2.0)
				draw_rect(box, Color(SELECTION_COLOR, 0.25 if _marking_drag_recorded else 0.15))
				draw_rect(box, SELECTION_COLOR, false, 2.0 if _marking_drag_recorded else 1.5)
	# Wire number being dragged, or under the mouse (it can be dragged).
	var number: Vector2i = _number_drag if _number_drag.x >= 0 else (view.wire_number_at(_mouse_point) if tool == Tool.SELECT and not _dragging and _wire_drag < 0 else Vector2i(-1, -1))
	if number.x >= 0:
		var r: Rect2 = view.wire_number_rect(number)
		if r.has_area():
			var box: Rect2 = Rect2(r.position * G, r.size * G).grow(2.0)
			draw_rect(box, Color(SELECTION_COLOR, 0.25 if _number_drag.x >= 0 else 0.12))
			draw_rect(box, SELECTION_COLOR, false, 2.0 if _number_drag.x >= 0 else 1.0)
	# Hovered terminal.
	if tool != Tool.PLACE and not _dragging:
		var key: String = doc.terminal_at(_mouse_point, 0.3 if tool == Tool.SELECT else 0.4)
		if not key.is_empty():
			draw_circle(Vector2(doc.terminal_cell(key)) * G, 6.0, Color(SELECTION_COLOR, 0.35))
	# Wire in progress.
	if tool == Tool.WIRE:
		var points: Array[Vector2i] = _wire_points.duplicate()
		var preview: Array[Vector2i] = _preview_points()
		var w: int = doc.wire_at(_mouse_point)
		if w >= 0 and doc.terminal_at(_mouse_point).is_empty():
			var cell: Vector2i = doc.wire_cell_near(w, _mouse_point)
			preview = _route_to(cell)
			draw_circle(Vector2(cell) * G, 5.0, PREVIEW_COLOR)
		for i: int in range(1, preview.size()):
			points.append(preview[i])
		if points.size() >= 2:
			draw_polyline(_pixels(points), PREVIEW_COLOR, 2.5)
	# Selection box.
	if _boxing:
		var box: Rect2 = Rect2(_box_origin * G, Vector2.ZERO).expand(_mouse_point * G)
		draw_rect(box, Color(SELECTION_COLOR, 0.1))
		draw_rect(box, SELECTION_COLOR, false, 1.0)


func _pixels(points: Array[Vector2i]) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2i in points:
		result.append(Vector2(p) * G)
	return result
