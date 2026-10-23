class_name SingleLine
extends RefCounted
## The consumer unit (rozváděč RD1) of a residential installation as its
## single-line diagram (jednopólové schéma), as Czech projects draw it: the
## supply through the main switch onto busbars L1, L2, L3 and N, and the
## outgoing circuits hanging from the busbars in columns, left to right. A
## column is a circuit (its breaker, RCBO or AFDD and what it feeds) or a
## group: a device with circuits and other groups under it (an RCD with
## its circuits, a 30 mA RCD under a selective 300 mA one, breakers under a
## breaker): any protective device heads one once something is put under it. The
## phases and the N poles of the devices are drawn; N and PE are wired all
## the same. No nodes.
##
## Every circuit has a number ([member Feeder.number], its cable's too). A
## circuit is made on the floor plan by putting parts on it, before anything
## protects it: it waits ([member waiting]) until a breaker, RCBO or AFDD is
## given it in the consumer unit ([method assign]).
##
## The parts are components of the document's circuit; the diagram keeps
## their order, phases and groups and what each circuit feeds, and wires
## them all ([method wire]: every wire of the document is made here, none is
## drawn by hand). The supply points, the main switch [constant MAIN] (while
## the diagram has one, [member main_switch]) and the ripple control
## contacts [constant HDO] are made and kept by it.

## The main switch: four poles, L1 L2 L3 and N.
const MAIN: String = "QB1"
## The contactor switched by the ripple control signal (HDO, low tariff):
## a contact of it in each circuit switched by it.
const HDO: String = "QA1"
## Supply points it makes, the conductor of each.
const SUPPLIES: PackedStringArray = ["L1", "L2", "L3", "N", "PE"]
## Main switch rating written beside it (A).
const MAIN_RATING: float = 63.0
## Supply cable when none is set.
const SUPPLY_CABLE: String = "CYKY-J 5×10"
## Cables are worked out as run this high in the wall (m: in the
## installation zone under a 2.6 m ceiling, ČSN 33 2130), with a reserve.
const ZONE_HEIGHT: float = 2.4
const CABLE_RESERVE: float = 1.1
## The consumer unit's middle is this high (m); a floor this much over the one under it.
const UNIT_HEIGHT: float = 1.5
const FLOOR_HEIGHT: float = 3.0
## Resistivity of copper at 70 °C, the conductor's working temperature (Ω·mm²/m).
const COPPER: float = 0.0225
## Voltage drop allowed from the consumer unit (%): lighting, the rest
## (ČSN 33 2000-5-52, an installation fed from the public LV network).
const LIGHTING_DROP: float = 3.0
const OTHER_DROP: float = 5.0
## Loop impedance of the supply up to the consumer unit when none is set (Ω).
const SUPPLY_IMPEDANCE: float = 0.4


## An outgoing circuit: its protective device and the parts it feeds.
class Feeder extends RefCounted:
	## Its number in the installation (from 1; its cable is -WD and the
	## number), 0 while none is given yet.
	var number: int = 0
	## Its circuit breaker, RCBO or AFDD ("" while it waits for one).
	var device: String = ""
	## Phase 1-3 its first pole is on (a three-pole device takes all three).
	var phase: int = 1
	## The parts it feeds: socket outlets, luminaires, appliances, and the
	## light switches it feeds the luminaires through.
	var loads: PackedStringArray = PackedStringArray()
	## Where it goes, as written under it ("" for the kind of its first part).
	var destination: String = ""
	## Room on the floor plan it goes to ("" for none).
	var room: String = ""
	## Its cable ("" for one that suits its device's rating).
	var cable: String = ""
	## Switched by the ripple control contactor [constant HDO] (low tariff).
	var hdo: bool = false

	func _init(p_device: String = "", p_phase: int = 1) -> void:
		device = p_device
		phase = p_phase

	func to_data() -> Dictionary:
		var d: Dictionary = {"device": device, "phase": phase}
		if number > 0:
			d["number"] = number
		if not loads.is_empty():
			d["loads"] = Array(loads)
		if not destination.is_empty():
			d["destination"] = destination
		if not room.is_empty():
			d["room"] = room
		if not cable.is_empty():
			d["cable"] = cable
		if hdo:
			d["hdo"] = true
		return d

	static func from_data(d: Dictionary) -> Feeder:
		var raw_phase: Variant = d.get("phase", 1)
		var f: Feeder = Feeder.new(str(d.get("device", "")), clampi(int(raw_phase) if raw_phase is float or raw_phase is int else 1, 1, 3))
		var raw_number: Variant = d.get("number", 0)
		f.number = maxi(int(raw_number), 0) if raw_number is float or raw_number is int else 0
		var raw: Variant = d.get("loads", [])
		if raw is Array:
			for load: Variant in raw:
				if load is String and not f.loads.has(load):
					f.loads.append(load)
		f.destination = str(d.get("destination", "")) if d.get("destination", "") is String else ""
		f.room = str(d.get("room", "")) if d.get("room", "") is String else ""
		f.cable = str(d.get("cable", "")) if d.get("cable", "") is String else ""
		f.hdo = d.get("hdo", false) == true
		return f


## A device with what is under it.
class Group extends RefCounted:
	## The RCD, or the breaker, RCBO or AFDD, at its head.
	var device: String = ""
	## Phase of a device of one phase (one of three takes all three).
	var phase: int = 1
	## Its circuits and the groups under it, left to right: [SingleLine.Feeder]
	## or [SingleLine.Group].
	var items: Array[RefCounted] = []

	func _init(p_device: String = "", p_phase: int = 1) -> void:
		device = p_device
		phase = p_phase

	func to_data() -> Dictionary:
		return {"device": device, "phase": phase, "feeders": SingleLine.list_data(items)}

	static func from_data(d: Dictionary) -> Group:
		var raw_phase: Variant = d.get("phase", 1)
		var g: Group = Group.new(str(d.get("device", "")), clampi(int(raw_phase) if raw_phase is float or raw_phase is int else 1, 1, 3))
		g.items = SingleLine.list_from_data(d.get("feeders", []))
		return g


## The columns left to right: [SingleLine.Feeder] or [SingleLine.Group].
var columns: Array[RefCounted] = []
## Circuits made on the floor plan that nothing protects yet (no device),
## by number.
var waiting: Array[Feeder] = []
## The supply comes in through the main switch [constant MAIN] (else
## straight onto the busbars).
var main_switch: bool = true
## The supply cable written at the incoming side ("" for [constant SUPPLY_CABLE]).
var supply_cable: String = ""
## A surge protective device (SPD) on the busbars to PE (drawn only).
var spd: bool = true
## The fault loop impedance of the supply at the consumer unit, Ze (Ω).
var supply_impedance: float = SUPPLY_IMPEDANCE


