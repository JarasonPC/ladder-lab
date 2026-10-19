extends GutTest
## The inside of a control station: the contact blocks behind its buttons
## and switches, lamp blocks, a cam switch's chambers, the cable's cores to
## the terminals they land on and the wires between terminals of one net.


## The start/stop example with its start button illuminated by H1.
func _illuminated() -> SchematicDocument:
	var doc: SchematicDocument = ExampleCircuits.build(0)
	var box: ControlBox = doc.control_boxes[0]
	var lamp: int = -1
	for i: int in box.items.size():
		if box.items[i].kind == ControlBoxItem.Kind.LAMP:
			lamp = i
	var designation: String = box.items[lamp].designation
	box.items.remove_at(lamp)
	for item: ControlBoxItem in box.items:
		if item.designation == "SB1":
			item.lamp = designation
			item.color = "green"
	return doc


func _item(inside: StationInside, designation: String) -> Dictionary:
	for entry: Dictionary in inside.items:
		if entry["designation"] == designation:
			return entry
	return {}


func test_blocks_behind_the_devices() -> void:
	var doc: SchematicDocument = _illuminated()
	var inside: StationInside = StationInside.build(doc, 0)
	assert_eq(inside.items.size(), doc.control_boxes[0].items.size())
	var stop: Dictionary = _item(inside, "SB0")
	assert_eq(stop["blocks"].size(), 1)
	assert_eq(stop["blocks"][0]["kind"], "NC")
	var start: Dictionary = _item(inside, "SB1")
	var kinds: PackedStringArray = PackedStringArray()
	for block: Dictionary in start["blocks"]:
		kinds.append(block["kind"])
	assert_true(kinds.has("NO"))
	assert_true(kinds.has("LAMP"), "the lamp inside the illuminated button has its block too")
	for entry: Dictionary in inside.items:
		var cell: Rect2 = entry["rect"]
		for block: Dictionary in entry["blocks"]:
			assert_true(cell.encloses(block["rect"]), "the blocks sit in their item's room")
			for t: Dictionary in block["terminals"]:
				assert_true((block["rect"] as Rect2).has_point(t["at"]), "terminals on their block")
	assert_true(Rect2(Vector2.ZERO, inside.size).encloses(inside.items[inside.items.size() - 1]["rect"]))


func test_cam_switch_chambers() -> void:
	var doc: SchematicDocument = SchematicDocument.new("cam")
	doc.add(CamSwitch.new("RB1", CamSwitch.Positions.CHANGEOVER, 2), Vector2i(0, 0))
	doc.add_control_box_for_all()
	var inside: StationInside = StationInside.build(doc, 0)
	var cam: Dictionary = _item(inside, "RB1")
	assert_true(cam["cam"])
	assert_eq(cam["blocks"].size(), 2, "a chamber a pole")
	var tops: int = 0
	for t: Dictionary in cam["blocks"][0]["terminals"]:
		tops += 1 if t["top"] else 0
	assert_eq(tops, 2, "the I and II sides on top, the common below")


## Joins the terminals and gland cores [param inside]'s wires join (cores
## of one net are joined outside, in the switchboard); returns end -> group.
func _groups(inside: StationInside) -> Dictionary:
	var group: Dictionary = {}
	var next: int = 0
	for wire: Dictionary in inside.wires:
		var points: PackedVector2Array = wire["points"]
		var ends: Array = ["core %d" % wire["net"] if wire["external"] else points[0], points[points.size() - 1]]
		var found: Array = []
		for end: Variant in ends:
			if group.has(end):
				found.append(group[end])
		var g: int = found[0] if not found.is_empty() else next
		next += 1
		for old: int in found:
			for key: Variant in group.keys():
				if group[key] == old:
					group[key] = g
		for end: Variant in ends:
			group[end] = g
	return group


func test_every_terminal_of_a_net_is_wired() -> void:
	var doc: SchematicDocument = _illuminated()
	var inside: StationInside = StationInside.build(doc, 0)
	var net: Dictionary[String, int] = CabinetDevices.nets(doc.circuit)
	var external: int = 0
	for wire: Dictionary in inside.wires:
		if wire["external"]:
			external += 1
		for point: Vector2 in wire["points"]:
			assert_true(Rect2(Vector2(0.0, -1.0), inside.size + Vector2(0.0, 1.0)).has_point(point), "wires stay in the housing")
	var cores: int = 0
	for cable: Dictionary in WorkspaceCables.cables(doc):
		if cable["b"] == "+" + doc.control_boxes[0].name or cable["a"] == "+" + doc.control_boxes[0].name:
			cores += cable["cores"].size()
	assert_eq(inside.glands.size(), 1, "the cable from the switchboard comes in through a gland")
	assert_eq(external, cores, "a core of the cable to each terminal it lands on")
	var groups: Dictionary = _groups(inside)
	# Terminals of one net here end up joined; every wired terminal is reached.
	var by_net: Dictionary = {}
	for key: String in inside.terminals:
		var at: Vector2 = inside.terminals[key]["at"]
		if not groups.has(at):
			continue
		var n: int = net[key]
		if not by_net.has(n):
			by_net[n] = {}
		by_net[n][groups[at]] = true
	for n: Variant in by_net:
		assert_eq(by_net[n].size(), 1, "net %s is joined in one" % n)
	var cored: Dictionary = {}
	for key: String in inside.terminals:
		cored[net[key]] = true
	assert_eq(by_net.size(), cored.size(), "every net of the station's terminals is wired")


func test_drawn_in_the_station_panel() -> void:
	var doc: SchematicDocument = _illuminated()
	var panel: StationPanel = StationPanel.new()
	panel.station_name = doc.control_boxes[0].name
	add_child_autofree(panel)
	panel.size = Vector2(900, 700)
	panel.set_document(doc, true)
	panel.inside_shown = true
	await wait_process_frames(3)
	var view: StationInsideView = panel.get("_inside")
	assert_true(view.visible, "the inside in place of the front")
	assert_false((panel.get("_scroll") as Control).visible)
	panel.inside_shown = false
	await wait_process_frames(2)
	assert_false(view.visible)
