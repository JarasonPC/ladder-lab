class_name ExampleCircuits
extends RefCounted
## Built-in schematics. Laid out with vertical current paths (L supply top left,
## N supply bottom left); [method build] can transpose them to horizontal.

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
	if doc != null and horizontal:
		doc.transpose()
	return doc


static func _supplies(doc: SchematicDocument, n_row: int) -> void:
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, n_row))


static func _c(points: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for p: Vector2i in points:
		result.append(p)
	return result


## L - S0 - S1 (K1 13-14 in parallel) - K1; K1 23-24 switches H1.
static func self_holding() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[0])
	_supplies(doc, 18)
	doc.add(PushButton.new("S0", NC), Vector2i(5, 3))
	doc.add(PushButton.new("S1", NO), Vector2i(5, 8))
	doc.add(Contact.new("K1", NO, 1), Vector2i(8, 8))
	doc.add(Coil.new("K1"), Vector2i(5, 13))
	doc.add(Contact.new("K1", NO, 2), Vector2i(12, 8))
	doc.add(Lamp.new("H1"), Vector2i(12, 13))

	doc.connect_terminals("L", "S0:11", _c([Vector2i(5, 1)]))
	doc.connect_terminals("S0:12", "S1:13")
	doc.connect_terminals("S0:12", "K1:13", _c([Vector2i(5, 7), Vector2i(8, 7)]))
	doc.connect_terminals("S1:14", "K1:14", _c([Vector2i(5, 12), Vector2i(8, 12)]))
	doc.connect_terminals("S1:14", "K1:A1")
	doc.connect_terminals("K1:A2", "N", _c([Vector2i(5, 18)]))
	doc.connect_terminals("L", "K1:23", _c([Vector2i(12, 1)]))
	doc.connect_terminals("K1:24", "H1:X1")
	doc.connect_terminals("H1:X2", "N", _c([Vector2i(12, 18)]))
	return doc


## Two self-holding branches, each fed through an NC contact of the other
## contactor; motor M1 runs from K1 33-34 or K2 33-34.
static func forward_reverse() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[1])
	_supplies(doc, 23)
	doc.add(PushButton.new("S0", NC), Vector2i(5, 3))
	doc.add(PushButton.new("S1", NO), Vector2i(5, 8))
	doc.add(PushButton.new("S2", NO), Vector2i(13, 8))
	doc.add(Contact.new("K1", NO, 1), Vector2i(8, 8))
	doc.add(Contact.new("K1", NC, 2), Vector2i(13, 13))
	doc.add(Contact.new("K1", NO, 3), Vector2i(21, 8))
	doc.add(Contact.new("K2", NO, 1), Vector2i(16, 8))
	doc.add(Contact.new("K2", NC, 2), Vector2i(5, 13))
	doc.add(Contact.new("K2", NO, 3), Vector2i(25, 8))
	doc.add(Coil.new("K1"), Vector2i(5, 18))
	doc.add(Coil.new("K2"), Vector2i(13, 18))
	doc.add(Motor.new("M1"), Vector2i(21, 15))

	doc.connect_terminals("L", "S0:11", _c([Vector2i(5, 1)]))
	# Forward.
	doc.connect_terminals("S0:12", "S1:13")
	doc.connect_terminals("S0:12", "K1:13", _c([Vector2i(5, 7), Vector2i(8, 7)]))
	doc.connect_terminals("S1:14", "K1:14", _c([Vector2i(5, 12), Vector2i(8, 12)]))
	doc.connect_terminals("S1:14", "K2:21")
	doc.connect_terminals("K2:22", "K1:A1")
	doc.connect_terminals("K1:A2", "N", _c([Vector2i(5, 23)]))
	# Reverse.
	doc.connect_terminals("S0:12", "S2:13", _c([Vector2i(5, 7), Vector2i(13, 7)]))
	doc.connect_terminals("S0:12", "K2:13", _c([Vector2i(5, 7), Vector2i(16, 7)]))
	doc.connect_terminals("S2:14", "K2:14", _c([Vector2i(13, 12), Vector2i(16, 12)]))
	doc.connect_terminals("S2:14", "K1:21")
	doc.connect_terminals("K1:22", "K2:A1")
	doc.connect_terminals("K2:A2", "N", _c([Vector2i(13, 23)]))
	# Motor.
	doc.connect_terminals("L", "K1:33", _c([Vector2i(21, 1)]))
	doc.connect_terminals("L", "K2:33", _c([Vector2i(25, 1)]))
	doc.connect_terminals("K1:34", "M1:U1", _c([Vector2i(21, 13)]))
	doc.connect_terminals("K2:34", "M1:U1", _c([Vector2i(25, 13), Vector2i(21, 13)]))
	doc.connect_terminals("M1:U2", "N", _c([Vector2i(21, 23)]))
	return doc


