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
## 25: names of the cables of the workspace ("cables": "+RA1|+ST1" -> "W1";
## missing before: named in turn).
## 26: mechanical links of groups ("drive", "travel_time", "start", "stops":
## the motor moving the group's part and where its limit switches are;
## missing before: none).
## 27: keys of the keyboard bound to push buttons and switches ("keys":
## designation -> key; missing before: none).
## 28: type names, cross-sections and lengths set on cables of the workspace
## ("cable_settings": "+RA1|+ST1" -> {"type", "section", "length"}; missing
## before: none).
## 29: load of three-phase motors ("load", % of the rated torque; missing
## before: 100).
## 30: control stations shown on the workspace as their face ("face": its
## scale; missing before: as their tile).
## 31: rotary cam switches ("cam_switch": poles, "positions" 0-I or I-0-II).
## 32: selector switches with the positions I-0-II ("latching_switch" with
## "positions": "I-0-II" and "operated_in" I or II; missing: 0-I).
## 33: the door of a switchboard ("door": columns and items like a control
## station's; missing before: an empty door).
## 34: proximity sensors ("proximity": sensing, output, function) and
## transmitters ("transmitter": quantity, range, value).
## 35: Ethernet: the IP address of PLCs ("ip"; missing before: 192.168.0.1),
## the port P1 added after their other terminals (custom terminal names of
## older PLCs get it added), network switches ("network_switch"), the
## network inputs of PLC programs ("network" in the program; missing
## before: none).
## 36: potentiometers ("pot": turns, setting in %) and station or door
## items of kind "pot".
## 37: + supplies of 10 V ("voltage": 10, a reference for potentiometers).
## 38: house installations ("environment": "residential"; missing: an
## industrial control circuit) with light switches ("light_switch": circuit
## 1-7, height), luminaires ("luminaire": power, height) and socket outlets
## ("socket": gangs, height).
## 39: residual current devices ("rcd": poles, residual, rcd_type,
## rated_current, overcurrent and characteristic of an RCBO), arc fault
## detection devices ("afdd"), appliances ("appliance": kind, power,
## two_phases, height) and appliances plugged into sockets ("plugged",
## "plugged_power"; missing: nothing plugged in).
## 40: the floor plan of a house installation ("floor_plan": rooms with
## name and rect, doors, where the parts and the consumer unit "+RD1" are
## with the way they face; missing: an empty plan).
## 41: three environments: "prototype" (saved as "residential" before) and
## "installation", a residential installation with its single-line diagram
## ("single_line": columns of circuits and RCD groups, each circuit's
## device, phase, the parts it feeds, destination, room, cable, ripple
## control; the supply cable and the SPD).
## 42: the lighting drawn on the floor plan of a residential installation
## ("links": [part, port, part, port]) and its rooms' "number",
## "environment" and "lux" (missing: the usual ones).
const VERSION: int = 42


## PLC program files (see [method save_plc_program]). 2: the network
## inputs' partners ("network" in the program; missing before: none).
const PLC_EXTENSION: String = "plcprog"
const PLC_FORMAT: String = "ladder-lab-plc"
const PLC_VERSION: int = 2


## Writes PLC program [param program] to [param path] on its own (JSON
## {format, version, program}, written as [method write_atomically] does),
## to use it again in another PLC. Returns OK or the file error.
static func save_plc_program(program: PlcProgram, path: String) -> Error:
	var data: Dictionary = {"format": PLC_FORMAT, "version": PLC_VERSION, "program": program.to_data()}
	return write_atomically(path, JSON.stringify(data, "\t") + "\n")


## Reads a PLC program file: {"program": PlcProgram} or {"error": English
## message with one %s for the file name}. Damaged parts of the program are
## left out (see [method PlcProgram.from_data]).
static func load_plc_program(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "Could not open %s."}
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary) or (json.data as Dictionary).get("format", "") != PLC_FORMAT:
		return {"error": "%s is not a PLC program of LadderLab."}
	return {"program": PlcProgram.from_data((json.data as Dictionary).get("program", {}))}


## Writes [param doc] to [param path]. Returns OK or the file error. The
## file is written next to it first and only then put in its place, so a
## write that fails (a full disk) never spoils the file saved before.
static func save(doc: SchematicDocument, path: String) -> Error:
	return write_atomically(path, JSON.stringify(to_dict(doc), "\t") + "\n")


## How many times, [constant RENAME_WAIT_MSEC] apart, the written file is
## put in place: on Windows an antivirus reading the new file (in Downloads
## above all) holds it for a moment, and the rename fails meanwhile.
const RENAME_TRIES: int = 50
const RENAME_WAIT_MSEC: int = 20


## Writes [param text] to [param path] through a temporary file beside it
## (path + ".tmp"), checking every step. Returns OK or the file error.
static func write_atomically(path: String, text: String) -> Error:
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored: bool = file.store_string(text)
	file.flush()
	# What did not reach the disk (it is full) leaves the file short.
	var complete: bool = stored and file.get_error() == OK and file.get_length() == text.to_utf8_buffer().size()
	file.close()
	if not complete:
		DirAccess.remove_absolute(temporary)
		return ERR_FILE_CANT_WRITE
	var error: Error = DirAccess.rename_absolute(temporary, path)
	for i: int in RENAME_TRIES - 1:
		if error == OK:
			break
		OS.delay_msec(RENAME_WAIT_MSEC)
		error = DirAccess.rename_absolute(temporary, path)
	return error


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
	if str(data.get("format", "")) != FORMAT:
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
