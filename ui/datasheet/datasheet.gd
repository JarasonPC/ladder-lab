class_name Datasheet
extends RefCounted
## What the datasheet of a part says, written like a manufacturer's
## datasheet: title, summary, description, features, the terminal
## assignment (every terminal of the part, with its name and function), the
## technical data, a function diagram where the part has one (time relay
## functions, time-current characteristic) and the device front where the part
## sits on a DIN rail in the switchboard. Built from the part itself
## ([method of]), so terminal names, poles, modules, ratings and times are
## the ones it has; the texts are translated when built. No nodes.

enum Diagram { NONE, TIMER, TRIP_CURVE }

## Designation letters of the parts made from palette templates, for the
## datasheets of the parts library (see [method of_template]).
const LETTERS: Dictionary[String, String] = {
	"push_button": "SB", "latching_switch": "RB", "cam_switch": "RB", "limit_switch": "SQ", "contact": "KM",
	"changeover": "KA", "coil": "KM", "timer": "KT", "lamp": "H", "motor": "M", "motor3": "M",
	"fuse": "FU", "breaker": "FA", "overload_relay": "F", "overload_contact": "F",
	"main_contacts": "KM", "terminal": "X", "rectifier": "TB", "connector": "PC", "plc": "A",
	"temp_sensor": "BT", "vfd": "TA",
}

## The part, as in the schematic (or made from a palette template).
var component: CircuitComponent
## The schematic the part is in; the device front is described from it.
var document: SchematicDocument
var title: String = ""
var summary: String = ""
## Palette group of the part ("Coils", "Protection", ...), translated.
var group: String = ""
## Designation letters ("KT" of "KT1").
var letters: String = ""
var description: PackedStringArray = PackedStringArray()
var features: PackedStringArray = PackedStringArray()
## Terminal assignment: [terminal, name, function]; a row with an empty
## terminal is a heading over the rows after it.
var terminals: Array[PackedStringArray] = []
## Technical data: [quantity, value].
var data: Array[PackedStringArray] = []
## A second table (time relay functions): its title and [code, text] rows.
var table_title: String = ""
var table: Array[PackedStringArray] = []
var diagram: Diagram = Diagram.NONE
var diagram_title: String = ""
var timer_mode: TimerRelay.Mode = TimerRelay.Mode.ON_DELAY
var trip_kind: TripCurve.Kind = TripCurve.Kind.FUSE_GG
## Name of a time relay's control input on its diagram.
var control_name: String = "S"
## The device in the switchboard ([method CabinetDevices.describe]); {} for
## parts that do not sit on a rail.
var front: Dictionary = {}


## The datasheet of [param c], a part of [param doc].
static func of(c: CircuitComponent, doc: SchematicDocument) -> Datasheet:
	var sheet: Datasheet = Datasheet.new()
	sheet.component = c
	sheet.document = doc
	sheet._build()
	return sheet


## The datasheet of a part made from palette [param template] (see
## [constant Palette.ENTRIES]), alone in a schematic of its own.
static func of_template(template: Dictionary) -> Datasheet:
	var d: Dictionary = template.duplicate()
	var type: String = d["type"]
	if type == "supply":
		var conductor: String = str(d.get("conductor", "L"))
		d["designation"] = "L1" if conductor == "L" else conductor
	else:
		d["designation"] = str(LETTERS.get(type, "X")) + "1"
	if type == "terminal" or type == "connector":
		d["label"] = "1"
	# As placed from the palette: the first rating offered.
	var ratings: PackedStringArray = VoltageRating.offered(type)
	if not ratings.is_empty() and d.get("family", "") != "compact":
		d["rating"] = ratings[0]
	var c: CircuitComponent = DocumentSerializer.component_from_dict(d)
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(c, Vector2i.ZERO)
	return of(c, doc)


## Designation letters of [param designation]: "KT" of "KT1", "L" of "L1".
static func letters_of(designation: String) -> String:
	var end: int = designation.length()
	while end > 1 and designation[end - 1].is_valid_int():
		end -= 1
	return designation.substr(0, end)


func _build() -> void:
	letters = component.designation if component is PowerSupply else letters_of(component.designation)
	group = _group_title()
	title = _palette_title()
	front = CabinetDevices.describe(document, component.designation) if CabinetDevices.kind_of(component) != CabinetDevices.Kind.NONE else {}
	if component is PowerSupply:
		_supply(component as PowerSupply)
	elif component is TerminalBlock:
		_terminal_block(component as TerminalBlock)
	elif component is PageConnector:
		_page_connector(component as PageConnector)
	elif component is Rectifier:
		_rectifier()
	elif component is OverloadContact:
		_overload_contact(component as OverloadContact)
	elif component is ProtectiveDevice or component is MotorBreaker or component is ThreePoleFuse:
		_protective()
	elif component is CamSwitch:
		_cam_switch(component as CamSwitch)
	elif component is SwitchingElement:
		_switching(component as SwitchingElement)
	elif component is ChangeoverContact:
		_changeover(component as ChangeoverContact)
	elif component is MainContacts:
		_main_contacts(component as MainContacts)
	elif component is OverloadRelay:
		_overload_relay(component as OverloadRelay)
	elif component is TimerRelay:
		_timer(component as TimerRelay)
	elif component is Coil:
		_coil(component as Coil)
	elif component is Plc:
		_plc(component as Plc)
	elif component is TemperatureSensor:
		_sensor(component as TemperatureSensor)
	elif component is Lamp:
		_lamp(component as Lamp)
	elif component is Motor:
		_motor()
	elif component is ThreePhaseMotor:
		_motor3(component as ThreePhaseMotor)
	elif component is Vfd:
		_vfd(component as Vfd)
	else:
		title = tr("Wire junction")


## Title of the palette entry the part is made from.
func _palette_title() -> String:
	if component is OverloadContact:
		return tr("Overload relay contact")
	# The entry that says the most about it (the compact PLC over the PLC).
	var best: Dictionary = {}
	var best_size: int = 0
	for entry: Dictionary in Palette.ENTRIES:
		var template: Dictionary = (entry["template"] as Dictionary).duplicate()
		# The palette places one CPU size; the others are the same part.
		template.erase("cpu")
		if SchematicEditor.matches_template(component, template) and (best.is_empty() or template.size() > best_size):
			best = entry
			best_size = template.size()
	return tr(best["title"]) if not best.is_empty() else component.designation