func is_empty() -> bool:
	return columns.is_empty() and waiting.is_empty() and main_switch and supply_cable.is_empty() and spd and is_equal_approx(supply_impedance, SUPPLY_IMPEDANCE)


# --- Design checks --------------------------------------------------------------------

## Length of circuit [param f]'s cable (m), from the plan: from the consumer
## unit along the walls to everything it feeds (the shortest tree over them,
## across and up and down, run at [constant ZONE_HEIGHT], each part's drop
## from there and a floor's height between floors), with
## [constant CABLE_RESERVE]; -1 when the unit or none of its parts is on a plan.
func cable_length(f: Feeder, doc: SchematicDocument) -> float:
	var unit_floor: int = doc.floor_of(FloorPlan.UNIT)
	if unit_floor < 0:
		return -1.0
	# Each point: where it is (m), its floor, its drop from the zone.
	var points: Array[Vector3] = [Vector3(doc.floors[unit_floor].parts[FloorPlan.UNIT].x, doc.floors[unit_floor].parts[FloorPlan.UNIT].y, unit_floor)]
	var drops: PackedFloat32Array = PackedFloat32Array([absf(ZONE_HEIGHT - UNIT_HEIGHT)])
	for load: String in f.loads:
		var on: int = doc.floor_of(load)
		var c: CircuitComponent = doc.circuit.get_component(load)
		if on < 0 or c == null:
			continue
		var at: Vector2 = doc.floors[on].parts[load]
		points.append(Vector3(at.x, at.y, on))
		var height: Variant = c.get("height")
		drops.append(absf(ZONE_HEIGHT - float(height)) if height != null else 0.0)
	if points.size() < 2:
		return -1.0
	# Prim's tree over them.
	var length: float = 0.0
	var joined: Array[bool] = [true]
	var best: PackedFloat32Array = PackedFloat32Array()
	for i: int in points.size():
		if i > 0:
			joined.append(false)
		best.append(_run(points[0], points[i]))
	for _step: int in points.size() - 1:
		var next: int = -1
		for i: int in points.size():
			if not joined[i] and (next < 0 or best[i] < best[next]):
				next = i
		joined[next] = true
		length += best[next]
		for i: int in points.size():
			if not joined[i]:
				best[i] = minf(best[i], _run(points[next], points[i]))
	for drop: float in drops:
		length += drop
	return length * CABLE_RESERVE


## A cable's run between two points (x, y, floor): along the walls' directions, a floor's height a floor.
static func _run(a: Vector3, b: Vector3) -> float:
	return absf(a.x - b.x) + absf(a.y - b.y) + absf(a.z - b.z) * FLOOR_HEIGHT


## Cross-section of a cable's conductors written as "CYKY-J 3×2,5" (mm²), 0 when it is not there.
static func cable_section(text: String) -> float:
	var found: RegExMatch = RegEx.create_from_string("[×x]\\s*([0-9]+(?:[.,][0-9]+)?)").search(text)
	return found.get_string(1).replace(",", ".").to_float() if found != null else 0.0


## The rated current and characteristic letter of circuit [param f]'s device.
static func _rating(f: Feeder, circuit: Circuit) -> Dictionary:
	var c: CircuitComponent = circuit.get_component(f.device)
	if c is CircuitBreaker:
		return {"current": (c as CircuitBreaker).rated_current, "magnetic": TripCurve.MAGNETIC[(TripCurve.Kind.BREAKER_B + (c as CircuitBreaker).characteristic) as TripCurve.Kind]}
	if c is MotorBreaker:
		return {"current": (c as MotorBreaker).rated_current, "magnetic": TripCurve.MAGNETIC[(TripCurve.Kind.BREAKER_B + (c as MotorBreaker).characteristic) as TripCurve.Kind]}
	return {"current": 0.0, "magnetic": 5.0}


## Voltage drop of circuit [param f] at its device's rated current over
## [param length] m of its cable (%): two conductors of 230 V, or three
## phases of 400 V; -1 when the length or the cable is not known.
func voltage_drop(f: Feeder, doc: SchematicDocument, length: float) -> float:
	var section: float = cable_section(cable_text(f, doc.circuit))
	if length < 0.0 or section <= 0.0:
		return -1.0
	var current: float = _rating(f, doc.circuit)["current"]
	if phases_of(f, doc.circuit).size() >= 3:
		return sqrt(3.0) * length * current * COPPER / section / 400.0 * 100.0
	return 2.0 * length * current * COPPER / section / 230.0 * 100.0


## The voltage drop allowed circuit [param f] (%): [constant LIGHTING_DROP]
## for one feeding lighting alone, else [constant OTHER_DROP].
func drop_limit(f: Feeder, circuit: Circuit) -> float:
	for load: String in f.loads:
		var c: CircuitComponent = circuit.get_component(load)
		if not (c is Luminaire or c is LightSwitch):
			return OTHER_DROP
	return LIGHTING_DROP if not f.loads.is_empty() else OTHER_DROP


## The fault loop impedance at the far end of circuit [param f] over
## [param length] m (Ω): the supply's and its phase and PE conductors'; -1
## when not known.
func loop_impedance(f: Feeder, doc: SchematicDocument, length: float) -> float:
	var section: float = cable_section(cable_text(f, doc.circuit))
	if length < 0.0 or section <= 0.0:
		return -1.0
	return supply_impedance + 2.0 * length * COPPER / section


## Whether a fault at the far end of circuit [param f] trips its device's
## magnetic release at once (within 0.4 s): 230 V over the loop impedance
## at least its multiple of the rated current.
func disconnects_in_time(f: Feeder, doc: SchematicDocument, length: float) -> bool:
	var z: float = loop_impedance(f, doc, length)
	var rating: Dictionary = _rating(f, doc.circuit)
	return z > 0.0 and 230.0 / z >= float(rating["current"]) * float(rating["magnetic"])


# --- Finding things -------------------------------------------------------------------

## Whether [param c] heads a group even with nothing under it: an RCD
## without overcurrent release (any protective device heads one with
## something under it).
static func heads_group(c: CircuitComponent) -> bool:
	return c is ResidualCurrentDevice and not (c as ResidualCurrentDevice).overcurrent


## Whether [param c] protects a circuit of its own: a circuit breaker, an
## RCBO or an AFDD.
static func protects_circuit(c: CircuitComponent) -> bool:
	return c is CircuitBreaker or (c is MotorBreaker and not heads_group(c))


## Whether [param c] is a part a circuit can feed (a light switch: feed the
## luminaires through).
static func is_load(c: CircuitComponent) -> bool:
	return c is SocketOutlet or c is Luminaire or c is Appliance or c is LightSwitch


