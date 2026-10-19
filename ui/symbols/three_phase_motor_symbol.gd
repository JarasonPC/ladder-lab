class_name ThreePhaseMotorSymbol
extends SchematicSymbol
## Three-phase motor (IEC 60617 S00819 style): circle with "M 3~" and a lead
## per terminal. While the shaft turns an arrow turns around it in its
## direction of rotation, faster at higher speeds and slowing down as the
## motor runs down; Y / Δ, the speed step or DC braking is written beside it,
## a phase loss or wrong connection in the fault colour, the current it
## draws (in the fault colour above its rated current) and its speed; its
## rating plate can be drawn beside it. The PE terminal of
## the frame is below left, as in the guide.

const CENTER := Vector2(2.0 * G, 2.0 * G)
const RADIUS: float = 26.0

var _angle: float = 0.0


func _process(delta: float) -> void:
	super(delta)
	var motor: ThreePhaseMotor = component as ThreePhaseMotor
	if motor.is_turning():
		var turn: float = 1.0 if motor.shaft_direction == ThreePhaseMotor.Direction.CLOCKWISE else -1.0
		_angle = fmod(_angle + turn * delta * TAU * motor.speed_count() * absf(motor.rotor_speed), TAU)
		queue_redraw()


func _designation_anchor() -> Vector2:
	# Further out when U1 is on a terminal strip, clear of its label.
	return Vector2(-1.7 * G if placement.strips.has(0) else -1.4 * G, 1.2 * G)


## A third winding's terminals and wires take the motor's right: the fault
## mark goes above, right of the first set's wires.
func fault_anchor() -> Vector2:
	if (component as ThreePhaseMotor).kind == ThreePhaseMotor.Kind.THREE_WINDINGS:
		return Vector2(5.5 * G, 0.0)
	return super()


func _terminal_box() -> bool:
	return (component as ThreePhaseMotor).terminal_box


func _draw_shape(color: Color, width: float) -> void:
	var motor: ThreePhaseMotor = component as ThreePhaseMotor
	if preview:
		_draw_preview(motor, color, width)
		return
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
		# Inside the housing, round "M3~": outside it would sweep over the
		# terminal names.
		var r: float = RADIUS - 4.5
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
		aa_polygon(PackedVector2Array([tip + forward * 6.0, tip - side * 3.5, tip + side * 3.5]), SchematicTheme.LINE)


## Middle of the column right of the circle in the palette (winding marks
## or what the motor is) and its width.
const PREVIEW_MARKS_X: float = CENTER.x + RADIUS + 22.0
const PREVIEW_COLUMN: float = 44.0


## The palette shows the circle with "M 3~" and, beside it, what kind of
## motor it is; the leads alone would not tell the kinds apart on a tile.
func preview_rect() -> Rect2:
	var circle: Rect2 = Rect2(CENTER - Vector2.ONE * RADIUS, Vector2.ONE * 2.0 * RADIUS)
	if (component as ThreePhaseMotor).kind == ThreePhaseMotor.Kind.STANDARD:
		return circle
	return circle.expand(Vector2(PREVIEW_MARKS_X + PREVIEW_COLUMN * 0.5, CENTER.y))