## S1 feeds on-delay KT1, S2 feeds off-delay KT2; their delayed contacts
## switch H1 and H2.
static func time_relays() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[2])
	_supplies(doc, 13)
	doc.add(LatchingSwitch.new("S1", NO), Vector2i(5, 3))
	doc.add(TimerRelay.new("KT1", TimerRelay.Mode.ON_DELAY, 3.0), Vector2i(5, 8))
	doc.add(Contact.new("KT1", NO, 1, true), Vector2i(10, 3))
	doc.add(Lamp.new("H1"), Vector2i(10, 8))
	doc.add(LatchingSwitch.new("S2", NO), Vector2i(16, 3))
	doc.add(TimerRelay.new("KT2", TimerRelay.Mode.OFF_DELAY, 3.0), Vector2i(16, 8))
	doc.add(Contact.new("KT2", NO, 1, true), Vector2i(21, 3))
	doc.add(Lamp.new("H2"), Vector2i(21, 8))

	doc.connect_terminals("L", "S1:13", _c([Vector2i(5, 1)]))
	doc.connect_terminals("S1:14", "KT1:A1")
	doc.connect_terminals("KT1:A2", "N", _c([Vector2i(5, 13)]))
	doc.connect_terminals("L", "KT1:17", _c([Vector2i(10, 1)]))
	doc.connect_terminals("KT1:18", "H1:X1")
	doc.connect_terminals("H1:X2", "N", _c([Vector2i(10, 13)]))
	doc.connect_terminals("L", "S2:13", _c([Vector2i(16, 1)]))
	doc.connect_terminals("S2:14", "KT2:A1")
	doc.connect_terminals("KT2:A2", "N", _c([Vector2i(16, 13)]))
	doc.connect_terminals("L", "KT2:17", _c([Vector2i(21, 1)]))
	doc.connect_terminals("KT2:18", "H2:X1")
	doc.connect_terminals("H2:X2", "N", _c([Vector2i(21, 13)]))
	return doc


## S1 feeds K1 through its own NC contact: K1 cuts itself off.
static func self_cutoff() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[3])
	_supplies(doc, 18)
	doc.add(PushButton.new("S1", NO), Vector2i(5, 3))
	doc.add(Contact.new("K1", NC, 1), Vector2i(5, 8))
	doc.add(Coil.new("K1"), Vector2i(5, 13))

	doc.connect_terminals("L", "S1:13", _c([Vector2i(5, 1)]))
	doc.connect_terminals("S1:14", "K1:11")
	doc.connect_terminals("K1:12", "K1:A1")
	doc.connect_terminals("K1:A2", "N", _c([Vector2i(5, 18)]))
	return doc


## S1 and S2 in series directly between L and N, next to lamp H1.
static func short_circuit() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[4])
	_supplies(doc, 13)
	doc.add(PushButton.new("S1", NO), Vector2i(5, 3))
	doc.add(PushButton.new("S2", NO), Vector2i(5, 8))
	doc.add(Lamp.new("H1"), Vector2i(10, 5))

	doc.connect_terminals("L", "S1:13", _c([Vector2i(5, 1)]))
	doc.connect_terminals("S1:14", "S2:13")
	doc.connect_terminals("S2:14", "N", _c([Vector2i(5, 13)]))
	doc.connect_terminals("L", "H1:X1", _c([Vector2i(10, 1)]))
	doc.connect_terminals("H1:X2", "N", _c([Vector2i(10, 13)]))
	return doc


