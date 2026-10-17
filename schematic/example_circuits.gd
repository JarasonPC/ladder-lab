class_name ExampleCircuits
extends RefCounted
## Built-in schematics, each with a power circuit driving a motor on the left
## (L1, L2, L3 on top) and its control circuit on the right, protected by
## circuit breakers (FA1 C16 for the power circuit, FA2 B2 for the control
## circuit) and wired to everything outside through terminal strips. Laid out with
## vertical current paths; [method build] can transpose them to horizontal.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC

const TITLES: PackedStringArray = [
	"Self-holding start/stop",
	"Forward/reverse with interlock",
	"Time relays",
	"Self-cutoff (oscillation)",
	"Short circuit",
	"Star/delta start",
	"Forward/reverse with button interlock",
	"Direct-on-line start 3~",
	"Forward/reverse 3~",
	"Star/delta start 3~",
	"Dahlander two-speed motor",
	"Two-speed motor, separate windings",
	"DC braking 3~",
	"Direct-on-line start 3~ on three pages",
	"PLC: start/stop with an on-delay",
]


static func count() -> int:
	return TITLES.size()


## Builds example [param index]; [param horizontal] draws current paths left to right.
static func build(index: int, horizontal: bool = false) -> SchematicDocument:
	var doc: SchematicDocument = null
	match index:
		0:
			doc = self_holding()
		1:
			doc = forward_reverse()
		2:
			doc = time_relays()
		3:
			doc = self_cutoff()
		4:
			doc = short_circuit()
		5:
			doc = star_delta()
		6:
			doc = forward_reverse_buttons()
		7:
			doc = direct_on_line()
		8:
			doc = forward_reverse_3()
		9:
			doc = star_delta_3()
		10:
			doc = dahlander()
		11:
			doc = two_windings()
		12:
			doc = dc_braking()
		13:
			doc = direct_on_line_pages()
		14:
			doc = plc_start_stop()
	if doc != null:
		_earth_motors(doc)
		_field_terminals(doc)
	if doc != null and doc.control_boxes.is_empty():
		doc.add_control_box_for_all()
	if doc != null and doc.cabinet_rails.is_empty():
		doc.fill_cabinet()
	if doc != null and horizontal:
		doc.transpose()
	return doc


## Every motor's PE terminal is wired to a PE supply point right under it.
static func _earth_motors(doc: SchematicDocument) -> void:
	var shown: int = doc.page
	for c: CircuitComponent in doc.circuit.get_components().duplicate():
		if not (c is ThreePhaseMotor):
			continue
		var key: String = c.designation + ":PE"
		doc.page = doc.page_of(c.id)
		var pe: PowerSupply = PowerSupply.new(doc.next_supply_designation(PowerSupply.Conductor.PE), PowerSupply.Conductor.PE)
		doc.add(pe, doc.terminal_cell(key) + Vector2i(0, 2), 2)
		doc.connect_terminals(pe.designation, key)
	doc.page = shown


## Everything outside the switchboard is wired through terminal strips: the
## supply comes in on strip X1 (one terminal per conductor, "X1:L1" ..
## "X1:PE"), push buttons, switches and lamps go out on X2, motors (with
## their PE) on X3, numbered page by page, left to right, top to bottom.
static func _field_terminals(doc: SchematicDocument) -> void:
	var parts: Array[CircuitComponent] = []
	for c: CircuitComponent in doc.circuit.get_components():
		if c is PowerSupply or c is PushButton or c is LatchingSwitch or c is Lamp or c is ThreePhaseMotor:
			parts.append(c)
	parts.sort_custom(func(a: CircuitComponent, b: CircuitComponent) -> bool:
		var ka: Vector3i = Vector3i(doc.page_of(a.id), doc.get_placement(a.id).cell.x, doc.get_placement(a.id).cell.y)
		var kb: Vector3i = Vector3i(doc.page_of(b.id), doc.get_placement(b.id).cell.x, doc.get_placement(b.id).cell.y)
		return ka < kb)
	var count: Dictionary[String, int] = {"X2": 0, "X3": 0}
	for c: CircuitComponent in parts:
		if c is PowerSupply:
			doc.set_strip_terminal(c.id, 0, "X1:" + (c as PowerSupply).conductor_name())
			continue
		var strip: String = "X3" if c is ThreePhaseMotor else "X2"
		for t: int in c.get_terminal_names().size():
			count[strip] += 1
			doc.set_strip_terminal(c.id, t, "%s:%d" % [strip, count[strip]])


## Signal lamp with its purpose written above it.
static func _lamp(designation: String, purpose: String) -> Lamp:
	var lamp: Lamp = Lamp.new(designation)
	lamp.purpose = purpose
	return lamp


## Push button on a control box, optionally illuminated by signal lamp [param lamp].
static func _panel_button(designation: String, color: String, label: String, lamp: String = "") -> ControlBoxItem:
	var item: ControlBoxItem = ControlBoxItem.new(ControlBoxItem.Kind.BUTTON, designation, color)
	item.label = label
	item.lamp = lamp
	return item


static func _c(points: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for p: Vector2i in points:
		result.append(p)
	return result


# --- Basic control circuits, each with its motor ---------------------------------
# Laid out like the three-phase examples below.

## Self-holding start/stop: FA1 - KM1 - overload relay F1 - M1. Control: SB0
## (STOP) and SB1 (START) with KM1 13-14 holding; KM1 23-24 lights H1.
static func self_holding() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[0])
	_motor_circuit(doc)
	var x: int = 16
	_start_stop(doc, x, _control_head(doc, x, ["F1"]))
	doc.add(Contact.new("KM1", NO, 2), Vector2i(x + 8, 17))
	doc.add(_lamp("H1", "Running"), Vector2i(x + 8, 22))
	doc.connect_terminals("FA2:2", "KM1:23", _c([Vector2i(x, 6), Vector2i(x + 8, 6)]))
	doc.connect_terminals("KM1:24", "H1:X1")
	doc.connect_terminals("H1:X2", "N", _c([Vector2i(x + 8, 27)]))
	return doc


