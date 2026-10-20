extends GutTest
## PLCs talking over Ethernet: network inputs NI / NAI read an operand of
## the PLC at an IP address on the same network (a cable between two ports,
## or a working network switch joining more).
##
## L - S1 (button NO 13-14) - A1 I1; A1 Q1 = I1
## A2 Q1.1-Q1.2 switches H2; A2 Q1 = NI1 (A1 Q1)
## A3 Q1.1-Q1.2 switches H3; A3 Q1 = NI1 (A1 Q1)

const NO := SwitchingElement.ContactType.NO

var circuit: Circuit
var sim: Simulator
var a1: Plc
var a2: Plc
var a3: Plc
var kf1: NetworkSwitch
var s1: PushButton
var h2: Lamp
var h3: Lamp


## Q1 = I1.
func _source_program() -> PlcProgram:
	var p: PlcProgram = PlcProgram.new()
	var i1: PlcBlock = p.add_block("input", Vector2i(0, 0))
	var q1: PlcBlock = p.add_block("output", Vector2i(4, 0))
	q1.inputs[0] = i1.id
	return p


## Q1 = NI1, NI1 reading Q1 of the PLC at [param ip].
func _reader_program(ip: String) -> PlcProgram:
	var p: PlcProgram = PlcProgram.new()
	var ni: PlcBlock = p.add_block("network_input", Vector2i(0, 0))
	var q1: PlcBlock = p.add_block("output", Vector2i(4, 0))
	q1.inputs[0] = ni.id
	p.set_network_source("NI1", ip, "Q1")
	return p


func _build(realistic: bool = false) -> void:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("L", PowerSupply.Conductor.L))
	circuit.add(PowerSupply.new("N", PowerSupply.Conductor.N))
	circuit.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS))
	circuit.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS))
	a1 = circuit.add(Plc.new("A1", _source_program())) as Plc
	a2 = circuit.add(Plc.new("A2", _reader_program("192.168.0.1"))) as Plc
	a2.ip_address = "192.168.0.2"
	a3 = circuit.add(Plc.new("A3", _reader_program("192.168.0.1"))) as Plc
	a3.ip_address = "192.168.0.3"
	kf1 = circuit.add(NetworkSwitch.new("KF1")) as NetworkSwitch
	s1 = circuit.add(PushButton.new("S1", NO)) as PushButton
	h2 = circuit.add(Lamp.new("H2")) as Lamp
	h3 = circuit.add(Lamp.new("H3")) as Lamp
	for plc: String in ["A1", "A2", "A3"]:
		circuit.connect_terminals("L", plc + ":L1")
		circuit.connect_terminals(plc + ":N", "N")
	circuit.connect_terminals("L", "S1:13")
	circuit.connect_terminals("S1:14", "A1:I1")
	circuit.connect_terminals("L", "A2:Q1.1")
	circuit.connect_terminals("A2:Q1.2", "H2:X1")
	circuit.connect_terminals("H2:X2", "N")
	circuit.connect_terminals("L", "A3:Q1.1")
	circuit.connect_terminals("A3:Q1.2", "H3:X1")
	circuit.connect_terminals("H3:X2", "N")
	circuit.connect_terminals("+", "KF1:L+")
	circuit.connect_terminals("KF1:M", "-")
	sim = Simulator.new(circuit)
	sim.mode = Simulator.Mode.REALISTIC if realistic else Simulator.Mode.IDEAL


func _break_wire_to(key: String) -> void:
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for w: int in wires.size():
		if wires[w].has(key):
			circuit.set_wire_broken(w, true)


func _press(on: bool) -> void:
	if on:
		s1.press()
	else:
		s1.release()
	if sim.mode == Simulator.Mode.REALISTIC:
		sim.step(0.1)
	else:
		sim.step()


