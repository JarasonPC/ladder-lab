class_name LessonRun
extends RefCounted
## A lesson being taken: which of its steps are done, the step shown and
## the results of the last check. A drawing step is done while the schematic
## has what it asks for (undone again when that is deleted); a step done
## while simulating stays done. No nodes.

var lesson: Lesson
## Per step: done.
var done: Array[bool] = []
## The step shown in full (see [method follow]).
var selected: int = 0
## The schematic as last looked at (its roles), or null.
var edited: LessonCheck = null
## One per goal after a check (see [method LessonCheck.run]); [] before
## one, and again after the schematic changed.
var results: Array[Dictionary] = []
## Steps done while simulating.
var _reached: Dictionary[int, bool] = {}


func _init(p_lesson: Lesson) -> void:
	lesson = p_lesson
	done.resize(lesson.steps.size())
	done.fill(false)


## Looks at the edited schematic again: ticks or unticks its drawing steps
## and drops the results of a check made before. Returns true when a step
## changed.
func update(doc: SchematicDocument) -> bool:
	edited = LessonCheck.new(doc, lesson)
	results.clear()
	var changed: bool = false
	for i: int in lesson.steps.size():
		var s: Lesson.Step = lesson.steps[i]
		if s.simulating:
			continue
		var now: bool = bool(s.done.call(edited, null))
		if now != done[i]:
			done[i] = now
			changed = true
	return changed


## Looks at the simulation [param live] (null while editing): ticks the
## steps done while simulating, for good. Returns true when one was ticked.
func update_live(live: SchematicDocument) -> bool:
	if live == null or edited == null or not waits_for_simulation():
		return false
	var check: LessonCheck = LessonCheck.new(live, lesson)
	var changed: bool = false
	for i: int in lesson.steps.size():
		var s: Lesson.Step = lesson.steps[i]
		if s.simulating and not _reached.has(i) and bool(s.done.call(edited, check)):
			_reached[i] = true
			done[i] = true
			changed = true
	return changed


## True while a step done while simulating is not done yet.
func waits_for_simulation() -> bool:
	for i: int in lesson.steps.size():
		if lesson.steps[i].simulating and not _reached.has(i):
			return true
	return false


## The first step not done, or -1 when all are.
func current() -> int:
	return done.find(false)


func count_done() -> int:
	return done.count(true)


## Shows the first step not done (the last one when all are).
func follow() -> void:
	var at: int = current()
	selected = at if at >= 0 else lesson.steps.size() - 1


## Runs every goal on [param doc]; returns the results (see [member results]).
func check(doc: SchematicDocument) -> Array[Dictionary]:
	var c: LessonCheck = LessonCheck.new(doc, lesson)
	results.clear()
	for goal: Lesson.Goal in lesson.goals:
		results.append(c.run(goal))
	return results


## True when the last check met every goal.
func passed() -> bool:
	if results.is_empty():
		return false
	for r: Dictionary in results:
		if not r["passed"]:
			return false
	return true
