# Changelog

What changed in each LadderLab version. Version numbers follow the rules in
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md#versioning); downloads are on the
[Releases](https://github.com/JarasonPC/ladder-lab/releases) page.

## Unreleased

### Simulation
- 3~ motors have a load setting (% of the rated torque) and show their torque in N·m while
  simulating

### Panels
- PLC ladder diagram: the chosen contact or coil is shown faintly where a click puts it
- PLC ladder diagram: wires are drawn as in the schematic: click where the wire starts, click
  for corners, and it ends on the rail, an element or another wire (or with a double click)
- Workspace cables get a type by their use: CGSG-J to motors and limit switches, JYTY-O to
  control stations, shielded LiYCY to sensors, CYKY-J between switchboards (View > Cable types:
  Czech, or the European H07RN-F, H05VV5-F, H05VVC4V5-K, NYY-J)
- A cable opened on the workspace can be given a type name of your own, a cross-section and its
  length; it then shows its voltage drop (marked above 4 %), and the length is written on the
  workspace and in the parts list

### Fixed
- Zooming, moving and simulating in a switchboard is smooth: only what changed is drawn again
- A motor of small rated slip (e.g. 2970 min⁻¹) starts with a real motor's torque: started in star
  it no longer stays at standstill drawing its starting current
- A field cable's core leaves the switchboard from the strip terminal on the part's own lead
  (e.g. a button's), not from another terminal of its net such as one under a breaker
- Saving a schematic no longer fails in folders an antivirus watches closely, such as Downloads
  on Windows

## 0.4.3 – 2026-10-19

### Fixed
- After a while the program could stop taking clicks and could not be closed (only a beep on
  every click): dialogs and menus now open inside the program's window, so none can be left
  open where it cannot be seen
- Changing what the PDF holds or the wire numbers in the export preview no longer turns the
  schematic white or puts dark sheets in the PDF; the preview can only be saved once it shows the
  sheets as they are now
- The Switchboards tick in the PDF export is greyed out while every switchboard is empty
- An exported PNG gives its page number in the schematic in the title block; the PDF creation date
  carries the time zone
- Long entries of the exported parts list get smaller, and end with "…" where they still do not
  fit; a long control station title no longer runs into the next station on the exported sheet
- Datasheets: a compact PLC of any CPU size gets the compact PLC's datasheet, long diagram
  headings of the time relay stay on the page, a heading of the terminal table never ends a page
  alone, a contactor lists its main contacts, and every terminal label on the device front is
  readable, also on a PLC with many modules
- The examples' lamp purposes and station button labels are in Czech in the Czech program
- Numbering the wires no longer joins two circuits through page connectors
- Splitting a terminal strip no longer gives two terminals the same number; moved terminals keep
  their order
- Deleting a branch no longer loses the wire number of the wire left
- Changing a part's type no longer passes its key or its place on a control station to a part that
  cannot take them, and within one part (fuse to fuse holder, another motor or PLC, contact NO to
  NC) it keeps its settings, such as the rated current or an unticked delay
- A coil turned into a time relay (or back) keeps swapped A1/A2 and times set by hand, and its
  contacts become delayed (or plain) contacts
- Editing poles, the control input S, the CPU or modules is no longer refused after a terminal was
  renamed; the names given by hand stay. After a refused edit the properties show the part as it
  stayed
- Editing a part's properties no longer re-routes its wires
- Renaming a coil takes all its contacts along, giving one with the same numbers the next free
  number; changeover and main contacts can no longer take the name of an overload relay
- A deleted part no longer leaves its key, group or mechanical link to the next part given its
  name; renaming a part to another block of an existing device no longer lists it twice in a group
  or overwrites its stop and its key
- Turning or mirroring a selection that holds an overload relay without poles works again
- A terminal from the palette takes a number no strip terminal on a lead uses, and pasted strip
  terminals get free numbers instead of sharing terminals with the originals
- A second wire between the same two terminals is no longer drawn, and pasting no longer leaves
  junctions without wires
- The temperature sensor's range bounds can no longer cross each other (one bound past the other
  no longer resets the range to 0–100 °C); the inverter's fixed and keypad frequencies can no
  longer be set above its maximum frequency, and lowering the maximum no longer cuts them for good
- PLC versions that do not fit the expansion modules can no longer be chosen
- A wire cancelled on its start terminal no longer clears Redo
- A designation or other marking being typed when Simulate is clicked is kept in the schematic, no
  longer applied to the simulation
- Editing a PLC program in its window no longer selects the PLC (Delete then removed it)
- Confirming an unchanged lamp purpose or label, binding the same key, or dragging a part back to
  its place no longer counts as a change; View menu toggles no longer end placing or wiring
- Undo and Redo keep the check results open and check again
- Check: no false "not connected" on compact PLC digital modules; supplies are checked per source
  (a load between L2 and L3 passes, L with DC − does not); hints for a time relay function that
  needs the control input S while it is off, open compact PLC commons (1M, 3L+, 3M) while inputs
  or outputs using them are wired, and analog modules on the AC supply
- Right-click menus no longer grow and shrink with the schematic's zoom: menus, the inverter
  keypad and the temperature slider open at the mouse at every interface size; the key prompt
  follows the interface size
- A short circuit with no fuse in it now drops out only its own supply (mains or DC); other
  circuits keep working
- A short on a frequency inverter's motor output or 24 V trips the inverter (output off) instead
  of leaving the whole circuit dead
- Instant switching: a buzzing relay no longer stops other relays from switching, a correctly
  interlocked reversing starter no longer blows its fuses, and clearing a stuck-armature fault
  releases the relay at once
- Time relays see the control input S correctly when it changes together with their power (no
  false pulse); a time relay cycling with both times set to zero no longer freezes the simulation,
  and times from a file are held to 0.1–3600 s
- The event log shows a time relay's output switching on or off together with its power (F1 at
  power on, F2 at power off)
