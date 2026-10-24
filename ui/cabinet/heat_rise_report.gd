class_name HeatRiseReport
extends RefCounted
## The protocol of a switchboard's temperature rise calculation
## ([HeatRise]) as rows for the export ([HeatRiseSheet]): the method, the
## data given, the losses (each device with what tells it apart, the wires by
## their current with their length, cross-section, resistance and loss),
## the effective cooling surface surface by surface, each step of the
## calculation with its figures put in, the temperatures over the height and
## at each rail, the verdict, the curve and what the method could not cover.
## Also the one layout the calculation is made on everywhere ([method layout]).
## No nodes.

## Pixels per mm the switchboard is laid out at for its calculation, so the
## panel, the dialog and the export reckon the same wire lengths.
const LAYOUT_K: float = 1.0

## A row: {"type": "title" / "heading" / "text" / "table" / "curve" / "gap"}
## with "text" (title, heading, text; "muted" for a note), a table row's
## "cells", "widths" (parts of the width), "align" ("l" or "r" per cell),
## "head" (a table's heading row, repeated on a sheet it goes on to),
## "table" (which table it is in), "bold"; a curve's "result", "ambient",
## "limit", "marks".
var _rows: Array[Dictionary] = []
var _table: int = 0


## Switchboard [param b] of [param doc] laid out for its calculation.
static func layout(doc: SchematicDocument, b: int) -> CabinetLayout:
	return CabinetLayout.build(doc, LAYOUT_K, b)


## What device [param designation] is and what tells it apart (its rated
## current, characteristic, poles, rating …), as the parts list says it.
static func device_text(doc: SchematicDocument, designation: String) -> String:
	var parts: PartsList = PartsList.new()
	var name: String = parts.name_of(doc, designation)
	var data: String = parts.data_of(doc, designation)
	var c: CircuitComponent = CabinetDevices.device(doc.circuit, designation)
	if c is MotorBreaker and (c as MotorBreaker).poles > 1:
		# An RCD's data leaves its poles out.
		var poles: String = TranslationServer.translate("%d poles") % (c as MotorBreaker).poles
		if not data.contains(poles):
			data = poles if data.is_empty() else "%s, %s" % [data, poles]
	if data.is_empty():
		return name
	# A breaker's, an RCD's or a fuse's data names it already ("Circuit breaker
	# C16, 3 poles", "Residual current device (RCD) 40 A 30 mA A").
	if c is ProtectiveDevice or c is MotorBreaker or c is ThreePoleFuse or data.begins_with(name):
		return data
	return "%s, %s" % [name, data]


## What a protocol was exported from: the program and its version, the
## file ([param file_name], "" when not saved), the schematic's
## [param title] and when.
func source_text(file_name: String, title: String) -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	var when: String = Time.get_datetime_string_from_system(false, true)
	return tr("Exported from LadderLab %s: file %s, schematic \"%s\", on %s.") % [version, file_name if not file_name.is_empty() else tr("not saved"), title, when]


