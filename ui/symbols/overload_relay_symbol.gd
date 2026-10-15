class_name OverloadRelaySymbol
extends SchematicSymbol
## Thermal overload relay (IEC 60617 thermal effect, S00325 style): a box
## with the thermal square wave. Shows the overload time while it heats up and
## is filled when tripped; click to reset. With three poles its heaters are
## drawn in the power circuit: each conductor bent into the thermal mark.

const BOX := Rect2(-16, 14, 32, 32)


func is_interactive() -> bool:
	return (component as OverloadRelay).tripped


func _draw_shape(color: Color, width: float) -> void:
	var relay: OverloadRelay = component as OverloadRelay
	if relay.poles == 3:
		_draw_heaters(relay, color, width)
		return
	if relay.tripped:
		draw_rect(BOX, Color(SchematicTheme.WARNING, 0.45))
	elif relay.overloaded:
		draw_rect(BOX, Color(SchematicTheme.FAULT, 0.2))
	draw_rect(BOX, color, false, width)
	var y0: float = 36.0
	var y1: float = 24.0
	draw_polyline(PackedVector2Array([Vector2(-10, y0), Vector2(-4, y0), Vector2(-4, y1), Vector2(4, y1), Vector2(4, y0), Vector2(10, y0)]), color, SchematicTheme.LINE_WIDTH)


## Three heaters inside one box spanning the poles.
func _draw_heaters(relay: OverloadRelay, color: Color, width: float) -> void:
	var box: Rect2 = Rect2(-14, 12, 2 * SymbolGeometry.POLE_SPACING * G + 28, 36)
	if relay.tripped:
		draw_rect(box, Color(SchematicTheme.WARNING, 0.45))
	elif relay.is_heating():
		draw_rect(box, Color(SchematicTheme.FAULT, 0.2))
	# The box is the relay housing, not a conductor: never in a phase colour.
	color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	draw_rect(box, color if not relay.is_heating() else SchematicTheme.FAULT, false, SchematicTheme.LINE_WIDTH)
	for pole: int in 3:
		var x: float = pole_x(pole)
		var top: int = pole * 2
		var bottom: int = top + 1
		draw_line(Vector2(x, 0), Vector2(x, 24), lead_color(top), lead_width(top))
		draw_line(Vector2(x, 36), Vector2(x, 3 * G), lead_color(bottom), lead_width(bottom))
		var heater: Color = lead_color(top) if reach(top) != REACH_NONE else color
		var w: float = lead_width(top) if reach(top) != REACH_NONE else width
		draw_polyline(PackedVector2Array([Vector2(x, 24), Vector2(x - 7, 24), Vector2(x - 7, 36), Vector2(x, 36)]), heater, w)


func _draw_labels() -> void:
	var relay: OverloadRelay = component as OverloadRelay
	var anchor: Vector2 = Vector2(-1.1 * G, 1.5 * G)
	if relay.poles == 3:
		anchor = Vector2(-1.2 * G, 1.5 * G)
		_draw_pole_labels()
	draw_label(designation_text(), anchor, SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	var text: String = "%.1f s" % relay.trip_delay
	if relay.is_heating() and not relay.tripped:
		text = "%.1f / %.1f s" % [relay.elapsed, relay.trip_delay]
	draw_label(text, anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
