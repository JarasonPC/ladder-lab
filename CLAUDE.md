# Project: Relay control circuit simulator

- Engine: Godot 4.7.2, GDScript only (no C#)
- Use static typing everywhere (var x: int, func f() -> void)
- Schematic symbols follow IEC 60617, drawn in code with _draw(), no image assets
- Keep the simulation logic (solver) separate from scenes and UI:
  solver classes extend RefCounted and must work without any nodes
- Tests use GUT; run them with: godot --headless -s addons/gut/gut_cmdln.gd
- Don't add features beyond what the current phase asks for

## Conventions (Czech practice: ČSN EN 60617 / 81346 / 60947 / 60445)

- Device designations: K = relay/contactor, KT = time relay, S = push button/switch,
  H = lamp, M = motor, F = fuse/overload relay, Q = motor breaker, supplies L (= L1), L2, L3 and N
- Terminals are addressed "<designation>:<terminal>", e.g. "K1:A1", "S0:11"; supplies are just "L" / "N"
- Contact terminals: first digit = sequence, second = function
  (1-2 NC, 3-4 NO, 5-6 delayed NC, 7-8 delayed NO); coils A1-A2, lamps X1-X2, motors U1-U2
- Power circuit: three-pole devices (main contacts, fuses, motor breaker, overload relay)
  1-2/3-4/5-6; 3~ motors U1-V1-W1 (+U2-V2-W2 star/delta), Dahlander and separate windings
  1U-1V-1W/2U-2V-2W(/3U-3V-3W); phase order L1-L2-L3 on U-V-W = clockwise

## Layout

- `sim/` solver (Circuit, Simulator, StepResult, UnionFind, Armature, TraceRecorder, components/) - no nodes
- Simulator modes: IDEAL (instant, solver default, used by most tests) and REALISTIC (Armature
  pick-up/drop-out times, NC breaks at 30 % before NO makes at 100 %, event-driven steps;
  documents default to realistic)
- `schematic/` drawing data (SchematicDocument, Placement, WireRoute, SymbolGeometry,
  ExampleCircuits) - RefCounted, no nodes; any symbol can be rotated/mirrored, so
  vertical and horizontal current paths can be mixed
- `ui/` nodes: SchematicView, WireLayer, symbols/ (one _draw() class per symbol), main.gd
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
