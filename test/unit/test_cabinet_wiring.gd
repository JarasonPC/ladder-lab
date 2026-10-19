extends GutTest
## Wiring of the switchboard (rozvaděč): the conductor each net is wired
## with and the wires led from terminal to terminal through the ducts.

const ExamplePower = preload("res://test/unit/example_power.gd")

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
	doc.add_switchboard()
	doc.fill_cabinet(0)
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
			# Straight runs, but for one slant into a slot at a duct's edge.
			var into_slot: bool = false
			for duct: Dictionary in layout.ducts:
				var r: Rect2 = duct["rect"]
				for y: float in [r.position.y, r.end.y]:
					into_slot = into_slot or (not duct["vertical"] and (is_equal_approx(a.y, y) or is_equal_approx(b.y, y)) and absf(a.x - b.x) <= 2.0 * absf(a.y - b.y) + 0.01)
			assert_true(is_equal_approx(a.x, b.x) or is_equal_approx(a.y, b.y) or into_slot, "%s-%s runs straight" % [wire["from"], wire["to"]])
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
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.build(9))
	if doc.switchboards.is_empty():
		doc.add_switchboard()
		doc.fill_cabinet(0)
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
	for rail: CabinetRail in doc.switchboards[0].rails:
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
		if wire["external"] and wire["cable"] == "W1":
			to_motor[wire["to"]] = wire
	assert_eq(to_motor.keys().size(), 4, "a core to each terminal of the motor's strip X2")
	assert_eq(to_motor["M1:U1"]["conductor"], CabinetDevices.Conductor.POWER)
	assert_eq(to_motor["M1:PE"]["conductor"], CabinetDevices.Conductor.PE)
	var gland: Dictionary = {}
	for g: Dictionary in wiring.glands:
		if g["cable"] == "W1":
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
		assert_true(g["cable"] in ["AC", "W1"], "only the supply and the motor cable, named like on the workspace")
	assert_eq(CabinetDevices.field_device(doc.circuit, "X5", CabinetDevices.nets(doc.circuit)), "", "the N terminal joins only devices inside")


func test_plc_example_is_wired() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.build(14))
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


func test_supply_lands_on_the_strip_terminal_of_its_supply_point() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.build(7))
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	var cores: Dictionary[String, String] = {}
	for wire: Dictionary in wiring.wires:
		if wire["external"] and wire["cable"] == "AC":
			cores[wire["from"]] = wire["to"]
	assert_eq(cores.size(), 5, "L1 L2 L3 N PE")
	for conductor: String in cores:
		assert_true(doc.circuit.get_terminal_owner(cores[conductor]) is PowerSupply, conductor + " lands on the terminal X1:" + conductor)



func test_wires_carry_their_numbers_on_marker_sleeves() -> void:
	var doc: SchematicDocument = _doc()
	doc.number_wires()
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	var numbers: Dictionary[int, String] = WorkspaceCables.wire_numbers(doc, net)
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	var control: Dictionary = _wire(wiring, "FU2:2", "KM1:13")
	assert_false(numbers.get(net["KM1:13"], "").is_empty(), "the net is numbered")
	assert_eq(control["mark"], numbers[net["KM1:13"]], "the wire number on the sleeves")
	assert_eq(_wire(wiring, "FU1:1", "FU2:1")["mark"], "L1", "a supply conductor without a number: its name")
	for wire: Dictionary in wiring.wires:
		if wire["external"] and wire["from"] == "N":
			assert_eq(wire["mark"], "N", "the cores of the supply cable too")
		assert_eq(wire["markers"].size(), 1 if wire["external"] else 2, "%s-%s: a sleeve at each terminal end, none where a core leaves its cable" % [wire["from"], wire["to"]])
	var points: PackedVector2Array = control["points"]
	var first: PackedVector2Array = control["markers"][0]
	assert_almost_eq(points[0].distance_to(first[0]), CabinetParts.MARKER_FROM, 0.01, "just behind the ferrule")
	assert_almost_eq(first[0].distance_to(first[1]), CabinetParts.marker_length(control["mark"]), 0.01)


## Sleeves of example 9 (star/delta: two power wires in terminals of the
## motor's strip), each as its wire and its outline.
func _sleeves(layout: CabinetLayout, wiring: CabinetWiring) -> Array[Array]:
	var result: Array[Array] = []
	for wire: Dictionary in wiring.wires:
		for span: PackedVector2Array in wire["markers"]:
			var r: Rect2 = Rect2(span[0], Vector2.ZERO).expand(span[1])
			var half: float = (wire["width"] + CabinetParts.MARKER_GROW) * 0.5 - 0.05
			result.append([wire, r.grow_individual(half, 0.0, half, 0.0) if r.size.x < r.size.y else r.grow_individual(0.0, half, 0.0, half)])
	return result