## The first part circuit [param f] feeds that is not a light switch (what
## the diagram shows at its end), or null.
static func end_part(f: Feeder, circuit: Circuit) -> CircuitComponent:
	for designation: String in f.loads:
		var c: CircuitComponent = circuit.get_component(designation)
		if c != null and not (c is LightSwitch):
			return c
	return null


## How many parts circuit [param f] feeds, its light switches left out.
static func end_count(f: Feeder, circuit: Circuit) -> int:
	var n: int = 0
	for designation: String in f.loads:
		if not (circuit.get_component(designation) is LightSwitch):
			n += 1
	return n


## Tag of part [param designation] as the floor plan writes it at a socket
## or appliance: "Z" and its circuit's cable number, a dot and its place
## among the sockets and appliances of that circuit ("Z 6.1"); "" when no
## circuit feeds it.
func tag(designation: String, circuit: Circuit) -> String:
	var f: Feeder = feeder_feeding(designation)
	if f == null:
		return ""
	var n: int = 0
	for load: String in f.loads:
		var c: CircuitComponent = circuit.get_component(load)
		if c is SocketOutlet or c is Appliance:
			n += 1
		if load == designation:
			return "Z %d.%d" % [cable_number(f), n]
	return ""


## Every circuit and group, left to right, a group before what is under it.
func items() -> Array[RefCounted]:
	var list: Array[RefCounted] = []
	_collect(columns, list)
	return list


static func _collect(from: Array[RefCounted], list: Array[RefCounted]) -> void:
	for item: RefCounted in from:
		list.append(item)
		if item is Group:
			_collect((item as Group).items, list)


## Every circuit, left to right.
func feeders() -> Array[Feeder]:
	var list: Array[Feeder] = []
	for item: RefCounted in items():
		if item is Feeder:
			list.append(item as Feeder)
	return list


## Every group, left to right, a group before the ones under it.
func groups() -> Array[Group]:
	var list: Array[Group] = []
	for item: RefCounted in items():
		if item is Group:
			list.append(item as Group)
	return list


## Device of circuit or group [param item].
static func device_of(item: RefCounted) -> String:
	return (item as Group).device if item is Group else (item as Feeder).device


## The circuit or group of device [param designation], or null.
func item_of(designation: String) -> RefCounted:
	for item: RefCounted in items():
		if device_of(item) == designation:
			return item
	return null


## The circuit of protective device [param designation], or null.
func feeder_of(designation: String) -> Feeder:
	for f: Feeder in feeders():
		if f.device == designation:
			return f
	return null


## The circuit feeding part [param designation] (protected or waiting), or null.
func feeder_feeding(designation: String) -> Feeder:
	for f: Feeder in circuits():
		if f.loads.has(designation):
			return f
	return null


## Every circuit, protected or waiting, by number.
func circuits() -> Array[Feeder]:
	var list: Array[Feeder] = feeders()
	list.append_array(waiting)
	list.sort_custom(func(a: Feeder, b: Feeder) -> bool: return a.number < b.number)
	return list


## The circuit numbered [param number], or null.
func circuit_numbered(number: int) -> Feeder:
	for f: Feeder in circuits():
		if f.number == number:
			return f
	return null


## The smallest number no circuit has.
func next_number() -> int:
	var used: Dictionary[int, bool] = {}
	for f: Feeder in feeders():
		used[f.number] = true
	for f: Feeder in waiting:
		used[f.number] = true
	var n: int = 1
	while used.has(n):
		n += 1
	return n


## The waiting circuit of the smallest number, or null for none.
func first_waiting() -> Feeder:
	var best: Feeder = null
	for f: Feeder in waiting:
		if best == null or f.number < best.number:
			best = f
	return best


## Gives every circuit without a number (or with one another has) the next
## free one, in the order of the columns, then the waiting ones.
func _number_all() -> void:
	var seen: Dictionary[int, bool] = {}
	var missing: Array[Feeder] = []
	var all: Array[Feeder] = feeders()
	all.append_array(waiting)
	for f: Feeder in all:
		if f.number <= 0 or seen.has(f.number):
			missing.append(f)
		else:
			seen[f.number] = true
	var n: int = 1
	for f: Feeder in missing:
		while seen.has(n):
			n += 1
		f.number = n
		seen[n] = true


## The group of RCD [param designation], or null.
func group_of(designation: String) -> Group:
	for g: Group in groups():
		if g.device == designation:
			return g
	return null


## The group circuit or group [param item] is directly under, or null.
func group_holding(item: RefCounted) -> Group:
	for g: Group in groups():
		if g.items.has(item):
			return g
	return null


## The list [param item] is in: its group's items or the columns.
func list_holding(item: RefCounted) -> Array[RefCounted]:
	var g: Group = group_holding(item)
	return g.items if g != null else columns


## How many groups [param item] is under.
func depth_of(item: RefCounted) -> int:
	var depth: int = 0
	var g: Group = group_holding(item)
	while g != null:
		depth += 1
		g = group_holding(g)
	return depth


## Whether [param item] is [param group] or under it.
func is_under(item: RefCounted, group: Group) -> bool:
	var at: RefCounted = item
	while at != null:
		if at == group:
			return true
		at = group_holding(at)
	return false


## Column of device [param designation] (a circuit's or a group's, or the
## group's it is under), -1 for none.
func column_of(designation: String) -> int:
	var item: RefCounted = item_of(designation)
	if item == null:
		return -1
	var g: Group = group_holding(item)
	while g != null:
		item = g
		g = group_holding(g)
	return columns.find(item)


## The smallest rated residual current protecting circuit [param f] (its
## RCBO's or of a group it is under), amperes; INF for none.
func residual_protection(f: Feeder, circuit: Circuit) -> float:
	var best: float = INF
	var rcbo: ResidualCurrentDevice = circuit.get_component(f.device) as ResidualCurrentDevice
	if rcbo != null:
		best = rcbo.residual_rating
	var g: Group = group_holding(f)
	while g != null:
		var rcd: ResidualCurrentDevice = circuit.get_component(g.device) as ResidualCurrentDevice
		if rcd != null:
			best = minf(best, rcd.residual_rating)
		g = group_holding(g)
	return best


## Whether circuit [param f] lacks the additional protection of an RCD of
## 30 mA or less that ČSN 33 2000-4-41 asks for every circuit an ordinary
## person (laik) can reach: it feeds something and none protects it.
func lacks_rcd(f: Feeder, circuit: Circuit) -> bool:
	return not f.loads.is_empty() and residual_protection(f, circuit) > 0.03 + 1e-6


