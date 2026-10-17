class_name PowerSupply
extends CircuitComponent
## Supply point: one per conductor (L or L1, L2, L3, N, PE, +, -). Has a single
## terminal addressed by its designation alone (e.g. "L", "L1", "N", "+").
## L, L1-L3 and N belong to the same three-phase source (L is the same phase as
## L1); PE, the protective conductor, is joined to N at the source (TN
## system), so it has the potential of N and a phase touching it is a short
## that the fuse clears; + and - are the poles of a separate DC source (e.g. a
## rectifier for DC braking of motors). The AC source has 230 V between a
## phase and N (400 V between two phases); a + supply has its [member voltage]
## (12, 24, 48, 110 or 220 V) against the - poles, which all DC supplies share.

enum Conductor { L, N, L2, L3, DC_PLUS, DC_MINUS, PE }

## Source bits used by the simulator.
const BIT_L1: int = 1
const BIT_L2: int = 2
const BIT_L3: int = 4
const BIT_N: int = 8
## The + pole of 24 V; of the other voltages and of rectifiers below.
const BIT_DC_PLUS: int = 16
const BIT_DC_MINUS: int = 32
const BIT_DC_12: int = 64
const BIT_DC_48: int = 128
const BIT_DC_110: int = 256
const BIT_DC_220: int = 512
## The + of a bridge rectifier ([constant RECTIFIED_VOLTS]).
const BIT_DC_RECTIFIED: int = 1024
const DC_PLUS_BITS: int = BIT_DC_PLUS | BIT_DC_12 | BIT_DC_48 | BIT_DC_110 | BIT_DC_220 | BIT_DC_RECTIFIED
## The motor outputs U V W of frequency inverters (an AC source of their
## own, at their frequency).
const BIT_VFD_U: int = 2048
const BIT_VFD_V: int = 4096
const BIT_VFD_W: int = 8192
const VFD_BITS: int = BIT_VFD_U | BIT_VFD_V | BIT_VFD_W
## Bits of the AC source and of the DC source: a load works between two
## conductors of the same source only.
const AC_BITS: int = BIT_L1 | BIT_L2 | BIT_L3 | BIT_N | VFD_BITS
const DC_BITS: int = DC_PLUS_BITS | BIT_DC_MINUS
## Volts between a phase and N.
const PHASE_VOLTS: float = 230.0
## Voltages a + supply can have, the first the default.
const DC_VOLTAGES: PackedFloat32Array = [24.0, 12.0, 48.0, 110.0, 220.0]
const DC_VOLTAGE_BITS: PackedInt32Array = [BIT_DC_PLUS, BIT_DC_12, BIT_DC_48, BIT_DC_110, BIT_DC_220]
## Mean DC of a bridge rectifier fed with 230 V AC (0.9 x 230 V).
const RECTIFIED_VOLTS: float = 207.0

var conductor: Conductor
## Volts of a + supply against the - poles (one of [constant DC_VOLTAGES]).
var voltage: float = DC_VOLTAGES[0]


func _init(p_designation: String, p_conductor: Conductor) -> void:
	super(p_designation)
	conductor = p_conductor


func source_bit() -> int:
	match conductor:
		Conductor.N, Conductor.PE:
			return BIT_N
		Conductor.L2:
			return BIT_L2
		Conductor.L3:
			return BIT_L3
		Conductor.DC_PLUS:
			var level: int = DC_VOLTAGES.find(voltage)
			return DC_VOLTAGE_BITS[maxi(level, 0)]
		Conductor.DC_MINUS:
			return BIT_DC_MINUS
	return BIT_L1


## Volts of DC supply bit [param bit] against the - poles (0 for -).
static func dc_volts(bit: int) -> float:
	if bit == BIT_DC_RECTIFIED:
		return RECTIFIED_VOLTS
	var level: int = DC_VOLTAGE_BITS.find(bit)
	return DC_VOLTAGES[level] if level >= 0 else 0.0


func is_dc() -> bool:
	return conductor == Conductor.DC_PLUS or conductor == Conductor.DC_MINUS


## Short name of the conductor: "L", "L2", "L3", "N", "PE", "+" or "-" ("L1" when
## the designation says so).
func conductor_name() -> String:
	match conductor:
		Conductor.N:
			return "N"
		Conductor.L2:
			return "L2"
		Conductor.L3:
			return "L3"
		Conductor.DC_PLUS:
			return "+"
		Conductor.DC_MINUS:
			return "-"
		Conductor.PE:
			return "PE"
	return "L1" if designation.begins_with("L1") else "L"


func get_terminal_names() -> PackedStringArray:
	return PackedStringArray([designation])


func get_terminal_keys() -> PackedStringArray:
	return PackedStringArray([designation])
