# Changelog

What changed in each LadderLab version. Version numbers follow the rules in
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md#versioning); downloads are on the
[Releases](https://github.com/JarasonPC/ladder-lab/releases) page.

## Unreleased

### Schematic editor
- Dimensions and notes are always on their own layer, "Dimensions and notes", shown or hidden
  in the Layers menu; it cannot be renamed or removed and nothing else goes on it
- More kinds of doors: swinging both ways, sliding along the wall, sliding into the wall
  (pocket), folding and sectional garage doors besides hinged ones (in the door dialog; new
  doors take the kind chosen last). Door widths are set in cm
- Doors are easier to take: by their leaf and swing too. A selected door has a handle at the
  end of its leaf: dragged to another corner it turns the door, its hinges to that end and
  opening to that side
- A corner that rooms share moves for all of them: the end of a wall between two rooms slides
  along the wall it ends on and never opens a gap; with Shift it moves on its own, the wall
  between them slanting. A move that would cross a room over itself is refused. While a corner
  or wall is dragged, every room it moves is shown moved
- Slanting walls can be dragged sideways (the rooms on both sides follow), and the wall dialog's
  length and direction keep the rooms sharing the corner together
- Walls drawn on their own join the walls they meet: mitred where two meet, cut along a room's
  wall they end on; a slanting wall between rooms reaches the wall across it without a notch
- Doors and windows are shown where a click would put them while placing them
- Drawing walls or a room by its corners, a point snapped onto a room's wall shows its
  distances to both ends of that wall
- A switch, socket or other part on a wall can have its symbol dragged off the wall into the
  room by the handle beside it when selected, so that it does not cover the wall; a thin line
  joins it to its place on the wall
- Walls drawn with the wall tool snap onto the rooms' walls, and walls drawn from a room's
  wall across the room to its wall (straight or bent where you click) split it in two; they
  take the place of the separate split tool
- While rooms, walls, doors or windows are drawn, or a room is picked, the floor plan's side
  panel shows the room alone, without the circuit for new parts and the parts still to place
- A new residential installation opens on its floor plan
- The prototype residential schematic is locked in File > New until it is finished
- Circuits are numbered and made on the floor plan: pick a circuit (or a new one) for the
  sockets, luminaires and appliances you put on the plan, before anything protects it; the
  plan writes the circuit's number beside each part. In the consumer unit a breaker, RCBO or
  AFDD put in protects the first circuit waiting for one, and its Circuit field lists the
  waiting circuits to choose another; the panel lists the circuits still waiting. Taking a
  breaker away leaves its circuit's parts on the plan, waiting again
- The main switch QB1 is a part like the others: select it and press Delete (the supply
  then goes straight onto the busbars), or put it back from the palette
- One circuit breaker and one RCD in the consumer unit's palette: poles (1-4; four poles are
  three phases and N), characteristic and rating are set in its properties once placed
- The single-line diagram draws every conductor on its own: the main switch's four poles,
  each pole of a breaker or RCD (joined by a dashed link) with an N pole where the device has
  one, a busbar a phase under a three-phase RCD; the poles come together into one line at
  the circuit's outlet
- Every part a circuit feeds is drawn on its own under its circuit, with its designation,
  and can be selected and edited (no more one symbol with "2×"); they are drawn with the
  floor plan's symbols, as are the palette's tiles, and a luminaire looks alike on a wall or
  the ceiling there
- An outlet for a later connection (vývod), e.g. for a workshop or a summerhouse, on the
  plan and in the consumer unit
- Light switch symbols on the plan and in the palette are turned as in the ČSN legends: their
  lines slant up to the right
- Floor plan walls: each wall can have its own thickness and, between two rooms, be put on
  the middle of the line or into either room (select a wall and press Enter, or double-click
  its dimension); the wall dialog also sets its direction, which makes it slant. The plan settings can
  make their wall thicknesses the ones every new plan starts with
- Slanting walls: draw a room by its corners with Shift (by 15°), or turn a wall in its dialog;
  parts go onto slanting walls too
- Draw walls on their own with the new wall tool (by 15°, with Shift at any angle, or a length
  typed), showing their length and direction as you draw; when they close round a space they
  become a room inside them. Their ends can be dragged, and a double click sets their length,
  direction and thickness
- A room can be a staircase: its stairs are drawn straight in a rectangle and turning in an
  L-shaped room, with the walking line and its arrow (the way up can be turned round); there
  is no wall where they start
- Circuit breakers 1+N (a phase and N) and 3+N in the consumer unit's palette; a two-pole
  breaker can be set to 1+N in its properties. The diagram draws its N pole, the N of what it
  feeds goes through it, and its marking says its poles (B16/1+N)
- In the consumer unit's diagram the poles of a breaker in a group come together below its
  symbol, not inside it; the poles of three-pole devices are further apart, and each busbar
  starts where its conductor comes onto it, the circuits under a three-phase RCD to the right
  of its poles, so every connection reads as it is
