class_name DocumentSerializer
extends RefCounted
## Converts schematics and components to plain Dictionaries and back. Used for
## undo snapshots, for the simulation copy of an edited schematic and for
## building components from editor templates. Only design data is stored,
## never simulation state.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC
const INVALID_CELL := Vector2i(-2147483648, -2147483648)
const TYPES: PackedStringArray = ["supply", "junction", "push_button", "latching_switch", "contact", "changeover", "coil", "timer", "lamp", "motor", "fuse", "breaker", "overload_relay", "overload_contact", "main_contacts", "fuse3", "breaker3", "motor3", "terminal", "limit_switch", "rectifier", "connector", "plc", "temp_sensor", "vfd", "cam_switch", "transmitter", "proximity", "network_switch", "pot", "light_switch", "luminaire", "socket", "rcd", "afdd", "appliance"]
const MOTOR_KINDS: PackedStringArray = ["standard", "star_delta", "dahlander", "two_windings", "three_windings"]
const CONDUCTORS: PackedStringArray = ["L", "N", "L2", "L3", "+", "-", "PE"]
## Limits of rated currents and settings (amperes) and of the starting
## current ratio of motors.
const MIN_AMPERES: float = 0.1
const MAX_AMPERES: float = 10000.0
const MIN_START_RATIO: float = 2.0
const MAX_START_RATIO: float = 12.0
## Most load a 3~ motor can be given, % of its rated torque.
const MAX_LOAD: float = 200.0
## Limits of the times t1 and t2 of time relays (seconds).
const SHORTEST_DELAY: float = 0.1
const LONGEST_DELAY: float = 3600.0
## Least span of a temperature sensor's range (°C).
const RANGE_STEP: float = 1.0
## Narrowest range of a transmitter.
const TRANSMITTER_RANGE_STEP: float = 0.1
## Highest mounting height of a part of a house installation (m).
const MAX_HEIGHT: float = 6.0


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
	match doc.environment:
		SchematicDocument.Kind.PROTOTYPE:
			result["environment"] = "prototype"
		SchematicDocument.Kind.RESIDENTIAL:
			result["environment"] = "installation"
			result["single_line"] = doc.single_line.to_data()
	if not doc.floor_plan.is_empty():
		result["floor_plan"] = doc.floor_plan.to_data()
	if not doc.control_boxes.is_empty():
		var boxes: Array[Dictionary] = []
		for box: ControlBox in doc.control_boxes:
			boxes.append(box.to_data())
		result["control_boxes"] = boxes
	if not doc.title_block.is_empty():
		result["title_block"] = doc.title_block.to_data()
	if not doc.switchboards.is_empty():
		var boards: Array[Dictionary] = []
		for board: Switchboard in doc.switchboards:
			boards.append(board.to_data())
		result["switchboards"] = boards
	if not doc.groups.is_empty():
		var list: Array[Dictionary] = []
		for group: WorkspaceGroup in doc.groups:
			list.append(group.to_data())
		result["groups"] = list
	var field: Dictionary = {}
	for designation: String in Workspace.field_devices(doc.circuit):
		if doc.field_positions.has(designation):
			var at: Vector2 = doc.field_positions[designation]
			field[designation] = [at.x, at.y]
	if not field.is_empty():
		result["field"] = field
	var keys: Dictionary = {}
	for designation: String in doc.key_bindings:
		if doc.can_have_key(designation):
			keys[designation] = doc.key_bindings[designation]
	if not keys.is_empty():
		result["keys"] = keys
	if not doc.cable_names.is_empty():
		var names: Dictionary = {}
		for key: String in doc.cable_names:
			names[key] = doc.cable_names[key]
		result["cables"] = names
	if not doc.cable_settings.is_empty():
		var settings: Dictionary = {}
		for key: String in doc.cable_settings:
			settings[key] = doc.cable_settings[key].duplicate()
		result["cable_settings"] = settings
	if not doc.strip_orders.is_empty():
		var orders: Dictionary = {}
		for strip: String in doc.strip_orders:
			orders[strip] = Array(doc.strip_orders[strip])
		result["strip_order"] = orders
	return result


