class_name Lessons
extends RefCounted
## The built-in lessons, from the first circuit to a motor with overload
## protection and a PLC reading a potentiometer (see [Lesson]). Texts are English source text, translated where
## shown; designations in them are the ones the editor gives the parts when
## they are placed in the order the steps ask. No nodes.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC
const L := PowerSupply.Conductor.L
const N := PowerSupply.Conductor.N

## Palette templates the steps point at (as in [constant Palette.ENTRIES]).
const SUPPLY_L: Dictionary = {"type": "supply", "conductor": "L"}
const SUPPLY_N: Dictionary = {"type": "supply", "conductor": "N"}
const SWITCH_NO: Dictionary = {"type": "latching_switch", "contact": "NO"}
const BUTTON_NO: Dictionary = {"type": "push_button", "contact": "NO"}
const BUTTON_NC: Dictionary = {"type": "push_button", "contact": "NC"}
const CONTACT_NO: Dictionary = {"type": "contact", "contact": "NO"}
const CONTACT_NC: Dictionary = {"type": "contact", "contact": "NC"}
const COIL: Dictionary = {"type": "coil"}
const TIMER: Dictionary = {"type": "timer"}
const LAMP: Dictionary = {"type": "lamp"}
const BREAKER: Dictionary = {"type": "breaker"}
const MAIN_CONTACTS: Dictionary = {"type": "main_contacts"}
const OVERLOAD_RELAY: Dictionary = {"type": "overload_relay"}
const MOTOR3: Dictionary = {"type": "motor3"}
const SUPPLY_PLUS: Dictionary = {"type": "supply", "conductor": "+"}
const POT: Dictionary = {"type": "pot", "turns": 1}
## The program of the PLC lesson: AI1 through an analog threshold trigger
## to Q1, on from half the range, off again under 40 % (of 0-27648).
const POT_ON: float = 13824.0
const POT_OFF: float = 11059.0


## Every lesson, in order.
static func all() -> Array[Lesson]:
	return [lamp_and_switch(), start_stop(), time_relay(), motor(), plc_pot()]


## The lesson saved as [param id], or null.
static func by_id(id: String) -> Lesson:
	for lesson: Lesson in all():
		if lesson.id == id:
			return lesson
	return null


