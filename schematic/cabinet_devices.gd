class_name CabinetDevices
extends RefCounted
## What the switchboard (rozvaděč) shows of a circuit: the devices that sit
## on DIN rails (circuit breakers, fuse holders, contactors with the overload
## relays fitted under them, auxiliary relays, time relays, bridge
## rectifiers, PLCs) and the terminal strips, with everything their look depends on (poles, contacts, terminal
## names) and their simulation state. Works on the circuit alone, no nodes.
##
## Terminal strips are made of the terminals on wires ([TerminalBlock]) and on
## component leads ([member Placement.strips]): a label "X2:4" is terminal 4
## of strip X2, a plain label "4" is terminal 4 of strip X1. Terminals with the
## same strip and label are one terminal.

enum Kind { NONE, BREAKER, FUSE, CONTACTOR, RELAY, TIMER, OVERLOAD, RECTIFIER, PLC, VFD }
## Conductor a net is wired with in the switchboard (see [method conductors]):
## the phase of the control circuit (red), the neutral (light blue), the
## main power circuit (grey) and the protective conductor.
enum Conductor { CONTROL, NEUTRAL, POWER, PE }

## Strip of the terminals whose label names none.
const DEFAULT_STRIP: String = "X1"
## Changeover contacts an auxiliary relay and a time relay have; more take
## further relays beside them, whose coil terminals are named after the
## first one's with UNIT and their number ("A1#2").
const RELAY_CONTACTS: int = 4
const TIMER_CONTACTS: int = 3
const UNIT: String = "#"


## Kind of device [param c] is in the switchboard, NONE for parts that are
## not devices of their own (contacts, main contacts) or sit elsewhere
## (buttons, lamps, motors, supplies).
static func kind_of(c: CircuitComponent) -> Kind:
	if c is CircuitBreaker or c is MotorBreaker:
		return Kind.BREAKER
	if c is Fuse or c is ThreePoleFuse:
		return Kind.FUSE
	if c is TimerRelay:
		return Kind.TIMER
	if c is Coil:
		return Kind.CONTACTOR if (c as Coil).kind == Coil.Kind.CONTACTOR else Kind.RELAY
	if c is OverloadRelay:
		return Kind.OVERLOAD
	if c is Rectifier:
		return Kind.RECTIFIER
	if c is Plc:
		return Kind.PLC
	if c is Vfd:
		return Kind.VFD
	return Kind.NONE


## Designations of the devices that can sit on a rail, in circuit order. An
## overload relay fitted under its contactor is not a place of its own.
static func devices(doc: SchematicDocument) -> PackedStringArray:
	var under: Dictionary[String, String] = overloads_under_contactors(doc.circuit)
	var fitted: Dictionary[String, bool] = {}
	for contactor: String in under:
		fitted[under[contactor]] = true
	var result: PackedStringArray = PackedStringArray()
	for c: CircuitComponent in doc.circuit.get_components():
		if kind_of(c) != Kind.NONE and not result.has(c.designation) and not fitted.has(c.designation):
			result.append(c.designation)
	return result


## The component of device [param designation] (the coil of a contactor or
## relay), or null.
static func device(circuit: Circuit, designation: String) -> CircuitComponent:
	for c: CircuitComponent in circuit.get_components():
		if c.designation == designation and kind_of(c) != Kind.NONE:
			return c
	return null


