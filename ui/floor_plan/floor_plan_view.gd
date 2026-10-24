class_name FloorPlanView
extends VBoxContainer
## The floor plan of a house installation (Floor plan in the toolbar of a
## residential schematic): a bar with the tools over the [FloorPlanCanvas],
## the tools on tabs by what they are for ([method show_tab]: building,
## the electrics, dimensions and notes), the Drawing menu with the plan's
## settings, the underlay and the layers. In Edit mode rooms are
## drawn (Room, by dragging) or added ready-made (Add room), doors and
## windows put in walls (Door, Window), the walls' thickness set (Plan
## settings), luminaires spread over a selected room or parts in a row along a
## selected wall (Array), notes with leaders written (Note), furniture put
## in from the palette (a double click sets its size, R turns it), the
## architect's drawing put under the plan, scaled and moved (Underlay),
## layers made, shown or hidden and the one new things go on chosen
## (Layers; a right click on a part, note, dimension, piece of furniture or
## mark puts it on another), floors added and chosen (the tabs over the plan), and a part chosen in the list of those not on the plan
## ([member parts_head]) is put where the plan is clicked next. What is
## selected is edited in the main window's side panel ([member inspector],
## [member part_box]). A residential installation also draws its lighting (Wire),
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
## The consumer unit was opened in place of the plan (true) or closed.
signal unit_shown(open: bool)
## The wall thickness new plans start with, or whether the room legend
## shows on the screen, was set (to save it).
signal defaults_changed
## Tab [param tab] of the tools is shown (the palette offers its parts).
signal tab_changed(tab: int)
## A part was selected on the plan ([param designation], "" for none).
signal part_selected(designation: String)
## What [member inspector] shows changed (the main window shows or hides it).
signal inspector_changed

## Tabs of the tools: building (rooms, walls, doors, windows, furniture), the
## electrics (lighting, rows, symbols, the check), dimensions and notes.
const TAB_BUILDING: int = 0
const TAB_ELECTRICS: int = 1
const TAB_ANNOTATIONS: int = 2
## Items of the Drawing menu.
const MENU_LEGEND: int = 1
const MENU_SETTINGS: int = 2

## Size of the icons of the plan's tools (logical pixels).
const ICON_SIZE: int = 22
## Tools drawing rooms, walls, doors and windows: the side panel leaves the
## parts out meanwhile.
const ROOM_TOOLS: Array[FloorPlanCanvas.Tool] = [FloorPlanCanvas.Tool.ROOM, FloorPlanCanvas.Tool.OUTLINE, FloorPlanCanvas.Tool.WALL, FloorPlanCanvas.Tool.PLACE_ROOM, FloorPlanCanvas.Tool.DOOR, FloorPlanCanvas.Tool.WINDOW]

