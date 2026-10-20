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
## to another type, keeping its wires), rotate, mirror, line up (several
## parts in a column or a row, a set number of cells apart, with a ruler on
## the drawing while the number is asked for), wire facing terminals,
## cut/copy/paste, delete.
## Wiring helpers (each turned on or off in the View menu): "Wire facing
## terminals" in the right click menu wires the free terminals of the selected
## parts that face each other straight; a wire drawn between multi-pole parts
## takes the poles beside it along (Shift: that wire alone); parts placed or
## dropped get straight wires to the free terminals they face.
## Keys: R rotate, F mirror, Delete remove, Ctrl+Z undo, Ctrl+Y redo,
## Ctrl+X/C/V cut/copy/paste, Ctrl+A select all.

## The document content changed (for unsaved-changes tracking).
signal edited
signal document_replaced(doc: SchematicDocument)
signal selection_changed(component: CircuitComponent)
signal hint_changed(text: String)
## Another page should be shown, centred on [param focus_id] (a page
## connector's partner, from the right click menu).
signal page_requested(index: int, focus_id: String)
## A PLC was double-clicked: open its program.
signal plc_requested(component_id: String)
## The datasheet of a part was asked for (right click menu).
signal datasheet_requested(component_id: String)
## A key should be bound to push button or switch [param designation] (right click menu).
signal key_bind_requested(designation: String)

enum Tool { SELECT, PLACE, WIRE }

const G: float = float(SymbolGeometry.GRID)
const CLICK_SLOP: float = 6.0

enum MenuId { ROTATE, MIRROR, FLIP, CUT, COPY, PASTE, DELETE, SELECT_ALL, ADD_STRIP, REMOVE_STRIP, DATASHEET, BIND_KEY, LINE_UP_VERTICAL, LINE_UP_HORIZONTAL, WIRE_FACING, GO_TO = 100 }
const SELECTION_COLOR := Color("2d7ff9")
const PREVIEW_COLOR := Color(0.18, 0.5, 0.98, 0.8)
## Phase conductors as the palette names them, in phase order.
const PHASES: PackedStringArray = ["L", "L2", "L3"]

var view: SchematicView
var history: UndoHistory = UndoHistory.new()
var active: bool = false:
	set(value):
		# Unchanged (e.g. a View menu toggle refreshing the window): the tool
		# in use goes on.
		if value == active:
			return
		active = value
		if not value and _inline != null:
			# A marking being typed is taken, as when its field loses focus.
			_commit_inline(_inline.text)
		_cancel_tool()
		visible = value

var tool: Tool = Tool.SELECT
## Wiring helpers, set from the View menu: "Wire facing terminals" in the
## right click menu; a wire drawn between multi-pole parts takes the poles
## beside it along; parts placed or dropped are wired to the terminals they
## face.
var wire_facing_menu: bool = true
var wire_all_poles: bool = false
var wire_on_drop: bool = false:
	set(value):
		wire_on_drop = value
		_drop_pairs.clear()
		_update_ghost_wires()
var selected_components: Dictionary[String, bool] = {}
var selected_wires: Dictionary[int, bool] = {}

var _mouse_cell: Vector2i = Vector2i.ZERO
var _mouse_point: Vector2 = Vector2.ZERO
# Placing.
var _template: Dictionary = {}
## Phase supplies placed one after the other with the place tool: each takes
## the next phase (L1, L2, L3, L1, ...), see [method _placed_data].
var _phase_step: int = 0
var _ghost: SchematicSymbol = null
var _ghost_rotation: int = 0
var _ghost_mirrored: bool = false
## Wires the part being placed would get where the ghost stands (see
## [member wire_on_drop]), from cell to cell, and the cell they were found for.
var _ghost_wires: Array[PackedVector2Array] = []
var _ghost_wires_cell: Vector2i = Vector2i.ZERO
# Wiring: start terminal and fixed points so far (start cell first).
var _wire_start: String = ""
var _wire_points: Array[Vector2i] = []
## Where the left button went down, and whether the mouse has since moved
## far enough (CLICK_SLOP) to drag: a plain click never moves anything.
var _press_point: Vector2 = Vector2.ZERO
var _press_moved: bool = false
# Dragging selected symbols.
var _dragging: bool = false
var _drag_applied: Vector2i = Vector2i.ZERO
var _drag_recorded: bool = false
## Placements and wire routes when the drag began (SchematicDocument.drag_start).
var _drag_start: Dictionary = {}
## The document as the drag's undo step recorded it ({} after a turn).
var _drag_snapshot: Dictionary = {}
## Wires the dragged parts would get where they are now (see
## [member wire_on_drop]), drawn dashed until they are let go.
var _drop_pairs: Array[PackedStringArray] = []
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
## Lead terminal the context menu was opened on (see [method _strip_place_at]).
var _menu_strip: Dictionary = {}
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
## Where the page connector of the context menu continues (see
## [method SchematicDocument.connector_targets]).
var _go_to_targets: Array[Dictionary] = []
## Asks how many free cells to leave between parts lined up (see
## [method SchematicDocument.line_up]).
var _line_up_dialog: ConfirmationDialog
var _line_up_caption: Label
var _line_up_spin: SpinBox
## The line-up being asked for, {"ids": PackedStringArray, "vertical": bool};
## its ruler is drawn while the dialog is open.
var _line_up: Dictionary = {}
## Free cells between parts lined up, kept for the next time.
var line_up_spacing: int = 2


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
	_build_line_up_dialog()


func _build_line_up_dialog() -> void:
	_line_up_dialog = ConfirmationDialog.new()
	_line_up_dialog.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_line_up_caption = Label.new()
	_line_up_caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_line_up_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_line_up_caption)
	_line_up_spin = SpinBox.new()
	_line_up_spin.min_value = 1
	_line_up_spin.max_value = 50
	_line_up_spin.step = 1
	_line_up_spin.rounded = true
	_line_up_spin.update_on_text_changed = true
	_line_up_spin.custom_minimum_size.x = 120.0
	_line_up_spin.value_changed.connect(func(_v: float) -> void: queue_redraw())
	row.add_child(_line_up_spin)
	_line_up_dialog.add_child(row)
	_line_up_dialog.register_text_enter(_line_up_spin.get_line_edit())
	_line_up_dialog.confirmed.connect(_apply_line_up)
	_line_up_dialog.canceled.connect(func() -> void:
		_line_up = {}
		queue_redraw())
	add_child(_line_up_dialog)


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
		# Set in the properties, not by the palette entry.
		if key == "delay" or key == "cpu":
			continue
		if not d.has(key) or d[key] != template[key]:
			return false
	if d.get("holder", false) != template.get("holder", false) or d.get("family", "") != template.get("family", ""):
		return false
	return true


