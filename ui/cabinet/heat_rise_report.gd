class_name HeatRiseReport
extends ReportRows
## The protocol of a switchboard's temperature rise calculation
## ([HeatRise]) as rows for the export ([ReportSheet]): the method, a summary
## (the enclosure, its type and material from the documentation
## ([BoardDocumentation]), the losses against the power loss the enclosure
## takes, the date, who worked it out, the evaluation), the parameters (the
## devices grouped by name, maker's type, data and loss with how many, the
## strip terminals, the wires, the totals and the balance), the data given,
## the losses (the wires by their current with their length, cross-section,
## resistance and loss),
## the effective cooling surface surface by surface, each step of the
## calculation with its figures put in, the temperatures over the height and
## at each rail, the verdict, the curve and what the method could not cover.
## Also the one layout the calculation is made on everywhere ([method layout]).
## No nodes.

## Pixels per mm the switchboard is laid out at for its calculation, so the
## panel, the dialog and the export reckon the same wire lengths.
const LAYOUT_K: float = 1.0

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
	var r: Dictionary = e["result"]
	var size: Variant = e["size"]
	var rdf: Variant = losses["rdf"]
	var balance: Variant = HeatRise.balance(s, losses)
	var with_rdf: Variant = rdf * rdf * losses["rated"] if rdf != null and losses["rated"] != null else null
	var docs: Dictionary = BoardDocumentation.clean(board.documentation)
	# The summary.
	_heading(tr("Summary"))
	var widths: Array[float] = [0.6, 0.4]
	var align: Array = ["l", "l"]
	_table_head([tr("Item"), tr("Value")], widths, align)
	var standards: String = "ČSN EN 61439-1"
	if not BoardDocumentation.standard(board).is_empty():
		standards += ", " + BoardDocumentation.standard(board)
	_table_row([tr("Standards"), standards + ", IEC 890 (ČSN 33 7107)"], widths, align)
	_table_row([tr("Switchboard type"), docs.get("board_type", tr("not given"))], widths, align)
	_table_row([tr("Material of the enclosure"), tr(docs["material"]) if docs.has("material") else tr("not given")], widths, align)
	_table_row([tr("Location"), tr(docs["location"]) if docs.has("location") else tr("not given")], widths, align)
	_table_row([tr("How it is installed"), tr(HeatRise.MOUNTINGS[s["mounting"]]["title"]) if s.has("mounting") else tr("not given")], widths, align)
	_table_row([tr("Dimensions (w × h × d)"), "%s × %s × %s mm" % [_n(size.y, 0), _n(size.x, 0), _n(size.z, 0)] if size != null else tr("not given")], widths, align)
	_table_row([tr("Effective cooling surface Ae"), "%s m²" % _n(r["section"]["ae"], 2) if not r.is_empty() and r["sections"] == 1 else (tr("%d sections, %s m² each") % [r["sections"], _n(r["section"]["ae"], 2)] if not r.is_empty() else tr("not worked out"))], widths, align)
	_table_row([tr("Power loss the enclosure takes (from its maker)"), _given(s.get("enclosure_loss"), "W")], widths, align)
	_table_row([tr("Power lost by the components at the rated currents"), _given(losses["rated"], "W")], widths, align)
	_table_row([tr("Rated diversity factor RDF"), _given(rdf, "")], widths, align)
	_table_row([tr("Power lost with the diversity factor (RDF² · P + further losses)"), _given(losses["total"], "W")], widths, align)
	_table_row([tr("Remaining available power loss"), _given(balance, "W")], widths, align, true)
	_table_row([tr("Temperature of the air at the top (at most)"), "%s °C (%s °C)" % [_n(r["temperature"], 1), _n(s["limit"], 0)] if not r.is_empty() else tr("not worked out")], widths, align, true)
	_gap()
	var date: String = doc.title_block.date if not doc.title_block.date.is_empty() else Time.get_date_string_from_system()
	var by: String = doc.title_block.drawn_by if not doc.title_block.drawn_by.is_empty() else "…………………………"
	_text(tr("Date: %s  ·  Worked out by: %s") % [date, by], false)
	_text(tr("Evaluation: %s") % _evaluation(e, balance), false)
	_text(tr("Warning: the documentation is valid only with the devices fitted exactly as the switchboard maker's documentation gives them – the table of parameters."), false)
	# The parameters: the devices grouped, the terminals, the wires, the balance.
	_heading(tr("Parameters"))
	widths = [0.19, 0.16, 0.2, 0.14, 0.1, 0.07, 0.14]
	align = ["l", "l", "l", "l", "r", "r", "r"]
	_table_head([tr("Name"), tr("Type"), tr("Data"), tr("Designation"), tr("Loss (W)"), tr("Pcs"), tr("Total (W)")], widths, align)
	var named: String = ""
	for group: Dictionary in device_groups(doc, losses):
		var power: Variant = group["power"]
		_table_row([group["name"] if group["name"] != named else "", group["type"] if not group["type"].is_empty() else tr("not given"), group["data"],
			PartsList.designations(group["designations"]), _given(power, ""), str(group["designations"].size()),
			_given(power * group["designations"].size() if power != null else null, "")], widths, align)
		named = group["name"]
	if losses["terminal_count"] > 0:
		_table_row([tr("Strip terminals"), "", "", "", "", str(losses["terminal_count"]), _given(losses["terminals"], "")], widths, align)
	for group: Dictionary in losses["groups"]:
		_table_row([tr("Wires"), "%s mm²" % _given(group["section"], "") if group["section"] != null else tr("not given"), "I = %s A, L = %s m" % [_n(group["amperes"], 2), _n(group["length"], 2)],
			"", "", str(group["count"]), _n(group["power"], 2) if group["power"] != null else tr("not given")], widths, align)
	var across: Array[float] = [0.86, 0.14]
	var right: Array = ["l", "r"]
	_table_row([tr("Total for the components at the rated currents"), _given(losses["rated"], "")], across, right, true)
	_table_row([tr("Rated diversity factor RDF (the losses RDF² times)"), _given(rdf, "")], across, right)
	_table_row([tr("Power lost by the components with the diversity factor: RDF² · P"), _given(with_rdf, "")], across, right)
	_table_row([tr("Further losses (lighting, fans, heaters …)"), _given(losses["extra"], "")], across, right)
	_table_row([tr("Total P"), _given(losses["total"], "")], across, right, true)
	var enclosure: String = tr("Enclosure %s: the power loss it takes") % docs["board_type"] if docs.has("board_type") else tr("Enclosure: the power loss it takes")
	_table_row([enclosure, _given(-float(s["enclosure_loss"]) if s.has("enclosure_loss") else null, "")], across, right)
	_table_row([tr("Overall balance (below 0: the enclosure takes more)"), _given(-balance if balance != null else null, "")], across, right, true)
	# The data given.
	_heading(tr("1. Data given"))
	widths = [0.5, 0.5]
	_table_head([tr("Item"), tr("Value")], widths, ["l", "l"])
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
	_table_row([tr("Rated diversity factor RDF"), _given(rdf, "")], widths, ["l", "l"])
	_table_row([tr("Power loss the enclosure takes (from its maker)"), _given(s.get("enclosure_loss"), "W")], widths, ["l", "l"])
	# The losses.
	_heading(tr("2. Power lost at the rated currents P"))
	_text(tr("Each device's loss at its rated current from its maker, as in the parameters."), true)
	if not losses["groups"].is_empty():
		_gap()
		_text(tr("Wires laid out, by the rated current I of the breaker, fuse or overload relay on their net: P = I² · R20 · (1 + α (Tc − 20 °C)) · L, α = %s 1/K, Tc = %s °C (annex H of ČSN EN 61439-1).") % [_n(HeatRise.ALPHA, 3), _n(HeatRise.CONDUCTOR_TEMPERATURE, 0)], true)
		widths = [0.13, 0.12, 0.15, 0.15, 0.2, 0.25]
		align = ["r", "r", "r", "r", "r", "r"]
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
		for gap: String in gap_texts(doc, gaps, losses):
			_text("• " + gap, false)
		_protocol_gaps(doc, board, s, losses, false)
		return _rows
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
	_protocol_gaps(doc, board, s, losses, true)
	return _rows