## Builds a document, or returns null if the data is malformed (unknown
## component type, duplicate designation, wire to a missing terminal, a page
## that does not exist, a wire between two pages, ...).
## Never pushes errors, so it can check untrusted files.
static func from_dict(d: Dictionary) -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(str(d.get("title", "")))
	doc.horizontal = _bool(d, "horizontal", false)
	doc.realistic_timing = str(d.get("switching", "realistic")) != "ideal"
	# Saved before version 41, a residential prototype was "residential".
	match str(d.get("environment", "")):
		"prototype", "residential":
			doc.environment = SchematicDocument.Kind.PROTOTYPE
		"installation":
			doc.environment = SchematicDocument.Kind.RESIDENTIAL
	var components: Variant = d.get("components", [])
	var wires: Variant = d.get("wires", [])
	if not (components is Array and wires is Array):
		return null
	# Files before version 11 have a single page; damaged titles are left empty.
	var raw_pages: Variant = d.get("pages", [""])
	var titles: PackedStringArray = PackedStringArray()
	if raw_pages is Array:
		for title: Variant in raw_pages:
			titles.append((title as String).strip_edges() if title is String else "")
	if titles.is_empty():
		titles.append("")
	doc.pages = titles
	for cd: Variant in components:
		if not (cd is Dictionary):
			return null
		var c: CircuitComponent = component_from_dict(cd)
		var cell: Vector2i = _cell(cd.get("cell", null))
		var on_page: int = _int(cd, "page", 0)
		if c == null or cell == INVALID_CELL or not _fits(doc.circuit, c) or on_page < 0 or on_page >= titles.size():
			return null
		doc.page = on_page
		doc.add(c, cell, _int(cd, "rotation", 0), _bool(cd, "mirrored", false))
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
		var number: Variant = wd.get("number", "")
		route.number = str(number).strip_edges() if (number is String or number is int or number is float) else ""
		var raw_offsets: Variant = wd.get("number_offsets", [])
		if raw_offsets is Array and (raw_offsets as Array).size() == 2:
			for end: int in 2:
				var o: Variant = raw_offsets[end]
				if o is Array and (o as Array).size() == 2 and (o[0] is float or o[0] is int) and (o[1] is float or o[1] is int):
					route.number_offsets[end] = Vector2(float(o[0]), float(o[1]))
	doc.page = _int(d, "page", 0)
	# Control boxes are only design data around the circuit: malformed ones are left out.
	var raw_boxes: Variant = d.get("control_boxes", [])
	if raw_boxes is Array:
		for bd: Variant in raw_boxes:
			var box: ControlBox = ControlBox.from_data(bd)
			if box != null:
				doc.control_boxes.append(box)
	doc.title_block = TitleBlock.from_data(d.get("title_block", {}))
	doc.floor_plan = FloorPlan.from_data(d.get("floor_plan", {}))
	doc.floor_plan.prune(doc.circuit)
	if doc.environment == SchematicDocument.Kind.RESIDENTIAL:
		doc.single_line = SingleLine.from_data(d.get("single_line", {}))
		doc.single_line.wire(doc)
	# So are the switchboards: malformed ones, rails and items are left out.
	var raw_boards: Variant = d.get("switchboards", [])
	if raw_boards is Array:
		for sd: Variant in raw_boards:
			var board: Switchboard = Switchboard.from_data(sd)
			if board != null:
				doc.switchboards.append(board)
	# Files before version 24 have one switchboard, its rails as "cabinet".
	var raw_rails: Variant = d.get("cabinet", [])
	if raw_rails is Array and not (raw_rails as Array).is_empty() and doc.switchboards.is_empty():
		var old_board: Switchboard = Switchboard.new()
		for rd: Variant in raw_rails:
			var rail: CabinetRail = CabinetRail.from_data(rd)
			if rail != null:
				old_board.rails.append(rail)
		doc.switchboards.append(old_board)
	var raw_groups: Variant = d.get("groups", [])
	if raw_groups is Array:
		for gd: Variant in raw_groups:
			var group: WorkspaceGroup = WorkspaceGroup.from_data(gd)
			if group != null:
				doc.groups.append(group)
	var raw_field: Variant = d.get("field", {})
	if raw_field is Dictionary:
		for designation: Variant in raw_field:
			if designation is String and Workspace.field_component(doc.circuit, designation) != null:
				doc.field_positions[designation] = Workspace.position_from(raw_field[designation])
	var raw_keys: Variant = d.get("keys", {})
	if raw_keys is Dictionary:
		for designation: Variant in raw_keys:
			if designation is String and raw_keys[designation] is String:
				doc.set_key(designation, raw_keys[designation])
	var raw_cables: Variant = d.get("cables", {})
	if raw_cables is Dictionary:
		for key: Variant in raw_cables:
			var cable_name: String = WorkspaceCables.cable_name(raw_cables[key])
			if key is String and (key as String).contains("|") and not cable_name.is_empty():
				doc.cable_names[key] = cable_name
	var raw_settings: Variant = d.get("cable_settings", {})
	if raw_settings is Dictionary:
		for key: Variant in raw_settings:
			var given: Variant = raw_settings[key]
			if not (key is String and (key as String).contains("|") and given is Dictionary):
				continue
			var type: Variant = given.get("type", "")
			var settings: Dictionary = WorkspaceCables.settings(type if type is String else "", _number_or(given, "section", 0.0), _number_or(given, "length", 0.0))
			if not settings.is_empty():
				doc.cable_settings[key] = settings
	# Places of older files (and damaged names) get names and spots; a name
	# used twice is given anew.
	var seen: Dictionary[String, bool] = {}
	for place: RefCounted in doc.places():
		if seen.has(place.get("name")):
			place.set("name", "")
		elif not str(place.get("name")).is_empty():
			seen[place.get("name")] = true
	doc.name_places()
	var raw_orders: Variant = d.get("strip_order", {})
	if raw_orders is Dictionary:
		for strip: Variant in raw_orders:
			if strip is String and raw_orders[strip] is Array:
				var order: PackedStringArray = PackedStringArray()
				for label: Variant in raw_orders[strip]:
					if label is String:
						order.append(label)
				doc.strip_orders[strip] = order
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
		if (c as PowerSupply).conductor == PowerSupply.Conductor.DC_PLUS:
			d["voltage"] = (c as PowerSupply).voltage
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
		d["rated_current"] = (c as Fuse).rated_current
	elif c is CircuitBreaker:
		d["type"] = "breaker"
		d["rated_current"] = (c as CircuitBreaker).rated_current
		d["characteristic"] = TripCurve.LETTERS[(c as CircuitBreaker).characteristic]
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
		d["setting"] = (c as OverloadRelay).setting
	elif c is MainContacts:
		d["type"] = "main_contacts"
		d["poles"] = (c as MainContacts).poles
	elif c is ThreePoleFuse:
		d["type"] = "fuse"
		d["poles"] = (c as ThreePoleFuse).poles
		if (c as ThreePoleFuse).holder:
			d["holder"] = true
		d["rated_current"] = (c as ThreePoleFuse).rated_current
	elif c is LightSwitch:
		d["type"] = "light_switch"
		d["circuit"] = (c as LightSwitch).circuit
		d["height"] = (c as LightSwitch).height
	elif c is SocketOutlet:
		d["type"] = "socket"
		d["gangs"] = (c as SocketOutlet).gangs
		d["height"] = (c as SocketOutlet).height
		if (c as SocketOutlet).plugged >= 0:
			d["plugged"] = Appliance.KIND_NAMES[(c as SocketOutlet).plugged]
			d["plugged_power"] = (c as SocketOutlet).plugged_power
	elif c is Appliance:
		var appliance: Appliance = c as Appliance
		d["type"] = "appliance"
		d["kind"] = Appliance.KIND_NAMES[appliance.kind]
		d["power"] = appliance.power
		d["two_phases"] = appliance.two_phases
		d["height"] = appliance.height
	elif c is CamSwitch:
		d["type"] = "cam_switch"
		d["poles"] = (c as CamSwitch).poles
		d["positions"] = CamSwitch.POSITION_NAMES[(c as CamSwitch).positions]
	elif c is ResidualCurrentDevice:
		var rcd: ResidualCurrentDevice = c as ResidualCurrentDevice
		d["type"] = "rcd"
		d["poles"] = rcd.poles
		d["residual"] = rcd.residual_rating
		d["rcd_type"] = rcd.type
		if rcd.selective:
			d["selective"] = true
		d["rated_current"] = rcd.rated_current
		if rcd.overcurrent:
			d["overcurrent"] = true
			d["characteristic"] = TripCurve.LETTERS[rcd.characteristic]
	elif c is ArcFaultDevice:
		d["type"] = "afdd"
		d["rated_current"] = (c as ArcFaultDevice).rated_current
		d["characteristic"] = TripCurve.LETTERS[(c as ArcFaultDevice).characteristic]
	elif c is MotorBreaker:
		d["type"] = "breaker"
		d["poles"] = (c as MotorBreaker).poles
		d["rated_current"] = (c as MotorBreaker).rated_current
		d["characteristic"] = TripCurve.LETTERS[(c as MotorBreaker).characteristic]
	elif c is ThreePhaseMotor:
		d["type"] = "motor3"
		var motor: ThreePhaseMotor = c as ThreePhaseMotor
		d["motor_kind"] = MOTOR_KINDS[motor.kind]
		d["terminal_box"] = motor.terminal_box
		if motor.kind == ThreePhaseMotor.Kind.STANDARD:
			d["connection"] = "delta" if motor.delta_bridges else "star"
		d["coast_time"] = motor.coast_time
		d["brake_time"] = motor.brake_time
		d["rated_current"] = motor.rated_current
		d["start_ratio"] = motor.start_ratio
		d["run_up_time"] = motor.run_up_time
		d["rated_power"] = motor.rated_power
		d["rated_speed"] = motor.rated_speed
		d["power_factor"] = motor.power_factor
		d["load"] = motor.load_level * 100.0
		if motor.show_plate:
			d["show_plate"] = true
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
			if (c as LatchingSwitch).three_positions:
				d["positions"] = "I-0-II"
				d["operated_in"] = "II" if (c as LatchingSwitch).side == 2 else "I"
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
	elif c is Vfd:
		var drive: Vfd = c as Vfd
		d["type"] = "vfd"
		d["control"] = Vfd.CONTROL_NAMES[drive.control]
		d["setpoint"] = Vfd.SETPOINT_NAMES[drive.setpoint]
		d["max_frequency"] = drive.max_frequency
		d["ramp_up"] = drive.ramp_up
		d["ramp_down"] = drive.ramp_down
		d["fixed_frequency"] = drive.fixed_frequency
		d["keypad_frequency"] = drive.keypad_frequency
	elif c is TemperatureSensor:
		var sensor: TemperatureSensor = c as TemperatureSensor
		d["type"] = "temp_sensor"
		d["range_min"] = sensor.range_min
		d["range_max"] = sensor.range_max
		d["temperature"] = sensor.temperature
	elif c is Transmitter:
		var transmitter: Transmitter = c as Transmitter
		d["type"] = "transmitter"
		d["quantity"] = Transmitter.QUANTITY_NAMES[transmitter.quantity]
		d["range_min"] = transmitter.range_min
		d["range_max"] = transmitter.range_max
		d["value"] = transmitter.value
	elif c is Potentiometer:
		d["type"] = "pot"
		d["turns"] = (c as Potentiometer).turns
		# Saved in per cent of the track.
		d["setting"] = snappedf((c as Potentiometer).setting * 100.0, 0.001)
	elif c is ProximitySensor:
		var proximity: ProximitySensor = c as ProximitySensor
		d["type"] = "proximity"
		d["sensing"] = ProximitySensor.SENSING_NAMES[proximity.sensing]
		d["output"] = ProximitySensor.OUTPUT_NAMES[proximity.output]
		d["function"] = ProximitySensor.FUNCTION_NAMES[proximity.function]
	elif c is Plc:
		d["type"] = "plc"
		if c is CompactPlc:
			d["family"] = "compact"
			d["cpu"] = CompactPlc.CPU_NAMES[(c as CompactPlc).cpu]
		d["program"] = (c as Plc).program.to_data()
		d["ip"] = (c as Plc).ip_address
		if not (c as Plc).modules.is_empty():
			var modules: Array[String] = []
			for module: Plc.Module in (c as Plc).modules:
				modules.append(Plc.MODULE_NAMES[module])
			d["modules"] = modules
	elif c is NetworkSwitch:
		d["type"] = "network_switch"
	elif c is Luminaire:
		d["type"] = "luminaire"
		d["power"] = (c as Luminaire).power
		d["height"] = (c as Luminaire).height
		if (c as Luminaire).wall:
			d["wall"] = true
	elif c is Lamp:
		d["type"] = "lamp"
		if not (c as Lamp).purpose.is_empty():
			d["purpose"] = (c as Lamp).purpose
	elif c is Motor:
		d["type"] = "motor"
	if c is Load and not (c as Load).rating.is_empty():
		d["rating"] = (c as Load).rating
	if not c.custom_terminals.is_empty():
		d["terminals"] = Array(c.custom_terminals)
	return d


