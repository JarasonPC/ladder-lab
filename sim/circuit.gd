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
	_by_id[component.id] = component
	for key: String in keys:
		_terminal_owner[key] = component
	if component is Coil:
		var coil: Coil = component as Coil
		_coils[coil.designation] = coil
		for c: CircuitComponent in _components:
			if c is Contact and c.designation == coil.designation:
				(c as Contact).linked_coil = coil
	elif component is Contact:
		(component as Contact).linked_coil = _coils.get(component.designation, null)
	topology_version += 1
	return component


## Connects two terminals, e.g. connect_terminals("S1:14", "K1:A1").
func connect_terminals(key_a: String, key_b: String) -> bool:
	for key: String in [key_a, key_b]:
		if not _terminal_owner.has(key):
			push_error("Circuit: unknown terminal '%s'" % key)
			return false
	_wires.append(PackedStringArray([key_a, key_b]))
	topology_version += 1
	return true


func get_component(component_id: String) -> CircuitComponent:
	return _by_id.get(component_id, null)


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
