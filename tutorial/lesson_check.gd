class_name LessonCheck
extends RefCounted
## A schematic as a [Lesson] sees it: which terminals are joined (by wires
## and page connectors), which part plays which role of the lesson, the
## state of those parts while simulating, and test runs of the lesson's
## goals on a copy of the circuit. No nodes.

## Simulated seconds of one step of a test run while waiting.
const RUN_STEP: float = 0.1

var doc: SchematicDocument
## Role -> the part playing it (see [member Lesson.roles]).
var roles: Dictionary[String, CircuitComponent] = {}
## Terminal key -> net (the root of its group of joined terminals).
var _net: Dictionary[String, int] = {}


func _init(p_doc: SchematicDocument, lesson: Lesson = null) -> void:
	doc = p_doc
	_build_nets()
	if lesson != null and lesson.roles.is_valid():
		roles = lesson.roles.call(self)


func _build_nets() -> void:
	var index: Dictionary[String, int] = {}
	for c: CircuitComponent in doc.circuit.get_components():
		for key: String in c.get_terminal_keys():
			index[key] = index.size()
	var uf: UnionFind = UnionFind.new(index.size())
	var pairs: Array[PackedStringArray] = doc.circuit.get_wires().duplicate()
	pairs.append_array(doc.circuit.get_links())
	for pair: PackedStringArray in pairs:
		if index.has(pair[0]) and index.has(pair[1]):
			uf.union(index[pair[0]], index[pair[1]])
	for key: String in index:
		_net[key] = uf.find(index[key])


# --- Parts and roles ---------------------------------------------------------------

## The parts of the schematic [param filter] (CircuitComponent -> bool) takes, in drawing order.
func find(filter: Callable) -> Array[CircuitComponent]:
	var found: Array[CircuitComponent] = []
	for c: CircuitComponent in doc.circuit.get_components():
		if filter.call(c):
			found.append(c)
	return found


## The first part [param filter] takes, or null.
func first(filter: Callable) -> CircuitComponent:
	var found: Array[CircuitComponent] = find(filter)
	return found[0] if not found.is_empty() else null


## The first supply point of [param conductor], or null.
func supply(conductor: PowerSupply.Conductor) -> CircuitComponent:
	return first(func(c: CircuitComponent) -> bool: return c is PowerSupply and (c as PowerSupply).conductor == conductor)


func part(role: String) -> CircuitComponent:
	return roles.get(role, null)


func has(role: String) -> bool:
	return roles.has(role) and roles[role] != null


## Designation of the part playing [param role], or [param fallback].
func designation(role: String, fallback: String = "") -> String:
	return part(role).designation if has(role) else fallback


## Key of terminal [param index] of the part playing [param role], or "".
func key(role: String, index: int) -> String:
	if not has(role):
		return ""
	var keys: PackedStringArray = part(role).get_terminal_keys()
	return keys[index] if index < keys.size() else ""


# --- Connections -------------------------------------------------------------------

## Net of terminal [param terminal_key], or -1.
func net(terminal_key: String) -> int:
	return _net.get(terminal_key, -1)


## True when terminals [param a] and [param b] are joined.
func joined(a: String, b: String) -> bool:
	return net(a) >= 0 and net(a) == net(b)


## True when the first two terminals of [param c] are joined to [param a]
## and [param b], one to each, either way round (and not to each other).
func bridges(c: CircuitComponent, a: String, b: String) -> bool:
	if c == null or net(a) < 0 or net(b) < 0 or net(a) == net(b):
		return false
	var keys: PackedStringArray = c.get_terminal_keys()
	if keys.size() < 2:
		return false
	var x: int = net(keys[0])
	var y: int = net(keys[1])
	return (x == net(a) and y == net(b)) or (x == net(b) and y == net(a))


## True when the parts of [param chain] are wired one after the other: from
## the first terminal of the first part through each two-terminal part in
## turn (either way round) to the first terminal of the last part. A part
## whose terminals are joined to each other breaks the chain.
func series(chain: Array) -> bool:
	if chain.size() < 2 or not has(chain[0]) or not has(chain[chain.size() - 1]):
		return false
	var at: int = net(key(chain[0], 0))
	for i: int in range(1, chain.size() - 1):
		if not has(chain[i]):
			return false
		var keys: PackedStringArray = part(chain[i]).get_terminal_keys()
		if keys.size() < 2:
			return false
		var a: int = net(keys[0])
		var b: int = net(keys[1])
		if a == b:
			return false
		if a == at:
			at = b
		elif b == at:
			at = a
		else:
			return false
	return net(key(chain[chain.size() - 1], 0)) == at


## Pole [param pole] (terminals 2 pole and 2 pole + 1) through the parts of
## [param chain] in turn, each input joined to the output of the part before:
## [input of the first, output of the last], or [] where it breaks.
func pole_chain(chain: Array, pole: int) -> PackedStringArray:
	var at: String = ""
	var start: String = ""
	for role: String in chain:
		var input: String = key(role, 2 * pole)
		var output: String = key(role, 2 * pole + 1)
		if input.is_empty() or output.is_empty() or joined(input, output) or (not at.is_empty() and not joined(at, input)):
			return PackedStringArray()
		if start.is_empty():
			start = input
		at = output
	return PackedStringArray([start, at])


