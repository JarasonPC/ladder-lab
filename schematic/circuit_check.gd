class_name CircuitCheck
extends RefCounted
## Finds likely mistakes in a schematic. Each issue is a Dictionary:
## "text": English message with %s placeholders (translate it, then format),
## "args": values for the placeholders, "ids": components to select.


static func run(doc: SchematicDocument) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var circuit: Circuit = doc.circuit
	var has_l: bool = false
	var has_n: bool = false
	var connected: Dictionary[String, bool] = {}
	for wire: PackedStringArray in circuit.get_wires():
		connected[wire[0]] = true
		connected[wire[1]] = true
	var contact_designations: Dictionary[String, bool] = {}
	for c: CircuitComponent in circuit.get_components():
		if c is Contact:
			contact_designations[c.designation] = true

	for c: CircuitComponent in circuit.get_components():
		if c is PowerSupply:
			if (c as PowerSupply).conductor == PowerSupply.Conductor.L:
				has_l = true
			else:
				has_n = true
		if c is Contact:
			var contact: Contact = c as Contact
			if contact.linked_coil == null:
				issues.append(_issue("Contact %s has no coil %s.", [c.id, c.designation], [c.id]))
			elif contact.delayed and not (contact.linked_coil is TimerRelay):
				issues.append(_issue("Delayed contact %s belongs to %s, which is not a timer.", [c.id, c.designation], [c.id]))
		if c is Coil and not contact_designations.has(c.designation):
			issues.append(_issue("Coil %s has no contacts.", [c.designation], [c.id]))
		if c is Junction:
			continue
		for key: String in c.get_terminal_keys():
			if not connected.has(key):
				issues.append(_issue("Terminal %s is not connected.", [key], [c.id]))
	if not has_l:
		issues.append(_issue("The circuit has no L supply.", [], []))
	if not has_n:
		issues.append(_issue("The circuit has no N supply.", [], []))
	return issues


static func _issue(text: String, args: Array, ids: Array) -> Dictionary:
	return {"text": text, "args": args, "ids": PackedStringArray(ids)}
