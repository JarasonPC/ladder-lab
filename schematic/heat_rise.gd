class_name HeatRise
extends RefCounted
## Temperature rise of the air inside a switchboard (oteplení rozváděče) by
## calculation, after the method of IEC 890 (ČSN 33 7107 part 1, for
## partially type-tested assemblies, used by ČSN EN 61439-1 for verifying
## the temperature rise by calculation): the effective cooling surface Ae
## of the enclosure (each outer surface times its factor b by how it is
## installed, [constant MOUNTINGS]), the rise half way up Δt0,5 = k · d · P^x,
## at the top Δt1,0 = c · Δt0,5, k and c read off the method's charts (figs.
## 2 to 7, digitised from the scanned method: their curves within about a
## pixel, the line width of the drawing ±0.001 k). P is the power lost by the
## devices and conductors inside at their rated currents ([method losses]).
## An enclosure over 11.5 m² of Ae or wider than 1.5 m is reckoned in
## sections of equal width, the dividing walls not counted. Nothing is
## assumed: what the drawing does not tell (the enclosure, the devices'
## losses, the wires' cross-sections …) has to be given, and the calculation
## is made only once it all is ([method missing]). No nodes.

## How an enclosure is installed (fig. 1): the curve of fig. 3 and the factor
## b of its top, back and sides (table 3; the front is always free,
## [constant FRONT], the floor never counts). English source text.
const MOUNTINGS: Array[Dictionary] = [
	{"title": "Separate enclosure, free on all sides", "curve": 1, "top": 1.4, "back": 0.9, "left": 0.9, "right": 0.9},
	{"title": "Separate enclosure for wall mounting", "curve": 3, "top": 1.4, "back": 0.5, "left": 0.9, "right": 0.9},
	{"title": "Separate enclosure with a side against a wall", "curve": 2, "top": 1.4, "back": 0.9, "left": 0.5, "right": 0.9},
	{"title": "Separate enclosure in a corner", "curve": 4, "top": 1.4, "back": 0.5, "left": 0.5, "right": 0.9},
	{"title": "Free-standing enclosure in a row", "curve": 3, "top": 1.4, "back": 0.9, "left": 0.5, "right": 0.5},
	{"title": "Enclosure in a row for wall mounting", "curve": 5, "top": 1.4, "back": 0.5, "left": 0.5, "right": 0.5},
	{"title": "Enclosure in a row for wall mounting, its top covered", "curve": 4, "top": 0.7, "back": 0.5, "left": 0.5, "right": 0.5},
]
const FRONT: float = 0.9
## Factor d by horizontal partitions inside (0 to 3, table 4 closed, table 5
## with ventilation openings).
const PARTITIONS_CLOSED: Array[float] = [1.0, 1.05, 1.15, 1.3]
const PARTITIONS_VENTED: Array[float] = [1.0, 1.05, 1.1, 1.15]
## Exponent x of P: closed, with ventilation openings.
const EXPONENT_CLOSED: float = 0.804
const EXPONENT_VENTED: float = 0.715
## Ae (m²) up to which the enclosure counts as small (figs. 6 and 7), the
## most one section may have, and the widest section (m).
const SMALL: float = 1.25
const MAX_AE: float = 11.5
const MAX_WIDTH: float = 1.5
## Most horizontal partitions the method takes; the outlet openings must be
## at least this times the inlet ones.
const MAX_PARTITIONS: int = 3
const OUTLET_SHARE: float = 1.1
## Fig. 6: k = SMALL_K · Ae^SMALL_EXP (a straight line on its log scales,
## fitted within 0.5 %), for Ae from SMALL_FROM m².
const SMALL_K: float = 0.6264
const SMALL_EXP: float = -0.7349
const SMALL_FROM: float = 0.08

## What a switchboard's calculation is given ([member Switchboard.heat]),
## each only once the user has given it, nothing assumed: the enclosure's
## "height", "width" and "depth" (mm), its "mounting" (index of
## [constant MOUNTINGS]), whether it has ventilation openings ("vented") and
## then the "inlet" and "outlet" openings (cm²), the horizontal
## "partitions", the "ambient" temperature and the most the air inside may
## reach, "limit" (°C), the "losses" of each device at its rated current (W
## by designation, from its maker), the cross-section of the wires on the
## nets of each rated current ("sections": mm² by the current as text,
## "16"), what the strip terminals lose together ("terminals", W), the
## further losses of what is not drawn ("extra", W: lighting, fans …) and
## the rated diversity factor "rdf" (over 0, at most 1).
const NUMBERS: PackedStringArray = ["height", "width", "depth", "inlet", "outlet", "ambient", "limit", "terminals", "extra", "rdf"]

## The rated diversity factor (RDF, součinitel soudobosti) as ČSN EN 61439-2
## (PSC, power switchgear) and ČSN EN 61439-3 (DBO, distribution boards
## operated by ordinary persons) give it when the maker gives none, shown
## for the user to choose from: what it applies to (English source text),
## the PSC value and the DBO value (null: none). The outgoing circuits are
## loaded at RDF times their rated currents together, so what they lose at
## their rated currents is lost RDF² times.
const RDF_TABLE: Array[Array] = [
	["2 and 3 outgoing circuits", 0.9, 0.8],
	["4 and 5 outgoing circuits", 0.8, 0.7],
	["6 to 9 outgoing circuits", 0.7, 0.6],
	["10 and more outgoing circuits", 0.6, 0.5],
	["Electric actuator", 0.2, null],
	["Motors up to 100 kW", 0.8, null],
	["Motors over 100 kW", 1.0, null],
]

