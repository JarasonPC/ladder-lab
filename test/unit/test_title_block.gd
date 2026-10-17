extends GutTest

const ExamplePower = preload("res://test/unit/example_power.gd")


func _filled() -> TitleBlock:
	var block: TitleBlock = TitleBlock.new()
	block.company = "SPŠ Elektro"
	block.project = "Lis"
	block.drawing_number = "E-001"
	block.revision = "B"
	block.drawn_by = "J. Novák"
	block.checked_by = "P. Dvořák"
	block.date = "2026-10-16"
	return block


func test_saved_with_the_document() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_cutoff())
	doc.title_block = _filled()
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_true(copy.title_block.equals(doc.title_block))
	assert_eq(copy.title_block.drawn_by, "J. Novák")
	assert_eq(copy.title_block.date, "2026-10-16")


func test_empty_title_block_is_not_written() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_cutoff())
	assert_false(DocumentSerializer.to_dict(doc).has("title_block"))
	doc.title_block.drawn_by = "J. Novák"
	assert_eq(DocumentSerializer.to_dict(doc)["title_block"], {"drawn_by": "J. Novák"})


func test_older_and_malformed_data_load_empty() -> void:
	var data: Dictionary = DocumentSerializer.to_dict(ExamplePower.on(ExampleCircuits.self_cutoff()))
	assert_true(DocumentSerializer.from_dict(data).title_block.is_empty(), "files before version 13 have no title block")
	data["title_block"] = "nope"
	assert_true(DocumentSerializer.from_dict(data).title_block.is_empty())
	data["title_block"] = {"drawn_by": 42, "revision": "  C ", "unknown": "x"}
	var block: TitleBlock = DocumentSerializer.from_dict(data).title_block
	assert_eq(block.drawn_by, "")
	assert_eq(block.revision, "C")
	assert_eq(block.to_data(), {"revision": "C"})


func test_set_title_block_reports_changes() -> void:
	var doc: SchematicDocument = ExamplePower.on(ExampleCircuits.self_cutoff())
	var title: String = doc.title
	assert_false(doc.set_title_block(title, TitleBlock.new()), "nothing changed")
	var block: TitleBlock = _filled()
	assert_true(doc.set_title_block("  Press  ", block))
	assert_eq(doc.title, "Press")
	assert_true(doc.title_block.equals(block))
	assert_ne(doc.title_block, block, "the document keeps its own copy")
	block.drawn_by = "someone else"
	assert_eq(doc.title_block.drawn_by, "J. Novák")
	assert_false(doc.set_title_block("Press", _filled()))
