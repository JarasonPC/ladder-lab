class_name Circuit
extends RefCounted
## A circuit: components plus wires between their terminals.
## Holds no simulation logic; see [Simulator].

## Incremented whenever components or wires change.
var topology_version: int = 0

var _components: Array[CircuitComponent] = []
var _by_id: Dictionary[String, CircuitComponent] = {}
var _terminal_owner: Dictionary[String, CircuitComponent] = {}
var _coils: Dictionary[String, Coil] = {}
var _overload_relays: Dictionary[String, OverloadRelay] = {}
## Simulation faults: indices of wires that are broken. Never saved.
var broken_wires: Dictionary[int, bool] = {}
var _wires: Array[PackedStringArray] = []


## Adds a component and returns it, or null if its id or a terminal is taken.
func add(component: CircuitComponent) -> CircuitComponent:
	if _by_id.has(component.id):
		push_error("Circuit: duplicate component id '%s'" % component.id)
		return null
	var keys: PackedStringArray = component.get_terminal_keys()
	for key: String in keys:
		if _terminal_owner.has(key):
			push_error("Circuit: terminal '%s' already exists" % key)
			return null
	_components.append(component)
	_register(component)
	topology_version += 1
	return component


## Removes a component. Returns the indices of the wires that were attached to
## it and removed with it, highest first.
func remove(component: CircuitComponent) -> PackedInt32Array:
	var removed: PackedInt32Array = wires_of(component)
	broken_wires.clear()
	for i: int in removed:
		_wires.remove_at(i)
	_components.erase(component)
	_unregister(component)
	topology_version += 1
	return removed


## Puts [param new_component] in place of [param old], keeping its position in
## the component order. Wires move to the new terminals by terminal index, so
## e.g. an NO contact 13-14 replaced by an NC contact 11-12 keeps its wiring.
## Fails if a terminal the new component lacks still has wires, or an id or
## terminal is taken.
func replace(old: CircuitComponent, new_component: CircuitComponent) -> bool:
	var index: int = _components.find(old)
	var old_keys: PackedStringArray = old.get_terminal_keys()
	var new_keys: PackedStringArray = new_component.get_terminal_keys()
	# Terminals beyond the new count must have no wires (see
	# SchematicDocument.replace_component); the others keep theirs by position.
	var dropped: bool = false
	for i: int in range(new_keys.size(), old_keys.size()):
		for wire: PackedStringArray in _wires:
			if wire.has(old_keys[i]):
				dropped = true
	if index < 0 or dropped:
		push_error("Circuit: cannot replace '%s' with '%s'" % [old.id, new_component.id])
		return false
	if new_component.id != old.id and _by_id.has(new_component.id):
		push_error("Circuit: duplicate component id '%s'" % new_component.id)
		return false
	for key: String in new_keys:
		if _terminal_owner.has(key) and _terminal_owner[key] != old:
			push_error("Circuit: terminal '%s' already exists" % key)
			return false
	_unregister(old)
	_components[index] = new_component
	_register(new_component)
	for i: int in _wires.size():
		var wire: PackedStringArray = _wires[i]
		for end: int in 2:
			var k: int = old_keys.find(wire[end])
			if k >= 0:
				wire[end] = new_keys[k]
		_wires[i] = wire
	topology_version += 1
	return true


func remove_wire(index: int) -> void:
	_wires.remove_at(index)
	broken_wires.clear()
	topology_version += 1


## Simulation fault: a broken wire no longer connects its terminals.
func set_wire_broken(index: int, broken: bool) -> void:
	if broken:
		broken_wires[index] = true
	else:
		broken_wires.erase(index)
	topology_version += 1


func get_overload_relay(designation: String) -> OverloadRelay:
	return _overload_relays.get(designation, null)


## Indices of the wires attached to a component, highest first.
func wires_of(component: CircuitComponent) -> PackedInt32Array:
	var keys: PackedStringArray = component.get_terminal_keys()
	var result: PackedInt32Array = PackedInt32Array()
	for i: int in range(_wires.size() - 1, -1, -1):
		if keys.has(_wires[i][0]) or keys.has(_wires[i][1]):
			result.append(i)
	return result


func _register(component: CircuitComponent) -> void:
	_by_id[component.id] = component
	for key: String in component.get_terminal_keys():
		_terminal_owner[key] = component
	if component is Coil:
		_coils[component.designation] = component as Coil
	elif component is OverloadRelay:
		_overload_relays[component.designation] = component as OverloadRelay
	_relink_contacts()


func _unregister(component: CircuitComponent) -> void:
	_by_id.erase(component.id)
	for key: String in component.get_terminal_keys():
		_terminal_owner.erase(key)
	if component is Coil and _coils.get(component.designation, null) == component:
		_coils.erase(component.designation)
	elif component is OverloadRelay and _overload_relays.get(component.designation, null) == component:
		_overload_relays.erase(component.designation)
	_relink_contacts()


## Links contacts to their coil and makes the blocks of each button or switch
## share the actuator of its first block.
func _relink_contacts() -> void:
	var buttons: Dictionary[String, Armature] = {}
	var switches: Dictionary[String, Armature] = {}
	for c: CircuitComponent in _components:
		if c is Contact:
			(c as Contact).linked_coil = _coils.get(c.designation, null)
		elif c is ChangeoverContact:
			(c as ChangeoverContact).linked_coil = _coils.get(c.designation, null)
		elif c is MainContacts:
			(c as MainContacts).linked_coil = _coils.get(c.designation, null)
		elif c is OverloadContact:
			(c as OverloadContact).linked_relay = _overload_relays.get(c.designation, null)
		elif c is PushButton:
			var button: PushButton = c as PushButton
			if buttons.has(c.designation):
				button.actuator = buttons[c.designation]
			else:
				buttons[c.designation] = button.actuator
		elif c is LatchingSwitch:
			# Limit switches and switches share actuators by designation alike.
			var switch: LatchingSwitch = c as LatchingSwitch
			if switches.has(c.designation):
				switch.actuator = switches[c.designation]
			else:
				switches[c.designation] = switch.actuator


## Connects two terminals, e.g. connect_terminals("S1:14", "K1:A1").
func connect_terminals(key_a: String, key_b: String) -> bool:
	for key: String in [key_a, key_b]:
		if not _terminal_owner.has(key):
			push_error("Circuit: unknown terminal '%s'" % key)
			return false
	_wires.append(PackedStringArray([key_a, key_b]))
	topology_version += 1
	return true


## True if a component has exactly this id.
func has_component_id(component_id: String) -> bool:
	return _by_id.has(component_id)


## Component by id ("K1", "S1:13-14"), or else the first component with that
## designation ("S1" finds the button's first block).
func get_component(component_id: String) -> CircuitComponent:
	if _by_id.has(component_id):
		return _by_id[component_id]
	for c: CircuitComponent in _components:
		if c.designation == component_id:
			return c
	return null


func get_coil(designation: String) -> Coil:
	return _coils.get(designation, null)


func get_components() -> Array[CircuitComponent]:
	return _components


func get_wires() -> Array[PackedStringArray]:
	return _wires


func has_terminal(key: String) -> bool:
	return _terminal_owner.has(key)


## Component that owns a terminal, or null.
func get_terminal_owner(key: String) -> CircuitComponent:
	return _terminal_owner.get(key, null)
