class_name VoltageRating
extends RefCounted
## Rated voltages of loads (coils, time relays, lamps, PLCs), by name as saved
## ("230ac", "24dc", ...); "" is a part without a rating, working on any
## voltage (parts of files before version 20).
##
## A coil works from [constant PICK_UP] of its rated voltage on and burns out
## above [constant BURN] of it; an AC coil on DC (no reactance to hold the
## current back) burns out from [constant AC_ON_DC] of it on, a DC coil on AC
## does not pull in. Lamps light on AC and DC alike. A PLC works within the
## range of its version and takes an input as 1 from its threshold on.

enum Kind { AC, DC, AC_DC }
## What a load does on a voltage.
enum State { OFF, WORKS, BURNS }

const PICK_UP: float = 0.85
const BURN: float = 1.3
const AC_ON_DC: float = 0.3

## name: [nominal volts, kind, lowest working volts, input threshold (PLC)].
## Lowest working 0: PICK_UP of the nominal.
const TABLE: Dictionary[String, Array] = {
	"230ac": [230.0, Kind.AC, 0.0, 0.0],
	"400ac": [400.0, Kind.AC, 0.0, 0.0],
	"12dc": [12.0, Kind.DC, 0.0, 0.0],
	"24dc": [24.0, Kind.DC, 0.0, 0.0],
	"48dc": [48.0, Kind.DC, 0.0, 0.0],
	"110dc": [110.0, Kind.DC, 0.0, 0.0],
	"220dc": [220.0, Kind.DC, 0.0, 0.0],
	"230v": [230.0, Kind.AC_DC, 0.0, 0.0],
	"400v": [400.0, Kind.AC_DC, 0.0, 0.0],
	"12v": [12.0, Kind.AC_DC, 0.0, 0.0],
	"24v": [24.0, Kind.AC_DC, 0.0, 0.0],
	"48v": [48.0, Kind.AC_DC, 0.0, 0.0],
	"110v": [110.0, Kind.AC_DC, 0.0, 0.0],
	"220v": [220.0, Kind.AC_DC, 0.0, 0.0],
	# PLC versions: 115-240 V AC/DC, 24 V AC/DC, 12/24 V DC.
	"230rc": [240.0, Kind.AC_DC, 85.0, 79.0],
	"24rc": [24.0, Kind.AC_DC, 20.4, 12.0],
	"1224rc": [24.0, Kind.DC, 10.8, 8.0],
	# Compact CPUs (DC/DC/DC): 24 V DC, inputs on from 15 V.
	"cpu24dc": [24.0, Kind.DC, 20.4, 15.0],
}
## The ratings offered for coils (and time relays), lamps and PLCs; new
## parts from the palette get the first.
const COIL_RATINGS: PackedStringArray = ["230ac", "400ac", "12dc", "24dc", "48dc", "110dc", "220dc"]
const LAMP_RATINGS: PackedStringArray = ["230v", "400v", "12v", "24v", "48v", "110v", "220v"]
const PLC_RATINGS: PackedStringArray = ["230rc", "24rc", "1224rc"]


## Ratings offered for a part saved as [param type] ("coil", "timer",
## "lamp", "plc"); empty for parts without a rating.
static func offered(type: String) -> PackedStringArray:
	match type:
		"coil", "timer":
			return COIL_RATINGS
		"lamp":
			return LAMP_RATINGS
		"plc":
			return PLC_RATINGS
	return PackedStringArray()


static func is_known(name: String) -> bool:
	return name.is_empty() or TABLE.has(name)


static func nominal(name: String) -> float:
	return float(TABLE[name][0]) if TABLE.has(name) else 0.0


static func kind(name: String) -> Kind:
	return TABLE[name][1] as Kind if TABLE.has(name) else Kind.AC_DC


## Lowest voltage a load of [param name] works on.
static func lowest(name: String) -> float:
	if not TABLE.has(name):
		return 0.0
	var given: float = float(TABLE[name][2])
	return given if given > 0.0 else PICK_UP * nominal(name)


## Voltage from which a PLC of [param name] takes an input as 1 (the lowest
## working voltage for other ratings).
static func input_threshold(name: String) -> float:
	if TABLE.has(name) and float(TABLE[name][3]) > 0.0:
		return float(TABLE[name][3])
	return lowest(name)


## What a load rated [param name] does with [param volts] across it ([param dc]:
## from a DC source).
static func state(name: String, volts: float, dc: bool) -> State:
	if not TABLE.has(name):
		return State.WORKS if volts > 0.0 else State.OFF
	var k: Kind = kind(name)
	var rated: float = nominal(name)
	if k == Kind.AC and dc:
		return State.BURNS if volts >= AC_ON_DC * rated else State.OFF
	if volts > BURN * rated:
		return State.BURNS
	if k == Kind.DC and not dc:
		return State.OFF
	return State.WORKS if volts >= lowest(name) else State.OFF


## How the rating is written on the drawing and in the properties: "230 V AC",
## "24 V DC", "230 V", "115-240 V AC/DC"; "" without a rating.
static func text(name: String) -> String:
	match name:
		"":
			return ""
		"230rc":
			return "115-240 V AC/DC"
		"24rc":
			return "24 V AC/DC"
		"1224rc":
			return "12/24 V DC"
		"cpu24dc":
			return "24 V DC"
	if not TABLE.has(name):
		return ""
	var volts: String = "%d V" % roundi(nominal(name))
	match kind(name):
		Kind.AC:
			return volts + " AC"
		Kind.DC:
			return volts + " DC"
	return volts
