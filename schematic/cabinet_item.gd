class_name CabinetItem
extends RefCounted
## One place on a DIN rail of the switchboard (rozvaděč, see [CabinetRail]):
## a device of the circuit named by its designation ("FA1", "KM1", "KT1") or a
## terminal strip named by its strip ("X1"). How it looks (poles, contacts)
## follows the circuit (see [CabinetDevices]); a name the circuit no longer
## has leaves an empty place. Design data only.

enum Kind { DEVICE, STRIP }

## Kind names as saved, in [enum Kind] order.
const KINDS: PackedStringArray = ["device", "strip"]

var kind: Kind = Kind.DEVICE
## Designation of the device, or name of the terminal strip.
var designation: String = ""


func _init(p_kind: Kind = Kind.DEVICE, p_designation: String = "") -> void:
	kind = p_kind
	designation = p_designation


func to_data() -> Dictionary:
	return {"kind": KINDS[kind], "designation": designation}


## Item from [method to_data] data, or null when it is malformed.
static func from_data(data: Variant) -> CabinetItem:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	var kind_index: int = KINDS.find(str(d.get("kind", "")))
	var designation: String = str(d.get("designation", "")).strip_edges()
	if kind_index < 0 or designation.is_empty() or designation.contains(" ") or designation.contains(":"):
		return null
	return CabinetItem.new(kind_index as Kind, designation)