static func _family(kind: String) -> String:
	match kind:
		"push_button", "latching_switch", "limit_switch", "contact":
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
	_phase_step = 0
	_ghost_rotation = 3 if document().horizontal else 0
	_ghost_mirrored = document().horizontal
	_rebuild_ghost()
	_emit_hint()


func undo() -> void:
	# A drag under way ends first (a part dragged back leaves no undo step).
	_end_drags()
	if not history.can_undo():
		return
	_cancel_tool()
	_restore(history.undo(DocumentSerializer.to_dict(document())))


func redo() -> void:
	_end_drags()
	if not history.can_redo():
		return
	_cancel_tool()
	_restore(history.redo(DocumentSerializer.to_dict(document())))


func delete_selection() -> void:
	# A drag under way would go on with wires and parts no longer there.
	_end_drags()
	if not selected_marking.is_empty() and selected_marking["kind"] == "strip" and selected_wires.is_empty() and selected_components.keys().all(func(id: String) -> bool: return id == selected_marking["component"]):
		# Delete on a strip terminal removes just that terminal mark (unless
		# more was selected since).
		_record()
		document().set_strip_terminal(selected_marking["component"], selected_marking["index"], "")
		selected_marking = {}
		_changed()
		return
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
	document().rotate_components(PackedStringArray(selected_components.keys()))
	_turned_while_dragging()
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
	document().mirror_components(PackedStringArray(selected_components.keys()))
	_turned_while_dragging()
	_changed()


## Wires the free terminals of the selected parts that face each other with
## straight wires (see [method SchematicDocument.facing_pairs]), one undo
## step. Returns how many wires were added.
func wire_facing_terminals() -> int:
	var pairs: Array[PackedStringArray] = document().facing_pairs(PackedStringArray(selected_components.keys()))
	if pairs.is_empty():
		return 0
	_record()
	var added: int = document().connect_pairs(pairs)
	_changed()
	return added


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
	document().flip_components(PackedStringArray(selected_components.keys()))
	_turned_while_dragging()
	_changed()


## The selection was turned or mirrored with the mouse button held: a drag of
## parts goes on from where they are now and a wire segment drag ends, since
## the routes they started from no longer fit the turned parts (a wire between
## two dragged parts would be shifted along with a stale corner, leaving a
## slanted segment).
func _turned_while_dragging() -> void:
	if _dragging and _drag_recorded:
		# The turn is an undo step of its own after the drag's.
		_drag_snapshot = {}
		_drag_start = document().drag_start(PackedStringArray(selected_components.keys()))
		_press_point += Vector2(_drag_applied)
		_drag_applied = Vector2i.ZERO
	_wire_drag = -1


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
		if new_kind != coil.kind and not (old is TimerRelay) and data["designation"] == old.designation and SchematicDocument._designation_prefix(old.designation) == old_prefix and not _designation_shared(old):
			data["designation"] = doc.next_device_designation(new_prefix)
	_follow_device(data, old.designation)
	adapt_terminals(data, old.default_terminal_names())
	# A contact given the designation of a device that already has a contact
	# with its numbers takes the next free sequence digit (13-14 -> 23-24).
	if (data["type"] == "contact" or data["type"] == "changeover") and data["designation"] != old.designation and not data.has("terminals"):
		var probe: CircuitComponent = DocumentSerializer.component_from_dict(data)
		if probe != null and doc.circuit.has_component_id(probe.id):
			data["sequence"] = doc.next_contact_sequence(data["designation"])
	var replacement: CircuitComponent = DocumentSerializer.component_from_dict(data)
	if replacement == null:
		return tr("Terminal names must all be different, without spaces or colons.")
	var snapshot: Dictionary = DocumentSerializer.to_dict(doc)
	if not _can_replace(old, replacement):
		return tr("%s is already used in this circuit.") % replacement.id
	if not _designation_free(old, replacement):
		return tr("%s is already the designation of another device.") % replacement.designation
	var renaming: bool = replacement.designation != old.designation and (old is Coil or old is OverloadRelay)
	if renaming:
		var clash: String = _rename_clash(old, replacement.designation)
		if not clash.is_empty():
			return tr("%s is already used in this circuit.") % clash
	# A coil turned into a time relay (or back): its contacts become delayed
	# ones (or plain ones), as a contact drawn for it would be.
	var timing_changed: bool = old is Coil and replacement is Coil and (old is TimerRelay) != (replacement is TimerRelay)
	history.record(snapshot)
	doc.replace_component(component_id, replacement)
	if renaming or timing_changed:
		# The device was renamed (or turned into a time relay or back): its
		# contacts go along with it.
		for part: CircuitComponent in doc.circuit.get_components().duplicate():
			if part == replacement or part.designation != old.designation or _designation_group(part) != _designation_group(old):
				continue
			var part_data: Dictionary = DocumentSerializer.component_to_dict(part)
			part_data["designation"] = replacement.designation
			if timing_changed and part_data.has("delayed"):
				part_data["delayed"] = replacement is TimerRelay
			var renamed: CircuitComponent = DocumentSerializer.component_from_dict(part_data)
			if renamed != null and not _can_replace(part, renamed) and (part is Contact or part is ChangeoverContact):
				# The device already has a contact with these numbers (e.g.
				# one drawn for it before): the next free sequence digit.
				part_data["sequence"] = doc.next_contact_sequence(replacement.designation)
				renamed = DocumentSerializer.component_from_dict(part_data)
			if renamed != null and _can_replace(part, renamed):
				doc.replace_component(part.id, renamed)
	# The selection follows the part only when it was selected: a PLC
	# program edited in its window leaves the selection alone.
	if selected_components.has(component_id):
		selected_components.clear()
		selected_components[replacement.id] = true
	_changed()
	return ""


