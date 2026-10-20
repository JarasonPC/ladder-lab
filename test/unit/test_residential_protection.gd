extends GutTest
## House installations, protection and appliances: residual current devices
## (RCD, RCBO) tripping on what does not come back through them, arc fault
## detection devices tripping on a loose connection that arcs, appliances
## wired for good or plugged into sockets drawing their power, and the
## insulation fault that puts a phase on an appliance's frame.


## L1, N and PE; RCD FB1 (2 poles) feeding breaker FA1 (B16), feeding
## socket XD1 with appliance [param plugged] plugged in. Everything on.
func _socket_circuit(plugged: int = Appliance.Kind.KETTLE) -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("socket")
	doc.residential = true
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(4, 0))
	doc.add(PowerSupply.new("PE", PowerSupply.Conductor.PE), Vector2i(12, 0))
	var rcd: ResidualCurrentDevice = ResidualCurrentDevice.new("FB1")
	rcd.switched_on = true
	doc.add(rcd, Vector2i(0, 4))
	var breaker: CircuitBreaker = CircuitBreaker.new("FA1")
	breaker.characteristic = CircuitBreaker.Characteristic.B
	breaker.rated_current = 16.0
	breaker.switched_on = true
	doc.add(breaker, Vector2i(0, 10))
	var socket: SocketOutlet = SocketOutlet.new("XD1")
	socket.plug(plugged)
	doc.add(socket, Vector2i(0, 16))
	for pair: Array in [["L1", "FB1:1"], ["N", "FB1:N"], ["FB1:2", "FA1:1"], ["FA1:2", "XD1:L"], ["FB1:N'", "XD1:N"], ["PE", "XD1:PE"]]:
		assert_true(doc.connect_terminals(pair[0], pair[1]), "%s - %s" % pair)
	return doc


func _rcd(doc: SchematicDocument) -> ResidualCurrentDevice:
	return doc.circuit.get_component("FB1:1-2-N-N'") as ResidualCurrentDevice


func test_terminals_and_saved() -> void:
	var rcd: ResidualCurrentDevice = ResidualCurrentDevice.new("FB1")
	assert_eq(rcd.get_terminal_names(), PackedStringArray(["1", "2", "N", "N'"]))
	rcd.poles = 3
	assert_eq(rcd.poles, 4, "2 or 4 poles")
	assert_eq(rcd.get_terminal_names(), PackedStringArray(["1", "2", "3", "4", "5", "6", "N", "N'"]))
	rcd.residual_rating = 0.1
	rcd.overcurrent = true
	rcd.characteristic = CircuitBreaker.Characteristic.C
	rcd.rated_current = 20.0
	var again: ResidualCurrentDevice = DocumentSerializer.component_from_dict(DocumentSerializer.component_to_dict(rcd)) as ResidualCurrentDevice
	assert_eq(again.poles, 4)
	assert_almost_eq(again.residual_rating, 0.1, 0.0001)
	assert_true(again.overcurrent)
	assert_eq(again.characteristic, CircuitBreaker.Characteristic.C)
	assert_almost_eq(again.rated_current, 20.0, 0.001)
	var afdd: ArcFaultDevice = DocumentSerializer.component_from_dict({"type": "afdd", "designation": "FB2", "rated_current": 10.0}) as ArcFaultDevice
	assert_eq(afdd.get_terminal_names(), PackedStringArray(["1", "2", "N", "N'"]))
	assert_almost_eq(afdd.rated_current, 10.0, 0.001)
	var hob: Appliance = Appliance.new("EB1", Appliance.Kind.HOB)
	assert_true(hob.two_phases, "a hob between two phases")
	assert_eq(hob.get_terminal_names(), PackedStringArray(["L1", "L2", "PE"]))
	hob.power = 7000.0
	var hob_again: Appliance = DocumentSerializer.component_from_dict(DocumentSerializer.component_to_dict(hob)) as Appliance
	assert_eq(hob_again.kind, Appliance.Kind.HOB)
	assert_almost_eq(hob_again.power, 7000.0, 0.01)
	assert_eq(hob_again.rating, "400v")
	var socket: SocketOutlet = SocketOutlet.new("XD1")
	socket.plug(Appliance.Kind.MICROWAVE)
	var socket_again: SocketOutlet = DocumentSerializer.component_from_dict(DocumentSerializer.component_to_dict(socket)) as SocketOutlet
	assert_eq(socket_again.plugged, Appliance.Kind.MICROWAVE)
	assert_almost_eq(socket_again.plugged_power, 1200.0, 0.01)
	socket.plug(Appliance.Kind.HOB)
	assert_eq(socket.plugged, -1, "a hob is not plugged in")


