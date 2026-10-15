class_name DocumentSerializer
extends RefCounted
## Converts schematics and components to plain Dictionaries and back. Used for
## undo snapshots, for the simulation copy of an edited schematic and for
## building components from editor templates. Only design data is stored,
## never simulation state.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC
const INVALID_CELL := Vector2i(-2147483648, -2147483648)
const TYPES: PackedStringArray = ["supply", "junction", "push_button", "latching_switch", "contact", "changeover", "coil", "timer", "lamp", "motor", "fuse", "breaker", "overload_relay", "overload_contact", "main_contacts", "fuse3", "breaker3", "motor3"]
const MOTOR_KINDS: PackedStringArray = ["standard", "star_delta", "dahlander", "two_windings", "three_windings"]
const CONDUCTORS: PackedStringArray = ["L", "N", "L2", "L3"]


static func to_dict(doc: SchematicDocument) -> Dictionary:
	var components: Array[Dictionary] = []
	for c: CircuitComponent in doc.circuit.get_components():
		var d: Dictionary = component_to_dict(c)
		var p: Placement = doc.get_placement(c.id)
		d["cell"] = [p.cell.x, p.cell.y]
		d["rotation"] = p.rotation
		d["mirrored"] = p.mirrored
		components.append(d)
	var wires: Array[Dictionary] = []
	var circuit_wires: Array[PackedStringArray] = doc.circuit.get_wires()
	for i: int in circuit_wires.size():
		var corners: Array = []
		for corner: Vector2i in doc.get_route(i).corners:
			corners.append([corner.x, corner.y])
		wires.append({"a": circuit_wires[i][0], "b": circuit_wires[i][1], "corners": corners})
	return {"title": doc.title, "horizontal": doc.horizontal, "switching": "realistic" if doc.realistic_timing else "ideal", "components": components, "wires": wires}


## Builds a document, or returns null if the data is malformed (unknown
## component type, duplicate designation, wire to a missing terminal, ...).
## Never pushes errors, so it can check untrusted files.
static func from_dict(d: Dictionary) -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(str(d.get("title", "")))
	doc.horizontal = bool(d.get("horizontal", false))
	doc.realistic_timing = d.get("switching", "realistic") != "ideal"
	var components: Variant = d.get("components", [])
	var wires: Variant = d.get("wires", [])
	if not (components is Array and wires is Array):
		return null
	for cd: Variant in components:
		if not (cd is Dictionary):
			return null
		var c: CircuitComponent = component_from_dict(cd)
		var cell: Vector2i = _cell(cd.get("cell", null))
		if c == null or cell == INVALID_CELL or not _fits(doc.circuit, c):
			return null
		doc.add(c, cell, int(cd.get("rotation", 0)), bool(cd.get("mirrored", false)))
	for wd: Variant in wires:
		if not (wd is Dictionary):
			return null
		var a: String = str(wd.get("a", ""))
		var b: String = str(wd.get("b", ""))
		var raw_corners: Variant = wd.get("corners", [])
		if not doc.circuit.has_terminal(a) or not doc.circuit.has_terminal(b) or not (raw_corners is Array):
			return null
		var corners: Array[Vector2i] = []
		for corner: Variant in raw_corners:
			var cell: Vector2i = _cell(corner)
			if cell == INVALID_CELL:
				return null
			corners.append(cell)
		doc.connect_terminals(a, b, corners)
	return doc


static func component_to_dict(c: CircuitComponent) -> Dictionary:
	var d: Dictionary = {"designation": c.designation}
	if c is PowerSupply:
		d["type"] = "supply"
		d["conductor"] = CONDUCTORS[(c as PowerSupply).conductor]
	elif c is Junction:
		d["type"] = "junction"
	elif c is Fuse:
		d["type"] = "fuse"
		if (c as Fuse).holder:
			d["holder"] = true
	elif c is CircuitBreaker:
		d["type"] = "breaker"
	elif c is OverloadContact:
		d["type"] = "overload_contact"
		d["contact"] = "NO" if (c as OverloadContact).contact_type == NO else "NC"
	elif c is ChangeoverContact:
		var changeover: ChangeoverContact = c as ChangeoverContact
		d["type"] = "changeover"
		d["sequence"] = changeover.sequence
		d["delayed"] = changeover.delayed
	elif c is OverloadRelay:
		d["type"] = "overload_relay"
		d["trip_delay"] = (c as OverloadRelay).trip_delay
		d["poles"] = (c as OverloadRelay).poles
	elif c is MainContacts:
		d["type"] = "main_contacts"
	elif c is ThreePoleFuse:
		d["type"] = "fuse3"
		if (c as ThreePoleFuse).holder:
			d["holder"] = true
	elif c is MotorBreaker:
		d["type"] = "breaker3"
	elif c is ThreePhaseMotor:
		d["type"] = "motor3"
		d["motor_kind"] = MOTOR_KINDS[(c as ThreePhaseMotor).kind]
	elif c is SwitchingElement:
		var s: SwitchingElement = c as SwitchingElement
		d["contact"] = "NO" if s.contact_type == NO else "NC"
		d["sequence"] = s.sequence
		if c is PushButton:
			d["type"] = "push_button"
		elif c is LatchingSwitch:
			d["type"] = "latching_switch"
		else:
			d["type"] = "contact"
			d["delayed"] = (c as Contact).delayed
	elif c is TimerRelay:
		var t: TimerRelay = c as TimerRelay
		d["type"] = "timer"
		d["mode"] = "on_delay" if t.mode == TimerRelay.Mode.ON_DELAY else "off_delay"
		d["delay"] = t.delay
		d["pick_up"] = t.pick_up_time
		d["drop_out"] = t.drop_out_time
	elif c is Coil:
		d["type"] = "coil"
		d["kind"] = "relay" if (c as Coil).kind == Coil.Kind.RELAY else "contactor"
		d["pick_up"] = (c as Coil).pick_up_time
		d["drop_out"] = (c as Coil).drop_out_time
	elif c is Lamp:
		d["type"] = "lamp"
		if not (c as Lamp).purpose.is_empty():
			d["purpose"] = (c as Lamp).purpose
	elif c is Motor:
		d["type"] = "motor"
	if not c.custom_terminals.is_empty():
		d["terminals"] = Array(c.custom_terminals)
	return d