func _group_title() -> String:
	var type: String = DocumentSerializer.component_to_dict(component).get("type", "")
	match Palette.group_of({"type": type}):
		"supplies":
			return tr("Supplies and terminals")
		"buttons":
			return tr("Buttons and switches")
		"contacts":
			return tr("Contacts")
		"coils":
			return tr("Coils")
		"loads":
			return tr("Loads")
		"protection":
			return tr("Protection")
		"plc":
			return tr("PLC and sensors")
	return tr("Power circuit")


# --- Helpers ------------------------------------------------------------------------

func _row(terminal: String, name: String, function: String) -> void:
	terminals.append(PackedStringArray([terminal, name, function]))


func _heading(text: String) -> void:
	terminals.append(PackedStringArray(["", text, ""]))


func _data(quantity: String, value: String) -> void:
	data.append(PackedStringArray([quantity, value]))


## The part's terminal names, as drawn (renamed ones too).
func _names() -> PackedStringArray:
	return component.get_terminal_names()


## ", 3 poles" for a part of more than one pole, else "".
func _poles_text(poles: int) -> String:
	return ", " + tr("%d poles") % poles if poles > 1 else ""


static func _num(value: float) -> String:
	return Fuse.amperes_text(value)


static func _volts(value: float) -> String:
	return "%s V" % _num(snappedf(value, 0.1))


## Rated voltage, working range and burn-out of a load rated [param rating].
func _rating_data(rating: String, works: String) -> void:
	if rating.is_empty():
		_data(tr("Rated voltage"), tr("Not set (works on any voltage)"))
		return
	var nominal: float = VoltageRating.nominal(rating)
	_data(tr("Rated voltage"), VoltageRating.text(rating))
	_data(works, tr("from %s (85 %%)") % _volts(VoltageRating.lowest(rating)))
	_data(tr("Burns out"), tr("above %s (130 %%)") % _volts(VoltageRating.BURN * nominal))
	match VoltageRating.kind(rating):
		VoltageRating.Kind.AC:
			_data(tr("On DC"), tr("burns out from %s (30 %%)") % _volts(VoltageRating.AC_ON_DC * nominal))
		VoltageRating.Kind.DC:
			_data(tr("On AC"), tr("does not pull in"))


## What operates the contacts named [param designation]: "the coil KM1 has
## pulled in", "button SB1 is pressed", ... ([param delayed]: a time relay's
## delayed contacts).
func _operated(designation: String, delayed: bool) -> String:
	for c: CircuitComponent in document.circuit.get_components():
		if c.designation != designation:
			continue
		if c is TimerRelay and delayed:
			return tr("output R of time relay %s is on") % designation
		if c is Coil:
			return tr("coil %s has pulled in") % designation
	for c: CircuitComponent in document.circuit.get_components():
		if c.designation != designation:
			continue
		if c is LimitSwitch:
			return tr("limit switch %s is operated") % designation
		if c is LatchingSwitch:
			return tr("switch %s is on") % designation
		if c is PushButton:
			return tr("button %s is pressed") % designation
		if c is CircuitBreaker or c is MotorBreaker:
			return tr("circuit breaker %s is on") % designation
	return tr("its device %s is operated") % designation


## Rows of a two-terminal contact block: [param operated] tells when it is
## operated ("the button is pressed").
func _contact_rows(names: PackedStringArray, no: bool, operated: String) -> void:
	var kind: String = tr("NO contact") if no else tr("NC contact")
	for i: int in 2:
		var other: String = names[1 - i]
		if no:
			_row(names[i], kind, tr("Closed to %s while %s.") % [other, operated])
		else:
			_row(names[i], kind, tr("Closed to %s at rest; open while %s.") % [other, operated])


## The contact terminal marking, for buttons, switches and contacts.
func _marking_data() -> void:
	_data(tr("Terminal marking"), tr("1st digit: contact block; 2nd: function (1-2 NC, 3-4 NO, 5-6 delayed NC, 7-8 delayed NO)"))


## Rows of the contacts drawn with the part's designation (on parts of their
## own: main, auxiliary and changeover contacts), under a heading; while none is drawn, those of the device in the
## switchboard: a time relay's changeover 15-16-18, a contactor's main
## contacts and 13-14, 21-22, a relay's changeover 11-12-14.
func _device_contacts(delayed_by_output: bool) -> void:
	var contacts: Array[CircuitComponent] = CabinetDevices.contacts_of(document.circuit, component.designation)
	var mains: Array[MainContacts] = []
	for c: CircuitComponent in document.circuit.get_components():
		if c is MainContacts and c.designation == component.designation:
			mains.append(c as MainContacts)
	if contacts.is_empty() and mains.is_empty():
		_heading(tr("Contacts (parts of their own)"))
		var operated: String = tr("the coil has pulled in")
		if delayed_by_output:
			_changeover_rows(PackedStringArray(["15", "16", "18"]), tr("output R is on"))
		elif (component as Coil).kind == Coil.Kind.CONTACTOR:
			for p: int in 3:
				_row(str(2 * p + 1), tr("Main contact, pole %d") % (p + 1), tr("Supply side; closed to %s while %s.") % [str(2 * p + 2), operated])
				_row(str(2 * p + 2), tr("Main contact, pole %d") % (p + 1), tr("Load side; closed to %s while %s.") % [str(2 * p + 1), operated])
			_contact_rows(PackedStringArray(["13", "14"]), true, operated)
			_contact_rows(PackedStringArray(["21", "22"]), false, operated)
		else:
			_changeover_rows(PackedStringArray(["11", "12", "14"]), operated)
		return
	_heading(tr("Contacts drawn as -%s") % component.designation)
	# Main contacts first, poles numbered on over all of them.
	var pole: int = 0
	for c: MainContacts in mains:
		var names: PackedStringArray = c.get_terminal_names()
		for p: int in c.poles:
			pole += 1
			var operated: String = tr("the coil has pulled in")
			_row(names[2 * p], tr("Main contact, pole %d") % pole, tr("Supply side; closed to %s while %s.") % [names[2 * p + 1], operated])
			_row(names[2 * p + 1], tr("Main contact, pole %d") % pole, tr("Load side; closed to %s while %s.") % [names[2 * p], operated])
	for c: CircuitComponent in contacts:
		var delayed: bool = (c as Contact).delayed if c is Contact else (c as ChangeoverContact).delayed
		var operated: String = tr("output R is on") if delayed and delayed_by_output else tr("the coil has pulled in")
		if c is ChangeoverContact:
			_changeover_rows(c.get_terminal_names(), operated)
		else:
			_contact_rows(c.get_terminal_names(), (c as Contact).contact_type == SwitchingElement.ContactType.NO, operated)


