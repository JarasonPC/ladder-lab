class_name SchematicDocument
extends RefCounted
## A circuit together with its drawing: where each component sits and how each
## wire is routed. Wire routes are kept in the same order as
## [method Circuit.get_wires].
##
## The drawing has one or more pages (e.g. power circuit, control circuit,
## signalling): every component sits on one page, a wire joins terminals of
## one page, and [PageConnector]s with the same label join the pages. The
## queries for the drawing (bounds, component_at, current_paths, ...) look at
## the current [member page]; new components are added to it.

## Display name of the schematic (English source text, translated by the UI).
var title: String
var circuit: Circuit = Circuit.new()
## True after [method transpose] turned the drawing to horizontal current paths.
var horizontal: bool = false
## Simulate relays with pick-up and drop-out times (see [Armature]) rather
## than instant switching.
var realistic_timing: bool = true
## What the schematic is, chosen when it is made, for good: an industrial
## control circuit; a residential prototype (light switches, luminaires and
## sockets drawn and wired freely, to try circuits out); or a residential
## installation (the consumer unit as its single-line diagram, see
## [member single_line]). It picks the parts the palette offers.
enum Kind { INDUSTRIAL, PROTOTYPE, RESIDENTIAL }

var environment: Kind = Kind.INDUSTRIAL
## A house installation of either kind (with its floor plan) rather than an
## industrial control circuit. Set true, an industrial schematic becomes a
## residential prototype.
var residential: bool:
	get:
		return environment != Kind.INDUSTRIAL
	set(value):
		if value != residential:
			environment = Kind.PROTOTYPE if value else Kind.INDUSTRIAL
## The floors of a house installation, each its own plan: rooms, doors and
## where its parts are (each part on one of them), lowest first.
var floors: Array[FloorPlan] = [FloorPlan.new()]
## The floor shown and edited (an index into [member floors]).
var floor: int = 0
## The plan of the floor shown; set, the house has that one floor.
var floor_plan: FloorPlan:
	get:
		return floors[clampi(floor, 0, floors.size() - 1)]
	set(value):
		floors = [value]
		floor = 0


## The layers of the floor plans, in the order made (see [FloorPlan.Layer]).
var plan_layers: Array[FloorPlan.Layer] = []
## Whether the dimensions and notes are shown (their layer,
## [constant FloorPlan.ANNOTATIONS], is not among [member plan_layers]).
var annotations_shown: bool = true


## Plan layer [param layer_name], null for none.
func plan_layer(layer_name: String) -> FloorPlan.Layer:
	for layer: FloorPlan.Layer in plan_layers:
		if layer.name == layer_name:
			return layer
	return null


## Whether what is on layer [param layer_name] is drawn: on none ("") or
## on a layer there is no more, always.
func layer_shown(layer_name: String) -> bool:
	if layer_name == FloorPlan.ANNOTATIONS:
		return annotations_shown
	var layer: FloorPlan.Layer = plan_layer(layer_name)
	return layer == null or layer.shown


## Adds a plan layer named [param layer_name] (trimmed); false when the name
## is empty or taken (or the dimensions and notes' own,
## [constant FloorPlan.ANNOTATIONS]).
func add_plan_layer(layer_name: String) -> bool:
	var trimmed: String = layer_name.strip_edges().left(FloorPlan.MAX_LAYER_NAME)
	if trimmed.is_empty() or trimmed == FloorPlan.ANNOTATIONS or plan_layer(trimmed) != null:
		return false
	plan_layers.append(FloorPlan.Layer.new(trimmed))
	return true


## Renames plan layer [param old_name] [param new_name] (trimmed) and what is
## on it on every floor along; false when the new name is empty or taken.
func rename_plan_layer(old_name: String, new_name: String) -> bool:
	var trimmed: String = new_name.strip_edges().left(FloorPlan.MAX_LAYER_NAME)
	var layer: FloorPlan.Layer = plan_layer(old_name)
	if layer == null or trimmed.is_empty() or trimmed == FloorPlan.ANNOTATIONS or plan_layer(trimmed) != null:
		return false
	layer.name = trimmed
	for plan: FloorPlan in floors:
		plan.rename_layer(old_name, trimmed)
	return true


## Takes plan layer [param layer_name] away; what was on it stays, on no layer.
func remove_plan_layer(layer_name: String) -> void:
	var layer: FloorPlan.Layer = plan_layer(layer_name)
	if layer == null:
		return
	plan_layers.erase(layer)
	for plan: FloorPlan in floors:
		plan.rename_layer(layer_name, "")


## The floor part [param designation] is placed on, -1 for none.
func floor_of(designation: String) -> int:
	for i: int in floors.size():
		if floors[i].parts.has(designation):
			return i
	return -1


## The user's own symbols ([CustomSymbol]) its floor plans use, by id: a
## copy of each from the library ([SymbolLibrary]), so it opens with them
## anywhere.
var symbols: Dictionary[String, CustomSymbol] = {}


## Custom symbol [param id]: the schematic's copy, else the library's; null
## for none.
func symbol(id: String) -> CustomSymbol:
	if symbols.has(id):
		return symbols[id]
	return SymbolLibrary.shared().find(id) if not id.is_empty() else null


## Keeps a copy of [param def] (in place of an older one of its id); the
## loads drawn with it take its name.
func use_symbol(def: CustomSymbol) -> void:
	symbols[def.id] = def.copy()
	for c: CircuitComponent in circuit.get_components():
		if c is Appliance and (c as Appliance).symbol == def.id:
			(c as Appliance).title = def.name


## The custom symbols on the floor plans (marks and loads), sorted.
func used_symbols() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for plan: FloorPlan in floors:
		for mark: FloorPlan.Mark in plan.marks:
			if symbols.has(mark.symbol) and not result.has(mark.symbol):
				result.append(mark.symbol)
	for c: CircuitComponent in circuit.get_components():
		var id: String = (c as Appliance).symbol if c is Appliance else ""
		if symbols.has(id) and not result.has(id):
			result.append(id)
	result.sort()
	return result


## Parts that go on a floor plan but are on none yet.
func unplaced_parts() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for designation: String in floors[0].unplaced(circuit):
		if floor_of(designation) < 0:
			result.append(designation)
	return result


## Adds a floor over the highest one ([param below]: under the lowest, a
## basement); returns its index.
func add_floor(below: bool = false) -> int:
	var plan: FloorPlan = FloorPlan.new()
	plan.level = floors[0].level - 1 if below else floors[floors.size() - 1].level + 1
	if below:
		floors.insert(0, plan)
		floor += 1
		return 0
	floors.append(plan)
	return floors.size() - 1
## The consumer unit of a residential installation as its single-line
## diagram: the order, phases and groups of its circuits, which it wires.
var single_line: SingleLine = SingleLine.new()
## Workspace: control stations with the buttons, switches and signal lamps
## of the circuit (see [ControlBox]).
var control_boxes: Array[ControlBox] = []
## Workspace: switchboards (rozvaděč) with DIN rails holding the devices and
## terminal strips of the circuit (see [Switchboard]).
var switchboards: Array[Switchboard] = []
## Workspace: groups of parts in the field (see [WorkspaceGroup]).
var groups: Array[WorkspaceGroup] = []
## Workspace: where the parts in the field were put (designation -> position;
## see [method Workspace.field_positions] for those not put anywhere).
var field_positions: Dictionary[String, Vector2] = {}
## Keys of the keyboard that operate push buttons and switches while
## simulating: designation -> key, as [method OS.get_keycode_string] names it
## ("S", "1", "F2"); a key operates one device at most.
var key_bindings: Dictionary[String, String] = {}
## Workspace: names of the cables between places (cable key "+RA1|+ST1" ->
## name, see [WorkspaceCables]), kept so a cable keeps its name.
var cable_names: Dictionary[String, String] = {}
## What is set by hand on cables of the workspace: key ("+RA1|+ST1") ->
## {"type": type name in place of the one by use ("" for that), "section":
## mm² (0: by the current), "length": metres (0: not given)}; see
## [method set_cable]. Dropped with the cable ([method name_cables]).
var cable_settings: Dictionary[String, Dictionary] = {}
## Order of the terminals of terminal strips set in the switchboard: strip
## -> terminal labels from left to right. Terminals not listed follow in the
## order of their labels (see [method CabinetDevices.strips]).
var strip_orders: Dictionary[String, PackedStringArray] = {}
## A wiring exercise made of this schematic (opened in training mode, see
## [TrainingPlan]), null for an ordinary schematic.
var training: TrainingPlan = null
## Titles of the pages, e.g. "Power section" (shown translated, like
## [member title]); "" for an untitled page.
var pages: PackedStringArray = PackedStringArray([""])
## Texts of the title block on exported sheets (drawn by, checked by, ...).
var title_block: TitleBlock = TitleBlock.new()
## Index of the page shown and edited.
var page: int = 0:
	set(value):
		page = clampi(value, 0, pages.size() - 1)

var _placements: Dictionary[String, Placement] = {}
var _routes: Array[WireRoute] = []
## Wires of Ethernet cables and the circuit and topology they were found
## for (see [method network_wires]).
var _network_wires: Dictionary[int, bool] = {}
var _network_version: Vector2i = Vector2i(-1, -1)
## Terminal cells remembered while wires are re-routed (nothing moves
## meanwhile), see [method _reroute].
var _cell_cache: Dictionary[String, Vector2i] = {}
var _caching: bool = false


func _init(p_title: String = "") -> void:
	title = p_title


## A residential installation rewires its parts from its single-line
## diagram (see [method SingleLine.wire]); call after every edit.
func update_single_line() -> void:
	if environment == Kind.RESIDENTIAL:
		single_line.wire(self)


## Adds a component at a grid cell. Returns it, or null if the circuit refused it.
func add(component: CircuitComponent, cell: Vector2i, rotation: int = 0, mirrored: bool = false) -> CircuitComponent:
	if circuit.add(component) == null:
		return null
	_placements[component.id] = Placement.new(cell, rotation, mirrored)
	_placements[component.id].page = page
	return component


## Wires two terminals, drawn through the given grid corners.
func connect_terminals(key_a: String, key_b: String, corners: Array[Vector2i] = []) -> bool:
	if not circuit.connect_terminals(key_a, key_b):
		return false
	_routes.append(WireRoute.new(corners))
	return true


## Index of a wire between terminals [param key_a] and [param key_b] (either
## way round), or -1.
func wire_between(key_a: String, key_b: String) -> int:
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in wires.size():
		if (wires[i][0] == key_a and wires[i][1] == key_b) or (wires[i][0] == key_b and wires[i][1] == key_a):
			return i
	return -1


## Wires the pairs of terminals [param pairs] (see [method facing_pairs] and
## [method parallel_pairs]), each routed clear of those before it; pairs
## already wired are left out. Returns how many wires were added.
func connect_pairs(pairs: Array[PackedStringArray]) -> int:
	var added: PackedInt32Array = PackedInt32Array()
	for pair: PackedStringArray in pairs:
		if pair[0] != pair[1] and wire_between(pair[0], pair[1]) < 0 and connect_terminals(pair[0], pair[1]):
			added.append(get_wire_count() - 1)
	_reroute(added)
	return added.size()


## Free terminals (without wires) that face each other straight along a
## column or row with nothing between them, so that one straight wire would
## join them: [key_a, key_b] pairs, each terminal in one pair at most. Pairs
## of terminals of components [param ids], with each other or with those of
## [param others]. A terminal without a lead (a supply point) is met from
## any side. Only the page of the first of [param ids] counts. With
## [param wired_too] terminals that already have wires pair as well, unless
## the two are on one net already; the way may then run along the wires of
## either end's net.
func facing_pairs(ids: PackedStringArray, others: PackedStringArray = PackedStringArray(), wired_too: bool = false) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	var own: Dictionary[String, bool] = {}
	var allowed: Dictionary[String, bool] = {}
	for given: String in ids:
		var c: CircuitComponent = circuit.get_component(given)
		if c != null and not (c is Junction):
			own[c.id] = true
			allowed[c.id] = true
	for given: String in others:
		var c: CircuitComponent = circuit.get_component(given)
		if c != null and not (c is Junction):
			allowed[c.id] = true
	if own.is_empty():
		return result
	var cached: bool = _caching
	_caching = true
	var wired: Dictionary[String, bool] = {}
	for wire: PackedStringArray in circuit.get_wires():
		wired[wire[0]] = true
		wired[wire[1]] = true
	var on_page: int = _placements[own.keys()[0]].page
	var cells: Dictionary[Vector2i, Array] = {}
	var parts: Array[CircuitComponent] = components_on_page(on_page)
	for c: CircuitComponent in parts:
		for key: String in c.get_terminal_keys():
			var at: Vector2i = terminal_cell(key)
			if not cells.has(at):
				cells[at] = []
			cells[at].append(key)
	var nets: Dictionary[String, int] = _terminal_nets()
	var router: WireRouter = _router(on_page, nets, {})
	# An Ethernet port pairs with another port only.
	var ports: Dictionary[String, bool] = CabinetDevices.network_keys(circuit)
	# A net no terminal or wire has: anything of another net is in the way.
	var lone: int = 1 << 30
	var used: Dictionary[String, bool] = {}
	for c: CircuitComponent in parts:
		if not allowed.has(c.id):
			continue
		for key: String in c.get_terminal_keys():
			var out: Vector2i = terminal_outward(key)
			if out == Vector2i.ZERO or (wired.has(key) and not wired_too) or used.has(key):
				continue
			var start: Vector2i = terminal_cell(key)
			var cell: Vector2i = start + out
			while router.has_cell(cell) and not cells.has(cell):
				cell += out
			if not cells.has(cell):
				continue
			# The first terminal straight ahead must face back, unless it
			# has no lead.
			for other: String in cells[cell]:
				var partner: CircuitComponent = circuit.get_terminal_owner(other)
				var back: Vector2i = terminal_outward(other)
				if partner == c or not allowed.has(partner.id) or not (own.has(c.id) or own.has(partner.id)):
					continue
				if (wired.has(other) and not wired_too) or used.has(other) or (back != -out and back != Vector2i.ZERO) or ports.has(key) != ports.has(other):
					continue
				var net_a: int = nets.get(key, lone)
				var net_b: int = nets.get(other, lone)
				if net_a != lone and net_a == net_b:
					# Joined already.
					break
				var way: Array[Vector2i] = [start, cell]
				if router.is_clear(way, net_a) or (net_b != net_a and router.is_clear(way, net_b)):
					result.append(PackedStringArray([key, other]))
					used[key] = true
					used[other] = true
				break
	_caching = cached
	if not cached:
		_cell_cache.clear()
	return result


## Terminals of two parts drawn on one cell of page [param on_page] (-1: the
## current page) that are not connected (not on one net, not supply points
## of one conductor): they look joined but are not. [key_a, key_b] pairs.
func overlapping_terminals(on_page: int = -1) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	var nets: Dictionary[String, int] = _terminal_nets()
	var cells: Dictionary[Vector2i, Array] = {}
	for c: CircuitComponent in components_on_page(on_page):
		for key: String in c.get_terminal_keys():
			var at: Vector2i = terminal_cell(key)
			if not cells.has(at):
				cells[at] = []
			for other: String in cells[at]:
				var owner: CircuitComponent = circuit.get_terminal_owner(other)
				if owner == c or (nets.has(key) and nets.get(other, -1) == nets[key]):
					continue
				if c is PowerSupply and owner is PowerSupply and (c as PowerSupply).conductor == (owner as PowerSupply).conductor:
					continue
				result.append(PackedStringArray([other, key]))
			cells[at].append(key)
	return result


## The straight wires [method facing_pairs] would give [param component],
## not in the drawing, placed at [param cell] on the current page, with every
## part there: from terminal cell to terminal cell. Empty when its id or a
## terminal is taken. The drawing is left as it was.
func facing_wires_placed(component: CircuitComponent, cell: Vector2i, rotation: int = 0, mirrored: bool = false) -> Array[PackedVector2Array]:
	var wires: Array[PackedVector2Array] = []
	if circuit.has_component_id(component.id) or Array(component.get_terminal_keys()).any(func(key: String) -> bool: return circuit.has_terminal(key)):
		return wires
	add(component, cell, rotation, mirrored)
	var ids: PackedStringArray = PackedStringArray()
	for c: CircuitComponent in components_on_page():
		ids.append(c.id)
	for pair: PackedStringArray in facing_pairs(PackedStringArray([component.id]), ids):
		wires.append(PackedVector2Array([Vector2(terminal_cell(pair[0])), Vector2(terminal_cell(pair[1]))]))
	circuit.remove(component)
	_placements.erase(component.id)
	return wires


