extends SceneTree
## Renders the look variants of the switchboard parts to PNG files for review.
## Needs a display (xvfb-run on a server):
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tools/render_cabinet_preview.gd -- <out_dir>

const BG := Color("17191d")
const CAPTION := Color("aab1ba")
const HEADING := Color("e8eaef")
## Pixels per mm on the part sheets (twice the size in the app).
const SHEET_K: float = 4.4
## Pixels per mm in the app.
const APP_K: float = 2.2

var out_dir: String = "user://cabinet_preview/"


class Sheet extends Control:
	var paint: Callable

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BG)
		paint.call(self)


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _breakers()
	await _fuses()
	await _contactors()
	await _overloads()
	await _relays()
	await _timers()
	await _terminals()
	await _rails_ducts_labels()
	for plate: String in ["A", "B", "C", "D"]:
		await _cabinet(plate, APP_K, "cabinet_plate_" + plate)
	await _cabinet("A", SHEET_K, "cabinet_detail")
	quit()


func _shot(file: String, size: Vector2i, paint: Callable) -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet: Sheet = Sheet.new()
	sheet.paint = paint
	sheet.size = Vector2(size)
	viewport.add_child(sheet)
	for i: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(out_dir + file + ".png")
	viewport.queue_free()
	print("saved ", file)