var canvas: FloorPlanCanvas
var _document: SchematicDocument
var _editing: bool = false
var _fit_pending: bool = true
var _bar: HBoxContainer
## The lines between the groups of tools in [member _bar].
var _tool_gaps: Array[VSeparator] = []
var _select_button: Button
var _room_button: Button
var _outline_button: Button
var _wall_button: Button
var _door_button: Button
var _wire_button: Button
var _join_button: Button
var _window_button: Button
var _dimension_button: Button
var _note_button: Button
## The plan's settings, the underlay and the layers (the last two submenus).
var _drawing_menu: MenuButton
var _underlay_popup: PopupMenu
var _underlay_file: FileDialog
var _layers_popup: PopupMenu
## Tabs of the tools ([constant TAB_BUILDING] …) and the one shown.
var _tabs_track: PanelContainer
var _tab_buttons: Array[Button] = []
var _tab: int = TAB_BUILDING
## The layers to put the selection on (a right click on it).
var _layer_picker: PopupMenu
var _layer_dialog: ConfirmationDialog
var _layer_name: LineEdit
## What the layer dialog names: "new" a new layer (then the active one),
## "move" a new one the selection goes on, "rename" the active one.
var _layer_asked: String = ""
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
## The walls set are the ones new plans start with.
var _walls_default: CheckBox
## Where north is on the plan (degrees clockwise from up), for the sheet's arrow.
var _north: SpinBox
## How large the plan's symbols and texts are drawn (%).
var _symbol_size: SpinBox
var _text_size: SpinBox
var _door_dialog: ConfirmationDialog
var _door_kind: OptionButton
var _door_width: SpinBox
var _door_double: CheckBox
var _door_hinge: OptionButton
var _door_side: OptionButton
## The door the dialog edits.
var _door: int = -1
var _circuit_title: Label
var _circuit: OptionButton
var _circuit_note: Label
## The circuit of the part selected, in [member part_box].
var _part_circuit_title: Label
var _part_circuit: OptionButton
## The circuits offered by [member _part_circuit], by item index.
var _part_circuits: PackedInt32Array = PackedInt32Array()
## The parts not on the plan and the circuit new parts go on (see
## [method place_parts_head]).
var parts_head: VBoxContainer
## The check's results and the room or walls picked (see [member part_box]).
var inspector: VBoxContainer
## The circuit of the part picked, shown under its properties.
var part_box: VBoxContainer
var _side_panel: PanelContainer
## Circuits offered (their numbers), by item index of [member _circuit]
## (for new parts first by kind, then none; the last: a new one).
var _circuits: PackedInt32Array = PackedInt32Array()
var _room_fields: GridContainer
## Headings of the room panel: its dimensions, electrics, the rest.
var _size_caption: Label
var _electrics_caption: Label
var _other_caption: Label
var _width_field: SpinBox
var _height_field: SpinBox
var _length_dialog: ConfirmationDialog
var _length_label: Label
## The wall's direction (degrees, anticlockwise from right), its own
## thickness (0: the plan's) and where it lies between two rooms.
var _angle_field: SpinBox
var _thickness_field: SpinBox
var _align_label: Label
var _align_field: OptionButton
var _length_field: SpinBox
## Room and wall (side) whose length is asked.
var _length_wall: Vector2i = Vector2i(-1, -1)
## The free wall the wall dialog shows, -1 for a room's wall.
var _free_wall: int = -1
var _number_field: LineEdit
var _environment_field: OptionButton
## The table of the external influences, opened by the List button beside
## the environment.
var _influences_button: Button
var _influences_dialog: InfluencesDialog
## The room's environment when it is none of [constant FloorPlan.ENVIRONMENTS]
## (influences ticked in the table), offered after them.
var _own_environment: String = ""
var _lux_field: LineEdit
## A staircase, and its way up turned round.
var _stairs_field: CheckBox
var _stairs_reverse_field: CheckBox
## What the environment chosen means.
var _environment_note: Label
var _presets: MenuButton
var _delete_button: Button
var _fit_button: Button
var _zoom_buttons: Array[Button] = []
var _side: VBoxContainer
var _list_title: Label
var _list: ItemList
var _list_hint: Label
## Runs the check of the installation; its problems in the side panel.
var _check_button: Button
var _check_box: VBoxContainer
var _check_title: Label
var _check_list: VBoxContainer
## Designations in the list, by item index.
var _listed: PackedStringArray = PackedStringArray()
## The consumer unit opened in place of the plan, null while the plan shows.
var _unit: CabinetPanel
var _body: HBoxContainer
## The room picked, at the top of the side panel: its name (typed or
## picked from the usual ones), size, area, number, environment and
## illuminance, changed as they are typed; Duplicate, Split, Delete.
var _room_box: VBoxContainer
## The walls selected: their own thickness, an outside wall taken away.
var _wall_box: VBoxContainer
var _wall_title: Label
var _wall_thickness_label: Label
var _wall_thickness: SpinBox
var _wall_open: CheckBox
var _wall_edit: Button
var _wall_delete: Button
var _filling_wall: bool = false
var _room_title: Label
var _rename_field: LineEdit
var _name_menu: MenuButton
var _area_label: Label
var _room_duplicate: Button
var _room_split: Button
var _room_delete: Button
## The room the panel shows, -1 for none.
var _renaming: int = -1
## The panel is being filled (its signals are not changes then).
var _filling_room: bool = false
## The names offered for a room just drawn, and the menu of a room right-clicked.
var _name_picker: PopupMenu
var _room_menu: PopupMenu
## The room the name picker or the menu is for.
var _menu_room: int = -1


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
	_select_button = _tool_button("select", FloorPlanCanvas.Tool.SELECT, group)
	_room_button = _tool_button("room", FloorPlanCanvas.Tool.ROOM, group)
	_outline_button = _tool_button("room_outline", FloorPlanCanvas.Tool.OUTLINE, group)
	_wall_button = _tool_button("plan_wall", FloorPlanCanvas.Tool.WALL, group)
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
	_presets.icon = AppTheme.icon("room_add", ICON_SIZE)
	_presets.get_popup().id_pressed.connect(_add_preset)
	_bar.add_child(_presets)
	_array_button = Button.new()
	_array_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_array_button.theme_type_variation = "ToolButton"
	_array_button.focus_mode = Control.FOCUS_NONE
	_array_button.icon = AppTheme.icon("plan_array", ICON_SIZE)
	_array_button.pressed.connect(_ask_array)
	_bar.add_child(_array_button)
	_symbols_button = Button.new()
	_symbols_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_symbols_button.theme_type_variation = "ToolButton"
	_symbols_button.focus_mode = Control.FOCUS_NONE
	_symbols_button.icon = AppTheme.icon("symbols", ICON_SIZE)
	_symbols_button.pressed.connect(func() -> void: _symbols_dialog.open())
	_bar.add_child(_symbols_button)
	_check_button = Button.new()
	_check_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_check_button.theme_type_variation = "ToolButton"
	_check_button.focus_mode = Control.FOCUS_NONE
	_check_button.icon = AppTheme.icon("check", ICON_SIZE)
	_check_button.pressed.connect(func() -> void:
		_check_box.visible = true
		_fill_check()
		inspector_changed.emit())
	_bar.add_child(_check_button)
	_delete_button = Button.new()
	_delete_button.theme_type_variation = "ToolButton"
	_delete_button.focus_mode = Control.FOCUS_NONE
	_delete_button.icon = AppTheme.icon("delete", ICON_SIZE)
	_delete_button.pressed.connect(func() -> void: canvas.delete_selected())
	_bar.add_child(_delete_button)
	# The tools by what they are for, on tabs: building, the electrics,
	# dimensions and notes; selecting and deleting beside them always.
	var track: PanelContainer = PanelContainer.new()
	track.theme_type_variation = "SegmentTrack"
	_bar.add_child(track)
	_tabs_track = track
	var segments: HBoxContainer = HBoxContainer.new()
	segments.add_theme_constant_override("separation", 2)
	track.add_child(segments)
	var tabs: ButtonGroup = ButtonGroup.new()
	for tab: int in 3:
		var button: Button = Button.new()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.theme_type_variation = "SegmentButton"
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.button_group = tabs
		button.pressed.connect(func() -> void: show_tab(tab))
		segments.add_child(button)
		_tab_buttons.append(button)
	_tab_buttons[_tab].set_pressed_no_signal(true)
	var order: Array[Control] = [_select_button, _delete_button, track]
	order.append_array(_tab_tools(TAB_BUILDING) + _tab_tools(TAB_ELECTRICS) + _tab_tools(TAB_ANNOTATIONS))
	for i: int in order.size():
		_bar.move_child(order[i], i)
	var gap: VSeparator = VSeparator.new()
	_bar.add_child(gap)
	_bar.move_child(gap, 2)
	_tool_gaps.append(gap)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.add_child(spacer)
	# What is drawn under the plan, the layers and the plan's settings.
	_drawing_menu = MenuButton.new()
	_drawing_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_drawing_menu.flat = false
	_drawing_menu.theme_type_variation = "ToolButton"
	_drawing_menu.icon = AppTheme.icon("plan_layers", ICON_SIZE)
	_drawing_menu.about_to_popup.connect(_fill_drawing_menu)
	_drawing_menu.get_popup().id_pressed.connect(_on_drawing_menu)
	_bar.add_child(_drawing_menu)
	_underlay_popup = PopupMenu.new()
	_underlay_popup.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_underlay_popup.id_pressed.connect(_on_underlay_menu)
	_underlay_popup.about_to_popup.connect(_fill_underlay_menu)
	_drawing_menu.get_popup().add_child(_underlay_popup)
	_layers_popup = PopupMenu.new()
	_layers_popup.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_layers_popup.id_pressed.connect(_on_layers_menu)
	_layers_popup.about_to_popup.connect(_fill_layers_menu)
	_drawing_menu.get_popup().add_child(_layers_popup)

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	add_child(body)
	_body = body
	# The parts to put on the plan and the circuit they go on: in the
	# palette's head for an installation ([method place_parts_head]), else
	# in a panel of their own beside the plan.
	_side_panel = PanelContainer.new()
	_side_panel.theme_type_variation = "LeftPanel"
	_side_panel.custom_minimum_size.x = 200.0
	body.add_child(_side_panel)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 6)
	_side_panel.add_child(_side)
	parts_head = VBoxContainer.new()
	parts_head.add_theme_constant_override("separation", 6)
	_side.add_child(parts_head)
	_circuit_title = Label.new()
	_circuit_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_circuit_title.theme_type_variation = "HeaderLabel"
	parts_head.add_child(_circuit_title)
	_circuit = _circuit_picker(parts_head)
	_circuit_note = Label.new()
	_circuit_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_circuit_note.theme_type_variation = "MutedLabel"
	_circuit_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_circuit_note.custom_minimum_size.x = 160.0
	parts_head.add_child(_circuit_note)
	_list_title = Label.new()
	_list_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list_title.theme_type_variation = "HeaderLabel"
	parts_head.add_child(_list_title)
	_list = ItemList.new()
	_list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list.auto_height = true
	_list.item_selected.connect(_on_listed)
	parts_head.add_child(_list)
	_list_hint = Label.new()
	_list_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list_hint.theme_type_variation = "MutedLabel"
	_list_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list_hint.custom_minimum_size.x = 160.0
	parts_head.add_child(_list_hint)
	# What is selected on the plan, shown by the main window in its side
	# panel: the check's results, the room or the walls picked over the
	# properties of a part, its circuit under them ([member inspector],
	# [member part_box]).
	inspector = VBoxContainer.new()
	inspector.add_theme_constant_override("separation", 8)
	part_box = VBoxContainer.new()
	part_box.add_theme_constant_override("separation", 6)
	_part_circuit_title = Label.new()
	_part_circuit_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_part_circuit_title.theme_type_variation = "CaptionLabel"
	part_box.add_child(_part_circuit_title)
	_part_circuit = _circuit_picker(part_box)
	# Beside the plan until the main window takes them into its side panel.
	_side.add_child(inspector)
	_side.add_child(part_box)

	var plan_column: VBoxContainer = VBoxContainer.new()
	plan_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan_column.add_theme_constant_override("separation", 0)
	body.add_child(plan_column)
	# The floors as tabs over the plan, adding one right after them.
	_floor_row = HBoxContainer.new()
	plan_column.add_child(_floor_row)
	_floor_tabs = TabBar.new()
	_floor_tabs.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_floor_tabs.tab_changed.connect(func(index: int) -> void:
		if not _filling_floors and _document != null and index != _document.floor:
			show_floor(index))
	_floor_row.add_child(_floor_tabs)
	_floor_menu = MenuButton.new()
	_floor_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_floor_menu.theme_type_variation = "ToolButton"
	_floor_menu.icon = AppTheme.icon("plus", 14)
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
	canvas.selection_changed.connect(_update_parts_side)
	canvas.tool_changed.connect(_update_parts_side)
	canvas.selection_changed.connect(_update_array_button)
	canvas.selection_changed.connect(func() -> void:
		_fill_part()
		part_selected.emit(_selected_part())
		inspector_changed.emit())
	canvas.length_requested.connect(_ask_length)
	canvas.free_wall_requested.connect(_ask_free_wall)
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
	# Zoom out, in, show all: in the corner of the plan.
	var zoom: HBoxContainer = HBoxContainer.new()
	zoom.add_theme_constant_override("separation", 4)
	zoom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	zoom.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	zoom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	zoom.offset_left = -10.0
	zoom.offset_top = -10.0
	zoom.offset_right = -10.0
	zoom.offset_bottom = -10.0
	canvas.add_child(zoom)
	for step: float in [1.0 / FloorPlanCanvas.ZOOM_STEP, FloorPlanCanvas.ZOOM_STEP]:
		var button: Button = Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.icon = AppTheme.icon("zoom_out" if step < 1.0 else "zoom_in")
		AppTheme.frame(button)
		button.pressed.connect(func() -> void: _zoom_by(step))
		zoom.add_child(button)
		_zoom_buttons.append(button)
	_fit_button = Button.new()
	_fit_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_fit_button.focus_mode = Control.FOCUS_NONE
	AppTheme.frame(_fit_button)
	_fit_button.pressed.connect(func() -> void: canvas.fit())
	zoom.add_child(_fit_button)

	_build_room_panel()
	_name_picker = PopupMenu.new()
	_name_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name_picker.id_pressed.connect(_on_name_picked)
	add_child(_name_picker)
	_room_menu = PopupMenu.new()
	_room_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_room_menu.id_pressed.connect(_on_room_menu)
	add_child(_room_menu)
	canvas.room_drawn.connect(_pick_room_name)
	canvas.room_menu_requested.connect(_open_room_menu)
	_layer_picker = PopupMenu.new()
	_layer_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_layer_picker.id_pressed.connect(_on_layer_picked)
	add_child(_layer_picker)
	canvas.layer_menu_requested.connect(_open_layer_picker)
	_layer_dialog = ConfirmationDialog.new()
	_layer_name = LineEdit.new()
	_layer_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_layer_name.custom_minimum_size.x = 220.0
	_layer_name.max_length = FloorPlan.MAX_LAYER_NAME
	_layer_dialog.add_child(_layer_name)
	_layer_dialog.register_text_enter(_layer_name)
	_layer_dialog.confirmed.connect(_apply_layer_name)
	add_child(_layer_dialog)
	_length_dialog = ConfirmationDialog.new()
	var wall_box: VBoxContainer = VBoxContainer.new()
	_length_dialog.add_child(wall_box)
	_length_label = Label.new()
	_length_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_length_label.theme_type_variation = "HeaderLabel"
	wall_box.add_child(_length_label)
	var wall_grid: GridContainer = GridContainer.new()
	wall_grid.columns = 2
	wall_box.add_child(wall_grid)
	_length_field = _metres()
	_angle_field = SpinBox.new()
	_angle_field.min_value = -360.0
	_angle_field.max_value = 360.0
	_angle_field.step = 0.5
	_angle_field.suffix = "°"
	_thickness_field = _metres()
	_thickness_field.min_value = 0.0
	_thickness_field.max_value = FloorPlan.MAX_WALL_THICKNESS
	_align_field = OptionButton.new()
	_align_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for field: Control in [_length_field, _angle_field, _thickness_field, _align_field]:
		var label: Label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		wall_grid.add_child(label)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wall_grid.add_child(field)
		if field is SpinBox:
			_length_dialog.register_text_enter((field as SpinBox).get_line_edit())
	_align_label = wall_grid.get_child(6) as Label
	_length_dialog.confirmed.connect(_apply_length)
	add_child(_length_dialog)
	_door_dialog = ConfirmationDialog.new()
	var door_grid: GridContainer = GridContainer.new()
	door_grid.columns = 2
	_door_dialog.add_child(door_grid)
	_door_kind = OptionButton.new()
	_door_kind.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# Its width in cm, as doors are sold.
	_door_width = SpinBox.new()
	_door_width.min_value = FloorPlan.DOOR_MIN_WIDTH * 100.0
	_door_width.max_value = FloorPlan.DOOR_MAX_WIDTH * 100.0
	_door_width.step = 1.0
	_door_width.suffix = "cm"
	_door_width.custom_minimum_size.x = 120.0
	_door_dialog.register_text_enter(_door_width.get_line_edit())
	_door_double = CheckBox.new()
	_door_hinge = OptionButton.new()
	_door_hinge.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_door_side = OptionButton.new()
	_door_side.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for field: Control in [_door_kind, _door_width, _door_double, _door_hinge, _door_side]:
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
	_walls_default = CheckBox.new()
	walls_grid.add_child(Control.new())
	walls_grid.add_child(_walls_default)
	_walls_dialog.confirmed.connect(_apply_walls)
	add_child(_walls_dialog)
	_symbols_dialog = SymbolLibraryDialog.new()
	_symbols_dialog.symbol_saved.connect(_on_symbol_saved)
	add_child(_symbols_dialog)
	retranslate()


