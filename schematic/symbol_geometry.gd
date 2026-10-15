class_name SymbolGeometry
extends RefCounted
## Grid geometry of symbols, independent of drawing. Units are grid cells
## unless noted. In local coordinates two-terminal symbols run from their first
## terminal down to the second; a [Placement] mirrors and rotates them, so
## current paths can run vertically or horizontally.

## Pixels per grid cell.
const GRID: int = 20
## Distance in cells between the two terminals of a two-terminal symbol.
const SPAN: int = 3
## Distance in cells between the poles of multi-pole symbols and motor terminals.
const POLE_SPACING: int = 2
## Distance in cells between the upper and lower terminals of a motor.
const MOTOR_HEIGHT: int = 4
## PE terminal of a three-phase motor: below left of the motor circle.
const MOTOR_PE_CELL := Vector2i(-1, 4)

## Wire directions, used for junction detection.
const DIR_UP: int = 1
const DIR_RIGHT: int = 2
const DIR_DOWN: int = 4
const DIR_LEFT: int = 8


## Terminal name -> cell offset, before rotation.
static func local_terminals(c: CircuitComponent) -> Dictionary[String, Vector2i]:
	var names: PackedStringArray = c.get_terminal_names()
	var result: Dictionary[String, Vector2i] = {}
	if _is_three_pole(c):
		# Poles side by side, POLE_SPACING apart: 1, 3, 5 on top, 2, 4, 6 below.
		for i: int in names.size():
			result[names[i]] = Vector2i((i / 2) * POLE_SPACING, 0 if i % 2 == 0 else SPAN)
		return result
	if c is ThreePhaseMotor:
		var windings: int = (c as ThreePhaseMotor).winding_terminal_count()
		for i: int in names.size():
			result[names[i]] = motor_terminal_cell(i, (c as ThreePhaseMotor).kind) if i < windings else MOTOR_PE_CELL
		return result
	if c is TimerRelay and names.size() == 3:
		# Time relay with control input: A1 on top, A2 below, S beside A1.
		result[names[0]] = Vector2i.ZERO
		result[names[1]] = Vector2i(0, SPAN)
		result[names[2]] = Vector2i(1, 0)
		return result
	if names.size() == 1:
		result[names[0]] = Vector2i.ZERO
	elif names.size() == 2:
		result[names[0]] = Vector2i.ZERO
		result[names[1]] = Vector2i(0, SPAN)
	elif names.size() == 3:
		# Changeover contact: common at the bottom, NO above it, NC one cell
		# to the right.
		result[names[0]] = Vector2i(0, SPAN)
		result[names[1]] = Vector2i(1, 0)
		result[names[2]] = Vector2i.ZERO
	return result


## Direction of the symbol lead leaving a terminal, before rotation
## (0 for supplies, whose symbol has no lead).
static func local_lead_direction(c: CircuitComponent, terminal_name: String) -> int:
	var names: PackedStringArray = c.get_terminal_names()
	if _is_three_pole(c):
		return DIR_DOWN if names.find(terminal_name) % 2 == 0 else DIR_UP
	if c is ThreePhaseMotor:
		var i: int = names.find(terminal_name)
		if i >= (c as ThreePhaseMotor).winding_terminal_count():
			return DIR_UP
		return DIR_DOWN if i < 3 else (DIR_UP if i < 6 else DIR_LEFT)
	if c is TimerRelay and names.size() == 3:
		return DIR_UP if terminal_name == names[1] else DIR_DOWN
	if names.size() == 3:
		return DIR_UP if terminal_name == names[0] else DIR_DOWN
	if names.size() != 2:
		return 0
	return DIR_DOWN if terminal_name == names[0] else DIR_UP


