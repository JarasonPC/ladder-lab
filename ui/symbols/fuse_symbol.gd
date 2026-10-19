class_name FuseSymbol
extends SchematicSymbol
## Fuse (IEC 60617 S00362): rectangle with the conductor running through.
## A blown fuse shows the conductor broken with a cross. A fuse holder (fuse
## disconnector, as in the guide) is drawn as a switch blade carrying the fuse,
## pivoting at the bottom terminal like the contacts; click it to open or
## close it.

const BOX := Rect2(-6, 14, 12, 32)
## Fuse holder: blade from the pivot (above the lower terminal) to the fixed
## contact (below the upper terminal); the fuse body sits in its middle.
const HOLDER_PIVOT := Vector2(0, 46)
const HOLDER_FIXED := Vector2(0, 14)
## As far from the pivot as the fixed contact: the blade keeps its length.
const HOLDER_OPEN_TIP := Vector2(-14.3, 17.4)
const HOLDER_HALF_LENGTH: float = 9.0
const HOLDER_HALF_WIDTH: float = 4.5


func flips_when_horizontal() -> bool:
	return true


func is_interactive() -> bool:
	return (component as Fuse).tripped or (component as Fuse).holder


func _draw_shape(color: Color, width: float) -> void:
	var fuse: Fuse = component as Fuse
	if fuse.holder:
		_draw_holder(self, Vector2.ZERO, 0, 1, shown("holder", 1.0 if fuse.switched_on else 0.0), fuse.tripped, color, width)
		return
	aa_line(Vector2(0, 0), Vector2(0, BOX.position.y), lead_color(0), lead_width(0))
	aa_line(Vector2(0, BOX.end.y), Vector2(0, 3 * G), lead_color(1), lead_width(1))
	aa_rect(BOX, color, false, SchematicTheme.LINE_WIDTH)
	if fuse.tripped:
		aa_line(Vector2(0, BOX.position.y), Vector2(0, 24), lead_color(0), SchematicTheme.LINE_WIDTH)
		aa_line(Vector2(0, 36), Vector2(0, BOX.end.y), lead_color(1), SchematicTheme.LINE_WIDTH)
		aa_line(Vector2(-5, 25), Vector2(5, 35), SchematicTheme.FAULT, 2.5)
		aa_line(Vector2(-5, 35), Vector2(5, 25), SchematicTheme.FAULT, 2.5)
	else:
		# The fuse element is a conductor: it shows the voltage like a lead.
		var element: Color = lead_color(0) if reach(0) != REACH_NONE else color
		aa_line(Vector2(0, BOX.position.y), Vector2(0, BOX.end.y), element, lead_width(0))


func _draw_labels() -> void:
	var anchor: Vector2 = _designation_anchor()
	draw_label(designation_text(), anchor, SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	var fuse: Fuse = component as Fuse
	draw_label(Fuse.amperes_text(fuse.rated_current) + " A", anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
	draw_heat(fuse.heat.progress, anchor, 2)
	var names: PackedStringArray = component.get_terminal_names()
	draw_label(names[0], Vector2(0.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[1], Vector2(0.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)


func _designation_anchor() -> Vector2:
	# Further out when the lower terminal is on a terminal strip: the heat
	# written under the rating would reach the strip's label.
	return Vector2(-1.4 * G if placement.strips.has(1) else -1.0 * G, 1.5 * G)


## Half the width of a fuse holder's body, measured horizontally through its
## middle (wider when the blade is open and tilted).
static func holder_half_extent(closed: float) -> float:
	var along: Vector2 = (blade_tip(HOLDER_PIVOT, HOLDER_OPEN_TIP, HOLDER_FIXED, closed) - HOLDER_PIVOT).normalized()
	var extent: float = HOLDER_HALF_WIDTH / absf(along.y)
	if absf(along.x) > 0.001:
		extent = minf(extent, HOLDER_HALF_LENGTH / absf(along.x))
	return extent


## Fuse holder pole at [param x]: the blade carries the fuse body. Shared with
## [ThreePoleFuseSymbol]. Returns the middle of the fuse body.
## [param closed] 0 open .. 1 closed (moving smoothly in between).
static func _draw_holder(symbol: SchematicSymbol, x: Vector2, top: int, bottom: int, closed: float, blown: bool, color: Color, width: float) -> Vector2:
	var g: float = SymbolGeometry.GRID
	var pivot: Vector2 = x + HOLDER_PIVOT
	var fixed_end: Vector2 = x + HOLDER_FIXED
	symbol.aa_line(x, fixed_end, symbol.lead_color(top), symbol.lead_width(top))
	symbol.aa_line(x + Vector2(0, 3 * g), pivot, symbol.lead_color(bottom), symbol.lead_width(bottom))
	# Closed, the blade runs straight on to the fixed contact.
	var tip: Vector2 = SchematicSymbol.blade_tip(pivot, x + HOLDER_OPEN_TIP, fixed_end, closed)
	var blade: Color = symbol.lead_color(bottom) if symbol.reach(bottom) != SchematicSymbol.REACH_NONE else color
	symbol.draw_blade(pivot, tip, blade, symbol.lead_width(bottom))
	# The fuse body sits on the blade.
	var along: Vector2 = (tip - pivot).normalized()
	var across: Vector2 = Vector2(-along.y, along.x)
	var middle: Vector2 = pivot.lerp(tip, 0.5)
	var half_l: float = HOLDER_HALF_LENGTH
	var half_w: float = HOLDER_HALF_WIDTH
	var corners: PackedVector2Array = PackedVector2Array([
		middle - along * half_l - across * half_w, middle + along * half_l - across * half_w,
		middle + along * half_l + across * half_w, middle - along * half_l + across * half_w,
		middle - along * half_l - across * half_w])
	symbol.aa_polygon(corners.slice(0, 4), SchematicTheme.BACKGROUND)
	symbol.aa_polyline(corners, color, SchematicTheme.LINE_WIDTH * 0.8)
	if blown:
		symbol.aa_line(middle - Vector2(5, 5), middle + Vector2(5, 5), SchematicTheme.FAULT, 2.5)
		symbol.aa_line(middle - Vector2(5, -5), middle + Vector2(5, -5), SchematicTheme.FAULT, 2.5)
	else:
		symbol.aa_line(middle - along * half_l, middle + along * half_l, blade, width)
	return middle