## The devices of [param losses] (see [method HeatRise.losses]) of
## [param doc] grouped as the parameters list them: by name, the maker's
## type, data and loss, in the order the names first come: [{"name", "type",
## "data", "power" (W each, null while not given), "designations"}].
static func device_groups(doc: SchematicDocument, losses: Dictionary) -> Array[Dictionary]:
	var parts: PartsList = PartsList.new()
	var groups: Array[Dictionary] = []
	var names: Array[String] = []
	for device: Dictionary in losses["devices"]:
		var designation: String = device["designation"]
		var name: String = parts.name_of(doc, designation)
		# An RCD or AFDD is no plain circuit breaker.
		var c: CircuitComponent = CabinetDevices.device(doc.circuit, designation)
		if c is ArcFaultDevice:
			name = TranslationServer.translate("Arc fault detection device with circuit breaker")
		elif c is ResidualCurrentDevice:
			name = TranslationServer.translate("Residual current device with overcurrent release (RCBO)" if (c as ResidualCurrentDevice).overcurrent else "Residual current device (RCD)")
		var data: String = device_text(doc, designation)
		for prefix: String in [name + ", ", name + " "]:
			if data.begins_with(prefix):
				data = data.substr(prefix.length())
		if data == name:
			data = ""
		if not names.has(name):
			names.append(name)
		var found: Dictionary = {}
		for group: Dictionary in groups:
			if group["name"] == name and group["type"] == device["type"] and group["data"] == data and group["power"] == device["power"]:
				found = group
		if found.is_empty():
			found = {"name": name, "type": device["type"], "data": data, "power": device["power"], "designations": PackedStringArray()}
			groups.append(found)
		var designations: PackedStringArray = found["designations"]
		designations.append("-" + designation)
		found["designations"] = designations
	var result: Array[Dictionary] = []
	for name: String in names:
		for group: Dictionary in groups:
			if group["name"] == name:
				result.append(group)
	return result


