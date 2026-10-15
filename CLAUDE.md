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
  H = lamp, M = motor, supplies L and N
- Terminals are addressed "<designation>:<terminal>", e.g. "K1:A1", "S0:11"; supplies are just "L" / "N"
- Contact terminals: first digit = sequence, second = function
  (1-2 NC, 3-4 NO, 5-6 delayed NC, 7-8 delayed NO); coils A1-A2, lamps X1-X2, motors U1-U2

## Layout

- `sim/` solver (Circuit, Simulator, StepResult, UnionFind, components/) - no nodes
- `schematic/` drawing data (SchematicDocument, Placement, WireRoute, SymbolGeometry,
  ExampleCircuits) - RefCounted, no nodes; any symbol can be rotated/mirrored, so
  vertical and horizontal current paths can be mixed
- `ui/` nodes: SchematicView, WireLayer, symbols/ (one _draw() class per symbol), main.gd
- `translations/` gettext: English source text in tr(), `ladder_lab.pot` template, `cs.po` Czech
- `test/unit/` GUT tests; headless Godot is not preinstalled in cloud sessions
