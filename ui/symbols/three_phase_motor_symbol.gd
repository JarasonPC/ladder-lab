class_name ThreePhaseMotorSymbol
extends SchematicSymbol
## Three-phase motor (IEC 60617 S00819 style): circle with "M 3~" and a lead
## per terminal. While the shaft turns an arrow turns around it in its
## direction of rotation, faster at higher speeds and slowing down as the
## motor runs down; Y / Δ, the speed step or DC braking is written beside it,
## a phase loss or wrong connection in the fault colour. The PE terminal of
## the frame is below left, as in the guide.

const CENTER := Vector2(2.0 * G, 2.0 * G)
const RADIUS: float = 26.0

var _angle: float = 0.0


func _process(delta: float) -> void:
	super(delta)
	var motor: ThreePhaseMotor = component as ThreePhaseMotor
	if motor.is_turning():
		var turn: float = 1.0 if motor.shaft_direction == ThreePhaseMotor.Direction.CLOCKWISE else -1.0
		_angle = fmod(_angle + turn * delta * TAU * maxf(motor.speed, 1) * motor.shaft, TAU)
		queue_redraw()


func _designation_anchor() -> Vector2:
	return Vector2(-1.4 * G, 1.2 * G)


func _terminal_box() -> bool:
	return (component as ThreePhaseMotor).terminal_box


func _draw_shape(color: Color, width: float) -> void:
	var motor: ThreePhaseMotor = component as ThreePhaseMotor
	if _terminal_box():
		_draw_terminal_box(motor, color)
		return
	var names: PackedStringArray = motor.get_terminal_names()
	var windings: int = motor.winding_terminal_count()
	# PE: from the frame to the left, then down to its terminal.
	var pe_cell: Vector2 = Vector2(SymbolGeometry.MOTOR_PE_CELL) * G
	var frame: Vector2 = CENTER + Vector2.from_angle(PI * 0.88) * RADIUS
	aa_polyline(PackedVector2Array([frame, Vector2(pe_cell.x, frame.y), pe_cell]), lead_color(windings), lead_width(windings))
	for i: int in windings:
		var cell: Vector2 = Vector2(SymbolGeometry.motor_terminal_cell(i, motor.kind)) * G
		var column: float = cell.x / (SymbolGeometry.POLE_SPACING * G)
		var angle: float
		var bend: Vector2
		if i < 3:
			angle = -PI * 0.5 + (column - 1) * PI * 0.25
			bend = cell + Vector2(0, 0.4 * G)
		elif i < 6:
			angle = PI * 0.5 - (column - 1) * PI * 0.25
			bend = cell - Vector2(0, 0.4 * G)
		else:
			angle = (i - 7) * PI * 0.2
			bend = cell - Vector2(0.6 * G, 0)
		var edge: Vector2 = CENTER + Vector2.from_angle(angle) * RADIUS
		aa_polyline(PackedVector2Array([cell, bend, edge]), lead_color(i), lead_width(i))
	var fill: Color = SchematicTheme.COIL_ON if _powered(motor) else SchematicTheme.BACKGROUND
	if motor.state == ThreePhaseMotor.State.PHASE_LOSS or motor.state == ThreePhaseMotor.State.MISWIRED:
		fill = Color(SchematicTheme.FAULT, 0.25)
	aa_circle(CENTER, RADIUS, fill)
	# The housing is drawn plain; the leads show the phases.
	color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	aa_arc(CENTER, RADIUS, 0.0, TAU, 40, color, SchematicTheme.LINE_WIDTH if not _powered(motor) else width)
	if motor.is_turning():
		var r: float = RADIUS + 6.0
		var arc: float = PI * 0.6
		var turn: float = 1.0 if motor.shaft_direction == ThreePhaseMotor.Direction.CLOCKWISE else -1.0
		var start: float = _angle
		if placement.mirrored:
			# Drawn mirrored: mirror the angle too, so the arrow turns the same way on screen.
			start = PI - _angle
			turn = -turn
		aa_arc(CENTER, r, start, start + turn * arc, 12, SchematicTheme.LINE, 2.0)
		var end_angle: float = start + turn * arc
		var tip: Vector2 = CENTER + Vector2.from_angle(end_angle) * r
		var forward: Vector2 = Vector2.from_angle(end_angle + turn * PI * 0.5)
		var side: Vector2 = Vector2.from_angle(end_angle)
		aa_polygon(PackedVector2Array([tip + forward * 7.0, tip - side * 4.5, tip + side * 4.5]), SchematicTheme.LINE)


## Box of the terminal board, with room for the stud names right of the
## last column.
const BOARD := Rect2(-12, 10, 120, 64)
## Rows of the terminal studs: U1 V1 W1 (fed) and W2 U2 V2 below them.
const FEED_ROW: float = 26.0
const END_ROW: float = 58.0