## Builds a component, or returns null for unknown or invalid data.
static func component_from_dict(d: Dictionary) -> CircuitComponent:
	var c: CircuitComponent = _component_from_dict(d)
	if c == null or not d.has("terminals"):
		return c
	var raw: Variant = d["terminals"]
	if not (raw is Array):
		return null
	var names: PackedStringArray = PackedStringArray()
	for n: Variant in raw:
		names.append(str(n))
	if c is ThreePhaseMotor and names.size() == c.default_terminal_names().size() - 1:
		# Saved before motors had a PE terminal (file version 4).
		names.append("PE")
	if not c.supports_custom_terminals() or names.size() != c.default_terminal_names().size() or not CircuitComponent.valid_terminal_names(names):
		return null
	if names != c.default_terminal_names():
		c.custom_terminals = names
	return c


static func _component_from_dict(d: Dictionary) -> CircuitComponent:
	var designation: String = str(d.get("designation", ""))
	var kind: String = str(d.get("type", ""))
	if designation.is_empty() or designation.contains(":") or not TYPES.has(kind):
		return null
	var contact: SwitchingElement.ContactType = NC if d.get("contact", "NO") == "NC" else NO
	var sequence: int = clampi(int(d.get("sequence", 1)), 0, 9)
	match kind:
		"supply":
			var conductor: int = maxi(CONDUCTORS.find(str(d.get("conductor", "L"))), 0)
			return PowerSupply.new(designation, conductor as PowerSupply.Conductor)
		"junction":
			return Junction.new(designation)
		"push_button":
			return PushButton.new(designation, contact, sequence)
		"latching_switch":
			return LatchingSwitch.new(designation, contact, sequence)
		"contact":
			return Contact.new(designation, contact, sequence, bool(d.get("delayed", false)))
		"changeover":
			return ChangeoverContact.new(designation, sequence, bool(d.get("delayed", false)))
		"fuse":
			var fuse: Fuse = Fuse.new(designation)
			fuse.holder = bool(d.get("holder", false))
			return fuse
		"breaker":
			return CircuitBreaker.new(designation)
		"overload_relay":
			return OverloadRelay.new(designation, _seconds_or(d, "trip_delay", OverloadRelay.DEFAULT_TRIP_DELAY, 3600.0), 3 if int(d.get("poles", 0)) == 3 else 0)
		"main_contacts":
			return MainContacts.new(designation)
		"fuse3":
			var fuse3: ThreePoleFuse = ThreePoleFuse.new(designation)
			fuse3.holder = bool(d.get("holder", false))
			return fuse3
		"breaker3":
			return MotorBreaker.new(designation)
		"motor3":
			var motor_kind: int = maxi(MOTOR_KINDS.find(str(d.get("motor_kind", "standard"))), 0)
			return ThreePhaseMotor.new(designation, motor_kind as ThreePhaseMotor.Kind)
		"overload_contact":
			return OverloadContact.new(designation, contact)
		"coil":
			var coil_kind: Coil.Kind = Coil.Kind.RELAY if d.get("kind", "contactor") == "relay" else Coil.Kind.CONTACTOR
			return Coil.new(designation, coil_kind, _seconds(d, "pick_up"), _seconds(d, "drop_out"))
		"timer":
			var mode: TimerRelay.Mode = TimerRelay.Mode.OFF_DELAY if d.get("mode", "on_delay") == "off_delay" else TimerRelay.Mode.ON_DELAY
			return TimerRelay.new(designation, mode, maxf(float(d.get("delay", 1.0)), 0.0), _seconds(d, "pick_up"), _seconds(d, "drop_out"))
		"lamp":
			var lamp: Lamp = Lamp.new(designation)
			lamp.purpose = str(d.get("purpose", "")).strip_edges()
			return lamp
		"motor":
			return Motor.new(designation)
	return null


## A switching time in seconds, or -1 (use the default) if missing or invalid.
static func _seconds(d: Dictionary, key: String) -> float:
	var value: Variant = d.get(key, null)
	if (value is float or value is int) and float(value) >= 0.0 and float(value) <= 10.0:
		return float(value)
	return -1.0


static func _seconds_or(d: Dictionary, key: String, fallback: float, maximum: float) -> float:
	var value: Variant = d.get(key, null)
	if (value is float or value is int) and float(value) >= 0.0 and float(value) <= maximum:
		return float(value)
	return fallback


static func _cell(value: Variant) -> Vector2i:
	if value is Array and value.size() == 2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float):
		return Vector2i(int(value[0]), int(value[1]))
	return INVALID_CELL


## True if [param c] can be added without clashing ids or terminals.
static func _fits(circuit: Circuit, c: CircuitComponent) -> bool:
	if circuit.has_component_id(c.id):
		return false
	for key: String in c.get_terminal_keys():
		if circuit.has_terminal(key):
			return false
	return true
