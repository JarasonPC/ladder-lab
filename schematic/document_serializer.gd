class_name DocumentSerializer
extends RefCounted
## Converts schematics and components to plain Dictionaries and back. Used for
## undo snapshots, for the simulation copy of an edited schematic and for
## building components from editor templates. Only design data is stored,
## never simulation state.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC
const INVALID_CELL := Vector2i(-2147483648, -2147483648)
const TYPES: PackedStringArray = ["supply", "junction", "push_button", "latching_switch", "contact", "changeover", "coil", "timer", "lamp", "motor", "fuse", "breaker", "overload_relay", "overload_contact", "main_contacts", "fuse3", "breaker3", "motor3", "terminal", "limit_switch", "rectifier", "connector"]
const MOTOR_KINDS: PackedStringArray = ["standard", "star_delta", "dahlander", "two_windings", "three_windings"]
const CONDUCTORS: PackedStringArray = ["L", "N", "L2", "L3", "+", "-", "PE"]


static func to_dict(doc: SchematicDocument) -> Dictionary:
	var components: Array[Dictionary] = []
	for c: CircuitComponent in doc.circuit.get_components():
		var d: Dictionary = component_to_dict(c)
		var p: Placement = doc.get_placement(c.id)
		d["cell"] = [p.cell.x, p.cell.y]
		d["rotation"] = p.rotation
		d["mirrored"] = p.mirrored
		if p.page != 0:
			d["page"] = p.page
		if not p.labels.is_empty():
			d["labels"] = p.labels_to_data()
		if not p.strips.is_empty():
			d["strips"] = p.strips_to_data()
		components.append(d)
	var wires: Array[Dictionary] = []
	var circuit_wires: Array[PackedStringArray] = doc.circuit.get_wires()
	for i: int in circuit_wires.size():
		var corners: Array = []
		for corner: Vector2i in doc.get_route(i).corners:
			corners.append([corner.x, corner.y])
		var wd: Dictionary = {"a": circuit_wires[i][0], "b": circuit_wires[i][1], "corners": corners}
		if not doc.get_route(i).number.is_empty():
			wd["number"] = doc.get_route(i).number
			var offsets: Array[Vector2] = doc.get_route(i).number_offsets
			if offsets[0] != Vector2.ZERO or offsets[1] != Vector2.ZERO:
				wd["number_offsets"] = [[offsets[0].x, offsets[0].y], [offsets[1].x, offsets[1].y]]
		wires.append(wd)
	var result: Dictionary = {"title": doc.title, "horizontal": doc.horizontal, "switching": "realistic" if doc.realistic_timing else "ideal", "pages": Array(doc.pages), "page": doc.page, "components": components, "wires": wires}
	if not doc.control_boxes.is_empty():
		var boxes: Array[Dictionary] = []
		for box: ControlBox in doc.control_boxes:
			boxes.append(box.to_data())
		result["control_boxes"] = boxes
	if not doc.title_block.is_empty():
		result["title_block"] = doc.title_block.to_data()
	return result