## Clickable body, before rotation, in cells.
static func local_body(c: CircuitComponent) -> Rect2:
	if c is PowerSupply:
		return Rect2(-0.6, -1.4, 1.2, 1.8)
	if c is Junction:
		return Rect2(-0.3, -0.3, 0.6, 0.6)
	if c is TerminalBlock:
		return Rect2(-0.45, -0.45, 0.9, 0.9)
	# The others fit what their symbol draws (with a little margin), so
	# selection and drag highlights match the symbol.
	if c is ChangeoverContact:
		var changeover_left: float = -1.55 if (c as ChangeoverContact).delayed else -0.85
		return Rect2(changeover_left, 0.75, 1.2 - changeover_left, 1.4)
	if _is_three_pole(c):
		var poles: int = c.get_terminal_names().size() / 2
		var span: float = (poles - 1) * POLE_SPACING
		if c is MotorBreaker:
			return Rect2(-1.15, 0.7, span + 1.45, 1.6)
		if c is MainContacts:
			return Rect2(-0.75, 0.75, span + 1.0, 1.4)
		if c is ThreePoleFuse:
			var fuse_left: float = -0.95 if (c as ThreePoleFuse).holder else -0.45
			return Rect2(fuse_left, 0.55, span + 0.45 - fuse_left, 1.9)
		return Rect2(-1.0, 0.5, span + 2.0, 2.0)
	if c is ThreePhaseMotor:
		var wide: bool = (c as ThreePhaseMotor).kind == ThreePhaseMotor.Kind.THREE_WINDINGS
		return Rect2(-0.4, 0.5, 6.0 if wide else 4.8, 3.0)
	if c is CircuitBreaker:
		return Rect2(-1.15, 0.7, 1.45, 1.6)
	if c is Fuse:
		var left: float = -0.95 if (c as Fuse).holder else -0.45
		return Rect2(left, 0.55, 0.45 - left, 1.9)
	if c is SwitchingElement:
		var marked: bool = c is PushButton or c is LatchingSwitch or c is OverloadContact or (c is Contact and (c as Contact).delayed)
		var contact_left: float = -1.55 if marked else -0.85
		return Rect2(contact_left, 0.75, 1.05 - contact_left, 1.4)
	if c is TimerRelay:
		return Rect2(-1.55, 0.85, 2.4, 1.3)
	if c is Coil:
		return Rect2(-0.85, 0.85, 1.7, 1.3)
	if c is Lamp:
		return Rect2(-0.75, 0.75, 1.5, 1.5)
	if c is Motor:
		return Rect2(-0.85, 0.65, 1.7, 1.7)
	if c is OverloadRelay:
		return Rect2(-0.95, 0.55, 1.9, 1.9)
	return Rect2(-1.0, 0.5, 2.0, 2.0)


## Cell of motor terminal [param index]: U-V-W of the first set on top, the
## second set below, the third on the right. A star-delta motor has its ends
## below as on its terminal board: W2 U2 V2 under U1 V1 W1.
static func motor_terminal_cell(index: int, kind: ThreePhaseMotor.Kind = ThreePhaseMotor.Kind.STANDARD) -> Vector2i:
	if index < 3:
		return Vector2i(index * POLE_SPACING, 0)
	if index < 6:
		var column: int = index - 3
		if kind == ThreePhaseMotor.Kind.STAR_DELTA:
			column = (column + 1) % 3
		return Vector2i(column * POLE_SPACING, MOTOR_HEIGHT)
	return Vector2i(3 * POLE_SPACING, index - 5)


static func _is_three_pole(c: CircuitComponent) -> bool:
	return c is PoleDevice or (c is OverloadRelay and (c as OverloadRelay).poles == 3)


## Local cell offset -> offset from the placement cell.
static func transform_cell(v: Vector2i, p: Placement) -> Vector2i:
	if p.mirrored:
		v.x = -v.x
	match p.rotation:
		1:
			return Vector2i(-v.y, v.x)
		2:
			return Vector2i(-v.x, -v.y)
		3:
			return Vector2i(v.y, -v.x)
	return v


static func transform_point(v: Vector2, p: Placement) -> Vector2:
	if p.mirrored:
		v.x = -v.x
	match p.rotation:
		1:
			return Vector2(-v.y, v.x)
		2:
			return Vector2(-v.x, -v.y)
		3:
			return Vector2(v.y, -v.x)
	return v


static func transform_rect(r: Rect2, p: Placement) -> Rect2:
	var a: Vector2 = transform_point(r.position, p)
	var b: Vector2 = transform_point(r.end, p)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


static func transform_direction(direction: int, p: Placement) -> int:
	var order: Array[int] = [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT]
	if p.mirrored:
		if direction == DIR_LEFT:
			direction = DIR_RIGHT
		elif direction == DIR_RIGHT:
			direction = DIR_LEFT
	var i: int = order.find(direction)
	if i < 0:
		return 0
	return order[posmod(i + p.rotation, 4)]


## Pixel transform for drawing a symbol in local coordinates (no translation).
static func draw_transform(p: Placement) -> Transform2D:
	var t: Transform2D = Transform2D(p.rotation * PI / 2.0, Vector2.ZERO)
	if p.mirrored:
		t = t * Transform2D.FLIP_X
	return t


## Direction bit for a unit step between neighbouring cells.
static func direction_of(step: Vector2i) -> int:
	if step == Vector2i.UP:
		return DIR_UP
	if step == Vector2i.RIGHT:
		return DIR_RIGHT
	if step == Vector2i.DOWN:
		return DIR_DOWN
	if step == Vector2i.LEFT:
		return DIR_LEFT
	return 0
