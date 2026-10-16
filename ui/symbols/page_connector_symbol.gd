class_name PageConnectorSymbol
extends SchematicSymbol
## Page connector: the wire leaves the page into a tag, its point on the
## wire and its flat end away from it. Beside the tag its label (the wire
## number of the link) and, below, where the wire continues ("/2.4": page 2,
## current path 4).

## Outline of the tag, drawn upward from the terminal (local pixels).
const TAG: Array[Vector2] = [Vector2(0, -8), Vector2(6, -14), Vector2(6, -25), Vector2(-6, -25), Vector2(-6, -14), Vector2(0, -8)]
## Local point beside the tag where the label is written.
const LABEL_ANCHOR := Vector2(0.55 * G, -0.8 * G)

## Cross reference written below the label, set by the view (see
## [method SchematicDocument.connector_reference]).
var reference: String = ""


func _draw_shape(_color: Color, _width: float) -> void:
	var line: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
	aa_line(Vector2.ZERO, Vector2(0, -8), lead_color(0), lead_width(0))
	var tag: PackedVector2Array = PackedVector2Array(TAG)
	aa_polygon(tag, SchematicTheme.BACKGROUND)
	aa_polyline(tag, line, SchematicTheme.LINE_WIDTH * 0.8)


func _draw_labels() -> void:
	var label: String = (component as PageConnector).label
	draw_label(label if not label.is_empty() else "?", LABEL_ANCHOR, SchematicTheme.LABEL_SIZE, SchematicTheme.WIRE_NUMBER, 0, ["label", -1])
	if not reference.is_empty():
		# Moves along with the label when that is dragged.
		draw_label(reference, LABEL_ANCHOR, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT, 1, ["label", -1])


## While simulating, a click shows the page the wire continues on.
func is_interactive() -> bool:
	return not reference.is_empty()
