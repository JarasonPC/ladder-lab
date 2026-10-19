class_name UndoHistory
extends RefCounted
## Undo/redo stack of document snapshots (see [DocumentSerializer]).

const LIMIT: int = 200

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
## What the last [method record] let go: the redo stack it cleared and the
## oldest state beyond [constant LIMIT], given back by [method discard_last].
var _cleared_redo: Array[Dictionary] = []
var _dropped: Array[Dictionary] = []


## Stores the state before an edit. Clears the redo stack.
func record(snapshot: Dictionary) -> void:
	_undo.append(snapshot)
	_dropped.clear()
	if _undo.size() > LIMIT:
		_dropped.append(_undo.pop_front())
	_cleared_redo = _redo
	_redo = []


## Drops the last recorded state (for an edit that turned out to change
## nothing): what could be redone before it can be redone again.
func discard_last() -> void:
	if not _undo.is_empty():
		_undo.pop_back()
		if not _dropped.is_empty():
			_undo.push_front(_dropped[0])
		_redo = _cleared_redo
	_forget_last()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


## Returns the state to restore; [param current] becomes redoable.
func undo(current: Dictionary) -> Dictionary:
	_forget_last()
	_redo.append(current)
	return _undo.pop_back()


## Returns the state to restore; [param current] becomes undoable.
func redo(current: Dictionary) -> Dictionary:
	_forget_last()
	_undo.append(current)
	return _redo.pop_back()


func clear() -> void:
	_undo.clear()
	_redo.clear()
	_forget_last()


func _forget_last() -> void:
	_cleared_redo = []
	_dropped = []
