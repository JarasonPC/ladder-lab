class_name PlcTimer
extends RefCounted
## Timer of a PLC program: an on-delay (output on [member preset] seconds
## after its input came on, off with the input) or an off-delay (output on
## with the input, off [member preset] seconds after the input went off; a
## reset input switches it off at once). [method update] is called once per
## program scan with the input; the PLC moves the time on between scans with
## [method advance].

enum Kind { ON_DELAY, OFF_DELAY }

const _EPSILON: float = 1e-9

var kind: Kind
## Set time in seconds.
var preset: float = 1.0
## Seconds counted in the running timing.
var elapsed: float = 0.0
var running: bool = false
var output: bool = false


func _init(p_kind: Kind = Kind.ON_DELAY, p_preset: float = 1.0) -> void:
	kind = p_kind
	preset = maxf(p_preset, 0.0)


## One scan with [param input] (the trigger) and [param reset_input].
func update(input: bool, reset_input: bool = false) -> void:
	if reset_input:
		reset()
		return
	match kind:
		Kind.ON_DELAY:
			if not input:
				reset()
			elif not output:
				if not running:
					running = true
					elapsed = 0.0
				if elapsed + _EPSILON >= preset:
					output = true
					running = false
		Kind.OFF_DELAY:
			if input:
				output = true
				running = false
				elapsed = 0.0
			elif output:
				if not running:
					running = true
					elapsed = 0.0
				if elapsed + _EPSILON >= preset:
					output = false
					running = false


func reset() -> void:
	running = false
	output = false
	elapsed = 0.0


func advance(delta: float) -> void:
	if running:
		elapsed += delta


## Seconds until the running timing ends (the next scan then switches the
## output), INF when not timing.
func time_left() -> float:
	return maxf(preset - elapsed, 0.0) if running else INF