## The motor drawn as its terminal board (as in the guide). A standard motor:
## U1 V1 W1 fed from above, W2 U2 V2 below them, joined by star (one bar along
## W2-U2-V2) or delta bridges (U1-W2, V1-U2, W1-V2). The other kinds show a
## stud for each of their terminals, the bridges being made by contactors.
func _draw_terminal_box(motor: ThreePhaseMotor, color: Color) -> void:
	var fill: Color = SchematicTheme.COIL_ON if _powered(motor) else SchematicTheme.BACKGROUND
	if motor.state == ThreePhaseMotor.State.PHASE_LOSS or motor.state == ThreePhaseMotor.State.MISWIRED:
		fill = Color(SchematicTheme.FAULT, 0.25)
	var board: Rect2 = _board(motor)
	aa_rect(board, fill)
	color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	aa_rect(board, color, false, SchematicTheme.LINE_WIDTH)
	if motor.kind != ThreePhaseMotor.Kind.STANDARD:
		for i: int in motor.winding_terminal_count():
			var cell: Vector2 = Vector2(SymbolGeometry.motor_terminal_cell(i, motor.kind)) * G
			var stud: Vector2 = _stud(motor, i)
			var toward: Vector2 = (cell - stud).normalized()
			aa_line(cell, stud + toward * 3.5, lead_color(i), lead_width(i))
			aa_circle(stud, 3.5, SchematicTheme.BACKGROUND)
			aa_arc(stud, 3.5, 0.0, TAU, 12, lead_color(i) if reach(i) != REACH_NONE else color, 1.5)
		_draw_box_pe(motor, board)
		return
	for i: int in 3:
		var x: float = i * SymbolGeometry.POLE_SPACING * G
		aa_line(Vector2(x, 0), Vector2(x, FEED_ROW - 4.0), lead_color(i), lead_width(i))
	var bridge_width: float = 1.8
	if motor.delta_bridges:
		for i: int in 3:
			var x: float = i * SymbolGeometry.POLE_SPACING * G
			_draw_bar(Vector2(x, FEED_ROW), Vector2(x, END_ROW), color, bridge_width)
	else:
		_draw_bar(Vector2(0, END_ROW), Vector2(4 * G, END_ROW), color, bridge_width)
	for i: int in 3:
		var x: float = i * SymbolGeometry.POLE_SPACING * G
		for y: float in [FEED_ROW, END_ROW]:
			aa_circle(Vector2(x, y), 3.5, SchematicTheme.BACKGROUND)
			aa_arc(Vector2(x, y), 3.5, 0.0, TAU, 12, lead_color(i) if y == FEED_ROW and reach(i) != REACH_NONE else color, 1.5)
	_draw_box_pe(motor, board)


## Current flows in the windings: running or DC braking.
func _powered(motor: ThreePhaseMotor) -> bool:
	return motor.is_running() or motor.state == ThreePhaseMotor.State.DC_BRAKING


## PE: from the frame of the box to its terminal.
func _draw_box_pe(motor: ThreePhaseMotor, board: Rect2) -> void:
	var windings: int = motor.winding_terminal_count()
	var pe_cell: Vector2 = Vector2(SymbolGeometry.MOTOR_PE_CELL) * G
	aa_polyline(PackedVector2Array([Vector2(board.position.x, 3.0 * G), Vector2(pe_cell.x, 3.0 * G), pe_cell]), lead_color(windings), lead_width(windings))


## Box of the terminal board, wider for a motor with a third winding.
func _board(motor: ThreePhaseMotor) -> Rect2:
	if motor.kind == ThreePhaseMotor.Kind.THREE_WINDINGS:
		return Rect2(BOARD.position, BOARD.size + Vector2(20, 0))
	return BOARD


## Stud of winding terminal [param i] on the terminal board: the first set on
## the upper row, the second on the lower row, the third in a column at the right.
func _stud(motor: ThreePhaseMotor, i: int) -> Vector2:
	var cell: Vector2 = Vector2(SymbolGeometry.motor_terminal_cell(i, motor.kind)) * G
	if i < 3:
		return Vector2(cell.x, FEED_ROW)
	if i < 6:
		return Vector2(cell.x, END_ROW)
	return Vector2(cell.x - 20.0, cell.y)


## Bridge: a rounded bar around two studs.
func _draw_bar(a: Vector2, b: Vector2, color: Color, w: float) -> void:
	var r: float = 7.0
	var along: Vector2 = (b - a).normalized()
	var across: Vector2 = Vector2(-along.y, along.x) * r
	aa_line(a + across, b + across, color, w)
	aa_line(a - across, b - across, color, w)
	var start: float = across.angle()
	aa_arc(a, r, start, start + PI, 10, color, w)
	aa_arc(b, r, start + PI, start + TAU, 10, color, w)


