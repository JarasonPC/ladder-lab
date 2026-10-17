extends RefCounted
## Built-in examples ready to simulate: their circuit breakers and fuse
## holders start switched off, as on a real switchboard; tests switch them on.


## Switches on every breaker and fuse holder of [param doc]; returns it.
static func on(doc: SchematicDocument) -> SchematicDocument:
	for c: CircuitComponent in doc.circuit.get_components():
		if c is CircuitBreaker:
			(c as CircuitBreaker).switched_on = true
		elif c is MotorBreaker:
			(c as MotorBreaker).switched_on = true
	return doc