## The tools on tab [param tab] (see [constant TAB_BUILDING]), in their order.
func _tab_tools(tab: int) -> Array[Control]:
	match tab:
		TAB_BUILDING:
			return [_outline_button, _wall_button, _room_button, _presets, _join_button, _door_button, _window_button]
		TAB_ELECTRICS:
			return [_wire_button, _array_button, _symbols_button, _check_button]
	return [_dimension_button, _measure_button, _note_button]


## Shows the tools of tab [param tab]; a tool of another tab in use gives
## way to selecting.
func show_tab(tab: int) -> void:
	_tab = tab
	if not _tab_buttons.is_empty():
		_tab_buttons[tab].set_pressed_no_signal(true)
	var tools: Array[Control] = _tab_tools(tab)
	for button: Button in [_room_button, _outline_button, _wall_button, _door_button, _window_button, _wire_button, _join_button, _dimension_button, _measure_button, _note_button]:
		if button.button_pressed and not tools.has(button):
			_select_button.button_pressed = true
	refresh()
	tab_changed.emit(tab)


## One short sentence on the tool in use, for the status bar (what moving
## the view takes the main window adds).
func hint() -> String:
	match canvas.tool:
		FloorPlanCanvas.Tool.ROOM:
			return tr("Drag from corner to corner, or type the width and depth in mm")
		FloorPlanCanvas.Tool.OUTLINE:
			return tr("Click each corner; a click on the first, Enter or a right click closes the room")
		FloorPlanCanvas.Tool.WALL:
			return tr("Click where each wall starts and ends; a right click ends")
		FloorPlanCanvas.Tool.DOOR, FloorPlanCanvas.Tool.WINDOW:
			return tr("Click a wall to put it in; a double click on one sets it")
		FloorPlanCanvas.Tool.JOIN:
			return tr("Click two rooms that touch")
		FloorPlanCanvas.Tool.WIRE:
			return tr("Drag from a light switch to the luminaire it switches")
		FloorPlanCanvas.Tool.DIMENSION:
			return tr("Click a wall for its dimensions, or drag between two points")
		FloorPlanCanvas.Tool.MEASURE:
			return tr("Drag between two points to measure")
		FloorPlanCanvas.Tool.NOTE:
			return tr("Press where the note points and let go where its text goes")
		FloorPlanCanvas.Tool.PLACE, FloorPlanCanvas.Tool.PLACE_ROOM:
			return tr("Click where it goes; a right click ends")
		FloorPlanCanvas.Tool.SCALE:
			return tr("Click two points a known distance apart")
		FloorPlanCanvas.Tool.UNDERLAY:
			return tr("Drag the underlay into place")
	return tr("A click selects, a drag moves, a double click edits")


## The tab of the tools shown (see [constant TAB_BUILDING]).
func shown_tab() -> int:
	return _tab


## Zooms by [param factor] about the middle of the plan.
func _zoom_by(factor: float) -> void:
	var middle: Vector2 = canvas.size * 0.5
	var before: Vector2 = (middle - canvas.offset) / canvas.zoom
	canvas.zoom = clampf(canvas.zoom * factor, FloorPlanCanvas.MIN_ZOOM, FloorPlanCanvas.MAX_ZOOM)
	canvas.offset = middle - before * canvas.zoom
	canvas.queue_redraw()


## A drop-down list of the circuits under [param parent].
func _circuit_picker(parent: Control) -> OptionButton:
	var picker: OptionButton = OptionButton.new()
	picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# A long circuit name is cut, never widening the panel over the plan.
	picker.fit_to_longest_item = false
	picker.clip_text = true
	picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	picker.item_selected.connect(_on_circuit_chosen.bind(picker))
	parent.add_child(picker)
	return picker


## Puts the parts not on the plan and the circuit new parts go on under
## [param parent] (the palette's head of an installation), or back into the
## panel beside the plan for null.
func place_parts_head(parent: Control) -> void:
	var target: Control = parent if parent != null else _side
	if parts_head.get_parent() != target:
		parts_head.reparent(target)
		if parent == null:
			_side.move_child(parts_head, 0)
	refresh()


## The Drawing menu: the underlay and the layers as submenus, the room
## legend on the screen, the plan's settings.
func _fill_drawing_menu() -> void:
	var popup: PopupMenu = _drawing_menu.get_popup()
	popup.clear()
	popup.add_submenu_node_item(tr("Underlay"), _underlay_popup)
	popup.set_item_tooltip(popup.item_count - 1, tr("Underlay: the architect's drawing under the plan, to trace the walls over it (a PDF page saved as a PNG or JPG first); it does not print"))
	var layers: String = tr("Layers") + ("  (%s)" % canvas.active_layer if not canvas.active_layer.is_empty() else "")
	popup.add_submenu_node_item(layers, _layers_popup)
	popup.set_item_tooltip(popup.item_count - 1, tr("Layers: show or hide what is on each (on the screen and on the exported sheets) and choose the one new parts and furniture go on (dimensions and notes always go on their own); a right click on something puts it on another"))
	if canvas.installation():
		popup.add_separator()
		popup.add_check_item(tr("Room legend on the screen"), MENU_LEGEND)
		popup.set_item_checked(popup.item_count - 1, FloorPlanCanvas.room_legend_shown)
		popup.set_item_tooltip(popup.item_count - 1, tr("The table of the rooms (number, purpose, environment, illuminance) beside the plan; it is always on the exported sheet"))
	popup.add_separator()
	popup.add_item(tr("Plan settings…"), MENU_SETTINGS)
	popup.set_item_tooltip(popup.item_count - 1, tr("Plan settings: the thickness of the outside walls and of those between rooms, where north is, how large the symbols and texts are drawn"))


func _on_drawing_menu(id: int) -> void:
	match id:
		MENU_LEGEND:
			FloorPlanCanvas.room_legend_shown = not FloorPlanCanvas.room_legend_shown
			canvas.queue_redraw()
			defaults_changed.emit()
		MENU_SETTINGS:
			_ask_walls()


func _tool_button(icon_name: String, tool: FloorPlanCanvas.Tool, group: ButtonGroup) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.theme_type_variation = "ToolButton"
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.button_group = group
	button.icon = AppTheme.icon(icon_name, ICON_SIZE)
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
		# A new plan is built first; one with rooms is wired.
		_tab = TAB_ELECTRICS if canvas.installation() and not doc.floor_plan.rooms.is_empty() else TAB_BUILDING
		if not _tab_buttons.is_empty():
			_tab_buttons[_tab].set_pressed_no_signal(true)
		tab_changed.emit(_tab)
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
	unit_shown.emit(true)


## Back from the consumer unit to the plan.
func close_unit() -> void:
	if _unit != null:
		_unit.queue_free()
		_unit = null
	_body.visible = true
	refresh()
	unit_shown.emit(false)


## Whether the consumer unit is shown in place of the plan.
func unit_open() -> bool:
	return _unit != null


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
	# The consumer unit has its own heading; the plan's tools are for the plan.
	(_bar.get_parent() as Control).visible = plan_shown
	if _unit != null:
		_unit.heading = "%s %s" % [tr("Consumer unit"), FloorPlan.UNIT]
	var tools: bool = _editing and plan_shown
	for button: Control in [_select_button, _delete_button, _tabs_track, _drawing_menu]:
		button.visible = tools
	for gap: VSeparator in _tool_gaps:
		gap.visible = tools
	# The electrics' tab is a house installation's: lighting, symbols, the check.
	var installation: bool = canvas.installation()
	_tab_buttons[TAB_ELECTRICS].visible = installation
	if _tab == TAB_ELECTRICS and not installation:
		_tab = TAB_BUILDING
		_tab_buttons[_tab].set_pressed_no_signal(true)
	for tab: int in 3:
		for control: Control in _tab_tools(tab):
			control.visible = tools and tab == _tab
	# The layer new things go on, while the schematic has it (an undo may
	# have taken it away).
	if _document.plan_layer(canvas.active_layer) == null:
		canvas.active_layer = ""
	_drawing_menu.text = tr("Drawing")
	_update_array_button()
	_fill_floor_tabs()
	_fit_button.visible = plan_shown
	_side_panel.visible = _editing and plan_shown and (parts_head.get_parent() == _side or inspector.get_parent() == _side)
	_listed = _document.unplaced_parts()
	_list.clear()
	for designation: String in _listed:
		_list.add_item(_entry_text(designation))
	_list_hint.text = tr("Pick a part, then click where it goes: switches, sockets and appliances go onto the nearest wall, luminaires on the ceiling.")
	_update_parts_side()
	_fill_room()
	_fill_wall()
	_fill_check()
	_fill_part()
	canvas.queue_redraw()
	inspector_changed.emit()