## Copper conductors (annex H of ČSN EN 61439-1): cross-section (mm²) and
## resistance at 20 °C (mΩ/m); the temperature coefficient α (1/K) and the
## conductor temperature of annex H's loss formula (°C, the most PVC
## insulation is allowed).
const CONDUCTORS: Array[Vector2] = [
	Vector2(0.5, 36.0), Vector2(0.75, 24.5), Vector2(1.0, 18.1), Vector2(1.5, 12.1),
	Vector2(2.5, 7.41), Vector2(4.0, 4.61), Vector2(6.0, 3.08), Vector2(10.0, 1.83),
	Vector2(16.0, 1.15), Vector2(25.0, 0.727), Vector2(35.0, 0.524), Vector2(50.0, 0.387),
	Vector2(70.0, 0.268), Vector2(95.0, 0.193), Vector2(120.0, 0.153), Vector2(150.0, 0.124),
	Vector2(185.0, 0.0991), Vector2(240.0, 0.0754), Vector2(300.0, 0.0601),
]
const ALPHA: float = 0.004
const CONDUCTOR_TEMPERATURE: float = 70.0
## Fig. 2: k of an enclosure without ventilation openings, Ae > 1.25 m², by Ae (m²) from 0.75 step 0.25.
const FIG2_FROM: float = 0.75
const FIG2_STEP: float = 0.25
const FIG2: Array[float] = [
	0.7473, 0.6234, 0.5302, 0.4588, 0.396, 0.3467, 0.3066, 0.2742, 0.2488, 0.2271, 0.2105, 0.1988,
	0.1897, 0.1829, 0.1764, 0.1702, 0.1646, 0.1597, 0.1538, 0.15, 0.146, 0.1415, 0.1379, 0.1344,
	0.1314, 0.1285, 0.126, 0.1236, 0.1209, 0.1188, 0.1163, 0.1138, 0.1114, 0.1092, 0.1067, 0.1043,
	0.1021, 0.1002, 0.0985, 0.0963, 0.0937, 0.0916, 0.0892, 0.0861,
]
## Fig. 3: c of an enclosure without ventilation openings, Ae > 1.25 m², by f from 0.75 step 0.25, one row per curve 1-5 of fig. 1.
const FIG3_FROM: float = 0.75
const FIG3_STEP: float = 0.25
const FIG3: Array[Array] = [
	[
		1.2287, 1.2396, 1.2504, 1.2618, 1.2727, 1.283, 1.2937, 1.3041, 1.3157, 1.327, 1.3383, 1.3495,
		1.3597, 1.3706, 1.3811, 1.3913, 1.4011, 1.4116, 1.4215, 1.4316, 1.4413, 1.4503, 1.4585, 1.4667,
		1.4741, 1.4813, 1.4882, 1.4953, 1.5013, 1.5088, 1.5152, 1.5218, 1.5287, 1.5349, 1.5406, 1.5464,
		1.5515, 1.5573, 1.5623, 1.5669, 1.5713, 1.5757, 1.5797, 1.5837, 1.5877, 1.5918, 1.5955, 1.5996,
	],
	[
		1.2123, 1.223, 1.2346, 1.2457, 1.2563, 1.2673, 1.2776, 1.2882, 1.2992, 1.3103, 1.3212, 1.3327,
		1.3438, 1.3544, 1.365, 1.375, 1.3849, 1.3948, 1.4045, 1.415, 1.4244, 1.434, 1.4424, 1.4503,
		1.4583, 1.4661, 1.473, 1.4795, 1.4862, 1.4926, 1.4994, 1.5061, 1.5126, 1.5187, 1.5247, 1.5309,
		1.5365, 1.5419, 1.5478, 1.5515, 1.5565, 1.5615, 1.566, 1.5701, 1.574, 1.5778, 1.5811, 1.5843,
	],
	[
		1.1961, 1.206, 1.2175, 1.229, 1.24, 1.25, 1.2614, 1.2724, 1.2831, 1.2943, 1.3045, 1.3158,
		1.3272, 1.3386, 1.3494, 1.3591, 1.3695, 1.3786, 1.3883, 1.3997, 1.4077, 1.4168, 1.4254, 1.4341,
		1.4423, 1.4501, 1.4576, 1.4647, 1.4712, 1.4774, 1.4838, 1.4898, 1.4968, 1.5023, 1.5083, 1.5142,
		1.5198, 1.5257, 1.5307, 1.5355, 1.5404, 1.5451, 1.5494, 1.5529, 1.5578, 1.562, 1.5656, 1.5691,
	],
	[
		1.1735, 1.1835, 1.1944, 1.2051, 1.2164, 1.2274, 1.2383, 1.2491, 1.2602, 1.2714, 1.2818, 1.293,
		1.3033, 1.3147, 1.3261, 1.3373, 1.3481, 1.3574, 1.3672, 1.3767, 1.3859, 1.3949, 1.4026, 1.4113,
		1.4193, 1.4272, 1.4349, 1.4417, 1.4487, 1.4542, 1.461, 1.4671, 1.4732, 1.4786, 1.484, 1.4892,
		1.4949, 1.4997, 1.5042, 1.5092, 1.5134, 1.5181, 1.5225, 1.5265, 1.5307, 1.5347, 1.5382, 1.5418,
	],
	[
		1.1336, 1.1449, 1.155, 1.1663, 1.1769, 1.1871, 1.1979, 1.2087, 1.2198, 1.2312, 1.2419, 1.2527,
		1.2639, 1.2747, 1.2853, 1.2959, 1.3059, 1.3163, 1.3267, 1.337, 1.3476, 1.3556, 1.3643, 1.3723,
		1.3801, 1.3876, 1.3952, 1.4015, 1.4092, 1.4157, 1.4225, 1.429, 1.4356, 1.4418, 1.4481, 1.4534,
		1.4596, 1.4648, 1.4697, 1.4742, 1.4788, 1.4832, 1.4879, 1.4922, 1.4974, 1.5008, 1.5045, 1.508,
	],
]
## Fig. 4: k of an enclosure with ventilation openings, Ae > 1.25 m², by the inlet openings (cm²) from 50 step 10, one row per Ae of FIG4_AE.
const FIG4_FROM: float = 50.0
const FIG4_STEP: float = 10.0
const FIG4_AE: Array[float] = [1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 10, 12, 14]
const FIG4: Array[Array] = [
	[
		0.3589, 0.3456, 0.3314, 0.3187, 0.3062, 0.2943, 0.284, 0.2743, 0.2653, 0.2566, 0.2483, 0.2406,
		0.2334, 0.2263, 0.2201, 0.2138, 0.2082, 0.2028, 0.1982, 0.1936, 0.1892, 0.1848, 0.1805, 0.1768,
		0.173, 0.1691, 0.1657, 0.1622, 0.1591, 0.1555, 0.1523, 0.1492, 0.1462, 0.1434, 0.1406, 0.138,
		0.135, 0.1324, 0.13, 0.1278, 0.1255, 0.1234, 0.1212, 0.1195, 0.1175, 0.1156, 0.1138, 0.112,
		0.1103, 0.1089, 0.1071, 0.1056, 0.104, 0.1026, 0.101, 0.1, 0.0985, 0.097, 0.0957, 0.0945,
		0.0932, 0.092, 0.0906, 0.0897, 0.0889, 0.0877,
	],
	[
		0.3264, 0.3155, 0.3025, 0.2906, 0.2797, 0.2693, 0.26, 0.2511, 0.243, 0.2351, 0.2274, 0.2208,
		0.2146, 0.2086, 0.2028, 0.1975, 0.1924, 0.1879, 0.1834, 0.1793, 0.1752, 0.171, 0.1675, 0.164,
		0.1605, 0.1571, 0.1536, 0.1503, 0.1474, 0.1444, 0.1417, 0.1389, 0.1359, 0.1332, 0.1306, 0.1285,
		0.1262, 0.124, 0.1219, 0.12, 0.1181, 0.116, 0.1142, 0.1124, 0.1106, 0.1091, 0.1075, 0.106,
		0.1045, 0.103, 0.1016, 0.1002, 0.0991, 0.0976, 0.0963, 0.0951, 0.0938, 0.0926, 0.0913, 0.0903,
		0.0893, 0.0882, 0.0872, 0.0862, 0.0852, 0.0842,
	],
	[
		0.2988, 0.2887, 0.2775, 0.2675, 0.2578, 0.2481, 0.2398, 0.2322, 0.2249, 0.2178, 0.2112, 0.205,
		0.1994, 0.1939, 0.1891, 0.1839, 0.1796, 0.1754, 0.1714, 0.1679, 0.1643, 0.1607, 0.1574, 0.1541,
		0.1508, 0.148, 0.1451, 0.1423, 0.1398, 0.1369, 0.1343, 0.1314, 0.1291, 0.1266, 0.1242, 0.1219,
		0.1199, 0.1179, 0.1158, 0.1137, 0.1117, 0.11, 0.1084, 0.1067, 0.1051, 0.1036, 0.1021, 0.1005,
		0.0994, 0.0979, 0.0964, 0.0952, 0.0939, 0.0926, 0.0914, 0.0901, 0.0894, 0.0882, 0.0871, 0.0862,
		0.0853, 0.0843, 0.0834, 0.0825, 0.0817, 0.0808,
	],
	[
		0.2803, 0.2712, 0.2611, 0.2512, 0.2419, 0.2335, 0.2256, 0.2187, 0.2112, 0.2046, 0.1983, 0.1927,
		0.1878, 0.1824, 0.1781, 0.1735, 0.1695, 0.1657, 0.1621, 0.1588, 0.1553, 0.1518, 0.1489, 0.146,
		0.1432, 0.1406, 0.1376, 0.135, 0.1323, 0.1298, 0.1274, 0.1249, 0.1226, 0.1205, 0.1186, 0.1165,
		0.1144, 0.1125, 0.1105, 0.109, 0.1071, 0.1055, 0.104, 0.1025, 0.1009, 0.0998, 0.0982, 0.0967,
		0.0954, 0.0941, 0.0929, 0.0916, 0.0904, 0.0895, 0.0884, 0.0872, 0.0862, 0.0853, 0.0843, 0.0834,
		0.0825, 0.0816, 0.0806, 0.0801, 0.0794, 0.0786,
	],
	[
		0.2619, 0.2533, 0.244, 0.2352, 0.2271, 0.2194, 0.212, 0.2053, 0.199, 0.1927, 0.187, 0.1814,
		0.1769, 0.1722, 0.1683, 0.1642, 0.1602, 0.1568, 0.1535, 0.1502, 0.1473, 0.1443, 0.1413, 0.1389,
		0.136, 0.1333, 0.1306, 0.1282, 0.1258, 0.1235, 0.1214, 0.1196, 0.1174, 0.1153, 0.1135, 0.1115,
		0.1096, 0.1079, 0.1062, 0.1046, 0.103, 0.1014, 0.1, 0.0988, 0.0972, 0.0958, 0.0944, 0.0932,
		0.0919, 0.0906, 0.0898, 0.0886, 0.0873, 0.0863, 0.0853, 0.0843, 0.0834, 0.0825, 0.0816, 0.0806,
		0.08, 0.0793, 0.0783, 0.0774, 0.0766, 0.0757,
	],
	[
		0.2399, 0.2328, 0.2247, 0.2172, 0.2098, 0.2026, 0.1958, 0.19, 0.1841, 0.1785, 0.173, 0.1688,
		0.1643, 0.1603, 0.1565, 0.1527, 0.1493, 0.1464, 0.1435, 0.1406, 0.1379, 0.135, 0.1322, 0.1299,
		0.1275, 0.125, 0.1227, 0.1206, 0.1189, 0.1167, 0.1147, 0.1127, 0.1107, 0.1092, 0.1075, 0.1059,
		0.1043, 0.1027, 0.1011, 0.0997, 0.0984, 0.0968, 0.0955, 0.0942, 0.0929, 0.0915, 0.0904, 0.0895,
		0.0884, 0.0873, 0.0862, 0.0852, 0.0842, 0.0833, 0.0824, 0.0814, 0.0805, 0.0798, 0.0792, 0.078,
		0.0771, 0.0764, 0.0756, 0.0748, 0.074, 0.0732,
	],
	[
		0.2217, 0.2146, 0.2075, 0.2006, 0.194, 0.1874, 0.1814, 0.1763, 0.1708, 0.1659, 0.1613, 0.1573,
		0.1534, 0.1498, 0.1466, 0.1432, 0.1404, 0.1376, 0.1349, 0.1321, 0.1295, 0.127, 0.1247, 0.1226,
		0.1204, 0.1184, 0.1163, 0.1143, 0.1124, 0.1104, 0.1086, 0.1069, 0.1052, 0.1036, 0.1022, 0.1006,
		0.0993, 0.0978, 0.0964, 0.095, 0.0936, 0.0923, 0.0909, 0.09, 0.0891, 0.0877, 0.0868, 0.0858,
		0.0848, 0.0839, 0.083, 0.082, 0.0811, 0.0804, 0.0797, 0.0789, 0.078, 0.0772, 0.0764, 0.0756,
		0.0749, 0.0742, 0.0736, 0.073, 0.0723, 0.0716,
	],
	[
		0.2067, 0.2001, 0.193, 0.1866, 0.1802, 0.1744, 0.1689, 0.1639, 0.1594, 0.1547, 0.1505, 0.1468,
		0.1436, 0.1405, 0.1375, 0.1346, 0.1316, 0.1293, 0.1267, 0.1242, 0.1219, 0.1198, 0.1177, 0.1156,
		0.1136, 0.1116, 0.1098, 0.108, 0.1064, 0.1048, 0.1033, 0.1017, 0.1003, 0.0991, 0.0975, 0.0961,
		0.0948, 0.0935, 0.0922, 0.0908, 0.09, 0.089, 0.0877, 0.0866, 0.0856, 0.0846, 0.0837, 0.0828,
		0.082, 0.0809, 0.0801, 0.0795, 0.0788, 0.0777, 0.0769, 0.0762, 0.0753, 0.0746, 0.0738, 0.0731,
		0.0725, 0.0719, 0.0713, 0.0706, 0.0701, 0.0695,
	],
	[
		0.1939, 0.1883, 0.1818, 0.1761, 0.1703, 0.1648, 0.1598, 0.1549, 0.1503, 0.1463, 0.1425, 0.1394,
		0.1361, 0.1329, 0.13, 0.1274, 0.1246, 0.1222, 0.1201, 0.1179, 0.1157, 0.1135, 0.1113, 0.1096,
		0.1077, 0.1061, 0.1044, 0.1028, 0.1012, 0.1, 0.0986, 0.0971, 0.0956, 0.0943, 0.093, 0.0916,
		0.0905, 0.0895, 0.0882, 0.0871, 0.086, 0.085, 0.084, 0.0831, 0.0822, 0.0812, 0.0804, 0.0797,
		0.0791, 0.078, 0.0771, 0.0764, 0.0756, 0.0748, 0.0742, 0.0734, 0.0727, 0.072, 0.0714, 0.0707,
		0.0702, 0.0697, 0.0692, 0.0687, 0.0681, 0.0676,
	],
	[
		0.1811, 0.1753, 0.1697, 0.1641, 0.1591, 0.1537, 0.1493, 0.1451, 0.1411, 0.1373, 0.1337, 0.1303,
		0.1275, 0.1247, 0.1221, 0.1197, 0.1174, 0.1151, 0.113, 0.1108, 0.1089, 0.107, 0.1052, 0.1034,
		0.1017, 0.1003, 0.099, 0.0974, 0.0961, 0.0947, 0.0933, 0.092, 0.0906, 0.0896, 0.0885, 0.0873,
		0.0862, 0.0851, 0.0841, 0.0831, 0.0822, 0.0811, 0.0803, 0.0796, 0.0791, 0.078, 0.0771, 0.0763,
		0.0755, 0.0748, 0.0741, 0.0734, 0.0726, 0.072, 0.0713, 0.0706, 0.0701, 0.0696, 0.0693, 0.0686,
		0.068, 0.0676, 0.0671, 0.0666, 0.0662, 0.0657,
	],
	[
		0.1627, 0.1592, 0.1536, 0.1488, 0.1444, 0.1405, 0.1363, 0.1327, 0.1292, 0.1259, 0.1226, 0.1201,
		0.1174, 0.1148, 0.1124, 0.11, 0.1078, 0.1059, 0.104, 0.1023, 0.1005, 0.0991, 0.0973, 0.0958,
		0.0943, 0.0928, 0.0913, 0.0902, 0.0891, 0.0877, 0.0865, 0.0854, 0.0842, 0.0833, 0.0823, 0.0813,
		0.0803, 0.0795, 0.0787, 0.0776, 0.0767, 0.076, 0.0752, 0.0745, 0.0738, 0.0732, 0.0725, 0.0719,
		0.0711, 0.0706, 0.0701, 0.0696, 0.0692, 0.0688, 0.0681, 0.0676, 0.0671, 0.0667, 0.0663, 0.0659,
		0.0656, 0.0652, 0.0648, 0.0645, 0.0642, 0.0638,
	],
	[
		0.1473, 0.1439, 0.1396, 0.1353, 0.1314, 0.128, 0.1248, 0.1219, 0.1193, 0.1164, 0.1137, 0.1112,
		0.1092, 0.1069, 0.105, 0.1032, 0.1012, 0.0998, 0.0982, 0.0965, 0.095, 0.0935, 0.0922, 0.0907,
		0.0896, 0.0884, 0.087, 0.0858, 0.0847, 0.0836, 0.0825, 0.0814, 0.0805, 0.0797, 0.079, 0.0778,
		0.077, 0.0761, 0.0753, 0.0745, 0.0738, 0.0731, 0.0724, 0.0717, 0.0708, 0.0704, 0.0698, 0.0694,
		0.0689, 0.0682, 0.0678, 0.0672, 0.0667, 0.0663, 0.0659, 0.0655, 0.065, 0.0646, 0.0643, 0.0639,
		0.0636, 0.0633, 0.0629, 0.0626, 0.0624, 0.0621,
	],
	[
		0.1343, 0.1307, 0.1275, 0.1242, 0.1212, 0.1186, 0.1158, 0.1133, 0.1107, 0.1087, 0.1063, 0.1043,
		0.1025, 0.1007, 0.0992, 0.0973, 0.0956, 0.0941, 0.0926, 0.091, 0.09, 0.0885, 0.0871, 0.0859,
		0.0847, 0.0836, 0.0826, 0.0816, 0.0806, 0.0798, 0.079, 0.0781, 0.0772, 0.0764, 0.0756, 0.0747,
		0.074, 0.0732, 0.0724, 0.0717, 0.0709, 0.0703, 0.0697, 0.0693, 0.0684, 0.0679, 0.0673, 0.0667,
		0.0662, 0.0657, 0.0651, 0.0646, 0.0642, 0.0637, 0.0633, 0.0628, 0.0624, 0.062, 0.0616, 0.0611,
		0.0606, 0.0605, 0.0602, 0.0599, 0.0597, 0.0594,
	],
]
## Fig. 5: c of an enclosure with ventilation openings, Ae > 1.25 m², by the inlet openings (cm²) from 10 step 10, one row per f of FIG5_F.
const FIG5_FROM: float = 10.0
const FIG5_STEP: float = 10.0
const FIG5_F: Array[float] = [1.5, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const FIG5: Array[Array] = [
	[
		1.1669, 1.1978, 1.2302, 1.2608, 1.2901, 1.3172, 1.3447, 1.3689, 1.3932, 1.4137, 1.4351, 1.4544,
		1.4721, 1.4897, 1.5052, 1.5197, 1.5326, 1.5461, 1.5566, 1.5674, 1.5774, 1.5866, 1.5959, 1.6031,
		1.6117, 1.6203, 1.6283, 1.6361, 1.6442, 1.6499, 1.6566, 1.6634, 1.6696, 1.6755, 1.6813, 1.6872,
		1.6926, 1.6981, 1.7025, 1.7073, 1.7138, 1.7196, 1.7249, 1.7299, 1.7347, 1.7398, 1.7451, 1.7489,
		1.7526, 1.7569, 1.7622, 1.7661, 1.7701, 1.7742, 1.7782, 1.782, 1.7858, 1.7897, 1.7933, 1.797,
		1.8002, 1.8034, 1.807, 1.8112, 1.8146, 1.8179, 1.8212,
	],
	[
		1.2154, 1.2489, 1.2822, 1.3119, 1.3414, 1.3696, 1.3963, 1.4201, 1.4435, 1.4633, 1.4832, 1.5017,
		1.5203, 1.5372, 1.552, 1.5649, 1.5769, 1.5885, 1.5991, 1.609, 1.6189, 1.6285, 1.6377, 1.6467,
		1.6539, 1.6616, 1.6685, 1.6753, 1.6818, 1.6878, 1.6947, 1.7, 1.7055, 1.7125, 1.7185, 1.7246,
		1.73, 1.7355, 1.7407, 1.7457, 1.7504, 1.754, 1.7599, 1.7643, 1.7683, 1.7727, 1.777, 1.7812,
		1.7853, 1.7892, 1.7946, 1.7981, 1.8017, 1.8053, 1.8106, 1.8146, 1.8188, 1.8228, 1.8266, 1.8303,
		1.8339, 1.8379, 1.8417, 1.8463, 1.8492, 1.8524, 1.8556,
	],
	[
		1.3034, 1.3382, 1.3713, 1.4017, 1.4328, 1.4586, 1.4835, 1.5056, 1.5291, 1.5493, 1.5684, 1.5861,
		1.6004, 1.6149, 1.6284, 1.6417, 1.6523, 1.6632, 1.6731, 1.6823, 1.6912, 1.6994, 1.707, 1.7151,
		1.7229, 1.7305, 1.7375, 1.7452, 1.7509, 1.7552, 1.7626, 1.7685, 1.7738, 1.7791, 1.784, 1.7889,
		1.7941, 1.7986, 1.8021, 1.8064, 1.8119, 1.8165, 1.8211, 1.825, 1.8292, 1.8333, 1.8373, 1.8413,
		1.846, 1.8491, 1.8525, 1.8559, 1.8602, 1.8637, 1.8676, 1.8712, 1.8743, 1.8778, 1.8811, 1.8841,
		1.8875, 1.8908, 1.8948, 1.8977, 1.9005, 1.9031, 1.906,
	],
	[
		1.3669, 1.4065, 1.4456, 1.4777, 1.5075, 1.5364, 1.5614, 1.5835, 1.6026, 1.6226, 1.6406, 1.655,
		1.6692, 1.6821, 1.694, 1.7048, 1.7159, 1.7264, 1.7361, 1.7451, 1.7529, 1.7619, 1.7696, 1.7765,
		1.7836, 1.7902, 1.7972, 1.8026, 1.8093, 1.8154, 1.8215, 1.8271, 1.8325, 1.838, 1.8431, 1.848,
		1.8522, 1.8573, 1.8618, 1.8659, 1.8701, 1.8743, 1.8779, 1.8818, 1.8854, 1.8892, 1.893, 1.8968,
		1.8996, 1.9024, 1.9064, 1.9105, 1.9139, 1.9174, 1.9207, 1.924, 1.9275, 1.9308, 1.9338, 1.9368,
		1.9399, 1.943, 1.9466, 1.9486, 1.9511, 1.9529, 1.9551,
	],
	[
		1.4192, 1.4649, 1.5043, 1.5417, 1.5726, 1.6006, 1.6261, 1.6489, 1.6683, 1.6862, 1.7008, 1.7156,
		1.7294, 1.7422, 1.7534, 1.7641, 1.7737, 1.7831, 1.7917, 1.7997, 1.8069, 1.8153, 1.8228, 1.8295,
		1.836, 1.8429, 1.8491, 1.8541, 1.8611, 1.8665, 1.8725, 1.8778, 1.8826, 1.8879, 1.893, 1.897,
		1.9009, 1.9047, 1.9103, 1.9141, 1.9182, 1.9222, 1.9261, 1.9299, 1.9337, 1.9374, 1.9413, 1.9459,
		1.9483, 1.951, 1.9532, 1.9578, 1.9608, 1.964, 1.9671, 1.9702, 1.9731, 1.9762, 1.979, 1.9818,
		1.9843, 1.9872, 1.9901, 1.9928, 1.9955, 1.998, 2.0006,
	],
	[
		1.4669, 1.5213, 1.5655, 1.6012, 1.6337, 1.6606, 1.6842, 1.7042, 1.724, 1.7403, 1.7543, 1.7685,
		1.7809, 1.793, 1.8038, 1.8141, 1.8238, 1.8331, 1.8421, 1.8496, 1.857, 1.8652, 1.8722, 1.8788,
		1.8854, 1.8912, 1.8974, 1.9022, 1.9084, 1.9137, 1.9195, 1.9246, 1.9296, 1.9345, 1.9385, 1.9431,
		1.9472, 1.9509, 1.9535, 1.9581, 1.9615, 1.9654, 1.9689, 1.9724, 1.9757, 1.9792, 1.9825, 1.9858,
		1.9889, 1.9927, 1.9963, 1.9984, 2.0014, 2.0035, 2.0066, 2.0108, 2.0138, 2.0167, 2.0196, 2.0226,
		2.0253, 2.0285, 2.0315, 2.0347, 2.0382, 2.0413, 2.0444,
	],
	[
		1.5189, 1.5753, 1.6205, 1.6562, 1.6874, 1.713, 1.738, 1.7575, 1.7759, 1.7913, 1.8048, 1.8187,
		1.8309, 1.8429, 1.8525, 1.8621, 1.8707, 1.8794, 1.8872, 1.8947, 1.9017, 1.9091, 1.9157, 1.9222,
		1.9285, 1.9345, 1.9406, 1.9471, 1.9515, 1.9546, 1.9612, 1.9658, 1.9704, 1.9748, 1.9788, 1.983,
		1.987, 1.9909, 1.9956, 1.9985, 2.0016, 2.0044, 2.0095, 2.0129, 2.0162, 2.0197, 2.0232, 2.0264,
		2.0296, 2.0327, 2.036, 2.0391, 2.042, 2.0459, 2.048, 2.0507, 2.0525, 2.0545, 2.0579, 2.0603,
		2.063, 2.0654, 2.0678, 2.0702, 2.073, 2.0753, 2.0776,
	],
	[
		1.5699, 1.6268, 1.6722, 1.7066, 1.7375, 1.7643, 1.787, 1.8055, 1.8236, 1.8392, 1.8522, 1.8652,
		1.8768, 1.8874, 1.8999, 1.9046, 1.9138, 1.922, 1.9295, 1.9376, 1.9456, 1.9517, 1.9581, 1.9637,
		1.9696, 1.975, 1.9807, 1.9862, 1.9918, 1.9973, 2.0013, 2.0055, 2.0112, 2.0155, 2.0194, 2.0233,
		2.027, 2.0304, 2.034, 2.0374, 2.0408, 2.0455, 2.0476, 2.0504, 2.0526, 2.0557, 2.0586, 2.0617,
		2.0644, 2.0669, 2.0698, 2.0725, 2.0752, 2.0777, 2.0801, 2.0825, 2.0853, 2.0876, 2.0898, 2.0924,
		2.0955, 2.0972, 2.0996, 2.1022, 2.1045, 2.1077, 2.1103,
	],
	[
		1.6209, 1.6806, 1.7236, 1.7564, 1.7856, 1.8098, 1.8311, 1.8492, 1.8655, 1.88, 1.8939, 1.9046,
		1.9166, 1.9273, 1.9369, 1.9465, 1.9536, 1.9617, 1.9688, 1.9756, 1.9822, 1.9887, 1.9953, 2.0005,
		2.0057, 2.0114, 2.0165, 2.0215, 2.0264, 2.0302, 2.0348, 2.0391, 2.0436, 2.0477, 2.0505, 2.0533,
		2.0577, 2.0614, 2.0646, 2.0679, 2.0714, 2.0748, 2.0778, 2.0811, 2.084, 2.0869, 2.09, 2.0931,
		2.0964, 2.0983, 2.1008, 2.1031, 2.1055, 2.1087, 2.111, 2.1137, 2.1163, 2.1186, 2.1212, 2.1237,
		2.1261, 2.1288, 2.1314, 2.134, 2.1366, 2.1396, 2.1422,
	],
	[
		1.6699, 1.7308, 1.7711, 1.8026, 1.8311, 1.8527, 1.8726, 1.8897, 1.9045, 1.9192, 1.932, 1.9446,
		1.9534, 1.9636, 1.9726, 1.9809, 1.9888, 1.9966, 2.0027, 2.0088, 2.0169, 2.0234, 2.0297, 2.0352,
		2.0409, 2.0463, 2.0505, 2.0541, 2.0594, 2.0636, 2.0675, 2.0718, 2.0756, 2.0795, 2.0828, 2.0865,
		2.0897, 2.0934, 2.0967, 2.0992, 2.1021, 2.1049, 2.1091, 2.112, 2.115, 2.1178, 2.1205, 2.1233,
		2.126, 2.1288, 2.1316, 2.1341, 2.1366, 2.1394, 2.1426, 2.1462, 2.1476, 2.1495, 2.1517, 2.1536,
		2.1565, 2.1592, 2.1618, 2.1644, 2.167, 2.1697, 2.1719,
	],
]
## Fig. 7: c of an enclosure without ventilation openings, Ae <= 1.25 m², by g from 0 step 0.05.
const FIG7_FROM: float = 0.0
const FIG7_STEP: float = 0.05
const FIG7: Array[float] = [
	0.9999, 1.0099, 1.0195, 1.029, 1.0391, 1.0488, 1.0586, 1.0684, 1.0776, 1.087, 1.0969, 1.1069,
	1.1167, 1.1261, 1.1357, 1.1453, 1.1549, 1.1645, 1.1728, 1.1805, 1.1877, 1.1944, 1.2004, 1.2058,
	1.2108, 1.2155, 1.2197, 1.2233, 1.2264, 1.2293, 1.2317, 1.2343, 1.2366, 1.2387, 1.2403, 1.242,
	1.2437, 1.2452, 1.2465, 1.2478, 1.249, 1.2499, 1.2506, 1.2514, 1.2521, 1.2528, 1.2534, 1.2539,
	1.2545, 1.255, 1.2554, 1.2559, 1.2563, 1.2565, 1.2569, 1.2571,
]


## The settings in [param data] (a switchboard's [member Switchboard.heat]):
## only what was given and makes sense (a number of the right kind in its
## range, a mounting of the list, losses and cross-sections by key); nothing
## is filled in for what is missing.
static func settings(data: Variant) -> Dictionary:
	var d: Dictionary = data if data is Dictionary else {}
	var s: Dictionary = {}
	for key: String in NUMBERS:
		if _is_number(d.get(key)):
			var value: float = float(d[key])
			if key == "rdf":
				if value > 0.0 and value <= 1.0:
					s[key] = value
			elif (key in ["ambient", "limit"] and absf(value) < 200.0) or (key not in ["ambient", "limit"] and value >= 0.0):
				s[key] = value
	if _is_number(d.get("mounting")) and int(d["mounting"]) >= 0 and int(d["mounting"]) < MOUNTINGS.size():
		s["mounting"] = int(d["mounting"])
	if _is_number(d.get("partitions")) and int(d["partitions"]) >= 0 and int(d["partitions"]) <= MAX_PARTITIONS:
		s["partitions"] = int(d["partitions"])
	if d.get("vented") is bool:
		s["vented"] = d["vented"]
	for key: String in ["losses", "sections"]:
		if d.get(key) is Dictionary:
			var given: Dictionary = {}
			for name: Variant in d[key]:
				var value: Variant = d[key][name]
				if _is_number(value) and float(value) >= 0.0 and (key == "losses" or float(value) > 0.0):
					given[str(name)] = float(value)
			if not given.is_empty():
				s[key] = given
	return s


static func _is_number(value: Variant) -> bool:
	return value is float or value is int


## Height, width and depth (mm) of the enclosure given in [param s], or
## null while any of them is missing or 0.
static func enclosure(s: Dictionary) -> Variant:
	for key: String in ["height", "width", "depth"]:
		if float(s.get(key, 0.0)) <= 0.0:
			return null
	return Vector3(s["height"], s["width"], s["depth"])


## Whether switchboard [param b] of [param doc] is a house's consumer unit.
static func is_unit(doc: SchematicDocument, b: int) -> bool:
	return b >= 0 and b < doc.switchboards.size() and doc.switchboards[b].name == FloorPlan.UNIT.trim_prefix("+")


## What switchboard [param b] of [param doc] still needs to be given (see
## [method missing]) and, once nothing does, its calculation, with
## [param wires] its wiring laid out and settings [param s] (its own when
## null): {"settings", "losses" ([method losses]), "missing", "size" (mm,
## null while missing), "result" ([method calculate], {} while anything is
## missing)}.
static func evaluate(doc: SchematicDocument, b: int, wires: Array, s: Variant = null) -> Dictionary:
	var used: Dictionary = s if s is Dictionary else settings(doc.switchboards[b].heat)
	var lost: Dictionary = losses(doc, b, wires, used)
	var gaps: Array[Dictionary] = missing(used, lost)
	var size: Variant = enclosure(used)
	var result: Dictionary = {}
	if gaps.is_empty():
		result = calculate(size, used, lost["total"])
	return {"settings": used, "losses": lost, "missing": gaps, "size": size, "result": result}


## What [param s] and [param lost] (see [method losses]) still lack before
## the calculation can be made: [{"text" (English), "args"}].
static func missing(s: Dictionary, lost: Dictionary) -> Array[Dictionary]:
	var gaps: Array[Dictionary] = []
	var sizes: Dictionary = {"height": "The enclosure's height", "width": "The enclosure's width", "depth": "The enclosure's depth"}
	for key: String in sizes:
		if float(s.get(key, 0.0)) <= 0.0:
			gaps.append(_note(sizes[key], []))
	if not s.has("mounting"):
		gaps.append(_note("How the enclosure is installed", []))
	if not s.has("vented"):
		gaps.append(_note("Whether it has ventilation openings", []))
	elif s["vented"]:
		if float(s.get("inlet", 0.0)) <= 0.0:
			gaps.append(_note("The inlet openings", []))
		if not s.has("outlet"):
			gaps.append(_note("The outlet openings", []))
	if not s.has("partitions"):
		gaps.append(_note("The horizontal partitions", []))
	if not s.has("ambient"):
		gaps.append(_note("The ambient temperature", []))
	if not s.has("limit"):
		gaps.append(_note("The most allowed inside", []))
	for device: Dictionary in lost["devices"]:
		if device["power"] == null:
			gaps.append(_note("The loss of -%s", [device["designation"]]))
	for group: Dictionary in lost["groups"]:
		if group["section"] == null:
			gaps.append(_note("The cross-section of the wires carrying %s A", [_num(group["amperes"])]))
	if lost["terminal_count"] > 0 and not s.has("terminals"):
		gaps.append(_note("The loss of the strip terminals", []))
	if not s.has("extra"):
		gaps.append(_note("The further losses", []))
	if not s.has("rdf"):
		gaps.append(_note("The rated diversity factor RDF", []))
	return gaps


# --- Losses -------------------------------------------------------------------

## The power lost in switchboard [param b] of [param doc] at the rated
## currents, with [param wires] its wiring ([member CabinetWiring.wires]) and
## [param s] its settings: {"devices": [{"designation", "kind"
## ([enum CabinetDevices.Kind]), "power" (W as given, null while not)}],
## "groups": the wires by the current of their net, largest first,
## [{"key" (the current as text), "amperes", "count", "length" (m),
## "section" (mm² as given, null while not), "power" (W, null while the
## section is missing)}], "wire_count", "wire_length" (m), "terminal_count",
## "terminals" and "extra" (W as given, null while not), "rated" (W of the
## devices, wires and terminals at their rated currents, null while one is
## missing), "rdf" (as given), "total" (W: RDF² · rated + extra, null
## while anything is missing)}. A wire carries the largest rated current of
## a breaker, an RCD, a fuse or an overload relay (its setting) on its net
## and loses I² R20 (1 + α (Tc − 20 °C)) per metre (annex H of ČSN EN
## 61439-1); one on a net with none of them (a control circuit fed from
## outside) is not counted, nor are PE and Ethernet.
static func losses(doc: SchematicDocument, b: int, wires: Array, s: Dictionary) -> Dictionary:
	var circuit: Circuit = doc.circuit
	var given: Dictionary = s.get("losses", {})
	var sections: Dictionary = s.get("sections", {})
	var devices: Array[Dictionary] = []
	var under: Dictionary[String, String] = CabinetDevices.overloads_under_contactors(circuit)
	var strips: Array[String] = []
	if b >= 0 and b < doc.switchboards.size():
		for rail: CabinetRail in doc.switchboards[b].rails:
			for item: CabinetItem in rail.items:
				if item.kind == CabinetItem.Kind.STRIP:
					strips.append(item.designation)
				if item.kind != CabinetItem.Kind.DEVICE:
					continue
				var designations: PackedStringArray = PackedStringArray([item.designation])
				if under.has(item.designation):
					designations.append(under[item.designation])
				for designation: String in designations:
					var c: CircuitComponent = CabinetDevices.device(circuit, designation)
					if c != null:
						devices.append({"designation": designation, "kind": CabinetDevices.kind_of(c),
							"power": float(given[designation]) if given.has(designation) else null})
	var net: Dictionary[String, int] = CabinetDevices.nets(circuit)
	var current: Dictionary[int, float] = net_currents(circuit, net)
	var by_key: Dictionary = {}
	var wire_count: int = 0
	var wire_length: float = 0.0
	for wire: Dictionary in wires:
		var conductor: int = wire.get("conductor", CabinetDevices.Conductor.CONTROL)
		if conductor == CabinetDevices.Conductor.PE or conductor == CabinetDevices.Conductor.NETWORK:
			continue
		var amperes: float = current.get(int(wire.get("net", -1)), 0.0)
		if amperes <= 0.0:
			continue
		var points: PackedVector2Array = wire.get("points", PackedVector2Array())
		var metres: float = 0.0
		for i: int in range(1, points.size()):
			metres += points[i - 1].distance_to(points[i]) / 1000.0
		var key: String = _num(amperes)
		if not by_key.has(key):
			by_key[key] = {"key": key, "amperes": amperes, "count": 0, "length": 0.0}
		by_key[key]["count"] += 1
		by_key[key]["length"] += metres
		wire_count += 1
		wire_length += metres
	var groups: Array[Dictionary] = []
	for key: String in by_key:
		var group: Dictionary = by_key[key]
		group["section"] = float(sections[key]) if sections.has(key) else null
		group["power"] = conductor_loss(group["amperes"], group["length"], group["section"]) if group["section"] != null else null
		groups.append(group)
	groups.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return a["amperes"] > c["amperes"])
	var terminal_count: int = 0
	var all_strips: Dictionary = CabinetDevices.strips(doc) if not strips.is_empty() else {}
	for strip: String in strips:
		terminal_count += (all_strips.get(strip, []) as Array).size()
	# At the rated currents: the devices, the wires, the strip terminals.
	var rated: Variant = 0.0
	var parts: Array = []
	for device: Dictionary in devices:
		parts.append(device["power"])
	for group: Dictionary in groups:
		parts.append(group["power"])
	parts.append(s.get("terminals") if terminal_count > 0 else 0.0)
	for part: Variant in parts:
		if part == null:
			rated = null
			break
		rated += float(part)
	var rdf: Variant = s.get("rdf")
	var total: Variant = null
	if rated != null and rdf != null and s.has("extra"):
		total = rdf * rdf * rated + float(s["extra"])
	return {"devices": devices, "groups": groups, "wire_count": wire_count, "wire_length": wire_length,
		"terminal_count": terminal_count, "terminals": s.get("terminals"), "extra": s.get("extra"),
		"rated": rated, "rdf": rdf, "total": total}


