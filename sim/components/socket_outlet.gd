class_name SocketOutlet
extends CircuitComponent
## Socket outlet 230 V of a house installation (zásuvka, designation "XD1",
## ČSN EN 81346-2 XD), the Czech type E: two holes and the protective pin
## (ČSN 35 4516). Terminals L, N and PE; single or double (two outlets on one
## plate, joined inside). Nothing is plugged in: it only shows whether it
## has its voltage.

## Mounting height over the floor (m) when none is set: Czech practice
## (ČSN 33 2130) puts sockets 0.3 m up in rooms (over a kitchen worktop
## about 1.1 m).
const STANDARD_HEIGHT: float = 0.3
## Most outlets on one plate.
const MAX_GANGS: int = 2

## Outlets on its plate, 1 or 2 (design data).
var gangs: int = 1:
	set(value):
		gangs = clampi(value, 1, MAX_GANGS)
## Mounting height over the floor in metres (design data).
var height: float = STANDARD_HEIGHT


func _init(p_designation: String, p_gangs: int = 1) -> void:
	super(p_designation)
	gangs = p_gangs


func default_terminal_names() -> PackedStringArray:
	return PackedStringArray(["L", "N", "PE"])
