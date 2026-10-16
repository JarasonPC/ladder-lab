class_name Phasor
extends RefCounted
## Complex numbers for AC currents and voltages, kept in a [Vector2]
## (x = real part, y = imaginary part). Voltages are in units of the phase
## voltage (230 V): L1 = 1∠0°, L2 = 1∠-120°, L3 = 1∠120°, N = 0; DC is real.

const ZERO := Vector2.ZERO
const ONE := Vector2(1.0, 0.0)
## a = 1∠120°, the operator of symmetrical components.
const A := Vector2(-0.5, 0.8660254037844386)
const A2 := Vector2(-0.5, -0.8660254037844386)


static func mul(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x)


static func div(a: Vector2, b: Vector2) -> Vector2:
	var d: float = b.x * b.x + b.y * b.y
	return Vector2((a.x * b.x + a.y * b.y) / d, (a.y * b.x - a.x * b.y) / d)


static func inv(a: Vector2) -> Vector2:
	return div(ONE, a)


static func polar(magnitude: float, angle: float) -> Vector2:
	return Vector2(cos(angle), sin(angle)) * magnitude


## Potential of phase 1-3 (L1-L3); 0 (N) for anything else.
static func phase(p: int) -> Vector2:
	match p:
		1:
			return ONE
		2:
			return A2
		3:
			return A
	return ZERO


## Solves [param m] x = [param b] for complex x; [param m] holds the n x n
## coefficients row by row. Gaussian elimination with partial pivoting; a
## singular column gives 0 for its unknown.
static func solve(m: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var n: int = b.size()
	for col: int in n:
		var best: int = col
		for r: int in range(col + 1, n):
			if m[r * n + col].length_squared() > m[best * n + col].length_squared():
				best = r
		if m[best * n + col].length_squared() < 1e-30:
			continue
		if best != col:
			for c: int in n:
				var t: Vector2 = m[col * n + c]
				m[col * n + c] = m[best * n + c]
				m[best * n + c] = t
			var v: Vector2 = b[col]
			b[col] = b[best]
			b[best] = v
		var pivot: Vector2 = m[col * n + col]
		for r: int in range(col + 1, n):
			if m[r * n + col] == ZERO:
				continue
			var f: Vector2 = div(m[r * n + col], pivot)
			for c: int in range(col, n):
				m[r * n + c] -= mul(f, m[col * n + c])
			b[r] -= mul(f, b[col])
	var x: PackedVector2Array = PackedVector2Array()
	x.resize(n)
	for r: int in range(n - 1, -1, -1):
		var sum: Vector2 = b[r]
		for c: int in range(r + 1, n):
			sum -= mul(m[r * n + c], x[c])
		x[r] = div(sum, m[r * n + r]) if m[r * n + r].length_squared() >= 1e-30 else ZERO
	return x
