class_name ApplianceSymbol
extends SchematicSymbol
## Appliance (see [Appliance]): a box with a sign of what it does (a heating
## element, the waves of a microwave, a drum, a snowflake), its supply above
## and below and its frame's PE beside the lower lead joined to the box.
## Its kind and power are written under the designation; an insulation fault
## shows as a fault, and "Frame live" in the fault colour while its frame has
## a phase. While it works the box is filled grey, as a lit lamp.

const BOX := Rect2(-13, 17, 26, 26)


func _draw_shape(color: Color, width: float) -> void:
	var appliance: Appliance = component as Appliance
	aa_line(Vector2(0, 0), Vector2(0, BOX.position.y), lead_color(0), lead_width(0))
	aa_line(Vector2(0, BOX.end.y), Vector2(0, 3 * G), lead_color(1), lead_width(1))
	aa_polyline(PackedVector2Array([Vector2(G, 3 * G), Vector2(G, BOX.get_center().y), Vector2(BOX.end.x, BOX.get_center().y)]), lead_color(2), lead_width(2))
	aa_rect(BOX, SchematicTheme.LAMP_ON if appliance.energized else SchematicTheme.BACKGROUND)
	aa_rect(BOX, color, false, width)
	draw_sign(self, appliance.kind, BOX.get_center(), color)


## The sign of appliance [param kind] centred on [param c], about 16 px wide.
static func draw_sign(symbol: SchematicSymbol, kind: Appliance.Kind, c: Vector2, color: Color) -> void:
	var w: float = SchematicTheme.LINE_WIDTH * 0.9
	match kind:
		Appliance.Kind.MICROWAVE:
			for k: int in 3:
				var y: float = c.y - 5.0 + 5.0 * k
				var wave: PackedVector2Array = PackedVector2Array()
				for i: int in 9:
					wave.append(Vector2(c.x - 8.0 + 2.0 * i, y + sin(i * PI / 2.0) * 1.6))
				symbol.aa_polyline(wave, color, w)
		Appliance.Kind.WASHING_MACHINE, Appliance.Kind.DISHWASHER:
			symbol.aa_arc(c, 7.0, 0.0, TAU, 24, color, w)
			symbol.aa_arc(c, 3.0, 0.0, TAU, 12, color, w)
		Appliance.Kind.FRIDGE:
			for k: int in 3:
				var d: Vector2 = Vector2.from_angle(k * PI / 3.0) * 8.0
				symbol.aa_line(c - d, c + d, color, w)
		_:
			# A heating element: a resistor's zigzag.
			var zig: PackedVector2Array = PackedVector2Array([c + Vector2(-9, 0)])
			for i: int in 6:
				zig.append(c + Vector2(-7.5 + 3.0 * i, -4.0 if i % 2 == 0 else 4.0))
			zig.append(c + Vector2(9, 0))
			symbol.aa_polyline(zig, color, w)


func has_fault() -> bool:
	return super() or (component as Appliance).frame_fault or (component as Appliance).arcing


func _draw_labels() -> void:
	var appliance: Appliance = component as Appliance
	var anchor: Vector2 = _designation_anchor()
	draw_label(designation_text(), anchor, SchematicTheme.LABEL_SIZE, SchematicTheme.DESIGNATION)
	var volts: String = "400 V" if appliance.two_phases else "230 V"
	draw_label(title_of(appliance), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 1)
	draw_label("%s %s" % [power_text(appliance.power), volts], anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, 2)
	var line: int = 3
	if not is_equal_approx(appliance.height, Appliance.STANDARD_HEIGHT):
		draw_label(LightSwitchSymbol.height_text(appliance.height), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.TEXT, line)
		line += 1
	var frame: int = reach(2)
	if frame >= StepResult.REACH_L1 and frame <= StepResult.REACH_L3:
		draw_label(tr("Frame live!"), anchor, SchematicTheme.TERMINAL_SIZE, SchematicTheme.FAULT, line)
	var names: PackedStringArray = component.get_terminal_names()
	draw_label(names[0], Vector2(0.35 * G, 0.4 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[1], Vector2(-0.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)
	draw_label(names[2], Vector2(1.35 * G, 2.6 * G), SchematicTheme.TERMINAL_SIZE, SchematicTheme.TERMINAL_TEXT)


## What [param appliance] is: the name of the user's symbol it is drawn
## with on the floor plan, else its kind's.
static func title_of(appliance: Appliance) -> String:
	return appliance.title if not appliance.title.is_empty() else kind_title(appliance.kind)


## Power as written: "150 W", "2 kW", "3.5 kW".
static func power_text(power: float) -> String:
	if power < 1000.0:
		return "%s W" % LuminaireSymbol.power_text(power)
	return "%s kW" % LuminaireSymbol.power_text(power / 1000.0)


## Name of appliance [param kind] as shown.
static func kind_title(kind: int) -> String:
	match kind:
		Appliance.Kind.OVEN:
			return TranslationServer.translate("Oven")
		Appliance.Kind.HOB:
			return TranslationServer.translate("Hob")
		Appliance.Kind.MICROWAVE:
			return TranslationServer.translate("Microwave")
		Appliance.Kind.WASHING_MACHINE:
			return TranslationServer.translate("Washing machine")
		Appliance.Kind.DISHWASHER:
			return TranslationServer.translate("Dishwasher")
		Appliance.Kind.HEATER:
			return TranslationServer.translate("Heater")
		Appliance.Kind.FRIDGE:
			return TranslationServer.translate("Fridge")
		Appliance.Kind.KETTLE:
			return TranslationServer.translate("Kettle")
	return TranslationServer.translate("Water heater")