## The largest rated current (A) of a breaker, an RCD, a fuse or an overload
## relay (its setting) on each net of [param net].
static func net_currents(circuit: Circuit, net: Dictionary[String, int]) -> Dictionary[int, float]:
	var result: Dictionary[int, float] = {}
	for c: CircuitComponent in circuit.get_components():
		var amperes: float = 0.0
		if c is ProtectiveDevice or c is MotorBreaker or c is ThreePoleFuse:
			amperes = float(c.get("rated_current"))
		elif c is OverloadRelay:
			amperes = (c as OverloadRelay).setting
		if amperes <= 0.0:
			continue
		for key: String in c.get_terminal_keys():
			var n: int = net.get(key, -1)
			if n >= 0:
				result[n] = maxf(result.get(n, 0.0), amperes)
	return result


## Loss (W) of copper conductors of [param mm2] [param metres] long in all
## carrying [param amperes]: I² R20 (1 + α (Tc − 20 °C)) (annex H of ČSN EN
## 61439-1).
static func conductor_loss(amperes: float, metres: float, mm2: float) -> float:
	if amperes <= 0.0 or metres <= 0.0:
		return 0.0
	return amperes * amperes * resistance(mm2) / 1000.0 * (1.0 + ALPHA * (CONDUCTOR_TEMPERATURE - 20.0)) * metres