- Limit switches part-way along a mechanical link are operated and let go at the right places in
  realistic timing; mechanical links keep moving when a lot happens in one step; a Dahlander motor
  at low speed moves its link at its real, slower speed
- A blown pole of a multi-pole fuse shows its heat like a single fuse
- Currents: a rectifier's output current returns through its own − terminal, and a load between
  two + supplies of different voltages shows its current
- A burnt-out coil can be replaced from the fault menu
- Clicking Simulate while simulating no longer restarts the simulation; Edit, Schematic and
  Workspace do nothing when already shown
- A push button held by its key is let go when the key comes up with Ctrl, Alt or Cmd down, while
  typing, or in the datasheet or PLC window
- The timing chart no longer fails with a compact PLC, and outputs that are not wired get no row
- Follow brings the timing chart back to now while paused too; dragging the chart at the start no
  longer jumps ahead; the time axis no longer shows "-0.0 s"; "Double click: follow" is shown
  beside Follow instead of over the last chart row
- The time span field shows the span zoomed to with the wheel; overload relays are marked Ir in
  the chart
- The event log no longer repeats entries when switching views, scrolls to the newest entry, and
  Reset keeps the events of the first step
- The status bar says "Paused" after Pause, and its warnings are readable in the light theme
- Clamp meter readings and currents on wires are no longer hidden behind symbols
- PLC: a compact CPU with many signal modules sees every input (inputs from I33 on were wrong)
- PLC: on the 12/24 V and 24 V versions, a sensor's volts on I7, I8, I1 or I2 also switch the
  digital input
- PLC ladder: deleting a row no longer joins two rungs; Insert row on a full ladder does nothing
- PLC function block diagram: a feedback loop starts at a block of the loop (counters after a loop
  no longer count wrongly)
- PLC: a very long simulation step of a program that keeps switching no longer runs timers
  backwards; operands like "I+1" are no longer accepted in saved programs; expansion modules
  beyond what the PLC's version takes are left out on loading