## Custom terminal names in [param data] of a part whose standard names were
## [param before], when the edit changes those (poles, the control input S,
## another CPU, modules, another contact): each name given by hand goes to
## the terminal with the same standard name, those of terminals that are gone
## are dropped, all of them if they would clash with the new ones.
static func adapt_terminals(data: Dictionary, before: PackedStringArray) -> void:
	if not (data.get("terminals") is Array) or (data["terminals"] as Array).size() != before.size():
		return
	var custom: Array = data["terminals"]
	var plain: Dictionary = data.duplicate()
	plain.erase("terminals")
	var probe: CircuitComponent = DocumentSerializer.component_from_dict(plain)
	if probe == null:
		return
	var after: PackedStringArray = probe.default_terminal_names()
	if after == before:
		return
	var names: PackedStringArray = after.duplicate()
	for i: int in before.size():
		var j: int = after.find(before[i])
		if j >= 0:
			names[j] = str(custom[i])
	if names != after and probe.supports_custom_terminals() and CircuitComponent.valid_terminal_names(names):
		data["terminals"] = Array(names)
	else:
		data.erase("terminals")


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
	if old_data["type"] == template["type"]:
		# Another entry of the same type (fuse holder, another 3~ motor or
		# PLC, contact NC): what was set stays, except what tells the entries
		# apart.
		data = old_data.duplicate()
		for entry: Dictionary in Palette.ENTRIES:
			if entry["template"]["type"] == template["type"]:
				for key: String in entry["template"]:
					if not template.has(key):
						data.erase(key)
		data.merge(template, true)
		if data.get("motor_kind", "standard") != "standard":
			data.erase("connection")
	if old_data.has("poles") and not data.has("poles"):
		data["poles"] = old_data["poles"]
	if VoltageRating.offered(template["type"]).has(str(old_data.get("rating", ""))):
		data["rating"] = old_data["rating"]
	else:
		data.erase("rating")
	match _family(template["type"]):
		"switching":
			var element: SwitchingElement = old as SwitchingElement
			var to_contact: bool = template["type"] == "contact"
			# The designation follows the type: SB push button, RB switch, SQ
			# limit switch, a contact that of its coil.
			var same_kind: bool = old_data["type"] == template["type"] or (old is Contact and to_contact)
			var designation: String = old.designation if same_kind else _new_designation(template, old.id)
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
			# A coil turned into a time relay becomes KT (and back), as long
			# as no contacts carry its designation yet.
			var old_prefix: String = "KT" if old is TimerRelay else ("KA" if (old as Coil).kind == Coil.Kind.RELAY else "KM")
			var new_prefix: String = "KT" if template["type"] == "timer" else ("KA" if template.get("kind", "contactor") == "relay" else "KM")
			if new_prefix != old_prefix and SchematicDocument._designation_prefix(old.designation) == old_prefix and not _designation_shared(old):
				data["designation"] = doc.next_device_designation(new_prefix)
			if old is TimerRelay and template["type"] == "timer":
				data["delay"] = (old as TimerRelay).delay
			# A1 and A2 stay swapped; times set by hand go along, the
			# defaults become those of the new type.
			if old_data.has("terminals"):
				data["terminals"] = old_data["terminals"]
			var coil: Coil = old as Coil
			if not (is_equal_approx(coil.pick_up_time, Coil.DEFAULT_PICK_UP[coil.kind]) and is_equal_approx(coil.drop_out_time, Coil.DEFAULT_DROP_OUT[coil.kind])):
				data["pick_up"] = coil.pick_up_time
				data["drop_out"] = coil.drop_out_time
		"load":
			data["designation"] = _new_designation(template)
		"protection":
			# FU fuse, FA circuit breaker.
			data["designation"] = old.designation if old_data["type"] == template["type"] else _new_designation(template)
		_:
			data["designation"] = old.designation
	return apply_properties(component_id, data)


## Applies [param change] (called with the document) to the workspace or a
## control station as one undoable edit.
func edit_workspace(change: Callable) -> void:
	_record()
	change.call(document())
	document().name_cables()
	# Keycaps on the symbols follow bound keys.
	view.rebuild()
	edited.emit()


## Applies [param change] (called with the document) to a switchboard as
## one undoable edit.
func edit_cabinet(change: Callable) -> void:
	_record()
	change.call(document())
	# Splitting a terminal strip relabels terminals on the drawing too.
	_changed()


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
	# Junctions copied without the wires they joined go.
	document().cleanup_junctions()
	_clear_selection()
	for id: String in ids:
		selected_components[id] = true
	_changed()


## Selects everything on the page shown.
func select_all() -> void:
	_cancel_tool()
	selected_marking = {}
	for c: CircuitComponent in document().components_on_page():
		selected_components[c.id] = true
	for w: int in document().wires_on_page():
		selected_wires[w] = true
	_selection_updated()


## The selected parts that can be lined up (junctions stay with their wires).
func _line_up_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for id: String in selected_components:
		if not (document().circuit.get_component(id) is Junction):
			ids.append(id)
	return ids


## Asks how many free cells to leave between the selected parts, then lines
## them up one under another ([param vertical]) or side by side (see
## [method SchematicDocument.line_up]); a ruler along the line shows the cells
## and where the parts will be meanwhile.
func ask_line_up(vertical: bool) -> void:
	var ids: PackedStringArray = _line_up_ids()
	if ids.size() < 2:
		return
	_cancel_tool()
	_line_up = {"ids": ids, "vertical": vertical}
	_line_up_dialog.title = tr("Line up vertically") if vertical else tr("Line up horizontally")
	_line_up_dialog.ok_button_text = tr("Line up")
	_line_up_dialog.cancel_button_text = tr("Cancel")
	_line_up_caption.text = tr("Free cells between the parts:")
	_line_up_spin.set_value_no_signal(line_up_spacing)
	AppTheme.popup_at_mouse(_line_up_dialog, Vector2(16, 16))
	_keep_dialog_off_ruler()
	_line_up_spin.get_line_edit().grab_focus()
	_line_up_spin.get_line_edit().select_all()
	queue_redraw()


func _apply_line_up() -> void:
	if _line_up.is_empty():
		return
	_line_up_spin.apply()
	line_up_spacing = int(_line_up_spin.value)
	var vertical: bool = _line_up["vertical"]
	var ids: PackedStringArray = PackedStringArray()
	for id: String in _line_up["ids"]:
		if document().circuit.has_component_id(id):
			ids.append(id)
	_line_up = {}
	queue_redraw()
	if ids.size() < 2:
		return
	_record()
	document().line_up(ids, vertical, line_up_spacing)
	_changed()


## What the ruler of the line-up being asked for runs beside (grid units):
## the parts as they stand and as they will be lined up, with their markings
## when [param markings].
func _line_up_area(markings: bool = true) -> Rect2:
	var doc: SchematicDocument = document()
	var area: Rect2 = Rect2()
	var first: bool = true
	var cells: Dictionary[String, Rect2i] = doc.line_up_cells(_line_up["ids"], _line_up["vertical"], int(_line_up_spin.value))
	for id: String in cells:
		var now: Rect2i = doc.component_cells(doc.circuit.get_component(id))
		var drawn: Rect2 = Rect2(now)
		var symbol: SchematicSymbol = view.get_symbol(id)
		if markings and symbol != null:
			for rect: Rect2 in symbol.text_rects:
				drawn = drawn.merge(Rect2((rect.position + symbol.position) / G, rect.size / G))
		var moved: Rect2 = Rect2(drawn.position + Vector2(cells[id].position - now.position), drawn.size)
		area = drawn.merge(moved) if first else area.merge(drawn).merge(moved)
		first = false
	return area