func test_marker_sleeves_keep_out_of_the_ducts_and_off_each_other() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(9)
	doc.number_wires()
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	for wire: Dictionary in wiring.wires:
		assert_eq(wire["markers"].size(), 1 if wire["external"] else 2, "%s-%s has room for its sleeves" % [wire["from"], wire["to"]])
	var sleeves: Array[Array] = _sleeves(layout, wiring)
	for i: int in sleeves.size():
		var outline: Rect2 = sleeves[i][1]
		for duct: Dictionary in layout.ducts:
			assert_false((duct["rect"] as Rect2).intersects(outline), "%s-%s: no sleeve in a duct" % [sleeves[i][0]["from"], sleeves[i][0]["to"]])
		for j: int in range(i + 1, sleeves.size()):
			assert_false(outline.intersects(sleeves[j][1]), "%s-%s and %s-%s: no sleeve covers another" % [sleeves[i][0]["from"], sleeves[i][0]["to"], sleeves[j][0]["from"], sleeves[j][0]["to"]])


func test_wires_in_one_terminal_spread_out_for_their_sleeves() -> void:
	var doc: SchematicDocument = _doc()
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	# L1 comes in to FU1:1 and goes on to FU2:1: two wires in FU1:1.
	var core: Dictionary = {}
	for wire: Dictionary in wiring.wires:
		if wire["external"] and wire["from"] == "L1":
			core = wire
	var jumper: Dictionary = _wire(wiring, "FU1:1", "FU2:1")
	var core_sleeve: PackedVector2Array = core["markers"][core["markers"].size() - 1]
	var jumper_sleeve: PackedVector2Array = jumper["markers"][0] if jumper["from"] == "FU1:1" else jumper["markers"][1]
	assert_almost_eq(core_sleeve[0].y, jumper_sleeve[0].y, 0.01, "side by side at one height")
	assert_true(absf(core_sleeve[0].x - jumper_sleeve[0].x) >= CabinetWiring.FAN - 0.01, "far enough apart for both sleeves")


func test_no_wire_goes_back_into_its_own_terminal() -> void:
	# The examples have supply points L1 and L1.2 of one conductor on strip
	# terminal X1:L1.
	for example: int in [0, 5, 9, 10]:
		var doc: SchematicDocument = ExampleCircuits.build(example)
		var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
		var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
		for wire: Dictionary in wiring.wires:
			var path: PackedVector2Array = wire["points"]
			assert_true(path[0].distance_to(path[path.size() - 1]) > CabinetWiring.FAN, "%d: %s-%s joins two terminals" % [example, wire["from"], wire["to"]])


## The end of [param wire] at terminal [param key] and how much of its
## ferrule shows there.
func _end_at(wire: Dictionary, key: String) -> Array:
	var path: PackedVector2Array = wire["points"]
	if wire["from"] == key:
		return [path[0], wire["pins"].x]
	return [path[path.size() - 1], wire["pins"].y]


func test_wires_go_into_the_face_of_their_terminals_tier() -> void:
	var doc: SchematicDocument = _doc()
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	var contactor: Vector2 = Vector2.ZERO
	for place: Dictionary in layout.places:
		if place["designation"] == "KM1":
			contactor = place["origin"]
	# KM1:1 in the outer tier: at the contactor's top face; KM1:13 in the
	# inner tier: at the step where it begins, its wire over the outer tier.
	var power: Array = _end_at(_wire(wiring, "FU1:2", "KM1:1"), "KM1:1")
	assert_almost_eq(float(power[0].y), contactor.y, 0.01, "the outer tier's top face")
	var control: Array = _end_at(_wire(wiring, "FU2:2", "KM1:13"), "KM1:13")
	assert_almost_eq(float(control[0].y), contactor.y + 5.1, 0.01, "the step to the inner tier")
	var screw: Vector3 = CabinetParts.terminal_points(CabinetDevices.Kind.CONTACTOR, CabinetDevices.describe(doc, "KM1"))["13"]
	assert_true(control[0].y < contactor.y + screw.y - screw.z, "past the screw, not onto it")
	assert_eq(control[1], 0.0, "the ferrule all the way in")
	# A strip terminal: the ferrule shows going into the push-in opening.
	var motor: Dictionary = _wire(wiring, "KM1:2", "M1:U1")
	assert_almost_eq(float(_end_at(motor, "M1:U1")[1]), CabinetParts.FERRULE, 0.001)


