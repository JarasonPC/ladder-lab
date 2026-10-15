class_name OverloadRelaySymbol
extends SchematicSymbol
## Thermal overload relay (IEC 60617 thermal effect, S00325 style): a box
## with the thermal square wave. Shows the overload time while it heats up and
## is filled when tripped; click to reset.

const BOX := Rect2(-16, 14, 32, 32)


func is_interactive() -> bool:
	return (component as OverloadRelay).tripped


func _draw_shape(color: Color, width: float) -> void:
	var relay: OverloadRelay = component as OverloadRelay
	if relay.tripped:
		draw_rect(BOX, Color(SchematicTheme.WARNING, 0.45))
	elif relay.overloaded:
		draw_rect(BOX, Color(SchematicTheme.FAULT, 0.2))
	draw_rect(BOX, color, false, width)
	var y0: float = 36.0
	var y1: float = 24.0
	draw_polyline(PackedVector2Array([Vector2(-10, y0), Vector2(-4, y0), Vector2(-4, y1), Vector2(4, y1), Vector2(4, y0), Vector2(10, y0)]), color, SchematicTheme.LINE_WIDTH)


func _draw_labels() -> void:
	var relay: OverloadRelay = component as OverloadRelay
	var anchor: Vector2 = Vector2(-1.1 * G, 1.5 * G)
	draw_label(component.designation, anchor, SchematicTheme.LABEL_SIZE, SchematicTheme.TEXT)
	var text: String = "%.1f s" % relay.trip_delay
	if relay.overloaded and not relay.tripped:
		text = "%.1f / %.1f s" % [relay.elapsed, relay.trip_delay]
	draw_label(text, anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
