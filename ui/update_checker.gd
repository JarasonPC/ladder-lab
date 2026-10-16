class_name UpdateChecker
extends Node
## Asks GitHub in the background whether a newer LadderLab is released.
## A failed check (offline, GitHub unreachable) is reported, never retried.

enum Result { NEWER, LATEST, FAILED }

## [param release] is the newer release ({"version", "url", "notes"}) when
## [param result] is NEWER, else {}.
signal checked(result: Result, release: Dictionary)

const TIMEOUT: float = 10.0

var _request: HTTPRequest
var _busy: bool = false


func is_busy() -> bool:
	return _busy


## Starts a check unless one is running; the answer comes as [signal checked].
func check() -> void:
	if _request == null:
		_request = HTTPRequest.new()
		_request.timeout = TIMEOUT
		_request.request_completed.connect(_on_completed)
		add_child(_request)
	if is_busy():
		return
	var headers: PackedStringArray = [
		"Accept: application/vnd.github+json",
		"User-Agent: LadderLab/" + ReleaseCheck.current_version(),
	]
	if _request.request(ReleaseCheck.LATEST_URL, headers) != OK:
		checked.emit.call_deferred(Result.FAILED, {})
		return
	_busy = true


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		checked.emit(Result.FAILED, {})
	elif code == 404:
		# Nothing released yet.
		checked.emit(Result.LATEST, {})
	elif code != 200:
		checked.emit(Result.FAILED, {})
	else:
		var release: Dictionary = ReleaseCheck.parse_latest(body.get_string_from_utf8())
		if release.is_empty():
			checked.emit(Result.FAILED, {})
		elif ReleaseCheck.is_newer(release["version"], ReleaseCheck.current_version()):
			checked.emit(Result.NEWER, release)
		else:
			checked.emit(Result.LATEST, {})
