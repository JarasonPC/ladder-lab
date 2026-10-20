class_name SingleLine
extends RefCounted
## The consumer unit (rozváděč RD1) of a residential installation as its
## single-line diagram (jednopólové schéma), as Czech projects draw it: the
## supply through the main switch onto busbars L1, L2, L3 and N, and the
## outgoing circuits hanging from the busbars in columns, left to right. A
## column is a circuit (its breaker, RCBO or AFDD and what it feeds) or a
## group: an RCD with the circuits under it. Only the phases are drawn; N
## and PE are wired all the same. No nodes.
##
## The parts are components of the document's circuit; the diagram keeps
## their order, phases and groups and what each circuit feeds, and wires
## them all ([method wire]: every wire of the document is made here, none is
## drawn by hand). The supply points, the main switch [constant MAIN] and the
## ripple control contacts [constant HDO] are made and kept by it.

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


## An outgoing circuit: its protective device and the parts it feeds.
class Feeder extends RefCounted:
	## Its circuit breaker, RCBO or AFDD.
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


## A residual current device with the circuits under it.
class Group extends RefCounted:
	## The RCD.
	var device: String = ""
	## Phase of a two-pole RCD (a four-pole one takes all three).
	var phase: int = 1
	var feeders: Array[Feeder] = []

	func _init(p_device: String = "", p_phase: int = 1) -> void:
		device = p_device
		phase = p_phase

	func to_data() -> Dictionary:
		var list: Array[Dictionary] = []
		for f: Feeder in feeders:
			list.append(f.to_data())
		return {"device": device, "phase": phase, "feeders": list}

	static func from_data(d: Dictionary) -> Group:
		var raw_phase: Variant = d.get("phase", 1)
		var g: Group = Group.new(str(d.get("device", "")), clampi(int(raw_phase) if raw_phase is float or raw_phase is int else 1, 1, 3))
		var raw: Variant = d.get("feeders", [])
		if raw is Array:
			for item: Variant in raw:
				if item is Dictionary:
					g.feeders.append(Feeder.from_data(item))
		return g


## The columns left to right: [SingleLine.Feeder] or [SingleLine.Group].
var columns: Array[RefCounted] = []
## The supply cable written at the incoming side ("" for [constant SUPPLY_CABLE]).
var supply_cable: String = ""
## A surge protective device (SPD) on the busbars to PE (drawn only).
var spd: bool = true


func is_empty() -> bool:
	return columns.is_empty() and supply_cable.is_empty() and spd


# --- Finding things -------------------------------------------------------------------

## Whether [param c] heads a group: an RCD without overcurrent release.
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


## Every circuit, left to right.
func feeders() -> Array[Feeder]:
	var list: Array[Feeder] = []
	for column: RefCounted in columns:
		if column is Group:
			list.append_array((column as Group).feeders)
		else:
			list.append(column as Feeder)
	return list


## The circuit of protective device [param designation], or null.
func feeder_of(designation: String) -> Feeder:
	for f: Feeder in feeders():
		if f.device == designation:
			return f
	return null


## The circuit feeding part [param designation], or null.
func feeder_feeding(designation: String) -> Feeder:
	for f: Feeder in feeders():
		if f.loads.has(designation):
			return f
	return null


## The group of RCD [param designation], or null.
func group_of(designation: String) -> Group:
	for column: RefCounted in columns:
		if column is Group and (column as Group).device == designation:
			return column as Group
	return null


## The group circuit [param f] is in, or null.
func group_holding(f: Feeder) -> Group:
	for column: RefCounted in columns:
		if column is Group and (column as Group).feeders.has(f):
			return column as Group
	return null


## Column of device [param designation] (a circuit's or a group's), -1 for none.
func column_of(designation: String) -> int:
	for i: int in columns.size():
		var column: RefCounted = columns[i]
		if column is Group:
			if (column as Group).device == designation:
				return i
			for f: Feeder in (column as Group).feeders:
				if f.device == designation:
					return i
		elif (column as Feeder).device == designation:
			return i
	return -1