func _changeover_rows(names: PackedStringArray, operated: String) -> void:
	_row(names[0], tr("Common"), tr("Switched between %s and %s.") % [names[1], names[2]])
	_row(names[1], tr("NC side"), tr("Closed to %s at rest; breaks first when %s.") % [names[0], operated])
	_row(names[2], tr("NO side"), tr("Closed to %s while %s; makes after %s has broken.") % [names[0], operated, names[1]])


## Rows of the poles 1-2, 3-4 ... of a power circuit device: [param line]
## and [param load] are formats of the other terminal of the pole, then
## [param args].
func _pole_rows(poles: int, line: String, load: String, args: Array = []) -> void:
	var names: PackedStringArray = _names()
	for p: int in poles:
		_row(names[2 * p], tr("Pole %d, line side") % (p + 1), line % ([names[2 * p + 1]] + args))
		_row(names[2 * p + 1], tr("Pole %d, load side") % (p + 1), load % ([names[2 * p]] + args))


# --- Supplies and terminals --------------------------------------------------------

func _supply(supply: PowerSupply) -> void:
	var name: String = component.designation
	match supply.conductor:
		PowerSupply.Conductor.L, PowerSupply.Conductor.L2, PowerSupply.Conductor.L3:
			summary = tr("Phase of the three-phase source, 230 V against N, 400 V against another phase")
			description.append(tr("Supply point of phase %s of the three-phase source. Loads work between a phase and N (230 V) or between two phases (400 V). Supply points of the same conductor are the same potential on every page.") % name)
			_data(tr("Voltage"), tr("230 V against N, 400 V against another phase, 50 Hz"))
		PowerSupply.Conductor.N:
			summary = tr("Neutral conductor of the three-phase source")
			description.append(tr("Supply point of the neutral conductor N. Loads work between a phase and N. Supply points of the same conductor are the same potential on every page."))
			_data(tr("Voltage"), tr("0 V (the reference of the phases)"))
		PowerSupply.Conductor.PE:
			summary = tr("Protective conductor, joined to N at the source")
			description.append(tr("Supply point of the protective conductor PE. It is joined to N at the source (TN system), so a phase touching it is a short circuit that the fuse or circuit breaker clears. The PE terminals of motors take no part in the simulation."))
			_data(tr("Voltage"), tr("0 V (joined to N at the source)"))
		PowerSupply.Conductor.DC_PLUS:
			summary = tr("Positive pole of a DC source")
			description.append(tr("Positive pole of a DC source of %s against the - poles. DC and AC are separate sources: a load works between two conductors of the same source, and AC joined to DC is a short circuit. Two + supplies of different voltages joined are a short circuit too.") % _volts(supply.voltage))
			_data(tr("Voltage"), tr("%s DC against -") % _volts(supply.voltage))
		PowerSupply.Conductor.DC_MINUS:
			summary = tr("Negative pole shared by every DC source")
			description.append(tr("Negative pole of the DC sources: every + supply and every bridge rectifier output works against it."))
			_data(tr("Voltage"), tr("0 V of the DC sources"))
	_row(name, tr("Supply point"), tr("Wire the circuit to it; it is named by its conductor."))


func _terminal_block(block: TerminalBlock) -> void:
	summary = tr("Connection point of a terminal strip")
	description.append(tr("Terminal of a terminal strip, placed on a wire or on a part's lead. Electrically it only joins its wires. Its label puts it on a strip in the switchboard: \"4\" is terminal 4 of strip X1, \"X2:4\" terminal 4 of strip X2."))
	var label: String = block.label if not block.label.is_empty() else block.designation
	_row(label, tr("Strip terminal"), tr("Joins the wires drawn to it."))
	_data(tr("Strip"), CabinetDevices.split_label(block.label)[0])


func _page_connector(connector: PageConnector) -> void:
	summary = tr("Continues a wire on another page")
	description.append(tr("The wire continues on another page: it is joined to every page connector with the same label (usually the wire number). Right click it to go there."))
	_row(connector.label if not connector.label.is_empty() else "–", tr("Link"), tr("Joined to every page connector with the same label."))
	_data(tr("Label"), connector.label if not connector.label.is_empty() else tr("none (joins nothing)"))


func _rectifier() -> void:
	summary = tr("Full bridge rectifier: AC in, DC out")
	description.append(tr("Full bridge rectifier (Graetz bridge). While its input ~1-~2 has voltage, its + and - are the poles of a DC source of %s, e.g. for DC braking of a motor. The output is isolated from the input, as behind a transformer.") % _volts(PowerSupply.RECTIFIED_VOLTS))
	var names: PackedStringArray = _names()
	_row(names[0], tr("AC input"), tr("Input between two conductors of one source (AC, or DC of either polarity), with %s.") % names[1])
	_row(names[1], tr("AC input"), tr("Other input terminal."))
	_row(names[2], tr("DC output +"), tr("Positive pole of the output while the input has voltage."))
	_row(names[3], tr("DC output -"), tr("Negative pole of the output."))
	_data(tr("Output voltage"), tr("%s DC") % _volts(PowerSupply.RECTIFIED_VOLTS))
	_data(tr("Current drawn"), tr("what its output delivers"))


# --- Buttons, switches, contacts -------------------------------------------------