## Moves the line-up dialog where it leaves the parts and the ruler in sight
## (beside them, as far as the window allows).
func _keep_dialog_off_ruler() -> void:
	var host: Window = _line_up_dialog.get_parent().get_window()
	if not host.gui_embed_subwindows:
		return
	var area: Rect2 = _line_up_area().grow(2.5)
	var screen: Rect2 = get_global_transform_with_canvas() * Rect2(area.position * G, area.size * G)
	var room: Rect2 = host.get_visible_rect()
	var size: Vector2 = Vector2(_line_up_dialog.size)
	var spots: Array[Vector2] = [
		Vector2(screen.position.x, screen.end.y + 8.0),
		Vector2(screen.position.x, screen.position.y - size.y - 8.0),
		Vector2(screen.end.x + 8.0, screen.position.y),
		Vector2(screen.position.x - size.x - 8.0, screen.position.y),
	]
	if Rect2(Vector2(_line_up_dialog.position), size).intersects(screen):
		for spot: Vector2 in spots:
			var at: Vector2 = spot.clamp(room.position, (room.end - size).max(room.position))
			if not Rect2(at, size).intersects(screen):
				_line_up_dialog.position = Vector2i(at)
				return


## Applies [param change] (called with the document) to the pages (add,
## rename, move, delete) as one undoable edit.
func edit_pages(change: Callable) -> void:
	_cancel_tool()
	_record()
	change.call(document())
	_clear_selection()
	_changed()


## Call before another page is shown: a wire in progress is dropped and the
## selection cleared; placing goes on, on the new page.
func leave_page() -> void:
	if tool == Tool.WIRE:
		_cancel_tool()
	_close_inline()
	_end_drags()
	_clear_selection()


func has_clipboard() -> bool:
	return not _clipboard.is_empty()


# --- Input ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not active or view.document == null:
		return
	if event is InputEventMouseMotion:
		_update_mouse()
		if _holding() and not ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT):
			# The release went elsewhere (e.g. outside the window): end the
			# drag rather than let the part follow the mouse.
			_on_left_released(false)
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
	elif event is InputEventKey:
		if (event as InputEventKey).keycode == KEY_SHIFT and tool == Tool.WIRE:
			# Shift hides or shows the poles that would go along.
			queue_redraw()
		if (event as InputEventKey).pressed:
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
	var strip: Dictionary = _strip_place_at(_mouse_point)
	var hit: CircuitComponent = doc.component_at(_mouse_point)
	if hit == null and not strip.is_empty():
		hit = doc.circuit.get_component(strip["component"])
	if hit != null and not selected_components.has(hit.id):
		_clear_selection()
		selected_components[hit.id] = true
		_selection_updated()
	var has_selection: bool = not selected_components.is_empty() or not selected_wires.is_empty()
	_menu.clear()
	_change_menu.clear()
	_change_options.clear()
	_go_to_targets.clear()
	if hit is PageConnector:
		_go_to_targets = doc.connector_targets(hit.id)
	if not _go_to_targets.is_empty():
		for i: int in _go_to_targets.size():
			var target: Dictionary = _go_to_targets[i]
			_menu.add_item(tr("Go to page %d (%s)") % [target["page"] + 1, tr(doc.page_name(target["page"], tr("Page %d")))], MenuId.GO_TO + i)
		_menu.add_separator()
	_menu_strip = strip
	if not strip.is_empty():
		# A terminal of a terminal strip on this lead: add or remove it.
		var label: String = doc.get_placement(strip["component"]).strips.get(strip["index"], "")
		if label.is_empty():
			_menu.add_item(tr("Add a strip terminal here"), MenuId.ADD_STRIP)
		else:
			_menu.add_item(tr("Remove strip terminal %s") % label, MenuId.REMOVE_STRIP)
		_menu.add_separator()
	if hit != null and selected_components.size() == 1 and not (hit is Junction):
		_menu.add_item(tr("Datasheet"), MenuId.DATASHEET, KEY_F1)
		if doc.can_have_key(hit.designation):
			var key: String = doc.key_bindings.get(hit.designation, "")
			_menu.add_item(tr("Bind a key…") + ("  [%s]" % key if not key.is_empty() else ""), MenuId.BIND_KEY)
			_menu.set_item_tooltip(_menu.item_count - 1, tr("A key of the keyboard that operates it while simulating"))
		_menu.add_separator()
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
		var line_up: bool = _line_up_ids().size() >= 2
		var facing: bool = wire_facing_menu and selected_components.size() >= 2
		if line_up or facing:
			_menu.add_separator()
		if line_up:
			_menu.add_item(tr("Line up vertically…"), MenuId.LINE_UP_VERTICAL)
			_menu.set_item_tooltip(_menu.item_count - 1, tr("One under another, the same number of cells apart"))
			_menu.add_item(tr("Line up horizontally…"), MenuId.LINE_UP_HORIZONTAL)
			_menu.set_item_tooltip(_menu.item_count - 1, tr("Side by side, the same number of cells apart"))
		if facing:
			var count: int = doc.facing_pairs(PackedStringArray(selected_components.keys())).size()
			_menu.add_item(tr("Wire facing terminals") + ("  (%d)" % count if count > 0 else ""), MenuId.WIRE_FACING)
			_menu.set_item_tooltip(_menu.item_count - 1, tr("Straight wires between the free terminals of the selected parts that face each other"))
			_menu.set_item_disabled(_menu.item_count - 1, count == 0)
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
	AppTheme.popup_at_mouse(_menu)


func _on_menu_id(id: int) -> void:
	if id >= MenuId.GO_TO and id - MenuId.GO_TO < _go_to_targets.size():
		var target: Dictionary = _go_to_targets[id - MenuId.GO_TO]
		page_requested.emit(target["page"], target["id"])
		return
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
		MenuId.LINE_UP_VERTICAL, MenuId.LINE_UP_HORIZONTAL:
			ask_line_up(id == MenuId.LINE_UP_VERTICAL)
		MenuId.WIRE_FACING:
			wire_facing_terminals()
		MenuId.DATASHEET:
			if selected_components.size() == 1:
				datasheet_requested.emit(selected_components.keys()[0])
		MenuId.BIND_KEY:
			if selected_components.size() == 1:
				key_bind_requested.emit(document().circuit.get_component(selected_components.keys()[0]).designation)
		MenuId.ADD_STRIP, MenuId.REMOVE_STRIP:
			if _menu_strip.is_empty() or not document().circuit.has_component_id(_menu_strip["component"]):
				return
			_record()
			var label: String = document().next_strip_label() if id == MenuId.ADD_STRIP else ""
			document().set_strip_terminal(_menu_strip["component"], _menu_strip["index"], label)
			selected_marking = {}
			_changed()


