class_name RecoveryFile
extends RefCounted
## A copy of the schematic with unsaved changes, kept so the work survives a
## crash or a freeze: main.gd writes it after every edit and removes it when
## the schematic is saved or its changes are given up. Each running LadderLab
## (session) has a copy of its own, so two windows never overwrite each
## other's, and keeps marking itself alive (every BEAT seconds); at start, the
## copies of sessions no longer marked alive (closed by a crash, frozen or
## killed) are offered back.

const DIR: String = "user://recovery"
const FORMAT: String = "ladder-lab-recovery"
## Seconds between two alive marks of a running session.
const BEAT: float = 15.0
## A session not marked alive for this many seconds is gone (or frozen).
const STALE: int = 60
const ALIVE_EXTENSION: String = "alive"

static var _session: String = ""


## Name of this run of the program, unique across runs.
static func session() -> String:
	if _session.is_empty():
		_session = "%d-%d" % [int(Time.get_unix_time_from_system()), randi() % 1000000]
	return _session


## The recovery copy of this session in [param dir].
static func own_path(dir: String = DIR) -> String:
	return dir.path_join("%s.%s" % [session(), ProjectFile.EXTENSION])


## Writes [param doc], edited from the file [param file_path] ("" when never
## saved), to [param path]. A copy written halfway (the program dying meanwhile)
## never replaces the last good one.
static func write(doc: SchematicDocument, file_path: String, path: String = own_path()) -> Error:
	var made: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if made != OK:
		return made
	var data: Dictionary = {"format": FORMAT, "file": file_path, "project": ProjectFile.to_dict(doc)}
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.close()
	return DirAccess.rename_absolute(temporary, path)


## Removes the recovery copy [param path], if there is one.
static func remove(path: String = own_path()) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Marks session [param name] alive at [param now] (unix time).
static func beat(dir: String = DIR, name: String = session(), now: int = int(Time.get_unix_time_from_system())) -> void:
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return
	var file: FileAccess = FileAccess.open(dir.path_join("%s.%s" % [name, ALIVE_EXTENSION]), FileAccess.WRITE)
	if file != null:
		file.store_string(str(now))
		file.close()


## Removes the copy and the alive mark of this session as the program quits.
static func forget(dir: String = DIR) -> void:
	remove(own_path(dir))
	remove(dir.path_join("%s.%s" % [session(), ALIVE_EXTENSION]))


## Recovery copies in [param dir] of other sessions not marked alive within
## STALE seconds before [param now], the newest first. Alive marks of gone
## sessions that left no copy are removed.
static func orphans(dir: String = DIR, now: int = int(Time.get_unix_time_from_system())) -> PackedStringArray:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return PackedStringArray()
	for name: String in DirAccess.get_files_at(dir):
		var path: String = dir.path_join(name)
		var other: String = name.get_basename()
		var mark: String = dir.path_join("%s.%s" % [other, ALIVE_EXTENSION])
		var alive: bool = other == session() or now - _marked_at(mark) < STALE
		if name.get_extension() == ProjectFile.EXTENSION and not alive:
			found.append(path)
		elif name.get_extension() == ALIVE_EXTENSION and not alive and not FileAccess.file_exists(dir.path_join("%s.%s" % [other, ProjectFile.EXTENSION])):
			remove(path)
	found.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(a) > FileAccess.get_modified_time(b))
	return PackedStringArray(found)


## When the alive mark [param path] was written (unix time), 0 without one.
static func _marked_at(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var text: String = FileAccess.get_file_as_string(path).strip_edges()
	return int(text) if text.is_valid_int() else 0


## Reads a recovery copy. Returns {"document": SchematicDocument, "file": the
## file it was edited from, "" when never saved} or {"error": English message
## with one %s for the file name}.
static func read(path: String) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return {"error": "%s is damaged and cannot be opened."}
	var data: Dictionary = json.data
	if data.get("format", "") != FORMAT or not (data.get("project", null) is Dictionary):
		return {"error": "%s is damaged and cannot be opened."}
	var result: Dictionary = ProjectFile.from_dict(data["project"])
	if result.has("document"):
		result["file"] = str(data.get("file", ""))
	return result
