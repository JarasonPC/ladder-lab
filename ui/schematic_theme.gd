class_name SchematicTheme
extends RefCounted
## Colors and sizes used to draw schematics, in the style of the course guide:
## thin black lines on white paper, square terminals, teal designations and
## terminal numbers; voltage reach in orange (L / L1), slate (L2), lavender
## (L3) and blue (N).

const BACKGROUND := Color("ffffff")
const GRID_DOT := Color("d9dce1")
const LINE := Color("1d1d1d")
## Parts at L / L1 potential (voltage reach).
const LIVE := Color("d8693d")
## Parts at L2 and L3 potential.
const LIVE_L2 := Color("5c6a99")
const LIVE_L3 := Color("a597e0")
## Parts joined to N (N reach), Czech light blue for the neutral conductor.
const NEUTRAL := Color("1f9be6")
## Short-circuit current, blown fuses, injected faults.
const FAULT := Color("e0245e")
## Chattering, tripped protection.
const WARNING := Color("c99700")
const HOVER := Color(0.18, 0.5, 0.98, 0.12)
const COIL_ON := Color("f6cbb8")
## A lit lamp is filled grey, as in the guide.
const LAMP_ON := Color("c4c4c4")
const LAMP_GLOW := Color(0, 0, 0, 0)
const TEXT := Color("1d1d1d")
## Designations ("-KM1") and terminal numbers.
const DESIGNATION := Color("2c8b86")
const TERMINAL_TEXT := Color("2c8b86")
## Current path numbers above or beside the drawing.
const PATH_TEXT := Color("8a9099")
## Terminal squares that nothing reaches.
const TERMINAL_DEAD := Color("1d1d1d")
## Supply circles: the conductor names are black, as in the guide.
const L_COLOR := Color("1d1d1d")
const L2_COLOR := Color("1d1d1d")
const L3_COLOR := Color("1d1d1d")
const N_COLOR := Color("1d1d1d")



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


const LINE_WIDTH: float = 2.0
const LIVE_WIDTH: float = 2.6
## Side of the terminal squares in pixels.
const TERMINAL_SQUARE: float = 7.0
const LABEL_SIZE: int = 14
const TERMINAL_SIZE: int = 10
