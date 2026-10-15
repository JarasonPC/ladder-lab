class_name ContactSymbol
extends SchematicSymbol
## NO / NC contact (IEC 60617 S00227 / S00229) drawn in its current position.
## As the guide's main contacts and breakers, every contact pivots at its
## second terminal (bottom, or right in horizontal paths) and its blade runs up
## toward the fixed contact: an NO blade stands off to the actuator side, an
## NC blade rests against the stop on its fixed contact on the other side. Shown
## with the push-button (S00253) or turn-switch (S00254) actuator, the thermal
## actuator of overload relay contacts, and the delay "parachute"
## on every delayed (time relay) contact, whatever the relay's function.

const FIXED_END := Vector2(0, 20)
const PIVOT := Vector2(0, 40)
const OPEN_TIP := Vector2(-13, 18)
const NO_CLOSED_TIP := Vector2(-3, 20)
const NC_CLOSED_TIP := Vector2(10, 18)
## An open NC blade swings further away from its stop, on the same side.
const NC_OPEN_TIP := Vector2(18, 24)
const HOOK_END := Vector2(9, 20)


func flips_when_horizontal() -> bool:
	return true


func _is_manual() -> bool:
	return component is PushButton or component is LatchingSwitch


## Where the contact is heading: 0 at rest, 1 operated (an NO closed, an NC
## open); between while its armature travels.
func _operated() -> float:
	var element: SwitchingElement = component as SwitchingElement
	if component is PushButton:
		return 1.0 if (component as PushButton).pressed else 0.0
	if component is LatchingSwitch:
		return 1.0 if (component as LatchingSwitch).switched_on else 0.0
	if element.get_armature() != null and element.fault == SwitchingElement.Fault.NONE:
		return element.get_travel()
	var is_nc: bool = element.contact_type == SwitchingElement.ContactType.NC
	return 1.0 if element.is_closed() != is_nc else 0.0


func is_interactive() -> bool:
	if component is OverloadContact:
		var relay: OverloadRelay = (component as OverloadContact).linked_relay
		return relay != null and relay.tripped
	return component is PushButton or component is LatchingSwitch


func _designation_anchor() -> Vector2:
	var has_mark: bool = component is PushButton or component is LatchingSwitch or component is OverloadContact or (component is Contact and (component as Contact).delayed)
	return Vector2(-1.9 * G if has_mark else -1.3 * G, 1.5 * G)


func _draw_shape(color: Color, _width: float) -> void:
	var element: SwitchingElement = component as SwitchingElement
	var is_nc: bool = element.contact_type == SwitchingElement.ContactType.NC
	# Fixed contact at terminal 0 (top), pivot at terminal 1 (bottom).
	var fixed_color: Color = lead_color(0)
	var fixed_width: float = lead_width(0)
	var pivot_color: Color = lead_color(1)
	var pivot_width: float = lead_width(1)
	var pivot: Vector2 = PIVOT
	aa_line(Vector2(0, 0), FIXED_END, fixed_color, fixed_width)
	aa_line(Vector2(0, 3 * G), pivot, pivot_color, pivot_width)
	if is_nc:
		aa_line(FIXED_END, HOOK_END, fixed_color, fixed_width)
	# Drawn where it is heading, moving smoothly (an NC breaks only after
	# the armature has passed the re-make point, as in REALISTIC mode).
	var s: float = shown("blade", _operated())
	var rest_tip: Vector2 = NC_CLOSED_TIP if is_nc else OPEN_TIP
	var tip: Vector2
	if is_nc:
		tip = NC_CLOSED_TIP.lerp(NC_OPEN_TIP, clampf((s - Armature.NC_REMAKE) / (1.0 - Armature.NC_REMAKE), 0.0, 1.0) if element.get_armature() != null else s)
	else:
		tip = OPEN_TIP.lerp(NO_CLOSED_TIP, s)
	draw_blade(pivot, tip, pivot_color, pivot_width)
	var middle: Vector2 = pivot.lerp(tip, 0.5)
	# Marks fixed to the blade turn with it; the button and switch heads stay
	# upright and only follow the blade's middle.
	var turn: float = (tip - pivot).angle() - (rest_tip - pivot).angle()
	var rest_middle: Vector2 = pivot.lerp(rest_tip, 0.5)
	# The actuator is insulated from the contact: never live.
	color = SchematicTheme.WARNING if warning else SchematicTheme.LINE

	if component is PushButton:
		_draw_push_actuator(middle, s, color)
	elif component is LatchingSwitch:
		_draw_turn_actuator(middle, (component as LatchingSwitch).switched_on, color)
	elif component is OverloadContact:
		_draw_thermal_actuator(rest_middle, color, pivot, turn)
	elif component is Contact and (component as Contact).delayed:
		draw_delay_mark(self, rest_middle, color, pivot, turn)