## Wires that go along with one from terminal [param key_a] to
## [param key_b] between multi-pole parts: the free terminals beside each
## end in its row (its column, for terminals leaving sideways) that leave
## the same way, paired off in order from the two ends (FA1:2 to KM1:1
## brings FA1:4 to KM1:3 and FA1:6 to KM1:5). Beside a supply point stand
## the free supply points in line with it across the way the wire leaves
## the other end. Empty for two terminals of one part.
func parallel_pairs(key_a: String, key_b: String) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	var owner_a: CircuitComponent = circuit.get_terminal_owner(key_a)
	var owner_b: CircuitComponent = circuit.get_terminal_owner(key_b)
	if owner_a == null or owner_b == null or owner_a == owner_b:
		return result
	var out_a: Vector2i = terminal_outward(key_a)
	var out_b: Vector2i = terminal_outward(key_b)
	if out_a == Vector2i.ZERO and out_b == Vector2i.ZERO:
		return result
	var wired: Dictionary[String, bool] = {}
	for wire: PackedStringArray in circuit.get_wires():
		wired[wire[0]] = true
		wired[wire[1]] = true
	var row_a: PackedStringArray = _pole_row(key_a, out_a if out_a != Vector2i.ZERO else out_b, wired)
	var row_b: PackedStringArray = _pole_row(key_b, out_b if out_b != Vector2i.ZERO else out_a, wired)
	var ia: int = row_a.find(key_a)
	var ib: int = row_b.find(key_b)
	var ports: Dictionary[String, bool] = CabinetDevices.network_keys(circuit)
	for k: int in range(-mini(ia, ib), mini(row_a.size() - ia, row_b.size() - ib)):
		var a: String = row_a[ia + k]
		var b: String = row_b[ib + k]
		if k != 0 and a != key_b and b != key_a and a != b and ports.has(a) == ports.has(b):
			result.append(PackedStringArray([a, b]))
	return result


## Terminal [param key] and the free terminals in line with it across
## [param out] (the way a wire leaves there), in order along the line: those
## of its part leaving the same way, or for a supply point the other supply
## points of its page.
func _pole_row(key: String, out: Vector2i, wired: Dictionary[String, bool]) -> PackedStringArray:
	var owner: CircuitComponent = circuit.get_terminal_owner(key)
	var along: int = 0 if out.x == 0 else 1
	var line: int = terminal_cell(key)[1 - along]
	var own_out: Vector2i = terminal_outward(key)
	var parts: Array[CircuitComponent] = [owner]
	if owner is PowerSupply:
		parts = components_on_page(_placements[owner.id].page).filter(func(c: CircuitComponent) -> bool: return c is PowerSupply)
	var row: Array[String] = []
	for c: CircuitComponent in parts:
		for other: String in c.get_terminal_keys():
			if other == key or (not wired.has(other) and terminal_outward(other) == own_out and terminal_cell(other)[1 - along] == line):
				row.append(other)
	row.sort_custom(func(a: String, b: String) -> bool: return terminal_cell(a)[along] < terminal_cell(b)[along])
	return PackedStringArray(row)


## Sets the schematic title and the title block texts (both stripped of
## surrounding spaces). Returns false when nothing changed.
func set_title_block(new_title: String, block: TitleBlock) -> bool:
	var cleaned: TitleBlock = TitleBlock.from_data(block.to_data())
	new_title = new_title.strip_edges()
	if new_title == title and cleaned.equals(title_block):
		return false
	title = new_title
	title_block = cleaned
	return true


func get_placement(component_id: String) -> Placement:
	return _placements.get(_id(component_id), null)


## Exact id for an id or a designation ("S1" -> "S1:13-14"), see
## [method Circuit.get_component].
func _id(component_id: String) -> String:
	var c: CircuitComponent = circuit.get_component(component_id)
	return c.id if c != null else component_id


func get_route(wire_index: int) -> WireRoute:
	return _routes[wire_index]


func get_wire_count() -> int:
	return _routes.size()


## Grid cell of a terminal.
func terminal_cell(key: String) -> Vector2i:
	if _caching and _cell_cache.has(key):
		return _cell_cache[key]
	var owner: CircuitComponent = circuit.get_terminal_owner(key)
	var p: Placement = _placements[owner.id]
	var local: Vector2i = SymbolGeometry.local_terminals(owner)[_terminal_name(owner, key)]
	var cell: Vector2i = p.cell + SymbolGeometry.transform_cell(local, p)
	if _caching:
		_cell_cache[key] = cell
	return cell


## Full polyline of a wire: start terminal, corners, end terminal.
func wire_points(wire_index: int) -> Array[Vector2i]:
	var wire: PackedStringArray = circuit.get_wires()[wire_index]
	var given: Array[Vector2i] = [terminal_cell(wire[0])]
	given.append_array(_routes[wire_index].corners)
	given.append(terminal_cell(wire[1]))
	# Wires run across and down only: a step that goes both ways (a route
	# made without its corners) turns at a corner, across first.
	var points: Array[Vector2i] = [given[0]]
	for k: int in range(1, given.size()):
		var a: Vector2i = points[points.size() - 1]
		var b: Vector2i = given[k]
		if a.x != b.x and a.y != b.y:
			points.append(Vector2i(b.x, a.y))
		points.append(b)
	return points


## Clickable body of a component in grid units.
func component_body(component: CircuitComponent) -> Rect2:
	var p: Placement = _placements[component.id]
	var r: Rect2 = SymbolGeometry.transform_rect(SymbolGeometry.local_body(component), p)
	r.position += Vector2(p.cell)
	return r


## Topmost component of page [param on_page] (-1: the current page) whose
## body contains [param point] (grid units), or null.
func component_at(point: Vector2, on_page: int = -1) -> CircuitComponent:
	var p: int = page if on_page < 0 else on_page
	var components: Array[CircuitComponent] = circuit.get_components()
	for i: int in range(components.size() - 1, -1, -1):
		if _placements[components[i].id].page == p and component_body(components[i]).has_point(point):
			return components[i]
	return null


## Bounding box of all symbols and wires of page [param on_page] (-1: the
## current page), in grid units.
func bounds(on_page: int = -1) -> Rect2:
	var r: Rect2 = Rect2()
	var first: bool = true
	for c: CircuitComponent in components_on_page(on_page):
		var body: Rect2 = component_body(c)
		r = body if first else r.merge(body)
		first = false
	for w: int in wires_on_page(on_page):
		for p: Vector2i in wire_points(w):
			r = r.expand(Vector2(p))
	return r


## Grid positions of the numbered current paths of page [param on_page] (-1:
## the current page): x of each column when the drawing is vertical, y of each
## row when it is horizontal. Every two-terminal symbol marks the midpoint
## between its terminals; positions closer than [param merge] cells count as
## one path.
func current_paths(merge: float = 2.0, on_page: int = -1) -> PackedFloat32Array:
	var coordinates: Array[float] = []
	for c: CircuitComponent in components_on_page(on_page):
		var keys: PackedStringArray = c.get_terminal_keys()
		if keys.size() < 2:
			continue
		var center: Vector2 = (Vector2(terminal_cell(keys[0])) + Vector2(terminal_cell(keys[1]))) * 0.5
		coordinates.append(center.y if horizontal else center.x)
	coordinates.sort()
	var paths: PackedFloat32Array = PackedFloat32Array()
	var group_start: float = 0.0
	var group_sum: float = 0.0
	var group_count: int = 0
	for value: float in coordinates:
		if group_count > 0 and value - group_start > merge:
			paths.append(group_sum / group_count)
			group_count = 0
		if group_count == 0:
			group_start = value
			group_sum = 0.0
		group_sum += value
		group_count += 1
	if group_count > 0:
		paths.append(group_sum / group_count)
	return paths


## Cells of page [param on_page] (-1: the current page) where three or more wire or lead
## directions of one net meet at a wire's end or corner, drawn as dots (a plain crossing is not
## a connection, nor are wires of other nets running over the cell).
func junction_cells(on_page: int = -1) -> Array[Vector2i]:
	var on: PackedInt32Array = wires_on_page(on_page)
	var wires: Array[PackedStringArray] = circuit.get_wires()
	# Nets of the page: wires joined at shared terminals or by page connectors.
	var nets: UnionFind = UnionFind.new(on.size())
	var first_of_key: Dictionary[String, int] = {}
	for n: int in on.size():
		for key: String in wires[on[n]]:
			if first_of_key.has(key):
				nets.union(n, first_of_key[key])
			else:
				first_of_key[key] = n
	for link: PackedStringArray in circuit.get_links():
		if first_of_key.has(link[0]) and first_of_key.has(link[1]):
			nets.union(first_of_key[link[0]], first_of_key[link[1]])
	# Directions at (cell, net); wires of different nets never join.
	var directions: Dictionary[Vector3i, int] = {}
	# Cells where a wire starts, ends or turns: only there do wires connect.
	# Two wires merely crossing each other get no dot.
	var vertices: Dictionary[Vector3i, bool] = {}
	var net_of_key: Dictionary[String, int] = {}
	for n: int in on.size():
		var i: int = on[n]
		var net: int = nets.find(n)
		net_of_key[wires[i][0]] = net
		net_of_key[wires[i][1]] = net
		var points: Array[Vector2i] = wire_points(i)
		for p: Vector2i in points:
			vertices[Vector3i(p.x, p.y, net)] = true
		for s: int in range(1, points.size()):
			var a: Vector2i = points[s - 1]
			var b: Vector2i = points[s]
			if a == b:
				continue
			var unit: Vector2i = (b - a).sign()
			var cell: Vector2i = a
			while true:
				var at: Vector3i = Vector3i(cell.x, cell.y, net)
				var bits: int = directions.get(at, 0)
				if cell != b:
					bits |= SymbolGeometry.direction_of(unit)
				if cell != a:
					bits |= SymbolGeometry.direction_of(-unit)
				directions[at] = bits
				if cell == b:
					break
				cell += unit
	for c: CircuitComponent in components_on_page(on_page):
		var p: Placement = _placements[c.id]
		var names: PackedStringArray = c.get_terminal_names()
		var keys: PackedStringArray = c.get_terminal_keys()
		for t: int in names.size():
			var lead: int = SymbolGeometry.local_lead_direction(c, names[t])
			if lead == 0 or not net_of_key.has(keys[t]):
				continue
			var cell: Vector2i = terminal_cell(keys[t])
			var at: Vector3i = Vector3i(cell.x, cell.y, net_of_key[keys[t]])
			if directions.has(at):
				directions[at] |= SymbolGeometry.transform_direction(lead, p)
	var found: Dictionary[Vector2i, bool] = {}
	for at: Vector3i in directions:
		var bits: int = directions[at]
		var count: int = (bits & 1) + ((bits >> 1) & 1) + ((bits >> 2) & 1) + ((bits >> 3) & 1)
		if count >= 3 and vertices.has(at):
			found[Vector2i(at.x, at.y)] = true
	var result: Array[Vector2i] = []
	result.assign(found.keys())
	return result


## Swaps rows and columns of the whole drawing, turning vertical current paths
## into horizontal ones and back. The circuit itself is unchanged.
func transpose() -> void:
	for id: String in _placements:
		var p: Placement = _placements[id]
		# Transpose = mirror then a quarter turn back: T * R(r) * M^m = R(3 - r) * M^(m + 1).
		p.cell = Vector2i(p.cell.y, p.cell.x)
		p.rotation = posmod(3 - p.rotation, 4)
		p.mirrored = not p.mirrored
		# Markings dragged beside a part stay beside it.
		for key: String in p.labels:
			p.labels[key] = Vector2(p.labels[key].y, p.labels[key].x)
	for route: WireRoute in _routes:
		for i: int in route.corners.size():
			route.corners[i] = Vector2i(route.corners[i].y, route.corners[i].x)
		for end: int in route.number_offsets.size():
			route.number_offsets[end] = Vector2(route.number_offsets[end].y, route.number_offsets[end].x)
	horizontal = not horizontal


## True when most parts of two or more terminals lie across (turned a
## quarter), as on a drawing of horizontal current paths, whatever
## [member horizontal] says; false when most stand upright or there are none.
func drawn_horizontal() -> bool:
	var across: int = 0
	var upright: int = 0
	for c: CircuitComponent in circuit.get_components():
		if c.get_terminal_keys().size() < 2:
			continue
		if _placements[c.id].rotation % 2 == 1:
			across += 1
		else:
			upright += 1
	return across > upright


# --- Pages -------------------------------------------------------------------

## Page a component is drawn on.
func page_of(component_id: String) -> int:
	return _placements[_id(component_id)].page


## Page wire [param index] is drawn on (that of its terminals).
func wire_page(index: int) -> int:
	return _placements[circuit.get_terminal_owner(circuit.get_wires()[index][0]).id].page


## Components drawn on page [param on_page] (-1: the current page).
func components_on_page(on_page: int = -1) -> Array[CircuitComponent]:
	var p: int = page if on_page < 0 else on_page
	var result: Array[CircuitComponent] = []
	for c: CircuitComponent in circuit.get_components():
		if _placements[c.id].page == p:
			result.append(c)
	return result


## Indices of the wires drawn on page [param on_page] (-1: the current page).
func wires_on_page(on_page: int = -1) -> PackedInt32Array:
	var p: int = page if on_page < 0 else on_page
	var result: PackedInt32Array = PackedInt32Array()
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in wires.size():
		if _placements[circuit.get_terminal_owner(wires[i][0]).id].page == p:
			result.append(i)
	return result


## Inserts a page titled [param page_title] at [param at] (-1: after the last
## one). Returns its index; the current page stays the same page.
func add_page(page_title: String, at: int = -1) -> int:
	var index: int = pages.size() if at < 0 or at > pages.size() else at
	for p: Placement in _placements.values():
		if p.page >= index:
			p.page += 1
	var shown: int = page + 1 if page >= index else page
	pages.insert(index, page_title.strip_edges())
	page = shown
	return index


func rename_page(index: int, page_title: String) -> void:
	if index >= 0 and index < pages.size():
		pages[index] = page_title.strip_edges()


## Removes page [param index] with everything drawn on it. The last page
## cannot be removed. Returns false when nothing was removed.
func remove_page(index: int) -> bool:
	if pages.size() <= 1 or index < 0 or index >= pages.size():
		return false
	for c: CircuitComponent in components_on_page(index):
		if circuit.has_component_id(c.id):
			remove_component(c.id)
	for p: Placement in _placements.values():
		if p.page > index:
			p.page -= 1
	var shown: int = page - 1 if page > index else page
	pages.remove_at(index)
	page = shown
	return true


## Moves page [param index] to place [param to] (clamped); the current page
## moves along.
func move_page(index: int, to: int) -> void:
	if index < 0 or index >= pages.size():
		return
	to = clampi(to, 0, pages.size() - 1)
	if to == index:
		return
	var order: Array[int] = []
	for i: int in pages.size():
		order.append(i)
	order.remove_at(index)
	order.insert(to, index)
	var new_index: PackedInt32Array = PackedInt32Array()
	new_index.resize(pages.size())
	var titles: PackedStringArray = PackedStringArray()
	for i: int in order.size():
		new_index[order[i]] = i
		titles.append(pages[order[i]])
	pages = titles
	for p: Placement in _placements.values():
		p.page = new_index[p.page]
	page = new_index[page]


## Title of page [param index] as shown: its title, else [param untitled]
## formatted with the page number (e.g. "Page %d").
func page_name(index: int, untitled: String = "Page %d") -> String:
	return pages[index] if not pages[index].is_empty() else untitled % (index + 1)


## Number (from 1) of the current path of page [param on_page] nearest to the
## grid coordinate [param at] (x when vertical, y when horizontal), or 0 when
## the page has none.
func path_number(on_page: int, at: float) -> int:
	var paths: PackedFloat32Array = current_paths(2.0, on_page)
	var best: int = 0
	for i: int in paths.size():
		if best == 0 or absf(paths[i] - at) < absf(paths[best - 1] - at):
			best = i + 1
	return best


## Where page connector [param component_id] continues: the other connectors
## with the same label as {"page": index, "path": number (0: none), "id": id},
## in page order.
func connector_targets(component_id: String) -> Array[Dictionary]:
	var me: CircuitComponent = circuit.get_component(component_id)
	var result: Array[Dictionary] = []
	if not (me is PageConnector) or (me as PageConnector).label.is_empty():
		return result
	for c: CircuitComponent in circuit.get_components():
		if c == me or not (c is PageConnector) or (c as PageConnector).label != (me as PageConnector).label:
			continue
		var p: Placement = _placements[c.id]
		result.append({"page": p.page, "path": path_number(p.page, float(p.cell.y if horizontal else p.cell.x)), "id": c.id})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["page"] < b["page"] or (a["page"] == b["page"] and a["path"] < b["path"]))
	return result