## Expansion modules of a PLC from saved data: unknown ones are left out,
## and those beyond what the PLC takes ([method Plc.modules_fit], with its own
## analog inputs counted for [param version]; the signal modules of compact
## CPU [param cpu], see [method CompactPlc.modules_fit_cpu]).
static func plc_modules(raw: Variant, cpu: int = -1, version: String = "") -> Array[Plc.Module]:
	var modules: Array[Plc.Module] = []
	if not (raw is Array):
		return modules
	for name: Variant in raw:
		var kind: int = Plc.MODULE_NAMES.find(str(name))
		if kind < 0:
			continue
		modules.append(kind as Plc.Module)
		var fits: bool = Plc.modules_fit(modules, version) if cpu < 0 else CompactPlc.modules_fit_cpu(modules, cpu as CompactPlc.Cpu)
		if not fits:
			modules.pop_back()
	return modules


## Builds a component, or returns null for unknown or invalid data.
static func component_from_dict(d: Dictionary) -> CircuitComponent:
	var c: CircuitComponent = _component_from_dict(d)
	if c is Load and d.has("rating") and VoltageRating.is_known(str(d["rating"])) and not (c is CompactPlc):
		(c as Load).rating = str(d["rating"])
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
	if c is Plc and names.size() == c.default_terminal_names().size() - 1:
		# Saved before PLCs had an Ethernet port (file version 34 and older).
		for port: String in [Plc.PORT_NAME, "X1P1", "ETH1"]:
			if not names.has(port):
				names.append(port)
				break
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
	var contact: SwitchingElement.ContactType = NC if str(d.get("contact", "NO")) == "NC" else NO
	var sequence: int = clampi(_int(d, "sequence", 1), 0, 9)
	match kind:
		"supply":
			var conductor: int = maxi(CONDUCTORS.find(str(d.get("conductor", "L"))), 0)
			var supply: PowerSupply = PowerSupply.new(designation, conductor as PowerSupply.Conductor)
			var volts: float = float(d.get("voltage", PowerSupply.DC_VOLTAGES[0])) if d.get("voltage") is float or d.get("voltage") is int else PowerSupply.DC_VOLTAGES[0]
			if PowerSupply.DC_VOLTAGES.has(volts):
				supply.voltage = volts
			return supply
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
			var switch: LatchingSwitch = LatchingSwitch.new(designation, contact, sequence)
			switch.three_positions = str(d.get("positions", "0-I")) == "I-0-II"
			switch.side = 2 if switch.three_positions and str(d.get("operated_in", "I")) == "II" else 1
			return switch
		"limit_switch":
			return LimitSwitch.new(designation, contact, sequence)
		"contact":
			return Contact.new(designation, contact, sequence, _bool(d, "delayed", false))
		"changeover":
			return ChangeoverContact.new(designation, sequence, _bool(d, "delayed", false))
		"fuse":
			if _poles(d, 1, 1) > 1:
				var multi_fuse: ThreePoleFuse = ThreePoleFuse.new(designation)
				multi_fuse.poles = _poles(d, 1, 1)
				multi_fuse.holder = _bool(d, "holder", false)
				multi_fuse.rated_current = _amperes(d, "rated_current", ThreePoleFuse.DEFAULT_RATED_CURRENT)
				return multi_fuse
			var fuse: Fuse = Fuse.new(designation)
			fuse.holder = _bool(d, "holder", false)
			fuse.rated_current = _amperes(d, "rated_current", Fuse.DEFAULT_RATED_CURRENT)
			return fuse
		"breaker":
			var characteristic: int = maxi(TripCurve.LETTERS.find(str(d.get("characteristic", "C"))), 0)
			if _poles(d, 1, 1) > 1:
				var multi_breaker: MotorBreaker = MotorBreaker.new(designation)
				multi_breaker.poles = _poles(d, 1, 1)
				multi_breaker.rated_current = _amperes(d, "rated_current", MotorBreaker.DEFAULT_RATED_CURRENT)
				multi_breaker.characteristic = characteristic as CircuitBreaker.Characteristic
				return multi_breaker
			var breaker: CircuitBreaker = CircuitBreaker.new(designation)
			breaker.rated_current = _amperes(d, "rated_current", CircuitBreaker.DEFAULT_RATED_CURRENT)
			breaker.characteristic = characteristic as CircuitBreaker.Characteristic
			return breaker
		"overload_relay":
			var relay: OverloadRelay = OverloadRelay.new(designation, _seconds_or(d, "trip_delay", OverloadRelay.DEFAULT_TRIP_DELAY, 3600.0), 3 if _int(d, "poles", 0) == 3 else 0)
			relay.setting = _amperes(d, "setting", OverloadRelay.DEFAULT_SETTING)
			return relay
		"cam_switch":
			var positions: int = maxi(CamSwitch.POSITION_NAMES.find(str(d.get("positions", ""))), 0)
			return CamSwitch.new(designation, positions as CamSwitch.Positions, _poles(d, 1, 3))
		"main_contacts":
			var contacts: MainContacts = MainContacts.new(designation)
			contacts.poles = _poles(d, 1, 3)
			return contacts
		"fuse3":
			# Files before version 9.
			var fuse3: ThreePoleFuse = ThreePoleFuse.new(designation)
			fuse3.holder = _bool(d, "holder", false)
			return fuse3
		"breaker3":
			# Files before version 9.
			var breaker3: MotorBreaker = MotorBreaker.new(designation)
			return breaker3
		"motor3":
			var motor_kind: int = maxi(MOTOR_KINDS.find(str(d.get("motor_kind", "standard"))), 0)
			var motor3: ThreePhaseMotor = ThreePhaseMotor.new(designation, motor_kind as ThreePhaseMotor.Kind)
			motor3.terminal_box = _bool(d, "terminal_box", false)
			motor3.delta_bridges = str(d.get("connection", "star")) == "delta"
			motor3.coast_time = _seconds_or(d, "coast_time", ThreePhaseMotor.DEFAULT_COAST_TIME, 3600.0)
			motor3.brake_time = _seconds_or(d, "brake_time", ThreePhaseMotor.DEFAULT_BRAKE_TIME, 3600.0)
			motor3.rated_current = _amperes(d, "rated_current", ThreePhaseMotor.DEFAULT_RATED_CURRENT)
			motor3.start_ratio = clampf(_number_or(d, "start_ratio", ThreePhaseMotor.DEFAULT_START_RATIO), MIN_START_RATIO, MAX_START_RATIO)
			motor3.run_up_time = _seconds_or(d, "run_up_time", ThreePhaseMotor.DEFAULT_RUN_UP_TIME, 600.0)
			motor3.rated_power = clampf(_number_or(d, "rated_power", ThreePhaseMotor.DEFAULT_RATED_POWER), 0.01, 10000.0)
			motor3.rated_speed = clampf(_number_or(d, "rated_speed", ThreePhaseMotor.DEFAULT_RATED_SPEED), 100.0, 2990.0)
			motor3.power_factor = clampf(_number_or(d, "power_factor", MotorModel.DEFAULT_POWER_FACTOR), 0.3, 0.97)
			motor3.show_plate = _bool(d, "show_plate", false)
			motor3.load_level = clampf(_number_or(d, "load", 100.0), 0.0, MAX_LOAD) / 100.0
			return motor3
		"overload_contact":
			return OverloadContact.new(designation, contact)
		"coil":
			var coil_kind: Coil.Kind = Coil.Kind.RELAY if str(d.get("kind", "contactor")) == "relay" else Coil.Kind.CONTACTOR
			return Coil.new(designation, coil_kind, _seconds(d, "pick_up"), _seconds(d, "drop_out"))
		"timer":
			var mode: int = maxi(TimerRelay.MODE_NAMES.find(str(d.get("mode", "on_delay"))), 0)
			# Times as the properties allow: zero times would keep the
			# simulation switching at one instant.
			var timer: TimerRelay = TimerRelay.new(designation, mode as TimerRelay.Mode, _delay(d, "delay"), _seconds(d, "pick_up"), _seconds(d, "drop_out"))
			timer.control_input = _bool(d, "control_input", false)
			timer.delay2 = _delay(d, "delay2")
			return timer
		"rectifier":
			return Rectifier.new(designation)
		"plc":
			var plc: Plc
			if str(d.get("family", "")) == "compact":
				var cpu: int = CompactPlc.CPU_NAMES.find(str(d.get("cpu", "")))
				if cpu < 0:
					cpu = CompactPlc.Cpu.DI8_DQ6
				plc = CompactPlc.new(designation, PlcProgram.from_data(d.get("program", {})), plc_modules(d.get("modules", []), cpu), cpu as CompactPlc.Cpu)
			else:
				plc = Plc.new(designation, PlcProgram.from_data(d.get("program", {})), plc_modules(d.get("modules", []), -1, str(d.get("rating", ""))))
			var ip: String = str(d.get("ip", Plc.DEFAULT_IP))
			plc.ip_address = ip if PlcProgram.valid_ip(ip) else Plc.DEFAULT_IP
			return plc
		"network_switch":
			return NetworkSwitch.new(designation)
		"vfd":
			var drive: Vfd = Vfd.new(designation)
			drive.control = maxi(Vfd.CONTROL_NAMES.find(str(d.get("control", ""))), 0) as Vfd.Command
			drive.setpoint = maxi(Vfd.SETPOINT_NAMES.find(str(d.get("setpoint", ""))), 0) as Vfd.Setpoint
			drive.max_frequency = clampf(_number_or(d, "max_frequency", Vfd.DEFAULT_MAX_FREQUENCY), 1.0, Vfd.HIGHEST_FREQUENCY)
			drive.ramp_up = clampf(_number_or(d, "ramp_up", Vfd.DEFAULT_RAMP), 0.0, Vfd.LONGEST_RAMP)
			drive.ramp_down = clampf(_number_or(d, "ramp_down", Vfd.DEFAULT_RAMP), 0.0, Vfd.LONGEST_RAMP)
			# They may be above the maximum frequency: the drive holds them to
			# it while running, so lowering the maximum for a while loses nothing.
			drive.fixed_frequency = clampf(_number_or(d, "fixed_frequency", Vfd.DEFAULT_FIXED), 0.0, Vfd.HIGHEST_FREQUENCY)
			drive.keypad_frequency = clampf(_number_or(d, "keypad_frequency", Vfd.DEFAULT_MAX_FREQUENCY), 0.0, Vfd.HIGHEST_FREQUENCY)
			return drive
		"temp_sensor":
			var sensor: TemperatureSensor = TemperatureSensor.new(designation)
			sensor.range_min = clampf(_number_or(d, "range_min", TemperatureSensor.DEFAULT_MIN), TemperatureSensor.LOWEST, TemperatureSensor.HIGHEST)
			sensor.range_max = clampf(_number_or(d, "range_max", TemperatureSensor.DEFAULT_MAX), TemperatureSensor.LOWEST, TemperatureSensor.HIGHEST)
			if sensor.range_max <= sensor.range_min:
				# A bound set past the other keeps the lower one: the upper
				# one goes just above it (the lower one below the top).
				sensor.range_max = minf(sensor.range_min + RANGE_STEP, TemperatureSensor.HIGHEST)
				sensor.range_min = minf(sensor.range_min, sensor.range_max - RANGE_STEP)
			sensor.temperature = clampf(_number_or(d, "temperature", TemperatureSensor.DEFAULT_TEMPERATURE), TemperatureSensor.LOWEST, TemperatureSensor.HIGHEST)
			return sensor
		"transmitter":
			var quantity: int = maxi(Transmitter.QUANTITY_NAMES.find(str(d.get("quantity", ""))), 0)
			var transmitter: Transmitter = Transmitter.new(designation, quantity as Transmitter.Quantity)
			transmitter.range_min = clampf(_number_or(d, "range_min", Transmitter.DEFAULT_MIN[quantity]), Transmitter.LOWEST, Transmitter.HIGHEST)
			transmitter.range_max = clampf(_number_or(d, "range_max", Transmitter.DEFAULT_MAX[quantity]), Transmitter.LOWEST, Transmitter.HIGHEST)
			if transmitter.range_max - transmitter.range_min < TRANSMITTER_RANGE_STEP:
				# As for the temperature sensor: the lower bound stays.
				transmitter.range_max = minf(transmitter.range_min + TRANSMITTER_RANGE_STEP, Transmitter.HIGHEST)
				transmitter.range_min = minf(transmitter.range_min, transmitter.range_max - TRANSMITTER_RANGE_STEP)
			transmitter.value = clampf(_number_or(d, "value", Transmitter.DEFAULT_VALUE[quantity]), Transmitter.LOWEST, Transmitter.HIGHEST)
			return transmitter
		"pot":
			var pot: Potentiometer = Potentiometer.new(designation, _int(d, "turns", 1))
			pot.setting = _number_or(d, "setting", Potentiometer.DEFAULT_SETTING * 100.0) / 100.0
			return pot
		"proximity":
			var function: int = maxi(ProximitySensor.FUNCTION_NAMES.find(str(d.get("function", ""))), 0)
			var proximity: ProximitySensor = ProximitySensor.new(designation, function as ProximitySensor.Function)
			proximity.sensing = maxi(ProximitySensor.SENSING_NAMES.find(str(d.get("sensing", ""))), 0) as ProximitySensor.Sensing
			proximity.output = maxi(ProximitySensor.OUTPUT_NAMES.find(str(d.get("output", ""))), 0) as ProximitySensor.Output
			return proximity
		"light_switch":
			var light_switch: LightSwitch = LightSwitch.new(designation, str(d.get("circuit", "1")))
			light_switch.height = _height(d, LightSwitch.STANDARD_HEIGHT)
			return light_switch
		"luminaire":
			var luminaire: Luminaire = Luminaire.new(designation)
			luminaire.power = clampf(_number_or(d, "power", luminaire.power), Luminaire.MIN_POWER, Luminaire.MAX_POWER)
			luminaire.wall = _bool(d, "wall", false)
			luminaire.height = _height(d, luminaire.standard_height())
			return luminaire
		"socket":
			var socket: SocketOutlet = SocketOutlet.new(designation, _int(d, "gangs", 1))
			socket.height = _height(d, SocketOutlet.STANDARD_HEIGHT)
			socket.plug(Appliance.KIND_NAMES.find(str(d.get("plugged", ""))))
			if socket.plugged >= 0:
				socket.plugged_power = clampf(_number_or(d, "plugged_power", socket.plugged_power), Appliance.MIN_POWER, Appliance.MAX_POWER)
			return socket
		"appliance":
			var appliance_kind: int = maxi(Appliance.KIND_NAMES.find(str(d.get("kind", ""))), 0)
			var appliance: Appliance = Appliance.new(designation, appliance_kind as Appliance.Kind)
			appliance.power = clampf(_number_or(d, "power", appliance.power), Appliance.MIN_POWER, Appliance.MAX_POWER)
			appliance.two_phases = _bool(d, "two_phases", appliance.two_phases)
			appliance.height = _height(d, Appliance.STANDARD_HEIGHT)
			return appliance
		"rcd":
			var rcd: ResidualCurrentDevice = ResidualCurrentDevice.new(designation, 4 if _int(d, "poles", 2) == 4 else 2)
			var residual: float = _number_or(d, "residual", 0.03)
			rcd.residual_rating = residual if ResidualCurrentDevice.RESIDUAL_RATINGS.has(residual) else 0.03
			rcd.type = str(d.get("rcd_type", "A")) if ResidualCurrentDevice.TYPES.has(str(d.get("rcd_type", "A"))) else "A"
			rcd.selective = _bool(d, "selective", false)
			rcd.overcurrent = _bool(d, "overcurrent", false)
			rcd.rated_current = _amperes(d, "rated_current", 16.0 if rcd.overcurrent else 40.0)
			rcd.characteristic = maxi(TripCurve.LETTERS.find(str(d.get("characteristic", "B"))), 0) as CircuitBreaker.Characteristic
			return rcd
		"afdd":
			var afdd: ArcFaultDevice = ArcFaultDevice.new(designation)
			afdd.rated_current = _amperes(d, "rated_current", 16.0)
			afdd.characteristic = maxi(TripCurve.LETTERS.find(str(d.get("characteristic", "B"))), 0) as CircuitBreaker.Characteristic
			return afdd
		"lamp":
			var lamp: Lamp = Lamp.new(designation)
			lamp.purpose = str(d.get("purpose", "")).strip_edges()
			return lamp
		"motor":
			return Motor.new(designation)
	return null