## Whether [param designation] is in the diagram (a device or a part fed).
func has(designation: String) -> bool:
	return column_of(designation) >= 0 or feeder_feeding(designation) != null


## Whether circuit [param f] is switched by the ripple control contactor:
## set so, and a circuit of its own (not in a group).
func switched_by_hdo(f: Feeder) -> bool:
	return f.hdo and group_holding(f) == null


## Number of the cable of circuit [param f]: its place among the circuits, from 1.
func cable_number(f: Feeder) -> int:
	return feeders().find(f) + 1


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


## The phases circuit [param f] takes, in pole order, as fed by [param circuit].
func phases_of(f: Feeder, circuit: Circuit) -> PackedInt32Array:
	var c: CircuitComponent = circuit.get_component(f.device)
	var poles: int = 1
	if c is MotorBreaker and not (c is ResidualCurrentDevice or c is ArcFaultDevice):
		poles = (c as MotorBreaker).poles
	elif c is ResidualCurrentDevice:
		poles = maxi((c as ResidualCurrentDevice).poles - 1, 1)
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
## an RCD as a new group at column [param column], a protective device as a
## new circuit there or, with [param group] (the column of a group), the
## [param column]-th circuit of that group, a part fed into circuit
## [param feeder] (a device's designation). Rewires. Returns false when it
## does not fit there (nothing changed then).
func add(doc: SchematicDocument, c: CircuitComponent, column: int, group: int = -1, feeder: String = "") -> bool:
	var placed: bool = false
	if heads_group(c):
		if group >= 0:
			return false
		var poles: int = (c as ResidualCurrentDevice).poles
		var g: Group = Group.new(c.designation, next_phase(doc.circuit) if poles == 2 else 1)
		columns.insert(clampi(column, 0, columns.size()), g)
		placed = true
	elif protects_circuit(c):
		var f: Feeder = Feeder.new(c.designation, 1)
		if group >= 0 and group < columns.size() and columns[group] is Group:
			var g: Group = columns[group] as Group
			var rcd: ResidualCurrentDevice = doc.circuit.get_component(g.device) as ResidualCurrentDevice
			# Under a two-pole RCD only single-pole circuits, on its phase.
			if rcd != null and rcd.poles == 2 and _poles(c) > 1:
				return false
			f.phase = g.phase if rcd == null or rcd.poles == 2 else next_phase(doc.circuit)
			g.feeders.insert(clampi(column, 0, g.feeders.size()), f)
		else:
			f.phase = next_phase(doc.circuit)
			columns.insert(clampi(column, 0, columns.size()), f)
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


## Moves the circuit or group of device [param designation] to column
## [param column] (counted without it), or with [param group] (the column of
## a group, counted without it) into that group as its [param column]-th
## circuit. A group never goes into another. Rewires. Returns false when it
## does not fit there.
func move(doc: SchematicDocument, designation: String, column: int, group: int = -1) -> bool:
	var head: Group = group_of(designation)
	var f: Feeder = feeder_of(designation)
	if head == null and f == null:
		return false
	var target: Group = null
	var from: int = column_of(designation)
	if group >= 0:
		if head != null:
			return false
		# The group's column once the circuit is out (a circuit of its own
		# left of it frees a column).
		var index: int = group + (1 if group_holding(f) == null and from <= group else 0)
		if index < 0 or index >= columns.size() or not (columns[index] is Group):
			return false
		target = columns[index] as Group
		var rcd: ResidualCurrentDevice = doc.circuit.get_component(target.device) as ResidualCurrentDevice
		if rcd != null and rcd.poles == 2 and _poles(doc.circuit.get_component(f.device)) > 1:
			return false
	if head != null:
		columns.erase(head)
		columns.insert(clampi(column, 0, columns.size()), head)
	else:
		var holder: Group = group_holding(f)
		if holder != null:
			holder.feeders.erase(f)
		else:
			columns.erase(f)
		if target != null:
			var rcd: ResidualCurrentDevice = doc.circuit.get_component(target.device) as ResidualCurrentDevice
			if rcd == null or rcd.poles == 2:
				f.phase = target.phase
			target.feeders.insert(clampi(column, 0, target.feeders.size()), f)
		else:
			columns.insert(clampi(column, 0, columns.size()), f)
	wire(doc)
	return true


