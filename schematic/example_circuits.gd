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
	if doc != null and doc.control_boxes.is_empty():
		doc.add_control_box_for_all()
	if doc != null and doc.cabinet_rails.is_empty():
		doc.fill_cabinet()
	if doc != null and horizontal:
		doc.transpose()
	return doc


static func _supplies(doc: SchematicDocument, n_row: int) -> void:
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(2, 1))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(2, n_row))


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


## Control fuse FU1 below the L supply; every current path starts at FU1:2.
static func _control_fuse(doc: SchematicDocument, n_row: int) -> void:
	_supplies(doc, n_row)
	doc.add(Fuse.new("FU1"), Vector2i(5, 2))
	doc.connect_terminals("L", "FU1:1", _c([Vector2i(5, 1)]))


## L - FU1 - SB0 - SB1 (KM1 13-14 in parallel) - KM1; KM1 23-24 switches H1.
static func self_holding() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[0])
	_control_fuse(doc, 22)
	doc.add(PushButton.new("SB0", NC), Vector2i(5, 7))
	doc.add(PushButton.new("SB1", NO), Vector2i(5, 12))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(8, 12))
	doc.add(Coil.new("KM1"), Vector2i(5, 17))
	doc.add(Contact.new("KM1", NO, 2), Vector2i(12, 12))
	doc.add(_lamp("H1", "Running"), Vector2i(12, 17))

	doc.connect_terminals("FU1:2", "SB0:11")
	doc.connect_terminals("SB0:12", "SB1:13")
	doc.connect_terminals("SB0:12", "KM1:13", _c([Vector2i(5, 11), Vector2i(8, 11)]))
	doc.connect_terminals("SB1:14", "KM1:14", _c([Vector2i(5, 16), Vector2i(8, 16)]))
	doc.connect_terminals("SB1:14", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(5, 22)]))
	doc.connect_terminals("FU1:2", "KM1:23", _c([Vector2i(5, 6), Vector2i(12, 6)]))
	doc.connect_terminals("KM1:24", "H1:X1")
	doc.connect_terminals("H1:X2", "N", _c([Vector2i(12, 22)]))
	return doc


## Two self-holding branches, each fed through an NC contact of the other
## contactor (electrical interlock); KM1 33-34 lights H1 (forward), KM2 33-34
## lights H2 (reverse). The motor itself is in the three-phase examples.
static func forward_reverse() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[1])
	_control_fuse(doc, 27)
	doc.add(PushButton.new("SB0", NC), Vector2i(5, 7))
	doc.add(PushButton.new("SB1", NO), Vector2i(5, 12))
	doc.add(PushButton.new("SB2", NO), Vector2i(13, 12))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(8, 12))
	doc.add(Contact.new("KM1", NC, 2), Vector2i(13, 17))
	doc.add(Contact.new("KM1", NO, 3), Vector2i(21, 12))
	doc.add(Contact.new("KM2", NO, 1), Vector2i(16, 12))
	doc.add(Contact.new("KM2", NC, 2), Vector2i(5, 17))
	doc.add(Contact.new("KM2", NO, 3), Vector2i(28, 12))
	doc.add(Coil.new("KM1"), Vector2i(5, 22))
	doc.add(Coil.new("KM2"), Vector2i(13, 22))
	doc.add(_lamp("H1", "Forward"), Vector2i(21, 17))
	doc.add(_lamp("H2", "Reverse"), Vector2i(28, 17))

	doc.connect_terminals("FU1:2", "SB0:11")
	# Forward.
	doc.connect_terminals("SB0:12", "SB1:13")
	doc.connect_terminals("SB0:12", "KM1:13", _c([Vector2i(5, 11), Vector2i(8, 11)]))
	doc.connect_terminals("SB1:14", "KM1:14", _c([Vector2i(5, 16), Vector2i(8, 16)]))
	doc.connect_terminals("SB1:14", "KM2:21")
	doc.connect_terminals("KM2:22", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(5, 27)]))
	# Reverse.
	doc.connect_terminals("SB0:12", "SB2:13", _c([Vector2i(5, 11), Vector2i(13, 11)]))
	doc.connect_terminals("SB0:12", "KM2:13", _c([Vector2i(5, 11), Vector2i(16, 11)]))
	doc.connect_terminals("SB2:14", "KM2:14", _c([Vector2i(13, 16), Vector2i(16, 16)]))
	doc.connect_terminals("SB2:14", "KM1:21")
	doc.connect_terminals("KM1:22", "KM2:A1")
	doc.connect_terminals("KM2:A2", "N", _c([Vector2i(13, 27)]))
	# Signal lamps.
	doc.connect_terminals("FU1:2", "KM1:33", _c([Vector2i(5, 6), Vector2i(21, 6)]))
	doc.connect_terminals("FU1:2", "KM2:33", _c([Vector2i(5, 6), Vector2i(28, 6)]))
	doc.connect_terminals("KM1:34", "H1:X1")
	doc.connect_terminals("H1:X2", "N", _c([Vector2i(21, 27)]))
	doc.connect_terminals("KM2:34", "H2:X1")
	doc.connect_terminals("H2:X2", "N", _c([Vector2i(28, 27)]))
	# Control box: illuminated start buttons (their lamps inside), stop below.
	var box: ControlBox = doc.add_control_box()
	box.items = [_panel_button("SB1", "green", "Forward", "H1"), _panel_button("SB2", "white", "Reverse", "H2"), _panel_button("SB0", "red", "Stop")]
	return doc


