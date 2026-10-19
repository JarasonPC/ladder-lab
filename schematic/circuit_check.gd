class_name CircuitCheck
extends RefCounted
## Finds likely mistakes in a schematic. Each issue is a Dictionary:
## "text": English message with %s placeholders (translate it, then format),
## "args": values for the placeholders, "ids": components to select.


static func run(doc: SchematicDocument) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var circuit: Circuit = doc.circuit
	# Conductors of the AC supply and poles of the DC supply drawn.
	var ac: Dictionary[PowerSupply.Conductor, bool] = {}
	var dc: Dictionary[PowerSupply.Conductor, bool] = {}
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
			if conductor == PowerSupply.Conductor.DC_PLUS or conductor == PowerSupply.Conductor.DC_MINUS:
				dc[conductor] = true
			elif conductor != PowerSupply.Conductor.PE:
				ac[conductor] = true
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
		if c is Vfd:
			# Its supply and motor output must be wired, the rest may stay open.
			keys = PackedStringArray([keys[Vfd.L1], keys[Vfd.L1 + 1], keys[Vfd.L1 + 2], keys[Vfd.U], keys[Vfd.U + 1], keys[Vfd.U + 2]])
		if c is Plc:
			# Inputs and outputs the circuit does not use may stay open, the
			# supply of the PLC and of its expansion modules not.
			issues.append_array(_plc_issues(c as Plc, connected, doc))
			keys = _plc_supply(c as Plc)
		if c is TimerRelay and not (c as TimerRelay).control_input and TimerRelay.uses_control((c as TimerRelay).mode):
			var code: String = TimerRelay.MODE_CODES[(c as TimerRelay).mode]
			issues.append(_issue("Function %s of time relay %s works with its control input S, which is turned off.", [code, c.designation], [c.id]))
		if c is TimerRelay and keys.size() > 2 and not TimerRelay.uses_control((c as TimerRelay).mode):
			# The control input of a function that does not use it may stay open.
			keys = keys.slice(0, 2)
		for key: String in keys:
			if not connected.has(key):
				issues.append(_issue("Terminal %s is not connected.", [key], [c.id]))
	# Loads work between two conductors of one source: two of L1 L2 L3 N,
	# or + and -.
	if ac.is_empty() and dc.is_empty():
		issues.append(_issue("The circuit has no L supply.", [], []))
		issues.append(_issue("The circuit has no N supply.", [], []))
	elif ac.size() == 1:
		issues.append(_issue("The circuit has no L supply." if ac.has(PowerSupply.Conductor.N) else "The circuit has no N supply.", [], []))
	if dc.size() == 1:
		issues.append(_issue("The circuit has no - supply." if dc.has(PowerSupply.Conductor.DC_PLUS) else "The circuit has no + supply.", [], []))
	return issues


## Terminals of [param plc] that must be wired: its supply and that of each
## expansion module that needs one (digital signal modules of a compact CPU
## work with the CPU).
static func _plc_supply(plc: Plc) -> PackedStringArray:
	var keys: PackedStringArray = plc.get_terminal_keys()
	var supply: PackedStringArray = keys.slice(0, 2)
	for m: int in plc.modules.size():
		var first: int = plc.module_supply(m)
		if first >= 0:
			supply.append_array(keys.slice(first, first + 2))
	return supply


## Hints on a PLC whose wired inputs or outputs cannot work: their common or
## output supply (1M, 3L+ 3M of a compact CPU and its digital modules) left
## open, and analog modules fed from the AC supply (they take 24 V DC).
static func _plc_issues(plc: Plc, connected: Dictionary[String, bool], doc: SchematicDocument) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var keys: PackedStringArray = plc.get_terminal_keys()
	var required: PackedStringArray = _plc_supply(plc)
	# Supply terminal -> the input and output terminals that need it.
	var users: Dictionary[int, PackedInt32Array] = {}
	for k: int in plc.input_count():
		var common: int = plc.input_reference(k)
		if not users.has(common):
			users[common] = PackedInt32Array()
		users[common].append(plc.input_terminal(k))
	for path: Vector2i in plc.switch_paths():
		if plc.terminal_role(path.y) != Plc.Role.TQ:
			continue
		# A group of transistor outputs: its L+ and the M laid out after it.
		for t: int in [path.x, path.x + 1]:
			if plc.terminal_role(t) == Plc.Role.SUPPLY:
				if not users.has(t):
					users[t] = PackedInt32Array()
				users[t].append(path.y)
	for t: int in users:
		if connected.has(keys[t]) or required.has(keys[t]):
			continue
		for used: int in users[t]:
			if connected.has(keys[used]):
				issues.append(_issue("Terminal %s is not connected, but the inputs or outputs using it are.", [keys[t]], [plc.id]))
				break
	var net: Dictionary[String, int] = {}
	for m: int in plc.modules.size():
		var first: int = plc.module_supply(m)
		if first < 0 or not Plc.is_analog(plc.modules[m]):
			continue
		if net.is_empty():
			net = CabinetDevices.nets(doc.circuit)
		var ac: bool = false
		for c: CircuitComponent in doc.circuit.get_components():
			if c is PowerSupply and _is_ac(c as PowerSupply):
				var at: int = net[c.get_terminal_keys()[0]]
				ac = ac or at == net[keys[first]] or at == net[keys[first + 1]]
		if ac:
			issues.append(_issue("Analog module %s of %s takes 24 V DC on %s and %s, not the AC supply.", [m + 2, plc.designation, keys[first], keys[first + 1]], [plc.id]))
	return issues


## True for L1, L2, L3 and N (not the DC poles, not PE).
static func _is_ac(supply: PowerSupply) -> bool:
	return supply.conductor in [PowerSupply.Conductor.L, PowerSupply.Conductor.N, PowerSupply.Conductor.L2, PowerSupply.Conductor.L3]


static func _issue(text: String, args: Array, ids: Array) -> Dictionary:
	return {"text": text, "args": args, "ids": PackedStringArray(ids)}
