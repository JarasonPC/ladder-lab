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
## coils, loads or supplies); empty for junctions.
static func type_options(c: CircuitComponent) -> Array[Dictionary]:
	var family: String = _family(DocumentSerializer.component_to_dict(c)["type"])
	var result: Array[Dictionary] = []
	if family.is_empty():
		return result
	for entry: Dictionary in Palette.ENTRIES:
		if _family(entry["template"]["type"]) == family:
			result.append(entry)
	return result


## True if [param c] is what [param template] would create.
static func matches_template(c: CircuitComponent, template: Dictionary) -> bool:
	var d: Dictionary = DocumentSerializer.component_to_dict(c)
	for key: String in template:
		if key == "delay":
			continue
		if d.get(key, false) != template[key]:
			return false
	if template["type"] == "contact" and d.get("delayed", false) != template.get("delayed", false):
		return false
	return true


static func _family(kind: String) -> String:
	match kind:
		"push_button", "latching_switch", "contact":
			return "switching"
		"coil", "timer":
			return "coil"
		"lamp", "motor":
			return "load"
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
		var conductor: PowerSupply.Conductor = PowerSupply.Conductor.N if data["conductor"] == "N" else PowerSupply.Conductor.L
		if conductor != (old as PowerSupply).conductor:
			data["designation"] = doc.next_supply_designation(conductor)
	if String(data.get("designation", "x")).is_empty():
		return tr("The designation must not be empty.")
	var replacement: CircuitComponent = DocumentSerializer.component_from_dict(data)
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
				if selected_wires.has(w):
					selected_wires.erase(w)
				else:
					selected_wires[w] = true
				_selection_updated()
				return
			if not shift:
				_clear_selection()
			_boxing = true
			_box_origin = _mouse_point
	queue_redraw()


func _on_left_released(shift: bool) -> void:
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
	if data["type"] == "contact" or data["type"] == "push_button" or data["type"] == "latching_switch":
		data["sequence"] = doc.next_contact_sequence(data["designation"])
	var c: CircuitComponent = DocumentSerializer.component_from_dict(data)
	if not _can_add(c):
		hint_changed.emit(tr("%s is already used in this circuit.") % c.id)
		return
	_record()
	doc.add(c, cell, _ghost_rotation, _ghost_mirrored)
	_clear_selection()
	selected_components[c.id] = true
	_changed()
	_rebuild_ghost()


func _new_designation(data: Dictionary) -> String:
	var doc: SchematicDocument = document()
	match data["type"]:
		"supply":
			return doc.next_supply_designation(PowerSupply.Conductor.N if data.get("conductor", "L") == "N" else PowerSupply.Conductor.L)
		"push_button", "latching_switch":
			return doc.next_designation("S")
		"contact":
			# Belongs to the selected coil, else to the first coil of the right kind.
			var want_timer: bool = data.get("delayed", false)
			for id: String in selected_components:
				var selected: CircuitComponent = doc.circuit.get_component(id)
				if selected is Coil and (selected is TimerRelay) == want_timer:
					return selected.designation
			for c: CircuitComponent in doc.circuit.get_components():
				if c is Coil and (c is TimerRelay) == want_timer:
					return c.designation
			return "KT1" if want_timer else "K1"
		"coil":
			return doc.next_designation("K")
		"timer":
			return doc.next_designation("KT")
		"lamp":
			return doc.next_designation("H")
		"motor":
			return doc.next_designation("M")
	return doc.next_designation("X")


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
		if document().circuit.get_component(id) == null:
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
	if circuit.get_component(c.id) != null:
		return false
	for key: String in c.get_terminal_keys():
		if circuit.has_terminal(key):
			return false
	return true


func _can_replace(old: CircuitComponent, replacement: CircuitComponent) -> bool:
	var circuit: Circuit = document().circuit
	if replacement.id != old.id and circuit.get_component(replacement.id) != null:
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
			hint_changed.emit(tr("Click a terminal to draw a wire. Drag to move. Right click for more. R rotates, F mirrors, Del deletes."))


# --- Drawing --------------------------------------------------------------------

func _draw() -> void:
	if not active or view.document == null:
		return
	var doc: SchematicDocument = document()
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