## Whether [param designation] is in the diagram (a device or a part fed).
func has(designation: String) -> bool:
	return column_of(designation) >= 0 or feeder_feeding(designation) != null


## Whether circuit [param f] is switched by the ripple control contactor:
## set so, and a circuit of its own (not in a group).
func switched_by_hdo(f: Feeder) -> bool:
	return f.hdo and group_holding(f) == null


## Number of the cable of circuit [param f]: the circuit's number.
func cable_number(f: Feeder) -> int:
	return f.number


## The cable of circuit [param f] as written: the one set, else one that
## suits its device in [param circuit] (3 or 5 cores of 1.5 mm² up to 10 A,
## 2.5 mm² up to 16 A, 4 mm² up to 25 A, 6 mm² beyond).
static func cable_text(f: Feeder, circuit: Circuit) -> String:
	if not f.cable.is_empty():
		return f.cable
	var c: CircuitComponent = circuit.get_component(f.device)
	var rating: float = 16.0
	var cores: int = 3
	if c is CircuitBreaker:
		rating = (c as CircuitBreaker).rated_current
	elif c is MotorBreaker:
		rating = (c as MotorBreaker).rated_current
		if (c as MotorBreaker).poles > 2:
			cores = 5
	var section: String = "1,5" if rating <= 10.0 else "2,5" if rating <= 16.0 else "4" if rating <= 25.0 else "6"
	return "CYKY-J %d×%s" % [cores, section]


## The phases circuit [param f] takes, in pole order, as fed by [param circuit]
## (its device [param device] when not in it yet).
func phases_of(f: Feeder, circuit: Circuit, device: CircuitComponent = null) -> PackedInt32Array:
	var c: CircuitComponent = device if device != null else circuit.get_component(f.device)
	var poles: int = _poles(c) if c != null else 1
	var list: PackedInt32Array = PackedInt32Array()
	# Three poles take L1, L2 and L3 in turn whatever the phase set.
	var first: int = 1 if poles >= 3 else f.phase
	for k: int in poles:
		list.append((first - 1 + k) % 3 + 1)
	return list


## The phase a new circuit is best put on: the one feeding the fewest yet.
func next_phase(circuit: Circuit) -> int:
	var counts: PackedInt32Array = PackedInt32Array([0, 0, 0])
	for f: Feeder in feeders():
		for ph: int in phases_of(f, circuit):
			counts[ph - 1] += 1
	var best: int = 0
	for i: int in 3:
		if counts[i] < counts[best]:
			best = i
	return best + 1


# --- Edits ----------------------------------------------------------------------------

## Adds [param c] to [param doc] (if it is not there yet) and to the diagram:
## the main switch [constant MAIN], an RCD as a new group, a protective
## device as a new circuit (waiting circuit [param number] when there is
## one, else a new one), at [param index] of the columns or, with
## [param into] (an RCD's designation), of that group; a part fed into
## circuit [param feeder] (a device's designation). Rewires. Returns false
## when it does not fit there (nothing changed then).
func add(doc: SchematicDocument, c: CircuitComponent, index: int, into: String = "", feeder: String = "", number: int = 0) -> bool:
	var placed: bool = false
	if is_main(c):
		if main_switch:
			return false
		main_switch = true
		placed = true
	elif heads_group(c) or protects_circuit(c):
		var parent: Group = null
		if not into.is_empty():
			if not can_hold(into) or not fits_poles(doc, _poles(c), into):
				return false
			parent = open_group(into)
		var item: RefCounted = Group.new(c.designation)
		if not heads_group(c):
			var f: Feeder = _waiting_numbered(number)
			if f != null:
				waiting.erase(f)
			else:
				f = Feeder.new()
				f.number = next_number()
			f.device = c.designation
			item = f
		var list: Array[RefCounted] = parent.items if parent != null else columns
		list.insert(clampi(index, 0, list.size()), item)
		_set_phase_of(item, _phase_under(doc, parent, c))
		placed = true
	elif is_load(c):
		var f: Feeder = feeder_of(feeder)
		if f == null:
			return false
		f.loads.append(c.designation)
		placed = true
	if not placed:
		return false
	if doc.circuit.get_component(c.id) == null:
		doc.add(c, hidden_cell(doc))
	wire(doc)
	return true


## Whether [param c] is the main switch.
static func is_main(c: CircuitComponent) -> bool:
	return c is CamSwitch and c.designation == MAIN


## The waiting circuit numbered [param number], or null.
func _waiting_numbered(number: int) -> Feeder:
	for f: Feeder in waiting:
		if f.number == number:
			return f
	return null


## Puts part [param designation] onto circuit [param number] (made, waiting
## for its protection, when no circuit has that number yet), off the circuit
## it was on; 0 takes it off any. Does not rewire.
func feed(designation: String, number: int) -> void:
	var old: Feeder = feeder_feeding(designation)
	if old != null:
		old.loads.remove_at(old.loads.find(designation))
	if number <= 0:
		return
	var f: Feeder = circuit_numbered(number)
	if f == null:
		f = Feeder.new()
		f.number = number
		waiting.append(f)
	f.loads.append(designation)


## Circuit [param number] (a waiting one) is protected by breaker, RCBO or
## AFDD [param device] from now on, in its place in the diagram: the circuit
## the device protected waits in its stead when it feeds something; with
## [param number] 0 (or none waiting so) the device protects a new circuit,
## feeding nothing. Rewires. Returns false when nothing changed.
func assign(doc: SchematicDocument, device: String, number: int) -> bool:
	var old: Feeder = feeder_of(device)
	if old == null or old.number == number:
		return false
	var f: Feeder = _waiting_numbered(number)
	if f == null:
		if old.loads.is_empty():
			return false
		f = Feeder.new()
		f.number = next_number()
	else:
		waiting.erase(f)
	var list: Array[RefCounted] = list_holding(old)
	list[list.find(old)] = f
	f.device = device
	f.phase = old.phase
	old.device = ""
	if not old.loads.is_empty() or not old.destination.is_empty():
		waiting.append(old)
	wire(doc)
	return true


## Whether something can be put under device [param designation]: a
## group's head, or a circuit that feeds nothing.
func can_hold(designation: String) -> bool:
	var item: RefCounted = item_of(designation)
	return item is Group or (item is Feeder and (item as Feeder).loads.is_empty())


## The group of device [param designation], a circuit feeding nothing made
## one (its head); null when it cannot hold anything.
func open_group(designation: String) -> Group:
	var item: RefCounted = item_of(designation)
	if item is Group:
		return item as Group
	if not can_hold(designation):
		return null
	var f: Feeder = item as Feeder
	var g: Group = Group.new(f.device, f.phase)
	var list: Array[RefCounted] = list_holding(f)
	list[list.find(f)] = g
	return g


