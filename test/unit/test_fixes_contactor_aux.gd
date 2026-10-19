extends GutTest
## Contactors with more auxiliary contacts than they and the block on their
## front hold: every contact goes on an auxiliary contact block mounted on
## the contactor's side, is drawn and wired, with or without an overload
## relay under the contactor.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC


func _add(doc: SchematicDocument, c: CircuitComponent) -> CircuitComponent:
	var n: int = doc.circuit.get_components().size()
	doc.add(c, Vector2i(4 + (n % 12) * 8, 4 + (n / 12) * 14))
	return c


## A lamp outside on strip terminal [param label], from [param from] to N.
func _lamp(doc: SchematicDocument, name: String, from: String, label: String) -> void:
	var lamp: Lamp = _add(doc, Lamp.new(name)) as Lamp
	doc.connect_terminals(from, name + ":X1")
	doc.connect_terminals(name + ":X2", "N")
	doc.set_strip_terminal(lamp.id, 0, label)


## Contactor KM1 with auxiliary contacts taking [param places] places in
## turn NO, NC, changeover (an NC and an NO place), delayed NO, delayed NC,
## each fed from FA1 and leading to a lamp outside; with [param overload]
## the overload relay F1 under it.
func _contactor(places: int, overload: bool, poles: int = 3) -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("aux")
	for s: Array in [["L1", PowerSupply.Conductor.L], ["L2", PowerSupply.Conductor.L2], ["L3", PowerSupply.Conductor.L3], ["N", PowerSupply.Conductor.N]]:
		_add(doc, PowerSupply.new(s[0], s[1]))
	_add(doc, CircuitBreaker.new("FA1"))
	doc.connect_terminals("L1", "FA1:1")
	_add(doc, Coil.new("KM1"))
	var mains: MainContacts = MainContacts.new("KM1")
	mains.poles = poles
	_add(doc, mains)
	doc.connect_terminals("FA1:2", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N")
	for k: int in 3:
		doc.connect_terminals(["L1", "L2", "L3"][k], "KM1:%d" % (2 * k + 1))
	var used: int = 0
	var s: int = 1
	while used < places:
		var kind: int = (s - 1) % 5
		if kind == 2 and places - used >= 2:
			_add(doc, ChangeoverContact.new("KM1", s))
			doc.connect_terminals("FA1:2", "KM1:%d1" % s)
			_lamp(doc, "H%d" % s, "KM1:%d4" % s, str(s))
			_lamp(doc, "G%d" % s, "KM1:%d2" % s, "%d2" % s)
			used += 2
		else:
			var c: Contact = _add(doc, Contact.new("KM1", NC if kind == 1 or kind == 4 else NO, s, kind >= 3)) as Contact
			doc.connect_terminals("FA1:2", c.get_terminal_keys()[0])
			_lamp(doc, "H%d" % s, c.get_terminal_keys()[1], str(s))
			used += 1
		s += 1
	if overload:
		_add(doc, OverloadRelay.new("F1", 5.0, 3))
		_add(doc, OverloadContact.new("F1", NC))
		doc.connect_terminals("FA1:2", "F1:95")
		_lamp(doc, "H95", "F1:96", "95")
		for k: int in 3:
			doc.connect_terminals("KM1:%d" % (2 * k + 2), "F1:%d" % (2 * k + 1))
	doc.add_switchboard()
	doc.fill_cabinet(0)
	return doc


func _contactor_place(layout: CabinetLayout) -> Dictionary:
	for place: Dictionary in layout.places:
		if place["designation"] == "KM1":
			return place
	return {}


## Contact terminals of KM1 no wire ends at.
func _unwired(doc: SchematicDocument) -> PackedStringArray:
	var wiring: CabinetWiring = CabinetWiring.build(doc, CabinetLayout.build(doc, 4.0), 4.0)
	var wired: Dictionary[String, bool] = {}
	for wire: Dictionary in wiring.wires:
		wired[wire["from"]] = true
		wired[wire["to"]] = true
	var result: PackedStringArray = PackedStringArray()
	for c: CircuitComponent in CabinetDevices.contacts_of(doc.circuit, "KM1"):
		for key: String in c.get_terminal_keys():
			if not wired.has(key):
				result.append(key)
	return result


## Wires passing over a screw of a contactor or overload relay they do not
## end at: "wire over device:terminal".
func _over_screws(doc: SchematicDocument) -> PackedStringArray:
	var layout: CabinetLayout = CabinetLayout.build(doc, 4.0)
	var wiring: CabinetWiring = CabinetWiring.build(doc, layout, 4.0)
	var screws: Array[Dictionary] = []
	for place: Dictionary in layout.places:
		var sets: Array = [[place["kind"], place["desc"], place["origin"], place["designation"]]]
		if place.has("under_origin"):
			sets.append([CabinetDevices.Kind.OVERLOAD, place["under_desc"], place["under_origin"], place["under_designation"]])
		for set: Array in sets:
			if set[0] != CabinetDevices.Kind.CONTACTOR and set[0] != CabinetDevices.Kind.OVERLOAD:
				continue
			var terminals: Dictionary = (set[1] as Dictionary).get("terminals", {})
			var points: Dictionary = CabinetParts.terminal_points(set[0], set[1])
			for name: String in points:
				var p: Vector3 = points[name]
				screws.append({"at": set[2] + Vector2(p.x, p.y), "r": p.z, "key": terminals.get(name, ""), "name": "%s:%s" % [set[3], name]})
	var result: PackedStringArray = PackedStringArray()
	for wire: Dictionary in wiring.wires:
		var path: PackedVector2Array = wire["points"]
		for screw: Dictionary in screws:
			if screw["key"] == wire["from"] or screw["key"] == wire["to"]:
				continue
			for i: int in path.size() - 1:
				var at: Vector2 = screw["at"]
				if at.distance_to(Geometry2D.get_closest_point_to_segment(at, path[i], path[i + 1])) < screw["r"] + wire["width"] * 0.5 - 0.3:
					result.append("%s-%s over %s" % [wire["from"], wire["to"], screw["name"]])
					break
	return result


func test_every_auxiliary_contact_has_a_place_on_the_contactor() -> void:
	for places: int in [8, 10, 12]:
		var doc: SchematicDocument = _contactor(places, false)
		var desc: Dictionary = CabinetDevices.describe(doc, "KM1")
		var aux: Array = desc["aux"]
		assert_eq(aux.size(), places, "%d: every contact has a place, the changeover contacts two" % places)
		assert_false(desc.has("left_out"), "nothing is left out")
		var blocks: int = ceili((places - 6) / 2.0)
		assert_eq(CabinetParts.side_blocks(places).size(), blocks, "%d: two contacts to a side block" % places)
		assert_eq(CabinetParts.device_size(desc), CabinetParts.CONTACTOR + Vector2(CabinetParts.SIDE_BLOCK_W * blocks, 0.0))
		var points: Dictionary = CabinetParts.terminal_points(CabinetDevices.Kind.CONTACTOR, desc)
		for c: Array in aux:
			assert_true(points.has(c[0]) and points.has(c[2]), "%d: %s-%s has its screws" % [places, c[0], c[2]])
		# No two screws of the contactor and its blocks overlap, all within
		# its drawing.
		var size: Vector2 = CabinetParts.device_size(desc)
		var names: Array = points.keys()
		for i: int in names.size():
			var a: Vector3 = points[names[i]]
			assert_true(Rect2(Vector2.ZERO, size).grow(-a.z + 0.3).has_point(Vector2(a.x, a.y)), "%d: screw %s within the drawing" % [places, names[i]])
			for j: int in range(i + 1, names.size()):
				var b: Vector3 = points[names[j]]
				assert_true(Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)) >= a.z + b.z, "%d: screws %s and %s apart" % [places, names[i], names[j]])


