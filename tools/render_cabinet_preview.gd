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
	# Round 3: the devices drawn after the reference photos.
	await _breakers()
	await _fuses()
	await _contactors()
	await _relays()
	await _timers()
	await _cabinet("B", APP_K, "cabinet")
	await _cabinet("B", SHEET_K, "cabinet_detail")
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
				p.rect(Rect2(Vector2.ZERO, cell_mm), Color("efece4"), 1.0)
				if rail_y >= 0.0:
					CabinetParts.din_rail(p.shifted(Vector2(0, rail_y - CabinetParts.RAIL_H * 0.5)), cell_mm.x, "A")
				cell.call(p, r, c))


## Painter for a part of [param size] mm centred across the cell, top at [param top].
static func _centred(p: CabinetPainter, cell_w: float, part_w: float, top: float) -> CabinetPainter:
	return p.shifted(Vector2((cell_w - part_w) * 0.5, top))


func _breakers() -> void:
	var cols: PackedStringArray = ["Off", "On", "Tripped (as real)", "Tripped (marked)", "3-pole, on"]
	await _grid("breaker", "Circuit breaker (jistič) FA", [""], cols, Vector2(66, 100), 50.0, func(p: CabinetPainter, _r: int, c: int) -> void:
		var poles: int = 3 if c == 4 else 1
		CabinetParts.breaker(_centred(p, 66, 18 * poles, 5), poles, c == 1 or c == 4, c == 2 or c == 3, "B10" if poles == 1 else "C16", [], c == 3))


func _fuses() -> void:
	var cols: PackedStringArray = ["Closed", "Open", "Blown", "Blown, open", "3-pole"]
	await _grid("fuse_holder", "Fuse holder (pojistkový odpínač) FU", [""], cols, Vector2(62, 100), 50.0, func(p: CabinetPainter, _r: int, c: int) -> void:
		var poles: int = 3 if c == 4 else 1
		CabinetParts.fuse_holder(_centred(p, 62, 18 * poles, 5), poles, c != 1 and c != 3, c == 2 or c == 3))


func _contactors() -> void:
	var cols: PackedStringArray = ["Off", "On", "On, overload relay tripped"]
	await _grid("contactor", "Contactor (stykač) KM with overload relay (tepelné relé) F", [""], cols, Vector2(60, 145), 45.0, func(p: CabinetPainter, _r: int, c: int) -> void:
		var q: CabinetPainter = _centred(p, 60, 45, 6.5)
		CabinetParts.contactor(q, c >= 1, true)
		CabinetParts.label(q, Vector2(22.7, 46.6), "-KM1")
		CabinetParts.overload_relay(q.shifted(Vector2(0, CabinetParts.CONTACTOR.y)), c == 2)
		CabinetParts.label(q, Vector2(22.5, CabinetParts.CONTACTOR.y + CabinetParts.OVERLOAD.y + 4.0), "-F1", "A", 12.0))


func _relays() -> void:
	var cols: PackedStringArray = ["Off", "On"]
	await _grid("relay", "Auxiliary relay (pomocné relé) KA", [""], cols, Vector2(40, 100), 50.0, func(p: CabinetPainter, _r: int, c: int) -> void:
		CabinetParts.relay(_centred(p, 40, CabinetParts.RELAY.x, 50.0 - CabinetParts.RELAY.y * 0.5), c == 1, true))


func _timers() -> void:
	var cols: PackedStringArray = ["No power", "Timing", "Output on"]
	await _grid("timer", "Time relay (časové relé) KT", [""], cols, Vector2(40, 100), 50.0, func(p: CabinetPainter, _r: int, c: int) -> void:
		CabinetParts.timer(_centred(p, 40, 18, 5), c))


const L1 := Color("d8693d")
const L2 := Color("5c6a99")
const L3 := Color("a597e0")
const N := Color("1f9be6")


# --- Assembled cabinet --------------------------------------------------------------

