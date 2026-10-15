class_name UndoHistory
extends RefCounted
## Undo/redo stack of document snapshots (see [DocumentSerializer]).

const LIMIT: int = 200

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []


## Stores the state before an edit. Clears the redo stack.
func record(snapshot: Dictionary) -> void:
	_undo.append(snapshot)
	if _undo.size() > LIMIT:
		_undo.pop_front()
	_redo.clear()


## Drops the last recorded state (for an edit that turned out to change nothing).
func discard_last() -> void:
	if not _undo.is_empty():
		_undo.pop_back()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


## Returns the state to restore; [param current] becomes redoable.
func undo(current: Dictionary) -> Dictionary:
	_redo.append(current)
	return _undo.pop_back()


## Returns the state to restore; [param current] becomes undoable.
func redo(current: Dictionary) -> Dictionary:
	_undo.append(current)
	return _redo.pop_back()


func clear() -> void:
	_undo.clear()
	_redo.clear()