## Resistance at 20 °C (mΩ/m) of a copper conductor of [param mm2] (the
## nearest of [constant CONDUCTORS] not thinner).
static func resistance(mm2: float) -> float:
	for entry: Vector2 in CONDUCTORS:
		if entry.x >= mm2 - 0.001:
			return entry.y
	return CONDUCTORS[CONDUCTORS.size() - 1].y

# --- The calculation ------------------------------------------------------------

## The temperature rise of an enclosure [param size] (height, width, depth
## in mm) set up as [param s] losing [param power] W inside: {"sections"
## (how many of equal width it is reckoned in), "section" (the one that
## gets warmest: {"width" (m), "surfaces" ([name (English), A0 m², b]),
## "ae" (m²), "small" (Ae <= [constant SMALL]), "vented", "power" (W),
## "inlet" (cm² of the section's openings, 0 closed), "curve" (of fig. 3),
## "partitions", "k",
## "d", "x", "factor" ("f" or "g"), "factor_value", "c", "half" (Δt0,5 K),
## "top" (Δt1,0 K)}), "half", "top" (K), "temperature" (°C at the top),
## "ok" (no warmer than the limit), "warnings" ([{"text" (English), "args"}])}.
static func calculate(size: Vector3, s: Dictionary, power: float) -> Dictionary:
	var warnings: Array[Dictionary] = []
	var h: float = size.x / 1000.0
	var w: float = size.y / 1000.0
	var depth: float = size.z / 1000.0
	var mounting: Dictionary = MOUNTINGS[clampi(int(s["mounting"]), 0, MOUNTINGS.size() - 1)]
	if int(s["partitions"]) > MAX_PARTITIONS:
		warnings.append(_note("More than %d horizontal partitions: the method does not cover them (reckoned with %d).", [MAX_PARTITIONS, MAX_PARTITIONS]))
	var inlet: float = float(s.get("inlet", 0.0)) if s.get("vented", false) else 0.0
	if inlet > 0.0 and float(s.get("outlet", 0.0)) < OUTLET_SHARE * inlet - 0.001:
		warnings.append(_note("The outlet openings (%s cm²) should be at least 1.1 times the inlet ones (%s cm²).", [_num(float(s.get("outlet", 0.0))), _num(inlet)]))
	# Sections of equal width: none wider than MAX_WIDTH, none over MAX_AE.
	var n: int = maxi(1, ceili(w / MAX_WIDTH - 0.0001))
	while n < 100 and _surfaces(h, w / n, depth, mounting, n == 1, true).reduce(_sum_ae, 0.0) > MAX_AE:
		n += 1
	var worst: Dictionary = {}
	# Which sides each kind of section has: one section both, else the two
	# ends one each and those between none.
	var kinds: Array[Vector2i] = [Vector2i(1, 1)]
	if n > 1:
		kinds = [Vector2i(1, 0), Vector2i(0, 1)]
	if n > 2:
		kinds.append(Vector2i(0, 0))
	var shared: Array[Dictionary] = []
	for kind: Vector2i in kinds:
		var notes: Array[Dictionary] = []
		var section: Dictionary = _section(h, w / n, depth, mounting, kind.x == 1, kind.y == 1, s, power / n, inlet / n, notes)
		if worst.is_empty() or section["top"] > worst["top"]:
			worst = section
			shared = notes
	warnings.append_array(shared)
	var temperature: float = float(s["ambient"]) + worst["top"]
	return {"sections": n, "section": worst, "half": worst["half"], "top": worst["top"],
		"temperature": temperature, "ok": temperature <= float(s["limit"]) + 0.0001, "warnings": warnings}


