extends GutTest
## Multifunction time relay: functions F1-F9 and the control input S.

const M := TimerRelay.Mode
const NO := SwitchingElement.ContactType.NO

var doc: SchematicDocument
var sim: Simulator
var supply: LatchingSwitch
var button: PushButton
var timer: TimerRelay
var lamp: Lamp


## L - S1 (power switch) - KT1 A1-A2 - N; L - S2 (button) - KT1:S;
## L - KT1 17-18 - H1 - N.
func _build(mode: M, with_s: bool = true) -> void:
	doc = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 20))
	supply = doc.add(LatchingSwitch.new("S1", NO), Vector2i(3, 2)) as LatchingSwitch
	button = doc.add(PushButton.new("S2", NO), Vector2i(8, 2)) as PushButton
	timer = TimerRelay.new("KT1", mode, 1.0)
	timer.control_input = with_s
	doc.add(timer, Vector2i(3, 8))
	doc.add(Contact.new("KT1", NO, 1, true), Vector2i(12, 2))
	lamp = doc.add(Lamp.new("H1"), Vector2i(12, 8)) as Lamp
	var pairs: Array = [["L", "S1:13"], ["S1:14", "KT1:A1"], ["KT1:A2", "N"], ["L", "KT1:17"], ["KT1:18", "H1:X1"], ["H1:X2", "N"]]
	if with_s:
		pairs.append_array([["S1:14", "S2:13"], ["S2:14", "KT1:S"]])
	for pair: Array in pairs:
		doc.connect_terminals(pair[0], pair[1])
	sim = Simulator.new(doc.circuit)
	sim.step()


## Runs [param seconds] and returns the lamp state at the end.
func _run(seconds: float) -> bool:
	var t: float = 0.0
	while t < seconds - 1e-9:
		sim.step(0.05)
		t += 0.05
	return lamp.energized


func _power(on: bool) -> void:
	supply.set_switched_on(on)
	sim.step()


func _press(seconds: float = 0.1) -> void:
	button.press()
	_run(seconds)
	button.release()
	sim.step()


func test_s_terminal_and_geometry() -> void:
	_build(M.PULSE_ON_PRESS)
	assert_eq(timer.get_terminal_names(), PackedStringArray(["A1", "A2", "S"]))
	assert_eq(doc.terminal_cell("KT1:S"), Vector2i(4, 8), "S beside A1")
	assert_eq(CircuitCheck.run(doc), [] as Array[Dictionary])
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(DocumentSerializer.to_dict(copy), DocumentSerializer.to_dict(doc), "round trip")


func test_s_can_be_renamed() -> void:
	var t: TimerRelay = TimerRelay.new("KT1", M.TOGGLE, 1.0)
	t.control_input = true
	t.custom_terminals = PackedStringArray(["A1", "A2", "TL"])
	assert_eq(t.get_terminal_keys(), PackedStringArray(["KT1:A1", "KT1:A2", "KT1:TL"]))


func test_f1_pulse_after_power_on() -> void:
	_build(M.PULSE_ON_POWER, false)
	_power(true)
	assert_true(_run(0.5), "on right after power")
	assert_false(_run(1.0), "off after t")


func test_f2_on_delay() -> void:
	_build(M.ON_DELAY, false)
	_power(true)
	assert_false(_run(0.9))
	assert_true(_run(0.2))
	_power(false)
	assert_false(lamp.energized)


func test_f3_pulse_when_pressed() -> void:
	_build(M.PULSE_ON_PRESS)
	_power(true)
	assert_false(lamp.energized)
	_press()
	assert_true(lamp.energized, "pulse starts with the press")
	assert_false(_run(1.0), "and ends after t")


func test_f4_on_delay_after_release() -> void:
	_build(M.DELAY_AFTER_RELEASE)
	_power(true)
	_press(0.5)
	assert_false(_run(0.9), "not before t after the release")
	assert_true(_run(0.2))
	assert_true(_run(3.0), "stays on while powered")
	_power(false)
	assert_false(lamp.energized)


func test_f5_pulse_after_release() -> void:
	_build(M.PULSE_AFTER_RELEASE)
	_power(true)
	button.press()
	assert_false(_run(0.5), "nothing while pressed")
	button.release()
	sim.step()
	assert_true(lamp.energized, "pulse on release")
	assert_false(_run(1.1))


func test_f6_impulse_relay() -> void:
	_build(M.TOGGLE)
	_power(true)
	_press()
	assert_true(lamp.energized)
	_press()
	assert_false(lamp.energized)
	_press()
	assert_true(lamp.energized)
	_power(false)
	_power(true)
	assert_false(lamp.energized, "no memory after power loss")


func test_f7_pulse_generator() -> void:
	_build(M.PULSE_GENERATOR, false)
	_power(true)
	assert_false(_run(0.9))
	assert_true(_run(0.3), "0.5 s pulse after t")
	assert_false(_run(0.5))
	assert_true(_run(0.8), "and again")


func test_f8_shifted_pulse() -> void:
	_build(M.SHIFTED_PULSE)
	_power(true)
	_press()
	assert_false(_run(0.8), "waits t")
	assert_true(_run(0.2))
	assert_false(_run(1.0), "then on for t")


func test_f9_test() -> void:
	_build(M.TEST, false)
	_power(true)
	assert_true(lamp.energized)


func test_realistic_mode_runs_functions() -> void:
	_build(M.PULSE_ON_PRESS)
	sim.mode = Simulator.Mode.REALISTIC
	_power(true)
	button.press()
	_run(0.2)
	button.release()
	assert_true(_run(0.3), "output contacts closed during the pulse")
	assert_false(_run(1.0))