func test_labels_sit_on_the_plate_clear_of_the_ducts() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(14)
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var across: Array[Rect2] = []
	for duct: Dictionary in layout.ducts:
		if not duct["vertical"]:
			across.append(duct["rect"])
	for place: Dictionary in layout.places:
		var labels: Array[Vector2] = []
		if place["label_w"] > 0.0:
			labels.append(place["label_at"])
		if place.has("under_label_at"):
			labels.append(place["under_label_at"])
		for at: Vector2 in labels:
			var r: Rect2 = Rect2(at - Vector2(8.0, 2.6), Vector2(16.0, 5.2))
			for duct: Rect2 in across:
				assert_false(duct.intersects(r), "-%s: the label keeps off the duct" % place["designation"])
			var device: Rect2 = place["rect"]
			if not device.encloses(r):
				assert_true(absf(at.y - device.position.y) >= CabinetLayout.LABEL_OFF - 0.01 or absf(at.y - device.end.y) >= CabinetLayout.LABEL_OFF - 0.01 or place.has("under_rect"), "-%s: past the wire ends" % place["designation"])


func test_lanes_keep_wires_easy_to_follow() -> void:
	var wiring: CabinetWiring = CabinetWiring.new()
	var counts: Array[int] = []
	# Both in over the top: the one nested in the other nearer the top, and
	# one beside them sharing its lane.
	var lanes: PackedFloat32Array = wiring._lanes([
		{"from": 10.0, "to": 100.0, "edge": -1},
		{"from": 40.0, "to": 60.0, "edge": -1},
		{"from": 110.0, "to": 130.0, "edge": -1},
	], 0.0, 40.0, counts)
	assert_true(lanes[1] < lanes[0], "the nested run nearer the edge its wires come in over")
	assert_eq(lanes[2], lanes[1], "runs side by side share a lane")
	assert_eq(counts, [2] as Array[int])
	# In over the bottom: mirrored.
	lanes = wiring._lanes([
		{"from": 10.0, "to": 100.0, "edge": 1},
		{"from": 40.0, "to": 60.0, "edge": 1},
		{"from": 20.0, "to": 70.0, "edge": -1},
	], 0.0, 40.0, counts)
	assert_true(lanes[1] > lanes[0], "nearer the bottom edge")
	assert_true(lanes[2] < lanes[0] and lanes[2] < lanes[1], "those from the top above them")
	# In over the top and out over the bottom, both heading right: the one
	# coming in further right higher, so neither crosses the other.
	lanes = wiring._lanes([
		{"from": 10.0, "to": 50.0, "edge": 0, "in": 10.0},
		{"from": 20.0, "to": 60.0, "edge": 0, "in": 20.0},
	], 0.0, 40.0, counts)
	assert_true(lanes[1] < lanes[0])


func test_wires_from_a_contactors_outputs_go_behind_its_overload_relay() -> void:
	# Forward / reverse: KM2's outputs carry the overload relay's heaters and
	# are wired on to KM1's.
	var doc: SchematicDocument = ExampleCircuits.build(6)
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0)
	var relay: Rect2 = Rect2()
	var place: Dictionary = {}
	for p: Dictionary in layout.places:
		if p.has("under_rect"):
			relay = p["under_rect"]
			place = p
	assert_true(relay.has_area(), "an overload relay under a contactor")
	var columns: Array[float] = []
	for x: float in CabinetParts.OVERLOAD_OUT_X + CabinetParts.OVERLOAD_AUX_X:
		columns.append(relay.position.x + x)
	var found: int = 0
	for pole: int in 3:
		var key: String = place["desc"]["terminals"][str(2 * pole + 2)]
		for wire: Dictionary in wiring.wires:
			if wire["from"] != key and wire["to"] != key:
				continue
			found += 1
			var path: PackedVector2Array = wire["points"]
			var out: Vector2 = path[0] if wire["from"] == key else path[path.size() - 1]
			assert_almost_eq(out.y, relay.end.y, 0.01, "%s: comes out under the relay" % key)
			assert_eq(wire["pins"].x if wire["from"] == key else wire["pins"].y, -1.0, "its end out of sight")
			for x: float in columns:
				assert_true(absf(out.x - x) > CabinetWiring.WIRE_W, "%s: in a column clear of the relay's own wires" % key)
			for i: int in path.size() - 1:
				var segment: Rect2 = Rect2(path[i], Vector2.ZERO).expand(path[i + 1])
				assert_false(relay.grow(-0.5).intersects(segment), "%s: nothing of it over the relay" % key)
	assert_true(found > 0, "KM2's outputs are wired on")