## Puts circuit or group [param designation] on phase [param phase] (a
## group's circuits along with it; a circuit under a two-pole RCD stays on
## the RCD's phase). Rewires.
func set_phase(doc: SchematicDocument, designation: String, phase: int) -> void:
	phase = clampi(phase, 1, 3)
	var head: Group = group_of(designation)
	if head != null:
		head.phase = phase
		var rcd: ResidualCurrentDevice = doc.circuit.get_component(head.device) as ResidualCurrentDevice
		if rcd == null or rcd.poles == 2:
			for f: Feeder in head.feeders:
				f.phase = phase
	else:
		var f: Feeder = feeder_of(designation)
		if f == null:
			return
		var holder: Group = group_holding(f)
		if holder != null:
			var rcd: ResidualCurrentDevice = doc.circuit.get_component(holder.device) as ResidualCurrentDevice
			if rcd == null or rcd.poles == 2:
				return
		f.phase = phase
	wire(doc)


## Leaves [param designation] out of the diagram (its component is gone): a
## group's circuits stay where it was, a circuit goes with what it fed
## unfed, a part fed is no longer fed.
func remove(designation: String) -> void:
	for i: int in columns.size():
		var column: RefCounted = columns[i]
		if column is Group:
			var g: Group = column as Group
			if g.device == designation:
				columns.remove_at(i)
				for k: int in g.feeders.size():
					columns.insert(i + k, g.feeders[k])
				return
			for f: Feeder in g.feeders:
				if f.device == designation:
					g.feeders.erase(f)
					return
		elif (column as Feeder).device == designation:
			columns.remove_at(i)
			return
	var fed: Feeder = feeder_feeding(designation)
	if fed != null:
		var at: int = fed.loads.find(designation)
		fed.loads.remove_at(at)


## Device or part [param old_designation] is now [param new_designation].
func rename(old_designation: String, new_designation: String) -> void:
	for column: RefCounted in columns:
		if column is Group and (column as Group).device == old_designation:
			(column as Group).device = new_designation
	for f: Feeder in feeders():
		if f.device == old_designation:
			f.device = new_designation
		var at: int = f.loads.find(old_designation)
		if at >= 0:
			f.loads[at] = new_designation


## Drops what [param circuit] no longer has, and parts of a kind that no
## longer fits (a breaker turned into an RCD's group head and the like).
func prune(circuit: Circuit) -> void:
	for f: Feeder in feeders():
		for i: int in range(f.loads.size() - 1, -1, -1):
			var load: CircuitComponent = circuit.get_component(f.loads[i])
			if load == null or not is_load(load):
				f.loads.remove_at(i)
	var stale: PackedStringArray = PackedStringArray()
	for column: RefCounted in columns:
		if column is Group:
			if not heads_group(circuit.get_component((column as Group).device)):
				stale.append((column as Group).device)
			for f: Feeder in (column as Group).feeders:
				if not protects_circuit(circuit.get_component(f.device)):
					stale.append(f.device)
		elif not protects_circuit(circuit.get_component((column as Feeder).device)):
			stale.append((column as Feeder).device)
	for designation: String in stale:
		remove(designation)


## A cell of the (never shown) schematic page for a new part, clear of the others.
static func hidden_cell(doc: SchematicDocument) -> Vector2i:
	return Vector2i(6 * doc.circuit.get_components().size(), 0)


