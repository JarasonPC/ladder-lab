class_name TrainingFunction
extends RefCounted
## Whether a training plan wired by the student works as its schematic does
## (the check of a plan that tests the function, see
## [member TrainingPlan.check_function]): the schematic and the student's
## wiring ([TrainingSim]) are simulated side by side, every breaker and fuse
## holder switched on, then every push button pressed and let go and every
## switch turned in turn, twice over (a circuit started in the first round
## is stopped in the second); after each step, and again once its time
## relays had time, what works (coils, time relays, lamps and other loads,
## motors with power) and what tripped must be the same in both. Accepts
## any wiring that works, not only the schematic's. No nodes.

## Simulated seconds given to time relays after each step.
const SETTLE_TIME: float = 60.0
## Rounds over all the buttons and switches.
const ROUNDS: int = 2


## The first difference between [param doc]'s schematic and the student's
## wiring of its plan, as a problem of [method TrainingCheck.run]
## ({"kind": "function", "text", "args", "ports": []}); {} when they work alike.
static func run(doc: SchematicDocument) -> Dictionary:
	var drawn: SchematicDocument = _switched_on(DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc)))
	var wired: SchematicDocument = _switched_on(TrainingSim.build(doc))
	var a: Simulator = Simulator.new(drawn.circuit)
	var b: Simulator = Simulator.new(wired.circuit)
	var difference: Dictionary = _compare(a, b, drawn, wired, TranslationServer.translate("switching on the breakers"))
	if not difference.is_empty():
		return difference
	var operators: Array[CircuitComponent] = []
	for c: CircuitComponent in drawn.circuit.get_components():
		if (c is PushButton or c is LatchingSwitch or c is CamSwitch) and drawn.circuit.get_operator(c.designation) == c and not operators.has(c):
			operators.append(c)
	for round: int in ROUNDS:
		for c: CircuitComponent in operators:
			var other: CircuitComponent = wired.circuit.get_operator(c.designation)
			if other == null:
				continue
			if c is PushButton:
				(c as PushButton).press()
				(other as PushButton).press()
				difference = _compare(a, b, drawn, wired, TranslationServer.translate("pressing -%s") % c.designation)
				if not difference.is_empty():
					return difference
				(c as PushButton).release()
				(other as PushButton).release()
				difference = _compare(a, b, drawn, wired, TranslationServer.translate("letting go of -%s") % c.designation)
			elif c is LatchingSwitch:
				(c as LatchingSwitch).toggle()
				(other as LatchingSwitch).toggle()
				difference = _compare(a, b, drawn, wired, TranslationServer.translate("turning -%s") % c.designation)
			else:
				(c as CamSwitch).step_on()
				(other as CamSwitch).step_on()
				difference = _compare(a, b, drawn, wired, TranslationServer.translate("turning -%s") % c.designation)
			if not difference.is_empty():
				return difference
	return {}


static func _switched_on(doc: SchematicDocument) -> SchematicDocument:
	for c: CircuitComponent in doc.circuit.get_components():
		if c is CircuitBreaker:
			(c as CircuitBreaker).switched_on = true
		elif c is MotorBreaker:
			(c as MotorBreaker).switched_on = true
		elif c is Fuse:
			(c as Fuse).switched_on = true
		elif c is ThreePoleFuse:
			(c as ThreePoleFuse).switched_on = true
	return doc


## Steps both simulations, now and once their time relays had time, and
## compares them; the difference after [param action] ({} for none).
static func _compare(a: Simulator, b: Simulator, drawn: SchematicDocument, wired: SchematicDocument, action: String) -> Dictionary:
	for delta: float in [0.0, SETTLE_TIME]:
		a.step(delta)
		b.step(delta)
		var expected: Dictionary[String, String] = _state(drawn.circuit)
		var got: Dictionary[String, String] = _state(wired.circuit)
		var keys: Array = expected.keys()
		for key: String in got:
			if not keys.has(key):
				keys.append(key)
		for key: String in keys:
			if expected.has(key) == got.has(key):
				continue
			var what: String = expected.get(key, got.get(key, ""))
			var text: String = "After %s, %s does not %s as the schematic does." if expected.has(key) else "After %s, %s does %s, which the schematic does not."
			return {"kind": "function", "text": text, "args": [action, "-" + key.get_slice("|", 0), TranslationServer.translate(what)], "ports": PackedStringArray()}
	return {}


## What works in [param circuit]: "designation|what" -> what it does
## (English: "pull in", "light", "run", "work", "trip").
static func _state(circuit: Circuit) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for c: CircuitComponent in circuit.get_components():
		var what: String = ""
		if c is Coil and (c as Coil).energized:
			what = "pull in"
		elif c is Lamp and (c as Lamp).energized:
			what = "light"
		elif c is Load and (c as Load).energized:
			what = "work"
		elif c is ThreePhaseMotor and (c as ThreePhaseMotor).ac_powered:
			what = "run"
		elif (c is ProtectiveDevice and (c as ProtectiveDevice).tripped) or (c is MotorBreaker and (c as MotorBreaker).tripped) or (c is ThreePoleFuse and (c as ThreePoleFuse).any_blown()):
			what = "trip"
		if not what.is_empty():
			result[c.designation + "|" + what] = what
	return result