## The lead terminal at [param point] that can carry a strip terminal (or
## whose strip terminal label is there): {"component": id, "index": i}, or {}.
func _strip_place_at(point: Vector2) -> Dictionary:
	var marking: Dictionary = _marking_at(point)
	if not marking.is_empty() and marking["kind"] == "strip":
		return {"component": marking["component"], "index": marking["index"]}
	var doc: SchematicDocument = document()
	var key: String = doc.terminal_at(point, 0.3)
	var owner: CircuitComponent = doc.circuit.get_terminal_owner(key) if not key.is_empty() else null
	if owner == null or owner is Junction or owner is TerminalBlock or owner is PageConnector:
		return {}
	return {"component": owner.id, "index": Array(owner.get_terminal_keys()).find(key)}


func _update_mouse() -> void:
	_mouse_point = get_local_mouse_position() / G
	_mouse_cell = Vector2i(_mouse_point.round())


func _on_mouse_moved() -> void:
	match tool:
		Tool.PLACE:
			if _ghost != null:
				_ghost.position = Vector2(_mouse_cell) * G
				if _mouse_cell != _ghost_wires_cell:
					_update_ghost_wires()
		Tool.SELECT:
			if _holding() and not _press_moved:
				var on_screen: float = (_mouse_point - _press_point).length() * G * get_global_transform_with_canvas().get_scale().x
				_press_moved = on_screen >= CLICK_SLOP
			if _press_moved:
				if _dragging:
					# Steps of whole cells from the press, wherever in its cell
					# the part was grabbed.
					_drag_to(Vector2i((_mouse_point - _press_point).round()))
				elif _wire_drag >= 0:
					_drag_wire_to(_mouse_cell - _wire_drag_origin)
				elif _number_drag.x >= 0:
					_drag_number_to(_mouse_point - _number_drag_origin)
				elif _marking_drag:
					_drag_marking_to(_mouse_point - _marking_drag_origin)
	queue_redraw()


## A drag of parts, a wire segment, a wire number or a marking is under way.
func _holding() -> bool:
	return _dragging or _wire_drag >= 0 or _number_drag.x >= 0 or _marking_drag


func _on_left_pressed(shift: bool) -> void:
	var doc: SchematicDocument = document()
	_press_point = _mouse_point
	_press_moved = false
	match tool:
		Tool.PLACE:
			_place_at(_mouse_cell)
		Tool.WIRE:
			var key: String = doc.terminal_at(_mouse_point)
			if not key.is_empty() and key != _wire_start:
				_finish_wire(key, -1, shift)
				return
			var w: int = _wire_to_join()
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
		_drag_start = {}
		_drop_pairs.clear()
		if _drag_recorded:
			if DocumentSerializer.to_dict(document()) == _drag_snapshot:
				# Dragged back to where they were: nothing changed, no undo step.
				history.discard_last()
			else:
				if wire_on_drop:
					# In the drag's undo step.
					document().connect_pairs(document().facing_pairs(PackedStringArray(selected_components.keys()), _page_ids()))
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
	if _template["type"] == "terminal":
		# On a component's lead the terminal takes the place of its square.
		var key: String = doc.terminal_at(Vector2(cell), 0.3)
		var owner: CircuitComponent = doc.circuit.get_terminal_owner(key) if not key.is_empty() else null
		if owner != null and not (owner is Junction or owner is TerminalBlock or owner is PageConnector):
			var index: int = Array(owner.get_terminal_keys()).find(key)
			if not doc.get_placement(owner.id).strips.has(index):
				_record()
				doc.set_strip_terminal(owner.id, index, doc.next_strip_label())
				_changed()
			return
	var data: Dictionary = _placed_data()
	data["designation"] = _new_designation(data)
	var ratings: PackedStringArray = VoltageRating.offered(data["type"]) if data.get("family", "") != "compact" else PackedStringArray()
	if not ratings.is_empty() and not data.has("rating"):
		# New parts have a rated voltage: the first offered, 230 V.
		data["rating"] = ratings[0]
	if ["contact", "changeover", "push_button", "latching_switch", "limit_switch"].has(data["type"]):
		data["sequence"] = doc.next_contact_sequence(data["designation"])
	if data["type"] == "terminal" and str(data.get("label", "")).is_empty():
		# The next free number, also past those of strip terminals on leads.
		data["label"] = doc.next_strip_label()
	if data["type"] == "connector" and str(data.get("label", "")).is_empty():
		data["label"] = doc.next_connector_label()
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
		if wire_on_drop:
			doc.connect_pairs(doc.facing_pairs(PackedStringArray([c.id]), _page_ids()))
	_clear_selection()
	selected_components[c.id] = true
	if c is PowerSupply and PHASES.has(data["conductor"]):
		_phase_step += 1
	_changed()
	_rebuild_ghost()


## What the place tool puts down next: its template, a phase supply placed
## after others moved on by [member _phase_step] phases (L1 → L2 → L3 →
## L1), except where a single-phase drawing names its phase plain "L".
func _placed_data() -> Dictionary:
	var data: Dictionary = _template.duplicate()
	if data.get("type", "") == "supply" and PHASES.has(str(data.get("conductor", ""))) and _phase_step > 0:
		if document().next_supply_designation(PowerSupply.Conductor.L) != "L" and not document().next_supply_designation(PowerSupply.Conductor.L).begins_with("L."):
			data["conductor"] = PHASES[(PHASES.find(str(data["conductor"])) + _phase_step) % PHASES.size()]
	return data


## True when other parts carry the designation of [param c].
func _designation_shared(c: CircuitComponent) -> bool:
	for other: CircuitComponent in document().circuit.get_components():
		if other != c and other.designation == c.designation:
			return true
	return false


## Parts that are renamed together with their device: a relay or contactor
## with its contacts, an overload relay with its contacts.
static func _designation_group(c: CircuitComponent) -> String:
	if c is OverloadRelay or c is OverloadContact:
		return "overload"
	if c is Coil or c is Contact or c is ChangeoverContact or c is MainContacts:
		return "relay"
	if c is PushButton:
		return "push_button"
	if c is LimitSwitch:
		return "limit_switch"
	if c is LatchingSwitch:
		return "switch"
	return ""


