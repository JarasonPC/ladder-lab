extends GutTest
## The timing chart and panel, the event log, popups and panels at small
## windows and large interface sizes, and the fault menu while simulating.


## A panel or bar laid out in a window of [param window_size] (logical
## pixels): a sub-viewport holding a column with [param above] pixels of
## other bars in it.
func _column(window_size: Vector2i, above: float) -> VBoxContainer:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = window_size
	add_child_autofree(viewport)
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(column)
	var bar: Control = Control.new()
	bar.custom_minimum_size = Vector2(0, above)
	column.add_child(bar)
	return column


func _row_labels(chart: TimingChart) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for row: Dictionary in chart.get("_rows"):
		labels.append(row["label"])
	return labels


func test_chart_rows_of_a_compact_plc() -> void:
	# Transistor outputs have one terminal: the last one used to be read past
	# the end, an unwired output beside a wired one got a row.
	var doc: SchematicDocument = SchematicDocument.new()
	var plc: CompactPlc = doc.add(CompactPlc.new("A1", PlcProgram.new()), Vector2i(0, 0)) as CompactPlc
	doc.add(Lamp.new("H1"), Vector2i(0, 10))
	doc.add(Lamp.new("H2"), Vector2i(4, 10))
	var keys: PackedStringArray = plc.get_terminal_keys()
	doc.connect_terminals(keys[plc.output_terminal(1)], "H1:X1")
	doc.connect_terminals(keys[plc.output_terminal(plc.output_count() - 1)], "H2:X1")
	var chart: TimingChart = TimingChart.new()
	add_child_autofree(chart)
	chart.set_document(doc, TraceRecorder.new())
	var labels: PackedStringArray = _row_labels(chart)
	assert_has(labels, "A1 Q2")
	assert_has(labels, "A1 Q%d" % plc.output_count(), "the last output, wired")
	assert_does_not_have(labels, "A1 Q1", "not wired")
	# The last output unwired: every row is still built.
	doc.remove_wire(doc.circuit.get_wires().size() - 1)
	chart.set_document(doc, TraceRecorder.new())
	assert_eq(_row_labels(chart), PackedStringArray(["A1 Q2", "H1", "H2"]))


func test_chart_rows_of_a_relay_plc() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	var plc: Plc = doc.add(Plc.new("A1", PlcProgram.new()), Vector2i(0, 0)) as Plc
	doc.add(Lamp.new("H1"), Vector2i(0, 10))
	var keys: PackedStringArray = plc.get_terminal_keys()
	doc.connect_terminals(keys[plc.output_terminal(2) + 1], "H1:X1")
	var chart: TimingChart = TimingChart.new()
	add_child_autofree(chart)
	chart.set_document(doc, TraceRecorder.new())
	assert_eq(_row_labels(chart), PackedStringArray(["A1 Q3", "H1"]), "a relay output wired on its second terminal")


func test_rated_current_mark_of_an_overload_relay() -> void:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(OverloadRelay.new("F1", OverloadRelay.DEFAULT_TRIP_DELAY, 3), Vector2i(0, 0))
	doc.add(Fuse.new("FU1"), Vector2i(6, 0))
	var chart: TimingChart = TimingChart.new()
	add_child_autofree(chart)
	chart.set_document(doc, TraceRecorder.new())
	var marks: Dictionary = {}
	for row: Dictionary in chart.get("_rows"):
		marks[row["label"]] = row["rated_label"]
	assert_eq(marks, {"F1": "Ir", "FU1": "In"})


func test_follow_jumps_to_now_while_paused() -> void:
	var panel: TimingPanel = TimingPanel.new()
	add_child_autofree(panel)
	var chart: TimingChart = panel.chart
	chart.window = 0.5
	chart.set_time(3.0)
	chart.follow = false
	chart.set("_end", 1.0)
	assert_eq(panel.get("_hint_text"), "Double click: follow", "the hint says how to follow again")
	# No step comes while paused: Follow alone must bring the chart to now.
	(panel.get("_live") as Button).pressed.emit()
	assert_true(chart.follow)
	assert_eq(chart.get("_end"), 3.0)
	assert_eq(panel.get("_hint_text"), "Drag to look back, wheel zooms")


func test_dragging_at_the_start_stays_at_now() -> void:
	var chart: TimingChart = TimingChart.new()
	chart.size = Vector2(600, 200)
	add_child_autofree(chart)
	chart.window = 2.0
	chart.set_time(0.14)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	chart._gui_input(press)
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.relative = Vector2(10, 0)
	chart._gui_input(drag)
	assert_eq(chart.get("_end"), 0.14, "never past now")
	drag.relative = Vector2(-10, 0)
	chart._gui_input(drag)
	assert_eq(chart.get("_end"), 0.14, "nothing before the start to look back to")


func test_time_span_field_shows_the_wheel_zoom() -> void:
	var panel: TimingPanel = TimingPanel.new()
	add_child_autofree(panel)
	var select: OptionButton = panel.get("_window_select")
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	panel.chart._gui_input(wheel)
	assert_almost_eq(panel.chart.window, 0.08, 1e-6)
	assert_eq(select.selected, -1, "no choice is 80 ms")
	assert_eq(select.text, "80 ms")
	panel.chart.window = 2.0
	panel.call("_on_window_changed", 2.0)
	assert_eq(select.text, "2 s")
	assert_eq(TimingPanel.span_text(2.5), "2.5 s")


