class_name TrainingFaults
extends RefCounted
## The hidden faults of a fault-finding task (a training plan with
## [member TrainingPlan.faults]): the switchboards, doors and stations come
## wired by the schematic, the student finds the faults by simulating and
## measuring (see [Multimeter]) and reports each. A fault, as a report of
## one: {"kind": "wire" (a broken wire, "place", "a", "b": its ports, see
## [TrainingCheck]), "open" (a contact that does not close), "welded" (one
## that stays closed) or "coil" (a broken coil), with "id" (the component's
## id) for the last three}. No nodes.

## Kinds of fault, and their English names (translated by the UI).
const KINDS: PackedStringArray = ["wire", "open", "welded", "coil"]
const KIND_TITLES: PackedStringArray = ["Broken wire", "Contact does not close", "Contact stays closed", "Coil broken"]


## What a fault of [param kind] can be in [param doc] (a plan wired), each
## a fault as described above.
static func choices(doc: SchematicDocument, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if kind == "wire":
		for place: String in doc.training.wires:
			for wire: PackedStringArray in doc.training.wires[place]:
				result.append({"kind": kind, "place": place, "a": wire[0], "b": wire[1]})
		return result
	for c: CircuitComponent in doc.circuit.get_components():
		var contact: bool = (c is SwitchingElement and not (c is ProtectiveDevice)) or c is ChangeoverContact or c is MainContacts
		if (kind == "coil" and c is Coil) or (kind != "coil" and contact):
			result.append({"kind": kind, "id": c.id})
	return result


## A fault as shown: "+RA1: -KM1:13 – -X2-3", "-KM1 13-14", "-KM1".
static func text(fault: Dictionary) -> String:
	if fault.get("kind", "") == "wire":
		return "%s: %s – %s" % [TrainingCheck.place_text(fault["place"]), TrainingPick.port_text(fault["a"]), TrainingPick.port_text(fault["b"])]
	return "-" + str(fault.get("id", "")).replace(":", " ")


## Whether [param a] and [param b] are the same fault.
static func same(a: Dictionary, b: Dictionary) -> bool:
	if a.get("kind", "") != b.get("kind", ""):
		return false
	if a["kind"] == "wire":
		return a.get("place", "") == b.get("place", "") and ((a.get("a", "") == b.get("a", "") and a.get("b", "") == b.get("b", "")) or (a.get("a", "") == b.get("b", "") and a.get("b", "") == b.get("a", "")))
	return a.get("id", "") == b.get("id", "")


## Whether the student's wire [param wire] of [param place] is broken in [param plan].
static func broken(plan: TrainingPlan, place: String, wire: PackedStringArray) -> bool:
	for fault: Dictionary in plan.faults:
		if same(fault, {"kind": "wire", "place": place, "a": wire[0], "b": wire[1]}):
			return true
	return false


## Gives the parts of [param copy] (a plan simulated, see [TrainingSim])
## the faults of its plan.
static func apply(copy: SchematicDocument) -> void:
	for fault: Dictionary in copy.training.faults:
		var c: CircuitComponent = copy.circuit.get_component(str(fault.get("id", "")))
		if c == null:
			continue
		match fault["kind"]:
			"open", "welded":
				var how: SwitchingElement.Fault = SwitchingElement.Fault.OPEN if fault["kind"] == "open" else SwitchingElement.Fault.WELDED
				if c is MainContacts:
					(c as MainContacts).fault = how
				elif c is ChangeoverContact:
					(c as ChangeoverContact).fault = how
				elif c is SwitchingElement:
					(c as SwitchingElement).fault = how
			"coil":
				if c is Coil:
					(c as Coil).fault = Coil.Fault.OPEN


## The faults of [param plan] found by a report.
static func found(plan: TrainingPlan) -> int:
	var count: int = 0
	for fault: Dictionary in plan.faults:
		if plan.reports.any(func(report: Dictionary) -> bool: return same(fault, report)):
			count += 1
	return count


## Whether report [param report] names a fault of [param plan].
static func right(plan: TrainingPlan, report: Dictionary) -> bool:
	return plan.faults.any(func(fault: Dictionary) -> bool: return same(fault, report))
