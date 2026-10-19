class_name KeyPrompt
extends ConfirmationDialog
## Asks for the key that operates a push button or switch while simulating:
## the next key pressed is taken (Delete takes the key off, Esc cancels).
## Space (run / pause), shortcuts with Ctrl, Alt or Cmd and F11 are not taken.

## [param key] was chosen for [param designation] ("" takes its key off).
signal chosen(designation: String, key: String)

var _designation: String = ""
var _note: Label
var _remove: Button


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var column: VBoxContainer = VBoxContainer.new()
	_note = Label.new()
	_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.custom_minimum_size = Vector2(320, 0)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)
	add_child(column)
	get_ok_button().visible = false
	_remove = add_button("", true, "remove")
	custom_action.connect(func(_action: StringName) -> void: _choose(""))
	window_input.connect(_on_key)


## Asks for the key of [param designation] ([param what]: its plate text or
## kind, [param current]: its key now, "" for none).
func ask(designation: String, what: String, current: String) -> void:
	_designation = designation
	title = tr("Bind a key")
	cancel_button_text = tr("Cancel")
	_remove.text = tr("Take the key off")
	_remove.visible = not current.is_empty()
	var text: String = tr("Press a key for -%s") % designation
	if not what.is_empty():
		text += "  (" + what + ")"
	text += "\n" + (tr("Now: %s") % current if not current.is_empty() else tr("No key yet."))
	_note.text = text
	# At the interface size of the window it is asked from.
	content_scale_factor = get_parent().get_window().content_scale_factor
	reset_size()
	popup_centered()


func _on_key(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	match key.keycode:
		KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB:
			return
		KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK:
			return
		KEY_SPACE, KEY_F11:
			_note.text = tr("Space runs and pauses the simulation and F11 is full screen: choose another key.")
			set_input_as_handled()
			return
		KEY_DELETE, KEY_BACKSPACE:
			_choose("")
		_:
			_choose(OS.get_keycode_string(key.keycode))
	set_input_as_handled()


func _choose(key: String) -> void:
	hide()
	chosen.emit(_designation, key)