## RB1 feeds on-delay KT1, RB2 feeds off-delay KT2; their delayed contacts
## (17-18, delayed NO) switch H1 and H2.
static func time_relays() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[2])
	_control_fuse(doc, 17)
	doc.add(LatchingSwitch.new("RB1", NO), Vector2i(5, 7))
	doc.add(TimerRelay.new("KT1", TimerRelay.Mode.ON_DELAY, 3.0), Vector2i(5, 12))
	doc.add(Contact.new("KT1", NO, 1, true), Vector2i(11, 7))
	doc.add(_lamp("H1", "On-delay"), Vector2i(11, 12))
	doc.add(LatchingSwitch.new("RB2", NO), Vector2i(17, 7))
	doc.add(TimerRelay.new("KT2", TimerRelay.Mode.OFF_DELAY, 3.0), Vector2i(17, 12))
	doc.add(Contact.new("KT2", NO, 1, true), Vector2i(23, 7))
	doc.add(_lamp("H2", "Off-delay"), Vector2i(23, 12))

	doc.connect_terminals("FU1:2", "RB1:13")
	doc.connect_terminals("RB1:14", "KT1:A1")
	doc.connect_terminals("KT1:A2", "N", _c([Vector2i(5, 17)]))
	doc.connect_terminals("FU1:2", "KT1:17", _c([Vector2i(5, 6), Vector2i(11, 6)]))
	doc.connect_terminals("KT1:18", "H1:X1")
	doc.connect_terminals("H1:X2", "N", _c([Vector2i(11, 17)]))
	doc.connect_terminals("FU1:2", "RB2:13", _c([Vector2i(5, 6), Vector2i(17, 6)]))
	doc.connect_terminals("RB2:14", "KT2:A1")
	doc.connect_terminals("KT2:A2", "N", _c([Vector2i(17, 17)]))
	doc.connect_terminals("FU1:2", "KT2:17", _c([Vector2i(5, 6), Vector2i(23, 6)]))
	doc.connect_terminals("KT2:18", "H2:X1")
	doc.connect_terminals("H2:X2", "N", _c([Vector2i(23, 17)]))
	return doc


## SB1 feeds KM1 through its own NC contact: KM1 cuts itself off.
static func self_cutoff() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[3])
	_control_fuse(doc, 22)
	doc.add(PushButton.new("SB1", NO), Vector2i(5, 7))
	doc.add(Contact.new("KM1", NC, 1), Vector2i(5, 12))
	doc.add(Coil.new("KM1"), Vector2i(5, 17))

	doc.connect_terminals("FU1:2", "SB1:13")
	doc.connect_terminals("SB1:14", "KM1:11")
	doc.connect_terminals("KM1:12", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(5, 22)]))
	return doc


