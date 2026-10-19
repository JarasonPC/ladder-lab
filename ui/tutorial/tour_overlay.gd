class_name TourOverlay
extends Control
## The interface tour: the window dimmed but for the control a step is
## about, ringed in the tutorial colour, and a card beside it saying what it
## is for, with Back, Next and Skip tour. Clicks outside the ringed control
## are held back, inside it they go through, so a step can wait for the
## control to be used (Next does it instead). Esc leaves the tour.

## The tour ended: [param completed] after its last step, else left early.
signal finished(completed: bool)

## Room round the ringed control, in pixels.
const HOLE_GAP: float = 6.0
const CARD_WIDTH: float = 360.0
## Room between the card and the ringed control.
const CARD_GAP: float = 16.0
const MARGIN: float = 12.0
const DIM := Color(0.02, 0.03, 0.05, 0.62)


## One stop of the tour.
class Step:
	extends RefCounted
	var title: String = ""
	var text: String = ""
	## The global rectangle of the control shown, or an empty one: the card
	## alone, in the middle.
	var target: Callable = Callable()
	## Run when the step is shown (e.g. the schematic brought to the front).
	var prepare: Callable = Callable()
	## While it returns false the step waits for the control to be used:
	## the card says so, and Next runs [member act] first.
	var waits: Callable = Callable()
	var act: Callable = Callable()
	## English source text saying what to click on a step that waits.
	var waiting: String = ""


var steps: Array[Step] = []
var index: int = 0

