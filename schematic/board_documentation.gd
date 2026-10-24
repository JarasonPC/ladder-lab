class_name BoardDocumentation
extends RefCounted
## What a switchboard's documentation is given beyond the drawing
## ([member Switchboard.documentation]): who it was made for and by whose
## system (original manufacturer, type, serial number, order, customer, the
## enclosure's material) and its interface characteristics after ČSN EN
## 61439-1 ed. 3 (the 26 of [constant CHARACTERISTICS]: voltages, currents,
## frequency, pollution degree, earthing system, degree of protection …),
## exported as the interface characteristics ([InterfaceReport]) and used by
## the operating instructions ([InstructionsReport]) and the temperature
## rise protocol ([HeatRiseReport]). Nothing is assumed: a value not given
## is missing ([method missing]). The rated diversity factor and the
## enclosure's size are the temperature rise calculation's ([member
## Switchboard.heat]), given there. No nodes.

## A field: "key" (as saved), "title" (English source text), "kind": "text"
## (as typed; "long" for several lines), "number" (over 0, in "unit"),
## "choice" (one of "options", English source text, saved as such) or
## "heat" (the temperature rise calculation's, see [method shown]).
const HEADER: Array[Dictionary] = [
	{"key": "original_maker", "title": "Original manufacturer", "kind": "text"},
	{"key": "board_type", "title": "Switchboard type", "kind": "text"},
	{"key": "material", "title": "Material of the enclosure", "kind": "choice", "options": ["Metal", "Plastic"]},
	{"key": "serial_number", "title": "Serial number of the switchboard", "kind": "text"},
	{"key": "order_number", "title": "Order / project number", "kind": "text"},
	{"key": "customer", "title": "Customer / investor", "kind": "text"},
]
## The interface characteristics, numbered 1 to 26 in this order.
const CHARACTERISTICS: Array[Dictionary] = [
	{"key": "un", "title": "Rated voltage (Un)", "kind": "number", "unit": "V"},
	{"key": "ue", "title": "Rated operational voltage (Ue), (Ue ≥ Un)", "kind": "number", "unit": "V"},
	{"key": "ui", "title": "Rated insulation voltage (Ui)", "kind": "number", "unit": "V"},
	{"key": "uimp", "title": "Rated impulse withstand voltage (Uimp)", "kind": "number", "unit": "kV"},
	{"key": "ina", "title": "Rated current of the assembly (InA)", "kind": "number", "unit": "A"},
	{"key": "inc", "title": "Rated current of the main circuit (Inc) ≤ InA", "kind": "number", "unit": "A"},
	{"key": "ipk", "title": "Rated peak withstand current (Ipk)", "kind": "number", "unit": "kA"},
	{"key": "rdf", "title": "Rated diversity factor (RDF)", "kind": "heat"},
	{"key": "fn", "title": "Rated frequency (fn)", "kind": "number", "unit": "Hz"},
	{"key": "additional", "title": "Additional requirements depending on the specific service conditions of a functional unit (e.g. type of coordination, overload characteristics)", "kind": "text", "long": true},
	{"key": "pollution", "title": "Pollution degree", "kind": "choice", "options": ["1", "2", "3", "4"]},
	{"key": "earthing", "title": "Types of system earthing the assembly is designed for", "kind": "choice", "options": ["TN-C", "TN-S", "TN-C-S", "TT", "IT"]},
	{"key": "location", "title": "Indoor and/or outdoor installation", "kind": "choice", "options": ["Indoor installation", "Outdoor installation", "Indoor and outdoor installation"]},
	{"key": "mobility", "title": "Stationary or movable", "kind": "choice", "options": ["Stationary", "Movable"]},
	{"key": "ip", "title": "Degree of protection", "kind": "text"},
	{"key": "persons", "title": "Intended for use by skilled or ordinary persons", "kind": "choice", "options": ["Ordinary persons", "Skilled persons"]},
	{"key": "emc", "title": "Electromagnetic compatibility (EMC) classification", "kind": "choice", "options": ["Environment A – industrial", "Environment B – residential"]},
	{"key": "special", "title": "Special service conditions, if applicable", "kind": "text"},
	{"key": "external_design", "title": "External design", "kind": "text"},
	{"key": "ik", "title": "Protection against mechanical impact", "kind": "text"},
	{"key": "construction", "title": "Type of construction", "kind": "choice", "options": ["Fixed parts", "Removable parts", "Withdrawable parts"]},
	{"key": "scpd", "title": "Nature of the short-circuit protective device(s)", "kind": "choice", "options": ["Circuit breaker", "Fuses", "Circuit breaker and fuses"]},
	{"key": "protection_class", "title": "Measures for protection against electric shock", "kind": "choice", "options": ["Class I – automatic disconnection of supply", "Class II – double insulation"]},
	{"key": "dimensions", "title": "Overall dimensions, including projections such as handles, covers, doors (H × W × D mm)", "kind": "heat"},
	{"key": "assembly", "title": "Type", "kind": "choice", "options": ["DBO", "PSC"]},
	{"key": "service", "title": "Operating conditions", "kind": "choice", "options": ["Normal service conditions", "Special service conditions"]},
]
## The assembly types of "assembly": the part of ČSN EN 61439 for each.
const STANDARDS: Dictionary = {"DBO": "ČSN EN 61439-3", "PSC": "ČSN EN 61439-2"}