## SB1 and SB2 in series directly between L and N, next to lamp H1.
static func short_circuit() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[4])
	_supplies(doc, 13)
	doc.add(PushButton.new("SB1", NO), Vector2i(5, 3))
	doc.add(PushButton.new("SB2", NO), Vector2i(5, 8))
	doc.add(Lamp.new("H1"), Vector2i(10, 5))

	doc.connect_terminals("L", "SB1:13", _c([Vector2i(5, 1)]))
	doc.connect_terminals("SB1:14", "SB2:13")
	doc.connect_terminals("SB2:14", "N", _c([Vector2i(5, 13)]))
	doc.connect_terminals("L", "H1:X1", _c([Vector2i(10, 1)]))
	doc.connect_terminals("H1:X2", "N", _c([Vector2i(10, 13)]))
	return doc


## Star/delta start while START is held: fuse FU1 and the overload relay's
## NC 95-96 (F1) feed STOP SB1. SB2 starts the star contactor KM3 (through the
## delta contactor's NC KM2 11-12); KM3 13-14 brings in the main contactor
## KM1, which holds itself through KM1 13-14. Letting go of SB2 drops KM3, and
## its NC 11-12 brings in the delta contactor KM2, whose NC keeps KM3 from
## starting again. SB1 stops everything; an overload trips F1 after its delay.
static func star_delta() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[5])
	_supplies(doc, 35)
	doc.add(Fuse.new("FU1"), Vector2i(5, 2))
	doc.add(OverloadContact.new("F1", NC), Vector2i(5, 7))
	doc.add(OverloadRelay.new("F1"), Vector2i(10, 7))
	doc.add(PushButton.new("SB1", NC), Vector2i(5, 12))
	doc.add(PushButton.new("SB2", NO), Vector2i(5, 19))
	doc.add(Contact.new("KM2", NC, 1), Vector2i(5, 24))
	doc.add(Coil.new("KM3"), Vector2i(5, 29))
	doc.add(Contact.new("KM3", NO, 1), Vector2i(10, 19))
	doc.add(Coil.new("KM1"), Vector2i(10, 29))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(15, 19))
	doc.add(Contact.new("KM3", NC, 1), Vector2i(15, 24))
	doc.add(Coil.new("KM2"), Vector2i(15, 29))

	doc.connect_terminals("L", "FU1:1", _c([Vector2i(5, 1)]))
	doc.connect_terminals("FU1:2", "F1:95")
	doc.connect_terminals("F1:96", "SB1:11")
	doc.connect_terminals("SB1:12", "SB2:13")
	doc.connect_terminals("SB1:12", "KM3:13", _c([Vector2i(5, 17), Vector2i(10, 17)]))
	doc.connect_terminals("SB1:12", "KM1:13", _c([Vector2i(5, 17), Vector2i(15, 17)]))
	# Star.
	doc.connect_terminals("SB2:14", "KM2:11")
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
	_control_fuse(doc, 32)
	doc.add(PushButton.new("SB0", NC), Vector2i(5, 7))
	doc.add(PushButton.new("SB1", NO, 1), Vector2i(5, 12))
	doc.add(PushButton.new("SB2", NC, 2), Vector2i(5, 17))
	doc.add(Contact.new("KM2", NC, 2), Vector2i(5, 22))
	doc.add(Coil.new("KM1"), Vector2i(5, 27))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(8, 12))
	doc.add(PushButton.new("SB2", NO, 1), Vector2i(13, 12))
	doc.add(PushButton.new("SB1", NC, 2), Vector2i(13, 17))
	doc.add(Contact.new("KM1", NC, 2), Vector2i(13, 22))
	doc.add(Coil.new("KM2"), Vector2i(13, 27))
	doc.add(Contact.new("KM2", NO, 1), Vector2i(16, 12))
	doc.add(Contact.new("KM1", NO, 3), Vector2i(21, 12))
	doc.add(Contact.new("KM2", NO, 3), Vector2i(28, 12))
	doc.add(_lamp("H1", "Forward"), Vector2i(21, 17))
	doc.add(_lamp("H2", "Reverse"), Vector2i(28, 17))

	doc.connect_terminals("FU1:2", "SB0:11")
	doc.connect_terminals("SB0:12", "SB1:13")
	doc.connect_terminals("SB0:12", "KM1:13", _c([Vector2i(5, 11), Vector2i(8, 11)]))
	doc.connect_terminals("SB0:12", "SB2:13", _c([Vector2i(5, 11), Vector2i(13, 11)]))
	doc.connect_terminals("SB0:12", "KM2:13", _c([Vector2i(5, 11), Vector2i(16, 11)]))
	# Forward: SB1 (or KM1 holding), then SB2's NC block and KM2's NC contact.
	doc.connect_terminals("SB1:14", "KM1:14", _c([Vector2i(5, 16), Vector2i(8, 16)]))
	doc.connect_terminals("SB1:14", "SB2:21")
	doc.connect_terminals("SB2:22", "KM2:21")
	doc.connect_terminals("KM2:22", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(5, 32)]))
	# Reverse: SB2 (or KM2 holding), then SB1's NC block and KM1's NC contact.
	doc.connect_terminals("SB2:14", "KM2:14", _c([Vector2i(13, 16), Vector2i(16, 16)]))
	doc.connect_terminals("SB2:14", "SB1:21")
	doc.connect_terminals("SB1:22", "KM1:21")
	doc.connect_terminals("KM1:22", "KM2:A1")
	doc.connect_terminals("KM2:A2", "N", _c([Vector2i(13, 32)]))
	# Signal lamps.
	doc.connect_terminals("FU1:2", "KM1:33", _c([Vector2i(5, 6), Vector2i(21, 6)]))
	doc.connect_terminals("FU1:2", "KM2:33", _c([Vector2i(5, 6), Vector2i(28, 6)]))
	doc.connect_terminals("KM1:34", "H1:X1")
	doc.connect_terminals("H1:X2", "N", _c([Vector2i(21, 32)]))
	doc.connect_terminals("KM2:34", "H2:X1")
	doc.connect_terminals("H2:X2", "N", _c([Vector2i(28, 32)]))
	return doc


