extends GutTest

const DIR: String = "user://test_recovery"
## Session of another LadderLab.
const OTHER: String = "1700000000-42"


func after_each() -> void:
	for name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(name))


func after_all() -> void:
	DirAccess.remove_absolute(DIR)


func test_written_copy_reads_back_with_its_file() -> void:
	var doc: SchematicDocument = ExampleCircuits.self_cutoff()
	var path: String = RecoveryFile.own_path(DIR)
	assert_eq(RecoveryFile.write(doc, "C:/work/motor.ladder", path), OK)
	assert_false(FileAccess.file_exists(path + ".tmp"), "no half-written copy left")
	var result: Dictionary = RecoveryFile.read(path)
	assert_eq(result.get("file", ""), "C:/work/motor.ladder")
	assert_eq(DocumentSerializer.to_dict(result["document"]), DocumentSerializer.to_dict(doc), "identical after recovery")
	RecoveryFile.write(SchematicDocument.new("Edited"), "", path)
	assert_eq((RecoveryFile.read(path)["document"] as SchematicDocument).title, "Edited", "a later edit replaces the copy")
	RecoveryFile.remove(path)
	assert_false(FileAccess.file_exists(path), "removed once saved")


func test_copies_of_sessions_no_longer_alive_are_offered() -> void:
	var doc: SchematicDocument = SchematicDocument.new("Lost work")
	var other: String = DIR.path_join(OTHER + ".ladder")
	RecoveryFile.write(doc, "", RecoveryFile.own_path(DIR))
	RecoveryFile.write(doc, "", other)
	RecoveryFile.beat(DIR, OTHER, 1000)
	assert_eq(RecoveryFile.orphans(DIR, 1000 + RecoveryFile.STALE - 1), PackedStringArray(),
		"another LadderLab still running keeps its copy; this one's own is never offered")
	assert_eq(RecoveryFile.orphans(DIR, 1000 + RecoveryFile.STALE), PackedStringArray([other]),
		"no longer marked alive: crashed, frozen or killed")
	RecoveryFile.remove(other)
	assert_eq(RecoveryFile.orphans(DIR, 1000 + RecoveryFile.STALE), PackedStringArray())
	assert_false(FileAccess.file_exists(DIR.path_join(OTHER + ".alive")), "the mark of a gone session that left nothing goes")
	RecoveryFile.write(doc, "", other)
	assert_eq(RecoveryFile.orphans(DIR), PackedStringArray([other]), "never marked alive")
	assert_eq(RecoveryFile.orphans("user://no_such_folder"), PackedStringArray())


func test_quitting_leaves_nothing() -> void:
	RecoveryFile.write(SchematicDocument.new(), "", RecoveryFile.own_path(DIR))
	RecoveryFile.beat(DIR)
	RecoveryFile.forget(DIR)
	assert_eq(DirAccess.get_files_at(DIR), PackedStringArray())


func test_damaged_copy_is_refused_cleanly() -> void:
	var path: String = DIR.path_join(OTHER + ".ladder")
	DirAccess.make_dir_recursive_absolute(DIR)
	for text: String in ["", "not json", '{"format": "ladder-lab"}', '{"format": "ladder-lab-recovery", "project": {"format": "ladder-lab", "version": 1, "document": "nope"}}']:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		assert_eq(RecoveryFile.read(path).get("error", ""), "%s is damaged and cannot be opened.", text)