## Cross reference written at page connector [param component_id]: where
## it continues, as "/page.path" per connector (e.g. "/2.4"), or "".
func connector_reference(component_id: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for target: Dictionary in connector_targets(component_id):
		parts.append("/%d.%d" % [target["page"] + 1, target["path"]] if target["path"] > 0 else "/%d" % (target["page"] + 1))
	return ", ".join(parts)


## Label for a new page connector: that of a connector on another page that
## has no partner yet (the new one continues it), else a free number.
func next_connector_label() -> String:
	var count: Dictionary[String, int] = {}
	var page_of_label: Dictionary[String, int] = {}
	var highest: int = 0
	for c: CircuitComponent in circuit.get_components():
		if c is PageConnector:
			var label: String = (c as PageConnector).label
			count[label] = count.get(label, 0) + 1
			page_of_label[label] = _placements[c.id].page
			if label.is_valid_int():
				highest = maxi(highest, int(label))
	for label: String in count:
		if not label.is_empty() and count[label] == 1 and page_of_label[label] != page:
			return label
	for route: WireRoute in _routes:
		if route.number.is_valid_int():
			highest = maxi(highest, int(route.number))
	return str(highest + 1)


# --- Editing -----------------------------------------------------------------

const AXIS_NONE: int = -1
const AXIS_HORIZONTAL: int = 0
const AXIS_VERTICAL: int = 1
## How much worse (in [WireRouter] costs) than the best route a re-routed
## wire's own shape may be before the best route replaces it.
const RESHAPE: int = 3 * WireRouter.STEP + WireRouter.BEND


func remove_wire(index: int) -> void:
	circuit.remove_wire(index)
	_routes.remove_at(index)


## Index of the segment of wire [param index] under [param point] (segment k
## runs from wire_points()[k] to [k + 1]), or -1.
func wire_segment_at(index: int, point: Vector2, tolerance: float = 0.35) -> int:
	var points: Array[Vector2i] = wire_points(index)
	for k: int in range(points.size() - 1):
		var a: Vector2 = Vector2(points[k])
		var b: Vector2 = Vector2(points[k + 1])
		if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) <= tolerance:
			return k
	return -1


## Moves segment [param segment] of wire [param index] sideways by
## [param offset] cells, starting from the route [param points] the wire had
## when the drag began (so a drag can be updated as the mouse moves). The
## terminal ends stay where they are: new corners are added next to them, and
## corners that end up in a straight line are merged.
func drag_wire_segment(index: int, points: Array[Vector2i], segment: int, offset: Vector2i) -> void:
	if segment < 0 or segment + 1 >= points.size():
		return
	var a: Vector2i = points[segment]
	var b: Vector2i = points[segment + 1]
	var shift: Vector2i = Vector2i(0, offset.y) if a.y == b.y else Vector2i(offset.x, 0)
	var moved: Array[Vector2i] = points.duplicate()
	var last: int = points.size() - 1
	if segment + 1 == last:
		moved.insert(last, b + shift)
	else:
		moved[segment + 1] = b + shift
	if segment == 0:
		moved.insert(1, a + shift)
	else:
		moved[segment] = a + shift
	var simple: Array[Vector2i] = _simplify_path(moved)
	_routes[index].corners = simple.slice(1, simple.size() - 1)


