class_name FloorPlanView
extends VBoxContainer
## The floor plan of a house installation (Schematic | Floor plan in the
## toolbar of a residential schematic): a bar with the tools above the list
## of parts not placed yet and the [FloorPlanCanvas]. In Edit mode rooms are
## drawn (Room, by dragging) or added ready-made (Add room), doors and
## windows put in walls (Door, Window), the walls' thickness set (Walls),
## luminaires spread over a selected room or parts in a row along a
## selected wall (Array), notes with leaders written (Note), furniture put
## in from the palette (a double click sets its size, R turns it), the
## architect's drawing put under the plan, scaled and moved (Underlay),
## floors added and chosen (the tabs over the plan), and a part chosen in the list is put where the plan is
## clicked next. A residential installation also draws its lighting (Wire),
## takes new parts from the palette ([method begin_place_template]) onto
## the circuit chosen beside the plan (where a selected part's circuit is
## changed too), and gives each room its number, environment and
## illuminance; Symbols opens the user's own symbols ([SymbolLibraryDialog]),
## drawn there and put in from the palette. Every change is emitted as one
## undoable edit of the document.

## A change of the plan: [param change] is called with the document.
signal edit_requested(change: Callable)
## Rocker [param rocker] of light switch [param designation] was clicked
## while simulating.
signal switch_toggled(designation: String, rocker: int)
## A change of the consumer unit's rails (see [CabinetPanel]).
signal cabinet_edit_requested(change: Callable)
## Device [param designation] of the consumer unit was operated while
## simulating (a breaker switched, a fuse replaced).
signal operate_requested(designation: String)
## Floor [param index] is shown (not an edit; the other copy of the
## document should show it too).
signal floor_changed(index: int)

