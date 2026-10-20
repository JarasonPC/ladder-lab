class_name SchematicTheme
extends RefCounted
## Colors and sizes used to draw schematics, in the style of the course guide:
## thin lines, square terminals, teal designations and terminal numbers;
## voltage reach in orange (L / L1), slate (L2), lavender (L3) and blue (N);
## the DC poles in magenta (+) and dark blue (-).
## Two papers: white (as in the guide) and dark ([method use]).

static var dark: bool = false

static var BACKGROUND: Color
static var GRID_DOT: Color
static var LINE: Color
## Parts at L / L1 potential (voltage reach).
static var LIVE: Color
## Parts at L2 and L3 potential.
static var LIVE_L2: Color
static var LIVE_L3: Color
## Parts joined to N (N reach), Czech light blue for the neutral conductor.
static var NEUTRAL: Color
## Parts at the potential of the DC poles + and -.
static var DC_PLUS: Color
static var DC_MINUS: Color
## Short-circuit current, blown fuses, injected faults.
static var FAULT: Color
## Chattering, tripped protection.
static var WARNING: Color
static var HOVER: Color
static var COIL_ON: Color
## A lit lamp is filled grey on white paper (as in the guide), light on dark paper.
static var LAMP_ON: Color
## Cross of a lit lamp.
static var LAMP_CROSS: Color
static var TEXT: Color
## Designations ("-KM1") and terminal numbers.
static var DESIGNATION: Color
static var TERMINAL_TEXT: Color
## Purpose text above a lamp ("Chod").
static var PURPOSE_TEXT: Color
## Current path numbers above or beside the drawing.
static var PATH_TEXT: Color
## Terminal squares that nothing reaches.
static var TERMINAL_DEAD: Color
## Protective earth (green-yellow conductor).
static var PE: Color
## Wire numbers at the wire ends.
static var WIRE_NUMBER: Color
## Currents written on the wires while simulating.
static var CURRENT: Color
## Ethernet cables between the ports of PLCs and network switches (drawn
## dashed).
static var NETWORK: Color
## Workspace tiles: switchboards, control stations, parts in the field,
## the frame of a group and the ring round what is selected.
static var TILE_SWITCHBOARD: Color
static var TILE_STATION: Color
static var TILE_FIELD: Color
static var GROUP_FILL: Color
static var GROUP_EDGE: Color
static var SELECTED: Color

const LINE_WIDTH: float = 2.0
const LIVE_WIDTH: float = 2.6
## Side of the terminal squares in pixels.
const TERMINAL_SQUARE: float = 7.0
const LABEL_SIZE: int = 14
const TERMINAL_SIZE: int = 10


static func _static_init() -> void:
	use(false)


## Switches between white paper and dark paper.
static func use(dark_paper: bool) -> void:
	dark = dark_paper
	HOVER = Color(0.18, 0.5, 0.98, 0.12 if not dark else 0.2)
	if not dark:
		BACKGROUND = Color("ffffff")
		GRID_DOT = Color("d9dce1")
		LINE = Color("1d1d1d")
		LIVE = Color("d8693d")
		LIVE_L2 = Color("5c6a99")
		LIVE_L3 = Color("a597e0")
		NEUTRAL = Color("1f9be6")
		DC_PLUS = Color("b0479a")
		DC_MINUS = Color("2a44a8")
		FAULT = Color("e0245e")
		WARNING = Color("c99700")
		COIL_ON = Color("f6cbb8")
		LAMP_ON = Color("c4c4c4")
		LAMP_CROSS = Color("1d1d1d")
		TEXT = Color("1d1d1d")
		DESIGNATION = Color("2c8b86")
		TERMINAL_TEXT = Color("2c8b86")
		PURPOSE_TEXT = Color("8c9a3c")
		PATH_TEXT = Color("8a9099")
		TERMINAL_DEAD = Color("1d1d1d")
		PE = Color("3c9a3c")
		WIRE_NUMBER = Color("d0342c")
		CURRENT = Color("8a5a00")
		NETWORK = Color("13865a")
		TILE_SWITCHBOARD = Color("1f6f78")
		TILE_STATION = Color("3a5fb0")
		TILE_FIELD = Color("5b6472")
		GROUP_FILL = Color(0.18, 0.43, 0.93, 0.08)
		GROUP_EDGE = Color(0.18, 0.43, 0.93, 0.35)
		SELECTED = Color("2f6fec")
	else:
		BACKGROUND = Color("15181d")
		GRID_DOT = Color("2a2f38")
		LINE = Color("c3c9d2")
		LIVE = Color("ff8d4d")
		LIVE_L2 = Color("8f9de0")
		LIVE_L3 = Color("c2b2ff")
		NEUTRAL = Color("46b4ff")
		DC_PLUS = Color("e27cca")
		DC_MINUS = Color("7d93ff")
		FAULT = Color("ff4f7b")
		WARNING = Color("f2c200")
		COIL_ON = Color("6b3a24")
		LAMP_ON = Color("e4e6ea")
		LAMP_CROSS = Color("15181d")
		TEXT = Color("e8eaef")
		DESIGNATION = Color("5fd0c4")
		TERMINAL_TEXT = Color("6fb8b0")
		PURPOSE_TEXT = Color("b9c76f")
		PATH_TEXT = Color("7d8590")
		TERMINAL_DEAD = Color("c3c9d2")
		PE = Color("6cc56c")
		WIRE_NUMBER = Color("ff7b72")
		CURRENT = Color("ffc857")
		NETWORK = Color("3fcf8e")
		TILE_SWITCHBOARD = Color("2b7c86")
		TILE_STATION = Color("4a6fc0")
		TILE_FIELD = Color("646d7c")
		GROUP_FILL = Color(0.3, 0.55, 1.0, 0.1)
		GROUP_EDGE = Color(0.3, 0.55, 1.0, 0.4)
		SELECTED = Color("4c8dff")


## A current as written on the drawing: "35 mA", "4.62 A", "48.1 A", "160 A".
static func amperes(value: float) -> String:
	if value < 1.0:
		return "%d mA" % maxi(roundi(value * 1000.0), 1)
	if value < 10.0:
		return "%.2f A" % value
	if value < 100.0:
		return "%.1f A" % value
	return "%d A" % roundi(value)


## Highlight colour for a reach code (see [StepResult]); LINE for none.
static func reach_color(code: int) -> Color:
	match code:
		StepResult.REACH_L1:
			return LIVE
		StepResult.REACH_L2:
			return LIVE_L2
		StepResult.REACH_L3:
			return LIVE_L3
		StepResult.REACH_N:
			return NEUTRAL
		StepResult.REACH_PE:
			return PE
		StepResult.REACH_DC_PLUS:
			return DC_PLUS
		StepResult.REACH_DC_MINUS:
			return DC_MINUS
		StepResult.REACH_SEVERAL:
			return FAULT
	return LINE