## Circle with "M 3~"; right of it star over delta (star/delta), or the
## number of speeds over "Dahl." (Dahlander) or "speed" (separate windings).
func _draw_preview(motor: ThreePhaseMotor, color: Color, width: float) -> void:
	aa_arc(CENTER, RADIUS, 0.0, TAU, 40, color, width)
	var lines: PackedStringArray = PackedStringArray()
	match motor.kind:
		ThreePhaseMotor.Kind.STAR_DELTA:
			_draw_star_mark(Vector2(PREVIEW_MARKS_X, CENTER.y - 13.0), 10.0, color, width)
			_draw_delta_mark(Vector2(PREVIEW_MARKS_X, CENTER.y + 13.0), 10.0, color, width)
		ThreePhaseMotor.Kind.DAHLANDER:
			lines = ["2", tr("Dahl.")]
		ThreePhaseMotor.Kind.TWO_WINDINGS:
			lines = ["2", tr("speed")]
		ThreePhaseMotor.Kind.THREE_WINDINGS:
			lines = ["3", tr("speed")]
	draw_preview_text("M", CENTER + Vector2(0.0, -7.0), 24)
	draw_preview_text("3~", CENTER + Vector2(0.0, 12.0), 17)
	if not lines.is_empty():
		draw_preview_text(lines[0], Vector2(PREVIEW_MARKS_X, CENTER.y - 10.0), 26)
		# The word as large as the column takes.
		var font: Font = AppTheme.schematic_font()
		var size: int = 17
		var w: float = font.get_string_size(lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if w > PREVIEW_COLUMN:
			size = maxi(floori(size * PREVIEW_COLUMN / w), 8)
		draw_preview_text(lines[1], Vector2(PREVIEW_MARKS_X, CENTER.y + 14.0), size)


## Star: three arms from the middle, two up and one down (centred on its height).
func _draw_star_mark(at: Vector2, r: float, color: Color, width: float) -> void:
	at.y -= r * 0.25
	for angle: float in [-PI * 5.0 / 6.0, -PI / 6.0, PI * 0.5]:
		aa_line(at, at + Vector2.from_angle(angle) * r, color, width)


## Delta: a triangle standing on its base (centred on its height).
func _draw_delta_mark(at: Vector2, r: float, color: Color, width: float) -> void:
	at.y += r * 0.25
	var corners: PackedVector2Array = PackedVector2Array()
	for angle: float in [-PI * 0.5, PI / 6.0, PI * 5.0 / 6.0, -PI * 0.5]:
		corners.append(at + Vector2.from_angle(angle) * r)
	aa_polyline(corners, color, width)


## Box of the terminal board, with room for the stud names right of the
## last column.
const BOARD := Rect2(-12, 10, 120, 64)
## Name of a lower terminal (or PE) on a terminal strip: right of its mark,
## a little above it, leaving the wire below it to the strip labels.
const BESIDE_MARK := Vector2(0.5 * G, -0.375 * G)
## Name of a third winding's terminal: right of it, half way to the wire
## above, so it stays between the wires however the motor is turned.
const THIRD_WINDING_NAME := Vector2(0.3 * G, -0.5 * G)
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


## Box of the terminal board, a little wider for the studs of a third
## winding; their terminals and names stay right of it.
func _board(motor: ThreePhaseMotor) -> Rect2:
	if motor.kind == ThreePhaseMotor.Kind.THREE_WINDINGS:
		return Rect2(BOARD.position, BOARD.size + Vector2(6, 0))
	return BOARD


## Stud of winding terminal [param i] on the terminal board: the first set on
## the upper row, the second on the lower row, the third in a column at the right.
func _stud(motor: ThreePhaseMotor, i: int) -> Vector2:
	var cell: Vector2 = Vector2(SymbolGeometry.motor_terminal_cell(i, motor.kind)) * G
	if i < 3:
		return Vector2(cell.x, FEED_ROW)
	if i < 6:
		return Vector2(cell.x, END_ROW)
	# Clear of the names of the last column's studs.
	return Vector2(cell.x - 12.0, cell.y)


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
	if motor.show_plate:
		_draw_plate(motor)
	if _terminal_box() and motor.kind != ThreePhaseMotor.Kind.STANDARD:
		var box_names: PackedStringArray = motor.get_terminal_names()
		for i: int in motor.winding_terminal_count():
			var stud: Vector2 = _stud(motor, i)
			var anchor: Vector2 = stud + (Vector2(7.0, -8.0) if i < 3 else Vector2(7.0, 8.0))
			if i >= 6:
				anchor = Vector2(SymbolGeometry.motor_terminal_cell(i, motor.kind)) * G + THIRD_WINDING_NAME
			elif placement.rotation % 2 == 1:
				_turned_stud_label(box_names[i], stud, true)
				continue
			draw_label(box_names[i], anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		draw_label(box_names[motor.winding_terminal_count()], _pe_name_anchor(motor), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		var box_status: String = _status(motor)
		if not box_status.is_empty():
			var faulty: bool = motor.state in [ThreePhaseMotor.State.PHASE_LOSS, ThreePhaseMotor.State.MISWIRED]
			draw_label(box_status, _designation_anchor(), SchematicTheme.LABEL_SIZE if not _connection(motor).is_empty() else SchematicTheme.TERMINAL_SIZE, SchematicTheme.FAULT if faulty else SchematicTheme.TEXT, _state_line(1))
		_draw_current(motor, 2 if not box_status.is_empty() else 1)
		return
	if _terminal_box():
		var names: PackedStringArray = motor.get_terminal_names()
		var ends: PackedStringArray = ["W2", "U2", "V2"]
		for i: int in 3:
			var x: float = i * SymbolGeometry.POLE_SPACING * G
			if placement.rotation % 2 == 1:
				_turned_stud_label(names[i], Vector2(x, FEED_ROW), true)
				_turned_stud_label(ends[i], Vector2(x, END_ROW), false)
				continue
			# Right of the delta bridges, above the stud: below it the star
			# bar would cross the text.
			draw_label(names[i], Vector2(x + 10.0, FEED_ROW - 8.0), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
			draw_label(ends[i], Vector2(x + 10.0, END_ROW - 13.0), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		draw_label(names[motor.winding_terminal_count()], _pe_name_anchor(motor), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
		draw_label("Δ" if motor.delta_bridges else "Y", _designation_anchor(), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, _state_line(1))
		_draw_current(motor, 2)
		return
	var names: PackedStringArray = motor.get_terminal_names()
	var windings: int = motor.winding_terminal_count()
	draw_label(names[windings], _pe_name_anchor(motor), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	for i: int in windings:
		var cell: Vector2 = Vector2(SymbolGeometry.motor_terminal_cell(i, motor.kind)) * G
		# Beside the lead, clear of its bend toward the circle: upper ones
		# left of the first column, lower ones level with their terminal
		# (the PE lead runs left of them).
		var side: float = -0.3 * G if cell.x < 1.0 else 0.3 * G
		var offset: Vector2 = Vector2(side, 0.4 * G)
		if i == 1 and placement.strips.has(i):
			# Off the strip mark: further out rather than down onto the circle.
			offset = Vector2(0.55 * G, 0.6 * G)
		if i >= 3 and i < 6:
			# Beside the wire leaving downward, below the lead's bend.
			offset = Vector2(0.3 * G, 0.05 * G) if not placement.strips.has(i) else BESIDE_MARK
		elif i >= 6:
			offset = THIRD_WINDING_NAME
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
		draw_label(status, _designation_anchor(), SchematicTheme.TERMINAL_SIZE, status_color, _state_line(1))
	_draw_current(motor, 2 if not status.is_empty() and connection.is_empty() else 1)


## Name of a stud of the terminal board lying on its side, where its rows
## run across the drawing: a little aside from the stud's row (toward the
## board's wider margin, clear of the leads and the delta bridges), from the
## stud toward the board's edge ([param outward]) or, for the ends of a
## standard motor, toward its middle, clear of the star bridge.
func _turned_stud_label(text: String, stud: Vector2, outward: bool) -> void:
	var font: Font = AppTheme.schematic_font()
	var size: int = SchematicTheme.TERMINAL_SIZE
	var t: Transform2D = SymbolGeometry.draw_transform(placement)
	var at: Vector2 = t * stud
	var middle: float = (t * Vector2(stud.x, (FEED_ROW + END_ROW) * 0.5)).x
	var toward: float = signf(at.x - middle) if outward else signf(middle - at.x)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x: float = at.x + toward * (-3.0 if outward else 9.0) - (width if toward < 0.0 else 0.0)
	var y: float = at.y + signf(t.basis_xform(Vector2.RIGHT).y) * 14.0
	_write(text, Vector2(x, y + font.get_ascent(size) * 0.5 - 1.0), size, SchematicTheme.TERMINAL_TEXT, _marking_of(text))


## Where the name of the PE terminal is written: right of its lead, beside
## its mark when it is on a terminal strip.
func _pe_name_anchor(motor: ThreePhaseMotor) -> Vector2:
	var strip: bool = placement.strips.has(motor.winding_terminal_count())
	return Vector2(SymbolGeometry.MOTOR_PE_CELL) * G + (BESIDE_MARK if strip else Vector2(0.3 * G, 0.4 * G))


## While it draws current: the largest of its line currents; while it
## turns: its speed.
func _draw_current(motor: ThreePhaseMotor, line: int) -> void:
	var amps: float = maxf(motor.max_line_current(), motor.max_current() if motor.state == ThreePhaseMotor.State.DC_BRAKING else 0.0)
	if amps >= 0.0005:
		var color: Color = SchematicTheme.FAULT if amps > motor.rated_current * 1.15 else SchematicTheme.CURRENT
		draw_label(SchematicTheme.amperes(amps), _designation_anchor(), SchematicTheme.TERMINAL_SIZE, color, _state_line(line))
		line += 1
	if motor.is_turning():
		draw_label("%d min⁻¹" % roundi(absf(motor.rpm())), _designation_anchor(), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, _state_line(line))


## Line [param n] of what the motor is doing, beside its designation: above
## it while the designation is beside the motor with the PE lead below it,
## which would cross the lines under it.
func _state_line(n: int) -> int:
	var pe_below: bool = SymbolGeometry.draw_transform(placement).basis_xform(Vector2.DOWN).y > 0.5
	return -n if pe_below and is_side_label(_designation_anchor()) else n


## Lines of the rating plate: kind, voltage and connection, currents, power
## and cos φ, speeds and efficiency, starting current.
static func plate_lines(motor: ThreePhaseMotor) -> PackedStringArray:
	var voltage: PackedStringArray = motor.plate_voltage()
	var amps: String = "%.1f" % motor.rated_current
	if motor.kind == ThreePhaseMotor.Kind.STAR_DELTA:
		amps += "/%.1f" % (motor.rated_current / MotorModel.SQRT3)
	var speeds: PackedStringArray = PackedStringArray()
	for n: float in motor.rated_speeds():
		speeds.append(str(roundi(n)))
	return PackedStringArray([
		"3~ Mot.   %s" % motor.designation,
		"%s %s   50 Hz" % [voltage[0], voltage[1]],
		"%s A" % amps,
		"%s kW   cos φ %.2f" % [Fuse.amperes_text(snappedf(motor.rated_power, 0.01)), motor.power_factor],
		"%s min⁻¹" % "/".join(speeds),
		"η %d %%   Ia/In %.1f" % [roundi(motor.efficiency() * 100.0), motor.start_ratio],
	])


## The rating plate in a box beside the motor (dragged like a marking).
func _draw_plate(motor: ThreePhaseMotor) -> void:
	var font: Font = AppTheme.schematic_font()
	var size: int = SchematicTheme.TERMINAL_SIZE
	var lines: PackedStringArray = plate_lines(motor)
	var width: float = 0.0
	for text: String in lines:
		width = maxf(width, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var line_height: float = font.get_height(size) + 1.0
	var box_size: Vector2 = Vector2(width + 10.0, lines.size() * line_height + 6.0)
	var local: Vector2 = Vector2(5.5 * G, 0.5 * G) if not _terminal_box() else Vector2(6.0 * G, 0.5 * G)
	if motor.kind == ThreePhaseMotor.Kind.THREE_WINDINGS:
		# Past the third winding's terminals and their names.
		local.x = 7.5 * G
	var own: Vector2 = placement.labels.get("plate", Vector2.ZERO)
	# The box hangs from its corner at that point away from the motor (to
	# the motor's right) and along it (downward), however the motor is turned.
	var t: Transform2D = SymbolGeometry.draw_transform(placement)
	var away: Vector2 = t.basis_xform(Vector2.RIGHT) + t.basis_xform(Vector2.DOWN)
	var top_left: Vector2 = to_upright(local) + own * G + Vector2(minf(away.x, 0.0) * box_size.x, minf(away.y, 0.0) * box_size.y)
	var box: Rect2 = Rect2(top_left, box_size)
	draw_set_transform_matrix(Transform2D().scaled(Vector2.ONE / _k))
	aa_rect(box, SchematicTheme.BACKGROUND)
	aa_rect(box, SchematicTheme.LINE, false, 1.0)
	aa_line(box.position + Vector2(0.0, line_height + 3.0), Vector2(box.end.x, box.position.y + line_height + 3.0), SchematicTheme.LINE, 1.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var efficiency_bad: bool = motor.efficiency() > 0.99
	for i: int in lines.size():
		var color: Color = SchematicTheme.FAULT if i == 5 and efficiency_bad else SchematicTheme.TEXT
		draw_string(font, box.position + Vector2(5.0, 3.0 + i * line_height + font.get_ascent(size)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	text_rects.append(box)
	marking_rects.append(["plate", -1, box, own])


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