## Everything a device's drawing needs, see the keys below; {} when the
## circuit has no such device. "kind" (Kind), "poles" (breaker, fuse,
## contactor: main poles; relay: changeover contacts), "terminals"
## (terminal name on the device -> terminal key in the circuit) and the state:
## - BREAKER: "on", "rating" (characteristic and rated current, "B2")
## - FUSE: "closed", "blown"
## - CONTACTOR: "aux" ([first terminal, "NO" / "NC", last terminal] per
##   auxiliary contact, the built-in ones first, a changeover contact as an
##   NC and an NO one; every one has a place, see [method CabinetParts.contactor]),
##   "on" (armature pulled in), "energized" (coil has power), "overload"
##   (designation of the overload relay under it, or "")
## - RELAY: "on", "energized"; more than [constant RELAY_CONTACTS]
##   contacts take further relays beside it (see [method _extra_coils])
## - TIMER: "contacts", "code" (function, "F2"), "control" (name of the
##   control input), "powered", "output"; more than
##   [constant TIMER_CONTACTS] contacts take further time relays
## - OVERLOAD: "tripped"
## - RECTIFIER: "on" (its input has voltage)
## - PLC: "terminals" by the standard marking (L1, N, I1-I8, Q1.1-Q4.2, then
##   the expansion modules' 2L1, 2N, I9...), "names" (standard name -> name in
##   the schematic), "powered", "inputs" and "outputs" (one bool per input,
##   per output relay closed), "language" ("FBD" / "LAD"), "modules"
##   ([constant Plc.MODULE_NAMES]), "modules_on" (one bool per module working)
##   and "rating" (its version, see [VoltageRating])
## - VFD: "terminals", "powered", "output" (switched on), "frequency" (Hz,
##   negative in reverse)
static func describe(doc: SchematicDocument, designation: String) -> Dictionary:
	var c: CircuitComponent = device(doc.circuit, designation)
	if c == null:
		return {}
	var d: Dictionary = {"kind": kind_of(c), "designation": designation, "terminals": {}}
	match d["kind"]:
		Kind.BREAKER:
			d["poles"] = (c as MotorBreaker).poles if c is MotorBreaker else 1
			if c is MotorBreaker:
				var mb: MotorBreaker = c as MotorBreaker
				d["on"] = mb.switched_on and not mb.tripped
				d["rating"] = CircuitBreaker.rating_text(mb.characteristic, mb.rated_current)
			else:
				var cb: CircuitBreaker = c as CircuitBreaker
				d["on"] = cb.switched_on and not cb.tripped
				d["rating"] = CircuitBreaker.rating_text(cb.characteristic, cb.rated_current)
			d["terminals"] = _named_keys(c)
		Kind.FUSE:
			if c is ThreePoleFuse:
				var f3: ThreePoleFuse = c as ThreePoleFuse
				d["poles"] = f3.poles
				d["closed"] = f3.switched_on or not f3.holder
				d["blown"] = f3.any_blown()
			else:
				var f: Fuse = c as Fuse
				d["poles"] = 1
				d["closed"] = f.switched_on or not f.holder
				d["blown"] = f.tripped
			d["terminals"] = _named_keys(c)
		Kind.CONTACTOR:
			_describe_coil(doc, c as Coil, d)
		Kind.RELAY:
			_describe_coil(doc, c as Coil, d)
		Kind.TIMER:
			_describe_timer(doc, c as TimerRelay, d)
		Kind.OVERLOAD:
			_describe_overload(doc.circuit, c as OverloadRelay, d)
		Kind.RECTIFIER:
			d["on"] = (c as Rectifier).energized
			d["terminals"] = _named_keys(c)
		Kind.PLC:
			_describe_plc(c as Plc, d)
		Kind.VFD:
			var drive: Vfd = c as Vfd
			d["terminals"] = _named_keys(c)
			d["powered"] = drive.powered
			d["output"] = drive.output
			d["frequency"] = drive.frequency
	return d


static func _describe_plc(plc: Plc, d: Dictionary) -> void:
	var standard: PackedStringArray = plc.default_terminal_names()
	var names: PackedStringArray = plc.get_terminal_names()
	var keys: PackedStringArray = plc.get_terminal_keys()
	var terminals: Dictionary = {}
	var shown: Dictionary = {}
	for k: int in standard.size():
		terminals[standard[k]] = keys[k]
		shown[standard[k]] = names[k]
	d["terminals"] = terminals
	d["names"] = shown
	d["powered"] = plc.energized
	var inputs: Array[bool] = []
	for k: int in plc.input_count():
		var m: int = plc.input_module(k)
		inputs.append(plc.energized and plc.input_on(k) and (m < 0 or plc.module_on(m)))
	var outputs: Array[bool] = []
	for a: Armature in plc.output_armatures:
		outputs.append(a.no_closed)
	var modules: Array[String] = []
	var working: Array[bool] = []
	for m: int in plc.modules.size():
		modules.append(Plc.MODULE_NAMES[plc.modules[m]])
		working.append(plc.module_on(m))
	d["modules"] = modules
	d["modules_on"] = working
	d["rating"] = plc.rating
	if plc is CompactPlc:
		d["family"] = "compact"
		d["cpu"] = CompactPlc.CPU_NAMES[(plc as CompactPlc).cpu]
	d["inputs"] = inputs
	d["outputs"] = outputs
	d["language"] = "LAD" if plc.program.language == PlcProgram.Language.LAD else "FBD"