static func _section(h: float, w: float, depth: float, mounting: Dictionary, left: bool, right: bool, s: Dictionary, power: float, inlet: float, notes: Array[Dictionary]) -> Dictionary:
	var surfaces: Array = _surfaces(h, w, depth, mounting, left, right)
	var ae: float = surfaces.reduce(_sum_ae, 0.0)
	var small: bool = ae <= SMALL
	var vented: bool = inlet > 0.0
	var partitions: int = clampi(int(s["partitions"]), 0, MAX_PARTITIONS)
	var k: float
	var d: float = 1.0
	var x: float = EXPONENT_CLOSED
	var c: float
	var factor: String = "f"
	var factor_value: float = pow(h, 1.35) / (w * depth) if w > 0.0 and depth > 0.0 else 0.0
	if small:
		if vented:
			notes.append(_note("The method has no chart for ventilation openings with Ae up to 1.25 m²: reckoned as closed, on the safe side.", []))
			vented = false
		if ae < SMALL_FROM:
			notes.append(_range("Ae", ae, 6, SMALL_FROM, SMALL))
		k = SMALL_K * pow(maxf(ae, SMALL_FROM), SMALL_EXP)
		factor = "g"
		factor_value = h / w if w > 0.0 else 0.0
		c = _row(FIG7, FIG7_FROM, FIG7_STEP, factor_value, "g", 7, notes)
	elif vented:
		k = _family(FIG4, FIG4_AE, FIG4_FROM, FIG4_STEP, inlet, ae, "Ae", 4, notes)
		d = PARTITIONS_VENTED[partitions]
		x = EXPONENT_VENTED
		c = _family(FIG5, FIG5_F, FIG5_FROM, FIG5_STEP, inlet, factor_value, "f", 5, notes)
	else:
		if ae > MAX_AE:
			notes.append(_range("Ae", ae, 2, SMALL, MAX_AE))
		k = _row(FIG2, FIG2_FROM, FIG2_STEP, ae, "Ae", 2, notes)
		d = PARTITIONS_CLOSED[partitions]
		c = _row(FIG3[int(mounting["curve"]) - 1], FIG3_FROM, FIG3_STEP, factor_value, "f", 3, notes)
	var half: float = k * d * pow(maxf(power, 0.0), x)
	return {"width": w, "surfaces": surfaces, "ae": ae, "small": small, "vented": vented, "power": power,
		"inlet": inlet if vented else 0.0, "curve": int(mounting["curve"]), "partitions": partitions,
		"k": k, "d": d, "x": x, "factor": factor, "factor_value": factor_value, "c": c, "half": half, "top": c * half}