## Forward/reverse (power as in [method forward_reverse_3]): two self-holding
## branches, each fed through an NC contact of the other contactor (electrical
## interlock); KM1 33-34 lights H1 (forward), KM2 33-34 lights H2 (reverse),
## the lamps inside the start buttons on the control box.
static func forward_reverse() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[1])
	_reversing_power(doc)
	var feed: String = _control_head(doc, 24, ["F1"])
	_two_way_control(doc, 24, 12, feed, "KM1", "KM2", 32, "SB0", "SB1", "SB2", false)
	_direction_lamps(doc, 24, 32)
	# Control box: illuminated start buttons (their lamps inside), stop below.
	var box: ControlBox = doc.add_control_box()
	box.items = [_panel_button("SB1", "green", "Forward", "H1"), _panel_button("SB2", "white", "Reverse", "H2"), _panel_button("SB0", "red", "Stop")]
	return doc


## Two motors started by time relays: RB1 feeds on-delay KT1, whose delayed
## 17-18 starts KM1 (motor M1) with H1 three seconds later; RB2 feeds
## off-delay KT2, whose delayed 17-18 runs KM2 (motor M2, e.g. a fan) with H2
## and keeps it running three seconds after RB2 is turned off. Each motor has
## its overload relay; both 95-96 are in the control supply.
static func time_relays() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[2])
	doc.add(_power_breaker(), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("KM1"), Vector2i(5, 10))
	doc.add(MainContacts.new("KM2"), Vector2i(13, 10))
	doc.add(OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(5, 15))
	doc.add(OverloadRelay.new("F2", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(13, 15))
	doc.add(ThreePhaseMotor.new("M1"), Vector2i(5, 20))
	doc.add(ThreePhaseMotor.new("M2"), Vector2i(13, 20))
	_straight(doc, "FA1", "KM1", POLES)
	_branch(doc, "FA1", "KM2", 7)
	_straight(doc, "KM1", "F1", POLES)
	_straight(doc, "KM2", "F2", POLES)
	_straight(doc, "F1", "M1", ["U1", "V1", "W1"])
	_straight(doc, "F2", "M2", ["U1", "V1", "W1"])

	var x: int = 24
	var feed: String = _control_head(doc, x, ["F1", "F2"])
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(x - 3, 27))
	var relays: Array = [["RB1", "KT1", TimerRelay.Mode.ON_DELAY, "KM1", "H1", "On-delay", x], ["RB2", "KT2", TimerRelay.Mode.OFF_DELAY, "KM2", "H2", "Off-delay", x + 18]]
	for r: Array in relays:
		var column: int = r[6]
		doc.add(LatchingSwitch.new(r[0], NO), Vector2i(column, 17))
		doc.add(TimerRelay.new(r[1], r[2], 3.0), Vector2i(column, 22))
		doc.add(Contact.new(r[1], NO, 1, true), Vector2i(column + 6, 17))
		doc.add(Coil.new(r[3]), Vector2i(column + 6, 22))
		doc.add(_lamp(r[4], r[5]), Vector2i(column + 12, 22))
		doc.connect_terminals(feed, r[0] + ":13", _c([Vector2i(x, 16), Vector2i(column, 16)]))
		doc.connect_terminals(r[0] + ":14", r[1] + ":A1")
		doc.connect_terminals(feed, r[1] + ":17", _c([Vector2i(x, 16), Vector2i(column + 6, 16)]))
		doc.connect_terminals(r[1] + ":18", r[3] + ":A1")
		doc.connect_terminals(r[1] + ":18", r[4] + ":X1", _c([Vector2i(column + 12, doc.terminal_cell(r[1] + ":18").y)]))
		doc.connect_terminals(r[1] + ":A2", "N", _c([Vector2i(column, 27)]))
		doc.connect_terminals(r[3] + ":A2", "N", _c([Vector2i(column + 6, 27)]))
		doc.connect_terminals(r[4] + ":X2", "N", _c([Vector2i(column + 12, 27)]))
	return doc


## A wiring mistake: SB1 feeds KM1 through its own NC contact, so KM1 cuts
## itself off as soon as it picks up and chatters while SB1 is held; the motor
## M1 behind its main contacts never gets going.
static func self_cutoff() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[3])
	_motor_circuit(doc)
	var x: int = 16
	var feed: String = _control_head(doc, x, ["F1"])
	doc.add(PushButton.new("SB1", NO), Vector2i(x, 12))
	doc.add(Contact.new("KM1", NC, 1), Vector2i(x, 17))
	doc.add(Coil.new("KM1"), Vector2i(x, 22))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(x - 3, 27))
	doc.connect_terminals(feed, "SB1:13")
	doc.connect_terminals("SB1:14", "KM1:11")
	doc.connect_terminals("KM1:12", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(x, 27)]))
	return doc


## A short circuit: a motor started by SB3 and stopped by SB0, and beside it
## SB1 and SB2 in series straight between L1 and N, next to lamp H1. The
## control circuit deliberately has no breaker, so pressing SB1 and SB2 together
## shows an unprotected short.
static func short_circuit() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[4])
	_motor_circuit(doc)
	var x: int = 16
	var n_row: int = 22
	doc.add(PowerSupply.new("L1.2", PowerSupply.Conductor.L), Vector2i(x - 3, 1))
	doc.add(OverloadContact.new("F1", NC), Vector2i(x, 2))
	doc.add(PushButton.new("SB0", NC), Vector2i(x, 7))
	doc.add(PushButton.new("SB3", NO), Vector2i(x, 12))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(x + 4, 12))
	doc.add(Coil.new("KM1"), Vector2i(x, 17))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(x - 3, n_row))
	doc.connect_terminals("L1.2", "F1:95", _c([Vector2i(x, 1)]))
	doc.connect_terminals("F1:96", "SB0:11")
	doc.connect_terminals("SB0:12", "SB3:13")
	doc.connect_terminals("SB0:12", "KM1:13", _c([Vector2i(x, 11), Vector2i(x + 4, 11)]))
	doc.connect_terminals("SB3:14", "KM1:14")
	doc.connect_terminals("SB3:14", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(x, n_row)]))
	# The short: SB1 and SB2 from L1 straight to N.
	doc.add(PushButton.new("SB1", NO), Vector2i(x + 9, 3))
	doc.add(PushButton.new("SB2", NO), Vector2i(x + 9, 8))
	doc.add(Lamp.new("H1"), Vector2i(x + 14, 5))
	doc.connect_terminals("L1.2", "SB1:13", _c([Vector2i(x + 9, 1)]))
	doc.connect_terminals("SB1:14", "SB2:13")
	doc.connect_terminals("SB2:14", "N", _c([Vector2i(x + 9, n_row)]))
	doc.connect_terminals("L1.2", "H1:X1", _c([Vector2i(x + 14, 1)]))
	doc.connect_terminals("H1:X2", "N", _c([Vector2i(x + 14, n_row)]))
	return doc


