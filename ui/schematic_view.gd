class_name SchematicView
extends Node2D
## Shows a [SchematicDocument]. When [member simulating], runs its simulation:
## push buttons are held with the left mouse button, switches toggle on click.
## Otherwise the schematic is shown at rest for editing.

signal stepped(result: StepResult)

const G: float = float(SymbolGeometry.GRID)
const BLINK_PERIOD: float = 0.5

var document: SchematicDocument
var simulator: Simulator
var simulating: bool = true
var running: bool = true
## Simulation time multiplier.
var speed: float = 1.0
## Simulated seconds since the document was loaded.
var sim_time: float = 0.0
var last_result: StepResult = StepResult.new()

var _wire_layer: WireLayer
var _symbols: Dictionary[String, SchematicSymbol] = {}
var _held: PushButton = null
var _hovered: SchematicSymbol = null
var _blink_time: float = 0.0


func load_document(doc: SchematicDocument, simulate: bool = true) -> void:
	document = doc
	simulating = simulate
	simulator = Simulator.new(doc.circuit)
	sim_time = 0.0
	rebuild()
	if simulating:
		_apply(simulator.step())
	else:
		_apply(StepResult.new())


## Recreates all symbol nodes, e.g. after the document was edited.
func rebuild() -> void:
	_set_hovered(null)
	for child: Node in get_children():
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
	sim_time += dt
	_apply(simulator.step(dt))


func _process(delta: float) -> void:
	if document == null:
		return
	_blink_time = fmod(_blink_time + delta, BLINK_PERIOD)
	if simulating and running:
		sim_time += delta * speed
		_apply(simulator.step(delta * speed))
	else:
		_update_visuals()


func _apply(result: StepResult) -> void:
	last_result = result
	_update_visuals()
	stepped.emit(result)


func _update_visuals() -> void:
	var blink_on: bool = _blink_time < BLINK_PERIOD * 0.5
	var live_keys: Dictionary[String, bool] = {}
	for key: String in last_result.live_terminals:
		live_keys[key] = true
	_wire_layer.live_wires.clear()
	for w: int in last_result.live_wires:
		_wire_layer.live_wires[w] = true
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
			symbol.live[k] = 1 if live_keys.has(keys[k]) else 0
		symbol.warning = blink_on and last_result.oscillating_tags.has(symbol.component.designation) and not (symbol.component is PowerSupply)
		symbol.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if document == null or not simulating:
		return
	if event is InputEventMouseMotion:
		_update_hover()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			var c: CircuitComponent = _component_under_mouse()
			if c is PushButton:
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
