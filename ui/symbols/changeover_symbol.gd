class_name ChangeoverSymbol
extends SchematicSymbol
## Changeover contact (IEC 60617 S00230), drawn like the other contacts:
## common terminal at the bottom with the pivot, NO fixed contact straight
## above it, NC fixed contact one cell to the right with its stop. The blade
## rests against the NC stop and swings to the NO contact.

const PIVOT := Vector2(0, 40)
const NO_END := Vector2(0, 20)
const NC_TIP := Vector2(10, 18)
const NO_TIP := Vector2(-3, 20)


func _designation_anchor() -> Vector2:
	var delayed: bool = (component as ChangeoverContact).delayed
	return Vector2(-1.9 * G if delayed else -1.3 * G, 1.5 * G)


func _draw_shape(color: Color, _width: float) -> void:
	var contact: ChangeoverContact = component as ChangeoverContact
	# Terminal order: common (0, bottom), NC side (1, top right), NO side (2, top).
	aa_line(Vector2(0, 3 * G), PIVOT, lead_color(0), lead_width(0))
	aa_line(Vector2(0, 0), NO_END, lead_color(2), lead_width(2))
	aa_line(Vector2(G, 0), Vector2(G, 20), lead_color(1), lead_width(1))
	aa_line(Vector2(G, 20), Vector2(9, 20), lead_color(1), lead_width(1))
	# Heading for the NO side (1) or resting on the NC side (0), moving smoothly.
	var target: float = contact.get_travel()
	if contact.is_path_closed(ChangeoverContact.PATH_NO):
		target = 1.0
	elif contact.is_path_closed(ChangeoverContact.PATH_NC):
		target = 0.0
	var tip: Vector2 = NC_TIP.lerp(NO_TIP, shown("blade", target))
	draw_blade(PIVOT, tip, lead_color(0), lead_width(0))
	if contact.delayed:
		# The delay mark is fixed to the blade and turns with it.
		var mark: Color = SchematicTheme.WARNING if warning else SchematicTheme.LINE
		var turn: float = (tip - PIVOT).angle() - (NC_TIP - PIVOT).angle()
		ContactSymbol.draw_delay_mark(self, PIVOT.lerp(NC_TIP, 0.5), mark, PIVOT, turn)


func _draw_labels() -> void:
	draw_label(designation_text(), _designation_anchor(), SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	var names: PackedStringArray = component.get_terminal_names()
	draw_label(names[0], Vector2(0.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[2], Vector2(-0.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[1], Vector2(1.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