## Star/delta start while START is held (power and control as in
## [method star_delta_3]), with signal lamps: KM3 23-24 lights H1 (star),
## KM2 23-24 lights H2 (delta).
static func star_delta() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[5])
	_star_delta_power(doc)
	var x: int = 25
	_star_delta_control(doc, x)
	for lamp: Array in [["KM3", "H1", "Star", x + 16], ["KM2", "H2", "Delta", x + 22]]:
		var column: int = lamp[3]
		doc.add(Contact.new(lamp[0], NO, 2), Vector2i(column, 24))
		doc.add(_lamp(lamp[1], lamp[2]), Vector2i(column, 29))
		doc.connect_terminals("FA2:2", lamp[0] + ":23", _c([Vector2i(x, 6), Vector2i(column, 6)]))
		doc.connect_terminals(lamp[0] + ":24", lamp[1] + ":X1")
		doc.connect_terminals(lamp[1] + ":X2", "N", _c([Vector2i(column, 35)]))
	return doc


## Forward/reverse with electrical and button interlock (power as in
## [method forward_reverse_3]): each start button has a second, NC block
## (11-12) in the other direction's branch, so pressing the other button first
## drops the running contactor and then starts the other one, without pressing
## STOP. KM1 33-34 lights H1 (forward), KM2 33-34 lights H2 (reverse).
static func forward_reverse_buttons() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[6])
	_reversing_power(doc)
	var feed: String = _control_head(doc, 24, ["F1"])
	_two_way_control(doc, 24, 12, feed, "KM1", "KM2", 37, "SB0", "SB1", "SB2", true)
	_direction_lamps(doc, 24, 37)
	return doc


## KM1 33-34 lights H1 (forward), KM2 33-34 lights H2 (reverse), right of a
## [method _two_way_control] in column [param x], fed after the control breaker.
static func _direction_lamps(doc: SchematicDocument, x: int, n_row: int) -> void:
	for lamp: Array in [["KM1", "H1", "Forward", x + 17], ["KM2", "H2", "Reverse", x + 23]]:
		var column: int = lamp[3]
		doc.add(Contact.new(lamp[0], NO, 3), Vector2i(column, 17))
		doc.add(_lamp(lamp[1], lamp[2]), Vector2i(column, 22))
		doc.connect_terminals("FA2:2", lamp[0] + ":33", _c([Vector2i(x, 6), Vector2i(column, 6)]))
		doc.connect_terminals(lamp[0] + ":34", lamp[1] + ":X1")
		doc.connect_terminals(lamp[1] + ":X2", "N", _c([Vector2i(column, n_row)]))


# --- Three-phase power circuits -------------------------------------------------
# Power circuit on the left (L1, L2, L3 on top, poles two cells apart), control
# circuit on the right, fed from its own L1 supply point through breaker FA2 and the
# overload relay's 95-96.

const POLES: Array[String] = ["1", "3", "5"]
const POLE_OUTS: Array[String] = ["2", "4", "6"]


## Circuit breaker FA1 (C16, three poles) protecting the power circuit.
static func _power_breaker() -> MotorBreaker:
	var breaker: MotorBreaker = MotorBreaker.new("FA1")
	breaker.characteristic = CircuitBreaker.Characteristic.C
	breaker.rated_current = 16.0
	return breaker


## Circuit breaker FA2 (B2) protecting the control circuit.
static func _control_breaker() -> CircuitBreaker:
	var breaker: CircuitBreaker = CircuitBreaker.new("FA2")
	breaker.characteristic = CircuitBreaker.Characteristic.B
	breaker.rated_current = 2.0
	return breaker


static func _phases(doc: SchematicDocument, x: int) -> void:
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(x, 0))
	doc.add(PowerSupply.new("L2", PowerSupply.Conductor.L2), Vector2i(x + 2, 0))
	doc.add(PowerSupply.new("L3", PowerSupply.Conductor.L3), Vector2i(x + 4, 0))
	doc.connect_terminals("L1", "FA1:1")
	doc.connect_terminals("L2", "FA1:3")
	doc.connect_terminals("L3", "FA1:5")


## Wires the outputs 2, 4, 6 of [param from] straight down to [param to_terminals].
static func _straight(doc: SchematicDocument, from: String, to: String, to_terminals: Array) -> void:
	for i: int in 3:
		doc.connect_terminals("%s:%s" % [from, POLE_OUTS[i]], "%s:%s" % [to, to_terminals[i]])


## Feeds a second three-pole device [param to] (to the right) from the outputs
## of [param from], along rows [param first_row] .. + 2.
static func _branch(doc: SchematicDocument, from: String, to: String, first_row: int) -> void:
	for i: int in 3:
		var a: String = "%s:%s" % [from, POLE_OUTS[i]]
		var b: String = "%s:%s" % [to, POLES[i]]
		var ca: Vector2i = doc.terminal_cell(a)
		var cb: Vector2i = doc.terminal_cell(b)
		doc.connect_terminals(a, b, _c([Vector2i(ca.x, first_row + i), Vector2i(cb.x, first_row + i)]))


## Wires the outputs of [param from] down around to motor terminals coming
## from below, along rows [param first_row] .. + 2.
static func _from_below(doc: SchematicDocument, from: String, motor_terminals: Array, first_row: int) -> void:
	for i: int in 3:
		var a: String = "%s:%s" % [from, POLE_OUTS[i]]
		var b: String = "M1:%s" % motor_terminals[i]
		var ca: Vector2i = doc.terminal_cell(a)
		var cb: Vector2i = doc.terminal_cell(b)
		doc.connect_terminals(a, b, _c([Vector2i(ca.x, first_row + i), Vector2i(cb.x, first_row + i)]))