func _switching(element: SwitchingElement) -> void:
	var no: bool = element.contact_type == SwitchingElement.ContactType.NO
	var names: PackedStringArray = _names()
	_data(tr("Contact"), tr("NO (make)") if no else tr("NC (break)"))
	if element is LimitSwitch:
		summary = tr("Operated by a moving part of the machine")
		description.append(tr("Limit switch, operated by a moving part of the machine. While simulating, a click operates or releases it; it stays until clicked again. Blocks drawn with the same designation are one switch."))
		_contact_rows(names, no, tr("it is operated"))
		_data(tr("Actuator"), tr("latching (operated or released by a click)"))
	elif element is LatchingSwitch:
		summary = tr("Keeps its position until operated again")
		description.append(tr("Switch that keeps its position until operated again (click it while simulating). It snaps over almost at once. Blocks drawn with the same designation are one switch."))
		_contact_rows(names, no, tr("it is on"))
		_data(tr("Actuator"), tr("latching, snap action"))
	elif element is PushButton:
		summary = tr("Momentary: operated only while held")
		description.append(tr("Momentary push button: operated only while held (press and hold it while simulating). Blocks drawn with the same designation are one button: pressing it moves them all, and its NC blocks break before its NO blocks make."))
		_contact_rows(names, no, tr("it is pressed"))
		_data(tr("Actuator"), tr("momentary"))
		_data(tr("Travel time"), "%s ms" % _num(PushButton.TRAVEL_TIME * 1000.0))
	else:
		var contact: Contact = element as Contact
		var operated: String = _operated(element.designation, contact != null and contact.delayed)
		if contact != null and contact.delayed:
			summary = tr("Delayed contact of a time relay")
			description.append(tr("Delayed contact of the time relay with the same designation: it follows the relay's output R, set by its time function, not the supply."))
		else:
			summary = tr("Auxiliary contact of a relay, contactor or device")
			description.append(tr("Auxiliary contact of the relay or contactor with the same designation: it follows the armature of its coil. Named like a push button, switch or limit switch it is one more block of it; named like a circuit breaker it is its auxiliary contact (NO closed while the breaker is on). Without such a device it stays at rest."))
		features.append(tr("NC contacts break at 30 % of the armature travel, NO contacts make at its end."))
		_contact_rows(names, no, operated)
		_data(tr("Belongs to"), element.designation)
	_marking_data()


func _cam_switch(cam: CamSwitch) -> void:
	var names: PackedStringArray = _names()
	if cam.positions == CamSwitch.Positions.OFF_ON:
		summary = tr("Turned by hand: off 0, on I") + _poles_text(cam.poles)
		description.append(tr("Rotary cam switch with the positions 0 (off) and I (on): every pole is a make contact closed in position I. While simulating, a click turns it over; on a control station or a switchboard door its knob is turned to the left or the right."))
		_pole_rows(cam.poles, tr("Closed to %s in position I."), tr("Closed to %s in position I."))
		_data(tr("Positions"), "0 – I")
	else:
		summary = tr("Turned by hand: I forward, 0 off, II reverse") + _poles_text(cam.poles)
		description.append(tr("Rotary cam switch with the positions I, 0 (off, in the middle) and II: every pole joins its common to its I side in position I and to its II side in position II, never to both. Wired with two phases swapped between the I and the II sides, it runs a motor forward in I and in reverse in II. While simulating, a click turns it on to the next position (0, I, 0, II); on a control station or a switchboard door its knob is turned to the left or the right."))
		for p: int in cam.poles:
			_row(names[3 * p], tr("Pole %d, I side") % (p + 1), tr("Closed to %s in position I.") % names[3 * p + 2])
			_row(names[3 * p + 1], tr("Pole %d, II side") % (p + 1), tr("Closed to %s in position II.") % names[3 * p + 2])
			_row(names[3 * p + 2], tr("Pole %d, common") % (p + 1), tr("Switched between %s and %s; open in position 0.") % [names[3 * p], names[3 * p + 1]])
		_data(tr("Positions"), "I – 0 – II")
	features.append(tr("Snap action: it switches at once, every pole together."))
	_data(tr("Poles"), str(cam.poles))
	_data(tr("Actuator"), tr("knob, stays where it is turned"))


func _changeover(c: ChangeoverContact) -> void:
	summary = tr("Common switched between an NC and an NO side")
	description.append(tr("Changeover contact of the relay, contactor or time relay with the same designation: a common terminal switched between an NC side and an NO side. Operated, it first breaks common-NC, then makes common-NO."))
	if c.delayed:
		description.append(tr("Delayed (15-16-18): it follows output R of the time relay, not the supply."))
	_changeover_rows(_names(), _operated(c.designation, c.delayed))
	_data(tr("Belongs to"), c.designation)
	_data(tr("Terminal marking"), tr("common-NC-NO: x1-x2-x4, delayed x5-x6-x8"))


func _overload_contact(c: OverloadContact) -> void:
	var no: bool = c.contact_type == SwitchingElement.ContactType.NO
	summary = tr("Contact of a thermal overload relay")
	description.append(tr("Auxiliary contact of the thermal overload relay with the same designation: NC 95-96 opens and NO 97-98 closes when the relay has tripped, until it is reset."))
	_contact_rows(_names(), no, tr("overload relay %s has tripped") % c.designation)
	_data(tr("Contact"), tr("NO (make)") if no else tr("NC (break)"))
	_data(tr("Belongs to"), c.designation)
	_data(tr("Terminal marking"), tr("NC 95-96, NO 97-98"))


func _main_contacts(c: MainContacts) -> void:
	summary = tr("Power contacts of a contactor") + _poles_text(c.poles)
	description.append(tr("Main (power) contacts of the contactor with the same designation. They make together with its NO contacts, at the end of the armature travel, and carry the current of the motor or load. Named like a push button or switch, they follow its actuator."))
	_pole_rows(c.poles, tr("Supply side; closed to %s while %s."), tr("Load side; closed to %s while %s."), [_operated(c.designation, false)])
	_data(tr("Poles"), str(c.poles))
	_data(tr("Belongs to"), c.designation)


# --- Coils and loads -----------------------------------------------------------

func _coil_rows() -> void:
	var names: PackedStringArray = _names()
	_row(names[0], tr("Coil"), tr("Rated voltage against %s pulls the armature in.") % names[1])
	_row(names[1], tr("Coil"), tr("Other end of the coil. %s and %s can be swapped.") % [names[0], names[1]])


func _coil(coil: Coil) -> void:
	var contactor: bool = coil.kind == Coil.Kind.CONTACTOR
	summary = tr("Contactor coil (KM)") if contactor else tr("Auxiliary relay coil (KA)")
	description.append(tr("Coil of a contactor (KM) or an auxiliary relay (KA). Every contact drawn with its designation (auxiliary, changeover and main contacts) follows its armature. It pulls in from 85 % of its rated voltage; far too much voltage, or DC on an AC coil, burns it out."))
	features.append(tr("NC contacts break at 30 % of the armature travel, NO contacts make at its end."))
	features.append(tr("Switching times differ by up to ±5 % between coils, so two relays started together never stay in step."))
	_coil_rows()
	_device_contacts(false)
	_rating_data(coil.rating, tr("Pulls in"))
	_data(tr("Pick-up time"), "%s ms" % _num(coil.pick_up_time * 1000.0))
	_data(tr("Drop-out time"), "%s ms" % _num(coil.drop_out_time * 1000.0))
	_data(tr("Current drawn"), "%s A" % _num(coil.rated_draw()))