- While a room is dragged its doors, windows, furniture, notes and symbols move along with
  it, a dragged wall takes its doors, windows and parts along, and a door or window being
  dragged is shown where it goes
- View > Paper size guide: the sheet of an A4 to A0 paper (landscape or portrait) drawn over the
  page at full size, with its frame and title block, so you can see how much fits on it as
  the export prints it; marked when the drawing does not fit
- The check names a terminal in a switchboard that would take more wires than it holds (a net
  leading out to several parts without a terminal strip), and a strip terminal labelled the
  same on two wires that are not connected (the switchboard would join them)
- The check names a supply conductor coming in on more than one strip terminal (L1 on X1-11
  and on X1-13): one terminal per conductor is enough, every supply point of it can carry it

### Panels
- Training plans for wiring: File > Save as training plan… turns a schematic with its
  switchboards and control stations into a .ladplan exercise. Opened, the student sees the
  schematic, the switchboards, the doors and the stations without wires, and wires them by
  clicking terminal after terminal (the cables between the places are laid, their cores are
  landed by the student); Check wiring says whether it is right and, if the plan allows it,
  lists the missing and wrong wires and the terminals with too many wires
- A training plan runs in Simulate as the student wired it: switch on the breakers in the
  switchboard and press the buttons on the stations to see whether it works
- Wiring a training plan, the student chooses each wire's colour and writes its number on
  its sleeves (the drawing no longer colours and numbers the wires by themselves); the check
  finds wires of the wrong colour and wrong numbers, and missing ones where the plan wants
  every wire numbered
- A training plan can check the function instead of the wires: any wiring that works as the
  schematic does (after switching on the breakers and operating every button and switch) is
  right. The plan keeps each check made and when the first wire was laid; the training panel
  shows how many checks, how the last went and how long it took
- A training plan can leave the mounting to the student: the switchboards, doors and stations
  start empty, the student puts the parts each place lists on its rails or panel and arranges
  them, then wires them; the check names the parts not mounted yet
- A multimeter while a training plan runs in Simulate: put its red and black probes on any
  two terminals in the switchboard, on the back of its door or in a station and read the
  voltage (the supply seen through the loads, as a real meter does, across an open contact
  too) or, with the power off, the resistance (a coil's, 0 Ω through a closed contact, OL
  where nothing conducts)
- Fault-finding tasks: File > Save as fault-finding task… hides faults the teacher chooses
  (or picks at random) in the wiring: a broken wire, a contact that does not close or stays
  closed, a broken coil. The student gets the switchboard and stations wired, runs them,
  measures with the multimeter and reports each fault; the panel says how many are found and,
  where the teacher lets it, which reports are right
- Wiring a training plan, the terminals that already have a wire are marked with a filled
  dot, so it is easy to see what is wired and what is left

### Application
- LadderLab opens with a start window: create a project or open one; tick Program guide to
  take the tour of the window once the project is open (ticked at the first start, after
  the language is chosen)

### Fixed
- No more steps in the floor plan where a wall between two rooms meets a wall going on
  outside: the wall between them lies out of the way of the room whose wall goes on, so its
  face runs straight through
