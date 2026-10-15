class_name CoilSymbol
extends SchematicSymbol
## Relay / contactor coil (IEC 60617 S00305). Time relays get the extra box of
## S00312 (on-delay, crossed) or S00311 (off-delay, filled).

const BOX := Rect2(-14, 20, 28, 20)
const TIMER_BOX := Rect2(-28, 20, 14, 20)


func _draw_shape(color: Color, width: float) -> void:
	var coil: Coil = component as Coil
	draw_line(Vector2(0, 0), Vector2(0, BOX.position.y), lead_color(0), lead_width(0))
	draw_line(Vector2(0, BOX.end.y), Vector2(0, 3 * G), lead_color(1), lead_width(1))
	if coil.energized:
		draw_rect(BOX, SchematicTheme.COIL_ON)
	draw_rect(BOX, color, false, width)
	if coil is TimerRelay:
		var timer: TimerRelay = coil as TimerRelay
		if timer.energized:
			draw_rect(TIMER_BOX, SchematicTheme.COIL_ON)
		draw_rect(TIMER_BOX, color, false, width)
		if timer.mode == TimerRelay.Mode.ON_DELAY:
			draw_line(TIMER_BOX.position, TIMER_BOX.end, color, SchematicTheme.LINE_WIDTH * 0.75)
			draw_line(Vector2(TIMER_BOX.position.x, TIMER_BOX.end.y), Vector2(TIMER_BOX.end.x, TIMER_BOX.position.y), color, SchematicTheme.LINE_WIDTH * 0.75)
		else:
			draw_rect(TIMER_BOX.grow(-3.0), color)


func _draw_labels() -> void:
	var anchor: Vector2 = Vector2(-1.8 * G, 1.5 * G)
	draw_label(designation_text(), anchor, SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	var names: PackedStringArray = component.get_terminal_names()
	draw_label(names[0], Vector2(0.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[1], Vector2(0.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	if component is TimerRelay:
		var timer: TimerRelay = component as TimerRelay
		var remaining: float = timer.get_remaining()
		var text: String = "%.1f / %.1f s" % [remaining, timer.delay] if remaining > 0.0 else "%.1f s" % timer.delay
		draw_label(text, anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
