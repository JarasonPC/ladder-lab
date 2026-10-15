class_name SchematicTheme
extends RefCounted
## Colors and sizes used to draw schematics, in the style of the course guide:
## thin lines, square terminals, teal designations and terminal numbers;
## voltage reach in orange (L / L1), slate (L2), lavender (L3) and blue (N).
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
	else:
		BACKGROUND = Color("15181d")
		GRID_DOT = Color("2a2f38")
		LINE = Color("c3c9d2")
		LIVE = Color("ff8d4d")
		LIVE_L2 = Color("8f9de0")
		LIVE_L3 = Color("c2b2ff")
		NEUTRAL = Color("46b4ff")
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
		StepResult.REACH_SEVERAL:
			return FAULT
	return LINE
