extends GutTest
## The multimeter on a simulated circuit (see [Multimeter]): voltages
## through the loads, resistances with the power off.


func _sim(doc: SchematicDocument) -> Simulator:
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.step()
	return sim


func _supply(doc: SchematicDocument, conductor: PowerSupply.Conductor) -> String:
	for c: CircuitComponent in doc.circuit.get_components():
		if c is PowerSupply and (c as PowerSupply).conductor == conductor:
			return c.designation
	return ""


func test_voltages() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.build(0))
	var sim: Simulator = _sim(doc)
	var l1: String = _supply(doc, PowerSupply.Conductor.L)
	var l2: String = _supply(doc, PowerSupply.Conductor.L2)
	var n: String = _supply(doc, PowerSupply.Conductor.N)
	assert_almost_eq(Multimeter.volts(sim, l1, n)["volts"], 230.0, 0.5, "L1-N")
	assert_false(Multimeter.volts(sim, l1, n)["dc"])
	assert_almost_eq(Multimeter.volts(sim, l1, l2)["volts"], 398.4, 0.5, "L1-L2")
	assert_almost_eq(Multimeter.volts(sim, "SB0:11", "SB0:12")["volts"], 0.0, 0.01, "across a closed contact")
	# Across the open start button: the supply on one side, N through the coil on the other.
	assert_almost_eq(Multimeter.volts(sim, "SB1:13", "SB1:14")["volts"], 230.0, 0.5, "across an open contact")
	assert_almost_eq(Multimeter.volts(sim, "KM1:A1", n)["volts"], 0.0, 0.5, "the coil without voltage")
	assert_eq(Multimeter.text(Multimeter.volts(sim, l1, n)), "230 V ~")
	(doc.circuit.get_operator("SB1") as PushButton).press()
	sim.step()
	assert_almost_eq(Multimeter.volts(sim, "KM1:A1", "KM1:A2")["volts"], 230.0, 0.5, "the coil pulled in")
	assert_almost_eq(Multimeter.volts(sim, "SB1:13", "SB1:14")["volts"], 0.0, 0.01)


func test_resistances() -> void:
	var doc: SchematicDocument = ExampleCircuits.build(0)
	var sim: Simulator = _sim(doc)
	assert_almost_eq(Multimeter.ohms(sim, "KM1:A1", "KM1:A2"), Multimeter.COIL_OHMS, 1.0, "the coil")
	assert_eq(Multimeter.ohms(sim, "SB0:11", "SB0:12"), 0.0, "a closed contact")
	assert_eq(Multimeter.ohms(sim, "SB1:13", "SB1:14"), Multimeter.ohms(sim, "SB1:13", "SB1:14"))
	for c: CircuitComponent in doc.circuit.get_components():
		if c is Coil and c.designation == "KM1":
			(c as Coil).fault = Coil.Fault.OPEN
	sim.step()
	assert_eq(Multimeter.ohms(sim, "KM1:A1", "KM1:A2"), INF, "a broken coil")
	assert_eq(Multimeter.text(INF), "OL")
	var live: SchematicDocument = ExamplePower.on(ExampleCircuits.build(0))
	var running: Simulator = _sim(live)
	assert_eq(Multimeter.ohms(running, _supply(live, PowerSupply.Conductor.L), _supply(live, PowerSupply.Conductor.N)), -1.0, "voltage there")
const ExamplePower = preload("res://test/unit/example_power.gd")