## Star/delta start while START is held: fuse F2 and the overload relay's
## NC 95-96 (F3) feed STOP S1. S2 starts the star contactor KM3 (through the
## delta contactor's NC KM2 11-12); KM3 13-14 brings in the main contactor
## KM1, which holds itself through KM1 13-14. Letting go of S2 drops KM3, and
## its NC 11-12 brings in the delta contactor KM2, whose NC keeps KM3 from
## starting again. S1 stops everything; an overload trips F3 after its delay.
static func star_delta() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[5])
	_supplies(doc, 35)
	doc.add(Fuse.new("F2"), Vector2i(5, 2))
	doc.add(OverloadContact.new("F3", NC), Vector2i(5, 7))
	doc.add(OverloadRelay.new("F3"), Vector2i(10, 7))
	doc.add(PushButton.new("S1", NC), Vector2i(5, 12))
	doc.add(PushButton.new("S2", NO), Vector2i(5, 19))
	doc.add(Contact.new("KM2", NC, 1), Vector2i(5, 24))
	doc.add(Coil.new("KM3"), Vector2i(5, 29))
	doc.add(Contact.new("KM3", NO, 1), Vector2i(10, 19))
	doc.add(Coil.new("KM1"), Vector2i(10, 29))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(15, 19))
	doc.add(Contact.new("KM3", NC, 1), Vector2i(15, 24))
	doc.add(Coil.new("KM2"), Vector2i(15, 29))

	doc.connect_terminals("L", "F2:1", _c([Vector2i(5, 1)]))
	doc.connect_terminals("F2:2", "F3:95")
	doc.connect_terminals("F3:96", "S1:11")
	doc.connect_terminals("S1:12", "S2:13")
	doc.connect_terminals("S1:12", "KM3:13", _c([Vector2i(5, 17), Vector2i(10, 17)]))
	doc.connect_terminals("S1:12", "KM1:13", _c([Vector2i(5, 17), Vector2i(15, 17)]))
	# Star.
	doc.connect_terminals("S2:14", "KM2:11")
	doc.connect_terminals("KM2:12", "KM3:A1")
	doc.connect_terminals("KM3:A2", "N", _c([Vector2i(5, 35)]))
	# Main contactor, fed by KM3 13-14 or its own KM1 13-14.
	doc.connect_terminals("KM3:14", "KM1:A1")
	doc.connect_terminals("KM3:14", "KM1:14", _c([Vector2i(10, 23), Vector2i(15, 23)]))
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(10, 35)]))
	# Delta, through the star contactor's NC.
	doc.connect_terminals("KM1:14", "KM3:11")
	doc.connect_terminals("KM3:12", "KM2:A1")
	doc.connect_terminals("KM2:A2", "N", _c([Vector2i(15, 35)]))
	return doc


