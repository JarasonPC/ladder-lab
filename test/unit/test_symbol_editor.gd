extends GutTest
## The symbol editor: polylines and polygons, fills, picking several
## shapes, turning, mirroring and scaling them, copying and pasting, the
## look of lines and texts, snapping to points, typed points and pictures.

const PICTURE: String = "user://test_picture.png"

var _canvas: SymbolCanvas
var _def: CustomSymbol


func before_each() -> void:
	_canvas = autofree(SymbolCanvas.new())
	_canvas.size = Vector2(600, 400)
	_def = CustomSymbol.new()
	_def.id = CustomSymbol.new_id()
	_canvas.edit(_def)
	SymbolCanvas.clipboard.clear()


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PICTURE))


## A click at symbol point [param at] (m) with the tool chosen.
func _click(at: Vector2) -> void:
	_canvas._press_at = _canvas.to_screen(at)
	_canvas._dragging = false
	_canvas._release(_canvas._pressed(_canvas._press_at), _canvas._press_at)


## A drag from [param from] to [param to] (m) with the tool chosen.
func _drag(from: Vector2, to: Vector2, adding: bool = false) -> void:
	_canvas._press_at = _canvas.to_screen(from)
	var press: Dictionary = _canvas._pressed(_canvas._press_at, adding)
	_canvas._dragging = true
	_canvas._mouse = _canvas.to_screen(to)
	_canvas._release(press, _canvas.to_screen(to))
	_canvas._dragging = false


func _rect(a: Vector2, b: Vector2) -> CustomSymbol.Shape:
	var shape: CustomSymbol.Shape = CustomSymbol.Shape.new()
	shape.kind = "rect"
	shape.points = PackedVector2Array([a, b])
	return shape


func test_polylines_and_polygons() -> void:
	_canvas.tool = SymbolCanvas.Tool.POLYLINE
	for p: Vector2 in [Vector2(0, 0), Vector2(0.1, 0), Vector2(0.1, 0.1)]:
		_click(p)
	assert_eq(_def.shapes.size(), 0, "still being drawn")
	_canvas.finish_path()
	assert_eq(_def.shapes.size(), 1)
	assert_eq(_def.shapes[0].kind, "polyline")
	assert_eq(_def.shapes[0].points.size(), 3)
	# A polygon closed by a click on its first point.
	_canvas.tool = SymbolCanvas.Tool.POLYGON
	for p: Vector2 in [Vector2(-0.2, -0.2), Vector2(-0.1, -0.2), Vector2(-0.15, -0.1), Vector2(-0.2, -0.2)]:
		_click(p)
	assert_eq(_def.shapes.size(), 2, "closed on its first point")
	assert_eq(_def.shapes[1].kind, "polygon")
	assert_eq(_def.shapes[1].points.size(), 3)
	assert_eq(CustomSymbol.outline_of(_def.shapes[1]).size(), 4, "round to the first point")
	# Too short to be one: dropped.
	_click(Vector2(0.2, 0.2))
	_click(Vector2(0.25, 0.2))
	_canvas.finish_path()
	assert_eq(_def.shapes.size(), 2, "a polygon of two points is none")
	# Filled, a click inside picks it.
	_def.shapes[1].filled = true
	assert_eq(_def.shape_at(Vector2(-0.15, -0.17), 0.001), 1)
	# Saved with its points; a polygon of two points is damaged.
	var again: CustomSymbol = CustomSymbol.from_data(_def.to_data())
	for k: int in 3:
		assert_true(again.shapes[1].points[k].is_equal_approx(_def.shapes[1].points[k]))
	assert_null(CustomSymbol.shape_from_data({"kind": "polygon", "points": [[0, 0], [1, 1]]}))


