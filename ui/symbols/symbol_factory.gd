class_name SymbolFactory
extends RefCounted
## Creates the symbol node for a component.


static func create(component: CircuitComponent, placement: Placement) -> SchematicSymbol:
	var symbol: SchematicSymbol
	if component is MainContacts:
		symbol = MainContactsSymbol.new()
	elif component is ThreePoleFuse:
		symbol = ThreePoleFuseSymbol.new()
	elif component is CamSwitch:
		symbol = CamSwitchSymbol.new()
	elif component is MotorBreaker:
		symbol = BreakerSymbol.new()
	elif component is ThreePhaseMotor:
		symbol = ThreePhaseMotorSymbol.new()
	elif component is Fuse:
		symbol = FuseSymbol.new()
	elif component is CircuitBreaker:
		symbol = BreakerSymbol.new()
	elif component is SwitchingElement:
		symbol = ContactSymbol.new()
	elif component is ChangeoverContact:
		symbol = ChangeoverSymbol.new()
	elif component is OverloadRelay:
		symbol = OverloadRelaySymbol.new()
	elif component is Coil:
		symbol = CoilSymbol.new()
	elif component is Rectifier:
		symbol = RectifierSymbol.new()
	elif component is Plc:
		symbol = PlcSymbol.new()
	elif component is Transmitter:
		symbol = TransmitterSymbol.new()
	elif component is TemperatureSensor:
		symbol = TemperatureSensorSymbol.new()
	elif component is ProximitySensor:
		symbol = ProximitySensorSymbol.new()
	elif component is Potentiometer:
		symbol = PotentiometerSymbol.new()
	elif component is Vfd:
		symbol = VfdSymbol.new()
	elif component is NetworkSwitch:
		symbol = NetworkSwitchSymbol.new()
	elif component is Lamp:
		symbol = LampSymbol.new()
	elif component is Motor:
		symbol = MotorSymbol.new()
	elif component is PowerSupply:
		symbol = SupplySymbol.new()
	elif component is TerminalBlock:
		symbol = TerminalBlockSymbol.new()
	elif component is PageConnector:
		symbol = PageConnectorSymbol.new()
	elif component is Junction:
		symbol = JunctionSymbol.new()
	else:
		symbol = SchematicSymbol.new()
	symbol.setup(component, placement)
	return symbol
