class_name Manufacturer
extends RefCounted
## Who makes the switchboards (výrobce rozváděče): the user's own name or
## business name, company ID (IČ), authorisation, trade name, address and
## contacts, written into the documentation each switchboard is exported
## with ([BoardDocumentation], [InterfaceReport], [InstructionsReport],
## [HeatRiseReport]). Given once in Settings > Switchboard manufacturer… and
## kept in the user settings (section "manufacturer"), the same for every
## schematic; free text, nothing assumed. No nodes.

## Fields in the order they are edited, keyed as saved, with their titles
## (English source text).
const FIELDS: Array[Array] = [
	["name", "Name or business name"],
	["id_number", "Company ID (IČ)"],
	["authorisation", "Authorisation"],
	["company", "Trade name"],
	["address", "Address"],
	["phone", "Phone"],
	["email", "E-mail"],
	["web", "Web"],
]

## How many values [method missing] asks for while nothing is given: the
## name, company ID, authorisation, address, and a phone or an e-mail.
const REQUIRED: int = 5

## What was given, by field; a field not given is missing.
static var data: Dictionary = {}


## The keys of [constant FIELDS].
static func keys() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for field: Array in FIELDS:
		result.append(field[0])
	return result


## [param raw] cleaned: only the fields of [constant FIELDS], as text, the
## empty ones left out.
static func clean(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if raw is Dictionary:
		for key: String in keys():
			var value: Variant = (raw as Dictionary).get(key)
			if value is String and not (value as String).strip_edges().is_empty():
				result[key] = (value as String).strip_edges()
	return result


## Field [param key] as given, "" when not.
static func value(key: String) -> String:
	return str(data.get(key, ""))


## The name the documents call the maker by: the trade name, else the name;
## "" when neither is given.
static func shown_name() -> String:
	return value("company") if not value("company").is_empty() else value("name")


## The titles (English) of the fields the documents need that are not given:
## the name, company ID, authorisation, address and a phone or an e-mail.
static func missing() -> Array[String]:
	var result: Array[String] = []
	for field: Array in FIELDS:
		if field[0] in ["name", "id_number", "authorisation", "address"] and value(field[0]).is_empty():
			result.append(field[1])
	if value("phone").is_empty() and value("email").is_empty():
		result.append("Phone or e-mail")
	return result
