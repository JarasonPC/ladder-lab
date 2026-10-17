class_name SchematicView
extends Node2D
## Shows the current page of a [SchematicDocument] (the simulation runs on
## all pages). When [member simulating], runs its simulation:
## push buttons are held with the left mouse button, switches toggle on click.
## Otherwise the schematic is shown at rest for editing.
## A view following another one (see [method follow], a page window) shows
## its own [member page] of the same document and simulation.

signal stepped(result: StepResult)
## Something was operated or a fault changed outside the simulation step
## (English text with %s placeholders, see [member StepResult.events]).
signal event_logged(text: String, args: Array)
## A document was loaded (for simulating or for editing).
signal loaded
## A page connector was clicked while simulating: show page [param index],
## centred on its partner [param focus_id].
signal page_requested(index: int, focus_id: String)
## A PLC was clicked while simulating: show its program running.
signal plc_requested(component_id: String)
## The symbols were recreated (a document was loaded, it was edited, another
## page was chosen) or moved.
signal rebuilt

enum FaultId { WELDED, CONTACT_OPEN, COIL_OPEN, COIL_STUCK, OVERLOAD, WIRE_BROKEN, CLEAR, CLEAR_ALL }

const G: float = float(SymbolGeometry.GRID)
const BLINK_PERIOD: float = 0.5

var document: SchematicDocument
var simulator: Simulator
var simulating: bool = true
var running: bool = true
## Simulation time multiplier.
var speed: float = 1.0
var last_result: StepResult = StepResult.new()
## History of coil power, armature positions and loads for the timing chart.
var trace: TraceRecorder = TraceRecorder.new()
## Page shown; -1: the document's current page.
var page: int = -1
## The view this one follows, sharing its document and simulation (it runs
## no simulation of its own), or null.
var source: SchematicView = null
## Simulated seconds since the document was loaded.
var sim_time: float:
	get:
		return simulator.time if simulator != null else 0.0

var _wire_layer: WireLayer
var _grid_visible: bool = false
var _numbers_visible: bool = true
var _path_numbers_visible: bool = true
## Current view: only what carries current is coloured, with the currents
## written on the wires; else the voltage view.
var _current_view: bool = false
## Clamp meter tool: a click on a wire clamps the meter on it (or takes it off).
var clamp_tool: bool = false
## Clamp meters on wires: wire index -> grid point where it is clamped
## (simulation only; a view following another one shows the other's).
var clamps: Dictionary[int, Vector2] = {}
var _symbols: Dictionary[String, SchematicSymbol] = {}
## Zoom the symbols were last drawn for.
var _drawn_scale: float = 0.0
var _held: PushButton = null
var _hovered: SchematicSymbol = null
var _blink_time: float = 0.0
var _fault_menu: PopupMenu
var _fault_target: CircuitComponent = null
var _fault_wire: int = -1
var _right_press: Vector2 = Vector2.ZERO


func _ready() -> void:
	_fault_menu = PopupMenu.new()
	_fault_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_fault_menu.id_pressed.connect(_on_fault_menu)
	add_child(_fault_menu)


func load_document(doc: SchematicDocument, simulate: bool = true) -> void:
	document = doc
	clamps.clear()
	simulating = simulate
	simulator = Simulator.new(doc.circuit)
	simulator.mode = Simulator.Mode.REALISTIC if doc.realistic_timing else Simulator.Mode.IDEAL
	trace = TraceRecorder.new()
	simulator.trace = trace
	rebuild()
	if simulating:
		_apply(simulator.step())
	else:
		_apply(StepResult.new())
	loaded.emit()


## Recreates all symbol nodes, e.g. after the document was edited or another
## page was chosen.
func rebuild() -> void:
	_set_hovered(null)
	for child: Node in get_children():
		if child != _fault_menu:
			child.free()
	_symbols.clear()
	_held = null
	_wire_layer = WireLayer.new()
	_wire_layer.show_grid = _grid_visible
	_wire_layer.show_numbers = _numbers_visible
	_wire_layer.show_path_numbers = _path_numbers_visible
	_wire_layer.current_view = _current_view
	if page >= document.pages.size():
		page = document.pages.size() - 1
	_wire_layer.page = page
	add_child(_wire_layer)
	_wire_layer.set_document(document)
	for c: CircuitComponent in document.components_on_page(page):
		var symbol: SchematicSymbol = SymbolFactory.create(c, document.get_placement(c.id))
		if symbol is PageConnectorSymbol:
			(symbol as PageConnectorSymbol).reference = document.connector_reference(c.id)
		add_child(symbol)
		_symbols[c.id] = symbol
	_update_visuals()
	rebuilt.emit()