- PLC window: operand names and block numbers no longer disappear after an edit or a properties
  change; the test simulation of a new PLC no longer stops at every schematic edit, and it shows
  the selected block's state
- PLC window: edits that change nothing no longer make undo steps; Esc or a right click while
  carrying a connection puts it back; Ctrl+V with the mouse outside the diagram pastes beside the
  copied blocks
- PLC window: times, presets and analog values take their whole range; analog help texts and new
  values follow the compact CPU's 0-27648 scale; the ladder's coils are in view at the default
  size
- PLC window: releasing a bound key there lets the push button go; Space stays for panning and no
  longer pauses the simulation
- Clicking an entry in the workspace tree no longer causes errors; a right click only opens its
  menu; the lamps inside illuminated buttons are listed under their station
- Text typed in a station field just before switching to Simulate no longer changes the
  simulation; workspace, station and switchboard edits are ignored while simulating
- A switchboard or station stays open (also in its own window) when it is renamed or the rename is
  undone
- Many cables leaving one side of a place no longer run diagonally or pile their name tags on each
  other
- An empty group moves with the mouse while dragged; a motor taken out of its group no longer
  shows its mechanical link; a part taken out of a group leaves its link
- A renamed cable between two parts in the field keeps its name when one of them is moved; new
  places no longer land on a group's frame
- Changing an item's kind on a station no longer shows a device twice; a long station title no
  longer runs over the cover screws
- The selection frame in a switchboard sits on the selected device; Ctrl+wheel zooms at the mouse
- An overload relay on a rail of its own is wired on both sides (it sits on a mounting unit with
  terminals 1, 3, 5) and is never drawn twice
- Field cables in the switchboard have as many cores as the workspace cable; a circuit going on to
  another switchboard leaves in the cable between the two
- Cable glands in the switchboard no longer overlap; the switchboard grows wide enough for them
- Wiring two supply points of different conductors together, or naming a main contact 13 or 21, no
  longer breaks the switchboard
- Switchboards draw and wire every auxiliary contact of a contactor: contacts beyond the six on
  the contactor and its front block go on auxiliary contact blocks mounted on its sides; a
  changeover contact on a contactor is wired on both sides
- Relays with more than four contacts and time relays with more than three get a second relay
  beside them
- Wires in the switchboard no longer run over the terminals of contactors, overload relays and
  inverters; terminal names on PLCs, relays and time relays are no longer hidden by their wires
- Fuse holders with several poles number each pole; the rectifier's − output is wired light blue;
  compact PLC module screws no longer touch; a missing device's name is readable
- F1 opens the selected part's datasheet also after the Help menu has been opened
- The example list shows "Example circuits…" again after New, Open or Restore, so the last example
  can be picked again
- A page window keeps showing its page when pages are moved and closes when its page is deleted;
  PLC windows and page window titles follow a change of language
- After restoring unsaved changes, copies from other sessions that did not close properly are
  offered too
- A file with a wrongly typed value opens with defaults instead of being refused as damaged
- Saving writes a temporary file first: a failed save (for example on a full disk) keeps the file
  saved before and reports the error
- At large interface sizes and in small windows, the toolbar, timing panel, event log, side panels
  and status bar fit the window; side panels scroll when they are taller than it
- Sliders and spin boxes match the theme (the slider is visible in the light theme)
- Clicks in the workspace no longer reach the hidden schematic
- Terminal strip labels no longer sit on the terminal marks, terminal numbers or ratings: on motor
  leads, parts lying horizontally, a changeover's NC, a time relay's S, sensors, rectifiers and
  supply points; terminal numbers keep off the marks
- The slash of a strip terminal leans the same way however the part is turned
- Contacts, buttons, breakers, main contacts and fuse holders turned once now pivot on the left;
  the palette shows the changeover contact pivoting on the left
