class_name DocumentSerializer
extends RefCounted
## Converts schematics and components to plain Dictionaries and back. Used for
## undo snapshots, for the simulation copy of an edited schematic and for
## building components from editor templates. Only design data is stored,
## never simulation state.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC


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
	return {"title": doc.title, "horizontal": doc.horizontal, "components": components, "wires": wires}


static func from_dict(d: Dictionary) -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(d.get("title", ""))
	doc.horizontal = bool(d.get("horizontal", false))
	for cd: Dictionary in d.get("components", []):
		var c: CircuitComponent = component_from_dict(cd)
		var cell: Array = cd.get("cell", [0, 0])
		if c != null:
			doc.add(c, Vector2i(int(cell[0]), int(cell[1])), int(cd.get("rotation", 0)), bool(cd.get("mirrored", false)))
	for wd: Dictionary in d.get("wires", []):
		var corners: Array[Vector2i] = []
		for corner: Array in wd.get("corners", []):
			corners.append(Vector2i(int(corner[0]), int(corner[1])))
		doc.connect_terminals(wd["a"], wd["b"], corners)
	return doc


static func component_to_dict(c: CircuitComponent) -> Dictionary:
	var d: Dictionary = {"designation": c.designation}
	if c is PowerSupply:
		d["type"] = "supply"
		d["conductor"] = "L" if (c as PowerSupply).conductor == PowerSupply.Conductor.L else "N"
	elif c is Junction:
		d["type"] = "junction"
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
	elif c is Coil:
		d["type"] = "coil"
		d["kind"] = "relay" if (c as Coil).kind == Coil.Kind.RELAY else "contactor"
	elif c is Lamp:
		d["type"] = "lamp"
	elif c is Motor:
		d["type"] = "motor"
	return d


static func component_from_dict(d: Dictionary) -> CircuitComponent:
	var designation: String = d.get("designation", "")
	var contact: SwitchingElement.ContactType = NC if d.get("contact", "NO") == "NC" else NO
	var sequence: int = int(d.get("sequence", 1))
	match d.get("type", ""):
		"supply":
			var conductor: PowerSupply.Conductor = PowerSupply.Conductor.N if d.get("conductor", "L") == "N" else PowerSupply.Conductor.L
			return PowerSupply.new(designation, conductor)
		"junction":
			return Junction.new(designation)
		"push_button":
			return PushButton.new(designation, contact, sequence)
		"latching_switch":
			return LatchingSwitch.new(designation, contact, sequence)
		"contact":
			return Contact.new(designation, contact, sequence, bool(d.get("delayed", false)))
		"coil":
			return Coil.new(designation, Coil.Kind.RELAY if d.get("kind", "contactor") == "relay" else Coil.Kind.CONTACTOR)
		"timer":
			var mode: TimerRelay.Mode = TimerRelay.Mode.OFF_DELAY if d.get("mode", "on_delay") == "off_delay" else TimerRelay.Mode.ON_DELAY
			return TimerRelay.new(designation, mode, float(d.get("delay", 1.0)))
		"lamp":
			return Lamp.new(designation)
		"motor":
			return Motor.new(designation)
	push_error("DocumentSerializer: unknown component type '%s'" % d.get("type", ""))
	return null