## Contacts (normal and changeover) of the relay, contactor or timer
## [param designation], ordered by their sequence digit.
static func contacts_of(circuit: Circuit, designation: String) -> Array[CircuitComponent]:
	var result: Array[CircuitComponent] = []
	for c: CircuitComponent in circuit.get_components():
		if c.designation == designation and (c is Contact or c is ChangeoverContact):
			result.append(c)
	result.sort_custom(func(a: CircuitComponent, b: CircuitComponent) -> bool: return _sequence(a) < _sequence(b))
	return result


static func _sequence(c: CircuitComponent) -> int:
	var first: String = c.get_terminal_names()[0]
	return int(first.left(first.length() - 1)) if first.length() > 1 and first.left(first.length() - 1).is_valid_int() else 0


static func _describe_coil(doc: SchematicDocument, coil: Coil, d: Dictionary) -> void:
	var circuit: Circuit = doc.circuit
	var terminals: Dictionary = {}
	var coil_keys: PackedStringArray = coil.get_terminal_keys()
	terminals["A1"] = coil_keys[0]
	terminals["A2"] = coil_keys[1]
	d["on"] = coil.armature != null and coil.armature.position >= 0.5
	d["energized"] = coil.energized
	var contacts: Array[CircuitComponent] = contacts_of(circuit, coil.designation)
	if d["kind"] == Kind.CONTACTOR:
		var mains: MainContacts = null
		for c: CircuitComponent in circuit.get_components():
			if c is MainContacts and c.designation == coil.designation:
				mains = c as MainContacts
				break
		d["poles"] = mains.poles if mains != null else 3
		if mains != null:
			terminals.merge(_named_keys(mains))
		var aux: Array = []
		for c: CircuitComponent in contacts:
			var names: PackedStringArray = c.get_terminal_names()
			var keys: PackedStringArray = c.get_terminal_keys()
			for k: int in names.size():
				terminals[names[k]] = keys[k]
			if c is ChangeoverContact:
				# Contactors have no changeover contacts: an NC and an NO one,
				# their commons joined (the second named as in _extra_coils).
				aux.append([names[0], "NC", names[1]])
				aux.append([names[0] + UNIT + "2", "NO", names[2]])
				terminals[names[0] + UNIT + "2"] = keys[0]
			else:
				aux.append([names[0], "NC" if (c as Contact).contact_type == SwitchingElement.ContactType.NC else "NO", names[1]])
		# Two auxiliary contacts are built in; the unused ones keep their
		# numbers, or take the next free ones where a terminal of the
		# contactor has those.
		var spares: Array = [["13", "NO", "14"], ["21", "NC", "22"]]
		for s: int in range(3, 10):
			spares.append([str(s) + "3", "NO", str(s) + "4"])
			spares.append([str(s) + "1", "NC", str(s) + "2"])
		for spare: Array in spares:
			if aux.size() < 2 and not terminals.has(spare[0]) and not terminals.has(spare[2]):
				aux.append(spare)
		d["aux"] = aux
		var under: Dictionary[String, String] = overloads_under_contactors(circuit)
		d["overload"] = under.get(coil.designation, "")
	else:
		d["poles"] = maxi(contacts.size(), 1)
		for k: int in contacts.size():
			_map_changeover(contacts[k], str(k + 1), "1", "2", "4", terminals)
		_extra_coils(coil_keys, PackedStringArray(["A1", "A2"]), ceili(contacts.size() / float(RELAY_CONTACTS)), terminals)
	d["terminals"] = terminals


static func _describe_timer(doc: SchematicDocument, timer: TimerRelay, d: Dictionary) -> void:
	var names: PackedStringArray = timer.get_terminal_names()
	var keys: PackedStringArray = timer.get_terminal_keys()
	var terminals: Dictionary = {"A1": keys[0], "A2": keys[1]}
	d["control"] = names[2] if names.size() > 2 else "S"
	if names.size() > 2:
		terminals[names[2]] = keys[2]
	var contacts: Array[CircuitComponent] = contacts_of(doc.circuit, timer.designation)
	d["contacts"] = maxi(contacts.size(), 1)
	for k: int in contacts.size():
		_map_changeover(contacts[k], str(k + 1), "5", "6", "8", terminals)
	var coil: PackedStringArray = PackedStringArray(["A1", "A2"])
	if names.size() > 2:
		coil.append(names[2])
	_extra_coils(keys, coil, ceili(contacts.size() / float(TIMER_CONTACTS)), terminals)
	d["terminals"] = terminals
	d["code"] = TimerRelay.code_of(timer.mode)
	d["powered"] = timer.energized
	d["output"] = timer.output


