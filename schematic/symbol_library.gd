class_name SymbolLibrary
extends RefCounted
## The user's own library of floor plan symbols ([CustomSymbol]), kept for
## every schematic in [constant PATH] (written whole after every change).
## A schematic keeps a copy of each symbol it uses (see
## [member SchematicDocument.symbols]), so it opens with its symbols on any
## computer. [method shared] is the one the program uses. No nodes.

## The library or a symbol in it changed.
signal changed

const PATH: String = "user://symbols.json"
const FORMAT: String = "ladder-lab-symbols"
const VERSION: int = 1

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
		var json: JSON = JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary and json.data.get("format", "") == FORMAT:
			var list: Variant = json.data.get("symbols", [])
			if list is Array:
				for raw: Variant in list:
					var symbol: CustomSymbol = CustomSymbol.from_data(raw)
					if symbol != null and find(symbol.id) == null:
						symbols.append(symbol)
	changed.emit()


func save_file() -> Error:
	var list: Array = []
	for symbol: CustomSymbol in symbols:
		list.append(symbol.to_data())
	return ProjectFile.write_atomically(path, JSON.stringify({"format": FORMAT, "version": VERSION, "symbols": list}, "\t"))


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
