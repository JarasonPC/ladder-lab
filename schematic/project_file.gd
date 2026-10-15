class_name ProjectFile
extends RefCounted
## Reads and writes schematics as .ladder files: UTF-8 JSON with a format
## name and version around the [DocumentSerializer] data.

const EXTENSION: String = "ladder"
const FORMAT: String = "ladder-lab"
## Raise when the file layout changes; older files must keep loading.
const VERSION: int = 1


## Writes [param doc] to [param path]. Returns OK or the file error.
static func save(doc: SchematicDocument, path: String) -> Error:
	var data: Dictionary = {"format": FORMAT, "version": VERSION, "document": DocumentSerializer.to_dict(doc)}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.close()
	return OK


## Reads a schematic. Returns {"document": SchematicDocument} on success or
## {"error": English message with one %s for the file name}.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "Could not open %s."}
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		return {"error": "Could not open %s."}
	return parse(text)


## Parses file contents; see [method load_file].
static func parse(text: String) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {"error": "%s is not a LadderLab file."}
	var data: Dictionary = json.data
	if data.get("format", "") != FORMAT:
		return {"error": "%s is not a LadderLab file."}
	var version: Variant = data.get("version", 0)
	if not (version is float or version is int) or int(version) < 1:
		return {"error": "%s is not a LadderLab file."}
	if int(version) > VERSION:
		return {"error": "%s was saved by a newer version of LadderLab."}
	var document_data: Variant = data.get("document", null)
	if not (document_data is Dictionary):
		return {"error": "%s is damaged and cannot be opened."}
	var doc: SchematicDocument = DocumentSerializer.from_dict(document_data)
	if doc == null:
		return {"error": "%s is damaged and cannot be opened."}
	return {"document": doc}
