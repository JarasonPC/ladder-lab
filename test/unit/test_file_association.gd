extends GutTest


func test_finds_the_schematic_among_arguments() -> void:
	var args: PackedStringArray = ["--remote-debug", "tcp://127.0.0.1:6007", "/home/jan/Lis.LADDER", "/home/jan/b.ladder"]
	assert_eq(FileAssociation.file_from_args(args), "/home/jan/Lis.LADDER")


func test_no_schematic_argument() -> void:
	assert_eq(FileAssociation.file_from_args(PackedStringArray(["--verbose", "notes.txt"])), "")


func test_registry_opens_files_with_the_executable() -> void:
	var text: String = FileAssociation.registry_text("C:/Program Files/LadderLab/LadderLab.exe", "Schéma \"LadderLab\"")
	assert_true(text.begins_with("Windows Registry Editor Version 5.00\r\n"))
	assert_string_contains(text, "[HKEY_CURRENT_USER\\Software\\Classes\\.ladder]\r\n@=\"LadderLab.Schematic\"")
	assert_string_contains(text, "[HKEY_CURRENT_USER\\Software\\Classes\\LadderLab.Schematic]\r\n@=\"Schéma \\\"LadderLab\\\"\"")
	assert_string_contains(text, "@=\"C:\\\\Program Files\\\\LadderLab\\\\LadderLab.exe,0\"")
	assert_string_contains(text, "@=\"\\\"C:\\\\Program Files\\\\LadderLab\\\\LadderLab.exe\\\" \\\"%1\\\"\"")
