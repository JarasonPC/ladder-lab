class_name DatasheetLayout
extends RefCounted
## One page of a datasheet laid out on A4 paper, in points (1/72 inch): what
## [DatasheetPage] draws. [method compose] lays out all pages of a
## [Datasheet] like a manufacturer's datasheet: a dark band with the part's
## group and letters on every page, the title with the summary, the symbol
## beside the description and features, the terminal assignment (continued
## on the next pages when it is long), the technical data beside the function
## diagram, a footer with the page number, and the device front on a page of
## its own. Texts are wrapped with the fonts they are drawn in. No nodes.
##
## Items, each a Dictionary with "type" and "rect" (its extent on the page):
## - "text": "at" (baseline start), "text", "size", "font" ([enum Face]), "color" ([enum Ink])
## - "box": "fill" ([enum Ink])
## - "line": "from", "to", "width", "color"
## - "symbol": "origin" and "scale" of the part's symbol
## - "diagram": the function diagram or characteristic
## - "front": the device front with its terminals

enum Face { REGULAR, BOLD, MONO }
## Colours, taken from [SchematicTheme] when drawn (paper, line colour,
## muted text, designation teal, faint rules and the zebra of tables).
enum Ink { PAPER, INK, MUTED, TEAL, RULE, TINT }

## A4 in points.
const PAGE := Vector2(595.0, 842.0)
const MARGIN: float = 36.0
const BAND_H: float = 24.0
## Lowest point of the content (the footer goes below it).
const BOTTOM: float = PAGE.y - 44.0
const SYMBOL_COLUMN: float = 196.0
const GAP: float = 18.0
const BODY: int = 9
const SMALL: int = 8
const HEADING: int = 8
const LINE: float = 1.38
## Height of a time-current characteristic; of a row of a timing diagram.
const CURVE_H: float = 150.0
const TIMER_ROW: float = 30.0

var items: Array[Dictionary] = []
## 1-based number of this page and the number of pages.
var page_number: int = 1
var page_count: int = 1
## The page shows the device front.
var front: bool = false
## Terminal assignment rows on this page.
var terminal_rows: int = 0


## The pages of [param sheet].
static func compose(sheet: Datasheet) -> Array[DatasheetLayout]:
	return _Composer.new(sheet).run()


static func font(face: Face) -> Font:
	match face:
		Face.BOLD:
			return AppTheme.bold_font()
		Face.MONO:
			return AppTheme.mono_font()
	return AppTheme.ui_font()


static func text_width(text: String, face: Face, size: int) -> float:
	return font(face).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## [param text] broken into lines no wider than [param width].
static func wrap(text: String, face: Face, size: int, width: float) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for paragraph: String in text.split("\n"):
		var line: String = ""
		for word: String in paragraph.split(" ", false):
			var candidate: String = word if line.is_empty() else line + " " + word
			if line.is_empty() or text_width(candidate, face, size) <= width:
				line = candidate
			else:
				lines.append(line)
				line = word
		lines.append(line)
	return lines


func add_text(at: Vector2, text: String, size: int, face: Face = Face.REGULAR, color: Ink = Ink.INK) -> void:
	var f: Font = font(face)
	var w: float = text_width(text, face, size)
	var rect: Rect2 = Rect2(at.x, at.y - f.get_ascent(size), w, f.get_height(size))
	items.append({"type": "text", "at": at, "text": text, "size": size, "font": face, "color": color, "rect": rect})


## Text ending at [param right_x].
func add_text_right(right_x: float, y: float, text: String, size: int, face: Face = Face.REGULAR, color: Ink = Ink.INK) -> void:
	add_text(Vector2(right_x - text_width(text, face, size), y), text, size, face, color)


func add_box(rect: Rect2, fill: Ink) -> void:
	items.append({"type": "box", "rect": rect, "fill": fill})


func add_line(from: Vector2, to: Vector2, width: float = 0.6, color: Ink = Ink.RULE) -> void:
	items.append({"type": "line", "from": from, "to": to, "width": width, "color": color, "rect": Rect2(from, Vector2.ZERO).expand(to)})


## The first item of [param type], or {}.
func item(type: String) -> Dictionary:
	for i: Dictionary in items:
		if i["type"] == type:
			return i
	return {}