func test_several_picked_moved_and_deleted() -> void:
	for x: float in [0.0, 0.2, 0.4]:
		_def.shapes.append(_rect(Vector2(x, 0.0), Vector2(x + 0.1, 0.1)))
	_canvas.tool = SymbolCanvas.Tool.SELECT
	_click(Vector2(0.05, 0.0))
	assert_eq(_canvas.selection, PackedInt32Array([0]))
	_canvas._release(_canvas._pressed(_canvas.to_screen(Vector2(0.45, 0.0)), true), Vector2.ZERO)
	assert_eq(_canvas.selection, PackedInt32Array([0, 2]), "Shift+click picks one more")
	# Dragged together.
	_drag(Vector2(0.05, 0.0), Vector2(0.05, 0.05))
	assert_almost_eq(_def.shapes[0].points[0].y, 0.05, 1e-6)
	assert_almost_eq(_def.shapes[2].points[0].y, 0.05, 1e-6)
	assert_almost_eq(_def.shapes[1].points[0].y, 0.0, 1e-6, "not the one not picked")
	# A box from an empty place picks what it touches.
	_drag(Vector2(0.15, -0.2), Vector2(0.45, 0.02))
	assert_eq(_canvas.selection, PackedInt32Array([1]), "only the one it reaches")
	_drag(Vector2(-0.1, -0.2), Vector2(0.6, 0.3))
	assert_eq(_canvas.selection.size(), 3)
	_canvas.delete_selected()
	assert_eq(_def.shapes.size(), 0)
	_canvas.undo()
	assert_eq(_def.shapes.size(), 3, "one undo step")
	_canvas.select_all()
	assert_eq(_canvas.selection.size(), 3)
	_click(Vector2(0.25, 0.0))
	assert_eq(_canvas.selection, PackedInt32Array([1]), "a click on one of several picks it alone")


func test_turned_mirrored_and_scaled() -> void:
	_def.shapes.append(_rect(Vector2(0.0, 0.0), Vector2(0.2, 0.1)))
	var label: CustomSymbol.Shape = CustomSymbol.Shape.new()
	label.kind = "text"
	label.text = "TV"
	label.points = PackedVector2Array([Vector2(0.1, 0.05)])
	_def.shapes.append(label)
	_canvas.select_all()
	_canvas.turn_selected(true)
	var box: Rect2 = CustomSymbol.shape_bounds(_def.shapes[0])
	assert_almost_eq(box.size.x, 0.1, 1e-6, "lying up and down")
	assert_almost_eq(box.size.y, 0.2, 1e-6)
	assert_almost_eq(box.get_center().x, 0.1, 1e-6, "about the middle")
	assert_almost_eq(_def.shapes[1].angle, -90.0, 1e-6, "the text turned along")
	_canvas.turn_selected(false)
	assert_almost_eq(_def.shapes[1].angle, 0.0, 1e-6)
	assert_almost_eq(CustomSymbol.shape_bounds(_def.shapes[0]).size.x, 0.2, 1e-6, "back")
	# Mirrored, a text still reads from left to right.
	_def.shapes[1].angle = 30.0
	_canvas.mirror_selected(true)
	assert_almost_eq(_def.shapes[1].angle, -30.0, 1e-6)
	_canvas.mirror_selected(false)
	assert_almost_eq(_def.shapes[1].angle, 30.0, 1e-6)
	# Scaled by a corner of the box round them: the opposite one stays.
	_def.shapes[1].angle = 0.0
	var corners: PackedVector2Array = _canvas.corners()
	assert_eq(corners.size(), 4)
	_drag(corners[2], corners[0] + (corners[2] - corners[0]) * 2.0)
	box = CustomSymbol.shape_bounds(_def.shapes[0])
	assert_almost_eq(box.size.x, 0.4, 1e-6, "twice as large")
	assert_almost_eq(box.position.x, corners[0].x, 1e-6, "from the corner opposite")
	assert_almost_eq(_def.shapes[1].size, CustomSymbol.TEXT_SIZE * 2.0, 1e-6, "the text's height too")


