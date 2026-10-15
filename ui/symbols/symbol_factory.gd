class_name SymbolFactory
extends RefCounted
## Creates the symbol node for a component.


static func create(component: CircuitComponent, placement: Placement) -> SchematicSymbol:
	var symbol: SchematicSymbol
	if component is Fuse:
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
	elif component is Lamp:
		symbol = LampSymbol.new()
	elif component is Motor:
		symbol = MotorSymbol.new()
	elif component is PowerSupply:
		symbol = SupplySymbol.new()
	elif component is Junction:
		symbol = JunctionSymbol.new()
	else:
		symbol = SchematicSymbol.new()
	symbol.setup(component, placement)
	return symbol