## Whether a device taking [param phases] phases can go under device
## [param head]: under one of one phase only what takes one phase.
func fits_poles(doc: SchematicDocument, phases: int, head: String) -> bool:
	return not _single_phase(doc.circuit, head) or phases <= 1


## Whether device [param head] takes one phase (what is under it on its phase).
static func _single_phase(circuit: Circuit, head: String) -> bool:
	var c: CircuitComponent = circuit.get_component(head)
	return c == null or _poles(c) <= 1


## How many phases device [param c] takes.
static func phase_count(c: CircuitComponent) -> int:
	return _poles(c)


## The phase device [param c] takes under [param parent] (null: the busbars):
## the phase of a device of one phase, L1 for three poles, else the least loaded.
func _phase_under(doc: SchematicDocument, parent: Group, c: CircuitComponent) -> int:
	if parent != null and _single_phase(doc.circuit, parent.device):
		return parent.phase
	return 1 if _poles(c) >= 3 else next_phase(doc.circuit)


## Puts [param item] on [param phase], with what is under it.
func _set_phase_of(item: RefCounted, phase: int) -> void:
	if item is Feeder:
		(item as Feeder).phase = phase
		return
	(item as Group).phase = phase
	for sub: RefCounted in (item as Group).items:
		_set_phase_of(sub, phase)


## Moves the circuit or group of device [param designation] to [param index]
## of the columns or, with [param into] (an RCD's designation), of that
## group's items, counted without it. Rewires. Returns false when it does
## not fit there.
func move(doc: SchematicDocument, designation: String, index: int, into: String = "") -> bool:
	return move_many(doc, PackedStringArray([designation]), index, into)


## Moves the circuits and groups of devices [param designations] together,
## in their order, to [param index] of the columns or of group [param into]'s
## items, counted without them (one under another moved goes along with
## it). A group never goes under itself. Rewires. Returns false when one
## does not fit there (nothing changed then).
func move_many(doc: SchematicDocument, designations: PackedStringArray, index: int, into: String = "") -> bool:
	var chosen: Array[RefCounted] = []
	for designation: String in designations:
		var item: RefCounted = item_of(designation)
		if item != null and not chosen.has(item):
			chosen.append(item)
	var moving: Array[RefCounted] = []
	for item: RefCounted in items():
		if not chosen.has(item):
			continue
		var g: Group = group_holding(item)
		var along: bool = false
		while g != null:
			along = along or chosen.has(g)
			g = group_holding(g)
		if not along:
			moving.append(item)
	if moving.is_empty():
		return false
	var parent: Group = null
	if not into.is_empty():
		var target: RefCounted = item_of(into)
		if not can_hold(into):
			return false
		for item: RefCounted in moving:
			if item == target or (item is Group and is_under(target, item as Group)) or not fits_poles(doc, _poles(doc.circuit.get_component(device_of(item))), into):
				return false
		parent = open_group(into)
	for item: RefCounted in moving:
		list_holding(item).erase(item)
	var list: Array[RefCounted] = parent.items if parent != null else columns
	var at: int = clampi(index, 0, list.size())
	for k: int in moving.size():
		list.insert(at + k, moving[k])
		if parent != null and _single_phase(doc.circuit, parent.device):
			_set_phase_of(moving[k], parent.phase)
	wire(doc)
	return true


## Puts circuit or group [param designation] on phase [param phase] (what is
## under a device of one phase along with it; under one it stays on its
## phase). Rewires.
func set_phase(doc: SchematicDocument, designation: String, phase: int) -> void:
	phase = clampi(phase, 1, 3)
	var item: RefCounted = item_of(designation)
	if item == null:
		return
	var holder: Group = group_holding(item)
	if holder != null and _single_phase(doc.circuit, holder.device):
		return
	if item is Group:
		if _single_phase(doc.circuit, (item as Group).device):
			_set_phase_of(item, phase)
		else:
			(item as Group).phase = phase
	else:
		(item as Feeder).phase = phase
	wire(doc)


## Leaves [param designation] out of the diagram (its component is gone): the
## main switch (the supply straight onto the busbars), a group's circuits
## and groups stay where it was, a circuit feeding something waits for
## another device, a part fed is no longer fed.
func remove(designation: String) -> void:
	if designation == MAIN:
		main_switch = false
		return
	var item: RefCounted = item_of(designation)
	if item != null:
		var list: Array[RefCounted] = list_holding(item)
		var at: int = list.find(item)
		list.remove_at(at)
		if item is Feeder and (not (item as Feeder).loads.is_empty() or not (item as Feeder).destination.is_empty()):
			(item as Feeder).device = ""
			waiting.append(item as Feeder)
		if item is Group:
			var sub: Array[RefCounted] = (item as Group).items
			for k: int in sub.size():
				list.insert(at + k, sub[k])
		return
	var fed: Feeder = feeder_feeding(designation)
	if fed != null:
		var at: int = fed.loads.find(designation)
		fed.loads.remove_at(at)


## Device or part [param old_designation] is now [param new_designation].
func rename(old_designation: String, new_designation: String) -> void:
	for g: Group in groups():
		if g.device == old_designation:
			g.device = new_designation
	for f: Feeder in circuits():
		if f.device == old_designation and not old_designation.is_empty():
			f.device = new_designation
		var at: int = f.loads.find(old_designation)
		if at >= 0:
			f.loads[at] = new_designation


## Drops what [param circuit] no longer has, and parts of a kind that no
## longer fits (a breaker turned into an RCD's group head and the like).
func prune(circuit: Circuit) -> void:
	for f: Feeder in circuits():
		for i: int in range(f.loads.size() - 1, -1, -1):
			var load: CircuitComponent = circuit.get_component(f.loads[i])
			if load == null or not is_load(load):
				f.loads.remove_at(i)
	# A waiting circuit feeding nothing is no more.
	for i: int in range(waiting.size() - 1, -1, -1):
		if waiting[i].loads.is_empty():
			waiting.remove_at(i)
	var stale: PackedStringArray = PackedStringArray()
	for item: RefCounted in items():
		var c: CircuitComponent = circuit.get_component(device_of(item))
		if not (heads_group(c) or protects_circuit(c) if item is Group else protects_circuit(c)):
			stale.append(device_of(item))
	for designation: String in stale:
		remove(designation)
	# A breaker with nothing left under it is a circuit again.
	for g: Group in groups():
		if g.items.is_empty() and not heads_group(circuit.get_component(g.device)):
			var list: Array[RefCounted] = list_holding(g)
			list[list.find(g)] = Feeder.new(g.device, g.phase)
	_number_all()


