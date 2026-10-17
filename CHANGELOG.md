# Changelog

What changed in each LadderLab version. Version numbers follow the rules in
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md#versioning); downloads are on the
[Releases](https://github.com/JarasonPC/ladder-lab/releases) page.

## Unreleased

### Schematic editor
- Every example has a power circuit with a motor and its control circuit, protected by circuit
  breakers (C16 for the motor, B2 for the control circuit), with everything outside the
  switchboard wired through terminal strips: the supply on X1, buttons and lamps on X2, motors
  with their PE on X3
- Supply points can have a strip terminal on their lead
- Right click on a terminal of a part adds or removes its strip terminal
- Strip terminals of other strips than X1 show the strip above their number, so neighbouring
  terminals stay readable
- A breaker's rated current is chosen from the ratings sold: 2, 4, 6, 10, 13, 16, 20, 25, 32,
  40, 50 and 63 A
- The breaker characteristics read as multiples of In (B: magnetic release 3-5x In)
- The PLC takes expansion modules, as the real logic modules do: 4 inputs and 4 relay outputs
  or 8 inputs and 8 relay outputs each, up to 24 inputs and 20 outputs in all. They are added
  and taken off in the PLC's properties and drawn beside it, each with its own L1-N supply
- The rated voltage of coils, time relays, lamps and PLCs and the voltage of DC supplies are set
  in the properties and written on the drawing
- Temperature sensor (0-10 V transmitter, BT1) in the parts library, with its measuring range
- Analog modules for the PLC: 2 analog inputs or 2 analog outputs 0-10 V each, up to 8 of
  each; the 12/24 V and 24 V PLCs read I7, I8, I1 and I2 also as analog inputs AI1-AI4
- PLC programs with analog signals: analog inputs and outputs, analog threshold trigger,
  comparator and amplifier in the function block diagram, comparing contacts and an analog
  output coil in the ladder diagram
- Compact PLC (CPU 24 V DC with transistor outputs, modelled on the small Siemens controllers) in
  three sizes: 6 inputs / 4 outputs, 8 / 6 and 14 / 10, each with 2 analog inputs; signal
  modules (8 inputs, 8 outputs, 8 + 8, 4 analog inputs, 2 analog outputs) as many as the CPU
  takes. Its program writes the addresses as the CPU does: %I0.0, %Q0.0, %IW64, %M0.0

### Simulation
- Supplies of different voltages: 230 V between a phase and N, 400 V between two phases, and DC
  supplies of 12, 24, 48, 110 or 220 V. Coils, time relays, lamps and PLCs have a rated voltage
  (230 V AC, 24 V DC, …; PLCs in 115-240 V, 24 V and 12/24 V versions): with too low a voltage
  they do not work, with far too high a voltage, or DC on an AC coil, they burn out, until
  replaced from the right-click menu. New parts are rated 230 V; parts of older schematics work
  on any voltage as before
- A bridge rectifier gives 207 V DC, a source of its own: joined to a DC supply it is a short
- The compact CPU: inputs on with 24 V against their common 1M, transistor outputs switching
  their supply 3L+, analog inputs 0-10 V as 0-27648; changing its size keeps the wires on
  their terminals
- Analog signals: the temperature sensor puts 0-10 V on its output over its range, the PLC
  reads it on its analog inputs and puts its analog outputs out as 0-10 V; while simulating, a
  click on the sensor sets the temperature. The PLC window tests analog inputs and outputs too
- Expansion modules work while their own supply has voltage; their inputs (I9…) and outputs
  (Q5…) are used in the program like those of the PLC, and the PLC window tests them too
- A tripped circuit breaker or overload relay stays hot and cools down slowly; switched on or
  reset too soon, it trips again sooner

### Panels
- The switchboard shows the PLC's expansion modules clipped on beside it, wired like the rest
- The compact CPU and its signal modules in the switchboard, their terminal blocks open, with
  the status, input and output lights and the network port
- The switchboard prints each breaker's characteristic and rating (B2, C16, …)
- Terminals can be moved along their terminal strip in the switchboard
- The incoming supply lands on the supply's strip terminals
- The control panel and the switchboard open in a window of their own (the window button at
  the right of their title), e.g. on a second monitor; closing the window puts them back beside
  the schematic

### Files and export
- Unsaved work is no longer lost when LadderLab crashes, freezes or is killed: a copy is kept
  after every edit, and the next start offers to restore it (also while the frozen window is
  still open); several LadderLab windows each keep their own copy

### Application
- A tidier start: an empty page and the parts library only. The properties appear while
  something is selected; at the first start the control panel is off and the timing chart and
  event log are rolled in while simulating

### Fixed
- Turning or mirroring parts while dragging them could freeze the program

## 0.3.0 – 2026-10-17

### Simulation
- The PLC runs its program in the simulation; clicked while simulating, its window shows the
  running program: signals that are 1, the power flow through the ladder, running times and
  counts. Its outputs are in the timing chart and the event log
- Real currents: every load draws current and the simulation shows how much flows in every
  wire, contact, fuse and breaker; parallel contacts share it
- Three-phase motors behave like induction motors: a large starting current (Ia/In) until they
  are up to speed, a third of it when started in star, the winding current In/√3 in delta, more
  current when a phase is lost or the motor is overloaded, a reversed winding in delta makes
  the motor pull both ways and draw a lot; plugging (reversing at speed) draws even more than a
  start
- Fuses (gG), circuit breakers with characteristic B, C or D and overload relays (class 10)
  trip after the time their characteristic gives for the current through them; the magnetic
  release of a breaker trips at once (a B breaker on a motor start, for example)
- Voltage view or current view: the current view colours only what carries current, with the
  current written on each wire
- Clamp meter: click a wire to read the current in it
- The timing chart shows the currents of motors and protective devices over time

### Schematic editor
- PLC window: the diagrams pan with the middle or right mouse button (or Space and drag), the
  wheel scrolls and Ctrl+wheel zooms at the mouse
- Function block diagram: select several blocks with a frame, move them together, copy, cut and
  paste them (Ctrl+C, Ctrl+X, Ctrl+V) with the connections between them
- Ladder diagram as in LOGO!Soft Comfort: one power rail down the whole diagram, no networks to
  add; rows joined by branches make a rung, numbered on the left; rising and falling edge
  contacts (P, N), negated coils, inserting and deleting rows
- PLC simulation in the program window: switch the inputs I1-I8 and watch the outputs Q1-Q4,
  timers and counters, without simulating the schematic; signals that are 1 are red, 0 blue
- A PLC (logic module) in the parts palette: supply L1-N, eight inputs I1-I8 (on with voltage
  against N) and four relay outputs Q1-Q4, each a contact between its two terminals
- Program the PLC in a window of its own (double-click the PLC or "Program the PLC…"): as a
  function block diagram with inputs, outputs, flags, AND, OR, NOT, NAND, NOR, XOR,
  on-delay, off-delay, latching relay, pulse relay and up/down counter, or as a ladder
  diagram with NO and NC contacts, branches, coils, set and reset coils, on- and off-delay
  timers and counters
- New example: PLC start/stop with an on-delay
- Rated current of fuses and breakers, characteristic B/C/D of breakers and current setting of
  overload relays, with their time-current characteristic in the properties
- Motor rating plate: power, rated current, speed, cos φ, starting current and run-up time;
  it can be drawn beside the motor with the voltages for Y/Δ, the currents and the efficiency
- Breakers, fuses and overload relays show their rating on the drawing (C16, 16 A, Ir 8 A)
- The current path numbers can be turned off (View > Current path numbers), also for export
- The parts palette can show a grid of symbols without names (the name shows on hover)

### Panels
- The PLC sits in the switchboard: a four-module device in Siemens grey with its supply and
  input terminals on top, its output relays below, wired like the other devices; while
  simulating its white backlit display shows the inputs and outputs that are on
- Terminals of the switchboard's terminal strips send their wires out to the buttons, lamps and
  motors outside: from the bottom of each terminal through the bottom wire duct to a cable
  gland in the bottom of the enclosure, one cable per device with its name on the gland
- The supply comes into the switchboard from outside: a cable through a gland in the top of the
  enclosure with a core for each supply conductor, led to the first terminal it feeds
- Terminal strips can be split: pick terminals in the switchboard sidebar and move them to
  another strip or a new one
- Terminals on a PE wire are green-yellow, terminals on an N wire blue
- Wires next to each other go into the wire duct through one slot
- The switchboard drawing zooms (buttons, Ctrl+wheel over it) and moves by right or middle drag
- The control panel and the switchboard roll in to a narrow tab by a click on their title
- The switchboard shows its wiring: every connection of the schematic between its devices and
  terminal strips is a wire led through the wire ducts, red for the control phase (L), light blue
  for N, grey for the main power circuit and green-yellow for PE; wires from under a contactor
  run down beside its overload relay, not across it

### Fixed
- More than one contact can be given the designation of a relay or contactor (KA1): a contact
  whose numbers are taken gets the next free ones (13-14, 23-24, 33-34)
- Terminals of terminal strips in the switchboard show the voltage that reaches them while
  simulating

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