## The simulation stepped: lights, sockets and appliances are drawn anew.
func show_step(result: StepResult) -> void:
	canvas.queue_redraw()
	if _unit != null:
		_unit.show_step(result)


func retranslate() -> void:
	var tab_names: Array[String] = [tr("Building"), tr("Electrics"), tr("Dimensions")]
	var tab_tips: Array[String] = [tr("Rooms, walls, doors, windows and furniture"), tr("The lighting, rows of parts, your own symbols and the check of the installation"), tr("Dimensions, measuring and notes")]
	for i: int in _tab_buttons.size():
		_tab_buttons[i].text = tab_names[i]
		_tab_buttons[i].tooltip_text = tab_tips[i]
	var names: Dictionary = {_outline_button: tr("Outline"), _wall_button: tr("Walls"), _room_button: tr("Room"), _join_button: tr("Join"),
		_door_button: tr("Door"), _window_button: tr("Window"), _wire_button: tr("Lighting"), _array_button: tr("Row"),
		_dimension_button: tr("Dimension"), _measure_button: tr("Measure"), _note_button: tr("Note")}
	for button: Button in names:
		button.text = names[button]
	_floor_menu.text = tr("Floor")
	_select_button.tooltip_text = tr("Select and move rooms, doors and parts; drag a room's edge to resize it")
	_room_button.tooltip_text = tr("Draw a room: drag from corner to corner, or click both corners; type its width, Tab, its depth in mm and Enter for an exact size; it snaps to the walls of the others")
	_door_button.tooltip_text = tr("Put a door in a wall by clicking it (of the kind chosen last); a double click on a door sets its kind, width, double door and swing; a selected door: drag the handle at the end of its leaf to another corner to turn it, F swaps its hinge, Shift+F opens it to the other side")
	_join_button.tooltip_text = tr("Join two rooms into one (an L-shaped room and the like): click one, then the other touching it")
	_window_button.tooltip_text = tr("Put a window in a wall by clicking it; a double click on a window sets its width, sill and height")
	_dimension_button.tooltip_text = tr("Dimensions printed with the plan: click a wall for a chain along it (corners, parts, doors and windows), or drag between two points; drag a dimension to set it off, Delete takes it away")
	_measure_button.tooltip_text = tr("Measure: drag between two points (corners, parts and the ends of doors and windows are caught) to see the distance; nothing is drawn")
	_scale_dialog.title = tr("Scale of the underlay")
	_scale_dialog.ok_button_text = tr("OK")
	_scale_dialog.cancel_button_text = tr("Cancel")
	(_scale_field.get_parent().get_child(0) as Label).text = tr("The two points are this far apart")
	_floor_menu.tooltip_text = tr("Floors: each its own plan and sheet")
	_floor_dialog.title = tr("Name of the floor")
	_floor_dialog.ok_button_text = tr("OK")
	_floor_dialog.cancel_button_text = tr("Cancel")
	_layer_dialog.ok_button_text = tr("OK")
	_layer_dialog.cancel_button_text = tr("Cancel")
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
	_drawing_menu.tooltip_text = tr("The underlay, the layers and the plan's settings")
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
	_walls_default.text = tr("Start new plans with these walls")
	var wall_labels: Array[String] = [tr("Outside walls"), tr("Walls between rooms"), tr("North (clockwise from up)"), tr("Size of the symbols"), tr("Size of the texts")]
	var walls_grid: GridContainer = _outer_wall.get_parent() as GridContainer
	for k: int in wall_labels.size():
		(walls_grid.get_child(2 * k) as Label).text = wall_labels[k]
	_door_dialog.title = tr("Door")
	_door_dialog.ok_button_text = tr("OK")
	_door_dialog.cancel_button_text = tr("Cancel")
	var door_labels: Array[String] = [tr("Kind"), tr("Width"), tr("Double door"), tr("Hinges or slides to"), tr("Opens")]
	var door_grid: GridContainer = _door_width.get_parent() as GridContainer
	_door_kind.clear()
	for kind_name: String in [tr("Hinged"), tr("Swinging both ways"), tr("Sliding along the wall"), tr("Sliding into the wall (pocket)"), tr("Folding"), tr("Garage (sectional)")]:
		_door_kind.add_item(kind_name)
	for k: int in door_labels.size():
		(door_grid.get_child(2 * k) as Label).text = door_labels[k]
	_door_hinge.clear()
	_door_hinge.add_item(tr("Left or top"))
	_door_hinge.add_item(tr("Right or bottom"))
	_door_side.clear()
	_door_side.add_item(tr("Down or left"))
	_door_side.add_item(tr("Up or right"))
	_wire_button.tooltip_text = tr("Draw the lighting: drag from a light switch (of two rockers, from the side of the one) to a luminaire it switches, or to the other switch of a staircase; it is wired by itself")
	var size_labels: Array[String] = [tr("Width"), tr("Depth")]
	var size_grid: GridContainer = _width_field.get_parent() as GridContainer
	for k: int in size_labels.size():
		(size_grid.get_child(k) as Label).text = size_labels[k]
	_length_dialog.title = tr("Wall")
	var wall_grid: GridContainer = _length_field.get_parent() as GridContainer
	var line_labels: Array[String] = [tr("Length"), tr("Direction"), tr("Thickness (0: the plan's)"), tr("Lies")]
	for k: int in line_labels.size():
		(wall_grid.get_child(2 * k) as Label).text = line_labels[k]
	_angle_field.tooltip_text = tr("Degrees anticlockwise from the right; another one turns the wall about its start, making it slant")
	_align_field.clear()
	for text: String in [tr("As suits (out of the way of a wall going on outside)"), tr("On the middle of the line"), tr("Into this room"), tr("Into the other room")]:
		_align_field.add_item(text)
	_length_dialog.ok_button_text = tr("OK")
	_length_dialog.cancel_button_text = tr("Cancel")
	_stairs_field.text = tr("Staircase")
	_stairs_field.tooltip_text = tr("Draws the stairs in the room: straight in a rectangle, turning in an L-shaped room")
	_stairs_reverse_field.text = tr("Up the other way")
	_number_field.tooltip_text = tr("Number")
	_electrics_caption.text = tr("Electrics").to_upper()
	var labels: Array[String] = [tr("Environment (ČSN 33 2000-5-51)"), tr("Illuminance (lx)")]
	for k: int in labels.size():
		(_room_fields.get_child(1 + 2 * k) as Label).text = labels[k]
	_size_caption.text = tr("Size").to_upper()
	_other_caption.text = tr("Other").to_upper()
	_room_duplicate.text = tr("Duplicate")
	_room_split.text = tr("Split")
	_room_delete.text = tr("Delete room")
	_influences_button.text = tr("List")
	_influences_button.tooltip_text = tr("The external influences of ČSN 33 2000-5-51 as a table: tick those of the room")
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
	_zoom_buttons[0].tooltip_text = tr("Zoom out")
	_zoom_buttons[1].tooltip_text = tr("Zoom in")
	_list_title.text = tr("Not on the plan").to_upper()
	_room_title.text = tr("Room").to_upper()
	_wall_thickness_label.text = tr("Thickness (0: the plan's)")
	_wall_open.text = tr("No wall (taken away)")
	_check_button.tooltip_text = tr("Check the installation: circuits not protected, socket circuits and bathrooms without a 30 mA residual current device, too many sockets on a circuit, switches and sockets in a bathroom's zones")
	_wall_edit.tooltip_text = tr("Length and direction of the wall (Enter)")
	_wall_delete.tooltip_text = tr("Take the wall away (Delete): the rooms on both sides become one, an outside wall leaves the room open; Ctrl+click selects more walls")
	_rename_field.placeholder_text = tr("Name of the room")
	_name_menu.tooltip_text = tr("A usual name: a bathroom, a kitchen, ... (in a house installation it sets the environment and illuminance)")
	_room_duplicate.tooltip_text = tr("Duplicate the room beside it (Ctrl+D); the arrow keys move a room (Shift: 50 cm)")
	_room_split.tooltip_text = tr("Split the room by a wall: draw it from one of its walls across the room to another, bent where clicked")
	_room_delete.tooltip_text = tr("Take the room away (what is in it stays)")
	_outline_button.tooltip_text = tr("Draw a room by its corners: click each corner (walls go across or up and down, with Shift slanting by 15°), or type a wall's length in mm and press Enter; a click on the first corner, a double click, Enter or a right click closes it")
	_wall_button.tooltip_text = tr("Draw walls: click where each wall starts and ends (by 15°, with Shift at any angle; type a length in mm and press Enter); they snap onto the rooms' walls. Walls drawn from a room's wall across the room to its wall split it; walls closing round a space become a room. A right click or Esc ends the walls being drawn")
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
	for button: Button in [_select_button, _room_button, _outline_button, _wall_button, _door_button, _window_button, _dimension_button, _measure_button, _note_button, _wire_button, _join_button]:
		button.set_pressed_no_signal(false)
	_list.deselect_all()
	canvas.grab_focus()


## Whether the parts' head is shown (the circuit new parts go on, those
## not on the plan yet): not while rooms are drawn or one is picked.
func _parts_side() -> bool:
	return canvas.tool not in ROOM_TOOLS and canvas.selected.get("kind", "") not in ["room", "edge"]


## The parts' head, shown or hidden by [method _parts_side]; the list of
## the parts not on the plan only while there are some.
func _update_parts_side() -> void:
	if _list == null:
		return
	var shown: bool = _parts_side() and _list.item_count > 0 and (_tab == TAB_ELECTRICS or not canvas.installation())
	for control: Control in [_list_title, _list, _list_hint]:
		control.visible = shown
	_fill_circuits()


