extends GutTest

const PATH: String = "user://test_project_file.ladder"


func after_all() -> void:
	DirAccess.remove_absolute(PATH)


func test_save_and_load_every_example() -> void:
	for index: int in ExampleCircuits.count() * 2:
		var doc: SchematicDocument = ExampleCircuits.build(index / 2, index % 2 == 1)
		assert_eq(ProjectFile.save(doc, PATH), OK)
		var result: Dictionary = ProjectFile.load_file(PATH)
		assert_true(result.has("document"), "%s loads" % doc.title)
		assert_eq(DocumentSerializer.to_dict(result["document"]), DocumentSerializer.to_dict(doc), "%s is identical after reopening" % doc.title)


func test_file_is_readable_json_with_version() -> void:
	ProjectFile.save(ExampleCircuits.self_cutoff(), PATH)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(data["format"], "ladder-lab")
	assert_eq(int(data["version"]), ProjectFile.VERSION)
	assert_true(data["document"]["components"] is Array)


func test_bad_files_are_refused_cleanly() -> void:
	assert_eq(ProjectFile.load_file("user://does_not_exist.ladder")["error"], "Could not open %s.")
	assert_eq(ProjectFile.parse("not json")["error"], "%s is not a LadderLab file.")
	assert_eq(ProjectFile.parse('{"format": "other", "version": 1}')["error"], "%s is not a LadderLab file.")
	assert_eq(ProjectFile.parse('{"format": "ladder-lab", "version": 99, "document": {}}')["error"], "%s was saved by a newer version of LadderLab.")
	var damaged: Array[String] = [
		'{"format": "ladder-lab", "version": 1, "document": {"components": [{"type": "rocket", "designation": "R1", "cell": [0, 0]}]}}',
		'{"format": "ladder-lab", "version": 1, "document": {"components": [{"type": "lamp", "designation": "H1", "cell": [0, 0]}, {"type": "lamp", "designation": "H1", "cell": [5, 0]}]}}',
		'{"format": "ladder-lab", "version": 1, "document": {"components": [], "wires": [{"a": "L", "b": "N", "corners": []}]}}',
		'{"format": "ladder-lab", "version": 1, "document": {"components": [{"type": "lamp", "designation": "H1", "cell": "x"}]}}',
		'{"format": "ladder-lab", "version": 1, "document": "nope"}',
	]
	for text: String in damaged:
		assert_eq(ProjectFile.parse(text).get("error", ""), "%s is damaged and cannot be opened.", text)


func test_version_1_files_load_with_default_times() -> void:
	var text: String = '{"format": "ladder-lab", "version": 1, "document": {"title": "old", "components": [{"type": "coil", "kind": "relay", "designation": "K1", "cell": [0, 0]}, {"type": "timer", "mode": "on_delay", "delay": 2.0, "designation": "KT1", "cell": [4, 0]}], "wires": []}}'
	var doc: SchematicDocument = ProjectFile.parse(text)["document"]
	assert_true(doc.realistic_timing, "realistic switching by default")
	var k1: Coil = doc.circuit.get_coil("K1")
	assert_almost_eq(k1.pick_up_time, Coil.DEFAULT_PICK_UP[Coil.Kind.RELAY], 1e-9)
	assert_almost_eq(k1.drop_out_time, Coil.DEFAULT_DROP_OUT[Coil.Kind.RELAY], 1e-9)


func test_switching_times_and_mode_are_saved() -> void:
	var doc: SchematicDocument = ExampleCircuits.self_holding()
	doc.realistic_timing = false
	doc.replace_component("KM1", Coil.new("KM1", Coil.Kind.CONTACTOR, 0.035, 0.025))
	ProjectFile.save(doc, PATH)
	var copy: SchematicDocument = ProjectFile.load_file(PATH)["document"]
	assert_false(copy.realistic_timing)
	assert_almost_eq(copy.circuit.get_coil("KM1").pick_up_time, 0.035, 1e-9)
	assert_almost_eq(copy.circuit.get_coil("KM1").drop_out_time, 0.025, 1e-9)
