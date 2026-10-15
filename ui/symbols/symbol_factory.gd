class_name SymbolFactory
extends RefCounted
## Creates the symbol node for a component.


static func create(component: CircuitComponent, placement: Placement) -> SchematicSymbol:
	var symbol: SchematicSymbol
	if component is SwitchingElement:
		symbol = ContactSymbol.new()
	elif component is Coil:
		symbol = CoilSymbol.new()
	elif component is Lamp:
		symbol = LampSymbol.new()
	elif component is Motor:
		symbol = MotorSymbol.new()
	elif component is PowerSupply:
		symbol = SupplySymbol.new()
	else:
		symbol = SchematicSymbol.new()
	symbol.setup(component, placement)
	return symbol
