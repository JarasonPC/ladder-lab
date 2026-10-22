class_name WorkspaceCables
extends RefCounted
## The cables of the workspace, worked out from the wiring: every net of the
## circuit that joins terminals in two or more places (a switchboard, a
## control station, a part in the field) needs a core between them. A net
## with a terminal on a strip in a switchboard runs from there to each other
## place (a star from the strip); any other net runs from the first
## switchboard to each other place, so stations and parts in the field are
## never cabled to one another (without a switchboard: the shortest way
## between them). The cores between two places make one cable, named
## W1, W2, ... ([member SchematicDocument.cable_names] keeps the names), and
## gets a type as a real cable by what it is used for ([method use],
## [method type_text]). An Ethernet cable between the ports of two PLCs (or
## a PLC and a network switch) in two places is a cable of its own, never a
## core of another (key "+RA1|+RA2|A1:P1", the port it starts from at the
## first end). No nodes.

## How cable types are written: Czech designations ("CGSG-J 3x2,5") or their
## European equivalents ("H07RN-F 3G2,5").
enum Naming { CZECH, HARMONISED }
## What a cable is used for, which decides its type: to a motor (rubber
## flexible), to a limit switch (rubber flexible, on the machine), to a
## sensor (shielded, analog signal), between switchboards with power cores (a
## feeder, laid fixed), any other control cable (control stations, control
## cores between switchboards: PVC control cable), an Ethernet cable between
## two ports (Cat 6, four shielded pairs).
enum Use { MOTOR, FIELD, SENSOR, FEEDER, CONTROL, ETHERNET }

## Copper cross-sections (mm²) with the most current (A) each is taken for,
## smallest first (a flexible rubber cable laid on a surface, protected for
## that current).
const SECTIONS: Array[Vector2] = [
	Vector2(1.5, 16.0), Vector2(2.5, 20.0), Vector2(4.0, 25.0), Vector2(6.0, 32.0),
	Vector2(10.0, 50.0), Vector2(16.0, 63.0), Vector2(25.0, 80.0), Vector2(35.0, 100.0),
	Vector2(50.0, 125.0), Vector2(70.0, 160.0), Vector2(95.0, 200.0), Vector2(120.0, 250.0),
]
## Cross-sections (mm²) a cable can be given by hand.
const CHOICES: PackedFloat32Array = [0.5, 0.75, 1.0, 1.5, 2.5, 4.0, 6.0, 10.0, 16.0, 25.0, 35.0, 50.0, 70.0, 95.0, 120.0]
## Longest cable length (m) that can be given.
const MAX_LENGTH: float = 10000.0
## Resistivity of copper at its working temperature (Ω mm²/m, 1.25 times
## that at 20 °C, as ČSN 33 2000-5-52 annex G reckons voltage drop).
const RESISTIVITY: float = 0.0225
## Voltage drop (%) above which a cable is marked: the 4 % commonly kept to
## for circuits other than lighting.
const DROP_LIMIT: float = 4.0
## Cross-section of a cable without power cores (control circuits).
const CONTROL_SECTION: float = 1.5
## How many core diameters across a bundle of n cores laid up round each
## other is (index n; beyond the list it grows with √n).
const LAY_UP: PackedFloat32Array = [0.0, 1.0, 2.0, 2.16, 2.42, 2.7, 3.0, 3.0, 3.45, 3.8, 4.0, 4.0, 4.16, 4.41, 4.41, 4.7, 4.7, 5.0, 5.0, 5.0, 6.0, 6.0, 6.0, 6.0, 6.0]
## Cable glands: what each size clamps, outer diameters in mm (smallest
## first): metric (EN 62444) and the older PG sizes still named in Czech
## practice ("PG vývodka").
const GLANDS_METRIC: Array[Array] = [["M12", 3.0, 6.5], ["M16", 4.5, 10.0], ["M20", 7.0, 13.0], ["M25", 9.0, 17.0], ["M32", 11.0, 21.0], ["M40", 19.0, 28.0], ["M50", 27.0, 35.0], ["M63", 34.0, 45.0]]
const GLANDS_PG: Array[Array] = [["PG7", 3.0, 6.5], ["PG9", 4.0, 8.0], ["PG11", 5.0, 10.0], ["PG13,5", 6.0, 12.0], ["PG16", 10.0, 14.0], ["PG21", 13.0, 18.0], ["PG29", 18.0, 25.0], ["PG36", 22.0, 32.0], ["PG42", 32.0, 38.0], ["PG48", 37.0, 44.0]]
## Cross-sections of control cables (PVC control cables come in 1 mm²) and of
## shielded sensor cables.
const CONTROL_CABLE_SECTION: float = 1.0
const SENSOR_SECTION: float = 0.75
## Types by [enum Use]: [Czech, European] and the letters marking a cable
## with / without a green-yellow core in each (type, then cores x section;
## "" where the letters go between the cores and the section: "3G1,5").
const TYPES: Dictionary[Use, Array] = {
	Use.MOTOR: [["CGSG-J", "CGSG-O"], ["H07RN-F", "H07RN-F"]],
	Use.FIELD: [["CGSG-J", "CGSG-O"], ["H07RN-F", "H07RN-F"]],
	Use.SENSOR: [["LiYCY", "LiYCY"], ["H05VVC4V5-K", "H05VVC4V5-K"]],
	Use.FEEDER: [["CYKY-J", "CYKY-O"], ["NYY-J", "NYY-O"]],
	Use.CONTROL: [["JYTY-J", "JYTY-O"], ["H05VV5-F", "H05VV5-F"]],
	Use.ETHERNET: [["Cat 6 S/FTP", "Cat 6 S/FTP"], ["Cat 6 S/FTP", "Cat 6 S/FTP"]],
}
## How an Ethernet cable's conductors are written (four pairs of AWG 23),
## its outer diameter (mm) and the cross-section of a conductor (mm²).
const ETHERNET_CORES: String = "4x2xAWG23"
const ETHERNET_DIAMETER: float = 7.2
const ETHERNET_SECTION: float = 0.26