func _timer(timer: TimerRelay) -> void:
	var names: PackedStringArray = _names()
	control_name = names[2] if names.size() > 2 else "S"
	var titles: Array = TimerFunctionsPopup.function_titles(control_name)
	summary = tr("12 time functions F1-F12 plus a true off-delay")
	description.append(tr("Multifunction time relay. Powered on A1-A2; the function set decides when its output R switches. R moves the delayed contacts (5-6, 7-8, changeover 15-16-18); other contacts drawn with its designation switch with the supply."))
	features.append(tr("Functions F1-F12 as on real multifunction relays, plus a true off-delay"))
	features.append(tr("Two times t1 and t2 for F10, F11 and F12"))
	features.append(tr("Losing the supply resets every function except the off-delay"))
	var a2: int = timer.a2_index()
	_row(names[1 - a2], tr("Supply"), tr("Rated voltage against %s powers the relay and starts the function.") % names[a2])
	_row(names[a2], tr("Supply, reference"), tr("Other end of the supply and the reference of %s.") % control_name)
	if names.size() > 2:
		_row(names[2], tr("Control input"), tr("Counts as pressed while it has voltage against %s, like the button input of a real relay. Used by F3, F4, F5, F6, F8 and F12.") % names[a2])
	else:
		_row("S", tr("Control input"), tr("Optional (Control input in the properties): counts as pressed while it has voltage against %s. Used by F3, F4, F5, F6, F8 and F12.") % names[a2])
	_device_contacts(true)
	_rating_data(timer.rating, tr("Works"))
	_data(tr("Function"), str(titles[timer.mode]))
	if TimerRelay.uses_two_times(timer.mode):
		_data(tr("Times t1 / t2"), "%s s / %s s" % [_num(timer.delay), _num(timer.delay2)])
	else:
		_data(tr("Time t"), "%s s" % _num(timer.delay))
	_data(tr("Pulse of F7"), "%s s" % _num(TimerRelay.GENERATOR_PULSE))
	_data(tr("Pick-up time"), "%s ms" % _num(timer.pick_up_time * 1000.0))
	_data(tr("Drop-out time"), "%s ms" % _num(timer.drop_out_time * 1000.0))
	table_title = tr("Time functions")
	for m: int in titles.size():
		var code: String = TimerRelay.code_of(m as TimerRelay.Mode)
		table.append(PackedStringArray([code if not code.is_empty() else "–", str(titles[m])]))
	diagram = Diagram.TIMER
	timer_mode = timer.mode
	diagram_title = tr("Function diagram: %s") % str(titles[timer.mode])


func _lamp(lamp: Lamp) -> void:
	summary = tr("Signal lamp, AC or DC")
	description.append(tr("Signal lamp. It lights while it has voltage between two conductors of one source, AC or DC alike; far too much voltage burns it out. A purpose written above it says what it signals."))
	var names: PackedStringArray = _names()
	_row(names[0], tr("Lamp"), tr("Lights with its rated voltage against %s.") % names[1])
	_row(names[1], tr("Lamp"), tr("Other end of the lamp."))
	_rating_data(lamp.rating, tr("Lights"))
	_data(tr("Current drawn"), "%s A" % _num(lamp.rated_draw()))
	if not lamp.purpose.is_empty():
		_data(tr("Purpose"), lamp.purpose)


func _motor() -> void:
	summary = tr("Motor as a simple load")
	description.append(tr("Motor drawn as a simple load between two terminals: it runs while it has voltage across them. For three-phase motors with currents, run-up and braking use the 3~ motors."))
	var names: PackedStringArray = _names()
	_row(names[0], tr("Winding"), tr("Supply against %s.") % names[1])
	_row(names[1], tr("Winding"), tr("Other end of the winding."))
	_data(tr("Rated voltage"), tr("Not set (works on any voltage)"))
	_data(tr("Current drawn"), "%s A" % _num(component.rated_draw()))


# --- Protection ---------------------------------------------------------------

func _protective() -> void:
	var poles: int = (component as PoleDevice).poles if component is PoleDevice else 1
	var breaker: bool = component is CircuitBreaker or component is MotorBreaker
	var rated: float
	if component is MotorBreaker:
		rated = (component as MotorBreaker).rated_current
	elif component is ThreePoleFuse:
		rated = (component as ThreePoleFuse).rated_current
	else:
		rated = (component as ProtectiveDevice).rated_current
	diagram = Diagram.TRIP_CURVE
	diagram_title = tr("Time-current characteristic")
	if breaker:
		var characteristic: CircuitBreaker.Characteristic = (component as MotorBreaker).characteristic if component is MotorBreaker else (component as CircuitBreaker).characteristic
		trip_kind = CircuitBreaker.breaker_curve(characteristic)
		var band: Vector2 = TripCurve.MAGNETIC_BAND[trip_kind]
		summary = tr("Circuit breaker %s") % CircuitBreaker.rating_text(characteristic, rated) + _poles_text(poles)
		description.append(tr("Circuit breaker with thermal and magnetic release: it trips on an overcurrent after the time of its thermal release, at once above the current of its magnetic release, and on a short circuit. It is switched off and on by hand (click it while simulating); switching on resets a trip. It starts switched off."))
		features.append(tr("The thermal release keeps its heat after a trip: switched on again while still hot, it trips sooner."))
		if poles > 1:
			features.append(tr("An overcurrent or fault current in any pole trips all poles."))
		features.append(tr("Contacts drawn with its designation are its auxiliary contacts (NO closed while it is on)."))
		_pole_rows(poles, tr("Supply side; joined to %s while the breaker is on."), tr("Load side; joined to %s while the breaker is on."))
		_data(tr("Rated current In"), "%s A" % _num(rated))
		_data(tr("Characteristic"), TripCurve.LETTERS[characteristic])
		_data(tr("Magnetic release"), tr("%s-%s × In") % [_num(band.x), _num(band.y)])
		_data(tr("Standard"), "ČSN EN 60898")
	else:
		var holder: bool = (component as ThreePoleFuse).holder if component is ThreePoleFuse else (component as Fuse).holder
		trip_kind = TripCurve.Kind.FUSE_GG
		summary = tr("Fuse gG %s A") % _num(rated) + _poles_text(poles)
		description.append(tr("Fuse gG. It blows when the fault current of a short circuit flows through it, or when an overcurrent lasts as long as its characteristic allows. While simulating, a blown fuse is replaced from its menu; a new fuse is cold."))
		if holder:
			features.append(tr("In a fuse holder (fuse disconnector): opened and closed by a click; holders start open."))
		if poles > 1:
			features.append(tr("Each pole blows on its own; a holder opens all poles together."))
		_pole_rows(poles, tr("Supply side; joined to %s through the fuse."), tr("Load side; joined to %s through the fuse."))
		_data(tr("Rated current In"), "%s A" % _num(rated))
		_data(tr("Characteristic"), "gG")
		_data(tr("Fuse holder"), tr("yes") if holder else tr("no"))
	_data(tr("Poles"), str(poles))