## Builds a document, or returns null if the data is malformed (unknown
## component type, duplicate designation, wire to a missing terminal, a page
## that does not exist, a wire between two pages, ...).
## Never pushes errors, so it can check untrusted files.
static func from_dict(d: Dictionary) -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(str(d.get("title", "")))
	doc.horizontal = bool(d.get("horizontal", false))
	doc.realistic_timing = d.get("switching", "realistic") != "ideal"
	var components: Variant = d.get("components", [])
	var wires: Variant = d.get("wires", [])
	# Files before version 11 have a single page.
	var raw_pages: Variant = d.get("pages", [""])
	if not (components is Array and wires is Array and raw_pages is Array) or (raw_pages as Array).is_empty():
		return null
	var titles: PackedStringArray = PackedStringArray()
	for title: Variant in raw_pages:
		if not (title is String):
			return null
		titles.append((title as String).strip_edges())
	doc.pages = titles
	for cd: Variant in components:
		if not (cd is Dictionary):
			return null
		var c: CircuitComponent = component_from_dict(cd)
		var cell: Vector2i = _cell(cd.get("cell", null))
		var on_page: Variant = cd.get("page", 0)
		if c == null or cell == INVALID_CELL or not _fits(doc.circuit, c) or not (on_page is int or on_page is float) or int(on_page) < 0 or int(on_page) >= titles.size():
			return null
		doc.page = int(on_page)
		doc.add(c, cell, int(cd.get("rotation", 0)), bool(cd.get("mirrored", false)))
		doc.get_placement(c.id).labels_from_data(cd.get("labels", {}))
		doc.get_placement(c.id).strips_from_data(cd.get("strips", {}))
	for wd: Variant in wires:
		if not (wd is Dictionary):
			return null
		var a: String = str(wd.get("a", ""))
		var b: String = str(wd.get("b", ""))
		var raw_corners: Variant = wd.get("corners", [])
		if not doc.circuit.has_terminal(a) or not doc.circuit.has_terminal(b) or not (raw_corners is Array):
			return null
		if doc.page_of(doc.circuit.get_terminal_owner(a).id) != doc.page_of(doc.circuit.get_terminal_owner(b).id):
			return null
		var corners: Array[Vector2i] = []
		for corner: Variant in raw_corners:
			var cell: Vector2i = _cell(corner)
			if cell == INVALID_CELL:
				return null
			corners.append(cell)
		doc.connect_terminals(a, b, corners)
		var route: WireRoute = doc.get_route(doc.get_wire_count() - 1)
		route.number = str(wd.get("number", ""))
		var raw_offsets: Variant = wd.get("number_offsets", [])
		if raw_offsets is Array and (raw_offsets as Array).size() == 2:
			for end: int in 2:
				var o: Variant = raw_offsets[end]
				if o is Array and (o as Array).size() == 2 and (o[0] is float or o[0] is int) and (o[1] is float or o[1] is int):
					route.number_offsets[end] = Vector2(float(o[0]), float(o[1]))
	var shown: Variant = d.get("page", 0)
	doc.page = int(shown) if (shown is int or shown is float) else 0
	# Control boxes are only design data around the circuit: malformed ones are left out.
	var raw_boxes: Variant = d.get("control_boxes", [])
	if raw_boxes is Array:
		for bd: Variant in raw_boxes:
			var box: ControlBox = ControlBox.from_data(bd)
			if box != null:
				doc.control_boxes.append(box)
	doc.title_block = TitleBlock.from_data(d.get("title_block", {}))
	return doc


## Pole count "poles" (1-4) of a device, [param fallback] when missing or invalid.
static func _poles(d: Dictionary, lowest: int, fallback: int) -> int:
	var raw: Variant = d.get("poles", fallback)
	var n: int = int(raw) if (raw is int or raw is float) else fallback
	return n if n >= lowest and n <= 4 else fallback