## What a part is to the device its designation names: the device itself
## ("coil", "overload", "breaker", or "operator" for push buttons, switches
## and limit switches, of which a device may have several blocks), one of its
## contacts ("contact"), or "" for a part with a designation of its own.
static func _device_role(c: CircuitComponent) -> String:
	if c is OverloadRelay:
		return "overload"
	if c is Coil:
		return "coil"
	if c is CircuitBreaker or c is MotorBreaker:
		return "breaker"
	if c is PushButton or c is LatchingSwitch:
		return "operator"
	if c is Contact or c is ChangeoverContact or c is MainContacts or c is OverloadContact:
		return "contact"
	return ""


## True when [param replacement] (replacing [param old]) may carry its
## designation: only parts of one device share it. A device is one coil,
## overload relay or circuit breaker, or any number of push buttons, switches
## and limit switches (sharing one actuator), with any number of contacts.
func _designation_free(old: CircuitComponent, replacement: CircuitComponent) -> bool:
	var parts: Array[CircuitComponent] = [replacement]
	for c: CircuitComponent in document().circuit.get_components():
		if c != old and c.designation == replacement.designation:
			parts.append(c)
	if parts.size() == 1:
		return true
	var device: String = ""
	for part: CircuitComponent in parts:
		var role: String = _device_role(part)
		if role.is_empty():
			return false
		if role == "contact":
			continue
		if device.is_empty():
			device = role
		elif role != device or role != "operator":
			return false
	if device.is_empty():
		return true
	# Contacts only of a kind the device takes (the circuit links them).
	for part: CircuitComponent in parts:
		if _device_role(part) == "contact" and not _contact_of(part, device):
			return false
	return true


## True when the contact [param c] works as part of a device of [param role]
## ([method _device_role]): main contacts of a coil or of a button, switch or
## limit switch, changeover contacts also of a breaker (auxiliary contacts),
## a plain contact also of an overload relay (it becomes its overload
## contact), an overload contact of an overload relay alone.
static func _contact_of(c: CircuitComponent, role: String) -> bool:
	if c is OverloadContact:
		return role == "overload"
	if c is MainContacts:
		return role == "coil" or role == "operator"
	if c is ChangeoverContact:
		return role != "overload"
	return role != "overload" or not (c as Contact).delayed


## Id of a part of the device [param old] that cannot take the designation
## [param designation] it is renamed to, because a part of that name with
## its numbers exists already (main contacts, overload contacts); "" when
## all can go along (contacts take the next free sequence digit).
func _rename_clash(old: CircuitComponent, designation: String) -> String:
	for part: CircuitComponent in document().circuit.get_components():
		if part == old or part.designation != old.designation or _designation_group(part) != _designation_group(old):
			continue
		if part is Contact or part is ChangeoverContact:
			continue
		var part_data: Dictionary = DocumentSerializer.component_to_dict(part)
		part_data["designation"] = designation
		var renamed: CircuitComponent = DocumentSerializer.component_from_dict(part_data)
		if renamed != null and not _can_replace(part, renamed):
			return renamed.id
	return ""


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


## Designation for a new part made from [param data]; [param changing] is
## the id of a part being turned into it (never taken as its device).
func _new_designation(data: Dictionary, changing: String = "") -> String:
	var doc: SchematicDocument = document()
	match data["type"]:
		"supply":
			return doc.next_supply_designation(_conductor(data))
		"push_button":
			return doc.next_device_designation("SB")
		"latching_switch", "cam_switch":
			return doc.next_device_designation("RB")
		"limit_switch":
			return doc.next_device_designation("SQ")
		"fuse":
			return doc.next_designation("FU")
		"breaker":
			return doc.next_device_designation("FA")
		"overload_relay":
			return doc.next_device_designation("F")
		"main_contacts":
			# Belongs to the selected contactor, else to the first one, as
			# long as its main contacts are not drawn yet.
			var preferred: PackedStringArray = PackedStringArray()
			for id: String in selected_components:
				var picked: CircuitComponent = doc.circuit.get_component(id)
				if picked is Coil and not (picked is TimerRelay):
					preferred.append(picked.designation)
			return doc.main_contacts_designation(preferred)
		"overload_contact":
			for id: String in selected_components:
				var chosen: CircuitComponent = doc.circuit.get_component(id)
				if chosen is OverloadRelay and _overload_contact_free(chosen.designation, data):
					return chosen.designation
			for c: CircuitComponent in doc.circuit.get_components():
				if c is OverloadRelay and _overload_contact_free(c.designation, data):
					return c.designation
			return doc.next_designation("F")
		"contact", "changeover":
			# Belongs to the selected coil (or overload relay), else to the
			# first coil of the right kind.
			var want_timer: bool = data.get("delayed", false)
			for id: String in selected_components:
				var relay: CircuitComponent = doc.circuit.get_component(id)
				if relay is OverloadRelay and data["type"] == "contact" and not want_timer and _overload_contact_free(relay.designation, data):
					return relay.designation
			for id: String in selected_components:
				var selected: CircuitComponent = doc.circuit.get_component(id)
				if selected is Coil and (selected is TimerRelay or not want_timer):
					return selected.designation
			# Another block of the selected button or switch, or an
			# auxiliary contact of the selected breaker.
			for id: String in selected_components:
				var device: CircuitComponent = doc.circuit.get_component(id)
				if id != changing and not want_timer and _device_role(device) in ["operator", "breaker"]:
					return device.designation
			for c: CircuitComponent in doc.circuit.get_components():
				if c is Coil and (c is TimerRelay) == want_timer:
					return c.designation
			# No coil yet: the contactor whose main contacts are drawn, else KM1.
			return doc.next_device_designation("KT" if want_timer else "KM")
		"coil":
			# Contactor KM, auxiliary (control) relay KA; it takes contacts
			# drawn before it (e.g. main contacts KM1) rather than skip them.
			return doc.next_device_designation("KA" if data.get("kind", "contactor") == "relay" else "KM")
		"timer":
			return doc.next_device_designation("KT")
		"lamp":
			return doc.next_designation("H")
		"rectifier":
			return doc.next_designation("TB")
		"plc":
			return doc.next_designation("A")
		"temp_sensor":
			return doc.next_designation("BT")
		"vfd":
			return doc.next_designation("TA")
		"motor", "motor3":
			return doc.next_designation("M")
		"terminal":
			return doc.next_designation("X")
		"connector":
			# Never shown: the connector shows its label.
			return doc.next_designation("PC")
	return doc.next_designation("X")


