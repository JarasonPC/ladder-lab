extends SceneTree
## Takes the screenshots shown in README.md (docs/screenshots/): built-in
## examples simulated with the breakers switched on and the start button
## pressed, in the dark theme on white schematic paper: the schematic with the
## timing chart and event log, the switchboard and a control station (on the
## dark background of the interface), and the PLC
## window with the ladder diagram running. User settings are not changed.
## Needs a display (xvfb-run on a server):
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tools/screenshot_readme.gd -- [out_dir]

const SIZE: Vector2i = Vector2i(1600, 900)
const STAR_DELTA: int = 5
const FORWARD_REVERSE: int = 1
const PLC_EXAMPLE: int = 14

var out_dir: String = "res://docs/screenshots/"
var main: Node
var view: SchematicView


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	DisplayServer.window_set_size(SIZE)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	# No start window over the pictures.
	(main.get("_start_dialog") as Window).hide()
	await _frames(5)
	# The look of the README, whatever the user settings say.
	TranslationServer.set_locale("en")
	main.call("_retranslate")
	main.set("_theme_variant", AppTheme.Variant.DARK)
	main.set("_white_paper", true)
	main.set("_current_view", false)
	main.set("_wire_numbers", true)
	main.set("_path_numbers", true)
	main.call("_apply_theme")
	get_root().content_scale_factor = 1.0
	view = main.get("view")

	# Star/delta start: the schematic with the timing chart and event log.
	main.set("_show_chart", true)
	main.set("_show_log", true)
	(main.get("_edit_button") as Button).set_pressed_no_signal(false)
	(main.get("_simulate_button") as Button).set_pressed_no_signal(true)
	main.call("_set_mode", 1)
	await _example(STAR_DELTA)
	var timing: TimingPanel = main.get("_timing_panel")
	var spans: OptionButton = timing.get("_window_select")
	spans.select(TimingPanel.WINDOWS.find(10.0))
	spans.item_selected.emit(spans.selected)
	await _start(3.0)
	await _save("schematic")

	# Its switchboard, the timing panel rolled in.
	main.set("_show_chart", false)
	main.set("_show_log", false)
	main.call("_set_area", 1)
	RenderingServer.set_default_clear_color(AppTheme.bg0)
	var workspace: WorkspaceView = main.get("_workspace")
	workspace.open(Workspace.Place.SWITCHBOARD, view.document.switchboards[0].name)
	await _frames(30)
	await _save("switchboard")

	# Forward/reverse: the control station with the forward lamp lit.
	await _example(FORWARD_REVERSE)
	workspace.open(Workspace.Place.STATION, view.document.control_boxes[0].name)
	await _start(1.0)
	await _save("station")

	# PLC: the ladder diagram running, the on-delay elapsed.
	main.call("_set_area", 0)
	RenderingServer.set_default_clear_color(SchematicTheme.BACKGROUND)
	await _example(PLC_EXAMPLE)
	var edit_doc: SchematicDocument = main.get("edit_doc")
	for c: CircuitComponent in edit_doc.circuit.get_components():
		if c is Plc:
			(c as Plc).program.language = PlcProgram.Language.LAD
	main.call("_start_simulation")
	await _frames(5)
	await _start(6.0)
	var plc_id: String = ""
	for c: CircuitComponent in view.document.circuit.get_components():
		if c is Plc:
			plc_id = c.id
	var window: PlcWindow = main.call("open_plc_window", plc_id)
	window.content_scale_factor = 1.0
	await _frames(5)
	window.size = Vector2i(1280, 720)
	await _frames(30)
	await _save("plc", window)
	quit()


## Loads built-in example [param index] (simulating, as the mode is).
func _example(index: int) -> void:
	main.call("_replace_document", ExampleCircuits.build(index, (main.get("_layout_select") as OptionButton).selected == 1), "")
	await _frames(10)


## Switches on the breakers and fuse holders, presses the first start button
## and lets the simulation run [param seconds].
func _start(seconds: float) -> void:
	for designation: String in CabinetDevices.devices(view.document):
		var c: CircuitComponent = CabinetDevices.device(view.document.circuit, designation)
		if c is CircuitBreaker or c is MotorBreaker or (c is Fuse and (c as Fuse).holder) or (c is ThreePoleFuse and (c as ThreePoleFuse).holder):
			view.operate_device(designation)
	for c: CircuitComponent in view.document.circuit.get_components():
		if c is PushButton and (c as PushButton).contact_type == SwitchingElement.ContactType.NO:
			view.hold_button(c.designation, true)
			await create_timer(0.5).timeout
			view.hold_button(c.designation, false)
			break
	await create_timer(seconds).timeout
	await _frames(10)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _save(file: String, viewport: Viewport = null) -> void:
	await RenderingServer.frame_post_draw
	var source: Viewport = viewport if viewport != null else root
	source.get_texture().get_image().save_png(ProjectSettings.globalize_path(out_dir + file + ".png"))
	print("saved ", file)
