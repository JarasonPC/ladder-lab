extends GutTest
## Wiring of the switchboard (rozvaděč): the conductor each net is wired
## with and the wires led from terminal to terminal through the ducts.

const NO := SwitchingElement.ContactType.NO


## Supplies, a three-pole fuse feeding KM1's main contacts, a control fuse
## through KM1's 13-14 to its coil, the coil back to N through terminal
## X1:N, the motor on terminal strip X2.
func _doc() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("wiring")
	for s: Array in [["L1", PowerSupply.Conductor.L], ["L2", PowerSupply.Conductor.L2], ["L3", PowerSupply.Conductor.L3], ["N", PowerSupply.Conductor.N], ["PE", PowerSupply.Conductor.PE]]:
		doc.add(PowerSupply.new(s[0], s[1]), Vector2i(4 * doc.circuit.get_components().size(), 0))
	var fuse: ThreePoleFuse = ThreePoleFuse.new("FU1")
	doc.add(fuse, Vector2i(0, 4))
	doc.add(Fuse.new("FU2"), Vector2i(12, 4))
	doc.add(Coil.new("KM1"), Vector2i(16, 4))
	doc.add(MainContacts.new("KM1"), Vector2i(20, 4))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(24, 4))
	var motor: ThreePhaseMotor = ThreePhaseMotor.new("M1")
	doc.add(motor, Vector2i(28, 4))
	var block: TerminalBlock = TerminalBlock.new("X5")
	block.label = "N"
	doc.add(block, Vector2i(32, 4))
	for pole: int in 3:
		doc.connect_terminals(["L1", "L2", "L3"][pole], "FU1:%d" % (2 * pole + 1))
		doc.connect_terminals("FU1:%d" % (2 * pole + 2), "KM1:%d" % (2 * pole + 1))
		doc.connect_terminals("KM1:%d" % (2 * pole + 2), "M1:" + ["U1", "V1", "W1"][pole])
		doc.set_strip_terminal(motor.id, pole, "X2:%d" % (pole + 1))
	doc.connect_terminals("M1:PE", "PE")
	doc.set_strip_terminal(motor.id, 3, "X2:PE")
	doc.connect_terminals("L1", "FU2:1")
	doc.connect_terminals("FU2:2", "KM1:13")
	doc.connect_terminals("KM1:14", "KM1:A1")
	doc.connect_terminals("KM1:A2", "X5")
	doc.connect_terminals("X5", "N")
	doc.fill_cabinet()
	return doc


func test_strip_terminals_join_their_circuit_terminals() -> void:
	var strips: Dictionary = CabinetDevices.strips(_doc())
	assert_eq(strips["X2"][0]["keys"], PackedStringArray(["M1:U1"]), "a terminal on a component's lead")
	assert_eq(strips["X1"][0]["keys"], PackedStringArray(["X5"]), "a terminal on a wire")


func test_conductors() -> void:
	var doc: SchematicDocument = _doc()
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	var conductor: Dictionary[int, CabinetDevices.Conductor] = CabinetDevices.conductors(doc.circuit, net)
	assert_eq(conductor[net["FU1:2"]], CabinetDevices.Conductor.POWER, "the main power circuit")
	assert_eq(conductor[net["KM1:2"]], CabinetDevices.Conductor.POWER)
	assert_eq(conductor[net["L1"]], CabinetDevices.Conductor.POWER, "the phase before the fuses feeds the power circuit too")
	assert_eq(conductor[net["FU2:2"]], CabinetDevices.Conductor.CONTROL, "the control circuit's phase")
	assert_eq(conductor[net["KM1:A1"]], CabinetDevices.Conductor.CONTROL)
	assert_eq(conductor[net["KM1:A2"]], CabinetDevices.Conductor.NEUTRAL)
	assert_eq(conductor[net["M1:PE"]], CabinetDevices.Conductor.PE)


## Wire between terminal keys [param a] and [param b] (either way), {} for none.
func _wire(wiring: CabinetWiring, a: String, b: String) -> Dictionary:
	for wire: Dictionary in wiring.wires:
		if (wire["from"] == a and wire["to"] == b) or (wire["from"] == b and wire["to"] == a):
			return wire
	return {}


