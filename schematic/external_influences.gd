class_name ExternalInfluences
extends RefCounted
## The external influences of ČSN 33 2000-5-51 (Annex A, a short list): each
## category ("AA" ambient temperature, "AD" water ...) with its classes
## ("AD4" splashing water). A room's environment is a list of them joined by
## ", " ("AB8, AD4"), besides the names in [constant FloorPlan.ENVIRONMENTS].
## Titles and texts are English source text, a class's text translated with
## its category's code as context ([method text]); ranges are not translated.
## No nodes.

## The groups (A environment, B utilisation, C construction of buildings),
## each {"code", "title", "categories"}; a category {"code", "title",
## "classes"}, a class [code, text] (no text where the class is the category
## itself, AM-4). A category without classes (AJ, AM heading AM-1 … AM-41, BB)
## is listed for completeness.
const GROUPS: Array[Dictionary] = [
	{"code": "A", "title": "Environment", "categories": [
		{"code": "AA", "title": "Ambient temperature", "classes": [
			["AA1", "−60 °C … +5 °C"], ["AA2", "−40 °C … +5 °C"], ["AA3", "−25 °C … +5 °C"],
			["AA4", "−5 °C … +40 °C"], ["AA5", "+5 °C … +40 °C"], ["AA6", "+5 °C … +60 °C"],
			["AA7", "−25 °C … +55 °C"], ["AA8", "−50 °C … +40 °C"]]},
		{"code": "AB", "title": "Temperature and relative humidity", "classes": [
			["AB1", "−60 °C … +5 °C, 3 % … 100 %"], ["AB2", "−40 °C … +5 °C, 10 % … 100 %"],
			["AB3", "−25 °C … +5 °C, 10 % … 100 %"], ["AB4", "−5 °C … +40 °C, 5 % … 95 %"],
			["AB5", "+5 °C … +40 °C, 5 % … 85 %"], ["AB6", "+5 °C … +60 °C, 10 % … 100 %"],
			["AB7", "−25 °C … +55 °C, 10 % … 100 %"], ["AB8", "−50 °C … +40 °C, 10 % … 100 %"]]},
		{"code": "AC", "title": "Altitude", "classes": [["AC1", "≤ 2 000 m"], ["AC2", "> 2 000 m"]]},
		{"code": "AD", "title": "Presence of water", "classes": [
			["AD1", "negligible"], ["AD2", "free-falling drops"], ["AD3", "sprays"],
			["AD4", "splashes"], ["AD5", "jets"], ["AD6", "waves"],
			["AD7", "immersion"], ["AD8", "submersion"]]},
		{"code": "AE", "title": "Presence of foreign solid bodies", "classes": [
			["AE1", "negligible"], ["AE2", "small objects"], ["AE3", "very small objects"],
			["AE4", "light dust"], ["AE5", "moderate dust"], ["AE6", "heavy dust"]]},
		{"code": "AF", "title": "Presence of corrosive or polluting substances", "classes": [
			["AF1", "negligible"], ["AF2", "atmospheric"], ["AF3", "intermittent"], ["AF4", "continuous"]]},
		{"code": "AG", "title": "Impact", "classes": [
			["AG1", "low severity"], ["AG2", "medium severity"], ["AG3", "high severity"]]},
		{"code": "AH", "title": "Vibration", "classes": [
			["AH1", "low severity"], ["AH2", "medium severity"], ["AH3", "high severity"]]},
		{"code": "AJ", "title": "Other mechanical stresses", "classes": []},
		{"code": "AK", "title": "Presence of flora or mould growth", "classes": [
			["AK1", "no hazard"], ["AK2", "hazard"]]},
		{"code": "AL", "title": "Presence of fauna", "classes": [["AL1", "no hazard"], ["AL2", "hazard"]]},
		{"code": "AM", "title": "Electromagnetic, electrostatic or ionising influences", "classes": []},
		{"code": "AM-1", "title": "Harmonics, interharmonics", "classes": [
			["AM-1-1", "controlled level"], ["AM-1-2", "normal level"], ["AM-1-3", "high level"]]},
		{"code": "AM-2", "title": "Signalling voltages", "classes": [
			["AM-2-1", "controlled level"], ["AM-2-2", "normal level"], ["AM-2-3", "high level"]]},
		{"code": "AM-3", "title": "Voltage amplitude variations", "classes": [
			["AM-3-1", "controlled level"], ["AM-3-2", "normal level"]]},
		{"code": "AM-4", "title": "Voltage unbalance", "classes": [["AM-4", ""]]},
		{"code": "AM-5", "title": "Power frequency variations", "classes": [["AM-5", ""]]},
		{"code": "AM-6", "title": "Induced low-frequency voltages", "classes": [["AM-6", ""]]},
		{"code": "AM-7", "title": "Direct current in a.c. networks", "classes": [["AM-7", ""]]},
		{"code": "AM-8", "title": "Radiated magnetic fields", "classes": [
			["AM-8-1", "medium level"], ["AM-8-2", "high level"]]},
		{"code": "AM-9", "title": "Electric fields", "classes": [
			["AM-9-1", "negligible level"], ["AM-9-2", "medium level"], ["AM-9-3", "high level"],
			["AM-9-4", "very high level"]]},
		{"code": "AM-21", "title": "Induced oscillatory voltages or currents", "classes": [["AM-21", ""]]},
		{"code": "AM-22", "title": "Conducted unidirectional transients of the nanosecond time scale", "classes": [
			["AM-22-1", "negligible level"], ["AM-22-2", "medium level"], ["AM-22-3", "high level"],
			["AM-22-4", "very high level"]]},
		{"code": "AM-23", "title": "Conducted unidirectional transients of the microsecond to millisecond time scale", "classes": [
			["AM-23-1", "controlled level"], ["AM-23-2", "medium level"], ["AM-23-3", "high level"]]},
		{"code": "AM-24", "title": "Conducted oscillatory transients", "classes": [
			["AM-24-1", "medium level"], ["AM-24-2", "high level"]]},
		{"code": "AM-25", "title": "Radiated high-frequency phenomena", "classes": [
			["AM-25-1", "negligible level"], ["AM-25-2", "medium level"], ["AM-25-3", "high level"]]},
		{"code": "AM-31", "title": "Electrostatic discharges", "classes": [
			["AM-31-1", "low level"], ["AM-31-2", "medium level"], ["AM-31-3", "high level"],
			["AM-31-4", "very high level"]]},
		{"code": "AM-41", "title": "Ionisation", "classes": [["AM-41-1", ""]]},
		{"code": "AN", "title": "Solar radiation", "classes": [
			["AN1", "low"], ["AN2", "medium"], ["AN3", "high"]]},
		{"code": "AP", "title": "Seismic effects", "classes": [
			["AP1", "negligible"], ["AP2", "low severity"], ["AP3", "medium severity"], ["AP4", "high severity"]]},
		{"code": "AQ", "title": "Lightning", "classes": [
			["AQ1", "negligible"], ["AQ2", "indirect exposure"], ["AQ3", "direct exposure"]]},
		{"code": "AR", "title": "Movement of air", "classes": [["AR1", "low"], ["AR2", "medium"], ["AR3", "high"]]},
		{"code": "AS", "title": "Wind", "classes": [["AS1", "low"], ["AS2", "medium"], ["AS3", "high"]]},
	]},
	{"code": "B", "title": "Utilisation", "categories": [
		{"code": "BA", "title": "Capability of persons", "classes": [
			["BA1", "ordinary"], ["BA2", "children"], ["BA3", "handicapped"], ["BA4", "instructed"],
			["BA5", "skilled"]]},
		{"code": "BB", "title": "Electrical resistance of the human body", "classes": []},
		{"code": "BC", "title": "Contact of persons with earth potential", "classes": [
			["BC1", "none"], ["BC2", "exceptional"], ["BC3", "frequent"], ["BC4", "continuous"]]},
		{"code": "BD", "title": "Conditions of evacuation in an emergency", "classes": [
			["BD1", "low density of persons, easy exit"], ["BD2", "low density of persons, difficult exit"],
			["BD3", "high density of persons, easy exit"], ["BD4", "high density of persons, difficult exit"]]},
		{"code": "BE", "title": "Nature of processed or stored materials", "classes": [
			["BE1", "no significant risks"], ["BE2", "fire risks"], ["BE3", "explosion risks"],
			["BE4", "contamination risks"]]},
	]},
	{"code": "C", "title": "Construction of buildings", "categories": [
		{"code": "CA", "title": "Construction materials", "classes": [["CA1", "non-combustible"], ["CA2", "combustible"]]},
		{"code": "CB", "title": "Building design", "classes": [
			["CB1", "negligible risks"], ["CB2", "propagation of fire"], ["CB3", "movement"],
			["CB4", "flexible or unstable"]]},
	]},
]

