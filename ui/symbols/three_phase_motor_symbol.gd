class_name ThreePhaseMotorSymbol
extends SchematicSymbol
## Three-phase motor (IEC 60617 S00819 style): circle with "M 3~" and a lead
## per terminal. While it runs an arrow turns around it in its direction of
## rotation, faster at higher speeds; Y / Δ or the speed step is written
## beside it, a phase loss or wrong connection in the fault colour. The PE
## terminal of the frame is below left, as in the guide.

const CENTER := Vector2(2.0 * G, 2.0 * G)
const RADIUS: float = 26.0

var _angle: float = 0.0


func _process(delta: float) -> void:
	var motor: ThreePhaseMotor = component as ThreePhaseMotor
	if motor.is_running():
		var turn: float = 1.0 if motor.direction == ThreePhaseMotor.Direction.CLOCKWISE else -1.0
		_angle = fmod(_angle + turn * delta * TAU * maxf(motor.speed, 1), TAU)
		queue_redraw()


func _designation_anchor() -> Vector2:
	return Vector2(-1.4 * G, 1.2 * G)


func _draw_shape(color: Color, width: float) -> void:
	var motor: ThreePhaseMotor = component as ThreePhaseMotor
	var names: PackedStringArray = motor.get_terminal_names()
	var windings: int = motor.winding_terminal_count()
	# PE: from the frame to the left, then down to its terminal.
	var pe_cell: Vector2 = Vector2(SymbolGeometry.MOTOR_PE_CELL) * G
	var frame: Vector2 = CENTER + Vector2.from_angle(PI * 0.88) * RADIUS
	draw_polyline(PackedVector2Array([frame, Vector2(pe_cell.x, frame.y), pe_cell]), lead_color(windings), lead_width(windings))
	for i: int in windings:
		var cell: Vector2 = Vector2(SymbolGeometry.motor_terminal_cell(i)) * G
		var angle: float
		var bend: Vector2
		if i < 3:
			angle = -PI * 0.5 + (i - 1) * PI * 0.25
			bend = cell + Vector2(0, 0.4 * G)
		elif i < 6:
			angle = PI * 0.5 - (i - 4) * PI * 0.25
			bend = cell - Vector2(0, 0.4 * G)
		else:
			angle = (i - 7) * PI * 0.2
			bend = cell - Vector2(0.6 * G, 0)
		var edge: Vector2 = CENTER + Vector2.from_angle(angle) * RADIUS
		draw_polyline(PackedVector2Array([cell, bend, edge]), lead_color(i), lead_width(i))
	var fill: Color = SchematicTheme.COIL_ON if motor.is_running() else SchematicTheme.BACKGROUND
	if motor.state == ThreePhaseMotor.State.PHASE_LOSS or motor.state == ThreePhaseMotor.State.MISWIRED:
		fill = Color(SchematicTheme.FAULT, 0.25)
	draw_circle(CENTER, RADIUS, fill)
	# The housing is drawn plain; the leads show the phases.
	color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	draw_arc(CENTER, RADIUS, 0.0, TAU, 40, color, SchematicTheme.LINE_WIDTH if not motor.is_running() else width)
	if motor.is_running():
		var r: float = RADIUS + 6.0
		var arc: float = PI * 0.6
		var turn: float = 1.0 if motor.direction == ThreePhaseMotor.Direction.CLOCKWISE else -1.0
		var start: float = _angle
		if placement.mirrored:
			# Drawn mirrored: mirror the angle too, so the arrow turns the same way on screen.
			start = PI - _angle
			turn = -turn
		draw_arc(CENTER, r, start, start + turn * arc, 12, SchematicTheme.LINE, 2.0)
		var end_angle: float = start + turn * arc
		var tip: Vector2 = CENTER + Vector2.from_angle(end_angle) * r
		var forward: Vector2 = Vector2.from_angle(end_angle + turn * PI * 0.5)
		var side: Vector2 = Vector2.from_angle(end_angle)
		draw_colored_polygon(PackedVector2Array([tip + forward * 7.0, tip - side * 4.5, tip + side * 4.5]), SchematicTheme.LINE)


func _draw_labels() -> void:
	var motor: ThreePhaseMotor = component as ThreePhaseMotor
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	var names: PackedStringArray = motor.get_terminal_names()
	var windings: int = motor.winding_terminal_count()
	draw_label(names[windings], Vector2(SymbolGeometry.MOTOR_PE_CELL) * G + Vector2(-0.3 * G, 0.3 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	for i: int in windings:
		var cell: Vector2 = Vector2(SymbolGeometry.motor_terminal_cell(i)) * G
		var offset: Vector2 = Vector2(0.3 * G, 0.4 * G)
		if i >= 3 and i < 6:
			offset = Vector2(0.3 * G, -0.4 * G)
		elif i >= 6:
			offset = Vector2(-0.3 * G, -0.3 * G)
		draw_label(names[i], cell + offset, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	var font: Font = AppTheme.schematic_font()
	var c: Vector2 = to_upright(CENTER)
	_centered(font, "M3~", c, 15, SchematicTheme.TEXT)
	var status: String = ""
	var status_color: Color = SchematicTheme.TEXT
	match motor.state:
		ThreePhaseMotor.State.STAR:
			status = "Y"
		ThreePhaseMotor.State.DELTA:
			status = "Δ"
		ThreePhaseMotor.State.PHASE_LOSS:
			status = tr("phase loss")
			status_color = SchematicTheme.FAULT
		ThreePhaseMotor.State.MISWIRED:
			status = tr("miswired")
			status_color = SchematicTheme.FAULT
		ThreePhaseMotor.State.RUNNING:
			if motor.speed > 0:
				status = tr("speed %d") % motor.speed
	if not status.is_empty():
		draw_label(status, _designation_anchor(), SchematicTheme.TERMINAL_SIZE, status_color, 1)


func _centered(font: Font, text: String, at: Vector2, size: int, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, at + Vector2(-w * 0.5, font.get_ascent(size) * 0.5 - 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
