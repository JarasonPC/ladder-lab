class_name ControlBoxItem
extends RefCounted
## One place of a [ControlBox]: a push button, a switch or a signal lamp with
## a label plate beside it. A button or switch can have a signal lamp under
## it. The item names a device of the circuit by its designation ("SB1",
## "H1"); "" or a designation the circuit no longer has leaves it unassigned.

enum Kind { BUTTON, SWITCH, LAMP }

## Kind names as saved, in [enum Kind] order.
const KINDS: PackedStringArray = ["button", "switch", "lamp"]
## Colours of button caps and lamp lenses (IEC 60073), as saved.
const COLORS: PackedStringArray = ["green", "red", "black", "white", "yellow", "blue"]
## Colours a lamp lens can have (no black).
const LAMP_COLORS: PackedStringArray = ["green", "red", "white", "yellow", "blue"]
## English names of [constant COLORS] (translated by the UI).
const COLOR_TITLES: PackedStringArray = ["Green", "Red", "Black", "White", "Yellow", "Blue"]

var kind: Kind = Kind.BUTTON
## Designation of the device, e.g. "SB1"; "" when none is chosen.
var designation: String = ""
## Text on the label plate (e.g. "Forward"); the designation is shown when empty.
var label: String = ""
## Colour of the button cap, switch grip or lamp lens, one of [constant COLORS].
var color: String = "green"
## Designation of a signal lamp under a button or switch, "" for none.
var lamp: String = ""
## Lens colour of [member lamp].
var lamp_color: String = "green"


func _init(p_kind: Kind = Kind.BUTTON, p_designation: String = "", p_color: String = "") -> void:
	kind = p_kind
	designation = p_designation
	color = p_color if COLORS.has(p_color) else default_color(p_kind)


## Colour a new item of [param p_kind] gets.
static func default_color(p_kind: Kind) -> String:
	return "black" if p_kind == Kind.SWITCH else "green"


## Kind of item that shows component [param c] on a control box, or -1 when it
## cannot be on one (contacts, coils, limit switches operated by the machine...).
static func kind_of(c: CircuitComponent) -> int:
	if c is PushButton:
		return Kind.BUTTON
	if c is LatchingSwitch and not (c is LimitSwitch):
		return Kind.SWITCH
	if c is Lamp:
		return Kind.LAMP
	return -1


func to_data() -> Dictionary:
	var d: Dictionary = {"kind": KINDS[kind], "designation": designation, "color": color}
	if not label.is_empty():
		d["label"] = label
	if kind != Kind.LAMP and not lamp.is_empty():
		d["lamp"] = lamp
		d["lamp_color"] = lamp_color
	return d


## Item from [method to_data] data, or null when it is malformed.
static func from_data(data: Variant) -> ControlBoxItem:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	var kind_index: int = KINDS.find(str(d.get("kind", "")))
	if kind_index < 0:
		return null
	var item: ControlBoxItem = ControlBoxItem.new(kind_index as Kind, _designation(d.get("designation", "")), str(d.get("color", "")))
	if item.kind == Kind.LAMP and not LAMP_COLORS.has(item.color):
		item.color = default_color(Kind.LAMP)
	item.label = str(d.get("label", "")).strip_edges()
	if item.kind != Kind.LAMP:
		item.lamp = _designation(d.get("lamp", ""))
		var raw_color: String = str(d.get("lamp_color", ""))
		item.lamp_color = raw_color if LAMP_COLORS.has(raw_color) else default_color(Kind.LAMP)
	return item


## A designation as saved, "" when it is unusable.
static func _designation(value: Variant) -> String:
	var text: String = str(value).strip_edges()
	return "" if text.contains(":") or text.contains(" ") else text