var canvas: FloorPlanCanvas
var _document: SchematicDocument
var _editing: bool = false
var _fit_pending: bool = true
var _bar: HBoxContainer
var _select_button: Button
var _room_button: Button
var _door_button: Button
var _wire_button: Button
var _join_button: Button
var _window_button: Button
var _dimension_button: Button
var _note_button: Button
var _underlay_menu: MenuButton
var _underlay_file: FileDialog
var _scale_dialog: ConfirmationDialog
var _scale_field: SpinBox
## The two points of the underlay whose distance is asked (m).
var _scale_points: PackedVector2Array = PackedVector2Array()
var _floor_row: HBoxContainer
var _floor_tabs: TabBar
var _floor_menu: MenuButton
## The floor tabs are being filled (their signals are not choices then).
var _filling_floors: bool = false
var _floor_dialog: ConfirmationDialog
var _floor_name: LineEdit
var _note_dialog: ConfirmationDialog
var _note_text: TextEdit
## The note the dialog edits, -1 for a new one.
var _note: int = -1
var _fixture_dialog: ConfirmationDialog
var _fixture_width: SpinBox
var _fixture_depth: SpinBox
## The fixture the dialog edits.
var _fixture: int = -1
var _measure_button: Button
var _walls_button: Button
var _symbols_button: Button
var _symbols_dialog: SymbolLibraryDialog
var _window_dialog: ConfirmationDialog
var _window_width: SpinBox
var _window_sill: SpinBox
var _window_height: SpinBox
## The window the dialog edits.
var _window: int = -1
var _array_button: Button
var _array_dialog: ConfirmationDialog
var _array_title: Label
var _array_part: OptionButton
var _array_grid: GridContainer
var _array_rows: SpinBox
var _array_columns: SpinBox
var _array_count: SpinBox
var _array_spacing: SpinBox
var _array_start: SpinBox
## Templates offered, by item of [member _array_part].
var _array_templates: Array[Dictionary] = []
## What the array goes into: {"kind": "room" or "edge", "index", "side"}.
var _array_target: Dictionary = {}
var _walls_dialog: ConfirmationDialog
var _outer_wall: SpinBox
var _inner_wall: SpinBox
## Where north is on the plan (degrees clockwise from up), for the sheet's arrow.
var _north: SpinBox
## How large the plan's symbols and texts are drawn (%).
var _symbol_size: SpinBox
var _text_size: SpinBox
var _door_dialog: ConfirmationDialog
var _door_width: SpinBox
var _door_double: CheckBox
var _door_hinge: OptionButton
var _door_side: OptionButton
## The door the dialog edits.
var _door: int = -1
var _circuit_title: Label
var _circuit: OptionButton
## Circuits offered (their devices), by item index of [member _circuit] (the first: none).
var _circuits: PackedStringArray = PackedStringArray()
## The circuit for new parts was chosen (else the first is taken).
var _circuit_picked: bool = false
var _room_fields: GridContainer
var _width_field: SpinBox
var _height_field: SpinBox
var _length_dialog: ConfirmationDialog
var _length_label: Label
var _length_field: SpinBox
## Room and wall (side) whose length is asked.
var _length_wall: Vector2i = Vector2i(-1, -1)
var _number_field: LineEdit
var _environment_field: OptionButton
var _lux_field: LineEdit
## What the environment chosen means.
var _environment_note: Label
var _presets: MenuButton
var _delete_button: Button
var _fit_button: Button
var _side: VBoxContainer
var _list_title: Label
var _list: ItemList
var _list_hint: Label
## Designations in the list, by item index.
var _listed: PackedStringArray = PackedStringArray()
## The consumer unit opened in place of the plan, null while the plan shows.
var _unit: CabinetPanel
var _back_button: Button
var _body: HBoxContainer
var _rename_dialog: ConfirmationDialog
var _rename_field: LineEdit
var _renaming: int = -1


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var bar: PanelContainer = PanelContainer.new()
	bar.theme_type_variation = "PageBar"
	add_child(bar)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 4)
	_bar.custom_minimum_size.y = 30.0
	bar.add_child(_bar)
	var group: ButtonGroup = ButtonGroup.new()
	_back_button = Button.new()
	_back_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_back_button.theme_type_variation = "ToolButton"
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.icon = AppTheme.icon("chevron_left")
	_back_button.visible = false
	_back_button.pressed.connect(close_unit)
	_bar.add_child(_back_button)
	_select_button = _tool_button("select", FloorPlanCanvas.Tool.SELECT, group)
	_room_button = _tool_button("room", FloorPlanCanvas.Tool.ROOM, group)
	_door_button = _tool_button("door", FloorPlanCanvas.Tool.DOOR, group)
	_window_button = _tool_button("plan_window", FloorPlanCanvas.Tool.WINDOW, group)
	_wire_button = _tool_button("wire", FloorPlanCanvas.Tool.WIRE, group)
	_join_button = _tool_button("join", FloorPlanCanvas.Tool.JOIN, group)
	_dimension_button = _tool_button("plan_dimension", FloorPlanCanvas.Tool.DIMENSION, group)
	_measure_button = _tool_button("plan_measure", FloorPlanCanvas.Tool.MEASURE, group)
	_note_button = _tool_button("plan_note", FloorPlanCanvas.Tool.NOTE, group)
	_select_button.set_pressed_no_signal(true)
	_presets = MenuButton.new()
	_presets.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_presets.flat = false
	_presets.theme_type_variation = "ToolButton"
	_presets.get_popup().id_pressed.connect(_add_preset)
	_bar.add_child(_presets)
	_array_button = Button.new()
	_array_button.theme_type_variation = "ToolButton"
	_array_button.focus_mode = Control.FOCUS_NONE
	_array_button.icon = AppTheme.icon("plan_array")
	_array_button.pressed.connect(_ask_array)
	_bar.add_child(_array_button)
	_underlay_menu = MenuButton.new()
	_underlay_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_underlay_menu.theme_type_variation = "ToolButton"
	_underlay_menu.icon = AppTheme.icon("plan_underlay")
	_underlay_menu.get_popup().id_pressed.connect(_on_underlay_menu)
	_underlay_menu.about_to_popup.connect(_fill_underlay_menu)
	_bar.add_child(_underlay_menu)
	_walls_button = Button.new()
	_walls_button.theme_type_variation = "ToolButton"
	_walls_button.focus_mode = Control.FOCUS_NONE
	_walls_button.icon = AppTheme.icon("walls")
	_walls_button.pressed.connect(_ask_walls)
	_bar.add_child(_walls_button)
	_symbols_button = Button.new()
	_symbols_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_symbols_button.theme_type_variation = "ToolButton"
	_symbols_button.focus_mode = Control.FOCUS_NONE
	_symbols_button.icon = AppTheme.icon("symbols")
	_symbols_button.pressed.connect(func() -> void: _symbols_dialog.open())
	_bar.add_child(_symbols_button)
	_delete_button = Button.new()
	_delete_button.theme_type_variation = "ToolButton"
	_delete_button.focus_mode = Control.FOCUS_NONE
	_delete_button.icon = AppTheme.icon("delete")
	_delete_button.pressed.connect(func() -> void: canvas.delete_selected())
	_bar.add_child(_delete_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.add_child(spacer)
	_fit_button = Button.new()
	_fit_button.theme_type_variation = "ToolButton"
	_fit_button.focus_mode = Control.FOCUS_NONE
	_fit_button.pressed.connect(func() -> void: canvas.fit())
	_bar.add_child(_fit_button)

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	add_child(body)
	_body = body
	var side_panel: PanelContainer = PanelContainer.new()
	side_panel.theme_type_variation = "LeftPanel"
	side_panel.custom_minimum_size.x = 200.0
	body.add_child(side_panel)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 6)
	side_panel.add_child(_side)
	_circuit_title = Label.new()
	_circuit_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_circuit_title.theme_type_variation = "HeaderLabel"
	_side.add_child(_circuit_title)
	_circuit = OptionButton.new()
	_circuit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_circuit.item_selected.connect(_on_circuit_chosen)
	_side.add_child(_circuit)
	_list_title = Label.new()
	_list_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list_title.theme_type_variation = "HeaderLabel"
	_side.add_child(_list_title)
	_list = ItemList.new()
	_list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_listed)
	_side.add_child(_list)
	_list_hint = Label.new()
	_list_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list_hint.theme_type_variation = "MutedLabel"
	_list_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list_hint.custom_minimum_size.x = 180.0
	_side.add_child(_list_hint)

	var plan_column: VBoxContainer = VBoxContainer.new()
	plan_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan_column.add_theme_constant_override("separation", 0)
	body.add_child(plan_column)
	# The floors as tabs over the plan, with what can be done with them.
	_floor_row = HBoxContainer.new()
	plan_column.add_child(_floor_row)
	_floor_tabs = TabBar.new()
	_floor_tabs.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_floor_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_floor_tabs.tab_changed.connect(func(index: int) -> void:
		if not _filling_floors and _document != null and index != _document.floor:
			show_floor(index))
	_floor_row.add_child(_floor_tabs)
	_floor_menu = MenuButton.new()
	_floor_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_floor_menu.theme_type_variation = "ToolButton"
	_floor_menu.icon = AppTheme.icon("plan_floors")
	_floor_menu.get_popup().id_pressed.connect(_on_floor_menu)
	_floor_menu.about_to_popup.connect(_fill_floor_menu)
	_floor_row.add_child(_floor_menu)
	canvas = FloorPlanCanvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.edit_requested.connect(func(change: Callable) -> void: edit_requested.emit(change))
	canvas.switch_toggled.connect(func(designation: String, rocker: int) -> void: switch_toggled.emit(designation, rocker))
	canvas.rename_requested.connect(_ask_rename)
	canvas.unit_requested.connect(open_unit)
	canvas.placed.connect(func() -> void:
		_select_button.button_pressed = true
		_list.deselect_all())
	canvas.selection_changed.connect(_fill_circuits)
	canvas.selection_changed.connect(_update_array_button)
	canvas.length_requested.connect(_ask_length)
	canvas.door_requested.connect(_ask_door)
	canvas.window_requested.connect(_ask_window)
	canvas.note_requested.connect(_ask_note)
	canvas.fixture_requested.connect(_ask_fixture)
	canvas.scale_requested.connect(_ask_scale)
	canvas.resized.connect(func() -> void:
		if _fit_pending and canvas.size.x > 10.0 and _document != null:
			_fit_pending = false
			canvas.fit())
	plan_column.add_child(canvas)

	_rename_dialog = ConfirmationDialog.new()
	var dialog_column: VBoxContainer = VBoxContainer.new()
	_rename_dialog.add_child(dialog_column)
	_rename_field = LineEdit.new()
	_rename_field.custom_minimum_size = Vector2(260, 0)
	dialog_column.add_child(_rename_field)
	_rename_dialog.register_text_enter(_rename_field)
	# Its inside, as typed lengths.
	var size_fields: GridContainer = GridContainer.new()
	size_fields.columns = 2
	dialog_column.add_child(size_fields)
	_width_field = _metres()
	_height_field = _metres()
	for field: SpinBox in [_width_field, _height_field]:
		var label: Label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		size_fields.add_child(label)
		size_fields.add_child(field)
	# A residential installation's room: its number, environment, illuminance.
	_room_fields = GridContainer.new()
	_room_fields.columns = 2
	dialog_column.add_child(_room_fields)
	_number_field = LineEdit.new()
	_environment_field = OptionButton.new()
	_environment_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for environment: String in FloorPlan.ENVIRONMENTS:
		_environment_field.add_item(environment)
	_lux_field = LineEdit.new()
	for field: Control in [_number_field, _environment_field, _lux_field]:
		var label: Label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_room_fields.add_child(label)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_room_fields.add_child(field)
		if field is LineEdit:
			_rename_dialog.register_text_enter(field as LineEdit)
	_environment_note = Label.new()
	_environment_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_environment_note.theme_type_variation = "MutedLabel"
	_environment_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_environment_note.custom_minimum_size.x = 380.0
	dialog_column.add_child(_environment_note)
	_environment_field.item_selected.connect(func(index: int) -> void: _environment_note.text = tr(FloorPlan.ENVIRONMENT_NOTES[index]))
	_rename_dialog.confirmed.connect(_apply_rename)
	add_child(_rename_dialog)
	_length_dialog = ConfirmationDialog.new()
	var length_row: HBoxContainer = HBoxContainer.new()
	_length_label = Label.new()
	_length_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	length_row.add_child(_length_label)
	_length_field = _metres()
	length_row.add_child(_length_field)
	_length_dialog.add_child(length_row)
	_length_dialog.register_text_enter(_length_field.get_line_edit())
	_length_dialog.confirmed.connect(_apply_length)
	add_child(_length_dialog)
	_door_dialog = ConfirmationDialog.new()
	var door_grid: GridContainer = GridContainer.new()
	door_grid.columns = 2
	_door_dialog.add_child(door_grid)
	_door_width = _metres()
	_door_width.min_value = 0.5
	_door_width.max_value = 3.0
	_door_double = CheckBox.new()
	_door_hinge = OptionButton.new()
	_door_hinge.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_door_side = OptionButton.new()
	_door_side.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for field: Control in [_door_width, _door_double, _door_hinge, _door_side]:
		var label: Label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		door_grid.add_child(label)
		door_grid.add_child(field)
	_door_dialog.confirmed.connect(_apply_door)
	add_child(_door_dialog)
	_window_dialog = ConfirmationDialog.new()
	var window_grid: GridContainer = GridContainer.new()
	window_grid.columns = 2
	_window_dialog.add_child(window_grid)
	_window_width = _metres()
	_window_width.min_value = 0.3
	_window_width.max_value = 6.0
	_window_sill = _metres()
	_window_sill.min_value = 0.0
	_window_sill.max_value = 3.0
	_window_height = _metres()
	_window_height.min_value = 0.2
	_window_height.max_value = 3.0
	for field: Control in [_window_width, _window_sill, _window_height]:
		var label: Label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		window_grid.add_child(label)
		window_grid.add_child(field)
		_window_dialog.register_text_enter((field as SpinBox).get_line_edit())
	_window_dialog.confirmed.connect(_apply_window)
	add_child(_window_dialog)
	_note_dialog = ConfirmationDialog.new()
	_note_text = TextEdit.new()
	_note_text.custom_minimum_size = Vector2(320, 90)
	_note_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_note_dialog.add_child(_note_text)
	_note_dialog.confirmed.connect(_apply_note)
	add_child(_note_dialog)
	_fixture_dialog = ConfirmationDialog.new()
	var fixture_grid: GridContainer = GridContainer.new()
	fixture_grid.columns = 2
	_fixture_dialog.add_child(fixture_grid)
	_fixture_width = _metres()
	_fixture_depth = _metres()
	for field: SpinBox in [_fixture_width, _fixture_depth]:
		field.min_value = 0.2
		field.max_value = 10.0
		var label: Label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		fixture_grid.add_child(label)
		fixture_grid.add_child(field)
		_fixture_dialog.register_text_enter(field.get_line_edit())
	_fixture_dialog.confirmed.connect(_apply_fixture)
	add_child(_fixture_dialog)
	_underlay_file = FileDialog.new()
	_underlay_file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_underlay_file.access = FileDialog.ACCESS_FILESYSTEM
	_underlay_file.use_native_dialog = true
	_underlay_file.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	_underlay_file.file_selected.connect(_load_underlay)
	add_child(_underlay_file)
	_scale_dialog = ConfirmationDialog.new()
	var scale_row: HBoxContainer = HBoxContainer.new()
	_scale_dialog.add_child(scale_row)
	var scale_label: Label = Label.new()
	scale_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	scale_row.add_child(scale_label)
	_scale_field = _metres()
	_scale_field.min_value = 0.01
	_scale_field.max_value = 500.0
	scale_row.add_child(_scale_field)
	_scale_dialog.register_text_enter(_scale_field.get_line_edit())
	_scale_dialog.confirmed.connect(_apply_scale)
	add_child(_scale_dialog)
	_floor_dialog = ConfirmationDialog.new()
	_floor_name = LineEdit.new()
	_floor_name.custom_minimum_size.x = 220.0
	_floor_dialog.add_child(_floor_name)
	_floor_dialog.register_text_enter(_floor_name)
	_floor_dialog.confirmed.connect(_apply_floor_name)
	add_child(_floor_dialog)
	_array_dialog = ConfirmationDialog.new()
	var array_column: VBoxContainer = VBoxContainer.new()
	_array_dialog.add_child(array_column)
	_array_title = Label.new()
	_array_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	array_column.add_child(_array_title)
	_array_grid = GridContainer.new()
	_array_grid.columns = 2
	array_column.add_child(_array_grid)
	_array_part = OptionButton.new()
	_array_part.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_array_rows = _count_field(1, 20)
	_array_columns = _count_field(1, 20)
	_array_count = _count_field(1, 30)
	_array_spacing = _count_field(0, 20000)
	_array_spacing.suffix = "mm"
	_array_spacing.step = 50
	_array_start = _count_field(0, 20000)
	_array_start.suffix = "mm"
	_array_start.step = 50
	for field: Control in [_array_part, _array_rows, _array_columns, _array_count, _array_spacing, _array_start]:
		var label: Label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_array_grid.add_child(label)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_array_grid.add_child(field)
	_array_dialog.confirmed.connect(_apply_array)
	add_child(_array_dialog)
	_walls_dialog = ConfirmationDialog.new()
	var walls_grid: GridContainer = GridContainer.new()
	walls_grid.columns = 2
	_walls_dialog.add_child(walls_grid)
	_outer_wall = _metres()
	_inner_wall = _metres()
	for field: SpinBox in [_outer_wall, _inner_wall]:
		field.min_value = FloorPlan.MIN_WALL_THICKNESS
		field.max_value = FloorPlan.MAX_WALL_THICKNESS
		var label: Label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		walls_grid.add_child(label)
		walls_grid.add_child(field)
		_walls_dialog.register_text_enter(field.get_line_edit())
	_north = SpinBox.new()
	_north.min_value = 0.0
	_north.max_value = 359.0
	_north.step = 1.0
	_north.suffix = "°"
	var north_label: Label = Label.new()
	north_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	walls_grid.add_child(north_label)
	walls_grid.add_child(_north)
	_walls_dialog.register_text_enter(_north.get_line_edit())
	_symbol_size = _percent()
	_text_size = _percent()
	for field: SpinBox in [_symbol_size, _text_size]:
		var size_label: Label = Label.new()
		size_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		walls_grid.add_child(size_label)
		walls_grid.add_child(field)
		_walls_dialog.register_text_enter(field.get_line_edit())
	_walls_dialog.confirmed.connect(_apply_walls)
	add_child(_walls_dialog)
	_symbols_dialog = SymbolLibraryDialog.new()
	_symbols_dialog.symbol_saved.connect(_on_symbol_saved)
	add_child(_symbols_dialog)
	retranslate()


