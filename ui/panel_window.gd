class_name PanelWindow
extends Window
## A side panel (control panel, switchboard) in a window of its own, e.g. on
## a second monitor. The panel itself moves here from its [SideBar], which
## stays hidden meanwhile, and goes back when the window is closed, so it
## works here as it does beside the schematic. Ctrl+wheel zooms it; keys the
## panel does not use go to the main window's shortcuts.

## A key was pressed in this window (the main window handles the shortcuts).
signal key_pressed(event: InputEventKey)
## The window is closing; its panel is back in its side bar.
signal closing

var bar: SideBar
var _default_size: Vector2


## A window showing the panel of [param p_bar], [param p_size] large.
func _init(p_bar: SideBar, p_size: Vector2) -> void:
	bar = p_bar
	_default_size = p_size
	visible = false
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	min_size = Vector2i(320, 240)


func _ready() -> void:
	size = Vector2i(_default_size * content_scale_factor)
	var zoom_box: ZoomBox = ZoomBox.new()
	zoom_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(zoom_box)
	zoom_box.add_child(bar.detach())
	zoom_box.zoom = bar.zoom
	var keys: _Keys = _Keys.new()
	keys.window = self
	add_child(keys)
	close_requested.connect(put_back)
	retranslate()
	show()


## Puts the panel back beside the schematic and closes the window.
func put_back() -> void:
	if is_queued_for_deletion():
		return
	bar.attach()
	closing.emit()
	queue_free()


func retranslate() -> void:
	title = "%s – LadderLab" % bar.title


## Passes on the keys nothing in the window used (text fields keep theirs).
class _Keys extends Node:
	var window: PanelWindow

	func _unhandled_input(event: InputEvent) -> void:
		var key: InputEventKey = event as InputEventKey
		if key == null or not key.pressed or key.echo:
			return
		window.key_pressed.emit(key)
		get_viewport().set_input_as_handled()
