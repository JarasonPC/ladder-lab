# LadderLab

A free simulator of relay control circuits for learning and teaching electrical
control. Draw a schematic with IEC 60617 symbols, switch to simulation and operate
the push buttons and switches: contactors pick up, contacts change over, lamps light
up, motors start, and the wires show where the voltage reaches.

The application is in English and Czech, and follows Czech practice
(ČSN EN 60617 / 81346 / 60947 / 60445): designations such as -KM1, -KA1, -KT1, -SB1,
contact numbering 13-14 / 21-22, coils A1-A2.

![A star/delta start simulated: the schematic with the wires coloured by voltage, the timing chart and the event log](docs/screenshots/schematic.png)

## Features

- **Schematic editor**: supplies (L1 L2 L3 N PE, DC + and -), push buttons, switches,
  limit switches, NO / NC / changeover contacts, contactors and relays, multifunction
  time relays (F1-F12), lamps, fuses and fuse holders, circuit breakers, overload relays,
  three-phase motors (including star/delta and Dahlander), bridge rectifiers, terminals and a
  small PLC (logic module with 8 inputs and 4 relay outputs).
  Undo / redo, rotating and mirroring, wire numbering, multi-page schematics with page
  connectors.
- **Simulation**: ideal (instant) or realistic switching with pick-up and drop-out times,
  a timing chart and event log, short circuits and overloads that trip the protection,
  DC braking of motors.
- **PLC programming**: the PLC's program in a window of its own, as a function block
  diagram (FBD: AND, OR, NOT, NAND, NOR, XOR, on- and off-delays, latching and pulse relays,
  up/down counter) or a ladder diagram (LAD: one endless power rail, NO/NC and edge contacts,
  coils, negated coils, set/reset, timer and counter coils), in the style of Siemens programming
  software; a built-in simulation with input switches and output lamps tests the program on its
  own, and while the schematic is simulated it shows the running program (signals, power flow,
  times and counts).
- **Control panel**: control boxes with push buttons, selector switches and signal lamps
  that operate the simulated circuit.
- **Switchboard** (rozvaděč): DIN rails with the breakers, fuse holders, contactors,
  overload relays, relays, time relays, PLCs and terminal strips of the schematic, drawn like
  the real cabinet; they show the simulation and breakers and fuses are switched there.
- **Export**: pages as PNG or all pages as PDF on A4 / A3 sheets with a frame and title block.
- **Examples**: self-holding start/stop, forward/reverse, star/delta start, time relays
  and more.

## Screenshots

| Switchboard | Control station | PLC program |
| --- | --- | --- |
| [![The switchboard of the star/delta start while simulating](docs/screenshots/switchboard.png)](docs/screenshots/switchboard.png) | [![A control station with illuminated push buttons, the forward lamp lit](docs/screenshots/station.png)](docs/screenshots/station.png) | [![The PLC window with a ladder diagram running](docs/screenshots/plc.png)](docs/screenshots/plc.png) |
| DIN rails, breakers, contactors and terminal strips drawn like the real cabinet, wired after the schematic | Push buttons and signal lamps that operate the simulated circuit | A ladder diagram running in the simulation, power flow shown live |

## Download

Get the latest version from the [Releases](https://github.com/JarasonPC/ladder-lab/releases)
page: unzip it and run `LadderLab.exe` (Windows, 64-bit). Schematics are saved as
`.ladder` files.
The program is not signed yet, so Windows may show "Windows protected your PC" the first
time: click **More info** and then **Run anyway**.

What changed in each version is in the [changelog](CHANGELOG.md). LadderLab tells you when
a new version is out (Help > Check for updates).

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

## Code signing, privacy and security

- [Code signing policy](CODE_SIGNING.md): how the Windows builds are made and signed, and
  what LadderLab changes on your computer
- [Privacy policy](PRIVACY.md): LadderLab collects no data; its only automatic network
  request is the update check, which can be turned off
- [Security](SECURITY.md): how to report a security problem privately

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