func _tool_button(icon_name: String, tool: FloorPlanCanvas.Tool, group: ButtonGroup) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.theme_type_variation = "ToolButton"
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.button_group = group
	button.icon = AppTheme.icon(icon_name)
	button.toggled.connect(func(on: bool) -> void:
		if on:
			canvas.tool = tool
			if tool != FloorPlanCanvas.Tool.PLACE:
				canvas.placing = ""
				canvas.placing_template = {}
				_list.deselect_all())
	_bar.add_child(button)
	return button


## Shows the plan of [param doc]; [param editing] lets it be changed,
## otherwise its switches operate the simulation. [param fit] shows all of
## it again (a new schematic).
func set_document(doc: SchematicDocument, editing: bool, fit: bool = false) -> void:
	_document = doc
	_editing = editing
	canvas.document = doc
	canvas.editing = editing
	if _unit != null:
		if _board_index(FloorPlan.UNIT.trim_prefix("+")) < 0:
			close_unit()
		else:
			_unit.set_document(doc, editing)
	if not editing:
		canvas.tool = FloorPlanCanvas.Tool.SELECT
		canvas.placing = ""
		canvas.placing_template = {}
		_select_button.set_pressed_no_signal(true)
	if fit:
		canvas.selected = {}
		if canvas.size.x > 10.0:
			canvas.fit()
		else:
			_fit_pending = true
	refresh()