func test_operand_areas_of_more_letters() -> void:
	assert_eq(PlcProgram.area_list("IQMTCNI"), PackedStringArray(["I", "Q", "M", "T", "C", "NI"]))
	assert_eq(PlcProgram.area_list("AINAI"), PackedStringArray(["AI", "NAI"]))
	assert_eq(PlcProgram.area_list("AIAQ"), PackedStringArray(["AI", "AQ"]))
	assert_eq(PlcProgram.area_of("NI12"), "NI")
	assert_eq(PlcProgram.area_of("NAI3"), "NAI")
	assert_true(PlcProgram.valid_operand("NI64", "IQMTCNI"))
	assert_false(PlcProgram.valid_operand("NI65", "IQMTCNI"))
	assert_false(PlcProgram.valid_operand("NAI1", "IQMTCNI"))


func test_network_sources_are_checked_and_saved() -> void:
	var p: PlcProgram = PlcProgram.new()
	p.set_network_source("NI1", "192.168.0.7", "M3")
	p.set_network_source("NI2", "192.168.0.300", "Q1")
	p.set_network_source("NI3", "192.168.0.7", "AI1")
	p.set_network_source("NAI1", "10.0.0.2", "AQ2")
	assert_eq(p.network.keys(), ["NI1", "NAI1"])
	var copy: PlcProgram = PlcProgram.from_data(JSON.parse_string(JSON.stringify(p.to_data())))
	assert_eq(copy.network_source("NI1"), {"ip": "192.168.0.7", "operand": "M3"})
	assert_eq(copy.network_source("NAI1"), {"ip": "10.0.0.2", "operand": "AQ2"})
	p.set_network_source("NI1", "", "")
	assert_false(p.network.has("NI1"))


func test_port_is_the_last_terminal() -> void:
	var plc: Plc = Plc.new("A1", null, [Plc.Module.DI4_DQ4])
	var names: PackedStringArray = plc.get_terminal_names()
	assert_eq(names[names.size() - 1], "P1")
	assert_eq(plc.port_terminal(), names.size() - 1)
	assert_eq(plc.terminal_role(plc.port_terminal()), Plc.Role.NET)
	assert_eq(plc.module_terminals(0).y, plc.port_terminal())
	var cpu: CompactPlc = CompactPlc.new("A1")
	assert_eq(cpu.get_terminal_names()[cpu.port_terminal()], "P1")


func test_direct_cable_between_two_plcs() -> void:
	_build()
	circuit.connect_terminals("A1:P1", "A2:P1")
	sim.step()
	assert_false(h2.energized)
	_press(true)
	assert_true(a1.runtime.outputs[0] == 1)
	assert_true(h2.energized, "A2 reads Q1 of A1 over the cable")
	assert_true(a1.port_link and a2.port_link)
	assert_false(h3.energized, "A3 has no cable")
	_press(false)
	assert_false(h2.energized)


func test_direct_cable_realistic() -> void:
	_build(true)
	circuit.connect_terminals("A1:P1", "A2:P1")
	sim.step(0.1)
	_press(true)
	assert_true(h2.energized)
	_press(false)
	assert_false(h2.energized)


func test_three_ports_on_one_cable_do_not_work() -> void:
	_build()
	circuit.connect_terminals("A1:P1", "A2:P1")
	circuit.connect_terminals("A1:P1", "A3:P1")
	sim.step()
	_press(true)
	assert_false(h2.energized)
	assert_false(h3.energized)


func test_switch_joins_three_plcs() -> void:
	_build()
	circuit.connect_terminals("A1:P1", "KF1:P1")
	circuit.connect_terminals("A2:P1", "KF1:P2")
	circuit.connect_terminals("A3:P1", "KF1:P4")
	sim.step()
	assert_true(kf1.energized)
	assert_eq(kf1.links, PackedByteArray([1, 1, 0, 1]))
	_press(true)
	assert_true(h2.energized)
	assert_true(h3.energized)
	_press(false)
	assert_false(h3.energized)


func test_switch_without_supply_joins_nothing() -> void:
	_build()
	circuit.connect_terminals("A1:P1", "KF1:P1")
	circuit.connect_terminals("A2:P1", "KF1:P2")
	_break_wire_to("KF1:L+")
	sim.step()
	assert_false(kf1.energized)
	_press(true)
	assert_false(h2.energized)