# --- Three-phase power circuits -------------------------------------------------
# Power circuit on the left (L1, L2, L3 on top, poles two cells apart), control
# circuit on the right, fed from its own L1 supply point through fuse FU2 and the
# overload relay's 95-96.

const POLES: Array[String] = ["1", "3", "5"]
const POLE_OUTS: Array[String] = ["2", "4", "6"]


static func _phases(doc: SchematicDocument, x: int) -> void:
	doc.add(PowerSupply.new("L1", PowerSupply.Conductor.L), Vector2i(x, 0))
	doc.add(PowerSupply.new("L2", PowerSupply.Conductor.L2), Vector2i(x + 2, 0))
	doc.add(PowerSupply.new("L3", PowerSupply.Conductor.L3), Vector2i(x + 4, 0))
	doc.connect_terminals("L1", "FU1:1")
	doc.connect_terminals("L2", "FU1:3")
	doc.connect_terminals("L3", "FU1:5")


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


## Control supply: L1.2 at ([param x] - 3, 1), control fuse [param fuse] and
## the 95-96 of each overload relay in [param overloads], one under the other
## in column [param x] from row 2. Returns the key of the last 96; the next
## part goes at row 7 + 5 * overloads.size().
static func _control_head(doc: SchematicDocument, x: int, fuse: String, overloads: Array, holder: bool = false) -> String:
	doc.add(PowerSupply.new("L1.2", PowerSupply.Conductor.L), Vector2i(x - 3, 1))
	var control_fuse: Fuse = Fuse.new(fuse)
	control_fuse.holder = holder
	doc.add(control_fuse, Vector2i(x, 2))
	doc.connect_terminals("L1.2", fuse + ":1", _c([Vector2i(x, 1)]))
	var last: String = fuse + ":2"
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


