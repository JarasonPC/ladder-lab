# Project: Relay control circuit simulator

- Engine: Godot 4.7.2, GDScript only (no C#)
- Use static typing everywhere (var x: int, func f() -> void)
- Schematic symbols follow IEC 60617, drawn in code with _draw(), no image assets
- Drawing style follows the course guide (style "A"): white paper, thin black lines, a square at
  every terminal coloured by voltage reach, branch dots in the wire colour, "-KM1" designations
  and terminal numbers in teal, supplies as circles with the name inside, lit lamps filled grey;
  colours live in SchematicTheme, which also has a dark paper (dark theme, unless View > White
  schematic paper); PNG export always uses white paper. Lamps may carry a purpose text drawn above
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
  releases, delay marks, limit-switch triangles) turn with it; button and switch heads stay
  straight on a dashed stem; the overload contact's bimetal step stays straight on a solid stem. Breakers and fuse holders start switched off (open).
- Time relays (TimerRelay) are multifunction relays: functions F1-F12 (TimerRelay.Mode, codes as in
  real relays; F10-F12 use two times t1 = delay, t2 = delay2) plus a true off-delay; optional control input S (terminals A1-A2-S, S renameable,
  active with voltage against A2; A1-A2 never renamed); the properties panel shows a timing diagram
  (TimerDiagram, computed by running TimerRelay itself) and a list of all functions
  (TimerFunctionsPopup). The palette has one time relay. Any 3~ motor can be drawn as its
  terminal box (standard motors with star/delta bridges, drawing only)
- One palette part per family: fuse/fuse holder, breaker and main contacts have 1-4 poles, the
  overload relay none or 3 (set in the properties); a contact designated like an overload relay
  becomes its OverloadContact; a contact of a time relay KT is delayed by default (no separate
  delayed contacts in the palette). Markings (designations, terminal names, lamp and terminal labels,
  wire numbers) are edited by double-clicking them on the drawing, not in the properties panel;
  a click highlights a marking, dragging moves it (Placement.labels, saved). Designations: no
  spaces or colons; only parts of one device share one (coil with its contacts, overload relay
  with its contacts, blocks of one button); renaming a coil or overload relay renames its contacts
- Terminals (TerminalBlock, "X1", free label) sit on wires, or on a component's lead
  (Placement.strips: terminal index -> label, drawn instead of the square; Delete on the selected
  mark removes it); wire segments can be dragged; wire
  numbers (WireRoute.number, one per net, shown once per terminal, draggable offsets) via the
  numbering tool or double click; the palette panel is resizable
- Keep the simulation logic (solver) separate from scenes and UI:
  solver classes extend RefCounted and must work without any nodes
- Tests use GUT; run them with: godot --headless -s addons/gut/gut_cmdln.gd
- Don't add features beyond what the current phase asks for

## Conventions (Czech practice: ČSN EN 60617 / 81346 / 60947 / 60445)

- Device designations: KM = contactor, KA = auxiliary (control) relay, KT = time relay, SB = push
  button, RB = rotary switch, SQ = limit switch (LimitSwitch, a LatchingSwitch clicked on/off),
  H = lamp, M = motor, FU = fuse, FA = circuit breaker, F = overload relay, X = terminal, supplies L (= L1), L2, L3 and N
- Terminals are addressed "<designation>:<terminal>", e.g. "K1:A1", "S0:11"; supplies are just "L" / "N"
- Contact terminals: first digit = sequence, second = function
  (1-2 NC, 3-4 NO, 5-6 delayed NC, 7-8 delayed NO); coils A1-A2, lamps X1-X2, motors U1-U2
- Power circuit: multi-pole devices (main contacts, fuses, breakers, overload relay)
  1-2/3-4/5-6/7-8; 3~ motors U1-V1-W1 (+U2-V2-W2 star/delta, drawn W2-U2-V2 under U1-V1-W1 as on
  the terminal board), Dahlander and separate windings
  1U-1V-1W/2U-2V-2W(/3U-3V-3W); phase order L1-L2-L3 on U-V-W = clockwise

## Layout

- `sim/` solver (Circuit, Simulator, StepResult, UnionFind, Armature, TraceRecorder, components/) - no nodes
- Simulator modes: IDEAL (instant, solver default, used by most tests) and REALISTIC (Armature
  pick-up/drop-out times, NC breaks at 30 % before NO makes at 100 %, event-driven steps;
  documents default to realistic)
- `schematic/` drawing data (SchematicDocument, Placement, WireRoute, SymbolGeometry,
  ExampleCircuits) - RefCounted, no nodes; any symbol can be rotated and mirrored left-right (F,
  mirror_component) or top-bottom (Shift+F, flip_component) as seen on the drawing, so
  vertical and horizontal current paths can be mixed
- `ui/` nodes: SchematicView, WireLayer, symbols/ (one _draw() class per symbol), main.gd
- UI look: `ui/app_theme.gd` (AppTheme) builds the whole Godot theme in code from colour tokens
  (dark/light), system fonts (MSDF font for schematic text), line icons as inline SVG via
  DPITexture; use its type variations (ToolButton, PrimaryButton, MutedLabel, ...) instead of
  per-control colours. No stretch scaling: the window uses content_scale_factor (View > Interface size)
- `ui/timing/` TimingChart, EventLog, TimingPanel (Simulate mode, bottom)
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
- Translations: English source text in tr()/tr_n(); regenerate `translations/ladder_lab.pot`
  when UI text changes and update `cs.po` (keep reviewed translations)
- Merge the working branch into main after each finished phase
- `translations/` gettext: English source text in tr(), `ladder_lab.pot` template, `cs.po` Czech
- `test/unit/` GUT tests; headless Godot is not preinstalled in cloud sessions