## Opens the consumer unit (switchboard "RD1") in place of the plan, made
## first in Edit mode when there is none.
func open_unit() -> void:
	if _document == null:
		return
	var unit_name: String = FloorPlan.UNIT.trim_prefix("+")
	if _board_index(unit_name) < 0:
		if not _editing:
			return
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.ensure_consumer_unit())
	if _unit == null:
		_unit = CabinetPanel.new()
		_unit.board_name = unit_name
		_unit.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_unit.edit_requested.connect(func(change: Callable) -> void: cabinet_edit_requested.emit(change))
		_unit.door_edit_requested.connect(func(change: Callable) -> void: edit_requested.emit(change))
		_unit.operate_requested.connect(func(designation: String) -> void: operate_requested.emit(designation))
		add_child(_unit)
		_unit.set_document(_document, _editing)
	_body.visible = false
	refresh()


## Back from the consumer unit to the plan.
func close_unit() -> void:
	if _unit != null:
		_unit.queue_free()
		_unit = null
	_body.visible = true
	refresh()


func _board_index(board_name: String) -> int:
	for i: int in _document.switchboards.size():
		if _document.switchboards[i].name == board_name:
			return i
	return -1


## Follows an edit of the document.
func refresh() -> void:
	if _document == null:
		return
	var plan_shown: bool = _unit == null
	if _unit != null:
		_unit.refresh()
	_back_button.visible = not plan_shown
	_back_button.text = tr("Floor plan") if not plan_shown else ""
	for button: Control in [_select_button, _room_button, _door_button, _window_button, _dimension_button, _measure_button, _note_button, _presets, _array_button, _underlay_menu, _walls_button, _delete_button]:
		button.visible = _editing and plan_shown
	_update_array_button()
	_fill_floor_tabs()
	_wire_button.visible = _editing and plan_shown and canvas.installation()
	_symbols_button.visible = _editing and plan_shown and canvas.installation()
	_join_button.visible = _editing and plan_shown
	_fill_circuits()
	_fit_button.visible = plan_shown
	(_side.get_parent() as Control).visible = _editing
	_listed = _document.unplaced_parts()
	_list.clear()
	for designation: String in _listed:
		_list.add_item(_entry_text(designation))
	_list_hint.text = tr("Pick a part, then click where it goes: switches, sockets and appliances go onto the nearest wall, luminaires on the ceiling.") if not _listed.is_empty() else tr("Every part is on the plan.")
	canvas.queue_redraw()


## The simulation stepped: lights, sockets and appliances are drawn anew.
func show_step(result: StepResult) -> void:
	canvas.queue_redraw()
	if _unit != null:
		_unit.show_step(result)


