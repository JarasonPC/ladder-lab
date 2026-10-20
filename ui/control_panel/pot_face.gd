class_name PotFace
extends RefCounted
## The front of a potentiometer ([Potentiometer]) on a control station
## ([ControlBoxView]) or a switchboard's door ([DoorView]), drawn with a
## [CabinetPainter] round its middle, as large as the bezel of the 22 mm
## devices beside it. A single-turn one is a black knob with a white
## pointer over a 0-10 scale printed on the panel round it (270°); a
## multi-turn one a turns-counting dial: a window counting the full turns
## over a ring of hundredths of a turn that turns with the knob (read at a
## fixed index at the top), and a lock lever. No nodes.

const BEZEL := Color("17181a")
const KNOB := Color("2a2c2f")
const GRIP := Color("45484c")
const FACE := Color("26282b")
const WINDOW := Color("f4f4f2")
const WINDOW_TEXT := Color("111111")
const RING_PRINT := Color("e8eaec")
const LEVER := Color("868a8f")
## Where the scale of a single-turn knob starts (lower left, degrees
## anticlockwise from the right) and how far it runs clockwise.
const SCALE_FROM: float = 225.0


## Draws a potentiometer of [param turns] turns set to [param setting]
## (0-1) round [param center], [param r] the radius of its bezel;
## [param print] is the colour of the scale printed on the panel.
static func paint(p: CabinetPainter, center: Vector2, r: float, turns: int, setting: float, print: Color) -> void:
	if turns <= 1:
		_knob(p, center, r, setting, print)
	else:
		_dial(p, center, r, turns, setting)


## Unit vector at [param degrees] anticlockwise from the right, on the
## screen (y down).
static func _towards(degrees: float) -> Vector2:
	var a: float = deg_to_rad(degrees)
	return Vector2(cos(a), -sin(a))


static func _knob(p: CabinetPainter, c: Vector2, r: float, setting: float, print: Color) -> void:
	for i: int in 11:
		var along: Vector2 = _towards(SCALE_FROM - Potentiometer.SINGLE_TURN_DEGREES * i / 10.0)
		p.line(c + along * r * 1.12, c + along * r * (1.34 if i % 5 == 0 else 1.24), print, r * 0.06)
	for i: int in [0, 10]:
		var along: Vector2 = _towards(SCALE_FROM - Potentiometer.SINGLE_TURN_DEGREES * i / 10.0)
		p.text_centered(c + along * r * 1.55, str(i), r * 0.4, print)
	p.circle(c, r, BEZEL)
	p.ring(c, r * 0.9, Color(1, 1, 1, 0.08), r * 0.05)
	p.circle(c, r * 0.75, KNOB)
	p.ring(c, r * 0.62, GRIP, r * 0.07)
	var pointer: Vector2 = _towards(SCALE_FROM - Potentiometer.SINGLE_TURN_DEGREES * setting)
	p.line(c + pointer * r * 0.16, c + pointer * r * 0.66, Color.WHITE, r * 0.13)


static func _dial(p: CabinetPainter, c: Vector2, r: float, turns: int, setting: float) -> void:
	p.circle(c, r * 1.08, BEZEL)
	p.circle(c, r * 0.92, FACE)
	var turned: float = setting * turns
	var share: float = turned - floorf(turned)
	# The ring turns clockwise with the knob, so the number at the index
	# rises: its numbers run anticlockwise.
	for i: int in 20:
		var theta: float = (share - i / 20.0) * TAU
		var along: Vector2 = Vector2(sin(theta), -cos(theta))
		p.line(c + along * r * (0.7 if i % 5 == 0 else 0.78), c + along * r * 0.9, RING_PRINT, r * 0.05)
	for i: int in 4:
		var theta: float = (share - i / 4.0) * TAU
		p.text_centered(c + Vector2(sin(theta), -cos(theta)) * r * 0.55, str(i * 25), r * 0.22, RING_PRINT)
	var window: Vector2 = Vector2(r * 0.56, r * 0.42)
	p.rect(Rect2(c - window * 0.5, window), WINDOW, r * 0.05, Color.BLACK, r * 0.03)
	p.text_centered(c, str(mini(floori(turned), turns)), r * 0.34, WINDOW_TEXT)
	# The fixed index over the top of the ring.
	p.polygon(PackedVector2Array([c + Vector2(0.0, -r * 0.9), c + Vector2(-r * 0.13, -r * 1.07), c + Vector2(r * 0.13, -r * 1.07)]), Color.WHITE)
	# The lock lever at the lower right.
	var out: Vector2 = _towards(-45.0)
	var across: Vector2 = out.orthogonal()
	var lever: PackedVector2Array = PackedVector2Array([
		c + out * r * 1.0 + across * r * 0.09, c + out * r * 1.0 - across * r * 0.09,
		c + out * r * 1.38 - across * r * 0.09, c + out * r * 1.38 + across * r * 0.09,
	])
	p.polygon(lever, LEVER)