## Naming of [method type_text] (Settings menu, kept in the user settings).
static var naming: Naming = Naming.CZECH

## A cable: {"key" (its two ends, "+RA1|+ST1"), "name" ("W1"), "a", "b" (the
## ends: "+RA1" a switchboard or station, "-M1" a part in the field), "cores"
## (one for each net, one for each strip terminal on the lead of a part at
## the other end where a net has two or more of them, see [method _split]):
## [{"net", "conductor" ([enum CabinetDevices.Conductor]), "a", "b" (what the
## core lands on at each end, e.g. "X2:3", "SB1:13"), "number" (wire number,
## may be empty), "hub" (the switchboard the net runs out from to the other
## places, where a supply comes in; "" for none)}], the PE core last, "use" ([enum Use], see [method use]),
## "section" (mm², see [method section], or the one set by hand), "auto_section"
## (the one by [method section]), "type" (a type name set by hand, "" for
## the one by its use), "length" (metres set by hand, 0 for none; see
## [member SchematicDocument.cable_settings])}.
static func cables(doc: SchematicDocument) -> Array[Dictionary]:
	# A training plan simulated as wired: the cables laid by the plan.
	doc = TrainingPlan.drawn_of(doc)
	var circuit: Circuit = doc.circuit
	var net: Dictionary[String, int] = nets(circuit)
	var conductor: Dictionary[int, CabinetDevices.Conductor] = CabinetDevices.conductors(circuit, net)
	var where: Dictionary[String, String] = _locations(doc)
	# Net -> place -> what the net lands on there.
	var ends: Dictionary[int, Dictionary] = {}
	# Net -> switchboards with a strip terminal on it.
	var strip_boards: Dictionary[int, Array] = {}
	for c: CircuitComponent in circuit.get_components():
		var place: String = where.get(c.designation, "")
		if c is TerminalBlock or place.is_empty():
			continue
		var names: PackedStringArray = c.get_terminal_names()
		var keys: PackedStringArray = c.get_terminal_keys()
		for i: int in keys.size():
			_land(ends, net[keys[i]], place, "%s:%s" % [c.designation, names[i]])
	var strips: Dictionary = CabinetDevices.strips(doc)
	var strip_labels: Dictionary[String, bool] = {}
	# Strip terminal label -> the terminal keys it joins.
	var strip_keys: Dictionary[String, PackedStringArray] = {}
	for strip: String in strips:
		var b: int = Workspace.switchboard_of(doc, CabinetItem.Kind.STRIP, strip)
		if b < 0:
			continue
		var place: String = "+" + doc.switchboards[b].name
		for t: Dictionary in strips[strip]:
			var label: String = "%s:%s" % [strip, t["label"]]
			strip_labels[label] = true
			strip_keys[label] = t["keys"]
			for key: String in t["keys"]:
				if not net.has(key):
					continue
				var n: int = net[key]
				_land(ends, n, place, label)
				if not strip_boards.has(n):
					strip_boards[n] = []
				if not strip_boards[n].has(place):
					strip_boards[n].append(place)
	# At a switchboard a core lands on its strip terminal (the devices behind
	# it are wired inside).
	for n: int in strip_boards:
		for place: String in strip_boards[n]:
			var on_strip: Array = []
			for label: Variant in ends[n][place]:
				if strip_labels.has(label):
					on_strip.append(label)
			ends[n][place] = on_strip
	# A net on a supply point comes from a switchboard, where the supply
	# comes in: from the first one when no switchboard has a terminal on it
	# (e.g. a potentiometer's 10 V reference).
	if not doc.switchboards.is_empty():
		var board: String = "+" + doc.switchboards[0].name
		for c: CircuitComponent in circuit.get_components():
			if not (c is PowerSupply):
				continue
			var n: int = net[c.get_terminal_keys()[0]]
			if ends.has(n) and not ends[n].keys().any(func(place: String) -> bool: return _is_board(doc, place)):
				_land(ends, n, board, c.designation)
	var numbers: Dictionary[int, String] = wire_numbers(doc, net)
	var centres: Dictionary[String, Vector2] = _centres(doc)
	var rank: Dictionary[String, int] = {}
	for i: int in centres.size():
		rank[centres.keys()[i]] = i
	# Cable key -> cable.
	var found: Dictionary[String, Dictionary] = {}
	var nets: Array = ends.keys()
	nets.sort()
	for n: int in nets:
		var places: Array = ends[n].keys()
		if places.size() < 2:
			continue
		places.sort_custom(func(p: String, q: String) -> bool: return rank.get(p, 1 << 20) < rank.get(q, 1 << 20))
		var pairs: Array[PackedStringArray] = []
		var hub: String = ""
		if strip_boards.has(n):
			hub = strip_boards[n][0]
		elif places[0].begins_with("+") and _is_board(doc, places[0]):
			hub = places[0]
		elif not doc.switchboards.is_empty():
			# Stations and parts in the field are never cabled to one another:
			# each goes to the first switchboard, where the net lands on
			# nothing until a strip terminal is put on it.
			hub = "+" + doc.switchboards[0].name
			ends[n][hub] = []
			places.push_front(hub)
		if not hub.is_empty():
			for place: String in places:
				if place != hub:
					pairs.append(PackedStringArray([hub, place]))
		else:
			pairs = _tree(places, centres)
		for pair: PackedStringArray in pairs:
			var a: String = pair[0]
			var b: String = pair[1]
			if rank.get(b, 1 << 20) < rank.get(a, 1 << 20):
				a = pair[1]
				b = pair[0]
			var key: String = a + "|" + b
			if conductor.get(n, CabinetDevices.Conductor.CONTROL) == CabinetDevices.Conductor.NETWORK:
				# A cable of its own, from the port at its first end.
				key += "|" + str(ends[n][a][0])
			if not found.has(key):
				found[key] = {"key": key, "name": "", "a": a, "b": b, "cores": []}
			for core: Array in _split(ends[n][a], ends[n][b], strip_keys):
				found[key]["cores"].append({"net": n, "conductor": conductor.get(n, CabinetDevices.Conductor.CONTROL), "a": _labels(core[0]), "b": _labels(core[1]), "number": numbers.get(n, ""), "hub": hub})
	var result: Array[Dictionary] = []
	for key: String in found:
		var cable: Dictionary = found[key]
		# The PE core last, as in a real cable.
		(cable["cores"] as Array).sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["conductor"] != CabinetDevices.Conductor.PE and q["conductor"] == CabinetDevices.Conductor.PE)
		cable["use"] = use(doc, cable)
		cable["auto_section"] = section(doc, cable)
		var given: Dictionary = doc.cable_settings.get(key, {})
		cable["section"] = float(given.get("section", 0.0)) if float(given.get("section", 0.0)) > 0.0 else cable["auto_section"]
		cable["type"] = str(given.get("type", ""))
		cable["length"] = float(given.get("length", 0.0))
		result.append(cable)
	result.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		if p["a"] != q["a"]:
			return rank.get(p["a"], 1 << 20) < rank.get(q["a"], 1 << 20)
		return rank.get(p["b"], 1 << 20) < rank.get(q["b"], 1 << 20))
	_name(doc, result)
	return result