## Shows the document and the simulation of [param view] (page [member page]),
## and keeps following it: what is operated here acts on its simulation.
func follow(view: SchematicView) -> void:
	if source != view:
		if source != null and source.rebuilt.is_connected(_on_source_rebuilt):
			source.rebuilt.disconnect(_on_source_rebuilt)
		source = view
		source.rebuilt.connect(_on_source_rebuilt)
	document = source.document
	simulator = source.simulator
	trace = source.trace
	simulating = source.simulating
	last_result = source.last_result
	rebuild()


## The followed view loaded a document or rebuilt its symbols after an edit.
func _on_source_rebuilt() -> void:
	if source.document != document or source.simulator != simulator or source.simulating != simulating:
		follow(source)
	else:
		rebuild()


## Everything drawn on the page, in cells, as last drawn: symbols and wires,
## the markings and other texts of the symbols (also where they were
## dragged to), the wire numbers and the current path numbers.
func drawn_extent() -> Rect2:
	var r: Rect2 = document.bounds(page)
	for symbol: SchematicSymbol in _symbols.values():
		for rect: Rect2 in symbol.text_rects:
			r = r.merge(Rect2((rect.position + symbol.position) / G, rect.size / G))
	if _wire_layer != null and _wire_layer.drawn_extent().has_area():
		r = r.merge(_wire_layer.drawn_extent())
	return r


func get_symbol(component_id: String) -> SchematicSymbol:
	return _symbols.get(component_id, null)


## Shows or hides the wire numbers.
func set_wire_numbers_visible(on: bool) -> void:
	_numbers_visible = on
	if _wire_layer != null:
		_wire_layer.show_numbers = on
		_wire_layer.queue_redraw()


## Shows or hides the current path numbers.
func set_path_numbers_visible(on: bool) -> void:
	_path_numbers_visible = on
	if _wire_layer != null:
		_wire_layer.show_path_numbers = on
		_wire_layer.queue_redraw()
## Switches between the current view ([param on]) and the voltage view.
func set_current_view(on: bool) -> void:
	_current_view = on
	if _wire_layer != null:
		_wire_layer.current_view = on
		_update_visuals()


## Shows or hides the dot grid behind the drawing.
func set_grid_visible(on: bool) -> void:
	_grid_visible = on
	if _wire_layer != null:
		_wire_layer.show_grid = on
		_wire_layer.queue_redraw()


## Wire end whose number is written at grid point [param point], as
## Vector2i(wire, end), or Vector2i(-1, -1).
func wire_number_at(point: Vector2) -> Vector2i:
	return _wire_layer.wire_number_at(point) if _wire_layer != null else Vector2i(-1, -1)


## Box (in cells) around the drawn number of wire end [param end].
func wire_number_rect(end: Vector2i) -> Rect2:
	return _wire_layer.wire_number_rect(end) if _wire_layer != null else Rect2()


## Call after placements changed (e.g. the document was transposed).
func refresh_layout() -> void:
	for id: String in _symbols:
		_symbols[id].update_position()
	_wire_layer.refresh_layout()
	_update_visuals()
	rebuilt.emit()


## Advances the simulation by [param dt] seconds (used while paused).
func step_once(dt: float = 0.1) -> void:
	_apply(simulator.step(dt))


## Switches between realistic and instant relays without restarting.
func set_realistic_timing(on: bool) -> void:
	document.realistic_timing = on
	if simulator == null:
		return
	simulator.mode = Simulator.Mode.REALISTIC if on else Simulator.Mode.IDEAL
	if not on:
		# Instant switching: finish every movement in progress.
		for c: CircuitComponent in document.circuit.get_components():
			if c is Coil:
				(c as Coil).snap()
			elif c is Plc:
				(c as Plc).snap()
	if simulating:
		_apply(simulator.step())


func _process(delta: float) -> void:
	if document == null:
		return
	# Symbols draw their antialiasing for the current zoom: redraw on zoom.
	var scale_now: float = get_global_transform_with_canvas().get_scale().x
	if not is_equal_approx(scale_now, _drawn_scale):
		_drawn_scale = scale_now
		for symbol: SchematicSymbol in _symbols.values():
			symbol.queue_redraw()
	_blink_time = fmod(_blink_time + delta, BLINK_PERIOD)
	if source != null:
		# The followed view runs the simulation; show its latest step.
		last_result = source.last_result
		_update_visuals()
	elif simulating and running:
		_apply(simulator.step(delta * speed))
	else:
		_update_visuals()


