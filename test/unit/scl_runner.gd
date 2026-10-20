extends RefCounted
## Runs the SCL that [SclExport] writes, for the tests: parses the source
## (refusing anything outside the subset the export uses, so a mistake in
## the syntax shows up), then executes the function block one cycle at a
## time on a process image: %I bits and %IW words in, %Q bits, %M bits and
## %QW words out. IEC timers (TON_TIME, TOF_TIME) by their definition, on
## a clock in milliseconds. Written apart from [PlcRuntime], so the two can
## check each other.

var statics: Dictionary = {}
var temps: Dictionary = {}
## Process image: "%I0.0" -> bool, "%IW64" -> int, "%Q0.0", "%M0.0", "%QW96".
var image: Dictionary = {}
## Milliseconds since the start.
var clock: int = 0
## Parse error, "" when the source was read.
var error: String = ""

var _types: Dictionary = {}
var _body: Array = []
var _tokens: Array = []
var _at: int = 0


class IecTimer:
	var on_delay: bool
	var q: bool = false
	var last_in: bool = false
	var start: int = 0
	var running: bool = false

	func _init(p_on_delay: bool) -> void:
		on_delay = p_on_delay

	func call_timer(input: bool, pt: int, now: int) -> void:
		if on_delay:
			if not input:
				q = false
				running = false
			else:
				if not last_in:
					running = true
					start = now
				if running and now - start >= pt:
					q = true
					running = false
		else:
			if input:
				q = true
				running = false
			elif last_in:
				running = true
				start = now
			if running and now - start >= pt:
				q = false
				running = false
		last_in = input

	func reset() -> void:
		q = false
		last_in = false
		running = false


func _init(source: String) -> void:
	_tokens = _tokenize(source)
	if not error.is_empty():
		return
	_parse_file()


# --- Running -------------------------------------------------------------------

## One cycle of the function block.
func cycle() -> void:
	temps.clear()
	for name: String in _types:
		if str(_types[name]).begins_with("TEMP_ARRAY"):
			temps[name] = {}
		elif str(_types[name]) == "TEMP_BOOL":
			temps[name] = false
	_run(_body)


func _run(statements: Array) -> void:
	for s: Array in statements:
		match s[0]:
			"assign":
				_store(s[1], _eval(s[2]))
			"if":
				for branch: Array in s[1]:
					if branch[0] == null or bool(_eval(branch[0])):
						_run(branch[1])
						break
			"timer":
				var t: IecTimer = statics[s[1]]
				t.call_timer(bool(_eval(s[2])), int(_eval(s[3])), clock)
			"reset_timer":
				(statics[s[1]] as IecTimer).reset()


func _store(target: Array, value: Variant) -> void:
	match target[0]:
		"var":
			if temps.has(target[1]):
				temps[target[1]] = value
			else:
				assert(statics.has(target[1]), "unknown variable " + target[1])
				statics[target[1]] = value
		"index":
			temps[target[1]][int(_eval(target[2]))] = value
		"address":
			image[target[1]] = value


func _eval(e: Array) -> Variant:
	match e[0]:
		"lit":
			return e[1]
		"var":
			return temps[e[1]] if temps.has(e[1]) else statics[e[1]]
		"index":
			return temps[e[1]].get(int(_eval(e[2])), false)
		"member":
			return (statics[e[1]] as IecTimer).q
		"address":
			var a: String = e[1]
			return image.get(a, 0 if a.contains("W") else false)
		"not":
			return not bool(_eval(e[1]))
		"neg":
			return -_eval(e[1])
		"bin":
			var a: Variant = _eval(e[2])
			var b: Variant = _eval(e[3])
			match e[1]:
				"AND":
					return bool(a) and bool(b)
				"OR":
					return bool(a) or bool(b)
				"XOR":
					return bool(a) != bool(b)
				"=":
					return a == b
				"<>":
					return a != b
				">=":
					return a >= b
				"<=":
					return a <= b
				">":
					return a > b
				"<":
					return a < b
				"+":
					return a + b
				"-":
					return a - b
				"*":
					return a * b
		"call":
			var args: Dictionary = {}
			for key: String in e[2]:
				args[key] = _eval(e[2][key])
			match e[1]:
				"INT_TO_REAL":
					return float(args["0"])
				"WORD_TO_INT":
					var w: int = int(args["0"]) & 0xFFFF
					return w - 0x10000 if w >= 0x8000 else w
				"INT_TO_WORD":
					return int(args["0"]) & 0xFFFF
				"REAL_TO_INT":
					return clampi(roundi(float(args["0"])), -32768, 32767)
				"LIMIT":
					return clampf(float(args["IN"]), float(args["MN"]), float(args["MX"]))
				"SEL":
					return args["IN1"] if bool(args["G"]) else args["IN0"]
	assert(false, "cannot evaluate " + str(e))
	return null