## The nets as the cables run them ([method CabinetDevices.nets]): the supply
## points of one conductor are one net (of one voltage for +), fed by one core.
static func nets(circuit: Circuit) -> Dictionary[String, int]:
	return CabinetDevices.supply_nets(circuit, CabinetDevices.nets(circuit))


## Type of a cable as written on it, by its use ([constant TYPES]) as
## [member naming] says: Czech "CGSG-J 4x2,5" (J with a PE core, O without),
## "JYTY-O 7x1", "CYKY-J 5x10", "LiYCY 3x0,75"; European "H07RN-F 4G2,5" (G
## with a PE core, x without), "H05VV5-F 7x1", "NYY-J 5x10" (J / O as in
## Czech), "H05VVC4V5-K 3x0,75". A cable without a use is taken as one to a
## part in the field. A type name set by hand ("type") takes the place of
## the one by its use, written with the cores as European types are while
## [member naming] is European.
static func type_text(cable: Dictionary) -> String:
	if int(cable.get("use", Use.FIELD)) == Use.ETHERNET:
		return "%s %s" % [type_name(cable), ETHERNET_CORES]
	var cores: int = (cable["cores"] as Array).size()
	var pe: bool = false
	for core: Dictionary in cable["cores"]:
		pe = pe or core["conductor"] == CabinetDevices.Conductor.PE
	var mm2: String = section_text(float(cable.get("section", CONTROL_SECTION)))
	var type: String = type_name(cable)
	var given: bool = not str(cable.get("type", "")).is_empty()
	if type.begins_with("H0") or (given and naming == Naming.HARMONISED):
		# Harmonised types mark the green-yellow core between count and section.
		return "%s %d%s%s" % [type, cores, "G" if pe else "x", mm2]
	return "%s %dx%s" % [type, cores, mm2]


