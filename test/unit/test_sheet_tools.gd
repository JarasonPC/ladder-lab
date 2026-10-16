extends GutTest
## Current path numbering, circuit check and clipboard.

const NO := SwitchingElement.ContactType.NO
const NC := SwitchingElement.ContactType.NC


func test_current_paths_vertical_and_horizontal() -> void:
	var doc: SchematicDocument = ExampleCircuits.self_holding()
	assert_eq(doc.current_paths(), PackedFloat32Array([5.0, 8.0, 12.0]), "SB0, SB1 and KM1 share path 1")
	doc.transpose()
	assert_eq(doc.current_paths().size(), 3, "rows when horizontal")


func test_check_finds_problems() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(Contact.new("K9", NO, 1), Vector2i(3, 1))
	doc.add(Coil.new("KM1"), Vector2i(6, 1))
	doc.add(TimerRelay.new("KT1", TimerRelay.Mode.ON_DELAY, 1.0), Vector2i(9, 1))
	doc.add(Contact.new("KM1", NO, 1, true), Vector2i(12, 1))
	doc.add(Contact.new("KT1", NO, 1, true), Vector2i(15, 1))
	doc.connect_terminals("L", "K9:13")
	var texts: PackedStringArray = PackedStringArray()
	for issue: Dictionary in CircuitCheck.run(doc):
		texts.append(issue["text"] % issue["args"])
	assert_has(texts, "Contact K9:13-14 has no coil K9.")
	assert_has(texts, "Delayed contact KM1:17-18 belongs to KM1, which is not a timer.")
	assert_has(texts, "Terminal K9:14 is not connected.")
	assert_does_not_have(texts, "Terminal K9:13 is not connected.")
	assert_does_not_have(texts, "Coil KT1 has no contacts.")
	assert_has(texts, "The circuit has no N supply.")
	assert_does_not_have(texts, "The circuit has no L supply.")


func test_examples_pass_the_check() -> void:
	for i: int in ExampleCircuits.count():
		var doc: SchematicDocument = ExampleCircuits.build(i)
		assert_eq(CircuitCheck.run(doc), [] as Array[Dictionary], "%s has no issues" % doc.title)


func test_paste_renames_coil_with_its_contacts() -> void:
	var doc: SchematicDocument = ExampleCircuits.self_holding()
	var data: Dictionary = doc.extract(PackedStringArray(["SB1:13-14", "KM1:13-14", "KM1"]))
	assert_eq(data["wires"].size(), 2, "only wires between copied parts")
	var ids: PackedStringArray = doc.insert(data, Vector2i(20, 0))
	assert_eq(ids, PackedStringArray(["SB2:13-14", "KM2:13-14", "KM2"]))
	assert_eq(doc.get_placement("KM2").cell, Vector2i(25, 17))
	assert_eq(doc.get_wire_count(), 12)
	assert_eq((doc.circuit.get_component("KM2:13-14") as Contact).linked_coil, doc.circuit.get_coil("KM2"))


func test_paste_contact_without_coil_gets_free_number() -> void:
	var doc: SchematicDocument = ExampleCircuits.self_holding()
	var ids: PackedStringArray = doc.insert(doc.extract(PackedStringArray(["KM1:13-14"])), Vector2i(0, 10))
	assert_eq(ids, PackedStringArray(["KM1:33-34"]), "stays with KM1, next contact number")


func test_paste_supply_and_junction() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(Junction.new("J1"), Vector2i(3, 0))
	doc.connect_terminals("L", "J1")
	var ids: PackedStringArray = doc.insert(doc.extract(PackedStringArray(["L", "J1"])), Vector2i(0, 4))
	assert_eq(ids, PackedStringArray(["L.2", "J2"]))
	assert_eq(doc.get_wire_count(), 2)


func test_paste_changeover_without_coil_stays_with_it() -> void:
	var doc: SchematicDocument = ExampleCircuits.self_holding()
	doc.add(ChangeoverContact.new("KM1", 3), Vector2i(20, 4))
	var ids: PackedStringArray = doc.insert(doc.extract(PackedStringArray(["KM1:31-32-34"])), Vector2i(0, 10))
	assert_eq(ids, PackedStringArray(["KM1:41-42-44"]), "stays with KM1, next contact number")


func test_paste_main_contacts_go_to_a_contactor_without_them() -> void:
	var doc: SchematicDocument = ExampleCircuits.direct_on_line()
	doc.add(Coil.new("KM2"), Vector2i(30, 4))
	var ids: PackedStringArray = doc.insert(doc.extract(PackedStringArray(["KM1:1-2-3-4-5-6"])), Vector2i(10, 0))
	assert_eq(ids, PackedStringArray(["KM2:1-2-3-4-5-6"]), "the main contacts of KM2")
	ids = doc.insert(doc.extract(PackedStringArray(["KM1:1-2-3-4-5-6"])), Vector2i(20, 0))
	assert_eq(ids, PackedStringArray(["KM3:1-2-3-4-5-6"]), "every contactor has them: a new KM")