## Drops repeated points and points in the middle of a straight run.
static func _simplify_path(points: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for p: Vector2i in points:
		if result.is_empty() or result[result.size() - 1] != p:
			result.append(p)
	var i: int = 1
	while i < result.size() - 1:
		var prev: Vector2i = result[i - 1]
		var next: Vector2i = result[i + 1]
		if (prev.x == result[i].x and next.x == result[i].x) or (prev.y == result[i].y and next.y == result[i].y):
			result.remove_at(i)
		else:
			i += 1
	return result


## Wires of the net of wire [param index]: all wires joined to it through
## shared terminals (junctions, terminal blocks, component terminals) and
## page connectors, on any page.
func wire_net(index: int) -> PackedInt32Array:
	var wires: Array[PackedStringArray] = circuit.get_wires()
	var by_key: Dictionary[String, PackedInt32Array] = {}
	for i: int in wires.size():
		for key: String in wires[i]:
			if not by_key.has(key):
				by_key[key] = PackedInt32Array()
			by_key[key].append(i)
	# Page connectors with the same label carry the net on to other pages.
	var linked: Dictionary[String, PackedStringArray] = {}
	for link: PackedStringArray in circuit.get_links():
		for end: int in 2:
			if not linked.has(link[end]):
				linked[link[end]] = PackedStringArray()
			linked[link[end]].append(link[1 - end])
	var seen: Dictionary[int, bool] = {index: true}
	var seen_keys: Dictionary[String, bool] = {}
	var queue: PackedInt32Array = PackedInt32Array([index])
	while not queue.is_empty():
		var w: int = queue[queue.size() - 1]
		queue.remove_at(queue.size() - 1)
		var keys: PackedStringArray = wires[w].duplicate()
		var k: int = 0
		while k < keys.size():
			var key: String = keys[k]
			k += 1
			if seen_keys.has(key):
				continue
			seen_keys[key] = true
			keys.append_array(linked.get(key, PackedStringArray()))
			for other: int in by_key.get(key, PackedInt32Array()):
				if not seen.has(other):
					seen[other] = true
					queue.append(other)
	var result: PackedInt32Array = PackedInt32Array(seen.keys())
	result.sort()
	return result


## Wires of Ethernet cables: those whose net reaches the port of a PLC or a
## network switch (kept until the wiring changes).
func network_wires() -> Dictionary[int, bool]:
	var version: Vector2i = Vector2i(circuit.get_instance_id(), circuit.topology_version)
	if _network_version == version:
		return _network_wires
	_network_version = version
	_network_wires = {}
	var ports: Dictionary[String, bool] = CabinetDevices.network_keys(circuit)
	if ports.is_empty():
		return _network_wires
	var net: Dictionary[String, int] = CabinetDevices.nets(circuit)
	var port_nets: Dictionary[int, bool] = {}
	for key: String in ports:
		port_nets[net[key]] = true
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for w: int in wires.size():
		if port_nets.has(net.get(wires[w][0], -1)):
			_network_wires[w] = true
	return _network_wires


## Gives the whole net of wire [param index] the number [param number]; its
## page connectors take the number as their label (an empty number leaves
## them as they are).
func set_wire_number(index: int, number: String) -> void:
	var net: PackedInt32Array = wire_net(index)
	for w: int in net:
		_routes[w].number = number.strip_edges()
	if not number.strip_edges().is_empty():
		_label_connectors(net, number.strip_edges())


## Gives the page connectors on the wires [param net] the label [param label].
func _label_connectors(net: PackedInt32Array, label: String) -> void:
	for w: int in net:
		for key: String in circuit.get_wires()[w]:
			var owner: CircuitComponent = circuit.get_terminal_owner(key)
			if owner is PageConnector and (owner as PageConnector).label != label:
				circuit.set_connector_label(owner as PageConnector, label)


## Wires up to this long (in cells) show their number only once.
const SHORT_WIRE: float = 2.0
## Distance (in cells) along the wire from its terminal to the wire number:
## right next to the terminal square.
const NUMBER_GAP: float = 0.4


## Wire ends of page [param on_page] (-1: the current page) that show their wire number, as
## Vector2i(wire, end): ends on components and terminal blocks (not junctions
## or page connectors, which show it themselves), one per terminal; a short
## wire shows its number once, at its upper (or left) end.
func wire_number_ends(on_page: int = -1) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var written: Dictionary[String, bool] = {}
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for w: int in wires_on_page(on_page):
		if _routes[w].number.is_empty() or _path_length(w) == 0.0:
			continue
		var ends: Array[int] = []
		for end: int in 2:
			var key: String = wires[w][end]
			var owner: CircuitComponent = circuit.get_terminal_owner(key)
			if not (owner is Junction or owner is PageConnector) and not written.has(key):
				written[key] = true
				ends.append(end)
		if ends.size() == 2 and _path_length(w) <= SHORT_WIRE:
			var points: Array[Vector2i] = wire_points(w)
			var first: Vector2i = points[0]
			var last: Vector2i = points[points.size() - 1]
			ends.clear()
			ends.append(1 if last.y < first.y or (last.y == first.y and last.x < first.x) else 0)
		for end: int in ends:
			result.append(Vector2i(w, end))
	return result


## Grid point the number of wire end [param end] is written at: right next
## to its terminal, [constant NUMBER_GAP] along the wire (never past the
## middle of a very short wire), plus the offset the user dragged it by.
func wire_number_point(index: int, end: int) -> Vector2:
	var points: Array[Vector2i] = wire_points(index)
	var along: float = minf(NUMBER_GAP, _path_length(index) * 0.5)
	if end == 1:
		points.reverse()
	var p: Vector2 = Vector2(points[0])
	for i: int in range(1, points.size()):
		var step: float = Vector2(points[i] - points[i - 1]).length()
		if along <= step or i == points.size() - 1:
			p = Vector2(points[i - 1]) + Vector2(points[i] - points[i - 1]).normalized() * minf(along, step)
			break
		along -= step
	return p + _routes[index].number_offsets[end]


## True when the wire leaves end [param end] vertically (the number is
## written beside it), false when horizontally (written above it).
func wire_number_vertical(index: int, end: int) -> bool:
	return wire_number_direction(index, end).x == 0


## Direction (one grid step) in which the wire leaves its terminal at end
## [param end]; down for a wire without length.
func wire_number_direction(index: int, end: int) -> Vector2i:
	var points: Array[Vector2i] = wire_points(index)
	if end == 1:
		points.reverse()
	for i: int in range(1, points.size()):
		if points[i] != points[0]:
			return (points[i] - points[0]).sign()
	return Vector2i.DOWN


## Moves the number at wire end [param end] by [param offset] cells from its
## standard place.
func set_wire_number_offset(index: int, end: int, offset: Vector2) -> void:
	_routes[index].number_offsets[end] = offset


func _path_length(index: int) -> float:
	var points: Array[Vector2i] = wire_points(index)
	var length: float = 0.0
	for i: int in range(1, points.size()):
		length += Vector2(points[i] - points[i - 1]).length()
	return length


## Numbers every net from [param first] on, in drawing order (page by page,
## current path by current path); nets fed straight from a supply (L, N, ...)
## and Ethernet cables (between the ports of PLCs and switches) stay
## unnumbered. A net running over several pages (through page
## connectors) gets one number, which its connectors take as their label.
func number_wires(first: int = 1) -> void:
	var done: Dictionary[int, bool] = {}
	var nets: Array[PackedInt32Array] = []
	for i: int in circuit.get_wires().size():
		if not done.has(i):
			var net: PackedInt32Array = wire_net(i)
			for w: int in net:
				done[w] = true
			nets.append(net)
	var order: Callable = func(net: PackedInt32Array) -> Vector3i:
		var best: Vector3i = Vector3i(2147483647, 2147483647, 2147483647)
		for w: int in net:
			var on_page: int = wire_page(w)
			for p: Vector2i in wire_points(w):
				var k: Vector3i = Vector3i(on_page, p.y, p.x) if horizontal else Vector3i(on_page, p.x, p.y)
				if k < best:
					best = k
		return best
	nets.sort_custom(func(a: PackedInt32Array, b: PackedInt32Array) -> bool:
		return order.call(a) < order.call(b))
	var supplied: Array[bool] = []
	var numbered_keys: Dictionary[String, bool] = {}
	var ports: Dictionary[String, bool] = CabinetDevices.network_keys(circuit)
	for net: PackedInt32Array in nets:
		var fed: bool = false
		for w: int in net:
			for key: String in circuit.get_wires()[w]:
				if circuit.get_terminal_owner(key) is PowerSupply or ports.has(key):
					fed = true
		supplied.append(fed)
		if not fed:
			for w: int in net:
				for key: String in circuit.get_wires()[w]:
					numbered_keys[key] = true
	# Connectors that keep their label (on a supplied net or on no wire)
	# would join a net given that label as its number: those numbers are skipped.
	var kept_labels: Dictionary[String, bool] = {}
	for c: CircuitComponent in circuit.get_components():
		if c is PageConnector and not numbered_keys.has(c.get_terminal_keys()[0]):
			kept_labels[(c as PageConnector).label] = true
	var n: int = first
	for i: int in nets.size():
		var net: PackedInt32Array = nets[i]
		if not supplied[i]:
			while kept_labels.has(str(n)):
				n += 1
		for w: int in net:
			_routes[w].number = "" if supplied[i] else str(n)
		if not supplied[i]:
			_label_connectors(net, str(n))
			n += 1


## Removes a component together with its wires.
func remove_component(component_id: String) -> void:
	var c: CircuitComponent = circuit.get_component(component_id)
	if c == null:
		return
	for i: int in circuit.remove(c):
		_routes.remove_at(i)
	_placements.erase(c.id)
	if circuit.get_component(c.designation) == null:
		_forget_device(c.designation)


## Drops what the keys and the workspace keep of device [param designation]
## once its last part is gone, so a new part given that name starts afresh:
## its key, its place in the field, its group and its part in a mechanical link.
func _forget_device(designation: String) -> void:
	key_bindings.erase(designation)
	field_positions.erase(designation)
	for plan: FloorPlan in floors:
		plan.remove(designation)
	single_line.remove(designation)
	for group: WorkspaceGroup in groups:
		_leave_group(group, designation)


## Takes [param designation] out of [param group], with its part in the
## group's mechanical link (as drive or as a stop).
func _leave_group(group: WorkspaceGroup, designation: String) -> void:
	var members: PackedStringArray = group.members
	if members.has(designation):
		members.remove_at(members.find(designation))
		group.members = members
	if group.drive == designation:
		group.drive = ""
	group.stops.erase(designation)


## Moves components by [param delta] cells. Wires between two moved
## components move along; wires with one moved end are re-routed, and so are
## wires the moved components now cover (see [method _reroute]).
func move_components(ids: PackedStringArray, delta: Vector2i) -> void:
	var moved: Dictionary[String, bool] = {}
	var moved_keys: Dictionary[String, bool] = {}
	for given: String in ids:
		var id: String = _id(given)
		_placements[id].cell += delta
		moved[id] = true
		for key: String in circuit.get_component(id).get_terminal_keys():
			moved_keys[key] = true
	var rerouted: PackedInt32Array = PackedInt32Array()
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in wires.size():
		var a: bool = moved_keys.has(wires[i][0])
		var b: bool = moved_keys.has(wires[i][1])
		if a and b:
			for k: int in _routes[i].corners.size():
				_routes[i].corners[k] += delta
		elif a or b:
			rerouted.append(i)
	_reroute(rerouted, moved)


## Where components [param ids] and all wire corners are before a drag, for
## [method drag_components].
func drag_start(ids: PackedStringArray) -> Dictionary:
	var cells: Dictionary[String, Vector2i] = {}
	for given: String in ids:
		var id: String = _id(given)
		if _placements.has(id):
			cells[id] = _placements[id].cell
	var corners: Array[Array] = []
	for route: WireRoute in _routes:
		corners.append(route.corners.duplicate())
	return {"cells": cells, "corners": corners}


## Moves the components of [param start] (from [method drag_start]) by
## [param delta] cells from where they were when the drag began, so a drag can
## be updated as the mouse moves: wires are re-routed from their routes at the
## start, never from a route of an earlier mouse position, and moving back
## puts everything back as it was.
func drag_components(start: Dictionary, delta: Vector2i) -> void:
	var cells: Dictionary[String, Vector2i] = start["cells"]
	for id: String in cells:
		_placements[id].cell = cells[id]
	var corners: Array[Array] = start["corners"]
	for i: int in mini(corners.size(), _routes.size()):
		var saved: Array[Vector2i] = []
		saved.assign(corners[i])
		_routes[i].corners = saved
	if delta != Vector2i.ZERO:
		move_components(PackedStringArray(cells.keys()), delta)


## Turns a component a quarter turn clockwise (or counterclockwise) about
## its first terminal.
func rotate_component(component_id: String, clockwise: bool = true) -> void:
	component_id = _id(component_id)
	_turn(component_id, clockwise)
	_reroute_component(component_id)


func _turn(component_id: String, clockwise: bool) -> void:
	var p: Placement = _placements[component_id]
	p.rotation = posmod(p.rotation + (1 if clockwise else -1), 4)


## Turns components [param ids] together a quarter turn clockwise (or
## counterclockwise) about the middle of their terminals, so they keep their
## places to each other: wires between them turn along, the others are
## re-routed. Four turns (or a turn back) put everything back where it was.
## A single component turns as in [method rotate_component].
func rotate_components(ids: PackedStringArray, clockwise: bool = true) -> void:
	if ids.size() == 1:
		rotate_component(ids[0], clockwise)
		return
	var twice: Vector2i = _turn_pivot(ids)
	var sum: int = (twice.x + twice.y) / 2
	var difference: int = (twice.y - twice.x) / 2
	var map: Callable = func(v: Vector2i) -> Vector2i:
		return Vector2i(sum - v.y, difference + v.x) if clockwise else Vector2i(v.y - difference, sum - v.x)
	_transform_components(ids, func(id: String) -> void: _turn(id, clockwise), map)


## Mirrors components [param ids] together left to right as seen on the
## drawing (each symbol mirrored, their order reversed); a single component
## as in [method mirror_component].
func mirror_components(ids: PackedStringArray) -> void:
	if ids.size() == 1:
		mirror_component(ids[0])
		return
	var span: Rect2i = _terminal_span(ids)
	var twice: int = span.position.x * 2 + span.size.x
	_transform_components(ids, _mirror, func(v: Vector2i) -> Vector2i: return Vector2i(twice - v.x, v.y))


## Mirrors components [param ids] together top to bottom as seen on the
## drawing; a single component as in [method flip_component].
func flip_components(ids: PackedStringArray) -> void:
	if ids.size() == 1:
		flip_component(ids[0])
		return
	var span: Rect2i = _terminal_span(ids)
	var twice: int = span.position.y * 2 + span.size.y
	_transform_components(ids, _flip, func(v: Vector2i) -> Vector2i: return Vector2i(v.x, twice - v.y))


## The cells component [param c] takes on the drawing: its body and its
## terminals, out to whole cells.
func component_cells(c: CircuitComponent) -> Rect2i:
	var r: Rect2 = component_body(c)
	for cell: Vector2i in _anchors(c).values():
		r = r.expand(Vector2(cell))
	var start: Vector2i = Vector2i(floori(r.position.x), floori(r.position.y))
	return Rect2i(start, Vector2i(ceili(r.end.x), ceili(r.end.y)) - start)


## The cells components [param ids] (junctions left out) would take lined up
## by [method line_up], in their order along the line: the first stays where it
## is, the others follow [param spacing] free cells apart, their first
## terminals in line with the first's (same column for [param vertical], same
## row otherwise). Keys are component ids.
func line_up_cells(ids: PackedStringArray, vertical: bool, spacing: int) -> Dictionary[String, Rect2i]:
	var axis: int = 1 if vertical else 0
	var across: int = 1 - axis
	var parts: Array[CircuitComponent] = []
	for given: String in ids:
		var c: CircuitComponent = circuit.get_component(given)
		if c != null and not (c is Junction):
			parts.append(c)
	# Along the line as they stand now, by their middles.
	var middles: Dictionary[String, Vector2] = {}
	for c: CircuitComponent in parts:
		middles[c.id] = Rect2(component_cells(c)).get_center()
	parts.sort_custom(func(a: CircuitComponent, b: CircuitComponent) -> bool:
		if middles[a.id][axis] != middles[b.id][axis]:
			return middles[a.id][axis] < middles[b.id][axis]
		if middles[a.id][across] != middles[b.id][across]:
			return middles[a.id][across] < middles[b.id][across]
		return a.id < b.id)
	var result: Dictionary[String, Rect2i] = {}
	if parts.is_empty():
		return result
	var line: int = (_anchors(parts[0]).values()[0] as Vector2i)[across]
	var next: int = component_cells(parts[0]).position[axis]
	for c: CircuitComponent in parts:
		var cells: Rect2i = component_cells(c)
		var shift: Vector2i = Vector2i.ZERO
		shift[axis] = next - cells.position[axis]
		shift[across] = line - (_anchors(c).values()[0] as Vector2i)[across]
		result[c.id] = Rect2i(cells.position + shift, cells.size)
		next += cells.size[axis] + spacing
	return result


## Lines components [param ids] up in a column ([param vertical]) or a row,
## [param spacing] free cells apart (see [method line_up_cells]). Wires
## between two parts moved alike move along, the others of the moved parts
## are re-routed.
func line_up(ids: PackedStringArray, vertical: bool, spacing: int) -> void:
	var shifts: Dictionary[String, Vector2i] = {}
	var cells: Dictionary[String, Rect2i] = line_up_cells(ids, vertical, spacing)
	for id: String in cells:
		var shift: Vector2i = cells[id].position - component_cells(circuit.get_component(id)).position
		if shift != Vector2i.ZERO:
			shifts[id] = shift
	var moved: Dictionary[String, bool] = {}
	var keys: Dictionary[String, Vector2i] = {}
	for id: String in shifts:
		_placements[id].cell += shifts[id]
		moved[id] = true
		for key: String in circuit.get_component(id).get_terminal_keys():
			keys[key] = shifts[id]
	var rerouted: PackedInt32Array = PackedInt32Array()
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in wires.size():
		var a: bool = keys.has(wires[i][0])
		var b: bool = keys.has(wires[i][1])
		if a and b and keys[wires[i][0]] == keys[wires[i][1]]:
			for k: int in _routes[i].corners.size():
				_routes[i].corners[k] += keys[wires[i][0]]
		elif a or b:
			rerouted.append(i)
	_reroute(rerouted, moved)


## Twice the point components [param ids] turn about: the middle of their
## terminals. Turning must land on cells, so the point's x and y must be both
## whole or both halves; when the middle is not, the terminal nearest to it
## (by key on a tie). Turning about a point keeps it where it is and every
## distance to it, so the next turn picks the same point again.
func _turn_pivot(ids: PackedStringArray) -> Vector2i:
	var span: Rect2i = _terminal_span(ids)
	var middle: Vector2i = span.position * 2 + span.size
	if (middle.x + middle.y) % 2 == 0:
		return middle
	var nearest: Vector2i = Vector2i.ZERO
	var nearest_key: String = ""
	var nearest_distance: int = 1 << 30
	for given: String in ids:
		var anchors: Dictionary[String, Vector2i] = _anchors(circuit.get_component(given))
		for key: String in anchors:
			var twice: Vector2i = anchors[key] * 2
			var distance: int = (twice - middle).length_squared()
			if distance < nearest_distance or (distance == nearest_distance and key < nearest_key):
				nearest = twice
				nearest_key = key
				nearest_distance = distance
	return nearest


## Cells spanned by the terminals of components [param ids] (see [method _anchors]).
func _terminal_span(ids: PackedStringArray) -> Rect2i:
	var span: Rect2i = Rect2i()
	var first: bool = true
	for given: String in ids:
		for cell: Vector2i in _anchors(circuit.get_component(given)).values():
			span = Rect2i(cell, Vector2i.ZERO) if first else span.expand(cell)
			first = false
	return span


## Cells that place component [param c] when parts are turned together: its
## terminals (by key), or for a part without terminals (an overload relay
## without poles) the cell it is placed at (by its id).
func _anchors(c: CircuitComponent) -> Dictionary[String, Vector2i]:
	var result: Dictionary[String, Vector2i] = {}
	for key: String in c.get_terminal_keys():
		result[key] = terminal_cell(key)
	if result.is_empty():
		result[c.id] = _placements[c.id].cell
	return result


## Turns or mirrors each of components [param ids] in place ([param change]
## on its id), then moves it so its terminals land where [param map] takes
## them; corners of wires between them are mapped too, the other wires of
## the components re-routed.
func _transform_components(ids: PackedStringArray, change: Callable, map: Callable) -> void:
	var moved: Dictionary[String, bool] = {}
	var keys: Dictionary[String, bool] = {}
	for given: String in ids:
		var c: CircuitComponent = circuit.get_component(given)
		moved[c.id] = true
		for k: String in c.get_terminal_keys():
			keys[k] = true
	# Wires between them keep the shape they are drawn in (also where a
	# route without its corners is drawn across first).
	var rerouted: PackedInt32Array = PackedInt32Array()
	var along: Dictionary[int, Array] = {}
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in wires.size():
		var a: bool = keys.has(wires[i][0])
		var b: bool = keys.has(wires[i][1])
		if a and b:
			var points: Array[Vector2i] = wire_points(i)
			along[i] = points.slice(1, points.size() - 1)
		elif a or b:
			rerouted.append(i)
	for id: String in moved:
		# Its first terminal (or its cell) lands where the map takes it.
		var c: CircuitComponent = circuit.get_component(id)
		var target: Vector2i = map.call(_anchors(c).values()[0])
		change.call(id)
		_placements[id].cell += target - (_anchors(c).values()[0] as Vector2i)
	for i: int in along:
		var corners: Array[Vector2i] = []
		for corner: Vector2i in along[i]:
			corners.append(map.call(corner))
		_routes[i].corners = corners
	_reroute(rerouted, moved)


## Makes lead [param index] of a component end in a strip terminal labelled
## [param label] (drawn instead of the terminal square); "" removes it.
func set_strip_terminal(component_id: String, index: int, label: String) -> void:
	var p: Placement = _placements[_id(component_id)]
	if label.strip_edges().is_empty():
		p.strips.erase(index)
		p.labels.erase("strip:%d" % index)
	else:
		p.strips[index] = label.strip_edges()


## Next free number for a strip terminal: one more than the highest number
## among the terminals on wires and on leads.
func next_strip_label() -> String:
	var highest: int = 0
	for c: CircuitComponent in circuit.get_components():
		if c is TerminalBlock and (c as TerminalBlock).label.is_valid_int():
			highest = maxi(highest, int((c as TerminalBlock).label))
		for label: String in _placements[c.id].strips.values():
			if label.is_valid_int():
				highest = maxi(highest, int(label))
	return str(highest + 1)


## Moves a marking of a component (see [member Placement.labels]) by
## [param offset] cells from its standard place.
func set_label_offset(component_id: String, key: String, offset: Vector2) -> void:
	var p: Placement = _placements[_id(component_id)]
	if offset == Vector2.ZERO:
		p.labels.erase(key)
	else:
		p.labels[key] = offset


## Mirrors a component left to right as seen on the drawing. A vertical
## symbol is mirrored across its own axis (actuator to the other side, the
## terminals stay); a horizontal one swaps its ends in place.
func mirror_component(component_id: String) -> void:
	component_id = _id(component_id)
	_mirror(component_id)
	_reroute_component(component_id)


func _mirror(component_id: String) -> void:
	if _placements[component_id].rotation % 2 == 0:
		_mirror_across_axis(component_id)
	else:
		_swap_ends(component_id)


## Mirrors a component top to bottom as seen on the drawing: a vertical
## symbol swaps its upper and lower terminals in place, a horizontal one is
## mirrored across its own axis.
func flip_component(component_id: String) -> void:
	component_id = _id(component_id)
	_flip(component_id)
	_reroute_component(component_id)


func _flip(component_id: String) -> void:
	if _placements[component_id].rotation % 2 == 0:
		_swap_ends(component_id)
	else:
		_mirror_across_axis(component_id)


func _mirror_across_axis(component_id: String) -> void:
	var p: Placement = _placements[component_id]
	# The mirror flips local x before rotation, so the symbol axis (local y)
	# and both terminals stay where they are; only the side marks swap.
	p.mirrored = not p.mirrored


## Mirrors local y about the symbol's middle, so its first and last
## terminals swap places.
func _swap_ends(component_id: String) -> void:
	var p: Placement = _placements[component_id]
	var height: int = 0
	for cell: Vector2i in SymbolGeometry.local_terminals(circuit.get_component(component_id)).values():
		height = maxi(height, cell.y)
	# Mirroring y = mirroring x and a half turn; shift so the ends swap.
	p.cell += SymbolGeometry.transform_cell(Vector2i(0, height), p)
	p.mirrored = not p.mirrored
	p.rotation = (p.rotation + 2) % 4


## Replaces a component (e.g. after its properties were edited) keeping its
## placement and wiring. Returns false if the circuit refused it.
func replace_component(old_id: String, new_component: CircuitComponent) -> bool:
	var old: CircuitComponent = circuit.get_component(old_id)
	if old == null:
		return false
	old_id = old.id
	# Terminals keep their wires by their standard name (a motor of another
	# kind keeps its PE, a cam switch with more positions its 1-6, another
	# CPU size moves a PLC's outputs), the others by position where no name
	# took it (a PLC's only by name). Wires on terminals the new component
	# no longer has go away.
	var new_count: int = new_component.get_terminal_keys().size()
	var old_keys: PackedStringArray = old.get_terminal_keys()
	var new_names: PackedStringArray = new_component.default_terminal_names()
	var old_names: PackedStringArray = old.default_terminal_names()
	var mapping: PackedInt32Array = PackedInt32Array()
	mapping.resize(old_keys.size())
	var taken: Dictionary[int, bool] = {}
	for k: int in old_keys.size():
		mapping[k] = new_names.find(old_names[k]) if k < old_names.size() else -1
		if mapping[k] >= 0:
			taken[mapping[k]] = true
	if not (old is Plc and new_component is Plc):
		for k: int in old_keys.size():
			if mapping[k] < 0 and k < new_count and not taken.has(k):
				mapping[k] = k
				taken[k] = true
	for i: int in range(circuit.get_wires().size() - 1, -1, -1):
		var wire: PackedStringArray = circuit.get_wires()[i]
		for k: int in old_keys.size():
			if mapping[k] < 0 and wire.has(old_keys[k]):
				remove_wire(i)
				break
	var p: Placement = _placements[old_id]
	# Where its terminals and its body are, to see whether its wires must be
	# re-routed.
	var before: Array[Vector2i] = _terminal_cells(old, p)
	var body: Rect2 = component_body(old)
	if not circuit.replace(old, new_component, mapping):
		return false
	# Strip terminals on its leads and the dragged markings of its terminals
	# follow their terminal.
	var strips: Dictionary[int, String] = {}
	for index: int in p.strips:
		if index < mapping.size() and mapping[index] >= 0:
			strips[mapping[index]] = p.strips[index]
	p.strips = strips
	var labels: Dictionary[String, Vector2] = {}
	for key: String in p.labels:
		var parts: PackedStringArray = key.split(":")
		if parts.size() == 2 and (parts[0] == "terminal" or parts[0] == "strip") and parts[1].is_valid_int():
			var index: int = int(parts[1])
			if index >= 0 and index < mapping.size() and mapping[index] >= 0:
				labels["%s:%d" % [parts[0], mapping[index]]] = p.labels[key]
		else:
			labels[key] = p.labels[key]
	p.labels = labels
	_placements.erase(old_id)
	_placements[new_component.id] = p
	# Only a part whose terminals or body moved (other poles, modules, ...)
	# has its wires re-routed: a plain edit leaves the drawing as it is.
	if _terminal_cells(new_component, p) != before or component_body(new_component) != body:
		_reroute_component(new_component.id)
	if new_component.designation != old.designation and circuit.get_component(old.designation) == null:
		# The last part of the device was renamed: the stations, switchboards,
		# the workspace and its key follow (see the rename functions for a
		# device that had the new name already, or is of another kind now).
		rename_control_device(old.designation, new_component.designation)
		rename_cabinet_device(old.designation, new_component.designation)
		rename_field_device(old.designation, new_component.designation)
		for plan: FloorPlan in floors:
			plan.rename(old.designation, new_component.designation)
		single_line.rename(old.designation, new_component.designation)
		if key_bindings.has(old.designation):
			var key: String = key_bindings[old.designation]
			key_bindings.erase(old.designation)
			if not key_bindings.has(new_component.designation) and can_have_key(new_component.designation):
				key_bindings[new_component.designation] = key
	return true


## Grid cells of the terminals of [param c] placed by [param p], in the
## order of its terminals.
static func _terminal_cells(c: CircuitComponent, p: Placement) -> Array[Vector2i]:
	var local: Dictionary[String, Vector2i] = SymbolGeometry.local_terminals(c)
	var cells: Array[Vector2i] = []
	for name: String in c.get_terminal_names():
		cells.append(p.cell + SymbolGeometry.transform_cell(local[name], p))
	return cells


## Where a wire drawn onto wire [param index] at [param cell] is joined: the
## end of that wire nearer along it (a part's terminal before a junction),
## with the cells from [param cell] along the wire to it, so the new wire
## branches off where it was drawn to: {"key": String, "cells":
## Array[Vector2i]}. Empty when the cell is not on the wire.
func branch_end(index: int, cell: Vector2i) -> Dictionary:
	var points: Array[Vector2i] = wire_points(index)
	var wire: PackedStringArray = circuit.get_wires()[index]
	var last: int = points.size() - 1
	if cell == points[0]:
		return {"key": wire[0], "cells": [cell] as Array[Vector2i]}
	if cell == points[last]:
		return {"key": wire[1], "cells": [cell] as Array[Vector2i]}
	for s: int in range(1, points.size()):
		if not _on_segment(cell, points[s - 1], points[s]):
			continue
		var back: Array[Vector2i] = [cell]
		for i: int in range(s - 1, -1, -1):
			back.append(points[i])
		var ahead: Array[Vector2i] = [cell]
		ahead.append_array(points.slice(s))
		var back_part: bool = not (circuit.get_terminal_owner(wire[0]) is Junction)
		var ahead_part: bool = not (circuit.get_terminal_owner(wire[1]) is Junction)
		var take_back: bool = _cells_length(back) <= _cells_length(ahead)
		if back_part != ahead_part:
			take_back = back_part
		if take_back:
			return {"key": wire[0], "cells": back}
		return {"key": wire[1], "cells": ahead}
	return {}


static func _cells_length(cells: Array[Vector2i]) -> int:
	var length: int = 0
	for i: int in range(1, cells.size()):
		length += absi(cells[i].x - cells[i - 1].x) + absi(cells[i].y - cells[i - 1].y)
	return length


## Inserts a [Junction] at [param cell] on wire [param index], splitting the
## wire in two. Returns the junction terminal key ("" if the cell is not on
## the wire). At an end of the wire the existing terminal key is returned.
func split_wire(index: int, cell: Vector2i, point: CircuitComponent = null) -> String:
	var points: Array[Vector2i] = wire_points(index)
	var wire: PackedStringArray = circuit.get_wires()[index]
	if cell == points[0]:
		return wire[0]
	if cell == points[points.size() - 1]:
		return wire[1]
	var segment: int = -1
	for s: int in range(1, points.size()):
		if _on_segment(cell, points[s - 1], points[s]):
			segment = s
			break
	if segment < 0:
		return ""
	# A new junction, or the given single-terminal component (a terminal block).
	var junction: CircuitComponent = point if point != null else Junction.new(next_designation("J"))
	add(junction, cell)
	_placements[junction.id].page = wire_page(index)
	var corners_a: Array[Vector2i] = points.slice(1, segment)
	var corners_b: Array[Vector2i] = points.slice(segment, points.size() - 1)
	if not corners_a.is_empty() and corners_a[corners_a.size() - 1] == cell:
		corners_a.remove_at(corners_a.size() - 1)
	if not corners_b.is_empty() and corners_b[0] == cell:
		corners_b.remove_at(0)
	var key_a: String = wire[0]
	var key_b: String = wire[1]
	var number: String = _routes[index].number
	remove_wire(index)
	connect_terminals(key_a, junction.designation, corners_a)
	connect_terminals(junction.designation, key_b, corners_b)
	_routes[_routes.size() - 1].number = number
	_routes[_routes.size() - 2].number = number
	return junction.designation


## Removes junctions that no longer join anything: without wires they go,
## with one wire the dangling stub goes too, with two wires the wires are
## merged back into one.
func cleanup_junctions() -> void:
	var changed: bool = true
	while changed:
		changed = false
		for c: CircuitComponent in circuit.get_components().duplicate():
			if not (c is Junction):
				continue
			var wires: PackedInt32Array = circuit.wires_of(c)
			if wires.size() == 2:
				_merge_at_junction(c, wires)
			elif wires.size() > 2:
				continue
			else:
				remove_component(c.id)
			changed = true
			break


## Replaces the junctions of drawings made before wires were joined terminal
## to terminal: the wires of each one are joined to the end nearest along
## them (a part's terminal before a junction), each running its old way to
## the junction and on along the wire to that end, so the drawing looks the
## same, the branch dot drawn where the junction was.
func remove_junctions() -> void:
	var left: bool = true
	while left:
		left = false
		for c: CircuitComponent in circuit.get_components():
			if c is Junction:
				_dissolve_junction(c)
				left = true
				break


func _dissolve_junction(junction: CircuitComponent) -> void:
	var ends: PackedStringArray = PackedStringArray()
	# Cells from the junction out to each end.
	var paths: Array[Array] = []
	var number: String = ""
	for w: int in circuit.wires_of(junction):
		var pair: PackedStringArray = circuit.get_wires()[w]
		var points: Array[Vector2i] = wire_points(w)
		if pair[1] == junction.designation:
			points.reverse()
		ends.append(pair[1] if pair[0] == junction.designation else pair[0])
		paths.append(points)
		if number.is_empty():
			number = _routes[w].number
	var anchor: int = -1
	for i: int in ends.size():
		if anchor < 0:
			anchor = i
			continue
		var part: bool = not (circuit.get_terminal_owner(ends[i]) is Junction)
		var anchor_part: bool = not (circuit.get_terminal_owner(ends[anchor]) is Junction)
		if part != anchor_part:
			if part:
				anchor = i
		elif _cells_length(paths[i]) < _cells_length(paths[anchor]):
			anchor = i
	remove_component(junction.id)
	for i: int in ends.size():
		if i == anchor or ends[i] == ends[anchor] or wire_between(ends[i], ends[anchor]) >= 0:
			continue
		var route: Array[Vector2i] = []
		route.assign(paths[i])
		route.reverse()
		route.append_array(paths[anchor].slice(1))
		var clean: Array[Vector2i] = orthogonalize(route)
		connect_terminals(ends[i], ends[anchor], clean.slice(1, clean.size() - 1))
		_routes[get_wire_count() - 1].number = number


## Re-routes a wire so all segments are horizontal or vertical. Each end that
## belongs to a symbol first leaves one cell straight out along the symbol
## axis. If that route would cross a symbol (e.g. after turning a symbol by
## 180 degrees), run over a terminal of another net or along a wire of
## another net, run over itself (a corner left behind by the moved end) or
## is clearly worse than the best route, the cheapest route a [WireRouter]
## finds is used instead: clean, with few corners and few crossings.
func normalize_route(index: int) -> void:
	_reroute(PackedInt32Array([index]))


## Re-routes wires [param indices] one after another (see
## [method normalize_route]): each keeps off those routed before it, while
## the old routes of those still to come are no obstacle. After them come
## the other wires that now run through one of components [param moved]
## (just moved or turned) or over its terminals, and those moved along with
## them: each is re-routed if its route is no longer clear.
func _reroute(indices: PackedInt32Array, moved: Dictionary[String, bool] = {}) -> void:
	if _caching:
		_route_all(indices, moved)
		return
	_caching = true
	_route_all(indices, moved)
	_caching = false
	_cell_cache.clear()


func _route_all(indices: PackedInt32Array, moved: Dictionary[String, bool]) -> void:
	var order: PackedInt32Array = indices.duplicate()
	if not moved.is_empty():
		order.append_array(_covered_wires(indices, moved))
	if order.is_empty():
		return
	var nets: Dictionary[String, int] = _terminal_nets()
	var wires: Array[PackedStringArray] = circuit.get_wires()
	var pending: Dictionary[int, bool] = {}
	for i: int in order:
		pending[i] = true
	var routers: Dictionary[int, WireRouter] = {}
	for k: int in order.size():
		var i: int = order[k]
		if not pending.has(i):
			continue
		var on: int = wire_page(i)
		if not routers.has(on):
			routers[on] = _router(on, nets, pending)
		var net: int = nets[wires[i][0]]
		_route_wire(i, routers[on], net, k < indices.size())
		pending.erase(i)
		routers[on].add_wire(wire_points(i), net)


## Wires but [param skip] that have both ends on components [param moved],
## or run through one of them or over one of its terminals.
func _covered_wires(skip: PackedInt32Array, moved: Dictionary[String, bool]) -> PackedInt32Array:
	var keys: Dictionary[String, bool] = {}
	var cells: Dictionary[Vector2i, String] = {}
	var bodies: Array[Rect2] = []
	var pages: Dictionary[int, bool] = {}
	for id: String in moved:
		var c: CircuitComponent = circuit.get_component(id)
		pages[_placements[id].page] = true
		for key: String in c.get_terminal_keys():
			keys[key] = true
			cells[terminal_cell(key)] = key
		var obstacle: Rect2 = _obstacle(c)
		if obstacle.has_area():
			bodies.append(obstacle)
	var result: PackedInt32Array = PackedInt32Array()
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in wires.size():
		if skip.has(i) or not pages.has(wire_page(i)):
			continue
		var wire: PackedStringArray = wires[i]
		if keys.has(wire[0]) and keys.has(wire[1]):
			result.append(i)
			continue
		var points: Array[Vector2i] = wire_points(i)
		var covered: bool = false
		for s: int in range(1, points.size()):
			var a: Vector2i = points[s - 1]
			var b: Vector2i = points[s]
			for body: Rect2 in bodies:
				if _crosses(a, b, body):
					covered = true
			for cell: Vector2i in cells:
				if _on_segment(cell, a, b) and not wire.has(cells[cell]):
					covered = true
			if covered:
				result.append(i)
				break
	return result


## True if the straight segment [param a]-[param b] crosses the inside of
## [param body].
static func _crosses(a: Vector2i, b: Vector2i, body: Rect2) -> bool:
	if a.x == b.x:
		return float(a.x) > body.position.x and float(a.x) < body.end.x and float(maxi(a.y, b.y)) > body.position.y and float(mini(a.y, b.y)) < body.end.y
	return float(a.y) > body.position.y and float(a.y) < body.end.y and float(maxi(a.x, b.x)) > body.position.x and float(mini(a.x, b.x)) < body.end.x


## Re-routes wire [param index]: its shape stays while clean (and, if
## [param reshape], about as good as the best route).
func _route_wire(index: int, router: WireRouter, net: int, reshape: bool) -> void:
	var wire: PackedStringArray = circuit.get_wires()[index]
	var points: Array[Vector2i] = wire_points(index)
	var start: Vector2i = points[0]
	var end: Vector2i = points[points.size() - 1]
	if start == end:
		_routes[index].corners = []
		return
	var out_a: Vector2i = terminal_outward(wire[0])
	var out_b: Vector2i = terminal_outward(wire[1])
	# The corners it has, not the ones wire_points adds to a route without
	# them, which only fit where its ends were.
	var path: Array[Vector2i] = [start]
	if out_a != Vector2i.ZERO:
		path.append(start + out_a)
	path.append_array(_routes[index].corners)
	if out_b != Vector2i.ZERO:
		path.append(end + out_b)
	path.append(end)
	var best: Array[Vector2i] = orthogonalize(path, terminal_axis(wire[0]), terminal_axis(wire[1]))
	var clear: bool = _route_simple(best) and router.is_clear(best, net)
	if not clear or reshape:
		var found: Array[Vector2i] = router.find(start, end, out_a, out_b, net)
		if not found.is_empty():
			found = _simplify_path(found)
			if not clear or router.cost(best, net, out_a, out_b) > router.cost(found, net, out_a, out_b) + RESHAPE:
				best = found
	_routes[index].corners = best.slice(1, best.size() - 1)


## A [WireRouter] for page [param on_page] knowing its symbols, terminals
## and wires (but those of [param pending]).
func _router(on_page: int, nets: Dictionary[String, int], pending: Dictionary[int, bool]) -> WireRouter:
	var components: Array[CircuitComponent] = components_on_page(on_page)
	var on: PackedInt32Array = wires_on_page(on_page)
	var area: Rect2i = Rect2i()
	var first: bool = true
	for c: CircuitComponent in components:
		var body: Rect2 = component_body(c)
		var cells: Rect2i = Rect2i(Vector2i(body.position.floor()), Vector2i.ZERO).expand(Vector2i(body.end.ceil()))
		area = cells if first else area.merge(cells)
		first = false
		for key: String in c.get_terminal_keys():
			area = area.expand(terminal_cell(key))
	for w: int in on:
		for p: Vector2i in wire_points(w):
			area = area.expand(p)
	var router: WireRouter = WireRouter.new(area)
	# Terminals without wires are nets of their own.
	var single: int = circuit.get_wires().size()
	for c: CircuitComponent in components:
		for key: String in c.get_terminal_keys():
			router.add_terminal(terminal_cell(key), nets.get(key, single))
			if not nets.has(key):
				single += 1
		var obstacle: Rect2 = _obstacle(c)
		if obstacle.has_area():
			router.add_body(obstacle)
	var wires: Array[PackedStringArray] = circuit.get_wires()
	for w: int in on:
		if not pending.has(w):
			router.add_wire(wire_points(w), nets[wires[w][0]])
	return router


## What wires keep off of a component: its body. Junctions and terminals on a
## wire have none (wires keep off their terminal); supplies and page
## connectors only the part beyond their terminal (their circle or tag).
func _obstacle(c: CircuitComponent) -> Rect2:
	if c is Junction or c is TerminalBlock:
		return Rect2()
	var body: Rect2 = component_body(c)
	if not (c is PowerSupply or c is PageConnector):
		return body
	var at: Vector2 = Vector2(terminal_cell(c.get_terminal_keys()[0]))
	# Cut the body off half a cell before the terminal, on the side the
	# terminal is nearest to.
	var gaps: Array[float] = [at.x - body.position.x, body.end.x - at.x, at.y - body.position.y, body.end.y - at.y]
	var side: int = gaps.find(gaps.min())
	match side:
		0:
			body = Rect2(Vector2(at.x + 0.5, body.position.y), Vector2(body.end.x - at.x - 0.5, body.size.y))
		1:
			body = Rect2(body.position, Vector2(at.x - 0.5 - body.position.x, body.size.y))
		2:
			body = Rect2(Vector2(body.position.x, at.y + 0.5), Vector2(body.size.x, body.end.y - at.y - 0.5))
		_:
			body = Rect2(body.position, Vector2(body.size.x, at.y - 0.5 - body.position.y))
	return body if body.size.x > 0.0 and body.size.y > 0.0 else Rect2()


## Net number of every terminal on a wire: wires joined at shared terminals
## or by page connectors have the same one.
func _terminal_nets() -> Dictionary[String, int]:
	var wires: Array[PackedStringArray] = circuit.get_wires()
	var nets: UnionFind = UnionFind.new(wires.size())
	var first: Dictionary[String, int] = {}
	for i: int in wires.size():
		for key: String in wires[i]:
			if first.has(key):
				nets.union(i, first[key])
			else:
				first[key] = i
	for link: PackedStringArray in circuit.get_links():
		if first.has(link[0]) and first.has(link[1]):
			nets.union(first[link[0]], first[link[1]])
	var result: Dictionary[String, int] = {}
	for key: String in first:
		result[key] = nets.find(first[key])
	return result


static func _route_simple(points: Array[Vector2i]) -> bool:
	var seen: Dictionary[Vector2i, bool] = {points[0]: true}
	for s: int in range(1, points.size()):
		var cell: Vector2i = points[s - 1]
		var unit: Vector2i = (points[s] - cell).sign()
		while cell != points[s]:
			cell += unit
			if seen.has(cell):
				return false
			seen[cell] = true
	return true


## Axis along which wires should leave a terminal, or AXIS_NONE.
func terminal_axis(key: String) -> int:
	var out: Vector2i = terminal_outward(key)
	if out == Vector2i.ZERO:
		return AXIS_NONE
	return AXIS_VERTICAL if out.x == 0 else AXIS_HORIZONTAL


## Unit step pointing away from the symbol at a terminal, or zero for
## supplies and junctions.
func terminal_outward(key: String) -> Vector2i:
	var owner: CircuitComponent = circuit.get_terminal_owner(key)
	var lead: int = SymbolGeometry.local_lead_direction(owner, _terminal_name(owner, key))
	if lead == 0:
		return Vector2i.ZERO
	match SymbolGeometry.transform_direction(lead, _placements[owner.id]):
		SymbolGeometry.DIR_UP:
			return Vector2i.DOWN
		SymbolGeometry.DIR_DOWN:
			return Vector2i.UP
		SymbolGeometry.DIR_LEFT:
			return Vector2i.RIGHT
	return Vector2i.LEFT


## Makes a polyline orthogonal by inserting elbows and drops duplicate and
## collinear points. The first and last point are kept. An elbow keeps going
## the way the previous segment went unless that would turn back; at the start
## (no previous segment) [param start_axis] decides, at the end [param end_axis].
static func orthogonalize(points: Array[Vector2i], start_axis: int = AXIS_NONE, end_axis: int = AXIS_NONE) -> Array[Vector2i]:
	var out: Array[Vector2i] = [points[0]]
	for s: int in range(1, points.size()):
		var p: Vector2i = out[out.size() - 1]
		var q: Vector2i = points[s]
		if p.x != q.x and p.y != q.y:
			var previous: Vector2i = Vector2i.ZERO
			if out.size() >= 2:
				previous = (p - out[out.size() - 2]).sign()
			var vertical_first: bool = false
			if previous.y != 0:
				vertical_first = signi(q.y - p.y) == previous.y
			elif previous.x != 0:
				vertical_first = signi(q.x - p.x) != previous.x
			elif s == 1 and start_axis != AXIS_NONE:
				vertical_first = start_axis == AXIS_VERTICAL
			elif s == points.size() - 1 and end_axis != AXIS_NONE:
				vertical_first = end_axis == AXIS_HORIZONTAL
			out.append(Vector2i(p.x, q.y) if vertical_first else Vector2i(q.x, p.y))
		out.append(q)
	var cleaned: Array[Vector2i] = [out[0]]
	for i: int in range(1, out.size()):
		var q: Vector2i = out[i]
		if q == cleaned[cleaned.size() - 1] and i < out.size() - 1:
			continue
		while cleaned.size() >= 2:
			var a: Vector2i = cleaned[cleaned.size() - 2]
			var b: Vector2i = cleaned[cleaned.size() - 1]
			if (a.x == b.x and b.x == q.x) or (a.y == b.y and b.y == q.y) or b == q:
				cleaned.remove_at(cleaned.size() - 1)
			else:
				break
		cleaned.append(q)
	return cleaned


# --- Queries for the editor ----------------------------------------------------

## Key of the terminal of the current page nearest to [param point] (grid
## units) within [param radius], or "".
func terminal_at(point: Vector2, radius: float = 0.4) -> String:
	var best: String = ""
	var best_distance: float = radius
	for c: CircuitComponent in components_on_page():
		for key: String in c.get_terminal_keys():
			var d: float = point.distance_to(Vector2(terminal_cell(key)))
			if d <= best_distance:
				best_distance = d
				best = key
	return best


## Index of the wire of page [param on_page] (-1: the current page) nearest to
## [param point] within [param tolerance], or -1.
func wire_at(point: Vector2, tolerance: float = 0.3, on_page: int = -1) -> int:
	var best: int = -1
	var best_distance: float = tolerance
	for i: int in wires_on_page(on_page):
		var points: Array[Vector2i] = wire_points(i)
		for s: int in range(1, points.size()):
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, Vector2(points[s - 1]), Vector2(points[s]))
			var d: float = point.distance_to(closest)
			if d <= best_distance:
				best_distance = d
				best = i
	return best