func test_connection_is_logged() -> void:
	_build(true)
	circuit.connect_terminals("A1:P1", "A2:P1")
	sim.step(0.1)
	var texts: PackedStringArray = PackedStringArray()
	for e: Dictionary in sim.last_result.events:
		texts.append(e["text"] % e["args"])
	assert_has(texts, "A2: connection to A1 (192.168.0.1) established")


func test_duplicate_address_breaks_the_connection() -> void:
	_build()
	circuit.connect_terminals("A1:P1", "KF1:P1")
	circuit.connect_terminals("A2:P1", "KF1:P2")
	circuit.connect_terminals("A3:P1", "KF1:P3")
	a3.ip_address = "192.168.0.1"
	sim.step()
	_press(true)
	assert_false(h2.energized, "two PLCs answer at 192.168.0.1")


func test_other_subnet_is_not_reached() -> void:
	_build()
	circuit.connect_terminals("A1:P1", "A2:P1")
	a2.ip_address = "192.168.1.2"
	sim.step()
	_press(true)
	assert_false(h2.energized)


func test_partner_switched_off_reads_zero() -> void:
	_build()
	circuit.connect_terminals("A1:P1", "A2:P1")
	s1.press()
	sim.step()
	assert_true(h2.energized)
	_break_wire_to("A1:L1")
	sim.step()
	assert_false(a1.energized)
	assert_false(h2.energized)


func test_network_analog_input() -> void:
	_build()
	circuit.connect_terminals("A1:P1", "A2:P1")
	var p: PlcProgram = a2.program
	p.blocks.clear()
	var nai: PlcBlock = p.add_block("network_analog_input", Vector2i(0, 0))
	nai.operand = "NAI2"
	var trigger: PlcBlock = p.add_block("analog_threshold", Vector2i(4, 0))
	trigger.inputs[0] = nai.id
	var q1: PlcBlock = p.add_block("output", Vector2i(8, 0))
	q1.inputs[0] = trigger.id
	p.set_network_source("NAI2", "192.168.0.1", "AQ1")
	var source: PlcProgram = a1.program
	var hi: PlcBlock = source.add_block("hi", Vector2i(0, 6))
	var amp: PlcBlock = source.add_block("analog_amplifier", Vector2i(4, 6))
	amp.inputs[0] = hi.id
	amp.gain = 0.6
	var aq: PlcBlock = source.add_block("analog_output", Vector2i(8, 6))
	aq.inputs[0] = amp.id
	a1.runtime.reset()
	a2.runtime.reset()
	sim.step()
	assert_almost_eq(a2.runtime.analog_value("NAI2"), 600.0, 0.01)
	assert_true(h2.energized, "600 is above the threshold's 500")


func test_ladder_contact_reads_a_network_input() -> void:
	_build()
	circuit.connect_terminals("A1:P1", "A2:P1")
	var p: PlcProgram = a2.program
	p.language = PlcProgram.Language.LAD
	var rung: PlcRung = p.ladder()
	rung.set_cell(0, 0, {"kind": "no", "operand": "NI1"})
	for c: int in range(1, PlcRung.COLUMNS):
		rung.set_cell(0, c, {"kind": "wire"})
	rung.set_coil(0, {"kind": "coil", "operand": "Q1"})
	a2.runtime.reset()
	sim.step()
	_press(true)
	assert_true(h2.energized)


# --- Schematic, files, switchboards, cables --------------------------------------

