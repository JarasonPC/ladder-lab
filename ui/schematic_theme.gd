class_name SchematicTheme
extends RefCounted
## Colors and sizes used to draw schematics.

const BACKGROUND := Color("f7f5ef")
const GRID_DOT := Color("d6d1c4")
const LINE := Color("1f2328")
## Parts at L / L1 potential (voltage reach).
const LIVE := Color("d7263d")
## Parts at L2 and L3 potential.
const LIVE_L2 := Color("7b3fd0")
const LIVE_L3 := Color("00897b")
## Parts joined to N (N reach), Czech light blue for the neutral conductor.
const NEUTRAL := Color("1e88e5")
const FAULT := Color("ff7a00")
const WARNING := Color("e8871e")
const HOVER := Color(0.18, 0.5, 0.98, 0.14)
const COIL_ON := Color("f6c2c8")
const LAMP_ON := Color("ffd23f")
const LAMP_GLOW := Color(1.0, 0.82, 0.25, 0.35)
const TEXT := Color("1f2328")
const TERMINAL_TEXT := Color("7a7a7a")
## Czech practice: L / L1 brown, L2 black, L3 grey, N light blue.
const L_COLOR := Color("8b4513")
const L2_COLOR := Color("1f2328")
const L3_COLOR := Color("8a8a8a")
const N_COLOR := Color("1e88e5")



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
const LIVE_WIDTH: float = 3.5
const LABEL_SIZE: int = 14
const TERMINAL_SIZE: int = 10