func test_wires_cross_only_in_the_ducts() -> void:
	# Each wire bends once past its sleeve and slants into its slot; the slots
	# take them in the order of their terminals, so wires heading apart cross
	# in the duct, never on the plate.
	for example: int in [1, 6, 9, 14]:
		var doc: SchematicDocument = ExampleCircuits.build(example)
		doc.number_wires()
		var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
		var wiring: CabinetWiring = layout.wiring
		var segments: Array = []
		for w: int in wiring.wires.size():
			var path: PackedVector2Array = wiring.wires[w]["points"]
			for i: int in path.size() - 1:
				segments.append([w, path[i], path[i + 1]])
		for i: int in segments.size():
			for j: int in range(i + 1, segments.size()):
				if segments[i][0] == segments[j][0]:
					continue
				var hit: Variant = Geometry2D.segment_intersects_segment(segments[i][1], segments[i][2], segments[j][1], segments[j][2])
				if hit == null:
					continue
				var at: Vector2 = hit
				var ends: bool = false
				for k: int in [i, j]:
					ends = ends or at.distance_to(segments[k][1]) < 0.01 or at.distance_to(segments[k][2]) < 0.01
				if ends:
					continue
				var in_duct: bool = false
				for duct: Dictionary in layout.ducts:
					in_duct = in_duct or (duct["rect"] as Rect2).grow(0.5).has_point(at)
				var a: Dictionary = wiring.wires[segments[i][0]]
				var b: Dictionary = wiring.wires[segments[j][0]]
				assert_true(in_duct, "%d: %s-%s and %s-%s cross at %s, out of a duct" % [example, a["from"], a["to"], b["from"], b["to"], at])


func test_neighbouring_strip_terminals_of_one_net_are_bridged() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(6)
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var wiring: CabinetWiring = layout.wiring
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	var bridged: int = 0
	for place: Dictionary in layout.places:
		if place["kind"] != CabinetLayout.STRIP:
			continue
		var terminals: Array = place["desc"]["terminals"]
		var bridges: Array = place["desc"]["bridges"]
		assert_eq(bridges.size(), terminals.size() - 1, "one between each two neighbours")
		for i: int in bridges.size():
			var a: int = net.get(terminals[i]["keys"][0], -1)
			var b: int = net.get(terminals[i + 1]["keys"][0], -2)
			assert_eq(bridges[i], a == b, "-%s: %s and %s bridged when they are on one net" % [place["designation"], terminals[i]["label"], terminals[i + 1]["label"]])
			if not bridges[i]:
				continue
			bridged += 1
			# No wire between them: the bridge joins them.
			var keys: Array = [terminals[i]["keys"], terminals[i + 1]["keys"]]
			for wire: Dictionary in wiring.wires:
				assert_false((keys[0].has(wire["from"]) and keys[1].has(wire["to"])) or (keys[1].has(wire["from"]) and keys[0].has(wire["to"])), "-%s: no wire between bridged %s and %s" % [place["designation"], terminals[i]["label"], terminals[i + 1]["label"]])
	assert_true(bridged > 0, "the example has neighbouring terminals of one net")
	# The parts list has the bridges.
	var names: Array = []
	for row: Dictionary in PartsList.new().rows(doc):
		names.append(row.get("name", ""))
	assert_true(names.has("Plug-in bridge"))


func test_no_terminal_takes_more_than_two_wires() -> void:
	# Nets are looped from terminal to terminal where they would branch;
	# terminals joined by a plug-in bridge take no wire between them.
	for example: int in range(15):
		var doc: SchematicDocument = ExampleCircuits.build(example)
		var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
		var clamps: Dictionary[String, int] = {}
		for wire: Dictionary in layout.wiring.wires:
			var path: PackedVector2Array = wire["points"]
			for end: int in range(1 if wire["external"] else 0, 2):
				var at: Vector2 = path[0] if end == 0 else path[path.size() - 1]
				var key: String = str(wire["from"] if end == 0 else wire["to"])
				# Top and bottom of a strip terminal are clamps of their own.
				var clamp: String = "%s@%d" % [key, roundi(at.y)]
				clamps[clamp] = clamps.get(clamp, 0) + 1
		for clamp: String in clamps:
			assert_true(clamps[clamp] <= CabinetWiring.CLAMP_WIRES, "%d: %s takes %d wires" % [example, clamp, clamps[clamp]])