static func component_to_dict(c: CircuitComponent) -> Dictionary:
	var d: Dictionary = {"designation": c.designation}
	if c is PowerSupply:
		d["type"] = "supply"
		d["conductor"] = CONDUCTORS[(c as PowerSupply).conductor]
	elif c is Junction:
		d["type"] = "junction"
	elif c is TerminalBlock:
		d["type"] = "terminal"
		d["label"] = (c as TerminalBlock).label
	elif c is PageConnector:
		d["type"] = "connector"
		d["label"] = (c as PageConnector).label
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
		d["poles"] = (c as MainContacts).poles
	elif c is ThreePoleFuse:
		d["type"] = "fuse"
		d["poles"] = (c as ThreePoleFuse).poles
		if (c as ThreePoleFuse).holder:
			d["holder"] = true
	elif c is MotorBreaker:
		d["type"] = "breaker"
		d["poles"] = (c as MotorBreaker).poles
	elif c is ThreePhaseMotor:
		d["type"] = "motor3"
		var motor: ThreePhaseMotor = c as ThreePhaseMotor
		d["motor_kind"] = MOTOR_KINDS[motor.kind]
		d["terminal_box"] = motor.terminal_box
		if motor.kind == ThreePhaseMotor.Kind.STANDARD:
			d["connection"] = "delta" if motor.delta_bridges else "star"
		d["coast_time"] = motor.coast_time
		d["brake_time"] = motor.brake_time
	elif c is SwitchingElement:
		var s: SwitchingElement = c as SwitchingElement
		d["contact"] = "NO" if s.contact_type == NO else "NC"
		d["sequence"] = s.sequence
		if c is PushButton:
			d["type"] = "push_button"
		elif c is LimitSwitch:
			d["type"] = "limit_switch"
		elif c is LatchingSwitch:
			d["type"] = "latching_switch"
		else:
			d["type"] = "contact"
			d["delayed"] = (c as Contact).delayed
	elif c is TimerRelay:
		var t: TimerRelay = c as TimerRelay
		d["type"] = "timer"
		d["mode"] = TimerRelay.MODE_NAMES[t.mode]
		if t.control_input:
			d["control_input"] = true
		d["delay"] = t.delay
		if TimerRelay.uses_two_times(t.mode) or not is_equal_approx(t.delay2, 1.0):
			d["delay2"] = t.delay2
		d["pick_up"] = t.pick_up_time
		d["drop_out"] = t.drop_out_time
	elif c is Coil:
		d["type"] = "coil"
		d["kind"] = "relay" if (c as Coil).kind == Coil.Kind.RELAY else "contactor"
		d["pick_up"] = (c as Coil).pick_up_time
		d["drop_out"] = (c as Coil).drop_out_time
	elif c is Rectifier:
		d["type"] = "rectifier"
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
		"terminal":
			var block: TerminalBlock = TerminalBlock.new(designation)
			block.label = str(d.get("label", "")).strip_edges()
			return block
		"connector":
			return PageConnector.new(designation, str(d.get("label", "")).strip_edges())
		"push_button":
			return PushButton.new(designation, contact, sequence)
		"latching_switch":
			return LatchingSwitch.new(designation, contact, sequence)
		"limit_switch":
			return LimitSwitch.new(designation, contact, sequence)
		"contact":
			return Contact.new(designation, contact, sequence, bool(d.get("delayed", false)))
		"changeover":
			return ChangeoverContact.new(designation, sequence, bool(d.get("delayed", false)))
		"fuse":
			if _poles(d, 1, 1) > 1:
				var multi_fuse: ThreePoleFuse = ThreePoleFuse.new(designation)
				multi_fuse.poles = _poles(d, 1, 1)
				multi_fuse.holder = bool(d.get("holder", false))
				return multi_fuse
			var fuse: Fuse = Fuse.new(designation)
			fuse.holder = bool(d.get("holder", false))
			return fuse
		"breaker":
			if _poles(d, 1, 1) > 1:
				var multi_breaker: MotorBreaker = MotorBreaker.new(designation)
				multi_breaker.poles = _poles(d, 1, 1)
				return multi_breaker
			return CircuitBreaker.new(designation)
		"overload_relay":
			return OverloadRelay.new(designation, _seconds_or(d, "trip_delay", OverloadRelay.DEFAULT_TRIP_DELAY, 3600.0), 3 if int(d.get("poles", 0)) == 3 else 0)
		"main_contacts":
			var contacts: MainContacts = MainContacts.new(designation)
			contacts.poles = _poles(d, 1, 3)
			return contacts
		"fuse3":
			# Files before version 9.
			var fuse3: ThreePoleFuse = ThreePoleFuse.new(designation)
			fuse3.holder = bool(d.get("holder", false))
			return fuse3
		"breaker3":
			# Files before version 9.
			var breaker3: MotorBreaker = MotorBreaker.new(designation)
			return breaker3
		"motor3":
			var motor_kind: int = maxi(MOTOR_KINDS.find(str(d.get("motor_kind", "standard"))), 0)
			var motor3: ThreePhaseMotor = ThreePhaseMotor.new(designation, motor_kind as ThreePhaseMotor.Kind)
			motor3.terminal_box = bool(d.get("terminal_box", false))
			motor3.delta_bridges = d.get("connection", "star") == "delta"
			motor3.coast_time = _seconds_or(d, "coast_time", ThreePhaseMotor.DEFAULT_COAST_TIME, 3600.0)
			motor3.brake_time = _seconds_or(d, "brake_time", ThreePhaseMotor.DEFAULT_BRAKE_TIME, 3600.0)
			return motor3
		"overload_contact":
			return OverloadContact.new(designation, contact)
		"coil":
			var coil_kind: Coil.Kind = Coil.Kind.RELAY if d.get("kind", "contactor") == "relay" else Coil.Kind.CONTACTOR
			return Coil.new(designation, coil_kind, _seconds(d, "pick_up"), _seconds(d, "drop_out"))
		"timer":
			var mode: int = maxi(TimerRelay.MODE_NAMES.find(str(d.get("mode", "on_delay"))), 0)
			var timer: TimerRelay = TimerRelay.new(designation, mode as TimerRelay.Mode, maxf(float(d.get("delay", 1.0)), 0.0), _seconds(d, "pick_up"), _seconds(d, "drop_out"))
			timer.control_input = bool(d.get("control_input", false))
			timer.delay2 = _seconds_or(d, "delay2", 1.0, 360000.0)
			return timer
		"rectifier":
			return Rectifier.new(designation)
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
