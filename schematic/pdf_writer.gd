class_name PdfWriter
extends RefCounted
## Writes a PDF document in which every page shows one picture covering the
## whole page (an exported sheet of the schematic, see [SheetRenderer]). The
## pictures are stored losslessly (Flate), so thin lines and small text stay
## crisp when printed.

## Document title shown by PDF viewers.
var title: String = ""

## Per page: {"width", "height" (pixels), "data" (compressed RGB), "size" (points)}.
var _pages: Array[Dictionary] = []


## Adds a page of [param size_points] (1/72 inch) showing [param image].
func add_page(image: Image, size_points: Vector2) -> void:
	var rgb: Image = image.duplicate() as Image
	if rgb.is_compressed():
		rgb.decompress()
	if rgb.get_format() != Image.FORMAT_RGB8:
		rgb.convert(Image.FORMAT_RGB8)
	_pages.append({"width": rgb.get_width(), "height": rgb.get_height(), "data": rgb.get_data().compress(FileAccess.COMPRESSION_DEFLATE), "size": size_points})


func page_count() -> int:
	return _pages.size()


## Writes the document to [param path]. Returns OK or the file error.
func save(path: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(to_bytes())
	file.close()
	return OK


## The whole PDF file.
func to_bytes() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	# Header; the comment with high bytes marks the file as binary.
	out.append_array("%PDF-1.4\n".to_ascii_buffer())
	out.append_array(PackedByteArray([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]))
	# Objects: 1 catalog, 2 page tree, 3 information, then per page the page,
	# its content stream and its picture.
	var object_count: int = 3 + 3 * _pages.size()
	var offsets: PackedInt64Array = PackedInt64Array()
	offsets.resize(object_count + 1)
	var kids: PackedStringArray = PackedStringArray()
	for i: int in _pages.size():
		kids.append("%d 0 R" % (4 + 3 * i))
	_object(out, offsets, 1, "<< /Type /Catalog /Pages 2 0 R >>")
	_object(out, offsets, 2, "<< /Type /Pages /Kids [%s] /Count %d >>" % [" ".join(kids), _pages.size()])
	_object(out, offsets, 3, "<< /Title %s /Producer (LadderLab) /CreationDate (%s) >>" % [text_string(title), _date()])
	for i: int in _pages.size():
		var page: Dictionary = _pages[i]
		var number: int = 4 + 3 * i
		var size: Vector2 = page["size"]
		_object(out, offsets, number, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %s %s] /Resources << /XObject << /Im0 %d 0 R >> >> /Contents %d 0 R >>" % [_num(size.x), _num(size.y), number + 2, number + 1])
		var content: PackedByteArray = ("q %s 0 0 %s 0 0 cm /Im0 Do Q\n" % [_num(size.x), _num(size.y)]).to_ascii_buffer()
		_object(out, offsets, number + 1, "<< /Length %d >>" % content.size(), content)
		var data: PackedByteArray = page["data"]
		_object(out, offsets, number + 2, "<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length %d >>" % [page["width"], page["height"], data.size()], data)
	var xref: int = out.size()
	var table: String = "xref\n0 %d\n0000000000 65535 f \n" % (object_count + 1)
	for n: int in range(1, object_count + 1):
		table += "%010d 00000 n \n" % offsets[n]
	table += "trailer\n<< /Size %d /Root 1 0 R /Info 3 0 R >>\nstartxref\n%d\n%%%%EOF\n" % [object_count + 1, xref]
	out.append_array(table.to_ascii_buffer())
	return out


## [param text] as a PDF text string: UTF-16BE with a byte order mark, in hex.
static func text_string(text: String) -> String:
	var bytes: PackedByteArray = PackedByteArray([0xFE, 0xFF])
	for i: int in text.length():
		var code: int = text.unicode_at(i)
		var units: Array[int] = [code]
		if code > 0xFFFF:
			code -= 0x10000
			units = [0xD800 + (code >> 10), 0xDC00 + (code & 0x3FF)]
		for unit: int in units:
			bytes.append(unit >> 8)
			bytes.append(unit & 0xFF)
	return "<%s>" % bytes.hex_encode().to_upper()


static func _object(out: PackedByteArray, offsets: PackedInt64Array, number: int, dictionary: String, stream: PackedByteArray = PackedByteArray()) -> void:
	offsets[number] = out.size()
	out.append_array(("%d 0 obj\n%s\n" % [number, dictionary]).to_ascii_buffer())
	if not stream.is_empty():
		out.append_array("stream\n".to_ascii_buffer())
		out.append_array(stream)
		out.append_array("\nendstream\n".to_ascii_buffer())
	out.append_array("endobj\n".to_ascii_buffer())


static func _num(value: float) -> String:
	return "%.2f" % value


static func _date() -> String:
	var t: Dictionary = Time.get_datetime_dict_from_system()
	# The offset from UTC as it is now (daylight saving time included).
	var offset: int = roundi((Time.get_unix_time_from_datetime_dict(t) - Time.get_unix_time_from_system()) / 60.0)
	return date_text(t, offset)


## PDF date of local time [param t] (as [method Time.get_datetime_dict_from_system]
## gives it) [param offset] minutes ahead of UTC: "D:20250314093000+01'00'".
static func date_text(t: Dictionary, offset: int) -> String:
	var zone: String = "Z" if offset == 0 else "%s%02d'%02d'" % ["+" if offset > 0 else "-", floori(absi(offset) / 60.0), absi(offset) % 60]
	return "D:%04d%02d%02d%02d%02d%02d%s" % [t["year"], t["month"], t["day"], t["hour"], t["minute"], t["second"], zone]
