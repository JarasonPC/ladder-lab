class_name Keycap
extends RefCounted
## A key of the keyboard drawn as a small keycap (a key bound to a push button
## or switch): white with a dark edge, lit in the accent colour while its
## device is operated.

const PAPER := Color.WHITE
const INK := Color("1d1d1d")


## Size of the keycap of [param key] at [param font_size].
static func size_of(key: String, font_size: int) -> Vector2:
	var font: Font = AppTheme.bold_font()
	var h: float = font.get_height(font_size) + 4.0
	return Vector2(maxf(h, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8.0), h)


## Draws the keycap of [param key] with its top-left corner at [param at] on
## [param item]; [param lit] while its device is operated. Returns its rect.
static func draw(item: CanvasItem, at: Vector2, key: String, font_size: int, lit: bool = false) -> Rect2:
	var font: Font = AppTheme.bold_font()
	var rect: Rect2 = Rect2(at, size_of(key, font_size))
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = AppTheme.accent if lit else PAPER
	box.border_color = AppTheme.accent if lit else INK
	box.set_border_width_all(1)
	box.border_width_bottom = 2
	box.set_corner_radius_all(int(round(rect.size.y * 0.22)))
	box.anti_aliasing = true
	box.draw(item.get_canvas_item(), rect)
	var baseline: float = rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5 - 1.0
	item.draw_string(font, Vector2(rect.position.x, baseline), key, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color.WHITE if lit else INK)
	return rect
