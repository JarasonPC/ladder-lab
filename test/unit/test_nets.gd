extends GutTest


func test_wires_join_terminals_into_nets() -> void:
	var c: Circuit = Circuit.new()
	c.add(PowerRail.new("L", PowerRail.Conductor.L))
	c.add(PushButton.new("S1", SwitchingElement.ContactType.NO))
	c.add(Coil.new("K1"))
	c.connect_terminals("L", "S1:13")
	c.connect_terminals("S1:14", "K1:A1")
	var sim: Simulator = Simulator.new(c)
	# L+S1:13, S1:14+K1:A1, K1:A2 alone.
	assert_eq(sim.get_net_count(), 3)
	assert_eq(sim.get_net_of("L"), sim.get_net_of("S1:13"))
	assert_eq(sim.get_net_of("S1:14"), sim.get_net_of("K1:A1"))
	assert_ne(sim.get_net_of("S1:13"), sim.get_net_of("S1:14"))


func test_nets_rebuild_after_new_wire() -> void:
	var c: Circuit = Circuit.new()
	c.add(Lamp.new("H1"))
	var sim: Simulator = Simulator.new(c)
	assert_eq(sim.get_net_count(), 2)
	c.connect_terminals("H1:X1", "H1:X2")
	assert_eq(sim.get_net_count(), 1)


func test_terminal_marking() -> void:
	assert_eq(PushButton.new("S0", SwitchingElement.ContactType.NC).get_terminal_keys(), PackedStringArray(["S0:11", "S0:12"]))
	assert_eq(Contact.new("K1", SwitchingElement.ContactType.NO, 2).get_terminal_keys(), PackedStringArray(["K1:23", "K1:24"]))
	assert_eq(Contact.new("KT1", SwitchingElement.ContactType.NC, 1, true).get_terminal_keys(), PackedStringArray(["KT1:15", "KT1:16"]))
	assert_eq(Contact.new("KT1", SwitchingElement.ContactType.NO, 1, true).id, "KT1:17-18")


func test_unknown_terminal_is_rejected() -> void:
	var c: Circuit = Circuit.new()
	c.add(Lamp.new("H1"))
	assert_false(c.connect_terminals("H1:X1", "H9:X1"))
	assert_push_error("unknown terminal")


func test_duplicate_terminal_is_rejected() -> void:
	var c: Circuit = Circuit.new()
	c.add(Contact.new("K1", SwitchingElement.ContactType.NO))
	assert_null(c.add(Contact.new("K1", SwitchingElement.ContactType.NO)))
	assert_push_error("duplicate component id")