func test_timing_panel_fits_a_small_window() -> void:
	# 1280 x 720 at 200 %: 640 x 360 logical pixels, 150 of them other bars.
	var column: VBoxContainer = _column(Vector2i(640, 360), 150.0)
	# Chosen earlier in a larger window (set before the panel is shown, as
	# from the settings).
	var panel: TimingPanel = TimingPanel.new()
	panel.panel_height = 700.0
	panel.log_width = 900.0
	column.add_child(panel)
	await wait_process_frames(3)
	assert_almost_eq(panel.custom_minimum_size.y, (360.0 - 150.0) * TimingPanel.MAX_HEIGHT_SHARE, 1.0, "a share of the height the other bars leave")
	assert_true(column.get_combined_minimum_size().x <= 640.0, "the chart and the log fit the width")
	assert_true(column.get_combined_minimum_size().y <= 360.0, "and the height")
	assert_eq(panel.panel_height, 700.0, "the chosen height is kept for a larger window")
	assert_eq(panel.log_width, 900.0)


func test_side_bar_fits_a_small_window() -> void:
	var column: VBoxContainer = _column(Vector2i(640, 360), 0.0)
	var bar: SideBar = SideBar.new(Control.new(), false, 400.0)
	column.add_child(bar)
	await wait_process_frames(2)
	assert_eq(bar.zoom_box.custom_minimum_size.x, 640.0 * SideBar.MAX_WIDTH_SHARE)
	assert_eq(bar.width, 400.0, "the chosen width is kept")
	# Content taller than the window scrolls.
	var tall: Control = bar.content
	tall.custom_minimum_size = Vector2(100, 2000)
	await wait_process_frames(2)
	assert_true(column.get_combined_minimum_size().y <= 360.0)


func test_event_log_scrolls_to_the_newest_entry() -> void:
	var log: EventLog = EventLog.new()
	log.custom_minimum_size = Vector2(300, 150)
	add_child_autofree(log)
	await wait_process_frames(1)
	for i: int in 40:
		var entries: Array[Dictionary] = [{"time": float(i), "text": "%s switched on", "args": ["EV%d" % i]}]
		log.add_events(entries)
		await wait_process_frames(1)
	await wait_process_frames(2)
	var bar: VScrollBar = (log.get("_list") as ItemList).get_v_scroll_bar()
	assert_almost_eq(bar.value + bar.page, bar.max_value, 0.5, "the last entry is shown")


func _fault_doc() -> SchematicDocument:
	var doc: SchematicDocument = SchematicDocument.new()
	doc.add(PowerSupply.new("L", PowerSupply.Conductor.L), Vector2i(0, 0))
	doc.add(Coil.new("KM1"), Vector2i(0, 4))
	doc.add(PowerSupply.new("N", PowerSupply.Conductor.N), Vector2i(0, 8))
	doc.connect_terminals("L", "KM1:A1")
	doc.connect_terminals("KM1:A2", "N")
	return doc


func test_burnt_out_coil_can_be_replaced() -> void:
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(_fault_doc(), true)
	var coil: Coil = view.document.circuit.get_component("KM1") as Coil
	coil.burnt = true
	view.set("_fault_target", coil)
	view.call("_fill_fault_menu")
	var menu: PopupMenu = view.get("_fault_menu")
	assert_eq(menu.get_item_text(0), "Replace the burnt-out part", "first")
	assert_eq(menu.get_item_id(0), SchematicView.FaultId.CLEAR)
	var texts: PackedStringArray = PackedStringArray()
	for i: int in menu.item_count:
		texts.append(menu.get_item_text(i))
	assert_has(texts, "Coil broken (no pull-in)", "its own faults stay offered")
	view.call("_on_fault_menu", SchematicView.FaultId.CLEAR)
	assert_false(coil.burnt)


func test_fault_menu_ignores_the_drawing_zoom() -> void:
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(_fault_doc(), true)
	# Zoomed in: a menu under the drawing took the zoom as its scale.
	view.scale = Vector2(3, 3)
	view.call("_open_fault_menu")
	var menu: PopupMenu = view.get("_fault_menu")
	assert_almost_eq(menu.content_scale_factor, view.get_window().content_scale_factor, 0.001)
	menu.hide()


func test_hidden_schematic_takes_no_clicks() -> void:
	var view: SchematicView = SchematicView.new()
	add_child_autofree(view)
	view.load_document(_fault_doc(), true)
	view.hide()
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		click.pressed = pressed
		view._unhandled_input(click)
	assert_eq((view.get("_fault_menu") as PopupMenu).item_count, 0, "no fault menu over the workspace")


func test_sliders_spin_boxes_and_popup_panels_are_themed() -> void:
	var theme: Theme = AppTheme.build()
	assert_true(theme.has_icon("grabber", "HSlider"))
	assert_true(theme.has_stylebox("grabber_area", "HSlider"))
	assert_true(theme.has_color("up_icon_modulate", "SpinBox"))
	assert_eq(theme.get_stylebox("panel", "PopupPanel").content_margin_left, 14.0, "the popup panel keeps its own margins")


## WCAG contrast ratio of two colours.
static func _contrast(a: Color, b: Color) -> float:
	var la: float = a.srgb_to_linear().get_luminance()
	var lb: float = b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func test_warning_colours_are_readable_on_both_themes() -> void:
	for variant: AppTheme.Variant in [AppTheme.Variant.LIGHT, AppTheme.Variant.DARK]:
		AppTheme.use(variant)
		for c: Color in [AppTheme.danger, AppTheme.warning]:
			assert_gt(_contrast(c, AppTheme.bg0), 4.5 if variant == AppTheme.Variant.LIGHT else 3.0, "on the status bar")
	AppTheme.use(AppTheme.Variant.DARK)
