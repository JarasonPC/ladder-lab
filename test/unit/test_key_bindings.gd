extends GutTest
## Keys of the keyboard bound to push buttons and switches: one key a
## device, kept when the device is renamed, saved with the project.

const NO := SwitchingElement.ContactType.NO


func _doc() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new("keys")
	doc.add(PushButton.new("SB1", NO), Vector2i(0, 0))
	doc.add(PushButton.new("SB2", NO), Vector2i(4, 0))
	doc.add(LatchingSwitch.new("SA1", NO), Vector2i(8, 0))
	doc.add(Lamp.new("H1"), Vector2i(12, 0))
	return doc


func test_bind_and_take_off() -> void:
	var doc: SchematicDocument = _doc()
	assert_true(doc.set_key("SB1", "A"))
	assert_true(doc.set_key("SA1", "F1"))
	assert_eq(doc.device_of_key("A"), "SB1")
	assert_eq(doc.device_of_key("F1"), "SA1")
	assert_eq(doc.device_of_key("B"), "")
	assert_false(doc.set_key("H1", "B"), "a lamp is not operated")
	assert_false(doc.set_key("SB2", "NoSuchKey"), "an unknown key")
	assert_true(doc.set_key("SB1", ""))
	assert_false(doc.key_bindings.has("SB1"), "the key is taken off")


func test_a_key_operates_one_device() -> void:
	var doc: SchematicDocument = _doc()
	doc.set_key("SB1", "A")
	doc.set_key("SB2", "A")
	assert_eq(doc.device_of_key("A"), "SB2")
	assert_false(doc.key_bindings.has("SB1"), "SB1 lost the key to SB2")


func test_renamed_device_keeps_its_key() -> void:
	var doc: SchematicDocument = _doc()
	doc.set_key("SB1", "A")
	var old: CircuitComponent = doc.circuit.get_component("SB1")
	assert_true(doc.replace_component(old.id, PushButton.new("SB9", NO)))
	assert_eq(doc.device_of_key("A"), "SB9")
	assert_false(doc.key_bindings.has("SB1"))


func test_saved_and_loaded() -> void:
	var doc: SchematicDocument = _doc()
	doc.set_key("SB1", "A")
	doc.set_key("SA1", "F2")
	var copy: SchematicDocument = DocumentSerializer.from_dict(DocumentSerializer.to_dict(doc))
	assert_eq(copy.key_bindings, doc.key_bindings)
	var data: Dictionary = DocumentSerializer.to_dict(doc)
	data["keys"]["H1"] = "B"
	data["keys"]["SB2"] = "NoSuchKey"
	copy = DocumentSerializer.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_false(copy.key_bindings.has("H1"), "a key on a lamp is dropped")
	assert_false(copy.key_bindings.has("SB2"), "an unknown key is dropped")