## Lays out the pages of one datasheet.
class _Composer:
	extends RefCounted

	var sheet: Datasheet
	var pages: Array[DatasheetLayout] = []
	var page: DatasheetLayout
	var y: float = 0.0
	var left: float = DatasheetLayout.MARGIN
	var right: float = DatasheetLayout.PAGE.x - DatasheetLayout.MARGIN

	func _init(p_sheet: Datasheet) -> void:
		sheet = p_sheet

	func run() -> Array[DatasheetLayout]:
		_new_page(true)
		_symbol_and_description()
		if not sheet.terminals.is_empty():
			_table(tr("Terminal assignment"), [tr("Terminal"), tr("Name"), tr("Function")], [52.0, 118.0], sheet.terminals, true)
		_data_and_diagram()
		if not sheet.table.is_empty():
			_table(sheet.table_title, [tr("Code"), tr("Function")], [52.0], sheet.table, false)
		if not sheet.front.is_empty():
			_new_page(false)
			page.front = true
			_front()
		for i: int in pages.size():
			pages[i].page_number = i + 1
			pages[i].page_count = pages.size()
			_band_and_footer(pages[i])
		return pages

	func _new_page(first: bool) -> void:
		page = DatasheetLayout.new()
		pages.append(page)
		y = DatasheetLayout.BAND_H + 26.0
		var letters: String = "-" + sheet.letters
		if first:
			var size: int = 20
			var letters_w: float = DatasheetLayout.text_width(letters, Face.MONO, 18)
			var title_lines: PackedStringArray = DatasheetLayout.wrap(sheet.title, Face.BOLD, size, right - left - letters_w - 16.0)
			for line: String in title_lines:
				page.add_text(Vector2(left, y), line, size, Face.BOLD)
				y += size * 1.2
			page.add_text_right(right, DatasheetLayout.BAND_H + 26.0, letters, 18, Face.MONO, Ink.TEAL)
			y = _paragraph(sheet.summary, left, right - left, y - 4.0, DatasheetLayout.BODY, Ink.MUTED)
			y += 2.0
		else:
			page.add_text(Vector2(left, y - 6.0), sheet.title, 12, Face.BOLD)
			page.add_text_right(right, y - 6.0, letters, 12, Face.MONO, Ink.TEAL)
		page.add_line(Vector2(left, y), Vector2(right, y), 1.4, Ink.INK)
		y += 16.0

	## Writes [param text] wrapped into [param width] from the baseline after
	## [param top]; returns the y below it.
	func _paragraph(text: String, x: float, width: float, top: float, size: int, color: Ink = Ink.INK, face: Face = Face.REGULAR) -> float:
		var at: float = top + size
		for line: String in DatasheetLayout.wrap(text, face, size, width):
			page.add_text(Vector2(x, at), line, size, face, color)
			at += size * DatasheetLayout.LINE
		return at - size * DatasheetLayout.LINE + size * 0.45

	## A section heading over [param width] from [param x]; returns the y below it.
	func _heading(text: String, x: float, width: float, top: float) -> float:
		page.add_text(Vector2(x, top + DatasheetLayout.HEADING), text.to_upper(), DatasheetLayout.HEADING, Face.BOLD)
		var rule: float = top + DatasheetLayout.HEADING + 4.0
		page.add_line(Vector2(x, rule), Vector2(x + width, rule))
		return rule + 6.0

	## The symbol beside the description and features; a wide symbol (a PLC
	## with modules) across the page above them.
	func _symbol_and_description() -> void:
		var extent: Rect2 = DatasheetLayout.symbol_extent(sheet.component)
		var column: float = DatasheetLayout.SYMBOL_COLUMN
		var wide: bool = extent.size.x / extent.size.y > 2.5 and (column - 16.0) / extent.size.x < 0.6
		if wide:
			column = right - left
		# The symbol, upright, scaled to fit its frame.
		var below: float = _heading(tr("Symbol"), left, column, y)
		var room: Vector2 = Vector2(column - 16.0, 200.0)
		var scale: float = minf(1.2, minf(room.x / extent.size.x, room.y / extent.size.y))
		var frame: Rect2 = Rect2(left, below, column, maxf(extent.size.y * scale + 16.0, 70.0))
		page.add_line(frame.position, Vector2(frame.end.x, frame.position.y))
		page.add_line(Vector2(frame.end.x, frame.position.y), frame.end)
		page.add_line(frame.end, Vector2(frame.position.x, frame.end.y))
		page.add_line(Vector2(frame.position.x, frame.end.y), frame.position)
		page.items.append({"type": "symbol", "rect": frame, "scale": scale, "origin": frame.get_center() - extent.get_center() * scale})
		var left_end: float = _paragraph(tr("Symbol as drawn in the schematic (IEC 60617)."), left, column, frame.end.y + 2.0, 7, Ink.MUTED)
		# Description and features beside it, or below it.
		var x: float = left if wide else left + column + DatasheetLayout.GAP
		var width: float = right - x
		var at: float = _heading(tr("Description"), x, width, left_end + 14.0 if wide else y)
		for text: String in sheet.description:
			at = _paragraph(text, x, width, at, DatasheetLayout.BODY) + 5.0
		if not sheet.features.is_empty():
			at = _heading(tr("Features"), x, width, at + 6.0)
			for text: String in sheet.features:
				page.add_text(Vector2(x, at + DatasheetLayout.BODY), "•", DatasheetLayout.BODY)
				at = _paragraph(text, x + 10.0, width - 10.0, at, DatasheetLayout.BODY) + 3.0
		y = maxf(left_end, at) + 16.0

	## A table under heading [param title]: [param widths] of all columns but
	## the last; rows with an empty first cell are headings (terminal table).
	func _table(title: String, captions: Array, widths: Array, rows: Array[PackedStringArray], terminals: bool) -> void:
		var head_h: float = DatasheetLayout.HEADING + 30.0
		if y + head_h + 20.0 > DatasheetLayout.BOTTOM:
			_new_page(false)
		y = _table_head(title, captions, widths)
		var even: bool = false
		for row: PackedStringArray in rows:
			var cells: Array[PackedStringArray] = []
			var heading: bool = terminals and row[0].is_empty()
			if heading:
				cells.append(DatasheetLayout.wrap(row[1], Face.BOLD, DatasheetLayout.SMALL, right - left - 12.0))
			else:
				var x: float = left
				for c: int in row.size():
					var w: float = (widths[c] if c < widths.size() else right - x) - 12.0
					cells.append(DatasheetLayout.wrap(row[c], Face.MONO if c == 0 else Face.REGULAR, DatasheetLayout.SMALL if c > 0 else DatasheetLayout.BODY, w))
					x += widths[c] if c < widths.size() else 0.0
			var lines: int = 1
			for cell: PackedStringArray in cells:
				lines = maxi(lines, cell.size())
			var h: float = lines * DatasheetLayout.SMALL * DatasheetLayout.LINE + 8.0
			if y + h > DatasheetLayout.BOTTOM:
				_new_page(false)
				y = _table_head(title + " " + tr("(continued)"), captions, widths)
				even = false
			if heading:
				_lines(cells[0], left + 6.0, y, Face.BOLD, DatasheetLayout.SMALL, Ink.TEAL)
				even = false
			else:
				if even:
					page.add_box(Rect2(left, y, right - left, h), Ink.TINT)
				var x: float = left
				for c: int in cells.size():
					var mono: bool = c == 0
					_lines(cells[c], x + 6.0, y, Face.MONO if mono else Face.REGULAR, DatasheetLayout.BODY if mono else DatasheetLayout.SMALL, Ink.TEAL if mono else Ink.INK)
					x += widths[c] if c < widths.size() else 0.0
				even = not even
			y += h
			page.add_line(Vector2(left, y), Vector2(right, y))
			if terminals:
				page.terminal_rows += 1
		y += 16.0

	func _table_head(title: String, captions: Array, widths: Array) -> float:
		var at: float = _heading(title, left, right - left, y) + 2.0
		var x: float = left
		for c: int in captions.size():
			page.add_text(Vector2(x + 6.0, at + 7.0), str(captions[c]).to_upper(), 7, Face.BOLD, Ink.MUTED)
			x += widths[c] if c < widths.size() else 0.0
		at += 11.0
		page.add_line(Vector2(left, at), Vector2(right, at), 0.8, Ink.INK)
		return at

	func _lines(lines: PackedStringArray, x: float, top: float, face: Face, size: int, color: Ink) -> void:
		var at: float = top + 4.0 + DatasheetLayout.SMALL
		for line: String in lines:
			page.add_text(Vector2(x, at), line, size, face, color)
			at += DatasheetLayout.SMALL * DatasheetLayout.LINE

	## Technical data, with the diagram beside it when the part has one.
	func _data_and_diagram() -> void:
		var diagram: bool = sheet.diagram != Datasheet.Diagram.NONE
		var width: float = (right - left - DatasheetLayout.GAP) * 0.5 if diagram else right - left
		var key_w: float = width * (0.45 if diagram else 0.36)
		# Height first, to keep the block on one page.
		var rows: Array = []
		var height: float = DatasheetLayout.HEADING + 12.0
		for row: PackedStringArray in sheet.data:
			var key: PackedStringArray = DatasheetLayout.wrap(row[0], Face.REGULAR, DatasheetLayout.SMALL, key_w - 10.0)
			var value: PackedStringArray = DatasheetLayout.wrap(row[1], Face.REGULAR, DatasheetLayout.SMALL, width - key_w - 10.0)
			var h: float = maxi(key.size(), value.size()) * DatasheetLayout.SMALL * DatasheetLayout.LINE + 7.0
			rows.append([key, value, h])
			height += h
		var diagram_h: float = DatasheetLayout.diagram_height(sheet)
		if diagram:
			height = maxf(height, DatasheetLayout.HEADING + 12.0 + diagram_h)
		if y + height > DatasheetLayout.BOTTOM:
			_new_page(false)
		var at: float = _heading(tr("Technical data"), left, width, y)
		var even: bool = false
		for row: Array in rows:
			var h: float = row[2]
			if even:
				page.add_box(Rect2(left, at, width, h), Ink.TINT)
			_lines(row[0], left + 6.0, at - 1.0, Face.REGULAR, DatasheetLayout.SMALL, Ink.MUTED)
			_lines(row[1], left + key_w, at - 1.0, Face.REGULAR, DatasheetLayout.SMALL, Ink.INK)
			at += h
			page.add_line(Vector2(left, at), Vector2(left + width, at))
			even = not even
		if diagram:
			var x: float = left + width + DatasheetLayout.GAP
			var top: float = _heading(sheet.diagram_title, x, width, y)
			page.items.append({"type": "diagram", "rect": Rect2(x, top, width, diagram_h)})
			at = maxf(at, top + diagram_h)
		y = at + 16.0

	func _front() -> void:
		y = _heading(tr("Device front and terminals"), left, right - left, y)
		var caption: String = tr("The device as drawn in the switchboard view, with the marking of every terminal. Wires go into the terminals from the duct above or below the rail.")
		var caption_h: float = DatasheetLayout.wrap(caption, Face.REGULAR, 7, right - left).size() * 7.0 * DatasheetLayout.LINE + 8.0
		var area: Rect2 = Rect2(left, y + 6.0, right - left, DatasheetLayout.BOTTOM - caption_h - y - 12.0)
		page.items.append({"type": "front", "rect": area})
		_paragraph(caption, left, right - left, area.end.y + 4.0, 7, Ink.MUTED)

	## The band at the top and the footer of [param p].
	func _band_and_footer(p: DatasheetLayout) -> void:
		var band: Rect2 = Rect2(0.0, 0.0, DatasheetLayout.PAGE.x, DatasheetLayout.BAND_H)
		p.items.push_front({"type": "box", "rect": band, "fill": Ink.INK})
		var base: float = DatasheetLayout.BAND_H * 0.5 + 3.0
		p.add_text(Vector2(left, base), "LADDERLAB · %s · %s" % [tr("Part datasheet").to_upper(), sheet.group.to_upper()], 7, Face.BOLD, Ink.PAPER)
		p.add_text_right(right, base, "%s · %s" % [sheet.letters, tr("sheet %d / %d") % [p.page_number, p.page_count]], 7, Face.MONO, Ink.PAPER)
		var rule: float = DatasheetLayout.PAGE.y - 32.0
		p.add_line(Vector2(left, rule), Vector2(right, rule))
		p.add_text(Vector2(left, rule + 11.0), tr("Values are those of the LadderLab simulation, not of a real product."), 6, Face.REGULAR, Ink.MUTED)
		p.add_text_right(right, rule + 11.0, "LadderLab %s · %s · %d / %d" % [ReleaseCheck.current_version(), sheet.letters, p.page_number, p.page_count], 6, Face.MONO, Ink.MUTED)


## Height of the function diagram of [param sheet].
static func diagram_height(sheet: Datasheet) -> float:
	if sheet.diagram == Datasheet.Diagram.TIMER:
		var rows: int = 3 if TimerRelay.uses_control(sheet.timer_mode) else 2
		return rows * TIMER_ROW + TimerDiagram.DIMENSION_HEIGHT + 16.0
	return CURVE_H


## Extent of the part's symbol drawn upright at scale 1, labels included
## (roughly: the designation and rating left of it, terminal names around it).
static func symbol_extent(c: CircuitComponent) -> Rect2:
	var g: float = float(SymbolGeometry.GRID)
	var local: Rect2 = SymbolGeometry.local_body(c)
	for cell: Vector2i in SymbolGeometry.local_terminals(c).values():
		local = local.expand(Vector2(cell))
	return Rect2(local.position * g, local.size * g).grow_individual(g * 3.6, g * 0.6, g * 1.0, g * 0.6)