## The type name of [param cable] without its cores: the one set by hand,
## else the one by its use ([constant TYPES]) as [member naming] says.
static func type_name(cable: Dictionary) -> String:
	var given: String = str(cable.get("type", ""))
	if not given.is_empty():
		return given
	var pe: bool = false
	for core: Dictionary in cable["cores"]:
		pe = pe or core["conductor"] == CabinetDevices.Conductor.PE
	var names: Array = TYPES[int(cable.get("use", Use.FIELD)) as Use][1 if naming == Naming.HARMONISED else 0]
	return names[0] if pe else names[1]


## Settings set by hand on a cable as kept in
## [member SchematicDocument.cable_settings]: [param type] (one line, at most
## 40 characters, "" for the type by use), [param section] (one of
## [constant CHOICES], else 0), [param length] (metres up to
## [constant MAX_LENGTH], else 0); {} when nothing is set.
static func settings(type: String, section: float, length: float) -> Dictionary:
	var result: Dictionary = {}
	var name: String = " ".join(type.strip_edges().split("\n", false)).left(40).strip_edges()
	if not name.is_empty():
		result["type"] = name
	for choice: float in CHOICES:
		if is_equal_approx(choice, section):
			result["section"] = choice
	if length > 0.0 and length <= MAX_LENGTH:
		result["length"] = snappedf(length, 0.1)
	return result