func test_plugged_kettle_draws_and_the_rcd_holds() -> void:
	var doc: SchematicDocument = _socket_circuit()
	var sim: Simulator = Simulator.new(doc.circuit)
	var r: StepResult = sim.step()
	var socket: SocketOutlet = doc.circuit.get_component("XD1") as SocketOutlet
	assert_true(socket.energized)
	assert_almost_eq(r.terminal_currents.get("XD1:L", 0.0), 2000.0 / 230.0, 0.05, "the kettle's current")
	assert_false(_rcd(doc).tripped, "all of it comes back on N")
	socket.plug(-1)
	r = sim.step()
	assert_eq(r.terminal_currents.get("XD1:L", 0.0), 0.0, "nothing plugged in, nothing drawn")


func test_neutral_taken_past_the_rcd_trips_it() -> void:
	var doc: SchematicDocument = _socket_circuit()
	# The socket's N to the N before the RCD: its current goes back past it.
	var wires: Array[PackedStringArray] = doc.circuit.get_wires()
	for w: int in wires.size():
		if wires[w][0] == "FB1:N'" or wires[w][1] == "FB1:N'":
			doc.remove_wire(w)
			break
	assert_true(doc.connect_terminals("N", "XD1:N"))
	var sim: Simulator = Simulator.new(doc.circuit)
	var r: StepResult = sim.step()
	assert_true(_rcd(doc).tripped, "8.7 A out, nothing back through it")
	var logged: bool = false
	for event: Dictionary in r.events:
		logged = logged or str(event["text"]).contains("residual current")
	assert_true(logged, "logged with its residual current")
	assert_false((doc.circuit.get_component("XD1") as SocketOutlet).energized)


func test_insulation_fault_trips_the_rcd() -> void:
	var doc: SchematicDocument = _socket_circuit()
	doc.add(Appliance.new("EB1", Appliance.Kind.WATER_HEATER), Vector2i(20, 16))
	for pair: Array in [["FA1:2", "EB1:L"], ["FB1:N'", "EB1:N"], ["PE", "EB1:PE"]]:
		assert_true(doc.connect_terminals(pair[0], pair[1]))
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.step()
	var heater: Appliance = doc.circuit.get_component("EB1") as Appliance
	assert_true(heater.energized)
	heater.frame_fault = true
	var r: StepResult = sim.step()
	assert_true(_rcd(doc).tripped, "the fault current goes back on PE")
	assert_false(r.short_circuit, "and is cut off")


func test_short_between_l_and_n_leaves_a_plain_rcd_on() -> void:
	var doc: SchematicDocument = _socket_circuit(-1)
	(doc.circuit.get_component("FA1") as CircuitBreaker).switched_on = false
	# L straight to N past the breaker, behind the RCD.
	assert_true(doc.connect_terminals("FB1:2", "FB1:N'"))
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.step()
	assert_false(_rcd(doc).tripped, "as much comes back as goes out")
	_rcd(doc).overcurrent = true
	sim.step()
	assert_true(_rcd(doc).tripped, "an RCBO trips on the short as a breaker")


func test_frame_live_without_pe() -> void:
	var doc: SchematicDocument = _socket_circuit(-1)
	doc.add(Appliance.new("EB1", Appliance.Kind.OVEN), Vector2i(20, 16))
	for pair: Array in [["FA1:2", "EB1:L"], ["FB1:N'", "EB1:N"]]:
		assert_true(doc.connect_terminals(pair[0], pair[1]))
	var oven: Appliance = doc.circuit.get_component("EB1") as Appliance
	oven.frame_fault = true
	var sim: Simulator = Simulator.new(doc.circuit)
	var r: StepResult = sim.step()
	assert_false(_rcd(doc).tripped, "nothing flows to PE")
	assert_eq(r.terminal_reach.get("EB1:PE", 0), StepResult.REACH_L1, "its frame is live")


func test_test_button() -> void:
	var rcd: ResidualCurrentDevice = ResidualCurrentDevice.new("FB1")
	assert_false(rcd.test(), "nothing to trip while off")
	rcd.switched_on = true
	assert_true(rcd.test())
	assert_true(rcd.tripped)
	rcd.toggle()
	assert_false(rcd.tripped, "switched on again")


