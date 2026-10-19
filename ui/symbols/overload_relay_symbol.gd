class_name OverloadRelaySymbol
extends SchematicSymbol
## Thermal overload relay (IEC 60617 thermal effect, S00325 style): a box
## with the thermal square wave. Shows its current setting (three poles) or
## trip delay and how far it has heated up, and is filled when tripped; a
## click trips it (test button) or resets it. With three poles its heaters are
## drawn in the power circuit: each conductor bent into the thermal mark.

const BOX := Rect2(-16, 14, 32, 32)
## Housing of the three heaters, low enough to leave the terminal numbers
## above and below it clear.
const HEATER_BOX := Rect2(-14, 15, 2 * SymbolGeometry.POLE_SPACING * G + 28, 30)


func is_interactive() -> bool:
	return true


func _draw_shape(color: Color, width: float) -> void:
	var relay: OverloadRelay = component as OverloadRelay
	if relay.poles == 3:
		_draw_heaters(relay, color, width)
		return
	if relay.tripped:
		aa_rect(BOX, Color(SchematicTheme.WARNING, 0.45))
	elif relay.overloaded:
		aa_rect(BOX, Color(SchematicTheme.FAULT, 0.2))
	aa_rect(BOX, color, false, width)
	var y0: float = 36.0
	var y1: float = 24.0
	aa_polyline(PackedVector2Array([Vector2(-10, y0), Vector2(-4, y0), Vector2(-4, y1), Vector2(4, y1), Vector2(4, y0), Vector2(10, y0)]), color, SchematicTheme.LINE_WIDTH)


## Three heaters inside one box spanning the poles.
func _draw_heaters(relay: OverloadRelay, color: Color, width: float) -> void:
	var box: Rect2 = HEATER_BOX
	if relay.tripped:
		aa_rect(box, Color(SchematicTheme.WARNING, 0.45))
	elif relay.is_heating():
		aa_rect(box, Color(SchematicTheme.FAULT, 0.2))
	# The box is the relay housing, not a conductor: never in a phase colour.
	color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	aa_rect(box, color if not relay.is_heating() else SchematicTheme.FAULT, false, SchematicTheme.LINE_WIDTH)
	for pole: int in 3:
		var x: float = pole_x(pole)
		var top: int = pole * 2
		var bottom: int = top + 1
		aa_line(Vector2(x, 0), Vector2(x, 24), lead_color(top), lead_width(top))
		aa_line(Vector2(x, 36), Vector2(x, 3 * G), lead_color(bottom), lead_width(bottom))
		var heater: Color = lead_color(top) if reach(top) != REACH_NONE else color
		var w: float = lead_width(top) if reach(top) != REACH_NONE else width
		aa_polyline(PackedVector2Array([Vector2(x, 24), Vector2(x - 7, 24), Vector2(x - 7, 36), Vector2(x, 36)]), heater, w)


func _draw_labels() -> void:
	var relay: OverloadRelay = component as OverloadRelay
	var anchor: Vector2 = Vector2(-1.1 * G, 1.5 * G)
	if relay.poles == 3:
		# Further out when terminal 2 is on a terminal strip, clear of the
		# strip's label.
		anchor = Vector2(-1.4 * G if placement.strips.has(1) else -1.2 * G, 1.5 * G)
		_draw_pole_labels(true)
	draw_label(designation_text(), anchor, SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	if relay.poles == 3:
		# The current setting, then how far it has heated up.
		draw_label("Ir %s A" % Fuse.amperes_text(relay.setting), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
		if relay.overloaded and not relay.tripped:
			draw_label("%.1f / %.1f s" % [relay.elapsed, relay.trip_delay], anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.FAULT, 2)
		else:
			draw_heat(relay.heat.progress, anchor, 2)
		return
	var text: String = "%.1f s" % relay.trip_delay
	if relay.is_heating() and not relay.tripped:
		text = "%.1f / %.1f s" % [relay.elapsed, relay.trip_delay]
	draw_label(text, anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