## Voltage drop along [param cable] over its length: {"amps" (the current
## reckoned with), "volts", "percent" (of the voltage it is reckoned against,
## "of")}; {} without a length or a current to reckon with. A cable to a
## three-phase motor carries its rated current, a feeder those of all
## three-phase motors (ΔU = √3 I L ρ cos φ / S, against 400 V); a control
## cable on each core the rated currents of the loads on the core's net all
## on at once (ΔU = 2 I L ρ / S, there and back, against their rated
## voltage), the worst core counting. Reactance is left out (small for these
## cross-sections).
static func voltage_drop(doc: SchematicDocument, cable: Dictionary) -> Dictionary:
	var length: float = float(cable.get("length", 0.0))
	var mm2: float = float(cable.get("section", CONTROL_SECTION))
	if length <= 0.0 or mm2 <= 0.0:
		return {}
	var power: bool = false
	for core: Dictionary in cable["cores"]:
		power = power or core["conductor"] == CabinetDevices.Conductor.POWER
		if core["conductor"] == CabinetDevices.Conductor.NETWORK:
			# Carries data, no load current.
			return {}
	if power:
		var motors: Array[ThreePhaseMotor] = []
		for end: String in [cable["a"], cable["b"]]:
			var c: CircuitComponent = Workspace.field_component(doc.circuit, end.substr(1)) if end.begins_with("-") else null
			if c is ThreePhaseMotor:
				motors.append(c)
		if motors.is_empty():
			for c: CircuitComponent in doc.circuit.get_components():
				if c is ThreePhaseMotor:
					motors.append(c)
		var amps: float = 0.0
		var active: float = 0.0
		for motor: ThreePhaseMotor in motors:
			amps += motor.rated_current
			active += motor.rated_current * motor.power_factor
		if amps <= 0.0:
			return {}
		var volts: float = sqrt(3.0) * length * RESISTIVITY * active / mm2
		return {"amps": amps, "volts": volts, "percent": 100.0 * volts / 400.0, "of": 400.0}
	var net: Dictionary[String, int] = nets(doc.circuit)
	var worst: Dictionary = {}
	for core: Dictionary in cable["cores"]:
		if core["conductor"] == CabinetDevices.Conductor.PE or core["conductor"] == CabinetDevices.Conductor.NEUTRAL:
			continue
		var amps: float = 0.0
		var of: float = 0.0
		for c: CircuitComponent in doc.circuit.get_components():
			if not (c is Load):
				continue
			for key: String in c.get_terminal_keys():
				if net.get(key, -1) == core["net"]:
					amps += (c as Load).rated_draw()
					if of <= 0.0:
						of = VoltageRating.nominal((c as Load).rating)
					break
		if amps <= 0.0:
			continue
		of = of if of > 0.0 else PowerSupply.PHASE_VOLTS
		var volts: float = 2.0 * amps * length * RESISTIVITY / mm2
		if worst.is_empty() or volts / of > float(worst["volts"]) / float(worst["of"]):
			worst = {"amps": amps, "volts": volts, "percent": 100.0 * volts / of, "of": of}
	return worst