## Mounting height "height" over the floor (m) of a part of a house
## installation, [param fallback] when missing; within 0 and [constant
## MAX_HEIGHT], to the centimetre.
static func _height(d: Dictionary, fallback: float) -> float:
	return snappedf(clampf(_number_or(d, "height", fallback), 0.0, MAX_HEIGHT), 0.01)


## A switching time in seconds, or -1 (use the default) if missing or invalid.
static func _seconds(d: Dictionary, key: String) -> float:
	var value: Variant = d.get(key, null)
	if (value is float or value is int) and float(value) >= 0.0 and float(value) <= 10.0:
		return float(value)
	return -1.0


## A current in amperes (0.1 A - 10 kA), or [param fallback] if missing or invalid.
static func _amperes(d: Dictionary, key: String, fallback: float) -> float:
	var value: float = _number_or(d, key, fallback)
	return value if value >= MIN_AMPERES and value <= MAX_AMPERES else fallback


## A time t1 or t2 of a time relay: within [constant SHORTEST_DELAY] -
## [constant LONGEST_DELAY], 1 s if missing or invalid.
static func _delay(d: Dictionary, key: String) -> float:
	return clampf(_number_or(d, key, 1.0), SHORTEST_DELAY, LONGEST_DELAY)


## A true / false value (a number counts as true unless 0), [param fallback]
## if missing or of another type.
static func _bool(d: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = d.get(key, null)
	if value is bool:
		return value
	if value is int or value is float:
		return float(value) != 0.0
	return fallback


## A whole number, [param fallback] if missing or not a number.
static func _int(d: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = d.get(key, null)
	return int(value) if value is int or value is float else fallback


static func _number_or(d: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = d.get(key, null)
	return float(value) if value is float or value is int else fallback


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