func test_copied_pasted_and_duplicated() -> void:
	_def.shapes.append(_rect(Vector2(0.0, 0.0), Vector2(0.1, 0.1)))
	_canvas.selected = 0
	_canvas.copy_selected()
	_canvas.paste()
	_canvas.paste()
	assert_eq(_def.shapes.size(), 3)
	assert_almost_eq(_def.shapes[1].points[0].x, 0.01, 1e-6, "off the original")
	assert_almost_eq(_def.shapes[2].points[0].x, 0.02, 1e-6, "further off each time")
	assert_eq(_canvas.selection, PackedInt32Array([2]), "the pasted one picked")
	_canvas.duplicate_selected()
	assert_eq(_def.shapes.size(), 4)
	assert_almost_eq(_def.shapes[3].points[0].x, 0.03, 1e-6)
	_canvas.cut_selected()
	assert_eq(_def.shapes.size(), 3)
	# Into another symbol.
	var other: CustomSymbol = CustomSymbol.new()
	_canvas.edit(other)
	_canvas.paste()
	assert_eq(other.shapes.size(), 1, "the clipboard is for any symbol")


func test_look_of_new_shapes_saved() -> void:
	_canvas.look.width = 0.5
	_canvas.look.style = "dashdot"
	_canvas.look.color = "cc0000"
	_canvas.look.filled = true
	_canvas.look.fill = "ffcc00"
	_canvas.look.angle = 45.0
	_canvas.look.bold = true
	_canvas.look.italic = true
	_canvas.tool = SymbolCanvas.Tool.ELLIPSE
	_drag(Vector2(-0.1, -0.1), Vector2(0.1, 0.1))
	_canvas.tool = SymbolCanvas.Tool.LINE
	_drag(Vector2(-0.1, 0.2), Vector2(0.1, 0.2))
	_canvas.tool = SymbolCanvas.Tool.TEXT
	_canvas.text = "SAT"
	_click(Vector2(0.0, -0.2))
	assert_eq(_def.shapes.size(), 3)
	assert_true(_def.shapes[0].filled)
	assert_false(_def.shapes[1].filled, "a line is never filled")
	var again: CustomSymbol = CustomSymbol.from_data(JSON.parse_string(JSON.stringify(_def.to_data())))
	var ellipse: CustomSymbol.Shape = again.shapes[0]
	assert_almost_eq(ellipse.width, 0.5, 1e-6)
	assert_eq(ellipse.style, "dashdot")
	assert_eq(ellipse.color, "cc0000")
	assert_eq(ellipse.fill, "ffcc00")
	assert_eq(CustomSymbol.fill_color(ellipse, Color.BLACK), Color.html("ffcc00"))
	var text: CustomSymbol.Shape = again.shapes[2]
	assert_eq(text.text, "SAT")
	assert_almost_eq(text.angle, 45.0, 1e-6)
	assert_true(text.bold and text.italic)
	# The plan's line colour where a shape has none of its own; damaged
	# colours and styles are left out.
	var plain: CustomSymbol.Shape = CustomSymbol.shape_from_data({"kind": "line", "points": [[0, 0], [1, 0]], "color": "nonsense", "style": "wavy", "width": 99})
	assert_eq(CustomSymbol.line_color(plain, Color.BLACK), Color.BLACK)
	assert_eq(plain.style, "solid")
	assert_almost_eq(plain.width, CustomSymbol.MAX_WIDTH, 1e-6)
	# A turned text's box turns with it.
	var tall: Rect2 = CustomSymbol.shape_bounds(text)
	text.angle = 0.0
	assert_gt(tall.size.y, CustomSymbol.shape_bounds(text).size.y)


func test_points_snap_to_other_shapes() -> void:
	_def.shapes.append(_rect(Vector2(0.0, 0.0), Vector2(0.1, 0.1)))
	var near: Vector2 = _canvas.to_screen(Vector2(0.1, 0.1)) + Vector2(4, -3)
	assert_eq(_canvas.snap_point(near), Vector2(0.1, 0.1), "onto the corner near it")
	assert_eq(_canvas.snap_point(_canvas.to_screen(Vector2(0.05, 0.05)) + Vector2(3, 2)), Vector2(0.05, 0.05), "onto its middle")
	var far: Vector2 = _canvas.to_screen(Vector2(0.3021, 0.2))
	assert_almost_eq(_canvas.snap_point(far).x, 0.3, 1e-6, "else onto the grid")
	_canvas.grid = 0.0
	assert_almost_eq(_canvas.snap_point(far).x, 0.3021, 1e-4, "no grid")
	assert_eq(_canvas.snap_point(near, PackedInt32Array([0])).distance_to(Vector2(0.1, 0.1)) > 0.001, true, "not onto its own points")