func _apply(result: StepResult) -> void:
	if source != null:
		# The followed view shows the step too and reports it.
		source._apply(result)
	last_result = result
	_update_visuals()
	if source == null:
		stepped.emit(result)


## Reports [param text] (see [signal event_logged]) through the followed view,
## if any.
func _log(text: String, args: Array) -> void:
	if source != null:
		source.event_logged.emit(text, args)
	else:
		event_logged.emit(text, args)


func _update_visuals() -> void:
	var blink_on: bool = _blink_time < BLINK_PERIOD * 0.5
	var reach_of: Dictionary[String, int] = last_result.terminal_reach
	_wire_layer.wire_reach = last_result.wire_reach
	_wire_layer.wire_currents = last_result.wire_currents
	_wire_layer.clamps = source.clamps if source != null else clamps
	_wire_layer.short_circuit = last_result.short_circuit
	_wire_layer.fault_wires.clear()
	if last_result.short_circuit:
		for w: int in last_result.current_wires:
			_wire_layer.fault_wires[w] = true
	_wire_layer.blink_on = blink_on
	_wire_layer.queue_redraw()
	for id: String in _symbols:
		var symbol: SchematicSymbol = _symbols[id]
		var keys: PackedStringArray = symbol.component.get_terminal_keys()
		symbol.live.resize(keys.size())
		for k: int in keys.size():
			symbol.live[k] = reach_of.get(keys[k], SchematicSymbol.REACH_NONE)
			if _current_view and not last_result.short_circuit and not last_result.terminal_currents.has(keys[k]):
				# Current view: a terminal no current flows through is drawn dead.
				symbol.live[k] = SchematicSymbol.REACH_NONE
		symbol.warning = blink_on and last_result.oscillating_tags.has(symbol.component.designation) and not (symbol.component is PowerSupply)
		symbol.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if document == null or not simulating:
		return
	if event is InputEventMouseMotion:
		_update_hover()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		var rb: InputEventMouseButton = event as InputEventMouseButton
		if rb.pressed:
			_right_press = rb.position
		elif rb.position.distance_to(_right_press) < 6.0:
			_open_fault_menu()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			var c: CircuitComponent = _component_under_mouse()
			if clamp_tool and c == null and _toggle_clamp():
				get_viewport().set_input_as_handled()
				return
			# A contact of a button or switch operates the device.
			var operator: CircuitComponent = operator_of(c)
			if operator != null:
				c = operator
			if c is Fuse or c is CircuitBreaker or c is ThreePoleFuse or c is MotorBreaker or c is OverloadRelay or c is OverloadContact:
				if _operate_protection(c):
					_apply(simulator.step())
					get_viewport().set_input_as_handled()
			elif c is PushButton:
				_held = c as PushButton
				_held.press()
				_apply(simulator.step())
				get_viewport().set_input_as_handled()
			elif c is LatchingSwitch:
				(c as LatchingSwitch).toggle()
				_apply(simulator.step())
				get_viewport().set_input_as_handled()
			elif c is Plc:
				plc_requested.emit(c.id)
				get_viewport().set_input_as_handled()
			elif c is PageConnector:
				var targets: Array[Dictionary] = document.connector_targets(c.id)
				if not targets.is_empty():
					page_requested.emit(targets[0]["page"], targets[0]["id"])
					get_viewport().set_input_as_handled()
		elif _held != null:
			_held.release()
			_held = null
			_apply(simulator.step())
			get_viewport().set_input_as_handled()


## Clamps the meter on the wire under the mouse, or takes it off. Returns
## false when there is no wire there.
func _toggle_clamp() -> bool:
	var point: Vector2 = get_local_mouse_position() / G
	var w: int = document.wire_at(point, 0.4, page)
	if w < 0:
		return false
	var on: Dictionary[int, Vector2] = source.clamps if source != null else clamps
	if on.has(w):
		on.erase(w)
	else:
		var points: Array[Vector2i] = document.wire_points(w)
		var best: Vector2 = Vector2(points[0])
		for s: int in range(1, points.size()):
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, Vector2(points[s - 1]), Vector2(points[s]))
			if closest.distance_to(point) < best.distance_to(point):
				best = closest
		on[w] = best
	_update_visuals()
	return true


## Presses or releases push button [param designation] (all its blocks), as
## from a control box of the operator panel.
func hold_button(designation: String, pressed: bool) -> void:
	var c: CircuitComponent = document.circuit.get_operator(designation) if document != null else null
	if not simulating or not (c is PushButton):
		return
	if pressed:
		(c as PushButton).press()
	else:
		(c as PushButton).release()
	_apply(simulator.step())