## The protocol rows of switchboard [param b] of [param doc]; [param source]
## says what it was exported from (see [method source_text]).
func rows(doc: SchematicDocument, b: int, source: String = "") -> Array[Dictionary]:
	_rows = []
	_table = 0
	var board: Switchboard = doc.switchboards[b]
	var laid: CabinetLayout = layout(doc, b)
	var wires: Array = laid.wiring.wires if laid.wiring != null else []
	var e: Dictionary = HeatRise.evaluate(doc, b, wires)
	var s: Dictionary = e["settings"]
	var losses: Dictionary = e["losses"]
	_add({"type": "title", "text": tr("Temperature rise of switchboard +%s: calculation") % board.name + ("  ·  " + board.title if not board.title.is_empty() else "")})
	if not source.is_empty():
		_text(source, false)
	_text(tr("After IEC 890 (ČSN 33 7107 part 1), the calculation ČSN EN 61439-1 allows for verifying the temperature rise of an assembly: the effective cooling surface Ae = Σ A0 · b, the rise of the air half way up Δt0,5 = k · d · P^x and at the top Δt1,0 = c · Δt0,5, k and c off the method's charts. The losses at the rated currents as given; the wires' losses by annex H of ČSN EN 61439-1."), true)
	# The data given.
	_heading(tr("1. Data given"))
	var head: Array = [tr("Item"), tr("Value")]
	var widths: Array[float] = [0.5, 0.5]
	_table_head(head, widths, ["l", "l"])
	var size: Variant = e["size"]
	for pair: Array in [["height", tr("Height of the enclosure h")], ["width", tr("Width of the enclosure w")], ["depth", tr("Depth of the enclosure")]]:
		_table_row([pair[1], _given(s.get(pair[0]), "mm")], widths, ["l", "l"])
	_table_row([tr("Mounting plate as laid out (w × h)"), "%s × %s mm" % [_n(laid.size.x, 0), _n(laid.size.y, 0)]], widths, ["l", "l"])
	var mounting: String = tr("not given")
	if s.has("mounting"):
		var m: Dictionary = HeatRise.MOUNTINGS[s["mounting"]]
		mounting = tr("%s (fig. 1, curve %d)") % [tr(m["title"]), m["curve"]]
	_table_row([tr("How it is installed"), mounting], widths, ["l", "l"])
	var vented: String = tr("not given")
	if s.has("vented"):
		vented = tr("with openings: inlet %s, outlet %s") % [_given(s.get("inlet"), "cm²"), _given(s.get("outlet"), "cm²")] if s["vented"] else tr("none (closed)")
	_table_row([tr("Ventilation openings"), vented], widths, ["l", "l"])
	_table_row([tr("Horizontal partitions"), str(s["partitions"]) if s.has("partitions") else tr("not given")], widths, ["l", "l"])
	_table_row([tr("Ambient temperature"), _given(s.get("ambient"), "°C")], widths, ["l", "l"])
	_table_row([tr("Most allowed inside"), _given(s.get("limit"), "°C")], widths, ["l", "l"])
	_table_row([tr("Rated diversity factor RDF"), _given(s.get("rdf"), "")], widths, ["l", "l"])
	# The losses.
	_heading(tr("2. Power lost at the rated currents P"))
	widths = [0.12, 0.7, 0.18]
	_table_head([tr("Designation"), tr("Device"), tr("Loss (W)")], widths, ["l", "l", "r"])
	for device: Dictionary in losses["devices"]:
		_table_row(["-" + device["designation"], device_text(doc, device["designation"]), _given(device["power"], "")], widths, ["l", "l", "r"])
	if not losses["groups"].is_empty():
		_gap()
		_text(tr("Wires laid out, by the rated current I of the breaker, fuse or overload relay on their net: P = I² · R20 · (1 + α (Tc − 20 °C)) · L, α = %s 1/K, Tc = %s °C (annex H of ČSN EN 61439-1).") % [_n(HeatRise.ALPHA, 3), _n(HeatRise.CONDUCTOR_TEMPERATURE, 0)], true)
		widths = [0.13, 0.12, 0.15, 0.15, 0.2, 0.25]
		var align: Array = ["r", "r", "r", "r", "r", "r"]
		_table_head(["I (A)", tr("Wires"), "L (m)", "S (mm²)", "R20 (mΩ/m)", "P (W)"], widths, align)
		for group: Dictionary in losses["groups"]:
			var section: Variant = group["section"]
			_table_row([_n(group["amperes"], 2), str(group["count"]), _n(group["length"], 2), _given(section, ""),
				_n(HeatRise.resistance(section), 3) if section != null else "", _n(group["power"], 2) if group["power"] != null else ""], widths, align)
	_gap()
	widths = [0.82, 0.18]
	_table_head([tr("Losses"), tr("W")], widths, ["l", "r"])
	var device_sum: Variant = 0.0
	for device: Dictionary in losses["devices"]:
		device_sum = null if device_sum == null or device["power"] == null else device_sum + device["power"]
	var wire_sum: Variant = 0.0
	for group: Dictionary in losses["groups"]:
		wire_sum = null if wire_sum == null or group["power"] == null else wire_sum + group["power"]
	_table_row([tr("Devices (%d)") % losses["devices"].size(), _given(device_sum, "")], widths, ["l", "r"])
	_table_row([tr("Wires (%d, %s m)") % [losses["wire_count"], _n(losses["wire_length"], 2)], _given(wire_sum, "")], widths, ["l", "r"])
	if losses["terminal_count"] > 0:
		_table_row([tr("Strip terminals (%d), all together") % losses["terminal_count"], _given(losses["terminals"], "")], widths, ["l", "r"])
	_table_row([tr("At the rated currents"), _given(losses["rated"], "")], widths, ["l", "r"], true)
	var rdf: Variant = losses["rdf"]
	_table_row([tr("With the rated diversity factor: RDF² · %s = %s² · %s") % [_given(losses["rated"], ""), _given(rdf, ""), _given(losses["rated"], "")],
		_given(rdf * rdf * losses["rated"] if rdf != null and losses["rated"] != null else null, "")], widths, ["l", "r"])
	_table_row([tr("Further losses (lighting, fans, heaters …)"), _given(losses["extra"], "")], widths, ["l", "r"])
	_table_row([tr("Total P = RDF² · losses at the rated currents + further losses"), _given(losses["total"], "")], widths, ["l", "r"], true)
	# The diversity factor given, and what the standards assume without a maker's.
	_gap()
	_text(tr("Rated diversity factor RDF = %s, one for the whole switchboard (ČSN EN 61439-1): the outgoing circuits loaded together at RDF times their rated currents lose RDF² times what they lose at them; RDF = 1 is without diversity, as IEC 890 reckons. The values the standards assume when the maker gives none:") % _given(rdf, ""), true)
	widths = [0.5, 0.25, 0.25]
	_table_head([tr("What"), tr("ČSN EN 61439-2 (PSC, power)"), tr("ČSN EN 61439-3 (DBO, ordinary persons)")], widths, ["l", "r", "r"])
	for entry: Array in HeatRise.RDF_TABLE:
		_table_row([tr(entry[0]), _n(entry[1], 1), _n(entry[2], 1) if entry[2] != null else "–"], widths, ["l", "r", "r"])
	var gaps: Array = e["missing"]
	if not gaps.is_empty():
		_heading(tr("Not worked out: still to give"))
		for gap: Dictionary in gaps:
			_text("• " + (tr(gap["text"]) % gap["args"] if not (gap["args"] as Array).is_empty() else tr(gap["text"])), false)
		return _rows
	var r: Dictionary = e["result"]
	var section_data: Dictionary = r["section"]
	var h: float = size.x / 1000.0
	var depth: float = size.z / 1000.0
	var ws: float = section_data["width"]
	# The cooling surface.
	_heading(tr("3. Effective cooling surface Ae (table 3)"))
	if r["sections"] > 1:
		_text(tr("Wider than %s m or over %s m² of Ae: reckoned in %d sections %s m wide, each with P/%d and its share of the openings; the dividing walls do not count. The warmest section:") % [_n(HeatRise.MAX_WIDTH, 1), _n(HeatRise.MAX_AE, 1), r["sections"], _n(ws, 3), r["sections"]], true)
	widths = [0.3, 0.25, 0.15, 0.12, 0.18]
	var align2: Array = ["l", "r", "r", "r", "r"]
	_table_head([tr("Surface"), tr("Size (m)"), "A0 (m²)", "b", "A0 · b (m²)"], widths, align2)
	for surface: Array in section_data["surfaces"]:
		var dims: String = "%s × %s" % [_n(ws, 3), _n(depth, 3)] if surface[0] == "Top" else ("%s × %s" % [_n(depth, 3), _n(h, 3)] if String(surface[0]).ends_with("side") else "%s × %s" % [_n(ws, 3), _n(h, 3)])
		_table_row([tr(surface[0]), dims, _n(surface[1], 4), _n(surface[2], 1), _n(float(surface[1]) * float(surface[2]), 4)], widths, align2)
	_table_row(["Ae", "", "", "", _n(section_data["ae"], 4)], widths, align2, true)
	# The calculation.
	_heading(tr("4. Temperature rise"))
	widths = [0.16, 0.6, 0.24]
	var align3: Array = ["l", "l", "r"]
	_table_head([tr("Quantity symbol"), tr("From"), tr("Value")], widths, align3)
	_table_row(["P", tr("total P / %d, the section's share") % r["sections"] if r["sections"] > 1 else tr("total P (part 2)"), "%s W" % _n(section_data["power"], 2)], widths, align3)
	var k_from: String
	if section_data["small"]:
		k_from = tr("fig. 6 (Ae ≤ %s m²): k = %s · Ae^%s") % [_n(HeatRise.SMALL, 2), _n(HeatRise.SMALL_K, 4), _n(HeatRise.SMALL_EXP, 4)]
	elif section_data["vented"]:
		k_from = tr("fig. 4 (with openings): inlet %s cm², Ae = %s m²") % [_n(section_data["inlet"], 1), _n(section_data["ae"], 3)]
	else:
		k_from = tr("fig. 2 (closed): Ae = %s m²") % _n(section_data["ae"], 3)
	_table_row(["k", k_from, _n(section_data["k"], 4)], widths, align3)
	var d_from: String = tr("not used for Ae ≤ 1.25 m²")
	if not section_data["small"]:
		d_from = (tr("table 5 (with openings), %d partitions") if section_data["vented"] else tr("table 4 (closed), %d partitions")) % section_data["partitions"]
	_table_row(["d", d_from, _n(section_data["d"], 2)], widths, align3)
	_table_row(["x", tr("with openings") if section_data["vented"] else tr("closed"), _n(section_data["x"], 3)], widths, align3)
	_table_row(["Δt0,5", "k · d · P^x = %s · %s · %s^%s" % [_n(section_data["k"], 4), _n(section_data["d"], 2), _n(section_data["power"], 2), _n(section_data["x"], 3)], "%s K" % _n(section_data["half"], 2)], widths, align3, true)
	if section_data["factor"] == "g":
		_table_row(["g", "h / w = %s / %s" % [_n(h, 3), _n(ws, 3)], _n(section_data["factor_value"], 3)], widths, align3)
		_table_row(["c", tr("fig. 7: g = %s") % _n(section_data["factor_value"], 3), _n(section_data["c"], 3)], widths, align3)
	else:
		_table_row(["f", "h^1,35 / Ab = %s^1,35 / (%s · %s)" % [_n(h, 3), _n(ws, 3), _n(depth, 3)], _n(section_data["factor_value"], 3)], widths, align3)
		var c_from: String = tr("fig. 5: inlet %s cm², f = %s") % [_n(section_data["inlet"], 1), _n(section_data["factor_value"], 3)] if section_data["vented"] else tr("fig. 3, curve %d: f = %s") % [section_data["curve"], _n(section_data["factor_value"], 3)]
		_table_row(["c", c_from, _n(section_data["c"], 3)], widths, align3)
	_table_row(["Δt1,0", "c · Δt0,5 = %s · %s" % [_n(section_data["c"], 3), _n(section_data["half"], 2)], "%s K" % _n(section_data["top"], 2)], widths, align3, true)
	if section_data["small"]:
		_table_row(["Δt0,75", tr("= Δt1,0 (the top quarter of a small enclosure)"), "%s K" % _n(section_data["top"], 2)], widths, align3)
	# The temperatures.
	_heading(tr("5. Temperature of the air inside"))
	widths = [0.46, 0.27, 0.27]
	var align4: Array = ["l", "r", "r"]
	_table_head([tr("Where"), "Δt (K)", tr("Temperature (°C)")], widths, align4)
	var heights: Array[Array] = [[tr("Half way up (0.5 h)"), 0.5]]
	if section_data["small"]:
		heights.append([tr("Three quarters up (0.75 h)"), 0.75])
	heights.append([tr("At the top (1.0 h)"), 1.0])
	for i: int in laid.rails.size():
		heights.append([tr("Rail %d (at %s h)") % [i + 1, _n(_height_of(laid.rails[i], size, laid.size), 2)], _height_of(laid.rails[i], size, laid.size)])
	for entry: Array in heights:
		var rise: float = HeatRise.rise_at(r, entry[1])
		_table_row([entry[0], _n(rise, 1), _n(s["ambient"] + rise, 1)], widths, align4)
	_gap()
	var top: String = _n(r["temperature"], 1)
	if r["ok"]:
		_text(tr("Result: at the top %s °C, within the %s °C allowed.") % [top, _n(s["limit"], 0)], false)
	else:
		_text(tr("Result: at the top %s °C, warmer than the %s °C allowed.") % [top, _n(s["limit"], 0)], false)
	var marks: Array[Vector2] = []
	for i: int in laid.rails.size():
		marks.append(Vector2(_height_of(laid.rails[i], size, laid.size), i + 1))
	_add({"type": "curve", "result": r, "ambient": s["ambient"], "limit": s["limit"], "marks": marks})
	if not r["warnings"].is_empty():
		_heading(tr("Notes"))
		for w: Dictionary in r["warnings"]:
			_text("• " + (tr(w["text"]) % w["args"] if not (w["args"] as Array).is_empty() else tr(w["text"])), true)
	return _rows


