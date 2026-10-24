class_name ReportRows
extends RefCounted
## Rows of a switchboard's document for the export, drawn by [ReportSheet]:
## the temperature rise protocol ([HeatRiseReport]), the interface
## characteristics ([InterfaceReport]), the operating instructions
## ([InstructionsReport]). No nodes.

## A row: {"type": "title" / "heading" / "text" / "table" / "curve" / "gap"}
## with "text" (title, heading, text; "muted" for a note), a table row's
## "cells", "widths" (parts of the width), "align" ("l" or "r" per cell),
## "head" (a table's heading row, repeated on a sheet it goes on to),
## "table" (which table it is in), "bold", "wrap" (its cells wrapped to
## their widths, "\n" a new line); a curve's "result", "ambient", "limit",
## "marks".
var _rows: Array[Dictionary] = []
var _table: int = 0


## What a document was exported from: the program and its version, the
## file ([param file_name], "" when not saved), the schematic's
## [param title] and when.
func source_text(file_name: String, title: String) -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	var when: String = Time.get_datetime_string_from_system(false, true)
	return tr("Exported from LadderLab %s: file %s, schematic \"%s\", on %s.") % [version, file_name if not file_name.is_empty() else tr("not saved"), title, when]


func _add(row: Dictionary) -> void:
	_rows.append(row)


func _heading(text: String) -> void:
	_add({"type": "heading", "text": text})


func _text(text: String, muted: bool) -> void:
	_add({"type": "text", "text": text, "muted": muted})


func _gap() -> void:
	_add({"type": "gap"})


func _table_head(cells: Array, widths: Array[float], align: Array, wrap: bool = false) -> void:
	_table += 1
	_add({"type": "table", "cells": cells, "widths": widths, "align": align, "head": true, "table": _table, "wrap": wrap})


func _table_row(cells: Array, widths: Array[float], align: Array, bold: bool = false, wrap: bool = false) -> void:
	_add({"type": "table", "cells": cells, "widths": widths, "align": align, "head": false, "table": _table, "bold": bold, "wrap": wrap})


## A value given, with its unit; "not given" while it is not.
func _given(value: Variant, unit: String) -> String:
	if value == null:
		return tr("not given")
	var text: String = _n(float(value), 2)
	return text if unit.is_empty() else "%s %s" % [text, unit]


static func _n(value: float, places: int) -> String:
	if absf(value - roundf(value)) < pow(10.0, -places) / 2.0:
		return str(roundi(value))
	return String.num(value, places)