## Direct-on-line start: FU1 - KM1 - overload relay F1 - M1; SB0 / SB1 with KM1 13-14
## holding in the control circuit. Signal lamps as on page 40 of the guide:
## H1 control voltage on, H2 overload tripped (F1 97-98), H3 running (KM1 23-24,
## a contact of the contactor itself, so a broken coil shows as not running).
static func direct_on_line() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[7])
	doc.add(ThreePoleFuse.new("FU1"), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("KM1"), Vector2i(5, 7))
	doc.add(OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(5, 12))
	doc.add(ThreePhaseMotor.new("M1"), Vector2i(5, 17))
	_straight(doc, "FU1", "KM1", POLES)
	_straight(doc, "KM1", "F1", POLES)
	_straight(doc, "F1", "M1", ["U1", "V1", "W1"])

	var x: int = 16
	var feed: String = _control_head(doc, x, "FU2", ["F1"])
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
	# Signal lamps, fed after the control fuse.
	doc.add(_lamp("H1", "Voltage on"), Vector2i(24, 22))
	doc.add(OverloadContact.new("F1", NO), Vector2i(31, 7))
	doc.add(_lamp("H2", "Fault"), Vector2i(31, 22))
	doc.add(Contact.new("KM1", NO, 2), Vector2i(38, 17))
	doc.add(_lamp("H3", "Running"), Vector2i(38, 22))
	doc.connect_terminals("FU2:2", "H1:X1", _c([Vector2i(x, 6), Vector2i(24, 6)]))
	doc.connect_terminals("FU2:2", "F1:97", _c([Vector2i(x, 6), Vector2i(31, 6)]))
	doc.connect_terminals("F1:98", "H2:X1")
	doc.connect_terminals("FU2:2", "KM1:23", _c([Vector2i(x, 6), Vector2i(38, 6)]))
	doc.connect_terminals("KM1:24", "H3:X1")
	for lamp: Array in [["H1", 24], ["H2", 31], ["H3", 38]]:
		doc.connect_terminals(lamp[0] + ":X2", "N", _c([Vector2i(lamp[1], 27)]))
	return doc


## Forward/reverse: KM1 feeds the motor L1-L2-L3, KM2 with L1 and L3 swapped;
## the contactors are interlocked by each other's 21-22.
static func forward_reverse_3() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[8])
	doc.add(ThreePoleFuse.new("FU1"), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("KM1"), Vector2i(5, 10))
	doc.add(MainContacts.new("KM2"), Vector2i(13, 10))
	doc.add(OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(5, 18))
	doc.add(ThreePhaseMotor.new("M1"), Vector2i(5, 24))
	_straight(doc, "FU1", "KM1", POLES)
	_branch(doc, "FU1", "KM2", 7)
	_straight(doc, "KM1", "F1", POLES)
	# KM2 swaps L1 and L3.
	doc.connect_terminals("KM2:2", "F1:5", _c([Vector2i(13, 15), Vector2i(9, 15)]))
	doc.connect_terminals("KM2:4", "F1:3", _c([Vector2i(15, 16), Vector2i(7, 16)]))
	doc.connect_terminals("KM2:6", "F1:1", _c([Vector2i(17, 17), Vector2i(5, 17)]))
	_straight(doc, "F1", "M1", ["U1", "V1", "W1"])
	var feed: String = _control_head(doc, 24, "FU2", ["F1"])
	_two_way_control(doc, 24, 12, feed, "KM1", "KM2", 32, "SB0", "SB1", "SB2", false)
	return doc


## Star/delta: KM1 feeds U1-V1-W1, KM3 joins U2-V2-W2 (star) while SB2 is held,
## then KM2 feeds U2-V2-W2 from L2, L3, L1 (delta). Control as in
## [method star_delta].
static func star_delta_3() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[9])
	doc.add(ThreePoleFuse.new("FU1"), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("KM1"), Vector2i(5, 10))
	doc.add(MainContacts.new("KM2"), Vector2i(13, 10))
	# F1 carries the winding current: set to In / √3.
	var relay: OverloadRelay = OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3)
	relay.setting = 4.6
	doc.add(relay, Vector2i(5, 15))
	doc.add(ThreePhaseMotor.new("M1", ThreePhaseMotor.Kind.STAR_DELTA), Vector2i(5, 21))
	doc.add(MainContacts.new("KM3"), Vector2i(5, 32))
	_straight(doc, "FU1", "KM1", POLES)
	_branch(doc, "FU1", "KM2", 7)
	_straight(doc, "KM1", "F1", POLES)
	_straight(doc, "F1", "M1", ["U1", "V1", "W1"])
	# Delta: U1-W2, V1-U2, W1-V2.
	_from_below(doc, "KM2", ["W2", "U2", "V2"], 28)
	doc.connect_terminals("M1:W2", "KM3:1")
	doc.connect_terminals("M1:U2", "KM3:3")
	doc.connect_terminals("M1:V2", "KM3:5")
	_star_bridge(doc, "KM3")

	var x: int = 25
	var feed: String = _control_head(doc, x, "FU2", ["F1"])
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
	return doc


