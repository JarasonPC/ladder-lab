extends GutTest
## Frequency inverter: a 3~ motor at the inverter's frequency, run, reverse,
## fixed frequency and coast stop from its inputs, the setpoint on AI1 or
## the keypad, the ramps, the relay output.

const NO := SwitchingElement.ContactType.NO

var circuit: Circuit
var sim: Simulator
var drive: Vfd
var motor: ThreePhaseMotor


## L1 L2 L3 on TA1, its U V W on M1; S1 (DI1), S2 (DI2), S3 (DI3), S4 (DI4)
## from its 24V, DIC on its 0V; AI1 on its 10 V reference unless
## [param no_setpoint]; H1 (24 V) on DO2 from 24V.
func _build(realistic: bool = false, no_setpoint: bool = false) -> void:
	circuit = Circuit.new()
	circuit.add(PowerSupply.new("L1", PowerSupply.Conductor.L))
	circuit.add(PowerSupply.new("L2", PowerSupply.Conductor.L2))
	circuit.add(PowerSupply.new("L3", PowerSupply.Conductor.L3))
	drive = circuit.add(Vfd.new("TA1")) as Vfd
	motor = circuit.add(ThreePhaseMotor.new("M1")) as ThreePhaseMotor
	for t: Array in [["L1", "TA1:L1"], ["L2", "TA1:L2"], ["L3", "TA1:L3"], ["TA1:U", "M1:U1"], ["TA1:V", "M1:V1"], ["TA1:W", "M1:W1"], ["TA1:DIC", "TA1:0V"]]:
		circuit.connect_terminals(t[0], t[1])
	for k: int in 4:
		circuit.add(LatchingSwitch.new("S%d" % (k + 1), NO))
		circuit.connect_terminals("TA1:24V", "S%d:13" % (k + 1))
		circuit.connect_terminals("S%d:14" % (k + 1), "TA1:DI%d" % (k + 1))
	if not no_setpoint:
		circuit.connect_terminals("TA1:10V", "TA1:AI1")
	var h1: Lamp = circuit.add(Lamp.new("H1")) as Lamp
	h1.rating = "24v"
	circuit.connect_terminals("TA1:24V", "TA1:DO2C")
	circuit.connect_terminals("TA1:DO2NO", "H1:X1")
	circuit.connect_terminals("H1:X2", "TA1:0V")
	sim = Simulator.new(circuit)
	sim.mode = Simulator.Mode.REALISTIC if realistic else Simulator.Mode.IDEAL
	sim.step()


func _switch(k: int, on: bool) -> void:
	(circuit.get_component("S%d" % k) as LatchingSwitch).set_switched_on(on)


func test_runs_the_motor_at_its_frequency() -> void:
	_build()
	assert_true(drive.powered, "the three phases on its supply")
	assert_false(drive.output)
	assert_false(motor.is_turning())
	_switch(1, true)
	sim.step()
	assert_true(drive.output)
	assert_eq(drive.frequency, 50.0, "10 V on AI1: the maximum")
	assert_true(motor.is_running())
	assert_almost_eq(motor.shaft, 1.0, 0.05, "at rated speed")
	assert_eq(motor.shaft_direction, ThreePhaseMotor.Direction.CLOCKWISE)
	assert_true((circuit.get_component("H1") as Lamp).energized, "DO2 closed while it runs")
	drive.setpoint = Vfd.Setpoint.KEYPAD
	drive.keypad_frequency = 25.0
	sim.step()
	assert_eq(drive.frequency, 25.0)
	assert_almost_eq(motor.shaft, 0.5, 0.05, "half the speed at 25 Hz")
	assert_lt(motor.max_current(), motor.rated_current * 1.5, "no starting current on the inverter")


func test_reverse_fixed_frequency_and_coast_stop() -> void:
	_build()
	_switch(1, true)
	_switch(2, true)
	sim.step()
	assert_eq(drive.frequency, -50.0)
	assert_eq(motor.shaft_direction, ThreePhaseMotor.Direction.COUNTERCLOCKWISE, "DI2: reverse")
	_switch(2, false)
	_switch(3, true)
	sim.step()
	assert_eq(drive.frequency, Vfd.DEFAULT_FIXED, "DI3: the fixed frequency")
	assert_eq(motor.shaft_direction, ThreePhaseMotor.Direction.CLOCKWISE)
	_switch(4, true)
	sim.step()
	assert_false(drive.output, "DI4: coast stop")
	assert_false(motor.is_running())
	_switch(4, false)
	_switch(1, false)
	sim.step()
	assert_false(drive.output)