## The outer surfaces of a section [param w] m wide: [name, A0, b]; a side
## only where the section ends the enclosure ([param left], [param right]).
static func _surfaces(h: float, w: float, depth: float, mounting: Dictionary, left: bool, right: bool) -> Array:
	var surfaces: Array = [["Top", w * depth, mounting["top"]], ["Front", w * h, FRONT], ["Back wall", w * h, mounting["back"]]]
	if left:
		surfaces.append(["Left side", depth * h, mounting["left"]])
	if right:
		surfaces.append(["Right side", depth * h, mounting["right"]])
	return surfaces


static func _sum_ae(total: float, surface: Array) -> float:
	return total + float(surface[1]) * float(surface[2])


## The rise (K) at [param y] of the height (0 the floor, 1 the top) on the
## curve of [param result]: the straight line through Δt0,5 and Δt1,0, for a
## small enclosure Δt1,0 over its top quarter; under the middle the line on
## down (the method's curve falls away to nothing at the floor, so this is
## on the safe side), never under 0.
static func rise_at(result: Dictionary, y: float) -> float:
	var section: Dictionary = result["section"]
	var half: float = section["half"]
	var top: float = section["top"]
	if section["small"]:
		if y >= 0.75:
			return top
		return maxf(0.0, half + (y - 0.5) * (top - half) / 0.25)
	return maxf(0.0, half + (y - 0.5) * (top - half) * 2.0)