## Joins the outputs 2, 4, 6 of [param contacts] one row below them (star point).
static func _star_bridge(doc: SchematicDocument, contacts: String) -> void:
	var y: int = doc.terminal_cell(contacts + ":2").y + 1
	for i: int in 2:
		var a: String = "%s:%s" % [contacts, POLE_OUTS[i]]
		var b: String = "%s:%s" % [contacts, POLE_OUTS[i + 1]]
		doc.connect_terminals(a, b, _c([Vector2i(doc.terminal_cell(a).x, y), Vector2i(doc.terminal_cell(b).x, y)]))


## Control supply: L1.2 at ([param x] - 3, 1), control breaker FA2 (B2) and
## the 95-96 of each overload relay in [param overloads], one under the other
## in column [param x] from row 2. Returns the key of the last 96; the next
## part goes at row 7 + 5 * overloads.size().
static func _control_head(doc: SchematicDocument, x: int, overloads: Array) -> String:
	doc.add(PowerSupply.new("L1.2", PowerSupply.Conductor.L), Vector2i(x - 3, 1))
	doc.add(_control_breaker(), Vector2i(x, 2))
	doc.connect_terminals("L1.2", "FA2:1", _c([Vector2i(x, 1)]))
	var last: String = "FA2:2"
	for i: int in overloads.size():
		doc.add(OverloadContact.new(overloads[i], NC), Vector2i(x, 7 + 5 * i))
		doc.connect_terminals(last, overloads[i] + ":95")
		last = overloads[i] + ":96"
	return last


## Two contactors [param a] and [param b] started by [param start_a] and
## [param start_b], held by their 13-14, stopped by [param stop] (at row
## [param top]) and interlocked by each other's 21-22. With
## [param button_interlock] each start button also has an NC block 11-12 in
## the other branch (as in the guide). [param feed] is the terminal feeding STOP.
static func _two_way_control(doc: SchematicDocument, x: int, top: int, feed: String, a: String, b: String, n_row: int, stop: String, start_a: String, start_b: String, button_interlock: bool) -> void:
	var xb: int = x + 8
	doc.add(PushButton.new(stop, NC), Vector2i(x, top))
	doc.connect_terminals(feed, stop + ":11")
	var row: int = top + 5
	doc.add(PushButton.new(start_a, NO), Vector2i(x, row))
	doc.add(Contact.new(a, NO, 1), Vector2i(x + 4, row))
	doc.add(PushButton.new(start_b, NO), Vector2i(xb, row))
	doc.add(Contact.new(b, NO, 1), Vector2i(xb + 4, row))
	var node: String = stop + ":12"
	doc.connect_terminals(node, start_a + ":13")
	doc.connect_terminals(node, a + ":13", _c([Vector2i(x, row - 1), Vector2i(x + 4, row - 1)]))
	doc.connect_terminals(node, start_b + ":13", _c([Vector2i(x, row - 1), Vector2i(xb, row - 1)]))
	doc.connect_terminals(node, b + ":13", _c([Vector2i(x, row - 1), Vector2i(xb + 4, row - 1)]))
	doc.connect_terminals(start_a + ":14", a + ":14")
	doc.connect_terminals(start_b + ":14", b + ":14")
	var below_a: String = start_a + ":14"
	var below_b: String = start_b + ":14"
	row += 5
	if button_interlock:
		doc.add(PushButton.new(start_b, NC), Vector2i(x, row))
		doc.add(PushButton.new(start_a, NC), Vector2i(xb, row))
		doc.connect_terminals(below_a, start_b + ":11")
		doc.connect_terminals(below_b, start_a + ":11")
		below_a = start_b + ":12"
		below_b = start_a + ":12"
		row += 5
	doc.add(Contact.new(b, NC, 2), Vector2i(x, row))
	doc.add(Contact.new(a, NC, 2), Vector2i(xb, row))
	doc.connect_terminals(below_a, b + ":21")
	doc.connect_terminals(below_b, a + ":21")
	row += 5
	doc.add(Coil.new(a), Vector2i(x, row))
	doc.add(Coil.new(b), Vector2i(xb, row))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(x - 3, n_row))
	doc.connect_terminals(b + ":22", a + ":A1")
	doc.connect_terminals(a + ":22", b + ":A1")
	doc.connect_terminals(a + ":A2", "N", _c([Vector2i(x, n_row)]))
	doc.connect_terminals(b + ":A2", "N", _c([Vector2i(xb, n_row), Vector2i(x, n_row)]))


## The power circuit of one motor in column 5: L1, L2, L3 - breaker FA1 - main
## contacts KM1 - overload relay F1 - motor M1.
static func _motor_circuit(doc: SchematicDocument) -> void:
	doc.add(_power_breaker(), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("KM1"), Vector2i(5, 7))
	doc.add(OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(5, 12))
	doc.add(ThreePhaseMotor.new("M1"), Vector2i(5, 17))
	_straight(doc, "FA1", "KM1", POLES)
	_straight(doc, "KM1", "F1", POLES)
	_straight(doc, "F1", "M1", ["U1", "V1", "W1"])


## Start/stop of KM1 in column [param x] below a [method _control_head]
## ending in [param feed]: SB0 (STOP), SB1 (START) with KM1 13-14 holding,
## the coil, N at row 27.
static func _start_stop(doc: SchematicDocument, x: int, feed: String) -> void:
	doc.add(PushButton.new("SB0", NC), Vector2i(x, 12))
	doc.add(PushButton.new("SB1", NO), Vector2i(x, 17))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(x + 4, 17))
	doc.add(Coil.new("KM1"), Vector2i(x, 22))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(x - 3, 27))
	doc.connect_terminals(feed, "SB0:11")
	doc.connect_terminals("SB0:12", "SB1:13")
	doc.connect_terminals("SB0:12", "KM1:13", _c([Vector2i(x, 16), Vector2i(x + 4, 16)]))
	doc.connect_terminals("SB1:14", "KM1:14")
	doc.connect_terminals("SB1:14", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(x, 27)]))


