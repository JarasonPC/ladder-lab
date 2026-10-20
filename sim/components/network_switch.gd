class_name NetworkSwitch
extends Load
## Unmanaged Ethernet switch (designation "KF1"), modelled on the small
## four-port switches that sit on a DIN rail beside small PLCs: supply L+ M
## (24 V DC) and the RJ45 ports P1-P4. While it has its supply it joins the
## Ethernet cables plugged into its ports into one network, so more than two
## PLCs can talk to one another (a PLC has one port, and a cable joins two
## ports only). The ports take no part in the electrical circuit.

## Ports.
const PORTS: int = 4
## Index of the first port (after L+ and M).
const FIRST_PORT: int = 2
## Current drawn while working (amperes at 24 V).
const DRAW: float = 0.08

## 1 for each port with a link (a working device at the other end of its
## cable) while the switch works (simulation state).
var links: PackedByteArray = PackedByteArray()


func _init(p_designation: String) -> void:
	super(p_designation, "L+", "M")
	rating = "24dc"
	links.resize(PORTS)


func default_terminal_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray(["L+", "M"])
	for k: int in PORTS:
		names.append("P%d" % (k + 1))
	return names


func rated_draw() -> float:
	return DRAW


## Terminal index of port P(k + 1).
static func port_terminal(k: int) -> int:
	return FIRST_PORT + k


## True when port P(k + 1) has a link.
func port_linked(k: int) -> bool:
	return energized and k < links.size() and links[k] != 0
