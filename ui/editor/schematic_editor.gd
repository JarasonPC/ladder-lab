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

enum MenuId { ROTATE, MIRROR, CUT, COPY, PASTE, DELETE, SELECT_ALL }
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
		if trial != null and trial.get_terminal_names().size() == terminals:
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
	if (template["type"] == "contact" or template["type"] == "changeover") and d.get("delayed", false) != template.get("delayed", false):
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
		_ghost_mirrored = not _ghost_mirrored
		_rebuild_ghost()
		return
	if selected_components.is_empty():
		return
	_record()
	for id: String in selected_components:
		document().mirror_component(id)
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
	if String(data.get("designation", "x")).is_empty():
		return tr("The designation must not be empty.")
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
	_follow_overload_relay(data)
	var replacement: CircuitComponent = DocumentSerializer.component_from_dict(data)
	if replacement == null:
		return tr("Terminal names must all be different, without spaces or colons.")
	var snapshot: Dictionary = DocumentSerializer.to_dict(doc)
	if not _can_replace(old, replacement):
		return tr("%s is already used in this circuit.") % replacement.id
	history.record(snapshot)
	doc.replace_component(component_id, replacement)
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
		_menu.add_item(tr("Mirror"), MenuId.MIRROR, KEY_F)
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
			var key: String = doc.terminal_at(_mouse_point, 0.3)
			var hit: CircuitComponent = doc.component_at(_mouse_point)
			if not key.is_empty() and not shift:
				_start_wire(key)
				return
			if hit != null:
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
	_follow_overload_relay(data)
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


## A contact designated like an overload relay (e.g. "F2") becomes its
## overload contact (95-96 / 97-98, drawn with the thermal actuator); an
## overload contact designated otherwise becomes a plain contact again.
func _follow_overload_relay(data: Dictionary) -> void:
	var doc: SchematicDocument = document()
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
				if selected is Coil and (selected is TimerRelay) == want_timer:
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
	for c: CircuitComponent in doc.circuit.get_components():
		var symbol: SchematicSymbol = view.get_symbol(c.id)
		if symbol == null:
			continue
		for m: Array in symbol.marking_rects:
			var rect: Rect2 = (m[2] as Rect2).grow(2.0)
			if rect.has_point(pixel - symbol.position):
				return _edit_marking(c, m[0], m[1])
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
	_inline.position = at - Vector2(4, 4)
	_inline.custom_minimum_size = Vector2(maxf(60.0, 10.0 * (text.length() + 3)), 0)
	_inline.add_theme_font_size_override("font_size", 13)
	add_child(_inline)
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
	view.rebuild()
	_selection_updated()
	edited.emit()


func _clear_selection() -> void:
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
			hint_changed.emit(tr("Click to place. R rotates, F mirrors. Right click or Esc stops placing."))
		Tool.WIRE:
			hint_changed.emit(tr("Click empty cells for corners, finish on a terminal or a wire. Backspace removes a corner, Esc cancels."))
		_:
			hint_changed.emit(tr("Click a terminal to draw a wire. Drag parts, wires or wire numbers to move them. Double-click a marking to edit it. Right click for more. R rotates, F mirrors, Del deletes."))


# --- Drawing --------------------------------------------------------------------

## Guide lines across the view through every terminal of the part being
## placed, to line it up with the parts and wires already drawn.
func _draw_placement_guides() -> void:
	var visible: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	var placement: Placement = Placement.new(_mouse_cell, _ghost_rotation, _ghost_mirrored)
	var color: Color = Color(SchematicTheme.LINE, 0.13)
	var xs: Dictionary[int, bool] = {}
	var ys: Dictionary[int, bool] = {}
	for cell: Vector2i in SymbolGeometry.local_terminals(_ghost.component).values():
		var at: Vector2i = _mouse_cell + SymbolGeometry.transform_cell(cell, placement)
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
			var body: Rect2 = doc.component_body(c)
			draw_rect(Rect2(body.position * G, body.size * G).grow(3.0), SELECTION_COLOR, false, 1.5)
	for w: int in selected_wires:
		if w < doc.get_wire_count():
			draw_polyline(_pixels(doc.wire_points(w)), SELECTION_COLOR, 4.0)
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