func test_wires_join_the_terminals_of_each_net() -> void:
	var doc: SchematicDocument = _doc()
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	var power: Dictionary = _wire(wiring, "FU1:2", "KM1:1")
	assert_false(power.is_empty())
	assert_eq(power["conductor"], CabinetDevices.Conductor.POWER)
	assert_eq(_wire(wiring, "KM1:2", "M1:U1")["conductor"], CabinetDevices.Conductor.POWER, "to the motor's terminal on the strip")
	assert_eq(_wire(wiring, "FU2:2", "KM1:13")["conductor"], CabinetDevices.Conductor.CONTROL)
	assert_eq(_wire(wiring, "KM1:14", "KM1:A1")["conductor"], CabinetDevices.Conductor.CONTROL)
	assert_eq(_wire(wiring, "KM1:A2", "X5")["conductor"], CabinetDevices.Conductor.NEUTRAL)
	assert_eq(_wire(wiring, "FU1:1", "FU2:1")["conductor"], CabinetDevices.Conductor.POWER, "L1 to both fuses")
	assert_eq(wiring.wires.size(), 19, "one wire fewer than terminals in each net, a core of the supply cable for each of L1, L2, L3, N and PE, and four cores out to the motor")


func test_wires_run_through_the_ducts() -> void:
	var doc: SchematicDocument = _doc()
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	var fuse: Dictionary = layout.places[0]
	assert_eq(fuse["designation"], "FU1")
	var screw: Vector3 = CabinetParts.terminal_points(CabinetDevices.Kind.FUSE, fuse["desc"])["2"]
	var points: PackedVector2Array = _wire(wiring, "FU1:2", "KM1:1")["points"]
	var at: Vector2 = fuse["origin"] + Vector2(screw.x, screw.y + screw.z)
	assert_true(points[0].is_equal_approx(at) or points[points.size() - 1].is_equal_approx(at), "the wire ends at the bottom of the fuse's screw")
	for wire: Dictionary in wiring.wires:
		var path: PackedVector2Array = wire["points"]
		var in_duct: bool = false
		for i: int in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			assert_true(is_equal_approx(a.x, b.x) or is_equal_approx(a.y, b.y), "%s-%s runs straight" % [wire["from"], wire["to"]])
			for duct: Dictionary in layout.ducts:
				var r: Rect2 = duct["rect"]
				if not duct["vertical"] and r.has_point(a) and r.has_point(b) and is_equal_approx(a.y, b.y):
					assert_true(a.y > r.position.y + CabinetParts.DUCT_DEPTH - 0.01 and a.y < r.end.y - CabinetParts.DUCT_DEPTH + 0.01, "along the floor of the duct")
		for i: int in path.size() - 1:
			var segment: Rect2 = Rect2(path[i], Vector2.ZERO).expand(path[i + 1]).grow(0.01)
			for duct: Dictionary in layout.ducts:
				in_duct = in_duct or (duct["rect"] as Rect2).intersects(segment)
		assert_true(in_duct, "%s-%s is led through a duct" % [wire["from"], wire["to"]])


func test_power_wire_between_rails_takes_a_side_duct() -> void:
	var doc: SchematicDocument = _doc()
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	# KM1's outputs (under its rail) go up to the strip's top on the rail below:
	# the same duct; L1 from the top of FU1 to the top of FU2 stays in the top duct.
	var feed: PackedVector2Array = _wire(wiring, "FU1:1", "FU2:1")["points"]
	for point: Vector2 in feed:
		assert_true(point.y < layout.rails[0].get_center().y, "stays above the first rail")
	# The control phase from FU2 (bottom) to KM1:13 (top of the next rail): the duct between them.
	var control: PackedVector2Array = _wire(wiring, "FU2:2", "KM1:13")["points"]
	var x0: float = layout.ducts[0]["rect"].position.x
	for point: Vector2 in control:
		assert_true(point.x >= x0, "no side duct needed")
	# KM1:14 at the bottom to its A1 at the top: round through a side duct.
	var coil: PackedVector2Array = _wire(wiring, "KM1:14", "KM1:A1")["points"]
	var sides: bool = false
	for point: Vector2 in coil:
		sides = sides or point.x < x0
	assert_true(sides, "through the left side duct")