func _overload_relay(relay: OverloadRelay) -> void:
	summary = tr("Thermal overload relay, trip class 10")
	description.append(tr("Thermal overload relay. With three poles its heaters carry the motor current (1-2, 3-4, 5-6) and it trips after the time of trip class 10 when the largest heater current is above its setting Ir: an overloaded motor, a lost phase, a start that lasts too long. Without poles it trips only with the injected fault \"Motor overloaded\", after its trip delay."))
	features.append(tr("Its contacts NC 95-96 and NO 97-98 are drawn as parts of their own with its designation."))
	features.append(tr("Test button and reset as on the real one, from its menu or in the switchboard; the heaters keep their heat after a reset."))
	if relay.poles == 3:
		_pole_rows(3, tr("From the contactor; the heater carries the current to %s."), tr("To the motor; the heater carries the current from %s."))
	_device_overload_contacts()
	_data(tr("Setting Ir"), "%s A" % _num(relay.setting))
	_data(tr("Trip class"), "10")
	_data(tr("Poles"), str(relay.poles))
	if relay.poles == 0:
		_data(tr("Trip delay"), "%s s" % _num(relay.trip_delay))
	diagram = Diagram.TRIP_CURVE
	trip_kind = TripCurve.Kind.OVERLOAD
	diagram_title = tr("Time-current characteristic")


## Rows of its contacts drawn with its designation; the standard 95-96 and
## 97-98 while none is drawn.
func _device_overload_contacts() -> void:
	var drawn: Array[OverloadContact] = []
	for c: CircuitComponent in document.circuit.get_components():
		if c is OverloadContact and c.designation == component.designation:
			drawn.append(c as OverloadContact)
	if drawn.is_empty():
		_heading(tr("Contacts (parts of their own)"))
		_contact_rows(PackedStringArray(["95", "96"]), false, tr("the relay has tripped"))
		_contact_rows(PackedStringArray(["97", "98"]), true, tr("the relay has tripped"))
		return
	_heading(tr("Contacts drawn as -%s") % component.designation)
	for c: OverloadContact in drawn:
		_contact_rows(c.get_terminal_names(), c.contact_type == SwitchingElement.ContactType.NO, tr("the relay has tripped"))


# --- Motors and drives ---------------------------------------------------------

func _motor3(motor: ThreePhaseMotor) -> void:
	var names: PackedStringArray = _names()
	var standard: PackedStringArray = motor.default_terminal_names()
	summary = tr("Three-phase induction motor 3 x 400 V, %s kW") % _num(motor.rated_power)
	description.append(tr("Three-phase induction motor. It runs when all three phases reach the right terminals: L1-L2-L3 on U-V-W turns it clockwise, two phases swapped reverse it. Two phases only is a phase loss (it hums and overheats). + and - of a DC source across a winding brake it (DC braking)."))
	match motor.kind:
		ThreePhaseMotor.Kind.STAR_DELTA:
			description.append(tr("Windings U1-U2, V1-V2, W1-W2 brought out for a star/delta start: U2 V2 W2 joined is star, each end joined to the start of the next winding is delta. Started in star it draws a third of the current."))
		ThreePhaseMotor.Kind.DAHLANDER:
			description.append(tr("Dahlander motor (two speeds, one winding): low speed in delta on 1U 1V 1W, high speed in double star on 2U 2V 2W with 1U 1V 1W joined."))
		ThreePhaseMotor.Kind.TWO_WINDINGS, ThreePhaseMotor.Kind.THREE_WINDINGS:
			description.append(tr("A separate star-connected winding for each speed. Feeding two speeds at once is miswired and overheats it."))
	features.append(tr("After switching off, it runs down in its coast time; with DC braking in its brake time."))
	features.append(tr("Its rating plate can be shown beside it (properties)."))
	for i: int in standard.size():
		var std: String = standard[i]
		if std == "PE":
			_row(names[i], tr("Protective earth"), tr("Frame of the motor; takes no part in the simulation."))
		elif motor.kind == ThreePhaseMotor.Kind.STAR_DELTA and std.ends_with("2"):
			_row(names[i], tr("End of winding %s") % std[0], tr("Joined to the other ends for star, to the start of the next winding for delta."))
		elif motor.kind == ThreePhaseMotor.Kind.STAR_DELTA or motor.kind == ThreePhaseMotor.Kind.STANDARD:
			_row(names[i], tr("Winding %s") % std[0], tr("Phase %s for clockwise rotation.") % ["L1", "L2", "L3"][i % 3])
		elif motor.kind == ThreePhaseMotor.Kind.DAHLANDER:
			var low: bool = std.begins_with("1")
			_row(names[i], tr("Low speed (delta)") if low else tr("High speed (double star)"), tr("Phase %s for clockwise rotation.") % ["L1", "L2", "L3"][i % 3])
		else:
			_row(names[i], tr("Winding of speed %s") % std[0], tr("Phase %s for clockwise rotation.") % ["L1", "L2", "L3"][i % 3])
	var plate: PackedStringArray = motor.plate_voltage()
	_data(tr("Rated voltage"), "%s %s, 50 Hz" % [plate[0], plate[1]])
	_data(tr("Rated power"), "%s kW" % _num(motor.rated_power))
	_data(tr("Rated current In"), "%s A" % _num(motor.rated_current))
	var speeds: PackedStringArray = PackedStringArray()
	for rpm: float in motor.rated_speeds():
		speeds.append(_num(roundf(rpm)))
	_data(tr("Rated speed"), "%s min⁻¹" % " / ".join(speeds))
	_data(tr("Power factor cos φ"), _num(motor.power_factor))
	_data(tr("Starting current Ia / In"), _num(motor.start_ratio))
	_data(tr("Run-up time"), "%s s" % _num(motor.run_up_time))
	_data(tr("Coast time / brake time"), "%s s / %s s" % [_num(motor.coast_time), _num(motor.brake_time)])