## More contacts than one relay (time relay) has take further ones beside
## it, their coils (and control inputs) wired to the first one's: the
## terminals [param names] (keys [param keys]) of relay 2, 3, ... of
## [param units] are named "A1#2", "A2#2", ... (see [constant UNIT]).
static func _extra_coils(keys: PackedStringArray, names: PackedStringArray, units: int, terminals: Dictionary) -> void:
	for u: int in range(2, units + 1):
		for k: int in names.size():
			terminals[names[k] + UNIT + str(u)] = keys[k]


## Puts the terminals of contact [param c] at the places of changeover
## contact [param pole] of the device: common, NC side, NO side.
static func _map_changeover(c: CircuitComponent, pole: String, common: String, nc: String, no: String, terminals: Dictionary) -> void:
	var keys: PackedStringArray = c.get_terminal_keys()
	terminals[pole + common] = keys[0]
	if c is ChangeoverContact:
		terminals[pole + nc] = keys[1]
		terminals[pole + no] = keys[2]
	else:
		var is_nc: bool = (c as Contact).contact_type == SwitchingElement.ContactType.NC
		terminals[pole + (nc if is_nc else no)] = keys[1]


static func _describe_overload(circuit: Circuit, relay: OverloadRelay, d: Dictionary) -> void:
	d["tripped"] = relay.tripped
	var terminals: Dictionary = _named_keys(relay)
	for c: CircuitComponent in circuit.get_components():
		if c is OverloadContact and c.designation == relay.designation:
			terminals.merge(_named_keys(c))
	d["terminals"] = terminals


## Terminal name -> terminal key of [param c].
static func _named_keys(c: CircuitComponent) -> Dictionary:
	var result: Dictionary = {}
	var names: PackedStringArray = c.get_terminal_names()
	var keys: PackedStringArray = c.get_terminal_keys()
	for k: int in names.size():
		result[names[k]] = keys[k]
	return result


## Contactor designation -> designation of the overload relay fitted under
## it: a three-pole overload relay whose heater inputs (1, 3, 5) are wired to
## the outputs (2, 4, 6) of the contactor's main contacts.
static func overloads_under_contactors(circuit: Circuit) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	var net: Dictionary[String, int] = nets(circuit)
	var outputs: Dictionary[int, String] = {}
	for c: CircuitComponent in circuit.get_components():
		if c is MainContacts and circuit.get_coil(c.designation) != null:
			var keys: PackedStringArray = c.get_terminal_keys()
			for k: int in range(1, keys.size(), 2):
				if net.has(keys[k]):
					outputs[net[keys[k]]] = c.designation
	for c: CircuitComponent in circuit.get_components():
		if c is OverloadRelay and (c as OverloadRelay).poles == 3:
			var keys: PackedStringArray = c.get_terminal_keys()
			for k: int in range(0, keys.size(), 2):
				var contactor: String = outputs.get(net.get(keys[k], -1), "")
				if not contactor.is_empty() and not result.has(contactor):
					result[contactor] = c.designation
					break
	return result


## Terminal key -> net number: terminals joined by wires or by page
## connectors share a number.
static func nets(circuit: Circuit) -> Dictionary[String, int]:
	var index: Dictionary[String, int] = {}
	for c: CircuitComponent in circuit.get_components():
		for key: String in c.get_terminal_keys():
			if not index.has(key):
				index[key] = index.size()
	var groups: UnionFind = UnionFind.new(index.size())
	var pairs: Array[PackedStringArray] = circuit.get_wires().duplicate()
	pairs.append_array(circuit.get_links())
	for pair: PackedStringArray in pairs:
		if index.has(pair[0]) and index.has(pair[1]):
			groups.union(index[pair[0]], index[pair[1]])
	var result: Dictionary[String, int] = {}
	for key: String in index:
		result[key] = groups.find(index[key])
	return result


