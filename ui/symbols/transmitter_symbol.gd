class_name TransmitterSymbol
extends TemperatureSensorSymbol
## Pressure, level or flow transmitter: the box of the temperature sensor
## holding the instrument circle of what it measures ("PT", "LT", "FT" as on
## a P&I diagram, ČSN EN 62424) with an arrow to the voltage U it puts out;
## supply 1 (L+) on top, 3 (M) below, the output 2 on top beside 1, the
## colours of the cores (BN, BU, WH) beside the leads. The palette shows the
## circle and the arrow to U.

const BUBBLE_CENTER := Vector2(6.0, 30.0)
const BUBBLE_RADIUS: float = 9.5
const ARROW_FROM := Vector2(18.0, 30.0)
const ARROW_TO := Vector2(34.0, 30.0)
## Letters of the instrument by quantity.
const TAGS: PackedStringArray = ["PT", "LT", "FT"]


func _draw_element(color: Color, width: float) -> void:
	aa_circle(BUBBLE_CENTER, BUBBLE_RADIUS, color, false, width)
	aa_line(ARROW_FROM, ARROW_TO, color, width)
	aa_polyline(PackedVector2Array([ARROW_TO + Vector2(-4.0, -3.5), ARROW_TO, ARROW_TO + Vector2(-4.0, 3.5)]), color, width)


func _draw_element_labels() -> void:
	var transmitter: Transmitter = component as Transmitter
	_centered(TAGS[transmitter.quantity], BUBBLE_CENTER, 8)
	# The colours of the cores beside the leads, away from the terminal numbers.
	var out_x: float = SymbolGeometry.SENSOR_OUTPUT_CELL.x * G
	var at: Array[Vector2] = [Vector2(-0.6 * G, 0.4 * G), Vector2(-0.6 * G, 2.6 * G), Vector2(out_x - 0.6 * G, 0.4 * G)]
	for i: int in 3:
		var colour: String = transmitter.core_colour(i)
		if not colour.is_empty() and not placement.strips.has(i):
			_centered(colour, at[i], SchematicTheme.TERMINAL_SIZE - 1)


func _draw_preview(color: Color, width: float) -> void:
	aa_rect(PREVIEW_BOX, color, false, width)
	aa_circle(Vector2(26.0, 25.0), 14.0, color, false, width)
	aa_line(Vector2(46.0, 25.0), Vector2(64.0, 25.0), color, width)
	aa_polyline(PackedVector2Array([Vector2(58.0, 19.0), Vector2(64.0, 25.0), Vector2(58.0, 31.0)]), color, width)
	draw_preview_text(TAGS[(component as Transmitter).quantity], Vector2(26.0, 25.0), 12)
	draw_preview_text("U", Vector2(80.0, 25.0), 28)


func _designation_anchor() -> Vector2:
	# Clear of the colour of the lower core.
	return Vector2(-1.6 * G if placement.strips.has(1) else -1.4 * G, 1.5 * G)