## True while the overload relay [param designation] has no contact of the
## kind of [param data] (NC 95-96, NO 97-98) drawn yet.
func _overload_contact_free(designation: String, data: Dictionary) -> bool:
	var nc: bool = str(data.get("contact", "NO")) == "NC"
	for c: CircuitComponent in document().circuit.get_components():
		if c is OverloadContact and c.designation == designation and ((c as OverloadContact).contact_type == SwitchingElement.ContactType.NC) == nc:
			return false
	return true


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
## (splitting it with a junction). Ending on a terminal, the poles beside it
## go along (see [member wire_all_poles]) unless [param alone].
func _finish_wire(key: String, wire_index: int, alone: bool = false) -> void:
	var doc: SchematicDocument = document()
	_record()
	var end_key: String = key
	var preview: Array[Vector2i] = _preview_points()
	if wire_index >= 0:
		var cell: Vector2i = doc.wire_cell_near(wire_index, _mouse_point)
		preview = _route_to(cell)
		end_key = doc.split_wire(wire_index, cell)
	if end_key.is_empty() or end_key == _wire_start or doc.wire_between(_wire_start, end_key) >= 0:
		# Nothing to join, or the two terminals have a wire already.
		history.discard_last()
		_cancel_tool()
		return
	var points: Array[Vector2i] = _wire_points.duplicate()
	for i: int in range(1, preview.size()):
		points.append(preview[i])
	points[points.size() - 1] = doc.terminal_cell(end_key)
	var clean: Array[Vector2i] = SchematicDocument.orthogonalize(points, doc.terminal_axis(_wire_start), doc.terminal_axis(end_key))
	var poles: Array[PackedStringArray] = doc.parallel_pairs(_wire_start, end_key) if wire_all_poles and not alone and wire_index < 0 else ([] as Array[PackedStringArray])
	doc.connect_terminals(_wire_start, end_key, clean.slice(1, clean.size() - 1))
	doc.connect_pairs(poles)
	tool = Tool.SELECT
	_wire_start = ""
	_wire_points.clear()
	_changed()
	_emit_hint()


## Wire under the mouse that the wire being drawn would end on (with a
## junction), or -1. Wires already joined to the start terminal do not count:
## a click on them adds a corner, as joining them would only close a loop.
func _wire_to_join() -> int:
	var doc: SchematicDocument = document()
	var w: int = doc.wire_at(_mouse_point)
	if w < 0:
		return -1
	var wires: Array[PackedStringArray] = doc.circuit.get_wires()
	for i: int in wires.size():
		if wires[i].has(_wire_start):
			return -1 if doc.wire_net(i).has(w) else w
	return w


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


## Moves the dragged parts [param delta] cells from where they were at the
## press; their wires are routed from their routes at the press.
func _drag_to(delta: Vector2i) -> void:
	if delta == _drag_applied or selected_components.is_empty():
		return
	if not _drag_recorded:
		_drag_snapshot = DocumentSerializer.to_dict(document())
		history.record(_drag_snapshot)
		_drag_recorded = true
		_drag_start = document().drag_start(PackedStringArray(selected_components.keys()))
	document().drag_components(_drag_start, delta)
	_drag_applied = delta
	if wire_on_drop:
		_drop_pairs = document().facing_pairs(PackedStringArray(selected_components.keys()), _page_ids())
	view.rebuild()


## Ids of the parts on the page shown.
func _page_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for c: CircuitComponent in document().components_on_page():
		ids.append(c.id)
	return ids


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
	if hit is Plc:
		plc_requested.emit(hit.id)
		return true
	if hit != null:
		var kind: String = "designation"
		if hit is Lamp:
			kind = "purpose"
		elif hit is TerminalBlock or hit is PageConnector:
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
	if c is Junction or (c is PowerSupply and kind != "strip") or kind == "plate":
		return false
	var text: String = c.designation
	match kind:
		"terminal":
			text = c.get_terminal_names()[index]
		"strip":
			text = CabinetDevices.terminal_text(document().get_placement(c.id).strips.get(index, ""))
		"purpose":
			text = (c as Lamp).purpose
		"label":
			text = (c as PageConnector).label if c is PageConnector else CabinetDevices.terminal_text((c as TerminalBlock).label)
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
	if target["kind"] == "strip":
		value = CabinetDevices.label_from_text(value)
		if value != document().get_placement(c.id).strips.get(target["index"], "") and not value.is_empty():
			_record()
			document().set_strip_terminal(c.id, target["index"], value)
			_changed()
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
			var index: int = target["index"]
			if value == names[index]:
				return
			# The name of another terminal of the part: the two swap.
			var other: int = names.find(value)
			if c is TimerRelay and (index < 2 or other == 0 or other == 1) and not (index < 2 and other >= 0 and other < 2):
				# A1 and A2 of a time relay are not renamed, only swapped.
				hint_changed.emit(tr("A1 and A2 of a time relay can only be swapped with each other."))
				return
			if other >= 0:
				names[other] = names[index]
			names[index] = value
			data["terminals"] = names
		"purpose":
			if value == (c as Lamp).purpose:
				return
			data["purpose"] = value
		"label":
			if c is TerminalBlock:
				value = CabinetDevices.label_from_text(value)
			if value == ((c as PageConnector).label if c is PageConnector else (c as TerminalBlock).label):
				return
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
	for c: CircuitComponent in doc.components_on_page():
		if box.intersects(doc.component_body(c)):
			selected_components[c.id] = true
	for w: int in doc.wires_on_page():
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
	_end_drags()
	if _ghost != null:
		_ghost.free()
		_ghost = null
	_emit_hint()
	queue_redraw()


## Ends any drag of parts, a wire segment, a wire number or a marking as when
## the button is let go, and drops a frame selection: after a delete, undo or
## redo they would go on with parts and wires no longer there.
func _end_drags() -> void:
	var applied: bool = (_marking_drag and _marking_drag_recorded) or (_number_drag.x >= 0 and _number_drag_recorded) or (_wire_drag >= 0 and _wire_drag_recorded)
	if _dragging and _drag_recorded:
		if DocumentSerializer.to_dict(document()) == _drag_snapshot:
			history.discard_last()
		else:
			applied = true
	_dragging = false
	_drag_start = {}
	_drop_pairs.clear()
	_boxing = false
	_wire_drag = -1
	_number_drag = Vector2i(-1, -1)
	_marking_drag = false
	if applied:
		_changed()


func _rebuild_ghost() -> void:
	if _ghost != null:
		_ghost.free()
		_ghost = null
	var data: Dictionary = _placed_data()
	data["designation"] = _new_designation(data)
	var placement: Placement = Placement.new(_mouse_cell, _ghost_rotation, _ghost_mirrored)
	_ghost = SymbolFactory.create(DocumentSerializer.component_from_dict(data), placement)
	_ghost.modulate = Color(1, 1, 1, 0.5)
	add_child(_ghost)
	_update_ghost_wires()