## Direct-on-line start: FA1 - KM1 - overload relay F1 - M1; SB0 / SB1 with KM1 13-14
## holding in the control circuit. Signal lamps as on page 40 of the guide:
## H1 control voltage on, H2 overload tripped (F1 97-98), H3 running (KM1 23-24,
## a contact of the contactor itself, so a broken coil shows as not running).
static func direct_on_line() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[7])
	_motor_circuit(doc)
	var x: int = 16
	_start_stop(doc, x, _control_head(doc, x, ["F1"]))
	# Signal lamps, fed after the control breaker.
	doc.add(_lamp("H1", "Voltage on"), Vector2i(24, 22))
	doc.add(OverloadContact.new("F1", NO), Vector2i(31, 7))
	doc.add(_lamp("H2", "Fault"), Vector2i(31, 22))
	doc.add(Contact.new("KM1", NO, 2), Vector2i(38, 17))
	doc.add(_lamp("H3", "Running"), Vector2i(38, 22))
	doc.connect_terminals("FA2:2", "H1:X1", _c([Vector2i(x, 6), Vector2i(24, 6)]))
	doc.connect_terminals("FA2:2", "F1:97", _c([Vector2i(x, 6), Vector2i(31, 6)]))
	doc.connect_terminals("F1:98", "H2:X1")
	doc.connect_terminals("FA2:2", "KM1:23", _c([Vector2i(x, 6), Vector2i(38, 6)]))
	doc.connect_terminals("KM1:24", "H3:X1")
	for lamp: Array in [["H1", 24], ["H2", 31], ["H3", 38]]:
		doc.connect_terminals(lamp[0] + ":X2", "N", _c([Vector2i(lamp[1], 27)]))
	return doc


## Forward/reverse: KM1 feeds the motor L1-L2-L3, KM2 with L1 and L3 swapped;
## the contactors are interlocked by each other's 21-22.
static func forward_reverse_3() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[8])
	_reversing_power(doc)
	var feed: String = _control_head(doc, 24, ["F1"])
	_two_way_control(doc, 24, 12, feed, "KM1", "KM2", 32, "SB0", "SB1", "SB2", false)
	return doc


## Reversing power circuit: FA1, KM1 straight and KM2 with L1 and L3 swapped,
## overload relay F1, motor M1.
static func _reversing_power(doc: SchematicDocument) -> void:
	doc.add(_power_breaker(), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("KM1"), Vector2i(5, 10))
	doc.add(MainContacts.new("KM2"), Vector2i(13, 10))
	doc.add(OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(5, 18))
	doc.add(ThreePhaseMotor.new("M1"), Vector2i(5, 24))
	_straight(doc, "FA1", "KM1", POLES)
	_branch(doc, "FA1", "KM2", 7)
	_straight(doc, "KM1", "F1", POLES)
	# KM2 swaps L1 and L3.
	doc.connect_terminals("KM2:2", "F1:5", _c([Vector2i(13, 15), Vector2i(9, 15)]))
	doc.connect_terminals("KM2:4", "F1:3", _c([Vector2i(15, 16), Vector2i(7, 16)]))
	doc.connect_terminals("KM2:6", "F1:1", _c([Vector2i(17, 17), Vector2i(5, 17)]))
	_straight(doc, "F1", "M1", ["U1", "V1", "W1"])


## Star/delta: KM1 feeds U1-V1-W1, KM3 joins U2-V2-W2 (star) while SB2 is held,
## then KM2 feeds U2-V2-W2 from L2, L3, L1 (delta). Control as in
## [method star_delta].
static func star_delta_3() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[9])
	_star_delta_power(doc)
	_star_delta_control(doc, 25)
	return doc


## Star/delta power circuit: KM1 feeds U1-V1-W1 through overload relay F1, KM2
## feeds W2-U2-V2 (delta), KM3 joins U2-V2-W2 (star).
static func _star_delta_power(doc: SchematicDocument) -> void:
	doc.add(_power_breaker(), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("KM1"), Vector2i(5, 10))
	doc.add(MainContacts.new("KM2"), Vector2i(13, 10))
	# F1 carries the winding current: set to In / √3.
	var relay: OverloadRelay = OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3)
	relay.setting = 4.6
	doc.add(relay, Vector2i(5, 15))
	doc.add(ThreePhaseMotor.new("M1", ThreePhaseMotor.Kind.STAR_DELTA), Vector2i(5, 21))
	doc.add(MainContacts.new("KM3"), Vector2i(5, 32))
	_straight(doc, "FA1", "KM1", POLES)
	_branch(doc, "FA1", "KM2", 7)
	_straight(doc, "KM1", "F1", POLES)
	_straight(doc, "F1", "M1", ["U1", "V1", "W1"])
	# Delta: U1-W2, V1-U2, W1-V2.
	_from_below(doc, "KM2", ["W2", "U2", "V2"], 28)
	doc.connect_terminals("M1:W2", "KM3:1")
	doc.connect_terminals("M1:U2", "KM3:3")
	doc.connect_terminals("M1:V2", "KM3:5")
	_star_bridge(doc, "KM3")


## Star/delta control in column [param x]: FA2 and F1 95-96 feed STOP SB1;
## SB2 starts star KM3 (through KM2 11-12), whose 13-14 brings in KM1, held by
## KM1 13-14; letting go of SB2 drops KM3, and its 11-12 brings in delta KM2.
static func _star_delta_control(doc: SchematicDocument, x: int) -> void:
	var feed: String = _control_head(doc, x, ["F1"])
	doc.add(PushButton.new("SB1", NC), Vector2i(x, 12))
	doc.add(PushButton.new("SB2", NO), Vector2i(x, 19))
	doc.add(Contact.new("KM2", NC, 1), Vector2i(x, 24))
	doc.add(Coil.new("KM3"), Vector2i(x, 29))
	doc.add(Contact.new("KM3", NO, 1), Vector2i(x + 5, 19))
	doc.add(Coil.new("KM1"), Vector2i(x + 5, 29))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(x + 10, 19))
	doc.add(Contact.new("KM3", NC, 1), Vector2i(x + 10, 24))
	doc.add(Coil.new("KM2"), Vector2i(x + 10, 29))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(x - 3, 35))
	doc.connect_terminals(feed, "SB1:11")
	doc.connect_terminals("SB1:12", "SB2:13")
	doc.connect_terminals("SB1:12", "KM3:13", _c([Vector2i(x, 17), Vector2i(x + 5, 17)]))
	doc.connect_terminals("SB1:12", "KM1:13", _c([Vector2i(x, 17), Vector2i(x + 10, 17)]))
	doc.connect_terminals("SB2:14", "KM2:11")
	doc.connect_terminals("KM2:12", "KM3:A1")
	doc.connect_terminals("KM3:A2", "N", _c([Vector2i(x, 35)]))
	doc.connect_terminals("KM3:14", "KM1:A1")
	doc.connect_terminals("KM3:14", "KM1:14", _c([Vector2i(x + 5, 23), Vector2i(x + 10, 23)]))
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(x + 5, 35)]))
	doc.connect_terminals("KM1:14", "KM3:11")
	doc.connect_terminals("KM3:12", "KM2:A1")
	doc.connect_terminals("KM2:A2", "N", _c([Vector2i(x + 10, 35)]))