## Net number (see [method nets]) -> [enum Conductor] of every net. Nets
## joined to the N supply or a - pole (of a supply point or a rectifier)
## are NEUTRAL, nets joined to PE alone PE; nets on the terminals of the
## power circuit (supplies L2 and L3, main contacts, overload relay heaters,
## 3~ motors, fuses, breakers and rotary cam switches of two or more poles)
## are POWER, all others CONTROL.
static func conductors(circuit: Circuit, net: Dictionary[String, int]) -> Dictionary[int, Conductor]:
	var neutral: Dictionary[int, bool] = {}
	var pe: Dictionary[int, bool] = {}
	var power: Dictionary[int, bool] = {}
	for c: CircuitComponent in circuit.get_components():
		var keys: PackedStringArray = c.get_terminal_keys()
		if c is PowerSupply:
			match (c as PowerSupply).conductor:
				PowerSupply.Conductor.N, PowerSupply.Conductor.DC_MINUS:
					neutral[net[keys[0]]] = true
				PowerSupply.Conductor.PE:
					pe[net[keys[0]]] = true
				PowerSupply.Conductor.L2, PowerSupply.Conductor.L3:
					power[net[keys[0]]] = true
			continue
		if c is Rectifier and keys.size() > 3:
			# Its - output is the pole of a DC source like a - supply point.
			neutral[net[keys[3]]] = true
		var count: int = 0
		if c is ThreePhaseMotor:
			count = (c as ThreePhaseMotor).winding_terminal_count()
		elif c is OverloadRelay or c is MainContacts or (c is PoleDevice and (c as PoleDevice).poles > 1) or (c is CamSwitch and (c as CamSwitch).poles > 1):
			count = keys.size()
		elif c is Vfd:
			for t: int in [Vfd.L1, Vfd.L1 + 1, Vfd.L1 + 2, Vfd.U, Vfd.U + 1, Vfd.U + 2]:
				power[net[keys[t]]] = true
			if net.has(keys[Vfd.PE]):
				pe[net[keys[Vfd.PE]]] = true
		for k: int in mini(count, keys.size()):
			power[net[keys[k]]] = true
	var result: Dictionary[int, Conductor] = {}
	for key: String in net:
		var n: int = net[key]
		if result.has(n):
			continue
		if neutral.has(n):
			result[n] = Conductor.NEUTRAL
		elif power.has(n):
			result[n] = Conductor.POWER
		elif pe.has(n):
			result[n] = Conductor.PE
		else:
			result[n] = Conductor.CONTROL
	return result


## True for a part that sits outside the switchboard and is wired to it
## through a terminal strip: buttons, switches, lamps, motors (not
## supplies, junctions, terminals, page connectors, nor the devices on the
## rails and their contacts).
static func is_outside(circuit: Circuit, c: CircuitComponent) -> bool:
	if c is PowerSupply or c is Junction or c is TerminalBlock or c is PageConnector:
		return false
	if kind_of(c) != Kind.NONE:
		return false
	if c is Contact or c is ChangeoverContact or c is MainContacts or c is OverloadContact:
		return device(circuit, c.designation) == null and circuit.get_overload_relay(c.designation) == null
	return true


## Designation of the part outside the switchboard that the strip terminal
## joining [param key] leads to: the part whose lead it sits on, else the
## first such part on its net; "" for none.
static func field_device(circuit: Circuit, key: String, net: Dictionary[String, int]) -> String:
	var owner: CircuitComponent = circuit.get_terminal_owner(key)
	if owner != null and is_outside(circuit, owner):
		return owner.designation
	var n: int = net.get(key, -1)
	for c: CircuitComponent in circuit.get_components():
		if is_outside(circuit, c):
			for k: String in c.get_terminal_keys():
				if net.get(k, -2) == n:
					return c.designation
	return ""


# --- Terminal strips -----------------------------------------------------------------