# --- Reading ------------------------------------------------------------------

func _tokenize(source: String) -> Array:
	var tokens: Array = []
	var i: int = 0
	var n: int = source.length()
	while i < n:
		var ch: String = source[i]
		if ch in [" ", "\t", "\r", "\n"]:
			i += 1
		elif source.substr(i, 2) == "//":
			while i < n and source[i] != "\n":
				i += 1
		elif source.substr(i, 2) in [":=", ">=", "<=", "<>", ".."]:
			tokens.append(source.substr(i, 2))
			i += 2
		elif ch in ["(", ")", "[", "]", ";", ",", ":", "+", "-", "*", "=", "<", ">", "{", "}", "."]:
			tokens.append(ch)
			i += 1
		elif ch == "\"" or ch == "'":
			var j: int = source.find(ch, i + 1)
			tokens.append(source.substr(i, j - i + 1))
			i = j + 1
		elif ch == "%":
			var j: int = i + 1
			while j < n and (source[j] == "." or source[j].is_valid_int() or source[j] in ["I", "Q", "M", "W"]):
				j += 1
			tokens.append(source.substr(i, j - i))
			i = j
		elif ch == "#" or _word_char(ch):
			var j: int = i + 1
			while j < n and (_word_char(source[j]) or (source[j] == "#" and source.substr(i, 2) == "T#")):
				j += 1
			# A real literal: digits, a point, digits.
			if source.substr(i, j - i).is_valid_int() and j + 1 < n and source[j] == "." and source[j + 1].is_valid_int():
				j += 1
				while j < n and source[j].is_valid_int():
					j += 1
			tokens.append(source.substr(i, j - i))
			i = j
		else:
			error = "unexpected character '%s'" % ch
			return tokens
	return tokens


static func _word_char(ch: String) -> bool:
	return ch == "_" or ch.is_valid_int() or (ch.to_upper() != ch.to_lower())


func _peek() -> String:
	return _tokens[_at] if _at < _tokens.size() else ""


func _next() -> String:
	_at += 1
	return _tokens[_at - 1] if _at - 1 < _tokens.size() else ""


func _expect(token: String) -> void:
	var got: String = _next()
	if got != token and error.is_empty():
		error = "expected %s, found %s (token %d)" % [token, got, _at]


func _parse_file() -> void:
	var blocks: Array = []
	while _at < _tokens.size() and error.is_empty():
		var kind: String = _next()
		blocks.append(kind)
		match kind:
			"FUNCTION_BLOCK":
				_next()
				_header()
				while _peek() in ["VAR", "VAR_TEMP"]:
					_vars(_next() == "VAR_TEMP")
				_expect("BEGIN")
				_body = _statements(["END_FUNCTION_BLOCK"])
				_expect("END_FUNCTION_BLOCK")
			"DATA_BLOCK":
				_next()
				_header()
				_expect("NON_RETAIN")
				_next()
				_expect("BEGIN")
				_expect("END_DATA_BLOCK")
			"ORGANIZATION_BLOCK":
				_next()
				_expect("TITLE")
				_expect("=")
				_next()
				_header()
				_expect("VAR_INPUT")
				while _peek() != "END_VAR":
					_next()
				_expect("END_VAR")
				_expect("BEGIN")
				var call: String = _next()
				if not call.begins_with("\""):
					error = "the OB calls no data block"
				_expect("(")
				_expect(")")
				_expect(";")
				_expect("END_ORGANIZATION_BLOCK")
			_:
				error = "unexpected %s" % kind
	if error.is_empty() and blocks != ["FUNCTION_BLOCK", "DATA_BLOCK", "ORGANIZATION_BLOCK"]:
		error = "blocks: %s" % str(blocks)


## { S7_Optimized_Access := 'TRUE' } VERSION : 0.1
func _header() -> void:
	_expect("{")
	_expect("S7_Optimized_Access")
	_expect(":=")
	_expect("'TRUE'")
	_expect("}")
	_expect("VERSION")
	_expect(":")
	_expect("0.1")


func _vars(temp: bool) -> void:
	while _peek() != "END_VAR" and error.is_empty():
		var name: String = _next()
		_expect(":")
		var type: String = _next()
		if type == "Array":
			_expect("[")
			_expect("0")
			_expect("..")
			_next()
			_expect("]")
			_expect("of")
			_expect("Bool")
			_types[name] = "TEMP_ARRAY"
		elif temp:
			if type != "Bool":
				error = "temporary %s of type %s" % [name, type]
			_types[name] = "TEMP_BOOL"
		else:
			match type:
				"Bool":
					statics[name] = false
				"Real":
					statics[name] = 0.0
				"DInt":
					statics[name] = 0
				"TON_TIME":
					statics[name] = IecTimer.new(true)
				"TOF_TIME":
					statics[name] = IecTimer.new(false)
				_:
					error = "type %s" % type
			_types[name] = type
		if _peek() == ":=":
			_next()
			statics[name] = int(_next())
		_expect(";")
	_expect("END_VAR")