func test_arcing_connection_trips_its_afdd_only() -> void:
	var doc: SchematicDocument = SchematicDocument.new("afdd")
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(4, 0))
	for k: int in 2:
		var afdd: ArcFaultDevice = ArcFaultDevice.new("FB%d" % (k + 1))
		afdd.switched_on = true
		doc.add(afdd, Vector2i(k * 12, 4))
		var socket: SocketOutlet = SocketOutlet.new("XD%d" % (k + 1))
		socket.plug(Appliance.Kind.HEATER)
		doc.add(socket, Vector2i(k * 12, 12))
		var id: String = afdd.id
		for pair: Array in [["L1", "FB%d:1" % (k + 1)], ["N", "FB%d:N" % (k + 1)], ["FB%d:2" % (k + 1), "XD%d:L" % (k + 1)], ["FB%d:N'" % (k + 1), "XD%d:N" % (k + 1)]]:
			assert_true(doc.connect_terminals(pair[0], pair[1]), id)
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.step()
	var first: ArcFaultDevice = doc.circuit.get_component("FB1:1-2-N-N'") as ArcFaultDevice
	var second: ArcFaultDevice = doc.circuit.get_component("FB2:1-2-N-N'") as ArcFaultDevice
	assert_false(first.tripped)
	(doc.circuit.get_component("XD2") as SocketOutlet).arcing = true
	sim.step()
	assert_true(second.tripped, "the arc's current flows through it")
	assert_false(first.tripped, "not through the other one")


func test_overloaded_circuit_trips_its_breaker() -> void:
	var doc: SchematicDocument = _socket_circuit(Appliance.Kind.HEATER)
	var breaker: CircuitBreaker = doc.circuit.get_component("FA1") as CircuitBreaker
	breaker.rated_current = 10.0
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.step()
	assert_false(breaker.tripped, "8.7 A on a B10")
	doc.add(SocketOutlet.new("XD2"), Vector2i(10, 16))
	(doc.circuit.get_component("XD2") as SocketOutlet).plug(Appliance.Kind.KETTLE)
	for pair: Array in [["FA1:2", "XD2:L"], ["FB1:N'", "XD2:N"]]:
		assert_true(doc.connect_terminals(pair[0], pair[1]))
	sim = Simulator.new(doc.circuit)
	sim.step()
	assert_false(breaker.tripped, "not at once")
	sim.step(3600.0)
	assert_true(breaker.tripped, "17.4 A on a B10 trips it in time")
	assert_false(_rcd(doc).tripped)


func test_hob_between_two_phases() -> void:
	var doc: SchematicDocument = SchematicDocument.new("hob")
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("L2", PowerSupply.Conductor.L2), Vector2i(4, 0))
	doc.add(Appliance.new("EB1", Appliance.Kind.HOB), Vector2i(0, 4))
	assert_true(doc.connect_terminals("L1", "EB1:L1"))
	assert_true(doc.connect_terminals("L2", "EB1:L2"))
	var r: StepResult = Simulator.new(doc.circuit).step()
	var hob: Appliance = doc.circuit.get_component("EB1") as Appliance
	assert_true(hob.energized, "400 V between L1 and L2")
	assert_false(hob.burnt)
	assert_almost_eq(r.terminal_currents.get("EB1:L1", 0.0), 6400.0 / 400.0, 0.1, "16 A")


func test_symbols_and_fault_menu() -> void:
	var doc: SchematicDocument = _socket_circuit()
	doc.add(Appliance.new("EB1", Appliance.Kind.FRIDGE), Vector2i(20, 16))
	doc.add(ArcFaultDevice.new("FB2"), Vector2i(20, 4))
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(doc, true)
	await wait_process_frames(2)
	for c: CircuitComponent in view.document.circuit.get_components():
		if not (c is PowerSupply):
			assert_true((view._symbols[c.id] as SchematicSymbol).marking_rects.size() > 0, "%s drawn" % c.id)
	view._fault_target = view.document.circuit.get_component("EB1")
	view._fill_fault_menu()
	var items: Array[String] = []
	for i: int in view._fault_menu.item_count:
		items.append(view._fault_menu.get_item_text(i))
	assert_has(items, "Insulation fault (phase on the frame)")
	assert_has(items, "Loose connection (arcing)")
	assert_eq(RcdSymbol.rating_text(_rcd(doc)), "40 A 30 mA A")
	assert_eq(ApplianceSymbol.power_text(3500.0), "3.5 kW")
	assert_eq(ApplianceSymbol.power_text(150.0), "150 W")
