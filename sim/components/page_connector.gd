class_name PageConnector
extends CircuitComponent
## Interruption point of a wire that continues on another page of the
## schematic (off-page connector, drawn as an arrow). Electrically every
## connector is joined to all connectors with the same [member label], as if
## a wire ran between them; the label is usually the wire number. Has a single
## terminal addressed by its designation (e.g. "PC1"), like a [Junction].

## Name of the link, e.g. "7" or "L1"; "" joins nothing. Design data.
var label: String = ""


func _init(p_designation: String, p_label: String = "") -> void:
	super(p_designation)
	label = p_label


func get_terminal_names() -> PackedStringArray:
	return PackedStringArray([designation])


func get_terminal_keys() -> PackedStringArray:
	return PackedStringArray([designation])