## Turns switch [param designation] over, as from a control box.
func toggle_switch(designation: String) -> void:
	var c: CircuitComponent = document.circuit.get_operator(designation) if document != null else null
	if not simulating or not (c is LatchingSwitch):
		return
	(c as LatchingSwitch).toggle()
	_apply(simulator.step())


## Operates breaker, fuse holder or overload relay [param designation] as a
## click on its symbol does, from the switchboard.
func operate_device(designation: String) -> void:
	var c: CircuitComponent = document.circuit.get_component(designation) if document != null else null
	if simulating and c != null and _operate_protection(c):
		_apply(simulator.step())


## Replaces a blown fuse, switches a breaker, trips an overload relay by its
## test button or resets it when tripped. Returns false if nothing happened.
func _operate_protection(c: CircuitComponent) -> bool:
	if c is Fuse:
		var fuse: Fuse = c as Fuse
		if fuse.tripped:
			fuse.reset()
			_log("%s replaced", [c.designation])
		elif fuse.holder:
			fuse.toggle()
			_log("%s switched on" if fuse.switched_on else "%s switched off", [c.designation])
		else:
			return false
	elif c is CircuitBreaker:
		var breaker: CircuitBreaker = c as CircuitBreaker
		var was_tripped: bool = breaker.tripped
		breaker.toggle()
		_log("%s reset" if was_tripped else ("%s switched on" if breaker.switched_on else "%s switched off"), [c.designation])
	elif c is ThreePoleFuse:
		var fuse3: ThreePoleFuse = c as ThreePoleFuse
		if fuse3.any_blown():
			fuse3.reset()
			_log("%s replaced", [c.designation])
		elif fuse3.holder:
			fuse3.toggle()
			_log("%s switched on" if fuse3.switched_on else "%s switched off", [c.designation])
		else:
			return false
	elif c is MotorBreaker:
		var motor_breaker: MotorBreaker = c as MotorBreaker
		var breaker_tripped: bool = motor_breaker.tripped
		motor_breaker.toggle()
		_log("%s reset" if breaker_tripped else ("%s switched on" if motor_breaker.switched_on else "%s switched off"), [c.designation])
	else:
		var relay: OverloadRelay = document.circuit.get_overload_relay(c.designation)
		if relay == null:
			return false
		if relay.tripped:
			relay.reset()
			_log("%s reset", [c.designation])
		else:
			relay.test_trip()
			_log("%s tripped by hand (test button)", [c.designation])
	return true


func _open_fault_menu() -> void:
	var point: Vector2 = get_local_mouse_position() / G
	_fault_target = document.component_at(point, page)
	_fault_wire = document.wire_at(point, 0.3, page) if _fault_target == null else -1
	_fault_menu.clear()
	if _fault_target is SwitchingElement and not (_fault_target is ProtectiveDevice) or _fault_target is ChangeoverContact or _fault_target is MainContacts:
		_fault_menu.add_item(tr("Contact welded (stays closed)"), FaultId.WELDED)
		_fault_menu.add_item(tr("Contact burnt (does not close)"), FaultId.CONTACT_OPEN)
	elif _fault_target is Coil:
		_fault_menu.add_item(tr("Coil broken (no pull-in)"), FaultId.COIL_OPEN)
		_fault_menu.add_item(tr("Armature stuck"), FaultId.COIL_STUCK)
	elif _fault_target is OverloadRelay:
		_fault_menu.add_item(tr("Overload"), FaultId.OVERLOAD)
	elif _fault_target is ThreePhaseMotor:
		_fault_menu.add_item(tr("Motor overloaded"), FaultId.OVERLOAD)
	elif _fault_wire >= 0:
		_fault_menu.add_item(tr("Broken wire"), FaultId.WIRE_BROKEN)
	if _fault_target is Load and (_fault_target as Load).burnt and _fault_menu.item_count == 0:
		_fault_menu.add_item(tr("Replace the burnt-out part"), FaultId.CLEAR)
		_fault_menu.add_separator()
	elif _fault_menu.item_count > 0:
		if _has_fault(_fault_target) or document.circuit.broken_wires.has(_fault_wire):
			_fault_menu.add_item(tr("Remove fault"), FaultId.CLEAR)
		_fault_menu.add_separator()
	_fault_menu.add_item(tr("Remove all faults"), FaultId.CLEAR_ALL)
	_fault_menu.reset_size()
	_fault_menu.popup_on_parent(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i.ZERO))