## Power part shared by the two-speed motors, as on page 47 of the guide:
## FA1, then KM1 - overload relay F1 - 1U-1V-1W (low speed, from above) and
## KM2 - overload relay F2 - 2U-2V-2W (high speed, from below). Each speed has
## its own overload relay, set to the current of that speed.
static func _two_speed_power(doc: SchematicDocument, kind: ThreePhaseMotor.Kind) -> void:
	doc.add(_power_breaker(), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("KM1"), Vector2i(5, 11))
	doc.add(MainContacts.new("KM2"), Vector2i(13, 11))
	var low: OverloadRelay = OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3)
	low.setting = 4.5
	doc.add(low, Vector2i(5, 16))
	doc.add(OverloadRelay.new("F2", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(13, 16))
	doc.add(ThreePhaseMotor.new("M1", kind), Vector2i(5, 23))
	_straight(doc, "FA1", "KM1", POLES)
	_branch(doc, "FA1", "KM2", 7)
	_straight(doc, "KM1", "F1", POLES)
	_straight(doc, "KM2", "F2", POLES)
	_straight(doc, "F1", "M1", ["1U", "1V", "1W"])
	_from_below(doc, "F2", ["2U", "2V", "2W"], 30)


## Dahlander: low speed KM1 feeds 1U-1V-1W (delta); high speed KM3 joins
## 1U-1V-1W (star point) and KM2 feeds 2U-2V-2W (double star). SB1 starts low
## speed; SB2 starts KM3, whose 13-14 then switches KM2 on, so the motor never
## gets high speed without its star point. KM3 21-22 keeps KM1 off while the
## star point is closed, KM1 21-22 keeps KM3 off. Control breaker FA2, then the
## 95-96 of both overload relays.
static func dahlander() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[10])
	_two_speed_power(doc, ThreePhaseMotor.Kind.DAHLANDER)
	doc.add(MainContacts.new("KM3"), Vector2i(21, 24))
	for i: int in 3:
		var a: String = "F1:" + POLE_OUTS[i]
		var x: int = doc.terminal_cell(a).x
		doc.connect_terminals(a, "KM3:" + POLES[i], _c([Vector2i(x, 20 + i), Vector2i(21 + 2 * i, 20 + i)]))
	_star_bridge(doc, "KM3")

	var x: int = 32
	var xb: int = x + 8
	var feed: String = _control_head(doc, x, ["F1", "F2"])
	doc.add(PushButton.new("SB0", NC), Vector2i(x, 17))
	doc.add(PushButton.new("SB1", NO), Vector2i(x, 22))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(x + 4, 22))
	doc.add(Contact.new("KM3", NC, 2), Vector2i(x, 27))
	doc.add(Coil.new("KM1"), Vector2i(x, 32))
	doc.add(PushButton.new("SB2", NO), Vector2i(xb, 22))
	doc.add(Contact.new("KM2", NO, 1), Vector2i(xb + 4, 22))
	doc.add(Contact.new("KM1", NC, 2), Vector2i(xb, 27))
	doc.add(Coil.new("KM3"), Vector2i(xb, 32))
	doc.add(Contact.new("KM3", NO, 1), Vector2i(xb + 8, 27))
	doc.add(Coil.new("KM2"), Vector2i(xb + 8, 32))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(x - 3, 38))
	doc.connect_terminals(feed, "SB0:11")
	doc.connect_terminals("SB0:12", "SB1:13")
	doc.connect_terminals("SB0:12", "KM1:13", _c([Vector2i(x, 21), Vector2i(x + 4, 21)]))
	doc.connect_terminals("SB0:12", "SB2:13", _c([Vector2i(x, 21), Vector2i(xb, 21)]))
	doc.connect_terminals("SB0:12", "KM2:13", _c([Vector2i(x, 21), Vector2i(xb + 4, 21)]))
	doc.connect_terminals("SB1:14", "KM1:14")
	doc.connect_terminals("SB1:14", "KM3:21")
	doc.connect_terminals("KM3:22", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(x, 38)]))
	doc.connect_terminals("SB2:14", "KM2:14")
	doc.connect_terminals("SB2:14", "KM1:21")
	doc.connect_terminals("KM1:22", "KM3:A1")
	doc.connect_terminals("KM3:A2", "N", _c([Vector2i(xb, 38), Vector2i(x, 38)]))
	doc.connect_terminals("KM2:14", "KM3:13", _c([Vector2i(xb + 4, 26), Vector2i(xb + 8, 26)]))
	doc.connect_terminals("KM3:14", "KM2:A1")
	doc.connect_terminals("KM2:A2", "N", _c([Vector2i(xb + 8, 38), Vector2i(x, 38)]))
	return doc


## Two separate windings, as on page 47 of the guide: KM1 feeds the low-speed
## winding 1U-1V-1W, KM2 the high-speed winding 2U-2V-2W. SB1 stops, SB2 starts
## low speed, SB3 high speed; each start button has an NC block 11-12 in the
## other branch and each contactor an NC 21-22 there (button and contactor
## interlock), so switching speed works without STOP.
static func two_windings() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[11])
	_two_speed_power(doc, ThreePhaseMotor.Kind.TWO_WINDINGS)
	var feed: String = _control_head(doc, 24, ["F1", "F2"])
	_two_way_control(doc, 24, 17, feed, "KM1", "KM2", 42, "SB1", "SB2", "SB3", true)
	return doc


