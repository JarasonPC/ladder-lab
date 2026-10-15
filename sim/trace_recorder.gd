class_name TraceRecorder
extends RefCounted
## Keeps a time history of named signals for the timing chart. A signal is a
## series of (time, value) samples; between samples the value is linear for
## analog signals (armature positions) and held for digital ones. Samples older
## than [member history_seconds] are dropped.

var history_seconds: float = 60.0

var _times: Dictionary[String, PackedFloat64Array] = {}
var _values: Dictionary[String, PackedFloat32Array] = {}
var _order: PackedStringArray = PackedStringArray()


## Adds a sample unless the value equals the last one (digital signals) or the
## sample adds nothing to a straight line (analog signals).
func record(signal_name: String, time: float, value: float, analog: bool = false) -> void:
	if not _times.has(signal_name):
		_times[signal_name] = PackedFloat64Array()
		_values[signal_name] = PackedFloat32Array()
		_order.append(signal_name)
	var times: PackedFloat64Array = _times[signal_name]
	var values: PackedFloat32Array = _values[signal_name]
	var n: int = times.size()
	if n > 0 and is_equal_approx(values[n - 1], value):
		if not analog or (n >= 2 and is_equal_approx(values[n - 2], value)):
			# Extend a flat run: move its end instead of adding a sample.
			if analog:
				times[n - 1] = time
				_times[signal_name] = times
			return
	if n > 0 and time < times[n - 1]:
		return
	times.append(time)
	values.append(value)
	# Drop old samples now and then (keeping one before the window).
	if times[0] < time - history_seconds * 1.25:
		var cut: int = maxi(times.bsearch(time - history_seconds, true) - 1, 0)
		times = times.slice(cut)
		values = values.slice(cut)
	_times[signal_name] = times
	_values[signal_name] = values


func signal_names() -> PackedStringArray:
	return _order


func times(signal_name: String) -> PackedFloat64Array:
	return _times.get(signal_name, PackedFloat64Array())


func values(signal_name: String) -> PackedFloat32Array:
	return _values.get(signal_name, PackedFloat32Array())


## Value of a signal at [param time] (0 before its first sample).
func value_at(signal_name: String, time: float, analog: bool = false) -> float:
	var t: PackedFloat64Array = times(signal_name)
	var v: PackedFloat32Array = values(signal_name)
	if t.is_empty() or time < t[0]:
		return 0.0
	var i: int = t.bsearch(time, false) - 1
	if i >= t.size() - 1 or not analog:
		return v[clampi(i, 0, v.size() - 1)]
	var span: float = t[i + 1] - t[i]
	return v[i] if span <= 0.0 else lerpf(v[i], v[i + 1], (time - t[i]) / span)


func clear() -> void:
	_times.clear()
	_values.clear()
	_order.clear()