func test_pictures_taken_in() -> void:
	var image: Image = Image.create(1024, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var shape: CustomSymbol.Shape = CustomSymbol.image_shape(image)
	assert_eq(shape.kind, "image")
	var box: Rect2 = CustomSymbol.shape_bounds(shape)
	assert_almost_eq(box.size.x, CustomSymbol.IMAGE_SIZE, 1e-6, "its longer side")
	assert_almost_eq(box.size.y, CustomSymbol.IMAGE_SIZE * 0.5, 1e-6, "as wide as it was tall")
	var texture: Texture2D = CustomSymbol.picture(shape.image)
	assert_not_null(texture)
	assert_eq(texture.get_width(), CustomSymbol.IMAGE_PIXELS, "made smaller")
	assert_null(CustomSymbol.picture("bm90IGEgcGljdHVyZQ=="), "not a PNG")
	# Mirrored and turned, saved.
	CustomSymbol.mirror_shape(shape, Vector2.ZERO, true)
	assert_true(shape.flipped)
	CustomSymbol.turn_shape(shape, Vector2.ZERO, true)
	assert_almost_eq(CustomSymbol.shape_bounds(shape).size.y, CustomSymbol.IMAGE_SIZE, 1e-6, "standing up")
	var again: CustomSymbol.Shape = CustomSymbol.shape_from_data(JSON.parse_string(JSON.stringify(CustomSymbol.shape_to_data(shape))))
	assert_eq(again.image, shape.image)
	assert_true(again.flipped)
	assert_almost_eq(again.angle, -90.0, 1e-6)
	assert_null(CustomSymbol.shape_from_data({"kind": "image", "points": [[0, 0], [1, 1]]}), "no picture")
	assert_eq(CustomSymbol.distance_to(again, CustomSymbol.shape_bounds(again).get_center()), 0.0, "picked by a click inside")


func test_editor_panel_sets_the_look_and_points() -> void:
	var editor: SymbolEditor = SymbolEditor.new()
	add_child_autofree(editor)
	var def: CustomSymbol = CustomSymbol.new()
	def.id = CustomSymbol.new_id()
	def.name = "Box"
	def.shapes.append(_rect(Vector2(0.0, 0.0), Vector2(0.1, 0.1)))
	editor.open(def)
	var canvas: SymbolCanvas = editor.canvas
	# Nothing picked: the look of new shapes.
	(editor.get("_width") as SpinBox).value = 0.8
	assert_almost_eq(canvas.look.width, 0.8, 1e-6)
	assert_eq(canvas.symbol.shapes[0].width, 0.0)
	canvas.selected = 0
	(editor.get("_width") as SpinBox).value = 1.2
	assert_almost_eq(canvas.symbol.shapes[0].width, 1.2, 1e-6, "the shape picked")
	(editor.get("_style") as OptionButton).item_selected.emit(1)
	assert_eq(canvas.symbol.shapes[0].style, "dash")
	# Its points typed in millimetres.
	var points: GridContainer = editor.get("_points")
	assert_eq(points.get_child_count(), 6, "two points, x and y each")
	(points.get_child(4) as SpinBox).value = 150.0
	assert_almost_eq(canvas.symbol.shapes[0].points[1].x, 0.15, 1e-6)
	# A picture from a file.
	var image: Image = Image.create(40, 20, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLUE)
	image.save_png(PICTURE)
	editor.add_picture(PICTURE)
	assert_eq(canvas.symbol.shapes.size(), 2)
	assert_eq(canvas.symbol.shapes[1].kind, "image")
	assert_eq(canvas.selected, 1, "picked to move and scale")
	editor.add_picture("user://test_missing.png")
	assert_eq(canvas.symbol.shapes.size(), 2, "a file that cannot be read adds nothing")
	editor.hide()


func test_turned_by_any_angle() -> void:
	_def.shapes.append(_rect(Vector2(-0.1, -0.05), Vector2(0.1, 0.05)))
	var line: CustomSymbol.Shape = CustomSymbol.Shape.new()
	line.kind = "line"
	line.points = PackedVector2Array([Vector2(0.3, 0.0), Vector2(0.5, 0.0)])
	_def.shapes.append(line)
	_canvas.selected = 0
	_canvas.rotate_selected(30.0)
	var rect: CustomSymbol.Shape = _def.shapes[0]
	assert_almost_eq(rect.angle, 30.0, 1e-6, "a rectangle keeps its box and turns by its angle")
	assert_true(CustomSymbol.box_middle(rect).is_equal_approx(Vector2.ZERO), "about its middle")
	var corner: Vector2 = CustomSymbol.handle_points(rect)[1]
	assert_true(corner.is_equal_approx(Vector2(0.1, 0.05).rotated(-deg_to_rad(30.0))), "its corner turned anticlockwise")
	assert_gt(CustomSymbol.shape_bounds(rect).size.y, 0.1, "the box round it grows")
	# A corner dragged: the other one stays where it is drawn.
	var other: Vector2 = CustomSymbol.handle_points(rect)[0]
	CustomSymbol.set_handle(rect, 1, corner + Vector2(0.05, 0.0))
	assert_true(CustomSymbol.handle_points(rect)[0].is_equal_approx(other))
	assert_true(CustomSymbol.handle_points(rect)[1].is_equal_approx(corner + Vector2(0.05, 0.0)))
	assert_almost_eq(rect.angle, 30.0, 1e-6)
	# R still turns it a quarter, F mirrors its angle; saved.
	_canvas.turn_selected(true)
	assert_almost_eq(rect.angle, -60.0, 1e-6)
	_canvas.mirror_selected(true)
	assert_almost_eq(rect.angle, 60.0, 1e-6)
	var again: CustomSymbol.Shape = CustomSymbol.shape_from_data(CustomSymbol.shape_to_data(rect))
	assert_almost_eq(again.angle, 60.0, 1e-6)
	# Several together about their middle; a line by its points.
	_canvas.select_all()
	var middle: Vector2 = _canvas.selection_bounds().get_center().snapped(Vector2(_canvas.grid, _canvas.grid))
	_canvas.rotate_selected(90.0)
	assert_true(_def.shapes[1].points[0].is_equal_approx(middle + (Vector2(0.3, 0.0) - middle).rotated(-PI / 2.0)), "the line round the middle of both")
	assert_almost_eq(_def.shapes[1].angle, 0.0, 1e-6, "a line has no angle of its own")
	_canvas.selected = 1
	_canvas.rotate_selected(45.0)
	var d: Vector2 = _def.shapes[1].points[1] - _def.shapes[1].points[0]
	assert_almost_eq(absf(d.x), absf(d.y), 1e-6, "a line turned by 45°")
	# A turned picture is picked inside its turned box only.
	var image: Image = Image.create(20, 10, false, Image.FORMAT_RGBA8)
	var picture: CustomSymbol.Shape = CustomSymbol.image_shape(image)
	CustomSymbol.rotate_shape(picture, Vector2.ZERO, 90.0)
	assert_almost_eq(picture.angle, 90.0, 1e-6)
	assert_eq(CustomSymbol.distance_to(picture, Vector2(0.0, 0.09)), 0.0, "standing up")
	assert_gt(CustomSymbol.distance_to(picture, Vector2(0.09, 0.0)), 0.0)


func test_fonts_of_the_computer() -> void:
	var label: CustomSymbol.Shape = CustomSymbol.Shape.new()
	label.kind = "text"
	label.text = "TV"
	label.points = PackedVector2Array([Vector2.ZERO])
	var plan_font: Font = ThemeDB.fallback_font
	assert_eq(CustomSymbol.face(plan_font, "", false, false), plan_font, "the plan's own font")
	assert_eq(CustomSymbol.face(plan_font, "No Such Family", false, false), plan_font, "a family the computer lacks: the plan's")
	var families: PackedStringArray = CustomSymbol.families()
	if not families.is_empty():
		var system: Font = CustomSymbol.face(plan_font, families[0], true, false)
		assert_true(system is SystemFont, "a family of the computer")
		assert_eq((system as SystemFont).font_weight, 700, "bold")
		label.font = families[0]
	var again: CustomSymbol.Shape = CustomSymbol.shape_from_data(JSON.parse_string(JSON.stringify(CustomSymbol.shape_to_data(label))))
	assert_eq(again.font, label.font, "saved")
	# Picked in the editor's list; one from another computer is listed as missing.
	var editor: SymbolEditor = SymbolEditor.new()
	add_child_autofree(editor)
	var def: CustomSymbol = CustomSymbol.new()
	def.id = CustomSymbol.new_id()
	def.name = "Label"
	var other: CustomSymbol.Shape = label.copy()
	other.font = "Font Of Another Computer"
	def.shapes.append(other)
	editor.open(def)
	var list: OptionButton = editor.get("_font")
	assert_eq(str(list.get_item_metadata(0)), "", "the plan's font first")
	assert_eq(list.item_count, families.size() + 1)
	editor.canvas.selected = 0
	assert_eq(str(list.get_item_metadata(list.selected)), "Font Of Another Computer")
	assert_string_contains(list.get_item_text(list.selected), "Font Of Another Computer")
	list.item_selected.emit(0)
	assert_eq(editor.canvas.symbol.shapes[0].font, "", "back to the plan's font")
	# Rotate asks for an angle.
	var typed: LineEdit = (editor.get("_rotate_angle") as SpinBox).get_line_edit()
	typed.text = "30"
	(editor.get("_rotate_dialog") as ConfirmationDialog).confirmed.emit()
	assert_almost_eq(editor.canvas.symbol.shapes[0].angle, 30.0, 1e-6, "turned by the angle typed, OK")
	typed.text = "-10"
	typed.text_submitted.emit("-10")
	assert_almost_eq(editor.canvas.symbol.shapes[0].angle, 20.0, 1e-6, "and by Enter")
	editor.hide()


func test_turned_by_the_rotation_handle() -> void:
	_def.shapes.append(_rect(Vector2(-0.1, -0.05), Vector2(0.1, 0.05)))
	_canvas.tool = SymbolCanvas.Tool.SELECT
	assert_true(is_nan(_canvas.rotation_handle().x), "none with nothing picked")
	_canvas.selected = 0
	var knob: Vector2 = _canvas.rotation_handle()
	assert_almost_eq(knob.x, _canvas.to_screen(Vector2.ZERO).x, 0.01, "over the middle")
	assert_almost_eq(knob.y, _canvas.to_screen(Vector2(0, -0.05)).y - SymbolCanvas.ROTATE_REACH, 0.01, "over the top of the box")
	assert_eq(_canvas._pressed(knob)["kind"], "rotate")
	# Dragged a quarter round its middle anticlockwise, a little off: whole degrees.
	var middle: Vector2 = _canvas.to_screen(Vector2.ZERO)
	var reach: float = knob.distance_to(middle)
	var to: Vector2 = middle + Vector2.from_angle(-PI / 2.0 - deg_to_rad(37.3)) * reach
	_canvas._press_at = knob
	_canvas._press = {"kind": "rotate"}
	_canvas._dragging = true
	_canvas._mouse = to
	assert_almost_eq(_canvas._rotation_degrees(to), 37.0, 1e-6, "whole degrees")
	assert_almost_eq(_canvas._shown(0).angle, 37.0, 1e-6, "shown turned while dragged")
	_canvas._shift = true
	assert_almost_eq(_canvas._rotation_degrees(to), 30.0, 1e-6, "15° steps with Shift")
	_canvas._shift = false
	_canvas._press = {}
	_canvas._release({"kind": "rotate"}, to)
	_canvas._dragging = false
	assert_almost_eq(_def.shapes[0].angle, 37.0, 1e-6, "turned anticlockwise")
	assert_true(CustomSymbol.box_middle(_def.shapes[0]).is_equal_approx(Vector2.ZERO), "about its middle")
	_canvas.undo()
	assert_almost_eq(_def.shapes[0].angle, 0.0, 1e-6, "one undo step")
	# A click on it without dragging turns nothing.
	_canvas.selected = 0
	_canvas._press_at = _canvas.rotation_handle()
	_canvas._dragging = false
	_canvas._release({"kind": "rotate"}, _canvas._press_at)
	assert_almost_eq(_def.shapes[0].angle, 0.0, 1e-6)