## Forward/reverse with electrical and button interlock: each start button
## has a second, NC block (21-22) in the other direction's branch, so pressing
## the other button first drops the running contactor and then starts the
## other one, without pressing STOP.
static func forward_reverse_buttons() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[6])
	_supplies(doc, 28)
	doc.add(PushButton.new("S0", NC), Vector2i(5, 3))
	doc.add(PushButton.new("S1", NO, 1), Vector2i(5, 8))
	doc.add(PushButton.new("S2", NC, 2), Vector2i(5, 13))
	doc.add(Contact.new("K2", NC, 2), Vector2i(5, 18))
	doc.add(Coil.new("K1"), Vector2i(5, 23))
	doc.add(Contact.new("K1", NO, 1), Vector2i(8, 8))
	doc.add(PushButton.new("S2", NO, 1), Vector2i(13, 8))
	doc.add(PushButton.new("S1", NC, 2), Vector2i(13, 13))
	doc.add(Contact.new("K1", NC, 2), Vector2i(13, 18))
	doc.add(Coil.new("K2"), Vector2i(13, 23))
	doc.add(Contact.new("K2", NO, 1), Vector2i(16, 8))
	doc.add(Contact.new("K1", NO, 3), Vector2i(21, 8))
	doc.add(Contact.new("K2", NO, 3), Vector2i(25, 8))
	doc.add(Motor.new("M1"), Vector2i(21, 15))

	doc.connect_terminals("L", "S0:11", _c([Vector2i(5, 1)]))
	doc.connect_terminals("S0:12", "S1:13")
	doc.connect_terminals("S0:12", "K1:13", _c([Vector2i(5, 7), Vector2i(8, 7)]))
	doc.connect_terminals("S0:12", "S2:13", _c([Vector2i(5, 7), Vector2i(13, 7)]))
	doc.connect_terminals("S0:12", "K2:13", _c([Vector2i(5, 7), Vector2i(16, 7)]))
	# Forward: S1 (or K1 holding), then S2's NC block and K2's NC contact.
	doc.connect_terminals("S1:14", "K1:14", _c([Vector2i(5, 12), Vector2i(8, 12)]))
	doc.connect_terminals("S1:14", "S2:21")
	doc.connect_terminals("S2:22", "K2:21")
	doc.connect_terminals("K2:22", "K1:A1")
	doc.connect_terminals("K1:A2", "N", _c([Vector2i(5, 28)]))
	# Reverse: S2 (or K2 holding), then S1's NC block and K1's NC contact.
	doc.connect_terminals("S2:14", "K2:14", _c([Vector2i(13, 12), Vector2i(16, 12)]))
	doc.connect_terminals("S2:14", "S1:21")
	doc.connect_terminals("S1:22", "K1:21")
	doc.connect_terminals("K1:22", "K2:A1")
	doc.connect_terminals("K2:A2", "N", _c([Vector2i(13, 28)]))
	# Motor.
	doc.connect_terminals("L", "K1:33", _c([Vector2i(21, 1)]))
	doc.connect_terminals("L", "K2:33", _c([Vector2i(25, 1)]))
	doc.connect_terminals("K1:34", "M1:U1", _c([Vector2i(21, 13)]))
	doc.connect_terminals("K2:34", "M1:U1", _c([Vector2i(25, 13), Vector2i(21, 13)]))
	doc.connect_terminals("M1:U2", "N", _c([Vector2i(21, 28)]))
	return doc


# --- Three-phase power circuits -------------------------------------------------
# Power circuit on the left (L1, L2, L3 on top, poles two cells apart), control
# circuit on the right, fed from its own L1 supply point through fuse F3 and the
# overload relay's 95-96.

const POLES: Array[String] = ["1", "3", "5"]
const POLE_OUTS: Array[String] = ["2", "4", "6"]


static func _phases(doc: SchematicDocument, x: int) -> void:
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(x, 0))
	doc.add(PowerSupply.new("L2", PowerSupply.Conductor.L2), Vector2i(x + 2, 0))
	doc.add(PowerSupply.new("L3", PowerSupply.Conductor.L3), Vector2i(x + 4, 0))
	doc.connect_terminals("L1", "F1:1")
	doc.connect_terminals("L2", "F1:3")
	doc.connect_terminals("L3", "F1:5")


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


## Control supply: L1.2 at ([param x] - 3, 1), fuse F3 and overload contact
## F2 95-96 in column [param x]; returns the cell row below them (y = 10).
static func _control_head(doc: SchematicDocument, x: int) -> void:
	doc.add(PowerSupply.new("L1.2", PowerSupply.Conductor.L), Vector2i(x - 3, 1))
	doc.add(Fuse.new("F3"), Vector2i(x, 2))
	doc.add(OverloadContact.new("F2", NC), Vector2i(x, 7))
	doc.connect_terminals("L1.2", "F3:1", _c([Vector2i(x, 1)]))
	doc.connect_terminals("F3:2", "F2:95")