func test_wires_go_beside_the_overload_relay() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(9)
	if doc.cabinet_rails.is_empty():
		doc.fill_cabinet()
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	var relays: Array[Rect2] = []
	for place: Dictionary in layout.places:
		if place.has("under_rect"):
			relays.append((place["under_rect"] as Rect2).grow(-0.5))
	assert_false(relays.is_empty(), "an overload relay sits under a contactor")
	var beside: int = 0
	for wire: Dictionary in wiring.wires:
		if str(wire["from"]).begins_with("F1:") or str(wire["to"]).begins_with("F1:"):
			continue
		var path: PackedVector2Array = wire["points"]
		for i: int in path.size() - 1:
			var segment: Rect2 = Rect2(path[i], Vector2.ZERO).expand(path[i + 1])
			for relay: Rect2 in relays:
				assert_false(relay.intersects(segment.grow(0.01)), "%s-%s keeps off the relay" % [wire["from"], wire["to"]])
			for relay: Rect2 in relays:
				var channel: Rect2 = relay.grow_individual(CabinetLayout.WIRE_CHANNEL, 0.0, CabinetLayout.WIRE_CHANNEL, 0.0)
				if channel.encloses(Rect2(segment.position.x, relay.position.y, segment.size.x, relay.size.y)) and segment.position.y <= relay.position.y and segment.end.y >= relay.end.y:
					beside += 1
	assert_true(beside > 0, "wires from the contactor's bottom terminals run down beside the relay")


func test_supply_comes_in_through_a_cable() -> void:
	var doc: SchematicDocument = _doc()
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	var cores: Dictionary[String, Dictionary] = {}
	for wire: Dictionary in wiring.wires:
		if wire["external"] and wire["cable"] == "AC":
			assert_false(cores.has(wire["from"]), "one core per conductor")
			cores[wire["from"]] = wire
	assert_eq(cores.keys(), ["L1", "L2", "L3", "N", "PE"], "the cores in order")
	assert_eq(cores["L1"]["to"], "FU1:1", "L1 to the nearest terminal it feeds; FU2 is jumpered from there")
	assert_false(_wire(wiring, "FU1:1", "FU2:1").is_empty())
	assert_eq(cores["N"]["conductor"], CabinetDevices.Conductor.NEUTRAL)
	assert_eq(cores["PE"]["to"], "M1:PE", "PE to the motor's PE terminal on the strip")
	assert_eq(cores["PE"]["conductor"], CabinetDevices.Conductor.PE)
	var top: Array[Dictionary] = []
	for gland: Dictionary in wiring.glands:
		if not gland["bottom"]:
			top.append(gland)
	assert_eq(top.size(), 1, "one cable for the AC supply")
	for core: Dictionary in cores.values():
		var start: Vector2 = (core["points"] as PackedVector2Array)[0]
		assert_true(is_equal_approx(start.y, CabinetLayout.FRAME), "a core starts at the top of the enclosure")
		assert_true((top[0]["rect"] as Rect2).has_point(start + Vector2(0, -0.5)), "inside the gland")


func test_terminals_on_pe_and_n_wires_are_coloured() -> void:
	var doc: SchematicDocument = _doc()
	var strips: Dictionary = CabinetDevices.strips(doc)
	var kinds: Dictionary = {}
	for t: Dictionary in strips["X2"]:
		kinds[t["label"]] = t["kind"]
	assert_eq(kinds, {"1": "L", "2": "L", "3": "L", "PE": "PE"})
	doc.set_strip_terminal(doc.circuit.get_component("M1").id, 3, "X2:4")
	assert_eq(CabinetDevices.strips(doc)["X2"][3]["kind"], "PE", "a terminal on the PE wire is a PE terminal whatever its number")
	var block: TerminalBlock = doc.circuit.get_component("X5") as TerminalBlock
	block.label = "7"
	assert_eq(CabinetDevices.strips(doc)["X1"][0]["kind"], "N", "a terminal on the N wire is blue")