## What [param missing] (see [method HeatRise.missing]) asks for,
## translated, the losses of devices alike (see [method device_groups]) of
## [param losses] asked for once: "The loss of -FA1…-FA4".
static func gap_texts(doc: SchematicDocument, missing: Array, losses: Dictionary) -> PackedStringArray:
	var groups: Array[Dictionary] = device_groups(doc, losses)
	var asked: Dictionary[int, bool] = {}
	var lines: PackedStringArray = PackedStringArray()
	for gap: Dictionary in missing:
		var text: String = gap["text"]
		var args: Array = gap["args"]
		if text == "The loss of -%s":
			for i: int in groups.size():
				if (groups[i]["designations"] as PackedStringArray).has("-" + str(args[0])):
					if not asked.has(i):
						asked[i] = true
						lines.append(TranslationServer.translate(text) % PartsList.designations(groups[i]["designations"]).trim_prefix("-"))
					break
			continue
		lines.append(TranslationServer.translate(text) % args if not args.is_empty() else TranslationServer.translate(text))
	return lines


## The evaluation of [param e] (see [method HeatRise.evaluate]) with the
## remaining power loss [param balance]: complies or not, the temperature
## and the balance.
func _evaluation(e: Dictionary, balance: Variant) -> String:
	if not e["missing"].is_empty():
		return tr("not made, values are still to give (see the end).")
	var r: Dictionary = e["result"]
	var s: Dictionary = e["settings"]
	var total: String = _n(e["losses"]["total"], 1)
	var parts: PackedStringArray = PackedStringArray()
	if r["ok"]:
		parts.append(tr("the air at the top reaches %s °C, within the %s °C allowed") % [_n(r["temperature"], 1), _n(s["limit"], 0)])
	else:
		parts.append(tr("the air at the top reaches %s °C, warmer than the %s °C allowed") % [_n(r["temperature"], 1), _n(s["limit"], 0)])
	if balance == null:
		parts.append(tr("the power loss the enclosure takes is not given"))
	elif balance >= 0.0:
		parts.append(tr("the %s W lost are within the %s W the enclosure takes (%s W left)") % [total, _n(s["enclosure_loss"], 1), _n(balance, 1)])
	else:
		parts.append(tr("the %s W lost are %s W more than the %s W the enclosure takes") % [total, _n(-balance, 1), _n(s["enclosure_loss"], 1)])
	var complies: bool = r["ok"] and balance != null and balance >= 0.0
	var verdict: String = tr("Complies") if complies else (tr("Does not comply") if not r["ok"] or (balance != null and balance < 0.0) else tr("Not decided"))
	return "%s: %s." % [verdict, "; ".join(parts)]


## What the protocol of [param board] still lacks beyond the calculation
## (the enclosure's power loss, the devices' types, the switchboard's type,
## material and location), under a heading of its own when
## [param heading].
func _protocol_gaps(doc: SchematicDocument, board: Switchboard, s: Dictionary, losses: Dictionary, heading: bool) -> void:
	var gaps: PackedStringArray = PackedStringArray()
	if not s.has("enclosure_loss"):
		gaps.append(tr("The power loss the enclosure takes (from its maker)"))
	for alike: Dictionary in device_groups(doc, losses):
		if (alike["type"] as String).is_empty():
			gaps.append(tr("The maker's type of -%s") % PartsList.designations(alike["designations"]).trim_prefix("-"))
	var docs: Dictionary = BoardDocumentation.clean(board.documentation)
	for key: String in ["board_type", "material", "location"]:
		if not docs.has(key):
			gaps.append(tr("%s (in Documentation…)") % tr(BoardDocumentation.field(key)["title"]))
	if gaps.is_empty():
		return
	if heading:
		_heading(tr("Still to give for the protocol"))
	for gap: String in gaps:
		_text("• " + gap, false)


## Where on the height (0 the floor, 1 the top) the middle of rail
## [param rail] (mm on a plate [param plate]) is, the plate in the middle of
## an enclosure [param size] high.
static func _height_of(rail: Rect2, size: Vector3, plate: Vector2) -> float:
	var from_top: float = (size.x - plate.y) / 2.0 + rail.get_center().y
	return clampf(1.0 - from_top / size.x, 0.0, 1.0)