static func _c(points: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(points)
	return cells


static func _phases(list: Array) -> Array[Dictionary]:
	var phases: Array[Dictionary] = []
	phases.assign(list)
	return phases


## A new schematic of one page titled like [param lesson].
static func _document(lesson_title: String) -> SchematicDocument:
	return SchematicDocument.new(TranslationServer.translate(lesson_title))


# --- Roles ---------------------------------------------------------------------------

static func _supplies(check: LessonCheck, roles: Dictionary[String, CircuitComponent]) -> void:
	roles["L"] = check.supply(L)
	roles["N"] = check.supply(N)


static func _switch(check: LessonCheck) -> CircuitComponent:
	return check.first(func(c: CircuitComponent) -> bool: return c is LatchingSwitch and not (c is LimitSwitch) and (c as LatchingSwitch).contact_type == NO)


static func _lamp(check: LessonCheck) -> CircuitComponent:
	return check.first(func(c: CircuitComponent) -> bool: return c is Lamp)


## Push buttons, the contactor's coil and its NO contacts: the one across the
## start button holds it in ("hold"), another lights the lamp ("lamp_contact").
static func _start_stop_roles(check: LessonCheck, roles: Dictionary[String, CircuitComponent]) -> void:
	roles["stop"] = check.first(func(c: CircuitComponent) -> bool: return c is PushButton and (c as PushButton).contact_type == NC)
	roles["start"] = check.first(func(c: CircuitComponent) -> bool: return c is PushButton and (c as PushButton).contact_type == NO)
	var coil: CircuitComponent = check.first(func(c: CircuitComponent) -> bool: return c is Coil and not (c is TimerRelay))
	roles["coil"] = coil
	if coil == null:
		return
	var contacts: Array[CircuitComponent] = check.find(func(c: CircuitComponent) -> bool:
		return c is Contact and c.designation == coil.designation and (c as Contact).contact_type == NO and not (c as Contact).delayed)
	contacts.sort_custom(func(a: CircuitComponent, b: CircuitComponent) -> bool: return (a as Contact).sequence < (b as Contact).sequence)
	var start: CircuitComponent = roles["start"]
	var hold: CircuitComponent = null
	if start != null:
		for c: CircuitComponent in contacts:
			if check.bridges(c, start.get_terminal_keys()[0], start.get_terminal_keys()[1]):
				hold = c
				break
	if hold == null and not contacts.is_empty():
		hold = contacts[0]
	contacts.erase(hold)
	roles["hold"] = hold
	roles["lamp_contact"] = contacts[0] if not contacts.is_empty() else null


# --- 1. A lamp and a switch ------------------------------------------------------------

static func lamp_and_switch() -> Lesson:
	var lesson: Lesson = Lesson.new("lamp_switch", "A lamp and a switch", "Draw your first circuit: a switch that turns a lamp on and off.")
	# The callables capture the title, never the lesson itself (a lesson
	# holding a callable that holds the lesson would never be freed).
	var title: String = lesson.title
	lesson.start = func() -> SchematicDocument: return _document(title)
	lesson.solution = func() -> SchematicDocument:
		var doc: SchematicDocument = _document(title)
		doc.add(PowerSupply.new("L1", L), Vector2i(4, 1))
		doc.add(LatchingSwitch.new("RB1", NO), Vector2i(4, 4))
		doc.add(Lamp.new("H1"), Vector2i(4, 10))
		doc.add(PowerSupply.new("N", N), Vector2i(4, 16))
		doc.connect_terminals("L1", "RB1:13")
		doc.connect_terminals("RB1:14", "H1:X1")
		doc.connect_terminals("H1:X2", "N")
		return doc
	lesson.parts = {"L": "L1", "switch": "RB1:13-14", "lamp": "H1", "N": "N"}
	lesson.anchor = "L"
	lesson.roles = func(check: LessonCheck) -> Dictionary[String, CircuitComponent]:
		var roles: Dictionary[String, CircuitComponent] = {}
		_supplies(check, roles)
		roles["switch"] = _switch(check)
		roles["lamp"] = _lamp(check)
		return roles

	var s: Lesson.Step = lesson.step("Place the L1 supply",
		"Click L1 supply in the palette, then click near the top left of the page. L1 is the phase: it carries 230 V against N.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("L"))
	s.hint = "Each click places another one. Right click or Esc stops placing."
	s.places = [["L", SUPPLY_L]]
	s.show = PackedStringArray(["L"])
	s = lesson.step("Place the N supply",
		"Put N supply some way below L1, with room for two parts in between. The current returns through N, the neutral conductor.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("N"))
	s.places = [["N", SUPPLY_N]]
	s.show = PackedStringArray(["N"])
	s = lesson.step("Add the switch",
		"Place Switch NO under L1. It is named -RB1; its contact 13-14 closes when the switch is turned on.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("switch"))
	s.places = [["switch", SWITCH_NO]]
	s.show = PackedStringArray(["switch"])
	s = lesson.step("Add the lamp",
		"Place Lamp under the switch. It is named -H1.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("lamp"))
	s.places = [["lamp", LAMP]]
	s.show = PackedStringArray(["lamp"])
	s = lesson.step("Wire L1 to the switch",
		"Click the terminal of L1 (the small square), then terminal 13 of -RB1. The wire finds its own way; click empty cells on the way to add corners.",
		func(e: LessonCheck, _live: LessonCheck) -> bool:
			return e.has("switch") and (e.joined(e.key("L", 0), e.key("switch", 0)) or e.joined(e.key("L", 0), e.key("switch", 1))))
	s.wires = [["L", 0, "switch", 0]]
	s = lesson.step("Wire the switch to the lamp",
		"Draw a wire from terminal 14 of -RB1 to terminal X1 of -H1.",
		func(e: LessonCheck, _live: LessonCheck) -> bool:
			return e.has("lamp") and (e.bridges(e.part("switch"), e.key("L", 0), e.key("lamp", 0)) or e.bridges(e.part("switch"), e.key("L", 0), e.key("lamp", 1))))
	s.wires = [["switch", 1, "lamp", 0]]
	s = lesson.step("Wire the lamp to N",
		"Draw a wire from X2 of -H1 to N. The circuit is closed now: L1, the switch, the lamp, N.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.series(["L", "switch", "lamp", "N"]))
	s.wires = [["lamp", 1, "N", 0]]
	s = lesson.step("Switch to Simulate",
		"Click Simulate at the top. The drawing cannot be changed now, and the wires are coloured by the voltage that reaches them.",
		func(_e: LessonCheck, live: LessonCheck) -> bool: return live != null)
	s.control = "simulate"
	s.simulating = true
	s = lesson.step("Turn the switch on",
		"Click -RB1. The lamp lights. Click it again to turn it off.",
		func(_e: LessonCheck, live: LessonCheck) -> bool: return live != null and live.is_on("lamp"))
	s.focus = PackedStringArray(["switch"])
	s.simulating = true

	lesson.goal("%s lights while %s is on", ["lamp", "switch"], _phases([
		{"do": [["switch", "on"]], "expect": {"lamp": true}},
	]), ["switch", "lamp"])
	lesson.goal("%s is dark while %s is off", ["lamp", "switch"], _phases([
		{"do": [["switch", "on"]]},
		{"do": [["switch", "off"]], "expect": {"lamp": false}},
	]), ["switch", "lamp"])
	return lesson


# --- 2. Start and stop a contactor -------------------------------------------------------

## The control circuit of a contactor started and stopped by push buttons and
## held in by its own 13-14, in column [param x] from row [param top] (the
## top of the stop button) with N at row [param n_row]; [param feed] is the
## terminal feeding the stop button. With [param lamp], KM1 23-24 lights H1
## (running), fed from [param feed].
static func _start_stop_circuit(doc: SchematicDocument, x: int, top: int, n_row: int, feed: String, lamp: bool) -> void:
	doc.add(PushButton.new("SB1", NC), Vector2i(x, top))
	doc.add(PushButton.new("SB2", NO), Vector2i(x, top + 6))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(x + 4, top + 6))
	doc.add(Coil.new("KM1"), Vector2i(x, top + 12))
	if doc.circuit.get_component("N") == null:
		doc.add(PowerSupply.new("N", N), Vector2i(x, n_row))
	doc.connect_terminals(feed, "SB1:11")
	doc.connect_terminals("SB1:12", "SB2:13")
	doc.connect_terminals("SB2:13", "KM1:13", _c([Vector2i(x, top + 5), Vector2i(x + 4, top + 5)]))
	doc.connect_terminals("SB2:14", "KM1:A1")
	doc.connect_terminals("SB2:14", "KM1:14", _c([Vector2i(x, top + 10), Vector2i(x + 4, top + 10)]))
	doc.connect_terminals("KM1:A2", "N")
	if lamp:
		doc.add(Contact.new("KM1", NO, 2), Vector2i(x + 8, top + 6))
		doc.add(Lamp.new("H1"), Vector2i(x + 8, top + 12))
		doc.connect_terminals(feed, "KM1:23", _c([Vector2i(x + 8, doc.terminal_cell(feed).y)]))
		doc.connect_terminals("KM1:24", "H1:X1")
		doc.connect_terminals("H1:X2", "N", _c([Vector2i(x + 8, n_row)]))


static func start_stop() -> Lesson:
	var lesson: Lesson = Lesson.new("start_stop", "Start and stop a contactor", "Two push buttons switch a contactor on and off; one of its own contacts keeps it on.")
	var title: String = lesson.title
	var start: Callable = func() -> SchematicDocument:
		var doc: SchematicDocument = _document(title)
		doc.add(PowerSupply.new("L1", L), Vector2i(4, 1))
		doc.add(PowerSupply.new("N", N), Vector2i(4, 23))
		return doc
	lesson.start = start
	lesson.solution = func() -> SchematicDocument:
		var doc: SchematicDocument = start.call()
		_start_stop_circuit(doc, 4, 4, 23, "L1", true)
		return doc
	lesson.parts = {"L": "L1", "N": "N", "stop": "SB1:11-12", "start": "SB2:13-14", "hold": "KM1:13-14", "coil": "KM1", "lamp_contact": "KM1:23-24", "lamp": "H1"}
	lesson.anchor = "L"
	lesson.roles = func(check: LessonCheck) -> Dictionary[String, CircuitComponent]:
		var roles: Dictionary[String, CircuitComponent] = {}
		_supplies(check, roles)
		_start_stop_roles(check, roles)
		roles["lamp"] = _lamp(check)
		return roles

	var s: Lesson.Step = lesson.step("Add the stop button",
		"Place Push button NC under L1. It is -SB1, the stop button: its contact 11-12 is closed and opens while you press it.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("stop"))
	s.places = [["stop", BUTTON_NC]]
	s.show = PackedStringArray(["stop"])
	s = lesson.step("Add the start button",
		"Place Push button NO under -SB1. It is -SB2, the start button: its contact 13-14 closes while you press it.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("start"))
	s.places = [["start", BUTTON_NO]]
	s.show = PackedStringArray(["start"])
	s = lesson.step("Add the contactor's coil",
		"Place Coil under -SB2. It is -KM1: when A1-A2 gets 230 V, the contactor pulls in and all its contacts switch.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("coil"))
	s.places = [["coil", COIL]]
	s.show = PackedStringArray(["coil"])
	s = lesson.step("Wire them in a row",
		"Wire L1 to 11 of -SB1, 12 to 13 of -SB2, 14 to A1 of -KM1, and A2 to N.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.series(["L", "stop", "start", "coil", "N"]))
	s.wires = [["L", 0, "stop", 0], ["stop", 1, "start", 0], ["start", 1, "coil", 0], ["coil", 1, "N", 0]]
	s = lesson.step("Try it",
		"Switch to Simulate and press -SB2 (hold the mouse button down). -KM1 pulls in, but as soon as you let go, it drops out again.",
		func(_e: LessonCheck, live: LessonCheck) -> bool: return live != null and live.is_on("coil"))
	s.control = "simulate"
	s.focus = PackedStringArray(["start"])
	s.simulating = true
	s = lesson.step("Hold it in with its own contact",
		"Back in Edit, place Contact NO to the right of -SB2. It takes the name of the coil: it is contact 13-14 of -KM1, the self-holding contact.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("hold"))
	s.places = [["hold", CONTACT_NO]]
	s.control = "edit"
	s.show = PackedStringArray(["hold"])
	s = lesson.step("Wire it across -SB2",
		"Wire 13 of -KM1 to 13 of -SB2 and 14 of -KM1 to 14 of -SB2. While -KM1 is on, its contact bridges -SB2, so the coil stays fed after you let go.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("start") and e.bridges(e.part("hold"), e.key("start", 0), e.key("start", 1)))
	s.hint = "A wire can end on another wire: a branch dot is put there."
	s.wires = [["start", 0, "hold", 0], ["start", 1, "hold", 1]]
	s = lesson.step("Add a lamp that shows it runs",
		"Place another Contact NO to the right (it becomes 23-24 of -KM1) and Lamp -H1 under it.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("lamp_contact") and e.has("lamp"))
	s.places = [["lamp_contact", CONTACT_NO], ["lamp", LAMP]]
	s.show = PackedStringArray(["lamp_contact", "lamp"])
	s = lesson.step("Wire the lamp",
		"Wire L1 to 23 of -KM1, 24 to X1 of -H1, and X2 to N.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.series(["L", "lamp_contact", "lamp", "N"]))
	s.wires = [["L", 0, "lamp_contact", 0], ["lamp_contact", 1, "lamp", 0], ["lamp", 1, "N", 0]]
	s = lesson.step("Test it",
		"Simulate again. Press -SB2 and let go: -KM1 stays on and -H1 lights. Press -SB1 to stop it.",
		func(e: LessonCheck, live: LessonCheck) -> bool:
			# Held in by its own contact: without it the coil is still on for
			# a moment after the start button is let go.
			return live != null and e.has("start") and e.bridges(e.part("hold"), e.key("start", 0), e.key("start", 1)) \
				and live.is_on("coil") and not live.is_on("start"))
	s.control = "simulate"
	s.focus = PackedStringArray(["start", "stop"])
	s.simulating = true

	var needs: Array = ["stop", "start", "coil"]
	lesson.goal("Pressing %s switches %s on", ["start", "coil"], _phases([
		{"do": [["start", "press"]], "expect": {"coil": true}},
	]), needs)
	lesson.goal("%s stays on after %s is released", ["coil", "start"], _phases([
		{"do": [["start", "press"]], "expect": {"coil": true}},
		{"do": [["start", "release"]], "expect": {"coil": true}},
	]), needs)
	lesson.goal("Pressing %s switches %s off", ["stop", "coil"], _phases([
		{"do": [["start", "press"]]},
		{"do": [["start", "release"]]},
		{"do": [["stop", "press"]], "expect": {"coil": false}},
	]), needs)
	lesson.goal("%s stays off after %s is released", ["coil", "stop"], _phases([
		{"do": [["start", "press"]]},
		{"do": [["start", "release"]]},
		{"do": [["stop", "press"]]},
		{"do": [["stop", "release"]], "expect": {"coil": false}},
	]), needs)
	lesson.goal("%s lights while %s is on", ["lamp", "coil"], _phases([
		{"do": [["start", "press"]], "expect": {"lamp": true}},
		{"do": [["start", "release"]]},
		{"do": [["stop", "press"]], "expect": {"lamp": false}},
	]), ["stop", "start", "coil", "lamp"])
	return lesson


# --- 3. A time relay ------------------------------------------------------------------------

static func time_relay() -> Lesson:
	var lesson: Lesson = Lesson.new("time_relay", "Switch on later: a time relay", "A time relay lights a lamp a few seconds after you turn a switch on.")
	var title: String = lesson.title
	var start: Callable = func() -> SchematicDocument:
		var doc: SchematicDocument = _document(title)
		doc.add(PowerSupply.new("L1", L), Vector2i(4, 1))
		doc.add(PowerSupply.new("N", N), Vector2i(4, 17))
		return doc
	lesson.start = start
	lesson.solution = func() -> SchematicDocument:
		var doc: SchematicDocument = start.call()
		doc.add(LatchingSwitch.new("RB1", NO), Vector2i(4, 4))
		doc.add(TimerRelay.new("KT1", TimerRelay.Mode.ON_DELAY, 3.0), Vector2i(4, 10))
		doc.add(Contact.new("KT1", NO, 1, true), Vector2i(10, 4))
		doc.add(Lamp.new("H1"), Vector2i(10, 10))
		doc.connect_terminals("L1", "RB1:13")
		doc.connect_terminals("RB1:14", "KT1:A1")
		doc.connect_terminals("KT1:A2", "N")
		doc.connect_terminals("L1", "KT1:17", _c([Vector2i(10, 1)]))
		doc.connect_terminals("KT1:18", "H1:X1")
		doc.connect_terminals("H1:X2", "N", _c([Vector2i(10, 17)]))
		return doc
	lesson.parts = {"L": "L1", "N": "N", "switch": "RB1:13-14", "timer": "KT1", "delayed": "KT1:17-18", "lamp": "H1"}
	lesson.anchor = "L"
	lesson.roles = func(check: LessonCheck) -> Dictionary[String, CircuitComponent]:
		var roles: Dictionary[String, CircuitComponent] = {}
		_supplies(check, roles)
		roles["switch"] = _switch(check)
		var timer: CircuitComponent = check.first(func(c: CircuitComponent) -> bool: return c is TimerRelay)
		roles["timer"] = timer
		roles["delayed"] = null if timer == null else check.first(func(c: CircuitComponent) -> bool:
			return c is Contact and c.designation == timer.designation and (c as Contact).contact_type == NO)
		roles["lamp"] = _lamp(check)
		return roles

	var s: Lesson.Step = lesson.step("Add the switch",
		"Place Switch NO under L1. It is named -RB1.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("switch"))
	s.places = [["switch", SWITCH_NO]]
	s.show = PackedStringArray(["switch"])
	s = lesson.step("Add the time relay",
		"Place Time relay under the switch. It is -KT1, set to function F2, on-delay: its delayed contacts switch 3 s after A1-A2 gets voltage.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("timer"))
	s.places = [["timer", TIMER]]
	s.show = PackedStringArray(["timer"])
	s = lesson.step("Wire the relay through the switch",
		"Wire L1 to 13 of -RB1, 14 to A1 of -KT1, and A2 to N.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.series(["L", "switch", "timer", "N"]))
	s.wires = [["L", 0, "switch", 0], ["switch", 1, "timer", 0], ["timer", 1, "N", 0]]
	s = lesson.step("Add its delayed contact",
		"Click -KT1 to select it, then place Contact NO to the right of the switch. It becomes the relay's delayed contact 17-18, drawn with the delay mark.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("delayed"))
	s.hint = "Named KM1, the contact does not belong to the relay: double-click its designation and type KT1."
	s.places = [["delayed", CONTACT_NO]]
	s.focus = PackedStringArray(["timer"])
	s.show = PackedStringArray(["delayed"])
	s = lesson.step("Add the lamp",
		"Place Lamp -H1 under the contact. Wire L1 to 17 of -KT1, 18 to X1 of -H1, and X2 to N.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.series(["L", "delayed", "lamp", "N"]))
	s.places = [["lamp", LAMP]]
	s.show = PackedStringArray(["lamp"])
	s.wires = [["L", 0, "delayed", 0], ["delayed", 1, "lamp", 0], ["lamp", 1, "N", 0]]
	s = lesson.step("Watch the delay",
		"Simulate and turn -RB1 on. -KT1 starts counting; 3 s later its contact closes and -H1 lights.",
		func(_e: LessonCheck, live: LessonCheck) -> bool: return live != null and live.is_on("lamp"))
	s.control = "simulate"
	s.focus = PackedStringArray(["switch"])
	s.simulating = true
	s = lesson.step("Change the delay",
		"Back in Edit, click -KT1 and set Time t to 5 s in its properties on the right. Simulate again and count.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("timer") and not is_equal_approx((e.part("timer") as TimerRelay).delay, 3.0))
	s.control = "edit"
	s.focus = PackedStringArray(["timer"])
	s.property = ["timer", "delay"]

	var needs: Array = ["switch", "timer", "lamp"]
	lesson.goal("%s stays dark right after %s is turned on", ["lamp", "switch"], _phases([
		{"do": [["switch", "on"]], "expect": {"lamp": false}},
	]), needs)
	lesson.goal("%s lights once the delay of %s is over", ["lamp", "timer"], _phases([
		{"do": [["switch", "on"]]},
		{"wait": 0.5, "wait_delay": "timer", "expect": {"lamp": true}},
	]), needs)
	lesson.goal("%s goes dark when %s is turned off", ["lamp", "switch"], _phases([
		{"do": [["switch", "on"]]},
		{"wait": 0.5, "wait_delay": "timer"},
		{"do": [["switch", "off"]], "expect": {"lamp": false}},
	]), needs)
	return lesson


# --- 4. A motor with overload protection ---------------------------------------------------------

static func motor() -> Lesson:
	var lesson: Lesson = Lesson.new("motor", "A motor with overload protection", "Add the power circuit to a start/stop control: a circuit breaker, the contactor's main contacts, an overload relay and a three-phase motor.")
	var title: String = lesson.title
	var start: Callable = func() -> SchematicDocument:
		var doc: SchematicDocument = _document(title)
		doc.add(PowerSupply.new("L1", L), Vector2i(5, 0))
		doc.add(PowerSupply.new("L2", PowerSupply.Conductor.L2), Vector2i(7, 0))
		doc.add(PowerSupply.new("L3", PowerSupply.Conductor.L3), Vector2i(9, 0))
		doc.add(PowerSupply.new("L1.2", L), Vector2i(18, 1))
		doc.add(PowerSupply.new("N", N), Vector2i(18, 28))
		_start_stop_circuit(doc, 18, 9, 28, "L1.2", false)
		return doc
	lesson.start = start
	lesson.solution = func() -> SchematicDocument:
		var doc: SchematicDocument = start.call()
		var breaker: MotorBreaker = MotorBreaker.new("FA1")
		breaker.poles = 3
		doc.add(breaker, Vector2i(5, 2))
		doc.add(MainContacts.new("KM1"), Vector2i(5, 7))
		doc.add(OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(5, 12))
		doc.add(ThreePhaseMotor.new("M1"), Vector2i(5, 17))
		var poles: Array = [["L1", "1", "U1"], ["L2", "3", "V1"], ["L3", "5", "W1"]]
		for p: Array in poles:
			var out: String = str(int(p[1]) + 1)
			doc.connect_terminals(p[0], "FA1:" + p[1])
			doc.connect_terminals("FA1:" + out, "KM1:" + p[1])
			doc.connect_terminals("KM1:" + out, "F1:" + p[1])
			doc.connect_terminals("F1:" + out, "M1:" + p[2])
		doc.remove_wire(doc.wire_between("L1.2", "SB1:11"))
		doc.add(OverloadContact.new("F1", NC), Vector2i(18, 3))
		doc.connect_terminals("L1.2", "F1:95")
		doc.connect_terminals("F1:96", "SB1:11")
		return doc
	lesson.parts = {"L1": "L1", "L2": "L2", "L3": "L3", "L": "L1.2", "N": "N", "breaker": "FA1:1-2-3-4-5-6", "any_breaker": "FA1:1-2-3-4-5-6", "main": "KM1:1-2-3-4-5-6", "relay": "F1:1-2-3-4-5-6", "motor": "M1", "overload_contact": "F1:95-96", "stop": "SB1:11-12", "start": "SB2:13-14", "coil": "KM1"}
	lesson.anchor = "L1"
	lesson.roles = func(check: LessonCheck) -> Dictionary[String, CircuitComponent]:
		var roles: Dictionary[String, CircuitComponent] = {}
		var phases: Array[CircuitComponent] = check.find(func(c: CircuitComponent) -> bool: return c is PowerSupply and (c as PowerSupply).conductor == L)
		roles["L1"] = phases[0] if not phases.is_empty() else null
		# The control circuit's supply point: another L1 where there is one.
		roles["L"] = phases[phases.size() - 1] if not phases.is_empty() else null
		roles["L2"] = check.supply(PowerSupply.Conductor.L2)
		roles["L3"] = check.supply(PowerSupply.Conductor.L3)
		roles["N"] = check.supply(N)
		_start_stop_roles(check, roles)
		roles["breaker"] = check.first(func(c: CircuitComponent) -> bool: return c is MotorBreaker and (c as MotorBreaker).poles == 3)
		# Placed with one pole, before its poles are set.
		roles["any_breaker"] = roles["breaker"] if roles["breaker"] != null else check.first(func(c: CircuitComponent) -> bool: return c is CircuitBreaker or c is MotorBreaker)
		var coil: CircuitComponent = roles["coil"]
		roles["main"] = check.first(func(c: CircuitComponent) -> bool: return c is MainContacts and (coil == null or c.designation == coil.designation))
		var relay: CircuitComponent = check.first(func(c: CircuitComponent) -> bool: return c is OverloadRelay and (c as OverloadRelay).poles == 3)
		roles["relay"] = relay
		roles["motor"] = check.first(func(c: CircuitComponent) -> bool: return c is ThreePhaseMotor)
		roles["overload_contact"] = null if relay == null else check.first(func(c: CircuitComponent) -> bool:
			return c is OverloadContact and c.designation == relay.designation and (c as OverloadContact).contact_type == NC)
		return roles

	var s: Lesson.Step = lesson.step("Add the circuit breaker",
		"Place Circuit breaker under L1. In its properties on the right set Poles to 3: one pole for each phase.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("breaker"))
	s.places = [["any_breaker", BREAKER]]
	s.property = ["any_breaker", "poles"]
	s.focus = PackedStringArray(["any_breaker"])
	s.show = PackedStringArray(["any_breaker"])
	s = lesson.step("Add the main contacts",
		"Place Main contacts under the breaker. They take the name of the coil, -KM1: the contactor switches the motor with them.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("main"))
	s.places = [["main", MAIN_CONTACTS]]
	s.show = PackedStringArray(["main"])
	s = lesson.step("Add the overload relay",
		"Place Overload relay under the main contacts. It is -F1: the motor current flows through its heaters, and it trips when the motor is overloaded.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("relay"))
	s.places = [["relay", OVERLOAD_RELAY]]
	s.show = PackedStringArray(["relay"])
	s = lesson.step("Add the motor",
		"Place Motor 3~ under the overload relay. It is named -M1.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("motor"))
	s.places = [["motor", MOTOR3]]
	s.show = PackedStringArray(["motor"])
	s = lesson.step("Wire the three phases",
		"Wire L1, L2 and L3 to 1, 3 and 5 of -FA1. Then wire 2, 4 and 6 of each device to 1, 3 and 5 of the next one, and 2, 4 and 6 of -F1 to U1, V1 and W1 of the motor.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return _phases_wired(e))
	s.wires = [["L1", 0, "breaker", 0], ["L2", 0, "breaker", 2], ["L3", 0, "breaker", 4]]
	for pole: int in 3:
		s.wires.append(["breaker", 2 * pole + 1, "main", 2 * pole])
		s.wires.append(["main", 2 * pole + 1, "relay", 2 * pole])
		s.wires.append(["relay", 2 * pole + 1, "motor", pole])
	s = lesson.step("Let the overload relay stop the contactor",
		"In the control circuit on the right, delete the wire from L1 to -SB1. Click -F1, place Contact NC in the gap above -SB1 (it becomes 95-96 of -F1), then wire L1 to 95 and 96 to 11 of -SB1.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.series(["L", "overload_contact", "stop", "start", "coil", "N"]))
	s.hint = "To delete a wire, click it and press Del."
	s.places = [["overload_contact", CONTACT_NC]]
	s.focus = PackedStringArray(["relay"])
	s.cut = [["L", 0, "stop", 0]]
	s.show = PackedStringArray(["overload_contact"])
	s.wires = [["L", 0, "overload_contact", 0], ["overload_contact", 1, "stop", 0]]
	s = lesson.step("Switch on and start",
		"Simulate. Circuit breakers start switched off: click -FA1 to switch it on. Then press -SB2: -KM1 pulls in and the motor runs.",
		func(_e: LessonCheck, live: LessonCheck) -> bool: return live != null and live.is_on("motor"))
	s.control = "simulate"
	s.focus = PackedStringArray(["breaker", "start"])
	s.simulating = true
	s = lesson.step("Trip the overload relay",
		"While the motor runs, click -F1: that presses its test button. The relay trips, its 95-96 opens and -KM1 drops out. Click -F1 again to reset it.",
		func(_e: LessonCheck, live: LessonCheck) -> bool: return live != null and live.is_on("relay") and not live.is_on("coil"))
	s.focus = PackedStringArray(["relay"])
	s.simulating = true

	var needs: Array = ["stop", "start", "coil", "main", "motor"]
	lesson.goal("Pressing %s starts %s", ["start", "motor"], _phases([
		{"do": [["start", "press"]], "expect": {"motor": true}},
	]), needs)
	lesson.goal("%s keeps running after %s is released", ["motor", "start"], _phases([
		{"do": [["start", "press"]], "expect": {"motor": true}},
		{"do": [["start", "release"]], "expect": {"motor": true}},
	]), needs)
	lesson.goal("Pressing %s stops %s", ["stop", "motor"], _phases([
		{"do": [["start", "press"]]},
		{"do": [["start", "release"]]},
		{"do": [["stop", "press"]], "expect": {"motor": false}},
	]), needs)
	lesson.goal("A tripped %s stops %s", ["relay", "motor"], _phases([
		{"do": [["start", "press"]]},
		{"do": [["start", "release"]], "expect": {"motor": true}},
		{"do": [["relay", "trip"]], "expect": {"motor": false}},
	]), needs + ["relay"])
	return lesson


## Each phase runs through a pole of the breaker, the main contacts and the
## overload relay to a winding of the motor: every phase and every winding
## once (two swapped turn it the other way, which is still wired).
static func _phases_wired(e: LessonCheck) -> bool:
	if not (e.has("motor") and e.has("L1") and e.has("L2") and e.has("L3")):
		return false
	var supplies: PackedStringArray = PackedStringArray([e.key("L1", 0), e.key("L2", 0), e.key("L3", 0)])
	var windings: PackedStringArray = PackedStringArray([e.key("motor", 0), e.key("motor", 1), e.key("motor", 2)])
	var phases_used: Dictionary[int, bool] = {}
	var windings_used: Dictionary[int, bool] = {}
	for pole: int in 3:
		var ends: PackedStringArray = e.pole_chain(["breaker", "main", "relay"], pole)
		if ends.is_empty():
			return false
		phases_used[e.joined_index(ends[0], supplies)] = true
		windings_used[e.joined_index(ends[1], windings)] = true
	return not phases_used.has(-1) and phases_used.size() == 3 and not windings_used.has(-1) and windings_used.size() == 3


# --- 5. A PLC reads a potentiometer ----------------------------------------------------------

## AI1 (the CPU's AI0) through an analog threshold trigger to Q1 (Q0.0).
static func _threshold_program() -> PlcProgram:
	var program: PlcProgram = PlcProgram.new()
	var ai: PlcBlock = program.add_block("analog_input", Vector2i(0, 0))
	var trigger: PlcBlock = program.add_block("analog_threshold", Vector2i(4, 0))
	trigger.on = POT_ON
	trigger.off = POT_OFF
	var q1: PlcBlock = program.add_block("output", Vector2i(10, 0))
	trigger.inputs[0] = ai.id
	q1.inputs[0] = trigger.id
	return program


static func plc_pot() -> Lesson:
	var lesson: Lesson = Lesson.new("plc_pot", "A PLC reads a potentiometer", "Wire a potentiometer to the analog input of a compact PLC; its program lights a lamp once you turn it past half.")
	var title: String = lesson.title
	var start: Callable = func() -> SchematicDocument:
		var doc: SchematicDocument = _document(title)
		# The CPU on 24 V DC: L+ and 3L+ (its outputs) from +, M, 2M (the
		# analog inputs) and 3M to -; H1 (24 V) on Q0.0.
		doc.add(PowerSupply.new("+", PowerSupply.Conductor.DC_PLUS), Vector2i(4, 2))
		doc.add(PowerSupply.new("-", PowerSupply.Conductor.DC_MINUS), Vector2i(10, 4))
		doc.add(PowerSupply.new("-.2", PowerSupply.Conductor.DC_MINUS), Vector2i(30, 4))
		doc.add(PowerSupply.new("-.3", PowerSupply.Conductor.DC_MINUS), Vector2i(16, 21))
		doc.add(PowerSupply.new("-.4", PowerSupply.Conductor.DC_MINUS), Vector2i(42, 5))
		doc.add(CompactPlc.new("A1", _threshold_program(), [], CompactPlc.Cpu.DI8_DQ6), Vector2i(8, 6))
		var lamp: Lamp = Lamp.new("H1")
		lamp.rating = "24v"
		lamp.purpose = TranslationServer.translate("Above half")
		doc.add(lamp, Vector2i(16, 15))
		doc.connect_terminals("+", "A1:L+", _c([Vector2i(8, 2)]))
		doc.connect_terminals("+", "A1:3L+", _c([Vector2i(4, 14), Vector2i(8, 14)]))
		doc.connect_terminals("-", "A1:M")
		doc.connect_terminals("-.2", "A1:2M")
		doc.connect_terminals("A1:Q0.0", "H1:X1", _c([Vector2i(12, 13), Vector2i(16, 13)]))
		doc.connect_terminals("H1:X2", "-.3")
		doc.connect_terminals("A1:3M", "-.3", _c([Vector2i(10, 21)]))
		return doc
	lesson.start = start
	lesson.solution = func() -> SchematicDocument:
		var doc: SchematicDocument = start.call()
		var pot: Potentiometer = Potentiometer.new("RP1", 10)
		doc.add(pot, Vector2i(42, 8))
		var ref: PowerSupply = PowerSupply.new("+.2", PowerSupply.Conductor.DC_PLUS)
		ref.voltage = 10.0
		doc.add(ref, Vector2i(42, 15))
		doc.connect_terminals("-.4", "RP1:1")
		doc.connect_terminals("RP1:3", "+.2")
		doc.connect_terminals("A1:AI0", "RP1:2", _c([Vector2i(32, 3), Vector2i(46, 3), Vector2i(46, 10)]))
		return doc
	lesson.parts = {"plus": "+", "minus": "-.4", "plc": "A1", "lamp": "H1", "ref": "+.2", "any_ref": "+.2", "pot": "RP1"}
	lesson.anchor = "plus"
	lesson.roles = func(check: LessonCheck) -> Dictionary[String, CircuitComponent]:
		var roles: Dictionary[String, CircuitComponent] = {}
		var pluses: Array[CircuitComponent] = check.find(func(c: CircuitComponent) -> bool: return c is PowerSupply and (c as PowerSupply).conductor == PowerSupply.Conductor.DC_PLUS)
		roles["plus"] = pluses[0] if not pluses.is_empty() else null
		var ref: CircuitComponent = check.first(func(c: CircuitComponent) -> bool:
			return c is PowerSupply and (c as PowerSupply).conductor == PowerSupply.Conductor.DC_PLUS and is_equal_approx((c as PowerSupply).voltage, 10.0))
		roles["ref"] = ref
		# Placed at 24 V, before its voltage is set.
		roles["any_ref"] = ref if ref != null else (pluses[pluses.size() - 1] if pluses.size() > 1 else null)
		# The - point the potentiometer is drawn under: the last one.
		var minuses: Array[CircuitComponent] = check.find(func(c: CircuitComponent) -> bool: return c is PowerSupply and (c as PowerSupply).conductor == PowerSupply.Conductor.DC_MINUS)
		roles["minus"] = minuses[minuses.size() - 1] if not minuses.is_empty() else null
		roles["plc"] = check.first(func(c: CircuitComponent) -> bool: return c is CompactPlc)
		roles["pot"] = check.first(func(c: CircuitComponent) -> bool: return c is Potentiometer)
		roles["lamp"] = _lamp(check)
		return roles
	var ai0: int = CompactPlc.new("A1", null, [], CompactPlc.Cpu.DI8_DQ6).analog_input_terminal(0)

	var s: Lesson.Step = lesson.step("Place a 10 V supply point",
		"Place + supply (DC) under the - point on the right, a little way down. In its properties set Voltage against - to 10 V (reference): the analog input reads 0-10 V, so the potentiometer is fed from 10 V, not from the 24 V of the PLC.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("ref"))
	s.hint = "All - points are one pole: the 10 V and the 24 V share it."
	s.places = [["any_ref", SUPPLY_PLUS]]
	s.property = ["any_ref", "voltage"]
	s.focus = PackedStringArray(["any_ref"])
	s.show = PackedStringArray(["any_ref"])
	s = lesson.step("Add the potentiometer",
		"Place Potentiometer between the - point and the 10 V point. It is -RP1: 1 and 3 are the ends of its track, 2 the wiper that runs from 1 to 3 as it is turned clockwise.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("pot"))
	s.places = [["pot", POT]]
	s.show = PackedStringArray(["pot"])
	s = lesson.step("Wire its track",
		"Wire 1 of -RP1 to - and 3 to the 10 V point. Turned fully anticlockwise the wiper gives 0 V, fully clockwise 10 V.",
		func(e: LessonCheck, _live: LessonCheck) -> bool:
			return e.has("pot") and e.has("ref") and e.has("minus") and e.joined(e.key("pot", 0), e.key("minus", 0)) and e.joined(e.key("pot", 2), e.key("ref", 0)))
	s.wires = [["minus", 0, "pot", 0], ["pot", 2, "ref", 0]]
	s = lesson.step("Wire the wiper to the analog input",
		"Wire 2 of -RP1 to AI0 of -A1. The PLC reads 0-10 V there as 0-27648 (%IW64); its analog inputs take their 0 V from 2M, wired to - already.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("pot") and e.has("plc") and e.joined(e.key("pot", 1), e.key("plc", ai0)))
	s.wires = [["pot", 1, "plc", ai0]]
	s = lesson.step("Switch to Simulate",
		"Click Simulate at the top. -A1 starts running its program: an analog threshold trigger between AI0 and the output Q0.0.",
		func(_e: LessonCheck, live: LessonCheck) -> bool: return live != null)
	s.control = "simulate"
	s.simulating = true
	s = lesson.step("Turn it past half",
		"Click -RP1 and drag the slider past 50 %. At half the range (5 V, 13824) the trigger switches Q0.0 on and -H1 lights.",
		func(_e: LessonCheck, live: LessonCheck) -> bool: return live != null and live.is_on("lamp"))
	s.hint = "Put -RP1 on a control station from the workspace to turn it with the mouse wheel like a real knob."
	s.focus = PackedStringArray(["pot"])
	s.simulating = true
	s = lesson.step("Turn it back a little",
		"Turn -RP1 back to 45 %: -H1 stays lit. The trigger switches off only under 40 % (4 V), so it does not flicker while the value wavers round the threshold. Turn it under 40 % to see it go dark.",
		func(_e: LessonCheck, live: LessonCheck) -> bool:
			return live != null and live.has("pot") and live.is_on("lamp") and (live.part("pot") as Potentiometer).setting < 0.5)
	s.focus = PackedStringArray(["pot"])
	s.simulating = true
	s = lesson.step("Set it finer",
		"Back in Edit, click -RP1 and set Turns to 10 in its properties: the whole track then takes ten turns of the knob, and each notch moves the value ten times less.",
		func(e: LessonCheck, _live: LessonCheck) -> bool: return e.has("pot") and (e.part("pot") as Potentiometer).turns > 1)
	s.control = "edit"
	s.focus = PackedStringArray(["pot"])
	s.property = ["pot", "turns"]

	var needs: Array = ["plc", "pot", "lamp"]
	lesson.goal("%s lights when %s is turned past half", ["lamp", "pot"], _phases([
		{"do": [["pot", "set 70"]], "expect": {"lamp": true}},
	]), needs)
	lesson.goal("%s stays dark while %s is under half", ["lamp", "pot"], _phases([
		{"do": [["pot", "set 30"]], "expect": {"lamp": false}},
	]), needs)
	lesson.goal("%s stays lit with %s turned back to 45 %%", ["lamp", "pot"], _phases([
		{"do": [["pot", "set 70"]], "expect": {"lamp": true}},
		{"do": [["pot", "set 45"]], "expect": {"lamp": true}},
	]), needs)
	lesson.goal("%s goes dark with %s under 40 %%", ["lamp", "pot"], _phases([
		{"do": [["pot", "set 70"]]},
		{"do": [["pot", "set 30"]], "expect": {"lamp": false}},
	]), needs)
	return lesson