## Grid cell on wire [param index] nearest to [param point].
func wire_cell_near(index: int, point: Vector2) -> Vector2i:
	var points: Array[Vector2i] = wire_points(index)
	var best: Vector2i = points[0]
	var best_distance: float = INF
	for s: int in range(1, points.size()):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, Vector2(points[s - 1]), Vector2(points[s]))
		var cell: Vector2i = Vector2i(closest.round())
		var d: float = point.distance_to(Vector2(cell))
		if d < best_distance:
			best_distance = d
			best = cell
	return best


## First free designation "<prefix><n>", e.g. "K3", also avoiding
## [param reserved].
func next_designation(prefix: String, reserved: Dictionary[String, bool] = {}) -> String:
	var used: Dictionary[String, bool] = reserved.duplicate()
	for c: CircuitComponent in circuit.get_components():
		used[c.designation] = true
	var n: int = 1
	while used.has(prefix + str(n)):
		n += 1
	return prefix + str(n)


## IP address for a new PLC: the first 192.168.0.n no PLC has (nor one of
## [param reserved]).
func next_ip(reserved: Dictionary[String, bool] = {}) -> String:
	var used: Dictionary[String, bool] = reserved.duplicate()
	for c: CircuitComponent in circuit.get_components():
		if c is Plc:
			used[(c as Plc).ip_address] = true
	var prefix: String = Plc.DEFAULT_IP.get_slice(".", 0) + "." + Plc.DEFAULT_IP.get_slice(".", 1) + "." + Plc.DEFAULT_IP.get_slice(".", 2) + "."
	for n: int in range(1, 255):
		if not used.has(prefix + str(n)):
			return prefix + str(n)
	return Plc.DEFAULT_IP