## A cell of the (never shown) schematic page for a new part, clear of the others.
static func hidden_cell(doc: SchematicDocument) -> Vector2i:
	return Vector2i(6 * doc.circuit.get_components().size(), 0)


## Whether [param c] switches N too: an RCD, RCBO or AFDD, a breaker of
## four poles (three phases and N).
static func has_n_pole(c: CircuitComponent) -> bool:
	return c is ResidualCurrentDevice or c is ArcFaultDevice or (c is MotorBreaker and (c as MotorBreaker).poles == 4)


static func _poles(c: CircuitComponent) -> int:
	if c is ResidualCurrentDevice:
		return maxi((c as ResidualCurrentDevice).poles - 1, 1)
	if c is ArcFaultDevice:
		return 1
	if c is MotorBreaker:
		return mini((c as MotorBreaker).poles, 3)
	return 1


# --- Wiring ---------------------------------------------------------------------------

## Makes every wire of [param doc] anew from the diagram: the supply points
## through the main switch onto the busbars, each group's RCD from them and
## its circuits from its outputs, each circuit's device and (switched by
## the ripple control contact where it is) the parts it feeds: their phase
## conductors on its outputs in pole order, N on the busbar's (or its RCD's
## or its own N pole's) N, PE on PE. Makes the supply points, the main
## switch and the ripple control contacts the diagram needs.
func wire(doc: SchematicDocument) -> void:
	prune(doc.circuit)
	_make_fixed_parts(doc)
	for i: int in range(doc.get_wire_count() - 1, -1, -1):
		doc.remove_wire(i)
	# The busbars: the main switch's outputs, else the supply points.
	var bus: Dictionary[int, String] = {1: SUPPLIES[0], 2: SUPPLIES[1], 3: SUPPLIES[2]}
	var n_bus: String = SUPPLIES[3]
	var main: CircuitComponent = doc.circuit.get_component(MAIN)
	if main != null:
		var main_keys: PackedStringArray = main.get_terminal_keys()
		for k: int in 4:
			doc.connect_terminals(SUPPLIES[k], main_keys[2 * k])
		bus = {1: main_keys[1], 2: main_keys[3], 3: main_keys[5]}
		n_bus = main_keys[7]
	var hdo_contacts: Array[CircuitComponent] = []
	for c: CircuitComponent in doc.circuit.get_components():
		if c.designation == HDO and c is LatchingSwitch:
			hdo_contacts.append(c)
	var hdo_used: int = 0
	_joined.clear()
	_live.clear()
	_switched = _switched_luminaires(doc)
	_wire_list(doc, columns, bus, n_bus, hdo_contacts, 0)
	_wire_lighting(doc)


## Wires circuits and groups [param list] from busbars [param bus] (phase ->
## terminal key) and N [param n_bus]: a group's RCD from them and what is
## under it from its outputs. Returns how many ripple control contacts are used.
func _wire_list(doc: SchematicDocument, list: Array[RefCounted], bus: Dictionary[int, String], n_bus: String, hdo_contacts: Array[CircuitComponent], hdo_used: int) -> int:
	for item: RefCounted in list:
		if item is Feeder:
			hdo_used = _wire_feeder(doc, item as Feeder, bus, n_bus, hdo_contacts, hdo_used)
			continue
		var g: Group = item as Group
		var head: CircuitComponent = doc.circuit.get_component(g.device)
		var keys: PackedStringArray = head.get_terminal_keys()
		var sub: Dictionary[int, String] = {}
		var phases: int = _poles(head)
		for k: int in phases:
			var ph: int = g.phase if phases == 1 else k + 1
			if bus.has(ph):
				doc.connect_terminals(bus[ph], keys[2 * k])
			sub[ph] = keys[2 * k + 1]
		# Through its own N pole (an RCD's, an AFDD's), else straight on.
		var n_sub: String = n_bus
		if has_n_pole(head):
			doc.connect_terminals(n_bus, keys[2 * phases])
			n_sub = keys[2 * phases + 1]
		hdo_used = _wire_list(doc, g.items, sub, n_sub, hdo_contacts, hdo_used)
	return hdo_used


## Wires circuit [param f] from busbars [param bus] (phase -> terminal key)
## and N [param n_bus]; returns how many ripple control contacts are used.
func _wire_feeder(doc: SchematicDocument, f: Feeder, bus: Dictionary[int, String], n_bus: String, hdo_contacts: Array[CircuitComponent], hdo_used: int) -> int:
	var device: CircuitComponent = doc.circuit.get_component(f.device)
	var keys: PackedStringArray = device.get_terminal_keys()
	var phases: PackedInt32Array = phases_of(f, doc.circuit)
	var outputs: PackedStringArray = PackedStringArray()
	for k: int in phases.size():
		if bus.has(phases[k]):
			doc.connect_terminals(bus[phases[k]], keys[2 * k])
		outputs.append(keys[2 * k + 1])
	var n_out: String = n_bus
	if has_n_pole(device):
		# Its own N pole.
		doc.connect_terminals(n_bus, keys[2 * phases.size()])
		n_out = keys[2 * phases.size() + 1]
	if switched_by_hdo(f) and hdo_used < hdo_contacts.size() and not outputs.is_empty():
		var contact: PackedStringArray = hdo_contacts[hdo_used].get_terminal_keys()
		doc.connect_terminals(outputs[0], contact[0])
		outputs[0] = contact[1]
		hdo_used += 1
	if not outputs.is_empty():
		_live[f.device] = outputs[0]
	for load: String in f.loads:
		var part: CircuitComponent = doc.circuit.get_component(load)
		# Switches are wired with the lighting; a switched luminaire gets
		# its phase through them.
		if part is LightSwitch:
			continue
		var names: PackedStringArray = part.get_terminal_names()
		var phase_index: int = 0
		for i: int in names.size():
			var key: String = "%s:%s" % [load, names[i]]
			if names[i] == "PE":
				doc.connect_terminals("PE", key)
			elif names[i] == "N":
				doc.connect_terminals(n_out, key)
			elif phase_index < outputs.size() and not _switched.has(load):
				doc.connect_terminals(outputs[phase_index], key)
				phase_index += 1
	return hdo_used


# --- Lighting ---------------------------------------------------------------------------

## While wiring: pairs joined (no wire twice), each circuit's phase out of
## its device (by device), the luminaires switched.
var _joined: Dictionary[String, bool] = {}
var _live: Dictionary[String, String] = {}
var _switched: Dictionary[String, bool] = {}


func _join(doc: SchematicDocument, a: String, b: String) -> void:
	if a.is_empty() or b.is_empty() or a == b:
		return
	var key: String = a + "|" + b if a < b else b + "|" + a
	if _joined.has(key):
		return
	_joined[key] = true
	doc.connect_terminals(a, b)