## DC braking: KM1 runs the motor (direct-on-line start). Bridge rectifier
## TB1, fed from L2 and L3 behind FA1, makes the DC. SB0 stops the motor with
## its 11-12 and starts braking with its 23-24: as soon as KM1 has released
## (its 31-32), KM2 feeds + and - of TB1 into U1 and V1, held by its 13-14,
## until time relay KT1 opens its delayed 55-56. KM1 and KM2 are interlocked
## by each other's NC contacts. Braking starts right after the AC is cut,
## while the rotor field is still there; without it the motor would run down
## in its run-down time.
static func dc_braking() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[12])
	doc.add(_power_breaker(), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("KM1"), Vector2i(5, 10))
	doc.add(Rectifier.new("TB1"), Vector2i(13, 9))
	var brake: MainContacts = MainContacts.new("KM2")
	brake.poles = 2
	doc.add(brake, Vector2i(13, 14))
	doc.add(OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(5, 20))
	var motor: ThreePhaseMotor = ThreePhaseMotor.new("M1")
	motor.coast_time = 6.0
	motor.brake_time = 1.5
	doc.add(motor, Vector2i(5, 26))
	_straight(doc, "FA1", "KM1", POLES)
	_straight(doc, "KM1", "F1", POLES)
	_straight(doc, "F1", "M1", ["U1", "V1", "W1"])
	# TB1 between L2 and L3.
	doc.connect_terminals("FA1:6", "TB1:~2", _c([Vector2i(9, 7), Vector2i(15, 7)]))
	doc.connect_terminals("FA1:4", "TB1:~1", _c([Vector2i(7, 8), Vector2i(13, 8)]))
	doc.connect_terminals("TB1:+", "KM2:1")
	doc.connect_terminals("TB1:-", "KM2:3")
	# DC into U1 and V1 (through the heaters of F1).
	doc.connect_terminals("KM2:2", "F1:1", _c([Vector2i(13, 18), Vector2i(5, 18)]))
	doc.connect_terminals("KM2:4", "F1:3", _c([Vector2i(15, 19), Vector2i(7, 19)]))

	var x: int = 24
	var xb: int = x + 8
	var n_row: int = 32
	var feed: String = _control_head(doc, x, ["F1"])
	# Run: SB0 11-12, SB1 (or KM1 holding), KM2's NC interlock, KM1.
	doc.add(PushButton.new("SB0", NC), Vector2i(x, 12))
	doc.add(PushButton.new("SB1", NO), Vector2i(x, 17))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(x + 4, 17))
	doc.add(Contact.new("KM2", NC, 2), Vector2i(x, 22))
	doc.add(Coil.new("KM1"), Vector2i(x, 27))
	# Brake: SB0 23-24 (or KM2 holding), KT1's delayed 55-56, KM1's NC
	# interlock, KM2; KT1 is fed before its own contact, so it does not restart
	# while SB0 is still held.
	doc.add(PushButton.new("SB0", NO, 2), Vector2i(xb, 12))
	doc.add(Contact.new("KM2", NO, 1), Vector2i(xb + 6, 12))
	doc.add(Contact.new("KT1", NC, 5, true), Vector2i(xb, 17))
	doc.add(Contact.new("KM1", NC, 3), Vector2i(xb, 22))
	doc.add(Coil.new("KM2"), Vector2i(xb, 27))
	doc.add(TimerRelay.new("KT1", TimerRelay.Mode.ON_DELAY, 2.0), Vector2i(xb + 6, 27))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(x - 3, n_row))
	doc.connect_terminals(feed, "SB0:11")
	doc.connect_terminals("SB0:12", "SB1:13")
	doc.connect_terminals("SB0:12", "KM1:13", _c([Vector2i(x, 16), Vector2i(x + 4, 16)]))
	doc.connect_terminals("SB1:14", "KM1:14")
	doc.connect_terminals("SB1:14", "KM2:21")
	doc.connect_terminals("KM2:22", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(x, n_row)]))
	doc.connect_terminals(feed, "SB0:23", _c([Vector2i(x, 11), Vector2i(xb, 11)]))
	doc.connect_terminals(feed, "KM2:13", _c([Vector2i(x, 11), Vector2i(xb + 6, 11)]))
	doc.connect_terminals("SB0:24", "KM2:14")
	doc.connect_terminals("SB0:24", "KT1:55")
	doc.connect_terminals("KM2:14", "KT1:A1")
	doc.connect_terminals("KT1:56", "KM1:31")
	doc.connect_terminals("KM1:32", "KM2:A1")
	doc.connect_terminals("KM2:A2", "N", _c([Vector2i(xb, n_row)]))
	doc.connect_terminals("KT1:A2", "N", _c([Vector2i(xb + 6, n_row)]))
	var box: ControlBox = doc.add_control_box()
	box.items = [_panel_button("SB1", "green", "Start"), _panel_button("SB0", "red", "Stop")]
	return doc


## [method direct_on_line] drawn on three pages, as a real project: the power
## circuit, the control circuit (KM1's coil, its main contacts stay on the
## power page) and the signalling. The control voltage after FA2 and F1 95-96
## continues to the signalling page through page connectors; the wires are
## numbered, so the connectors carry the wire number of their link.
static func direct_on_line_pages() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[13])
	doc.pages = PackedStringArray(["Power section", "Control section", "Signalling section"])
	_motor_circuit(doc)

	doc.page = 1
	var x: int = 8
	_start_stop(doc, x, _control_head(doc, x, ["F1"]))
	# The signalling page is fed after the control breaker: arrow to the right.
	doc.add(PageConnector.new("PC1", "1"), Vector2i(16, 6), 1)
	doc.connect_terminals("FA2:2", "PC1", _c([Vector2i(x, 6)]))

	doc.page = 2
	doc.add(PageConnector.new("PC2", "1"), Vector2i(5, 4), 3)
	doc.add(_lamp("H1", "Voltage on"), Vector2i(8, 12))
	doc.add(OverloadContact.new("F1", NO), Vector2i(15, 7))
	doc.add(_lamp("H2", "Fault"), Vector2i(15, 12))
	doc.add(Contact.new("KM1", NO, 2), Vector2i(22, 7))
	doc.add(_lamp("H3", "Running"), Vector2i(22, 12))
	doc.add(PowerSupply.new("N.2", PowerSupply.Conductor.N), Vector2i(5, 17))
	doc.connect_terminals("PC2", "H1:X1", _c([Vector2i(8, 4)]))
	doc.connect_terminals("PC2", "F1:97", _c([Vector2i(15, 4)]))
	doc.connect_terminals("F1:98", "H2:X1")
	doc.connect_terminals("PC2", "KM1:23", _c([Vector2i(22, 4)]))
	doc.connect_terminals("KM1:24", "H3:X1")
	for lamp: Array in [["H1", 8], ["H2", 15], ["H3", 22]]:
		doc.connect_terminals(lamp[0] + ":X2", "N.2", _c([Vector2i(lamp[1], 17)]))
	doc.number_wires()
	doc.page = 0
	return doc