func _on_fault_menu(id: int) -> void:
	var c: CircuitComponent = _fault_target
	match id:
		FaultId.WELDED, FaultId.CONTACT_OPEN:
			var fault: SwitchingElement.Fault = SwitchingElement.Fault.WELDED if id == FaultId.WELDED else SwitchingElement.Fault.OPEN
			if c is ChangeoverContact:
				(c as ChangeoverContact).fault = fault
			elif c is MainContacts:
				(c as MainContacts).fault = fault
			else:
				(c as SwitchingElement).fault = fault
			_log("Fault: %s welded" if id == FaultId.WELDED else "Fault: %s burnt", [c.id])
		FaultId.COIL_OPEN, FaultId.COIL_STUCK:
			(c as Coil).fault = Coil.Fault.OPEN if id == FaultId.COIL_OPEN else Coil.Fault.STUCK
			_log("Fault: coil %s broken" if id == FaultId.COIL_OPEN else "Fault: %s armature stuck", [c.designation])
		FaultId.OVERLOAD:
			if c is ThreePhaseMotor:
				(c as ThreePhaseMotor).overloaded = true
			else:
				(c as OverloadRelay).overloaded = true
			_log("Fault: overload on %s", [c.designation])
		FaultId.WIRE_BROKEN:
			document.circuit.set_wire_broken(_fault_wire, true)
			_wire_layer.queue_redraw()
			_log("Fault: broken wire %s", [" – ".join(document.circuit.get_wires()[_fault_wire])])
		FaultId.CLEAR:
			if c != null:
				_clear_fault(c)
			elif _fault_wire >= 0:
				document.circuit.set_wire_broken(_fault_wire, false)
			_log("Fault removed", [])
		FaultId.CLEAR_ALL:
			for component: CircuitComponent in document.circuit.get_components():
				_clear_fault(component)
			for w: int in document.circuit.broken_wires.keys():
				document.circuit.set_wire_broken(w, false)
			_log("All faults removed", [])
	_apply(simulator.step())


static func _has_fault(c: CircuitComponent) -> bool:
	if c is Load and (c as Load).burnt:
		return true
	if c is SwitchingElement:
		return (c as SwitchingElement).fault != SwitchingElement.Fault.NONE
	if c is ChangeoverContact:
		return (c as ChangeoverContact).fault != SwitchingElement.Fault.NONE
	if c is Coil:
		return (c as Coil).fault != Coil.Fault.NONE
	if c is MainContacts:
		return (c as MainContacts).fault != SwitchingElement.Fault.NONE
	if c is OverloadRelay:
		return (c as OverloadRelay).overloaded
	if c is ThreePhaseMotor:
		return (c as ThreePhaseMotor).overloaded
	return false


static func _clear_fault(c: CircuitComponent) -> void:
	if c is Load:
		(c as Load).burnt = false
	if c is SwitchingElement:
		(c as SwitchingElement).fault = SwitchingElement.Fault.NONE
	elif c is ChangeoverContact:
		(c as ChangeoverContact).fault = SwitchingElement.Fault.NONE
	elif c is Coil:
		(c as Coil).fault = Coil.Fault.NONE
	elif c is MainContacts:
		(c as MainContacts).fault = SwitchingElement.Fault.NONE
	elif c is OverloadRelay:
		(c as OverloadRelay).overloaded = false
	elif c is ThreePhaseMotor:
		(c as ThreePhaseMotor).overloaded = false


## The button or switch that [param c] (a contact or main contacts without a
## coil) is a block of, or null.
func operator_of(c: CircuitComponent) -> CircuitComponent:
	var follows: bool = (c is Contact and (c as Contact).linked_actuator != null) or (c is ChangeoverContact and (c as ChangeoverContact).linked_actuator != null) or (c is MainContacts and (c as MainContacts).linked_actuator != null)
	return document.circuit.get_operator(c.designation) if follows else null


func _component_under_mouse() -> CircuitComponent:
	return document.component_at(get_local_mouse_position() / G, page)


func _update_hover() -> void:
	var c: CircuitComponent = _component_under_mouse()
	var symbol: SchematicSymbol = _symbols.get(c.id, null) if c != null else null
	if symbol != null and not symbol.is_interactive():
		symbol = null
	_set_hovered(symbol)


func _set_hovered(symbol: SchematicSymbol) -> void:
	if symbol == _hovered:
		return
	if _hovered != null and is_instance_valid(_hovered):
		_hovered.hovered = false
		_hovered.queue_redraw()
	_hovered = symbol
	if _hovered != null:
		_hovered.hovered = true
		_hovered.queue_redraw()
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if _hovered != null else Input.CURSOR_ARROW)


## Shows page [param index] of the document.
func show_page(index: int) -> void:
	document.page = index
	rebuild()
