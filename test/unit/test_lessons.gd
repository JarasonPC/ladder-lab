extends GutTest
## The built-in lessons: their solutions tick every drawing step and pass
## every goal, their start schematics do not, the steps follow the parts by
## their roles whatever they are called, and the goals find wiring mistakes.


func _drawing_steps(lesson: Lesson) -> Array[Lesson.Step]:
	var steps: Array[Lesson.Step] = []
	for s: Lesson.Step in lesson.steps:
		if not s.simulating:
			steps.append(s)
	return steps


func test_ids_are_unique_and_found() -> void:
	var seen: Dictionary[String, bool] = {}
	for lesson: Lesson in Lessons.all():
		assert_false(seen.has(lesson.id), lesson.id)
		seen[lesson.id] = true
		assert_eq(Lessons.by_id(lesson.id).title, lesson.title)
	assert_null(Lessons.by_id("no such lesson"))


func test_solution_parts_play_their_roles() -> void:
	for lesson: Lesson in Lessons.all():
		var doc: SchematicDocument = lesson.solution.call()
		var check: LessonCheck = LessonCheck.new(doc, lesson)
		for role: String in lesson.parts:
			assert_true(doc.circuit.has_component_id(lesson.parts[role]), "%s: %s" % [lesson.id, lesson.parts[role]])
			assert_true(check.has(role), "%s: role %s" % [lesson.id, role])
			if check.has(role):
				assert_eq(check.part(role).id, lesson.parts[role], "%s: role %s" % [lesson.id, role])
		assert_true(lesson.parts.has(lesson.anchor), lesson.id)


func test_solutions_tick_every_drawing_step() -> void:
	for lesson: Lesson in Lessons.all():
		var check: LessonCheck = LessonCheck.new(lesson.solution.call(), lesson)
		for s: Lesson.Step in _drawing_steps(lesson):
			if s.title == "Change the delay":
				continue
			assert_true(s.done.call(check, null), "%s: %s" % [lesson.id, s.title])


func test_solutions_pass_every_goal() -> void:
	for lesson: Lesson in Lessons.all():
		var check: LessonCheck = LessonCheck.new(lesson.solution.call(), lesson)
		for goal: Lesson.Goal in lesson.goals:
			var result: Dictionary = check.run(goal)
			assert_true(result["passed"], "%s: %s %s" % [lesson.id, goal.title, result])


func test_start_schematics_pass_no_goal() -> void:
	for lesson: Lesson in Lessons.all():
		var check: LessonCheck = LessonCheck.new(lesson.start.call(), lesson)
		for goal: Lesson.Goal in lesson.goals:
			assert_false(check.run(goal)["passed"], "%s: %s" % [lesson.id, goal.title])


func test_start_schematics_leave_the_first_step_to_do() -> void:
	for lesson: Lesson in Lessons.all():
		var check: LessonCheck = LessonCheck.new(lesson.start.call(), lesson)
		assert_false(lesson.steps[0].done.call(check, null), lesson.id)


func test_steps_while_simulating_wait_for_the_simulation() -> void:
	for lesson: Lesson in Lessons.all():
		var check: LessonCheck = LessonCheck.new(lesson.solution.call(), lesson)
		for s: Lesson.Step in lesson.steps:
			if s.simulating:
				assert_false(s.done.call(check, null), "%s: %s" % [lesson.id, s.title])


func test_start_stop_without_holding_contact_fails_to_hold() -> void:
	var lesson: Lesson = Lessons.start_stop()
	var doc: SchematicDocument = lesson.solution.call()
	doc.remove_wire(doc.wire_between("SB2:14", "KM1:14"))
	var check: LessonCheck = LessonCheck.new(doc, lesson)
	var results: Array[bool] = []
	for goal: Lesson.Goal in lesson.goals:
		results.append(check.run(goal)["passed"])
	assert_eq(results, [true, false, true, true, true] as Array[bool])
	var held: Dictionary = check.run(lesson.goals[1])
	assert_eq(held["phase"], 1, "fails when the start button is let go")
	var coil_row: Dictionary = held["rows"][1]
	assert_eq(coil_row["label"], "KM1")
	assert_eq(coil_row["got"], [true, false])
	assert_eq(coil_row["expected"], [true, true])


