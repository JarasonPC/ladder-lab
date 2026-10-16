# Changelog

What changed in each LadderLab version. Version numbers follow the rules in
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md#versioning); downloads are on the
[Releases](https://github.com/JarasonPC/ladder-lab/releases) page.

## Unreleased

## 0.2.2 – 2026-10-16

### Fixed
- The About window opened taller than the screen, so it could not be closed
- Release notes in the update dialog are shown as plain text, without formatting marks
- A click on a part no longer nudges it a cell; parts move only when really dragged and stop
  following the mouse when the button is let go outside the window
- Wires of a dragged part no longer pick up hooks and loops, keep off the terminals of other
  parts, and are back as they were when the part is dragged back
- A new wire clicked onto a wire it is already connected to adds a corner there instead of an
  extra junction
- No branch dot where wires that are not connected only meet

## 0.2.0 – 2026-10-16

First public version.

### Schematic editor
- IEC 60617 symbols in Czech practice: supplies L1, L2, L3, N, PE and DC + / −; push buttons,
  switches and limit switches; NO, NC, changeover and delayed contacts; contactors (KM),
  auxiliary relays (KA) and multifunction time relays (KT, functions F1–F12, control input S);
  lamps; fuses and fuse holders; circuit breakers; overload relays with a test button;
  three-phase motors with terminal box, star/delta and Dahlander windings; bridge rectifiers;
  terminals and terminal strips
- Vertical or horizontal current paths, rotating and mirroring, undo and redo
- Designations, terminal numbers and labels edited by double-click and moved by dragging
- Wire numbering
- Multi-page schematics with page connectors; a page can be opened in its own window
- Check for unconnected terminals, contacts without a coil and other mistakes

### Simulation
- Realistic switching (pick-up and drop-out times, NC contacts break before NO contacts make)
  or ideal, instant switching
- Run, pause (Space), step and slow motion; timing chart and event log
- Short circuits and overloads trip fuses, circuit breakers and overload relays
- Three-phase motors run up and coast down; DC braking
- Wires coloured by where the voltage reaches

### Panels
- Control panel: control boxes with push buttons, selector switches, signal lamps and
  illuminated buttons that operate the simulation
- Switchboard: DIN rails with the breakers, fuses, contactors, relays and terminals
- Switchboard: bridge rectifiers (TB) on the rails, their DC LED lit while the input has voltage

### Files and export
- `.ladder` files, recent files; on Windows a double-click in Explorer opens them
- Export a page as PNG or all pages as PDF on A4 / A3 sheets with a frame and an editable
  title block, shown in a preview first

### Application
- English and Czech
- Dark and light theme, white schematic paper, interface size
- Examples: self-holding start/stop, forward/reverse, star/delta start, time relays,
  self-cutoff, short circuit and three-phase circuits
- Help menu: check for updates (also at start), report a problem, About with the licenses
- Free software under the GNU GPL, version 3 or later