func _statements(ends: Array) -> Array:
	var list: Array = []
	while not ends.has(_peek()) and error.is_empty() and _at < _tokens.size():
		list.append(_statement())
	return list


func _statement() -> Array:
	var first: String = _peek()
	if first == "IF":
		var branches: Array = []
		_next()
		var cond: Array = _expr()
		_expect("THEN")
		branches.append([cond, _statements(["ELSIF", "ELSE", "END_IF"])])
		while _peek() == "ELSIF":
			_next()
			var c: Array = _expr()
			_expect("THEN")
			branches.append([c, _statements(["ELSIF", "ELSE", "END_IF"])])
		if _peek() == "ELSE":
			_next()
			branches.append([null, _statements(["END_IF"])])
		_expect("END_IF")
		_expect(";")
		return ["if", branches]
	if first == "RESET_TIMER":
		_next()
		_expect("(")
		var name: String = _next().trim_prefix("#")
		_expect(")")
		_expect(";")
		if not (statics.get(name) is IecTimer):
			error = "RESET_TIMER of %s, no timer" % name
		return ["reset_timer", name]
	if first.begins_with("#") and _at + 1 < _tokens.size() and _tokens[_at + 1] == "(":
		var name: String = _next().trim_prefix("#")
		_expect("(")
		_expect("IN")
		_expect(":=")
		var input: Array = _expr()
		_expect(",")
		_expect("PT")
		_expect(":=")
		var pt: Array = _expr()
		_expect(")")
		_expect(";")
		if not (statics.get(name) is IecTimer):
			error = "call of %s, no timer" % name
		return ["timer", name, input, pt]
	var target: Array = _primary()
	if not (target[0] in ["var", "index", "address"]):
		error = "cannot assign to %s" % str(target)
	if target[0] == "address" and target[1].begins_with("%I"):
		error = "assignment to input %s" % target[1]
	_expect(":=")
	var value: Array = _expr()
	_expect(";")
	return ["assign", target, value]


# Precedence, low to high: OR, XOR, AND, = <>, < > <= >=, + -, *, NOT / unary -.
func _expr() -> Array:
	return _binary(0)


const LEVELS: Array = [["OR"], ["XOR"], ["AND"], ["=", "<>"], ["<", ">", "<=", ">="], ["+", "-"], ["*"]]


func _binary(level: int) -> Array:
	if level >= LEVELS.size():
		return _unary()
	var left: Array = _binary(level + 1)
	while LEVELS[level].has(_peek()):
		var op: String = _next()
		left = ["bin", op, left, _binary(level + 1)]
	return left


func _unary() -> Array:
	if _peek() == "NOT":
		_next()
		return ["not", _unary()]
	if _peek() == "-":
		_next()
		return ["neg", _unary()]
	return _primary()


func _primary() -> Array:
	var t: String = _next()
	if t == "(":
		var e: Array = _expr()
		_expect(")")
		return e
	if t == "TRUE" or t == "FALSE":
		return ["lit", t == "TRUE"]
	if t.begins_with("T#") and t.ends_with("MS"):
		return ["lit", int(t.substr(2, t.length() - 4))]
	if t.is_valid_int():
		return ["lit", int(t)]
	if t.is_valid_float():
		return ["lit", float(t)]
	if t.begins_with("%"):
		return ["address", t]
	if t.begins_with("#"):
		var name: String = t.substr(1)
		if _peek() == "[":
			_next()
			var i: Array = _expr()
			_expect("]")
			return ["index", name, i]
		if _peek() == ".":
			_next()
			_expect("Q")
			if not (statics.get(name) is IecTimer):
				error = "%s.Q of no timer" % name
			return ["member", name]
		if not statics.has(name) and not _types.has(name):
			error = "undeclared %s" % name
		return ["var", name]
	if t in ["INT_TO_REAL", "WORD_TO_INT", "INT_TO_WORD", "REAL_TO_INT", "LIMIT", "SEL"]:
		_expect("(")
		var args: Dictionary = {}
		var k: int = 0
		while _peek() != ")" and error.is_empty():
			if _at + 1 < _tokens.size() and _tokens[_at + 1] == ":=":
				var key: String = _next()
				_next()
				args[key] = _expr()
			else:
				args[str(k)] = _expr()
				k += 1
			if _peek() == ",":
				_next()
		_expect(")")
		return ["call", t, args]
	error = "unexpected %s (token %d)" % [t, _at]
	return ["lit", false]