func test_side_blocks_one_on_each_side_then_stacked() -> void:
	var left: float = CabinetParts.contactor_left(12)
	assert_eq(left, CabinetParts.SIDE_BLOCK_W, "of three blocks one goes on the left")
	assert_eq(CabinetParts.side_blocks(12), [left + CabinetParts.CONTACTOR.x, 0.0, left + CabinetParts.CONTACTOR.x + CabinetParts.SIDE_BLOCK_W] as Array[float], "right, left, then outside the right one")
	assert_eq(CabinetParts.side_blocks(6), [] as Array[float], "six fit on the contactor and its front block")


func test_every_contact_terminal_is_wired() -> void:
	for places: int in [8, 10, 12]:
		for overload: bool in [false, true]:
			var doc: SchematicDocument = _contactor(places, overload)
			assert_eq(_unwired(doc), PackedStringArray(), "%d contacts%s" % [places, " over an overload relay" if overload else ""])
	assert_eq(_unwired(_contactor(12, true, 4)), PackedStringArray(), "four poles")


func test_places_do_not_overlap() -> void:
	for places: int in [8, 10, 12]:
		for overload: bool in [false, true]:
			var doc: SchematicDocument = _contactor(places, overload)
			var layout: CabinetLayout = CabinetLayout.build(doc, 4.0)
			# What each place takes: its drawing, the overload relay under it
			# and the labels (a contactor's label lies on its own front).
			var rects: Array[Rect2] = []
			var owners: Array[int] = []
			for p: int in layout.places.size():
				var place: Dictionary = layout.places[p]
				var taken: Array[Rect2] = [place["rect"]]
				if place.has("under_rect"):
					taken.append(place["under_rect"])
					taken.append(Rect2(place["under_label_at"] - Vector2(6.0, 2.6), Vector2(12.0, 5.2)))
				if place["label_w"] > 0.0:
					taken.append(Rect2(place["label_at"] - Vector2(place["label_w"] * 0.5, 2.6), Vector2(place["label_w"], 5.2)))
				for r: Rect2 in taken:
					rects.append(r)
					owners.append(p)
			for i: int in rects.size():
				for j: int in range(i + 1, rects.size()):
					if owners[i] != owners[j]:
						assert_false(rects[i].grow(-0.05).intersects(rects[j]), "%d: %s and %s apart" % [places, rects[i], rects[j]])
			# The places on a rail side by side, the side blocks within the
			# contactor's.
			var contactor: Dictionary = _contactor_place(layout)
			var desc: Dictionary = contactor["desc"]
			var drawing: Rect2 = Rect2(contactor["origin"], CabinetParts.device_size(desc))
			for x: float in CabinetParts.side_blocks(places):
				assert_true(drawing.encloses(Rect2(contactor["origin"] + Vector2(x, 0.0), Vector2(CabinetParts.SIDE_BLOCK_W, CabinetParts.CONTACTOR.y))), "%d: side block at %.1f within the place" % [places, x])
			assert_eq(contactor["rect"], drawing)
			var place: Dictionary = _contactor_place(layout)
			if overload:
				# The overload relay sits under the contactor itself, between
				# its side blocks.
				var left: float = CabinetParts.contactor_left(places)
				assert_eq(place["under_origin"].x, place["origin"].x + left, "%d: under the contactor" % places)
				assert_almost_eq(float(place["label_at"].x), place["under_rect"].get_center().x, 0.3, "%d: the label stays on the contactor's front" % places)


func test_no_wire_runs_over_a_screw_it_does_not_end_at() -> void:
	for places: int in [8, 10, 12]:
		for overload: bool in [false, true]:
			assert_eq(_over_screws(_contactor(places, overload)), PackedStringArray(), "%d contacts%s" % [places, " over an overload relay" if overload else ""])
	assert_eq(_over_screws(_contactor(12, true, 4)), PackedStringArray(), "four poles")


func test_tooltip_names_no_contacts_left_out() -> void:
	var view: CabinetView = CabinetView.new()
	view.document = _contactor(12, false)
	view.size = Vector2(800, 600)
	add_child_autofree(view)
	var layout: CabinetLayout = view.get("_layout")
	var place: Dictionary = _contactor_place(layout)
	var k: float = view.drawn_size().x / layout.size.x
	var at: Vector2 = view.call("_origin") + (place["rect"] as Rect2).get_center() * k
	var tip: String = view.call("_get_tooltip", at)
	assert_true(tip.ends_with("-KM1"), "the contactor alone: " + tip)