## Class code -> {"category": its category's code, "title": the category's
## title, "text": the class's text}, built on first use.
static var _classes: Dictionary = {}


static func _index() -> Dictionary:
	if _classes.is_empty():
		for group: Dictionary in GROUPS:
			for category: Dictionary in group["categories"]:
				for entry: Array in category["classes"]:
					_classes[entry[0]] = {"category": category["code"], "title": category["title"], "text": entry[1]}
	return _classes


## Whether [param code] is a class of the list ("AD4").
static func has_class(code: String) -> bool:
	return _index().has(code)


## The category of class [param code] ("AD" for "AD4"), "" for none.
static func category_of(code: String) -> String:
	return _index().get(code, {}).get("category", "")


## The items of [param environment] ("AB8, AD4" -> ["AB8", "AD4"]).
static func items(environment: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in environment.split(",", false):
		if not item.strip_edges().is_empty():
			result.append(item.strip_edges())
	return result


## The classes of the list among the items of [param environment].
static func classes_of(environment: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in items(environment):
		if has_class(item):
			result.append(item)
	return result


## [param codes] put in the order of the list, one class per category (the
## last given wins), and joined by ", ".
static func join(codes: PackedStringArray) -> String:
	var by_category: Dictionary = {}
	for code: String in codes:
		if has_class(code):
			by_category[category_of(code)] = code
	var result: PackedStringArray = PackedStringArray()
	for group: Dictionary in GROUPS:
		for category: Dictionary in group["categories"]:
			if by_category.has(category["code"]):
				result.append(by_category[category["code"]])
	return ", ".join(result)


## What class [param code] means, translated: "Presence of water: splashes".
static func describe(code: String) -> String:
	var entry: Dictionary = _index().get(code, {})
	if entry.is_empty():
		return code
	if entry["text"].is_empty():
		return TranslationServer.translate(entry["title"])
	return "%s: %s" % [TranslationServer.translate(entry["title"]), text(entry["category"], entry["text"])]


## Class text [param value] of category [param category], translated (by
## the category as context: "negligible" water and corrosion differ in Czech).
static func text(category: String, value: String) -> String:
	return TranslationServer.translate(value, category)


## What the classes in [param environment] mean, translated, one after
## another ("AB8 Temperature and relative humidity: … ; AD4 …"), "" for none.
static func note(environment: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for code: String in classes_of(environment):
		parts.append("%s %s" % [code, describe(code)])
	return "; ".join(parts)