## Whether [member inspector] has something to show: the check's results,
## the room or the walls picked.
func inspector_shown() -> bool:
	return _editing and _unit == null and (_check_box.visible or _room_box.visible or _wall_box.visible)


## The part selected on the plan ("" for none or the consumer unit).
func selected_part() -> String:
	return _selected_part()


## The part selected on the plan ("" for none or the consumer unit).
func _selected_part() -> String:
	var part: String = canvas.selected.get("designation", "") if canvas.selected.get("kind", "") == "part" else ""
	return "" if part == FloorPlan.UNIT else part


## The circuit picker of a residential installation in the parts' head:
## the one new parts go on.
func _fill_circuits() -> void:
	if _document == null or _circuit == null:
		return
	var shown: bool = canvas.installation() and _parts_side() and _tab == TAB_ELECTRICS
	for control: Control in [_circuit_title, _circuit, _circuit_note]:
		control.visible = shown
	if not shown:
		return
	_circuit_title.text = tr("New parts go on").to_upper()
	_circuits = _offer_circuits(_circuit, "")
	_circuit.select(maxi(_circuits.find(canvas.circuit), 0))
	_circuit_note.text = tr("Luminaires and switches on the lighting, sockets on a circuit of their room") if canvas.circuit == SingleLine.BY_KIND else ""
	_circuit_note.visible = not _circuit_note.text.is_empty()


## The circuit of the part selected, under its properties (an installation's).
func _fill_part() -> void:
	if part_box == null or _document == null:
		return
	var part: String = _selected_part()
	part_box.visible = _editing and _unit == null and canvas.installation() and not part.is_empty()
	if not part_box.visible:
		return
	_part_circuit_title.text = tr("Circuit")
	_part_circuits = _offer_circuits(_part_circuit, part)
	var fed: SingleLine.Feeder = _document.single_line.feeder_feeding(part)
	_part_circuit.select(maxi(_part_circuits.find(fed.number if fed != null else 0), 0))


## Fills [param picker] with the circuits by number, protected or waiting,
## no circuit and a new one (by kind first, for new parts: [param part]
## ""); returns the circuit number of each item.
func _offer_circuits(picker: OptionButton, part: String) -> PackedInt32Array:
	var line: SingleLine = _document.single_line
	var numbers: PackedInt32Array = PackedInt32Array()
	picker.clear()
	if part.is_empty():
		# The default: each part on a circuit by its kind.
		numbers.append(SingleLine.BY_KIND)
		picker.add_item(tr("By kind (lighting, sockets, appliances)"))
		picker.set_item_tooltip(0, tr("Luminaires and light switches go on the lighting circuit, sockets on a socket circuit of their room (up to %d sockets), large appliances on circuits of their own") % SingleLine.SOCKETS_PER_CIRCUIT)
	numbers.append(0)
	picker.add_item(tr("No circuit"))
	for f: SingleLine.Feeder in line.circuits():
		numbers.append(f.number)
		var by: String = ("-" + f.device) if not f.device.is_empty() else tr("not protected yet")
		picker.add_item("%s  [%s]" % [SingleLineView.circuit_text(f, _document), by])
	# A new circuit: the one picked for new parts that has nothing yet, else the next number.
	var current: int = canvas.circuit
	var fresh: int = current if current > 0 and not numbers.has(current) and part.is_empty() else line.next_number()
	numbers.append(fresh)
	picker.add_item(tr("New circuit %d") % fresh)
	return numbers


func _on_circuit_chosen(index: int, picker: OptionButton) -> void:
	if picker == _circuit:
		canvas.circuit = _circuits[index] if index < _circuits.size() else 0
		_fill_circuits()
		return
	var part: String = _selected_part()
	if part.is_empty():
		return
	# The selected part moves to the circuit chosen.
	var number: int = _part_circuits[index] if index < _part_circuits.size() else 0
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.single_line.feed(part, number))


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


## Ready room [param index] follows the mouse to be put where the plan is
## clicked (again until a right click or Esc).
func _add_preset(index: int) -> void:
	for button: Button in [_select_button, _room_button, _outline_button, _wall_button, _door_button, _window_button, _dimension_button, _measure_button, _note_button, _wire_button, _join_button]:
		button.set_pressed_no_signal(false)
	_list.deselect_all()
	canvas.begin_place_room(index)


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
	_free_wall = -1
	var plan: FloorPlan = _document.floor_plan
	var room: FloorPlan.Room = plan.rooms[index]
	var w: PackedVector2Array = room.wall(k)
	_length_label.text = tr("Wall of %s") % tr(room.name)
	_length_field.min_value = FloorPlan.MIN_WALL
	_length_field.value = w[0].distance_to(w[1])
	_angle_field.value = FloorPlan.wall_angle(w)
	_thickness_field.value = room.wall_thickness(k)
	var between: bool = false
	for piece: Dictionary in plan.wall_pieces():
		if int(piece["other"]) >= 0 and ((piece["room"] == index and piece["wall"] == k) or (piece["other"] == index and piece["other_wall"] == k)):
			between = true
	var own: float = plan.inner_wall if between else plan.outer_wall
	_thickness_field.get_line_edit().placeholder_text = String.num(own, 2)
	_align_label.visible = between
	_align_field.visible = between
	_align_field.select(room.wall_align(k))
	_length_dialog.reset_size()
	_length_dialog.popup_centered()
	_length_field.get_line_edit().select_all()
	_length_field.get_line_edit().grab_focus()


## Asks the length, direction and thickness of free wall [param index]
## (its start stays).
func _ask_free_wall(index: int) -> void:
	if not _editing or index < 0 or index >= _document.floor_plan.walls.size():
		return
	_free_wall = index
	var plan: FloorPlan = _document.floor_plan
	var wall: FloorPlan.Wall = plan.walls[index]
	_length_label.text = tr("Wall")
	_length_field.min_value = FloorPlan.MIN_WALL
	_length_field.value = wall.a.distance_to(wall.b)
	_angle_field.value = FloorPlan.wall_angle(PackedVector2Array([wall.a, wall.b]))
	_thickness_field.value = wall.thickness
	_thickness_field.get_line_edit().placeholder_text = String.num(plan.inner_wall, 2)
	_align_label.visible = false
	_align_field.visible = false
	_length_dialog.reset_size()
	_length_dialog.popup_centered()
	_length_field.get_line_edit().select_all()
	_length_field.get_line_edit().grab_focus()


func _apply_length() -> void:
	if _free_wall >= 0:
		var index: int = _free_wall
		if index >= _document.floor_plan.walls.size():
			return
		var length: float = _length_field.value
		var angle: float = _angle_field.value
		var thickness: float = _thickness_field.value
		var room_name: String = canvas._next_room_name()
		edit_requested.emit(func(doc: SchematicDocument) -> void:
			var wall: FloorPlan.Wall = doc.floor_plan.walls[index]
			wall.thickness = thickness
			doc.floor_plan.move_wall_end(index, 1, (wall.a + Vector2.from_angle(deg_to_rad(-angle)) * length).snappedf(0.001), room_name))
		return
	var wall: Vector2i = _length_wall
	if wall.x < 0 or wall.x >= _document.floor_plan.rooms.size():
		return
	var room: FloorPlan.Room = _document.floor_plan.rooms[wall.x]
	var w: PackedVector2Array = room.wall(wall.y)
	var length: float = _length_field.value
	var angle: float = _angle_field.value
	var thickness: float = _thickness_field.value
	var mode: int = _align_field.selected if _align_field.visible else room.wall_align(wall.y)
	var new_length: bool = not is_equal_approx(length, w[0].distance_to(w[1]))
	var new_angle: bool = absf(angle_difference(deg_to_rad(angle), deg_to_rad(FloorPlan.wall_angle(w)))) > 0.001
	var new_look: bool = not is_equal_approx(thickness, room.wall_thickness(wall.y)) or mode != room.wall_align(wall.y)
	if not (new_length or new_angle or new_look):
		return
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		if new_angle:
			doc.floor_plan.set_wall_angle(wall.x, wall.y, angle, length)
		elif new_length:
			doc.floor_plan.set_wall_length(wall.x, wall.y, length)
		if new_look:
			doc.floor_plan.set_wall_look(wall.x, wall.y, thickness, mode))


## Asks how door [param index] is: its kind, its width (cm), single or
## double, its hinge end (where it slides or folds to) and the side it
## opens to.
func _ask_door(index: int) -> void:
	if not _editing or index < 0 or index >= _document.floor_plan.doors.size():
		return
	_door = index
	var door: FloorPlan.Door = _document.floor_plan.doors[index]
	_door_kind.select(door.kind)
	_door_width.value = roundf(door.width * 100.0)
	_door_double.button_pressed = door.double
	_door_hinge.select(1 if door.hinge_end else 0)
	_door_side.select(1 if door.opens_back else 0)
	_door_dialog.reset_size()
	_door_dialog.popup_centered()


func _apply_door() -> void:
	var index: int = _door
	if index < 0 or index >= _document.floor_plan.doors.size():
		return
	var kind: int = maxi(_door_kind.selected, 0)
	var width: float = _door_width.value / 100.0
	var double: bool = _door_double.button_pressed
	var hinge_end: bool = _door_hinge.selected == 1
	var opens_back: bool = _door_side.selected == 1
	# The next door put in is of this kind too.
	canvas.door_kind = kind
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		var door: FloorPlan.Door = doc.floor_plan.doors[index]
		door.kind = kind
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
			# Drawn over the floor next to it: its outline and staircases.
			edit_requested.emit(func(doc: SchematicDocument) -> void:
				var next: FloorPlan = doc.floors[0] if below else doc.floors[doc.floors.size() - 1]
				doc.floor = doc.add_floor(below)
				doc.floor_plan.start_over(next))
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
	var popup: PopupMenu = _underlay_popup
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