## Saved program [param data] with the partners of its network inputs at
## the addresses [param readdressed] gives them (old -> new).
static func _readdressed_program(data: Variant, readdressed: Dictionary[String, String]) -> Variant:
	if not (data is Dictionary) or not ((data as Dictionary).get("network") is Dictionary):
		return data
	var copy: Dictionary = (data as Dictionary).duplicate(true)
	for operand: Variant in copy["network"]:
		var source: Variant = copy["network"][operand]
		if source is Dictionary and readdressed.has(str(source.get("ip", ""))):
			source["ip"] = readdressed[str(source["ip"])]
	return copy


## True when a PLC answers at [param ip].
func _ip_taken(ip: String) -> bool:
	for c: CircuitComponent in circuit.get_components():
		if c is Plc and (c as Plc).ip_address == ip:
			return true
	return false


## Designation for a new device "<prefix><n>" (coil, button, breaker,
## ...): the first one carried only by parts whose device is not drawn (e.g.
## main contacts KM1 placed before their coil), else the first free one.
func next_device_designation(prefix: String, reserved: Dictionary[String, bool] = {}) -> String:
	for designation: String in orphan_designations(prefix):
		if not reserved.has(designation):
			return designation
	return next_designation(prefix, reserved)


## Designations "<prefix><n>", lowest number first, that only contacts
## (contacts, changeovers, main contacts, overload contacts) carry: their
## coil, button, breaker or overload relay is not drawn.
func orphan_designations(prefix: String) -> PackedStringArray:
	var parts: Dictionary[int, bool] = {}
	var devices: Dictionary[int, bool] = {}
	for c: CircuitComponent in circuit.get_components():
		var number: String = c.designation.trim_prefix(prefix)
		if number == c.designation or not number.is_valid_int():
			continue
		if c is Contact or c is ChangeoverContact or c is MainContacts or c is OverloadContact:
			parts[int(number)] = true
		else:
			devices[int(number)] = true
	var numbers: Array[int] = []
	for n: int in parts:
		if not devices.has(n):
			numbers.append(n)
	numbers.sort()
	var result: PackedStringArray = PackedStringArray()
	for n: int in numbers:
		result.append(prefix + str(n))
	return result


## Designation for a new set of main contacts: the first of [param preferred],
## then of the contactors, whose main contacts are not drawn yet, then of
## auxiliary contacts without a coil (e.g. KM1 13-14 drawn first), else a free
## KM designation (for a contactor still to be drawn); never one of
## [param reserved].
func main_contacts_designation(preferred: PackedStringArray = PackedStringArray(), reserved: Dictionary[String, bool] = {}) -> String:
	var taken: Dictionary[String, bool] = reserved.duplicate()
	var candidates: PackedStringArray = preferred.duplicate()
	for c: CircuitComponent in circuit.get_components():
		if c is MainContacts:
			taken[c.designation] = true
		elif c is Coil and not (c is TimerRelay) and (c as Coil).kind == Coil.Kind.CONTACTOR:
			candidates.append(c.designation)
	candidates.append_array(orphan_designations("KM"))
	for designation: String in candidates:
		if not taken.has(designation):
			return designation
	return next_designation("KM", reserved)


## Designation for another supply point: "L", then "L.2", "L.3", ...
func next_supply_designation(conductor: PowerSupply.Conductor) -> String:
	var base: String = "N"
	match conductor:
		PowerSupply.Conductor.L:
			# L1, unless a single-phase drawing already names its phase plain
			# "L" (then "L.2", "L.3", ...); next to L2 or L3 always L1.
			base = "L1"
			var plain: bool = false
			for c: CircuitComponent in circuit.get_components():
				if c is PowerSupply:
					if (c as PowerSupply).conductor in [PowerSupply.Conductor.L2, PowerSupply.Conductor.L3]:
						plain = false
						break
					if c.designation == "L" or c.designation.begins_with("L."):
						plain = true
			if plain:
				base = "L"
		PowerSupply.Conductor.L2:
			base = "L2"
		PowerSupply.Conductor.L3:
			base = "L3"
		PowerSupply.Conductor.DC_PLUS:
			base = "+"
		PowerSupply.Conductor.DC_MINUS:
			base = "-"
		PowerSupply.Conductor.PE:
			base = "PE"
	if not circuit.has_component_id(base):
		return base
	var n: int = 2
	while circuit.has_component_id("%s.%d" % [base, n]):
		n += 1
	return "%s.%d" % [base, n]


## Next to L2 or L3 the first phase is called L1: its supply points still
## named plain "L" ("L.2", ...) are renamed "L1" ("L1.2", ...), their wires
## stay. Returns the renamed component ids (old id -> new id).
func name_first_phase() -> Dictionary[String, String]:
	var renamed: Dictionary[String, String] = {}
	var three_phase: bool = false
	for c: CircuitComponent in circuit.get_components():
		if c is PowerSupply and (c as PowerSupply).conductor in [PowerSupply.Conductor.L2, PowerSupply.Conductor.L3]:
			three_phase = true
			break
	if not three_phase:
		return renamed
	for c: CircuitComponent in circuit.get_components().duplicate():
		if not (c is PowerSupply) or (c as PowerSupply).conductor != PowerSupply.Conductor.L:
			continue
		if c.designation != "L" and not c.designation.begins_with("L."):
			continue
		var designation: String = "L1" + c.designation.substr(1)
		if circuit.has_component_id(designation):
			designation = next_supply_designation(PowerSupply.Conductor.L)
		var data: Dictionary = DocumentSerializer.component_to_dict(c)
		data["designation"] = designation
		var old_id: String = c.id
		var replacement: CircuitComponent = DocumentSerializer.component_from_dict(data)
		if replacement != null and replace_component(old_id, replacement):
			renamed[old_id] = replacement.id
	return renamed


## First contact sequence digit (1-9) not yet used by [param designation].
func next_contact_sequence(designation: String) -> int:
	var used: Dictionary[int, bool] = {}
	for c: CircuitComponent in circuit.get_components():
		if c is SwitchingElement and c.designation == designation:
			used[(c as SwitchingElement).sequence] = true
		elif c is ChangeoverContact and c.designation == designation:
			used[(c as ChangeoverContact).sequence] = true
	for n: int in range(1, 10):
		if not used.has(n):
			return n
	return 9


# --- Clipboard -----------------------------------------------------------------

## Copies components and the wires running between them (both ends inside the
## selection) into plain data for [method insert].
func extract(ids: PackedStringArray) -> Dictionary:
	var keys: Dictionary[String, bool] = {}
	var components: Array[Dictionary] = []
	for c: CircuitComponent in circuit.get_components():
		if not ids.has(c.id):
			continue
		var d: Dictionary = DocumentSerializer.component_to_dict(c)
		var p: Placement = _placements[c.id]
		d["cell"] = [p.cell.x, p.cell.y]
		d["rotation"] = p.rotation
		d["mirrored"] = p.mirrored
		if not p.labels.is_empty():
			d["labels"] = p.labels_to_data()
		if not p.strips.is_empty():
			d["strips"] = p.strips_to_data()
		components.append(d)
		for key: String in c.get_terminal_keys():
			keys[key] = true
	var wires: Array[Dictionary] = []
	var circuit_wires: Array[PackedStringArray] = circuit.get_wires()
	for i: int in circuit_wires.size():
		if keys.has(circuit_wires[i][0]) and keys.has(circuit_wires[i][1]):
			var corners: Array = []
			for corner: Vector2i in _routes[i].corners:
				corners.append([corner.x, corner.y])
			wires.append({"a": circuit_wires[i][0], "b": circuit_wires[i][1], "corners": corners})
	return {"components": components, "wires": wires}


## Adds data from [method extract], shifted by [param offset] cells. Taken
## designations are renumbered; a copied coil and its copied contacts get the
## same new designation, contacts (and changeovers) copied without their coil
## stay with it and get a free contact number, main contacts copied without
## their coil go to a contactor without main contacts
## ([method main_contacts_designation]). Returns the ids of the new components.
func insert(data: Dictionary, offset: Vector2i) -> PackedStringArray:
	var components: Array = data.get("components", [])
	var renamed: Dictionary[String, String] = {}
	var reserved: Dictionary[String, bool] = {}
	for cd: Dictionary in components:
		var kind: String = cd["type"]
		if kind in ["supply", "junction", "contact", "changeover", "main_contacts"]:
			continue
		var designation: String = cd["designation"]
		if renamed.has(designation):
			continue
		var taken: bool = reserved.has(designation)
		for c: CircuitComponent in circuit.get_components():
			if c.designation == designation:
				taken = true
				break
		var new_designation: String = designation
		if taken:
			new_designation = next_designation(_designation_prefix(designation), reserved)
		renamed[designation] = new_designation
		reserved[new_designation] = true

	# Strip terminals on the copies get free numbers on their strips, else
	# copies and originals would share one terminal.
	var numbers: Dictionary[String, Dictionary] = {}
	var strips: Dictionary = CabinetDevices.strips(self)
	for strip: String in strips:
		numbers[strip] = {}
		for t: Dictionary in strips[strip]:
			numbers[strip][t["label"]] = true
	var relabelled: Dictionary[String, String] = {}
	var new_ids: PackedStringArray = PackedStringArray()
	var key_map: Dictionary[String, String] = {}
	# A copied PLC answers at an address of its own; copies reading one
	# another read the copies' new addresses.
	var ips: Dictionary[String, bool] = {}
	var readdressed: Dictionary[String, String] = {}
	var new_ips: Array[String] = []
	for cd: Dictionary in components:
		if cd["type"] != "plc":
			continue
		var ip: String = str(cd.get("ip", ""))
		var given: String = next_ip(ips) if ips.has(ip) or _ip_taken(ip) else ip
		if not readdressed.has(ip):
			readdressed[ip] = given
		new_ips.append(given)
		ips[given] = true
	for cd: Dictionary in components:
		var d: Dictionary = cd.duplicate()
		match d["type"]:
			"plc":
				d["designation"] = renamed.get(d["designation"], d["designation"])
				d["ip"] = new_ips.pop_front()
				d["program"] = _readdressed_program(d.get("program", {}), readdressed)
			"supply":
				var conductor: int = maxi(DocumentSerializer.CONDUCTORS.find(str(d.get("conductor", "L"))), 0)
				d["designation"] = next_supply_designation(conductor as PowerSupply.Conductor)
			"junction":
				d["designation"] = next_designation("J")
			"terminal":
				d["designation"] = renamed.get(d["designation"], d["designation"])
				d["label"] = _pasted_strip_label(str(d.get("label", "")), numbers, relabelled)
			_:
				d["designation"] = renamed.get(d["designation"], d["designation"])
		var c: CircuitComponent = DocumentSerializer.component_from_dict(d)
		if (c is SwitchingElement or c is ChangeoverContact) and not DocumentSerializer._fits(circuit, c):
			d["sequence"] = next_contact_sequence(d["designation"])
			c = DocumentSerializer.component_from_dict(d)
		elif c is MainContacts and not DocumentSerializer._fits(circuit, c):
			d["designation"] = main_contacts_designation(PackedStringArray(), reserved)
			c = DocumentSerializer.component_from_dict(d)
		if c == null or not DocumentSerializer._fits(circuit, c):
			continue
		var old_keys: PackedStringArray = DocumentSerializer.component_from_dict(cd).get_terminal_keys()
		var new_keys: PackedStringArray = c.get_terminal_keys()
		for k: int in old_keys.size():
			key_map[old_keys[k]] = new_keys[k]
		var cell: Array = cd["cell"]
		add(c, Vector2i(int(cell[0]), int(cell[1])) + offset, int(cd.get("rotation", 0)), bool(cd.get("mirrored", false)))
		_placements[c.id].labels_from_data(cd.get("labels", {}))
		_placements[c.id].strips_from_data(cd.get("strips", {}))
		var lead_strips: Dictionary[int, String] = _placements[c.id].strips
		for index: int in lead_strips:
			lead_strips[index] = _pasted_strip_label(lead_strips[index], numbers, relabelled)
		new_ids.append(c.id)
	for wd: Dictionary in data.get("wires", []):
		if not key_map.has(wd["a"]) or not key_map.has(wd["b"]):
			continue
		var corners: Array[Vector2i] = []
		for corner: Array in wd["corners"]:
			corners.append(Vector2i(int(corner[0]), int(corner[1])) + offset)
		connect_terminals(key_map[wd["a"]], key_map[wd["b"]], corners)
	return new_ids


static func _designation_prefix(designation: String) -> String:
	var prefix: String = ""
	for ch: String in designation:
		if ch >= "0" and ch <= "9":
			break
		prefix += ch
	return prefix if not prefix.is_empty() else "X"


## Label for a pasted strip terminal labelled [param label]: the same while
## its strip has no such terminal, else the next free number on the strip.
## [param numbers]: strip -> labels in use there (updated);
## [param relabelled]: labels given so far in this paste, so copies that
## shared a terminal still share one.
static func _pasted_strip_label(label: String, numbers: Dictionary[String, Dictionary], relabelled: Dictionary[String, String]) -> String:
	label = label.strip_edges()
	if label.is_empty():
		return label
	if relabelled.has(label):
		return relabelled[label]
	var parts: PackedStringArray = CabinetDevices.split_label(label)
	if not numbers.has(parts[0]):
		numbers[parts[0]] = {}
	var used: Dictionary = numbers[parts[0]]
	var result: String = label
	if used.has(parts[1]):
		var highest: int = 0
		for number: Variant in used:
			if str(number).is_valid_int():
				highest = maxi(highest, int(str(number)))
		parts[1] = str(highest + 1)
		result = parts[1] if parts[0] == CabinetDevices.DEFAULT_STRIP else parts[0] + ":" + parts[1]
	used[parts[1]] = true
	relabelled[label] = result
	return result


func _reroute_component(component_id: String) -> void:
	var wires: PackedInt32Array = circuit.wires_of(circuit.get_component(component_id))
	wires.reverse()
	_reroute(wires, {component_id: true} as Dictionary[String, bool])


func _merge_at_junction(junction: Junction, unordered: PackedInt32Array) -> void:
	# Older wire first, so the merged wire keeps the original direction.
	var wires: PackedInt32Array = unordered.duplicate()
	wires.sort()
	var cell: Vector2i = _placements[junction.id].cell
	var first: Array[Vector2i] = wire_points(wires[0])
	var second: Array[Vector2i] = wire_points(wires[1])
	var w0: PackedStringArray = circuit.get_wires()[wires[0]]
	var w1: PackedStringArray = circuit.get_wires()[wires[1]]
	var key_a: String = w0[0] if w0[1] == junction.designation else w0[1]
	var key_b: String = w1[1] if w1[0] == junction.designation else w1[0]
	if first[0] == cell:
		first.reverse()
	if second[second.size() - 1] == cell:
		second.reverse()
	var merged: Array[Vector2i] = first
	merged.append_array(second.slice(1))
	# The merged wire keeps the net's number.
	var number: String = _routes[wires[0]].number if not _routes[wires[0]].number.is_empty() else _routes[wires[1]].number
	remove_component(junction.id)
	if key_a == key_b:
		return
	connect_terminals(key_a, key_b, merged.slice(1, merged.size() - 1))
	_routes[get_wire_count() - 1].number = number
	normalize_route(get_wire_count() - 1)


static func _on_segment(cell: Vector2i, a: Vector2i, b: Vector2i) -> bool:
	if a.x == b.x and cell.x == a.x:
		return cell.y >= mini(a.y, b.y) and cell.y <= maxi(a.y, b.y)
	if a.y == b.y and cell.y == a.y:
		return cell.x >= mini(a.x, b.x) and cell.x <= maxi(a.x, b.x)
	return false


func _terminal_name(owner: CircuitComponent, key: String) -> String:
	var keys: PackedStringArray = owner.get_terminal_keys()
	return owner.get_terminal_names()[keys.find(key)]


# --- Workspace --------------------------------------------------------------------