func test_split_a_terminal_strip() -> void:
	var doc: SchematicDocument = _doc()
	var motor: String = doc.circuit.get_component("M1").id
	(doc.circuit.get_component("X5") as TerminalBlock).label = "X2:5"
	assert_eq(doc.next_strip_name(), "X3", "X1 has no terminals any more but still its place")
	assert_eq(doc.move_strip_terminals("X2", PackedStringArray(["2", "5"]), "X3"), 2)
	assert_eq(doc.get_placement(motor).strips[1], "X3:2", "a terminal on a lead")
	assert_eq((doc.circuit.get_component("X5") as TerminalBlock).label, "X3:5", "a terminal on a wire")
	assert_eq(doc.get_placement(motor).strips[0], "X2:1", "the others stay")
	var names: PackedStringArray = PackedStringArray()
	for rail: CabinetRail in doc.cabinet_rails:
		for item: CabinetItem in rail.items:
			if item.kind == CabinetItem.Kind.STRIP:
				names.append(item.designation)
	assert_true(names.find("X3") == names.find("X2") + 1, "the new strip sits right after the old one")
	# A number the strip has already: the next free one.
	doc.set_strip_terminal(motor, 0, "X2:5")
	assert_eq(doc.move_strip_terminals("X2", PackedStringArray(["5"]), "X3"), 1)
	assert_eq(doc.get_placement(motor).strips[0], "X3:6")
	# Back to X1 the plain number is used; the emptied strip loses its place.
	doc.move_strip_terminals("X3", PackedStringArray(["2", "5", "6"]), "X1")
	assert_eq((doc.circuit.get_component("X5") as TerminalBlock).label, "5")
	assert_eq(doc.get_placement(motor).strips[1], "2")
	assert_false(doc.cabinet_has(CabinetItem.Kind.STRIP, "X3"), "nothing left in X3")
	assert_eq(doc.move_strip_terminals("X2", PackedStringArray(["PE"]), "X2"), 0, "not into itself")


func test_field_cables_leave_through_the_bottom() -> void:
	var doc: SchematicDocument = _doc()
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	var to_motor: Dictionary[String, Dictionary] = {}
	for wire: Dictionary in wiring.wires:
		if wire["external"] and wire["cable"] == "M1":
			to_motor[wire["to"]] = wire
	assert_eq(to_motor.keys().size(), 4, "a core to each terminal of the motor's strip X2")
	assert_eq(to_motor["M1:U1"]["conductor"], CabinetDevices.Conductor.POWER)
	assert_eq(to_motor["M1:PE"]["conductor"], CabinetDevices.Conductor.PE)
	var gland: Dictionary = {}
	for g: Dictionary in wiring.glands:
		if g["cable"] == "M1":
			gland = g
	assert_true(gland["bottom"], "the motor cable leaves through the bottom of the enclosure")
	var strip: Dictionary = {}
	for place: Dictionary in layout.places:
		if place["kind"] == CabinetLayout.STRIP and place["designation"] == "X2":
			strip = place
	for wire: Dictionary in to_motor.values():
		var path: PackedVector2Array = wire["points"]
		assert_true(path[0].y > layout.size.y - CabinetLayout.FRAME - 0.5, "the core starts at the bottom of the enclosure")
		assert_true(is_equal_approx(path[path.size() - 1].y, (strip["origin"] as Vector2).y + CabinetParts.TERMINAL.y - CabinetParts.TERMINAL_ENTRY), "and goes into the bottom of the strip terminal")
	# Terminals of strip X1 lead to nothing outside: no cable for them.
	for g: Dictionary in wiring.glands:
		assert_true(g["cable"] in ["AC", "M1"], "only the supply and the motor cable")
	assert_eq(CabinetDevices.field_device(doc.circuit, "X5", CabinetDevices.nets(doc.circuit)), "", "the N terminal joins only devices inside")


func test_plc_example_is_wired() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(14)
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var kinds: Array = []
	for place: Dictionary in layout.places:
		kinds.append(place["kind"])
	assert_true(kinds.has(CabinetDevices.Kind.PLC))
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	var to_plc: bool = false
	for wire: Dictionary in wiring.wires:
		if str(wire["from"]).begins_with("A1:") or str(wire["to"]).begins_with("A1:"):
			to_plc = true
	assert_true(to_plc, "the fuse feeds the PLC in the switchboard")
