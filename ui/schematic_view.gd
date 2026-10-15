class_name SchematicView
extends Node2D
## Shows a [SchematicDocument]. When [member simulating], runs its simulation:
## push buttons are held with the left mouse button, switches toggle on click.
## Otherwise the schematic is shown at rest for editing.

signal stepped(result: StepResult)
## Something was operated or a fault changed outside the simulation step
## (English text with %s placeholders, see [member StepResult.events]).
signal event_logged(text: String, args: Array)

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
## Simulated seconds since the document was loaded.
var sim_time: float:
	get:
		return simulator.time if simulator != null else 0.0

var _wire_layer: WireLayer
var _symbols: Dictionary[String, SchematicSymbol] = {}
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


## Recreates all symbol nodes, e.g. after the document was edited.
func rebuild() -> void:
	_set_hovered(null)
	for child: Node in get_children():
		if child != _fault_menu:
			child.free()
	_symbols.clear()
	_held = null
	_wire_layer = WireLayer.new()
	add_child(_wire_layer)
	_wire_layer.set_document(document)
	for c: CircuitComponent in document.circuit.get_components():
		var symbol: SchematicSymbol = SymbolFactory.create(c, document.get_placement(c.id))
		add_child(symbol)
		_symbols[c.id] = symbol
	_update_visuals()


func get_symbol(component_id: String) -> SchematicSymbol:
	return _symbols.get(component_id, null)


## Call after placements changed (e.g. the document was transposed).
func refresh_layout() -> void:
	for id: String in _symbols:
		_symbols[id].update_position()
	_wire_layer.refresh_layout()
	_update_visuals()


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
	if simulating:
		_apply(simulator.step())


func _process(delta: float) -> void:
	if document == null:
		return
	_blink_time = fmod(_blink_time + delta, BLINK_PERIOD)
	if simulating and running:
		_apply(simulator.step(delta * speed))
	else:
		_update_visuals()


func _apply(result: StepResult) -> void:
	last_result = result
	_update_visuals()
	stepped.emit(result)


func _update_visuals() -> void:
	var blink_on: bool = _blink_time < BLINK_PERIOD * 0.5
	var reach_of: Dictionary[String, int] = last_result.terminal_reach
	_wire_layer.wire_reach = last_result.wire_reach
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
			if c is Fuse or c is CircuitBreaker or c is OverloadRelay or c is OverloadContact:
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
		elif _held != null:
			_held.release()
			_held = null
			_apply(simulator.step())
			get_viewport().set_input_as_handled()


## Replaces a blown fuse, switches a breaker, resets a tripped overload relay.
## Returns false if nothing happened.
func _operate_protection(c: CircuitComponent) -> bool:
	if c is Fuse:
		if not (c as Fuse).tripped:
			return false
		(c as Fuse).reset()
		event_logged.emit("%s replaced", [c.designation])
	elif c is CircuitBreaker:
		var breaker: CircuitBreaker = c as CircuitBreaker
		var was_tripped: bool = breaker.tripped
		breaker.toggle()
		event_logged.emit("%s reset" if was_tripped else ("%s switched on" if breaker.switched_on else "%s switched off"), [c.designation])
	else:
		var relay: OverloadRelay = document.circuit.get_overload_relay(c.designation)
		if relay == null or not relay.tripped:
			return false
		relay.reset()
		event_logged.emit("%s reset", [c.designation])
	return true


func _open_fault_menu() -> void:
	var point: Vector2 = get_local_mouse_position() / G
	_fault_target = document.component_at(point)
	_fault_wire = document.wire_at(point) if _fault_target == null else -1
	_fault_menu.clear()
	if _fault_target is SwitchingElement and not (_fault_target is ProtectiveDevice) or _fault_target is ChangeoverContact:
		_fault_menu.add_item(tr("Contact welded (stays closed)"), FaultId.WELDED)
		_fault_menu.add_item(tr("Contact burnt (does not close)"), FaultId.CONTACT_OPEN)
	elif _fault_target is Coil:
		_fault_menu.add_item(tr("Coil broken (no pull-in)"), FaultId.COIL_OPEN)
		_fault_menu.add_item(tr("Armature stuck"), FaultId.COIL_STUCK)
	elif _fault_target is OverloadRelay:
		_fault_menu.add_item(tr("Overload"), FaultId.OVERLOAD)
	elif _fault_wire >= 0:
		_fault_menu.add_item(tr("Broken wire"), FaultId.WIRE_BROKEN)
	if _fault_menu.item_count > 0:
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
			else:
				(c as SwitchingElement).fault = fault
			event_logged.emit("Fault: %s welded" if id == FaultId.WELDED else "Fault: %s burnt", [c.id])
		FaultId.COIL_OPEN, FaultId.COIL_STUCK:
			(c as Coil).fault = Coil.Fault.OPEN if id == FaultId.COIL_OPEN else Coil.Fault.STUCK
			event_logged.emit("Fault: coil %s broken" if id == FaultId.COIL_OPEN else "Fault: %s armature stuck", [c.designation])
		FaultId.OVERLOAD:
			(c as OverloadRelay).overloaded = true
			event_logged.emit("Fault: overload on %s", [c.designation])
		FaultId.WIRE_BROKEN:
			document.circuit.set_wire_broken(_fault_wire, true)
			_wire_layer.queue_redraw()
			event_logged.emit("Fault: broken wire %s", [" – ".join(document.circuit.get_wires()[_fault_wire])])
		FaultId.CLEAR:
			if c != null:
				_clear_fault(c)
			elif _fault_wire >= 0:
				document.circuit.set_wire_broken(_fault_wire, false)
			event_logged.emit("Fault removed", [])
		FaultId.CLEAR_ALL:
			for component: CircuitComponent in document.circuit.get_components():
				_clear_fault(component)
			for w: int in document.circuit.broken_wires.keys():
				document.circuit.set_wire_broken(w, false)
			event_logged.emit("All faults removed", [])
	_apply(simulator.step())


static func _has_fault(c: CircuitComponent) -> bool:
	if c is SwitchingElement:
		return (c as SwitchingElement).fault != SwitchingElement.Fault.NONE
	if c is ChangeoverContact:
		return (c as ChangeoverContact).fault != SwitchingElement.Fault.NONE
	if c is Coil:
		return (c as Coil).fault != Coil.Fault.NONE
	if c is OverloadRelay:
		return (c as OverloadRelay).overloaded
	return false


static func _clear_fault(c: CircuitComponent) -> void:
	if c is SwitchingElement:
		(c as SwitchingElement).fault = SwitchingElement.Fault.NONE
	elif c is ChangeoverContact:
		(c as ChangeoverContact).fault = SwitchingElement.Fault.NONE
	elif c is Coil:
		(c as Coil).fault = Coil.Fault.NONE
	elif c is OverloadRelay:
		(c as OverloadRelay).overloaded = false


func _component_under_mouse() -> CircuitComponent:
	return document.component_at(get_local_mouse_position() / G)


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
