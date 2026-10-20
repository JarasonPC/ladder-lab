class_name Lesson
extends RefCounted
## A lesson: steps that teach drawing a circuit, each ticked by itself when
## the schematic (or the simulation) has what it asks for, and goals that
## Check proves by running a copy of the circuit (see [LessonCheck]). Texts
## are English source text, shown through tr(). No nodes.

## Saved name of the lesson (the finished lessons are remembered by it).
var id: String = ""
var title: String = ""
var summary: String = ""
## The schematic the lesson starts from (a new document each call).
var start: Callable
## The finished circuit, laid out as the steps suggest: [b]Show me[/b]
## draws its parts and wires (see [member parts]).
var solution: Callable
## Finds the part playing each role in a schematic:
## (check: LessonCheck) -> Dictionary[String, CircuitComponent].
var roles: Callable
## Role -> id of the part playing it in [member solution].
var parts: Dictionary[String, String] = {}
## Role whose place in the schematic lines the solution up with it (the
## supply the drawing starts from).
var anchor: String = ""
var steps: Array[Step] = []
var goals: Array[Goal] = []


## One step of a lesson.
class Step:
	extends RefCounted
	var title: String = ""
	var text: String = ""
	## A tip shown under the text ("" for none).
	var hint: String = ""
	## Parts the step places: [role, template of its palette entry], the
	## entry pointed at while the schematic has no part in that role.
	var places: Array[Array] = []
	## Property to set: [role, key] (the field in the properties of the
	## part in that role is pointed at while it is selected), or [].
	var property: Array = []
	## Wires to delete: [role, terminal index, role, terminal index], marked
	## on the drawing while there is a wire right between the two.
	var cut: Array[Array] = []
	## Toolbar control to point at: "simulate", "edit" or "".
	var control: String = ""
	## Roles whose parts are ringed on the drawing (wiring steps ring the
	## terminals of their [member wires] instead).
	var focus: PackedStringArray = PackedStringArray()
	## Roles drawn by Show me where the schematic does not have them yet.
	var show: PackedStringArray = PackedStringArray()
	## Wires drawn by Show me: [role, terminal index, role, terminal index].
	var wires: Array[Array] = []
	## Done while simulating only; once done it stays done (see [LessonRun]).
	var simulating: bool = false
	## (edited: LessonCheck, live: LessonCheck or null) -> bool; [param live]
	## is the simulation while simulating.
	var done: Callable


## A goal Check proves by a test run: [member phases] one after the other,
## each operating parts and then expecting parts on or off.
class Goal:
	extends RefCounted
	## English source text with %s for the designations of [member names].
	var title: String = ""
	## Roles whose designations fill [member title].
	var names: PackedStringArray = PackedStringArray()
	## Each {"do": [[role, action], ...], "wait": seconds, "wait_delay":
	## role (wait its time relay's delay as well), "expect": {role: bool}}.
	## Actions: "press", "release", "on", "off", "trip".
	var phases: Array[Dictionary] = []
	## Roles whose parts the goal needs; missing, it fails at once.
	var needs: PackedStringArray = PackedStringArray()


func _init(p_id: String, p_title: String, p_summary: String) -> void:
	id = p_id
	title = p_title
	summary = p_summary


## Designation the lesson gives the part playing [param role] (its
## designation in [member solution]).
func default_designation(role: String) -> String:
	return parts.get(role, role).get_slice(":", 0)


## Adds a step; returns it so its other fields can be set.
func step(p_title: String, p_text: String, p_done: Callable) -> Step:
	var s: Step = Step.new()
	s.title = p_title
	s.text = p_text
	s.done = p_done
	steps.append(s)
	return s


## Adds a goal titled [param p_title] (with the designations of
## [param p_names]) proved by [param p_phases].
func goal(p_title: String, p_names: Array, p_phases: Array[Dictionary], p_needs: Array) -> Goal:
	var g: Goal = Goal.new()
	g.title = p_title
	g.names = PackedStringArray(p_names)
	g.phases = p_phases
	g.needs = PackedStringArray(p_needs)
	goals.append(g)
	return g