## Power part shared by the two-speed motors, as on page 47 of the guide:
## FU1, then KM1 - overload relay F1 - 1U-1V-1W (low speed, from above) and
## KM2 - overload relay F2 - 2U-2V-2W (high speed, from below). Each speed has
## its own overload relay, set to the current of that speed.
static func _two_speed_power(doc: SchematicDocument, kind: ThreePhaseMotor.Kind) -> void:
	# Fuse holders (fuse disconnectors) FU1 and FU2, as on page 47.
	var f1: ThreePoleFuse = ThreePoleFuse.new("FU1")
	f1.holder = true
	doc.add(f1, Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("KM1"), Vector2i(5, 11))
	doc.add(MainContacts.new("KM2"), Vector2i(13, 11))
	var low: OverloadRelay = OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3)
	low.setting = 4.5
	doc.add(low, Vector2i(5, 16))
	doc.add(OverloadRelay.new("F2", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(13, 16))
	doc.add(ThreePhaseMotor.new("M1", kind), Vector2i(5, 23))
	_straight(doc, "FU1", "KM1", POLES)
	_branch(doc, "FU1", "KM2", 7)
	_straight(doc, "KM1", "F1", POLES)
	_straight(doc, "KM2", "F2", POLES)
	_straight(doc, "F1", "M1", ["1U", "1V", "1W"])
	_from_below(doc, "F2", ["2U", "2V", "2W"], 30)


## Dahlander: low speed KM1 feeds 1U-1V-1W (delta); high speed KM3 joins
## 1U-1V-1W (star point) and KM2 feeds 2U-2V-2W (double star). SB1 starts low
## speed; SB2 starts KM3, whose 13-14 then switches KM2 on, so the motor never
## gets high speed without its star point. KM3 21-22 keeps KM1 off while the
## star point is closed, KM1 21-22 keeps KM3 off. Control fuse FU2, then the
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
	var feed: String = _control_head(doc, x, "FU2", ["F1", "F2"], true)
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
	var feed: String = _control_head(doc, 24, "FU2", ["F1", "F2"], true)
	_two_way_control(doc, 24, 17, feed, "KM1", "KM2", 42, "SB1", "SB2", "SB3", true)
	return doc


## DC braking: KM1 runs the motor (direct-on-line start). Bridge rectifier
## TB1, fed from L2 and L3 behind FU1, makes the DC. SB0 stops the motor with
## its 11-12 and starts braking with its 23-24: as soon as KM1 has released
## (its 31-32), KM2 feeds + and - of TB1 into U1 and V1, held by its 13-14,
## until time relay KT1 opens its delayed 55-56. KM1 and KM2 are interlocked
## by each other's NC contacts. Braking starts right after the AC is cut,
## while the rotor field is still there; without it the motor would run down
## in its run-down time.
static func dc_braking() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[12])
	doc.add(ThreePoleFuse.new("FU1"), Vector2i(5, 2))
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
	_straight(doc, "FU1", "KM1", POLES)
	_straight(doc, "KM1", "F1", POLES)
	_straight(doc, "F1", "M1", ["U1", "V1", "W1"])
	# TB1 between L2 and L3.
	doc.connect_terminals("FU1:6", "TB1:~2", _c([Vector2i(9, 7), Vector2i(15, 7)]))
	doc.connect_terminals("FU1:4", "TB1:~1", _c([Vector2i(7, 8), Vector2i(13, 8)]))
	doc.connect_terminals("TB1:+", "KM2:1")
	doc.connect_terminals("TB1:-", "KM2:3")
	# DC into U1 and V1 (through the heaters of F1).
	doc.connect_terminals("KM2:2", "F1:1", _c([Vector2i(13, 18), Vector2i(5, 18)]))
	doc.connect_terminals("KM2:4", "F1:3", _c([Vector2i(15, 19), Vector2i(7, 19)]))

	var x: int = 24
	var xb: int = x + 8
	var n_row: int = 32
	var feed: String = _control_head(doc, x, "FU2", ["F1"])
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
## power page) and the signalling. The control voltage after FU2 and F1 95-96
## continues to the signalling page through page connectors; the wires are
## numbered, so the connectors carry the wire number of their link.
static func direct_on_line_pages() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[12])
	doc.pages = PackedStringArray(["Power section", "Control section", "Signalling section"])
	doc.add(ThreePoleFuse.new("FU1"), Vector2i(5, 2))
	_phases(doc, 5)
	doc.add(MainContacts.new("KM1"), Vector2i(5, 7))
	doc.add(OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(5, 12))
	doc.add(ThreePhaseMotor.new("M1"), Vector2i(5, 17))
	_straight(doc, "FU1", "KM1", POLES)
	_straight(doc, "KM1", "F1", POLES)
	_straight(doc, "F1", "M1", ["U1", "V1", "W1"])

	doc.page = 1
	var x: int = 8
	var feed: String = _control_head(doc, x, "FU2", ["F1"])
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
	# The signalling page is fed after the control fuse: arrow to the right.
	doc.add(PageConnector.new("PC1", "1"), Vector2i(16, 6), 1)
	doc.connect_terminals("FU2:2", "PC1", _c([Vector2i(x, 6)]))

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