func _draw_labels() -> void:
	var motor: ThreePhaseMotor = component as ThreePhaseMotor
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	if _terminal_box() and motor.kind != ThreePhaseMotor.Kind.STANDARD:
		var box_names: PackedStringArray = motor.get_terminal_names()
		for i: int in motor.winding_terminal_count():
			var stud: Vector2 = _stud(motor, i)
			var anchor: Vector2 = stud + (Vector2(7.0, -8.0) if i < 3 else (Vector2(7.0, 10.0) if i < 6 else Vector2(6.0, -7.0)))
			draw_label(box_names[i], anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		draw_label(box_names[motor.winding_terminal_count()], Vector2(SymbolGeometry.MOTOR_PE_CELL) * G + Vector2(-0.3 * G, 0.3 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		var box_status: String = _status(motor)
		if not box_status.is_empty():
			var faulty: bool = motor.state in [ThreePhaseMotor.State.PHASE_LOSS, ThreePhaseMotor.State.MISWIRED]
			draw_label(box_status, _designation_anchor(), SchematicTheme.LABEL_SIZE if not _connection(motor).is_empty() else SchematicTheme.TERMINAL_SIZE, SchematicTheme.FAULT if faulty else SchematicTheme.TEXT, 1)
		return
	if _terminal_box():
		var names: PackedStringArray = motor.get_terminal_names()
		var ends: PackedStringArray = ["W2", "U2", "V2"]
		for i: int in 3:
			var x: float = i * SymbolGeometry.POLE_SPACING * G
			draw_label(names[i], Vector2(x + 7.0, FEED_ROW - 8.0), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
			# Above the stud: below it the star bar would cross the text.
			draw_label(ends[i], Vector2(x + 7.0, END_ROW - 13.0), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		draw_label(names[motor.winding_terminal_count()], Vector2(SymbolGeometry.MOTOR_PE_CELL) * G + Vector2(-0.3 * G, 0.3 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		draw_label("Δ" if motor.delta_bridges else "Y", _designation_anchor(), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
		return
	var names: PackedStringArray = motor.get_terminal_names()
	var windings: int = motor.winding_terminal_count()
	draw_label(names[windings], Vector2(SymbolGeometry.MOTOR_PE_CELL) * G + Vector2(-0.3 * G, 0.3 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	for i: int in windings:
		var cell: Vector2 = Vector2(SymbolGeometry.motor_terminal_cell(i, motor.kind)) * G
		# Beside the lead, clear of its bend toward the circle: upper ones
		# left of the first column, lower ones level with their terminal
		# (the PE lead runs left of them).
		var side: float = -0.3 * G if cell.x < 1.0 else 0.3 * G
		var offset: Vector2 = Vector2(side, 0.4 * G)
		if i >= 3 and i < 6:
			# Beside the wire leaving downward, below the lead's bend.
			offset = Vector2(0.3 * G, 0.05 * G)
		elif i >= 6:
			# Third winding: right of the terminal, above its wire.
			offset = Vector2(0.3 * G, -0.35 * G)
		draw_label(names[i], cell + offset, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	var font: Font = AppTheme.schematic_font()
	var c: Vector2 = to_upright(CENTER)
	var connection: String = _connection(motor)
	if connection.is_empty():
		_centered(font, "M3~", c, 15, SchematicTheme.TEXT)
	else:
		# Running in star or delta: written large in the motor.
		_centered(font, "M3~", c + Vector2(0, -8), 13, SchematicTheme.TEXT)
		_centered(AppTheme.bold_font(), connection, c + Vector2(0, 10), 16, SchematicTheme.TEXT)
	var status: String = _status(motor)
	var status_color: Color = SchematicTheme.FAULT if motor.state in [ThreePhaseMotor.State.PHASE_LOSS, ThreePhaseMotor.State.MISWIRED] else SchematicTheme.TEXT
	if not status.is_empty() and connection.is_empty():
		draw_label(status, _designation_anchor(), SchematicTheme.TERMINAL_SIZE, status_color, 1)


## "Y" or "Δ" while the motor runs in star or delta, else "".
static func _connection(motor: ThreePhaseMotor) -> String:
	match motor.state:
		ThreePhaseMotor.State.STAR:
			return "Y"
		ThreePhaseMotor.State.DELTA:
			return "Δ"
	return ""


## What the motor is doing, written beside it: Y / Δ, the speed step, DC
## braking, a phase loss or wrong connection; "" when there is nothing to say.
func _status(motor: ThreePhaseMotor) -> String:
	var status: String = _connection(motor)
	match motor.state:
		ThreePhaseMotor.State.PHASE_LOSS:
			status = tr("phase loss")
		ThreePhaseMotor.State.MISWIRED:
			status = tr("miswired")
		ThreePhaseMotor.State.DC_BRAKING:
			status = tr("DC brake")
		ThreePhaseMotor.State.RUNNING:
			if motor.speed > 0:
				status = tr("speed %d") % motor.speed
	return status


func _centered(font: Font, text: String, at: Vector2, size: int, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, at + Vector2(-w * 0.5, font.get_ascent(size) * 0.5 - 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
