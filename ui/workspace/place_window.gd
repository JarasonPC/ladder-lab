class_name PlaceWindow
extends Window
## A switchboard or control station of the workspace in a window of its own,
## e.g. on a second monitor, opened by a right click on it. It shows the same
## schematic or simulation as the main window and closes when its place is
## gone. Ctrl+wheel zooms the station; keys nothing here uses go to the main
## window's shortcuts.

## A key was pressed in this window (the main window handles the shortcuts).
signal key_pressed(event: InputEventKey)
signal edit_requested(change: Callable)
signal cabinet_edit_requested(change: Callable)
signal button_held(designation: String, pressed: bool)
signal switch_toggled(designation: String)
signal operate_requested(designation: String)
signal key_bind_requested(designation: String)

var kind: Workspace.Place
var place_name: String
var _panel: Control
var _document: SchematicDocument


func _init(p_kind: Workspace.Place, p_name: String) -> void:
	kind = p_kind
	place_name = p_name
	visible = false
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	min_size = Vector2i(360, 260)


func _ready() -> void:
	var default_size: Vector2 = Vector2(1000, 760) if kind == Workspace.Place.SWITCHBOARD else Vector2(720, 620)
	size = Vector2i(default_size * content_scale_factor)
	var background: Panel = Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_panel = WorkspaceView.make_panel(kind, place_name)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	WorkspaceView.forward_panel(_panel, self)
	add_child(_panel)
	var keys: _Keys = _Keys.new()
	keys.window = self
	add_child(keys)
	close_requested.connect(queue_free)
	_update_title()
	show()


## Shows the place in [param doc] (editing it, or operating its simulation);
## closes the window when [param doc] has no such place.
func set_document(doc: SchematicDocument, editing: bool) -> void:
	_document = doc
	if not _exists():
		queue_free()
		return
	_panel.call("set_document", doc, editing)
	_update_title()


## Shows the document again after an edit; closes when the place is gone.
func refresh() -> void:
	if not _exists():
		queue_free()
		return
	_panel.call("refresh")
	_update_title()


func show_step(result: StepResult) -> void:
	if _panel is CabinetPanel:
		(_panel as CabinetPanel).show_step(result)


func retranslate() -> void:
	_update_title()
	_panel.call("retranslate")


func _update_title() -> void:
	var text: String = ""
	if _document != null:
		for place: RefCounted in _document.places():
			if place.get("name") == place_name and ((place is Switchboard) == (kind == Workspace.Place.SWITCHBOARD)):
				text = str(place.get("title"))
	if text.is_empty():
		text = tr("Switchboard") if kind == Workspace.Place.SWITCHBOARD else tr("Control station")
	title = "+%s %s – LadderLab" % [place_name, text]


func _exists() -> bool:
	if _document == null:
		return true
	var list: Array = _document.switchboards if kind == Workspace.Place.SWITCHBOARD else _document.control_boxes
	for place: Variant in list:
		if (place as RefCounted).get("name") == place_name:
			return true
	return false


## Passes on the keys nothing in the window used (text fields keep theirs).
class _Keys extends Node:
	var window: PlaceWindow

	func _unhandled_input(event: InputEvent) -> void:
		var key: InputEventKey = event as InputEventKey
		if key == null or key.echo:
			return
		window.key_pressed.emit(key)
		get_viewport().set_input_as_handled()