## [param values] read at [param at] (from [param from] in steps of
## [param step]), linearly between; beyond them their end, noted.
static func _row(values: Array, from: float, step: float, at: float, name: String, figure: int, notes: Array[Dictionary]) -> float:
	var last: float = from + step * (values.size() - 1)
	if at < from - 0.0001 or at > last + 0.0001:
		notes.append(_range(name, at, figure, from, last))
	var t: float = clampf((at - from) / step, 0.0, values.size() - 1)
	var i: int = mini(floori(t), values.size() - 2)
	return lerpf(float(values[i]), float(values[i + 1]), t - i)


## One of the curves [param rows] (one per value of [param keys]) read at
## [param at] (the inlet openings, cm²), between the two curves round
## [param key] linearly; beyond them the nearest, noted.
static func _family(rows: Array, keys: Array[float], from: float, step: float, at: float, key: float, name: String, figure: int, notes: Array[Dictionary]) -> float:
	var last: float = from + step * ((rows[0] as Array).size() - 1)
	if at < from - 0.0001 or at > last + 0.0001:
		notes.append(_range("A", at, figure, from, last))
	if key < keys[0] - 0.0001 or key > keys[keys.size() - 1] + 0.0001:
		notes.append(_range(name, key, figure, keys[0], keys[keys.size() - 1]))
	var quiet: Array[Dictionary] = []
	var kk: float = clampf(key, keys[0], keys[keys.size() - 1])
	var j: int = 0
	while j < keys.size() - 2 and kk > keys[j + 1]:
		j += 1
	var a: float = _row(rows[j], from, step, at, name, figure, quiet)
	var b: float = _row(rows[j + 1], from, step, at, name, figure, quiet)
	return lerpf(a, b, (kk - keys[j]) / (keys[j + 1] - keys[j]))


static func _range(name: String, value: float, figure: int, low: float, high: float) -> Dictionary:
	return _note("%s = %s is beyond fig. %d (%s to %s): its edge is taken.", [name, _num(value), figure, _num(low), _num(high)])


static func _note(text: String, args: Array) -> Dictionary:
	return {"text": text, "args": args}


## [param value] as written: a whole number without decimals, else to two places.
static func _num(value: float) -> String:
	if absf(value - roundf(value)) < 0.005:
		return str(roundi(value))
	return String.num(value, 2)