func retranslate() -> void:
	_select_button.tooltip_text = tr("Select and move rooms, doors and parts; drag a room's edge to resize it")
	_room_button.tooltip_text = tr("Draw a room by dragging; it snaps to the walls of the others")
	_door_button.tooltip_text = tr("Put a door in a wall by clicking it; a double click on a door sets its width, double door and swing; a selected door: F swaps its hinge, Shift+F opens it to the other side")
	_join_button.tooltip_text = tr("Join two rooms into one (an L-shaped room and the like): click one, then the other touching it")
	_window_button.tooltip_text = tr("Put a window in a wall by clicking it; a double click on a window sets its width, sill and height")
	_dimension_button.tooltip_text = tr("Dimensions printed with the plan: click a wall for a chain along it (corners, parts, doors and windows), or drag between two points; drag a dimension to set it off, Delete takes it away")
	_measure_button.tooltip_text = tr("Measure: drag between two points (corners, parts and the ends of doors and windows are caught) to see the distance; nothing is drawn")
	_underlay_menu.tooltip_text = tr("Underlay: the architect's drawing under the plan, to trace the walls over it (a PDF page saved as a PNG or JPG first); it does not print")
	_scale_dialog.title = tr("Scale of the underlay")
	_scale_dialog.ok_button_text = tr("OK")
	_scale_dialog.cancel_button_text = tr("Cancel")
	(_scale_field.get_parent().get_child(0) as Label).text = tr("The two points are this far apart")
	_floor_menu.tooltip_text = tr("Floors: each its own plan and sheet")
	_floor_dialog.title = tr("Name of the floor")
	_floor_dialog.ok_button_text = tr("OK")
	_floor_dialog.cancel_button_text = tr("Cancel")
	_note_button.tooltip_text = tr("Note: press where it points and drag to where its text goes, then type it; a double click edits a note, an empty text takes it away")
	_note_dialog.title = tr("Note")
	_note_dialog.ok_button_text = tr("OK")
	_note_dialog.cancel_button_text = tr("Cancel")
	_fixture_dialog.ok_button_text = tr("OK")
	_fixture_dialog.cancel_button_text = tr("Cancel")
	var fixture_labels: Array[String] = [tr("Width"), tr("Depth")]
	var fixture_grid: GridContainer = _fixture_width.get_parent() as GridContainer
	for k: int in fixture_labels.size():
		(fixture_grid.get_child(2 * k) as Label).text = fixture_labels[k]
	_array_button.tooltip_text = tr("Array: luminaires spread over the selected room in rows and columns, or sockets and wall luminaires in a row along the selected wall, on the circuit chosen")
	_array_dialog.title = tr("Array")
	_array_dialog.ok_button_text = tr("Put them in")
	_array_dialog.cancel_button_text = tr("Cancel")
	var array_labels: Array[String] = [tr("Part"), tr("Rows"), tr("Columns"), tr("Count"), tr("Spacing (0: evenly)"), tr("From the left or top end")]
	for k: int in array_labels.size():
		(_array_grid.get_child(2 * k) as Label).text = array_labels[k]
	_symbols_button.text = tr("Symbols")
	_symbols_button.tooltip_text = tr("My symbols: draw your own from lines, shapes, curves and text, sorted into your categories; the palette offers them for the plan, drawings or loads on a circuit")
	_walls_button.tooltip_text = tr("Plan settings: the thickness of the outside walls and of those between rooms, where north is, how large the symbols and texts are drawn")
	_window_dialog.title = tr("Window")
	_window_dialog.ok_button_text = tr("OK")
	_window_dialog.cancel_button_text = tr("Cancel")
	var window_labels: Array[String] = [tr("Width"), tr("Sill height"), tr("Height")]
	var window_grid: GridContainer = _window_width.get_parent() as GridContainer
	for k: int in window_labels.size():
		(window_grid.get_child(2 * k) as Label).text = window_labels[k]
	_walls_dialog.title = tr("Plan settings")
	_walls_dialog.ok_button_text = tr("OK")
	_walls_dialog.cancel_button_text = tr("Cancel")
	var wall_labels: Array[String] = [tr("Outside walls"), tr("Walls between rooms"), tr("North (clockwise from up)"), tr("Size of the symbols"), tr("Size of the texts")]
	var walls_grid: GridContainer = _outer_wall.get_parent() as GridContainer
	for k: int in wall_labels.size():
		(walls_grid.get_child(2 * k) as Label).text = wall_labels[k]
	_door_dialog.title = tr("Door")
	_door_dialog.ok_button_text = tr("OK")
	_door_dialog.cancel_button_text = tr("Cancel")
	var door_labels: Array[String] = [tr("Width"), tr("Double door"), tr("Hinges"), tr("Opens")]
	var door_grid: GridContainer = _door_width.get_parent() as GridContainer
	for k: int in door_labels.size():
		(door_grid.get_child(2 * k) as Label).text = door_labels[k]
	_door_hinge.clear()
	_door_hinge.add_item(tr("Left or top"))
	_door_hinge.add_item(tr("Right or bottom"))
	_door_side.clear()
	_door_side.add_item(tr("Down or left"))
	_door_side.add_item(tr("Up or right"))
	_wire_button.tooltip_text = tr("Draw the lighting: drag from a light switch (of two rockers, from the side of the one) to a luminaire it switches, or to the other switch of a staircase; it is wired by itself")
	var size_labels: Array[String] = [tr("Width"), tr("Height")]
	var size_grid: GridContainer = _width_field.get_parent() as GridContainer
	for k: int in size_labels.size():
		(size_grid.get_child(2 * k) as Label).text = size_labels[k]
	_length_dialog.title = tr("Wall length")
	_length_dialog.ok_button_text = tr("OK")
	_length_dialog.cancel_button_text = tr("Cancel")
	var labels: Array[String] = [tr("Number"), tr("Environment (ČSN 33 2000-5-51)"), tr("Illuminance (lx)")]
	for k: int in labels.size():
		(_room_fields.get_child(2 * k) as Label).text = labels[k]
	_presets.text = tr("Add room")
	var popup: PopupMenu = _presets.get_popup()
	popup.clear()
	for i: int in FloorPlan.PRESETS.size():
		var preset: Dictionary = FloorPlan.PRESETS[i]
		var size: Vector2 = preset["size"]
		var shape: String = (tr("L-shaped") + " ") if preset.has("l") else ""
		popup.add_item("%s%s  %s × %s m" % [shape, tr(preset["name"]), String.num(size.x, 2), String.num(size.y, 2)], i)
	_delete_button.tooltip_text = tr("Take the selected room, door or part away")
	_fit_button.text = tr("Show all")
	_list_title.text = tr("Not on the plan").to_upper()
	_rename_dialog.title = tr("Room")
	_rename_dialog.ok_button_text = tr("OK")
	_rename_dialog.cancel_button_text = tr("Cancel")
	if _document != null:
		refresh()


## Symbol [param def] was drawn in the library: a schematic using it takes
## the new drawing (an edit, undone like any).
func _on_symbol_saved(def: CustomSymbol) -> void:
	if _document != null and _document.symbols.has(def.id):
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.use_symbol(def))
	canvas.queue_redraw()


## Puts a new part made from the palette's [param template] where the plan
## is clicked next (on the circuit chosen), again until a right click.
func begin_place_template(template: Dictionary) -> void:
	canvas.placing = ""
	canvas.placing_template = template
	canvas.tool = FloorPlanCanvas.Tool.PLACE
	for button: Button in [_select_button, _room_button, _door_button, _window_button, _dimension_button, _measure_button, _note_button, _wire_button, _join_button]:
		button.set_pressed_no_signal(false)
	_list.deselect_all()
	canvas.grab_focus()


## The circuit picker of a residential installation: the circuit of the
## selected part (changed there), or the one new parts go on.
func _fill_circuits() -> void:
	if _document == null or _circuit == null:
		return
	var shown: bool = canvas.installation()
	_circuit_title.visible = shown
	_circuit.visible = shown
	if not shown:
		return
	var line: SingleLine = _document.single_line
	var part: String = canvas.selected.get("designation", "") if canvas.selected.get("kind", "") == "part" else ""
	if part == FloorPlan.UNIT:
		part = ""
	_circuit_title.text = (tr("Circuit of -%s") % part if not part.is_empty() else tr("Circuit for new parts")).to_upper()
	_circuits = PackedStringArray([""])
	_circuit.clear()
	_circuit.add_item(tr("No circuit"))
	for f: SingleLine.Feeder in line.feeders():
		_circuits.append(f.device)
		var where: String = f.destination
		if where.is_empty():
			var end: CircuitComponent = SingleLine.end_part(f, _document.circuit)
			where = ""
			if end is SocketOutlet:
				where = tr("Sockets")
			elif end is Luminaire:
				where = tr("Lighting")
			elif end is Appliance:
				where = ApplianceSymbol.title_of(end as Appliance)
		_circuit.add_item(("-%s  %s" % [f.device, where]).strip_edges())
	var current: String = canvas.circuit
	if not part.is_empty():
		var fed: SingleLine.Feeder = line.feeder_feeding(part)
		current = fed.device if fed != null else ""
	elif (current.is_empty() and not _circuit_picked) or not _circuits.has(current):
		current = _circuits[1] if _circuits.size() > 1 else ""
		canvas.circuit = current
	_circuit.select(maxi(_circuits.find(current), 0))