## The index in [param keys] of the first terminal joined to [param terminal_key], or -1.
func joined_index(terminal_key: String, keys: PackedStringArray) -> int:
	for i: int in keys.size():
		if joined(terminal_key, keys[i]):
			return i
	return -1


# --- Simulation state ----------------------------------------------------------------

## True when the part of [param role] is on: a coil pulled in, a lamp lit,
## a motor running, a button pressed, a switch or breaker switched on, an
## overload relay tripped.
func is_on(role: String) -> bool:
	return state_of(part(role))


static func state_of(c: CircuitComponent) -> bool:
	if c is ThreePhaseMotor:
		return (c as ThreePhaseMotor).is_running()
	if c is Load:
		return (c as Load).energized
	if c is PushButton:
		return (c as PushButton).pressed
	if c is LatchingSwitch:
		return (c as LatchingSwitch).switched_on
	if c is CircuitBreaker:
		return (c as CircuitBreaker).switched_on
	if c is MotorBreaker:
		return (c as MotorBreaker).switched_on
	if c is OverloadRelay:
		return (c as OverloadRelay).tripped
	return false


# --- Test runs -------------------------------------------------------------------------

## Runs [param goal] on a copy of the schematic in the simulator (instant
## switching), with every breaker and fuse holder switched on first.
## Returns {"passed": bool, "phase": index of the first phase that went
## wrong or -1, "short": bool (a short circuit stopped the run), "missing":
## role of a part the schematic does not have or "", "rows": [{"role",
## "label", "got": Array[bool], "expected": Array (bool or null)}]}, a row
## per part operated or expected, a value per phase.
func run(goal: Lesson.Goal) -> Dictionary:
	var result: Dictionary = {"passed": false, "phase": -1, "short": false, "missing": "", "rows": []}
	for role: String in goal.needs:
		if not has(role):
			result["missing"] = role
			return result
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	var circuit: Circuit = copy.circuit
	for c: CircuitComponent in circuit.get_components():
		if c is CircuitBreaker:
			(c as CircuitBreaker).switched_on = true
		elif c is MotorBreaker:
			(c as MotorBreaker).switched_on = true
		elif c is Fuse and (c as Fuse).holder:
			(c as Fuse).switched_on = true
		elif c is ThreePoleFuse and (c as ThreePoleFuse).holder:
			(c as ThreePoleFuse).switched_on = true
	var sim: Simulator = Simulator.new(circuit)
	sim.mode = Simulator.Mode.IDEAL
	var step: StepResult = sim.step()
	# Rows: the parts operated, then those expected, each once.
	var order: PackedStringArray = PackedStringArray()
	for phase: Dictionary in goal.phases:
		for action: Array in phase.get("do", []):
			if not order.has(action[0]):
				order.append(action[0])
	for phase: Dictionary in goal.phases:
		for role: String in phase.get("expect", {}):
			if not order.has(role):
				order.append(role)
	var rows: Array[Dictionary] = []
	for role: String in order:
		rows.append({"role": role, "label": designation(role, role), "got": [], "expected": []})
	for i: int in goal.phases.size():
		var phase: Dictionary = goal.phases[i]
		for action: Array in phase.get("do", []):
			_act(circuit.get_component(part(action[0]).id) if has(action[0]) else null, action[1])
		step = sim.step()
		var wait: float = float(phase.get("wait", 0.0))
		var timer: CircuitComponent = part(phase.get("wait_delay", ""))
		if timer is TimerRelay:
			wait += (timer as TimerRelay).delay
		var waited: float = 0.0
		while waited < wait - 1e-6 and not step.short_circuit:
			var dt: float = minf(RUN_STEP, wait - waited)
			step = sim.step(dt)
			waited += dt
		var expect: Dictionary = phase.get("expect", {})
		for row: Dictionary in rows:
			var role: String = row["role"]
			var c: CircuitComponent = circuit.get_component(part(role).id) if has(role) else null
			var got: bool = state_of(c)
			(row["got"] as Array).append(got)
			(row["expected"] as Array).append(expect.get(role, null))
			if expect.has(role) and got != bool(expect[role]) and result["phase"] < 0:
				result["phase"] = i
		if step.short_circuit:
			result["short"] = true
			if result["phase"] < 0:
				result["phase"] = i
			break
	result["rows"] = rows
	result["passed"] = result["phase"] < 0
	return result


## Operates [param c] in a test run.
static func _act(c: CircuitComponent, action: String) -> void:
	if c is PushButton:
		if action == "press":
			(c as PushButton).press()
		elif action == "release":
			(c as PushButton).release()
	elif c is LatchingSwitch:
		(c as LatchingSwitch).set_switched_on(action == "on")
	elif c is OverloadRelay and action == "trip":
		(c as OverloadRelay).test_trip()