## Two contactors [param a] and [param b] started by S1 and S2, held by their
## 13-14, stopped by S0 and interlocked by each other's 21-22.
static func _two_way_control(doc: SchematicDocument, x: int, a: String, b: String, n_row: int) -> void:
	_control_head(doc, x)
	var xb: int = x + 7
	doc.add(PushButton.new("S0", NC), Vector2i(x, 12))
	doc.add(PushButton.new("S1", NO), Vector2i(x, 17))
	doc.add(Contact.new(a, NO, 1), Vector2i(x + 3, 17))
	doc.add(Contact.new(b, NC, 2), Vector2i(x, 22))
	doc.add(Coil.new(a), Vector2i(x, 27))
	doc.add(PushButton.new("S2", NO), Vector2i(xb, 17))
	doc.add(Contact.new(b, NO, 1), Vector2i(xb + 3, 17))
	doc.add(Contact.new(a, NC, 2), Vector2i(xb, 22))
	doc.add(Coil.new(b), Vector2i(xb, 27))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(x - 3, n_row))
	doc.connect_terminals("F2:96", "S0:11")
	doc.connect_terminals("S0:12", "S1:13")
	doc.connect_terminals("S0:12", a + ":13", _c([Vector2i(x, 16), Vector2i(x + 3, 16)]))
	doc.connect_terminals("S0:12", "S2:13", _c([Vector2i(x, 16), Vector2i(xb, 16)]))
	doc.connect_terminals("S0:12", b + ":13", _c([Vector2i(x, 16), Vector2i(xb + 3, 16)]))
	doc.connect_terminals("S1:14", a + ":14")
	doc.connect_terminals("S1:14", b + ":21")
	doc.connect_terminals(b + ":22", a + ":A1")
	doc.connect_terminals(a + ":A2", "N", _c([Vector2i(x, n_row)]))
	doc.connect_terminals("S2:14", b + ":14")
	doc.connect_terminals("S2:14", a + ":21")
	doc.connect_terminals(a + ":22", b + ":A1")
	doc.connect_terminals(b + ":A2", "N", _c([Vector2i(xb, n_row), Vector2i(x, n_row)]))


## Direct-on-line start: F1 - K1 - overload relay F2 - M1; S0 / S1 with K1 13-14
## holding in the control circuit.
static func direct_on_line() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[7])
	doc.add(ThreePoleFuse.new("F1"), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("K1"), Vector2i(5, 7))
	doc.add(OverloadRelay.new("F2", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(5, 12))
	doc.add(ThreePhaseMotor.new("M1"), Vector2i(5, 17))
	_straight(doc, "F1", "K1", POLES)
	_straight(doc, "K1", "F2", POLES)
	_straight(doc, "F2", "M1", ["U1", "V1", "W1"])

	var x: int = 16
	_control_head(doc, x)
	doc.add(PushButton.new("S0", NC), Vector2i(x, 12))
	doc.add(PushButton.new("S1", NO), Vector2i(x, 17))
	doc.add(Contact.new("K1", NO, 1), Vector2i(x + 3, 17))
	doc.add(Coil.new("K1"), Vector2i(x, 22))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(x - 3, 27))
	doc.connect_terminals("F2:96", "S0:11")
	doc.connect_terminals("S0:12", "S1:13")
	doc.connect_terminals("S0:12", "K1:13", _c([Vector2i(x, 16), Vector2i(x + 3, 16)]))
	doc.connect_terminals("S1:14", "K1:14")
	doc.connect_terminals("S1:14", "K1:A1")
	doc.connect_terminals("K1:A2", "N", _c([Vector2i(x, 27)]))
	return doc


