class_name SchematicView
extends Node2D
## Shows a [SchematicDocument] and runs its simulation. Push buttons are held
## with the left mouse button, switches toggle on click.

signal stepped(result: StepResult)

const G: float = float(SymbolGeometry.GRID)
const BLINK_PERIOD: float = 0.5

var document: SchematicDocument
var simulator: Simulator
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


func load_document(doc: SchematicDocument) -> void:
	for child: Node in get_children():
		child.queue_free()
	_symbols.clear()
	_held = null
	_hovered = null
	document = doc
	simulator = Simulator.new(doc.circuit)
	sim_time = 0.0
	_wire_layer = WireLayer.new()
	add_child(_wire_layer)
	_wire_layer.set_document(doc)
	for c: CircuitComponent in doc.circuit.get_components():
		var symbol: SchematicSymbol = SymbolFactory.create(c, doc.get_placement(c.id))
		add_child(symbol)
		_symbols[c.id] = symbol
	_apply(simulator.step())


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
	if running:
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
	var current: Dictionary[String, bool] = {}
	for id: String in last_result.current_components:
		current[id] = true
	_wire_layer.current_wires.clear()
	for w: int in last_result.current_wires:
		_wire_layer.current_wires[w] = true
	_wire_layer.fault = last_result.short_circuit
	_wire_layer.blink_on = blink_on
	_wire_layer.queue_redraw()
	for id: String in _symbols:
		var symbol: SchematicSymbol = _symbols[id]
		symbol.carries_current = current.has(id)
		symbol.warning = blink_on and last_result.oscillating_tags.has(symbol.component.designation) and not (symbol.component is PowerSupply)
		symbol.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if document == null:
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
	if symbol == _hovered:
		return
	if _hovered != null:
		_hovered.hovered = false
		_hovered.queue_redraw()
	_hovered = symbol
	if _hovered != null:
		_hovered.hovered = true
		_hovered.queue_redraw()
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if _hovered != null else Input.CURSOR_ARROW)