## [param motors] motors on terminal strip X2, each with its PE terminal
## there; the supply with its PE on strip X1.
func _motors(motors: int) -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("pe")
	var supplies: Array[PowerSupply] = []
	for s: Array in [["L1", PowerSupply.Conductor.L], ["L2", PowerSupply.Conductor.L2], ["L3", PowerSupply.Conductor.L3], ["PE", PowerSupply.Conductor.PE]]:
		var supply: PowerSupply = PowerSupply.new(s[0], s[1])
		doc.add(supply, Vector2i(4 * supplies.size(), 0))
		supplies.append(supply)
	doc.set_strip_terminal(supplies[3].id, 0, "X1:PE")
	for m: int in motors:
		var fuse: ThreePoleFuse = ThreePoleFuse.new("FU%d" % (m + 1))
		doc.add(fuse, Vector2i(8 * m, 4))
		var motor: ThreePhaseMotor = ThreePhaseMotor.new("M%d" % (m + 1))
		doc.add(motor, Vector2i(8 * m, 12))
		for pole: int in 3:
			doc.connect_terminals(["L1", "L2", "L3"][pole], "FU%d:%d" % [m + 1, 2 * pole + 1])
			doc.connect_terminals("FU%d:%d" % [m + 1, 2 * pole + 2], "M%d:%s" % [m + 1, ["U1", "V1", "W1"][pole]])
			doc.set_strip_terminal(motor.id, pole, "X2:%d" % (3 * m + pole + 1))
		doc.connect_terminals("M%d:PE" % (m + 1), "PE")
		doc.set_strip_terminal(motor.id, 3, "X2:PE%d" % (m + 1))
	doc.add_switchboard()
	doc.fill_cabinet(0)
	return doc


func test_pe_goes_through_a_distribution_block_for_more_than_two_loads() -> void:
	var two: CabinetLayout = CabinetLayout.build(_motors(2), 2.0)
	for place: Dictionary in two.places:
		assert_ne(place["kind"], CabinetLayout.PE_BLOCK, "two loads: no block")
	var doc: SchematicDocument = _motors(3)
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0)
	var block: Dictionary = {}
	var strip_x1: Dictionary = {}
	for place: Dictionary in layout.places:
		if place["kind"] == CabinetLayout.PE_BLOCK:
			block = place
		elif place["kind"] == CabinetLayout.STRIP and place["designation"] == "X1":
			strip_x1 = place
	assert_false(block.is_empty(), "three loads: a PE distribution block")
	assert_eq(block["desc"]["connections"], CabinetParts.PE_SIZES[0], "the smallest size taking the loads and the incoming PE")
	assert_eq(block["index"], -1, "added by the switchboard, not an item of the rail")
	assert_eq(block["rail"], strip_x1["rail"], "on the rail of the strip the incoming PE lands on")
	assert_true(block["origin"].x > strip_x1["origin"].x, "right after it")
	# A star: every PE wire inside the switchboard goes to the block, one to
	# each of its connections.
	var used: Dictionary[float, int] = {}
	var pe_wires: int = 0
	for wire: Dictionary in layout.wiring.wires:
		if wire["conductor"] != CabinetDevices.Conductor.PE or wire["external"]:
			continue
		pe_wires += 1
		var path: PackedVector2Array = wire["points"]
		var at_block: Array[Vector2] = []
		for end: Vector2 in [path[0], path[path.size() - 1]]:
			if (block["rect"] as Rect2).grow(0.1).has_point(end):
				at_block.append(end)
		assert_eq(at_block.size(), 1, "%s-%s: from the block" % [wire["from"], wire["to"]])
		if at_block.size() == 1:
			used[snappedf(at_block[0].x, 0.01)] = used.get(snappedf(at_block[0].x, 0.01), 0) + 1
	assert_eq(pe_wires, 4, "the incoming PE and the three motors'")
	for x: float in used:
		assert_eq(used[x], 1, "one wire in each connection")
	var names: Array = []
	for row: Dictionary in PartsList.new().rows(doc):
		names.append(row.get("name", ""))
	assert_true(names.has("PE distribution block"), "in the parts list")
