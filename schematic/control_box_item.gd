class_name ControlBoxItem
extends RefCounted
## One place of a [ControlBox]: a push button, a switch or a signal lamp with
## a label plate beside it. A button or switch can be illuminated: a signal
## lamp of the circuit inside it lights its cap or grip. The item names a device of the circuit by its designation ("SB1",
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
## Designation of the signal lamp inside an illuminated button or switch,
## "" for none. Its light has the colour of the cap (never black).
var lamp: String = ""


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
	if (c is LatchingSwitch and not (c is LimitSwitch)) or c is CamSwitch:
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
		if not item.lamp.is_empty() and not LAMP_COLORS.has(item.color):
			# A lit cap is translucent: a black one becomes white.
			item.color = "white"
	return item


## A designation as saved, "" when it is unusable.
static func _designation(value: Variant) -> String:
	var text: String = str(value).strip_edges()
	return "" if text.contains(":") or text.contains(" ") else text
