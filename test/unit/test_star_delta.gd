extends GutTest
## Star/delta start (built-in example 5), in both switching modes.

var doc: SchematicDocument
var sim: Simulator
var stop: PushButton
var start: PushButton
var km1: Coil
var km2: Coil
var km3: Coil


func _setup(realistic: bool) -> void:
	doc = ExampleCircuits.star_delta()
	sim = Simulator.new(doc.circuit)
	sim.mode = Simulator.Mode.REALISTIC if realistic else Simulator.Mode.IDEAL
	stop = doc.circuit.get_component("SB1") as PushButton
	start = doc.circuit.get_component("SB2") as PushButton
	km1 = doc.circuit.get_coil("KM1")
	km2 = doc.circuit.get_coil("KM2")
	km3 = doc.circuit.get_coil("KM3")
	sim.step()


## Runs [param seconds] in small steps and checks star and delta never have
## their contacts closed at the same time.
func _run(seconds: float) -> void:
	var dt: float = 0.0005
	var t: float = 0.0
	while t < seconds:
		sim.step(dt)
		t += dt
		if km2.armature.no_closed and km3.armature.no_closed:
			fail_test("star KM3 and delta KM2 closed together at %.4f s" % sim.time)
			return


func _assert_state(main: bool, delta: bool, star: bool, text: String) -> void:
	assert_eq(km1.energized, main, "KM1 main: " + text)
	assert_eq(km2.energized, delta, "KM2 delta: " + text)
	assert_eq(km3.energized, star, "KM3 star: " + text)


func _sequence(realistic: bool) -> void:
	_setup(realistic)
	_assert_state(false, false, false, "at rest")
	start.press()
	_run(0.2)
	_assert_state(true, false, true, "star while START is held")
	start.release()
	_run(0.2)
	_assert_state(true, true, false, "delta after letting go")
	start.press()
	_run(0.2)
	_assert_state(true, true, false, "START again does not bring star back")
	start.release()
	stop.press()
	_run(0.2)
	_assert_state(false, false, false, "after STOP")
	stop.release()
	_run(0.2)
	_assert_state(false, false, false, "stays off")


func test_ideal_sequence() -> void:
	_sequence(false)


func test_realistic_sequence() -> void:
	_sequence(true)


func test_delta_waits_for_star_to_release() -> void:
	_setup(true)
	start.press()
	_run(0.2)
	start.release()
	# Step until the delta coil gets power and check where star is by then.
	var guard: int = 0
	while not km2.energized and guard < 1000:
		sim.step(0.0001)
		guard += 1
	assert_true(km2.energized)
	assert_false(km3.armature.no_closed, "star main contacts are open before delta gets power")
	assert_lte(km3.armature.position, Armature.NC_REMAKE + 1e-6, "delta starts when KM3 11-12 has closed again")


func test_too_short_tap_starts_nothing() -> void:
	_setup(true)
	start.press()
	_run(0.005)
	start.release()
	_run(0.2)
	_assert_state(false, false, false, "a 5 ms tap is shorter than the star contactor's pick-up")


func test_example_passes_check() -> void:
	assert_eq(CircuitCheck.run(ExampleCircuits.star_delta()), [] as Array[Dictionary])