func _vfd(drive: Vfd) -> void:
	var names: PackedStringArray = _names()
	summary = tr("Frequency inverter for a 3~ motor, 3 x 400 V")
	description.append(tr("Supply 3 x 400 V on L1 L2 L3, the motor on U V W. DI1 runs, DI2 reverses, DI3 runs at the fixed frequency, DI4 stops the output at once (coast stop); the inputs are on with 24 V against DIC, from its own 24V-0V. AI1 takes 0-10 V (from its 10V reference, a PLC or a sensor) for 0 to the maximum frequency. DO2 closes while the motor runs. While simulating, click it for its keypad."))
	features.append(tr("The output frequency follows the target along the ramps; reversing goes through 0 Hz."))
	features.append(tr("V/f: the motor's voltage in proportion to the frequency."))
	features.append(tr("Without all three phases on its supply it does nothing."))
	# Name and function of each terminal, in [constant Vfd.TERMINALS] order.
	var rows: Array[PackedStringArray] = [
		[tr("Supply"), tr("Phase L1 of the supply, 3 x 400 V.")],
		[tr("Supply"), tr("Phase L2 of the supply.")],
		[tr("Supply"), tr("Phase L3 of the supply.")],
		[tr("Protective earth"), tr("Frame of the device; not simulated.")],
		[tr("Reference"), tr("10 V against %s, for a setpoint potentiometer on %s.") % [names[Vfd.ZERO_V], names[Vfd.AI1]]],
		[tr("Setpoint"), tr("0-10 V against %s: 0 Hz up to the maximum frequency.") % names[Vfd.ZERO_V]],
		[tr("0 V"), tr("0 V of the control terminals.")],
		[tr("Run"), tr("ON/OFF1: on runs the motor, off stops it along the ramp.")],
		[tr("Reverse"), tr("On reverses the direction (through 0 Hz).")],
		[tr("Fixed frequency"), tr("On runs at the fixed frequency instead of the setpoint.")],
		[tr("Coast stop"), tr("OFF2: on switches the output off at once; the motor runs down.")],
		[tr("Common"), tr("Common of the digital inputs: they are on with 24 V against it (join it to %s to use the %s supply).") % [names[Vfd.ZERO_V], names[Vfd.SUPPLY_24V]]],
		[tr("24 V"), tr("24 V for the digital inputs, against %s.") % names[Vfd.ZERO_V]],
		[tr("Motor output"), tr("Phase U of the motor.")],
		[tr("Motor output"), tr("Phase V of the motor.")],
		[tr("Motor output"), tr("Phase W of the motor.")],
		[tr("Relay output DO2"), tr("Common of the relay contact.")],
		[tr("Relay output DO2"), tr("NO: closed to %s while the motor runs.") % names[Vfd.DO2C]],
	]
	var groups: Dictionary[int, String] = {0: tr("Supply"), Vfd.REF_10V: tr("Control terminals"), Vfd.U: tr("Motor output"), Vfd.DO2C: tr("Relay output")}
	for i: int in names.size():
		if groups.has(i):
			_heading(groups[i])
		_row(names[i], rows[i][0], rows[i][1])
	_data(tr("Supply"), tr("3 x 400 V, 50 Hz"))
	_data(tr("Output"), tr("3 x 0-400 V, 0-%s Hz (V/f)") % _num(drive.max_frequency))
	_data(tr("Ramp-up / ramp-down time"), "%s s / %s s" % [_num(drive.ramp_up), _num(drive.ramp_down)])
	_data(tr("Fixed frequency, DI3 (Hz)"), _num(drive.fixed_frequency))
	_data(tr("Digital inputs"), tr("on from %s against DIC") % _volts(Vfd.INPUT_THRESHOLD))
	_data(tr("Run and stop"), tr("Terminals (DI1 run, DI2 reverse)") if drive.control == Vfd.Command.TERMINALS else tr("Keypad (I / O)"))
	_data(tr("Setpoint"), tr("Analog input AI1 (0-10 V)") if drive.setpoint == Vfd.Setpoint.ANALOG else tr("Keypad"))


# --- PLC and sensors ---------------------------------------------------------------

func _plc(plc: Plc) -> void:
	var compact: bool = plc is CompactPlc
	var names: PackedStringArray = _names()
	var standard: PackedStringArray = plc.default_terminal_names()
	if compact:
		summary = tr("Compact PLC, 24 V DC, transistor outputs")
		description.append(tr("24 V DC on L+ and M. Inputs are on with 24 V against their common 1M (from 15 V on), the analog inputs AI0 AI1 read 0-10 V against 2M as 0-27648, the transistor outputs switch the output supply 3L+ to their terminal. The program writes them by address: %I0.0, %Q0.0, %IW64."))
	else:
		summary = tr("Logic module with relay outputs")
		if not plc.rating.is_empty():
			summary += ", " + VoltageRating.text(plc.rating)
		description.append(tr("Logic module with relay outputs: supply on L1 and N, inputs I1-I8 on with voltage against N, relay outputs Q1-Q4 each a free contact (Qn.1-Qn.2). Expansion modules clip on to its right, each with its own supply."))
	description.append(tr("It runs its program (function block or ladder diagram; double-click it) whenever an input changes or a timer of the program ends, until the program settles. Losing power resets the program."))
	var heading_module: int = -2
	for i: int in standard.size():
		var m: int = plc.terminal_module(i)
		if m != heading_module and not plc.modules.is_empty():
			heading_module = m
			_heading(tr("CPU") if m < 0 and compact else (tr("PLC") if m < 0 else tr("Module %d: %s") % [m + 2, _module_title(plc.modules[m])]))
		_plc_row(plc, i, names, standard)
	if compact:
		_data(tr("Supply"), "24 V DC")
	elif not plc.rating.is_empty():
		_data(tr("PLC version (supply and inputs)"), VoltageRating.text(plc.rating))
	if not plc.rating.is_empty():
		_data(tr("Inputs on from"), _volts(VoltageRating.input_threshold(plc.rating)))
	_data(tr("Inputs / outputs"), "%d / %d" % [plc.input_count(), plc.output_count()])
	if plc.analog_input_count() + plc.analog_output_count() > 0:
		_data(tr("Analog inputs / outputs"), tr("%d / %d, 0-10 V = 0-%s") % [plc.analog_input_count(), plc.analog_output_count(), _num(plc.full_scale())])
	if compact:
		_data(tr("Output switching"), tr("transistor, %s ms") % _num(CompactPlc.SWITCH_TIME * 1000.0))
	else:
		_data(tr("Output switching"), tr("relay, pick-up %s ms, drop-out %s ms") % [_num(Plc.RELAY_PICK_UP * 1000.0), _num(Plc.RELAY_DROP_OUT * 1000.0)])
	_data(tr("Program"), tr("Ladder diagram (LAD)") if plc.program.language == PlcProgram.Language.LAD else tr("Function block diagram (FBD)"))


