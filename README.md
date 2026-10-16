# LadderLab

A free simulator of relay control circuits for learning and teaching electrical
control. Draw a schematic with IEC 60617 symbols, switch to simulation and operate
the push buttons and switches: contactors pick up, contacts change over, lamps light
up, motors start, and the wires show where the voltage reaches.

The application is in English and Czech, and follows Czech practice
(ČSN EN 60617 / 81346 / 60947 / 60445): designations such as -KM1, -KA1, -KT1, -SB1,
contact numbering 13-14 / 21-22, coils A1-A2.

## Features

- **Schematic editor**: supplies (L1 L2 L3 N PE, DC + and -), push buttons, switches,
  limit switches, NO / NC / changeover contacts, contactors and relays, multifunction
  time relays (F1-F12), lamps, fuses and fuse holders, circuit breakers, overload relays,
  three-phase motors (including star/delta and Dahlander), bridge rectifiers and terminals.
  Undo / redo, rotating and mirroring, wire numbering, multi-page schematics with page
  connectors.
- **Simulation**: ideal (instant) or realistic switching with pick-up and drop-out times,
  a timing chart and event log, short circuits and overloads that trip the protection,
  DC braking of motors.
- **Control panel**: control boxes with push buttons, selector switches and signal lamps
  that operate the simulated circuit.
- **Export**: pages as PNG or all pages as PDF on A4 / A3 sheets with a frame and title block.
- **Examples**: self-holding start/stop, forward/reverse, star/delta start, time relays
  and more.

## Download

Get the latest version from the [Releases](https://github.com/JarasonPC/ladder-lab/releases)
page: unzip it and run `LadderLab.exe` (Windows, 64-bit). Schematics are saved as
`.ladder` files.

## Building from source

1. Install [Godot](https://godotengine.org/) 4.7 (standard version, not .NET).
2. Clone this repository and open `project.godot` in Godot.
3. Press F5 to run, or use Project > Export to build the Windows version
   (the export templates are installed from the Export dialog).

Run the tests (GUT) with:

```
godot --headless -s addons/gut/gut_cmdln.gd
```

How the code is organised is described in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Reporting problems

Report bugs and suggest improvements in the
[Issues](https://github.com/JarasonPC/ladder-lab/issues). Attaching the `.ladder` file
helps a lot.

## License

Copyright © 2026 Jaroslav Krnínský

LadderLab is free software: you can redistribute it and/or modify it under the terms of
the GNU General Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version. It is distributed in
the hope that it will be useful, but WITHOUT ANY WARRANTY; see the [LICENSE](LICENSE)
file for details.

LadderLab is made with the [Godot Engine](https://godotengine.org/license) (MIT license).
The tests use [GUT](https://github.com/bitwes/Gut) (MIT license).
