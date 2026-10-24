class_name InstructionsReport
extends ReportRows
## The operating and maintenance instructions of a switchboard (pokyny pro
## obsluhu a údržbu rozváděče nn) as rows for the export ([ReportSheet]): a
## fixed text in ten parts naming the switchboard maker ([Manufacturer]),
## its technical data as given ([BoardDocumentation], the rated diversity
## factor and ambient temperature of its temperature rise calculation), and
## how to operate the protective devices it has: the main switch, circuit
## breakers, residual current devices and arc fault detection devices, each
## part only when the switchboard has one, then its other devices; what is
## not given yet is listed at the end. No nodes.

## The documentation fields the instructions write (see [constant
## BoardDocumentation.CHARACTERISTICS]).
const USED: PackedStringArray = ["assembly", "board_type", "material", "original_maker", "un", "fn", "earthing", "pollution", "ip", "protection_class", "service", "rdf"]


## What switchboard [param b] of [param doc] has of the protective devices
## the instructions explain: {"main" (the main switch: a house's on the
## consumer unit, a cam switch on the door), "breakers", "rcds", "afdds",
## "others"}, each the designations ("-FA1"), in rail order.
static func devices(doc: SchematicDocument, b: int) -> Dictionary:
	var found: Dictionary = {"main": PackedStringArray(), "breakers": PackedStringArray(), "rcds": PackedStringArray(), "afdds": PackedStringArray(), "others": PackedStringArray()}
	var board: Switchboard = doc.switchboards[b]
	if HeatRise.is_unit(doc, b):
		for c: CircuitComponent in doc.circuit.get_components():
			if SingleLine.is_main(c) and not found["main"].has("-" + c.designation):
				found["main"].append("-" + c.designation)
	var on_door: Dictionary[String, bool] = {}
	for item: ControlBoxItem in board.door.items:
		on_door[item.designation] = true
	for c: CircuitComponent in doc.circuit.get_components():
		if c is CamSwitch and on_door.has(c.designation) and not found["main"].has("-" + c.designation):
			found["main"].append("-" + c.designation)
	for rail: CabinetRail in board.rails:
		for item: CabinetItem in rail.items:
			if item.kind != CabinetItem.Kind.DEVICE:
				continue
			var c: CircuitComponent = CabinetDevices.device(doc.circuit, item.designation)
			if c == null:
				continue
			var designation: String = "-" + item.designation
			if c is ArcFaultDevice:
				found["afdds"].append(designation)
			elif c is ResidualCurrentDevice:
				found["rcds"].append(designation)
				if (c as ResidualCurrentDevice).overcurrent:
					found["breakers"].append(designation)
			elif c is CircuitBreaker or c is MotorBreaker:
				found["breakers"].append(designation)
			elif CabinetDevices.kind_of(c) != CabinetDevices.Kind.FUSE:
				found["others"].append(designation)
	return found


