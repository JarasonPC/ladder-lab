class_name Luminaire
extends Load
## Luminaire of a house installation (svítidlo, designation "EA1",
## ČSN EN 81346-2 EA), terminals L, N and PE (its frame, ignored by the
## solver). Lights while it has 230 V between L and N.

## Mounting height over the floor (m) when none is set: on the ceiling of a
## room 2.6 m high (the least clear height of living rooms, ČSN 73 4301).
const STANDARD_HEIGHT: float = 2.6
## Least and most rated power (W).
const MIN_POWER: float = 1.0
const MAX_POWER: float = 2000.0

## Rated power at 230 V (W; design data).
var power: float = 60.0
## Mounting height over the floor in metres (design data).
var height: float = STANDARD_HEIGHT


func _init(p_designation: String) -> void:
	super(p_designation, "L", "N")
	_terminals.append("PE")
	rating = "230v"


## Current it draws at 230 V while lit, amperes.
func rated_draw() -> float:
	return power / 230.0