## What [param cable] is used for: a motor at one end makes it a motor cable,
## else a sensor a sensor cable, else another part in the field (a limit
## switch) a field cable; one between switchboards and stations is a feeder
## when it has power cores, else a control cable. An Ethernet cable is one.
static func use(doc: SchematicDocument, cable: Dictionary) -> Use:
	for core: Dictionary in cable["cores"]:
		if core["conductor"] == CabinetDevices.Conductor.NETWORK:
			return Use.ETHERNET
	var kinds: Array[Workspace.Field] = []
	for end: String in [cable["a"], cable["b"]]:
		var c: CircuitComponent = Workspace.field_component(doc.circuit, end.substr(1)) if end.begins_with("-") else null
		if c != null:
			kinds.append(Workspace.field_kind(c))
	if kinds.has(Workspace.Field.MOTOR):
		return Use.MOTOR
	if kinds.has(Workspace.Field.SENSOR):
		return Use.SENSOR
	if not kinds.is_empty():
		return Use.FIELD
	for core: Dictionary in cable["cores"]:
		if core["conductor"] == CabinetDevices.Conductor.POWER:
			return Use.FEEDER
	return Use.CONTROL


## The type of [param cable] with its length when one is set: "CGSG-J
## 4x2,5, 25 m" (on the workspace and in the parts list).
static func type_and_length(cable: Dictionary) -> String:
	var length: float = float(cable.get("length", 0.0))
	if length <= 0.0:
		return type_text(cable)
	return "%s, %s m" % [type_text(cable), section_text(length)]


## Outer diameter of [param cable] in mm, estimated as cable makers' tables
## give it: copper of its cross-section (stranded but in PVC control and
## feeder cables), insulated, the cores laid up ([constant LAY_UP]) and
## sheathed (rubber thicker than PVC, a shield under the sheath of a sensor
## cable).
static func outer_diameter(cable: Dictionary) -> float:
	var mm2: float = float(cable.get("section", CONTROL_SECTION))
	var kind: Use = int(cable.get("use", Use.FIELD)) as Use
	if kind == Use.ETHERNET:
		return ETHERNET_DIAMETER
	var rubber: bool = kind == Use.MOTOR or kind == Use.FIELD
	var solid: bool = kind == Use.CONTROL or kind == Use.FEEDER
	var copper: float = sqrt(4.0 * mm2 / PI) * (1.0 if solid else 1.15)
	var steps: PackedFloat32Array = [1.5, 2.5, 6.0, 16.0, 35.0]
	var rubber_wall: PackedFloat32Array = [0.8, 1.0, 1.0, 1.2, 1.4, 1.6]
	var pvc_wall: PackedFloat32Array = [0.6, 0.7, 0.8, 1.0, 1.2, 1.4]
	var step: int = steps.size()
	for i: int in steps.size():
		if mm2 <= steps[i] + 0.001:
			step = i
			break
	if kind == Use.SENSOR:
		step = 0
	var core: float = copper + 2.0 * (rubber_wall[step] if rubber else pvc_wall[step]) * (0.6 if kind == Use.SENSOR else 1.0)
	var cores: int = maxi((cable["cores"] as Array).size(), 1)
	var across: float = LAY_UP[cores] if cores < LAY_UP.size() else LAY_UP[LAY_UP.size() - 1] * sqrt(cores / float(LAY_UP.size() - 1))
	var sheath: float = ([1.8, 1.8, 1.8, 2.2, 2.2, 2.8] as Array)[step] if rubber else ([1.2, 1.2, 1.2, 1.4, 1.4, 1.8] as Array)[step]
	if kind == Use.SENSOR:
		sheath = 1.2
	return across * core + 2.0 * sheath


## The cable gland for [param cable] as [member naming] names glands (PG in
## Czech practice, metric otherwise): {"size", "from", "to" (mm it clamps)},
## the smallest whose range takes its outer diameter ({} when none does).
static func gland(cable: Dictionary) -> Dictionary:
	var diameter: float = outer_diameter(cable)
	for entry: Array in (GLANDS_PG if naming == Naming.CZECH else GLANDS_METRIC):
		if diameter >= float(entry[1]) and diameter <= float(entry[2]):
			return {"size": entry[0], "from": entry[1], "to": entry[2]}
	return {}