## Name for a new place of [param kind] ([enum Workspace.Place]): its prefix
## with the first number no place uses ("RA1", "ST2", "G1").
func next_place_name(kind: Workspace.Place) -> String:
	var n: int = 1
	while place_taken(Workspace.PREFIXES[kind] + str(n)):
		n += 1
	return Workspace.PREFIXES[kind] + str(n)


## True when a switchboard, control station or group is named [param place_name].
func place_taken(place_name: String) -> bool:
	for board: Switchboard in switchboards:
		if board.name == place_name:
			return true
	for box: ControlBox in control_boxes:
		if box.name == place_name:
			return true
	for group: WorkspaceGroup in groups:
		if group.name == place_name:
			return true
	return false


## A free spot on the workspace for a new place: right of every place there is.
func free_spot() -> Vector2:
	var right: float = -INF
	var top: float = INF
	for board: Switchboard in switchboards:
		right = maxf(right, board.position.x + Workspace.PLACE_SIZE.x)
		top = minf(top, board.position.y)
	for box: ControlBox in control_boxes:
		right = maxf(right, box.position.x + Workspace.place_size(box).x)
		top = minf(top, box.position.y)
	# A group's frame is round its members where they stand, also those not
	# put anywhere yet (drawn in its frame).
	var positions: Dictionary[String, Vector2] = Workspace.field_positions(self)
	for group: WorkspaceGroup in groups:
		var frame: Rect2 = Workspace.group_rect(group, positions)
		right = maxf(right, frame.end.x)
		top = minf(top, frame.position.y)
	if right == -INF:
		return Vector2.ZERO
	return Vector2(right + Workspace.SPACING, top)


## Adds an empty switchboard at [param at] (a free spot when not a Vector2).
func add_switchboard(at: Variant = null) -> Switchboard:
	var board: Switchboard = Switchboard.new(next_place_name(Workspace.Place.SWITCHBOARD), at if at is Vector2 else free_spot())
	switchboards.append(board)
	return board


## The consumer unit of a house installation: switchboard "RD1" (see
## [constant FloorPlan.UNIT]), made with the devices that have no place
## yet on its rails when there is none. Returns its index.
func ensure_consumer_unit() -> int:
	var unit_name: String = FloorPlan.UNIT.trim_prefix("+")
	for i: int in switchboards.size():
		if switchboards[i].name == unit_name:
			return i
	switchboards.append(Switchboard.new(unit_name, free_spot()))
	fill_cabinet(switchboards.size() - 1)
	return switchboards.size() - 1


## Adds an empty group at [param at] (a free spot when not a Vector2).
func add_group(at: Variant = null) -> WorkspaceGroup:
	var group: WorkspaceGroup = WorkspaceGroup.new(next_place_name(Workspace.Place.GROUP), at if at is Vector2 else free_spot())
	groups.append(group)
	return group


## Removes place [param index] of [param kind]: what a switchboard or station
## held has no place any more, the members of a group stay where they are.
func remove_place(kind: Workspace.Place, index: int) -> void:
	match kind:
		Workspace.Place.SWITCHBOARD:
			if index >= 0 and index < switchboards.size():
				switchboards.remove_at(index)
		Workspace.Place.STATION:
			if index >= 0 and index < control_boxes.size():
				control_boxes.remove_at(index)
		Workspace.Place.GROUP:
			if index >= 0 and index < groups.size():
				var positions: Dictionary[String, Vector2] = Workspace.field_positions(self)
				for member: String in groups[index].members:
					if positions.has(member):
						field_positions[member] = positions[member]
				groups.remove_at(index)


## Renames place [param index] of [param kind] to [param place_name] with the
## text [param place_title]. Returns false when the name is unusable (empty,
## spaces, colons) or another place has it.
func rename_place(kind: Workspace.Place, index: int, place_name: String, place_title: String) -> bool:
	var place: RefCounted = _place(kind, index)
	var new_name: String = Workspace.place_name(place_name)
	if place == null or new_name.is_empty() or place_name.strip_edges().trim_prefix("+") != new_name:
		return false
	if new_name != place.get("name") and place_taken(new_name):
		return false
	_rename_cable_end("+" + str(place.get("name")), "+" + new_name)
	place.set("name", new_name)
	place.set("title", place_title.strip_edges())
	return true


## Moves place [param index] of [param kind] to [param at]; a group takes its
## members along.
func move_place(kind: Workspace.Place, index: int, at: Vector2) -> void:
	var place: RefCounted = _place(kind, index)
	if place == null:
		return
	if kind == Workspace.Place.GROUP:
		var group: WorkspaceGroup = place as WorkspaceGroup
		var positions: Dictionary[String, Vector2] = Workspace.field_positions(self)
		var offset: Vector2 = at - Workspace.group_rect(group, positions).position
		for member: String in group.members:
			if positions.has(member):
				field_positions[member] = positions[member] + offset
		group.position += offset
		return
	place.set("position", at)


## Shows station [param index] on the workspace as its face at
## [param scale] (see [member ControlBox.face_scale]; 0: as its tile).
func set_station_face(index: int, scale: float) -> void:
	if index >= 0 and index < control_boxes.size():
		control_boxes[index].face_scale = ControlBox.valid_face(scale)


## Resizes the frame of group [param index] to [param new_size] (kept no
## smaller than round its members; as small as that or smaller: just round
## them again).
func set_group_size(index: int, new_size: Vector2) -> void:
	if index < 0 or index >= groups.size():
		return
	var group: WorkspaceGroup = groups[index]
	var fit: Vector2 = Workspace.group_fit(group, Workspace.field_positions(self)).size
	if new_size.x <= fit.x and new_size.y <= fit.y:
		group.size = Vector2.ZERO
	else:
		group.size = WorkspaceGroup.valid_size(new_size.max(fit))


## Puts part [param designation] in the field at [param at], in group
## [param group] (-1 for none). A part leaving a group leaves its mechanical
## link too.
func place_field_device(designation: String, at: Vector2, group: int = -1) -> void:
	if Workspace.field_component(circuit, designation) == null:
		return
	field_positions[designation] = at
	for g: int in groups.size():
		var members: PackedStringArray = groups[g].members
		if g == group and not members.has(designation):
			members.append(designation)
			groups[g].members = members
		elif g != group:
			_leave_group(groups[g], designation)


## Sets the mechanical link of group [param index]: member motor
## [param drive] ("" for none) moves its part, [param seconds] end to end,
## from [param start_at] (0-1) at the start; member limit switches and
## proximity sensors [param at_stops] (designation -> 0-1) are operated where they are. Returns
## false when the drive is not a motor of the group.
func set_group_link(index: int, drive: String, seconds: float, start_at: float, at_stops: Dictionary) -> bool:
	if index < 0 or index >= groups.size():
		return false
	var group: WorkspaceGroup = groups[index]
	if not drive.is_empty() and (not group.members.has(drive) or Workspace.field_kind(Workspace.field_component(circuit, drive)) != Workspace.Field.MOTOR):
		return false
	group.drive = drive
	group.travel_time = clampf(seconds, 0.1, 3600.0)
	group.start = clampf(start_at, 0.0, 1.0)
	group.stops.clear()
	for designation: Variant in at_stops:
		if designation is String and group.members.has(designation) and Workspace.is_stop(Workspace.field_component(circuit, designation)):
			group.stops[designation] = clampf(float(at_stops[designation]), 0.0, 1.0)
	return true


## Gives the places of an older schematic their names and spots: switchboards
## and stations without a name get the next free one, side by side.
func name_places() -> void:
	var unnamed: Array[RefCounted] = []
	for board: Switchboard in switchboards:
		if board.name.is_empty():
			unnamed.append(board)
	for box: ControlBox in control_boxes:
		if box.name.is_empty():
			unnamed.append(box)
	for group: WorkspaceGroup in groups:
		if group.name.is_empty():
			unnamed.append(group)
	for place: RefCounted in unnamed:
		var kind: Workspace.Place = Workspace.Place.SWITCHBOARD if place is Switchboard else (Workspace.Place.STATION if place is ControlBox else Workspace.Place.GROUP)
		place.set("position", Vector2(-INF, -INF))
		place.set("name", next_place_name(kind))
	for place: RefCounted in unnamed:
		place.set("position", _spot_without(place))


## Points the place and group of part [param old_designation] in the field
## to [param new_designation]. When that is no part in the field (another
## type) or one placed already (a block joining a limit switch), the old
## name's place, group and link go instead.
func rename_field_device(old_designation: String, new_designation: String) -> void:
	if Workspace.field_component(circuit, new_designation) == null or field_positions.has(new_designation) or Workspace.group_of(self, new_designation) >= 0:
		field_positions.erase(old_designation)
		for group: WorkspaceGroup in groups:
			_leave_group(group, old_designation)
		return
	_rename_cable_end("-" + old_designation, "-" + new_designation)
	if field_positions.has(old_designation):
		field_positions[new_designation] = field_positions[old_designation]
		field_positions.erase(old_designation)
	for group: WorkspaceGroup in groups:
		var index: int = group.members.find(old_designation)
		if index >= 0:
			group.members[index] = new_designation
		if group.drive == old_designation:
			group.drive = new_designation
		if group.stops.has(old_designation):
			group.stops[new_designation] = group.stops[old_designation]
			group.stops.erase(old_designation)


## Every switchboard, control station and group, in that order.
func places() -> Array[RefCounted]:
	var result: Array[RefCounted] = []
	result.append_array(switchboards)
	result.append_array(control_boxes)
	result.append_array(groups)
	return result


## Keeps the name of every cable of the workspace (see [WorkspaceCables]):
## a new cable gets the first free "W<n>", the names of cables that are gone
## are dropped. Run after every edit.
func name_cables() -> void:
	var kept: Dictionary[String, String] = {}
	var settings: Dictionary[String, Dictionary] = {}
	for cable: Dictionary in WorkspaceCables.cables(self):
		kept[cable["key"]] = cable["name"]
		if cable_settings.has(cable["key"]):
			settings[cable["key"]] = cable_settings[cable["key"]]
	cable_names = kept
	cable_settings = settings


## Cables with end [param old_end] ("+ST1", "-M1") keep their names when
## the end is renamed to [param new_end].
func _rename_cable_end(old_end: String, new_end: String) -> void:
	if old_end == new_end:
		return
	var renamed: Dictionary[String, String] = {}
	for key: String in cable_names:
		var ends: PackedStringArray = key.split("|")
		for i: int in ends.size():
			if ends[i] == old_end:
				ends[i] = new_end
		renamed["|".join(ends)] = cable_names[key]
	cable_names = renamed
	var settings: Dictionary[String, Dictionary] = {}
	for key: String in cable_settings:
		var ends: PackedStringArray = key.split("|")
		for i: int in ends.size():
			if ends[i] == old_end:
				ends[i] = new_end
		settings["|".join(ends)] = cable_settings[key]
	cable_settings = settings


## Renames cable [param key] ("+RA1|+ST1") to [param cable_name]. Returns
## false when the name is unusable (empty, spaces, colons) or another cable
## has it.
func rename_cable(key: String, cable_name: String) -> bool:
	var new_name: String = WorkspaceCables.cable_name(cable_name)
	if new_name.is_empty() or new_name != cable_name.strip_edges():
		return false
	var found: bool = false
	for cable: Dictionary in WorkspaceCables.cables(self):
		if cable["key"] == key:
			found = true
		elif cable["name"] == new_name:
			return false
	if not found:
		return false
	cable_names[key] = new_name
	return true


## Sets on cable [param key] a type name in place of the one by its use
## ([param type], "" for that), a cross-section in mm² ([param section], one
## of [constant WorkspaceCables.CHOICES], 0 for the one by the current) and
## its length in metres ([param length], 0 for not given). Returns false
## when there is no such cable.
func set_cable(key: String, type: String, section: float, length: float) -> bool:
	var found: bool = false
	for cable: Dictionary in WorkspaceCables.cables(self):
		found = found or cable["key"] == key
	if not found:
		return false
	var settings: Dictionary = WorkspaceCables.settings(type, section, length)
	if settings.is_empty():
		cable_settings.erase(key)
	else:
		cable_settings[key] = settings
	return true


## Place [param index] of [param kind], or null.
func _place(kind: Workspace.Place, index: int) -> RefCounted:
	var list: Array = switchboards if kind == Workspace.Place.SWITCHBOARD else (control_boxes if kind == Workspace.Place.STATION else groups)
	return list[index] if index >= 0 and index < list.size() else null


## [method free_spot] for [param place], leaving out itself and the places
## not placed yet (at -INF).
func _spot_without(place: RefCounted) -> Vector2:
	var right: float = -INF
	for other: RefCounted in places():
		var at: Vector2 = other.get("position")
		if other != place and at.x > -INF:
			right = maxf(right, at.x + Workspace.place_size(other).x)
	return Vector2.ZERO if right == -INF else Vector2(right + Workspace.SPACING, 0.0)


# --- Set at simulation start --------------------------------------------------------------

## True for a part that can be switched on or operated when a simulation
## starts (see [member CircuitComponent.set_at_start]): a circuit breaker, a
## fuse holder, a switch (also a limit switch) or a rotary cam switch.
static func can_set_at_start(c: CircuitComponent) -> bool:
	return c is CircuitBreaker or c is MotorBreaker or (c is Fuse and (c as Fuse).holder) or (c is ThreePoleFuse and (c as ThreePoleFuse).holder) or c is LatchingSwitch or c is CamSwitch


## Switches on or operates the parts set at start: breakers and fuse holders
## on, a switch in the position of its block (I, or II for an I-0-II block on
## II), a cam switch in I, at once. Run on the copy a simulation starts from.
func apply_start_settings() -> void:
	for c: CircuitComponent in circuit.get_components():
		if not c.set_at_start or not can_set_at_start(c):
			continue
		if c is CircuitBreaker:
			(c as CircuitBreaker).switched_on = true
		elif c is MotorBreaker:
			(c as MotorBreaker).switched_on = true
		elif c is Fuse:
			(c as Fuse).switched_on = true
		elif c is ThreePoleFuse:
			(c as ThreePoleFuse).switched_on = true
		elif c is LatchingSwitch:
			var selector: LatchingSwitch = c as LatchingSwitch
			selector.switched_on = true
			selector.actuator.snap(selector.actuator.target)
			selector.actuator_two.snap(selector.actuator_two.target)
		elif c is CamSwitch:
			(c as CamSwitch).position = CamSwitch.ONE


# --- Keys -------------------------------------------------------------------------------

## True for a device a key can operate: a push button or a switch (not a
## limit switch, the machine operates those).
func can_have_key(designation: String) -> bool:
	var kind: int = ControlBoxItem.kind_of(circuit.get_operator(designation))
	return kind == ControlBoxItem.Kind.BUTTON or kind == ControlBoxItem.Kind.SWITCH


## Binds [param key] (see [member key_bindings]; "" takes the key off) to
## push button or switch [param designation]; a device the key operated
## before loses it. Returns false for another kind of device or an unknown key.
func set_key(designation: String, key: String) -> bool:
	if not can_have_key(designation):
		return false
	if key.is_empty():
		key_bindings.erase(designation)
		return true
	if OS.find_keycode_from_string(key) == KEY_NONE:
		return false
	for other: String in key_bindings.keys():
		if key_bindings[other] == key:
			key_bindings.erase(other)
	key_bindings[designation] = key
	return true


## The push button or switch [param key] operates, "" for none.
func device_of_key(key: String) -> String:
	for designation: String in key_bindings:
		if key_bindings[designation] == key:
			return designation
	return ""


# --- Control stations ---------------------------------------------------------------

## Adds an empty control station at [param at] (a free spot when not a Vector2).
func add_control_box(box_title: String = "", columns: int = 1, at: Variant = null) -> ControlBox:
	var box: ControlBox = ControlBox.new(box_title, columns)
	box.name = next_place_name(Workspace.Place.STATION)
	box.position = at if at is Vector2 else free_spot()
	control_boxes.append(box)
	return box


## Adds a control station with every push button, switch and signal lamp
## that is not on a station yet (see [method fill_control_box]). Returns
## null when there is none.
func add_control_box_for_all() -> ControlBox:
	var items: Array[ControlBoxItem] = _unlisted_control_items()
	if items.is_empty():
		return null
	var box: ControlBox = add_control_box("", 1 if items.size() <= 4 else 2)
	box.items = items
	return box


## Puts every push button, switch and signal lamp that is not on a station
## or a door yet on panel [param index] (see [method control_panels]):
## buttons that only break (stop) red, other buttons green, switches black,
## lamps green. Returns how many were added.
func fill_control_box(index: int) -> int:
	var panel: ControlBox = _panel(index)
	if panel == null:
		return 0
	var items: Array[ControlBoxItem] = _unlisted_control_items()
	panel.items.append_array(items)
	return items.size()


## Everything push buttons, switches and lamps are put on: the control
## stations, then the door of each switchboard, in that order. The item
## edits below take an index into it ("panel"; a station's is its index in
## [member control_boxes], see [method door_panel] for a door).
func control_panels() -> Array[ControlBox]:
	var panels: Array[ControlBox] = control_boxes.duplicate()
	for board: Switchboard in switchboards:
		panels.append(board.door)
	return panels


