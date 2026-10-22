extends GutTest
## The paper size guide over the schematic: a sheet of the chosen paper at
## full size, its room for the drawing starting at the drawing's top left.


func test_room_of_a_sheet_at_full_size() -> void:
	var a4: SheetLayout = SheetLayout.at_corner("A4", false, Vector2(-3.0, 2.0))
	assert_eq(a4.paper_mm, Vector2(297.0, 210.0))
	assert_eq(a4.cell_mm, SheetLayout.CELL_MM)
	var room: Rect2 = a4.room()
	assert_almost_eq(room.position, Vector2(-3.0, 2.0), Vector2(0.001, 0.001), "starts at the corner given")
	# 297 - 2 x (10 + 5) mm across, 210 - 2 x (10 + 5) - 18 mm down, 5 mm a cell.
	assert_almost_eq(room.size, Vector2(53.4, 32.4), Vector2(0.001, 0.001))
	var upright: Rect2 = SheetLayout.at_corner("A4", true, Vector2.ZERO).room()
	assert_almost_eq(upright.size, Vector2(36.0, 49.8), Vector2(0.001, 0.001), "portrait")
	assert_true(SheetLayout.at_corner("A3", false, Vector2.ZERO).room().size.x > room.size.x)


func test_the_room_is_what_the_export_fits_at_full_size() -> void:
	# A drawing just as large as the room goes on that paper unscaled.
	var room: Rect2 = SheetLayout.at_corner("A3", false, Vector2(4.0, 1.0)).room()
	var sheet: SheetLayout = SheetLayout.fit(room, "A3")
	assert_eq(sheet.paper_name, "A3")
	assert_almost_eq(sheet.cell_mm, SheetLayout.CELL_MM, 0.0001, "not scaled down")
	var larger: SheetLayout = SheetLayout.fit(room.grow(1.0), "A3")
	assert_true(larger.cell_mm < SheetLayout.CELL_MM, "a cell more on each side is scaled down")


func test_guide_shown_on_the_schematic_only_when_chosen() -> void:
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(ExampleCircuits.build(9), false)
	var guide: PaperGuide = null
	for child: Node in view.get_children():
		if child is PaperGuide:
			guide = child
	assert_not_null(guide)
	assert_eq(guide.paper, "", "none unless chosen")
	view.set_paper_guide("A3", true)
	assert_eq(guide.paper, "A3")
	assert_true(guide.portrait)
	view.rebuild()
	for child: Node in view.get_children():
		if child is PaperGuide:
			guide = child
	assert_eq(guide.paper, "A3", "kept when the page is drawn again")
	assert_eq(guide.z_index, -1, "behind the drawing")


func test_guide_says_when_the_drawing_does_not_fit() -> void:
	assert_eq(PaperGuide.text_of("A4", false, true), "A4, landscape")
	assert_eq(PaperGuide.text_of("A3", true, true), "A3, portrait")
	assert_true(PaperGuide.text_of("A4", false, false).begins_with("A4, landscape – "))
