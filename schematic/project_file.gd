class_name ProjectFile
extends RefCounted
## Reads and writes schematics as .ladder files: UTF-8 JSON with a format
## name and version around the [DocumentSerializer] data.

const EXTENSION: String = "ladder"
const FORMAT: String = "ladder-lab"
## Raise when the file layout changes; older files must keep loading.
## 1: first format. 2: switching times per coil and the switching mode
## (missing in version 1, so defaults are used). 3: fuses, breakers, overload
## relays and contacts, changeover contacts, custom terminal names.
## 4: three-phase supplies, main contacts, three-pole fuses, breakers and
## overload relays, three-phase motors. 5: purpose text of lamps, PE terminal
## of three-phase motors (version 4 custom motor terminal names get "PE" added).
## 6: fuse holders (fuses that can be opened). 7: multifunction time relays
## (functions F1-F9, optional control input S). 8: terminals of terminal
## strips (svorky) with free labels. 9: wire numbers (with dragged offsets);
## fuses and breakers of 1-4 poles saved as "fuse" / "breaker" with "poles"
## (older "fuse3" / "breaker3" still load), main contacts with "poles".
## 10: control boxes of the operator panel (missing before: no boxes).
## 11: DC supply points + / - (conductor "+" / "-"), run-down and DC
## braking times of three-phase motors (missing before: defaults), bridge
## rectifiers ("rectifier").
## 12: pages (titles, the page of each component, the page shown) and page
## connectors (missing before: one untitled page).
## 13: title block texts of the exported sheets (missing before: empty).
## 14: PE supply points (conductor "PE"), time relays with A1 and A2 swapped.
## 15: switchboard rails with their devices and terminal strips ("cabinet",
## missing before: no switchboard).
## 16: rated currents of fuses and breakers, breaker characteristic B / C / D,
## current setting of overload relays, rating plate of three-phase motors
## (rated power, current, speed, power factor, starting current ratio,
## run-up time, whether the plate is drawn; missing before: defaults).
## 17: PLCs ("plc") with their program (function block diagram and ladder
## diagram).
## 18: order of the terminals of a terminal strip set in the switchboard
## ("strip_order"; missing before: in the order of their labels).
## 19: expansion modules of PLCs ("modules"; missing before: none).
## 20: rated voltages of coils, time relays, lamps and PLCs ("rating", see
## VoltageRating; missing: works on any voltage), the voltage of + supplies
## ("voltage"; missing before: 24 V).
## 21: temperature sensors ("temp_sensor": range, start temperature), analog
## modules of PLCs ("2ai", "2aq"), analog blocks and ladder elements of PLC
## programs (gain, offset, on, off, value).
## 22: compact CPUs ("plc" with "family": "compact" and "cpu"; missing: a
## logic module) and their signal modules ("sm_di8" ...).
## 23: frequency inverters ("vfd": control, setpoint, maximum frequency,
## ramps, fixed and keypad frequency).
## 24: the workspace: several switchboards ("switchboards": name, title,
## position, rails; the "cabinet" rails of older files become switchboard
## RA1), control stations with a name and position, groups of parts in the
## field ("groups") and where those parts stand ("field").
const VERSION: int = 24


## Writes [param doc] to [param path]. Returns OK or the file error.
static func save(doc: SchematicDocument, path: String) -> Error:
	var data: Dictionary = to_dict(doc)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.close()
	return OK


## Reads a schematic. Returns {"document": SchematicDocument} on success or
## {"error": English message with one %s for the file name}.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "Could not open %s."}
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		return {"error": "Could not open %s."}
	return parse(text)


## Parses file contents; see [method load_file].
static func parse(text: String) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {"error": "%s is not a LadderLab file."}
	return from_dict(json.data)


## The file contents of [param doc] before they are turned into JSON.
static func to_dict(doc: SchematicDocument) -> Dictionary:
	return {"format": FORMAT, "version": VERSION, "document": DocumentSerializer.to_dict(doc)}


## Reads parsed file contents; see [method load_file].
static func from_dict(data: Dictionary) -> Dictionary:
	if data.get("format", "") != FORMAT:
		return {"error": "%s is not a LadderLab file."}
	var version: Variant = data.get("version", 0)
	if not (version is float or version is int) or int(version) < 1:
		return {"error": "%s is not a LadderLab file."}
	if int(version) > VERSION:
		return {"error": "%s was saved by a newer version of LadderLab."}
	var document_data: Variant = data.get("document", null)
	if not (document_data is Dictionary):
		return {"error": "%s is damaged and cannot be opened."}
	var doc: SchematicDocument = DocumentSerializer.from_dict(document_data)
	if doc == null:
		return {"error": "%s is damaged and cannot be opened."}
	return {"document": doc}