var _hole: Rect2 = Rect2()
var _card: PanelContainer
var _step_label: Label
var _title: Label
var _text: Label
var _waiting_box: PanelContainer
var _waiting: Label
var _dots: Control
var _back: Button
var _next: Button
var _skip: Button
var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card = PanelContainer.new()
	_card.theme_type_variation = "TourCard"
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	add_child(_card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_card.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	_step_label = _label(head, "TutorialLabel")
	_step_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_step_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_step_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dots = Control.new()
	_dots.custom_minimum_size = Vector2(0, 16)
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dots.draw.connect(_draw_dots)
	head.add_child(_dots)
	var close: Button = Button.new()
	close.theme_type_variation = "ToolButton"
	close.focus_mode = Control.FOCUS_NONE
	close.icon = AppTheme.icon("close", 16)
	close.pressed.connect(func() -> void: stop(false))
	head.add_child(close)
	_title = _label(column, "TitleLabel")
	_title.add_theme_font_size_override("font_size", 18)
	_text = _label(column, "")
	_waiting_box = PanelContainer.new()
	_waiting_box.theme_type_variation = "HintBox"
	column.add_child(_waiting_box)
	_waiting = _label(_waiting_box, "")
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	column.add_child(spacer)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	column.add_child(foot)
	_skip = _button(foot, "")
	_skip.pressed.connect(func() -> void: stop(false))
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	_back = _button(foot, "")
	_back.pressed.connect(func() -> void: show_step(index - 1))
	_next = _button(foot, "TutorialButton")
	_next.pressed.connect(_on_next)
	hide()


## Starts the tour at its first step.
func start() -> void:
	show()
	show_step(0)


## Ends the tour; [param completed] when its last step was reached.
func stop(completed: bool) -> void:
	if not visible:
		return
	hide()
	finished.emit(completed)


func show_step(at: int) -> void:
	if steps.is_empty():
		return
	index = clampi(at, 0, steps.size() - 1)
	var s: Step = steps[index]
	if s.prepare.is_valid():
		s.prepare.call()
	retranslate()
	_time = 0.0


## Sets the texts of the step shown (also when the language changes).
func retranslate() -> void:
	if steps.is_empty():
		return
	var s: Step = steps[index]
	_step_label.text = (tr("Step %d of %d") % [index + 1, steps.size()]).to_upper()
	_title.text = tr(s.title)
	_text.text = tr(s.text)
	_waiting.text = tr(s.waiting)
	_skip.text = tr("Skip tour")
	_back.text = tr("Back")
	_back.visible = index > 0
	_next.text = tr("Done") if index == steps.size() - 1 else tr("Next")
	_update_waiting()
	_dots.queue_redraw()


func _update_waiting() -> void:
	var s: Step = steps[index]
	_waiting_box.visible = s.waits.is_valid() and not bool(s.waits.call()) and not s.waiting.is_empty()


func _on_next() -> void:
	var s: Step = steps[index]
	if s.waits.is_valid() and not bool(s.waits.call()) and s.act.is_valid():
		s.act.call()
	if index == steps.size() - 1:
		stop(true)
	else:
		show_step(index + 1)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		stop(false)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or steps.is_empty():
		return
	_time += delta
	var s: Step = steps[index]
	var target: Rect2 = s.target.call() if s.target.is_valid() else Rect2()
	_hole = Rect2(target.position - global_position, target.size).grow(HOLE_GAP) if target.has_area() else Rect2()
	_update_waiting()
	_place_card()
	queue_redraw()


## Beside the ringed control: under it, else over it, right or left of it,
## always inside the window; in the middle when nothing is ringed.
func _place_card() -> void:
	_card.size = Vector2(CARD_WIDTH, 0.0)
	var card: Vector2 = _card.get_combined_minimum_size()
	card.x = maxf(card.x, CARD_WIDTH)
	var room: Rect2 = Rect2(Vector2.ZERO, size).grow(-MARGIN)
	var at: Vector2 = (size - card) * 0.5
	if _hole.has_area():
		var below: Vector2 = Vector2(_hole.get_center().x - card.x * 0.5, _hole.end.y + CARD_GAP)
		var above: Vector2 = Vector2(below.x, _hole.position.y - CARD_GAP - card.y)
		var right: Vector2 = Vector2(_hole.end.x + CARD_GAP, _hole.get_center().y - card.y * 0.5)
		var left: Vector2 = Vector2(_hole.position.x - CARD_GAP - card.x, right.y)
		for spot: Vector2 in [below, above, right, left]:
			var fitted: Vector2 = spot.clamp(room.position, room.end - card)
			if not Rect2(fitted, card).intersects(_hole):
				at = fitted
				break
	_card.position = at.clamp(room.position, (room.end - card).max(room.position))
	_card.size = card


## Clicks inside the ringed control go through to it.
func _has_point(point: Vector2) -> bool:
	return not _hole.has_point(point)


func _draw() -> void:
	var full: Rect2 = Rect2(Vector2.ZERO, size)
	if not _hole.has_area():
		draw_rect(full, DIM)
		return
	var h: Rect2 = _hole
	draw_rect(Rect2(0, 0, size.x, h.position.y), DIM)
	draw_rect(Rect2(0, h.end.y, size.x, size.y - h.end.y), DIM)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), DIM)
	draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), DIM)
	# Rounded corners of the hole: the dim fills what the arcs leave out.
	var radius: float = minf(10.0, minf(h.size.x, h.size.y) * 0.5)
	var corners: Array[Vector2] = [h.position, Vector2(h.end.x, h.position.y), h.end, Vector2(h.position.x, h.end.y)]
	var centres: Array[Vector2] = [h.position + Vector2(radius, radius), Vector2(h.end.x - radius, h.position.y + radius), h.end - Vector2(radius, radius), Vector2(h.position.x + radius, h.end.y - radius)]
	for k: int in 4:
		var points: PackedVector2Array = PackedVector2Array([corners[k]])
		for i: int in 9:
			var a: float = PI + k * PI * 0.5 + i * PI / 16.0
			points.append(centres[k] + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(points, DIM)
	var pulse: float = 0.5 + 0.5 * sin(_time * TAU / 1.6)
	draw_style_box(TutorialRings._ring(Color(AppTheme.tutorial, 0.45 * (1.0 - pulse)), 3.0), h.grow(2.0 + 6.0 * pulse))
	draw_style_box(TutorialRings._ring(AppTheme.tutorial, 3.0), h)


func _draw_dots() -> void:
	var y: float = _dots.size.y * 0.5
	var x: float = 10.0
	for i: int in steps.size():
		var w: float = 16.0 if i == index else 6.0
		var dot: StyleBoxFlat = StyleBoxFlat.new()
		dot.bg_color = AppTheme.tutorial if i <= index else AppTheme.border_strong
		dot.set_corner_radius_all(3)
		dot.anti_aliasing = true
		_dots.draw_style_box(dot, Rect2(x, y - 3.0, w, 6.0))
		x += w + 4.0


func _label(parent: Control, variation: String) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _button(parent: Control, variation: String) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.theme_type_variation = variation
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button