## Forward/reverse: K1 feeds the motor L1-L2-L3, K2 with L1 and L3 swapped;
## the contactors are interlocked by each other's 21-22.
static func forward_reverse_3() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[8])
	doc.add(ThreePoleFuse.new("F1"), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("K1"), Vector2i(5, 10))
	doc.add(MainContacts.new("K2"), Vector2i(13, 10))
	doc.add(OverloadRelay.new("F2", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(5, 18))
	doc.add(ThreePhaseMotor.new("M1"), Vector2i(5, 24))
	_straight(doc, "F1", "K1", POLES)
	_branch(doc, "F1", "K2", 7)
	_straight(doc, "K1", "F2", POLES)
	# K2 swaps L1 and L3.
	doc.connect_terminals("K2:2", "F2:5", _c([Vector2i(13, 15), Vector2i(9, 15)]))
	doc.connect_terminals("K2:4", "F2:3", _c([Vector2i(15, 16), Vector2i(7, 16)]))
	doc.connect_terminals("K2:6", "F2:1", _c([Vector2i(17, 17), Vector2i(5, 17)]))
	_straight(doc, "F2", "M1", ["U1", "V1", "W1"])
	_two_way_control(doc, 24, "K1", "K2", 32)
	return doc


## Star/delta: KM1 feeds U1-V1-W1, KM3 joins U2-V2-W2 (star) while S2 is held,
## then KM2 feeds U2-V2-W2 from L2, L3, L1 (delta). Control as in
## [method star_delta].
static func star_delta_3() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[9])
	doc.add(ThreePoleFuse.new("F1"), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("KM1"), Vector2i(5, 10))
	doc.add(MainContacts.new("KM2"), Vector2i(13, 10))
	doc.add(OverloadRelay.new("F2", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(5, 15))
	doc.add(ThreePhaseMotor.new("M1", ThreePhaseMotor.Kind.STAR_DELTA), Vector2i(5, 21))
	doc.add(MainContacts.new("KM3"), Vector2i(5, 32))
	_straight(doc, "F1", "KM1", POLES)
	_branch(doc, "F1", "KM2", 7)
	_straight(doc, "KM1", "F2", POLES)
	_straight(doc, "F2", "M1", ["U1", "V1", "W1"])
	# Delta: U1-W2, V1-U2, W1-V2.
	_from_below(doc, "KM2", ["W2", "U2", "V2"], 28)
	doc.connect_terminals("M1:U2", "KM3:1")
	doc.connect_terminals("M1:V2", "KM3:3")
	doc.connect_terminals("M1:W2", "KM3:5")
	_star_bridge(doc, "KM3")

	var x: int = 25
	_control_head(doc, x)
	doc.add(PushButton.new("S1", NC), Vector2i(x, 12))
	doc.add(PushButton.new("S2", NO), Vector2i(x, 19))
	doc.add(Contact.new("KM2", NC, 1), Vector2i(x, 24))
	doc.add(Coil.new("KM3"), Vector2i(x, 29))
	doc.add(Contact.new("KM3", NO, 1), Vector2i(x + 5, 19))
	doc.add(Coil.new("KM1"), Vector2i(x + 5, 29))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(x + 10, 19))
	doc.add(Contact.new("KM3", NC, 1), Vector2i(x + 10, 24))
	doc.add(Coil.new("KM2"), Vector2i(x + 10, 29))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(x - 3, 35))
	doc.connect_terminals("F2:96", "S1:11")
	doc.connect_terminals("S1:12", "S2:13")
	doc.connect_terminals("S1:12", "KM3:13", _c([Vector2i(x, 17), Vector2i(x + 5, 17)]))
	doc.connect_terminals("S1:12", "KM1:13", _c([Vector2i(x, 17), Vector2i(x + 10, 17)]))
	doc.connect_terminals("S2:14", "KM2:11")
	doc.connect_terminals("KM2:12", "KM3:A1")
	doc.connect_terminals("KM3:A2", "N", _c([Vector2i(x, 35)]))
	doc.connect_terminals("KM3:14", "KM1:A1")
	doc.connect_terminals("KM3:14", "KM1:14", _c([Vector2i(x + 5, 23), Vector2i(x + 10, 23)]))
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(x + 5, 35)]))
	doc.connect_terminals("KM1:14", "KM3:11")
	doc.connect_terminals("KM3:12", "KM2:A1")
	doc.connect_terminals("KM2:A2", "N", _c([Vector2i(x + 10, 35)]))
	return doc