func _on_circuit_chosen(index: int) -> void:
	var device: String = _circuits[index] if index < _circuits.size() else ""
	var part: String = canvas.selected.get("designation", "") if canvas.selected.get("kind", "") == "part" else ""
	if part.is_empty() or part == FloorPlan.UNIT:
		canvas.circuit = device
		_circuit_picked = true
		return
	# The selected part moves to the circuit chosen.
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		var old: SingleLine.Feeder = doc.single_line.feeder_feeding(part)
		if old != null:
			old.loads.remove_at(old.loads.find(part))
		var f: SingleLine.Feeder = doc.single_line.feeder_of(device)
		if f != null:
			f.loads.append(part))


func _entry_text(designation: String) -> String:
	if designation == FloorPlan.UNIT:
		return tr("Consumer unit %s") % FloorPlan.UNIT
	var c: CircuitComponent = _document.circuit.get_component(designation)
	var what: String = ""
	if c is LightSwitch:
		what = tr("Switch no. %s") % (c as LightSwitch).circuit
	elif c is SocketOutlet:
		what = tr("Socket outlet")
	elif c is Luminaire:
		what = tr("Luminaire")
	elif c is Appliance:
		what = ApplianceSymbol.title_of(c as Appliance)
	return "-%s  %s" % [designation, what]


func _on_listed(index: int) -> void:
	if index < 0 or index >= _listed.size():
		return
	canvas.placing = _listed[index]
	canvas.tool = FloorPlanCanvas.Tool.PLACE
	_select_button.set_pressed_no_signal(false)
	_room_button.set_pressed_no_signal(false)
	_door_button.set_pressed_no_signal(false)
	canvas.grab_focus()


func _add_preset(index: int) -> void:
	var preset: Dictionary = FloorPlan.PRESETS[index]
	var room_name: String = preset["name"]
	var rect: Rect2 = _document.floor_plan.free_spot(preset["size"])
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.rooms.append(FloorPlan.preset_room(index, rect.position, room_name)))
	canvas.queue_redraw()


## A field of metres, to the centimetre.
func _metres() -> SpinBox:
	var field: SpinBox = SpinBox.new()
	field.min_value = FloorPlan.MIN_ROOM
	field.max_value = 100.0
	field.step = 0.01
	field.suffix = "m"
	field.custom_minimum_size.x = 120.0
	return field


## Asks the length of wall [param k] of room [param index] (its start
## stays, the wall after it moves).
func _ask_length(index: int, k: int) -> void:
	if not _editing or index < 0 or index >= _document.floor_plan.rooms.size():
		return
	_length_wall = Vector2i(index, k)
	var w: PackedVector2Array = _document.floor_plan.rooms[index].wall(k)
	_length_label.text = tr("Wall of %s") % tr(_document.floor_plan.rooms[index].name)
	_length_field.min_value = FloorPlan.MIN_WALL
	_length_field.value = w[0].distance_to(w[1])
	_length_dialog.reset_size()
	_length_dialog.popup_centered()
	_length_field.get_line_edit().select_all()
	_length_field.get_line_edit().grab_focus()


func _apply_length() -> void:
	var wall: Vector2i = _length_wall
	if wall.x < 0 or wall.x >= _document.floor_plan.rooms.size():
		return
	var length: float = _length_field.value
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.set_wall_length(wall.x, wall.y, length))


## Asks how door [param index] is: its width, single or double, its hinge
## end and the side it opens to.
func _ask_door(index: int) -> void:
	if not _editing or index < 0 or index >= _document.floor_plan.doors.size():
		return
	_door = index
	var door: FloorPlan.Door = _document.floor_plan.doors[index]
	_door_width.value = door.width
	_door_double.button_pressed = door.double
	_door_hinge.select(1 if door.hinge_end else 0)
	_door_side.select(1 if door.opens_back else 0)
	_door_dialog.reset_size()
	_door_dialog.popup_centered()


func _apply_door() -> void:
	var index: int = _door
	if index < 0 or index >= _document.floor_plan.doors.size():
		return
	var width: float = _door_width.value
	var double: bool = _door_double.button_pressed
	var hinge_end: bool = _door_hinge.selected == 1
	var opens_back: bool = _door_side.selected == 1
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		var door: FloorPlan.Door = doc.floor_plan.doors[index]
		door.width = width
		door.double = double
		door.hinge_end = hinge_end
		door.opens_back = opens_back)


func _ask_window(index: int) -> void:
	if not _editing or index < 0 or index >= _document.floor_plan.windows.size():
		return
	_window = index
	var window: FloorPlan.WindowOpening = _document.floor_plan.windows[index]
	_window_width.value = window.width
	_window_sill.value = window.sill
	_window_height.value = window.height
	_window_dialog.reset_size()
	_window_dialog.popup_centered()


func _apply_window() -> void:
	var index: int = _window
	if index < 0 or index >= _document.floor_plan.windows.size():
		return
	var width: float = _window_width.value
	var sill: float = _window_sill.value
	var height: float = _window_height.value
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		var window: FloorPlan.WindowOpening = doc.floor_plan.windows[index]
		window.width = width
		window.sill = sill
		window.height = height)


## Asks the text of note [param index] (-1: a new one where the canvas keeps it).
func _ask_note(index: int) -> void:
	if not _editing:
		return
	_note = index
	_note_text.text = _document.floor_plan.notes[index].text if index >= 0 and index < _document.floor_plan.notes.size() else ""
	_note_dialog.reset_size()
	_note_dialog.popup_centered()
	_note_text.grab_focus()


## A new note with the text typed, or the note's text changed (taken away
## when it is left empty).
func _apply_note() -> void:
	var text: String = _note_text.text.strip_edges()
	var index: int = _note
	if index < 0:
		if text.is_empty() or canvas.pending_note.size() != 2:
			return
		var anchor: Vector2 = canvas.pending_note[0]
		var label: Vector2 = canvas.pending_note[1]
		edit_requested.emit(func(doc: SchematicDocument) -> void:
			var note: FloorPlan.Note = FloorPlan.Note.new()
			note.text = text
			note.at = anchor
			note.label = label
			doc.floor_plan.notes.append(note))
		return
	if index >= _document.floor_plan.notes.size():
		return
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		if text.is_empty():
			doc.floor_plan.notes.remove_at(index)
		else:
			doc.floor_plan.notes[index].text = text)