## The rows of switchboard [param b] of [param doc]; [param source] says
## what it was exported from (see [method source_text]).
func rows(doc: SchematicDocument, b: int, source: String = "") -> Array[Dictionary]:
	_rows = []
	_table = 0
	var board: Switchboard = doc.switchboards[b]
	var maker: String = Manufacturer.shown_name() if not Manufacturer.shown_name().is_empty() else "…………………"
	var found: Dictionary = devices(doc, b)
	var standards: String = "ČSN EN 61439-1 ed. 3" + (", " + BoardDocumentation.standard(board) if not BoardDocumentation.standard(board).is_empty() else "")
	_add({"type": "title", "text": tr("Operating and maintenance instructions of switchboard +%s") % board.name + ("  ·  " + board.title if not board.title.is_empty() else "")})
	if not InterfaceReport.kind_text(board).is_empty():
		_text(InterfaceReport.kind_text(board), false)
	_text(tr("Following these instructions is necessary for the product to work properly within the meaning of Act No. 90/2016 Coll. and Act No. 22/1997 Coll."), false)
	if not source.is_empty():
		_text(source, true)
	_gap()
	if not Manufacturer.shown_name().is_empty():
		_text(Manufacturer.shown_name(), false)
	for pair: Array in [["phone", tr("Phone: %s")], ["email", tr("E-mail: %s")], ["web", tr("Web: %s")]]:
		if not Manufacturer.value(pair[0]).is_empty():
			_text(pair[1] % Manufacturer.value(pair[0]), false)
	_heading(tr("I. General"))
	_text(tr("These operating instructions are intended for switchboards made by %s.") % maker, false)
	_text(tr("For the sake of clarity these instructions do not contain all the detailed information about all types of products. The details of the technical design and equipment are given in the documentation. Switchboards are subject to constant technical improvement in the course of technical progress. Changes are reserved. Following these instructions is necessary for the product to work properly."), false)
	_text(tr("The switchboards are intended for distributing electric energy and supplying electrical equipment."), false)
	_text(tr("If you wish further information, or situations arise that these instructions do not describe in enough detail, ask for the information you need by phone or e-mail."), false)
	_text(tr("A declaration of conformity has been drawn up for the products under § 12 of Act No. 22/1997 Coll., Title III of Act No. 90/2016 Coll. and Government Regulation No. 118/2016 Coll."), false)
	_heading(tr("II. Construction and description of the switchboard"))
	_text(tr("The switchboard is made in accordance with %s and the technical documentation attached. Its construction, function and purpose are fully evident from it. Using it for other purposes is not permitted.") % standards, false)
	_heading(tr("III. Design"))
	_text(tr("The distribution boards are made of plastic or sheet steel according to the type required, by ABB, Eaton, Hager, Famatel, Schneider Electric, OEZ and others, with a degree of protection of at least IP 30 and protection class I or II."), false)
	var this: PackedStringArray = PackedStringArray()
	for key: String in ["board_type", "material", "original_maker", "ip", "protection_class"]:
		var value: String = BoardDocumentation.shown(board, key)
		if not value.is_empty():
			this.append("%s: %s" % [tr(BoardDocumentation.field(key)["title"]), value])
	if not this.is_empty():
		_text(tr("This switchboard: %s.") % "; ".join(this), false)
	_heading(tr("IV. Equipment"))
	_text(tr("The devices fitted are as the project gives them. Only branded devices are used. All the components (materials and devices) used to make the switchboard can withstand the mechanical, electrical and thermal stresses and the effects of humidity that occur in normal service. Built-in devices and components without electronic circuits are not sensitive to electromagnetic disturbances. Built-in devices and components with electronic circuits meet the EMC requirements (ČSN EN 61000-1-2) under Government Regulation No. 117/2016 Coll."), false)
	# The technical data as given.
	_heading(tr("V. Technical data"))
	var widths: Array[float] = [0.4, 0.6]
	var align: Array = ["l", "l"]
	_table_head([tr("Item"), tr("Value")], widths, align, true)
	var system: PackedStringArray = PackedStringArray()
	for key: String in ["earthing", "fn", "un"]:
		if not BoardDocumentation.shown(board, key).is_empty():
			system.append(BoardDocumentation.shown(board, key))
	_table_row([tr("Voltage system"), ", ".join(system) if not system.is_empty() else tr("not given")], widths, align, false, true)
	_table_row([tr("Protection against electric shock"), tr("automatic disconnection of supply (MCB)") if not found["breakers"].is_empty() else tr("automatic disconnection of supply")], widths, align, false, true)
	if not found["rcds"].is_empty():
		_table_row([tr("Additional protection"), tr("residual current device RCD (FI)")], widths, align, false, true)
	_table_row([tr("Recommended additional protection"), tr("arc fault detection device AFDD, surge protective device SPD")], widths, align, false, true)
	_table_row([tr("Working conditions indoors"), tr("−5 to +40 °C, relative humidity 90 % at +20 °C, average +35 °C over 24 h")], widths, align, false, true)
	var heat: Dictionary = HeatRise.settings(board.heat)
	if heat.has("ambient"):
		_table_row([tr("Ambient temperature (temperature rise calculation)"), "%s °C" % _n(heat["ambient"], 1)], widths, align, false, true)
	for key: String in ["service", "pollution", "ip", "rdf"]:
		var value: String = BoardDocumentation.shown(board, key)
		_table_row([tr(BoardDocumentation.field(key)["title"]), value if not value.is_empty() else tr("not given")], widths, align, false, true)
	_table_row([tr("Ratings"), tr("given on the switchboard's rating plate and in the documentation supplied with it")], widths, align, false, true)
	_heading(tr("VI. Safety measures for work and operation"))
	_text(tr("Operating the switchboard means the actions connected with its service, e.g. inspection, cleaning, switching a circuit breaker on or off, pressing a button, watching the signal lamps and the like. Where personal protective equipment is prescribed for operation, it must be used. The person maintaining the switchboard must be professionally qualified within the meaning of § 19 of Act No. 250/2021 Coll. Persons without electrical qualification – ordinary persons – must not work on switchboards; they may only operate switchboards accessible to ordinary persons that are part of the fixed electrical installation. Under ČSN 33 1310 ed. 2:2009, instruction in the correct and safe use of the electrical installation including its distribution boards and switchboards is given by the person who made the installation or a person authorised by them. Once instructed, ordinary persons use the equipment but do not interfere with it."), false)
	# The protective devices it has, lettered in turn.
	_heading(tr("VII. Operating the protective devices in the switchboard"))
	var parts: Array[Array] = [
		["main", "Main switch", ["The main switch is meant only for switching off or on, most often the whole switchboard. It never trips by itself. At first sight, though, it looks like a circuit breaker. It should be labelled \"Main switch\". If the main switch is off, check that nobody is working on the electrical equipment!"]],
		["breakers", "Circuit breaker", ["You can switch a circuit breaker on by lifting its lever up, or first pressing the lever down and then lifting it up. If the circuit breaker trips again, though, there is a fault somewhere in the circuit. Do not switch it on again; call an expert with professional qualification. Bear in mind that a circuit breaker does not trip by itself. Its tripping protects the circuit against electric shock or fire."]],
		["rcds", "Residual current device (RCD)", ["A residual current device is a somewhat more complex device than a circuit breaker, and it can trip for many reasons, not all of them dangerous to life. If you switch it on (as a circuit breaker) and it does not trip again, all is well. If it trips again, unplug all the appliances from the socket outlets it feeds. Switch it on. Plugging the appliances in one after another tells you which one is faulty. Even so, the fault need not lie in the appliance itself: it may be a fire starting somewhere at a pinched cord, or simply many appliances with large residual currents on one socket circuit. An expert or an inspection technician will find the exact cause.",
			"Residual current devices must be tested regularly at the intervals their maker gives. Usually every 6 months, check that the residual current device works by pressing the test button on the device itself. The residual current device must trip at once. If it does not, call an expert!"]],
		["afdds", "Arc fault detection device with breaker (AFDD)", ["Arc fault detection devices protect against fires breaking out. An arc fault detection device fills the functional gap of today's protective devices – circuit breakers, residual current devices and fuses – and lessens the effects of a fault arc by disconnecting the circuit. It has a self-test that starts automatically every 15 hours to test the circuits and the detection algorithm. It can also be tested by hand by pressing the test button on its front. The status LED on the front of the device (which also serves as the test button) gives simple and clear information on why it tripped on devices made by OEZ.",
			"Devices made by Eaton give more detailed diagnostics."]],
		["others", "Other devices", ["Other devices include installation contactors for switching e.g. underfloor heating, control and time relays, energy meters, time switches and other equipment. For a description of their function or a possible fault, see their maker's documentation, or call the maker of your switchboard."]],
	]
	var letter: int = 0
	for part: Array in parts:
		var designations: PackedStringArray = found[part[0]]
		if designations.is_empty():
			continue
		_heading("%s. %s" % [char("a".unicode_at(0) + letter), tr(part[1])])
		letter += 1
		for paragraph: String in part[2]:
			_text(tr(paragraph), false)
		_text(tr("In this switchboard: %s") % PartsList.designations(designations), true)
	if letter == 0:
		_text(tr("The switchboard has none of these devices."), true)
	_heading(tr("VIII. Maintenance"))
	_text(tr("Safe and correct operation of the switchboard requires that it is operated and maintained in accordance with the standards and regulations in force, the requirements of the suppliers of the individual devices and these instructions. The maintenance needed is minimal, focused on: regular checks of the power connections and the connections of the protective conductors, visual inspections, checks of the heating of the connections and of the temperature rise inside the switchboard. Excessive heating and exceeding the operating temperature inside the switchboard can shorten the life of the devices, or even lead to a fire in the switchboard. Safe operation means having a specialist firm (preferably the switchboard's maker) check the switchboard once every five years, above all to remove dirt and dust, inspect it visually and then tighten all connections, and replace any faulty parts at once. Only a person with electrical qualification, the switchboard's maker or an inspection technician may carry out this check."), false)
	_text(tr("The switchboard is designed for a certain operating temperature (see the technical data). The operator must therefore keep the ambient temperature within the limits prescribed. The safety signs and safety marking must be checked and renewed (after the ČSN ISO 3864 series of standards in force)."), false)
	_text(tr("The owner of the switchboard should have the electrical installation inspected regularly after ČSN 33 1500/Z3/4.2004 annex 2, at intervals by the environment (usually every five years)."), false)
	_heading(tr("IX. Disposal"))
	_text(tr("The cardboard packaging is fully recyclable and can be used as a secondary raw material. The protective packaging of PE film is not biodegradable. The switchboard as a whole should last as long as the electrical installation, in practice about 30 years. The product or its components must be handed over for recycling or disposed of in an environmentally friendly way in accordance with the laws and regulations in force."), false)
	_heading(tr("X. Conclusion and special arrangements"))
	_text(tr("It is forbidden to interfere with the construction and wiring of the switchboard without the consent of the designer and the maker (e.g. to replace circuit breakers with others of different ratings, replace devices, remove protective covers, blanking plates etc.)."), false)
	_text(tr("For the switchboard to work safely and without faults, the provisions of these instructions must be followed. Breaking them ends the warranty of the switchboard. Nor does the warranty cover protective elements (e.g. fuses) or parts of the working equipment worn by natural wear. If individual components of the switchboard stop working, contact the maker of the equipment at once. If any component in the switchboard is replaced by a firm other than %s – the switchboard's maker, the new maker – the installing firm – takes over all responsibility and must draw up new documentation of the switchboard including a new temperature rise calculation, as it becomes the switchboard's new maker (ČSN EN 61439-1 ed. 3). The original documentation supplied with this switchboard becomes invalid! The switchboard's maker is not responsible for mechanical and electrical damage to components caused by unskilled handling of the equipment or unskilled connection of the equipment.") % maker, false)
	_heading(tr("Notes"))
	for i: int in 4:
		_text("……………………………………………………………………………………………………………………………………", true)
	var gaps: PackedStringArray = PackedStringArray()
	for title: String in Manufacturer.missing():
		gaps.append(tr("%s (Settings > Switchboard manufacturer…)") % tr(title))
	for key: String in USED:
		if BoardDocumentation.shown(board, key).is_empty():
			gaps.append((tr("%s (Temperature rise…)") if key == "rdf" else tr("%s (Documentation…)")) % tr(BoardDocumentation.field(key)["title"]))
	if not gaps.is_empty():
		_heading(tr("Still to give"))
		for gap: String in gaps:
			_text("• " + gap, false)
	return _rows