## A1 and the switch KF1 in +RA1, A3 in +RA2: A1 P1 - KF1 P1, A3 P1 - KF1 P2.
func _doc() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("network")
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 40))
	doc.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS), Vector2i(-10, 0))
	doc.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS), Vector2i(-10, 40))
	var a3: Plc = Plc.new("A3", _reader_program("192.168.0.1"))
	a3.ip_address = "192.168.0.3"
	doc.add(a3, Vector2i(60, 10))
	doc.add(Plc.new("A1", _source_program()), Vector2i(10, 10))
	doc.add(NetworkSwitch.new("KF1"), Vector2i(10, 30))
	for plc: String in ["A1", "A3"]:
		doc.connect_terminals("L", plc + ":L1")
		doc.connect_terminals(plc + ":N", "N")
	doc.connect_terminals("+", "KF1:L+")
	doc.connect_terminals("KF1:M", "-")
	doc.connect_terminals("A1:P1", "KF1:P1")
	doc.connect_terminals("A3:P1", "KF1:P2")
	doc.add_switchboard()
	doc.add_cabinet_rail(0)
	doc.add_cabinet_item(0, 0, CabinetItem.Kind.DEVICE, "A1")
	doc.add_cabinet_item(0, 0, CabinetItem.Kind.DEVICE, "KF1")
	doc.add_switchboard()
	doc.add_cabinet_rail(1)
	doc.add_cabinet_item(1, 0, CabinetItem.Kind.DEVICE, "A3")
	return doc


func test_plc_address_and_switch_saved_and_loaded() -> void:
	var doc: SchematicDocument = _doc()
	var copy: SchematicDocument = ProjectFile.from_dict(JSON.parse_string(JSON.stringify(ProjectFile.to_dict(doc))))["document"]
	var a3: Plc = copy.circuit.get_component("A3") as Plc
	assert_eq(a3.ip_address, "192.168.0.3")
	assert_eq(a3.program.network_source("NI1"), {"ip": "192.168.0.1", "operand": "Q1"})
	assert_true(copy.circuit.get_component("KF1") is NetworkSwitch)
	assert_eq(copy.circuit.get_wires().size(), doc.circuit.get_wires().size(), "the Ethernet cables too")
	var old: Plc = DocumentSerializer.component_from_dict({"type": "plc", "designation": "A4"}) as Plc
	assert_eq(old.ip_address, Plc.DEFAULT_IP, "older files: the default address")


func test_older_custom_terminal_names_get_the_port() -> void:
	var names: Array = Array(Plc.new("A1").default_terminal_names().slice(0, 18))
	names[2] = "E1"
	var plc: Plc = DocumentSerializer.component_from_dict({"type": "plc", "designation": "A1", "terminals": names}) as Plc
	assert_not_null(plc)
	assert_eq(plc.get_terminal_names()[2], "E1", "the names given by hand stay")
	assert_eq(plc.get_terminal_names()[plc.port_terminal()], Plc.PORT_NAME)


func test_new_and_pasted_plcs_take_a_free_address() -> void:
	var doc: SchematicDocument = _doc()
	assert_eq(doc.next_ip(), "192.168.0.2")
	var data: Dictionary = doc.extract(PackedStringArray(["A1"]))
	var ids: PackedStringArray = doc.insert(data, Vector2i(0, 60))
	assert_eq(ids.size(), 1)
	assert_eq((doc.circuit.get_component(ids[0]) as Plc).ip_address, "192.168.0.2")


func test_check_finds_ethernet_mistakes() -> void:
	var doc: SchematicDocument = _doc()
	assert_eq(_texts(doc), PackedStringArray(), "a clean network")
	(doc.circuit.get_component("A3") as Plc).ip_address = "192.168.0.1"
	assert_has(_texts(doc), "PLCs %s and %s have the same IP address %s on one network.")
	(doc.circuit.get_component("A3") as Plc).ip_address = "192.168.0.3"
	(doc.circuit.get_component("A3") as Plc).program.set_network_source("NI2", "192.168.0.9", "M1")
	assert_has(_texts(doc), "Network input %s of %s reads from %s, but no PLC on its network has that IP address.")
	doc.connect_terminals("L", "KF1:P4")
	assert_has(_texts(doc), "Ethernet port %s is wired to %s: an Ethernet cable joins two ports only.")