func _ask_fixture(index: int) -> void:
	if not _editing or index < 0 or index >= _document.floor_plan.fixtures.size():
		return
	_fixture = index
	var fixture: FloorPlan.Fixture = _document.floor_plan.fixtures[index]
	_fixture_dialog.title = tr(FloorPlan.FIXTURE_NAMES.get(fixture.kind, "Furniture and fixtures"))
	_fixture_width.value = fixture.extent().x
	_fixture_depth.value = fixture.extent().y
	_fixture_dialog.reset_size()
	_fixture_dialog.popup_centered()


func _apply_fixture() -> void:
	var index: int = _fixture
	if index < 0 or index >= _document.floor_plan.fixtures.size():
		return
	var width: float = _fixture_width.value
	var depth: float = _fixture_depth.value
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.resize_fixture(index, width, depth))


## Shows floor [param index] (the other copy of the document follows by
## [signal floor_changed]).
func show_floor(index: int) -> void:
	if _document == null or index < 0 or index >= _document.floors.size():
		return
	_document.floor = index
	canvas.selected = {}
	canvas.tool = FloorPlanCanvas.Tool.SELECT
	_select_button.set_pressed_no_signal(true)
	floor_changed.emit(index)
	refresh()


## The tabs of the floors: shown with several floors, or while editing.
func _fill_floor_tabs() -> void:
	if _floor_tabs == null or _document == null:
		return
	_floor_row.visible = _unit == null and (_editing or _document.floors.size() > 1)
	_filling_floors = true
	_floor_tabs.clear_tabs()
	for plan: FloorPlan in _document.floors:
		_floor_tabs.add_tab(plan.floor_name())
	_floor_tabs.current_tab = clampi(_document.floor, 0, _document.floors.size() - 1)
	_filling_floors = false
	_floor_menu.visible = _editing


func _fill_floor_menu() -> void:
	var popup: PopupMenu = _floor_menu.get_popup()
	popup.clear()
	popup.add_item(tr("Add a floor above"), 0)
	popup.add_item(tr("Add a basement below"), 1)
	popup.add_item(tr("Rename this floor"), 2)
	popup.add_item(tr("Remove this floor"), 3)
	popup.set_item_disabled(3, _document.floors.size() < 2)


func _on_floor_menu(id: int) -> void:
	match id:
		0, 1:
			var below: bool = id == 1
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor = doc.add_floor(below))
			show_floor(0 if below else _document.floors.size() - 1)
		2:
			_floor_name.text = _document.floor_plan.floor_name()
			_floor_dialog.reset_size()
			_floor_dialog.popup_centered()
			_floor_name.select_all()
			_floor_name.grab_focus()
		3:
			if _document.floors.size() < 2:
				return
			var index: int = _document.floor
			# What is on it goes back to the list of parts not on a plan.
			edit_requested.emit(func(doc: SchematicDocument) -> void:
				doc.floors.remove_at(index)
				doc.floor = clampi(index, 0, doc.floors.size() - 1))
			show_floor(clampi(index, 0, _document.floors.size() - 1))


func _apply_floor_name() -> void:
	var text: String = _floor_name.text.strip_edges()
	var index: int = _document.floor
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		var plan: FloorPlan = doc.floors[index]
		plan.name = ""
		if text != plan.floor_name():
			plan.name = text)


func _fill_underlay_menu() -> void:
	var popup: PopupMenu = _underlay_menu.get_popup()
	popup.clear()
	var plan: FloorPlan = _document.floor_plan
	var has: bool = not plan.underlay.is_empty()
	popup.add_item(tr("Load the architect's drawing (PNG or JPG)…"), 0)
	popup.add_item(tr("Set its scale: click two points a known distance apart"), 1)
	popup.add_item(tr("Move it: drag it under the plan"), 2)
	popup.add_check_item(tr("Show it"), 3)
	popup.set_item_checked(popup.get_item_index(3), plan.underlay_shown)
	popup.add_item(tr("Remove it"), 4)
	for id: int in [1, 2, 3, 4]:
		popup.set_item_disabled(popup.get_item_index(id), not has)
	if has and canvas.underlay_texture(plan.underlay) == null:
		popup.add_separator()
		popup.add_item(tr("%s cannot be read") % plan.underlay.get_file(), 5)
		popup.set_item_disabled(popup.get_item_index(5), true)


func _on_underlay_menu(id: int) -> void:
	match id:
		0:
			_underlay_file.popup_centered_ratio(0.6)
		1:
			canvas.tool = FloorPlanCanvas.Tool.SCALE
			_deselect_tools()
		2:
			canvas.tool = FloorPlanCanvas.Tool.UNDERLAY
			_deselect_tools()
		3:
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.underlay_shown = not doc.floor_plan.underlay_shown)
		4:
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.underlay = "")


func _deselect_tools() -> void:
	for button: Button in [_select_button, _room_button, _door_button, _window_button, _dimension_button, _measure_button, _note_button, _wire_button, _join_button]:
		button.set_pressed_no_signal(false)
	canvas.grab_focus()


## Puts the image at [param path] under the floor shown, its top left at the
## plan's, at the usual scale; then asks for two points to scale it.
func _load_underlay(path: String) -> void:
	var at: Vector2 = _document.floor_plan.bounds().position if not _document.floor_plan.rooms.is_empty() else Vector2.ZERO
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		doc.floor_plan.underlay = path
		doc.floor_plan.underlay_at = at
		doc.floor_plan.underlay_scale = FloorPlan.UNDERLAY_SCALE
		doc.floor_plan.underlay_shown = true)
	canvas.tool = FloorPlanCanvas.Tool.SCALE
	_deselect_tools()


## Asks how far apart plan points [param a] and [param b] really are.
func _ask_scale(a: Vector2, b: Vector2) -> void:
	_scale_points = PackedVector2Array([a, b])
	_scale_field.value = snappedf(a.distance_to(b), 0.01)
	_scale_dialog.reset_size()
	_scale_dialog.popup_centered()
	_scale_field.get_line_edit().select_all()
	_scale_field.get_line_edit().grab_focus()


## Scales the underlay so the two points are the distance typed apart, the
## first one staying where it is.
func _apply_scale() -> void:
	if _scale_points.size() != 2:
		return
	var a: Vector2 = _scale_points[0]
	var measured: float = a.distance_to(_scale_points[1])
	var real: float = _scale_field.value
	canvas.tool = FloorPlanCanvas.Tool.SELECT
	_select_button.set_pressed_no_signal(true)
	if measured < 0.001:
		return
	edit_requested.emit(func(doc: SchematicDocument) -> void: FloorPlanView.scale_underlay(doc.floor_plan, a, real / measured))


## Scales the underlay of [param plan] by [param factor] round plan point [param fixed].
static func scale_underlay(plan: FloorPlan, fixed: Vector2, factor: float) -> void:
	plan.underlay_scale *= factor
	plan.underlay_at = fixed - (fixed - plan.underlay_at) * factor