## Where on the height (0 the floor, 1 the top) the middle of rail
## [param rail] (mm on a plate [param plate]) is, the plate in the middle of
## an enclosure [param size] high.
static func _height_of(rail: Rect2, size: Vector3, plate: Vector2) -> float:
	var from_top: float = (size.x - plate.y) / 2.0 + rail.get_center().y
	return clampf(1.0 - from_top / size.x, 0.0, 1.0)


func _add(row: Dictionary) -> void:
	_rows.append(row)


func _heading(text: String) -> void:
	_add({"type": "heading", "text": text})


func _text(text: String, muted: bool) -> void:
	_add({"type": "text", "text": text, "muted": muted})


func _gap() -> void:
	_add({"type": "gap"})


func _table_head(cells: Array, widths: Array[float], align: Array) -> void:
	_table += 1
	_add({"type": "table", "cells": cells, "widths": widths, "align": align, "head": true, "table": _table})


func _table_row(cells: Array, widths: Array[float], align: Array, bold: bool = false) -> void:
	_add({"type": "table", "cells": cells, "widths": widths, "align": align, "head": false, "table": _table, "bold": bold})


## A value given, with its unit; "not given" while it is not.
func _given(value: Variant, unit: String) -> String:
	if value == null:
		return tr("not given")
	var text: String = _n(float(value), 2)
	return text if unit.is_empty() else "%s %s" % [text, unit]


static func _n(value: float, places: int) -> String:
	if absf(value - roundf(value)) < pow(10.0, -places) / 2.0:
		return str(roundi(value))
	return String.num(value, places)