func _fill_layers_menu() -> void:
	var popup: PopupMenu = _layers_popup
	popup.clear()
	var layers: Array[FloorPlan.Layer] = _document.plan_layers
	popup.add_separator(tr("Shown"))
	# The dimensions and notes' own layer, always there.
	popup.add_check_item(tr("Dimensions and notes"), 99)
	popup.set_item_checked(popup.item_count - 1, _document.annotations_shown)
	popup.set_item_tooltip(popup.item_count - 1, tr("Every dimension and note is on this layer; it cannot be renamed nor removed, nor anything else put on it"))
	for i: int in layers.size():
		popup.add_check_item(layers[i].name, 100 + i)
		popup.set_item_checked(popup.item_count - 1, layers[i].shown)
	if not layers.is_empty():
		popup.add_separator(tr("New things go on"))
		popup.add_radio_check_item(tr("No layer"), 200)
		popup.set_item_checked(popup.item_count - 1, canvas.active_layer.is_empty())
		for i: int in layers.size():
			popup.add_radio_check_item(layers[i].name, 201 + i)
			popup.set_item_checked(popup.item_count - 1, layers[i].name == canvas.active_layer)
		popup.add_separator()
	popup.add_item(tr("New layer…"), 0)
	if not canvas.active_layer.is_empty():
		popup.add_item(tr("Rename the layer %s…") % canvas.active_layer, 1)
		popup.add_item(tr("Remove the layer %s (what is on it stays, on no layer)") % canvas.active_layer, 2)
	if not _document.annotations_shown or layers.any(func(layer: FloorPlan.Layer) -> bool: return not layer.shown):
		popup.add_item(tr("Show all layers"), 3)


func _on_layers_menu(id: int) -> void:
	var active: String = canvas.active_layer
	var count: int = _document.plan_layers.size()
	if id == 99:
		var shown_now: bool = not _document.annotations_shown
		if not shown_now and str(canvas.selected.get("kind", "")) in ["note", "dimension"]:
			canvas.selected = {}
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.annotations_shown = shown_now)
		return
	if id >= 100 and id < 100 + count:
		# Hidden, what is on it is neither drawn nor picked: nor the
		# selection, nor the layer new things go on.
		var toggled: String = _document.plan_layers[id - 100].name
		var shown: bool = not _document.plan_layers[id - 100].shown
		if not shown:
			canvas.selected = {}
			if toggled == active:
				canvas.active_layer = ""
		edit_requested.emit(func(doc: SchematicDocument) -> void: doc.plan_layer(toggled).shown = shown)
		return
	if id >= 200 and id <= 200 + count:
		# New things go on it, shown so they are seen.
		var chosen: String = _document.plan_layers[id - 201].name if id > 200 else ""
		canvas.active_layer = chosen
		if _document.layer_shown(chosen):
			refresh()
		else:
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.plan_layer(chosen).shown = true)
		return
	match id:
		0:
			_ask_layer_name("new")
		1:
			_ask_layer_name("rename")
		2:
			canvas.active_layer = ""
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.remove_plan_layer(active))
		3:
			edit_requested.emit(func(doc: SchematicDocument) -> void:
				doc.annotations_shown = true
				for layer: FloorPlan.Layer in doc.plan_layers:
					layer.shown = true)


## Asks the name of a layer: [param asked] "new", "move" (a new one the
## selection goes on) or "rename" (the active one).
func _ask_layer_name(asked: String) -> void:
	_layer_asked = asked
	_layer_dialog.title = tr("Rename the layer") if asked == "rename" else tr("New layer")
	_layer_name.text = canvas.active_layer if asked == "rename" else ""
	_layer_dialog.reset_size()
	_layer_dialog.popup_centered()
	_layer_name.select_all()
	_layer_name.grab_focus()


## The name typed: a new layer (the active one, or the selection's), or
## the active one renamed; an empty name or one taken changes nothing.
func _apply_layer_name() -> void:
	var layer_name: String = _layer_name.text.strip_edges().left(FloorPlan.MAX_LAYER_NAME)
	if layer_name.is_empty() or _document.plan_layer(layer_name) != null:
		return
	match _layer_asked:
		"rename":
			var old_name: String = canvas.active_layer
			canvas.active_layer = layer_name
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.rename_plan_layer(old_name, layer_name))
		"move":
			var item: Dictionary = canvas.selected
			edit_requested.emit(func(doc: SchematicDocument) -> void:
				doc.add_plan_layer(layer_name)
				doc.floor_plan.set_item_layer(str(item.get("kind", "")), int(item.get("index", -1)), str(item.get("designation", "")), layer_name))
		_:
			canvas.active_layer = layer_name
			edit_requested.emit(func(doc: SchematicDocument) -> void: doc.add_plan_layer(layer_name))


## The layers the selection (right-clicked) can go on, its own ticked.
func _open_layer_picker(_at: Vector2) -> void:
	var item: Dictionary = canvas.selected
	var current: String = _document.floor_plan.item_layer(str(item.get("kind", "")), int(item.get("index", -1)), str(item.get("designation", "")))
	_layer_picker.clear()
	_layer_picker.add_separator(tr("Layer"))
	_layer_picker.add_radio_check_item(tr("No layer"), 0)
	_layer_picker.set_item_checked(_layer_picker.item_count - 1, current.is_empty())
	for i: int in _document.plan_layers.size():
		var layer: FloorPlan.Layer = _document.plan_layers[i]
		_layer_picker.add_radio_check_item(layer.name if layer.shown else tr("%s (hidden)") % layer.name, 1 + i)
		_layer_picker.set_item_checked(_layer_picker.item_count - 1, layer.name == current)
	_layer_picker.add_separator()
	_layer_picker.add_item(tr("New layer…"), 1000)
	AppTheme.popup_at_mouse(_layer_picker)


func _on_layer_picked(id: int) -> void:
	if id == 1000:
		_ask_layer_name("move")
		return
	var layer_name: String = _document.plan_layers[id - 1].name if id > 0 and id <= _document.plan_layers.size() else ""
	var item: Dictionary = canvas.selected
	if not _document.layer_shown(layer_name):
		# Gone from sight with its layer.
		canvas.selected = {}
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.set_item_layer(str(item.get("kind", "")), int(item.get("index", -1)), str(item.get("designation", "")), layer_name))


func _deselect_tools() -> void:
	for button: Button in [_select_button, _room_button, _outline_button, _wall_button, _door_button, _window_button, _dimension_button, _measure_button, _note_button, _wire_button, _join_button]:
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
	var feeder: int = canvas.circuit
	var points: PackedVector2Array
	var face: int = -1
	if _array_target["kind"] == "room":
		points = plan.grid_points(index, int(_array_rows.value), int(_array_columns.value))
	else:
		var k: int = _array_target["side"]
		var spacing: float = _array_spacing.value / 1000.0
		points = plan.row_points(index, k, int(_array_count.value), _array_start.value / 1000.0 if spacing > 0.0 else 0.0, spacing)
		face = maxi(FloorPlan.FACING.find(plan.rooms[index].inward(k)), 0)
	var layer: String = canvas.new_layer()
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		for p: Vector2 in points:
			doc.floor_plan.set_part_layer(FloorPlanCanvas.add_part(doc, template, feeder, p, face >= 0, face), layer))


## Asks the thickness of the outside walls and of those between rooms.
func _ask_walls() -> void:
	if not _editing:
		return
	_outer_wall.value = _document.floor_plan.outer_wall
	_inner_wall.value = _document.floor_plan.inner_wall
	_north.value = _document.floor_plan.north
	_symbol_size.value = _document.floor_plan.symbol_scale * 100.0
	_text_size.value = _document.floor_plan.text_scale * 100.0
	_walls_default.button_pressed = false
	_walls_dialog.reset_size()
	_walls_dialog.popup_centered()


func _apply_walls() -> void:
	var outer: float = _outer_wall.value
	var inner: float = _inner_wall.value
	var north: float = _north.value
	var symbols: float = _symbol_size.value / 100.0
	var texts: float = _text_size.value / 100.0
	if _walls_default.button_pressed:
		FloorPlan.default_outer = outer
		FloorPlan.default_inner = inner
		defaults_changed.emit()
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		doc.floor_plan.outer_wall = outer
		doc.floor_plan.inner_wall = inner
		doc.floor_plan.north = north
		# The sizes for every floor alike.
		for plan: FloorPlan in doc.floors:
			plan.symbol_scale = symbols
			plan.text_scale = texts)