## The ways light switch [param sw] switches, by port: a one-way output
## {"common", "a"}, a two-way {"common", "a", "b"} (at rest on a), an
## intermediate {"through": [in 1, in 2, out 1, out 2]} (at rest in 1 to
## out 1). Only a switch's first pole is used.
static func switch_ports(sw: LightSwitch) -> Array[Dictionary]:
	var t: PackedStringArray = sw.get_terminal_keys()
	match sw.circuit:
		"4", "5":
			return [{"common": t[0], "a": t[1]}, {"common": t[0], "a": t[2]}]
		"6":
			return [{"common": t[0], "a": t[1], "b": t[2]}]
		"6/2":
			return [{"common": t[0], "a": t[2], "b": t[4]}]
		"5B":
			return [{"common": t[0], "a": t[1], "b": t[2]}, {"common": t[3], "a": t[4], "b": t[5]}]
		"7":
			return [{"through": [t[0], t[2], t[1], t[3]]}]
	return [{"common": t[0], "a": t[1]}]


## The lighting drawn on the plan as a graph: node "SF1#0" for port 0 of a
## switch, "EA1" for a luminaire, each with its neighbours.
static func lighting_graph(doc: SchematicDocument) -> Dictionary[String, PackedStringArray]:
	var graph: Dictionary[String, PackedStringArray] = {}
	var links: Array[FloorPlan.Link] = []
	for plan: FloorPlan in doc.floors:
		links.append_array(plan.links)
	for link: FloorPlan.Link in links:
		var ends: PackedStringArray = PackedStringArray()
		for end: String in [link.a, link.b]:
			var c: CircuitComponent = doc.circuit.get_component(end)
			if c is LightSwitch:
				var ports: int = switch_ports(c as LightSwitch).size()
				ends.append("%s#%d" % [end, clampi(link.port(end), 0, ports - 1)])
			elif c is Luminaire:
				ends.append(end)
		if ends.size() != 2 or ends[0] == ends[1]:
			continue
		for k: int in 2:
			var list: PackedStringArray = graph.get(ends[k], PackedStringArray())
			if not list.has(ends[1 - k]):
				list.append(ends[1 - k])
			graph[ends[k]] = list
	return graph


## Luminaires the lighting drawn on the plan switches (their phase comes
## through a switch).
func _switched_luminaires(doc: SchematicDocument) -> Dictionary[String, bool]:
	var result: Dictionary[String, bool] = {}
	var graph: Dictionary[String, PackedStringArray] = lighting_graph(doc)
	for group: PackedStringArray in _groups_of(graph, graph.keys()):
		var has_switch: bool = false
		for node: String in group:
			if node.contains("#"):
				has_switch = true
		if has_switch:
			for node: String in group:
				if not node.contains("#"):
					result[node] = true
	return result


## [param nodes] of [param graph] in groups joined by its edges (only those
## between nodes of [param nodes]).
static func _groups_of(graph: Dictionary[String, PackedStringArray], nodes: Array) -> Array[PackedStringArray]:
	var seen: Dictionary[String, bool] = {}
	var groups: Array[PackedStringArray] = []
	for start: String in nodes:
		if seen.has(start):
			continue
		var group: PackedStringArray = PackedStringArray()
		var queue: PackedStringArray = PackedStringArray([start])
		seen[start] = true
		while not queue.is_empty():
			var node: String = queue[0]
			queue.remove_at(0)
			group.append(node)
			for next: String in graph.get(node, PackedStringArray()):
				if nodes.has(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)
		groups.append(group)
	return groups