static func _poles(c: CircuitComponent) -> int:
	if c is ResidualCurrentDevice:
		return maxi((c as ResidualCurrentDevice).poles - 1, 1)
	if c is ArcFaultDevice:
		return 1
	if c is MotorBreaker:
		return (c as MotorBreaker).poles
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
	var main: CircuitComponent = doc.circuit.get_component(MAIN)
	var main_keys: PackedStringArray = main.get_terminal_keys()
	for k: int in 4:
		doc.connect_terminals(SUPPLIES[k], main_keys[2 * k])
	# The busbars: the main switch's outputs.
	var bus: Dictionary[int, String] = {1: main_keys[1], 2: main_keys[3], 3: main_keys[5]}
	var n_bus: String = main_keys[7]
	var hdo_contacts: Array[CircuitComponent] = []
	for c: CircuitComponent in doc.circuit.get_components():
		if c.designation == HDO and c is LatchingSwitch:
			hdo_contacts.append(c)
	var hdo_used: int = 0
	_joined.clear()
	_live.clear()
	_switched = _switched_luminaires(doc)
	for column: RefCounted in columns:
		if column is Group:
			var g: Group = column as Group
			var rcd: ResidualCurrentDevice = doc.circuit.get_component(g.device) as ResidualCurrentDevice
			var keys: PackedStringArray = rcd.get_terminal_keys()
			var sub: Dictionary[int, String] = {}
			var phases: int = rcd.poles - 1
			for k: int in phases:
				var ph: int = g.phase if phases == 1 else k + 1
				doc.connect_terminals(bus[ph], keys[2 * k])
				sub[ph] = keys[2 * k + 1]
			doc.connect_terminals(n_bus, keys[2 * phases])
			var n_sub: String = keys[2 * phases + 1]
			for f: Feeder in g.feeders:
				hdo_used = _wire_feeder(doc, f, sub, n_sub, hdo_contacts, hdo_used)
		else:
			hdo_used = _wire_feeder(doc, column as Feeder, bus, n_bus, hdo_contacts, hdo_used)
	_wire_lighting(doc)


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
	if device is ResidualCurrentDevice or device is ArcFaultDevice:
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
	for link: FloorPlan.Link in doc.floor_plan.links:
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


## The supply points, the main switch and one ripple control contact a
## circuit switched by it (made or taken away to match).
func _make_fixed_parts(doc: SchematicDocument) -> void:
	var conductors: Array[PowerSupply.Conductor] = [PowerSupply.Conductor.L, PowerSupply.Conductor.L2, PowerSupply.Conductor.L3, PowerSupply.Conductor.N, PowerSupply.Conductor.PE]
	for k: int in SUPPLIES.size():
		if doc.circuit.get_component(SUPPLIES[k]) == null:
			doc.add(PowerSupply.new(SUPPLIES[k], conductors[k]), hidden_cell(doc))
	var main: CircuitComponent = doc.circuit.get_component(MAIN)
	if not (main is CamSwitch) or (main as CamSwitch).poles != 4:
		if main != null:
			doc.remove_component(main.id)
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

func to_data() -> Dictionary:
	var list: Array[Dictionary] = []
	for column: RefCounted in columns:
		var d: Dictionary = (column as Group).to_data() if column is Group else (column as Feeder).to_data()
		d["kind"] = "group" if column is Group else "circuit"
		list.append(d)
	var result: Dictionary = {"columns": list}
	if not supply_cable.is_empty():
		result["supply_cable"] = supply_cable
	if not spd:
		result["spd"] = false
	return result


## The diagram saved as [param d]; damaged entries are left out.
static func from_data(d: Variant) -> SingleLine:
	var line: SingleLine = SingleLine.new()
	if not (d is Dictionary):
		return line
	var raw: Variant = (d as Dictionary).get("columns", [])
	if raw is Array:
		for item: Variant in raw:
			if not (item is Dictionary):
				continue
			if (item as Dictionary).get("kind", "") == "group":
				line.columns.append(Group.from_data(item))
			else:
				line.columns.append(Feeder.from_data(item))
	var cable: Variant = (d as Dictionary).get("supply_cable", "")
	line.supply_cable = cable if cable is String else ""
	line.spd = (d as Dictionary).get("spd", true) != false
	return line
