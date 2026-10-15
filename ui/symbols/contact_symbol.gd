class_name ContactSymbol
extends SchematicSymbol
## NO / NC contact (IEC 60617 S00227 / S00229) drawn in its current position
## (NO opens upward, NC is drawn pivoting from the top and opens downward;
## both blades lean to the same side, as in the guide),
## with the push-button (S00253) or turn-switch (S00254) actuator, the thermal
## actuator of overload relay contacts, and the delay "parachute"
## (S00243-S00246) for delayed timer contacts.
## The arc is drawn so the movement toward its centre is the delayed one.

const FIXED_END := Vector2(0, 20)
const PIVOT := Vector2(0, 40)
const OPEN_TIP := Vector2(-13, 18)
const NO_CLOSED_TIP := Vector2(-3, 20)
const NC_CLOSED_TIP := Vector2(10, 18)
const HOOK_END := Vector2(9, 20)


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
	var closed: bool = element.is_closed()
	# NO: pivot at the bottom, blade opens upward. NC: turned half round, with
	# the pivot at the top and the hook at the bottom, so it opens downward and
	# its blade leans to the same side as an NO blade.
	var flip: Callable = func(v: Vector2) -> Vector2:
		return Vector2(-v.x, 3 * G - v.y) if is_nc else v
	# Terminal 0 is at the top: the fixed side of an NO contact, the pivot of an NC.
	var fixed_terminal: int = 1 if is_nc else 0
	var pivot_terminal: int = 1 - fixed_terminal
	var fixed_color: Color = lead_color(fixed_terminal)
	var fixed_width: float = lead_width(fixed_terminal)
	var pivot_color: Color = lead_color(pivot_terminal)
	var pivot_width: float = lead_width(pivot_terminal)
	var pivot: Vector2 = flip.call(PIVOT)
	draw_line(flip.call(Vector2(0, 0)), flip.call(FIXED_END), fixed_color, fixed_width)
	draw_line(flip.call(Vector2(0, 3 * G)), pivot, pivot_color, pivot_width)
	if is_nc:
		draw_line(flip.call(FIXED_END), flip.call(HOOK_END), fixed_color, fixed_width)
	var tip: Vector2 = OPEN_TIP
	if closed:
		tip = NC_CLOSED_TIP if is_nc else NO_CLOSED_TIP
	if element.get_armature() != null and not closed:
		# Contacts are drawn where their armature or actuator is, so they visibly move.
		var travel: float = element.get_travel()
		if is_nc:
			tip = NC_CLOSED_TIP.lerp(OPEN_TIP, clampf((travel - Armature.NC_REMAKE) / (1.0 - Armature.NC_REMAKE), 0.15, 1.0))
		else:
			tip = OPEN_TIP.lerp(NO_CLOSED_TIP, minf(travel, 0.85))
	tip = flip.call(tip)
	draw_line(pivot, tip, pivot_color, pivot_width)
	var middle: Vector2 = pivot.lerp(tip, 0.5)
	# The actuator is insulated from the contact: never live.
	color = SchematicTheme.WARNING if warning else SchematicTheme.LINE

	if component is PushButton:
		_draw_push_actuator(middle, (component as PushButton).pressed, color)
	elif component is LatchingSwitch:
		_draw_turn_actuator(middle, (component as LatchingSwitch).switched_on, color)
	elif component is OverloadContact:
		_draw_thermal_actuator(middle, color)
	elif component is Contact:
		var contact: Contact = component as Contact
		if contact.delayed and contact.linked_coil is TimerRelay:
			var on_delay: bool = (contact.linked_coil as TimerRelay).mode == TimerRelay.Mode.ON_DELAY
			# Operated, an NO blade moves right to close and an NC blade (turned
			# half round) moves right to open: the delayed move is to the
			# right for on-delay contacts.
			var delayed_move_right: bool = on_delay
			_draw_parachute(middle, delayed_move_right, color)


## Stem from the blade to the button head (a bracket open toward the blade),
## drawn solid as in the guide.
func _draw_push_actuator(middle: Vector2, pressed: bool, color: Color) -> void:
	var head_x: float = -22.0 if pressed else -28.0
	var y: float = middle.y
	draw_line(Vector2(head_x, y), Vector2(middle.x - 1.0, y), color, 1.4)
	draw_line(Vector2(head_x, y - 7), Vector2(head_x, y + 7), color, 1.8)
	draw_line(Vector2(head_x, y - 7), Vector2(head_x + 5, y - 7), color, 1.8)
	draw_line(Vector2(head_x, y + 7), Vector2(head_x + 5, y + 7), color, 1.8)


## Stem from the blade to the hook of the thermal release, as in the guide.
func _draw_thermal_actuator(middle: Vector2, color: Color) -> void:
	var y: float = middle.y
	var x: float = -28.0
	draw_line(Vector2(x, y), Vector2(middle.x - 1.0, y), color, 1.4)
	draw_polyline(PackedVector2Array([Vector2(x, y), Vector2(x, y - 8), Vector2(x + 6, y - 8)]), color, 1.8)


func _draw_turn_actuator(middle: Vector2, switched_on: bool, color: Color) -> void:
	var head_x: float = -26.0
	var y: float = middle.y
	var flip: float = -1.0 if switched_on else 1.0
	draw_line(Vector2(head_x, y), Vector2(middle.x - 1.0, y), color, 1.4)
	draw_line(Vector2(head_x, y - 7), Vector2(head_x, y + 7), color, 1.8)
	draw_line(Vector2(head_x, y - 7), Vector2(head_x - 5 * flip, y - 7), color, 1.8)
	draw_line(Vector2(head_x, y + 7), Vector2(head_x + 5 * flip, y + 7), color, 1.8)


## Two short lines from the blade to a half circle on its left.
## [param delayed_move_right]: the arc centre lies to the right of the arc.
func _draw_parachute(middle: Vector2, delayed_move_right: bool, color: Color) -> void:
	var radius: float = 6.0
	var y: float = middle.y
	var w: float = SchematicTheme.LINE_WIDTH * 0.75
	if delayed_move_right:
		# "(" : centre to the right, arc ends joined to the blade.
		var c: Vector2 = Vector2(-12.0, y)
		draw_arc(c, radius, PI * 0.5, PI * 1.5, 12, color, w)
		draw_line(Vector2(c.x, y - radius), Vector2(middle.x - 1.0, y - radius), color, w)
		draw_line(Vector2(c.x, y + radius), Vector2(middle.x - 1.0, y + radius), color, w)
	else:
		# ")" : centre to the left, arc apex joined to the blade.
		var c2: Vector2 = Vector2(-20.0, y)
		draw_arc(c2, radius, -PI * 0.5, PI * 0.5, 12, color, w)
		draw_line(Vector2(c2.x + radius, y - 2.5), Vector2(middle.x - 1.0, y - 2.5), color, w)
		draw_line(Vector2(c2.x + radius, y + 2.5), Vector2(middle.x - 1.0, y + 2.5), color, w)
