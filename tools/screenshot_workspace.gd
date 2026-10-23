extends SceneTree
## Takes screenshots of the app's workspace for visual review: the workspace
## of a built-in example in Edit mode, its first switchboard opened (a place
## selected, so the editing tools show), and while simulating with the
## breakers and fuse holders switched on and the first start button pressed:
## the switchboard and the first control station. Needs a display (xvfb-run
## on a server):
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tools/screenshot_workspace.gd -- <out_dir> [example index]

var out_dir: String = "user://screenshots/"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0].trim_suffix("/") + "/"
	var example: int = int(args[1]) if args.size() > 1 else 9
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	# No start window over the pictures.
	(main.get("_start_dialog") as Window).hide()
	await _frames(5)
	main.call("_replace_document", ExampleCircuits.build(example), "")
	main.call("_set_area", 1)
	await _frames(10)
	await _save("workspace_edit")
	var workspace: WorkspaceView = main.get("_workspace")
	var view: SchematicView = main.get("view")
	if view.document.switchboards.is_empty():
		quit()
		return
	var board: String = view.document.switchboards[0].name
	workspace.open(Workspace.Place.SWITCHBOARD, board)
	await _frames(5)
	# Select the first contactor's place, so the editing card shows too.
	var panel: CabinetPanel = workspace.get("_panel")
	(panel.get("_view") as CabinetView).place_clicked.emit(1, 0)
	await _frames(10)
	await _save("switchboard_edit")
	main.call("_set_mode", 1)
	await _frames(5)
	for designation: String in CabinetDevices.devices(view.document):
		var c: CircuitComponent = CabinetDevices.device(view.document.circuit, designation)
		if c is CircuitBreaker or c is MotorBreaker or (c is Fuse and (c as Fuse).holder) or (c is ThreePoleFuse and (c as ThreePoleFuse).holder):
			view.operate_device(designation)
	var start: String = ""
	for c: CircuitComponent in view.document.circuit.get_components():
		if c is PushButton and (c as PushButton).contact_type == SwitchingElement.ContactType.NO:
			start = c.designation
			break
	if not start.is_empty():
		view.hold_button(start, true)
		await _frames(30)
		view.hold_button(start, false)
	await _frames(90)
	await _save("switchboard_simulate")
	if not view.document.control_boxes.is_empty():
		workspace.open(Workspace.Place.STATION, view.document.control_boxes[0].name)
		await _frames(10)
		await _save("station_simulate")
	quit()


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + file + ".png")
	print("saved ", file)