## The room panel at the top of the side panel (shown while a room is
## picked in Edit mode).
func _build_room_panel() -> void:
	_room_box = VBoxContainer.new()
	_room_box.add_theme_constant_override("separation", 6)
	inspector.add_child(_room_box)
	_room_title = Label.new()
	_room_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_room_title.theme_type_variation = "HeaderLabel"
	_room_box.add_child(_room_title)
	# Its number (an installation's) and name in one row.
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	_room_box.add_child(name_row)
	_number_field = LineEdit.new()
	_number_field.custom_minimum_size.x = 56.0
	_number_field.text_submitted.connect(func(_text: String) -> void: _apply_rename())
	_number_field.focus_exited.connect(_apply_rename)
	name_row.add_child(_number_field)
	_rename_field = LineEdit.new()
	_rename_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rename_field.text_submitted.connect(func(_text: String) -> void: _apply_rename())
	_rename_field.focus_exited.connect(_apply_rename)
	name_row.add_child(_rename_field)
	_name_menu = MenuButton.new()
	_name_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name_menu.flat = false
	_name_menu.theme_type_variation = "ToolButton"
	_name_menu.icon = AppTheme.icon("chevron_down")
	_name_menu.about_to_popup.connect(func() -> void: _fill_names(_name_menu.get_popup(), false))
	_name_menu.get_popup().id_pressed.connect(func(id: int) -> void: _set_room_name(_renaming, _usual_names()[id]))
	name_row.add_child(_name_menu)
	# Its inside, as typed lengths, side by side.
	_size_caption = _room_caption()
	var size_fields: GridContainer = GridContainer.new()
	size_fields.columns = 2
	size_fields.add_theme_constant_override("h_separation", 6)
	_room_box.add_child(size_fields)
	_width_field = _metres()
	_height_field = _metres()
	for field: SpinBox in [_width_field, _height_field]:
		var label: Label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.theme_type_variation = "CaptionLabel"
		size_fields.add_child(label)
	for field: SpinBox in [_width_field, _height_field]:
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.value_changed.connect(func(_value: float) -> void: _apply_rename())
		size_fields.add_child(field)
	_area_label = Label.new()
	_area_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_area_label.theme_type_variation = "MutedLabel"
	_room_box.add_child(_area_label)
	# A residential installation's room: its environment and illuminance,
	# each label over its field: the panel stays narrow.
	_room_fields = GridContainer.new()
	_room_fields.columns = 1
	_room_box.add_child(_room_fields)
	_electrics_caption = Label.new()
	_electrics_caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_electrics_caption.theme_type_variation = "HeaderLabel"
	_room_fields.add_child(_electrics_caption)
	_environment_field = OptionButton.new()
	_environment_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_environment_field.fit_to_longest_item = false
	_environment_field.clip_text = true
	_environment_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer_environments("")
	# Beside it the List button: the table of every influence to tick.
	var environment_row: HBoxContainer = HBoxContainer.new()
	environment_row.add_theme_constant_override("separation", 4)
	environment_row.add_child(_environment_field)
	_influences_button = Button.new()
	_influences_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_influences_button.icon = AppTheme.icon("list", 16)
	_influences_button.pressed.connect(func() -> void: _influences_dialog.open(_chosen_environment()))
	environment_row.add_child(_influences_button)
	_influences_dialog = InfluencesDialog.new()
	_influences_dialog.chosen.connect(func(codes: PackedStringArray) -> void:
		_show_environment(FloorPlan.with_influences(_chosen_environment(), codes))
		_apply_rename())
	add_child(_influences_dialog)
	_lux_field = LineEdit.new()
	_lux_field.text_submitted.connect(func(_text: String) -> void: _apply_rename())
	_lux_field.focus_exited.connect(_apply_rename)
	for field: Control in [environment_row, _lux_field]:
		var label: Label = Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.theme_type_variation = "CaptionLabel"
		_room_fields.add_child(label)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_room_fields.add_child(field)
	# What the environment means: in the field's tooltip and the list's.
	_environment_note = Label.new()
	_environment_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_environment_note.theme_type_variation = "MutedLabel"
	_environment_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_environment_note.custom_minimum_size.x = 180.0
	_environment_note.visible = false
	_room_box.add_child(_environment_note)
	_environment_field.item_selected.connect(func(_index: int) -> void:
		_environment_note.text = FloorPlan.environment_note(_chosen_environment())
		_apply_rename())
	# A staircase: its stairs drawn in it.
	_other_caption = _room_caption()
	_stairs_field = CheckBox.new()
	_stairs_field.toggled.connect(func(_on: bool) -> void: _apply_rename())
	_room_box.add_child(_stairs_field)
	_stairs_reverse_field = CheckBox.new()
	_stairs_reverse_field.toggled.connect(func(_on: bool) -> void: _apply_rename())
	_room_box.add_child(_stairs_reverse_field)
	# What can be done with it, named.
	var actions: GridContainer = GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 4)
	actions.add_theme_constant_override("v_separation", 4)
	_room_box.add_child(actions)
	_room_duplicate = _room_button_named(actions, "duplicate", func() -> void: _duplicate_room(_renaming))
	_room_split = _room_button_named(actions, "room_split", func() -> void:
		show_tab(TAB_BUILDING)
		_wall_button.button_pressed = true)
	_room_delete = _room_button_named(actions, "delete", func() -> void: canvas.delete_selected())
	_room_delete.add_theme_color_override("font_color", AppTheme.danger)
	canvas.selection_changed.connect(_fill_room)
	_build_wall_panel()
	_build_check_panel()


## A heading of the room panel (its text set by [method retranslate]).
func _room_caption() -> Label:
	var caption: Label = Label.new()
	caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	caption.theme_type_variation = "HeaderLabel"
	_room_box.add_child(caption)
	return caption


## A button with icon [param icon_name] and a text (set by [method retranslate]).
func _room_button_named(parent: Control, icon_name: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.focus_mode = Control.FOCUS_NONE
	button.icon = AppTheme.icon(icon_name, 16)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AppTheme.frame(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## The problems the check of the installation found, each a button that
## selects the parts it is about.
func _build_check_panel() -> void:
	_check_box = VBoxContainer.new()
	_check_box.add_theme_constant_override("separation", 4)
	_check_box.visible = false
	inspector.add_child(_check_box)
	inspector.move_child(_check_box, 0)
	var header: HBoxContainer = HBoxContainer.new()
	_check_box.add_child(header)
	_check_title = Label.new()
	_check_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_check_title.theme_type_variation = "HeaderLabel"
	_check_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_check_title)
	var close: Button = Button.new()
	close.theme_type_variation = "ToolButton"
	close.focus_mode = Control.FOCUS_NONE
	close.icon = AppTheme.icon("close", 14)
	close.pressed.connect(func() -> void:
		_check_box.visible = false
		inspector_changed.emit())
	header.add_child(close)
	_check_list = VBoxContainer.new()
	_check_box.add_child(_check_list)
	_check_box.add_child(HSeparator.new())


## The check run again (while its results show).
func _fill_check() -> void:
	if _check_box == null or _document == null:
		return
	# How many problems there are, on the button, whether or not they show.
	var issues: Array[Dictionary] = []
	if canvas.installation():
		issues = InstallationCheck.run(_document)
	_check_button.text = tr("Check") + ("  (%d)" % issues.size() if not issues.is_empty() else "")
	if issues.is_empty():
		_check_button.remove_theme_color_override("font_color")
	else:
		_check_button.add_theme_color_override("font_color", AppTheme.warning)
	if not _check_box.visible:
		return
	# Freed once the click on one of them is over.
	for child: Node in _check_list.get_children():
		_check_list.remove_child(child)
		child.queue_free()
	_check_title.text = (tr("Check") if issues.is_empty() else tr_n("Check: %d problem", "Check: %d problems", issues.size()) % issues.size()).to_upper()
	if issues.is_empty():
		var fine: Label = Label.new()
		fine.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		fine.theme_type_variation = "MutedLabel"
		fine.text = tr("No problems found.")
		_check_list.add_child(fine)
	for issue: Dictionary in issues:
		var row: Button = Button.new()
		row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.theme_type_variation = "ListButton"
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(180, 0)
		row.text = tr(issue["text"]) % issue["args"]
		var ids: PackedStringArray = issue["ids"]
		row.pressed.connect(func() -> void: _show_issue(ids))
		_check_list.add_child(row)


## The first part of a problem that is on a plan shown and selected.
func _show_issue(ids: PackedStringArray) -> void:
	for designation: String in ids:
		var on: int = _document.floor_of(designation)
		if on < 0:
			continue
		if on != _document.floor:
			show_floor(on)
		canvas.selected = {"kind": "part", "designation": designation}
		canvas.queue_redraw()
		return


## The panel of the walls selected: their own thickness for all of them,
## an outside wall taken away (open) or put back, the length and direction
## of one, Delete.
func _build_wall_panel() -> void:
	_wall_box = VBoxContainer.new()
	_wall_box.add_theme_constant_override("separation", 4)
	inspector.add_child(_wall_box)
	_wall_title = Label.new()
	_wall_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_wall_title.theme_type_variation = "HeaderLabel"
	_wall_box.add_child(_wall_title)
	_wall_thickness_label = Label.new()
	_wall_thickness_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_wall_box.add_child(_wall_thickness_label)
	_wall_thickness = SpinBox.new()
	_wall_thickness.min_value = 0.0
	_wall_thickness.max_value = FloorPlan.MAX_WALL_THICKNESS
	_wall_thickness.step = 0.01
	_wall_thickness.suffix = "m"
	_wall_thickness.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wall_thickness.value_changed.connect(_apply_wall_thickness)
	_wall_box.add_child(_wall_thickness)
	_wall_open = CheckBox.new()
	_wall_open.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_wall_open.toggled.connect(_apply_wall_open)
	_wall_box.add_child(_wall_open)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	_wall_box.add_child(actions)
	_wall_edit = _room_action(actions, "plan_dimension", func() -> void:
		var walls: Array[Vector2i] = canvas.selected_walls()
		if not walls.is_empty():
			_ask_length(walls[0].x, walls[0].y))
	_wall_delete = _room_action(actions, "delete", func() -> void: canvas.delete_selected())
	_wall_box.add_child(HSeparator.new())
	canvas.selection_changed.connect(_fill_wall)


## The wall panel for the walls selected (hidden for none).
func _fill_wall() -> void:
	if _wall_box == null or _document == null:
		return
	var walls: Array[Vector2i] = canvas.selected_walls()
	var shown: bool = _editing and _unit == null and not walls.is_empty()
	_wall_box.visible = shown
	if not shown:
		return
	var plan: FloorPlan = _document.floor_plan
	_filling_wall = true
	_wall_title.text = (tr("Wall") if walls.size() == 1 else tr("Walls (%d)") % walls.size()).to_upper()
	var first: FloorPlan.Room = plan.rooms[walls[0].x]
	_wall_thickness.set_value_no_signal(first.wall_thickness(walls[0].y))
	_wall_thickness.get_line_edit().text = String.num(first.wall_thickness(walls[0].y), 2) + " m"
	var outside: bool = true
	var all_open: bool = true
	for wall_at: Vector2i in walls:
		if plan.room_behind(wall_at.x, wall_at.y) >= 0:
			outside = false
		if not plan.rooms[wall_at.x].is_open(wall_at.y):
			all_open = false
	_wall_thickness.get_line_edit().placeholder_text = String.num(plan.outer_wall if outside else plan.inner_wall, 2)
	_wall_open.visible = outside
	_wall_open.set_pressed_no_signal(all_open)
	_wall_edit.visible = walls.size() == 1
	_filling_wall = false


## The thickness typed given to every wall selected (0: the plan's).
func _apply_wall_thickness(value: float) -> void:
	if _filling_wall:
		return
	var walls: Array[Vector2i] = canvas.selected_walls()
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		for wall_at: Vector2i in walls:
			var room: FloorPlan.Room = doc.floor_plan.rooms[wall_at.x]
			doc.floor_plan.set_wall_look(wall_at.x, wall_at.y, value, room.wall_align(wall_at.y)))


