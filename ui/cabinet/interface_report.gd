class_name InterfaceReport
extends ReportRows
## The interface characteristics of a switchboard (charakteristiky rozhraní,
## ČSN EN 61439-1 ed. 3) as rows for the export ([ReportSheet]): what kind
## of assembly it is and after which standards, who made it ([Manufacturer])
## and for whom, and its 26 characteristics ([BoardDocumentation]), each as
## given; what is not given yet is listed at the end. No nodes.


## What switchboard [param board] is by its assembly type, after which
## standards ("" while the type is not given), for the documents' subtitle.
static func kind_text(board: Switchboard) -> String:
	match BoardDocumentation.clean(board.documentation).get("assembly", ""):
		"DBO":
			return TranslationServer.translate("Distribution board (DBO) intended to be operated by ordinary persons, after ČSN EN 61439-1 ed. 3 and ČSN EN 61439-3")
		"PSC":
			return TranslationServer.translate("Power switchgear and controlgear assembly (PSC), after ČSN EN 61439-1 ed. 3 and ČSN EN 61439-2")
	return ""


## The switchboard maker as the documents name it ([Manufacturer]): the
## name and company ID, the authorisation, the trade name and address, a
## line each; "" while none of it is given.
static func maker_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	var first: PackedStringArray = PackedStringArray()
	for key: String in ["name", "id_number"]:
		if not Manufacturer.value(key).is_empty():
			first.append(Manufacturer.value(key))
	if not first.is_empty():
		lines.append(", ".join(first))
	if not Manufacturer.value("authorisation").is_empty():
		lines.append(TranslationServer.translate("Authorisation: %s") % Manufacturer.value("authorisation"))
	var last: PackedStringArray = PackedStringArray()
	for key: String in ["company", "address"]:
		if not Manufacturer.value(key).is_empty():
			last.append(Manufacturer.value(key))
	if not last.is_empty():
		lines.append(", ".join(last))
	return "\n".join(lines)


## The rows of switchboard [param b] of [param doc]; [param source] says
## what it was exported from (see [method source_text]).
func rows(doc: SchematicDocument, b: int, source: String = "") -> Array[Dictionary]:
	_rows = []
	_table = 0
	var board: Switchboard = doc.switchboards[b]
	_add({"type": "title", "text": tr("Interface characteristics of switchboard +%s") % board.name + ("  ·  " + board.title if not board.title.is_empty() else "")})
	if not kind_text(board).is_empty():
		_text(kind_text(board), false)
	_text(tr("The characteristics of the assembly for ensuring compatibility with the ratings of the circuits it is connected to and with the conditions of the electrical installation. This document is part of the accompanying technical documentation of every assembly (ČSN EN 61439-1 ed. 3%s).") % (", " + BoardDocumentation.standard(board) if not BoardDocumentation.standard(board).is_empty() else ""), false)
	_text(tr("The documentation is valid only with the devices fitted exactly as the switchboard maker's documentation gives them."), false)
	if not source.is_empty():
		_text(source, true)
	_gap()
	var widths: Array[float] = [0.34, 0.66]
	var align: Array = ["l", "l"]
	var maker: String = maker_text()
	_table_head([tr("Switchboard manufacturer"), maker if not maker.is_empty() else tr("not given")], widths, align, true)
	for key: String in ["original_maker", "board_type", "serial_number", "order_number", "customer"]:
		var value: String = BoardDocumentation.shown(board, key)
		_table_row([tr(BoardDocumentation.field(key)["title"]), value if not value.is_empty() else tr("not given")], widths, align, false, true)
	_gap()
	widths = [0.07, 0.58, 0.35]
	align = ["r", "l", "l"]
	_table_head([tr("No."), tr("Characteristic"), tr("Value")], widths, align, true)
	for i: int in BoardDocumentation.CHARACTERISTICS.size():
		var f: Dictionary = BoardDocumentation.CHARACTERISTICS[i]
		var value: String = BoardDocumentation.shown(board, f["key"])
		_table_row([str(i + 1), tr(f["title"]), value if not value.is_empty() else tr("not given")], widths, align, false, true)
	var notes: Array[String] = BoardDocumentation.conflicts(board.documentation)
	if not notes.is_empty():
		_heading(tr("Notes"))
		for note: String in notes:
			_text("• " + tr(note), false)
	var gaps: PackedStringArray = PackedStringArray()
	for title: String in Manufacturer.missing():
		gaps.append(tr("%s (Settings > Switchboard manufacturer…)") % tr(title))
	for title: String in BoardDocumentation.missing(board):
		var key_title: String = tr(title)
		gaps.append(tr("%s (Temperature rise…)") % key_title if title in [BoardDocumentation.field("rdf")["title"], BoardDocumentation.field("dimensions")["title"]] else tr("%s (Documentation…)") % key_title)
	if not gaps.is_empty():
		_heading(tr("Still to give"))
		for gap: String in gaps:
			_text("• " + gap, false)
	return _rows
