class_name SymbolLibrary
extends RefCounted
## The user's own library of floor plan symbols ([CustomSymbol]), kept for
## every schematic in [constant PATH] (written whole after every change).
## A schematic keeps a copy of each symbol it uses (see
## [member SchematicDocument.symbols]), so it opens with its symbols on any
## computer. [method shared] is the one the program uses. Symbols are
## shared as files of their own ([constant EXTENSION], the format of the
## library's file): [method export_file] writes some or all of them,
## [method import_file] takes those of a file in. No nodes.

## The library or a symbol in it changed.
signal changed

const PATH: String = "user://symbols.json"
const FORMAT: String = "ladder-lab-symbols"
const VERSION: int = 1
## Files of symbols exported and imported.
const EXTENSION: String = "ladsym"

## The file it is read from and written to.
var path: String = PATH
var symbols: Array[CustomSymbol] = []

static var _shared: SymbolLibrary = null


## The library of the program, read from [constant PATH] the first time.
static func shared() -> SymbolLibrary:
	if _shared == null:
		_shared = SymbolLibrary.new()
		_shared.load_file()
	return _shared


## Makes [param library] the one the program uses (tests: one with a file
## of their own).
static func set_shared(library: SymbolLibrary) -> void:
	_shared = library


## Reads [member path]; a missing or damaged file is an empty library.
func load_file() -> void:
	symbols.clear()
	if FileAccess.file_exists(path):
		var read: Dictionary = parse(FileAccess.get_file_as_string(path))
		symbols.assign(read.get("symbols", []))
	changed.emit()


func save_file() -> Error:
	return ProjectFile.write_atomically(path, to_text(symbols))


## [param list] as the text of a file of symbols (the library's or one exported).
static func to_text(list: Array[CustomSymbol]) -> String:
	var data: Array = []
	for symbol: CustomSymbol in list:
		data.append(symbol.to_data())
	return JSON.stringify({"format": FORMAT, "version": VERSION, "symbols": data}, "\t")


## Reads the text of a file of symbols: {"symbols": the symbols, each id
## once, damaged ones left out} or {"error": why not, with a %s for the
## file's name}.
static func parse(text: String) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary) or json.data.get("format", "") != FORMAT:
		return {"error": "%s is not a file of LadderLab symbols."}
	var version: Variant = json.data.get("version", 0)
	if (version is float or version is int) and int(version) > VERSION:
		return {"error": "%s was saved by a newer version of LadderLab."}
	var result: Array[CustomSymbol] = []
	var ids: Dictionary[String, bool] = {}
	var list: Variant = json.data.get("symbols", [])
	if list is Array:
		for raw: Variant in list:
			var symbol: CustomSymbol = CustomSymbol.from_data(raw)
			if symbol != null and not ids.has(symbol.id):
				ids[symbol.id] = true
				result.append(symbol)
	return {"symbols": result}


## Writes the symbols of [param ids] (all of them when empty) to
## [param file_path], sorted as [method sorted].
func export_file(file_path: String, ids: PackedStringArray = PackedStringArray()) -> Error:
	var list: Array[CustomSymbol] = []
	for symbol: CustomSymbol in sorted():
		if ids.is_empty() or ids.has(symbol.id):
			list.append(symbol)
	return ProjectFile.write_atomically(file_path, to_text(list))


## Takes the symbols of file [param file_path] in: a symbol the library
## has (the same id) in place of its drawing there, the others added.
## Returns {"added": ids, "replaced": ids} or {"error": why not, with a %s
## for the file's name}; written to the library's file when any came in.
func import_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"error": "%s cannot be read."}
	var read: Dictionary = parse(FileAccess.get_file_as_string(file_path))
	if read.has("error"):
		return read
	var added: PackedStringArray = PackedStringArray()
	var replaced: PackedStringArray = PackedStringArray()
	for symbol: CustomSymbol in read["symbols"]:
		var at: int = -1
		for i: int in symbols.size():
			if symbols[i].id == symbol.id:
				at = i
		if at >= 0:
			symbols[at] = symbol
			replaced.append(symbol.id)
		else:
			symbols.append(symbol)
			added.append(symbol.id)
	if not added.is_empty() or not replaced.is_empty():
		save_file()
		changed.emit()
	return {"added": added, "replaced": replaced}


## The symbol of [param id], null for none.
func find(id: String) -> CustomSymbol:
	for symbol: CustomSymbol in symbols:
		if symbol.id == id:
			return symbol
	return null


## Adds a copy of [param symbol], or puts it in place of the one of its id;
## written to the file.
func put(symbol: CustomSymbol) -> void:
	var stored: CustomSymbol = symbol.copy()
	for i: int in symbols.size():
		if symbols[i].id == stored.id:
			symbols[i] = stored
			save_file()
			changed.emit()
			return
	symbols.append(stored)
	save_file()
	changed.emit()


## Takes the symbol of [param id] away (schematics keep their copies).
func remove(id: String) -> void:
	for i: int in symbols.size():
		if symbols[i].id == id:
			symbols.remove_at(i)
			save_file()
			changed.emit()
			return


## The categories of the symbols, sorted ("" among them for symbols
## without one).
func categories() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for symbol: CustomSymbol in sorted():
		if not result.has(symbol.category):
			result.append(symbol.category)
	return result


## The symbols by category (as [method categories]), each sorted by name.
func sorted() -> Array[CustomSymbol]:
	var result: Array[CustomSymbol] = symbols.duplicate()
	result.sort_custom(func(a: CustomSymbol, b: CustomSymbol) -> bool:
		if a.category != b.category:
			return a.category.naturalnocasecmp_to(b.category) < 0
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return result