## The outside walls selected taken away (open) or put back.
func _apply_wall_open(on: bool) -> void:
	if _filling_wall:
		return
	var walls: Array[Vector2i] = canvas.selected_walls()
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		for wall_at: Vector2i in walls:
			doc.floor_plan.rooms[wall_at.x].set_open(wall_at.y, on))


func _room_action(row: HBoxContainer, icon_name: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.theme_type_variation = "ToolButton"
	button.focus_mode = Control.FOCUS_NONE
	button.icon = AppTheme.icon(icon_name, ICON_SIZE)
	button.pressed.connect(action)
	row.add_child(button)
	return button


## The room panel for the room picked (hidden for none); a field being
## typed in is left as it is.
func _fill_room() -> void:
	if _room_box == null or _document == null:
		return
	var plan: FloorPlan = _document.floor_plan
	var index: int = canvas.selected.get("index", -1) if canvas.selected.get("kind", "") == "room" else -1
	var shown: bool = _editing and _unit == null and index >= 0 and index < plan.rooms.size()
	_room_box.visible = shown
	if not shown:
		_renaming = -1
		return
	var changed_room: bool = index != _renaming
	_renaming = index
	var room: FloorPlan.Room = plan.rooms[index]
	_filling_room = true
	if changed_room or not _rename_field.has_focus():
		_rename_field.text = tr(room.name)
	# Width and depth of a rectangle; an L's walls are dragged or typed one by one.
	(_width_field.get_parent() as Control).visible = room.is_rectangle()
	_size_caption.visible = room.is_rectangle()
	_width_field.set_value_no_signal(room.rect.size.x)
	_height_field.set_value_no_signal(room.rect.size.y)
	_width_field.get_line_edit().text = String.num(room.rect.size.x, 2) + " m"
	_height_field.get_line_edit().text = String.num(room.rect.size.y, 2) + " m"
	_area_label.text = tr("Area %s m²") % String.num(room.area(), 2) + ("" if room.is_rectangle() else "  ·  %s × %s m" % [String.num(room.rect.size.x, 2), String.num(room.rect.size.y, 2)])
	_room_fields.visible = canvas.installation()
	_number_field.visible = _room_fields.visible
	if changed_room or not _number_field.has_focus():
		_number_field.text = room.number
	_number_field.placeholder_text = plan.room_number(index)
	_show_environment(plan.room_environment(index))
	if changed_room or not _lux_field.has_focus():
		_lux_field.text = room.lux
	_lux_field.placeholder_text = plan.room_lux(index)
	_stairs_field.set_pressed_no_signal(room.stairs)
	_stairs_reverse_field.set_pressed_no_signal(room.stairs_reverse)
	_stairs_reverse_field.visible = room.stairs
	_filling_room = false


## Room [param index] picked and its name ready to be typed (a double click on it).
func _ask_rename(index: int) -> void:
	canvas.selected = {"kind": "room", "index": index}
	_fill_room()
	_rename_field.grab_focus()
	_rename_field.select_all()


## What the room panel says, taken into the room picked (one edit, only
## when something changed).
func _apply_rename() -> void:
	if _filling_room or _document == null:
		return
	var index: int = _renaming
	var plan: FloorPlan = _document.floor_plan
	if index < 0 or index >= plan.rooms.size():
		return
	var room: FloorPlan.Room = plan.rooms[index]
	var typed: String = _rename_field.text.strip_edges()
	# The name as it was (perhaps shown translated) is kept as it is.
	var room_name: String = room.name if typed.is_empty() or typed == tr(room.name) else typed
	var number: String = _number_field.text.strip_edges()
	var environment: String = _chosen_environment()
	var lux: String = _lux_field.text.strip_edges()
	var details: bool = canvas.installation()
	var size: Vector2 = Vector2(_width_field.value, _height_field.value)
	var resized: bool = room.is_rectangle() and not room.rect.size.is_equal_approx(size)
	var stairs: bool = _stairs_field.button_pressed
	var stairs_reverse: bool = _stairs_reverse_field.button_pressed
	var same: bool = room_name == room.name and not resized and stairs == room.stairs and stairs_reverse == room.stairs_reverse
	if details:
		same = same and number == room.number and lux == room.lux and environment == plan.room_environment(index)
	if same:
		return
	edit_requested.emit(func(doc: SchematicDocument) -> void:
		var edited: FloorPlan.Room = doc.floor_plan.rooms[index]
		edited.name = room_name
		edited.stairs = stairs
		edited.stairs_reverse = stairs_reverse
		if resized:
			doc.floor_plan.resize_room(index, size)
		if details:
			edited.number = number
			edited.lux = lux
			# The usual one for the room is kept as none set.
			edited.environment = ""
			if environment != doc.floor_plan.room_environment(index):
				edited.environment = environment)
	_fill_room()


## The environments offered: [constant FloorPlan.ENVIRONMENTS], then
## [param own] when it is none of them.
func _offer_environments(own: String) -> void:
	_own_environment = "" if FloorPlan.ENVIRONMENTS.has(own) else own
	_environment_field.clear()
	for environment: String in FloorPlan.ENVIRONMENTS:
		_environment_field.add_item(environment)
	if not _own_environment.is_empty():
		_environment_field.add_item(_own_environment)
		_environment_field.set_item_tooltip(FloorPlan.ENVIRONMENTS.size(), _own_environment)


## [param environment] picked in the room panel, with what it means under it.
func _show_environment(environment: String) -> void:
	_offer_environments(environment)
	var index: int = FloorPlan.ENVIRONMENTS.find(environment)
	_environment_field.select(index if index >= 0 else FloorPlan.ENVIRONMENTS.size())
	_environment_note.text = FloorPlan.environment_note(environment)
	_environment_field.tooltip_text = environment + ("\n" + _environment_note.text if not _environment_note.text.is_empty() else "")


## The environment picked in the room panel.
func _chosen_environment() -> String:
	var index: int = maxi(_environment_field.selected, 0)
	return FloorPlan.ENVIRONMENTS[index] if index < FloorPlan.ENVIRONMENTS.size() else _own_environment


## The usual names of rooms (English source text), each once.
static func _usual_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for preset: Dictionary in FloorPlan.PRESETS:
		if not names.has(preset["name"]):
			names.append(preset["name"])
	for more: String in ["Dining room", "Children's room", "Study", "Utility room", "Storeroom", "Garage", "Staircase", "Corridor"]:
		names.append(more)
	return names


## [param popup] filled with the usual names (ids their index), with
## [param other] a last item to type another.
func _fill_names(popup: PopupMenu, other: bool) -> void:
	popup.clear()
	var names: PackedStringArray = _usual_names()
	for i: int in names.size():
		popup.add_item(tr(names[i]), i)
	if other:
		popup.add_separator()
		popup.add_item(tr("Another name…"), names.size())


## Room [param index] named [param room_name] (one edit).
func _set_room_name(index: int, room_name: String) -> void:
	if _document == null or index < 0 or index >= _document.floor_plan.rooms.size():
		return
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.rooms[index].name = room_name)
	_renaming = -1
	_fill_room()


## Room [param index] was just drawn: the usual names offered at the mouse.
func _pick_room_name(index: int) -> void:
	_menu_room = index
	_fill_names(_name_picker, true)
	if _name_picker.is_inside_tree():
		AppTheme.popup_at_mouse(_name_picker)


func _on_name_picked(id: int) -> void:
	var names: PackedStringArray = _usual_names()
	if id < names.size():
		_set_room_name(_menu_room, names[id])
	else:
		_ask_rename(_menu_room)


## The menu of room [param index], right-clicked at screen point [param _at].
func _open_room_menu(index: int, _at: Vector2) -> void:
	_menu_room = index
	_room_menu.clear()
	_room_menu.add_item(tr("Rename…"), 0)
	_room_menu.add_item(tr("Duplicate") + "\tCtrl+D", 1)
	_room_menu.add_item(tr("Split by a wall"), 2)
	_room_menu.add_item(tr("Join with another room…"), 3)
	_room_menu.add_separator()
	_room_menu.add_item(tr("Delete"), 4)
	AppTheme.popup_at_mouse(_room_menu)


func _on_room_menu(id: int) -> void:
	var index: int = _menu_room
	if index < 0 or index >= _document.floor_plan.rooms.size():
		return
	match id:
		0:
			_ask_rename(index)
		1:
			_duplicate_room(index)
		2:
			_wall_button.button_pressed = true
		3:
			_join_button.button_pressed = true
			canvas.begin_join(index)
		4:
			canvas.selected = {"kind": "room", "index": index}
			canvas.delete_selected()


## A copy of room [param index] beside it, picked.
func _duplicate_room(index: int) -> void:
	if _document == null or index < 0 or index >= _document.floor_plan.rooms.size():
		return
	var twin: int = _document.floor_plan.rooms.size()
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.floor_plan.duplicate_room(index))
	canvas.selected = {"kind": "room", "index": twin}
