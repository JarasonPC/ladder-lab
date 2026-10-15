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


## Star/delta start while START is held: S2 starts the star contactor KM3
## (through the delta contactor's NC KM2 11-12); KM3 13-14 brings in the main
## contactor KM1, which holds itself through KM1 13-14. Letting go of S2 drops
## KM3, and its NC 11-12 brings in the delta contactor KM2, whose NC keeps
## KM3 from starting again. S1 stops everything.
## (Fuse and overload contact of the supply are not modelled yet.)
static func star_delta() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new(TITLES[5])
	_supplies(doc, 26)
	doc.add(PushButton.new("S1", NC), Vector2i(5, 3))
	doc.add(PushButton.new("S2", NO), Vector2i(5, 10))
	doc.add(Contact.new("KM2", NC, 1), Vector2i(5, 15))
	doc.add(Coil.new("KM3"), Vector2i(5, 20))
	doc.add(Contact.new("KM3", NO, 1), Vector2i(10, 10))
	doc.add(Coil.new("KM1"), Vector2i(10, 20))
	doc.add(Contact.new("KM1", NO, 1), Vector2i(15, 10))
	doc.add(Contact.new("KM3", NC, 1), Vector2i(15, 15))
	doc.add(Coil.new("KM2"), Vector2i(15, 20))

	doc.connect_terminals("L", "S1:11", _c([Vector2i(5, 1)]))
	doc.connect_terminals("S1:12", "S2:13")
	doc.connect_terminals("S1:12", "KM3:13", _c([Vector2i(5, 8), Vector2i(10, 8)]))
	doc.connect_terminals("S1:12", "KM1:13", _c([Vector2i(5, 8), Vector2i(15, 8)]))
	# Star.
	doc.connect_terminals("S2:14", "KM2:11")
	doc.connect_terminals("KM2:12", "KM3:A1")
	doc.connect_terminals("KM3:A2", "N", _c([Vector2i(5, 26)]))
	# Main contactor, fed by KM3 13-14 or its own KM1 13-14.
	doc.connect_terminals("KM3:14", "KM1:A1")
	doc.connect_terminals("KM3:14", "KM1:14", _c([Vector2i(10, 14), Vector2i(15, 14)]))
	doc.connect_terminals("KM1:A2", "N", _c([Vector2i(10, 26)]))
	# Delta, through the star contactor's NC.
	doc.connect_terminals("KM1:14", "KM3:11")
	doc.connect_terminals("KM3:12", "KM2:A1")
	doc.connect_terminals("KM2:A2", "N", _c([Vector2i(15, 26)]))
	return doc
