class_name MotorSymbol
extends SchematicSymbol
## Motor (IEC 60617 S00819 style): circle with "M". Spins while energized.

const CENTER := Vector2(0, 30)
const RADIUS: float = 14.0

var _angle: float = 0.0


func _process(delta: float) -> void:
	super(delta)
	if (component as Load).energized:
		_angle = fmod(_angle + delta * TAU, TAU)


func _draw_shape(color: Color, width: float) -> void:
	aa_line(Vector2(0, 0), Vector2(0, CENTER.y - RADIUS), lead_color(0), lead_width(0))
	aa_line(Vector2(0, CENTER.y + RADIUS), Vector2(0, 3 * G), lead_color(1), lead_width(1))
	aa_arc(CENTER, RADIUS, 0.0, TAU, 32, color, width)
	if (component as Load).energized:
		# Close round the housing, inside the terminal names.
		var r: float = RADIUS + 3.5
		aa_arc(CENTER, r, _angle, _angle + PI * 0.6, 10, color, 2.0)
		var tip: Vector2 = CENTER + Vector2.from_angle(_angle + PI * 0.6) * r
		aa_circle(tip, 2.5, color)
	if preview:
		draw_preview_text("M", CENTER, 16)


func _draw_labels() -> void:
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	var names: PackedStringArray = component.get_terminal_names()
	draw_label(names[0], name_anchor(0, Vector2(0.35 * G, 0.4 * G)), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[1], name_anchor(1, Vector2(0.35 * G, 2.6 * G)), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	var font: Font = AppTheme.schematic_font()
	var c: Vector2 = to_upright(CENTER)
	var size: int = 16
	var w: float = font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, c + Vector2(-w * 0.5, font.get_ascent(size) * 0.5 - 1.0), "M", HORIZONTAL_ALIGNMENT_LEFT, -1, size, SchematicTheme.TEXT)
