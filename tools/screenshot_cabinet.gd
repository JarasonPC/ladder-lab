extends SceneTree
## Takes screenshots of the app with the switchboard sidebar open: one in
## Edit mode, one while simulating with the breakers and fuse holders
## switched on and the first start button pressed. Needs a display
## (xvfb-run on a server):
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tools/screenshot_cabinet.gd -- <out_dir> [example index] [sidebar width]

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
	await _frames(5)
	main.get("_circuit_select").select(example)
	main.call("_load_example")
	main.call("_set_cabinet", true)
	if args.size() > 2:
		(main.get("_cabinet_bar") as SideBar).width = float(args[2])
	await _frames(20)
	await _save("app_edit")
	main.call("_set_mode", 1)
	await _frames(5)
	var view: SchematicView = main.get("view")
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
	await _save("app_simulate")
	quit()


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + file + ".png")
	print("saved ", file)