## Panel index (see [method control_panels]) of the door of switchboard
## [param board], -1 when there is no such switchboard.
func door_panel(board: int) -> int:
	return control_boxes.size() + board if _has_board(board) else -1


func _panel(index: int) -> ControlBox:
	if index >= 0 and index < control_boxes.size():
		return control_boxes[index]
	if _has_board(index - control_boxes.size()):
		return switchboards[index - control_boxes.size()].door
	return null


func _unlisted_control_items() -> Array[ControlBoxItem]:
	var items: Array[ControlBoxItem] = []
	var listed: Dictionary[String, bool] = control_panel_devices()
	var breaks_only: Dictionary[String, bool] = {}
	for c: CircuitComponent in circuit.get_components():
		if c is PushButton:
			var nc: bool = (c as PushButton).contact_type == SwitchingElement.ContactType.NC
			breaks_only[c.designation] = breaks_only.get(c.designation, true) and nc
	for kind: int in [ControlBoxItem.Kind.BUTTON, ControlBoxItem.Kind.SWITCH, ControlBoxItem.Kind.LAMP, ControlBoxItem.Kind.POT]:
		for designation: String in control_devices(kind):
			if listed.has(designation):
				continue
			var color: String = ControlBoxItem.default_color(kind as ControlBoxItem.Kind)
			if kind == ControlBoxItem.Kind.BUTTON and breaks_only.get(designation, false):
				color = "red"
			var item: ControlBoxItem = ControlBoxItem.new(kind as ControlBoxItem.Kind, designation, color)
			var device: CircuitComponent = circuit.get_component(designation)
			if device is Lamp:
				item.label = (device as Lamp).purpose
			items.append(item)
	return items


## Sets the text on a control station and how many items it has per row
## (a door: [param box_title] unused).
func set_control_box(index: int, box_title: String, columns: int) -> void:
	var panel: ControlBox = _panel(index)
	if panel != null:
		if index < control_boxes.size():
			panel.title = box_title.strip_edges()
		panel.columns = columns


## Adds a [param kind] item to panel [param box_index] (a station or a door,
## see [method control_panels]), showing the first device of that kind not
## on one yet (or no device). Returns it.
func add_control_item(box_index: int, kind: ControlBoxItem.Kind) -> ControlBoxItem:
	if _panel(box_index) == null:
		return null
	var designation: String = ""
	var listed: Dictionary[String, bool] = control_panel_devices()
	for candidate: String in control_devices(kind):
		if not listed.has(candidate):
			designation = candidate
			break
	var item: ControlBoxItem = ControlBoxItem.new(kind, designation)
	_panel(box_index).items.append(item)
	return item


func remove_control_item(box_index: int, item_index: int) -> void:
	if _has_control_item(box_index, item_index):
		_panel(box_index).items.remove_at(item_index)


## Moves an item by [param delta] places within its station or door (clamped).
func move_control_item(box_index: int, item_index: int, delta: int) -> void:
	if not _has_control_item(box_index, item_index):
		return
	var items: Array[ControlBoxItem] = _panel(box_index).items
	var item: ControlBoxItem = items[item_index]
	items.remove_at(item_index)
	items.insert(clampi(item_index + delta, 0, items.size()), item)


## Replaces an item by one made from [method ControlBoxItem.to_data] data.
## Returns false when the data is malformed.
func set_control_item(box_index: int, item_index: int, data: Dictionary) -> bool:
	var item: ControlBoxItem = ControlBoxItem.from_data(data)
	if item == null or not _has_control_item(box_index, item_index):
		return false
	_panel(box_index).items[item_index] = item
	return true


## Designations of the devices that can be shown as [param kind] items, in
## the order they were added to the circuit (each device once).
func control_devices(kind: int) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for c: CircuitComponent in circuit.get_components():
		if ControlBoxItem.kind_of(c) == kind and not result.has(c.designation):
			result.append(c.designation)
	return result


## Points every station and door item (and lamp under one) showing device
## [param old_designation] to [param new_designation], if that is a device of
## the item's kind (a button turned into a limit switch leaves its item); a
## device shown on a station already keeps its items, the old name's go empty.
func rename_control_device(old_designation: String, new_designation: String) -> void:
	var device: CircuitComponent = circuit.get_operator(new_designation)
	var kind: int = ControlBoxItem.kind_of(device if device != null else circuit.get_component(new_designation))
	var shown: bool = control_panel_devices().has(new_designation)
	for box: ControlBox in control_panels():
		for item: ControlBoxItem in box.items:
			if item.designation == old_designation and item.kind == kind:
				item.designation = "" if shown else new_designation
			if item.lamp == old_designation and kind == ControlBoxItem.Kind.LAMP:
				item.lamp = "" if shown else new_designation


func _has_control_item(box_index: int, item_index: int) -> bool:
	var panel: ControlBox = _panel(box_index)
	return panel != null and item_index >= 0 and item_index < panel.items.size()


## Designations already shown on a station or a switchboard door (items and
## lamps under them).
func control_panel_devices() -> Dictionary[String, bool]:
	var listed: Dictionary[String, bool] = {}
	for box: ControlBox in control_panels():
		for item: ControlBoxItem in box.items:
			listed[item.designation] = true
			if not item.lamp.is_empty():
				listed[item.lamp] = true
	return listed


# --- Switchboards -------------------------------------------------------------------

## Adds an empty DIN rail at the bottom of switchboard [param board].
func add_cabinet_rail(board: int) -> CabinetRail:
	if not _has_board(board):
		return null
	var rail: CabinetRail = CabinetRail.new()
	switchboards[board].rails.append(rail)
	return rail


func remove_cabinet_rail(board: int, index: int) -> void:
	if _has_board(board) and index >= 0 and index < switchboards[board].rails.size():
		switchboards[board].rails.remove_at(index)


## Moves rail [param index] of switchboard [param board] by [param delta] places (clamped).
func move_cabinet_rail(board: int, index: int, delta: int) -> void:
	if not _has_board(board) or index < 0 or index >= switchboards[board].rails.size():
		return
	var rails: Array[CabinetRail] = switchboards[board].rails
	var rail: CabinetRail = rails[index]
	rails.remove_at(index)
	rails.insert(clampi(index + delta, 0, rails.size()), rail)


## Puts a device or terminal strip at the end of rail [param rail_index] of
## switchboard [param board]. Returns the item, or null when there is no such
## rail or it is already in a switchboard.
func add_cabinet_item(board: int, rail_index: int, kind: CabinetItem.Kind, designation: String) -> CabinetItem:
	if not _has_board(board) or rail_index < 0 or rail_index >= switchboards[board].rails.size() or designation.is_empty() or cabinet_has(kind, designation):
		return null
	var item: CabinetItem = CabinetItem.new(kind, designation)
	switchboards[board].rails[rail_index].items.append(item)
	return item


func remove_cabinet_item(board: int, rail_index: int, item_index: int) -> void:
	if _has_cabinet_item(board, rail_index, item_index):
		switchboards[board].rails[rail_index].items.remove_at(item_index)


## Moves an item by [param delta] places along its rail (clamped).
func move_cabinet_item(board: int, rail_index: int, item_index: int, delta: int) -> void:
	if not _has_cabinet_item(board, rail_index, item_index):
		return
	var items: Array[CabinetItem] = switchboards[board].rails[rail_index].items
	var item: CabinetItem = items[item_index]
	items.remove_at(item_index)
	items.insert(clampi(item_index + delta, 0, items.size()), item)


## Moves an item to the end of the rail [param delta] rails up or down.
## Returns false when there is no such rail.
func move_cabinet_item_to_rail(board: int, rail_index: int, item_index: int, delta: int) -> bool:
	var target: int = rail_index + delta
	if not _has_cabinet_item(board, rail_index, item_index) or target < 0 or target >= switchboards[board].rails.size() or delta == 0:
		return false
	var rails: Array[CabinetRail] = switchboards[board].rails
	var item: CabinetItem = rails[rail_index].items[item_index]
	rails[rail_index].items.remove_at(item_index)
	rails[target].items.append(item)
	return true


## Puts the distribution block [param name] ("N" or "PE") of switchboard
## [param board] at place [param index] of rail [param rail_index] (moved
## from where it was), where it stays while the switchboard needs it, instead
## of after the strip its incoming conductor lands on. Returns false when
## there is no such rail.
func place_bus_block(board: int, rail_index: int, index: int, name: String) -> bool:
	if not _has_board(board) or rail_index < 0 or rail_index >= switchboards[board].rails.size() or not CabinetItem.BUSES.has(name):
		return false
	var item: CabinetItem = CabinetItem.new(CabinetItem.Kind.BUS, name)
	for rail: CabinetRail in switchboards[board].rails:
		for i: int in rail.items.size():
			if rail.items[i].kind == CabinetItem.Kind.BUS and rail.items[i].designation == name:
				item = rail.items[i]
				rail.items.remove_at(i)
				break
	var items: Array[CabinetItem] = switchboards[board].rails[rail_index].items
	items.insert(clampi(index, 0, items.size()), item)
	return true


## True when the device or strip already has a place in a switchboard.
func cabinet_has(kind: CabinetItem.Kind, designation: String) -> bool:
	return Workspace.switchboard_of(self, kind, designation) >= 0


## Devices (by designation) and terminal strips (by name) of the circuit that
## have no place in a switchboard yet, as items not on any rail.
func cabinet_unplaced() -> Array[CabinetItem]:
	var result: Array[CabinetItem] = []
	for designation: String in CabinetDevices.devices(self):
		if not cabinet_has(CabinetItem.Kind.DEVICE, designation):
			result.append(CabinetItem.new(CabinetItem.Kind.DEVICE, designation))
	for strip: String in CabinetDevices.strips(self):
		if not cabinet_has(CabinetItem.Kind.STRIP, strip):
			result.append(CabinetItem.new(CabinetItem.Kind.STRIP, strip))
	return result


## Adds rails to switchboard [param board] with everything not in a
## switchboard yet: protection, time relays, relays, bridge rectifiers, PLCs
## and frequency inverters on one rail, contactors (with their overload
## relays) and lone overload relays on the next, terminal strips at the
## bottom. Returns the number of rails added.
func fill_cabinet(board: int) -> int:
	if not _has_board(board):
		return 0
	var groups_of: Array[Array] = [[], [], []]
	for item: CabinetItem in cabinet_unplaced():
		if item.kind == CabinetItem.Kind.STRIP:
			groups_of[2].append(item)
			continue
		var kind: CabinetDevices.Kind = CabinetDevices.kind_of(CabinetDevices.device(circuit, item.designation))
		groups_of[1 if kind == CabinetDevices.Kind.CONTACTOR or kind == CabinetDevices.Kind.OVERLOAD else 0].append(item)
	# Protection first, then time relays, relays, rectifiers, PLCs and their
	# network switches; each keeps circuit order.
	var order: Array[CabinetDevices.Kind] = [CabinetDevices.Kind.BREAKER, CabinetDevices.Kind.FUSE, CabinetDevices.Kind.TIMER, CabinetDevices.Kind.RELAY, CabinetDevices.Kind.RECTIFIER, CabinetDevices.Kind.PLC, CabinetDevices.Kind.SWITCH, CabinetDevices.Kind.VFD]
	var rank: Callable = func(item: CabinetItem) -> int:
		return order.find(CabinetDevices.kind_of(CabinetDevices.device(circuit, item.designation)))
	var first: Array = groups_of[0]
	var sorted: Array = []
	for r: int in order.size():
		for item: CabinetItem in first:
			if rank.call(item) == r:
				sorted.append(item)
	groups_of[0] = sorted
	var added: int = 0
	for group: Array in groups_of:
		if group.is_empty():
			continue
		var rail: CabinetRail = add_cabinet_rail(board)
		for item: CabinetItem in group:
			rail.items.append(item)
		added += 1
	return added


## Points every switchboard place of device [param old_designation] to
## [param new_designation]. A device with a place already keeps it, the
## old name's place goes.
func rename_cabinet_device(old_designation: String, new_designation: String) -> void:
	var placed: bool = cabinet_has(CabinetItem.Kind.DEVICE, new_designation)
	for board: Switchboard in switchboards:
		for rail: CabinetRail in board.rails:
			for i: int in range(rail.items.size() - 1, -1, -1):
				var item: CabinetItem = rail.items[i]
				if item.kind != CabinetItem.Kind.DEVICE or item.designation != old_designation:
					continue
				if placed:
					rail.items.remove_at(i)
				else:
					item.designation = new_designation


## Moves terminals [param labels] of terminal strip [param strip] to strip
## [param target] (a new one or one there already): every terminal on a
## wire and on a lead with such a label is relabelled ("5" -> "X2:5"). A
## number the target strip has already becomes its next free one. A new
## strip takes a place right after [param strip] in the switchboard; the
## place of a strip left without terminals goes. Returns how many
## terminals of the strip were moved.
func move_strip_terminals(strip: String, labels: PackedStringArray, target: String) -> int:
	target = target.strip_edges()
	if target.is_empty() or target == strip or target.contains(" ") or target.contains(":"):
		return 0
	var strips: Dictionary = CabinetDevices.strips(self)
	var taken: Dictionary[String, bool] = {}
	var highest: int = 0
	for t: Dictionary in strips.get(target, []):
		taken[t["label"]] = true
		if str(t["label"]).is_valid_int():
			highest = maxi(highest, int(t["label"]))
	# Old terminal label -> its label in the target strip.
	var renamed: Dictionary[String, String] = {}
	# The target's order goes on with the moved terminals in their order.
	var order: PackedStringArray = PackedStringArray()
	for t: Dictionary in strips.get(target, []):
		order.append(t["label"])
	for t: Dictionary in strips.get(strip, []):
		var label: String = t["label"]
		if not labels.has(label):
			continue
		var number: String = label
		while taken.has(number):
			highest += 1
			number = str(highest)
		taken[number] = true
		order.append(number)
		renamed[label] = number if target == CabinetDevices.DEFAULT_STRIP else target + ":" + number
	if renamed.is_empty():
		return 0
	if strip_orders.has(strip) or strip_orders.has(target):
		strip_orders[target] = order
	if strip_orders.has(strip):
		var rest: PackedStringArray = PackedStringArray()
		for label: String in strip_orders[strip]:
			if not renamed.has(label):
				rest.append(label)
		if rest.is_empty():
			strip_orders.erase(strip)
		else:
			strip_orders[strip] = rest
	for c: CircuitComponent in circuit.get_components():
		if c is TerminalBlock:
			var block: TerminalBlock = c as TerminalBlock
			var parts: PackedStringArray = CabinetDevices.split_label(block.label.strip_edges())
			if parts[0] == strip and renamed.has(parts[1]):
				block.label = renamed[parts[1]]
		var placement: Placement = _placements[c.id]
		for index: int in placement.strips:
			var parts: PackedStringArray = CabinetDevices.split_label(str(placement.strips[index]).strip_edges())
			if parts[0] == strip and renamed.has(parts[1]):
				placement.strips[index] = renamed[parts[1]]
	var left: bool = CabinetDevices.strips(self).has(strip)
	for board: Switchboard in switchboards:
		for rail: CabinetRail in board.rails:
			for i: int in rail.items.size():
				var item: CabinetItem = rail.items[i]
				if item.kind != CabinetItem.Kind.STRIP or item.designation != strip:
					continue
				if not cabinet_has(CabinetItem.Kind.STRIP, target):
					rail.items.insert(i + 1, CabinetItem.new(CabinetItem.Kind.STRIP, target))
				if not left:
					rail.items.remove_at(i)
				return renamed.size()
	return renamed.size()


## Moves terminals [param labels] of strip [param strip] one place along it,
## to the left when [param step] is negative; a terminal does not pass
## another one being moved. Returns true when one moved.
func move_strip_terminals_along(strip: String, labels: PackedStringArray, step: int) -> bool:
	var order: PackedStringArray = PackedStringArray()
	for t: Dictionary in CabinetDevices.strips(self).get(strip, []):
		order.append(t["label"])
	var indices: Array[int] = []
	for i: int in order.size():
		if labels.has(order[i]):
			indices.append(i)
	if step > 0:
		indices.reverse()
	var moved: bool = false
	for i: int in indices:
		var j: int = i + signi(step)
		if j < 0 or j >= order.size() or labels.has(order[j]):
			continue
		var label: String = order[i]
		order[i] = order[j]
		order[j] = label
		moved = true
	if moved:
		strip_orders[strip] = order
	return moved


## Name for a new terminal strip: the first "X<n>" no terminal uses.
func next_strip_name() -> String:
	var strips: Dictionary = CabinetDevices.strips(self)
	var n: int = 1
	while strips.has("X%d" % n) or cabinet_has(CabinetItem.Kind.STRIP, "X%d" % n):
		n += 1
	return "X%d" % n


func _has_board(board: int) -> bool:
	return board >= 0 and board < switchboards.size()


func _has_cabinet_item(board: int, rail_index: int, item_index: int) -> bool:
	if not _has_board(board) or rail_index < 0 or rail_index >= switchboards[board].rails.size():
		return false
	return item_index >= 0 and item_index < switchboards[board].rails[rail_index].items.size()