## Dashed stem (mechanical link) from the blade to the button head, a
## bracket open toward the blade; [param pressed] 0..1 moves the head in.
func _draw_push_actuator(middle: Vector2, pressed: float, color: Color) -> void:
	var head_x: float = lerpf(-28.0, -22.0, pressed)
	var y: float = middle.y
	aa_dashed_line(Vector2(head_x, y), Vector2(middle.x - 1.0, y), color, 1.4, 2.5)
	aa_line(Vector2(head_x, y - 7), Vector2(head_x, y + 7), color, 1.8)
	aa_line(Vector2(head_x, y - 7), Vector2(head_x + 5, y - 7), color, 1.8)
	aa_line(Vector2(head_x, y + 7), Vector2(head_x + 5, y + 7), color, 1.8)


## Stem from the blade to the hook of the thermal release, as in the guide;
## drawn for the blade at rest ([param middle]) and turned by [param turn]
## about [param pivot] with the blade.
func _draw_thermal_actuator(middle: Vector2, color: Color, pivot: Vector2, turn: float) -> void:
	var y: float = middle.y
	var x: float = -28.0
	var on_blade: Callable = func(p: Vector2) -> Vector2:
		return pivot + (p - pivot).rotated(turn)
	aa_line(on_blade.call(Vector2(x, y)), on_blade.call(Vector2(middle.x - 1.0, y)), color, 1.4)
	aa_polyline(PackedVector2Array([on_blade.call(Vector2(x, y)), on_blade.call(Vector2(x, y - 8)), on_blade.call(Vector2(x + 6, y - 8))]), color, 1.8)


func _draw_turn_actuator(middle: Vector2, switched_on: bool, color: Color) -> void:
	var head_x: float = -26.0
	var y: float = middle.y
	var flip: float = -1.0 if switched_on else 1.0
	aa_line(Vector2(head_x, y), Vector2(middle.x - 1.0, y), color, 1.4)
	aa_line(Vector2(head_x, y - 7), Vector2(head_x, y + 7), color, 1.8)
	aa_line(Vector2(head_x, y - 7), Vector2(head_x - 5 * flip, y - 7), color, 1.8)
	aa_line(Vector2(head_x, y + 7), Vector2(head_x + 5 * flip, y + 7), color, 1.8)


## Time relay contact mark (the "parachute"): a half circle ")" on the left
## of the blade at [param middle], its apex joined to the blade by two short
## lines. Shared with [ChangeoverSymbol].
## Drawn for the blade at rest ([param middle]) and turned by [param turn]
## about [param pivot], fixed to the blade.
static func draw_delay_mark(symbol: SchematicSymbol, middle: Vector2, color: Color, pivot: Vector2 = Vector2.ZERO, turn: float = 0.0) -> void:
	var radius: float = 6.0
	var y: float = middle.y
	var w: float = SchematicTheme.LINE_WIDTH * 0.75
	var on_blade: Callable = func(p: Vector2) -> Vector2:
		return pivot + (p - pivot).rotated(turn)
	var c: Vector2 = Vector2(-20.0, y)
	symbol.aa_arc(on_blade.call(c), radius, -PI * 0.5 + turn, PI * 0.5 + turn, 12, color, w)
	symbol.aa_line(on_blade.call(Vector2(c.x + radius, y - 2.5)), on_blade.call(Vector2(middle.x - 1.0, y - 2.5)), color, w)
	symbol.aa_line(on_blade.call(Vector2(c.x + radius, y + 2.5)), on_blade.call(Vector2(middle.x - 1.0, y + 2.5)), color, w)