## Motor M1 (power as in [method direct_on_line]) run by PLC A1, fed
## through FA2: start button SB1 (NO) on I1, stop button SB0 (NC) on I2 in
## series with the overload relay's 95-96, so a trip stops the motor like STOP.
## Output Q1 switches KM1 (KM1 13-14 lights H1), Q2 lights H2 five seconds
## later. The program (function block diagram): Q1 = (I1 OR Q1) AND I2, Q2 =
## on-delay of Q1; the same in the ladder diagram, switched to in the PLC window.
static func plc_start_stop() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[14])
	_motor_circuit(doc)
	var px: int = 22
	var n_row: int = 30
	doc.add(PowerSupply.new("L1.2", PowerSupply.Conductor.L), Vector2i(16, 1))
	doc.add(_control_breaker(), Vector2i(19, 2))
	doc.add(PushButton.new("SB1", NO), Vector2i(px + 4, 12))
	doc.add(OverloadContact.new("F1", NC), Vector2i(px + 9, 7))
	doc.add(PushButton.new("SB0", NC), Vector2i(px + 9, 12))
	doc.add(Plc.new("A1", plc_start_stop_program()), Vector2i(px, 17))
	doc.add(Coil.new("KM1"), Vector2i(px + 2, 25))
	doc.add(_lamp("H2", "Delayed"), Vector2i(px + 7, 25))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(px + 22, 20))
	doc.add(_lamp("H1", "Running"), Vector2i(px + 22, 25))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(16, n_row))

	doc.connect_terminals("L1.2", "FA2:1", _c([Vector2i(19, 1)]))
	doc.connect_terminals("FA2:2", "A1:L1", _c([Vector2i(19, 6), Vector2i(px, 6)]))
	doc.connect_terminals("A1:N", "N", _c([Vector2i(px + 2, 15), Vector2i(17, 15), Vector2i(17, n_row)]))
	doc.connect_terminals("FA2:2", "SB1:13", _c([Vector2i(19, 6), Vector2i(px + 4, 6)]))
	doc.connect_terminals("FA2:2", "F1:95", _c([Vector2i(19, 6), Vector2i(px + 9, 6)]))
	doc.connect_terminals("F1:96", "SB0:11")
	doc.connect_terminals("SB1:14", "A1:I1")
	doc.connect_terminals("SB0:12", "A1:I2", _c([Vector2i(px + 9, 16), Vector2i(px + 6, 16)]))
	doc.connect_terminals("FA2:2", "A1:Q1.1", _c([Vector2i(19, 24), Vector2i(px, 24)]))
	doc.connect_terminals("A1:Q1.1", "A1:Q2.1", _c([Vector2i(px, 24), Vector2i(px + 5, 24)]))
	doc.connect_terminals("A1:Q1.2", "KM1:A1")
	doc.connect_terminals("A1:Q2.2", "H2:X1")
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(px + 2, n_row)]))
	doc.connect_terminals("H2:X2", "N", _c([Vector2i(px + 7, n_row)]))
	doc.connect_terminals("FA2:2", "KM1:13", _c([Vector2i(19, 6), Vector2i(px + 22, 6)]))
	doc.connect_terminals("KM1:14", "H1:X1")
	doc.connect_terminals("H1:X2", "N", _c([Vector2i(px + 22, n_row)]))
	return doc


## Program of [method plc_start_stop]: self-holding Q1 started by I1 and
## stopped by I2 (the NC stop button), Q2 five seconds after Q1.
static func plc_start_stop_program() -> PlcProgram:
	var p: PlcProgram = PlcProgram.new()
	var start: PlcBlock = p.add_block("input", Vector2i(0, 0))
	var stop: PlcBlock = p.add_block("input", Vector2i(0, 6))
	stop.operand = "I2"
	var gate_or: PlcBlock = p.add_block("or", Vector2i(6, 0))
	var gate_and: PlcBlock = p.add_block("and", Vector2i(12, 1))
	var q1: PlcBlock = p.add_block("output", Vector2i(19, 2))
	var delay: PlcBlock = p.add_block("on_delay", Vector2i(19, 8))
	delay.time = 5.0
	var q2: PlcBlock = p.add_block("output", Vector2i(26, 8))
	q2.operand = "Q2"
	gate_or.inputs[0] = start.id
	gate_or.inputs[1] = q1.id
	gate_and.inputs[0] = gate_or.id
	gate_and.inputs[1] = stop.id
	q1.inputs[0] = gate_and.id
	delay.inputs[0] = q1.id
	q2.inputs[0] = delay.id
	# The same as a ladder: rung 1 self-holding Q1, rung 2 the timer T1,
	# rung 3 Q2 from T1.
	var ladder: PlcRung = p.ladder()
	ladder.set_cell(0, 0, {"kind": "no", "operand": "I1"})
	ladder.set_cell(0, 1, {"kind": "no", "operand": "I2"})
	ladder.set_coil(0, {"kind": "coil", "operand": "Q1"})
	ladder.wire_to_coil(0)
	ladder.set_cell(1, 0, {"kind": "no", "operand": "Q1"})
	ladder.set_link(0, 0, true)
	ladder.set_cell(2, 0, {"kind": "no", "operand": "Q1"})
	ladder.set_coil(2, {"kind": "on_delay", "operand": "T1", "time": 5.0})
	ladder.wire_to_coil(2)
	ladder.set_cell(3, 0, {"kind": "no", "operand": "T1"})
	ladder.set_coil(3, {"kind": "coil", "operand": "Q2"})
	ladder.wire_to_coil(3)
	return p
