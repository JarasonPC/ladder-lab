class_name TrainingWireBar
extends HBoxContainer
## The wire being laid or picked while wiring a training plan: its colour
## (see [constant TrainingPlan.COLOURS]) and the number written on its
## sleeves. With no wire picked it sets what the next wires get; with one
## picked ([method show_wire]) it changes that wire (a cable's core keeps its
## own colour).

## A change of the wire picked: [param change] is called with the document.
signal edit_requested(change: Callable)

## What the next wires get (shared by every switchboard and station).
static var colour: String = TrainingPlan.COLOURS[0]
static var number: String = ""

var _colour: OptionButton
var _number: LineEdit
var _what: Label
## The wire shown: its place and index there (-1: the next ones).
var _place: String = ""
var _index: int = -1
var _document: SchematicDocument


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_what = Label.new()
	_what.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_what.theme_type_variation = "MutedLabel"
	add_child(_what)
	_colour = OptionButton.new()
	_colour.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_colour.focus_mode = Control.FOCUS_NONE
	_colour.item_selected.connect(_on_colour)
	add_child(_colour)
	var caption: Label = Label.new()
	caption.text = tr("Number")
	add_child(caption)
	_number = LineEdit.new()
	_number.custom_minimum_size.x = 70.0
	_number.max_length = 12
	_number.text_submitted.connect(func(_text: String) -> void: _commit_number())
	_number.focus_exited.connect(_commit_number)
	add_child(_number)
	show_wire(null, "", -1)


## Shows wire [param index] of [param place] of [param doc]'s plan, or what
## the next wires get for -1.
func show_wire(doc: SchematicDocument, place: String, index: int) -> void:
	_document = doc
	var wires: Array[PackedStringArray] = []
	if doc != null and doc.training != null:
		wires = doc.training.wires_of(place)
	_place = place
	_index = index if index >= 0 and index < wires.size() else -1
	if _colour == null:
		return
	_colour.clear()
	for k: int in TrainingPlan.COLOURS.size():
		_colour.add_icon_item(_swatch(TrainingCheck.conductor_of(TrainingPlan.COLOURS[k])), tr(TrainingCheck.COLOUR_NAMES[k]))
	if _index < 0:
		_what.text = tr("Next wire:")
		_colour.select(maxi(TrainingPlan.COLOURS.find(colour), 0))
		_colour.disabled = false
		_number.text = number
		return
	var wire: PackedStringArray = wires[_index]
	_what.text = tr("Wire %s – %s:") % [TrainingPick.port_text(wire[0]), TrainingPick.port_text(wire[1])]
	_colour.select(maxi(TrainingPlan.COLOURS.find(wire[2]), 0))
	# A cable's core landed: it has the colour of its core.
	_colour.disabled = _is_core(wire[0]) or _is_core(wire[1])
	_number.text = wire[3]


## Shows the wire shown again from [param doc] (after an edit).
func refresh(doc: SchematicDocument) -> void:
	show_wire(doc, _place, _index)


static func _is_core(port: String) -> bool:
	return port.begins_with("c:") or port.begins_with("p:")


func _on_colour(k: int) -> void:
	if _index < 0:
		colour = TrainingPlan.COLOURS[k]
		return
	_change(TrainingPlan.COLOURS[k], _number.text)


func _commit_number() -> void:
	if _index < 0:
		number = _number.text.strip_edges()
		return
	var wire: PackedStringArray = _document.training.wires_of(_place)[_index]
	if wire[3] != _number.text.strip_edges():
		_change(wire[2], _number.text)


func _change(new_colour: String, new_number: String) -> void:
	var place: String = _place
	var index: int = _index
	edit_requested.emit(func(doc: SchematicDocument) -> void: doc.training.set_look(place, index, new_colour, new_number))


## A square of the colour of conductor [param c].
static func _swatch(c: CabinetDevices.Conductor) -> Texture2D:
	var image: Image = Image.create(14, 14, false, Image.FORMAT_RGBA8)
	image.fill(CabinetParts.WIRE_COLORS[c])
	if c == CabinetDevices.Conductor.PE:
		# Green-yellow: a yellow stripe across.
		image.fill_rect(Rect2i(0, 5, 14, 4), Color("e8d23a"))
	return ImageTexture.create_from_image(image)