- Switchboard: a net leading to a button, lamp or motor without a terminal strip is wired out
  of the switchboard (straight from the device's terminal), also to parts on its door and to
  parts not on any station, instead of being left without a wire
- Switchboard: a net going on to another switchboard leaves from the strip terminal the cable
  lands on, and a supply sent on from another switchboard comes in through the cable between
  the two instead of a supply cable of its own
- Switchboard: a 10 V reference and the 24 V + are no longer wired or bridged together
- Switchboard: an N or PE distribution block has a connection for every wire, also the overload
  contact's under a contactor, so no wire is left out
- Wiring a training plan, a wire lands on an N or PE distribution block wherever the block is
  clicked, not only in its middle
- Switchboard: PE terminals side by side have no plug-in bridge (drawn or in the parts list),
  they are joined through the rail they clamp onto
- Strip terminals on supply points L1 L2 L3 side by side are labelled on one line under the
  mark ("X1-14", not "X1" over "14"), and a strip label is never written over its own mark


## 0.8.0 – 2026-10-21

### Schematic editor
- A contact renamed to SB, SQ or RB becomes a push button, limit switch or switch (one more
  block of the device of that name where it is drawn), a button or switch renamed to KM, KA
  or KT becomes a contact
- A device takes any number of blocks: a second NC block named SQ1 takes the next free numbers
  (21-22) instead of being refused
- Floor plan: layers of your own (Layers in the plan's bar): make and name them, choose the
  one new parts, notes, dimensions and furniture go on, and show or hide each; a right click
  on a part, note, dimension or piece of furniture puts it on another layer. Rooms, walls,
  doors, windows and the consumer unit are always shown

### Panels
- The N and PE distribution blocks in a switchboard can be picked and moved along a rail or to
  another rail; they stay where they were put

### Files and export
- The floor plan sheets of a PDF export leave out the layers hidden on the plan, in place of
  the fixed choice of lighting and sockets on separate sheets: hide a layer to print a plan
  without it

### Fixed
- Wires of a moved part no longer step out of a terminal and back; they take a corner instead
- A strip terminal on a wire between two parts in different places (two limit switches) gets
  the cores of both cables in the switchboard, not just one
- Stations and parts in the field are no longer cabled to one another: each cable runs to the
  switchboard

## 0.7.0 – 2026-10-21

### Schematic editor
- Three kinds of schematic at File > New: industrial, prototype residential (light switches,
  luminaires and sockets drawn and wired freely, as residential schematics were) and
  residential, a house installation whose consumer unit is drawn as its single-line diagram
- The single-line diagram of a residential installation, as Czech projects draw it: the supply
  through the main switch onto busbars L1, L2, L3 and N, a surge protective device, PE and N
  bars, and the circuits hanging from their busbar in columns, only the phases drawn. A breaker
  from the palette clicked under the busbars makes a circuit, an RCD a group with its own
  busbar and N bar for the breakers put under it; sockets, luminaires and appliances clicked
  onto a circuit are what it feeds. Each circuit shows its breaker as on the schematic (an
  RCBO or AFDD with its release and test button), designation and rating, cable number and
  cable, the symbol of what it feeds, where it goes and a link to its room on the floor plan;
  a circuit can be switched by the ripple control (HDO) contactor. Breakers and RCDs are
  dragged to move their circuits; N and PE are wired by themselves. While simulating the
  circuits show their voltage, and the main switch, breakers, RCDs, test buttons and the HDO
  contact are clicked to operate them
- Export to PDF puts a residential installation's single-line diagram on a sheet
- The floor plan of a residential installation takes its light switches, luminaires,
  sockets and appliances from the palette onto the circuit chosen beside the plan (a part's
  circuit is changed there too). Wire draws the lighting: from a switch to the luminaires it
  switches, between the switches of a staircase (with intermediate switches between them),
  from the side of a two-rocker switch for its rocker; it is wired by itself and simulates,
  drawn along the walls with a tick per core
- Sockets and appliances on the plan carry their circuit tag (Z 6.1); rooms their number,
  and the plan a legend of the rooms with their environment (ČSN 33 2000-5-51) and
  illuminance, set by a double click on a room
- The floor plan opens the consumer unit RD1 (a click on its symbol while simulating, a
  double click in Edit mode): its switchboard in place of the plan, made with the protection
  on its rails when there is none yet, its breakers switched there while simulating
- Export to PDF puts the floor plan of a house installation on a sheet in place of the
  workspace, with a legend of the symbols and the standard installation heights
- Light switch levers are all one length, as long as reaches a contact straight below;
  contacts further off have a fixed arm up to the lever, and every lever rests off
- Socket outlets on the floor plan are drawn as on Czech installation drawings: a stem from
  the wall to the back of a half circle open to the room, a double socket two of them
- Floor plan: the palette draws the parts as the plan does; a selected room shows its
  dimensions, and a double click on one (or Enter with a wall selected) types that wall's
  length, the room dialog a rectangle's width and height; a wall moved takes the room sharing
  it and the parts and doors on it along
- Rooms of any outline: two rooms touching along a wall are joined into one (Join), an
  L-shaped room is offered ready-made; every wall is dragged and its length typed
- Doors: a double click sets a door's width, single or double, the end of its hinges and the
  side it opens to (F and Shift+F swap them on a selected door)
- A room's number or name and its area are dragged where they suit; walls are drawn grey,
  apart from the symbols; the consumer unit is a box with a second one inside it; the room
  environments are explained in the room dialog and under the legend of the rooms
- Ctrl+Z and Ctrl+Y undo and redo on the floor plan, the workspace and the single-line diagram
- Single-line diagram: anything nests under anything in the consumer unit: a 30 mA RCD under a
  selective 300 mA one, breakers under a breaker, an RCBO or AFDD with circuits under it,
  to any depth; a device is put under another below its busbar, or below the breaker of a
  circuit that feeds nothing
- Single-line diagram: Shift or Ctrl+click and a box drawn from an empty place select several
  devices and parts, dragged or deleted together; while placing or dragging, the diagram makes
  room and shows a see-through ghost of what goes there
- Single-line diagram: a circuit without an RCD of 30 mA or less over it is marked, as
  ČSN 33 2000-4-41 asks for one on everything an ordinary person can reach
- Single-line diagram: each circuit's cable length worked out from the floor plan (the unit to
  every part it feeds, along the walls, with the drops and a 10 % reserve), its voltage drop at
  the breaker's rated current against 3 % (lighting) or 5 % (ČSN 33 2000-5-52) and its fault
  loop impedance against what trips the breaker at once (the supply's Ze set at the incoming
  supply); written along the cable, red when out of bounds
- Residual current devices of types F, B and B+ beside AC and A, and selective ones (S): a
  selective RCD lets the one nearest the fault trip alone
- The floor plan sheet of a PDF export draws the plan as large as its paper takes, and the
  designations of parts close together (switches back to back on a wall) no longer print over
  each other: each goes where it is clear, into its room first
- Floor plan: windows (Window tool; a double click sets width, sill and height) and walls
  drawn with their thickness, outside walls outside the rooms and walls between rooms on their
  line (Walls sets both); doors and windows cut through the whole wall
- Floor plan: dimensions printed with it, a chain along a wall clicked (its corners, parts,
  doors and windows) or one dragged between two points, set off by dragging; a measure tool
  shows the distance between two points
- Floor plan: while a socket or switch goes on a wall (or one there is selected), its distance
  from the nearest corner or door or window frame shows; typing a number (mm) and Enter puts
  it exactly that far
- Floor plan: Array spreads luminaires over a selected room in rows and columns, or puts
  sockets and wall luminaires in a row along a selected wall, evenly or every so far
- Floor plan: notes with a leader to the point they are about, printed with the plan
- Floor plan: furniture and fixtures from the palette (kitchen worktop, bath, shower tray,
  washbasin, WC, bed, wardrobe, table, sofa), drawn faintly with their backs against a wall;
  R turns one, a double click sets its size; a socket behind the worktop goes at 1.10 m
- Floor plan: selected rooms, parts, doors and windows are drawn in the selection colour,
  which shows on white paper
- Floor plan: several floors (1.PP, 1.NP, 2.NP ...) as tabs over the plan, each its own plan
  and sheet, rooms numbered by floor (001, 101, 201); one consumer unit and one single-line
  diagram for the whole house
- Floor plan: the architect's drawing (PNG or JPG) as a faint underlay to trace over, scaled
  by two points a known distance apart and dragged into place; it does not print
- Export: a house's floor plans can go on two sheets a floor, the lighting plan and the
  socket plan; each sheet's legend lists only the symbols on it, with how many there are
- Export: floor plans print at a true scale (1:50, 1:100, 1:200 or 1:500, the largest the
  paper takes) with a scale bar and a north arrow (set with the walls); the title block has
  the stage of the documentation and the scale and format
- Export: a house's parts list has each floor's parts, the wall and luminaire boxes and the
  metres of each cable type; File > Export parts list as CSV writes it for a spreadsheet
- Floor plan: the symbols and the texts can be drawn larger or smaller (Plan settings, 50 to
  300 %), on the plan, its sheet and its legend
- Floor plan: what is selected shows handles to change its size by dragging: a room's
  corners, a door's or window's ends, a piece of furniture's corners, a dimension's ends;
  the legend of the rooms is dragged anywhere
- Floor plan: every symbol is drawn upright, the way the legend and the palette show it, on
  whatever wall it is, but socket outlets, which face into the room from their wall;
  dimensions up and down are written across like all other text
- Luminaires are a plain cross on the floor plan; wall luminaires (a cross with a line on its
  wall's side, 2.00 m over the floor) are a new part in the palette, put onto a wall
- Floor plan rooms: drawn by dragging or by clicking two corners, the size typed in mm
  (width, Tab, depth, Enter); drawn by their corners for any shape with walls across or up
  and down (a wall's length typed); split in two by a wall dragged across; a ready room
  follows the mouse and goes where clicked. A room just drawn offers the usual names (a
  bathroom's environment and illuminance follow); the room picked is edited in a panel
  beside the plan (name, size, area, number, environment, illuminance), right-clicked for
  its menu (rename, duplicate, split, join, delete), duplicated with Ctrl+D and moved with
  the arrow keys. The wall or room under the mouse lights up with the cursor of what a
  drag does; resizing shows the size and area and a guide where a wall lines up with
  another room's; overlapping rooms are hatched with a warning. The plan's tools have
  larger icons drawn after what they do
- Floor plan: your own symbols (Symbols in the plan's bar): draw them from lines, rectangles,
  ellipses, arcs, curves and text on a grid of centimetres, give each a name and a category
  of your own, put them on a wall or anywhere; the palette offers them under their
  categories for every residential installation. A symbol can be a drawing only or an
  electrical one, a load of its power on the circuit chosen: on the single-line diagram,
  in the parts list and the simulation like an appliance. Both are in the legend with their
  count, and a schematic keeps the symbols it uses, so it opens with them anywhere
- Floor plan: your symbols are exported to a file (all of them or one category) and
  imported from one, to share them or move them to another computer; a symbol you have
  already is drawn as in the file
- Symbol editor: polylines and polygons, pictures from image files (PNG, JPG, WebP, SVG),
  a line width, style (dashed, dotted, dash and dot) and colour for every shape and a fill
  colour for closed ones, arcs and curves filled too; texts at any angle, bold or italic.
  Several shapes are picked at once (Shift or Ctrl+click, a box, Ctrl+A), moved, turned,
  mirrored and scaled together, copied, cut, pasted (into another symbol too) and
  duplicated; points snap to those of other shapes, the grid is 1, 5 or 10 mm or none, and
  the points of a shape can be typed in millimetres
- Symbol editor: points also snap to the middles of edges (a triangle marks one), and lines
  drawn from a point or points dragged to angles of 15°, 45° or 90° (chosen beside the
  grid, or 15° with Shift), the length on the grid; a guide shows the angle and the length
- Symbol editor: the points of a polygon or polyline are edited (a double click on it, or
  Edit points): dragged, put in on an edge or from the plus in its middle, taken out with
  Delete or Ctrl+click
- Symbol editor: shapes turn by any angle (Rotate, Ctrl+R, or dragging the round handle over
  the shapes picked, by 15° with Shift; R still turns a quarter), and a
  rectangle, ellipse or picture has an angle of its own; texts in any font of the computer
  (where a symbol's font is missing, the plan's font stands in)
- On an industrial schematic a warning sign marks terminals of two parts lying on one another
  without being connected; with the mouse over it the status bar names them
- "Set at simulation start" in the right click menu of an industrial schematic: circuit
  breakers, fuse holders, switches and cam switches set this way are switched on (or turned to
  I) when the simulation starts
- Terminals are easier to hit: while drawing a wire a click anywhere in a terminal's cell takes
  it, a wire is started a little beside a terminal too, and zoomed out the area never gets
  smaller than a few pixels on screen

### Panels
- The narrowest switchboard has a 12-module DIN rail: room for four 3-pole circuit breakers
  side by side
- A group on the workspace is resized by dragging the corner of its frame in Edit mode; a
  group with a mechanical link shows where its part is (or starts) in per cent in its heading
- The control panel is back beside the schematic of an industrial circuit while simulating:
  every control station and switchboard door with its push buttons, switches, lamps and
  potentiometers, operated there with the schematic in view. A click on its title rolls it in
  to a narrow tab at the edge of the window, a click on the tab rolls it out again
- The control panel also shows the mechanical links of the workspace's groups while
  simulating: where the part a motor moves is (in per cent and on its way), whether the motor
  runs forwards, in reverse or stands, and the limit switches along the way, lit while the
  part operates them

### Files and export
- Export to PDF can hold the time relays: each relay's symbol as on the schematic, its
  designation, function, times (t, or t1 and t2) and control input, beside the timing
  diagram of its function (Time relays in the preview)

### Fixed
- Inside a control station, terminals wired only to a supply point of their own (a
  potentiometer's - point or 10 V reference) get their wires: supply points of one conductor
  are one core, and a supply only wired to the station comes from the switchboard
- "Wire facing terminals" also wires terminals that already have a wire to something else
- In a switchboard, two overload relays behind contactors whose outputs are joined (each
  feeding both motors, or a reversing pair) are both fitted under a contactor, one under
  each; the second one no longer stands beside them on the rail

## 0.6.0 – 2026-10-20

### Schematic editor
- House installations: File > New asks whether the new schematic is an industrial control
  circuit or a residential installation (for good; the toolbar says which). A residential
  schematic has a palette of its own: light switches numbered as Czech installations
  number them after ČSN EN 60669-1 (řazení 1, 2, 3, 03, 4, 5, 5B (6+6), 6, 6/2 and 7, -SF,
  terminals marked as on the switches; drawn as on Czech wiring diagrams: a box with the
  incoming terminals on top, a lever to the contact it touches, live contacts filled while
  simulating), luminaires (-EA) and single or
  double type E socket outlets (-XD), with the supplies and the circuit breaker
- Residential protection and appliances: residual current devices (-FB, 2 or 4 poles,
  10-300 mA, type AC or A, or an RCBO with its breaker characteristic), arc fault detection
  devices with breaker (AFDD), and appliances: water heater, oven, induction hob (400 V),
  microwave, washing machine, dishwasher, heater and fridge; a socket can have an appliance
  plugged in
- Floor plan of a house installation (Schematic | Floor plan): rooms drawn by dragging or added
  ready-made, snapping to each other's walls like modules, resized by their edges, moved with
  everything in them, renamed by a double click; doors in their walls. Switches, sockets,
  luminaires, appliances and the consumer unit are put on it from the list of parts not
  placed yet (onto the nearest wall, luminaires on the ceiling), drawn with the symbols of
  Czech installation drawings and their heights, and the cables between them are worked out
  from the wiring with a tick per core
- Every light switch, luminaire and socket has a mounting height over the floor: the
  standard one of Czech practice (switches 1.20 m, sockets 0.30 m, luminaires on a 2.60 m
  ceiling) until it is set in the properties; a height other than the standard one is
  written beside the part, as on Czech installation drawings
- "Wire facing terminals" in the right click menu wires the free terminals of the selected
  parts that face each other with straight wires in one go
- Wiring helpers under Settings > Wiring: "Wire all poles at once" makes a wire drawn between
  breakers, contactors, overload relays, motors or supply points in a row take the poles
  beside it along (Shift: that wire alone); "Wire parts placed in line (EPLAN style)" gives a
  part placed or dropped straight wires to the free terminals it faces. The wires to come
  are shown dashed first
- PLCs talk to one another over Ethernet as real ones do: every PLC has an Ethernet port P1
  and an IP address (properties; a new PLC takes the next free one, 192.168.0.n), Ethernet
  cables are drawn port to port (dashed green) and a network switch with four ports (KF, in
  the palette under PLC and sensors) joins more than two PLCs
- The check finds Ethernet mistakes: a port wired to anything but one other port, more than
  two ports on one cable, two PLCs with one IP address on one network, network inputs
  reading from an address no PLC on the network has or one on another subnet
- Selector switch blocks (I-0-II) and rotary cam switches show a small switching table under
  their designation: the positions I 0 II (or 0 I) with a dot under each position the
  contact is closed in, instead of a text such as "I-0-II: I"
- Proximity sensors for PLC inputs (palette, PLC and sensors): inductive, capacitive, optical
  (diffuse light) or magnetic (cylinder sensor), PNP or NPN, NO, NC or antivalent NO + NC
  (4 wires), with the terminals and core colours of the real ones: 1 BN (+24 V), 3 BU (0 V),
  4 BK (output), 2 WH (second output); each with its datasheet
- Pressure, level and flow transmitters with a 0-10 V output, wired 1 BN, 3 BU, 2 WH as on
  their M12 plug, with their measuring range set in the properties
- A 10 kΩ potentiometer (-RP1, terminals 1-2-3) for analog inputs, with 1, 2, 5 or 10 turns

### Simulation
- An RCD trips when what goes out on the phases does not come back on its N: an insulation
  fault of an appliance (fault menu: phase on the frame), N taken past it, and its test button
  T; a short between L and N leaves it on (an RCBO trips on it as a breaker). Without PE an
  insulation fault leaves the appliance's frame live. A loose connection that arcs (fault
  menu) trips the AFDD feeding it. Appliances draw their power, so too many on one circuit
  trip its breaker
- The floor plan shows the simulation: lit luminaires glow, live sockets and working
  appliances are filled, and a click on a switch on the plan switches it
- A click on a light switch's rocker switches it over (on a double switch, the rocker
  clicked): a staircase light with two-way switches and intermediate switches between them
  is switched from any place; luminaires light and show in the timing chart, a socket shows
  230 V while it has its voltage
- A proximity sensor switches its output while it has 10-30 V DC: click it to put something
  in front of it or take it away. A PNP output works a PLC input whose common is on 0 V, an
  NPN output one whose common is on +24 V; the outputs show in the timing chart
- A proximity sensor in a group with a mechanical link is worked by the moving part, like a
  limit switch, e.g. as the end position sensors of a gate
- Click a transmitter to set its pressure, level or flow; it puts 0-10 V on a PLC's analog
  input over its range
- A potentiometer's wiper gives its share of the voltage between 1 and 3 (e.g. 0-10 V from a
  frequency inverter's 10V) to an analog input; click it in the schematic to set it
- A + supply can be 10 V, a reference to feed potentiometers for 0-10 V analog inputs
- Network inputs NI1-NI64 and network analog inputs NAI1-NAI32 in both program languages
  read an input, output or flag (or an analog input or output) of the PLC at the IP address
  set for them in the PLC window, as the network inputs of real logic modules do; they read 0 while it cannot be
  reached (switched off, no cable, the switch without its supply, another subnet, an address
  taken twice). The event log says when a connection is established or lost, the ports and
  switch ports light while they have a link, and the PLC window's own simulation has a
  switch for each network input

### Panels
- The switchboard draws the PLCs' Ethernet sockets and the network switch, and wires the
  Ethernet cables as green Cat 6 cables with RJ45 plugs through the ducts; to a PLC in
  another switchboard the cable leaves through a gland of its own. On the workspace that
  cable is its own cable (Cat 6 S/FTP 4x2xAWG23), drawn green
- Potentiometers on control stations and switchboard doors: a knob over a 0-10 scale for
  one turn, a turns-counting dial for 2, 5 and 10 turns; turned with the mouse wheel or by
  dragging up and down (Shift: ten notches at a time), finer the more turns it has. Inside,
  its round body with solder lugs, the wires pushed on with insulated fastons and numbered
- Sensors on the workspace show what they are: a sensor barrel, a light sensor, a gauge, a
  tank, a pipe or a thermometer, named under the tile
- On the workspace, switchboards and stations are a tile with their name under it; their
  title, what they hold and the keys bound to their buttons show when you point at them.
  Cable names are written beside the cable instead of in a box on it, so no text hides a
  cable any more
- Two wires that have to go into one strip terminal share a twin ferrule (one pin, the
  collar round both wires) instead of a terminal twice as wide
- Plug-in bridges on terminal strips are grey (blue on N) instead of red
- View > Wire duct covers draws the switchboards' wire ducts with their covers on, for a
  tidier look with the wiring in the ducts out of sight; the export still shows them open
- Switchboard wire ducts are at most four wires wide: busier ducts no longer grow wider,
  their wires lie closer together in them, so the switchboards are more compact

### Files and export
- "Export SCL…" in the PLC window saves a compact CPU's program as an SCL source for TIA Portal
  (S7-1200): a function block with the program, its instance data block and Main [OB1]
  calling it, with the CPU's addresses (%I0.0, %Q0.0, %M0.0, %IW64) and IEC timers. Add it
  under External source files, generate the blocks and download them to the CPU; it switches
  the outputs as the program does in LadderLab
- PLC program files (.plcprog) keep the partners of the network inputs; schematics keep the
  PLCs' IP addresses and the network switches (older files open with 192.168.0.1)

### Application
- A fifth lesson, "A PLC reads a potentiometer": a 10 V supply point, a potentiometer wired
  to the analog input of a compact PLC whose threshold trigger lights a lamp past half (and
  only under 40 % dark again); Check turns the potentiometer to set positions
- Lessons ring the terminals each wire of a wiring step goes between, every palette entry a
  step still needs (a contact and a lamp, not only the contact), the property field a step
  asks to set (the breaker's Poles, the time relay's Time t) and cross out the wire a step
  asks to delete
- While a wire is drawn from a terminal a lesson step asks to wire, a dashed guide runs to
  the terminal it should end on; a part drawn faintly by Show me gives way to any part placed
  where it was drawn
- The welcome card on the first start asks for the language first (English or Čeština) and
  offers the tour and the first lesson in it
- A Settings menu beside View holds the wiring helpers, the cable type names and the
  language, which have moved there from View

## 0.5.0 – 2026-10-20

### Panels
- Wires on from a contactor's outputs under its overload relay come out from behind the
  relay at its left side, all of them, near its top, and run down beside it, no longer out under the relay
  between its own wires
- Every terminal strip entry in a switchboard takes one wire with one marker sleeve: the
  wiring loops through the devices' terminals rather than a strip terminal, the terminals of
  one net stand side by side on their strip (unless you set the order) joined by a plug-in
  bridge, and N or PE gets a distribution block from two loads on; a strip terminal that
  still has to join two wires is a terminal for two wires, twice as wide, with two entries
  side by side at each end

### Application
- Lessons (Help > Lessons): four lessons teach drawing and simulating circuits, from a lamp
  and a switch through start/stop with a self-holding contact and a time relay to a motor
  with a circuit breaker and an overload relay. The lesson panel beside the drawing ticks each
  step by itself when the drawing (or the simulation) has it, rings the palette entry, the
  parts or the button the step is about, and Show me draws where its parts and wires go;
  Check runs the circuit and says which of the lesson's goals it meets, with a chart of the
  test that failed and the parts concerned ringed; finished lessons are ticked in the menu
- Interface tour (Help > Interface tour): a short walk through the window, each stop
  highlighted with a card saying what it is for; Esc or Skip tour leaves it
- A card over the drawing offers the tour or the first lesson, until it is answered

### Fixed
- The terminal strip labels of a motor or of three poles side by side are all written alike,
  on one line in one size past their marks beside the wires, no longer some a size smaller or
  on two lines; a strip label no longer runs onto a terminal of its own part (a motor's PE)
- In the switchboard the wires go into the middle of their strip terminals at every zoom;
  at some zoom levels they drifted off the terminals along the strip
- In the switchboard the wires of a rotary cam switch of two or more poles are grey like the
  rest of the main power circuit; L1 fed through one was red, like a control circuit's phase
- Changing a 3~ motor's kind or turning a rotary cam switch from 0-I into I-0-II keeps every
  wire on its terminal; the PE wire moved onto U2 (or a phase onto PE), and a cam switch's
  L2 onto the common of its first pole
- Pressing Delete, Ctrl+Z or Ctrl+Y while dragging a wire, a wire number or a marking no
  longer moves another wire or stops with an error when the mouse moves on
- Delete after Select all (or Shift+click) removes everything selected, not only a strip
  terminal mark highlighted before
- Switching the layout between vertical and horizontal takes markings and wire numbers moved
  beside their part or wire along to the same side
- Mains on a frequency inverter's 24 V blows the fuse or trips the breaker in its way; the
  short lasted with the whole mains down
- With instant switching a motor on a frequency inverter above 60 Hz runs at its speed; it
  stopped at 1.2 times its rated speed
- A PLC switching an output from Q8 on back and forth through its own wiring is reported as
  oscillating, like one switching Q1-Q7
- On a station or a switchboard door, a plate text typed and not entered is kept when the
  item is then moved, removed or its colour, device or kind changed; moving it put a copy of
  the item in place of its neighbour, and other changes were undone
- A control station shown as its face no longer stays on the workspace after a new or opened
  schematic with no places; undo while dragging a group on the workspace no longer stops
  with an error

## 0.4.5 – 2026-10-19

### Panels
- A switchboard has a door (Inside | Door at the top of the opened switchboard) with push
  buttons, switches, rotary cam switches and signal lamps on it, put on and edited like on a
  control station and operated there while simulating; inside, their wires leave the strip
  terminals in the door harness, and the export shows the door beside the switchboard
- Door open shows the switchboard with its door opened beside it: the back of the door with
  the contact blocks of its buttons and switches, their wires going straight into the
  contacts, and the door harness crossing in its conduit at the hinge; inside the switchboard
  the harness runs from the terminal strips along the bottom duct to a fitting in the hinge
  side wall, never out of the enclosure and back in
- The wires inside a control station and on the back of a door show their wire numbers,
  written beside their sleeves while the drawing is too small to read them on the sleeves;
  the door harness's cores are marked where they leave their fittings, and its conduit
  lists their numbers
- A control station can be opened with its cover off (Front | Inside): the contact blocks
  behind each button and switch with their terminal numbers, lamp blocks, a cam switch's
  chambers, the cable coming in through its gland and every core and wire to the terminals,
  coloured by conductor with their wire numbers; while simulating the terminals show their
  voltage

## 0.4.4 – 2026-10-19

### Schematic editor
- Phase supplies placed one after the other become L1, L2, L3 (not L1, L1, L1)
- Terminal marks are written on one line, "X2-6" (and "X1-6"), instead of the strip over the
  number, where there is room; they can be typed that way too
- Several selected parts can be lined up vertically or horizontally (right click), the same
  number of free cells apart; a ruler on the drawing shows the cells while you choose it
- Rotary cam switch: 1-4 poles with the positions 0-I (off / on) or I-0-II (forward / off /
  reverse, each pole a changeover with the off position in the middle); a click turns it on
  to the next position, on a control station its knob turns left or right
- Selector switches can have the positions I-0-II (e.g. manual / off / auto): each block of the
  switch is operated in position I or in position II (set in its properties)

### Simulation
- 3~ motors have a load setting (% of the rated torque) and show their torque in N·m while
  simulating
- The timing chart shows only the signals you choose (the list button beside Follow)

### Panels
- PLC ladder diagram: the chosen contact or coil is shown faintly where a click puts it
- PLC ladder diagram: wires are drawn as in the schematic: click where the wire starts, click
  for corners, and it ends on the rail, an element or another wire (or with a double click)
- A control station can be shown on the workspace as the station itself (right click, Edit mode):
  its buttons and switches work right there while simulating, its lamps light, and its corner
  sizes it
- Parts list: identical parts of a place are one row with their quantity, buttons and switches
  list their contact blocks, contactors and breakers their auxiliary contacts, and each
  switchboard and station lists its cable glands sized for the cables (PG or metric)
- Motors in the field turn on the workspace while simulating, as fast and in the direction they run
- A rotary cam switch is drawn bigger than a selector switch on a control station
- Workspace cables get a type by their use: CGSG-J to motors and limit switches, JYTY-O to
  control stations, shielded LiYCY to sensors, CYKY-J between switchboards (View > Cable types:
  Czech, or the European H07RN-F, H05VV5-F, H05VVC4V5-K, NYY-J)
- A cable opened on the workspace can be given a type name of your own, a cross-section and its
  length; it then shows its voltage drop (marked above 4 %), and the length is written on the
  workspace and in the parts list
- Switchboard wires carry yellow marker sleeves with their wire numbers at both ends (L1, N,
  PE … on supply wires without a number); two wires in one terminal spread apart so both sleeves
  show, side by side or one above the other; the ducts sit further from the devices to leave
  room for them
- Switchboard wires go into their terminals as on a real device: in at the face of the
  terminal's tier past the screw, with insulated ferrule collars; device labels sit on the plate
  clear of the wire ends
- Switchboard wire ducts are just as wide as the wires running through them need
- Switchboard wires are easier to follow: in each duct they lie in order by where they come in
  and go out, so far fewer of them cross
- Switchboard wires bend once past their marker sleeve and slant into the duct's slot, and
  never cross each other on the way to the ducts
- Neighbouring terminals of one net on a terminal strip are joined by a plug-in bridge
  instead of a wire; the parts list has the bridges
- Every strip terminal on the lead of a part outside gets its own core in the cable to it,
  also where several terminals are on one net
- No terminal in a switchboard takes more than two wires: nets are looped from terminal to
  terminal instead of branching
- A switchboard where more than two loads take PE gets a PE distribution block: the incoming
  PE and every load's PE are wired to it, each in a connection of its own; it is in the parts
  list
- Likewise where more than two loads take N: an N distribution block (grey, blue cover) the
  incoming N and every load's N are wired to
- Wires to the auxiliary contact block on a contactor's front run straight over the contactor;
  wires from a contactor's bottom terminals over its overload relay go straight down as far as
  they can before turning aside, and wires from its main contacts go behind the relay

### Files and export
- PLC programs can be exported to a file and imported into another PLC (PLC window)
- The PDF export can hold the PLC programs, each in the language it runs (FBD on one sheet,
  a ladder diagram over as many sheets as it needs)
- The export preview has a largest sheet size (A5 to A0): pages go on the smallest sheet they
  fit on up to it, larger ones are scaled down onto it

### Application
- The example circuits are no longer in the program (the toolbar list is gone)

### Fixed
- Switchboard: two supply points of one conductor on the same strip terminal no longer get a wire
  from the terminal back into itself
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