func test_no_setpoint_no_speed() -> void:
	_build(false, true)
	_switch(1, true)
	sim.step()
	assert_true(drive.output, "running")
	assert_eq(drive.frequency, 0.0, "0 V on AI1")
	assert_false(motor.is_turning())


func test_ramps() -> void:
	_build(true)
	_switch(1, true)
	sim.step(5.0)
	assert_almost_eq(drive.frequency, 25.0, 0.5, "halfway along the 10 s ramp")
	assert_almost_eq(motor.shaft, 0.5, 0.1, "the motor follows")
	sim.step(6.0)
	assert_eq(drive.frequency, 50.0)
	_switch(1, false)
	sim.step(2.5)
	assert_almost_eq(drive.frequency, 37.5, 0.5, "ramping down")
	assert_true(drive.output)
	sim.step(10.0)
	assert_eq(drive.frequency, 0.0)
	assert_false(drive.output, "off at the end of the ramp")


func test_keypad_control_and_phase_loss() -> void:
	_build()
	drive.control = Vfd.Command.KEYPAD
	drive.keypad_run = true
	drive.keypad_reverse = true
	sim.step()
	assert_eq(drive.frequency, -50.0, "run and reverse from the keypad")
	circuit.remove_wire(circuit.get_wires().find(PackedStringArray(["L3", "TA1:L3"])))
	sim = Simulator.new(circuit)
	sim.step()
	assert_false(drive.powered, "two phases are not enough")
	assert_false(drive.output)


func test_mains_on_the_output_is_a_short() -> void:
	_build()
	_switch(1, true)
	sim.step()
	circuit.connect_terminals("L1", "TA1:V")
	sim = Simulator.new(circuit)
	assert_true(sim.step().short_circuit)


func test_draws_from_its_supply() -> void:
	_build()
	_switch(1, true)
	var r: StepResult = sim.step()
	var line: float = r.terminal_currents.get("TA1:L1", 0.0)
	assert_gt(line, Vfd.IDLE_CURRENT)
	assert_almost_eq(r.terminal_currents.get("TA1:L2", 0.0), line, 0.01, "balanced")
	assert_gt(r.terminal_currents.get("M1:U1", 0.0), 0.0, "the motor's current from U")


func test_saved_and_loaded() -> void:
	var ta1: Vfd = Vfd.new("TA1")
	ta1.control = Vfd.Command.KEYPAD
	ta1.setpoint = Vfd.Setpoint.KEYPAD
	ta1.max_frequency = 60.0
	ta1.ramp_up = 3.5
	ta1.ramp_down = 7.0
	ta1.fixed_frequency = 12.5
	ta1.keypad_frequency = 40.0
	var copy: Vfd = DocumentSerializer.component_from_dict(JSON.parse_string(JSON.stringify(DocumentSerializer.component_to_dict(ta1)))) as Vfd
	assert_not_null(copy)
	assert_eq(copy.control, Vfd.Command.KEYPAD)
	assert_eq(copy.setpoint, Vfd.Setpoint.KEYPAD)
	assert_eq(copy.max_frequency, 60.0)
	assert_eq(copy.ramp_up, 3.5)
	assert_eq(copy.ramp_down, 7.0)
	assert_eq(copy.fixed_frequency, 12.5)
	assert_eq(copy.keypad_frequency, 40.0)
	assert_eq(CabinetDevices.kind_of(copy), CabinetDevices.Kind.VFD, "on a rail in the switchboard")
	var cells: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(copy)
	var seen: Dictionary[Vector2i, bool] = {}
	for name: String in cells:
		assert_false(seen.has(cells[name]), name)
		seen[cells[name]] = true
	var points: Dictionary = CabinetParts.terminal_points(CabinetDevices.Kind.VFD, {})
	assert_eq(points.size(), Vfd.TERMINALS.size(), "a screw for every terminal")