## A cross-section as written on cables: "0,75", "2,5", "10".
static func section_text(mm2: float) -> String:
	return str(snappedf(mm2, 0.01)).trim_suffix(".0").replace(".", ",")


## Cross-section (mm²) of [param cable]: a PVC control cable
## [constant CONTROL_CABLE_SECTION], a sensor cable [constant SENSOR_SECTION],
## another cable without power cores [constant CONTROL_SECTION]; one to a
## motor carries the motor's rated current, any other power cable the rated
## currents of all motors together (it feeds them), the smallest of
## [constant SECTIONS] that takes it.
static func section(doc: SchematicDocument, cable: Dictionary) -> float:
	var power: bool = false
	for core: Dictionary in cable["cores"]:
		power = power or core["conductor"] == CabinetDevices.Conductor.POWER
	var kind: Use = int(cable.get("use", use(doc, cable))) as Use
	if kind == Use.SENSOR:
		return SENSOR_SECTION
	if kind == Use.ETHERNET:
		return ETHERNET_SECTION
	if not power:
		return CONTROL_CABLE_SECTION if kind == Use.CONTROL else CONTROL_SECTION
	var amps: float = 0.0
	var motor: bool = false
	for end: String in [cable["a"], cable["b"]]:
		var c: CircuitComponent = Workspace.field_component(doc.circuit, end.substr(1)) if end.begins_with("-") else null
		if c is ThreePhaseMotor:
			amps = maxf(amps, (c as ThreePhaseMotor).rated_current)
			motor = true
	if not motor:
		for c: CircuitComponent in doc.circuit.get_components():
			if c is ThreePhaseMotor:
				amps += (c as ThreePhaseMotor).rated_current
	for entry: Vector2 in SECTIONS:
		if amps <= entry.y:
			return entry.x
	return SECTIONS[SECTIONS.size() - 1].x


## A cable name as saved: "" when unusable (empty, spaces, colons, "|").
static func cable_name(value: Variant) -> String:
	var text: String = str(value).strip_edges()
	return "" if text.contains(":") or text.contains(" ") or text.contains("|") else text


## Names: the one kept for the cable, else the first free "W<n>" in order.
static func _name(doc: SchematicDocument, list: Array[Dictionary]) -> void:
	var taken: Dictionary[String, bool] = {}
	for cable: Dictionary in list:
		var kept: String = doc.cable_names.get(cable["key"], "")
		if not kept.is_empty() and not taken.has(kept):
			cable["name"] = kept
			taken[kept] = true
	var n: int = 1
	for cable: Dictionary in list:
		if not str(cable["name"]).is_empty():
			continue
		while taken.has("W%d" % n):
			n += 1
		cable["name"] = "W%d" % n
		taken[cable["name"]] = true


## Where each part of the circuit sits, by designation: "+RA1" for a device
## in a switchboard (an overload relay fitted under its contactor where the
## contactor is) or a button, switch or lamp on its door, "+ST1" for one on a
## station, "-M1" for a part in the field. Parts with no place are left out.
static func _locations(doc: SchematicDocument) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for board: Switchboard in doc.switchboards:
		for rail: CabinetRail in board.rails:
			for item: CabinetItem in rail.items:
				if item.kind == CabinetItem.Kind.DEVICE:
					result[item.designation] = "+" + board.name
	var under: Dictionary[String, String] = CabinetDevices.overloads_under_contactors(doc.circuit)
	for contactor: String in under:
		if result.has(contactor) and not result.has(under[contactor]):
			result[under[contactor]] = result[contactor]
	for box: ControlBox in doc.control_boxes:
		for item: ControlBoxItem in box.items:
			for designation: String in [item.designation, item.lamp]:
				if not designation.is_empty():
					result[designation] = "+" + box.name
	for board: Switchboard in doc.switchboards:
		for item: ControlBoxItem in board.door.items:
			for designation: String in [item.designation, item.lamp]:
				if not designation.is_empty():
					result[designation] = "+" + board.name
	for designation: String in Workspace.field_devices(doc.circuit):
		result[designation] = "-" + designation
	return result


