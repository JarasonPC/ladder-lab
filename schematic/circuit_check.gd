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
	var connector_labels: Dictionary[String, int] = {}
	for c: CircuitComponent in circuit.get_components():
		if c is Contact or c is ChangeoverContact or c is MainContacts:
			contact_designations[c.designation] = true
		if c is PageConnector:
			var label: String = (c as PageConnector).label
			connector_labels[label] = connector_labels.get(label, 0) + 1

	for c: CircuitComponent in circuit.get_components():
		if c is PowerSupply:
			var conductor: PowerSupply.Conductor = (c as PowerSupply).conductor
			if conductor == PowerSupply.Conductor.L or conductor == PowerSupply.Conductor.DC_PLUS:
				has_l = true
			elif conductor != PowerSupply.Conductor.PE:
				has_n = true
		if c is Contact:
			var contact: Contact = c as Contact
			if not contact.has_device():
				issues.append(_issue("Contact %s has no coil %s.", [c.id, c.designation], [c.id]))
			elif contact.delayed and not (contact.linked_coil is TimerRelay):
				issues.append(_issue("Delayed contact %s belongs to %s, which is not a timer.", [c.id, c.designation], [c.id]))
		if c is ChangeoverContact:
			var changeover: ChangeoverContact = c as ChangeoverContact
			if not changeover.has_device():
				issues.append(_issue("Contact %s has no coil %s.", [c.id, c.designation], [c.id]))
			elif changeover.delayed and not (changeover.linked_coil is TimerRelay):
				issues.append(_issue("Delayed contact %s belongs to %s, which is not a timer.", [c.id, c.designation], [c.id]))
		if c is MainContacts and (c as MainContacts).get_armature() == null:
			issues.append(_issue("Contact %s has no coil %s.", [c.id, c.designation], [c.id]))
		if c is OverloadContact and (c as OverloadContact).linked_relay == null:
			issues.append(_issue("Overload contact %s has no overload relay %s.", [c.id, c.designation], [c.id]))
		if c is Coil and not contact_designations.has(c.designation):
			issues.append(_issue("Coil %s has no contacts.", [c.designation], [c.id]))
		if c is Junction:
			continue
		if c is PageConnector:
			var link: String = (c as PageConnector).label
			if not connected.has(c.designation):
				issues.append(_issue("Page connector %s is not connected to a wire.", [link], [c.id]))
			elif link.is_empty() or connector_labels[link] < 2:
				issues.append(_issue("Page connector %s does not continue anywhere: no other page connector has its label.", [link], [c.id]))
			continue
		var keys: PackedStringArray = c.get_terminal_keys()
		if c is ThreePhaseMotor:
			# The PE terminal of the frame may stay open on the drawing.
			keys = keys.slice(0, (c as ThreePhaseMotor).winding_terminal_count())
		if c is Plc:
			# Inputs and outputs the circuit does not use may stay open.
			keys = keys.slice(0, 2)
		if c is TimerRelay and keys.size() > 2 and not TimerRelay.uses_control((c as TimerRelay).mode):
			# The control input of a function that does not use it may stay open.
			keys = keys.slice(0, 2)
		for key: String in keys:
			if not connected.has(key):
				issues.append(_issue("Terminal %s is not connected.", [key], [c.id]))
	if not has_l:
		issues.append(_issue("The circuit has no L supply.", [], []))
	if not has_n:
		issues.append(_issue("The circuit has no N supply.", [], []))
	return issues


static func _issue(text: String, args: Array, ids: Array) -> Dictionary:
	return {"text": text, "args": args, "ids": PackedStringArray(ids)}