## Every field, the header's first.
static func fields() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append_array(HEADER)
	result.append_array(CHARACTERISTICS)
	return result


## The field of [param key], {} for none.
static func field(key: String) -> Dictionary:
	for f: Dictionary in fields():
		if f["key"] == key:
			return f
	return {}


## [param data] cleaned (a switchboard's [member Switchboard.documentation]):
## only the fields of [constant HEADER] and [constant CHARACTERISTICS] that
## were given and make sense (text not empty, a number over 0, a choice of
## its options); nothing is filled in for what is missing.
static func clean(data: Variant) -> Dictionary:
	var d: Dictionary = data if data is Dictionary else {}
	var result: Dictionary = {}
	for f: Dictionary in fields():
		var value: Variant = d.get(f["key"])
		match f["kind"]:
			"text":
				if value is String and not (value as String).strip_edges().is_empty():
					result[f["key"]] = (value as String).strip_edges()
			"number":
				if (value is float or value is int) and float(value) > 0.0:
					result[f["key"]] = float(value)
			"choice":
				if value is String and (f["options"] as Array).has(value):
					result[f["key"]] = value
	return result


## What field [param key] of [param board] says, translated where it is a
## choice, with its unit where it is a number; "" while not given. The
## rated diversity factor and the dimensions come from the temperature rise
## calculation's settings.
static func shown(board: Switchboard, key: String) -> String:
	var f: Dictionary = field(key)
	if f.is_empty():
		return ""
	match key:
		"rdf":
			var heat: Dictionary = HeatRise.settings(board.heat)
			return HeatRise._num(heat["rdf"]) if heat.has("rdf") else ""
		"dimensions":
			var size: Variant = HeatRise.enclosure(HeatRise.settings(board.heat))
			return "%s × %s × %s" % [HeatRise._num(size.x), HeatRise._num(size.y), HeatRise._num(size.z)] if size != null else ""
	var d: Dictionary = clean(board.documentation)
	if not d.has(key):
		return ""
	match f["kind"]:
		"number":
			return "%s %s" % [HeatRise._num(d[key]), f["unit"]]
		"choice":
			return TranslationServer.translate(d[key])
	return d[key]


## The titles (English) of the fields of [param board] not given yet, the
## header's first, then the characteristics' (the rated diversity factor and
## the dimensions are given in the temperature rise calculation).
static func missing(board: Switchboard) -> Array[String]:
	var result: Array[String] = []
	for f: Dictionary in fields():
		if shown(board, f["key"]).is_empty():
			result.append(f["title"])
	return result


## The part of ČSN EN 61439 the assembly type of [param board] is made to
## ("" while the type is not given).
static func standard(board: Switchboard) -> String:
	return STANDARDS.get(clean(board.documentation).get("assembly", ""), "")


## What does not fit together in [param data] (English): Inc over InA, Ue
## under Un.
static func conflicts(data: Dictionary) -> Array[String]:
	var d: Dictionary = clean(data)
	var result: Array[String] = []
	if d.has("inc") and d.has("ina") and d["inc"] > d["ina"]:
		result.append("The rated current of the main circuit Inc is larger than the rated current of the assembly InA.")
	if d.has("ue") and d.has("un") and d["ue"] < d["un"]:
		result.append("The rated operational voltage Ue is lower than the rated voltage Un.")
	return result