## Terminal strip name -> its terminals from left to right (the order set in
## the switchboard, [member SchematicDocument.strip_orders], else by label),
## each {"label", "kind": "L",
## "N" or "PE", "keys": PackedStringArray of the circuit terminals it joins}.
## A terminal labelled PE or on a PE wire is a PE terminal, one labelled N
## or on an N wire an N terminal (blue).
static func strips(doc: SchematicDocument) -> Dictionary:
	var found: Dictionary = {}
	for c: CircuitComponent in doc.circuit.get_components():
		if c is TerminalBlock:
			_add_terminal(found, (c as TerminalBlock).label, c.get_terminal_keys()[0])
		var placement: Placement = doc.get_placement(c.id)
		if placement == null:
			continue
		var keys: PackedStringArray = c.get_terminal_keys()
		for index: int in placement.strips:
			if index < keys.size():
				_add_terminal(found, placement.strips[index], keys[index])
	var result: Dictionary = {}
	if found.is_empty():
		return result
	var net: Dictionary[String, int] = nets(doc.circuit)
	var conductor: Dictionary[int, Conductor] = conductors(doc.circuit, net)
	var names: Array = found.keys()
	names.sort_custom(_natural_less)
	for strip: String in names:
		var labels: Array = (found[strip] as Dictionary).keys()
		labels.sort_custom(_natural_less)
		var order: PackedStringArray = doc.strip_orders.get(strip, PackedStringArray())
		if not order.is_empty():
			# The order set in the switchboard; terminals it does not list
			# keep their place after them.
			var listed: Array = []
			for label: String in order:
				if labels.has(label):
					listed.append(label)
			for label: String in labels:
				if not listed.has(label):
					listed.append(label)
			labels = listed
		var terminals: Array = []
		for label: String in labels:
			var kind: String = _terminal_kind(label)
			for key: String in found[strip][label]:
				match conductor.get(net.get(key, -1), Conductor.CONTROL):
					Conductor.PE:
						kind = "PE"
					Conductor.NEUTRAL:
						if kind != "PE":
							kind = "N"
			terminals.append({"label": label, "kind": kind, "keys": found[strip][label]})
		result[strip] = terminals
	return result


## Strip and terminal of a terminal label: "X2:4" -> ["X2", "4"], "4" -> ["X1", "4"].
static func split_label(label: String) -> PackedStringArray:
	var colon: int = label.find(":")
	if colon > 0:
		return PackedStringArray([label.left(colon), label.substr(colon + 1)])
	return PackedStringArray([DEFAULT_STRIP, label])


## A terminal label as written on the drawing: strip and number on one
## line, "X2:6" -> "X2-6", plain "6" -> "X1-6" ("" stays "").
static func terminal_text(label: String) -> String:
	if label.strip_edges().is_empty():
		return label
	var parts: PackedStringArray = split_label(label.strip_edges())
	return "%s-%s" % [parts[0], parts[1]]


## A terminal label as typed, as kept: "X2-6" or "X2:6" -> "X2:6", one on
## strip X1 ("X1-6", "X1:6") just its number "6"; other text as it is.
static func label_from_text(text: String) -> String:
	text = text.strip_edges()
	var dash: int = text.find("-")
	# A strip name starts with a capital letter ("X2-6"), the number follows the dash.
	if not text.contains(":") and dash > 0 and dash < text.length() - 1 and text.left(1) != text.left(1).to_lower():
		text = text.left(dash) + ":" + text.substr(dash + 1)
	var parts: PackedStringArray = split_label(text)
	return parts[1] if parts[0] == DEFAULT_STRIP and text.contains(":") else text


static func _add_terminal(found: Dictionary, label: String, key: String) -> void:
	label = label.strip_edges()
	if label.is_empty():
		return
	var parts: PackedStringArray = split_label(label)
	if parts[1].is_empty():
		return
	if not found.has(parts[0]):
		found[parts[0]] = {}
	var terminals: Dictionary = found[parts[0]]
	# Packed arrays are values: appended to and stored back.
	var keys: PackedStringArray = terminals.get(parts[1], PackedStringArray())
	keys.append(key)
	terminals[parts[1]] = keys


static func _terminal_kind(label: String) -> String:
	var upper: String = label.to_upper()
	if upper == "PE":
		return "PE"
	if upper == "N":
		return "N"
	return "L"


## Numbers in numeric order, then the other names alphabetically ("2" < "10" < "N").
static func _natural_less(a: String, b: String) -> bool:
	if a.is_valid_int() and b.is_valid_int():
		return int(a) < int(b)
	if a.is_valid_int() != b.is_valid_int():
		return a.is_valid_int()
	return a.naturalnocasecmp_to(b) < 0
