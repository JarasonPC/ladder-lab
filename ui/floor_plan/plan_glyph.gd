class_name PlanGlyph
extends Control
## A part of a residential floor plan drawn as the plan draws it (see
## [PlanSymbols]), for the palette's tile: a switch, socket or appliance
## on a piece of wall at the top facing down into the room, a luminaire on
## the ceiling in the middle (a wall luminaire on the wall).

## The part drawn.
var component: CircuitComponent
## Or the furniture or fixture drawn (a kind of [constant FloorPlan.FIXTURES]).
var fixture: String = ""

## Pixels a metre, by what is drawn: an appliance is taller.
const SCALE: float = 68.0
const APPLIANCE_SCALE: float = 55.0


func _draw() -> void:
	var color: Color = SchematicTheme.LINE
	var width: float = 1.4
	if not fixture.is_empty():
		# Against a piece of wall at the top, as large as the tile takes.
		var extent: Vector2 = FloorPlan.FIXTURES.get(fixture, Vector2.ONE)
		var fit: float = minf((size.x - 8.0) / extent.x, (size.y - 10.0) / extent.y)
		var shape: Vector2 = extent * fit
		draw_line(Vector2(size.x * 0.5 - shape.x * 0.5 - 3.0, 4.0), Vector2(size.x * 0.5 + shape.x * 0.5 + 3.0, 4.0), Color(color, 0.45), 3.0)
		PlanSymbols.draw_fixture(self, fixture, Rect2(Vector2(size.x * 0.5 - shape.x * 0.5, 5.5), shape), Vector2.DOWN, Color(color, 0.8), 1.1)
		return
	if component == null:
		return
	if component is Luminaire and not (component as Luminaire).wall:
		PlanSymbols.draw_luminaire(self, size * 0.5, SCALE, color, width, false)
		return
	var s: float = APPLIANCE_SCALE if component is Appliance else SCALE
	var wall: Vector2 = Vector2(size.x * 0.5, 4.0)
	# The piece of wall it is on.
	draw_line(Vector2(wall.x - 0.22 * s, wall.y), Vector2(wall.x + 0.22 * s, wall.y), Color(color, 0.45), 3.0)
	if component is LightSwitch:
		PlanSymbols.draw_switch(self, component as LightSwitch, wall, Vector2.DOWN, s, color, width)
	elif component is SocketOutlet:
		PlanSymbols.draw_socket(self, component as SocketOutlet, wall, Vector2.DOWN, s, color, width, false)
	elif component is Luminaire:
		PlanSymbols.draw_luminaire(self, wall, SCALE, color, width, false, Vector2.DOWN)
	elif component is Appliance:
		PlanSymbols.draw_appliance(self, component as Appliance, wall, Vector2.DOWN, s, color, width, false)
