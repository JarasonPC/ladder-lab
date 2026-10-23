class_name InstallationCheck
extends RefCounted
## Checks a residential installation as the rules ask: every circuit with
## something on it protected, socket circuits and the bathroom's behind a
## residual current device of 30 mA (ČSN 33 2000-4-41, 33 2000-7-701), no
## more sockets on a circuit than [constant SingleLine.SOCKETS_PER_CIRCUIT],
## no socket outlet or light switch in a bathroom's zones 1 and 2. No nodes.

## The residual current a socket circuit or a bathroom's is protected by
## at most (A).
const RCD_LIMIT: float = 0.03


## The problems of the installation of [param doc] (none for another kind
## of schematic): each {"text" (English source text), "args", "ids" (the
## designations of the parts it is about)}.
static func run(doc: SchematicDocument) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if doc.environment != SchematicDocument.Kind.RESIDENTIAL:
		return issues
	var line: SingleLine = doc.single_line
	for f: SingleLine.Feeder in line.waiting:
		if not f.loads.is_empty():
			issues.append(_issue("Circuit %d is not protected yet: put a breaker for it in the consumer unit.", [f.number], f.loads))
	for f: SingleLine.Feeder in line.feeders():
		var sockets: int = 0
		var bathroom: bool = false
		for designation: String in f.loads:
			var c: CircuitComponent = doc.circuit.get_component(designation)
			if c is SocketOutlet:
				sockets += (c as SocketOutlet).gangs
			if _in_bathroom(doc, designation):
				bathroom = true
		if sockets > SingleLine.SOCKETS_PER_CIRCUIT:
			issues.append(_issue("Circuit %d has %d sockets: no more than %d are advised on one circuit.", [f.number, sockets, SingleLine.SOCKETS_PER_CIRCUIT], f.loads))
		if (sockets > 0 or bathroom) and not _behind_rcd(doc, f):
			issues.append(_issue("Circuit %d (-%s) is not behind a 30 mA residual current device, which sockets and bathrooms need.", [f.number, f.device], f.loads))
	for plan: FloorPlan in doc.floors:
		if plan.bath_zones().is_empty():
			continue
		for designation: String in plan.parts:
			var c: CircuitComponent = doc.circuit.get_component(designation) if designation != FloorPlan.UNIT else null
			if not (c is SocketOutlet or c is LightSwitch):
				continue
			var zone: int = plan.zone_of(plan.parts[designation], float(c.get("height")))
			if zone > 0:
				issues.append(_issue("-%s is in zone %d of the bathroom: no socket outlets or switches there.", [designation, zone], [designation]))
	return issues


## Whether circuit [param f] is protected by a residual current device of
## [constant RCD_LIMIT]: its own (an RCBO) or one heading a group it is in.
static func _behind_rcd(doc: SchematicDocument, f: SingleLine.Feeder) -> bool:
	if _rcd_enough(doc.circuit.get_component(f.device)):
		return true
	var item: RefCounted = f
	var group: SingleLine.Group = doc.single_line.group_holding(item)
	while group != null:
		if _rcd_enough(doc.circuit.get_component(group.device)):
			return true
		group = doc.single_line.group_holding(group)
	return false


static func _rcd_enough(c: CircuitComponent) -> bool:
	return c is ResidualCurrentDevice and (c as ResidualCurrentDevice).residual_rating <= RCD_LIMIT + 0.0001


## Whether part [param designation] is in a bathroom (a room of the
## bathroom's environment).
static func _in_bathroom(doc: SchematicDocument, designation: String) -> bool:
	var at: Vector2i = SingleLine._room_of(doc, designation)
	return at.x >= 0 and doc.floors[at.x].room_environment(at.y) == FloorPlan.ENVIRONMENTS[1]


static func _issue(text: String, args: Array, ids: Array) -> Dictionary:
	return {"text": text, "args": args, "ids": PackedStringArray(ids)}