- PLC lights and display, the inverter window and the motor rating plate no longer fade away below
  zoom 1; box outlines are smoother
- A motor's rating plate stays beside the motor when it is turned or mirrored
- A running motor writes its current, speed and state clear of the PE lead; its turning arrow no
  longer covers terminal names
- PLC example: the -KM1 designation no longer touches the PLC
- The 3-pole overload relay's terminal numbers are clear of its housing
- Motor terminal boards: with three windings the terminals and names are outside the board;
  turned, the stud names stay inside the board
- Turned PLCs and inverters fit "PLC RUN", module texts and the frequency into their windows
- A lamp's purpose is written above its designation also when the designation is under the lamp
- The fault mark sits beside the part, off its lines and terminal numbers
- F10–F12 fit the time relay's box
- A closed NO contact's blade lines up with its lead

## 0.4.2 – 2026-10-19

### Schematic editor
- Contactor and relay coils show what they are rated for: a band in the coil box with "~" for
  AC or "⎓" for DC
- The palette tells the parts apart at a glance: the motors are a circle with "M 3~" and
  star/delta, Dahlander or the number of speeds beside it, the PLCs say "PLC relay" and
  "PLC CPU", the frequency inverter "VFD 3~ f", the temperature sensor shows a thermometer
- A new overload relay from the palette has three poles (its heaters in the power circuit)
- The fuse, fuse holder and circuit breaker stand upright in the palette
- Current path numbers are written without a box around them
- The temperature sensor is drawn with its measuring element, a resistor varying with the
  temperature (as a Pt100), inside the transmitter box
- lots of BUG FIXES and tiny features

## 0.4.1 – 2026-10-19

### Files and export
- File > Open .ladder files with LadderLab (Windows): turns the file association on or off;
  turning it off removes it from the registry again

### Fixed
- The PLC, compact PLC and frequency inverter are readable in the palette (drawn smaller there),
  and no palette symbol has lines too thin to see
- The mouse wheel scrolls a datasheet or an opened control station with the pointer over the
  sheet or the station, not only beside it

## 0.4.0 – 2026-10-18

### Schematic editor
- Every part has a datasheet, laid out like a manufacturer's: what it does, every terminal with
  its name and function, technical data, the timing diagram or time-current characteristic,
  and the device front from the switchboard with its terminal markings. Open it with a right
  click on the part (Datasheet), F1 or the Datasheet button in the properties; Help > Part
  datasheets lists every part of the library. Datasheets export as PDF
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
- Frequency inverter (TA1) for a 3~ motor, modelled on the small Siemens drives: supply L1 L2 L3,
  motor on U V W, control terminals DI1-DI4, 24V-0V, 10V and AI1, relay output DO2; maximum
  frequency, ramp times, fixed frequency and where run and the setpoint come from are set in
  its properties
- Wires of moved or turned parts find their way around the other symbols, never over a
  terminal of another circuit or along one of its wires, with few corners and crossings; a part
  dropped on a wire that is not its own moves the wire aside
- Several selected parts turn and mirror together, keeping their places to each other (a
  column of parts turned becomes a row), with the wires between them; four turns bring them
  back exactly where they were

### Simulation
- Keys of the keyboard operate push buttons and switches: right click on one in Edit mode (on
  the schematic, an opened control station or the workspace tree), Bind a key…, and press the
  key. While simulating a held key holds the button, a press flips a switch. The key shows as
  a keycap beside the designation on the schematic (on the side away from the symbol), under
  the label plate on the station and on the station's tile, lit while held; a strip above the timing chart lists every key with what it operates
- Mechanical links: in a group, a motor moves a part such as a gate from one end to the other
  in the time you set, and the part operates the group's limit switches where they are (at the
  ends, or as it passes one in between); the workspace shows the way with the switches on it
  and where the part is while simulating
