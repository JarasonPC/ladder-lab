# LadderLab developer notes

Architecture and conventions of the code base. Read this before changing the code.

- Engine: Godot 4.7.2, GDScript only (no C#)
- Use static typing everywhere (var x: int, func f() -> void)
- Schematic symbols follow IEC 60617, drawn in code with _draw(), no image assets
- Drawing style follows the course guide (style "A"): white paper, thin black lines, a square at
  every terminal coloured by voltage reach, branch dots in the wire colour, "-KM1" designations
  and terminal numbers in teal, supplies as circles with the name inside, lit lamps filled grey;
  colours live in SchematicTheme, which also has a dark paper (dark theme, unless View > White
  schematic paper); export always uses white paper. Lamps may carry a purpose text drawn above
  the designation; 3~ motors have a PE terminal (last terminal, below left, ignored by the solver).
  Every contact (NO, NC, changeover, main contacts, breakers, fuse holders) pivots at its
  second/bottom terminal (changeover: common at the bottom); NO blades stand off to the actuator
  side, NC blades rest against a stop on the other side. Every delayed (time relay) contact
  carries the same time relay mark ")=" whatever the function. Breakers carry the cross plus thermal and
  magnetic releases. Fuses can be fuse holders (holder = true: can be opened by clicking). No dot
  grid by default; while placing, guide lines run through the new part's terminals.
  Voltage colour goes on the wires up to the terminal squares only; symbols stay in the line
  colour, except coils. A coil (not a time relay) rated for AC or DC carries a band across the
  end of its box with "~" or "⎓" (top of the box lying horizontally).
  Symbols draw shapes through SchematicSymbol.aa_* helpers (antialiased with a one-pixel edge at
  any zoom; the view redraws them when the zoom changes); lying horizontally, switching symbols
  are drawn mirrored along their axis so the blade pivots on the left (only when turned three
  times: turned once the pivot is already on the left; a changeover is never mirrored, its NC
  terminal sits beside the NO one, so it pivots on the left only turned once, as the palette
  shows it). Every moving part (blades,
  buttons, holders) moves smoothly (SchematicSymbol.shown); marks fixed to a blade (breaker
  releases, delay marks) turn with it; button and switch heads stay straight on a dashed stem;
  the limit switch's roller stays straight on a solid stem from the middle of the blade; the overload contact's bimetal step stays straight on a solid stem. Breakers and fuse holders start switched off (open).
- Time relays (TimerRelay) are multifunction relays: functions F1-F12 (TimerRelay.Mode, codes as in
  real relays; F10-F12 use two times t1 = delay, t2 = delay2) plus a true off-delay; optional control input S (terminals A1-A2-S, S renameable,
  active with voltage against A2; A1-A2 never renamed); the properties panel shows a timing diagram
  (TimerDiagram, computed by running TimerRelay itself) and a list of all functions
  (TimerFunctionsPopup). The palette has one time relay. Any 3~ motor can be drawn as its
  terminal box (standard motors with star/delta bridges, drawing only)
- One palette part per family: fuse/fuse holder, breaker and main contacts have 1-4 poles, the
  overload relay none or 3 (set in the properties; 3 from the palette), the rotary cam switch 1-4 poles with
  0-I or I-0-II positions (3 poles 0-I from the palette); a contact designated like an overload relay
  becomes its OverloadContact; a contact of a time relay KT is delayed by default (no separate
  delayed contacts in the palette). Parts of one device share a designation whatever their
  type: a contact, changeover or main contacts named like a push button, switch or limit switch
  is one more block of it (follows its actuator; a coil of that name wins), one named like a
  circuit breaker is its auxiliary contact; buttons, switches and limit switches of one name
  share one actuator (Circuit.get_operator finds the device to click or panel-operate). Markings (designations, terminal names, lamp and terminal labels,
  wire numbers) are edited by double-clicking them on the drawing, not in the properties panel;
  a click highlights a marking, dragging moves it (Placement.labels, saved). A new device (coil,
  time relay, button, breaker, overload relay) takes the designation of contacts drawn before it
  without their device (SchematicDocument.next_device_designation: main contacts KM1-KM4, then a
  coil = KM1); new main contacts take that of auxiliary contacts without a coil. Designations: no
  spaces or colons; only parts of one device share one (coil with its contacts, overload relay
  with its contacts, blocks of one button); renaming a coil or overload relay renames its contacts. Renaming a terminal to the name of
  another terminal of the same part swaps the two (coils: also a "Swap A1 and A2" button; a
  time relay's A1/A2 are only swapped, never renamed; its S counts against whichever is A2)
- Terminals (TerminalBlock, "X1", free label) sit on wires, or on a component's lead, supply
  points included (Placement.strips: terminal index -> label "X2:6" or "6" on X1, drawn instead
  of the square, written strip and number on one line "X2-6" / "X1-6"
  (CabinetDevices.terminal_text; typed that way too, label_from_text), a size smaller or
  strip over number only where one line would run onto a mark or terminal, its own symbol's
  or a nearby part's (SchematicSymbol.nearby_terminals, set by the view); all the labels of
  one symbol in one style, the first that fits the most of them (_strip_styles): beside a
  vertical wire level with the mark (the outer side for two terminals side by side), over the
  mark along a horizontal wire, or on one line past the mark beside the wire where three or
  more terminals stand in a row across their wires (motors, poles of a breaker; along a
  horizontal wire also two), on one line over the mark for supply points; a strip
  terminal's number keeps off its mark; Delete on the
  selected mark
  removes it, a right click on a lead adds or removes one); a palette terminal takes
  SchematicDocument.next_strip_label(), a pasted strip terminal whose label is taken the next
  free number on its strip; wire segments can be dragged; wire
  numbers (WireRoute.number, one per net, shown once per terminal right next to its square,
  a short wire once at its upper/left end, draggable offsets) via the
  numbering tool or double click; side panels (palette, properties + check, the workspace tree)
  are SideBars: resizable by a grip, zoomed with Ctrl+wheel (ZoomBox: scaled with
  oversampling_with_scale, so text stays sharp), scrolled when taller than the window and shown
  at most SideBar.MAX_WIDTH_SHARE (30 %) of the window wide (the chosen width is kept); the
  palette is a list (symbol and name) or a grid of symbols alone (Palette.grid, saved; fuses,
  breakers, multi-pole devices, motors and sensors upright, other two-terminal symbols lying; symbols too wide
  for a tile draw a simpler version there, SchematicSymbol.preview_rect: the inverter a box saying
  "VFD 3~ f", PLCs a box saying "PLC relay" / "PLC CPU", the temperature sensor a thermometer → U,
  a transmitter its circle → U, the proximity sensor its rhombus working an NO contact, 3~ motors a circle with "M 3~" and beside it
  Y over Δ (star/delta) or the number of speeds over "Dahl." / "speed"; the 1~ motor has its
  "M"; tiles show the rating a new part gets); the timing panel is resized by its top edge and the grip before the
  event log (at most MAX_HEIGHT_SHARE of the height the other bars leave, the log never wider
  than the room beside the chart's tools; the chosen sizes are kept; Follow shows only its icon
  when its text leaves no room for the log's smallest width), its chart and event log
  roll in and out by a click on their titles; widths, heights and zooms are saved in the settings
- The program starts with as little as possible: an empty schematic of one page and the
  palette (the program has no example circuits); the properties panel
  (with the check results) shows in Edit mode only while something is selected or the check
  results are shown; it starts on the schematic (Schematic | Workspace); by default (no
  settings saved yet) the timing chart and event log are rolled in; until it is answered, the
  welcome card offers the tour and the first lesson
- Example circuits (ExampleCircuits): circuits the tests and the screenshot tools build, not
  offered in the program; each has a power circuit with a motor on the left (L1 L2
  L3 on top) and its control circuit on the right; circuit breakers FA1 (C16, three poles) for
  the power circuit and FA2 (B2) for the control circuit; everything outside the switchboard on
  terminal strips: the supply on X1 (one terminal per conductor, "X1:L1" .. "X1:PE"), buttons,
  switches and lamps on X2, motors with their PE on X3; a PE supply point under every motor;
  lamp purposes and station labels are translated when the example is built
- Lessons and the tour (tutorial/ no nodes, ui/tutorial/): a Lesson (Lessons.all: lamp_switch,
  start_stop, time_relay, motor; English source texts, designations as the editor gives them
  placing the parts in the order asked) has a start schematic (a new document each call), a
  solution laid out as the steps suggest, roles found in a schematic by kind, not by name
  (Lesson.roles: e.g. "stop" the first NC push button, "hold" the coil's NO contact across the
  start button) with the solution's part for each role (Lesson.parts) and the role whose
  placement lines the solution up with the drawing (anchor); steps (title, text, hint, the
  parts they place [role, palette template] (each entry ringed while its role is missing),
  the property [role, key] they set (its field ringed, PropertiesPanel.field_rect), the
  toolbar control and roles they point at, wires [role, terminal index, role, terminal
  index] whose terminals are ringed and which Show me draws, wires to delete (cut, crossed
  out on the drawing), done(edited, live)) and goals
  (phases of a test run: actions press / release / on / off / trip, waits, expected states).
  LessonCheck: nets by wires and page connectors (UnionFind), series (parts one after the
  other, either way round, a part bridged by a wire breaks it), bridges, pole_chain, the
  state of a role while simulating, and run: a goal on a copy in the simulator (IDEAL, every
  breaker and fuse holder switched on), a row per role operated or expected, a value per
  phase, the first phase that went wrong. LessonRun: drawing steps done while the schematic
  has them (undone again), steps done while simulating stay done, the step shown follows
  the first not done, check results dropped by the next edit. main.gd starts a lesson on its
  own schematic (after the unsaved-changes prompt; another schematic ends it) with the
  LessonPanel in a SideBar on the right ("lesson"), updates it on edits and simulation
  steps; LessonMarks (Node2D over the drawing) rings the step's parts, in Edit mode the
  terminals of its wires not drawn yet (while a wire is drawn from one of them,
  SchematicEditor.wire_start, a guide to the terminal it should end on) and its wires to
  delete, and with Show me draws (where no part stands already) the solution's missing parts faintly and its wires as marching dashes;
  TutorialRings (CanvasLayer 2) rings the palette entries (Palette.entry_rect / reveal), the
  property field and Simulate or Edit; all in AppTheme.tutorial (purple: never the selection's accent nor a
  wire colour). TourOverlay (CanvasLayer 3): the window dimmed but for the control of the
  step (clicks there go through, _has_point), a card beside it, steps that wait for the
  control to be used (Next does it), Esc; main.gd builds its stops and puts the mode and
  area back after it. WelcomeCard over the drawing until it is answered: first the language (main.gd
  LOCALE_NAMES, asked in both languages at once, set_language), then the tour or the first
  lesson in it (settings
  "tutorial"/"welcomed"; finished lessons "tutorial"/"finished")
- Pages: a schematic has one or more pages (SchematicDocument.pages: titles, English source text
  shown through tr(), e.g. "Power section" = Silová část; Placement.page; SchematicDocument.page
  = the page shown). Drawing queries (bounds, component_at, terminal_at, wire_at, current_paths,
  junction_cells, wire_number_ends) look at the current page; new parts go on it; a wire joins
  terminals of one page. Page tabs above the drawing (add from presets, double-click renames,
  drag reorders, right click: move/delete, open in a new window; page edits undoable via SchematicEditor.edit_pages).
  A page window (PageWindow) holds a SchematicView with its own page (SchematicView.page) that
  follows the main view (SchematicView.follow: same document and simulation, steps and events go
  through the main view; it rebuilds when the main view does; keeps its page when pages are
  moved, closes when its page is deleted); shortcuts pressed there are handled
  by main.gd. Space runs/pauses the simulation
- Page connectors (PageConnector, internal designation "PC1", drawn as a tag: point on the wire, flat
  end away from it; label in the wire-number colour, cross reference "/page.path" below): all connectors
  with the same label are joined (Circuit.get_links, used by the solver and by wire_net); numbering
  runs over the pages and connectors take their net's wire number as label; right click (Edit) or
  click (Simulate) jumps to the partner page
- Datasheets (ui/datasheet/): Datasheet (no nodes) is what a part's datasheet says, built from
  the part itself (its terminal names, poles, modules, rating, times; texts through tr()): title
  (its palette entry), summary, description, features, terminal assignment (every terminal:
  name and function; contacts drawn with the device's designation under a heading, else the
  device's own, e.g. 15-16-18), technical data, the time functions of a time relay, a diagram
  (TimerDiagram / TripCurveDiagram with paper = true) and the device front
  (CabinetDevices.describe, parts on a rail only); Datasheet.of_template for palette parts.
  DatasheetLayout lays it out on A4 pages in points (band, title, symbol beside the description,
  tables continued on the next page, data beside the diagram, footer; the front on a page of its
  own); DatasheetPage draws a page in SchematicTheme colours (white on export), the symbol, the
  diagram and the front (DatasheetFront: CabinetParts.device at up to 2:1 with a label on a
  leader at every terminal, in as many rows as needed, smaller or upright where terminals are
  close, DatasheetFront.arrange; a table's heading never ends a page) as children;
  DatasheetWindow lists the part from the schematic and
  every palette part, zooms (ZoomBox) and exports a PDF (200 dpi pages). Opened from the right
  click menu (Datasheet, F1), the properties (Datasheet button) and Help > Part datasheets
- Menu bar: File, View (what is shown: fullscreen, theme and paper, wire and path numbers,
  grid, voltage or current view, interface size), Settings (how the program works: wiring
  helpers, cable type names, language), Help; View and Settings rebuild their items each
  time they open (main.gd _rebuild_view_menu / _rebuild_settings_menu)
- Current path numbers (the number alone, no box; above the columns, left of the rows) can be turned off in View >
  Current path numbers (saved; page windows and export follow it)
- Export: File > Export page as PNG / Export as PDF first show the sheets in a preview
  (ExportPreview: page by page, paper and scale, wire numbers on/off, on by default); saving
  writes what the preview shows. A PDF holds what is ticked in the preview (ExportPreview.contents,
  remembered in the user settings, section "export"): the schematic, the control stations
  (StationsSheet: ControlBoxViews with their names, side by side, shared out over A4 sheets by
  StationsSheet.arrange: as many as fit, then the next sheet), each switchboard with something in
  it on a sheet of its own, the PLC programs (PlcCanvas.paper: read-only, no editing aids; a
  function block diagram on one sheet, a ladder LADDER_ROWS rows to a sheet,
  PlcLadCanvas.paper_pages / paper_rows, whole rungs together where they fit) (CabinetView SWITCHBOARD_WIDTH wide), the workspace
  (WorkspaceCanvas at zoom 1 around WorkspaceCanvas.bounds) and the parts list (PartsList.rows:
  devices under the place they sit in, terminal strips with their count, the groups' and other
  parts in the field, what has no place, the cables with type and ends; within a place identical
  parts (same name and data) are one row with a quantity, designations shortened "-KM1…-KM3"
  (PartsList.designations); a button's or switch's contact blocks and a coil's or breaker's
  auxiliary contacts in its data (PartsList.contacts_of); each switchboard and station lists a
  cable gland per cable coming in, sized by WorkspaceCables.gland from the cable's estimated
  outer diameter (WorkspaceCables.outer_diameter: copper, insulation, LAY_UP, sheath), PG sizes
  with Czech cable names, metric M with European ones; PartsSheet tables on A4
  portrait, PartsSheet.split never ends a sheet with a heading); what the schematic has nothing
  of is greyed out. SheetRenderer.sheets lists the sheets, numbered in turn across the PDF; no
  keys of the keyboard on any sheet. Each page on an A4 to A3 sheet, or up to the largest
  chosen in the preview (A5-A0, ExportPreview.largest_paper, user settings
  "export"/"largest_paper", SheetRenderer.largest_paper; A5 only when it is the largest; sheets
  larger than A2 rendered at fewer dpi, SheetRenderer.MAX_PIXELS)
  (SheetLayout: 5 mm per cell, scaled down only when needed) with frame and title block
  (SheetFrame), rendered by SheetRenderer at 200 dpi on white paper
  (SheetRenderer.begin_white_paper / end_white_paper count the renders, datasheets too; the last
  to end puts the paper shown back; the preview is empty and cannot be saved while it renders
  again, ExportPreview.rendering; SheetRenderer.available says what has sheets), fitted to
  everything drawn (it draws each
  page once to measure: SchematicView.drawn_extent, with texts, wire and path numbers); PdfWriter writes one Flate image per page;
  title block texts (company, project, drawing no., revision, drawn by, checked by, date; empty
  date = export date) are SchematicDocument.title_block (TitleBlock, saved), edited in
  File > Title block… together with the schematic title (undoable)
- Workspace (ui/workspace/, Schematic | Workspace in the toolbar, a segmented switch like Edit |
  Simulate; both modes, the simulation runs on whichever is shown): WorkspaceView in place of the
  page tabs and the schematic (SchematicView hidden, editor inactive), its WorkspaceTree in a
  SideBar on the left. Places with location designations (ČSN EN 81346 "+"; Workspace.Place):
  switchboards (Switchboard "RA1": title, rails, position; SchematicDocument.switchboards),
  control stations (ControlBox "ST1" with title and position), groups (WorkspaceGroup "G1":
  title, members, position while empty; SchematicDocument.groups); names unique over all places
  (next_place_name, rename_place), new places at a free spot right of the others (free_spot)
  or where the menu was opened. Parts in the field (Workspace.field_devices: motors, limit
  switches, sensors; VFDs and PLCs sit in switchboards) stand on the workspace by
  themselves: where they were put (SchematicDocument.field_positions), else in a row under
  everything (Workspace.field_positions); a group's frame is round its members
  (Workspace.group_rect), dragging it moves them (move_place), a part dropped into a frame
  joins the group, dropped outside leaves it, and its link role (place_field_device); renamed
  parts keep both. Workspace, station and switchboard edits only apply in Edit mode (main.gd
  _edit_workspace / _edit_cabinet).
  WorkspaceCanvas draws on schematic paper (SchematicTheme, follows White schematic paper)
  solid tiles (WorkspaceTile: switchboard teal, station blue, field grey, white signs; also the
  tree's icons): the place's tile with "+RA1" under it (Workspace.place_tile: at the top in the middle of
  Workspace.PLACE_SIZE; its title, what it holds and the keys bound to its buttons and switches
  in the tooltip, WorkspaceCanvas.place_tooltip), a part's tile with
  "-M1"; a station can be shown as its face instead (place menu in Edit mode, ControlBox.face_scale,
  saved as "face", SchematicDocument.set_station_face, undoable): a ControlBoxView over the canvas at
  its place and scale (WorkspaceCanvas._place_faces; Workspace.place_size gives its size to cables,
  groups and free spots), operated there while simulating (button_held / switch_toggled; a click
  on its housing does not open it then), resized in Edit mode by the handle at its corner
  (ControlBox.MIN_FACE-MAX_FACE); wheel zooms at the mouse, right / middle drag pans, a right click without a drag asks
  for a menu (Open, Open in a new window, Rename…, Delete; on parts Show in the schematic, Take
  out of the group; on empty paper Add … here), left drag moves (Edit mode, one undoable edit
  at the drop, SchematicEditor.edit_workspace), a click on a switchboard or station opens it:
  map + detail, the CabinetPanel / StationPanel takes the canvas's room with a bar above (back,
  rename, window, close; Esc goes back) and the tree stays as the map (a click on a device in
  it opens its place with the device selected). The tree lists switchboards with their devices
  and strips, stations with their items and the lamps inside them, groups with their parts, the
  parts in the field and
  what has no place yet (Workspace.unplaced: devices and strips in no switchboard, buttons,
  switches and lamps on no station); its search field filters it. PlaceWindow shows a
  switchboard or station in a window of its own (follows the shown document, follows its place
  when it is renamed (as does the opened place, also after undo; WorkspaceView.follow_place) and
  closes when it is gone; keys it does not use go to main.gd's shortcuts). While simulating only
  the
  opened place shows the circuit's state; on the workspace only the motors in the field turn
  (three marks going round the ring of a motor's tile, WorkspaceCanvas.motor_turn: the share of
  its rated speed, signed; SPIN_RATE turns a second at rated speed). Older files: the rails of
  "cabinet" become switchboard RA1, control boxes become stations ST1, ST2, … side by side
  (SchematicDocument.name_places)
- Cables of the workspace (WorkspaceCables, no nodes): worked out from the wiring, never drawn
  by hand. Every part has a place by designation ("+RA1" a device on a rail, an overload relay
  under its contactor where the contactor is; "+ST1" a button, switch or lamp on a station, also
  a lamp inside a button; "-M1" a part in the field; contacts go with their device); a net
  reaching two or more places gets a core between them: from the switchboard with a strip
  terminal on it to each other place (a star from the strip), else from the first switchboard,
  else along the shortest tree between the places' centres (stop buttons looped through from
  station to station). A strip terminal on the lead of a part at the other end has a core of
  its own to that part where its net has two or more such terminals (WorkspaceCables._split; the
  switchboard lands each, joined there by a plug-in bridge or wires). The cores between two places are one cable (key "+RA1|+ST1", its ends in
  workspace order: switchboards, stations, parts in circuit order), each core with what it lands
  on at both ends
  (at a switchboard its strip terminals alone when it has some) and its wire number, the PE core
  last. A cable's type (WorkspaceCables.type_text) follows its use (WorkspaceCables.use, "use"
  in the cable: a motor at an end MOTOR, else a sensor SENSOR, else a limit switch FIELD;
  between switchboards and stations FEEDER with power cores, else CONTROL) from
  WorkspaceCables.TYPES, Czech or European by WorkspaceCables.naming (Settings menu, user settings
  "cable_types"): motor and field CGSG-J / H07RN-F, sensor LiYCY / H05VVC4V5-K (shielded),
  feeder CYKY-J / NYY-J, control JYTY-O / H05VV5-F ("J" with a PE core, "O" without; harmonised
  H0... types "4G2,5" with PE, "4x2,5" without); its cross-section (WorkspaceCables.section,
  "section" in the cable) is CONTROL_CABLE_SECTION (1 mm²) for control, SENSOR_SECTION for
  sensors, CONTROL_SECTION for other cables without power cores, else the smallest of SECTIONS
  taking the current: a motor's rated current for a cable to it, all motors' together for any
  other. Set by hand per cable in its CablePanel (Edit mode, undoable, SchematicDocument.set_cable
  / cable_settings, saved as "cable_settings", kept and dropped with the cable's name): a type name
  in place of the one by use ("type"), a cross-section of WorkspaceCables.CHOICES ("section";
  "auto_section" keeps the one by current) and the length in metres ("length", shown with the type
  on the workspace and in the parts list, WorkspaceCables.type_and_length); the panel shows
  WorkspaceCables.voltage_drop: power cables √3 I L ρ cos φ / S with the motors' rated currents
  against 400 V, control cables 2 I L ρ / S with the rated draws of the loads on each core's net
  against their rated voltage (worst core), ρ = RESISTIVITY (0.0225), marked above DROP_LIMIT 4 %.
  Names W1, W2, … in order, kept in
  SchematicDocument.cable_names (saved as "cables"; name_cables after every edit gives new
  cables the first free number and drops the names of cables that are gone; renaming a place
  or a part keeps its cables' names; rename_cable). WorkspaceCanvas draws them under the tiles
  as tracks: the sides of both ends are chosen by trying every pair from the sides' middles
  (fewest places in the way, then shortest, then fewest bends; a bottom side starts under the
  name of the place or part), each cable leaves from a point of its own
  in line with its other end's port (two rounds), a lane apart from the others on that side
  (closer on a short side),
  runs out STUB, then at right angles (Z or L) with CORNER-rounded bends, the middle run moved
  by its lane as far as the route allows; a dot at both ports; power cables (with a power core)
  thicker and darker; the
  name and type written beside the wire, never on it and without a box (above a level run, else
  below; along the right of an upright run reading upwards, else the left; TAG_GAP from the
  wire), on the longest straight run, the name alone when both do not fit (the tooltip has it
  all), moved along it or onto another run to keep clear of places, parts, other names and,
  where it can, the cables; a click on a cable (name or line) or on it in the tree ("Cables")
  opens CablePanel in place of the canvas: a row per core, wire number, both ends
- Mechanical links (Travel in sim/, no nodes): a group's member motor (WorkspaceGroup.drive)
  moves its part, e.g. a gate, from 0 to 1 in travel_time at full speed (the rated speed of its
  fastest speed step), forwards (clockwise;
  a plain Motor while it has power) towards 1; it starts at start; member limit switches
  and proximity sensors (stops: designation -> 0-1) are operated at an end while the part is there, between the ends
  within Travel.BAND (both blocks of a switch, through its actuator); the part stops at the
  ends (no stall modelled). Set in the group's menu, "Mechanical link…"
  (SchematicDocument.set_group_link, undoable; saved with the group). Workspace.travels builds
  them for a simulation (SchematicView.load_document gives them to Simulator.travels); the
  simulator moves them with the motors (IDEAL: every step; REALISTIC: an event where the part
  reaches an end or a switch's band, Travel.time_to_next_event) and logs "SQ1 actuated" /
  "let go". The canvas draws the link (between members of the group only) as dashed lines from
  the motor to the switches and the
  way along the bottom of the group's frame: a tick per switch, the start (Edit) or where the
  part is (Simulate, SchematicView.travel_positions)
- Keys: SchematicDocument.key_bindings (designation -> key name as OS.get_keycode_string, e.g.
  "A", "F2"; saved as "keys") for push buttons and switches (can_have_key); set_key keeps a key
  on one device (undoable through SchematicEditor.edit_workspace), device_of_key finds it; a
  renamed device keeps its key unless the new name has its own (a block joining a device) or
  cannot take one; deleting the last part of a device drops its key, field position, group
  membership and link role. "Bind a key…" in the context menus of the schematic, an opened
  station (StationPanel) and the workspace tree opens KeyPrompt (window_input: Esc, Enter, Tab
  and combinations with Ctrl/Alt/Meta are ignored, Space and F11 refused, Delete/Backspace takes
  the key off). While simulating main.gd's _bound_key runs before the shortcuts (no Ctrl/Alt/
  Meta): a push button is held while its key is down (released on focus loss), a switch flips
  on a press; also from PlaceWindows. Keycap draws a key; SchematicSymbol.key (SchematicView
  sets it when show_keys, off for exports; drawn beside the designation on the side away from
  the symbol, after it when the designation is above or below), ControlBoxView (under the
  label plate) draw them, lit while a button is held (a station's tile lists them in its tooltip). KeyStrip above the timing panel (Simulate, when there are keys)
  lists every key, what it operates and where, rolled in or out (user settings "keys_rolled")
- Control stations: control boxes (SchematicDocument.control_boxes,
  ControlBox / ControlBoxItem, saved) drawn like real ones (grey housing, black label plates,
  coloured push buttons, 0/I selector switches, signal lamps, illuminated buttons and switches with a lamp inside, its designation on the plate too);
  items name devices by designation (buttons, switches without limit switches, lamps) and follow
  renames; opened from the workspace (StationPanel: the box drawn large, ZoomBox, the editing
  tools beside it in Edit mode, undoable; the tools are ControlItemTools, shared with the
  switchboard door), operate the simulation in Simulate mode. Front | Inside at the top of an
  opened station (StationPanel.inside_shown) shows it with its cover off (StationInside, no
  nodes, laid out in mm; StationInsideView draws it with CabinetPainter, fitted to the room):
  behind each button or switch its contact blocks side by side on the mounting adapter (every
  part with its designation that switches with it: NO green, NC red, CO both; a lamp block
  in the middle of an illuminated one), behind a lamp its lamp block, behind a cam switch a
  chamber a pole; screw terminals on top and below with their numbers (a changeover's common
  and a cam switch's load side below), the designations on a label at the top left of each
  item; the workspace cables to the station come in through glands in the top, a core of
  each to the first terminal here it lands on (WorkspaceCables cores), the other terminals of
  a net joined to the nearest one joined already; a wire goes straight into the contact at
  the block's top or bottom face, under its screw (never onto the screw, no opening drawn;
  terminal "entry"), and leaves it up or down into
  a lane of the channel above or below its row, run along it and down the left side in a
  lane of their own between channels (channels and the side as wide as their lanes), coloured
  by conductor, with ferrule collars and marker sleeves (CabinetWiring.wire_marks; drawn
  too small for the sleeves' numbers to be read, below StationInsideView.NUMBER_PX, each
  number also on a white tag beside its sleeve; a door harness core has a sleeve where it
  comes out of its fitting too, on both sides of the hinge, and the conduit a tag with
  their numbers); while
  simulating the terminals are ringed in their voltage's colour (StationPanel.show_step) and
  lamp blocks light Every switchboard has a door
  (Switchboard.door, a ControlBox: columns and items only, saved as the switchboard's "door"
  when it has items or other columns): SchematicDocument.control_panels lists the stations,
  then the doors; the item edits (add/set/move/remove_control_item, fill_control_box,
  set_control_box) take an index into it (a station's own index, door_panel(board) for a
  door), a device shows on one station or door only (control_panel_devices), and a door's
  items are in the switchboard's place ("+RA1": WorkspaceCables, the tree under the
  switchboard, the parts list, the key strip; Workspace.door_of). CabinetPanel shows the door
  in place of the inside (Inside | Door | Door open at the top, door_shown, door_open,
  select_door_device): a
  DoorView (a ControlBoxView drawn in mm with CabinetPainter, after a photo of a real door:
  RAL 7035 face the size of the enclosure, larger only when its items do not fit at
  DoorView.PITCH, the items sharing out its width and height, two quarter-turn locks on the
  left, "+RA1" and the title top left, the yellow warning sign at the top, 22 mm devices with
  a black label holder under each, yellow position tags over selector switches, rotary cam
  switches bigger), edited (door_edit_requested, a workspace edit) and operated as a station;
  the export puts the door beside the inside on the switchboard's sheet. Door open draws the
  inside with the door opened beside it, hinged on the switchboard's right
  (CabinetView.door_open, DOOR_GAP, CONDUIT_ROOM): the door's back laid out by
  StationInside.build_door (each item behind its place on the front, mirrored; the blocks
  and wires as inside a station, drawn by StationInsideView.paint; the channels clear of a
  cam switch's back, StationInside.BACK_HALF; the labels beside the devices), hinges on its
  left, the locks' latches on its right; a core of the door harness for each net of
  CabinetWiring.door_harness comes in through a fitting in the door's hinge edge, at the
  height the harness leaves the switchboard, its conduit (CabinetParts.conduit) straight
  across the hinge from the switchboard's wall, and goes up the hinge side to its channel
- Switchboards (rozvaděč, opened from the workspace, both modes): DIN rails (Switchboard.rails,
  CabinetRail / CabinetItem: a device by designation or a terminal strip by name; a device or
  strip has one place in all switchboards, SchematicDocument.cabinet_has; saved in "switchboards")
  drawn by CabinetView / CabinetLayout / CabinetParts in millimetres (CabinetPainter), real sizes, after
  photos of real devices but never with maker names or type designations; approved look: white plate,
  slotted TS35 rails, open slotted ducts, white labels, push-in terminals, orange glow on energized
  coils, voltage colours on terminals while simulating. The look follows the circuit (CabinetDevices):
  breakers and fuse holders 1-4 poles, contactors 3 (also for 1-2) or 4 main poles plus a front
  auxiliary block (four contacts) beyond two auxiliary contacts and 9 mm auxiliary blocks of two
  contacts mounted on their sides beyond six (CabinetParts.side_blocks: the first on the right,
  the second on the left, further ones outside them; the overload relay stays under the
  contactor itself; a changeover contact takes an NC and an NO place), the overload relay fitted
  under the contactor its heaters follow (drawn there only, even when it is on a rail too; on a
  rail of its own it sits on a mounting unit with its heaters' terminals 1 3 5 on top), relays
  one changeover contact per contact used (1: 6.2 mm module, 2: slim socket,
  3-4: wide socket), time relays 1-3 changeover contacts (more contacts on further relays or
  time relays beside it, their coils, A1#2 …, wired to the first one's), bridge rectifiers one
  dark module, PLCs
  four modules in Siemens grey; breakers print their characteristic and rating ("B2", "C16");
  terminal strips from terminal labels ("X2:4" = strip X2, plain "4" = strip X1), their
  terminals in the order set in the sidebar (SchematicDocument.strip_orders, saved; arrows move
  the picked terminals along the strip), else by label with those of one net side by side
  from where the first of them is (CabinetDevices._grouped; supply points of one conductor are
  one net in the switchboard, CabinetDevices.supply_nets, for the bridges too); neighbouring
  terminals of one net are joined by a plug-in bridge instead of a wire (CabinetWiring.strip_bridges, the strip's
  desc "bridges"; grey, blue on N; one point for the wiring tree; in the parts list). A strip
  terminal takes one wire in each entry; one that still has to join a second wire (where the
  wiring, the grouping and the distribution blocks leave no other way, e.g. an order set by
  hand) takes both in one twin ferrule (CabinetWiring._tree marks the point "twin"; its two
  wires side by side, starting CabinetParts.TWIN_IN out from the entry with no ferrules of
  their own, wire "pins" -1; CabinetWiring.twins, drawn over them by
  CabinetParts.twin_ferrule: one pin, the collar round both, coloured as a single one). Where
  more than CabinetLayout.BUS_LOADS (1) load takes N or PE in a switchboard (strip terminals on
  the net but the incoming one, devices' terminals on it; not N wired to the supply point of
  another conductor), it gets an N or PE distribution block
  by itself (CabinetLayout.bus_blocks, N first: a place of kind BUS_BLOCK, index -1, not a rail
  item and not selectable, desc "neutral", "nets", "connections", right after the strip the
  incoming conductor lands on, CabinetParts.BUS_SIZES 7, 12 or 15
  screw connections, drawn as made, standing across the rail: a brass bar in a yellow base under a
  green cover for PE, a grey base under a blue cover for N, with a round hole over each screw, the
  wires going in under the cover's left edge
  by their screws, all from the left (CabinetParts.bus_entry), out CabinetWiring.BUS_LEAD past the block (further for those
  further along, so no lead crosses another) and on to the duct over (upper half) or under it,
  room on its left for the leads, CabinetParts.bus_block): the net is wired as a star from it, one wire to each
  connection and from each load, its strip terminals not bridged then (CabinetLayout.bus_nets); in the parts list. Wired after the circuit (CabinetWiring): each net
  joins its terminals on the rails along the shortest tree with at most two wires in any
  device terminal's clamp and one in a strip terminal's entry (CabinetWiring.CLAMP_WIRES: looped from terminal to terminal where it would
  branch; a clamp keeps room for a wire on to another switchboard; where that tree would need a
  strip terminal to take a second wire, the device terminals are joined first and the strip
  terminals at the ends, CabinetWiring._grow, if that needs fewer; a core of the incoming
  cable starts at the cable), every wire straight from its terminal
  towards the duct over or under its rail, past its sleeve, then one bend slanting into a slot
  between the fingers (CabinetWiring._slants: wires whose slants lie side by side bend at one
  height, the latest any needs and at most SLANT_MAX before the duct, the slots taking them in
  the order of their terminals, so no slant crosses another and wires heading apart cross in
  the duct; without room to slant the two short turns by the duct), along the duct in a
  lane of its own (down a side duct to another duct); the lanes are laid so wires are easy
  to follow (CabinetWiring._lanes): wires coming in over one edge of a duct lie nearest it, a
  run nested in another nearer the edge, those coming in over both edges between them, stepped
  by the way they head; each run past every earlier run it overlaps; each
  duct just as wide as its wires need side by side at its busiest point, in whole millimetres
  (CabinetWiring.lanes, CabinetLayout.duct_size; CabinetLayout.build lays out, wires and sizes
  again until every duct fits, never narrowing one, and keeps that wiring,
  CabinetLayout.wiring; the view lays out again only for edits and a new scale); a contactor with its overload relay under
  it has a wiring channel on both sides (CabinetLayout.WIRE_CHANNEL): wires from its bottom
  terminals go straight down as far as they can without passing over a screw on their way down
  or across, then run across its front at heights clear of its screws (CabinetParts.CONTACTOR_OUT_Y,
  a side block's wires at the first under their terminal); wires on from its power outputs,
  which carry the relay's heaters, go down behind the relay and come out at its left side (all
  of them) near its top, each a lane lower than the one before (CabinetWiring._behind_height; their end
  out of sight: wire "pins" -1), straight on into the channel
  out to the nearer side and down beside the relay, never across it; wires from the auxiliary
  contact block on its front run straight on over the contactor's tiers, in at the block's top
  and bottom (its columns, CabinetParts.AUX_BLOCK_X / AUX_BLOCK_X4, lie between the
  contactor's, clear of the wires going into them; over an overload relay its bottom wires go
  out to the side like the contactor's); colours by conductor
  (CabinetDevices.conductors): red = phase of the control circuit (L), light blue = N (and the
  DC - pole, a rectifier's - too), grey = main power circuit (L2/L3 and the terminals of main
  contacts, overload relay
  heaters, 3~ motors, fuses, breakers and rotary cam switches of 2-4 poles), green-yellow = PE; wires go into the
  top of strip terminals, wires near each other share the nearest slot; a wire to a device
  terminal goes into the face of the terminal's tier, past the screw (CabinetParts.wire_entry:
  the outer tiers' top or bottom face, the step where an inner tier begins, a time relay's wire
  slots, a VFD's terminal recesses; at the screw for a fuse holder's deep opening and for a
  contactor's power outputs over its overload relay), wires sharing such a terminal side by
  side; every wire end has an insulated ferrule collar (CabinetParts.COLLAR, yellow on control,
  blue on power wires), its metal showing only going into a strip terminal (wire "pins");
  device labels sit on the plate CabinetLayout.LABEL_OFF over (or under) their device, drawn
  with the place under the wires (a contactor's on its front); every wire carries a
  yellow marker sleeve at each terminal end with its wire number printed along it (bottom to
  top; the supply conductor's name "L1", "N", "PE" on a net without a number;
  CabinetWiring._marks), CabinetParts.MARKER_FROM from the end and before the bend into the
  duct (CabinetLayout.PAD, 20 mm between the ducts and the parts, leaves the room), placed by
  CabinetWiring._markers (wire "markers") and drawn over all wires; wires sharing a terminal
  spread out under it (CabinetWiring.FAN, as far as the next terminal and the screws on their
  way allow) so their sleeves sit side by side, a sleeve that would still cover another moves
  on along its wire by its length (one above the other, by turns along a strip); the supply comes in
  from outside: one cable per source (AC, DC) through a gland in the top of the enclosure, one
  core per supply conductor (L1 L2 L3 N PE, + -) straight down into the top duct to the first
  terminal it feeds, or onto the field side (bottom entry) of the strip terminal on a supply
  point's lead. Strip terminals leading to parts outside (CabinetDevices.is_outside:
  buttons, switches, lamps, motors; field_device finds the part: the one whose lead the
  terminal is on, else the first on its net) send field wires out of their bottom entries to
  the bottom duct and out through a gland in the bottom of the enclosure, one cable for each
  cable of the workspace from this switchboard, with a core for each net as on the workspace
  (the first of its terminals; the others joined inside; a net going on to another switchboard
  leaves the same way in the cable between the two, on both boards; the plate is wide enough for
  a slot of the bottom duct to each cable, CabinetWiring.bottom_slots, glands side by side
  narrower where they would meet) (its name "W2" on the gland, all the buttons and
  lamps of a station in one; CabinetWiring.build(doc, layout, k, board)), one per part for parts
  without a place ("-SB1" on the gland), cores coloured like the other wires (a PE or N terminal gives a PE or
  N core). Strip terminals on a PE wire are PE terminals, on an N wire blue N
  terminals. A strip is split in the sidebar: picked terminals move to another strip or a new
  one (SchematicDocument.move_strip_terminals relabels them, "5" -> "X2:5", a taken number
  becomes the next free one; a new strip gets a place right after the old one). The drawing
  zooms (CabinetView.zoom over fitting the width and the height, CabinetView.fit_height, centred
  across: buttons, Ctrl+wheel over it; right or middle drag moves it; painted in layers,
  CabinetView.Layer: plate/rails/ducts, each place, wires/glands/labels, selection, each painted
  again only when what it shows changed, the layers scaled while the zoom changes and painted
  sharp CabinetView.ZOOM_SETTLE after it; laid out again until the scale it fits at changes by
  less than CabinetView.SETTLED, as the terminal strips snapped to whole pixels make it a little
  wider or narrower at each scale, and painted at the scale it was last laid out at
  (CabinetView._built_k: the wires were routed to terminals at that scale's pitch); while simulating the places are only described again,
  CabinetLayout.describe_again); each switchboard is laid out
  and wired on its own (CabinetLayout.build(doc, k, board), CabinetView.board). Strip
  terminals leading to parts on the switchboard's own door send their cores to the door as
  one door harness (CabinetWiring.DOOR in place of a cable name) that never leaves the
  enclosure: out of the strip terminals' field side into the bottom duct, along its bottom in
  lanes of their own to the hinge side and through a fitting in the right wall (its gland
  "door", CabinetParts.door_fitting, tagged Door); to a door of another switchboard in the
  cable between the two. Edited in
  CabinetPanel beside the drawing (undoable, "Fill from the schematic" fills the opened
  switchboard), breakers, fuse holders and overload relays operated there while simulating.
  tools/screenshot_workspace.gd screenshots the app's workspace, a switchboard and a station
  (xvfb) for visual review; tools/screenshot_readme.gd takes the screenshots in README.md
  (docs/screenshots/, kept out of the project by a .gdignore): retake them when the look changes
- PLC (Plc, "A1", modelled on the small Siemens logic modules with relay outputs, never with
  maker names or type designations on the drawing): a Load on L1-N with inputs I1-I8 (on with
  voltage against its N, like a time relay's S) and relay outputs Q1-Q4, two terminals each
  (Q1.1-Q1.2, switch paths with an Armature per output, 10/8 ms). Expansion modules
  (Plc.modules, Plc.Module: 4 inputs + 4 relay outputs or 8 + 8, saved as "modules"; at most
  Plc.MAX_INPUTS 24 inputs and MAX_OUTPUTS 20 outputs in all, Plc.modules_fit) clip on to its
  right as on the real ones: their terminals follow the PLC's (its own never move), each module
  its own supply 2L1-2N, 3L1-3N ..., inputs and outputs numbered on (I9.., Q5..); a module works
  while its own L1-N has voltage and the PLC works (Plc.module_power, logged), its inputs are on
  with voltage against its own N, it draws Plc.MODULE_DRAW; the circuit check wants the modules'
  supplies wired (the commons of a compact CPU and its digital modules, 1M, 3L+ 3M, only while
  inputs or outputs using them are wired; it hints at analog modules on the AC supply). Terminal
  indices come from the instance (input_terminal, output_terminal,
  module_terminal, module_terminals); the properties add a module after the last one or take
  the last one off, so the other terminals keep their numbers (names given by hand stay). Analog:
  the 24 V and 12/24 V versions read I7 I8 I1 I2 also as AI1-AI4 (volts from a sensor or an AQ
  at the input's threshold also switch the digital input) (Plc.ANALOG_VERSIONS); analog
  modules (Module.AI2: nL+ nM nU1 nU2, AI numbered on after the PLC's own; Module.AQ2: nL+ nM
  AQ1 AQ2; always 24 V DC, Plc.module_rating) up to Plc.MAX_ANALOG 8 of each; terminal roles
  (Plc.Role: supply, DI, DQ, AI, AQ) place them on the symbol and in the switchboard. The
  simulator puts analog volts on nets (sensors with their supply, AQ of working PLCs; a DC +
  pole reads its voltage) and hands each PLC the volts on its AIs (Plc.analog_in, 0-10 V =
  0-1000 in PlcRuntime.analog_inputs); Plc.analog_output_volts from PlcRuntime.analog_outputs. It runs its PlcProgram
  (sim/plc/, no nodes) through PlcRuntime: scans when the power or an input changes and when a
  program timer ends, until a scan changes nothing (PlcRuntime.MAX_SCANS; a program that keeps
  changing is scanned again after Plc.CYCLE_TIME and reported as oscillating); losing power
  resets it. A program holds both a function block diagram (PlcBlock: connectors I/Q/M/hi/lo,
  AND OR NOT NAND NOR XOR with 4/4/1/4/4/2 inputs, on-/off-delay, latching relay, pulse relay,
  up/down counter, analog input AI / output AQ connectors, analog threshold trigger, analog
  comparator (On / Off with hysteresis), analog amplifier (gain, offset; PlcRuntime.analog holds
  the analog block values, a digital source reads 0 / 1000); numbered B001; worked through in
  signal order, a feedback loop starting at its lowest-numbered block) and a ladder diagram (one
  PlcRung along one power rail, no networks: rows
  of 8 cell columns, cells wire/NO/NC/P/N (edge contacts, closed for one scan) with operands
  I Q M T C, comparing contacts AI >= value / AI < value, vertical links at the right side of a
  cell, a coil per row: assignment, negated, S, R, SD, SF, CU, CD, AQ (value while powered, 0
  without); rows joined by links make a rung (PlcRung.rung_groups, numbered in the
  margin), rungs run from the top, power flows column by column, linked rows share it; older
  programs with several networks load as rows one after another);
  language says which one runs; the PLC window exports a program to a file of its own and
  imports one (ProjectFile.save_plc_program / load_plc_program, ".plcprog": JSON format
  "ladder-lab-plc", version, program; import is one undoable edit). Operands I1-I24, Q1-Q20 (the PLC window offers
  those the PLC has with its modules), M1-M16, T1-T16, C1-C16. Saved with
  the component ("program"); damaged parts of a program are left out, never refusing the file.
  The symbol (PlcSymbol): a box with L1 N I1-I8 on top, the output contacts below (moving),
  input lights and a RUN display; each expansion module a box of its own one cell to the right
  (SymbolGeometry.plc_terminal_cells / plc_module_origins), joined by a plug, its window filled
  while it works. In the switchboard (CabinetDevices.Kind.PLC, CabinetParts.plc)
  a four-module device in Siemens light grey (RAL 7035) with anthracite (RAL 7016) keys, print and
  display frame and a white backlit display: L1 N I1-I8 screws on top, the two screws of each output under
  its module below (CabinetParts.terminal_points by the standard marking, the schematic's names
  printed), a display with the inputs and output relays that are on (backlit while powered, RUN
  and the language; beyond 8 in rows of ten marked by their last digit), cursor keys, ESC / OK;
  its expansion modules beside it (two or four modules wide, CabinetParts.plc_size), in the same
  grey with a raised middle, INPUT / OUTPUT print, a RUN/STOP light; it sits on the first rail after the rectifiers
- Compact PLC (CompactPlc extends Plc, "A1", modelled on the small Siemens controllers in their
  24 V DC version with transistor outputs, never with maker names or type designations): CPU
  sizes (CompactPlc.Cpu: 6 DI / 4 DQ, 8 / 6, 14 / 10, each 2 AI; saved "family": "compact",
  "cpu"), terminals L+ M, 1M I0.0 ..., 2M AI0 AI1 on top, 3L+ 3M Q0.0 ... below; rated
  "cpu24dc" (24 V DC, inputs on from 15 V against their common, Plc.input_reference); a
  transistor output (Plc.Role.TQ, one terminal) is a switch path from its group's supply 3L+
  (Plc._add_transistor_output, 0.5 ms); analog 0-10 V = 0-27648 (Plc.full_scale,
  PlcRuntime.full_scale). Signal modules (Plc.Module.SM_*: 8 DI, 8 DQ, 8 DI / 8 DQ, 4 AI, 2 AQ; as
  many as the CPU takes, CompactPlc.CPU_MODULES 0 / 2 / 8, modules_fit_cpu) are named by their
  slot (2.1M, 2.L+, 2.AI0) with addresses as by default in the programming software: DI / DQ
  from byte 8, four a slot (I8.0, Q12.0), analog words from 96, sixteen bytes a slot; digital
  ones work with the CPU (Plc.module_supply -1), analog ones need 24 V on n.L+ n.M. The program
  keeps I1, Q1, AI1 ...; Plc.address writes them %I0.0, %Q0.0, %IW64, %M0.0 in the PLC window
  (PlcCanvas.address). A PLC's wires follow their terminal names when the CPU size changes
  (SchematicDocument.replace_component maps them, Circuit.replace takes the mapping). Symbol:
  terminals by Plc.terminal_on_bottom, transistor outputs with a light; switchboard
  (CabinetParts.compact_plc): 90 mm CPU (110 mm the largest), 45 mm modules, 100 mm high, the
  same grey, open terminal blocks without covers, RUN/STOP ERROR MAINT, channel lights DI a /
  DQ a, network port X1 P1 with LINK Rx/Tx, memory card slot X50; a module's DIAG light
- PLC window (ui/plc/, PlcWindow): opened by double-clicking a PLC, from its properties or by
  clicking it while simulating; one per PLC; keys it does not use (releases too) go to main.gd,
  Space stays in the window for Space+drag. FBD (PlcFbdCanvas) or LAD (PlcLadCanvas, both
  PlcCanvas, drawn on schematic paper in a ScrollContainer: wheel scrolls, Ctrl+wheel zooms at
  the mouse, middle / right drag or Space+drag pans; a right press that does not move is a
  click) switched at the top (the PLC runs the one shown), a palette of tools on the left, the
  selection's operand / time / preset on the right. FBD: frame selection on empty paper (Shift
  adds), the selection moves together, Ctrl+A / C / X / V (pasted at the mouse with new block
  numbers, connections between the copies kept). LAD: the power rail runs the whole height,
  spare rows below the last one, anything placed anywhere along it (the tool's element drawn
  faintly where a click puts it); wires drawn as in the schematic between cell sides (start,
  corners, one-corner preview to the mouse, ends on the rail, an element, a wire or a link or by
  a double click; runs along a row fill its empty cells, runs down a side become links;
  Backspace / Esc); Insert / Delete row.
  Simulation (Edit mode, as in LOGO!Soft Comfort): a Plc of its own runs a copy of the program
  with switches I1-I8 and lamps Q1-Q4 below the diagram and the time running; read-only
  meanwhile. In Edit mode it edits a copy and sends each finished change that alters the program
  to main.gd, which applies
  it with SchematicEditor.apply_properties (undoable; Ctrl+Z / Ctrl+Y in the window too). While
  simulating it shows the simulated PLC read-only: signals that are 1, the power flow, times
  and counts, 1 in PlcCanvas.ON (red), 0 in PlcCanvas.OFF (blue) as in the programming software. Windows rebind when the document is loaded or edited and close
  when their PLC is gone
- Keep the simulation logic (solver) separate from scenes and UI:
  solver classes extend RefCounted and must work without any nodes
- Tests use GUT; run them with: godot --headless -s addons/gut/gut_cmdln.gd

## Conventions (Czech practice: ČSN EN 60617 / 81346 / 60947 / 60445)

- Device designations: A = PLC, BT = temperature sensor, BG = proximity sensor, BP / BL / BF =
  pressure / level / flow transmitter, TA = frequency inverter, KM = contactor, KA = auxiliary (control) relay, KT = time relay, SB = push
  button, RB = rotary switch (also the rotary cam switch, CamSwitch: a knob turned by hand,
  snap action, starts at 0, its position simulation state; 0-I poles 1-2, 3-4 … closed in I,
  drawn as NO contacts; I-0-II poles I side 1, 3 … / II side 1', 3' … / common 2, 4 … below
  between them, SymbolGeometry.CAM_CHANGEOVER_SPACING apart, the blade straight up in 0; one
  turn actuator on the left on a dashed link, its switching table under the designation
  (SchematicSymbol.draw_position_table: the positions in a row, a dot under each one a contact
  is closed in; I-0-II a row for the first pole's I and II contacts, "1-2" / "1'-2"); a
  click turns it on 0 → I → 0 → II (CamSwitch.step_on), a station turns it left or right
  (CamSwitch.turn, switch_toggled's steps); a station shows it as a square black front with
  the positions round a handle, bigger than a selector switch (ControlBoxView.CAM_HALF);
  Circuit.get_operator returns it, no contacts follow it; a selector switch, LatchingSwitch,
  is 0-I or I-0-II (three_positions; its blocks share a second actuator actuator_two for
  position II, each block operated in I or II, side; "positions", "operated_in" saved; a
  station draws I 0 II round it and turns it left or right like the cam switch; its blocks
  draw the switching table I 0 II under the designation, a dot under the position that
  operates them), SQ = limit switch (LimitSwitch, a LatchingSwitch clicked on/off,
  or operated by a mechanical link),
  H = lamp, M = motor, FU = fuse, FA = circuit breaker, F = overload relay, X = terminal, supplies L (= L1), L2, L3, N
  and PE (bonded to N at the source: N potential in the solver, so a phase on PE is a short;
  wires reached by PE alone are drawn in the PE colour, StepResult.REACH_PE),
  DC supplies + and - (a separate source: loads work between two conductors of the same source;
  AC joined to DC is a short; a short that no protective device interrupts drops out only the
  sources it is on (the mains, the DC source, an inverter's outputs) while it lasts, only the
  fault path shown; the - pole is drawn like N; a + supply has a voltage,
  PowerSupply.voltage 12/24/48/110/220 V, default 24 V, each a source bit of its own, all sharing
  the - poles, so two + of different voltages joined are a short), TB = bridge rectifier (Rectifier, a Load
  with terminals ~1 ~2 + -: while its input has voltage its + and - are DC poles, output taken as
  isolated, 207 V DC, a source bit of its own, BIT_DC_RECTIFIED; its input carries current only
  while its output does)
- Voltages: 230 V between a phase and N, 400 V between two phases (PowerSupply.PHASE_VOLTS,
  Simulator._volts). Coils, time relays, lamps and PLCs have a rated voltage (Load.rating,
  VoltageRating: "230ac", "24dc", lamps "230v" AC or DC, PLC versions "230rc" 115-240 V AC/DC,
  "24rc", "1224rc" 12/24 V DC with their input thresholds; saved as "rating"; "" = works on any
  voltage, parts of older files and parts made in code); new parts from the palette get the first
  offered (230 V), a coil turned into a time relay keeps it. Below PICK_UP (85 %) a part does not
  work, above BURN (130 %) it burns out (Load.burnt, simulation state, logged, shown as a fault,
  "Replace the burnt-out part" in the fault menu), an AC coil on DC burns out from 30 % on, a DC
  coil on AC does not pull in; a PLC also burns out with too high a voltage on an input or a
  module supply. The rating is written under the designation, a + supply's voltage beside it
  (supply points of one conductor are the same potential on every page); next to L2 or L3 a plain "L" supply is renamed
  "L1" ("L.2" -> "L1.2", SchematicDocument.name_first_phase, run after every edit); phase supplies
  placed one after the other with the place tool take the next phase, L1 → L2 → L3 → L1
  (SchematicEditor._placed_data), unless a single-phase drawing names its phase plain "L"
- Terminals are addressed "<designation>:<terminal>", e.g. "K1:A1", "S0:11"; supplies are just "L" / "N"
- Contact terminals: first digit = sequence, second = function
  (1-2 NC, 3-4 NO, 5-6 delayed NC, 7-8 delayed NO); coils A1-A2, lamps X1-X2, motors U1-U2
- Power circuit: multi-pole devices (main contacts, fuses, breakers, overload relay)
  1-2/3-4/5-6/7-8; 3~ motors U1-V1-W1 (+U2-V2-W2 star/delta, drawn W2-U2-V2 under U1-V1-W1 as on
  the terminal board), Dahlander and separate windings
  1U-1V-1W/2U-2V-2W(/3U-3V-3W); phase order L1-L2-L3 on U-V-W = clockwise

## Layout

- `sim/` solver (Circuit, Simulator, StepResult, UnionFind, Armature, TraceRecorder, Phasor,
  MotorModel, CurrentFlow, TripCurve, components/) - no nodes
- Currents: AC as phasors in a Vector2 (Phasor; potentials in phase voltages, L1 = 1∠0°, N = 0,
  DC + = 1). Loads draw Load.rated_draw() at 230 V (x √3 between two phases); three-phase motors
  what MotorModel gives; CurrentFlow spreads it (supply nets held fixed, other nets joined by
  closed switching paths of equal resistance, so parallel paths share; within a net along a
  wire tree); a working rectifier draws on its input what its output delivers. Results:
  StepResult.wire_currents / terminal_currents, ThreePhaseMotor.terminal_currents /
  line_currents, trace signals "<designation>/I1".. (motor lines L1-L3, device poles).
  Nothing flows during a short (the fault path is shown as before)
- MotorModel (cached per kind, Ia/In, rated slip, cos φ): windings in sets (one per speed;
  STANDARD star inside, STAR_DELTA U1-U2.. rated 400 V, Dahlander delta + tap halves taking
  part only while a tap is fed, separate windings as stars), each set an induction machine by
  symmetrical components (the rotor resistance growing with the slip as in deep bars,
  MotorModel.deep_bar, as far as needed for MIN_START_TORQUE 1.6 direct on line, so a motor of
  small rated slip still starts, also in star): positive and negative sequence admittance -j m + 1/(r2/s + j x) at
  slips s and 2 - s, zero sequence 1/(r2 + j x); calibrated to In at rated slip and cos φ and
  Ia at standstill; floating terminals and star points solved by nodal analysis. Torque
  (positive minus negative sequence rotor power) against a fan-like load (25 % at standstill,
  ThreePhaseMotor.load_level times rated at rated speed, set in the properties as "load" in % of
  the rated torque, saved; at least OVERLOAD_FACTOR when overloaded; the symbol shows the torque
  in N·m while simulating, ThreePhaseMotor.torque_nm from rated_torque = 9550 P / n) and inertia from run_up_time gives
  ThreePhaseMotor.rotor_speed (signed, fraction of the fastest synchronous speed; shaft =
  |speed| / rated speed of the step). REALISTIC: runs up in steps of at most MOTOR_STEP while
  not settled; IDEAL: snap_speed() jumps to the speed where torque meets load. Rating plate
  (rated_power, rated_current, rated_speed -> slip, power_factor, start_ratio, run_up_time;
  400 V supply, 50 Hz) drawn beside the motor with show_plate (marking "plate", draggable)
- 3~ motors: + and - across a winding = DC_BRAKING (with a phase = MISWIRED); the shaft
  (ThreePhaseMotor.shaft, simulation state) runs down in coast_time when switched off, in brake_time
  with DC braking; braking force follows the rotor field (rotor_flux, decays with ROTOR_TIME_CONSTANT
  after the AC cut), so DC applied at once brakes best; a star/delta motor running shows a large Y or Δ under "M3~"
- Analog sensors (AnalogSensor, a Load with a 0-10 V output: range_min..range_max of what it
  measures, AnalogSensor.measured / set_measured / unit; the simulator puts output_volts on the
  net of output_terminal() while it has its supply; a click while simulating opens a slider,
  SchematicView.set_measured; geometry, field kind SENSOR and parts list shared):
  TemperatureSensor and Transmitter (pressure / level / flow, "BP1" / "BL1" / "BF1" by
  Transmitter.LETTERS, Transmitter.Quantity with its unit, default range and value; terminals
  1 3 2 as on its M12 plug, core colours BN BU WH drawn beside the leads, rated "1530dc"
  15-30 V DC; TransmitterSymbol: the temperature sensor's box with the instrument circle
  "PT" / "LT" / "FT" (ČSN EN 62424) and an arrow to U; saved as "transmitter": quantity,
  range_min, range_max, value)
- Proximity sensor (ProximitySensor, "BG1", ČSN EN 81346-2 BG; a Load on 1-3 rated "1030dc"
  10-30 V DC): sensing inductive / capacitive / optical (diffuse) / magnetic, output PNP (a switch
  path from 1 to each output) or NPN (from 3), function NO / NC / antivalent; terminals as
  ČSN EN 60947-5-2: 1 BN L+, 3 BU M, 4 BK output, 2 WH the antivalent version's NC output
  (core_colour); detecting (simulation state: a click, or a mechanical link as a stop like a
  limit switch, Workspace.is_stop, Travel.is_on) switches each output through an Armature of
  SWITCH_TIME while it works (aim_outputs; the simulator settles them like coils, in its
  signature; trace "BG1/out1" rows in the timing chart). ProximitySensorSymbol: a box with the
  proximity rhombus (filled while detecting) and its sensing mark ("Fe", capacitor, light
  arrows, magnet), "PNP" / "NPN" under it, an NO / NC contact per output under its lead on a
  dashed link (drawn at rest without supply), core colours beside the leads; outputs on top
  SymbolGeometry.SENSOR_OUTPUT_CELL apart; saved as "proximity": sensing, output, function
- Temperature sensor (TemperatureSensor, "BT1", an AnalogSensor on L+-M rated 24 V DC, output U): puts
  0-10 V on U over its range (range_min..range_max °C, saved with the start temperature);
  drawn as a transmitter (box holding a resistor varying with θ, IEC 60617 S00561, as a Pt100,
  and U; TemperatureSensorSymbol; in the palette a thermometer → U), its range,
  temperature and volts written beside it; while simulating a click opens a slider
  (SchematicView.set_temperature); outside the switchboard like buttons and lamps
- Frequency inverter (Vfd, "TA1", modelled on the small Siemens drives, never with maker names or
  type designations; CabinetDevices.Kind.VFD): supply L1 L2 L3 (all three phases or it does
  nothing; PE not simulated), motor output U V W, control terminals 10V AI1 0V DI1-DI4 DIC 24V and
  the relay output DO2 (C-NO, closed while the motor runs). DI1 run, DI2 reverse, DI3 fixed
  frequency, DI4 coast stop (OFF2), on with 24 V against DIC (Vfd.INPUT_THRESHOLD); run / stop
  from the terminals or the keypad (Vfd.control), the setpoint from AI1 0-10 V or the keypad
  (Vfd.setpoint; a click while simulating opens its keypad, SchematicView.operate_keypad); the
  output frequency follows the target along the ramps (Vfd.advance; IDEAL: snap), through 0
  when reversing. The simulator: its 24V-0V a DC source and its 10V an analog source while it
  has its supply, its output nets source bits of their own (PowerSupply.BIT_VFD_U/V/W, AC,
  mains on them is a short, V and W swapped in reverse; a short on its output or its 24 V trips
  it, Vfd.tripped: output off, logged, until the run command is given anew or the supply
  returns) that the motors take as phases; a motor
  on them runs at frequency ThreePhaseMotor.frequency (fraction of 50 Hz): with V/f the torque
  and the currents depend on the slip frequency alone, so MotorModel is solved at the speed
  shifted by (1 - frequency) in the field's direction (ThreePhaseMotor._solve); it draws on
  its supply the power its motors take, balanced (Simulator._drive_input_draws). Symbol
  (VfdSymbol): a converter box with a diagonal, "3~ 50 Hz" / "3~ f", the frequency in a window;
  switchboard (CabinetParts.vfd): 90 x 150 mm, dark, heat sink fins over the supply terminals,
  display, O I M OK and arrow keys, warning label, control and motor terminals at the bottom
- Simulator modes: IDEAL (instant, solver default, used by most tests) and REALISTIC (Armature
  pick-up/drop-out times, NC breaks at 30 % before NO makes at 100 %, event-driven steps;
  documents default to realistic). IDEAL switches coils one at a time until nothing changes:
  coils switching round in a circle are frozen (reported as oscillating) while the others
  settle, and a short or too high a voltage between two coil switchings trips and burns nothing,
  only the settled state counts; S of a time relay is applied before its power
- `schematic/` drawing data (SchematicDocument, Placement, WireRoute, WireRouter, SymbolGeometry,
  ExampleCircuits, SheetLayout, PdfWriter, ProjectFile, RecoveryFile; the workspace: Workspace,
  Switchboard, WorkspaceGroup, ControlBox) - RefCounted, no nodes; any symbol can be rotated and mirrored left-right (F,
  mirror_component) or top-bottom (Shift+F, flip_component) as seen on the drawing, so
  vertical and horizontal current paths can be mixed
- `ui/` nodes: SchematicView, WireLayer, symbols/ (one _draw() class per symbol), main.gd
- UI look: `ui/app_theme.gd` (AppTheme) builds the whole Godot theme in code from colour tokens
  (dark/light), system fonts (MSDF font for schematic text), line icons as inline SVG via
  DPITexture; use its type variations (ToolButton, PrimaryButton, MutedLabel, ...) instead of
  per-control colours. No stretch scaling: the window uses content_scale_factor (View >
  Interface size); popups and context menus open through AppTheme.popup_at_mouse (at the mouse
  in window pixels, at the window's content_scale_factor, never at the drawing's zoom)
- Dialogs, popups and tooltips are embedded (drawn inside the window they belong to, never
  windows of the system: one left open off screen or behind would block the main window);
  PageWindow, PlaceWindow, PlcWindow and DatasheetWindow are windows of their own (force_native)
  and embed their own dialogs and popups
- `ui/timing/` TimingChart, EventLog, TimingPanel (Simulate mode, bottom); the chart ends with
  rows of currents (motor lines, poles of fuses, breakers and overload relays; autoscaled, rated
  current dashed); rows can be hidden from the list button beside Follow (TimingChart.hidden_rows
  by row key, "I " before the designation for rows of currents; saved in the user settings,
  "timing_hidden")
- Simulate mode shows a voltage view (wires coloured by voltage reach) or a current view
  (SchematicView.set_current_view, saved setting: only wires and terminals carrying current
  coloured, line width growing with the current, amperes written on the wires); a clamp meter
  (SchematicView.clamp_tool / clamps, simulation only) reads the current of clicked wires in
  either view. Symbols show ratings (breaker "C16", fuse "16 A", relay "Ir 8 A"), the heat of
  protective devices in % and a motor's line current and speed while simulating; the
  properties panel draws the time-current characteristic (TripCurveDiagram)
- `ui/export/` SheetRenderer (renders sheets in SubViewports), SheetFrame (frame, title block),
  StationsSheet, PartsSheet, PartsList (rows of the parts list),
  ExportPreview (dialog)
- `sim/plc/` PlcProgram, PlcBlock, PlcRung, PlcRuntime, PlcTimer, PlcCounter (PLC programs)
- `ui/plc/` PlcWindow, PlcCanvas, PlcFbdCanvas, PlcLadCanvas (PLC program window)
- `tutorial/` Lesson, Lessons, LessonCheck, LessonRun (lessons, no nodes)
- `ui/tutorial/` LessonPanel, LessonMarks, TutorialRings, TourOverlay, WelcomeCard
- `ui/workspace/` WorkspaceView, WorkspaceCanvas, WorkspaceTree, WorkspaceTile, PlaceWindow
- `ui/control_panel/` StationPanel (one opened station), ControlBoxView (one box drawn with _draw())
- `ui/cabinet/` CabinetPanel (one opened switchboard), CabinetView, CabinetLayout, CabinetWiring, CabinetParts, CabinetPainter
- `ui/editor/` SchematicEditor (tools, selection, undo), Palette, PropertiesPanel;
  edits go through SchematicDocument methods, which are tested without nodes
- Dragging (parts, wire segments, numbers, markings) starts only after the mouse moved CLICK_SLOP
  pixels, so a click never moves anything; parts are dragged from the state at the press
  (SchematicDocument.drag_start / drag_components), so wires are re-routed from their routes at
  the press, never from those of an earlier mouse position; turning or mirroring the parts
  mid-drag takes a new drag start where they are (and ends a wire segment drag). A re-routed wire
  (normalize_route) keeps its shape while that is clean and about as good as the best route,
  else WireRouter (A* on the grid of its page, near the wire's ends first) finds one: never
  across a symbol (supplies and page connectors: beyond their terminal), over a terminal of
  another net or along a wire of another net when a clean route exists, leaving terminals along
  their lead, few corners and crossings. The wires of moved or turned parts are routed one after
  another, each keeping off those before; then wires the parts now cover and wires between two
  moved parts are re-routed if no longer clean. Several selected parts turn and mirror together
  (rotate_components, mirror_components, flip_components: about the middle of their terminals,
  or the terminal nearest to it when turning about the middle would leave the cells, so four
  turns or a turn back put everything back; wires between them turned along); a single part turns about its first terminal.
  Several selected parts (junctions left out) line up from the right click menu ("Line up
  vertically… / horizontally…", SchematicDocument.line_up / line_up_cells): in their order
  along the line, the first stays, the others follow in its column or row (first terminals in
  line), a set number of free cells apart (between the cells each part takes,
  component_cells: body and terminals out to whole cells; asked for in a dialog, 1-50, kept
  for the next time); while asked, the editor draws a ruler beside them (beyond their
  markings, a tick and number at every cell, the cells each part will take marked) and keeps
  the dialog off it. Branch dots
  join wires of one net only
- Wiring helpers (Settings > Wiring, user settings "editor": wire_all_poles and wire_on_drop,
  off by default; SchematicEditor.wire_all_poles / wire_on_drop; "Wire facing terminals" is
  always in the right click menu). SchematicDocument.facing_pairs: free terminals (no wire) facing each other
  straight along a column or row, the first terminal straight ahead facing back (or without
  a lead: supply points), nothing in the way (WireRouter.is_clear); each terminal in one
  pair; connect_pairs wires pairs, routed. "Wire facing terminals (n)" in the right click
  menu (two or more selected) wires those of the selection, one undo step. parallel_pairs:
  a wire drawn from terminal to terminal brings along the free terminals beside each end in
  its row leaving the same way (the other supply points in line for a supply point), paired
  off in order from the two ends; Shift on the click that ends the wire draws it alone. A
  part placed or dropped (in the place's or the drag's undo step; EPLAN-style autoconnect) is wired to the free
  terminals of the page it faces. The wires to come are drawn dashed: the poles while
  hovering the end terminal, the part being placed (facing_wires_placed: added for the
  query and taken out again) or dragged
- Protection: Fuse/CircuitBreaker (ProtectiveDevice, terminals 1-2) trip when fault current flows
  through them; OverloadRelay (no control terminals) + OverloadContact 95-96/97-98; faults are
  simulation-only state (never saved). Overcurrent: every fuse, breaker and 3-pole overload
  relay has rated_current (relay: setting Ir) and TripCurve heat (simulation state): progress +=
  dt / trip time of the curve (breakers B/C/D thermal per ČSN EN 60898 with magnetic release at
  5/10/20 In tripping at once, rated current chosen from CircuitBreaker.STANDARD_RATINGS
  2-63 A as sold; fuses gG; overload relays class 10), cooling below the lowest
  point; a trip keeps the heat, which cools down from there (a breaker switched on or an
  overload relay reset while still hot trips sooner; a replaced fuse is cold); CircuitComponent.heat_up / time_to_heat_trip / trips_instantly, driven by the
  Simulator with the path currents of the last evaluation (event-driven in REALISTIC). Breakers
  trip all poles on the largest pole current, fuses per pole, the relay on its largest heater;
  a 0-pole relay (and the injected overloaded fault) still uses trip_delay
- Buttons/switches with the same designation share one actuator (multi-block devices); ids of
  switching elements are "<designation>:<terminals>"; any component may have custom terminal names;
  a part replaced by its edited copy (properties, Change type: SchematicDocument.replace_component)
  keeps its wires, strip terminals and terminal markings by standard terminal name, by position
  where no name matches (a PLC's only by name)
- Wire branches are `Junction` components; simulation runs on a serialized copy of the edited document
- Files: `.ladder` = JSON {format, version, document} via ProjectFile; bump ProjectFile.VERSION
  on format changes and keep older versions loading; values of the wrong type load as defaults
  (DocumentSerializer helpers); ProjectFile.save and RecoveryFile.write go through
  ProjectFile.write_atomically (<path>.tmp, checked, renamed; the rename tried again for about a
  second, as an antivirus on Windows holds a new file for a moment)
- Recovery (RecoveryFile, no nodes, in user://recovery): main.gd writes a copy of the edited
  schematic and the file it came from after every edit (_mark_dirty; written to a .tmp first),
  removed when it is saved, replaced (new, open) and on quit. Each run of the program is
  a session with a copy of its own and an alive mark rewritten every RecoveryFile.BEAT seconds;
  at start, copies of sessions not marked alive for STALE seconds (crashed, killed or still
  frozen) are offered, the newest first: Restore (opened unsaved, Save writes to its file),
  Discard, Later (offered again at the next start)
- File association (FileAssociation): an exported Windows build registers .ladder for the current
  user (HKCU via `reg import`, redone only when the exe moved) unless File > Open .ladder files
  with LadderLab is turned off (setting files/associate; turning it off deletes the keys); a
  .ladder path among the command-line arguments is opened at start
- PRIVACY.md and CODE_SIGNING.md (signing policy for SignPath) describe every network request
  and system change the program makes: keep them true when adding one
- Version: `application/config/version` in project.godot (semantic, e.g. 0.2.0); releases are
  GitHub Releases tagged `v<version>`. Updates (Help menu): UpdateChecker asks the GitHub API for
  the latest release at start (Help > Check for updates at startup, saved) and on request;
  ReleaseCheck (no nodes) compares versions and reads the answer; a newer release shows a
  toolbar button opening its page (no self-update). AboutDialog: version, GPL notice, the
  LICENSE file (exported through include_filter) and Godot's third-party licenses
- Translations: English source text in tr()/tr_n(); regenerate `translations/ladder_lab.pot`
  when UI text changes and update `cs.po` (keep reviewed translations)
- `translations/` gettext: English source text in tr(), `ladder_lab.pot` template, `cs.po` Czech
- `test/unit/` GUT tests; example_power.gd switches on the breakers of a built-in example
  (they start switched off like every breaker)

## Versioning

- The version in `application/config/version` (project.godot) is raised only when releasing,
  once per release, not per merge: merges into main keep it and only add their changes to
  CHANGELOG.md under "Unreleased". Builds of main between two releases carry the version of
  the last release.
- MAJOR.MINOR.PATCH, raised by the biggest change since the last release (one step, however
  many merges it took):
  - PATCH (0.3.0 → 0.3.1): only bug fixes, translation fixes, small drawing or layout adjustments
  - MINOR (0.3.1 → 0.4.0, PATCH back to 0): any new feature, part, example, menu item or setting
  - MAJOR stays 0 during development; 1.0.0 is the first stable release. After it, MAJOR rises
    when something is removed or older versions can no longer open the new schematics
- The number only goes up from the last release and a released number is never reused.
  (Versions 0.3.0-0.9.0 were once raised on main per merge but never released; numbering
  went on from the last release, 0.2.2, so 0.3.0 is the release after it.)
- A release is tagged `v<version>` exactly as in project.godot (the update check compares the
  tag). Pre-releases use a suffix (`0.4.0-beta1`), are published as GitHub pre-releases and
  are older than `0.4.0`.
- The program version is independent of ProjectFile.VERSION (the .ladder file format number).
- CHANGELOG.md: every merge that changes the program adds its changes under "Unreleased", as
  short lines a user understands (what they can do now, what works better), in the matching
  group (Schematic editor, Simulation, Panels, Files and export, Application; "Fixed" for bug
  fixes).
- Releasing (.github/workflows/release.yml): on main, raise the version in project.godot (see
  above), "Unreleased" becomes "<version> – <date>" with that version and a new empty
  "Unreleased" above it; commit, push, then push the tag `v<version>` on that commit. The workflow runs the
  tests, exports the Windows build on Linux (Godot GODOT_VERSION, only the Windows template),
  zips LadderLab.exe with LICENSE.txt as LadderLab-<version>-win64.zip and publishes the
  release with that changelog section as its text (the update dialog shows it); it refuses a
  tag that differs from the version or a version without a changelog section. Instead of
  pushing the tag: Actions > Release > Run workflow on main with "Publish" ticked creates the
  tag itself (refused when that version is already released). Run by hand without "Publish"
  it only builds the zip. Raise GODOT_VERSION there when
  the project moves to a newer Godot.