static func _text(ci: CanvasItem, at: Vector2, s: String, size: int, color: Color, bold: bool = false) -> void:
	ci.draw_string(AppTheme.bold_font() if bold else AppTheme.ui_font(), at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Sheet of [param rows] x [param cols] cells of [param cell_mm] millimetres;
## every cell shows a piece of mounting plate with a DIN rail at
## [param rail_y] mm (none when negative) and [param cell] draws the part
## with (painter, row, col).
func _grid(file: String, title: String, rows: PackedStringArray, cols: PackedStringArray, cell_mm: Vector2, rail_y: float, cell: Callable) -> void:
	var left: float = 200.0
	var top: float = 74.0
	var gap: float = 16.0
	var cell_px: Vector2 = cell_mm * SHEET_K
	var size: Vector2i = Vector2i(int(left + cols.size() * (cell_px.x + gap) + 10.0), int(top + rows.size() * (cell_px.y + gap) + 10.0))
	await _shot(file, size, func(ci: CanvasItem) -> void:
		_text(ci, Vector2(16, 32), title, 22, HEADING, true)
		for c: int in cols.size():
			_text(ci, Vector2(left + c * (cell_px.x + gap), top - 12.0), cols[c], 16, CAPTION, true)
		for r: int in rows.size():
			var y: float = top + r * (cell_px.y + gap)
			_text(ci, Vector2(16, y + 26.0), rows[r], 18, HEADING, true)
			for c: int in cols.size():
				var at: Vector2 = Vector2(left + c * (cell_px.x + gap), y)
				var p: CabinetPainter = CabinetPainter.new(ci, SHEET_K, at)
				p.rect(Rect2(Vector2.ZERO, cell_mm), Color("c9cdd0"), 1.0)
				if rail_y >= 0.0:
					CabinetParts.din_rail(p.shifted(Vector2(0, rail_y - CabinetParts.RAIL_H * 0.5)), cell_mm.x, "A")
				cell.call(p, r, c))


## Painter for a part of [param size] mm centred across the cell, top at [param top].
static func _centred(p: CabinetPainter, cell_w: float, part_w: float, top: float) -> CabinetPainter:
	return p.shifted(Vector2((cell_w - part_w) * 0.5, top))


func _breakers() -> void:
	var cols: PackedStringArray = ["Off", "On", "Tripped", "3-pole, on"]
	await _grid("breaker", "Circuit breaker (jistič) FA", ["A  black lever", "B  grey lever"], cols, Vector2(66, 100), 50.0, func(p: CabinetPainter, r: int, c: int) -> void:
		var variant: String = "A" if r == 0 else "B"
		var poles: int = 3 if c == 3 else 1
		CabinetParts.breaker(_centred(p, 66, 18 * poles, 5), poles, c == 1 or c == 3, c == 2, variant))


func _fuses() -> void:
	var cols: PackedStringArray = ["Closed", "Open", "Blown", "Blown, open", "3-pole"]
	await _grid("fuse_holder", "Fuse holder (pojistkový odpínač) FU", ["A  grey, LED", "B  white, window"], cols, Vector2(62, 100), 50.0, func(p: CabinetPainter, r: int, c: int) -> void:
		var variant: String = "A" if r == 0 else "B"
		var poles: int = 3 if c == 4 else 1
		CabinetParts.fuse_holder(_centred(p, 62, 18 * poles, 5), poles, c != 1 and c != 3, c == 2 or c == 3, variant))


func _contactors() -> void:
	var cols: PackedStringArray = ["Off", "On", "On, highlighted"]
	await _grid("contactor", "Contactor (stykač) KM", ["A  dark", "B  light", "C  modular"], cols, Vector2(60, 100), 50.0, func(p: CabinetPainter, r: int, c: int) -> void:
		var variant: String = ["A", "B", "C"][r]
		var w: float = 36.0 if variant == "C" else CabinetParts.CONTACTOR.x
		var h: float = 90.0 if variant == "C" else CabinetParts.CONTACTOR.y
		CabinetParts.contactor(_centred(p, 60, w, 50.0 - h * 0.5), c >= 1, variant, ["A1", "1/L1", "3/L2", "5/L3", "13NO"], ["A2", "2/T1", "4/T2", "6/T3", "14NO"], c == 2)
		if variant != "C":
			CabinetParts.label(_centred(p, 60, 45, 10.0), Vector2(22.5, 53.5), "-KM1"))


func _overloads() -> void:
	var cols: PackedStringArray = ["Normal", "Tripped"]
	await _grid("overload", "Overload relay (tepelné relé) F under its contactor", ["A  dark", "B  light"], cols, Vector2(60, 150), 50.0, func(p: CabinetPainter, r: int, c: int) -> void:
		var variant: String = "A" if r == 0 else "B"
		var q: CabinetPainter = _centred(p, 60, 45, 10)
		CabinetParts.contactor(q, c == 0, variant)
		CabinetParts.overload_relay(q.shifted(Vector2(0, 80)), c == 1, variant)
		CabinetParts.label(q, Vector2(22.5, 53.5), "-KM1")
		CabinetParts.label(q, Vector2(22.5, 80.0 + 61.5), "-F1", "A", 12.0))


func _relays() -> void:
	var cols: PackedStringArray = ["Off", "On", "On, highlighted"]
	await _grid("relay", "Auxiliary relay (pomocné relé) KA", ["A  plug-in relay", "B  control relay"], cols, Vector2(60, 100), 50.0, func(p: CabinetPainter, r: int, c: int) -> void:
		var variant: String = "A" if r == 0 else "B"
		var size: Vector2 = CabinetParts.RELAY if r == 0 else CabinetParts.CONTACTOR
		CabinetParts.relay(_centred(p, 60, size.x, 50.0 - size.y * 0.5), c >= 1, variant, c == 2)
		if variant == "B":
			CabinetParts.label(_centred(p, 60, 45, 10.0), Vector2(22.5, 53.5), "-KA1"))


func _timers() -> void:
	var cols: PackedStringArray = ["No power", "Timing", "Output on"]
	await _grid("timer", "Time relay (časové relé) KT", ["A  dials", "B  display"], cols, Vector2(40, 100), 50.0, func(p: CabinetPainter, r: int, c: int) -> void:
		CabinetParts.timer(_centred(p, 40, 18, 5), c, "A" if r == 0 else "B"))


func _terminal_items(reach: bool) -> Array:
	var items: Array = []
	var colors: Array[Color] = [Color("d8693d"), Color("d8693d"), Color("d8693d"), Color.TRANSPARENT, Color("d8693d"), Color.TRANSPARENT]
	for i: int in 6:
		items.append({"label": str(i + 1), "kind": "L", "reach": colors[i] if reach else Color.TRANSPARENT})
	items.append({"label": "N", "kind": "N", "reach": Color("1f9be6") if reach else Color.TRANSPARENT})
	items.append({"label": "PE", "kind": "PE"})
	return items


func _terminals() -> void:
	var rows: PackedStringArray = ["A  screw, grey", "B  push-in", "C  screw, beige", "A + voltage"]
	await _grid("terminals", "Terminal strip (svorkovnice) X1", rows, ["Strip X1 (6 terminals, N, PE)"], Vector2(80, 57), 28.5, func(p: CabinetPainter, r: int, _c: int) -> void:
		var variant: String = ["A", "B", "C", "A"][r]
		CabinetParts.terminal_strip(p.shifted(Vector2(8, 5)), "X1", _terminal_items(r == 3), variant))


func _rails_ducts_labels() -> void:
	var rows: PackedStringArray = ["DIN rail", "Wire duct", "Labels"]
	await _grid("rail_duct_label", "DIN rail, wire duct, designation labels", rows, ["A", "B", "C"], Vector2(70, 45), -1.0, func(p: CabinetPainter, r: int, c: int) -> void:
		if r == 0 and c < 2:
			CabinetParts.din_rail(p.shifted(Vector2(0, 5)), 70, ["A", "B"][c])
		elif r == 1 and c < 2:
			CabinetParts.duct(p.shifted(Vector2(0, 5)), 70, 30, false, ["A", "B"][c])
		elif c == 2 and r < 2:
			p.text_centered(Vector2(35, 22), "none" if r == 1 else "", 4.0, Color("6b7177"))
		elif r == 2:
			CabinetParts.label(p, Vector2(35, 22), "-KM1", ["A", "B", "C"][c], 16.0))


# --- Assembled cabinet --------------------------------------------------------------

func _cabinet(plate: String, k: float, file: String) -> void:
	var size_mm: Vector2 = Vector2(250, 445)
	var detail: bool = k > APP_K
	var px: Vector2i = Vector2i(size_mm * k) + Vector2i(32, 70)
	if detail:
		px = Vector2i(Vector2(size_mm.x, 330) * k) + Vector2i(32, 70)
	await _shot(file, px, func(ci: CanvasItem) -> void:
		_text(ci, Vector2(16, 32), "Switchboard -  plate %s%s" % [plate, ", detail (2x)" if detail else " (size in the app)"], 20, HEADING, true)
		var p: CabinetPainter = CabinetPainter.new(ci, k, Vector2(16, 54))
		_draw_cabinet(p, size_mm, plate))


static func _draw_cabinet(p: CabinetPainter, size: Vector2, plate: String) -> void:
	CabinetParts.plate(p, size, plate)
	var duct_w: float = 25.0
	var inner_left: float = 6.0
	var inner_right: float = size.x - 6.0
	var x0: float = inner_left + duct_w + 3.0
	var x1: float = inner_right - duct_w - 3.0
	# Ducts: across at the top, between the rails and at the bottom; down both sides.
	var across: Array[float] = [8.0, 138.0, 316.0, 405.0]
	for y: float in across:
		CabinetParts.duct(p.shifted(Vector2(inner_left + duct_w, y)), inner_right - inner_left - 2 * duct_w, 28.0, false, "A")
	CabinetParts.duct(p.shifted(Vector2(inner_left + 2.0, 8.0)), 425.0, duct_w - 2.0, true, "A")
	CabinetParts.duct(p.shifted(Vector2(inner_right - duct_w, 8.0)), 425.0, duct_w - 2.0, true, "A")
	# Rail 1: breaker, fuse holders, time relay, relay.
	var rail1: float = 91.0
	CabinetParts.din_rail(p.shifted(Vector2(x0 - 2.0, rail1 - 17.5)), x1 - x0 + 4.0, "A")
	var x: float = x0
	var top1: float = rail1 - 45.0
	CabinetParts.breaker(p.shifted(Vector2(x, top1)), 3, true, false, "A", "C10")
	CabinetParts.label(p, Vector2(x + 27.0, top1 - 3.5), "-FA1")
	x += 54.0 + 2.0
	CabinetParts.fuse_holder(p.shifted(Vector2(x, top1)), 1, true, false, "A", "4A")
	CabinetParts.label(p, Vector2(x + 9.0, top1 - 3.5), "-FU1", "A", 14.0)
	x += 18.0 + 2.0
	CabinetParts.fuse_holder(p.shifted(Vector2(x, top1)), 1, false, false, "A", "2A")
	CabinetParts.label(p, Vector2(x + 9.0, top1 - 3.5), "-FU2", "A", 14.0)
	x += 18.0 + 6.0
	CabinetParts.timer(p.shifted(Vector2(x, top1)), 1, "A")
	CabinetParts.label(p, Vector2(x + 9.0, top1 - 3.5), "-KT1", "A", 14.0)
	x += 18.0 + 6.0
	CabinetParts.relay(p.shifted(Vector2(x, rail1 - CabinetParts.RELAY.y * 0.5)), true, "A")
	CabinetParts.label(p, Vector2(x + 13.5, rail1 - CabinetParts.RELAY.y * 0.5 - 3.5), "-KA1", "A", 14.0)
	# Rail 2: contactors, the overload relay under the first.
	var rail2: float = 210.0
	CabinetParts.din_rail(p.shifted(Vector2(x0 - 2.0, rail2 - 17.5)), x1 - x0 + 4.0, "A")
	var top2: float = rail2 - 40.0
	CabinetParts.contactor(p.shifted(Vector2(x0, top2)), true, "A")
	CabinetParts.label(p, Vector2(x0 + 22.5, top2 + 53.5), "-KM1")
	CabinetParts.overload_relay(p.shifted(Vector2(x0, top2 + 80.0)), false, "A")
	CabinetParts.label(p, Vector2(x0 + 22.5, top2 + 80.0 + 61.5), "-F1", "A", 12.0)
	CabinetParts.contactor(p.shifted(Vector2(x0 + 50.0, top2)), false, "A")
	CabinetParts.label(p, Vector2(x0 + 72.5, top2 + 53.5), "-KM2")
	CabinetParts.relay(p.shifted(Vector2(x0 + 100.0, top2)), false, "B")
	CabinetParts.label(p, Vector2(x0 + 122.5, top2 + 53.5), "-KA2")
	# Rail 3: terminal strips.
	var rail3: float = 380.0
	CabinetParts.din_rail(p.shifted(Vector2(x0 - 2.0, rail3 - 17.5)), x1 - x0 + 4.0, "A")
	var items: Array = []
	for i: int in 9:
		items.append({"label": str(i + 1), "kind": "L"})
	items.append({"label": "N", "kind": "N"})
	items.append({"label": "PE", "kind": "PE"})
	var strip_w: float = CabinetParts.terminal_strip(p.shifted(Vector2(x0, rail3 - 23.5)), "X1", items, "A")
	var motor: Array = []
	for t: String in ["U", "V", "W", "PE"]:
		motor.append({"label": t, "kind": "PE" if t == "PE" else "L"})
	CabinetParts.terminal_strip(p.shifted(Vector2(x0 + strip_w + 6.0, rail3 - 23.5)), "X2", motor, "A")