- Supplies of different voltages: 230 V between a phase and N, 400 V between two phases, and DC
  supplies of 12, 24, 48, 110 or 220 V. Coils, time relays, lamps and PLCs have a rated voltage
  (230 V AC, 24 V DC, …; PLCs in 115-240 V, 24 V and 12/24 V versions): with too low a voltage
  they do not work, with far too high a voltage, or DC on an AC coil, they burn out, until
  replaced from the right-click menu. New parts are rated 230 V; parts of older schematics work
  on any voltage as before
- A bridge rectifier gives 207 V DC, a source of its own: joined to a DC supply it is a short
- The frequency inverter runs its motor at its output frequency along the ramps: DI1 run, DI2
  reverse, DI3 fixed frequency, DI4 coast stop, the setpoint 0-10 V on AI1 (from its 10V, a PLC
  or a sensor) or from its keypad, opened by a click while simulating; the motor turns at the
  speed of the frequency without the starting current of a direct start, DO2 closes while it
  runs, and the timing chart shows the frequency
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
- The frequency inverter in the switchboard, dark as the real ones, with its display showing
  the frequency, its keys and its terminals
- The switchboard prints each breaker's characteristic and rating (B2, C16, …)
- Terminals can be moved along their terminal strip in the switchboard
- The incoming supply lands on the supply's strip terminals
- The workspace (Schematic | Workspace in the toolbar) takes the place of the control panel
  and switchboard sidebars: as many switchboards (+RA1, +RA2, …) and control stations (+ST1,
  +ST2, …) as you like, placed and dragged around on schematic paper, with the motors, limit
  switches and temperature sensors of the schematic standing in the field beside them
- A click on a switchboard or control station opens it in place of the workspace, with the
  tree of everything kept beside it as the map; a right click opens it in a window of its own,
  e.g. on a second monitor, renames it or deletes it
- Groups (+G1) keep parts in the field that belong together, e.g. a gate with its motor and
  limit switches: drag a part into a group's frame to put it in, drag the frame to move them all
- The tree beside the workspace lists every switchboard with its devices and terminal strips,
  every station with its buttons and lamps, the groups and what has no place yet; a search
  field finds a device, a click opens its switchboard or station with it selected
- Schematics saved before keep their switchboard as +RA1 and each control box as a station
- Cables between the switchboards, control stations and parts in the field are worked out from
  the wiring and drawn on the workspace as tracks (right angles with rounded corners, each
  cable from a point of its own, power cables thicker) with their name and type; a stop button
  wired straight on to the next station's gets a cable from station to station
- Cables are typed like real ones: CGSG-J 4x2,5 (J with a PE core, O without), or, chosen in
  View > Cable types, harmonised H07RN-F 4G2,5. Control cables are 1.5 mm², a cable to a motor
  is sized for its rated current, other power cables for all the motors together
- A click on a cable lists its cores: what each core lands on at both ends (strip terminal or
  device terminal) and its wire number; cables keep their names and can be renamed
- The switchboard sends one field cable out to each control station and part in the field,
  named like the cable on the workspace

### Files and export
- The PDF export holds, as ticked in its preview, the schematic, the control stations, every
  switchboard, the workspace and a parts list: every device under the switchboard, station or
  group it sits in with its ratings, the terminal strips, the parts in the field, what has no
  place yet, and the cables with their type and ends. The preview shows all of it, page by
  page, and the choice is remembered (File > Export as PDF…)
- Unsaved work is no longer lost when LadderLab crashes, freezes or is killed: a copy is kept
  after every edit, and the next start offers to restore it (also while the frozen window is
  still open); several LadderLab windows each keep their own copy

### Application
- A tidier start: an empty page and the parts library only. The properties appear while
  something is selected; at the first start the timing chart and event log are rolled in
  while simulating

### Fixed
- A wire without its corners (from a file edited by hand or made by another program) froze the
  program; it now runs across and down
- Turning or mirroring parts while dragging them could freeze the program
- A straight wire whose end was moved off its line took a hook back over itself

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
