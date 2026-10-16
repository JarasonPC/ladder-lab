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
  colour, except coils.
  Symbols draw shapes through SchematicSymbol.aa_* helpers (antialiased with a one-pixel edge at
  any zoom; the view redraws them when the zoom changes); lying horizontally, switching symbols
  are drawn mirrored along their axis so the blade pivots on the left. Every moving part (blades,
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
  overload relay none or 3 (set in the properties); a contact designated like an overload relay
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
- Terminals (TerminalBlock, "X1", free label) sit on wires, or on a component's lead
  (Placement.strips: terminal index -> label, drawn instead of the square; Delete on the selected
  mark removes it); wire segments can be dragged; wire
  numbers (WireRoute.number, one per net, shown once per terminal right next to its square,
  a short wire once at its upper/left end, draggable offsets) via the
  numbering tool or double click; side panels (palette, properties + check, control panel) are
  SideBars: resizable by a grip, zoomed with Ctrl+wheel (ZoomBox: scaled with oversampling_with_scale,
  so text stays sharp); the timing panel is resized by its top edge and the grip before the
  event log, its chart and event log roll in and out by a click on their titles; widths, heights and zooms are saved in the settings
- Pages: a schematic has one or more pages (SchematicDocument.pages: titles, English source text
  shown through tr(), e.g. "Power section" = Silová část; Placement.page; SchematicDocument.page
  = the page shown). Drawing queries (bounds, component_at, terminal_at, wire_at, current_paths,
  junction_cells, wire_number_ends) look at the current page; new parts go on it; a wire joins
  terminals of one page. Page tabs above the drawing (add from presets, double-click renames,
  drag reorders, right click: move/delete, open in a new window; page edits undoable via SchematicEditor.edit_pages).
  A page window (PageWindow) holds a SchematicView with its own page (SchematicView.page) that
  follows the main view (SchematicView.follow: same document and simulation, steps and events go
  through the main view; it rebuilds when the main view does); shortcuts pressed there are handled
  by main.gd. Space runs/pauses the simulation
- Page connectors (PageConnector, internal designation "PC1", drawn as a tag: point on the wire, flat
  end away from it; label in the wire-number colour, cross reference "/page.path" below): all connectors
  with the same label are joined (Circuit.get_links, used by the solver and by wire_net); numbering
  runs over the pages and connectors take their net's wire number as label; right click (Edit) or
  click (Simulate) jumps to the partner page
- Export: File > Export page as PNG / Export all pages as PDF first show the sheets in a preview
  (ExportPreview: page by page, paper and scale, wire numbers on/off, on by default); saving
  writes what the preview shows. Each page on an A4/A3 sheet
  (SheetLayout: 5 mm per cell, scaled down only when needed) with frame and title block
  (SheetFrame), rendered by SheetRenderer at 200 dpi, fitted to everything drawn (it draws each
  page once to measure: SchematicView.drawn_extent, with texts, wire and path numbers); PdfWriter writes one Flate image per page;
  title block texts (company, project, drawing no., revision, drawn by, checked by, date; empty
  date = export date) are SchematicDocument.title_block (TitleBlock, saved), edited in
  File > Title block… together with the schematic title (undoable)
- Control panel (sidebar, both modes, toolbar toggle): control boxes (SchematicDocument.control_boxes,
  ControlBox / ControlBoxItem, saved) drawn like real ones (grey housing, black label plates,
  coloured push buttons, 0/I selector switches, signal lamps, illuminated buttons and switches with a lamp inside, its designation on the plate too);
  items name devices by designation (buttons, switches without limit switches, lamps) and follow
  renames; edited in the sidebar in Edit mode (undoable), operate the simulation in Simulate mode
- Switchboard (rozvaděč, sidebar, both modes, toolbar toggle): DIN rails (SchematicDocument.cabinet_rails,
  CabinetRail / CabinetItem: a device by designation or a terminal strip by name, saved as "cabinet")
  drawn by CabinetView / CabinetLayout / CabinetParts in millimetres (CabinetPainter), real sizes, after
  photos of real devices but never with maker names or type designations; approved look: white plate,
  slotted TS35 rails, open slotted ducts, white labels, push-in terminals, orange glow on energized
  coils, voltage colours on terminals while simulating. The look follows the circuit (CabinetDevices):
  breakers and fuse holders 1-4 poles, contactors 3 (also for 1-2) or 4 main poles plus a front
  auxiliary block beyond two auxiliary contacts, the overload relay fitted under the contactor its
  heaters follow, relays one changeover contact per contact used (1: 6.2 mm module, 2: slim socket,
  3-4: wide socket), time relays 1-3 changeover contacts; terminal strips from terminal labels
  ("X2:4" = strip X2, plain "4" = strip X1). Edited in the sidebar (undoable, "Fill from the
  schematic"), breakers, fuse holders and overload relays operated there while simulating.
  tools/screenshot_cabinet.gd screenshots the app (xvfb) for visual review
- Keep the simulation logic (solver) separate from scenes and UI:
  solver classes extend RefCounted and must work without any nodes
- Tests use GUT; run them with: godot --headless -s addons/gut/gut_cmdln.gd

## Conventions (Czech practice: ČSN EN 60617 / 81346 / 60947 / 60445)

- Device designations: KM = contactor, KA = auxiliary (control) relay, KT = time relay, SB = push
  button, RB = rotary switch, SQ = limit switch (LimitSwitch, a LatchingSwitch clicked on/off),
  H = lamp, M = motor, FU = fuse, FA = circuit breaker, F = overload relay, X = terminal, supplies L (= L1), L2, L3, N
  and PE (bonded to N at the source: N potential in the solver, so a phase on PE is a short;
  wires reached by PE alone are drawn in the PE colour, StepResult.REACH_PE),
  DC supplies + and - (a separate source: loads work between two conductors of the same source;
  AC joined to DC is a short; the - pole is drawn like N), TB = bridge rectifier (Rectifier, a Load
  with terminals ~1 ~2 + -: while its input has voltage its + and - are DC poles, output taken as
  isolated; its input carries current only while its output does)
  (supply points of one conductor are the same potential on every page); next to L2 or L3 a plain "L" supply is renamed
  "L1" ("L.2" -> "L1.2", SchematicDocument.name_first_phase, run after every edit)
- Terminals are addressed "<designation>:<terminal>", e.g. "K1:A1", "S0:11"; supplies are just "L" / "N"
- Contact terminals: first digit = sequence, second = function
  (1-2 NC, 3-4 NO, 5-6 delayed NC, 7-8 delayed NO); coils A1-A2, lamps X1-X2, motors U1-U2
- Power circuit: multi-pole devices (main contacts, fuses, breakers, overload relay)
  1-2/3-4/5-6/7-8; 3~ motors U1-V1-W1 (+U2-V2-W2 star/delta, drawn W2-U2-V2 under U1-V1-W1 as on
  the terminal board), Dahlander and separate windings
  1U-1V-1W/2U-2V-2W(/3U-3V-3W); phase order L1-L2-L3 on U-V-W = clockwise

## Layout

- `sim/` solver (Circuit, Simulator, StepResult, UnionFind, Armature, TraceRecorder, components/) - no nodes
- 3~ motors: + and - across a winding = DC_BRAKING (with a phase = MISWIRED); the shaft
  (ThreePhaseMotor.shaft, simulation state) runs down in coast_time when switched off, in brake_time
  with DC braking; braking force follows the rotor field (rotor_flux, decays with ROTOR_TIME_CONSTANT
  after the AC cut), so DC applied at once brakes best; a star/delta motor running shows a large Y or Δ under "M3~"
- Simulator modes: IDEAL (instant, solver default, used by most tests) and REALISTIC (Armature
  pick-up/drop-out times, NC breaks at 30 % before NO makes at 100 %, event-driven steps;
  documents default to realistic)
- `schematic/` drawing data (SchematicDocument, Placement, WireRoute, SymbolGeometry,
  ExampleCircuits, SheetLayout, PdfWriter) - RefCounted, no nodes; any symbol can be rotated and mirrored left-right (F,
  mirror_component) or top-bottom (Shift+F, flip_component) as seen on the drawing, so
  vertical and horizontal current paths can be mixed
- `ui/` nodes: SchematicView, WireLayer, symbols/ (one _draw() class per symbol), main.gd
- UI look: `ui/app_theme.gd` (AppTheme) builds the whole Godot theme in code from colour tokens
  (dark/light), system fonts (MSDF font for schematic text), line icons as inline SVG via
  DPITexture; use its type variations (ToolButton, PrimaryButton, MutedLabel, ...) instead of
  per-control colours. No stretch scaling: the window uses content_scale_factor (View > Interface size)
- `ui/timing/` TimingChart, EventLog, TimingPanel (Simulate mode, bottom)
- `ui/export/` SheetRenderer (renders pages in SubViewports), SheetFrame (frame, title block),
  ExportPreview (dialog)
- `ui/control_panel/` ControlPanel (sidebar), ControlBoxView (one box drawn with _draw())
- `ui/cabinet/` CabinetPanel (sidebar), CabinetView, CabinetLayout, CabinetParts, CabinetPainter
- `ui/editor/` SchematicEditor (tools, selection, undo), Palette, PropertiesPanel;
  edits go through SchematicDocument methods, which are tested without nodes
- Protection: Fuse/CircuitBreaker (ProtectiveDevice, terminals 1-2) trip when fault current flows
  through them; OverloadRelay (no control terminals) + OverloadContact 95-96/97-98; faults are
  simulation-only state (never saved)
- Buttons/switches with the same designation share one actuator (multi-block devices); ids of
  switching elements are "<designation>:<terminals>"; any component may have custom terminal names
- Wire branches are `Junction` components; simulation runs on a serialized copy of the edited document
- Files: `.ladder` = JSON {format, version, document} via ProjectFile; bump ProjectFile.VERSION on
  format changes and keep older versions loading
- File association (FileAssociation): an exported Windows build registers .ladder for the current
  user (HKCU via `reg import`, redone only when the exe moved); a .ladder path among the
  command-line arguments is opened at start
- Version: `application/config/version` in project.godot (semantic, e.g. 0.2.0); releases are
  GitHub Releases tagged `v<version>`. Updates (Help menu): UpdateChecker asks the GitHub API for
  the latest release at start (Help > Check for updates at startup, saved) and on request;
  ReleaseCheck (no nodes) compares versions and reads the answer; a newer release shows a
  toolbar button opening its page (no self-update). AboutDialog: version, GPL notice, the
  LICENSE file (exported through include_filter) and Godot's third-party licenses
- Translations: English source text in tr()/tr_n(); regenerate `translations/ladder_lab.pot`
  when UI text changes and update `cs.po` (keep reviewed translations)
- `translations/` gettext: English source text in tr(), `ladder_lab.pot` template, `cs.po` Czech
- `test/unit/` GUT tests

## Versioning

- Every merge into main that changes the program raises `application/config/version` in
  project.godot, so no two builds of main share a number. Merges that only touch README, docs/
  or tests (the exported build stays the same) keep the version.
- MAJOR.MINOR.PATCH, raised by the biggest change in the merge:
  - PATCH (0.2.0 → 0.2.1): bug fixes, translation fixes, small drawing or layout adjustments
  - MINOR (0.2.1 → 0.3.0, PATCH back to 0): a new feature, part, example, menu item or setting
  - MAJOR stays 0 during development; 1.0.0 is the first stable release. After it, MAJOR rises
    when something is removed or older versions can no longer open the new schematics
- Raise it once per merge, in the working branch just before merging. If main moved meanwhile
  and already raised it (a conflict on the version line), start from main's version and raise
  that again: the number only ever goes up and is never reused.
- A release is tagged `v<version>` exactly as in project.godot (the update check compares the
  tag); versions between two releases are simply skipped. Pre-releases use a suffix
  (`0.3.0-beta1`), are published as GitHub pre-releases and are older than `0.3.0`.
- The program version is independent of ProjectFile.VERSION (the .ladder file format number).