## Luminaires reached from [param node] through luminaires alone.
static func _lights_from(graph: Dictionary[String, PackedStringArray], node: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var queue: PackedStringArray = PackedStringArray()
	for next: String in graph.get(node, PackedStringArray()):
		if not next.contains("#"):
			queue.append(next)
	while not queue.is_empty():
		var light: String = queue[0]
		queue.remove_at(0)
		if found.has(light):
			continue
		found.append(light)
		for next: String in graph.get(light, PackedStringArray()):
			if not next.contains("#") and not found.has(next):
				queue.append(next)
	return found


## Wires the light switches and the luminaires they switch, as drawn on
## the plan: a one-way output from the circuit's phase to its luminaires;
## a staircase of two two-way switches (with intermediates between them)
## from the phase on the first's common through the travellers, crossed so
## that all at rest leave the light off, to the luminaires on the last's
## common (the end the luminaires are drawn to); the phase from the
## circuit of the first switch that has one.
func _wire_lighting(doc: SchematicDocument) -> void:
	var graph: Dictionary[String, PackedStringArray] = lighting_graph(doc)
	for group: PackedStringArray in _groups_of(graph, graph.keys()):
		var switch_nodes: PackedStringArray = PackedStringArray()
		for node: String in group:
			if node.contains("#"):
				switch_nodes.append(node)
		if switch_nodes.is_empty():
			continue
		var phase: String = ""
		for node: String in switch_nodes:
			var f: Feeder = feeder_feeding(node.get_slice("#", 0))
			if f != null and _live.has(f.device):
				phase = _live[f.device]
				break
		if phase.is_empty():
			for node: String in group:
				var f: Feeder = feeder_feeding(node.get_slice("#", 0))
				if f != null and _live.has(f.device):
					phase = _live[f.device]
					break
		var one_way: PackedStringArray = PackedStringArray()
		var chained: PackedStringArray = PackedStringArray()
		for node: String in switch_nodes:
			var port: Dictionary = _port(doc, node)
			if port.has("b") or port.has("through"):
				chained.append(node)
			else:
				one_way.append(node)
		for node: String in one_way:
			var port: Dictionary = _port(doc, node)
			_join(doc, phase, port["common"])
			for light: String in _lights_from(graph, node):
				_join(doc, port["a"], light + ":L")
		for chain: PackedStringArray in _groups_of(graph, Array(chained)):
			_wire_chain(doc, graph, chain, phase)


func _port(doc: SchematicDocument, node: String) -> Dictionary:
	var sw: LightSwitch = doc.circuit.get_component(node.get_slice("#", 0)) as LightSwitch
	var ports: Array[Dictionary] = switch_ports(sw)
	return ports[clampi(int(node.get_slice("#", 1)), 0, ports.size() - 1)]


## Wires a staircase [param chain] of two-way switches and intermediates.
func _wire_chain(doc: SchematicDocument, graph: Dictionary[String, PackedStringArray], chain: PackedStringArray, phase: String) -> void:
	var ends: PackedStringArray = PackedStringArray()
	var lights: PackedStringArray = PackedStringArray()
	for node: String in chain:
		var degree: int = 0
		for next: String in graph.get(node, PackedStringArray()):
			if chain.has(next):
				degree += 1
		if _port(doc, node).has("b") and degree <= 1:
			ends.append(node)
		for light: String in _lights_from(graph, node):
			if not lights.has(light):
				lights.append(light)
	if ends.size() == 1 and chain.size() == 1:
		# A two-way switch alone: as a one-way one.
		var port: Dictionary = _port(doc, ends[0])
		_join(doc, phase, port["common"])
		for light: String in lights:
			_join(doc, port["a"], light + ":L")
		return
	if ends.size() != 2:
		return
	# The last is the end the luminaires are drawn to.
	var last: String = ends[0]
	if _lights_from(graph, ends[0]).is_empty() and not _lights_from(graph, ends[1]).is_empty():
		last = ends[1]
	var first: String = ends[0] if last == ends[1] else ends[1]
	var path: PackedStringArray = _path(graph, chain, first, last)
	var first_port: Dictionary = _port(doc, first)
	_join(doc, phase, first_port["common"])
	var t1: String = first_port["a"]
	var t2: String = first_port["b"]
	for i: int in range(1, path.size() - 1):
		var port: Dictionary = _port(doc, path[i])
		if not port.has("through"):
			continue
		var through: Array = port["through"]
		_join(doc, t1, through[0])
		_join(doc, t2, through[1])
		t1 = through[2]
		t2 = through[3]
	var last_port: Dictionary = _port(doc, last)
	# Crossed: all at rest, the light is off.
	_join(doc, t1, last_port["b"])
	_join(doc, t2, last_port["a"])
	for light: String in lights:
		_join(doc, last_port["common"], light + ":L")


## The nodes from [param from] to [param to] within [param chain].
static func _path(graph: Dictionary[String, PackedStringArray], chain: PackedStringArray, from: String, to: String) -> PackedStringArray:
	var back: Dictionary[String, String] = {from: ""}
	var queue: PackedStringArray = PackedStringArray([from])
	while not queue.is_empty():
		var node: String = queue[0]
		queue.remove_at(0)
		if node == to:
			break
		for next: String in graph.get(node, PackedStringArray()):
			if chain.has(next) and not back.has(next):
				back[next] = node
				queue.append(next)
	var path: PackedStringArray = PackedStringArray()
	var at: String = to
	while not at.is_empty():
		path.insert(0, at)
		at = back.get(at, "")
	return path


## The supply points, the main switch (while the diagram has one) and one
## ripple control contact a circuit switched by it (made or taken away to match).
func _make_fixed_parts(doc: SchematicDocument) -> void:
	var conductors: Array[PowerSupply.Conductor] = [PowerSupply.Conductor.L, PowerSupply.Conductor.L2, PowerSupply.Conductor.L3, PowerSupply.Conductor.N, PowerSupply.Conductor.PE]
	for k: int in SUPPLIES.size():
		if doc.circuit.get_component(SUPPLIES[k]) == null:
			doc.add(PowerSupply.new(SUPPLIES[k], conductors[k]), hidden_cell(doc))
	var main: CircuitComponent = doc.circuit.get_component(MAIN)
	if main != null and (not main_switch or not (main is CamSwitch) or (main as CamSwitch).poles != 4):
		# Taken away without the diagram forgetting it.
		var had: bool = main_switch
		doc.remove_component(main.id)
		main_switch = had
		main = null
	if main == null and main_switch:
		doc.add(CamSwitch.new(MAIN, CamSwitch.Positions.OFF_ON, 4), hidden_cell(doc))
	var wanted: int = 0
	for f: Feeder in feeders():
		if switched_by_hdo(f):
			wanted += 1
	var have: Array[CircuitComponent] = []
	for c: CircuitComponent in doc.circuit.get_components():
		if c.designation == HDO and c is LatchingSwitch:
			have.append(c)
	for k: int in range(have.size() - 1, wanted - 1, -1):
		doc.remove_component(have[k].id)
	for k: int in range(have.size(), wanted):
		doc.add(LatchingSwitch.new(HDO, SwitchingElement.ContactType.NO, k + 1), hidden_cell(doc))


# --- Saving ---------------------------------------------------------------------------

## Circuits and groups [param list] saved, each with its "kind".
static func list_data(list: Array[RefCounted]) -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for item: RefCounted in list:
		var d: Dictionary = (item as Group).to_data() if item is Group else (item as Feeder).to_data()
		d["kind"] = "group" if item is Group else "circuit"
		data.append(d)
	return data


## Circuits and groups saved as [param raw]; damaged entries are left out.
static func list_from_data(raw: Variant) -> Array[RefCounted]:
	var list: Array[RefCounted] = []
	if not (raw is Array):
		return list
	for item: Variant in raw:
		if not (item is Dictionary):
			continue
		if (item as Dictionary).get("kind", "") == "group":
			list.append(Group.from_data(item))
		else:
			list.append(Feeder.from_data(item))
	return list


func to_data() -> Dictionary:
	var result: Dictionary = {"columns": list_data(columns)}
	if not waiting.is_empty():
		var list: Array[Dictionary] = []
		for f: Feeder in waiting:
			list.append(f.to_data())
		result["waiting"] = list
	if not main_switch:
		result["main"] = false
	if not supply_cable.is_empty():
		result["supply_cable"] = supply_cable
	if not spd:
		result["spd"] = false
	if not is_equal_approx(supply_impedance, SUPPLY_IMPEDANCE):
		result["ze"] = supply_impedance
	return result


## The diagram saved as [param d]; damaged entries are left out.
static func from_data(d: Variant) -> SingleLine:
	var line: SingleLine = SingleLine.new()
	if not (d is Dictionary):
		return line
	line.columns = list_from_data((d as Dictionary).get("columns", []))
	var raw_waiting: Variant = (d as Dictionary).get("waiting", [])
	if raw_waiting is Array:
		for item: Variant in raw_waiting:
			if item is Dictionary:
				var f: Feeder = Feeder.from_data(item)
				f.device = ""
				line.waiting.append(f)
	line.main_switch = (d as Dictionary).get("main", true) != false
	line._number_all()
	var cable: Variant = (d as Dictionary).get("supply_cable", "")
	line.supply_cable = cable if cable is String else ""
	line.spd = (d as Dictionary).get("spd", true) != false
	var ze: Variant = (d as Dictionary).get("ze", SUPPLY_IMPEDANCE)
	line.supply_impedance = clampf(float(ze), 0.01, 10.0) if (ze is float or ze is int) else SUPPLY_IMPEDANCE
	return line