## Centre of every place and part in the field on the workspace, switchboards
## first, then stations, then parts (their order ranks the ends of a cable).
static func _centres(doc: SchematicDocument) -> Dictionary[String, Vector2]:
	var result: Dictionary[String, Vector2] = {}
	for board: Switchboard in doc.switchboards:
		result["+" + board.name] = Workspace.place_tile(board.position).get_center()
	for box: ControlBox in doc.control_boxes:
		result["+" + box.name] = Workspace.place_tile(box.position).get_center()
	# Parts in circuit order, wherever they were put: moving one keeps the
	# ends of its cables in the same order, so the cables keep their names.
	var positions: Dictionary[String, Vector2] = Workspace.field_positions(doc)
	for designation: String in Workspace.field_devices(doc.circuit):
		if positions.has(designation):
			result["-" + designation] = positions[designation] + Vector2(Workspace.FIELD_SIZE.x * 0.5, Workspace.FIELD_TILE * 0.5)
	return result


static func _is_board(doc: SchematicDocument, place: String) -> bool:
	for board: Switchboard in doc.switchboards:
		if "+" + board.name == place:
			return true
	return false


static func _land(ends: Dictionary[int, Dictionary], n: int, place: String, label: String) -> void:
	if not ends.has(n):
		ends[n] = {}
	if not ends[n].has(place):
		ends[n][place] = []
	if not ends[n][place].has(label):
		ends[n][place].append(label)


static func _labels(list: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for label: Variant in list:
		result.append(str(label))
	return result


## The cores of one net between two places that land on [param a] and
## [param b] there: [what a core lands on at a, at b] for each. Strip
## terminals ([param strip_keys]: label -> terminal keys) on the leads of
## parts at the other end each have a core of their own to that part, two
## or more of them; else one core lands on them all.
static func _split(a: Array, b: Array, strip_keys: Dictionary[String, PackedStringArray]) -> Array:
	for side: int in 2:
		var strips: Array = a if side == 0 else b
		var parts: Array = b if side == 0 else a
		var leads: Array = []
		for label: Variant in strips:
			for key: String in strip_keys.get(str(label), PackedStringArray()):
				if parts.has(key):
					leads.append([[label], [key]] if side == 0 else [[key], [label]])
					break
		if leads.size() >= 2:
			return leads
	return [[a, b]]


## Wire number of each net that has one.
static func wire_numbers(doc: SchematicDocument, net: Dictionary[String, int]) -> Dictionary[int, String]:
	var result: Dictionary[int, String] = {}
	var wires: Array[PackedStringArray] = doc.circuit.get_wires()
	for i: int in wires.size():
		var number: String = doc.get_route(i).number
		if not number.is_empty() and net.has(wires[i][0]):
			result[net[wires[i][0]]] = number
	return result


## Pairs of [param places] joining them all along the shortest distances
## between their [param centres] (a minimum spanning tree).
static func _tree(places: Array, centres: Dictionary[String, Vector2]) -> Array[PackedStringArray]:
	var pairs: Array[PackedStringArray] = []
	var joined: Array = [places[0]]
	while joined.size() < places.size():
		var best: float = INF
		var pair: PackedStringArray = PackedStringArray()
		for a: String in joined:
			for b: String in places:
				if joined.has(b):
					continue
				var d: float = centres.get(a, Vector2.ZERO).distance_to(centres.get(b, Vector2.ZERO))
				if d < best:
					best = d
					pair = PackedStringArray([a, b])
		joined.append(pair[1])
		pairs.append(pair)
	return pairs