## Power part shared by the two-speed motors: F1 - F2 - K1 (low speed, to
## 1U-1V-1W from above) and K2 (high speed, to 2U-2V-2W from below).
static func _two_speed_power(doc: SchematicDocument, kind: ThreePhaseMotor.Kind) -> void:
	doc.add(ThreePoleFuse.new("F1"), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(OverloadRelay.new("F2", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(5, 7))
	doc.add(MainContacts.new("K1"), Vector2i(5, 16))
	doc.add(MainContacts.new("K2"), Vector2i(13, 16))
	doc.add(ThreePhaseMotor.new("M1", kind), Vector2i(5, 24))
	_straight(doc, "F1", "F2", POLES)
	_straight(doc, "F2", "K1", POLES)
	_branch(doc, "F2", "K2", 12)
	_straight(doc, "K1", "M1", ["1U", "1V", "1W"])
	_from_below(doc, "K2", ["2U", "2V", "2W"], 31)


## Dahlander: low speed K1 feeds 1U-1V-1W (delta); high speed K3 joins
## 1U-1V-1W (star point) and K2 feeds 2U-2V-2W (double star). S1 starts low
## speed; S2 starts K3, whose 13-14 then switches K2 on. K3 21-22 keeps K1 off
## while the star point is closed, K1 21-22 keeps K3 off.
static func dahlander() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[10])
	_two_speed_power(doc, ThreePhaseMotor.Kind.DAHLANDER)
	doc.add(MainContacts.new("K3"), Vector2i(21, 25))
	for i: int in 3:
		var a: String = "K1:" + POLE_OUTS[i]
		var x: int = doc.terminal_cell(a).x
		doc.connect_terminals(a, "K3:" + POLES[i], _c([Vector2i(x, 21 + i), Vector2i(21 + 2 * i, 21 + i)]))
	_star_bridge(doc, "K3")

	var x: int = 32
	var xb: int = x + 7
	_control_head(doc, x)
	doc.add(PushButton.new("S0", NC), Vector2i(x, 12))
	doc.add(PushButton.new("S1", NO), Vector2i(x, 17))
	doc.add(Contact.new("K1", NO, 1), Vector2i(x + 3, 17))
	doc.add(Contact.new("K3", NC, 2), Vector2i(x, 22))
	doc.add(Coil.new("K1"), Vector2i(x, 27))
	doc.add(PushButton.new("S2", NO), Vector2i(xb, 17))
	doc.add(Contact.new("K2", NO, 1), Vector2i(xb + 3, 17))
	doc.add(Contact.new("K1", NC, 2), Vector2i(xb, 22))
	doc.add(Coil.new("K3"), Vector2i(xb, 27))
	doc.add(Contact.new("K3", NO, 1), Vector2i(xb + 7, 22))
	doc.add(Coil.new("K2"), Vector2i(xb + 7, 27))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(x - 3, 33))
	doc.connect_terminals("F2:96", "S0:11")
	doc.connect_terminals("S0:12", "S1:13")
	doc.connect_terminals("S0:12", "K1:13", _c([Vector2i(x, 16), Vector2i(x + 3, 16)]))
	doc.connect_terminals("S0:12", "S2:13", _c([Vector2i(x, 16), Vector2i(xb, 16)]))
	doc.connect_terminals("S0:12", "K2:13", _c([Vector2i(x, 16), Vector2i(xb + 3, 16)]))
	doc.connect_terminals("S1:14", "K1:14")
	doc.connect_terminals("S1:14", "K3:21")
	doc.connect_terminals("K3:22", "K1:A1")
	doc.connect_terminals("K1:A2", "N", _c([Vector2i(x, 33)]))
	doc.connect_terminals("S2:14", "K2:14")
	doc.connect_terminals("S2:14", "K1:21")
	doc.connect_terminals("K1:22", "K3:A1")
	doc.connect_terminals("K3:A2", "N", _c([Vector2i(xb, 33), Vector2i(x, 33)]))
	doc.connect_terminals("K2:14", "K3:13", _c([Vector2i(xb + 3, 21), Vector2i(xb + 7, 21)]))
	doc.connect_terminals("K3:14", "K2:A1")
	doc.connect_terminals("K2:A2", "N", _c([Vector2i(xb + 7, 33), Vector2i(x, 33)]))
	return doc


## Two separate windings: K1 feeds the low-speed winding 1U-1V-1W, K2 the
## high-speed winding 2U-2V-2W; interlocked as forward/reverse.
static func two_windings() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[11])
	_two_speed_power(doc, ThreePhaseMotor.Kind.TWO_WINDINGS)
	_two_way_control(doc, 24, "K1", "K2", 33)
	return doc