func _update_ghost_wires() -> void:
	_ghost_wires_cell = _mouse_cell
	_ghost_wires.clear()
	if wire_on_drop and _ghost != null:
		_ghost_wires = document().facing_wires_placed(_ghost.component, _mouse_cell, _ghost_rotation, _ghost_mirrored)


# --- State ----------------------------------------------------------------------

func _record() -> void:
	history.record(DocumentSerializer.to_dict(document()))


func _restore(snapshot: Dictionary) -> void:
	# A marking being typed belongs to the state left.
	_close_inline()
	_clear_selection()
	document_replaced.emit(DocumentSerializer.from_dict(snapshot))
	edited.emit()
	queue_redraw()


## Call after every edit of the document.
func _changed() -> void:
	# Next to L2 or L3 a plain L supply becomes L1 (and stays selected).
	var renamed: Dictionary[String, String] = document().name_first_phase()
	# Cables of the workspace keep their names, new ones get the next.
	document().name_cables()
	for id: String in renamed:
		if selected_components.erase(id):
			selected_components[renamed[id]] = true
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
			if wire_all_poles:
				hint_changed.emit(tr("Click empty cells for corners, finish on a terminal or a wire; the poles beside go along (Shift: this wire alone). Backspace removes a corner, Esc cancels."))
			else:
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
		_draw_wires(_ghost_wires)
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
	for c: CircuitComponent in doc.components_on_page():
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
		var w: int = _wire_to_join()
		if w >= 0 and doc.terminal_at(_mouse_point).is_empty():
			var cell: Vector2i = doc.wire_cell_near(w, _mouse_point)
			preview = _route_to(cell)
			draw_circle(Vector2(cell) * G, 5.0, PREVIEW_COLOR)
		for i: int in range(1, preview.size()):
			points.append(preview[i])
		if points.size() >= 2:
			draw_polyline(_pixels(points), PREVIEW_COLOR, 2.5)
		var end_key: String = doc.terminal_at(_mouse_point)
		if wire_all_poles and not end_key.is_empty() and end_key != _wire_start and not Input.is_key_pressed(KEY_SHIFT):
			_draw_pairs(doc.parallel_pairs(_wire_start, end_key))
	if _dragging and _drag_recorded:
		_draw_pairs(_drop_pairs)
	if not _line_up.is_empty():
		_draw_line_up_ruler()
	# Selection box.
	if _boxing:
		var box: Rect2 = Rect2(_box_origin * G, Vector2.ZERO).expand(_mouse_point * G)
		draw_rect(box, Color(SELECTION_COLOR, 0.1))
		draw_rect(box, SELECTION_COLOR, false, 1.0)


## The ruler of the line-up being asked for: along the top of a row or the
## left of a column, a tick at every cell numbered from the first part, and
## the cells each part will take with the spacing in the dialog marked.
func _draw_line_up_ruler() -> void:
	var doc: SchematicDocument = document()
	var vertical: bool = _line_up["vertical"]
	var axis: int = 1 if vertical else 0
	var across: int = 1 - axis
	var area: Rect2 = _line_up_area()
	var parts: Rect2 = _line_up_area(false)
	var from: int = floori(parts.position[axis])
	var to: int = ceili(parts.end[axis]) + 2
	# The band, beyond the parts and their markings, half a cell thick.
	var band_near: float = area.position[across] - 0.5
	var band_far: float = band_near - 0.5
	var band: Callable = func(a: float, b: float) -> Rect2:
		var start: Vector2 = Vector2.ZERO
		var end: Vector2 = Vector2.ZERO
		start[axis] = a
		end[axis] = b
		start[across] = band_far
		end[across] = band_near
		return Rect2(start * G, (end - start) * G)
	# Paper under the band and its numbers, so they read over anything drawn there.
	var backing: Rect2 = band.call(float(from) - 0.5, float(to) + 0.5)
	backing = backing.expand(backing.position - (Vector2(1.6, 0.0) if vertical else Vector2(0.0, 0.8)) * G)
	draw_rect(backing, SchematicTheme.BACKGROUND)
	var cells: Dictionary[String, Rect2i] = doc.line_up_cells(_line_up["ids"], vertical, int(_line_up_spin.value))
	for id: String in cells:
		draw_rect(band.call(float(cells[id].position[axis]), float(cells[id].end[axis])), Color(SELECTION_COLOR, 0.3))
	draw_rect(band.call(float(from), float(to)), SchematicTheme.LINE, false, 1.0)
	# Numbers on every cell, or every fifth when the cells are small on screen.
	var on_screen: float = G * get_global_transform_with_canvas().get_scale().x
	var every: int = 1 if on_screen >= 16.0 else 5
	var font: Font = AppTheme.schematic_font()
	var font_size: int = 9
	for n: int in range(0, to - from + 1):
		var at: float = float(from + n)
		var tick: float = 0.35 if n % 5 == 0 else 0.2
		var a: Vector2 = Vector2.ZERO
		var b: Vector2 = Vector2.ZERO
		a[axis] = at
		b[axis] = at
		a[across] = band_near
		b[across] = band_near - tick
		draw_line(a * G, b * G, SchematicTheme.LINE, 1.0)
		if n % every != 0:
			continue
		var text: String = str(n)
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var ascent: float = font.get_ascent(font_size)
		var pos: Vector2
		if vertical:
			pos = Vector2(band_far * G - text_size.x - 3.0, at * G + ascent * 0.5 - 1.0)
		else:
			pos = Vector2(at * G - text_size.x * 0.5, band_far * G - 3.0)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, SchematicTheme.TEXT)


## Dashed wires the wiring helpers would add between the terminal pairs
## [param pairs] (straight, or with one corner).
func _draw_pairs(pairs: Array[PackedStringArray]) -> void:
	var doc: SchematicDocument = document()
	var wires: Array[PackedVector2Array] = []
	for pair: PackedStringArray in pairs:
		var points: Array[Vector2i] = SchematicDocument.orthogonalize([doc.terminal_cell(pair[0]), doc.terminal_cell(pair[1])] as Array[Vector2i], doc.terminal_axis(pair[0]), doc.terminal_axis(pair[1]))
		var line: PackedVector2Array = PackedVector2Array()
		for p: Vector2i in points:
			line.append(Vector2(p))
		wires.append(line)
	_draw_wires(wires)


## Dashed wires along the cells of each of [param wires].
func _draw_wires(wires: Array[PackedVector2Array]) -> void:
	for line: PackedVector2Array in wires:
		for i: int in range(1, line.size()):
			draw_dashed_line(line[i - 1] * G, line[i] * G, PREVIEW_COLOR, 2.0, 6.0)


func _pixels(points: Array[Vector2i]) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2i in points:
		result.append(Vector2(p) * G)
	return result