## PLC A1 fed through FU1: start button SB1 (NO) on I1, stop button SB0 (NC)
## on I2; output Q1 lights H1, Q2 lights H2 five seconds later. The program
## (function block diagram): Q1 = (I1 OR Q1) AND I2, Q2 = on-delay of Q1; the
## same in the ladder diagram, switched to in the PLC window.
static func plc_start_stop() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[14])
	_control_fuse(doc, 25)
	doc.add(PushButton.new("SB1", NO), Vector2i(12, 7))
	doc.add(PushButton.new("SB0", NC), Vector2i(17, 7))
	doc.add(Plc.new("A1", plc_start_stop_program()), Vector2i(8, 12))
	doc.add(_lamp("H1", "Running"), Vector2i(10, 20))
	doc.add(_lamp("H2", "Delayed"), Vector2i(15, 20))

	doc.connect_terminals("FU1:2", "A1:L1", _c([Vector2i(5, 6), Vector2i(8, 6)]))
	doc.connect_terminals("A1:N", "N", _c([Vector2i(10, 10), Vector2i(3, 10), Vector2i(3, 25)]))
	doc.connect_terminals("FU1:2", "SB1:13", _c([Vector2i(5, 6), Vector2i(12, 6)]))
	doc.connect_terminals("FU1:2", "SB0:11", _c([Vector2i(5, 6), Vector2i(17, 6)]))
	doc.connect_terminals("SB1:14", "A1:I1")
	doc.connect_terminals("SB0:12", "A1:I2", _c([Vector2i(17, 11), Vector2i(14, 11)]))
	doc.connect_terminals("FU1:2", "A1:Q1.1", _c([Vector2i(5, 19), Vector2i(8, 19)]))
	doc.connect_terminals("A1:Q1.1", "A1:Q2.1", _c([Vector2i(8, 19), Vector2i(13, 19)]))
	doc.connect_terminals("A1:Q1.2", "H1:X1")
	doc.connect_terminals("A1:Q2.2", "H2:X1")
	doc.connect_terminals("H1:X2", "N", _c([Vector2i(10, 25)]))
	doc.connect_terminals("H2:X2", "N", _c([Vector2i(15, 25)]))
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
	var hold: PlcRung = PlcRung.new()
	hold.set_cell(0, 0, {"kind": "no", "operand": "I1"})
	hold.set_cell(0, 1, {"kind": "no", "operand": "I2"})
	hold.set_coil(0, {"kind": "coil", "operand": "Q1"})
	hold.wire_to_coil(0)
	hold.set_cell(1, 0, {"kind": "no", "operand": "Q1"})
	hold.set_link(0, 0, true)
	var timer: PlcRung = PlcRung.new()
	timer.set_cell(0, 0, {"kind": "no", "operand": "Q1"})
	timer.set_coil(0, {"kind": "on_delay", "operand": "T1", "time": 5.0})
	timer.wire_to_coil(0)
	var output: PlcRung = PlcRung.new()
	output.set_cell(0, 0, {"kind": "no", "operand": "T1"})
	output.set_coil(0, {"kind": "coil", "operand": "Q2"})
	output.wire_to_coil(0)
	p.rungs.append_array([hold, timer, output])
	return p
