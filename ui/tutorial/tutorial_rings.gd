class_name TutorialRings
extends Control
## Pulsing rings round controls of the window a lesson points at (a palette
## entry, Simulate), drawn over the interface without taking any input.

## Callables returning the global rectangle to ring, or an empty one while
## there is nothing to ring.
var targets: Array[Callable] = []:
	set(value):
		targets = value
		queue_redraw()
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if targets.is_empty():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * TAU / 1.6)
	for target: Callable in targets:
		var r: Rect2 = target.call() if target.is_valid() else Rect2()
		if not r.has_area():
			continue
		r = Rect2(r.position - global_position, r.size).grow(3.0)
		draw_style_box(_ring(Color(AppTheme.tutorial, 0.4 * (1.0 - pulse)), 3.0), r.grow(2.0 + 6.0 * pulse))
		draw_style_box(_ring(AppTheme.tutorial, 2.0), r)


static func _ring(color: Color, width: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(int(ceilf(width)))
	box.set_corner_radius_all(AppTheme.RADIUS + 3)
	box.anti_aliasing = true
	return box