## A field of a size in percent of the usual one.
func _percent() -> SpinBox:
	var field: SpinBox = SpinBox.new()
	field.min_value = FloorPlan.MIN_SIZE * 100.0
	field.max_value = FloorPlan.MAX_SIZE * 100.0
	field.step = 5.0
	field.suffix = "%"
	field.custom_minimum_size.x = 120.0
	return field


## A count field from [param low] to [param high].
func _count_field(low: int, high: int) -> SpinBox:
	var field: SpinBox = SpinBox.new()
	field.min_value = low
	field.max_value = high
	field.step = 1
	field.custom_minimum_size.x = 120.0
	return field


## Array works on a selected room or wall.
func _update_array_button() -> void:
	if _array_button != null:
		_array_button.disabled = not (canvas.selected.get("kind", "") in ["room", "edge"])


## Asks how to spread parts: luminaires over the selected room in rows and
## columns, or parts along the selected wall (evenly, or from its start
## every so far).
func _ask_array() -> void:
	var kind: String = canvas.selected.get("kind", "")
	if not _editing or not (kind in ["room", "edge"]):
		return
	_array_target = canvas.selected.duplicate()
	var plan: FloorPlan = _document.floor_plan
	var index: int = _array_target["index"]
	var room_text: String = plan.room_number(index) if canvas.installation() else tr(plan.rooms[index].name)
	_array_templates.clear()
	_array_part.clear()
	var offered: Array = [["Luminaire", {"type": "luminaire"}]] if kind == "room" else [["Socket outlet 230 V (type E)", {"type": "socket", "gangs": 1}], ["Double socket outlet 230 V (type E)", {"type": "socket", "gangs": 2}], ["Wall luminaire", {"type": "luminaire", "wall": true}]]
	for entry: Array in offered:
		_array_part.add_item(tr(entry[0]))
		_array_templates.append(entry[1])
	_array_title.text = (tr("Luminaires spread over room %s") if kind == "room" else tr("Parts in a row along a wall of room %s")) % room_text
	for k: int in 6:
		var shown: bool = k == 0 or (kind == "room" and k in [1, 2]) or (kind == "edge" and k in [3, 4, 5])
		_array_grid.get_child(2 * k).visible = shown
		_array_grid.get_child(2 * k + 1).visible = shown
	if kind == "room":
		_array_rows.value = 2
		_array_columns.value = 2
	else:
		_array_count.value = 3
		_array_spacing.value = 0
		_array_start.value = 300
	_array_dialog.reset_size()
	_array_dialog.popup_centered()


func _apply_array() -> void:
	if _array_target.is_empty() or _array_part.selected < 0:
		return
	var plan: FloorPlan = _document.floor_plan
	var index: int = _array_target["index"]
	if index >= plan.rooms.size():
		return
	var template: Dictionary = _array_templates[_array_part.selected]
	var feeder: String = canvas.circuit
	var points: PackedVector2Array
	var face: int = -1
	if _array_target["kind"] == "room":
		points = plan.grid_points(index, int(_array_rows.value), int(_array_columns.value))
	else:
		var k: int = _array_target["side"]
		var spacing: float = _array_spacing.value / 1000.0
		points = plan.row_points(index, k, int(_array_count.value), _array_start.value / 1000.0 if spacing > 0.0 else 0.0, spacing)
		face = maxi(FloorPlan.FACING.find(plan.rooms[index].inward(k)), 0)
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		for p: Vector2 in points:
			FloorPlanCanvas.add_part(doc, template, feeder, p, face >= 0, face))


## Asks the thickness of the outside walls and of those between rooms.
func _ask_walls() -> void:
	if not _editing:
		return
	_outer_wall.value = _document.floor_plan.outer_wall
	_inner_wall.value = _document.floor_plan.inner_wall
	_north.value = _document.floor_plan.north
	_symbol_size.value = _document.floor_plan.symbol_scale * 100.0
	_text_size.value = _document.floor_plan.text_scale * 100.0
	_walls_dialog.reset_size()
	_walls_dialog.popup_centered()


func _apply_walls() -> void:
	var outer: float = _outer_wall.value
	var inner: float = _inner_wall.value
	var north: float = _north.value
	var symbols: float = _symbol_size.value / 100.0
	var texts: float = _text_size.value / 100.0
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		doc.floor_plan.outer_wall = outer
		doc.floor_plan.inner_wall = inner
		doc.floor_plan.north = north
		# The sizes for every floor alike.
		for plan: FloorPlan in doc.floors:
			plan.symbol_scale = symbols
			plan.text_scale = texts)


func _ask_rename(index: int) -> void:
	_renaming = index
	_rename_field.text = tr(_document.floor_plan.rooms[index].name)
	_room_fields.visible = canvas.installation()
	var plan: FloorPlan = _document.floor_plan
	# Width and height of a rectangle; an L's walls are typed one by one.
	(_width_field.get_parent() as Control).visible = plan.rooms[index].is_rectangle()
	_width_field.value = plan.rooms[index].rect.size.x
	_height_field.value = plan.rooms[index].rect.size.y
	_number_field.text = plan.rooms[index].number
	_number_field.placeholder_text = str(FloorPlan.FIRST_NUMBER + index)
	_environment_field.select(maxi(FloorPlan.ENVIRONMENTS.find(plan.room_environment(index)), 0))
	_environment_note.visible = _room_fields.visible
	_environment_note.text = tr(FloorPlan.ENVIRONMENT_NOTES[_environment_field.selected])
	_lux_field.text = plan.rooms[index].lux
	_lux_field.placeholder_text = plan.room_lux(index)
	_rename_dialog.reset_size()
	_rename_dialog.popup_centered()
	_rename_field.select_all()
	_rename_field.grab_focus()


func _apply_rename() -> void:
	var index: int = _renaming
	var room_name: String = _rename_field.text.strip_edges()
	if index < 0 or index >= _document.floor_plan.rooms.size() or room_name.is_empty():
		return
	var number: String = _number_field.text.strip_edges()
	var environment: String = FloorPlan.ENVIRONMENTS[maxi(_environment_field.selected, 0)]
	var lux: String = _lux_field.text.strip_edges()
	var details: bool = _room_fields.visible
	var size: Vector2 = Vector2(_width_field.value, _height_field.value)
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		var room: FloorPlan.Room = doc.floor_plan.rooms[index]
		room.name = room_name
		if room.is_rectangle() and not room.rect.size.is_equal_approx(size):
			doc.floor_plan.resize_room(index, size)
		if details:
			room.number = number
			room.lux = lux
			# The usual one for the room is kept as none set.
			room.environment = ""
			if environment != doc.floor_plan.room_environment(index):
				room.environment = environment)