func test_steps_follow_the_parts_whatever_their_names() -> void:
	# The lamp named H7, the switch RB4 and the wires drawn the other way round.
	var lesson: Lesson = Lessons.lamp_and_switch()
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(4, 1))
	doc.add(LatchingSwitch.new("RB4", SwitchingElement.ContactType.NO), Vector2i(4, 4))
	doc.add(Lamp.new("H7"), Vector2i(4, 10))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(4, 16))
	doc.connect_terminals("RB4:14", "L1")
	doc.connect_terminals("H7:X2", "RB4:13")
	doc.connect_terminals("N", "H7:X1")
	var check: LessonCheck = LessonCheck.new(doc, lesson)
	assert_eq(check.designation("lamp"), "H7")
	for s: Lesson.Step in _drawing_steps(lesson):
		assert_true(s.done.call(check, null), s.title)
	for goal: Lesson.Goal in lesson.goals:
		assert_true(check.run(goal)["passed"], goal.title)


func test_a_part_bridged_by_a_wire_breaks_the_row() -> void:
	var lesson: Lesson = Lessons.lamp_and_switch()
	var doc: SchematicDocument = lesson.solution.call()
	doc.connect_terminals("RB1:13", "RB1:14")
	var check: LessonCheck = LessonCheck.new(doc, lesson)
	assert_false(check.series(["L", "switch", "lamp", "N"]))
	assert_false(check.run(lesson.goals[1])["passed"], "the lamp lights with the switch off")


func test_a_short_circuit_stops_the_run() -> void:
	var lesson: Lesson = Lessons.lamp_and_switch()
	var doc: SchematicDocument = lesson.solution.call()
	doc.connect_terminals("H1:X1", "H1:X2")
	var result: Dictionary = LessonCheck.new(doc, lesson).run(lesson.goals[0])
	assert_false(result["passed"])
	assert_true(result["short"])


func test_missing_part_is_named() -> void:
	var lesson: Lesson = Lessons.start_stop()
	var result: Dictionary = LessonCheck.new(lesson.start.call(), lesson).run(lesson.goals[0])
	assert_false(result["passed"])
	assert_eq(result["missing"], "stop")


func test_time_relay_goals_follow_the_delay_set() -> void:
	var lesson: Lesson = Lessons.time_relay()
	var doc: SchematicDocument = lesson.solution.call()
	(doc.circuit.get_coil("KT1") as TimerRelay).delay = 5.0
	var check: LessonCheck = LessonCheck.new(doc, lesson)
	for goal: Lesson.Goal in lesson.goals:
		assert_true(check.run(goal)["passed"], goal.title)
	assert_true(lesson.steps[lesson.steps.size() - 1].done.call(check, null), "a delay other than 3 s")


func test_motor_with_two_phases_swapped_is_still_wired() -> void:
	var lesson: Lesson = Lessons.motor()
	var doc: SchematicDocument = lesson.solution.call()
	doc.remove_wire(doc.wire_between("F1:4", "M1:V1"))
	doc.remove_wire(doc.wire_between("F1:6", "M1:W1"))
	doc.connect_terminals("F1:4", "M1:W1")
	doc.connect_terminals("F1:6", "M1:V1")
	assert_true(Lessons._phases_wired(LessonCheck.new(doc, lesson)))
	doc.remove_wire(doc.wire_between("F1:6", "M1:V1"))
	doc.connect_terminals("F1:6", "M1:W1")
	assert_false(Lessons._phases_wired(LessonCheck.new(doc, lesson)), "two phases on one winding")


func test_motor_overload_contact_bypassed_fails() -> void:
	var lesson: Lesson = Lessons.motor()
	var doc: SchematicDocument = lesson.solution.call()
	doc.connect_terminals("L1.2", "SB1:11")
	var check: LessonCheck = LessonCheck.new(doc, lesson)
	var overload_step: Lesson.Step = lesson.steps[5]
	assert_false(overload_step.done.call(check, null))
	assert_false(check.run(lesson.goals[3])["passed"])


func test_live_state_ticks_the_simulation_steps() -> void:
	var lesson: Lesson = Lessons.start_stop()
	var doc: SchematicDocument = lesson.solution.call()
	var live: LessonCheck = LessonCheck.new(doc, lesson)
	var sim: Simulator = Simulator.new(doc.circuit)
	sim.mode = Simulator.Mode.IDEAL
	var test_step: Lesson.Step = lesson.steps[lesson.steps.size() - 1]
	sim.step()
	assert_false(test_step.done.call(live, live))
	(live.part("start") as PushButton).press()
	sim.step()
	assert_false(test_step.done.call(live, live), "still held")
	(live.part("start") as PushButton).release()
	sim.step()
	assert_true(test_step.done.call(live, live))
