class_name FileAssociation
extends RefCounted
## Lets the operating system open .ladder files with LadderLab: an exported
## Windows build registers the extension for the current user (no admin
## rights needed), and a schematic double-clicked in Explorer arrives as a
## command-line argument. File > Open .ladder files with LadderLab turns it
## off, which removes the registration again.

const PROG_ID: String = "LadderLab.Schematic"
## Last registration imported, so the registry is written only when the
## executable moved or the description changed.
const REG_PATH: String = "user://file_association.reg"


## The first .ladder file among the command-line arguments, or "".
static func file_from_args(args: PackedStringArray) -> String:
	for arg: String in args:
		if arg.get_extension().to_lower() == ProjectFile.EXTENSION:
			return arg.replace("\\", "/") if OS.get_name() == "Windows" else arg
	return ""


## Only an exported Windows build registers itself (not the editor).
static func available() -> bool:
	return OS.get_name() == "Windows" and OS.has_feature("template")


## Registers .ladder for the running executable when it is an exported
## Windows build; [param description] is the file type name Explorer shows.
static func register(description: String) -> void:
	if not available():
		return
	var text: String = registry_text(OS.get_executable_path(), description)
	if FileAccess.file_exists(REG_PATH):
		var old: PackedByteArray = FileAccess.get_file_as_bytes(REG_PATH)
		if old.slice(2).get_string_from_utf16() == text:
			return
	var file: FileAccess = FileAccess.open(REG_PATH, FileAccess.WRITE)
	if file == null:
		return
	# reg.exe reads version 5.00 files as UTF-16 LE with a byte order mark.
	file.store_buffer(PackedByteArray([0xFF, 0xFE]))
	file.store_buffer(text.to_utf16_buffer())
	file.close()
	var global_path: String = ProjectSettings.globalize_path(REG_PATH).replace("/", "\\")
	if OS.execute("reg", ["import", global_path]) != 0:
		DirAccess.remove_absolute(REG_PATH)


## Removes the registration written by [method register].
static func unregister() -> void:
	if not available():
		return
	for key: String in registry_keys():
		OS.execute("reg", ["delete", key, "/f"])
	DirAccess.remove_absolute(REG_PATH)


## The registry keys [method register] creates (with their subkeys).
static func registry_keys() -> PackedStringArray:
	var classes: String = "HKEY_CURRENT_USER\\Software\\Classes\\"
	return [classes + "." + ProjectFile.EXTENSION, classes + PROG_ID]


## Contents of the .reg file that associates .ladder with [param exe_path].
static func registry_text(exe_path: String, description: String) -> String:
	var exe: String = exe_path.replace("/", "\\")
	var classes: String = "[HKEY_CURRENT_USER\\Software\\Classes\\"
	var lines: PackedStringArray = [
		"Windows Registry Editor Version 5.00",
		"",
		classes + "." + ProjectFile.EXTENSION + "]",
		"@=" + _reg_string(PROG_ID),
		"",
		classes + "." + ProjectFile.EXTENSION + "\\OpenWithProgids]",
		_reg_string(PROG_ID) + "=\"\"",
		"",
		classes + PROG_ID + "]",
		"@=" + _reg_string(description),
		"",
		classes + PROG_ID + "\\DefaultIcon]",
		"@=" + _reg_string(exe + ",0"),
		"",
		classes + PROG_ID + "\\shell\\open\\command]",
		"@=" + _reg_string("\"%s\" \"%%1\"" % exe),
		"",
	]
	return "\r\n".join(lines)


## A quoted .reg string value.
static func _reg_string(value: String) -> String:
	return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
