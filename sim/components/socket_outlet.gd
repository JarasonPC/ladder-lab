class_name SocketOutlet
extends Load
## Socket outlet 230 V of a house installation (zásuvka, designation "XD1",
## ČSN EN 81346-2 XD), the Czech type E: two holes and the protective pin
## (ČSN 35 4516). Terminals L, N and PE; single or double (two outlets on one
## plate, joined inside). An appliance may be plugged in ([member plugged]):
## it then draws its power while the socket has its voltage.

## Mounting height over the floor (m) when none is set: Czech practice
## (ČSN 33 2130) puts sockets 0.3 m up in rooms (over a kitchen worktop
## about 1.1 m).
const STANDARD_HEIGHT: float = 0.3
## Most outlets on one plate.
const MAX_GANGS: int = 2
## Appliances that can be plugged in (the others are wired for good).
const PLUGGABLE: Array[Appliance.Kind] = [Appliance.Kind.MICROWAVE, Appliance.Kind.WASHING_MACHINE, Appliance.Kind.DISHWASHER, Appliance.Kind.HEATER, Appliance.Kind.FRIDGE, Appliance.Kind.KETTLE]

## Outlets on its plate, 1 or 2 (design data).
var gangs: int = 1:
	set(value):
		gangs = clampi(value, 1, MAX_GANGS)
## Mounting height over the floor in metres (design data).
var height: float = STANDARD_HEIGHT
## Appliance plugged in, -1 for none (an [enum Appliance.Kind]; design data).
var plugged: int = -1
## Power of the appliance plugged in (W; design data).
var plugged_power: float = 0.0


func _init(p_designation: String, p_gangs: int = 1) -> void:
	super(p_designation, "L", "N")
	_terminals.append("PE")
	gangs = p_gangs


## Plugs appliance [param kind] in (-1 pulls it out), at its usual power.
func plug(kind: int) -> void:
	plugged = kind if PLUGGABLE.has(kind) else -1
	plugged_power = Appliance.DEFAULT_POWER[plugged] if plugged >= 0 else 0.0


## Current the appliance plugged in draws at 230 V, amperes.
func rated_draw() -> float:
	return plugged_power / 230.0 if plugged >= 0 else 0.0