func test_check_wants_a_switch_for_more_than_two() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	for name: String in ["A1", "A2", "A3"]:
		doc.add(Plc.new(name), Vector2i(0, 10 * doc.circuit.get_components().size()))
	doc.connect_terminals("A1:P1", "A2:P1")
	doc.connect_terminals("A2:P1", "A3:P1")
	var found: bool = false
	for issue: Dictionary in CircuitCheck.run(doc):
		found = found or issue["text"] == "The Ethernet cable from %s joins %s ports: more than two are joined only through a network switch."
	assert_true(found)


func _texts(doc: SchematicDocument) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for issue: Dictionary in CircuitCheck.run(doc):
		if str(issue["text"]).contains("Ethernet") or str(issue["text"]).contains("IP address") or str(issue["text"]).contains("Network input"):
			texts.append(issue["text"])
	return texts


func test_ethernet_cable_between_switchboards() -> void:
	var doc: SchematicDocument = _doc()
	var ethernet: Array[Dictionary] = []
	for cable: Dictionary in WorkspaceCables.cables(doc):
		if cable["use"] == WorkspaceCables.Use.ETHERNET:
			ethernet.append(cable)
	assert_eq(ethernet.size(), 1, "a cable of its own, not a core of the control cable")
	assert_eq(ethernet[0]["key"], "+RA1|+RA2|KF1:P2")
	assert_eq(WorkspaceCables.type_text(ethernet[0]), "Cat 6 S/FTP 4x2xAWG23")
	assert_eq((ethernet[0]["cores"] as Array).size(), 1)
	assert_eq(ethernet[0]["cores"][0]["a"], PackedStringArray(["KF1:P2"]))
	assert_eq(ethernet[0]["cores"][0]["b"], PackedStringArray(["A3:P1"]))
	assert_true(WorkspaceCables.voltage_drop(doc, ethernet[0]).is_empty(), "it carries no load current")


func test_switchboard_wires_ethernet_cables_with_plugs() -> void:
	var doc: SchematicDocument = _doc()
	var layout: CabinetLayout = CabinetLayout.build(doc, 2.0, 0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 2.0, 0)
	var inside: Array[Dictionary] = []
	var out: Array[Dictionary] = []
	for wire: Dictionary in wiring.wires:
		if wire["conductor"] != CabinetDevices.Conductor.NETWORK:
			continue
		assert_eq(wire["width"], CabinetWiring.NETWORK_W)
		assert_eq(wire["mark"], "", "no marker sleeves: Ethernet cables have no wire number")
		(out if wire["external"] else inside).append(wire)
	assert_eq(inside.size(), 1, "A1 to the switch, in the ducts")
	assert_eq(out.size(), 1, "the switch's port P2 out to A3 in +RA2")
	var gland: bool = false
	for g: Dictionary in wiring.glands:
		gland = gland or (g["bottom"] and g["cable"] == "W2")
	assert_true(gland, "the cable leaves through a gland of its own")


func test_numbering_leaves_ethernet_cables_out() -> void:
	var doc: SchematicDocument = _doc()
	doc.number_wires()
	var network: Dictionary[int, bool] = doc.network_wires()
	assert_eq(network.size(), 2)
	for w: int in network:
		assert_eq(doc.get_route(w).number, "")


func test_facing_ports_pair_with_ports_only() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(NetworkSwitch.new("KF1"), Vector2i(0, 0))
	# Turned round under it: its ports face those of KF1 (P1 under KF1's P4).
	doc.add(NetworkSwitch.new("KF2"), Vector2i(8, 12), 2)
	# A lamp's X1 straight under KF1's port P1, facing it.
	doc.add(Lamp.new("H1"), Vector2i(0, 8))
	var pairs: Array[PackedStringArray] = doc.facing_pairs(PackedStringArray(["KF1"]), PackedStringArray(["KF2", "H1"]))
	assert_eq(pairs.size(), 3, "port to port")
	for pair: PackedStringArray in pairs:
		assert_false(pair.has("H1:X1"), "never a port to a lamp")