func _cabinet(plate: String, k: float, file: String) -> void:
	var size_mm: Vector2 = Vector2(250, 445)
	var detail: bool = k > APP_K
	var px: Vector2i = Vector2i(size_mm * k) + Vector2i(32, 70)
	if detail:
		px = Vector2i(Vector2(size_mm.x, 330) * k) + Vector2i(32, 70)
	await _shot(file, px, func(ci: CanvasItem) -> void:
		_text(ci, Vector2(16, 32), "Switchboard, round 3%s" % [": detail (2x)" if detail else " (size in the app)"], 20, HEADING, true)
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
	for y: float in [8.0, 138.0, 316.0, 405.0]:
		CabinetParts.duct(p.shifted(Vector2(inner_left + duct_w, y)), inner_right - inner_left - 2 * duct_w, 28.0, false, "A")
	CabinetParts.duct(p.shifted(Vector2(inner_left + 2.0, 8.0)), 425.0, duct_w - 2.0, true, "A")
	CabinetParts.duct(p.shifted(Vector2(inner_right - duct_w, 8.0)), 425.0, duct_w - 2.0, true, "A")
	# Rail 1: breaker, fuse holders, time relay, relays.
	var rail1: float = 91.0
	CabinetParts.din_rail(p.shifted(Vector2(x0 - 2.0, rail1 - 17.5)), x1 - x0 + 4.0, "A")
	var x: float = x0
	var top1: float = rail1 - 45.0
	CabinetParts.breaker(p.shifted(Vector2(x, top1)), 3, true, false, "C10", [L1, L1, L2, L2, L3, L3])
	CabinetParts.label(p, Vector2(x + 27.0, top1 - 3.5), "-FA1")
	x += 54.0 + 2.0
	CabinetParts.fuse_holder(p.shifted(Vector2(x, top1)), 1, true, false, [L1, L1])
	CabinetParts.label(p, Vector2(x + 9.0, top1 - 1.0), "-FU1", "A", 14.0)
	x += 18.0 + 2.0
	CabinetParts.fuse_holder(p.shifted(Vector2(x, top1)), 1, false, false, [L1])
	CabinetParts.label(p, Vector2(x + 9.0, top1 - 1.0), "-FU2", "A", 14.0)
	x += 18.0 + 6.0
	CabinetParts.timer(p.shifted(Vector2(x, top1)), 1, 1, "S", {"A1": L1, "A2": N})
	CabinetParts.label(p, Vector2(x + 9.0, top1 - 3.5), "-KT1", "A", 14.0)
	x += 18.0 + 6.0
	for k: int in 2:
		var on: bool = k == 0
		CabinetParts.relay(p.shifted(Vector2(x, rail1 - CabinetParts.RELAY.y * 0.5)), on, true, {"A1": L1, "A2": N} if on else {})
		CabinetParts.label(p, Vector2(x + 7.9, rail1 - CabinetParts.RELAY.y * 0.5 - 3.5), "-KA%d" % (k + 1), "A", 14.0)
		x += CabinetParts.RELAY.x + 2.0
	# Rail 2: contactors, the overload relay under the first.
	var rail2: float = 210.0
	CabinetParts.din_rail(p.shifted(Vector2(x0 - 2.0, rail2 - 17.5)), x1 - x0 + 4.0, "A")
	var top2: float = rail2 - 38.5
	var on_reach: Dictionary = {"1": L1, "3": L2, "5": L3, "2": L1, "4": L2, "6": L3, "A1": L1, "A2": N}
	CabinetParts.contactor(p.shifted(Vector2(x0, top2)), true, true, [["13", "NO", "14"], ["21", "NC", "22"]], on_reach)
	CabinetParts.label(p, Vector2(x0 + 22.7, top2 + 46.6), "-KM1")
	CabinetParts.overload_relay(p.shifted(Vector2(x0, top2 + CabinetParts.CONTACTOR.y)), false, "5", {"2": L1, "4": L2, "6": L3, "95": L1, "96": L1})
	CabinetParts.label(p, Vector2(x0 + 22.5, top2 + CabinetParts.CONTACTOR.y + CabinetParts.OVERLOAD.y + 4.0), "-F1", "A", 12.0)
	CabinetParts.contactor(p.shifted(Vector2(x0 + 50.0, top2)), false, true, [["13", "NO", "14"], ["21", "NC", "22"]], {"1": L1, "3": L2, "5": L3})
	CabinetParts.label(p, Vector2(x0 + 72.7, top2 + 46.6), "-KM2")
	# Rail 3: terminal strips.
	var rail3: float = 380.0
	CabinetParts.din_rail(p.shifted(Vector2(x0 - 2.0, rail3 - 17.5)), x1 - x0 + 4.0, "A")
	var items: Array = []
	var reach: Array[Color] = [L1, L1, L1, Color.TRANSPARENT, L1, L1, Color.TRANSPARENT, L1, Color.TRANSPARENT]
	for i: int in 9:
		items.append({"label": str(i + 1), "kind": "L", "reach": reach[i]})
	items.append({"label": "N", "kind": "N", "reach": N})
	items.append({"label": "PE", "kind": "PE"})
	var strip_w: float = CabinetParts.terminal_strip(p.shifted(Vector2(x0, rail3 - 23.5)), "X1", items)
	var motor: Array = []
	for t: Array in [["U", L1], ["V", L2], ["W", L3], ["PE", Color.TRANSPARENT]]:
		motor.append({"label": t[0], "kind": "PE" if t[0] == "PE" else "L", "reach": t[1]})
	CabinetParts.terminal_strip(p.shifted(Vector2(x0 + strip_w + 6.0, rail3 - 23.5)), "X2", motor)
