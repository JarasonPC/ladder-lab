class_name CoilSymbol
extends SchematicSymbol
## Relay / contactor coil (IEC 60617 S00305). Time relays get the extra box of
## S00312 (on-delay, crossed) or S00311 (off-delay, filled); the other
## functions of a multifunction relay show their code (F1-F9) in that box, which
## is filled while the output R is on. A control input S enters from the top
## right. A band across the left end of a coil's box shows the supply it is
## rated for: "~" AC, "⎓" DC (none without a rating, nor on time relays);
## lying horizontally as in the palette, it is the top of the box.

const BOX := Rect2(-14, 20, 28, 20)
const TIMER_BOX := Rect2(-28, 20, 14, 20)
## Band of the AC / DC mark at the left end of the box.
const SUPPLY_BAND := Rect2(-14, 20, 8, 20)


func _draw_shape(color: Color, width: float) -> void:
	var coil: Coil = component as Coil
	aa_line(Vector2(0, 0), Vector2(0, BOX.position.y), lead_color(0), lead_width(0))
	aa_line(Vector2(0, BOX.end.y), Vector2(0, 3 * G), lead_color(1), lead_width(1))
	if coil.energized:
		aa_rect(BOX, SchematicTheme.COIL_ON)
	aa_rect(BOX, color, false, width)
	if VoltageRating.TABLE.has(coil.rating) and not coil is TimerRelay:
		_draw_supply_mark(VoltageRating.kind(coil.rating), color, width)
	if coil is TimerRelay:
		var timer: TimerRelay = coil as TimerRelay
		if timer.output:
			aa_rect(TIMER_BOX, SchematicTheme.COIL_ON)
		aa_rect(TIMER_BOX, color, false, width)
		match timer.mode:
			TimerRelay.Mode.ON_DELAY:
				aa_line(TIMER_BOX.position, TIMER_BOX.end, color, SchematicTheme.LINE_WIDTH * 0.75)
				aa_line(Vector2(TIMER_BOX.position.x, TIMER_BOX.end.y), Vector2(TIMER_BOX.end.x, TIMER_BOX.position.y), color, SchematicTheme.LINE_WIDTH * 0.75)
			TimerRelay.Mode.OFF_DELAY:
				aa_rect(TIMER_BOX.grow(-3.0), color)
		if timer.control_input and component.get_terminal_names().size() > 2:
			# Control input S: from its terminal down into the coil box.
			var s: Vector2 = Vector2(G, 0)
			aa_polyline(PackedVector2Array([s, Vector2(G, 10), Vector2(8, 10), Vector2(8, BOX.position.y)]), lead_color(2), lead_width(2))


## The band and its mark: a sine wave for AC, a line over three dashes for
## DC, both along the band.
func _draw_supply_mark(kind: VoltageRating.Kind, color: Color, width: float) -> void:
	var band: Rect2 = SUPPLY_BAND
	aa_line(Vector2(band.end.x, band.position.y), band.end, color, width)
	var mid: float = band.get_center().x
	var top: float = band.position.y + 3.5
	var length: float = band.size.y - 7.0
	if kind == VoltageRating.Kind.DC:
		aa_line(Vector2(mid - 1.5, top), Vector2(mid - 1.5, top + length), color, 1.5)
		for i: int in 3:
			var y: float = top + i * length * 0.4
			aa_line(Vector2(mid + 1.8, y), Vector2(mid + 1.8, y + length * 0.2), color, 1.5)
		return
	var wave: PackedVector2Array = PackedVector2Array()
	for i: int in 17:
		var f: float = i / 16.0
		wave.append(Vector2(mid - 2.2 * sin(f * TAU), top + f * length))
	aa_polyline(wave, color, 1.5)


func _draw_labels() -> void:
	var anchor: Vector2 = Vector2(-1.8 * G, 1.5 * G)
	draw_label(designation_text(), anchor, SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	var names: PackedStringArray = component.get_terminal_names()
	# With a control input S on the right, A1 is labelled on the left.
	var a1_x: float = -0.35 * G if names.size() > 2 else 0.35 * G
	draw_label(names[0], Vector2(a1_x, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[1], Vector2(0.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_rating(anchor, 2 if component is TimerRelay else 1)
	if component is TimerRelay:
		var timer: TimerRelay = component as TimerRelay
		var remaining: float = timer.get_remaining()
		var text: String = "%.1f / %.1f s" % [remaining, timer.delay] if remaining > 0.0 else "%.1f s" % timer.delay
		if remaining <= 0.0 and TimerRelay.uses_two_times(timer.mode):
			text = "%.1f s · %.1f s" % [timer.delay, timer.delay2]
		draw_label(text, anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
		var code: String = TimerRelay.code_of(timer.mode)
		if timer.mode != TimerRelay.Mode.ON_DELAY and not code.is_empty():
			var font: Font = AppTheme.schematic_font()
			var size: int = 9
			var w: float = font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var c: Vector2 = to_upright(TIMER_BOX.get_center())
			draw_string(font, c + Vector2(-w * 0.5, font.get_ascent(size) * 0.5 - 1.0), code, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SchematicTheme.TEXT)
		if names.size() > 2:
			draw_label(names[2], Vector2(1.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