func _module_title(module: Plc.Module) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if Plc.MODULE_INPUTS[module] > 0:
		parts.append(tr("%d inputs") % Plc.MODULE_INPUTS[module])
	if Plc.MODULE_OUTPUTS[module] > 0:
		parts.append(tr("%d outputs") % Plc.MODULE_OUTPUTS[module])
	if Plc.MODULE_ANALOG_INPUTS[module] > 0:
		parts.append(tr("%d analog inputs") % Plc.MODULE_ANALOG_INPUTS[module])
	if Plc.MODULE_ANALOG_OUTPUTS[module] > 0:
		parts.append(tr("%d analog outputs") % Plc.MODULE_ANALOG_OUTPUTS[module])
	return ", ".join(parts)


## The row of PLC terminal [param i].
func _plc_row(plc: Plc, i: int, names: PackedStringArray, standard: PackedStringArray) -> void:
	var role: Plc.Role = plc.terminal_role(i)
	var m: int = plc.terminal_module(i)
	var operand: String = ""
	match role:
		Plc.Role.DI:
			var k: int = _index_of(plc.input_count(), func(j: int) -> bool: return plc.input_terminal(j) == i)
			operand = plc.address("I%d" % (k + 1)).trim_prefix("%")
			var text: String = tr("1 while it has voltage against %s.") % names[plc.input_reference(k)]
			var analog: int = _index_of(plc.analog_input_count(), func(j: int) -> bool: return plc.analog_input_terminal(j) == i)
			if analog >= 0:
				text += " " + tr("Also analog input AI%d: 0-10 V = 0-%s.") % [analog + 1, _num(plc.full_scale())]
			_row(names[i], tr("Input %s") % operand, text)
		Plc.Role.DQ:
			var k: int = _index_of(plc.output_count(), func(j: int) -> bool: return plc.output_terminal(j) == i or plc.output_terminal(j) + 1 == i)
			var first: int = plc.output_terminal(k)
			var other: String = names[first + 1] if i == first else names[first]
			_row(names[i], tr("Relay output Q%d") % (k + 1), tr("Free contact: closed to %s while the program sets Q%d.") % [other, k + 1])
		Plc.Role.TQ:
			var k: int = _index_of(plc.output_count(), func(j: int) -> bool: return plc.output_terminal(j) == i)
			operand = plc.address("Q%d" % (k + 1)).trim_prefix("%")
			_row(names[i], tr("Output %s") % operand, tr("Transistor output: switched to the output supply while the program sets it."))
		Plc.Role.AI:
			var k: int = _index_of(plc.analog_input_count(), func(j: int) -> bool: return plc.analog_input_terminal(j) == i)
			operand = plc.address("AI%d" % (k + 1)).trim_prefix("%")
			_row(names[i], tr("Analog input %s") % operand, tr("0-10 V = 0-%s in the program.") % _num(plc.full_scale()))
		Plc.Role.AQ:
			var k: int = _index_of(plc.analog_output_count(), func(j: int) -> bool: return plc.analog_output_terminal(j) == i)
			operand = plc.address("AQ%d" % (k + 1)).trim_prefix("%")
			_row(names[i], tr("Analog output %s") % operand, tr("0-10 V for 0-%s in the program; 0 V while it does not work.") % _num(plc.full_scale()))
		_:
			_row(names[i], tr("Supply"), _plc_supply_text(plc, i, m, standard[i]))


## What supply terminal [param i] ([param std] its standard name) of module
## [param m] is.
func _plc_supply_text(plc: Plc, i: int, m: int, std: String) -> String:
	if plc is CompactPlc:
		if std == "L+":
			return tr("+24 V DC supply of the CPU.")
		if std == "M":
			return tr("0 V of the CPU supply.")
		if std.ends_with("1M"):
			return tr("Common of the inputs: they are on with 24 V against it.")
		if std.ends_with("2M"):
			return tr("Reference of the analog inputs.")
		if plc.terminal_on_bottom(i):
			return tr("+24 V supply of the transistor outputs.") if std.ends_with("L+") else tr("0 V of the output supply.")
		return tr("+24 V DC supply of the analog module.") if std.ends_with("L+") else tr("0 V of the analog module, reference of its values.")
	var first: int = 0 if m < 0 else plc.module_supply(m)
	if i == first:
		return tr("Supply of the PLC (%s).") % VoltageRating.text(plc.rating) if m < 0 else tr("Supply of module %d (%s); it works only together with the PLC.") % [m + 2, VoltageRating.text(plc.module_rating(m))]
	return tr("Other supply terminal; the inputs of the PLC are on against it.") if m < 0 else tr("Other supply terminal of module %d; its inputs are on against it.") % (m + 2)


## First j below [param count] for which [param test] holds, or -1.
static func _index_of(count: int, test: Callable) -> int:
	for j: int in count:
		if test.call(j):
			return j
	return -1


func _sensor(sensor: TemperatureSensor) -> void:
	var names: PackedStringArray = _names()
	summary = tr("Temperature transmitter, output 0-10 V")
	description.append(tr("Supply 24 V DC on L+ and M; puts 0-10 V on U against M over its range. While simulating, click it to set the temperature."))
	_row(names[0], tr("Supply"), tr("+24 V DC against %s.") % names[1])
	_row(names[1], tr("Supply, reference"), tr("0 V of the supply and the reference of the output."))
	_row(names[2], tr("Output"), tr("0 V at %s °C up to 10 V at %s °C, against %s.") % [_num(sensor.range_min), _num(sensor.range_max), names[1]])
	_data(tr("Supply"), "24 V DC")
	_data(tr("Measuring range"), "%s … %s °C" % [_num(sensor.range_min), _num(sensor.range_max)])
	_data(tr("Output"), tr("0-10 V, held within it"))
	_data(tr("Current drawn"), "%s mA" % _num(TemperatureSensor.DRAW * 1000.0))
